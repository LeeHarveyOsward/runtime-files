-- LHO gameplay adapter for Orbama Actions v1. No cursor internals are written.
local U=require('lho.util')
local Intent=require('lho.intent')
return function(a)
    local c=a.ctx;local api=c.sdk.Actions
    if not api and c.originalGG then api=require('lho.ggbridge')(c) end
    if not api or api.version~=1 then return end -- Retained GG fixture compatibility.
    a.api=api;a.scope=assert(api:RegisterScope('LHO',{priorities={'critical','interactive','normal','background'}}))
    -- Provider capabilities are immutable for this controller lifetime. Avoid
    -- allocating a fresh capabilities table for every validation/dispatch.
    a.capabilities=api:GetCapabilities()
    a.originalGG=api.provider=='OriginalGG'
    a.owners={};a.keyRequests={};a.dependencies={};a.intentRequests={}
    function a:syncAutomation()
        if not self.capabilities.automationClaims or not self.scope.ClaimAutomation then return end
        -- LHO implements item QSS, not summoner Cleanse. Claim only that actual
        -- enabled service; Close releases the claim on unload/error.
        local enabled=c.config:get('enabled') and c.config:get('items') and c.config:get('idleDefense') and c.config:get('itemCleanse')
        if not enabled then
            if self.qssClaim then self.scope:ReleaseAutomation('qss') end
            self.qssClaim=nil;self.qssRetry=nil;return
        end
        if self.qssClaim or self.qssRetry and self.api:Now()<self.qssRetry then return end
        self.qssClaim=self.scope:ClaimAutomation('qss')==true
        self.qssRetry=not self.qssClaim and self.api:Now()+500 or nil
    end
    function a:inputAction(id) return id and self.scope:GetAction(id) end
    function a:inputNow() return self.api:Now() end
    function a:syncWindow(window)
        if not window or not window.event or not window.event.cursorID then return 'ready' end
        local r=self:inputAction(window.event.cursorID)
        if not r or r.jobCancelled or r.state=='cancelled_before_send' then return 'cancelled' end
        if not r.sentAt then return 'waiting' end
        if not window.sendTimeApplied then
            local sent=c:now()-math.max(0,self.api:Now()-r.sentAt)*.001
            window.deadline=window.deadline+math.max(0,sent-window.event.at)
            window.startedAt=sent;window.sendTimeApplied=true
        end
        return r.state=='send_uncertain' and 'uncertain' or 'ready'
    end
    function a:cursorBusy() local s=self.api:GetAvailability();return s.busy or s.uncertain end
    function a:cursorWaitReason()
        local s=self.api:GetAvailability()
        return s.pendingReturn and 'Checking cursor return' or s.uncertain and 'Waiting for input' or 'Automatic input in progress'
    end
    function a:hasCursorQueue() return true end
    function a:request(q)
        local id,why=self.scope:Request(q)
        if not id then return false,why end
        self.lastCursorAction=id;self.owners[q.owner]=id
        local r=self:inputAction(id)
        if not r then return false,'Action record unavailable' end
        return r.state~='cancelled_before_send',r.reason or r.state,{cursorID=id,keyTick=r.sentAt,
            keyAt=r.sentAt and c:now()-math.max(0,self.api:Now()-r.sentAt)*.001}
    end
    function a:dispatchCursor(key,target,owner,chain,leftClicks,verifyTarget,validate,worldIntent,execution)
        owner=owner or 'default'
        -- Owner history is diagnostic only. Dependencies belong to a concrete
        -- gameplay sequence, never to independent retries such as Autosmite.
        local previous=chain and self.dependencies[owner]
        local prior=previous and self:inputAction(previous)
        if not prior or prior.jobCancelled or prior.state=='cancelled_before_send' then previous=nil end
        local kind=not target and 'none' or target.pos and 'object' or target.z~=nil and 'world' or 'screen'
        local actionType=leftClicks and 'click' or key==(MOUSEEVENTF_RIGHTDOWN or 8) and 'move' or key and 'cast' or 'hover'
        local farmMove=actionType=='move' and owner=='farm' and c.farm
        local moveCamp=farmMove and c.farm.camp
        local moveCombat=farmMove and (c.farm.state=='clearing' or c.farm.state=='finishing')
        local moveStep=moveCombat and c.farm.kiteStep
        local moveKey=moveStep and moveStep.key;local movePhase=moveStep and moveStep.phase
        local intentKey=owner..':'..actionType
        if actionType=='move' or actionType=='hover' then
            local intent=self.intentRequests[intentKey];local action=intent and self:inputAction(intent.id)
            if action and (action.state=='requested' or action.state=='waiting') then
                local same=intent.kind==kind and (kind=='object' and U.same(intent.target,target)
                    or kind=='world' and U.dist(intent.target,target)<5 or kind=='screen' and U.screenDist(intent.target,target)<2)
                if same then self.lastCursorAction=intent.id;return true,'waiting',{cursorID=intent.id} end
                self.scope:Cancel(intent.id,'Movement intent changed before send')
            end
        end
        local priority=execution and execution.priority or (actionType=='hover' and 'background' or Intent.priority(owner))
        local caps=self.capabilities
        local useAim=verifyTarget and kind=='object' and caps.aimCandidates
        local reactiveCast=actionType=='cast' and not previous and kind~='screen'
            and owner~='ward' and owner~='farm' and owner~='secure'
            and (owner~='insec' or c.input:insecMovementHeld())
        if useAim and self.bodyPoint and not U.same(self.bodyPoint.target,verifyTarget) then self.bodyPoint=nil end
        local resolver=execution and execution.resolveWorldTarget
        if resolver and execution.contextValid then
            local resolve=resolver
            resolver=function(...)
                local valid,reason=execution.contextValid();if not valid then return nil,reason end
                return resolve(...)
            end
        end
        local synthetic=c.synthetic;c.synthetic=true
        local ok,why,timing=self:request{type=actionType,targetKind=kind,target=target,keys=key,
            owner=owner,priority=priority,expires=self.api:Now()+500,dependency=previous,handoff=chain==true and previous~=nil,
            count=leftClicks,verifyTarget=not self.originalGG and verifyTarget or nil,world=worldIntent,
            resource=execution and execution.resource,
            resolveWorldTarget=resolver,
            prevalidateWorldCast=resolver and caps.prevalidateWorldCast and not previous and not verifyTarget and true or nil,
            commitGuard=resolver and caps.prevalidateWorldCast and not previous and not verifyTarget and execution.contextValid or nil,
            intentTargetID=execution and execution.intentTargetID,
            survivePointerMotion=reactiveCast
                and caps.survivePointerMotion and true or nil,
            surviveMovementCommands=reactiveCast
                and caps.surviveMovementCommands and true or nil,
            aimCandidates=useAim and function()return require('lho.aim').points(self,verifyTarget,
                (owner=='autosmite' or owner=='secure') and c.config:get('smiteProjectionFallback'))end or nil,
            aimFallback=useAim and caps.aimFallback and (owner=='autosmite' or owner=='secure') and c.config:get('smiteProjectionFallback')
                and function(point)return require('lho.aim').isolated(c,verifyTarget,point)end or nil,
            retryKey=useAim and (tostring(key)..':'..tostring(verifyTarget.networkID)..':'..tostring(verifyTarget.handle)) or nil,
            validate=function()if c:blocked() then return false,'context_blocked' end
                if actionType=='move' and (owner=='cursor' or owner=='ally')
                    and (c.mode~=owner or not c.combat:insecOrbwalkAllowed()) then return false,'insec_movement_superseded' end
                if farmMove then
                    local combat=c.farm.state=='clearing' or c.farm.state=='finishing'
                    local step=c.farm.kiteStep
                    if c.farm.camp~=moveCamp or combat~=moveCombat
                        or moveStep and (not step or step.key~=moveKey or step.phase~=movePhase) then
                        return false,'farm_movement_superseded'
                    end
                end
                if validate then return validate() end;return true end}
        if timing and (actionType=='move' or actionType=='hover') then
            self.intentRequests[intentKey]={id=timing.cursorID,kind=kind,target=kind=='object' and target or U.copy(target)}
        end
        c.synthetic=synthetic;return ok,why,timing
    end
    function a:cancelMoveIntent(owner)
        local intent=self.intentRequests[owner..':move']
        local action=intent and self:inputAction(intent.id)
        if action and not action.sentAt and (action.state=='waiting' or action.state=='requested') then
            self.scope:Cancel(intent.id,'Target attack supersedes pending ground movement')
        end
        self.intentRequests[owner..':move']=nil
    end
    function a:keyAction(keys,owner,kind,validate)
        owner=owner or 'control';kind=kind or 'key'
        local list=type(keys)=='table' and keys or {keys};local signature=owner..':'..kind..':'..table.concat(list,',')
        local id=self.keyRequests[signature];local r=self:inputAction(id)
        if not r then
            local ok,why,timing=self:request{type=kind,targetKind='none',keys=keys,owner=owner,
                priority=owner=='farm' and 'normal' or 'background',expires=self.api:Now()+500,
                validate=function()return not c:blocked() and (not validate or validate()) end}
            if not timing then return false,why,false end
            id=timing.cursorID;self.keyRequests[signature]=id;r=self:inputAction(id)
        end
        if r.state=='waiting' or r.state=='requested' then return false,'waiting',false,id end
        self.keyRequests[signature]=nil
        if r.state=='cancelled_before_send' then return false,r.reason or 'declined',false,id end
        return r.state=='sent',r.state,true,id
    end
    function a:cameraKey(key) return self:keyAction(key,'camera') end
    function a:restoreCameraOnShutdown()
        local lease=self.cameraOwned
        if not lease or not c.config:get('farmRestoreCamera') then return end
        -- The gameplay scope is closed on shutdown. Give this bounded cleanup
        -- its own scope so it survives the unload and cursor stabilization.
        local scope=api:RegisterScope('LHO camera cleanup '..tostring(self.scope.id),{priorities={'interactive'}})
        if not scope then return end
        self.cameraOwned=nil
        local pending={scope=scope,deadline=api:Now()+5000,key=lease.key}
        _G.LHO_CameraCleanup=pending
        local tick
        local function finish(state)
            scope:Close('Camera cleanup '..state)
            for index,fn in ipairs(c.sdk.OnTick) do if fn==tick then c.sdk.OnTick[index]=function()end;break end end
            if _G.LHO_CameraCleanup==pending then _G.LHO_CameraCleanup=nil end
            if c.config.capture then pcall(c.log,c,'camera_shutdown_restore',{state=state}) end
        end
        tick=function()
            if api:Now()>pending.deadline then finish('expired');return end
            if not pending.id then
                if Game.IsChatOpen and Game.IsChatOpen() or Game.IsOnTop and not Game.IsOnTop() then return end
                pending.id=scope:Request{type='key',targetKind='none',keys=lease.key,owner='restore',priority='interactive',
                    expires=pending.deadline,validate=function()
                        return not (Game.IsChatOpen and Game.IsChatOpen()) and not (Game.IsOnTop and not Game.IsOnTop())
                    end}
                if not pending.id then finish('request_declined');return end
            end
            local action=scope:GetAction(pending.id)
            if action and action.sentAt then finish(action.state);return end
            if not action or action.state=='cancelled_before_send' then finish('cancelled');return end
        end
        c.sdk.OnTick[#c.sdk.OnTick+1]=tick;tick()
    end
    function a:attack(target,owner)
        owner=owner or c.mode
        local prior=self:inputAction(self.attackRequest)
        local waiting=prior and (prior.state=='waiting' or prior.state=='requested')
        local ready=c.sdk.Orbwalker:CanAttack() and U.valid(target)
            and U.dist(myHero.pos,target.pos)<=c:attackRange(target)
        if waiting and (not ready or not U.same(self.attackIntentTarget,target) or self.attackIntentOwner~=owner) then
            self.scope:Cancel(self.attackRequest,'Attack intent no longer ready');waiting=false
        end
        -- A cooling-down or out-of-range attack must not reserve this tick and
        -- suppress the move that kites or brings the target back into range.
        if not ready then return false,'attack_not_ready','not_requested' end
        self:cancelMoveIntent(owner)
        if waiting then return true,'waiting','waiting' end
        self.attackIntentTarget=target;self.attackIntentOwner=owner
        local ok,why,timing=self:request{type='attack',targetKind='object',target=target,owner=owner,
            priority=owner=='farm' and 'background' or 'normal',expires=self.api:Now()+150,
            validate=function()return not c:blocked() and not c:recalling() and U.valid(target)
                and U.same(c.attackTarget,target) and c.mode==owner
                and ((owner~='cursor' and owner~='ally') or c.combat:insecOrbwalkAllowed()) end}
        self.attackRequest=timing and timing.cursorID
        local action=self:inputAction(self.attackRequest)
        return ok,why,action and action.state or 'not_requested'
    end
    function a:attackApproach(target,owner,cycle)
        if not self.capabilities.attackApproach then return false,'attack_approach_unavailable' end
        local function valid()
            return not c:blocked() and not c:recalling() and not c:dash() and U.valid(target)
                and U.same(c.attackTarget,target) and c.mode==owner and c.config:get('autoJungle')
                and not c.input.farmPaused and c.sdk.Orbwalker:CanMove() and not c.sdk.Orbwalker:IsAutoAttacking()
        end
        if not valid() then return false,'attack_approach_invalid' end
        local prior=self.approachRequest;local action=prior and self:inputAction(prior.id)
        local distance=U.dist(myHero.pos,target.pos)
        if prior and U.same(prior.target,target) and distance<(prior.distance or distance)-15 then
            prior.distance=distance;prior.progressAt=c:now()
        end
        local stalled=prior and action and action.sentAt and c:now()-(prior.progressAt or c:now())>=.6
            and (c.sdk.Attack.ServerStart or 0)<=(prior.attackStart or 0)
        local rejected=action and action.state=='cancelled_before_send' and not action.sentAt and action.aim and action.aim.exhausted
        if prior and U.same(prior.target,target) and (rejected or stalled) then
            if stalled then require('lho.aim').reject(self,action,target) end
            if not prior.recoveryYielded then
                -- Let independent spells use the released cursor this callback.
                -- Recovery is not another immediate high-frequency aim retry.
                prior.recoveryYielded=true;return false,'attack_approach_recovery_yield'
            end
            -- A nil/wrong host hover must not strand Lee just outside AA range.
            -- Move on verified ground into range; never turn ambiguous aim into
            -- an attack on an arbitrary overlapping monster.
            local goal=U.toward(target.pos,myHero.pos,math.max(70,c:attackRange(target)-35))
            local ground=require('lho.ground');local point=ground.select(c,goal)
            if not point or U.dist(point,target.pos)>=distance-15 then
                -- Search empty ground inside attack range, including when the
                -- camp has already been dragged outside its preferred leash ring.
                local scene=ground.scene(c);local radius=math.max(70,c:attackRange(target)-35)
                local dx,dz=(myHero.pos.x-target.pos.x)/math.max(1,distance),(myHero.pos.z-target.pos.z)/math.max(1,distance)
                for _,angle in ipairs({.55,-.55,1.1,-1.1,1.57,-1.57}) do
                    local p={x=target.pos.x+(dx*math.cos(angle)-dz*math.sin(angle))*radius,y=target.pos.y,
                        z=target.pos.z+(dx*math.sin(angle)+dz*math.cos(angle))*radius}
                    if U.vector(p):To2D().onScreen and not ground.blocker(c,p,scene)
                        and c.terrain:walkLine(myHero.pos,p,myHero.boundingRadius or 35) then point=p;break end
                end
            end
            if point and U.dist(point,target.pos)<U.dist(myHero.pos,target.pos)-15
                and U.dist(myHero.pos,point)>25 and c.terrain:walkLine(myHero.pos,point,myHero.boundingRadius or 35) then
                if not prior.recoveryAt or c:now()-prior.recoveryAt>.35 then
                    local moved=self:move(point,owner)
                    if moved then
                        prior.recoveryAt=c:now()
                        if c.config.capture then c:log('attack_approach_recovery',{target=U.id(target),reason=action.reason,pos=point}) end
                        return true,'recovering attack approach on clear ground'
                    end
                else return true,'waiting for approach recovery' end
            end
        end
        self:cancelMoveIntent(owner)
        if prior and prior.cycle==cycle and U.same(prior.target,target) and action
            and action.state~='cancelled_before_send' then
            if not action.sentAt then return true,'attack approach waiting' end
            local distance=U.dist(myHero.pos,target.pos)
            if distance<(prior.distance or distance)-15 then
                prior.distance=distance;prior.progressAt=c:now()
            end
            -- A delivered click is not proof that the game accepted the order.
            -- Keep a progressing approach; reassert only after a bounded stall.
            if c:now()-(prior.progressAt or c:now())<.6 then return true,'attack approach already issued' end
        end
        if prior and action and not action.sentAt then self.scope:Cancel(prior.id,'Attack approach changed') end
        local ok,why,timing=self:request{type='attack',approach=true,targetKind='object',target=target,
            verifyTarget=target,owner=owner,priority='normal',expires=api:Now()+150,validate=valid,
            retryKey='attack-approach:'..tostring(U.id(target)),
            aimCandidates=function()return require('lho.aim').points(self,target,true)end,
            aimFallback=function(point)return require('lho.aim').isolated(c,target,point)end}
        if timing then
            self.approachRequest={id=timing.cursorID,target=target,cycle=cycle,
                distance=U.dist(myHero.pos,target.pos),progressAt=c:now(),attackStart=c.sdk.Attack.ServerStart}
            if c.config.capture then c:log('kite_attack_approach',{cursorID=timing.cursorID,target=U.id(target),
                separation=U.dist(myHero.pos,target.pos),attackRange=c:attackRange(target),
                attackStart=c.sdk.Attack.ServerStart,cycle=c.sdk.Attack:GetAnimation(),
                cooldownLeft=math.max(0,c.sdk.Attack.ServerStart+c.sdk.Attack:GetAnimation()-c:now())}) end
        end
        return ok,why
    end
    function a:recall()
        return self:keyAction(HK_RECALL or 66,'farm','key',function()
            return c.config:get('autoJungle') and not c.input.farmPaused and not c:recalling()
                and c.farm:recallSafe(true)
        end)
    end
    function a:recallStatus(id,finished)
        local r=self:inputAction(id)
        if finished and r and not r.sentAt then
            self.scope:Cancel(id,'Recall recovery finished');r=self:inputAction(id)
        end
        if r and (r.sentAt or r.state=='cancelled_before_send') then
            for signature,request in pairs(self.keyRequests) do
                if request==id then self.keyRequests[signature]=nil end
            end
        end
        return r
    end
    function a:cancel(owner)
        self.ownerGeneration[owner]=(self.ownerGeneration[owner] or 0)+1
        self.dependencies[owner]=nil
        self.scope:CancelOwner(owner,'LHO owner cancelled')
        for signature in pairs(self.keyRequests) do if signature:sub(1,#owner+1)==owner..':' then self.keyRequests[signature]=nil end end
        for slot,e in pairs(self.pending) do if e.owner==owner then
            local r=self:inputAction(e.cursorID)
            e.gameplayCancelled=true;e.cancelledAt=e.cancelledAt or c:now()
            self:quarantine(slot,e,r)
            -- Owner cancellation ends future intent, not an issued cast's
            -- observation window. Keep that slot until its original bounded
            -- observation completes; a new mode must not resend an in-flight
            -- Q just because delayed spell metadata still reports it ready.
            -- Uncertain sends retain their separate reconciliation contract.
            if not r or not r.sentAt or r.state=='send_uncertain' then
                self.pending[slot]=nil
                if r and not r.sentAt then e.status='cancelled' end
            end
        end end
    end
    function a:releaseMinimap() self.minimapLease=nil end
    function a:sampleCursor() end
    function a:ownsCursorPoint(owner,point)
        local id=self.owners[owner];local s=self.api:GetAvailability()
        return id and s.activeID==id and self:inputAction(id)~=nil
    end
    function a:ownsHoverAim(target,owner)
        local aim=self.hoverAim
        return aim and aim.owner==owner and U.same(aim.target,target)
            and self.api:GetAvailability().activeID==aim.id
    end
    function a:prepareHover(target,owner)
        if type(Game.GetUnderMouseObject)~='function' then return false,'Target verification unavailable' end
        if self:cursorBusy() and not self:ownsHoverAim(target,owner) then return false,'Waiting for input' end
        local point=U.vector(target.pos):To2D();if not point.onScreen then return false,'Target offscreen' end
        local ok,hovered=pcall(Game.GetUnderMouseObject)
        if ok and U.same(hovered,target) then local p=Game.cursorPos();return true,{x=p.x,y=p.y} end
        local aim=self.hoverAim
        if aim and self:ownsHoverAim(target,owner) then return false,'Waiting for hover' end
        local accepted,_,timing=self:dispatchCursor(nil,{x=point.x,y=point.y},owner,false,nil,nil,function()return U.valid(target)end)
        if accepted then self.hoverAim={owner=owner,target=target,point=point,at=c:now(),id=timing.cursorID} end
        return false,'Waiting for hover'
    end
    function a:canChainWard(slot,target,owner,anticipation)
        if self.originalGG then return false end
        return c.config:get('wardFastCursor') and self:wardDependency(slot,target,owner,anticipation)
            and self.owners[owner]~=nil
    end
    function a:canChainInsecKick(slot,target,owner)
        if self.originalGG then return false end
        if slot~=3 or c:dash() or not c:enemyValid(target) or U.dist(myHero.pos,target.pos)>c.profile.rRange
            or c.combat:kickProtected(target) then return false end
        if owner=='insec' and (not c.combat.insec or not c.combat:kickValid(c.combat.insec)) then return false end
        local last=self.history[#self.history]
        local action=last and self:inputAction(last.cursorID)
        return last and not last.gameplayCancelled and last.owner==owner and last.status=='observed'
            and action and not action.jobCancelled
    end
end
