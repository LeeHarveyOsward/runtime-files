local U=require('tf.util')
local P=require('CombatProfiles.twisted_fate')
local F={};F.__index=F
function F.new(c)return setmetatable({c=c},F)end
function F:eligible(u,mode)
    local c=self.c
    if not U.target(u) or u.team==c.hero.team or u.type~=Obj_AI_Minion then return false end
    if mode=='JUNGLECLEAR' then return u.team==300 and U.dist(c.hero,u)<850 end
    return u.team~=300 and U.dist(c.hero,u)<c.profile.q.range
end
function F:hp(u,delay)return self.c.sdk.HealthPrediction:GetPrediction(u,delay)end
function F:impact(u)
    local c=self.c;local attack=c.sdk.Attack
    local wait=math.max(0,(attack.ServerStart or -10)+attack:GetAnimation()-Game.Timer())
    return wait+attack:GetWindup()+U.dist(c.hero,u)/math.max(1,attack:GetProjectileSpeed())
end
function F:aa(u,color)
    local raw=self.c.combat:packet(u,color,self.c.state.eReady)
    return raw.physical+raw.magical+raw.trueDamage
end
function F:attackChoice(mode)
    local c=self.c;local s=c.state;local hit,best,urgent,hitHP,bestHP
    local examined=0
    for _,u in ipairs(s.minions)do
        examined=examined+1;if examined>128 then break end
        if self:eligible(u,mode) and U.dist(c.hero,u)<=c.sdk.Data:GetAutoAttackRange(c.hero,u)then
            local at=self:impact(u);local hp=self:hp(u,at)
            if hp>0 then
                if not best or hp<bestHP then best=u;bestHP=hp end
                if hp<=self:aa(u,s.stage=='held' and s.color or nil)then
                    local losesWindow=self:hp(u,at+c.profile.q.delay)<=0
                    if not hit or losesWindow and not urgent or losesWindow==urgent and hp<hitHP then
                        hit=u;hitHP=hp;urgent=losesWindow
                    end
                end
            end
        end
    end
    return hit,best,urgent
end
function F:decision(reason,target)
    local c=self.c;if not c.config:get('diagnostics')then return end
    local id=target and U.id(target);local now=Game.Timer()
    if self.lastReason==reason and self.lastTarget==id and now<(self.nextDecision or 0)then return end
    self.lastReason=reason;self.lastTarget=id;self.nextDecision=now+.5
    c:record('farm_decision',{reason=reason,target=id,mode=c.state.mode})
end
function F:diagnostics(mode)
    local c=self.c;if not c.config:get('diagnostics')then return end
    local now=Game.Timer();if now<(self.nextDiagnostic or 0)then return end
    self.nextDiagnostic=now+.25
    local s=c.state;local attack=c.sdk.Attack;local n=0;local examined=0;local tracked={}
    local sdkRows={}
    for i,row in ipairs(c.sdk.HealthPrediction.FarmMinions or {})do
        if i>128 then break end
        if row.Minion then sdkRows[U.id(row.Minion)]=row end
    end
    c:record('farm_snapshot',{mode=mode,stage=s.stage,color=s.color,manual=c.cards.manual and c.cards.manual.color,
        attackBlocked=c.actions.client.locks.manual_card and c.actions.client.locks.manual_card.attack,
        providerCanAttack=c.sdk.Orbwalker:CanAttack(),
        attackJob=c.combat.attackID,serverStart=attack.ServerStart,castEnd=attack.CastEndTime,
        period=attack:GetAnimation(),windup=attack:GetWindup(),speed=attack:GetProjectileSpeed(),
        qReady=s:ready(0),wReady=s:ready(1,s.stage=='selecting'),eReady=s.eReady,mana=c.hero.mana})
    for _,u in ipairs(s.minions)do
        examined=examined+1;if examined>128 or n>=12 then break end
        if self:eligible(u,mode)then
            n=n+1;local at=self:impact(u);local row=sdkRows[U.id(u)]
            tracked[U.id(u)]={unit=u,health=u.health,at=now}
            c:record('farm_minion',{id=U.id(u),handle=u.handle,name=u.charName,team=u.team,health=u.health,
                maxHealth=u.maxHealth,distance=U.dist(c.hero,u),range=c.sdk.Data:GetAutoAttackRange(c.hero,u),
                aaImpact=at,hpAA=self:hp(u,at),aaDamage=self:aa(u,s.stage=='held' and s.color or nil),
                hpAfterQCast=self:hp(u,at+c.profile.q.delay),qImpact=c.profile.q.delay+U.dist(c.hero,u)/c.profile.q.speed,
                hpQ=self:hp(u,c.profile.q.delay+U.dist(c.hero,u)/c.profile.q.speed),qDamage=c.combat:qDamage(u),
                sdkLastHittable=row and row.LastHitable,sdkPredictedHP=row and row.PredictedHP,
                sdkUnkillable=row and row.Unkillable})
        end
    end
    for id,last in pairs(self.tracked or {})do
        if not tracked[id]then
            local u=last.unit;local dead=u.valid~=false and (u.dead or (u.health or 1)<=0)
            c:record('farm_minion_exit',{id=id,lastHealth=last.health,lastSeen=last.at,
                state=dead and 'death_observed' or 'left_sample',credit='unknown'})
        end
    end
    self.tracked=tracked
end
function F:qWorth(u,mode,attackWindowChecked,evaluation)
    local c=self.c;local s=c.state
    if not attackWindowChecked then
        local _,_,urgent=self:attackChoice(mode)
        if urgent then return false end -- Rechecked before a queued Q sends, too.
    end
    if evaluation and not evaluation.geometry then evaluation.geometry={}end
    local plan=c.q:plan(u,s.minions,evaluation and evaluation.geometry);if not plan then return false end
    local kills,total=0,0
    for _,m in ipairs(plan.hits)do
        if not self:eligible(m,mode)then return false end
        local id=U.id(m);local row=evaluation and evaluation[id]
        if not row then
            row={hp=self:hp(m,c.profile.q.delay+U.dist(c.hero,m)/c.profile.q.speed),damage=c.combat:qDamage(m)}
            if evaluation then evaluation[id]=row end
        end
        local hp,damage=row.hp,row.damage
        if hp>0 then
            total=total+math.min(damage,hp)
            if hp<=damage then kills=kills+1 elseif mode=='LASTHIT' then return false end
        end
    end
    if mode=='LASTHIT' then
        local aaTime=self:impact(u)
        local hpAA=self:hp(u,aaTime)
        if c.effects:hasUnknownSplash()then return false end
        local inRange=U.dist(c.hero,u)<=c.sdk.Data:GetAutoAttackRange(c.hero,u)
        if inRange and hpAA>0 and hpAA<=self:aa(u,s.stage=='held' and s.color or nil) then return false end
        return kills>0 and c.hero.mana>=s:cost(0)+s:reserve(0)
    end
    return total>0 and (kills>0 or #plan.hits>=2 or mode=='JUNGLECLEAR') and c.hero.mana>=s:cost(0)+s:reserve(0),kills,total
end
function F:tick(mode,modeID)
    local c=self.c;local s=c.state
    self:diagnostics(mode)
    local hit,best,urgent=self:attackChoice(mode)
    local function attack(u)
        self:decision(urgent and 'save_aa_window' or 'aa_last_hit',u)
        return c.combat:attack(u,modeID,'farm_attack',function()
            local hp=self:hp(u,self:impact(u));local color=c.state.stage=='held' and c.state.color or nil
            return self:eligible(u,mode) and hp>0 and hp<=self:aa(u,color)
        end)
    end
    if hit and (urgent or mode=='LASTHIT')then return attack(hit)end
    local examined=0
    local qTarget,qKills,qTotal;local predicted=0
    -- These candidates are evaluated synchronously from the same fresh state.
    -- Reuse identical Q impact health/damage, never across ticks or dispatch.
    local evaluation={}
    local canQ=c.config:get(mode..'Q') and s:ready(0) and not s:windupActive()
        and not c.actions:busy(0) and c.hero.mana>=s:cost(0)+s:reserve(0)
    for _,u in ipairs(s.minions)do
        examined=examined+1;if examined>128 then break end
        if self:eligible(u,mode)then
            if canQ and predicted<8 then
                predicted=predicted+1
                local worth,kills,total=self:qWorth(u,mode,true,evaluation);kills=kills or 1;total=total or 0
                if worth and (not qTarget or kills>qKills or kills==qKills and total>qTotal)then
                    qTarget=u;qKills=kills;qTotal=total
                end
            end
        end
    end
    if qTarget then
        self:decision('q_farm',qTarget)
        return c.q:cast(qTarget,modeID,function(t)return c.config:get(mode..'Q') and self:eligible(t,mode) and self:qWorth(t,mode)end)
    end
    if hit then return attack(hit)end
    if not best then self:decision('no_reachable_target');return end
    if c.config:get('level') and math.floor(Game.Timer())~=c.level.lastSample then
        local qOpportunity=c.q:plan(best,s.minions)
        c.level:sample(mode,{attack=true,period=c.sdk.Attack:GetAnimation(),
            q=qOpportunity and #qOpportunity.hits>=2 and true or nil,controlValue=0})
    end
    local bestHP=self:hp(best,self:impact(best))
    self:decision('provider_clear_or_wait',best)
    if c.cards.manual or not c.config:get(mode..'W') or s.stage=='held' or not s:ready(1,s.stage=='selecting')then return end
    local blue=self:aa(best,'blue')
    if mode=='LASTHIT' then
        if not c.effects:hasUnknownSplash() and bestHP<=blue and c.cards:waitFor('blue')<.4
            and c.hero.mana>=s:cost(1)+s:reserve(1)then c.cards:auto('blue','save_cs',function()
                local hp=self:hp(best,self:impact(best)+c.cards:waitFor('blue'))
                return self:eligible(best,mode) and hp>0 and hp<=self:aa(best,'blue')
            end)end
    else
        local color='blue'
        local usable=P.BlueRecovery(c.profile,s.spells[1].level,c.hero.mana,c.hero.maxMana)
        local splash=0
        if c.profile.redRadius then
            for _,u in ipairs(s.minions)do if self:eligible(u,mode) and U.dist(best,u)<=c.profile.redRadius then splash=splash+1 end end
        end
        if splash>=3 and c.hero.mana-s:cost(1)>=s:reserve(1)+s:cost(0) and usable<25 then color='red'end
        local recovery=color=='blue' and P.Rank(c.profile.wMana,s.spells[1].level) or 0
        if c.hero.mana>=s:cost(1) and math.min(c.hero.maxMana,c.hero.mana-s:cost(1)+recovery)>=s:reserve(1)then
            c.cards:auto(color,'clear',function()return self:eligible(best,mode) and U.dist(c.hero,best)<=c.sdk.Data:GetAutoAttackRange(c.hero,best)end)
        end
    end
end
return F
