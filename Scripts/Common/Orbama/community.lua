-- Public v1 contract. All host effects remain inside the input owner.
return function(input, clock, selectCandidate)
    if not selectCandidate then
        selectCandidate=function(candidates)
            local best,index
            for i,a in ipairs(candidates)do
                local b=best
                if not b or a.effective>b.effective or a.effective==b.effective and (
                    a.record.expires<b.record.expires or a.record.expires==b.record.expires and (
                        a.selectionLast<b.selectionLast or a.selectionLast==b.selectionLast and a.record.id<b.record.id)) then best,index=a,i end
            end
            return best,index
        end
    end
    local api={version=1,scopes={},queue={},actions={},sequences={},serial=0,turn=0,history={},scopeSerial=0,automation={},automationEpoch={cleanse=0,qss=0}}
    local rank={background=1,normal=2,interactive=3,critical=4}
    local function finite(n) return type(n)=='number' and n==n and math.abs(n)<math.huge end
    local function copy(t)
        if type(t)~='table' then return t end
        local out={};for k,v in pairs(t) do out[k]=copy(v) end;return out
    end
    local function reason(r)
        if r.generation~=input.Generation then return 'interrupted' end
        if clock()>r.expires then return 'expired' end
    end
    local function state(a)
        local r=a.record
        if r.sentAt then return r.submissionFailed and 'send_uncertain' or 'sent' end
        if r.state=='aborted' then return 'cancelled_before_send' end
        return a.waiting and 'waiting' or 'requested'
    end
    function api:Now() return clock() end
    function api:GetCapabilities()
        return {version=1,createClient=type(self.CreateClient)=='function',updatePriority=true,actionCleanupState=true,timebase='monotonic milliseconds; same epoch as GetTickCount',
            states={'requested','waiting','sent','cancelled_before_send','send_uncertain'},
            priorities={'critical','interactive','normal','background'},scopes=true,sequences=true,
            aimCandidates=true,aimFallback=true,maxAimCandidates=5,retryKeys=true,observations=true,keyedMechanicalObservation=true,maxWaitingPerScope=32,maxWaiting=128,
            attackApproach=type(input.env.executeApproach)=='function',
            independentMotion=false,withholdInput=false,hideCursor=false,survivePointerMotion=true,surviveMovementCommands=true,resolveWorldTarget=true,prevalidateWorldCast=true,worldCommitMaxMs=20,automationClaims=true,automationFunctions={"cleanse","qss"}}
    end
    function api:GetAvailability()
        return {available=input:Available() and not input.Uncertain,busy=input.Active~=nil or input.Step>0,
            uncertain=input.Uncertain==true,generation=input.Generation,activeID=input.Active and input.Active.id,
            pendingReturn=input.PendingReturn~=nil,cleanupPending=input.Active~=nil or input.PendingReturn~=nil
                or next(input.PendingUp or {})~=nil or next(input.Buttons or {})~=nil or next(input.KeysOwned or {})~=nil,at=clock()}
    end
    function api:GetPlayerPosition() return input:GetPlayerPosition() end
    function api:GetPlayerScreenPosition() return input:GetPlayerScreenPosition() end
    function api:RegisterScope(name,options)
        if type(name)~='string' or #name==0 or #name>64 then return nil,'invalid_scope' end
        options=options or {};local classes={normal=true}
        for _,p in ipairs(options.priorities or {}) do if not rank[p] then return nil,'invalid_priority' end;classes[p]=true end
        for _,s in pairs(self.scopes) do if s.name==name and not s.closed then return nil,'scope_exists' end end
        self.scopeSerial=self.scopeSerial+1
        local s={id=self.scopeSerial,name=name,classes=classes,cap='critical',waiting=0,last=0,retries={}}
        self.scopes[s.id]=s
        if self.onRegister then self.onRegister(s) end
        local handle={id=s.id}
        function handle:Request(request) return api:Request(self.id,request) end
        function handle:Sequence(steps,options) return api:Sequence(self.id,steps,options) end
        function handle:GetAction(id) return api:GetAction(self.id,id) end
        function handle:UpdatePriority(id,priority) return api:UpdatePriority(self.id,id,priority) end
        function handle:Cancel(id,why) return api:Cancel(self.id,id,why) end
        function handle:CancelOwner(owner,why) return api:CancelOwner(self.id,owner,why) end
        function handle:CancelSequence(id,why) return api:CancelSequence(self.id,id,why) end
        function handle:GetSequence(id) return api:GetSequence(self.id,id) end
        function handle:Observe(id,evidence) return api:Observe(self.id,id,evidence) end
        function handle:ClaimAutomation(name) return api:ClaimAutomation(self.id,name) end
        function handle:ReleaseAutomation(name) return api:ReleaseAutomation(self.id,name) end
        function handle:Close(why) return api:CloseScope(self.id,why) end
        return handle
    end
    function api:ClaimAutomation(scope,name)
        local s=self.scopes[scope]
        if not s or s.closed then return false,'scope_closed' end
        if self.automationEpoch[name]==nil then return false,'unsupported_automation' end
        if self.automation[name] and self.automation[name]~=scope then return false,'already_claimed' end
        if self.automation[name]~=scope then
            self.automationEpoch[name]=self.automationEpoch[name]+1;self.automation[name]=scope
        end
        return true
    end
    function api:ReleaseAutomation(scope,name)
        if self.automation[name]~=scope then return false,'not_owner' end
        self.automation[name]=nil;self.automationEpoch[name]=self.automationEpoch[name]+1;return true
    end
    function api:GetAutomation(name)
        if self.automationEpoch[name]==nil then return nil,'unsupported_automation' end
        return {scope=self.automation[name],epoch=self.automationEpoch[name],builtin=self.automation[name]==nil}
    end
    function api:AllowsBuiltin(name,epoch)
        return self.automationEpoch[name]~=nil and self.automation[name]==nil
            and (epoch==nil or epoch==self.automationEpoch[name])
    end
    input.Automation=api
    function api:ResumeUnsentMotion(r)
        local a=r and self.actions[r.id];local s=a and self.scopes[a.scope]
        -- Resume only a cursor preparation, never a possibly delivered input.
        -- Each retry retains the original identity/deadline and resolves again.
        if not a or not s or s.closed or a.cancelled or a.type~='cast' or a.dependency or a.handoff or a.sequence
            or r.sentAt or r.submissionFailed or r.keyLease or r.followup or input.Active
            or input.PendingReturn or not r.returnObservedAt or not input:Available()
            or (r.motionResumes or 0)>=2 or clock()+input.env.fallback()>=r.expires then return false end
        for _,owner in pairs(input.KeysOwned) do if owner==r.owner then return false end end
        for _,pending in pairs(input.PendingUp) do if pending.owner==r.owner then return false end end
        for _,button in pairs(input.Buttons) do if button.owner==r.owner then return false end end
        local queued=false;for _,q in ipairs(self.queue) do if q==a then queued=true;break end end
        if not queued and (s.waiting>=32 or #self.queue>=128) then return false end
        r.motionResumes=(r.motionResumes or 0)+1
        r.generation=input.Generation;r.state='requested';r.reason=nil;r.abortedAt=nil;r.interrupted=nil;r.manualAt=nil
        r.rootAt=nil;r.budgetEnd=nil;r.returnTarget=nil;r.predecessorID=nil;r.chainDepth=0
        r.preparedPosition=nil;r.preparedAt=nil;r.acquiredAt=nil;r.actionScreen=nil;r.awaitingPosition=nil
        r.positionPasses=nil;r.resolvedPass=nil;r.confirmAfterPass=nil;r.nativePlacementConfirmedAt=nil
        r.sendAfter=nil;r.releasedAt=nil;r.returnRequestedAt=nil;r.returnObservedAt=nil;r.returnRetried=nil
        a.dispatched=false;a.waiting=true
        if not queued then self.queue[#self.queue+1]=a;s.waiting=s.waiting+1 end
        input:record('waiting_resumed',r,'Unsent preparation interrupted; fresh validation before reacquisition')
        return true
    end
    function api:SetPriorityLimit(scope,priority)
        local s=self.scopes[scope];if not s or not rank[priority] then return false,'invalid_priority' end
        s.cap=priority;s.readLimit=nil;return true
    end
    -- Priority-only escalation preserves identity, validators, deadlines and descendants.
    function api:UpdatePriority(scope,id,priority)
        if input.Resolving then return false,'resolver_side_effect' end
        local s=self.scopes[scope];local a=self.actions[id]
        if not s or s.closed then return false,'scope_closed' end
        if not a or a.scope~=scope then return false,'unknown_action' end
        if not rank[priority] or not s.classes[priority] then return false,'priority_not_declared' end
        local r=a.record
        if a.cancelled or not a.waiting or r.sentAt or r.state=='aborted' or clock()>=r.expires then return false,'not_waiting' end
        if rank[priority]<rank[a.priority] then return false,'priority_downgrade' end
        a.priority=priority;r.priorityClass=priority
        a.effective=math.min(rank[priority],s.readLimit and s.readLimit() or rank[s.cap])
        return true
    end
    function api:GetScopes()
        local out={};for id,s in pairs(self.scopes) do if not s.closed then
            out[#out+1]={id=id,name=s.name,limit=s.cap,waiting=s.waiting}
        end end;table.sort(out,function(a,b)return a.id<b.id end);return out
    end
    local function actionCleanupPending(r)
        if input.Active==r or input.PendingReturn==r then return true end
        for _,owner in pairs(input.KeysOwned or {})do if owner==r.owner then return true end end
        for _,pending in pairs(input.PendingUp or {})do if pending.owner==r.owner then return true end end
        for _,button in pairs(input.Buttons or {})do if button.action==r or button.owner==r.owner then return true end end
        return false
    end
    function api:GetAction(scope,id)
        local a=self.actions[id];if not a or a.scope~=scope then return nil,'unknown_action' end
        local r=a.record
        return {id=id,owner=a.owner,state=state(a),priority=a.priority,requestedAt=r.requestedAt,
            waitingAt=a.waitingAt,sentAt=r.sentAt,sendCompletedAt=r.sendCompletedAt,
            cleanupPending=actionCleanupPending(r),releasedAt=r.releasedAt,returnRequestedAt=r.returnRequestedAt,returnObservedAt=r.returnObservedAt,holdUntil=r.holdUntil,
            cancelledAt=r.abortedAt,reason=r.reason,jobCancelled=a.cancelled==true,
            jobCancelledAt=a.cancelledAt,cancellationReason=a.cancellationReason,
            descendantsCancelledAt=a.descendantsCancelledAt,descendantsCancellationReason=a.descendantsCancellationReason,interrupted=r.interrupted,competitor=r.competitor,
            resolution=input.ResolutionSnapshot and input:ResolutionSnapshot(r),positionPasses=r.positionPasses,aim=copy(r.aim),retryAfter=r.retryAfter,positionedAt=r.positionedAt,acquiredAt=r.acquiredAt,
            commandReceipt=a.type=='cast' and not r.submissionFailed and copy(r.commandReceipt) or nil,
            interferenceID=r.interferenceID,interferenceAt=r.interferenceAt,interferenceCause=r.interferenceCause,
            generation=r.generation,mechanical=copy(a.mechanical),effect=copy(a.effect),
            handoffStatus=r.handoffStatus,keyLease=r.keyLease,inputSession=input.SessionID}
    end
    local function abort(a,why)
        local r=a.record
        if not r.sentAt and r.state~='aborted' then r.state='aborted';r.abortedAt=clock();r.reason=why;input:record('aborted',r,why) end
        a.cancelled=true;a.cancelledAt=a.cancelledAt or clock();a.cancellationReason=a.cancellationReason or why
    end
    function api:Cancel(scope,id,why)
        local a=self.actions[id];if not a or a.scope~=scope then return false,'unknown_action' end
        abort(a,why or 'cancelled')
        a.descendantsCancelledAt=a.descendantsCancelledAt or clock()
        a.descendantsCancellationReason=a.descendantsCancellationReason or why or 'cancelled'
        local r=a.record
        if input.Active and input.Active.followup==r then input.Active.followup=nil end
        if input.Active==r and not r.sentAt then input:release(why or 'cancelled') end
        -- A sent command keeps its stabilization phase. Only unsent descendants stop.
        for _,b in pairs(self.actions) do if b.scope==scope and b.dependency==id then self:Cancel(scope,b.record.id,why) end end
        return true,r.sentAt and 'already_sent' or 'cancelled_before_send'
    end
    function api:CancelOwner(scope,owner,why)
        for id,a in pairs(self.actions) do if a.scope==scope and a.owner==owner then self:Cancel(scope,id,why) end end
        local token='community:'..scope..':'..tostring(owner)
        for key,who in pairs(input.KeysOwned) do if who==token then input:ReleaseKey(key,who,nil,nil,true) end end
        input:CleanupButtons(false,token)
        return true
    end
    function api:CloseScope(scope,why)
        local s=self.scopes[scope];if not s then return false,'unknown_scope' end
        if s.closed then return true end;s.closed=true
        for name,owner in pairs(self.automation) do if owner==scope then self:ReleaseAutomation(scope,name) end end
        for id in pairs(self.sequences) do self:CancelSequence(scope,id,why or 'scope_closed') end
        for id,a in pairs(self.actions) do if a.scope==scope then self:Cancel(scope,id,why or 'scope_closed') end end
        local prefix='community:'..scope..':'
        for key,who in pairs(input.KeysOwned) do if who:sub(1,#prefix)==prefix then input:ReleaseKey(key,who,nil,nil,true) end end
        for _,row in pairs(input.Buttons) do if row.owner:sub(1,#prefix)==prefix then input:CleanupButtons(false,row.owner) end end
        self:Prune();return true
    end
    function api:Prune()
        for i=#self.queue,1,-1 do
            local a=self.queue[i];local why=reason(a.record)
            if why then abort(a,why) end
            if a.cancelled or a.record.state=='aborted' or a.dispatched then
                if input.Active and input.Active.followup==a.record and (a.cancelled or a.record.state=='aborted') then
                    input.Active.followup=nil
                end
                a.waiting=false;self.scopes[a.scope].waiting=self.scopes[a.scope].waiting-1;table.remove(self.queue,i)
            end
        end
        -- Keep pending and actively held records; bound completed public history.
        while #self.history>256 do
            local removed=false
            for i,id in ipairs(self.history) do local a=self.actions[id]
                if a and not a.waiting and input.Active~=a.record and not a.sequence and not a.releaseDeadline then
                    self.actions[id]=nil;table.remove(self.history,i);removed=true;break
                end
            end
            if not removed then break end
        end
    end
    function api:Request(scope,q)
        if input.Resolving then return nil,"resolver_side_effect" end
        local s=self.scopes[scope];if not s or s.closed then return nil,'scope_closed' end
        if type(q)~='table' then return nil,'invalid_request' end
        if q.owner~=nil and (type(q.owner)~='string' or #q.owner>64) then return nil,'invalid_owner' end
        local p=q.priority or 'normal'
        if not rank[p] or not s.classes[p] then return nil,'priority_not_declared' end
        if not finite(q.expires) or q.expires<clock() then return nil,'expired' end
        if type(q.validate)~='function' then return nil,'validation_required' end
        local types={cast=true,attack=true,move=true,click=true,hover=true,key=true,chord=true,key_down=true,key_up=true}
        if not types[q.type] then return nil,'invalid_type' end
        if q.type=='attack' and (q.targetKind~='object' or not input.env.executeAttack) then return nil,'attack_unavailable' end
        if q.approach~=nil and (type(q.approach)~='boolean' or q.type~='attack') then return nil,'invalid_attack_approach' end
        if q.approach and not input.env.executeApproach then return nil,'attack_approach_unavailable' end
        if q.survivePointerMotion~=nil and (type(q.survivePointerMotion)~='boolean'
            or q.type~='cast' or q.dependency or q.handoff or q.targetKind~='world' and q.targetKind~='object' and q.targetKind~='none') then
            return nil,'invalid_pointer_motion_policy'
        end
        if q.surviveMovementCommands~=nil and (type(q.surviveMovementCommands)~='boolean'
            or q.type~='cast' or q.dependency or q.handoff or q.targetKind=='screen') then
            return nil,'invalid_movement_command_policy'
        end
        if q.targetKind~='none' and q.targetKind~='object' and q.targetKind~='world' and q.targetKind~='screen' then return nil,'invalid_target_kind' end
        local t=q.target
        if q.targetKind=='object' and (not t or not t.pos or not (t.networkID or t.handle)) then return nil,'invalid_target' end
        if q.targetKind=='world' and (not t or not finite(t.x) or not finite(t.z) or t.pos) then return nil,'invalid_target' end
        if q.targetKind=='screen' and (not t or not finite(t.x) or not finite(t.y) or t.z~=nil or t.pos) then return nil,'invalid_target' end
        if q.targetKind=='none' and t~=nil then return nil,'invalid_target' end
        if (q.type=='hover' or q.type=='move' or q.type=='click') and not t then return nil,'target_required' end
        local keys=q.keys or {};if type(keys)~='table' then keys={keys} end
        if #keys>8 then return nil,'too_many_keys' end
        for _,key in ipairs(keys) do if not finite(key) or key%1~=0 or key<=0 then return nil,'invalid_key' end end
        if (q.type=='key' or q.type=='cast' or q.type=='chord' or q.type=='key_down' or q.type=='key_up') and #keys==0 then return nil,'key_required' end
        if q.type=='chord' and #keys~=2 then return nil,'invalid_chord' end
        if q.dependency then local d=self.actions[q.dependency];if not d or d.scope~=scope then return nil,'invalid_dependency' end end
        if q.dependencyState and q.dependencyState~='sent' and q.dependencyState~='mechanical' and q.dependencyState~='effect' then return nil,'invalid_dependency_state' end
        if q.resolveWorldTarget~=nil and (type(q.resolveWorldTarget)~='function' or q.type~='cast' or q.targetKind~='world' or q.world or q.handoff) then return nil,'invalid_world_resolver' end
        if q.prevalidateWorldCast~=nil and (type(q.prevalidateWorldCast)~='boolean'
            or q.prevalidateWorldCast and (not q.resolveWorldTarget or #keys~=1 or q.verifyTarget
                or q.aimCandidates or q.dependency or q.handoff)) then return nil,'invalid_prevalidated_cast' end
        if q.commitGuard~=nil and (not q.prevalidateWorldCast or type(q.commitGuard)~='function') then return nil,'invalid_commit_guard' end
        if q.ready and type(q.ready)~='function' then return nil,'invalid_condition' end
        if q.aimCandidates and (type(q.aimCandidates)~='function' or q.targetKind~='object') then return nil,'invalid_aim_candidates' end
        if q.aimFallback and (type(q.aimFallback)~='function' or not q.aimCandidates) then return nil,'invalid_aim_fallback' end
        if q.retryKey and (type(q.retryKey)~='string' or #q.retryKey>128) then return nil,'invalid_retry_key' end
        self:Prune();if s.waiting>=32 or #self.queue>=128 then return nil,'queue_full' end
        local owner='community:'..scope..':'..tostring(q.owner or 'default')
        local r=input:newAction{owner=owner,keys=q.type=='move' and input.env.moveKey or keys,target=t,
            validate=q.validate,verifyTarget=q.verifyTarget or q.aimCandidates and t,aimCandidates=q.aimCandidates,aimFallback=q.aimFallback,expires=q.expires,world=q.world,
            leftClicks=q.type=='click' and (q.count or 1) or nil,class=q.type=='move' and 'move' or q.type=='hover' and 'hover' or 'cast',critical=q.type~='move'}
        local a={scope=scope,owner=q.owner or 'default',record=r,priority=p,type=q.type,
            dependency=q.dependency,dependencyState=q.dependencyState or 'sent',ready=q.ready,
            handoff=q.handoff==true,waiting=true,waitingAt=clock()}
        if q.retryKey then
            a.retryKey=q.retryKey
            r.onAimFailure=function(record)
                local untilAt=clock()+50;record.retryAfter=untilAt
                for key,row in pairs(s.retries) do if row<=clock() then s.retries[key]=nil end end
                local count=0;for _ in pairs(s.retries) do count=count+1 end
                if count>=128 then local oldest,key=math.huge,nil;for k,v in pairs(s.retries) do if v<oldest then oldest,key=v,k end end;s.retries[key]=nil end
                s.retries[q.retryKey]=untilAt
            end
        end
        r.resolveWorldTarget=q.resolveWorldTarget;r.intentTargetID=q.intentTargetID
        r.prevalidateWorldCast=q.prevalidateWorldCast==true;r.commitGuard=q.commitGuard
        r.publicScope=scope;r.priorityClass=p;r.publicType=q.type;r.approach=q.approach==true
        r.surviveMovementCommands=q.surviveMovementCommands==true
        r.survivePointerMotion=q.survivePointerMotion==true or r.surviveMovementCommands
        self.actions[r.id]=a;self.history[#self.history+1]=r.id;self.queue[#self.queue+1]=a;s.waiting=s.waiting+1
        input:record('waiting',r,nil,{apiVersion=1,targetKind=q.targetKind,expires=r.expires})
        self:Pump();return r.id,state(a)
    end
    function api:Observe(scope,id,evidence)
        local a=self.actions[id]
        if not a or a.scope~=scope or not a.record.sentAt then return false,'not_sent' end
        if type(evidence)~='table' or (evidence.kind~='mechanical' and evidence.kind~='effect')
            or type(evidence.source)~='string' or evidence.unique~=true or not finite(evidence.at)
            or evidence.at<a.record.sentAt or evidence.at>clock() then return false,'invalid_evidence' end
        if evidence.attribution=='command_key' then
            local receipt=a.record.commandReceipt
            if evidence.kind~='mechanical' or a.type~='cast' or a.record.submissionFailed or not receipt
                or evidence.key~=receipt.key or evidence.generation~=receipt.generation
                or evidence.session~=receipt.session or clock()>receipt.expiresAt
                or input:CommandGeneration(receipt.key)~=receipt.generation then
                return false,'ambiguous_command'
            end
        elseif evidence.attribution~=nil then return false,'unsupported_attribution'
        elseif a.record.interrupted or a.record.competitor then return false,'ambiguous' end
        a[evidence.kind]={at=evidence.at,source=evidence.source,result=evidence.result or 'observed',attribution=evidence.attribution}
        input:record(evidence.kind..'_observed',a.record,evidence.source,{evidenceAt=evidence.at,evidenceResult=evidence.result})
        -- Plugin assertions never validate a timing source. Mechanical != impact.
        return true
    end
    function api:DependencyReady(a)
        if not a.dependency then return true end
        local d=self.actions[a.dependency]
        if not d or d.cancelled or d.record.state=='aborted' then abort(a,'dependency_cancelled');return false end
        if a.dependencyState=='sent' then return d.record.sentAt~=nil and not d.record.submissionFailed end
        return d[a.dependencyState]~=nil
    end
    local function deferHandoff(previous,why)
        local r=previous.followup;previous.followup=nil
        -- Keep the queued request and its logical dependency, but discard the
        -- reservation. A later dispatch samples the player and projects afresh.
        r.rootAt=nil;r.budgetEnd=nil;r.returnTarget=nil;r.predecessorID=nil
        r.chainDepth=0;r.preparedPosition=nil;r.handoffStatus=why
        input:record('handoff_deferred',r,why)
        if clock()>=(previous.holdUntil or math.huge) then input:release(why) end
    end
    function api:Pump(minimum)
        if self.pumping or input.Resolving then return end;self.pumping=true
        input.ResolutionPass=(input.ResolutionPass or 0)+1
        local ok,err=pcall(function()
            self:Prune()
            if not input:Available() or input.Uncertain then return end
            local candidates={}
            for _,a in ipairs(self.queue) do
                local s=self.scopes[a.scope]
                local limit=s.readLimit and s.readLimit() or rank[s.cap]
                a.effective=math.min(rank[a.priority],limit)
                local ready=true
                if a.ready then local yes,value=pcall(a.ready);ready=yes and value==true;if not yes then abort(a,'condition_error') end end
                local dependency=not a.cancelled and self:DependencyReady(a)
                local retry=a.retryKey and s.retries[a.retryKey]
                local retryBlocked=retry and clock()<retry
                if retryBlocked and a.record.verifyTarget then
                    if input:VerifyHover(a.record) then s.retries[a.retryKey]=nil;retryBlocked=false end
                end
                a.record.retryAfter=retryBlocked and retry or a.record.retryAfter
                local blocked=input:InputsBlocked(a.record) or retryBlocked
                local previous=input.Active
                if previous and previous.followup==a.record
                    and (not ready or not dependency or blocked) then
                    deferHandoff(previous,'waiting without cursor reservation')
                end
                if not a.cancelled and ready and dependency and not blocked and a.effective>=(minimum or 1) then a.selectionLast=s.last;candidates[#candidates+1]=a end
            end
            local function pollPrepared()
                local r=input.Active;local running=r and self.actions[r.id]
                if running and r.awaitingPosition and (running.effective or rank[running.priority])>=(minimum or 1) then
                    input:PollPlacement(r)
                end
            end
            if #candidates==0 then pollPrepared();return end
            while #candidates>0 do
            local a,index=selectCandidate(candidates)
            candidates[index]=candidates[#candidates];candidates[#candidates]=nil
            local r=a.record;local previous=input.Active
            if previous and previous.followup==r and clock()<(previous.holdUntil or 0) then return end
            local chain=previous and a.type~='move' and a.handoff and a.dependency==previous.id and previous.owner==r.owner
                and (not previous.followup or previous.followup==r) and (previous.chainDepth or 0)<1
            if previous and not chain then
                if previous.followup and clock()>=(previous.holdUntil or math.huge) then
                    -- Prepared work is still queued. Return the predecessor safely
                    -- before admitting a higher ranked independent action.
                    deferHandoff(previous,'yielded to priority')
                    return
                end
                local running=self.actions[previous.id]
                if not previous.sentAt and a.effective>(running and running.effective or 2) then
                    input:release('preempted before send');if running then abort(running,'preempted') end
                else pollPrepared() end
                return
            end
            if not chain and input.Step>0 then return end
            if clock()<input.NotBefore and not chain then return end
            if input:InputsBlocked(r) then return end
            if chain then
                r.returnTarget=copy(previous.returnTarget or previous.playerScreen);r.rootAt=previous.rootAt
                r.budgetEnd=previous.budgetEnd;r.predecessorID=previous.id;r.chainDepth=(previous.chainDepth or 0)+1
            end
            self.turn=self.turn+1;self.scopes[a.scope].last=self.turn;a.dispatched=true
            local worked,result=pcall(function()
                if a.type=='attack' then
                    if r.approach then return input.env.executeApproach(r) end
                    return input.env.executeAttack(r)
                end
                if a.type=='key_down' or a.type=='key_up' or a.type=='chord' then
                    if not input:valid(r) then return false end
                    local sent
                    if a.type=='key_down' then
                        sent=input:AcquireKey(r.keys[1],r.owner,r)
                        if sent then a.releaseDeadline=math.min(r.expires,clock()+500) end
                    elseif a.type=='key_up' then sent=input:ReleaseKey(r.keys[1],r.owner,r)
                    else
                        sent=input:AcquireKey(r.keys[1],r.owner,r)
                        if sent then sent=input:PulseKeys(r.keys[2],r.owner,r) end
                        if not input:ReleaseKey(r.keys[1],r.owner,r) then sent=false end
                    end
                    r.releasedAt=clock();return sent
                end
                return input:dispatch(r,chain and previous or nil)
            end)
            if previous and previous.followup==r and not r.sentAt then a.dispatched=false end
            if not worked or not result then
                if r.sentAt then r.submissionFailed=true;r.reason=worked and 'send_uncertain' or tostring(result)
                else abort(a,worked and (r.reason or 'validation_declined') or 'host_exception') end
                if not worked and input.Active==r then input:release('host_exception') end
            end
            self:Prune()
            if r.sentAt or input.Active or input.Step>0 then return end
            end
        end)
        self.pumping=false;if not ok then error(err,0) end
    end
    function api:Sequence(scope,steps,options)
        local s=self.scopes[scope];if not s or s.closed then return nil,'scope_closed' end
        if type(steps)~='table' or #steps==0 or #steps>32 then return nil,'invalid_sequence' end
        local count=0;for _,seq in pairs(self.sequences) do if seq.scope==scope and not seq.done then count=count+1 end end
        if count>=32 then return nil,'sequence_limit' end
        local frozen={}
        for i,step in ipairs(steps) do
            if type(step)~='table' then return nil,'invalid_sequence' end
            local row={};for k,v in pairs(step) do row[k]=v end
            if type(row.keys)=='table' then row.keys=copy(row.keys) end
            if row.targetKind~='object' and row.target then row.target=copy(row.target) end
            frozen[i]=row
        end
        self.serial=self.serial+1;local seq={id=self.serial,scope=scope,steps=frozen,index=0,ids={},generation=input.Generation}
        self.sequences[seq.id]=seq;self:Advance(seq);return seq.id
    end
    function api:Advance(seq)
        if seq.done then return end
        if seq.generation~=input.Generation then self:CancelSequence(seq.scope,seq.id,'interrupted');return end
        local prior=seq.ids[seq.index];local a=prior and self.actions[prior]
        if a and (a.cancelled or a.record.state=='aborted' or a.record.submissionFailed) then self:CancelSequence(seq.scope,seq.id,'dependency_failed');return end
        if a and not a.record.sentAt then return end
        if seq.index==#seq.steps then
            seq.done=true;for _,id in ipairs(seq.ids) do if self.actions[id] then self.actions[id].sequence=nil end end
            return
        end
        local step=seq.steps[seq.index+1];local q={};for k,v in pairs(step) do q[k]=v end
        q.dependency=prior or q.dependency
        local id,why=self:Request(seq.scope,q)
        if not id then self:CancelSequence(seq.scope,seq.id,why);return end
        seq.index=seq.index+1;seq.ids[seq.index]=id;self.actions[id].sequence=seq.id
    end
    function api:GetSequence(scope,id)
        local seq=self.sequences[id];if not seq or seq.scope~=scope then return nil,'unknown_sequence' end
        return {id=id,actions=copy(seq.ids),done=seq.done==true,cancelled=seq.cancelled==true,reason=seq.reason}
    end
    function api:CancelSequence(scope,id,why)
        local seq=self.sequences[id];if not seq or seq.scope~=scope then return false,'unknown_sequence' end
        seq.done=true;seq.cancelled=true;seq.reason=why or 'cancelled'
        for _,aid in ipairs(seq.ids) do self:Cancel(scope,aid,seq.reason);if self.actions[aid] then self.actions[aid].sequence=nil end end
        return true
    end
    function api:Tick(minimum)
        -- With no admitted or historical work, there is nothing to prune,
        -- release, advance or dispatch. Keep this path independent of owner
        -- names and modes; the next Request resumes the ordinary lifecycle.
        if not next(self.actions) and not next(self.sequences) and #self.queue==0 then return end
        for _,a in pairs(self.actions) do
            if a.releaseDeadline and (not input.KeyLeases or input.KeyLeases[a.record.keys[1]]~=a.record.keyLease
                or clock()>=a.releaseDeadline) then
                input:ReleaseKey(a.record.keys[1],a.record.owner,nil,a.record.keyLease);a.releaseDeadline=nil
            end
        end
        for _,seq in pairs(self.sequences) do self:Advance(seq) end
        for id,seq in pairs(self.sequences) do if seq.done and id<self.serial-256 then self.sequences[id]=nil end end
        self:Pump(minimum)
    end
    return api
end
