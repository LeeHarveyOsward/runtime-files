local U=require('lho.util');local P=require('lho.profiles')
local S={};S.__index=S
function S.new(ctx,actions) return setmetatable({ctx=ctx,actions=actions},S) end
function S:resolve()
    for slot=4,5 do
        local d=self.ctx:spell(slot);local name=(d.name or ''):lower()
        if name=='summonersmite_jade' then return slot,true,d end
        if P.smites[U.name(name)] then return slot,false,d end
    end
end
function S:damage()
    local override=self.ctx.config:get('smiteOverride')
    if override>0 then return override end
    local slot,classic,d=self:resolve();if not slot then return 0 end
    if classic then
        -- Live Classic exposes its current true-damage value on Lee himself.
        local buff=U.buff(myHero,{smitedamagebuff=true},self.ctx:now())
        local value=buff and buff.stacks
        if buff and (buff.count==nil or buff.count>0) and type(value)=='number' and value>=100 and value<=2000 then return value end
        return 460+30*U.clamp((myHero.levelData and myHero.levelData.lvl) or 1,1,18)
    end
    return P.smites[U.name(d.name)] or 0
end
function S:ready(validatingOwnedRequest)
    local slot,classic,d=self:resolve()
    if not slot or not self.ctx:ready(slot) or not validatingOwnedRequest and self.actions.pending[slot] then return false end
    return classic or (type(d.ammo)=='number' and d.ammo>0)
end
function S:inRange(target)
    local _,classic=self:resolve()
    local range=classic and 760 or 500
    -- Center-to-center is deliberately conservative until edge semantics are measured.
    return U.dist(myHero.pos,target.pos)<=range
end
function S:cast(target,owner,requireLethal)
    if not self:ready() or not U.valid(target) or target.team==myHero.team or target.isImmortal or not self:inRange(target) then return false end
    local slot,classic=self:resolve()
    -- Normal minion damage is not interchangeable with monster damage.
    if target.team~=300 and not (classic and Obj_AI_Minion and target.type==Obj_AI_Minion) then return false end
    if not self:campTarget(target) then return false end
    local margin=self:margin(target)
    if requireLethal and (target.health or 0)+(target.allShield or 0)>self:damage()-margin then return false end
    local function validAtKeypress()
        if not self:ready(true) or self:resolve()~=slot then return false,'smite_slot_or_readiness_changed' end
        if not U.valid(target) or not self:campTarget(target) or target.isImmortal then return false,'smite_target_unavailable' end
        if not self:inRange(target) then return false,'smite_out_of_range' end
        if requireLethal and target.health+(target.allShield or 0)>self:damage()-self:margin(target) then return false,'smite_not_lethal' end
        return (owner=='secure' or self.ctx.config:get('autosmite')) and not self.ctx:blocked() and self:ready(true)
            and self:resolve()==slot
            and U.valid(target) and self:campTarget(target) and not target.isImmortal and self:inRange(target)
            and (not requireLethal or target.health+(target.allShield or 0)<=self:damage()-self:margin(target))
    end
    local accepted,event=self.actions:cast(slot,target,owner,{urgent=true,interrupt=true,delay=.02,verifyHover=true,
        smiteExecute=requireLethal==true,validate=validAtKeypress})
    if accepted and self.ctx.config.capture then
        self.outcome={target=target,event=event,at=self.ctx:now(),health=target.health,damage=self:damage()}
    end
    if accepted then if self.ctx.config.capture then self.ctx:log('smite_execute_requested',{target=U.id(target),name=target.charName,
        health=target.health,shield=target.allShield,damage=self:damage(),margin=margin,slot=slot,
        distance=U.dist(myHero.pos,target.pos),owner=owner}) end end
    return accepted
end
function S:margin(target)
    return self.ctx.config:get(P.epics[P.category(target.charName)] and 'smiteEpicMargin' or 'smiteMargin')
end
function S:campTarget(target)
    if not target or target.team~=300 or not P.jungleEntity(target) then return false end
    local name=U.name(target.charName)
    if P.epics[P.category(target.charName)] then return true end
    -- Identity, never relative HP: a surviving/scaled companion must not
    -- become the main monster when the large monster dies or leaves vision.
    local names=self.ctx.profile.id=='classic' and P.classicSmiteTargets or P.normalSmiteTargets
    return names[name]==true
end
function S:auto(epicsOnly)
    local c=self.ctx
    local outcome=self.outcome
    if outcome then
        local event=outcome.event;local now=c:now()
        if event.status=='observed' or event.status=='unconfirmed' or event.gameplayCancelled or now-outcome.at>1 then
            local target=outcome.target
            local action=self.actions.api and self.actions:inputAction(event.cursorID)
            if c.config.capture then c:log('smite_outcome',{target=U.id(target),name=target.charName,
                healthBefore=outcome.health,healthAfter=target.health,dead=target.dead,valid=target.valid,
                damage=outcome.damage,request=event.id,cursorID=event.cursorID,status=event.status,
                sentAt=action and action.sentAt,aimSource=action and action.aim and action.aim.source,
                evidence='Concurrent damage may contribute; target HP is not exclusive Smite attribution'}) end
            self.outcome=nil
        end
    end
    local stamp=epicsOnly and 'epicAt' or 'fullAt'
    if self[stamp]==c:now() then return false end
    self[stamp]=c:now()
    local best,rank=nil,-1
    local enabled=c.config:get('autosmite')
    local cache=c.monsterCache
    local targets=cache and cache.source==c.minions and cache.units or c.minions or {}
    -- Re-enumerate in a nearby objective contest so replacement wrappers and
    -- fresh health do not wait for the general 80 ms object-cache refresh.
    local freshScan=false
    for _,m in ipairs(targets) do
        if m and m.team==300 and P.epics[P.category(m.charName)] and U.dist(myHero.pos,m.pos)<1400
            then freshScan=true;break end
    end
    -- A boss appearing in vision must not first wait for the ordinary cache.
    -- Profile-bound camp anchors are only a reason to enumerate, never proof
    -- that an objective exists, is visible, or is legally smiteable.
    if not freshScan then
        for _,camp in pairs(c.farm and c.farm.known or {}) do
            if P.epics[camp.category] and U.dist(myHero.pos,camp.pos)<1400 then freshScan=true;break end
        end
    end
    if freshScan and Game.MinionCount and Game.Minion then
        targets={}
        for i=1,U.count(Game.MinionCount(),4096) do local fresh=Game.Minion(i);if fresh then targets[#targets+1]=fresh end end
    end
    if #targets==0 and not self.contest then
        self.decision=enabled and 'No eligible monster in range' or 'Toggle OFF';return false
    end
    local ready=self:ready();local damage=self:damage()
    local reserve=not epicsOnly and c.farm and c.farm:epicSoon()
    self.decision=not enabled and 'Toggle OFF' or not ready and 'Cooldown / no charge / pending input' or 'No eligible monster in range'
    local rows=c.config.capture and {};local objectiveCount=0;local warm;local now=c:now();self.objectiveHealth=self.objectiveHealth or {}
    for _,m in ipairs(targets) do
        local cat=P.category(m.charName);local epic=P.epics[cat]
        if epic and m.team==300 and U.dist(myHero.pos,m.pos)<1600 and objectiveCount<8 then
            objectiveCount=objectiveCount+1
            local id=U.id(m);local prior=id and self.objectiveHealth[id]
            local seen=m.visible~=false;local hp=seen and m.health or nil
            local dt=prior and now-prior.at;local dps=hp and prior and dt>0 and dt<.5 and math.max(0,(prior.hp-hp)/dt) or 0
            if id and hp then self.objectiveHealth[id]={hp=hp,at=now} end
            if rows then rows[#rows+1]={id=id,name=m.charName,category=cat,hp=hp,shield=seen and m.allShield or nil,
                maxHP=seen and m.maxHealth or nil,visible=seen,valid=m.valid,dead=m.dead,targetable=m.isTargetable,
                pos=U.copy(m.pos),distance=U.dist(myHero.pos,m.pos),inRange=self:inRange(m),eligible=self:campTarget(m),
                lethal=U.valid(m) and m.health+(m.allShield or 0)<=damage-self:margin(m),damage=damage,margin=self:margin(m),dps=dps} end
            -- A short falling-health window prepares only the hover, not Smite.
            -- No fixed HP forecast is ever accepted as proof of a lethal cast.
            local window=math.min(damage*.5,math.max(75,dps*(c.latency+.06)))
            if c.config:get('smitePreaim') and enabled and ready and dps>0 and U.valid(m) and self:inRange(m)
                and self:campTarget(m) and m.health>damage and m.health+(m.allShield or 0)<=damage+window then warm=m end
        end
        if enabled and ready and U.valid(m) and m.team==300 and P.jungleEntity(m) and self:inRange(m) then
            local lethal=damage-self:margin(m)
            if (epic or not epicsOnly and c.config:get('smiteCamps') and self:campTarget(m)
                and not reserve) and m.health+(m.allShield or 0)<=lethal then
                local score=(cat=='Baron' or cat=='Elder') and 4 or epic and 3 or (cat=='Red' or cat=='Blue') and 2 or 1
                if score>rank then best,rank=m,score end
            elseif not epic and reserve then self.decision='Reserved for active nearby objective'
            elseif m.health+(m.allShield or 0)>lethal then self.decision='Waiting for lethal health' end
        end
    end
    for id,sample in pairs(self.objectiveHealth) do if now-sample.at>2 then self.objectiveHealth[id]=nil end end
    local ok=false
    if best then
        ok=self:cast(best,'autosmite',true)
        self.decision=ok and 'Execute requested' or 'Execute waiting for dispatcher'
    elseif warm and not c:blocked() and not c:recalling() and not c.leveling.pending
        and not c.input:previewHeld() and not (c.combat.insec and c.combat.insec.preview)
        and (not c.actions:cursorBusy() or c.actions:ownsHoverAim(warm,'autosmite')) then
        local aimed,reason=c.actions:prepareHover(warm,'autosmite')
        self.decision=aimed and 'Objective hover confirmed; waiting for lethal health' or reason
    end
    -- Persistent, bounded objective evidence survives the 20-minute playtest
    -- window. Dispatch takes priority over serialization and disk I/O.
    if rows and (#rows>0 or self.contest) then
        local slot,classic,spell=self:resolve();local block=c.actions.lastBlock
        local state=tostring(enabled)..':'..tostring(ready)..':'..tostring(self.decision)
        local edge=false;for _,row in ipairs(rows) do if row.lethal then edge=true end end
        if ok or edge~=self.lethalEdge or now>=(self.contestAt or 0)
            or state~=self.contestState and now-(self.lastSampleAt or -1)>=.05 or #rows==0 then
            if c.config.capture then c:log('objective_sample',{objectives=rows,enabled=enabled,ready=ready,slot=slot,classic=classic,
                cooldown=spell and spell.currentCd,ammo=spell and spell.ammo,damage=damage,mode=c.mode,
                decision=self.decision,attempted=ok,origin=U.copy(myHero.pos),cursorStep=c.sdk.Cursor.Step,
                block=block and now-block.at<.2 and block or nil,chat=Game.IsChatOpen and Game.IsChatOpen(),
                focused=Game.IsOnTop and Game.IsOnTop(),leeDead=myHero.dead}) end
            self.contestAt=now+(edge and .05 or .1);self.contestState=state;self.lethalEdge=edge;self.lastSampleAt=now
        end
    end
    self.contest=objectiveCount>0
    return ok
end
function S:clear(target,owner)
    if not self.ctx.config:get('autosmite') or not self:ready() or not U.valid(target) then return false end
    if self:auto(true) then return true end
    if P.epics[P.category(target.charName)] then return self:cast(target,'autosmite',true) end
    if not self.ctx.config:get('smiteCamps') then return false end
    -- Attack priority may be a small monster while the buff is already lethal.
    for _,camp in pairs(self.ctx.farm and self.ctx.farm.known or {}) do
        local found=false
        for _,m in ipairs(camp.members or {}) do if U.same(m,target) then found=true;break end end
        if found then
            for _,m in ipairs(camp.members or {}) do
                if U.valid(m) and self:campTarget(m) and (not self:campTarget(target)
                    or (m.maxHealth or 0)>(target.maxHealth or 0)) then target=m end
            end
            break
        end
    end
    if not self:campTarget(target) then return false end
    if self.ctx.farm and self.ctx.farm:epicSoon() then return false end
    return self:cast(target,'autosmite',true)
end
function S:followAim()
    local c=self.ctx;local aim=self.actions.hoverAim
    if not aim or aim.owner~='autosmite' or not c.config:get('autosmite') or c:blocked() then return false end
    if not self.actions:ownsHoverAim(aim.target,'autosmite') then return false end
    if not P.epics[P.category(aim.target.charName)] and (not c.config:get('smiteCamps') or c.farm:epicSoon()) then return false end
    return self:cast(aim.target,'autosmite',true)
end
return S
