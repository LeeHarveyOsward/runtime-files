-- Read-only combat evidence. A cast acknowledgement is not proof of damage.
local U=require('lho.util')
local T={};T.__index=T
local function number(n)
    return type(n)=='number' and n==n and math.abs(n)<math.huge and n or nil
end
local function visible(u) return u and u.valid~=false and u.visible==true and u.pos~=nil end
local function position(u) return visible(u) and U.copy(u.pos) or nil end
local function active(u)
    local a=u and u.activeSpell
    if not a or not a.valid then return end
    return {name=a.name,startTime=number(a.startTime),endTime=number(a.endTime),target=number(a.target),
        placementPos=U.copy(a.placementPos),isAutoAttack=a.isAutoAttack}
end
function T.new(ctx) return setmetatable({ctx=ctx,units={},watches={},serial=0},T) end
function T:enabled() return self.ctx.config:get('combatLogging') and self.ctx.config:get('fileLogging') end
function T:safe(method,...)
    if not self:enabled() then
        if self.encounter or next(self.units) or next(self.watches) then self.units={};self.watches={};self.encounter=nil end
        return
    end
    if self.ctx:now()<(self.retryAt or 0) then return end
    local ok,err=pcall(self[method],self,...)
    if not ok then
        self.retryAt=self.ctx:now()+30
        -- Telemetry must never stop the controller or print per-frame errors.
        pcall(self.ctx.log,self.ctx,'combat_logging_error',{reason=tostring(err)})
    end
end
function T:begin(reason)
    if self.encounter then return end
    self.serial=self.serial+1
    self.encounter={id=self.serial,at=self.ctx:now(),lastNear=self.ctx:now(),loss={},healing={}}
    self.ctx:log('combat_begin',{encounter=self.serial,reason=reason,origin=U.copy(myHero.pos),
        attribution='Health changes are observed net changes, not attributed damage'})
end
function T:finish(reason)
    local e=self.encounter;if not e then return end
    self.ctx:log('combat_end',{encounter=e.id,duration=self.ctx:now()-e.at,reason=reason,
        observedHealthLoss=e.loss,observedHealing=e.healing,damageAttribution='unavailable'})
    self.encounter=nil
end
function T:champion(unit)
    for _,h in ipairs(self.ctx.heroes or {}) do if U.same(h,unit) then return true end end
    return U.same(unit,myHero) or false
end
function T:action(event,target)
    local c=self.ctx
    local enemy=self:champion(target) and target.team~=myHero.team
    if not enemy and event.owner~='insec' and event.owner~='fight' and not self.encounter then return end
    self:begin('Combat action')
    event.encounter=self.encounter.id
    self.encounter.lastNear=c:now()
    if #self.watches>=32 then
        local old=table.remove(self.watches,1)
        c:log('combat_action_result',{request=old.event.id,encounter=old.event.encounter,result='Observation capacity exceeded'})
    end
    local i=c.combat and c.combat.insec
    local endpoint=event.slot==3 and enemy and (i and i.endpoint or
        U.toward(myHero.pos,target.pos,U.dist(myHero.pos,target.pos)+c.profile.kickDistance))
    self.watches[#self.watches+1]={event=event,target=enemy and target or nil,origin=position(target),
        endpoint=U.copy(endpoint),hp=enemy and number(target.health),at=c:now(),
        wasMarked=enemy and c:mark(target)~=nil,maxDistance=0,lastStatus=event.status}
end
function T:watch(now)
    local c=self.ctx
    for n=#self.watches,1,-1 do
        local w=self.watches[n];local e=w.event;local t=w.target
        if e.status~=w.lastStatus then
            c:log('combat_action_state',{request=e.id,encounter=e.encounter,owner=e.owner,slot=e.slot,
                stage=e.stage,target=e.target,status=e.status,delay=now-e.at,cancelled=e.cancelled or false,insecAttempt=e.insecAttempt})
            w.lastStatus=e.status
        end
        if t then
            if not visible(t) then w.visibilityGap=true
            else
                w.lastPos=U.copy(t.pos);w.lastHP=number(t.health);w.dead=t.dead or (w.lastHP or 1)<=0
                if e.slot==0 and e.stage==1 and not w.wasMarked and c:mark(t) then w.markObserved=true end
                if e.slot==3 and (e.observedAt or e.status=='completed') and w.origin then
                    local distance=U.dist(w.origin,t.pos)
                    if distance>w.maxDistance then w.maxDistance=distance;w.furthest=U.copy(t.pos) end
                end
            end
        end
        if now-w.at>=1.6 or e.status=='unconfirmed' or e.status=='rejected' then
            local result='Cast state only; impact unverified';local angle
            if e.status=='unconfirmed' or e.status=='rejected' then result='Cast unconfirmed'
            elseif w.visibilityGap then result='Target visibility gap; impact unverified'
            elseif w.markObserved then result='New Q mark observed; source association only'
            elseif e.slot==3 and w.origin and w.endpoint then
                local a,b=w.furthest or w.origin,w.endpoint
                local dx,dz=a.x-w.origin.x,a.z-w.origin.z
                local ex,ez=b.x-w.origin.x,b.z-w.origin.z
                local length=math.sqrt((dx*dx+dz*dz)*(ex*ex+ez*ez))
                if length>0 then angle=math.deg(math.acos(U.clamp((dx*ex+dz*ez)/length,-1,1))) end
                if w.dead then result='Target death observed; kick completion unverified'
                elseif w.maxDistance>=200 and angle and angle<=20 then result='Displacement consistent with intended kick'
                else result='Intended kick displacement not observed' end
            end
            c:log('combat_action_result',{request=e.id,encounter=e.encounter,owner=e.owner,name=e.name,
                slot=e.slot,stage=e.stage,target=e.target,result=result,status=e.status,cancelled=e.cancelled or false,insecAttempt=e.insecAttempt,
                origin=w.origin,expectedEndpoint=w.endpoint,lastObservedPos=w.lastPos,furthestObservedPos=w.furthest,
                displacement=w.maxDistance,directionErrorDegrees=angle,visibilityGap=w.visibilityGap or false,
                healthBefore=w.hp,lastObservedHealth=w.lastHP,damageAttribution='unavailable'})
            table.remove(self.watches,n)
        end
    end
end
function T:sample(unit,now,includeBuffs)
    local c=self.ctx;local id=U.id(unit);if not id then return end
    local old=self.units[id] or {};local seen=visible(unit) or U.same(unit,myHero)
    if not seen then
        if old.visible then c:log('champion_lost',{target=id,name=unit.charName,lastSeenAt=old.at,lastSeenPos=old.pos}) end
        old.visible=false;self.units[id]=old
        return {id=id,name=unit.charName,team=unit.team,visible=false,lastSeenAt=old.at,lastSeenPos=old.pos}
    end
    local hp=number(unit.health);local pos=U.copy(unit.pos)
    local dead=unit.dead==true or hp~=nil and hp<=0
    local spell=active(unit)
    local mark=c:mark(unit)~=nil
    local row={id=id,name=unit.charName,team=unit.team,visible=true,pos=pos,hp=hp,maxHP=number(unit.maxHealth),
        dead=dead,targetable=unit.isTargetable,isImmortal=unit.isImmortal,controllerEligible=c:enemyValid(unit),
        allShield=number(unit.allShield),physicalShield=number(unit.shieldAD),
        magicShield=number(unit.shieldAP),marked=mark,markLeft=mark and c:markLeft(unit) or nil,activeSpell=spell}
    if self.encounter and U.dist(myHero.pos,unit.pos)<2000 and (includeBuffs~=false or not old.visible) then
        row.buffs={}
        for _,b in ipairs(U.buffs(unit)) do
            if #row.buffs>=24 then break end
            if b.name~='' then row.buffs[#row.buffs+1]={name=b.name,count=number(b.count),
                expires=number(U.buffEnd(b)),buffType=number(b.type),source=number(b.sourcenID or b.sourceID)} end
        end
    end
    if not old.visible then c:log('champion_seen',row) end
    if old.visible and now-(old.at or 0)<=.35 then
        if hp and old.hp and math.abs(hp-old.hp)>=.01 then
            local delta=hp-old.hp;local e=self.encounter
            if e then
                local sums=delta<0 and e.loss or e.healing;sums[tostring(id)]=(sums[tostring(id)] or 0)+math.abs(delta)
                c:log('combat_health_delta',{encounter=e.id,target=id,name=unit.charName,before=old.hp,after=hp,
                    delta=delta,interval=now-old.at,pos=pos,allShield=row.allShield,
                    damageAttribution='unavailable; includes other sources and simultaneous healing'})
            end
        end
        if dead~=old.dead then c:log('champion_life_state',{target=id,name=unit.charName,dead=dead,pos=pos,hp=hp}) end
        if mark~=old.mark then c:log('combat_mark',{target=id,name=unit.charName,marked=mark,pos=pos,markLeft=row.markLeft}) end
    elseif old.visible and dead~=old.dead then
        c:log('champion_life_state',{target=id,name=unit.charName,dead=dead,pos=pos,hp=hp,observationGap=true})
    end
    local signature=spell and tostring(spell.name)..':'..tostring(spell.startTime)..':'..tostring(spell.target)
    if signature and signature~=old.spell and (self.encounter or U.same(unit,myHero)) then
        c:log('combat_native_spell',{source=id,name=unit.charName,spell=spell,pos=pos,
            evidence='Native active spell; not proof of hit or script ownership'})
    end
    self.units[id]={visible=true,hp=hp,pos=pos,at=now,dead=dead,mark=mark,spell=signature}
    return row
end
function T:tick()
    local c=self.ctx;local now=c:now()
    if now<(self.nextAt or 0) then return end
    local near=false
    for _,h in ipairs(c.heroes or {}) do
        if h.team~=myHero.team and visible(h) and not h.dead and U.dist(myHero.pos,h.pos)<2000 then near=true;break end
    end
    if near or c.combat.insec or c.mode=='fight' then
        self:begin('Visible enemy nearby / combat mode');self.encounter.lastNear=now
    elseif self.encounter and now-self.encounter.lastNear>5 and #self.watches==0 then self:finish('No nearby visible enemy / combat action') end
    self.nextAt=now+(self.encounter and .1 or .5)
    local rows={};local ownIncluded=false;local present={}
    for _,h in ipairs(c.heroes or {}) do
        if #rows>=16 then break end
        local row=self:sample(h,now,now>=(self.frameAt or 0));if row then rows[#rows+1]=row end
        if U.id(h) then present[U.id(h)]=true end
        if U.same(h,myHero) then ownIncluded=true end
    end
    if not ownIncluded then rows[#rows+1]=self:sample(myHero,now,now>=(self.frameAt or 0)) end
    present[U.id(myHero)]=true
    for id,old in pairs(self.units) do
        if not present[id] then
            if old.visible then c:log('champion_lost',{target=id,lastSeenAt=old.at,lastSeenPos=old.pos,reason='Absent from object enumeration'}) end
            self.units[id]=nil
        end
    end
    self:watch(now)
    if now>=(self.frameAt or 0) then
        self.frameAt=now+(self.encounter and .25 or 1)
        local slots={}
        for slot=0,5 do local s=c:spell(slot);slots[tostring(slot)]={name=s.name,rank=s.level,cd=s.currentCd,mana=s.mana,
            ammo=s.ammo,nativeState=Game.CanUseSpell(c:spellSlot(slot))} end
        c:log('combat_frame',{encounter=self.encounter and self.encounter.id,champions=rows,mode=c.mode,
            autosmite=c.config:get('autosmite'),smiteDecision=c.smite.decision,
            selected=U.id(c:locked()),attackTarget=U.id(c.attackTarget),aim=U.copy(c.aim),energy=myHero.mana,
            passive=c:passive(),spells=slots,cursorStep=c.sdk.Cursor and c.sdk.Cursor.Step,
            insecPhase=c.combat.insec and c.combat.insec.phase,plan=c.combat.insec and c.combat.insec.resource})
    end
end
function T:postAttack()
    if not self.encounter then return end
    self.ctx:log('combat_attack_finished',{activeSpell=active(myHero),origin=U.copy(myHero.pos),
        selected=U.id(self.ctx:locked()),evidence='GG post-attack callback; damage recipient unconfirmed'})
end
function T:shutdown()
    for _,w in ipairs(self.watches) do
        self.ctx:log('combat_action_result',{request=w.event.id,encounter=w.event.encounter,
            result='Observer unloaded before outcome',status=w.event.status})
    end
    self.watches={};self:finish('Plugin unloaded')
end
return T
