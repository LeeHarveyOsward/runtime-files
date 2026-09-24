-- Opt-in draw cadence and provider-owned cursor intervals. All input clocks are
-- monotonic milliseconds; neither callback cadence nor Game.FPS is relabeled as
-- a measured League render rate.
local T={};T.__index=T
function T.new(c)return setmetatable({c=c,spans={},frames=0,frameGaps={},ticks=0,lost=0},T)end
function T:enabled()return self.c.config:get('diagnostics')end
function T:draw()
    if not self:enabled()then self.lastDraw=nil;return end
    local now=GetTickCount();self.frames=self.frames+1
    if self.lastDraw then
        self.frameIndex=(self.frameIndex or 0)%256+1;self.frameGaps[self.frameIndex]=math.max(0,now-self.lastDraw)
    end
    self.lastDraw=now
    if type(Game.FPS)=='function' and now>=(self.nextFPS or 0)then
        self.nextFPS=now+100
        local ok,fps=pcall(Game.FPS)
        if ok and type(fps)=='number' and fps==fps and fps>0 and fps<10000 then
            self.fpsMin=math.min(self.fpsMin or fps,fps);self.fpsMax=math.max(self.fpsMax or fps,fps)
            self.fpsSum=(self.fpsSum or 0)+fps;self.fpsN=(self.fpsN or 0)+1
        end
    end
end
function T:tick()
    local c=self.c;local input=c.sdk.Input
    if not self:enabled()then self.window=nil;self.frames=0;self.frameGaps={};self.fpsN=0;self.lastDraw=nil;return end
    local now=GetTickCount()
    if not self.window then
        self.window=now;self.lastTick=now;self.sequence=input and input.Metrics and input.Metrics.sequence or 0
    end
    self.ticks=self.ticks+1;self.tickMax=math.max(self.tickMax or 0,now-self.lastTick);self.lastTick=now
    -- Drain at a report boundary too, otherwise a release in the last 100 ms
    -- can be omitted from this window and clipped out of the next one.
    if input and input.GetDiagnosticEvents and (now>=(self.nextInput or 0) or now-self.window>=1000)then
        self.nextInput=now+100
        local events,lost=input:GetDiagnosticEvents(self.sequence,64);self.lost=self.lost+(lost or 0)
        for _,e in ipairs(events)do
            self.sequence=math.max(self.sequence,e.sequence or 0)
            if (e.kind=='released' or e.kind=='dependent_handoff') and e.acquiredAt and e.releasedAt then
                if #self.spans<128 then self.spans[#self.spans+1]={e.acquiredAt,e.releasedAt}else self.lost=self.lost+1 end
                c:record('cursor_interval',{id=e.id,owner=e.owner,action=e.actionType,reason=e.reason,pointerMove=e.pointerMove,
                    requestedAt=e.requestedAt,acquiredAt=e.acquiredAt,positionedAt=e.positionedAt,
                    sentAt=e.sentAt,sendCompletedAt=e.sendCompletedAt,holdUntil=e.holdUntil,
                    returnRequestedAt=e.returnRequestedAt,returnObservedAt=e.returnObservedAt,releasedAt=e.releasedAt,
                    ownedMs=e.releasedAt-e.acquiredAt,requestedHold=e.hold,positionPasses=e.positionPasses})
            end
        end
    end
    if now-self.window<1000 then return end
    local duration=now-self.window;local owned=0;local ending=self.window
    -- Release records are chronological and one provider owns the cursor.
    for _,span in ipairs(self.spans)do
        local first=math.max(self.window,ending,span[1]);local last=math.min(now,span[2])
        if last>first then owned=owned+last-first;ending=last end
    end
    local active=input and input.Active
    if active and active.acquiredAt then owned=owned+math.max(0,now-math.max(self.window,ending,active.acquiredAt))end
    table.sort(self.frameGaps)
    local pending=input and input.Metrics and input.Metrics.sequence>self.sequence or false
    c:record('frame_performance',{windowMs=duration,drawCallbacks=self.frames,drawHz=self.frames*1000/duration,
        drawGapP95Ms=self.frameGaps[math.max(1,math.ceil(#self.frameGaps*.95))],drawGapMaxMs=self.frameGaps[#self.frameGaps],
        hostFPSMin=self.fpsMin,hostFPSMax=self.fpsMax,hostFPSMean=(self.fpsN or 0)>0 and self.fpsSum/self.fpsN or nil,
        hostFPSSource='Game.FPS',tickHz=self.ticks*1000/duration,tickGapMaxMs=self.tickMax,
        cursorOwnedMs=owned,cursorOwnedPct=100*owned/duration,cursorEventsLost=self.lost,cursorEventsPending=pending,
        pendingReturn=input and input.PendingReturn~=nil,clock='GetTickCount milliseconds; quantized',mode=c.state.mode})
    self.window=now;self.frames=0;self.frameGaps={};self.frameIndex=0;self.ticks=0;self.tickMax=0;self.spans={};self.lost=0
    self.fpsN=0;self.fpsSum=0;self.fpsMin=nil;self.fpsMax=nil
end
return T
