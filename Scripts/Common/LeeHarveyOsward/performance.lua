-- Measures only this controller. Inclusive/self elapsed time is not CPU usage
-- attribution for other scripts or native work outside these calls.
local U=require('lho.util')
local F={};F.__index=F
function F.new(ctx) return setmetatable({ctx=ctx,stack={},rows={},pool={},cadence={}},F) end
function F:begin(name)
    if not self.ctx.config:get('performanceLogging') or type(GetTickCount)~='function' then return end
    -- Preview planners yield across frames. Measure each caller's resume work,
    -- never count the suspended interval as controller execution time.
    local thread,isMain=coroutine.running();if thread and not isMain then return end
    local at=GetTickCount();if not U.finite(at) then return end
    local depth=#self.stack+1;local token=self.pool[depth] or {};self.pool[depth]=token
    token.name=name;token.at=at;token.children=0;token.depth=depth;self.stack[depth]=token
    return token
end
function F:finish(token,...)
    if token then
        local elapsed=GetTickCount()-token.at
        if elapsed<0 then elapsed=elapsed+4294967296 end
        if U.finite(elapsed) and elapsed>=0 then
            local row=self.rows[token.name] or {calls=0,totalMs=0,selfMs=0,maxMs=0,over16ms=0,over50ms=0,over100ms=0}
            self.rows[token.name]=row;row.calls=row.calls+1;row.totalMs=row.totalMs+elapsed
            row.selfMs=row.selfMs+math.max(0,elapsed-token.children);row.maxMs=math.max(row.maxMs,elapsed)
            if elapsed>16 then row.over16ms=row.over16ms+1 end
            if elapsed>50 then row.over50ms=row.over50ms+1 end
            if elapsed>100 then row.over100ms=row.over100ms+1 end
            -- A nested method may throw and have its error handled internally.
            -- Remove unfinished descendants without corrupting the parent.
            for index=#self.stack,token.depth,-1 do self.stack[index]=nil end
            local parent=self.stack[#self.stack];if parent then parent.children=parent.children+elapsed end
        else self.stack={} end
    end
    return ...
end
function F:abort()
    local path={};for _,token in ipairs(self.stack) do path[#path+1]=token.name end
    self.stack={};return path
end
function F:wrap(object,name,methods)
    for _,method in ipairs(methods) do
        local original=object[method]
        if type(original)=='function' then
            local label=name..'.'..method
            object[method]=function(...)
                local token=self:begin(label)
                return self:finish(token,original(...))
            end
        end
    end
end
function F:pulse(name)
    if not self.ctx.config:get('performanceLogging') or type(GetTickCount)~='function' then return end
    local now=GetTickCount();local row=self.cadence[name]
    if not row then row={calls=0,totalGapMs=0,maxGapMs=0,over50ms=0};self.cadence[name]=row end
    row.calls=row.calls+1
    if row.last then
        local gap=math.max(0,now-row.last);row.totalGapMs=row.totalGapMs+gap;row.maxGapMs=math.max(row.maxGapMs,gap)
        if gap>50 then row.over50ms=row.over50ms+1 end
    end
    row.last=now
end
function F:flush()
    local now=self.ctx:now()
    if #self.stack>0 or now<(self.nextAt or 0) or not next(self.rows) then return end
    local rows=self.rows;self.rows={};self.nextAt=now+5
    local cadence=self.cadence;self.cadence={}
    local heapOK,heapKB=pcall(function()return collectgarbage('count')end)
    self.ctx:log('callback_performance',{interval=now-(self.lastAt or now),rows=rows,
        cadence=cadence,heapKB=heapOK and heapKB or nil,
        logger=self.ctx.logger and self.ctx.logger.ioMetrics,
        timer='GetTickCount; elapsed milliseconds, quantized',mode=self.ctx.mode})
    self.lastAt=now
end
function F:install(app)
    if not self.ctx.config:get('performanceLogging') then return end
    self:wrap(app,'app',{'tick','event','preAttack','preMove'})
    self:wrap(self.ctx,'runtime',{'refresh'})
    self.ctx.logger=self.ctx.logger or require('lho.logger').new(self.ctx)
    self:wrap(self.ctx.logger,'logger',{'record','flush','writeRecord','write'})
    self:wrap(self.ctx.combat.planner,'insec',{'plan','search','validate','adapt'})
    self:wrap(self.ctx.combat.tactics,'tactics',{'assess','model'})
    for component,methods in pairs({smite={'auto'},wards={'fastTick','tick','preview','releasePreview'},
        terrain={'landing','plan'},combat={'fight','insecTick','killsteal','multi'},
        farm={'fastTick','fastKite','tick','spawn','updateCamps','recovery','combatSafety','choose','selectTarget','retreat','routeDistance','travel','probeCamp','kite'},clear={'tick','observe','weaving','remainingHealth'},wave={'tick'},leveling={'tick'},
        telemetry={'safe'},overlay={'draw','damageBars'},actions={'tick','dispatchCursor','move','attack','cameraTrack'}}) do
        self:wrap(self.ctx[component],component,methods)
    end
end
return F
