-- Callback-clock measurements, never sub-millisecond claims or timeout learning.
local T={}; T.__index=T
local function statistics(self)
    if self.cachedRevision==self.sampleRevision then return self.cachedStats end
    local sorted={};for i=1,#self.gaps do sorted[i]=self.gaps[i] end
    table.sort(sorted)
    local function q(p)return sorted[math.max(1,math.ceil(#sorted*p))]end
    local median,p95,p99=q(.5),q(.95),q(.99)
    local result={median=median,p95=p95,p99=p99,quantum=math.max(1,median or 1),
        reserve=#sorted<3 and 0 or (p95 or 0)+math.max(0,(p95 or 0)-(median or 0))}
    self.cachedRevision=self.sampleRevision;self.cachedStats=result
    return result
end
function T.new(fallback)
    return setmetatable({fallback=fallback,enabled=false,validatedMoves=false,
        removeSecondWait=false,profiles={},gaps={},sampleRevision=0,lastTick=nil,
        resolution='GetTickCount units; effective resolution and callback jitter require live measurement'},T)
end
function T:tick(now)
    if type(now)~='number' or now~=now or math.abs(now)==math.huge or self.lastTick and now<self.lastTick then
        self.invalidTimes=(self.invalidTimes or 0)+1;return
    end
    if self.lastTick and now>self.lastTick then
        self.sampleRevision=self.sampleRevision+1
            local index=(self.gapIndex or 0)%128+1;self.gapIndex=index
            self.gaps[index]=now-self.lastTick
    end
    self.lastTick=now
end
function T:reserve()
    return statistics(self).reserve
end
-- A preparation allowance is a deadline, never a sleep or a claim that a spell
-- landed. Keep it separate from post-send hold calibration and absolute expiry.
function T:preparationBudget(hold)
    local stats=statistics(self)
    return math.min(300,math.max(120,hold*2,hold+3*(stats.p95 or 0),self.preparationFloor or 0))
end
function T:observePreparation(action,now,exhausted)
    if not action.resolveWorldTarget or not action.acquiredAt or action.preparationRecorded then return end
    local elapsed=now-action.acquiredAt
    if elapsed<0 or elapsed~=elapsed or elapsed==math.huge then return end
    action.preparationRecorded=true;action.preparationMs=elapsed
    local stats=statistics(self);local reserve=math.max(16,stats.p95 or 0)
    if exhausted then
        self.preparationExhausted=(self.preparationExhausted or 0)+1
        self.preparationFloor=math.min(300,math.max(self.preparationFloor or 120,elapsed+(action.hold or 30)+reserve))
        self.preparationSuccesses=0;self.preparationPeak=0
    else
        self.preparationSuccesses=(self.preparationSuccesses or 0)+1
        self.preparationPeak=math.max(self.preparationPeak or 0,elapsed)
        -- Reduce conservatively only after a full window of successful sends.
        if self.preparationSuccesses>=32 then
            self.preparationFloor=math.min(300,math.max(120,(self.preparationFloor or 120)-reserve,
                self.preparationPeak+(action.hold or 30)+reserve))
            self.preparationSuccesses=0;self.preparationPeak=0
        end
    end
end
function T:profile(class)
    if not self.profiles[class] then
        self.profiles[class]={reliable=self.fallback(),candidate=nil,samples=0,directions={},unknown=0,misdirected=0,
            baselineSamples=0,baselineDirections={},seen={},recent={}}
    end
    return self.profiles[class]
end
function T:hold(class,critical)
    local p=self:profile(class)
    if critical or class~='move' or not self.enabled or not self.validatedMoves then return self.fallback() end
    return math.max(p.candidate or p.reliable,self:reserve())
end
function T:beginTrial(class,value)
    local p=self:profile(class)
    if class~='move' or not self.enabled or not self.validatedMoves or #self.gaps<30
        or type(value)~='number' or value~=value or value<self:reserve() or value>=p.reliable
        or p.failedFloor and value<=p.failedFloor then return false end
    p.candidate=value;p.samples=0;p.directions={};return true
end
function T:observe(action,evidence)
    local previous
    for _,name in ipairs({'requestedAt','sentAt','sendCompletedAt','releasedAt'}) do
        local value=action[name]
        if value~=nil then
            if type(value)~='number' or value~=value or math.abs(value)==math.huge or previous and value<previous then
                self.invalidTimes=(self.invalidTimes or 0)+1;return
            end
            previous=value
        end
    end
    local p=self:profile(action.class)
    if not evidence or evidence.result=='unknown' then p.unknown=p.unknown+1;return end
    if action.interrupted or action.competitor or not evidence.unique or evidence.actionID~=action.id
        or not evidence.sourceValidated then p.unknown=p.unknown+1;return end
    if p.seen[action.id] then return end
    p.seen[action.id]=true;p.recent[#p.recent+1]=action.id
    if #p.recent>128 then p.seen[table.remove(p.recent,1)]=nil end
    if evidence.result=='misdirected' then
        p.misdirected=p.misdirected+1
        p.failedFloor=math.max(p.failedFloor or 0,action.hold or p.candidate or p.reliable)
        if not p.candidate then p.reliable=p.previousReliable or self.fallback() end
        p.candidate=nil;p.samples=0;p.directions={};p.baselineSamples=0;p.baselineDirections={};return
    end
    if evidence.result~='confirmed' or action.class~='move' or action.critical or not evidence.direction then return end
    if not p.candidate then
        if action.hold~=p.reliable then return end
        p.baselineSamples=p.baselineSamples+1;p.baselineDirections[evidence.direction]=true
        local count=0;for _ in pairs(p.baselineDirections) do count=count+1 end
        if p.baselineSamples>=30 and count>=3 then
            local quantum=statistics(self).quantum
            self:beginTrial('move',math.max(self:reserve(),p.reliable-quantum))
            p.baselineSamples=0;p.baselineDirections={}
        end
        return
    end
    if action.hold~=p.candidate then return end
    p.samples=p.samples+1;p.directions[evidence.direction]=true
    local count=0;for _ in pairs(p.directions) do count=count+1 end
    if p.samples>=30 and count>=3 then p.previousReliable=p.reliable;p.reliable=p.candidate;p.candidate=nil;p.samples=0;p.directions={} end
end
function T:summary()
    local profiles={}
    for class,p in pairs(self.profiles) do
        local dirs,base=0,0;for _ in pairs(p.directions) do dirs=dirs+1 end;for _ in pairs(p.baselineDirections) do base=base+1 end
        profiles[class]={reliable=p.reliable,candidate=p.candidate,previousReliable=p.previousReliable,
            failedFloor=p.failedFloor,
            samples=p.samples,directions=dirs,baselineSamples=p.baselineSamples,baselineDirections=base,
            unknown=p.unknown,misdirected=p.misdirected}
    end
    local stats=statistics(self)
    return {clock=self.resolution,invalidTimes=self.invalidTimes or 0,callbackMedian=stats.median,callbackP95=stats.p95,
        callbackP99=stats.p99,reserve=stats.reserve,validatedMoves=self.validatedMoves,
        enabled=self.enabled,profiles=profiles,preparationBudget=self:preparationBudget(self.fallback()),
        preparationFloor=self.preparationFloor,preparationExhausted=self.preparationExhausted or 0}
end
return T
