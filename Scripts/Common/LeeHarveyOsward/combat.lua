local U=require('lho.util');local P=require('lho.profiles')
local B={};B.__index=B
function B.new(ctx,actions,spells,wards)
    local self=setmetatable({ctx=ctx,actions=actions,spells=spells,wards=wards},B)
    self.planner=require('lho.insec').new(self);self.kicks=require('lho.kickplan').new(ctx)
    self.tactics=require('lho.tactics').new(self);return self
end
function B:planAligned(i,origin)
    return self:aligned({pos=i.plannedTarget or i.target.pos},i.plannedEndpoint or i.endpoint,origin)
end
function B:direction(target,destination)
    local endpoint=U.toward(target.pos,destination,self.ctx.profile.kickDistance)
    local stand=math.min(self.ctx.config:get('insecStandDistance'),self.ctx.profile.rRange-45)
    return U.toward(target.pos,destination,-stand),endpoint
end
function B:allyDestination(target,origin,preferred)
    local c=self.ctx;local best,score=nil,math.huge
    local function tower(a,range)
        -- Fountain structures may be untargetable; we target the enemy, not
        -- the recipient. Dead or invalid structures never qualify.
        if a.team~=myHero.team or a.valid==false or a.dead or not U.position(a.pos)
            or not U.finite(a.health) or a.health<=0 then return end
        local endpoint=U.toward(target.pos,a.pos,c.profile.kickDistance)
        local inside=U.dist(endpoint,a.pos)
        if inside<=range-35 then
            local value=inside+U.dist(origin,a.pos)*.05
            if U.same(a,preferred) or a.platform and preferred and preferred.platform then value=-1 end
            if value<score then best,score=a,value end
        end
    end
    for _,a in ipairs(c.config:get('insecPreferStructures') and c.turrets or {}) do
        local range=U.finite(a.range) and a.range>0 and a.range or 775
        tower(a,range+(a.boundingRadius or 80)+(target.boundingRadius or 0))
    end
    local spawn=c.farm.spawnPos or c.farm.spawnPoints and c.farm.spawnPoints[myHero.team]
    if spawn and c.config:get('insecPreferStructures') and c.config:get('insecBasePlatform') then
        -- A recorded spawn anchor supports a small area deep in the platform.
        -- Do not fabricate the unobserved laser's outer attack radius.
        tower({team=myHero.team,pos=spawn,health=1,charName='Base platform',platform=true},250)
    end
    if best then return U.copy(best.pos),best,'structure' end
    for _,a in ipairs(c.allies or {}) do
        if a.team==myHero.team and not U.same(a,myHero) and U.valid(a) and U.dist(target.pos,a.pos)<2000 then
            local value=U.dist(target.pos,a.pos)+c:threats(a.pos,700)*200
            if value<score then best,score=a,value end
        end
    end
    return U.copy(best and best.pos or origin),best,best and 'ally' or 'origin'
end
function B:aligned(target,endpoint,origin)
    origin=origin or myHero.pos
    if U.dist(origin,target.pos)>self.ctx.profile.rRange or U.dist(origin,target.pos)<25 then return false end
    local dx,dz=target.pos.x-origin.x,target.pos.z-origin.z
    local ex,ez=endpoint.x-target.pos.x,endpoint.z-target.pos.z
    local length=math.sqrt((dx*dx+dz*dz)*(ex*ex+ez*ez))
    if length<1 then return false end
    return (dx*ex+dz*ez)/length+1e-9>=math.cos(math.rad(self.ctx.config:get('insecAngle')))
end
function B:startInsec(kind)
    local c=self.ctx;local target=c:locked()
    local selection='GG selection'
    if not target and c.config:get('insecMouseTarget') then
        local nearest=c.config:get('insecMouseRadius')
        for _,enemy in ipairs(c.enemies or {}) do
            local distance=U.dist(c.aim,enemy.pos)
            if distance<nearest and c:enemyValid(enemy) then target=enemy;nearest=distance end
        end
        selection='Mouse fallback'
    end
    if not c:enemyValid(target) then c.status='Select a champion for insec';return false end
    local origin=U.copy(myHero.pos)
    if kind=='ally' and c.input:held('allyKey') and not self.allyHoldOrigin then self.allyHoldOrigin=U.copy(origin) end
    self.insec={kind=kind,target=target,origin=origin,at=c:now(),phase='approach',preview=c.input:previewHeld(),selection=selection}
    self.insec.fallbackOrigin=U.copy(kind=='ally' and self.allyHoldOrigin or origin)
    if c.config.capture then c:log('insec_started',{insecKind=kind,target=U.id(target),name=target.charName,origin=origin,
        wardSlot=c.wards:slot(),preview=self.insec.preview,flash=false,selection=selection}) end
    if kind=='ally' then self.insec.destination,self.insec.recipient,self.insec.recipientKind=self:allyDestination(target,self.insec.fallbackOrigin)
    elseif c.config:get('aimLock')==1 then
        self.insec.destination=U.copy(c.aim);self.insec.locked=true
        local direction=U.toward(target.pos,c.aim,1);self.insec.direction={x=direction.x-target.pos.x,z=direction.z-target.pos.z}
    end
    return true
end
function B:cancel(reason)
    if self.insec then
        if self.ctx.config.capture then self.ctx:log('insec_cancelled',{reason=reason or 'Mode released / input takeover',phase=self.insec.phase,
            outcome=self.insec.preview and 'Preview ended' or self.insec.commitAt and 'Stopped after resource commitment' or 'Stopped before resource commitment',
            target=U.id(self.insec.target),plan=self.insec.resource,flashReason=self.insec.flashReason,
            targetVisible=self.insec.target.visible,targetDead=self.insec.target.dead,targetHP=self.insec.target.health,
            targetable=self.insec.target.isTargetable,leeDead=myHero.dead,leeHP=myHero.health,
            rState=Game.CanUseSpell(3),rCooldown=self.ctx:spell(3).currentCd,energy=myHero.mana,
            cursorHeld=self.ctx.input:held('cursorKey'),allyHeld=self.ctx.input:held('allyKey'),
            chat=Game.IsChatOpen and Game.IsChatOpen(),focus=Game.IsOnTop and Game.IsOnTop(),
            lastInput=self.ctx.input.lastPhysicalEvent,lastTransition=self.ctx.input.lastTransition,mode=self.ctx.mode,
            request=self.insec.event and self.insec.event.id,castStatus=self.insec.event and self.insec.event.status}) end
        self.actions:cancel('insec')
        if self.wards.pending and self.wards.pending.owner=='insec' then self.wards:cancel('Insec released') end
        self.insec=nil
    end
end
function B:insecOrbwalkAllowed()
    local c=self.ctx;local i=self.insec
    if not c.config:get('insecOrbwalk') or (c.mode~='cursor' and c.mode~='ally')
        or not c.input:held(c.mode=='cursor' and 'cursorKey' or 'allyKey')
        or c.input:previewHeld() or c.input.cancel or c:blocked() or c:recalling()
        or c.wards.pending or c:combatTransit() or c.leveling.pending then return false end
    return not i or i.orbwalking and not i.preview and not i.confirmBlocked and not i.flight and not i.qWait
        and i.phase~='kick' or false
end
function B:orbwalkInsec(suppressed)
    local c=self.ctx
    if suppressed or not self:insecOrbwalkAllowed() then return end
    c.moveTarget=c.aim
    local target=self.insec and self.insec.target
    if not c:enemyValid(target) or U.dist(myHero.pos,target.pos)>c:attackRange(target) then
        target=c:target(c:attackRange(myHero)+100)
    end
    if c:enemyValid(target) and U.dist(myHero.pos,target.pos)<=c:attackRange(target) then c.attackTarget=target end
end
function B:confirmPreview()
    local i=self.insec;local c=self.ctx
    if not i or not i.preview or c.input:previewHeld() then return false end
    if not c.input:held(i.kind=='cursor' and 'cursorKey' or 'allyKey') then return false end
    local shown=i.displayPlan or i.plan
    i.preview=false;i.search=nil;i.displayPlan=nil
    if not shown then i.confirmBlocked=true;i.resource='No shown plan to confirm; hold Alt to preview';return false end
    i.contract={};i.contractIndex=1;i.flashConsent=false
    for _,step in ipairs(shown.steps) do
        i.contract[#i.contract+1]={kind=step.kind,unitID=U.id(step.unit),itemID=step.itemID}
        if step.kind=='flash' then i.flashConsent=true end
    end
    i.plan=shown;i.approvedLabel=shown.label;i.at=c:now();i.confirmBlocked=nil
    self.planner:committed(i,c.aim)
    if c.config.capture then c:log('insec_confirmed',{plan=shown.label,flash=i.flashConsent,target=U.id(i.target),resources=i.contract}) end
    return true
end
function B:previewTick(i)
    local c=self.ctx
    local r=c:spell(3)
    if (r.level or 0)==0 or (r.currentCd or 0)>0 then
        i.plan=nil;i.displayPlan=nil;i.resource='R on cooldown / not learned';i.phase='preview';c.status='ALT PREVIEW | '..i.resource;return
    end
    self:geometry(i)
    if not i.stand then return end
    local plan=self.planner:adapt(i,self.planner:search(i))
    if plan and self.planner:validate(i,plan) then i.plan=plan
    elseif i.plan and not self.planner:validate(i,self.planner:adapt(i,i.plan)) then i.plan=nil end
    i.phase='preview';i.resource=i.plan and i.plan.label or 'No complete opportunity yet'
    local _,reason=self.planner:flashAllowed(i);i.flashReason=reason
    if c.config.capture then c:trace('insec_preview',{target=U.id(i.target),targetPos=U.copy(i.target.pos),plan=i.plan and i.plan.label,
        stand=U.copy(i.stand),endpoint=U.copy(i.endpoint),searching=i.search and not i.search.done,
        resources=i.plan and i.plan.steps and #i.plan.steps or 0,flashReason=reason},tostring(U.id(i.target)),.25) end
    c.status='ALT PREVIEW | Release Alt to confirm | '..i.resource
end
function B:geometry(i,wardPlacement)
    local c=self.ctx
    if i.kind=='ally' and i.recipient and (i.recipient.dead or i.recipient.valid==false or (i.recipient.health or 0)<=0) then
        i.locked=nil;i.direction=nil;i.recipient=nil
        i.destination,i.recipient,i.recipientKind=self:allyDestination(i.target,i.fallbackOrigin or i.origin)
    end
    if i.kind=='ally' and not i.locked and c.config:get('insecTrackAlly') then
        local destination,recipient,kind=self:allyDestination(i.target,i.fallbackOrigin or i.origin,i.recipient)
        if kind=='structure' or i.recipientKind=='structure' or not U.valid(i.recipient) then
            i.destination,i.recipient,i.recipientKind=destination,recipient,kind
        else i.destination=U.copy(i.recipient.pos) end
    end
    local aim=i.destination or c.aim
    if i.locked and i.direction then
        aim={x=i.target.pos.x+i.direction.x*1200,y=i.target.pos.y,z=i.target.pos.z+i.direction.z*1200}
    end
    if i.kind=='cursor' and c.config:get('aimLock')==3 then aim=c.aim end
    if not aim or U.dist(aim,i.target.pos)<10 then return end
    i.stand,i.endpoint=self:direction(i.target,aim)
    i.geometryTarget=U.copy(i.target.pos)
    i.plannedTarget=i.target.pos;i.plannedEndpoint=i.endpoint
    local lead=c.config:get('insecLead')/1000
    local pending=c.wards.pending
    local wardStep=i.plan and i.plan.steps and i.plan.steps[1] and i.plan.steps[1].kind=='ward'
    if c.config:get('insecAutoLead') and (wardPlacement or wardStep or pending and pending.owner=='insec') then
        local remaining=self.tactics:wardArrival()
        if pending and pending.owner=='insec' then remaining=remaining-math.max(0,c:now()-pending.at) end
        lead=math.max(lead,U.clamp(remaining,0,.65))
    end
    i.predictionLead=lead
    if i.target.GetPrediction and i.target.pathing and i.target.pathing.hasMovePath and lead>0 then
        local ok,p=pcall(i.target.GetPrediction,i.target,math.huge,lead)
        if ok and p and type(p.x)=='number' and type(p.z)=='number' and p.x==p.x and p.z==p.z
            and U.dist(p,i.target.pos)<300 then
            i.plannedTarget=p
            local futureAim=i.locked and i.direction and {x=p.x+i.direction.x*1200,y=p.y,z=p.z+i.direction.z*1200} or aim
            i.stand=U.toward(p,futureAim,-math.min(c.config:get('insecStandDistance'),c.profile.rRange-45))
            i.plannedEndpoint=U.toward(p,futureAim,c.profile.kickDistance)
        end
    end
    return aim
end
function B:kickValid(i)
    if not self.ctx:enemyValid(i.target) or self:kickProtected(i.target) or not self:aligned(i.target,i.endpoint) then return false end
    local target=i.target
    if target.GetPrediction and target.pathing and target.pathing.hasMovePath then
        local ok,p=pcall(target.GetPrediction,target,math.huge,.25)
        if not ok or not p or type(p.x)~='number' or type(p.z)~='number' or p.x~=p.x or p.z~=p.z then return false end
        local aim=i.destination or self.ctx.aim
        if i.locked and i.direction then aim={x=p.x+i.direction.x*1200,y=p.y,z=p.z+i.direction.z*1200} end
        if i.kind=='cursor' and self.ctx.config:get('aimLock')==3 then aim=self.ctx.aim end
        local endpoint=U.toward(p,aim,self.ctx.profile.kickDistance)
        if not self:aligned({pos=p},endpoint) then return false end
    end
    return true
end
function B:kickProtected(target)
    if target.spellShield==true or U.buff(target,P.kickBlocked,self.ctx:now()) then return true end
    if self.ctx.profile.id=='normal' and U.buff(target,{fioraw=true},self.ctx:now()) then return true end
    for _,buff in ipairs(U.buffs(target)) do
        if buff.type==4 and (buff.expireTime or buff.endTime or math.huge)>self.ctx:now() then return true end
    end
    return false
end
function B:wardFollowValid(p)
    if p.owner~='insec' then return true end
    local i=self.insec
    local r=self.ctx:spell(3)
    if not i or not self.ctx:enemyValid(i.target) or self:kickProtected(i.target)
        or not self:geometry(i) or (r.level or 0)==0 or (r.currentCd or 0)>0 then return false end
    -- Called immediately before W, including the fast ward-spawn callback.
    -- This closes the gap where the target moves before the ordinary tick.
    local from=p.target and p.target.pos or p.pos
    if (myHero.mana or 0)<(self.ctx:spell(1).mana or 0)+(self.ctx:spell(3).mana or 0) then return false end
    if self:aligned(i.target,i.endpoint,from) then return true end
    local plan=self.planner:adapt(i,i.plan)
    if self.planner:validate(i,plan,from,self.ctx:spell(1).mana or 0) then return true end
    -- Only when the cheap continuation check fails do we rebuild from the
    -- observed ward. This callback never executes another resource itself.
    i.plan=self.planner:plan(i,from,nil,self.ctx:spell(1).mana or 0)
    return i.plan~=nil
end
function B:insecTick()
    local c=self.ctx;local i=self.insec;if not i then return end
    if not c:enemyValid(i.target) then self:cancel('Target unavailable');return end
    if i.phase=='kick' then
        if i.event.status=='observed' or i.event.status=='completed' then
            i.event.status='completed';if c.config.capture then c:log('insec_completed',{target=U.id(i.target),request=i.event.id,
                evidence='R cast acknowledged; displacement assessed separately'}) end
            self.completedSerial=(self.completedSerial or 0)+1;self.insec=nil;return
        elseif (i.event.status=='unconfirmed' or i.event.status=='cancelled') and c:ready(3) then
            if c.config.capture then c:log('insec_kick_retry',{target=U.id(i.target)}) end;i.phase='replan';i.event=nil
        else return end
    end
    if c.input:previewHeld() and not i.preview then
        -- Already dispatched motion must settle. Alt pauses subsequent actions;
        -- it cannot retract a ward placement, dash or R that the game accepted.
        if c.wards.pending or c:dash() then i.resource='Waiting for current jump before preview';return end
        if i.flight then
            local f=i.flight
            if c:now()<=f.deadline and (U.dist(myHero.pos,f.origin)<=60
                or f.event and f.event.status~='observed' and f.event.status~='completed') then return end
            i.flight=nil
        end
        if i.qWait then
            if c:mark(i.qWait.unit) and c:stage(0)==2 then i.used.q=nil;i.qWait=nil
            elseif c:now()>i.qWait.deadline or not U.valid(i.qWait.unit) then i.qWait=nil
            else i.resource='Waiting for Q result before preview';return end
        end
        i.preview=true;i.contract=nil;i.flashConsent=false;i.search=nil;i.plan=nil;i.displayPlan=nil;i.confirmBlocked=nil;i.commitAt=nil
    end
    if i.preview then
        if c.input:previewHeld() then self:previewTick(i);return end
        self:confirmPreview()
    end
    if i.confirmBlocked then c.status=i.resource;return end
    if i.commitAt and c:now()-i.commitAt>c.config:get('insecTimeout') then self:cancel('Insec timeout');return end
    local r=c:spell(3)
    if (r.level or 0)==0 or (r.currentCd or 0)>0 then self:cancel('R cooldown / not learned');return end
    -- Native R castability is checked when R is issued. It must not discard
    -- a still-valid Q2 window while approaching or recovering from CC.
    local aim=self:geometry(i)
    if not aim then c.status='Aim away from the selected champion';return end
    if c:now()>=(i.traceAt or 0) then
        i.traceAt=c:now()+.25
        local buffs={};for _,buff in ipairs(U.buffs(i.target)) do
            if #buffs>=12 then break end
            buffs[#buffs+1]={name=buff.name,count=buff.count,expires=buff.expireTime,type=buff.type}
        end
        if c.config.capture then c:log('insec_state',{target=U.id(i.target),targetPos=U.copy(i.target.pos),origin=U.copy(myHero.pos),
             phase=i.phase,stand=U.copy(i.stand),endpoint=U.copy(i.endpoint),plan=i.resource,
             fallbackOrigin=U.copy(i.fallbackOrigin),recipient=U.id(i.recipient),recipientKind=i.recipientKind,
             used=i.used,qWaitTarget=i.qWait and U.id(i.qWait.unit),qReady=c:ready(0),qStage=c:stage(0),
             qState=Game.CanUseSpell(0),wState=Game.CanUseSpell(1),rState=Game.CanUseSpell(3),
            kickValid=self:kickValid(i),rReady=c:ready(3),wReady=c:ready(1),wStage=c:stage(1),
            wardSlot=c.wards:slot(),wardState=c.wards.pending and c.wards.pending.state,
            cursorStep=c.sdk.Cursor and c.sdk.Cursor.Step,targetBuffs=buffs,flashReason=i.flashReason}) end
    end
    if self:kickProtected(i.target) then
        i.orbwalking=true;i.plan=nil;i.resource='Waiting: spell shield / kick immunity';c.status=i.resource;return
    end
    c.status='Insec: '..i.phase..(i.locked and ' | AIM LOCKED' or ' | aiming')
    self.planner:tick(i,aim)
end
function B:kickHits(target,from)
    if not self.ctx:enemyValid(target) then return 0 end
    local endPos=U.toward(from or myHero.pos,target.pos,U.dist(from or myHero.pos,target.pos)+self.ctx.profile.kickDistance)
    local hits=1
    for _,e in ipairs(self.ctx.enemies or {}) do
        if self.ctx:enemyValid(e) and not U.same(e,target) then
            local d,t=U.segment(e.pos,target.pos,endPos)
            if t>0 and d<100+(e.boundingRadius or 65) then hits=hits+1 end
        end
    end
    return hits,endPos
end
function B:multi(target,allowReposition)
    local c=self.ctx
    if not c.config:get('comboR') or not c:ready(3) or c:combatTransit() or self.wards.pending then return false end
    if not c.config:get('multi') and not c.config:get('collateralKills') then return false end
    local now=c:now()
    if now<(self.kickSearchAt or 0) then return false end
    self.kickSearchAt=now+.08
    local plan=self.kicks:best(allowReposition~=false and now>=(self.wards.fightRetryAt or 0))
    if not plan then return false end
    self.kickProposal=plan
    if plan.ward then
        if not self:wardOpportunity(plan.primary,true) then return false end
        local function valid()
            if not self:wardOpportunity(plan.primary,true) then return false end
            local current=self.kicks:evaluate(plan.primary,plan.origin,true)
            return current and current.worthwhile and current.hits>=2 or false
        end
        if self.wards:start(plan.origin,'fight',true,nil,valid) then
            self.multiTarget={target=plan.primary,untilTime=now+1.5};if c.config.capture then c:log('fight_multikick_plan',{
                target=U.id(plan.primary),hits=plan.hits,estimatedKills=plan.kills,secondaryKills=plan.secondaryKills,
                origin=plan.origin,endpoint=plan.endpoint,confidence=c.config:get('mechanicsVerified') and 'measured profile' or 'profile estimate'}) end
            return true
        end
    elseif self:castFightR(plan.primary,true) then
        if c.config.capture then c:log('fight_multikick_cast',{target=U.id(plan.primary),hits=plan.hits,estimatedKills=plan.kills,
            secondaryKills=plan.secondaryKills,endpoint=plan.endpoint}) end;return true
    end
    return false
end
function B:defense()
    local c=self.ctx
    if not c.config:get('idleDefense') or self.wards.pending or self.insec or c:combatTransit() then return false end
    if c.config:get('reserveW') then return c.emergencyShield:tick() end
    local threatened=c:threats(myHero.pos,850)>0
    if c:stage(1)==1 and threatened and U.hp(myHero)<=c.config:get('shieldHP') then
        return self.spells:w(myHero,'defense',true)
    end
    if c:stage(1)==1 then
        for _,a in ipairs(c.allies or {}) do
            if U.hp(a)<=c.config:get('allyShieldHP') and c:threats(a.pos,700)>0 and not c:underTurret(a.pos)
                and U.dist(myHero.pos,a.pos)<=c.profile.wRange then return self.spells:w(a,'defense',true) end
        end
    end
    return false
end
function B:killsteal(inFight)
    local c=self.ctx;local lock=c:locked();local candidates={}
    if c:combatTransit() then return false end
    for _,target in ipairs(lock and {lock} or c.enemies or {}) do
        if c:enemyValid(target) then
            local distance=U.dist(myHero.pos,target.pos)
            local function hp(slot)return U.typedHP(target,slot==2 and 'magic' or 'physical')+c.config:get('combatDamageMargin')+(target.hpRegen or 0)*.8 end
            local function add(slot,stage,delay,cost)
                if (not inFight or c.config:get(slot==0 and stage==2 and 'comboQ2' or ({[0]='comboQ',[2]='comboE',[3]='comboR'})[slot]))
                    and c:ready(slot) and c:combatDamage(slot,target,stage)>=hp(slot) then
                    candidates[#candidates+1]={slot=slot,stage=stage,target=target,delay=delay,cost=cost}
                end
            end
            if c.config:get('killE') and c:stage(2)==1 and distance<=c.profile.eRange then add(2,1,.25,1) end
            if c.config:get('killQ') and c:stage(0)==1 and distance<=c.profile.qRange then add(0,1,.25+distance/c.profile.qSpeed,1) end
            if c.config:get('killQ2') and c:stage(0,target)==2 and c:mark(target) and distance<=c.profile.q2Range then add(0,2,.15+distance/1800,2) end
            if c.config:get('killR') and distance<=c.profile.rRange then add(3,1,.25,4) end
        end
    end
    table.sort(candidates,function(a,b)
        local aa,bb=math.floor(a.delay/.08+.5),math.floor(b.delay/.08+.5)
        if aa~=bb then return aa<bb end
        if a.cost~=b.cost then return a.cost<b.cost end
        return a.delay<b.delay
    end)
    for _,candidate in ipairs(candidates) do
        local t=candidate.target;local ok
        if candidate.slot==2 then ok=self.spells:e(t,'killsteal')
        elseif candidate.slot==3 then
            local policy=inFight and 'fight' or 'killsteal'
            if self:allowFinisherR(t,policy) then ok=self.spells:r(t,'killsteal',false,function()return self:allowFinisherR(t,policy)end) end
        elseif candidate.stage==2 then ok=self.spells:q2(t,'killsteal',false,true)
        else ok=self.spells:q1(t,'killsteal',false) end
        if ok then return true end
    end
    return false
end
function B:followAllowed(target)
    local c=self.ctx
    if not c.config:get('comboQ2') or not c.config:get('comboKickFollow') or not c:mark(target)
        or c:stage(0,target)~=2 or not c:ready(0) or c:markLeft(target)<math.max(.5,c.latency+.35)
        or (myHero.mana or 0)<(c:spell(0).mana or 0)+(c:spell(3).mana or 0) then return false end
    local _,endpoint=self:kickHits(target)
    return not c.config:get('q2Safety') or not c:underTurret(endpoint)
end
function B:cheapFinish(target,owner)
    local c=self.ctx
    if not c.config:get('comboConserveR') then return false,'conservation_disabled' end
    local result=self.tactics:assess(target,owner or 'fight')
    self.finishAssessment=result
    if result.lethal then
        local now=c:now();local promise=self.finishPromise
        if promise and promise.target==U.id(target) and target.health>=promise.health-.5 then
            if now>promise.untilTime then return false,'cheaper_plan_made_no_damage_progress' end
        else
            self.finishPromise={target=U.id(target),health=target.health,
                untilTime=now+result.lethal.t+c.latency+math.max(.08,c.jitter*2)}
        end
    else self.finishPromise=nil end
    return result.lethal~=nil,result.lethal and (result.lethal.path or 'observed_attack_lethal') or 'no_timely_cheaper_finish'
end
function B:allowFinisherR(target,owner)
    local c=self.ctx;local cheaper,reason=self:cheapFinish(target,owner)
    if c.config.capture then c:trace('r_finisher_decision',{target=U.id(target),name=target.charName,owner=owner,
        allowed=not cheaper,reason=reason,health=target.health,physicalHP=U.typedHP(target,'physical'),
        distance=U.dist(myHero.pos,target.pos),pendingAA=c:pendingAttackDamage(target,.25),
        aaDamage=c:aaDamage(target),qDamage=c:combatDamage(0,target,1),qReady=c:ready(0),qStage=c:stage(0,target),
        eReady=c:ready(2),eStage=c:stage(2),conserve=c.config:get('comboConserveR'),
        horizon=self.finishAssessment and self.finishAssessment.horizon,
        expansions=self.finishAssessment and self.finishAssessment.expanded,
        finishTime=self.finishAssessment and self.finishAssessment.lethal and self.finishAssessment.lethal.t},
        tostring(U.id(target))..':'..tostring(cheaper)..':'..tostring(reason),.4) end
    return not cheaper,cheaper and 'cheaper_finish_available' or nil
end
function B:castFightR(target,multiple,purpose)
    local c=self.ctx;purpose=multiple and 'multi' or purpose or 'execute'
    local follow=self:followAllowed(target)
    local function valid()
        if multiple then
            local plan=self.kicks:evaluate(target,myHero.pos,false)
            return plan and plan.hits>=2 and plan.worthwhile or false,'multi_no_longer_worthwhile'
        end
        if not self:allowFinisherR(target,'fight') then return false,'cheaper_finish_available' end
        local damage=c:combatDamage(3,target)
        if purpose=='follow' then
            if not self:followAllowed(target) then return false,'q2_follow_unavailable' end
            local after=math.max(0,target.health-math.max(0,damage-(target.allShield or 0)-(target.shieldAD or 0)))
            local burst=damage+c:combatDamage(0,target,2,after)>=U.typedHP(target,'physical')+15
            return burst or self:isolateUseful(target),'kick_follow_no_longer_useful'
        end
        return damage>=U.typedHP(target,'physical')+10,'r_no_longer_lethal'
    end
    local ok,event=self.spells:r(target,'fight',false,valid)
    if ok and follow then
        self.rFollow={target=target,event=event,untilTime=self.ctx:now()+math.min(2,self.ctx:markLeft(target)),
            targetOrigin=U.copy(target.pos),health=target.health}
    end
    if ok and c.config.capture then c:log('fight_kick_requested',{request=event.id,target=U.id(target),
        pos=U.copy(target.pos),purpose=purpose,health=target.health,physicalHP=U.typedHP(target,'physical'),
        rDamage=c:combatDamage(3,target),markLeft=c:markLeft(target),follow=follow,
        multiMinimum=multiple and c.config:get('multiHits') or nil}) end
    return ok,event
end
function B:followKick()
    local c=self.ctx;local f=self.rFollow;if not f then return false end
    local lock=c:locked()
    local active=myHero.activeSpell
    local q2Used=active and active.valid and U.name(active.name):find('leesinqtwo',1,true)
    if not c.config:get('comboQ2') or not c.config:get('comboKickFollow') or not c.config:get('comboR')
        or lock and not U.same(lock,f.target) or not c:enemyValid(f.target) or c:now()>f.untilTime
        or not c:mark(f.target) or q2Used or c:stage(0,f.target)~=2 or f.event.status=='unconfirmed' or f.event.cancelled then
        if c.config.capture then c:log('fight_kick_cancelled',{target=U.id(f.target),event=f.event.status}) end;self.rFollow=nil;return false
    end
    c.attackTarget=f.target
    if f.event.status=='observed' or f.event.status=='completed' then
        local moved=f.targetOrigin and U.dist(f.target.pos,f.targetOrigin)>60
        local elapsed=c:now()-(f.event.observedAt or f.event.at or c:now())
        -- Follow the confirmed kick before its full displacement puts Q2 out
        -- of range. Expiry is urgent, but never bypasses R acknowledgement.
        if moved or elapsed>=.25 or c:markLeft(f.target)<.4 then
            if self.spells:q2(f.target,'fight',false,true) then
                if c.config.capture then c:log('fight_kick_follow',{target=U.id(f.target),delay=elapsed,moved=moved,
                    distance=U.dist(myHero.pos,f.target.pos),markLeft=c:markLeft(f.target)}) end
                self.rFollow=nil
            end
        end
    end
    return true
end
function B:fastBurst(target)
    if not self.ctx.config:get('comboBurst') then return false end
    local horizon=self.tactics:window(target)
    local finish=self.tactics:assess(target,'fight',math.min(.8,horizon)).lethal
    return finish~=nil and finish.first~=nil and finish.first~='AA'
end
-- Draw callback can finish a confirmed ward landing without waiting for the
-- next expensive planning tick. No graph search and no uncancellable R queue.
function B:fastKick()
    local c=self.ctx;local i=self.insec
    if not i or i.preview or i.confirmBlocked or i.phase=='kick' or i.flight or i.qWait
        or c:blocked() or c:dash() or c.wards.pending or c.input:previewHeld()
        or not c.input:held(i.kind=='cursor' and 'cursorKey' or 'allyKey')
        or (c:spell(3).level or 0)==0 or not c:ready(3) or c.actions.pending[3]
        or i.commitAt and c:now()-i.commitAt>c.config:get('insecTimeout')
        or not U.valid(i.target) or U.dist(myHero.pos,i.target.pos)>c.profile.rRange then return false end
    if not self:geometry(i) or not self:kickValid(i) then return false end
    local ok,event=c.spells:r(i.target,'insec',true)
    if ok then i.phase='kick';i.event=event end
    return ok
end
function B:passiveHold(target)
    local c=self.ctx
    if not c.config:get('comboPassive') or not c.clear:weaving() or U.dist(myHero.pos,target.pos)>c:attackRange(target) then return false end
    local a=c.sdk.Attack;local cycle=a.GetAnimation and a:GetAnimation() or 1
    local wait=a.IsReady and not a:IsReady() and math.max(0,(a.ServerStart or c:now())+cycle-c:now()) or 0
    local impact=wait+c:windup()+c.latency*.5
    if impact>c.clear.passiveUntil-c:now() then return false end
    if c:mark(target) and impact+.65>=c:markLeft(target) then return false end
    if self:fastBurst(target) then return false end
    if target.GetPrediction and target.pathing and target.pathing.hasMovePath then
        local ok,p=pcall(target.GetPrediction,target,math.huge,impact)
        if not ok or not p or U.dist(myHero.pos,p)>c:attackRange(target) then return false end
    end
    return true
end
function B:chaseMotion(target)
    local now=self.ctx:now();local lock=0;local gg=_G.GGPrediction
    if gg and type(gg.GetImmobileDuration)=='function' then
        local ok,duration=pcall(gg.GetImmobileDuration,gg,target)
        if ok and U.finite(duration) then lock=math.max(0,duration) end
    else
        -- These types are defined by the installed GG runtime, in both maps.
        for _,buff in ipairs(U.buffs(target)) do
            if buff.type==5 or buff.type==12 or buff.type==25 or buff.type==30 or buff.type==35 then
                lock=math.max(lock,(U.buffEnd(buff) or now)-now)
            end
        end
    end
    local origin=U.copy(target.pos);local path=target.pathing
    local endpoint=path and path.hasMovePath and path.endPos
    local speed=U.finite(target.ms) and math.max(0,target.ms) or 0
    if not endpoint or not U.finite(endpoint.x) or not U.finite(endpoint.z) then speed=0;endpoint=origin end
    local length=U.dist(origin,endpoint)
    local function at(delay)
        return U.toward(origin,endpoint,math.min(length,speed*math.max(0,delay-lock)))
    end
    return at,lock,speed
end
function B:chaseDecision(target)
    local c=self.ctx;local at,lock,speed=self:chaseMotion(target)
    if target.pathing and target.pathing.isDashing then return false,nil,'Wait for enemy dash destination' end
    local ownSpeed=U.finite(myHero.ms) and math.max(1,myHero.ms) or 350
    local range=c:attackRange(target);local wait=c.config:get('comboWalkWait')/1000
    local arrival=self.tactics:wardArrival()
    local future=at(arrival);local distance=U.dist(myHero.pos,future)
    local landing=U.toward(myHero.pos,future,math.max(0,distance-math.min(100,range*.5)))
    local reason
    if c:underTurret(future) or c:underTurret(at(arrival+.6)) then reason='Target escaping into turret range'
    elseif U.dist(myHero.pos,landing)>self.wards:range() then reason='Predicted landing outside ward range'
    else
        local walkTime=math.huge
        -- A bounded local intercept estimate follows the current path and its
        -- endpoint. Recomputed before resource spending; no ground detour.
        local horizon=math.max(wait,arrival+c.config:get('comboWardGain')/1000)
        for n=1,16 do
            local dt=horizon*n/16
            if U.dist(myHero.pos,at(dt))<=range+ownSpeed*dt then walkTime=dt;break end
        end
        if walkTime<=wait then reason='Walking reaches attack range soon'
        elseif walkTime-arrival<c.config:get('comboWardGain')/1000 then reason='Wardjump saves too little time' end
        if c.config.capture then c:trace('combo_chase',{target=U.id(target),reason=reason or 'Ward saves approach time',
            ownSpeed=ownSpeed,targetSpeed=speed,immobile=lock,walkTime=walkTime<math.huge and walkTime or nil,
            arrival=arrival,landing=landing,future=future},tostring(U.id(target)),.4) end
    end
    return not reason,landing,reason
end
function B:gapclose(target)
    local c=self.ctx
    -- A blocked/temporarily reserved Q2 must not fall through to a ward entry.
    -- Preserving a marked Q for R-follow is an explicit optional playstyle.
    if not c.config:get('comboWardPreserveQ') and c:stage(0,target)==2 and c:mark(target) then return false end
    local flight,phase,remaining=self.spells:q1Reservation(target)
    if flight then
        if c.config.capture then c:trace('combo_chase',{target=U.id(target),reason=phase=='queued'
                and 'Q1 queued; preserve ward' or 'Wait for own Q1 impact before spending a ward',
            request=flight.event.id,phase=phase,remaining=remaining},tostring(U.id(target)),.4) end
        return false
    end
    if not c.config:get('comboWard') or not c.config:get('comboW') or not self.wards:available()
        or self.wards.pending or U.hp(myHero)<=c.config:get('shieldHP') then return false end
    local distance=U.dist(myHero.pos,target.pos);local stop=math.min(100,c:attackRange(target)*.5)
    if distance<=c:attackRange(target)+60 or distance-stop>self.wards:range() then return false end
    if c.config:get('comboChaseE2') and c.config:get('comboE2') and c:stage(2)==2 and c:ready(2)
        and c.spells:e(target,'fight') then return true end
    if not self:wardOpportunity(target,false) then return false end
    local allowed,landing=self:chaseDecision(target)
    if not allowed then return false end
    if c:underTurret(landing) or c.terrain:wall(landing)~=false then return false end
    return self.wards:start(landing,'fight',true,nil,function()
        if not self:wardOpportunity(target,false) or U.dist(myHero.pos,target.pos)<=c:attackRange(target)+60 then return false end
        local useful,newLanding=self:chaseDecision(target)
        return useful and U.dist(newLanding,landing)<100 and not c:underTurret(landing)
    end,function()
        -- The ward is already spent. Re-evaluating whether to buy that same
        -- approach again can strand the follow-up as soon as a slow expires.
        if not c:enemyValid(target) then return false,'Chase target unavailable' end
        if c:underTurret(landing) then return false,'Chase landing under turret' end
        local at=self:chaseMotion(target)
        local future=at(c.metrics.wardDashDuration or c.config:get('insecDashEstimate')/1000)
        if U.dist(landing,future)>c:attackRange(target)+60 then return false,'Chase target left ward landing' end
        if U.dist(myHero.pos,target.pos)<=c:attackRange(target) then return false,'Target already in attack range' end
        return true
    end)
end
function B:wardOpportunity(target,multiple)
    local c=self.ctx
    if c:combatTransit() or not c:enemyValid(target) or c:mark(target) then return false end
    if self.spells:q1Reservation(target) then return false end
    if not multiple and c.config:get('comboQ') and c:ready(0) and c:stage(0)==1 then
        local aim=self.spells:predict(target)
        if aim and #self.spells:blockers(target,aim)==0 and not self.spells:projectileWall(aim) then return false end
    end
    return true
end
function B:harass(owner)
    local c=self.ctx;owner=owner or 'harass'
    if c:combatTransit() or self.wards.pending then return false end
    local target=c:target(c.profile.qRange);if not target then return false end
    c.attackTarget=target
    if self:rotation(target,owner) then return true end
    if c.config:get('harassR') and not self:cheapFinish(target,owner) then return self.spells:r(target,owner) end
    return false
end
function B:rotation(target,owner,options)
    local horizon=self.tactics:window(target)
    options=options or {}
    local result=self.tactics:assess(target,owner,math.min(options.horizon or 1.5,horizon),options)
    local plan=result.lethal or result.best
    if not plan then
        -- The survival horizon limits committed melee/finisher sequences. A
        -- ranged poke can be launched now and finish travelling after we leave.
        -- Keep this fallback out of lethal-R comparisons and all gapclosers.
        if owner=='harass' and result.model and result.model.lookup.Q1 then
            self.spells:q1Status(target,owner,'harass_projectile_beyond_plan_horizon')
            return self.spells:q1(target,owner,false)
        end
        return false
    end
    if self.ctx.config.capture then self.ctx:trace('combat_plan',{owner=owner,target=U.id(target),
        path=plan.path,first=plan.first,finish=plan.hp<=0,time=plan.t,horizon=result.horizon,
        conditional=plan.conditional,estimated=result.estimated,expanded=result.expanded},tostring(U.id(target))..':'..tostring(plan.first),.5) end
    -- The orbwalker remains the sole AA dispatcher. Future actions are never
    -- enqueued as a fixed macro: observe and rebuild after each actual action.
    if not plan.first or plan.first=='AA' then return true end
    return self.tactics:cast(plan.first,target,owner)
end
function B:isolateUseful(target)
    if not self.ctx.config:get('comboIsolate') then return false end
    local _,endpoint=self:kickHits(target);local before,after=math.huge,math.huge
    for _,enemy in ipairs(self.ctx.enemies or {}) do
        if not U.same(enemy,target) and self.ctx:enemyValid(enemy) then
            before=math.min(before,U.dist(target.pos,enemy.pos));after=math.min(after,U.dist(endpoint,enemy.pos))
        end
    end
    return before<650 and after>before+300
end
function B:fight()
    local c=self.ctx;local target=c:target(c.profile.q2Range)
    local focus=c.attackFocus
    if focus and c:now()-focus.at<c:windup()+.1 and focus.selected==c:locked() and c:enemyValid(focus.target)
        and U.dist(myHero.pos,focus.target.pos)<=c.profile.q2Range then target=focus.target end
    c.attackTarget=target;c.moveTarget=c.aim
    if c:combatTransit() or self.wards.pending then return end
    if self:followKick() then return end
    if self.multiTarget then
        local continuation=self.kicks:evaluate(self.multiTarget.target,myHero.pos,false)
        if not c.config:get('comboR') or c:now()>self.multiTarget.untilTime or not continuation then self.multiTarget=nil
        elseif continuation.worthwhile and self:castFightR(self.multiTarget.target,true) then self.multiTarget=nil;return end
    end
    if self:killsteal(true) then return end
    if self:multi(target) then return end
    if not target then return end
    c.clear:observe()
    local lead=math.max(.3,c.latency*.5+c.jitter*2+.15)
    if c.config:get('comboQ2') and c:stage(0)==2 and c:mark(target) and c:markLeft(target)<lead then
        if self.spells:q2(target,'fight',false) then return end
    end
    for _,slot in ipairs({1,2}) do
        if c.config:get(slot==1 and 'comboW2' or 'comboE2') and c:stage(slot)==2 and c.clear.windows[slot]
            and c.clear.windows[slot]-c:now()<lead then
            local ok
            if slot==1 then ok=self.spells:w(myHero,'fight') else ok=self.spells:e(target,'fight') end
            if ok then return end
        end
    end
    local dist=U.dist(myHero.pos,target.pos)
    local weaving=self:passiveHold(target)
    if c.config:get('comboQ2') and c:stage(0)==2 and c:mark(target) then
        if c:combatDamage(0,target,2)>=U.effectiveHP(target)+10 and self.spells:q2(target,'fight',false,true) then return end
        if c.config:get('comboWardPreserveQ') and c.config:get('comboKickFollow') and c.config:get('comboR')
            and c:ready(3) and c:markLeft(target)>.8 and dist>c.profile.rRange and self:gapclose(target) then return end
        local rDamage=c:combatDamage(3,target)
        local afterR=math.max(0,target.health-math.max(0,rDamage-(target.allShield or 0)-(target.shieldAD or 0)))
        local burst=rDamage+c:combatDamage(0,target,2,afterR)>=U.effectiveHP(target)+15
        local tactical=not weaving and self:isolateUseful(target)
        if c.config:get('comboR') and c:ready(3) and dist<=c.profile.rRange
            and self:followAllowed(target) and (burst or tactical) then
            if not burst and c:markLeft(target)>1.2 and self:rotation(target,'fight',
                {excludeQ2=true,reserveEnergy=(c:spell(0).mana or 0)+(c:spell(3).mana or 0),horizon=c:markLeft(target)-.8}) then return end
            if self:castFightR(target,false,'follow') then return end
        end
    end
    if not weaving then
        if self:rotation(target,'fight') then return end
    end
    -- Offensive item actives also belong to Q1 / no-mark rotations and must
    -- not depend on reaching the old Q2-only branch.
    if c.actives:tick(target,'fight') then return end
    if c.config:get('comboR') and c:combatDamage(3,target)>=U.effectiveHP(target)+10 and self:castFightR(target) then return end
    if c.damageModel:castIgnite(target) then return end
    self:gapclose(target)
end
return B
