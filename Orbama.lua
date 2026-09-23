-- Release 1
local client=_G.OrbamaReleaseClient
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
return function(env,hash,builtin,origin)
    local names={'Orbama','LeeHarveyOsward'}
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
    local function path(slot,name)return base..'runtime-'..slot..'-'..name end
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
        local version,a,asize,acrc,b,bsize,bcrc=text:match('^R1\n(%d+)\nOrbama (%x+) (%d+) (%d+)\nLeeHarveyOsward (%x+) (%d+) (%d+)\n$')
        version=tonumber(version);asize=tonumber(asize);bsize=tonumber(bsize);acrc=tonumber(acrc);bcrc=tonumber(bcrc)
        if not version or version<1 or version>999999999 or #a~=64 or #b~=64
            or asize<1 or bsize<1 or asize>4000000 or bsize>4000000
            or acrc>4294967295 or bcrc>4294967295 then return end
        return {version=version,text=text,Orbama={hash=a,size=asize,checksum=acrc},LeeHarveyOsward={hash=b,size=bsize,checksum=bcrc}}
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
        request(origin..'/main/release/manifest',function(text)
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
                request(origin..'/main/release/'..manifest.version..'/'..name..'.lua',function(body)
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
client=create(_G,hash,1,"https://raw.githubusercontent.com/LeeHarveyOsward/runtime-files")
_G.OrbamaReleaseClient=client
end
return client:Boot("Orbama",function()
-- GENERATED LUA-FIRST ORBAMA; tools/build_orbama_lua.py
local __version__ = 3.075
local __name__ = "Orbama"

if _G.SDK and _G.SDK.OrbamaVersion then return _G.SDK end
if _G.SDK or _G.GGUpdate then
    print('[Orbama] Another SDK is active; reload the complete script runtime.')
    return
end

_G.GGUpdate = (function()
-- Compatible asynchronous helper. A callback, never elapsed time or a stale file,
-- authorizes reading a download. Replacement is staged and rollback-capable.
local U={Callbacks={},ActivePaths={},serial=0}
function U:__init() self.Callbacks={} end
function U:Trim(s) return (s:gsub('^%s+',''):gsub('%s+$','')) end
function U:ReadFile(path)
    local rows={};local f=io.open(path,'r');if not f then return rows end
    for line in f:lines() do local s=self:Trim(line);if #s>0 then rows[#rows+1]=s end end
    f:close();return rows
end
function U:DownloadFile(url,path,done)
    local ok,err=pcall(DownloadFileAsync,url,path,function(...) if done then done(...) end end)
    return ok,err
end
local function number(s)
    if type(s)~='string' or not s:match('^%d+%.?%d*$') then return end
    local n=tonumber(s);if n and n>=0 and n<math.huge then return n end
end
local function replace(stage,path)
    local previous=stage..'.previous'
    local file=io.open(path,'rb');local exists=file~=nil;if file then file:close() end
    if exists then
        -- Do not destroy an earlier backup when its ownership is unknown.
        local old=io.open(previous,'rb')
        if old then old:close();return false,'backup already exists' end
        local ok,err=os.rename(path,previous);if not ok then return false,err end
    end
    local ok,err=os.rename(stage,path)
    if not ok and exists then os.rename(previous,path) end
    return ok,err
end
function U:New(args)
    self.serial=self.serial+1
    local job={Step=1,Version=tonumber(args.version),VersionUrl=args.versionUrl,VersionPath=args.versionPath,
        ScriptUrl=args.scriptUrl,ScriptPath=args.scriptPath,ScriptName=args.scriptName,
        suffix='.orbama-stage-'..tostring(GetTickCount())..'-'..self.serial}
    function job:finish()
        self.Step=0
        if self.ScriptPath and U.ActivePaths[self.ScriptPath]==self then U.ActivePaths[self.ScriptPath]=nil end
    end
    function job:fail(reason) self.Error=tostring(reason);self:finish() end
    function job:download(url,path,nextStep)
        self.Waiting=true;self.Deadline=GetTickCount()+30000
        local token={};self.Token=token
        local ok,err=U:DownloadFile(url,path,function(success)
            if self.Step==0 or self.Token~=token then return end
            if success==false then self:fail('download callback reported failure');return end
            self.Waiting=false;self.Step=nextStep
        end)
        if not ok then self:fail(err) end
    end
    function job:DownloadVersion()
        if not self.Version or self.Version<0 or self.Version>=math.huge
            or not self.VersionUrl or not self.VersionPath or not self.ScriptPath or not self.ScriptUrl then
            self:fail('invalid update arguments');return
        end
        self.StageVersion=self.VersionPath..self.suffix
        self.StageScript=self.ScriptPath..self.suffix
        self:download(self.VersionUrl,self.StageVersion,2)
    end
    function job:CanUpdate() return self.NewVersion~=nil and self.NewVersion>self.Version end
    function job:OnTick()
        if self.Step==0 then return end
        if self.Waiting then
            if GetTickCount()>self.Deadline then self:fail('download timeout; late callback ignored') end
            return
        end
        if self.Step==2 then
            local rows=U:ReadFile(self.StageVersion)
            self.NewVersion=#rows==1 and number(rows[1]) or nil
            if not self.NewVersion then self:fail('invalid version data');return end
            local f=io.open(self.ScriptPath,'rb');local exists=f~=nil;if f then f:close() end
            if self:CanUpdate() or not exists then
                self.Step=3;self:download(self.ScriptUrl,self.StageScript,4)
            else self:finish() end
        elseif self.Step==4 then
            local f=io.open(self.StageScript,'rb');local content=f and f:read('*a');if f then f:close() end
            if not content or #content==0 or not loadstring(content) then self:fail('incomplete or invalid Lua download');return end
            local ok,err=replace(self.StageScript,self.ScriptPath)
            if not ok then self:fail(err);return end
            self:finish();self.Completed=true
            print(tostring(self.ScriptName)..' - downloaded and validated; reload to activate.')
        end
    end
    if job.ScriptPath and self.ActivePaths[job.ScriptPath] then job:fail('update already pending for this path');return job end
    if job.ScriptPath then self.ActivePaths[job.ScriptPath]=job end
    job:DownloadVersion();self.Callbacks[#self.Callbacks+1]=job;return job
end
function U:OnTick() for _,job in ipairs(self.Callbacks) do job:OnTick() end end
return U

end)()
Callback.Add("Tick", function() GGUpdate:OnTick() end)
-- Self-overwrite intentionally disabled.

--#region headers

local math_huge = math.huge
local math_pi = math.pi
local math_ceil = assert(math.ceil)
local math_min = assert(math.min)
local math_max = assert(math.max)
local math_atan = assert(math.atan)
local math_random = assert(math.random)

local table_sort = assert(table.sort)
local table_remove = assert(table.remove)
local table_insert = assert(table.insert)

local myHero = myHero
local os = os
local math = math
local Game = Game
local Vector = Vector
local Control = Control
local Draw = Draw
local pairs = pairs
local NativeTickCount=GetTickCount
local tickLast=NativeTickCount();local tickMonotonic=tickLast
local function GetTickCount()
    local value=NativeTickCount();local elapsed=value-tickLast
    if elapsed< -2147483648 then elapsed=elapsed+4294967296 end
    tickLast=value;tickMonotonic=tickMonotonic+math.max(0,elapsed);return tickMonotonic
end

local GameTimer = Game.Timer
local GameMapID = Game.mapID
local GameIsOnTop = Game.IsOnTop
local GameIsChatOpen = Game.IsChatOpen
local GameCanUseSpell = Game.CanUseSpell
local GameMissile = Game.Missile
local GameMissileCount = Game.MissileCount
local GameGetObjectByNetID = Game.GetObjectByNetID
local GameWard = Game.Ward
local GameHero = Game.Hero
local GameObject = Game.Object
local GameTurret = Game.Turret
local GameMinion = Game.Minion
local GameWardCount = Game.WardCount
local GameHeroCount = Game.HeroCount
local GameObjectCount = Game.ObjectCount
local GameTurretCount = Game.TurretCount
local GameMinionCount = Game.MinionCount

--#endregion

--#region methods

local function IsInRange(p1, p2, range)
	p2 = p2 or myHero
	p1 = p1.pos or p1
	p2 = p2.pos or p2
	local dx = p1.x - p2.x
	local dy = (p1.z or p1.y) - (p2.z or p2.y)
	return dx * dx + dy * dy <= range * range
end

local function GetDistance(p1, p2)
	p2 = p2 or myHero
	p1 = p1.pos or p1
	p2 = p2.pos or p2
	local dx = p1.x - p2.x
	local dy = (p1.z or p1.y) - (p2.z or p2.y)
	return math.sqrt(dx * dx + dy * dy)
end

local function ClearArray(t)
	for i = #t, 1, -1 do
		t[i] = nil
	end
end

local function ClearMap(t)
	for k in pairs(t) do
		t[k] = nil
	end
end

local function Polar(v1)
	local x = v1.x
	local z = v1.z or v1.y
	if x == 0 then
		if z > 0 then
			return 90
		end
		return z < 0 and 270 or 0
	end
	local theta = math_atan(z / x) * (180.0 / math_pi)
	if x < 0 then
		theta = theta + 180
	end
	if theta < 0 then
		theta = theta + 360
	end
	return theta
end

local function AngleBetween(vec1, vec2)
	local theta = Polar(vec1) - Polar(vec2)
	if theta < 0 then
		theta = theta + 360
	end
	if theta > 180 then
		theta = 360 - theta
	end
	return theta
end

local function IsFacing(source, target, angle)
	angle = angle or 90
	target = target.pos or Vector(target)
	return AngleBetween(source.dir, target - source.pos) < angle
end

local function Base64Decode(data)
	local b = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
	data = string.gsub(data, "[^" .. b .. "=]", "")
	return (
		data:gsub(".", function(x)
			if x == "=" then
				return ""
			end
			local r, f = "", (b:find(x) - 1)
			for i = 6, 1, -1 do
				r = r .. (f % 2 ^ i - f % 2 ^ (i - 1) > 0 and "1" or "0")
			end
			return r
		end):gsub("%d%d%d?%d?%d?%d?%d?%d?", function(x)
			if #x ~= 8 then
				return ""
			end
			local c = 0
			for i = 1, 8 do
				c = c + (x:sub(i, i) == "1" and 2 ^ (8 - i) or 0)
			end
			return string.char(c)
		end)
	)
end

local function WriteToFile(path, str)
	path = SPRITE_PATH .. path
	if FileExist(path) then
		return
	end
	local output = io.open(path, "wb")
	output:write(Base64Decode(str))
	output:close()
end

local function GetControlPos(a, b, c)
	local pos
	if a and b and c then
		pos = { x = a, y = b, z = c }
	elseif a and b then
		pos = { x = a, y = b }
	elseif a then
		pos = a.pos or a
	end
	return pos
end

local function CastKey(key)
	if key == MOUSEEVENTF_RIGHTDOWN then
		Control.mouse_event(MOUSEEVENTF_RIGHTDOWN)
		Control.mouse_event(MOUSEEVENTF_RIGHTUP)
	else
		Control.KeyDown(key)
		Control.KeyUp(key)
	end
end

local function GetBuffTypes(menu)
	--[[enum class BuffType {
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
	return {
		[11] = menu.Slow:Value(),
		[5] = menu.Stun:Value(),
		[12] = menu.Snare:Value(),
		[9] = menu.Berserk:Value(),
		[25] = menu.Supress:Value(),
		--[30] = menu.Knockup:Value(),
		[29] = menu.Flee:Value(),
		[23] = menu.Charm:Value(),
		[8] = menu.Taunt:Value(),
		--[31] = menu.Knockback:Value(),
		[26] = menu.Blind:Value(),
		[32] = menu.Disarm:Value(),
		[34] = menu.Drowsy:Value(),
		[35] = menu.Asleep:Value(),
	}
end

--#endregion

local ChampionInfo, FlashHelper, Cached, Menu, Color, Action, Buff, Damage, Data, Spell, SummonerSpell, Item, Object, Target, Orbwalker, Movement, Cursor, Health, Attack, EvadeSupport

local DAMAGE_TYPE_PHYSICAL = 0
local DAMAGE_TYPE_MAGICAL = 1
local DAMAGE_TYPE_TRUE = 2

local ORBWALKER_MODE_NONE = -1
local ORBWALKER_MODE_COMBO = 0
local ORBWALKER_MODE_HARASS = 1
local ORBWALKER_MODE_LANECLEAR = 2
local ORBWALKER_MODE_JUNGLECLEAR = 3
local ORBWALKER_MODE_LASTHIT = 4
local ORBWALKER_MODE_FLEE = 5

local SORT_AUTO = 1
local SORT_CLOSEST = 2
local SORT_NEAR_MOUSE = 3
local SORT_LOWEST_HEALTH = 4
local SORT_LOWEST_MAX_HEALTH = 5
local SORT_HIGHEST_PRIORITY = 6
local SORT_MOST_STACK = 7
local SORT_MOST_AD = 8
local SORT_MOST_AP = 9
local SORT_LESS_CAST = 10
local SORT_LESS_ATTACK = 11

local ItemSlots = { ITEM_1, ITEM_2, ITEM_3, ITEM_4, ITEM_5, ITEM_6, ITEM_7 }
local ItemKeys = { HK_ITEM_1, HK_ITEM_2, HK_ITEM_3, HK_ITEM_4, HK_ITEM_5, HK_ITEM_6, HK_ITEM_7 }

local LastChatOpenTimer = 0

ChampionInfo = {

	GwenMistObject = nil,
	GwenMistPos = nil,
	GwenMistEndTime = 0,

	AzirSoldiers = {},

	OnLoad = function(self) end,

	DrawObjects = function(self)
		local text = {}
		local mePos = myHero.pos
		for i = 1, Game.ObjectCount() do
			local obj = Game.Object(i)
			if obj then
				local pos = obj.pos
				if pos and GetDistance(mePos, pos) < 1300 then
					Draw.Circle(pos, 10)
					local pos2D = pos:To2D()
					local contains = false
					for j = 1, #text do
						local t = text[j]
						if GetDistance(pos2D, t[1]) < 50 then
							contains = true
							t[2] = t[2] .. tostring(obj.handle) .. " " .. obj.name .. "\n"
							break
						end
					end
					if not contains then
						table.insert(text, { pos2D, tostring(obj.handle) .. " " .. obj.name .. "\n" })
					end
				end
			end
		end
		for i = 1, #text do
			Draw.Text(text[i][2], text[i][1])
		end
	end,

	DrawObject = function(self, obj)
		local text = {}
		local mePos = myHero.pos
		if obj then
			local pos = obj.pos
			if pos and GetDistance(mePos, pos) < 1300 then
				Draw.Circle(pos, 10)
				local pos2D = pos:To2D()
				local contains = false
				for j = 1, #text do
					local t = text[j]
					if GetDistance(pos2D, t[1]) < 50 then
						contains = true
						t[2] = t[2] .. tostring(obj.handle) .. " " .. obj.name .. "\n"
						break
					end
				end
				if not contains then
					table.insert(text, { pos2D, tostring(obj.handle) .. " " .. obj.name .. "\n" })
				end
			end
		end
		for i = 1, #text do
			Draw.Text(text[i][2], text[i][1])
		end
	end,

	GwenDebug = function(self)
		local enemy = nil
		local enemies = Object:GetEnemyHeroes()
		for i = 1, #enemies do
			if GetDistance(enemies[i].pos, myHero.pos) < 1000 then
				enemy = enemies[i]
				break
			end
		end
		if Buff:HasBuff(myHero, "gwenwuntargetabilitymanager") then
			if not self:IsGwenMistValid() then
				self:DetectGwenMist(myHero)
			end
			self:DrawObject(self.GwenMistObject)
			--print(GetDistance(enemy.pos, self.GwenMistObject.pos))
			--self:DrawObjects()
		elseif enemy then
			--print(GetDistance(enemy.pos, myHero.pos))
		end
		if enemy then
			--print("Gwen is targetable to dummyTarget?: " .. tostring(self:CustomIsTargetable(myHero, enemy)))
		end
	end,

	OnTick = function(self)
		--self:GwenDebug()
		if Object.IsAzir then
			self:DetectAzirSoldiers()
		end
	end,

	CustomIsTargetable = function(self, enemy, ally)
		ally = ally or myHero
				if  Buff:HasBuff(enemy, "gwenwuntargetabilitymanager") then
					if not self:IsGwenMistValid() then
						self:DetectGwenMist(enemy)
					end
					--print(GetDistance(self.GwenMistObject.pos, ally.pos))
					if self.GwenMistObject and
					GetDistance(self.GwenMistObject.pos,
					ally.pos) >= 425 then
						return false
					end
				end
		return true
	end,

	IsGwenMistValid = function(self)
		if os.clock() >= self.GwenMistEndTime then
			self.GwenMistObject = nil
			self.GwenMistPos = nil
		end
		if self.GwenMistObject then
			local name = self.GwenMistObject.name
			if name and name:find("_W_MistArea") then
				local pos = self.GwenMistObject.pos
				if pos and GetDistance(self.GwenMistPos, pos) < 1200 then
					return true
				end
			end
		end
		return false
	end,

	DetectGwenMist = function(self, unit)
		local unitPos = unit.pos
		local count = Game.ObjectCount()
		if count and count > 0 and count < 100000 then
			for i = 1, count do
				local o = Game.Object(i)
				if o then
					local pos = o.pos
					if pos and GetDistance(unitPos, pos) < 600 then
						local name = o.name
						if name and name:find("_W_MistArea") then
							self.GwenMistObject = o
							self.GwenMistPos = o.pos
							self.GwenMistEndTime = os.clock()
								+ Buff:GetBuffDuration(unit, "gwenwuntargetabilitymanager")
							break
						end
					end
				end
			end
		end
	end,

	DetectAzirSoldiers = function(self)
		for i = #self.AzirSoldiers, 1, -1 do
			local soldier = self.AzirSoldiers[i]
			if soldier and (soldier.health == 0 or soldier.name ~= "AzirSoldier") then
				table_remove(self.AzirSoldiers, i)
			end
		end
		local activeSpell = myHero.activeSpell
		if activeSpell and activeSpell.valid then
			if activeSpell.name == "AzirWSpawnSoldier" then
				for i = 1, GameObjectCount() do
					local obj = GameObject(i)
					if obj and GetDistance(myHero.pos, obj.pos) <= 1000 and obj.name == "AzirSoldier" then
						local exists = false
						for j = 1, #self.AzirSoldiers do
							if self.AzirSoldiers[j].handle == obj.handle then
								exists = true
								break
							end
						end
						if not exists then
							table_insert(self.AzirSoldiers, obj)
						end
					end
				end
			end
		end
	end,

	IsInAzirSoldierRange = function(self, obj)
		local result = false
		local commandRange = 780
		if(myHero.range == 575) then -- Lethal Tempo grants 50 attack range. Hacky fix.
			commandRange = 830
		end
		for i = 1, #self.AzirSoldiers do
			local soldier = self.AzirSoldiers[i]
			if
				soldier
				and soldier.name == "AzirSoldier"
				and soldier.health > 0
				and GetDistance(soldier, myHero) < commandRange
				and GetDistance(soldier, obj) < 350
			then
				result = true
			end
		end
		return result
	end,
}

local CommunityMenuMigration=(function()
-- Startup-only setting migration. Never edits the host's shared save file.
local M={saved={},icons={}}
-- Host save files are data, not executable modules. In particular, do not use
-- setfenv/loadfile here: restricted hosts may reject environment mutation.
function M:ParseSaveContent(text)
    if type(text)~='string' or #text>2097152 then return nil,'save_size' end
    local i,nodes=1,0
    if text:sub(1,3)=='\239\187\191' then i=4 end
    local function space()
        while true do
            local _,last=text:find('^%s*',i);i=(last or i-1)+1
            if text:sub(i,i+1)~='--' then return end
            if text:sub(i+2,i+3)=='[[' then
                local close=text:find(']]',i+4,true);assert(close,'unfinished comment');i=close+2
            else local close=text:find('\n',i+2,true);i=close and close+1 or #text+1 end
        end
    end
    local function take(token)space();assert(text:sub(i,i+#token-1)==token,'invalid save token');i=i+#token end
    local function quoted()
        local quote=text:sub(i,i);i=i+1;local out={}
        while i<=#text do
            local char=text:sub(i,i);i=i+1
            if char==quote then return table.concat(out) end
            if char=='\\' then
                char=text:sub(i,i);i=i+1
                local escapes={a='\a',b='\b',f='\f',n='\n',r='\r',t='\t',v='\v',['\\']='\\',['"']='"',["'"]="'"}
                if char:match('%d') then
                    local digits=char
                    for _=1,2 do local nextChar=text:sub(i,i);if not nextChar:match('%d')then break end;digits=digits..nextChar;i=i+1 end
                    local byte=tonumber(digits);assert(byte<=255,'invalid escape');char=string.char(byte)
                else char=assert(escapes[char],'unsupported escape') end
            end
            out[#out+1]=char
        end
        error('unfinished string')
    end
    local value
    value=function(depth)
        nodes=nodes+1;assert(depth<=32 and nodes<=100000,'save_complexity');space()
        local char=text:sub(i,i)
        if char=='{' then
            i=i+1;local result={};space()
            while text:sub(i,i)~='}' do
                take('[');local key=value(depth+1)
                assert(type(key)=='string' or type(key)=='number','invalid save key')
                take(']');take('=');result[key]=value(depth+1);space()
                if text:sub(i,i)==',' or text:sub(i,i)==';'then i=i+1;space()
                else assert(text:sub(i,i)=='}','missing separator') end
            end
            i=i+1;return result
        elseif char=='"' or char=="'" then return quoted()
        elseif text:sub(i,i+3)=='true' then i=i+4;return true
        elseif text:sub(i,i+4)=='false' then i=i+5;return false
        elseif text:sub(i,i+2)=='nil' then i=i+3;return nil
        end
        local literal=text:match('^[+-]?%d+%.?%d*[eE][+-]?%d+',i) or text:match('^[+-]?%d+%.?%d*',i)
        local number=literal and tonumber(literal)
        assert(number and number==number and math.abs(number)~=math.huge,'invalid save value')
        i=i+#literal;return number
    end
    local ok,result=pcall(function()take('return');local result=value(0);space();assert(i>#text and type(result)=='table','invalid save root');return result end)
    if ok then return result end
    return nil,tostring(result)
end
do
    local base=COMMON_PATH or (SCRIPT_PATH and SCRIPT_PATH..'Common/')
    if base and io and type(io.open)=='function' then
        if not base:match('[/\\]$') then base=base..'/' end
        local ok,file=pcall(io.open,base..'MenuElement.save','rb')
        if ok and file then
            local read,text=pcall(file.read,file,2097153);pcall(file.close,file)
            if read then
                local value,reason=M:ParseSaveContent(text)
                if value then M.saved=value;M.status='loaded_data' else M.status=reason end
            else M.status='read_failed' end
        else M.status='unavailable' end
    end
end
local function at(t,path)
    for part in path:gmatch('[^.]+') do t=type(t)=='table' and t[part] or nil end
    return t
end
function M:Apply(args,root,oldPath,newPath)
    local saved=self.saved[root] or {};local current=at(saved,newPath)
    local previous=at(saved,oldPath)
    local field=args.key~=nil and '__key' or '__active'
    local expected=args.key~=nil and 'number' or type(args.value)
    local value
    if type(current)=='table' then value=current[field] end
    if type(value)~=expected then
        value=nil
        if type(previous)=='table' then value=previous[field] end
    end
    if type(value)==expected then
        if field=='__key' then args.key=value else args.value=value end
    end
    return args
end
function M:Icon(path,fallback)
    if self.icons[path]~=nil then return self.icons[path] or nil end
    local selected
    for _,candidate in ipairs({path,fallback}) do
        local base=SPRITE_PATH
        if base and FileExist then
            if not base:match('[/\\]$') then base=base..'/' end
            local ok,exists=pcall(FileExist,base..'MenuElement'..candidate)
            if ok and exists then selected=candidate;break end
        end
    end
    self.icons[path]=selected or false;return selected
end
local drawingModes={{'Combo','Combo','COMBO'},{'Harass','Harass','HARASS'},
    {'LaneClear','Lane clear','LANECLEAR'},{'JungleClear','Jungle clear','JUNGLECLEAR'},
    {'LastHit','Last hit','LASTHIT'},{'Flee','Flee','FLEE'}}
function M:Drawing(parent,args,root,oldPath,newPath)
    local id=args.id
    self:Apply(args,root,oldPath,oldPath)
    parent:MenuElement({id=id..'Display',name=args.name,type=MENU,leftIcon=args.leftIcon})
    local menu=parent[id..'Display'];local nodes={}
    local function add(key,label,value)
        local option={id=key,name=label,value=value}
        self:Apply(option,root,newPath..'.'..key,newPath..'.'..key)
        menu:MenuElement(option);nodes[key]=menu[key]
    end
    add('Enabled','Enabled',args.value)
    add('Always','Always',true)
    for _,mode in ipairs(drawingModes) do add(mode[1],mode[2],false) end
    local facade={args=args,menu=menu}
    function facade:Value(value)
        if value~=nil then nodes.Enabled:Value(value);return value end
        if not nodes.Enabled:Value() then return false end
        if nodes.Always:Value() then return true end
        local sdk=_G.SDK;local active=sdk and sdk.Orbwalker and sdk.Orbwalker.Modes
        if active then for _,mode in ipairs(drawingModes) do
            local index=sdk['ORBWALKER_MODE_'..mode[3]]
            if index and active[index] and nodes[mode[1]]:Value() then return true end
        end end
        return false
    end
    parent[id]=facade;return facade
end
function M:Orbama()
    local root;local paths={};local actual={};local groups={}
    local definitions={{'Controls','Controls','/Gamsteron_Loader.png'},
        {'Target','Targeting','/Gamsteron_TargetSelector.png'},
        {'Orbwalker','Attack & Movement','/Gamsteron_Orbwalker.png'},
        {'Automation','Automation','/Gamsteron_Spell_SummonerDot.png'},
        {'Plugins','Plugins and priorities','/Gamsteron_Spell_SummonerHaste.png'},
        {'Drawings','Appearance','/Gamsteron_Drawings.png'}}
    local hidden={SetCursorMultipleTimes=true,GeneralSpace=true,VersionSpaceA=true,VersionSpaceB=true}
    local function valueNode(args)
        local value=args.value;local key=args.key
        return {Value=function(_,v)if v~=nil then value=v end;return value end,
            Key=function(_,v)if v~=nil then key=v end;return key end,args=args}
    end
    local iconsByParent={}
    local function uniqueIcon(parent,args)
        if not args.leftIcon then return end
        local used=iconsByParent[parent] or {};iconsByParent[parent]=used
        if used[args.leftIcon] then args.leftIcon=nil else used[args.leftIcon]=true end
    end
    return function(parent,args)
        if not root then
            root=parent;paths[root]='';actual[root]=''
            for _,d in ipairs(definitions) do
                local args={id=d[1],name=d[2],type=MENU,leftIcon=self:Icon(d[3])}
                uniqueIcon(root,args);root:MenuElement(args)
                groups[d[1]]=root[d[1]];actual[root[d[1]]]=d[1];paths[root[d[1]]]=d[1]
            end
            groups.Plugins:MenuElement({id='DefaultLimit',name='Default priority limit',value=4,
                drop={'Background','Normal','Interactive','Critical'}})
        end
        local old=paths[parent];if old==nil then uniqueIcon(parent,args);parent:MenuElement(args);return parent[args.id] end
        local oldPath=old=='' and args.id or old..'.'..args.id
        if old=='Drawings' and args.id~='Enabled' and type(args.value)=='boolean' then
            return self:Drawing(parent,args,'GGOrbwalker',oldPath,'Drawings.'..args.id..'Display')
        end
        if parent==root and groups[args.id] then return groups[args.id] end
        if old=='' and hidden[args.id] then local node=valueNode(args);parent[args.id]=node;return node end
        local destination=parent
        if old=='' and (args.id=='Loader' or args.id=='Items' or args.id=='SummonerSpells' or args.id=='PMenuFH') then destination=groups.Automation
        elseif old=='' and args.id=='AttackTKey' then destination=groups.Controls
        elseif old=='' and (args.id=='Latency' or args.id=='CursorDelay' or args.id=='Humanizer') then destination=groups.Orbwalker
        elseif old=='Orbwalker' and args.id=='Keys' then
            parent.Keys=groups.Controls;paths[groups.Controls]='Orbwalker.Keys';return groups.Controls
        end
        local newPath=actual[destination]..'.'..args.id
        self:Apply(args,'GGOrbwalker',oldPath,newPath)
        uniqueIcon(destination,args)
        destination:MenuElement(args);local node=destination[args.id]
        parent[args.id]=node;paths[node]=oldPath;actual[node]=newPath
        return node
    end
end
return M

end)()
local CommunityMenuElement=CommunityMenuMigration:Orbama()
FlashHelper = {

	Timer = 0,
	FlashSpell = 0,
	Flash = nil,
	FlashSpellNames = {
		["SummonerFlash"] = true,
		["SummonerFlash_Jade"] = true,
		["SummonerCherryFlash"] = true,
		["Augment_ARAM_FlashySpell"] = true,
	},

	CreateMenu = function(self, main)
        -- stylua: ignore start
        self.Menu = CommunityMenuElement(main,{type = MENU, id = "PMenuFH", name = "Flash Helper", leftIcon = "/Gamsteron_Spell_SummonerFlash.png"})
        self.Menu:MenuElement({id = "Enabled", name = "Enabled", value = false})
        self.Menu:MenuElement({id = "CustomBinding", name = "Enable custom Flash key remapping", value = false})
        self.Menu:MenuElement({id = "Flashlol", name = "Flash LOL HotKey", key = string.byte("P")})
        self.Menu:MenuElement({id = "Flashgos", name = "Flash GOS HotKey", key = string.byte("F")})
		-- stylua: ignore end
	end,

	OnTick = function(self)
		if
			self.Menu.Flashgos:Value()
            and self.Menu.CustomBinding:Value()
            and self.Menu.Flashgos:Key() ~= self.Menu.Flashlol:Key()
			and self.Menu.Enabled:Value()
			and self:IsReady()
			and not myHero.dead
			and not GameIsChatOpen()
			and GameIsOnTop()
		then
			-- print("Flash Helper | Flashing!")
			Control.Flash()
		end
	end,

	IsReady = function(self)
		local sd1 = myHero:GetSpellData(SUMMONER_1)
		local sd2 = myHero:GetSpellData(SUMMONER_2)
		local has_flash = false
		if self.FlashSpellNames[sd1.name] then
			self.FlashSpell = SUMMONER_1
			has_flash = true
		end
		if self.FlashSpellNames[sd2.name] then
			self.FlashSpell = SUMMONER_2
			has_flash = true
		end
		if not has_flash then
			return false
		end
		if GetTickCount() < LastChatOpenTimer + 1000 then
			return
		end
		local flashData = self.FlashSpell == SUMMONER_1 and sd1 or sd2
		if flashData.currentCd > 0 or flashData.name == "SummonerCherryFlash_CD" then
			return false
		end
		if GameCanUseSpell(self.FlashSpell) ~= 0 then
			return false
		end
		if GetTickCount() < self.Timer + 100 then
			return false
		end
		return true
	end,
}

_G.Control.Flash = function()
    -- An explicit programmatic request uses the current Flash summoner slot.
    -- A custom output key requires separate, deliberate remapping opt-in.
    if not FlashHelper:IsReady() or not Cursor:Available() or Cursor.Step ~= 0 or Cursor.Active then return false end
    local key = FlashHelper.FlashSpell == SUMMONER_1 and HK_SUMMONER_1 or HK_SUMMONER_2
    if FlashHelper.Menu.CustomBinding:Value() then key = FlashHelper.Menu.Flashlol:Key() end
    local accepted = Cursor:Add(key, myHero.pos:Extended(Vector(Cursor:GetPlayerPosition()), 600))
    if accepted then FlashHelper.Timer = GetTickCount() end
    return accepted
end

Cached = {

	OtherMinionOwners = {
		["apheliosturret"] = "aphelios",
		["fiddlestickseffigy"] = "fiddlesticks",
		["gangplankbarrel"] = "gangplank",
		["heimertyellow"] = "heimerdinger",
		["heimertblue"] = "heimerdinger",
		["illaoiminion"] = "illaoi",
		["jhintrap"] = "jhin",
		["kalistaspawn"] = "kalista",
		["nidaleespear"] = "nidalee",
		["teemomushroom"] = "teemo",
		["yorickwinvisible"] = "yorick",
		["zyragraspingplant"] = "zyra",
		["zyrathornplant"] = "zyra",
		["jade_heimerdingerturret"] = "jade_heimerdinger",
		["jade_nidaleespear"] = "jade_nidalee",
		["jade_teemomushroom"] = "jade_teemo"
	},

	FruitMinionsByMap = {
		[11] = {
			["sru_plant_health"] = true,
			["sru_plant_satchel"] = true,
			["sru_plant_vision"] = true
		},
		[12] = {
			["cherry_plant_powerup"] = true
		},
		[30] = {
			["sru_plant_satchel"] = true,
			["cherry_plant_powerup"] = true,
			["cherry_ancestralwoods_interactable"] = true,
			["cherry_destructible_column"] = true,
			["cherry_petricitegrove_interactable"] = true
		}
	},

	EnabledOtherMinions = {},
	EnemyChampionNames = {},
	HasFeeneypult = false,

	Minions = {},
	TempCachedMinions = {},
	TempCachedWards = {},
	TempCachedTurrets = {},
	TempCachedPlants = {},
	TempBuildingPlants = {},
	TempBuildingPlantHandles = {},
	PlantScanActive = false,
	PlantScanIndex = 1,
	PlantScanCount = 0,
	PlantScanSlices = 30,
	PlantScanAttackPlants = false,
	PlantScanAttackBarrel = false,
	ExtraHeroes = {},
	ExtraUnits = {},
	Turrets = {},
	Wards = {},
	Plants = {},
	Heroes = {},
	Buffs = {},
	HeroesSaved = false,
	MinionsSaved = false,
	ExtraHeroesSaved = false,
	ExtraUnitsSaved = false,
	TurretsSaved = false,
	WardsSaved = false,
	PlantsSaved = false,
	TempCacheBuffer = {m = 0, w = 0, t = 0, p = 0},
	TempCacheTimeout = {m = 1, w = 3, t = 3, p = 1},

	WndMsg = function(self, msg, wParam)
		if msg ~= KEY_DOWN then
			return
		end
		local menuKeys = Orbwalker.MenuKeys
		if menuKeys == nil then
			return
		end
		--If we press an orbwalker hotkey, reset our buffer so we immediately cache new minions (we only do this once per button press to prevent lag)
		if
			wParam == menuKeys[ORBWALKER_MODE_COMBO][1]:Key()
			or wParam == menuKeys[ORBWALKER_MODE_FLEE][1]:Key()
			or wParam == menuKeys[ORBWALKER_MODE_HARASS][1]:Key()
			or wParam == menuKeys[ORBWALKER_MODE_LANECLEAR][1]:Key()
			or wParam == menuKeys[ORBWALKER_MODE_JUNGLECLEAR][1]:Key()
			or wParam == menuKeys[ORBWALKER_MODE_LASTHIT][1]:Key()
		then
			local buffer = self.TempCacheBuffer
			buffer.m = 0
			buffer.w = 0
			buffer.t = 0
			buffer.p = 0
		end
	end,

	Reset = function(self)
		for k in pairs(self.Buffs) do
			self.Buffs[k] = nil
		end
		if self.HeroesSaved then
			self.Heroes = {}
			self.HeroesSaved = false
		end
		if self.MinionsSaved then
			self.Minions = {}
			self.MinionsSaved = false
		end
		if self.ExtraHeroesSaved then
			for i = #self.ExtraHeroes, 1, -1 do
				local u = self.ExtraHeroes[i]
				if not (u and u.valid and u.visible and u.isTargetable and not u.dead and not u.isImmortal) then
					table_remove(self.ExtraHeroes, i)
				end
			end
			self.ExtraHeroesSaved = false
		end
		if self.ExtraUnitsSaved then
			for i = #self.ExtraUnits, 1, -1 do
				local u = self.ExtraUnits[i]
				if not (u and u.valid and u.visible and u.isTargetable and not u.dead and not u.isImmortal) then
					table_remove(self.ExtraUnits, i)
				end
			end
			self.ExtraUnitsSaved = false
		end
		if self.TurretsSaved then
			self.Turrets = {}
			self.TurretsSaved = false
		end
		if self.WardsSaved then
			self.Wards = {}
			self.WardsSaved = false
		end
		if self.PlantsSaved then
			self.Plants = {}
			self.PlantsSaved = false
		end
	end,

	Buff = function(self, b)
		local class = {}
		local members = {}
		local metatable = {}
		local _b = b
        members.lowerName = (b.name or ""):lower()
		function metatable.__index(s, k)
			if members[k] == nil then
				if k == "duration" then
					members[k] = _b.duration
				elseif k == "count" then
					members[k] = _b.count
				elseif k == "stacks" then
					members[k] = _b.stacks
				else
					members[k] = _b[k]
				end
			end
			return members[k]
		end
		setmetatable(class, metatable)
		return class
	end,

	GetHeroes = function(self)
		if not self.HeroesSaved then
			self.HeroesSaved = true
			self.ExtraHeroesSaved = true
			local count = GameHeroCount()
			if count and count > 0 and count < 1000 then
				for i = 1, count do
					local o = GameHero(i)
					if o and o.valid and o.visible and o.isTargetable and not o.dead then
						table_insert(self.Heroes, o)
					end
				end
			end

			for i = 1, #self.ExtraHeroes do
				local e = self.ExtraHeroes[i]
				table_insert(self.Heroes, e)
			end
		end
		return self.Heroes
	end,

	AddCachedHero = function(self, unit)
		for _, u in pairs(self.ExtraHeroes) do
			if(u.networkID == unit.networkID) then
				return false
			end
		end

		table_insert(self.ExtraHeroes, unit)
	end,

	AddCachedMinion = function(self, unit)
		
		for _, u in pairs(self.ExtraUnits) do
			if(u.networkID == unit.networkID) then
			--	print("AddCachedMinion",Game.Timer())
				return false
			end
		end
		for _, u in pairs(self.Minions) do
			if(u.networkID == unit.networkID) then
			--	print("alreadyinminionlist",Game.Timer())
				return false
			end
		end

		table_insert(self.ExtraUnits, unit)
	end,

	GetMinions = function(self)
		if not self.MinionsSaved then
			self.MinionsSaved = true
			self.ExtraUnitsSaved = true
			local cachedMinions = self:FetchCachedMinions()
			local count = #cachedMinions
			if count and count > 0 and count < 1000 then
				for i = 1, count do
					local o = cachedMinions[i]
					if o and o.valid and o.visible and o.isTargetable and not o.dead and not o.isImmortal then
						table_insert(self.Minions, o)
					end
				end
			end

			for i = 1, #self.ExtraUnits do
				local e = self.ExtraUnits[i]
				table_insert(self.Minions, e)
			end
		end
		return self.Minions
	end,

	FetchCachedMinions = function(self)
        local timer, count = GameTimer(), GameMinionCount()
        if self.DiscoveryCounts == nil then self.DiscoveryCounts = {} end
        if self.DiscoveryCounts.m ~= count or self.TempCacheBuffer.m <= timer then
            self.DiscoveryCounts.m = count
            ClearArray(self.TempCachedMinions)
            if count and count > 0 and count < 1000 then
                for i=1,count do
                    local o=GameMinion(i)
                    if o and o.valid and not o.dead then table_insert(self.TempCachedMinions, o) end
                end
            end
            self.TempCacheBuffer.m = timer + .20
        end
        return self.TempCachedMinions
    end,

	GetTurrets = function(self)
		if not self.TurretsSaved then
			self.TurretsSaved = true
			local cachedTurrets = self:FetchCachedTurrets()
			local count = #cachedTurrets
			if count and count > 0 and count < 1000 then
				for i = 1, count do
					local o = cachedTurrets[i]
					if o and o.valid and o.visible and o.isTargetable and not o.dead and not o.isImmortal then
						table_insert(self.Turrets, o)
					end
				end
			end
		end
		return self.Turrets
	end,

	FetchCachedTurrets = function(self)
        local timer, count = GameTimer(), GameTurretCount()
        if self.DiscoveryCounts == nil then self.DiscoveryCounts = {} end
        if self.DiscoveryCounts.t ~= count or self.TempCacheBuffer.t <= timer then
            self.DiscoveryCounts.t = count
            ClearArray(self.TempCachedTurrets)
            if count and count > 0 and count < 1000 then
                for i=1,count do
                    local o=GameTurret(i)
                    if o and o.valid and not o.dead then table_insert(self.TempCachedTurrets, o) end
                end
            end
            self.TempCacheBuffer.t = timer + .50
        end
        return self.TempCachedTurrets
    end,

	GetWards = function(self)
		if not self.WardsSaved then
			self.WardsSaved = true
			local cachedWards = self:FetchCachedWards()
			local count = #cachedWards
			if count and count > 0 and count < 1000 then
				for i = 1, count do
					local o = cachedWards[i]
					if o and o.valid and o.visible and o.isTargetable and not o.dead and not o.isImmortal then
						table_insert(self.Wards, o)
					end
				end
			end
		end
		return self.Wards
	end,

	FetchCachedWards = function(self)
        local timer, count = GameTimer(), GameWardCount()
        if self.DiscoveryCounts == nil then self.DiscoveryCounts = {} end
        if self.DiscoveryCounts.w ~= count or self.TempCacheBuffer.w <= timer then
            self.DiscoveryCounts.w = count
            ClearArray(self.TempCachedWards)
            if count and count > 0 and count < 1000 then
                for i=1,count do
                    local o=GameWard(i)
                    if o and o.valid and not o.dead then table_insert(self.TempCachedWards, o) end
                end
            end
            self.TempCacheBuffer.w = timer + .10
        end
        return self.TempCachedWards
    end,
	
	GetPlants = function(self)
		if not self.PlantsSaved then
			self.PlantsSaved = true
			local cachedPlants = self:FetchCachedPlants()
			local count = #cachedPlants
			if count and count > 0 and count < 1000 then
				for i = 1, count do
					local o = cachedPlants[i]
					if o and o.valid and o.visible and o.isTargetable and not o.dead and not o.isImmortal then
						table_insert(self.Plants, o)
					end
				end
			end
		end
		return self.Plants
	end,

	RefreshEnabledOtherMinions = function(self, attackPlants, attackBarrel)
		local enabled = self.EnabledOtherMinions
		ClearMap(enabled)

		if myHero.charName == "Senna" then
			enabled["sennasoul"] = true
		end

		if attackPlants then
			local fruitMinions = self.FruitMinionsByMap[GameMapID]
			if fruitMinions and (GameMapID ~= 12 or self.HasFeeneypult) then
				for charName in pairs(fruitMinions) do
					enabled[charName] = true
				end
			end
		end

		if GameMapID == 30 and Object and Object.HeroesInGame then
			ClearMap(self.EnemyChampionNames)
			for _, hero in pairs(Object.HeroesInGame) do
				local heroName = hero and hero.charName
				if hero and hero.valid and hero.isEnemy and heroName then
					self.EnemyChampionNames[heroName:lower()] = true
				end
			end
		end

		for charName, ownerName in pairs(self.OtherMinionOwners) do
			if self.EnemyChampionNames[ownerName] and (charName ~= "gangplankbarrel" or attackBarrel) then
				enabled[charName] = true
			end
		end
	end,

	FetchCachedPlants = function(self)
		local timer = GameTimer()
		local attackPlants = Menu.Orbwalker.General.AttackPlants:Value()
		local attackBarrel = Menu.Orbwalker.General.AttackBarrel:Value()
		if self.PlantScanAttackPlants ~= attackPlants or self.PlantScanAttackBarrel ~= attackBarrel then
			self.PlantScanAttackPlants = attackPlants
			self.PlantScanAttackBarrel = attackBarrel
			self.PlantScanActive = false
			self.PlantScanIndex = 1
			self.PlantScanCount = 0
			self.TempCacheBuffer.p = 0
			ClearArray(self.TempCachedPlants)
			ClearArray(self.TempBuildingPlants)
			ClearMap(self.TempBuildingPlantHandles)
		end

		if not self.PlantScanActive and self.TempCacheBuffer.p <= timer then
			self:RefreshEnabledOtherMinions(attackPlants, attackBarrel)
			if next(self.EnabledOtherMinions) == nil then
				ClearArray(self.TempCachedPlants)
				self.TempCacheBuffer.p = timer + self.TempCacheTimeout.p
			else
				local count = GameObjectCount()
				if count and count > 0 and count < 100000 then
					self.PlantScanActive = true
					self.PlantScanIndex = 1
					self.PlantScanCount = count
					ClearArray(self.TempBuildingPlants)
					ClearMap(self.TempBuildingPlantHandles)
				else
					self.TempCacheBuffer.p = timer + self.TempCacheTimeout.p
				end
			end
		end

		if self.PlantScanActive then
			local count = self.PlantScanCount
			local startIndex = self.PlantScanIndex
			local scanBudget = math_max(1, math_ceil(count / self.PlantScanSlices))
			local endIndex = math_min(count, startIndex + scanBudget - 1)
			local buildingPlants = self.TempBuildingPlants
			local buildingHandles = self.TempBuildingPlantHandles

			for i = startIndex, endIndex do
				local o = GameObject(i)
				if o and o.type == Obj_AI_Minion and o.valid then
					local rawName = o.charName
					local charName = rawName and rawName:lower() or nil
					if
						charName
						and self.EnabledOtherMinions[charName]
						and o.isEnemy
						and o.visible
						and o.isTargetable
						and not o.dead
						and not o.isImmortal
						and (charName ~= "apheliosturret" or o.isTargetableToTeam)
					then
						local id = o.networkID or o.handle
						if id == nil or not buildingHandles[id] then
							if id ~= nil then
								buildingHandles[id] = true
							end
							table_insert(buildingPlants, o)
						end
					end
				end
			end

			if endIndex >= count then
				self.PlantScanActive = false
				self.PlantScanIndex = 1
				self.PlantScanCount = 0
				self.TempCachedPlants, self.TempBuildingPlants = self.TempBuildingPlants, self.TempCachedPlants
				self.TempCacheBuffer.p = timer + self.TempCacheTimeout.p
			else
				self.PlantScanIndex = endIndex + 1
			end
		end

		return self.TempCachedPlants
	end,

	GetBuffs = function(self, o)
		local id = o.networkID
		if self.Buffs[id] == nil then
			local count = o.buffCount
			if count and count >= 0 and count < 10000 then
				local b = nil
				local buffs = {}
				for i = 0, count do
					b = o:GetBuff(i)
					local buffCount = b and b.count
					if buffCount and buffCount > 0 then
						table_insert(buffs, self:Buff(b))
					end
				end
				self.Buffs[id] = buffs
			end
		end
		return self.Buffs[id] or {}
	end,
}

-- stylua: ignore start
WriteToFile('MenuElement/Gamsteron_Drawings.png', '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')
WriteToFile('MenuElement/Gamsteron_Item_3139.png', 'iVBORw0KGgoAAAANSUhEUgAAAEAAAABACAIAAAAlC+aJAAAACXBIWXMAAAsTAAALEwEAmpwYAAAYBklEQVRogY2af3Qb5ZnvP9ZIyshjC8lyZAs7AiXGwambYCc0jddpwMWbNCFQktLl0NKzu3R76IWbLSwn7L3LaW9ZeneXhbKHwx66lPQHBxbO7iFAQkxSB0Ma6sTBcUgqIqw4lnEs5AyRpcgaeyJ5lPvHjGbkH0nvc3R0Zt55Z+bzfd5fz/u+U3bb8yIAOMtJnSF6JJccKwAOB6blLyNV2iS3ILkFSdL8IUFPn1ZUM4+aB1i2zLZpo9MlWum9H4nhEzl5vABgp2O11LFa6lgjedisZxgbDv72JTkhXxj4JArU1YSA+jpP37ERBA1ITCjjKQUI1Xk6vrI0Fk+p0+lcLqdpGmCnxJLnNJ0e0DQjURAAlMmCMlkgnieLf0QD/NcLlX6ubp+dQ05ogL/WZmiYZ/HhIMgJOQkEFvt0+rF4Wr86h15PzOVygCAIgN1ZTm4K/T85pi34jjkmjxT0f7HWSKm9Du+1C+T88CjSIvy1RonJFwo9x5WO1dL8nIkvkiY9EC8KMJ7vlXT6WDylo2tFB9tzU0YmZQLT/aYJwsIa/Nfb/NcLlf584HqAxIhRhUrt8JGF7y21seFgPHbdQPhVM6W+3nu0L2aoKrq/tcFv0uumCxAEwe50AjBDPJwjC54iepn1GnHGOg7czI6HWbuuAAWxWAEH047+s0LsFAUYr6CpQhw6o0WH8kBllZHHFyjkKgGQUAG+A0SHTw6cfTmWiIeCQSAUDKYSFmg6r4kVYuN1/tY1TQPhyPSUka7lNaFM0C5rFGa3gT9pf/2U47tbLVdfUG36QVIVvDV4O0mdNy4NDWnAsgZbZgpAcAoA2bnF1HPwZM97J83TUPC6w78/rR+fHRtHFBuv89/xtebBz+Tp6Wk9XVVVocyqGJYAebhASc8zx1o6bS2dQmunABZEtVgwNYBFD5wdsmqjTi84Z91bSq+7v6N9fWz0s6GxRGmeO77WbHKLoqiqVv+my7AX6TVgQQH5SQQRnX6gWzt4hh2PWFerxQKAJ3fsgtNbY2gYOmN1Bobvi9Z2o9WCew6W+j4IxEZHDf1j48Cj93UAg5/Jg5/JUhkLml2XoGmoaRyidUEoelbw8JdPOgrQ/572ix/kPev4vzuNS2ZPcaK78OobGrDtn6VpuHgx76nNA8lsQbRbPgtVEBRb6uzttazveu1014E+oHn5MpvgbfvKqsHoWGI07yx3AeoMf/2tjtpAoK9/IPnFeHU5tjIRKJtRXXZyl0sF/Cmrazak/OL7eeBfdi6Qp3svkffyQORgruk251Wetrahfe0N64HX395vJi5vrAP2vnPMcMfpWMuKUOuKUF//QDwxric6F7mUTGre8xYSINhmndZ92aoDD7zk6Gyf2xC793Jwr/GkyMF8023OhqXS2ZhyFfrn3v2n8KACNC9fBixvrN/zTl8p/f3f6gBM+qvYLAFz0IG6Zlv9lwUKmk6/5s65DXGO6eXQsFQC/4H35NJLW27m3ub/pR/3DX3YvPxb+vE9d246GR2LRuNmTp1+4HRszsPzl1TmmV0+o/mbhOQZzejUy0D3+AyA0463gss+gO+vzM+h782KwGBOQ8yTBVi3VWytFtu4v20p9WcTQJouIFizLri4TVWbgJf/43Xv8XttvgDQsDSA6Dpw+BPnNRJwqC/8jz+6u21d6xtv708nE5IoAoqqSqLosIPDpb/Xls+VCIho/qZiJdFbegHmFcVVrHWjcOJ32ondc0fxjs4AIJ//O/00WNOmqpzsD586HtZTGpYGGpYG9h8c0E8P9YV/vOOe7Xd2vvH2/sjgUOmjJFHMzSzgfua2AeGK9K01VwuTWv5cEPNO4NEXjZG8pzvR05148qnWYE1bac6Tx8PAytXN6oyzYWlgaDhxNpbQ6Tesbd7w1ebTnw7Ne/wVzWkX7PKnBTlSAqfTz/amTv9gt3j/ylxHTQGIpW09I85AQzHDRmHLnZ7SW3QBbS37Hn1qV/vKvwNGz/eefr9Zp0evPDA0bNH/+G/vAeb4Xq8/kujKZa0ScNqF3IxW4XJmp3N27Ix9lHdVgh1bGYXLhgy1AKCVIy7BdU3huR/Rd0C9+Vk6vgnwzI8LXe+qjTfbtj5ldJqJ6vHmsmBzWbDZFtz95nTv4cTd324eHJTfeNb7ccNJoKGh0R8IxuPjQF1dbWBJqK8vPJnNx2Lj624K/dM//CVwMjzkrXIPDg3rNcOGANjsglgh6m1MNzUPCKIoDo1l7EB6HECsQMsBRQ0l1refvgMAazcBPLSDrncBot2FvTtzpgbTBj+Vgb17wo3L/csa6oCGhrqGG+rd7oCeob4u0NcX7jsW7jsWBp554kGdfu6LAXBXWIO36HSouTzgr5LkCUVOKUYbULMAgg1NKymHEgGmdb1r0C9ozbYgMDhodKDRQXnSa3VcratD9XWB+roA8O8vvq3T73jonjn0vipvMpUGJrNKZYVkChCds0IdeULBbMRqFrHCuDC/BHRbuxHgoR1XpNctXBiNDl6xxev0b7zZZdKvXdvcd+Sj0jzVVd7kRCqZStfV+nX6THbWsGi6HzMWQm+9iygUc4oiQO4SsTMol2AGqY5d/wozUA7FWYQK+nC5ffi+tq+5x+E3TyrpdDRYX6c/J3B9AAgEQ4H6Bp2+92j41f/qBTasb/nmlvYPDg+4K6TURFLPH4uPAs5FZYFab/pCKp0udvk252VbPj2peCol7I74+YS3QmR+KOFwkL/CUCsPF49K6nxw3dw5W+/vJ016/WDZ0mUNSxusDEfDOv1P/vf9pTeaGgbPGGNwjdfo2WLnEotcFUCozg9EhsbMuwwBDjtOOzjI52ZpGP/E6lANAWY9tEbDUvqMpa2+7rol9eVuSafX/5/+t9d7+8KATv/B4QGTPp1KQrHoIToU+2TmMhCqD4SWBKZzBcDrlobH5PRFq0bNKwEn+dlkibBVoeVhcBdPpgius5kl0PY19xwBC8g7Gtbpd7/2ZGn68FAUCC1rjJ2NDp6JRYdi0aEYgF0EYmPjHdB0w9JURklllPTkrPZgd9jJF6e8gg3BRkFAEFCtebCQdeapRs5AdcmtHnJNBWHEWFrxNG8Devf9DBC8ztoav7/G7/F6PV5fJqO03rQc1F0vvu51sePh+8QKMXVhHKAwCfiCQeDA73oO/K7HU+EFaqsDm7c0dXyjY/fu3t27e3uORmw2we9zy8mMMpmlJKwwSkDX4HSSW6hieOsZOTY3sbKazqYg0B0ZfWp7O/DBB5GruH/Xb/cAOx6+b+26VX1HTqYmxoG1a1f19Z3U0c2cz7+wbcvtTQD2Fdu3t7lc2wA5uUDZ3vb1dVYb0M3pnNuIU+c01+IFgNzV6PRA54ogKk/8dLd+qbbGH6ixFr1ab1o+8PHgiZPRDV9dCTz385eB1MXxtV9ZBTz3/MsnPjWU//zpJ//qfpHZ9sorj373u08v6JSn/vlRu2N2KzALwaxC6XOaazGeOtLxWTndiw36P+n+gY8Hf/Xy3pZVjbrv9USd/jv3GbHqxj/vePYZvWH0zrl9+/a23bvben8f0auQmX7b19cB9gIIdoPYZQdwushdMubHeRW0gmhHcIE+0hWFeZagRkTg7hXfBP7zlY/GxxPBJXXBYJ230qdOaT5fZaDWA9qr/92zsjnY9pWG3iMfAif/GFn15SZ1Rn1rT/+R/giw70x6c8ODkEhkD0WyT5mIoYoW/SCwbEV6T6pwOaCHmdNZFXjupVbosQO+GpIlKyLORQBagbwKkJtewKm+OpJjAD//4T3A/o/CH/7hWHCJ0f37fJXJ5KTP5wYOHwkH6/3r1zUfPhJ2Vwg6PfDWnv639/QDv37pgc0NnYnsoUT20Hj2UKB6bhUCmldYjk9OZIDnX7pdPzUqUONKoqfIXTLo9XLIl0whfAGSsyeoyTh3dzRvurkZeOSF1yGkpweD9bqGap+790gECNb7Dx8Jm75f9eWml/9z99vv9N95x5rf7PohYNIDn8kaMCprgOJ2l9JfmMgAyVTm3m+v2nLncktA8jzLV8JKoqdwLjYKYRocoqXBF4ATs+jXbWPjzc26+wHd/cGgWQjuweiYTj86JgP6v05/Khwx6XUBOr2JPvpFAXCOuUt9D0TPjjUuq//3XVv1031vDxqx0PkEm7bxxTmrigvgclCw43KgTdoAT2UBUIuN/v51LZtubgD1qR2jtbRJlU4gUOX1ulyiKOanC6Ofy/4q71Q2WdAUOZlJZyf/5m+W7Xl3b19/Ajxvvb0cekazQ6PZodHsWeBCEkCeLKgKgKowEBn0VfubV4YGPg4z44oOJsF16OhGceZVoOePqWf+MGLgnP0UYNv3HbtfWiASWt4iANGPrbDi+Z0tW9oDwE//IWwm+qt95rE8kfJXeUtOJ5tvqNv/7uiBd0eByJnvQGwOfTIJoE5hCJhaYG774q/b9YOeP6Yef22EOaFEU6vQ1KpFBmZNKKUqQ8PgCa1UA/DBe/KhnllrJya9LkCeSKUvJuWJSX9Vpd/n/q9f9hfpmU+vCyidzXbe5u+8zQ8cfE8G14u/bt/6zWAp/SwBQxFCTTS1CroAqQplwhCgl4Bpm/+sVnf/E4/Pcr+/2udfXC1/cSFzKafTy6l0Oj0JNDfW9xyNAM8+Z7jQpIcS+qKpU4jlxnH3QRkw6fe+NfrCwIiZ0y4Wy1lwiM4Rz6oq5LVq9yGVjOq041xMsMa25LIbWLVemQwoG8/dvrG1vpb6h3cejY2kWm8yOh9Pld/t8Y6dT0WHR5saQoqiplKTalYtL6fzlhCovR/FHvxVYtNdKnA6Pj04OQKkJkhPkC5ZMlRzhmPXrHB0tpxl5uxvuqab1nPfPWEI7/xt7ODJtJZ1SB5hbgkAnbcYK0fdh6wedNVay/3tDdLGG+s3ddbv7x470B0P1BrxeiDgBS5MpKLDMSCTVdwV0mTJNOqxn/bctiH0+F3o9HrifHrdgrW2YK0QDBjv3fFd59qVQvfHqe6T6YMn04BJbwnw19jk81r3B9Odt7g6b3F1HlI/PK4CK9faVn1VyCYMemDTDfXAIzv7gECt16RPplL6RBZwV0jmJLDzllD3BzHgqf/TAbt0+khcTc0sQO9fTNDnMNFNe+6V3Fun4ixkdn+NTT5f8NcIwM4n0iducQGdG8QPj891P7D+Bgl4eOdRM0WnB0x6n9cDxMdloLJCAg4eiv3LTzrMWyJxFSx6jxenHcDvx+/Hg/XGvlOa/lsQXUlr8ki+rOmHAMFa1rfw9L2bt97lefHlELB75Gdm1vJPfgRs2lIPPP5IZNcvT3d8vR7QZjTJ7QWUTEqZygO+Kqm6Sho+NwaMj2dabqr3L7Ydel/oOawCCbEXGIipwKdfWBUs5Lb67lQWYCxli6eF+JiQihmVWStYSxJSeT6ZIPoxzJ+R7X3TcGSwfM3oVH+wfA2wZku9nrh/39iuX54OhcxZGUomlc+pDqfoq5KA6irpwoRFFgi4e7qnf/zEApOM0LUCEPtcA46OWnDpi8TTRiHkFM0hGYOBNmndGz1hxTWGgNFxgK13efa+mf7B92Ivvhxq9z8wqvSXvvLhB48e6IqHQu7QUkNAPjd3wdWkHx/P1Na6gQ23arfcavXtAzHrltjnmi4glbeWCdIlG8ROSXBKQk7RAMEhKBOaktKUVKE0Kltgg2Pvm+m9b6buvisUlNboKSppnd548XDG1AA4nCKQnFCAZEoXMA0Eat2JRObub1vLTDr9iRH1xEjpbh2e0pnqPDM1AEqqAPhq55UAMHzeUelyqVlXy2qe/dklj9PXuWU50L1v8BfPxLren2r5UgvA5LVS3aCa0wceEUiO24DMpQvJCyrgqxb1ELBw+TxwS2cF0CcPxKfGp1WAA6/S32fMLkKNtlCjkMjiKW4ni3bjKwdNs9ZvbGXCWL8GqKoNEMVC7RKUC+SnSwS0tToGShbIHnvoncceekc/jowkNt/akpBTCTm9Ys2ImSczYctMCMBkSsiJqq9arF7sAhLnjJ5+bbsTGFMS8Smr1B/4Ef1HiZ636r3ost5b+o2GVows9TXFkeN5T8CKj6RqclOzq1DrGn71IvPNpG9tDqmcAHIZnxJfrpT9Uaev9GrV13uBC19MRz9Nh673AH1/yO/4+wrg2Bcn5jxwzVfJR6zu8vPZ83VTgzm/dTrxXiuMHM+nE4VSDc7yooB1rY62VmfvcYATx2lZPeuJA+HY+Bfpzbe26Oi5jC8/WQ24q7T4WWelV6tvyI8lpqOfpoHGGz2tqx2674E+eWABl8w2VzHsmZ6alZ7LLbBQkk4UqmpwFm+xY6d9ldi+ShRnRKe4yOMZAWJnaQ0Y636xi73p6VjHrSGVcYDLnvGpCALrV27t+ShOBZN5IhGm68f/YqdjU4dj09fV1Izh8vCwFh02+vjYKHoLH4sDTGasVqyVOYDq6wVArCj5wsQJGMOcWGlpmMwgFZuHUQLrbxIPf6w+tmPkSk66MKFUV1nr9KPno4dP7TVPN29Z++QvDpmn4WHN/I9PGPSxUXJ54sWAQC0JIsSZPBD9fR7wBG1AoFEINF7hSxnITxufCAFlTf8TMAqhLHJv97vp7nfTgLe8KXSNsb11wfnfei/pq5LSWevN+UsZ4PkXdmy+fW2a7cD+93JALG8ssYRjhfRFQwBcRYB1XNq91tbZAl8SgECzMNSrRT+cNdkq95W0gQ9Pqu2rxM5veDu/4W254QQQy/SGrmkzNLi6gOSEkpxQhCvvw+v0V7H4wvHYFW38k4K+upz4RBv/bO4uaH5KF5A1ljHSWbXWo3btnXbZPYA6E+s993hbew8wen5RTeWimuuqgPCANVTWVq4Cntx5InJMafsfieu+BNC7tylf/wmgZPGK5KeQJ4z8kgulGBGIdmv+XRqsmQtt2gyF4krU+GDBYUcrXtKl5KdhWrS60ZtvAnjoBwZf45IN0XOHnn6to3HJhmORPjNbqL5pvque/McjHR9va9t6tbVRQ0NlUYP55pkrZrby2FkwIlUyOSPLA9/T6WeF57qG6LlD+oi79Y51W+9oq6sZArreSXbtS0YiyaYmH7Bte2M699nTP9gOtG093bbzfWUSqQLAXCKVUwa9ocFRpLfjwFoh1027iqr5Gh/4HjffxP2PoO6dG5zpGnT6F3c9CtRWp4HNt1c/9MDgq/8xBTSt8M196mzzF8ME2Q7M1uCAvBExmBos+v8PGfYH7w4wzbZACxBqBoiejSZTycSMZ+MWDuwDu3jnvb5nXz0xzXcAiABd+31dh5aLFaLsP5x2yrnP/clPJKqPbHwsBqSKH105ihsuogNRwGPnspPcIgDRLOwybIsQFyFCfor8jLFWC6V7FEbFFwQ0reRbglzBfrrXs/tpY2KenEj6qnw+rw9QLmsH9gFs3MKzr1ghftd+X9d+X9eBakBaHXZeK+c+9+c+94Oy7M9SDe1pgHMLuMpfbc210lnECmNvF8hPATjKkapxlqFcBIz/OabNawp2nb6pLRXp9UaHo400+qp8gDIhAz9/gU23A+x/w3FgtxM4NbC89H6dPp/wI8Ya2tNDH3oAp60kqJ8dsHuLm7l6ZdU15Ketf6eEP2gIUHMoaZRZn5DC7I85Zj3e5/UlU0kgOhwVPR6TXjddgP6hqEmfT/gBaXV4w+0yoAuYcFrvNGP90hLwVlifq6kl3xBMJSmbAZCuQboGYQbJi5JCHqFQALDNXqzTwB5oVmNn5fd7lJY1Ln9j5tAenyJnxIra1/r6VjUWTkZtgPPagpz3e8RmoLwik/zU6FrUGad0Y1RqkqUm+dSwKMdzkFEmC46CQ8tpQCFfSMSw2W2CXYg5BLekAlIxqnFB4TJOCfIoxYA0eR5VRVWRrim2n8X4FpOZIH62uGxX0jbsqQnF45WA1IQS2eMDNtyR/MmuaK2ITj/HTHrfjXL+hlGpSQaUiD+pXACUyVnjpc1hK+QLhZlCYaaQV/OqPgKMGz1sqTkWkb9kbJAqF1Eu4g+aO64A7ircVYwNMTl7JcYOeKskYGRYFis8Oj0Y9CejAsBAdf871p6X70bZ1yRXN8mxGVWJGOml6Lr79RKY7wJAyc46tS30SaU8ijaJVGUszupW30BmgvR5m5IuWAJSE0o6pXi80s4XorfcmQQ+eNuXkzLAqTMCsDJA/z4DtPGucHXTAgu6UqVVXJrdqeU0LafpJbCghvnmWIRjEWU2KHZBSgqYJQBwV+Esd8oxI+76f/449HVn47JYAAAAAElFTkSuQmCC')
WriteToFile('MenuElement/Gamsteron_Loader.png', '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')
WriteToFile('MenuElement/Gamsteron_Minion.png', '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')
WriteToFile('MenuElement/Gamsteron_Orbwalker.png', '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')
WriteToFile('MenuElement/Gamsteron_Spell_SummonerBarrier.png', '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')
WriteToFile('MenuElement/Gamsteron_Spell_SummonerBoost.png', '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')
WriteToFile('MenuElement/Gamsteron_Spell_SummonerDot.png', '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')
WriteToFile('MenuElement/Gamsteron_Spell_SummonerExhaust.png', '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')
WriteToFile('MenuElement/Gamsteron_Spell_SummonerFlash.png', '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')
WriteToFile('MenuElement/Gamsteron_Spell_SummonerHaste.png', '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')
WriteToFile('MenuElement/Gamsteron_Spell_SummonerHeal.png', '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')
WriteToFile('MenuElement/Gamsteron_Spell_SummonerSmite.png', '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')
WriteToFile('MenuElement/Gamsteron_Spell_SummonerTeleport.png', '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')
WriteToFile('MenuElement/Gamsteron_TargetSelector.png', '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')
-- stylua: ignore end

-- stylua: ignore start
Menu = {

    Main = nil,
    Target = nil,
    Orbwalker = nil,
    ItemsLoaded = false,
    SummonerSpellsLoaded = false,

    CreateMain = function(self)
        self.Main = MenuElement({id = "GGOrbwalker", name = "Orbama", type = MENU})
        CommunityMenuElement(self.Main,{id = "Loader", name = "Loader", type = MENU, leftIcon = "/Gamsteron_Loader.png"})
        CommunityMenuElement(self.Main.Loader,{id = "Items", name = "Items", value = true})
        CommunityMenuElement(self.Main.Loader,{id = "SummonerSpells", name = "SummonerSpells", value = true})
    end,

    CreateTarget = function(self)
        self.Target = CommunityMenuElement(self.Main,{id = 'Target', name = 'Target Selector', type = MENU, leftIcon = '/Gamsteron_TargetSelector.png'})
        CommunityMenuElement(self.Target,{id = 'Priorities', name = 'Priorities', type = MENU})
        CommunityMenuElement(self.Target,{id = 'SelectedTarget', name = 'Selected Target', value = true})
        CommunityMenuElement(self.Target,{id = 'OnlySelectedTarget', name = 'Only Selected Target', value = false})
        CommunityMenuElement(self.Target,{id = 'SortMode' .. myHero.charName, name = 'Sort Mode', value = 1, drop = {'Auto', 'Closest', 'Near Mouse', 'Lowest HP', 'Lowest MaxHP', 'Highest Priority', 'Most Stack', 'Most AD', 'Most AP', 'Less Cast', 'Less Attack'}})
	end,

    CreateOrbwalker = function(self)
        self.Orbwalker = CommunityMenuElement(self.Main,{id = 'Orbwalker', name = 'Orbwalker', type = MENU, leftIcon = '/Gamsteron_Orbwalker.png'})
        CommunityMenuElement(self.Orbwalker,{id = 'Enabled', name = 'Enabled', value = true})
        CommunityMenuElement(self.Orbwalker,{id = 'MovementEnabled', name = 'Movement Enabled', value = true})
        CommunityMenuElement(self.Orbwalker,{id = 'AttackEnabled', name = 'Attack Enabled', value = true})
        CommunityMenuElement(self.Orbwalker,{id = 'Keys', name = 'Keys', type = MENU})
        CommunityMenuElement(self.Orbwalker.Keys,{id = 'Combo', name = 'Combo Key', key = string.byte(' ')})
        CommunityMenuElement(self.Orbwalker.Keys,{id = 'Harass', name = 'Harass Key', key = string.byte('C')})
        CommunityMenuElement(self.Orbwalker.Keys,{id = 'LastHit', name = 'LastHit Key', key = string.byte('X')})
        CommunityMenuElement(self.Orbwalker.Keys,{id = 'LaneClear', name = 'LaneClear Key', key = string.byte('V')})
        CommunityMenuElement(self.Orbwalker.Keys,{id = 'Jungle', name = 'Jungle Key', key = string.byte('V')})
        CommunityMenuElement(self.Orbwalker.Keys,{id = 'Flee', name = 'Flee Key', key = string.byte('A')})
        -- CommunityMenuElement(self.Orbwalker.Keys,{id = 'HoldKey', name = 'Hold Key', key = string.byte('H'), tooltip = 'Should be same in game keybinds'})
        CommunityMenuElement(self.Orbwalker,{id = 'General', name = 'General', type = MENU})
        CommunityMenuElement(self.Orbwalker.General,{id = 'AttackBarrel', name = 'Attack Gangplank Barrel', value = true})
        CommunityMenuElement(self.Orbwalker.General,{id = 'AttackPlants', name = 'Attack Plants(LaneClear Mode)', value = false})
        CommunityMenuElement(self.Orbwalker.General,{id = 'HarassFarm', name = 'Farm In Harass Mode', value = true})
        CommunityMenuElement(self.Orbwalker.General,{id = 'AttackResetting', name = 'Attack Resetting', value = true})
        CommunityMenuElement(self.Orbwalker.General,{id = 'FastKiting', name = 'Fast Kiting', value = true})
        CommunityMenuElement(self.Orbwalker.General,{id = 'LaneClearHeroes', name = 'LaneClear Heroes', value = true})
        CommunityMenuElement(self.Orbwalker.General,{id = 'AttackRange', name = 'AARange = RealRange - X', value = 35, min = 0, max = 35, step = 1})
        CommunityMenuElement(self.Orbwalker.General,{id = 'HoldRadius', name = 'Hold Radius', value = 100, min = 0, max = 250, step = 10})
        CommunityMenuElement(self.Orbwalker.General,{id = 'ExtraWindUpTime', name = 'Extra WindUpTime', value = 0, min = -25, max = 75, step = 5})
        CommunityMenuElement(self.Orbwalker,{id = 'RandomHumanizer', name = 'Random Humanizer', type = MENU})
        CommunityMenuElement(self.Orbwalker.RandomHumanizer,{id = 'Min', name = 'Min', value = 100, min = 50, max = 300, step = 10})
        CommunityMenuElement(self.Orbwalker.RandomHumanizer,{id = 'Max', name = 'Max', value = 150, min = 150, max = 400, step = 10})
        CommunityMenuElement(self.Orbwalker,{id = 'Farming', name = 'Farming Settings', type = MENU})
        CommunityMenuElement(self.Orbwalker.Farming,{id = 'LastHitPriority', name = 'Priorize Last Hit over Harass', value = true})
        CommunityMenuElement(self.Orbwalker.Farming,{id = 'PushPriority', name = 'Priorize Push over Freeze', value = true})
        CommunityMenuElement(self.Orbwalker.Farming,{id = 'ExtraFarmDelay', name = 'ExtraFarmDelay', value = 0, min = -80, max = 80, step = 10})
    end,

    CreateSummonerSpells = function(self)
        if self.Main.Loader.SummonerSpells:Value() then
            self.SummonerSpellsLoaded = true
            self.SummonerSpells = CommunityMenuElement(self.Main,{id = 'SummonerSpells', name = 'Summoner Spells', type = MENU, leftIcon = "/Gamsteron_Spell_SummonerDot.png"})
            CommunityMenuElement(self.SummonerSpells,{id = 'Cleanse', name = 'Cleanse', type = MENU, leftIcon = '/Gamsteron_Spell_SummonerBoost.png'})
            CommunityMenuElement(self.SummonerSpells.Cleanse,{id = 'BuffTypes', name = 'Buff Types', type = MENU})
            CommunityMenuElement(self.SummonerSpells.Cleanse.BuffTypes,{id = 'Slow', name = 'Slow: nasus w', value = true})--SLOW = 11 -> nasus W, zilean E
            CommunityMenuElement(self.SummonerSpells.Cleanse.BuffTypes,{id = 'Stun', name = 'Stun: sona r', value = true})--STUN = 5
            CommunityMenuElement(self.SummonerSpells.Cleanse.BuffTypes,{id = 'Snare', name = 'Snare: xayah e', value = true})--SNARE = 12
            CommunityMenuElement(self.SummonerSpells.Cleanse.BuffTypes,{id = 'Berserk', name = 'Berserk: renata r', value = true})--Berserk = 9
            CommunityMenuElement(self.SummonerSpells.Cleanse.BuffTypes,{id = 'Supress', name = 'Supress: warwick r', value = false})--SUPRESS = 25
            --CommunityMenuElement(self.SummonerSpells.Cleanse.BuffTypes,{id = 'Knockup', name = 'Knockup: yasuo q3', value = true})--KNOCKUP = 30
            CommunityMenuElement(self.SummonerSpells.Cleanse.BuffTypes,{id = 'Flee', name = 'Flee: fiddle q', value = true})--FLEE = 29 -> fiddle Q, ...
            CommunityMenuElement(self.SummonerSpells.Cleanse.BuffTypes,{id = 'Charm', name = 'Charm: ahri e', value = true})--CHARM = 23 -> ahri E, ...
            CommunityMenuElement(self.SummonerSpells.Cleanse.BuffTypes,{id = 'Taunt', name = 'Taunt: rammus e', value = true})--TAUNT = 8 -> rammus E, ...
            --CommunityMenuElement(self.SummonerSpells.Cleanse.BuffTypes,{id = 'Knockback', name = 'Knockback: alistar w', value = true})--KNOCKBACK = 31 -> alistar W, lee sin R, ...
            CommunityMenuElement(self.SummonerSpells.Cleanse.BuffTypes,{id = 'Blind', name = 'Blind: teemo q', value = true})--BLIND = 26 -> teemo Q
            CommunityMenuElement(self.SummonerSpells.Cleanse.BuffTypes,{id = 'Disarm', name = 'Disarm: lulu w', value = true})--DISARM = 32 -> Lulu W
            CommunityMenuElement(self.SummonerSpells.Cleanse.BuffTypes,{id = 'Drowsy', name = 'Drowsy', value = true})--Drowsy = 34
            CommunityMenuElement(self.SummonerSpells.Cleanse.BuffTypes,{id = 'Asleep', name = 'Asleep', value = true})--ASleep = 35
            CommunityMenuElement(self.SummonerSpells.Cleanse,{id = 'Enabled', name = 'Enabled', value = true})
            CommunityMenuElement(self.SummonerSpells.Cleanse,{id = 'Count', name = 'Enemies Count', value = 1, min = 0, max = 5, step = 1})
            CommunityMenuElement(self.SummonerSpells.Cleanse,{id = 'Distance', name = 'Enemies Distance < X', value = 1200, min = 0, max = 1500, step = 50})
            CommunityMenuElement(self.SummonerSpells.Cleanse,{id = 'Duration', name = 'Buff Duration > X', value = 500, min = 0, max = 1000, step = 50})
            CommunityMenuElement(self.SummonerSpells.Cleanse,{id = 'Delay', name = 'humanized delay', value = 0.1, min = 0, max = 0.3, step = 0.01})
        end
    end,

    CreateItems = function(self)
        if self.Main.Loader.Items:Value() then
            self.ItemsLoaded = true
            CommunityMenuElement(self.Main,{id = 'Items', name = 'Items', type = MENU, leftIcon = '/Gamsteron_Item_3139.png'})
            CommunityMenuElement(self.Main.Items,{id = 'Qss', name = 'QSS | Mercurial Scimitar | Silvermere Dawn', type = MENU})
            CommunityMenuElement(self.Main.Items.Qss,{id = 'BuffTypes', name = 'Buff Types', type = MENU})
            CommunityMenuElement(self.Main.Items.Qss.BuffTypes,{id = 'Slow', name = 'Slow: nasus w', value = true})--SLOW = 11 -> nasus W, zilean E
            CommunityMenuElement(self.Main.Items.Qss.BuffTypes,{id = 'Stun', name = 'Stun: sona r', value = true})--STUN = 5
            CommunityMenuElement(self.Main.Items.Qss.BuffTypes,{id = 'Snare', name = 'Snare: xayah e', value = true})--SNARE = 12
            CommunityMenuElement(self.Main.Items.Qss.BuffTypes,{id = 'Berserk', name = 'Berserk: renata r', value = true})--Berserk = 9
            CommunityMenuElement(self.Main.Items.Qss.BuffTypes,{id = 'Supress', name = 'Supress: warwick r', value = true})--SUPRESS = 25
            --CommunityMenuElement(self.Main.Items.Qss.BuffTypes,{id = 'Knockup', name = 'Knockup: yasuo q3', value = true})--KNOCKUP = 30
            CommunityMenuElement(self.Main.Items.Qss.BuffTypes,{id = 'Flee', name = 'Flee: fiddle q', value = true})--FLEE = 29 -> fiddle Q, ...
            CommunityMenuElement(self.Main.Items.Qss.BuffTypes,{id = 'Charm', name = 'Charm: ahri e', value = true})--CHARM = 23 -> ahri E, ...
            CommunityMenuElement(self.Main.Items.Qss.BuffTypes,{id = 'Taunt', name = 'Taunt: rammus e', value = true})--TAUNT = 8 -> rammus E, ...
            --CommunityMenuElement(self.Main.Items.Qss.BuffTypes,{id = 'Knockback', name = 'Knockback: alistar w', value = true})--KNOCKBACK = 31 -> alistar W, lee sin R, ...
            CommunityMenuElement(self.Main.Items.Qss.BuffTypes,{id = 'Blind', name = 'Blind: teemo q', value = true})--BLIND = 26 -> teemo Q
            CommunityMenuElement(self.Main.Items.Qss.BuffTypes,{id = 'Disarm', name = 'Disarm: lulu w', value = true})--DISARM = 32 -> Lulu W
            CommunityMenuElement(self.Main.Items.Qss.BuffTypes,{id = 'Drowsy', name = 'Drowsy', value = true})--Drowsy = 34
            CommunityMenuElement(self.Main.Items.Qss.BuffTypes,{id = 'Asleep', name = 'Asleep', value = true})--Asleep = 35
			CommunityMenuElement(self.Main.Items.Qss,{id = 'Enabled', name = 'Enabled', value = true})
            CommunityMenuElement(self.Main.Items.Qss,{id = 'Count', name = 'Enemies Count', value = 1, min = 0, max = 5, step = 1})
            CommunityMenuElement(self.Main.Items.Qss,{id = 'Distance', name = 'Enemies Distance < X', value = 1200, min = 0, max = 1500, step = 50})
            CommunityMenuElement(self.Main.Items.Qss,{id = 'Duration', name = 'Buff Duration > X', value = 500, min = 0, max = 1000, step = 50})
			CommunityMenuElement(self.Main.Items.Qss,{id = 'Delay', name = 'humanized delay', value = 0.1, min = 0, max = 0.3, step = 0.01})
        end
    end,

    CreateDrawings = function(self)
        CommunityMenuElement(self.Main,{id = 'Drawings', name = 'Drawings', type = MENU, leftIcon = '/Gamsteron_Drawings.png'})
        CommunityMenuElement(self.Main.Drawings,{id = 'Enabled', name = 'Enabled', value = true})
        CommunityMenuElement(self.Main.Drawings,{id = 'Cursor', name = 'Cursor', value = true})
        CommunityMenuElement(self.Main.Drawings,{id = 'Range', name = 'AutoAttack Range', value = true})
        CommunityMenuElement(self.Main.Drawings,{id = 'EnemyRange', name = 'Enemy AutoAttack Range', value = true})
        CommunityMenuElement(self.Main.Drawings,{id = 'HoldRadius', name = 'Hold Radius', value = false})
        CommunityMenuElement(self.Main.Drawings,{id = 'LastHittableMinions', name = 'Last Hittable Minions', value = true})
        CommunityMenuElement(self.Main.Drawings,{id = 'SelectedTarget', name = 'Selected Target', value = true})
    end,

    CreateGeneral = function(self)
        CommunityMenuElement(self.Main,{name = '', type = SPACE, id = 'GeneralSpace'})
        CommunityMenuElement(self.Main,{id = 'AttackTKey', name = 'Attack Target Key', key = string.byte('U'), tooltip = 'You should bind this one in ingame settings'})
        CommunityMenuElement(self.Main,{id = 'Latency', name = 'Ping [ms]', value = 50, min = 0, max = 120, step = 1, callback = function(value) _G.LATENCY = value end})
        CommunityMenuElement(self.Main,{id = 'SetCursorMultipleTimes', name = 'Set Cursor Position Multiple Times', value = false})
        CommunityMenuElement(self.Main,{id = 'CursorDelay', name = 'Cursor Delay', value = 30, min = 30, max = 50, step = 1})
		CommunityMenuElement(self.Main,{id = 'Humanizer', name = 'min dist b/t move commands', value = 200, min = 0, max = 300, step = 5})
        CommunityMenuElement(self.Main,{name = '', type = SPACE, id = 'VersionSpaceA'})
        CommunityMenuElement(self.Main,{name = 'Version  ' .. __version__, type = SPACE, id = 'VersionSpaceB'})
    end,
}
-- stylua: ignore end

Menu:CreateMain()
Menu:CreateTarget()
Menu:CreateOrbwalker()
Menu:CreateSummonerSpells()
Menu:CreateItems()
Menu:CreateDrawings()
FlashHelper:CreateMenu(Menu.Main)
Menu:CreateGeneral()

local testConfig={}
local function setting(value) return {Value=function(_,v)if v~=nil then value=v end;return value end} end
Menu.Main.OrbamaLua={LearnMoves=setting(testConfig.learnMoves==true),AutoMovementTiming=setting(true),
    GGCompatibility=setting(testConfig.ggCompatible~=false),DetailedInput=setting(testConfig.enabled==true),
    Profile=setting(testConfig.enabled==true and testConfig.profile==true),ReleaseGapTrial=setting(false)}

local initialLatency = Game.Latency()
_G.LATENCY = type(initialLatency) == "number" and initialLatency == initialLatency and initialLatency >= 0 and initialLatency < math.huge and initialLatency or Menu.Main.Latency:Value()

Color = {
	LightGreen = Draw.Color(255, 144, 238, 144),
	OrangeRed = Draw.Color(255, 255, 69, 0),
	Black = Draw.Color(255, 0, 0, 0),
	Red = Draw.Color(255, 255, 0, 0),
	Yellow = Draw.Color(255, 255, 255, 0),
	DarkRed = Draw.Color(255, 204, 0, 0),
	AlmostLastHitable = Draw.Color(255, 239, 159, 55),
	LastHitable = Draw.Color(255, 255, 255, 255),
	Range = Draw.Color(150, 49, 210, 0),
	EnemyRange = Draw.Color(150, 255, 0, 0),
	Cursor = Draw.Color(255, 0, 255, 0),
	drawcolor1 = Draw.Color(150, 255, 255, 255),
	drawcolor2 = Draw.Color(150, 239, 159, 55),
}

Action = {

	Tasks = {},

	OnTick = function(self)
		-- Use reverse order so table_remove will not shift later tasks past the loop.
		for i = #self.Tasks, 1, -1 do
			local task = self.Tasks[i]
			if os.clock() >= task[2] then
				if task[1]() or os.clock() >= task[3] then
					table_remove(self.Tasks, i)
				end
			end
		end
	end,

	Add = function(self, task, startTime, endTime)
		startTime = startTime or 0
		endTime = endTime or 10000
		table_insert(self.Tasks, { task, os.clock() + startTime, os.clock() + startTime + endTime })
	end,
}

Buff = {

	GetBuffDuration = function(self, unit, name)
		name = name:lower()
		local result = 0
		local buff = nil
		local buffs = Cached:GetBuffs(unit)
		for i = 1, #buffs do
			buff = buffs[i]
			if (buff.lowerName or buff.name:lower()) == name then
				local duration = buff.duration
				if duration > result then
					result = duration
				end
			end
		end
		return result
	end,

	GetBuffs = function(self, unit)
		return Cached:GetBuffs(unit)
	end,

	GetBuff = function(self, unit, name)
		name = name:lower()
		local result = nil
		local buff = nil
		local buffs = Cached:GetBuffs(unit)
		for i = 1, #buffs do
			buff = buffs[i]
			if (buff.lowerName or buff.name:lower()) == name then
				result = buff
				break
			end
		end
		return result
	end,

	HasBuffContainsName = function(self, unit, name)
		name = name:lower()
		local buffs = Cached:GetBuffs(unit)
		local result = false
		for i = 1, #buffs do
			if (buffs[i].lowerName or buffs[i].name:lower()):find(name) then
				result = true
				break
			end
		end
		return result
	end,

	GetBuffExpire = function(self, unit, name)
		name = name:lower()
		local result = 0
		local buff = nil
		local buffs = Cached:GetBuffs(unit)
		for i = 1, #buffs do
			buff = buffs[i]
			if (buff.lowerName or buff.name:lower()) == name then
				local expireTime = buff.expireTime
				if expireTime > result then
					result = expireTime
				end
			end
		end
		return result
	end,

	HasBuffContainsNameCount = function(self, unit, name)
		name = name:lower()
		local buffs = Cached:GetBuffs(unit)
		local result = 0
		for i = 1, #buffs do
			if (buffs[i].lowerName or buffs[i].name:lower()):find(name) then
				result = result + 1
			end
		end
		return result
	end,

	ContainsBuffs = function(self, unit, arr)
		local buffs = Cached:GetBuffs(unit)
		local result = false
		for i = 1, #buffs do
			if arr[(buffs[i].lowerName or buffs[i].name:lower())] then
				result = true
				break
			end
		end
		return result
	end,

	HasBuff = function(self, unit, name)
		if unit == nil or name == nil then
			return false
		end
		name = name:lower()
		local buffs = Cached:GetBuffs(unit)
		local result = false
		for i = 1, #buffs do
			if (buffs[i].lowerName or buffs[i].name:lower()) == name then
				result = true
				break
			end
		end
		return result
	end,

	HasBuffTypes = function(self, unit, arr)
		local buffs = Cached:GetBuffs(unit)
		local result = false
		for i = 1, #buffs do
			if arr[buffs[i].type] then
				result = true
				break
			end
		end
		return result
	end,

	GetBuffCount = function(self, unit, name)
		name = name:lower()
		local result = 0
		local buff = nil
		local buffs = Cached:GetBuffs(unit)
		for i = 1, #buffs do
			buff = buffs[i]
			if (buff.lowerName or buff.name:lower()) == name then
				local count = buff.count
				if count > result then
					result = count
				end
			end
		end
		return result
	end,

	GetBuffStacks = function(self, unit, name)
		name = name:lower()
		local result = 0
		local buff = nil
		local buffs = Cached:GetBuffs(unit)
		for i = 1, #buffs do
			buff = buffs[i]
			if (buff.lowerName or buff.name:lower()) == name then
				local count = buff.stacks
				if count > result then
					result = count
				end
			end
		end
		return result
	end,
	
	GetBuffStartTime = function(self, unit, name)
		name = name:lower()
		local result = 0
		local buff = nil
		local buffs = Cached:GetBuffs(unit)
		for i = 1, #buffs do
			buff = buffs[i]
			if (buff.lowerName or buff.name:lower()) == name then
				local time = buff.startTime
				if time > result then
					result = time
				end
			end
		end
		return result
	end,

	Print = function(self, target)
		local result = ""
		local buffs = self:GetBuffs(target)
		for i = 1, #buffs do
			local buff = buffs[i]
			result = result .. buff.name .. ": count=" .. buff.count .. " duration=" .. tostring(buff.duration) .. "\n"
		end
		local pos2D = target.pos:To2D()
		local posX = pos2D.x - 50
		local posY = pos2D.y
		Draw.Text(result, 22, posX + 50, posY - 15)
	end,
}

Damage = {

	BaseTurrets = {
		["SRUAP_Turret_Order3"] = true,
		["SRUAP_Turret_Order4"] = true,
		["SRUAP_Turret_Chaos3"] = true,
		["SRUAP_Turret_Chaos4"] = true,
	},

	TurretToMinionPercent = {
		["SRU_ChaosMinionMelee"] = 0.43,
		["SRU_ChaosMinionRanged"] = 0.68,
		["SRU_ChaosMinionSiege"] = 0.14,
		["SRU_ChaosMinionSuper"] = 0.05,
		["SRU_OrderMinionMelee"] = 0.43,
		["SRU_OrderMinionRanged"] = 0.68,
		["SRU_OrderMinionSiege"] = 0.14,
		["SRU_OrderMinionSuper"] = 0.05,
		["HA_ChaosMinionMelee"] = 0.43,
		["HA_ChaosMinionRanged"] = 0.68,
		["HA_ChaosMinionSiege"] = 0.14,
		["HA_ChaosMinionSuper"] = 0.05,
		["HA_OrderMinionMelee"] = 0.43,
		["HA_OrderMinionRanged"] = 0.68,
		["HA_OrderMinionSiege"] = 0.14,
		["HA_OrderMinionSuper"] = 0.05,
	},

	HeroStaticDamage = {
		["Zaahen"] = function(args)
			local level = args.From:GetSpellData(_Q).level
			if Buff:HasBuff(args.From, "ZaahenQ") then
				args.RawPhysical = args.RawPhysical +  15 * level + (0.15 + 0.05 * level) * args.From.bonusDamage
			end
			if Buff:HasBuff(args.From, "ZaahenQ2") then
				args.RawPhysical = args.RawPhysical +  25 * level + (0.15 + 0.05 * level) * args.From.bonusDamage
			end
		end,
		["Yunara"] = function(args)
			local level = args.From:GetSpellData(_Q).level
			if level > 0 then
				args.RawMagical = args.RawMagical +  5 * level + 0.2 * args.From.ap
			end
			if args.From.critChance >= 1 then
				args.RawMagical = args.RawMagical
					+ args.RawTotal * Damage:GetCriticalStrikePercent(args.From) * (0.1 + 0.001 * args.From.ap)
			end
		end,
		["Ashe"] = function(args)
			local level = args.From:GetSpellData(_Q).level
			local modCrit = 1.0 + (Item:HasItem(args.From, 3031) and 0.3 or 0)
			args.RawTotal = args.RawTotal * (1.0 + (modCrit * args.From.critChance))
			if Buff:HasBuff(args.From, "asheqattack") then
				args.RawTotal = args.RawTotal * (1.05 + 0.05 * level)
			end
		end,
		["Jayce"] = function(args)
			local level = args.From.levelData.lvl
			local t = level < 6 and 25 or (level < 11 and 65 or level < 16 and 105 or 145)
			if Buff:HasBuff(args.From, "jaycepassivemeleeattack") then
				args.RawMagical = args.RawMagical + t + 0.25 * args.From.bonusDamage
			end
		end,
		["Neeko"] = function(args)
			local level = args.From:GetSpellData(_W).level
			if level > 0 then
				if Buff:HasBuff(args.From, "neekowpassiveready") then
					args.RawMagical = args.RawMagical + (35 * level - 5) + 0.6 * args.From.ap
				end	
			end
		end,
		["Ziggs"] = function(args)
			local t = { 20, 24, 28, 32, 36, 40, 48, 56, 64, 72, 80, 88, 100, 112, 124, 136, 148, 160 }
			if Buff:HasBuff(args.From, "ziggsshortfuse") then
				args.RawMagical = args.RawMagical + t[math_max(math_min(args.From.levelData.lvl, 18), 1)] + 0.5 * args.From.ap
			end
		end,
		["Caitlyn"] = function(args)
			if Buff:HasBuff(args.From, "caitlynpassivedriver") then
				local modCrit = 1.0 + (Item:HasItem(args.From, 3031) and 0.3 or 0)
				local level = args.From.levelData.lvl
				local t = level < 7 and 0.6 or (level < 13 and 0.8 or 1.0)
				if args.TargetIsMinion then
					t = 1.1
					args.RawPhysical = args.RawPhysical
						+ (t + (modCrit * args.From.critChance)) * args.From.totalDamage
				else
					args.RawPhysical = args.RawPhysical
						+ (t + (modCrit * args.From.critChance)) * args.From.totalDamage
				end
			end
		end,
		["Corki"] = function(args)
			args.CalculatedTrue = args.CalculatedTrue + 0.15 * args.From.totalDamage
		end,
		["Diana"] = function(args)
			if Buff:GetBuffCount(args.From, "dianapassivemarker") == 2 then
				local level = args.From.levelData.lvl
				args.RawMagical = args.RawMagical
					+ math_max(15 + 5 * level, -10 + 10 * level, -60 + 15 * level, -125 + 20 * level, -200 + 25 * level)
					+ 0.8 * args.From.ap
			end
		end,
		["Draven"] = function(args)
			if Buff:HasBuff(args.From, "DravenSpinningAttack") then
				local level = args.From:GetSpellData(_Q).level
				args.RawPhysical = args.RawPhysical + 25 + 5 * level + (0.55 + 0.1 * level) * args.From.bonusDamage
			end
		end,
		["Fizz"] = function(args)
			if Buff:HasBuff(args.From, "fizzw") then
				args.RawMagical = args.RawMagical+ (30 + 20 * args.From:GetSpellData(_W).level) +0.5 * args.From.ap
			end
		end,
		["Hwei"] = function(args)
			if Buff:HasBuff(args.From, "HweiWEBuffCounter") then
				local amnt = 0
				if(args.From:GetSpellData(_Q).name == "HweiQ") then
					amnt = ({20, 30, 40, 50, 60})[args.From:GetSpellData(_W).level] + (args.From.ap * 0.15)
				else
					amnt = 20 + (args.From.ap * 0.15)
				end
				args.RawMagical = args.RawMagical + amnt
			end
		end,
		["Kassadin"] = function(args)
			if Game.CanUseSpell(1)==8 then
				args.RawMagical = args.RawMagical+ (25 + 25 * args.From:GetSpellData(_W).level) +0.8 * args.From.ap
			end
		end,
		["Graves"] = function(args)
			local t = { 70, 71, 72, 74, 75, 76, 78, 80, 81, 83, 85, 87, 89, 91, 95, 96, 97, 100 }
			args.RawTotal = args.RawTotal * t[math_max(math_min(args.From.levelData.lvl, 18), 1)] * 0.01
		end,
		["Jinx"] = function(args)
			if Buff:HasBuff(args.From, "JinxQ") then
				args.RawPhysical = args.RawPhysical + args.From.totalDamage * 0.1
			end
		end,
		["Kayle"] = function(args)
			local level = args.From:GetSpellData(_E).level
			if level > 0 then
				if Buff:HasBuff(args.From, "JudicatorRighteousFury") then
					args.RawMagical = args.RawMagical + 10 + 10 * level + 0.3 * args.From.ap
				else
					args.RawMagical = args.RawMagical + 5 + 5 * level + 0.15 * args.From.ap
				end
			end
		end,
		["Nasus"] = function(args)
			if Buff:HasBuff(args.From, "NasusQ") then
				args.RawPhysical = args.RawPhysical
					+ math_max(Buff:GetBuffStacks(args.From, "NasusQStacks"), 0)
					+ 20
					+ 20 * args.From:GetSpellData(_Q).level
			end
		end,
		["Thresh"] = function(args)
			local level = args.From:GetSpellData(_E).level
			if level > 0 then
				local damage = math_max(Buff:GetBuffCount(args.From, "threshpassivesouls"), 0)
					+ (0.5 + 0.3 * level) * args.From.totalDamage
				if Buff:HasBuff(args.From, "threshqpassive4") then
					damage = damage * 1
				elseif Buff:HasBuff(args.From, "threshqpassive3") then
					damage = damage * 0.5
				elseif Buff:HasBuff(args.From, "threshqpassive2") then
					damage = damage * 1 / 3
				else
					damage = damage * 0.25
				end
				args.RawMagical = args.RawMagical + damage
			end
		end,
		["TwistedFate"] = function(args)
			if Buff:HasBuff(args.From, "cardmasterstackparticle") then
				args.RawMagical = args.RawMagical + 40 + 25 * args.From:GetSpellData(_E).level + 0.75 * args.From.bonusDamage + 0.5 * args.From.ap
			end
			if Buff:HasBuff(args.From, "BlueCardPreAttack") then
				args.DamageType = DAMAGE_TYPE_MAGICAL
				args.RawMagical = args.RawMagical + (20 + 20 * args.From:GetSpellData(_W).level + args.From.totalDamage + 1.15 * args.From.ap) * (1 + 0.575 * args.From.critChance)
			elseif Buff:HasBuff(args.From, "RedCardPreAttack") then
				args.DamageType = DAMAGE_TYPE_MAGICAL
				args.RawMagical = args.RawMagical + (15 + 15 * args.From:GetSpellData(_W).level + args.From.totalDamage + 0.7 * args.From.ap) * (1 + 0.35 * args.From.critChance)
			elseif Buff:HasBuff(args.From, "GoldCardPreAttack") then
				args.DamageType = DAMAGE_TYPE_MAGICAL
				args.RawMagical = args.RawMagical + (7.5 + 7.5 * args.From:GetSpellData(_W).level + args.From.totalDamage + 0.5 * args.From.ap) * (1 + 0.25 * args.From.critChance)
			end
		end,
		["Varus"] = function(args)
			local level = args.From:GetSpellData(_W).level
			if level > 0 then
				args.RawMagical = args.RawMagical + (9 * level - 5) + 0.25 * args.From.ap + 0.15 * args.From.bonusDamage
			end
		end,
		["Viktor"] = function(args)
			if Buff:HasBuff(args.From, "ViktorQReturn") then
				args.DamageType = DAMAGE_TYPE_MAGICAL
				args.RawMagical = args.RawMagical + (25 * args.From:GetSpellData(_Q).level - 5) + 0.5 * args.From.ap
			end
		end,
		["Vayne"] = function(args)
			if Buff:HasBuff(args.From, "vaynetumblebonus") then
				args.RawPhysical = args.RawPhysical
					+ (0.65 + 0.1 * args.From:GetSpellData(_Q).level) * args.From.totalDamage + 0.5 * args.From.ap
			end
		end,
		["Jade_Vayne"] = function(args)
			if Buff:HasBuff(args.From, "jade_vayneq_bonus") then
				local level = args.From:GetSpellData(_Q).level
				local ratio = 0.25 + 0.05 * level
				args.RawPhysical = args.RawPhysical + ratio * args.From.totalDamage
			end
		end,
	},

	ItemStaticDamage = {
		[1043] = function(args) -- Recurve Bow
			args.RawPhysical = args.RawPhysical + 15
		end,
		[3144] = function(args) -- Scout's Slingshot
			if not args.TargetIsMinion and Item:IsReady(args.From, 3144) then
				args.RawMagical = args.RawMagical + 40
			end
		end,
		[3091] = function(args) -- Wit's End
			args.RawMagical = args.RawMagical + 45
		end,
		[3115] = function(args) -- Nashor's Tooth
			args.RawMagical = args.RawMagical + 15 + 0.15 * args.From.ap
		end,
		[3124] = function(args)	-- Guinsoo's Rageblade
			args.RawMagical = args.RawMagical + 30
		end,
		[3302] = function(args) -- Terminus
			args.RawMagical = args.RawMagical + 30
		end,
		[3087] = function(args) -- Statikk Shiv
			if Buff:GetBuffStacks(args.From, "itemstatikshankcharge") == 100 then
				if args.TargetIsMinion then
					args.RawMagical = args.RawMagical + 90
				else
					args.RawMagical = args.RawMagical + 60
				end
			end
		end,
		[3094] = function(args) -- Rapid Firecannon
			if Buff:GetBuffStacks(args.From, "itemstatikshankcharge") == 100 then
				args.RawMagical = args.RawMagical + 40
			end
		end,
		[3097] = function(args) -- Stormrazor
			if Buff:GetBuffStacks(args.From, "itemstatikshankcharge") == 100 then
				args.RawMagical = args.RawMagical + 100
			end
		end,
		[3057] = function(args) -- Sheen
			if Buff:HasBuff(args.From, "sheen") then
				args.RawPhysical = args.RawPhysical + 1.0 * args.From.baseDamage
			end
		end,
		[6662] = function(args) -- Iceborn Gauntlet
			if Buff:HasBuff(args.From, "6662buff") then
				args.RawPhysical = args.RawPhysical + 1.5 * args.From.baseDamage
			end
		end,
		[3078] = function(args) -- Trinity Force
			if Buff:HasBuff(args.From, "3078trinityforce") then
				args.RawPhysical = args.RawPhysical + 2.0 * args.From.baseDamage
			end
		end,
		[3508] = function(args) -- Essence Reaver
			if Buff:HasBuff(args.From, "3508buff") then
				local critMultiplier = 0.5 * args.From.critChance
				local damage = 1.25 * args.From.baseDamage * (1 + critMultiplier)
				args.RawPhysical = args.RawPhysical + damage
			end
		end,
		[3100] = function(args) -- Lich Bane
			if Buff:HasBuff(args.From, "lichbane") then
				args.RawMagical = args.RawMagical + 0.75 * args.From.baseDamage + 0.4 * args.From.ap
			end
		end,
		[2510] = function(args) -- Dusk and Dawn
			if Buff:HasBuff(args.From, "2510_sheenhands") then
				args.RawPhysical = args.RawPhysical + 0.75 * args.From.baseDamage + 0.1 * args.From.ap
			end
		end,
	},

	HeroPassiveDamage = {
		["KogMaw"] = function(args)
			local level = args.From:GetSpellData(_W).level
			if Buff:HasBuff(args.From, "kogmawbioarcanebarrage") then
				args.RawMagical = args.RawMagical + ((2.25 + 0.75 * level) + args.From.ap/100)/100 * args.Target.maxHealth
			end
		end,
		["Zeri"] = function(args)
			args.RawTotal = args.RawTotal * 0
			args.RawPhysical = args.RawTotal
			local level = args.From.levelData.lvl
			if Buff:HasBuff(myHero, "zeriqpassiveready") then
				local percentDamage = (1 + (10 / 17) * (level - 1)) / 100 * args.Target.maxHealth
				if args.Target.team == 300 then
					percentDamage = math_min(300, percentDamage)
				end
				args.RawMagical = 70 + 5 * level + args.From.ap * 1.1
					+ percentDamage
			else
				args.RawMagical = 10 + (15 / 17) * (level - 1) * (0.7025 + 0.0175 * (level-1)) + args.From.ap * 0.03
				if args.Target.health < 70 + (90 / 17) * (level - 1) + args.From.ap * 0.2 then
					args.RawMagical = 9999 --(Execute targets, < this health)
				end
			end
		end,
		["Jhin"] = function(args)
			local level = args.From.levelData.lvl
			local t = level <= 9 and (3 + level) or level <= 11 and (12 + 2 * (level - 9)) or (16 + 4 * (level - 11))
			args.RawTotal = args.From.baseDamage
				* (1 + t / 100 + args.From.critChance * 0.35 + 0.3 * (args.From.attackSpeed - 1)) + args.From.bonusDamage
			if args.From.hudAmmo == 1 then
				args.CriticalStrike = true
				args.RawPhysical = args.RawPhysical
					+ math_min(0.25, 0.1 + 0.05 * math_ceil(args.From.levelData.lvl / 5))
						* (args.Target.maxHealth - args.Target.health)
			end
		end,
		["Lux"] = function(args)
			if Buff:HasBuff(args.Target, "LuxIlluminatingFraulein") then
				args.RawMagical = 20 + args.From.levelData.lvl * 10 + args.From.ap * 0.25
			end
		end,
		["Locke"] = function(args)
			local level = args.From.levelData.lvl
			local percent = 0
			if args.Target.maxHealth > 0 then
				percent = math_min((args.Target.maxHealth - args.Target.health) / args.Target.maxHealth / 0.7, 1)
			end
			args.RawMagical = args.RawMagical + (5 + (35 / 17) * (level - 1) + 0.1 * args.From.ap) * (1 + percent)
			local Qlevel = args.From:GetSpellData(_Q).level
			if Qlevel > 0 then
				local stacks = math_max(Buff:GetBuffCount(args.Target, "LockeQ"), 0)
				if stacks > 0 then
					local bonus = 1
					if stacks == 2 then
						bonus = 1.2
					elseif stacks == 3 then
						bonus = 1.4
					end
					args.RawMagical = args.RawMagical
						+ stacks * (8 + 10 * Qlevel + (0.225 + 0.025 * Qlevel) * args.From.ap) * bonus
				end
			end
		end,
		["Orianna"] = function(args)
			local level = math_ceil(args.From.levelData.lvl / 3)
			args.RawMagical = args.RawMagical + 2 + 8 * level + 0.15 * args.From.ap
			if args.Target.handle == args.From.attackData.target then
				args.RawMagical = args.RawMagical
					+ math_max(Buff:GetBuffCount(args.From, "orianapowerdaggerdisplay"), 0)
						* (0.4 + 1.6 * level + 0.03 * args.From.ap)
			end
		end,
		["Quinn"] = function(args)
			if Buff:HasBuff(args.Target, "QuinnW") then
				local level = args.From.levelData.lvl
				args.RawPhysical = args.RawPhysical + 10 + level * 5 + (0.14 + 0.02 * level) * args.From.totalDamage
			end
		end,
		["Teemo"] = function(args)
			local Edata = myHero:GetSpellData(_E)
			if Edata.level > 0 then
				args.RawMagical = Edata.level * 10 + 0.30 * args.From.ap
			end
		end,
		["Vayne"] = function(args)
			if Buff:GetBuffCount(args.Target, "VayneSilveredDebuff") == 2 then
				local level = args.From:GetSpellData(_W).level
				args.CalculatedTrue = args.CalculatedTrue
					+ math_max((0.025 + 0.015 * level) * args.Target.maxHealth, 25 + 15 * level)
			end
		end,
		["Jade_Vayne"] = function(args)
			if Buff:GetBuffCount(args.Target, "Jade_VayneW_Debuff") == 2 then
				local level = args.From:GetSpellData(_W).level
				local damage = (10 + 10 * level) + (0.03 + 0.01 * level) * args.Target.maxHealth
				if args.Target.team == 300 then
					damage = math_min(damage, 200)
				end
				args.CalculatedTrue = args.CalculatedTrue + damage
			end
		end,
		["Zed"] = function(args)
			if
				100 * args.Target.health / args.Target.maxHealth <= 50 and not Buff:HasBuff(args.From, "zedpassivecd")
			then
				args.RawMagical = args.RawMagical
					+ args.Target.maxHealth * (4 + 2 * math_ceil(args.From.levelData.lvl / 6)) * 0.01
			end
		end,
	},

	ItemPassiveDamage = {
		[6699] = function(args) -- Voltaic Cyclosword
			if Buff:GetBuffStacks(args.From, "itemstatikshankcharge") == 100 then
				local damage = args.Target.health * (Data:IsMelee(args.From) and 0.09 or 0.07)
				if args.TargetIsMinion then
					damage = math_min(damage, 200)
				end
				args.RawPhysical = args.RawPhysical + damage
			end
		end,
		[6672] = function(args) -- Kraken Slayer
			if Buff:GetBuffStacks(args.From, "6672buff") == 2 then
				local isMelee = Data:IsMelee(args.From)
				local level = args.From.levelData.lvl
				local baseDamage = isMelee and (level <= 8 and 150 or 150 + (level - 8) * 5)
											or (level <= 8 and 120 or 120 + (level - 8) * 4)
				local missingHealthPercent = (args.Target.maxHealth - args.Target.health) / args.Target.maxHealth
				args.RawPhysical = args.RawPhysical + baseDamage * (1 + 0.75 * missingHealthPercent)
			end
		end,
		[3153] = function(args) -- Blade of the Ruined King
    		local damage = args.Target.health * (Data:IsMelee(args.From) and 0.09 or 0.06)
    		if args.TargetIsMinion then
        		damage = math_min(damage, 100)
    		end
			args.RawPhysical = args.RawPhysical + damage
		end,
	},

	IsBaseTurret = function(self, name)
		if self.BaseTurrets[name] then
			return true
		end
		return false
	end,

	SetHeroStaticDamage = function(self, args)
		local s = self.HeroStaticDamage[args.From.charName]
		if s then
			s(args)
		end
	end,

	SetItemStaticDamage = function(self, id, args)
		local s = self.ItemStaticDamage[id]
		if s and (args.From.charName ~= "Zeri" or id == 3144) then
			s(args)
		end
	end,

	SetHeroPassiveDamage = function(self, args)
		local s = self.HeroPassiveDamage[args.From.charName]
		if s then
			s(args)
		end
	end,

	SetItemPassiveDamage = function(self, id, args)
		local s = self.ItemPassiveDamage[id]
		if s and (args.From.charName ~= "Zeri" or id == 6699) then
			s(args)
		end
	end,

	CalculateDamage = function(self, from, target, damageType, rawDamage, isAbility, isAutoAttackOrTargetted)
		if from == nil or target == nil then
			return 0
		end
		if isAbility == nil then
			isAbility = true
		end
		if isAutoAttackOrTargetted == nil then
			isAutoAttackOrTargetted = false
		end
		local fromIsMinion = from.type == Obj_AI_Minion
		local targetIsMinion = target.type == Obj_AI_Minion
		local baseResistance = 0
		local bonusResistance = 0
		local penetrationFlat = 0
		local penetrationPercent = 0
		local bonusPenetrationPercent = 0
		if damageType == DAMAGE_TYPE_PHYSICAL then
			baseResistance = target.armor - target.bonusArmor
			bonusResistance = target.bonusArmor
			penetrationFlat = from.armorPen
			penetrationPercent = from.armorPenPercent
			bonusPenetrationPercent = from.bonusArmorPenPercent
			-- Minions return wrong percent values.
			if fromIsMinion then
				penetrationFlat = 0
				penetrationPercent = 0
				bonusPenetrationPercent = 0
			elseif from.type == Obj_AI_Turret then
				penetrationPercent = self:IsBaseTurret(from.charName) and 0.75 or 0.3
				penetrationFlat = 0
				bonusPenetrationPercent = 0
			end
		elseif damageType == DAMAGE_TYPE_MAGICAL then
			baseResistance = target.magicResist - target.bonusMagicResist
			bonusResistance = target.bonusMagicResist
			penetrationFlat = from.magicPen
			penetrationPercent = from.magicPenPercent
			bonusPenetrationPercent = 0
		elseif damageType == DAMAGE_TYPE_TRUE then
			return rawDamage
		end
		local resistance = baseResistance + bonusResistance
		if resistance > 0 then
			if penetrationPercent > 0 then
				baseResistance = baseResistance * penetrationPercent
				bonusResistance = bonusResistance * penetrationPercent
			end
			if bonusPenetrationPercent > 0 then
				bonusResistance = bonusResistance * bonusPenetrationPercent
			end
			resistance = baseResistance + bonusResistance
			resistance = math_max(0, resistance - penetrationFlat)
		end
		local percentMod = 1
		-- Penetration cant reduce resistance below 0.
		if resistance >= 0 then
			percentMod = percentMod * (100 / (100 + resistance))
		else
			percentMod = percentMod * (2 - 100 / (100 - resistance))
		end
		local flatPassive = 0
		local percentPassive = 1
		if fromIsMinion and targetIsMinion then
			percentPassive = percentPassive * (1 + from.bonusDamagePercent)
		end
		local flatReceived = 0
		if not isAbility and targetIsMinion then
			flatReceived = flatReceived - target.flatDamageReduction
		end
		return math_max(percentPassive * percentMod * (rawDamage + flatPassive) + flatReceived, 0)
	end,

	GetStaticAutoAttackDamage = function(self, from, targetIsMinion)
		local args = {
			From = from,
			RawTotal = from.totalDamage,
			RawPhysical = 0,
			RawMagical = 0,
			CalculatedTrue = 0,
			CalculatedPhysical = 0,
			CalculatedMagical = 0,
			DamageType = DAMAGE_TYPE_PHYSICAL,
			TargetIsMinion = targetIsMinion,
		}

		self:SetHeroStaticDamage(args)
		local HashSet = {}
		for i = 1, #ItemSlots do
			local slot = ItemSlots[i]
			local item = Item:GetSnapshot(args.From).slots[slot]
			if item ~= nil and item.itemID > 0 then
				if HashSet[item.itemID] == nil then
					self:SetItemStaticDamage(item.itemID, args)
					HashSet[item.itemID] = true
				end
			end
		end
		return args
	end,

	GetHeroAutoAttackDamage = function(self, from, target, static)
		local args = {
			From = from,
			Target = target,
			RawTotal = static.RawTotal,
			RawPhysical = static.RawPhysical,
			RawMagical = static.RawMagical,
			CalculatedTrue = static.CalculatedTrue,
			CalculatedPhysical = static.CalculatedPhysical,
			CalculatedMagical = static.CalculatedMagical,
			DamageType = static.DamageType,
			TargetIsMinion = target.type == Obj_AI_Minion,
			CriticalStrike = false,
		}
		if args.TargetIsMinion and args.Target.maxHealth <= 6 then
			return 1
		end
		self:SetHeroPassiveDamage(args)
		local HashSet = {}
		for i = 1, #ItemSlots do
			local slot = ItemSlots[i]
			local item = Item:GetSnapshot(args.From).slots[slot]
			if item ~= nil and item.itemID > 0 then
				if HashSet[item.itemID] == nil then
					self:SetItemPassiveDamage(item.itemID, args)
					HashSet[item.itemID] = true
				end
			end
		end
		local percentMod = 1
		if args.From.critChance - 1 == 0 or args.CriticalStrike then
			percentMod = percentMod * self:GetCriticalStrikePercent(args.From)
		end
		args.RawTotal = args.RawTotal * percentMod
		args.RawPhysical = args.RawPhysical + args.RawTotal
		if args.RawPhysical > 0 then
			args.CalculatedPhysical = args.CalculatedPhysical
				+ self:CalculateDamage(
					from,
					target,
					DAMAGE_TYPE_PHYSICAL,
					args.RawPhysical,
					false,
					args.DamageType == DAMAGE_TYPE_PHYSICAL
				)
		end
		if args.RawMagical > 0 then
			args.CalculatedMagical = args.CalculatedMagical
				+ self:CalculateDamage(
					from,
					target,
					DAMAGE_TYPE_MAGICAL,
					args.RawMagical,
					false,
					args.DamageType == DAMAGE_TYPE_MAGICAL
				)
		end
		-- Focus passive from Doran items and Tear of the Goddess
		if args.TargetIsMinion and args.Target.maxHealth > 6 then
			if Item:HasItem(from, 1054) or Item:HasItem(from, 1056) or Item:HasItem(from, 3070) or Item:HasItem(from, 1120) then
				args.CalculatedPhysical = args.CalculatedPhysical + 5
			end
		end
		return args.CalculatedPhysical + args.CalculatedMagical + args.CalculatedTrue
	end,

	GetAutoAttackDamage = function(self, from, target, respectPassives, staticDamage)
		if respectPassives == nil then
			respectPassives = true
		end
		if from == nil or target == nil then
			return 0
		end
		local targetIsMinion = target.type == Obj_AI_Minion
		if respectPassives and from.type == Obj_AI_Hero then
			local static = staticDamage or self:GetStaticAutoAttackDamage(from, targetIsMinion)
			if from.charName=="Graves" then
				if target.distance<target.boundingRadius/0.212 then
					return self:GetHeroAutoAttackDamage(from, target, static)*2
				end
				return self:GetHeroAutoAttackDamage(from, target, static)*1.33
			end
			return self:GetHeroAutoAttackDamage(from, target, static)
		end

		if targetIsMinion then
			if target.maxHealth <= 6 then
				return 1
			end
			if from.type == Obj_AI_Turret and not self:IsBaseTurret(from.charName) then
				local percentMod = self.TurretToMinionPercent[target.charName]
				if percentMod ~= nil then
					return target.maxHealth * percentMod
				end
			end
		end
		return self:CalculateDamage(from, target, DAMAGE_TYPE_PHYSICAL, from.totalDamage, false, true)
	end,

	GetCriticalStrikePercent = function(self, from)
		local heroName = from.charName
		local baseCriticalDamage = 2.0
		local percentMod = 1
		if Item:HasItem(from, 773031) then
			baseCriticalDamage = 2.5
		elseif Item:HasItem(from, 3031) then
			baseCriticalDamage = 2.3
		end
		if heroName == "Ashe" then
			baseCriticalDamage = 1.0
		elseif heroName == "Jhin" then
			percentMod = 0.75
		elseif heroName == "Senna" then
			percentMod = 0.8
		elseif heroName == "Yasuo" or heroName == "Yone" then
			percentMod = 0.95
		end
		return baseCriticalDamage * percentMod
	end,
}

Data = {

	JungleTeam = 300,
	AllyTeam = myHero.team,
	EnemyTeam = 300 - myHero.team,
	HeroName = myHero.charName,

	ChannelingBuffs = {
		["Caitlyn"] = function()
			return Buff:HasBuff(myHero, "CaitlynAceintheHole")
		end,
		["FiddleSticks"] = function()
			return Buff:HasBuff(myHero, "Drain") or Buff:HasBuff(myHero, "Crowstorm")
		end,
		["Galio"] = function()
			return Buff:HasBuff(myHero, "GalioIdolOfDurand")
		end,
		["Janna"] = function()
			return Buff:HasBuff(myHero, "ReapTheWhirlwind")
		end,
		["Kaisa"] = function()
			return Buff:HasBuff(myHero, "KaisaE")
		end,
		["Karthus"] = function()
			return Buff:HasBuff(myHero, "karthusfallenonecastsound")
		end,
		["Katarina"] = function()
			return Buff:HasBuff(myHero, "katarinarsound")
		end,
		["Lucian"] = function()
			return Buff:HasBuff(myHero, "LucianR")
		end,
		["Malzahar"] = function()
			return Buff:HasBuff(myHero, "alzaharnethergraspsound")
		end,
		["MissFortune"] = function()
			return Buff:HasBuff(myHero, "missfortunebulletsound")
		end,
		["Nunu"] = function()
			return Buff:HasBuff(myHero, "AbsoluteZero")
		end,
		["Pantheon"] = function()
			return Buff:HasBuff(myHero, "pantheonesound") or Buff:HasBuff(myHero, "PantheonRJump")
		end,
		["Shen"] = function()
			return Buff:HasBuff(myHero, "shenstandunitedlock")
		end,
		["TwistedFate"] = function()
			return Buff:HasBuff(myHero, "Destiny")
		end,
		["Urgot"] = function()
			return Buff:HasBuff(myHero, "UrgotSwap2")
		end,
		["Varus"] = function()
			return Buff:HasBuff(myHero, "VarusQ")
		end,
		["Velkoz"] = function()
			return Buff:HasBuff(myHero, "VelkozR")
		end,
		["Vi"] = function()
			return Buff:HasBuff(myHero, "ViQ")
		end,
		["Vladimir"] = function()
			return Buff:HasBuff(myHero, "VladimirE")
		end,
		["Warwick"] = function()
			return Buff:HasBuff(myHero, "infiniteduresssound")
		end,
		["Xerath"] = function()
			return Buff:HasBuff(myHero, "XerathArcanopulseChargeUp") or Buff:HasBuff(myHero, "XerathLocusOfPower2")
		end,
	},

	SpecialWindup = {
		["Yunara"] = function()
			if Buff:HasBuff(myHero, "YunaraQ") then
				return 0.09
			end
			return nil
		end,
		["TwistedFate"] = function()
			if
				Buff:HasBuff(myHero, "BlueCardPreAttack")
				or Buff:HasBuff(myHero, "RedCardPreAttack")
				or Buff:HasBuff(myHero, "GoldCardPreAttack")
			then
				return 0.125
			end
			return nil
		end,
		["Jayce"] = function()
			if Buff:HasBuff(myHero, "JayceHyperCharge") then
				return 0.125
			end
			return nil
		end,
		["Aphelios"] = function()
			if Buff:HasBuff(myHero, "ApheliosCrescendumManager") then
				local spell = myHero.activeSpell
				if spell and spell.valid and spell.name == "ApheliosCrescendumAttack" then
					return spell.windup
				end
				return 0.1067 / Attack:GetAttackSpeed()
			end
			return nil
		end,
	},

	AllowMovement = {
		["Kaisa"] = function()
			return Buff:HasBuff(myHero, "KaisaE")
		end,
		["Lucian"] = function()
			return Buff:HasBuff(myHero, "LucianR")
		end,
		["Varus"] = function()
			return Buff:HasBuff(myHero, "VarusQ")
		end,
		["Vi"] = function()
			return Buff:HasBuff(myHero, "ViQ")
		end,
		["Vladimir"] = function()
			return Buff:HasBuff(myHero, "VladimirE")
		end,
		["Xerath"] = function()
			return Buff:HasBuff(myHero, "XerathArcanopulseChargeUp")
		end,
	},

	DisableAttackBuffs = {
		["Renata"] = function()
			return Buff:HasBuff(myHero, "renataqselfroot") or Buff:HasBuff(myHero, "RenataQRecast")
		end,
		["Urgot"] = function()
			return Buff:HasBuff(myHero, "UrgotW")
		end,
		["Darius"] = function()
			return Buff:HasBuff(myHero, "dariusqcast")
		end,
		["Graves"] = function()
			if myHero.hudAmmo == 0 then
				return true
			end
			return false
		end,
		["Jhin"] = function()
			if myHero.hudAmmo == 0 then
				return true
			end
			return false
		end,
	},

	SpecialMissileSpeeds = {
		["Kaisa"] = function()
			if Buff:HasBuff(myHero, "kaisaeattackspeed") then
				return 2500
			end
			return nil
		end,
		["Yunara"] = function()
			if Buff:HasBuff(myHero, "YunaraQ") then
				return 10000
			end
			return nil
		end,
		["Hwei"] = function()
			return 2800
		end,
		["Aphelios"] = function()
			if Buff:HasBuff(myHero, "ApheliosCrescendumManager") then
				return 3500
			elseif Buff:HasBuff(myHero, "ApheliosCalibrumManager") then
				return 3000
			elseif Buff:HasBuff(myHero, "ApheliosInfernumManager") then
				return 1700
			elseif Buff:HasBuff(myHero, "ApheliosSeverumManager") then
				return math.huge
			end
			return 1500
		end,
		["Caitlyn"] = function()
			if Buff:HasBuff(myHero, "caitlynpassivedriver") then
				return 3000
			end
			return nil
		end,
		["Graves"] = function()
			return 3800
		end,
		["Seraphine"] = function()
			return 1800
		end,
		["Anivia"] = function()
			return 1600
		end,
		["Illaoi"] = function()
			if Buff:HasBuff(myHero, "IllaoiW") then
				return 1600
			end
			return nil
		end,
		["Jayce"] = function()
			if myHero:GetSpellData(_Q).name=="JayceShockBlast" then
				return 2000
			end
			return nil
		end,
        ["Viktor"] = function()
            if Buff:HasBuff(myHero, "ViktorQReturn") then
                return 5000
            end
            return nil
        end,
		["Jhin"] = function()
			if myHero.hudAmmo==1 then
				return 3000
			end
			return nil
		end,
		["Jinx"] = function()
			if Buff:HasBuff(myHero, "JinxQ") then
				return 2000
			end
			return nil
		end,
		["Poppy"] = function()
			if Buff:HasBuff(myHero, "poppypassivebuff") then
				return 1600
			end
			return nil
		end,
		["Twitch"] = function()
			if Buff:HasBuff(myHero, "TwitchFullAutomatic") then
				return 5000
			end
			return nil
		end,
		["Kayle"] = function()
			if Buff:HasBuff(myHero, "KayleE") then
				return 1750
			end
			return nil
		end,
	},

	--26.17
	-- priority, melee, base attack speed, optional attack speed ratio
	HEROES = {
		Aatrox = { 3, true, 0.651 },
		Ahri = { 4, false, 0.668, 0.625 },
		Akali = { 4, true, 0.625 },
		Akshan = { 5, false, 0.638, 0.4 },
		Alistar = { 1, true, 0.625 },
		Ambessa = { 2, true, 0.625 },
		Amumu = { 1, true, 0.736, 0.638 },
		Anivia = { 4, false, 0.658, 0.625 },
		Annie = { 4, false, 0.61, 0.625 },
		Aphelios = { 5, false, 0.665, 0.658 },
		Ashe = { 5, false, 0.658 },
		AurelionSol = { 4, false, 0.625 },
		Aurora = { 4, false, 0.668 },
		Azir = { 4, true, 0.625, 0.694 },
		Bard = { 3, false, 0.658 },
		Belveth = { 4, true, 0.67 },
		Blitzcrank = { 1, true, 0.625 },
		Brand = { 4, false, 0.681, 0.625 },
		Braum = { 1, true, 0.644 },
		Briar = { 4, true, 0.644, 0.669 },
		Caitlyn = { 5, false, 0.681, 0.625 },
		Camille = { 3, true, 0.644 },
		Cassiopeia = { 4, false, 0.647 },
		Chogath = { 1, true, 0.658, 0.625 },
		Corki = { 5, false, 0.644 },
		Darius = { 2, true, 0.625 },
		Diana = { 4, true, 0.625, 0.694 },
		DrMundo = { 1, true, 0.67, 0.625 },
		Draven = { 5, false, 0.679 },
		Ekko = { 4, true, 0.688, 0.625 },
		Elise = { 3, false, 0.625 },
		Evelynn = { 4, true, 0.667 },
		Ezreal = { 5, false, 0.625 },
		FiddleSticks = { 3, false, 0.625 },
		Fiora = { 3, true, 0.69 },
		Fizz = { 4, true, 0.658 },
		Galio = { 1, true, 0.625 },
		Gangplank = { 4, true, 0.658, 0.69 },
		Garen = { 1, true, 0.625 },
		Gnar = { 1, false, 0.625 },
		Gragas = { 2, true, 0.675, 0.625 },
		Graves = { 4, false, 0.475, 0.49 },
		Gwen = { 4, true, 0.69 },
		Hecarim = { 2, true, 0.67 },
		Heimerdinger = { 3, false, 0.658, 0.625 },
		Hwei = { 4, false, 0.69, 0.658 },
		Illaoi = { 3, true, 0.625 },
		Irelia = { 3, true, 0.656 },
		Ivern = { 1, true, 0.644 },
		Janna = { 2, false, 0.625 },
		JarvanIV = { 3, true, 0.658 },
		Jax = { 3, true, 0.638 },
		Jayce = { 4, false, 0.658 },
		Jhin = { 5, false, 0.625, 0 },
		Jinx = { 5, false, 0.625 },
		KSante = { 1, true, 0.688, 0.625 },
		Kaisa = { 5, false, 0.644 },
		Kalista = { 5, false, 0.694 },
		Karma = { 4, false, 0.625 },
		Karthus = { 4, false, 0.625 },
		Kassadin = { 4, true, 0.64 },
		Katarina = { 4, true, 0.658 },
		Kayle = { 4, false, 0.625, 0.667 },
		Kayn = { 4, true, 0.669 },
		Kennen = { 4, false, 0.625, 0.69 },
		Khazix = { 4, true, 0.668 },
		Kindred = { 4, false, 0.625 },
		Kled = { 2, true, 0.625 },
		KogMaw = { 5, false, 0.665 },
		Leblanc = { 4, false, 0.658, 0.625 },
		LeeSin = { 3, true, 0.651 },
		Leona = { 1, true, 0.625 },
		Lillia = { 4, false, 0.625 },
		Lissandra = { 4, false, 0.656, 0.625 },
		Locke = { 4, true, 0.688, 0.625 },
		Lucian = { 5, false, 0.638 },
		Lulu = { 3, false, 0.625 },
		Lux = { 4, false, 0.669, 0.625 },
		Malphite = { 1, true, 0.736, 0.638 },
		Malzahar = { 3, false, 0.625 },
		Maokai = { 2, true, 0.8, 0.695 },
		MasterYi = { 5, true, 0.679 },
		Mel = { 4, false, 0.625 },
		Milio = { 3, false, 0.625 },
		MissFortune = { 5, false, 0.656 },
		MonkeyKing = { 3, true, 0.69, 0.658 },
		Mordekaiser = { 4, true, 0.625 },
		Morgana = { 3, false, 0.625 },
		Naafiri = { 4, true, 0.663, 0.625 },
		Nami = { 3, false, 0.644 },
		Nasus = { 2, true, 0.638 },
		Nautilus = { 1, true, 0.706, 0.612 },
		Neeko = { 4, false, 0.625, 0.67 },
		Nidalee = { 4, false, 0.638 },
		Nilah = { 5, true, 0.697, 0.67 },
		Nocturne = { 4, true, 0.721 },
		Nunu = { 2, true, 0.625 },
		Olaf = { 2, true, 0.72, 0.694 },
		Orianna = { 4, false, 0.658 },
		Ornn = { 2, true, 0.625 },
		Pantheon = { 3, true, 0.658 },
		Poppy = { 2, true, 0.658, 0.625 },
		Pyke = { 4, true, 0.667 },
		Qiyana = { 4, true, 0.688, 0.625 },
		Quinn = { 5, false, 0.668 },
		Rakan = { 3, true, 0.635 },
		Rammus = { 1, true, 0.7, 0.625 },
		RekSai = { 2, true, 0.667 },
		Rell = { 1, true, 0.625 },
		Renata = { 2, false, 0.625 },
		Renekton = { 2, true, 0.665 },
		Rengar = { 4, true, 0.667 },
		Riven = { 4, true, 0.625 },
		Rumble = { 4, true, 0.644 },
		Ryze = { 4, false, 0.658, 0.625 },
		Samira = { 5, false, 0.658 },
		Sejuani = { 2, true, 0.688, 0.625 },
		Senna = { 5, false, 0.625, 0.4 },
		Seraphine = { 3, false, 0.669, 0.625 },
		Sett = { 2, true, 0.625 },
		Shaco = { 4, true, 0.694 },
		Shen = { 1, true, 0.751, 0.651 },
		Shyvana = { 2, true, 0.638 },
		Singed = { 1, true, 0.7, 0.625 },
		Sion = { 1, true, 0.679 },
		Sivir = { 5, false, 0.625 },
		Skarner = { 2, true, 0.625 },
		Smolder = { 5, false, 0.638 },
		Sona = { 3, false, 0.644 },
		Soraka = { 3, false, 0.625 },
		Swain = { 3, false, 0.625 },
		Sylas = { 4, true, 0.645 },
		Syndra = { 4, false, 0.658, 0.625 },
		TahmKench = { 1, true, 0.658 },
		Taliyah = { 4, false, 0.658, 0.625 },
		Talon = { 4, true, 0.625 },
		Taric = { 1, true, 0.625 },
		Teemo = { 4, false, 0.69 },
		Thresh = { 1, true, 0.625 },
		Tristana = { 5, false, 0.656, 0.694 },
		Trundle = { 2, true, 0.67 },
		Tryndamere = { 4, true, 0.67, 0.725 },
		TwistedFate = { 4, false, 0.625, 0.651 },
		Twitch = { 5, false, 0.679 },
		Udyr = { 2, true, 0.65 },
		Urgot = { 2, true, 0.625 },
		Varus = { 5, false, 0.658 },
		Vayne = { 5, false, 0.658, 0.67 },
		Veigar = { 4, false, 0.625 },
		Velkoz = { 4, false, 0.643, 0.625 },
		Vex = { 4, false, 0.669, 0.625 },
		Vi = { 2, true, 0.644 },
		Viego = { 4, true, 0.658 },
		Viktor = { 4, false, 0.658 },
		Vladimir = { 3, false, 0.658 },
		Volibear = { 2, true, 0.625, 0.7 },
		Warwick = { 2, true, 0.638 },
		Xayah = { 5, false, 0.658 },
		Xerath = { 4, false, 0.658, 0.625 },
		XinZhao = { 3, true, 0.645 },
		Yasuo = { 4, true, 0.697, 0.67 },
		Yone = { 4, true, 0.625 },
		Yorick = { 2, true, 0.625 },
		Yunara = { 5, false, 0.65 },
		Yuumi = { 3, false, 0.625 },
		Zaahen = { 4, true, 0.625 },
		Zac = { 1, true, 0.736, 0.638 },
		Zed = { 4, true, 0.651 },
		Zeri = { 5, false, 0.658, 0.625 },
		Ziggs = { 4, false, 0.656 },
		Zilean = { 3, false, 0.658, 0.625 },
		Zoe = { 4, false, 0.658, 0.625 },
		Zyra = { 2, false, 0.681, 0.625 },
		-- Classic
		Jade_Ahri = { 4, false, 0.668 },
		Jade_Akali = { 4, true, 0.694 },
		Jade_Alistar = { 1, true, 0.625 },
		Jade_Amumu = { 1, true, 0.638 },
		Jade_Anivia = { 4, false, 0.625 },
		Jade_Annie = { 4, false, 0.579 },
		Jade_Ashe = { 5, false, 0.658 },
		Jade_Blitzcrank = { 1, true, 0.625 },
		Jade_Brand = { 4, false, 0.625 },
		Jade_Chogath = { 1, true, 0.625 },
		Jade_Corki = { 5, false, 0.658 },
		Jade_DrMundo = { 1, true, 0.625 },
		Jade_Evelynn = { 4, true, 0.625 },
		Jade_Ezreal = { 5, false, 0.658 },
		Jade_Fiddlesticks = { 3, false, 0.625 },
		Jade_Gangplank = { 4, true, 0.651 },
		Jade_Garen = { 1, true, 0.625 },
		Jade_Gragas = { 2, true, 0.651 },
		Jade_Heimerdinger = { 3, false, 0.625 },
		Jade_Janna = { 2, false, 0.625 },
		Jade_JarvanIV = { 3, true, 0.658 },
		Jade_Jax = { 3, true, 0.638 },
		Jade_Karthus = { 4, false, 0.625 },
		Jade_Kassadin = { 4, true, 0.64 },
		Jade_Katarina = { 4, true, 0.658 },
		Jade_Kayle = { 4, false, 0.638 },
		Jade_Kennen = { 4, false, 0.69 },
		Jade_KogMaw = { 5, false, 0.665 },
		Jade_LeeSin = { 3, true, 0.651 },
		Jade_Leona = { 1, true, 0.625 },
		Jade_Lulu = { 3, false, 0.625 },
		Jade_Lux = { 4, false, 0.625 },
		Jade_Malphite = { 1, true, 0.638 },
		Jade_Malzahar = { 3, false, 0.625 },
		Jade_MasterYi = { 5, true, 0.679 },
		Jade_MissFortune = { 5, false, 0.656 },
		Jade_Morgana = { 3, false, 0.579 },
		Jade_Nasus = { 2, true, 0.638 },
		Jade_Nidalee = { 4, false, 0.67 },
		Jade_Nunu = { 2, true, 0.625 },
		Jade_Olaf = { 2, true, 0.694 },
		Jade_Pantheon = { 3, true, 0.679 },
		Jade_Rammus = { 1, true, 0.625 },
		Jade_Ryze = { 4, false, 0.625 },
		Jade_Shaco = { 4, true, 0.694 },
		Jade_Shen = { 1, true, 0.651 },
		Jade_Singed = { 1, true, 0.613 },
		Jade_Sion = { 1, true, 0.625 },
		Jade_Sivir = { 5, false, 0.679 },
		Jade_Skarner = { 2, true, 0.625 },
		Jade_Sona = { 3, false, 0.644 },
		Jade_Soraka = { 3, false, 0.625 },
		Jade_Taric = { 1, true, 0.625 },
		Jade_Teemo = { 4, false, 0.69 },
		Jade_Tristana = { 5, false, 0.656 },
		Jade_Tryndamere = { 4, true, 0.67 },
		Jade_TwistedFate = { 4, false, 0.651 },
		Jade_Twitch = { 5, false, 0.679 },
		Jade_Vayne = { 5, false, 0.658 },
		Jade_Veigar = { 4, false, 0.625 },
		Jade_Warwick = { 2, true, 0.644 },
		Jade_Wukong = { 3, true, 0.658 },
		Jade_Zilean = { 3, false, 0.625 },
	},

	HeroSpecialMelees = {
		["Elise"] = function()
			return myHero.range < 200
		end,
		["Gnar"] = function()
			return myHero.range < 200
		end,
		["Jayce"] = function()
			return myHero.range < 200
		end,
		["Kayle"] = function()
			return myHero.range < 200
		end,
		["Nidalee"] = function()
			return myHero.range < 200
		end,
		["Jade_Kayle"] = function()
			return myHero.range < 200
		end,
		["Jade_Nidalee"] = function()
			return myHero.range < 200
		end,
	},

	IsAttackSpell = {
		["TrundleQ"] = true,
		["YunaraQCrit"] = true,
		["YunaraQCrit2"] = true,
		["ViktorQBuff"] = true,
		["CaitlynPassiveMissile"] = true,
		["GarenQAttack"] = true,
		["KennenMegaProc"] = true,
		["QuinnWEnhanced"] = true,
		["RenektonSuperExecute"] = true,
		["RenektonExecute"] = true,
		["XinZhaoQThrust1"] = true,
		["XinZhaoQThrust2"] = true,
		["XinZhaoQThrust3"] = true,
		["MasterYiDoubleStrike"] = true,
		["Jade_MasterYiDoubleStrike"] = true,
	},

	IsNotAttack = {
		["GravesAutoAttackRecoil"] = true,
		["LeonaShieldOfDaybreakAttack"] = true,
		["Jade_LeonaShieldOfDaybreakAttack"] = true,
		["ShyvanaQAttack"] = true,
		["ShyvanaQAttackDragon"] = true,
		["ShyvanaQAttackDragon2"] = true,
		["VolibearQAttack"] = true,
	},

	MinionRange = {
		["SRU_ChaosMinionMelee"] = 110,
		["SRU_ChaosMinionRanged"] = 550,
		["SRU_ChaosMinionSiege"] = 300,
		["SRU_ChaosMinionSuper"] = 170,
		["SRU_OrderMinionMelee"] = 110,
		["SRU_OrderMinionRanged"] = 550,
		["SRU_OrderMinionSiege"] = 300,
		["SRU_OrderMinionSuper"] = 170,
		["HA_ChaosMinionMelee"] = 110,
		["HA_ChaosMinionRanged"] = 550,
		["HA_ChaosMinionSiege"] = 300,
		["HA_ChaosMinionSuper"] = 170,
		["HA_OrderMinionMelee"] = 110,
		["HA_OrderMinionRanged"] = 550,
		["HA_OrderMinionSiege"] = 300,
		["HA_OrderMinionSuper"] = 170,
	},

	CaitlynConsumedMarks = { E = {}, W = {} },

	ExtraAttackRanges = {
		["Aphelios"] = function(target)
			if
				target
				and Buff:HasBuff(myHero, "aphelioscalibrumbonusrangebuff")
				and Buff:HasBuff(target, "aphelioscalibrumbonusrangedebuff")
			then
				return math_max(0, 1800 - myHero.range - myHero.boundingRadius - target.boundingRadius)
			end
			return 0
		end,
		["Caitlyn"] = function(target)
			if not target then
				return 0
			end

			local targetID = target.networkID
			local consumedMarks = Data.CaitlynConsumedMarks
			local eStartTime = Buff:GetBuffStartTime(target, "eternals_caitlyneheadshottracker")
			local wStartTime = Buff:GetBuffStartTime(target, "caitlynwsight")
			local hasEMark = eStartTime > 0 and consumedMarks.E[targetID] ~= eStartTime
			local hasWMark =
				wStartTime > 0
				and Buff:GetBuffDuration(target, "caitlynwsight") > 0.75
				and consumedMarks.W[targetID] ~= wStartTime
			if hasEMark or hasWMark then
				return math_max(0, 1300 - myHero.range - myHero.boundingRadius - target.boundingRadius)
			end
			return 0
		end,
	},

	ConsumeCaitlynMark = function(self, target)
		if not target then
			return
		end

		local targetID = target.networkID
		local eStartTime = Buff:GetBuffStartTime(target, "eternals_caitlyneheadshottracker")
		if eStartTime > 0 and self.CaitlynConsumedMarks.E[targetID] ~= eStartTime then
			self.CaitlynConsumedMarks.E[targetID] = eStartTime
			return
		end

		local wStartTime = Buff:GetBuffStartTime(target, "caitlynwsight")
		if wStartTime > 0 and self.CaitlynConsumedMarks.W[targetID] ~= wStartTime then
			self.CaitlynConsumedMarks.W[targetID] = wStartTime
		end
	end,

	AttackResets = {
		["Aatrox"] = { { Slot = _E, Key = HK_E, OnCast = true, CanCancel = true } },
		["Ashe"] = { { Slot = _Q, Key = HK_Q  } },
		["Blitzcrank"] = { { Slot = _E, Key = HK_E } },
		["Camille"] = { { Slot = _Q, Key = HK_Q } },
		["Chogath"] = { { Slot = _E, Key = HK_E } },
		["Darius"] = { { Slot = _W, Key = HK_W } },
		["DrMundo"] = { { Slot = _E, Key = HK_E } },
		["Ekko"] = { { Slot = _E, Key = HK_E, Buff = { ["ekkoeattackbuff"] = true }, CanCancel = true } },
		["Elise"] = { { Slot = _W, Key = HK_W, Name = "EliseSpiderW" } },
		["Fiora"] = { { Slot = _E, Key = HK_E } },
		["Fizz"] = { { Slot = _W, Key = HK_W } },
		["Garen"] = { { Slot = _Q, Key = HK_Q } },
		["Graves"] = { { Slot = _E, Key = HK_E, OnCast = true, CanCancel = true } },
		["Gwen"] = {{ Slot = _E, Key = HK_E, OnCast = true, CanCancel = true } },
		["Kassadin"] = {{ Slot = _W, Key = HK_W } },
		["Illaoi"] = { { Slot = _W, Key = HK_W } },
		["Jax"] = { { Slot = _W, Key = HK_W } },
		["Jayce"] = { { Slot = _W, Key = HK_W, Name = "JayceHyperCharge" } },
		["KSante"] = { { Slot = _Q, Key = HK_Q } },
		["Kayle"] = { { Slot = _E, Key = HK_E } },
		["Katarina"] = { { Slot = _E, Key = HK_E, CanCancel = true, OnCast = true } },
		["Kindred"] = { { Slot = _Q, Key = HK_Q, OnCast = true, CanCancel = true } },
		["Leona"] = { { Slot = _Q, Key = HK_Q } },
		["Jade_Leona"] = { { Slot = _Q, Key = HK_Q } },
		["Lucian"] = { { Slot = _E, Key = HK_E, OnCast = true, CanCancel = true } },
		["Malphite"] = { { Slot = _W, Key = HK_W } },		
		["MasterYi"] = { { Slot = _W, Key = HK_W } },
		["Nasus"] = { { Slot = _Q, Key = HK_Q } },
		["Nautilus"] = { { Slot = _W, Key = HK_W } },
		["Nilah"] = { { Slot = _E, Key = HK_E, OnCast = true, CanCancel = true } },
		["Nidalee"] = { { Slot = _Q, Key = HK_Q, Name = "Takedown" } },
		["Olaf"] = { { Slot = _W, Key = HK_W } },
		["Quinn"] = { { Slot = _E, Key = HK_E, OnCast = true, CanCancel = true } },
		["RekSai"] = { { Slot = _Q, Key = HK_Q, Name = "RekSaiQ" } },
		["Renekton"] = { { Slot = _W, Key = HK_W } },
		["Rengar"] = { { Slot = _Q, Key = HK_Q } },
		["Sejuani"] = { { Slot = _E, Key = HK_E, ActiveCheck = true, SpellName = "SejuaniE2" } },
		["Sett"] = {{ Slot = _Q, Key = HK_Q } },
		["Shyvana"] = {{ Slot = _Q, Key = HK_Q } },
		["Sivir"] = { { Slot = _W, Key = HK_W } },
		["Talon"] = { { Slot = _Q, Key = HK_Q, OnCast = true, CanCancel = true } },
		["Trundle"] = { { Slot = _Q, Key = HK_Q } },
		["TwistedFate"] = {
			{ Slot = _W, Key = HK_W, CanCancel = true, Name = "GoldCardLock", Buff = { ["goldcardpreattack"] = true } },
			{ Slot = _W, Key = HK_W, CanCancel = true, Name = "BlueCardLock", Buff = { ["bluecardpreattack"] = true } },
			{ Slot = _W, Key = HK_W, CanCancel = true, Name = "RedCardLock", Buff = { ["redcardpreattack"] = true } },
		},
		["Vayne"] = { { Slot = _Q, Key = HK_Q, Buff = { ["vaynetumblebonus"] = true }, CanCancel = true }},
		["Jade_Vayne"] = { { Slot = _Q, Key = HK_Q, Buff = { ["jade_vayneq_bonus"] = true }, CanCancel = true }},
		["Vi"] = { { Slot = _E, Key = HK_E } },
		["Volibear"] = { { Slot = _Q, Key = HK_Q } },
		["MonkeyKing"] = { { Slot = _Q, Key = HK_Q } },
		["XinZhao"] = { { Slot = _Q, Key = HK_Q } },
		["Yorick"] = { { Slot = _Q, Key = HK_Q, Name = "YorickQ" } },
		["Yunara"] = {
			{ Slot = _Q, Key = HK_Q },
			{ Slot = _E, Key = HK_E, Name = "YunaraE2", CanCancel = true, OnCast = true },
			{ Slot = _R, Key = HK_R, BlockBuff = "yunaraq" },
		},
		["Zaahen"] = {
			{ Slot = _Q, Key = HK_Q, Name = "ZaahenQ" },
			{ Slot = _Q, Key = HK_Q, Name = "ZaahenQ2" },
		},
	},
	-- AA reset logic updated by zgjfjfl.
	WndMsg = function(self, msg, wParam)
		if self.AttackResetsList == nil then
			return
		end

		if msg ~= KEY_DOWN and msg ~= KEY_UP then
			return
		end

		if self.AttackResetSuccess or Control.IsKeyDown(HK_LUS) or GameIsChatOpen() then
			return
		end

		for _, AttackReset in ipairs(self.AttackResetsList) do
			if wParam == AttackReset.Key then
				--Add a 600ms cooldown to prevent spamming the reset key
				if GetTickCount() <= self.AttackResetKeyTimer + 600 then return end

				if AttackReset.BlockBuff and Buff:HasBuff(myHero, AttackReset.BlockBuff) then return end

				local spellData = myHero:GetSpellData(AttackReset.Slot)
				if 
					spellData.level > 0 and GameCanUseSpell(AttackReset.Slot) == 0 
					and (not AttackReset.Name or spellData.name == AttackReset.Name)
				then
					--print('Reset Spell.name: ' .. spellData.name)
					self.AttackResetKeyTimer = GetTickCount()
					if AttackReset.ActiveCheck then -- Preserve the original logic For Sejuani E
						local startTime = GetTickCount() + 400
						Action:Add(function()
							local s = myHero.activeSpell
							if s and s.valid and s.name == AttackReset.SpellName then
								self.ActiveAttackReset = AttackReset
								return true
							end
							if GetTickCount() < startTime then
								return false
							end
							return true
						end)
						return
					end
					
					self.ActiveAttackReset = AttackReset -- to 'CanResetAttack()' processing. ('Attack.Reset' check it)
					return
				end
			end
		end
	end,

	CanResetAttack = function(self)
		if self.AttackResetsList == nil or self.ActiveAttackReset == nil then
			return false
		end
		if GetTickCount() > self.AttackResetKeyTimer + 1000 then
			self.ActiveAttackReset = nil
			return false
		end
		local config = self.ActiveAttackReset
		if config.CanCancel then
			if config.OnCast then
				local spellData = myHero:GetSpellData(config.Slot)
				local startTime = spellData.castTime - spellData.cd
				if GameTimer() - startTime > 0.075 and GameTimer() - startTime < 0.5 then
					self.AttackResetSuccess = true
					--print('OnCast Reset')
				end
			elseif config.Buff and Buff:ContainsBuffs(myHero, config.Buff) then
				self.AttackResetSuccess = true
				--print('Buff Reset')
			end
		else
			self.AttackResetSuccess = true
			--print('Quick Reset')
		end
		if self.AttackResetSuccess == true then
			self.AttackResetSuccess = false
			self.ActiveAttackReset = nil
			return true
		end
		return false
	end,

	IdEquals = function(self, a, b)
		if a == nil or b == nil then
			return false
		end
		return a.networkID == b.networkID
	end,

	GetAutoAttackRange = function(self, from, target)
		local result = from.range
		if from.charName == "Zeri" then
			result = 550
		end
		local fromType = from.type
		if fromType == Obj_AI_Minion then
			local fromName = from.charName
			result = self.MinionRange[fromName] ~= nil and self.MinionRange[fromName] or 0
		elseif fromType == Obj_AI_Turret then
			result = 750
		end
		if target then
			local targetType = target.type
			if targetType == Obj_AI_Barracks then
				result = result + 270
			elseif targetType == Obj_AI_Nexus then
				result = result + 380
			else
				result = result + from.boundingRadius + target.boundingRadius
				if from.networkID == myHero.networkID and targetType == Obj_AI_Hero and self.ExtraAttackRange then
					result = result + self.ExtraAttackRange(target)
				end
			end
		else
			result = result + from.boundingRadius + 35
		end
		return result
	end,

	IsInAutoAttackRange = function(self, from, target, extrarange)
		local range = extrarange or 0
		return IsInRange(from.pos, target.pos, self:GetAutoAttackRange(from, target) + range)
	end,

	IsInAutoAttackRange2 = function(self, from, target, extrarange)
		local range = self:GetAutoAttackRange(from, target) + (extrarange or 0)
		if IsInRange(from.pos, target.pos, range) and IsInRange(from.pos, target.posTo, range) then
			return true
		end
		return false
	end,

	IsAttack = function(self, name)
		if self.IsAttackSpell[name] then
			return true
		end
		if self.IsNotAttack[name] then
			return false
		end
		return name:lower():find("attack")
	end,

	GetLatency = function(self)
		return LATENCY * 0.001
	end,

	HeroCanMove = function(self)
		if self.IsChanneling and self.IsChanneling() then
			if self.CanAllowMovement == nil or (not self.CanAllowMovement()) then
				return false
			end
		end
		-- reduce spam clicks during hardCC
		if Buff:HasBuffTypes(myHero, self.HardCCMoveTypes) then
			return false
		end
		return true
	end,

	HeroCanAttack = function(self)
		if self.IsChanneling and self.IsChanneling() then
			return false
		end
		if myHero.pathing and myHero.pathing.isDashing then
			return false
		end
		local spell = myHero.activeSpell
		if
			spell
			and spell.valid
			and spell.castEndTime
			and spell.castEndTime > GameTimer()
			and not (spell.isAutoAttack or (spell.name and self:IsAttack(spell.name)))
		then
			return false
		end
		if self.CanDisableAttack and self.CanDisableAttack() then
			return false
		end
		-- reduce spam clicks during hardCC
		if Buff:HasBuffTypes(myHero, self.HardCCAttackTypes) then
			return false
		end
		return true
	end,

	IsMelee = function(self)
		if self.IsHeroMelee or (self.IsHeroSpecialMelee and self.IsHeroSpecialMelee()) then
			return true
		end
		return false
	end,

	GetTotalShield = function(self, obj)
		local shieldAd, shieldAp
		shieldAd = obj.shieldAD
		shieldAp = obj.shieldAP
		return (shieldAd and shieldAd or 0) + (shieldAp and shieldAp or 0)
	end,

	GetBuildingBBox = function(self, unit)
		local type = unit.type
		if type == Obj_AI_Barracks then
			return 270
		end
		if type == Obj_AI_Nexus then
			return 380
		end
		return 0
	end,

	Stop = function(self)
		return GameIsChatOpen()
			or (ExtLibEvade and ExtLibEvade.Evading)
			or (JustEvade and JustEvade.Evading())
			or (not GameIsOnTop())
	end,
}

do
local install=(function()
-- Identity comes from host hero objects. Static combat metadata is deliberately
-- incomplete and must never act as an allowlist for roster events or menus.
return function(Data,heroType)
    local priorities={}
    for name,row in pairs(Data.HEROES) do priorities[name:lower()]=row[1] end
    function Data:GetHeroPriority(name)
        if type(name)~='string' then return 5 end
        local exact=self.HEROES[name]
        if exact then return exact[1] end
        local key=name:lower()
        -- Reuse a UI default only. Do not inherit modern attack timings, damage,
        -- passive handlers or reset data for an unverified Classic champion.
        return priorities[key] or (key:sub(1,5)=='jade_' and priorities[key:sub(6)]) or 5
    end
    function Data:GetHeroData(obj)
        if not obj or obj.type~=heroType then return {} end
        local id,name,team=obj.networkID,obj.charName,obj.team
        if type(id)~='number' or id~=id or id<=0 or id==math.huge
            or type(name)~='string' or name=='' then return {} end
        if team~=100 and team~=200 then return {} end
        local enemy,ally=obj.isEnemy,obj.isAlly
        if type(enemy)~='boolean' or type(ally)~='boolean' or enemy==ally then return {} end
        -- Visibility, death and targetability are transient combat conditions;
        -- they must not prevent a roster entry or erase the user's priority.
        return {valid=true,isEnemy=enemy,isAlly=ally,networkID=id,charName=name,team=team,unit=obj}
    end
end

end)()
install(Data,Obj_AI_Hero)
end

Data.HardCCMoveTypes = { [5] = true, [8] = true, [9] = true, [12] = true, [23] = true, [25] = true, [29] = true, [30] = true, [31] = true, [35] = true }
Data.HardCCAttackTypes = { [5] = true, [8] = true, [9] = true, [23] = true, [25] = true, [29] = true, [30] = true, [31] = true, [32] = true, [35] = true }
if Data.HeroName ~= "Azir" then
	Data.HardCCAttackTypes[26] = true
end

Data.IsChanneling = Data.ChannelingBuffs[Data.HeroName]
Data.CanAllowMovement = Data.AllowMovement[Data.HeroName]
Data.CanDisableAttack = Data.DisableAttackBuffs[Data.HeroName]
Data.SpecialMissileSpeed = Data.SpecialMissileSpeeds[Data.HeroName]
Data.HeroData = Data.HEROES[Data.HeroName]
if Data.HeroData ~= nil then
	Data.IsHeroMelee = Data.HeroData[2]
else
	Data.IsHeroMelee = myHero.range < 300
end
Data.IsHeroSpecialMelee = Data.HeroSpecialMelees[Data.HeroName]
Data.ExtraAttackRange = Data.ExtraAttackRanges[Data.HeroName]
Data.AttackResetsList = Data.AttackResets[Data.HeroName]
if Data.AttackResetsList ~= nil then
	Data.AttackResetSuccess = false
	Data.AttackResetKeyTimer = 0
	Data.ActiveAttackReset = nil
end

Spell = {

	QTimer = 0,
	WTimer = 0,
	ETimer = 0,
	RTimer = 0,
	QkTimer = 0,
	WkTimer = 0,
	EkTimer = 0,
	RkTimer = 0,
	OnSpellCastCb = {},
	ControlKeyDown = _G.Control.KeyDown,

	OnSpellCast = function(self, cb)
		table_insert(self.OnSpellCastCb, cb)
	end,

	WndMsg = function(self, msg, wParam)
		local timer = GameTimer()
		if wParam == HK_Q then
			if timer > self.QkTimer + 0.5 and GameCanUseSpell(_Q) == 0 then
				self.QkTimer = timer
			end
			return
		end
		if wParam == HK_W then
			if timer > self.WkTimer + 0.5 and GameCanUseSpell(_W) == 0 then
				self.WkTimer = timer
			end
			return
		end
		if wParam == HK_E then
			if timer > self.EkTimer + 0.5 and GameCanUseSpell(_E) == 0 then
				self.EkTimer = timer
			end
			return
		end
		if wParam == HK_R then
			if timer > self.RkTimer + 0.5 and GameCanUseSpell(_R) == 0 then
				self.RkTimer = timer
			end
			return
		end
	end,

	IsReady = function(self, spell, delays)
		if Cursor.Step > 0 then
			return false
		end
		if not self:CanTakeAction(delays) then
			return false
		end
		return GameCanUseSpell(spell) == 0
	end,

	CanTakeAction = function(self, delays)
		if delays == nil then
			return true
		end
		local t = GameTimer()
		local q = t - delays.q
		local w = t - delays.w
		local e = t - delays.e
		local r = t - delays.r
		if q < self.QkTimer or q < self.QTimer then
			return false
		end
		if w < self.WkTimer or w < self.WTimer then
			return false
		end
		if e < self.EkTimer or e < self.ETimer then
			return false
		end
		if r < self.RkTimer or r < self.RTimer then
			return false
		end
		return true
	end,

	SpellClear = function(self, spell, spelldata, isReady, canLastHit, canLaneClear, getDamage)
		local hk
		if spell == _Q then
			hk = HK_Q
		elseif spell == _W then
			hk = HK_W
		elseif spell == _E then
			hk = HK_E
		elseif spell == _R then
			hk = HK_R
		end
		Health:AddSpell({
			HK = hk,
			spell = spell,
			isReady = isReady,
			canLastHit = canLastHit,
			canLaneClear = canLaneClear,
			getDamage = getDamage,
			SpellPrediction = spelldata,
			Radius = spelldata.Radius,
			Delay = spelldata.Delay,
			Speed = spelldata.Speed,
			Range = spelldata.Range,
			ShouldWaitTime = 0,
			IsLastHitable = false,
			LastHitHandle = 0,
			LaneClearHandle = 0,
			FarmMinions = {},

			GetLastHitTargets = function(self)
				local result = {}
				for i, minion in pairs(self.FarmMinions) do
					if minion.LastHitable then
						local unit = minion.Minion
						if unit.handle ~= Health.LastHitHandle then
							table_insert(result, unit)
						end
					end
				end
				return result
			end,

			GetLaneClearTargets = function(self)
				local result = {}
				for i, minion in pairs(self.FarmMinions) do
					local unit = minion.Minion
					if unit.handle ~= Health.LaneClearHandle then
						table_insert(result, unit)
					end
				end
				return result
			end,

			ShouldWait = function(self)
				return GameTimer() <= self.ShouldWaitTime + 1
			end,

			SetLastHitable = function(self, target, time, damage)
				local hpPred = Health:GetPrediction(target, time)
				local lastHitable = false
				local almostLastHitable = false
				if hpPred - damage < 0 then
					lastHitable = true
					self.IsLastHitable = true
				elseif Health:GetPrediction(target, myHero:GetSpellData(self.spell).cd + (time * 3)) - damage < 0 then
					almostLastHitable = true
					self.ShouldWaitTime = GameTimer()
				end
				return {
					LastHitable = lastHitable,
					Unkillable = hpPred < 0,
					Time = time,
					AlmostLastHitable = almostLastHitable,
					PredictedHP = hpPred,
					Minion = target,
				}
			end,

			Reset = function(self)
				for i = #self.FarmMinions, 1, -1 do
					self.FarmMinions[i] = nil
				end
				self.IsLastHitable = false
				self.LastHitHandle = 0
				self.LaneClearHandle = 0
			end,

			Tick = function(self)
				if Cursor.Step > 0 or Orbwalker:IsAutoAttacking() or not self.isReady() then
					return
				end
				local isLastHit = self.canLastHit()
					and (Orbwalker.Modes[ORBWALKER_MODE_LASTHIT] or Orbwalker.Modes[ORBWALKER_MODE_LANECLEAR])
				local isLaneClear = self.canLaneClear() and Orbwalker.Modes[ORBWALKER_MODE_LANECLEAR]
				if not isLastHit and not isLaneClear then
					return
				end
				if myHero:GetSpellData(self.spell).level == 0 then
					return
				end
				if myHero.mana < myHero:GetSpellData(self.spell).mana then
					return
				end
				if GameCanUseSpell(self.spell) ~= 0 and myHero:GetSpellData(self.spell).currentCd > 0.5 then
					return
				end
				local targets = Object:GetEnemyMinions(self.Range, false, true)
				for i = 1, #targets do
					local target = targets[i]
					table_insert(
						self.FarmMinions,
						self:SetLastHitable(
							target,
							self.Delay + target.distance / self.Speed + Data:GetLatency(),
							self.getDamage()
						)
					)
				end
				if self.IsLastHitable and (isLastHit or isLaneClear) then
					local targets = self:GetLastHitTargets()
					for i = 1, #targets do
						local unit = targets[i]
						if unit.alive then
							--self.SpellPrediction:GetPrediction(unit, myHero)
							if Control.CastSpell(self.HK, unit.pos) then
								--if self.SpellPrediction:CanHit() and Control.CastSpell(self.HK, self.SpellPrediction.CastPosition) then
								self.LastHitHandle = unit.handle
								Orbwalker:SetAttack(false)
								Action:Add(function()
									Orbwalker:SetAttack(true)
								end, self.Delay + (unit.distance / self.Speed) + 0.05, 0)
								break
							end
						end
					end
				end
				if isLaneClear and self.LastHitHandle == 0 and not self:ShouldWait() then
					local targets = self:GetLaneClearTargets()
					for i = 1, #targets do
						local unit = targets[i]
						if unit.alive then
							--self.SpellPrediction:GetPrediction(unit, myHero)
							if Control.CastSpell(self.HK, unit.pos) then
								--if self.SpellPrediction:CanHit() and Control.CastSpell(self.HK, self.SpellPrediction.CastPosition) then
								self.LaneClearHandle = unit.handle
							end
						end
					end
				end
				local targets = self.FarmMinions
				for i = 1, #targets do
					local minion = targets[i]
					if minion.LastHitable then
						Draw.Circle(minion.Minion.pos, 50, 1, Color.drawcolor1)
					elseif minion.AlmostLastHitable then
						Draw.Circle(minion.Minion.pos, 50, 1,  Color.drawcolor2)
					end
				end
			end,
		})
	end,
}

_G.Control.KeyDown = function(key)
	if key == HK_Q then
		local timer = GameTimer()
		if timer > Spell.QTimer + 0.5 and GameCanUseSpell(_Q) == 0 then
			Spell.QTimer = timer
			for i = 1, #Spell.OnSpellCastCb do
				Spell.OnSpellCastCb[i](_Q)
			end
		end
	end
	if key == HK_W then
		local timer = GameTimer()
		if timer > Spell.WTimer + 0.5 and GameCanUseSpell(_W) == 0 then
			Spell.WTimer = timer
			for i = 1, #Spell.OnSpellCastCb do
				Spell.OnSpellCastCb[i](_W)
			end
		end
	end
	if key == HK_E then
		local timer = GameTimer()
		if timer > Spell.ETimer + 0.5 and GameCanUseSpell(_E) == 0 then
			Spell.ETimer = timer
			for i = 1, #Spell.OnSpellCastCb do
				Spell.OnSpellCastCb[i](_E)
			end
		end
	end
	if key == HK_R then
		local timer = GameTimer()
		if timer > Spell.RTimer + 0.5 and GameCanUseSpell(_R) == 0 then
			Spell.RTimer = timer
			for i = 1, #Spell.OnSpellCastCb do
				Spell.OnSpellCastCb[i](_R)
			end
		end
	end
--	print(key..Game.Timer())
	Spell.ControlKeyDown(key)
end

SummonerSpell = {

	SpellNames = {
		"SummonerHeal", --1 heal
		"SummonerHaste", --2 ghost
		"SummonerBarrier", --3 barrier
		"SummonerExhaust", --4 exhaust
		"SummonerFlash", --5 flash
		"SummonerTeleport", --6 teleport
		"SummonerSmite", --7 smite
		"SummonerBoost", --8 cleanse
		"SummonerDot", --9 ignite
	},

	SpellNameAliases = {
		["SummonerBoost_Jade"] = "SummonerBoost", --8 cleanse (jade variant)
	},

	Spell = {
		{
			Id = 0,
			Ready = false,
		},
		{
			Id = 0,
			Ready = false,
		},
	},

	CleanseStartTime = GetTickCount(),

	OnTick = function(self)
		if not Menu.SummonerSpellsLoaded then
			return
		end
		if Cursor.Step > 0 then
			return
		end
		local sd1 = myHero:GetSpellData(SUMMONER_1)
		local sd2 = myHero:GetSpellData(SUMMONER_2)
		local sd1Name = self.SpellNameAliases[sd1.name] or sd1.name
		local sd2Name = self.SpellNameAliases[sd2.name] or sd2.name
		local success1 = false
		local success2 = false
		for i = 1, 9 do
			if not success1 and sd1Name == self.SpellNames[i] then
				self.Spell[1].Id = i
				self.Spell[1].Ready = sd1.currentCd == 0 and GameCanUseSpell(SUMMONER_1) == 0
				success1 = true
			elseif not success2 and sd2Name == self.SpellNames[i] then
				self.Spell[2].Id = i
				self.Spell[2].Ready = sd2.currentCd == 0 and GameCanUseSpell(SUMMONER_2) == 0
				success2 = true
			end
		end
		if not success1 and not success2 then
			return
		end
		if not success1 then
			self.Spell[1].Ready = false
		end
		if not success2 then
			self.Spell[2].Ready = false
		end
		local s1 = self.Spell[1]
		local s2 = self.Spell[2]
		if not s1.Ready and not s2.Ready then
			return
		end
		self:UseCleanse(s1, s2)
	end,

	UseCleanse = function(self, s1, s2)
        if Cursor.Automation and not Cursor.Automation:AllowsBuiltin("cleanse") then return false end
		local hk
		if s1.Id == 8 and s1.Ready then
			hk = HK_SUMMONER_1
		end
		if s2.Id == 8 and s2.Ready then
			hk = HK_SUMMONER_2
		end
		if hk == nil then
			return false
		end
		if GetTickCount() < Item.CleanseStartTime + 200 then
			return false
		end
		if not self.MenuCleanse.Enabled:Value() then
			return false
		end
		local enemiesCount = 0
		local menuDistance = self.MenuCleanse.Distance:Value()
		local cachedHeroes = Cached:GetHeroes()
		for i = 1, #cachedHeroes do
			local hero = cachedHeroes[i]
			if hero.isEnemy and hero.distance <= menuDistance then
				enemiesCount = enemiesCount + 1
			end
		end
		if enemiesCount < self.MenuCleanse.Count:Value() then
			return false
		end
		local menuDuration = self.MenuCleanse.Duration:Value() * 0.001
		local menuBuffs = GetBuffTypes(self.MenuCleanseBuffs)
		local casted = false
		local buffs = Buff:GetBuffs(myHero)
		for i = 1, #buffs do
			local buff = buffs[i]
			if buff.duration >= menuDuration and menuBuffs[buff.type] then
				-- Calculate the time when the spell should be cast
				local castTime = buff.startTime + self.MenuCleanse.Delay:Value()
		
				-- Check if the current time has exceeded the calculated cast time
				if Game.Timer() > castTime then
					casted = true
					Control.CastSpell(hk)
					self.CleanseStartTime = GetTickCount()
					break
				end
			end
		end
		
		if not casted and self.MenuCleanseBuffs.Slow:Value() then
			local ms = myHero.ms
			for i = 1, #buffs do
				local buff = buffs[i]
				if buff.type == 11 and buff.duration >= 1 and ms <= 200 then
					casted = true
					Control.CastSpell(hk)
					self.CleanseStartTime = GetTickCount()
					break
				end
			end
		end
		return casted
	end,
}

if Menu.SummonerSpellsLoaded then
	SummonerSpell.MenuCleanse = Menu.SummonerSpells.Cleanse
	SummonerSpell.MenuCleanseBuffs = Menu.SummonerSpells.Cleanse.BuffTypes
end

Item = {

	ItemQss = { 3139, 3140, 6035, 223139, 223140, 226035, 773139, 773140, 776035 },
	CachedItems = {},
	Hotkey = nil,
	CleanseStartTime = GetTickCount(),

	OnTick = function(self)
		if not Menu.ItemsLoaded then
			return
		end
		if self:UseQss() then
			return
		end
	end,

	GetItemById = function(self, unit, id)
        return self:GetSnapshot(unit).ids[id]
    end,

	IsReady = function(self, unit, id)
		local item = self:GetItemById(unit, id)
		if item and unit:GetSpellData(ItemSlots[item]).currentCd == 0 then
			self.Hotkey = ItemKeys[item]
            self.ReadySlot = ItemSlots[item]
            self.ReadyItem = id
			return true
		end
		return false
	end,

	UseQss = function(self)
        if Cursor.Automation and not Cursor.Automation:AllowsBuiltin("qss") then return false end
		if GetTickCount() < SummonerSpell.CleanseStartTime + 200 then
			return false
		end
		if not self.MenuQss.Enabled:Value() then
			return false
		end
		local qssReady = false
		for _, id in pairs(self.ItemQss) do
			if self:IsReady(myHero, id) then
				qssReady = true
				break
			end
		end
		if self.QssPending or not qssReady then
			return false
		end
		local enemiesCount = 0
		local menuDistance = self.MenuQss.Distance:Value()
		local cachedHeroes = Cached:GetHeroes()
		for i = 1, #cachedHeroes do
			local hero = cachedHeroes[i]
			if hero.isEnemy and hero.distance <= menuDistance then
				enemiesCount = enemiesCount + 1
			end
		end
		if enemiesCount < self.MenuQss.Count:Value() then
			return false
		end
		local menuDuration = self.MenuQss.Duration:Value() * 0.001
		local menuBuffs = GetBuffTypes(self.MenuQssBuffs)
		local casted = false
		local buffs = Buff:GetBuffs(myHero)
		for i = 1, #buffs do
			local buff = buffs[i]
			if buff.duration >= menuDuration and menuBuffs[buff.type] then
				casted = true
				local slot, id, key = self.ReadySlot, self.ReadyItem, self.Hotkey
                local generation = Cursor.Generation
                local job = {}; self.QssPending = job
                local claimEpoch = Cursor.Automation and Cursor.Automation:GetAutomation("qss").epoch
                DelayAction(function()
                    if self.QssPending ~= job then return end
                    self.QssPending = nil
                    local item = myHero:GetItemData(slot)
                    local spell = myHero:GetSpellData(slot)
                    if Cursor.Automation and not Cursor.Automation:AllowsBuiltin("qss",claimEpoch) then return end
                    if Cursor.Generation ~= generation or not Orbwalker:IsEnabled()
                        or not self.MenuQss.Enabled:Value() or myHero.dead
                        or GetTickCount() < SummonerSpell.CleanseStartTime + 200
                        or not item or item.itemID ~= id or not spell or spell.currentCd ~= 0 then return end
                    local current = Buff:GetBuffs(myHero)
                    local currentTypes = GetBuffTypes(self.MenuQssBuffs)
                    for j=1,#current do
                        if current[j].duration > 0 and currentTypes[current[j].type] then
                            Cursor:SendKeys(key, "qss"); return
                        end
                    end
                end, self.MenuQss.Delay:Value())
				self.CleanseStartTime = GetTickCount()
				break
			end
		end
		if not casted and self.MenuQssBuffs.Slow:Value() then
			local ms = myHero.ms
			for i = 1, #buffs do
				local buff = buffs[i]
				if buff.type == 11 and buff.duration >= 1 and ms <= 200 then
					casted = true
					Cursor:SendKeys(self.Hotkey, "qss")
					self.CleanseStartTime = GetTickCount()
					break
				end
			end
		end
		return casted
	end,

	HasItem = function(self, unit, id)
		return self:GetItemById(unit, id) ~= nil
	end,
}

if Menu.ItemsLoaded then
	Item.MenuQss = Menu.Main.Items.Qss
	Item.MenuQssBuffs = Menu.Main.Items.Qss.BuffTypes
end

Object = {

	UndyingBuffs = {
		--["zhonyasringshield"] = true,
		["kindredrnodeathbuff"] = true,
		["chronoshift"] = true,
		["undyingrage"] = true,
		["jaxe"] = true,
		["jade_kayler"] = true,
		["jade_zilean_chronoshift"] = true,
		["jade_tryndamereundyingrage"] = true,
		["jade_jaxe"] = true,
	},

	AllyBuildings = {},
	EnemyBuildings = {},
	ExpectedBuildingsByMap = {
		[11] = 4,
		[12] = 2,
		[30] = 0,
		[35] = 0,
		[453] = 4,
	},
	HeroesInGame = {},
	AllyHeroesInGame = {},
	EnemyHeroesInGame = {},
	EnemyHeroCb = {},
	AllyHeroCb = {},
	CachedHeroes = {},
	CachedMinions = {},
	CachedTurrets = {},
	CachedWards = {},
	IsAzir = myHero.charName == "Azir",
	IsAphelios = myHero.charName == "Aphelios",
	IsKalista = myHero.charName == "Kalista",
	IsCaitlyn = myHero.charName == "Caitlyn",
	IsRiven = myHero.charName == "Riven",
	IsKindred = myHero.charName == "Kindred",
	IsNasus = myHero.charName == "Nasus",
	OnLoad = function(self)
		if GameMapID == 12 then
			Action:Add(function()
				for i = 1, GameObjectCount() do
					local obj = GameObject(i)
					if obj and obj.charName == "URF_Feeneypult" then
						Cached.HasFeeneypult = true
						return true
					end
				end
			end, 1, 3)
		end

		local expectedBuildings = self.ExpectedBuildingsByMap[GameMapID]
		Action:Add(function()  -- prevent missing buildings during rapid loading
			self.EnemyBuildings = {}
			self.AllyBuildings = {}
			for i = 1, GameObjectCount() do
				local object = GameObject(i)
				if object and (object.type == Obj_AI_Barracks or object.type == Obj_AI_Nexus) then
					if object.isEnemy then
						table_insert(self.EnemyBuildings, object)
					elseif object.isAlly then
						table_insert(self.AllyBuildings, object)
					end
				end
			end
			if expectedBuildings == 0
				or (expectedBuildings
					and #self.EnemyBuildings >= expectedBuildings
					and #self.AllyBuildings >= expectedBuildings)
			then
				return true
			end
		end, 1, 5)

		Action:Add(function()
			local success = 0
			for i = 1, GameHeroCount() do
				local args = Data:GetHeroData(GameHero(i))
				if args.valid and self.HeroesInGame[args.networkID] == nil then
					self.HeroesInGame[args.networkID] = args.unit
				end
				if args.valid and args.isAlly and self.AllyHeroesInGame[args.networkID] == nil then
					self.AllyHeroesInGame[args.networkID] = true
					for j, func in pairs(self.AllyHeroCb) do
						func(args)
					end
				end
				if args.valid and args.isEnemy then
					if self.EnemyHeroesInGame[args.networkID] == nil then
						self.EnemyHeroesInGame[args.networkID] = true
						for j, func in pairs(self.EnemyHeroCb) do
							func(args)
						end
					end
					success = success + 1
				end
			end
			return success >= 5
		end, 1, 100)
	end,

	OnAllyHeroLoad = function(self, cb)
		table_insert(self.AllyHeroCb, cb)
	end,

	OnEnemyHeroLoad = function(self, cb)
		table_insert(self.EnemyHeroCb, cb)
	end,

	IsFacing = function(self, source, target, angle)
		return IsFacing(source, target, angle)
	end,

	IsValid = function(self, unit)
		return unit and unit.valid and unit.visible and unit.isTargetable and not unit.dead
	end,

	IsHeroImmortal = function(self, unit, isAttack)
		local hp = 100 * (unit.health / unit.maxHealth)
		local lowHp = hp < 15
		local undying = self.UndyingBuffs
		undying["kindredrnodeathbuff"] = hp <= 10.1
		undying["chronoshift"] = lowHp
		undying["chronorevive"] = lowHp
		undying["undyingrage"] = lowHp
		undying["jaxe"] = isAttack
		undying["shenwbuff"] = isAttack
		undying["jade_zilean_chronoshift"] = lowHp
		undying["jade_tryndamereundyingrage"] = lowHp
		undying["jade_jaxe"] = isAttack
		local buffs = Buff:GetBuffs(unit)
		for i = 1, #buffs do
			local buff = buffs[i]
			if undying[(buff.lowerName or buff.name:lower())] then
				if not isAttack then
					return true
				end
				if self.IsAzir then
					return false
				end
				if
					buff.duration
					>= myHero.attackData.windUpTime
						+ (unit.distance / Attack:GetProjectileSpeed())
						+ Data:GetLatency() / 2
				then
					return true
				end
			end
		end
		-- anivia passive, olaf R, ... if unit.isImmortal and not Buff:HasBuff(unit, 'willrevive') and not Buff:HasBuff(unit, 'zacrebirthready') then return true end
		return false
	end,

	GetHeroes = function(self, range, bbox, immortal, isAttack)
		local result = {}
		local a = self:GetEnemyHeroes(range, bbox, immortal, isAttack)
		local b = self:GetAllyHeroes(range, bbox, immortal, isAttack)
		for i = 1, #a do
			table_insert(result, a[i])
		end
		for i = 1, #b do
			table_insert(result, b[i])
		end
		return result
	end,

	GetEnemyHeroes = function(self, range, bbox, immortal, isAttack)
		local result = {}
		local cachedHeroes = Cached:GetHeroes()
		for i = 1, #cachedHeroes do
			local hero = cachedHeroes[i]
			if hero.isEnemy and self:IsValid(hero) and ((not immortal or not self:IsHeroImmortal(hero, isAttack)) or (Object.IsKindred and Orbwalker:KindredETarget(hero))) then
				if not range or hero.distance < range + (bbox and hero.boundingRadius or 0) then
					table_insert(result, hero)
				end
			end
		end
		return result
	end,

	GetAllyHeroes = function(self, range, bbox, immortal, isAttack)
		local result = {}
		local cachedHeroes = Cached:GetHeroes()
		for i = 1, #cachedHeroes do
			local hero = cachedHeroes[i]
			if hero.isAlly and self:IsValid(hero) and (not immortal or not self:IsHeroImmortal(hero, isAttack)) then
				if not range or hero.distance < range + (bbox and hero.boundingRadius or 0) then
					table_insert(result, hero)
				end
			end
		end
		return result
	end,

	GetMinions = function(self, range, bbox, immortal)
		local result = {}
		local a = self:GetEnemyMinions(range, bbox, immortal)
		local b = self:GetAllyMinions(range, bbox, immortal)
		for i = 1, #a do
			table_insert(result, a[i])
		end
		for i = 1, #b do
			table_insert(result, b[i])
		end
		return result
	end,

	GetEnemyMinions = function(self, range, bbox, immortal)
		local result = {}
		local cachedminions = Cached:GetMinions()
		for i = 1, #cachedminions do
			local obj = cachedminions[i]
			if obj.isEnemy and (not immortal or not obj.isImmortal) then
				if not range or obj.distance < range + (bbox and obj.boundingRadius or 0) then
					table_insert(result, obj)
				end
			end
		end
		return result
	end,

	GetMonsters = function(self, range, bbox, immortal)
		local result = {}
		local cachedminions = Cached:GetMinions()
		for i = 1, #cachedminions do
			local obj = cachedminions[i]
			if obj.team == 300 and (not immortal or not obj.isImmortal) then
				if not range or obj.distance < range + (bbox and obj.boundingRadius or 0) then
					table_insert(result, obj)
				end
			end
		end
		return result
	end,

	GetAllyMinions = function(self, range, bbox, immortal)
		local result = {}
		local cachedminions = Cached:GetMinions()
		for i = 1, #cachedminions do
			local obj = cachedminions[i]
			if obj.isAlly and obj.team < 300 and (not immortal or not obj.isImmortal) then
				if not range or obj.distance < range + (bbox and obj.boundingRadius or 0) then
					table_insert(result, obj)
				end
			end
		end
		return result
	end,

	GetOtherMinions = function(self, range, bbox, immortal)
		local result = {}
		local a = self:GetOtherAllyMinions(range, bbox, immortal)
		local b = self:GetOtherEnemyMinions(range, bbox, immortal)
		for i = 1, #a do
			table_insert(result, a[i])
		end
		for i = 1, #b do
			table_insert(result, b[i])
		end
		return result
	end,

	GetOtherAllyMinions = function(self, range)
		local result = {}
		local cachedwards = Cached:GetWards()
		for i = 1, #cachedwards do
			local obj = cachedwards[i]
			if obj.isAlly and (not range or obj.distance < range) then
				table_insert(result, obj)
			end
		end
		return result
	end,

	GetOtherEnemyMinions = function(self, range)
		local result = {}
		local cachedwards = Cached:GetWards()
		for i = 1, #cachedwards do
			local obj = cachedwards[i]
			if obj.isEnemy and (not range or obj.distance < range) then
				table_insert(result, obj)
			end
		end
		return result
	end,

	GetPlants = function(self, range)
		local result = {}
		local cachedplants = Cached:GetPlants()
		for i = 1, #cachedplants do
			local obj = cachedplants[i]
			if not range or obj.distance < range then
				table_insert(result, obj)
			end
		end
		return result
	end,

	GetTurrets = function(self, range, bbox, immortal)
		local result = {}
		local a = self:GetEnemyTurrets(range, bbox, immortal)
		local b = self:GetAllyTurrets(range, bbox, immortal)
		for i = 1, #a do
			table_insert(result, a[i])
		end
		for i = 1, #b do
			table_insert(result, b[i])
		end
		return result
	end,

	GetEnemyTurrets = function(self, range, bbox, immortal)
		local result = {}
		local cachedturrets = Cached:GetTurrets()
		for i = 1, #cachedturrets do
			local obj = cachedturrets[i]
			if obj.isEnemy and (not immortal or not obj.isImmortal) then
				if not range or obj.distance < range + (bbox and obj.boundingRadius or 0) then
					table_insert(result, obj)
				end
			end
		end
		return result
	end,

	GetAllyTurrets = function(self, range, bbox, immortal)
		local result = {}
		local cachedturrets = Cached:GetTurrets()
		for i = 1, #cachedturrets do
			local obj = cachedturrets[i]
			if obj.isAlly then
				if not range or obj.distance < range + (bbox and obj.boundingRadius or 0) then
					table_insert(result, obj)
				end
			end
		end
		return result
	end,

	GetEnemyBuildings = function(self, range, bbox)
		local result = {}
		for i = 1, #self.EnemyBuildings do
			local obj = self.EnemyBuildings[i]
			if obj and obj.valid and obj.visible and obj.isTargetable and not obj.dead and not obj.isImmortal then
				if not range or obj.distance < range + (bbox and Data:GetBuildingBBox(obj) or 0) then
					table_insert(result, obj)
				end
			end
		end
		return result
	end,

	GetAllyBuildings = function(self, range, bbox)
		local result = {}
		for i = 1, #self.AllyBuildings do
			local obj = self.AllyBuildings[i]
			if obj and obj.valid and obj.visible and obj.isTargetable and not obj.dead and not obj.isImmortal then
				if not range or obj.distance < range + (bbox and Data:GetBuildingBBox(obj) or 0) then
					table_insert(result, obj)
				end
			end
		end
		return result
	end,

	GetAllStructures = function(self, range, bbox)
		local result = {}
		for i = 1, #self.AllyBuildings do
			local obj = self.AllyBuildings[i]
			if obj and obj.valid and obj.visible and obj.isTargetable and not obj.dead and not obj.isImmortal then
				if not range or obj.distance < range + (bbox and Data:GetBuildingBBox(obj) or 0) then
					table_insert(result, obj)
				end
			end
		end
		for i = 1, #self.EnemyBuildings do
			local obj = self.EnemyBuildings[i]
			if obj and obj.valid and obj.visible and obj.isTargetable and not obj.dead and not obj.isImmortal then
				if not range or obj.distance < range + (bbox and Data:GetBuildingBBox(obj) or 0) then
					table_insert(result, obj)
				end
			end
		end
		local cachedturrets = Cached:GetTurrets()
		for i = 1, #cachedturrets do
			local obj = cachedturrets[i]
			if not range or obj.distance < range + (bbox and obj.boundingRadius or 0) then
				table_insert(result, obj)
			end
		end
		return result
	end,
}

Object.UndyingBuffsByChampion = {
	["Mel"] = { "melwreflect" },
	["Kayle"] = { "kayler" },
	["Taric"] = { "taricr" },
	["Kindred"] = { "kindredrnodeathbuff" },
	["Zilean"] = { "chronoshift", "chronorevive" },
	["Tryndamere"] = { "undyingrage" },
	["Jax"] = { "jaxe" },
	["Fiora"] = { "fioraw" },
	["Aatrox"] = { "aatroxpassivedeath" },
	["Vladimir"] = { "vladimirsanguinepool" },
	["KogMaw"] = { "kogmawicathiansurprise" },
	["Karthus"] = { "karthusdeathdefiedbuff" },
	["Shen"] = { "shenwbuff" },
	["Samira"] = { "samiraw" },
	["Jade_KogMaw"] = { "jade_kogmawicathiansurprise" },
	["Jade_Karthus"] = {"jade_karthusdeathdefiedbuff" },
}

Object:OnEnemyHeroLoad(function(args)
	local charName = args.charName
	if not charName then
		return
	end
	Cached.EnemyChampionNames[charName:lower()] = true
	local names = Object.UndyingBuffsByChampion[charName]
	if names then
		for i = 1, #names do
			Object.UndyingBuffs[names[i]] = true
		end
	end
end)

Target = {

	SelectionTick = 0,
	Selected = nil,
	CurrentSort = nil,
	CurrentSortMode = 0,
	CurrentDamage = nil,
--	lastNetProc=0,
--	lastCaitWProc=0,
	--lastCaitWEnemy=nil,
	ActiveStackBuffs = { "BraumMark" },

	StackBuffs = {
		["Vayne"] = { "VayneSilverDebuff" },
		["TahmKench"] = { "tahmkenchpdebuffcounter" },
		["Kennen"] = { "kennenmarkofstorm" },
		["Darius"] = { "DariusHemo" },
		["Ekko"] = { "EkkoStacks" },
		["Gnar"] = { "GnarWProc" },
		["Kalista"] = { "KalistaExpungeMarker" },
		["Kindred"] = { "KindredHitCharge", "kindredecharge" },
		["Tristana"] = { "tristanaecharge" },
		["Twitch"] = { "TwitchDeadlyVenom" },
		["Varus"] = { "VarusWDebuff" },
		["Velkoz"] = { "VelkozResearchStack" },
		["Vi"] = { "ViWProc" },
		["Jade_Tristana"] = { "Jade_TristanaE_Debuff" },
		["Jade_Twitch"] = { "Jade_TwitchDeadlyVenomMarker", "Jade_TwitchPassive_Marker" },
		["Jade_Vayne"] = { "Jade_VayneW_Debuff" },
	},

	MenuAARange = Menu.Orbwalker.General.AttackRange,
	MenuPriorities = Menu.Target.Priorities,
	MenuDrawSelected = Menu.Main.Drawings.SelectedTarget,
	MenuTableSortMode = Menu.Target["SortMode" .. myHero.charName],
	MenuCheckSelected = Menu.Target.SelectedTarget,
	MenuCheckSelectedOnly = Menu.Target.OnlySelectedTarget,

	WndMsg = function(self, msg, wParam)
		if msg == WM_LBUTTONDOWN and self.MenuCheckSelected:Value() and GetTickCount() > self.SelectionTick + 100 then
			self.Selected = nil
			local num = 10000000
			local pos = Vector(Cursor:GetPlayerPosition())
			local enemies = Object:GetEnemyHeroes()
			for i = 1, #enemies do
				local enemy = enemies[i]
				if enemy.pos:ToScreen().onScreen then
					local distance = GetDistance(pos, enemy.pos)
					if distance < 150 and distance < num then
						self.Selected = enemy
						num = distance
					end
				end
			end
			self.SelectionTick = GetTickCount()
		end
	end,

	OnDraw = function(self)
		if
			self.MenuDrawSelected:Value()
			and Object:IsValid(self.Selected)
		--	and not Object:IsHeroImmortal(self.Selected)
		then
			Draw.Circle(self.Selected.pos, 150, 1, Color.DarkRed)
		end
	end,

	OnTick = function(self)
		local sortMode = self.MenuTableSortMode:Value()
		if sortMode ~= self.CurrentSortMode then
			self.CurrentSortMode = sortMode
			self.CurrentSort = self.SortModes[sortMode]
		end
	end,

	GetTarget = function(self, a, dmgType, isAttack)
		a = a or 20000
        if type(a) == "table" then
            local copy, seen = {}, {}
            for i=1,#a do
                local id = a[i].networkID or a[i].handle or a[i]
                if not seen[id] then seen[id]=true; copy[#copy+1]=a[i] end
            end
            a=copy
        end
		dmgType = dmgType or 1
		self.CurrentDamage = dmgType
		if
			self.MenuCheckSelected:Value()
			and Object:IsValid(self.Selected)
			and ChampionInfo:CustomIsTargetable(self.Selected)
			and (Object:IsHeroImmortal(self.Selected, isAttack)==false or (Object.IsKindred and Orbwalker:KindredETarget(self.Selected)))
		then
			if type(a) == "number" then
				if self.Selected.distance < a then
					return self.Selected
				end
			else
				local ok
				for i = 1, #a do
					if a[i].networkID == self.Selected.networkID then
						ok = true
						break
					end
				end
				if ok then
					return self.Selected
				end
			end
			if self.MenuCheckSelectedOnly:Value() then
				return nil
			end
		end
		if type(a) == "number" then
			a = Object:GetEnemyHeroes(a, false, true, isAttack)
		end
		for i = #a, 1, -1 do
			if not ChampionInfo:CustomIsTargetable(a[i]) then
				table_remove(a, i)
			end
		end
		if self.CurrentSortMode == SORT_MOST_STACK then
			local stackA = {}
			for i = 1, #a do
				local obj = a[i]
				for j = 1, #self.ActiveStackBuffs do
					if Buff:HasBuff(obj, self.ActiveStackBuffs[j]) then
						table_insert(stackA, obj)
						break
					end
				end
			end
			local sortMode = (#stackA == 0 and SORT_AUTO or SORT_MOST_STACK)
			if sortMode == SORT_MOST_STACK then
				a = stackA
			end
			table_sort(a, self.SortModes[sortMode])
		else
			table_sort(a, self.CurrentSort)
		end
		return (#a == 0 and nil or a[1])
	end,

	GetTargets = function(self, a, dmgType, isAttack)
		a = a or 20000
        if type(a) == "table" then
            local copy, seen = {}, {}
            for i=1,#a do
                local id = a[i].networkID or a[i].handle or a[i]
                if not seen[id] then seen[id]=true; copy[#copy+1]=a[i] end
            end
            a=copy
        end
		dmgType = dmgType or 1
		self.CurrentDamage = dmgType
		if
			self.MenuCheckSelected:Value()
			and Object:IsValid(self.Selected)
			and ChampionInfo:CustomIsTargetable(self.Selected)
			and (Object:IsHeroImmortal(self.Selected, isAttack)==false or (Object.IsKindred and Orbwalker:KindredETarget(self.Selected)))
		then
			if type(a) == "number" then
				if self.Selected.distance < a then
					return {self.Selected}
				end
			else
				local ok
				for i = 1, #a do
					if a[i].networkID == self.Selected.networkID then
						ok = true
						break
					end
				end
				if ok then
					return {self.Selected}
				end
			end
			if self.MenuCheckSelectedOnly:Value() then
				return nil
			end
		end
		if type(a) == "number" then
			a = Object:GetEnemyHeroes(a, false, true, isAttack)
		end
		for i = #a, 1, -1 do
			if not ChampionInfo:CustomIsTargetable(a[i]) then
				table_remove(a, i)
			end
		end
		if self.CurrentSortMode == SORT_MOST_STACK then
			local stackA = {}
			for i = 1, #a do
				local obj = a[i]
				for j = 1, #self.ActiveStackBuffs do
					if Buff:HasBuff(obj, self.ActiveStackBuffs[j]) then
						table_insert(stackA, obj)
                        break
					end
				end
			end
			local sortMode = (#stackA == 0 and SORT_AUTO or SORT_MOST_STACK)
			if sortMode == SORT_MOST_STACK then
				a = stackA
			end
			table_sort(a, self.SortModes[sortMode])
		else
			table_sort(a, self.CurrentSort)
		end
		return (#a == 0 and nil or a)
	end,

	GetPriority = function(self, unit)
		local name = unit.charName
		if self.MenuPriorities[name] then
			return self.MenuPriorities[name]:Value()
		end
		return Data:GetHeroPriority(name)
	end,

	GetComboTarget = function(self, dmgType)
		dmgType = dmgType or DAMAGE_TYPE_PHYSICAL
		local menuRange = self.MenuAARange:Value()
		local attackRange = (myHero.charName == "Zeri" and 550 or myHero.range) + myHero.boundingRadius - menuRange
		local enemies = Object:GetEnemyHeroes(false, false, true, true)
		local enemiesaa = {}
		if Menu.Orbwalker.General.AttackBarrel:Value() then
			local gangplank = nil
			for _, hero in pairs(Object.HeroesInGame) do
				if hero and hero.valid and hero.isEnemy and not hero.dead and hero.charName == "Gangplank" then
					gangplank = hero
					break
				end
			end

			if gangplank then
				for _, barrel in ipairs(Cached:GetPlants()) do
					if barrel and barrel.charName:lower() == "gangplankbarrel" then
						if barrel.health <= 1 and barrel.distance <= attackRange + barrel.boundingRadius then
							return barrel
						end
						local time = Attack:GetWindup() + (barrel.distance - myHero.boundingRadius - barrel.boundingRadius) / Attack:GetProjectileSpeed() + Data:GetLatency() / 2
						local barrelBuffStartTime = Buff:GetBuffStartTime(barrel, "gangplankebarrelactive")
						if barrel.health <= 2 then
							local healthDecayRate = gangplank.levelData.lvl >= 13 and 0.5 or (gangplank.levelData.lvl >= 7 and 1 or 2)
							local nextHealthDecayTime = Game.Timer() < barrelBuffStartTime + healthDecayRate and barrelBuffStartTime + healthDecayRate or barrelBuffStartTime + healthDecayRate * 2
							if nextHealthDecayTime <= Game.Timer() + time and barrel.distance <= attackRange + barrel.boundingRadius then
								return barrel
							end
						end
					end
				end
			end
		end
		for i = 1, #enemies do
			local enemy = enemies[i]
			local extraRange = enemy.boundingRadius
			if Data.ExtraAttackRange then
				extraRange = extraRange + Data.ExtraAttackRange(enemy)
			end
			if Object.IsAzir and ChampionInfo:IsInAzirSoldierRange(enemy) then
				table_insert(enemiesaa, enemy)
			elseif enemy.distance < attackRange + extraRange then
				table_insert(enemiesaa, enemy)
			end
		end
		return self:GetTarget(enemiesaa, dmgType, true)
	end,
}

-- stylua: ignore start
Object:OnEnemyHeroLoad(function(args)
    local priority = Data:GetHeroPriority(args.charName) or 1
    Target.MenuPriorities:MenuElement({id = args.charName, name = args.charName, value = priority, min = 1, max = 5, step = 1})
end)
-- stylua: ignore end

if Target.StackBuffs[myHero.charName] then
	for i, buffName in pairs(Target.StackBuffs[myHero.charName]) do
		table_insert(Target.ActiveStackBuffs, buffName)
	end
end

Target.SortModes = {

	[SORT_AUTO] = function(a, b)
		local aMultiplier = 1.75 - Target:GetPriority(a) * 0.15
		local bMultiplier = 1.75 - Target:GetPriority(b) * 0.15
		local aDef, bDef = 0, 0
		if Target.CurrentDamage == DAMAGE_TYPE_MAGICAL then
			local magicPen, magicPenPercent = myHero.magicPen, myHero.magicPenPercent
			aDef = math_max(0, aMultiplier * (a.magicResist - magicPen) * magicPenPercent)
			bDef = math_max(0, bMultiplier * (b.magicResist - magicPen) * magicPenPercent)
		elseif Target.CurrentDamage == DAMAGE_TYPE_PHYSICAL then
			local armorPen, bonusArmorPenPercent = myHero.armorPen, myHero.bonusArmorPenPercent
			aDef = math_max(0, aMultiplier * (a.armor - armorPen) * bonusArmorPenPercent)
			bDef = math_max(0, bMultiplier * (b.armor - armorPen) * bonusArmorPenPercent)
		end
		return (a.health * aMultiplier * ((100 + aDef) / 100)) - a.ap - (a.totalDamage * a.attackSpeed * 2)
			< (b.health * bMultiplier * ((100 + bDef) / 100)) - b.ap - (b.totalDamage * b.attackSpeed * 2)
	end,

	[SORT_CLOSEST] = function(a, b)
		return a.distance < b.distance
	end,

	[SORT_NEAR_MOUSE] = function(a, b)
		return GetDistance(a.pos, Vector(Cursor:GetPlayerPosition())) < GetDistance(b.pos, Vector(Cursor:GetPlayerPosition()))
	end,

	[SORT_LOWEST_HEALTH] = function(a, b)
		return a.health < b.health
	end,

	[SORT_LOWEST_MAX_HEALTH] = function(a, b)
		return a.maxHealth < b.maxHealth
	end,

	[SORT_HIGHEST_PRIORITY] = function(a, b)
		return Target:GetPriority(a) > Target:GetPriority(b)
	end,

	[SORT_MOST_STACK] = function(a, b)
		local aMax = 0
		for i, buffName in pairs(Target.ActiveStackBuffs) do
			local buff = Buff:GetBuff(a, buffName)
			if buff then
				aMax = math_max(aMax, math_max(buff.count or 0, buff.stacks or 0))
			end
		end
		local bMax = 0
		for i, buffName in pairs(Target.ActiveStackBuffs) do
			local buff = Buff:GetBuff(b, buffName)
			if buff then
				bMax = math_max(bMax, math_max(buff.count or 0, buff.stacks or 0))
			end
		end
		return aMax > bMax
	end,

	[SORT_MOST_AD] = function(a, b)
		return a.totalDamage > b.totalDamage
	end,

	[SORT_MOST_AP] = function(a, b)
		return a.ap > b.ap
	end,

	[SORT_LESS_CAST] = function(a, b)
		local aMultiplier = 1.75 - Target:GetPriority(a) * 0.15
		local bMultiplier = 1.75 - Target:GetPriority(b) * 0.15
		local aDef, bDef = 0, 0
		local magicPen, magicPenPercent = myHero.magicPen, myHero.magicPenPercent
		aDef = math_max(0, aMultiplier * (a.magicResist - magicPen) * magicPenPercent)
		bDef = math_max(0, bMultiplier * (b.magicResist - magicPen) * magicPenPercent)
		return (a.health * aMultiplier * ((100 + aDef) / 100)) - a.ap - (a.totalDamage * a.attackSpeed * 2)
			< (b.health * bMultiplier * ((100 + bDef) / 100)) - b.ap - (b.totalDamage * b.attackSpeed * 2)
	end,

	[SORT_LESS_ATTACK] = function(a, b)
		local aMultiplier = 1.75 - Target:GetPriority(a) * 0.15
		local bMultiplier = 1.75 - Target:GetPriority(b) * 0.15
		local aDef, bDef = 0, 0
		local armorPen, bonusArmorPenPercent = myHero.armorPen, myHero.bonusArmorPenPercent
		aDef = math_max(0, aMultiplier * (a.armor - armorPen) * bonusArmorPenPercent)
		bDef = math_max(0, bMultiplier * (b.armor - armorPen) * bonusArmorPenPercent)
		return (a.health * aMultiplier * ((100 + aDef) / 100)) - a.ap - (a.totalDamage * a.attackSpeed * 2)
			< (b.health * bMultiplier * ((100 + bDef) / 100)) - b.ap - (b.totalDamage * b.attackSpeed * 2)
	end,
}

Target.CurrentSortMode = Target.MenuTableSortMode:Value()
Target.CurrentSort = Target.SortModes[Target.CurrentSortMode]

Health = {

	ExtraFarmDelay = Menu.Orbwalker.Farming.ExtraFarmDelay,
	MenuDrawings = Menu.Main.Drawings,
	IsLastHitable = false,
	ShouldRemoveObjects = false,
	ShouldWaitTime = 0,
	OnUnkillableC = {},
	ActiveAttacks = {},
	AllyTurret = nil,
	AllyTurretHandle = nil,
	StaticAutoAttackDamage = nil,
	FarmMinions = {},
	Handles = {},
	AllyMinionsHandles = {},
	EnemyWardsInAttackRange = {},
	EnemyMinionsInAttackRange = {},
	JungleMinionsInAttackRange = {},
	PlantsMinionsInAttackRange = {},
	EnemyStructuresInAttackRange = {},
	CachedWards = {},
	CachedPlants = {},
	CachedMinions = {},
	TargetsHealth = {},
	AttackersDamage = {},
	Spells = {},
	LastHitHandle = 0,
	LaneClearHandle = 0,
	LastHitHandleExpire = 0,
	LaneClearHandleExpire = 0,

	AddSpell = function(self, class)
		table_insert(self.Spells, class)
	end,

	OnTick = function(self)
		local attackRange, structures, pos, speed, windup, time, anim
		local healthTimer = GameTimer()
        self.IncomingReady = false
        self.PendingUnkillable = nil
        self.PendingSpellTicks = false
        self.TargetsHealth = {}
        self.AttackersDamage = {}
        self.IsLastHitable = false
		if healthTimer >= self.LastHitHandleExpire then self.LastHitHandle = 0 end
		if healthTimer >= self.LaneClearHandleExpire then self.LaneClearHandle = 0 end
		-- RESET ALL
		if self.ShouldRemoveObjects then
			self.ShouldRemoveObjects = false
			self.AllyTurret = nil
			self.AllyTurretHandle = nil
			self.StaticAutoAttackDamage = nil
			self.FarmMinions = {}
			self.EnemyWardsInAttackRange = {}
			self.EnemyMinionsInAttackRange = {}
			self.JungleMinionsInAttackRange = {}
			self.PlantsMinionsInAttackRange = {}
			self.EnemyStructuresInAttackRange = {}
			self.AttackersDamage = {}
			self.ActiveAttacks = {}
			self.AllyMinionsHandles = {}
			self.TargetsHealth = {}
			self.Handles = {}
			self.CachedMinions = {}
			self.CachedWards = {}
			self.CachedPlants = {}
		end
		-- SPELLS
		for i = 1, #self.Spells do
			self.PendingSpellResets = true
		end
		if Orbwalker.IsNone or Orbwalker.Modes[ORBWALKER_MODE_COMBO] then
			return
		end
		self.IsLastHitable = false
		self.ShouldRemoveObjects = true
		self.StaticAutoAttackDamage = Damage:GetStaticAutoAttackDamage(myHero, true)
		-- SET OBJECTS
		attackRange = (myHero.charName == "Zeri" and 550 or myHero.range) + myHero.boundingRadius
		local cachedminions = Cached:GetMinions()
		for i = 1, #cachedminions do
			local obj = cachedminions[i]
			if IsInRange(myHero, obj, 2000) then
				table_insert(self.CachedMinions, obj)
			end
		end
		local cachedwards = Cached:GetWards()
		for i = 1, #cachedwards do
			local obj = cachedwards[i]
			if obj.isEnemy and IsInRange(myHero, obj, 2000) then
				table_insert(self.CachedWards, obj)
			end
		end
		local cachedplants = Cached:GetPlants()
		for i = 1, #cachedplants do
			local obj = cachedplants[i]
			if IsInRange(myHero, obj, 2000) then
				table_insert(self.CachedPlants, obj)
			end
		end
		for i = 1, #self.CachedMinions do
			local obj = self.CachedMinions[i]
			local handle = obj.handle
			self.Handles[handle] = obj
			local team = obj.team
			if team == Data.AllyTeam then
				self.AllyMinionsHandles[handle] = obj
			elseif team == Data.EnemyTeam then
				if
					IsInRange(myHero, obj, attackRange + obj.boundingRadius)
					or (Object.IsAzir and ChampionInfo:IsInAzirSoldierRange(obj))
				then
					table_insert(self.EnemyMinionsInAttackRange, obj)
				end
			elseif team == Data.JungleTeam then
				if
					IsInRange(myHero, obj, attackRange + obj.boundingRadius)
					or (Object.IsAzir and ChampionInfo:IsInAzirSoldierRange(obj))
				then
					table_insert(self.JungleMinionsInAttackRange, obj)
				end
			end
		end
		for i = 1, #self.CachedWards do
			local obj = self.CachedWards[i]
			if IsInRange(myHero, obj, attackRange + 35) then
				table_insert(self.EnemyWardsInAttackRange, obj)
			end
		end
		for i = 1, #self.CachedPlants do
			local obj = self.CachedPlants[i]
			if IsInRange(myHero, obj, attackRange + obj.boundingRadius) then
				local objName = obj.charName:lower()
				if objName == "sennasoul" then
					-- Souls are explicit fallback targets; their health no longer controls last-hit priority.
					local value = {LastHitable = true, Unkillable = false, AlmostLastHitable = false, PredictedHP = obj.health or 1, Minion = obj, AlmostAlmost = false, IsSennaSoul = true}
					self.IsLastHitable = true
					table_insert(self.FarmMinions, value)
				elseif objName ~= "gangplankbarrel" then
					table_insert(self.PlantsMinionsInAttackRange, obj)
				end
			end
		end
		structures = Object:GetAllStructures(2000)
		for i = 1, #structures do
			local obj = structures[i]
			local objType = obj.type
			if objType == Obj_AI_Turret then
				self.Handles[obj.handle] = obj
				if obj.team == Data.AllyTeam then
					self.AllyTurret = obj
					self.AllyTurretHandle = obj.handle
				end
			end
			if obj.team == Data.EnemyTeam then
				local objRadius = 0
				if objType == Obj_AI_Barracks then
					objRadius = 270
				elseif objType == Obj_AI_Nexus then
					objRadius = 380
				elseif objType == Obj_AI_Turret then
					objRadius = obj.boundingRadius
				end
				if IsInRange(myHero, obj, attackRange + objRadius) then
					table_insert(self.EnemyStructuresInAttackRange, obj)
				end
			end
		end
		-- ON ATTACK
		local timer = GameTimer()
		for handle, obj in pairs(self.Handles) do
			local s = obj.activeSpell
			if s and s.valid and s.isAutoAttack then
				local endTime = s.endTime
				local speed = s.speed
				local animation = s.animation
				local windup = s.windup
				local target = s.target
				if obj.type == Obj_AI_Turret then
					local ad = obj.attackData
					local adWindup = ad and ad.windUpTime
					if adWindup and adWindup > 0 then
						windup = adWindup
					end
				end
				if endTime and speed and animation and windup and target and endTime > timer then
					self.ActiveAttacks[handle] = {
						Speed = speed,
						EndTime = endTime,
						AnimationTime = animation,
						WindUpTime = windup,
						StartTime = endTime - animation,
						Target = target,
					}
				end
			end
		end
		-- SET FARM MINIONS
		pos = myHero.pos
		speed = Attack:GetProjectileSpeed()
		windup = Attack:GetWindup()
		time = windup - self.ExtraFarmDelay:Value() * 0.001 --why is this -getlatency here? i isbjorn might try removing it -- - Data:GetLatency()
		anim = Attack:GetAnimation()
		for i = 1, #self.EnemyMinionsInAttackRange do
			local target = self.EnemyMinionsInAttackRange[i]
			table_insert(
				self.FarmMinions,
				self:SetLastHitable(
					target,
					anim,
					time + target.distance / speed,
					Damage:GetAutoAttackDamageAt(myHero, target, time + target.distance / speed, self.StaticAutoAttackDamage)
				)
			)
		end
		-- SPELLS
		for i = 1, #self.Spells do
			self.PendingSpellTicks = true
		end
	end,

	OnDraw = function(self)
		if self.MenuDrawings.Enabled:Value() and self.MenuDrawings.LastHittableMinions:Value() then
			for i = 1, #self.FarmMinions do
				local args = self.FarmMinions[i]
				local minion = args.Minion
				if Object:IsValid(minion) then
					if args.LastHitable then
						Draw.Circle(minion.pos, math_max(65, minion.boundingRadius), 1, Color.LastHitable)
					elseif args.AlmostLastHitable then
						Draw.Circle(minion.pos, math_max(65, minion.boundingRadius), 1, Color.AlmostLastHitable)
					end
				end
			end
		end
	end,

	GetPrediction = function(self, target, time)
		local timer, pos, team, handle, health, attackers
		timer = GameTimer()
		pos = target.pos
		handle = target.handle
		if self.TargetsHealth[handle] == nil then
			self.TargetsHealth[handle] = target.health + Data:GetTotalShield(target)
		end
		health = self.TargetsHealth[handle]
		for attackerHandle, attack in pairs(self:GetIncoming(handle)) do
            self.PredictionWork.candidates = self.PredictionWork.candidates + 1
			local c = 0
			local attacker = self.Handles[attackerHandle]
			if attacker and attack.Target == handle then
				local speed, startT, flyT, endT, damage
				speed = attack.Speed
				startT = attack.StartTime
				flyT = speed > 0 and GetDistance(attacker.pos, pos) / speed or 0
				endT = (startT + attack.WindUpTime + flyT) - timer
				if endT > 0 and endT < time then
					c = c + 1
					if self.AttackersDamage[attackerHandle] == nil then
						self.AttackersDamage[attackerHandle] = {}
					end
					if self.AttackersDamage[attackerHandle][handle] == nil then
						self.AttackersDamage[attackerHandle][handle] = Damage:GetAutoAttackDamage(attacker, target)
					end
					damage = self.AttackersDamage[attackerHandle][handle]

					health = health - damage
				end
			end
		end
		return health
	end,

	LocalGetPrediction = function(self, target, time)
		local timer, pos, team, handle, health, attackers, turretAttacked
		turretAttacked = false
		timer = GameTimer()
		pos = target.pos
		handle = target.handle
		if self.TargetsHealth[handle] == nil then
			self.TargetsHealth[handle] = target.health + Data:GetTotalShield(target)
		end
		health = self.TargetsHealth[handle]
		local handles = {}
		for attackerHandle, attack in pairs(self:GetIncoming(handle)) do
            self.PredictionWork.candidates = self.PredictionWork.candidates + 1
			local attacker = self.Handles[attackerHandle]
			if attacker and attacker.valid and attacker.visible and attacker.alive and attack.Target == handle then
				local speed, startT, flyT, endT, damage
				speed = attack.Speed
				startT = attack.StartTime
				flyT = speed > 0 and GetDistance(attacker.pos, pos) / speed or 0
				endT = (startT + attack.WindUpTime + flyT) - timer
				-- laneClear
				if endT < 0 and timer - attack.EndTime < 1.25 then
					endT = attack.WindUpTime + flyT
					endT = timer > attack.EndTime and endT or endT + (attack.EndTime - timer)
					startT = timer > attack.EndTime and timer or attack.EndTime
				end
				if endT > 0 and endT < time then
					handles[attackerHandle] = true
					-- damage
					if self.AttackersDamage[attackerHandle] == nil then
						self.AttackersDamage[attackerHandle] = {}
					end
					if self.AttackersDamage[attackerHandle][handle] == nil then
						self.AttackersDamage[attackerHandle][handle] = Damage:GetAutoAttackDamage(attacker, target)
					end
					damage = self.AttackersDamage[attackerHandle][handle]
					-- laneClear
					local c = 1
					while endT < time do
						if attackerHandle == self.AllyTurretHandle then
							turretAttacked = true
						else
							health = health - damage
						end
						endT = (startT + attack.WindUpTime + flyT + c * attack.AnimationTime) - timer
						c = c + 1
						if c > 10 then
							--print("ERROR LANECLEAR!")
							health = self.TargetsHealth[handle]
							break
						end
					end
				end
			end
		end
		-- laneClear
		for attackerHandle, obj in pairs(self.AllyMinionsHandles) do
			if handles[attackerHandle] == nil and obj and obj.valid and obj.visible and obj.alive then
				local aaData = obj.attackData
				local isMoving = obj.pathing and obj.pathing.hasMovePath
				if
					aaData ~= nil and aaData.projectileSpeed ~= nil and aaData.windUpTime ~= nil
                    and aaData.animationTime ~= nil and aaData.animationTime > 0 and (aaData.target == nil
					or self.Handles[aaData.target] == nil
					or isMoving
					or self.ActiveAttacks[attackerHandle] == nil)
				then
					local distance = GetDistance(obj.pos, pos)
					local range = Data:GetAutoAttackRange(obj, target)
					local extraRange = isMoving and 250 or 0
					if distance < range + extraRange then
						local speed, flyT, endT, damage
						speed = aaData.projectileSpeed
						distance = distance > range and range or distance
						flyT = speed > 0 and distance / speed or 0
						endT = aaData.windUpTime + flyT
						if endT < time then
							if self.AttackersDamage[attackerHandle] == nil then
								self.AttackersDamage[attackerHandle] = {}
							end
							if self.AttackersDamage[attackerHandle][handle] == nil then
								self.AttackersDamage[attackerHandle][handle] = Damage:GetAutoAttackDamage(obj, target)
							end
							damage = self.AttackersDamage[attackerHandle][handle]
							local c = 1
							while endT < time do
								health = health - damage
								endT = aaData.windUpTime + flyT + c * aaData.animationTime
								c = c + 1
								if c > 10 then
									--print("ERROR LANECLEAR!")
									health = self.TargetsHealth[handle]
									break
								end
							end
						end
					end
				end
			end
		end
		return health, turretAttacked
	end,

	SetLastHitable = function(self, target, anim, time, damage)
		local timer, handle, currentHealth, health, lastHitable, almostLastHitable, almostalmost, unkillable
		timer = GameTimer()
		handle = target.handle
		currentHealth = target.health + Data:GetTotalShield(target)
		self.TargetsHealth[handle] = currentHealth
		health = self:GetPrediction(target, time)
		lastHitable = false
		almostLastHitable = false
		almostalmost = false
		unkillable = false
		if (Object.IsAzir and ChampionInfo:IsInAzirSoldierRange(target)) then
			damage=({50, 67, 84, 101, 118})[myHero:GetSpellData(_W).level] + 0.6 * myHero.ap
		end
		-- unkillable
		if health < 0 then
			unkillable = true
			for i = 1, #self.OnUnkillableC do
				self.PendingUnkillable = self.PendingUnkillable or {}
                self.PendingUnkillable[#self.PendingUnkillable+1] = {callback=self.OnUnkillableC[i],target=target}
			end
			return {
				LastHitable = lastHitable,
				Unkillable = unkillable,
				AlmostLastHitable = almostLastHitable,
				PredictedHP = health,
				Minion = target,
				AlmostAlmost = almostalmost,
				Time = time,
			}
		end
		-- lasthitable
		if health - damage < 0 then
			lastHitable = true
			self.IsLastHitable = true
			return {
				LastHitable = lastHitable,
				Unkillable = unkillable,
				AlmostLastHitable = almostLastHitable,
				PredictedHP = health,
				Minion = target,
				AlmostAlmost = almostalmost,
				Time = time,
			}
		end
		-- almost lasthitable
		local turretAttack, extraTime, almostHealth, almostAlmostHealth, turretAttacked
		turretAttack = self.AllyTurret ~= nil and self.AllyTurret.attackData or nil
		extraTime = (1.5 - anim) * 0.3
		extraTime = extraTime < 0 and 0 or extraTime
		local almostTime = anim + time + extraTime
		local targetName = (target.charName or ""):lower()
		if targetName:find("minionsiege", 1, true) then
			almostTime = anim + time * 1.4 + extraTime
		end
		almostHealth, turretAttacked = self:LocalGetPrediction(target, almostTime)
		if almostHealth < 0 then
			almostLastHitable = true
			self.ShouldWaitTime = GetTickCount()
		elseif almostHealth - damage < 0 then
			almostLastHitable = true
		elseif currentHealth ~= almostHealth then
			almostAlmostHealth, turretAttacked = self:LocalGetPrediction(
				target,
				1.25 * anim + 1.25 * time + extraTime -- removed +0.5 just to test
			)
			if almostAlmostHealth - damage < 0 then
				almostalmost = true
			end
		end
		-- under turret, turret attackdata: 1.20048 0.16686 1200
		if
			turretAttacked
			or (turretAttack and turretAttack.target == handle)
			or (
				self.AllyTurret
				and (
					Data:IsInAutoAttackRange(self.AllyTurret, target)
					or Data:IsInAutoAttackRange2(self.AllyTurret, target)
				)
			)
		then
			local nearTurret, isTurretTarget, maxHP, startTime, windUpTime, flyTime, turretDamage, turretHits
			nearTurret = true
			isTurretTarget = turretAttack ~= nil and turretAttack.target == handle
			maxHP = target.maxHealth
			startTime = turretAttack and turretAttack.endTime and turretAttack.endTime - 1.20048 or 0
			windUpTime = 0.16686
			flyTime = GetDistance(self.AllyTurret, target) / 1200
			turretDamage = Damage:GetAutoAttackDamage(self.AllyTurret, target)
			turretHits = 1
			while maxHP > turretHits * turretDamage do
				turretHits = turretHits + 1
				if turretHits > 10 then
					--print("ERROR TURRETHITS")
					break
				end
			end
			turretHits = turretHits - 1
			return {
				LastHitable = lastHitable,
				Unkillable = unkillable,
				AlmostLastHitable = almostLastHitable,
				PredictedHP = health,
				Minion = target,
				AlmostAlmost = almostalmost,
				Time = time,
				-- turret
				NearTurret = nearTurret,
				IsTurretTarget = isTurretTarget,
				TurretHits = turretHits,
				TurretDamage = turretDamage,
				TurretFlyDelay = flyTime,
				TurretStart = startTime,
				TurretWindup = windUpTime,
			}
		end
		return {
			LastHitable = lastHitable,
			Unkillable = health < 0,
			AlmostLastHitable = almostLastHitable,
			PredictedHP = health,
			Minion = target,
			AlmostAlmost = almostalmost,
			Time = time,
		}
	end,

	ShouldWait = function(self)
		return GetTickCount() < self.ShouldWaitTime + 250
	end,

	GetPlantsTarget = function(self)
		if #self.PlantsMinionsInAttackRange > 0 then
			table_sort(self.PlantsMinionsInAttackRange, function(a, b)
				return a.maxHealth > b.maxHealth
			end)
			return self.PlantsMinionsInAttackRange[1]
		end
		return nil
	end,

	GetJungleTarget = function(self)
		if #self.JungleMinionsInAttackRange > 0 then
			table_sort(self.JungleMinionsInAttackRange, function(a, b)
				return a.maxHealth > b.maxHealth
			end)
			return self.JungleMinionsInAttackRange[1]
		end
		return #self.EnemyWardsInAttackRange > 0 and self.EnemyWardsInAttackRange[1] or nil
	end,

	GetFarmTargetPriority = function(self, minion)
		if minion.IsSennaSoul then
			return 4
		end
		local name = (minion.Minion.charName or ""):lower()
		if name:find("minionsiege", 1, true) or name:find("minionsuper", 1, true) then
			return 1
		end
		if name:find("minionmelee", 1, true) then
			return 2
		end
		return 3
	end,

	GetLastHitTarget = function(self)
		local bestPriority = math.huge
		local min = math.huge
		local result = nil
		for i = 1, #self.FarmMinions do
			local minion = self.FarmMinions[i]
			local unit = minion.Minion
			if
				Object:IsValid(unit)
				and minion.LastHitable
				and (Data:IsInAutoAttackRange(myHero, unit) or (Object.IsAzir and ChampionInfo:IsInAzirSoldierRange(unit)))
			then
				local priority = self:GetFarmTargetPriority(minion)
				local predictedHP = minion.PredictedHP or math.huge
				if priority < bestPriority or (priority == bestPriority and predictedHP < min) then
					bestPriority = priority
					min = predictedHP
					result = unit
				end
			end
		end
		if result then
			self.LastHitHandle = result.handle
			self.LastHitHandleExpire = GameTimer() + math_max(0.25, Attack:GetAnimation() + Data:GetLatency() + 0.1)
		end
		return result
	end,

	GetHarassTarget = function(self)
		if not Menu.Orbwalker.General.HarassFarm:Value() then
			return Target:GetComboTarget()
		end
		local LastHitPriority = Menu.Orbwalker.Farming.LastHitPriority:Value()
		local structure = #self.EnemyStructuresInAttackRange > 0 and self.EnemyStructuresInAttackRange[1] or nil
		if structure ~= nil then
			if not LastHitPriority then
				return structure
			end
			if self.IsLastHitable then
				return self:GetLastHitTarget()
			end
			if LastHitPriority and not self:ShouldWait() then
				return structure
			end
		else
			if not LastHitPriority then
				local hero = Target:GetComboTarget()
				if hero ~= nil then
					return hero
				end
			end
			if self.IsLastHitable then
				return self:GetLastHitTarget()
			end
			if LastHitPriority and not self:ShouldWait() then
				local hero = Target:GetComboTarget()
				if hero ~= nil then
					return hero
				end
			end
		end
	end,

	GetLaneMinion = function(self)
		local laneMinion = nil
		local num = 10000
		for i = 1, #self.FarmMinions do
			local minion = self.FarmMinions[i]
			if Data:IsInAutoAttackRange(myHero, minion.Minion) or (Object.IsAzir and ChampionInfo:IsInAzirSoldierRange(minion.Minion)) then
				if minion.PredictedHP < num and not minion.AlmostAlmost and not minion.AlmostLastHitable then --and (self.AllyTurret == nil or minion.CanUnderTurret) then
					num = minion.PredictedHP
					laneMinion = minion.Minion
				end
			--	Draw.Circle(minion.Minion.pos, 50, 1, Color.Red)
			end
		end
		return laneMinion
	end,

	GetLaneClearTarget = function(self)
		local LastHitPriority = Menu.Orbwalker.Farming.LastHitPriority:Value()
		local LaneClearHeroes = Menu.Orbwalker.General.LaneClearHeroes:Value()
		local structure = #self.EnemyStructuresInAttackRange > 0 and self.EnemyStructuresInAttackRange[1] or nil
		local other = #self.EnemyWardsInAttackRange > 0 and self.EnemyWardsInAttackRange[1] or nil
		if structure ~= nil then
			if not LastHitPriority then
				return structure
			end
			if self.IsLastHitable then
				return self:GetLastHitTarget()
			end
			if other ~= nil then
				return other
			end
			if LastHitPriority and not self:ShouldWait() then
				return structure
			end
		else
			if not LastHitPriority and LaneClearHeroes then
				local hero = Target:GetComboTarget()
				if hero ~= nil then
					return hero
				end
			end
			if self.IsLastHitable then
				return self:GetLastHitTarget()
			end
			if self:ShouldWait() then
				return nil
			end
			if LastHitPriority and LaneClearHeroes then
				local hero = Target:GetComboTarget()
				if hero ~= nil then
					return hero
				end
			end
			-- plants or pets
			local plants = self:GetPlantsTarget()
			if plants ~= nil then
				return plants
			end
			-- lane minion
			local laneMinion = self:GetLaneMinion()
			if laneMinion ~= nil then
				self.LaneClearHandle = laneMinion.handle
				self.LaneClearHandleExpire = GameTimer() + math_max(0.25, Attack:GetAnimation() + Data:GetLatency() + 0.1)
				return laneMinion
			end
			-- ward
			if other ~= nil then
				return other
			end
		end
		return nil
	end,
}

local MenuRandomHumanizer = Menu.Orbwalker.RandomHumanizer

Movement = {

	MoveTimer = 0,

	GetHumanizer = function(self)
		local min = MenuRandomHumanizer.Min:Value()
		local max = MenuRandomHumanizer.Max:Value()
		return max <= min and min or math_random(min, max)
	end,
}

do
	_G.LevelUpKeyTimer = 0

	Callback.Add("WndMsg", function(msg, wParam)
		if msg == HK_LUS or wParam == HK_LUS then
			_G.LevelUpKeyTimer = GetTickCount()
		end
	end)

	local AttackKey = Menu.Main.AttackTKey
	local FastKiting = Menu.Orbwalker.General.FastKiting

	_G.Control.Evade = function(a)
		local pos = GetControlPos(a)
		if pos then
			EvadeSupport = nil
			if Cursor.Step == 0 then
				Cursor:Add(MOUSEEVENTF_RIGHTDOWN, pos)
				return true
			end
			EvadeSupport = pos
			return true
		end
		EvadeSupport = nil
		return false
	end

	_G.Control.Attack = function(target, actionRecord)
		if target then
			local issued
            if actionRecord then issued=Cursor:DispatchRecord(actionRecord,AttackKey:Key(),target)
            else issued=Cursor:Add(AttackKey:Key(),target) end
			if not issued then
				return false
			end
			if FastKiting:Value() then
				Movement.MoveTimer = 0
			end
			return true
		end
		return false
	end

	_G.Control.CastSpell = function(key, a, b, c)
		local pos = GetControlPos(a, b, c)
		if pos then
			if Cursor.Step > 0 then
				return false
			end
			if not b then
				if not (Vector(pos):To2D().onScreen) then return false end
			end

			if a and (a.x or a[1]) then
				if (GetDistance(Game.mousePos(), pos)) < 2 then
					--return false
				end	
			end
			
			if not b and a.pos then
				return Cursor:Add(key, a)
			else
				return Cursor:Add(key, pos)
			end
		end
		if not a then
			return Cursor:SendKeys(key, "control")
		end
		return false
	end

	-- _G.Control.Hold = function(key)
	-- 	CastKey(key)
	-- 	Movement.MoveTimer = 0
	-- 	Orbwalker.CanHoldPosition = false
	-- 	return true
	-- end

	_G.Control.Move = function(a, b, c)
		if Cursor.Step > 0 or GetTickCount() < Movement.MoveTimer then
			return false
		end
		local pos = GetControlPos(a, b, c)
		if pos then
			if not Cursor:Add(MOUSEEVENTF_RIGHTDOWN, pos) then return false end
		elseif not a then
			local unit = Game.GetUnderMouseObject()
			if unit and unit.isEnemy and unit.isTargetable then
				return false
			end
			if myHero.pathing.hasMovePath and GetDistance(Cursor:GetPlayerPosition(), myHero.pathing.endPos) < Menu.Main.Humanizer:Value() then
				return false
			end
			if not Cursor:Add(MOUSEEVENTF_RIGHTDOWN, Cursor:GetPlayerPosition()) then return false end
		end
		Movement.MoveTimer = GetTickCount() + Movement:GetHumanizer()
		-- Orbwalker.CanHoldPosition = true
		return true
	end
end

local MenuMultipleTimes = Menu.Main.SetCursorMultipleTimes
local MenuDelay = Menu.Main.CursorDelay
local MenuDrawCursor = Menu.Main.Drawings.Cursor

Cursor = {

	Step = 0,
	ForceTCOUp = false,

	Add = function(self, key, castPos)
		if type(key) == "table" then
            self.Keys = key
		else
            self.Keys = { key }  -- store it in a table format for consistency
		end
		self.CursorPos = cursorPos
		self.CastPos = castPos
		if self.CastPos ~= nil then
			self.IsTarget = self.CastPos.pos ~= nil
			self.correctedCastPos = self.CastPos
			self.IsMouseClick = key == MOUSEEVENTF_RIGHTDOWN
			self:StepSetToCastPos()
			local issued = self:StepPressKey()
			if issued then
				self.Timer = GetTickCount() + MenuDelay:Value()
			end
			return issued
		end
		return false
	end,

	StepReady = function(self)
		if FlashHelper.Flash then
			self:Add(FlashHelper.Flash, myHero.pos:Extended(Vector(Cursor:GetPlayerPosition()), 600))
			FlashHelper.Flash = nil
		elseif EvadeSupport then
			if JustEvade and JustEvade.Evading() then
				self:Add(MOUSEEVENTF_RIGHTDOWN, EvadeSupport)
			end
			EvadeSupport = nil
		end
	end,

	ProjectCastPosition = function(self)
		local pos
		if self.IsTarget then
			pos = self.CastPos.pos:To2D()
			if self.CastPos.charName == "GangplankBarrel" then
				pos.y=pos.y-((69/1440)*Game.Resolution().y)
			end
			if self.CastPos.charName:lower():find("chaosminion") or self.CastPos.charName:lower():find("orderminion") then
				pos.y=pos.y-((25/1440)*Game.Resolution().y)
			end
		else
			pos = (self.CastPos.z ~= nil) and Vector(self.CastPos.x, self.CastPos.y or 0, self.CastPos.z):To2D()
				or Vector({ x = self.CastPos.x, y = self.CastPos.y })
		end
		return pos
	end,
	StepSetToCastPos = function(self)
		local pos = self:ProjectCastPosition()
		self.correctedCastPos = pos
		self:SetPosition(pos, "action")
	end,

	StepPressKey = function() return false end,

	StepWaitForResponse = function(self)
		if GetTickCount() > self.Timer then
			self.Step = 2
		elseif MenuMultipleTimes:Value() then
			self:StepSetToCastPos()
		end
	end,

	StepSetToCursorPos = function(self)
		self:SetPosition(self.CursorPos, "return")
		self.Timer = GetTickCount() + MenuDelay:Value()
		self.Step = 3
	end,

	StepWaitForReady = function(self)
		if GetTickCount() > self.Timer then
			self.Step = 0
			self.ForceTCOUp = false
		end
	end,

	OnTick = function(self)
		local step = self.Step
		if step == 0 then
			self:StepReady()
		elseif step == 1 then
			self:StepWaitForResponse()
		elseif step == 2 then
			self:StepSetToCursorPos()
		elseif step == 3 then
			self:StepWaitForReady()
		end
	end,

	OnDraw = function(self)
		if MenuDrawCursor:Value() then
			Draw.Circle(Cursor:GetPlayerPosition(), 150, 1, Color.Cursor)
		end
	end,
}

do
    local timing = (function()
-- Callback-clock measurements, never sub-millisecond claims or timeout learning.
local T={}; T.__index=T
local function statistics(self)
    if self.cachedRevision==self.sampleRevision then return self.cachedStats end
    local sorted={};for i=1,#self.gaps do sorted[i]=self.gaps[i] end
    table.sort(sorted)
    local function q(p)return sorted[math.max(1,math.ceil(#sorted*p))]end
    local median,p95,p99=q(.5),q(.95),q(.99)
    local result={median=median,p95=p95,p99=p99,quantum=math.max(1,median or 1),
        reserve=#sorted<3 and 0 or (p95 or 0)+math.max(0,(p95 or 0)-(median or 0))}
    self.cachedRevision=self.sampleRevision;self.cachedStats=result
    return result
end
function T.new(fallback)
    return setmetatable({fallback=fallback,enabled=false,validatedMoves=false,
        removeSecondWait=false,profiles={},gaps={},sampleRevision=0,lastTick=nil,
        resolution='GetTickCount units; effective resolution and callback jitter require live measurement'},T)
end
function T:tick(now)
    if type(now)~='number' or now~=now or math.abs(now)==math.huge or self.lastTick and now<self.lastTick then
        self.invalidTimes=(self.invalidTimes or 0)+1;return
    end
    if self.lastTick and now>self.lastTick then
        self.sampleRevision=self.sampleRevision+1
            local index=(self.gapIndex or 0)%128+1;self.gapIndex=index
            self.gaps[index]=now-self.lastTick
    end
    self.lastTick=now
end
function T:reserve()
    return statistics(self).reserve
end
-- A preparation allowance is a deadline, never a sleep or a claim that a spell
-- landed. Keep it separate from post-send hold calibration and absolute expiry.
function T:preparationBudget(hold)
    local stats=statistics(self)
    return math.min(300,math.max(120,hold*2,hold+3*(stats.p95 or 0),self.preparationFloor or 0))
end
function T:observePreparation(action,now,exhausted)
    if not action.resolveWorldTarget or not action.acquiredAt or action.preparationRecorded then return end
    local elapsed=now-action.acquiredAt
    if elapsed<0 or elapsed~=elapsed or elapsed==math.huge then return end
    action.preparationRecorded=true;action.preparationMs=elapsed
    local stats=statistics(self);local reserve=math.max(16,stats.p95 or 0)
    if exhausted then
        self.preparationExhausted=(self.preparationExhausted or 0)+1
        self.preparationFloor=math.min(300,math.max(self.preparationFloor or 120,elapsed+(action.hold or 30)+reserve))
        self.preparationSuccesses=0;self.preparationPeak=0
    else
        self.preparationSuccesses=(self.preparationSuccesses or 0)+1
        self.preparationPeak=math.max(self.preparationPeak or 0,elapsed)
        -- Reduce conservatively only after a full window of successful sends.
        if self.preparationSuccesses>=32 then
            self.preparationFloor=math.min(300,math.max(120,(self.preparationFloor or 120)-reserve,
                self.preparationPeak+(action.hold or 30)+reserve))
            self.preparationSuccesses=0;self.preparationPeak=0
        end
    end
end
function T:profile(class)
    if not self.profiles[class] then
        self.profiles[class]={reliable=self.fallback(),candidate=nil,samples=0,directions={},unknown=0,misdirected=0,
            baselineSamples=0,baselineDirections={},seen={},recent={}}
    end
    return self.profiles[class]
end
function T:hold(class,critical)
    local p=self:profile(class)
    if critical or class~='move' or not self.enabled or not self.validatedMoves then return self.fallback() end
    return math.max(p.candidate or p.reliable,self:reserve())
end
function T:beginTrial(class,value)
    local p=self:profile(class)
    if class~='move' or not self.enabled or not self.validatedMoves or #self.gaps<30
        or type(value)~='number' or value~=value or value<self:reserve() or value>=p.reliable
        or p.failedFloor and value<=p.failedFloor then return false end
    p.candidate=value;p.samples=0;p.directions={};return true
end
function T:observe(action,evidence)
    local previous
    for _,name in ipairs({'requestedAt','sentAt','sendCompletedAt','releasedAt'}) do
        local value=action[name]
        if value~=nil then
            if type(value)~='number' or value~=value or math.abs(value)==math.huge or previous and value<previous then
                self.invalidTimes=(self.invalidTimes or 0)+1;return
            end
            previous=value
        end
    end
    local p=self:profile(action.class)
    if not evidence or evidence.result=='unknown' then p.unknown=p.unknown+1;return end
    if action.interrupted or action.competitor or not evidence.unique or evidence.actionID~=action.id
        or not evidence.sourceValidated then p.unknown=p.unknown+1;return end
    if p.seen[action.id] then return end
    p.seen[action.id]=true;p.recent[#p.recent+1]=action.id
    if #p.recent>128 then p.seen[table.remove(p.recent,1)]=nil end
    if evidence.result=='misdirected' then
        p.misdirected=p.misdirected+1
        p.failedFloor=math.max(p.failedFloor or 0,action.hold or p.candidate or p.reliable)
        if not p.candidate then p.reliable=p.previousReliable or self.fallback() end
        p.candidate=nil;p.samples=0;p.directions={};p.baselineSamples=0;p.baselineDirections={};return
    end
    if evidence.result~='confirmed' or action.class~='move' or action.critical or not evidence.direction then return end
    if not p.candidate then
        if action.hold~=p.reliable then return end
        p.baselineSamples=p.baselineSamples+1;p.baselineDirections[evidence.direction]=true
        local count=0;for _ in pairs(p.baselineDirections) do count=count+1 end
        if p.baselineSamples>=30 and count>=3 then
            local quantum=statistics(self).quantum
            self:beginTrial('move',math.max(self:reserve(),p.reliable-quantum))
            p.baselineSamples=0;p.baselineDirections={}
        end
        return
    end
    if action.hold~=p.candidate then return end
    p.samples=p.samples+1;p.directions[evidence.direction]=true
    local count=0;for _ in pairs(p.directions) do count=count+1 end
    if p.samples>=30 and count>=3 then p.previousReliable=p.reliable;p.reliable=p.candidate;p.candidate=nil;p.samples=0;p.directions={} end
end
function T:summary()
    local profiles={}
    for class,p in pairs(self.profiles) do
        local dirs,base=0,0;for _ in pairs(p.directions) do dirs=dirs+1 end;for _ in pairs(p.baselineDirections) do base=base+1 end
        profiles[class]={reliable=p.reliable,candidate=p.candidate,previousReliable=p.previousReliable,
            failedFloor=p.failedFloor,
            samples=p.samples,directions=dirs,baselineSamples=p.baselineSamples,baselineDirections=base,
            unknown=p.unknown,misdirected=p.misdirected}
    end
    local stats=statistics(self)
    return {clock=self.resolution,invalidTimes=self.invalidTimes or 0,callbackMedian=stats.median,callbackP95=stats.p95,
        callbackP99=stats.p99,reserve=stats.reserve,validatedMoves=self.validatedMoves,
        enabled=self.enabled,profiles=profiles,preparationBudget=self:preparationBudget(self.fallback()),
        preparationFloor=self.preparationFloor,preparationExhausted=self.preparationExhausted or 0}
end
return T

end)()
    local create = (function()
-- Single Lua cursor/input owner. No raw mouse deltas, input interception or
-- cursor hiding are claimed. Screen-motion reconstruction is observation only.
return function(cursor,env)
    for _,name in ipairs({'screen','world','liveWorld','resolution'}) do
        local read=env[name]
        if read then env[name]=function()
            if cursor.Metrics and cursor.DiagnosticsEnabled~=false then cursor.Metrics.cursorReads=(cursor.Metrics.cursorReads or 0)+1 end
            local ok,value=pcall(read);if ok then return value end
        end end
    end
    local function copy(p)
        if not p then return end
        return {x=p.x,y=p.y,z=p.z}
    end
    local function finite(x) return type(x)=='number' and x==x and math.abs(x)<math.huge end
    local function worldDistance(a,b)
        if not a or not b or not finite(a.x) or not finite(b.x) or not finite(a.z) or not finite(b.z) then return math.huge end
        return math.sqrt((a.x-b.x)^2+(a.z-b.z)^2)
    end
    local function near(a,b)
        return a and b and finite(a.x) and finite(a.y) and finite(b.x) and finite(b.y)
            and (a.x-b.x)^2+(a.y-b.y)^2<=25
    end
    local function screenDistance(a,b)
        if not a or not b or not finite(a.x) or not finite(a.y) or not finite(b.x) or not finite(b.y) then return math.huge end
        return math.sqrt((a.x-b.x)^2+(a.y-b.y)^2)
    end
    local function safe(fn,...) if not fn then return true end local ok,value=pcall(fn,...);return ok and value end
    local project=cursor.StepSetToCastPos
    cursor.env=env;cursor.InputVersion='lua-1';cursor.Generation=0;cursor.Serial=0
    cursor.GGCompatible=env.ggCompatible==true
    cursor.SessionID='lua-input-'..tostring(env.clock())
    cursor.Queue={};cursor.Records={};cursor.Recent={};cursor.Warps={};cursor.KeysOwned={}
    cursor.Buttons={};cursor.TickSerial=0
    cursor.CommandGenerations={};cursor.Physical={};cursor.PendingUp={};cursor.KeyEchoes={};cursor.Sources={};cursor.Step=0;cursor.NotBefore=0
    cursor.Capabilities={independentMotion=false,hideCursor=false,withholdInput=false,clickQueue=false,
        reconstructedMotionAffectsReturn=false}
    cursor.PlayerScreen=copy(env.screen());cursor.PlayerWorld=copy(env.world())
    cursor.Timing=env.timing.new(env.fallback)
    cursor.DiagnosticErrors={rows={},head=1,count=0,lost=0,sequence=0}
    cursor.DetailedDiagnostics=true
    cursor.Metrics={events={},eventHead=1,eventCount=0,lostEvents=0,sequence=0,hostCalls=0,hostDuration=0,hostDurationMax=0,unknown=0,misdirected=0,interruptions=0}
    function cursor:record()end
    function cursor:GetDiagnosticEvents()return {},0 end
    function cursor:GetDiagnosticErrors()return {},0 end
    function cursor:GetPendingButtons()
        local out={}
        for vk,row in pairs(self.Buttons) do
            out[tostring(vk)]={owner=row.owner,id=row.action.id,pendingUp=true,retries=row.retries,
                lastAttemptTick=row.lastTick,physicalTakeover=row.manual==true,exhausted=row.retries>=3}
        end
        return out
    end
    function cursor:GetDiagnostics()return {pendingButtons=self:GetPendingButtons()}end
    function cursor:call(fn,...)
        self.InFlight=(self.InFlight or 0)+1
        local ok,value=pcall(fn,...);self.InFlight=self.InFlight-1
        return ok and value~=false,value
    end
    local canonicalKey={[160]=16,[161]=16,[162]=17,[163]=17,[164]=18,[165]=18}
    local keyFamilies={[16]={16,160,161},[17]={17,162,163},[18]={18,164,165}}
    function cursor:GetPlayerPosition() return copy(self.PlayerWorld or env.world()) end
    function cursor:GetPlayerScreenPosition() return copy(self.PlayerScreen) end
    function cursor:ReadKeyState(key)
        -- The host exposes current state, not a raw physical-input stream.
        -- Owned keys and unavailable/erroring queries remain unknown.
        local family=canonicalKey[key] or key
        for _,alias in ipairs(keyFamilies[family] or {key}) do if self.KeysOwned[alias] then return nil end end
        if not env.isDown then return nil end
        local ok,state=pcall(env.isDown,key)
        if ok and type(state)=='boolean' then return state end
    end
    function cursor:IsSyntheticEvent() return (self.InFlight or 0)>0 or self.LastInputSynthetic==true end
    function cursor:ReconcilePhysical()
        if not self.PhysicalReview or env.clock()<(self.PhysicalPollAt or 0) then return end
        local now=env.clock();self.PhysicalPollAt=now+100
        for key,first in pairs(self.PhysicalReview) do
            local released=true
            for _,alias in ipairs(keyFamilies[key] or {key}) do
                if self:ReadKeyState(alias)~=false then released=false;break end
            end
            if not self.Physical[key] then self.PhysicalReview[key]=nil
            elseif released and first and now-first>=90 then
                self.Physical[key]=nil;self.PhysicalReview[key]=nil
                self:record('physical_state_reconciled',nil,tostring(key)..': two focused released samples; no key-up sent')
            else self.PhysicalReview[key]=released and now or false end
        end
        if not next(self.PhysicalReview) then self.PhysicalReview=nil end
    end
    function cursor:PruneKeyEchoes()
        local now=env.clock()
        for i=#self.KeyEchoes,1,-1 do
            local row=self.KeyEchoes[i]
            -- Active owned holds can receive their first echo after a stalled
            -- callback (>150ms in live traces). Keep only the exact current
            -- lease's down edge longer, never arbitrary old/manual presses.
            local owned=row.down and row.lease and self.KeysOwned[row.key]
                and self.KeyLeases and self.KeyLeases[row.key]==row.lease
            if now-row.at>(owned and 1000 or 150) then table.remove(self.KeyEchoes,i) end
        end
    end
    function cursor:ExpectKey(key,down)
        self:PruneKeyEchoes()
        local row={key=canonicalKey[key] or key,down=down,at=env.clock(),seen={}}
        self.KeyEchoes[#self.KeyEchoes+1]=row
        if #self.KeyEchoes>64 then table.remove(self.KeyEchoes,1) end
        return row
    end
    function cursor:Interfere(action,cause)
        local id=action and action.id
        if not id then self.AnonymousEffect=(self.AnonymousEffect or 0)-1;id=self.AnonymousEffect end
        if self.LastEffectAction==id then return end
        self.LastEffectAction=id
        for _,previousID in ipairs(self.Recent) do
            local r=self.Records[previousID]
            if r and r.id~=id and r.sentAt and not r.observedAt and not r.timedOut then
                r.competitor=true;r.interferenceID=id;r.interferenceAt=env.clock();r.interferenceCause=cause
                self:record('interference',r,cause)
            end
        end
    end
    function cursor:ButtonReleased(vk)
        if self.Physical[vk] or not env.isDown then return false end
        local ok,down=pcall(env.isDown,vk);return ok and down==false
    end
    function cursor:ReleaseButton(vk,retry)
        local row=self.Buttons[vk];if not row then return true end
        if self.Physical[vk] or row.manual then return false end
        if row.upTried and not retry then return false end
        if retry then
            if row.retries>=3 or row.lastTick==self.TickSerial then return false end
            row.retries=row.retries+1
        end
        row.lastTick=self.TickSerial;row.upTried=true
        local ok=self:CallMouse(vk==1 and 4 or 16,vk,false,row.action)
        if self.Active==row.action and row.action.sentAt then
            row.action.holdUntil=row.action.sendCompletedAt+row.action.hold;self.Timer=row.action.holdUntil
        end
        if self:ButtonReleased(vk) then
            self.Buttons[vk]=nil;self:record('button_released',row.action,tostring(vk));return ok
        end
        self:record(row.retries>=3 and 'button_release_exhausted' or 'button_release_pending',row.action,tostring(vk))
        return false
    end
    function cursor:CleanupButtons(retry,owner)
        for vk,row in pairs(self.Buttons) do
            if not owner or row.owner==owner then
                if self:ButtonReleased(vk) then self.Buttons[vk]=nil;self:record('button_released',row.action,tostring(vk))
                elseif not row.manual then self:ReleaseButton(vk,retry) end
            end
        end
    end
    function cursor:CallMouse(flag,vk,down,action)
        local row=self:ExpectKey(vk,down)
        row.mouse=true;row.pos=copy(self.ActionScreen);row.returnPos=copy(self.PlayerScreen)
        self:Interfere(action,down and "mouse down" or "mouse up")
        local ok,result=self:call(env.mouse,flag)
        if action then
            if down or self.Active==action then action.sendCompletedAt=env.clock()
            else action.buttonReleaseCompletedAt=env.clock() end
        end
        if not ok then
            for i=#self.KeyEchoes,1,-1 do if self.KeyEchoes[i]==row then table.remove(self.KeyEchoes,i);break end end
        end
        return ok,result
    end
    function cursor:MatchKeyEcho(key,down,mouse)
        self:PruneKeyEchoes()
        -- A host may omit an earlier key-up callback even though the key was
        -- released. Its stale FIFO entry must not misclassify the next owned
        -- acquisition as a player's permanent hold. Only bypass it for the
        -- exact, still-owned lease whose down we actually issued. Mouse input
        -- and unmatched user key presses keep the stricter attribution below.
        local lease=not mouse and down and self.KeysOwned[key] and self.KeyLeases and self.KeyLeases[key]
        if lease then
            for index,row in ipairs(self.KeyEchoes) do
                if row.key==(canonicalKey[key] or key) and row.down and row.lease==lease and not row.seen[key] then
                    for i=1,index do
                        local prior=self.KeyEchoes[i]
                        if prior.key==row.key and prior.lease and prior.lease<=lease then prior.seen[key]=true end
                    end
                    return true
                end
            end
        end
        for _,row in ipairs(self.KeyEchoes) do
            if row.key==(canonicalKey[key] or key) and not row.seen[key] then
                -- Preserve order separately for generic and side-specific modifiers.
                -- This is bounded echo attribution, never proof of game acceptance
                -- or physical input interception. Mismatches remain manual input.
                if row.down~=down then return false end
                if mouse and (not row.mouse or not near(env.screen(),row.pos) and not near(env.screen(),row.returnPos)) then return false end
                row.seen[key]=true;return true
            end
        end
        return false
    end
    -- Separate command identity from aim/transport interference. This receipt is
    -- not execution evidence; consumers still need a fresh mechanical transition.
    function cursor:CommandGeneration(key)
        return self.CommandGenerations[canonicalKey[key] or key] or 0
    end
    function cursor:AdvanceCommand(key)
        key=canonicalKey[key] or key
        self.CommandGenerations[key]=(self.CommandGenerations[key] or 0)+1
        return key,self.CommandGenerations[key]
    end
    function cursor:CallKey(key,down,action,releasedLease)
        if down then
            local command,generation=self:AdvanceCommand(key)
            if action and action.keys and #action.keys==1 and not action.commandReceipt then
                action.commandReceipt={key=command,generation=generation,expiresAt=env.clock()+1000,session=self.SessionID}
            end
        end
        local row=self:ExpectKey(key,down) -- Before synchronous host callbacks.
        row.lease=releasedLease or self.KeyLeases and self.KeyLeases[key]
        if action then action.sentAt=action.sentAt or env.clock();action.state='sent' end
        self:Interfere(action,down and "key down" or "key up")
        local ok,result=self:call(down and env.down or env.up,key)
        if action then action.sendCompletedAt=env.clock() end
        if not ok then
            for i=#self.KeyEchoes,1,-1 do
                if self.KeyEchoes[i]==row then table.remove(self.KeyEchoes,i);break end
            end
        end
        return ok,result
    end
    function cursor:AcquireKey(key,owner,action)
        if not key then return false end
        if self.Uncertain or not self:Available() then return false end
        if self.KeysOwned[key] then
            if action then action.reason='key_already_owned';return false end
            return self.KeysOwned[key]==owner
        end
        if self.Physical[key] or safe(env.isDown,key) then return false end
        if action and action.budgetEnd and not self:InputBudget(action) then return false end
        if action and action.prevalidateWorldCast and not action.sentAt then
            local ticket=action.commitCertificate;action.commitCertificate=nil
            if self.Active~=action or not self:valid(action,true) then return false end
            if not ticket or ticket.pass~=self.ResolutionPass or not action.resolution
                or ticket.revision~=action.resolution.revision or env.clock()-ticket.at>20 then
                action.reason='world_commit_expired';return false
            end
            if not near(env.screen(),action.actionScreen) then action.reason='cursor_changed_before_send';return false end
        end
        self.KeysOwned[key]=owner -- Register ownership before synchronous callbacks.
        self.KeyLeases=self.KeyLeases or {};self.KeyLeaseSerial=(self.KeyLeaseSerial or 0)+1
        self.KeyLeases[key]=self.KeyLeaseSerial
        if action then action.keyLease=self.KeyLeaseSerial end
        if action then action.sentAt=action.sentAt or env.clock();action.state='sent' end
        local ok=self:CallKey(key,true,action)
        if not ok then self:ReleaseKey(key,owner,action) end
        return ok
    end
    function cursor:ReleaseKey(key,owner,action,lease,finalCleanup)
        if self.Resolving then return false end
        if lease and (not self.KeyLeases or self.KeyLeases[key]~=lease) then return false end
        if self.KeysOwned[key]~=owner then return false end
        local acquisition=self.KeyLeases and self.KeyLeases[key]
        local previous=self.PendingUp[key]
        if previous and previous.attempts>=3 and not finalCleanup and safe(env.isDown,key) then return false end
        self.KeysOwned[key]=nil;self.PendingUp[key]=nil
        if self.KeyLeases then self.KeyLeases[key]=nil end
        if self.Physical[key] then return false end
        local ok=self:CallKey(key,false,action,acquisition)
        if safe(env.isDown,key) then
            self.KeysOwned[key]=owner;self.KeyLeases[key]=acquisition
            self.PendingUp[key]={owner=owner,attempts=previous and previous.attempts+1 or 0,lease=acquisition}
            self:record('key_release_pending',self.Active,tostring(key))
        end
        return ok
    end
    function cursor:PulseKeys(keys,owner,action)
        owner=owner or 'control'
        if not self:Available() then return false end
        if type(keys)~='table' then keys={keys} end
        for _,key in ipairs(keys) do
            if self.Physical[key] or safe(env.isDown,key) and self.KeysOwned[key]~=owner then return false end
        end
        for _,key in ipairs(keys) do
            if not self:AcquireKey(key,owner,action) then return false end
            if not self:ReleaseKey(key,owner,action) then return false end
        end
        -- Host return is submission only, never spell confirmation.
        return true
    end
    function cursor:SendKeys(keys,owner)
        local r=self:newAction{keys=keys,owner=owner,critical=true,class='key'}
        self.LastActionID=r.id
        if not self:valid(r) then r.state='aborted';r.abortedAt=env.clock();return false end
        -- A key-only command can coexist with an aim lease but cannot establish
        -- unique attribution for another in-flight action.
        local result=self:PulseKeys(r.keys,r.owner,r)
        if not r.sentAt then r.state='aborted';r.abortedAt=env.clock() end
        r.releasedAt=env.clock();self:record(r.sentAt and 'sent' or 'aborted',r,result and nil or 'key submission declined or uncertain')
        return result
    end
    function cursor:IsChatOpen()
        -- Some hosts report false while the chat editor is visibly open.
        -- Keep physical Enter/Escape evidence until explicitly dismissed;
        -- injected Enter and key-repeat must never change this latch.
        return self.ChatLatched==true or (env.chat and safe(env.chat)==true) or false
    end
    function cursor:Available()
        return not self.Resolving and not self.Stopped and safe(env.enabled) and safe(env.focus)
            and not self:IsChatOpen() and not env.hero.dead
    end
    function cursor:SetPosition(p,phase,action)
        if self.Resolving then return false end
        if phase=='action' then self.PlacementAccepted=false end
        if not p or not finite(p.x) or not finite(p.y) then return false end
        if phase=='action' and p.onScreen==false then return false end
        local bounds=env.resolution and env.resolution()
        if bounds and (p.x<0 or p.y<0 or p.x>=bounds.x or p.y>=bounds.y) then return false end
        local warp={pos={x=p.x,y=p.y},phase=phase,at=env.clock(),id=self.Active and self.Active.id}
        self.Warps[#self.Warps+1]=warp
        if #self.Warps>32 then table.remove(self.Warps,1) end
        self.LastWarp=warp -- Before host invocation: synchronous WndMsg is synthetic too.
        local aiming=phase=='action' and self.Active and self.Active.class=='hover' and self.Active
        if aiming then aiming.sentAt=aiming.sentAt or warp.at;aiming.state='sent' end
        self:Interfere(action or self.Active,"cursor "..tostring(phase))
        local ok,result=self:call(env.set,p.x,p.y)
        if aiming then aiming.sendCompletedAt=env.clock();if not ok then aiming.submissionFailed=true end end
        if phase=='action' then self.PlacementAccepted=ok end
        if near(env.screen(),warp.pos) then warp.observed=true end
        return ok,result
    end
    function cursor:PollReturn(p)
        local r=self.PendingReturn;if not r then return end
        local now=env.clock()
        if near(p,r.returnTarget) then
            r.returnObservedAt=now;self.PendingReturn=nil;self.Uncertain=false;self.UntrustedScreen=nil
            self:record('return_observed',r,'Later screen sample; no input acceptance claim');return
        end
        if self.Generation~=r.returnGeneration or not self:Available() then
            self.PendingReturn=nil;self:record('return_unconfirmed',r,'New input or unavailable; no retry');return
        end
        if now>r.returnRequestedAt and not r.returnRetried and near(p,r.returnBefore) then
            r.returnRetried=true;self.RecoveryUsed=true
            r.returnAccepted=self:SetPosition(r.returnTarget,'return',r);r.returnSample=copy(env.screen())
            self:record('return_retry',r,'One retry while cursor still at pre-return position')
            if near(r.returnSample,r.returnTarget) then
                r.returnObservedAt=now;self.PendingReturn=nil;self.Uncertain=false;self.UntrustedScreen=nil
                self:record('return_observed',r,'Screen sample after bounded retry')
            end
        elseif now-r.returnRequestedAt>=100 then
            self.PendingReturn=nil
            self:record('return_unconfirmed',r,'No matching sample; no continued cursor forcing')
        end
    end
    function cursor:SamplePlayer()
        local p=env.screen();if not p then return end
        if self.PendingReturn then self:PollReturn(p);p=env.screen();if not p then return end end
        local now=env.clock();local synthetic=false
        local guard=self.ReturnGuard
        if guard and (now-guard.at>250 or self.Active or self.Generation~=guard.generation) then
            self.ReturnGuard=nil;guard=nil
        end
        if guard and not self.PendingReturn and not self.RecoveryUsed
            and screenDistance(p,guard.previous)>math.max(256,guard.radius*2)
            and screenDistance(p,guard.action)<=guard.radius and screenDistance(p,self.PlayerScreen)>256 then
            -- A discontinuous return to the recent action region is ambiguous,
            -- even if real motion has moved it away from the exact warp pixel.
            -- Never reconstruct deltas: one recovery uses only the last trusted
            -- player sample. Smooth traversal of the region is left untouched.
            self.ReturnGuard=nil;self.RecoveryUsed=true;self.Uncertain=true;self.UntrustedScreen=copy(p)
            self:record('return_discontinuity',guard.actionRecord,'Suspected delayed action displacement; one bounded return')
            self:CancelAll('suspected delayed cursor displacement',true)
            self:SetPosition(self.PlayerScreen,'return')
            if near(env.screen(),self.PlayerScreen) then self.Uncertain=false end
            return
        end
        for i=#self.Warps,1,-1 do
            local w=self.Warps[i]
            if now-w.at>250 then table.remove(self.Warps,i)
            elseif near(p,w.pos) then
                synthetic=true;w.observed=true
                -- A delayed action warp after release never becomes player aim.
                if not self.Active and w.phase=='action' and self.LastReturnAt and w.at<=self.LastReturnAt
                    and not near(p,self.PlayerScreen) and not w.recovered then
                    w.recovered=true;self:record('late_warp',nil,'return once; attribution uncertain')
                    self.UntrustedScreen=copy(p)
                    self.Uncertain=true
                    self:CancelAll('late synthetic cursor feedback',true)
                    if not self.RecoveryUsed then self.RecoveryUsed=true;self:SetPosition(self.PlayerScreen,'return') end
                end
                break
            end
        end
        if synthetic then return end
        if not self.Active and (self.PendingReturn or near(p,self.UntrustedScreen)) then return end
        if self.Active then
            if not near(p,self.ActionScreen) and not near(p,self.PlayerScreen) then
                local r=self.Active
                -- A key already handed to the host still needs its complete
                -- post-send cursor stabilization. Pure pointer sampling must
                -- not itself warp back to the player position during that hold.
                -- This does not constrain physical motion, reposition, retry or
                -- extend the hold. Explicit input/cancel/unavailability still
                -- takes the immediate cleanup path; after hold, ordinary motion
                -- reconciliation below resumes.
                if r.sentAt and r.class=='cast' and r.space=='world' and not r.leftClicks
                    and r.holdUntil and now<r.holdUntil then
                    if not r.pointerMotionDuringHold then
                        r.pointerMotionDuringHold=true
                        self:record('pointer_motion_during_hold',r,'No return warp before post-send stabilization ends')
                    end
                    return
                end
                if self.CanCorrectWorldDrift and self:CanCorrectWorldDrift(r,p) then
                    if not r.pointerCorrectionPending then
                        r.pointerCorrectionPending=true
                        self:record('world_pointer_correction_pending',r,'Small drift; fresh validation and placement required')
                    end
                    return
                end
                self.ReconstructedScreen=copy(p)
                self:record('player_motion_ambiguous',self.Active,'screen delta observed; return reconstruction is not validated')
                self.Uncertain=true
                self:CancelAll('ambiguous mouse movement',true)
            end
            return
        end
        -- Unmatched motion while synthetic acknowledgements remain is not a
        -- trustworthy delta. Observe it, but do not move the return point.
        for _,w in ipairs(self.Warps) do
            if not w.observed then self.ReconstructedScreen=copy(p);return end
        end
        self.PlayerScreen=copy(p);self.PlayerWorld=copy(env.world());self.Uncertain=false;self.UntrustedScreen=nil
        if guard then guard.previous=copy(p) end
    end
    function cursor:newAction(request)
        self.Serial=self.Serial+1
        local r={id=self.Serial,owner=request.owner or 'control',target=request.target,
            space=request.world and 'minimap' or request.target and (request.target.pos or request.target.z~=nil) and 'world' or 'screen',
            publicTarget=request.publicTarget,
            keys=request.keys or {},priority=request.priority or 0,
            requestedAt=env.clock(),expires=request.expires or env.clock()+250,
            validate=request.validate,verifyTarget=request.verifyTarget,aimCandidates=request.aimCandidates,aimFallback=request.aimFallback,leftClicks=request.leftClicks,
            dependency=request.dependency,world=copy(request.world or request.target and (request.target.pos or request.target.z~=nil and request.target)),critical=request.critical~=false,
            class=request.class or 'cast',state='requested',generation=self.Generation}
        r.targetID=r.target and r.target.pos and (r.target.networkID or r.target.handle)
        r.verifyID=r.verifyTarget and (r.verifyTarget.networkID or r.verifyTarget.handle)
        r.verifyKind=r.verifyTarget and (r.verifyTarget.networkID and "networkID" or "handle")
        if type(r.keys)~='table' then r.keys={r.keys} end
        local keys={};for i,v in ipairs(r.keys) do keys[i]=v end;r.keys=keys
        if r.target and not r.target.pos then r.target=copy(r.target) end
        if r.leftClicks and (not finite(r.leftClicks) or r.leftClicks<1 or r.leftClicks>2 or r.leftClicks%1~=0) then
            r.validate=function()return false end
        end
        self.Records[r.id]=r;self.Recent[#self.Recent+1]=r.id
        if #self.Recent>128 then self.Records[table.remove(self.Recent,1)]=nil end
        self:record('requested',r);return r
    end
    function cursor:valid(r,transportOnly)
        local why=r.state=='aborted' and (r.reason or 'cancelled') or self.Uncertain and 'input_uncertain'
            or r.generation~=self.Generation and 'interrupted' or env.clock()>r.expires and 'expired'
            or not self:Available() and 'context_blocked'
        if not why and r.validate and not transportOnly then
            local ok,valid,detail=pcall(r.validate,r,self.ResolutionSnapshot and self:ResolutionSnapshot(r))
            if not ok or not valid then why=ok and (detail or 'plugin_validation_declined') or 'validation_exception' end
        end
        if not why and r.target and r.target.pos then
            local t=r.target
            why=(not r.targetID or (t.networkID or t.handle)~=r.targetID) and 'target_identity_changed'
                or not t.valid and 'target_invalid' or t.dead and 'target_dead'
                or not t.visible and 'target_invisible' or not t.isTargetable and 'target_untargetable'
        end
        if why then r.reason=tostring(why);return false end
        return true
    end
    function cursor:Submit(request)
        if self.Resolving then return false end
        if type(request)~='table' or #self.Queue>=32 then return nil,'queue full or invalid request' end
        if request.priority~=nil and not finite(request.priority) or request.expires~=nil and not finite(request.expires) then
            return nil,'invalid priority or expiry'
        end
        local r=self:newAction(request)
        self.Queue[#self.Queue+1]=r
        table.sort(self.Queue,function(a,b) if a.priority==b.priority then return a.id<b.id end return a.priority>b.priority end)
        return r.id,'requested'
    end
    function cursor:GetAction(id)
        local r=self.Records[id];if not r then return end
        local out={};for _,k in ipairs({'id','owner','state','requestedAt','sentAt','observedAt','releasedAt','completedAt','abortedAt','observation','reason','interrupted','competitor','sendCompletedAt','holdUntil','budgetEnd','handoffStatus','predecessorID','interferenceID','interferenceAt','interferenceCause'}) do out[k]=r[k] end
        for _,k in ipairs({'playerScreen','playerWorld','actionScreen','screenAtSend','worldAtSend'}) do out[k]=copy(r[k]) end
        out.inputSession=self.SessionID
        return out
    end
    function cursor:GetState()
        local held={};for key in pairs(self.Physical) do held[#held+1]=key end
        local owned={};for key,owner in pairs(self.KeysOwned) do owned[tostring(key)]=owner end
        return {phase=self.Step,owner=self.Active and self.Active.owner,id=self.Active and self.Active.id,
            pendingButtons=self:GetPendingButtons(),
            pendingReturnID=self.PendingReturn and self.PendingReturn.id,
            pendingPlacement=self.Active and self.Active.awaitingPosition==true or false,
            uncertain=self.Uncertain==true,physical=held,owned=owned,
            playerScreen=copy(self.PlayerScreen),actionScreen=copy(self.ActionScreen),
            screen=copy(env.screen()),remainingMs=math.max(0,(self.Timer or 0)-env.clock()),
            mode=self.GGCompatible and 'GG-compatible phases' or 'experimental adaptive phases',session=self.SessionID}
    end
    function cursor:InputBudget(r)
        if r.sentAt then return true end
        if env.clock()+r.hold>r.budgetEnd then
            self.Timing:observePreparation(r,env.clock(),true)
            r.reason='Insufficient positioning budget for full hold';self:record('budget_rejected',r,r.reason);return false
        end
        return true
    end
    -- An observation is made after every warp and again immediately before input.
    function cursor:VerifyHover(r)
        local fn=Game.GetUnderMouseObject
        local ok,t=false,nil
        if type(fn)=='function' then ok,t=pcall(fn) end
        local returnedType=type(t);local returnedNil=ok and t==nil
        local object=returnedType=='table' or returnedType=='userdata'
        local observed=ok and object and t or nil
        local expected=r.verifyTarget
        local same=observed and expected and r.verifyID and observed[r.verifyKind]==r.verifyID
        if same and expected.networkID and t.networkID and expected.networkID~=t.networkID then same=false end
        if same and expected.handle and t.handle and expected.handle~=t.handle then same=false end
        local why=type(fn)~='function' and 'hover_api_missing' or not ok and 'hover_api_error'
            or not same and 'hover_identity_mismatch' or nil
        local aim=r.aim or {};r.aim=aim
        aim.at=env.clock();aim.api=type(fn)~='function' and 'missing' or ok and 'returned' or 'error'
        aim.returnType=returnedType;aim.returnedNil=returnedNil
        aim.expectedKind=r.verifyKind;aim.expectedID=r.verifyID
        aim.expectedNetworkID=expected and expected.networkID;aim.expectedHandle=expected and expected.handle
        aim.observedNetworkID=observed and observed.networkID;aim.observedHandle=observed and observed.handle
        aim.reason=why;aim.hoverConfirmed=same==true;aim.confirmed=same==true
        aim.screenError=screenDistance(env.screen(),r.actionScreen)
        aim.worldError=worldDistance(env.world(),r.world)
        if same then aim.source='native_hover';aim.confirmedAt=env.clock();aim.position=copy(r.actionScreen) end
        -- Optional client policy for a nil-only host result. A contradictory
        -- object, an API error, or a cursor outside the placement never qualifies.
        if not same and returnedNil and r.aimFallback and r.actionScreen and aim.screenError<=6 then
            local good,allowed=pcall(r.aimFallback,copy(r.actionScreen))
            if good and allowed==true then
                aim.source='client_projection';aim.confirmed=true;aim.confirmedAt=env.clock()
                aim.position=copy(r.actionScreen);aim.reason=nil;return true
            end
        end
        return same==true,why
    end
    function cursor:FailAim(r,why)
        r.aim=r.aim or {};r.aim.reason=why;r.aim.confirmed=false;r.aim.exhausted=true;r.aim.failedAt=env.clock();r.reason=why
        if r.onAimFailure then r.onAimFailure(r) end
        self:record('aim_failed',r,why,r.aim)
        self:release(why)
        -- No input was sent, so there is no stabilization to preserve. The
        -- confirmed return ends acquisition; the retry gate supplies fairness.
        if not r.sentAt and not self.PendingReturn then self.Step=0;self.NotBefore=env.clock();self.Timer=self.NotBefore end
        return false
    end
    function cursor:RefreshAimPoints(r)
        local ok,points=pcall(r.aimCandidates,r.target)
        if not ok or type(points)~='table' or #points==0 or #points>5 then r.reason='invalid_aim_candidates';return false end
        local fresh={};local bounds=env.resolution and env.resolution()
        for _,p in ipairs(points) do
            if not p or not finite(p.x) or not finite(p.y) or p.z~=nil
                or bounds and (p.x<0 or p.y<0 or p.x>=bounds.x or p.y>=bounds.y) then
                r.reason='invalid_aim_candidates';return false
            end
            fresh[#fresh+1]=copy(p)
        end
        r.aimPoints=fresh
        return true
    end
    function cursor:TryAim(r)
        if not self:valid(r) then self:release(r.reason);return false end
        local same,why=self:VerifyHover(r)
        if same and near(env.screen(),r.actionScreen) then return self:SendPositioned(r) end
        if why=='hover_api_missing' or why=='hover_api_error' then return self:FailAim(r,why) end
        if not near(env.screen(),r.actionScreen) then why='aim_position_mismatch' end
        if env.clock()+r.hold>=r.budgetEnd then return self:FailAim(r,'aim_budget_exhausted') end
        -- The target and camera may move between callbacks. Refresh geometry,
        -- retaining the candidate index and the original bounded cursor budget.
        if not self:RefreshAimPoints(r) then return self:FailAim(r,r.reason) end
        local nextIndex=(r.aimIndex or 1)+1
        local point=r.aimPoints and r.aimPoints[nextIndex]
        if not point then return self:FailAim(r,why or 'hover_identity_mismatch') end
        r.aimIndex=nextIndex;r.aim.candidate=nextIndex
        self.correctedCastPos=point;self.ActionScreen=copy(point);r.actionScreen=copy(point)
        local ok=self:SetPosition(point,'action',r)
        -- Do not reuse the previous hover result, even for synchronous hosts.
        local confirmed,reason=self:VerifyHover(r)
        if not ok or not near(env.screen(),point) then return self:FailAim(r,'aim_position_mismatch') end
        if confirmed then return self:SendPositioned(r) end
        r.awaitingPosition=true;r.sendAfter=env.clock();self.Timer=r.budgetEnd-r.hold
        self:record('aim_candidate',r,reason,r.aim);return true
    end
    function cursor:PrepareTargetFilter(r)
        if not r.target or not r.target.type or r.target.type==env.heroType or not env.tco then return true end
        local key=env.tco;local physical=self.Physical[canonicalKey[key] or key]
        if physical then r.reason='target_champions_only_held';return false end
        if self.KeysOwned[key]=='orbwalker' then self:ReleaseKey(key,'orbwalker') end
        if not safe(env.isDown,key) then self.TCORecovery=nil;return true end
        -- HK_TCO can remain latched across runtime reloads without an owner in
        -- this dispatcher. Recover only for an explicit non-champion target,
        -- never for an observed physical hold or another input owner's lease.
        if env.recoverLatchedTCO and not self.KeysOwned[key] then
            local now=env.clock();local recovery=self.TCORecovery
            if not recovery then recovery={attempts=0,nextAt=0};self.TCORecovery=recovery end
            if recovery.attempts<3 and now>=recovery.nextAt then
                recovery.attempts=recovery.attempts+1;recovery.nextAt=now+250
                local accepted=self:CallKey(key,false)
                local stillHeld=safe(env.isDown,key)==true
                self:record('target_filter_recovery',r,stillHeld and 'release awaiting native confirmation' or 'native filter released',
                    {targetFilterKey=key,releaseAccepted=accepted,stillHeld=stillHeld,attempt=recovery.attempts})
                if not stillHeld then self.TCORecovery=nil;return true end
            end
        end
        r.reason='target_champions_only_held';return false
    end
    function cursor:StepPressKey()
        local r=self.Active
        local validationStart=self.DiagnosticsEnabled~=false and env.clock()
        if not r then return false end
        if r.prevalidateWorldCast then
            if not self:WorldCommitValid(r) then return false end
        elseif not self:valid(r) then return false end
        local checkedScreen=env.screen()
        if r.prevalidateWorldCast and self.DiagnosticsEnabled~=false then r.screenAtSend=copy(checkedScreen) end
        if not near(checkedScreen,self.correctedCastPos) then
            r.reason='cursor_changed_before_send'
            if validationStart then
                self:record('position_unconfirmed',r,r.reason,{validationMs=env.clock()-validationStart,
                    checkedScreenX=checkedScreen and checkedScreen.x,checkedScreenY=checkedScreen and checkedScreen.y,
                    expectedScreenX=self.correctedCastPos and self.correctedCastPos.x,
                    expectedScreenY=self.correctedCastPos and self.correctedCastPos.y,
                    screenError=screenDistance(checkedScreen,self.correctedCastPos)})
            end
            return false
        end
        if r.verifyTarget then
            local confirmed,why=self:VerifyHover(r)
            if not confirmed then r.reason=why;return false end
            if not self:valid(r) then return false end
        end
        if not self:InputBudget(r) then return false end
        if not self:PrepareTargetFilter(r) then return false end
        local mouse=r.leftClicks or r.keys[1]==env.moveKey
        if mouse then
            local vk=r.leftClicks and 1 or 2
            if self.Buttons[vk] or self.Physical[vk] or safe(env.isDown,vk) then r.reason='mouse_button_held_before_send';return false end
            local down=r.leftClicks and 2 or 8;local up=r.leftClicks and 4 or 16
            for _=1,r.leftClicks or 1 do
                -- Once a host call may have sent input, cancellation cannot undo it.
                if not self:InputBudget(r) then return false end
                r.sentAt=r.sentAt or env.clock();r.state='sent'
                r.mouseButton=vk;self.Buttons[vk]={owner=r.owner,action=r,retries=0}
                local ok=self:CallMouse(down,vk,true,r)
                local released=self:ReleaseButton(vk,false)
                if not ok or not released then return false end
            end
        else
            for _,key in ipairs(r.keys) do
                if self.Physical[key] or safe(env.isDown,key) and self.KeysOwned[key]~=r.owner then r.reason='key_held_before_send';return false end
            end
            if not self:PulseKeys(r.keys,r.owner,r) then return false end
        end
        return true
    end
    function cursor:InputsBlocked(r)
        local keyBlocked=false
        if r.leftClicks or r.keys[1]==env.moveKey then
            local vk=r.leftClicks and 1 or 2;keyBlocked=self.Buttons[vk] or self.Physical[vk] or safe(env.isDown,vk)
        else
            for _,key in ipairs(r.keys) do
                if self.Physical[key] or safe(env.isDown,key) and self.KeysOwned[key]~=r.owner then keyBlocked=true;break end
            end
        end
        return keyBlocked
    end
    function cursor:dispatch(r,predecessor)
        if r.resolveWorldTarget and not self:ResolveWorld(r) then r.state="aborted";r.abortedAt=env.clock();return false end
        if not self:valid(r,r.prevalidateWorldCast) then r.state='aborted';r.reason=r.reason or 'validation or expiry';r.abortedAt=env.clock();self:record('aborted',r,r.reason);return false end
        -- Target-filter rejection must happen before any projection or warp.
        -- Rechecking at send time also covers a state change during placement.
        if not self:PrepareTargetFilter(r) then
            r.state='aborted';r.abortedAt=env.clock();self:record('aborted',r,r.reason);return false
        end
        if self:InputsBlocked(r) then
            r.state='aborted';r.abortedAt=env.clock();r.reason='Held input before cursor acquisition'
            self:record('aborted',r,r.reason);return false
        end
        if not r.target then
            local result=self:PulseKeys(r.keys,r.owner,r)
            if not r.sentAt then r.state='aborted';r.abortedAt=env.clock() end
            if r.sentAt and not result then r.submissionFailed=true end
            r.releasedAt=env.clock();self:record(r.sentAt and 'sent' or 'aborted',r)
            return result
        end
        if not r.rootAt then self:SamplePlayer() end
        if not self:valid(r,r.prevalidateWorldCast) then return false end
        local proxy=setmetatable({CastPos=r.target,IsTarget=r.target and r.target.pos~=nil},{__index=self})
        r.ggCompatible=self.GGCompatible
        r.hold=r.ggCompatible and env.fallback() or self.Timing:hold(r.class,r.critical)
        r.playerScreen=copy(r.returnTarget or self.PlayerScreen);r.playerWorld=copy(self.PlayerWorld)
        if r.space=='minimap' then r.critical=true;r.hold=env.fallback() end
        r.beforePath=copy(env.hero.pathing and env.hero.pathing.endPos);r.origin=copy(env.hero.pos)
        if r.target and self.ProjectCastPosition then
            local ok,p=pcall(self.ProjectCastPosition,proxy)
            local bounds=env.resolution and env.resolution()
            if not ok or not p or not finite(p.x) or not finite(p.y) or p.onScreen==false
                or bounds and (p.x<0 or p.y<0 or p.x>=bounds.x or p.y>=bounds.y) then
                r.state='aborted';r.abortedAt=env.clock();self:record('aborted',r,'Projection failed before cursor acquisition');return false
            end
            r.preparedPosition=p
        end
        if r.aimCandidates then
            if not self:RefreshAimPoints(r) then return false end
            r.preparedPosition=r.aimPoints[1];r.aimIndex=1;r.aim={candidate=1}
        end
        r.preparedAt=env.clock()
        if not r.rootAt then
            self:SamplePlayer();self.CursorPos=copy(self.PlayerScreen)
            r.playerScreen=copy(r.returnTarget or self.PlayerScreen);r.playerWorld=copy(self.PlayerWorld)
        end
        if not self:valid(r) or self:InputsBlocked(r) then r.state='aborted';r.abortedAt=env.clock();return false end
        if r.prevalidateWorldCast then
            self:PrepareWorldCommit(r)
            -- The final validator can take time; project the validated world
            -- intent again before the warp, never run it after positioning.
            local ok,p=pcall(self.ProjectCastPosition,proxy)
            if not ok or not p or not finite(p.x) or not finite(p.y) or p.onScreen==false then
                r.state='aborted';r.reason='world_projection_failed';return false
            end
            r.preparedPosition=p
        end
        if predecessor and self.Active~=predecessor then return false end
        r.rootAt=r.rootAt or env.clock()
        r.preparationBudget=r.resolveWorldTarget and self.Timing:preparationBudget(r.hold) or math.max(120,env.fallback()*2)
        r.budgetEnd=r.budgetEnd or math.min(r.rootAt+r.preparationBudget,r.expires+r.hold)
        if predecessor and predecessor.holdUntil and env.clock()<predecessor.holdUntil then
            predecessor.followup=r;r.handoffStatus='waiting for predecessor hold';self:record('handoff_wait',r);return true
        end
        if predecessor then
            predecessor.followup=nil;predecessor.releasedAt=env.clock();predecessor.handoffStatus='transferred'
            self:record('dependent_handoff',predecessor);r.handoffStatus='acquired'
        end
        self.CursorPos=copy(r.returnTarget or self.PlayerScreen);self.CastPos=r.target;self.Keys=r.keys
        self.IsTarget=r.target and r.target.pos~=nil;self.IsMouseClick=r.keys[1]==env.moveKey
        self.Active=r;r.acquiredAt=env.clock();self.RecoveryUsed=false;self.Step=1
        self.ForceTCOUp=r.target and r.target.type and r.target.type~=env.heroType or false
        if not r.target then
            local ok=self:PulseKeys(r.keys,r.owner,r)
            self:release(ok and 'key only' or 'key rejected');return ok
        end
        r.warpStartedAt=env.clock()
        local ok,err
        if r.preparedPosition then
            self.correctedCastPos=r.preparedPosition;ok,err=pcall(self.SetPosition,self,r.preparedPosition,'action')
        else ok,err=pcall(project,self) end
        if r.publicTarget then self.CastPos=r.publicTarget end
        self.ActionScreen=copy(self.correctedCastPos)
        r.actionScreen=copy(self.ActionScreen)
        if not ok or not self.PlacementAccepted or not near(env.screen(),self.ActionScreen) then
            if r.aimCandidates then return self:FailAim(r,'aim_position_mismatch') end
            self:release('position unconfirmed');return false
        end
        if r.ggCompatible and not r.resolveWorldTarget then
            -- v27 checked placement before GG's own positioning call. Keep both
            -- calls inside this owner so the original player position survives.
            -- Resolved world casts already use a freshly projected, confirmed
            -- position above. Repeating the native warp adds no evidence.
            if not self:SetPosition(self.ActionScreen,'action') or not near(env.screen(),self.ActionScreen) then
                if r.onAimFailure then return self:FailAim(r,'aim_position_mismatch') end
                self:release('GG-compatible positioning declined');return false
            end
        end
        if env.deferMoves and not r.ggCompatible and r.class=='move' then
            r.deferredMove=true;r.awaitingPosition=true;r.sendAfter=env.clock()+env.fallback()
            self.Timer=r.budgetEnd-r.hold
            self:record('position_requested',r);return true
        end
        if r.aimCandidates then return self:TryAim(r) end
        if r.verifyTarget then
            if not self:VerifyHover(r) then
                r.awaitingPosition=true;r.sendAfter=env.clock();self.Timer=r.budgetEnd-r.hold
                self:record('hover_wait',r);return true
            end
        end
        if r.resolveWorldTarget then
            r.positionPasses=1;r.confirmAfterPass=self.ResolutionPass
            r.awaitingPosition=true;r.sendAfter=env.clock();self.Timer=r.budgetEnd-r.hold
            if self:WorldPlacementConfirmed(r) then return self:SendPositioned(r,true) end
            return true
        end
        return self:SendPositioned(r)
    end
    function cursor:SendPositioned(r,placementFresh)
        -- PollPlacement already resolved, validated and projected this action in
        -- this call. Repeating that work lengthens the cursor lease and creates
        -- more opportunity for camera/mouse drift. StepPressKey still performs
        -- the final gameplay and cursor checks immediately before sending.
        if r.resolveWorldTarget and not placementFresh and not self:RefreshWorldPlacement(r) then return self.Active==r end
        r.awaitingPosition=nil;r.positionedAt=env.clock()
        if self.DiagnosticsEnabled~=false and not r.prevalidateWorldCast then r.screenAtSend=copy(env.screen());r.worldAtSend=copy(env.world()) end
        local pressed,result=pcall(self.StepPressKey,self)
        if self.Active~=r then return false end
        if r.sentAt then
            r.holdUntil=(r.sendCompletedAt or env.clock())+r.hold
            self.Timing:observePreparation(r,r.sentAt,false)
        end
        if not pressed or not result then
            if not r.sentAt then
                if r.reason=='cursor_changed_before_send' and r.resolveWorldTarget then
                    -- Pointer motion can occur inside the final gameplay
                    -- validator. Give opted-in world intents the same bounded
                    -- correction as motion sampled between callbacks. No new
                    -- action, deadline, hold reduction or keypress is created.
                    r.awaitingPosition=true
                    if self:CanCorrectWorldDrift(r,env.screen()) then
                        r.pointerCorrectionPending=true;r.reason=nil
                        r.sendAfter=env.clock();self.Timer=r.budgetEnd-r.hold
                        self:record('world_pointer_correction_pending',r,'Final validation drift; reconfirm within original budget')
                        -- Correct within this dispatch rather than yielding into
                        -- another physical-motion callback. Refresh keeps the
                        -- same resolver revision in this scheduler pass, checks
                        -- gameplay again, and counts every positioning attempt.
                        -- A second final validation still runs after the warp.
                        if self:RefreshWorldPlacement(r) then return self:SendPositioned(r,true) end
                        return self.Active==r
                    end
                    r.awaitingPosition=nil
                end
                if (r.aimCandidates or r.onAimFailure) and r.reason then
                    if r.reason:find('hover_',1,true) then return self:FailAim(r,r.reason) end
                    if r.reason=='Insufficient positioning budget for full hold' then return self:FailAim(r,'aim_budget_exhausted') end
                end
                self:release(r.reason or 'input rejected or uncertain')
            else r.submissionFailed=true;self.Timer=r.holdUntil;self:record('submission_uncertain',r,tostring(result)) end
            return false
        end
        self.Timer=r.holdUntil or env.clock()+r.hold
        self:record(r.sentAt and 'sent' or 'cursor_aimed',r)
        return true
    end
    function cursor:PollPlacement(r)
        if r.resolveWorldTarget and not self:RefreshWorldPlacement(r) then return end
        if r.aimCandidates then return self:TryAim(r) end
        if not r.resolveWorldTarget and not self:valid(r) then self:release('placement cancelled or expired');return end
        local now=env.clock()
        local screenOK=near(env.screen(),r.actionScreen)
        -- Prefer fresh host evidence when available; a stale global mousePos
        -- must not override a confirmed placement (nor override its rejection).
        local worldOK=true
        if r.space=='world' then
            if r.resolveWorldTarget and type(env.liveWorld)=='function' then worldOK=self:WorldPlacementConfirmed(r)
            else worldOK=worldDistance(env.world(),r.world)<=75 end
        end
        if r.verifyTarget then
            worldOK=self:VerifyHover(r)
        end
        if screenOK and worldOK and now>=r.sendAfter then
            self:SendPositioned(r,true)
        elseif now>=self.Timer then
            if r.onAimFailure then return self:FailAim(r,'aim_budget_exhausted') end
            self:record('position_unconfirmed',r,'cursor/world target did not settle; no click sent')
            self:release('position unconfirmed; no click sent')
        end
    end
    function cursor:Add(key,target)
        if self.Resolving then return false end
        local intent=self.NextIntent or {}
        local compatible=false
        if self.Active then
            compatible=#self.Active.keys==0 and not self.Active.leftClicks and (type(key)~='table' or #key>0)
            -- Compatibility callers must explicitly identify and validate a dependency.
            if key~=env.moveKey and intent.dependency==self.Active.id and type(intent.validate)=='function' then compatible=true end
        end
        local predecessor=self.Active
        local chain=predecessor and intent.dependency==predecessor.id and intent.owner==predecessor.owner
            and type(intent.validate)=='function' and compatible and (predecessor.chainDepth or 0)<1 and not predecessor.followup
        if (self.Step>0 or self.Active) and not chain or not chain and env.clock()<self.NotBefore then return false end
        local rootAt,chainDepth
        if chain then rootAt=predecessor.rootAt;chainDepth=(predecessor.chainDepth or 0)+1 end
        local ordinary=key==env.moveKey and not intent.critical
        local request={owner=intent.owner or (ordinary and 'orbwalker' or 'control'),keys=key,target=target,publicTarget=target,
            validate=intent.validate,verifyTarget=intent.verifyTarget,leftClicks=intent.leftClicks,
            critical=not ordinary,class=ordinary and 'move' or 'cast',world=intent.world,
            expires=intent.expires,priority=intent.priority}
        local r=self:newAction(request);r.rootAt=rootAt;r.chainDepth=chainDepth or 0
        if chain then
            r.returnTarget=copy(predecessor.returnTarget or predecessor.playerScreen);r.budgetEnd=predecessor.budgetEnd
            r.predecessorID=predecessor.id;r.handoffStatus='preparing'
        end
        local ok,result=pcall(self.dispatch,self,r,chain and predecessor or nil)
        if not ok or not result then
            r.state=r.sentAt and r.state or 'aborted';r.abortedAt=not r.sentAt and env.clock() or nil
            r.reason=r.reason or (not ok and tostring(result) or 'handoff or dispatch preparation rejected')
            self:record('aborted',r,r.reason)
            if self.Active==r and not ok then self:release('dispatch exception')
            elseif chain and self.Active==predecessor then
                predecessor.followup=nil;predecessor.handoffStatus='preparation rejected'
                if not predecessor.holdUntil or env.clock()>=predecessor.holdUntil then self:release('handoff preparation rejected') end
            end
        end
        self.LastActionID=r.id
        return ok and result==true
    end
    function cursor:DispatchRecord(r,key,target)
        if self.Step>0 or self.Active or env.clock()<self.NotBefore then return false end
        r.keys={key};r.target=target;r.targetID=target and (target.networkID or target.handle)
        return self:dispatch(r)
    end
    function cursor:release(reason)
        local r=self.Active;if not r then return end
        if r.followup then
            r.followup.state='aborted';r.followup.reason=reason;r.followup.abortedAt=env.clock()
            self:record('aborted',r.followup,reason);r.followup=nil
        end
        self.Active=nil;self.ActionScreen=nil
        self:CleanupButtons(false,r.owner)
        r.reason=reason
        if not r.sentAt then r.state='aborted';r.abortedAt=env.clock() end
        for key,owner in pairs(self.KeysOwned) do if owner==r.owner then self:ReleaseKey(key,owner) end end
        r.returnRequestedAt=env.clock()
        r.returnTarget=copy(r.returnTarget or self.PlayerScreen);r.returnBefore=copy(env.screen());r.returnGeneration=self.Generation
        self.LastReturnAt=r.returnRequestedAt
        r.returnAccepted=self:SetPosition(r.returnTarget,'return',r);r.returnSample=copy(env.screen())
        r.releasedAt=env.clock()
        if near(r.returnSample,r.returnTarget) then r.returnObservedAt=env.clock()
        else
            self.PendingReturn=r;self.Uncertain=true
            if not near(r.returnBefore,r.returnTarget) then self.UntrustedScreen=copy(r.returnBefore) end
        end
        if r.actionScreen and screenDistance(r.actionScreen,r.returnTarget)>256 then
            self.ReturnGuard={at=env.clock(),generation=self.Generation,action=copy(r.actionScreen),
                actionRecord=r,previous=copy(r.returnTarget),
                -- Mouse motion can displace a delayed warp after the return was
                -- sampled. Exact-pixel/24px matching promoted that displaced
                -- cast cursor into player aim (live Q -> move at 29:46).
                -- This guard only acts on a >256px discontinuity within 250ms;
                -- smooth intentional traversal and new physical commands win.
                radius=128}
        end
        self.Step=3;self.ForceTCOUp=false
        -- Keep second wait as player-owned time until comparison tests validate removal.
        self.NotBefore=env.clock()+(self.Timing.removeSecondWait and math.max(1,self.Timing:reserve()) or env.fallback())
        self.Timer=self.NotBefore;self:record('released',r,reason)
    end
    function cursor:Cancel(owner,reason)
        self:CleanupButtons(false,owner)
        for i=#self.Queue,1,-1 do
            local r=self.Queue[i]
            if not owner or r.owner==owner then
                table.remove(self.Queue,i);r.state='aborted';r.reason=reason;r.abortedAt=env.clock();self:record('aborted',r,reason)
            end
        end
        if self.Active and (not owner or self.Active.owner==owner) then
            self.Active.interrupted=true;self:release(reason or 'cancelled')
        end
        -- An explicit cancellation gets one last owned release even if automatic
        -- retries exhausted; it must still be possible to recover after host input
        -- becomes available again. Regular Prepare/OnTick calls stay bounded.
        for key,who in pairs(self.KeysOwned) do if not owner or who==owner then self:ReleaseKey(key,who,nil,nil,true) end end
    end
    function cursor:CancelAll(reason,pointerOnly,movementOnly)
        local previousGeneration=self.Generation;local active=self.Active
        local resume=active and not active.sentAt and active.publicScope
            and (pointerOnly and active.survivePointerMotion or movementOnly and active.surviveMovementCommands)
            and active.generation==previousGeneration
        self.Generation=self.Generation+1;self.Metrics.interruptions=self.Metrics.interruptions+1
        if env.cancelPending then env.cancelPending() end
        if self.Active and (reason=='manual input or unassignable delayed echo' or reason=='ambiguous mouse movement') then
            self.Active.manualAt=env.clock()
        end
        for _,id in ipairs(self.Recent) do
            local r=self.Records[id];if r and r.sentAt and not r.observedAt and not r.timedOut then r.interrupted=true end
        end
        self:Cancel(nil,reason)
        if resume and self.Automation then self.Automation:ResumeUnsentMotion(active) end
        if pointerOnly or movementOnly then
            -- Opted-in, independent public casts have not acquired the cursor
            -- yet. Aiming motion or an explicitly permitted movement command
            -- may release the previous action without destroying these intentions.
            -- They still wait for a trusted
            -- cursor and pass full gameplay validation before a new acquisition.
            for _,id in ipairs(self.Recent) do
                local r=self.Records[id]
                if r and r~=active and (pointerOnly and r.survivePointerMotion or movementOnly and r.surviveMovementCommands)
                    and r.publicScope and not r.sentAt
                    and r.state~='aborted' and r.generation==previousGeneration then
                    r.generation=self.Generation;self:record('waiting_preserved',r,
                        movementOnly and 'movement command; revalidation required' or 'pointer motion; revalidation required')
                end
            end
        end
        self:record('cancel_all',nil,reason)
    end
    function cursor:Shutdown() self:CancelAll('reload or shutdown');self.Stopped=true end
    function cursor:RegisterObservationSource(name,validated)
        self.Sources[name]=validated==true
        if name=='movement' then self.Timing.validatedMoves=validated==true end
    end
    function cursor:ObserveMovement(r)
        local endpoint=env.hero.pathing and env.hero.pathing.endPos
        local function dist2(a,b)
            if not a or not b or not finite(a.z) or not finite(b.z) then return math.huge end
            return (a.x-b.x)^2+(a.z-b.z)^2
        end
        if r.class~='move' or r.pathObserved or not endpoint or not r.beforePath or not r.world
            or not r.origin or not finite(r.world.z) or not finite(r.origin.z)
            or dist2(endpoint,r.beforePath)<=25 then return end
        if env.strictMovement then
            if env.hero.pathing.isDashing or r.competitor or r.interrupted then return end
            if not r.endpointCandidate or worldDistance(r.endpointCandidate,endpoint)>5 then
                r.endpointCandidate=copy(endpoint);r.endpointCandidateAt=env.clock();return
            end
            if env.clock()<=r.endpointCandidateAt then return end
        end
        r.pathObserved=true;r.observedEndpoint=copy(endpoint);r.pathObservedAt=env.clock()
        r.expectedError=worldDistance(endpoint,r.world);r.playerError=worldDistance(endpoint,r.playerWorld)
        local result=dist2(endpoint,r.world)<=2500 and 'confirmed' or 'misdirected'
        -- Terrain clamping and other endpoint changes are not proven misdirection.
        if env.strictMovement and result=='misdirected' and not (r.playerError<=75 and r.expectedError>250) then result='unknown' end
        r.pathResult=result
        local dx=r.world.x-r.origin.x;local dz=r.world.z-r.origin.z
        local direction=math.floor(((math.atan2(dz,dx)+math.pi)/(2*math.pi))*8)%8
        if not self:Observe(r.id,{actionID=r.id,source='movement',result=result,
            unique=not r.competitor and not r.interrupted,direction=direction}) then
            self:record('movement_candidate',r,'unvalidated or ambiguous path observation: '..result)
        end
    end
    function cursor:Observe(id,evidence)
        local r=self.Records[id]
        if not r or not r.sentAt or r.observedAt or not evidence or evidence.actionID~=id then return false end
        local proven=self.Sources[evidence.source] and evidence.unique==true and not r.interrupted and not r.competitor
        if not proven or evidence.result=='unknown' then return false end
        r.observedAt=env.clock();r.observation=evidence.result;r.state='observed'
        evidence.sourceValidated=true
        self.Timing:observe(r,evidence);self:record('observed',r)
        if evidence.result=='confirmed' then r.state='completed';r.completedAt=env.clock()
        elseif evidence.result=='misdirected' then
            self.Metrics.misdirected=self.Metrics.misdirected+1;self:CancelAll('confirmed misdirection')
        end
        self:record(r.state,r);return true
    end
    function cursor:OnInput(msg,param)
        self.LastInputSynthetic=(self.InFlight or 0)>0
        local keyDown=msg==256 or msg==260
        local keyUp=msg==257 or msg==261
        local mouseDown=msg==513 or msg==516 or msg==519 or msg==523
        local mouseUp=msg==514 or msg==517 or msg==520 or msg==524
        if keyDown or keyUp or mouseDown or mouseUp then
            self.LastInputEdge={message=msg,param=param,at=env.clock(),classification=self.LastInputSynthetic and 'host call' or 'unmatched'}
        end
        if (keyDown or keyUp) and self:MatchKeyEcho(param,keyDown) then
            self.LastInputEdge.classification='expected key echo'
            if not self.LastInputSynthetic then self:record('key_echo_inferred',nil,tostring(param)) end
            self.LastInputSynthetic=true;return
        end
        local mouseVK=(msg==513 or msg==514) and 1 or (msg==516 or msg==517) and 2 or 4
        if (mouseDown or mouseUp) and self:MatchKeyEcho(mouseVK,mouseDown,true) then
            self.LastInputEdge.classification='expected mouse echo'
            if not self.LastInputSynthetic then self:record('mouse_echo_inferred',self.Active,tostring(msg)) end
            self.LastInputSynthetic=true;return
        end
        if self.LastInputSynthetic then return end
        if msg==512 then self:SamplePlayer();return end
        local down=msg==256 or msg==260
        local up=msg==257 or msg==261
        local freshPress=false
        if down or up then
            local key=canonicalKey[param] or param
            if self.PhysicalReview and self.PhysicalReview[key]~=nil then self.PhysicalReview[key]=false end
            if down then self:AdvanceCommand(key) end
            freshPress=down and not self.Physical[key]
            self.Physical[key]=down or nil
            if down then
                self.PhysicalReview=self.PhysicalReview or {};self.PhysicalReview[key]=false
            end
            if key==(canonicalKey[env.tco] or env.tco) then self.TCORecovery=nil end
        elseif mouseDown or mouseUp then
            local vk=(msg==513 or msg==514) and 1 or (msg==516 or msg==517) and 2 or 4
            freshPress=mouseDown and not self.Physical[vk]
            self.Physical[vk]=mouseDown or nil
            if self.Buttons[vk] then
                if mouseDown then self.Buttons[vk].manual=true;self:record('button_physical_takeover',self.Buttons[vk].action,tostring(vk))
                elseif mouseUp then self.Buttons[vk].manual=nil end
            end
        end
        if freshPress then
            if down and safe(env.focus) and (param==13 or param==27) then
                self.ChatLatched=param==13 and not self:IsChatOpen() or false
                self:record('chat_guard',nil,self.ChatLatched and 'physical Enter opened editor' or 'physical editor dismissal',
                    {chatLatched=self.ChatLatched,nativeChat=env.chat and safe(env.chat)==true or false})
            end
            self.LastInputEdge.classification='new manual press or unmatched echo'
            for _,id in ipairs(self.Recent) do local r=self.Records[id];if r and r.sentAt and not r.observedAt then r.interrupted=true end end
            self:CancelAll('manual input or unassignable delayed echo',false,msg==516)
        elseif up or mouseUp then
            -- A toggle's release and duplicate host releases are not new commands.
            -- LHO still receives the event to finish its release-triggered assists.
            self.LastInputEdge.classification='release; no new command'
            self:record('input_release',self.Active)
        end
    end
    function cursor:StepSetToCursorPos() self:release('compatibility release') end
    function cursor:StepWaitForResponse()
        if self.Active and self.Active.ggCompatible then
            if env.clock()>self.Timer then self.Step=2;self:record('hold_finished',self.Active) end
        elseif env.clock()>=self.Timer then self:release('hold deadline; result unknown') end
    end
    function cursor:StepWaitForReady() if env.clock()>=self.NotBefore then self.Step=0 end end
    function cursor:OnTick()
        self.TickSerial=self.TickSerial+1;self:CleanupButtons(true)
        local now=env.clock()
        self.Timing:tick(now)
        self:PruneKeyEchoes()
        for key,pending in pairs(self.PendingUp) do
            if not safe(env.isDown,key) then
                self.PendingUp[key]=nil
                if self.KeyLeases and self.KeyLeases[key]==pending.lease then
                    self.KeysOwned[key]=nil;self.KeyLeases[key]=nil
                end
            elseif pending.attempts<3 then
                self:ReleaseKey(key,pending.owner,nil,pending.lease)
            end
        end
        if not self:Available() then
            if not self.Suspended then self:CancelAll('focus, chat, death or disabled') end
            self.PhysicalReview={};self.PhysicalPollAt=nil
            for key in pairs(self.Physical) do self.PhysicalReview[key]=false end
            self.Suspended=true;return
        end
        self.Suspended=false;self:ReconcilePhysical();self:SamplePlayer()
        if self.Active and self.Active.followup and not self.Active.followup.publicScope and env.clock()>=(self.Active.holdUntil or 0) then
            local previous=self.Active;local nextAction=previous.followup;previous.followup=nil
            local ok,accepted=pcall(self.dispatch,self,nextAction,previous)
            if not ok or not accepted then
                nextAction.state=nextAction.sentAt and nextAction.state or 'aborted';nextAction.reason='deferred handoff rejected'
                self:record('aborted',nextAction,nextAction.reason)
                if self.Active==previous or self.Active==nextAction and not nextAction.sentAt then self:release(nextAction.reason) end
            end
        end
        if self.Active and self.Active.awaitingPosition and not self.Active.publicScope then self:PollPlacement(self.Active) end
        if self.Active and not self.Active.awaitingPosition and not (self.Active.followup and self.Active.followup.publicScope) then
            if self.Active.ggCompatible then
                -- GG observes the wait deadline in Step 1 and restores on the
                -- following Tick in Step 2. Never collapse these into one call.
                if self.Step==2 then self:release('GG response phase complete; see separate observation')
                elseif now>self.Timer then self.Step=2;self:record('hold_finished',self.Active) end
            elseif now>=self.Timer then self:release('hold deadline; see separate observation') end
        end
        if self.Step==3 and now>=self.NotBefore then self.Step=0 end
        for _,id in ipairs(self.Recent) do
            local r=self.Records[id]
            if r and r.sentAt and not r.observedAt and not r.timedOut then self:ObserveMovement(r) end
            if r and r.sentAt and not r.observedAt and not r.timedOut and now-r.sentAt>750 then
                r.timedOut=true;r.observation='unknown';self.Metrics.unknown=self.Metrics.unknown+1
                self.Timing:observe(r,nil);self:record('unknown',r)
            end
        end
        if self.Step==0 and not self.Active and now>=self.NotBefore then
            if #self.Queue>0 then self:dispatch(table.remove(self.Queue,1)) else self:StepReady() end
        end
    end
    if env.strictMovement then cursor:RegisterObservationSource('movement',true) end
    return cursor
end

end)()
    Cursor = create(Cursor, {
        clock=GetTickCount, screen=Game.cursorPos,
        world=function()
            if type(Game.mousePos)=='function' then
                local ok,p=pcall(Game.mousePos)
                if ok and p and type(p.x)=='number' and type(p.z)=='number' then return p end
            end
            return mousePos
        end,
        liveWorld=Game.mousePos,
        set=Control.SetCursorPos, down=Control.KeyDown, up=Control.KeyUp,
        isDown=Control.IsKeyDown, mouse=Control.mouse_event,
        focus=Game.IsOnTop, chat=Game.IsChatOpen, resolution=Game.Resolution,
        fallback=function()return MenuDelay:Value() end,
        tco=HK_TCO, heroType=Obj_AI_Hero, moveKey=MOUSEEVENTF_RIGHTDOWN, recoverLatchedTCO=true,
        executeAttack=function(record)return Orbwalker:Attack(record.target,record)end,
        executeApproach=(function()
-- Explicit target-attack order used to approach during attack cooldown.
-- It does not claim an attack started: only native attack evidence may do that.
return function(env)
    return function(record)
        local orb=env.orb();local target=record.target
        if not orb:IsEnabled() or not orb.AttackEnabled or not orb.MovementEnabled
            or not orb.Menu.AttackEnabled:Value() or not orb.Menu.MovementEnabled:Value()
            or env.isDown(17) or env.isDown(18) or not orb.CanAttackC()
            or not env.canAttack() or not orb:CanMove() or orb:IsAutoAttacking() then record.reason='approach_attack_or_movement_gate';return false end
        if not target or not target.valid or not target.visible or target.dead or target.health<=0
            or not target.pos or not target.pos:To2D().onScreen or not env.targetable(target) then record.reason='approach_target_unavailable';return false end
        local args={Target=target,Process=true,Approach=true}
        for _,fn in ipairs(orb.OnPreAttackCb) do fn(args) end
        -- An approach contract belongs to this exact object. A retargeting hook
        -- must submit a fresh intent instead of silently chasing another unit.
        if not args.Process or args.Target~=target then record.reason='approach_pre_attack_hook';return false end
        if not env.send(target,record) then return false end
        orb.LastTarget=target
        return true
    end
end

end)(){orb=function()return Orbwalker end,isDown=Control.IsKeyDown,
            canAttack=function()return Data:HeroCanAttack()end,
            targetable=function(unit)return ChampionInfo:CustomIsTargetable(unit)end,
            send=function(unit,record)return Control.Attack(unit,record)end},
        hero=myHero, attackKey=function()return Menu.Main.AttackTKey:Key() end,
        enabled=function()return Orbwalker: IsEnabled() end,
        timing=timing,deferMoves=true,strictMovement=true,ggCompatible=true,
        cancelPending=function()FlashHelper.Flash=nil;EvadeSupport=nil end,
    })
    local installWorld=(function()
-- Optional world intent resolution. No new deadline or input owner is created.
return function(input, clock)
    local function finite(n) return type(n)=='number' and n==n and math.abs(n)<math.huge end
    local function copy(v, seen, depth)
        if type(v)~='table' then return v end
        seen=seen or {};depth=depth or 0
        if seen[v] or depth>12 then error('cyclic or excessive resolution data') end
        seen[v]=true;local out={}
        for k,x in pairs(v) do
            if type(k)=='string' or type(k)=='number' then
                if type(x)~='function' and type(x)~='userdata' then out[k]=copy(x,seen,depth+1) end
            end
        end
        seen[v]=nil;return out
    end
    function input:ResolutionSnapshot(r) return r.resolution and copy(r.resolution) end
    function input:WorldPlacementConfirmed(r)
        -- GG's cast contract confirms the projected SCREEN coordinate, then
        -- sends in that same call. Game.mousePos can lag the OS cursor. Waiting
        -- for that separate world sample added a callback before every skillshot
        -- and let physical aiming/camera motion repeatedly cancel the cast.
        -- Gameplay validation and the final <=5px screen check still run at send.
        if r.ggCompatible then
            local p=self.env.screen();local aim=r.actionScreen
            local yes=p and aim and finite(p.x) and finite(p.y)
                and (p.x-aim.x)^2+(p.y-aim.y)^2<=25
            if yes then r.screenPlacementConfirmedAt=clock() end
            return yes or false
        end
        -- Only a fresh host world query can eliminate the extra callback. A
        -- cached global mousePos (or screen position alone) is insufficient.
        if type(self.env.liveWorld)~='function' then return false end
        local screen=self.env.screen();local ok,world=pcall(self.env.liveWorld)
        local aim=r.actionScreen;local target=r.world
        if not ok or not world or not target or not screen or not aim then return false end
        if not finite(world.x) or not finite(world.z) or not finite(screen.x) or not finite(screen.y) then return false end
        local confirmed=(screen.x-aim.x)^2+(screen.y-aim.y)^2<=25
            and (world.x-target.x)^2+(world.z-target.z)^2<=75^2
        if confirmed then r.nativePlacementConfirmedAt=clock() end
        return confirmed
    end
    function input:CanCorrectWorldDrift(r,screen)
        -- Small physical motion during a held assist is not cancellation. Keep
        -- the same bounded lease, but never send at the displaced position.
        -- Large movements, clicks and legacy actions retain manual takeover.
        if not r or r.sentAt or not r.survivePointerMotion or not r.resolveWorldTarget
            or not r.awaitingPosition or not self:Available() or self.Uncertain
            or (r.positionPasses or 1)>=3 or clock()+r.hold>=r.budgetEnd
            or clock()>r.expires or r.generation~=self.Generation then return false end
        local aim=r.actionScreen
        if not aim or not screen or not finite(screen.x) or not finite(screen.y)
            or (screen.x-aim.x)^2+(screen.y-aim.y)^2>32^2 then return false end
        -- GG-compatible casts use confirmed screen projection throughout. A
        -- stale asynchronous world sample must not veto a bounded correction of
        -- that same screen contract; strict world mode keeps its native check.
        if r.ggCompatible then return true end
        if type(self.env.liveWorld)~='function' then return false end
        local ok,world=pcall(self.env.liveWorld)
        return ok and world and r.world and finite(world.x) and finite(world.z)
            and (world.x-r.world.x)^2+(world.z-r.world.z)^2<=75^2 or false
    end
    function input:ResolveWorld(r)
        if not r.resolveWorldTarget then return true end
        if r.state=='aborted' or clock()>r.expires or r.generation~=self.Generation or not self:Available() then r.reason='resolution_context_ended';return false end
        if r.resolvedPass==self.ResolutionPass then return r.resolution~=nil and not r.resolutionError end
        r.resolvedPass=self.ResolutionPass;r.resolutionError=nil
        local context={id=r.id,owner=r.owner,requestedAt=r.requestedAt,expires=r.expires,
            targetID=r.intentTargetID,keys=copy(r.keys),position=copy(r.target),
            revision=r.resolution and r.resolution.revision or 0,now=clock()}
        local revision=context.revision+1
        self.Resolving=true
        local ok,value,detail=pcall(r.resolveWorldTarget,context)
        self.Resolving=false
        if ok and value then
            local p=value.position or value
            if finite(p.x) and finite(p.z) and (p.y==nil or finite(p.y)) and not p.pos then
                local copied,data=pcall(copy,value.data)
                if copied then
                    r.resolution={revision=revision,position={x=p.x,y=p.y or 0,z=p.z},data=data,at=clock()}
                    r.target=copy(r.resolution.position);r.world=copy(r.target);return true
                end
            end
        end
        r.resolutionError=true;r.reason=ok and tostring(detail or 'world_resolution_declined') or 'world_resolution_exception'
        return false
    end
    -- A bounded, one-use certificate for this synchronous placement attempt.
    -- It certifies pre-warp gameplay validation, never observed execution.
    function input:PrepareWorldCommit(r)
        r.worldCommit={at=clock(),pass=self.ResolutionPass,revision=r.resolution and r.resolution.revision}
        r.gameplayValidatedAt=clock()
    end
    function input:WorldCommitValid(r)
        local ticket=r.worldCommit;r.worldCommit=nil
        if self.Active~=r or not self:valid(r,true) then return false end
        local function fresh()
            return ticket and ticket.pass==self.ResolutionPass and r.resolution
                and ticket.revision==r.resolution.revision and clock()-ticket.at>=0 and clock()-ticket.at<=20
        end
        if not fresh() then r.reason='world_commit_expired';return false end
        if r.commitGuard then
            local ok,allowed,reason=pcall(r.commitGuard)
            if not ok or not allowed then r.reason=ok and (reason or 'commit_guard_declined') or 'commit_guard_exception';return false end
        end
        -- A guard/host call can synchronously cancel or stall; no gameplay
        -- callback or resolver is allowed to extend the certificate.
        if self.Active~=r or not self:valid(r,true) then return false end
        if not fresh() then r.reason='world_commit_expired';return false end
        r.commitValidatedAt=clock();r.commitCertificate=ticket;return true
    end
    function input:RefreshWorldPlacement(r)
        if not r.resolveWorldTarget then return true end
        if not self:ResolveWorld(r) or not self:valid(r) then self:release(r.reason or 'world_resolution_declined');return false end
        if r.prevalidateWorldCast then self:PrepareWorldCommit(r) end
        if clock()>r.expires then self:release('expired');return false end
        if clock()>=r.budgetEnd-r.hold then
            self.Timing:observePreparation(r,clock(),true)
            self:release('world_position_budget_exhausted');return false
        end
        local proxy=setmetatable({CastPos=r.target,IsTarget=false},{__index=self})
        local ok,p=pcall(self.ProjectCastPosition,proxy)
        local bounds=self.env.resolution and self.env.resolution()
        if not ok or not p or not finite(p.x) or not finite(p.y) or p.onScreen==false
            or bounds and (p.x<0 or p.y<0 or p.x>=bounds.x or p.y>=bounds.y) then
            self:release('world_projection_failed');return false
        end
        local old=r.actionScreen
        local changed=r.pointerCorrectionPending or not old or (old.x-p.x)^2+(old.y-p.y)^2>25
        if changed then
            if (r.positionPasses or 1)>=3 then self:release('world_position_limit');return false end
            r.positionPasses=(r.positionPasses or 1)+1
            r.pointerCorrectionPending=nil
            self.CastPos=r.target;self.correctedCastPos=copy(p);self.ActionScreen=copy(p);r.actionScreen=copy(p)
            if not self:SetPosition(p,'action') then self:release('world_reposition_failed');return false end
            r.confirmAfterPass=self.ResolutionPass;r.awaitingPosition=true
            return self:WorldPlacementConfirmed(r)
        end
        self.CastPos=r.target
        if r.confirmAfterPass==self.ResolutionPass then return self:WorldPlacementConfirmed(r) end
        return true
    end
    input.ResolutionPass=0
end

end)()
    installWorld(Cursor,GetTickCount)
    Cursor.DiagnosticsEnabled=({}).enabled==true
    GameIsChatOpen=function()return Cursor:IsChatOpen()end
    Control.KeyDown=function(key)return Cursor:AcquireKey(key,'control')end
    Control.KeyUp=function(key)return Cursor:ReleaseKey(key,'control')end
end

-- Track Crescendum's outgoing and returning missile because the next attack is ready only after the chakram returns.
local CRESCENDUM_MISSILE_OUT = "ApheliosCrescendumAttackMisOut"
local CRESCENDUM_MISSILE_IN = "ApheliosCrescendumAttackMisIn"

Attack = {

	TestDamage = false,
	TestCount = 0,
	TestStartTime = 0,
	IsGraves = myHero.charName == "Graves",
	SpecialWindup = Data.SpecialWindup[myHero.charName],
	IsJhin = myHero.charName == "Jhin",
	IsAphelios = myHero.charName == "Aphelios",
	IsCaitlyn = myHero.charName == "Caitlyn",
	BaseAttackSpeed = Data.HeroData and Data.HeroData[3] or 0.625,
	AttackSpeedRatio = Data.HeroData and (Data.HeroData[4] or Data.HeroData[3]) or 0.625,
	BaseWindupTime = nil,
	Reset = false,
	ServerStart = 0,
	CastEndTime = 1,
	LocalStart = 0,
	AttackWindup = 0,
	AttackAnimation = 0,
	IsSenna = myHero.charName == "Senna",
	CrescendumMissilePhase = nil,
	CrescendumMissileID = nil,
	CrescendumSearchStart = 0,
	CrescendumSearchUntil = 0,

	ClearCrescendumMissile = function(self)
		self.CrescendumMissilePhase = nil
		self.CrescendumMissileID = nil
		self.CrescendumSearchStart = 0
		self.CrescendumSearchUntil = 0
	end,

	FindCrescendumMissile = function(self, includeOutgoing)
		for i = GameMissileCount(), 1, -1 do
			local missile = GameMissile(i)
			local data = missile and missile.missileData
			if data and data.owner == myHero.handle then
				if data.name == CRESCENDUM_MISSILE_IN then
					return missile.networkID, "in"
				elseif includeOutgoing and data.name == CRESCENDUM_MISSILE_OUT then
					return missile.networkID, "out"
				end
			end
		end
		return nil, nil
	end,

	StartCrescendumMissile = function(self)
		local now = GameTimer()
		self.CrescendumMissilePhase = "find_out"
		self.CrescendumMissileID = nil
		self.CrescendumSearchStart = math_max(now, self.CastEndTime - Data:GetLatency() - 0.05)
		self.CrescendumSearchUntil = self.CrescendumSearchStart + 0.4
	end,

	UpdateCrescendumMissile = function(self)
		if not self.IsAphelios or not self.CrescendumMissilePhase then
			return
		end
		if myHero.dead then
			self:ClearCrescendumMissile()
			return
		end

		local now = GameTimer()
		local phase = self.CrescendumMissilePhase
		if phase == "out" or phase == "in" then
			local missile = self.CrescendumMissileID and GameGetObjectByNetID(self.CrescendumMissileID)
			local data = missile and missile.missileData
			local expectedName = phase == "out" and CRESCENDUM_MISSILE_OUT or CRESCENDUM_MISSILE_IN
			if data and data.owner == myHero.handle and data.name == expectedName then
				return
			end

			self.CrescendumMissileID = nil
			if phase == "in" then
				self:ClearCrescendumMissile()
				self.Reset = true
				return
			end

			self.CrescendumMissilePhase = "find_in"
			self.CrescendumSearchStart = now
			self.CrescendumSearchUntil = now + 0.6
			phase = "find_in"
		end

		if now < self.CrescendumSearchStart then
			return
		end
		self.CrescendumSearchStart = now + 0.01

		local missileID, missilePhase = self:FindCrescendumMissile(phase == "find_out")
		if missileID then
			self.CrescendumMissileID = missileID
			self.CrescendumMissilePhase = missilePhase
			return
		end

		if now >= self.CrescendumSearchUntil then
			self:ClearCrescendumMissile()
		end
	end,

	OnTick = function(self)
		if Data:CanResetAttack() and Orbwalker.Menu.General.AttackResetting:Value() then
			self.Reset = true
		end
		local spell = myHero.activeSpell
		if
			spell
			and spell.valid
			and spell.target > 0
			and spell.castEndTime > self.CastEndTime
			and (spell.isAutoAttack or Data:IsAttack(spell.name))
		then
			self.Reset = false
			-- spell.isAutoAttack then  and GameTimer() < self.LocalStart + 0.2
			for i = 1, #Orbwalker.OnAttackCb do
				Orbwalker.OnAttackCb[i]()
			end
			self.CastEndTime = spell.castEndTime
			self.AttackWindup = spell.windup
			self.ServerStart = self.CastEndTime - self.AttackWindup
			self.AttackAnimation = spell.animation
			if self.IsCaitlyn and spell.name == "CaitlynPassiveMissile" then
				local target = Orbwalker.LastTarget
				if
					not target
					or (spell.target ~= target.handle and spell.target ~= target.networkID)
				then
					target = GameGetObjectByNetID(spell.target)
				end
				Data:ConsumeCaitlynMark(target)
			end
			if self.IsAphelios then
				if spell.name == "ApheliosCrescendumAttack" then
					self:StartCrescendumMissile()
				end
			end
			if self.TestDamage then
				if self.TestCount == 0 then
					self.TestStartTime = GameTimer()
				end
				self.TestCount = self.TestCount + 1
				if self.TestCount == 5 then
					--print('5 attacks in time: ' .. tostring(GameTimer() - self.TestStartTime) .. '[sec]')
					self.TestCount = 0
					self.TestStartTime = 0
				end
			end
		end
		self:UpdateCrescendumMissile()
	end,

	GetAttackSpeed = function(self)
		if self.IsJhin then
			-- Jhin's passive applies 3% level growth to base AS despite AS ratio 0.
			local level = myHero.levelData.lvl - 1
			return self.BaseAttackSpeed * (1 + 0.03 * level * (0.7025 + 0.0175 * level))
		end
		return self.BaseAttackSpeed + (myHero.attackSpeed - 1) * self.AttackSpeedRatio
	end,

	GetWindup = function(self)
		if self.IsJhin then
			return self.AttackWindup
		end
		if self.IsGraves then
			return myHero.attackData.windUpTime * 0.2
		end
		if self.SpecialWindup then
			local windup = self.SpecialWindup()
			if windup then
				return windup
			end
		end
		if self.BaseWindupTime then
			return math_max(self.AttackWindup, 1 / self:GetAttackSpeed() / self.BaseWindupTime)
		end
		local data = myHero.attackData
		if data.animationTime > 0 and data.windUpTime > 0 then
			self.BaseWindupTime = data.animationTime / data.windUpTime
		end
		return math_max(self.AttackWindup, myHero.attackData.windUpTime)
	end,

	GetAnimation = function(self)
		if self.IsJhin then
			return self.AttackAnimation
		end
		if self.IsGraves then
			return myHero.attackData.animationTime * 0.9
		end
		return 1 / self:GetAttackSpeed()
	end,

	GetProjectileSpeed = function(self)
		if Data.IsHeroMelee or (Data.IsHeroSpecialMelee and Data.IsHeroSpecialMelee()) then
			return math_huge
		end
		if Data.SpecialMissileSpeed then
			local speed = Data.SpecialMissileSpeed()
			if speed then
				return speed
			end
		end
		local speed = myHero.attackData.projectileSpeed
		if speed > 0 then
			return speed
		end
		return math_huge
	end,

	IsReady = function(self)
		if self.IsAphelios and self.CrescendumMissilePhase then
			return false
		end
		if myHero.charName=="Sion" and myHero.attackData.state==STATE_ATTACK then
			return true
		end
		if self.CastEndTime > self.LocalStart then
        	if GameTimer() >= self.ServerStart + self:GetAnimation() - Data:GetLatency() - 0.01 then
				self.Reset = false
				return true
			elseif self.Reset and not self:IsActive() and not (myHero.pathing and myHero.pathing.isDashing) then
				-- print('Reset AA Success')
            	return true
			end
			return false
		end
		if GameTimer() < self.LocalStart + 0.2 then
			return false
		end
		if myHero.charName=="Rengar" and Game.CanUseSpell(_Q)~=8 and myHero:GetSpellData(63).castTime+myHero.attackData.windDownTime>Game.Timer()+10+LATENCY * 0.001 then
			return false
		end

		return true
	end,

	GetAttackCastTime = function(self, num)
		num = num or 0
		return self:GetWindup()
			- Data:GetLatency()
			+ num
			+ 0.025
			+ (Orbwalker.Menu.General.ExtraWindUpTime:Value() * 0.001)
	end,

	IsActive = function(self, num)
		num = num or 0
		if self.CastEndTime > self.LocalStart then
			if
				GameTimer()
				>= self.ServerStart
					+ self:GetWindup()
					- Data:GetLatency()
					+ 0.025
					+ num
					+ (Orbwalker.Menu.General.ExtraWindUpTime:Value() * 0.001)
			then
				return false
			end
			return true
		end
		if GameTimer() < self.LocalStart + 0.2 then
			return true
		end
		return false
	end,

	IsBefore = function(self, multipier)
		return GameTimer() > self.LocalStart + multipier * self:GetAnimation()
	end,
}

Orbwalker = {

	LastTarget = nil,
	-- CanHoldPosition = true,
	PostAttackTimer = 0,
	IsNone = true,
	OnPreAttackCb = {},
	OnPostAttackCb = {},
	OnPostAttackTickCb = {},
	OnAttackCb = {},
	OnMoveCb = {},
	Menu = Menu.Orbwalker,
	MenuDrawings = Menu.Main.Drawings,
	-- HoldPositionButton = Menu.Orbwalker.Keys.HoldKey,

	MenuKeys = {
		[ORBWALKER_MODE_COMBO] = {},
		[ORBWALKER_MODE_HARASS] = {},
		[ORBWALKER_MODE_LANECLEAR] = {},
		[ORBWALKER_MODE_JUNGLECLEAR] = {},
		[ORBWALKER_MODE_LASTHIT] = {},
		[ORBWALKER_MODE_FLEE] = {},
	},

	Modes = {
		[ORBWALKER_MODE_COMBO] = false,
		[ORBWALKER_MODE_HARASS] = false,
		[ORBWALKER_MODE_LANECLEAR] = false,
		[ORBWALKER_MODE_JUNGLECLEAR] = false,
		[ORBWALKER_MODE_LASTHIT] = false,
		[ORBWALKER_MODE_FLEE] = false,
	},

	ForceMovement = nil,
	ForceTarget = nil,
	PostAttackBool = false,
	AttackEnabled = true,
	MovementEnabled = true,
	TCOComboActive = false,

	CanAttackC = function()
		return true
	end,

	CanMoveC = function()
		return true
	end,

	OnTick = function(self)
        if not self:IsEnabled() then return end
		if Cursor.Step > 0 then
			return
		end
		if (Attack.Reset or Data.ActiveAttackReset) and myHero.pathing and myHero.pathing.isDashing then
			return
		end
		if Data:Stop() then
			return
		end
		if myHero.dead or (myHero.charName == "Sion" and Buff:HasBuff(myHero, "sionpassivedelay")) or self.IsNone then
			return
		end
		self:Orbwalk()
	end,

	OnDraw = function(self)
		if not self.Menu.Enabled:Value() then
			return
		end
		if self.MenuDrawings.Range:Value() then
			Draw.Circle(myHero.pos, Data:GetAutoAttackRange(myHero), 1, Color.Range)
		end
		if self.MenuDrawings.HoldRadius:Value() then
			Draw.Circle(myHero.pos, self.Menu.General.HoldRadius:Value(), 1, Color.LightGreen)
		end
		if self.MenuDrawings.EnemyRange:Value() then
			local t = Object:GetEnemyHeroes()
			for i = 1, #t do
				local enemy = t[i]
				local range = Data:GetAutoAttackRange(enemy, myHero)
				Draw.Circle(enemy.pos, range, 1, IsInRange(enemy, myHero, range) and Color.EnemyRange or Color.Range)
			end
		end
	end,

	RegisterMenuKey = function(self, mode, key)
		table_insert(self.MenuKeys[mode], key)
	end,

	ResetMovement = function(self)
		Movement.MoveTimer = 0
	end,

	GetModes = function(self)
		return {
			[ORBWALKER_MODE_COMBO] = self:HasMode(ORBWALKER_MODE_COMBO),
			[ORBWALKER_MODE_HARASS] = self:HasMode(ORBWALKER_MODE_HARASS),
			[ORBWALKER_MODE_LANECLEAR] = self:HasMode(ORBWALKER_MODE_LANECLEAR),
			[ORBWALKER_MODE_JUNGLECLEAR] = self:HasMode(ORBWALKER_MODE_JUNGLECLEAR),
			[ORBWALKER_MODE_LASTHIT] = self:HasMode(ORBWALKER_MODE_LASTHIT),
			[ORBWALKER_MODE_FLEE] = self:HasMode(ORBWALKER_MODE_FLEE),
		}
	end,

	HasMode = function(self, mode)
		if mode == ORBWALKER_MODE_NONE then
			for _, value in pairs(self:GetModes()) do
				if value then
					return false
				end
			end
			return true
		end
		for i = 1, #self.MenuKeys[mode] do
			local key = self.MenuKeys[mode][i]
			if key:Value() then
				return true
			end
		end
		return false
	end,

	OnPreAttack = function(self, func)
		table_insert(self.OnPreAttackCb, func)
	end,

	OnPostAttack = function(self, func)
		table_insert(self.OnPostAttackCb, func)
	end,

	OnPostAttackTick = function(self, func)
		table_insert(self.OnPostAttackTickCb, func)
	end,

	OnAttack = function(self, func)
		table_insert(self.OnAttackCb, func)
	end,

	OnPreMovement = function(self, func)
		table_insert(self.OnMoveCb, func)
	end,

	CanAttackEvent = function(self, func)
		self.CanAttackC = func
	end,

	CanMoveEvent = function(self, func)
		self.CanMoveC = func
	end,

	__OnAutoAttackReset = function(self)
		Attack.Reset = true
	end,

	SetMovement = function(self, boolean)
		self.MovementEnabled = boolean
	end,

	SetAttack = function(self, boolean)
		self.AttackEnabled = boolean
	end,

	IsEnabled = function(self)
		return self.Menu.Enabled:Value() == true
	end,

	IsAutoAttacking = function(self, unit)
		if unit == nil or unit.isMe then
			return Attack:IsActive()
		end
		return GameTimer() < unit.attackData.endTime - unit.attackData.windDownTime
	end,

	CanMove = function(self, unit)
		if unit == nil or unit.isMe then
			if not self.CanMoveC() then
				return false
			end
			if (JustEvade and JustEvade.Evading()) or (ExtLibEvade and ExtLibEvade.Evading) then
				return false
			end
	 		if myHero.charName == "Kalista" then
				return true
			end
	 		if myHero.charName == "Kaisa" and Buff:HasBuff(myHero, "KaisaE") then
				return true -- Fix bug: Kai'Sa's E ability incorrectly recognized as basic attack
			end
	 		if myHero.charName == "Aphelios" and Buff:HasBuff(myHero, "ApheliosSeverumQ") then
				return true
			end
			if not Data:HeroCanMove() then
				return false
			end
			return not Attack:IsActive()
		end
		local attackData = unit.attackData
		return GameTimer() > attackData.endTime - attackData.windDownTime
	end,

	CanAttack = function(self, unit)
		if unit == nil or unit.isMe then
			if not self.CanAttackC() then
				return false
			end
			if (JustEvade and JustEvade.Evading()) or (ExtLibEvade and ExtLibEvade.Evading) then
				return false
			end
			if not Data:HeroCanAttack() then
				return false
			end
			return Attack:IsReady()
		end
		return GameTimer() > unit.attackData.endTime
	end,

	KindredETarget = function(self, unit)
		if (unit and Buff:HasBuff(unit,"kindredecharge"))==false then
			return false
		end
		local particleCount = Game.ParticleCount()
		for i = particleCount, 1, -1 do
			local obj = Game.Particle(i)
			local name = obj and obj.name and obj.name:lower()
			if
				obj
				and obj.type == "obj_GeneralParticleEmitter"
				and name
				and name:find("kindred")
				and name:find("_e_")
				and name:find("stack_3")
				and obj.pos
				and GetDistance(obj.pos, unit.pos) < 100
			then
				return false
			end
		end
		return true
	end,
	GetTarget = function(self)
		if
			Object:IsValid(self.ForceTarget)
			and ChampionInfo:CustomIsTargetable(self.ForceTarget)
			and (Object:IsHeroImmortal(self.ForceTarget, true)==false or (Object.IsKindred and (self:KindredETarget(self.ForceTarget))))
		then

			return self.ForceTarget
		end
		if self.Modes[ORBWALKER_MODE_COMBO] then
			return Target:GetComboTarget()
		end
		if self.Modes[ORBWALKER_MODE_LASTHIT] then
			return Health:GetLastHitTarget()
		end
		if self.Modes[ORBWALKER_MODE_JUNGLECLEAR] then
			local jungle = Health:GetJungleTarget()
			if jungle ~= nil then
				return jungle
			end
		end
		if self.Modes[ORBWALKER_MODE_LANECLEAR] then
			return Health:GetLaneClearTarget()
		end
		if self.Modes[ORBWALKER_MODE_HARASS] then
			return Health:GetHarassTarget()
		end
		return nil
	end,

	OnUnkillableMinion = function(self, cb)
		table_insert(Health.OnUnkillableC, cb)
	end,

	Attack = function(self, unit, actionRecord)
		if not self.Menu.AttackEnabled:Value()  or Control.IsKeyDown(0x11) or Control.IsKeyDown(0x12) then -- ctrl or alt, press these will spam clicks
			return
		end
		if self.AttackEnabled and unit and unit.valid and unit.visible and unit.pos:To2D().onScreen then
			self.LastTarget = unit
			if self:CanAttack() then
				local args = { Target = unit, Process = true }
				for i = 1, #self.OnPreAttackCb do
					self.OnPreAttackCb[i](args)
				end
				if args.Process then
					if args.Target and not ChampionInfo:CustomIsTargetable(args.Target) then
						args.Target = Target:GetComboTarget()
					end
					if args.Target then
						local targetpos = args.Target.pos
						if targetpos and targetpos:ToScreen().onScreen then
							if
								not Data:IsInAutoAttackRange(myHero, args.Target)
								and not (Object.IsAzir and ChampionInfo:IsInAzirSoldierRange(args.Target))
							then
								return false
							end
							self.LastTarget = args.Target
							if not Control.Attack(args.Target, actionRecord) then
								return false
							end
							Attack.Reset = false
							Attack.LocalStart = GameTimer()
							self.PostAttackBool = true
							return true
						end
					end
				end
			end
		end
		return false
	end,

	Move = function(self)
		if not self.Menu.MovementEnabled:Value() then
			return
		end
		if self.MovementEnabled and self:CanMove() then
			if self.PostAttackBool and not Attack:IsActive(0.025) then
				for i = 1, #self.OnPostAttackCb do
					self.OnPostAttackCb[i]()
				end
				self.PostAttackTimer = GameTimer()
				self.PostAttackBool = false
			end
			if not Attack:IsActive(0.025) and GameTimer() < self.PostAttackTimer + 1 then
				for i = 1, #self.OnPostAttackTickCb do
					self.OnPostAttackTickCb[i](self.PostAttackTimer)
				end
			end
			local mePos = myHero.pos
			if IsInRange(mePos, Cursor:GetPlayerPosition(), self.Menu.General.HoldRadius:Value()) then
				-- if self.CanHoldPosition then
				-- 	Control.Hold(self.HoldPositionButton:Key())
				-- end
				return
			end
			if GetTickCount() > Movement.MoveTimer then

				local args = { Target = nil, Process = true }
				for i = 1, #self.OnMoveCb do
					self.OnMoveCb[i](args)
				end
				if not args.Process then
					return
				end
				if self.ForceMovement ~= nil then
					Control.Move(self.ForceMovement)
					return
				end
				if args.Target ~= nil then
					if args.Target.x then
						args.Target = Vector(args.Target)
					elseif args.Target.pos then
						args.Target = args.Target.pos
					end
					Control.Move(args.Target)
					return
				end
				-- local pos = IsInRange(mePos, Cursor:GetPlayerPosition(), 100) and mePos:Extend(mousePos, 100) or nil
				Control.Move()
			end
		end
	end,

	Orbwalk = function(self)
		if not self:Attack(self:GetTarget()) then
			self:Move()
		end
	end,
}

Orbwalker:RegisterMenuKey(ORBWALKER_MODE_COMBO, Menu.Orbwalker.Keys.Combo)
Orbwalker:RegisterMenuKey(ORBWALKER_MODE_HARASS, Menu.Orbwalker.Keys.Harass)
Orbwalker:RegisterMenuKey(ORBWALKER_MODE_LASTHIT, Menu.Orbwalker.Keys.LastHit)
Orbwalker:RegisterMenuKey(ORBWALKER_MODE_LANECLEAR, Menu.Orbwalker.Keys.LaneClear)
Orbwalker:RegisterMenuKey(ORBWALKER_MODE_JUNGLECLEAR, Menu.Orbwalker.Keys.Jungle)
Orbwalker:RegisterMenuKey(ORBWALKER_MODE_FLEE, Menu.Orbwalker.Keys.Flee)

do
local install=(function()
-- Target-dependent attack procs belong to the SDK, including for scripts that
-- never load ClassicAIO. No input ownership or forced target is changed here.
return function(Damage,Health,Buff,Data,Attack,hero,clock,profile,menu,Object)
    function Damage:GetSilverBoltsState(from,target,at)
        if not from or from.charName~='Jade_Vayne' or not target then return 0,0 end
        local proc=profile.Damage(from,target)
        if proc==0 then return 0,0 end
        return profile.Stacks(Buff:GetBuff(target,profile.buff),at or clock(),from),proc
    end
    Damage.HeroPassiveDamage.Jade_Vayne=function(args)
        local stacks,proc=Damage:GetSilverBoltsState(args.From,args.Target)
        if stacks==2 then args.CalculatedTrue=args.CalculatedTrue+proc end
    end
    function Damage:GetAutoAttackDamageAt(from,target,delay,static)
        local damage=self:GetAutoAttackDamage(from,target,true,static)
        if from.charName~='Jade_Vayne' then return damage end
        local now=clock();local current,proc=self:GetSilverBoltsState(from,target,now)
        local future=self:GetSilverBoltsState(from,target,now+math.max(0,delay or 0))
        return damage-(current==2 and proc or 0)+(future==2 and proc or 0)
    end
    if hero.charName~='Jade_Vayne' then return end
    menu:MenuElement({id='PreserveSilverBolts',name='Vayne: preserve W stacks while clearing',value=true})
    local original=Health.GetLaneMinion
    function Health:GetLaneMinion()
        local chosen=original(self)
        if not chosen or not menu.PreserveSilverBolts:Value() or self.IsLastHitable then return chosen end
        local speed=Attack:GetProjectileSpeed();local impact=Attack:GetWindup()+chosen.distance/speed
        local function estimate(unit,hp,at)
            local stacks,proc=Damage:GetSilverBoltsState(hero,unit,clock()+at)
            local aa=Damage:GetAutoAttackDamageAt(hero,unit,at,self.StaticAutoAttackDamage)
            return profile.AttacksToKill(hp,aa-(stacks==2 and proc or 0),stacks,proc),stacks
        end
        local count=estimate(chosen,self:GetPrediction(chosen,impact),impact)
        local best=chosen
        for i=1,#self.FarmMinions do
            local row=self.FarmMinions[i];local unit=row.Minion
            if Object:IsValid(unit) and Data:IsInAutoAttackRange(hero,unit)
                and not row.AlmostAlmost and not row.AlmostLastHitable and row.PredictedHP>0 then
                local at=Attack:GetWindup()+unit.distance/speed
                local stacks=Damage:GetSilverBoltsState(hero,unit,clock()+at)
                if stacks>0 then
                    local hits=estimate(unit,row.PredictedHP,at)
                    if hits<math.huge and hits<=count then best=unit;count=hits end
                end
            end
        end
        return best
    end
end

end)()
install(Damage,Health,Buff,Data,Attack,myHero,GameTimer,(function()
-- Classic values retained from the pinned GG/Jade profile, not modern SR.
local P={buff='Jade_VayneW_Debuff'}
local function multiplicity(value)
    return (value==1 or value==2) and value or 0
end
function P.Stacks(buff,at,source)
    if not buff or (buff.count or 0)<=0 then return 0 end
    local expires=buff.expireTime
    if not expires or expires<=0 then expires=buff.endTime end
    if expires and expires>0 and expires<=at then return 0 end
    local owner=buff.source
    if source and owner and owner~=0 then
        if type(owner)=='number' then
            if owner~=source.handle and owner~=source.networkID then return 0 end
        elseif (type(owner)=='table' or type(owner)=='userdata') and owner.networkID and owner.networkID~=source.networkID then return 0 end
    end
    -- Hosts expose stack multiplicity in either field. Count can be only the
    -- active-buff flag; never infer an extra hit from an issued attack command.
    -- Live Classic can expose count=2 alongside stacks=9. Validate each field
    -- independently so an unrelated/invalid value cannot erase a valid mark.
    return math.max(multiplicity(buff.count),multiplicity(buff.stacks))
end
function P.Damage(source,target)
    local spell=source:GetSpellData(1);local rank=spell and spell.level or 0
    if rank<1 or rank>5 or not target or not target.maxHealth then return 0 end
    local damage=10+10*rank+(0.03+0.01*rank)*target.maxHealth
    return target.team==300 and math.min(damage,200) or damage
end
-- Short, bounded planning horizon. Existing item/on-hit damage is supplied by
-- the SDK. This is an estimate, not a promise about future health or movement.
function P.AttacksToKill(health,base,stacks,proc)
    if base<=0 then return math.huge end
    for n=1,6 do
        health=health-base
        stacks=stacks+1
        if stacks==3 then health=health-proc;stacks=0 end
        if health<=0 then return n end
    end
    return math.huge
end
return P

end)(),Menu.Orbwalker.Farming,Object)
end

do
local install=(function()
-- Shared champion damage adapter. No controller policy or input.
return function(Damage,Buff,clock,profile,magical)
    local function apply(args)
        local from=args.From;local p=profile.Profile(from.charName)
        local _,color=profile.CardState(p,'',function(name)return Buff:GetBuff(from,name)end,clock())
        local e=p.eBuff and profile.AliveBuff(Buff:GetBuff(from,p.eBuff),clock())
        local raw=profile.Attack(p,from,from:GetSpellData(1).level,from:GetSpellData(2).level,color,e,false)
        args.RawTotal=color and 0 or from.totalDamage
        args.RawMagical=args.RawMagical+raw.magical
        if color then args.DamageType=magical end
    end
    Damage.HeroStaticDamage.TwistedFate=apply
    Damage.HeroStaticDamage.Jade_TwistedFate=apply
    local passive=Damage.HeroPassiveDamage.TwistedFate
    Damage.HeroPassiveDamage.TwistedFate=function(args)
        if passive then passive(args)end
        local p=profile.Profile('TwistedFate');local from=args.From
        if args.Target.type==Obj_AI_Turret and profile.AliveBuff(Buff:GetBuff(from,p.eBuff),clock())then
            args.RawMagical=math.max(0,args.RawMagical-profile.E(p,from:GetSpellData(2).level,from,false)*(1-p.towerE))
        end
    end
    -- Additive API: typed, item-free mechanics for bounded controller simulation.
    Damage.TwistedFateProfile=profile
    function Damage:GetTwistedFateAttack(from,target,color,eReady)
        local p=profile.Profile(from.charName)
        if not p then return nil end
        local items={};for slot=6,12 do items[slot]=from:GetItemData(slot)end
        local raw=profile.Attack(p,from,from:GetSpellData(1).level,from:GetSpellData(2).level,color,eReady,
            target and target.type==Obj_AI_Turret,profile.CritMultiplier(p,items))
        if target and (target.type==Obj_AI_Hero or target.type==Obj_AI_Minion)then
            local charge=Buff:GetBuff(from,'itemstatikshankcharge')
            local extra=profile.ItemAttack(p,from,{health=target.health,minion=target.type==Obj_AI_Minion,hero=target.type==Obj_AI_Hero},items,
                {energized=profile.AliveBuff(charge,clock()) and charge.stacks==100})
            raw.physical=raw.physical+extra.physical;raw.magical=raw.magical+extra.magical
        end
        return raw
    end
    local original=Damage.GetHeroAutoAttackDamage
    function Damage:GetHeroAutoAttackDamage(from,target,static)
        local p=profile.Profile(from.charName)
        if not p then return original(self,from,target,static)end
        if target.type==Obj_AI_Minion and target.maxHealth<=6 then return 1 end
        local _,color=profile.CardState(p,'',function(name)return Buff:GetBuff(from,name)end,clock())
        local e=p.eBuff and profile.AliveBuff(Buff:GetBuff(from,p.eBuff),clock())
        local raw=self:GetTwistedFateAttack(from,target,color,e)
        return self:CalculateDamage(from,target,DAMAGE_TYPE_PHYSICAL,raw.physical,false,true)
            +self:CalculateDamage(from,target,magical,raw.magical,false,true)
    end
end

end)()
install(Damage,Buff,GameTimer,(function()
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

end)(),DAMAGE_TYPE_MAGICAL)
end

do
local install = (function()
-- Generic selected-target reservation. No champion/controller dependencies.
return function(target,clock,grace)
    local previous,hiddenAt
    function target:GetSelectedTarget()
        local selected=self.Selected
        if not selected or selected.dead or (selected.health or 0)<=0 or selected.valid==false then
            if selected then self.Selected=nil end
            previous=nil;hiddenAt=nil;return nil
        end
        if selected~=previous then previous=selected;hiddenAt=nil end
        if self.MenuCheckSelected and not self.MenuCheckSelected:Value() then hiddenAt=nil;return nil end
        if selected.visible~=false then hiddenAt=nil;return selected end
        local now=clock();hiddenAt=hiddenAt or now
        if self.MenuCheckSelectedOnly and self.MenuCheckSelectedOnly:Value() then return selected end
        if now-hiddenAt<math.max(0,grace()) then return selected end
        -- Keep the user's selection so reappearance restores its priority.
        return nil
    end
    local tick=target.OnTick
    function target:OnTick(...)
        self:GetSelectedTarget()
        return tick(self,...)
    end
    local single,multiple=target.GetTarget,target.GetTargets
    function target:GetTarget(...)
        local selected=self:GetSelectedTarget()
        if selected and selected.visible==false then return nil end
        return single(self,...)
    end
    function target:GetTargets(...)
        local selected=self:GetSelectedTarget()
        if selected and selected.visible==false then return {} end
        return multiple(self,...)
    end
end

end)()
Menu.Target:MenuElement({id="SelectedFogGrace",name="Reserve unseen selection (ms)",value=1500,min=0,max=3000,step=100})
install(Target,GameTimer,function()return Menu.Target.SelectedFogGrace:Value()/1000 end)
end

do
local prepare = (function()
-- Internal preparation; public callback lists and their ordering are untouched.
return function(cached, item, health, orb, input, env)
    local attack=orb.Attack
    if type(attack)=='function' then
        function orb:Attack(unit,record)
            local before=input.LastActionID
            local result=attack(self,unit,record)
            if input.DiagnosticsEnabled then
                local id=input.LastActionID~=before and input.LastActionID or record and record.id
                local action=id and input:GetAction(id)
                local row=self.LastAttackDiagnostic or {}
                row.at=env.time();row.target=unit and (unit.networkID or unit.handle)
                row.accepted=result==true;row.inputID=id;row.state=action and action.state
                row.reason=action and action.reason or result~=true and (not unit and 'no_target_selected' or 'attack_gated_before_input') or nil
                self.LastAttackDiagnostic=row
                if unit then
                    -- A subsequent nil-target tick must not erase evidence of
                    -- the last real attack attempt. Reuse private records;
                    -- GetControlState returns detached snapshots to consumers.
                    local targeted=self.LastTargetedAttackDiagnostic or {}
                    for key in pairs(targeted) do targeted[key]=nil end
                    for key,value in pairs(row) do targeted[key]=value end
                    self.LastTargetedAttackDiagnostic=targeted
                end
            end
            return result
        end
    end
    function item:Prepare()
        -- Invalidate independently of item automation, but enumerate inventory
        -- only when a consumer requests it. Reuse the two private maps.
        self.Snapshots=self.Snapshots or {};self.CachedItems=self.CachedItems or {}
        for id in pairs(self.Snapshots) do self.Snapshots[id]=nil end
        for id in pairs(self.CachedItems) do self.CachedItems[id]=nil end
    end
    function item:GetSnapshot(unit)
        self.Snapshots=self.Snapshots or {}
        local id=unit.networkID or unit.handle or unit
        if not self.Snapshots[id] then
            local snapshot={ids={},slots={},at=env.clock and env.clock() or 0}
            for i,slot in ipairs(env.slots) do
                local value=unit:GetItemData(slot)
                -- Copy the fields we expose; host userdata can change in place.
                if value and value.itemID and value.itemID>0 then
                    snapshot.slots[slot]={itemID=value.itemID,stacks=value.stacks,stackCount=value.stackCount,ammo=value.ammo,currentCd=value.currentCd}
                    snapshot.ids[value.itemID]=i
                end
            end
            self.Snapshots[id]=snapshot; self.CachedItems[id]=snapshot.ids
        end
        return self.Snapshots[id]
    end
    function orb:Prepare()
        local enabled=self:IsEnabled()
        self.Modes=enabled and self:GetModes() or {}
        self.IsNone=true
        for _,value in pairs(self.Modes) do if value then self.IsNone=false;break end end
        if not enabled then
            if self.WasEnabled~=false then input:CancelAll('disabled') end
            item.QssPending=nil
        end
        self.WasEnabled=enabled
        local active=enabled and self.Modes[env.combo] and not env.hero.dead
            and (not input.env.focus or input.env.focus())
            and (not input.env.chat or not input.env.chat())
        if active and not input.ForceTCOUp then input:AcquireKey(env.tco,'orbwalker')
        else input:ReleaseKey(env.tco,'orbwalker') end
        self.TCOComboActive=not not active
    end
    -- Read-only control diagnostics for any plugin. No calls to movement hooks
    -- and no mutation of bindings, keys or external movement ownership.
    function orb:GetControlState()
        local row={enabled=self:IsEnabled(),attackEnabled=self.AttackEnabled,movementEnabled=self.MovementEnabled,
            menuAttack=self.Menu.AttackEnabled:Value(),menuMovement=self.Menu.MovementEnabled:Value(),
            none=self.IsNone,dead=env.hero.dead==true,bindings={},modes={},
            forceMovement=self.ForceMovement~=nil,forceTarget=self.ForceTarget~=nil,
            cursorPhase=input.Step,uncertain=input.Uncertain==true,chat=input:IsChatOpen(),
            targetChampionsOnly=input:ReadKeyState(env.tco),targetFilterKey=env.tco,
            targetFilterPhysical=input.Physical[env.tco]==true,
            targetFilterOwner=input.KeysOwned[env.tco],
            targetFilterRecoveryAttempts=input.TCORecovery and input.TCORecovery.attempts,
            ctrl=input:ReadKeyState(17),alt=input:ReadKeyState(18),
            attackKey=input.env.attackKey and input.env.attackKey()}
        if self.LastAttackDiagnostic then
            row.lastAttack={};for key,value in pairs(self.LastAttackDiagnostic) do row.lastAttack[key]=value end
        end
        if self.LastTargetedAttackDiagnostic then
            row.lastTargetedAttack={};for key,value in pairs(self.LastTargetedAttackDiagnostic) do row.lastTargetedAttack[key]=value end
        end
        for mode,value in pairs(self.Modes or {}) do row.modes[mode]=value end
        for mode,bindings in pairs(self.MenuKeys or {}) do
            local out={};row.bindings[mode]=out
            for _,binding in ipairs(bindings) do
                local key=binding.Key and binding:Key()
                out[#out+1]={key=key,active=binding:Value(),hostDown=key and input:ReadKeyState(key)}
            end
        end
        return row
    end
    function cached:RefreshCritical(kind)
        if kind=='ward' then self.TempCacheBuffer.w=0; self.WardsSaved=false; self.Wards={}
        elseif kind=='target' then self.TempCacheBuffer.m=0; self.MinionsSaved=false; self.Minions={} end
    end
    function health:DispatchCallbacks()
        if self.PendingSpellResets then
            self.PendingSpellResets=false
            for i=1,#self.Spells do self.Spells[i]:Reset() end
        end
        local pending=self.PendingUnkillable or {};self.PendingUnkillable=nil
        for i=1,#pending do pending[i].callback(pending[i].target) end
        if self.PendingSpellTicks then
            self.PendingSpellTicks=false
            for i=1,#self.Spells do self.Spells[i]:Tick() end
        end
    end
    function health:GetIncoming(handle)
        self.PredictionWork=self.PredictionWork or {indexVisits=0,candidates=0,queries=0}
        local work=self.PredictionWork
        if not self.IncomingReady then
            self.IncomingIndex=self.IncomingIndex or {}
            for _,bucket in pairs(self.IncomingIndex) do for id in pairs(bucket) do bucket[id]=nil end end
            for id,attack in pairs(self.ActiveAttacks) do
                work.indexVisits=work.indexVisits+1
                local target=attack.Target
                if target then
                    local bucket=self.IncomingIndex[target]
                    if not bucket then bucket={};self.IncomingIndex[target]=bucket end
                    bucket[id]=attack
                end
            end
            -- Empty target buckets do not grow across a long session.
            for id,bucket in pairs(self.IncomingIndex) do if next(bucket)==nil then self.IncomingIndex[id]=nil end end
            self.IncomingReady=true
        end
        self.EmptyIncoming=self.EmptyIncoming or {}
        work.queries=work.queries+1
        return self.IncomingIndex[handle] or self.EmptyIncoming
    end
end

end)()
prepare(Cached, Item, Health, Orbwalker, Cursor, {clock=GetTickCount, time=GameTimer, slots=ItemSlots, keys=ItemKeys, control=Control, tco=HK_TCO, combo=ORBWALKER_MODE_COMBO, hero=myHero})
end

_G.SDK = {
	OnDraw = {},
	OnTick = {},
	OnWndMsg = {},
	Menu = Menu,
	Color = Color,
	Action = Action,
	BuffManager = Buff,
	Damage = Damage,
	Data = Data,
	Spell = Spell,
	SummonerSpell = SummonerSpell,
	ItemManager = Item,
	ObjectManager = Object,
	TargetSelector = Target,
	HealthPrediction = Health,
	Cursor = Cursor,
	Attack = Attack,
	Orbwalker = Orbwalker,
	Cached = Cached,
	Movement = Movement,
	DAMAGE_TYPE_PHYSICAL = DAMAGE_TYPE_PHYSICAL,
	DAMAGE_TYPE_MAGICAL = DAMAGE_TYPE_MAGICAL,
	DAMAGE_TYPE_TRUE = DAMAGE_TYPE_TRUE,
	ORBWALKER_MODE_NONE = ORBWALKER_MODE_NONE,
	ORBWALKER_MODE_COMBO = ORBWALKER_MODE_COMBO,
	ORBWALKER_MODE_HARASS = ORBWALKER_MODE_HARASS,
	ORBWALKER_MODE_LANECLEAR = ORBWALKER_MODE_LANECLEAR,
	ORBWALKER_MODE_JUNGLECLEAR = ORBWALKER_MODE_JUNGLECLEAR,
	ORBWALKER_MODE_LASTHIT = ORBWALKER_MODE_LASTHIT,
	ORBWALKER_MODE_FLEE = ORBWALKER_MODE_FLEE,
	IsRecalling = function(unit)
		if unit == nil then
			return false
		end
		if Buff:HasBuff(unit, "recall") then
			return true
		end
		local as = unit.activeSpell
		if as and as.valid and as.name == "recall" then
			return true
		end
		return false
	end,
}

--[[tickTest = 2
drawTest = 2]]
Callback.Add("Load", function()
	ChampionInfo:OnLoad()

	Object:OnLoad()

	local ticks = SDK.OnTick
	local draws = SDK.OnDraw
	local wndmsgs = SDK.OnWndMsg

	local function OrbamaDraw()
		--[[local as = myHero.activeSpell
		if as and as.valid then
			print(as.name)
			print(as.castEndTime - Game.Timer())
		end
		Buff:Print(myHero)]]
		--[[local target = Target:GetTarget(2000)
		if target then
			if
				Buff:GetBuffDuration(target, "caitlynwsight") > 0.75
				or Buff:HasBuff(target, "eternals_caitlyneheadshottracker")
			then
				print("caitlynwsight  " .. os.clock())
			end
			--print(target.distance .. ' ' .. tostring(myHero.range + myHero.boundingRadius + target.boundingRadius))
			Buff:Print(target)
		end
		Buff:Print(myHero)

		if Buff:HasBuff(myHero, "caitlynpassivedriver") then
			print("myHero caitlynpassivedriver")
		end

		if drawTest ~= 2 then
			print("DRAW")
		end
		drawTest = 1]]

		if Menu.Main.Drawings.Enabled:Value() then
			Target:OnDraw()
			Cursor:OnDraw()
			Orbwalker:OnDraw()
			Health:OnDraw()
		end
		for i = 1, #draws do
			draws[i]()
		end
		--drawTest = 2
    end
    Callback.Add("Draw",function()
        SDK.Performance.enabled=Menu.Main.OrbamaLua.Profile:Value()
        return SDK.Performance:Call("draw",OrbamaDraw)
    end)

	local function OrbamaTick()
		--[[if tickTest ~= 2 then
			print("TICK")
		end
		tickTest = 1
		if Item:HasItem(myHero, 3031) then
			print("ok " .. os.clock())
		end]]
		--print(myHero.critChance)
		local latency = Game.Latency()
		_G.LATENCY = type(latency) == "number" and latency == latency and latency >= 0 and latency < math.huge and latency or Menu.Main.Latency:Value()
		if GameIsChatOpen() then
			LastChatOpenTimer = GetTickCount()
		end

        if Cursor.Step==0 then Cursor.GGCompatible=Menu.Main.OrbamaLua.GGCompatibility:Value() end
        Cursor.Timing.enabled=not Cursor.GGCompatible and (Menu.Main.OrbamaLua.AutoMovementTiming:Value() or Menu.Main.OrbamaLua.LearnMoves:Value())
        Cursor.Timing.removeSecondWait=not Cursor.GGCompatible and Menu.Main.OrbamaLua.ReleaseGapTrial:Value() and Cursor.ReleaseGapValidated==true
        Cursor.DetailedDiagnostics=Menu.Main.OrbamaLua.DetailedInput:Value()
        Cursor.DiagnosticsEnabled=({}).enabled==true
		Cached:Reset()
		Item:Prepare()
		Orbwalker:Prepare()
		FlashHelper:OnTick()
		Cursor:OnTick()
		Action:OnTick()
		Attack:OnTick()
		Health:OnTick()
		Target:OnTick()
        SDK.SharedData:Prepare()
        for _,fn in ipairs(SDK.OnUrgent) do
            if SDK.Performance.enabled then SDK.Performance:Call('urgent_callbacks',fn) else fn() end
        end
        SDK.Actions:Tick(2)
		Orbwalker:OnTick()
		ChampionInfo:OnTick()
		SummonerSpell:OnTick()
		Item:OnTick()
		Health:DispatchCallbacks()
		for i = 1, #ticks do
			if SDK.Performance.enabled then SDK.Performance:Call('sdk_callbacks',ticks[i]) else ticks[i]() end
		end
        if not Cursor.Active then
            for _,fn in ipairs(SDK.OnMaintenance) do if SDK.Performance.enabled then SDK.Performance:Call('maintenance',fn) else fn() end end
        end
        SDK.Actions:Tick()
		--tickTest = 2
    end
    Callback.Add("Tick", function()
        SDK.Performance.enabled=Menu.Main.OrbamaLua.Profile:Value()
        if SDK.Performance.enabled then return SDK.Performance:Call('tick',OrbamaTick) end
        return OrbamaTick()
    end)

	Callback.Add("WndMsg", function(msg, wParam)
		Cursor:OnInput(msg, wParam)
		Data:WndMsg(msg, wParam)
		Spell:WndMsg(msg, wParam)
		Target:WndMsg(msg, wParam)
		Cached:WndMsg(msg, wParam)
		for i = 1, #wndmsgs do
			wndmsgs[i](msg, wParam)
		end
	end)

	if _G.Orbwalker then
		_G.Orbwalker.Enabled:Value(false)
		_G.Orbwalker.Drawings.Enabled:Value(false)
	end
end)

SDK.OrbamaVersion='Orbama-lua-45'
SDK.Input=Cursor
SDK.OnMaintenance={}
SDK.GetPlayerPosition=function()return Cursor:GetPlayerPosition()end
do
    local create = (function()
return function()return {enabled=false,Call=function(_,name,fn,...)return fn(...)end,Wrap=function()end,Snapshot=function()return {enabled=false}end,EmitMetrics=function()end}end
end)()
    local profiler=create(GetTickCount)
    SDK.Performance=profiler
    if ({}).enabled==true then
    for name,object in pairs({cursor=Cursor,attack=Attack,orbwalker=Orbwalker,health=Health,
        target=Target,items=Item,summoners=SummonerSpell,champions=ChampionInfo,actions=Action}) do
        profiler:Wrap(object,'OnTick',name)
    end
    profiler:Wrap(Cursor,'call','host')
    profiler:Wrap(Cursor,'dispatch','input')
    profiler:Wrap(Cached,'Reset','cache_reset')
    profiler:Wrap(Item,'Prepare','inventory_prepare')
    profiler:Wrap(Orbwalker,'Prepare','mode_prepare')
    -- Nested exclusive scopes distinguish host-heavy damage work from health
    -- prediction. No new caching or changes to gameplay freshness.
    profiler:Wrap(Damage,'GetStaticAutoAttackDamage','damage_static')
    profiler:Wrap(Damage,'GetAutoAttackDamageAt','damage_attack')
    profiler:Wrap(Health,'SetLastHitable','health_last_hit')
    profiler:Wrap(Health,'LocalGetPrediction','health_prediction')
    profiler:Wrap(Health,'GetIncoming','health_incoming')
    table.insert(SDK.OnMaintenance,function()profiler:EmitMetrics(Cursor)end)
    end
end

SDK.MenuMigration=CommunityMenuMigration
SDK.SharedData=(function()
-- Shared identities with explicit refresh age. Lists are caller-owned; host objects remain live.
return function(game,clock,item,hero,attack)
    local data={version=1,rows={},cycle=0}
    local kinds={heroes='Hero',minions='Minion',wards='Ward',turrets='Turret',camps='Camp'}
    function data:Prepare()
        self.cycle=self.cycle+1
        for kind,name in pairs(kinds) do
            local count,get=game[name..'Count'],game[name]
            if count and get then
                local n=math.max(0,math.min(kind=='minions' and 4096 or 512,count()))
                local row=self.rows[kind]
                if not row or n~=row.count or clock()-row.at>=80 then
                    row={at=clock(),count=n,objects={}}
                    for i=1,n do local obj=get(i);if obj then row.objects[#row.objects+1]=obj end end
                    self.rows[kind]=row
                end
            end
        end
    end
    function data:GetObjects(kind)
        local r=self.rows[kind];if not r then return nil,'unavailable' end
        local list={};for i,obj in ipairs(r.objects) do list[i]=obj end
        return {objects=list,refreshedAt=r.at,ageMs=math.max(0,clock()-r.at),cycle=self.cycle,identityOnly=true}
    end
    function data:GetInventory()
        local r=item:GetSnapshot(hero);local slots={}
        for slot,entry in pairs(r.slots) do local row={};for k,v in pairs(entry) do row[k]=v end;slots[slot]=row end
        return {slots=slots,refreshedAt=r.at,ageMs=math.max(0,clock()-(r.at or clock())),cycle=self.cycle}
    end
    function data:GetAttack()
        return {castEndTime=attack.CastEndTime,timebase='Game.Timer seconds',observedAt=clock()}
    end
    return data
end

end)()(Game,GetTickCount,Item,myHero,Attack)
SDK.Actions=(function()
-- Public v1 contract. All host effects remain inside the input owner.
return function(input, clock, selectCandidate)
    if not selectCandidate then
        selectCandidate=function(candidates)
            local best,index
            for i,a in ipairs(candidates)do
                local b=best
                if not b or a.effective>b.effective or a.effective==b.effective and (
                    a.record.expires<b.record.expires or a.record.expires==b.record.expires and (
                        a.selectionLast<b.selectionLast or a.selectionLast==b.selectionLast and a.record.id<b.record.id)) then best,index=a,i end
            end
            return best,index
        end
    end
    local api={version=1,scopes={},queue={},actions={},sequences={},serial=0,turn=0,history={},scopeSerial=0,automation={},automationEpoch={cleanse=0,qss=0}}
    local rank={background=1,normal=2,interactive=3,critical=4}
    local function finite(n) return type(n)=='number' and n==n and math.abs(n)<math.huge end
    local function copy(t)
        if type(t)~='table' then return t end
        local out={};for k,v in pairs(t) do out[k]=copy(v) end;return out
    end
    local function reason(r)
        if r.generation~=input.Generation then return 'interrupted' end
        if clock()>r.expires then return 'expired' end
    end
    local function state(a)
        local r=a.record
        if r.sentAt then return r.submissionFailed and 'send_uncertain' or 'sent' end
        if r.state=='aborted' then return 'cancelled_before_send' end
        return a.waiting and 'waiting' or 'requested'
    end
    function api:Now() return clock() end
    function api:GetCapabilities()
        return {version=1,createClient=type(self.CreateClient)=='function',updatePriority=true,actionCleanupState=true,timebase='monotonic milliseconds; same epoch as GetTickCount',
            states={'requested','waiting','sent','cancelled_before_send','send_uncertain'},
            priorities={'critical','interactive','normal','background'},scopes=true,sequences=true,
            aimCandidates=true,aimFallback=true,maxAimCandidates=5,retryKeys=true,observations=true,keyedMechanicalObservation=true,maxWaitingPerScope=32,maxWaiting=128,
            attackApproach=type(input.env.executeApproach)=='function',
            independentMotion=false,withholdInput=false,hideCursor=false,survivePointerMotion=true,surviveMovementCommands=true,resolveWorldTarget=true,prevalidateWorldCast=true,worldCommitMaxMs=20,automationClaims=true,automationFunctions={"cleanse","qss"}}
    end
    function api:GetAvailability()
        return {available=input:Available() and not input.Uncertain,busy=input.Active~=nil or input.Step>0,
            uncertain=input.Uncertain==true,generation=input.Generation,activeID=input.Active and input.Active.id,
            pendingReturn=input.PendingReturn~=nil,cleanupPending=input.Active~=nil or input.PendingReturn~=nil
                or next(input.PendingUp or {})~=nil or next(input.Buttons or {})~=nil or next(input.KeysOwned or {})~=nil,at=clock()}
    end
    function api:GetPlayerPosition() return input:GetPlayerPosition() end
    function api:GetPlayerScreenPosition() return input:GetPlayerScreenPosition() end
    function api:RegisterScope(name,options)
        if type(name)~='string' or #name==0 or #name>64 then return nil,'invalid_scope' end
        options=options or {};local classes={normal=true}
        for _,p in ipairs(options.priorities or {}) do if not rank[p] then return nil,'invalid_priority' end;classes[p]=true end
        for _,s in pairs(self.scopes) do if s.name==name and not s.closed then return nil,'scope_exists' end end
        self.scopeSerial=self.scopeSerial+1
        local s={id=self.scopeSerial,name=name,classes=classes,cap='critical',waiting=0,last=0,retries={}}
        self.scopes[s.id]=s
        if self.onRegister then self.onRegister(s) end
        local handle={id=s.id}
        function handle:Request(request) return api:Request(self.id,request) end
        function handle:Sequence(steps,options) return api:Sequence(self.id,steps,options) end
        function handle:GetAction(id) return api:GetAction(self.id,id) end
        function handle:UpdatePriority(id,priority) return api:UpdatePriority(self.id,id,priority) end
        function handle:Cancel(id,why) return api:Cancel(self.id,id,why) end
        function handle:CancelOwner(owner,why) return api:CancelOwner(self.id,owner,why) end
        function handle:CancelSequence(id,why) return api:CancelSequence(self.id,id,why) end
        function handle:GetSequence(id) return api:GetSequence(self.id,id) end
        function handle:Observe(id,evidence) return api:Observe(self.id,id,evidence) end
        function handle:ClaimAutomation(name) return api:ClaimAutomation(self.id,name) end
        function handle:ReleaseAutomation(name) return api:ReleaseAutomation(self.id,name) end
        function handle:Close(why) return api:CloseScope(self.id,why) end
        return handle
    end
    function api:ClaimAutomation(scope,name)
        local s=self.scopes[scope]
        if not s or s.closed then return false,'scope_closed' end
        if self.automationEpoch[name]==nil then return false,'unsupported_automation' end
        if self.automation[name] and self.automation[name]~=scope then return false,'already_claimed' end
        if self.automation[name]~=scope then
            self.automationEpoch[name]=self.automationEpoch[name]+1;self.automation[name]=scope
        end
        return true
    end
    function api:ReleaseAutomation(scope,name)
        if self.automation[name]~=scope then return false,'not_owner' end
        self.automation[name]=nil;self.automationEpoch[name]=self.automationEpoch[name]+1;return true
    end
    function api:GetAutomation(name)
        if self.automationEpoch[name]==nil then return nil,'unsupported_automation' end
        return {scope=self.automation[name],epoch=self.automationEpoch[name],builtin=self.automation[name]==nil}
    end
    function api:AllowsBuiltin(name,epoch)
        return self.automationEpoch[name]~=nil and self.automation[name]==nil
            and (epoch==nil or epoch==self.automationEpoch[name])
    end
    input.Automation=api
    function api:ResumeUnsentMotion(r)
        local a=r and self.actions[r.id];local s=a and self.scopes[a.scope]
        -- Resume only a cursor preparation, never a possibly delivered input.
        -- Each retry retains the original identity/deadline and resolves again.
        if not a or not s or s.closed or a.cancelled or a.type~='cast' or a.dependency or a.handoff or a.sequence
            or r.sentAt or r.submissionFailed or r.keyLease or r.followup or input.Active
            or input.PendingReturn or not r.returnObservedAt or not input:Available()
            or (r.motionResumes or 0)>=2 or clock()+input.env.fallback()>=r.expires then return false end
        for _,owner in pairs(input.KeysOwned) do if owner==r.owner then return false end end
        for _,pending in pairs(input.PendingUp) do if pending.owner==r.owner then return false end end
        for _,button in pairs(input.Buttons) do if button.owner==r.owner then return false end end
        local queued=false;for _,q in ipairs(self.queue) do if q==a then queued=true;break end end
        if not queued and (s.waiting>=32 or #self.queue>=128) then return false end
        r.motionResumes=(r.motionResumes or 0)+1
        r.generation=input.Generation;r.state='requested';r.reason=nil;r.abortedAt=nil;r.interrupted=nil;r.manualAt=nil
        r.rootAt=nil;r.budgetEnd=nil;r.returnTarget=nil;r.predecessorID=nil;r.chainDepth=0
        r.preparedPosition=nil;r.preparedAt=nil;r.acquiredAt=nil;r.actionScreen=nil;r.awaitingPosition=nil
        r.positionPasses=nil;r.resolvedPass=nil;r.confirmAfterPass=nil;r.nativePlacementConfirmedAt=nil
        r.sendAfter=nil;r.releasedAt=nil;r.returnRequestedAt=nil;r.returnObservedAt=nil;r.returnRetried=nil
        a.dispatched=false;a.waiting=true
        if not queued then self.queue[#self.queue+1]=a;s.waiting=s.waiting+1 end
        input:record('waiting_resumed',r,'Unsent preparation interrupted; fresh validation before reacquisition')
        return true
    end
    function api:SetPriorityLimit(scope,priority)
        local s=self.scopes[scope];if not s or not rank[priority] then return false,'invalid_priority' end
        s.cap=priority;s.readLimit=nil;return true
    end
    -- Priority-only escalation preserves identity, validators, deadlines and descendants.
    function api:UpdatePriority(scope,id,priority)
        if input.Resolving then return false,'resolver_side_effect' end
        local s=self.scopes[scope];local a=self.actions[id]
        if not s or s.closed then return false,'scope_closed' end
        if not a or a.scope~=scope then return false,'unknown_action' end
        if not rank[priority] or not s.classes[priority] then return false,'priority_not_declared' end
        local r=a.record
        if a.cancelled or not a.waiting or r.sentAt or r.state=='aborted' or clock()>=r.expires then return false,'not_waiting' end
        if rank[priority]<rank[a.priority] then return false,'priority_downgrade' end
        a.priority=priority;r.priorityClass=priority
        a.effective=math.min(rank[priority],s.readLimit and s.readLimit() or rank[s.cap])
        return true
    end
    function api:GetScopes()
        local out={};for id,s in pairs(self.scopes) do if not s.closed then
            out[#out+1]={id=id,name=s.name,limit=s.cap,waiting=s.waiting}
        end end;table.sort(out,function(a,b)return a.id<b.id end);return out
    end
    local function actionCleanupPending(r)
        if input.Active==r or input.PendingReturn==r then return true end
        for _,owner in pairs(input.KeysOwned or {})do if owner==r.owner then return true end end
        for _,pending in pairs(input.PendingUp or {})do if pending.owner==r.owner then return true end end
        for _,button in pairs(input.Buttons or {})do if button.action==r or button.owner==r.owner then return true end end
        return false
    end
    function api:GetAction(scope,id)
        local a=self.actions[id];if not a or a.scope~=scope then return nil,'unknown_action' end
        local r=a.record
        return {id=id,owner=a.owner,state=state(a),priority=a.priority,requestedAt=r.requestedAt,
            waitingAt=a.waitingAt,sentAt=r.sentAt,sendCompletedAt=r.sendCompletedAt,
            cleanupPending=actionCleanupPending(r),releasedAt=r.releasedAt,returnRequestedAt=r.returnRequestedAt,returnObservedAt=r.returnObservedAt,holdUntil=r.holdUntil,
            cancelledAt=r.abortedAt,reason=r.reason,jobCancelled=a.cancelled==true,
            jobCancelledAt=a.cancelledAt,cancellationReason=a.cancellationReason,
            descendantsCancelledAt=a.descendantsCancelledAt,descendantsCancellationReason=a.descendantsCancellationReason,interrupted=r.interrupted,competitor=r.competitor,
            resolution=input.ResolutionSnapshot and input:ResolutionSnapshot(r),positionPasses=r.positionPasses,aim=copy(r.aim),retryAfter=r.retryAfter,positionedAt=r.positionedAt,acquiredAt=r.acquiredAt,
            commandReceipt=a.type=='cast' and not r.submissionFailed and copy(r.commandReceipt) or nil,
            interferenceID=r.interferenceID,interferenceAt=r.interferenceAt,interferenceCause=r.interferenceCause,
            generation=r.generation,mechanical=copy(a.mechanical),effect=copy(a.effect),
            handoffStatus=r.handoffStatus,keyLease=r.keyLease,inputSession=input.SessionID}
    end
    local function abort(a,why)
        local r=a.record
        if not r.sentAt and r.state~='aborted' then r.state='aborted';r.abortedAt=clock();r.reason=why;input:record('aborted',r,why) end
        a.cancelled=true;a.cancelledAt=a.cancelledAt or clock();a.cancellationReason=a.cancellationReason or why
    end
    function api:Cancel(scope,id,why)
        local a=self.actions[id];if not a or a.scope~=scope then return false,'unknown_action' end
        abort(a,why or 'cancelled')
        a.descendantsCancelledAt=a.descendantsCancelledAt or clock()
        a.descendantsCancellationReason=a.descendantsCancellationReason or why or 'cancelled'
        local r=a.record
        if input.Active and input.Active.followup==r then input.Active.followup=nil end
        if input.Active==r and not r.sentAt then input:release(why or 'cancelled') end
        -- A sent command keeps its stabilization phase. Only unsent descendants stop.
        for _,b in pairs(self.actions) do if b.scope==scope and b.dependency==id then self:Cancel(scope,b.record.id,why) end end
        return true,r.sentAt and 'already_sent' or 'cancelled_before_send'
    end
    function api:CancelOwner(scope,owner,why)
        for id,a in pairs(self.actions) do if a.scope==scope and a.owner==owner then self:Cancel(scope,id,why) end end
        local token='community:'..scope..':'..tostring(owner)
        for key,who in pairs(input.KeysOwned) do if who==token then input:ReleaseKey(key,who,nil,nil,true) end end
        input:CleanupButtons(false,token)
        return true
    end
    function api:CloseScope(scope,why)
        local s=self.scopes[scope];if not s then return false,'unknown_scope' end
        if s.closed then return true end;s.closed=true
        for name,owner in pairs(self.automation) do if owner==scope then self:ReleaseAutomation(scope,name) end end
        for id in pairs(self.sequences) do self:CancelSequence(scope,id,why or 'scope_closed') end
        for id,a in pairs(self.actions) do if a.scope==scope then self:Cancel(scope,id,why or 'scope_closed') end end
        local prefix='community:'..scope..':'
        for key,who in pairs(input.KeysOwned) do if who:sub(1,#prefix)==prefix then input:ReleaseKey(key,who,nil,nil,true) end end
        for _,row in pairs(input.Buttons) do if row.owner:sub(1,#prefix)==prefix then input:CleanupButtons(false,row.owner) end end
        self:Prune();return true
    end
    function api:Prune()
        for i=#self.queue,1,-1 do
            local a=self.queue[i];local why=reason(a.record)
            if why then abort(a,why) end
            if a.cancelled or a.record.state=='aborted' or a.dispatched then
                if input.Active and input.Active.followup==a.record and (a.cancelled or a.record.state=='aborted') then
                    input.Active.followup=nil
                end
                a.waiting=false;self.scopes[a.scope].waiting=self.scopes[a.scope].waiting-1;table.remove(self.queue,i)
            end
        end
        -- Keep pending and actively held records; bound completed public history.
        while #self.history>256 do
            local removed=false
            for i,id in ipairs(self.history) do local a=self.actions[id]
                if a and not a.waiting and input.Active~=a.record and not a.sequence and not a.releaseDeadline then
                    self.actions[id]=nil;table.remove(self.history,i);removed=true;break
                end
            end
            if not removed then break end
        end
    end
    function api:Request(scope,q)
        if input.Resolving then return nil,"resolver_side_effect" end
        local s=self.scopes[scope];if not s or s.closed then return nil,'scope_closed' end
        if type(q)~='table' then return nil,'invalid_request' end
        if q.owner~=nil and (type(q.owner)~='string' or #q.owner>64) then return nil,'invalid_owner' end
        local p=q.priority or 'normal'
        if not rank[p] or not s.classes[p] then return nil,'priority_not_declared' end
        if not finite(q.expires) or q.expires<clock() then return nil,'expired' end
        if type(q.validate)~='function' then return nil,'validation_required' end
        local types={cast=true,attack=true,move=true,click=true,hover=true,key=true,chord=true,key_down=true,key_up=true}
        if not types[q.type] then return nil,'invalid_type' end
        if q.type=='attack' and (q.targetKind~='object' or not input.env.executeAttack) then return nil,'attack_unavailable' end
        if q.approach~=nil and (type(q.approach)~='boolean' or q.type~='attack') then return nil,'invalid_attack_approach' end
        if q.approach and not input.env.executeApproach then return nil,'attack_approach_unavailable' end
        if q.survivePointerMotion~=nil and (type(q.survivePointerMotion)~='boolean'
            or q.type~='cast' or q.dependency or q.handoff or q.targetKind~='world' and q.targetKind~='object' and q.targetKind~='none') then
            return nil,'invalid_pointer_motion_policy'
        end
        if q.surviveMovementCommands~=nil and (type(q.surviveMovementCommands)~='boolean'
            or q.type~='cast' or q.dependency or q.handoff or q.targetKind=='screen') then
            return nil,'invalid_movement_command_policy'
        end
        if q.targetKind~='none' and q.targetKind~='object' and q.targetKind~='world' and q.targetKind~='screen' then return nil,'invalid_target_kind' end
        local t=q.target
        if q.targetKind=='object' and (not t or not t.pos or not (t.networkID or t.handle)) then return nil,'invalid_target' end
        if q.targetKind=='world' and (not t or not finite(t.x) or not finite(t.z) or t.pos) then return nil,'invalid_target' end
        if q.targetKind=='screen' and (not t or not finite(t.x) or not finite(t.y) or t.z~=nil or t.pos) then return nil,'invalid_target' end
        if q.targetKind=='none' and t~=nil then return nil,'invalid_target' end
        if (q.type=='hover' or q.type=='move' or q.type=='click') and not t then return nil,'target_required' end
        local keys=q.keys or {};if type(keys)~='table' then keys={keys} end
        if #keys>8 then return nil,'too_many_keys' end
        for _,key in ipairs(keys) do if not finite(key) or key%1~=0 or key<=0 then return nil,'invalid_key' end end
        if (q.type=='key' or q.type=='cast' or q.type=='chord' or q.type=='key_down' or q.type=='key_up') and #keys==0 then return nil,'key_required' end
        if q.type=='chord' and #keys~=2 then return nil,'invalid_chord' end
        if q.dependency then local d=self.actions[q.dependency];if not d or d.scope~=scope then return nil,'invalid_dependency' end end
        if q.dependencyState and q.dependencyState~='sent' and q.dependencyState~='mechanical' and q.dependencyState~='effect' then return nil,'invalid_dependency_state' end
        if q.resolveWorldTarget~=nil and (type(q.resolveWorldTarget)~='function' or q.type~='cast' or q.targetKind~='world' or q.world or q.handoff) then return nil,'invalid_world_resolver' end
        if q.prevalidateWorldCast~=nil and (type(q.prevalidateWorldCast)~='boolean'
            or q.prevalidateWorldCast and (not q.resolveWorldTarget or #keys~=1 or q.verifyTarget
                or q.aimCandidates or q.dependency or q.handoff)) then return nil,'invalid_prevalidated_cast' end
        if q.commitGuard~=nil and (not q.prevalidateWorldCast or type(q.commitGuard)~='function') then return nil,'invalid_commit_guard' end
        if q.ready and type(q.ready)~='function' then return nil,'invalid_condition' end
        if q.aimCandidates and (type(q.aimCandidates)~='function' or q.targetKind~='object') then return nil,'invalid_aim_candidates' end
        if q.aimFallback and (type(q.aimFallback)~='function' or not q.aimCandidates) then return nil,'invalid_aim_fallback' end
        if q.retryKey and (type(q.retryKey)~='string' or #q.retryKey>128) then return nil,'invalid_retry_key' end
        self:Prune();if s.waiting>=32 or #self.queue>=128 then return nil,'queue_full' end
        local owner='community:'..scope..':'..tostring(q.owner or 'default')
        local r=input:newAction{owner=owner,keys=q.type=='move' and input.env.moveKey or keys,target=t,
            validate=q.validate,verifyTarget=q.verifyTarget or q.aimCandidates and t,aimCandidates=q.aimCandidates,aimFallback=q.aimFallback,expires=q.expires,world=q.world,
            leftClicks=q.type=='click' and (q.count or 1) or nil,class=q.type=='move' and 'move' or q.type=='hover' and 'hover' or 'cast',critical=q.type~='move'}
        local a={scope=scope,owner=q.owner or 'default',record=r,priority=p,type=q.type,
            dependency=q.dependency,dependencyState=q.dependencyState or 'sent',ready=q.ready,
            handoff=q.handoff==true,waiting=true,waitingAt=clock()}
        if q.retryKey then
            a.retryKey=q.retryKey
            r.onAimFailure=function(record)
                local untilAt=clock()+50;record.retryAfter=untilAt
                for key,row in pairs(s.retries) do if row<=clock() then s.retries[key]=nil end end
                local count=0;for _ in pairs(s.retries) do count=count+1 end
                if count>=128 then local oldest,key=math.huge,nil;for k,v in pairs(s.retries) do if v<oldest then oldest,key=v,k end end;s.retries[key]=nil end
                s.retries[q.retryKey]=untilAt
            end
        end
        r.resolveWorldTarget=q.resolveWorldTarget;r.intentTargetID=q.intentTargetID
        r.prevalidateWorldCast=q.prevalidateWorldCast==true;r.commitGuard=q.commitGuard
        r.publicScope=scope;r.priorityClass=p;r.publicType=q.type;r.approach=q.approach==true
        r.surviveMovementCommands=q.surviveMovementCommands==true
        r.survivePointerMotion=q.survivePointerMotion==true or r.surviveMovementCommands
        self.actions[r.id]=a;self.history[#self.history+1]=r.id;self.queue[#self.queue+1]=a;s.waiting=s.waiting+1
        input:record('waiting',r,nil,{apiVersion=1,targetKind=q.targetKind,expires=r.expires})
        self:Pump();return r.id,state(a)
    end
    function api:Observe(scope,id,evidence)
        local a=self.actions[id]
        if not a or a.scope~=scope or not a.record.sentAt then return false,'not_sent' end
        if type(evidence)~='table' or (evidence.kind~='mechanical' and evidence.kind~='effect')
            or type(evidence.source)~='string' or evidence.unique~=true or not finite(evidence.at)
            or evidence.at<a.record.sentAt or evidence.at>clock() then return false,'invalid_evidence' end
        if evidence.attribution=='command_key' then
            local receipt=a.record.commandReceipt
            if evidence.kind~='mechanical' or a.type~='cast' or a.record.submissionFailed or not receipt
                or evidence.key~=receipt.key or evidence.generation~=receipt.generation
                or evidence.session~=receipt.session or clock()>receipt.expiresAt
                or input:CommandGeneration(receipt.key)~=receipt.generation then
                return false,'ambiguous_command'
            end
        elseif evidence.attribution~=nil then return false,'unsupported_attribution'
        elseif a.record.interrupted or a.record.competitor then return false,'ambiguous' end
        a[evidence.kind]={at=evidence.at,source=evidence.source,result=evidence.result or 'observed',attribution=evidence.attribution}
        input:record(evidence.kind..'_observed',a.record,evidence.source,{evidenceAt=evidence.at,evidenceResult=evidence.result})
        -- Plugin assertions never validate a timing source. Mechanical != impact.
        return true
    end
    function api:DependencyReady(a)
        if not a.dependency then return true end
        local d=self.actions[a.dependency]
        if not d or d.cancelled or d.record.state=='aborted' then abort(a,'dependency_cancelled');return false end
        if a.dependencyState=='sent' then return d.record.sentAt~=nil and not d.record.submissionFailed end
        return d[a.dependencyState]~=nil
    end
    local function deferHandoff(previous,why)
        local r=previous.followup;previous.followup=nil
        -- Keep the queued request and its logical dependency, but discard the
        -- reservation. A later dispatch samples the player and projects afresh.
        r.rootAt=nil;r.budgetEnd=nil;r.returnTarget=nil;r.predecessorID=nil
        r.chainDepth=0;r.preparedPosition=nil;r.handoffStatus=why
        input:record('handoff_deferred',r,why)
        if clock()>=(previous.holdUntil or math.huge) then input:release(why) end
    end
    function api:Pump(minimum)
        if self.pumping or input.Resolving then return end;self.pumping=true
        input.ResolutionPass=(input.ResolutionPass or 0)+1
        local ok,err=pcall(function()
            self:Prune()
            if not input:Available() or input.Uncertain then return end
            local candidates={}
            for _,a in ipairs(self.queue) do
                local s=self.scopes[a.scope]
                local limit=s.readLimit and s.readLimit() or rank[s.cap]
                a.effective=math.min(rank[a.priority],limit)
                local ready=true
                if a.ready then local yes,value=pcall(a.ready);ready=yes and value==true;if not yes then abort(a,'condition_error') end end
                local dependency=not a.cancelled and self:DependencyReady(a)
                local retry=a.retryKey and s.retries[a.retryKey]
                local retryBlocked=retry and clock()<retry
                if retryBlocked and a.record.verifyTarget then
                    if input:VerifyHover(a.record) then s.retries[a.retryKey]=nil;retryBlocked=false end
                end
                a.record.retryAfter=retryBlocked and retry or a.record.retryAfter
                local blocked=input:InputsBlocked(a.record) or retryBlocked
                local previous=input.Active
                if previous and previous.followup==a.record
                    and (not ready or not dependency or blocked) then
                    deferHandoff(previous,'waiting without cursor reservation')
                end
                if not a.cancelled and ready and dependency and not blocked and a.effective>=(minimum or 1) then a.selectionLast=s.last;candidates[#candidates+1]=a end
            end
            local function pollPrepared()
                local r=input.Active;local running=r and self.actions[r.id]
                if running and r.awaitingPosition and (running.effective or rank[running.priority])>=(minimum or 1) then
                    input:PollPlacement(r)
                end
            end
            if #candidates==0 then pollPrepared();return end
            while #candidates>0 do
            local a,index=selectCandidate(candidates)
            candidates[index]=candidates[#candidates];candidates[#candidates]=nil
            local r=a.record;local previous=input.Active
            if previous and previous.followup==r and clock()<(previous.holdUntil or 0) then return end
            local chain=previous and a.type~='move' and a.handoff and a.dependency==previous.id and previous.owner==r.owner
                and (not previous.followup or previous.followup==r) and (previous.chainDepth or 0)<1
            if previous and not chain then
                if previous.followup and clock()>=(previous.holdUntil or math.huge) then
                    -- Prepared work is still queued. Return the predecessor safely
                    -- before admitting a higher ranked independent action.
                    deferHandoff(previous,'yielded to priority')
                    return
                end
                local running=self.actions[previous.id]
                if not previous.sentAt and a.effective>(running and running.effective or 2) then
                    input:release('preempted before send');if running then abort(running,'preempted') end
                else pollPrepared() end
                return
            end
            if not chain and input.Step>0 then return end
            if clock()<input.NotBefore and not chain then return end
            if input:InputsBlocked(r) then return end
            if chain then
                r.returnTarget=copy(previous.returnTarget or previous.playerScreen);r.rootAt=previous.rootAt
                r.budgetEnd=previous.budgetEnd;r.predecessorID=previous.id;r.chainDepth=(previous.chainDepth or 0)+1
            end
            self.turn=self.turn+1;self.scopes[a.scope].last=self.turn;a.dispatched=true
            local worked,result=pcall(function()
                if a.type=='attack' then
                    if r.approach then return input.env.executeApproach(r) end
                    return input.env.executeAttack(r)
                end
                if a.type=='key_down' or a.type=='key_up' or a.type=='chord' then
                    if not input:valid(r) then return false end
                    local sent
                    if a.type=='key_down' then
                        sent=input:AcquireKey(r.keys[1],r.owner,r)
                        if sent then a.releaseDeadline=math.min(r.expires,clock()+500) end
                    elseif a.type=='key_up' then sent=input:ReleaseKey(r.keys[1],r.owner,r)
                    else
                        sent=input:AcquireKey(r.keys[1],r.owner,r)
                        if sent then sent=input:PulseKeys(r.keys[2],r.owner,r) end
                        if not input:ReleaseKey(r.keys[1],r.owner,r) then sent=false end
                    end
                    r.releasedAt=clock();return sent
                end
                return input:dispatch(r,chain and previous or nil)
            end)
            if previous and previous.followup==r and not r.sentAt then a.dispatched=false end
            if not worked or not result then
                if r.sentAt then r.submissionFailed=true;r.reason=worked and 'send_uncertain' or tostring(result)
                else abort(a,worked and (r.reason or 'validation_declined') or 'host_exception') end
                if not worked and input.Active==r then input:release('host_exception') end
            end
            self:Prune()
            if r.sentAt or input.Active or input.Step>0 then return end
            end
        end)
        self.pumping=false;if not ok then error(err,0) end
    end
    function api:Sequence(scope,steps,options)
        local s=self.scopes[scope];if not s or s.closed then return nil,'scope_closed' end
        if type(steps)~='table' or #steps==0 or #steps>32 then return nil,'invalid_sequence' end
        local count=0;for _,seq in pairs(self.sequences) do if seq.scope==scope and not seq.done then count=count+1 end end
        if count>=32 then return nil,'sequence_limit' end
        local frozen={}
        for i,step in ipairs(steps) do
            if type(step)~='table' then return nil,'invalid_sequence' end
            local row={};for k,v in pairs(step) do row[k]=v end
            if type(row.keys)=='table' then row.keys=copy(row.keys) end
            if row.targetKind~='object' and row.target then row.target=copy(row.target) end
            frozen[i]=row
        end
        self.serial=self.serial+1;local seq={id=self.serial,scope=scope,steps=frozen,index=0,ids={},generation=input.Generation}
        self.sequences[seq.id]=seq;self:Advance(seq);return seq.id
    end
    function api:Advance(seq)
        if seq.done then return end
        if seq.generation~=input.Generation then self:CancelSequence(seq.scope,seq.id,'interrupted');return end
        local prior=seq.ids[seq.index];local a=prior and self.actions[prior]
        if a and (a.cancelled or a.record.state=='aborted' or a.record.submissionFailed) then self:CancelSequence(seq.scope,seq.id,'dependency_failed');return end
        if a and not a.record.sentAt then return end
        if seq.index==#seq.steps then
            seq.done=true;for _,id in ipairs(seq.ids) do if self.actions[id] then self.actions[id].sequence=nil end end
            return
        end
        local step=seq.steps[seq.index+1];local q={};for k,v in pairs(step) do q[k]=v end
        q.dependency=prior or q.dependency
        local id,why=self:Request(seq.scope,q)
        if not id then self:CancelSequence(seq.scope,seq.id,why);return end
        seq.index=seq.index+1;seq.ids[seq.index]=id;self.actions[id].sequence=seq.id
    end
    function api:GetSequence(scope,id)
        local seq=self.sequences[id];if not seq or seq.scope~=scope then return nil,'unknown_sequence' end
        return {id=id,actions=copy(seq.ids),done=seq.done==true,cancelled=seq.cancelled==true,reason=seq.reason}
    end
    function api:CancelSequence(scope,id,why)
        local seq=self.sequences[id];if not seq or seq.scope~=scope then return false,'unknown_sequence' end
        seq.done=true;seq.cancelled=true;seq.reason=why or 'cancelled'
        for _,aid in ipairs(seq.ids) do self:Cancel(scope,aid,seq.reason);if self.actions[aid] then self.actions[aid].sequence=nil end end
        return true
    end
    function api:Tick(minimum)
        -- With no admitted or historical work, there is nothing to prune,
        -- release, advance or dispatch. Keep this path independent of owner
        -- names and modes; the next Request resumes the ordinary lifecycle.
        if not next(self.actions) and not next(self.sequences) and #self.queue==0 then return end
        for _,a in pairs(self.actions) do
            if a.releaseDeadline and (not input.KeyLeases or input.KeyLeases[a.record.keys[1]]~=a.record.keyLease
                or clock()>=a.releaseDeadline) then
                input:ReleaseKey(a.record.keys[1],a.record.owner,nil,a.record.keyLease);a.releaseDeadline=nil
            end
        end
        for _,seq in pairs(self.sequences) do self:Advance(seq) end
        for id,seq in pairs(self.sequences) do if seq.done and id<self.serial-256 then self.sequences[id]=nil end end
        self:Pump(minimum)
    end
    return api
end

end)()(Cursor,GetTickCount,(function()
-- Select the same total order as the historical full sort. Fairness is captured
-- when candidates become executable, before any dispatch updates scope.last.
return function(candidates)
    local best,index
    for i,a in ipairs(candidates)do
        local b=best
        if not b or a.effective>b.effective or a.effective==b.effective and (
            a.record.expires<b.record.expires or a.record.expires==b.record.expires and (
                a.selectionLast<b.selectionLast or a.selectionLast==b.selectionLast and a.record.id<b.record.id)) then
            best,index=a,i
        end
    end
    return best,index
end

end)())
SDK.OnUrgent={}
if ({}).enabled then
    SDK.Performance:Wrap(SDK.SharedData,"Prepare","shared_data")
    SDK.Performance:Wrap(SDK.Actions,"Pump","scheduler")
end
SDK.Actions.onRegister=function(scope)
    local parent=Menu.Main.Plugins
    local args={id=scope.name,name=scope.name,type=MENU}
    if not parent[scope.name] then parent:MenuElement(args) end;local group=parent[scope.name]
    group:MenuElement({id="Limit",name="Priority limit",value=parent.DefaultLimit:Value(),drop={"Background","Normal","Interactive","Critical"}})
    scope.readLimit=function()return math.max(1,math.min(4,group.Limit:Value()))end
end
local createActionClient=(function()
-- GENERATED by build_action_client.py; Actions client v1
local transports={}
transports["gg"]=(function()
-- Only this client's unsubmitted work is scheduled here. No private GG writes.
return function(g,sdk,active,options)
    assert(not sdk.OrbamaVersion,'Original GG required')
    local A={falseIsRejection=options.ggFalseIsRejection~=false,name='OriginalGG',queue={},records={},serial=0,history={},caps={
        surviveMovementCommands=false,resolveWorldTarget=false,automationClaims=false,
        cancelSubmitted=false,observedExecution=false,privateQueue=true,updatePriority=true}}
    sdk.ActionClientGG=sdk.ActionClientGG or {};local providers=sdk.ActionClientGG;providers[#providers+1]=A
    local rank={critical=4,interactive=3,normal=2,background=1}
    local last=g.GetTickCount();local now=last
    function A:Now()
        local value=g.GetTickCount();local delta=value-last
        if delta< -2147483648 then delta=delta+4294967296 end
        last=value;now=now+math.max(0,delta);return now
    end
    function A:Capabilities() return self.caps end
    function A:Available() return not sdk.Cursor or sdk.Cursor.Step==0 end
    function A:Submit(q)
        for _,name in ipairs({'verifyTarget','aimCandidates','aimFallback','retryKey','world','count','approach','handoff','survivePointerMotion'})do
            if q[name]~=nil and q[name]~=false then return nil,'GG_unsupported_option:'..name end
        end
        if q.type~='cast' and q.type~='attack' and q.type~='move' then return nil,'GG_unsupported_type' end
        if q.type=='cast' and #q.keys~=1 then return nil,'GG_chord_unavailable' end
        local count=0;for _,r in pairs(self.records)do if not r.acknowledged then count=count+1 end end
        if not active() or count>=128 then return nil,'inactive_or_unconsumed_results_full' end
        self.serial=self.serial+1;local id=self.serial
        sdk.ActionClientGGOrder=(sdk.ActionClientGGOrder or 0)+1
        self.records[id]={order=sdk.ActionClientGGOrder,provider=self,active=active,id=id,state='waiting',requestedAt=self:Now(),intent=q}
        self.queue[#self.queue+1]=id;return id,'waiting'
    end
    local function snapshot(t)if not t then return nil end;local o={};for k,v in pairs(t)do o[k]=v end;return o end
    function A:Poll(id)
        local r=self.records[id];if not r then return nil end
        return {id=id,state=r.state,priority=r.intent and r.intent.priority or r.priority,requestedAt=r.requestedAt,attemptedAt=r.attemptedAt,
            sentAt=r.sentAt,handedAt=r.sentAt,reason=r.reason,jobCancelled=r.cancelled,
            mechanical=snapshot(r.mechanical),effect=snapshot(r.effect),reconciled=r.reconciled}
    end
    function A:UpdatePriority(id,priority)
        local r=self.records[id]
        if not active() or not r or r.state~='waiting' or r.cancelled or r.attemptedAt or self:Now()>=r.intent.expires then return false,'not_waiting' end
        if not rank[priority] then return false,'invalid_priority' end
        if rank[priority]<rank[r.intent.priority] then return false,'priority_downgrade' end
        r.intent.priority=priority;return true
    end
    function A:Acknowledge(id,reconciled)
        local r=self.records[id];if not r or r.state=='waiting' then return false end
        if r.sentAt and not r.mechanical and not reconciled then return false,'reconciliation_required' end
        if r.acknowledged then return true end
        r.priority=r.intent and r.intent.priority;r.acknowledged=true;r.reconciled=reconciled;r.intent=nil;r.active=nil;r.provider=nil -- release all gameplay closures
        for i=#self.queue,1,-1 do if self.queue[i]==id then table.remove(self.queue,i)end end
        self.history[#self.history+1]=id
        while #self.history>128 do self.records[table.remove(self.history,1)]=nil end
        return true
    end
    function A:Cancel(id,why)
        local r=self.records[id];if not r then return false end
        r.cancelled=true;r.reason=why or 'cancelled'
        if r.sentAt then return true,'already_handed_to_GG' end
        r.state='cancelled_before_send';return true
    end
    function A:Tick()
        for i=#providers,1,-1 do
            local p=providers[i];local live=false;for _,r in pairs(p.records)do if not r.acknowledged then live=true;break end end
            if p.closed and not live then table.remove(providers,i)end
        end
        local now=self:Now();local candidates={}
        for _,provider in ipairs(providers)do
        local self=provider
        for i=#self.queue,1,-1 do
            local id=self.queue[i];local r=self.records[id];local q=r and r.intent
            if not r or r.state~='waiting' then table.remove(self.queue,i)
            else
                if now>=q.expires or not r.active() then self:Cancel(id,'expired_or_inactive')
                else
                    local blocked=false
                    for _,key in ipairs(q.keys or {})do if g.Control.IsKeyDown(key)then blocked=true end end
                    if not blocked then candidates[#candidates+1]=r end
                end
            end
        end
        end
        table.sort(candidates,function(a,b)
            local x,y=a.intent,b.intent
            if rank[x.priority]~=rank[y.priority]then return rank[x.priority]>rank[y.priority]end
            if x.expires~=y.expires then return x.expires<y.expires end
            if a.requestedAt~=b.requestedAt then return a.requestedAt<b.requestedAt end
            return a.order<b.order
        end)
        if not self:Available()then return end
        for _,r in ipairs(candidates)do
            local self=r.provider
            if not self:Available()then return end
            local q=r.intent;local resolved
            local ok,valid,reason=pcall(function()
                if q.resolve then resolved=q.resolve({id=r.id,now=now,expires=q.expires});if not resolved then return false,'resolution_declined' end end
                return q.mechanical(resolved)
            end)
            if not ok or not valid then
                if reason~='dependency_waiting' and reason~='not_ready' then self:Cancel(r.id,reason or 'validation_declined')end
            else
                if not r.active()then self:Cancel(r.id,'inactive');return end
                local target=resolved and resolved.position or q.target
                if q.type~='move' and q.type~='attack' and #q.keys~=1 then self:Cancel(r.id,'GG_chord_unavailable')
                else
                    r.attemptedAt=now;self.sending=true
                    local accepted,result
                    if q.type=='move' then accepted,result=pcall(g.Control.Move,target)
                    elseif q.type=='attack' then accepted,result=pcall(g.Control.Attack,target)
                    else accepted,result=pcall(g.Control.CastSpell,q.keys[1],target)end
                    self.sending=false
                    -- The pinned GG CastSpell/Attack false return is a no-send contract.
                    -- Unknown wrappers must opt out; exceptions/nil/Move(false) remain uncertain.
                    if accepted and result==false and q.type~='move' and self.falseIsRejection then
                        r.state='cancelled_before_send';r.reason='GG_rejected_before_send'
                    else
                        r.sentAt=now;r.state=accepted and result==true and 'sent' or 'send_uncertain'
                        r.reason=accepted and (result==true and 'GG_handoff_accepted' or 'GG_handoff_unknown') or 'GG_handoff_exception'
                    end
                    if r.sentAt then return end
                end
            end
        end
    end
    function A:Claim()return false,'original_GG_has_no_claim_API'end
    function A:Observe(id,evidence)
        local r=self.records[id]
        if not r or not r.sentAt or r.state~='sent' or type(evidence)~='table' or evidence.unique~=true then return false end
        if type(evidence.at)~='number' or evidence.at~=evidence.at or evidence.at<r.sentAt or evidence.at>self:Now() then return false end
        if evidence.kind~='mechanical' and evidence.kind~='effect' then return false end
        r[evidence.kind]={at=evidence.at,source=evidence.source,result=evidence.result};return true
    end
    function A:Close(why)self.closed=true;for id in pairs(self.records)do self:Cancel(id,why)end end
    return A
end

end)()
transports["orbama"]=(function()
return function(g, sdk, active, options)
    local api=assert(sdk.Actions,'Orbama Actions API required')
    assert(api.version==1,'Unsupported Actions contract')
    local capabilities=api:GetCapabilities()
    local scope=assert(api:RegisterScope(options.name,{priorities={'critical','interactive','normal','background'}}))
    -- Only capabilities exposed by this facade, not unrelated raw-scope methods.
    local clientCaps={surviveMovementCommands=capabilities.surviveMovementCommands,
        survivePointerMotion=capabilities.survivePointerMotion,resolveWorldTarget=capabilities.resolveWorldTarget,
        automationClaims=capabilities.automationClaims,automationFunctions=capabilities.automationFunctions,
        actionCleanupState=capabilities.actionCleanupState,aimCandidates=capabilities.aimCandidates,
        aimFallback=capabilities.aimFallback,maxAimCandidates=capabilities.maxAimCandidates,
        retryKeys=capabilities.retryKeys,attackApproach=capabilities.attackApproach,
        keyedMechanicalObservation=capabilities.keyedMechanicalObservation,observations=capabilities.observations,updatePriority=capabilities.updatePriority}
    local A={name='Orbama',scope=scope,capabilities=clientCaps}
    function A:Capabilities() return self.capabilities end
    function A:Now() return api:Now() end
    function A:Submit(intent)
        if not active() then return nil,'inactive_instance' end
        local q={type=intent.type or 'cast',keys=intent.keys,target=intent.target,targetKind=intent.kind,
            owner=intent.owner,priority=intent.priority,expires=intent.expires,intentTargetID=intent.targetID,
            dependency=intent.dependency,dependencyState=intent.dependencyState,ready=intent.ready,handoff=intent.handoff,
            verifyTarget=intent.verifyTarget,aimCandidates=intent.aimCandidates,aimFallback=intent.aimFallback,
            retryKey=intent.retryKey,world=intent.world,count=intent.count,approach=intent.approach,
            survivePointerMotion=intent.survivePointerMotion,
            validate=function(_,resolved)if not active() then return false,'inactive_instance' end;return intent.mechanical(resolved) end}
        -- An independent resolved skillshot keeps its gameplay target while the
        -- player orbwalks. Opt into the provider's bounded correction centrally;
        -- explicit false, dependent sequences and manual point casts stay strict.
        if q.survivePointerMotion==nil and capabilities.survivePointerMotion
            and intent.independent and intent.resolve and intent.kind=='world'
            and q.type=='cast' and not intent.dependency and not intent.handoff then
            q.survivePointerMotion=true
        end
        if intent.resolve and capabilities.resolveWorldTarget then q.resolveWorldTarget=intent.resolve end
        if intent.independent and capabilities.surviveMovementCommands and q.type=='cast'
            and intent.kind~='screen' and not intent.dependency and not intent.handoff then
            q.surviveMovementCommands=true
        end
        if intent.resolve and not capabilities.resolveWorldTarget then return nil,'resolveWorldTarget_unavailable' end
        return scope:Request(q)
    end
    function A:Poll(id) return scope:GetAction(id) end
    function A:UpdatePriority(id,priority)
        if not capabilities.updatePriority then return false,'priority_update_unavailable' end
        return scope:UpdatePriority(id,priority)
    end
    function A:Cancel(id,why) return scope:Cancel(id,why) end
    function A:Acknowledge() return true end
    function A:Available() local a=api:GetAvailability();return not a.busy and not a.cleanupPending and not a.uncertain end
    function A:Settled(id)
        local r=self:Poll(id)
        if capabilities.actionCleanupState and r and r.cleanupPending~=nil then
            return r.releasedAt~=nil and not r.cleanupPending and not api:GetAvailability().uncertain
        end
        return self:Available()
    end
    function A:Tick() end -- SDK owns its scheduler.
    function A:Claim(name,on)
        if not capabilities.automationClaims then return false,'automation_claims_unavailable' end
        if on then return scope:ClaimAutomation(name) end
        return scope:ReleaseAutomation(name)
    end
    function A:Observe(id,evidence) return scope:Observe(id,evidence) end
    function A:Close(why) return scope:Close(why) end
    return A
end

end)()
local create=(function()
-- Public, provider-neutral intention client. Milliseconds throughout this module.
return function(g,transports,options)
    options=options or {};local sdk=assert(g.SDK);local active=options.active or function()return true end
    local hub=sdk.ActionClientHub
    if not hub then hub={resources={},clients={},serial=0};sdk.ActionClientHub=hub end
    hub.serial=hub.serial+1
    local C={locks={},id=hub.serial,name=options.name or 'plugin',jobs={},history={},resources={},gates={},closed=false}
    local transport=transports[sdk.OrbamaVersion and 'orbama' or 'gg'](g,sdk,function()return not C.closed and active()end,options)
    C.transport=transport;C.name=transport.name
    if not hub.hooks then
        hub.hooks=true
        for _,kind in ipairs({'attack','move'})do
            local register=kind=='attack' and 'OnPreAttack' or 'OnPreMovement'
            sdk.Orbwalker[register](sdk.Orbwalker,function(args)
                for _,client in pairs(hub.clients)do
                    if not client.closed and client:IsActive()then
                        for _,locks in pairs(client.locks)do if locks[kind]then args.Process=false;return end end
                    end
                end
            end)
        end
    end
    function C:IsActive()return active()end
    function C:SetBlocked(owner,kind,blocked)
        if self.resolving then return false,'resolver_side_effect'end

        if self.closed then return false end
        if kind~='attack' and kind~='move'then return false end
        self.locks[owner]=self.locks[owner]or {};self.locks[owner][kind]=blocked==true;return true
    end
    -- Compatibility diagnostic views: never use these to modify provider ownership.
    C.records=transport.records;C.queue=transport.queue
    local rank={critical=4,interactive=3,normal=2,background=1}
    local function call(fn,...)if not fn then return true end;local ok,a,b=pcall(fn,...);return ok and a==true,b or (not ok and 'condition_exception')end
    local function copy(t,seen,depth)
        if t==nil then return {}end
        assert(type(t)=='table','snapshot table required');seen=seen or {};depth=depth or 0
        assert(not seen[t] and depth<16,'cyclic or excessive snapshot');seen[t]=true
        local o={};local count=0
        for k,v in pairs(t)do count=count+1;assert(count<=256,'snapshot too large');o[k]=type(v)=='table' and copy(v,seen,depth+1)or v end
        seen[t]=nil;return o
    end
    local function same(a,b)
        if a.equivalence or b.equivalence then return a.equivalence~=nil and a.equivalence==b.equivalence end
        if a.type~=b.type or a.owner~=b.owner or a.targetID~=b.targetID or a.kind~=b.kind or #a.keys~=#b.keys then return false end
        for i,key in ipairs(a.keys)do if key~=b.keys[i]then return false end end
        if a.kind=='world' or a.kind=='screen' then
            return a.target and b.target and a.target.x==b.target.x and a.target.y==b.target.y and a.target.z==b.target.z
        end
        return a.target==b.target
    end
    function C:Now()return transport:Now()end
    function C:Capabilities()
        local c=copy(transport:Capabilities());c.contexts=true;c.resources=true;c.replaceUnsent=true
        c.observationTracking=true;c.boundedHistory=true;c.scopedConditions=true;c.sharedClientVersion=1
        return c
    end
    function C:Available()return transport:Available()end
    function C:IsSending()return transport.sending==true end
    function C:Condition(owner,name,condition,exceptions)
        if self.resolving then return false,'resolver_side_effect'end

        assert(type(condition)=='function');local token={owner=owner,name=name,condition=condition,exceptions=exceptions}
        self.gates[token]=true;return token
    end
    function C:ReleaseCondition(token)
        if self.resolving then return false,'resolver_side_effect'end
if self.gates[token]then self.gates[token]=nil;return true end;return false end
    function C:ContextValid(q,phase)
        if self.closed or not active() or g.myHero.dead or g.Game.IsChatOpen() or not g.Game.IsOnTop() then return false,'context_unavailable' end
        local c=q.context
        if c then
            if c.modes then local yes=false;for _,mode in ipairs(c.modes)do if sdk.Orbwalker.Modes[mode]then yes=true end end;if not yes then return false,'mode_ended' end end
            if c.held and not call(c.held)then return false,'binding_released'end
            if c.condition and not call(c.condition,q)then return false,'context_condition_ended'end
        end
        if phase~='continuation' then
        for gate in pairs(self.gates)do
            if not (q.exceptions and q.exceptions[gate.name] and gate.exceptions and gate.exceptions[q.exceptions[gate.name]]) then
                if not call(gate.condition,q)then return false,'condition:'..gate.name end
            end
        end
        end
        return true
    end
    function C:Poll(id)return transport:Poll(id)end
    function C:UpdatePriority(id,priority)
        if self.resolving then return false,'resolver_side_effect'end
        local q=self.jobs[id]
        if not q or self.closed or not active() then return false,'unknown_or_inactive_action'end
        if not rank[priority]then return false,'invalid_priority'end
        if not transport.UpdatePriority then return false,'priority_update_unavailable'end
        local ok,why=transport:UpdatePriority(id,priority)
        if ok then q.priority=priority end
        return ok,why
    end
    function C:Finish(id,reconciled)
        if self.resolving then return false,'resolver_side_effect'end

        local q=self.jobs[id];if not q then return false end
        local r=self:Poll(id);if not r or r.state=='waiting' or r.state=='requested' then return false end
        if r.sentAt and not (r.mechanical or reconciled)then return false,'reconciliation_required'end
        if r.cleanupPending or r.sentAt and not (transport.Settled and transport:Settled(id) or not transport.Settled and transport:Available())then
            q.finishRequested=true;q.finishReconciled=reconciled;return false,'cleanup_pending'
        end
        transport:Acknowledge(id,reconciled)
        if q.resource then
            local lease=hub.resources[q.resource]
            if lease and lease.client==self and lease.id==id then hub.resources[q.resource]=nil end
            if self.resources[q.resource]==q then self.resources[q.resource]=nil end
        end
        self.jobs[id]=nil
        self.history[#self.history+1]=copy(r)
        while #self.history>128 do table.remove(self.history,1)end
        return true
    end
    function C:Reconcile(id)
        if self.resolving then return false,'resolver_side_effect'end

        local q=self.jobs[id];local r=q and self:Poll(id)
        if not r then return false end
        if not r.sentAt then return r.state=='cancelled_before_send' and self:Finish(id) end
        if r.mechanical then return self:Finish(id)end
        -- Timeout is only an admission budget. Fresh caller evidence is mandatory.
        if self:Now()<(r.sentAt+math.max(750,q.reconcileAfter or 1000)) or not transport:Available() then return false end
        if not q.reconcile or not call(q.reconcile,copy(r)) then return false,'fresh_evidence_required'end
        return self:Finish(id,'fresh_resource_state; historical execution unresolved')
    end
    function C:Cancel(id,reason)
        if self.resolving then return false,'resolver_side_effect'end
        local q=self.jobs[id];if q then q.cancelled=true end
        for child,other in pairs(self.jobs)do if other.dependency==id and child~=id then self:Cancel(child,'dependency_cancelled')end end
        return transport:Cancel(id,reason)
    end
    function C:CancelOwner(owner,reason)
        if self.resolving then return false,'resolver_side_effect'end

        for id,q in pairs(self.jobs)do if q.owner==owner then self:Cancel(id,reason)end end
        for gate in pairs(self.gates)do if gate.owner==owner then self.gates[gate]=nil end end
        self.locks[owner]=nil
    end
    function C:Submit(intent)
        if self.resolving then return nil,'resolver_side_effect'end
        if self.closed or not active() then return nil,'inactive'end
        local q={};for k,v in pairs(intent)do q[k]=v end
        q.owner=q.owner or 'default';q.priority=q.priority or 'normal';q.expires=q.expires or self:Now()+250
        q.type=q.type or 'cast';q.keys=q.keys or (q.key and {q.key} or {});q.kind=q.kind or (q.target and q.target.pos and 'object' or q.target and 'world' or 'none')
        if type(q.keys)~='table'then q.keys={q.keys}end;q.keys=copy(q.keys)
        if q.kind=='world' or q.kind=='screen'then q.target=q.target and {x=q.target.x,y=q.target.y,z=q.target.z}end
        if q.world then
            if type(q.world)~='table' and type(q.world)~='userdata'then return nil,'invalid_world_point'end
            local x,z=q.world.x,q.world.z
            if type(x)~='number' or type(z)~='number' or x~=x or z~=z or math.abs(x)==math.huge or math.abs(z)==math.huge then return nil,'invalid_world_point'end
            q.world={x=x,y=q.world.y or 0,z=z}
        end
        if q.count~=nil and (q.type~='click' or type(q.count)~='number' or q.count%1~=0 or q.count<1 or q.count>8)then return nil,'invalid_click_count'end
        if q.kind=='object' and not q.targetID and q.target then q.targetID=q.target.networkID or q.target.handle end
        q.context=copy(q.context);q.exceptions=copy(q.exceptions)
        if not rank[q.priority]or q.expires<=self:Now()then return nil,'invalid_priority_or_deadline'end
        if q.dependency and not self.jobs[q.dependency]then return nil,'foreign_or_unknown_dependency'end
        for _,previous in pairs(hub.clients)do if previous.closed then previous:Collect()end end
        local lease=q.resource and hub.resources[q.resource]
        if lease then
            if lease.client~=self then return nil,'foreign_resource_conflict'end
            self:Reconcile(lease.id);lease=hub.resources[q.resource]
            if lease then
                local old=self.jobs[lease.id];local r=self:Poll(lease.id)
                local equivalent=old and same(old,q)
                local replacing=q.replace=='higher_priority' and old and rank[q.priority]>rank[old.priority]
                if equivalent and not replacing then
                    if rank[q.priority]>rank[old.priority] then
                        local ok,why=self:UpdatePriority(lease.id,q.priority)
                        if not ok then return nil,why end
                    end
                    return lease.id,'deduplicated'
                end
                if q.replace~='higher_priority' or not old or rank[q.priority]<=rank[old.priority]then return nil,'resource_reserved'end
                if not r or r.sentAt or r.state=='send_uncertain'then return nil,'resource_already_attempted'end
                -- Explicit promotion replaces only unissued work, never extends its budget.
                if equivalent then q.expires=math.min(q.expires,old.expires)end
                self:Cancel(lease.id,'replaced_by_higher_priority')
                r=self:Poll(lease.id)
                if not r or r.state~='cancelled_before_send' or r.cleanupPending or (r.acquiredAt and not r.releasedAt)then return nil,'replacement_cleanup_pending'end
                self:Finish(lease.id)
            end
        end
        local count=0;for _ in pairs(self.jobs)do count=count+1 end;if count>=128 then return nil,'unconsumed_results_full'end
        if q.resolve then
            local resolver=q.resolve
            q.resolve=function(context)
                self.resolving=true;local ok,result,why=pcall(resolver,context);self.resolving=false
                if not ok then return nil,'resolver_exception'end
                if not result then return nil,why end
                local p=result.position or result
                if type(p.x)~='number' or type(p.z)~='number' or p.x~=p.x or p.z~=p.z or math.abs(p.x)==math.huge or math.abs(p.z)==math.huge then return nil,'invalid_world_point'end
                return {position={x=p.x,y=p.y or 0,z=p.z},data=copy(result.data)}
            end
        end
        local mechanical=q.mechanical
        q.mechanical=function(resolved)
            local ok,reason=self:ContextValid(q);if not ok then return false,reason end
            if q.cancelled then return false,'cancelled'end
            if q.kind=='object' and (not q.target or (q.target.networkID or q.target.handle)~=q.targetID)then return false,'target_identity_changed'end
            if q.dependency then
                local p=self:Poll(q.dependency)
                if not p or p.jobCancelled or p.state=='cancelled_before_send'then return false,'dependency_cancelled'end
                local ready=q.dependencyState=='mechanical' and p.mechanical or q.dependencyState=='effect' and p.effect or not q.dependencyState and p.sentAt or q.dependencyState=='sent' and p.sentAt
                if not ready then return false,'dependency_waiting'end
            end
            if q.ready and not call(q.ready)then return false,'not_ready'end
            return call(mechanical,resolved)
        end
        local id,reason=transport:Submit(q);if not id then return nil,reason end
        q.id=id;self.jobs[id]=q
        if q.resource then self.resources[q.resource]=q;hub.resources[q.resource]={client=self,id=id}end
        return id,reason
    end
    function C:Cast(key,target,opts)local q={};for k,v in pairs(opts or {})do q[k]=v end;q.key=key;q.keys={key};q.target=target;q.type='cast';return self:Submit(q)end
    function C:Attack(target,opts)local q={};for k,v in pairs(opts or {})do q[k]=v end;q.target=target;q.type='attack';return self:Submit(q)end
    function C:Move(target,opts)local q={};for k,v in pairs(opts or {})do q[k]=v end;q.target=target;q.type='move';return self:Submit(q)end
    function C:Observe(id,evidence)return transport:Observe(id,evidence)end
    function C:Claim(name,on)if self.resolving then return false,'resolver_side_effect'end;return transport:Claim(name,on)end
    function C:Tick()
        for id,q in pairs(self.jobs)do
            local r=self:Poll(id)
            if r and not r.sentAt and not self:ContextValid(q)then self:Cancel(id,'context_ended')end
        end
        transport:Tick();self.sending=transport.sending
        for id,q in pairs(self.jobs)do if q.finishRequested then self:Finish(id,q.finishReconciled)end end
    end
    function C:Close(reason)
        if self.resolving then return false,'resolver_side_effect'end

        if self.closed then return end
        self.closed=true;self.gates={};self.locks={};transport:Close(reason)
        for id in pairs(self.jobs)do self:Reconcile(id)end
    end
    -- Closed clients with historical sends remain only until explicit fresh reconciliation.
    hub.clients[C.id]=C
    function C:Collect()
        for id in pairs(self.jobs)do self:Reconcile(id)end
        if self.closed and next(self.jobs)==nil then hub.clients[self.id]=nil end
    end
    for _,previous in pairs(hub.clients)do if previous~=C and previous.closed then previous:Collect()end end
    return C
end

end)()
return function(g,options)return create(g or _G,transports,options)end
end)()
function SDK.Actions:CreateClient(options)return createActionClient(_G,options)end
_G.Orbama=SDK
return SDK

end,1)
