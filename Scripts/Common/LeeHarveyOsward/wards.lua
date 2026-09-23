local U=require('lho.util')
local Shared=require('ChampionMobility.wards')(U)
local W={};W.__index=W
function W.new(ctx,actions,terrain) return setmetatable({ctx=ctx,actions=actions,terrain=terrain},W) end
function W:available()
    return self.ctx:ready(1) and self.ctx:stage(1)==1 and not self.actions.pending[1]
end
function W:objects(force)
    local count=Game.WardCount and U.count(Game.WardCount(),512) or 0
    if not force and self.objectCache and self.objectAt==self.ctx:now() and self.objectCount==count then return self.objectCache end
    local result={}
    if Game.WardCount and Game.Ward then for i=1,count do local w=Game.Ward(i);if w then result[#result+1]=w end end end
    self.objectCache=result;self.objectAt=self.ctx:now();self.objectCount=count
    return result
end
function W:jumpable(u)
    local n=U.name(u and u.charName)
    return U.valid(u) and u.team==myHero.team and not U.same(u,myHero)
        and n~='bluetrinket' and n~='farsightward' and n~='zombieward'
        and U.dist(myHero.pos,u.pos)<=self.ctx.profile.wRange
end
W.itemReady=Shared.itemReady
W.hasCharges=Shared.hasCharges
function W:diagnostics(reason)
    if not self.ctx.config.capture then return end
    local c=self.ctx;local rows={}
    for slot=6,12 do
        local item=myHero:GetItemData(slot);local d=c:spell(slot)
        if item and (item.itemID or 0)>0 then rows[#rows+1]={slot=slot,id=item.itemID,name=d.name,
            spellSlot=c:spellSlot(slot),hotkey=self.actions:key(slot),
            supported=c.profile.wards[item.itemID]~=nil,cd=d.currentCd,useState=Game.CanUseSpell(c:spellSlot(slot)),
            spellAmmo=d.ammo,itemAmmo=item.ammo,stacks=item.stacks,stackCount=item.stackCount,ready=self:itemReady(slot,item)} end
    end
    if c.config.capture then c:log('ward_resolution',{reason=reason,wStage=c:stage(1),wReady=c:ready(1),items=rows}) end
end
W.slot=Shared.slot
function W:itemSlot(id) return self:slot(id) end
function W:canStart(destination)
    local c=self.ctx
    if not destination or not self:available() or c:dash() then return false end
    if self:existing(destination) then return true end
    return self:slot()~=nil and U.dist(myHero.pos,destination)<=self:range()
        and self.terrain:wall(destination)==false
end
function W:range(slot)
    slot=slot or self:slot();local range=slot and self.ctx:spell(slot).range
    local configured=self.ctx.config:get('wardRange')
    if not range or range<=0 or range>700 then range=configured
    else range=math.min(configured,math.max(50,range-25)) end
    return math.min(range,self.ctx.profile.wRange-15)
end
function W:existing(pos,tolerance)
    local result,dist=nil,tolerance or self.ctx.config:get('reuseRadius')
    local units={};for _,w in ipairs(self:objects()) do units[#units+1]=w end
    for _,u in ipairs(self.ctx.allies or {}) do units[#units+1]=u end
    for _,u in ipairs(self.ctx.minions or {}) do if u.team==myHero.team then units[#units+1]=u end end
    for _,u in ipairs(units) do
        local d=U.dist(pos,u.pos)
        if self:jumpable(u) and d<=dist then result,dist=u,d end
    end
    return result
end
function W:advance(job)
    if job.done or job.stepAt==self.ctx:now() then return job.result end
    job.stepAt=self.ctx:now()
    local ok,result=coroutine.resume(job.work)
    if not ok then
        job.done=true;job.result={valid=false,pos=job.raw,raw=job.raw,reason='Navigation calculation failed'}
        if self.ctx.config.capture then self.ctx:log('ward_planner_error',{reason=tostring(result)}) end
    elseif coroutine.status(job.work)=='dead' then job.done=true;job.result=result
    else job.result={valid=false,kind='planning',pos=job.raw,raw=job.raw,reason='Calculating approach',job=job} end
    return job.result
end
function W:resetPreview()
    self.previewCache=nil;self.previewState=nil;self.lastValid=nil
end
function W:planUsable(p)
    if not p or not p.valid or not self:available() or self.ctx:dash() then return false end
    if p.provider~=self.terrain.provider or p.wall~=(self.terrain.provider and self.terrain.provider.isWall)
        or self.terrain:wall(p.pos)~=false then return false end
    if p.kind=='assisted' and not self.ctx.config:get('wardAssist') then return false end
    if p.kind~='approach' then return self:canStart(p.pos) end
    if not self.ctx.config:get('wardApproach') or not self:slot() or not p.path or #p.path==0
        or U.dist(p.stand,p.pos)>self:range() then return false end
    local limit=self.ctx.config:get('wardWalkRange')
    if limit>0 and U.dist(myHero.pos,p.walkTo or p.stand)>limit then return false end
    if p.nativeRoute then
        local hit,out=self.terrain:crossing(p.walkTo,p.pos)
        local toward=(myHero.pos.x-p.walkTo.x)*(p.pos.x-p.walkTo.x)+(myHero.pos.z-p.walkTo.z)*(p.pos.z-p.walkTo.z)
        return hit~=nil and out~=nil and toward<=self:range()*35
            and self.terrain:clearance(p.walkTo,math.min(45,myHero.boundingRadius or 35),true)
    end
    local from=myHero.pos;local radius=math.min(45,myHero.boundingRadius or 35)
    -- Static routes need no repeat segment scan while Lee remains stationary.
    -- Live/custom providers always recheck; provider/function changes invalidate
    -- the whole plan above. A moving Lee gets a new connection check.
    if self.terrain.provider.static and p.checkedRadius==radius and U.dist(p.checkedOrigin,from)<.001 then return true end
    for _,point in ipairs(p.path) do
        if not self.terrain:walkLine(from,point,radius) then return false end
        from=point
    end
    p.checkedOrigin=U.copy(myHero.pos);p.checkedRadius=radius
    return true
end
function W:publish(p)
    if p.valid then
        p.provider=self.terrain.provider;p.wall=self.terrain.provider and self.terrain.provider.isWall
        self.lastValid=p;self.previewState=p
    elseif self:planUsable(self.lastValid) then self.previewState=self.lastValid
    else
        self.lastValid=nil
        self.previewState=p.kind=='planning' and {valid=false,pos=p.pos,raw=p.raw,reason='No verified landing yet'} or p
    end
    -- Calculations remain internal; a valid visible plan stays the release plan.
    return self.previewState.valid and self.previewState or p
end
function W:releasePreview(raw)
    local shown=self.previewState
    if shown and (shown.kind=='approach' or shown.kind=='assisted') then
        if self:planUsable(shown) then return shown end
        return {valid=false,pos=shown.pos,reason='Displayed wardjump is no longer reachable'}
    end
    -- No hold duration is required for a straightforward tap. Never commit an
    -- unfinished approach calculation that was not shown before release.
    local p=self:preview(raw)
    if p.kind=='planning' then return self.previewState end
    return p
end
function W:preview(raw,force)
    local now=self.ctx:now();local job=self.previewCache;local range=self:range()
    if raw and U.dist(myHero.pos,raw)<=range and self.terrain:wall(raw)==false then
        self.previewCache=nil
        local ready=self:available() and (self:slot() or self:existing(raw))~=nil
        return self:publish({valid=ready,pos=U.copy(raw),raw=U.copy(raw),kind='exact',
            reason=not ready and 'Safeguard or ward unavailable' or nil})
    end
    local cfg=self.ctx.config;local provider=self.terrain.provider;local static=provider and provider.static
    local sameContext=job and job.range==range and job.provider==provider and job.wall==(provider and provider.isWall)
        and job.assist==cfg:get('wardAssist') and job.approach==cfg:get('wardApproach')
        and job.radius==cfg:get('assistRadius') and job.maxWalk==cfg:get('wardWalkRange')
    local sameGeometry=sameContext and U.dist(job.origin,myHero.pos)<.001 and U.dist(job.raw,raw)<.001
    -- The common tap path never creates or resumes a pathfinding coroutine.
    local direct=sameGeometry and static and job.direct
        or self.terrain:landing(myHero.pos,raw,range,self.previewState)
    if direct.valid and direct.kind~='clamped' then
        self.previewCache=nil
        if not self:available() then direct.valid=false;direct.reason='Safeguard unavailable / already requested'
        elseif not self:slot() and not self:existing(direct.pos) then direct.valid=false;direct.reason='No jumpable ward available' end
        return self:publish(direct)
    end
    -- Finish the running job while the cursor moves. Restarting at each pixel
    -- starved the solver and erased its visible result on every refresh.
    if not sameContext or force or (job.done and (not sameGeometry or (not static and now-job.at>.2)))
        or (not sameGeometry and now-job.at>.35 and (U.dist(job.raw,raw)>80 or U.dist(job.origin,myHero.pos)>100)) then
        job={at=now,origin=U.copy(myHero.pos),raw=U.copy(raw),range=range,provider=self.terrain.provider,
            wall=self.terrain.provider and self.terrain.provider.isWall,direct=direct,
            assist=cfg:get('wardAssist'),approach=cfg:get('wardApproach'),radius=cfg:get('assistRadius'),maxWalk=cfg:get('wardWalkRange')}
        local previous=self.previewState
        job.work=coroutine.create(function()
            return self.terrain:plan(job.origin,job.raw,range,previous,function()coroutine.yield()end,job.direct)
        end)
        self.previewCache=job
    end
    local p=self:advance(job)
    if not self:available() then p={valid=false,pos=raw,raw=raw,reason='Safeguard unavailable / already requested'}
    elseif (p.valid or p.kind=='planning') and not self:slot() and not self:existing(p.pos) then
        p={valid=false,pos=raw,raw=raw,reason='No jumpable ward available'}
    end
    if p.valid then
        p.provider=self.terrain.provider;p.wall=self.terrain.provider and self.terrain.provider.isWall
        if not self:planUsable(p) then p={valid=false,pos=raw,raw=raw,reason='Calculated path is no longer reachable'} end
    end
    return self:publish(p)
end
function W:fastTick(actionsUpdated)
    local p=self.pending
    if not p or (p.state~='approaching' and p.state~='placing' and p.state~='waiting_w' and p.state~='jumping') then return end
    if not actionsUpdated then self.actions:tick() end
    self:tick()
end
function W:start(destination,owner,exact,resource,validate,followValidate)
    local c=self.ctx
    if c.config:get('reserveW') and owner=='fight' then return false end
    if self.pending or not destination or not self:available() or c:dash() then return false end
    if owner=='fight' and (c:combatTransit() or c:now()<(self.fightRetryAt or 0)) then return false end
    if validate and not validate() then return false end
    if owner=='fight' and c:underTurret(destination) then return false end
    local existing=not resource and self:existing(destination)
    if existing and owner=='fight' and c:underTurret(existing.pos) then return false end
    if existing then
        local ok,event=self.actions:cast(1,existing,owner,{interrupt=true,verifyHover=true,validate=followValidate or validate})
        if ok then self.pending={owner=owner,pos=U.copy(existing.pos),target=existing,state='jumping',event=event,at=c:now(),
            deadline=c:now()+c.config:get('wardJumpTimeout')/1000} end
        return ok
    end
    local slot=self:itemSlot(resource);if not slot then return false end
    local placementRange,nativeRange=self:range(slot),c:spell(slot).range
    local p=exact and {valid=U.dist(myHero.pos,destination)<=placementRange and self.terrain:wall(destination)==false,pos=U.copy(destination)}
        or self.terrain:landing(myHero.pos,destination,placementRange,self.previewState)
    if not p.valid then return false end
    if U.dist(myHero.pos,p.pos)>placementRange then return false end
    local ids={};for _,w in ipairs(self:objects()) do if U.id(w) then ids[U.id(w)]=true end end
    local ok,event=self.actions:cast(slot,p.pos,owner,{interrupt=true,urgent=true,delay=.02,wardItem=true,validate=validate})
    if not ok then return false end
    if owner=='fight' then self.fightRetryAt=c:now()+c.config:get('comboWardRetry')/1000 end
    self.pending={owner=owner,validate=followValidate or validate,pos=U.copy(p.pos),ids=ids,at=c:now(),wardDispatchAt=event.keyAt or (not self.actions.api and event.dispatchAt),
        wardDispatchTick=event.keyTick or event.dispatchTick,state='placing',event=event,
        deadline=c:now()+math.max(c.config:get('wardTimeout')/1000,c.latency*2+.25)+2*c.jitter}
    -- A consumable can disappear immediately after dispatch. Log the captured
    -- pre-cast inventory instead of dereferencing the now-empty slot.
    local before=event.before
    if c.config.capture then c:log('ward_requested',{pos=U.copy(p.pos),origin=U.copy(myHero.pos),distance=U.dist(myHero.pos,p.pos),
        placementRange=placementRange,nativeRange=nativeRange,owner=owner,slot=slot,item=before.item,
        spellAmmo=before.ammo,itemAmmo=before.itemAmmo,stacks=before.stacks,stackCount=before.stackCount}) end
    return true
end
function W:requestPlan(plan,owner)
    self:diagnostics(plan and (plan.reason or plan.kind) or 'No plan')
    if not plan or self.pending then return false end
    if plan.kind=='planning' and plan.job then
        self.pending={state='planning',owner=owner,pos=U.copy(plan.raw),job=plan.job,at=self.ctx:now(),deadline=self.ctx:now()+3}
        self.ctx.input:pauseFarm();self.stopRequested=nil;return true
    end
    if not plan.valid then return false end
    self.stopRequested=nil
    if plan.kind~='approach' then return self:request(plan.pos,owner) end
    if not self.ctx:ready(1) or self.ctx:stage(1)~=1 or not self:slot() or not plan.path or #plan.path==0 then return false end
    local c=self.ctx;local now=c:now()
    self.pending={state='approaching',owner=owner,pos=U.copy(plan.pos),walkTo=U.copy(plan.walkTo or plan.path[#plan.path]),at=now,
        provider=self.terrain.provider,wall=self.terrain.provider and self.terrain.provider.isWall,crossWall=plan.crossWall,
        lastPos=U.copy(myHero.pos),progressAt=now,deadline=now+5+plan.walkDistance/math.max(150,myHero.ms or 350)*2}
    c.input:pauseFarm();if c.config.capture then c:log('ward_approach_started',{distance=plan.walkDistance,nodes=plan.expanded}) end
    return true
end
function W:request(destination,owner)
    if self.pending then return false end
    self:diagnostics('Wardjump released')
    local at=self.ctx:now()
    if self:start(destination,owner,true) then
        self.ctx.metrics.releaseToPlacement=self.ctx:now()-at
        if self.ctx.config.capture then self.ctx:log('ward_release_dispatch',{delay=self.ctx:now()-at}) end;return true
    end
    -- A release during GG's cursor restoration is queued, never silently lost.
    local c=self.ctx
    if c:ready(1) and c:stage(1)==1 and (self.actions:cursorBusy() or self.actions.issuedTick==at) then
        self.pending={state='queued',owner=owner,pos=U.copy(destination),at=at,
            deadline=at+math.max(.25,c.latency+3*c.jitter)}
        return true
    end
    return false
end
function W:earlyW(p)
    local c=self.ctx;local now=c:now()
    if not c.config:get('wardEarlyW') or p.earlyTried or p.state~='placing' or self.actions.api and not p.wardDispatchAt
        or now<(p.wardDispatchAt or p.at)+c.config:get('wardEarlyDelay')/1000 then return end
    if p.owner=='insec' and not c.combat:wardFollowValid(p) then return end
    local function valid()
        if p.validate and not p.validate() then return false end
        if self.pending~=p or p.state~='placing' or p.event.cancelled or c:blocked() or c:dash()
            or c:stage(1)~=1 or not c:ready(1) or U.dist(myHero.pos,p.pos)>c.profile.wRange then return false end
        if p.owner=='fight' and c:underTurret(p.pos) then return false end
        -- Do not knowingly redirect the speculative W to Lee or another ally.
        -- The exact ward identity is checked again when enumeration catches up.
        local hover
        if Game.GetUnderMouseObject then
            local ok,value=pcall(Game.GetUnderMouseObject);if not ok then return false end;hover=value
            if not hover then p.emptyHoverAt=c:now() end
        end
        if U.valid(hover) and hover.team==myHero.team then
            if U.same(hover,myHero) or not U.name(hover.charName):find('ward',1,true)
                or p.ids[U.id(hover)] or U.dist(hover.pos,p.pos)>90 then return false end
            local owner=hover.ownerID or hover.ownerNetworkID
            if owner and owner~=0 and owner~=myHero.networkID and owner~=myHero.handle then return false end
        end
        return true
    end
    local ok,event=self.actions:cast(1,p.pos,p.owner,{interrupt=true,urgent=true,stage=1,
        wardAnticipation=p,validate=valid})
    if ok then
        p.earlyTried=true;p.earlyEvent=event
        if c.config.capture then c:log('ward_early_w_requested',{owner=p.owner,request=event.id,placementRequest=p.event.id,
            configuredMs=c.config:get('wardEarlyDelay'),requestDelayMs=(event.at-(p.wardDispatchAt or p.at))*1000,
            wallDelayMs=(event.keyTick or event.dispatchTick) and p.wardDispatchTick and (event.keyTick or event.dispatchTick)-p.wardDispatchTick,
            pos=U.copy(p.pos),wardObserved=false}) end
    end
end
function W:earlyObserved(p,stage)
    local c=self.ctx;local event=p.earlyEvent
    if not event then return false end
    local used=(stage or c:stage(1))==2 or event.status=='observed' or event.status=='completed'
    if used and not p.earlyObservedAt then
        p.earlyObservedAt=c:now()
        if c.config.capture then c:log('ward_early_w_observed',{owner=p.owner,request=event.id,stage=c:stage(1),dashing=not not c:dash(),
            delayMs=(c:now()-(event.dispatchAt or event.at))*1000,origin=U.copy(myHero.pos),destination=U.copy(p.pos)}) end
    end
    return used
end
function W:confirmedWValid(p)
    local c=self.ctx
    return self.pending==p and not c:blocked() and not c:dash() and c:stage(1)==1 and c:ready(1)
        and (not p.validate or p.validate())
        and self:jumpable(p.target) and (p.owner~='fight' or not c:underTurret(p.target.pos))
        and (p.owner~='insec' or c.combat:wardFollowValid(p))
end
function W:timing(p)
    local e=p.event;if not e then return end
    local r=self.actions:inputAction(e.cursorID)
    local sent=r and r.sentAt and self.ctx:now()-math.max(0,self.actions:inputNow()-r.sentAt)*.001
        or not self.actions.api and (e.keyAt or e.dispatchAt)
    if not sent or p.wSentAt then return end
    p.wSentAt=sent
    local c=self.ctx
    local placement=(p.placementEvent or p.event)
    local ward=placement and self.actions:inputAction(placement.cursorID)
    local placementTick=ward and ward.sentAt
    local function delta(last,first)if last and first and last>=first then return (last-first)*.001 end end
    local placementAt,observedAt,mechanicalAt
    if self.actions.api then
        placementAt=placementTick;observedAt=p.observedTick;mechanicalAt=r and r.mechanical and r.mechanical.at
        c.metrics.wardPlacementToW=delta(r and r.sentAt,placementTick)
        c.metrics.wardObservationToW=delta(r and r.sentAt,p.observedTick)
    else
        placementAt=p.wardDispatchAt;observedAt=p.observed;mechanicalAt=e.observedAt
        c.metrics.wardPlacementToW=p.wardDispatchAt and sent-p.wardDispatchAt
        c.metrics.wardObservationToW=p.observed and sent-p.observed
    end
    if c.config.capture then c:log('ward_timing',{owner=p.owner,request=e.id,cursorID=e.cursorID,
        requestedAt=r and r.requestedAt or e.at,sentAt=r and r.sentAt or sent,
        queue=r and r.sentAt and r.sentAt>=r.requestedAt and (r.sentAt-r.requestedAt)*.001 or not r and sent-e.at or nil,
        timebase=r and 'monotonic milliseconds' or 'Game.Timer seconds',gameTime=c:now(),placementSentAt=placementAt,
        wardObservedAt=observedAt,placementToW=c.metrics.wardPlacementToW,
        observationToW=c.metrics.wardObservationToW,mechanicalAt=mechanicalAt,
        sendCompletedAt=r and r.sendCompletedAt,holdUntil=r and r.holdUntil,releasedAt=r and r.releasedAt}) end
end
function W:tick()
    if self.stopRequested then
        if self.ctx:now()>self.stopRequested or self.actions:move(myHero.pos,'ward') then self.stopRequested=nil end
    end
    local p=self.pending;if not p then return end
    local c=self.ctx;local now=c:now()
    if c:blocked() or now>p.deadline then self:cancel('Ward request expired');return end
    if self.actions.api and p.event and p.event.cursorID then
        local action=self.actions:inputAction(p.event.cursorID)
        if action and action.state=='cancelled_before_send' then
            -- A fresh T may safely interrupt an unissued object-W at the provider.
            -- Re-enter the existing confirmed-target path only for that explicit
            -- continuation, with the same target/deadline and a bounded budget.
            if p.continuationAction==action.id and p.owner=='ward' and p.state=='jumping' and p.placementEvent
                and not action.sentAt and (p.continuations or 0)<2 and self:confirmedWValid(p) then
                p.continuations=(p.continuations or 0)+1;p.continuationAction=nil
                p.event=p.placementEvent;p.state='waiting_w';p.wSentAt=nil
                if c.config.capture then c:log('ward_w_continuation',{request=action.id,
                    target=U.id(p.target),attempt=p.continuations,reason='Repeated T interrupted unissued W'}) end
                action=self.actions:inputAction(p.event.cursorID)
            else self:cancel('Ward input cancelled');return end
        end
        if action and not action.sentAt then return end
        if action and action.sentAt and not p.event.sendObservedByWard then
            p.event.sendObservedByWard=true
            local sent=now-math.max(0,self.actions.api:Now()-action.sentAt)*.001
            if p.state=='placing' then p.wardDispatchAt=sent;p.deadline=sent+c.config:get('wardTimeout')/1000+2*c.jitter end
        end
    end
    if p.owner=='fight' and p.state~='jumping' and c:underTurret(p.target and p.target.pos or p.pos) then
        self:cancel('Combo ward landing entered turret range');return
    end
    if p.state=='planning' then
        if not c:ready(1) or c:stage(1)~=1 or not self:slot() or c:recalling() then self:cancel('Approach resources changed');return end
        local result=self:advance(p.job)
        if p.job.done then
            if U.dist(p.job.origin,myHero.pos)>=20 then
                result=self:preview(p.pos,true)
                if result.kind=='planning' then p.job=result.job;return end
            end
            self.pending=nil
            if not self:requestPlan(result,p.owner) then c.status=result.reason or 'No wardjump approach available' end
        end
        return
    elseif p.state=='approaching' then
        if not c.config:get('wardApproach') or not c:ready(1) or c:stage(1)~=1 or not self:slot()
            or self.terrain:wall(p.pos)~=false or c:recalling() then self:cancel('Approach resources / context changed');return end
        if U.dist(myHero.pos,p.lastPos)>25 then p.lastPos=U.copy(myHero.pos);p.progressAt=now;p.moveObserved=true end
        if self:canStart(p.pos) then
            if p.crossWall then
                local hit,out=self.terrain:crossing(myHero.pos,p.pos)
                if not hit or not out then self:cancel('Crossing no longer lies between Lee and landing');return end
            end
            self.pending=nil
            if self:request(p.pos,p.owner) then if c.config.capture then c:log('ward_approach_arrived',{delay=now-p.at}) end else self.pending=p end
            return
        end
        if p.provider~=self.terrain.provider or p.wall~=(self.terrain.provider and self.terrain.provider.isWall)
            or not self.terrain:clearance(p.walkTo,math.min(45,myHero.boundingRadius or 35)) then
            self:cancel('Approach destination changed');return
        end
        if p.moveID then
            local move=self.actions:inputAction(p.moveID)
            if not move or move.state=='cancelled_before_send' then self:cancel('Approach input cancelled');return end
            p.moveSentAt=move.sentAt and now-math.max(0,self.actions:inputNow()-move.sentAt)*.001
            if move.state=='send_uncertain' then self:waitReason(p,'Approach input uncertain');return end
            if not p.moveSentAt then return end
        end
        local path=myHero.pathing
        if p.moveSentAt and path and path.hasMovePath then p.moveObserved=true end
        if p.moveObserved and p.moveIssued and p.moveSentAt and now-p.moveSentAt>.25 and path and not path.hasMovePath then
            -- Native path ended short: stay across the selected local wall.
            local hit,out=self.terrain:crossing(myHero.pos,p.pos)
            local alternate=out and U.toward(myHero.pos,p.pos,U.dist(myHero.pos,out)+16)
            if hit and alternate and self:canStart(alternate) then p.pos=alternate;return self:tick() end
            if not p.corrected then
                p.corrected=true
                local nextPoint=self.terrain:nearBoundary(p.walkTo,p.pos)
                if U.dist(myHero.pos,nextPoint)>25 then
                    p.walkTo=nextPoint;p.moveIssued=nil;p.moveID=nil;p.moveSentAt=nil;p.moveObserved=nil;p.progressAt=now
                else self:cancel('Native approach ended before reachable landing');return end
            else self:cancel('Correction ended before reachable landing');return end
        end
        if now-p.progressAt>1.5 and (not p.moveID or p.moveSentAt) then self:cancel('Approach stalled');return end
        if not p.moveIssued then
            p.moveIssued=self.actions:move(p.walkTo,p.owner)
            if p.moveIssued then
                p.moveID=self.actions.lastCursorAction;p.moveRequestedAt=now
                if not self.actions.api then p.moveSentAt=now end
                if c.config.capture then c:log('ward_approach_move',{destination=p.walkTo,landing=p.pos,cursorID=p.moveID,correction=p.corrected==true}) end
            end
        end
        return
    elseif p.state=='queued' then
        if c:stage(1)~=1 or not c:ready(1) then self:cancel('Safeguard unavailable');return end
        self.pending=nil
        if self:start(p.pos,p.owner,true) then c.metrics.releaseToPlacement=now-p.at;if c.config.capture then c:log('ward_release_dispatch',{delay=now-p.at}) end
        else self.pending=p end
        return
    elseif p.state=='placing' then
        if c:stage(1)==2 and not p.earlyEvent then self:cancel('Safeguard used elsewhere');return end
        self:earlyObserved(p)
        local function accept(w,source)
            if not w then return false end
            local owner=w.ownerID or w.ownerNetworkID
            if U.id(w) and not p.ids[U.id(w)] and w.valid~=false and w.team==myHero.team and w.pos and not w.dead and U.dist(p.pos,w.pos)<=90
                and (not owner or owner==0 or owner==myHero.networkID or owner==myHero.handle) then
                p.observed=now;p.observedTick=self.actions.api and self.actions:inputNow();p.target=w;p.state='waiting_w';p.placementEvent=p.event
                p.deadline=now+c.config:get('wardJumpTimeout')/1000+2*c.jitter
                if c.config.capture then c:log('ward_first_observation',{source=source,target=U.id(w),delay=now-(p.wardDispatchAt or p.at),owner=p.owner,
                    earlyRequest=p.earlyEvent and p.earlyEvent.id,earlyWObserved=p.earlyObservedAt~=nil}) end
                return true
            end
        end
        -- Native hover can expose the new ward before WardCount/Ward does.
        -- Use that earliest object signal, retaining the same GG-owned handoff.
        if c.config:get('wardFastCursor') and Game.GetUnderMouseObject then
            local ok,hovered=pcall(Game.GetUnderMouseObject)
            if ok and hovered and U.name(hovered.charName):find('ward',1,true) and self:jumpable(hovered) then
                accept(hovered,'native hover')
            end
        end
        if p.state=='placing' then
            for _,w in ipairs(self:objects(true)) do if accept(w,'ward enumeration') then break end end
        end
        if p.state=='placing' then self:earlyW(p) end
    end
    -- Discovering the ward and dispatching W happen in the same callback.
    if p.state=='waiting_w' then
        -- Read the stage once for this transition. Host metadata can advance
        -- between reads, before Actions publishes the matching observation.
        -- A sent early W is historical input, not an unspent W prerequisite.
        p.followStage=c:stage(1)
        if self:earlyObserved(p,p.followStage) then
            p.state='jumping';p.event=p.earlyEvent;p.pos=U.copy(p.target.pos)
            self:timing(p)
        end
    end
    if p.state=='waiting_w' then
        if p.validate then
            local valid,reason=p.validate()
            if not valid then self:cancel(reason or 'Ward follow-up no longer useful');return end
        end
        if p.owner=='insec' and not c.combat:wardFollowValid(p) then
            self:cancel('Target moved beyond remaining insec resources');return
        end
        if p.followStage==2 then self:cancel('Safeguard used elsewhere');return end
        if p.followStage~=1 then self:waitReason(p,'W stage metadata');return end
        if p.target.dead or p.target.valid==false then self:cancel('Jump ward destroyed');return end
        if self:jumpable(p.target) and not c:dash() then
            -- A rejected early ground cast must not occupy the normal W slot
            -- until the generic acknowledgement timeout. Only replace our own
            -- speculative request, and only with W1 still ready at observation.
            if self.actions.api and p.earlyEvent and p.earlyEvent.cursorID then
                local early=self.actions:inputAction(p.earlyEvent.cursorID)
                if early and not early.sentAt and early.state~='cancelled_before_send' then
                    self.actions.scope:Cancel(early.id,'Confirmed object replaces unsent speculative cast')
                    p.earlyEvent.status='cancelled'
                elseif early and early.state=='send_uncertain' then
                    self:waitReason(p,'Early W send uncertain');return
                elseif early and early.sentAt then
                    -- Empty hover can establish an early no-target trial. If
                    -- hover was nonempty, wait for the action acknowledgement
                    -- window instead, then reconcile against current ready W1
                    -- and the confirmed ward. This is one new object-targeted
                    -- attempt, not a replay or proof the first input never ran.
                    local sent=now-math.max(0,self.actions.api:Now()-early.sentAt)*.001
                    local empty=p.emptyHoverAt and math.abs(p.emptyHoverAt-sent)<.03
                    local expired=p.earlyEvent.status=='unconfirmed' and now>p.earlyEvent.deadline
                    local ready=(empty or expired)
                        and now-sent>=math.max(.12,c.latency*2+3*c.jitter)
                        and early.releasedAt and c:ready(1) and c:stage(1)==1
                        and not c:dash() and p.earlyEvent.status~='observed'
                    if not ready then self:waitReason(p,'Early W awaiting mechanical evidence');return end
                    p.earlyEvent.status=empty and 'no_target' or 'unconfirmed';p.earlyNoEffectAt=now
                    p.earlyReconciliation=empty and 'empty_hover' or 'acknowledgement_expired_W1_ready'
                end
            end
            if p.earlyEvent and self.actions.pending[1]==p.earlyEvent and c:ready(1) then
                self.actions.pending[1]=nil;p.earlyEvent.status='unconfirmed';p.earlyEvent.intentStatus='superseded'
            end
            if p.earlyEvent and not p.fallbackReported then
                p.fallbackReported=true;p.earlyEvent.intentStatus='superseded'
                if c.config.capture then c:log('ward_early_w_fallback',{owner=p.owner,request=p.earlyEvent.id,target=U.id(p.target),
                    reason=p.earlyReconciliation or 'unsent_replacement',
                    delayMs=(now-(p.earlyEvent.dispatchAt or p.earlyEvent.at))*1000}) end
            end
            -- W is object-targeted: a settled screen coordinate alone does not
            -- establish that a newly spawned ward is actually under the cursor.
            -- Use the shared bounded identity/candidate path, with no projection
            -- fallback and no replay of an already issued W.
            local ok,event=self.actions:cast(1,p.target,p.owner,{interrupt=true,urgent=true,wardFollowup=true,verifyHover=true,
                validate=function()return self:confirmedWValid(p)end})
            if ok then
                p.state='jumping';p.event=event;p.pos=U.copy(p.target.pos)
                self:timing(p)
            else self:waitReason(p,not c:ready(1) and 'W not ready' or self.actions:cursorBusy() and 'GG cursor unavailable' or 'Cast dispatcher declined') end
        else self:waitReason(p,c:dash() and 'Lee is dashing' or 'Ward targetability / visibility / range') end
    end
    if p.state=='jumping' then
        self:timing(p)
        if c:dash() and not p.dashStartedAt then p.dashStartedAt=now end
        if p.owner=='ward' and not p.followIssued and c.config:get('wardFollowCursor') and (c:dash() or c:stage(1)==2) then
            if not self.actions:cursorBusy() then c.aim=c:playerPosition() end
            p.followIssued=self.actions:move(c.aim,'ward')
            if p.followIssued then if c.config.capture then c:log('ward_follow_move',{destination=U.copy(c.aim),duringDash=not not c:dash()}) end end
        end
        if not c:dash() and U.dist(myHero.pos,p.pos)<140 and (c:stage(1)==2 or p.event.status=='observed') then
            local duration=p.dashStartedAt and now-p.dashStartedAt or nil
            if duration and duration>=.02 and duration<=.8 then
                c.metrics.wardDashDuration=c.metrics.wardDashDuration and c.metrics.wardDashDuration*.75+duration*.25 or duration
            end
            p.event.status='completed';self.lastCompleted=now;self.pending=nil;if c.config.capture then c:log('wardjump_completed',{owner=p.owner,target=U.id(p.target),request=p.event.id,duration=now-p.at,dashEndAt=now,dashStartAt=p.dashStartedAt,wSentAt=p.wSentAt,wObservedAt=p.event.observedAt,landing=U.copy(myHero.pos),destination=U.copy(p.pos)}) end
        elseif not self.actions.api and p.event.status=='unconfirmed' and self:available() and self:jumpable(p.target) and not c:dash() then
            local ok,event=self.actions:cast(1,p.target,p.owner,{interrupt=true,urgent=true,verifyHover=true,
                validate=function()return self:confirmedWValid(p)end})
            if ok then p.event=event;if c.config.capture then c:log('ward_w_retry',{target=U.id(p.target)}) end end
        end
    end
end
function W:waitReason(p,reason)
    if p.waitReason==reason then return end
    p.waitReason=reason
    if self.ctx.config.capture then self.ctx:log('ward_handoff_wait',{reason=reason,delay=self.ctx:now()-p.at}) end
end
-- Repeated standalone T is continuation after resource commitment. Before
-- commitment it remains a new preview/re-aim; right-click still explicitly cancels.
function W:retainCommitted()
    local p=self.pending;local c=self.ctx
    if not p or p.owner~='ward' or c:blocked() or c:now()>p.deadline
        or (p.state~='placing' and p.state~='waiting_w' and p.state~='jumping') then return false end
    local event=p.placementEvent or p.event
    local action=event and self.actions:inputAction(event.cursorID)
    local issued=self.actions.api and action and (action.sentAt or action.state=='send_uncertain')
        or not self.actions.api and event and event.keyAt
    if not issued then return false end
    local current=p.event and self.actions:inputAction(p.event.cursorID)
    p.continuationAction=p.state=='jumping' and current and not current.sentAt
        and current.state~='send_uncertain' and current.id or nil
    if c.config.capture then c:log('wardjump_continued',{owner=p.owner,state=p.state,
        placementRequest=event.id,target=U.id(p.target),destination=U.copy(p.pos),
        reason='Repeated T retains committed jump',deadline=p.deadline}) end
    return true
end
function W:cancel(reason,stop)
    self.stopRequested=stop and self.pending and self.pending.state=='approaching' and self.ctx:now()+.4 or nil
    if self.pending then
        self.pending.cancelled=true;self.pending.cancelReason=reason
        self.actions:cancel(self.pending.owner)
        if self.ctx.config.capture then self.ctx:log('wardjump_cancelled',{reason=reason,owner=self.pending.owner,state=self.pending.state,
            earlyRequest=self.pending.earlyEvent and self.pending.earlyEvent.id,earlyWObserved=self.pending.earlyObservedAt~=nil,
            destination=U.copy(self.pending.pos),target=U.id(self.pending.target)}) end
        self.pending=nil
    end
end
return W
