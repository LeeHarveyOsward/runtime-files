local G=require('evade.geometry')
local D=require('evade.damage')
local P={};P.__index=P
function P.new(terrain,threats)
    return setmetatable({terrain=terrain,threats=threats,maxCandidates=64,maxNodes=512,horizon=2,query={}},P)
end
local function unknown(why)return {safe=false,known=false,reason=why,damage=0,unknown=true,lethal=false,cc=0,hits={}}end
function P:Evaluate(path,ctx,defense)
    if type(path)~='table'or #path==0 or #path>64 or not G.point(ctx.origin)
        or not G.finite(ctx.now)or not G.finite(ctx.speed)or ctx.speed<=0
        or not G.finite(ctx.radius)or ctx.radius<0 then return unknown('invalid_path_context')end
    if self.threats.overflow then return unknown('threat_capacity')end
    local budget=ctx.sharedBudget or {remaining=ctx.workBudget or 12000};local began=budget.remaining;local hits,seen={},{}
    local from,t=ctx.origin,ctx.now;local finish=ctx.now+(ctx.horizon or self.horizon)
    local function segment(a,b,t0,t1,walking)
        if walking then local ok,why=self.terrain:Segment(a,b,ctx.radius,t0,t1,budget);if ok~=true then return false,why end end
        for _,s in ipairs(self.threats:Query(a,b,t0,t1,ctx.radius,self.query))do
            if not seen[s.damageID or s.id]then
                local hit,at
                if s.shape=='targeted'then hit=s.targetID==ctx.heroID;at=math.max(t0,s.starts)
                else hit,at=G.sweep(s,a,b,t0,t1,ctx.radius,budget)end
                if hit==nil then return false,at end
                if hit then
                    seen[s.damageID or s.id]=true
                    hits[#hits+1]={id=s.id,damageID=s.damageID,at=at,damage=s.damage,cc=s.cc,
                        blockable=s.blockable,externalCounted=s.externalCounted,alreadyApplied=s.alreadyApplied}
                end
            end
        end
        return true
    end
    local delay=ctx.delay or 0
    if not G.finite(delay)or delay<0 then return unknown('invalid_delay')end
    local ok,why=segment(from,from,t,math.min(finish,t+delay),false)
    if not ok then return unknown(why)end;t=t+delay
    for _,point in ipairs(path)do
        if not G.point(point)then return unknown('invalid_endpoint')end
        local dt=G.dist(from,point)/ctx.speed
        if t+dt>finish then return unknown('route_exceeds_horizon')end
        ok,why=segment(from,point,t,t+dt,true);if not ok then return unknown(why)end
        from,t=point,t+dt
    end
    ok,why=segment(from,from,t,finish,false);if not ok then return unknown(why)end
    -- A persistent zone that activates after arrival still makes the destination
    -- unsuitable. Do not assume leaving it without a subsequently issued route.
    for _,s in ipairs(self.threats.list)do if s.persistent and s.starts>finish then
        local d=G.distance(s,from,s.starts)
        if d==nil then return unknown('persistent_geometry_unknown')end
        if d<=ctx.radius then return unknown('future_persistent_zone')end
    end end
    local result=D.forecast(hits,ctx.stats or {},defense)
    result.known=true;result.safe=#hits==0 or #result.hits==0 and not result.unknown;result.arrival=t;result.position=G.copy(from)
    result.work=began-budget.remaining;result.threatRevision=self.threats.revision
    result.terrainRevision=self.terrain.revision;result.reason=result.safe and 'clear' or 'threat_intersection'
    result.firstImpact=math.huge;for _,hit in ipairs(hits)do result.firstImpact=math.min(result.firstImpact,hit.at)end
    result.path={};for _,p in ipairs(path)do result.path[#result.path+1]=G.copy(p)end
    result.danger=0
    if ctx.destinationDanger then
        local good,value=pcall(ctx.destinationDanger,from,t)
        if not good or not G.finite(value)or value<0 then return unknown('destination_danger_unknown')end
        result.danger=value
    end
    return result
end
local function cost(r,ctx)
    return {r.lethal and 1 or 0,r.unknown and #r.hits or 0,r.damage+(r.danger or 0),r.cc or 0,
        r.resourceCost or 0,(r.arrival or ctx.now)-ctx.now,
        r.position and G.dist(r.position,ctx.intent or ctx.origin)or math.huge}
end
function P:Better(a,b,ctx)
    if not a or not a.known then return false end;if not b or not b.known then return true end
    local x,y=cost(a,ctx),cost(b,ctx)
    for i=1,#x do if math.abs(x[i]-y[i])>.0001 then return x[i]<y[i]end end
    return false
end
local function push(heap,n)
    local i=#heap+1;while i>1 do local p=math.floor(i/2);if heap[p].f<=n.f then break end;heap[i]=heap[p];i=p end;heap[i]=n
end
local function pop(heap)
    local a,last=heap[1],table.remove(heap);if #heap>0 then
        local i=1;while i*2<=#heap do local c=i*2;if c<#heap and heap[c+1].f<heap[c].f then c=c+1 end
            if heap[c].f>=last.f then break end;heap[i]=heap[c];i=c end;heap[i]=last
    end;return a
end
function P:Plan(ctx,previous)
    local original=ctx;ctx={};for k,v in pairs(original)do ctx[k]=v end
    ctx.sharedBudget={remaining=ctx.cycleBudget or 64000}
    local clock=ctx.budgetClock;local deadline=clock and clock()+(ctx.decisionBudgetMs or 4)
    local function timeRemaining()return not deadline or clock()<deadline end
    local length=math.max(0,ctx.speed*(self.horizon-(ctx.delay or 0))*.8)
    local intent=G.point(ctx.intent)and ctx.intent or ctx.origin
    if G.dist(ctx.origin,intent)>length then intent=G.lerp(ctx.origin,intent,length/G.dist(ctx.origin,intent))end
    local baseline=self:Evaluate({intent},ctx);local idle=self:Evaluate({ctx.origin},ctx)
    local best=baseline.known and baseline or idle.known and idle or nil;local count=2
    if self:Better(idle,best,ctx)then best=idle end
    if baseline.safe then baseline.candidates=count;baseline.nodes=0;return baseline,baseline end
    local function consider(path)
        if count>=self.maxCandidates or ctx.sharedBudget.remaining<=0 or not timeRemaining()then return end;count=count+1
        local r=self:Evaluate(path,ctx);if self:Better(r,best,ctx)then best=r end;return r
    end
    if previous and previous.path then consider(previous.path)end
    local dx,dz=G.direction(ctx.origin,intent)
    for _,scale in ipairs({.22,.45,.75})do for i=0,15 do
        local a=i*math.pi/8;local x,z=dx*math.cos(a)-dz*math.sin(a),dz*math.cos(a)+dx*math.sin(a)
        consider({{x=ctx.origin.x+x*length*scale,y=ctx.origin.y,z=ctx.origin.z+z*length*scale}})
    end end
    local expanded=0
    if not best or not best.safe then
        local step=self.terrain.grid and self.terrain.grid.cell or 50
        local heap,seen={{x=0,z=0,g=0,f=0}}, {['0:0']=0}
        while #heap>0 and expanded<self.maxNodes and count<self.maxCandidates and ctx.sharedBudget.remaining>0 and timeRemaining()do
            local n=pop(heap);expanded=expanded+1
            local p={x=ctx.origin.x+n.x*step,y=ctx.origin.y,z=ctx.origin.z+n.z*step}
            if n.g>0 then
                local d=math.huge;for _,s in ipairs(self.threats:Query(p,p,ctx.now,ctx.now+self.horizon,ctx.radius,self.query))do
                    local v=G.distance(s,p,ctx.now+n.g/ctx.speed);if v then d=math.min(d,v)end
                end
                if d>ctx.radius then
                    local reverse={};local q=n;while q.parent do reverse[#reverse+1]={x=ctx.origin.x+q.x*step,y=ctx.origin.y,z=ctx.origin.z+q.z*step};q=q.parent end
                    local path={};for j=#reverse,1,-1 do path[#path+1]=reverse[j]end
                    local result=consider(path);if result and result.safe then break end
                end
            end
            for x=-1,1 do for z=-1,1 do if x~=0 or z~=0 then
                local nx,nz=n.x+x,n.z+z;local key=nx..':'..nz
                local distance=n.g+step*((x~=0 and z~=0)and 1.4142135623731 or 1)
                if distance<=length and (not seen[key]or distance<seen[key])then
                    local point={x=ctx.origin.x+nx*step,y=ctx.origin.y,z=ctx.origin.z+nz*step}
                    local free=self.terrain:Segment(p,point,ctx.radius,ctx.now+n.g/ctx.speed,ctx.now+distance/ctx.speed,ctx.sharedBudget)
                    if free==true then seen[key]=distance;push(heap,{x=nx,z=nz,g=distance,f=distance+G.dist(point,intent)*.1,parent=n})end
                end
            end end end
        end
    end
    if best then best.candidates=count;best.nodes=expanded;best.work=math.min(ctx.cycleBudget or 64000,(ctx.cycleBudget or 64000)-ctx.sharedBudget.remaining)
        best.exhausted=count>=self.maxCandidates or expanded>=self.maxNodes or ctx.sharedBudget.remaining<=0 or not timeRemaining()end
    return best,baseline
end
return P
