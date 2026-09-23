return function(U,N)
local T={};T.__index=T
local clearanceDirections={}
for index=0,7 do local angle=index*math.pi/4
    clearanceDirections[#clearanceDirections+1]={x=math.cos(angle),z=math.sin(angle)}
end
function T.new(ctx, suppliedProvider)
    local provider=suppliedProvider
    if not provider then provider=N.provider(ctx.profile) end
    if not provider and ctx.profile.id=='normal' and Game.mapID==11 then
        pcall(require,'MapPositionGOS')
        if _G.MapPosition then provider={mode='normal',kind='legacy static 33-unit grid',isWall=function(p) return not not MapPosition:inWall(U.vector(p)) end} end
    end
    return setmetatable({ctx=ctx,provider=provider},T)
end
function T:wall(p)
    if not U.position(p) then return nil end
    if not self.provider or type(self.provider.isWall)~='function'
        or (self.provider.mode and self.provider.mode~=self.ctx.profile.id)
        or (self.provider.mapID and self.provider.mapID~=Game.mapID) then return nil end
    local ok,value=pcall(self.provider.isWall,p)
    if ok and type(value)=='boolean' then return value end
end
function T:trusted()
    return self.provider and (self.provider.validated or self.ctx.config:get('terrainVerified'))
        and (not self.provider.mode or self.provider.mode==self.ctx.profile.id)
        and (not self.provider.mapID or self.provider.mapID==Game.mapID)
end
function T:crossing(a,b)
    if not U.position(a) or not U.position(b) or U.dist(a,b)>50000 then return nil,nil,'unknown' end
    local distance=U.dist(a,b);local entry,exitPoint=nil,nil
    local dx,dz=0,0
    if distance>=.001 then dx,dz=(b.x-a.x)/distance,(b.z-a.z)/distance end
    for step=0,math.ceil(distance/8) do
        local length=math.min(distance,step*8)
        local p={x=a.x+dx*length,y=a.y or 0,z=a.z+dz*length};local wall=self:wall(p)
        if wall==nil then return nil,nil,'unknown' end
        if wall then entry=entry or p;exitPoint=nil elseif entry then exitPoint=p;break end
    end
    return entry,exitPoint
end
function T:cursorCrossing(origin,raw,radius)
    if not U.position(origin) or not U.position(raw) or U.dist(origin,raw)>50000
        or not U.finite(radius) or radius<0 or radius>1000 then return nil,nil,'unknown' end
    -- Select the wall interval nearest the aim, not the first obstacle along
    -- Lee's approach. Earlier geometry belongs to native walking pathfinding.
    local distance=U.dist(origin,raw)
    if distance<.001 then return nil end
    local dx,dz=(raw.x-origin.x)/distance,(raw.z-origin.z)/distance
    local searchLimit=distance+radius
    -- When the cursor is inside / just before a wall, finish that interval
    -- beyond the assist radius, but do not select new walls beyond it.
    local length=searchLimit+(self.ctx.profile.jumpRange or self.ctx.profile.wRange)
    local entry,bestEntry,bestExit,bestScore
    local function consider(exitPoint)
        local start=U.dist(origin,entry)
        local finish=exitPoint and U.dist(origin,exitPoint) or length
        local score=math.max(start-distance,distance-finish,0)
        if not bestScore or score<=bestScore then
            bestEntry,bestExit,bestScore=entry,exitPoint,score
        end
    end
    for step=0,math.ceil(length/8) do
        local d=math.min(length,step*8)
        if d>searchLimit and not entry then break end
        local point={x=origin.x+dx*d,y=raw.y or origin.y or 0,z=origin.z+dz*d}
        local wall=self:wall(point)
        if wall==nil then return nil,nil,'unknown' end
        if wall then entry=entry or point
        elseif entry then consider(point);entry=nil end
    end
    if entry then consider(nil) end
    return bestEntry,bestExit
end
function T:landing(origin,raw,range,previous)
    if not U.position(origin) or not U.position(raw) or U.dist(origin,raw)>50000
        or not U.finite(range) or range<=0 or range>2000 then
        return {valid=false,kind='unknown',reason='Invalid world position / range'}
    end
    local distance=U.dist(origin,raw)
    local direct=distance>range and U.toward(origin,raw,range) or U.copy(raw)
    local directWall=self:wall(direct)
    if directWall==nil then return {valid=false,pos=direct,raw=U.copy(raw),kind='unknown',reason='Terrain unavailable for this map / profile'} end
    local radius=self.ctx.config:get('assistRadius')
    local entry,exitPoint,unknown=self:cursorCrossing(origin,raw,radius)
    if unknown then return {valid=false,pos=direct,raw=U.copy(raw),kind='unknown',reason='Terrain unavailable along aim'} end
    local nearEdge=entry and (U.dist(raw,entry)<=radius or (exitPoint and U.dist(raw,exitPoint)<=radius))
    -- A valid far-side cursor remains exact, even immediately beside the edge.
    if distance<=range and directWall==false and (not entry or (exitPoint and distance>=U.dist(origin,exitPoint))) then
        return {valid=true,pos=direct,raw=U.copy(raw),kind='exact'}
    end
    if not entry and directWall==false then
        return {valid=true,pos=direct,raw=U.copy(raw),kind=distance>range and 'clamped' or 'exact'}
    end
    if not self:trusted() or not self.ctx.config:get('wardAssist') then
        if entry and distance>U.dist(origin,entry) and (not exitPoint or U.dist(origin,exitPoint)>range) then
            return {valid=false,pos=direct,raw=U.copy(raw),reason='Far side is outside placement range'}
        end
        if directWall==false and not nearEdge then return {valid=true,pos=direct,raw=U.copy(raw),kind='exact'} end
        return {valid=false,pos=direct,raw=U.copy(raw),reason='Wall assistance requires verified terrain'}
    end
    if entry and U.dist(origin,entry)>range then
        return {valid=false,pos=direct,raw=U.copy(raw),reason='Cursor-selected wall requires approach'}
    end
    local best,bestScore=nil,math.huge
    local function consider(p)
        if U.dist(origin,p)>range or self:wall(p)~=false then return end
        -- Crossing an earlier wall must never satisfy a later cursor-selected
        -- crossing, even when that earlier landing is immediately reachable.
        if entry and (not exitPoint or (p.x-exitPoint.x)*(raw.x-origin.x)+(p.z-exitPoint.z)*(raw.z-origin.z)<0) then return end
        local hit,exit=self:crossing(origin,p)
        if entry and (not hit or not exit) then return end
        -- Require clearance beyond the exit, not merely the first free grid cell.
        if exit and U.dist(exit,p)<8 then return end
        local score=U.dist(raw,p)
        if previous and previous.valid and U.dist(previous.pos,p)<10 then score=score-4 end
        if score<bestScore then best,bestScore=p,score end
    end
    consider(direct)
    -- Radial projection is already the closest point in the reachable disk.
    if best and distance>range then return {valid=true,pos=best,raw=U.copy(raw),kind='assisted'} end
    for r=8,radius,8 do
        local count=math.max(16,math.ceil(2*math.pi*r/12))
        for i=1,count do local angle=2*math.pi*i/count
            consider({x=raw.x+math.cos(angle)*r,y=raw.y,z=raw.z+math.sin(angle)*r})
        end
        if best and r>bestScore+16 then break end
    end
    if best then return {valid=true,pos=best,raw=U.copy(raw),kind='assisted'} end
    return {valid=false,pos=direct,raw=U.copy(raw),reason='No reachable far-side landing'}
end
function T:walkWall(p)
    if not U.position(p) then return nil end
    if self:trusted() and type(self.provider.isWalkWall)=='function' then
        local ok,value=pcall(self.provider.isWalkWall,p,myHero.team)
        if ok and type(value)=='boolean' then return value end
    end
    return self:wall(p)
end
function T:clearance(p,radius,walking)
    local query=walking and self.walkWall or self.wall
    if query(self,p)~=false then return false end
    for _,direction in ipairs(clearanceDirections) do
        if query(self,{x=p.x+direction.x*radius,y=p.y,z=p.z+direction.z*radius})~=false then return false end
    end
    return true
end
function T:walkLine(a,b,radius)
    if not U.position(a) or not U.position(b) or U.dist(a,b)>50000
        or not U.finite(radius) or radius<0 or radius>1000 then return false end
    local distance=U.dist(a,b)
    local dx,dz=0,0
    if distance>=.001 then dx,dz=(b.x-a.x)/distance,(b.z-a.z)/distance end
    for i=1,math.max(1,math.ceil(distance/20)) do
        local length=math.min(distance,i*20)
        if not self:clearance({x=a.x+dx*length,y=a.y or 0,z=a.z+dz*length},radius,true) then return false end
    end
    return true
end
function T:egressLine(a,b,radius)
    if not U.position(a) or not U.position(b) or not U.finite(radius) or radius<0 or radius>1000 then return false end
    if self:walkLine(a,b,radius) then return true end
    -- A valid live position can overlap the conservative static cell padding.
    -- Allow that initial padding only; never cross a wall with the center line,
    -- never relax an unknown/dynamic provider, and require full endpoint clearance.
    local provider=self.provider
    if not provider or not provider.static or not self:trusted() or self:walkWall(a)~=false
        or self:clearance(a,radius,true) or not self:clearance(b,radius,true) then return false end
    local distance=U.dist(a,b);if distance>1000 or distance<1 then return false end
    local padding=radius+math.min(50,provider.cell or 0);local cleared=false
    for step=1,math.ceil(distance/10) do
        local length=math.min(distance,step*10);local p=U.toward(a,b,length)
        if self:walkWall(p)~=false then return false end
        local free=self:clearance(p,radius,true)
        if free then cleared=true elseif cleared or length>padding then return false end
    end
    return cleared
end
function T:refineApproach(origin,near,landing,range,maxWalk)
    -- Sample the near shore around the same landing. A shorter crossing tends
    -- toward the wall normal; walking cost keeps a long perpendicular detour
    -- from beating an already fast diagonal approach.
    local clearance=math.min(45,myHero.boundingRadius or 35)
    local length=U.dist(near,landing)
    if length<1 then return near end
    local dx,dz=(near.x-landing.x)/length,(near.z-landing.z)/length
    local best=near
    local function cost(point)
        return math.max(0,U.dist(origin,point)-math.max(0,range-U.dist(point,landing)))
            +U.dist(point,landing)*.3
    end
    local score=cost(near)
    for _,degrees in ipairs({0,-15,15,-30,30,-45,45,-60,60,-75,75}) do
        local angle=degrees*math.pi/180
        local x,z=dx*math.cos(angle)-dz*math.sin(angle),dx*math.sin(angle)+dz*math.cos(angle)
        for distance=clearance+24,range-8,24 do
            local point={x=landing.x+x*distance,y=near.y,z=landing.z+z*distance}
            -- Stay on the original shore and in this wall's local neighborhood.
            if U.dist(point,near)<=range and U.dist(origin,point)<=(maxWalk or math.huge)
                and cost(point)<score and self:clearance(point,clearance,true) then
                local hit,out=self:crossing(point,landing)
                if hit and out and self:crossing(near,point)==nil then best,score=point,cost(point) end
            end
        end
    end
    return best
end
function T:nearBoundary(near,landing)
    local radius=myHero.boundingRadius or 35
    if not self:clearance(near,radius,true) then
        for setback=4,radius*2,4 do
            local p=U.toward(near,landing,-setback)
            if self:clearance(p,radius,true) then near=p;break end
        end
    end
    local best=near;local limit=U.dist(near,landing)
    for distance=4,limit,4 do
        local p=U.toward(near,landing,distance)
        if not self:clearance(p,radius,true) then break end
        best=p
    end
    return best
end
function T:plan(origin,raw,range,previous,yieldWork,landingResult)
    if not U.position(origin) or not U.position(raw) or U.dist(origin,raw)>50000
        or not U.finite(range) or range<=0 or range>2000 then
        return {valid=false,kind='unknown',reason='Invalid world position / range'}
    end
    local result=landingResult or self:landing(origin,raw,range,previous)
    if not raw or result.kind=='unknown' or not self:trusted() or not self.ctx.config:get('wardApproach') then return result end
    if result.valid and result.kind~='clamped' then return result end
    local limit=self.ctx.config:get('wardWalkRange')
    local maxWalk=limit>0 and limit or U.dist(origin,raw)+range+1400
    if limit>0 and U.dist(origin,raw)>limit+range then return result end
    local radius=self.ctx.config:get('assistRadius')
    local entry,exit=self:cursorCrossing(origin,raw,radius)
    if not entry then return result end
    if not exit then return {valid=false,pos=result.pos,raw=U.copy(raw),reason='No far-side opening near cursor'} end
    -- Solve the crossing locally at the wall. Native movement owns the long
    -- approach; do not expand a whole-map A* graph to issue one destination.
    local clearance=math.min(45,myHero.boundingRadius or 35)
    for setback=clearance+8,clearance+104,16 do
        local near=U.toward(entry,origin,setback)
        if U.dist(origin,near)<=maxWalk and self:clearance(near,clearance,true) then
            local landing,hit,out
            local desired=U.dist(near,raw)
            if self.ctx.config:get('wardAssist') then desired=math.max(desired,U.dist(near,exit)+16) end
            local length=math.min(range-8,desired)
            if self.ctx.config:get('wardAssist') or U.dist(near,raw)<=range-8 then
                -- Cheap local ray first. Avoid running the full radial assist
                -- search once per setback in the same preview frame.
                local candidate=U.toward(near,raw,length)
                hit,out=self:crossing(near,candidate)
                local later=U.dist(near,raw)>length and self:wall(candidate)==false and self:crossing(candidate,raw)
                if hit and out and self:wall(candidate)==false and not later then
                    local minimum=U.dist(near,out)+8
                    for distance=length,minimum,-8 do
                        local point=U.toward(near,raw,distance)
                        if self:clearance(point,8) then landing={pos=point};break end
                    end
                end
            end
            if landing and hit and out then
                near=self:refineApproach(origin,near,landing.pos,range,maxWalk)
                near=self:nearBoundary(near,landing.pos)
                if U.dist(near,landing.pos)>range then
                    local point=U.toward(near,landing.pos,range-8)
                    local first,last=self:crossing(near,point)
                    if first and last and self:clearance(point,8) then landing.pos=point end
                end
                local stand=U.toward(near,origin,math.max(0,range-U.dist(near,landing.pos)))
                if U.dist(stand,landing.pos)>range then stand=near end
                return {valid=true,kind='approach',pos=landing.pos,raw=U.copy(raw),
                    path={near},stand=stand,walkTo=near,walkDistance=U.dist(origin,near),
                    nativeRoute=true,crossWall=true,expanded=0}
            end
        end
    end
    local candidates={}
    local function consider(p)
        if self:wall(p)~=false then return end
        local dx,dz=raw.x-origin.x,raw.z-origin.z
        if (p.x-exit.x)*dx+(p.z-exit.z)*dz<0 then return end
        candidates[#candidates+1]={pos=p,offset=U.dist(raw,p)}
    end
    consider(U.copy(raw))
    if self.ctx.config:get('wardAssist') then
        for r=16,radius,16 do
            for i=0,23 do local a=i*math.pi/12
                consider({x=raw.x+math.cos(a)*r,y=raw.y,z=raw.z+math.sin(a)*r})
            end
            if #candidates>=6 then break end
        end
    end
    table.sort(candidates,function(a,b)return a.offset<b.offset end)
    -- Keep aim exact whenever possible; try nearby alternatives only when the
    -- closest landing cannot be approached within the configured walk bound.
    for i=1,math.min(3,#candidates) do
        local candidate=candidates[i]
        local path,length,nodes=N.approach(self,origin,candidate.pos,range,maxWalk,yieldWork)
        if path and #path>0 then
            local stand=path[#path];local walkTo=stand
            local clearance=math.min(45,myHero.boundingRadius or 35)
            -- The command aims deeper into the near-side walkable area. The
            -- range-entry point is only a trigger, never a pixel-perfect stop.
            local remaining=math.min(U.dist(stand,candidate.pos),math.max(0,maxWalk-length))
            for distance=8,remaining,8 do
                local point=U.toward(stand,candidate.pos,distance)
                if not self:clearance(point,clearance) then break end
                walkTo=point
            end
            walkTo=self:nearBoundary(walkTo,candidate.pos)
            local extra=U.dist(stand,walkTo)
            if extra>0 then path[#path+1]=walkTo end
            return {valid=true,kind='approach',pos=candidate.pos,raw=U.copy(raw),path=path,
                stand=stand,walkTo=walkTo,walkDistance=length+extra,expanded=nodes}
        end
    end
    return {valid=false,pos=result.pos,raw=U.copy(raw),reason='No bounded approach to a far-side landing'}
end
return T

end
