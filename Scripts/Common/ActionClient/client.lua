-- Public, provider-neutral intention client. Milliseconds throughout this module.
return function(g,transports,options)
    options=options or {};local sdk=assert(g.SDK);local active=options.active or function()return true end
    local hub=sdk.ActionClientHub
    if not hub then hub={resources={},clients={},serial=0};sdk.ActionClientHub=hub end
    hub.serial=hub.serial+1
    local C={locks={},id=hub.serial,name=options.name or 'plugin',jobs={},history={},resources={},gates={},closed=false}
    local transport=transports[sdk.OrbamaVersion and 'orbama' or 'gg'](g,sdk,function()return not C.closed and active()end,options)
    C.transport=transport;C.name=transport.name
    if not hub.hooks then
        hub.hooks=true
        for _,kind in ipairs({'attack','move'})do
            local register=kind=='attack' and 'OnPreAttack' or 'OnPreMovement'
            sdk.Orbwalker[register](sdk.Orbwalker,function(args)
                for _,client in pairs(hub.clients)do
                    if not client.closed and client:IsActive()then
                        for _,locks in pairs(client.locks)do if locks[kind]then args.Process=false;return end end
                    end
                end
            end)
        end
    end
    function C:IsActive()return active()end
    function C:SetBlocked(owner,kind,blocked)
        if self.resolving then return false,'resolver_side_effect'end

        if self.closed then return false end
        if kind~='attack' and kind~='move'then return false end
        self.locks[owner]=self.locks[owner]or {};self.locks[owner][kind]=blocked==true;return true
    end
    -- Compatibility diagnostic views: never use these to modify provider ownership.
    C.records=transport.records;C.queue=transport.queue
    local rank={critical=4,interactive=3,normal=2,background=1}
    local function call(fn,...)if not fn then return true end;local ok,a,b=pcall(fn,...);return ok and a==true,b or (not ok and 'condition_exception')end
    local function copy(t,seen,depth)
        if t==nil then return {}end
        assert(type(t)=='table','snapshot table required');seen=seen or {};depth=depth or 0
        assert(not seen[t] and depth<16,'cyclic or excessive snapshot');seen[t]=true
        local o={};local count=0
        for k,v in pairs(t)do count=count+1;assert(count<=256,'snapshot too large');o[k]=type(v)=='table' and copy(v,seen,depth+1)or v end
        seen[t]=nil;return o
    end
    local function same(a,b)
        if a.equivalence or b.equivalence then return a.equivalence~=nil and a.equivalence==b.equivalence end
        if a.type~=b.type or a.owner~=b.owner or a.targetID~=b.targetID or a.kind~=b.kind or #a.keys~=#b.keys then return false end
        for i,key in ipairs(a.keys)do if key~=b.keys[i]then return false end end
        if a.kind=='world' or a.kind=='screen' then
            return a.target and b.target and a.target.x==b.target.x and a.target.y==b.target.y and a.target.z==b.target.z
        end
        return a.target==b.target
    end
    function C:Now()return transport:Now()end
    function C:Capabilities()
        local c=copy(transport:Capabilities());c.contexts=true;c.resources=true;c.replaceUnsent=true
        c.observationTracking=true;c.boundedHistory=true;c.scopedConditions=true;c.sharedClientVersion=1;c.emergencyResourceRelease=true
        return c
    end
    function C:Available()return transport:Available()end
    function C:RegisterEmergencyYield(callback)
        if self.closed or self.resolving or type(callback)~='function'then return false end
        self.emergencyYield=callback;return true
    end
    function C:CooperateWithEvade(policy)
        if self.closed or self.resolving or type(policy)~='table'or type(policy.committed)~='function'
            or type(policy.yield)~='function'then return false end
        self.evadePolicy=policy;return true
    end
    function C:YieldUnsent(resource)
        if self.closed or self.resolving then return false end
        for id,q in pairs(self.jobs)do if not resource or q.resource==resource then
            local r=self:Poll(id)
            if r and not r.sentAt then self:Cancel(id,'evade_emergency');self:Finish(id)end
        end end
        if resource then return hub.resources[resource]==nil end
        return true
    end
    function C:RequestEmergencyRelease(resource,evidence)
        if self.closed or self.resolving or type(evidence)~='table' or evidence.likelyDeath~=true
            or type(evidence.expires)~='number' or evidence.expires<self:Now()
            or evidence.expires>self:Now()+250 then return false,'emergency_evidence_required'end
        local lease=hub.resources[resource]
        if not lease then return true end
        local owner=lease.client
        if owner==self then return false,'already_owned'end
        local record=owner:Poll(lease.id)
        if not record or record.sentAt or record.cleanupPending then return false,'resource_in_flight'end
        if not owner.emergencyYield then return false,'owner_declined'end
        local ok,accepted=pcall(owner.emergencyYield,resource,copy(evidence),lease.id)
        if not ok or accepted~=true then return false,'owner_declined'end
        -- Only the owner can cancel and release. A callback's true is not release.
        return hub.resources[resource]==nil,hub.resources[resource]and 'owner_release_pending' or nil
    end
    function C:IsSending()return transport.sending==true end
    function C:Condition(owner,name,condition,exceptions)
        if self.resolving then return false,'resolver_side_effect'end

        assert(type(condition)=='function');local token={owner=owner,name=name,condition=condition,exceptions=exceptions}
        self.gates[token]=true;return token
    end
    function C:ReleaseCondition(token)
        if self.resolving then return false,'resolver_side_effect'end
if self.gates[token]then self.gates[token]=nil;return true end;return false end
    function C:ContextValid(q,phase)
        if self.closed or not active() or g.myHero.dead or g.Game.IsChatOpen() or not g.Game.IsOnTop() then return false,'context_unavailable' end
        if self.evadePolicy and sdk.Evade and type(sdk.Evade.Evading)=='function' and sdk.Evade:Evading()and not q.evadeCompatible then return false,'evade_intervention'end
        local c=q.context
        if c then
            if c.modes then local yes=false;for _,mode in ipairs(c.modes)do if sdk.Orbwalker.Modes[mode]then yes=true end end;if not yes then return false,'mode_ended' end end
            if c.held and not call(c.held)then return false,'binding_released'end
            if c.condition and not call(c.condition,q)then return false,'context_condition_ended'end
        end
        if phase~='continuation' then
        for gate in pairs(self.gates)do
            if not (q.exceptions and q.exceptions[gate.name] and gate.exceptions and gate.exceptions[q.exceptions[gate.name]]) then
                if not call(gate.condition,q)then return false,'condition:'..gate.name end
            end
        end
        end
        return true
    end
    function C:Poll(id)return transport:Poll(id)end
    function C:UpdatePriority(id,priority)
        if self.resolving then return false,'resolver_side_effect'end
        local q=self.jobs[id]
        if not q or self.closed or not active() then return false,'unknown_or_inactive_action'end
        if not rank[priority]then return false,'invalid_priority'end
        if not transport.UpdatePriority then return false,'priority_update_unavailable'end
        local ok,why=transport:UpdatePriority(id,priority)
        if ok then q.priority=priority end
        return ok,why
    end
    function C:Finish(id,reconciled)
        if self.resolving then return false,'resolver_side_effect'end

        local q=self.jobs[id];if not q then return false end
        local r=self:Poll(id);if not r or r.state=='waiting' or r.state=='requested' then return false end
        if r.sentAt and not (r.mechanical or reconciled)then return false,'reconciliation_required'end
        if r.cleanupPending or r.sentAt and not (transport.Settled and transport:Settled(id) or not transport.Settled and transport:Available())then
            q.finishRequested=true;q.finishReconciled=reconciled;return false,'cleanup_pending'
        end
        transport:Acknowledge(id,reconciled)
        if q.resource then
            local lease=hub.resources[q.resource]
            if lease and lease.client==self and lease.id==id then hub.resources[q.resource]=nil end
            if self.resources[q.resource]==q then self.resources[q.resource]=nil end
        end
        self.jobs[id]=nil
        self.history[#self.history+1]=copy(r)
        while #self.history>128 do table.remove(self.history,1)end
        return true
    end
    function C:Reconcile(id)
        if self.resolving then return false,'resolver_side_effect'end

        local q=self.jobs[id];local r=q and self:Poll(id)
        if not r then return false end
        if not r.sentAt then return r.state=='cancelled_before_send' and self:Finish(id) end
        if r.mechanical then return self:Finish(id)end
        -- Timeout is only an admission budget. Fresh caller evidence is mandatory.
        if self:Now()<(r.sentAt+math.max(750,q.reconcileAfter or 1000)) or not transport:Available() then return false end
        if not q.reconcile or not call(q.reconcile,copy(r)) then return false,'fresh_evidence_required'end
        return self:Finish(id,'fresh_resource_state; historical execution unresolved')
    end
    function C:Cancel(id,reason)
        if self.resolving then return false,'resolver_side_effect'end
        local q=self.jobs[id];if q then q.cancelled=true end
        for child,other in pairs(self.jobs)do if other.dependency==id and child~=id then self:Cancel(child,'dependency_cancelled')end end
        return transport:Cancel(id,reason)
    end
    function C:CancelOwner(owner,reason)
        if self.resolving then return false,'resolver_side_effect'end

        for id,q in pairs(self.jobs)do if q.owner==owner then self:Cancel(id,reason)end end
        for gate in pairs(self.gates)do if gate.owner==owner then self.gates[gate]=nil end end
        self.locks[owner]=nil
    end
    function C:Submit(intent)
        if self.resolving then return nil,'resolver_side_effect'end
        if self.closed or not active() then return nil,'inactive'end
        local q={};for k,v in pairs(intent)do q[k]=v end
        q.owner=q.owner or 'default';q.priority=q.priority or 'normal';q.expires=q.expires or self:Now()+250
        q.type=q.type or 'cast';q.keys=q.keys or (q.key and {q.key} or {});q.kind=q.kind or (q.target and q.target.pos and 'object' or q.target and 'world' or 'none')
        if type(q.keys)~='table'then q.keys={q.keys}end;q.keys=copy(q.keys)
        if q.kind=='world' or q.kind=='screen'then q.target=q.target and {x=q.target.x,y=q.target.y,z=q.target.z}end
        if q.world then
            if type(q.world)~='table' and type(q.world)~='userdata'then return nil,'invalid_world_point'end
            local x,z=q.world.x,q.world.z
            if type(x)~='number' or type(z)~='number' or x~=x or z~=z or math.abs(x)==math.huge or math.abs(z)==math.huge then return nil,'invalid_world_point'end
            q.world={x=x,y=q.world.y or 0,z=z}
        end
        if q.count~=nil and (q.type~='click' or type(q.count)~='number' or q.count%1~=0 or q.count<1 or q.count>8)then return nil,'invalid_click_count'end
        if q.kind=='object' and not q.targetID and q.target then q.targetID=q.target.networkID or q.target.handle end
        q.context=copy(q.context);q.exceptions=copy(q.exceptions)
        if not rank[q.priority]or q.expires<=self:Now()then return nil,'invalid_priority_or_deadline'end
        if q.dependency and not self.jobs[q.dependency]then return nil,'foreign_or_unknown_dependency'end
        for _,previous in pairs(hub.clients)do if previous.closed then previous:Collect()end end
        local lease=q.resource and hub.resources[q.resource]
        if lease then
            if lease.client~=self then return nil,'foreign_resource_conflict'end
            self:Reconcile(lease.id);lease=hub.resources[q.resource]
            if lease then
                local old=self.jobs[lease.id];local r=self:Poll(lease.id)
                local equivalent=old and same(old,q)
                local replacing=q.replace=='higher_priority' and old and rank[q.priority]>rank[old.priority]
                if equivalent and not replacing then
                    if rank[q.priority]>rank[old.priority] then
                        local ok,why=self:UpdatePriority(lease.id,q.priority)
                        if not ok then return nil,why end
                    end
                    return lease.id,'deduplicated'
                end
                if q.replace~='higher_priority' or not old or rank[q.priority]<=rank[old.priority]then return nil,'resource_reserved'end
                if not r or r.sentAt or r.state=='send_uncertain'then return nil,'resource_already_attempted'end
                -- Explicit promotion replaces only unissued work, never extends its budget.
                if equivalent then q.expires=math.min(q.expires,old.expires)end
                self:Cancel(lease.id,'replaced_by_higher_priority')
                r=self:Poll(lease.id)
                if not r or r.state~='cancelled_before_send' or r.cleanupPending or (r.acquiredAt and not r.releasedAt)then return nil,'replacement_cleanup_pending'end
                self:Finish(lease.id)
            end
        end
        local count=0;for _ in pairs(self.jobs)do count=count+1 end;if count>=128 then return nil,'unconsumed_results_full'end
        if q.resolve then
            local resolver=q.resolve
            q.resolve=function(context)
                self.resolving=true;local ok,result,why=pcall(resolver,context);self.resolving=false
                if not ok then return nil,'resolver_exception'end
                if not result then return nil,why end
                local p=result.position or result
                if type(p.x)~='number' or type(p.z)~='number' or p.x~=p.x or p.z~=p.z or math.abs(p.x)==math.huge or math.abs(p.z)==math.huge then return nil,'invalid_world_point'end
                return {position={x=p.x,y=p.y or 0,z=p.z},data=copy(result.data)}
            end
        end
        local mechanical=q.mechanical
        q.mechanical=function(resolved)
            local ok,reason=self:ContextValid(q);if not ok then return false,reason end
            if q.cancelled then return false,'cancelled'end
            if q.kind=='object' and (not q.target or (q.target.networkID or q.target.handle)~=q.targetID)then return false,'target_identity_changed'end
            if q.dependency then
                local p=self:Poll(q.dependency)
                if not p or p.jobCancelled or p.state=='cancelled_before_send'then return false,'dependency_cancelled'end
                local ready=q.dependencyState=='mechanical' and p.mechanical or q.dependencyState=='effect' and p.effect or not q.dependencyState and p.sentAt or q.dependencyState=='sent' and p.sentAt
                if not ready then return false,'dependency_waiting'end
            end
            if q.ready and not call(q.ready)then return false,'not_ready'end
            return call(mechanical,resolved)
        end
        local id,reason=transport:Submit(q);if not id then return nil,reason end
        q.id=id;self.jobs[id]=q
        if q.resource then self.resources[q.resource]=q;hub.resources[q.resource]={client=self,id=id}end
        return id,reason
    end
    function C:Cast(key,target,opts)local q={};for k,v in pairs(opts or {})do q[k]=v end;q.key=key;q.keys={key};q.target=target;q.type='cast';return self:Submit(q)end
    function C:Attack(target,opts)local q={};for k,v in pairs(opts or {})do q[k]=v end;q.target=target;q.type='attack';return self:Submit(q)end
    function C:Move(target,opts)local q={};for k,v in pairs(opts or {})do q[k]=v end;q.target=target;q.type='move';return self:Submit(q)end
    function C:Observe(id,evidence)return transport:Observe(id,evidence)end
    function C:Claim(name,on)if self.resolving then return false,'resolver_side_effect'end;return transport:Claim(name,on)end
    function C:Tick()
        for id,q in pairs(self.jobs)do
            local r=self:Poll(id)
            if r and not r.sentAt and not self:ContextValid(q)then self:Cancel(id,'context_ended')end
        end
        transport:Tick();self.sending=transport.sending
        for id,q in pairs(self.jobs)do if q.finishRequested then self:Finish(id,q.finishReconciled)end end
    end
    function C:Close(reason)
        if self.resolving then return false,'resolver_side_effect'end

        if self.closed then return end
        self.closed=true;self.gates={};self.locks={};transport:Close(reason)
        for id in pairs(self.jobs)do self:Reconcile(id)end
    end
    -- Closed clients with historical sends remain only until explicit fresh reconciliation.
    hub.clients[C.id]=C
    function C:Collect()
        for id in pairs(self.jobs)do self:Reconcile(id)end
        if self.closed and next(self.jobs)==nil then hub.clients[self.id]=nil end
    end
    for _,previous in pairs(hub.clients)do if previous~=C and previous.closed then previous:Collect()end end
    return C
end
