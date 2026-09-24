-- Release 6
if not myHero or (myHero.charName~='Katarina' and myHero.charName~='Jade_Katarina') then return end
local client=_G.KataHariReleaseClient
if not client then
local hash=(function()
local native=bit32 or bit
local floor=math.floor
local modulus=4294967296
local xor4={}
for a=0,15 do
    xor4[a]={}
    for b=0,15 do
        local x,y,value,place=a,b,0,1
        for _=1,4 do
            if x%2~=y%2 then value=value+place end
            x=floor(x/2);y=floor(y/2);place=place*2
        end
        xor4[a][b]=value
    end
end
local function bxor(a,b)
    if native then return native.bxor(a,b)%modulus end
    local value,place=0,1
    for _=1,8 do
        value=value+xor4[a%16][b%16]*place
        a=floor(a/16);b=floor(b/16);place=place*16
    end
    return value
end
local function band(a,b)
    if native then return native.band(a,b)%modulus end
    return (a+b-bxor(a,b))/2
end
local function rotate(a,n)
    return floor(a/2^n)+(a%2^n)*2^(32-n)
end
local function triple(a,b,c)return bxor(bxor(a,b),c)end
local constants={
    1116352408,1899447441,3049323471,3921009573,961987163,1508970993,2453635748,2870763221,
    3624381080,310598401,607225278,1426881987,1925078388,2162078206,2614888103,3248222580,
    3835390401,4022224774,264347078,604807628,770255983,1249150122,1555081692,1996064986,
    2554220882,2821834349,2952996808,3210313671,3336571891,3584528711,113926993,338241895,
    666307205,773529912,1294757372,1396182291,1695183700,1986661051,2177026350,2456956037,
    2730485921,2820302411,3259730800,3345764771,3516065817,3600352804,4094571909,275423344,
    430227734,506948616,659060556,883997877,958139571,1322822218,1537002063,1747873779,
    1955562222,2024104815,2227730452,2361852424,2428436474,2756734187,3204031479,3329325298}
return function(message,pause)
    local length=#message
    local tail=string.char(128)..string.rep('\0',(55-length)%64)
    local bits=length*8
    for shift=7,0,-1 do tail=tail..string.char(floor(bits/256^shift)%256) end
    message=message..tail
    local h={1779033703,3144134277,1013904242,2773480762,1359893119,2600822924,528734635,1541459225}
    local w={}
    for start=1,#message,64 do
        for i=0,15 do local a,b,c,d=message:byte(start+i*4,start+i*4+3);w[i]=((a*256+b)*256+c)*256+d end
        for i=16,63 do
            local a,b=w[i-15],w[i-2]
            w[i]=(w[i-16]+triple(rotate(a,7),rotate(a,18),floor(a/8))+w[i-7]
                +triple(rotate(b,17),rotate(b,19),floor(b/1024)))%modulus
        end
        local a,b,c,d,e,f,g,k=unpack(h)
        for i=0,63 do
            local t1=(k+triple(rotate(e,6),rotate(e,11),rotate(e,25))
                +bxor(band(e,f),band(modulus-1-e,g))+constants[i+1]+w[i])%modulus
            local t2=(triple(rotate(a,2),rotate(a,13),rotate(a,22))
                +triple(band(a,b),band(a,c),band(b,c)))%modulus
            k=g;g=f;f=e;e=(d+t1)%modulus;d=c;c=b;b=a;a=(t1+t2)%modulus
        end
        local values={a,b,c,d,e,f,g,k}
        for i=1,8 do h[i]=(h[i]+values[i])%modulus end
        if pause then pause() end
    end
    local result={}
    for i=1,8 do result[i]=string.format('%08x',h[i]) end
    return table.concat(result)
end

end)()
local create=(function()
return function(env,hash,builtin,origin,package)
    local names=package and package.names or {'Orbama','LeeHarveyOsward'}
    local channel=package and package.channel or 'release'
    local prefix=package and package.cachePrefix or 'runtime-'
    local client={version=builtin,state='current',loaded={}}
    local function checksum(text)
        local a,b=1,0
        for offset=1,#text,4096 do
            for i=offset,math.min(offset+4095,#text) do a=a+text:byte(i);b=b+a end
            a=a%65521;b=b%65521
        end
        return b*65536+a
    end
    local base=env.COMMON_PATH
    if type(base)=='string' and not base:match('[/\\]$') then base=base..'/' end
    local function path(slot,name)return base..prefix..slot..'-'..name end
    local function read(file,limit)
        local ok,value=pcall(function()
            local f=env.io.open(file,'rb');if not f then return end
            local data=f:read(limit+1);f:close()
            if data and #data<=limit then return data end
        end)
        if ok then return value end
    end
    local function write(file,data)
        local ok,result=pcall(function()
            local f=env.io.open(file,'wb');if not f then return false end
            local written=f:write(data);local closed=f:close()
            return written~=nil and closed~=nil
        end)
        return ok and result and read(file,#data)==data
    end
    local function parse(text)
        if type(text)~='string' or #text>512 then return end
        local version,rest=text:match('^R1\n(%d+)\n(.*)$')
        version=tonumber(version)
        if not version or version<1 or version>999999999 then return end
        local result={version=version,text=text}
        for _,expected in ipairs(names)do
            local name,digest,size,crc,remaining=rest:match('^(%w+) (%x+) (%d+) (%d+)\n(.*)$')
            size=tonumber(size);crc=tonumber(crc)
            if name~=expected or not digest or #digest~=64 or not size or size<1 or size>4000000
                or not crc or crc>4294967295 then return end
            result[name]={hash=digest,size=size,checksum=crc};rest=remaining
        end
        if rest~='' then return end
        return result
    end
    local function validate(slot,manifest,pause)
        local chunks={}
        for _,name in ipairs(names) do
            local item=manifest[name];local body=read(path(slot,name..'.lua'),item.size)
            if not body or #body~=item.size or checksum(body)~=item.checksum then return end
            local fn=env.loadstring(body,'@runtime/'..name..'.lua')
            if not fn then return end
            chunks[name]=fn
        end
        return chunks
    end
    if base and env.io and env.loadstring then
        local choices={}
        for _,slot in ipairs({'a','b'}) do
            local candidate=parse(read(path(slot,'manifest'),512))
            if candidate and candidate.version>builtin then candidate.slot=slot;choices[#choices+1]=candidate end
        end
        table.sort(choices,function(a,b)return a.version>b.version end)
        for _,candidate in ipairs(choices) do
            local chunks=validate(candidate.slot,candidate)
            if chunks then client.version=candidate.version;client.slot=candidate.slot;client.chunks=chunks;break end
        end
    end
    function client:Boot(name,fallback,version)
        if self.loaded[name] then return self.loaded[name].value end
        if not self.chunks and version~=self.version then error('Runtime files belong to different releases; install the matching pair.') end
        local record={};self.loaded[name]=record
        local fn=self.chunks and self.chunks[name] or fallback
        -- Never retry another implementation after a chunk might have installed callbacks.
        record.value=fn();return record.value
    end
    local job,waiting,deadline,nextCheck,generation=nil,nil,0,0,0
    local function now()return env.GetTickCount()/1000 end
    local function fail()
        generation=generation+1;waiting=nil;job=nil;client.state='unavailable';nextCheck=now()+600
    end
    local function request(url,accept)
        generation=generation+1;local token=generation
        waiting=true;deadline=now()+45
        local ok=pcall(env.GetWebResultAsync,url,function(body)
            if token~=generation or not waiting then return end
            waiting=nil
            if type(body)~='string' or #body>4000000 then fail();return end
            accept(body)
        end)
        if not ok then fail() end
    end
    local function begin()
        client.state='checking';nextCheck=now()+600
        request(origin..'/main/'..channel..'/manifest',function(text)
            local manifest=parse(text)
            if not manifest then fail();return end
            if manifest.version<=client.version then client.state='current';return end
            local slot=client.slot=='a' and 'b' or 'a';local index=1
            local function download()
                local name=names[index]
                if not name then
                    if write(path(slot,'manifest'),manifest.text) then client.state='ready';client.pending=manifest.version
                    else fail() end
                    return
                end
                local item=manifest[name]
                request(origin..'/main/'..channel..'/'..manifest.version..'/'..name..'.lua',function(body)
                    job=coroutine.create(function()
                        if #body~=item.size or hash(body,coroutine.yield)~=item.hash or checksum(body)~=item.checksum
                            or not env.loadstring(body,'@update/'..name..'.lua') then fail();return end
                        if not write(path(slot,name..'.lua'),body) then fail();return end
                        index=index+1;job=nil;download()
                    end)
                end)
            end
            download()
        end)
    end
    function client:Tick()
        if self.state=='ready' then return end
        if waiting and now()>deadline then fail();return end
        if job then
            local current=job
            local ok=coroutine.resume(current)
            if not ok then fail()
            elseif current==job and coroutine.status(current)=='dead' then job=nil end
        elseif not waiting and now()>=nextCheck then begin() end
    end
    if base and env.io and env.loadstring and env.GetWebResultAsync and env.GetTickCount and env.Callback then
        env.Callback.Add('Tick',function()
            local sdk=env.SDK;local input=sdk and sdk.Input
            if input and (input.Step~=0 or input.InFlight and input.InFlight>0) then return end
            local modes=sdk and sdk.Orbwalker and sdk.Orbwalker.Modes
            if modes then for _,active in pairs(modes) do if active then return end end end
            local spell=env.myHero and env.myHero.activeSpell
            if spell and spell.valid then return end
            local ok=pcall(client.Tick,client)
            if not ok then fail() end
        end)
    end
    return client
end

end)()
client=create(_G,hash,6,"https://raw.githubusercontent.com/LeeHarveyOsward/runtime-files",{names={'KataHari'},channel='katahari',cachePrefix='runtime-katahari-'})
_G.KataHariReleaseClient=client
end
return client:Boot("KataHari",function()
-- Generated by tools/build_katarina.py; edit Scripts/Common/Katarina.
if not myHero or (myHero.charName~='Katarina' and myHero.charName~='Jade_Katarina') then return end
local function boot()
local generation='b16bf6e714082f88b213a9e759bb5ee6913aa204c78352710aa8b482a84ecd9a'
if not SDK or not SDK.OrbamaVersion or not SDK.Actions or not SDK.Actions.GetCapabilities or not SDK.Actions:GetCapabilities().createClient
 or not SDK.Damage or not SDK.TargetSelector or not SDK.SharedData or not SDK.OnTick or not SDK.OnDraw or not SDK.OnWndMsg then
 print('[Kata Hari] Enable Orbama and reload the script runtime.');return
end
local previous=_G.KatarinaController
if previous and previous.active then
 if previous.hero==myHero and previous.sdk==SDK and previous.generation==generation then return previous end
 local ok=pcall(previous.Shutdown,previous,'replacement')
 if not ok or previous.active then return end
end
local modules,cache={},{}
local externalRequire=require
modules["ChampionMobility.navigation"]=function(require)
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

end
modules["ChampionMobility.terrain"]=function(require)
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

end
modules["ChampionMobility.wards"]=function(require)
return function(U)
local W={}
function W:itemReady(slot,item,owned)
    local c=self.ctx;item=item or myHero:GetItemData(slot)
    if not item or not c.profile.wards[item.itemID] then return false end
    local d=c:spell(slot)
    if (d.currentCd or 0)>0 or self.actions.pending[slot] and not owned then return false end
    if c.profile.wardInventoryCharges and c.profile.wardInventoryCharges[item.itemID]
        and U.finite(item.ammo) and item.ammo>=0 and item.ammo==0 then return false end
    if c:ready(slot) then return true end
    -- GG's item readiness uses currentCd. Classic Sightstone can expose zero
    -- spell ammo while its inventory has charges; do not let the summoner /
    -- spell-ammo readiness check veto that supported inventory representation.
    if c.profile.wardInventoryCharges and c.profile.wardInventoryCharges[item.itemID]
        or c.profile.id=='classic' and c.profile.wards[item.itemID]=='stack' then
        return d.currentCd==0 and math.max(d.ammo or 0,item.ammo or 0,U.stackCount(item))>0 and (owned or not self.actions.pending[slot])
    end
    return false
end
function W:hasCharges(slot,item)
    local c=self.ctx;item=item or myHero:GetItemData(slot)
    local kind=item and c.profile.wards[item.itemID];if not kind then return false end
    local charge=c:spell(slot).ammo
    if c.profile.wardInventoryCharges and c.profile.wardInventoryCharges[item.itemID]then
        charge=U.finite(item.ammo)and item.ammo>=0 and item.ammo or math.max(charge or 0,U.stackCount(item))
    elseif charge==nil or charge<0 then
        charge=item.ammo
        if(charge==nil or charge<0)and kind~='stored'then charge=item.stackCount end
    end
    local count=math.max(U.stackCount(item),item.ammo or 0)
    return kind=='cooldown'or((kind=='charge'or kind=='stored')and charge and charge>0)
        or(kind=='stack'and(count>0 or charge and charge>0))or false
end
function W:slot(itemID)
    local c=self.ctx;local best,bestRank=nil,math.huge
    for slot=6,12 do
        local item=myHero:GetItemData(slot);local kind=item and c.profile.wards[item.itemID]
        if kind and (not itemID or item.itemID==itemID) and self:itemReady(slot,item) then
            local available=self:hasCharges(slot,item)
            if available then
                -- Resource preference is independent of the inventory slot and
                -- of how the item reports readiness / charges.
                local rank=item.itemID==c.profile.yellowWard and 1 or kind=='charge' and 2
                    or kind=='cooldown' and 3 or 4
                if c.profile.id=='classic' and kind=='stack' then rank=item.itemID==772043 and 5 or 4 end
                if rank<bestRank then best,bestRank=slot,rank end
            end
        end
    end
    return best
end

return W
end

end
modules["kata.actions"]=function(require)
local U=require('kata.util')
local A={};A.__index=A
function A.new(c)
    local self=setmetatable({c=c,pending={},history={}},A)
    self.client=c.sdk.Actions:CreateClient({name='Katarina',active=function()return c.active and c.sdk==SDK end})
    if self.client.CooperateWithEvade then
        self.client:CooperateWithEvade({committed=function()return c.state:channel()==true or self.pending[3]~=nil end,
            yield=function(evidence)
                if not evidence.likelyDeath then return false end
                self.client:YieldUnsent();c.mobility:cancel('evade_emergency')
                self.client:SetBlocked('channel','attack',false);self.client:SetBlocked('channel','move',false)
                return true
            end})
        self.client:RegisterEmergencyYield(function(resource)return self.client:YieldUnsent(resource)end)
    end
    self.client:Condition('channel','channel',function(q)
        return q.resource=='slot:3'or not c.state:channel()and not self.pending[3]
    end,{release=true})
    return self
end
function A:key(slot)
    if slot<6 then return ({[0]=HK_Q,[1]=HK_W,[2]=HK_E,[3]=HK_R,[4]=HK_SUMMONER_1,[5]=HK_SUMMONER_2})[slot]end
    return ({[6]=HK_ITEM_1,[7]=HK_ITEM_2,[8]=HK_ITEM_3,[9]=HK_ITEM_4,[10]=HK_ITEM_5,[11]=HK_ITEM_6,[12]=HK_ITEM_7})[slot]
end
function A:context(owner)
    local c=self.c
    return {condition=function()return c:available()and c:ownerActive(owner)end}
end
function A:submit(a)
    local c=self.c;local resource=a.slot or a.kind or 'move'
    local prior=self.pending[resource]
    if prior then
        if prior.a.owner==a.owner and U.id(prior.a.target)==U.id(a.target)and a.priority then self.client:UpdatePriority(prior.id,a.priority)end
        return false,'resource_pending'
    end
    local key=a.slot and self:key(a.slot)
    if a.slot and not key then return false,'missing_slot_key'end
    local origin=U.copy(c.hero.pos);local identity=U.id(a.anchor or a.target)
    local q={owner=a.owner,resource=a.slot and 'slot:'..a.slot or resource,priority=a.priority or 'normal',
        expires=self.client:Now()+(a.ttl or 350),context=self:context(a.owner),targetID=identity,
        exceptions=a.release and {channel='release'}or nil,
        mechanical=function(resolved)
            if a.slot and not c.state:ready(a.slot)then return false,'spell_not_ready'end
            if identity and U.id(a.anchor or a.target)~=identity then return false,'target_identity_changed'end
            return c:legal(a,resolved and resolved.position)
        end,
        reconcile=function()
            local active=c.hero.activeSpell
            -- Shutdown may retire this client while its physical send settles.
            -- A fresh readable cooldown permits releasing the lease without declaring a hit.
            local spell=a.slot and c.state:spell(a.slot)
            return c.sdk==SDK and c.hero==myHero and not(active and active.valid)
                and(not a.slot or U.finite(spell.currentCd)and(spell.currentCd>0 or c.state:ready(a.slot)))
        end,
        independent=a.owner=='combo'or a.owner=='harass'}
    local selfCast=a.slot==1 or a.slot==3 or a.rule and a.rule.active=='stasis'
    local aim=not selfCast and(a.pos or a.target)or nil
    if a.pos then
        q.kind='world'
        if a.anchor then q.resolve=function()
            local pos=c:landing(a.anchor,a.target,a.side,a.dagger)
            if not pos or U.dist(pos,a.pos)>160 then return nil,'landing_budget_exceeded'end
            return {position=pos}
        end end
    elseif a.target and not selfCast then q.kind='object'else q.kind='none'end
    if a.kind=='move'then q.kind='world';q.independent=false end
    local id,why
    if a.kind=='move'then
        if a.release then self.client:SetBlocked('channel','move',false)end
        id,why=self.client:Move(aim,q)
    elseif a.kind=='attack'then id,why=self.client:Attack(a.target,q)
    else id,why=self.client:Cast(key,aim,q)end
    if not id then c:log('rejected',a,why);return false,why end
    a.actionID=id
    local record={id=id,a=a,origin=origin,event=c.state.serial,at=Game.Timer(),resource=resource,
        generation=c.manualGeneration or 0,oldCd=a.slot and c.state:spell(a.slot).currentCd}
    self.pending[resource]=record;c:log('requested',a,id);return true,record
end
function A:tick()
    local c=self.c;self.client:Tick()
    for resource,q in pairs(self.pending)do
        local r=self.client:Poll(q.id)
        if r then
            if q.status~=r.state then q.status=r.state;c:log(r.state,q.a,r.reason)end
            if r.sentAt and not q.sentTime then q.sentTime=Game.Timer()-(self.client:Now()-r.sentAt)/1000 end
            if r.sentAt and not r.mechanical and not q.observed then
                local event=q.a.slot and c.state.events[q.a.slot]
                local attributable=(c.manualGeneration or 0)==q.generation
                local observed=attributable and event and event.serial>q.event and event.at>=q.sentTime-.02
                -- Blink evidence needs actual displacement, an intended endpoint and no competing manual spell.
                if not observed and attributable and q.a.slot==2 then
                    local pos=q.a.pos or(q.a.target and q.a.target.pos)
                    observed=pos and not c.state:ready(2)and U.dist(q.origin,c.hero.pos)>100 and U.dist(c.hero.pos,pos)<100 and Game.Timer()-q.sentTime<.5
                end
                if observed then
                    local ok=self.client:Observe(q.id,{kind='mechanical',unique=true,source=event and event.source or 'blink_position',at=self.client:Now()})
                    if ok then
                        q.observed=true;c.state:expect(q.a.slot,q.origin,q.a.target);c:log('mechanical',q.a,q.id)
                        if q.a.slot==2 and q.a.owner=='harass'then c.trade={origin=q.origin,at=Game.Timer(),expires=Game.Timer()+2,target=q.a.combatTarget or q.a.target}end
                    end
                end
            end
            if r.state=='cancelled_before_send'or q.observed or r.mechanical then
                self.client:Finish(q.id)
            elseif r.sentAt then self.client:Reconcile(q.id)end
            if not self.client.jobs[q.id]then
                q.finished=true;self.history[#self.history+1]=q
                if #self.history>32 then table.remove(self.history,1)end
                self.pending[resource]=nil
            end
        end
    end
end
function A:cancel(owner,why)
    -- Do not remove the permanent channel condition by cancelling its owner.
    for _,q in pairs(self.pending)do if not owner or q.a.owner==owner then self.client:Cancel(q.id,why)end end
end
function A:close()self.client:Close('Katarina shutdown')end
return A

end
modules["kata.app"]=function(require)
local U=require('kata.util');local Profiles=require('kata.profiles')
local App={};App.__index=App
function App.new()
    return setmetatable({hero=myHero,sdk=SDK,active=true,build=Profiles.build,callbacks={},manualGeneration=0,enemies={},allies={},minions={}},App)
end
function App:init()
    self.profile=assert(Profiles.select(myHero.charName))
    self.config=require('kata.config').new(self.profile)
    self.state=require('kata.state').new(self)
    self.actions=require('kata.actions').new(self)
    self.session=tostring(self.actions.client:Now())
    self.items=require('kata.items').new(self)
    self.damage=require('kata.damage').new(self)
    self.planner=require('kata.planner').new(self)
    self.mobility=require('kata.mobility').new(self)
    return self
end
function App:now()return Game.Timer()end
function App:spell(slot)return self.state:spell(slot)end
function App:ready(slot)return not self.actions.pending[slot]and self.state:ready(slot)end
function App:mouse()
    local p=Game.mousePos
    if type(p)=='function'then local ok,value=pcall(p);p=ok and value or nil end
    return U.copy(p)or U.copy(mousePos)
end
function App:mode()
    local m=self.sdk.Orbwalker.Modes
    for _,row in ipairs({{'flee','ORBWALKER_MODE_FLEE'},{'combo','ORBWALKER_MODE_COMBO'},{'harass','ORBWALKER_MODE_HARASS'},
        {'last','ORBWALKER_MODE_LASTHIT'},{'lane','ORBWALKER_MODE_LANECLEAR'},{'jungle','ORBWALKER_MODE_JUNGLECLEAR'}})do
        if self.sdk[row[2]]and m[self.sdk[row[2]]]then return row[1]end
    end
end
function App:ownerActive(owner)
    if owner=='defense'then return true end
    if owner=='jump'then return self.config:get('jump')==true and not self.mobility.doneHeld end
    if owner=='idle'then return self.config:get('idleKill')and not self:mode()end
    if owner=='lane'or owner=='jungle'then
        local mode=self:mode();local id=self.sdk[owner=='lane'and 'ORBWALKER_MODE_LANECLEAR'or 'ORBWALKER_MODE_JUNGLECLEAR']
        return (mode=='lane'or mode=='jungle')and self.sdk.Orbwalker.Modes[id]==true
    end
    return self:mode()==owner
end
function App:available()
    return self.active and self.sdk==SDK and self.hero==myHero and myHero.charName==self.profile.hero and self.config:get('enabled')
        and not myHero.dead and not Game.IsChatOpen()and Game.IsOnTop()
        and not U.buff(myHero,{recall=true,recallimproved=true,zhonyasringshield=true},Game.Timer())
end
function App:anchorValid(o,origin)
    local d=self.state.daggers[U.id(o)]
    if d then return self.profile.id=='normal'and self.state:daggerValid(d)and U.dist(origin or self.hero.pos,d.pos)<=self.profile.eRange end
    if not U.valid(o)or U.same(o,self.hero)or U.dist(origin or self.hero.pos,o.pos)>self.profile.eRange then return false end
    local id=U.id(o)
    for _,w in ipairs(self.state.objects.wards or {})do if U.id(w)==id then
        local n=U.name(w.charName)
        return self.profile.id=='classic'and w.team==self.hero.team and n~='bluetrinket'and n~='farsightward'and n~='zombieward'
    end end
    -- A new ward can precede SharedData's identity refresh.
    if U.name(o.charName):find('ward',1,true)then return self.profile.id=='classic'and o.team==self.hero.team and U.name(o.charName)~='farsightward'and U.name(o.charName)~='zombieward'end
    for _,kind in ipairs({'heroes','minions'})do for _,x in ipairs(self.state.objects[kind]or {})do if U.id(x)==id then return true end end end
    return false
end
function App:anchors()
    local out,seen={},{}
    local function add(o)if #out<64 and U.id(o)and not seen[U.id(o)]and self:anchorValid(o)then out[#out+1]=o;seen[U.id(o)]=true end end
    for _,o in ipairs(self.state.objects.heroes or {})do add(o)end
    for _,d in pairs(self.state.daggers)do add(d.object)end
    for _,o in ipairs(self.state.objects.minions or {})do add(o)end
    if self.profile.id=='classic'then for _,o in ipairs(self.state.objects.wards or {})do add(o)end end
    return out
end
function App:landing(anchor,target,side,dagger)
    if not self:anchorValid(anchor)then return end
    local pos=dagger and dagger.pos or anchor.pos
    if self.profile.id=='classic'then return U.copy(pos)end
    if side then if U.dist(pos,side)<=self.profile.eOffset then return U.copy(side)else return end end
    local toward=target and U.predict(target,.15)or self:mouse()or self.hero.pos
    return U.toward(pos,toward,math.min(100,U.dist(pos,toward)))
end
function App:hasReturn(pos,used)
    -- E has just been spent. An ally in range is not an immediately available escape.
    return U.dist(pos,self.hero.pos)<=550 and not self.state:turret(pos)
        and self.mobility.terrain:walkLine(pos,self.hero.pos,self.hero.boundingRadius or 35)==true
end
function App:attackRange(o)return(self.hero.range or 125)+(self.hero.boundingRadius or 35)+(o.boundingRadius or 35)end
function App:healthPrediction(o,delay)
    local hp=self.sdk.HealthPrediction or self.sdk.Health
    if hp and hp.GetPrediction then return hp:GetPrediction(o,delay)end
    return o.health
end
function App:aaSaves(o,deadline)
    local attack=self.sdk.Attack
    if U.dist(self.hero.pos,o.pos)>self:attackRange(o)then return false end
    local delay=attack and attack.GetWindup and attack:GetWindup()or .3
    if delay>deadline or (self.sdk.Orbwalker.CanAttack and not self.sdk.Orbwalker:CanAttack())then return false end
    return self.damage:amount('AA',o)>=self:healthPrediction(o,delay)
end
function App:legal(a,resolved,farmFacts)
    if not self:available()or not self:ownerActive(a.owner)then return false,'context_ended'end
    if a.validate then local ok,why=a.validate();if not ok then return false,why or 'dependent_validation'end end
    local pos=resolved or a.pos;local t=a.combatTarget or a.target
    if a.slot and a.slot<=3 and(a.owner=='combo'or a.owner=='harass'or a.owner=='lane'or a.owner=='jungle'or a.owner=='last')then
        if not self.config:get(a.owner..({'Q','W','E','R'})[a.slot+1])then return false,'spell_setting_disabled'end
    end
    if a.farm and U.valid(t)then
        local impact=a.slot==0 and .25+U.dist(self.hero.pos,t.pos)/self.profile.qSpeed or .2
        -- Only the synchronous planner lends these facts. They are never put
        -- on the action; queued dispatch calls legal() without them.
        local facts=farmFacts and farmFacts.target==t and farmFacts.impact==impact
            and farmFacts.at==Game.Timer()and farmFacts.observedHP==t.health and farmFacts
        local hp=facts and facts.hp or self:healthPrediction(t,impact)
        if hp<=0 then return false,'already_dying_to_incoming_hit'end
        if a.owner=='last'then
            local damage=facts and facts.damage or self.damage:amount(a.slot,t)
            local saved
            if facts and facts.aaSaved~=nil then saved=facts.aaSaved else saved=self:aaSaves(t,impact)end
            if damage<hp or saved then return false,'last_hit_no_longer_needed'end
        end
    end
    if self.state:channel()and a.owner=='combo'and a.release then
        local emptyMove=a.kind=='move'and self.config:get('smartR')and self.state:enemiesNear(self.hero.pos,self.profile.rRange)==0
        if not emptyMove and(not a.slot or a.slot>=6 or not U.valid(t)or not self.damage:lethal(a.slot,t,.3)or self.damage:lethal(3,t,.34))then
            return false,'r_followup_no_longer_better'
        end
    end
    if a.extended and(not self.config:get('extended')or self:mode()~='combo')then return false,'extended_consent_ended'end
    if a.kind=='move'then return U.position(pos)and self.mobility.terrain:wall(pos)==false,'movement_terrain_unknown'end
    if a.kind=='attack'then return U.valid(t)and U.dist(self.hero.pos,t.pos)<=self:attackRange(t),'attack_invalid'end
    if a.ward then return true end
    if a.rule then
        local item=self.hero:GetItemData(a.slot)
        if not item or item.itemID~=a.itemID or not self.items:enabled(a.itemID)then return false,'item_changed'end
        if a.rule.active=='stasis'then return self.items:stasisNeeded(),'stasis_not_needed'end
        if a.rule.active=='move'then return a.extended and self.planner:safe(pos,t),'movement_item_unsafe'end
        return U.valid(t)and U.dist(self.hero.pos,t.pos)<=a.rule.range and not self.damage:protected(t),'item_target_invalid'
    end
    if a.slot==1 and a.prepareWall then return a.owner=='jump'or a.owner=='flee','wall_context'end
    if not U.valid(t)and not a.dagger then return false,'invalid_target'end
    if t and t.team~=self.hero.team and not a.escape and(self.damage:protected(t)or self.damage:spellShield(t))then return false,'target_protected'end
    if a.slot==0 then return U.dist(self.hero.pos,t.pos)<=self.profile.qRange,'q_range'end
    if a.slot==1 then return U.dist(self.hero.pos,t.pos)<=self.profile.wRange,'w_range'end
    if a.slot==2 then
        local anchor=a.anchor or t;local landing=pos or anchor.pos
        if not self:anchorValid(anchor)then return false,'e_anchor_invalid'end
        if self.profile.id=='normal'and U.dist(landing,anchor.pos)>self.profile.eOffset then return false,'e_offset'end
        if pos and self.mobility.terrain:wall(pos)~=false then return false,'e_terrain_unknown'end
        if not self.planner:safe(landing,t,a.escape)then return false,'e_safety'end
        -- Avoid selecting a different overlapping E anchor at the outgoing aim.
        if pos then for _,o in ipairs(self:anchors())do
            if not U.same(o,anchor)and U.dist(o.pos,pos)+5<U.dist(anchor.pos,pos)then return false,'e_ambiguous_anchor'end
        end end
        if a.owner=='harass'and(not self:hasReturn(landing,anchor)or self.state:enemiesNear(landing,450)>1)then return false,'harass_no_return'end
        return true
    end
    if a.slot==3 then return not self.state:channel()and not self.state:interruptIncoming()and self.state:enemiesNear(self.hero.pos,self.profile.rActivation)>0,'r_activation_or_observed_interrupt'end
    if a.slot==4 or a.slot==5 then
        local name=U.name(self.state:spell(a.slot).name)
        if name=='summonerflash'then return a.extended and U.dist(self.hero.pos,pos)<=400 and self.mobility.terrain:wall(pos)==false and self.planner:safe(pos,t),'flash_invalid'end
        return name=='summonerdot'and U.dist(self.hero.pos,t.pos)<=600 and self.config:get('ignite')and self.damage:lethal(a.slot,t,5),'ignite_not_lethal'
    end
    return false,'unsupported_action'
end
function App:record()end
function App:flushLog()end
function App:log()end
function App:tick()if self.active then self:decide()end end
function App:decide()
    self.state:refresh();self.items:refresh();self.actions:tick()
    if not self:available()then
        self.actions:cancel(nil,'unavailable');self.mobility:cancel('unavailable')
        self.actions.client:SetBlocked('channel','attack',false);self.actions.client:SetBlocked('channel','move',false);return
    end
    if self.sdk.Evade and type(self.sdk.Evade.Evading)=='function'and self.sdk.Evade:Evading()then
        self.actions.client:SetBlocked('channel','attack',false);self.actions.client:SetBlocked('channel','move',false);return
    end
    local channel=self.state:channel()
    local protect=channel==true or self.actions.pending[3]~=nil
    self.actions.client:SetBlocked('channel','attack',protect);self.actions.client:SetBlocked('channel','move',protect)
    local mode=self:mode();local owner=self.config:get('jump')and 'jump'or(mode=='flee'and 'flee'or nil)
    if mode~='harass'then self.trade=nil end
    local defense=self.items:activeCandidate(nil,nil)
    if defense then self.actions:submit(defense);return end
    if self.mobility:tick(owner)then return end
    local action
    if mode=='combo'or mode=='harass'then action=self.planner:combat(mode)
    elseif mode=='lane'or mode=='jungle'or mode=='last'then
        if not channel then
            action=self.planner:farm(mode)
            if not action and mode=='lane'and self:ownerActive('jungle')then action=self.planner:farm('jungle')end
        end
    elseif not mode and self.config:get('idleKill')and not channel then
        for _,o in ipairs(self.enemies)do if U.valid(o)and self:ready(0)and self.damage:lethal(0,o)then
            local a={slot=0,target=o,owner='idle'};if self:legal(a)then action=a;break end
        end end
    end
    if channel and self.config:get('smartR')and self.state:enemiesNear(self.hero.pos,self.profile.rRange)==0 and mode=='combo'then
        local pos=self:mouse();if pos then action={kind='move',pos=pos,owner='combo',release=true}end
    end
    self.preview=action
    if action then if action.kind=='wardplan'then self.mobility:start(action.pos,action.owner,action.target)else self.actions:submit(action)end end
end
function App:draw()
    if not self.active or not self.config:get('draw')or not Draw then return end
    local p=self.mobility.preview or self.preview
    if p and p.pos and Draw.Circle then Draw.Circle(U.vector(p.pos),65,2,Draw.Color(220,120,230,180))end
    local action=self.preview;local target=action and(action.combatTarget or action.target)
    if U.valid(target)and Draw.Circle then
        Draw.Circle(target.pos,target.boundingRadius or 45,1,Draw.Color(200,220,170,70))
        local screen=target.pos2D
        if screen and screen.onScreen~=false and Draw.Text and action.estimate then Draw.Text('~'..math.floor(action.estimate)..' damage',14,screen.x,screen.y-30,Draw.Color(220,220,230,200))end
    end
end
function App:event(msg,param)
    if not self.active then return end
    local cursor=self.sdk.Cursor
    if cursor and cursor.IsSyntheticEvent and cursor:IsSyntheticEvent()then return end
    if msg==256 and(param==HK_Q or param==HK_W or param==HK_E or param==HK_R)then self.manualGeneration=self.manualGeneration+1;self.actions:cancel(nil,'manual_spell')end
    if msg==516 then
        self.trade=nil
        self.mobility:cancel('manual_pointer');self.mobility.doneHeld=true
        -- A physical right click can interrupt R; never replay or suppress it.
        self.actions.client:SetBlocked('channel','move',false)
    end
end
function App:install()
    local function attach(list,fn)
        assert(type(list)=='table','SDK callback list unavailable')
        local wrapper=function(...)if not self.active then return end;local ok,why=pcall(fn,...);if not ok then self:log('error',nil,why);self:Shutdown('callback_error');print('[Katarina] '..tostring(why))end end
        list[#list+1]=wrapper;self.callbacks[#self.callbacks+1]={list=list,fn=wrapper}
    end
    attach(self.sdk.OnTick,function()self:tick()end);attach(self.sdk.OnDraw,function()self:draw()end);attach(self.sdk.OnWndMsg,function(m,p)self:event(m,p)end)
    if Callback and Callback.Add then self.unload=function()self:Shutdown('unload')end;Callback.Add('UnLoad',self.unload)end
    self.loadedAt=Game.Timer();self.state:refresh();self.items:refresh();self:log('controller_ready',nil,self.build);self:flushLog(true)
end
function App:Shutdown(reason)
    if not self.active then return end;self.active=false
    if self.actions then self.actions:close()end
    for _,row in ipairs(self.callbacks)do for i=#row.list,1,-1 do if row.list[i]==row.fn then table.remove(row.list,i)end end end
    self.callbacks={}
    if self.unload and Callback and Callback.Del then pcall(Callback.Del,'UnLoad',self.unload)end
    if self.config then self.config:close()end
    if self.logger then self:record('shutdown',{reason=reason});pcall(self.flushLog,self,true)end
    if _G.KatarinaController==self then _G.KatarinaController=nil end
end
return App

end
modules["kata.config"]=function(require)
local C={};C.__index=C
local defaults={enabled=true,comboQ=true,comboW=true,comboE=true,comboR=true,harassQ=true,harassW=true,harassE=false,
    lastQ=true,lastW=true,lastE=false,laneQ=true,laneW=true,laneE=false,jungleQ=true,jungleW=true,jungleE=false,
    idleKill=false,turret=false,ignite=true,offensiveWards=true,stasis=true,items=true,smartR=true,
    draw=true,diagnostics=false,wardAssist=true,wardApproach=true,wardRange=600,reuseRadius=100,wardWalkRange=600,
    wardAssistRadius=300,terrainVerified=false,wardFollowCursor=false,wardTolerance=75,minHP=25,maxEnemies=2,
    clearHits=3,stasisHP=20,assistRadius=300}
function C.new(profile)
    local self=setmetatable({values={},nodes={}},C)
    for k,v in pairs(defaults)do self.values[k]=v end
    -- Explicit local recording profile, separate from saved gameplay settings.
    local test=_G.OrbamaTestConfig
    if not test then local ok,value=pcall(require,'OrbamaTestConfig');if ok then test=value end end
    self.capture=type(test)=='table'and test.enabled==true and type(test.katarina)=='table'and test.katarina.diagnostics==true
    if MenuElement then
        self.menu=MenuElement({id='KatarinaController',name='Kata Hari - '..profile.id,type=MENU})
        local labels={combo='Combo',harass='Harass',last='Last hit',lane='Lane clear',jungle='Jungle clear'}
        for _,mode in ipairs({'combo','harass','last','lane','jungle'})do
            self.menu:MenuElement({id=mode,name=labels[mode],type=MENU})
            for _,letter in ipairs({'Q','W','E','R'})do local id=mode..letter
                if defaults[id]~=nil then self.menu[mode]:MenuElement({id=letter,name='Use '..letter,value=defaults[id]});self.nodes[id]=self.menu[mode][letter]end
            end
        end
        local options={{'enabled','Enabled'},{'turret','Allow turret entry'},{'idleKill','Killsecure without held mode'},
            {'ignite','Combo Ignite'},{'items','Offensive item actives'},{'stasis','Emergency stasis'},
            {'smartR','Situational ultimate cancellation'},{'wardAssist','Wall assistance'},{'wardApproach','Approach nearby wall'},
            {'draw','Draw plan'}}
        if profile.id=='classic'then options[#options+1]={'offensiveWards','Spend wards for lethal combos'}end
        for _,row in ipairs(options)do self.menu:MenuElement({id=row[1],name=row[2],value=defaults[row[1]]});self.nodes[row[1]]=self.menu[row[1]]end
        for _,row in ipairs({{'minHP','Minimum entry HP %',0,100},{'maxEnemies','Maximum nearby enemies',1,5},{'clearHits','Waveclear minimum hits',1,8},{'stasisHP','Emergency HP %',1,50}})do
            self.menu:MenuElement({id=row[1],name=row[2],value=defaults[row[1]],min=row[3],max=row[4],step=1});self.nodes[row[1]]=self.menu[row[1]]
        end
        self.menu:MenuElement({id='jump',name='Jump toward mouse (hold)',key=string.byte('T')})
        self.menu:MenuElement({id='extended',name='Allow Flash / movement items in Combo (hold)',key=string.byte('G')})
        self.nodes.jump=self.menu.jump;self.nodes.extended=self.menu.extended
    end
    return self
end
function C:get(k)if k=='diagnostics'then return false end;if k=='diagnostics'and self.capture then return true end;local node=self.nodes[k];if node then return node:Value()end;return self.values[k]end
function C:close()if self.menu and self.menu.Hide then pcall(self.menu.Hide,self.menu,true)end end
return C

end
modules["kata.damage"]=function(require)
local U=require('kata.util');local P=require('kata.profiles')
local D={};D.__index=D
-- Installed KatarinaPassive TotalDamage level table, ranks 1..18.
local passive={68.184616,72.138458,76.861542,82.353844,88.615387,95.646156,103.446152,112.015381,121.353844,131.461533,142.338455,153.984619,166.399994,179.584610,193.538467,208.261536,223.753845,240.015381}
function D.new(c)return setmetatable({c=c},D)end
function D:protected(o)return o.isImmortal==true or U.buff(o,P.protection,Game.Timer())~=nil end
function D:spellShield(o)return U.buff(o,P.spellShield,Game.Timer())~=nil end
function D:mitigate(o,kind,raw)
    if kind=='true'then return math.max(0,raw)end
    local c=self.c;local dtype=kind=='magic'and c.sdk.DAMAGE_TYPE_MAGICAL or c.sdk.DAMAGE_TYPE_PHYSICAL
    return math.max(0,c.sdk.Damage:CalculateDamage(c.hero,o,dtype,raw))
end
function D:raw(slot,o)
    local c=self.c;local p,h=c.profile,c.hero;local ap,ad=h.ap or 0,h.totalDamage or 0;local bonus=h.bonusDamage or math.max(0,ad-(h.baseDamage or ad))
    local level=h.levelData and h.levelData.lvl or 1
    if slot=='passive'then
        if p.id~='normal'then return 0,0 end
        return (passive[level]or 0)+.6*bonus+(.7+(level>=6 and .1 or 0)+(level>=11 and .1 or 0)+(level>=16 and .1 or 0))*ap,0
    end
    if slot=='AA'then return 0,ad end
    local rank=c.state:spell(slot).level or 0;if rank<=0 then return 0,0 end
    if slot==0 then return (p.qBase[rank]or 0)+p.qAP*ap,0
    elseif slot==1 then return p.id=='classic'and((p.wBase[rank]or 0)+p.wAP*ap+p.wAD*bonus)or 0,0
    elseif slot==2 then return (p.eBase[rank]or 0)+p.eAP*ap+p.eAD*ad,0
    elseif slot==3 then
        local physical=p.id=='normal'and .16*(1+3.125*math.max(0,h.bonusAttackSpeed or 0))*bonus or 0
        return (p.rBase[rank]or 0)+p.rAP*ap+(p.rAD or 0)*bonus,physical
    end
    return 0,0
end
function D:mark(o)
    local c=self.c;local rank=c.state:spell(0).level or 0
    if c.profile.id=='classic'and rank>0 and c.state:mark(o)then return (c.profile.markBase[rank]or 0)+c.profile.markAP*(c.hero.ap or 0)end
    return 0
end
function D:parts(slot,o,seconds,sim)
    sim=sim or {};sim.procs=sim.procs or {}
    if slot==3 then
        local duration=self.c.profile.rDuration;local active=self.c.hero.activeSpell
        if self.c.state:channel()and active and U.finite(active.startTime)and active.startTime>0 then
            duration=math.max(0,duration-(Game.Timer()-active.startTime))
        end
        local ticks=math.floor(math.max(0,math.min(seconds or .5,duration))*self.c.profile.rTicks+1e-6)
        local total={magic=0,physical=0,trueDamage=0}
        local work=self:pool(o,sim.hp or o.health);work.markUsed=sim.markUsed;work.procs=sim.procs
        local baseMagic,basePhysical,onhitRatio
        for tick=1,ticks do
            if work.hp<=0 then break end
            if U.dist(self.c.hero.pos,U.predict(o,tick/self.c.profile.rTicks))<=self.c.profile.rRange then
            if baseMagic==nil then
                baseMagic,basePhysical=self:raw(3,o)
                if self.c.profile.id=='normal'then onhitRatio=self.c.profile.rOnHit[self.c.state:spell(3).level]or 0 end
            end
            local m,p=baseMagic,basePhysical
            if not work.markUsed then m=m+self:mark(o);work.markUsed=true end
            if self.c.profile.id=='normal'then
                local a,b=self.c.items:onhit(o,work,3)
                m=m+a*onhitRatio;p=p+b*onhitRatio
            end
            local hit={magic=self:mitigate(o,'magic',m),physical=self:mitigate(o,'physical',p),trueDamage=0}
            total.magic=total.magic+hit.magic;total.physical=total.physical+hit.physical;self:apply(work,hit)
            end
        end
        sim.markUsed=work.markUsed;return total
    end
    local magic,physical=self:raw(slot,o);local trueDamage=0
    if slot==4 or slot==5 then trueDamage=(50+20*(self.c.hero.levelData.lvl or 1))*math.min(1,(seconds or 5)/5);magic=0;physical=0 end
    if slot~='passive'and slot~=0 and slot~=4 and slot~=5 and not(sim and sim.markUsed)then magic=magic+self:mark(o);if sim then sim.markUsed=true end end
    if slot=='AA'or self.c.profile.id=='normal'and(slot==2 or slot=='passive'or slot==3)then
        local m,p=self.c.items:onhit(o,sim,slot);magic=magic+m;physical=physical+p
    end
    return {magic=self:mitigate(o,'magic',magic),physical=self:mitigate(o,'physical',physical),trueDamage=trueDamage}
end
function D:pool(o,hp)return {hp=hp or o.health,magic=o.shieldAP or 0,physical=o.shieldAD or 0,all=o.allShield or 0,markUsed=false,procs={}}end
function D:apply(pool,parts)
    for _,kind in ipairs({'magic','physical','trueDamage'})do
        local value=parts[kind]or 0
        if pool[kind]then local n=math.min(value,pool[kind]);pool[kind]=pool[kind]-n;value=value-n end
        local n=math.min(value,pool.all);pool.all=pool.all-n;value=value-n;pool.hp=math.max(0,pool.hp-value)
    end
    return pool.hp
end
function D:lethal(slot,o,seconds)
    if self:protected(o)or(slot~='AA'and self:spellShield(o))then return false end
    local pool=self:pool(o,(o.health or 0)+10+(o.hpRegen or 0)*(seconds or .3))
    return self:apply(pool,self:parts(slot,o,seconds,pool))<=0
end
function D:amount(slot,o,seconds)local x=self:parts(slot,o,seconds,{});return x.magic+x.physical+x.trueDamage end
return D

end
modules["kata.items"]=function(require)
local U=require('kata.util')
local I={};I.__index=I
-- Explicit scope: no stacking/periodic/rune damage is invented for unsupported effects.
-- Modern on-hit values below match the active Orbama item mechanics; provenance in docs.
local normal={
    [3115]={onhit='nashor'},[3153]={onhit='bork'},[3091]={onhit='wits'},[3124]={onhit='rage'},[3302]={onhit='rage'},
    [6672]={onhit='kraken',attackOnly=true},
    [3100]={onhit='lich',buff={lichbane=true}},[3057]={onhit='sheen',buff={sheen=true}},[3078]={onhit='trinity',buff={['3078trinityforce']=true}},
    [3157]={active='stasis',range=0},[3152]={active='move',range=275},[3146]={active='target',range=600,unknownDamage=true}}
local classic={
    [773157]={active='stasis',range=0},[773128]={active='amplify',range=750,maxHP=.15,amp=1.2},
    [773146]={active='target',range=600,unknownDamage=true},[773144]={active='target',range=450,raw=100},
    [773153]={active='target',range=450,maxHP=.15}}
local labels={[3157]="Zhonya's Hourglass",[773157]="Zhonya's Hourglass",[3152]='Hextech Rocketbelt',
    [3146]='Hextech Gunblade',[773146]='Hextech Gunblade',[773128]='Deathfire Grasp',
    [773144]='Bilgewater Cutlass',[773153]='Blade of the Ruined King'}
function I.new(c)return setmetatable({c=c,inventory={},catalog=c.profile.id=='classic'and classic or normal},I)end
function I:refresh()
    self.inventory={}
    for slot=6,12 do local item=self.c.hero:GetItemData(slot);if item and(item.itemID or 0)>0 then
        self.inventory[slot]={id=item.itemID,rule=self.catalog[item.itemID],data=item}
        if self.c.config.menu and self.catalog[item.itemID]and self.catalog[item.itemID].active then
            local key='item'..item.itemID
            if not self.c.config.nodes[key]then self.c.config.menu:MenuElement({id=key,name='Use '..labels[item.itemID],value=true});self.c.config.nodes[key]=self.c.config.menu[key]end
        end
    end end
end
function I:enabled(id)local v=self.c.config:get('item'..id);return v~=false end
function I:damage(rule,target)
    local raw=rule.raw or rule.maxHP and rule.maxHP*(target.maxHealth or 0)or 0
    if self.c.profile.id=='classic'and rule.active=='target'and rule.maxHP then raw=math.max(100,raw)end
    return self.c.damage:mitigate(target,'magic',raw)
end
function I:onhit(o,sim,trigger)
    local h=self.c.hero;local m,p=0,0;sim=sim or {};sim.procs=sim.procs or {}
    for _,item in pairs(self.inventory)do local r=item.rule
        if r and r.onhit and(not r.attackOnly or trigger=='AA')and(not r.buff or not sim.procs.spellblade and U.buff(h,r.buff,Game.Timer()))then
            local value=0
            if r.onhit=='nashor'then m=m+15+.15*(h.ap or 0)
            elseif r.onhit=='wits'then m=m+45
            elseif r.onhit=='rage'then m=m+30
            elseif r.onhit=='bork'then value=(sim.hp or o.health)*.09;if o.type~=h.type then value=math.min(100,value)end;p=p+value
            elseif r.onhit=='kraken'then
                local buff=U.buff(h,{['6672buff']=true},Game.Timer())
                if not sim.procs.kraken and buff and buff.count==2 then
                    local level=h.levelData.lvl;p=p+(150+math.max(0,level-8)*5)*(1+.75*(1-math.min(1,(sim.hp or o.health)/math.max(1,o.maxHealth))))
                    sim.procs.kraken=true
                end
            elseif r.onhit=='lich'then m=m+.75*(h.baseDamage or 0)+.4*(h.ap or 0)
            elseif r.onhit=='sheen'then p=p+(h.baseDamage or 0)
            elseif r.onhit=='trinity'then p=p+2*(h.baseDamage or 0)end
            if r.buff then sim.procs.spellblade=true end
        end
    end
    return m,p
end
function I:stasisNeeded()
    local c=self.c
    if not c.config:get('stasis')then return false end
    local hp=c.sdk.HealthPrediction or c.sdk.Health
    if hp and hp.GetIncoming and next(hp:GetIncoming(c.hero.handle))and c:healthPrediction(c.hero,.45)<=0 then return true end
    if U.hp(c.hero)>c.config:get('stasisHP')then return false end
    -- Require an attributable attack/cast targeting Katarina, not just nearby enemies.
    for _,o in ipairs(c.enemies)do
        local a=U.valid(o)and o.activeSpell
        if a and a.valid and(a.target==U.id(c.hero)or a.target==c.hero.handle)
            and(a.castEndTime or a.endTime or 0)>=Game.Timer()then return true end
    end
    return false
end
function I:activeCandidate(target,mode)
    for slot,item in pairs(self.inventory)do local r=item.rule
        if r and r.active and self:enabled(item.id)and self.c:ready(slot)then
            if r.active=='stasis'and self:stasisNeeded()then return {slot=slot,owner='defense',rule=r,itemID=item.id,release=true,priority='critical'}end
            if mode=='combo'and U.valid(target)and self.c.config:get('items')and not self.c.damage:protected(target)then
                if (r.active=='target'or r.active=='amplify')and U.dist(self.c.hero.pos,target.pos)<=r.range then
                    return {slot=slot,target=target,owner=mode,rule=r,itemID=item.id,score=r.active=='amplify'and 700 or 80}
                end
            end
        end
    end
end
return I

end
modules["kata.mobility"]=function(require)
local U=require('kata.util');local Ward=require('ChampionMobility.wards')(U)
local Nav=require('ChampionMobility.navigation')(U,require('kata.navdata'))
local Terrain=require('ChampionMobility.terrain')(U,Nav)
local M={};M.__index=M
function M.new(c)
    local wardContext={profile=c.profile,spell=function(_,slot)return c:spell(slot)end,ready=function(_,slot)return c.state:ready(slot)end}
    local self=setmetatable({c=c,ctx=wardContext,actions=c.actions,doneHeld=false},M)
    self.terrain=Terrain.new(c);return self
end
M.itemReady=Ward.itemReady;M.slot=Ward.slot;M.hasCharges=Ward.hasCharges
function M:cancel(reason)
    if self.pending then self.c.actions:cancel(self.pending.owner,reason);self.pending=nil end
    self.preview=nil;self.job=nil
end
function M:existing(pos)
    local best,dist
    for _,o in ipairs(self.c:anchors())do local d=U.dist(o.pos,pos)
        if self.c:anchorValid(o)and d<150 and(not dist or d<dist)then best,dist=o,d end
    end
    return best
end
function M:start(pos,owner,target)
    local c=self.c
    if self.pending or not c:ready(2)then return false end
    local anchor=self:existing(pos)
    if anchor then
        local a={slot=2,target=anchor,anchor=anchor,dagger=c.state.daggers[U.id(anchor)],owner=owner,escape=owner~='combo',release=true,
            pos=c.profile.id=='normal'and c:landing(anchor,nil,nil,c.state.daggers[U.id(anchor)])or nil}
        local ok,record=c.actions:submit(a)
        if ok then self.pending={state='jumping',owner=owner,event=record,at=Game.Timer(),expires=Game.Timer()+2};return true end
        return false
    end
    if c.profile.id=='normal'then return false end
    local slot=self:slot();if not slot or U.dist(c.hero.pos,pos)>c.config:get('wardRange')or self.terrain:wall(pos)~=false then return false end
    if not c.planner:safe(pos,target,owner~='combo')then return false end
    if owner=='combo'and(not U.valid(target)or not c.planner:estimate(target,pos,2).lethal or not c.planner:safe(pos,target))then return false end
    local ids={};for _,w in ipairs(c.state.objects.wards or {})do if U.id(w)then ids[U.id(w)]=true end end
    local p={state='placing',owner=owner,pos=U.copy(pos),ids=ids,target=target,at=Game.Timer(),expires=Game.Timer()+2}
    local ok,record=c.actions:submit({slot=slot,pos=pos,owner=owner,ward=true,release=true,
        validate=function()return c.state:ready(2)and self:itemReady(slot,nil,true)and self:hasCharges(slot)and self.terrain:wall(pos)==false and c.planner:safe(pos,target,owner~='combo')
            and U.dist(c.hero.pos,pos)<=c.config:get('wardRange')and(owner~='combo'or U.valid(target)and c.planner:estimate(target,pos,2).lethal and c.planner:safe(pos,target))end})
    if ok then p.event=record;self.pending=p;return true end
    return false
end
function M:advance()
    local c=self.c;local p=self.pending;if not p then return false end
    if not c:ownerActive(p.owner)or Game.Timer()>p.expires then self:cancel('jump_context_expired');return false end
    if p.state=='placing'then
        local raw=c.actions.client:Poll(p.event.id)
        if raw and raw.state=='cancelled_before_send'then self:cancel('ward_not_sent');return false end
        if raw and raw.sentAt then
            local match
            for i=1,U.count(Game.WardCount and Game.WardCount()or 0,512)do local w=Game.Ward(i)
                local owner=w and(w.ownerID or w.ownerNetworkID)
                if U.valid(w)and w.team==c.hero.team and not p.ids[U.id(w)]and U.dist(w.pos,p.pos)<90
                    and(not owner or owner==0 or owner==U.id(c.hero)or owner==c.hero.handle)then
                    if match then self:cancel('ambiguous_new_wards');return false end;match=w
                end
            end
            if match then
                c.actions.client:Observe(p.event.id,{kind='mechanical',unique=true,at=c.actions.client:Now(),source='new_ward_identity'})
                p.event.observed=true;p.anchor=match;p.state='ward_ready'
            end
        end
    end
    if p.state=='ward_ready'then
        if not c:anchorValid(p.anchor)then self:cancel('ward_lost');return false end
        local function check()
            return U.valid(p.anchor)and c:anchorValid(p.anchor)and(p.owner~='combo'or U.valid(p.target)and c.planner:estimate(p.target,p.anchor.pos,2).lethal and c.planner:safe(p.anchor.pos,p.target))
        end
        if not check()then self:cancel('followup_no_longer_valid');return false end
        local ok,event=c.actions:submit({slot=2,target=p.anchor,anchor=p.anchor,owner=p.owner,escape=p.owner~='combo',release=true,validate=check})
        if ok then p.event=event;p.state='jumping'end
    end
    if p.state=='jumping'then
        if p.event.observed then self.doneHeld=true;self.pending=nil;return false end
        if p.event.finished then self:cancel('jump_unconfirmed');return false end
    end
    return true
end
function M:plan(raw)
    local c=self.c;local p
    if not c.config:get('wardAssist')then return end
    if c.profile.id=='classic'then
        local direct=self.terrain:landing(c.hero.pos,raw,math.min(c.profile.eRange,c.config:get('wardRange')),self.preview)
        if direct and direct.valid then self.preview=direct;return direct end
        if not c.config:get('wardApproach')then return direct end
        if not self.job or U.dist(self.job.raw,raw)>75 then
            self.job={raw=U.copy(raw),work=coroutine.create(function()
                return self.terrain:plan(U.copy(c.hero.pos),raw,math.min(c.profile.eRange,c.config:get('wardRange')),self.preview,function()coroutine.yield()end,direct)
            end)}
        end
        local ok,result=coroutine.resume(self.job.work)
        if not ok then self.job=nil;return end
        if coroutine.status(self.job.work)=='dead'then self.job=nil;if result and result.valid then self.preview=result end end
        p=self.preview
    else
        -- W stays on the near side. Only a real, correlated dagger authorizes E.
        local entry,exit=self.terrain:cursorCrossing(c.hero.pos,raw,250)
        if entry and exit and U.dist(entry,exit)<=200 then
            local near=U.toward(entry,c.hero.pos,45);local far=U.toward(exit,raw,40)
            if self.terrain:wall(near)==false and self.terrain:wall(far)==false and U.dist(near,far)<=c.profile.eOffset then
                p={valid=true,stand=near,pos=far,kind='modern_wall'};self.preview=p
            end
        end
    end
    return p
end
function M:tick(owner)
    local c=self.c
    if self:advance()then return true end
    if not owner then self.doneHeld=false;self.job=nil;self.preview=nil;return false end
    if self.doneHeld then return true end
    local raw=c:mouse();if not raw then return true end
    if not c:ready(2)then return true end
    if self:start(raw,owner)then return true end
    local p=self:plan(raw);if not p or not p.valid then return true end
    if p.kind=='modern_wall'then
        if U.dist(c.hero.pos,p.stand)>30 then
            if U.dist(c.hero.pos,p.stand)<=c.config:get('wardWalkRange')and self.terrain:walkLine(c.hero.pos,p.stand,35)then c.actions:submit({kind='move',pos=p.stand,owner=owner,release=true})end
        else
            local dagger
            for _,d in pairs(c.state.daggers)do if c.state:daggerValid(d)and U.dist(d.pos,p.stand)<=50 then dagger=d;break end end
            if dagger then
                local ok,record=c.actions:submit({slot=2,owner=owner,pos=p.pos,anchor=dagger.object,dagger=dagger,side=U.copy(p.pos),escape=true,release=true})
                if ok then self.pending={state='jumping',owner=owner,event=record,expires=Game.Timer()+2}end
            elseif c:ready(1)then c.actions:submit({slot=1,owner=owner,prepareWall=true,release=true})end
        end
    elseif U.dist(c.hero.pos,p.pos)<=math.min(c.profile.eRange,c.config:get('wardRange'))then self:start(p.pos,owner)
    elseif c.config:get('wardApproach')and p.walkTo and U.dist(c.hero.pos,p.walkTo)<=c.config:get('wardWalkRange')then
        c.actions:submit({kind='move',pos=p.walkTo,owner=owner,release=true,validate=function()return self.terrain:wall(p.walkTo)==false end})
    end
    return true
end
return M

end
modules["kata.navdata"]=function(require)
-- Generated by tools/build_lho_navigation.py; static map assets, not live terrain.
return {["normal"]={["x"]=-1.1048965454101562,["z"]=32.75579833984375,["maxX"]=14718.400390625,["maxZ"]=14792.2109375,["cell"]=50.0,["nx"]=295,["nz"]=296,["gates"]={[100]={[15433]=true,[15434]=true,[15728]=true,[15729]=true,[15730]=true,[15731]=true,[15732]=true,[15733]=true,[16023]=true,[16024]=true,[16025]=true,[16026]=true,[16027]=true,[16028]=true,[16318]=true,[16319]=true,[16320]=true,[16321]=true,[16322]=true,[16323]=true,[16613]=true,[16614]=true,[16615]=true,[16616]=true,[16617]=true,[16618]=true,[16908]=true,[16909]=true,[16910]=true,[16911]=true,[16912]=true,[17203]=true,[17204]=true,[17205]=true,[17206]=true,[17207]=true,[17502]=true,[27485]=true,[27486]=true,[27487]=true,[27488]=true,[27489]=true,[27490]=true,[27491]=true,[27780]=true,[27781]=true,[27782]=true,[27783]=true,[27784]=true,[27785]=true,[27786]=true,[28076]=true,[28077]=true,[28078]=true,[28079]=true,[28080]=true,[28081]=true,[28371]=true,[28372]=true,[28373]=true,[28374]=true,[28375]=true,[28376]=true,[28666]=true,[28667]=true,[28668]=true,[28669]=true,[28670]=true,[28671]=true,[28672]=true},[200]={[58944]=true,[58945]=true,[58946]=true,[58947]=true,[58948]=true,[58949]=true,[59238]=true,[59239]=true,[59240]=true,[59241]=true,[59242]=true,[59243]=true,[59244]=true,[59534]=true,[59535]=true,[59536]=true,[59537]=true,[59538]=true,[59539]=true,[59829]=true,[59830]=true,[59831]=true,[59832]=true,[59833]=true,[59834]=true,[60124]=true,[60125]=true,[60126]=true,[60127]=true,[60128]=true,[60129]=true,[60130]=true,[70408]=true,[70409]=true,[70703]=true,[70704]=true,[70705]=true,[70706]=true,[70707]=true,[70998]=true,[70999]=true,[71000]=true,[71001]=true,[71002]=true,[71293]=true,[71294]=true,[71295]=true,[71296]=true,[71297]=true,[71588]=true,[71589]=true,[71590]=true,[71591]=true,[71592]=true,[71883]=true,[71884]=true,[71885]=true,[71886]=true,[71887]=true,[72178]=true,[72179]=true,[72180]=true,[72181]=true,[72182]=true,[72476]=true,[72477]=true}},["mapID"]=11,["rows"]={"fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff7","fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff7","f10cfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff7","f008fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff7","3000effffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff7","1000cffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff7","10000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff7","10000cfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff7","100000fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff7","100000cffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff7","10000000000000000000000efffffffffffffffffffffffffffffffffffffffffffffffff7","100000000000000000000008fffffffffffffffffffffffffffffffffffffffffffffffff7","100000000000000000000000fffffffffffffffffffffffffffffffffffffffffffffffff7","300000000000000000000000cffffffffffffffffffffffffffffffffffffffffffffffff7","7000000000000000000000000000000000000000000cfffffffffffffffffffffffffffff7","f100000000000000000000000000000000000000000000000000effffffffffffffffffff7","f70000000000000000000000000000000000000000000000000000effffffffffffffffff7","ff0000000000000000000000000000000000000000000000000060000ffffffffffffffff7","ff10000000000000000000000000000000000000000000000000f00000fffffffffffffff7","ff10000000000000000000000000000000000000000000000000f100008ffffffffffffff7","ff10000000000000030000000000000000000000000000000000f100000cfffff1cffffff7","ff30000000000000cf0000000000000000000000000000000000f0000000cffff08ffffff7","ff30000000000000cf1007000000000000000000000000000000000000000cff700efffff7","ff30000000000000ef108f0000000000000000000000000000000000000000ff3008fffff7","ff30000000000000ef108f0000000000000000000000000000000000000000000000fffff7","ff30000c00000000cf108f0000000000000000000000000000000000000000000000effff7","ff30008f70000000cf10070000000000000000000000000000000000000000000000cffff7","ff3000cff0000000070000000000000000f0000000000000000000000000000000008ffff7","ff3000eff1000000000000000000000000f100000000000000000000000000000c108ffff7","ff3000eff1000000000000000000000000f100000000000000000000000000000e100ffff7","ff3000fff3000000000000000000000000f000000000000000000000000000000f000ffff7","ff3000fff30000000000000000000000004000000000000000000000000000008f100efff7","ff3000fff300000000000000f000000000000000000000000000000000000000cf300cfff7","ff3000fff3c1000000000008f1000000000000000000000000000000000000008f730cfff7","ff3000fff3e3000000000008f1000000effffff30ffff70000000000000000000ff30cfff7","ff3000eff1e3000000000008f10ef700effffff30ffff700ffff7000000000000ef30cfff7","ff3000eff1e3000000000008f10ef700fffffff30ffff308fffff100000000000cf10cfff7","ff3000cff0c1000000000008f10ef300fffffff30ffff308fffff3000000000008f00efff7","ff30008f7000000000000008f10ef308fffffff30ffff108fffff300f000000000700ffff7","ff30000c0000000000000008f10ef10cfffffff30ffff00cfffff308f300000000208ffff7","ff3000000000000000000008f10ef10cffffff3000fff00cfffff308f70000000000cffff7","ff300000000000000000000cf10ef10cffffff00000f700cfffff10cf70000000000effff7","ff300000c00000000000000cf00ef10cfffff7000000700cfffff00cff0000000000effff7","ff300000e10000000000000cf00ef10cfffff3000000000efff0000eff0000000000effff7","ff300000f10000000008100cf00ef10cfffff1000000000eff30000eff1000000000effff7","ff300000e1000000000c300cf00ef10cfffff0000000000fff00000eff1000000000effff7","ff300000e1000000000e700cf00ef100ffff70000000000ff300000eff1000000000effff7","ff30000000000000000e700cf00ef100cfff300e100000000000000eff3000000000effff7","ff30000000000000000c300cf00ef1000fff100f300000000000000fff3000000000effff7","ff300000000000000008100cf00ef10008ff008f700000000000000fff7000000000effff7","ff300000000000000000000cf00ef300000000cf700000000000008fff7000000000effff7","ff300000000000000000000cf00ef700000000eff00e1000000000cfff7000000000effff7","ff300000000000000000000e700eff10000000eff00e700000e100cfff7000000000effff7","ff300000000000000000000e700eff70000000eff00ef30008f100efff7000000000cffff7","ff300000000000000000000e700efff1000000fff00eff000ef300ffff7000000000cffff7","ff300000000000000000000e700efff1000000fff10fff308ff308ffff3000000000cffff7","ff300000000000000000000e700efff1000000fff10ffffffff008ffff10000000008ffff7","ff300000000000000000000e300efff0000000fff10fffffff700cffff00000000008ffff7","ff300000000000000000000e300efff0000000fffffffffff7000efff700000000000ffff7","ff300000000000000000000e300eff70000000effffffffff1000efff300000000000ffff7","ff3000000000000c3000000f300eff30000000efffffffff10000efff000000000000ffff7","ff3000000000000e7000000f300eff30000000effffffff300000eff7000000000000efff7","ff3000000000000ff000000f300eff1000c100e30effff3000000cff3000000000000efff7","ff3000000000000ff000008f300eff108ff700e00cffff10000008ff0000000000000efff7","ff3000000000000ff000008f1008ff00cff70000000eff00000000e7000000c300000cfff7","ff3000000000000e700000cf0008f700cff700000008f70000cf0000000008f700000cfff7","ff3000000000000c300000ef0008f700eff700000000f30000ff000000000cff000008fff7","ff300c1000000000000000f70008f300fff700000000c1000cff000000000eff100008fff7","ff300f3000000000000008f70008f300fff70000000000000fff000000000fff300008fff7","ff300f7000000000000008f300000008fff7000000000000cfff000000008fff300008fff7","ff300f700000000000000cf300000008fff30008f0000000ffff10000000cfff700008fff7","ff300f700000000008700cf10000000cfff1000cf100000cffff10000000cfff700008fff7","ff300f700000000008700ef10000000eff70000ef700000effff3e000000efff700000fff7","ff300e300000000008f00ef00000000eff10000eff00000fffffff300000effff00000fff7","ff300c100000000008700cf00000000ff700000eff00008fffffff700000effff00000fff7","ff300000000000000030087000ff108ff100000cff1000cffffffff00000fffff00000eff7","ff300000000000000000003000ff108ff1000000ff3000ef78fffff00000fffff10000eff7","ff300000000030000000000008ff108ff1000000ef7000ff30cffff00000fffff10000eff7","ff30000000087000000000000cff308ff1000000eff008ff108ffff00008fffff10000eff7","ff300000000cf000000000000cff308ff108f100eff008ff000ffff00008fffff10000cff7","ff300000000cf000000000000eff708ff108f100eff008f7000eff700008fffff10000cff7","ff30000000087000000000000eff700ff10cf100eff00cf3000cff700008fffff10000cff7","ff3000000000300000000000cfff700ff10cf100eff00cf00008ff700008fffff10000cff7","ff700e100000000000000000effff00ef10cf700eff00c700000ff30000cfffff10000cff7","ff700e300000000000000000effff00ef10cff00eff00c700000ef30000cfffff10000cff7","ff700e300000000000000000cffff10cf10cff7cfff00e300000cf30000cfffff10000cff7","ff700e10000000000c300000cffff10cf10cfffffff00e300000cf10000cfffff10000cff7","fff00800000000000f7000008ffff308f10cfffffff00e300000cf00000efffff100078ff7","fff00000000000008f7000000ffff300e10cfffffff00e300000e300000efffff1008f8ff7","fff0000000000000ef7000000efff700000cfffffff00e300000f100000ef7cff1008f8ff7","fff100000000000cff7000000cfff7000000efffff700c700008f000000f10cff1008f8ff7","fff100000000008fff30000008ffff0000008fffff700c70000c7000000f108ff100078ff7","fff10000000000cfff00000000ffff0000000cffff700c70000c3000008f000ff100008ff7","fff100000000cffff300000003efff10000000cfff300cf00008100000c7000ff100008ff7","fff30000cffffffff000000087cfff300000000000000cf00000000000e3000ff100008ff7","fff30000efffffff30000000c78fff300000000000000ef10000000000e1000ff100008ff7","fff30000effffff700000000870eff308300000000000ef70000000000f1000ef100008ff7","fff30000effffff3000000008708f300e300000000000fff1000000008f0000cf100008ff7","fff30000cfff70000000000000000000e700000000008fffff0000000c700000f100008ff7","fff30000cfff10000000000000000000e70000000000cfffff0000000c300000e100008ff7","fff30000000000000000000000000000e70000000000efffff0000000e3081008100008ff7","fff30000000000000000f00000000000e70000000008fffff30000000f1081000000008ff7","fff7000000000000000cf10000000000e7000000000cfffff00000008f0081000000008ff7","fff7000000000000008ff30000000000e7000000000cffff30000000870081000000008ff7","fff700000000000000fff70000000c30ef00ff30000cffff000000008700c1000000008ff7","fff70000000000000effff0000000c30ef00ff30000cfff1000000008700c1000000008ff7","fff7000000000000cfffff1000000cffff00ff30000cff10000000000700e1000000008ff7","fff700000000000effffff30000008ffff00ff300008f100000000000f00e1000000008ff7","fff700000000000fffffff70000000ffff00ff3000000000000000000f00e10c0000008ff7","fff700000000000ffffffff0000000efff00ff3000000000000000000e00f10e3000008ff7","fff7000000cf000efffffff1000000cfff00ff3000000000000000c00e00f10ef100008ff7","fff700008fff100cfffffff30000008fff00ff1000000000000000f00c00f30ef300008ff7","fff700008fff700cfffffff70000000fffffff0000000000000008f00000f30cf300008ff7","fff700008ffff008ffffffff0000000efffff7000000000000000cf10000f30cf300008ff7","fff700008ffff008ffffffff1000000cfffff1000000000000000ef10000f30cf700008ff7","fff700008ffff008fff00eff10000008fffff0000830000000000ff30000f30cf700008ff7","fff300008ffff008ff10087000000000ffff70000f3000000000cff70000f30cf700008ff7","fff300008ffff008f700003000000000efff1000ef1000000000fff70008f308f700008ff7","fff300008fff3008f100000000000000cfff0008f7000000000effff000cf708f700008ff7","fff300008fff100cf0000000000000008ff7000cf100000000cfffff000ef708f700008ff7","fff300008fff000ef0000000000000008ff3000ff000000000effff7000ff708f700008ff7","fff300008fff000e70000000000000000ff000cf3000000000effff3008ff700f700008ff7","fff300008fff000f3000f0008f0000000e7000ef0000000000cffff100cff700f700008ff7","fff300008fff008f1008f100ff300000000008f700000000000ffff100eff300f700008ff7","fff300008fff00cf0008f300ff70000000000cf300000000000efff100fff300f700008ff7","fff300008fff00ef0000ff00eff0870000000ef000000000000cfff108fff300f700008ff7","fff300008fff00f70000ef10eff1870000000f70000000000008fff00cfff100f700008ff7","fff300008fff00f30000ef10cff3c70000008f30000000cf1000fff00cff7000f700008ff7","fff300008fff00f30000cf10cff787000000cf10000000ff7000eff000ff0000f700008ff7","fff300008fff00f10000cf30cfff13000000cf10000008fff000eff000c30000f700008ff7","fff300008fff10f10000ef30cfff30000000cf0000000efff100eff000000008f700008ff7","fff3000e8fff10f10000ff30cfff70000000c70000008ffff300eff10000000cf700008ff7","fff3000f9fff10f10008ff708ffff000000083000000effff700eff10000000ef300008ff7","fff3000f9fff10e1000cff708ffff100000000000000fffff700eff1000000cff300008ff7","fff3000f8fff10e10cffff708ffff10000000000000cfffff700eff0000008fff300008ff7","fff300060fff10e10effff708ffff10000000000000ffffff700ff7000000cfff300008ff7","fff300000fff10e10effff708ffff30000000000008ffffff300ff1000000ffff100008ff7","fff300000fff10e10cffff308ffff3000000000000cfffff1008f3000000cfff3000008ff7","fff300000fff10e108ffff308ffff1000000000000fffff30008f3000000cfff0000008ff7","fff300000fff10e100ffff008ffff1000000000000ffff30000cf3000000cff70000008ff7","fff300000fff10c000cff3008ffff1000000000008fff700000cf3000000cff10000008ff7","fff300000fff1000000e10008ffff100000000000cfff300000ef3000000cf700000008ff7","fff300000fff100000000000cffff000000000000cfff100000ef3000000cf300000008ff7","fff300000ff7000000000000efff7000000000000cff7000000ef70000008f100000008ff7","fff300000ff3000000000000ffff700e300000000cff3000000effffff1000000000008ff7","fff300000ff1000000000000ffff300ff000000008ff1000000cffffff3000000000008ff7","fff300000f70000000000000efff108ff000000008ff00000000ffffff3000000000008ff7","fff300000f30000000000000cff7008ff000000000f7000ef300efffff100000e100008ff7","fff300000f000000fffff0008ff300cff000000000e3008ff30000efff100000f100008ff7","fff3000007000008ffffff100f3000eff0000000000000eff700000000000008f100008ff7","fff3000000000008ffffff30000000fff0000000000000fff70000000000000ef100008ff7","fff3000000000008ffffff70000000ff70000000000008fff70000000000000ff100008ff7","fff300000000e300fffffff0000008ff3000000000000cfff70000000000008ff100008ff7","fff300000008f7000000cff000000eff3000000000000efff7000000000000eff100008ff7","fff30000000cf70000008f7000000fff1000000000000ffff7000000000000fff100008ff7","fff30000000ff70000008f7000008fff1000000000000ffff3008ff3000e10fff100008ff7","fff30000008ff70000008f700000efff0000000000008ffff300efff000f10fff100008ff7","fff3000000eff70000008f30000cffff0000000000008ffff300ffff100f10fff100008ff7","fff3000008fff70000008f3000cffff70000000000008ffff108ffff300f10fff100008ff7","fff300000efff30000008f10cffffff70000000000008ffff108fffff00f10fff300008ff7","fff300008ffff0000000ef00effffff10000830000008ffff10cfffff00f10fff300008ff7","fff300008fff3000000cff00efffff700000c70000008ffff10cfffff00f10fff340008ff7","fff300008fff0000000ff700efffff300000e70000008ffff10cff38f00f10fff3f1008ff7","fff30000cff10000000ff700efffff000000f70000000ffff10cff10700f10fff3f1008ff7","fff30000cf700000000ff300cffff7000000f70000000efff10cff00608f10fff3f1008ff7","fff30000cf300000000ff3008ffff1000008f30000000cfff308f700008f10fff3e0008ff7","fff30000cf100000000ff7000ffff000000cf100000008fff308f700008f10fff300008ff7","fff30000cf0000cf000ff7000eff3000000ef0000000c1fff308f700008f10fff300008ff7","fff30000cf0008ff100fff0008ff0000000f30000000e1eff700f700008f10eff300008ff7","fff30000cf000eff700fff1000c30000008f10000000e3cff700f700008f10eff300008ff7","fff30000cf008fff700fff3000000000008f00000000e18fff00ef0000cf10eff300008ff7","fff30000cf008fff300fff700000000000c700000000c10fff10cf0000ef00eff300008ff7","fff30000cf008fff100ffff10000000000f300000000000eff108f0000e700eff300008ff7","fff30000cf00cfff000ffff30000000008f100000000000cff00060000f300eff300008ff7","fff30000cf00cff7000fffff000000000cf0000e100000081000000008f100eff300008ff7","fff30000cf10cff3008fffff000000000f70000f70000000000000000cf000fff300008ff7","fff30000cf10cff100effff7000000008f10008ff0000000000000000e7000fff300008ff7","fff30000cf30cff000effff100000000ef0000cff1000000000000000f7000fff300008ff7","fff30000cf30cf7000cfff7000000000f70000fff3000000000000000f300cfff300008ff7","fff30000cf708f3000cfff000000000cf10008fff700000000000000cf300efff30000cff7","fff300008f708f10008ff7000000000c30000effff00000000000000ff300efff30000cff7","fff300008f708f10000ff1000000000000000fffff30000000ff100cff300efff30000cff7","fff300008ff08f10000ff0000000000000008fffff70000000ff300fff300efff10000cff7","fff300008ff00f10000f3000000000000000cffffff0000000fff8ffff300efff10000cff7","fff300008ff00f10600e1000000000000000fffffff1000000efffffff7008fff10000cff7","fff300008ff00f10600e0000000000000008ff10eff3000000cfffffff7000fff00000cff7","fff300000ef10f10e0060000000000000008ff10eff70000008ffffffff000e1000000cff7","fff7000000f10f00e1000000000000000008ff10efff0000008ffffffff00000000000cff7","fff7000000c00f00e1000000000000000008ff10efff1000000fffffff700000000000cff7","fff7000000000f00e100000000008f100008ff10efff3000000effffff3000000000008ff7","fff7000000000700e1000000000cff700008ff10efff7000000cfffff30000000000008ff7","fff7000000000700e3000000008fff700000cf10e70870000008ffff700000000000008ff7","fff7000000000700e300000000efff7000000000c70000000000efff000000000000008ff7","fff7000000000300e300000008ffff3000000000c70000000000cff1000000000000008ff7","fff7000000000300e30000000effff1000000000c700000000000f70000000000000008ff7","fff7000000000300f10000008fffff0000000000c700000000000e00000000000000008ff7","fff7000007000300f1000000effff70000000000c700000000000000000000000000008ff7","fff700000f100008f1000000effff30000000000c7000000000000000000000cf700008ff7","fff700000f300008f0000000cffff10000000000870000000000000000000cffff00008ff7","fff700000f70000cf000000000eff000000000008700c100c10000000008ffffff00008ff7","fff700000f70000c7000000000eff000000000008708ff00e3000000000cffffff00008ff7","fff700000ff0000e7000000000cff000000000000008fff0e300000000efffffff00008ff7","fff700000ff1000f30000000008ff008ff7000000008fff3e30000000cfffffff700008ff7","fff700000ff1008f30000830000ff00cffff00000008fff7c1000000fffffff30000008ff7","fff700000ff3008f30000c70000ff00cffff70000000ffff0000000cfff700000000000ff7","fff700000ff300cf10000e70000ef00cfffff3000000ffff1000000efff300000000000ff7","fff7c3000ff700ef10008f30000cf00effffff000000efff3000000ffff000000000000ff7","fff7e3000fff00ff0000cf10000cf00effffff700300efff7000000fff1000000000000ef7","fff7e3000fffffff0000ef10000cf00effffff700f00cffff100000ff70000000008300ef7","fff7c3000ffffff70000ff10000cf00effffff700f10cffff300000ef1000000000c700ef7","fff781000ffffff70008ff10000cf00effffff700f308ffff700000c70000000000c700ef7","fff700000ffffff3000cff10000cf00eff3cff700f700fffff00000830000000000c700ef7","fff700000ffffff3000cff30000c700eff00ef700f700fffff000000000000000008300ef7","fff700000ffffff1000eff70000e700eff008f700ff00effff000000000000000000000cf7","fff700000ffffff1000efff0000e700eff000f700ff00efff1000000000000000000000cf7","fff700000ffffff0000efff1008f300eff000f700ff10cfff0000000000008100000000cf7","ffff00000ffffff0000efff300cf300eff000f700ff10cfff000000000000c300000000cf7","ffff00000fffff70000fffff00ef300eff000f300ff10cff7000000000000e700000000cf7","ffff00000fffff70000ffffff8ff100cff0000000ff10cff3000000000000e700000000cf7","ffff00000fffff30000fffffffff0008ff0000000ff10cff3000000000000c300000000cf7","ffff00000fffff30000efffffff70008ff1000000ff10cff10000000000008100000000cf7","ffff00000effff10000efffffff30000ff7000000ff108ff000e100e000000000008300cf7","ffff10000effff10000cfffffff10000eff000008ff00000000f300f10000000000e700cf7","ffff10000effff000000fffffff00000cff00000ef700000000f300f10000000000ff00cf7","ffff10000cffff00000000fffff000008ff0000cff700000008f300f10000000000ff00cf7","ffff10000cfff700000000efff3000000f70000fff300000008f300e00000000000ff10cf7","ffff10000cfff300000000efff0000000c30008fff30000000cf100000000000000ff00cf7","ffff100008fff100000000eff1000000000000cfff10000000cf100000000000000ff00cf7","ffff100000fff100000000cf70000300000000cfff108f3000cf000008100000000e700cf7","ffff300000fff0000000008f00008f00000000cfff008f3000e700000e700000000c300cf7","ffff300000ef7000000000030000cf30000000cfff00cf3000e700000ff000000000000cf7","ffff300000cf3000000700000000ef70000000cff700ef3000f300000ff000000000000cf7","ffff3000008f000000ff10000000fff1000000cff300eff000f300000ff000000000000cf7","ffff30000000000008ff30000008ffff700f008f7000fff000f300000ff000000000000cf7","ffff3000000000000cff7000000cfffff0cf00000000fff000f300000ff000000000000cf7","ffff3000000000000eff700000cfffffffff00000008fff008f100000e7000000000000cf7","ffff7000000000000fff70000cffffffffff0000000cfff008f100000c3000000000000cf7","ffff7000000000008fff70008fffffffffff0000000cfff008f10000000000000000000cf7","ffff700000000000ffff7000efffffffffff0000000efff00cf00000000000000000000cf7","ffff700000000000ffff700cfffffff10fff0000000efff00c700000000000000000000cf7","fffff00000000008ffff300ffffffff00fff0000000ffff00c700000000000000000000cf7","fffff0000000000cffff108f7000fff00fff0000000ffff00c700000000000000000000cf7","fffff0000000000effff108f1000cff00eff0000000efff00c700000000000000000000cf7","fffff0000000000fffff000700000ff00eff00000008fff00c700000000000000000000cf7","fffff0000000000ffff7000000000cf00eff00000000eff00c700000000000000000000cf7","fffff0000000000ffff30000000000600ef700000000cff00e7000000000000000000008f7","fffff0000000000ffff30000000000000cf7000000000ff00f3000000000000000000008f7","fffff0000000000ffff10000000000000cf300ef70000ff00f3000600000000000000008f7","fffff0000000000efff000000000000008f100fff3000ff00f3000f00000000000000008f7","fffff0000000000efff000000e100000000008ffff000ff00f3008f10000000003000008f7","fffff0000000000eff7000000ff0000000000cffff300ff00f3008f10000000087000008f7","fffff0000000000eff7000008ff0000000000effff700ff00f3000f0000000008f000008f7","fffff0000000000cff7000008ff0000000000fffff700ff00f3000600000000087000008f7","fffff00000000008ff300cfffff0000000008fffff700ff00f3000000000000087000008f7","fffff00000000000ff300efffff000f00000efffff700ff00f3000000000000000000008f7","fffff00000000000cf100fffff7008ff0008ffffff708f700f3000000000000000000008f7","fffff000000000000e100fffff700cff700fffffff708f700f3000000000000000000008f7","ffff70000000000000008fffff700efff18fffffff308f700f300000000000000cf00008f7","ffff30800000000000008fffff300efff18fffffff308f700f300000000000000ef10008f7","ffff10c10000000000008fffff300ffff18fffffff108f700f300000000000c38ff30008f7","ffff00e30000000000000effff300ffff18fffffff008f300f300000000000c78ff70008f7","fff700f70000000000000cffff108ffff18fffffff000e100f300000000000c7cff70008f7","fff708ff000000000000000000008ffff18ffffff70000000f300000000000c3cfff0008f7","fff708ff10000000000000000000000000000000000000000e10000000000001cfff0008f7","fff708df30000000000000000000000000000000000000000000000000000000cfff0008f7","fff7008f7000000000000000000000000000000e000000000000000000000000cfff0008f7","ffff000f3000000000000000000000000000000e100000000000000000000000cff70008f7","ffff100e1000000000000000000000000000000f1000000000000000000000008ff70008f7","ffff300f0000000000000000000000000000000e1000000000000000700000008ff30008f7","ffff70070000000000000000000000000000000e000000000000000cf00000000ff10008f7","fffff00000000000000000000000000000000000000000000000700ef10000000cf00008f7","fffff10000000000000000000000000000000000000000000008f00ef100000000000008f7","fffff30000000000000000000000000000000000000000000008f00ef300000000000008f7","fffff70000000000000000000000000000000000000000000008f00ef100000000000000f7","ffffff008fff3000000004000000000000000000000000000000700ef100000000000000f7","ffffff10cffff30000000f000000000000000000000000000000000cf100000000000000f7","ffffff30efffff1000000f10000000000000000000000000000000087000000000000000e7","ffffff70fffffff000000f10000000000000000000000000000000000000000000000000e7","ffffffffffffffff00000e00000000000000000000000000000000000000000000000000c7","fffffffffffffffff0000000000000000000000000000000000000000000000000000000c7","fffffffffffffffffff3000000000000000000000000000000000000000000000000000087","ffffffffffffffffffffffff10000000000000000000000000000000000000000000000007","ffffffffffffffffffffffffffffffffffffffff0000000ef7000000000000000000000006","fffffffffffffffffffffffffffffffffffffffffffffffffff70000000000000000000004","ffffffffffffffffffffffffffffffffffffffffffffffffffff0000000000000000000004","ffffffffffffffffffffffffffffffffffffffffffffffffffff1000000000000000000004","ffffffffffffffffffffffffffffffffffffffffffffffffffff700000000000008ff10004","fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff30004","fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff70004","ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff0004","ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff1007","ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff1087","ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff10c7","ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff10e7","ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff30f7","fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff7"},["mode"]="normal",["sha256"]="b7551b91dcdc3dec0228ff2df63483399b0b040552d2115b65d9fe1faf35bd93"},["classic"]={["x"]=0.0,["z"]=0.0,["maxX"]=16000.0,["maxZ"]=16000.0,["cell"]=50.0,["nx"]=321,["nz"]=321,["gates"]={[100]={[19365]=true,[19366]=true,[19367]=true,[19368]=true,[19371]=true,[19686]=true,[19687]=true,[19688]=true,[19689]=true,[19690]=true,[19691]=true,[19692]=true,[20007]=true,[20008]=true,[20009]=true,[20010]=true,[20011]=true,[20012]=true,[20013]=true,[20327]=true,[20328]=true,[20329]=true,[20330]=true,[20331]=true,[20332]=true,[20333]=true,[20648]=true,[20649]=true,[20650]=true,[20651]=true,[20652]=true,[20653]=true,[20654]=true,[20973]=true,[20974]=true,[20975]=true,[21296]=true,[31841]=true,[31842]=true,[31843]=true,[31844]=true,[31845]=true,[31846]=true,[32162]=true,[32163]=true,[32164]=true,[32165]=true,[32166]=true,[32167]=true,[32168]=true,[32483]=true,[32484]=true,[32485]=true,[32486]=true,[32487]=true,[32488]=true,[32489]=true,[32804]=true,[32805]=true,[32806]=true,[32807]=true,[32808]=true,[32809]=true,[32810]=true,[33125]=true,[33126]=true,[33127]=true,[33128]=true,[33129]=true,[33130]=true,[33131]=true,[33132]=true,[33446]=true,[33447]=true,[33448]=true},[200]={[65736]=true,[65737]=true,[65738]=true,[65739]=true,[65740]=true,[65741]=true,[66058]=true,[66059]=true,[66060]=true,[66061]=true,[66062]=true,[66380]=true,[66381]=true,[66382]=true,[66383]=true,[66701]=true,[66702]=true,[66703]=true,[66704]=true,[67022]=true,[67023]=true,[67024]=true,[67025]=true,[67026]=true,[67343]=true,[67344]=true,[67345]=true,[67346]=true,[67347]=true,[67663]=true,[67664]=true,[67665]=true,[67666]=true,[67667]=true,[67668]=true,[77571]=true,[77572]=true,[77573]=true,[77574]=true,[77892]=true,[77893]=true,[77894]=true,[77895]=true,[77896]=true,[77897]=true,[77898]=true,[78213]=true,[78214]=true,[78215]=true,[78216]=true,[78217]=true,[78218]=true,[78534]=true,[78535]=true,[78536]=true,[78537]=true,[78538]=true,[78539]=true,[78855]=true,[78856]=true,[78857]=true,[78858]=true,[78859]=true,[78860]=true,[79176]=true,[79177]=true,[79178]=true,[79179]=true,[79180]=true,[79181]=true}},["mapID"]=453,["rows"]={"ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff1","ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff1","ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff1","ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff1","ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff1","ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff1","ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff1","ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff1","ffff70ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff1","ffff30efffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff1","ffff30ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff1","ffff106cffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff1","fff10000efffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff1","fff100000fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff1","fff100000cffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff1","fff1000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff1","fff1000000cffffffffff0008fffffffffffffffffffffffffffffffffffffffffffffffffffffff1","fff1000000000000000000000cffffffffffffffffffffffffffffffffffffffffffffffffffffff1","fff10000000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffff1","fff300000000000000000000008ffffff1008fffffffffffffffffffffffffffffffffffffffffff1","ffff00000000000000000000000000c3000000000000fff30000008fffffffffffffffffffffffff1","ffff3000000000000000000000000000000000000000000000000000cfffffffffffffffffffffff1","ffff700000000000000000000000000000000000000000000000000000ffffffffffffffffffffff1","fffff000000000000000000000000000000000000000000000000000000fffffffffffffffffffff1","fffff1000000000000000000000000000000000000000000000000000000efffffffffffffffffff1","fffff30000000000000000000000000000000000000000000000000000000fffffffffffffffffff1","fffff30000000000000000000000000000000000000000000000000000000cffffffffffffffffff1","fffff300000000000000000000000000000000000000000000000000000000ffffffffffffffffff1","fffff300000000000000000000000000000000000000000000000000000000cfffffffffffffffff1","fffff3000000000000000000000000000000000000000000000000000000000fffffffffffffffff1","fffff1000000000000000000000000000000000000000000000000000000000cffffffffffffffff1","fffff00000000000000000000000000000000000000000000000000000000000ffffffffffffffff1","fffff00000000000000000000000000000000000000000000000000000000000cfffffffffffffff1","ffff7000000000000000000000000000000000000000000000000000000000000fffffffffffffff1","fffff000000000000000000000000000000000000000000000000000000000000cffffffffffffff1","fffff0000000000000000000000000000000000000000000000000000000000000ffffffffffffff1","fffff1000000000000000000000000000000000000000000000000000000000000efffffffffffff1","fffff1000000000000000000000000000000000000000000000000000000000000cfffffffffffff1","fffff10000000000000000000000000000000000000000000000000000000000008fffffffffffff1","fffff10000000000000000000007000300000000000000000000000000000000000fffffffffffff1","fffff1000000000000000000008f00ef0000cfffff10cff30000000000000000000effffffffffff1","fffff1000000000000000000008f00ef100cffffff30ffff308fff1000000000000cffffffffffff1","fffff1000000000000000000008f00ef308fffffff30ffff308fffff100000000008ffffffffffff1","fffff1000000000000000000008f00ef30cfffffff30ffff30cfffff100000000008ffffffffffff1","fffff1000000000000000000008f10ef30cfffffff30ffff30cfffff100000000000ffffffffffff1","fffff1000000000000000000008f10ef30cfffffff10ffff30efffff100600000000efffffffffff1","fffff1000000000000000000008f10ef30efffff1000efff30ffffff100f00000000cfffffffffff1","fffff1000000000000000000008f10ef30efffff000000ef10ffffff108f300000008fffffffffff1","fffff1000000000000000000008f10ef30effff70000000f08ffffff108f700000000fffffffffff1","fffff100000000000000000000cf00ef30effff30000000c08fffff300cff00000000effffffffff1","fffff100000000000000003000cf00ef30effff3000000000cfff30000cff10000000cffffffffff1","fffff10000000000000000f300cf00ef30cffff10000000008fff00000cff300000008ffffffffff1","fffff10000000000000000f300cf00ef308ffff10000000000ff300000eff300000008ffffffffff1","fffff10000000000000000f300cf00ef700efff0000000000000000000eff300000000ffffffffff1","fffff10000000000000000f300cf00ef7008ff7008f100000000000000eff300000000efffffffff1","fffff10000000000000000f300cf00eff000ef7008f300000000000000fff300000000cfffffffff1","fffff100000000000000000000cf00eff1000c300cf300000000000000fff3000000008fffffffff1","fffff100000000000000000000cf00eff30000000ef700000000000008fff3000000008fffffffff1","fffff100000000000000000000cf00eff70000000ef7000f0000c00008fff3000000008fffffffff1","fffff100000000000000000000cf00efff0000000eff00eff008ff000cfff3000000000fffffffff1","fffff100000000000000000000ef00efff1000000fff00fff7ffff100efff1000000000fffffffff1","fffff100000000000000000000ef00efff1000000fff18ffffffff100fff70000000000effffffff1","fffff100000000000000000000ef00efff1000000fff18ffffffff108fff30000000000effffffff1","fffff100000000000000000000f700efff1000000fff3cfffffff300cfff10000000000cffffffff1","fffff100000000000000000000f700efff0000000fffffffffff7000cfff10000000000cffffffff1","fffff100000000000000000000e700efff0000000fffffffffff0000cfff000000000008ffffffff1","fffff100000000000000000000f700eff7000f100ffffffffff30000eff7000000000008ffffffff1","fffff100000000000000000000f100eff3008f700fffffffff700000cff3000000000008ffffffff1","fffff100000000000000000008f100eff300ef700fffffffff100000cff1000000000000ffffffff1","fffff100000000000000000008f100eff108fff00e108ffff7000000cff0000000000000ffffffff1","fffff100000000000000000008f100eff10efff000000cfff1000e100f70000000000000ffffffff1","fffff10000000000000000000cf100fff00ffff0000000fff0000f300000000000000000efffffff1","fffff10000000000000000000cf100fff00ffff0000000ef70008f7000000000c1000000efffffff1","fffff10000000000000000000ef000ef708ffff00000008f1000ff7000000000cf700000cfffffff1","fffff10000000000000000000ef000cf10cffff000000000000cfff000000000eff30000cfffffff1","fffff10000000000000000000ef0000000efff7000000000000efff000000000eff30000cfffffff1","fffff10000000000000000000f70000000efff7000060000008ffff000000000fff70000cfffffff1","fffff10000000000000000000f70000000fff300008f700000cffff100000000ffff00008fffffff1","fffff10000000000000000000f30000000fff00000ef700000fffff700000000ffff00008fffffff1","fffff10000000000000000008f10000008ff700000eff00008fffffff0000008ffff00008fffffff1","fffff10000000000000000008f100c7008ff700000cff0000cfffffff1000008ffff00008fffffff1","fffff10000000000000000008f000ef008ff3000008ff1000efffffff300000cffff00000fffffff1","fffff100000000810000000006000ff10cff1000000ff3000ffffffff700000cffff00000fffffff1","fffff1000000008f0000000000008ff10cff1000000ff3008ff10ffff700000cffff00000fffffff1","fffff100000000cf100000000000cff10cff0000000ef700cf700cfff700000effff00000fffffff1","fffff100000000cf100000000000cff30cff0000000ef700cf3008fff700000effff00000fffffff1","fffff100000000cf100000000000eff30cff10cf000eff00ef1000fff300000fffff00000effffff1","fffff300000000cf100000000000fff308ff10cf100fff00ef0000eff300000fffff00000effffff1","fffff3000000000000000000000cfff708ff30ef300fff00ef0000cff300008fffff00000effffff1","fffff3000000000000000000000efff700ff30ef708fff10e70000cff300008fffff00000effffff1","fffff3000000000000000000000effff00ff30eff08fff10e700008ff300008fffff00000effffff1","fffff3000000000000000000000effff00ff30eff3efff10e700008ff100008fffff10000cffffff1","fffff3000000000000000000000effff10ff30efffffff10f30000cff000008fffff10000cffffff1","fffff30000000000000083000008ffff30cf30efffffff10f30000cff000008fffff10000cffffff1","fffff300000000000008f7000000ffff300f10efffffff00f10000cf700000cfffff10000cffffff1","fffff30000000000000ff7000000efff700000efffffff00f10000cf100000cfffff100008ffffff1","fffff3000000000000efff000000cffff000008fffffff00f30000c7000000e70fff100008ffffff1","fffff300000000000cfff70000000ffff000000effffff00f3000083000000e30cff100008ffffff1","fffff300000000000ffff30000000efff1000008fffff700e7000080000000f100ff100008ffffff1","fffff30000000f1cfffff10000000cfff1000000cffff700c7000000000008f000ef100008ffffff1","ffffff00000cffffffff3000000008fff30000000000e000cf000000000008f000ef100000ffffff1","ffffff30000cfffffff70000000000eff300000000000000cf00000000000c7000ef100000ffffff1","ffffff30000cffffff700000000000cff30e300000000000ef10000000000e3000cf100000ffffff1","ffffff30000cfffff30000000000008ff10f700000000000ff30000000000f1000cf100000ffffff1","ffffff30000cfffcf000000000000007008f700000000008ff38300000008f00008f100000ffffff1","ffffff3000008f100000000000000000008ff0000000000eff7f70000000c700000f100000ffffff1","ffffff30000000000000000200000000008ff0000000000fffff70000000c300000e100000ffffff1","ffffff3000000000000000c700000000000ff0000000008fffff10000000e1081000000000ffffff1","ffffff3000000000000008ff00000000000ff000000000cffff700000000f00c1000000000ffffff1","ffffff300000000000000eff30000000008ff000f00000cffff300000000700c1000000008ffffff1","ffffff30000000000000cfff70000000e7cff00cf30000cffff000000008700e1000000008ffffff1","ffffff3000000000000efffff0000000efcff00ef30000cfff3000000008700e1000000008ffffff1","ffffff300000000000effffff1000000effff00ff30000cff00000000008700e1000000008ffffff1","ffffff300000000000fffffff3000000cffff00ff3000081000000000000700f1040000008ffffff1","ffffff300000000000fffffff70000008ffff08ff3000000000000000000700f10c3000008ffffff1","ffffff30000000f300ffffffff0000000efff08ff1000000000000000000e00f10c7000008ffffff1","ffffff300000cff300ffffffff1000000efff1eff1000000000000000000e00f30cf000008ffffff1","ffffff300000fff700ffffffff1000000cfffffff0000000000000000000e08f30cf100008ffffff1","ffffff300000ffff00ffffffff30000008ffffff70000000000000000000c08f30cf300008ffffff1","ffffff300000ffff00ffffffff70000000ffffff70000000000000000e10008f30cf300008ffffff1","ffffff300000ffff00effffffff0000000ffffff30000000000000008f30008f30cf300008ffffff1","ffffff300000ffff00cfff10fff0000000efffff1000000000000000ef30008f30cf300008ffffff1","ffffff300000ffff00cff700cf10000000cfffff0000000000000000ff3000cf30cf700008ffffff1","ffffff300000ffff00cff10083000000008ffff7000cf0000000000eff3000cf70cf700008ffffff1","ffffff300000ffff00ef700000000000000ffff3000f7000000000cfff3000ef70cf700008ffffff1","ffffff300000ffff00ef300000000000000efff000cf3000000008ffff3000ff708f700008ffffff1","ffffff300000fff700ff000000000000000cff3000ff000000000effff1008ff708f700008ffffff1","ffffff300000fff700f700000000e0000008ff1008f7000000000effff100cff700f700008ffffff1","ffffff300000fff708f70087000ef1000000ef000ef1000000000cffff100eff700e700008ffffff1","ffffff300000fff30cf300cf700ff300000000000ff00000000008ffff100eff700e700008ffffff1","ffffff300000fff30ef100cff00ff70000000000cf300000000000ffff000fff700e700008ffffff1","ffffff300000fff30ff0008ff10fff0000000000ef100000000000efff000fff700e700008ffffff1","ffffff300000fff10f70000ff10fff1000000000ff000000000000cfff000fff300e700008ffffff1","ffffff300000fff10f70000ff30fff3000000008f30000000000008fff000fff100f700008ffffff1","ffffff300000fff10f70000ef30eff700000000cf30000000ff0000fff000ff7008f700008ffffff1","ffffff300000fff10f70000ef70efff00000000cf1000000cff3000eff000ef0008f300008ffffff1","ffffff300000fff10f30000ef70cfff10000000cf0000000fff7000eff00000000cf300008ffffff1","ffffff300000fff10f30000eff0cfff3000000087000000cffff100ef700000000ef300008ffffff1","ffffff300000fff10f30000fff0cfff7000000000000000fffff300ff700000008ff300000ffffff1","ffffff300000fff10f30e78fff18ffff00000000000000cfffff300ff30000000cff300000ffffff1","ffffff300000fff10f30ffffff08ffff10000000000000efffff300ff1000000ffff100000ffffff1","ffffff300000fff10f30ffffff08ffff30000000000008ffffff308ff0000008ffff000000ffffff1","ffffff300000fff10f30fffff708ffff3000000000000cffffff308ff000000cfff7000000ffffff1","ffffff300000fff10f30fffff708ffff3000000000000ffffff000cf7000000cfff3000000ffffff1","ffffff300000fff10e30effff308ffff3000000000008fffff0000cf7000000efff1000000ffffff1","ffffff300000fff30e308ffff108ffff300000000000cffff30000ef3000000eff70000000ffffff1","ffffff300000fff30e100efff00cffff100000000000cffff00000ff3000000eff10000000ffffff1","ffffff100000fff3040008ff700fffff100000000000cfff300000ff3000000eff00000000ffffff1","ffffff300000fff10000000f000fffff000000000000cfff100000ff7000000ef300000000ffffff1","ffffff300000ff7000000000008ffff7000000000000cff7000000ffffcff00cf000000000ffffff1","ffffff300000ff3000000000008ffff7000000000000cff3000000fffffff1083000000000ffffff1","ffffff300000ff000000000000cffff30000000000008ff1000000effffff1000000000000ffffff1","ffffff300000f70000000000008ffff000c7000000000ff000ff108ffffff0000000000000ffffff1","ffffff300000f300000efff7000fff7000ff000000000ef00eff300fffff70000000000000ffffff1","ffffff300000f100000ffffff00eff3008ff0000000000000fff7000cfff30000008000000ffffff1","ffffff3000003000008ffffff30cff000cff0000000000008ffff000000e0000000f100000ffffff1","ffffff3000000000008ffffff700f1000eff000000000000cffff0000000000000cf300000ffffff1","ffffff3000000008108fffffff0020000ff7000000000000cffff0000000000008ff300000ffffff1","ffffff300000000f300fffffff0000008ff3000000000000effff000000000000eff300000ffffff1","ffffff300000008f700effffff000000eff1000000000000ffff7000000000000fff300000ffffff1","ffffff30000000ef70000008ff000008fff0000000000000ffff7000870000008fff300000ffffff1","ffffff30000000ff70000008ff00000eff70000000000008ffff7008ff7000008fff300000ffffff1","ffffff30000008ff70000008ff00008fff30000000000008ffff308ffff300e08fff300000ffffff1","ffffff3000000eff7000000cff0000ffff30000000000008ffff108ffff700f18fff300000ffffff1","ffffff300000efff3000000ef7000cffff10000000000008ffff10cffff708f10fff300000ffffff1","ffffff300000ffff3000000ef308ffffff00000000000008ffff10cfffff08f10fff100000ffffff1","ffffff300008ffff0000000ff10cfffff700000c10000008ffff10cfffff08f10fff100000ffffff1","ffffff300008fff70000008ff10efffff300000e70000008ffff10efffff08f10fff100000ffffff1","ffffff30000cfff3000000cff00efffff100000f70000008ffff30eff3ff08f10fff100000ffffff1","ffffff30000cff70000000ef700cfffff000008f70000000ffff30eff1c70cf10fff100000ffffff1","ffffff30000cff00000000ef300cffff700000cf30000000efff30cff0870cf10fff100000ffffff1","ffffff30000cf700000000ef3008ffff100000ef10000000cfff30cf70000cf10fff100000ffffff1","ffffff30000cf300000000ff7000ffff000000ef000000008fff70cf70000cf10fff100000ffffff1","ffffff30000cf1008ff100ff7000eff3000000f7000000000fff70cf70000ef10fff100000ffffff1","ffffff30000cf100eff300fff000cff0000008f1000000000eff70cff0000ef00fff100000ffffff1","ffffff30000cf100fff300fff1000f0000000cf0000000000cff708ff0000ef00fff100000ffffff1","ffffff30000cf108fff300fff300000000000e300000000008ff708ff0000ff00fff100000ffffff1","ffffff30000cf108fff300fff700000000000f100000000000ff700ff1000ff00fff300000ffffff1","ffffff30000cf108fff100ffff00000000008f000000000000ef700cf1008f700fff300000ffffff1","ffffff30000cf108fff000ffff1000000000c7000000000000cf3008f1008f700fff300000ffffff1","ffffff30000cf108ff7008ffff7000000000e30000e00000008f0000f000cf700fff300000ffffff1","ffffff30000cf108ff300cfffff000000000f10000f30000000000000000cf308fff300000ffffff1","ffffff30000cf308ff100effff7000000008f0000cf70000000000000000ef008fff300000ffffff1","ffffff30000cf308ff000effff100000000e70000eff1000000000000000ef008fff300008ffffff1","ffffff30000cf308ff000effff000000000f30000fff7000000000000008ff00cfff300008ffffff1","ffffff30000cf308f7000cfff3000000008f1000cffff000000000e0000ef700efff300008ffffff1","ffffff300008f708f7000cfff100000000c70000effff30000000cf1008ff700efff300008ffffff1","ffffff300008f708f30008ff7000000000830000fffff70000000ff300eff700efff300008ffffff1","ffffff300008f708f30008ff300000000000000cffffff0000000fff08fff700efff300008ffffff1","ffffff300008f70cf10000ff000000000000000effffff1000000efffffff300efff100008ffffff1","ffffff300008f70cf10000f3000000000000000ff7cfff3000000cfffffff300efff100008ffffff1","ffffff300008ff0cf10800e1000000000000008ff70fff7000000cfffffff700efff100008ffffff1","ffffff300008ff0cf00c0060000000000000008ff30efff0000008ffffffff00cff0000008ffffff1","ffffff300000ff0cf00c1000000000000000008ff10efff1000000ffffffff000300000008ffffff1","ffffff3000000f0cf00c1000000000000000008ff10cfff3000000efffffff000000000008ffffff1","ffffff300000080c700c10000000008ff100008ff00cfff7000000cfffffff000000000008ffffff1","ffffff300000000c700c1000000008fff300008ff00cfff70000008ffffff7000000000008ffffff1","ffffff3000000008700e100000000ffff300008f700cfff30000000ffffff0000000000008ffffff1","ffffff3000000008700e100000008ffff300000f100ef1000000000effff10000000000008ffffff1","ffffff3000000008700f10000000cffff3000000000ef0000000000cfff100000000000008ffffff1","ffffff3000000008700f00000000effff3000000000ef00000000008ff3000000000000008ffffff1","ffffff3000000008308f0000000cfffff1000000000e700000000000ff000000000000000cffffff1","ffffff300000200000c70000000efffff0000000000e700000000000e1000000000000000cffffff1","ffffff300000f00000c70000000effff70000000000e7000000000004000000000cf30000cffffff1","ffffff300000f10000e70000000effff10000000000c7000000000000000000fbfff30000cffffff1","ffffff300000f70000f3000000000fff1000000000083081000000000000000fffff30000effffff1","ffffff300000ff0000f3000000000cff100000000000008ff100000000000effffff70000effffff1","ffffff300000ff1008f10000000000ff000000000000008ff30000000000cfffffff70000cffffff1","ffffff300000ff1008f10000000000ef008ff1000000008fff0000000008ffffffff70000cffffff1","ffffff300000ff300cf00000c30000ef00cffff00000008fff100000000effff700000000cffffff1","ffffff100000ff300ef00000f30000cf00effff70000000fff300000008fffff700000000cffffff1","ffffff100000ff700e700008f300008f00ffffff7000000eff70000000cfff10000000000cffffff1","ffffff100000fff00f70000cf300008f00fffffff000000efff0000000eff1000000000008ffffff1","ffffff300000fff70f30000ef100008f08fffffff100600cfff1000000ef70000000000008ffffff1","ffffff300000ffffff30000ff100008f08fffffff300f00cfff7000000cf10000000000008ffffff1","ffffff300000ffffff10000ff100008f08ffffeff308f308ffff0000000000000000000008ffffff1","ffffff300000ffffff10008ff10000cf08fff78ff308f708ffff1000000000000000000008ffffff1","ffffff300000ffffff00008ff30000cf08fff30ff308f700ffff3000000000000000000000ffffff1","ffffff300000ffffff0000cff30000ef08fff10ef308ff00ffff3000000000000000000000ffffff1","ffffff700000ffffff0000cff70000ef08fff00ef308ff00efff1000000000000000000000ffffff1","ffffff700000fffff70000cfff0000ff00fff00cf308ff00efff000000000000e000000000ffffff1","ffffff700000fffff70000efff0008ff00fff008f308ff10cff7000000000000f300000000ffffff1","ffffff700000fffff30000efff100cff00eff000f308ff10cff3000000000000f300000000efffff1","ffffff700000fffff30000efff300ef700eff000e308ff108ff3000000000000f300000000efffff1","fffffff00000fffff10000efff700ff300cff0000008ff108ff1000000000000f300000000efffff1","fffffff00000fffff10000effff3eff100cff0000008ff100ff1000000000000e100000000efffff1","fffffff00000fffff00000effffffff0008ff100000cff100ef0006000000000c000000000efffff1","fffffff00000ffff700000efffffff70000ff300000cff000cf000f1000000000000000000efffff1","fffffff00000ffff300000cfffffff30000ef300000eff00087000f1000000000000000000efffff1","fffffff00008ffff1000008fffffff10000cf300000fff00003008f1000000000000000000efffff1","fffffff10008ffff00000000efffff00000cf300008fff0000000cf1000000000000000000efffff1","fffffff10000ffff000000008ffff3000000f30000fff70000000cf0000000000000000000efffff1","fffffff10000eff7000000000efff1000000e10008fff70000000ef0000000000000000000efffff1","fffffff10000cff3000000000cff3000000000000cfff30000000ef0000000000000000000efffff1","fffffff100008ff30000000000f30000100000000efff100f3000e70000000000000000000efffff1","fffffff100000ff10000000000000008700000000efff10cf7000e70000000000000000000efffff1","fffffff100000ef1000000000000000cf10000000efff00ef7000e70000000000000000000efffff1","fffffff300000cf0000000000000000ef70000000eff700fff000f30000000000000000000efffff1","fffffff3000000f000000cf30000000fff1000000eff700fff000f30000000000000000000cfffff1","fffffff30000000000008ff7000000cffff100000eff308fff000f10000000000000000000cfffff1","fffffff3000000000000cfff000000ffffff7cf008ff308fff000f10000000000000000000cfffff1","fffffff3000000000000efff1000effffffffff000e300cfff10cf00000000000000000000cfffff1","fffffff3000000000000ffff100efffffffffff0000000cfff10cf10000000000000000000cfffff1","fffffff7000000000008ffff008ffffffffffff1000000efff10cf00000000000000000000cfffff1","fffffff700000000000effff00cffffffffffff1000000ffff10cf00000000000000000000cfffff1","fffffff700000000000fffff00ffffffff3ffff1000000ffff10cf00000000000000000000cfffff1","ffffffff00000000008ffff700fff9ffff1cfff0000000ffff10cf00000000000000000000cfffff1","ffffffff0000000000cffff108ff10efff18fff0000000efff10c700000000000000000000cfffff1","ffffffff0000000000effff00000008fff08fff0000000efff10c300000000000000000000cfffff1","ffffffff1000000000ffff700000000ef708fff0000000cfff10c300000000000000000000cfffff1","ffffffff1000000000ffff30000000000008fff00000008fff10e300000000000000000000cfffff1","ffffffff1000000000ffff10000000000000ff700000000fff10e300000000000000000000cfffff1","ffffffff3000000000ffff00000000000000ef300e30000eff00e300000000000000000000cfffff1","ffffffff3000000000fff700000000000000cf100ef7000eff00e3008f0000000000000000cfffff1","ffffffff3000000000fff7000000000000000f000fff100cff00f300cf1000000000000000cfffff1","ffffffff3000000000eff70000008100000000000fff700cff00f300ef1000000000000000cfffff1","ffffffff7000000000eff700000cf700000000000ffff00cff00f300cf0000000000000000cfffff1","ffffffff7000000000cff700000fff00000000008ffff30cff00f3008f00000000000000008fffff1","ffffffff7000000000cff70000cfff0000000000cffff70cff08f3000100000000000000008fffff1","fffffffff0000000008ff700cfffff0000000008ffffff0cff08f3000000000000000000008fffff1","fffffffff1000000000ff300ffffff008000000cffffff0cff08f3000000000000000000008fffff1","fffffffff30000000000f308ffffff00cff7008ffffff70cff00f3000000000000000000008fffff1","fffffffff70000000000000cffffff00efff18fffffff30cff00f1000000000000000000008fffff1","ffffffffff0000000000000cffffff00ffff1cfffffff308f700f1000000000000000000008fffff1","ffffffffff1000000000000cfffff708ffff0cfffffff108f700f1000000000000000000008fffff1","ffffffffff30000000000008fffff70cffff0cfffffff008f700f1000000000000000000000fffff1","ffffffffff70000000000000fffff30cffff0cffffff7008f700f1000000000000000000000fffff1","ffffffffff700000000000008ffff10cffff08ffffff30000700e1000000000000000000000fffff1","fffffffffff0000000000000000f7008ff000000000000000000e1000000000000000000000fffff1","fffffffffff10000000000000000000030000000000000000000e1000000000000000000000fffff1","fffffffffff3000000000000000000000000000000000000000000000000000000000000000effff1","fffffffffff7000000000000000000000000000000000000000000000000000000000000000effff1","ffffffffffff000000000000000000000000000000000000000000000000000000000000000effff1","ffffffffffff300000000000000000000000000000000000000000000000000000000000000effff1","fffffffffffff00000000000000000000000000000000000000000000000000000000000000effff1","fffffffffffff30000000000000000000000000000000000000000000000000000000000000cffff1","fffffffffffff70000000000000000000000000000000000000000000000000000000000000cffff1","ffffffffffffff1000000000000000000000000000000000000000000000000000000000000cffff1","ffffffffffffff7000000000000000000000000000000000000000000000000000000000000cffff1","fffffffffffffff100000000000000000000000000000000000000000000000000000000000cffff1","fffffffffffffff3000000000000000000000000000000000000000000000000000000000008ffff1","ffffffffffffffff100000000000000000000000000000000000000000000000000000000008ffff1","fffffffffffffffff10000000000000000000000000000000000000000000000000000000008ffff1","ffffffffffffffffff3000000000000000000000000000000000000000000000000000000008ffff1","fffffffffffffffffff300000000000000000000000000000000000000000000000000000008ffff1","ffffffffffffffffffff70000000000000000000000000000000000000000000000000000008ffff1","fffffffffffffffffffff7000000000000000000000000000000000000000000000000000008ffff1","fffffffffffffffffffffffffff3000000000000000000000000000000000000000000000008ffff1","fffffffffffffffffffffffffffffffffffffffffffffffffffff10000000000000000000008ffff1","ffffffffffffffffffffffffffffffffffffffffffffffffffffff0000000000000000000000ffff1","fffffffffffffffffffffffffffffffffffffffffffffffffffffff0000000000000000000008fff1","fffffffffffffffffffffffffffffffffffffffffffffffffffffff7000000000000000810008fff1","ffffffffffffffffffffffffffffffffffffffffffffffffffffffff700000000000810f30008fff1","ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffdf70008fff1","ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff70008fff1","fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff0008fff1","fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff0008fff1","fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff30cffff1","fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff70cffff1","ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff0effff1","ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff0effff1","ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff1","ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff1","ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff1","ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff1","ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff1","ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff1","ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff1","ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff1","ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff1","ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff1","ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff1","ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff1","ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff1","ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff1","ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff1","ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff1","ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff1","ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff1","ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff1","ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff1"},["mode"]="classic",["sha256"]="9a8f02985fa9ab4eb4bb8954341fcb16dd4fd559282ad5e79e547b224cfcbafc"}}

end
modules["kata.planner"]=function(require)
local U=require('kata.util')
local P={};P.__index=P
function P.new(c)return setmetatable({c=c},P)end
function P:safe(pos,target,escape)
    local c=self.c
    if not U.position(pos)then return false end
    if not c.config:get('turret')and c.state:turret(pos)then return false end
    if escape then return c.state:enemiesNear(pos,550)<=c.state:enemiesNear(c.hero.pos,550)end
    if c.state:interruptIncoming()then return false end
    if U.hp(c.hero)<c.config:get('minHP')then return false end
    if c:healthPrediction(c.hero,.45)<=0 then return false end
    return c.state:enemiesNear(pos,650)<=c.config:get('maxEnemies')
end
function P:target(range)
    local c=self.c;local ts=c.sdk.TargetSelector
    local selected=ts.GetSelectedTarget and ts:GetSelectedTarget()or ts.Selected
    if ts.MenuCheckSelected and not ts.MenuCheckSelected:Value()then selected=nil end
    if U.valid(selected)and selected.team~=c.hero.team and U.dist(c.hero.pos,selected.pos)<=range then return selected end
    if ts.GetTarget then local o=ts:GetTarget(range,c.sdk.DAMAGE_TYPE_MAGICAL);if U.valid(o)and not c.damage:protected(o)then return o end end
    local best,score
    for _,o in ipairs(c.enemies)do if U.valid(o)and U.dist(c.hero.pos,o.pos)<=range and not c.damage:protected(o)then
        local s=(o.health or 0)+U.dist(c.hero.pos,o.pos)*.2
        if not score or s<score then best,score=o,s end
    end end
    return best
end
function P:estimate(target,origin,exclude)
    local c=self.c;local best={lethal=false,time=0,damage=0,parts={}}
    if not U.valid(target)or c.damage:protected(target)or c.damage:spellShield(target)then return best end
    -- Finite short horizons; no assumed takedown or dagger reset in any branch.
    local usable,aims,safeAt={},{},{}
    for slot=0,2 do usable[slot]=slot~=exclude and c.config:get('combo'..({'Q','W','E'})[slot+1])and c:ready(slot)end
    usable.AA=exclude~='AA'
    for _,sequence in ipairs({{0,2,1,'AA'},{2,1,0,'AA'},{0,1,'AA'},{'AA',2,0,1}})do
        local pool=c.damage:pool(target,(target.health or 0)+10);local time=0
        local pos=origin;local used={}
        for _,slot in ipairs(sequence)do
            local range=slot==0 and c.profile.qRange or slot==2 and c.profile.eRange or slot==1 and c.profile.wRange or c:attackRange(target)
            local aim
            if usable[slot]then
                local at=time+.25;aim=aims[at]
                if not aim then aim=U.predict(target,at);aims[at]=aim end
            end
            local safe=true
            if aim and slot==2 and U.dist(pos,aim)<=range then
                local at=time+.25
                if safeAt[at]==nil then safeAt[at]=self:safe(aim,target)end
                safe=safeAt[at]
            end
            if aim and U.dist(pos,aim)<=range and safe then
                time=time+.25;pool.hp=pool.hp+(target.hpRegen or 0)*.25
                c.damage:apply(pool,c.damage:parts(slot,target,.25,pool));used[#used+1]=slot
                if slot==2 then pos=aim end
                if pool.hp<=0 then break end
            end
        end
        local result={lethal=pool.hp<=0,time=time,damage=math.max(0,target.health-pool.hp),parts=used}
        if result.lethal and(not best.lethal or result.time<best.time)or not best.lethal and result.damage>best.damage then best=result end
    end
    return best
end
function P:combat(mode)
    local c=self.c
    if c.state:channel()and not c.config:get('smartR')then return end
    if mode=='harass'and c.trade then
        local trade=c.trade
        if U.dist(c.hero.pos,trade.origin)<60 or Game.Timer()>trade.expires then c.trade=nil
        elseif Game.Timer()-trade.at>.55 or not U.valid(trade.target)then
            local a={kind='move',pos=trade.origin,owner='harass',validate=function()
                return c.mobility.terrain:walkLine(c.hero.pos,trade.origin,c.hero.boundingRadius or 35)==true
            end}
            if c:legal(a)then return a end
            c.trade=nil
        end
    end
    local target=self:target(c.profile.eRange+600)
    if not target then return end
    local d=U.dist(c.hero.pos,target.pos);local candidates={}
    local function add(a,score)
        a.owner=mode;a.target=a.target or target;a.score=score
        local legal,why=c:legal(a)
        if legal then
            local direct=a.slot~=2 or U.same(a.anchor,target)or c.profile.id=='normal'and a.pos and U.dist(a.pos,target.pos)<=150
            local damage=direct and a.slot and a.slot<6 and c.damage:amount(a.slot,target,a.slot==3 and .5 or .25)or 0
            if a.rule then damage=c.items:damage(a.rule,target)end
            a.score=a.score+damage
            a.estimate=damage
            if direct and a.slot and a.slot<6 and c.damage:lethal(a.slot,target,a.slot==3 and .5 or .3)then a.score=a.score+2000;a.lethal=true end
            if a.rule and damage>0 and c.damage:apply(c.damage:pool(target,target.health+10),{magic=damage})<=0 then a.score=a.score+2000;a.lethal=true end
            candidates[#candidates+1]=a
        elseif c.telemetry then c.telemetry:reject(a,why)
        end
    end
    if c:ready(0)and c.config:get(mode..'Q')and d<=c.profile.qRange then add({slot=0},60)end
    if c:ready(1)and c.config:get(mode..'W')and d<=c.profile.wRange then
        -- A pending, actually observed Q may need a mark before spending W.
        local q=c.state.qFlight
        local wait=c.profile.id=='classic'and q and q.target==U.id(target)and not c.state:mark(target)and Game.Timer()<q.expires
        if not wait or c.damage:lethal(1,target)then add({slot=1},c.profile.id=='normal'and 180 or 100)end
    end
    if c:ready(2)and c.config:get(mode..'E')then
        local targetPos=U.predict(target,.2)
        for _,anchor in ipairs(c:anchors())do
            local pos=c:landing(anchor,target)
            if pos and U.dist(pos,targetPos)<=c.profile.wRange and self:safe(pos,target)then
                if mode~='harass'or c:hasReturn(pos,anchor)then
                    local extended=d>c.profile.wRange and 90 or -100
                    local dagger=c.state.daggers[U.id(anchor)]
                    add({slot=2,anchor=anchor,pos=c.profile.id=='normal'and pos or nil,target=c.profile.id=='classic'and anchor or target,
                        combatTarget=target,dagger=dagger},extended+(dagger and U.dist(pos,dagger.pos)<=c.profile.daggerPickup and c.damage:amount('passive',target)or 0))
                end
            end
        end
    end
    if mode=='combo'and c:ready(3)and c.config:get('comboR')and d<=c.profile.rActivation then
        local short=self:estimate(target,c.hero.pos,3)
        if not short.lethal then add({slot=3},30+c.state:enemiesNear(c.hero.pos,450)*40)end
    end
    if mode=='combo'and c.config:get('ignite')then
        for slot=4,5 do if c:ready(slot)and U.name(c.state:spell(slot).name)=='summonerdot'and d<=600
            and not U.buff(target,{summonerdot=true},Game.Timer())and c.damage:lethal(slot,target,5)then add({slot=slot},10)end end
    end
    local item=c.items:activeCandidate(target,mode);if item then add(item,item.score or 0)end
    local best
    for _,a in ipairs(candidates)do if not best or a.score>best.score then best=a end end
    if best and c.state:channel()then
        if not c.config:get('smartR')or not best.lethal or best.slot==3 then return end
        if c.damage:lethal(3,target,.34)then return end
        best.release=true
    end
    if not best and mode=='combo'and not c.state:channel()then
        if c.profile.id=='classic'and c.config:get('offensiveWards')and c:ready(2)and c.mobility:slot()and d>c.profile.eRange then
            local pos=U.toward(c.hero.pos,target.pos,math.min(580,d-150))
            local result=self:estimate(target,pos,2)
            if result.lethal and self:safe(pos,target)then return {kind='wardplan',owner='combo',pos=pos,target=target,lethal=true}end
        end
        if c.config:get('extended')and d>c.profile.eRange then
            local pos=U.toward(c.hero.pos,target.pos,math.min(375,d-100))
            if self:safe(pos,target)and self:estimate(target,pos).lethal then
                for slot=4,5 do if c:ready(slot)and U.name(c.state:spell(slot).name)=='summonerflash'then return {slot=slot,owner=mode,pos=pos,extended=true,target=target}end end
                for slot,x in pairs(c.items.inventory)do if x.rule and x.rule.active=='move'and c:ready(slot)and c.items:enabled(x.id)then
                    pos=U.toward(c.hero.pos,target.pos,x.rule.range)
                    if self:safe(pos,target)and self:estimate(target,pos).lethal then return {slot=slot,owner=mode,pos=pos,extended=true,rule=x.rule,itemID=x.id,target=target}end
                end end
            end
        end
    end
    return best
end
function P:farm(mode)
    local c=self.c;local usable={};local any=false
    for slot=0,2 do
        usable[slot]=c.config:get(mode..({'Q','W','E'})[slot+1])and c:ready(slot)
            and not(slot==1 and mode=='last'and c.profile.id=='normal')
        any=any or usable[slot]
    end
    if not any then return end
    local best,score;local nearby={};local hits=0
    for i=1,math.min(#c.minions,128)do local o=c.minions[i]
        if U.valid(o)and U.dist(c.hero.pos,o.pos)<=c.profile.eRange and(mode=='jungle'and o.team==300 or mode~='jungle'and o.team~=300 and o.team~=c.hero.team)then
            if #nearby<32 then nearby[#nearby+1]=o end
            if U.dist(c.hero.pos,o.pos)<=c.profile.wRange then hits=hits+1 end
        end
    end
    for _,o in ipairs(nearby)do
        local eligible=U.valid(o)and(mode=='jungle'and o.team==300 or mode~='jungle'and o.team~=c.hero.team and o.team~=300)
        if eligible and U.dist(c.hero.pos,o.pos)<c.profile.eRange then
            for slot=0,2 do if usable[slot]and not(slot==1 and (mode=='lane'or c.profile.id=='normal')and hits<c.config:get('clearHits'))then
                local a={slot=slot,owner=mode,target=o,farm=true,anchor=slot==2 and o or nil}
                if c.profile.id=='normal'and slot==2 then a.pos=c:landing(o,o)end
                local impact=slot==0 and .25+U.dist(c.hero.pos,o.pos)/c.profile.qSpeed or slot==1 and c.profile.id=='normal'and 1.25 or .2
                local at,observedHP=Game.Timer(),o.health
                local hp=c:healthPrediction(o,impact)
                local damage=c.damage:amount(slot,o)
                local aaSaved=mode=='last'and hp>0 and damage>=hp and c:aaSaves(o,impact)or false
                local valid=hp>0 and(mode~='last'or damage>=hp and not aaSaved)
                if slot==1 and c.profile.id=='normal'then valid=mode~='last'and hits>=c.config:get('clearHits')end
                if slot==1 and mode=='lane'then valid=valid and hits>=c.config:get('clearHits')end
                local facts=valid and {target=o,impact=impact,hp=hp,damage=damage,aaSaved=aaSaved,at=at,observedHP=observedHP}
                if valid and c:legal(a,nil,facts)then
                    local s=(damage>=hp and 1000 or 0)+(slot==1 and hits*100 or 0)-(o.health or 0)*.01
                    if not score or s>score then best,score=a,s end
                end
            end end
        end
    end
    return best
end
return P

end
modules["kata.profiles"]=function(require)
-- Values come from installed character BINs (research/katarina/installed).
-- Asset evidence is not live validation. Readiness always comes from the host.
local P={build='2026-09-24-kata-2',classic={id='classic',hero='Jade_Katarina',mapID=453,
    qRange=675,qSpeed=1600,wRange=375,eRange=700,jumpRange=700,rRange=550,rActivation=500,
    qBase={60,85,110,135,160},qAP=.45,wBase={40,75,110,145,180},wAP=.25,wAD=.6,
    eBase={60,85,110,135,160},eAP=.4,eAD=0,markBase={15,30,45,60,75},markAP=.15,
    rBase={40,57.5,75},rAP=.25,rAD=.375,rTicks=4,rDuration=2.5,
    marks={jade_katarinaqbuff=true},channels={jade_katarinarsound=true},rNames={jade_katarinar=true},
    spellNames={[0]={jade_katarinaq=true},[1]={jade_katarinaw=true},[2]={jade_katarinae=true},[3]={jade_katarinar=true}},
    wards={[772043]='stack',[772044]='stack',[772045]='charge',[772049]='charge',[772050]='stack',[773154]='cooldown',[773160]='cooldown',[773340]='charge'},
    wardInventoryCharges={[772045]=true,[772049]=true},yellowWard=773340,
    -- Lower legal E bound retained where castRange=700 disagrees with display=725.
    evidence={eRange='installed castRange; display disagrees',wRange='pinned Classic controller, conservative 375',damage='installed BIN named data; live unverified'}},
    normal={id='normal',hero='Katarina',mapID=11,qRange=625,qSpeed=1800,wRange=340,eRange=725,jumpRange=725,rRange=550,rActivation=500,
    qBase={80,115,150,185,220},qAP=.4,eBase={20,30,40,50,60},eAP=.25,eAD=.4,
    rBase={25,37.5,50},rAP=.19,rTicks=6,rDuration=2.5,rOnHit={.25,.30,.35},
    daggerRadius=340,daggerPickup=140,daggerDuration=4,daggerLand=1.25,eOffset=140,
    channels={katarinarsound=true},rNames={katarinar=true},marks={},wards={},
    spellNames={[0]={katarinaq=true},[1]={katarinaw=true},[2]={katarinaewrapper=true,katarinae=true},[3]={katarinar=true}},
    evidence={eRange='installed KatarinaE and display override',damage='installed named data; physical R and passive level curve separately catalogued'}}}
P.protection={judicatorintervention=true,kayler=true,undyingrage=true,tryndamereundyingrage=true,
    kindredrnodeathbuff=true,zhonyasringshield=true,bardrstasis=true,zileanr=true,zileanchronoshift=true,
    chronoshift=true,willrevive=true,guardianangel=true,aniviapassiverebirth=true}
P.spellShield={bansheesveil=true,sivire=true,nocturneshroudofdarkness=true,malzaharpassiveshield=true}
-- Recognized targeted interrupts only. Classic names are pinned in ClassicAIOv2
-- Fiora's WAttackList; no alias is generated by prefixing a modern name.
P.interrupts={classic={jade_leonashieldofdaybreakattack=true,jade_leonashieldofdaybreak=true,
    jade_blitzcrankpowerfistattack=true,jade_blitzcrankpowerfist=true,jade_garenqattack=true,
    jade_xinzhaoq_thrust3=true,jade_twistedfate_goldcardattack=true},
    normal={leonashieldofdaybreakattack=true,powerfistattack=true,goldcardattack=true}}
function P.select(name)if name=='Jade_Katarina'then return P.classic elseif name=='Katarina'then return P.normal end end
return P

end
modules["kata.state"]=function(require)
local U=require('kata.util');local Profiles=require('kata.profiles')
local S={};S.__index=S
function S.new(c)return setmetatable({c=c,objects={},daggers={},consumed={},expected={},spells={},events={},serial=0,scanIndex=1,scanSeen={},scanEpoch=0},S)end
function S:spell(slot)return self.c.hero:GetSpellData(slot)or {}end
function S:ready(slot)
    local d=self:spell(slot)
    return (slot>=4 or (d.level or 0)>0) and (d.currentCd or 0)<=0 and Game.CanUseSpell(slot)==0
end
function S:channel()
    local c=self.c;local a=c.hero.activeSpell
    return (a and a.valid and c.profile.rNames[U.name(a.name)] and a.isStopped~=true)
        or U.buff(c.hero,c.profile.channels,Game.Timer())~=nil
end
function S:mark(o)return U.buff(o,self.c.profile.marks,Game.Timer(),U.id(self.c.hero))end
function S:interruptIncoming()
    local c=self.c;local names=Profiles.interrupts[c.profile.id]
    for _,o in ipairs(c.enemies)do
        local a=U.valid(o)and o.activeSpell
        if a and a.valid and names[U.name(a.name)]and(a.target==U.id(c.hero)or a.target==c.hero.handle)
            and(a.castEndTime or a.endTime or 0)>=Game.Timer()-.05 then return true end
    end
    return false
end
function S:emit(slot,source,at)
    self.serial=self.serial+1
    self.events[slot]={serial=self.serial,at=at or Game.Timer(),slot=slot,source=source,pos=U.copy(self.c.hero.pos)}
end
function S:refresh()
    local c=self.c;local now=Game.Timer();self.now=now
    for _,kind in ipairs({'heroes','minions','wards','turrets'})do
        local list=c.sdk.SharedData and c.sdk.SharedData:GetObjects(kind)
        if not list then
            list={};local stem=({heroes='Hero',minions='Minion',wards='Ward',turrets='Turret'})[kind]
            local count,get=Game[stem..'Count'],Game[stem]
            if count and get then for i=1,U.count(count(),kind=='heroes'and 20 or 512)do local o=get(i);if o then list[#list+1]=o end end end
        end
        self.objects[kind]=list
    end
    c.enemies={};c.allies={};c.minions=self.objects.minions
    for _,o in ipairs(self.objects.heroes)do if not U.same(o,c.hero)then
        if o.team==c.hero.team then c.allies[#c.allies+1]=o else c.enemies[#c.enemies+1]=o end
    end end
    local active=c.hero.activeSpell
    for slot=0,12 do
        local d=self:spell(slot);local prev=self.spells[slot]
        local start=d.castTime
        -- Host castTime may be cooldown end, as in Orbama's attack-reset contract.
        if U.finite(start)and start>now+.05 then start=start-(d.cd or d.currentCd or 0)end
        if U.finite(start)and start>0 and start<=now+.05 and prev and start>(prev.castTime or 0)then self:emit(slot,'spell_cast_time',start)end
        if prev and prev.cd<=0 and(d.currentCd or 0)>0 then self:emit(slot,'cooldown_transition',now)end
        if slot<4 and active and active.valid and c.profile.spellNames[slot][U.name(active.name)]then
            local t=active.startTime
            if U.finite(t)and (not prev or prev.activeStart~=t)then self:emit(slot,'active_spell',t)end
        end
        self.spells[slot]={name=d.name,cd=d.currentCd or 0,castTime=start,activeStart=active and active.valid and active.startTime}
    end
    if c.profile.id=='normal'then
        self:scan()
        if active and active.valid and U.name(active.name)=='katarinadaggerpickuppbaoe'and active.startTime~=self.lastPickup then
            self.lastPickup=active.startTime
            local near={}
            for _,d in pairs(self.daggers)do if U.dist(c.hero.pos,d.pos)<=c.profile.daggerPickup then near[#near+1]=d end end
            if #near==1 then
                local d=near[1];d.state='consumed';self.consumed[d.id]=d.expires;self.daggers[d.id]=nil
                c:log('effect_dagger_pickup',{target=d.object},'observed passive; unique nearby dagger')
            elseif #near>1 then
                for _,d in ipairs(near)do d.ambiguousPickup=true;d.state='pickup_unresolved'end
            end
        end
    end
end
function S:expect(slot,origin,target)
    if self.c.profile.id=='classic'and slot==0 and target then
        self.qFlight={target=U.id(target),expires=Game.Timer()+.25+U.dist(origin,target.pos)/self.c.profile.qSpeed};return
    end
    if self.c.profile.id~='normal'or (slot~=0 and slot~=1)then return end
    local pos=slot==1 and U.copy(origin)or target and U.toward(target.pos,origin,-350)
    if not pos then return end
    local now=Game.Timer();self.expected[#self.expected+1]={slot=slot,pos=pos,at=now,land=now+(slot==1 and 1.25 or U.dist(origin,target.pos)/self.c.profile.qSpeed+1),expires=now+6}
    while #self.expected>8 do table.remove(self.expected,1)end
end
function S:acceptDagger(o,index)
    if not o then return end
    local name=U.name(o.name or o.charName)
    -- Most particles are unrelated. Reject by name before native position,
    -- identity and ownership reads; discovery cadence and budget stay intact.
    if not name:find('katarina',1,true)or not name:find('_w_indicator',1,true)then return end
    if name:find('enemy',1,true)then return end
    local c=self.c;local id=U.id(o)
    if not id or not U.position(o.pos)or o.valid==false or o.dead then return end
    if self.consumed[id]and self.consumed[id]>Game.Timer()then return end
    -- Only a dagger-specific marker plus ownership/cast correlation qualifies.
    local owner=o.ownerID or o.ownerNetworkID or(o.owner and U.id(o.owner))
    if owner and owner~=0 and owner~=U.id(c.hero)and owner~=c.hero.handle then return end
    local now=Game.Timer();local match,ambiguity
    for _,x in ipairs(self.expected)do
        if now>=x.at and now<=x.expires and U.dist(o.pos,x.pos)<110 then
            if match then ambiguity=true end;match=x
        end
    end
    if (not owner or owner==0)and(not match or ambiguity)then return end
    local old=self.daggers[id]
    if old and old.object~=o and U.dist(old.pos,o.pos)>10 then old=nil end
    if not old then
        local count=0;for _ in pairs(self.daggers)do count=count+1 end;if count>=16 then return end
        local land=match and match.land or now+c.profile.daggerLand
        local expire=o.expireTime and o.expireTime>now and o.expireTime or land+c.profile.daggerDuration
        old={id=id,object=o,pos=U.copy(o.pos),land=land,expires=expire,source=match and match.slot,owned=true,state='observed'}
        self.daggers[id]=old
    end
    old.lastSeen=now;old.epoch=self.scanEpoch;old.pos=U.copy(o.pos);old.index=index or old.index
    old.state=now>=old.land and 'pickup_candidate'or 'observed'
    self.scanSeen[id]=true
end
function S:scan()
    local now=Game.Timer()
    for id,expiry in pairs(self.consumed)do if now>expiry then self.consumed[id]=nil end end
    for i=#self.expected,1,-1 do if now>self.expected[i].expires then table.remove(self.expected,i)end end
    for id,d in pairs(self.daggers)do
        if now>d.expires or d.object.valid==false or d.object.dead then self.daggers[id]=nil
        elseif now>=d.land then d.state='pickup_candidate'end
    end
    local count=Game.ParticleCount and U.count(Game.ParticleCount(),8192)or 0
    local get=Game.Particle
    if count==0 and Game.ObjectCount then count=U.count(Game.ObjectCount(),8192);get=Game.Object end
    if not get or count==0 then return end
    -- Refresh at most sixteen known marker identities before the bounded new-object
    -- scan, so a large particle list cannot starve already discovered daggers.
    for id,d in pairs(self.daggers)do if d.index then
        local object=get(d.index)
        if U.id(object)==id then self:acceptDagger(object,d.index)else self.daggers[id]=nil end
    end end
    if self.scanIndex>count then self.scanIndex=1;self.scanEpoch=self.scanEpoch+1;self.scanSeen={}end
    -- A fixed slice, independent of particle-count changes; catches replacements.
    for _=1,math.min(count,256)do
        self:acceptDagger(get(self.scanIndex),self.scanIndex);self.scanIndex=self.scanIndex+1
        if self.scanIndex>count then self.scanIndex=1;self.scanEpoch=self.scanEpoch+1;break end
    end
end
function S:daggerValid(d)return d and self.daggers[d.id]==d and not d.ambiguousPickup and d.owned and Game.Timer()>=d.land and Game.Timer()<d.expires and d.object.valid~=false and not d.object.dead and Game.Timer()-d.lastSeen<=.35 end
function S:enemiesNear(pos,range)
    local n=0;for _,o in ipairs(self.c.enemies)do if U.valid(o)and U.dist(pos,o.pos)<=range then n=n+1 end end;return n
end
function S:turret(pos)
    for _,t in ipairs(self.objects.turrets or {})do if U.valid(t)and t.team~=self.c.hero.team and U.dist(pos,t.pos)<(t.range or 775)+(t.boundingRadius or 80)then return true end end
    return false
end
return S

end
modules["kata.util"]=function(require)
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

end
local function load(name)
 if cache[name]~=nil then return cache[name] end
 if not modules[name] then return externalRequire(name) end
 local value=modules[name](load);cache[name]=value;return value
end
local app
local ok,why=pcall(function()app=load('kata.app').new();app.generation=generation;app:init();app:install()end)
if not ok then if app then pcall(app.Shutdown,app,'load_failed')end;print('[Kata Hari] Load failed: '..tostring(why));return end
local legacy=_G.ClassicAIOv2
if myHero.charName=='Jade_Katarina' and legacy and legacy.enabled then
 local closed=pcall(legacy.Shutdown,legacy,'standalone_katarina')
 if not closed or legacy.enabled then app:Shutdown('legacy_cleanup_failed');return end
end
_G.KatarinaController=app
print('[Kata Hari] Loaded '..app.profile.id..' '..app.build)
return app
end
if not SDK and Callback and Callback.Add and DelayAction then
 -- The provider's Load callback may run after this file was evaluated.
 local pending=true
 Callback.Add('Load',function()
  if pending then pending=false;DelayAction(function()boot()end,.1)end
 end)
 return
end
return boot()

end,6)
