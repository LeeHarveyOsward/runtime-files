local U={}
function U.finite(n)return type(n)=='number' and n==n and math.abs(n)<math.huge end
function U.position(p)return (type(p)=='table'or type(p)=='userdata')and U.finite(p.x)and U.finite(p.z)end
function U.copy(p)if U.position(p)then return {x=p.x,y=p.y or 0,z=p.z}end end
function U.dist(a,b)if not U.position(a)or not U.position(b)then return math.huge end;return math.sqrt((a.x-b.x)^2+(a.z-b.z)^2)end
function U.toward(a,b,d)local n=U.dist(a,b);if n==math.huge then return end;if n<.001 then return U.copy(a)end;return {x=a.x+(b.x-a.x)*d/n,y=a.y or 0,z=a.z+(b.z-a.z)*d/n}end
function U.id(o)return o and ((o.networkID and o.networkID~=0)and o.networkID or (o.handle and o.handle~=0)and o.handle or nil)end
function U.name(n)return type(n)=='string' and n:lower()or ''end
function U.same(a,b)return a and b and U.id(a)and U.id(a)==U.id(b)end
function U.valid(o)return o and U.id(o)and o.valid~=false and not o.dead and (o.health or 1)>0 and o.visible~=false and o.isTargetable~=false and U.position(o.pos)end
function U.count(n,max)return U.finite(n)and math.max(0,math.min(max,math.floor(n)))or 0 end
function U.stackCount(o)return U.finite(o.stackCount)and o.stackCount or U.finite(o.stacks)and o.stacks or 0 end
function U.vector(p)return Vector(p.x,p.y or 0,p.z)end
function U.dot(a,b)return a.x*b.x+a.z*b.z end
function U.clamp(v,a,b)return math.max(a,math.min(b,v))end
function U.hp(o)return 100*(o.health or 0)/math.max(1,o.maxHealth or 1)end
function U.buff(o,names,now,owner)
    if not o or not o.GetBuff then return end
    for i=0,U.count(o.buffCount,128)do
        local b=o:GetBuff(i)
        if b and names[U.name(b.name)]then
            local expiry=(b.expireTime and b.expireTime>0)and b.expireTime or b.endTime
            local source=b.sourceID or b.sourceNetworkID or (b.source and U.id(b.source))
            if (b.count or 0)>0 and expiry and expiry>now and (not owner or source==owner)then return b end
        end
    end
end
function U.predict(o,seconds)
    local p=o and o.pos;if not U.position(p)then return end
    local path=o.pathing;local dest=path and path.endPos
    if path and path.hasMovePath and U.position(dest)then return U.toward(p,dest,math.min(U.dist(p,dest),(o.ms or 0)*seconds))end
    return U.copy(p)
end
return U
