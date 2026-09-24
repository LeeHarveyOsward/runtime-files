-- World x/z, distances in game units, times in seconds. No host calls.
local G={}
local sqrt,abs,min,max=math.sqrt,math.abs,math.min,math.max
function G.finite(n)return type(n)=='number' and n==n and abs(n)<math.huge end
function G.point(p)return p and G.finite(p.x) and G.finite(p.z) and (p.y==nil or G.finite(p.y))end
function G.copy(p)return p and {x=p.x,y=p.y or 0,z=p.z}end
function G.dist(a,b)return sqrt((a.x-b.x)^2+(a.z-b.z)^2)end
function G.lerp(a,b,t)return {x=a.x+(b.x-a.x)*t,y=a.y or 0,z=a.z+(b.z-a.z)*t}end
function G.segment(p,a,b)
    local x,z=b.x-a.x,b.z-a.z;local d=x*x+z*z
    local t=d>0 and max(0,min(1,((p.x-a.x)*x+(p.z-a.z)*z)/d)) or 0
    return G.dist(p,G.lerp(a,b,t)),t
end
function G.direction(a,b)
    local d=G.dist(a,b);if d<.00001 then return 1,0 end
    return (b.x-a.x)/d,(b.z-a.z)/d
end
function G.center(s,t)
    if s.motion then
        local nodes=s.motion
        for i=2,#nodes do
            if t<=nodes[i].at then
                local a,b=nodes[i-1],nodes[i];return G.lerp(a.pos,b.pos,max(0,min(1,(t-a.at)/(b.at-a.at))))
            end
        end
        return G.copy(nodes[#nodes].pos)
    end
    local origin=s.origin or s.a
    if not origin then return nil end
    local dt=max(0,t-(s.launch or s.starts));local speed=s.speed or 0
    if s.speed and s.b then
        local length=G.dist(origin,s.b);local distance=max(0,min(length,speed*dt+.5*(s.acceleration or 0)*dt*dt))
        return G.lerp(origin,s.b,length>0 and distance/length or 0)
    end
    return origin
end
local function angle(x,z)return math.atan2 and math.atan2(z,x) or math.atan(z/x)end
local function delta(a,b)return (a-b+math.pi)%(2*math.pi)-math.pi end
function G.distance(s,p,t)
    local kind=s.shape;local a=G.center(s,t)
    if kind=='compound' then
        local d=math.huge;for _,part in ipairs(s.parts or {})do local x=G.distance(part,p,t);if not x then return nil end;d=min(d,x)end
        return d
    end
    if not a then return nil end
    local radius=s.radius or 0
    if kind=='circle' or kind=='missile' then return G.dist(a,p)-radius end
    if kind=='line' then return s.b and G.segment(p,a,s.b)-radius end
    if kind=='ring' then local d=G.dist(a,p);return max((s.innerRadius or 0)-d,d-radius)end
    local b=s.b;if not b then return nil end
    local dx,dz=G.direction(a,b);local x,z=p.x-a.x,p.z-a.z
    local forward,side=x*dx+z*dz,abs(x*dz-z*dx)
    if kind=='rectangle' then
        local length=s.length or G.dist(a,b);local qx,qz=abs(forward-length/2)-length/2,side-radius
        return sqrt(max(qx,0)^2+max(qz,0)^2)+min(max(qx,qz),0)
    end
    if kind=='cone' then
        local half=s.halfAngle;if not half then return nil end
        local length=s.length or G.dist(a,b);local c,si=math.cos(half),math.sin(half)
        local left={x=a.x+(dx*c-dz*si)*length,z=a.z+(dz*c+dx*si)*length}
        local right={x=a.x+(dx*c+dz*si)*length,z=a.z+(dz*c-dx*si)*length}
        local radial=sqrt(x*x+z*z);local inside=radial<=length and forward>=radial*c
        local d=min((G.segment(p,a,left)),(G.segment(p,a,right)))
        if forward>=radial*c then d=min(d,abs(radial-length))end
        return inside and -d or d
    end
    if kind=='arc' then
        if not s.arcRadius or not s.halfAngle then return nil end
        local theta=angle(x,z);local axis=angle(dx,dz);local offset=delta(theta,axis)
        local theta2=axis+max(-s.halfAngle,min(s.halfAngle,offset))
        local q={x=a.x+math.cos(theta2)*s.arcRadius,z=a.z+math.sin(theta2)*s.arcRadius}
        return G.dist(p,q)-radius
    end
    return nil
end
function G.valid(s)
    if type(s)~='table' or not G.finite(s.starts) or not G.finite(s.ends) or s.ends<s.starts then return false,'invalid_time' end
    if s.shape=='targeted' then return s.targetID~=nil,'missing_target' end
    if s.shape=='compound' then
        if type(s.parts)~='table' or #s.parts==0 or #s.parts>16 then return false,'invalid_parts'end
        for _,p in ipairs(s.parts)do if p.shape=='compound' or not G.valid(p)then return false,'invalid_part'end end
        return true
    end
    if not G.point(s.origin or s.a) then return false,'invalid_origin'end
    local shapes={circle=true,missile=true,line=true,rectangle=true,cone=true,ring=true,arc=true}
    if not shapes[s.shape] then return false,'unknown_shape'end
    if not G.finite(s.radius) or s.radius<0 then return false,'invalid_radius'end
    if s.shape~='circle' and s.shape~='ring' and not G.point(s.b) then return false,'invalid_endpoint'end
    if s.shape=='cone' or s.shape=='arc' then
        if not G.finite(s.halfAngle) or s.halfAngle<=0 or s.halfAngle>math.pi then return false,'invalid_angle'end
    end
    if s.shape=='arc' and (not G.finite(s.arcRadius) or s.arcRadius<0)then return false,'invalid_arc'end
    if s.shape=='ring' and (not G.finite(s.innerRadius) or s.innerRadius<0 or s.innerRadius>s.radius)then return false,'invalid_ring'end
    if s.speed~=nil and (not G.finite(s.speed) or s.speed<0)then return false,'invalid_speed'end
    if s.acceleration~=nil and not G.finite(s.acceleration) then return false,'invalid_acceleration'end
    if s.launch~=nil and not G.finite(s.launch)then return false,'invalid_launch'end
    if s.motion then
        if #s.motion<2 or #s.motion>32 then return false,'invalid_motion'end
        for i,n in ipairs(s.motion)do
            if not G.point(n.pos) or not G.finite(n.at) or i>1 and n.at<=s.motion[i-1].at then return false,'invalid_motion'end
        end
    end
    return true
end
function G.motionBound(s)
    local v=(s.speed or 0)+abs(s.acceleration or 0)*max(0,s.ends-(s.launch or s.starts))
    for i=2,#(s.motion or {})do local a,b=s.motion[i-1],s.motion[i];v=max(v,G.dist(a.pos,b.pos)/(b.at-a.at))end
    for _,part in ipairs(s.parts or {})do v=max(v,G.motionBound(part))end
    -- Moving directional primitives can change their orientation. Only fixed
    -- directional shapes and translated circular primitives have this bound.
    if (s.motion or s.speed and s.speed>0) and s.shape~='circle' and s.shape~='missile' and s.shape~='ring' then return nil end
    return v
end
-- Conservative continuous collision. A Lipschitz bound rejects entire time
-- intervals, so a fast missile cannot slip between sampled positions.
local function linearCircle(s,a,b,t0,t1,lo,hi,radius,budget)
    local function interval(l,h)
        budget.remaining=budget.remaining-1;if budget.remaining<0 then return nil,'geometry_budget'end
        local c,d=G.center(s,l),G.center(s,h);local duration=t1-t0
        local u=duration>0 and (l-t0)/duration or 0;local v=duration>0 and (h-t0)/duration or 0
        local x,z=a.x+(b.x-a.x)*u-c.x,a.z+(b.z-a.z)*u-c.z
        local vx,vz=(b.x-a.x)*(v-u)-(d.x-c.x),(b.z-a.z)*(v-u)-(d.z-c.z)
        local r=s.radius+radius+.001;local cc=x*x+z*z-r*r
        if cc<=0 then return true,l end
        local aa=vx*vx+vz*vz;if aa<1e-20 then return false end
        local bb=2*(x*vx+z*vz);local discriminant=bb*bb-4*aa*cc
        if discriminant<0 then return false end
        local root=(-bb-sqrt(discriminant))/(2*aa)
        if root>=0 and root<=1 then return true,l+(h-l)*root end
        return false
    end
    -- Fixed-speed missiles stop at their endpoint. Splitting there keeps each
    -- relative-motion interval linear; it must not extrapolate past that point.
    local launch=s.launch or s.starts
    local arrival=s.speed and s.speed>0 and s.b and launch+G.dist(s.origin or s.a,s.b)/s.speed
    local from=lo
    if launch>from and launch<hi then local hit,at=interval(from,launch);if hit~=false then return hit,at end;from=launch end
    if arrival and arrival>from and arrival<hi then local hit,at=interval(from,arrival);if hit~=false then return hit,at end;from=arrival end
    return interval(from,hi)
end
function G.sweep(s,a,b,t0,t1,radius,budget)
    if not G.finite(t0)or not G.finite(t1)or t1<t0 or not G.finite(radius)or radius<0 then return nil,'invalid_interval'end
    local lo,hi=max(t0,s.starts),min(t1,s.ends)
    if hi<lo then return false end
    if (s.shape=='circle'or s.shape=='missile')and not s.motion and (not s.acceleration or s.acceleration==0)then
        return linearCircle(s,a,b,t0,t1,lo,hi,radius,budget)
    end
    local speed=G.motionBound(s);if not speed then return nil,'motion_unknown'end
    local duration=t1-t0;local player=duration>0 and G.dist(a,b)/duration or 0
    local function sample(t)
        return G.distance(s,G.lerp(a,b,duration>0 and (t-t0)/duration or 0),t)
    end
    budget.remaining=budget.remaining-1
    if budget.remaining<0 then return nil,'geometry_budget'end
    local initial=sample(lo)
    if initial==nil then return nil,'geometry_unknown'end
    if initial<=radius then return true,lo end
    local function visit(l,h,depth)
        budget.remaining=budget.remaining-1
        if budget.remaining<0 then return nil,'geometry_budget'end
        local mid=(l+h)/2;local d=sample(mid)
        if d==nil then return nil,'geometry_unknown'end
        if d-radius>(player+speed)*(h-l)/2+0.001 then return false end
        if depth>=14 or h-l<=.001 then return true,l end
        local hit,at=visit(l,mid,depth+1);if hit~=false then return hit,at end
        return visit(mid,h,depth+1)
    end
    return visit(lo,hi,0)
end
return G
