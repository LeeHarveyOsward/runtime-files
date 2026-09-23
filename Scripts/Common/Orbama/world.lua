-- Optional world intent resolution. No new deadline or input owner is created.
return function(input, clock)
    local function finite(n) return type(n)=='number' and n==n and math.abs(n)<math.huge end
    local function copy(v, seen, depth)
        if type(v)~='table' then return v end
        seen=seen or {};depth=depth or 0
        if seen[v] or depth>12 then error('cyclic or excessive resolution data') end
        seen[v]=true;local out={}
        for k,x in pairs(v) do
            if type(k)=='string' or type(k)=='number' then
                if type(x)~='function' and type(x)~='userdata' then out[k]=copy(x,seen,depth+1) end
            end
        end
        seen[v]=nil;return out
    end
    function input:ResolutionSnapshot(r) return r.resolution and copy(r.resolution) end
    function input:WorldPlacementConfirmed(r)
        -- GG's cast contract confirms the projected SCREEN coordinate, then
        -- sends in that same call. Game.mousePos can lag the OS cursor. Waiting
        -- for that separate world sample added a callback before every skillshot
        -- and let physical aiming/camera motion repeatedly cancel the cast.
        -- Gameplay validation and the final <=5px screen check still run at send.
        if r.ggCompatible then
            local p=self.env.screen();local aim=r.actionScreen
            local yes=p and aim and finite(p.x) and finite(p.y)
                and (p.x-aim.x)^2+(p.y-aim.y)^2<=25
            if yes then r.screenPlacementConfirmedAt=clock() end
            return yes or false
        end
        -- Only a fresh host world query can eliminate the extra callback. A
        -- cached global mousePos (or screen position alone) is insufficient.
        if type(self.env.liveWorld)~='function' then return false end
        local screen=self.env.screen();local ok,world=pcall(self.env.liveWorld)
        local aim=r.actionScreen;local target=r.world
        if not ok or not world or not target or not screen or not aim then return false end
        if not finite(world.x) or not finite(world.z) or not finite(screen.x) or not finite(screen.y) then return false end
        local confirmed=(screen.x-aim.x)^2+(screen.y-aim.y)^2<=25
            and (world.x-target.x)^2+(world.z-target.z)^2<=75^2
        if confirmed then r.nativePlacementConfirmedAt=clock() end
        return confirmed
    end
    function input:CanCorrectWorldDrift(r,screen)
        -- Small physical motion during a held assist is not cancellation. Keep
        -- the same bounded lease, but never send at the displaced position.
        -- Large movements, clicks and legacy actions retain manual takeover.
        if not r or r.sentAt or not r.survivePointerMotion or not r.resolveWorldTarget
            or not r.awaitingPosition or not self:Available() or self.Uncertain
            or (r.positionPasses or 1)>=3 or clock()+r.hold>=r.budgetEnd
            or clock()>r.expires or r.generation~=self.Generation then return false end
        local aim=r.actionScreen
        if not aim or not screen or not finite(screen.x) or not finite(screen.y)
            or (screen.x-aim.x)^2+(screen.y-aim.y)^2>32^2 then return false end
        -- GG-compatible casts use confirmed screen projection throughout. A
        -- stale asynchronous world sample must not veto a bounded correction of
        -- that same screen contract; strict world mode keeps its native check.
        if r.ggCompatible then return true end
        if type(self.env.liveWorld)~='function' then return false end
        local ok,world=pcall(self.env.liveWorld)
        return ok and world and r.world and finite(world.x) and finite(world.z)
            and (world.x-r.world.x)^2+(world.z-r.world.z)^2<=75^2 or false
    end
    function input:ResolveWorld(r)
        if not r.resolveWorldTarget then return true end
        if r.state=='aborted' or clock()>r.expires or r.generation~=self.Generation or not self:Available() then r.reason='resolution_context_ended';return false end
        if r.resolvedPass==self.ResolutionPass then return r.resolution~=nil and not r.resolutionError end
        r.resolvedPass=self.ResolutionPass;r.resolutionError=nil
        local context={id=r.id,owner=r.owner,requestedAt=r.requestedAt,expires=r.expires,
            targetID=r.intentTargetID,keys=copy(r.keys),position=copy(r.target),
            revision=r.resolution and r.resolution.revision or 0,now=clock()}
        local revision=context.revision+1
        self.Resolving=true
        local ok,value,detail=pcall(r.resolveWorldTarget,context)
        self.Resolving=false
        if ok and value then
            local p=value.position or value
            if finite(p.x) and finite(p.z) and (p.y==nil or finite(p.y)) and not p.pos then
                local copied,data=pcall(copy,value.data)
                if copied then
                    r.resolution={revision=revision,position={x=p.x,y=p.y or 0,z=p.z},data=data,at=clock()}
                    r.target=copy(r.resolution.position);r.world=copy(r.target);return true
                end
            end
        end
        r.resolutionError=true;r.reason=ok and tostring(detail or 'world_resolution_declined') or 'world_resolution_exception'
        return false
    end
    -- A bounded, one-use certificate for this synchronous placement attempt.
    -- It certifies pre-warp gameplay validation, never observed execution.
    function input:PrepareWorldCommit(r)
        r.worldCommit={at=clock(),pass=self.ResolutionPass,revision=r.resolution and r.resolution.revision}
        r.gameplayValidatedAt=clock()
    end
    function input:WorldCommitValid(r)
        local ticket=r.worldCommit;r.worldCommit=nil
        if self.Active~=r or not self:valid(r,true) then return false end
        local function fresh()
            return ticket and ticket.pass==self.ResolutionPass and r.resolution
                and ticket.revision==r.resolution.revision and clock()-ticket.at>=0 and clock()-ticket.at<=20
        end
        if not fresh() then r.reason='world_commit_expired';return false end
        if r.commitGuard then
            local ok,allowed,reason=pcall(r.commitGuard)
            if not ok or not allowed then r.reason=ok and (reason or 'commit_guard_declined') or 'commit_guard_exception';return false end
        end
        -- A guard/host call can synchronously cancel or stall; no gameplay
        -- callback or resolver is allowed to extend the certificate.
        if self.Active~=r or not self:valid(r,true) then return false end
        if not fresh() then r.reason='world_commit_expired';return false end
        r.commitValidatedAt=clock();r.commitCertificate=ticket;return true
    end
    function input:RefreshWorldPlacement(r)
        if not r.resolveWorldTarget then return true end
        if not self:ResolveWorld(r) or not self:valid(r) then self:release(r.reason or 'world_resolution_declined');return false end
        if r.prevalidateWorldCast then self:PrepareWorldCommit(r) end
        if clock()>r.expires then self:release('expired');return false end
        if clock()>=r.budgetEnd-r.hold then
            self.Timing:observePreparation(r,clock(),true)
            self:release('world_position_budget_exhausted');return false
        end
        local proxy=setmetatable({CastPos=r.target,IsTarget=false},{__index=self})
        local ok,p=pcall(self.ProjectCastPosition,proxy)
        local bounds=self.env.resolution and self.env.resolution()
        if not ok or not p or not finite(p.x) or not finite(p.y) or p.onScreen==false
            or bounds and (p.x<0 or p.y<0 or p.x>=bounds.x or p.y>=bounds.y) then
            self:release('world_projection_failed');return false
        end
        local old=r.actionScreen
        local changed=r.pointerCorrectionPending or not old or (old.x-p.x)^2+(old.y-p.y)^2>25
        if changed then
            if (r.positionPasses or 1)>=3 then self:release('world_position_limit');return false end
            r.positionPasses=(r.positionPasses or 1)+1
            r.pointerCorrectionPending=nil
            self.CastPos=r.target;self.correctedCastPos=copy(p);self.ActionScreen=copy(p);r.actionScreen=copy(p)
            if not self:SetPosition(p,'action') then self:release('world_reposition_failed');return false end
            r.confirmAfterPass=self.ResolutionPass;r.awaitingPosition=true
            return self:WorldPlacementConfirmed(r)
        end
        self.CastPos=r.target
        if r.confirmAfterPass==self.ResolutionPass then return self:WorldPlacementConfirmed(r) end
        return true
    end
    input.ResolutionPass=0
end
