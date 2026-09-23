local U=require('lho.util')
local P=require('lho.profiles')
local R={}; R.__index=R
function R.new(profile,config)
    return setmetatable({profile=profile,config=config,sdk=_G.SDK,events={},cacheAt=-1,latency=.05,
        jitter=0,selected=nil,mode='idle',synthetic=false,injected={},status='Idle',verification={},metrics={}},R)
end
function R:now() return Game.Timer() end
function R:playerPosition()
    if self.sdk.Actions and self.sdk.Actions.GetPlayerPosition then return self.sdk.Actions:GetPlayerPosition() end
    return self.sdk.Input and self.sdk.Input:GetPlayerPosition() or U.copy(mousePos or self.aim or myHero.pos)
end
function R:log(kind,fields)
    if not self.config:get('fileLogging') and not self.config:get('diagnostics') then return end
    local event=fields or {};event.kind=kind;event.time=self:now()
    self.traceSession=self.traceSession or (P.build..'@'..string.format('%.3f',event.time)..':'..tostring(GetTickCount and GetTickCount() or 0))
    self.traceSequence=(self.traceSequence or 0)+1
    event.session=self.traceSession;event.sequence=self.traceSequence
    event.encounter=event.encounter or (self.telemetry and self.telemetry.encounter and self.telemetry.encounter.id)
    if kind=='insec_started' then self.insecSerial=(self.insecSerial or 0)+1;self.insecTrace=self.insecSerial end
    if kind:find('insec',1,true) or event.owner=='insec' then event.insecAttempt=event.insecAttempt or self.insecTrace end
    event.tickMs=GetTickCount and GetTickCount() or nil
    self.events[#self.events+1]=event
    if #self.events>512 then table.remove(self.events,1) end
    if not self.logger then self.logger=require('lho.logger').new(self) end
    self.logger:record(event)
    if kind=='insec_cancelled' or kind=='insec_completed' then self.insecTrace=nil end
    if self.config:get('diagnostics') then print('[LHO] '..kind..' '..tostring(event.reason or event.name or '')) end
end
function R:chatOpen()
    if self.sdk.Input and self.sdk.Input.IsChatOpen then return self.sdk.Input:IsChatOpen() end
    return Game.IsChatOpen and Game.IsChatOpen() or false
end
function R:blocked()
    return not self.config:get('enabled') or myHero.dead or self:chatOpen()
        or (Game.IsOnTop and not Game.IsOnTop())
end
function R:recalling()
    if self.sdk.IsRecalling then return self.sdk.IsRecalling(myHero) end
    return U.buff(myHero,{recall=true,recallimproved=true},self:now())~=nil
end
function R:refresh()
    local now=self:now()
    if now<(self.cacheAt or 0)+.08 then return end
    self.cacheAt=now
    local ms=Game.Latency and Game.Latency() or 50
    if type(ms)=='number' and ms>=0 and ms<=2000 then
        local sample=ms/1000
        self.jitter=self.jitter*.8+math.abs(sample-self.latency)*.2
        self.latency=self.latency*.8+sample*.2
    end
    self.heroes={};self.enemies={};self.allies={};self.minions={};self.wardObjects={};self.turrets={};self.camps={}
    for _,entry in ipairs({{'Hero','heroes'},{'Minion','minions'},{'Ward','wardObjects'},{'Turret','turrets'},{'Camp','camps'}}) do
        local shared=self.sdk.SharedData
        local kind=entry[2]=='wardObjects' and 'wards' or entry[2]
        local snapshot=shared and shared:GetObjects(kind)
        if snapshot and snapshot.ageMs<=80 then self[entry[2]]=snapshot.objects
        else
            local count,get=Game[entry[1]..'Count'],Game[entry[1]]
            if count and get then for i=1,U.count(count(),entry[1]=='Minion' and 4096 or 512) do
                local unit=get(i);if unit then self[entry[2]][#self[entry[2]]+1]=unit end
            end end
        end
    end
    local monsters={}
    for _,m in ipairs(self.minions) do if m.team==300 and P.jungleEntity(m) then monsters[#monsters+1]=m end end
    self.monsterCache={source=self.minions,units=monsters}
    for _,h in ipairs(self.heroes) do
        if U.valid(h) and not U.same(h,myHero) then
            local list=h.team==myHero.team and self.allies or self.enemies;list[#list+1]=h
        end
    end
end
function R:spellSlot(slot)
    -- Inventory positions are 6..12; native spell-slot constants are a
    -- separate API. Do not assume ITEM_1..ITEM_7 equal those positions.
    return slot>=6 and slot<=12 and (_G['ITEM_'..(slot-5)] or slot) or slot
end
function R:spell(slot) return myHero:GetSpellData(self:spellSlot(slot)) or {} end
function R:stage(slot,markedTarget,sampledSpell)
    local spell=sampledSpell or self:spell(slot);local name=U.name(spell.name)
    if slot==0 and (name=='leesinqone' or name=='leesinqmanager' or name=='leesinqoneability') then
        local scope=U.buffScopeKey();local cached=self.qStageCache
        if scope and cached and cached.scope==scope and cached.name==name and cached.toggle==spell.toggleState
            and cached.minions==self.minions and cached.enemies==self.enemies then
            if cached.stage~=2 and U.valid(markedTarget) and self:mark(markedTarget,name) then cached.stage=2 end
            return cached.stage
        end
        local function resolved(stage)
            if scope then self.qStageCache={scope=scope,name=name,toggle=spell.toggleState,
                minions=self.minions,enemies=self.enemies,stage=stage} end
            return stage
        end
        if U.valid(markedTarget) and self:mark(markedTarget,name) then return resolved(2) end
        for _,list in ipairs({self.minions or {},self.enemies or {}}) do
            for _,unit in ipairs(list) do
                if unit.team~=myHero.team and U.valid(unit) and self:mark(unit,name) then return resolved(2) end
            end
        end
        local fallback=name=='leesinqmanager' and (spell.toggleState==2 and 2 or spell.toggleState==1 and 1 or 0)
            or name=='leesinqone' and spell.toggleState==2 and 2 or 1
        return resolved(fallback)
    end
    if slot==0 and (name=='leesinqone' or name=='leesinqmanager') and spell.toggleState==2 then return 2 end
    if slot==0 and name=='leesinqmanager' and spell.toggleState==1 then return 1 end
    if name:find('two',1,true) or name:match('[qwe]2$') or name=='ironwill' or name=='cripple' then return 2 end
    if name:find('one',1,true) or name:match('[qwe]1$') or name=='safeguard' or name=='tempest' then return 1 end
    return 0
end
function R:ready(slot)
    local d=self:spell(slot)
    if slot>=6 and (d.currentCd or 0)>0 then return false end
    return (slot>3 or (d.level or 0)>0) and (d.mana or 0)<=(myHero.mana or 0) and Game.CanUseSpell(self:spellSlot(slot))==0
end
function R:mark(unit,spellName)
    local mark=U.buff(unit,P.qMarks,self:now(),U.id(myHero))
    if not mark and myHero.handle and myHero.handle~=U.id(myHero) then mark=U.buff(unit,P.qMarks,self:now(),myHero.handle) end
    -- Recorded in both runtimes: the active QOne debuff's sourcenID equals
    -- the monster's ID, not Lee's. Accept that representation only while our
    -- own slot explicitly exposes QTwo, and only for an unambiguous target.
    -- Foreign caster IDs retain the existing ownership rule.
    if not mark and U.name(spellName or self:spell(0).name)=='leesinqtwo' then
        local function recipientMark(target)
            local b=U.buff(target,{leesinqone=true},self:now(),U.id(target))
            local source=b and (b.sourcenID and b.sourcenID~=0 and b.sourcenID or b.sourceID)
            return b and source==U.id(target) and b or nil
        end
        mark=recipientMark(unit)
        if mark then
            local scan=self.recipientMarkScan;local id=U.id(unit)
            if scan and scan.at==self:now() and scan.target==id then return not scan.ambiguous and mark or nil end
            local ambiguous=false
            for _,list in ipairs({self.minions or {},self.enemies or {}}) do
                for _,other in ipairs(list) do
                    if U.valid(other) and not U.same(other,unit) and recipientMark(other) then ambiguous=true;break end
                end
                if ambiguous then break end
            end
            self.recipientMarkScan={at=self:now(),target=id,ambiguous=ambiguous}
            if ambiguous then return nil end
        end
    end
    return mark
end
function R:trace(kind,fields,key,interval)
    local persistent=self.config:get('combatLogging') and (fields and (fields.owner=='autosmite' or fields.owner=='insec' or fields.owner=='fight')
        or kind:match('^smite_') or kind:match('^insec_') or kind:match('^combo_'))
    if not persistent and (not self.config:get('playtestLogging') or self.playtestState=='finished') then return end
    self.traceLimits=self.traceLimits or {};key=kind..':'..tostring(key or '')
    if self:now()<(self.traceLimits[key] or 0) then return end
    self.traceLimits[key]=self:now()+(interval or 1);self:log(kind,fields)
end
function R:markLeft(unit)
    local b=self:mark(unit)
    return b and math.max(0,(U.buffEnd(b) or (self:now()+.2))-self:now()) or 0
end
function R:passive() return self.clear and self:now()<self.clear.passiveUntil and self.clear.passiveLeft or 0 end
function R:dash() return myHero.pathing and myHero.pathing.isDashing end
function R:combatTransit()
    local now=self:now();local active=myHero.activeSpell
    if self:dash() then self.combatDashActive=true;return true end
    if self.combatDashActive then self.combatDashActive=nil;self.combatDashEndedAt=now end
    if active and active.valid and U.name(active.name):find('leesinqtwo',1,true)
        and U.finite(active.startTime) and active.startTime>(self.combatDashEndedAt or -math.huge)
        and now-active.startTime>=0 and now-active.startTime<.8 then return true end
    local press=self.manualSpells and self.manualSpells[0]
    -- Bridge the physical-Q2 to native-dash acknowledgement gap, without
    -- treating an unacknowledged press as an indefinitely active dash.
    return press and press.before and press.before.stage==2 and press.at>(self.combatDashEndedAt or -math.huge)
        and now-press.at>=0 and now-press.at<.20 or false
end
function R:abilityEnabled(slot,stage,owner,target,abilityPolicy)
    local jungleW=slot==1 and (U.same(target,myHero) or stage==2 and target==nil)
        and (owner=='farm' and abilityPolicy=='autoClear' or owner=='clear' and abilityPolicy=='jungle')
    if slot==1 and self.config:get('reserveW') and not jungleW then
        -- Controller policy: explicit mobility owns W, ordinary rotations do not.
        if owner=='defense' then return stage==1 and U.same(target,myHero) end
        if owner~='ward' and owner~='insec' and owner~='escape' then return false end
        if stage~=1 or owner=='escape' and (not target or U.same(target,myHero)) then return false end
    end
    local mode=owner
    if owner=='expiry' or owner=='defense' or owner=='killsteal' then mode=self.mode end
    local prefix=mode=='fight' and 'combo' or mode=='harass' and 'harass'
    if prefix and slot>=0 and slot<=3 then
        local key=({[0]='Q',[1]='W',[2]='E',[3]='R'})[slot]
        if not self.config:get(prefix..key..(stage==2 and '2' or '')) then return false end
    end
    if slot==0 and stage==1 and self.config:get('qOnlySelected') and target and target.type==myHero.type and target.team~=300
        and target.team~=myHero.team and mode~='insec' and mode~='farm' then
        local selector=self.sdk.TargetSelector;local selected=selector and selector.Selected or self.selected
        if not U.same(target,selected) then return false end
    end
    return true
end
function R:pendingAttackDamage(target,delay)
    local active=myHero.activeSpell;local now=self:now()
    if not target or not active or not active.valid or active.isStopped then return 0 end
    local name=U.name(active.name)
    if not active.isAutoAttack and not name:find('basicattack',1,true) and not name:find('critattack',1,true) then return 0 end
    local id=active.target
    if not id or id==0 or id~=target.handle and id~=target.networkID then return 0 end
    local finish=active.castEndTime;local start=active.startTime
    if not U.finite(finish) or not U.finite(start) or start>now or finish<start or finish-start>1.5
        or finish>now+delay or now>finish+math.min(.12,self.latency*.5+.06) then return 0 end
    local attack=self.finishingAttack
    if not attack or attack.start~=start or attack.target~=U.id(target) then
        attack={start=start,target=U.id(target),health=target.health};self.finishingAttack=attack
    end
    -- Once damage is visible, never subtract that auto again from remaining HP.
    if target.health<attack.health-.5 then return 0 end
    return math.max(0,self:aaDamage(target)),math.max(0,finish-now)
end
function R:attackFinishesBefore(target,delay)
    return target and self:pendingAttackDamage(target,delay)>=U.typedHP(target,'physical')+5 or false
end
function R:attackRange(target)
    if self.sdk.Data and self.sdk.Data.GetAutoAttackRange then return self.sdk.Data:GetAutoAttackRange(myHero,target) end
    return (myHero.range or 125)+(myHero.boundingRadius or 65)+(target and target.boundingRadius or 0)
end
function R:jungleQ2Range(target)
    return math.min(self.profile.q2Range,self:attackRange(target)*U.clamp(self.config:get('jungleQ2RangeScale') or 2,1,4))
end
function R:windup()
    return self.sdk.Attack and self.sdk.Attack.GetWindup and self.sdk.Attack:GetWindup() or .25
end
function R:healthAt(target,delay)
    local hp=self.sdk.HealthPrediction
    if hp and hp.GetPrediction then
        local ok,value=pcall(hp.GetPrediction,hp,target,math.max(0,delay))
        if ok and type(value)=='number' and value==value and value>-math.huge and value<math.huge then return value end
    end
    return target.health or 0
end
function R:aaDamage(target)
    local d=self.sdk.Damage
    if d and d.GetAutoAttackDamage then return d:GetAutoAttackDamage(myHero,target,true) end
    return (myHero.totalDamage or 0)*100/(100+math.max(0,target.armor or 0))
end
function R:damage(slot,target,stage,healthOverride)
    if not self.config:get('mechanicsVerified') and not self.profile.damageVerified then return 0 end
    return self:spellDamageEstimate(slot,target,stage,healthOverride)
end
function R:combatDamage(slot,target,stage,healthOverride)
    local damage=self:damage(slot,target,stage,healthOverride)
    if self.config:get('mechanicsVerified') or self.profile.damageVerified then return damage end
    if self.config:get('combatEstimates') and self:enemyValid(target) then
        -- Deliberately separate from objective/Smite guaranteed damage.
        return self:spellDamageEstimate(slot,target,stage,healthOverride)*.9
    end
    return 0
end
function R:spellDamageEstimate(slot,target,stage,healthOverride)
    local p=self.profile;local rank=self:spell(slot).level or 0
    if rank==0 then return 0 end
    local bonus=myHero.bonusDamage or math.max(0,(myHero.totalDamage or 0)-(myHero.baseDamage or 0))
    local raw,dtype=0,self.sdk.DAMAGE_TYPE_PHYSICAL
    if slot==0 then
        raw=(p.qBase[rank] or 0)+p.qRatio*bonus
        if stage==2 then
            local missing=math.max(0,(target.maxHealth or 0)-(healthOverride or target.health or 0))
            if p.id=='classic' then raw=raw+missing*.08
            else raw=raw*(1+missing/math.max(1,target.maxHealth or 1)) end
            -- Never count an unmeasured monster execute amplification as guaranteed.
            if target.team==300 then raw=(p.qBase[rank] or 0)+p.qRatio*bonus end
        end
    elseif slot==2 then raw=(p.eBase[rank] or 0)+p.eRatio*(p.id=='normal' and (myHero.totalDamage or 0) or bonus);dtype=self.sdk.DAMAGE_TYPE_MAGICAL
    elseif slot==3 then raw=(p.rBase[rank] or 0)+p.rRatio*bonus end
    if slot==0 and target.team==300 then
        local cap=self.config:get('monsterQCap')
        if not cap or cap<=0 then return 0 end
        raw=math.min(raw,cap)
    end
    if self.sdk.Damage and self.sdk.Damage.CalculateDamage then
        return self.sdk.Damage:CalculateDamage(myHero,target,dtype,raw,true,slot==3)
    end
    local resist=dtype==self.sdk.DAMAGE_TYPE_MAGICAL and (target.magicResist or 0) or (target.armor or 0)
    return raw*(resist>=0 and 100/(100+resist) or 2-100/(100-resist))
end
function R:enemyValid(target)
    if not U.valid(target) or target.team==myHero.team or target.team==300 then return false end
    local now=self:now()
    if U.buff(target,P.immortal,now) then return false end
    -- The host may flag a ready resurrection as immortal. GG explicitly
    -- distinguishes willrevive from active invulnerability. A living,
    -- targetable carrier is still a combat target; an unknown flag stays gated.
    if target.isImmortal and not U.buff(target,P.reviveReady,now) then return false end
    return true
end
function R:locked()
    local selector=self.sdk.TargetSelector
    local target
    if selector and selector.GetSelectedTarget then target=selector:GetSelectedTarget()
    elseif selector and selector.GetTarget then target=selector.Selected else target=self.selected end
    if selector and selector.GetTarget and selector.MenuCheckSelected and not selector.MenuCheckSelected:Value() then return nil end
    if not self.selectionOwned and not target and not (selector and selector.GetSelectedTarget) then target=selector and selector.Selected end
    if target and (target.dead or (target.health or 0)<=0) then self.selected=nil;return nil end
    return target
end
function R:target(range)
    local selector=self.sdk.TargetSelector
    if selector and selector.GetTarget then
        local target=selector:GetTarget(range,self.sdk.DAMAGE_TYPE_PHYSICAL or 1,false)
        return self:enemyValid(target) and U.dist(myHero.pos,target.pos)<=range and target or nil
    end
    local lock=self:locked()
    if lock then return self:enemyValid(lock) and U.dist(myHero.pos,lock.pos)<=range and lock or nil end
    local best,score=nil,math.huge
    for _,e in ipairs(self.enemies or {}) do
        if self:enemyValid(e) and U.dist(myHero.pos,e.pos)<=range then
            local mouseDistance=U.dist(self.aim,e.pos)
            local value=U.effectiveHP(e)/math.max(1,self:aaDamage(e)) + U.dist(myHero.pos,e.pos)/100
            if mouseDistance<300 then value=value-30+mouseDistance/20 end
            if value<score then best,score=e,value end
        end
    end
    return best
end
function R:underTurret(pos)
    for _,t in ipairs(self.turrets or {}) do
        if t.team~=myHero.team and not t.dead and U.dist(pos,t.pos)<(t.boundingRadius or 80)+775+(myHero.boundingRadius or 65) then return true end
    end
    return false
end
function R:threats(pos,range)
    local count=0
    for _,e in ipairs(self.enemies or {}) do if U.dist(e.pos,pos)<range then count=count+1 end end
    return count
end
function R:snapshot(telemetry)
    local out={mode=self.profile.id,patch=P.version,build=P.build,hero=myHero.charName,map=Game.mapID,latency=self.latency,
        spell={},items={},buffs={},camps={},config={},verification=self.verification,events=not telemetry and self.events or nil,metrics=self.metrics,
        controllerMode=self.mode,status=self.status,
        logs={main=self.logFile,combat=self.combatLogFile,journal=self.eventLogFile}}
    if not telemetry and self.sdk.Input then
        out.orbama=self.sdk.Input:GetDiagnostics()
        out.orbamaPerformance=self.sdk.Performance and self.sdk.Performance:Snapshot()
        out.droppedBufferedLogs=self.logger and self.logger.dropped or 0
    end
    local ward=self.wards and self.wards.pending
    if ward then out.wardState={state=ward.state,pos=U.copy(ward.pos),target=U.id(ward.target),
        requestedAt=ward.at,observedAt=ward.observed,waitReason=ward.waitReason,deadline=ward.deadline} end
    if self.clear then out.clearState={stages=self.clear.stages,windows=self.clear.windows,
        passiveLeft=self.clear.passiveLeft,passiveUntil=self.clear.passiveUntil,lastCast=self.clear.lastCast,
        sustainUntil=self.clear.sustainUntil} end
    local lock=self:locked()
    if not telemetry and self.damageModel and self:enemyValid(lock) then
        local safe,max=self.damageModel:both(lock);out.damageEstimate={target=U.id(lock),conservative=safe,maximum=max}
    end
    for key in pairs(self.config.values) do
        out.config[key]=(key:match('Key$')) and self.config:key(key) or self.config:get(key)
    end
    for slot=0,12 do
        local d=self:spell(slot);out.spell[slot]={name=d.name,rank=d.level,range=d.range,ammo=d.ammo,cd=d.currentCd,
            mana=d.mana,toggle=d.toggleState,stage=slot<3 and self:stage(slot) or nil,
            nativeSlot=self:spellSlot(slot),useState=Game.CanUseSpell(self:spellSlot(slot))}
        if slot>=6 then local item=myHero:GetItemData(slot);out.items[slot]=item and {id=item.itemID,stacks=item.stacks,stackCount=item.stackCount,ammo=item.ammo} end
    end
    for _,b in ipairs(U.buffs(myHero)) do out.buffs[#out.buffs+1]={name=b.name,count=b.count} end
    for _,c in ipairs(self.camps or {}) do out.camps[#out.camps+1]={name=c.name,pos=U.copy(c.pos),up=c.isCampUp,visible=c.visible} end
    return out
end
return R
