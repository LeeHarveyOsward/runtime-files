local U=require('tf.util')
local P=require('CombatProfiles.twisted_fate')
local Planner=require('tf.planner')
local C={};C.__index=C
function C.new(c)return setmetatable({c=c},C)end
function C:packet(target,color,eReady,index,hp)
    local c=self.c;local sdk=c.sdk;local crit=P.CritMultiplier(c.profile,c.state.inventory.slots)
    local raw=P.Attack(c.profile,c.hero,c.state.spells[1].level,c.state.spells[2].level,color,eReady,target.type==Obj_AI_Turret,crit)
    local charge=c.state:buff(c.hero,'itemstatikshankcharge')
    local extra=P.ItemAttack(c.profile,c.hero,{health=hp or target.health,minion=target.type==Obj_AI_Minion,hero=target.type==Obj_AI_Hero},
        c.state.inventory.slots,{energized=(index or 0)==0 and P.AliveBuff(charge,Game.Timer()) and charge.stacks==100})
    if target.type==Obj_AI_Hero or target.type==Obj_AI_Minion then raw.physical=raw.physical+extra.physical;raw.magical=raw.magical+extra.magical end
    local chance=c.hero.critChance or 0
    local expected=not color and chance<1 and (c.hero.totalDamage or 0)*chance*(crit-1) or 0
    return {physical=sdk.Damage:CalculateDamage(c.hero,target,sdk.DAMAGE_TYPE_PHYSICAL,raw.physical,false,true),
        magical=sdk.Damage:CalculateDamage(c.hero,target,sdk.DAMAGE_TYPE_MAGICAL,raw.magical,false,true),trueDamage=0,
        expected=sdk.Damage:CalculateDamage(c.hero,target,sdk.DAMAGE_TYPE_PHYSICAL,expected,false,true)}
end
function C:qDamage(target)
    local c=self.c
    return c.sdk.Damage:CalculateDamage(c.hero,target,c.sdk.DAMAGE_TYPE_MAGICAL,
        P.Q(c.profile,c.state.spells[0].level,c.hero),true,false)
end
function C:target(range)
    local c=self.c
    return c.sdk.TargetSelector:GetTarget(range,c.sdk.DAMAGE_TYPE_MAGICAL)
end
function C:attack(target,mode,owner,check)
    local c=self.c;local id=U.id(target)
    if self.attackID and c.actions.client.jobs[self.attackID]then return false end
    if not c.sdk.Orbwalker:CanAttack()then return false,'attack_not_ready' end
    self.attackID=c.actions.client:Attack(target,{owner=owner or 'combat_attack',resource='attack',priority='normal',
        targetID=id,expires=c.actions.client:Now()+140,context=mode and {modes={mode}} or nil,
        mechanical=function()
            if U.id(target)~=id or not U.target(target)then return false,'attack_target_lost' end
            if c.state:channel()then return false,'manual_channel' end
            if U.dist(c.hero,target)>c.sdk.Data:GetAutoAttackRange(c.hero,target)then return false,'attack_out_of_range' end
            local protection=c.state:protection(target)
            if protection.dodge or protection.invulnerable then return false,'attack_protected' end
            if c.state.stage=='held' and protection.spellShield then return false,'card_spellshield' end
            if check and not check()then return false,'attack_plan_changed' end
            return true
        end,reconcile=function()return target~=nil and c.hero.attackData~=nil end})
    if self.attackID then
        self.attackAt=c.state.lastAttack;self.attackTarget=id;self.attackOwner=owner or 'combat_attack';self.attackLoggedState=nil
        c:record('attack_requested',{id=self.attackID,target=id,owner=self.attackOwner,mode=c.state.mode,health=target.health})
    end
    return self.attackID
end
function C:pollAttack()
    local id=self.attackID;if not id then return end
    local c=self.c;local client=c.actions.client;local r=client:Poll(id)
    if r and c.config:get('diagnostics') and (self.attackLoggedState~=r.state or self.attackLoggedSent~=r.sentAt)then
        self.attackLoggedState=r.state;self.attackLoggedSent=r.sentAt
        c:record('attack_state',{id=id,target=self.attackTarget,owner=self.attackOwner,state=r.state,reason=r.reason,
            sentAt=r.sentAt,requestedAt=r.requestedAt,releasedAt=r.releasedAt,cleanupPending=r.cleanupPending})
    end
    if r and r.sentAt and c.state.lastAttack>(self.attackAt or 0)then
        client:Observe(id,{kind='mechanical',unique=true,at=client:Now(),source='sdk_attack_start'})
    end
    client:Reconcile(id)
    if not client.jobs[id]then self.attackID=nil end
end
function C:model(target,mode)
    local c=self.c;local s=c.state;local h=c.hero;local protection=s:protection(target)
    if protection.invulnerable then return nil end
    local range=c.sdk.Data:GetAutoAttackRange(h,target);local dist=U.dist(h,target)
    local p={hp=target.health,shield=target.allShield,physicalShield=target.shieldAD,magicalShield=target.shieldAP,
        regen=target.hpRegen or 0,mana=h.mana,maxMana=h.maxMana,windup=c.sdk.Attack:GetWindup(),
        period=c.sdk.Attack:GetAnimation(),flight=dist/math.max(1,c.sdk.Attack:GetProjectileSpeed()),
        nextAA=math.max(0,(c.sdk.Attack.ServerStart or -10)+c.sdk.Attack:GetAnimation()-Game.Timer()),
        qCost=s:cost(0),wCost=s.stage=='selecting' and 0 or s:cost(1),reserveQ=s:reserve(0),reserveW=s:reserve(1),
        qCast=c.profile.q.delay,stun=protection.immune and 0 or math.max(0,P.Stun(s.spells[1].level)-protection.cc),
        blueMana=P.Rank(c.profile.wMana,s.spells[1].level),reset=c.profile.lockReset,
        card=s.stage=='held' and s.color or nil,e=s.eReady and 3 or 0,hasE=c.profile.eBase~=nil,
        -- Repeated reach uses base observed range, excluding SDK's one-use extension.
        repeatReachable=dist<=(h.range or 0)+(h.boundingRadius or 0)+(target.boundingRadius or 0)-40}
    p.controlValue=0
    if dist<=range and not protection.dodge and not(p.card and protection.spellShield) then
        local cache={};local healthDependent=false
        for _,item in pairs(s.inventory.slots)do
            local rule=P.itemRules[c.profile.id][item.itemID]
            if rule and rule.currentHealthPhysical then healthDependent=true end
        end
        p.attack=function(color,eReady,index,hp)
            local key=(color or 'none')..':'..tostring(eReady)..':'..tostring(index==0)
                ..(healthDependent and ':'..tostring(hp) or '')
            if not cache[key]then cache[key]=self:packet(target,color,eReady,index,hp)end
            return cache[key]
        end
        p.controlValue=(h.totalDamage or 0)/math.max(.1,p.period)*.25
        for _,ally in ipairs(s.heroes)do
            if ally.team==h.team and ally~=h and U.alive(ally) and U.dist(ally,target)<(ally.range or 125)+250 then
                -- Utility estimate only; not damage or a guaranteed kill.
                p.controlValue=p.controlValue+20
            end
        end
    end
    local busy,busyReason=c.actions:busy(0)
    p.qReason=not c.config:get(mode..'Q') and 'disabled' or not s:ready(0) and 'not_ready'
        or busy and busyReason or s:windupActive() and 'attack_windup'
        or protection.spellShield and 'spellshield' or h.mana<p.qCost+p.reserveQ and 'mana_reserve' or nil
    if not p.qReason then
        local q=c.q:plan(target,s.heroes)
        if q then p.q={magical=self:qDamage(target)};p.qImpact=q.impact end
        p.qReason=c.q.reason
    end
    if c.config:get(mode..'W') and not c.cards.manual and s:ready(1,s.stage=='selecting') and s.stage~='held' and dist<=range then
        p.cards={}
        for _,color in ipairs(P.colors)do
            if not protection.spellShield then p.cards[#p.cards+1]={color=color,wait=c.cards:waitFor(color)}end
        end
    end
    p.extras=(mode=='COMBO' or mode=='HARASS') and c.effects:candidates(target) or nil
    local flight=s.cardFlight
    if flight and flight.packet and (flight.target==target.networkID or flight.target==target.handle)
        and flight.missile.valid~=false and not protection.spellShield then
        p.incoming={{at=U.dist(flight.missile,target)/flight.speed,packet=flight.packet,
            control=flight.color=='gold' and not protection.immune and p.stun or 0}}
    end
    return p
end
function C:diagnostics(mode,target,p,plan)
    local c=self.c;if not c.config:get('diagnostics')then return end
    local now=Game.Timer();if now<(self.nextDiagnostic or 0)then return end
    self.nextDiagnostic=now+.5
    c:record('combat_decision',{mode=mode,target=U.id(target),reason=not target and 'no_target'
        or not p and 'target_protected' or p.qReason,first=plan and plan.first,usedQ=plan and plan.usedQ,
        qDamage=p and p.q and p.q.magical,qImpact=p and p.qImpact,qCost=p and p.qCost,
        reserveQ=p and p.reserveQ,nextAA=p and p.nextAA,period=p and p.period,
        predictionChance=c.q.predict and c.q.predict.HitChance,windup=c.state:windupActive(),
        distance=target and U.dist(c.hero,target),health=target and target.health,
        mana=c.hero.mana,ap=c.hero.ap,ad=c.hero.totalDamage,transitions=plan and plan.transitions})
end
function C:tick(mode,modeID)
    local c=self.c;local target=self:target(c.profile.q.range)
    if not U.target(target)then self:diagnostics(mode,nil);return end
    local p=self:model(target,mode);if not p then self:diagnostics(mode,target);return end
    local plan=Planner.solve(p);c.plan={target=target,first=plan.first,color=plan.color,damage=target.health-math.max(0,plan.hp),transitions=plan.transitions}
    self:diagnostics(mode,target,p,plan)
    if c.config:get('level')then c.level:sample(mode,p)end
    if plan.first=='card' then c.cards:auto(plan.color,'combat',function()
        return U.target(target) and U.dist(c.hero,target)<=c.sdk.Data:GetAutoAttackRange(c.hero,target)
            and c.config:get(mode..'W') and not c.state:protection(target).spellShield
    end)
    elseif plan.first=='q' then
        c.q:cast(target,modeID,function(t)
            -- Q's resolver already checked fresh prediction, target and blockers.
            -- Rebuilding the whole combat model here repeats that work while the
            -- provider owns the cursor, without changing this intent's target.
            return c.config:get(mode..'Q') and c.hero.mana>=c.state:cost(0)+c.state:reserve(0)
        end)
    elseif plan.first=='extra' and modeID then c.effects:execute(plan.extra,target,modeID)
    elseif plan.first=='attack' then
        -- Orbama owns ordinary attacks. Explicit requests are only needed for a
        -- concrete held card target; the SDK selected target remains authoritative.
        if c.state.stage=='held' then self:attack(target,modeID)end
    end
end
function C:interrupt()
    local c=self.c;local s=c.state
    if not c.config:get('interrupt') or c.cards.manual and c.cards.manual.color~='gold' then return end
    for _,u in ipairs(s.heroes)do
        -- activeSpell is a native object read. Allies and unavailable enemies
        -- cannot be interrupt candidates; reject them before requesting it.
        if u.team~=c.hero.team and U.target(u)then
        local a=u.activeSpell
        if a and a.valid and a.isChanneling then
            local id=U.id(u);local ending=a.endTime or a.castEndTime or 0
            local delay=c.cards:waitFor('gold')+c.sdk.Attack:GetWindup()+U.dist(c.hero,u)/1500
            local protect=s:protection(u)
            if not protect.immune and not protect.spellShield and not protect.dodge and not protect.invulnerable
                and ending>Game.Timer()+delay+.10 and U.dist(c.hero,u)<=c.sdk.Data:GetAutoAttackRange(c.hero,u)then
                c.cards:auto('gold','interrupt',function()
                    local a=u.activeSpell;local protect=s:protection(u)
                    return c.config:get('interrupt') and U.target(u) and a and a.valid and a.isChanneling
                        and (a.endTime or a.castEndTime or 0)>Game.Timer()+c.sdk.Attack:GetWindup()+U.dist(c.hero,u)/1500
                        and not protect.immune and not protect.spellShield and not protect.invulnerable
                end)
                if s.stage=='held' and s.color=='gold' then
                    return self:attack(u,nil,'interrupt',function()
                        local spell=u.activeSpell
                        return c.config:get('interrupt') and U.id(u)==id and spell and spell.valid and spell.isChanneling
                            and (spell.endTime or spell.castEndTime or 0)>Game.Timer()+c.sdk.Attack:GetWindup()+U.dist(c.hero,u)/1500
                            and not s:protection(u).immune and not s:protection(u).spellShield
                            and not(c.cards.manual and c.cards.manual.color~='gold')
                    end)
                end
                return true
            end
        end
        end
    end
end
function C:peel()
    local c=self.c;local s=c.state
    if s.mode=='FLEE' and not c.config:get('FLEEW')then return end
    if not(c.config:get('peel') or s.mode=='FLEE') or c.cards.manual and c.cards.manual.color~='gold' then return end
    if s.mode~='FLEE'then
        local approaching=false
        for _,u in ipairs(s.heroes)do
            if u.team~=c.hero.team and U.target(u) and U.dist(c.hero,u)<=650 then
                local path=u.pathing
                if path and path.isDashing and path.endPos and U.dist(path.endPos,c.hero)<300 then approaching=true;break end
            end
        end
        -- Keep the SDK's explicit selection/priority policy when there is a
        -- threat. Avoid its damage-based ranking when no action is possible.
        if not approaching then return end
    end
    local target=self:target(650)
    if not U.target(target)then return end
    local path=target.pathing;local threatening=s.mode=='FLEE' or path and path.isDashing and path.endPos and U.dist(path.endPos,c.hero)<300
    if not threatening then return end
    if not s:protection(target).immune then
        c.cards:auto('gold','peel',function()
            local path=target.pathing
            return U.target(target) and U.dist(c.hero,target)<650 and not s:protection(target).immune
                and (U.mode(c.sdk)=='FLEE' or c.config:get('peel') and path and path.isDashing and path.endPos and U.dist(path.endPos,c.hero)<300)
        end)
        if s.stage=='held' and s.color=='gold'then return self:attack(target,nil,'peel',function()
            return c.config:get('peel') or U.mode(c.sdk)=='FLEE'
        end)end
    end
end
function C:flee()
    local c=self.c;local s=c.state
    if c.config:get('FLEEQ') and s:ready(0) and c.hero.mana>=s:cost(0)+s:reserve(0)then
        local target=self:target(c.profile.q.range)
        if U.target(target) and U.dist(c.hero,target)>c.sdk.Data:GetAutoAttackRange(c.hero,target)then
            c.q:cast(target,s.modeID,function(t)return c.config:get('FLEEQ') and U.dist(c.hero,t)>c.sdk.Data:GetAutoAttackRange(c.hero,t)end)
        end
    end
end
function C:classicR()
    local c=self.c;local s=c.state
    if not(c.profile.autoRVerified and c.config:get('classicR')) or (s.mode~='COMBO' and s.mode~='FLEE')then return end
    local target=self:target(1000);if not U.target(target)then return end
    local id=U.id(target);local mode=s.modeID
    local function useful()
        local protection=s:protection(target)
        return U.id(target)==id and U.target(target) and c.sdk.Orbwalker.Modes[mode] and s:ready(3)
            and U.lower(c.hero:GetSpellData(3).name)==U.lower(c.profile.rName)
            and U.dist(c.hero,target)<1000 and U.dist(c.hero,target)>250 and protection.cc<.2
            and not protection.immune and not protection.spellShield and not protection.invulnerable
            and c.hero.mana>=s:cost(3)+s:reserve(3) and (target.ms or 0)>(c.hero.ms or 0)*.8
    end
    if useful()then return c.actions:submit(3,{owner='classic_r',context={modes={mode}},mechanical=useful})end
end
return C
