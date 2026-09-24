local G=require('evade.geometry')
local H={};H.__index=H
local function copy(t,depth)
    if type(t)~='table'then return t end
    if (depth or 0)>12 then error('excessive threat depth')end
    local o={};for k,v in pairs(t)do if type(v)~='function'and type(v)~='userdata'then o[k]=copy(v,(depth or 0)+1)end end;return o
end
function H.new()return setmetatable({byID={},list={},revision=0,serial=0,overflow=false,max=512},H)end
function H:Observe(event)
    if type(event)~='table'or not event.id or not event.casterID or not event.profile then return nil,'identity_required'end
    local valid,why=G.valid(event);if not valid then return nil,why end
    if event.evidence~='observed' and event.evidence~='cast-derived' then return nil,'observation_required'end
    local old=self.byID[event.id]
    if not old and #self.list>=self.max then self.overflow=true;self.overflowUntil=math.max(self.overflowUntil or 0,event.ends);return nil,'threat_capacity'end
    local row=copy(event);self.serial=self.serial+1;row.revision=self.serial
    if old then
        for i,v in ipairs(self.list)do if v==old then self.list[i]=row;break end end
    else self.list[#self.list+1]=row end
    self.byID[row.id]=row;self.revision=self.revision+1;return row.id
end
function H:Remove(id)
    local row=self.byID[id];if not row then return false end
    self.byID[id]=nil
    for i,v in ipairs(self.list)do if v==row then self.list[i]=self.list[#self.list];self.list[#self.list]=nil;break end end
    self.revision=self.revision+1;return true
end
function H:Expire(now)
    for i=#self.list,1,-1 do local v=self.list[i];if v.ends<now then self:Remove(v.id)end end
    if self.overflowUntil and now>self.overflowUntil and #self.list<self.max then self.overflow=false;self.overflowUntil=nil end
end
function H:Snapshot()
    local out={};for _,r in ipairs(self.list)do out[#out+1]=copy(r)end;return out
end
function H:Query(a,b,t0,t1,radius,out)
    out=out or {};for i=#out,1,-1 do out[i]=nil end
    if self.indexRevision~=self.revision then
        self.buckets={};self.global={}
        for _,s in ipairs(self.list)do
            local p,q=s.origin or s.a,s.b or s.origin or s.a
            local unbounded=s.shape=='targeted'or s.shape=='compound'or s.motion~=nil
            local r=(s.shape=='cone'and(s.length or G.dist(p,q))or s.shape=='arc'and s.arcRadius or 0)+(s.radius or 0)
            if not unbounded then
                local x0,x1=math.floor((math.min(p.x,q.x)-r)/512),math.floor((math.max(p.x,q.x)+r)/512)
                local z0,z1=math.floor((math.min(p.z,q.z)-r)/512),math.floor((math.max(p.z,q.z)+r)/512)
                if (x1-x0+1)*(z1-z0+1)<=128 then
                    for x=x0,x1 do for z=z0,z1 do local key=x..':'..z
                        local bucket=self.buckets[key]or {};self.buckets[key]=bucket;bucket[#bucket+1]=s
                    end end
                else unbounded=true end
            end
            if unbounded then self.global[#self.global+1]=s end
        end
        self.indexRevision=self.revision
    end
    local candidates,seen={},{}
    local function add(s)if not seen[s.id]then seen[s.id]=true;candidates[#candidates+1]=s end end
    for _,s in ipairs(self.global)do add(s)end
    local x0,x1=math.floor((math.min(a.x,b.x)-radius)/512),math.floor((math.max(a.x,b.x)+radius)/512)
    local z0,z1=math.floor((math.min(a.z,b.z)-radius)/512),math.floor((math.max(a.z,b.z)+radius)/512)
    if (x1-x0+1)*(z1-z0+1)>256 then for _,s in ipairs(self.list)do add(s)end
    else for x=x0,x1 do for z=z0,z1 do for _,s in ipairs(self.buckets[x..':'..z]or {})do add(s)end end end end
    for _,s in ipairs(candidates)do
        if s.ends>=t0 and s.starts<=t1 then
            local include=s.shape=='targeted'or s.shape=='compound'or s.motion~=nil
            if not include then
                local p,q=s.origin or s.a,s.b or s.origin or s.a
                local r=(s.shape=='cone' and (s.length or G.dist(p,q)) or s.shape=='arc'and s.arcRadius or 0)+(s.radius or 0)+radius
                include=math.min(a.x,b.x)<=math.max(p.x,q.x)+r and math.max(a.x,b.x)>=math.min(p.x,q.x)-r
                    and math.min(a.z,b.z)<=math.max(p.z,q.z)+r and math.max(a.z,b.z)>=math.min(p.z,q.z)-r
            end
            if include then out[#out+1]=s end
        end
    end
    return out
end
return H
