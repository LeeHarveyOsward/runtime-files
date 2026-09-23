local U=require('lho.util');local P=require('lho.profiles')
local S={};S.__index=S
local collisionOptions={padding=0,trim=0}
local function finite(value) return type(value)=='number' and value==value and math.abs(value)<math.huge end
local function pathEnd(target)
    return target and (target.posTo or target.pathing and target.pathing.endPos or target.pos)
end
function S.new(ctx,actions,smite) pcall(require,'GGPrediction');return setmetatable({ctx=ctx,actions=actions,smite=smite},S) end
function S:q1Status(target,owner,reason)
    local c=self.ctx;if not c.config.capture then return end
    self.q1Decision={at=c:now(),target=U.id(target),owner=owner,reason=reason}
    c:trace('q1_decision',self.q1Decision,tostring(U.id(target))..':'..tostring(owner)..':'..reason,.5)
end
function S:q1Useful(target,pos)
    if not target then return true end -- Fog probes have separate camp evidence.
    local c=self.ctx;local delay=.25+U.dist(myHero.pos,pos or target.pos)/c.profile.qSpeed
    local reason,predicted
    if c:attackFinishesBefore(target,delay) then reason='own_attack_finishes_first'
    elseif target.team==300 or target.type and myHero.type and target.type~=myHero.type then
        predicted=c:healthAt(target,delay)
        if predicted<=0 then reason='target_dies_before_q1' end
    end
    if not reason then return true end
    if c.config.capture then
        local active=myHero.activeSpell
        c:trace('q1_conserved',{target=U.id(target),reason=reason,health=target.health,predictedHP=predicted,
            impactDelay=delay,ownAttackTarget=active and active.target,ownAttackEnd=active and active.castEndTime},
            tostring(U.id(target))..':'..reason,.25)
    end
    return false,reason
end
-- Shared, input-free rules for planning and the final send boundary.
function S:allowed(slot,target,owner,plan)
    local c=self.ctx;local stage=plan.stage
    if not c:abilityEnabled(slot,stage,owner,target,plan.abilityPolicy) then return false,'disabled_for_mode' end
    if plan.abilityPolicy then
        local prefix=plan.abilityPolicy
        local ability=({[0]=stage==2 and 'Q2' or 'Q',[1]='W',[2]='E'})[slot]
        if not c.config:get(prefix..'Abilities') or ability and not c.config:get(prefix..ability) then return false,'disabled_for_mode' end
    end
    if plan.waveHarass and (not c.config:get('waveHarass') or not c.config:get('harassQ')) then return false,'wave_harass_disabled' end
    if owner=='killsteal' then
        local option=slot==0 and (stage==2 and 'killQ2' or 'killQ') or slot==2 and 'killE' or slot==3 and 'killR'
        if option and not c.config:get(option) then return false,'killsteal_disabled' end
        local lock=c:locked()
        if lock and not U.same(target,lock) then return false,'selected_target_changed' end
    elseif owner=='expiry' then
        if not c.config:get(slot==1 and 'expiryW' or 'expiryE')
            or c.wards.pending or c.combat.insec or c.input:held('wardKey')
            or (myHero.mana or 0)-(c:spell(slot).mana or 0)<c.config:get('recastReserve') then return false,'expiry_assist_unavailable' end
    end
    if (owner=='fight' or owner=='harass' or owner=='expiry' or owner=='killsteal') and c:combatTransit() then return false,'engage_in_flight' end
    if c:blocked() or not c:ready(slot) then return false,'spell_unavailable' end
    if slot<3 and c:stage(slot,target)~=stage then return false,'spell_stage_changed' end
    if target and not U.valid(target) then return false,'target_unavailable' end
    if slot==0 then
        if c:dash() then return false,'dash_active' end
        if owner=='farm' and target and P.epics[P.category(target.charName)] then return false,'boss_excluded' end
        if stage==2 then
            if not target or not c:mark(target) then return false,'q2_mark_missing' end
            if U.dist(myHero.pos,target.pos)>c.profile.q2Range then return false,'q2_out_of_range' end
            local travel=plan.travel and owner=='farm' and c.config:get('farmQTravel')
                and ((plan.travelTarget and c.farm.travelTarget==plan.travelTarget)
                    or (plan.probe and c.farm.probe==plan.probe))
            if not travel and (owner=='farm' or owner=='clear') and c.config:get('jungleQ2MeleeOnly')
                and U.dist(myHero.pos,target.pos)>c:jungleQ2Range(target) then return false,'q2_clear_range' end
            if not plan.deliberate and c.config:get('q2Safety') and c:underTurret(target.pos) then return false,'q2_turret_safety' end
        else
            local pos=plan.shot
            if not pos or U.dist(myHero.pos,pos)>c.profile.qRange then return false,'q1_shot_out_of_range' end
            local useful,reason=self:q1Useful(target,pos);if not useful then return false,reason end
            local collisionEnd=pos
            if target then
                -- Preserve an already accepted confidence decision briefly on
                -- the SAME path. GG's high-confidence 150ms new-path window can
                -- end while this request waits for the cursor. Recompute the
                -- intercept at normal confidence, and still validate this exact
                -- shot and its collision; a changed path gets the full policy.
                local predicted=self:planPrediction(target,plan)
                if not predicted then return false,'q1_prediction_unavailable' end
                -- A line spell continues beyond its original aiming point.
                -- Validate the ray, then collision only as far as the refreshed
                -- target intercept. A blocker behind the target is irrelevant.
                local origin=myHero.pos;local length=U.dist(origin,pos)
                if length<1 then return false,'q1_shot_no_longer_suitable' end
                local dx,dz=(pos.x-origin.x)/length,(pos.z-origin.z)/length
                local along=(predicted.x-origin.x)*dx+(predicted.z-origin.z)*dz
                local across=math.abs((predicted.x-origin.x)*dz-(predicted.z-origin.z)*dx)
                if along<=0 or along>c.profile.qRange or across>c.profile.qRadius+(target.boundingRadius or 35)*.5 then
                    if c.config.capture then c:trace('q1_ray_rejected',{target=U.id(target),along=along,across=across,
                        allowedAcross=c.profile.qRadius+(target.boundingRadius or 35)*.5,
                        origin=U.copy(origin),shot=U.copy(pos),prediction=U.copy(predicted)},tostring(U.id(target)),.4) end
                    return false,'q1_shot_no_longer_suitable'
                end
                collisionEnd={x=origin.x+dx*along,y=pos.y,z=origin.z+dz*along}
            end
            if self:projectileWall(collisionEnd,nil,U.id(target)) then return false,'q1_projectile_blocked' end
            local blockers=self:blockers(target,collisionEnd)
            if #blockers>0 then self:traceCollision(target,collisionEnd,blockers,'dispatch');return false,'q1_collision' end
        end
    elseif slot==2 then
        if not target then return plan.independent==true,'e_target_required' end
        if U.dist(myHero.pos,target.pos)>(stage==2 and c.profile.e2Range or c.profile.eRange) then return false,'e_out_of_range' end
        if stage==1 and target.team==300 and (owner=='farm' or owner=='clear')
            and not self:eHits(target) then return false,'e_impact_out_of_range' end
        if stage==2 and not U.buff(target,P.eMarks,c:now()) then return false,'e2_mark_missing' end
    elseif slot==1 then
        if c:dash() then return false,'dash_active' end
        if stage==1 and (not target or target.team~=myHero.team or U.dist(myHero.pos,target.pos)>c.profile.wRange) then return false,'w_target_or_range' end
    elseif slot==3 then
        if not c:enemyValid(target) or U.dist(myHero.pos,target.pos)>c.profile.rRange or c:dash()
            or c.combat:kickProtected(target) then return false,'r_target_or_protection' end
    elseif U.name(c:spell(slot).name)=='summonerflash' then
        if not plan.shot or U.dist(myHero.pos,plan.shot)>400 or c.terrain:wall(plan.shot)==true then return false,'flash_position_invalid' end
        if owner=='insec' and not c.combat.planner:flashAllowed(c.combat.insec) then return false,'flash_not_authorized' end
    end
    if owner=='killsteal' and target and c:combatDamage(slot,target,stage)
        <U.typedHP(target,slot==2 and 'magic' or 'physical')+c.config:get('combatDamageMargin')+(target.hpRegen or 0)*.8 then
        return false,'kill_no_longer_lethal'
    end
    return true
end
function S:submit(slot,castTarget,target,owner,opts,plan)
    opts=opts or {};plan=plan or {};plan.stage=plan.stage or (slot<3 and self.ctx:stage(slot,target))
    if slot<3 and not plan.abilityPolicy then
        if owner=='farm' and not plan.travel then plan.abilityPolicy='autoClear'
        elseif owner=='clear' then
            plan.abilityPolicy=self.ctx.mode=='gg_last' and 'last' or target and target.team==300 and 'jungle'
                or target and not U.same(target,myHero) and 'wave' or nil
        end
    end
    if owner=='clear' and slot==0 and target then
        for _,enemy in ipairs(self.ctx.enemies or {}) do
            if U.same(enemy,target) then plan.waveHarass=true;break end
        end
    end
    local extra=opts.validate
    opts.abilityPolicy=plan.abilityPolicy
    opts.validate=function()
        local ok,why=self:allowed(slot,target,owner,plan);if not ok then return false,why end
        if extra then return extra() end;return true
    end
    local ok,why=opts.validate();if not ok then return false,why end
    if slot==0 and plan.stage==1 and target and self.actions.capabilities
        and (self.actions.capabilities.resolveWorldTarget or self.actions.capabilities.resolveBeforeHandoff) then
        plan.resolvePrediction=true
        local function resolve(context)
            if not U.valid(target) or not self.ctx:ready(0) or self.ctx:stage(0)~=1 or self.ctx:dash() then return nil,'spell_unavailable' end
            -- One fresh prediction per resolver pass. Repeated mechanical
            -- checks in that same pass may reuse it while geometry is identical.
            plan.predictionSample=nil
            local point=self:planPrediction(target,plan)
            if not point then return nil,'q1_prediction_unavailable' end
            local valid,reason
            -- Once positioned, keep the existing ray only if fresh prediction,
            -- collision and every gameplay condition still approve that ray.
            -- Following each tiny intercept change can otherwise starve send.
            if context and (context.revision or 0)>0 and context.position then
                plan.shot=U.copy(context.position)
                valid,reason=opts.validate()
                if valid then point=plan.shot end
            end
            if not valid then plan.shot=U.copy(point);valid,reason=opts.validate() end
            if not valid then return nil,reason end
            return {position=U.copy(point),data={targetID=U.id(target),origin=U.copy(myHero.pos),
                flightDuration=.25+U.dist(myHero.pos,point)/self.ctx.profile.qSpeed+self.ctx.latency+2*self.ctx.jitter+.10}}
        end
        opts.resolveWorldTarget=function(context)return U.withBuffScope(resolve,context)end
    end
    return self.actions:cast(slot,castTarget,owner,opts)
end
function S:planPrediction(target,plan)
    local c=self.ctx;local accepted=plan.prediction
    local sample=plan.predictionSample;local now=c:now();local path=pathEnd(target)
    local policy=c.config:get('hitchance')
    if plan.resolvePrediction and sample and sample.at==now and sample.policy==policy
        and target.visible==sample.visible and U.dist(myHero.pos,sample.origin)<.001
        and U.dist(target.pos,sample.target)<.001 and U.dist(path,sample.path)<.001 then
        return U.copy(sample.point)
    end
    local continuous=accepted and accepted.policy==c.config:get('hitchance') and accepted.policy<=2
        and c:now()-accepted.at<=.25 and target.visible~=false
        and U.dist(pathEnd(target),accepted.path)<1
    local point=self:predict(target,continuous and (_G.GGPrediction and GGPrediction.HITCHANCE_NORMAL or 2) or nil)
    if point and plan.resolvePrediction then
        plan.predictionSample={at=now,policy=policy,visible=target.visible,origin=U.copy(myHero.pos),target=U.copy(target.pos),path=U.copy(path),point=U.copy(point)}
    end
    return point
end
local function pointKey(p) return p and (tostring(p.x)..','..tostring(p.y)..','..tostring(p.z)) or '-' end
function S:memo(kind,key,fn)
    local cycle=U.buffScopeKey()
    if not cycle then return fn() end
    if self.memoCycle~=cycle or self.memoTime~=self.ctx:now() then self.memoCycle=cycle;self.memoTime=self.ctx:now();self.memoData={} end
    local full=kind..':'..key;local cached=self.memoData[full]
    if cached then return cached.value end
    local value=fn();self.memoData[full]={value=value};return value
end
function S:predictionFailure(kind,err)
    self.failures=self.failures or {}
    local reason=tostring(err)
    if self.failures[kind]~=reason then
        self.failures[kind]=reason;if self.ctx.config.capture then self.ctx:log('prediction_unavailable',{name=kind,reason=reason}) end
    end
end
function S:collisionRaw(origin,pos,types,targetID)
    local gg=_G.GGPrediction;local p=self.ctx.profile
    local options=gg.CollisionOptions and collisionOptions or nil
    local ok,wall,objects,count=pcall(gg.GetCollision,gg,U.copy(origin),U.copy(pos),p.qSpeed,.25,p.qRadius,types,targetID,options)
    if not ok or objects~=nil and type(objects)~='table' then
        self:predictionFailure('collision',not ok and wall or 'Invalid collision object list')
        return true,{},0 -- Unknown obstruction must not turn into a clear shot.
    end
    for _,unit in ipairs(objects or {}) do
        if (type(unit)~='table' and type(unit)~='userdata') or not unit.pos then
            self:predictionFailure('collision','Invalid collision object');return true,{},0
        end
    end
    return wall,objects,count
end
function S:collision(origin,pos,types,targetID)
    local key=pointKey(origin)..':'..pointKey(pos)..':'..table.concat(types,',')..':'..tostring(targetID)
    local row=self:memo('collision',key,function()
        local wall,objects,count=self:collisionRaw(origin,pos,types,targetID)
        return {wall=wall,objects=objects,count=count}
    end)
    local objects={};for i,v in ipairs(row.objects or {})do objects[i]=v end
    return row.wall,objects,row.count
end
function S:projectileWall(pos,origin,targetID)
    local gg=_G.GGPrediction;origin=origin or myHero.pos
    if not gg or not gg.GetCollision then return false end
    return self:collision(origin,pos,{gg.COLLISION_YASUOWALL or 3},targetID)==true
end
function S:predictRaw(target,required)
    local c=self.ctx;local p=c.profile;local gg=_G.GGPrediction
    if not U.valid(target) or U.dist(myHero.pos,target.pos)>p.qRange then return nil end
    if not gg then
        -- No unqualified raw-position shots at moving champions.
        if target.team==300 or not (target.pathing and target.pathing.hasMovePath) then return U.copy(target.pos) end
        return nil
    end
    local minion=target.team==300 or target.type~=myHero.type
    for _,m in ipairs(c.minions or {}) do if U.same(m,target) then minion=true;break end end
    local ok,pos=pcall(function()
        -- Prediction output is consumed synchronously and copied below. Reuse
        -- one model per range policy instead of rebuilding its methods each cast.
        local signature=tostring(p.qRange)..':'..tostring(p.qSpeed)..':'..tostring(p.qRadius)
        if self.predictionProvider~=gg or self.predictionFactory~=gg.SpellPrediction or self.predictionSignature~=signature then
            self.predictionModels={};self.predictionProvider=gg;self.predictionFactory=gg.SpellPrediction;self.predictionSignature=signature
        end
        local key=minion and 'minion' or 'hero';local prediction=self.predictionModels[key]
        if not prediction then
            prediction=gg:SpellPrediction({Type=gg.SPELLTYPE_LINE,Delay=.25,Radius=p.qRadius,
                Range=minion and math.huge or p.qRange,Speed=p.qSpeed,Collision=false})
            self.predictionModels[key]=prediction
        end
        prediction:GetPrediction(target,myHero)
        local hitchance=required or ({gg.HITCHANCE_NORMAL or 2,gg.HITCHANCE_HIGH or 3,gg.HITCHANCE_IMMOBILE or 4})[c.config:get('hitchance')]
        if minion then hitchance=gg.HITCHANCE_NORMAL or 2 end
        if not prediction.CastPosition or not prediction:CanHit(hitchance) then
            if c.config.capture then c:trace('q1_prediction_rejected',{target=U.id(target),name=target.charName,
                reason=prediction.LastFailureReason or (not prediction.CastPosition and 'prediction_unavailable' or 'provider_rejected'),
                required=hitchance,actual=prediction.HitChance,distance=U.dist(myHero.pos,target.pos),
                pos=U.copy(prediction.CastPosition),impact=prediction.TimeToHit},tostring(U.id(target)),.4) end
            return nil
        end
        local pos=U.copy(prediction.CastPosition)
        if minion then pos.y=target.pos.y or 0 end -- Bypass GG's champion range-margin conversion.
        if not finite(pos.x) or not finite(pos.y) or not finite(pos.z) then error('Invalid predicted position') end
        return pos
    end)
    if not ok then self:predictionFailure('position',pos);return nil end
    if not pos then return nil end
    if U.dist(myHero.pos,pos)>p.qRange then return nil end
    if self:projectileWall(pos,nil,U.id(target)) then return nil end
    return pos
end
function S:blockersRaw(target,pos,origin)
    local result={};local c=self.ctx
    origin=origin or myHero.pos
    local known={};local gg=_G.GGPrediction
    if gg and gg.GetCollision then
        local collision,objects=self:collision(origin,pos,{gg.COLLISION_MINION or 0,gg.COLLISION_ENEMYHERO or 2},U.id(target))
        if collision and (not objects or #objects==0) then result[#result+1]={unknownCollision=true} end
        for _,u in ipairs(objects or {}) do
            result[#result+1]=u;if U.id(u) then known[U.id(u)]=true end
        end
    end
    for _,list in ipairs({c.minions or {},c.enemies or {}}) do
        for _,u in ipairs(list) do
            if U.valid(u) and u.team~=myHero.team and not U.same(u,target) and not known[U.id(u)] then
                local d,t=U.segment(u.pos,origin,pos)
                local hit=t>0 and t<1 and d<c.profile.qRadius+(u.boundingRadius or 45)
                if not hit and u.GetPrediction and u.pathing and u.pathing.hasMovePath then
                    local ok,predicted=pcall(function()return U.copy(u:GetPrediction(c.profile.qSpeed,.25))end)
                    if not ok or not predicted or not finite(predicted.x) or not finite(predicted.z) then
                        self:predictionFailure('blocker',not ok and predicted or 'Blocker prediction unavailable')
                        result[#result+1]={unknownCollision=true}
                    else d,t=U.segment(predicted,origin,pos);hit=t>0 and t<1 and d<c.profile.qRadius+(u.boundingRadius or 45) end
                end
                if hit then result[#result+1]=u end
            end
        end
    end
    return result
end
function S:predict(target,required)
    local key=tostring(U.id(target))..':'..pointKey(target and target.pos)..':'..pointKey(myHero.pos)..':'..pointKey(pathEnd(target))
        ..':'..tostring(required or self.ctx.config:get('hitchance'))..':'..tostring(target and target.visible)
        ..':'..tostring(required~=nil)
    local value=self:memo('predict',key,function()return self:predictRaw(target,required)end)
    return value and U.copy(value)
end
function S:blockers(target,pos,origin)
    local key=tostring(U.id(target))..':'..pointKey(origin or myHero.pos)..':'..pointKey(pos)
    local value=self:memo('blockers',key,function()return self:blockersRaw(target,pos,origin)end)
    local out={};for i,v in ipairs(value)do out[i]=v end;return out
end
function S:traceCollision(target,pos,blockers,phase)
    local c=self.ctx;if not c.config.capture then return end
    local u=blockers[1];local distance=u and u.pos and U.segment(u.pos,myHero.pos,pos)
    c:trace('q1_collision_rejected',{target=U.id(target),phase=phase,blocker=U.id(u),
        blockerName=u and u.charName,blockerPos=u and U.copy(u.pos),blockerRadius=u and u.boundingRadius,
        rayDistance=distance,qRadius=c.profile.qRadius,origin=U.copy(myHero.pos),shot=U.copy(pos),count=#blockers,
        preciseProvider=_G.GGPrediction and GGPrediction.CollisionOptions==true},tostring(U.id(target))..':'..phase,.4)
end
function S:q1(target,owner,smiteBlocker,validate)
    local c=self.ctx
    if not c:abilityEnabled(0,1,owner,target) then self:q1Status(target,owner,'disabled_for_mode');return false end
    if owner=='farm' and P.epics[P.category(target and target.charName)] then return false end
    if not c:ready(0) or c:stage(0)~=1 or c:dash() then self:q1Status(target,owner,'unavailable_stage_or_dash');return false end
    if not self:q1Useful(target) then return false end
    local pos=self:predict(target);if not pos then self:q1Status(target,owner,'prediction_rejected');return false end
    local blockers=self:blockers(target,pos)
    if #blockers>0 then
        self:q1Status(target,owner,'collision')
        self:traceCollision(target,pos,blockers,'planning')
        if smiteBlocker and #blockers==1 and c.config:get('autosmite') and blockers[1].team==300 and self.smite:clear(blockers[1],owner) then
            self.afterSmite={target=target,owner=owner,untilTime=c:now()+.7};return true
        end
        return false
    end
    local ok,event=self:submit(0,pos,target,owner,{intendedTarget=target,validate=validate},
        {stage=1,shot=U.copy(pos),prediction={at=c:now(),path=U.copy(pathEnd(target)),policy=c.config:get('hitchance')}})
    self:q1Status(target,owner,ok and 'requested_not_yet_proven_sent' or type(event)=='string' and event or 'dispatch_declined')
    if ok then
        local duration=.25+U.dist(myHero.pos,pos)/c.profile.qSpeed+c.latency+2*c.jitter+.10
        self.q1Flight={target=U.id(target),event=event,duration=duration,
            untilTime=(event.dispatchAt or c:now())+duration}
    end
    return ok,event
end
function S:q1Reservation(target)
    local flight=self.q1Flight;local c=self.ctx
    if not flight or flight.target~=U.id(target) then return nil end
    local event=flight.event;local sent=event.keyAt
    if self.actions.api then
        local action=self.actions:inputAction(event.cursorID)
        if not action or action.state=='cancelled_before_send' then return nil end
        if action.sentAt then
            sent=sent or c:now()-math.max(0,self.actions:inputNow()-action.sentAt)*.001
            local data=action.resolution and action.resolution.data
            if data and U.finite(data.flightDuration) then flight.duration=data.flightDuration end
        elseif not action.jobCancelled and not event.gameplayCancelled and not event.cancelled
            and event.status~='cancelled' and (action.state=='waiting' or action.state=='requested')
            and self.actions:inputNow()<(action.expires or 0) then
            return flight,'queued',math.max(0,(action.expires-self.actions:inputNow())*.001)
        else return nil end
    else
        if event.cancelled or event.status=='cancelled' then return nil end
        sent=sent or event.dispatchAt
    end
    -- Cancellation cannot unsend a projectile. A queued intent, however, has
    -- no flight time until its actual send timestamp is known.
    if not sent then return nil end
    local deadline=sent+flight.duration
    if c:now()<deadline then return flight,'in_flight',deadline-c:now() end
end
function S:q2(target,owner,deliberate,entry,travelEntry,validate)
    local c=self.ctx;local reason
    local plan={stage=2,deliberate=deliberate,travel=travelEntry,travelTarget=c.farm.travelTarget,probe=c.farm.probe}
    local allowed;allowed,reason=self:allowed(0,target,owner,plan)
    if not allowed then
        -- The same rule is checked again by submit immediately before sending.
    else
        local ok,event=self:submit(0,nil,target,owner,{delay=.15,urgent=entry,interrupt=entry,stage=2,intendedTarget=target,validate=validate},plan)
        if ok then
            self.q2LastRequest=c:now();self.q2Decision='Q2 key sent'
            if owner=='farm' or owner=='clear' then c.qDebug={at=c:now(),text='Q2: key sent | '..tostring(c:spell(0).name)} end
            return ok,event
        end
        reason=not c:ready(0) and 'Native castability / energy'
            or c.sdk.Orbwalker:IsAutoAttacking() and 'Attack windup' or 'Dispatcher reservation'
    end
    self.q2Decision=reason
    if owner=='farm' or owner=='clear' then c.qDebug={at=c:now(),text='Q2: '..reason..' | '..tostring(c:spell(0).name)} end
    if c:now()>=(self.q2LogAt or 0) then
        self.q2LogAt=c:now()+1;local d=c:spell(0)
        if c.config.capture then c:log('q2_blocked',{reason=reason,owner=owner,name=d.name,toggleState=d.toggleState,cd=d.currentCd,
            useState=Game.CanUseSpell(0),energy=myHero.mana,cost=d.mana,markLeft=target and c:markLeft(target),
            target=U.id(target),stage=c:stage(0),pending=self.actions.pending[0]~=nil}) end
    end
    return false
end
function S:q1Camp(pos,validate)
    return self:submit(0,U.copy(pos),nil,'farm',{delay=.25,validate=validate},{stage=1,shot=U.copy(pos)})
end
function S:eHits(target,origin)
    local c=self.ctx;origin=origin or myHero.pos
    if not U.valid(target) then return false end
    local point=target.pos;local path=target.pathing
    if path and path.hasMovePath and path.endPos then
        point=U.toward(point,path.endPos,math.min(U.dist(point,path.endPos),(target.ms or 0)*(.25+c.latency)))
    end
    -- Tempest stops Lee to cast: never credit future approach movement as its
    -- origin. Keep a small measured-latency allowance on a moving local origin.
    local moving=myHero.pathing and myHero.pathing.hasMovePath
    local margin=moving and (myHero.ms or 0)*(c.latency+c.jitter+.016) or 0
    return U.dist(origin,point)<=c.profile.eRange-margin
end
function S:e(target,owner,validate)
    return self:submit(2,nil,target,owner,{intendedTarget=target,validate=validate},{stage=self.ctx:stage(2),independent=false})
end
function S:w(target,owner,interrupt,abilityPolicy,validate)
    local stage=self.ctx:stage(1)
    if stage~=1 and stage~=2 then return false end
    target=stage==1 and (target or myHero) or nil
    return self:submit(1,target,target,owner,{interrupt=stage==1 and interrupt or nil,validate=validate,
        verifyHover=stage==1 and target and not U.same(target,myHero) or nil},{stage=stage,abilityPolicy=abilityPolicy})
end
function S:r(target,owner,interrupt,validate)
    return self:submit(3,target,target,owner,{interrupt=interrupt,urgent=owner=='insec',validate=validate})
end

function S:flash(pos,owner)
    for slot=4,5 do
        if U.name(self.ctx:spell(slot).name)=='summonerflash' then
            return self:submit(slot,pos,nil,owner,{interrupt=true,delay=.05},{shot=U.copy(pos)})
        end
    end
    return false
end
return S
