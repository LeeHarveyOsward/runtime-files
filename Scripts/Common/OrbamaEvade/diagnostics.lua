-- Fixed-size rings. Percentiles are calculated only on explicit snapshots.
local M={};M.__index=M
function M.new(clock)return setmetatable({clock=clock,metrics={},events={},index=0,enabled=false},M)end
function M:Sample(name,value)
    if type(value)~='number'or value~=value then return end
    local m=self.metrics[name];if not m then m={values={},index=0,total=0,count=0,max=0};self.metrics[name]=m end
    m.index=m.index%256+1;m.values[m.index]=value;m.total=m.total+value;m.count=m.count+1;m.max=math.max(m.max,value)
end
function M:Event(kind,reason,id)
    if not self.enabled then return end
    self.index=self.index%128+1;self.events[self.index]={at=self.clock(),kind=kind,reason=reason,id=id}
end
function M:Snapshot()
    local result={metrics={},events={},clock='monotonic milliseconds'}
    for name,m in pairs(self.metrics)do
        local v={};for i,x in ipairs(m.values)do v[i]=x end;table.sort(v)
        local function percentile(p)return v[math.max(1,math.ceil(#v*p))]end
        result.metrics[name]={count=m.count,total=m.total,max=m.max,p50=percentile(.5),p95=percentile(.95),p99=percentile(.99),window=#v}
    end
    for i=1,#self.events do local e=self.events[(self.index+i-1)%#self.events+1];result.events[i]={at=e.at,kind=e.kind,reason=e.reason,id=e.id}end
    return result
end
return M
