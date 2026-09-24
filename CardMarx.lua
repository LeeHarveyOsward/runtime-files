-- Release 6
if not myHero or (myHero.charName~='TwistedFate' and myHero.charName~='Jade_TwistedFate') then return end
local client=_G.CardMarxReleaseClient
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
client=create(_G,hash,6,"https://raw.githubusercontent.com/LeeHarveyOsward/runtime-files",{names={'CardMarx'},channel='cardmarx',cachePrefix='runtime-cardmarx-'})
_G.CardMarxReleaseClient=client
end
return client:Boot("CardMarx",function()
if myHero and (myHero.charName=='TwistedFate' or myHero.charName=='Jade_TwistedFate') and SDK and SDK.OrbamaVersion and not _G.GGPrediction then
(function()
-- OrbamaPrediction: compatible fork of GGPrediction 1.59 (original in reference/).
-- No runtime updater. GGPrediction and OrbamaPrediction share one instance.
if _G.OrbamaPrediction then _G.GGPrediction=_G.OrbamaPrediction;return _G.OrbamaPrediction end
if _G.GGPrediction then
    print('[OrbamaPrediction] Another prediction instance is already loaded; reload the runtime to switch safely.')
    return _G.GGPrediction
end
local Version = '1.0.0'
local math_huge = math.huge
local math_pi = math.pi
local math_sqrt = assert(math.sqrt)
local math_abs = assert(math.abs)
local math_min = assert(math.min)
local math_max = assert(math.max)
local math_pow = assert(math.pow)
local math_atan = assert(math.atan)
local math_acos = assert(math.acos)
local table_remove = assert(table.remove)
local table_insert = assert(table.insert)
local Game, Vector, Draw, Callback = _G.Game, _G.Vector, _G.Draw, _G.Callback
local Menu, Immobile, Math, Path, UnitData, ObjectManager, Collision, Prediction, YasuoWall
local COLLISION_MINION = 0
local COLLISION_ALLYHERO = 1
local COLLISION_ENEMYHERO = 2
local COLLISION_YASUOWALL = 3
local HITCHANCE_IMPOSSIBLE = 0
local HITCHANCE_COLLISION = 1
local HITCHANCE_NORMAL = 2
local HITCHANCE_HIGH = 3
local HITCHANCE_IMMOBILE = 4
local SPELLTYPE_LINE = 0
local SPELLTYPE_CIRCLE = 1
local SPELLTYPE_CONE = 2

YasuoWall = {
	HasYasuo = false,
	Hero = nil,
	wallCastPos = nil,
	wallPos = nil,
	wallLevel = 0,
	wallCastTime = 0,
	LastScanTime = 0,
	WALL_DURATION = 4,
	SCAN_INTERVAL = 0.1,
}

function YasuoWall:OnEnemyHeroLoad(args)
	if args.charName == "Yasuo" or args.charName == "Jade_Yasuo" then
		self.HasYasuo = true
		self.Hero = args.unit
	end
end

function YasuoWall:OnTick()
	local currentTime = Game.Timer()
	if self.wallCastTime > 0 and currentTime - self.wallCastTime > self.WALL_DURATION then
		self.wallLevel = 0
		self.wallCastTime = 0
		self.wallCastPos = nil
		self.wallPos = nil
	end
	if not self.HasYasuo or not self.Hero or not Game.ParticleCount then return end
	if currentTime - self.LastScanTime < self.SCAN_INTERVAL then
		return
	end
	self.LastScanTime = currentTime
	local wLevel = self.Hero:GetSpellData(_W).level
	if wLevel > self.wallLevel then
		self.wallLevel = wLevel
	end
	local pCount = Game.ParticleCount()
	for i = 1, pCount do
		local obj = Game.Particle(i)
		if obj and obj.pos then
			local name = obj.name
			if name then
				local lower = name:lower()
				if lower:find("yasuo", 1, true) then
					if lower:find("_w_windwall_activate", 1, true) then
						if not self.wallCastPos then
							self.wallCastPos = Math:Get2D(obj.pos)
						end
						if self.wallCastTime == 0 then
							self.wallCastTime = currentTime
						end
					elseif lower:find("_w_windwall_enemy", 1, true) then
						self.wallPos = obj.pos
					end
				end
			end
		end
	end
end

function YasuoWall:IsWallActive()
	return self.HasYasuo and self.wallCastPos and self.wallPos and Game.Timer() - self.wallCastTime <= self.WALL_DURATION
end

function YasuoWall:CheckCollision(source, castPos)
	if not self:IsWallActive() then
		return false
	end
	local pos = Math:Get2D(self.wallPos)
	local wallThickness = 100
	local width = 250 + 70 * self.wallLevel + wallThickness
	local direction = Math:Perpendicular(Math:Normalized(pos, self.wallCastPos))
	local startPos = Math:Extended(pos, direction, width / 2)
	local endPos = Math:Extended(startPos, direction, -width)
	local intersectionResult = Math:Intersection(startPos, endPos, source, castPos)
	return intersectionResult.Intersects
end

-- stylua: ignore start
local __menu = MenuElement({name = "Orbama Prediction", id = "GGPrediction", type = _G.MENU})

Menu =
{
    MaxRange = __menu:MenuElement({id = "PredMaxRange" .. myHero.charName, name = "Pred Max Range %", value = 100, min = 70, max = 100, step = 1}),
    Latency = __menu:MenuElement({id = "Latency", name = "Ping/Latency", value = 50, min = 0, max = 200, step = 5}),
    ExtraDelay = __menu:MenuElement({id = "ExtraDelay", name = "Extra Delay", value = 60, min = 0, max = 100, step = 5}),
    VersionA = __menu:MenuElement({name = '', type = _G.SPACE, id = 'VersionSpaceA'}),
    VersionB = __menu:MenuElement({name = 'Version  ' .. Version, type = _G.SPACE, id = 'VersionSpaceB'}),
}
-- stylua: ignore end

function Menu:GetMaxRange()
	local result = self.MaxRange:Value() * 0.01
	return result
end

function Menu:GetLatency()
	local latency = Game.Latency()
	local result = type(latency)=='number' and latency==latency and latency>=0 and latency<math_huge and latency or self.Latency:Value()
	return result * 0.001
end

function Menu:GetExtraDelay()
	local result = self.ExtraDelay:Value() * 0.001
	return result
end
--[[
enum class BuffType {
    Internal = 0,
    Aura = 1,
    CombatEnchancer = 2,
    CombatDehancer = 3,
    SpellShield = 4,
    Stun = 5,
    Invisibility = 6,
    Silence = 7,
    Taunt = 8,
    Berserk = 9,
    Polymorph = 10,
    Slow = 11,
    Snare = 12,
    Damage = 13,
    Heal = 14,
    Haste = 15,
    SpellImmunity = 16,
    PhysicalImmunity = 17,
    Invulnerability = 18,
    AttackSpeedSlow = 19,
    NearSight = 20,
    Fear = 22,
    Charm = 23,
    Poison = 24,
    Suppression = 25,
    Blind = 26,
    Counter = 27,
    Currency = 21,
    Shred = 28,
    Flee = 29,
    Knockup = 30,
    Knockback = 31,
    Disarm = 32,
    Grounded = 33,
    Drowsy = 34,
    Asleep = 35,
    Obscured = 36,
    ClickProofToEnemies = 37,
    Unkillable = 38
};
--]]

Immobile = {
	IMMOBILE_TYPES = {
		[5] = true,
		[12] = true,
		[25] = true,
		[30] = true,
		[35] = true,
	},
}

function Immobile:GetDuration(unit)
	local SpellCastTime = 0
	local AttackCastTime = 0
	local ImmobileDuration = 0
	local KnockDuration = 0
	local buffs = SDK.BuffManager:GetBuffs(unit)
	local now=Game.Timer()
	for i = 1, #buffs do
		local buff = buffs[i]
		-- Hosts differ on duration (remaining vs original length). Positive
		-- expiry timestamps are authoritative; zero expireTime may accompany
		-- a valid endTime. Never promote an expired/deleted buff to hard CC.
		local finish=buff.expireTime
		if type(finish)~='number' or finish<=0 or finish~=finish or finish==math_huge then finish=buff.endTime end
		local duration=type(finish)=='number' and finish>0 and finish<math_huge and math_max(0,finish-now) or buff.duration or 0
		if type(duration)~='number' or duration~=duration or duration==math_huge or buff.count==0 then duration=0 end
		if duration > 0 then
			if buff.type == 31 or buff.name == "ThreshQ" or buff.name == "Jade_ThreshQ" then
				KnockDuration = math_max(KnockDuration, duration)
			elseif duration > ImmobileDuration and self.IMMOBILE_TYPES[buff.type] then
				ImmobileDuration = duration
			end
		end
	end
	local spell = unit.activeSpell
	if spell and spell.valid then
		if spell.isAutoAttack then
			AttackCastTime = spell.castEndTime or 0
		elseif (spell.windup or 0) > 0.1 then
			SpellCastTime = spell.castEndTime or 0
		end
	end
	return ImmobileDuration, SpellCastTime, AttackCastTime, KnockDuration
end

function Immobile:CanHit(unit, timeToHit, radius)
	local immobileDuration, spellCastTime, attackCastTime, knockDuration = self:GetDuration(unit)
	local timer = Game.Timer()
	local spellDuration = math_max(0, spellCastTime - timer)
	local attackDuration = math_max(0, attackCastTime - timer)
	local lockDuration = math_max(immobileDuration, spellDuration, attackDuration)
	local moveSpeed = unit.ms or 0
	local radiusDuration = moveSpeed > 0 and (radius or 0) / moveSpeed or 0
	local isLocked = lockDuration > 0
	local canHit = isLocked and timeToHit + 0.02 < lockDuration + radiusDuration
	return canHit, isLocked, immobileDuration, knockDuration
end
Math = {}

function Math:Get2D(p)
	p = p.pos == nil and p or p.pos
	return { x = p.x, z = p.z == nil and p.y or p.z }
end

function Math:Get3D(p)
	local result = Vector(p.x, p.y, p.z)
	return result
end

function Math:GetDistance(p1, p2)
	local dx = p2.x - p1.x
	local dz = p2.z - p1.z
	return math_sqrt(dx * dx + dz * dz)
end

function Math:IsInRange(p1, p2, range)
	local dx = p1.x - p2.x
	local dz = p1.z - p2.z
	if dx * dx + dz * dz <= range * range then
		return true
	end
	return false
end

function Math:VectorsEqual(p1, p2, num)
	num = num or 5
	if self:GetDistance(p1, p2) < num then
		return true
	end
	return false
end

function Math:Normalized(p1, p2)
	local dx = p1.x - p2.x
	local dz = p1.z - p2.z
	local length = math_sqrt(dx * dx + dz * dz)
	local sol = nil
	if length > 0 then
		local inv = 1.0 / length
		sol = { x = (dx * inv), z = (dz * inv) }
	end
	return sol
end

function Math:Extended(vec, dir, range)
	if dir == nil then
		return vec
	end
	return { x = vec.x + dir.x * range, z = vec.z + dir.z * range }
end

function Math:Perpendicular(dir)
	if dir == nil then
		return nil
	end
	return { x = -dir.z, z = dir.x }
end

function Math:Intersection(s1, e1, s2, e2)
	local IntersectionResult = { Intersects = false, Point = { x = 0, z = 0 } }
	local deltaACz = s1.z - s2.z
	local deltaDCx = e2.x - s2.x
	local deltaACx = s1.x - s2.x
	local deltaDCz = e2.z - s2.z
	local deltaBAx = e1.x - s1.x
	local deltaBAz = e1.z - s1.z
	local denominator = deltaBAx * deltaDCz - deltaBAz * deltaDCx
	local numerator = deltaACz * deltaDCx - deltaACx * deltaDCz
	if denominator == 0 then
        if numerator ~= 0 then return IntersectionResult end
        local length2=deltaBAx*deltaBAx+deltaBAz*deltaBAz
        if length2==0 then
            local dx,dz=e2.x-s2.x,e2.z-s2.z
            local cross=(s1.x-s2.x)*dz-(s1.z-s2.z)*dx
            if cross==0 and s1.x>=math_min(s2.x,e2.x) and s1.x<=math_max(s2.x,e2.x)
                and s1.z>=math_min(s2.z,e2.z) and s1.z<=math_max(s2.z,e2.z) then
                return {Intersects=true,Point={x=s1.x,z=s1.z}}
            end
            return IntersectionResult
        end
        local t0=((s2.x-s1.x)*deltaBAx+(s2.z-s1.z)*deltaBAz)/length2
        local t1=((e2.x-s1.x)*deltaBAx+(e2.z-s1.z)*deltaBAz)/length2
        local lo,hi=math_max(0,math_min(t0,t1)),math_min(1,math_max(t0,t1))
        if lo<=hi then return {Intersects=true,Point={x=s1.x+lo*deltaBAx,z=s1.z+lo*deltaBAz}} end
        return IntersectionResult
    end
	local r = numerator / denominator
	if r < 0 or r > 1 then
		return IntersectionResult
	end
	local s = (deltaACz * deltaBAx - deltaACx * deltaBAz) / denominator
	if s < 0 or s > 1 then
		return IntersectionResult
	end
	local point = { x = s1.x + r * deltaBAx, z = s1.z + r * deltaBAz }
	return { Intersects = true, Point = point }
end

function Math:ClosestPointOnLineSegment(p, p1, p2)
	local px = p.x
	local pz = p.z
	local ax = p1.x
	local az = p1.z
	local bx = p2.x
	local bz = p2.z
	local bxax = bx - ax
	local bzaz = bz - az
	local length2 = bxax * bxax + bzaz * bzaz
	if length2 == 0 then return {x=ax,z=az}, false end
	local t = ((px - ax) * bxax + (pz - az) * bzaz) / length2
	if t < 0 then
		return p1, false
	end
	if t > 1 then
		return p2, false
	end
	return { x = ax + t * bxax, z = az + t * bzaz }, true
end

function Math:Intercept(src, spos, epos, sspeed, tspeed)
	local dx = epos.x - spos.x
	local dz = epos.z - spos.z
	local magnitude = math_sqrt(dx * dx + dz * dz)
	local tx = spos.x - src.x
	local tz = spos.z - src.z
	if sspeed<=0 then return nil end
	if sspeed==math_huge then return 0 end
	if magnitude==0 or tspeed==0 then return math_sqrt(tx*tx+tz*tz)/sspeed end
	local tvx = (dx / magnitude) * tspeed
	local tvz = (dz / magnitude) * tspeed
	local a = tvx * tvx + tvz * tvz - sspeed * sspeed
	local b = 2 * (tvx * tx + tvz * tz)
	local c = tx * tx + tz * tz
	local ts
	if math_abs(a) < 1e-6 then
		if math_abs(b) < 1e-6 then
			if math_abs(c) < 1e-6 then
				ts = { 0, 0 }
			end
		else
			ts = { -c / b, -c / b }
		end
	else
		local disc = b * b - 4 * a * c
		if disc >= 0 then
			disc = math_sqrt(disc)
			local a = 2 * a
			ts = { (-b - disc) / a, (-b + disc) / a }
		end
	end
	local sol
	if ts then
		local t0 = ts[1]
		local t1 = ts[2]
		local t = math_min(t0, t1)
		if t < 0 then
			t = math_max(t0, t1)
		end
		if t > 0 then
			sol = t
		end
	end
	return sol
end

function Math:Polar(p1)
	local x = p1.x
	local z = p1.z
	if x == 0 then
		if z > 0 then
			return 90
		end
		if z < 0 then
			return 270
		end
		return 0
	end
	local theta = math_atan(z / x) * (180.0 / math_pi) --RadianToDegree
	if x < 0 then
		theta = theta + 180
	end
	if theta < 0 then
		theta = theta + 360
	end
	return theta
end

function Math:AngleBetween(p1, p2)
	if p1 == nil or p2 == nil then
		return nil
	end
	local theta = self:Polar(p1) - self:Polar(p2)
	if theta < 0 then
		theta = theta + 360
	end
	if theta > 180 then
		theta = 360 - theta
	end
	return theta
end

function Math:FindAngle(p1, center, p2)
	local b = math_pow(center.x - p1.x, 2) + math_pow(center.z - p1.z, 2)
	local a = math_pow(center.x - p2.x, 2) + math_pow(center.z - p2.z, 2)
	local c = math_pow(p2.x - p1.x, 2) + math_pow(p2.z - p1.z, 2)
	if a==0 or b==0 then return 0 end
	local cosine=math_max(-1,math_min(1,(a + b - c) / math_sqrt(4 * a * b)))
	local angle = math_acos(cosine) * (180 / math_pi)
	if angle > 90 then
		angle = 180 - angle
	end
	return angle
end

function Math:CircleCircleIntersection(center1, center2, radius1, radius2)
	local result = {}
	local D = self:GetDistance(center1, center2)
	if radius1<0 or radius2<0 or D==0 or D > radius1 + radius2 or D < math_abs(radius1 - radius2) then
		return result
	end
	local A = (radius1 * radius1 - radius2 * radius2 + D * D) / (2 * D)
	local H = math_sqrt(math_max(0,radius1 * radius1 - A * A))
	local Direction = self:Normalized(center2, center1)
	local PA = self:Extended(center1, Direction, A)
	local DirectionPerpendicular = self:Perpendicular(Direction)
	table_insert(result, self:Extended(PA, DirectionPerpendicular, H))
	if H>0 then table_insert(result, self:Extended(PA, DirectionPerpendicular, -H)) end
	return result
end

function Math:MEC(points)
	local n = #points
	if n == 0 then
		return nil, 0
	end
	if n == 1 then
		return { x = points[1].x, z = points[1].z }, 0
	end
	local bestC, bestR = nil, math_huge
	local function covers(cx, cz, r)
		local r2 = (r + 0.01) * (r + 0.01)
		for k = 1, n do
			local dx, dz = points[k].x - cx, points[k].z - cz
			if dx * dx + dz * dz > r2 then
				return false
			end
		end
		return true
	end
	for i = 1, n - 1 do
		for j = i + 1, n do
			local cx, cz = (points[i].x + points[j].x) / 2, (points[i].z + points[j].z) / 2
			local dx, dz = points[i].x - cx, points[i].z - cz
			local r = math_sqrt(dx * dx + dz * dz)
			if r < bestR and covers(cx, cz, r) then
				bestC, bestR = { x = cx, z = cz }, r
			end
		end
	end
	for i = 1, n - 2 do
		for j = i + 1, n - 1 do
			for k = j + 1, n do
				local ax, az = points[i].x, points[i].z
				local bx, bz = points[j].x, points[j].z
				local cx, cz = points[k].x, points[k].z
				local d = 2 * (ax * (bz - cz) + bx * (cz - az) + cx * (az - bz))
				if math_abs(d) > 1e-6 then
					local a2, b2, c2 = ax * ax + az * az, bx * bx + bz * bz, cx * cx + cz * cz
					local ux = (a2 * (bz - cz) + b2 * (cz - az) + c2 * (az - bz)) / d
					local uz = (a2 * (cx - bx) + b2 * (ax - cx) + c2 * (bx - ax)) / d
					local dx, dz = ax - ux, az - uz
					local r = math_sqrt(dx * dx + dz * dz)
					if r < bestR and covers(ux, uz, r) then
						bestC, bestR = { x = ux, z = uz }, r
					end
				end
			end
		end
	end
	return bestC, bestR
end

Path = {}

function Path:GetLenght(path)
	local result = 0
	for i = 1, #path - 1 do
		result = result + Math:GetDistance(path[i], path[i + 1])
	end
	return result
end

function Path:CutPath(path, distance)
	local result = {}
	if distance <= 0 then
		return path
	end
	for i = 1, #path - 1 do
		local a, b = path[i], path[i + 1]
		local dist = Math:GetDistance(a, b)
		if dist > distance then
			table_insert(result, Math:Extended(a, Math:Normalized(b, a), distance))
			for j = i + 1, #path do
				table_insert(result, path[j])
			end
			break
		end
		distance = distance - dist
	end
	return #result > 0 and result or { path[#path] }
end  
function Path:CutPath2(path, distance, endPoint)
    local result = {}
    if distance <= 0 then
        return path
    end
    for i = 1, #path - 1 do
        local a, b = path[i], path[i + 1]
        local dist = Math:GetDistance(a, b)
        if dist > distance then
            table_insert(result, Math:Extended(a, Math:Normalized(b, a), distance))
            for j = i + 1, #path do
                table_insert(result, path[j])
            end
			distance=0
            break
        end
        distance = distance - dist
    end
    
    -- Check if there's still some distance left and if endPoint is provided
    if distance > 0 and endPoint then
        local lastPoint = result[#result] or path[#path]
        local distanceToEnd = Math:GetDistance(lastPoint, endPoint)
        
        -- If the distance to the endPoint is less than the remaining distance,
        -- then just add the endPoint to the result
		local backfillDistance = math_max(distance - 5, 0)
		if distanceToEnd <= backfillDistance then
            table_insert(result, endPoint)
        else
			table_insert(result, Math:Extended(lastPoint, Math:Normalized(endPoint, lastPoint), backfillDistance))
        end
    end
    
    return #result > 0 and result or { path[#path] }
end






function Path:ReversePath(path)
	local result = {}
	for i = #path, 1, -1 do
		table_insert(result, path[i])
	end
	return result
end

function Path:GetPath(unit)
	local currentPos = Math:Get2D(unit.pos)
	local result = { currentPos }
	local pathing = unit.pathing
	if not pathing or not pathing.hasMovePath then
		return result
	end

	if pathing.isDashing then
		local endPos = pathing.endPos
		if endPos ~= nil and endPos.x ~= nil then
			local point = Math:Get2D(endPos)
			if not Math:VectorsEqual(currentPos, point, 1) then
				table_insert(result, point)
			end
		end
		return result
	end

	local pathIndex = pathing.pathIndex or 0
	local pathCount = pathing.pathCount or -1
	for i = pathIndex, pathCount do
		local pos = unit.GetPath and unit:GetPath(i)
		if pos ~= nil and pos.x ~= nil then
			local point = Math:Get2D(pos)
			if not Math:VectorsEqual(result[#result], point, 1) then
				table_insert(result, point)
			end
		end
	end
	return result
end

function Path:GetPredictedPath(source, speed, movespeed, path)
	local result = {}
	local tT = 0
	for i = 1, #path - 1 do
		local a = path[i]
		table_insert(result, a)
		local b = path[i + 1]
		local tB = Math:GetDistance(a, b) / movespeed
		local direction = Math:Normalized(b, a)
		a = Math:Extended(a, direction, -(movespeed * tT))
		local t = Math:Intercept(source, a, b, speed, movespeed)
		if t and t >= tT and t <= tT + tB then
			table_insert(result, Math:Extended(a, direction, t * movespeed))
			return result, t
		end
		tT = tT + tB
	end
	return nil, -1
end
UnitData = {
	Visible = {},
	Waypoints = {},
}

function UnitData:OnVisible(id, visible)
	if self.Visible[id] == nil then
		self.Visible[id] = { visible = visible, visibleTick = GetTickCount(), invisibleTick = GetTickCount() }
	end
	if visible then
		if not self.Visible[id].visible then
			self.Visible[id].visible = true
			self.Visible[id].visibleTick = GetTickCount()
		end
	else
		if self.Visible[id].visible then
			self.Visible[id].visible = false
			self.Visible[id].invisibleTick = GetTickCount()
		end
	end
end

function UnitData:OnWaypoint(id, path, hasMovePath, isDashing, endPos)
	local timer = GetTickCount()
	if self.Waypoints[id] == nil then
		self.Waypoints[id] = {
			moving = hasMovePath,
			dashing = isDashing,
			path = path,
			tick = timer,
			stoptick = timer,
			pos = endPos,
		}
	end
	if hasMovePath then
		if not Math:VectorsEqual(self.Waypoints[id].pos, endPos, 50) then
			self.Waypoints[id].tick = timer
		end
		self.Waypoints[id].pos = endPos
	elseif self.Waypoints[id].moving then
		self.Waypoints[id].stoptick = GetTickCount()
	end
	self.Waypoints[id].path = path
	self.Waypoints[id].moving = hasMovePath
	self.Waypoints[id].dashing = isDashing
end

function UnitData:OnTick()
	local id, visible, path, pathing, hasMovePath, isDashing, endPos
	for i, unit in ipairs(ObjectManager:GetHeroes()) do
		if not YasuoWall.HasYasuo and unit.isEnemy and (unit.charName=='Yasuo' or unit.charName=='Jade_Yasuo') then
			YasuoWall:OnEnemyHeroLoad({charName=unit.charName,unit=unit})
		end
		id = unit.networkID
		visible = unit.visible
		self:OnVisible(id, visible)
		if visible then
			pathing = unit.pathing
			if pathing then
				hasMovePath = pathing.hasMovePath
				isDashing = pathing.isDashing
				endPos = Math:Get2D(pathing.endPos or unit.pos)
				path = Path:GetPath(unit)
				self:OnWaypoint(id, path, hasMovePath, isDashing, endPos)
			end
		end
	end
end

function UnitData:OnPrediction(unit)
	local id = unit.networkID
	local visible = unit.visible
	self:OnVisible(id, visible)
	if visible and unit.pathing then
		local hasMovePath = unit.pathing.hasMovePath
		local isDashing = unit.pathing.isDashing
		local endPos = Math:Get2D(unit.pathing.endPos or unit.pos)
		self:OnWaypoint(id, Path:GetPath(unit), hasMovePath, isDashing, endPos)
	end
end

-- One observation pass per host tick. Prediction itself refreshes its target,
-- so correctness does not depend on Draw frequency or callback ordering.
Callback.Add("Tick", function()
    UnitData:OnTick()
    YasuoWall:OnTick()
end)
ObjectManager = {}

function ObjectManager:IsValid(unit)
	if unit and unit.valid and unit.visible and not unit.dead and unit.isTargetable then
		return true
	end
	return false
end

-- Cache identities only within the current game timestamp; visibility,
-- health and targetability remain live predicates at each use.
function ObjectManager:Snapshot(kind)
    local now=Game.Timer();local count=Game[kind..'Count']()
    local old=self[kind]
    if old and old.at==now and old.count==count then return old.units end
    local units={}
    for i=1,count do local unit=Game[kind](i);if unit then units[#units+1]=unit end end
    self[kind]={at=now,count=count,units=units};return units
end
function ObjectManager:GetHeroes()
    local result={}
    for _,hero in ipairs(self:Snapshot('Hero')) do
        if hero.valid and not hero.dead then result[#result+1]=hero end
    end
    return result
end

function ObjectManager:GetEnemyHeroes()
	local _EnemyHeroes = {}
	for _,hero in ipairs(self:Snapshot('Hero')) do
		if self:IsValid(hero) and hero.isEnemy then
			table_insert(_EnemyHeroes, hero)
		end
	end
	return _EnemyHeroes
end

function ObjectManager:GetAllyHeroes()
	local _AllyHeroes = {}
	for _,hero in ipairs(self:Snapshot('Hero')) do
		if self:IsValid(hero) and hero.isAlly then
			table_insert(_AllyHeroes, hero)
		end
	end
	return _AllyHeroes
end
Collision = {}

function Collision:GetCollision(source, castPos, speed, delay, radius, collisionTypes, skipID, options)
	-- Keep legacy margins for existing callers; precise callers can opt into
	-- host hitboxes without an additional safety halo or endpoint truncation.
	local padding,trim=15,75
	if type(options)=='table' then
		if type(options.padding)=='number' and options.padding==options.padding and options.padding>=0 and options.padding<math_huge then padding=options.padding end
		if type(options.trim)=='number' and options.trim==options.trim and options.trim>=0 and options.trim<math_huge then trim=options.trim end
	end
	if trim>0 then
		source = Math:Extended(source, Math:Normalized(source, castPos), trim)
		castPos = Math:Extended(castPos, Math:Normalized(castPos, source), trim)
	end
	local isWall, collisionObjects, collisionCount = false, {}, 0
	local objects, seen = {}, {}
	local reach=Math:GetDistance(source,castPos)+radius+150
	for i, colType in pairs(collisionTypes or {0,3}) do
		if colType == COLLISION_YASUOWALL then
			isWall = YasuoWall:CheckCollision(source, castPos)
			if isWall then
				return isWall, collisionObjects, collisionCount
			end
		elseif colType == COLLISION_MINION then
			for _,unit in ipairs(ObjectManager:Snapshot('Minion')) do
				if
					unit.networkID ~= skipID
					and ObjectManager:IsValid(unit)
					and (unit.isEnemy or unit.team==300)
					and Math:IsInRange(source, Math:Get2D(unit.pos), reach+(unit.ms or 0)*(delay+(speed>0 and reach/speed or 0)))
				then
					table_insert(objects, unit)
				end
			end
		elseif colType == COLLISION_ALLYHERO then
			for k, unit in pairs(ObjectManager:GetAllyHeroes()) do
				if unit.networkID ~= skipID and Math:IsInRange(source, Math:Get2D(unit.pos), reach+(unit.ms or 0)*(delay+(speed>0 and reach/speed or 0))) then
					table_insert(objects, unit)
				end
			end
		elseif colType == COLLISION_ENEMYHERO then
			for k, unit in pairs(ObjectManager:GetEnemyHeroes()) do
				if unit.networkID ~= skipID and Math:IsInRange(source, Math:Get2D(unit.pos), reach+(unit.ms or 0)*(delay+(speed>0 and reach/speed or 0))) then
					table_insert(objects, unit)
				end
			end
		end
	end
	for i, object in ipairs(objects) do
		local id=object.networkID or object
		if not seen[id] then
		seen[id]=true
		local isCol = false
		local objectPos = Math:Get2D(object.pos)
		local pointLine, isOnSegment = Math:ClosestPointOnLineSegment(objectPos, source, castPos)
		if isOnSegment and Math:IsInRange(objectPos, pointLine, radius + padding + (object.boundingRadius or 45)) then
			isCol = true
		elseif object.pathing and object.pathing.hasMovePath and object.GetPrediction then
			objectPos = Math:Get2D(object:GetPrediction(speed, delay) or object.pos)
			pointLine, isOnSegment = Math:ClosestPointOnLineSegment(objectPos, source, castPos)
			if isOnSegment and Math:IsInRange(objectPos, pointLine, radius + padding + (object.boundingRadius or 45)) then
				isCol = true
			end
		end
		if isCol then
			table_insert(collisionObjects, object)
			collisionCount = collisionCount + 1
		end
	end
	end
	return isWall, collisionObjects, collisionCount
end
Prediction = {}

function Prediction:GetPrediction(target, source, speed, delay, radius, isHero)
	if not target or not target.pos or not source or not speed or speed<=0 then return nil,nil,-1 end
	local id, ms = target.networkID, target.ms or 0
	if not target.pathing or ms<=0 then
		local pos=Math:Get2D(target.pos);return pos,pos,delay+Menu:GetLatency()/2+Menu:GetExtraDelay()+Math:GetDistance(pos,source)/speed
	end
	if target.pathing.isDashing and target.pathing.dashSpeed and target.pathing.dashSpeed > 0 then
		ms = target.pathing.dashSpeed
	end
	local delay2 = delay + Menu:GetLatency() / 2 + Menu:GetExtraDelay()
	if not isHero then
		local hasMovePath = target.pathing.hasMovePath
		if not hasMovePath then
			local pos = Math:Get2D(target.pos)
			return pos, pos, delay2 + Math:GetDistance(pos, source) / speed
		end
		local path = Path:GetPath(target)
		if #path <= 1 then
			local pos = Math:Get2D(target.pos)
			return pos, pos, delay2 + Math:GetDistance(pos, source) / speed
		end
		local path2 = Path:CutPath(path, ms * delay2)
		if speed == math_huge then
			return path2[1], path2[1], delay2
		end
		local path3 = Path:GetPredictedPath(source, speed, ms, path2)
		if path3 then
			local pos = path3[#path3]
			return pos, pos, delay2 + Math:GetDistance(pos, source) / speed
		end
		local pos = path[#path]
		return pos, pos, delay2 + Math:GetDistance(pos, source) / speed
	end
	UnitData:OnPrediction(target)
	-- Fresh visible hard CC is actionable immediately, even during the
	-- visibility-history warmup. Forced movement (fear/charm/taunt/knockback)
	-- must not masquerade as a stationary, guaranteed hit.
	local currentLock
	if target.visible then
		local pos=Math:Get2D(target.pos)
		local impact=delay2+Math:GetDistance(pos,source)/speed
		local canHit,locked,_,knock=Immobile:CanHit(target,impact,radius)
		currentLock=locked
		if canHit and knock==0 then return pos,pos,impact end
	end
	local vis = UnitData.Visible[id]
	if vis.visible then
		if GetTickCount() < vis.visibleTick + 100 then
			return nil, nil, -1
		end
	elseif GetTickCount() > vis.invisibleTick + 1000 then
		return nil, nil, -1
	end
	local wp = UnitData.Waypoints[id]
	if not wp then return nil,nil,-1 end
	if wp.moving then
		if currentLock==nil then
			local _,locked=Immobile:CanHit(target,delay2+Math:GetDistance(target.pos,source)/speed,radius)
			currentLock=locked
		end
		if currentLock then return nil,nil,-1 end -- Lock ends before arrival; do not invent post-CC direction.
	end
	if wp.moving and #wp.path <= 1 then
		return nil, nil, -1
	end
	if not wp.moving then
		local pos = Math:Get2D(target.pos)
		return pos, pos, delay2 + Math:GetDistance(pos, source) / speed
	end
	if speed == math_huge then
		local path = Path:CutPath(wp.path, ms * delay2)
		if wp.dashing then
			return path[1], path[1], delay2
		end
		local path2 = Path:CutPath(wp.path, (ms * delay2) - radius / 2)
		return path[1], path2[1], delay2
	end
	local path, time = Path:GetPredictedPath(source, speed, ms, Path:CutPath(wp.path, ms * delay2))
	if path then
		if wp.dashing then
			local unitPos = path[#path]
			return unitPos, unitPos, delay2 + Math:GetDistance(unitPos, source) / speed
		end
		local path2 = Path:CutPath2(Path:ReversePath(path), radius / 2, target.pos)
		return path[#path], path2[1], delay2 + Math:GetDistance(path2[1], source) / speed
	end
	local p = wp.path[#wp.path]
	return p, p, delay2 + Math:GetDistance(p, source) / speed
end
local SpellMethods = {}
function SpellMethods:ResetOutput()
		self.HitChance = 0
		self.LastFailureReason = nil
		self.CastPosition = nil
		self.UnitPosition = nil
		self.TimeToHit = 0
		self.CollionableObjects = {}
	end
function SpellMethods:GetOutput()
		self.TargetIsHero = self.Target.type == Obj_AI_Hero
		self.RealRadius = self.UseBoundingRadius and self.Radius + self.Target.boundingRadius or self.Radius
		self.UnitPosition, self.CastPosition, self.TimeToHit = Prediction:GetPrediction(
			self.Target,
			self.Source,
			self.Speed,
			self.Delay,
			self.RealRadius,
			self.TargetIsHero
		)
	end
function SpellMethods:HighHitChance()
		local wp, tick = UnitData.Waypoints[self.Target.networkID], GetTickCount()
		if not self.Target.visible then
			return false
		end
		if not wp then return false end
		if wp.moving then
			if tick < wp.tick + 150 then
				return true
			end
			if tick > wp.tick + 1000 and Path:GetLenght(wp.path) > 1000 then
				return true
			end
			return false
		end
		if tick - wp.stoptick < 50 then
			return true
		end
		if tick - wp.stoptick > 1000 then
			return true
		end
		return false
	end
function SpellMethods:IsCollision()
		local isWall, collisionObjects, collisionCount = Collision:GetCollision(
			self.Source,
			self.CastPosition,
			self.Speed,
			self.Delay,
			self.Radius,
			self.CollisionTypes,
			self.Target.networkID
		)

		if isWall or collisionCount > self.MaxCollision then
			self.CollionableObjects = collisionObjects
			return true
		end
		return false	
	end
function SpellMethods:IsInRange()
		local range = self.Range * Menu:GetMaxRange()
		local unitRange = range
		if self.Type == SPELLTYPE_CIRCLE then
			unitRange = unitRange + self.RealRadius
		end
		if not Math:IsInRange(self.UnitPosition, self.Source, unitRange) then
			return false
		end
		local castDirection = Math:Normalized(self.UnitPosition, self.Source)
		if not Math:IsInRange(self.CastPosition, self.Source, range) then
			self.CastPosition = Math:Extended(self.Source, castDirection, range)
		end
		local y = self.Target.pos.y
		y = y > 100 and 100 or y
		self.CastPosition.y = y
		self.UnitPosition.y = y
		local castPos3D = Math:Get3D(self.CastPosition)
		self.IsOnScreen = castPos3D:To2D().onScreen
		if not self.IsOnScreen then
			if self.Type == SPELLTYPE_CIRCLE then
				return false
			end
			local sourcePos3D = Vector(self.Source.x, self.SourceY, self.Source.z)
			self.CastPosition = sourcePos3D:Extended(castPos3D, math_min(800,range,Math:GetDistance(self.Source,self.CastPosition)))
		end
		return true
	end
function SpellMethods:CanHit(hitChance)
		hitChance = hitChance or HITCHANCE_NORMAL
		self.LastFailureReason = nil
		if self.UnitPosition == nil or self.CastPosition == nil then
			self.HitChance = 0
			self.LastFailureReason = 'prediction_unavailable'
			return false
		end
		--[[if self.Type ~= SPELLTYPE_CIRCLE and self.TimeToHit > 0.7 and Math:FindAngle(self.CastPosition, self.Target.pos, myHero.pos) > 90 - self.TimeToHit * 30 then
			return false
		end]]
		self.HitChance = HITCHANCE_NORMAL
		if self.TargetIsHero then
			local canHitLocked, isLocked, duration, knockduration =
				Immobile:CanHit(self.Target, self.TimeToHit, self.RealRadius)
			if knockduration ~= 0 then
				self.HitChance = 0
				self.LastFailureReason = 'knockback_active'
				return false
			end
			if canHitLocked then
				self.HitChance = duration > 0 and HITCHANCE_IMMOBILE or HITCHANCE_HIGH
			end
			if not isLocked and self.HitChance == HITCHANCE_NORMAL and self:HighHitChance() then
				self.HitChance = HITCHANCE_HIGH
			end			
		end
		if self.HitChance < hitChance then
			self.LastFailureReason = 'hitchance_below_threshold'
			return false
		end
		if self.Range ~= math_huge and not self:IsInRange() then
			self.LastFailureReason = 'prediction_out_of_range'
			return false
		end

		if self.Collision and self:IsCollision() then
			self.LastFailureReason = 'collision'
			return false
		end
		if not Math:VectorsEqual(self.PosTo, Math:Get2D(self.Target.posTo or self.Target.pos), 50) then
			self.LastFailureReason = 'path_changed'
			return false
		end

		-- The old 5ms CPU-time deadline rejected freshly calculated results
		-- during host stalls. Bound age by a quarter-radius of movement, capped
		-- at 50ms; never let a slow frame authorize an old cached prediction.
		local maxAge=math_min(.05,math_max(.005,(self.RealRadius or self.Radius or 0)*.25/math_max(1,self.Target.ms or 0)))
		if os.clock() - self.StartTime > maxAge then
			self.LastFailureReason = 'prediction_expired'
			return false
		end
		return true
	end
function SpellMethods:GetPrediction(target, source)
		self:ResetOutput()
		if not target or not target.pos then return end
		self.Target = target
		source=source or myHero
		local sourcePos = source.pos == nil and source or source.pos
		self.Source = Math:Get2D(sourcePos)
		self.SourceY = sourcePos.y or myHero.pos.y
		self.PosTo = Math:Get2D(target.posTo or target.pos)
		self.StartTime = os.clock()
		self:GetOutput()
	end
function SpellMethods:GetAOEPrediction(source)
		local aoetargets = {}
		local enemies = ObjectManager:GetEnemyHeroes()
		for i = 1, #enemies do
			local enemy = enemies[i]
			if not SDK.ObjectManager:IsHeroImmortal(enemy) then
				self:GetPrediction(enemy, source)
				if self:CanHit(HITCHANCE_NORMAL) then
					table_insert(
						aoetargets,
						{ enemy, self.HitChance, self.TimeToHit, self.CastPosition, self.UnitPosition }
					)
				end
			end
		end
		local result = {}
		local isCircle = self.Type == SPELLTYPE_CIRCLE
		local range = self.Range * Menu:GetMaxRange()
		for i = 1, #aoetargets do
			local aoetarget = aoetargets[i]
			local count = 1
			local distance = 0
			local castpos = aoetarget[4]
			if isCircle then
				local anchor = aoetarget[5]
				local cluster = { anchor }
				for j = 1, #aoetargets do
					if i ~= j and Math:GetDistance(anchor, aoetargets[j][5]) < self.RealRadius * 2 then
						table_insert(cluster, aoetargets[j][5])
					end
				end
				while #cluster > 1 do
					local center, r = Math:MEC(cluster)
					if r <= self.RealRadius - 10 and (range == math_huge or Math:IsInRange(center, self.Source, range)) then
						castpos = center
						break
					end
					local far, fi = -1, 2
					for k = 2, #cluster do
						local dd = Math:GetDistance(cluster[k], anchor)
						if dd > far then
							far, fi = dd, k
						end
					end
					table_remove(cluster, fi)
				end
			elseif self.Type == SPELLTYPE_LINE and range ~= math_huge then
				local anchor = aoetarget[5]
				local gate = self.Radius + aoetarget[1].boundingRadius / 3
				local bestCount, bestPos = 1, nil
				for j = 1, #aoetargets do
					if i ~= j then
						local other = aoetargets[j][5]
						local mid = { x = (anchor.x + other.x) / 2, z = (anchor.z + other.z) / 2 }
						local dir = Math:Normalized(mid, self.Source)
						if dir then
							local endpos = Math:Extended(self.Source, dir, range)
							local pa, aOn = Math:ClosestPointOnLineSegment(anchor, self.Source, endpos)
							if aOn and Math:IsInRange(anchor, pa, gate) then
								local cnt, farthest = 0, 0
								for k = 1, #aoetargets do
									local unitpos = aoetargets[k][5]
									local pl, isOn = Math:ClosestPointOnLineSegment(unitpos, self.Source, endpos)
									if isOn and Math:IsInRange(unitpos, pl, self.RealRadius) then
										cnt = cnt + 1
										local dp = Math:GetDistance(self.Source, pl)
										if dp > farthest then
											farthest = dp
										end
									end
								end
								if cnt > bestCount then
									bestCount = cnt
									bestPos = Math:Extended(self.Source, dir, farthest)
								end
							end
						end
					end
				end
				if bestPos then
					castpos = bestPos
				end
			end
			if castpos ~= aoetarget[4] then
				castpos.y = aoetarget[4].y
			end
			for j = 1, #aoetargets do
				if i ~= j then
					local d
					local unitpos = aoetargets[j][5]
					if isCircle then
						d = Math:GetDistance(castpos, unitpos)
					else
						local pointLine, isOnSegment = Math:ClosestPointOnLineSegment(unitpos, self.Source, castpos)
						d = Math:GetDistance(pointLine, unitpos)
					end
					if d < self.RealRadius then
						count = count + 1
						distance = distance + d
					end
				end
			end
			table_insert(result, {
				Count = count,
				Distance = distance,
				Unit = aoetarget[1],
				HitChance = aoetarget[2],
				TimeToHit = aoetarget[3],
				CastPosition = castpos,
			})
		end
		return result
	end
function Prediction:SpellPrediction(args)
	local c = {}
	do -- __init()
		c.Collision, c.MaxCollision, c.CollisionTypes = false, 0, { 0, 3 }
		if args.Collision ~= nil then
			c.Collision = args.Collision
		end
		if args.MaxCollision ~= nil then
			c.MaxCollision = args.MaxCollision
		end
		if args.CollisionTypes ~= nil then
			c.CollisionTypes = args.CollisionTypes
		end
		c.Type, c.Speed, c.Range, c.Delay, c.Radius, c.UseBoundingRadius =
			SPELLTYPE_LINE, math_huge, math_huge, 0, 1, false
		if args.Type ~= nil then
			c.Type = args.Type
		end
		if args.Speed ~= nil then
			c.Speed = args.Speed
		end
		if args.Range ~= nil then
			c.Range = args.Range
		end
		if args.Delay ~= nil then
			c.Delay = args.Delay
		end
		if args.Radius ~= nil then
			c.Radius = args.Radius
		end
		if args.UseBoundingRadius or (args.UseBoundingRadius == nil and c.Type == SPELLTYPE_LINE) then
			c.UseBoundingRadius = true
		end
	end
	for name,method in pairs(SpellMethods) do c[name]=method end
	return c
end
--[[
	GGPrediction - Global Class, API
]]
_G.GGPrediction = {
	CollisionOptions = true,
	COLLISION_MINION = COLLISION_MINION,
	COLLISION_ALLYHERO = COLLISION_ALLYHERO,
	COLLISION_ENEMYHERO = COLLISION_ENEMYHERO,
	COLLISION_YASUOWALL = COLLISION_YASUOWALL,
	HITCHANCE_IMPOSSIBLE = HITCHANCE_IMPOSSIBLE,
	HITCHANCE_COLLISION = HITCHANCE_COLLISION,
	HITCHANCE_NORMAL = HITCHANCE_NORMAL,
	HITCHANCE_HIGH = HITCHANCE_HIGH,
	HITCHANCE_IMMOBILE = HITCHANCE_IMMOBILE,
	SPELLTYPE_LINE = SPELLTYPE_LINE,
	SPELLTYPE_CIRCLE = SPELLTYPE_CIRCLE,
	SPELLTYPE_CONE = SPELLTYPE_CONE,
}
function GGPrediction:GetPrediction(target, source, speed, delay, radius)
	if not target or not target.pos then return nil,nil,-1 end
	source=source or myHero
	return Prediction:GetPrediction(target, Math:Get2D(source), speed, delay, radius, target.type == Obj_AI_Hero)
end
function GGPrediction:GetCollision(source, castPos, speed, delay, radius, collisionTypes, skipID, options)
	return Collision:GetCollision(source, castPos, speed, delay, radius, collisionTypes, skipID, options)
end
function GGPrediction:SpellPrediction(args)
	return Prediction:SpellPrediction(args)
end
function GGPrediction:ClosestPointOnLineSegment(p, p1, p2)
	return Math:ClosestPointOnLineSegment(p, p1, p2)
end
function GGPrediction:IsInRange(p1, p2, range)
	return Math:IsInRange(p1, p2, range)
end
function GGPrediction:GetImmobileDuration(unit)
	return Immobile:GetDuration(unit)
end
function GGPrediction:FindAngle(p1, center, p2)
	return Math:FindAngle(p1, center, p2)
end
function GGPrediction:GetDistance(p1, p2)
	return Math:GetDistance(p1, p2)
end
function GGPrediction:CircleCircleIntersection(center1, center2, radius1, radius2)
	return Math:CircleCircleIntersection(center1, center2, radius1, radius2)
end

GGPrediction.Version=Version
GGPrediction.BaseVersion='GGPrediction 1.59'
_G.OrbamaPrediction=GGPrediction
return GGPrediction

end)()
end
-- Generated by tools/build_twisted_fate.py; edit modular sources.
if not myHero or (myHero.charName~="TwistedFate" and myHero.charName~="Jade_TwistedFate") then return end
if not (_G.SDK and SDK.OrbamaVersion) then print("[CardMarx] Load Orbama first; reload the complete runtime."); return end
if not SDK.Actions or not SDK.Actions.GetCapabilities or not SDK.Actions:GetCapabilities().createClient
 or not SDK.SharedData or not SDK.OnUrgent or not SDK.Attack or not SDK.Damage or not SDK.Damage.GetTwistedFateAttack then
 print("[CardMarx] Required Orbama capabilities unavailable."); return end
local fingerprint="6517c16577d5e509ffafb136b3946ee714848dca13c139a3f4a9be8de0873b27"
local previous=_G.OrbamaTwistedFate
if previous then
 if previous.active and previous.fingerprint==fingerprint then return previous end
 print("[CardMarx] Another TF instance exists; reload the complete runtime."); return previous
end
pcall(require,"GGPrediction")
local modules,cache={},{}
local externalRequire=require
modules["tf.actions"] = function(require)
local U=require('tf.util')
local A={};A.__index=A
function A.new(c)
    local self=setmetatable({c=c,pending={},uncertain={}},A)
    c.actions=self -- retain ownership if a later constructor step fails
    self.client=c.sdk.Actions:CreateClient({name='TwistedFate',active=function()return c.active and c.config:get('enabled')end})
    if self.client.CooperateWithEvade then
        self.client:CooperateWithEvade({committed=function()return c.state:channel()==true end,
            yield=function(evidence)
                if not evidence.likelyDeath then return false end
                self.client:YieldUnsent();c.cards:clear()
                self.client:SetBlocked('gate','attack',false);self.client:SetBlocked('gate','move',false)
                return true
            end})
        self.client:RegisterEmergencyYield(function(resource)return self.client:YieldUnsent(resource)end)
    end
    self.client:Condition('channel','manual_channel',function(q)
        local active,kind=c.state:channel()
        return not active or kind=='gate' and q.tfLock==true and c.profile.channelW2==true
    end)
    return self
end
function A:submit(slot,q,observe)
    local c=self.c;local client=self.client
    if self.uncertain[slot] then return nil,'awaiting_fresh_state' end
    q.resource='slot:'..slot;q.owner=q.owner or 'combat';q.priority=q.priority or 'normal'
    q.expires=q.expires or client:Now()+220
    q.keys=q.keys or {({[0]=HK_Q,[1]=HK_W,[2]=HK_E,[3]=HK_R,[4]=HK_SUMMONER_1,[5]=HK_SUMMONER_2})[slot]}
    q.kind=q.kind or 'none';q.type=q.type or 'cast'
    q.equivalence=q.equivalence or (q.owner..':'..slot..':'..tostring(q.targetID or '')..':'..tostring(q.tfStage or ''))
    local before=c.hero:GetSpellData(slot);local beforeName=before.name;local beforeRank=before.level
    local beforeCD=before.currentCd or 0;local serial=c.state.serial
    q.reconcile=function(record)
        local d=c.hero:GetSpellData(slot)
        if not d or not d.name then return false end
        -- Reconciliation releases the old resource, never declares the cast successful.
        self.uncertain[slot]={name=d.name,rank=d.level,cd=d.currentCd or 0,stage=c.state.stage,color=c.state.color,
            id=record and record.id,freshReadyReplan=slot==0 and q.freshReadyReplan==true}
        c:record('resource_reconciled',{slot=slot,id=record and record.id,reason='historical_send_unresolved',
            name=d.name,rank=d.level,cooldown=d.currentCd,ready=Game.CanUseSpell(slot)})
        return true
    end
    local id,why=client:Submit(q)
    if id and not self.pending[id]then
        self.pending[id]={slot=slot,name=beforeName,rank=beforeRank,cd=beforeCD,serial=serial,observe=observe,owner=q.owner}
        c:record('requested',{id=id,slot=slot,owner=q.owner,mode=c.state.mode,target=q.targetID,stage=q.tfStage,lock=q.tfLock,
            desired=c.cards and c.cards.desired,observed=c.state.color})
    end
    return id,why
end
function A:busy(slot)
    if self.uncertain[slot]then return true,'awaiting_fresh_state' end
    for id,p in pairs(self.pending)do if p.slot==slot and self.client.jobs[id]then return true,'pending' end end
    return false
end
function A:tick()
    local c=self.c;local client=self.client;client:Tick()
    for slot,b in pairs(self.uncertain)do
        local d=c.hero:GetSpellData(slot)
        if d and (d.name~=b.name or d.level~=b.rank or (d.currentCd or 0)>b.cd+.05
            or slot==1 and (c.state.stage~=b.stage or c.state.color~=b.color))then
            self.uncertain[slot]=nil
        elseif b.freshReadyReplan and d and d.level>0 and (d.currentCd or 0)<=0
            and U.lower(d.name)==U.lower(c.profile.qName) and c.state:ready(slot) and not c.state:channel()
            and (not b.id or not client.jobs[b.id]) and client:Available() then
            -- The client already waited for transport cleanup and reconciled
            -- the historical send. Two fresh ready observations may reopen Q
            -- for a NEW plan; this neither confirms nor replays that old cast.
            local at=Game.Timer();local active=c.hero.activeSpell
            if active and active.valid and U.lower(active.name)==U.lower(c.profile.qName) then b.readyAt=nil
            elseif b.readyAt and at>b.readyAt then
                self.uncertain[slot]=nil
                c:record('resource_reopened',{slot=slot,id=b.id,reason='fresh_ready_observed',historicalExecution='unknown'})
            else b.readyAt=at end
        else b.readyAt=nil
        end
    end
    for id,p in pairs(self.pending)do
        local r=client:Poll(id)
        if r then
            if c.config:get('diagnostics') and (p.loggedState~=r.state or p.loggedSent~=r.sentAt)then
                p.loggedState=r.state;p.loggedSent=r.sentAt
                c:record('action_state',{id=id,slot=p.slot,owner=p.owner,state=r.state,reason=r.reason,
                    requestedAt=r.requestedAt,sentAt=r.sentAt,releasedAt=r.releasedAt,cleanupPending=r.cleanupPending,
                    interrupted=r.interrupted,competitor=r.competitor})
            end
            if r.sentAt and not r.mechanical then
                local d=c.hero:GetSpellData(p.slot)
                -- A cooldown transition is a resource observation; a timer is not.
                local seen=p.observe and p.observe(p) or not p.observe and d and
                    (d.level~=p.rank or (d.currentCd or 0)>p.cd+.05)
                if seen then
                    local evidence={kind='mechanical',unique=true,at=client:Now(),source='fresh_tf_state'}
                    local receipt=r.commandReceipt
                    if client:Capabilities().keyedMechanicalObservation and receipt then
                        evidence.attribution='command_key';evidence.key=receipt.key
                        evidence.generation=receipt.generation;evidence.session=receipt.session
                    end
                    local accepted,why=client:Observe(id,evidence)
                    if p.observationReason~=tostring(accepted)..':'..tostring(why)then
                        p.observationReason=tostring(accepted)..':'..tostring(why)
                        c:record('action_observation',{id=id,accepted=accepted,reason=why,attribution=evidence.attribution})
                    end
                    r=client:Poll(id) or r
                end
            end
            client:Reconcile(id)
            if not r.sentAt and r.state=='cancelled_before_send' then client:Finish(id)end
        end
        if not client.jobs[id]then self.pending[id]=nil;c:record('completed',{id=id,state=r and r.state,
            mechanical=r and r.mechanical~=nil and r.mechanical~=false or false,reason=r and r.reason,sentAt=r and r.sentAt})end
    end
end
function A:cancel(owner,reason)
    self.client:CancelOwner(owner,reason)
    -- Explicit new player intent may reopen a reconciled resource, with fresh validation.
    if owner=='cards' then self.uncertain[1]=nil end
end
function A:close()
    self.client:Close('tf_shutdown');self:tick();self.client:Collect()
end
return A

end
modules["tf.app"] = function(require)
local P=require('CombatProfiles.twisted_fate')
local U=require('tf.util')
local App={};App.__index=App
App.build='CardMarx-10'
function App.new()
    return setmetatable({hero=myHero,sdk=SDK,active=true,build=App.build},App)
end
function App:initialize()
    local c=self
    c.profile=assert(P.Profile(myHero.charName));c.config=require('tf.config').new(c.profile)
    c.state=require('tf.state').new(c)
    c.actions=require('tf.actions').new(c);c.cards=require('tf.cards').new(c)
    c.q=require('tf.q').new(c);c.combat=require('tf.combat').new(c)
    c.effects=require('tf.effects').new(c);c.farm=require('tf.farm').new(c);c.level=require('tf.level').new(c)
    c.state:refresh();return c
end
function App:record()end
function App:blocked()
    return not self.config:get('enabled') or self.hero.dead or Game.IsChatOpen() or not Game.IsOnTop()
end
function App:tick()
    if not self.active then return end
    self.state:refresh();self.actions:tick();self.combat:pollAttack();self.plan=nil
    if self:blocked()then
        self.cards:clear()
        for _,owner in ipairs({'combat_attack','farm_attack','interrupt','peel','q','level','item','summoner','classic_r','planned_active'})do self.actions:cancel(owner,'context_unavailable')end
        self.actions.client:SetBlocked('gate','attack',false);self.actions.client:SetBlocked('gate','move',false)
        self.effects:claimsUpdate();return
    end
    if self.sdk.Evade and type(self.sdk.Evade.Evading)=='function'and self.sdk.Evade:Evading()then
        self.actions.client:SetBlocked('gate','attack',false);self.actions.client:SetBlocked('gate','move',false);return
    end
    local s=self.state
    self.actions.client:SetBlocked('gate','attack',s.channeling)
    self.actions.client:SetBlocked('gate','move',s.channeling)
    if self.wasGate and not s.channeling then
        self.level.teleports=self.level.teleports or {};table.insert(self.level.teleports,Game.Timer())
        if #self.level.teleports>16 then table.remove(self.level.teleports,1)end
        if self.config:get('teleportCards') and not self.cards.manual then self.cards:auto('gold','arrival')end
    end
    self.wasGate=s.channelKind=='gate'
    if self.wasGate and self.config:get('teleportCards') and s.stage=='selecting' and not self.cards.manual then
        self.cards:auto('gold','manual_gate')
    end
    self.cards:tick()
    if s.channeling then return end
    self.effects:tick()
    if s.mode=='FLEE'then self.combat:classicR()end
    local urgent=self.combat:interrupt() or self.combat:peel()
    if not urgent then
        if s.mode=='COMBO' or s.mode=='HARASS'then self.combat:tick(s.mode,s.modeID)
        elseif s.mode=='LASTHIT' or s.mode=='LANECLEAR' or s.mode=='JUNGLECLEAR'then
            local mode,id=s.mode,s.modeID
            if self.sdk.Orbwalker.Modes[self.sdk.ORBWALKER_MODE_LANECLEAR] and self.sdk.Orbwalker.Modes[self.sdk.ORBWALKER_MODE_JUNGLECLEAR] then
                local nearest,distance=nil,math.huge
                for _,m in ipairs(s.minions)do if U.target(m) and m.team~=self.hero.team then
                    local d=U.dist(self.hero,m);if d<distance then nearest=m;distance=d end
                end end
                if nearest and nearest.team==300 then mode='JUNGLECLEAR';id=self.sdk.ORBWALKER_MODE_JUNGLECLEAR end
            end
            self.farm:tick(mode,id)
            if s.mode=='LANECLEAR' and self.config:get('farmHarass')then self.combat:tick('HARASS',s.modeID)end
        elseif s.mode=='FLEE'then self.combat:flee()
        elseif self.config:get('autoHarass') and s.mode=='NONE'then self.combat:tick('HARASS',nil)end
    end
    self.level:tick()
end
function App:draw()
    if not self.active or not self.config:get('draw')then return end
    local p=self.hero.pos:To2D();local color=self.cards.manual and self.cards.manual.color or self.cards.desired
    Draw.Text('Card Marx '..self.profile.id..' | '..self.cards.phase..(color and ' / '..color or ''),16,p.x-80,p.y+50,Draw.Color(255,240,210,80))
    if self.plan and U.target(self.plan.target)then Draw.Circle(self.plan.target.pos,90,2,Draw.Color(220,240,210,80))end
end
function App:install()
    self.tickFn=function()
        local ok,err=pcall(function()
            if self.sdk.Performance and self.sdk.Performance.enabled then
                return self.sdk.Performance:Call('tf_controller',function()self:tick()end)
            end
            return self:tick()
        end)
        if not ok then print('[CardMarx] stopped: '..tostring(err));self:Shutdown()end
    end
    self.drawFn=function()self:draw()end
    table.insert(self.sdk.OnUrgent,self.tickFn);table.insert(self.sdk.OnDraw,self.drawFn)
end
function App:Shutdown()
    if not self.active then return end
    self.active=false;U.remove(self.sdk.OnUrgent,self.tickFn);U.remove(self.sdk.OnDraw,self.drawFn)
    if self.actions and self.actions.client then self.actions:close()end
    if self.actions and self.actions.client and next(self.actions.client.jobs) and self.sdk.OnMaintenance then
        local cleanup
        cleanup=function()
            self.actions.client:Collect()
            if not next(self.actions.client.jobs)then U.remove(self.sdk.OnMaintenance,cleanup)end
        end
        table.insert(self.sdk.OnMaintenance,cleanup)
    end
    if _G.OrbamaTwistedFate==self then _G.OrbamaTwistedFate=nil end
end
return App

end
modules["tf.cards"] = function(require)
local U=require('tf.util')
local P=require('CombatProfiles.twisted_fate')
local C={};C.__index=C
function C.new(c)return setmetatable({c=c,keys={},phase='idle',cycle={},manual=nil},C)end
function C:request(color,manual,reason)
    local c=self.c
    if self.manual and not manual then return self.manual.color==color end
    if manual then
        c.actions:cancel('cards','manual_card_changed')
        self.manual={color=color,requestedAt=Game.Timer()}
        c:record('manual_card_requested',{color=color,reason=reason})
    end
    self.desired=color;self.reason=reason;return true
end
function C:waitFor(color)
    local s=self.c.state
    if s.stage=='held' then return s.color==color and 0 or math.huge end
    if s.stage=='selecting' and s.color==color then return 0 end
    -- Scheduling estimate only, never evidence of a lock or a color transition.
    return self.cycle[color] or (s.stage=='selecting' and .8 or 1.2)
end
function C:intentActive(color)
    if self.desired~=color then return false end
    if self.manual then return true end
    return self.autoUntil~=nil and Game.Timer()<self.autoUntil
        and (not self.autoMode or self.c.sdk.Orbwalker.Modes[self.autoMode])
        and (not self.autoCondition or self.autoCondition())
end
function C:tick()
    local c=self.c;local s=c.state;local now=Game.Timer()
    for _,color in ipairs(P.colors)do
        local down=c.config:get(color)==true
        if down and not self.keys[color]then self:request(color,true,'manual')end
        self.keys[color]=down
    end
    if self.lastColor and s.stage=='selecting' and s.color~=self.lastColor then
        local elapsed=now-(self.lastColorAt or now)
        if elapsed>.1 and elapsed<2 then
            -- Used only for estimates; direct spell-name observation selects the lock.
            for _,color in ipairs(P.colors)do self.cycle[color]=math.min(1.5,elapsed*2)end
        end
        self.lastColorAt=now
    elseif s.stage=='selecting' and not self.lastColor then self.lastColorAt=now end
    self.lastColor=s.stage=='selecting' and s.color or nil
    if self.manual then
        if s.stage=='held' and s.color==self.manual.color then self.manual.observed=true end
        if self.manual.observed and s.stage~='held' then
            if c.config:get(self.manual.color)==true then self.manual.observed=nil
            else self.manual=nil;self.desired=nil end
        end
    end
    if self.manual then self.desired=self.manual.color end
    -- A colour tap alone only reserves a card. An explicitly held attack/farm
    -- mode authorizes using it; rolling cards never block ordinary attacks.
    local usingCard=s.mode=='COMBO' or s.mode=='HARASS' or s.mode=='LASTHIT'
        or s.mode=='LANECLEAR' or s.mode=='JUNGLECLEAR'
    c.actions.client:SetBlocked('manual_card','attack',self.manual~=nil and s.stage=='held'
        and not usingCard)
    self.phase=s.cardFlight and 'projectile_observed' or s.cardAttack and now<=s.cardAttack.castEnd and 'attack_observed' or s.stage
    if not self.desired or s.stage=='held' or s.stage=='unknown' then return end
    if not self:intentActive(self.desired)then return end
    if s.channeling then
        -- No W1 during a manual channel. W2 exception needs profile live evidence.
        if not(s.stage=='selecting' and c.profile.channelW2 and s.channelKind=='gate')then return end
    end
    local color=self.desired
    local isLock=s.stage=='selecting'
    if isLock and s.color~=color then return end
    if s:windupActive()then
        if self.waitReason~='attack_windup' then c:record('card_wait',{reason='attack_windup',color=color,stage=s.stage})end
        self.waitReason='attack_windup';return
    end -- locking must never cancel a current windup
    if not s:ready(1,isLock)then
        if self.waitReason~='spell_not_ready' then c:record('card_wait',{reason='spell_not_ready',color=color,stage=s.stage})end
        self.waitReason='spell_not_ready';return
    end
    self.waitReason=nil
    local expected=isLock and c.profile.locks[color] or c.profile.wName
    local id,why=c.actions:submit(1,{owner='cards',priority=self.manual and 'interactive' or 'normal',independent=true,
        tfStage=expected,tfLock=isLock,expires=c.actions.client:Now()+120,
        context={condition=function()return self:intentActive(color)end},
        mechanical=function()
            local d=c.hero:GetSpellData(1)
            local channel,kind=s:channel()
            if self.desired~=color then return false,'card_intent_changed' end
            if U.lower(d.name)~=U.lower(expected)then return false,'card_color_changed' end
            if not s:ready(1,isLock)then return false,'card_not_ready'end
            if s:windupActive()then return false,'attack_windup'end
            if channel and not(isLock and kind=='gate' and c.profile.channelW2)then return false,'manual_channel'end
            return true
        end},function(p)
            local e=s.cardEvent
            return e and e.serial>p.serial and (isLock and e.stage=='held' and e.color==color or not isLock and e.stage=='selecting')
        end)
    if id then
        self.phase=isLock and 'lock_requested' or 'selection_requested'
        self.lastReject=nil
    elseif self.lastReject~=why then
        self.lastReject=why;c:record('card_wait',{reason=why,color=color,stage=s.stage,w=expected})
    end
end
function C:auto(color,reason,condition)
    if self.manual then return false end
    self.autoMode=(reason=='combat' or reason=='clear' or reason=='save_cs') and self.c.state.modeID or nil
    self.autoCondition=condition
    self.autoUntil=Game.Timer()+.25;return self:request(color,false,reason)
end
function C:clear()
    self.desired=nil;self.manual=nil;self.autoUntil=nil;self.phase='idle';self.c.actions:cancel('cards','context_unavailable')
    self.c.actions.client:SetBlocked('manual_card','attack',false)
end
return C

end
modules["tf.combat"] = function(require)
local U=require('tf.util')
local P=require('CombatProfiles.twisted_fate')
local Planner=require('tf.planner')
local C={};C.__index=C
function C.new(c)return setmetatable({c=c},C)end
function C:packet(target,color,eReady,index,hp)
    local c=self.c;local sdk=c.sdk;local crit=P.CritMultiplier(c.profile,c.state.inventory.slots)
    local raw=P.Attack(c.profile,c.hero,c.state.spells[1].level,c.state.spells[2].level,color,eReady,target.type==Obj_AI_Turret,crit)
    local charge=c.state:buff(c.hero,'itemstatikshankcharge')
    local extra=P.ItemAttack(c.profile,c.hero,{health=hp or target.health,minion=target.type==Obj_AI_Minion,hero=target.type==Obj_AI_Hero},
        c.state.inventory.slots,{energized=(index or 0)==0 and P.AliveBuff(charge,Game.Timer()) and charge.stacks==100})
    if target.type==Obj_AI_Hero or target.type==Obj_AI_Minion then raw.physical=raw.physical+extra.physical;raw.magical=raw.magical+extra.magical end
    local chance=c.hero.critChance or 0
    local expected=not color and chance<1 and (c.hero.totalDamage or 0)*chance*(crit-1) or 0
    return {physical=sdk.Damage:CalculateDamage(c.hero,target,sdk.DAMAGE_TYPE_PHYSICAL,raw.physical,false,true),
        magical=sdk.Damage:CalculateDamage(c.hero,target,sdk.DAMAGE_TYPE_MAGICAL,raw.magical,false,true),trueDamage=0,
        expected=sdk.Damage:CalculateDamage(c.hero,target,sdk.DAMAGE_TYPE_PHYSICAL,expected,false,true)}
end
function C:qDamage(target)
    local c=self.c
    return c.sdk.Damage:CalculateDamage(c.hero,target,c.sdk.DAMAGE_TYPE_MAGICAL,
        P.Q(c.profile,c.state.spells[0].level,c.hero),true,false)
end
function C:target(range)
    local c=self.c
    return c.sdk.TargetSelector:GetTarget(range,c.sdk.DAMAGE_TYPE_MAGICAL)
end
function C:attack(target,mode,owner,check)
    local c=self.c;local id=U.id(target)
    if self.attackID and c.actions.client.jobs[self.attackID]then return false end
    if not c.sdk.Orbwalker:CanAttack()then return false,'attack_not_ready' end
    self.attackID=c.actions.client:Attack(target,{owner=owner or 'combat_attack',resource='attack',priority='normal',
        targetID=id,expires=c.actions.client:Now()+140,context=mode and {modes={mode}} or nil,
        mechanical=function()
            if U.id(target)~=id or not U.target(target)then return false,'attack_target_lost' end
            if c.state:channel()then return false,'manual_channel' end
            if U.dist(c.hero,target)>c.sdk.Data:GetAutoAttackRange(c.hero,target)then return false,'attack_out_of_range' end
            local protection=c.state:protection(target)
            if protection.dodge or protection.invulnerable then return false,'attack_protected' end
            if c.state.stage=='held' and protection.spellShield then return false,'card_spellshield' end
            if check and not check()then return false,'attack_plan_changed' end
            return true
        end,reconcile=function()return target~=nil and c.hero.attackData~=nil end})
    if self.attackID then
        self.attackAt=c.state.lastAttack;self.attackTarget=id;self.attackOwner=owner or 'combat_attack';self.attackLoggedState=nil
        c:record('attack_requested',{id=self.attackID,target=id,owner=self.attackOwner,mode=c.state.mode,health=target.health})
    end
    return self.attackID
end
function C:pollAttack()
    local id=self.attackID;if not id then return end
    local c=self.c;local client=c.actions.client;local r=client:Poll(id)
    if r and c.config:get('diagnostics') and (self.attackLoggedState~=r.state or self.attackLoggedSent~=r.sentAt)then
        self.attackLoggedState=r.state;self.attackLoggedSent=r.sentAt
        c:record('attack_state',{id=id,target=self.attackTarget,owner=self.attackOwner,state=r.state,reason=r.reason,
            sentAt=r.sentAt,requestedAt=r.requestedAt,releasedAt=r.releasedAt,cleanupPending=r.cleanupPending})
    end
    if r and r.sentAt and c.state.lastAttack>(self.attackAt or 0)then
        client:Observe(id,{kind='mechanical',unique=true,at=client:Now(),source='sdk_attack_start'})
    end
    client:Reconcile(id)
    if not client.jobs[id]then self.attackID=nil end
end
function C:model(target,mode)
    local c=self.c;local s=c.state;local h=c.hero;local protection=s:protection(target)
    if protection.invulnerable then return nil end
    local range=c.sdk.Data:GetAutoAttackRange(h,target);local dist=U.dist(h,target)
    local p={hp=target.health,shield=target.allShield,physicalShield=target.shieldAD,magicalShield=target.shieldAP,
        regen=target.hpRegen or 0,mana=h.mana,maxMana=h.maxMana,windup=c.sdk.Attack:GetWindup(),
        period=c.sdk.Attack:GetAnimation(),flight=dist/math.max(1,c.sdk.Attack:GetProjectileSpeed()),
        nextAA=math.max(0,(c.sdk.Attack.ServerStart or -10)+c.sdk.Attack:GetAnimation()-Game.Timer()),
        qCost=s:cost(0),wCost=s.stage=='selecting' and 0 or s:cost(1),reserveQ=s:reserve(0),reserveW=s:reserve(1),
        qCast=c.profile.q.delay,stun=protection.immune and 0 or math.max(0,P.Stun(s.spells[1].level)-protection.cc),
        blueMana=P.Rank(c.profile.wMana,s.spells[1].level),reset=c.profile.lockReset,
        card=s.stage=='held' and s.color or nil,e=s.eReady and 3 or 0,hasE=c.profile.eBase~=nil,
        -- Repeated reach uses base observed range, excluding SDK's one-use extension.
        repeatReachable=dist<=(h.range or 0)+(h.boundingRadius or 0)+(target.boundingRadius or 0)-40}
    p.controlValue=0
    if dist<=range and not protection.dodge and not(p.card and protection.spellShield) then
        local cache={};local healthDependent=false
        for _,item in pairs(s.inventory.slots)do
            local rule=P.itemRules[c.profile.id][item.itemID]
            if rule and rule.currentHealthPhysical then healthDependent=true end
        end
        p.attack=function(color,eReady,index,hp)
            local key=(color or 'none')..':'..tostring(eReady)..':'..tostring(index==0)
                ..(healthDependent and ':'..tostring(hp) or '')
            if not cache[key]then cache[key]=self:packet(target,color,eReady,index,hp)end
            return cache[key]
        end
        p.controlValue=(h.totalDamage or 0)/math.max(.1,p.period)*.25
        for _,ally in ipairs(s.heroes)do
            if ally.team==h.team and ally~=h and U.alive(ally) and U.dist(ally,target)<(ally.range or 125)+250 then
                -- Utility estimate only; not damage or a guaranteed kill.
                p.controlValue=p.controlValue+20
            end
        end
    end
    local busy,busyReason=c.actions:busy(0)
    p.qReason=not c.config:get(mode..'Q') and 'disabled' or not s:ready(0) and 'not_ready'
        or busy and busyReason or s:windupActive() and 'attack_windup'
        or protection.spellShield and 'spellshield' or h.mana<p.qCost+p.reserveQ and 'mana_reserve' or nil
    if not p.qReason then
        local q=c.q:plan(target,s.heroes)
        if q then p.q={magical=self:qDamage(target)};p.qImpact=q.impact end
        p.qReason=c.q.reason
    end
    if c.config:get(mode..'W') and not c.cards.manual and s:ready(1,s.stage=='selecting') and s.stage~='held' and dist<=range then
        p.cards={}
        for _,color in ipairs(P.colors)do
            if not protection.spellShield then p.cards[#p.cards+1]={color=color,wait=c.cards:waitFor(color)}end
        end
    end
    p.extras=(mode=='COMBO' or mode=='HARASS') and c.effects:candidates(target) or nil
    local flight=s.cardFlight
    if flight and flight.packet and (flight.target==target.networkID or flight.target==target.handle)
        and flight.missile.valid~=false and not protection.spellShield then
        p.incoming={{at=U.dist(flight.missile,target)/flight.speed,packet=flight.packet,
            control=flight.color=='gold' and not protection.immune and p.stun or 0}}
    end
    return p
end
function C:diagnostics(mode,target,p,plan)
    local c=self.c;if not c.config:get('diagnostics')then return end
    local now=Game.Timer();if now<(self.nextDiagnostic or 0)then return end
    self.nextDiagnostic=now+.5
    c:record('combat_decision',{mode=mode,target=U.id(target),reason=not target and 'no_target'
        or not p and 'target_protected' or p.qReason,first=plan and plan.first,usedQ=plan and plan.usedQ,
        qDamage=p and p.q and p.q.magical,qImpact=p and p.qImpact,qCost=p and p.qCost,
        reserveQ=p and p.reserveQ,nextAA=p and p.nextAA,period=p and p.period,
        predictionChance=c.q.predict and c.q.predict.HitChance,windup=c.state:windupActive(),
        distance=target and U.dist(c.hero,target),health=target and target.health,
        mana=c.hero.mana,ap=c.hero.ap,ad=c.hero.totalDamage,transitions=plan and plan.transitions})
end
function C:tick(mode,modeID)
    local c=self.c;local target=self:target(c.profile.q.range)
    if not U.target(target)then self:diagnostics(mode,nil);return end
    local p=self:model(target,mode);if not p then self:diagnostics(mode,target);return end
    local plan=Planner.solve(p);c.plan={target=target,first=plan.first,color=plan.color,damage=target.health-math.max(0,plan.hp),transitions=plan.transitions}
    self:diagnostics(mode,target,p,plan)
    if c.config:get('level')then c.level:sample(mode,p)end
    if plan.first=='card' then c.cards:auto(plan.color,'combat',function()
        return U.target(target) and U.dist(c.hero,target)<=c.sdk.Data:GetAutoAttackRange(c.hero,target)
            and c.config:get(mode..'W') and not c.state:protection(target).spellShield
    end)
    elseif plan.first=='q' then
        c.q:cast(target,modeID,function(t)
            -- Q's resolver already checked fresh prediction, target and blockers.
            -- Rebuilding the whole combat model here repeats that work while the
            -- provider owns the cursor, without changing this intent's target.
            return c.config:get(mode..'Q') and c.hero.mana>=c.state:cost(0)+c.state:reserve(0)
        end)
    elseif plan.first=='extra' and modeID then c.effects:execute(plan.extra,target,modeID)
    elseif plan.first=='attack' then
        -- Orbama owns ordinary attacks. Explicit requests are only needed for a
        -- concrete held card target; the SDK selected target remains authoritative.
        if c.state.stage=='held' then self:attack(target,modeID)end
    end
end
function C:interrupt()
    local c=self.c;local s=c.state
    if not c.config:get('interrupt') or c.cards.manual and c.cards.manual.color~='gold' then return end
    for _,u in ipairs(s.heroes)do
        -- activeSpell is a native object read. Allies and unavailable enemies
        -- cannot be interrupt candidates; reject them before requesting it.
        if u.team~=c.hero.team and U.target(u)then
        local a=u.activeSpell
        if a and a.valid and a.isChanneling then
            local id=U.id(u);local ending=a.endTime or a.castEndTime or 0
            local delay=c.cards:waitFor('gold')+c.sdk.Attack:GetWindup()+U.dist(c.hero,u)/1500
            local protect=s:protection(u)
            if not protect.immune and not protect.spellShield and not protect.dodge and not protect.invulnerable
                and ending>Game.Timer()+delay+.10 and U.dist(c.hero,u)<=c.sdk.Data:GetAutoAttackRange(c.hero,u)then
                c.cards:auto('gold','interrupt',function()
                    local a=u.activeSpell;local protect=s:protection(u)
                    return c.config:get('interrupt') and U.target(u) and a and a.valid and a.isChanneling
                        and (a.endTime or a.castEndTime or 0)>Game.Timer()+c.sdk.Attack:GetWindup()+U.dist(c.hero,u)/1500
                        and not protect.immune and not protect.spellShield and not protect.invulnerable
                end)
                if s.stage=='held' and s.color=='gold' then
                    return self:attack(u,nil,'interrupt',function()
                        local spell=u.activeSpell
                        return c.config:get('interrupt') and U.id(u)==id and spell and spell.valid and spell.isChanneling
                            and (spell.endTime or spell.castEndTime or 0)>Game.Timer()+c.sdk.Attack:GetWindup()+U.dist(c.hero,u)/1500
                            and not s:protection(u).immune and not s:protection(u).spellShield
                            and not(c.cards.manual and c.cards.manual.color~='gold')
                    end)
                end
                return true
            end
        end
        end
    end
end
function C:peel()
    local c=self.c;local s=c.state
    if s.mode=='FLEE' and not c.config:get('FLEEW')then return end
    if not(c.config:get('peel') or s.mode=='FLEE') or c.cards.manual and c.cards.manual.color~='gold' then return end
    if s.mode~='FLEE'then
        local approaching=false
        for _,u in ipairs(s.heroes)do
            if u.team~=c.hero.team and U.target(u) and U.dist(c.hero,u)<=650 then
                local path=u.pathing
                if path and path.isDashing and path.endPos and U.dist(path.endPos,c.hero)<300 then approaching=true;break end
            end
        end
        -- Keep the SDK's explicit selection/priority policy when there is a
        -- threat. Avoid its damage-based ranking when no action is possible.
        if not approaching then return end
    end
    local target=self:target(650)
    if not U.target(target)then return end
    local path=target.pathing;local threatening=s.mode=='FLEE' or path and path.isDashing and path.endPos and U.dist(path.endPos,c.hero)<300
    if not threatening then return end
    if not s:protection(target).immune then
        c.cards:auto('gold','peel',function()
            local path=target.pathing
            return U.target(target) and U.dist(c.hero,target)<650 and not s:protection(target).immune
                and (U.mode(c.sdk)=='FLEE' or c.config:get('peel') and path and path.isDashing and path.endPos and U.dist(path.endPos,c.hero)<300)
        end)
        if s.stage=='held' and s.color=='gold'then return self:attack(target,nil,'peel',function()
            return c.config:get('peel') or U.mode(c.sdk)=='FLEE'
        end)end
    end
end
function C:flee()
    local c=self.c;local s=c.state
    if c.config:get('FLEEQ') and s:ready(0) and c.hero.mana>=s:cost(0)+s:reserve(0)then
        local target=self:target(c.profile.q.range)
        if U.target(target) and U.dist(c.hero,target)>c.sdk.Data:GetAutoAttackRange(c.hero,target)then
            c.q:cast(target,s.modeID,function(t)return c.config:get('FLEEQ') and U.dist(c.hero,t)>c.sdk.Data:GetAutoAttackRange(c.hero,t)end)
        end
    end
end
function C:classicR()
    local c=self.c;local s=c.state
    if not(c.profile.autoRVerified and c.config:get('classicR')) or (s.mode~='COMBO' and s.mode~='FLEE')then return end
    local target=self:target(1000);if not U.target(target)then return end
    local id=U.id(target);local mode=s.modeID
    local function useful()
        local protection=s:protection(target)
        return U.id(target)==id and U.target(target) and c.sdk.Orbwalker.Modes[mode] and s:ready(3)
            and U.lower(c.hero:GetSpellData(3).name)==U.lower(c.profile.rName)
            and U.dist(c.hero,target)<1000 and U.dist(c.hero,target)>250 and protection.cc<.2
            and not protection.immune and not protection.spellShield and not protection.invulnerable
            and c.hero.mana>=s:cost(3)+s:reserve(3) and (target.ms or 0)>(c.hero.ms or 0)*.8
    end
    if useful()then return c.actions:submit(3,{owner='classic_r',context={modes={mode}},mechanical=useful})end
end
return C

end
modules["tf.config"] = function(require)
local M={}
function M.new(p)
    local menu=MenuElement({id='OrbamaTwistedFate',name='Card Marx - '..p.id,type=MENU})
    local nodes={}
    local function add(id,name,value,parent)
        parent=parent or menu;parent:MenuElement({id=id,name=name,value=value});nodes[id]=parent[id]
    end
    add('enabled','Enabled',true)
    menu:MenuElement({id='cards',name='Manual card (tap to select)',type=MENU})
    for _,row in ipairs({{'gold','Gold',84},{'red','Red',71},{'blue','Blue',72}})do
        menu.cards:MenuElement({id=row[1],name=row[2]..': tap to select / hold to repeat',key=row[3],toggle=false});nodes[row[1]]=menu.cards[row[1]]
    end
    for _,name in ipairs({'COMBO','HARASS','LASTHIT','LANECLEAR','JUNGLECLEAR','FLEE'})do
        menu:MenuElement({id=name,name=name,type=MENU})
        add(name..'Q','Use Q',name~='FLEE',menu[name]);add(name..'W','Use cards',true,menu[name])
    end
    add('interrupt','Gold: interrupt channels',true)
    add('peel','Gold: defend against approaching enemies',true)
    add('autoHarass','Harass without held mode',false)
    add('farmHarass','Harass during LaneClear',false)
    add('teleportCards','Prepare card after manual Gate',true)
    if p.autoRVerified then add('classicR','R slow in Combo / Flee',true)end
    add('defense','Defensive items and summoners',true)
    add('offense','Offensive items and Ignite / Exhaust',true)
    add('ghost','Ghost in Combo / Flee',false)
    add('level','Dynamic skill leveling',true)
    add('draw','Draw current intention',true)
    local c={menu=menu,nodes=nodes}
    function c:get(id)if id=='diagnostics'then return false end;return self.nodes[id] and self.nodes[id]:Value()end
    function c:key(id)return self.nodes[id] and self.nodes[id]:Key()end
    return c
end
return M

end
modules["tf.effects"] = function(require)
local U=require('tf.util')
local P=require('CombatProfiles.twisted_fate')
local E={};E.__index=E
-- Exact mode IDs; intentionally no arithmetic Jade aliases. Active eligibility
-- follows the workspace's dated Riot 16.17.1 extraction (lho.actives). Passive
-- damage needs separate proc/charge/cooldown evidence and is not inferred here.
local active={normal={
    [3140]={kind='qss'},[3139]={kind='qss'},[3157]={kind='stasis'},
    [3190]={kind='shield'},[3143]={kind='slow',range=500},
    [3142]={kind='speed',range=700},[2065]={kind='speed',range=700},
    [3146]={kind='target',range=600,slow=.25,duration=1.5}},classic={
    [773140]={kind='qss'},[773139]={kind='qss'},[773157]={kind='stasis'},
    [773190]={kind='shield'},[773143]={kind='slow',range=500},
    [773142]={kind='speed',range=600},[773069]={kind='speed',range=700},
    [773144]={kind='target',range=450},[773153]={kind='target',range=450,slow=.30,duration=3},[773146]={kind='target',range=600,slow=.40,duration=2}}}
E.coverage={
    cardCrit={status='supported',scope='asset coefficient times live crit chance; no random crit assumption'},
    stackedDeck={status='supported',scope='normal only; observed ready buff, target tower factor'},
    spellblade={status='unresolved',reason='mode-specific trigger, ICD and target rules require extracted item data'},
    onHit={status='unresolved',reason='SDK aggregate is not a typed, reusable proc model'},
    energized={status='unresolved',reason='charges and consumed range extension require host verification'},
    splash={status='unresolved',reason='splash must not be added to primary target twice'},
    chain={status='unresolved',reason='secondary victim and proc ICD unknown'},
    spellEffects={status='unresolved',reason='trigger and duration not profiled'},
    shopping={status='inapplicable',reason='explicitly outside controller scope'}}
local splashIDs={[3074]=true,[3085]=true,[3087]=true,[3748]=true,[773074]=true}
local cleanseTypes={[5]=true,[7]=true,[8]=true,[9]=true,[10]=true,[12]=true,[22]=true,[23]=true,[26]=true,[29]=true,[35]=true}
function E.new(c)return setmetatable({c=c,claims={}},E)end
function E:hasUnknownSplash()
    for _,row in pairs(self.c.state.inventory.slots)do if splashIDs[row.itemID]then return true end end
    return false
end
function E:cc(qss)
    local found=false;local air=false
    U.buffs(self.c.hero,function(b)
        if P.AliveBuff(b,Game.Timer()) and P.Expiry(b)>Game.Timer()+.15 then
            if b.type==30 or b.type==31 then air=true end
            if cleanseTypes[b.type] or qss and b.type==25 then found=true end
        end
    end)
    return found and not air
end
function E:threat()
    local c=self.c
    for _,u in ipairs(c.state.heroes)do
        if u.team~=c.hero.team and U.target(u) and U.dist(c.hero,u)<800 then
            local a=u.activeSpell
            if a and a.valid and (a.target==c.hero.handle or a.target==c.hero.networkID) then return true end
            if U.dist(c.hero,u)<(u.range or 125)+150 then return true end
        end
    end
    return false
end
function E:claimsUpdate()
    local c=self.c;local wanted=c.config:get('defense') and c.config:get('enabled') and c.active
    for _,name in ipairs({'qss','cleanse'})do
        if wanted and not self.claims[name]then self.claims[name]=c.actions.client:Claim(name,true)==true
        elseif not wanted and self.claims[name]then c.actions.client:Claim(name,false);self.claims[name]=nil end
    end
end
function E:allowedItem(slot,row,target)
    local c=self.c;local item=c.hero:GetItemData(slot)
    if not item or item.itemID~=row.id or not c.state:ready(slot)then return false end
    local low=c.hero.health/math.max(1,c.hero.maxHealth)<.25
    if row.kind=='qss'then return c.config:get('defense') and self.claims.qss and self:cc(true)end
    if row.kind=='stasis'then return c.config:get('defense') and c.hero.health/c.hero.maxHealth<.15 and self:threat()end
    if row.kind=='shield'then return c.config:get('defense') and low and self:threat()end
    if not c.config:get('offense') or not U.target(target)then return false end
    local mode=U.mode(c.sdk)
    if mode~='COMBO' and mode~='HARASS'then return false end
    if U.dist(c.hero,target)>row.range or c.state:windupActive()then return false end
    if row.kind=='speed'then return U.dist(c.hero,target)>c.sdk.Data:GetAutoAttackRange(c.hero,target)end
    return not c.state:protection(target).invulnerable
end
function E:tick()
    local c=self.c;self:claimsUpdate()
    local target
    -- Stable inventory slot order, defensive candidates before offensive candidates.
    for pass=1,1 do for slot=6,12 do
        local item=c.state.inventory.slots[slot];local rule=item and active[c.profile.id][item.itemID]
        if rule then
            local row=U.copy(rule);row.id=item.itemID
            local defensive=row.kind=='qss' or row.kind=='shield' or row.kind=='stasis'
            if (pass==1)==defensive and self:allowedItem(slot,row,target)then
                return c.actions:submit(slot,{owner='item',priority=defensive and 'critical' or 'normal',
                    keys={_G['HK_ITEM_'..(slot-5)]},kind=row.kind=='target' and 'object' or 'none',
                    target=row.kind=='target' and target or nil,targetID=row.kind=='target' and U.id(target) or nil,
                    mechanical=function()return self:allowedItem(slot,row,target)end})
            end
        end
    end end
    for slot=4,5 do
        local name=U.lower(c.hero:GetSpellData(slot).name)
        if c.state:ready(slot)then
            local function useful()
                if U.lower(c.hero:GetSpellData(slot).name)~=name or not c.state:ready(slot)then return false end
                if name=='summonerboost'then return c.config:get('defense') and self.claims.cleanse and self:cc(false)end
                if name=='summonerheal' or name=='summonerbarrier'then
                    return c.config:get('defense') and c.hero.health/c.hero.maxHealth<.25 and self:threat()
                end
                local mode=U.mode(c.sdk)
                if name=='summonerhaste' and c.config:get('ghost') and (mode=='COMBO' or mode=='FLEE')then
                    target=c.combat:target(800);return U.target(target)
                end
                if not c.config:get('offense') or (mode~='COMBO' and mode~='HARASS') or not U.target(target)then return false end
                -- Offensive targeted summoners are evaluated by the combat search.
                -- Ignite's host tooltip is not a reliable typed damage contract;
                -- until profiled, no invented damage threshold can authorize it.
                return false
            end
            if useful()then
                return c.actions:submit(slot,{owner='summoner',priority='critical',kind=name=='summonerexhaust' and 'object' or 'none',
                    target=name=='summonerexhaust' and target or nil,targetID=name=='summonerexhaust' and U.id(target) or nil,
                    mechanical=useful})
            end
        end
    end
end
function E:candidates(target)
    local c=self.c;local rows={};local protection=c.state:protection(target)
    if protection.invulnerable or protection.immune or protection.spellShield then return rows end
    for slot=6,12 do
        local item=c.state.inventory.slots[slot];local rule=item and active[c.profile.id][item.itemID]
        if rule and rule.slow then
            local row=U.copy(rule);row.id=item.itemID
            if self:allowedItem(slot,row,target) and protection.cc<row.duration then
                rows[#rows+1]={id=slot,slot=slot,row=row,cost=0,delay=.05,castTime=.05,
                    control=(row.duration-protection.cc)*row.slow,opportunityCost=15,packet={}}
            end
        end
    end
    if c.profile.autoRVerified and c.config:get('classicR') and c.state:ready(3)
        and c.hero.mana>=c.state:cost(3)+c.state:reserve(3)
        and (c.state.mode=='COMBO' or c.state.mode=='FLEE') and U.dist(c.hero,target)<1000 then
        rows[#rows+1]={id=3,slot=3,cost=c.state:cost(3),delay=.25,castTime=.25,
            control=math.max(0,P.Rank(c.profile.rDuration,c.state.spells[3].level)-protection.cc)*c.profile.rSlow,
            opportunityCost=50,packet={}}
    end
    if c.config:get('offense') and (c.state.mode=='COMBO' or c.state.mode=='HARASS') and self:threat()then
        for slot=4,5 do
            local spell=c.hero:GetSpellData(slot)
            local range=(spell.range or 0)>0 and spell.range or c.profile.id=='normal' and 650 or 0
            if U.lower(spell.name)=='summonerexhaust' and c.state:ready(slot) and U.dist(c.hero,target)<=range then
                -- Utility budget, not a claim about exact slow duration or damage reduction.
                rows[#rows+1]={id=slot,slot=slot,cost=0,delay=.05,castTime=.05,control=.5,opportunityCost=100,packet={}}
            end
        end
    end
    return rows
end
function E:execute(slot,target,mode)
    local c=self.c;local chosen
    for _,row in ipairs(self:candidates(target))do if row.slot==slot then chosen=row;break end end
    if not chosen then return false end
    local targetID=U.id(target)
    return c.actions:submit(slot,{owner='planned_active',priority='normal',context={modes={mode}},
        keys={slot==3 and HK_R or slot==4 and HK_SUMMONER_1 or slot==5 and HK_SUMMONER_2 or _G['HK_ITEM_'..(slot-5)]},
        kind=slot==3 and 'none' or 'object',target=slot~=3 and target or nil,targetID=targetID,
        mechanical=function()
            if U.id(target)~=targetID or not U.target(target)then return false end
            for _,row in ipairs(self:candidates(target))do if row.slot==slot then return true end end
            return false
        end})
end
return E

end
modules["tf.farm"] = function(require)
local U=require('tf.util')
local P=require('CombatProfiles.twisted_fate')
local F={};F.__index=F
function F.new(c)return setmetatable({c=c},F)end
function F:eligible(u,mode)
    local c=self.c
    if not U.target(u) or u.team==c.hero.team or u.type~=Obj_AI_Minion then return false end
    if mode=='JUNGLECLEAR' then return u.team==300 and U.dist(c.hero,u)<850 end
    return u.team~=300 and U.dist(c.hero,u)<c.profile.q.range
end
function F:hp(u,delay)return self.c.sdk.HealthPrediction:GetPrediction(u,delay)end
function F:impact(u)
    local c=self.c;local attack=c.sdk.Attack
    local wait=math.max(0,(attack.ServerStart or -10)+attack:GetAnimation()-Game.Timer())
    return wait+attack:GetWindup()+U.dist(c.hero,u)/math.max(1,attack:GetProjectileSpeed())
end
function F:aa(u,color)
    local raw=self.c.combat:packet(u,color,self.c.state.eReady)
    return raw.physical+raw.magical+raw.trueDamage
end
function F:attackChoice(mode)
    local c=self.c;local s=c.state;local hit,best,urgent,hitHP,bestHP
    local examined=0
    for _,u in ipairs(s.minions)do
        examined=examined+1;if examined>128 then break end
        if self:eligible(u,mode) and U.dist(c.hero,u)<=c.sdk.Data:GetAutoAttackRange(c.hero,u)then
            local at=self:impact(u);local hp=self:hp(u,at)
            if hp>0 then
                if not best or hp<bestHP then best=u;bestHP=hp end
                if hp<=self:aa(u,s.stage=='held' and s.color or nil)then
                    local losesWindow=self:hp(u,at+c.profile.q.delay)<=0
                    if not hit or losesWindow and not urgent or losesWindow==urgent and hp<hitHP then
                        hit=u;hitHP=hp;urgent=losesWindow
                    end
                end
            end
        end
    end
    return hit,best,urgent
end
function F:decision(reason,target)
    local c=self.c;if not c.config:get('diagnostics')then return end
    local id=target and U.id(target);local now=Game.Timer()
    if self.lastReason==reason and self.lastTarget==id and now<(self.nextDecision or 0)then return end
    self.lastReason=reason;self.lastTarget=id;self.nextDecision=now+.5
    c:record('farm_decision',{reason=reason,target=id,mode=c.state.mode})
end
function F:diagnostics(mode)
    local c=self.c;if not c.config:get('diagnostics')then return end
    local now=Game.Timer();if now<(self.nextDiagnostic or 0)then return end
    self.nextDiagnostic=now+.25
    local s=c.state;local attack=c.sdk.Attack;local n=0;local examined=0;local tracked={}
    local sdkRows={}
    for i,row in ipairs(c.sdk.HealthPrediction.FarmMinions or {})do
        if i>128 then break end
        if row.Minion then sdkRows[U.id(row.Minion)]=row end
    end
    c:record('farm_snapshot',{mode=mode,stage=s.stage,color=s.color,manual=c.cards.manual and c.cards.manual.color,
        attackBlocked=c.actions.client.locks.manual_card and c.actions.client.locks.manual_card.attack,
        providerCanAttack=c.sdk.Orbwalker:CanAttack(),
        attackJob=c.combat.attackID,serverStart=attack.ServerStart,castEnd=attack.CastEndTime,
        period=attack:GetAnimation(),windup=attack:GetWindup(),speed=attack:GetProjectileSpeed(),
        qReady=s:ready(0),wReady=s:ready(1,s.stage=='selecting'),eReady=s.eReady,mana=c.hero.mana})
    for _,u in ipairs(s.minions)do
        examined=examined+1;if examined>128 or n>=12 then break end
        if self:eligible(u,mode)then
            n=n+1;local at=self:impact(u);local row=sdkRows[U.id(u)]
            tracked[U.id(u)]={unit=u,health=u.health,at=now}
            c:record('farm_minion',{id=U.id(u),handle=u.handle,name=u.charName,team=u.team,health=u.health,
                maxHealth=u.maxHealth,distance=U.dist(c.hero,u),range=c.sdk.Data:GetAutoAttackRange(c.hero,u),
                aaImpact=at,hpAA=self:hp(u,at),aaDamage=self:aa(u,s.stage=='held' and s.color or nil),
                hpAfterQCast=self:hp(u,at+c.profile.q.delay),qImpact=c.profile.q.delay+U.dist(c.hero,u)/c.profile.q.speed,
                hpQ=self:hp(u,c.profile.q.delay+U.dist(c.hero,u)/c.profile.q.speed),qDamage=c.combat:qDamage(u),
                sdkLastHittable=row and row.LastHitable,sdkPredictedHP=row and row.PredictedHP,
                sdkUnkillable=row and row.Unkillable})
        end
    end
    for id,last in pairs(self.tracked or {})do
        if not tracked[id]then
            local u=last.unit;local dead=u.valid~=false and (u.dead or (u.health or 1)<=0)
            c:record('farm_minion_exit',{id=id,lastHealth=last.health,lastSeen=last.at,
                state=dead and 'death_observed' or 'left_sample',credit='unknown'})
        end
    end
    self.tracked=tracked
end
function F:qWorth(u,mode,attackWindowChecked,evaluation)
    local c=self.c;local s=c.state
    if not attackWindowChecked then
        local _,_,urgent=self:attackChoice(mode)
        if urgent then return false end -- Rechecked before a queued Q sends, too.
    end
    if evaluation and not evaluation.geometry then evaluation.geometry={}end
    local plan=c.q:plan(u,s.minions,evaluation and evaluation.geometry);if not plan then return false end
    local kills,total=0,0
    for _,m in ipairs(plan.hits)do
        if not self:eligible(m,mode)then return false end
        local id=U.id(m);local row=evaluation and evaluation[id]
        if not row then
            row={hp=self:hp(m,c.profile.q.delay+U.dist(c.hero,m)/c.profile.q.speed),damage=c.combat:qDamage(m)}
            if evaluation then evaluation[id]=row end
        end
        local hp,damage=row.hp,row.damage
        if hp>0 then
            total=total+math.min(damage,hp)
            if hp<=damage then kills=kills+1 elseif mode=='LASTHIT' then return false end
        end
    end
    if mode=='LASTHIT' then
        local aaTime=self:impact(u)
        local hpAA=self:hp(u,aaTime)
        if c.effects:hasUnknownSplash()then return false end
        local inRange=U.dist(c.hero,u)<=c.sdk.Data:GetAutoAttackRange(c.hero,u)
        if inRange and hpAA>0 and hpAA<=self:aa(u,s.stage=='held' and s.color or nil) then return false end
        return kills>0 and c.hero.mana>=s:cost(0)+s:reserve(0)
    end
    return total>0 and (kills>0 or #plan.hits>=2 or mode=='JUNGLECLEAR') and c.hero.mana>=s:cost(0)+s:reserve(0),kills,total
end
function F:tick(mode,modeID)
    local c=self.c;local s=c.state
    self:diagnostics(mode)
    local hit,best,urgent=self:attackChoice(mode)
    local function attack(u)
        self:decision(urgent and 'save_aa_window' or 'aa_last_hit',u)
        return c.combat:attack(u,modeID,'farm_attack',function()
            local hp=self:hp(u,self:impact(u));local color=c.state.stage=='held' and c.state.color or nil
            return self:eligible(u,mode) and hp>0 and hp<=self:aa(u,color)
        end)
    end
    if hit and (urgent or mode=='LASTHIT')then return attack(hit)end
    local examined=0
    local qTarget,qKills,qTotal;local predicted=0
    -- These candidates are evaluated synchronously from the same fresh state.
    -- Reuse identical Q impact health/damage, never across ticks or dispatch.
    local evaluation={}
    local canQ=c.config:get(mode..'Q') and s:ready(0) and not s:windupActive()
        and not c.actions:busy(0) and c.hero.mana>=s:cost(0)+s:reserve(0)
    for _,u in ipairs(s.minions)do
        examined=examined+1;if examined>128 then break end
        if self:eligible(u,mode)then
            if canQ and predicted<8 then
                predicted=predicted+1
                local worth,kills,total=self:qWorth(u,mode,true,evaluation);kills=kills or 1;total=total or 0
                if worth and (not qTarget or kills>qKills or kills==qKills and total>qTotal)then
                    qTarget=u;qKills=kills;qTotal=total
                end
            end
        end
    end
    if qTarget then
        self:decision('q_farm',qTarget)
        return c.q:cast(qTarget,modeID,function(t)return c.config:get(mode..'Q') and self:eligible(t,mode) and self:qWorth(t,mode)end)
    end
    if hit then return attack(hit)end
    if not best then self:decision('no_reachable_target');return end
    if c.config:get('level') and math.floor(Game.Timer())~=c.level.lastSample then
        local qOpportunity=c.q:plan(best,s.minions)
        c.level:sample(mode,{attack=true,period=c.sdk.Attack:GetAnimation(),
            q=qOpportunity and #qOpportunity.hits>=2 and true or nil,controlValue=0})
    end
    local bestHP=self:hp(best,self:impact(best))
    self:decision('provider_clear_or_wait',best)
    if c.cards.manual or not c.config:get(mode..'W') or s.stage=='held' or not s:ready(1,s.stage=='selecting')then return end
    local blue=self:aa(best,'blue')
    if mode=='LASTHIT' then
        if not c.effects:hasUnknownSplash() and bestHP<=blue and c.cards:waitFor('blue')<.4
            and c.hero.mana>=s:cost(1)+s:reserve(1)then c.cards:auto('blue','save_cs',function()
                local hp=self:hp(best,self:impact(best)+c.cards:waitFor('blue'))
                return self:eligible(best,mode) and hp>0 and hp<=self:aa(best,'blue')
            end)end
    else
        local color='blue'
        local usable=P.BlueRecovery(c.profile,s.spells[1].level,c.hero.mana,c.hero.maxMana)
        local splash=0
        if c.profile.redRadius then
            for _,u in ipairs(s.minions)do if self:eligible(u,mode) and U.dist(best,u)<=c.profile.redRadius then splash=splash+1 end end
        end
        if splash>=3 and c.hero.mana-s:cost(1)>=s:reserve(1)+s:cost(0) and usable<25 then color='red'end
        local recovery=color=='blue' and P.Rank(c.profile.wMana,s.spells[1].level) or 0
        if c.hero.mana>=s:cost(1) and math.min(c.hero.maxMana,c.hero.mana-s:cost(1)+recovery)>=s:reserve(1)then
            c.cards:auto(color,'clear',function()return self:eligible(best,mode) and U.dist(c.hero,best)<=c.sdk.Data:GetAutoAttackRange(c.hero,best)end)
        end
    end
end
return F

end
modules["tf.itemstats"] = function(require)
-- Generated by tools/build_tf_itemstats.py; Riot 16.17.1, exact observed inventory IDs only.
return {[1001]={["ap"]=0,["ad"]=0,["as"]=0},[1004]={["ap"]=0,["ad"]=0,["as"]=0},[1006]={["ap"]=0,["ad"]=0,["as"]=0},[1011]={["ap"]=0,["ad"]=0,["as"]=0},[1018]={["ap"]=0,["ad"]=0,["as"]=0},[1026]={["ap"]=45,["ad"]=0,["as"]=0},[1027]={["ap"]=0,["ad"]=0,["as"]=0},[1028]={["ap"]=0,["ad"]=0,["as"]=0},[1029]={["ap"]=0,["ad"]=0,["as"]=0},[1031]={["ap"]=0,["ad"]=0,["as"]=0},[1033]={["ap"]=0,["ad"]=0,["as"]=0},[1036]={["ap"]=0,["ad"]=10,["as"]=0},[1037]={["ap"]=0,["ad"]=25,["as"]=0},[1038]={["ap"]=0,["ad"]=40,["as"]=0},[1042]={["ap"]=0,["ad"]=0,["as"]=0.1},[1043]={["ap"]=0,["ad"]=0,["as"]=0.15},[1052]={["ap"]=20,["ad"]=0,["as"]=0},[1053]={["ap"]=0,["ad"]=15,["as"]=0},[1054]={["ap"]=0,["ad"]=0,["as"]=0},[1055]={["ap"]=0,["ad"]=10,["as"]=0},[1056]={["ap"]=18,["ad"]=0,["as"]=0},[1057]={["ap"]=0,["ad"]=0,["as"]=0},[1058]={["ap"]=65,["ad"]=0,["as"]=0},[1082]={["ap"]=15,["ad"]=0,["as"]=0},[1083]={["ap"]=0,["ad"]=7,["as"]=0},[1086]={["ap"]=0,["ad"]=8,["as"]=0.15},[1101]={["ap"]=0,["ad"]=0,["as"]=0},[1102]={["ap"]=0,["ad"]=0,["as"]=0},[1103]={["ap"]=0,["ad"]=0,["as"]=0},[1105]={["ap"]=0,["ad"]=0,["as"]=0},[1106]={["ap"]=0,["ad"]=0,["as"]=0},[1107]={["ap"]=0,["ad"]=0,["as"]=0},[1120]={["ap"]=0,["ad"]=0,["as"]=0},[1501]={["ap"]=0,["ad"]=0,["as"]=0},[1502]={["ap"]=0,["ad"]=0,["as"]=0},[1503]={["ap"]=0,["ad"]=0,["as"]=0},[1505]={["ap"]=0,["ad"]=0,["as"]=0},[1506]={["ap"]=0,["ad"]=0,["as"]=0},[1507]={["ap"]=0,["ad"]=0,["as"]=0},[1508]={["ap"]=0,["ad"]=0,["as"]=0},[1509]={["ap"]=0,["ad"]=0,["as"]=0},[1510]={["ap"]=0,["ad"]=0,["as"]=0},[1511]={["ap"]=0,["ad"]=0,["as"]=0},[1512]={["ap"]=0,["ad"]=0,["as"]=0},[1515]={["ap"]=0,["ad"]=0,["as"]=0},[1516]={["ap"]=0,["ad"]=0,["as"]=0},[1517]={["ap"]=0,["ad"]=0,["as"]=0},[1518]={["ap"]=0,["ad"]=0,["as"]=0},[1519]={["ap"]=0,["ad"]=0,["as"]=0},[1520]={["ap"]=0,["ad"]=0,["as"]=0},[1521]={["ap"]=0,["ad"]=0,["as"]=0},[1522]={["ap"]=0,["ad"]=0,["as"]=0},[1523]={["ap"]=0,["ad"]=0,["as"]=0},[1524]={["ap"]=0,["ad"]=0,["as"]=0},[2001]={["ap"]=0,["ad"]=0,["as"]=0},[2003]={["ap"]=0,["ad"]=0,["as"]=0},[2007]={["ap"]=0,["ad"]=0,["as"]=0},[2010]={["ap"]=0,["ad"]=0,["as"]=0},[2019]={["ap"]=0,["ad"]=15,["as"]=0},[2020]={["ap"]=0,["ad"]=25,["as"]=0},[2021]={["ap"]=0,["ad"]=15,["as"]=0},[2022]={["ap"]=0,["ad"]=0,["as"]=0},[2031]={["ap"]=0,["ad"]=0,["as"]=0},[2033]={["ap"]=0,["ad"]=0,["as"]=0},[2051]={["ap"]=0,["ad"]=0,["as"]=0},[2052]={["ap"]=0,["ad"]=0,["as"]=0},[2055]={["ap"]=0,["ad"]=0,["as"]=0},[2065]={["ap"]=50,["ad"]=0,["as"]=0},[2138]={["ap"]=0,["ad"]=0,["as"]=0},[2139]={["ap"]=0,["ad"]=0,["as"]=0},[2140]={["ap"]=0,["ad"]=0,["as"]=0},[2141]={["ap"]=0,["ad"]=0,["as"]=0},[2150]={["ap"]=0,["ad"]=0,["as"]=0},[2151]={["ap"]=0,["ad"]=0,["as"]=0},[2152]={["ap"]=0,["ad"]=0,["as"]=0},[2403]={["ap"]=0,["ad"]=0,["as"]=0},[2420]={["ap"]=40,["ad"]=0,["as"]=0},[2421]={["ap"]=40,["ad"]=0,["as"]=0},[2422]={["ap"]=0,["ad"]=0,["as"]=0},[2501]={["ap"]=0,["ad"]=30,["as"]=0},[2502]={["ap"]=0,["ad"]=0,["as"]=0},[2503]={["ap"]=80,["ad"]=0,["as"]=0},[2504]={["ap"]=0,["ad"]=0,["as"]=0},[2508]={["ap"]=30,["ad"]=0,["as"]=0},[2510]={["ap"]=60,["ad"]=0,["as"]=0.2},[2512]={["ap"]=0,["ad"]=0,["as"]=0.45},[2517]={["ap"]=0,["ad"]=65,["as"]=0},[2520]={["ap"]=0,["ad"]=55,["as"]=0},[2522]={["ap"]=90,["ad"]=0,["as"]=0},[2523]={["ap"]=0,["ad"]=55,["as"]=0},[2524]={["ap"]=0,["ad"]=0,["as"]=0},[2525]={["ap"]=0,["ad"]=0,["as"]=0},[2526]={["ap"]=0,["ad"]=0,["as"]=0},[2530]={["ap"]=0,["ad"]=0,["as"]=0},[3002]={["ap"]=0,["ad"]=0,["as"]=0},[3003]={["ap"]=70,["ad"]=0,["as"]=0},[3004]={["ap"]=0,["ad"]=35,["as"]=0},[3006]={["ap"]=0,["ad"]=0,["as"]=0.3},[3008]={["ap"]=0,["ad"]=0,["as"]=0},[3009]={["ap"]=0,["ad"]=0,["as"]=0},[3010]={["ap"]=0,["ad"]=0,["as"]=0},[3011]={["ap"]=35,["ad"]=0,["as"]=0},[3013]={["ap"]=0,["ad"]=0,["as"]=0},[3020]={["ap"]=0,["ad"]=0,["as"]=0},[3024]={["ap"]=0,["ad"]=0,["as"]=0},[3026]={["ap"]=0,["ad"]=55,["as"]=0},[3031]={["ap"]=0,["ad"]=75,["as"]=0},[3032]={["ap"]=0,["ad"]=50,["as"]=0.45},[3033]={["ap"]=0,["ad"]=35,["as"]=0},[3035]={["ap"]=0,["ad"]=20,["as"]=0},[3036]={["ap"]=0,["ad"]=35,["as"]=0},[3040]={["ap"]=70,["ad"]=0,["as"]=0},[3041]={["ap"]=20,["ad"]=0,["as"]=0},[3042]={["ap"]=0,["ad"]=35,["as"]=0},[3044]={["ap"]=0,["ad"]=15,["as"]=0},[3046]={["ap"]=0,["ad"]=0,["as"]=0.65},[3047]={["ap"]=0,["ad"]=0,["as"]=0},[3050]={["ap"]=0,["ad"]=0,["as"]=0},[3051]={["ap"]=0,["ad"]=20,["as"]=0.2},[3053]={["ap"]=0,["ad"]=0,["as"]=0},[3057]={["ap"]=0,["ad"]=0,["as"]=0},[3065]={["ap"]=0,["ad"]=0,["as"]=0},[3066]={["ap"]=0,["ad"]=0,["as"]=0},[3067]={["ap"]=0,["ad"]=0,["as"]=0},[3068]={["ap"]=0,["ad"]=0,["as"]=0},[3070]={["ap"]=0,["ad"]=0,["as"]=0},[3071]={["ap"]=0,["ad"]=45,["as"]=0},[3072]={["ap"]=0,["ad"]=80,["as"]=0},[3073]={["ap"]=0,["ad"]=40,["as"]=0.2},[3074]={["ap"]=0,["ad"]=65,["as"]=0},[3075]={["ap"]=0,["ad"]=0,["as"]=0},[3076]={["ap"]=0,["ad"]=0,["as"]=0},[3077]={["ap"]=0,["ad"]=25,["as"]=0},[3078]={["ap"]=0,["ad"]=36,["as"]=0.3},[3082]={["ap"]=0,["ad"]=0,["as"]=0},[3083]={["ap"]=0,["ad"]=0,["as"]=0},[3084]={["ap"]=0,["ad"]=0,["as"]=0},[3085]={["ap"]=0,["ad"]=0,["as"]=0.4},[3086]={["ap"]=0,["ad"]=0,["as"]=0.15},[3087]={["ap"]=45,["ad"]=45,["as"]=0.3},[3089]={["ap"]=130,["ad"]=0,["as"]=0},[3091]={["ap"]=0,["ad"]=0,["as"]=0.5},[3094]={["ap"]=0,["ad"]=0,["as"]=0.35},[3095]={["ap"]=0,["ad"]=50,["as"]=0.25},[3100]={["ap"]=100,["ad"]=0,["as"]=0},[3102]={["ap"]=105,["ad"]=0,["as"]=0},[3107]={["ap"]=30,["ad"]=0,["as"]=0},[3108]={["ap"]=25,["ad"]=0,["as"]=0},[3109]={["ap"]=0,["ad"]=0,["as"]=0},[3110]={["ap"]=0,["ad"]=0,["as"]=0},[3111]={["ap"]=0,["ad"]=0,["as"]=0},[3112]={["ap"]=50,["ad"]=0,["as"]=0},[3113]={["ap"]=30,["ad"]=0,["as"]=0},[3114]={["ap"]=0,["ad"]=0,["as"]=0},[3115]={["ap"]=80,["ad"]=0,["as"]=0.5},[3116]={["ap"]=65,["ad"]=0,["as"]=0},[3117]={["ap"]=0,["ad"]=0,["as"]=0},[3118]={["ap"]=90,["ad"]=0,["as"]=0},[3119]={["ap"]=0,["ad"]=0,["as"]=0},[3121]={["ap"]=0,["ad"]=0,["as"]=0},[3123]={["ap"]=0,["ad"]=15,["as"]=0},[3124]={["ap"]=30,["ad"]=30,["as"]=0.25},[3133]={["ap"]=0,["ad"]=20,["as"]=0},[3134]={["ap"]=0,["ad"]=20,["as"]=0},[3135]={["ap"]=95,["ad"]=0,["as"]=0},[3137]={["ap"]=75,["ad"]=0,["as"]=0},[3139]={["ap"]=0,["ad"]=50,["as"]=0},[3140]={["ap"]=0,["ad"]=0,["as"]=0},[3142]={["ap"]=0,["ad"]=55,["as"]=0},[3143]={["ap"]=0,["ad"]=0,["as"]=0},[3144]={["ap"]=0,["ad"]=0,["as"]=0.2},[3145]={["ap"]=45,["ad"]=0,["as"]=0},[3146]={["ap"]=80,["ad"]=40,["as"]=0},[3147]={["ap"]=30,["ad"]=0,["as"]=0},[3152]={["ap"]=60,["ad"]=0,["as"]=0},[3153]={["ap"]=0,["ad"]=40,["as"]=0.25},[3155]={["ap"]=0,["ad"]=25,["as"]=0},[3156]={["ap"]=0,["ad"]=60,["as"]=0},[3157]={["ap"]=105,["ad"]=0,["as"]=0},[3158]={["ap"]=0,["ad"]=0,["as"]=0},[3161]={["ap"]=0,["ad"]=45,["as"]=0},[3165]={["ap"]=75,["ad"]=0,["as"]=0},[3168]={["ap"]=0,["ad"]=0,["as"]=0},[3170]={["ap"]=0,["ad"]=0,["as"]=0},[3171]={["ap"]=0,["ad"]=0,["as"]=0},[3172]={["ap"]=0,["ad"]=0,["as"]=0.45},[3173]={["ap"]=0,["ad"]=0,["as"]=0},[3174]={["ap"]=0,["ad"]=0,["as"]=0},[3175]={["ap"]=0,["ad"]=0,["as"]=0},[3176]={["ap"]=0,["ad"]=0,["as"]=0},[3177]={["ap"]=0,["ad"]=30,["as"]=0},[3179]={["ap"]=0,["ad"]=60,["as"]=0},[3181]={["ap"]=0,["ad"]=40,["as"]=0},[3184]={["ap"]=0,["ad"]=25,["as"]=0},[3190]={["ap"]=0,["ad"]=0,["as"]=0},[3211]={["ap"]=0,["ad"]=0,["as"]=0},[322065]={["ap"]=65,["ad"]=0,["as"]=0},[3222]={["ap"]=0,["ad"]=0,["as"]=0},[322526]={["ap"]=0,["ad"]=0,["as"]=0},[322530]={["ap"]=0,["ad"]=0,["as"]=0},[323002]={["ap"]=0,["ad"]=0,["as"]=0},[323003]={["ap"]=70,["ad"]=0,["as"]=0},[323004]={["ap"]=0,["ad"]=35,["as"]=0},[323040]={["ap"]=70,["ad"]=0,["as"]=0},[323042]={["ap"]=0,["ad"]=35,["as"]=0},[323050]={["ap"]=0,["ad"]=0,["as"]=0},[323070]={["ap"]=0,["ad"]=0,["as"]=0},[323075]={["ap"]=0,["ad"]=0,["as"]=0},[323107]={["ap"]=30,["ad"]=0,["as"]=0},[323109]={["ap"]=0,["ad"]=0,["as"]=0},[323110]={["ap"]=0,["ad"]=0,["as"]=0},[323119]={["ap"]=0,["ad"]=0,["as"]=0},[323121]={["ap"]=0,["ad"]=0,["as"]=0},[323190]={["ap"]=0,["ad"]=0,["as"]=0},[323222]={["ap"]=0,["ad"]=0,["as"]=0},[323504]={["ap"]=55,["ad"]=0,["as"]=0},[324005]={["ap"]=65,["ad"]=0,["as"]=0},[326616]={["ap"]=45,["ad"]=0,["as"]=0},[326617]={["ap"]=35,["ad"]=0,["as"]=0},[326620]={["ap"]=35,["ad"]=0,["as"]=0},[326621]={["ap"]=50,["ad"]=0,["as"]=0},[326657]={["ap"]=45,["ad"]=0,["as"]=0},[328020]={["ap"]=0,["ad"]=0,["as"]=0},[3302]={["ap"]=0,["ad"]=30,["as"]=0.35},[3330]={["ap"]=0,["ad"]=0,["as"]=0},[3340]={["ap"]=0,["ad"]=0,["as"]=0},[3363]={["ap"]=0,["ad"]=0,["as"]=0},[3364]={["ap"]=0,["ad"]=0,["as"]=0},[3400]={["ap"]=0,["ad"]=0,["as"]=0},[3504]={["ap"]=45,["ad"]=0,["as"]=0},[3508]={["ap"]=0,["ad"]=50,["as"]=0},[3599]={["ap"]=0,["ad"]=0,["as"]=0},[3600]={["ap"]=0,["ad"]=0,["as"]=0},[3742]={["ap"]=0,["ad"]=0,["as"]=0},[3748]={["ap"]=0,["ad"]=40,["as"]=0},[3801]={["ap"]=0,["ad"]=0,["as"]=0},[3802]={["ap"]=40,["ad"]=0,["as"]=0},[3803]={["ap"]=0,["ad"]=0,["as"]=0},[3814]={["ap"]=0,["ad"]=50,["as"]=0},[3865]={["ap"]=0,["ad"]=0,["as"]=0},[3866]={["ap"]=0,["ad"]=0,["as"]=0},[3867]={["ap"]=0,["ad"]=0,["as"]=0},[3869]={["ap"]=0,["ad"]=0,["as"]=0},[3870]={["ap"]=0,["ad"]=0,["as"]=0},[3871]={["ap"]=0,["ad"]=0,["as"]=0},[3876]={["ap"]=0,["ad"]=0,["as"]=0},[3877]={["ap"]=0,["ad"]=0,["as"]=0},[3901]={["ap"]=0,["ad"]=0,["as"]=0},[3902]={["ap"]=0,["ad"]=0,["as"]=0},[3903]={["ap"]=0,["ad"]=0,["as"]=0},[3916]={["ap"]=25,["ad"]=0,["as"]=0},[4005]={["ap"]=60,["ad"]=0,["as"]=0},[4401]={["ap"]=0,["ad"]=0,["as"]=0},[4628]={["ap"]=75,["ad"]=0,["as"]=0},[4629]={["ap"]=70,["ad"]=0,["as"]=0},[4630]={["ap"]=25,["ad"]=0,["as"]=0},[4632]={["ap"]=40,["ad"]=0,["as"]=0},[4633]={["ap"]=70,["ad"]=0,["as"]=0},[4635]={["ap"]=20,["ad"]=0,["as"]=0},[4636]={["ap"]=90,["ad"]=0,["as"]=0},[4637]={["ap"]=75,["ad"]=0,["as"]=0},[4641]={["ap"]=0,["ad"]=0,["as"]=0},[4642]={["ap"]=20,["ad"]=0,["as"]=0},[4645]={["ap"]=110,["ad"]=0,["as"]=0},[4646]={["ap"]=90,["ad"]=0,["as"]=0},[6333]={["ap"]=0,["ad"]=60,["as"]=0},[6609]={["ap"]=0,["ad"]=45,["as"]=0},[6610]={["ap"]=0,["ad"]=40,["as"]=0},[6616]={["ap"]=35,["ad"]=0,["as"]=0},[6617]={["ap"]=25,["ad"]=0,["as"]=0},[6620]={["ap"]=35,["ad"]=0,["as"]=0},[6621]={["ap"]=45,["ad"]=0,["as"]=0},[663039]={["ap"]=0,["ad"]=0,["as"]=0},[663056]={["ap"]=0,["ad"]=0,["as"]=0},[663058]={["ap"]=0,["ad"]=0,["as"]=0},[663059]={["ap"]=0,["ad"]=0,["as"]=0},[663060]={["ap"]=0,["ad"]=0,["as"]=0},[663064]={["ap"]=0,["ad"]=0,["as"]=0},[6631]={["ap"]=0,["ad"]=40,["as"]=0.25},[663146]={["ap"]=90,["ad"]=45,["as"]=0},[663172]={["ap"]=0,["ad"]=0,["as"]=0.4},[663193]={["ap"]=0,["ad"]=0,["as"]=0},[664011]={["ap"]=35,["ad"]=0,["as"]=0},[664403]={["ap"]=125,["ad"]=90,["as"]=0.3},[664644]={["ap"]=65,["ad"]=0,["as"]=0},[6653]={["ap"]=60,["ad"]=0,["as"]=0},[6655]={["ap"]=100,["ad"]=0,["as"]=0},[6657]={["ap"]=45,["ad"]=0,["as"]=0},[6660]={["ap"]=0,["ad"]=0,["as"]=0},[6662]={["ap"]=0,["ad"]=0,["as"]=0},[6664]={["ap"]=0,["ad"]=0,["as"]=0},[6665]={["ap"]=0,["ad"]=0,["as"]=0},[6670]={["ap"]=0,["ad"]=15,["as"]=0},[667101]={["ap"]=0,["ad"]=0,["as"]=0},[667109]={["ap"]=60,["ad"]=0,["as"]=0},[667112]={["ap"]=0,["ad"]=0,["as"]=0},[6672]={["ap"]=0,["ad"]=45,["as"]=0.4},[6673]={["ap"]=0,["ad"]=55,["as"]=0},[6675]={["ap"]=0,["ad"]=0,["as"]=0.4},[6676]={["ap"]=0,["ad"]=50,["as"]=0},[667666]={["ap"]=0,["ad"]=50,["as"]=0},[6690]={["ap"]=0,["ad"]=15,["as"]=0},[6692]={["ap"]=0,["ad"]=60,["as"]=0},[6693]={["ap"]=0,["ad"]=55,["as"]=0},[6694]={["ap"]=0,["ad"]=45,["as"]=0},[6695]={["ap"]=0,["ad"]=55,["as"]=0},[6696]={["ap"]=0,["ad"]=55,["as"]=0},[6697]={["ap"]=0,["ad"]=55,["as"]=0},[6698]={["ap"]=0,["ad"]=55,["as"]=0},[6699]={["ap"]=0,["ad"]=55,["as"]=0},[6701]={["ap"]=0,["ad"]=55,["as"]=0},[7050]={["ap"]=0,["ad"]=0,["as"]=0},[771001]={["ap"]=0,["ad"]=0,["as"]=0},[771004]={["ap"]=0,["ad"]=0,["as"]=0},[771006]={["ap"]=0,["ad"]=0,["as"]=0},[771011]={["ap"]=0,["ad"]=0,["as"]=0},[771018]={["ap"]=0,["ad"]=0,["as"]=0},[771026]={["ap"]=40,["ad"]=0,["as"]=0},[771027]={["ap"]=0,["ad"]=0,["as"]=0},[771028]={["ap"]=0,["ad"]=0,["as"]=0},[771029]={["ap"]=0,["ad"]=0,["as"]=0},[771031]={["ap"]=0,["ad"]=0,["as"]=0},[771033]={["ap"]=0,["ad"]=0,["as"]=0},[771036]={["ap"]=0,["ad"]=10,["as"]=0},[771037]={["ap"]=0,["ad"]=25,["as"]=0},[771038]={["ap"]=0,["ad"]=45,["as"]=0},[771039]={["ap"]=0,["ad"]=0,["as"]=0},[771042]={["ap"]=0,["ad"]=0,["as"]=0.12},[771043]={["ap"]=0,["ad"]=0,["as"]=0.3},[771051]={["ap"]=0,["ad"]=0,["as"]=0},[771052]={["ap"]=20,["ad"]=0,["as"]=0},[771053]={["ap"]=0,["ad"]=10,["as"]=0},[771054]={["ap"]=0,["ad"]=0,["as"]=0},[771055]={["ap"]=0,["ad"]=10,["as"]=0},[771056]={["ap"]=15,["ad"]=0,["as"]=0},[771057]={["ap"]=0,["ad"]=0,["as"]=0},[771058]={["ap"]=80,["ad"]=0,["as"]=0},[771080]={["ap"]=0,["ad"]=0,["as"]=0},[771500]={["ap"]=0,["ad"]=0,["as"]=0},[772001]={["ap"]=0,["ad"]=0,["as"]=0},[772003]={["ap"]=0,["ad"]=0,["as"]=0},[772004]={["ap"]=0,["ad"]=0,["as"]=0},[772009]={["ap"]=0,["ad"]=0,["as"]=0},[772037]={["ap"]=0,["ad"]=0,["as"]=0},[772038]={["ap"]=0,["ad"]=0,["as"]=0},[772039]={["ap"]=0,["ad"]=0,["as"]=0},[772041]={["ap"]=0,["ad"]=0,["as"]=0},[772042]={["ap"]=0,["ad"]=0,["as"]=0},[772043]={["ap"]=0,["ad"]=0,["as"]=0},[772044]={["ap"]=0,["ad"]=0,["as"]=0},[772045]={["ap"]=0,["ad"]=0,["as"]=0},[772049]={["ap"]=0,["ad"]=0,["as"]=0},[772050]={["ap"]=0,["ad"]=0,["as"]=0},[773001]={["ap"]=70,["ad"]=0,["as"]=0},[773003]={["ap"]=60,["ad"]=0,["as"]=0},[773004]={["ap"]=0,["ad"]=20,["as"]=0},[773005]={["ap"]=0,["ad"]=0,["as"]=0},[773006]={["ap"]=0,["ad"]=0,["as"]=0.2},[773009]={["ap"]=0,["ad"]=0,["as"]=0},[773010]={["ap"]=0,["ad"]=0,["as"]=0},[773020]={["ap"]=0,["ad"]=0,["as"]=0},[773022]={["ap"]=0,["ad"]=30,["as"]=0},[773023]={["ap"]=40,["ad"]=0,["as"]=0},[773024]={["ap"]=0,["ad"]=0,["as"]=0},[773025]={["ap"]=30,["ad"]=0,["as"]=0},[773026]={["ap"]=0,["ad"]=0,["as"]=0},[773027]={["ap"]=60,["ad"]=0,["as"]=0},[773028]={["ap"]=0,["ad"]=0,["as"]=0},[773031]={["ap"]=0,["ad"]=70,["as"]=0},[773035]={["ap"]=0,["ad"]=40,["as"]=0},[773037]={["ap"]=0,["ad"]=0,["as"]=0},[773040]={["ap"]=60,["ad"]=0,["as"]=0},[773041]={["ap"]=20,["ad"]=0,["as"]=0},[773042]={["ap"]=0,["ad"]=20,["as"]=0},[773044]={["ap"]=0,["ad"]=20,["as"]=0},[773046]={["ap"]=0,["ad"]=0,["as"]=0.5},[773047]={["ap"]=0,["ad"]=0,["as"]=0},[773050]={["ap"]=0,["ad"]=0,["as"]=0},[773052]={["ap"]=0,["ad"]=0,["as"]=0},[773056]={["ap"]=50,["ad"]=0,["as"]=0},[773057]={["ap"]=25,["ad"]=0,["as"]=0},[773060]={["ap"]=40,["ad"]=0,["as"]=0},[773063]={["ap"]=0,["ad"]=0,["as"]=0},[773064]={["ap"]=0,["ad"]=0,["as"]=0},[773065]={["ap"]=0,["ad"]=0,["as"]=0},[773067]={["ap"]=0,["ad"]=0,["as"]=0},[773068]={["ap"]=0,["ad"]=0,["as"]=0},[773069]={["ap"]=0,["ad"]=0,["as"]=0},[773070]={["ap"]=0,["ad"]=0,["as"]=0},[773071]={["ap"]=0,["ad"]=50,["as"]=0},[773072]={["ap"]=0,["ad"]=70,["as"]=0},[773073]={["ap"]=0,["ad"]=0,["as"]=0},[773074]={["ap"]=0,["ad"]=75,["as"]=0},[773075]={["ap"]=0,["ad"]=0,["as"]=0},[773077]={["ap"]=0,["ad"]=40,["as"]=0},[773078]={["ap"]=30,["ad"]=30,["as"]=0.3},[773082]={["ap"]=0,["ad"]=0,["as"]=0},[773083]={["ap"]=0,["ad"]=0,["as"]=0},[773084]={["ap"]=0,["ad"]=0,["as"]=0},[773085]={["ap"]=0,["ad"]=0,["as"]=0.7},[773086]={["ap"]=0,["ad"]=0,["as"]=0.18},[773087]={["ap"]=0,["ad"]=0,["as"]=0.4},[773089]={["ap"]=120,["ad"]=0,["as"]=0},[773091]={["ap"]=0,["ad"]=0,["as"]=0.4},[773092]={["ap"]=45,["ad"]=0,["as"]=0},[773093]={["ap"]=0,["ad"]=0,["as"]=0},[773096]={["ap"]=0,["ad"]=0,["as"]=0},[773098]={["ap"]=25,["ad"]=0,["as"]=0},[773100]={["ap"]=80,["ad"]=0,["as"]=0},[773101]={["ap"]=0,["ad"]=0,["as"]=0.4},[773102]={["ap"]=0,["ad"]=0,["as"]=0},[773105]={["ap"]=0,["ad"]=0,["as"]=0},[773106]={["ap"]=0,["ad"]=0,["as"]=0},[773107]={["ap"]=0,["ad"]=0,["as"]=0},[773108]={["ap"]=30,["ad"]=0,["as"]=0},[773109]={["ap"]=0,["ad"]=40,["as"]=0.4},[773110]={["ap"]=0,["ad"]=0,["as"]=0},[773111]={["ap"]=0,["ad"]=0,["as"]=0},[773114]={["ap"]=25,["ad"]=0,["as"]=0.45},[773115]={["ap"]=65,["ad"]=0,["as"]=0.5},[773116]={["ap"]=80,["ad"]=0,["as"]=0},[773117]={["ap"]=0,["ad"]=0,["as"]=0},[773123]={["ap"]=0,["ad"]=25,["as"]=0},[773124]={["ap"]=40,["ad"]=30,["as"]=0},[773128]={["ap"]=120,["ad"]=0,["as"]=0},[773131]={["ap"]=0,["ad"]=0,["as"]=0},[773132]={["ap"]=0,["ad"]=0,["as"]=0},[773134]={["ap"]=0,["ad"]=25,["as"]=0},[773135]={["ap"]=70,["ad"]=0,["as"]=0},[773136]={["ap"]=25,["ad"]=0,["as"]=0},[773138]={["ap"]=0,["ad"]=0,["as"]=0},[773139]={["ap"]=0,["ad"]=60,["as"]=0},[773140]={["ap"]=0,["ad"]=0,["as"]=0},[773141]={["ap"]=0,["ad"]=10,["as"]=0},[773142]={["ap"]=0,["ad"]=30,["as"]=0},[773143]={["ap"]=0,["ad"]=0,["as"]=0},[773144]={["ap"]=0,["ad"]=25,["as"]=0},[773145]={["ap"]=40,["ad"]=0,["as"]=0},[773146]={["ap"]=65,["ad"]=45,["as"]=0},[773151]={["ap"]=50,["ad"]=0,["as"]=0},[773152]={["ap"]=50,["ad"]=0,["as"]=0},[773153]={["ap"]=0,["ad"]=25,["as"]=0.4},[773154]={["ap"]=0,["ad"]=0,["as"]=0.3},[773155]={["ap"]=0,["ad"]=25,["as"]=0},[773156]={["ap"]=0,["ad"]=60,["as"]=0},[773157]={["ap"]=120,["ad"]=0,["as"]=0},[773158]={["ap"]=0,["ad"]=0,["as"]=0},[773160]={["ap"]=0,["ad"]=0,["as"]=0.3},[773165]={["ap"]=75,["ad"]=0,["as"]=0},[773172]={["ap"]=0,["ad"]=25,["as"]=0.5},[773173]={["ap"]=0,["ad"]=0,["as"]=0},[773174]={["ap"]=60,["ad"]=0,["as"]=0},[773178]={["ap"]=0,["ad"]=0,["as"]=0.5},[773190]={["ap"]=0,["ad"]=0,["as"]=0},[773191]={["ap"]=20,["ad"]=0,["as"]=0},[773206]={["ap"]=40,["ad"]=0,["as"]=0},[773207]={["ap"]=0,["ad"]=0,["as"]=0},[773209]={["ap"]=0,["ad"]=35,["as"]=0},[773211]={["ap"]=0,["ad"]=0,["as"]=0},[773222]={["ap"]=0,["ad"]=0,["as"]=0},[773340]={["ap"]=0,["ad"]=0,["as"]=0},[773348]={["ap"]=0,["ad"]=0,["as"]=0},[773504]={["ap"]=40,["ad"]=0,["as"]=0},[8001]={["ap"]=0,["ad"]=0,["as"]=0},[8010]={["ap"]=65,["ad"]=0,["as"]=0},[8020]={["ap"]=0,["ad"]=0,["as"]=0}}

end
modules["tf.level"] = function(require)
local P=require('CombatProfiles.twisted_fate')
local ItemStats=require('tf.itemstats')
local L={};L.__index=L
function L.new(c)return setmetatable({c=c,bins={},lastSample=-1},L)end
function L:sample(mode,model)
    local now=math.floor(Game.Timer());if now==self.lastSample then return end;self.lastSample=now
    local slot=now%60+1
    local stats={ap=0,bonusDamage=0,totalDamage=self.c.hero.baseDamage or 0,attackSpeed=0}
    for _,item in pairs(self.c.state.inventory.slots)do
        local row=ItemStats[item.itemID]
        if not row then self.reason='unknown_permanent_item_stats';return end
        stats.ap=stats.ap+row.ap;stats.bonusDamage=stats.bonusDamage+row.ad;stats.attackSpeed=stats.attackSpeed+row['as']
    end
    stats.totalDamage=stats.totalDamage+stats.bonusDamage
    self.permanent=stats
    self.bins[slot]={at=now,attacks=model.attack and 3/math.max(.1,model.period) or 0,q=model.q and 1 or 0,
        control=(model.controlValue or 0)>0 and 1 or 0,mana=self.c.hero.mana/math.max(1,self.c.hero.maxMana),
        -- Base AD is permanent; transient AS/AP buffs never determine rank choice.
        baseAD=self.c.hero.baseDamage or 0}
end
function L.choose(p,ranks,level,history)
    if P.LegalRank(3,ranks[3],level)then return 3,'ultimate_rank'end
    if ranks[0]+ranks[1]+ranks[2]==0 then return 1,'first_card'end
    if not history or history.n==0 then return nil,'awaiting_representative_play'end
    local scores={};local stats=history.stats or {}
    for slot=0,2 do if P.LegalRank(slot,ranks[slot],level)then
        if slot==0 then scores[slot]=(P.Q(p,ranks[slot]+1,stats)-P.Q(p,ranks[slot],stats))*history.q
        elseif slot==1 then
            scores[slot]=(P.Card(p,'blue',ranks[slot]+1,stats)-P.Card(p,'blue',ranks[slot],stats))*history.attacks/4
                +history.control*25+math.max(0,1-history.mana)*25
        elseif p.eBase then
            scores[slot]=(P.E(p,ranks[slot]+1,stats)-P.E(p,ranks[slot],stats))*history.attacks/4
                +(P.Rank(p.eAS,ranks[slot]+1)-P.Rank(p.eAS,ranks[slot]))*history.baseAD*history.attacks
        else scores[slot]=(history.teleports or 0)*(ranks[slot]==0 and 100 or 15)end
    end end
    local best,value,second=nil,-1,-1
    for slot=0,2 do if scores[slot]then
        if scores[slot]>value then second=value;best=slot;value=scores[slot]else second=math.max(second,scores[slot])end
    end end
    if value<=0 or value-second<1 then return nil,'rank_utility_ambiguous'end
    return best,'observed_marginal_utility'
end
function L:tick()
    local c=self.c;local h=c.hero;local s=c.state
    if not c.config:get('level') or s.channeling or s:windupActive() or not h.levelData or (h.levelData.lvlPts or 0)<=0 then return end
    local r={};for slot=0,3 do r[slot]=h:GetSpellData(slot).level end
    local hist={n=0,q=0,attacks=0,control=0,mana=0,baseAD=0,teleports=0,stats=self.permanent}
    for _,at in ipairs(self.teleports or {})do if Game.Timer()-at<60 then hist.teleports=hist.teleports+1 end end
    for _,b in pairs(self.bins)do if Game.Timer()-b.at<60 then
        hist.n=hist.n+1;for _,k in ipairs({'q','attacks','control','mana','baseAD'})do hist[k]=hist[k]+b[k]end
    end end
    if hist.n>0 then for _,k in ipairs({'q','attacks','control','mana','baseAD'})do hist[k]=hist[k]/hist.n end end
    local slot,reason=L.choose(c.profile,r,h.levelData.lvl,hist);self.reason=reason
    if slot==nil then return end
    local rank=r[slot];local points=h.levelData.lvlPts
    c.actions:submit(slot,{owner='level',priority='background',type='chord',keys={HK_LUS or 17,({[0]=HK_Q,[1]=HK_W,[2]=HK_E,[3]=HK_R})[slot]},
        expires=c.actions.client:Now()+200,
        mechanical=function()
            return c.config:get('level') and h.levelData.lvlPts>0 and h:GetSpellData(slot).level==rank
                and P.LegalRank(slot,rank,h.levelData.lvl) and not s:channel() and not s:windupActive()
        end},function()return h:GetSpellData(slot).level>rank and h.levelData.lvlPts<points end)
end
return L

end
modules["tf.planner"] = function(require)
-- Pure bounded event simulation. No input, objects, clock or global callbacks.
-- Unknown item effects are omitted, never counted as confirmed kill damage.
local M={horizon=3,width=8,limit=256}
local function clone(s)
    local o={};for k,v in pairs(s)do if k~='events'then o[k]=v end end
    o.events={};for i,e in ipairs(s.events)do o.events[i]=e end;return o
end
local function damage(s,packet)
    s.expected=s.expected+(packet.expected or 0)
    for _,kind in ipairs({'physical','magical','trueDamage'})do
        local n=packet[kind] or 0;local key=kind=='physical' and 'physicalShield' or kind=='magical' and 'magicalShield'
        if key then local used=math.min(s[key],n);s[key]=s[key]-used;n=n-used end
        local used=math.min(s.shield,n);s.shield=s.shield-used;n=n-used
        s.hp=s.hp-n;if s.hp<=0 then return end
    end
end
local function advance(s,t,p)
    table.sort(s.events,function(a,b)return a.at<b.at end)
    while s.events[1] and s.events[1].at<=t and s.hp>0 do
        local e=table.remove(s.events,1)
        s.hp=math.min(p.hp,s.hp+p.regen*math.max(0,e.at-s.t));s.t=e.at
        if e.lock then
            s.card=e.lock;s.pendingCard=false
            if p.reset then s.nextAA=math.max(s.t,s.windupEnd)end
        else
            damage(s,e.packet)
            local control=math.min(e.control or 0,math.max(0,M.horizon-e.at))
            s.control=s.control+math.max(0,control-math.max(0,s.controlUntil-e.at))
            s.controlUntil=math.max(s.controlUntil,e.at+control)
            if e.mana then s.mana=math.min(p.maxMana,s.mana+e.mana)end
            if s.hp<=0 then s.killAt=e.at end
        end
    end
    if s.hp>0 then s.hp=math.min(p.hp,s.hp+p.regen*math.max(0,t-s.t));s.t=t end
end
local function first(s,kind,color)if not s.first then s.first=kind;s.color=color end end
local function score(s,p)
    local damageDone=p.hp-math.max(0,s.hp)
    if s.hp<=0 then return 100000-s.killAt*100-s.spent end
    return damageDone+math.min(s.hp,s.expected)+s.control*p.controlValue-s.spent*.12
end
function M.solve(p)
    p.regen=p.regen or 0;p.controlValue=p.controlValue or 0
    local start={t=0,hp=p.hp,shield=p.shield or 0,physicalShield=p.physicalShield or 0,magicalShield=p.magicalShield or 0,
        mana=p.mana,nextAA=p.nextAA or 0,windupEnd=0,card=p.card,e=p.e or 0,events={},spent=0,control=0,
        usedQ=false,usedW=p.card~=nil,attacks=0,expected=0,extraBits=0,controlUntil=0}
    for _,event in ipairs(p.incoming or {})do start.events[#start.events+1]=event end
    local beam={start};local best=clone(start);advance(best,M.horizon,p);best.score=score(best,p)
    local count=0
    -- Always include a complete legal AA-only baseline. Beam pruning must not
    -- win merely because it evaluated fewer future attacks on the other branch.
    local baseline=clone(start)
    while p.attack and baseline.hp>0 and count<64 do
        if baseline.attacks>0 and not p.repeatReachable then break end
        local at=math.max(baseline.t,baseline.nextAA)
        if at+p.windup+p.flight>M.horizon then break end
        if at>baseline.t then first(baseline,'wait');advance(baseline,at,p)end
        first(baseline,'attack');count=count+1
        baseline.events[#baseline.events+1]={at=at+p.windup+p.flight,
            packet=p.attack(baseline.card,baseline.e==3,baseline.attacks,baseline.hp),
            control=baseline.card=='gold' and p.stun or 0,mana=baseline.card=='blue' and p.blueMana or 0}
        baseline.card=nil;baseline.e=p.hasE and (baseline.e+1)%4 or 0
        baseline.attacks=baseline.attacks+1;baseline.nextAA=at+p.period
        baseline.windupEnd=at+p.windup;advance(baseline,baseline.windupEnd,p)
    end
    advance(baseline,M.horizon,p);baseline.score=score(baseline,p)
    if baseline.score>best.score then best=baseline end
    for depth=1,64 do
        local nextBeam={}
        for _,s in ipairs(beam)do
            if count>=M.limit then break end
            local function offer(n)
                if count>=M.limit then return end
                count=count+1
                local final=clone(n);advance(final,M.horizon,p);final.score=score(final,p)
                if final.score>best.score then best=final end
                n.bound=final.score;nextBeam[#nextBeam+1]=n
            end
            if s.hp>0 and s.t<M.horizon then
                if p.attack and s.t>=s.nextAA and (s.attacks==0 or p.repeatReachable)then
                    local n=clone(s);first(n,'attack')
                    local packet=p.attack(n.card,n.e==3,n.attacks,n.hp);local at=s.t+p.windup+p.flight
                    local control=n.card=='gold' and p.stun or 0
                    n.events[#n.events+1]={at=at,packet=packet,control=control,mana=n.card=='blue' and p.blueMana or 0}
                    n.card=nil;n.e=p.hasE and (n.e+1)%4 or 0;n.attacks=n.attacks+1
                    n.windupEnd=s.t+p.windup;n.nextAA=s.t+p.period
                    advance(n,n.windupEnd,p);offer(n)
                end
                if p.q and not s.usedQ and s.mana>=p.qCost+p.reserveQ and not s.pendingCard then
                    local n=clone(s);first(n,'q');n.usedQ=true;n.mana=n.mana-p.qCost;n.spent=n.spent+p.qCost
                    n.events[#n.events+1]={at=s.t+p.qImpact,packet=p.q}
                    advance(n,s.t+p.qCast,p);offer(n)
                end
                if p.cards and not s.usedW and s.mana>=p.wCost then
                    for _,row in ipairs(p.cards)do
                        local recovery=row.color=='blue' and math.min(p.blueMana,p.maxMana-(s.mana-p.wCost)) or 0
                        if s.mana-p.wCost+recovery>=p.reserveW then
                        local n=clone(s);first(n,'card',row.color);n.usedW=true;n.pendingCard=true
                        n.mana=n.mana-p.wCost;n.spent=n.spent+p.wCost
                        n.events[#n.events+1]={at=s.t+row.wait,lock=row.color}
                        advance(n,s.t+.001,p);offer(n)
                        end
                    end
                end
                for i,row in ipairs(p.extras or {})do
                    local flag=2^(i-1)
                    if math.floor(s.extraBits/flag)%2==0 and s.mana>=row.cost and s.t+row.delay<=M.horizon then
                        local n=clone(s)
                        if not n.first then first(n,'extra');n.extra=row.id end
                        n.extraBits=n.extraBits+flag;n.mana=n.mana-row.cost;n.spent=n.spent+row.cost+(row.opportunityCost or 0)
                        n.events[#n.events+1]={at=s.t+row.delay,packet=row.packet or {},control=row.control or 0}
                        advance(n,s.t+row.castTime,p);offer(n)
                    end
                end
                local at=s.nextAA>s.t and s.nextAA or M.horizon
                for _,e in ipairs(s.events)do if e.at>s.t then at=math.min(at,e.at)end end
                if at>s.t then local n=clone(s);first(n,'wait');advance(n,math.min(at,M.horizon),p);offer(n)end
            end
        end
        table.sort(nextBeam,function(a,b)return a.bound>b.bound end)
        beam={};for i=1,math.min(M.width,#nextBeam)do beam[i]=nextBeam[i]end
        if #beam==0 or count>=M.limit then break end
    end
    best.transitions=count;return best
end
return M

end
modules["tf.q"] = function(require)
local U=require('tf.util')
local Q={};Q.__index=Q
function Q.new(c)
    local self=setmetatable({c=c},Q)
    local g=GGPrediction;local p=c.profile.q
    if g then self.predict=g:SpellPrediction({Type=g.SPELLTYPE_LINE,Speed=p.speed,Range=p.range,Delay=p.delay,
        Radius=p.radius,Collision=true,CollisionTypes={g.COLLISION_YASUOWALL}})end
    return self
end
function Q.ray(origin,point,dx,dz,range,radius)
    local x,z=point.x-origin.x,point.z-origin.z;local along=x*dx+z*dz
    return along>=0 and along<=range and math.abs(x*dz-z*dx)<=radius
end
function Q:plan(target,list,batch)
    self.reason=nil
    if not self.predict then self.reason='prediction_unavailable';return nil end
    if not U.target(target) then self.reason='target_unavailable';return nil end
    local c=self.c;local p=c.profile.q;local h=c.hero
    local targetID=U.id(target)
    self.predict:GetPrediction(target,h)
    if not self.predict:CanHit(target.type==Obj_AI_Hero and GGPrediction.HITCHANCE_HIGH or GGPrediction.HITCHANCE_NORMAL)then self.reason='prediction_declined';return nil end
    local aim=self.predict.CastPosition
    if not aim or U.dist(h,aim)>p.range then self.reason='aim_out_of_range';return nil end
    local dx,dz=aim.x-h.pos.x,aim.z-h.pos.z;local length=math.sqrt(dx*dx+dz*dz)
    if length<1 then self.reason='aim_too_close';return nil end;dx=dx/length;dz=dz/length
    local best;local positions,collisions={},{}
    if batch then
        -- One synchronous farming decision may compare several primary aims.
        -- Secondary predictions are identical there. Never retain this cache
        -- across ticks, origin changes or object-list refreshes, and never put
        -- a primary aim in it: that aim belongs to its own spell prediction.
        local origin=h.pos;local now=Game.Timer()
        if batch.at~=now or batch.x~=origin.x or batch.z~=origin.z or batch.list~=list then
            batch.at=now;batch.x=origin.x;batch.z=origin.z;batch.list=list
            batch.positions={};batch.collisions={}
        end
        positions=batch.positions;collisions=batch.collisions
    end
    local primaryCollisions={}
    for _,rotation in ipairs({0,p.angle,-p.angle})do
        local ax=dx*math.cos(rotation)-dz*math.sin(rotation)
        local az=dx*math.sin(rotation)+dz*math.cos(rotation)
        -- Aim direction is sufficient; projecting the full missile range can
        -- unnecessarily put an otherwise visible target's cast point off screen.
        local point=U.point(h.pos.x+ax*length,h.pos.y,h.pos.z+az*length)
        local hits,seen={},{};local primary=false
        local rays={}
        for _,angle in ipairs({0,p.angle,-p.angle})do
            rays[#rays+1]={x=ax*math.cos(angle)-az*math.sin(angle),z=ax*math.sin(angle)+az*math.cos(angle)}
        end
        for _,u in ipairs(list or {target})do
            if #hits>=32 then break end
            if U.target(u) and u.team~=h.team and not seen[U.id(u)] then
                local id=U.id(u)
                local up=id==targetID and aim or positions[id]
                if up==nil then
                    local radius=u.boundingRadius or 0;local speed=u.ms
                    -- SharedData contains the whole map. A walking unit beyond
                    -- even its maximum travel budget cannot enter any Q ray.
                    -- Unknown movement and dashes retain regular prediction.
                    local tooFar=id~=targetID and speed and speed>=0
                        and U.dist(h,u)>p.range+p.radius+radius+speed*(p.delay+p.range/p.speed)
                    local path=tooFar and u.pathing
                    if tooFar and not(path and path.isDashing)then up=false
                    else up=id==targetID and aim or (u.GetPrediction and u:GetPrediction(p.speed,p.delay)) or u.pos end
                    positions[id]=up
                end
                if up then
                for _,ray in ipairs(rays)do
                    if Q.ray(h.pos,up,ray.x,ray.z,p.range,p.radius+(u.boundingRadius or 0)) then
                        local cache=id==targetID and primaryCollisions or collisions
                        local blocked=cache[id]
                        if blocked==nil then
                            blocked=GGPrediction:GetCollision({x=h.pos.x,z=h.pos.z},{x=up.x,z=up.z},p.speed,p.delay,p.radius,
                                {GGPrediction.COLLISION_YASUOWALL},id,{padding=0,trim=0})==true
                            cache[id]=blocked
                        end
                        if not blocked then hits[#hits+1]=u;seen[id]=true;if id==targetID then primary=true end end
                        break
                    end
                end
                end
            end
        end
        if primary and (not best or #hits>#best.hits)then
            best={point=point,hits=hits,impact=p.delay+length/p.speed,targetID=U.id(target)}
        end
    end
    self.reason=best and 'eligible' or 'primary_not_hit';return best
end
function Q:cast(target,mode,worth)
    local c=self.c;local id=U.id(target)
    if c.actions:busy(0)then return false,'q_pending' end
    if c.state:windupActive()then return false,'attack_windup' end
    local minion=target.type==Obj_AI_Minion
    local function targets()return minion and c.state.minions or c.state.heroes end
    local plan=self:plan(target,targets())
    if not plan then return false end
    return c.actions:submit(0,{owner='q',kind='world',target=plan.point,targetID=id,independent=true,freshReadyReplan=true,
        context=mode and {modes={mode}} or {condition=function()return c.config:get('autoHarass')end},
        ready=function()return not c.state:windupActive()end,
        resolve=function()
            local list=targets();local fresh=c.state:identity(id,list)
            if not fresh then return nil,'target_lost' end
            local nextPlan=self:plan(fresh,list)
            if not nextPlan then return nil,'prediction_declined' end
            return {position=nextPlan.point,data={targetID=id}}
        end,
        mechanical=function(resolved)
            local fresh=c.state:identity(id,targets())
            if not fresh then return false,'q_target_lost' end
            if not c.state:ready(0)then return false,'q_not_ready' end
            if c.state:windupActive()then return false,'attack_windup' end
            if c.state:channel()then return false,'manual_channel' end
            if U.lower(c.hero:GetSpellData(0).name)~=U.lower(c.profile.qName)then return false,'q_stage_changed' end
            local protection=c.state:protection(fresh)
            if protection.invulnerable or protection.spellShield then return false,'q_target_protected' end
            if not resolved then return false,'q_aim_missing' end
            if worth and not worth(fresh)then return false,'q_plan_changed' end
            return true
        end})
end
return Q

end
modules["tf.state"] = function(require)
local U=require('tf.util')
local P=require('CombatProfiles.twisted_fate')
local S={};S.__index=S
function S.new(c)return setmetatable({c=c,events={},serial=0,lastAttack=0,lastSpell='',previousStage='unknown'},S)end
function S:buff(unit,name)return self.c.sdk.BuffManager:GetBuff(unit,name)end
function S:channel()
    local h=self.c.hero;local a=h.activeSpell
    if self.c.sdk.IsRecalling(h) then return true,'recall',0 end
    if a and a.valid and U.lower(a.name)==U.lower(self.c.profile.gateName)
        and ((a.endTime or a.castEndTime or 0)>Game.Timer() or a.isChanneling)then
        return true,'gate',a.endTime or a.castEndTime or 0
    end
    return false,nil,0
end
function S:flight()
    local c=self.c;local now=Game.Timer();local attack=self.cardAttack
    if not attack or now-attack.seen>5 then self.cardFlight=nil;return end
    if not Game.MissileCount or now<(self.nextMissileScan or 0)then return end
    self.nextMissileScan=now+.04;local found
    for i=1,math.min(256,Game.MissileCount())do
        local missile=Game.Missile(i);local d=missile and missile.missileData
        if d and missile.pos then
            local owner=d.owner
            if type(owner)=='table' or type(owner)=='userdata'then owner=U.id(owner)end
            if owner==c.hero.networkID or owner==c.hero.handle then
                for color,name in pairs(c.profile.attacks)do
                    if U.lower(d.name or missile.name)==U.lower(name)then
                        local id=U.id(missile);local target=d.target
                        if type(target)=='table' or type(target)=='userdata'then target=U.id(target)end
                        found={id=id,target=target,color=color,missile=missile,speed=(d.speed or 0)>0 and d.speed or 1500}
                        if self.cardFlight and self.cardFlight.id==id then found.packet=self.cardFlight.packet
                        else
                            for _,list in ipairs({self.heroes,self.minions})do for _,u in ipairs(list)do
                                if u.networkID==target or u.handle==target then found.packet=c.combat:packet(u,color,attack.eReady);break end
                            end end
                            c:record('card_projectile_observed',{id=id,target=target,color=color})
                        end
                        break
                    end
                end
            end
        end
        if found then break end
    end
    if not found and self.cardFlight then
        c:record('card_projectile_disappeared',{id=self.cardFlight.id,target=self.cardFlight.target,effect='unknown'})
    end
    self.cardFlight=found
end
function S:refresh()
    local c=self.c;local h=c.hero;local now=Game.Timer();self.now=now
    self.mode,self.modeID=U.mode(c.sdk)
    self.spells={};for slot=0,5 do self.spells[slot]=h:GetSpellData(slot)end
    self.stage,self.color,self.cardExpiry=P.CardState(c.profile,self.spells[1].name,
        function(n)return self:buff(h,n)end,now)
    self.eReady=c.profile.eBuff and P.AliveBuff(self:buff(h,c.profile.eBuff),now) or false
    self.channeling,self.channelKind,self.channelEnd=self:channel()
    self.heroes={};self.minions={}
    for _,kind in ipairs({'heroes','minions'})do
        local row=c.sdk.SharedData:GetObjects(kind)
        if row then self[kind]=row.objects end
    end
    self.inventory=c.sdk.SharedData:GetInventory()
    local attack=c.sdk.SharedData:GetAttack().castEndTime or 0
    if attack>self.lastAttack and attack<=now+2 then
        self.lastAttack=attack;self.serial=self.serial+1
        if c.config:get('diagnostics')then
            local ad=h.attackData;local active=h.activeSpell
            local target=ad and ad.target or active and active.valid and active.target
            if type(target)=='table' or type(target)=='userdata'then target=U.id(target)end
            c:record('attack_observed',{castEnd=attack,target=target,mode=self.mode,
                card=self.color,eReady=self.eReady,serverStart=c.sdk.Attack.ServerStart,
                windup=c.sdk.Attack:GetWindup(),period=c.sdk.Attack:GetAnimation()})
        end
    end
    local a=h.activeSpell
    local spellToken=a and a.valid and (tostring(a.name)..':'..tostring(a.startTime or a.castEndTime)) or ''
    if spellToken~='' and spellToken~=self.lastSpell then
        self.lastSpell=spellToken;self.spellEvent={name=U.lower(a.name),at=now,serial=self.serial+1}
        self.serial=self.serial+1
        c:record('spell_observed',{name=a.name,start=a.startTime,castEnd=a.castEndTime,ending=a.endTime,channel=a.isChanneling,target=a.target})
        for color,name in pairs(c.profile.attacks)do
            if U.lower(a.name)==U.lower(name)then
                self.cardAttack={color=color,target=a.target,seen=now,castEnd=a.castEndTime or now,eReady=self.eReady}
                c:record('card_attack_observed',{color=color,target=a.target,castEnd=a.castEndTime})
            end
        end
    end
    if self.stage~=self.previousStage or self.color~=self.previousColor then
        self.cardEvent={stage=self.stage,color=self.color,at=now,serial=self.serial+1};self.serial=self.serial+1
        c:record('card_observed',{stage=self.stage,color=self.color,expiry=self.cardExpiry})
        if self.previousStage=='held' and self.stage~='held'then
            c:record('card_removed',{reason=(self.previousExpiry or 0)>0 and now>=self.previousExpiry and 'expired' or 'consumed_or_removed'})
        end
        self.previousStage=self.stage;self.previousColor=self.color
    end
    self.previousExpiry=self.cardExpiry
    self:flight()
end
function S:ready(slot,lock)
    local d=self.c.hero:GetSpellData(slot)
    return d and (slot>=4 or d.level>0) and Game.CanUseSpell(slot)==0 and (lock or self.c.hero.mana>=(d.mana or math.huge))
end
function S:cost(slot)local d=self.c.hero:GetSpellData(slot);return d and d.mana or math.huge end
function S:identity(id,list)
    for _,u in ipairs(list or self.heroes)do if U.id(u)==id and U.target(u)then return u end end
end
function S:protection(unit)
    local o={cc=0,spellShield=false,dodge=false,immune=false,invulnerable=false}
    U.buffs(unit,function(b)
        if P.AliveBuff(b,Game.Timer())then
            local n=U.lower(b.name);local remain=math.max(0,P.Expiry(b)-Game.Timer())
            if b.type==4 then o.spellShield=true end
            if b.type==5 or b.type==8 or b.type==12 or b.type==22 or b.type==23 or b.type==25 or b.type==29 or b.type==30 or b.type==35 then o.cc=math.max(o.cc,remain)end
            if b.type==18 or b.type==38 then o.invulnerable=true end
            if b.type==17 then o.dodge=true end
            if b.type==16 then o.immune=true end
            if n=='jaxcounterstrike' or n=='nilahw' or n=='shenwbuff' then o.dodge=true end
            if n=='olafragnarok' or n=='morganae' then o.immune=true end
            if n=='sivirshield' or n=='nocturneshroudofdarkness' then o.spellShield=true end
        end
    end)
    return o
end
function S:windupActive()return (self.c.sdk.Attack.CastEndTime or 0)>Game.Timer()end
function S:reserve(exclude)
    local h=self.c.hero;local reserve=0;local nearby=false
    for _,u in ipairs(self.heroes)do if u.team~=h.team and U.target(u) and U.dist(h,u)<1100 then nearby=true;break end end
    if nearby and exclude~=1 and (self.spells[1].level or 0)>0 then reserve=reserve+self:cost(1)end
    if (self.mode=='COMBO' or self.mode=='HARASS') and exclude~=0 and self.spells[0].level>0 then reserve=reserve+self:cost(0)end
    if self.channelKind=='gate' then
        if exclude~=1 then reserve=reserve+self:cost(1)end
        if exclude~=0 and self.spells[0].level>0 then reserve=reserve+self:cost(0)end
    end
    return math.min(h.maxMana or math.huge,reserve)
end
return S

end
modules["tf.util"] = function(require)
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

end
modules["CombatProfiles.twisted_fate"] = function(require)
-- Shared, input-free TF mechanics. Rank arrays start at rank ONE; rank zero is zero.
-- Source: research/twistedfate/manifest.json and spell-summary.json, 2026-09-20.
-- Installed assets are not a claim of server/live verification. Distances: world units;
-- durations: seconds; ratios: fractions. Costs/readiness come from live spell objects.
local M={revision='tf-mechanics-1', provenance={
    normal='2c65ae046e3924879008a1abb17563b00d292a06f84e75a191aa0c5009c8d0bf',
    classic='946645b5d7588a5e9a5fbe3626b1debf912cd3d302c9023b9cfc97de54d48461',
    scope='installed assets; patch and live behavior not independently established',
    reset='https://www.leagueoflegends.com/en-us/news/game-updates/patch-14-2-notes/'}}
local normal={id='normal',name='TwistedFate',qName='WildCards',wName='PickACard',
    eName='CardmasterStack',rName='Destiny',gateName='Gate',gateSlot=3,
    qBase={60,105,150,195,240},qAP=.85,qBonusAD=.5,
    q={range=1450,speed=1000,delay=.25,radius=40,angle=28*math.pi/180,
       geometryScope='range/speed/mMissileWidth=40: missile asset; delay/fan: historical scripts, pending measurement'},
    wAP={blue=1,red=.7,gold=.5},wMana={50,75,100,125,150},
    locks={blue='BlueCardLock',red='RedCardLock',gold='GoldCardLock'},
    held={blue='BlueCardPreAttack',red='RedCardPreAttack',gold='GoldCardPreAttack'},
    attacks={blue='BlueCardAttack',red='RedCardAttack',gold='GoldCardAttack'},
    eBuff='cardmasterstackparticle',eBase={65,90,115,140,165},eAP=.4,eBonusAD=.2,
    eAS={.15,.25,.35,.45,.55},towerE=.5,lockReset=true,
    channelW1=false,channelW2=false,liveVerified=false}
local classic={id='classic',name='Jade_TwistedFate',qName='Jade_TwistedFateWildCards',
    wName='Jade_TwistedFatePickACard',eName='Jade_TwistedFateE',rName='Jade_TwistedFateDestiny',
    gateName='Jade_TwistedFateE',gateSlot=2,qBase={60,110,160,210,260},qAP=.65,qBonusAD=0,
    q={range=1450,speed=1000,delay=.25,radius=40,angle=28*math.pi/180,
       geometryScope='range/speed/mMissileWidth=40: Classic missile asset; delay/fan: pending Classic measurement'},
    wAP={blue=.4,red=.4,gold=.4},wMana={50,75,100,125,150},
    locks={blue='Jade_TwistedFate_BlueCardLock',red='Jade_TwistedFate_RedCardLock',gold='Jade_TwistedFate_GoldCardLock'},
    held={blue='Jade_TwistedFate_BlueCardPreAttack',red='Jade_TwistedFate_RedCardPreAttack',gold='Jade_TwistedFate_GoldCardPreAttack'},
    attacks={blue='Jade_TwistedFate_BlueCardAttack',red='Jade_TwistedFate_RedCardAttack',gold='Jade_TwistedFate_GoldCardAttack'},
    gateDuration=3,gateWithR=1.5,rSlow=.30,rDuration={4,5,6},
    -- W2 during E is a guide hypothesis, never enabled by a menu or a timer.
    channelW1=false,channelW2=false,lockReset=false,autoRVerified=false,liveVerified=false}
M.profiles={TwistedFate=normal,Jade_TwistedFate=classic}
M.colors={'blue','red','gold'}
-- Normal base: Riot patch 26.1; Classic base/IE: pinned Riot item 773031 tooltip.
function M.CritMultiplier(p,items)
    local value=2
    for _,item in pairs(items or {})do
        if p.id=='normal' and item.itemID==3031 then value=2.3 end
        if p.id=='classic' and item.itemID==773031 then value=2.5 end
    end
    return value
end
-- Only explicit numeric effects from pinned Riot 16.17.1 item descriptions.
-- research/shop/en_US.json SHA256 cfc41c11dc27161a969469975386d386babc645278980bf3a06f251a541e881d
-- Missing tooltip placeholders and unobserved stacks are intentionally omitted.
M.itemRules={normal={
    [1043]={physical=15},[3124]={magical=30},
    [3042]={manaPhysical=.012,championsOnly=true},
    [3094]={magical=40,energized=true}},classic={
    [773091]={magical=42},[773153]={currentHealthPhysical=.05,minionCap=60}}}
function M.ItemAttack(p,stats,target,items,proc)
    local result={physical=0,magical=0,trueDamage=0};local seen={}
    for _,item in pairs(items or {})do
        local id=item.itemID;local row=M.itemRules[p.id][id]
        if row and not seen[id]then
            seen[id]=true
            if (not row.championsOnly or target.hero) and (not row.energized or proc and proc.energized)then
                local physical=(row.physical or 0)+(row.manaPhysical or 0)*(stats.maxMana or 0)
                if row.currentHealthPhysical then
                    local extra=(target.health or 0)*row.currentHealthPhysical
                    if target.minion then extra=math.min(extra,row.minionCap)end
                    physical=physical+extra
                end
                result.physical=result.physical+physical;result.magical=result.magical+(row.magical or 0)
            end
        end
    end
    return result
end
local base={blue={40,60,80,100,120},red={30,45,60,75,90},gold={15,22.5,30,37.5,45}}
local crit={blue=.575,red=.35,gold=.25}
function M.Profile(name) return M.profiles[name] end
function M.Rank(values,rank) return values and values[rank or 0] or 0 end
function M.Q(p,rank,stats)
    if not p or rank<1 or rank>5 then return 0 end
    return M.Rank(p.qBase,rank)+p.qAP*(stats.ap or 0)+p.qBonusAD*(stats.bonusDamage or 0)
end
-- Full replacement attack damage, NOT an addition to the physical base attack.
function M.Card(p,color,rank,stats)
    if not p or not base[color] or rank<1 or rank>5 then return 0 end
    return (base[color][rank]+(stats.totalDamage or 0)+p.wAP[color]*(stats.ap or 0))
        *(1+crit[color]*math.max(0,math.min(1,stats.critChance or 0)))
end
function M.E(p,rank,stats,tower)
    if not p or not p.eBase or rank<1 or rank>5 then return 0 end
    return (p.eBase[rank]+p.eAP*(stats.ap or 0)+p.eBonusAD*(stats.bonusDamage or 0))*(tower and p.towerE or 1)
end
function M.Expiry(buff)
    if not buff then return 0 end
    local at=buff.expireTime
    if not at or at<=0 then at=buff.endTime end
    return at or 0
end
function M.AliveBuff(buff,at)
    if not buff or buff.valid==false or (buff.count or 0)<=0 then return false end
    local expiry=M.Expiry(buff)
    return expiry==0 or expiry>at
end
function M.CardState(p,spellName,getBuff,at)
    for _,color in ipairs(M.colors)do
        local b=getBuff(p.held[color])
        if M.AliveBuff(b,at) then return 'held',color,M.Expiry(b) end
    end
    local name=string.lower(spellName or '')
    for _,color in ipairs(M.colors)do
        if name==string.lower(p.locks[color]) then return 'selecting',color,0 end
    end
    if name==string.lower(p.wName) then return 'idle',nil,0 end
    return 'unknown',nil,0
end
function M.Attack(p,stats,wrank,erank,color,eReady,tower,critMultiplier)
    local physical,magical=stats.totalDamage or 0,0
    if color and wrank>0 then physical=0;magical=M.Card(p,color,wrank,stats) end
    if not color and (stats.critChance or 0)>=1 then physical=physical*(critMultiplier or 2)end
    if eReady then magical=magical+M.E(p,erank,stats,tower) end
    return {physical=physical,magical=magical,trueDamage=0}
end
function M.BlueRecovery(p,rank,mana,maxMana)
    return math.max(0,math.min(M.Rank(p.wMana,rank),(maxMana or 0)-(mana or 0)))
end
function M.Stun(rank) return rank>0 and (.75+.25*rank) or 0 end
function M.LegalRank(slot,rank,level)
    if slot==3 then return rank<3 and level>=({6,11,16})[rank+1] end
    return rank<5 and level>=rank*2+1
end
return M

end
local function load(name)
 if cache[name]~=nil then return cache[name] end
 local factory=modules[name];if not factory then return externalRequire(name) end
 local value=factory(load);cache[name]=value;return value
end
local app
local ok,err=pcall(function()app=load("tf.app").new();app:initialize();app.fingerprint=fingerprint;app:install()end)
if not ok then if app then app:Shutdown()end;print("[CardMarx] Load failed: "..tostring(err));return end
_G.OrbamaTwistedFate=app
return app

end,6)
