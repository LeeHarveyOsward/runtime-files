return function(g, sdk, active, options)
    local api=assert(sdk.Actions,'Orbama Actions API required')
    assert(api.version==1,'Unsupported Actions contract')
    local capabilities=api:GetCapabilities()
    local scope=assert(api:RegisterScope(options.name,{priorities={'critical','interactive','normal','background'}}))
    -- Only capabilities exposed by this facade, not unrelated raw-scope methods.
    local clientCaps={surviveMovementCommands=capabilities.surviveMovementCommands,
        survivePointerMotion=capabilities.survivePointerMotion,resolveWorldTarget=capabilities.resolveWorldTarget,
        automationClaims=capabilities.automationClaims,automationFunctions=capabilities.automationFunctions,
        actionCleanupState=capabilities.actionCleanupState,aimCandidates=capabilities.aimCandidates,
        aimFallback=capabilities.aimFallback,maxAimCandidates=capabilities.maxAimCandidates,
        retryKeys=capabilities.retryKeys,attackApproach=capabilities.attackApproach,
        keyedMechanicalObservation=capabilities.keyedMechanicalObservation,observations=capabilities.observations,updatePriority=capabilities.updatePriority}
    local A={name='Orbama',scope=scope,capabilities=clientCaps}
    function A:Capabilities() return self.capabilities end
    function A:Now() return api:Now() end
    function A:Submit(intent)
        if not active() then return nil,'inactive_instance' end
        local q={type=intent.type or 'cast',keys=intent.keys,target=intent.target,targetKind=intent.kind,
            owner=intent.owner,priority=intent.priority,expires=intent.expires,intentTargetID=intent.targetID,
            dependency=intent.dependency,dependencyState=intent.dependencyState,ready=intent.ready,handoff=intent.handoff,
            verifyTarget=intent.verifyTarget,aimCandidates=intent.aimCandidates,aimFallback=intent.aimFallback,
            retryKey=intent.retryKey,world=intent.world,count=intent.count,approach=intent.approach,
            survivePointerMotion=intent.survivePointerMotion,
            validate=function(_,resolved)if not active() then return false,'inactive_instance' end;return intent.mechanical(resolved) end}
        -- An independent resolved skillshot keeps its gameplay target while the
        -- player orbwalks. Opt into the provider's bounded correction centrally;
        -- explicit false, dependent sequences and manual point casts stay strict.
        if q.survivePointerMotion==nil and capabilities.survivePointerMotion
            and intent.independent and intent.resolve and intent.kind=='world'
            and q.type=='cast' and not intent.dependency and not intent.handoff then
            q.survivePointerMotion=true
        end
        if intent.resolve and capabilities.resolveWorldTarget then q.resolveWorldTarget=intent.resolve end
        if intent.independent and capabilities.surviveMovementCommands and q.type=='cast'
            and intent.kind~='screen' and not intent.dependency and not intent.handoff then
            q.surviveMovementCommands=true
        end
        if intent.resolve and not capabilities.resolveWorldTarget then return nil,'resolveWorldTarget_unavailable' end
        return scope:Request(q)
    end
    function A:Poll(id) return scope:GetAction(id) end
    function A:UpdatePriority(id,priority)
        if not capabilities.updatePriority then return false,'priority_update_unavailable' end
        return scope:UpdatePriority(id,priority)
    end
    function A:Cancel(id,why) return scope:Cancel(id,why) end
    function A:Acknowledge() return true end
    function A:Available() local a=api:GetAvailability();return not a.busy and not a.cleanupPending and not a.uncertain end
    function A:Settled(id)
        local r=self:Poll(id)
        if capabilities.actionCleanupState and r and r.cleanupPending~=nil then
            return r.releasedAt~=nil and not r.cleanupPending and not api:GetAvailability().uncertain
        end
        return self:Available()
    end
    function A:Tick() end -- SDK owns its scheduler.
    function A:Claim(name,on)
        if not capabilities.automationClaims then return false,'automation_claims_unavailable' end
        if on then return scope:ClaimAutomation(name) end
        return scope:ReleaseAutomation(name)
    end
    function A:Observe(id,evidence) return scope:Observe(id,evidence) end
    function A:Close(why) return scope:Close(why) end
    return A
end
