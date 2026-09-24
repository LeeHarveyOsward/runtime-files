local G=require('evade.geometry')
local T={};T.__index=T
local function bit(n,b)return math.floor(n/b)%2==1 end
function T.new(grid,team,live)
    return setmetatable({grid=grid,team=team,live=live,revision=0,obstacles={},unknown=false},T)
end
function T:SetDynamic(id,shape)
    if shape and not G.valid(shape)then return false,'invalid_obstacle'end
    self.obstacles[id]=shape;self.revision=self.revision+1;return true
end
function T:SetUnknown(on)
    if self.unknown~=on then self.unknown=on;self.revision=self.revision+1 end
end
function T:Cell(x,z)
    local g=self.grid;if not g then return nil end
    if x<0 or z<0 or x>=g.nx or z>=g.nz then return true end
    local row=g.rows and g.rows[z+1]
    local flag=row and tonumber(row:sub(x*4+1,x*4+4),16) or g.flags and g.flags[z*g.nx+x+1]
    if not flag then return nil end
    if flag>=4096 then return nil end -- Upper navigation flags are retained but not interpreted yet.
    local solid=bit(flag,2) or bit(flag,4) or bit(flag,8) or bit(flag,64) or bit(flag,512)
    if solid then return true end
    if bit(flag,1024)and bit(flag,2048)then return true end
    if bit(flag,1024) then return self.team~=100 end
    if bit(flag,2048) then return self.team~=200 end
    -- Existing extracted profiles treat 2048 as a team gate. It must be
    -- interpreted before other obstacle flags, never globally cleared.
    return false
end
function T:Wall(p,t,radius)
    if self.unknown or not G.point(p)then return nil,'terrain_unknown'end
    local g=self.grid;if not g then return nil,'map_variant_unknown'end
    local x,z=math.floor((p.x-g.x)/g.cell),math.floor((p.z-g.z)/g.cell)
    local wall=self:Cell(x,z)
    if wall~=false then return wall,wall and 'static_wall' or 'terrain_unknown'end
    if self.live then local ok,v=pcall(self.live,p);if not ok or type(v)~='boolean'then return nil,'dynamic_terrain_unknown'end;if v then return true,'live_wall'end end
    for _,s in pairs(self.obstacles)do if t>=s.starts and t<=s.ends then
        local d=G.distance(s,p,t);if not d then return nil,'dynamic_terrain_unknown'end
        if d<=(radius or 0)then return true,'dynamic_wall'end
    end end
    return false
end
function T:Segment(a,b,radius,t0,t1,budget)
    if not G.point(a)or not G.point(b)or not G.finite(radius)or radius<0 then return nil,'invalid_path'end
    local g=self.grid;if not g or self.unknown then return nil,'map_variant_unknown'end
    -- Test every grid square intersecting the swept capsule, not a few samples.
    local minx=math.floor((math.min(a.x,b.x)-radius-g.x)/g.cell)
    local maxx=math.floor((math.max(a.x,b.x)+radius-g.x)/g.cell)
    local minz=math.floor((math.min(a.z,b.z)-radius-g.z)/g.cell)
    local maxz=math.floor((math.max(a.z,b.z)+radius-g.z)/g.cell)
    local half=g.cell/2;local circ=half*1.4142135623731
    for z=minz,maxz do for x=minx,maxx do
        budget.remaining=budget.remaining-1;if budget.remaining<0 then return nil,'terrain_budget'end
        local center={x=g.x+(x+.5)*g.cell,z=g.z+(z+.5)*g.cell}
        if G.segment(center,a,b)<=radius+circ then
            local wall=self:Cell(x,z)
            if wall==nil then return nil,'terrain_unknown'end
            if wall then return false,'static_wall'end
        end
    end end
    for _,s in pairs(self.obstacles)do
        local hit,why=G.sweep(s,a,b,t0,t1,radius,budget)
        if hit==nil then return nil,why elseif hit then return false,'dynamic_wall'end
    end
    -- Static cells do not establish the absence of runtime terrain changes.
    if self.live then
        local steps=math.max(1,math.ceil(G.dist(a,b)/math.max(4,math.min(20,radius/2))))
        for i=0,steps do
            budget.remaining=budget.remaining-1;if budget.remaining<0 then return nil,'terrain_budget'end
            local p=G.lerp(a,b,i/steps);local wall,why=self:Wall(p,t0+(t1-t0)*i/steps,radius)
            if wall==true then return false,why elseif wall==nil then return nil,why end
            for k=0,7 do local ang=k*math.pi/4
                budget.remaining=budget.remaining-1;if budget.remaining<0 then return nil,'terrain_budget'end
                local q={x=p.x+math.cos(ang)*radius,z=p.z+math.sin(ang)*radius,y=p.y}
                local ok,v=pcall(self.live,q);if not ok or type(v)~='boolean'then return nil,'dynamic_terrain_unknown'end
                if v then return false,'live_wall'end
            end
        end
    end
    return true
end
return T
