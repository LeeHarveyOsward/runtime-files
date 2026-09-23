local U=require('lho.util')
local Intent=require('lho.intent')
local A={};A.__index=A
local hoverOffsets={{0,0},{0,-30},{0,-60},{-25,-30},{25,-30}}
local recastNames={'leesinqtwo','leesinwtwo','leesinetwo'}
function A.new(ctx)
    local a=setmetatable({ctx=ctx,pending={},history={},nextCast=0,issuedTick=-1,serial=0},A)
    require('lho.community')(a);require('lho.actionstate')(a);return a
end
function A:inputAction(id) return id and self.ctx.sdk.Input and self.ctx.sdk.Input:GetAction(id) end
function A:inputNow() return self.ctx.sdk.Input.env.clock() end
function A:key(slot)
    if slot<4 then return ({HK_Q,HK_W,HK_E,HK_R})[slot+1] end
    if slot==4 then return HK_SUMMONER_1 elseif slot==5 then return HK_SUMMONER_2 end
    return ({HK_ITEM_1,HK_ITEM_2,HK_ITEM_3,HK_ITEM_4,HK_ITEM_5,HK_ITEM_6,HK_ITEM_7})[slot-5]
end
function A:cursorBusy() return self.minimapLease~=nil or self.ctx.sdk.Cursor and (self.ctx.sdk.Cursor.Step or 0)>0 end
function A:cursorWaitReason()
    local input=self.ctx.sdk.Input
    if input then
        if input.PendingReturn then return 'Checking cursor return' end
        if not input.Active then return 'Input / movement cooldown' end
        return 'Automatic input in progress'
    end
    return 'GG cursor busy'
end
function A:hasCursorQueue()
    local cursor=self.ctx.sdk.Cursor
    return cursor and type(cursor.Add)=='function' and type(cursor.StepPressKey)=='function'
        and type(cursor.StepSetToCastPos)=='function' and type(cursor.StepSetToCursorPos)=='function'
end
function A:dispatchNative(key,target,owner,leftClicks,validate)
    local c=self.ctx;local native=c.sdk.NativeTransport
    if not native or c:blocked() or validate and not validate() then return false,'Native context invalid' end
    local started=GetTickCount and GetTickCount();local at=c:now()
    local synthetic=c.synthetic;c.synthetic=true;c.syntheticMouseUntil=at+.08
    local ok,result,reason=pcall(function()
        if leftClicks then
            for _=1,leftClicks do
                local accepted,why=native:LeftClick(target.x,target.y)
                if not accepted then return false,why end
            end
            return true
        elseif key==(MOUSEEVENTF_RIGHTDOWN or 8) then return native:Move(target.pos or target)
        elseif key then return native:CastSpell(key,target) end
        return false,'Native transport does not reserve hover positions'
    end)
    c.synthetic=synthetic
    if c.config.capture then c:log('native_dispatch',{owner=owner,key=key,target=target and target.pos and U.id(target),
        pos=U.copy(target and (target.pos or target)),submitted=ok and result==true,
        reason=not ok and tostring(result) or reason,beginTick=started,
        returnTick=GetTickCount and GetTickCount(),verification='Host return only; gameplay observation pending'}) end
    return ok and result==true,not ok and tostring(result) or reason,{keyAt=key and at,keyTick=key and started}
end
function A:sampleCursor(reason)
    local span=self.cursorSpan;if not span then return end
    local cursor=self.ctx.sdk.Cursor;local now=GetTickCount and GetTickCount()
    if not now then self.cursorSpan=nil;return end
    local step=cursor and cursor.Step or 0
    if step~=span.lastStep and #span.phases<8 then
        span.phases[#span.phases+1]={step=step,afterMs=now-span.at};span.lastStep=step
    end
    if reason or step==0 or not cursor or cursor.CastPos~=span.castPos then
        self.cursorSpan=nil
        if self.ctx.config.capture then self.ctx:log('cursor_pipeline',{owner=span.owner,key=span.key,id=span.id,
            reason=reason or (step==0 and 'released' or 'replaced externally'),
            heldMs=now-span.at,sequenceHeldMs=now-span.rootAt,phases=span.phases,
            sampling='Callback-observed; transition time has callback uncertainty'}) end
    end
end
function A:dispatchCursor(key,target,owner,chain,leftClicks,verifyTarget,validate,worldIntent)
    local shared=self.ctx.sdk.Input
    if shared and shared.InputVersion then
        local c=self.ctx
        local previous=shared.NextIntent
        local dependency=chain and shared.Active and shared.Active.owner==owner and shared.Active.id
        shared.NextIntent={owner=owner,dependency=dependency,validate=validate or (dependency and function()return not c:blocked()end),
            verifyTarget=verifyTarget,leftClicks=leftClicks,world=worldIntent,
            critical=owner~='farm' or key~=(MOUSEEVENTF_RIGHTDOWN or 8)}
        local synthetic=c.synthetic;c.synthetic=true
        local ok,result=pcall(shared.Add,shared,key or {},target)
        c.synthetic=synthetic;shared.NextIntent=previous
        if ok and result then
            self.lastCursorAction=shared.LastActionID
            c.cursorLease={owner=owner,castPos=shared.CastPos}
            local action=shared:GetAction(shared.LastActionID)
            local sent=action and action.sentAt
            local keyAt=sent and c:now()-math.max(0,shared.env.clock()-sent)*.001
            return true,nil,{keyAt=keyAt,keyTick=sent,cursorID=shared.LastActionID}
        end
        return false,ok and 'Shared input declined' or tostring(result)
    end
    if self.ctx.sdk.NativeTransport then
        return self:dispatchNative(key,worldIntent or verifyTarget or target,owner,leftClicks,validate)
    end
    local c=self.ctx;local cursor=c.sdk.Cursor
    if not self:hasCursorQueue() or not target or not Game.cursorPos then return false,'GG cursor queue unavailable' end
    if self:cursorBusy() and not chain then return false,'GG cursor reservation' end
    local world=target.pos or target.z~=nil and target
    local screen=world and U.vector(world):To2D() or target
    if not screen or not U.finite(screen.x) or not U.finite(screen.y)
        or math.abs(screen.x)>100000 or math.abs(screen.y)>100000 then return false,'Invalid cursor projection' end
    if world and not screen.onScreen then return false,'Target offscreen' end
    local before=chain and (self.minimapLease and self.minimapLease.original or cursor.CursorPos) or Game.cursorPos()
    before=before or Game.cursorPos()
    if not before then return false,'Original cursor unavailable' end
    local original={x=before.x,y=before.y}
    local started=GetTickCount and GetTickCount();local pressed,pressedAt,returned
    local prior=self.cursorSpan
    local synthetic=c.synthetic;c.synthetic=true;c.syntheticMouseUntil=c:now()+.08
    local press=cursor.StepPressKey
    local previousIntent=cursor.NextIntent
    cursor.StepPressKey=function(queue)
            if validate and not validate() then return false end
            local hovered=verifyTarget and Game.GetUnderMouseObject and Game.GetUnderMouseObject()
            if verifyTarget and (not U.valid(verifyTarget) or not U.same(hovered,verifyTarget)) then return false end
            if verifyTarget and verifyTarget.type~=Obj_AI_Hero or key==HK_W and validate then
                queue.ForceTCOUp=true
                if HK_TCO and Control.IsKeyDown(HK_TCO) then Control.KeyUp(HK_TCO) end
            end
            pressed=GetTickCount and GetTickCount()
            pressedAt=c:now()
            return press(queue)
    end
    local ok,result=pcall(function()
        -- Check placement before any key/click. Add then owns the complete GG
        -- response wait and restoration, including an empty key list for UI clicks.
        Control.SetCursorPos(screen.x,screen.y)
        if U.screenDist(Game.cursorPos(),screen)>6 then return false end
        if cursor.AdaptiveVersion then
            cursor.NextIntent={owner=owner,chain=not not chain,original=original,originalWorld=U.copy(c.aim),
                world=U.copy(worldIntent),critical=owner=='insec' or owner=='ward' or owner=='autosmite'
                    or owner=='secure' or owner=='defense' or key==HK_W or key==HK_R}
        end
        local issued=cursor:Add(key or {},target)
        if cursor.CastPos~=target then return false end
        if chain then self.minimapLease=nil end -- The new GG sequence now owns restoration.
        cursor.CursorPos=original;c.cursorLease={castPos=target,owner=owner}
        if issued and leftClicks then
            for _=1,leftClicks do
                local pressed,reason=pcall(Control.mouse_event,2)
                local released=pcall(Control.mouse_event,4)
                if not pressed or not released then error(reason or 'Left-click release failed') end
            end
        end
        return issued
    end)
    returned=GetTickCount and GetTickCount()
    cursor.StepPressKey=press
    if cursor.AdaptiveVersion then cursor.NextIntent=previousIntent end
    c.synthetic=synthetic
    if (not ok or not result) and (cursor.Step or 0)==0 and U.screenDist(Game.cursorPos(),screen)<=6 then
        pcall(Control.SetCursorPos,original.x,original.y)
    end
    if ok and result==true and started then
        self:sampleCursor(chain and 'chained' or 'replaced by plugin')
        self.cursorSerial=(self.cursorSerial or 0)+1
        self.cursorSpan={id=self.cursorSerial,owner=owner,key=key,at=started,
            rootAt=chain and prior and prior.rootAt or started,castPos=target,lastStep=cursor.Step,
            phases={{step=cursor.Step,afterMs=returned-started}}}
    end
    if c.config.capture then c:log('cursor_dispatch',{owner=owner,key=key,original=original,requested=U.copy(screen),
        corrected=U.copy(cursor.correctedCastPos),observed=U.copy(Game.cursorPos()),step=cursor.Step,
        accepted=ok and result==true,chain=not not chain,leftClicks=leftClicks,
        verifiedTarget=verifyTarget and U.id(verifyTarget),cursorID=self.cursorSpan and self.cursorSpan.id,
        beginTick=started,keyTick=pressed,returnTick=returned,
        keyDelayMs=pressed and started and pressed-started,dispatchMs=returned and started and returned-started,
        ggResponseWaitMs=returned and cursor.Timer and math.max(0,cursor.Timer-returned)}) end
    return ok and result==true,not ok and tostring(result) or 'GG cursor dispatch declined',
        {keyAt=key and pressedAt,keyTick=key and pressed,cursorID=self.cursorSpan and self.cursorSpan.id}
end
function A:ownsHoverAim(target,owner)
    local aim=self.hoverAim;local cursor=self.ctx.sdk.Cursor;local lease=self.ctx.cursorLease
    return aim and U.same(target,aim.target) and aim.owner==owner and cursor and cursor.Step>0
        and cursor.Step<=2 and lease and lease.owner==owner and lease.castPos==aim.point
        and cursor.CastPos==aim.point and self.ctx:now()-aim.at<.25
        and U.screenDist(Game.cursorPos(),aim.point)<=6
end
function A:prepareHover(target,owner,preempt)
    local c=self.ctx;local now=c:now()
    if not self:hasCursorQueue() or type(Game.GetUnderMouseObject)~='function' then
        return false,'Target verification API unavailable'
    end
    -- Already hovering the exact object needs no synthetic aim/one-frame wait.
    -- dispatchCursor checks the object again at GG's actual keypress.
    if not self:cursorBusy() or preempt then
        local ok,hovered=pcall(Game.GetUnderMouseObject)
        local point=Game.cursorPos and Game.cursorPos()
        if ok and U.same(hovered,target) and U.valid(target) and point then
            return true,{x=point.x,y=point.y}
        end
    end
    local owned=self:ownsHoverAim(target,owner);local aim=self.hoverAim
    if owned then
        local ok,hovered=pcall(Game.GetUnderMouseObject)
        if now>aim.at and ok and U.same(hovered,target) then return true,aim.point end
        if now-aim.at<.03 then return false,'Waiting for game hover observation' end
        if c.config.capture then c:trace('smite_hover_blocked',{target=U.id(target),hovered=ok and U.id(hovered),
            name=ok and hovered and hovered.charName,point=aim.point},tostring(U.id(target)),.5) end
    elseif self:cursorBusy() and not preempt then return false,'GG cursor reservation' end
    local screen=U.vector(target.pos):To2D()
    if not screen.onScreen then return false,'Target offscreen' end
    -- Probe only on separate game frames. Alternative body points are never
    -- trusted on coordinates alone; the native hovered network ID must match.
    local index=owned and aim.index%#hoverOffsets+1 or 1
    local size=Game.Resolution and Game.Resolution();local scale=size and size.y/1440 or 1
    local point={x=screen.x+hoverOffsets[index][1]*scale,y=screen.y+hoverOffsets[index][2]*scale}
    local ok=self:dispatchCursor(nil,point,owner,owned or preempt)
    if ok then
        self.hoverAim={target=target,owner=owner,point=point,at=now,index=index}
        -- Some runtimes refresh hover during SetCursorPos. Use that confirmed
        -- observation immediately; otherwise the fast callback finishes aiming.
        local observed,hovered=pcall(Game.GetUnderMouseObject)
        if observed and U.same(hovered,target) and U.valid(target) and U.screenDist(Game.cursorPos(),point)<=6 then return true,point end
    end
    return false,'Aiming; no Smite key issued'
end
function A:releaseMinimap(force,manual)
    if self.ctx.sdk.Input then self.minimapLease=nil;return end
    local lease=self.minimapLease;local c=self.ctx
    if not lease or not force and c:now()<lease.restoreAt then return end
    self.minimapLease=nil
    local cursor=c.sdk.Cursor
    if not manual and (not cursor or (cursor.Step or 0)==0) and Game.cursorPos
        and U.screenDist(Game.cursorPos(),lease.point)<=6 then
        local synthetic=c.synthetic;c.synthetic=true;c.syntheticMouseUntil=c:now()+.08
        pcall(Control.SetCursorPos,lease.original.x,lease.original.y)
        c.synthetic=synthetic
    end
end
function A:wardDependency(slot,target,owner,anticipation)
    local c=self.ctx;local ward=c.wards and c.wards.pending
    local early=anticipation and ward==anticipation and ward.state=='placing' and not ward.earlyTried
        and target and not target.pos and U.dist(target,ward.pos)<1
    local event=ward and (early and ward.event or ward.placementEvent)
    return slot==1 and ward and (early or ward.state=='waiting_w' and ward.observed and U.same(ward.target,target))
        and event and not event.cancelled and event.owner==owner and ward.owner==owner
        and c.profile.wards[event.before.item]
end
function A:canChainWard(slot,target,owner,anticipation)
    local c=self.ctx;local cursor=c.sdk.Cursor;local lease=c.cursorLease;local ward=c.wards and c.wards.pending
    local event=ward and (anticipation and ward.event or ward.placementEvent)
    -- The repository GG Cursor:Add issues the key synchronously; Steps 1-3
    -- wait/restore its cursor afterwards. Only our own placement sequence can
    -- be replaced by its early W test or its confirmed ward follow-up.
    return c.config:get('wardFastCursor') and slot==1 and cursor and cursor.Step>=1 and cursor.Step<=3
        and type(cursor.Add)=='function' and type(cursor.StepPressKey)=='function'
        and type(cursor.StepSetToCastPos)=='function' and type(cursor.StepSetToCursorPos)=='function'
        and lease and lease.owner==owner and cursor.CastPos==lease.castPos and cursor.CursorPos
        and self:wardDependency(slot,target,owner,anticipation)
        and cursor.Keys and #cursor.Keys==1 and (cursor.Keys[1]==self:key(event.slot)
            or not anticipation and ward.earlyEvent and cursor.Keys[1]==HK_W)
        and U.vector(target.pos or target):To2D().onScreen
end
function A:canChainInsecKick(slot,target,owner)
    local c=self.ctx;local cursor=c.sdk.Cursor;local lease=c.cursorLease;local i=c.combat and c.combat.insec
    if slot~=3 or (owner~='insec' and owner~='fight' and owner~='killsteal') or c:dash()
        or not cursor or cursor.Step<1 or cursor.Step>3 or not lease or lease.owner~=owner
        or cursor.CastPos~=lease.castPos then return false end
    if owner=='insec' then
        if not i or not U.same(i.target,target) or not c.combat:kickValid(i) then return false end
    elseif not c:enemyValid(target) or U.dist(myHero.pos,target.pos)>c.profile.rRange or c.combat:kickProtected(target) then return false end
    local previous=self.history[#self.history]
    return previous and previous.owner==owner and not previous.cancelled
        and (previous.status=='observed' or previous.status=='completed')
        and (previous.slot==1 and previous.stage==1 or previous.slot==0 and previous.stage==2
            or previous.slot>=4 and previous.slot<=5 and U.name(previous.name)=='summonerflash')
end
local function directionError(origin,intended,observed)
    if not origin or not intended or not observed or not origin.z or not intended.z or not observed.z then return end
    local ax,az=intended.x-origin.x,intended.z-origin.z
    local bx,bz=observed.x-origin.x,observed.z-origin.z
    local length=math.sqrt((ax*ax+az*az)*(bx*bx+bz*bz))
    if length>1 then return math.deg(math.acos(U.clamp((ax*bx+az*bz)/length,-1,1))) end
end
function A:observeQAim()
    local c=self.ctx;local now=c:now();local active=myHero.activeSpell
    local candidates={}
    for n=#self.history,math.max(1,#self.history-15),-1 do
        local e=self.history[n]
        if e.aimIntent and not e.aimReported then
            local r=self.api and self:inputAction(e.cursorID)
            local sentAt=r and r.sentAt and now-math.max(0,self:inputNow()-r.sentAt)/1000 or not self.api and e.keyAt
            if not sentAt then
                if e.cancelled or r and r.state=='cancelled_before_send' or now-e.at>1 then
                    e.aimReported=true
                    if c.config.capture then c:log('q_aim_not_sent',{request=e.id,cursorID=e.cursorID,
                        reason=r and r.reason or e.status or 'No send evidence'}) end
                end
            elseif now-sentAt>1 then
                e.aimReported=true;if c.config.capture then c:log('q_aim_unknown',{request=e.id,cursorID=e.cursorID,
                    reason='No matching native placement observed within one second; no timing learning'}) end
            elseif active and active.valid and active.name==e.name and active.placementPos and active.startTime
                and active.startTime>=sentAt-.02 and active.startTime<=now+.1 then
                candidates[#candidates+1]=e
            end
        end
    end
    for _,e in ipairs(candidates) do
        e.aimReported=true
        local input=c.sdk.Input;local action=input and e.cursorID and input:GetAction(e.cursorID)
        if c.config.capture then c:log('q_aim_observed',{request=e.id,cursorID=e.cursorID,inputSession=action and action.inputSession,
            requested=e.aimIntent,origin=e.aimOrigin,playerWorld=action and action.playerWorld,
            observed=U.copy(active.placementPos),nativeStart=active.startTime,
            desiredErrorDegrees=directionError(e.aimOrigin,e.aimIntent,active.placementPos),
            playerErrorDegrees=directionError(e.aimOrigin,action and action.playerWorld,active.placementPos),
            sentAt=action and action.sentAt,releasedAt=action and action.releasedAt,
            interrupted=action and action.interrupted,competitor=action and action.competitor,
            attribution=#candidates==1 and action and not action.interrupted and not action.competitor
                and 'Single matching script request; source not independently proven' or 'Ambiguous or interrupted request',
            evidence='Native placement direction only; no hit confirmation or timing learning'}) end
    end
end
function A:tick()
    local c=self.ctx;local now=c:now()
    if self.originalGG then self.api:Pump(self) end
    if self.api then self:refreshUncertainty();self:syncAutomation() end
    if c.config.capture then self:observeQAim() end
    self:sampleCursor()
    self:releaseMinimap()
    local move=self.routeObservation
    if move then
        local action=self:inputAction(move.cursorID)
        local pending=action and not action.sentAt and action.state~='aborted' and action.state~='cancelled_before_send'
        local declined=action and not action.sentAt and (action.state=='aborted' or action.state=='cancelled_before_send')
        if action and action.sentAt and not move.sendObserved then
            move.sendObserved=true;move.at=now-math.max(0,self:inputNow()-action.sentAt)/1000
        end
        if declined then
            if c.config.capture then c:log('route_input_aborted',{cursorID=move.cursorID,reason=action.reason,destination=move.destination}) end
            self.routeObservation=nil;self.routeCommand=nil
        elseif pending then
            -- An accepted cursor request has not yet sent a game movement command.
        elseif not c.config:get('autoJungle') then self.routeObservation=nil
        elseif action and (action.interrupted or action.competitor) then
            -- A interrupted input has no uniquely attributable endpoint. Manual
            -- clicks already pause farming through the input handler. Replan
            -- from fresh state after the player interval, never replay this ID.
            if c.config.capture then c:log('route_input_uncertain',{cursorID=move.cursorID,reason=action.reason,
                destination=move.destination,observedDestination=myHero.pathing and U.copy(myHero.pathing.endPos),
                interrupted=action.interrupted,competitor=action.competitor}) end
            self.routeObservation=nil
            -- Keep the ordinary acknowledgement interval for this destination.
            -- Discarding the command here caused a new warp every ~180 ms.
            if self.routeCommand then self.routeCommand.uncertain=true end
            self.nextMove=math.max(self.nextMove or 0,now+.12)
        elseif c:dash() or c:recalling() or c.farm.state=='clearing' or c.farm.state=='finishing' then
            self.routeObservation=nil -- Combat, dash and recall supersede travel.
        elseif myHero.pathing and myHero.pathing.hasMovePath and myHero.pathing.endPos
            and now-move.at>.2 and U.dist(myHero.pathing.endPos,move.sent or move.destination)>250 then
            if c.config.capture then c:log('route_endpoint_mismatch',{destination=move.destination,dispatchedDestination=move.sent,
                cursorID=move.cursorID,
                observedDestination=U.copy(myHero.pathing.endPos),transport=move.transport}) end
            self.routeObservation=nil;self.routeCommand=nil
            if move.transport=='minimap' then self.mapFit=nil;self.minimapRejectedUntil=now+10 end
            -- Native path endpoints may stop at attack range, snap to walkable
            -- ground, or be superseded by our own combat order. A mismatch is
            -- failed movement evidence, never evidence of a player's cancel.
            -- Retry from fresh planning without switching off retaliation.
            self.nextMove=math.max(self.nextMove or 0,now+.25)
            c.routeFailureReason=nil
        elseif U.dist(myHero.pos,move.origin)>40 and now-move.at>.2 then
            if c.config.capture then c:log('route_move_observed',{delay=now-move.at,destination=move.destination,cursorID=move.cursorID}) end;self.routeObservation=nil
        elseif now-move.at>1.5 and not move.reported then
            move.reported=true;if c.config.capture then c:log('route_move_unobserved',{destination=move.destination,origin=move.origin,
                hasMovePath=myHero.pathing and myHero.pathing.hasMovePath,endPos=myHero.pathing and U.copy(myHero.pathing.endPos)}) end
        end
    end
    if self.routeStop and not self:cursorBusy() and not c:blocked() and not c:recalling() then
        local ok=self:worldMove(myHero.pos)
        if ok then self.routeStop=nil end
    end
    if self.cameraOwned and not c.config:get('autoJungle') then self:restoreCamera() end
    if not self.api and c.cursorLease and (not self:cursorBusy() or c.sdk.Cursor.CastPos~=c.cursorLease.castPos) then c.cursorLease=nil end
    for slot,event in pairs(self.pending) do
        local r=self:inputAction(event.cursorID)
        if self.api and r and not r.sentAt and r.state~='cancelled_before_send' and event.validate then
            -- A resolving world cast must be checked against its new aim at
            -- dispatch, not rejected here against the old planning position.
            local check=event.resolveWorldTarget and event.contextValid or event.validate
            local ok,valid,why=pcall(check)
            if not ok or not valid then
                self.scope:Cancel(event.cursorID,ok and (why or 'gameplay_condition_changed') or 'validation_exception')
                r=self:inputAction(event.cursorID)
            end
        end
        if self.api and r and r.state=='cancelled_before_send' then
            event.status='cancelled';event.cancelled=true;event.reason=r.reason;self.pending[slot]=nil
            if c.config.capture then c:log('cast_cancelled',{request=event.id,cursorID=event.cursorID,owner=event.owner,slot=slot,reason=r.reason}) end
        elseif not self.api or r and r.sentAt then
        if self.api and not event.sendObserved then
            if event.aimTarget then require('lho.aim').remember(self,r,event.aimTarget) end
            event.sendObserved=true;event.keyTick=r.sentAt;event.keyAt=now-math.max(0,self:inputNow()-r.sentAt)*.001
            event.deadline=event.keyAt+math.max(.4,c.latency*2+c.jitter*3+.2)
            event.status=r.state
            if r.resolution then
                event.aimIntent=U.copy(r.resolution.position)
                event.aimOrigin=U.copy(myHero.pos)
                event.resolution=r.resolution
            end
            if c.config.capture then c:log('cast_sent',{request=event.id,cursorID=event.cursorID,slot=slot,owner=event.owner,
                inputBoundary=self.originalGG and 'GG_public_handoff' or 'Orbama_send',
                requestedAt=r.requestedAt,sentAt=r.sentAt,queue=r.sentAt>=r.requestedAt and (r.sentAt-r.requestedAt)*.001 or nil,
                invalidTiming=r.sentAt<r.requestedAt,timebase='monotonic milliseconds',gameTime=now,state=r.state,
                sendCompletedAt=r.sendCompletedAt,holdUntil=r.holdUntil,releasedAt=r.releasedAt}) end
        end
        local d=c:spell(slot)
        local q2=slot==0 and event.stage==2
        local active=myHero.activeSpell
        local q2Observed=q2 and active and active.valid and U.name(active.name):find('leesinqtwo',1,true)
            and (not active.startTime or active.startTime>=event.at-.1)
        local observed=(d.name and d.name~='' and d.name~=event.before.name) or (d.currentCd or 0)>(event.before.cd or 0)+.05
            or (d.ammo~=nil and event.before.ammo~=nil and d.ammo<event.before.ammo)
            or (d.toggleState~=nil and event.before.toggleState~=nil and d.toggleState~=event.before.toggleState)
        if event.before.item then
            local item=myHero:GetItemData(slot)
            observed=observed or not item or item.itemID~=event.before.item
                or (U.stackCount(item)<event.before.stacks)
                or (item and item.ammo~=nil and event.before.itemAmmo~=nil and item.ammo<event.before.itemAmmo)
        end
        local recastObserved
        if self.api and slot<3 and event.stage==2 then
            local evidence
            recastObserved,evidence=require('lho.recasts').evidence(c,slot,event.recastBefore,event.keyAt)
            event.recastEvidence=evidence;observed=recastObserved and true or false
            if c.config.capture and event.lastRecastReason~=evidence.reason then
                event.lastRecastReason=evidence.reason
                c:log('recast_evidence',{cursorID=event.cursorID,slot=slot,observed=observed,evidence=evidence})
            end
            if q2 then q2Observed=recastObserved end
        end
        if q2Observed then
            c.q2Outcome={at=now,text='Q2 cast observed'}
            if c.config.capture then c:log('q2_cast_observed',{name=event.name,request=event.id,delay=now-event.at}) end
            observed=true
        end
        if observed then
            if (event.wardAnticipation or self.api) and c.clear then c.clear:accepted(slot,event.stage,not self.api) end
            if self.api and c.clear and slot<4 and (event.stage~=2 and (d.currentCd or 0)>(event.before.cd or 0)+.05
                or event.stage==1 and c:stage(slot)==2 or recastObserved) then
                c.clear:executed(slot,event.stage,event.recastEvidence and event.recastEvidence.at or now)
            end
            if self.api then self.scope:Observe(event.cursorID,{kind='mechanical',source='spell_metadata',unique=true,at=self.api:Now()}) end
            if q2 and not q2Observed then c.q2Outcome={at=now,text='Q state changed; Q2 hit unconfirmed'} end
            event.status='observed';event.observedAt=now;self.pending[slot]=nil
            c.metrics.observed=(c.metrics.observed or 0)+1;if c.config.capture then c:log('cast_observed',{name=event.name,request=event.id,delay=now-event.at,
                slot=slot,stage=event.stage,owner=event.owner,target=event.target,encounter=event.encounter,
                insecAttempt=event.insecAttempt,evidence='Spell metadata changed; impact not confirmed'}) end
        elseif self.api and r and r.state=='send_uncertain' then
            self:quarantine(slot,event,r)
        elseif now>event.deadline then
            if event.aimTarget then require('lho.aim').reject(self,r,event.aimTarget) end
            event.status='unconfirmed';self.pending[slot]=nil
            if c.config.capture then c:log('cast_unconfirmed',{name=event.name,request=event.id,slot=slot,owner=event.owner,
                cursorID=event.cursorID,target=event.target,stage=event.stage,before=event.before,
                after={name=d.name,cd=d.currentCd,ammo=d.ammo,toggleState=d.toggleState},
                keyAt=event.keyAt,deadline=event.deadline,recastEvidence=event.recastEvidence,
                input=r and {state=r.state,reason=r.reason,sentAt=r.sentAt,releasedAt=r.releasedAt,
                    interrupted=r.interrupted,uncertain=r.uncertain},
                active=active and {name=active.name,valid=active.valid,startTime=active.startTime},
                evidence='No attributable spell-state change before observation deadline; effect unknown'}) end
            if q2 then c.q2Outcome={at=now,text='Q2 key sent but cast unconfirmed'} end
        end
        end
    end
end
function A:cameraKey(key)
    local c=self.ctx;local input=c.sdk.Input
    if c:blocked() or self:cursorBusy() or input and input.Uncertain then return false,'Input unavailable',false end
    if input then
        local synthetic=c.synthetic;c.synthetic=true
        local previous=input.LastActionID
        local ok,accepted=pcall(input.SendKeys,input,key,'camera')
        c.synthetic=synthetic
        local action=input.LastActionID~=previous and input:GetAction(input.LastActionID)
        return ok and accepted==true,ok and (accepted and 'Host submission only' or 'Key input declined') or tostring(accepted),
            action and action.sentAt~=nil or not ok
    end
    return false,'Owned key input unavailable',false
end
function A:restoreCamera()
    local c=self.ctx;local lease=self.cameraOwned
    if not lease then return false end
    if not c.config:get('farmRestoreCamera') then self.cameraOwned=nil;return false end
    if (Game.IsChatOpen and Game.IsChatOpen()) or (Game.IsOnTop and not Game.IsOnTop()) then return false end
    if c:now()<(self.cameraRestoreAt or 0) then return false end
    local accepted,reason,submitted=self:cameraKey(lease.key)
    if not accepted and not submitted then
        self.cameraRestoreAt=c:now()+.1
        if c.config.capture then c:trace('camera_restore_deferred',{reason=reason},'camera restore',1) end;return false
    end
    self.cameraOwned=nil;self.cameraToggleAt=nil;self.cameraAt=nil;self.cameraRestoreAt=nil
    if c.config.capture then c:log(accepted and 'camera_restored' or 'camera_restore_unknown',{reason=reason,
        evidence='Host submission; camera state unverified. No automatic toggle replay.'}) end;return accepted
end
function A:cast(slot,target,owner,opts)
    opts=opts or {};local c=self.ctx;local now=c:now();local key=self:key(slot)
    local function blocked(reason)
        local previous=self.lastBlock
        local same=previous and previous.owner==owner and previous.slot==slot and previous.reason==reason
            and previous.target==U.id(target)
        self.lastBlock={at=now,owner=owner,slot=slot,reason=reason,target=U.id(target),
            count=same and previous.count+1 or 1,reportAt=same and previous.reportAt or now}
        if same and now<previous.reportAt+.75 then return false end
        self.lastBlock.reportAt=now
        if c.config.capture then c:trace('cast_blocked',{slot=slot,stage=opts.stage,owner=owner,reason=reason,
            target=target and target.pos and U.id(target),pos=U.copy(target and (target.pos or target)),
            count=self.lastBlock.count,cursorStep=c.sdk.Cursor and c.sdk.Cursor.Step,pending=self.pending[slot] and self.pending[slot].id},
            tostring(slot)..':'..tostring(owner)..':'..reason,.75) end
        return false
    end
    -- GG's untargeted CastSpell branch calls CastKey directly and does not
    -- touch Cursor.Step / CastPos / CursorPos. Self-centered spells and recasts
    -- can share a cursor reservation without changing its owner or aim.
    local keyOnly=target==nil and (slot==0 and opts.stage==2 or slot==2 or slot==1 and (opts.stage or c:stage(1))==2)
    local priority=opts.smiteExecute and (owner=='autosmite' or owner=='secure')
        and c.smite and slot==c.smite:resolve() and opts.validate and opts.validate()
    local dependent=(opts.wardFollowup or opts.wardAnticipation) and self:wardDependency(slot,target,owner,opts.wardAnticipation)
    local chain=dependent and self:canChainWard(slot,target,owner,opts.wardAnticipation)
        or opts.verifyHover and self:ownsHoverAim(target,owner)
        or self:canChainInsecKick(slot,target,owner) or priority and self:hasCursorQueue()
    if c:blocked() then return blocked('Disabled / dead / chat / focus') end
    if opts.wardAnticipation and (not dependent or not (self:hasCursorQueue() or c.sdk.NativeTransport) or not opts.validate or not opts.validate()) then
        return blocked('Early W context / GG queue unavailable')
    end
    if c.combat and c.combat.insec and c.combat.insec.preview and owner~='autosmite' then return blocked('Insec preview owns input; no casts') end
    if self:smiteOwnsInput() and not priority then return blocked('Lethal Smite awaiting target verification') end
    if c:recalling() and not priority then return blocked('Recall active') end
    if c.leveling and c.leveling.pending and not priority then return blocked('Skill allocation owns input') end
    if not key then return blocked('No resolved binding') end
    if self.api then self:refreshUncertainty() end
    if self.slotUncertainty[slot] then return blocked('Slot awaiting evidence or physical reactivation') end
    if self.pending[slot] then return blocked('Previous request awaiting acknowledgement') end
    if self:cursorBusy() and not self.api and not chain and not keyOnly then return blocked('GG cursor reservation') end
    if self.issuedTick==now and not dependent and not priority then return blocked('Another cast issued this tick') end
    if not opts.urgent and now<self.nextCast then return blocked('Cast spacing') end
    if opts.wardItem and slot>=6 then
        if not c.wards:itemReady(slot) then return blocked('Ward item not ready') end
    elseif not c:ready(slot) then return blocked('Native cooldown / energy / rank') end
    if slot<4 and not opts.interrupt and c.sdk.Orbwalker:IsAutoAttacking() then return blocked('Attack windup protected') end
    if target and target.pos and not U.valid(target) then return blocked('Target unavailable') end
    if target and not target.pos then target=U.vector(target) end
    local hoverPoint
    if opts.verifyHover and not self.api and not c.sdk.NativeTransport then
        local ready,point=self:prepareHover(target,owner,priority)
        if not ready then
            -- Reserve only a real hover attempt, once per lethal target. A
            -- missing API/offscreen object or failed aim must not freeze play.
            if priority and self:ownsHoverAim(target,owner)
                and (not self.smiteLease or not U.same(self.smiteLease.target,target)) then
                self.smiteLease={target=target,untilTime=now+.12,validate=opts.validate}
            end
            return blocked(point)
        end
        hoverPoint=point;chain=true
    end
    local d=c:spell(slot);local item=slot>=6 and myHero:GetItemData(slot);local stage=slot<3 and (opts.stage or c:stage(slot))
    self.serial=self.serial+1
    c.metrics.requested=(c.metrics.requested or 0)+1
    local intended=opts.intendedTarget or (target and target.pos and target)
    local event={id=self.serial,name=d.name,slot=slot,stage=stage,owner=owner,status='requested',at=now,
        intentMode=Intent.origin(c,owner),
        activation=self.activation[owner] or 0,ownerGeneration=self.ownerGeneration[owner] or 0,
        wardAnticipation=opts.wardAnticipation and true or nil,
        target=U.id(intended),targetName=intended and intended.charName,targetPos=U.copy(intended and intended.pos),
        insecAttempt=owner=='insec' and c.insecTrace or nil,
        deadline=now+math.max(.4,c.latency*2+c.jitter*3+.2),
        before={name=d.name,cd=d.currentCd,ammo=d.ammo,toggleState=d.toggleState,item=item and item.itemID,
            itemAmmo=item and item.ammo,stacks=U.stackCount(item),stackCount=item and item.stackCount}}
    if stage==2 then
        event.recastBefore=require('lho.recasts').snapshot(c,slot)
        event.recastBefore.targetPos=U.copy(intended and intended.pos)
    end
    local requestFields=c.config.capture and {request=event.id,name=d.name,slot=slot,stage=stage,owner=owner,key=key,requestedAt=now,
        target=event.target,targetName=event.targetName,targetPos=event.targetPos,pos=U.copy(target and (target.pos or target)),
        nativeSlot=c:spellSlot(slot),nativeState=Game.CanUseSpell(c:spellSlot(slot)),energy=myHero.mana,cost=d.mana,
        before=event.before,deadline=event.deadline} or nil
    if c.config.capture and slot==0 and stage==1 and target then
        event.aimIntent=U.copy(target.pos or target);event.aimOrigin=U.copy(myHero.pos)
    end
    -- No input waits for synchronous request-log writes. requestedAt and the
    -- dispatch timestamps preserve causality even though records follow input.
    c.synthetic=true;c.injected[key]={at=now,remaining=2}
    local ok,result
    event.dispatchAt=c:now()
    event.dispatchTick=GetTickCount and GetTickCount() or nil
    if self.api then
        local itemID=item and item.itemID;local identity=target and target.pos and U.id(target)
        local insec=c.combat and c.combat.insec
        event.modeBound=event.intentMode~=nil
        local function contextValid()
            if c:blocked() then return false,'context_blocked' end
            if (self.ownerGeneration[owner] or 0)~=event.ownerGeneration then return false,'owner_cancelled' end
            return Intent.valid(c,event.intentMode)
        end
        local function checkLegal()
            local valid,reason=contextValid();if not valid then return false,reason end
            if c.combat and c.combat.insec and c.combat.insec.preview and owner~='autosmite' then return false,'preview_active' end
            if c.leveling and c.leveling.pending and not priority then return false,'leveling_active' end
            if owner=='fight' and c:combatTransit() then return false,'engage_in_flight' end
            if slot<4 and not c:abilityEnabled(slot,stage,owner,intended,opts.abilityPolicy) then return false,'disabled_for_mode' end
            if c:recalling() and not priority then return false,'recall_active' end
            if target and target.pos and (not U.valid(target) or U.id(target)~=identity) then return false,'target_changed_or_unavailable' end
            if slot<3 and stage and c:stage(slot,intended)~=stage then return false,'spell_stage_changed' end
            if not opts.wardItem and not c:ready(slot) then return false,'cooldown_energy_or_rank' end
            if itemID and (myHero:GetItemData(slot) or {}).itemID~=itemID then return false,'item_slot_changed' end
            if opts.wardItem and target and U.dist(myHero.pos,target)>c.wards:range(slot) then return false,'ward_out_of_range' end
            if opts.wardItem and target and c.terrain:wall(target)~=false then return false,'ward_placement_blocked' end
            if slot==1 and stage==1 and target and target.pos and not U.same(target,myHero) and not c.wards:jumpable(target) then return false,'invalid_w_ally_or_range' end
            if opts.validate then local allowed,why=opts.validate();if not allowed then return false,why or 'gameplay_condition_changed' end end
            if slot<4 and not opts.interrupt and c.sdk.Orbwalker:IsAutoAttacking() then return false,'attack_windup' end
            return not c:blocked() and (not target or not target.pos or U.valid(target) and U.id(target)==identity)
                and (not intended or U.valid(intended))
                and (slot>=3 or not stage or c:stage(slot,intended)==stage)
                and (slot>=4 or opts.interrupt or not c.sdk.Orbwalker:IsAutoAttacking())
                and (not itemID or (myHero:GetItemData(slot) or {}).itemID==itemID)
                and (opts.wardItem and c.wards:itemReady(slot,nil,self.pending[slot]==event) or not opts.wardItem and c:ready(slot))
                and (owner~='insec' or c.combat.insec==insec and insec~=nil
                    and c.input:held(insec.kind=='cursor' and 'cursorKey' or 'allyKey')
                    and (slot~=3 or c.combat:geometry(insec) and c.combat:kickValid(insec)))
                and (slot~=0 or stage~=2 or intended and c:mark(intended)
                    and U.dist(myHero.pos,intended.pos)<=c.profile.q2Range and not c:dash())
                and (slot~=1 or stage~=1 or not target or not target.pos or U.same(target,myHero) or c.wards:jumpable(target))
                and (slot<4 or slot>5 or U.name(d.name)~='summonerflash'
                    or target and U.dist(myHero.pos,target)<=400 and c.terrain:wall(target)~=true
                        and (owner~='insec' or c.combat.planner:flashAllowed(insec)))
                and (slot~=3 or not target or not target.pos or not c:dash()
                    and U.dist(myHero.pos,target.pos)<=c.profile.rRange and not c.combat:kickProtected(target))
        end
        local function legal() return U.withBuffScope(checkLegal) end
        local why,timing
        event.validate=legal;event.contextValid=contextValid
        event.resolveWorldTarget=opts.resolveWorldTarget~=nil
        self.dependencies[owner]=dependent and c.wards.pending and
            (c.wards.pending.placementEvent or c.wards.pending.event).cursorID or nil
        if not dependent and self:canChainInsecKick(slot,target,owner) then
            self.dependencies[owner]=self.history[#self.history].cursorID
        end
        result,why,timing=self:dispatchCursor(key,target,owner,chain,nil,opts.verifyHover and target,legal,nil,
            {priority=Intent.priority(owner,priority),resolveWorldTarget=opts.resolveWorldTarget,resource='slot:'..slot,
                contextValid=contextValid,intentTargetID=event.target});ok=true
        event.reason=why;event.aimTarget=opts.verifyHover and target
        if timing then event.keyAt=timing.keyAt;event.keyTick=timing.keyTick;event.cursorID=timing.cursorID end
    elseif c.sdk.NativeTransport then
        local timing,reason
        result,reason,timing=self:dispatchNative(key,target,owner,nil,opts.validate);ok=true
        if timing then event.keyAt=timing.keyAt;event.keyTick=timing.keyTick end
    elseif target and self:hasCursorQueue() then
        local reason,timing
        result,reason,timing=self:dispatchCursor(key,hoverPoint or target,owner,chain,nil,opts.verifyHover and target,opts.validate);ok=true
        if timing then event.keyAt=timing.keyAt;event.keyTick=timing.keyTick;event.cursorID=timing.cursorID end
        if dependent and chain and ok and result==true then if c.config.capture then c:log('ward_cursor_chained') end end
    elseif c.sdk.Input and not target then
        ok,result=pcall(c.sdk.Input.SendKeys,c.sdk.Input,key,owner)
        local action=c.sdk.Input:GetAction(c.sdk.Input.LastActionID)
        if action and action.sentAt then
            event.keyTick=action.sentAt;event.keyAt=c:now()-math.max(0,self:inputNow()-action.sentAt)*.001
        end
    else ok,result=pcall(Control.CastSpell,key,target) end
    c.synthetic=false
    if requestFields then
        requestFields.keyAt=event.keyAt;requestFields.keyTick=event.keyTick;requestFields.cursorID=event.cursorID
        c:log('cast_requested',requestFields)
    end
    U.invalidateBuffScope()
    if not ok or result~=true then
        event.status='rejected';c.metrics.rejected=(c.metrics.rejected or 0)+1
        return blocked(not ok and tostring(result) or event.reason or 'input_declined')
    end
    c.metrics.accepted=(c.metrics.accepted or 0)+1
    if not self.api and stage and c.clear and not opts.wardAnticipation then c.clear:accepted(slot,stage) end
    if not self.api and not keyOnly and self:cursorBusy() then c.cursorLease={castPos=c.sdk.Cursor.CastPos,owner=owner} end
    event.status='accepted';self.pending[slot]=event;self.issuedTick=now
    if priority then self.smiteLease=nil end
    self.nextCast=now+(opts.delay or ((slot==0 or slot==3) and .25 or .06))
    self.history[#self.history+1]=event;if #self.history>128 then table.remove(self.history,1) end
    if c.telemetry then c.telemetry:safe('action',event,intended) end
    if c.config.capture then c:log('cast_accepted',{name=d.name,slot=slot,stage=stage,owner=owner,request=event.id,
        target=event.target,targetName=event.targetName,encounter=event.encounter,insecAttempt=event.insecAttempt}) end
    return true,event
end
function A:smiteOwnsInput()
    if self.api then return false end -- Dispatcher alone owns positioning and failure retry windows.
    local lease=self.smiteLease
    if not lease then return false end
    if not lease.validate() then self.smiteLease=nil;return false end
    return self.ctx:now()<=lease.untilTime
end
function A:cancel(owner)
    if self.ctx.sdk.Input then self.ctx.sdk.Input:Cancel(owner,'LHO owner cancelled') end
    for _,event in ipairs(self.history) do
        if event.owner==owner and event.status=='accepted' and not event.cancelled then
            event.cancelled=true;event.intentStatus='cancelled';if self.ctx.config.capture then self.ctx:log('cast_cancelled',{request=event.id,slot=event.slot,owner=owner}) end
        end
    end
end
function A:minimap(pos)
    if self.ctx:now()<(self.minimapRejectedUntil or 0) then return end
    local p=U.vector(pos);local size=Game.Resolution and Game.Resolution()
    local ok,map=pcall(function()return p.ToMM and p:ToMM()end)
    if not ok then map=nil end
    local function valid(p)
        return p and size and type(p.x)=='number' and type(p.y)=='number'
            and p.x==p.x and p.y==p.y and p.x>=0 and p.y>=0 and p.x<size.x and p.y<size.y
    end
    map=self:minimapPixels(map,size)
    if not valid(map) then map=self:objectMinimap(pos,size,valid) end
    if not valid(map) then return end
    return {x=map.x,y=map.y}
end
function A:minimapPixels(point,size)
    if not point or not size or type(point.x)~='number' or type(point.y)~='number' then return end
    if point.x>=0 and point.y>=0 and point.x<size.x and point.y<size.y then return {x=point.x,y=point.y} end
    local display=require('lho.display')
    if size.x==display.apiWidth and size.y==display.apiHeight and point.x>=0 and point.y>=0
        and point.x<display.renderWidth and point.y<display.renderHeight then
        return {x=point.x*display.apiWidth/display.renderWidth,y=point.y*display.apiHeight/display.renderHeight}
    end
end
function A:worldMove(destination,owner,chain)
    if self:smiteOwnsInput() then return false,'Lethal Smite awaiting target verification' end
    if self.ctx.sdk.NativeTransport then return self:dispatchNative(MOUSEEVENTF_RIGHTDOWN or 8,U.vector(destination),owner or 'farm') end
    if self:hasCursorQueue() then
        local ground=require('lho.ground');local point,reason=ground.select(self.ctx,destination)
        if not point then return false,reason end
        if self.ctx.config.capture and U.dist(point,destination)>1 then
            self.ctx:trace('ground_click_adjusted',{owner=owner,goal=U.copy(destination),click=U.copy(point)},'ground_click',.25)
        end
        local accepted,why,detail=self:dispatchCursor(MOUSEEVENTF_RIGHTDOWN or 8,U.vector(point),owner or 'farm',chain,nil,nil,function()
            return not ground.blocker(self.ctx,point),'ground_click_occupied'
        end)
        if accepted then detail=detail or {};detail.movementDestination=U.copy(point) end
        return accepted,why,detail
    end
    -- GG's mouse-movement branch clicks without checking SetCursorPos success.
    -- Confirm the screen point before allowing that branch to issue its click.
    if not Control.Move or not Control.SetCursorPos or not Game.cursorPos then return false,'screen cursor API unavailable' end
    local point=U.vector(destination):To2D();local before=Game.cursorPos()
    local original=before and {x=before.x,y=before.y}
    if not point.onScreen or not original then return false,'world destination is offscreen' end
    local c=self.ctx;local synthetic=c.synthetic;c.synthetic=true;c.syntheticMouseUntil=c:now()+.08
    local ok,result=pcall(function()
        Control.SetCursorPos(point.x,point.y)
        if U.screenDist(Game.cursorPos(),point)>6 then return false end
        return Control.Move(U.vector(destination))
    end)
    local cursor=c.sdk.Cursor
    if ok and result and cursor and cursor.Step>0 and cursor.CastPos and U.dist(cursor.CastPos,destination)<1 then
        cursor.CursorPos=original;c.cursorLease={castPos=cursor.CastPos,owner='farm'}
    elseif U.screenDist(Game.cursorPos(),point)<=6 then pcall(Control.SetCursorPos,original.x,original.y) end
    c.synthetic=synthetic
    return ok and result==true,not ok and tostring(result) or 'screen move unconfirmed'
end
function A:objectMinimap(pos,size,valid)
    -- GOS documents object.posMM independently of Vector:ToMM. Calibrate an
    -- affine transform from live map markers, never guessed HUD coordinates.
    if not size then return end
    local c=self.ctx;local fit=self.mapFit
    if not fit or fit.width~=size.x or fit.height~=size.y or c:now()-fit.at>.5 then
        local points={}
        for _,list in ipairs({c.heroes or {},c.turrets or {},c.camps or {}}) do
            for _,o in ipairs(list) do
                local ok,mm=pcall(function()return o.posMM end)
                mm=ok and self:minimapPixels(mm,size) or nil
                if ok and o.pos and valid(mm) and (mm.x~=0 or mm.y~=0) then
                    points[#points+1]={world=U.copy(o.pos),map={x=mm.x,y=mm.y}}
                end
            end
        end
        local a,b,d=points[1],nil,nil;local far,area=0,0
        if a then for _,v in ipairs(points) do local n=U.dist(a.world,v.world);if n>far then b,far=v,n end end end
        local function cross(p,q,r)return (q.x-p.x)*(r.z-p.z)-(q.z-p.z)*(r.x-p.x) end
        if b then for _,v in ipairs(points) do local n=math.abs(cross(a.world,b.world,v.world));if n>area then d,area=v,n end end end
        fit={at=c:now(),width=size.x,height=size.y};self.mapFit=fit
        if not d or area<250000 or U.screenDist(a.map,b.map)<20 or U.screenDist(a.map,d.map)<20 then return end
        local det=cross(a.world,b.world,d.world)
        local function project(p)
            local u=((p.x-a.world.x)*(d.world.z-a.world.z)-(p.z-a.world.z)*(d.world.x-a.world.x))/det
            local v=((b.world.x-a.world.x)*(p.z-a.world.z)-(b.world.z-a.world.z)*(p.x-a.world.x))/det
            return {x=a.map.x+u*(b.map.x-a.map.x)+v*(d.map.x-a.map.x),
                y=a.map.y+u*(b.map.y-a.map.y)+v*(d.map.y-a.map.y)}
        end
        -- Reject collapsed/inconsistent projections; a fourth marker checks the fit.
        if #points<4 or math.abs((b.map.x-a.map.x)*(d.map.y-a.map.y)-(b.map.y-a.map.y)*(d.map.x-a.map.x))<100 then return end
        for _,v in ipairs(points) do if U.screenDist(project(v.world),v.map)>4 then return end end
        fit.project=project;if c.config.capture then c:log('minimap_calibrated',{source='native object.posMM',anchors=#points}) end
    end
    return fit.project and fit.project(pos)
end
function A:clickMinimap(map,destination)
    local c=self.ctx
    if self:cursorBusy() or not Game.cursorPos or not Control.SetCursorPos then return false,'cursor API unavailable' end
    if not Control.mouse_event and not Control.RightClick then return false,'native click API unavailable' end
    if self:hasCursorQueue() then
        local point={x=math.floor(map.x+.5),y=math.floor(map.y+.5)}
        return self:dispatchCursor(MOUSEEVENTF_RIGHTDOWN or 8,point,'farm',false,nil,nil,nil,destination)
    end
    local before=Game.cursorPos();if not before then return false,'cursor position unavailable' end
    local original={x=before.x,y=before.y}
    local point={x=math.floor(map.x+.5),y=math.floor(map.y+.5)}
    local synthetic=c.synthetic;c.synthetic=true;c.syntheticMouseUntil=c:now()+.08
    local cursor=c.sdk.Cursor
    local ok,err=pcall(function()
        Control.SetCursorPos(point.x,point.y)
        if U.screenDist(Game.cursorPos(),point)>6 then error('minimap cursor placement unconfirmed') end
        if Control.mouse_event then
            local pressed,reason=pcall(Control.mouse_event,MOUSEEVENTF_RIGHTDOWN or 8)
            local released=pcall(Control.mouse_event,MOUSEEVENTF_RIGHTUP or 16)
            if not pressed or not released then error(reason or 'right-click release failed') end
        else Control.RightClick(point.x,point.y) end
    end)
    if ok then
        self.minimapLease={point=point,original=original,restoreAt=c:now()+.10}
    elseif not ok and not (cursor and cursor.Step>0) and U.screenDist(Game.cursorPos(),point)<=6 then
        pcall(Control.SetCursorPos,original.x,original.y)
    end
    if c.config.capture then c:log('minimap_click_requested',{point=point,original=original,accepted=ok,
        dispatcher='native deferred',reason=not ok and tostring(err) or nil}) end
    c.synthetic=synthetic
    return ok,not ok and tostring(err) or nil
end
function A:groundWaypoint(destination)
    local c=self.ctx;local distance=U.dist(myHero.pos,destination)
    -- Screen-visible final destinations go straight to native pathfinding.
    -- A conservative terrain cell must not replace a camp with a near-wall stop.
    if U.vector(destination):To2D().onScreen then self.groundJob=nil;return destination end
    for length=math.min(1100,distance),300,-100 do
        local direct=U.toward(myHero.pos,destination,length)
        if U.vector(direct):To2D().onScreen and c.terrain:clearance(direct,35,true) then self.groundJob=nil;return direct end
    end
    if not c.terrain:trusted() then return end
    local job=self.groundJob
    if not job or U.dist(job.goal,destination)>50 or U.dist(job.origin,myHero.pos)>100 then
        job={goal=U.copy(destination),origin=U.copy(myHero.pos)}
        job.work=coroutine.create(function()
            return require('lho.navigation').approach(c.terrain,job.origin,job.goal,math.max(50,distance-300),1400,
                function()coroutine.yield()end,function(p)return U.vector(p):To2D().onScreen end,true)
        end);self.groundJob=job
    end
    if not job.done and job.stepAt~=c:now() then
        job.stepAt=c:now();local ok,path=coroutine.resume(job.work)
        if not ok then self.groundJob=nil;if c.config.capture then c:log('route_ground_failed',{reason=tostring(path)}) end;return end
        if coroutine.status(job.work)=='dead' then job.done=true;job.path=path end
    end
    if job.path then
        -- Skip reached nodes and prefer the furthest visible endpoint. Native
        -- movement supplies the turns; never click Lee's current coordinates.
        for index=#job.path,1,-1 do
            local point=job.path[index]
            if U.dist(myHero.pos,point)>100 and U.vector(point):To2D().onScreen
                and c.terrain:clearance(point,35,true) then return point end
        end
    end
    if job.done then self.groundJob=nil end
end
function A:followCamera()
    local c=self.ctx;local now=c:now()
    if _G.LHO_CameraCleanup then return false end
    if not c.config:get('farmFollowCamera') or not c.config:get('autoJungle') or c:blocked()
        or c:recalling() or c.leveling.pending then return false end
    -- Dash camera easing is not a lock-state change. Discard the pre-dash
    -- reference and wait for a fresh ordinary-walking observation afterwards.
    if c:dash() then
        self.cameraSample=nil;self.cameraLostSamples=0
        self.cameraResumeAt=now+math.max(.2,c.latency+(c.jitter or 0)*2)
        return false
    end
    if now<(self.cameraResumeAt or 0) then self.cameraSample=nil;return false end
    local screen=U.vector(myHero.pos):To2D()
    local sample=self.cameraSample
    if not sample then
        self.cameraSample={world=U.copy(myHero.pos),screen=U.copy(screen),at=now};return false
    end
    -- Infer follow only from sustained actual movement, never from centring.
    -- This is observational evidence, not a native lock-state API.
    local travel=U.dist(myHero.pos,sample.world)
    -- Also reject a dash/teleport that completed between callbacks. Ordinary
    -- running cannot cover this displacement in the measured interval.
    if travel>math.max(1,myHero.ms or 350)*math.max(0,now-sample.at)+80 then
        self.cameraSample={world=U.copy(myHero.pos),screen=U.copy(screen),at=now}
        self.cameraLostSamples=0
        self.cameraResumeAt=now+math.max(.2,c.latency+(c.jitter or 0)*2)
        return false
    end
    if travel<80 then return false end
    local shift=U.screenDist(screen,sample.screen)
    local resolution=Game.Resolution and Game.Resolution()
    local scale=(resolution and resolution.y or 1080)/1080
    local following=travel>=160 and screen.onScreen~=false and sample.screen.onScreen~=false and shift<=12*scale
    -- Reproject the SAME world landmark. Hero displacement alone cannot tell
    -- unlocked camera from follow easing, a map-edge clamp or a dash.
    local landmark=U.vector(sample.world):To2D()
    local cameraShift=U.screenDist(landmark,sample.screen)
    local unlocked=travel>=160 and now-sample.at>=.45 and shift>=30*scale and cameraShift<=5*scale
    if not following and not unlocked then return false end
    self.cameraSample={world=U.copy(myHero.pos),screen=U.copy(screen),at=now}
    if c.config.capture then c:log('camera_follow_observed',{following=following,travel=travel,screenShift=shift,cameraShift=cameraShift}) end
    if following then
        self.cameraLostSamples=0
        self.cameraFollowing=true
        if self.cameraOwned then self.cameraOwned.confirmed=true end
        return false
    end
    -- Observation is never evidence of a physical takeover. Preserve the lease
    -- so EVERY stop path can restore our toggle. Physical Z is handled by Input.
    if self.cameraFollowing then
        return false
    end
    if self.cameraToggleAt or self:cursorBusy() then return false end
    -- Locked cameras can hit map boundaries at base. Do not infer their toggle
    -- state there, and require two independent stationary-camera observations.
    local spawn=c.farm and c.farm:spawn()
    if spawn and U.dist(myHero.pos,spawn)<1400 then self.cameraLostSamples=0;return false end
    self.cameraLostSamples=(self.cameraLostSamples or 0)+1
    if self.cameraLostSamples<2 then return false end
    local key=c.config:key('farmCameraKey')
    if not key or key<=0 then return false end
    local accepted,reason,submitted=self:cameraKey(key)
    if accepted or submitted then
        self.cameraToggleAt=now
        if accepted then self.cameraOwned={key=key,at=now,wasFollowing=false} end
        self.cameraSample={world=U.copy(myHero.pos),screen=U.copy(screen),at=now}
        if c.config.capture then c:log('camera_lock_requested',{key=key,accepted=accepted,reason=reason,
            evidence='Screen displacement while moving; awaiting follow confirmation'}) end
    end
    return accepted
end

function A:move(pos,owner)
    local c=self.ctx;local now=c:now()
    local plannedKite=owner=='farm' and c.farm and c.farm.kiteStep
    local transition=plannedKite and plannedKite.key and (self.lastKiteKey~=plannedKite.key or self.lastKitePhase~=plannedKite.phase)
    self.lastCursorAction=nil
    if self:smiteOwnsInput() then return false,'Lethal Smite awaiting target verification' end
    local ward=c.wards and c.wards.pending;local cursor=c.sdk.Cursor;local lease=c.cursorLease
    local follow=owner=='ward' and ward and ward.state=='jumping' and (c:dash() or c:stage(1)==2)
    local chain=not self.api and follow and cursor and (cursor.Step or 0)>=1 and cursor.Step<=3 and lease and lease.owner==owner
        and cursor.CastPos==lease.castPos and cursor.Keys and #cursor.Keys==1 and cursor.Keys[1]==HK_W
        and cursor.CursorPos and type(cursor.Add)=='function' and type(cursor.StepPressKey)=='function'
        and type(cursor.StepSetToCastPos)=='function' and type(cursor.StepSetToCursorPos)=='function'
    local restore=chain and cursor.CursorPos
    if owner=='farm' and pos and U.dist(myHero.pos,pos)<25 then return false,'destination reached' end
    if not pos or c:blocked() or c:recalling() or (c.leveling and c.leveling.pending)
        or (self:cursorBusy() and not chain) or (now<(self.nextMove or 0) and not follow and not transition) then
        return false,self:cursorBusy() and self:cursorWaitReason() or c.leveling and c.leveling.pending and 'skill allocation pending' or 'input / movement cooldown'
    end
    local orb=c.sdk.Orbwalker
    if orb:IsAutoAttacking() or not orb:CanMove() or orb.MovementEnabled==false or orb.ForceMovement then return false end
    if orb.Menu and orb.Menu.MovementEnabled and not orb.Menu.MovementEnabled:Value() then return false end
    local p=U.vector(pos);c.dispatchMovement=p
    local args={Target=p,Process=true}
    local hooksOK=pcall(function() for _,fn in ipairs(orb.OnMoveCb or {}) do fn(args) end end)
    c.dispatchMovement=nil
    if not hooksOK or not args.Process or not args.Target then return false,'GG movement hook veto' end
    if owner=='farm' and U.dist(pos,args.Target)>80 then return false,'GG hook changed the camp destination' end
    p=U.vector(args.Target)
    local combat=owner=='farm' and c.farm and (c.farm.state=='clearing' or c.farm.state=='finishing')
    local kite=combat and c.farm.kiteStep
    if kite and kite.command and U.dist(kite.command.pos,p)<35 then
        local path=myHero.pathing
        if now-kite.command.at<.6 or path and path.hasMovePath and path.endPos and U.dist(path.endPos,p)<50 then
            return true,'kite command already active'
        end
    end
    local routing=owner=='farm' and not combat and U.dist(myHero.pos,p)>300
    local command=self.routeCommand
    if routing and command and U.dist(command.goal,p)<80 and U.dist(myHero.pos,command.sent)>160 then
        if U.dist(myHero.pos,command.progressPos)>35 then
            command.progressPos=U.copy(myHero.pos);command.progressAt=now
        end
        local path=myHero.pathing
        local following=path and path.hasMovePath and path.endPos and U.dist(path.endPos,command.sent)<150
        -- A new command gets a short acknowledgement window. Thereafter retain
        -- it while movement progresses; bounded retries recover rejected input.
        if now-command.at<.8 or following and now-command.progressAt<1.5
            or not command.uncertain and now-command.progressAt<.6 then
            return true,command.uncertain and 'Observing current route' or 'route already active'
        end
    elseif not routing then self.routeCommand=nil end
    local sent=U.copy(p)
    c.synthetic=true; c.syntheticMouseUntil=now+.08
    local screen=p:To2D()
    local travelMap=not c.sdk.NativeTransport and owner=='farm' and routing and U.dist(myHero.pos,p)>600 and c.config:get('farmMinimap') and self:minimap(p)
    local minimap=not not travelMap or not screen.onScreen
    -- Screen movement retains precise monster coordinates. Minimap pixels are
    -- a fallback for offscreen travel, not a reason to round a visible endpoint.
    local ok,result,moveReason,projection,moveDetail
    if c.sdk.NativeTransport then
        minimap=false
        result,moveReason=self:dispatchNative(MOUSEEVENTF_RIGHTDOWN or 8,p,owner);ok=true
    elseif not minimap then
        c.dispatchMovement=p
        if self:hasCursorQueue() or owner=='farm' then
            result,moveReason,moveDetail=self:worldMove(p,owner,chain);ok=true
            if result and moveDetail and moveDetail.movementDestination then sent=moveDetail.movementDestination end
        elseif Control.Move then
            -- GG Orbwalker:Move checks cursor hold-radius before OnPreMovement.
            -- Its explicit Control.Move API accepts a destination independently
            -- of the physical cursor; preserve every registered movement hook.
            ok,result=pcall(Control.Move,p)
        else ok,result=pcall(orb.Move,orb);result=ok end
        c.dispatchMovement=nil
        -- GG Move has no return value; its own CanMove / menu / hooks decide dispatch.
    else
        local map=travelMap or (owner~='farm' or c.config:get('farmMinimap')) and self:minimap(p)
        projection=map or nil
        if map and owner=='farm' and Control.SetCursorPos and (Control.mouse_event or Control.RightClick) then
            result,moveReason=self:clickMinimap(map,p);ok=true
        elseif map and self.api then
            result,moveReason=self:dispatchCursor(MOUSEEVENTF_RIGHTDOWN or 8,map,owner,false,nil,nil,nil,p);ok=true
        elseif map and c.sdk.Cursor and c.sdk.Cursor.Add then
            ok,result=pcall(c.sdk.Cursor.Add,c.sdk.Cursor,MOUSEEVENTF_RIGHTDOWN or 8,map)
        end
        if not map and owner=='farm' and Control.Move then
            local waypoint=self:groundWaypoint(p)
            if waypoint then
                sent=U.copy(waypoint)
                c.dispatchMovement=U.vector(waypoint);result,moveReason,moveDetail=self:worldMove(c.dispatchMovement);ok=true;c.dispatchMovement=nil
                if result and moveDetail and moveDetail.movementDestination then sent=moveDetail.movementDestination end
                c.status=c.status..' | ground route (native minimap projection unavailable)'
            end
        end
        if not ok or not result then
            local reason=moveReason or (map and 'Minimap input rejected' or 'Native minimap projection unavailable; finding ground route')
            moveReason=reason
            if self.moveFailure~=reason then self.moveFailure=reason;if c.config.capture then c:log('route_move_failed',{reason=reason,destination=U.copy(p),projection=map}) end end
        else self.moveFailure=nil end
    end
    if chain and not c.sdk.Input then
        cursor.CursorPos=restore;c.cursorLease={castPos=cursor.CastPos,owner=owner}
        if not ok or not result then pcall(cursor.StepSetToCursorPos,cursor) end
    end
    c.synthetic=false
    if ok and result then
        if routing then self.routeCommand={goal=U.copy(p),sent=sent,at=now,progressAt=now,progressPos=U.copy(myHero.pos)} end
        if owner=='farm' and (not self.lastRouteGoal or U.dist(self.lastRouteGoal,p)>100) then
            self.lastRouteGoal=U.copy(p)
            if c.config.capture then c:log('route_move_started',{destination=U.copy(p),dispatchedDestination=sent,origin=U.copy(myHero.pos),projection=projection,
                cursorID=self.lastCursorAction,
                transport=c.sdk.NativeTransport and 'native world' or projection and 'minimap' or minimap and 'ground fallback' or 'screen',qRank=c:spell(0).level}) end
        end
        if routing then self.routeObservation={origin=U.copy(myHero.pos),destination=U.copy(p),sent=sent,at=now,
            cursorID=self.lastCursorAction,
            transport=c.sdk.NativeTransport and 'native world' or projection and 'minimap' or minimap and 'ground fallback' or 'screen'} end
        if not self.api and self:cursorBusy() then c.cursorLease={castPos=c.sdk.Cursor.CastPos,owner=owner} end
        if kite then
            kite.command={pos=U.copy(p),at=now}
            self.lastKiteKey=kite.key;self.lastKitePhase=kite.phase
        end
        local action=self.lastCursorAction and c.sdk.Input and c.sdk.Input:GetAction(self.lastCursorAction)
        self.nextMove=now+.12;if c.config.capture then c:log(action and not action.sentAt and 'move_requested' or 'move_dispatched',
            {owner=owner,minimap=minimap,cursorID=self.lastCursorAction}) end;return true
    end
    return false,moveReason or 'GG movement declined'
end
return A
