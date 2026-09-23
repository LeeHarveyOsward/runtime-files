return function(U,navdata)
local N={}
function N.provider(profile)
    local g=navdata[profile.id]
    if not g or Game.mapID~=g.mapID then return end
    local rows={}
    for z,row in ipairs(g.rows) do
        rows[z]={}
        for x=1,#row do rows[z][x]=tonumber(row:sub(x,x),16) end
    end
    local function isWall(p)
            if not p or not p.x or not p.z or p.x~=p.x or p.z~=p.z then return nil end
            if p.x<g.x or p.z<g.z or p.x>g.maxX or p.z>g.maxZ then return true end
            local x,z=math.floor((p.x-g.x)/g.cell),math.floor((p.z-g.z)/g.cell)
            local row=rows[z+1];local packed=row and row[math.floor(x/4)+1]
            if not packed then return nil end
            return math.floor(packed/2^(x%4))%2==1
    end
    return {mode=profile.id,mapID=g.mapID,validated=true,static=true,cell=g.cell,
        kind='Bundled '..profile.id..' navigation (50-unit static cells)',isWall=isWall,
        isWalkWall=function(p,team)
            if p and p.x and p.z and g.gates and g.gates[team] then
                local x,z=math.floor((p.x-g.x)/g.cell),math.floor((p.z-g.z)/g.cell)
                if x>=0 and x<g.nx and z>=0 and z<g.nz and g.gates[team][z*g.nx+x] then return false end
            end
            return isWall(p)
        end}
end

local function push(heap,node)
    local i=#heap+1
    while i>1 do local parent=math.floor(i/2)
        if heap[parent].f<=node.f then break end
        heap[i]=heap[parent];i=parent
    end
    heap[i]=node
end
local function pop(heap)
    local root,last=heap[1],table.remove(heap)
    if #heap>0 then
        local i=1
        while i*2<=#heap do
            local child=i*2
            if child<#heap and heap[child+1].f<heap[child].f then child=child+1 end
            if last.f<=heap[child].f then break end
            heap[i]=heap[child];i=child
        end
        heap[i]=last
    end
    return root
end
-- Local A*: fixed node budget and travel bound, eight neighbours, no corner
-- cutting. GG remains responsible for dispatching every movement order.
function N.approach(terrain,origin,landing,range,maxWalk,yieldWork,accept,sliceNodes)
    sliceNodes=math.max(1,math.min(64,sliceNodes or 64))
    local step=50;local radius=math.min(45,myHero.boundingRadius or 35)
    local heap,seen,free={}, {}, {};local expanded=0
    local function point(x,z) return {x=origin.x+x*step,y=origin.y,z=origin.z+z*step} end
    local function key(x,z) return x..':'..z end
    local function walkable(x,z)
        local k=key(x,z)
        if free[k]==nil then free[k]=terrain:clearance(point(x,z),radius,true) end
        return free[k]
    end
    local start={x=0,z=0,g=0,f=math.max(0,U.dist(origin,landing)-range)}
    push(heap,start);seen['0:0']=0
    while #heap>0 and expanded<1800 do
        local node=pop(heap);local p=point(node.x,node.z)
        if node.g==seen[key(node.x,node.z)] then
            expanded=expanded+1
            if yieldWork and expanded%sliceNodes==0 then yieldWork() end
            if U.dist(p,landing)<=range-20 then
                local accepted
                if accept then accepted=accept(p)
                else local entry,exit=terrain:crossing(p,landing);accepted=entry and exit and terrain:wall(landing)==false end
                if accepted then
                    local reversed={};local n=node
                    while n.parent do reversed[#reversed+1]=point(n.x,n.z);n=n.parent end
                    local path={};for i=#reversed,1,-1 do path[#path+1]=reversed[i] end
                    -- Collapse only verified straight, traversable segments.
                    local smooth={};local from=origin;local i=1
                    while i<=#path do
                        local last=i
                        for j=i+1,#path do
                            if yieldWork and (j-i)%sliceNodes==0 then yieldWork() end
                            if not terrain:walkLine(from,path[j],radius) then break end
                            last=j
                        end
                        smooth[#smooth+1]=path[last];from=path[last];i=last+1
                    end
                    return smooth,node.g,expanded
                end
            end
            for dx=-1,1 do for dz=-1,1 do
                if dx~=0 or dz~=0 then
                    local x,z=node.x+dx,node.z+dz
                    local cost=node.g+step*((dx~=0 and dz~=0) and 1.41421356237 or 1)
                    local k=key(x,z)
                    if cost<=maxWalk and (not seen[k] or cost<seen[k]) and walkable(x,z)
                        and (dx==0 or dz==0 or (walkable(node.x+dx,node.z) and walkable(node.x,node.z+dz)))
                        and terrain:walkLine(p,point(x,z),radius) then
                        seen[k]=cost
                        push(heap,{x=x,z=z,g=cost,f=cost+math.max(0,U.dist(point(x,z),landing)-(range-20)),parent=node})
                    end
                end
            end end
        end
    end
    return nil,nil,expanded
end
return N

end
