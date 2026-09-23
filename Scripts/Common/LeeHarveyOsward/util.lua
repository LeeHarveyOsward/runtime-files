local U = {}
-- Cache only within one outer LHO callback; never keep native buff wrappers
-- across callbacks or after dispatching input that can change spell state.
local buffScope;local buffEpoch=0
function U.beginBuffScope() buffScope={};buffEpoch=buffEpoch+1 end
function U.endBuffScope() buffScope=nil end
function U.invalidateBuffScope() if buffScope then buffScope={};buffEpoch=buffEpoch+1 end end
function U.buffScopeKey() return buffScope and buffEpoch end
function U.withBuffScope(fn,...)
    -- Public action validators also run outside LHO callbacks. Share native
    -- buff reads within one validation, but never across input or callbacks.
    if buffScope then return fn(...) end
    U.beginBuffScope()
    local ok,a,b=pcall(fn,...)
    U.endBuffScope()
    if not ok then error(a,0) end
    return a,b
end
function U.readBuff(unit,index)
    if not buffScope then return unit:GetBuff(index) end
    local row=buffScope[unit];if not row then row={};buffScope[unit]=row end
    if row[index]==nil then row[index]=unit:GetBuff(index) or false end
    return row[index] or nil
end
function U.finite(n) return type(n)=='number' and n==n and n>-math.huge and n<math.huge end
function U.count(n,limit)
    if not U.finite(n) or n<0 or n>limit then return 0 end
    return math.floor(n)
end
function U.position(p)
    return p and U.finite(p.x) and U.finite(p.z or p.y) and U.finite(p.y or 0)
        and math.abs(p.x)<100000 and math.abs(p.z or p.y)<100000 and math.abs(p.y or 0)<100000
end
function U.clamp(n, lo, hi) return math.max(lo, math.min(hi, n)) end
function U.copy(p) return p and {x=p.x, y=p.y or 0, z=p.z or p.y or 0} end
function U.dist(a,b)
    if not a or not b then return math.huge end
    local x,z=a.x-b.x,(a.z or a.y)-(b.z or b.y)
    return math.sqrt(x*x+z*z)
end
function U.screenDist(a,b)
    if not a or not b then return math.huge end
    local dx,dy=a.x-b.x,a.y-b.y
    return math.sqrt(dx*dx+dy*dy)
end
function U.toward(a,b,d)
    local length=U.dist(a,b)
    if length<0.001 then return U.copy(a) end
    return {x=a.x+(b.x-a.x)*d/length,y=a.y or 0,z=(a.z or a.y)+((b.z or b.y)-(a.z or a.y))*d/length}
end
function U.segment(p,a,b)
    local dx,dz=b.x-a.x,b.z-a.z
    local length=dx*dx+dz*dz
    local t=length>0 and U.clamp(((p.x-a.x)*dx+(p.z-a.z)*dz)/length,0,1) or 0
    return U.dist(p,{x=a.x+t*dx,z=a.z+t*dz}),t
end
function U.valid(u)
    return u and u.valid~=false and u.visible~=false and not u.dead and u.isTargetable~=false
        and U.position(u.pos) and U.finite(u.health) and u.health>0
end
function U.id(u) return u and (u.networkID or u.handle) end
function U.same(a,b) return a and b and (a==b or (U.id(a) and U.id(a)==U.id(b))) end
function U.name(s)
    s=s or ''
    local names=buffScope and buffScope.names
    if names and names[s] then return names[s] end
    local value=s:lower():gsub('^jade_',''):gsub('_jade$',''):gsub('blindmonk','leesin'):gsub('[^%w]','')
    if buffScope then
        if not names then names={};buffScope.names=names end
        names[s]=value
    end
    return value
end
function U.buffs(unit)
    local result={}
    if unit and unit.GetBuff then
        for i=0,U.count(unit.buffCount or 0,256) do
            local b=U.readBuff(unit,i)
            if b and math.max(b.count or 0,b.stacks or 0)>0 and b.name then result[#result+1]=b end
        end
    end
    return result
end
function U.buff(unit,names,now,source)
    if not unit or not unit.GetBuff then return end
    -- Most callers need one match. Avoid allocating/copying the entire buff
    -- list for every mark/range candidate, and stop at the first valid match.
    for index=0,U.count(unit.buffCount or 0,256) do
        local b=U.readBuff(unit,index)
        if b and b.name and names[U.name(b.name)] and math.max(b.count or 0,b.stacks or 0)>0 then
            local expiry=U.buffEnd(b)
            local owner=b.sourcenID and b.sourcenID~=0 and b.sourcenID or b.sourceID
            if (not expiry or expiry>now)
                and (not source or not owner or owner==0 or owner==source) then return b end
        end
    end
end
function U.buffEnd(buff)
    -- Native buff wrappers may expose expireTime=0 with a real endTime.
    if U.finite(buff.expireTime) and buff.expireTime>0 then return buff.expireTime end
    if U.finite(buff.endTime) and buff.endTime>0 then return buff.endTime end
end
function U.hp(u) return (u.health or 0)/math.max(1,u.maxHealth or 1)*100 end
function U.stackCount(item) return math.max(item and item.stacks or 0,item and item.stackCount or 0) end
function U.typedHP(u,kind)
    return (u.health or 0)+(u.allShield or 0)+(kind=='physical' and (u.shieldAD or 0) or kind=='magic' and (u.shieldAP or 0) or 0)
end
function U.effectiveHP(u) return (u.health or 0)+(u.allShield or 0)+(u.shieldAD or 0) end
function U.vector(p) return Vector(p.x,p.y or 0,p.z) end
function U.sortedKeys(t)
    local keys={} for k in pairs(t) do keys[#keys+1]=k end
    table.sort(keys) return keys
end
local keyNames={[0]='Unbound',[1]='Mouse1',[2]='Mouse2',[4]='Mouse3',[5]='Mouse4',[6]='Mouse5',
        [8]='Backspace',[9]='Tab',[13]='Enter',[16]='Shift',[17]='Ctrl',[18]='Alt',[20]='CapsLock',
        [27]='Esc',[32]='Space',[33]='PgUp',[34]='PgDn',[35]='End',[36]='Home',
        [37]='Left',[38]='Up',[39]='Right',[40]='Down',[45]='Insert',[46]='Delete',
        [160]='LShift',[161]='RShift',[162]='LCtrl',[163]='RCtrl',[164]='LAlt',[165]='RAlt',
        [186]=';',[187]='=',[188]=',',[189]='-',[190]='.',[191]='/',[192]='`',[219]='[',[220]='\\',[221]=']',[222]="'"}
function U.keyLabel(key)
    if not key then return 'Unbound' end
    if keyNames[key] then return keyNames[key] end
    if key>=48 and key<=57 or key>=65 and key<=90 then return string.char(key) end
    if key>=112 and key<=135 then return 'F'..(key-111) end
    if key>=96 and key<=105 then return 'Num'..(key-96) end
    return 'Key '..tostring(key)
end
return U
