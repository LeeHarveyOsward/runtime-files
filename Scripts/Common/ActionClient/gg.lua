-- Only this client's unsubmitted work is scheduled here. No private GG writes.
return function(g,sdk,active,options)
    assert(not sdk.OrbamaVersion,'Original GG required')
    local A={falseIsRejection=options.ggFalseIsRejection~=false,name='OriginalGG',queue={},records={},serial=0,history={},caps={
        surviveMovementCommands=false,resolveWorldTarget=false,automationClaims=false,
        cancelSubmitted=false,observedExecution=false,privateQueue=true,updatePriority=true}}
    sdk.ActionClientGG=sdk.ActionClientGG or {};local providers=sdk.ActionClientGG;providers[#providers+1]=A
    local rank={critical=4,interactive=3,normal=2,background=1}
    local last=g.GetTickCount();local now=last
    function A:Now()
        local value=g.GetTickCount();local delta=value-last
        if delta< -2147483648 then delta=delta+4294967296 end
        last=value;now=now+math.max(0,delta);return now
    end
    function A:Capabilities() return self.caps end
    function A:Available() return not sdk.Cursor or sdk.Cursor.Step==0 end
    function A:Submit(q)
        for _,name in ipairs({'verifyTarget','aimCandidates','aimFallback','retryKey','world','count','approach','handoff','survivePointerMotion'})do
            if q[name]~=nil and q[name]~=false then return nil,'GG_unsupported_option:'..name end
        end
        if q.type~='cast' and q.type~='attack' and q.type~='move' then return nil,'GG_unsupported_type' end
        if q.type=='cast' and #q.keys~=1 then return nil,'GG_chord_unavailable' end
        local count=0;for _,r in pairs(self.records)do if not r.acknowledged then count=count+1 end end
        if not active() or count>=128 then return nil,'inactive_or_unconsumed_results_full' end
        self.serial=self.serial+1;local id=self.serial
        sdk.ActionClientGGOrder=(sdk.ActionClientGGOrder or 0)+1
        self.records[id]={order=sdk.ActionClientGGOrder,provider=self,active=active,id=id,state='waiting',requestedAt=self:Now(),intent=q}
        self.queue[#self.queue+1]=id;return id,'waiting'
    end
    local function snapshot(t)if not t then return nil end;local o={};for k,v in pairs(t)do o[k]=v end;return o end
    function A:Poll(id)
        local r=self.records[id];if not r then return nil end
        return {id=id,state=r.state,priority=r.intent and r.intent.priority or r.priority,requestedAt=r.requestedAt,attemptedAt=r.attemptedAt,
            sentAt=r.sentAt,handedAt=r.sentAt,reason=r.reason,jobCancelled=r.cancelled,
            mechanical=snapshot(r.mechanical),effect=snapshot(r.effect),reconciled=r.reconciled}
    end
    function A:UpdatePriority(id,priority)
        local r=self.records[id]
        if not active() or not r or r.state~='waiting' or r.cancelled or r.attemptedAt or self:Now()>=r.intent.expires then return false,'not_waiting' end
        if not rank[priority] then return false,'invalid_priority' end
        if rank[priority]<rank[r.intent.priority] then return false,'priority_downgrade' end
        r.intent.priority=priority;return true
    end
    function A:Acknowledge(id,reconciled)
        local r=self.records[id];if not r or r.state=='waiting' then return false end
        if r.sentAt and not r.mechanical and not reconciled then return false,'reconciliation_required' end
        if r.acknowledged then return true end
        r.priority=r.intent and r.intent.priority;r.acknowledged=true;r.reconciled=reconciled;r.intent=nil;r.active=nil;r.provider=nil -- release all gameplay closures
        for i=#self.queue,1,-1 do if self.queue[i]==id then table.remove(self.queue,i)end end
        self.history[#self.history+1]=id
        while #self.history>128 do self.records[table.remove(self.history,1)]=nil end
        return true
    end
    function A:Cancel(id,why)
        local r=self.records[id];if not r then return false end
        r.cancelled=true;r.reason=why or 'cancelled'
        if r.sentAt then return true,'already_handed_to_GG' end
        r.state='cancelled_before_send';return true
    end
    function A:Tick()
        for i=#providers,1,-1 do
            local p=providers[i];local live=false;for _,r in pairs(p.records)do if not r.acknowledged then live=true;break end end
            if p.closed and not live then table.remove(providers,i)end
        end
        local now=self:Now();local candidates={}
        for _,provider in ipairs(providers)do
        local self=provider
        for i=#self.queue,1,-1 do
            local id=self.queue[i];local r=self.records[id];local q=r and r.intent
            if not r or r.state~='waiting' then table.remove(self.queue,i)
            else
                if now>=q.expires or not r.active() then self:Cancel(id,'expired_or_inactive')
                else
                    local blocked=false
                    for _,key in ipairs(q.keys or {})do if g.Control.IsKeyDown(key)then blocked=true end end
                    if not blocked then candidates[#candidates+1]=r end
                end
            end
        end
        end
        table.sort(candidates,function(a,b)
            local x,y=a.intent,b.intent
            if rank[x.priority]~=rank[y.priority]then return rank[x.priority]>rank[y.priority]end
            if x.expires~=y.expires then return x.expires<y.expires end
            if a.requestedAt~=b.requestedAt then return a.requestedAt<b.requestedAt end
            return a.order<b.order
        end)
        if not self:Available()then return end
        for _,r in ipairs(candidates)do
            local self=r.provider
            if not self:Available()then return end
            local q=r.intent;local resolved
            local ok,valid,reason=pcall(function()
                if q.resolve then resolved=q.resolve({id=r.id,now=now,expires=q.expires});if not resolved then return false,'resolution_declined' end end
                return q.mechanical(resolved)
            end)
            if not ok or not valid then
                if reason~='dependency_waiting' and reason~='not_ready' then self:Cancel(r.id,reason or 'validation_declined')end
            else
                if not r.active()then self:Cancel(r.id,'inactive');return end
                local target=resolved and resolved.position or q.target
                if q.type~='move' and q.type~='attack' and #q.keys~=1 then self:Cancel(r.id,'GG_chord_unavailable')
                else
                    r.attemptedAt=now;self.sending=true
                    local accepted,result
                    if q.type=='move' then accepted,result=pcall(g.Control.Move,target)
                    elseif q.type=='attack' then accepted,result=pcall(g.Control.Attack,target)
                    else accepted,result=pcall(g.Control.CastSpell,q.keys[1],target)end
                    self.sending=false
                    -- The pinned GG CastSpell/Attack false return is a no-send contract.
                    -- Unknown wrappers must opt out; exceptions/nil/Move(false) remain uncertain.
                    if accepted and result==false and q.type~='move' and self.falseIsRejection then
                        r.state='cancelled_before_send';r.reason='GG_rejected_before_send'
                    else
                        r.sentAt=now;r.state=accepted and result==true and 'sent' or 'send_uncertain'
                        r.reason=accepted and (result==true and 'GG_handoff_accepted' or 'GG_handoff_unknown') or 'GG_handoff_exception'
                    end
                    if r.sentAt then return end
                end
            end
        end
    end
    function A:Claim()return false,'original_GG_has_no_claim_API'end
    function A:Observe(id,evidence)
        local r=self.records[id]
        if not r or not r.sentAt or r.state~='sent' or type(evidence)~='table' or evidence.unique~=true then return false end
        if type(evidence.at)~='number' or evidence.at~=evidence.at or evidence.at<r.sentAt or evidence.at>self:Now() then return false end
        if evidence.kind~='mechanical' and evidence.kind~='effect' then return false end
        r[evidence.kind]={at=evidence.at,source=evidence.source,result=evidence.result};return true
    end
    function A:Close(why)self.closed=true;for id in pairs(self.records)do self:Cancel(id,why)end end
    return A
end
