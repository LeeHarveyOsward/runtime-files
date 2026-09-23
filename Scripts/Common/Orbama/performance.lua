-- Opt-in exclusive subsystem timing. Nested host/input scopes are subtracted
-- from their parents. Fixed history, no file I/O and no busy waits.
return function(clock)
    local P={enabled=false,stack={},frames={},stats={},resolution='GetTickCount; callback quantization included'}
    local function pack(...)return {n=select('#',...),...}end
    function P:Call(name,fn,...)
        if not self.enabled then return fn(...) end
        local depth=#self.stack+1;local frame=self.frames[depth] or {};self.frames[depth]=frame
        frame.start=clock();frame.children=0;self.stack[depth]=frame
        local result=pack(pcall(fn,...));local elapsed=math.max(0,clock()-frame.start)
        self.stack[#self.stack]=nil
        local parent=self.stack[#self.stack];if parent then parent.children=parent.children+elapsed end
        local row=self.stats[name] or {calls=0,total=0,max=0,samples={},inclusiveTotal=0,inclusiveMax=0,inclusiveSamples={}}
        self.stats[name]=row;row.calls=row.calls+1
        local exclusive=math.max(0,elapsed-frame.children)
        row.total=row.total+exclusive;row.max=math.max(row.max,exclusive)
        local index=(row.sampleIndex or 0)%256+1;row.sampleIndex=index;row.samples[index]=exclusive
        row.inclusiveTotal=row.inclusiveTotal+elapsed;row.inclusiveMax=math.max(row.inclusiveMax,elapsed)
        row.inclusiveSamples[index]=elapsed
        if elapsed>50 then row.over50=(row.over50 or 0)+1 end
        if elapsed>100 then row.over100=(row.over100 or 0)+1 end
        if not result[1] then error(result[2],0) end
        return unpack(result,2,result.n)
    end
    function P:Wrap(object,method,name)
        local fn=object[method]
        object[method]=function(...)return self:Call(name,fn,...)end
    end
    function P:Snapshot()
        local out={resolution=self.resolution,enabled=self.enabled,subsystems={},
            semantics='total/max/quantiles are exclusive; inclusive includes nested scopes; never add inclusive rows'}
        for name,row in pairs(self.stats) do
            local samples={};for i,v in ipairs(row.samples) do samples[i]=v end;table.sort(samples)
            local function q(p)return samples[math.max(1,math.ceil(#samples*p))]end
            out.subsystems[name]={calls=row.calls,total=row.total,max=row.max,median=q(.5),p95=q(.95),p99=q(.99),
                over50=row.over50 or 0,over100=row.over100 or 0}
            samples={};for i,v in ipairs(row.inclusiveSamples) do samples[i]=v end;table.sort(samples)
            out.subsystems[name].inclusive={total=row.inclusiveTotal,max=row.inclusiveMax,median=q(.5),p95=q(.95),p99=q(.99)}
        end
        return out
    end
    function P:EmitMetrics(input)
        if not self.enabled or clock()<(self.nextReport or 0) then return end
        self.nextReport=clock()+2000
        for name,row in pairs(self:Snapshot().subsystems) do
            input:record('performance',nil,'Completed scopes; inclusive rows must not be added',{
                subsystem=name,profileCalls=row.calls,exclusiveTotal=row.total,exclusiveMax=row.max,
                exclusiveMedian=row.median,exclusiveP95=row.p95,exclusiveP99=row.p99,over50ms=row.over50,over100ms=row.over100,
                inclusiveTotal=row.inclusive.total,inclusiveMax=row.inclusive.max,
                inclusiveMedian=row.inclusive.median,inclusiveP95=row.inclusive.p95,inclusiveP99=row.inclusive.p99,
                resolution=self.resolution})
        end
    end
    return P
end
