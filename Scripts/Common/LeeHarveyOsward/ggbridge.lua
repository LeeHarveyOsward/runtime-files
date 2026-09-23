-- Local signature adapter, not an SDK replacement. All scheduling is ActionClient's.
return function(c)
    local create=require('ActionClient')
    local client=create(_G,{name='LHO',active=function()return not c.ggClosed end})
    local caps=client:Capabilities()
    caps.resolveBeforeHandoff=true -- Not cursor-phase resolveWorldTarget support.
    local api={version=1,provider='OriginalGG',client=client}
    local scope={id=client.id}
    function api:Now()return client:Now()end
    function api:GetCapabilities()return caps end
    function api:RegisterScope()return scope end
    function api:GetAvailability()
        local available=client:Available()
        return {available=available,busy=not available,uncertain=false,cleanupPending=not available}
    end
    function scope:GetAction(id)
        local r=client:Poll(id);local q=client.jobs[id]
        if r and q then r.expires=q.expires end
        return r
    end
    function scope:Request(q)
        -- No private cursor control, hover verification, handoffs or modifier input.
        if q.type~='cast' and q.type~='attack' and q.type~='move' then return nil,'GG_unsupported_type:'..tostring(q.type)end
        if q.targetKind=='screen' then return nil,'GG_screen_transport_unavailable'end
        for _,name in ipairs({'verifyTarget','handoff','aimCandidates','aimFallback','dependency'})do
            if q[name] then return nil,'GG_unsupported_option:'..name end
        end
        local slot=q.resource and tonumber(q.resource:match('^slot:(%d+)$'))
        local modes={fight={'COMBO'},harass={'HARASS'},clear={'LANECLEAR','JUNGLECLEAR'},gg_last={'LASTHIT'}}
        local origin=require('lho.intent').origin(c,q.owner)
        local names=modes[origin];local context
        if names then
            context={modes={}}
            for _,name in ipairs(names)do context.modes[#context.modes+1]=c.sdk['ORBWALKER_MODE_'..name] end
        end
        return client:Submit{type=q.type,kind=q.targetKind,target=q.target,keys=q.keys,
            owner=q.owner,priority=q.priority,expires=q.expires,targetID=q.intentTargetID,
            resource=q.resource,resolve=q.resolveWorldTarget,context=context,
            mechanical=function(resolved)return not c:blocked() and (not q.validate or q.validate(nil,resolved))end,
            reconcile=function()
                local active=myHero.activeSpell
                return not c:blocked() and (not active or not active.valid)
                    and (slot==nil or c:ready(slot))
            end}
    end
    function scope:Cancel(id,reason)return client:Cancel(id,reason)end
    function scope:CancelOwner(owner,reason)return client:CancelOwner(owner,reason)end
    function scope:Observe(id,evidence)return client:Observe(id,evidence)end
    function scope:Close(reason)c.ggClosed=true;return client:Close(reason)end
    function api:Pump(actions)
        -- Consume only results whose gameplay observation is no longer pending.
        local retained={}
        for _,event in pairs(actions.pending)do if event.cursorID then retained[event.cursorID]=true end end
        for _,lock in pairs(actions.slotUncertainty or {})do
            if lock.event.cursorID then retained[lock.event.cursorID]=true end
        end
        for _,id in pairs(actions.keyRequests)do retained[id]=true end
        for id in pairs(client.jobs)do
            if not retained[id]then
                local r=client:Poll(id)
                if r and (r.mechanical or r.state=='cancelled_before_send')then client:Finish(id)
                else client:Reconcile(id)end
            end
        end
        local previous=c.synthetic;c.synthetic=true
        local ok,why=pcall(client.Tick,client)
        c.synthetic=previous
        if not ok then error(why)end
    end
    return api
end
