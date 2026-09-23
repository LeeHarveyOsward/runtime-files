local Q={};Q.__index=Q
local function ring()return {rows={},head=1,count=0}end
local function pop(r)
    if r.count==0 then return end
    local value=r.rows[r.head];r.rows[r.head]=nil;r.head=r.head%256+1;r.count=r.count-1;return value
end
local function push(r,value)r.rows[(r.head+r.count-1)%256+1]=value;r.count=r.count+1 end
function Q.new()return setmetatable({high=ring(),low=ring(),count=0,dropped=0,serial=0,aggregated=0},Q)end
function Q:push(event,periodic)
    local last=self.last
    if last and last.queued and (event.kind=='cast_blocked' or event.kind=='smite_hover_blocked')
        and event.kind==last.event.kind and event.owner==last.event.owner and event.slot==last.event.slot
        and event.target==last.event.target and event.reason==last.event.reason then
        last.event.repeatCount=(last.event.repeatCount or 1)+1;last.event.lastTime=event.time
        self.aggregated=self.aggregated+1;return
    end
    if self.count==256 then
        self.dropped=self.dropped+1
        if periodic and self.low.count==0 then return end
        local removed=pop(self.low.count>0 and self.low or self.high);removed.queued=false;self.count=self.count-1
    end
    self.serial=self.serial+1;local row={event=event,serial=self.serial,queued=true}
    push(periodic and self.low or self.high,row);self.count=self.count+1;self.last=row
end
function Q:pop()
    local h,l=self.high.rows[self.high.head],self.low.rows[self.low.head]
    local source=h and (not l or h.serial<l.serial) and self.high or self.low
    local row=pop(source);if not row then return end
    row.queued=false;self.count=self.count-1;return row.event
end
return Q
