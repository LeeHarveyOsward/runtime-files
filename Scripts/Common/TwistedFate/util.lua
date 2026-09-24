local U={}
function U.id(o)return o and (o.networkID or o.handle)end
function U.alive(o)return o and o.valid~=false and not o.dead and (o.health or 0)>0 end
function U.target(o)return U.alive(o) and o.visible==true and o.isTargetable==true end
function U.dist(a,b)
    a=a.pos or a;b=b.pos or b
    return math.sqrt((a.x-b.x)^2+(a.z-b.z)^2)
end
function U.lower(s)return string.lower(s or '')end
function U.remove(list,fn)for i=#list,1,-1 do if list[i]==fn then table.remove(list,i)end end end
function U.copy(t)local o={};for k,v in pairs(t)do o[k]=v end;return o end
function U.point(x,y,z)return {x=x,y=y or 0,z=z}end
function U.mode(sdk)
    for _,name in ipairs({'FLEE','COMBO','HARASS','LASTHIT','LANECLEAR','JUNGLECLEAR'})do
        local id=sdk['ORBWALKER_MODE_'..name]
        if sdk.Orbwalker.Modes[id]then return name,id end
    end
    return 'NONE',nil
end
function U.buffs(unit,fn)
    for i=0,(unit.buffCount or -1)do local b=unit:GetBuff(i);if b and b.name then fn(b)end end
end
return U
