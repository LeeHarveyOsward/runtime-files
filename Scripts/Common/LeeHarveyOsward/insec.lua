-- Bounded, resource-aware search. Only the next hop is issued; every later hop
-- is provisional and is rebuilt from observed positions before dispatch.
local U=require('lho.util')
local WardNames=require('lho.wardnames')
local I={};I.__index=I
local function cheaper(a,b) return a.cost==b.cost and a.time<b.time or a.cost<b.cost end
local function enqueue(heap,node)
    local n=#heap+1;heap[n]=node
    while n>1 do
        local parent=math.floor(n/2);if not cheaper(node,heap[parent]) then break end
        heap[n]=heap[parent];n=parent;heap[n]=node
    end
end
local function dequeue(heap)
    local top=heap[1];local last=table.remove(heap)
    if #heap>0 then
        local n=1;heap[1]=last
        while n*2<=#heap do
            local child=n*2
            if child+1<=#heap and cheaper(heap[child+1],heap[child]) then child=child+1 end
            if not cheaper(heap[child],last) then break end
            heap[n]=heap[child];n=child;heap[n]=last
        end
    end
    return top
end
function I.new(combat) return setmetatable({b=combat,ctx=combat.ctx},I) end
-- A close landing is an explicit fallback policy, not a global relaxation of
-- the configured ordinary landing margin. The kick angle/range still applies.
function I:landingMargin(step)
    if step and step.closeLanding and self.ctx.config:get('insecCloseWard') then return 80 end
    return self.ctx.config:get('insecLandingMargin')
end
function I:q2Continuation(i,unit,previous)
    local c=self.ctx
    if self.b.insec~=i or not c:enemyValid(i.target) or self.b:kickProtected(i.target)
        or not self:spellReady(3,true) or not U.valid(unit) then return nil end
    local future={};for k,v in pairs(i) do future[k]=v end
    future.used={};for k,v in pairs(i.used or {}) do future.used[k]=v end;future.used.q=true
    local dash=c.config:get('insecDashEstimate')/1000
    local horizon=dash+self.b.tactics:wardArrival()+c.latency+.25
    local function predict(u,lead)
        if not (u.pathing and u.pathing.hasMovePath) then return U.copy(u.pos) end
        if not u.GetPrediction then return nil end
        local ok,p=pcall(u.GetPrediction,u,math.huge,lead)
        if ok and U.position(p) then return U.copy(p) end
    end
    local center=predict(i.target,horizon);local landing=predict(unit,dash)
    if not center or not landing then return nil end
    local aim=i.destination or c.aim
    if i.locked and i.direction then aim={x=center.x+i.direction.x*1200,y=center.y,z=center.z+i.direction.z*1200} end
    if not aim or U.dist(center,aim)<10 then return nil end
    future.plannedTarget=center;future.plannedEndpoint=U.toward(center,aim,c.profile.kickDistance)
    future.stand=U.toward(center,aim,-math.min(c.config:get('insecStandDistance'),c.profile.rRange-45))
    local reserved=c:spell(0).mana or 0
    -- Fresh dispatch validation adapts the already selected continuation; it
    -- never repeats the full search or sends an input from the callback.
    local plan=previous and self:adapt(future,previous) or self:plan(future,landing,future.used,reserved)
    if plan and self:validate(future,plan,landing,reserved) then return plan end
end
function I:resourceOrderValid(i,steps)
    for n,step in ipairs(steps) do
        if step.kind=='ward' and n<#steps then
            -- A held insec never spends its ward merely to get Q in range.
            -- Preserve W for the kick-side reposition. Extra repositioning
            -- after the ward requires a shown/confirmed Flash continuation.
            if not (i.preview or i.flashConsent and i.contract) then return false end
            local flash=false
            for j=n+1,#steps do if steps[j].kind=='flash' then flash=true end end
            if not flash then return false end
        end
    end
    return true
end
function I:finishSideValid(i,step,from)
    if not step then return true end
    if step.kind=='q' and U.same(step.unit,i.target) then
        -- Q2 approaches the marked champion from the launch side. Comparing
        -- its current center with a forecast target center can falsely invent
        -- a landing behind them (Ward -> Q -> R). Require the actual approach
        -- side to agree too; a later ward/Flash or a different Q bridge remains valid.
        local near=U.toward(i.target.pos,from,100)
        return self.b:aligned(i.target,i.endpoint,near)
    end
    if step.kind=='ward' then
        return U.dist(step.pos,i.plannedTarget or i.target.pos)+1e-6>=self:landingMargin(step)
    end
    return true
end
function I:flashAllowed(i)
    if not self.ctx.config:get('insecFlash') then return false,'Flash proposals disabled' end
    if i and i.preview then return true,'Preview only: Flash may be proposed' end
    if i and i.flashConsent and i.contract then return true,'Flash explicitly approved with Alt release' end
    if self.ctx.config:get('insecFlashFallback') and i and not i.contract and not i.wardCommitted
        and not (i.used and i.used.w) and not self.ctx.wards:slot() then
        return true,'Flash fallback: no ready ward; no W already committed'
    end
    return false,'Ready ward / W committed / Flash needs Alt confirmation'
end
function I:spellReady(slot,forecast)
    local c=self.ctx
    if c:ready(slot) then return true end
    local spell=c:spell(slot)
    -- A current cast lock is not a future cooldown. Forecasts may retain the
    -- resource, but every actual dispatch still uses native readiness.
    return forecast and (slot>3 or (spell.level or 0)>0) and (spell.currentCd or 0)<=0
        and (spell.mana or 0)<=(myHero.mana or 0) or false
end
function I:flashSlot(forecast)
    local c=self.ctx
    for slot=4,5 do
        if U.name(c:spell(slot).name)=='summonerflash' and self:spellReady(slot,forecast) and not c.actions.pending[slot] then return slot end
    end
end
function I:units(target)
    local c=self.ctx;local q={target};local w={};local seen={[U.id(target) or target]=true};local wSeen={}
    if c.config:get('insecBridges') then
        for _,list in ipairs({c.enemies or {},c.minions or {}}) do for _,u in ipairs(list) do
            if U.valid(u) and u.team~=myHero.team and not seen[U.id(u) or u]
                and U.dist(myHero.pos,u.pos)<2200 then q[#q+1]=u;seen[U.id(u) or u]=true end
        end end
    end
    -- Bound expensive collision checks without changing the selected champion.
    table.sort(q,function(a,b)
        if U.same(a,b) then return false end
        if U.same(a,target) then return true elseif U.same(b,target) then return false end
        return U.dist(a.pos,target.pos)<U.dist(b.pos,target.pos)
    end)
    while #q>12 do table.remove(q) end
    for _,list in ipairs({c.wards:objects(),c.allies or {},c.minions or {}}) do for _,u in ipairs(list) do
        local name=U.name(u.charName)
        if U.valid(u) and not wSeen[U.id(u) or u] and u.team==myHero.team and not U.same(u,myHero) and name~='bluetrinket'
            and name~='farsightward' and name~='zombieward' and U.dist(myHero.pos,u.pos)<1800 then
            w[#w+1]=u;wSeen[U.id(u) or u]=true
        end
    end end
    table.sort(w,function(a,b)return U.dist(a.pos,target.pos)<U.dist(b.pos,target.pos) end)
    while #w>12 do table.remove(w) end
    return q,w
end
function I:plan(i,origin,used,reservedEnergy,checkpoint)
    local c=self.ctx;local forecast=origin~=nil;origin=origin or myHero.pos;used=used or i.used or {}
    local energyBudget=math.max(0,(myHero.mana or 0)-(reservedEnergy or 0)-(c:spell(3).mana or 0))
    local qUnits,wUnits=self:units(i.target)
    local stage=c:stage(0);local qReady=c.config:get('insecQ') and self:spellReady(0,forecast) and not used.q and not c.actions.pending[0]
    local qMana=c:spell(0).mana or 0;local wMana=c:spell(1).mana or 0
    local rank=math.max(1,c:spell(0).level or 1)
    local qDamage=(c.profile.qBase[rank] or 180)+c.profile.qRatio*(myHero.bonusDamage or 0)
    i.qOptions={ready=qReady,stage=stage,used=not not used.q,candidates={}}
    local marks={}
    if stage==2 then for _,u in ipairs(qUnits) do marks[u]=c:mark(u)~=nil end end
    local wReady=c.config:get('insecW') and self:spellReady(1,forecast) and c:stage(1)==1 and not c.actions.pending[1] and not used.w
    local flashAllowed,flashReason=self:flashAllowed(i)
    i.flashReason=flashReason
    local flash=flashAllowed and not used.f and self:flashSlot(forecast)
    local wardSlot=wReady and c.wards:slot()
    if i.contract then
        wardSlot=nil
        for n=i.contractIndex or 1,#i.contract do
            if i.contract[n].kind=='ward' then wardSlot=wReady and c.wards:itemSlot(i.contract[n].itemID);break end
        end
    end
    local wardRange=c.wards:range(wardSlot)
    i.resources={qReady=not not qReady,wReady=not not wReady,wardReady=wardSlot~=nil,
        wardSlot=wardSlot,flashReady=flash~=nil and flash~=false,flashReason=flashReason}
    local maxDepth=c.config:get('insecChains') and 3 or 1
    local best,expanded=nil,0;local collisionCache={};local visited={};local goals={i.stand}
    local wardArrival=self.b.tactics:wardArrival()
    -- Alternative distances on the same kick ray let tight wall boundaries
    -- work without changing the requested direction. No landing inside walls.
    for _,d in ipairs({180,300}) do
        local center=i.plannedTarget or i.target.pos
        local dx,dz=i.stand.x-center.x,i.stand.z-center.z
        goals[#goals+1]=U.toward(center,{x=center.x+dx,z=center.z+dz},d)
    end
    if c.config:get('insecCloseWard') then
        for _,d in ipairs({140,100,80}) do
            if d<c.config:get('insecLandingMargin') then
                goals[#goals+1]=U.toward(i.plannedTarget or i.target.pos,i.plannedEndpoint or i.endpoint,-d)
            end
        end
    end
    local function ground(p) return c.terrain:wall(p)==false end
    local function expected(node) return i.contract and i.contract[(i.contractIndex or 1)+#node.steps] end
    local function permits(node,kind,unit)
        if not i.contract then return true end
        local e=expected(node)
        return e and e.kind==kind and (not e.unitID or e.unitID==U.id(unit))
    end
    local function qClear(u,from)
        local key=tostring(U.id(u))..':'..math.floor(from.x)..':'..math.floor(from.z)
        if collisionCache[key]==nil then
            if checkpoint then checkpoint() end
            local p=u.pos
            if U.dist(from,myHero.pos)<1 then p=c.spells:predict(u) end
            collisionCache[key]=p~=nil and #c.spells:blockers(u,p,from)==0 and not c.spells:projectileWall(p,from,U.id(u))
        end
        return collisionCache[key]
    end
    local function terminal(node)
        if not self:resourceOrderValid(i,node.steps) then return false end
        local last=node.steps[#node.steps]
        local before=#node.steps>1 and node.steps[#node.steps-1].pos or origin
        if not self:finishSideValid(i,last,before) then return false end
        if self.b:planAligned(i,node.pos) then return true end
        for _,goal in ipairs(goals) do
            local d=U.dist(node.pos,goal)
            local walkTime=d/math.max(1,myHero.ms or 350)
            local viable=true
            if d<=c.config:get('insecWalk') and i.target.GetPrediction and i.target.pathing and i.target.pathing.hasMovePath then
                local ok,future=pcall(i.target.GetPrediction,i.target,math.huge,node.time+walkTime+c.latency+.25)
                local center=i.plannedTarget or i.target.pos;local endpoint=i.plannedEndpoint or i.endpoint
                local aim=ok and U.position(future) and {x=future.x+endpoint.x-center.x,y=future.y,z=future.z+endpoint.z-center.z}
                viable=aim and self.b:aligned({pos=future},aim,goal)
            end
            if d<=c.config:get('insecWalk') and viable and ground(goal) and c.terrain:walkLine(node.pos,goal,35) then
                node.walk=goal;node.walkDistance=U.dist(goal,i.plannedTarget or i.target.pos)
                node.walkTime=walkTime;return true
            end
        end
    end
    local queue={{pos=origin,used={q=used.q,w=used.w,f=used.f},steps={},cost=0,time=0,energy=0}}
    local function push(node,kind,p,unit,cost,energy,dt)
        if not permits(node,kind,unit) or not ground(p) or node.energy+energy>energyBudget then return end
        local steps={};for n,s in ipairs(node.steps) do steps[n]=s end
        local step={kind=kind,pos=U.copy(p),unit=unit}
        if kind=='ward' then step.itemID=myHero:GetItemData(wardSlot).itemID end
        for _,goal in ipairs(goals) do
            if (kind=='ward' or kind=='flash') and U.dist(p,goal)<1 then step.goalDistance=U.dist(goal,i.plannedTarget or i.target.pos);break end
        end
        if kind=='ward' and step.goalDistance and step.goalDistance<c.config:get('insecLandingMargin') then
            step.closeLanding=c.config:get('insecCloseWard') and true or nil
        end
        steps[#steps+1]=step
        local mask={q=node.used.q,w=node.used.w,f=node.used.f}
        mask[kind=='q' and 'q' or kind=='flash' and 'f' or 'w']=true
        -- An optimistic remaining-distance bound discards bridge detours that
        -- cannot reach even R range with every remaining resource. This does
        -- not replace terrain/collision or exact kick-alignment validation.
        local reach=c.profile.rRange+c.config:get('insecWalk')
        if qReady and not mask.q then reach=reach+math.max(c.profile.qRange,c.profile.q2Range) end
        if wReady and not mask.w then reach=reach+c.profile.wRange end
        if flash and not mask.f then reach=reach+400 end
        if U.dist(p,i.target.pos)>reach then return end
        local key=(mask.q and 'q' or '')..(mask.w and 'w' or '')..(mask.f and 'f' or '')
            ..':'..math.floor(p.x/5)..':'..math.floor(p.z/5)
        local total=node.cost+cost;local time=node.time+dt;local prior=visited[key]
        if prior and (prior.cost<total or prior.cost==total and prior.time<=time) then return end
        visited[key]={cost=total,time=time}
        if #queue>=512 or best and total>best.cost then return end
        enqueue(queue,{pos=p,steps=steps,used=mask,cost=total,time=time,energy=node.energy+energy})
    end
    while #queue>0 and expanded<96 do
        local node=dequeue(queue);expanded=expanded+1
        if checkpoint then checkpoint() end
        if best and node.cost>best.cost then break end
        if terminal(node) then
            node.time=node.time+(node.walkTime or 0)
            if not best or node.cost<best.cost or node.cost==best.cost and node.time<best.time then best=node end
        elseif #node.steps<maxDepth then
            if wReady and not node.used.w then
                for _,u in ipairs(wUnits) do if permits(node,'w',u) and U.dist(node.pos,u.pos)<=c.profile.wRange then
                    push(node,'w',u.pos,u,1,wMana,.2)
                end end
                if wardSlot and permits(node,'ward') then
                    local destinations={};for _,goal in ipairs(goals) do
                        destinations[#destinations+1]=U.dist(node.pos,goal)<=wardRange and goal or U.toward(node.pos,goal,wardRange-15)
                    end
                    for _,u in ipairs(qUnits) do
                        -- Enables W -> Q -> Flash as well as Q -> W -> Flash.
                        if U.dist(node.pos,u.pos)>c.profile.qRange then destinations[#destinations+1]=U.toward(node.pos,u.pos,wardRange-15) end
                    end
                    for _,p in ipairs(destinations) do push(node,'ward',p,nil,3,wMana,wardArrival) end
                end
            end
            if qReady and not node.used.q then
                for _,u in ipairs(qUnits) do
                    local d=U.dist(node.pos,u.pos);local marked=marks[u]
                    local viable=permits(node,'q',u) and (marked and d<=c.profile.q2Range or stage==1 and d<=c.profile.qRange and qClear(u,node.pos))
                    if #node.steps==0 then
                        i.qOptions.candidates[#i.qOptions.candidates+1]={id=U.id(u),name=u.charName,pos=U.copy(u.pos),
                            hp=u.health,distance=d,marked=not not marked,
                            reason=not permits(node,'q',u) and 'Confirmed resources exclude this bridge'
                                or d>(marked and c.profile.q2Range or c.profile.qRange) and 'Out of Q range'
                                or not viable and 'Prediction / collision / Q stage'
                                or not marked and u.health<=qDamage+20 and 'Q1 may kill bridge'
                                or d<=100 and 'No useful Q displacement' or 'Entry candidate; continuation still required'}
                    end
                    -- A bridge killed by Q1 cannot carry Q2. Unknown monster
                    -- coefficients get a conservative raw upper estimate here.
                    if viable and (marked or u.health>qDamage+20) and d>100 then
                        local energy=marked and qMana or qMana+50
                        push(node,'q',u.pos,u,2,energy,marked and .2 or .25+d/c.profile.qSpeed+.2)
                    end
                end
            end
            if flash and not node.used.f and permits(node,'flash') then
                local destinations={};for _,goal in ipairs(goals) do
                    destinations[#destinations+1]=U.dist(node.pos,goal)<=400 and goal or U.toward(node.pos,goal,390)
                end
                for _,u in ipairs(qUnits) do if U.dist(node.pos,u.pos)>c.profile.qRange then
                    destinations[#destinations+1]=U.toward(node.pos,u.pos,390)
                end end
                for _,p in ipairs(destinations) do push(node,'flash',p,nil,20,0,.08) end
            end
        end
    end
    if best then
        local labels={};for _,s in ipairs(best.steps) do
            local label=s.kind=='ward' and 'Ward / W' or s.kind=='flash' and 'Flash' or s.kind=='w' and 'Existing W'
                or ((stage==2 and 'Q2' or 'Q1 > Q2')..' ['..(s.unit.charName or 'bridge')..']')
            if s.kind=='ward' then label=label..' ['..(WardNames[s.itemID] or 'item '..tostring(s.itemID))..']' end
            labels[#labels+1]=label
        end
        if best.walk then labels[#labels+1]='Walk correction' end
        labels[#labels+1]='R';best.label=table.concat(labels,' > ')
    end
    i.searchNodes=expanded;return best
end
-- Search can yield between bounded graph/collision operations. Drawing never
-- invokes this search. A confirmed resource contract greatly narrows the graph.
function I:search(i,origin,reserved)
    if i.contract then return self:plan(i,origin,nil,reserved) end
    local now=self.ctx:now();local j=i.search
    local context=origin and 'forecast' or 'current'
    if not j or j.context~=context or j.reserved~=(reserved or 0) or j.target~=U.id(i.target)
        or j.done and now-j.at>=.06 or not j.done and now-j.at>.75 then
        local snapshot={};for k,v in pairs(i) do snapshot[k]=v end
        snapshot.stand=U.copy(i.stand);snapshot.endpoint=U.copy(i.endpoint)
        snapshot.used={};for k,v in pairs(i.used or {}) do snapshot.used[k]=v end
        j={at=now,origin=U.copy(origin or myHero.pos),context=context,reserved=reserved or 0,
            target=U.id(i.target),snapshot=snapshot,operations=0}
        j.work=coroutine.create(function()return self:plan(snapshot,j.origin,nil,reserved,function()coroutine.yield()end)end)
        i.search=j
    end
    if not j.done and j.stepAt~=now then
        j.stepAt=now
        local started=GetTickCount and GetTickCount()
        for n=1,24 do
            j.operations=j.operations+1
            local ok,result=coroutine.resume(j.work)
            if not ok then j.done=true;j.result=nil;if self.ctx.config.capture then self.ctx:trace('insec_search_error',{reason=tostring(result)},'search',1) end;break end
            if coroutine.status(j.work)=='dead' then j.done=true;j.result=result;break end
            -- Bound work between native calls. One native prediction call can
            -- still overrun; Lua cannot interrupt that call safely.
            if n>=2 and started and GetTickCount()-started>=2 then break end
        end
        if j.done then
            i.searchNodes=j.snapshot.searchNodes or 0
            if self.ctx.config.capture then self.ctx:trace('insec_search_timing',{elapsed=now-j.at,nodes=i.searchNodes,operations=j.operations,found=j.result~=nil},'search',1) end
            i.qOptions=j.snapshot.qOptions
            i.resources=j.snapshot.resources;i.flashReason=j.snapshot.flashReason
            if self.ctx.config.capture then self.ctx:trace('insec_q_options',{target=U.id(i.target),options=i.qOptions,found=j.result~=nil},'options',.5) end
        end
    end
    if j.done then return j.result end
    return i.plan
end
function I:blockedReason(i)
    if i.contract then return 'Confirmed plan blocked; hold Alt to revise' end
    local r=i.resources
    if r and not r.qReady then return 'Waiting for Q readiness / a complete kick route' end
    if r and not r.wardReady and not r.flashReady then
        return 'No ready ward or authorized Flash; no Q-only kick route'
    end
    if r and not r.wReady and not r.flashReady then return 'W unavailable; no Q-only kick route' end
    return 'No complete kick route: checking range, collision and landing'
end
function I:adapt(i,plan)
    if not plan then return end
    local out={steps={},label=plan.label,cost=plan.cost,time=plan.time,walkDistance=plan.walkDistance}
    if plan.walk then out.walk=plan.walkDistance and U.toward(i.plannedTarget or i.target.pos,i.plannedEndpoint or i.endpoint,-plan.walkDistance) or U.copy(plan.walk) end
    for _,s in ipairs(plan.steps) do
        local p=s.unit and s.unit.pos or s.pos
        if s.goalDistance then p=U.toward(i.plannedTarget or i.target.pos,i.plannedEndpoint or i.endpoint,-s.goalDistance) end
        out.steps[#out.steps+1]={kind=s.kind,pos=U.copy(p),unit=s.unit,itemID=s.itemID,goalDistance=s.goalDistance,closeLanding=s.closeLanding}
    end
    return out
end
function I:validate(i,plan,origin,reserved)
    if not plan or not self:resourceOrderValid(i,plan.steps) then return false end
    local c=self.ctx;local from=origin or myHero.pos;local energy=(myHero.mana or 0)-(reserved or 0)-(c:spell(3).mana or 0)
    for n,step in ipairs(plan.steps) do
        if n==#plan.steps and not self:finishSideValid(i,step,from) then return false end
        if i.contract then
            local expected=i.contract[(i.contractIndex or 1)+n-1]
            if not expected or expected.kind~=step.kind or expected.unitID and expected.unitID~=U.id(step.unit)
                or expected.itemID and expected.itemID~=step.itemID then return false end
        end
        if not step.pos or c.terrain:wall(step.pos)~=false then return false end
        local d=U.dist(from,step.pos)
        if step.kind=='q' then
            if not U.valid(step.unit) or not self:spellReady(0,origin~=nil) then return false end
            local marked=c:mark(step.unit) and c:stage(0)==2
            if marked then if d>c.profile.q2Range then return false end
            elseif step.unit.health<=((c.profile.qBase[c:spell(0).level or 1] or 0)+c.profile.qRatio*(myHero.bonusDamage or 0))+20
                or c:stage(0)~=1 or d>c.profile.qRange or #c.spells:blockers(step.unit,step.pos,from)>0
                or c.spells:projectileWall(step.pos,from,U.id(step.unit)) then return false end
            energy=energy-(c:spell(0).mana or 0)-(marked and 0 or 50)
        elseif step.kind=='w' or step.kind=='ward' then
            local wardSlot=step.kind=='ward' and c.wards:itemSlot(step.itemID)
            if step.kind=='ward' and not wardSlot then return false end
            if not self:spellReady(1,origin~=nil) or c:stage(1)~=1 or c.actions.pending[1]
                or d>(step.kind=='ward' and c.wards:range(wardSlot) or c.profile.wRange) then return false end
            if step.kind=='w' and (not U.valid(step.unit) or step.unit.team~=myHero.team) then return false end
            energy=energy-(c:spell(1).mana or 0)
        elseif step.kind=='flash' then
            if not self:flashAllowed(i) or not self:flashSlot(origin~=nil) or d>400 then return false end
        else return false end
        if energy<0 then return false end
        from=step.pos
    end
    if plan.walk then
        if U.dist(from,plan.walk)>c.config:get('insecWalk') or not c.terrain:walkLine(from,plan.walk,35) then return false end
        from=plan.walk
    end
    return self.b:planAligned(i,from)
end
function I:committed(i,aim)
    if self.ctx.config:get('aimLock')~=3 and not i.locked then
        i.destination=U.copy(aim);i.locked=true
        local d=U.toward(i.target.pos,aim,1);i.direction={x=d.x-i.target.pos.x,z=d.z-i.target.pos.z}
    end
end
function I:tick(i,aim)
    local c=self.ctx;local now=c:now();i.used=i.used or {};i.orbwalking=false
    -- Requesting a ward reserves W; it does not prove that W was consumed.
    -- Keep the exact attempt identity so a later cancelled input can release
    -- its reservation without confusing another jump or replaying a sent W.
    local ward=i.wardAttempt
    if ward and c.wards.pending~=ward then
        if ward.cancelled and c:stage(1)==1 and c:ready(1) and not c.actions.pending[1] and not c:dash() then
            local wEvent=ward.event and ward.event.slot==1 and ward.event or ward.earlyEvent
            local state=wEvent and c.actions.inputAction and c.actions:inputAction(wEvent.cursorID)
            local unsent=not wEvent or state and state.state=='cancelled_before_send' and not state.sentAt
                or not c.actions.api and wEvent.status=='cancelled' and not wEvent.keyAt
            if unsent then
                local placement=ward.event and c.actions.inputAction and c.actions:inputAction(ward.event.cursorID)
                local placementUnsent=placement and placement.state=='cancelled_before_send' and not placement.sentAt
                    or not c.actions.api and ward.event and ward.event.status=='cancelled' and not ward.event.keyAt
                i.used.w=nil;i.search=nil;i.plan=nil;i.phase='replan'
                if placementUnsent then i.wardCommitted=nil end
                if i.contract and ward.contractIndex and placementUnsent then
                    i.contractIndex=ward.contractIndex
                end
                if c.config.capture then c:log('insec_resource_released',{resource='w',reason=ward.cancelReason,evidence='Cancelled jump; W not sent and still ready'}) end
                i.wardAttempt=nil
            end
        elseif not ward.cancelled or c:stage(1)==2 then i.wardAttempt=nil end
    end
    if c.actions.syncWindow then
        for _,name in ipairs({'flight','qWait'}) do
            local window=i[name]
            if window then
                local state=c.actions:syncWindow(window)
                if state=='waiting' or state=='uncertain' then i.resource='Waiting for input confirmation';return end
                if state=='cancelled' then
                    local event=window.event
                    if event then
                        local resource=event.slot==0 and 'q' or event.slot==1 and 'w' or event.slot>=4 and 'f'
                        if resource then i.used[resource]=nil end
                        if event.contractIndex then i.contractIndex=event.contractIndex end
                    end
                    i[name]=nil;i.search=nil;i.plan=nil;i.phase='replan'
                end
            end
        end
    end
    -- Even while a hop is in flight the overlay tracks the current target.
    -- Already-issued movement cannot be retargeted by pretending its endpoint
    -- moved. Replan only from its confirmed landing before spending more.
    if c.wards.pending then
        local p=c.wards.pending
        if p.owner=='insec' then
            i.plan=self:search(i,p.target and p.target.pos or p.pos,p.state~='jumping' and (c:spell(1).mana or 0) or 0)
            i.resource=i.plan and ('Wardjump in flight > '..i.plan.label) or 'Wardjump: kick currently unreachable'
            if not i.plan and (i.contract or i.search and i.search.done) and p.state~='jumping' then
                c.wards:cancel('Target moved beyond remaining insec resources')
            end
        end
        return
    end
    if i.flight then
        local f=i.flight
        i.plan=self:search(i,f.unit and f.unit.pos or f.pos)
        i.resource=i.plan and ('In flight > '..i.plan.label) or 'In flight: kick currently unreachable'
        if c:dash() then return end
        if U.dist(myHero.pos,f.origin)>60 and (not f.event or f.event.status=='observed' or f.event.status=='completed') then i.flight=nil;i.search=nil;i.plan=nil
        elseif now>f.deadline then i.flight=nil;i.search=nil;i.plan=nil;i.phase='replan'
        else return end
    end
    if c:dash() then return end
    if self.b:kickValid(i) then
        local ok,event=c.spells:r(i.target,'insec',true)
        if ok then i.phase='kick';i.event=event end
        return
    end
    if i.qWait then
        local q=i.qWait
        -- Q can hit a different valid anchor after the prediction was made.
        -- Adopt observed owned marks, then validate the complete continuation.
        -- An explicitly confirmed anchor remains part of the user's contract.
        if not i.contract and c:stage(0)==2 and not c:mark(q.unit) then
            for _,unit in ipairs(self:units(i.target)) do
                if U.valid(unit) and c:mark(unit) then
                    if c.config.capture then c:log('insec_q_anchor_changed',{expected=U.id(q.unit),observed=U.id(unit)}) end
                    q.unit=unit;i.search=nil;i.plan=nil;break
                end
            end
        end
        local marked=U.valid(q.unit) and c:mark(q.unit) and c:stage(0)==2
        -- The missile arrival deadline is not the Q2 recast deadline. CC or
        -- another native cast lock can outlast arrival while the mark survives.
        if marked then
            q.markSeen=true;q.deadline=now+c:markLeft(q.unit)
            i.plan=self:q2Continuation(i,q.unit)
            if i.plan then
                local continuation=i.plan
                local ok,event=c.spells:q2(q.unit,'insec',true,nil,nil,function()
                    return self:q2Continuation(i,q.unit,continuation)~=nil,'insec_continuation_unreachable'
                end)
                if c.config.capture then c:trace('insec_q2_decision',{target=U.id(q.unit),marked=true,markLeft=c:markLeft(q.unit),
                    qReady=c:ready(0),rReady=c:ready(3),plan=i.plan.label,requested=ok},'q2',.15) end
                if ok then
                    i.qWait=nil;i.search=nil;i.phase='Q2 entry';i.flight={origin=U.copy(myHero.pos),pos=U.copy(q.unit.pos),unit=q.unit,event=event,deadline=now+1}
                end
            else
                i.resource='Q marked; kick currently unreachable'
                if c.config.capture then c:trace('insec_q2_decision',{target=U.id(q.unit),marked=true,markLeft=c:markLeft(q.unit),
                    requested=false,reason='No valid continuation from Q2 landing'},'q2',.15) end
            end
            return
        elseif not U.valid(q.unit) or now>q.deadline or q.markSeen and c:stage(0)~=2 then
            if c.config.capture then c:trace('insec_q_wait_ended',{target=U.id(q.unit),markSeen=q.markSeen,
                deadline=q.deadline,stage=c:stage(0)},'qwait',.15) end
            i.qWait=nil;i.used.q=nil;i.search=nil;i.phase='replan'
        else return end
    end
    local plan=self:adapt(i,self:search(i));i.plan=plan
    if plan and not self:validate(i,plan) then plan=nil end
    if c.config.capture then c:trace('insec_plan',{target=U.id(i.target),targetPos=U.copy(i.target.pos),origin=U.copy(myHero.pos),
        stand=U.copy(i.stand),endpoint=U.copy(i.endpoint),plan=plan and plan.label,
        wardSlot=c.wards:slot(),wStage=c:stage(1),wReady=c:ready(1),flashReason=i.flashReason,
        energy=myHero.mana,expanded=i.searchNodes,resources=i.resources,
        blocked=not plan and self:blockedReason(i) or nil},tostring(U.id(i.target)),.5) end
    if not plan then
        i.orbwalking=true;i.phase='cursor orbwalk';i.resource=self:blockedReason(i)
        return
    end
    i.resource=plan.label;i.phase='replan'
    local step=plan.steps[1]
    if not step then if plan.walk then c.actions:move(plan.walk,'insec') end;return end
    local ok,event
    if step.kind=='ward' then
        self.b:geometry(i,true)
        plan=self:adapt(i,plan)
        if not self:validate(i,plan) then i.search=nil;return end
        i.plan=plan;step=plan.steps[1]
        i.resource=#plan.steps==1 and not plan.walk and 'Ward / W' or plan.label
        ok=c.wards:start(step.pos,'insec',true,step.itemID)
        if ok then
            i.used.w=true;i.wardCommitted=true;i.phase='wardjump';i.wardAttempt=c.wards.pending
            if i.wardAttempt then i.wardAttempt.contractIndex=i.contractIndex or 1 end
        end
    elseif step.kind=='w' then
        if c.wards:jumpable(step.unit) then ok,event=c.spells:w(step.unit,'insec',true) end
        if ok then i.used.w=true;i.phase='W entry' end
    elseif step.kind=='flash' then
        if c:ready(3) then ok,event=c.spells:flash(step.pos,'insec') end
        if ok then i.used.f=true;i.phase='Flash' end
    elseif step.kind=='q' then
        if c:stage(0)==2 then
            local continuation=self:q2Continuation(i,step.unit)
            if continuation then
                ok,event=c.spells:q2(step.unit,'insec',true,nil,nil,function()
                    return self:q2Continuation(i,step.unit,continuation)~=nil,'insec_continuation_unreachable'
                end)
            else i.resource='Q marked; predicted kick landing unavailable';i.search=nil end
            if ok then i.used.q=true;i.phase='Q2 entry' end
        else
            -- Re-predict and collision-check from the actual casting position.
            ok,event=c.spells:q1(step.unit,'insec',false)
            if ok then
                i.used.q=true;i.phase='Waiting for Q mark'
                i.qWait={unit=step.unit,event=event,deadline=now+.25+U.dist(myHero.pos,step.unit.pos)/c.profile.qSpeed+math.max(.4,c.latency*2+c.jitter*3)}
            end
        end
    end
    if ok then
        if event then event.contractIndex=i.contractIndex or 1 end
        i.commitAt=i.commitAt or now
        if i.contract then i.contractIndex=(i.contractIndex or 1)+1 end
        i.search=nil
        self:committed(i,aim)
        if event and not i.qWait then i.flight={origin=U.copy(myHero.pos),pos=U.copy(step.pos),unit=step.unit,event=event,deadline=now+1} end
        if c.config.capture then c:log('insec_hop',{name=step.kind,plan=plan.label,target=U.id(i.target),origin=U.copy(myHero.pos),
            destination=U.copy(step.pos),wardSlot=c.wards:slot(),flashReason=i.flashReason}) end
    end
end
return I
