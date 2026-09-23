local U=require('lho.util');local P=require('lho.profiles')
local Clear={};Clear.__index=Clear
local passiveBuffs={leesinpassivebuff=true,leesinpassive=true}

function Clear.new(ctx)
    return setmetatable({ctx=ctx,stages={},windows={},lastCast={},spellSamples={},passiveLeft=0,passiveUntil=0},Clear)
end

function Clear:executed(slot,stage,at,native)
    if slot<0 or slot>3 then return end
    self.observedScope=nil
    at=at or self.ctx:now()
    self.executionBySlot=self.executionBySlot or {}
    local previous=self.executionBySlot[slot]
    self.executionCredits=self.executionCredits or {}
    local credits=self.executionCredits[slot] or {}
    -- Native start, delayed cooldown/stage and controller observation describe
    -- the same cast. Deduplicate by stage within the observed readiness cycle,
    -- not a short time window that can expire before metadata arrives.
    local credit=credits[stage]
    if credit then
        if not native or at<=credit.at+.01 then return end
        -- A distinct native start is fresh execution evidence even if no ready
        -- sample occurred between callbacks. A first cast begins a new cycle.
        if stage==1 then credits={} end
    end
    credits[stage]={at=at};self.executionCredits[slot]=credits
    self.lastExecution={slot=slot,stage=stage,at=at};self.executionBySlot[slot]=self.lastExecution
    if self.ctx.config.capture then self.ctx:log('passive_credit',{slot=slot,stage=stage,castAt=at,remaining=2}) end
    self:accepted(slot,stage)
    self.passiveCastAt=at;self.passiveUntil=at+3
    local d=self.ctx:spell(slot)
    self.spellSamples[slot]={cd=d.currentCd or 0,stage=self.ctx:stage(slot)}
end

function Clear:observe()
    local scope=U.buffScopeKey()
    if scope and self.observedScope==scope then return end
    self.observedScope=scope
    local c=self.ctx;local now=c:now()
    local active=myHero.activeSpell
    if active and active.valid and U.finite(active.startTime) and active.startTime<=now and now-active.startTime<.75 then
        local name=U.name(active.name);local slot=name:find('leesinq',1,true) and 0 or name:find('leesinw',1,true) and 1
            or name:find('leesine',1,true) and 2 or name:find('leesinr',1,true) and 3
        local token=name..':'..active.startTime
        if slot and token~=self.activeToken then
            self.activeToken=token
            if not self.lastExecution or self.lastExecution.slot~=slot or active.startTime>self.lastExecution.at+.01 then
                self:executed(slot,name:find('two',1,true) and 2 or 1,active.startTime,true)
            end
        end
    end
    -- GG emits OnPostAttack from Move(), so stationary auto-jungle cannot
    -- depend on that callback alone. Its native attack cast-end is shared
    -- evidence for both paths; deduplicate the eventual movement callback.
    local attack=c.sdk.Attack;local finish=attack and attack.CastEndTime
    if finish and finish>0 and now>=finish and now-finish<.5 and self.finishedAttack~=finish then
        self:attackFinished(finish)
    end
    for slot=0,2 do
        local d=c:spell(slot);local stage=c:stage(slot,nil,d);local prior=self.spellSamples[slot]
        if prior and stage==1 and (d.currentCd or 0)<=.05 and (prior.cd>.05 or prior.stage~=1) then
            -- A fresh ready cycle permits another cast; unchanged ready
            -- metadata following a native start does not reset its credit.
            if self.executionCredits then self.executionCredits[slot]=nil end
        end
        -- A recast's remaining cooldown can become visible on natural expiry.
        -- Only first casts use cooldown evidence; recasts need active-spell or
        -- finite passive-buff evidence, handled separately above/below.
        local provisional=not c.actions.api and self.lastCast[slot] and now-self.lastCast[slot].at<.6
        if prior and not provisional and prior.stage==1 and ((d.currentCd or 0)>prior.cd+.05 or stage==2) then
            self:executed(slot,prior.stage,now)
        end
        local physical=c.manualSpells and c.manualSpells[slot]
        local before=physical and not physical.consumed and physical.before or prior and prior.recast
        local recast=(stage==2 or before and before.stage==2 and c.actions.api)
            and require('lho.recasts').snapshot(c,slot,d,stage) or nil
        if before and before.stage==2 and c.actions.api then
            local yes,evidence=require('lho.recasts').evidence(c,slot,before,nil,true,recast)
            if yes then self:executed(slot,2,evidence.at);if physical then physical.consumed=true end end
        end
        local sample=self.spellSamples[slot] or {}
        sample.cd=d.currentCd or 0;sample.stage=stage;self.spellSamples[slot]=sample
        if stage==2 and self.stages[slot]~=2 then self.windows[slot]=self.windows[slot] or now+3 end
        if stage~=2 then self.windows[slot]=nil end
        self.stages[slot]=stage
        if recast then recast.window=self.windows[slot] end
        sample.recast=stage==2 and recast or nil
    end
    if now>=self.passiveUntil then self.passiveLeft=0 end
    local buff=U.buff(myHero,passiveBuffs,now)
    local expiry=buff and math.max(buff.expireTime or 0,buff.endTime or 0) or 0
    if not c.actions.api and expiry>now and expiry<=now+3.3 and expiry~=self.passiveObservedExpiry then
        self.passiveObservedExpiry=expiry
        -- Observe manual casts too, without regranting attacks when the buff
        -- acknowledgement for our own cast arrives late. Cosmetic buffs do
        -- not participate; a persistent count=1 cannot stall future spells.
        local started=U.finite(buff.startTime) and buff.startTime>0 and buff.startTime or expiry-3
        if started>(self.passiveCastAt or -10)+.05 then
            self.passiveLeft=2;self.passiveUntil=expiry;self.passiveCastAt=started
        end
    end
    self.observedScope=scope
end

function Clear:attackFinished(finish)
    local c=self.ctx
    finish=finish or c.sdk.Attack and c.sdk.Attack.CastEndTime
    local active=myHero.activeSpell
    if active and active.castEndTime==finish and active.isStopped then self.cancelledAttack=finish end
    if finish and finish==self.cancelledAttack then return false end
    if finish and finish>0 then
        if finish>c:now() then return false end
        if self.finishedAttack==finish then return false end
        self.finishedAttack=finish
        if finish<(self.passiveCastAt or 0) then return false end
    else return false end -- No deduplication identity: do not spend an attack.
    self.passiveLeft=math.max(0,self.passiveLeft-1)
    c.lastAttackFinished=c:now()
    if c.config.capture then c:log('passive_attack_consumed',{remaining=self.passiveLeft,castEndTime=finish}) end
    return true
end

function Clear:weaving()
    self:observe()
    -- A cosmetic/manager buff may remain visible with count=1. It must never
    -- permanently veto every later cast. Track our own bounded two-attack window.
    return self.ctx:now()<self.passiveUntil and self.passiveLeft>0
end
function Clear:remainingHealth(target)
    if target.team==300 then
        for _,camp in pairs(self.ctx.farm.known) do
            local found,total=false,0
            for _,m in ipairs(camp.members or {}) do
                if U.valid(m) then total=total+m.health end
                if U.same(m,target) then found=true end
            end
            if found then return total end
        end
    end
    return target.health
end

-- Short rolling horizon: how long the remaining boosted attacks cover us,
-- when another usable spell can replenish them, and whether waiting is safe.
-- This is a bounded estimate, not a forced two-auto combo or a global optimum.
function Clear:passivePlan(slot,target,owner)
    local c=self.ctx;local now=c:now();local attack=c.sdk.Attack
    local cycle=math.max(.15,attack.GetAnimation and attack:GetAnimation() or 1)
    local wait=attack.IsReady and not attack:IsReady() and math.max(0,(attack.ServerStart or now)+cycle-now) or 0
    local first=wait+c:windup()+c.latency*.5
    local coverage=math.min(math.max(0,self.passiveUntil-now),first+math.max(0,self.passiveLeft-1)*cycle)
    local prefix=owner=='farm' and 'autoClear' or 'jungle';local nextSpell=math.huge
    local energyAfter=math.max(0,(myHero.mana or 0)-(c:spell(slot).mana or 0))
    -- Q1 creates its own next refresh after impact, provided the monster can
    -- survive it. Do not model Q1 like a final recast with no follow-up.
    if slot==0 and c:stage(0)==1 and energyAfter>=30 and c.config:get(prefix..'Q2') then
        local impact=.25+U.dist(myHero.pos,target.pos)/c.profile.qSpeed+c.latency
        if c.farm:qSurvives(target,impact) then nextSpell=impact end
    end
    for other=0,2 do
        local d=c:spell(other);local stage=c:stage(other,other==0 and target or nil)
        local key=other==0 and (stage==2 and 'Q2' or 'Q') or other==1 and 'W' or 'E'
        if other~=slot and (d.level or 0)>0 and (stage==1 or stage==2)
            and c.config:get(prefix..'Abilities') and c.config:get(prefix..key) and (d.mana or 0)<=energyAfter then
            local usable=true
            if other==0 then
                usable=stage==2 and c:mark(target)~=nil or stage==1 and U.dist(myHero.pos,target.pos)<=c.profile.qRange
                    and #c.spells:blockers(target,target.pos)==0
            elseif other==2 then
                usable=U.dist(myHero.pos,target.pos)<=(stage==2 and c.profile.e2Range or c.profile.eRange)
                    and (stage==1 or U.buff(target,P.eMarks,now)~=nil)
            end
            local cd=math.max(0,d.currentCd or 0)
            if stage==2 and self.windows[other] and self.windows[other]-now<=cd then usable=false end
            if usable then nextSpell=math.min(nextSpell,cd) end
        end
    end
    local members={target}
    for _,camp in pairs(c.farm.known) do
        local found=false;for _,m in ipairs(camp.members or {}) do if U.same(m,target) then found=true;break end end
        if found then members=camp.members;break end
    end
    local incoming=0
    for _,m in ipairs(members) do
        if U.valid(m) and U.dist(myHero.pos,m.pos)<math.max(400,(m.range or 0)+100) then
            local raw=m.totalDamage or m.attackData and m.attackData.damage or math.max(8,(m.maxHealth or m.health)*.035)
            local rate=m.attackSpeed or (m.attackData and m.attackData.animationTime and 1/math.max(.2,m.attackData.animationTime)) or .7
            local ok,damage=pcall(c.sdk.Damage.CalculateDamage,c.sdk.Damage,m,myHero,c.sdk.DAMAGE_TYPE_PHYSICAL,raw)
            if not ok or type(damage)~='number' or damage~=damage then damage=raw end
            -- Include one immediately possible hit; unknown attack phases must
            -- not falsely promise that the next hit is a full cycle away.
            incoming=incoming+math.max(0,damage)*math.max(1,math.ceil(coverage*rate))
        end
    end
    local health=myHero.health+(myHero.allShield or 0)
    local danger=U.hp(myHero)<=15 or incoming>=health-math.max(50,myHero.maxHealth*.08)
    local plan={slot=slot,target=U.id(target),at=now,remaining=self.passiveLeft,coverage=coverage,
        nextSpell=nextSpell<math.huge and nextSpell or nil,gap=nextSpell<math.huge and math.max(0,nextSpell-coverage) or nil,
        drought=nextSpell>coverage+.1,incoming=incoming,health=health,energyAfter=energyAfter,danger=danger}
    self.passiveDecision=plan
    return plan
end

function Clear:passiveReason(plan,reason)
    plan.reason=reason
    if self.ctx.config.capture then self.ctx:trace('clear_passive_decision',plan,tostring(plan.slot)..':'..reason,.75) end
end

function Clear:eOpportunity(target)
    local c=self.ctx
    if c:stage(2)~=1 or target.team~=300 then return true end
    if not c.spells:eHits(target) then return false,'e_impact_out_of_range' end
    if U.hp(myHero)<45 or c:spellDamageEstimate(2,target,1)>=U.effectiveHP(target) then return true end
    local path=myHero.pathing
    if not path or not path.hasMovePath or not path.endPos then return true end
    local future=U.toward(myHero.pos,path.endPos,math.min(U.dist(myHero.pos,path.endPos),(myHero.ms or 0)*.75))
    for _,camp in pairs(c.farm.known) do
        local contains=false;for _,m in ipairs(camp.members or {}) do if U.same(m,target) then contains=true;break end end
        if contains then
            local now,later=0,0
            for _,m in ipairs(camp.members) do
                if c.spells:eHits(m) then now=now+1 end
                if c.spells:eHits(m,future) then later=later+1 end
            end
            if later>now then
                if c.config.capture then c:trace('clear_e_coverage_wait',{hits=now,approachHits=later,
                    origin=U.copy(myHero.pos),target=U.id(target)},tostring(camp.id),.5) end
                return false,'e_better_coverage_on_current_approach'
            end
            break
        end
    end
    return true
end
function Clear:cast(slot,target,owner,urgent)
    local c=self.ctx;local stage=c:stage(slot,slot==0 and target or nil);local ok,event
    local prefix=owner=='farm' and 'autoClear' or 'jungle'
    local key=slot==0 and (stage==2 and 'Q2' or 'Q') or ({'Q','W','E'})[slot+1]
    if not c.config:get(prefix..'Abilities') or not c.config:get(prefix..key) then return false end
    if stage==1 and target.team==300 and (slot==0 or slot==2) and not urgent
        and self:reserveForNext(slot,target,owner) then return false end
    if slot==0 then
        if stage==1 then ok,event=c.spells:q1(target,owner,false) else ok,event=c.spells:q2(target,owner,false,urgent) end
    elseif slot==1 then ok,event=c.spells:w(myHero,owner,nil,owner=='farm' and 'autoClear' or 'jungle')
    else
        local function valid()return self:eOpportunity(target) end
        if not valid() then return false end
        ok,event=c.spells:e(target,owner,valid)
    end
    if ok then
        if c.config.capture then c:log('clear_cast',{slot=slot,stage=stage,owner=owner,target=U.id(target),health=U.hp(myHero)}) end
    end
    return ok,event
end
function Clear:accepted(slot,stage,grantPassive)
    local now=self.ctx:now()
    self.lastCast[slot]={at=now,stage=stage}
    if slot==1 and stage==2 then self.sustainUntil=now+4 end
    if grantPassive~=false then self.passiveLeft=2;self.passiveUntil=now+3;self.passiveCastAt=now end
    self.stages[slot]=stage
    self.windows[slot]=stage==1 and now+3 or nil
end
function Clear:q2Estimate(target,health)
    local c=self.ctx;local p=c.profile;local rank=c:spell(0).level or 0
    if rank==0 then return 0 end
    local base=(p.qBase[rank] or 0)+p.qRatio*(myHero.bonusDamage or 0)
    local missing=math.max(0,(target.maxHealth or 0)-health)
    local raw=p.id=='classic' and base+missing*.08 or base*(1+missing/math.max(1,target.maxHealth or 1))
    local cap=c.config:get('monsterQCap');if target.team==300 and cap and cap>0 then raw=math.min(raw,cap) end
    return c.sdk.Damage:CalculateDamage(myHero,target,c.sdk.DAMAGE_TYPE_PHYSICAL,raw)
end
function Clear:q2Timing(target)
    local c=self.ctx;local left=c:markLeft(target);local lead=math.max(.25,c.latency+c.jitter*2)
    if left<=lead then return 'cast' end
    local damage=self:q2Estimate(target,target.health)
    if damage>=target.health+(target.allShield or 0) then return 'cast' end
    if U.dist(myHero.pos,target.pos)>c:attackRange(target) then return 'cast' end
    local attack=c.sdk.Attack;local cycle=attack.GetAnimation and attack:GetAnimation() or 1
    local wait=attack.IsReady and not attack:IsReady() and math.max(0,(attack.ServerStart or c:now())+cycle-c:now()) or 0
    local impact=wait+c:windup()+c.latency*.5;local aa=c:aaDamage(target)
    local qTime=.15+U.dist(myHero.pos,target.pos)/1800
    if impact+lead>=left then return 'cast' end
    local hp=target.health+(target.allShield or 0)
    local after=math.max(0,hp-aa);local qAfter=self:q2Estimate(target,after)
    local afterQ=math.ceil(math.max(0,after-qAfter)/math.max(1,aa))
    -- The Q dash overlaps the remaining attack cooldown; do not add a full
    -- attack cycle on top of it and accidentally prefer an extra auto.
    local aaFirst=after<=0 and impact or afterQ==0 and impact+qTime
        or math.max(wait+cycle,impact+qTime)+c:windup()+c.latency*.5+(afterQ-1)*cycle
    local qFirst=math.max(wait,qTime)+c:windup()+c.latency*.5+math.max(0,math.ceil((hp-damage)/math.max(1,aa))-1)*cycle
    -- Estimated clear-time comparison, separate from verified objective damage.
    -- Waiting consumes no recast; mark expiry and actual HP are checked again.
    if aaFirst<qFirst-.03 then return 'attack' end
    return 'cast'
end
function Clear:expiryTick()
    local c=self.ctx;self:observe()
    if c:blocked() or c:recalling() or c:dash() or c.wards.pending or c.combat.insec
        or c.mode=='farm' and (c.farm.recallAction or c.farm.state=='recalling')
        or c.input:held('wardKey') or c.leveling.pending or c.sdk.Orbwalker:IsAutoAttacking() then return false end
    local lead=math.max(.3,c.latency+c.jitter*2)
    local prefix=c.mode=='farm' and 'autoClear' or c.mode=='clear' and 'jungle'
    if prefix and c.config:get(prefix..'Abilities') and c.config:get(prefix..'Q2') and c:stage(0)==2 and c:ready(0) then
        for _,m in ipairs(c.minions or {}) do
            local left=m.team==300 and U.valid(m) and c:markLeft(m) or 0
            if left>0 and left<=lead+c:windup() then return false end -- Let the jungle controller rescue Q2 first.
        end
    end
    for slot=1,2 do
        local window=self.windows[slot]
        if c.config:get(slot==1 and 'expiryW' or 'expiryE') and c:stage(slot)==2 and window
            and window>c:now() and window-c:now()<=lead and c:ready(slot)
            and (myHero.mana or 0)-(c:spell(slot).mana or 0)>=c.config:get('recastReserve') then
            if slot==1 then if c.spells:w(myHero,'expiry') then return true end
            else
                for _,list in ipairs({c.enemies or {},c.minions or {}}) do for _,target in ipairs(list) do
                    if U.valid(target) and target.team~=myHero.team and c.spells:e(target,'expiry') then return true end
                end end
            end
        end
    end
    return false
end

function Clear:q1Target(target)
    local c=self.ctx;local best=target
    if target.team~=300 then return best end
    for _,camp in pairs(c.farm.known) do
        local contains=false
        for _,m in ipairs(camp.members or {}) do if U.same(m,target) then contains=true;break end end
        if contains then
            for _,m in ipairs(camp.members) do
                if U.valid(m) and (m.maxHealth or 0)>(best.maxHealth or 0)
                    and U.dist(myHero.pos,m.pos)<=c.profile.qRange and #c.spells:blockers(m,m.pos)==0 then best=m end
            end
            break
        end
    end
    return best
end

function Clear:tick(target,owner,beforeAttack)
    local c=self.ctx;self:observe()
    if owner=='farm' and not c.farm:ordinaryTarget(target) then return false end
    if not U.valid(target) or target.team==myHero.team or c:dash() then return false end
    local now=c:now();local distance=U.dist(myHero.pos,target.pos)
    if self.targetID~=U.id(target) then self.targetID=U.id(target);self.engagedAt=now end
    local melee=distance<=c:attackRange(target)+35
    if not melee and beforeAttack then return false end
    local hp=U.hp(myHero);local weaving=melee and self:weaving()
    local lead=math.max(.3,c:windup()+c.latency+c.jitter*2+.1)
    local function expiring(slot) return self.windows[slot] and self.windows[slot]-now<=lead end
    if target.team==300 then
        for _,camp in pairs(c.farm.known) do
            for _,m in ipairs(camp.members or {}) do if U.same(m,target) then camp.lastFoughtAt=now;break end end
        end
    end
    local qMarked=c:mark(target)

    -- Never throw away a confirmed Q mark solely to finish two passive attacks.
    local qTarget=qMarked and target
    if not qTarget and target.team==300 then
        for _,camp in pairs(c.farm.known) do
            local contains=false;for _,m in ipairs(camp.members or {}) do if U.same(m,target) then contains=true end end
            if contains then for _,m in ipairs(camp.members) do if U.valid(m) and c:mark(m) then qTarget=m;break end end end
        end
    end
    if target.team==300 then self:diagnoseQ(target,qTarget,owner) end
    if c.config.capture and target.team==300 and not qTarget and now>=(self.qDiagnosticAt or 0) then
        local last=self.lastCast[0]
        if c:stage(0)==2 or last and last.stage==1 and now-last.at>.4 and now-last.at<3.5 then
            local buffs={}
            for index=0,math.min(32,target.buffCount or 0) do
                local b=target.GetBuff and target:GetBuff(index)
                if b and b.name and b.name~='' then buffs[#buffs+1]={name=b.name,count=b.count,stacks=b.stacks,
                    expireTime=b.expireTime,endTime=b.endTime,source=b.sourcenID,sourceID=b.sourceID} end
            end
            local d=c:spell(0);self.qDiagnosticAt=now+2
            if c.config.capture then c:log('q2_wait',{reason='No recognized confirmed mark',name=d.name,stage=c:stage(0),toggleState=d.toggleState,
                ready=c:ready(0),target=U.id(target),buffs=buffs}) end
        end
    end
    local prefix=owner=='farm' and 'autoClear' or 'jungle'
    local rescueQ=qTarget and c.config:get(prefix..'Abilities') and c.config:get(prefix..'Q2')
        and (not c.config:get('jungleQ2MeleeOnly') or U.dist(myHero.pos,qTarget.pos)<=c:jungleQ2Range(qTarget))
    if rescueQ and self:q2Estimate(qTarget,qTarget.health)>=U.effectiveHP(qTarget) then
        -- A lethal estimate is already a useful timing decision. Do not gate
        -- jungle execution on the separately unverified damage-overlay toggle.
        if self:cast(0,qTarget,owner,true) then return true end
    end
    if rescueQ and c:markLeft(qTarget)<=lead then
        if self:cast(0,qTarget,owner,true) then return true end
        return false -- Do not spend its last cast opportunity on another ability.
    end
    if target.team==300 and c.smite:clear(target,owner) then return true end
    if target.team==300 and c.actives:potions(owner) then return true end
    -- Cleave resets belong immediately after the attack, before another spell
    -- can consume that dispatch opportunity. All item/range toggles still apply.
    if target.team==300 and c.lastAttackFinished and now-c.lastAttackFinished<.3 and c.actives:tick(target,owner) then return true end
    if target.team==300 and hp>=45 and c:ready(2) and c:stage(2)==1
        and c.config:get(prefix..'Abilities') and c.config:get(prefix..'E')
        and (myHero.mana or 0)-(c:spell(2).mana or 0)>=30 then
        local count,total,kills=0,0,0
        for _,camp in pairs(c.farm.known) do
            local contains=false;for _,m in ipairs(camp.members or {}) do if U.same(m,target) then contains=true;break end end
            if contains then
                for _,m in ipairs(camp.members) do
                    if c.spells:eHits(m) then
                        local damage=c:spellDamageEstimate(2,m,1)
                        count=count+1;total=total+math.min(m.health,damage)
                        if damage>=m.health then kills=kills+1 end
                    end
                end
                break
            end
        end
        if count>=2 and (kills>0 or total>=c:aaDamage(target)*2) then
            if self:cast(2,target,owner) then if c.config.capture then c:log('clear_aoe_priority',{targets=count,estimatedDamage=total,kills=kills}) end;return true end
        end
    end
    if qTarget and c.config:get('clearQTiming') and not beforeAttack then
        local decision=self:q2Timing(qTarget);self.qTiming=decision
        if decision=='cast' and weaving and U.dist(myHero.pos,qTarget.pos)<=c:attackRange(qTarget) then
            local plan=self:passivePlan(0,qTarget,owner)
            if plan.drought and not plan.danger then
                decision='attack';self.qTiming=decision;self:passiveReason(plan,'Preserve Q2 refresh across cooldown gap')
            end
        end
        if decision=='cast' and self:cast(0,qTarget,owner) then return true end
    end
    -- Fit Q1 inside an observed attack cooldown at surplus energy; two
    -- passive autos are a preference, not a mandatory delay on useful damage.
    local attack=c.sdk.Attack
    if target.team==300 and weaving and not beforeAttack and hp>=75 and c:stage(0)==1 and c:ready(0)
        and (myHero.mana or 0)-(c:spell(0).mana or 0)>=100
        and attack and attack.IsReady and not attack:IsReady() and attack.GetAnimation and attack.ServerStart then
        local wait=attack.ServerStart+attack:GetAnimation()-now
        if wait>.25+c.latency+.05 then
            local q1=self:q1Target(target)
            -- At full target HP the clear Q2 estimate is its shared Q1 base.
            -- Objective accounting intentionally returns zero for an unknown
            -- monster cap; that must not disable ordinary clear decisions.
            if q1.health>c:aaDamage(q1)*3 and self:q2Estimate(q1,q1.maxHealth)>=c:aaDamage(q1)
                and not self:passivePlan(0,q1,owner).drought then
                if self:cast(0,q1,owner) then if c.config.capture then c:log('clear_tempo_q',{target=U.id(q1),nextAttackIn=wait}) end;return true end
            end
        end
    end
    -- Re-evaluate W1 each cooldown cycle, even if an unrelated buff is stale.
    if melee and c:ready(1) and c:stage(1)==1 and (hp<75 or not weaving) then
        if self:cast(1,target,owner) then return true end
    end
    if melee and c:ready(1) and c:stage(1)==2 then
        local sustainActive=now<(self.sustainUntil or 0)
        local endingSoon=hp<98 and self:remainingHealth(target)<=c:aaDamage(target)*3
        local plan=weaving and self:passivePlan(1,target,owner)
        local early=plan and (plan.danger or hp<60 and not plan.drought)
        if plan then self:passiveReason(plan,expiring(1) and 'W2 expiry' or endingSoon and 'W2 final camp sustain'
            or early and (plan.danger and 'W2 incoming damage risk' or 'W2 sustain with another refresh available')
            or 'Keep passive attacks before W2') end
        if expiring(1) or (not sustainActive and (not weaving or early or endingSoon)) then
            if self:cast(1,target,owner) then return true end
        end
    end
    if c:stage(2)==2 then
        local plan=weaving and c.profile.id=='classic' and hp<60 and self:passivePlan(2,target,owner)
        if expiring(2) or not weaving or plan and plan.danger then
            if plan then self:passiveReason(plan,'E2 incoming damage risk') end
            if self:cast(2,target,owner) then return true end
        end
    end
    if weaving then return false end
    if (myHero.mana or 0)/math.max(1,myHero.maxMana or 200)*100<c.config:get('clearEnergy') then return false end
    if c:stage(0)==1 then
        if self:cast(0,self:q1Target(target),owner) then return true end
    end
    if c:stage(2)==1 and self:cast(2,target,owner) then return true end
    if qTarget and (not c.config:get('clearQTiming') or self:q2Timing(qTarget)=='cast') then return self:cast(0,qTarget,owner) end
    return false
end

function Clear:diagnoseQ(target,marked,owner)
    if not self.ctx.config.capture then return end
    local c=self.ctx;local now=c:now();local d=c:spell(0)
    if (d.level or 0)==0 then c.qDebug=nil;return end
    local stage=c:stage(0,marked);local prefix=owner=='farm' and 'autoClear' or 'jungle'
    local enabled=c.config:get(prefix..'Abilities') and c.config:get(prefix..'Q2')
    local reason=not enabled and 'Q2 disabled' or not marked and 'No recognized target mark'
        or c.config:get('jungleQ2MeleeOnly') and U.dist(myHero.pos,marked.pos)>c:jungleQ2Range(marked) and 'Outside configured Q2 clear range'
        or not c:ready(0) and 'Native castability / energy'
        or c.actions.pending[0] and 'Waiting for Q acknowledgement'
        or c.spells.q2LastRequest and now-c.spells.q2LastRequest<.5 and 'Q2 key sent'
        or self.qTiming=='attack' and 'Weaving before Q2' or 'Q2 eligible'
    c.qDebug={at=now,text='Q stage '..stage..' | '..reason..' | '..tostring(d.name)}
    if c.q2Outcome and now-c.q2Outcome.at<2 then c.qDebug.text=c.qDebug.text..' | '..c.q2Outcome.text end
    if now<(self.qStateLogAt or 0) then return end
    self.qStateLogAt=now+1
    local function buffs(unit)
        local result={}
        for index=0,math.min(32,unit.buffCount or 0) do
            local b=unit.GetBuff and unit:GetBuff(index)
            if b and b.name and b.name~='' then result[#result+1]={name=b.name,count=b.count,stacks=b.stacks,
                expireTime=b.expireTime,endTime=b.endTime,source=b.sourcenID,sourceID=b.sourceID} end
        end
        return result
    end
    if c.config.capture then c:log('jungle_q_state',{reason=reason,owner=owner,name=d.name,stage=stage,rank=d.level,cd=d.currentCd,
        toggleState=d.toggleState,useState=Game.CanUseSpell(0),energy=myHero.mana,cost=d.mana,
        target=U.id(target),targetName=target.charName,targetBuffs=buffs(target),heroBuffs=buffs(myHero),
        markedTarget=U.id(marked),markLeft=marked and c:markLeft(marked),lastDecision=c.spells.q2Decision,
        cursorStep=c.sdk.Cursor.Step,lastQRequest=c.spells.q2LastRequest,build=require('lho.profiles').build}) end
end

require('lho.clearreserve')(Clear)
return Clear
