-- Single Lua cursor/input owner. No raw mouse deltas, input interception or
-- cursor hiding are claimed. Screen-motion reconstruction is observation only.
return function(cursor,env)
    for _,name in ipairs({'screen','world','liveWorld','resolution'}) do
        local read=env[name]
        if read then env[name]=function()
            if cursor.Metrics and cursor.DiagnosticsEnabled~=false then cursor.Metrics.cursorReads=(cursor.Metrics.cursorReads or 0)+1 end
            local ok,value=pcall(read);if ok then return value end
        end end
    end
    local function copy(p)
        if not p then return end
        return {x=p.x,y=p.y,z=p.z}
    end
    local function finite(x) return type(x)=='number' and x==x and math.abs(x)<math.huge end
    local function worldDistance(a,b)
        if not a or not b or not finite(a.x) or not finite(b.x) or not finite(a.z) or not finite(b.z) then return math.huge end
        return math.sqrt((a.x-b.x)^2+(a.z-b.z)^2)
    end
    local function near(a,b)
        return a and b and finite(a.x) and finite(a.y) and finite(b.x) and finite(b.y)
            and (a.x-b.x)^2+(a.y-b.y)^2<=25
    end
    local function screenDistance(a,b)
        if not a or not b or not finite(a.x) or not finite(a.y) or not finite(b.x) or not finite(b.y) then return math.huge end
        return math.sqrt((a.x-b.x)^2+(a.y-b.y)^2)
    end
    local function safe(fn,...) if not fn then return true end local ok,value=pcall(fn,...);return ok and value end
    local project=cursor.StepSetToCastPos
    cursor.env=env;cursor.InputVersion='lua-1';cursor.Generation=0;cursor.Serial=0
    cursor.GGCompatible=env.ggCompatible==true
    cursor.SessionID='lua-input-'..tostring(env.clock())
    cursor.Queue={};cursor.Records={};cursor.Recent={};cursor.Warps={};cursor.KeysOwned={}
    cursor.Buttons={};cursor.TickSerial=0
    cursor.CommandGenerations={};cursor.Physical={};cursor.PendingUp={};cursor.KeyEchoes={};cursor.Sources={};cursor.Step=0;cursor.NotBefore=0
    cursor.Capabilities={independentMotion=false,hideCursor=false,withholdInput=false,clickQueue=false,
        reconstructedMotionAffectsReturn=false}
    cursor.PlayerScreen=copy(env.screen());cursor.PlayerWorld=copy(env.world())
    cursor.Timing=env.timing.new(env.fallback)
    cursor.DiagnosticErrors={rows={},head=1,count=0,lost=0,sequence=0}
    cursor.DetailedDiagnostics=true
    cursor.Metrics={events={},eventHead=1,eventCount=0,lostEvents=0,sequence=0,hostCalls=0,hostDuration=0,hostDurationMax=0,unknown=0,misdirected=0,interruptions=0}
    function cursor:record(kind,action,reason,fields)
        if self.DiagnosticsEnabled==false then return end
        local events=self.Metrics.events;local details=self.DetailedDiagnostics~=false or nil
        local button=action and action.mouseButton and self.Buttons[action.mouseButton]
        self.Metrics.sequence=self.Metrics.sequence+1
        local event={kind=kind,session=self.SessionID,sequence=self.Metrics.sequence,at=env.clock(),id=action and action.id,owner=action and action.owner,
            scope=action and action.publicScope,priorityClass=action and action.priorityClass,actionType=action and action.publicType,
            targetID=action and action.targetID,targetType=action and action.target and action.target.type,
            commandKey=action and action.keys and action.keys[1],
            sendCompletedAt=action and action.sendCompletedAt,holdUntil=action and action.holdUntil,
            mouseButton=action and action.mouseButton,buttonPending=button~=nil,
            buttonRetries=button and button.retries,buttonPhysical=button and button.manual,
            buttonReleaseCompletedAt=action and action.buttonReleaseCompletedAt,
            hostDuration=self.Metrics.hostDuration,hostDurationMax=self.Metrics.hostDurationMax,
            budgetEnd=action and action.budgetEnd,predecessorID=action and action.predecessorID,handoffStatus=action and action.handoffStatus,
            interferenceID=action and action.interferenceID,interferenceAt=action and action.interferenceAt,interferenceCause=action and action.interferenceCause,
            reason=reason,state=action and action.state,requestedAt=action and action.requestedAt,
            acquiredAt=action and action.acquiredAt,positionedAt=action and action.positionedAt,
            preparationBudget=action and action.preparationBudget,preparationMs=action and action.preparationMs,
            positionPasses=action and action.positionPasses,nativePlacementConfirmedAt=action and action.nativePlacementConfirmedAt,
            screenPlacementConfirmedAt=action and action.screenPlacementConfirmedAt,
            observedAt=action and action.observedAt,returnRequestedAt=action and action.returnRequestedAt,
            returnObservedAt=action and action.returnObservedAt,manualAt=action and action.manualAt,
            preparedAt=action and action.preparedAt,warpStartedAt=action and action.warpStartedAt,
            gameplayValidatedAt=action and action.gameplayValidatedAt,commitValidatedAt=action and action.commitValidatedAt,
            prevalidateWorldCast=action and action.prevalidateWorldCast or nil,
            pointerMove=action and action.pointerMove or nil,
            returnTarget=details and copy(action and action.returnTarget),returnBefore=details and copy(action and action.returnBefore),
            returnSample=details and copy(action and action.returnSample),returnAccepted=action and action.returnAccepted,
            sentAt=action and action.sentAt,releasedAt=action and action.releasedAt,
            observation=action and action.observation,hold=action and action.hold,
            class=action and action.class,space=action and action.space,
            requestedWorld=details and copy(action and action.world),actionScreen=details and copy(action and action.actionScreen),
            playerScreen=details and copy(action and action.playerScreen or self.PlayerScreen),
            playerWorld=details and copy(action and action.playerWorld or self.PlayerWorld),
            screenAtSend=details and copy(action and action.screenAtSend),worldAtSend=details and copy(action and action.worldAtSend),
            observedEndpoint=details and copy(action and action.observedEndpoint),beforePath=details and copy(action and action.beforePath),
            pathObservedAt=action and action.pathObservedAt,pathResult=action and action.pathResult,
            expectedError=action and action.expectedError,playerError=action and action.playerError,
            interrupted=action and action.interrupted,competitor=action and action.competitor,
            ggCompatible=action and action.ggCompatible,inputEdge=self.LastInputEdge and {
                message=self.LastInputEdge.message,param=self.LastInputEdge.param,at=self.LastInputEdge.at,
                classification=self.LastInputEdge.classification},
            uncertain=self.Uncertain==true,reconstructedScreen=details and copy(self.ReconstructedScreen)}
        if details and (kind=='position_unconfirmed' or kind=='player_motion_ambiguous' or kind=='return_discontinuity') then
            event.screenSample=details and copy(env.screen());event.worldSample=details and copy(env.world())
        end
        if fields then for k,v in pairs(fields) do if type(v)~='table' then event[k]=v end end end
        if kind=='aim_failed' or kind=='aborted' or kind=='submission_uncertain' or kind=='position_unconfirmed'
            or kind=='return_discontinuity' or kind=='button_release_failed' then
            local errors=self.DiagnosticErrors;errors.sequence=errors.sequence+1
            local row={};for k,v in pairs(event) do row[k]=v end
            row.inputSequence=event.sequence;row.sequence=errors.sequence
            if errors.count<64 then errors.rows[(errors.head+errors.count-1)%64+1]=row;errors.count=errors.count+1
            else errors.rows[errors.head]=row;errors.head=errors.head%64+1;errors.lost=errors.lost+1 end
        end
        local m=self.Metrics
        if m.eventCount<256 then
            events[(m.eventHead+m.eventCount-1)%256+1]=event;m.eventCount=m.eventCount+1
        else
            events[m.eventHead]=event;m.eventHead=m.eventHead%256+1;m.lostEvents=m.lostEvents+1
        end
    end
    local function eventCopy(row)
        local out={};for k,v in pairs(row) do
            if type(v)=='table' then local t={};for a,b in pairs(v) do t[a]=b end;out[k]=t else out[k]=v end
        end;return out
    end
    function cursor:GetDiagnosticErrors(after,limit)
        local errors=self.DiagnosticErrors;local out={};after=after or 0;limit=limit or 64
        local oldest=errors.rows[errors.head]
        if not oldest then return out,0 end
        for offset=0,errors.count-1 do
            local row=errors.rows[(errors.head+offset-1)%64+1]
            if row.sequence>after and #out<limit then out[#out+1]=eventCopy(row) end
        end
        return out,math.max(0,oldest.sequence-after-1)
    end
    function cursor:GetDiagnosticEvents(after,limit)
        local m=self.Metrics;local out={};after=after or 0;limit=limit or 16
        local oldest=m.events[m.eventHead]
        if not oldest then return out,0 end
        local start=math.max(0,math.floor(after-oldest.sequence+1))
        for offset=start,math.min(m.eventCount-1,start+limit-1) do
            local row=m.events[(m.eventHead+offset-1)%256+1]
            out[#out+1]=eventCopy(row)
        end
        return out,math.max(0,oldest.sequence-after-1)
    end
    function cursor:GetPendingButtons()
        local out={}
        for vk,row in pairs(self.Buttons) do
            out[tostring(vk)]={owner=row.owner,id=row.action.id,pendingUp=true,retries=row.retries,
                lastAttemptTick=row.lastTick,physicalTakeover=row.manual==true,exhausted=row.retries>=3}
        end
        return out
    end
    function cursor:GetDiagnostics()
        local out={events={},sequence=self.Metrics.sequence,lostEvents=self.Metrics.lostEvents,
            detailed=self.DetailedDiagnostics~=false,pendingButtons=self:GetPendingButtons(),
            hostDuration=self.Metrics.hostDuration,hostDurationMax=self.Metrics.hostDurationMax,
            hostCalls=self.Metrics.hostCalls,cursorReads=self.Metrics.cursorReads,unknown=self.Metrics.unknown,
            misdirected=self.Metrics.misdirected,interruptions=self.Metrics.interruptions,timing=self.Timing:summary(),
            uncertain=self.Uncertain==true,playerScreen=copy(self.PlayerScreen),reconstructedScreen=copy(self.ReconstructedScreen)}
        out.events=self:GetDiagnosticEvents(0,256)
        return out
    end
    function cursor:call(fn,...)
        if self.DiagnosticsEnabled==false then
            self.InFlight=(self.InFlight or 0)+1
            local ok,value=pcall(fn,...);self.InFlight=self.InFlight-1
            return ok and value~=false,value
        end
        self.Metrics.hostCalls=self.Metrics.hostCalls+1
        self.InFlight=(self.InFlight or 0)+1
        local started=env.clock();local ok,result=pcall(fn,...)
        local duration=env.clock()-started
        if not finite(duration) or duration<0 then self.Metrics.invalidDurations=(self.Metrics.invalidDurations or 0)+1;duration=0 end
        self.Metrics.hostDuration=self.Metrics.hostDuration+duration
        self.Metrics.hostDurationMax=math.max(self.Metrics.hostDurationMax,duration)
        self.InFlight=self.InFlight-1
        return ok and result~=false,result
    end
    local canonicalKey={[160]=16,[161]=16,[162]=17,[163]=17,[164]=18,[165]=18}
    local keyFamilies={[16]={16,160,161},[17]={17,162,163},[18]={18,164,165}}
    function cursor:GetPlayerPosition() return copy(self.PlayerWorld or env.world()) end
    function cursor:GetPlayerScreenPosition() return copy(self.PlayerScreen) end
    function cursor:ReadKeyState(key)
        -- The host exposes current state, not a raw physical-input stream.
        -- Owned keys and unavailable/erroring queries remain unknown.
        local family=canonicalKey[key] or key
        for _,alias in ipairs(keyFamilies[family] or {key}) do if self.KeysOwned[alias] then return nil end end
        if not env.isDown then return nil end
        local ok,state=pcall(env.isDown,key)
        if ok and type(state)=='boolean' then return state end
    end
    function cursor:IsSyntheticEvent() return (self.InFlight or 0)>0 or self.LastInputSynthetic==true end
    function cursor:ReconcilePhysical()
        if not self.PhysicalReview or env.clock()<(self.PhysicalPollAt or 0) then return end
        local now=env.clock();self.PhysicalPollAt=now+100
        for key,first in pairs(self.PhysicalReview) do
            local released=true
            for _,alias in ipairs(keyFamilies[key] or {key}) do
                if self:ReadKeyState(alias)~=false then released=false;break end
            end
            if not self.Physical[key] then self.PhysicalReview[key]=nil
            elseif released and first and now-first>=90 then
                self.Physical[key]=nil;self.PhysicalReview[key]=nil
                self:record('physical_state_reconciled',nil,tostring(key)..': two focused released samples; no key-up sent')
            else self.PhysicalReview[key]=released and now or false end
        end
        if not next(self.PhysicalReview) then self.PhysicalReview=nil end
    end
    function cursor:PruneKeyEchoes()
        local now=env.clock()
        for i=#self.KeyEchoes,1,-1 do
            local row=self.KeyEchoes[i]
            -- Active owned holds can receive their first echo after a stalled
            -- callback (>150ms in live traces). Keep only the exact current
            -- lease's down edge longer, never arbitrary old/manual presses.
            local owned=row.down and row.lease and self.KeysOwned[row.key]
                and self.KeyLeases and self.KeyLeases[row.key]==row.lease
            if now-row.at>(owned and 1000 or 150) then table.remove(self.KeyEchoes,i) end
        end
    end
    function cursor:ExpectKey(key,down)
        self:PruneKeyEchoes()
        local row={key=canonicalKey[key] or key,down=down,at=env.clock(),seen={}}
        self.KeyEchoes[#self.KeyEchoes+1]=row
        if #self.KeyEchoes>64 then table.remove(self.KeyEchoes,1) end
        return row
    end
    function cursor:Interfere(action,cause)
        local id=action and action.id
        if not id then self.AnonymousEffect=(self.AnonymousEffect or 0)-1;id=self.AnonymousEffect end
        if self.LastEffectAction==id then return end
        self.LastEffectAction=id
        for _,previousID in ipairs(self.Recent) do
            local r=self.Records[previousID]
            if r and r.id~=id and r.sentAt and not r.observedAt and not r.timedOut then
                r.competitor=true;r.interferenceID=id;r.interferenceAt=env.clock();r.interferenceCause=cause
                self:record('interference',r,cause)
            end
        end
    end
    function cursor:ButtonReleased(vk)
        if self.Physical[vk] or not env.isDown then return false end
        local ok,down=pcall(env.isDown,vk);return ok and down==false
    end
    function cursor:ReleaseButton(vk,retry)
        local row=self.Buttons[vk];if not row then return true end
        if self.Physical[vk] or row.manual then return false end
        if row.upTried and not retry then return false end
        if retry then
            if row.retries>=3 or row.lastTick==self.TickSerial then return false end
            row.retries=row.retries+1
        end
        row.lastTick=self.TickSerial;row.upTried=true
        local ok=self:CallMouse(vk==1 and 4 or 16,vk,false,row.action)
        if self.Active==row.action and row.action.sentAt then
            row.action.holdUntil=row.action.sendCompletedAt+row.action.hold;self.Timer=row.action.holdUntil
        end
        if self:ButtonReleased(vk) then
            self.Buttons[vk]=nil;self:record('button_released',row.action,tostring(vk));return ok
        end
        self:record(row.retries>=3 and 'button_release_exhausted' or 'button_release_pending',row.action,tostring(vk))
        return false
    end
    function cursor:CleanupButtons(retry,owner)
        for vk,row in pairs(self.Buttons) do
            if not owner or row.owner==owner then
                if self:ButtonReleased(vk) then self.Buttons[vk]=nil;self:record('button_released',row.action,tostring(vk))
                elseif not row.manual then self:ReleaseButton(vk,retry) end
            end
        end
    end
    function cursor:CallMouse(flag,vk,down,action)
        local row=self:ExpectKey(vk,down)
        row.mouse=true;row.pos=copy(self.ActionScreen);row.returnPos=copy(self.PlayerScreen)
        self:Interfere(action,down and "mouse down" or "mouse up")
        local ok,result=self:call(env.mouse,flag)
        if action then
            if down or self.Active==action then action.sendCompletedAt=env.clock()
            else action.buttonReleaseCompletedAt=env.clock() end
        end
        if not ok then
            for i=#self.KeyEchoes,1,-1 do if self.KeyEchoes[i]==row then table.remove(self.KeyEchoes,i);break end end
        end
        return ok,result
    end
    function cursor:MatchKeyEcho(key,down,mouse)
        self:PruneKeyEchoes()
        -- A host may omit an earlier key-up callback even though the key was
        -- released. Its stale FIFO entry must not misclassify the next owned
        -- acquisition as a player's permanent hold. Only bypass it for the
        -- exact, still-owned lease whose down we actually issued. Mouse input
        -- and unmatched user key presses keep the stricter attribution below.
        local lease=not mouse and down and self.KeysOwned[key] and self.KeyLeases and self.KeyLeases[key]
        if lease then
            for index,row in ipairs(self.KeyEchoes) do
                if row.key==(canonicalKey[key] or key) and row.down and row.lease==lease and not row.seen[key] then
                    for i=1,index do
                        local prior=self.KeyEchoes[i]
                        if prior.key==row.key and prior.lease and prior.lease<=lease then prior.seen[key]=true end
                    end
                    return true
                end
            end
        end
        for _,row in ipairs(self.KeyEchoes) do
            if row.key==(canonicalKey[key] or key) and not row.seen[key] then
                -- Preserve order separately for generic and side-specific modifiers.
                -- This is bounded echo attribution, never proof of game acceptance
                -- or physical input interception. Mismatches remain manual input.
                if row.down~=down then return false end
                if mouse and (not row.mouse or not near(env.screen(),row.pos) and not near(env.screen(),row.returnPos)) then return false end
                row.seen[key]=true;return true
            end
        end
        return false
    end
    -- Separate command identity from aim/transport interference. This receipt is
    -- not execution evidence; consumers still need a fresh mechanical transition.
    function cursor:CommandGeneration(key)
        return self.CommandGenerations[canonicalKey[key] or key] or 0
    end
    function cursor:AdvanceCommand(key)
        key=canonicalKey[key] or key
        self.CommandGenerations[key]=(self.CommandGenerations[key] or 0)+1
        return key,self.CommandGenerations[key]
    end
    function cursor:CallKey(key,down,action,releasedLease)
        if down then
            local command,generation=self:AdvanceCommand(key)
            if action and action.keys and #action.keys==1 and not action.commandReceipt then
                action.commandReceipt={key=command,generation=generation,expiresAt=env.clock()+1000,session=self.SessionID}
            end
        end
        local row=self:ExpectKey(key,down) -- Before synchronous host callbacks.
        row.lease=releasedLease or self.KeyLeases and self.KeyLeases[key]
        if action then action.sentAt=action.sentAt or env.clock();action.state='sent' end
        self:Interfere(action,down and "key down" or "key up")
        local ok,result=self:call(down and env.down or env.up,key)
        if action then action.sendCompletedAt=env.clock() end
        if not ok then
            for i=#self.KeyEchoes,1,-1 do
                if self.KeyEchoes[i]==row then table.remove(self.KeyEchoes,i);break end
            end
        end
        return ok,result
    end
    function cursor:AcquireKey(key,owner,action)
        if not key then return false end
        if self.Uncertain or not self:Available() then return false end
        if self.KeysOwned[key] then
            if action then action.reason='key_already_owned';return false end
            return self.KeysOwned[key]==owner
        end
        if self.Physical[key] or safe(env.isDown,key) then return false end
        if action and action.budgetEnd and not self:InputBudget(action) then return false end
        if action and action.prevalidatedWorld and not action.sentAt then
            local ticket=action.commitCertificate;action.commitCertificate=nil
            if self.Active~=action or not self:valid(action,true) then return false end
            if not ticket or ticket.pass~=self.ResolutionPass or not action.resolution
                or ticket.revision~=action.resolution.revision or env.clock()-ticket.at>20 then
                action.reason='world_commit_expired';return false
            end
            if not near(env.screen(),action.actionScreen) then action.reason='cursor_changed_before_send';return false end
        end
        self.KeysOwned[key]=owner -- Register ownership before synchronous callbacks.
        self.KeyLeases=self.KeyLeases or {};self.KeyLeaseSerial=(self.KeyLeaseSerial or 0)+1
        self.KeyLeases[key]=self.KeyLeaseSerial
        if action then action.keyLease=self.KeyLeaseSerial end
        if action then action.sentAt=action.sentAt or env.clock();action.state='sent' end
        local ok=self:CallKey(key,true,action)
        if not ok then self:ReleaseKey(key,owner,action) end
        return ok
    end
    function cursor:ReleaseKey(key,owner,action,lease,finalCleanup)
        if self.Resolving then return false end
        if lease and (not self.KeyLeases or self.KeyLeases[key]~=lease) then return false end
        if self.KeysOwned[key]~=owner then return false end
        local acquisition=self.KeyLeases and self.KeyLeases[key]
        local previous=self.PendingUp[key]
        if previous and previous.attempts>=3 and not finalCleanup and safe(env.isDown,key) then return false end
        self.KeysOwned[key]=nil;self.PendingUp[key]=nil
        if self.KeyLeases then self.KeyLeases[key]=nil end
        if self.Physical[key] then return false end
        local ok=self:CallKey(key,false,action,acquisition)
        if safe(env.isDown,key) then
            self.KeysOwned[key]=owner;self.KeyLeases[key]=acquisition
            self.PendingUp[key]={owner=owner,attempts=previous and previous.attempts+1 or 0,lease=acquisition}
            self:record('key_release_pending',self.Active,tostring(key))
        end
        return ok
    end
    function cursor:PulseKeys(keys,owner,action)
        owner=owner or 'control'
        if not self:Available() then return false end
        if type(keys)~='table' then keys={keys} end
        for _,key in ipairs(keys) do
            if self.Physical[key] or safe(env.isDown,key) and self.KeysOwned[key]~=owner then return false end
        end
        for _,key in ipairs(keys) do
            if not self:AcquireKey(key,owner,action) then return false end
            if not self:ReleaseKey(key,owner,action) then return false end
        end
        -- Host return is submission only, never spell confirmation.
        return true
    end
    function cursor:SendKeys(keys,owner)
        local r=self:newAction{keys=keys,owner=owner,critical=true,class='key'}
        self.LastActionID=r.id
        if not self:valid(r) then r.state='aborted';r.abortedAt=env.clock();return false end
        -- A key-only command can coexist with an aim lease but cannot establish
        -- unique attribution for another in-flight action.
        local result=self:PulseKeys(r.keys,r.owner,r)
        if not r.sentAt then r.state='aborted';r.abortedAt=env.clock() end
        r.releasedAt=env.clock();self:record(r.sentAt and 'sent' or 'aborted',r,result and nil or 'key submission declined or uncertain')
        return result
    end
    function cursor:IsChatOpen()
        -- Some hosts report false while the chat editor is visibly open.
        -- Keep physical Enter/Escape evidence until explicitly dismissed;
        -- injected Enter and key-repeat must never change this latch.
        return self.ChatLatched==true or (env.chat and safe(env.chat)==true) or false
    end
    function cursor:Available()
        return not self.Resolving and not self.Stopped and safe(env.enabled) and safe(env.focus)
            and not self:IsChatOpen() and not env.hero.dead
    end
    function cursor:SetPosition(p,phase,action)
        if self.Resolving then return false end
        if phase=='action' then self.PlacementAccepted=false end
        if not p or not finite(p.x) or not finite(p.y) then return false end
        if phase=='action' and p.onScreen==false then return false end
        local bounds=env.resolution and env.resolution()
        if bounds and (p.x<0 or p.y<0 or p.x>=bounds.x or p.y>=bounds.y) then return false end
        local warp={pos={x=p.x,y=p.y},phase=phase,at=env.clock(),id=self.Active and self.Active.id}
        self.Warps[#self.Warps+1]=warp
        if #self.Warps>32 then table.remove(self.Warps,1) end
        self.LastWarp=warp -- Before host invocation: synchronous WndMsg is synthetic too.
        local aiming=phase=='action' and self.Active and self.Active.class=='hover' and self.Active
        if aiming then aiming.sentAt=aiming.sentAt or warp.at;aiming.state='sent' end
        self:Interfere(action or self.Active,"cursor "..tostring(phase))
        local ok,result=self:call(env.set,p.x,p.y)
        if aiming then aiming.sendCompletedAt=env.clock();if not ok then aiming.submissionFailed=true end end
        if phase=='action' then self.PlacementAccepted=ok end
        if near(env.screen(),warp.pos) then warp.observed=true end
        return ok,result
    end
    function cursor:PollReturn(p)
        local r=self.PendingReturn;if not r then return end
        local now=env.clock()
        if near(p,r.returnTarget) then
            r.returnObservedAt=now;self.PendingReturn=nil;self.Uncertain=false;self.UntrustedScreen=nil
            self:record('return_observed',r,'Later screen sample; no input acceptance claim');return
        end
        if self.Generation~=r.returnGeneration or not self:Available() then
            self.PendingReturn=nil;self:record('return_unconfirmed',r,'New input or unavailable; no retry');return
        end
        if now>r.returnRequestedAt and not r.returnRetried and near(p,r.returnBefore) then
            r.returnRetried=true;self.RecoveryUsed=true
            r.returnAccepted=self:SetPosition(r.returnTarget,'return',r);r.returnSample=copy(env.screen())
            self:record('return_retry',r,'One retry while cursor still at pre-return position')
            if near(r.returnSample,r.returnTarget) then
                r.returnObservedAt=now;self.PendingReturn=nil;self.Uncertain=false;self.UntrustedScreen=nil
                self:record('return_observed',r,'Screen sample after bounded retry')
            end
        elseif now-r.returnRequestedAt>=100 then
            self.PendingReturn=nil
            self:record('return_unconfirmed',r,'No matching sample; no continued cursor forcing')
        end
    end
    function cursor:SamplePlayer()
        local p=env.screen();if not p then return end
        if self.PendingReturn then self:PollReturn(p);p=env.screen();if not p then return end end
        local now=env.clock();local synthetic=false
        local guard=self.ReturnGuard
        if guard and (now-guard.at>250 or self.Active or self.Generation~=guard.generation) then
            self.ReturnGuard=nil;guard=nil
        end
        if guard and not self.PendingReturn and not self.RecoveryUsed
            and screenDistance(p,guard.previous)>math.max(256,guard.radius*2)
            and screenDistance(p,guard.action)<=guard.radius and screenDistance(p,self.PlayerScreen)>256 then
            -- A discontinuous return to the recent action region is ambiguous,
            -- even if real motion has moved it away from the exact warp pixel.
            -- Never reconstruct deltas: one recovery uses only the last trusted
            -- player sample. Smooth traversal of the region is left untouched.
            self.ReturnGuard=nil;self.RecoveryUsed=true;self.Uncertain=true;self.UntrustedScreen=copy(p)
            self:record('return_discontinuity',guard.actionRecord,'Suspected delayed action displacement; one bounded return')
            self:CancelAll('suspected delayed cursor displacement',true)
            self:SetPosition(self.PlayerScreen,'return')
            if near(env.screen(),self.PlayerScreen) then self.Uncertain=false end
            return
        end
        for i=#self.Warps,1,-1 do
            local w=self.Warps[i]
            if now-w.at>250 then table.remove(self.Warps,i)
            elseif near(p,w.pos) then
                synthetic=true;w.observed=true
                -- A delayed action warp after release never becomes player aim.
                if not self.Active and w.phase=='action' and self.LastReturnAt and w.at<=self.LastReturnAt
                    and not near(p,self.PlayerScreen) and not w.recovered then
                    w.recovered=true;self:record('late_warp',nil,'return once; attribution uncertain')
                    self.UntrustedScreen=copy(p)
                    self.Uncertain=true
                    self:CancelAll('late synthetic cursor feedback',true)
                    if not self.RecoveryUsed then self.RecoveryUsed=true;self:SetPosition(self.PlayerScreen,'return') end
                end
                break
            end
        end
        if synthetic then return end
        if not self.Active and (self.PendingReturn or near(p,self.UntrustedScreen)) then return end
        if self.Active then
            if self.Active.pointerMove then
                -- No synthetic positioning belongs to this click. Physical
                -- motion during the native down/up must never trigger a return.
                self.PlayerScreen=copy(p);self.PlayerWorld=copy(env.world());return
            end
            if not near(p,self.ActionScreen) and not near(p,self.PlayerScreen) then
                local r=self.Active
                -- A key already handed to the host still needs its complete
                -- post-send cursor stabilization. Pure pointer sampling must
                -- not itself warp back to the player position during that hold.
                -- This does not constrain physical motion, reposition, retry or
                -- extend the hold. Explicit input/cancel/unavailability still
                -- takes the immediate cleanup path; after hold, ordinary motion
                -- reconciliation below resumes.
                if r.sentAt and r.class=='cast' and r.space=='world' and not r.leftClicks
                    and r.holdUntil and now<r.holdUntil then
                    if not r.pointerMotionDuringHold then
                        r.pointerMotionDuringHold=true
                        self:record('pointer_motion_during_hold',r,'No return warp before post-send stabilization ends')
                    end
                    return
                end
                if self.CanCorrectWorldDrift and self:CanCorrectWorldDrift(r,p) then
                    if not r.pointerCorrectionPending then
                        r.pointerCorrectionPending=true
                        self:record('world_pointer_correction_pending',r,'Small drift; fresh validation and placement required')
                    end
                    return
                end
                self.ReconstructedScreen=copy(p)
                self:record('player_motion_ambiguous',self.Active,'screen delta observed; return reconstruction is not validated')
                self.Uncertain=true
                self:CancelAll('ambiguous mouse movement',true)
            end
            return
        end
        -- Unmatched motion while synthetic acknowledgements remain is not a
        -- trustworthy delta. Observe it, but do not move the return point.
        for _,w in ipairs(self.Warps) do
            if not w.observed then self.ReconstructedScreen=copy(p);return end
        end
        self.PlayerScreen=copy(p);self.PlayerWorld=copy(env.world());self.Uncertain=false;self.UntrustedScreen=nil
        if guard then guard.previous=copy(p) end
    end
    function cursor:newAction(request)
        self.Serial=self.Serial+1
        local r={id=self.Serial,owner=request.owner or 'control',target=request.target,
            space=request.world and 'minimap' or request.target and (request.target.pos or request.target.z~=nil) and 'world' or 'screen',
            publicTarget=request.publicTarget,
            keys=request.keys or {},priority=request.priority or 0,
            requestedAt=env.clock(),expires=request.expires or env.clock()+250,
            validate=request.validate,verifyTarget=request.verifyTarget,aimCandidates=request.aimCandidates,aimFallback=request.aimFallback,leftClicks=request.leftClicks,
            dependency=request.dependency,world=copy(request.world or request.target and (request.target.pos or request.target.z~=nil and request.target)),critical=request.critical~=false,
            class=request.class or 'cast',state='requested',generation=self.Generation}
        r.targetID=r.target and r.target.pos and (r.target.networkID or r.target.handle)
        r.verifyID=r.verifyTarget and (r.verifyTarget.networkID or r.verifyTarget.handle)
        r.verifyKind=r.verifyTarget and (r.verifyTarget.networkID and "networkID" or "handle")
        if type(r.keys)~='table' then r.keys={r.keys} end
        local keys={};for i,v in ipairs(r.keys) do keys[i]=v end;r.keys=keys
        if r.target and not r.target.pos then r.target=copy(r.target) end
        if r.leftClicks and (not finite(r.leftClicks) or r.leftClicks<1 or r.leftClicks>2 or r.leftClicks%1~=0) then
            r.validate=function()return false end
        end
        self.Records[r.id]=r;self.Recent[#self.Recent+1]=r.id
        if #self.Recent>128 then self.Records[table.remove(self.Recent,1)]=nil end
        self:record('requested',r);return r
    end
    function cursor:valid(r,transportOnly)
        local why=r.state=='aborted' and (r.reason or 'cancelled') or self.Uncertain and 'input_uncertain'
            or r.generation~=self.Generation and 'interrupted' or env.clock()>r.expires and 'expired'
            or not self:Available() and 'context_blocked'
        if not why and r.validate and not transportOnly then
            local ok,valid,detail=pcall(r.validate,r,self.ResolutionSnapshot and self:ResolutionSnapshot(r))
            if not ok or not valid then why=ok and (detail or 'plugin_validation_declined') or 'validation_exception' end
        end
        if not why and r.target and r.target.pos then
            local t=r.target
            why=(not r.targetID or (t.networkID or t.handle)~=r.targetID) and 'target_identity_changed'
                or not t.valid and 'target_invalid' or t.dead and 'target_dead'
                or not t.visible and 'target_invisible' or not t.isTargetable and 'target_untargetable'
        end
        if why then r.reason=tostring(why);return false end
        return true
    end
    function cursor:Submit(request)
        if self.Resolving then return false end
        if type(request)~='table' or #self.Queue>=32 then return nil,'queue full or invalid request' end
        if request.priority~=nil and not finite(request.priority) or request.expires~=nil and not finite(request.expires) then
            return nil,'invalid priority or expiry'
        end
        local r=self:newAction(request)
        self.Queue[#self.Queue+1]=r
        table.sort(self.Queue,function(a,b) if a.priority==b.priority then return a.id<b.id end return a.priority>b.priority end)
        return r.id,'requested'
    end
    function cursor:GetAction(id)
        local r=self.Records[id];if not r then return end
        local out={};for _,k in ipairs({'id','owner','state','requestedAt','sentAt','observedAt','releasedAt','completedAt','abortedAt','observation','reason','interrupted','competitor','sendCompletedAt','holdUntil','budgetEnd','handoffStatus','predecessorID','interferenceID','interferenceAt','interferenceCause'}) do out[k]=r[k] end
        for _,k in ipairs({'playerScreen','playerWorld','actionScreen','screenAtSend','worldAtSend'}) do out[k]=copy(r[k]) end
        out.inputSession=self.SessionID
        return out
    end
    function cursor:GetState()
        local held={};for key in pairs(self.Physical) do held[#held+1]=key end
        local owned={};for key,owner in pairs(self.KeysOwned) do owned[tostring(key)]=owner end
        return {phase=self.Step,owner=self.Active and self.Active.owner,id=self.Active and self.Active.id,
            pendingButtons=self:GetPendingButtons(),
            pendingReturnID=self.PendingReturn and self.PendingReturn.id,
            pendingPlacement=self.Active and self.Active.awaitingPosition==true or false,
            uncertain=self.Uncertain==true,physical=held,owned=owned,
            playerScreen=copy(self.PlayerScreen),actionScreen=copy(self.ActionScreen),
            screen=copy(env.screen()),remainingMs=math.max(0,(self.Timer or 0)-env.clock()),
            mode=self.GGCompatible and 'GG-compatible phases' or 'experimental adaptive phases',session=self.SessionID}
    end
    function cursor:InputBudget(r)
        if r.sentAt then return true end
        if env.clock()+r.hold>r.budgetEnd then
            self.Timing:observePreparation(r,env.clock(),true)
            r.reason='Insufficient positioning budget for full hold';self:record('budget_rejected',r,r.reason);return false
        end
        return true
    end
    -- An observation is made after every warp and again immediately before input.
    function cursor:VerifyHover(r)
        local fn=Game.GetUnderMouseObject
        local ok,t=false,nil
        if type(fn)=='function' then ok,t=pcall(fn) end
        local returnedType=type(t);local returnedNil=ok and t==nil
        local object=returnedType=='table' or returnedType=='userdata'
        local observed=ok and object and t or nil
        local expected=r.verifyTarget
        local same=observed and expected and r.verifyID and observed[r.verifyKind]==r.verifyID
        if same and expected.networkID and t.networkID and expected.networkID~=t.networkID then same=false end
        if same and expected.handle and t.handle and expected.handle~=t.handle then same=false end
        local why=type(fn)~='function' and 'hover_api_missing' or not ok and 'hover_api_error'
            or not same and 'hover_identity_mismatch' or nil
        local aim=r.aim or {};r.aim=aim
        aim.at=env.clock();aim.api=type(fn)~='function' and 'missing' or ok and 'returned' or 'error'
        aim.returnType=returnedType;aim.returnedNil=returnedNil
        aim.expectedKind=r.verifyKind;aim.expectedID=r.verifyID
        aim.expectedNetworkID=expected and expected.networkID;aim.expectedHandle=expected and expected.handle
        aim.observedNetworkID=observed and observed.networkID;aim.observedHandle=observed and observed.handle
        aim.reason=why;aim.hoverConfirmed=same==true;aim.confirmed=same==true
        aim.screenError=screenDistance(env.screen(),r.actionScreen)
        aim.worldError=worldDistance(env.world(),r.world)
        if same then aim.source='native_hover';aim.confirmedAt=env.clock();aim.position=copy(r.actionScreen) end
        -- Optional client policy for a nil-only host result. A contradictory
        -- object, an API error, or a cursor outside the placement never qualifies.
        if not same and returnedNil and r.aimFallback and r.actionScreen and aim.screenError<=6 then
            local good,allowed=pcall(r.aimFallback,copy(r.actionScreen))
            if good and allowed==true then
                aim.source='client_projection';aim.confirmed=true;aim.confirmedAt=env.clock()
                aim.position=copy(r.actionScreen);aim.reason=nil;return true
            end
        end
        return same==true,why
    end
    function cursor:FailAim(r,why)
        r.aim=r.aim or {};r.aim.reason=why;r.aim.confirmed=false;r.aim.exhausted=true;r.aim.failedAt=env.clock();r.reason=why
        if r.onAimFailure then r.onAimFailure(r) end
        self:record('aim_failed',r,why,r.aim)
        self:release(why)
        -- No input was sent, so there is no stabilization to preserve. The
        -- confirmed return ends acquisition; the retry gate supplies fairness.
        if not r.sentAt and not self.PendingReturn then self.Step=0;self.NotBefore=env.clock();self.Timer=self.NotBefore end
        return false
    end
    function cursor:RefreshAimPoints(r)
        local ok,points=pcall(r.aimCandidates,r.target)
        if not ok or type(points)~='table' or #points==0 or #points>5 then r.reason='invalid_aim_candidates';return false end
        local fresh={};local bounds=env.resolution and env.resolution()
        for _,p in ipairs(points) do
            if not p or not finite(p.x) or not finite(p.y) or p.z~=nil
                or bounds and (p.x<0 or p.y<0 or p.x>=bounds.x or p.y>=bounds.y) then
                r.reason='invalid_aim_candidates';return false
            end
            fresh[#fresh+1]=copy(p)
        end
        r.aimPoints=fresh
        return true
    end
    function cursor:TryAim(r)
        if not self:valid(r) then self:release(r.reason);return false end
        local same,why=self:VerifyHover(r)
        if same and near(env.screen(),r.actionScreen) then return self:SendPositioned(r) end
        if why=='hover_api_missing' or why=='hover_api_error' then return self:FailAim(r,why) end
        if not near(env.screen(),r.actionScreen) then why='aim_position_mismatch' end
        if env.clock()+r.hold>=r.budgetEnd then return self:FailAim(r,'aim_budget_exhausted') end
        -- The target and camera may move between callbacks. Refresh geometry,
        -- retaining the candidate index and the original bounded cursor budget.
        if not self:RefreshAimPoints(r) then return self:FailAim(r,r.reason) end
        local nextIndex=(r.aimIndex or 1)+1
        local point=r.aimPoints and r.aimPoints[nextIndex]
        if not point then return self:FailAim(r,why or 'hover_identity_mismatch') end
        r.aimIndex=nextIndex;r.aim.candidate=nextIndex
        self.correctedCastPos=point;self.ActionScreen=copy(point);r.actionScreen=copy(point)
        local ok=self:SetPosition(point,'action',r)
        -- Do not reuse the previous hover result, even for synchronous hosts.
        local confirmed,reason=self:VerifyHover(r)
        if not ok or not near(env.screen(),point) then return self:FailAim(r,'aim_position_mismatch') end
        if confirmed then return self:SendPositioned(r) end
        r.awaitingPosition=true;r.sendAfter=env.clock();self.Timer=r.budgetEnd-r.hold
        self:record('aim_candidate',r,reason,r.aim);return true
    end
    function cursor:PrepareTargetFilter(r)
        if not r.target or not r.target.type or r.target.type==env.heroType or not env.tco then return true end
        local key=env.tco;local physical=self.Physical[canonicalKey[key] or key]
        if physical then r.reason='target_champions_only_held';return false end
        if self.KeysOwned[key]=='orbwalker' then self:ReleaseKey(key,'orbwalker') end
        if not safe(env.isDown,key) then self.TCORecovery=nil;return true end
        -- HK_TCO can remain latched across runtime reloads without an owner in
        -- this dispatcher. Recover only for an explicit non-champion target,
        -- never for an observed physical hold or another input owner's lease.
        if env.recoverLatchedTCO and not self.KeysOwned[key] then
            local now=env.clock();local recovery=self.TCORecovery
            if not recovery then recovery={attempts=0,nextAt=0};self.TCORecovery=recovery end
            if recovery.attempts<3 and now>=recovery.nextAt then
                recovery.attempts=recovery.attempts+1;recovery.nextAt=now+250
                local accepted=self:CallKey(key,false)
                local stillHeld=safe(env.isDown,key)==true
                self:record('target_filter_recovery',r,stillHeld and 'release awaiting native confirmation' or 'native filter released',
                    {targetFilterKey=key,releaseAccepted=accepted,stillHeld=stillHeld,attempt=recovery.attempts})
                if not stillHeld then self.TCORecovery=nil;return true end
            end
        end
        r.reason='target_champions_only_held';return false
    end
    function cursor:StepPressKey()
        local r=self.Active
        local validationStart=self.DiagnosticsEnabled~=false and env.clock()
        if not r then return false end
        if r.prevalidatedWorld then
            if not self:WorldCommitValid(r) then return false end
        elseif not self:valid(r) then return false end
        local checkedScreen=env.screen()
        if r.prevalidatedWorld and self.DiagnosticsEnabled~=false then r.screenAtSend=copy(checkedScreen) end
        if not near(checkedScreen,self.correctedCastPos) then
            r.reason='cursor_changed_before_send'
            if validationStart then
                self:record('position_unconfirmed',r,r.reason,{validationMs=env.clock()-validationStart,
                    checkedScreenX=checkedScreen and checkedScreen.x,checkedScreenY=checkedScreen and checkedScreen.y,
                    expectedScreenX=self.correctedCastPos and self.correctedCastPos.x,
                    expectedScreenY=self.correctedCastPos and self.correctedCastPos.y,
                    screenError=screenDistance(checkedScreen,self.correctedCastPos)})
            end
            return false
        end
        if r.verifyTarget then
            local confirmed,why=self:VerifyHover(r)
            if not confirmed then r.reason=why;return false end
            if not self:valid(r) then return false end
        end
        if r.prevalidateWorldMove or r.pointerMove then
            local fn=Game.GetUnderMouseObject
            if type(fn)~='function' then r.reason='ground_hover_unavailable';return false end
            local ok,obj=pcall(fn)
            if not ok or obj~=nil then r.reason=ok and 'ground_hover_obstructed' or 'ground_hover_error';return false end
        end
        if not self:InputBudget(r) then return false end
        if not self:PrepareTargetFilter(r) then return false end
        local mouse=r.leftClicks or r.keys[1]==env.moveKey
        if mouse then
            local vk=r.leftClicks and 1 or 2
            if self.Buttons[vk] or self.Physical[vk] or safe(env.isDown,vk) then r.reason='mouse_button_held_before_send';return false end
            local down=r.leftClicks and 2 or 8;local up=r.leftClicks and 4 or 16
            for _=1,r.leftClicks or 1 do
                -- Once a host call may have sent input, cancellation cannot undo it.
                if not self:InputBudget(r) then return false end
                if r.pointerMove and (not self:valid(r,true) or not near(env.screen(),r.actionScreen)) then
                    r.reason=r.reason or 'cursor_changed_before_send';return false
                end
                if r.prevalidateWorldMove then
                    local ticket=r.commitCertificate;r.commitCertificate=nil
                    if self.Active~=r or not self:valid(r,true) then return false end
                    if r.commitGuard then
                        local ok,allowed,why=pcall(r.commitGuard)
                        if not ok or not allowed then r.reason=why or 'commit_guard_declined';return false end
                    end
                    if self.Active~=r or not self:valid(r,true)then return false end
                    if not ticket or ticket.pass~=self.ResolutionPass or not r.resolution
                        or ticket.revision~=r.resolution.revision or env.clock()-ticket.at>20 then
                        r.reason='world_commit_expired';return false
                    end
                    if not near(env.screen(),r.actionScreen) then r.reason='cursor_changed_before_send';return false end
                end
                r.sentAt=r.sentAt or env.clock();r.state='sent'
                r.mouseButton=vk;self.Buttons[vk]={owner=r.owner,action=r,retries=0}
                local ok=self:CallMouse(down,vk,true,r)
                local released=self:ReleaseButton(vk,false)
                if not ok or not released then return false end
            end
        else
            for _,key in ipairs(r.keys) do
                if self.Physical[key] or safe(env.isDown,key) and self.KeysOwned[key]~=r.owner then r.reason='key_held_before_send';return false end
            end
            if not self:PulseKeys(r.keys,r.owner,r) then return false end
        end
        return true
    end
    function cursor:InputsBlocked(r)
        local keyBlocked=false
        if r.leftClicks or r.keys[1]==env.moveKey then
            local vk=r.leftClicks and 1 or 2;keyBlocked=self.Buttons[vk] or self.Physical[vk] or safe(env.isDown,vk)
        else
            for _,key in ipairs(r.keys) do
                if self.Physical[key] or safe(env.isDown,key) and self.KeysOwned[key]~=r.owner then keyBlocked=true;break end
            end
        end
        return keyBlocked
    end
    function cursor:dispatch(r,predecessor)
        if r.resolveWorldTarget and not self:ResolveWorld(r) then r.state="aborted";r.abortedAt=env.clock();return false end
        if not self:valid(r,r.prevalidatedWorld) then r.state='aborted';r.reason=r.reason or 'validation or expiry';r.abortedAt=env.clock();self:record('aborted',r,r.reason);return false end
        -- Target-filter rejection must happen before any projection or warp.
        -- Rechecking at send time also covers a state change during placement.
        if not self:PrepareTargetFilter(r) then
            r.state='aborted';r.abortedAt=env.clock();self:record('aborted',r,r.reason);return false
        end
        if self:InputsBlocked(r) then
            r.state='aborted';r.abortedAt=env.clock();r.reason='Held input before cursor acquisition'
            self:record('aborted',r,r.reason);return false
        end
        if not r.target then
            local result=self:PulseKeys(r.keys,r.owner,r)
            if not r.sentAt then r.state='aborted';r.abortedAt=env.clock() end
            if r.sentAt and not result then r.submissionFailed=true end
            r.releasedAt=env.clock();self:record(r.sentAt and 'sent' or 'aborted',r)
            return result
        end
        if not r.rootAt then self:SamplePlayer() end
        if not self:valid(r,r.prevalidatedWorld) then return false end
        local proxy=setmetatable({CastPos=r.target,IsTarget=r.target and r.target.pos~=nil},{__index=self})
        r.ggCompatible=self.GGCompatible
        r.hold=r.ggCompatible and env.fallback() or self.Timing:hold(r.class,r.critical)
        r.playerScreen=copy(r.returnTarget or self.PlayerScreen);r.playerWorld=copy(self.PlayerWorld)
        if r.space=='minimap' then r.critical=true;r.hold=env.fallback() end
        r.beforePath=copy(env.hero.pathing and env.hero.pathing.endPos);r.origin=copy(env.hero.pos)
        if r.target and self.ProjectCastPosition then
            local ok,p=pcall(self.ProjectCastPosition,proxy)
            local bounds=env.resolution and env.resolution()
            if not ok or not p or not finite(p.x) or not finite(p.y) or p.onScreen==false
                or bounds and (p.x<0 or p.y<0 or p.x>=bounds.x or p.y>=bounds.y) then
                r.state='aborted';r.abortedAt=env.clock();self:record('aborted',r,'Projection failed before cursor acquisition');return false
            end
            r.preparedPosition=p
        end
        if r.aimCandidates then
            if not self:RefreshAimPoints(r) then return false end
            r.preparedPosition=r.aimPoints[1];r.aimIndex=1;r.aim={candidate=1}
        end
        r.preparedAt=env.clock()
        if not r.rootAt then
            self:SamplePlayer();self.CursorPos=copy(self.PlayerScreen)
            r.playerScreen=copy(r.returnTarget or self.PlayerScreen);r.playerWorld=copy(self.PlayerWorld)
        end
        if not self:valid(r) or self:InputsBlocked(r) then r.state='aborted';r.abortedAt=env.clock();return false end
        if r.prevalidatedWorld then
            self:PrepareWorldCommit(r)
            -- The final validator can take time; project the validated world
            -- intent again before the warp, never run it after positioning.
            local ok,p=pcall(self.ProjectCastPosition,proxy)
            if not ok or not p or not finite(p.x) or not finite(p.y) or p.onScreen==false then
                r.state='aborted';r.reason='world_projection_failed';return false
            end
            r.preparedPosition=p
        end
        if predecessor and self.Active~=predecessor then return false end
        r.rootAt=r.rootAt or env.clock()
        r.preparationBudget=r.resolveWorldTarget and self.Timing:preparationBudget(r.hold) or math.max(120,env.fallback()*2)
        r.budgetEnd=r.budgetEnd or math.min(r.rootAt+r.preparationBudget,r.expires+r.hold)
        if predecessor and predecessor.holdUntil and env.clock()<predecessor.holdUntil then
            predecessor.followup=r;r.handoffStatus='waiting for predecessor hold';self:record('handoff_wait',r);return true
        end
        if predecessor then
            predecessor.followup=nil;predecessor.releasedAt=env.clock();predecessor.handoffStatus='transferred'
            self:record('dependent_handoff',predecessor);r.handoffStatus='acquired'
        end
        self.CursorPos=copy(r.returnTarget or self.PlayerScreen);self.CastPos=r.target;self.Keys=r.keys
        self.IsTarget=r.target and r.target.pos~=nil;self.IsMouseClick=r.keys[1]==env.moveKey
        self.Active=r;r.acquiredAt=env.clock();self.RecoveryUsed=false;self.Step=1
        self.ForceTCOUp=r.target and r.target.type and r.target.type~=env.heroType or false
        if not r.target then
            local ok=self:PulseKeys(r.keys,r.owner,r)
            self:release(ok and 'key only' or 'key rejected');return ok
        end
        r.warpStartedAt=env.clock()
        local ok,err
        if r.preparedPosition then
            self.correctedCastPos=r.preparedPosition;ok,err=pcall(self.SetPosition,self,r.preparedPosition,'action')
        else ok,err=pcall(project,self) end
        if r.publicTarget then self.CastPos=r.publicTarget end
        self.ActionScreen=copy(self.correctedCastPos)
        r.actionScreen=copy(self.ActionScreen)
        if not ok or not self.PlacementAccepted or not near(env.screen(),self.ActionScreen) then
            if r.aimCandidates then return self:FailAim(r,'aim_position_mismatch') end
            self:release('position unconfirmed');return false
        end
        -- Placement has just been confirmed above. A duplicate native warp to
        -- the same pixel adds no evidence. Final validation and the full
        -- configured post-send hold still apply in both timing modes.
        if env.deferMoves and not r.ggCompatible and r.class=='move' and not r.prevalidateWorldMove then
            r.deferredMove=true;r.awaitingPosition=true;r.sendAfter=env.clock()+env.fallback()
            self.Timer=r.budgetEnd-r.hold
            self:record('position_requested',r);return true
        end
        if r.aimCandidates then return self:TryAim(r) end
        if r.verifyTarget then
            if not self:VerifyHover(r) then
                r.awaitingPosition=true;r.sendAfter=env.clock();self.Timer=r.budgetEnd-r.hold
                self:record('hover_wait',r);return true
            end
        end
        if r.resolveWorldTarget then
            r.positionPasses=1;r.confirmAfterPass=self.ResolutionPass
            r.awaitingPosition=true;r.sendAfter=env.clock();self.Timer=r.budgetEnd-r.hold
            if self:WorldPlacementConfirmed(r) then return self:SendPositioned(r,true) end
            return true
        end
        return self:SendPositioned(r)
    end
    function cursor:SendPositioned(r,placementFresh)
        -- PollPlacement already resolved, validated and projected this action in
        -- this call. Repeating that work lengthens the cursor lease and creates
        -- more opportunity for camera/mouse drift. StepPressKey still performs
        -- the final gameplay and cursor checks immediately before sending.
        if r.resolveWorldTarget and not placementFresh and not self:RefreshWorldPlacement(r) then return self.Active==r end
        r.awaitingPosition=nil;r.positionedAt=env.clock()
        if self.DiagnosticsEnabled~=false and not r.prevalidatedWorld then r.screenAtSend=copy(env.screen());r.worldAtSend=copy(env.world()) end
        local pressed,result=pcall(self.StepPressKey,self)
        if self.Active~=r then return false end
        if r.sentAt then
            r.holdUntil=(r.sendCompletedAt or env.clock())+r.hold
            self.Timing:observePreparation(r,r.sentAt,false)
        end
        if not pressed or not result then
            if not r.sentAt then
                if r.reason=='cursor_changed_before_send' and r.resolveWorldTarget then
                    -- Pointer motion can occur inside the final gameplay
                    -- validator. Give opted-in world intents the same bounded
                    -- correction as motion sampled between callbacks. No new
                    -- action, deadline, hold reduction or keypress is created.
                    r.awaitingPosition=true
                    if self:CanCorrectWorldDrift(r,env.screen()) then
                        r.pointerCorrectionPending=true;r.reason=nil
                        r.sendAfter=env.clock();self.Timer=r.budgetEnd-r.hold
                        self:record('world_pointer_correction_pending',r,'Final validation drift; reconfirm within original budget')
                        -- Correct within this dispatch rather than yielding into
                        -- another physical-motion callback. Refresh keeps the
                        -- same resolver revision in this scheduler pass, checks
                        -- gameplay again, and counts every positioning attempt.
                        -- A second final validation still runs after the warp.
                        if self:RefreshWorldPlacement(r) then return self:SendPositioned(r,true) end
                        return self.Active==r
                    end
                    r.awaitingPosition=nil
                end
                if (r.aimCandidates or r.onAimFailure) and r.reason then
                    if r.reason:find('hover_',1,true) then return self:FailAim(r,r.reason) end
                    if r.reason=='Insufficient positioning budget for full hold' then return self:FailAim(r,'aim_budget_exhausted') end
                end
                self:release(r.reason or 'input rejected or uncertain')
            else r.submissionFailed=true;self.Timer=r.holdUntil;self:record('submission_uncertain',r,tostring(result)) end
            return false
        end
        self.Timer=r.holdUntil or env.clock()+r.hold
        self:record(r.sentAt and 'sent' or 'cursor_aimed',r)
        return true
    end
    function cursor:PollPlacement(r)
        if r.resolveWorldTarget and not self:RefreshWorldPlacement(r) then return end
        if r.aimCandidates then return self:TryAim(r) end
        if not r.resolveWorldTarget and not self:valid(r) then self:release('placement cancelled or expired');return end
        local now=env.clock()
        local screenOK=near(env.screen(),r.actionScreen)
        -- Prefer fresh host evidence when available; a stale global mousePos
        -- must not override a confirmed placement (nor override its rejection).
        local worldOK=true
        if r.space=='world' then
            if r.resolveWorldTarget and type(env.liveWorld)=='function' then worldOK=self:WorldPlacementConfirmed(r)
            else worldOK=worldDistance(env.world(),r.world)<=75 end
        end
        if r.verifyTarget then
            worldOK=self:VerifyHover(r)
        end
        if screenOK and worldOK and now>=r.sendAfter then
            self:SendPositioned(r,true)
        elseif now>=self.Timer then
            if r.onAimFailure then return self:FailAim(r,'aim_budget_exhausted') end
            self:record('position_unconfirmed',r,'cursor/world target did not settle; no click sent')
            self:release('position unconfirmed; no click sent')
        end
    end
    function cursor:Add(key,target)
        if self.Resolving then return false end
        local intent=self.NextIntent or {}
        local compatible=false
        if self.Active then
            compatible=#self.Active.keys==0 and not self.Active.leftClicks and (type(key)~='table' or #key>0)
            -- Compatibility callers must explicitly identify and validate a dependency.
            if key~=env.moveKey and intent.dependency==self.Active.id and type(intent.validate)=='function' then compatible=true end
        end
        local predecessor=self.Active
        local chain=predecessor and intent.dependency==predecessor.id and intent.owner==predecessor.owner
            and type(intent.validate)=='function' and compatible and (predecessor.chainDepth or 0)<1 and not predecessor.followup
        if (self.Step>0 or self.Active) and not chain or not chain and env.clock()<self.NotBefore then return false end
        local rootAt,chainDepth
        if chain then rootAt=predecessor.rootAt;chainDepth=(predecessor.chainDepth or 0)+1 end
        local ordinary=key==env.moveKey and not intent.critical
        local request={owner=intent.owner or (ordinary and 'orbwalker' or 'control'),keys=key,target=target,publicTarget=target,
            validate=intent.validate,verifyTarget=intent.verifyTarget,leftClicks=intent.leftClicks,
            critical=not ordinary,class=ordinary and 'move' or 'cast',world=intent.world,
            expires=intent.expires,priority=intent.priority}
        local r=self:newAction(request);r.rootAt=rootAt;r.chainDepth=chainDepth or 0
        if chain then
            r.returnTarget=copy(predecessor.returnTarget or predecessor.playerScreen);r.budgetEnd=predecessor.budgetEnd
            r.predecessorID=predecessor.id;r.handoffStatus='preparing'
        end
        local ok,result=pcall(self.dispatch,self,r,chain and predecessor or nil)
        if not ok or not result then
            r.state=r.sentAt and r.state or 'aborted';r.abortedAt=not r.sentAt and env.clock() or nil
            r.reason=r.reason or (not ok and tostring(result) or 'handoff or dispatch preparation rejected')
            self:record('aborted',r,r.reason)
            if self.Active==r and not ok then self:release('dispatch exception')
            elseif chain and self.Active==predecessor then
                predecessor.followup=nil;predecessor.handoffStatus='preparation rejected'
                if not predecessor.holdUntil or env.clock()>=predecessor.holdUntil then self:release('handoff preparation rejected') end
            end
        end
        self.LastActionID=r.id
        return ok and result==true
    end
    function cursor:DispatchRecord(r,key,target)
        if self.Step>0 or self.Active or env.clock()<self.NotBefore then return false end
        r.keys={key};r.target=target;r.targetID=target and (target.networkID or target.handle)
        return self:dispatch(r)
    end
    function cursor:MoveAtCursor()
        -- Only the no-argument Control.Move path uses this. Explicit world
        -- targets, attacks and plugin movement retain positioned dispatch.
        if self.Resolving or self.Step>0 or self.Active or self.PendingReturn
            or self.Uncertain or env.clock()<self.NotBefore or not self:Available() then return false end
        self:SamplePlayer()
        if self.Step>0 or self.Active or self.PendingReturn or self.Uncertain then return false end
        local p=copy(env.screen());local world=copy(env.world())
        if not p or not world or not near(p,self.PlayerScreen) then return false end
        local bounds=env.resolution and env.resolution()
        if not finite(p.x) or not finite(p.y) or bounds and (p.x<0 or p.y<0 or p.x>=bounds.x or p.y>=bounds.y) then return false end
        local r=self:newAction({owner='orbwalker',keys={env.moveKey},target=world,critical=false,class='move'})
        r.pointerMove=true;r.publicType='move';r.hold=0;r.ggCompatible=false
        r.rootAt=env.clock();r.budgetEnd=r.expires;r.acquiredAt=r.rootAt
        r.playerScreen=copy(p);r.playerWorld=copy(world);r.actionScreen=copy(p)
        r.beforePath=copy(env.hero.pathing and env.hero.pathing.endPos);r.origin=copy(env.hero.pos)
        self.Active=r;self.Step=1;self.ActionScreen=copy(p);self.correctedCastPos=copy(p)
        local ok=self:SendPositioned(r,true)
        if self.Active==r then self:release(ok and 'current_cursor_click_complete' or r.reason or 'current_cursor_click_uncertain') end
        self.LastActionID=r.id
        return ok
    end
    function cursor:release(reason)
        local r=self.Active;if not r then return end
        if r.followup then
            r.followup.state='aborted';r.followup.reason=reason;r.followup.abortedAt=env.clock()
            self:record('aborted',r.followup,reason);r.followup=nil
        end
        self.Active=nil;self.ActionScreen=nil
        self:CleanupButtons(false,r.owner)
        r.reason=reason
        if not r.sentAt then r.state='aborted';r.abortedAt=env.clock() end
        if r.pointerMove then
            -- There was no warp, therefore no return or positioning hold exists.
            -- Failed mouse-up stays owned in Buttons for bounded cleanup.
            r.releasedAt=env.clock();self.Step=0;self.ForceTCOUp=false
            self.NotBefore=env.clock();self.Timer=self.NotBefore
            self:record('released',r,reason);return
        end
        for key,owner in pairs(self.KeysOwned) do if owner==r.owner then self:ReleaseKey(key,owner) end end
        r.returnRequestedAt=env.clock()
        r.returnTarget=copy(r.returnTarget or self.PlayerScreen);r.returnBefore=copy(env.screen());r.returnGeneration=self.Generation
        self.LastReturnAt=r.returnRequestedAt
        r.returnAccepted=self:SetPosition(r.returnTarget,'return',r);r.returnSample=copy(env.screen())
        r.releasedAt=env.clock()
        if near(r.returnSample,r.returnTarget) then r.returnObservedAt=env.clock()
        else
            self.PendingReturn=r;self.Uncertain=true
            if not near(r.returnBefore,r.returnTarget) then self.UntrustedScreen=copy(r.returnBefore) end
        end
        if r.actionScreen and screenDistance(r.actionScreen,r.returnTarget)>256 then
            self.ReturnGuard={at=env.clock(),generation=self.Generation,action=copy(r.actionScreen),
                actionRecord=r,previous=copy(r.returnTarget),
                -- Mouse motion can displace a delayed warp after the return was
                -- sampled. Exact-pixel/24px matching promoted that displaced
                -- cast cursor into player aim (live Q -> move at 29:46).
                -- This guard only acts on a >256px discontinuity within 250ms;
                -- smooth intentional traversal and new physical commands win.
                radius=128}
        end
        self.Step=3;self.ForceTCOUp=false
        -- Keep second wait as player-owned time until comparison tests validate removal.
        self.NotBefore=env.clock()+(self.Timing.removeSecondWait and math.max(1,self.Timing:reserve()) or env.fallback())
        self.Timer=self.NotBefore;self:record('released',r,reason)
    end
    function cursor:Cancel(owner,reason)
        self:CleanupButtons(false,owner)
        for i=#self.Queue,1,-1 do
            local r=self.Queue[i]
            if not owner or r.owner==owner then
                table.remove(self.Queue,i);r.state='aborted';r.reason=reason;r.abortedAt=env.clock();self:record('aborted',r,reason)
            end
        end
        if self.Active and (not owner or self.Active.owner==owner) then
            self.Active.interrupted=true;self:release(reason or 'cancelled')
        end
        -- An explicit cancellation gets one last owned release even if automatic
        -- retries exhausted; it must still be possible to recover after host input
        -- becomes available again. Regular Prepare/OnTick calls stay bounded.
        for key,who in pairs(self.KeysOwned) do if not owner or who==owner then self:ReleaseKey(key,who,nil,nil,true) end end
    end
    function cursor:CancelAll(reason,pointerOnly,movementOnly)
        local previousGeneration=self.Generation;local active=self.Active
        local resume=active and not active.sentAt and active.publicScope
            and (pointerOnly and active.survivePointerMotion or movementOnly and active.surviveMovementCommands)
            and active.generation==previousGeneration
        self.Generation=self.Generation+1;self.Metrics.interruptions=self.Metrics.interruptions+1
        if env.cancelPending then env.cancelPending() end
        if self.Active and (reason=='manual input or unassignable delayed echo' or reason=='ambiguous mouse movement') then
            self.Active.manualAt=env.clock()
        end
        for _,id in ipairs(self.Recent) do
            local r=self.Records[id];if r and r.sentAt and not r.observedAt and not r.timedOut then r.interrupted=true end
        end
        self:Cancel(nil,reason)
        if resume and self.Automation then self.Automation:ResumeUnsentMotion(active) end
        if pointerOnly or movementOnly then
            -- Opted-in, independent public casts have not acquired the cursor
            -- yet. Aiming motion or an explicitly permitted movement command
            -- may release the previous action without destroying these intentions.
            -- They still wait for a trusted
            -- cursor and pass full gameplay validation before a new acquisition.
            for _,id in ipairs(self.Recent) do
                local r=self.Records[id]
                if r and r~=active and (pointerOnly and r.survivePointerMotion or movementOnly and r.surviveMovementCommands)
                    and r.publicScope and not r.sentAt
                    and r.state~='aborted' and r.generation==previousGeneration then
                    r.generation=self.Generation;self:record('waiting_preserved',r,
                        movementOnly and 'movement command; revalidation required' or 'pointer motion; revalidation required')
                end
            end
        end
        self:record('cancel_all',nil,reason)
    end
    function cursor:Shutdown() self:CancelAll('reload or shutdown');self.Stopped=true end
    function cursor:RegisterObservationSource(name,validated)
        self.Sources[name]=validated==true
        if name=='movement' then self.Timing.validatedMoves=validated==true end
    end
    function cursor:ObserveMovement(r)
        local endpoint=env.hero.pathing and env.hero.pathing.endPos
        local function dist2(a,b)
            if not a or not b or not finite(a.z) or not finite(b.z) then return math.huge end
            return (a.x-b.x)^2+(a.z-b.z)^2
        end
        if r.class~='move' or r.pathObserved or not endpoint or not r.beforePath or not r.world
            or not r.origin or not finite(r.world.z) or not finite(r.origin.z)
            or dist2(endpoint,r.beforePath)<=25 then return end
        if env.strictMovement then
            if env.hero.pathing.isDashing or r.competitor or r.interrupted then return end
            if not r.endpointCandidate or worldDistance(r.endpointCandidate,endpoint)>5 then
                r.endpointCandidate=copy(endpoint);r.endpointCandidateAt=env.clock();return
            end
            if env.clock()<=r.endpointCandidateAt then return end
        end
        r.pathObserved=true;r.observedEndpoint=copy(endpoint);r.pathObservedAt=env.clock()
        r.expectedError=worldDistance(endpoint,r.world);r.playerError=worldDistance(endpoint,r.playerWorld)
        local result=dist2(endpoint,r.world)<=2500 and 'confirmed' or 'misdirected'
        -- Terrain clamping and other endpoint changes are not proven misdirection.
        if env.strictMovement and result=='misdirected' and not (r.playerError<=75 and r.expectedError>250) then result='unknown' end
        r.pathResult=result
        local dx=r.world.x-r.origin.x;local dz=r.world.z-r.origin.z
        local direction=math.floor(((math.atan2(dz,dx)+math.pi)/(2*math.pi))*8)%8
        if not self:Observe(r.id,{actionID=r.id,source='movement',result=result,
            unique=not r.competitor and not r.interrupted,direction=direction}) then
            self:record('movement_candidate',r,'unvalidated or ambiguous path observation: '..result)
        end
    end
    function cursor:Observe(id,evidence)
        local r=self.Records[id]
        if not r or not r.sentAt or r.observedAt or not evidence or evidence.actionID~=id then return false end
        local proven=self.Sources[evidence.source] and evidence.unique==true and not r.interrupted and not r.competitor
        if not proven or evidence.result=='unknown' then return false end
        r.observedAt=env.clock();r.observation=evidence.result;r.state='observed'
        evidence.sourceValidated=true
        self.Timing:observe(r,evidence);self:record('observed',r)
        if evidence.result=='confirmed' then r.state='completed';r.completedAt=env.clock()
        elseif evidence.result=='misdirected' then
            self.Metrics.misdirected=self.Metrics.misdirected+1;self:CancelAll('confirmed misdirection')
        end
        self:record(r.state,r);return true
    end
    function cursor:OnInput(msg,param)
        self.LastInputSynthetic=(self.InFlight or 0)>0
        local keyDown=msg==256 or msg==260
        local keyUp=msg==257 or msg==261
        local mouseDown=msg==513 or msg==516 or msg==519 or msg==523
        local mouseUp=msg==514 or msg==517 or msg==520 or msg==524
        if keyDown or keyUp or mouseDown or mouseUp then
            self.LastInputEdge={message=msg,param=param,at=env.clock(),classification=self.LastInputSynthetic and 'host call' or 'unmatched'}
        end
        if (keyDown or keyUp) and self:MatchKeyEcho(param,keyDown) then
            self.LastInputEdge.classification='expected key echo'
            if not self.LastInputSynthetic then self:record('key_echo_inferred',nil,tostring(param)) end
            self.LastInputSynthetic=true;return
        end
        local mouseVK=(msg==513 or msg==514) and 1 or (msg==516 or msg==517) and 2 or 4
        if (mouseDown or mouseUp) and self:MatchKeyEcho(mouseVK,mouseDown,true) then
            self.LastInputEdge.classification='expected mouse echo'
            if not self.LastInputSynthetic then self:record('mouse_echo_inferred',self.Active,tostring(msg)) end
            self.LastInputSynthetic=true;return
        end
        if self.LastInputSynthetic then return end
        if msg==512 then self:SamplePlayer();return end
        local down=msg==256 or msg==260
        local up=msg==257 or msg==261
        local freshPress=false
        if down or up then
            local key=canonicalKey[param] or param
            if self.PhysicalReview and self.PhysicalReview[key]~=nil then self.PhysicalReview[key]=false end
            if down then self:AdvanceCommand(key) end
            freshPress=down and not self.Physical[key]
            self.Physical[key]=down or nil
            if down then
                self.PhysicalReview=self.PhysicalReview or {};self.PhysicalReview[key]=false
            end
            if key==(canonicalKey[env.tco] or env.tco) then self.TCORecovery=nil end
        elseif mouseDown or mouseUp then
            local vk=(msg==513 or msg==514) and 1 or (msg==516 or msg==517) and 2 or 4
            freshPress=mouseDown and not self.Physical[vk]
            self.Physical[vk]=mouseDown or nil
            if self.Buttons[vk] then
                if mouseDown then self.Buttons[vk].manual=true;self:record('button_physical_takeover',self.Buttons[vk].action,tostring(vk))
                elseif mouseUp then self.Buttons[vk].manual=nil end
            end
        end
        if freshPress then
            if down and safe(env.focus) and (param==13 or param==27) then
                self.ChatLatched=param==13 and not self:IsChatOpen() or false
                self:record('chat_guard',nil,self.ChatLatched and 'physical Enter opened editor' or 'physical editor dismissal',
                    {chatLatched=self.ChatLatched,nativeChat=env.chat and safe(env.chat)==true or false})
            end
            self.LastInputEdge.classification='new manual press or unmatched echo'
            for _,id in ipairs(self.Recent) do local r=self.Records[id];if r and r.sentAt and not r.observedAt then r.interrupted=true end end
            self:CancelAll('manual input or unassignable delayed echo',false,msg==516)
        elseif up or mouseUp then
            -- A toggle's release and duplicate host releases are not new commands.
            -- LHO still receives the event to finish its release-triggered assists.
            self.LastInputEdge.classification='release; no new command'
            self:record('input_release',self.Active)
        end
    end
    function cursor:StepSetToCursorPos() self:release('compatibility release') end
    function cursor:StepWaitForResponse()
        if self.Active and self.Active.ggCompatible then
            if env.clock()>self.Timer then self.Step=2;self:record('hold_finished',self.Active) end
        elseif env.clock()>=self.Timer then self:release('hold deadline; result unknown') end
    end
    function cursor:StepWaitForReady() if env.clock()>=self.NotBefore then self.Step=0 end end
    function cursor:OnTick()
        self.TickSerial=self.TickSerial+1;self:CleanupButtons(true)
        local now=env.clock()
        self.Timing:tick(now)
        self:PruneKeyEchoes()
        for key,pending in pairs(self.PendingUp) do
            if not safe(env.isDown,key) then
                self.PendingUp[key]=nil
                if self.KeyLeases and self.KeyLeases[key]==pending.lease then
                    self.KeysOwned[key]=nil;self.KeyLeases[key]=nil
                end
            elseif pending.attempts<3 then
                self:ReleaseKey(key,pending.owner,nil,pending.lease)
            end
        end
        if not self:Available() then
            if not self.Suspended then self:CancelAll('focus, chat, death or disabled') end
            self.PhysicalReview={};self.PhysicalPollAt=nil
            for key in pairs(self.Physical) do self.PhysicalReview[key]=false end
            self.Suspended=true;return
        end
        self.Suspended=false;self:ReconcilePhysical();self:SamplePlayer()
        if self.Active and self.Active.followup and not self.Active.followup.publicScope and env.clock()>=(self.Active.holdUntil or 0) then
            local previous=self.Active;local nextAction=previous.followup;previous.followup=nil
            local ok,accepted=pcall(self.dispatch,self,nextAction,previous)
            if not ok or not accepted then
                nextAction.state=nextAction.sentAt and nextAction.state or 'aborted';nextAction.reason='deferred handoff rejected'
                self:record('aborted',nextAction,nextAction.reason)
                if self.Active==previous or self.Active==nextAction and not nextAction.sentAt then self:release(nextAction.reason) end
            end
        end
        if self.Active and self.Active.awaitingPosition and not self.Active.publicScope then self:PollPlacement(self.Active) end
        if self.Active and not self.Active.awaitingPosition and not (self.Active.followup and self.Active.followup.publicScope) then
            if self.Active.ggCompatible then
                -- GG observes the wait deadline in Step 1 and restores on the
                -- following Tick in Step 2. Never collapse these into one call.
                if self.Step==2 then self:release('GG response phase complete; see separate observation')
                elseif now>self.Timer then self.Step=2;self:record('hold_finished',self.Active) end
            elseif now>=self.Timer then self:release('hold deadline; see separate observation') end
        end
        if self.Step==3 and now>=self.NotBefore then self.Step=0 end
        for _,id in ipairs(self.Recent) do
            local r=self.Records[id]
            if r and r.sentAt and not r.observedAt and not r.timedOut then self:ObserveMovement(r) end
            if r and r.sentAt and not r.observedAt and not r.timedOut and now-r.sentAt>750 then
                r.timedOut=true;r.observation='unknown';self.Metrics.unknown=self.Metrics.unknown+1
                self.Timing:observe(r,nil);self:record('unknown',r)
            end
        end
        if self.Step==0 and not self.Active and now>=self.NotBefore then
            if #self.Queue>0 then self:dispatch(table.remove(self.Queue,1)) else self:StepReady() end
        end
    end
    if env.strictMovement then cursor:RegisterObservationSource('movement',true) end
    return cursor
end
