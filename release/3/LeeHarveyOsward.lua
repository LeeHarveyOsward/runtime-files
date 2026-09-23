if not myHero or (myHero.charName~='LeeSin' and myHero.charName~='Jade_LeeSin') then return end
if not _G.GGPrediction then
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
-- LEE HARVEY OSWARD -- generated by tools/build_lho.py; edit modular sources.
if not myHero or (myHero.charName ~= "LeeSin" and myHero.charName ~= "Jade_LeeSin") then return end
if not _G.SDK and not _G.GGUpdate then
 if not Callback or not Callback.Add then print("[LHO] Game callback API unavailable; enable Orbama and reload."); return end
 local ok, err = pcall(function()
  if SCRIPT_PATH and type(loadfile) == "function" then
   local path = SCRIPT_PATH; if not path:match("[/\\]$") then path = path .. "/" end
   local loader, reason = loadfile(path .. "Orbama.lua"); assert(loader, reason); loader()
  else require("Orbama") end
 end)
 if not ok or not (_G.SDK and _G.SDK.OrbamaVersion) then print("[LHO] Orbama load failed: " .. tostring(err or "SDK unavailable")); return end
end
local incomingBuild = "2026-09-23-r82"
local previous = _G.LeeHarveyOsward
if previous then
 if previous.build == incomingBuild and previous.active then return previous end
 if type(previous.Shutdown) ~= "function" then print("[LHO] Older controller cannot be unloaded; restart the script runtime."); return previous end
 local ok, err = pcall(previous.Shutdown, previous)
 if not ok or previous.active ~= false or _G.LeeHarveyOsward == previous then
  print("[LHO] Older controller cleanup failed; restart the script runtime: " .. tostring(err)); return previous
 end
 print("[LHO] Replacing older controller with " .. incomingBuild)
end
pcall(require, "GGPrediction")
local modules, cache = {}, {}
local externalRequire = require
modules["lho.actions"] = function(require)
local U=require('lho.util')
local Intent=require('lho.intent')
local A={};A.__index=A
local hoverOffsets={{0,0},{0,-30},{0,-60},{-25,-30},{25,-30}}
local recastNames={'leesinqtwo','leesinwtwo','leesinetwo'}
function A.new(ctx)
    local a=setmetatable({ctx=ctx,pending={},history={},nextCast=0,issuedTick=-1,serial=0},A)
    require('lho.community')(a);require('lho.actionstate')(a);return a
end
function A:inputAction(id) return id and self.ctx.sdk.Input and self.ctx.sdk.Input:GetAction(id) end
function A:inputNow() return self.ctx.sdk.Input.env.clock() end
function A:key(slot)
    if slot<4 then return ({HK_Q,HK_W,HK_E,HK_R})[slot+1] end
    if slot==4 then return HK_SUMMONER_1 elseif slot==5 then return HK_SUMMONER_2 end
    return ({HK_ITEM_1,HK_ITEM_2,HK_ITEM_3,HK_ITEM_4,HK_ITEM_5,HK_ITEM_6,HK_ITEM_7})[slot-5]
end
function A:cursorBusy() return self.minimapLease~=nil or self.ctx.sdk.Cursor and (self.ctx.sdk.Cursor.Step or 0)>0 end
function A:cursorWaitReason()
    local input=self.ctx.sdk.Input
    if input then
        if input.PendingReturn then return 'Checking cursor return' end
        if not input.Active then return 'Input / movement cooldown' end
        return 'Automatic input in progress'
    end
    return 'GG cursor busy'
end
function A:hasCursorQueue()
    local cursor=self.ctx.sdk.Cursor
    return cursor and type(cursor.Add)=='function' and type(cursor.StepPressKey)=='function'
        and type(cursor.StepSetToCastPos)=='function' and type(cursor.StepSetToCursorPos)=='function'
end
function A:dispatchNative(key,target,owner,leftClicks,validate)
    local c=self.ctx;local native=c.sdk.NativeTransport
    if not native or c:blocked() or validate and not validate() then return false,'Native context invalid' end
    local started=GetTickCount and GetTickCount();local at=c:now()
    local synthetic=c.synthetic;c.synthetic=true;c.syntheticMouseUntil=at+.08
    local ok,result,reason=pcall(function()
        if leftClicks then
            for _=1,leftClicks do
                local accepted,why=native:LeftClick(target.x,target.y)
                if not accepted then return false,why end
            end
            return true
        elseif key==(MOUSEEVENTF_RIGHTDOWN or 8) then return native:Move(target.pos or target)
        elseif key then return native:CastSpell(key,target) end
        return false,'Native transport does not reserve hover positions'
    end)
    c.synthetic=synthetic
    if c.config.capture then c:log('native_dispatch',{owner=owner,key=key,target=target and target.pos and U.id(target),
        pos=U.copy(target and (target.pos or target)),submitted=ok and result==true,
        reason=not ok and tostring(result) or reason,beginTick=started,
        returnTick=GetTickCount and GetTickCount(),verification='Host return only; gameplay observation pending'}) end
    return ok and result==true,not ok and tostring(result) or reason,{keyAt=key and at,keyTick=key and started}
end
function A:sampleCursor(reason)
    local span=self.cursorSpan;if not span then return end
    local cursor=self.ctx.sdk.Cursor;local now=GetTickCount and GetTickCount()
    if not now then self.cursorSpan=nil;return end
    local step=cursor and cursor.Step or 0
    if step~=span.lastStep and #span.phases<8 then
        span.phases[#span.phases+1]={step=step,afterMs=now-span.at};span.lastStep=step
    end
    if reason or step==0 or not cursor or cursor.CastPos~=span.castPos then
        self.cursorSpan=nil
        if self.ctx.config.capture then self.ctx:log('cursor_pipeline',{owner=span.owner,key=span.key,id=span.id,
            reason=reason or (step==0 and 'released' or 'replaced externally'),
            heldMs=now-span.at,sequenceHeldMs=now-span.rootAt,phases=span.phases,
            sampling='Callback-observed; transition time has callback uncertainty'}) end
    end
end
function A:dispatchCursor(key,target,owner,chain,leftClicks,verifyTarget,validate,worldIntent)
    local shared=self.ctx.sdk.Input
    if shared and shared.InputVersion then
        local c=self.ctx
        local previous=shared.NextIntent
        local dependency=chain and shared.Active and shared.Active.owner==owner and shared.Active.id
        shared.NextIntent={owner=owner,dependency=dependency,validate=validate or (dependency and function()return not c:blocked()end),
            verifyTarget=verifyTarget,leftClicks=leftClicks,world=worldIntent,
            critical=owner~='farm' or key~=(MOUSEEVENTF_RIGHTDOWN or 8)}
        local synthetic=c.synthetic;c.synthetic=true
        local ok,result=pcall(shared.Add,shared,key or {},target)
        c.synthetic=synthetic;shared.NextIntent=previous
        if ok and result then
            self.lastCursorAction=shared.LastActionID
            c.cursorLease={owner=owner,castPos=shared.CastPos}
            local action=shared:GetAction(shared.LastActionID)
            local sent=action and action.sentAt
            local keyAt=sent and c:now()-math.max(0,shared.env.clock()-sent)*.001
            return true,nil,{keyAt=keyAt,keyTick=sent,cursorID=shared.LastActionID}
        end
        return false,ok and 'Shared input declined' or tostring(result)
    end
    if self.ctx.sdk.NativeTransport then
        return self:dispatchNative(key,worldIntent or verifyTarget or target,owner,leftClicks,validate)
    end
    local c=self.ctx;local cursor=c.sdk.Cursor
    if not self:hasCursorQueue() or not target or not Game.cursorPos then return false,'GG cursor queue unavailable' end
    if self:cursorBusy() and not chain then return false,'GG cursor reservation' end
    local world=target.pos or target.z~=nil and target
    local screen=world and U.vector(world):To2D() or target
    if not screen or not U.finite(screen.x) or not U.finite(screen.y)
        or math.abs(screen.x)>100000 or math.abs(screen.y)>100000 then return false,'Invalid cursor projection' end
    if world and not screen.onScreen then return false,'Target offscreen' end
    local before=chain and (self.minimapLease and self.minimapLease.original or cursor.CursorPos) or Game.cursorPos()
    before=before or Game.cursorPos()
    if not before then return false,'Original cursor unavailable' end
    local original={x=before.x,y=before.y}
    local started=GetTickCount and GetTickCount();local pressed,pressedAt,returned
    local prior=self.cursorSpan
    local synthetic=c.synthetic;c.synthetic=true;c.syntheticMouseUntil=c:now()+.08
    local press=cursor.StepPressKey
    local previousIntent=cursor.NextIntent
    cursor.StepPressKey=function(queue)
            if validate and not validate() then return false end
            local hovered=verifyTarget and Game.GetUnderMouseObject and Game.GetUnderMouseObject()
            if verifyTarget and (not U.valid(verifyTarget) or not U.same(hovered,verifyTarget)) then return false end
            if verifyTarget and verifyTarget.type~=Obj_AI_Hero or key==HK_W and validate then
                queue.ForceTCOUp=true
                if HK_TCO and Control.IsKeyDown(HK_TCO) then Control.KeyUp(HK_TCO) end
            end
            pressed=GetTickCount and GetTickCount()
            pressedAt=c:now()
            return press(queue)
    end
    local ok,result=pcall(function()
        -- Check placement before any key/click. Add then owns the complete GG
        -- response wait and restoration, including an empty key list for UI clicks.
        Control.SetCursorPos(screen.x,screen.y)
        if U.screenDist(Game.cursorPos(),screen)>6 then return false end
        if cursor.AdaptiveVersion then
            cursor.NextIntent={owner=owner,chain=not not chain,original=original,originalWorld=U.copy(c.aim),
                world=U.copy(worldIntent),critical=owner=='insec' or owner=='ward' or owner=='autosmite'
                    or owner=='secure' or owner=='defense' or key==HK_W or key==HK_R}
        end
        local issued=cursor:Add(key or {},target)
        if cursor.CastPos~=target then return false end
        if chain then self.minimapLease=nil end -- The new GG sequence now owns restoration.
        cursor.CursorPos=original;c.cursorLease={castPos=target,owner=owner}
        if issued and leftClicks then
            for _=1,leftClicks do
                local pressed,reason=pcall(Control.mouse_event,2)
                local released=pcall(Control.mouse_event,4)
                if not pressed or not released then error(reason or 'Left-click release failed') end
            end
        end
        return issued
    end)
    returned=GetTickCount and GetTickCount()
    cursor.StepPressKey=press
    if cursor.AdaptiveVersion then cursor.NextIntent=previousIntent end
    c.synthetic=synthetic
    if (not ok or not result) and (cursor.Step or 0)==0 and U.screenDist(Game.cursorPos(),screen)<=6 then
        pcall(Control.SetCursorPos,original.x,original.y)
    end
    if ok and result==true and started then
        self:sampleCursor(chain and 'chained' or 'replaced by plugin')
        self.cursorSerial=(self.cursorSerial or 0)+1
        self.cursorSpan={id=self.cursorSerial,owner=owner,key=key,at=started,
            rootAt=chain and prior and prior.rootAt or started,castPos=target,lastStep=cursor.Step,
            phases={{step=cursor.Step,afterMs=returned-started}}}
    end
    if c.config.capture then c:log('cursor_dispatch',{owner=owner,key=key,original=original,requested=U.copy(screen),
        corrected=U.copy(cursor.correctedCastPos),observed=U.copy(Game.cursorPos()),step=cursor.Step,
        accepted=ok and result==true,chain=not not chain,leftClicks=leftClicks,
        verifiedTarget=verifyTarget and U.id(verifyTarget),cursorID=self.cursorSpan and self.cursorSpan.id,
        beginTick=started,keyTick=pressed,returnTick=returned,
        keyDelayMs=pressed and started and pressed-started,dispatchMs=returned and started and returned-started,
        ggResponseWaitMs=returned and cursor.Timer and math.max(0,cursor.Timer-returned)}) end
    return ok and result==true,not ok and tostring(result) or 'GG cursor dispatch declined',
        {keyAt=key and pressedAt,keyTick=key and pressed,cursorID=self.cursorSpan and self.cursorSpan.id}
end
function A:ownsHoverAim(target,owner)
    local aim=self.hoverAim;local cursor=self.ctx.sdk.Cursor;local lease=self.ctx.cursorLease
    return aim and U.same(target,aim.target) and aim.owner==owner and cursor and cursor.Step>0
        and cursor.Step<=2 and lease and lease.owner==owner and lease.castPos==aim.point
        and cursor.CastPos==aim.point and self.ctx:now()-aim.at<.25
        and U.screenDist(Game.cursorPos(),aim.point)<=6
end
function A:prepareHover(target,owner,preempt)
    local c=self.ctx;local now=c:now()
    if not self:hasCursorQueue() or type(Game.GetUnderMouseObject)~='function' then
        return false,'Target verification API unavailable'
    end
    -- Already hovering the exact object needs no synthetic aim/one-frame wait.
    -- dispatchCursor checks the object again at GG's actual keypress.
    if not self:cursorBusy() or preempt then
        local ok,hovered=pcall(Game.GetUnderMouseObject)
        local point=Game.cursorPos and Game.cursorPos()
        if ok and U.same(hovered,target) and U.valid(target) and point then
            return true,{x=point.x,y=point.y}
        end
    end
    local owned=self:ownsHoverAim(target,owner);local aim=self.hoverAim
    if owned then
        local ok,hovered=pcall(Game.GetUnderMouseObject)
        if now>aim.at and ok and U.same(hovered,target) then return true,aim.point end
        if now-aim.at<.03 then return false,'Waiting for game hover observation' end
        if c.config.capture then c:trace('smite_hover_blocked',{target=U.id(target),hovered=ok and U.id(hovered),
            name=ok and hovered and hovered.charName,point=aim.point},tostring(U.id(target)),.5) end
    elseif self:cursorBusy() and not preempt then return false,'GG cursor reservation' end
    local screen=U.vector(target.pos):To2D()
    if not screen.onScreen then return false,'Target offscreen' end
    -- Probe only on separate game frames. Alternative body points are never
    -- trusted on coordinates alone; the native hovered network ID must match.
    local index=owned and aim.index%#hoverOffsets+1 or 1
    local size=Game.Resolution and Game.Resolution();local scale=size and size.y/1440 or 1
    local point={x=screen.x+hoverOffsets[index][1]*scale,y=screen.y+hoverOffsets[index][2]*scale}
    local ok=self:dispatchCursor(nil,point,owner,owned or preempt)
    if ok then
        self.hoverAim={target=target,owner=owner,point=point,at=now,index=index}
        -- Some runtimes refresh hover during SetCursorPos. Use that confirmed
        -- observation immediately; otherwise the fast callback finishes aiming.
        local observed,hovered=pcall(Game.GetUnderMouseObject)
        if observed and U.same(hovered,target) and U.valid(target) and U.screenDist(Game.cursorPos(),point)<=6 then return true,point end
    end
    return false,'Aiming; no Smite key issued'
end
function A:releaseMinimap(force,manual)
    if self.ctx.sdk.Input then self.minimapLease=nil;return end
    local lease=self.minimapLease;local c=self.ctx
    if not lease or not force and c:now()<lease.restoreAt then return end
    self.minimapLease=nil
    local cursor=c.sdk.Cursor
    if not manual and (not cursor or (cursor.Step or 0)==0) and Game.cursorPos
        and U.screenDist(Game.cursorPos(),lease.point)<=6 then
        local synthetic=c.synthetic;c.synthetic=true;c.syntheticMouseUntil=c:now()+.08
        pcall(Control.SetCursorPos,lease.original.x,lease.original.y)
        c.synthetic=synthetic
    end
end
function A:wardDependency(slot,target,owner,anticipation)
    local c=self.ctx;local ward=c.wards and c.wards.pending
    local early=anticipation and ward==anticipation and ward.state=='placing' and not ward.earlyTried
        and target and not target.pos and U.dist(target,ward.pos)<1
    local event=ward and (early and ward.event or ward.placementEvent)
    return slot==1 and ward and (early or ward.state=='waiting_w' and ward.observed and U.same(ward.target,target))
        and event and not event.cancelled and event.owner==owner and ward.owner==owner
        and c.profile.wards[event.before.item]
end
function A:canChainWard(slot,target,owner,anticipation)
    local c=self.ctx;local cursor=c.sdk.Cursor;local lease=c.cursorLease;local ward=c.wards and c.wards.pending
    local event=ward and (anticipation and ward.event or ward.placementEvent)
    -- The repository GG Cursor:Add issues the key synchronously; Steps 1-3
    -- wait/restore its cursor afterwards. Only our own placement sequence can
    -- be replaced by its early W test or its confirmed ward follow-up.
    return c.config:get('wardFastCursor') and slot==1 and cursor and cursor.Step>=1 and cursor.Step<=3
        and type(cursor.Add)=='function' and type(cursor.StepPressKey)=='function'
        and type(cursor.StepSetToCastPos)=='function' and type(cursor.StepSetToCursorPos)=='function'
        and lease and lease.owner==owner and cursor.CastPos==lease.castPos and cursor.CursorPos
        and self:wardDependency(slot,target,owner,anticipation)
        and cursor.Keys and #cursor.Keys==1 and (cursor.Keys[1]==self:key(event.slot)
            or not anticipation and ward.earlyEvent and cursor.Keys[1]==HK_W)
        and U.vector(target.pos or target):To2D().onScreen
end
function A:canChainInsecKick(slot,target,owner)
    local c=self.ctx;local cursor=c.sdk.Cursor;local lease=c.cursorLease;local i=c.combat and c.combat.insec
    if slot~=3 or (owner~='insec' and owner~='fight' and owner~='killsteal') or c:dash()
        or not cursor or cursor.Step<1 or cursor.Step>3 or not lease or lease.owner~=owner
        or cursor.CastPos~=lease.castPos then return false end
    if owner=='insec' then
        if not i or not U.same(i.target,target) or not c.combat:kickValid(i) then return false end
    elseif not c:enemyValid(target) or U.dist(myHero.pos,target.pos)>c.profile.rRange or c.combat:kickProtected(target) then return false end
    local previous=self.history[#self.history]
    return previous and previous.owner==owner and not previous.cancelled
        and (previous.status=='observed' or previous.status=='completed')
        and (previous.slot==1 and previous.stage==1 or previous.slot==0 and previous.stage==2
            or previous.slot>=4 and previous.slot<=5 and U.name(previous.name)=='summonerflash')
end
local function directionError(origin,intended,observed)
    if not origin or not intended or not observed or not origin.z or not intended.z or not observed.z then return end
    local ax,az=intended.x-origin.x,intended.z-origin.z
    local bx,bz=observed.x-origin.x,observed.z-origin.z
    local length=math.sqrt((ax*ax+az*az)*(bx*bx+bz*bz))
    if length>1 then return math.deg(math.acos(U.clamp((ax*bx+az*bz)/length,-1,1))) end
end
function A:observeQAim()
    local c=self.ctx;local now=c:now();local active=myHero.activeSpell
    local candidates={}
    for n=#self.history,math.max(1,#self.history-15),-1 do
        local e=self.history[n]
        if e.aimIntent and not e.aimReported then
            local r=self.api and self:inputAction(e.cursorID)
            local sentAt=r and r.sentAt and now-math.max(0,self:inputNow()-r.sentAt)/1000 or not self.api and e.keyAt
            if not sentAt then
                if e.cancelled or r and r.state=='cancelled_before_send' or now-e.at>1 then
                    e.aimReported=true
                    if c.config.capture then c:log('q_aim_not_sent',{request=e.id,cursorID=e.cursorID,
                        reason=r and r.reason or e.status or 'No send evidence'}) end
                end
            elseif now-sentAt>1 then
                e.aimReported=true;if c.config.capture then c:log('q_aim_unknown',{request=e.id,cursorID=e.cursorID,
                    reason='No matching native placement observed within one second; no timing learning'}) end
            elseif active and active.valid and active.name==e.name and active.placementPos and active.startTime
                and active.startTime>=sentAt-.02 and active.startTime<=now+.1 then
                candidates[#candidates+1]=e
            end
        end
    end
    for _,e in ipairs(candidates) do
        e.aimReported=true
        local input=c.sdk.Input;local action=input and e.cursorID and input:GetAction(e.cursorID)
        if c.config.capture then c:log('q_aim_observed',{request=e.id,cursorID=e.cursorID,inputSession=action and action.inputSession,
            requested=e.aimIntent,origin=e.aimOrigin,playerWorld=action and action.playerWorld,
            observed=U.copy(active.placementPos),nativeStart=active.startTime,
            desiredErrorDegrees=directionError(e.aimOrigin,e.aimIntent,active.placementPos),
            playerErrorDegrees=directionError(e.aimOrigin,action and action.playerWorld,active.placementPos),
            sentAt=action and action.sentAt,releasedAt=action and action.releasedAt,
            interrupted=action and action.interrupted,competitor=action and action.competitor,
            attribution=#candidates==1 and action and not action.interrupted and not action.competitor
                and 'Single matching script request; source not independently proven' or 'Ambiguous or interrupted request',
            evidence='Native placement direction only; no hit confirmation or timing learning'}) end
    end
end
function A:tick()
    local c=self.ctx;local now=c:now()
    if self.originalGG then self.api:Pump(self) end
    if self.api then self:refreshUncertainty();self:syncAutomation() end
    if c.config.capture then self:observeQAim() end
    self:sampleCursor()
    self:releaseMinimap()
    local move=self.routeObservation
    if move then
        local action=self:inputAction(move.cursorID)
        local pending=action and not action.sentAt and action.state~='aborted' and action.state~='cancelled_before_send'
        local declined=action and not action.sentAt and (action.state=='aborted' or action.state=='cancelled_before_send')
        if action and action.sentAt and not move.sendObserved then
            move.sendObserved=true;move.at=now-math.max(0,self:inputNow()-action.sentAt)/1000
        end
        if declined then
            if c.config.capture then c:log('route_input_aborted',{cursorID=move.cursorID,reason=action.reason,destination=move.destination}) end
            self.routeObservation=nil;self.routeCommand=nil
        elseif pending then
            -- An accepted cursor request has not yet sent a game movement command.
        elseif not c.config:get('autoJungle') then self.routeObservation=nil
        elseif action and (action.interrupted or action.competitor) then
            -- A interrupted input has no uniquely attributable endpoint. Manual
            -- clicks already pause farming through the input handler. Replan
            -- from fresh state after the player interval, never replay this ID.
            if c.config.capture then c:log('route_input_uncertain',{cursorID=move.cursorID,reason=action.reason,
                destination=move.destination,observedDestination=myHero.pathing and U.copy(myHero.pathing.endPos),
                interrupted=action.interrupted,competitor=action.competitor}) end
            self.routeObservation=nil
            -- Keep the ordinary acknowledgement interval for this destination.
            -- Discarding the command here caused a new warp every ~180 ms.
            if self.routeCommand then self.routeCommand.uncertain=true end
            self.nextMove=math.max(self.nextMove or 0,now+.12)
        elseif c:dash() or c:recalling() or c.farm.state=='clearing' or c.farm.state=='finishing' then
            self.routeObservation=nil -- Combat, dash and recall supersede travel.
        elseif myHero.pathing and myHero.pathing.hasMovePath and myHero.pathing.endPos
            and now-move.at>.2 and U.dist(myHero.pathing.endPos,move.sent or move.destination)>250 then
            if c.config.capture then c:log('route_endpoint_mismatch',{destination=move.destination,dispatchedDestination=move.sent,
                cursorID=move.cursorID,
                observedDestination=U.copy(myHero.pathing.endPos),transport=move.transport}) end
            self.routeObservation=nil;self.routeCommand=nil
            if move.transport=='minimap' then self.mapFit=nil;self.minimapRejectedUntil=now+10 end
            -- Native path endpoints may stop at attack range, snap to walkable
            -- ground, or be superseded by our own combat order. A mismatch is
            -- failed movement evidence, never evidence of a player's cancel.
            -- Retry from fresh planning without switching off retaliation.
            self.nextMove=math.max(self.nextMove or 0,now+.25)
            c.routeFailureReason=nil
        elseif U.dist(myHero.pos,move.origin)>40 and now-move.at>.2 then
            if c.config.capture then c:log('route_move_observed',{delay=now-move.at,destination=move.destination,cursorID=move.cursorID}) end;self.routeObservation=nil
        elseif now-move.at>1.5 and not move.reported then
            move.reported=true;if c.config.capture then c:log('route_move_unobserved',{destination=move.destination,origin=move.origin,
                hasMovePath=myHero.pathing and myHero.pathing.hasMovePath,endPos=myHero.pathing and U.copy(myHero.pathing.endPos)}) end
        end
    end
    if self.routeStop and not self:cursorBusy() and not c:blocked() and not c:recalling() then
        local ok=self:worldMove(myHero.pos)
        if ok then self.routeStop=nil end
    end
    if self.cameraOwned and not c.config:get('autoJungle') then self:restoreCamera() end
    if not self.api and c.cursorLease and (not self:cursorBusy() or c.sdk.Cursor.CastPos~=c.cursorLease.castPos) then c.cursorLease=nil end
    for slot,event in pairs(self.pending) do
        local r=self:inputAction(event.cursorID)
        if self.api and r and not r.sentAt and r.state~='cancelled_before_send' and event.validate then
            -- A resolving world cast must be checked against its new aim at
            -- dispatch, not rejected here against the old planning position.
            local check=event.resolveWorldTarget and event.contextValid or event.validate
            local ok,valid,why=pcall(check)
            if not ok or not valid then
                self.scope:Cancel(event.cursorID,ok and (why or 'gameplay_condition_changed') or 'validation_exception')
                r=self:inputAction(event.cursorID)
            end
        end
        if self.api and r and r.state=='cancelled_before_send' then
            event.status='cancelled';event.cancelled=true;event.reason=r.reason;self.pending[slot]=nil
            if c.config.capture then c:log('cast_cancelled',{request=event.id,cursorID=event.cursorID,owner=event.owner,slot=slot,reason=r.reason}) end
        elseif not self.api or r and r.sentAt then
        if self.api and not event.sendObserved then
            if event.aimTarget then require('lho.aim').remember(self,r,event.aimTarget) end
            event.sendObserved=true;event.keyTick=r.sentAt;event.keyAt=now-math.max(0,self:inputNow()-r.sentAt)*.001
            event.deadline=event.keyAt+math.max(.4,c.latency*2+c.jitter*3+.2)
            event.status=r.state
            if r.resolution then
                event.aimIntent=U.copy(r.resolution.position)
                event.aimOrigin=U.copy(myHero.pos)
                event.resolution=r.resolution
            end
            if c.config.capture then c:log('cast_sent',{request=event.id,cursorID=event.cursorID,slot=slot,owner=event.owner,
                inputBoundary=self.originalGG and 'GG_public_handoff' or 'Orbama_send',
                requestedAt=r.requestedAt,sentAt=r.sentAt,queue=r.sentAt>=r.requestedAt and (r.sentAt-r.requestedAt)*.001 or nil,
                invalidTiming=r.sentAt<r.requestedAt,timebase='monotonic milliseconds',gameTime=now,state=r.state,
                sendCompletedAt=r.sendCompletedAt,holdUntil=r.holdUntil,releasedAt=r.releasedAt}) end
        end
        local d=c:spell(slot)
        local q2=slot==0 and event.stage==2
        local active=myHero.activeSpell
        local q2Observed=q2 and active and active.valid and U.name(active.name):find('leesinqtwo',1,true)
            and (not active.startTime or active.startTime>=event.at-.1)
        local observed=(d.name and d.name~='' and d.name~=event.before.name) or (d.currentCd or 0)>(event.before.cd or 0)+.05
            or (d.ammo~=nil and event.before.ammo~=nil and d.ammo<event.before.ammo)
            or (d.toggleState~=nil and event.before.toggleState~=nil and d.toggleState~=event.before.toggleState)
        if event.before.item then
            local item=myHero:GetItemData(slot)
            observed=observed or not item or item.itemID~=event.before.item
                or (U.stackCount(item)<event.before.stacks)
                or (item and item.ammo~=nil and event.before.itemAmmo~=nil and item.ammo<event.before.itemAmmo)
        end
        local recastObserved
        if self.api and slot<3 and event.stage==2 then
            local evidence
            recastObserved,evidence=require('lho.recasts').evidence(c,slot,event.recastBefore,event.keyAt)
            event.recastEvidence=evidence;observed=recastObserved and true or false
            if c.config.capture and event.lastRecastReason~=evidence.reason then
                event.lastRecastReason=evidence.reason
                c:log('recast_evidence',{cursorID=event.cursorID,slot=slot,observed=observed,evidence=evidence})
            end
            if q2 then q2Observed=recastObserved end
        end
        if q2Observed then
            c.q2Outcome={at=now,text='Q2 cast observed'}
            if c.config.capture then c:log('q2_cast_observed',{name=event.name,request=event.id,delay=now-event.at}) end
            observed=true
        end
        if observed then
            if (event.wardAnticipation or self.api) and c.clear then c.clear:accepted(slot,event.stage,not self.api) end
            if self.api and c.clear and slot<4 and (event.stage~=2 and (d.currentCd or 0)>(event.before.cd or 0)+.05
                or event.stage==1 and c:stage(slot)==2 or recastObserved) then
                c.clear:executed(slot,event.stage,event.recastEvidence and event.recastEvidence.at or now)
            end
            if self.api then self.scope:Observe(event.cursorID,{kind='mechanical',source='spell_metadata',unique=true,at=self.api:Now()}) end
            if q2 and not q2Observed then c.q2Outcome={at=now,text='Q state changed; Q2 hit unconfirmed'} end
            event.status='observed';event.observedAt=now;self.pending[slot]=nil
            c.metrics.observed=(c.metrics.observed or 0)+1;if c.config.capture then c:log('cast_observed',{name=event.name,request=event.id,delay=now-event.at,
                slot=slot,stage=event.stage,owner=event.owner,target=event.target,encounter=event.encounter,
                insecAttempt=event.insecAttempt,evidence='Spell metadata changed; impact not confirmed'}) end
        elseif self.api and r and r.state=='send_uncertain' then
            self:quarantine(slot,event,r)
        elseif now>event.deadline then
            if event.aimTarget then require('lho.aim').reject(self,r,event.aimTarget) end
            event.status='unconfirmed';self.pending[slot]=nil
            if c.config.capture then c:log('cast_unconfirmed',{name=event.name,request=event.id,slot=slot,owner=event.owner,
                cursorID=event.cursorID,target=event.target,stage=event.stage,before=event.before,
                after={name=d.name,cd=d.currentCd,ammo=d.ammo,toggleState=d.toggleState},
                keyAt=event.keyAt,deadline=event.deadline,recastEvidence=event.recastEvidence,
                input=r and {state=r.state,reason=r.reason,sentAt=r.sentAt,releasedAt=r.releasedAt,
                    interrupted=r.interrupted,uncertain=r.uncertain},
                active=active and {name=active.name,valid=active.valid,startTime=active.startTime},
                evidence='No attributable spell-state change before observation deadline; effect unknown'}) end
            if q2 then c.q2Outcome={at=now,text='Q2 key sent but cast unconfirmed'} end
        end
        end
    end
end
function A:cameraKey(key)
    local c=self.ctx;local input=c.sdk.Input
    if c:blocked() or self:cursorBusy() or input and input.Uncertain then return false,'Input unavailable',false end
    if input then
        local synthetic=c.synthetic;c.synthetic=true
        local previous=input.LastActionID
        local ok,accepted=pcall(input.SendKeys,input,key,'camera')
        c.synthetic=synthetic
        local action=input.LastActionID~=previous and input:GetAction(input.LastActionID)
        return ok and accepted==true,ok and (accepted and 'Host submission only' or 'Key input declined') or tostring(accepted),
            action and action.sentAt~=nil or not ok
    end
    return false,'Owned key input unavailable',false
end
function A:restoreCamera()
    local c=self.ctx;local lease=self.cameraOwned
    if not lease then return false end
    if not c.config:get('farmRestoreCamera') then self.cameraOwned=nil;return false end
    if (Game.IsChatOpen and Game.IsChatOpen()) or (Game.IsOnTop and not Game.IsOnTop()) then return false end
    if c:now()<(self.cameraRestoreAt or 0) then return false end
    local accepted,reason,submitted=self:cameraKey(lease.key)
    if not accepted and not submitted then
        self.cameraRestoreAt=c:now()+.1
        if c.config.capture then c:trace('camera_restore_deferred',{reason=reason},'camera restore',1) end;return false
    end
    self.cameraOwned=nil;self.cameraToggleAt=nil;self.cameraAt=nil;self.cameraRestoreAt=nil
    if c.config.capture then c:log(accepted and 'camera_restored' or 'camera_restore_unknown',{reason=reason,
        evidence='Host submission; camera state unverified. No automatic toggle replay.'}) end;return accepted
end
function A:cast(slot,target,owner,opts)
    opts=opts or {};local c=self.ctx;local now=c:now();local key=self:key(slot)
    local function blocked(reason)
        local previous=self.lastBlock
        local same=previous and previous.owner==owner and previous.slot==slot and previous.reason==reason
            and previous.target==U.id(target)
        self.lastBlock={at=now,owner=owner,slot=slot,reason=reason,target=U.id(target),
            count=same and previous.count+1 or 1,reportAt=same and previous.reportAt or now}
        if same and now<previous.reportAt+.75 then return false end
        self.lastBlock.reportAt=now
        if c.config.capture then c:trace('cast_blocked',{slot=slot,stage=opts.stage,owner=owner,reason=reason,
            target=target and target.pos and U.id(target),pos=U.copy(target and (target.pos or target)),
            count=self.lastBlock.count,cursorStep=c.sdk.Cursor and c.sdk.Cursor.Step,pending=self.pending[slot] and self.pending[slot].id},
            tostring(slot)..':'..tostring(owner)..':'..reason,.75) end
        return false
    end
    -- GG's untargeted CastSpell branch calls CastKey directly and does not
    -- touch Cursor.Step / CastPos / CursorPos. Self-centered spells and recasts
    -- can share a cursor reservation without changing its owner or aim.
    local keyOnly=target==nil and (slot==0 and opts.stage==2 or slot==2 or slot==1 and (opts.stage or c:stage(1))==2)
    local priority=opts.smiteExecute and (owner=='autosmite' or owner=='secure')
        and c.smite and slot==c.smite:resolve() and opts.validate and opts.validate()
    local dependent=(opts.wardFollowup or opts.wardAnticipation) and self:wardDependency(slot,target,owner,opts.wardAnticipation)
    local chain=dependent and self:canChainWard(slot,target,owner,opts.wardAnticipation)
        or opts.verifyHover and self:ownsHoverAim(target,owner)
        or self:canChainInsecKick(slot,target,owner) or priority and self:hasCursorQueue()
    if c:blocked() then return blocked('Disabled / dead / chat / focus') end
    if opts.wardAnticipation and (not dependent or not (self:hasCursorQueue() or c.sdk.NativeTransport) or not opts.validate or not opts.validate()) then
        return blocked('Early W context / GG queue unavailable')
    end
    if c.combat and c.combat.insec and c.combat.insec.preview and owner~='autosmite' then return blocked('Insec preview owns input; no casts') end
    if self:smiteOwnsInput() and not priority then return blocked('Lethal Smite awaiting target verification') end
    if c:recalling() and not priority then return blocked('Recall active') end
    if c.leveling and c.leveling.pending and not priority then return blocked('Skill allocation owns input') end
    if not key then return blocked('No resolved binding') end
    if self.api then self:refreshUncertainty() end
    if self.slotUncertainty[slot] then return blocked('Slot awaiting evidence or physical reactivation') end
    if self.pending[slot] then return blocked('Previous request awaiting acknowledgement') end
    if self:cursorBusy() and not self.api and not chain and not keyOnly then return blocked('GG cursor reservation') end
    if self.issuedTick==now and not dependent and not priority then return blocked('Another cast issued this tick') end
    if not opts.urgent and now<self.nextCast then return blocked('Cast spacing') end
    if opts.wardItem and slot>=6 then
        if not c.wards:itemReady(slot) then return blocked('Ward item not ready') end
    elseif not c:ready(slot) then return blocked('Native cooldown / energy / rank') end
    if slot<4 and not opts.interrupt and c.sdk.Orbwalker:IsAutoAttacking() then return blocked('Attack windup protected') end
    if target and target.pos and not U.valid(target) then return blocked('Target unavailable') end
    if target and not target.pos then target=U.vector(target) end
    local hoverPoint
    if opts.verifyHover and not self.api and not c.sdk.NativeTransport then
        local ready,point=self:prepareHover(target,owner,priority)
        if not ready then
            -- Reserve only a real hover attempt, once per lethal target. A
            -- missing API/offscreen object or failed aim must not freeze play.
            if priority and self:ownsHoverAim(target,owner)
                and (not self.smiteLease or not U.same(self.smiteLease.target,target)) then
                self.smiteLease={target=target,untilTime=now+.12,validate=opts.validate}
            end
            return blocked(point)
        end
        hoverPoint=point;chain=true
    end
    local d=c:spell(slot);local item=slot>=6 and myHero:GetItemData(slot);local stage=slot<3 and (opts.stage or c:stage(slot))
    self.serial=self.serial+1
    c.metrics.requested=(c.metrics.requested or 0)+1
    local intended=opts.intendedTarget or (target and target.pos and target)
    local event={id=self.serial,name=d.name,slot=slot,stage=stage,owner=owner,status='requested',at=now,
        intentMode=Intent.origin(c,owner),
        activation=self.activation[owner] or 0,ownerGeneration=self.ownerGeneration[owner] or 0,
        wardAnticipation=opts.wardAnticipation and true or nil,
        target=U.id(intended),targetName=intended and intended.charName,targetPos=U.copy(intended and intended.pos),
        insecAttempt=owner=='insec' and c.insecTrace or nil,
        deadline=now+math.max(.4,c.latency*2+c.jitter*3+.2),
        before={name=d.name,cd=d.currentCd,ammo=d.ammo,toggleState=d.toggleState,item=item and item.itemID,
            itemAmmo=item and item.ammo,stacks=U.stackCount(item),stackCount=item and item.stackCount}}
    if stage==2 then
        event.recastBefore=require('lho.recasts').snapshot(c,slot)
        event.recastBefore.targetPos=U.copy(intended and intended.pos)
    end
    local requestFields=c.config.capture and {request=event.id,name=d.name,slot=slot,stage=stage,owner=owner,key=key,requestedAt=now,
        target=event.target,targetName=event.targetName,targetPos=event.targetPos,pos=U.copy(target and (target.pos or target)),
        nativeSlot=c:spellSlot(slot),nativeState=Game.CanUseSpell(c:spellSlot(slot)),energy=myHero.mana,cost=d.mana,
        before=event.before,deadline=event.deadline} or nil
    if c.config.capture and slot==0 and stage==1 and target then
        event.aimIntent=U.copy(target.pos or target);event.aimOrigin=U.copy(myHero.pos)
    end
    -- No input waits for synchronous request-log writes. requestedAt and the
    -- dispatch timestamps preserve causality even though records follow input.
    c.synthetic=true;c.injected[key]={at=now,remaining=2}
    local ok,result
    event.dispatchAt=c:now()
    event.dispatchTick=GetTickCount and GetTickCount() or nil
    if self.api then
        local itemID=item and item.itemID;local identity=target and target.pos and U.id(target)
        local insec=c.combat and c.combat.insec
        event.modeBound=event.intentMode~=nil
        local function contextValid()
            if c:blocked() then return false,'context_blocked' end
            if (self.ownerGeneration[owner] or 0)~=event.ownerGeneration then return false,'owner_cancelled' end
            return Intent.valid(c,event.intentMode)
        end
        local function checkLegal()
            local valid,reason=contextValid();if not valid then return false,reason end
            if c.combat and c.combat.insec and c.combat.insec.preview and owner~='autosmite' then return false,'preview_active' end
            if c.leveling and c.leveling.pending and not priority then return false,'leveling_active' end
            if owner=='fight' and c:combatTransit() then return false,'engage_in_flight' end
            if slot<4 and not c:abilityEnabled(slot,stage,owner,intended,opts.abilityPolicy) then return false,'disabled_for_mode' end
            if c:recalling() and not priority then return false,'recall_active' end
            if target and target.pos and (not U.valid(target) or U.id(target)~=identity) then return false,'target_changed_or_unavailable' end
            if slot<3 and stage and c:stage(slot,intended)~=stage then return false,'spell_stage_changed' end
            if not opts.wardItem and not c:ready(slot) then return false,'cooldown_energy_or_rank' end
            if itemID and (myHero:GetItemData(slot) or {}).itemID~=itemID then return false,'item_slot_changed' end
            if opts.wardItem and target and U.dist(myHero.pos,target)>c.wards:range(slot) then return false,'ward_out_of_range' end
            if opts.wardItem and target and c.terrain:wall(target)~=false then return false,'ward_placement_blocked' end
            if slot==1 and stage==1 and target and target.pos and not U.same(target,myHero) and not c.wards:jumpable(target) then return false,'invalid_w_ally_or_range' end
            if opts.validate then local allowed,why=opts.validate();if not allowed then return false,why or 'gameplay_condition_changed' end end
            if slot<4 and not opts.interrupt and c.sdk.Orbwalker:IsAutoAttacking() then return false,'attack_windup' end
            return not c:blocked() and (not target or not target.pos or U.valid(target) and U.id(target)==identity)
                and (not intended or U.valid(intended))
                and (slot>=3 or not stage or c:stage(slot,intended)==stage)
                and (slot>=4 or opts.interrupt or not c.sdk.Orbwalker:IsAutoAttacking())
                and (not itemID or (myHero:GetItemData(slot) or {}).itemID==itemID)
                and (opts.wardItem and c.wards:itemReady(slot,nil,self.pending[slot]==event) or not opts.wardItem and c:ready(slot))
                and (owner~='insec' or c.combat.insec==insec and insec~=nil
                    and c.input:held(insec.kind=='cursor' and 'cursorKey' or 'allyKey')
                    and (slot~=3 or c.combat:geometry(insec) and c.combat:kickValid(insec)))
                and (slot~=0 or stage~=2 or intended and c:mark(intended)
                    and U.dist(myHero.pos,intended.pos)<=c.profile.q2Range and not c:dash())
                and (slot~=1 or stage~=1 or not target or not target.pos or U.same(target,myHero) or c.wards:jumpable(target))
                and (slot<4 or slot>5 or U.name(d.name)~='summonerflash'
                    or target and U.dist(myHero.pos,target)<=400 and c.terrain:wall(target)~=true
                        and (owner~='insec' or c.combat.planner:flashAllowed(insec)))
                and (slot~=3 or not target or not target.pos or not c:dash()
                    and U.dist(myHero.pos,target.pos)<=c.profile.rRange and not c.combat:kickProtected(target))
        end
        local function legal() return U.withBuffScope(checkLegal) end
        local why,timing
        event.validate=legal;event.contextValid=contextValid
        event.resolveWorldTarget=opts.resolveWorldTarget~=nil
        self.dependencies[owner]=dependent and c.wards.pending and
            (c.wards.pending.placementEvent or c.wards.pending.event).cursorID or nil
        if not dependent and self:canChainInsecKick(slot,target,owner) then
            self.dependencies[owner]=self.history[#self.history].cursorID
        end
        result,why,timing=self:dispatchCursor(key,target,owner,chain,nil,opts.verifyHover and target,legal,nil,
            {priority=Intent.priority(owner,priority),resolveWorldTarget=opts.resolveWorldTarget,resource='slot:'..slot,
                contextValid=contextValid,intentTargetID=event.target});ok=true
        event.reason=why;event.aimTarget=opts.verifyHover and target
        if timing then event.keyAt=timing.keyAt;event.keyTick=timing.keyTick;event.cursorID=timing.cursorID end
    elseif c.sdk.NativeTransport then
        local timing,reason
        result,reason,timing=self:dispatchNative(key,target,owner,nil,opts.validate);ok=true
        if timing then event.keyAt=timing.keyAt;event.keyTick=timing.keyTick end
    elseif target and self:hasCursorQueue() then
        local reason,timing
        result,reason,timing=self:dispatchCursor(key,hoverPoint or target,owner,chain,nil,opts.verifyHover and target,opts.validate);ok=true
        if timing then event.keyAt=timing.keyAt;event.keyTick=timing.keyTick;event.cursorID=timing.cursorID end
        if dependent and chain and ok and result==true then if c.config.capture then c:log('ward_cursor_chained') end end
    elseif c.sdk.Input and not target then
        ok,result=pcall(c.sdk.Input.SendKeys,c.sdk.Input,key,owner)
        local action=c.sdk.Input:GetAction(c.sdk.Input.LastActionID)
        if action and action.sentAt then
            event.keyTick=action.sentAt;event.keyAt=c:now()-math.max(0,self:inputNow()-action.sentAt)*.001
        end
    else ok,result=pcall(Control.CastSpell,key,target) end
    c.synthetic=false
    if requestFields then
        requestFields.keyAt=event.keyAt;requestFields.keyTick=event.keyTick;requestFields.cursorID=event.cursorID
        c:log('cast_requested',requestFields)
    end
    U.invalidateBuffScope()
    if not ok or result~=true then
        event.status='rejected';c.metrics.rejected=(c.metrics.rejected or 0)+1
        return blocked(not ok and tostring(result) or event.reason or 'input_declined')
    end
    c.metrics.accepted=(c.metrics.accepted or 0)+1
    if not self.api and stage and c.clear and not opts.wardAnticipation then c.clear:accepted(slot,stage) end
    if not self.api and not keyOnly and self:cursorBusy() then c.cursorLease={castPos=c.sdk.Cursor.CastPos,owner=owner} end
    event.status='accepted';self.pending[slot]=event;self.issuedTick=now
    if priority then self.smiteLease=nil end
    self.nextCast=now+(opts.delay or ((slot==0 or slot==3) and .25 or .06))
    self.history[#self.history+1]=event;if #self.history>128 then table.remove(self.history,1) end
    if c.telemetry then c.telemetry:safe('action',event,intended) end
    if c.config.capture then c:log('cast_accepted',{name=d.name,slot=slot,stage=stage,owner=owner,request=event.id,
        target=event.target,targetName=event.targetName,encounter=event.encounter,insecAttempt=event.insecAttempt}) end
    return true,event
end
function A:smiteOwnsInput()
    if self.api then return false end -- Dispatcher alone owns positioning and failure retry windows.
    local lease=self.smiteLease
    if not lease then return false end
    if not lease.validate() then self.smiteLease=nil;return false end
    return self.ctx:now()<=lease.untilTime
end
function A:cancel(owner)
    if self.ctx.sdk.Input then self.ctx.sdk.Input:Cancel(owner,'LHO owner cancelled') end
    for _,event in ipairs(self.history) do
        if event.owner==owner and event.status=='accepted' and not event.cancelled then
            event.cancelled=true;event.intentStatus='cancelled';if self.ctx.config.capture then self.ctx:log('cast_cancelled',{request=event.id,slot=event.slot,owner=owner}) end
        end
    end
end
function A:minimap(pos)
    if self.ctx:now()<(self.minimapRejectedUntil or 0) then return end
    local p=U.vector(pos);local size=Game.Resolution and Game.Resolution()
    local ok,map=pcall(function()return p.ToMM and p:ToMM()end)
    if not ok then map=nil end
    local function valid(p)
        return p and size and type(p.x)=='number' and type(p.y)=='number'
            and p.x==p.x and p.y==p.y and p.x>=0 and p.y>=0 and p.x<size.x and p.y<size.y
    end
    map=self:minimapPixels(map,size)
    if not valid(map) then map=self:objectMinimap(pos,size,valid) end
    if not valid(map) then return end
    return {x=map.x,y=map.y}
end
function A:minimapPixels(point,size)
    if not point or not size or type(point.x)~='number' or type(point.y)~='number' then return end
    if point.x>=0 and point.y>=0 and point.x<size.x and point.y<size.y then return {x=point.x,y=point.y} end
    local display=require('lho.display')
    if size.x==display.apiWidth and size.y==display.apiHeight and point.x>=0 and point.y>=0
        and point.x<display.renderWidth and point.y<display.renderHeight then
        return {x=point.x*display.apiWidth/display.renderWidth,y=point.y*display.apiHeight/display.renderHeight}
    end
end
function A:worldMove(destination,owner,chain)
    if self:smiteOwnsInput() then return false,'Lethal Smite awaiting target verification' end
    if self.ctx.sdk.NativeTransport then return self:dispatchNative(MOUSEEVENTF_RIGHTDOWN or 8,U.vector(destination),owner or 'farm') end
    if self:hasCursorQueue() then
        local ground=require('lho.ground');local point,reason=ground.select(self.ctx,destination)
        if not point then return false,reason end
        if self.ctx.config.capture and U.dist(point,destination)>1 then
            self.ctx:trace('ground_click_adjusted',{owner=owner,goal=U.copy(destination),click=U.copy(point)},'ground_click',.25)
        end
        local accepted,why,detail=self:dispatchCursor(MOUSEEVENTF_RIGHTDOWN or 8,U.vector(point),owner or 'farm',chain,nil,nil,function()
            return not ground.blocker(self.ctx,point),'ground_click_occupied'
        end)
        if accepted then detail=detail or {};detail.movementDestination=U.copy(point) end
        return accepted,why,detail
    end
    -- GG's mouse-movement branch clicks without checking SetCursorPos success.
    -- Confirm the screen point before allowing that branch to issue its click.
    if not Control.Move or not Control.SetCursorPos or not Game.cursorPos then return false,'screen cursor API unavailable' end
    local point=U.vector(destination):To2D();local before=Game.cursorPos()
    local original=before and {x=before.x,y=before.y}
    if not point.onScreen or not original then return false,'world destination is offscreen' end
    local c=self.ctx;local synthetic=c.synthetic;c.synthetic=true;c.syntheticMouseUntil=c:now()+.08
    local ok,result=pcall(function()
        Control.SetCursorPos(point.x,point.y)
        if U.screenDist(Game.cursorPos(),point)>6 then return false end
        return Control.Move(U.vector(destination))
    end)
    local cursor=c.sdk.Cursor
    if ok and result and cursor and cursor.Step>0 and cursor.CastPos and U.dist(cursor.CastPos,destination)<1 then
        cursor.CursorPos=original;c.cursorLease={castPos=cursor.CastPos,owner='farm'}
    elseif U.screenDist(Game.cursorPos(),point)<=6 then pcall(Control.SetCursorPos,original.x,original.y) end
    c.synthetic=synthetic
    return ok and result==true,not ok and tostring(result) or 'screen move unconfirmed'
end
function A:objectMinimap(pos,size,valid)
    -- GOS documents object.posMM independently of Vector:ToMM. Calibrate an
    -- affine transform from live map markers, never guessed HUD coordinates.
    if not size then return end
    local c=self.ctx;local fit=self.mapFit
    if not fit or fit.width~=size.x or fit.height~=size.y or c:now()-fit.at>.5 then
        local points={}
        for _,list in ipairs({c.heroes or {},c.turrets or {},c.camps or {}}) do
            for _,o in ipairs(list) do
                local ok,mm=pcall(function()return o.posMM end)
                mm=ok and self:minimapPixels(mm,size) or nil
                if ok and o.pos and valid(mm) and (mm.x~=0 or mm.y~=0) then
                    points[#points+1]={world=U.copy(o.pos),map={x=mm.x,y=mm.y}}
                end
            end
        end
        local a,b,d=points[1],nil,nil;local far,area=0,0
        if a then for _,v in ipairs(points) do local n=U.dist(a.world,v.world);if n>far then b,far=v,n end end end
        local function cross(p,q,r)return (q.x-p.x)*(r.z-p.z)-(q.z-p.z)*(r.x-p.x) end
        if b then for _,v in ipairs(points) do local n=math.abs(cross(a.world,b.world,v.world));if n>area then d,area=v,n end end end
        fit={at=c:now(),width=size.x,height=size.y};self.mapFit=fit
        if not d or area<250000 or U.screenDist(a.map,b.map)<20 or U.screenDist(a.map,d.map)<20 then return end
        local det=cross(a.world,b.world,d.world)
        local function project(p)
            local u=((p.x-a.world.x)*(d.world.z-a.world.z)-(p.z-a.world.z)*(d.world.x-a.world.x))/det
            local v=((b.world.x-a.world.x)*(p.z-a.world.z)-(b.world.z-a.world.z)*(p.x-a.world.x))/det
            return {x=a.map.x+u*(b.map.x-a.map.x)+v*(d.map.x-a.map.x),
                y=a.map.y+u*(b.map.y-a.map.y)+v*(d.map.y-a.map.y)}
        end
        -- Reject collapsed/inconsistent projections; a fourth marker checks the fit.
        if #points<4 or math.abs((b.map.x-a.map.x)*(d.map.y-a.map.y)-(b.map.y-a.map.y)*(d.map.x-a.map.x))<100 then return end
        for _,v in ipairs(points) do if U.screenDist(project(v.world),v.map)>4 then return end end
        fit.project=project;if c.config.capture then c:log('minimap_calibrated',{source='native object.posMM',anchors=#points}) end
    end
    return fit.project and fit.project(pos)
end
function A:clickMinimap(map,destination)
    local c=self.ctx
    if self:cursorBusy() or not Game.cursorPos or not Control.SetCursorPos then return false,'cursor API unavailable' end
    if not Control.mouse_event and not Control.RightClick then return false,'native click API unavailable' end
    if self:hasCursorQueue() then
        local point={x=math.floor(map.x+.5),y=math.floor(map.y+.5)}
        return self:dispatchCursor(MOUSEEVENTF_RIGHTDOWN or 8,point,'farm',false,nil,nil,nil,destination)
    end
    local before=Game.cursorPos();if not before then return false,'cursor position unavailable' end
    local original={x=before.x,y=before.y}
    local point={x=math.floor(map.x+.5),y=math.floor(map.y+.5)}
    local synthetic=c.synthetic;c.synthetic=true;c.syntheticMouseUntil=c:now()+.08
    local cursor=c.sdk.Cursor
    local ok,err=pcall(function()
        Control.SetCursorPos(point.x,point.y)
        if U.screenDist(Game.cursorPos(),point)>6 then error('minimap cursor placement unconfirmed') end
        if Control.mouse_event then
            local pressed,reason=pcall(Control.mouse_event,MOUSEEVENTF_RIGHTDOWN or 8)
            local released=pcall(Control.mouse_event,MOUSEEVENTF_RIGHTUP or 16)
            if not pressed or not released then error(reason or 'right-click release failed') end
        else Control.RightClick(point.x,point.y) end
    end)
    if ok then
        self.minimapLease={point=point,original=original,restoreAt=c:now()+.10}
    elseif not ok and not (cursor and cursor.Step>0) and U.screenDist(Game.cursorPos(),point)<=6 then
        pcall(Control.SetCursorPos,original.x,original.y)
    end
    if c.config.capture then c:log('minimap_click_requested',{point=point,original=original,accepted=ok,
        dispatcher='native deferred',reason=not ok and tostring(err) or nil}) end
    c.synthetic=synthetic
    return ok,not ok and tostring(err) or nil
end
function A:groundWaypoint(destination)
    local c=self.ctx;local distance=U.dist(myHero.pos,destination)
    -- Screen-visible final destinations go straight to native pathfinding.
    -- A conservative terrain cell must not replace a camp with a near-wall stop.
    if U.vector(destination):To2D().onScreen then self.groundJob=nil;return destination end
    for length=math.min(1100,distance),300,-100 do
        local direct=U.toward(myHero.pos,destination,length)
        if U.vector(direct):To2D().onScreen and c.terrain:clearance(direct,35,true) then self.groundJob=nil;return direct end
    end
    if not c.terrain:trusted() then return end
    local job=self.groundJob
    if not job or U.dist(job.goal,destination)>50 or U.dist(job.origin,myHero.pos)>100 then
        job={goal=U.copy(destination),origin=U.copy(myHero.pos)}
        job.work=coroutine.create(function()
            return require('lho.navigation').approach(c.terrain,job.origin,job.goal,math.max(50,distance-300),1400,
                function()coroutine.yield()end,function(p)return U.vector(p):To2D().onScreen end,true)
        end);self.groundJob=job
    end
    if not job.done and job.stepAt~=c:now() then
        job.stepAt=c:now();local ok,path=coroutine.resume(job.work)
        if not ok then self.groundJob=nil;if c.config.capture then c:log('route_ground_failed',{reason=tostring(path)}) end;return end
        if coroutine.status(job.work)=='dead' then job.done=true;job.path=path end
    end
    if job.path then
        -- Skip reached nodes and prefer the furthest visible endpoint. Native
        -- movement supplies the turns; never click Lee's current coordinates.
        for index=#job.path,1,-1 do
            local point=job.path[index]
            if U.dist(myHero.pos,point)>100 and U.vector(point):To2D().onScreen
                and c.terrain:clearance(point,35,true) then return point end
        end
    end
    if job.done then self.groundJob=nil end
end
function A:followCamera()
    local c=self.ctx;local now=c:now()
    if _G.LHO_CameraCleanup then return false end
    if not c.config:get('farmFollowCamera') or not c.config:get('autoJungle') or c:blocked()
        or c:recalling() or c.leveling.pending then return false end
    -- Dash camera easing is not a lock-state change. Discard the pre-dash
    -- reference and wait for a fresh ordinary-walking observation afterwards.
    if c:dash() then
        self.cameraSample=nil;self.cameraLostSamples=0
        self.cameraResumeAt=now+math.max(.2,c.latency+(c.jitter or 0)*2)
        return false
    end
    if now<(self.cameraResumeAt or 0) then self.cameraSample=nil;return false end
    local screen=U.vector(myHero.pos):To2D()
    local sample=self.cameraSample
    if not sample then
        self.cameraSample={world=U.copy(myHero.pos),screen=U.copy(screen),at=now};return false
    end
    -- Infer follow only from sustained actual movement, never from centring.
    -- This is observational evidence, not a native lock-state API.
    local travel=U.dist(myHero.pos,sample.world)
    -- Also reject a dash/teleport that completed between callbacks. Ordinary
    -- running cannot cover this displacement in the measured interval.
    if travel>math.max(1,myHero.ms or 350)*math.max(0,now-sample.at)+80 then
        self.cameraSample={world=U.copy(myHero.pos),screen=U.copy(screen),at=now}
        self.cameraLostSamples=0
        self.cameraResumeAt=now+math.max(.2,c.latency+(c.jitter or 0)*2)
        return false
    end
    if travel<80 then return false end
    local shift=U.screenDist(screen,sample.screen)
    local resolution=Game.Resolution and Game.Resolution()
    local scale=(resolution and resolution.y or 1080)/1080
    local following=travel>=160 and screen.onScreen~=false and sample.screen.onScreen~=false and shift<=12*scale
    -- Reproject the SAME world landmark. Hero displacement alone cannot tell
    -- unlocked camera from follow easing, a map-edge clamp or a dash.
    local landmark=U.vector(sample.world):To2D()
    local cameraShift=U.screenDist(landmark,sample.screen)
    local unlocked=travel>=160 and now-sample.at>=.45 and shift>=30*scale and cameraShift<=5*scale
    if not following and not unlocked then return false end
    self.cameraSample={world=U.copy(myHero.pos),screen=U.copy(screen),at=now}
    if c.config.capture then c:log('camera_follow_observed',{following=following,travel=travel,screenShift=shift,cameraShift=cameraShift}) end
    if following then
        self.cameraLostSamples=0
        self.cameraFollowing=true
        if self.cameraOwned then self.cameraOwned.confirmed=true end
        return false
    end
    -- Observation is never evidence of a physical takeover. Preserve the lease
    -- so EVERY stop path can restore our toggle. Physical Z is handled by Input.
    if self.cameraFollowing then
        return false
    end
    if self.cameraToggleAt or self:cursorBusy() then return false end
    -- Locked cameras can hit map boundaries at base. Do not infer their toggle
    -- state there, and require two independent stationary-camera observations.
    local spawn=c.farm and c.farm:spawn()
    if spawn and U.dist(myHero.pos,spawn)<1400 then self.cameraLostSamples=0;return false end
    self.cameraLostSamples=(self.cameraLostSamples or 0)+1
    if self.cameraLostSamples<2 then return false end
    local key=c.config:key('farmCameraKey')
    if not key or key<=0 then return false end
    local accepted,reason,submitted=self:cameraKey(key)
    if accepted or submitted then
        self.cameraToggleAt=now
        if accepted then self.cameraOwned={key=key,at=now,wasFollowing=false} end
        self.cameraSample={world=U.copy(myHero.pos),screen=U.copy(screen),at=now}
        if c.config.capture then c:log('camera_lock_requested',{key=key,accepted=accepted,reason=reason,
            evidence='Screen displacement while moving; awaiting follow confirmation'}) end
    end
    return accepted
end

function A:move(pos,owner)
    local c=self.ctx;local now=c:now()
    local plannedKite=owner=='farm' and c.farm and c.farm.kiteStep
    local transition=plannedKite and plannedKite.key and (self.lastKiteKey~=plannedKite.key or self.lastKitePhase~=plannedKite.phase)
    self.lastCursorAction=nil
    if self:smiteOwnsInput() then return false,'Lethal Smite awaiting target verification' end
    local ward=c.wards and c.wards.pending;local cursor=c.sdk.Cursor;local lease=c.cursorLease
    local follow=owner=='ward' and ward and ward.state=='jumping' and (c:dash() or c:stage(1)==2)
    local chain=not self.api and follow and cursor and (cursor.Step or 0)>=1 and cursor.Step<=3 and lease and lease.owner==owner
        and cursor.CastPos==lease.castPos and cursor.Keys and #cursor.Keys==1 and cursor.Keys[1]==HK_W
        and cursor.CursorPos and type(cursor.Add)=='function' and type(cursor.StepPressKey)=='function'
        and type(cursor.StepSetToCastPos)=='function' and type(cursor.StepSetToCursorPos)=='function'
    local restore=chain and cursor.CursorPos
    if owner=='farm' and pos and U.dist(myHero.pos,pos)<25 then return false,'destination reached' end
    if not pos or c:blocked() or c:recalling() or (c.leveling and c.leveling.pending)
        or (self:cursorBusy() and not chain) or (now<(self.nextMove or 0) and not follow and not transition) then
        return false,self:cursorBusy() and self:cursorWaitReason() or c.leveling and c.leveling.pending and 'skill allocation pending' or 'input / movement cooldown'
    end
    local orb=c.sdk.Orbwalker
    if orb:IsAutoAttacking() or not orb:CanMove() or orb.MovementEnabled==false or orb.ForceMovement then return false end
    if orb.Menu and orb.Menu.MovementEnabled and not orb.Menu.MovementEnabled:Value() then return false end
    local p=U.vector(pos);c.dispatchMovement=p
    local args={Target=p,Process=true}
    local hooksOK=pcall(function() for _,fn in ipairs(orb.OnMoveCb or {}) do fn(args) end end)
    c.dispatchMovement=nil
    if not hooksOK or not args.Process or not args.Target then return false,'GG movement hook veto' end
    if owner=='farm' and U.dist(pos,args.Target)>80 then return false,'GG hook changed the camp destination' end
    p=U.vector(args.Target)
    local combat=owner=='farm' and c.farm and (c.farm.state=='clearing' or c.farm.state=='finishing')
    local kite=combat and c.farm.kiteStep
    if kite and kite.command and U.dist(kite.command.pos,p)<35 then
        local path=myHero.pathing
        if now-kite.command.at<.6 or path and path.hasMovePath and path.endPos and U.dist(path.endPos,p)<50 then
            return true,'kite command already active'
        end
    end
    local routing=owner=='farm' and not combat and U.dist(myHero.pos,p)>300
    local command=self.routeCommand
    if routing and command and U.dist(command.goal,p)<80 and U.dist(myHero.pos,command.sent)>160 then
        if U.dist(myHero.pos,command.progressPos)>35 then
            command.progressPos=U.copy(myHero.pos);command.progressAt=now
        end
        local path=myHero.pathing
        local following=path and path.hasMovePath and path.endPos and U.dist(path.endPos,command.sent)<150
        -- A new command gets a short acknowledgement window. Thereafter retain
        -- it while movement progresses; bounded retries recover rejected input.
        if now-command.at<.8 or following and now-command.progressAt<1.5
            or not command.uncertain and now-command.progressAt<.6 then
            return true,command.uncertain and 'Observing current route' or 'route already active'
        end
    elseif not routing then self.routeCommand=nil end
    local sent=U.copy(p)
    c.synthetic=true; c.syntheticMouseUntil=now+.08
    local screen=p:To2D()
    local travelMap=not c.sdk.NativeTransport and owner=='farm' and routing and U.dist(myHero.pos,p)>600 and c.config:get('farmMinimap') and self:minimap(p)
    local minimap=not not travelMap or not screen.onScreen
    -- Screen movement retains precise monster coordinates. Minimap pixels are
    -- a fallback for offscreen travel, not a reason to round a visible endpoint.
    local ok,result,moveReason,projection,moveDetail
    if c.sdk.NativeTransport then
        minimap=false
        result,moveReason=self:dispatchNative(MOUSEEVENTF_RIGHTDOWN or 8,p,owner);ok=true
    elseif not minimap then
        c.dispatchMovement=p
        if self:hasCursorQueue() or owner=='farm' then
            result,moveReason,moveDetail=self:worldMove(p,owner,chain);ok=true
            if result and moveDetail and moveDetail.movementDestination then sent=moveDetail.movementDestination end
        elseif Control.Move then
            -- GG Orbwalker:Move checks cursor hold-radius before OnPreMovement.
            -- Its explicit Control.Move API accepts a destination independently
            -- of the physical cursor; preserve every registered movement hook.
            ok,result=pcall(Control.Move,p)
        else ok,result=pcall(orb.Move,orb);result=ok end
        c.dispatchMovement=nil
        -- GG Move has no return value; its own CanMove / menu / hooks decide dispatch.
    else
        local map=travelMap or (owner~='farm' or c.config:get('farmMinimap')) and self:minimap(p)
        projection=map or nil
        if map and owner=='farm' and Control.SetCursorPos and (Control.mouse_event or Control.RightClick) then
            result,moveReason=self:clickMinimap(map,p);ok=true
        elseif map and self.api then
            result,moveReason=self:dispatchCursor(MOUSEEVENTF_RIGHTDOWN or 8,map,owner,false,nil,nil,nil,p);ok=true
        elseif map and c.sdk.Cursor and c.sdk.Cursor.Add then
            ok,result=pcall(c.sdk.Cursor.Add,c.sdk.Cursor,MOUSEEVENTF_RIGHTDOWN or 8,map)
        end
        if not map and owner=='farm' and Control.Move then
            local waypoint=self:groundWaypoint(p)
            if waypoint then
                sent=U.copy(waypoint)
                c.dispatchMovement=U.vector(waypoint);result,moveReason,moveDetail=self:worldMove(c.dispatchMovement);ok=true;c.dispatchMovement=nil
                if result and moveDetail and moveDetail.movementDestination then sent=moveDetail.movementDestination end
                c.status=c.status..' | ground route (native minimap projection unavailable)'
            end
        end
        if not ok or not result then
            local reason=moveReason or (map and 'Minimap input rejected' or 'Native minimap projection unavailable; finding ground route')
            moveReason=reason
            if self.moveFailure~=reason then self.moveFailure=reason;if c.config.capture then c:log('route_move_failed',{reason=reason,destination=U.copy(p),projection=map}) end end
        else self.moveFailure=nil end
    end
    if chain and not c.sdk.Input then
        cursor.CursorPos=restore;c.cursorLease={castPos=cursor.CastPos,owner=owner}
        if not ok or not result then pcall(cursor.StepSetToCursorPos,cursor) end
    end
    c.synthetic=false
    if ok and result then
        if routing then self.routeCommand={goal=U.copy(p),sent=sent,at=now,progressAt=now,progressPos=U.copy(myHero.pos)} end
        if owner=='farm' and (not self.lastRouteGoal or U.dist(self.lastRouteGoal,p)>100) then
            self.lastRouteGoal=U.copy(p)
            if c.config.capture then c:log('route_move_started',{destination=U.copy(p),dispatchedDestination=sent,origin=U.copy(myHero.pos),projection=projection,
                cursorID=self.lastCursorAction,
                transport=c.sdk.NativeTransport and 'native world' or projection and 'minimap' or minimap and 'ground fallback' or 'screen',qRank=c:spell(0).level}) end
        end
        if routing then self.routeObservation={origin=U.copy(myHero.pos),destination=U.copy(p),sent=sent,at=now,
            cursorID=self.lastCursorAction,
            transport=c.sdk.NativeTransport and 'native world' or projection and 'minimap' or minimap and 'ground fallback' or 'screen'} end
        if not self.api and self:cursorBusy() then c.cursorLease={castPos=c.sdk.Cursor.CastPos,owner=owner} end
        if kite then
            kite.command={pos=U.copy(p),at=now}
            self.lastKiteKey=kite.key;self.lastKitePhase=kite.phase
        end
        local action=self.lastCursorAction and c.sdk.Input and c.sdk.Input:GetAction(self.lastCursorAction)
        self.nextMove=now+.12;if c.config.capture then c:log(action and not action.sentAt and 'move_requested' or 'move_dispatched',
            {owner=owner,minimap=minimap,cursorID=self.lastCursorAction}) end;return true
    end
    return false,moveReason or 'GG movement declined'
end
return A

end
modules["lho.actionstate"] = function(require)
local U=require('lho.util')
local toggles={autoJungle='farm',autosmite='autosmite'}
return function(a)
    a.slotUncertainty={};a.ownerGeneration={};a.activation={};a.releasedIntent={}
    a.toggleObserved={}
    for key in pairs(toggles) do a.toggleObserved[key]={value=a.ctx.config:get(key),serial=(a.ctx.config.writeSerial or {})[key]} end
    function a:physicalIntent(owner,down)
        if not down then self.releasedIntent[owner]=true;return end
        if self.releasedIntent[owner] then
            self.activation[owner]=(self.activation[owner] or 0)+1;self.releasedIntent[owner]=nil
        end
    end
    function a:quarantine(slot,event,r)
        if not self.api or not r or r.state~='send_uncertain' then return end
        if not event.keyAt and r.sentAt then event.keyTick=r.sentAt;event.keyAt=self.ctx:now()-(self.api:Now()-r.sentAt)*.001 end
        self.slotUncertainty[slot]=self.slotUncertainty[slot] or {event=event,at=self.ctx:now()}
        event.status='input_uncertain';self.pending[slot]=nil
    end
    function a:refreshUncertainty()
        local c=self.ctx;local now=c:now()
        -- Menu changes are observable separately from internal config:set()
        -- writes. Hotkey toggles already report their physical event directly.
        for key,owner in pairs(toggles) do
            local seen=self.toggleObserved[key];local value=c.config:get(key);local serial=(c.config.writeSerial or {})[key]
            if seen.serial==serial and value~=seen.value then
                self:physicalIntent(owner,value);if not value then self:cancel(owner) end
            end
            seen.value=value;seen.serial=serial
        end
        for slot,lock in pairs(self.slotUncertainty) do
            local e=lock.event;local d=c:spell(slot);local stage=slot<3 and c:stage(slot)
            local active=myHero.activeSpell
            local observed=active and active.valid and U.name(active.name)==U.name(e.before.name)
                and U.finite(active.startTime) and active.startTime>=(e.keyAt or e.at) and active.startTime<=now
            if slot<3 and e.stage==2 then
                local yes,evidence=require('lho.recasts').evidence(c,slot,e.recastBefore,e.keyAt)
                observed=yes;e.recastEvidence=evidence
            end
            if slot<3 and e.stage==1 and (stage==2 or (d.currentCd or 0)>(e.before.cd or 0)+.05) then observed=true end
            if slot>=3 and (d.currentCd or 0)>(e.before.cd or 0)+.05 then observed=true end
            if observed and not lock.executionObserved then
                lock.executionObserved=true;e.executionObservedAt=now
                local at=active and active.valid and U.name(active.name)==U.name(e.before.name) and U.finite(active.startTime) and active.startTime>=(e.keyAt or e.at)
                    and active.startTime<=now and active.startTime or now
                if slot<4 and c.clear then c.clear:executed(slot,e.stage,at) end
                self.scope:Observe(e.cursorID,{kind='mechanical',source='spell_state_after_uncertain_input',unique=true,at=self.api:Now()})
            end
            local newCycle=lock.cooldownSeen and (d.currentCd or 0)==0 and (slot>=3 or stage==1) and c:ready(slot)
            if (d.currentCd or 0)>0 then lock.cooldownSeen=true end
            local availability=self.api:GetAvailability()
            local deliberate=(self.activation[e.owner] or 0)>(e.activation or 0)
            if not availability.cleanupPending and not availability.uncertain and availability.available
                and (lock.executionObserved or newCycle or deliberate) then
                self.slotUncertainty[slot]=nil
                e.resolvedAt=now;e.resolution=lock.executionObserved and 'execution_observed' or newCycle and 'new_ready_cycle' or 'physical_reactivation'
                if c.config.capture then c:log('slot_uncertainty_resolved',{slot=slot,cursorID=e.cursorID,reason=e.resolution}) end
            end
        end
    end
end

end
modules["lho.actives"] = function(require)
local U=require('lho.util')
local I={};I.__index=I
-- Explicit active mechanics from Riot 16.17.1. Passive-only items are absent.
local normal={
    [3077]={range=400,group='itemCleave'},[3074]={range=400,group='itemCleave'},
    [3748]={range=300,group='itemCleave',reset=true},[6698]={range=400,group='itemCleave'},
    [6631]={range=400,group='itemCleave'},[3143]={range=500,group='itemSlow',damage=false,champion=true},
    [3142]={range=700,group='itemSpeed',damage=false,champion=true},
    [2065]={range=700,group='itemSpeed',damage=false,champion=true},
    [3146]={range=600,group='itemTargeted',targeted=true,champion=true},
    [3140]={range=0,group='itemCleanse',damage=false,cleanse=true},[3139]={range=0,group='itemCleanse',damage=false,cleanse=true},
    [3190]={range=600,group='itemShield',damage=false,shield=true}}
local classic={
    [773077]={range=400,group='itemCleave'},[773074]={range=400,group='itemCleave'},
    [773143]={range=500,group='itemSlow',damage=false,champion=true},
    [773144]={range=450,group='itemTargeted',targeted=true,champion=true},
    [773153]={range=450,group='itemTargeted',targeted=true,champion=true},
    [773146]={range=600,group='itemTargeted',targeted=true,champion=true},
    [773142]={range=600,group='itemSpeed',damage=false,attackSpeed=true},
    [773069]={range=700,group='itemSpeed',damage=false,champion=true},
    [773140]={range=0,group='itemCleanse',damage=false,cleanse=true},[773139]={range=0,group='itemCleanse',damage=false,cleanse=true},
    [773190]={range=600,group='itemShield',damage=false,shield=true}}
local potions={normal={[2003]={heal=120,duration=15},[2031]={heal=100,duration=12,charge=true},[2033]={heal=100,duration=12,charge=true}},
    classic={[772003]={heal=150,duration=15},[773521]={heal=150,duration=15},[772041]={heal=120,duration=12,charge=true}}}
local healing={regenerationpotion=true,healthpotion=true,item2003=true,itemcrystalflask=true,
    itemminiregenpotion=true,itemdarkcrystalflask=true,crystalflask=true}
local cleanseTypes={[5]=true,[7]=true,[8]=true,[9]=true,[10]=true,[12]=true,[22]=true,[23]=true,[25]=true,[26]=true,[29]=true,[35]=true}
function I.new(ctx,actions) return setmetatable({ctx=ctx,actions=actions},I) end
function I:rule(id) return (self.ctx.profile.id=='classic' and classic or normal)[id] end
function I:potionAllowed(slot,owner,owned)
    local c=self.ctx;local now=c:now()
    local enabled=owner=='farm' and c.config:get('potionAuto') or owner=='clear' and c.config:get('potionJungle') or owner=='fight' and c.config:get('potionFight')
    if not c.config:get('potions') or not enabled or c:blocked() or c:recalling() or c:dash()
        or (c.farm and c.farm:spawn() and U.dist(myHero.pos,c.farm:spawn())<550) or U.hp(myHero)>c.config:get('potionHP') or U.buff(myHero,healing,now)
        or not owned and now<(self.potionUntil or 0) then return false end
    local item=myHero:GetItemData(slot);local rule=item and potions[c.profile.id][item.itemID]
    if not rule or myHero.maxHealth-myHero.health<rule.heal*.8 then return false end
    local spell=c:spell(slot)
    local count=rule.charge and math.max(spell.ammo or 0,item.ammo or 0,c.profile.id=='classic' and U.stackCount(item) or 0) or U.stackCount(item)
    return count>0 and c:ready(slot),rule
end
function I:potions(owner)
    if self.potionRequest then
        local pending=self.potionRequest;local r=self.actions:inputAction(pending.event.cursorID)
        if r and r.sentAt then
            self.potionUntil=self.ctx:now()-math.max(0,self.actions:inputNow()-r.sentAt)*.001+pending.duration
            self.potionRequest=nil
        elseif pending.event.gameplayCancelled or r and r.state=='cancelled_before_send' then self.potionRequest=nil
        else return false end
    end
    for slot=6,11 do
        local allowed,rule=self:potionAllowed(slot,owner)
        if allowed then
            local accepted,event=self.actions:cast(slot,nil,owner,{validate=function()
                -- Our provisional potion lock belongs to this request only.
                local ok=self:potionAllowed(slot,owner,true);return ok,'potion_no_longer_needed'
            end})
            if accepted then
                if self.actions.api then self.potionRequest={event=event,duration=rule.duration}
                else self.potionUntil=self.ctx:now()+rule.duration end
                return true
            end
        end
    end
    return false
end
function I:needsCleanse()
    if self.ctx.actions.originalGG then return false end -- GG owns QSS; no claim/cancel API.
    local found=false;local now=self.ctx:now()
    for _,b in ipairs(U.buffs(myHero)) do
        if (U.buffEnd(b) or now+1)>now+.15 then
            if b.type==30 or b.type==31 then return false end
            if cleanseTypes[b.type] then found=true end
        end
    end
    return found
end
function I:needsShield(range)
    local c=self.ctx
    for _,list in ipairs({{myHero},c.allies or {}}) do for _,ally in ipairs(list) do
        if U.valid(ally) and U.dist(myHero.pos,ally.pos)<=range and U.hp(ally)<=c.config:get('shieldHP')
            and c:threats(ally.pos,700)>0 then return true end
    end end
    return false
end
function I:defenseAllowed(slot)
    local c=self.ctx;local item=myHero:GetItemData(slot);local rule=item and self:rule(item.itemID)
    if not c.config:get('items') or not c.config:get('idleDefense') or not rule or not c.config:get(rule.group) then return false end
    if rule.cleanse and self.actions.capabilities and self.actions.capabilities.automationClaims then
        self.actions:syncAutomation()
        if not self.actions.qssClaim then return false end
    end
    return rule.cleanse and self:needsCleanse() or rule.shield and self:needsShield(rule.range)
        or rule.group=='itemSlow' and U.hp(myHero)<=c.config:get('shieldHP') and c:threats(myHero.pos,rule.range)>0
end
function I:defense(owner)
    for slot=6,11 do
        if self:defenseAllowed(slot) and self.actions:cast(slot,nil,owner or 'defense',{interrupt=true,
            validate=function()return self:defenseAllowed(slot),'defense_no_longer_needed' end}) then return true end
    end
    return false
end
function I:itemAllowed(slot,target)
    local c=self.ctx
    if not c.config:get('items') or not U.valid(target) or c:dash() or c.sdk.Orbwalker:IsAutoAttacking() then return false end
    local champion=target.team~=300 and target.team~=myHero.team and target.type==myHero.type
    local item=myHero:GetItemData(slot);local rule=item and self:rule(item.itemID)
    if not rule or not c.config:get(rule.group) or rule.cleanse or rule.shield or rule.champion and not champion
        or U.dist(myHero.pos,target.pos)>rule.range then return false end
    local useful=true
    if rule.reset then useful=c.lastAttackFinished and c:now()-c.lastAttackFinished<.3 and U.dist(myHero.pos,target.pos)<=c:attackRange(target) end
    if rule.group=='itemSpeed' then useful=rule.attackSpeed and (champion or target.health>c:aaDamage(target)*4)
        or champion and U.dist(myHero.pos,target.pos)>c:attackRange(target)+50 end
    return useful,rule
end
function I:tick(target,owner)
    for slot=6,11 do
        local useful,rule=self:itemAllowed(slot,target)
        if useful and self.actions:cast(slot,rule.targeted and target or nil,owner,{intendedTarget=target,
            validate=function()return self:itemAllowed(slot,target) end}) then return true end
    end
    return false
end
return I

end
modules["lho.aim"] = function(require)
local U=require('lho.util')
local A={}
function A.reject(actions,record,target)
    if not record or not record.sentAt or not record.aim or record.aim.source~='client_projection' then return end
    local old=actions.aimTrial
    if old and old.action==record.id then return end
    actions.aimTrial={target=U.id(target),action=record.id,at=actions.ctx:now(),
        index=old and old.target==U.id(target) and (old.index+1)%5 or 1}
    actions.bodyPoint=nil
end
-- Read-only candidate provider; successful observations update the cache elsewhere.
function A.points(actions,target,preferIsolated)
    local p=U.vector(target.pos):To2D();local size=Game.Resolution and Game.Resolution()
    if not p or p.onScreen==false or not size then return {} end
    local origin=U.vector(myHero.pos):To2D();local old=actions.bodyPoint
    local out={};local scale=math.max(.5,math.min(3,size.y/1080))
    local function add(x,y)
        if x<0 or y<0 or x>=size.x or y>=size.y then return end
        for _,q in ipairs(out) do if U.screenDist(q,{x=x,y=y})<2 then return end end
        if #out<5 then out[#out+1]={x=x,y=y} end
    end
    if old and U.same(old.target,target) and actions:inputNow()-old.at>=0 and actions:inputNow()-old.at<1000
        and old.width==size.x and old.height==size.y and U.screenDist(old.projection,p)<12
        and U.screenDist(old.origin,origin)<12 then add(old.point.x,old.point.y) end
    -- When the host has no hover identity, start with an isolated body point
    -- instead of spending a positioning phase on ground that cannot qualify.
    if preferIsolated then
        local scene=require('lho.ground').scene(actions.ctx)
        -- Evaluate lateral candidates too before acquiring the cursor. Otherwise
        -- a reachable side of a crowded monster may be last in the list and
        -- never reached before the bounded positioning budget expires.
        local offsets={{0,60},{0,30},{0,15},{-18,30},{18,30}}
        local trial=actions.aimTrial
        local start=trial and trial.target==U.id(target) and actions.ctx:now()-trial.at<5 and trial.index or 0
        for i=1,#offsets do
            local offset=offsets[(start+i-1)%#offsets+1]
            local point={x=p.x+offset[1]*scale,y=p.y-offset[2]*scale}
            if A.isolated(actions.ctx,target,point,scene) then add(point.x,point.y);break end
        end
    end
    add(p.x,p.y);add(p.x,p.y-60*scale);add(p.x,p.y-30*scale)
    add(p.x-18*scale,p.y-45*scale);add(p.x+18*scale,p.y-45*scale)
    return out
end
function A.isolated(c,target,point,scene)
    if not U.valid(target) or target.team~=300 or not point then return false end
    local screen=U.vector(target.pos):To2D();local size=Game.Resolution and Game.Resolution()
    if not screen.onScreen or not size then return false end
    local scale=math.max(.5,math.min(3,size.y/1080))
    -- Only a central body point, never an unrelated ground position. Nearby
    -- projected bodies reject this approximation; native identity wins always.
    if math.abs(point.x-screen.x)>20*scale or point.y>screen.y-10*scale or point.y<screen.y-80*scale then return false end
    return not require('lho.ground').screenBlocker(c,point,target,scene)
end
function A.remember(actions,r,target)
    local aim=r and r.aim
    if not aim or not aim.hoverConfirmed or not aim.position or not r.sentAt then return end
    local size=Game.Resolution and Game.Resolution();if not size then return end
    actions.bodyPoint={target=target,point=U.copy(aim.position),projection=U.vector(target.pos):To2D(),
        origin=U.vector(myHero.pos):To2D(),at=aim.confirmedAt,width=size.x,height=size.y}
end
return A

end
modules["lho.app"] = function(require)
local U=require('lho.util');local P=require('lho.profiles')
local App={};App.__index=App
function App.new(options)
    local p=assert(P.get(myHero.charName),'Unsupported champion')
    local c=require('lho.runtime').new(p,require('lho.config').new(p))
    c.originalGG=options and options.originalGG==true
    c.actions=require('lho.actions').new(c)
    c.input=require('lho.input').new(c)
    c.terrain=require('lho.terrain').new(c)
    c.wards=require('lho.wards').new(c,c.actions,c.terrain)
    c.smite=require('lho.smite').new(c,c.actions)
    c.spells=require('lho.spells').new(c,c.actions,c.smite)
    c.emergencyShield=require('lho.emergencyshield').new(c)
    c.combat=require('lho.combat').new(c,c.actions,c.spells,c.wards)
    c.leveling=require('lho.leveling').new(c)
    c.farm=require('lho.farm').new(c,c.actions,c.spells,c.smite)
    c.clear=require('lho.clear').new(c)
    c.wave=require('lho.wave').new(c)
    c.actives=require('lho.actives').new(c,c.actions)
    c.damageModel=require('lho.damage').new(c)
    c.overlay=require('lho.overlay').new(c)
    c.guide=require('lho.guide').new(c)

    c.aim=c:playerPosition()
    return setmetatable({ctx=c,active=true,hooks={},build=require('lho.profiles').build},App)
end
function App:ggMode(name)
    local c=self.ctx;local id=c.sdk['ORBWALKER_MODE_'..name]
    if id==nil then return false end
    local orb=c.sdk.Orbwalker
    if orb.HasMode then return orb:HasMode(id) end
    return orb.Modes and orb.Modes[id] or false
end
function App:localClearTarget()
    return self.ctx.farm:localTarget(self:ggMode('LANECLEAR'),self:ggMode('JUNGLECLEAR'))
end
function App:mode()
    local c=self.ctx;local i=c.input
    if c:blocked() then return 'blocked' end
    i:reconcileSuspended()
    if next(i.suspended) then return 'reserved' end
    if i:held('wardKey') then return 'ward' end
    if i:held('cursorKey') then return 'cursor' end
    if i:held('allyKey') then return 'ally' end
    if i:held('secureKey') then return 'secure' end
    if i:held('qKey') then return 'q' end
    if c.wards.pending then return 'ward_pending' end
    if self:ggMode('COMBO') then return 'fight' end
    if self:ggMode('LASTHIT') then return 'gg_last' end
    if self:ggMode('LANECLEAR') or self:ggMode('JUNGLECLEAR') then return 'clear' end
    if self:ggMode('HARASS') then return 'harass' end
    if self:ggMode('FLEE') then return 'gg' end
    if c.config:get('autoJungle') then return 'farm' end
    return 'idle'
end
function App:impact(target)
    local c=self.ctx;local speed=c.sdk.Attack and c.sdk.Attack.GetProjectileSpeed and c.sdk.Attack:GetProjectileSpeed() or math.huge
    return c:windup()+c.latency*.5+(speed>0 and U.dist(myHero.pos,target.pos)/speed or 0)
end
function App:laneMinion(target)
    if not U.valid(target) or target.team==300 or target.team==myHero.team then return false end
    for _,m in ipairs(self.ctx.minions or {}) do if U.same(m,target) then return true end end
    return false
end
function App:preAttack(args)
    if not self.active then return end
    local c=self.ctx;local mode=self:mode()
    if not c.config:get('enabled') then return end
    if c.actions:smiteOwnsInput() then args.Process=false;return end
    if mode=='idle' then return end
    if mode=='blocked' or c.wards.pending or c.leveling.pending or c:dash()
        or mode=='fight' and c:combatTransit() then args.Process=false;return end
    if not args.Process then return end
    if (mode=='gg_last' or mode=='clear') and self:laneMinion(args.Target) and c.wave:attackLocked() then
        args.Process=false;return
    end
    if mode=='gg_last' then
        if self:laneMinion(args.Target) then
            if c.wave:tick(args.Target,true,true) then args.Process=false
            else
                local other,last=c.wave:attackTarget(args.Target)
                if other and last then args.Target=other
                elseif c.wave:reservedTarget(args.Target) then args.Process=false end
            end
        end
        return
    end
    if mode=='harass' or mode=='gg' then return end
    local target
    if mode=='fight' then
        -- GG already chose this attack using its own priorities and selection.
        if c.sdk.TargetSelector and c.sdk.TargetSelector.GetTarget then
            target=args.Target
            if c:enemyValid(target) then c.attackFocus={target=target,at=c:now(),selected=c:locked()} end
        else target=c:target(c.profile.q2Range) end
    elseif mode=='clear' then
        local anchor=self:localClearTarget()
        if anchor and anchor.team~=300 then
            if c.wave:tick(anchor,true) then args.Process=false;return end
            target=c.wave:attackTarget(anchor)
        else target=anchor end
    elseif mode=='farm' then
        target=c.attackTarget
        if P.epics[P.category(args.Target and args.Target.charName)] or P.epics[P.category(target and target.charName)] then args.Process=false;return end
        if target and not self:laneMinion(target) and target.team~=300 then target=nil end
    elseif mode=='cursor' or mode=='ally' then
        if self.insecSuppressed or not c.combat:insecOrbwalkAllowed() then args.Process=false;return end
        target=c.attackTarget
    end
    if args.Approach then
        args.Process=mode=='farm' and U.valid(target) and U.same(target,args.Target)
            and (c.farm.kiteStep and c.farm.kiteStep.phase=='attack'
                or (c.farm.state=='clearing' or c.farm.state=='finishing')
                    and U.dist(myHero.pos,target.pos)>c:attackRange(target)) or false
        return
    end
    if not U.valid(target) or U.dist(myHero.pos,target.pos)>c:attackRange(target) then args.Process=false;return end
    args.Target=target
    if (mode=='farm' or mode=='clear' and target.team==300) and c.clear:tick(target,mode,true) then args.Process=false end
end
function App:preMove(args)
    if not self.active then return end
    local c=self.ctx;local mode=self:mode()
    if not c.config:get('enabled') then return end
    if c.actions:smiteOwnsInput() then args.Process=false;return end
    if mode=='idle' then return end
    if (mode=='cursor' or mode=='ally') and not c.dispatchMovement then args.Process=false;return end
    if (c.wards.pending and not ((c.wards.pending.state=='approaching'
        or c.wards.pending.state=='jumping' and c.wards.pending.owner=='ward' and c.config:get('wardFollowCursor')) and c.dispatchMovement))
        or c.leveling.pending or mode=='blocked' then args.Process=false;return end
    -- Local clear inherits GG cursor orbwalking immediately, including when
    -- jungle and lane clear share a key. Routing/kiting ownership belongs to J.
    if mode=='fight' or mode=='clear' or mode=='gg_last' or mode=='harass' or mode=='gg' then
        if not c.sdk.Orbwalker.ForceMovement then
            local destination=args.Target or (c.sdk.Cursor.GetPlayerPosition and c.sdk.Cursor:GetPlayerPosition()) or c.aim or mousePos
            if destination then
                local point=require('lho.ground').select(c,destination.pos or destination)
                if point then args.Target=U.vector(point) else args.Process=false end
            end
        end
        return
    end
    if not c.dispatchMovement or c.sdk.Orbwalker.ForceMovement then args.Process=false;return end
    args.Target=U.vector(c.dispatchMovement)
end
function App:cancel(reason,manual)
    local c=self.ctx;c.wards:cancel(reason);c.combat:cancel();c.leveling:cancel()
    if c.mode=='cursor' or c.mode=='ally' then c.actions:cancel(c.mode) end
    c.actions:releaseMinimap(true,manual)
    c.actions.routeStop=nil;c.actions.routeObservation=nil
    c.spells.afterSmite=nil;c.combat.rFollow=nil;c.combat.multiTarget=nil
    c.attackTarget=nil;c.moveTarget=nil
end
function App:event(msg,param)
    if not self.active then return end
    local c=self.ctx
    if c.guide and c.guide:event(msg,param) then return end
    c.input:event(msg,param)
    if c.input.pressed.wardKey and c.input:held('wardKey') and not c.synthetic then
        c.input.wardContinuation=c.wards:retainCommitted()
        if not c.input.wardContinuation then c.wards:cancel('Wardjump re-aim',true);c.wards:resetPreview() end
        c.input.pressed.wardKey=nil
    end
    if msg==516 and c.input.cancel then c.localManualMovement=true end
    if c.input.cancel then
        self:cancel('Manual cancellation',true)
        c.input.pressed.cursorKey=nil;c.input.pressed.allyKey=nil
    end
    -- WndMsg can contain an entire tap between frames. Commit on the release event.
    if c.input.released.wardKey then
        c.input.released.wardKey=nil
        local continuation=c.input.wardContinuation;c.input.wardContinuation=nil
        if not continuation and not c.input.wardCancelled and not c:blocked() then
            if not c.actions:cursorBusy() then c.aim=c:playerPosition() end
            local preview=c.wards:releasePreview(c.aim)
            if preview.valid then
                if not c.wards:requestPlan(preview,'ward') then c.status='Wardjump could not be accepted' end
            else c.status=preview.reason or 'Invalid wardjump';c.wards:diagnostics(c.status);if c.config.capture then c:log('ward_invalid',{reason=c.status}) end end
        end
    end
    if c.combat.insec then
        local bind=c.combat.insec.kind=='cursor' and 'cursorKey' or 'allyKey'
        if not c.input:held(bind) then c.combat:cancel() end
        if c.combat.insec and not c.input:previewHeld() then c.combat:confirmPreview() end
    end
end
function App:secure()
    local c=self.ctx;local best
    for _,m in ipairs(c.minions or {}) do
        if m.team==300 and U.valid(m) and P.epics[P.category(m.charName)] and U.dist(myHero.pos,m.pos)<=c.profile.qRange then
            if not best or m.health<best.health then best=m end
        end
    end
    if not best then c.status='Secure: no visible epic in reach';return end
    c.status='Securing '..P.category(best.charName)
    if c.smite:cast(best,'secure',true) then return end
    if c:mark(best) then
        -- Current health only: never assume another player's future damage.
        local budget=c:damage(0,best,2)+(c.smite:ready() and c.smite:damage() or 0)
        if budget>=U.effectiveHP(best)+c.config:get('smiteMargin') then c.spells:q2(best,'secure',false) end
    elseif c:stage(0)==1 then c.spells:q1(best,'secure',false) end
end
function App:tick()
    if not self.active then return end
    local c=self.ctx;c.actions:tick();c:refresh()
    if c.config.bindings then c.config.bindings:sync() end
    -- A lethal objective gets the first legal cast opportunity before Q2,
    -- auto-leveling or ordinary combat can consume this tick's dispatcher.
    local previewInput=c.input:previewHeld() and (c.input:held('cursorKey') or c.input:held('allyKey'))
    if not c:blocked() then c.smite:auto() end
    c.wards:fastTick(true)
    c.combat:fastKick()
    -- Release a prepared post-attack move before diagnostic snapshots and
    -- other controllers can consume this callback's response window.
    if self:mode()=='farm' then c.farm:fastKite();c.farm:fastTick() end

    if c.sdk.Input or not c.actions:cursorBusy() then c.aim=c:playerPosition() end
    local mode=self:mode()
    local ggOwned=mode=='fight' or mode=='clear' or mode=='gg_last' or mode=='harass' or mode=='gg'
    if ggOwned then c.input:pauseFarm('GG mode '..mode) end
    if mode=='blocked' then
        local resume=c.config:get('autoJungle') and c.config:get('enabled') and not myHero.dead
        self:cancel('Chat / focus / champion unavailable',true);c.input:reset(resume)
        c.mode='blocked';c.status='Paused: chat / focus / unavailable';return
    end
    -- Skill allocation is independent of GG mode and auto-jungle ownership.
    if not previewInput then c.leveling:tick() end
    if c.input.cancel then self:cancel('Manual cancellation',true) end
    if mode~=c.mode then
        if mode=='clear' or c.mode=='clear' then c.farm.localCamp=nil;c.localManualMovement=false end
        if c.mode=='fight' then c.combat.rFollow=nil;c.combat.multiTarget=nil;c.attackFocus=nil;c.actions:cancel('fight') end
        if c.mode=='harass' then c.actions:cancel('harass') end
        if c.mode=='clear' or c.mode=='gg_last' then c.actions:cancel('clear');c.actions:cancel('harass') end
        if c.mode=='q' or c.mode=='secure' then c.actions:cancel(c.mode) end
        if c.mode=='cursor' or c.mode=='ally' then c.actions:cancel(c.mode) end
        if c.mode=='farm' and mode~='farm' then
            c.attackTarget=nil;c.actions:cancel('farm')
        end
        c.spells.afterSmite=nil;if c.config.capture then c:log('mode_changed',{name=mode}) end;c.mode=mode
    end
    c.attackTarget=nil;c.moveTarget=nil
    if mode=='farm' and (c.input.pressed.farmKey or not self.autoWasOn) then
        c.actions.cameraToggleAt=nil;c.actions.cameraAt=nil
        c.actions.cameraSample=nil;c.actions.cameraFollowing=nil
        c.actions.cameraLostSamples=0;c.actions.cameraResumeAt=nil
        c.input.farmPaused=false
        c.farm.camp=nil;c.farm.waveCenter=nil;c.farm.progressAt=nil;c.farm.state='routing'
        c.farm:startRoute()
    end
    self.autoWasOn=c.config:get('autoJungle')
    if mode=='cursor' or mode=='ally' then
        local bind=mode=='cursor' and 'cursorKey' or 'allyKey'
        if c.input.pressed[bind] or self.insecMode~=mode then
            c.combat:cancel();self.insecSuppressed=false
            self.insecCompletedStart=c.combat.completedSerial or 0
        end
        self.insecMode=mode
        if c.input.cancel then self.insecSuppressed=true end
        if not c.combat.insec and not self.insecSuppressed then
            local r=c:spell(3)
            if (c.combat.completedSerial or 0)~=(self.insecCompletedStart or 0) then c.status='Insec completed; release bind'
            elseif (r.level or 0)==0 or (r.currentCd or 0)>0 then c.status='Insec held: waiting for R'
            else c.combat:startInsec(mode) end
        elseif self.insecSuppressed then c.status='Insec cancelled; release bind to rearm' end
    else
        self.insecMode=nil;self.insecSuppressed=nil
        if c.combat.insec then c.combat:cancel() end
    end
    c.wards:tick()
    -- Ambient execution is independent of held modes. Explicit positioning,
    -- Recall and cursor ownership still govern whether dispatch is legal.
    if not c.wards.pending and not c.combat.insec and mode~='ward' and mode~='secure' then c.smite:auto() end
    local expiryAllowed=mode~='ward' and mode~='cursor' and mode~='ally' and mode~='secure' and mode~='reserved'
    if expiryAllowed and c.config:get('reserveW') and c.combat:defense() then c.status='Lethal incoming attack: self shield'
    elseif expiryAllowed and not (mode=='fight' and c.combat.rFollow) and c.clear:expiryTick() then c.status='Recast expiry assist'
    elseif mode=='ward' then
        if c.input.wardContinuation then c.status='Wardjump: '..(c.wards.pending and c.wards.pending.state or 'completed; release T')
        elseif not c.input.wardCancelled then c.wards:preview(c.aim);c.status='Wardjump: release to jump; right-click cancels' end
    elseif mode=='cursor' or mode=='ally' then c.combat:insecTick();c.combat:orbwalkInsec(self.insecSuppressed)
    elseif c.wards.pending then c.status='Wardjump: '..c.wards.pending.state
    elseif c:recalling() then c.status='Recalling';if mode=='farm' then c.farm:recovery() end
    elseif mode=='fight' then
        c.status='Fight'
        if c:combatTransit() then c.smite:auto()
        elseif c.combat.rFollow then c.combat:fight()
        elseif not c.actives:defense('fight') and not c.actives:potions('fight') and not c.combat:defense() and not c.smite:auto() then c.combat:fight() end
    elseif mode=='farm' then c.farm:tick();if c.attackTarget then c.actives:tick(c.attackTarget,'farm') end
    elseif mode=='clear' then
        c.status='GG local clear: nearest enabled wave / camp'
        local target=self:localClearTarget()
        if target then
            if target.team==300 then c.clear:tick(target,'clear');c.actives:tick(target,'clear')
            else c.wave:tick(target,false) end
        end
    elseif mode=='secure' then self:secure()
    elseif mode=='harass' then
        c.status='Harass';c.combat:harass('harass')
    elseif mode=='q' then
        c.status='Q1 assist';local target=c:target(c.profile.qRange);if target then c.spells:q1(target,'q',false) end
    elseif mode=='gg_last' then
        c.status='GG Last Hit'
        if c.config:get('lastAbilities') and not c.sdk.Orbwalker:IsAutoAttacking() then
            for _,m in ipairs(c.minions or {}) do
                if self:laneMinion(m) and U.dist(myHero.pos,m.pos)<=c.profile.qRange then
                    c.wave:tick(m,false,true);break
                end
            end
        end
    elseif mode=='gg' then c.status='GG orbwalker'
    elseif mode=='paused' then c.status='Auto-jungle stopped: press '..U.keyLabel(c.config:key('farmKey'))
    elseif mode=='reserved' then c.status=next(c.input.suspended) and 'Release held keys to resume' or 'Last-hit mode disabled'
    else
        c.status=c.routeFailureReason or 'Manual play'
        if not c.smite:auto() and not c.combat:defense() and not c.actives:defense() then
            if not (c.config:get('autoMultiR') and c.combat:multi(nil,false)) then c.combat:killsteal() end
        end
    end
    local follow=c.spells.afterSmite
    if follow then
        if c:now()>follow.untilTime or follow.owner~=mode or not U.valid(follow.target) then c.spells.afterSmite=nil
        elseif c.spells:q1(follow.target,follow.owner,false) then c.spells.afterSmite=nil end
    end
    if not ggOwned and not c.wards.pending and not c.leveling.pending and not c:dash() then
        local attacked=false
        if mode=='farm' and c.attackTarget and P.epics[P.category(c.attackTarget.charName)] then c.attackTarget=nil end
        if c.attackTarget then
            local requestState,requestReason
            if c.actions.attack then attacked,requestReason,requestState=c.actions:attack(c.attackTarget,mode) else attacked=c.sdk.Orbwalker:Attack(c.attackTarget) end
            if attacked then if c.config.capture then c:log('attack_accepted',{target=U.id(c.attackTarget),mode=mode,health=c.attackTarget.health,
                inputState=requestState,cursorID=c.actions.attackRequest,
                predictedHealth=c:healthAt(c.attackTarget,self:impact(c.attackTarget))}) end end
        end
        if not attacked and c.moveTarget then
            local ok,reason=c.actions:move(c.moveTarget,mode)
            if mode=='farm' and not ok and reason and not c.status:find(reason,1,true) then c.status=c.status..' | '..reason end
        end
    end
    if c.config.capture then c.verification={damage=c.config:get('mechanicsVerified'),terrain=c.terrain:trusted() and true or false,
        wardRange=c.config:get('rangeVerified'),smite=c.config:get('smiteVerified'),
        terrainProvider=c.terrain.provider and c.terrain.provider.kind or 'none',
        terrainStatic=c.terrain.provider and c.terrain.provider.static or false,gameplay='NOT RECORDED'} end
    c.input:clearEdges()
end
function App:install()
    local c=self.ctx;local sdk=c.sdk

    local function attach(list,fn) list[#list+1]=fn;self.hooks[#self.hooks+1]={list=list,fn=fn} end
    local function guarded(fn,label)
        local name='callback.'..(label or 'hook')
        return function(...)
            if not self.active then return end


            if (self.inCallback or 0)==0 then U.beginBuffScope() else U.invalidateBuffScope() end
            self.inCallback=(self.inCallback or 0)+1
            local values={...};local count=select('#',...)
            local ok,err=xpcall(function()return fn(unpack(values,1,count))end,function(error)
                return debug and debug.traceback and debug.traceback(tostring(error),2) or tostring(error)
            end)
            if not ok then

                local args=select(1,...);if type(args)=='table' and args.Process~=nil then args.Process=false end
                pcall(c.log,c,'controller_error',{reason=tostring(err),});pcall(self.Shutdown,self)
                print('[LHO] Controller stopped. Reload the runtime.')
            end
            self.inCallback=self.inCallback-1

            if self.inCallback==0 then U.endBuffScope() else U.invalidateBuffScope() end
        end
    end
    if sdk.OnUrgent then attach(sdk.OnUrgent,guarded(function()
        c:refresh();c.actions:tick()
        if not c:blocked() then c.smite:auto();c.wards:fastTick(true);c.combat:fastKick() end
    end,'urgent')) end
    attach(sdk.OnTick,guarded(function() self:tick() end,'tick'))
    if sdk.OnMaintenance then
        attach(sdk.OnMaintenance,function()if c.logger then pcall(c.logger.flush,c.logger) end end)
    end
    attach(sdk.OnDraw,guarded(function()
        if not c:blocked() then c.actions:tick();if not c.smite:auto() then c.smite:followAim() end end
        c.wards:fastTick();c.combat:fastKick();if self:mode()=='farm' then c.farm:fastTick();c.farm:fastKite() end;c.overlay:draw()
    end,'draw'))
    attach(sdk.OnWndMsg,guarded(function(msg,param) self:event(msg,param) end))
    local pre=guarded(function(args)
        local original=args.Target;self:preAttack(args)
        if c.config.capture then c.lastPreAttack={at=c:now(),mode=self:mode(),process=args.Process,
            original=U.id(original),target=U.id(args.Target),waveLock=c.wave:attackLocked(),
            wardPending=c.wards.pending~=nil,levelPending=c.leveling.pending~=nil} end
    end)
    self.hooks[#self.hooks+1]={list=sdk.Orbwalker.OnPreAttackCb,fn=pre};sdk.Orbwalker:OnPreAttack(pre)
    local move=guarded(function(args) self:preMove(args) end)
    self.hooks[#self.hooks+1]={list=sdk.Orbwalker.OnMoveCb,fn=move};sdk.Orbwalker:OnPreMovement(move)
    local post=guarded(function()

        if c.clear:attackFinished() then if c.config.capture then c:log('attack_finished') end end
        local mode=self:mode()
        if mode=='farm' then c.farm:fastKite() end
        if mode=='gg_last' or mode=='clear' then
            local anchor=mode=='clear' and self:localClearTarget()
            if mode=='gg_last' then for _,m in ipairs(c.minions or {}) do if self:laneMinion(m) then anchor=m;break end end end
            if anchor and anchor.team~=300 then c.wave:tick(anchor,false,mode=='gg_last') end
        end
    end)
    self.hooks[#self.hooks+1]={list=sdk.Orbwalker.OnPostAttackCb,fn=post};sdk.Orbwalker:OnPostAttack(post)
    c:refresh();c.farm:spawn();if c.config.capture then c:log('loaded',{name=c.profile.id,build=require('lho.profiles').build,
        provider=c.originalGG and 'OriginalGG' or 'Orbama',capabilities=c.actions.capabilities}) end


end
function App:Shutdown()
    if not self.active then return end
    self.active=false
    local c=self.ctx
    if c.actions.scope then c.actions.scope:Close('LHO shutdown')
    elseif c.sdk.Input then
    for _,owner in ipairs({'ward','insec','autosmite','secure','level','defense','farm','combat','camera','fight','harass','clear','q','killsteal','expiry'}) do
            pcall(c.sdk.Input.Cancel,c.sdk.Input,owner,'LHO shutdown')
        end
    end
    -- Cleanup steps are independent: one broken native input method must not
    -- leave every later callback registered or another held modifier behind.

    pcall(c.wards.cancel,c.wards,'Plugin shutdown')
    pcall(c.combat.cancel,c.combat);pcall(c.leveling.cancel,c.leveling)
    pcall(c.input.reset,c.input)
    pcall(c.actions.restoreCameraOnShutdown or c.actions.restoreCamera,c.actions)
    pcall(c.actions.releaseMinimap,c.actions,true)
    c.spells.afterSmite=nil;c.combat.rFollow=nil;c.combat.multiTarget=nil
    c.attackTarget=nil;c.moveTarget=nil;c.synthetic=false;c.dispatchMovement=nil
    for _,h in ipairs(self.hooks) do
        if h.list then
            for i=#h.list,1,-1 do
                if h.list[i]==h.fn then
                    -- Never shorten an SDK callback array while it is being iterated.
                    if (self.inCallback or 0)>0 then h.list[i]=function() end else table.remove(h.list,i) end
                end
            end
        end
    end
    self.hooks={}
    -- The crash event may still be buffered when normal hooks are detached.
    -- Drain it in maintenance, outside cursor/host input calls, then detach.
    if c.sdk.OnMaintenance and c.logger and c.logger:pendingCount()>0 then
        local list=c.sdk.OnMaintenance;local logger=c.logger
        local index=#list+1
        list[index]=function()
            pcall(logger.flush,logger)
            if logger:pendingCount()==0 then list[index]=function()end end
        end
    end
    if _G.LeeHarveyOsward==self then _G.LeeHarveyOsward=nil end
end
return App

end
modules["lho.bindings"] = function(require)
-- Contextual editors share the original native key node, including its save ID.
-- Mirrors have no ID: the host documents anonymous parameters as unsaved.
local B={};B.__index=B
local function read(node)
    if not node or type(node.Key)~='function' then return end
    local ok,key=pcall(node.Key,node)
    if ok and type(key)=='number' then return key end
end
local function write(node,key)
    if read(node)==key then return true end
    -- GoS native key parameters expose __key. Do not assume Key is a setter:
    -- several providers implement it as a getter only. Check both before/after.
    local old=read(node)
    if old==nil or node.__key~=old then return false end
    local ok=pcall(function()node.__key=key end)
    if ok and read(node)==key then return true end
    pcall(function()node.__key=old end)
    return false
end
function B.new(config,sdk)
    local self=setmetatable({config=config,entries={},nextSync=0},B)
    if not config.menu then return self end
    local menu=config.menu;local icon=require('lho.menuicons').new()
    menu.Guide:MenuElement({id='Bindings',name='Key bindings',type=MENU})
    local help=menu.Guide.Bindings
    local function branch(parent,id,name)
        if not parent[id] then parent:MenuElement({id=id,name=name,type=MENU,leftIcon=icon(id)}) end
        return parent[id]
    end
    local function editor(parent,node,label,semantic)
        if not parent or read(node)==nil then return end
        -- Unknown menu implementations keep their original editor; never show
        -- a second independent binding that cannot update the real input node.
        if node.__key~=read(node) then return end
        local entry={source=node,last=read(node)}
        local args={name=label,key=entry.last,leftIcon=icon(semantic),
            tooltip='Changes the same binding everywhere, including the original Controls menu.'}
        args.onKeyChange=function(key)
            if type(key)~='number' or key<0 or key%1~=0 then return end
            if write(node,key) then self:sync(true) end
        end
        entry.mirror=parent:MenuElement(args)
        if entry.mirror then self.entries[#self.entries+1]=entry end
    end
    local function own(parent,key,label,helpGroup)
        editor(parent,config.nodes[key],label,key)
        editor(branch(help,helpGroup,helpGroup),config.nodes[key],label,key)
    end
    own(menu.Wardjump,'wardKey','Hold / release wardjump','Wardjump')
    own(menu.Insec,'cursorKey','Hold: kick toward cursor','Insec')
    own(menu.Insec,'allyKey','Hold: kick toward team / turret','Insec')
    own(menu.Insec,'insecPreviewKey','Preview modifier','Insec')
    editor(menu.Drawings.Wardjump,config.nodes.wardKey,'Hold / release wardjump','wardKey')
    editor(menu.Drawings.Insec,config.nodes.cursorKey,'Hold: kick toward cursor','cursorKey')
    editor(menu.Drawings.Insec,config.nodes.allyKey,'Hold: kick toward team / turret','allyKey')
    editor(menu.Drawings.Insec,config.nodes.insecPreviewKey,'Preview modifier','insecPreviewKey')
    editor(menu.Insec.Flash,config.nodes.insecPreviewKey,'Preview / Flash modifier','insecPreviewKey')
    own(menu.Harass,'qAssistKey','Hold: Q1 assist','Assists')
    editor(menu.Assists,config.nodes.qAssistKey,'Hold: Q1 assist','qAssistKey')
    own(menu.Farming,'autoJungleKey','Toggle auto-jungle','Farming')
    editor(branch(help,'Farming','Farming'),config.nodes.farmCameraKey,'Camera lock key','farmCameraKey')
    own(menu.SmiteItems.Smite,'smiteKey','Toggle autosmite','Smite')
    own(menu.SmiteItems.Smite,'secureKey','Hold: Q + Smite objective assist','Smite')
    for _,row in ipairs({{'guideKey','Open / close guide'},{'guidePreviousKey','Previous topic'},
        {'guideNextKey','Next topic'}}) do
        editor(menu.Controls,config.nodes[row[1]],row[2],row[1])
        editor(branch(help,'Guide','Guide'),config.nodes[row[1]],row[2],row[1])
    end
    local modes={{'COMBO','Combat','Combo'},{'HARASS','Harass','Harass'},
        {'LANECLEAR','Wave','Lane clear'},{'JUNGLECLEAR','Jungle','Jungle clear'},
        {'LASTHIT','LastHit','Last hit'},{'FLEE','Controls','Flee'}}
    local orb=sdk and sdk.Orbwalker
    for _,row in ipairs(modes) do
        local id=sdk and sdk['ORBWALKER_MODE_'..row[1]]
        local nodes=orb and orb.MenuKeys and id~=nil and orb.MenuKeys[id]
        for index,node in ipairs(nodes or {}) do
            local label=row[3]..' key'..(index>1 and ' '..index or '')
            editor(menu[row[2]],node,label,row[2])
            editor(branch(help,'Modes','Orbwalker modes'),node,label,row[2])
        end
    end
    return self
end
function B:sync(force)
    local now=Game and Game.Timer and Game.Timer() or 0
    if not force and now<self.nextSync then return end
    self.nextSync=now+.1
    for _,entry in ipairs(self.entries) do
        local key=read(entry.source)
        if key~=nil and read(entry.mirror)~=key then write(entry.mirror,key) end
        entry.last=key
    end
end
return B

end
modules["lho.campdata"] = function(require)
-- Generated from installed map453.bin; locations do not imply availability.
return {["mapID"]=453,["mode"]="classic",["camps"]={{["name"]="Camp_Order_GreatWraith",["number"]=13,["pos"]={["x"]=2200.0,["y"]=0.0,["z"]=8450.0},["category"]="Wight",["team"]=100},{["name"]="Camp_Order_BlueBuff",["number"]=1,["pos"]={["x"]=3700.0,["y"]=0.0,["z"]=8000.0},["category"]="Blue",["team"]=100},{["name"]="Camp_Order_Wolves",["number"]=2,["pos"]={["x"]=3800.0,["y"]=0.0,["z"]=6500.0},["category"]="Wolves",["team"]=100},{["name"]="Camp_Order_Wraiths",["number"]=3,["pos"]={["x"]=6950.0,["y"]=0.0,["z"]=5450.0},["category"]="Wraiths",["team"]=100},{["name"]="Camp_Order_RedBuff",["number"]=4,["pos"]={["x"]=8000.0,["y"]=0.0,["z"]=4100.0},["category"]="Red",["team"]=100},{["name"]="Camp_Order_Golems",["number"]=5,["pos"]={["x"]=8500.0,["y"]=0.0,["z"]=2820.0},["category"]="Golems",["team"]=100},{["name"]="Camp_Chaos_GreatWraith",["number"]=14,["pos"]={["x"]=12500.0,["y"]=0.0,["z"]=6500.0},["category"]="Wight",["team"]=200},{["name"]="Camp_Chaos_BlueBuff",["number"]=7,["pos"]={["x"]=10900.0,["y"]=0.0,["z"]=7080.0},["category"]="Blue",["team"]=200},{["name"]="Camp_Chaos_Wolves",["number"]=8,["pos"]={["x"]=10900.0,["y"]=0.0,["z"]=9400.0},["category"]="Wolves",["team"]=200},{["name"]="Camp_Chaos_Wraiths",["number"]=9,["pos"]={["x"]=8000.0,["y"]=0.0,["z"]=9500.0},["category"]="Wraiths",["team"]=200},{["name"]="Camp_Chaos_RedBuff",["number"]=10,["pos"]={["x"]=7050.0,["y"]=0.0,["z"]=11000.0},["category"]="Red",["team"]=200},{["name"]="Camp_Chaos_Golems",["number"]=11,["pos"]={["x"]=6350.0,["y"]=0.0,["z"]=12100.0},["category"]="Golems",["team"]=200},{["name"]="Camp_Dragon",["number"]=nil,["pos"]={["x"]=9900.0,["y"]=0.0,["z"]=4350.0},["category"]="Dragon",["team"]=0},{["name"]="Camp_Baron",["number"]=nil,["pos"]={["x"]=4900.0,["y"]=0.0,["z"]=10408.0},["category"]="Baron",["team"]=0}}}

end
modules["lho.campobservations"] = function(require)
-- Generated by tools/extract_lho_camp_observations.py from recorded stationary full camps.
-- Position/health estimates only; current availability must be checked separately.
return {["mode"]="classic",["mapID"]=453,["estimated"]=true,["camps"]={["map:Camp_Order_GreatWraith"]={["rows"]={{["pos"]={["z"]=8692.3974609375,["x"]=2765.9743652344,["y"]=-5.0},["health"]=1819.9998779297,["maxHealth"]=1819.9998779297,["name"]="GreatWraith",["radius"]=65}},["at"]=507.24020385742,["session"]="2026-09-08-r13@0.004:101425015",["source"]="live-2026-09-08-r13-1008.log"},["map:Camp_Order_Wraiths"]={["rows"]={{["pos"]={["z"]=5663.0053710938,["x"]=7443.1166992188,["y"]=0.0},["health"]=1300.0,["maxHealth"]=1300.0,["name"]="Wraith",["radius"]=65},{["pos"]={["z"]=5840.5327148438,["x"]=7499.6645507813,["y"]=0.0},["health"]=195.0,["maxHealth"]=195.0,["name"]="S3_LesserWraith",["radius"]=65},{["pos"]={["z"]=5641.1630859375,["x"]=7622.8295898438,["y"]=0.0},["health"]=195.0,["maxHealth"]=195.0,["name"]="S3_LesserWraith",["radius"]=65},{["pos"]={["z"]=5769.7875976563,["x"]=7645.8198242188,["y"]=0.0},["health"]=195.0,["maxHealth"]=195.0,["name"]="S3_LesserWraith",["radius"]=65}},["at"]=535.97601318359,["session"]="2026-09-08-r13@0.004:101425015",["source"]="live-2026-09-08-r13-1008.log"},["map:Camp_Order_Golems"]={["rows"]={{["pos"]={["z"]=2991.1967773438,["x"]=9136.392578125,["y"]=0.0},["health"]=1560.0,["maxHealth"]=1560.0,["name"]="Golem",["radius"]=65},{["pos"]={["z"]=3005.5112304688,["x"]=8883.275390625,["y"]=0.0},["health"]=390.0,["maxHealth"]=390.0,["name"]="SmallGolem",["radius"]=65}},["at"]=559.51342773438,["session"]="2026-09-08-r13@0.004:101425015",["source"]="live-2026-09-08-r13-1008.log"},["map:Camp_Order_Wolves"]={["rows"]={{["pos"]={["z"]=6735.521484375,["x"]=4366.7724609375,["y"]=0.0},["health"]=1650.0,["maxHealth"]=1650.0,["name"]="GiantWolf",["radius"]=65},{["pos"]={["z"]=6876.595703125,["x"]=4284.072265625,["y"]=0.0},["health"]=300.0,["maxHealth"]=300.0,["name"]="Wolf",["radius"]=65},{["pos"]={["z"]=6661.5830078125,["x"]=4488.017578125,["y"]=0.0},["health"]=300.0,["maxHealth"]=300.0,["name"]="Wolf",["radius"]=65}},["at"]=719.10650634766,["session"]="2026-09-08-r13@0.004:101425015",["source"]="live-2026-09-08-r13-1008.log"},["map:Camp_Order_RedBuff"]={["rows"]={{["pos"]={["z"]=4373.0029296875,["x"]=8427.0380859375,["y"]=0.0},["health"]=2310.0,["maxHealth"]=2310.0,["name"]="S3_LizardElder",["radius"]=65},{["pos"]={["z"]=4379.0825195313,["x"]=8226.330078125,["y"]=0.0},["health"]=660.0,["maxHealth"]=660.0,["name"]="YoungLizard",["radius"]=65},{["pos"]={["z"]=4193.9155273438,["x"]=8441.0166015625,["y"]=0.0},["health"]=660.0,["maxHealth"]=660.0,["name"]="YoungLizard",["radius"]=65}},["at"]=784.107421875,["session"]="2026-09-08-r13@0.004:101425015",["source"]="live-2026-09-08-r13-1008.log"},["map:Camp_Order_BlueBuff"]={["rows"]={{["pos"]={["z"]=8083.4931640625,["x"]=4657.2421875,["y"]=-5.0},["health"]=2520.0,["maxHealth"]=2520.0,["name"]="S3_AncientGolem",["radius"]=65},{["pos"]={["z"]=8082.3896484375,["x"]=4465.814453125,["y"]=-5.0},["health"]=720.0,["maxHealth"]=720.0,["name"]="YoungLizardBlue",["radius"]=65},{["pos"]={["z"]=8258.49609375,["x"]=4532.4506835938,["y"]=-5.0},["health"]=720.0,["maxHealth"]=720.0,["name"]="YoungLizardBlue",["radius"]=65}},["at"]=988.37622070313,["session"]="2026-09-08-r13@0.004:101425015",["source"]="live-2026-09-08-r13-1008.log"},["map:Camp_Chaos_Wolves"]={["rows"]={{["pos"]={["y"]=0.0,["z"]=8699.7568359375,["x"]=11616.383789063},["health"]=1210.0,["maxHealth"]=1210.0,["name"]="GiantWolf",["radius"]=65.0},{["pos"]={["y"]=0.0,["z"]=8735.484375,["x"]=11463.833007813},["health"]=220.0,["maxHealth"]=220.0,["name"]="Wolf",["radius"]=65.0},{["pos"]={["y"]=0.0,["z"]=8547.2802734375,["x"]=11654.91015625},["health"]=220.0,["maxHealth"]=220.0,["name"]="Wolf",["radius"]=65.0}},["at"]=263.77151489258,["session"]="2026-09-08-r14@0.004:103998531",["source"]="live-2026-09-08-r14-706.log"},["map:Camp_Chaos_GreatWraith"]={["rows"]={{["pos"]={["y"]=0.0,["z"]=6796.0659179688,["x"]=13158.169921875},["health"]=1540.0,["maxHealth"]=1540.0,["name"]="GreatWraith",["radius"]=80.0}},["at"]=279.21655273438,["session"]="2026-09-08-r14@0.004:103998531",["source"]="live-2026-09-08-r14-706.log"},["map:Camp_Chaos_Wraiths"]={["rows"]={{["pos"]={["y"]=0.0,["z"]=9708.888671875,["x"]=8601.673828125},["health"]=1200.0,["maxHealth"]=1200.0,["name"]="Wraith",["radius"]=50.0},{["pos"]={["y"]=0.0,["z"]=9719.435546875,["x"]=8350.6591796875},["health"]=180.0,["maxHealth"]=180.0,["name"]="S3_LesserWraith",["radius"]=50.0},{["pos"]={["y"]=0.0,["z"]=9830.1201171875,["x"]=8420.1142578125},["health"]=180.0,["maxHealth"]=180.0,["name"]="S3_LesserWraith",["radius"]=50.0},{["pos"]={["y"]=0.0,["z"]=9579.6083984375,["x"]=8431.978515625},["health"]=180.0,["maxHealth"]=180.0,["name"]="S3_LesserWraith",["radius"]=50.0}},["at"]=329.09042358398,["session"]="2026-09-08-r14@0.004:103998531",["source"]="live-2026-09-08-r14-706.log"},["map:Camp_Chaos_Golems"]={["rows"]={{["pos"]={["y"]=0.0,["z"]=12454.596679688,["x"]=7102.7568359375},["health"]=1560.0,["maxHealth"]=1560.0,["name"]="Golem",["radius"]=80.0},{["pos"]={["y"]=0.0,["z"]=12430.750976563,["x"]=6826.0888671875},["health"]=390.0,["maxHealth"]=390.0,["name"]="SmallGolem",["radius"]=80.0}},["at"]=482.60717773438,["session"]="2026-09-08-r14@0.004:103998531",["source"]="live-2026-09-08-r14-706.log"}}}

end
modules["lho.clear"] = function(require)
local U=require('lho.util');local P=require('lho.profiles')
local Clear={};Clear.__index=Clear
local passiveBuffs={leesinpassivebuff=true,leesinpassive=true}

function Clear.new(ctx)
    return setmetatable({ctx=ctx,stages={},windows={},lastCast={},spellSamples={},passiveLeft=0,passiveUntil=0},Clear)
end

function Clear:executed(slot,stage,at,native)
    if slot<0 or slot>3 then return end
    self.observedScope=nil
    at=at or self.ctx:now()
    self.executionBySlot=self.executionBySlot or {}
    local previous=self.executionBySlot[slot]
    self.executionCredits=self.executionCredits or {}
    local credits=self.executionCredits[slot] or {}
    -- Native start, delayed cooldown/stage and controller observation describe
    -- the same cast. Deduplicate by stage within the observed readiness cycle,
    -- not a short time window that can expire before metadata arrives.
    local credit=credits[stage]
    if credit then
        if not native or at<=credit.at+.01 then return end
        -- A distinct native start is fresh execution evidence even if no ready
        -- sample occurred between callbacks. A first cast begins a new cycle.
        if stage==1 then credits={} end
    end
    credits[stage]={at=at};self.executionCredits[slot]=credits
    self.lastExecution={slot=slot,stage=stage,at=at};self.executionBySlot[slot]=self.lastExecution
    if self.ctx.config.capture then self.ctx:log('passive_credit',{slot=slot,stage=stage,castAt=at,remaining=2}) end
    self:accepted(slot,stage)
    self.passiveCastAt=at;self.passiveUntil=at+3
    local d=self.ctx:spell(slot)
    self.spellSamples[slot]={cd=d.currentCd or 0,stage=self.ctx:stage(slot)}
end

function Clear:observe()
    local scope=U.buffScopeKey()
    if scope and self.observedScope==scope then return end
    self.observedScope=scope
    local c=self.ctx;local now=c:now()
    local active=myHero.activeSpell
    if active and active.valid and U.finite(active.startTime) and active.startTime<=now and now-active.startTime<.75 then
        local name=U.name(active.name);local slot=name:find('leesinq',1,true) and 0 or name:find('leesinw',1,true) and 1
            or name:find('leesine',1,true) and 2 or name:find('leesinr',1,true) and 3
        local token=name..':'..active.startTime
        if slot and token~=self.activeToken then
            self.activeToken=token
            if not self.lastExecution or self.lastExecution.slot~=slot or active.startTime>self.lastExecution.at+.01 then
                self:executed(slot,name:find('two',1,true) and 2 or 1,active.startTime,true)
            end
        end
    end
    -- GG emits OnPostAttack from Move(), so stationary auto-jungle cannot
    -- depend on that callback alone. Its native attack cast-end is shared
    -- evidence for both paths; deduplicate the eventual movement callback.
    local attack=c.sdk.Attack;local finish=attack and attack.CastEndTime
    if finish and finish>0 and now>=finish and now-finish<.5 and self.finishedAttack~=finish then
        self:attackFinished(finish)
    end
    for slot=0,2 do
        local d=c:spell(slot);local stage=c:stage(slot,nil,d);local prior=self.spellSamples[slot]
        if prior and stage==1 and (d.currentCd or 0)<=.05 and (prior.cd>.05 or prior.stage~=1) then
            -- A fresh ready cycle permits another cast; unchanged ready
            -- metadata following a native start does not reset its credit.
            if self.executionCredits then self.executionCredits[slot]=nil end
        end
        -- A recast's remaining cooldown can become visible on natural expiry.
        -- Only first casts use cooldown evidence; recasts need active-spell or
        -- finite passive-buff evidence, handled separately above/below.
        local provisional=not c.actions.api and self.lastCast[slot] and now-self.lastCast[slot].at<.6
        if prior and not provisional and prior.stage==1 and ((d.currentCd or 0)>prior.cd+.05 or stage==2) then
            self:executed(slot,prior.stage,now)
        end
        local physical=c.manualSpells and c.manualSpells[slot]
        local before=physical and not physical.consumed and physical.before or prior and prior.recast
        local recast=(stage==2 or before and before.stage==2 and c.actions.api)
            and require('lho.recasts').snapshot(c,slot,d,stage) or nil
        if before and before.stage==2 and c.actions.api then
            local yes,evidence=require('lho.recasts').evidence(c,slot,before,nil,true,recast)
            if yes then self:executed(slot,2,evidence.at);if physical then physical.consumed=true end end
        end
        local sample=self.spellSamples[slot] or {}
        sample.cd=d.currentCd or 0;sample.stage=stage;self.spellSamples[slot]=sample
        if stage==2 and self.stages[slot]~=2 then self.windows[slot]=self.windows[slot] or now+3 end
        if stage~=2 then self.windows[slot]=nil end
        self.stages[slot]=stage
        if recast then recast.window=self.windows[slot] end
        sample.recast=stage==2 and recast or nil
    end
    if now>=self.passiveUntil then self.passiveLeft=0 end
    local buff=U.buff(myHero,passiveBuffs,now)
    local expiry=buff and math.max(buff.expireTime or 0,buff.endTime or 0) or 0
    if not c.actions.api and expiry>now and expiry<=now+3.3 and expiry~=self.passiveObservedExpiry then
        self.passiveObservedExpiry=expiry
        -- Observe manual casts too, without regranting attacks when the buff
        -- acknowledgement for our own cast arrives late. Cosmetic buffs do
        -- not participate; a persistent count=1 cannot stall future spells.
        local started=U.finite(buff.startTime) and buff.startTime>0 and buff.startTime or expiry-3
        if started>(self.passiveCastAt or -10)+.05 then
            self.passiveLeft=2;self.passiveUntil=expiry;self.passiveCastAt=started
        end
    end
    self.observedScope=scope
end

function Clear:attackFinished(finish)
    local c=self.ctx
    finish=finish or c.sdk.Attack and c.sdk.Attack.CastEndTime
    local active=myHero.activeSpell
    if active and active.castEndTime==finish and active.isStopped then self.cancelledAttack=finish end
    if finish and finish==self.cancelledAttack then return false end
    if finish and finish>0 then
        if finish>c:now() then return false end
        if self.finishedAttack==finish then return false end
        self.finishedAttack=finish
        if finish<(self.passiveCastAt or 0) then return false end
    else return false end -- No deduplication identity: do not spend an attack.
    self.passiveLeft=math.max(0,self.passiveLeft-1)
    c.lastAttackFinished=c:now()
    if c.config.capture then c:log('passive_attack_consumed',{remaining=self.passiveLeft,castEndTime=finish}) end
    return true
end

function Clear:weaving()
    self:observe()
    -- A cosmetic/manager buff may remain visible with count=1. It must never
    -- permanently veto every later cast. Track our own bounded two-attack window.
    return self.ctx:now()<self.passiveUntil and self.passiveLeft>0
end
function Clear:remainingHealth(target)
    if target.team==300 then
        for _,camp in pairs(self.ctx.farm.known) do
            local found,total=false,0
            for _,m in ipairs(camp.members or {}) do
                if U.valid(m) then total=total+m.health end
                if U.same(m,target) then found=true end
            end
            if found then return total end
        end
    end
    return target.health
end

-- Short rolling horizon: how long the remaining boosted attacks cover us,
-- when another usable spell can replenish them, and whether waiting is safe.
-- This is a bounded estimate, not a forced two-auto combo or a global optimum.
function Clear:passivePlan(slot,target,owner)
    local c=self.ctx;local now=c:now();local attack=c.sdk.Attack
    local cycle=math.max(.15,attack.GetAnimation and attack:GetAnimation() or 1)
    local wait=attack.IsReady and not attack:IsReady() and math.max(0,(attack.ServerStart or now)+cycle-now) or 0
    local first=wait+c:windup()+c.latency*.5
    local coverage=math.min(math.max(0,self.passiveUntil-now),first+math.max(0,self.passiveLeft-1)*cycle)
    local prefix=owner=='farm' and 'autoClear' or 'jungle';local nextSpell=math.huge
    local energyAfter=math.max(0,(myHero.mana or 0)-(c:spell(slot).mana or 0))
    -- Q1 creates its own next refresh after impact, provided the monster can
    -- survive it. Do not model Q1 like a final recast with no follow-up.
    if slot==0 and c:stage(0)==1 and energyAfter>=30 and c.config:get(prefix..'Q2') then
        local impact=.25+U.dist(myHero.pos,target.pos)/c.profile.qSpeed+c.latency
        if c.farm:qSurvives(target,impact) then nextSpell=impact end
    end
    for other=0,2 do
        local d=c:spell(other);local stage=c:stage(other,other==0 and target or nil)
        local key=other==0 and (stage==2 and 'Q2' or 'Q') or other==1 and 'W' or 'E'
        if other~=slot and (d.level or 0)>0 and (stage==1 or stage==2)
            and c.config:get(prefix..'Abilities') and c.config:get(prefix..key) and (d.mana or 0)<=energyAfter then
            local usable=true
            if other==0 then
                usable=stage==2 and c:mark(target)~=nil or stage==1 and U.dist(myHero.pos,target.pos)<=c.profile.qRange
                    and #c.spells:blockers(target,target.pos)==0
            elseif other==2 then
                usable=U.dist(myHero.pos,target.pos)<=(stage==2 and c.profile.e2Range or c.profile.eRange)
                    and (stage==1 or U.buff(target,P.eMarks,now)~=nil)
            end
            local cd=math.max(0,d.currentCd or 0)
            if stage==2 and self.windows[other] and self.windows[other]-now<=cd then usable=false end
            if usable then nextSpell=math.min(nextSpell,cd) end
        end
    end
    local members={target}
    for _,camp in pairs(c.farm.known) do
        local found=false;for _,m in ipairs(camp.members or {}) do if U.same(m,target) then found=true;break end end
        if found then members=camp.members;break end
    end
    local incoming=0
    for _,m in ipairs(members) do
        if U.valid(m) and U.dist(myHero.pos,m.pos)<math.max(400,(m.range or 0)+100) then
            local raw=m.totalDamage or m.attackData and m.attackData.damage or math.max(8,(m.maxHealth or m.health)*.035)
            local rate=m.attackSpeed or (m.attackData and m.attackData.animationTime and 1/math.max(.2,m.attackData.animationTime)) or .7
            local ok,damage=pcall(c.sdk.Damage.CalculateDamage,c.sdk.Damage,m,myHero,c.sdk.DAMAGE_TYPE_PHYSICAL,raw)
            if not ok or type(damage)~='number' or damage~=damage then damage=raw end
            -- Include one immediately possible hit; unknown attack phases must
            -- not falsely promise that the next hit is a full cycle away.
            incoming=incoming+math.max(0,damage)*math.max(1,math.ceil(coverage*rate))
        end
    end
    local health=myHero.health+(myHero.allShield or 0)
    local danger=U.hp(myHero)<=15 or incoming>=health-math.max(50,myHero.maxHealth*.08)
    local plan={slot=slot,target=U.id(target),at=now,remaining=self.passiveLeft,coverage=coverage,
        nextSpell=nextSpell<math.huge and nextSpell or nil,gap=nextSpell<math.huge and math.max(0,nextSpell-coverage) or nil,
        drought=nextSpell>coverage+.1,incoming=incoming,health=health,energyAfter=energyAfter,danger=danger}
    self.passiveDecision=plan
    return plan
end

function Clear:passiveReason(plan,reason)
    plan.reason=reason
    if self.ctx.config.capture then self.ctx:trace('clear_passive_decision',plan,tostring(plan.slot)..':'..reason,.75) end
end

function Clear:eOpportunity(target)
    local c=self.ctx
    if c:stage(2)~=1 or target.team~=300 then return true end
    if not c.spells:eHits(target) then return false,'e_impact_out_of_range' end
    if U.hp(myHero)<45 or c:spellDamageEstimate(2,target,1)>=U.effectiveHP(target) then return true end
    local path=myHero.pathing
    if not path or not path.hasMovePath or not path.endPos then return true end
    local future=U.toward(myHero.pos,path.endPos,math.min(U.dist(myHero.pos,path.endPos),(myHero.ms or 0)*.75))
    for _,camp in pairs(c.farm.known) do
        local contains=false;for _,m in ipairs(camp.members or {}) do if U.same(m,target) then contains=true;break end end
        if contains then
            local now,later=0,0
            for _,m in ipairs(camp.members) do
                if c.spells:eHits(m) then now=now+1 end
                if c.spells:eHits(m,future) then later=later+1 end
            end
            if later>now then
                if c.config.capture then c:trace('clear_e_coverage_wait',{hits=now,approachHits=later,
                    origin=U.copy(myHero.pos),target=U.id(target)},tostring(camp.id),.5) end
                return false,'e_better_coverage_on_current_approach'
            end
            break
        end
    end
    return true
end
function Clear:cast(slot,target,owner,urgent)
    local c=self.ctx;local stage=c:stage(slot,slot==0 and target or nil);local ok,event
    local prefix=owner=='farm' and 'autoClear' or 'jungle'
    local key=slot==0 and (stage==2 and 'Q2' or 'Q') or ({'Q','W','E'})[slot+1]
    if not c.config:get(prefix..'Abilities') or not c.config:get(prefix..key) then return false end
    if stage==1 and target.team==300 and (slot==0 or slot==2) and not urgent
        and self:reserveForNext(slot,target,owner) then return false end
    if slot==0 then
        if stage==1 then ok,event=c.spells:q1(target,owner,false) else ok,event=c.spells:q2(target,owner,false,urgent) end
    elseif slot==1 then ok,event=c.spells:w(myHero,owner,nil,owner=='farm' and 'autoClear' or 'jungle')
    else
        local function valid()return self:eOpportunity(target) end
        if not valid() then return false end
        ok,event=c.spells:e(target,owner,valid)
    end
    if ok then
        if c.config.capture then c:log('clear_cast',{slot=slot,stage=stage,owner=owner,target=U.id(target),health=U.hp(myHero)}) end
    end
    return ok,event
end
function Clear:accepted(slot,stage,grantPassive)
    local now=self.ctx:now()
    self.lastCast[slot]={at=now,stage=stage}
    if slot==1 and stage==2 then self.sustainUntil=now+4 end
    if grantPassive~=false then self.passiveLeft=2;self.passiveUntil=now+3;self.passiveCastAt=now end
    self.stages[slot]=stage
    self.windows[slot]=stage==1 and now+3 or nil
end
function Clear:q2Estimate(target,health)
    local c=self.ctx;local p=c.profile;local rank=c:spell(0).level or 0
    if rank==0 then return 0 end
    local base=(p.qBase[rank] or 0)+p.qRatio*(myHero.bonusDamage or 0)
    local missing=math.max(0,(target.maxHealth or 0)-health)
    local raw=p.id=='classic' and base+missing*.08 or base*(1+missing/math.max(1,target.maxHealth or 1))
    local cap=c.config:get('monsterQCap');if target.team==300 and cap and cap>0 then raw=math.min(raw,cap) end
    return c.sdk.Damage:CalculateDamage(myHero,target,c.sdk.DAMAGE_TYPE_PHYSICAL,raw)
end
function Clear:q2Timing(target)
    local c=self.ctx;local left=c:markLeft(target);local lead=math.max(.25,c.latency+c.jitter*2)
    if left<=lead then return 'cast' end
    local damage=self:q2Estimate(target,target.health)
    if damage>=target.health+(target.allShield or 0) then return 'cast' end
    if U.dist(myHero.pos,target.pos)>c:attackRange(target) then return 'cast' end
    local attack=c.sdk.Attack;local cycle=attack.GetAnimation and attack:GetAnimation() or 1
    local wait=attack.IsReady and not attack:IsReady() and math.max(0,(attack.ServerStart or c:now())+cycle-c:now()) or 0
    local impact=wait+c:windup()+c.latency*.5;local aa=c:aaDamage(target)
    local qTime=.15+U.dist(myHero.pos,target.pos)/1800
    if impact+lead>=left then return 'cast' end
    local hp=target.health+(target.allShield or 0)
    local after=math.max(0,hp-aa);local qAfter=self:q2Estimate(target,after)
    local afterQ=math.ceil(math.max(0,after-qAfter)/math.max(1,aa))
    -- The Q dash overlaps the remaining attack cooldown; do not add a full
    -- attack cycle on top of it and accidentally prefer an extra auto.
    local aaFirst=after<=0 and impact or afterQ==0 and impact+qTime
        or math.max(wait+cycle,impact+qTime)+c:windup()+c.latency*.5+(afterQ-1)*cycle
    local qFirst=math.max(wait,qTime)+c:windup()+c.latency*.5+math.max(0,math.ceil((hp-damage)/math.max(1,aa))-1)*cycle
    -- Estimated clear-time comparison, separate from verified objective damage.
    -- Waiting consumes no recast; mark expiry and actual HP are checked again.
    if aaFirst<qFirst-.03 then return 'attack' end
    return 'cast'
end
function Clear:expiryTick()
    local c=self.ctx;self:observe()
    if c:blocked() or c:recalling() or c:dash() or c.wards.pending or c.combat.insec
        or c.mode=='farm' and (c.farm.recallAction or c.farm.state=='recalling')
        or c.input:held('wardKey') or c.leveling.pending or c.sdk.Orbwalker:IsAutoAttacking() then return false end
    local lead=math.max(.3,c.latency+c.jitter*2)
    local prefix=c.mode=='farm' and 'autoClear' or c.mode=='clear' and 'jungle'
    if prefix and c.config:get(prefix..'Abilities') and c.config:get(prefix..'Q2') and c:stage(0)==2 and c:ready(0) then
        for _,m in ipairs(c.minions or {}) do
            local left=m.team==300 and U.valid(m) and c:markLeft(m) or 0
            if left>0 and left<=lead+c:windup() then return false end -- Let the jungle controller rescue Q2 first.
        end
    end
    for slot=1,2 do
        local window=self.windows[slot]
        if c.config:get(slot==1 and 'expiryW' or 'expiryE') and c:stage(slot)==2 and window
            and window>c:now() and window-c:now()<=lead and c:ready(slot)
            and (myHero.mana or 0)-(c:spell(slot).mana or 0)>=c.config:get('recastReserve') then
            if slot==1 then if c.spells:w(myHero,'expiry') then return true end
            else
                for _,list in ipairs({c.enemies or {},c.minions or {}}) do for _,target in ipairs(list) do
                    if U.valid(target) and target.team~=myHero.team and c.spells:e(target,'expiry') then return true end
                end end
            end
        end
    end
    return false
end

function Clear:q1Target(target)
    local c=self.ctx;local best=target
    if target.team~=300 then return best end
    for _,camp in pairs(c.farm.known) do
        local contains=false
        for _,m in ipairs(camp.members or {}) do if U.same(m,target) then contains=true;break end end
        if contains then
            for _,m in ipairs(camp.members) do
                if U.valid(m) and (m.maxHealth or 0)>(best.maxHealth or 0)
                    and U.dist(myHero.pos,m.pos)<=c.profile.qRange and #c.spells:blockers(m,m.pos)==0 then best=m end
            end
            break
        end
    end
    return best
end

function Clear:tick(target,owner,beforeAttack)
    local c=self.ctx;self:observe()
    if owner=='farm' and not c.farm:ordinaryTarget(target) then return false end
    if not U.valid(target) or target.team==myHero.team or c:dash() then return false end
    local now=c:now();local distance=U.dist(myHero.pos,target.pos)
    if self.targetID~=U.id(target) then self.targetID=U.id(target);self.engagedAt=now end
    local melee=distance<=c:attackRange(target)+35
    if not melee and beforeAttack then return false end
    local hp=U.hp(myHero);local weaving=melee and self:weaving()
    local lead=math.max(.3,c:windup()+c.latency+c.jitter*2+.1)
    local function expiring(slot) return self.windows[slot] and self.windows[slot]-now<=lead end
    if target.team==300 then
        for _,camp in pairs(c.farm.known) do
            for _,m in ipairs(camp.members or {}) do if U.same(m,target) then camp.lastFoughtAt=now;break end end
        end
    end
    local qMarked=c:mark(target)

    -- Never throw away a confirmed Q mark solely to finish two passive attacks.
    local qTarget=qMarked and target
    if not qTarget and target.team==300 then
        for _,camp in pairs(c.farm.known) do
            local contains=false;for _,m in ipairs(camp.members or {}) do if U.same(m,target) then contains=true end end
            if contains then for _,m in ipairs(camp.members) do if U.valid(m) and c:mark(m) then qTarget=m;break end end end
        end
    end
    if target.team==300 then self:diagnoseQ(target,qTarget,owner) end
    if c.config.capture and target.team==300 and not qTarget and now>=(self.qDiagnosticAt or 0) then
        local last=self.lastCast[0]
        if c:stage(0)==2 or last and last.stage==1 and now-last.at>.4 and now-last.at<3.5 then
            local buffs={}
            for index=0,math.min(32,target.buffCount or 0) do
                local b=target.GetBuff and target:GetBuff(index)
                if b and b.name and b.name~='' then buffs[#buffs+1]={name=b.name,count=b.count,stacks=b.stacks,
                    expireTime=b.expireTime,endTime=b.endTime,source=b.sourcenID,sourceID=b.sourceID} end
            end
            local d=c:spell(0);self.qDiagnosticAt=now+2
            if c.config.capture then c:log('q2_wait',{reason='No recognized confirmed mark',name=d.name,stage=c:stage(0),toggleState=d.toggleState,
                ready=c:ready(0),target=U.id(target),buffs=buffs}) end
        end
    end
    local prefix=owner=='farm' and 'autoClear' or 'jungle'
    local rescueQ=qTarget and c.config:get(prefix..'Abilities') and c.config:get(prefix..'Q2')
        and (not c.config:get('jungleQ2MeleeOnly') or U.dist(myHero.pos,qTarget.pos)<=c:jungleQ2Range(qTarget))
    if rescueQ and self:q2Estimate(qTarget,qTarget.health)>=U.effectiveHP(qTarget) then
        -- A lethal estimate is already a useful timing decision. Do not gate
        -- jungle execution on the separately unverified damage-overlay toggle.
        if self:cast(0,qTarget,owner,true) then return true end
    end
    if rescueQ and c:markLeft(qTarget)<=lead then
        if self:cast(0,qTarget,owner,true) then return true end
        return false -- Do not spend its last cast opportunity on another ability.
    end
    if target.team==300 and c.smite:clear(target,owner) then return true end
    if target.team==300 and c.actives:potions(owner) then return true end
    -- Cleave resets belong immediately after the attack, before another spell
    -- can consume that dispatch opportunity. All item/range toggles still apply.
    if target.team==300 and c.lastAttackFinished and now-c.lastAttackFinished<.3 and c.actives:tick(target,owner) then return true end
    if target.team==300 and hp>=45 and c:ready(2) and c:stage(2)==1
        and c.config:get(prefix..'Abilities') and c.config:get(prefix..'E')
        and (myHero.mana or 0)-(c:spell(2).mana or 0)>=30 then
        local count,total,kills=0,0,0
        for _,camp in pairs(c.farm.known) do
            local contains=false;for _,m in ipairs(camp.members or {}) do if U.same(m,target) then contains=true;break end end
            if contains then
                for _,m in ipairs(camp.members) do
                    if c.spells:eHits(m) then
                        local damage=c:spellDamageEstimate(2,m,1)
                        count=count+1;total=total+math.min(m.health,damage)
                        if damage>=m.health then kills=kills+1 end
                    end
                end
                break
            end
        end
        if count>=2 and (kills>0 or total>=c:aaDamage(target)*2) then
            if self:cast(2,target,owner) then if c.config.capture then c:log('clear_aoe_priority',{targets=count,estimatedDamage=total,kills=kills}) end;return true end
        end
    end
    if qTarget and c.config:get('clearQTiming') and not beforeAttack then
        local decision=self:q2Timing(qTarget);self.qTiming=decision
        if decision=='cast' and weaving and U.dist(myHero.pos,qTarget.pos)<=c:attackRange(qTarget) then
            local plan=self:passivePlan(0,qTarget,owner)
            if plan.drought and not plan.danger then
                decision='attack';self.qTiming=decision;self:passiveReason(plan,'Preserve Q2 refresh across cooldown gap')
            end
        end
        if decision=='cast' and self:cast(0,qTarget,owner) then return true end
    end
    -- Fit Q1 inside an observed attack cooldown at surplus energy; two
    -- passive autos are a preference, not a mandatory delay on useful damage.
    local attack=c.sdk.Attack
    if target.team==300 and weaving and not beforeAttack and hp>=75 and c:stage(0)==1 and c:ready(0)
        and (myHero.mana or 0)-(c:spell(0).mana or 0)>=100
        and attack and attack.IsReady and not attack:IsReady() and attack.GetAnimation and attack.ServerStart then
        local wait=attack.ServerStart+attack:GetAnimation()-now
        if wait>.25+c.latency+.05 then
            local q1=self:q1Target(target)
            -- At full target HP the clear Q2 estimate is its shared Q1 base.
            -- Objective accounting intentionally returns zero for an unknown
            -- monster cap; that must not disable ordinary clear decisions.
            if q1.health>c:aaDamage(q1)*3 and self:q2Estimate(q1,q1.maxHealth)>=c:aaDamage(q1)
                and not self:passivePlan(0,q1,owner).drought then
                if self:cast(0,q1,owner) then if c.config.capture then c:log('clear_tempo_q',{target=U.id(q1),nextAttackIn=wait}) end;return true end
            end
        end
    end
    -- Re-evaluate W1 each cooldown cycle, even if an unrelated buff is stale.
    if melee and c:ready(1) and c:stage(1)==1 and (hp<75 or not weaving) then
        if self:cast(1,target,owner) then return true end
    end
    if melee and c:ready(1) and c:stage(1)==2 then
        local sustainActive=now<(self.sustainUntil or 0)
        local endingSoon=hp<98 and self:remainingHealth(target)<=c:aaDamage(target)*3
        local plan=weaving and self:passivePlan(1,target,owner)
        local early=plan and (plan.danger or hp<60 and not plan.drought)
        if plan then self:passiveReason(plan,expiring(1) and 'W2 expiry' or endingSoon and 'W2 final camp sustain'
            or early and (plan.danger and 'W2 incoming damage risk' or 'W2 sustain with another refresh available')
            or 'Keep passive attacks before W2') end
        if expiring(1) or (not sustainActive and (not weaving or early or endingSoon)) then
            if self:cast(1,target,owner) then return true end
        end
    end
    if c:stage(2)==2 then
        local plan=weaving and c.profile.id=='classic' and hp<60 and self:passivePlan(2,target,owner)
        if expiring(2) or not weaving or plan and plan.danger then
            if plan then self:passiveReason(plan,'E2 incoming damage risk') end
            if self:cast(2,target,owner) then return true end
        end
    end
    if weaving then return false end
    if (myHero.mana or 0)/math.max(1,myHero.maxMana or 200)*100<c.config:get('clearEnergy') then return false end
    if c:stage(0)==1 then
        if self:cast(0,self:q1Target(target),owner) then return true end
    end
    if c:stage(2)==1 and self:cast(2,target,owner) then return true end
    if qTarget and (not c.config:get('clearQTiming') or self:q2Timing(qTarget)=='cast') then return self:cast(0,qTarget,owner) end
    return false
end

function Clear:diagnoseQ(target,marked,owner)
    if not self.ctx.config.capture then return end
    local c=self.ctx;local now=c:now();local d=c:spell(0)
    if (d.level or 0)==0 then c.qDebug=nil;return end
    local stage=c:stage(0,marked);local prefix=owner=='farm' and 'autoClear' or 'jungle'
    local enabled=c.config:get(prefix..'Abilities') and c.config:get(prefix..'Q2')
    local reason=not enabled and 'Q2 disabled' or not marked and 'No recognized target mark'
        or c.config:get('jungleQ2MeleeOnly') and U.dist(myHero.pos,marked.pos)>c:jungleQ2Range(marked) and 'Outside configured Q2 clear range'
        or not c:ready(0) and 'Native castability / energy'
        or c.actions.pending[0] and 'Waiting for Q acknowledgement'
        or c.spells.q2LastRequest and now-c.spells.q2LastRequest<.5 and 'Q2 key sent'
        or self.qTiming=='attack' and 'Weaving before Q2' or 'Q2 eligible'
    c.qDebug={at=now,text='Q stage '..stage..' | '..reason..' | '..tostring(d.name)}
    if c.q2Outcome and now-c.q2Outcome.at<2 then c.qDebug.text=c.qDebug.text..' | '..c.q2Outcome.text end
    if now<(self.qStateLogAt or 0) then return end
    self.qStateLogAt=now+1
    local function buffs(unit)
        local result={}
        for index=0,math.min(32,unit.buffCount or 0) do
            local b=unit.GetBuff and unit:GetBuff(index)
            if b and b.name and b.name~='' then result[#result+1]={name=b.name,count=b.count,stacks=b.stacks,
                expireTime=b.expireTime,endTime=b.endTime,source=b.sourcenID,sourceID=b.sourceID} end
        end
        return result
    end
    if c.config.capture then c:log('jungle_q_state',{reason=reason,owner=owner,name=d.name,stage=stage,rank=d.level,cd=d.currentCd,
        toggleState=d.toggleState,useState=Game.CanUseSpell(0),energy=myHero.mana,cost=d.mana,
        target=U.id(target),targetName=target.charName,targetBuffs=buffs(target),heroBuffs=buffs(myHero),
        markedTarget=U.id(marked),markLeft=marked and c:markLeft(marked),lastDecision=c.spells.q2Decision,
        cursorStep=c.sdk.Cursor.Step,lastQRequest=c.spells.q2LastRequest,build=require('lho.profiles').build}) end
end

require('lho.clearreserve')(Clear)
return Clear

end
modules["lho.clearreserve"] = function(require)
local U=require('lho.util')
return function(Clear)
    function Clear:reserveForNext(slot,target,owner)
        local c=self.ctx;local farm=c.farm
        if U.hp(myHero)<55 or farm:championPressure().count>0 or farm.recoveryWanted then return false end
        local camp
        for _,known in pairs(farm.known) do
            for _,m in ipairs(known.members or {}) do if U.same(m,target) then camp=known;break end end
            if camp then break end
        end
        if not camp then return false end
        local attack=c.sdk.Attack;local cycle=attack.GetAnimation and attack:GetAnimation()
        if not U.finite(cycle) or cycle<=0 then return false end
        local wait=attack.IsReady and not attack:IsReady() and math.max(0,(attack.ServerStart or c:now())+cycle-c:now()) or 0
        local aaTime=wait+c:windup()+c.latency
        if slot==2 then
            if c.profile.id~='normal' or camp.category~='Krugs' or not c.config:get('clearKrugE') then return false end
            local imminent=farm:splitPending(camp);local parentFinishing=false;local smallKills=0
            for _,m in ipairs(camp.members or {}) do if U.valid(m) then
                if farm:krugRemnant(m) and U.dist(myHero.pos,m.pos)<=c.profile.eRange
                    and c:spellDamageEstimate(2,m,1)>=U.effectiveHP(m) then smallKills=smallKills+1
                elseif not farm:krugRemnant(m) and U.same(m,target) and U.dist(myHero.pos,m.pos)<=c:attackRange(m)
                    and aaTime<=1.2 and U.effectiveHP(m)<=c:aaDamage(m) then imminent=true;parentFinishing=true end
            end end
            if imminent and smallKills<(parentFinishing and 4 or 2) then
                if c.config.capture then c:trace('clear_resource_reserve',{slot=2,reason='imminent_krug_split',camp=camp.id},'reserve_e',.5) end
                return true
            end
            return false
        end
        -- Only substitute a nearly due finishing auto. Q2 and low-health
        -- execution are never postponed for a speculative future camp.
        if owner~='farm' or not c.config:get('farmPreserveQ') or not c.config:get('farmQTravel')
            or not c.config:get('autoClearQ2') or aaTime>.65 or U.dist(myHero.pos,target.pos)>c:attackRange(target) then return false end
        local count=0
        for _,m in ipairs(camp.members or {}) do if U.valid(m) then count=count+1 end end
        if count~=1 or U.effectiveHP(target)>c:aaDamage(target) or farm:splitPending(camp)
            or c.profile.id=='normal' and camp.category=='Krugs' and not farm:krugRemnant(target) then return false end
        local nextCamp=farm:choose(camp,true)
        if not nextCamp or nextCamp.team~=myHero.team or nextCamp.awaitingRespawn
            or nextCamp.availability~='observed_alive' then return false end
        local destination=farm:walkDestination(nextCamp);local distance=U.dist(myHero.pos,destination)
        if distance<=c:attackRange(target)+100 or distance>2200 then return false end
        local approach=U.toward(myHero.pos,destination,math.max(0,distance-c.profile.qRange+50))
        local arrival=aaTime+U.dist(myHero.pos,approach)/math.max(1,myHero.ms or 350)
        local spell=c:spell(0);local cooldown=spell.cd or spell.totalCooldown
        -- Without runtime cooldown data, do not invent future availability.
        if not U.finite(cooldown) or cooldown<=arrival then return false end
        local fog=true
        for _,m in ipairs(nextCamp.members or {}) do if U.valid(m) then fog=false;break end end
        if fog and not c.config:get('farmQBlind') then return false end
        local shot=farm:entryShot(nextCamp,approach,fog)
        if not shot or not farm:entryFaster(shot.pos,approach) then return false end
        if c.config.capture then c:trace('clear_resource_reserve',{slot=0,reason='finishing_auto_before_next_q_entry',
            camp=camp.id,nextCamp=nextCamp.id,autoIn=aaTime,entryIn=arrival,cooldown=cooldown},'reserve_q',.5) end
        return true
    end
end

end
modules["lho.combat"] = function(require)
local U=require('lho.util');local P=require('lho.profiles')
local B={};B.__index=B
function B.new(ctx,actions,spells,wards)
    local self=setmetatable({ctx=ctx,actions=actions,spells=spells,wards=wards},B)
    self.planner=require('lho.insec').new(self);self.kicks=require('lho.kickplan').new(ctx)
    self.tactics=require('lho.tactics').new(self);return self
end
function B:planAligned(i,origin)
    return self:aligned({pos=i.plannedTarget or i.target.pos},i.plannedEndpoint or i.endpoint,origin)
end
function B:direction(target,destination)
    local endpoint=U.toward(target.pos,destination,self.ctx.profile.kickDistance)
    local stand=math.min(self.ctx.config:get('insecStandDistance'),self.ctx.profile.rRange-45)
    return U.toward(target.pos,destination,-stand),endpoint
end
function B:allyDestination(target,origin,preferred)
    local c=self.ctx;local best,score=nil,math.huge
    local function tower(a,range)
        -- Fountain structures may be untargetable; we target the enemy, not
        -- the recipient. Dead or invalid structures never qualify.
        if a.team~=myHero.team or a.valid==false or a.dead or not U.position(a.pos)
            or not U.finite(a.health) or a.health<=0 then return end
        local endpoint=U.toward(target.pos,a.pos,c.profile.kickDistance)
        local inside=U.dist(endpoint,a.pos)
        if inside<=range-35 then
            local value=inside+U.dist(origin,a.pos)*.05
            if U.same(a,preferred) or a.platform and preferred and preferred.platform then value=-1 end
            if value<score then best,score=a,value end
        end
    end
    for _,a in ipairs(c.config:get('insecPreferStructures') and c.turrets or {}) do
        local range=U.finite(a.range) and a.range>0 and a.range or 775
        tower(a,range+(a.boundingRadius or 80)+(target.boundingRadius or 0))
    end
    local spawn=c.farm.spawnPos or c.farm.spawnPoints and c.farm.spawnPoints[myHero.team]
    if spawn and c.config:get('insecPreferStructures') and c.config:get('insecBasePlatform') then
        -- A recorded spawn anchor supports a small area deep in the platform.
        -- Do not fabricate the unobserved laser's outer attack radius.
        tower({team=myHero.team,pos=spawn,health=1,charName='Base platform',platform=true},250)
    end
    if best then return U.copy(best.pos),best,'structure' end
    for _,a in ipairs(c.allies or {}) do
        if a.team==myHero.team and not U.same(a,myHero) and U.valid(a) and U.dist(target.pos,a.pos)<2000 then
            local value=U.dist(target.pos,a.pos)+c:threats(a.pos,700)*200
            if value<score then best,score=a,value end
        end
    end
    return U.copy(best and best.pos or origin),best,best and 'ally' or 'origin'
end
function B:aligned(target,endpoint,origin)
    origin=origin or myHero.pos
    if U.dist(origin,target.pos)>self.ctx.profile.rRange or U.dist(origin,target.pos)<25 then return false end
    local dx,dz=target.pos.x-origin.x,target.pos.z-origin.z
    local ex,ez=endpoint.x-target.pos.x,endpoint.z-target.pos.z
    local length=math.sqrt((dx*dx+dz*dz)*(ex*ex+ez*ez))
    if length<1 then return false end
    return (dx*ex+dz*ez)/length+1e-9>=math.cos(math.rad(self.ctx.config:get('insecAngle')))
end
function B:startInsec(kind)
    local c=self.ctx;local target=c:locked()
    local selection='GG selection'
    if not target and c.config:get('insecMouseTarget') then
        local nearest=c.config:get('insecMouseRadius')
        for _,enemy in ipairs(c.enemies or {}) do
            local distance=U.dist(c.aim,enemy.pos)
            if distance<nearest and c:enemyValid(enemy) then target=enemy;nearest=distance end
        end
        selection='Mouse fallback'
    end
    if not c:enemyValid(target) then c.status='Select a champion for insec';return false end
    local origin=U.copy(myHero.pos)
    if kind=='ally' and c.input:held('allyKey') and not self.allyHoldOrigin then self.allyHoldOrigin=U.copy(origin) end
    self.insec={kind=kind,target=target,origin=origin,at=c:now(),phase='approach',preview=c.input:previewHeld(),selection=selection}
    self.insec.fallbackOrigin=U.copy(kind=='ally' and self.allyHoldOrigin or origin)
    if c.config.capture then c:log('insec_started',{insecKind=kind,target=U.id(target),name=target.charName,origin=origin,
        wardSlot=c.wards:slot(),preview=self.insec.preview,flash=false,selection=selection}) end
    if kind=='ally' then self.insec.destination,self.insec.recipient,self.insec.recipientKind=self:allyDestination(target,self.insec.fallbackOrigin)
    elseif c.config:get('aimLock')==1 then
        self.insec.destination=U.copy(c.aim);self.insec.locked=true
        local direction=U.toward(target.pos,c.aim,1);self.insec.direction={x=direction.x-target.pos.x,z=direction.z-target.pos.z}
    end
    return true
end
function B:cancel(reason)
    if self.insec then
        if self.ctx.config.capture then self.ctx:log('insec_cancelled',{reason=reason or 'Mode released / input takeover',phase=self.insec.phase,
            outcome=self.insec.preview and 'Preview ended' or self.insec.commitAt and 'Stopped after resource commitment' or 'Stopped before resource commitment',
            target=U.id(self.insec.target),plan=self.insec.resource,flashReason=self.insec.flashReason,
            targetVisible=self.insec.target.visible,targetDead=self.insec.target.dead,targetHP=self.insec.target.health,
            targetable=self.insec.target.isTargetable,leeDead=myHero.dead,leeHP=myHero.health,
            rState=Game.CanUseSpell(3),rCooldown=self.ctx:spell(3).currentCd,energy=myHero.mana,
            cursorHeld=self.ctx.input:held('cursorKey'),allyHeld=self.ctx.input:held('allyKey'),
            chat=Game.IsChatOpen and Game.IsChatOpen(),focus=Game.IsOnTop and Game.IsOnTop(),
            lastInput=self.ctx.input.lastPhysicalEvent,lastTransition=self.ctx.input.lastTransition,mode=self.ctx.mode,
            request=self.insec.event and self.insec.event.id,castStatus=self.insec.event and self.insec.event.status}) end
        self.actions:cancel('insec')
        if self.wards.pending and self.wards.pending.owner=='insec' then self.wards:cancel('Insec released') end
        self.insec=nil
    end
end
function B:insecOrbwalkAllowed()
    local c=self.ctx;local i=self.insec
    if not c.config:get('insecOrbwalk') or (c.mode~='cursor' and c.mode~='ally')
        or not c.input:held(c.mode=='cursor' and 'cursorKey' or 'allyKey')
        or c.input:previewHeld() or c.input.cancel or c:blocked() or c:recalling()
        or c.wards.pending or c:combatTransit() or c.leveling.pending then return false end
    return not i or i.orbwalking and not i.preview and not i.confirmBlocked and not i.flight and not i.qWait
        and i.phase~='kick' or false
end
function B:orbwalkInsec(suppressed)
    local c=self.ctx
    if suppressed or not self:insecOrbwalkAllowed() then return end
    c.moveTarget=c.aim
    local target=self.insec and self.insec.target
    if not c:enemyValid(target) or U.dist(myHero.pos,target.pos)>c:attackRange(target) then
        target=c:target(c:attackRange(myHero)+100)
    end
    if c:enemyValid(target) and U.dist(myHero.pos,target.pos)<=c:attackRange(target) then c.attackTarget=target end
end
function B:confirmPreview()
    local i=self.insec;local c=self.ctx
    if not i or not i.preview or c.input:previewHeld() then return false end
    if not c.input:held(i.kind=='cursor' and 'cursorKey' or 'allyKey') then return false end
    local shown=i.displayPlan or i.plan
    i.preview=false;i.search=nil;i.displayPlan=nil
    if not shown then i.confirmBlocked=true;i.resource='No shown plan to confirm; hold Alt to preview';return false end
    i.contract={};i.contractIndex=1;i.flashConsent=false
    for _,step in ipairs(shown.steps) do
        i.contract[#i.contract+1]={kind=step.kind,unitID=U.id(step.unit),itemID=step.itemID}
        if step.kind=='flash' then i.flashConsent=true end
    end
    i.plan=shown;i.approvedLabel=shown.label;i.at=c:now();i.confirmBlocked=nil
    self.planner:committed(i,c.aim)
    if c.config.capture then c:log('insec_confirmed',{plan=shown.label,flash=i.flashConsent,target=U.id(i.target),resources=i.contract}) end
    return true
end
function B:previewTick(i)
    local c=self.ctx
    local r=c:spell(3)
    if (r.level or 0)==0 or (r.currentCd or 0)>0 then
        i.plan=nil;i.displayPlan=nil;i.resource='R on cooldown / not learned';i.phase='preview';c.status='ALT PREVIEW | '..i.resource;return
    end
    self:geometry(i)
    if not i.stand then return end
    local plan=self.planner:adapt(i,self.planner:search(i))
    if plan and self.planner:validate(i,plan) then i.plan=plan
    elseif i.plan and not self.planner:validate(i,self.planner:adapt(i,i.plan)) then i.plan=nil end
    i.phase='preview';i.resource=i.plan and i.plan.label or 'No complete opportunity yet'
    local _,reason=self.planner:flashAllowed(i);i.flashReason=reason
    if c.config.capture then c:trace('insec_preview',{target=U.id(i.target),targetPos=U.copy(i.target.pos),plan=i.plan and i.plan.label,
        stand=U.copy(i.stand),endpoint=U.copy(i.endpoint),searching=i.search and not i.search.done,
        resources=i.plan and i.plan.steps and #i.plan.steps or 0,flashReason=reason},tostring(U.id(i.target)),.25) end
    c.status='ALT PREVIEW | Release Alt to confirm | '..i.resource
end
function B:geometry(i,wardPlacement)
    local c=self.ctx
    if i.kind=='ally' and i.recipient and (i.recipient.dead or i.recipient.valid==false or (i.recipient.health or 0)<=0) then
        i.locked=nil;i.direction=nil;i.recipient=nil
        i.destination,i.recipient,i.recipientKind=self:allyDestination(i.target,i.fallbackOrigin or i.origin)
    end
    if i.kind=='ally' and not i.locked and c.config:get('insecTrackAlly') then
        local destination,recipient,kind=self:allyDestination(i.target,i.fallbackOrigin or i.origin,i.recipient)
        if kind=='structure' or i.recipientKind=='structure' or not U.valid(i.recipient) then
            i.destination,i.recipient,i.recipientKind=destination,recipient,kind
        else i.destination=U.copy(i.recipient.pos) end
    end
    local aim=i.destination or c.aim
    if i.locked and i.direction then
        aim={x=i.target.pos.x+i.direction.x*1200,y=i.target.pos.y,z=i.target.pos.z+i.direction.z*1200}
    end
    if i.kind=='cursor' and c.config:get('aimLock')==3 then aim=c.aim end
    if not aim or U.dist(aim,i.target.pos)<10 then return end
    i.stand,i.endpoint=self:direction(i.target,aim)
    i.geometryTarget=U.copy(i.target.pos)
    i.plannedTarget=i.target.pos;i.plannedEndpoint=i.endpoint
    local lead=c.config:get('insecLead')/1000
    local pending=c.wards.pending
    local wardStep=i.plan and i.plan.steps and i.plan.steps[1] and i.plan.steps[1].kind=='ward'
    if c.config:get('insecAutoLead') and (wardPlacement or wardStep or pending and pending.owner=='insec') then
        local remaining=self.tactics:wardArrival()
        if pending and pending.owner=='insec' then remaining=remaining-math.max(0,c:now()-pending.at) end
        lead=math.max(lead,U.clamp(remaining,0,.65))
    end
    i.predictionLead=lead
    if i.target.GetPrediction and i.target.pathing and i.target.pathing.hasMovePath and lead>0 then
        local ok,p=pcall(i.target.GetPrediction,i.target,math.huge,lead)
        if ok and p and type(p.x)=='number' and type(p.z)=='number' and p.x==p.x and p.z==p.z
            and U.dist(p,i.target.pos)<300 then
            i.plannedTarget=p
            local futureAim=i.locked and i.direction and {x=p.x+i.direction.x*1200,y=p.y,z=p.z+i.direction.z*1200} or aim
            i.stand=U.toward(p,futureAim,-math.min(c.config:get('insecStandDistance'),c.profile.rRange-45))
            i.plannedEndpoint=U.toward(p,futureAim,c.profile.kickDistance)
        end
    end
    return aim
end
function B:kickValid(i)
    if not self.ctx:enemyValid(i.target) or self:kickProtected(i.target) or not self:aligned(i.target,i.endpoint) then return false end
    local target=i.target
    if target.GetPrediction and target.pathing and target.pathing.hasMovePath then
        local ok,p=pcall(target.GetPrediction,target,math.huge,.25)
        if not ok or not p or type(p.x)~='number' or type(p.z)~='number' or p.x~=p.x or p.z~=p.z then return false end
        local aim=i.destination or self.ctx.aim
        if i.locked and i.direction then aim={x=p.x+i.direction.x*1200,y=p.y,z=p.z+i.direction.z*1200} end
        if i.kind=='cursor' and self.ctx.config:get('aimLock')==3 then aim=self.ctx.aim end
        local endpoint=U.toward(p,aim,self.ctx.profile.kickDistance)
        if not self:aligned({pos=p},endpoint) then return false end
    end
    return true
end
function B:kickProtected(target)
    if target.spellShield==true or U.buff(target,P.kickBlocked,self.ctx:now()) then return true end
    if self.ctx.profile.id=='normal' and U.buff(target,{fioraw=true},self.ctx:now()) then return true end
    for _,buff in ipairs(U.buffs(target)) do
        if buff.type==4 and (buff.expireTime or buff.endTime or math.huge)>self.ctx:now() then return true end
    end
    return false
end
function B:wardFollowValid(p)
    if p.owner~='insec' then return true end
    local i=self.insec
    local r=self.ctx:spell(3)
    if not i or not self.ctx:enemyValid(i.target) or self:kickProtected(i.target)
        or not self:geometry(i) or (r.level or 0)==0 or (r.currentCd or 0)>0 then return false end
    -- Called immediately before W, including the fast ward-spawn callback.
    -- This closes the gap where the target moves before the ordinary tick.
    local from=p.target and p.target.pos or p.pos
    if (myHero.mana or 0)<(self.ctx:spell(1).mana or 0)+(self.ctx:spell(3).mana or 0) then return false end
    if self:aligned(i.target,i.endpoint,from) then return true end
    local plan=self.planner:adapt(i,i.plan)
    if self.planner:validate(i,plan,from,self.ctx:spell(1).mana or 0) then return true end
    -- Only when the cheap continuation check fails do we rebuild from the
    -- observed ward. This callback never executes another resource itself.
    i.plan=self.planner:plan(i,from,nil,self.ctx:spell(1).mana or 0)
    return i.plan~=nil
end
function B:insecTick()
    local c=self.ctx;local i=self.insec;if not i then return end
    if not c:enemyValid(i.target) then self:cancel('Target unavailable');return end
    if i.phase=='kick' then
        if i.event.status=='observed' or i.event.status=='completed' then
            i.event.status='completed';if c.config.capture then c:log('insec_completed',{target=U.id(i.target),request=i.event.id,
                evidence='R cast acknowledged; displacement assessed separately'}) end
            self.completedSerial=(self.completedSerial or 0)+1;self.insec=nil;return
        elseif (i.event.status=='unconfirmed' or i.event.status=='cancelled') and c:ready(3) then
            if c.config.capture then c:log('insec_kick_retry',{target=U.id(i.target)}) end;i.phase='replan';i.event=nil
        else return end
    end
    if c.input:previewHeld() and not i.preview then
        -- Already dispatched motion must settle. Alt pauses subsequent actions;
        -- it cannot retract a ward placement, dash or R that the game accepted.
        if c.wards.pending or c:dash() then i.resource='Waiting for current jump before preview';return end
        if i.flight then
            local f=i.flight
            if c:now()<=f.deadline and (U.dist(myHero.pos,f.origin)<=60
                or f.event and f.event.status~='observed' and f.event.status~='completed') then return end
            i.flight=nil
        end
        if i.qWait then
            if c:mark(i.qWait.unit) and c:stage(0)==2 then i.used.q=nil;i.qWait=nil
            elseif c:now()>i.qWait.deadline or not U.valid(i.qWait.unit) then i.qWait=nil
            else i.resource='Waiting for Q result before preview';return end
        end
        i.preview=true;i.contract=nil;i.flashConsent=false;i.search=nil;i.plan=nil;i.displayPlan=nil;i.confirmBlocked=nil;i.commitAt=nil
    end
    if i.preview then
        if c.input:previewHeld() then self:previewTick(i);return end
        self:confirmPreview()
    end
    if i.confirmBlocked then c.status=i.resource;return end
    if i.commitAt and c:now()-i.commitAt>c.config:get('insecTimeout') then self:cancel('Insec timeout');return end
    local r=c:spell(3)
    if (r.level or 0)==0 or (r.currentCd or 0)>0 then self:cancel('R cooldown / not learned');return end
    -- Native R castability is checked when R is issued. It must not discard
    -- a still-valid Q2 window while approaching or recovering from CC.
    local aim=self:geometry(i)
    if not aim then c.status='Aim away from the selected champion';return end
    if c:now()>=(i.traceAt or 0) then
        i.traceAt=c:now()+.25
        local buffs={};for _,buff in ipairs(U.buffs(i.target)) do
            if #buffs>=12 then break end
            buffs[#buffs+1]={name=buff.name,count=buff.count,expires=buff.expireTime,type=buff.type}
        end
        if c.config.capture then c:log('insec_state',{target=U.id(i.target),targetPos=U.copy(i.target.pos),origin=U.copy(myHero.pos),
             phase=i.phase,stand=U.copy(i.stand),endpoint=U.copy(i.endpoint),plan=i.resource,
             fallbackOrigin=U.copy(i.fallbackOrigin),recipient=U.id(i.recipient),recipientKind=i.recipientKind,
             used=i.used,qWaitTarget=i.qWait and U.id(i.qWait.unit),qReady=c:ready(0),qStage=c:stage(0),
             qState=Game.CanUseSpell(0),wState=Game.CanUseSpell(1),rState=Game.CanUseSpell(3),
            kickValid=self:kickValid(i),rReady=c:ready(3),wReady=c:ready(1),wStage=c:stage(1),
            wardSlot=c.wards:slot(),wardState=c.wards.pending and c.wards.pending.state,
            cursorStep=c.sdk.Cursor and c.sdk.Cursor.Step,targetBuffs=buffs,flashReason=i.flashReason}) end
    end
    if self:kickProtected(i.target) then
        i.orbwalking=true;i.plan=nil;i.resource='Waiting: spell shield / kick immunity';c.status=i.resource;return
    end
    c.status='Insec: '..i.phase..(i.locked and ' | AIM LOCKED' or ' | aiming')
    self.planner:tick(i,aim)
end
function B:kickHits(target,from)
    if not self.ctx:enemyValid(target) then return 0 end
    local endPos=U.toward(from or myHero.pos,target.pos,U.dist(from or myHero.pos,target.pos)+self.ctx.profile.kickDistance)
    local hits=1
    for _,e in ipairs(self.ctx.enemies or {}) do
        if self.ctx:enemyValid(e) and not U.same(e,target) then
            local d,t=U.segment(e.pos,target.pos,endPos)
            if t>0 and d<100+(e.boundingRadius or 65) then hits=hits+1 end
        end
    end
    return hits,endPos
end
function B:multi(target,allowReposition)
    local c=self.ctx
    if not c.config:get('comboR') or not c:ready(3) or c:combatTransit() or self.wards.pending then return false end
    if not c.config:get('multi') and not c.config:get('collateralKills') then return false end
    local now=c:now()
    if now<(self.kickSearchAt or 0) then return false end
    self.kickSearchAt=now+.08
    local plan=self.kicks:best(allowReposition~=false and now>=(self.wards.fightRetryAt or 0))
    if not plan then return false end
    self.kickProposal=plan
    if plan.ward then
        if not self:wardOpportunity(plan.primary,true) then return false end
        local function valid()
            if not self:wardOpportunity(plan.primary,true) then return false end
            local current=self.kicks:evaluate(plan.primary,plan.origin,true)
            return current and current.worthwhile and current.hits>=2 or false
        end
        if self.wards:start(plan.origin,'fight',true,nil,valid) then
            self.multiTarget={target=plan.primary,untilTime=now+1.5};if c.config.capture then c:log('fight_multikick_plan',{
                target=U.id(plan.primary),hits=plan.hits,estimatedKills=plan.kills,secondaryKills=plan.secondaryKills,
                origin=plan.origin,endpoint=plan.endpoint,confidence=c.config:get('mechanicsVerified') and 'measured profile' or 'profile estimate'}) end
            return true
        end
    elseif self:castFightR(plan.primary,true) then
        if c.config.capture then c:log('fight_multikick_cast',{target=U.id(plan.primary),hits=plan.hits,estimatedKills=plan.kills,
            secondaryKills=plan.secondaryKills,endpoint=plan.endpoint}) end;return true
    end
    return false
end
function B:defense()
    local c=self.ctx
    if not c.config:get('idleDefense') or self.wards.pending or self.insec or c:combatTransit() then return false end
    if c.config:get('reserveW') then return c.emergencyShield:tick() end
    local threatened=c:threats(myHero.pos,850)>0
    if c:stage(1)==1 and threatened and U.hp(myHero)<=c.config:get('shieldHP') then
        return self.spells:w(myHero,'defense',true)
    end
    if c:stage(1)==1 then
        for _,a in ipairs(c.allies or {}) do
            if U.hp(a)<=c.config:get('allyShieldHP') and c:threats(a.pos,700)>0 and not c:underTurret(a.pos)
                and U.dist(myHero.pos,a.pos)<=c.profile.wRange then return self.spells:w(a,'defense',true) end
        end
    end
    return false
end
function B:killsteal(inFight)
    local c=self.ctx;local lock=c:locked();local candidates={}
    if c:combatTransit() then return false end
    for _,target in ipairs(lock and {lock} or c.enemies or {}) do
        if c:enemyValid(target) then
            local distance=U.dist(myHero.pos,target.pos)
            local function hp(slot)return U.typedHP(target,slot==2 and 'magic' or 'physical')+c.config:get('combatDamageMargin')+(target.hpRegen or 0)*.8 end
            local function add(slot,stage,delay,cost)
                if (not inFight or c.config:get(slot==0 and stage==2 and 'comboQ2' or ({[0]='comboQ',[2]='comboE',[3]='comboR'})[slot]))
                    and c:ready(slot) and c:combatDamage(slot,target,stage)>=hp(slot) then
                    candidates[#candidates+1]={slot=slot,stage=stage,target=target,delay=delay,cost=cost}
                end
            end
            if c.config:get('killE') and c:stage(2)==1 and distance<=c.profile.eRange then add(2,1,.25,1) end
            if c.config:get('killQ') and c:stage(0)==1 and distance<=c.profile.qRange then add(0,1,.25+distance/c.profile.qSpeed,1) end
            if c.config:get('killQ2') and c:stage(0,target)==2 and c:mark(target) and distance<=c.profile.q2Range then add(0,2,.15+distance/1800,2) end
            if c.config:get('killR') and distance<=c.profile.rRange then add(3,1,.25,4) end
        end
    end
    table.sort(candidates,function(a,b)
        local aa,bb=math.floor(a.delay/.08+.5),math.floor(b.delay/.08+.5)
        if aa~=bb then return aa<bb end
        if a.cost~=b.cost then return a.cost<b.cost end
        return a.delay<b.delay
    end)
    for _,candidate in ipairs(candidates) do
        local t=candidate.target;local ok
        if candidate.slot==2 then ok=self.spells:e(t,'killsteal')
        elseif candidate.slot==3 then
            local policy=inFight and 'fight' or 'killsteal'
            if self:allowFinisherR(t,policy) then ok=self.spells:r(t,'killsteal',false,function()return self:allowFinisherR(t,policy)end) end
        elseif candidate.stage==2 then ok=self.spells:q2(t,'killsteal',false,true)
        else ok=self.spells:q1(t,'killsteal',false) end
        if ok then return true end
    end
    return false
end
function B:followAllowed(target)
    local c=self.ctx
    if not c.config:get('comboQ2') or not c.config:get('comboKickFollow') or not c:mark(target)
        or c:stage(0,target)~=2 or not c:ready(0) or c:markLeft(target)<math.max(.5,c.latency+.35)
        or (myHero.mana or 0)<(c:spell(0).mana or 0)+(c:spell(3).mana or 0) then return false end
    local _,endpoint=self:kickHits(target)
    return not c.config:get('q2Safety') or not c:underTurret(endpoint)
end
function B:cheapFinish(target,owner)
    local c=self.ctx
    if not c.config:get('comboConserveR') then return false,'conservation_disabled' end
    local result=self.tactics:assess(target,owner or 'fight')
    self.finishAssessment=result
    if result.lethal then
        local now=c:now();local promise=self.finishPromise
        if promise and promise.target==U.id(target) and target.health>=promise.health-.5 then
            if now>promise.untilTime then return false,'cheaper_plan_made_no_damage_progress' end
        else
            self.finishPromise={target=U.id(target),health=target.health,
                untilTime=now+result.lethal.t+c.latency+math.max(.08,c.jitter*2)}
        end
    else self.finishPromise=nil end
    return result.lethal~=nil,result.lethal and (result.lethal.path or 'observed_attack_lethal') or 'no_timely_cheaper_finish'
end
function B:allowFinisherR(target,owner)
    local c=self.ctx;local cheaper,reason=self:cheapFinish(target,owner)
    if c.config.capture then c:trace('r_finisher_decision',{target=U.id(target),name=target.charName,owner=owner,
        allowed=not cheaper,reason=reason,health=target.health,physicalHP=U.typedHP(target,'physical'),
        distance=U.dist(myHero.pos,target.pos),pendingAA=c:pendingAttackDamage(target,.25),
        aaDamage=c:aaDamage(target),qDamage=c:combatDamage(0,target,1),qReady=c:ready(0),qStage=c:stage(0,target),
        eReady=c:ready(2),eStage=c:stage(2),conserve=c.config:get('comboConserveR'),
        horizon=self.finishAssessment and self.finishAssessment.horizon,
        expansions=self.finishAssessment and self.finishAssessment.expanded,
        finishTime=self.finishAssessment and self.finishAssessment.lethal and self.finishAssessment.lethal.t},
        tostring(U.id(target))..':'..tostring(cheaper)..':'..tostring(reason),.4) end
    return not cheaper,cheaper and 'cheaper_finish_available' or nil
end
function B:castFightR(target,multiple,purpose)
    local c=self.ctx;purpose=multiple and 'multi' or purpose or 'execute'
    local follow=self:followAllowed(target)
    local function valid()
        if multiple then
            local plan=self.kicks:evaluate(target,myHero.pos,false)
            return plan and plan.hits>=2 and plan.worthwhile or false,'multi_no_longer_worthwhile'
        end
        if not self:allowFinisherR(target,'fight') then return false,'cheaper_finish_available' end
        local damage=c:combatDamage(3,target)
        if purpose=='follow' then
            if not self:followAllowed(target) then return false,'q2_follow_unavailable' end
            local after=math.max(0,target.health-math.max(0,damage-(target.allShield or 0)-(target.shieldAD or 0)))
            local burst=damage+c:combatDamage(0,target,2,after)>=U.typedHP(target,'physical')+15
            return burst or self:isolateUseful(target),'kick_follow_no_longer_useful'
        end
        return damage>=U.typedHP(target,'physical')+10,'r_no_longer_lethal'
    end
    local ok,event=self.spells:r(target,'fight',false,valid)
    if ok and follow then
        self.rFollow={target=target,event=event,untilTime=self.ctx:now()+math.min(2,self.ctx:markLeft(target)),
            targetOrigin=U.copy(target.pos),health=target.health}
    end
    if ok and c.config.capture then c:log('fight_kick_requested',{request=event.id,target=U.id(target),
        pos=U.copy(target.pos),purpose=purpose,health=target.health,physicalHP=U.typedHP(target,'physical'),
        rDamage=c:combatDamage(3,target),markLeft=c:markLeft(target),follow=follow,
        multiMinimum=multiple and c.config:get('multiHits') or nil}) end
    return ok,event
end
function B:followKick()
    local c=self.ctx;local f=self.rFollow;if not f then return false end
    local lock=c:locked()
    local active=myHero.activeSpell
    local q2Used=active and active.valid and U.name(active.name):find('leesinqtwo',1,true)
    if not c.config:get('comboQ2') or not c.config:get('comboKickFollow') or not c.config:get('comboR')
        or lock and not U.same(lock,f.target) or not c:enemyValid(f.target) or c:now()>f.untilTime
        or not c:mark(f.target) or q2Used or c:stage(0,f.target)~=2 or f.event.status=='unconfirmed' or f.event.cancelled then
        if c.config.capture then c:log('fight_kick_cancelled',{target=U.id(f.target),event=f.event.status}) end;self.rFollow=nil;return false
    end
    c.attackTarget=f.target
    if f.event.status=='observed' or f.event.status=='completed' then
        local moved=f.targetOrigin and U.dist(f.target.pos,f.targetOrigin)>60
        local elapsed=c:now()-(f.event.observedAt or f.event.at or c:now())
        -- Follow the confirmed kick before its full displacement puts Q2 out
        -- of range. Expiry is urgent, but never bypasses R acknowledgement.
        if moved or elapsed>=.25 or c:markLeft(f.target)<.4 then
            if self.spells:q2(f.target,'fight',false,true) then
                if c.config.capture then c:log('fight_kick_follow',{target=U.id(f.target),delay=elapsed,moved=moved,
                    distance=U.dist(myHero.pos,f.target.pos),markLeft=c:markLeft(f.target)}) end
                self.rFollow=nil
            end
        end
    end
    return true
end
function B:fastBurst(target)
    if not self.ctx.config:get('comboBurst') then return false end
    local horizon=self.tactics:window(target)
    local finish=self.tactics:assess(target,'fight',math.min(.8,horizon)).lethal
    return finish~=nil and finish.first~=nil and finish.first~='AA'
end
-- Draw callback can finish a confirmed ward landing without waiting for the
-- next expensive planning tick. No graph search and no uncancellable R queue.
function B:fastKick()
    local c=self.ctx;local i=self.insec
    if not i or i.preview or i.confirmBlocked or i.phase=='kick' or i.flight or i.qWait
        or c:blocked() or c:dash() or c.wards.pending or c.input:previewHeld()
        or not c.input:held(i.kind=='cursor' and 'cursorKey' or 'allyKey')
        or (c:spell(3).level or 0)==0 or not c:ready(3) or c.actions.pending[3]
        or i.commitAt and c:now()-i.commitAt>c.config:get('insecTimeout')
        or not U.valid(i.target) or U.dist(myHero.pos,i.target.pos)>c.profile.rRange then return false end
    if not self:geometry(i) or not self:kickValid(i) then return false end
    local ok,event=c.spells:r(i.target,'insec',true)
    if ok then i.phase='kick';i.event=event end
    return ok
end
function B:passiveHold(target)
    local c=self.ctx
    if not c.config:get('comboPassive') or not c.clear:weaving() or U.dist(myHero.pos,target.pos)>c:attackRange(target) then return false end
    local a=c.sdk.Attack;local cycle=a.GetAnimation and a:GetAnimation() or 1
    local wait=a.IsReady and not a:IsReady() and math.max(0,(a.ServerStart or c:now())+cycle-c:now()) or 0
    local impact=wait+c:windup()+c.latency*.5
    if impact>c.clear.passiveUntil-c:now() then return false end
    if c:mark(target) and impact+.65>=c:markLeft(target) then return false end
    if self:fastBurst(target) then return false end
    if target.GetPrediction and target.pathing and target.pathing.hasMovePath then
        local ok,p=pcall(target.GetPrediction,target,math.huge,impact)
        if not ok or not p or U.dist(myHero.pos,p)>c:attackRange(target) then return false end
    end
    return true
end
function B:chaseMotion(target)
    local now=self.ctx:now();local lock=0;local gg=_G.GGPrediction
    if gg and type(gg.GetImmobileDuration)=='function' then
        local ok,duration=pcall(gg.GetImmobileDuration,gg,target)
        if ok and U.finite(duration) then lock=math.max(0,duration) end
    else
        -- These types are defined by the installed GG runtime, in both maps.
        for _,buff in ipairs(U.buffs(target)) do
            if buff.type==5 or buff.type==12 or buff.type==25 or buff.type==30 or buff.type==35 then
                lock=math.max(lock,(U.buffEnd(buff) or now)-now)
            end
        end
    end
    local origin=U.copy(target.pos);local path=target.pathing
    local endpoint=path and path.hasMovePath and path.endPos
    local speed=U.finite(target.ms) and math.max(0,target.ms) or 0
    if not endpoint or not U.finite(endpoint.x) or not U.finite(endpoint.z) then speed=0;endpoint=origin end
    local length=U.dist(origin,endpoint)
    local function at(delay)
        return U.toward(origin,endpoint,math.min(length,speed*math.max(0,delay-lock)))
    end
    return at,lock,speed
end
function B:chaseDecision(target)
    local c=self.ctx;local at,lock,speed=self:chaseMotion(target)
    if target.pathing and target.pathing.isDashing then return false,nil,'Wait for enemy dash destination' end
    local ownSpeed=U.finite(myHero.ms) and math.max(1,myHero.ms) or 350
    local range=c:attackRange(target);local wait=c.config:get('comboWalkWait')/1000
    local arrival=self.tactics:wardArrival()
    local future=at(arrival);local distance=U.dist(myHero.pos,future)
    local landing=U.toward(myHero.pos,future,math.max(0,distance-math.min(100,range*.5)))
    local reason
    if c:underTurret(future) or c:underTurret(at(arrival+.6)) then reason='Target escaping into turret range'
    elseif U.dist(myHero.pos,landing)>self.wards:range() then reason='Predicted landing outside ward range'
    else
        local walkTime=math.huge
        -- A bounded local intercept estimate follows the current path and its
        -- endpoint. Recomputed before resource spending; no ground detour.
        local horizon=math.max(wait,arrival+c.config:get('comboWardGain')/1000)
        for n=1,16 do
            local dt=horizon*n/16
            if U.dist(myHero.pos,at(dt))<=range+ownSpeed*dt then walkTime=dt;break end
        end
        if walkTime<=wait then reason='Walking reaches attack range soon'
        elseif walkTime-arrival<c.config:get('comboWardGain')/1000 then reason='Wardjump saves too little time' end
        if c.config.capture then c:trace('combo_chase',{target=U.id(target),reason=reason or 'Ward saves approach time',
            ownSpeed=ownSpeed,targetSpeed=speed,immobile=lock,walkTime=walkTime<math.huge and walkTime or nil,
            arrival=arrival,landing=landing,future=future},tostring(U.id(target)),.4) end
    end
    return not reason,landing,reason
end
function B:gapclose(target)
    local c=self.ctx
    -- A blocked/temporarily reserved Q2 must not fall through to a ward entry.
    -- Preserving a marked Q for R-follow is an explicit optional playstyle.
    if not c.config:get('comboWardPreserveQ') and c:stage(0,target)==2 and c:mark(target) then return false end
    local flight,phase,remaining=self.spells:q1Reservation(target)
    if flight then
        if c.config.capture then c:trace('combo_chase',{target=U.id(target),reason=phase=='queued'
                and 'Q1 queued; preserve ward' or 'Wait for own Q1 impact before spending a ward',
            request=flight.event.id,phase=phase,remaining=remaining},tostring(U.id(target)),.4) end
        return false
    end
    if not c.config:get('comboWard') or not c.config:get('comboW') or not self.wards:available()
        or self.wards.pending or U.hp(myHero)<=c.config:get('shieldHP') then return false end
    local distance=U.dist(myHero.pos,target.pos);local stop=math.min(100,c:attackRange(target)*.5)
    if distance<=c:attackRange(target)+60 or distance-stop>self.wards:range() then return false end
    if c.config:get('comboChaseE2') and c.config:get('comboE2') and c:stage(2)==2 and c:ready(2)
        and c.spells:e(target,'fight') then return true end
    if not self:wardOpportunity(target,false) then return false end
    local allowed,landing=self:chaseDecision(target)
    if not allowed then return false end
    if c:underTurret(landing) or c.terrain:wall(landing)~=false then return false end
    return self.wards:start(landing,'fight',true,nil,function()
        if not self:wardOpportunity(target,false) or U.dist(myHero.pos,target.pos)<=c:attackRange(target)+60 then return false end
        local useful,newLanding=self:chaseDecision(target)
        return useful and U.dist(newLanding,landing)<100 and not c:underTurret(landing)
    end,function()
        -- The ward is already spent. Re-evaluating whether to buy that same
        -- approach again can strand the follow-up as soon as a slow expires.
        if not c:enemyValid(target) then return false,'Chase target unavailable' end
        if c:underTurret(landing) then return false,'Chase landing under turret' end
        local at=self:chaseMotion(target)
        local future=at(c.metrics.wardDashDuration or c.config:get('insecDashEstimate')/1000)
        if U.dist(landing,future)>c:attackRange(target)+60 then return false,'Chase target left ward landing' end
        if U.dist(myHero.pos,target.pos)<=c:attackRange(target) then return false,'Target already in attack range' end
        return true
    end)
end
function B:wardOpportunity(target,multiple)
    local c=self.ctx
    if c:combatTransit() or not c:enemyValid(target) or c:mark(target) then return false end
    if self.spells:q1Reservation(target) then return false end
    if not multiple and c.config:get('comboQ') and c:ready(0) and c:stage(0)==1 then
        local aim=self.spells:predict(target)
        if aim and #self.spells:blockers(target,aim)==0 and not self.spells:projectileWall(aim) then return false end
    end
    return true
end
function B:harass(owner)
    local c=self.ctx;owner=owner or 'harass'
    if c:combatTransit() or self.wards.pending then return false end
    local target=c:target(c.profile.qRange);if not target then return false end
    c.attackTarget=target
    if self:rotation(target,owner) then return true end
    if c.config:get('harassR') and not self:cheapFinish(target,owner) then return self.spells:r(target,owner) end
    return false
end
function B:rotation(target,owner,options)
    local horizon=self.tactics:window(target)
    options=options or {}
    local result=self.tactics:assess(target,owner,math.min(options.horizon or 1.5,horizon),options)
    local plan=result.lethal or result.best
    if not plan then
        -- The survival horizon limits committed melee/finisher sequences. A
        -- ranged poke can be launched now and finish travelling after we leave.
        -- Keep this fallback out of lethal-R comparisons and all gapclosers.
        if owner=='harass' and result.model and result.model.lookup.Q1 then
            self.spells:q1Status(target,owner,'harass_projectile_beyond_plan_horizon')
            return self.spells:q1(target,owner,false)
        end
        return false
    end
    if self.ctx.config.capture then self.ctx:trace('combat_plan',{owner=owner,target=U.id(target),
        path=plan.path,first=plan.first,finish=plan.hp<=0,time=plan.t,horizon=result.horizon,
        conditional=plan.conditional,estimated=result.estimated,expanded=result.expanded},tostring(U.id(target))..':'..tostring(plan.first),.5) end
    -- The orbwalker remains the sole AA dispatcher. Future actions are never
    -- enqueued as a fixed macro: observe and rebuild after each actual action.
    if not plan.first or plan.first=='AA' then return true end
    return self.tactics:cast(plan.first,target,owner)
end
function B:isolateUseful(target)
    if not self.ctx.config:get('comboIsolate') then return false end
    local _,endpoint=self:kickHits(target);local before,after=math.huge,math.huge
    for _,enemy in ipairs(self.ctx.enemies or {}) do
        if not U.same(enemy,target) and self.ctx:enemyValid(enemy) then
            before=math.min(before,U.dist(target.pos,enemy.pos));after=math.min(after,U.dist(endpoint,enemy.pos))
        end
    end
    return before<650 and after>before+300
end
function B:fight()
    local c=self.ctx;local target=c:target(c.profile.q2Range)
    local focus=c.attackFocus
    if focus and c:now()-focus.at<c:windup()+.1 and focus.selected==c:locked() and c:enemyValid(focus.target)
        and U.dist(myHero.pos,focus.target.pos)<=c.profile.q2Range then target=focus.target end
    c.attackTarget=target;c.moveTarget=c.aim
    if c:combatTransit() or self.wards.pending then return end
    if self:followKick() then return end
    if self.multiTarget then
        local continuation=self.kicks:evaluate(self.multiTarget.target,myHero.pos,false)
        if not c.config:get('comboR') or c:now()>self.multiTarget.untilTime or not continuation then self.multiTarget=nil
        elseif continuation.worthwhile and self:castFightR(self.multiTarget.target,true) then self.multiTarget=nil;return end
    end
    if self:killsteal(true) then return end
    if self:multi(target) then return end
    if not target then return end
    c.clear:observe()
    local lead=math.max(.3,c.latency*.5+c.jitter*2+.15)
    if c.config:get('comboQ2') and c:stage(0)==2 and c:mark(target) and c:markLeft(target)<lead then
        if self.spells:q2(target,'fight',false) then return end
    end
    for _,slot in ipairs({1,2}) do
        if c.config:get(slot==1 and 'comboW2' or 'comboE2') and c:stage(slot)==2 and c.clear.windows[slot]
            and c.clear.windows[slot]-c:now()<lead then
            local ok
            if slot==1 then ok=self.spells:w(myHero,'fight') else ok=self.spells:e(target,'fight') end
            if ok then return end
        end
    end
    local dist=U.dist(myHero.pos,target.pos)
    local weaving=self:passiveHold(target)
    if c.config:get('comboQ2') and c:stage(0)==2 and c:mark(target) then
        if c:combatDamage(0,target,2)>=U.effectiveHP(target)+10 and self.spells:q2(target,'fight',false,true) then return end
        if c.config:get('comboWardPreserveQ') and c.config:get('comboKickFollow') and c.config:get('comboR')
            and c:ready(3) and c:markLeft(target)>.8 and dist>c.profile.rRange and self:gapclose(target) then return end
        local rDamage=c:combatDamage(3,target)
        local afterR=math.max(0,target.health-math.max(0,rDamage-(target.allShield or 0)-(target.shieldAD or 0)))
        local burst=rDamage+c:combatDamage(0,target,2,afterR)>=U.effectiveHP(target)+15
        local tactical=not weaving and self:isolateUseful(target)
        if c.config:get('comboR') and c:ready(3) and dist<=c.profile.rRange
            and self:followAllowed(target) and (burst or tactical) then
            if not burst and c:markLeft(target)>1.2 and self:rotation(target,'fight',
                {excludeQ2=true,reserveEnergy=(c:spell(0).mana or 0)+(c:spell(3).mana or 0),horizon=c:markLeft(target)-.8}) then return end
            if self:castFightR(target,false,'follow') then return end
        end
    end
    if not weaving then
        if self:rotation(target,'fight') then return end
    end
    -- Offensive item actives also belong to Q1 / no-mark rotations and must
    -- not depend on reaching the old Q2-only branch.
    if c.actives:tick(target,'fight') then return end
    if c.config:get('comboR') and c:combatDamage(3,target)>=U.effectiveHP(target)+10 and self:castFightR(target) then return end
    if c.damageModel:castIgnite(target) then return end
    self:gapclose(target)
end
return B

end
modules["lho.community"] = function(require)
-- LHO gameplay adapter for Orbama Actions v1. No cursor internals are written.
local U=require('lho.util')
local Intent=require('lho.intent')
return function(a)
    local c=a.ctx;local api=c.sdk.Actions
    if not api and c.originalGG then api=require('lho.ggbridge')(c) end
    if not api or api.version~=1 then return end -- Retained GG fixture compatibility.
    a.api=api;a.scope=assert(api:RegisterScope('LHO',{priorities={'critical','interactive','normal','background'}}))
    -- Provider capabilities are immutable for this controller lifetime. Avoid
    -- allocating a fresh capabilities table for every validation/dispatch.
    a.capabilities=api:GetCapabilities()
    a.originalGG=api.provider=='OriginalGG'
    a.owners={};a.keyRequests={};a.dependencies={};a.intentRequests={}
    function a:syncAutomation()
        if not self.capabilities.automationClaims or not self.scope.ClaimAutomation then return end
        -- LHO implements item QSS, not summoner Cleanse. Claim only that actual
        -- enabled service; Close releases the claim on unload/error.
        local enabled=c.config:get('enabled') and c.config:get('items') and c.config:get('idleDefense') and c.config:get('itemCleanse')
        if not enabled then
            if self.qssClaim then self.scope:ReleaseAutomation('qss') end
            self.qssClaim=nil;self.qssRetry=nil;return
        end
        if self.qssClaim or self.qssRetry and self.api:Now()<self.qssRetry then return end
        self.qssClaim=self.scope:ClaimAutomation('qss')==true
        self.qssRetry=not self.qssClaim and self.api:Now()+500 or nil
    end
    function a:inputAction(id) return id and self.scope:GetAction(id) end
    function a:inputNow() return self.api:Now() end
    function a:syncWindow(window)
        if not window or not window.event or not window.event.cursorID then return 'ready' end
        local r=self:inputAction(window.event.cursorID)
        if not r or r.jobCancelled or r.state=='cancelled_before_send' then return 'cancelled' end
        if not r.sentAt then return 'waiting' end
        if not window.sendTimeApplied then
            local sent=c:now()-math.max(0,self.api:Now()-r.sentAt)*.001
            window.deadline=window.deadline+math.max(0,sent-window.event.at)
            window.startedAt=sent;window.sendTimeApplied=true
        end
        return r.state=='send_uncertain' and 'uncertain' or 'ready'
    end
    function a:cursorBusy() local s=self.api:GetAvailability();return s.busy or s.uncertain end
    function a:cursorWaitReason()
        local s=self.api:GetAvailability()
        return s.pendingReturn and 'Checking cursor return' or s.uncertain and 'Waiting for input' or 'Automatic input in progress'
    end
    function a:hasCursorQueue() return true end
    function a:request(q)
        local id,why=self.scope:Request(q)
        if not id then return false,why end
        self.lastCursorAction=id;self.owners[q.owner]=id
        local r=self:inputAction(id)
        if not r then return false,'Action record unavailable' end
        return r.state~='cancelled_before_send',r.reason or r.state,{cursorID=id,keyTick=r.sentAt,
            keyAt=r.sentAt and c:now()-math.max(0,self.api:Now()-r.sentAt)*.001}
    end
    function a:dispatchCursor(key,target,owner,chain,leftClicks,verifyTarget,validate,worldIntent,execution)
        owner=owner or 'default'
        -- Owner history is diagnostic only. Dependencies belong to a concrete
        -- gameplay sequence, never to independent retries such as Autosmite.
        local previous=chain and self.dependencies[owner]
        local prior=previous and self:inputAction(previous)
        if not prior or prior.jobCancelled or prior.state=='cancelled_before_send' then previous=nil end
        local kind=not target and 'none' or target.pos and 'object' or target.z~=nil and 'world' or 'screen'
        local actionType=leftClicks and 'click' or key==(MOUSEEVENTF_RIGHTDOWN or 8) and 'move' or key and 'cast' or 'hover'
        local farmMove=actionType=='move' and owner=='farm' and c.farm
        local moveCamp=farmMove and c.farm.camp
        local moveCombat=farmMove and (c.farm.state=='clearing' or c.farm.state=='finishing')
        local moveStep=moveCombat and c.farm.kiteStep
        local moveKey=moveStep and moveStep.key;local movePhase=moveStep and moveStep.phase
        local intentKey=owner..':'..actionType
        if actionType=='move' or actionType=='hover' then
            local intent=self.intentRequests[intentKey];local action=intent and self:inputAction(intent.id)
            if action and (action.state=='requested' or action.state=='waiting') then
                local same=intent.kind==kind and (kind=='object' and U.same(intent.target,target)
                    or kind=='world' and U.dist(intent.target,target)<5 or kind=='screen' and U.screenDist(intent.target,target)<2)
                if same then self.lastCursorAction=intent.id;return true,'waiting',{cursorID=intent.id} end
                self.scope:Cancel(intent.id,'Movement intent changed before send')
            end
        end
        local priority=execution and execution.priority or (actionType=='hover' and 'background' or Intent.priority(owner))
        local caps=self.capabilities
        local useAim=verifyTarget and kind=='object' and caps.aimCandidates
        local reactiveCast=actionType=='cast' and not previous and kind~='screen'
            and owner~='ward' and owner~='farm' and owner~='secure'
            and (owner~='insec' or c.input:insecMovementHeld())
        if useAim and self.bodyPoint and not U.same(self.bodyPoint.target,verifyTarget) then self.bodyPoint=nil end
        local resolver=execution and execution.resolveWorldTarget
        if resolver and execution.contextValid then
            local resolve=resolver
            resolver=function(...)
                local valid,reason=execution.contextValid();if not valid then return nil,reason end
                return resolve(...)
            end
        end
        local synthetic=c.synthetic;c.synthetic=true
        local ok,why,timing=self:request{type=actionType,targetKind=kind,target=target,keys=key,
            owner=owner,priority=priority,expires=self.api:Now()+500,dependency=previous,handoff=chain==true and previous~=nil,
            count=leftClicks,verifyTarget=not self.originalGG and verifyTarget or nil,world=worldIntent,
            resource=execution and execution.resource,
            resolveWorldTarget=resolver,
            prevalidateWorldCast=resolver and caps.prevalidateWorldCast and not previous and not verifyTarget and true or nil,
            commitGuard=resolver and caps.prevalidateWorldCast and not previous and not verifyTarget and execution.contextValid or nil,
            intentTargetID=execution and execution.intentTargetID,
            survivePointerMotion=reactiveCast
                and caps.survivePointerMotion and true or nil,
            surviveMovementCommands=reactiveCast
                and caps.surviveMovementCommands and true or nil,
            aimCandidates=useAim and function()return require('lho.aim').points(self,verifyTarget,
                (owner=='autosmite' or owner=='secure') and c.config:get('smiteProjectionFallback'))end or nil,
            aimFallback=useAim and caps.aimFallback and (owner=='autosmite' or owner=='secure') and c.config:get('smiteProjectionFallback')
                and function(point)return require('lho.aim').isolated(c,verifyTarget,point)end or nil,
            retryKey=useAim and (tostring(key)..':'..tostring(verifyTarget.networkID)..':'..tostring(verifyTarget.handle)) or nil,
            validate=function()if c:blocked() then return false,'context_blocked' end
                if actionType=='move' and (owner=='cursor' or owner=='ally')
                    and (c.mode~=owner or not c.combat:insecOrbwalkAllowed()) then return false,'insec_movement_superseded' end
                if farmMove then
                    local combat=c.farm.state=='clearing' or c.farm.state=='finishing'
                    local step=c.farm.kiteStep
                    if c.farm.camp~=moveCamp or combat~=moveCombat
                        or moveStep and (not step or step.key~=moveKey or step.phase~=movePhase) then
                        return false,'farm_movement_superseded'
                    end
                end
                if validate then return validate() end;return true end}
        if timing and (actionType=='move' or actionType=='hover') then
            self.intentRequests[intentKey]={id=timing.cursorID,kind=kind,target=kind=='object' and target or U.copy(target)}
        end
        c.synthetic=synthetic;return ok,why,timing
    end
    function a:cancelMoveIntent(owner)
        local intent=self.intentRequests[owner..':move']
        local action=intent and self:inputAction(intent.id)
        if action and not action.sentAt and (action.state=='waiting' or action.state=='requested') then
            self.scope:Cancel(intent.id,'Target attack supersedes pending ground movement')
        end
        self.intentRequests[owner..':move']=nil
    end
    function a:keyAction(keys,owner,kind,validate)
        owner=owner or 'control';kind=kind or 'key'
        local list=type(keys)=='table' and keys or {keys};local signature=owner..':'..kind..':'..table.concat(list,',')
        local id=self.keyRequests[signature];local r=self:inputAction(id)
        if not r then
            local ok,why,timing=self:request{type=kind,targetKind='none',keys=keys,owner=owner,
                priority=owner=='farm' and 'normal' or 'background',expires=self.api:Now()+500,
                validate=function()return not c:blocked() and (not validate or validate()) end}
            if not timing then return false,why,false end
            id=timing.cursorID;self.keyRequests[signature]=id;r=self:inputAction(id)
        end
        if r.state=='waiting' or r.state=='requested' then return false,'waiting',false,id end
        self.keyRequests[signature]=nil
        if r.state=='cancelled_before_send' then return false,r.reason or 'declined',false,id end
        return r.state=='sent',r.state,true,id
    end
    function a:cameraKey(key) return self:keyAction(key,'camera') end
    function a:restoreCameraOnShutdown()
        local lease=self.cameraOwned
        if not lease or not c.config:get('farmRestoreCamera') then return end
        -- The gameplay scope is closed on shutdown. Give this bounded cleanup
        -- its own scope so it survives the unload and cursor stabilization.
        local scope=api:RegisterScope('LHO camera cleanup '..tostring(self.scope.id),{priorities={'interactive'}})
        if not scope then return end
        self.cameraOwned=nil
        local pending={scope=scope,deadline=api:Now()+5000,key=lease.key}
        _G.LHO_CameraCleanup=pending
        local tick
        local function finish(state)
            scope:Close('Camera cleanup '..state)
            for index,fn in ipairs(c.sdk.OnTick) do if fn==tick then c.sdk.OnTick[index]=function()end;break end end
            if _G.LHO_CameraCleanup==pending then _G.LHO_CameraCleanup=nil end
            if c.config.capture then pcall(c.log,c,'camera_shutdown_restore',{state=state}) end
        end
        tick=function()
            if api:Now()>pending.deadline then finish('expired');return end
            if not pending.id then
                if Game.IsChatOpen and Game.IsChatOpen() or Game.IsOnTop and not Game.IsOnTop() then return end
                pending.id=scope:Request{type='key',targetKind='none',keys=lease.key,owner='restore',priority='interactive',
                    expires=pending.deadline,validate=function()
                        return not (Game.IsChatOpen and Game.IsChatOpen()) and not (Game.IsOnTop and not Game.IsOnTop())
                    end}
                if not pending.id then finish('request_declined');return end
            end
            local action=scope:GetAction(pending.id)
            if action and action.sentAt then finish(action.state);return end
            if not action or action.state=='cancelled_before_send' then finish('cancelled');return end
        end
        c.sdk.OnTick[#c.sdk.OnTick+1]=tick;tick()
    end
    function a:attack(target,owner)
        owner=owner or c.mode
        local prior=self:inputAction(self.attackRequest)
        local waiting=prior and (prior.state=='waiting' or prior.state=='requested')
        local ready=c.sdk.Orbwalker:CanAttack() and U.valid(target)
            and U.dist(myHero.pos,target.pos)<=c:attackRange(target)
        if waiting and (not ready or not U.same(self.attackIntentTarget,target) or self.attackIntentOwner~=owner) then
            self.scope:Cancel(self.attackRequest,'Attack intent no longer ready');waiting=false
        end
        -- A cooling-down or out-of-range attack must not reserve this tick and
        -- suppress the move that kites or brings the target back into range.
        if not ready then return false,'attack_not_ready','not_requested' end
        self:cancelMoveIntent(owner)
        if waiting then return true,'waiting','waiting' end
        self.attackIntentTarget=target;self.attackIntentOwner=owner
        local ok,why,timing=self:request{type='attack',targetKind='object',target=target,owner=owner,
            priority=owner=='farm' and 'background' or 'normal',expires=self.api:Now()+150,
            validate=function()return not c:blocked() and not c:recalling() and U.valid(target)
                and U.same(c.attackTarget,target) and c.mode==owner
                and ((owner~='cursor' and owner~='ally') or c.combat:insecOrbwalkAllowed()) end}
        self.attackRequest=timing and timing.cursorID
        local action=self:inputAction(self.attackRequest)
        return ok,why,action and action.state or 'not_requested'
    end
    function a:attackApproach(target,owner,cycle)
        if not self.capabilities.attackApproach then return false,'attack_approach_unavailable' end
        local function valid()
            return not c:blocked() and not c:recalling() and not c:dash() and U.valid(target)
                and U.same(c.attackTarget,target) and c.mode==owner and c.config:get('autoJungle')
                and not c.input.farmPaused and c.sdk.Orbwalker:CanMove() and not c.sdk.Orbwalker:IsAutoAttacking()
        end
        if not valid() then return false,'attack_approach_invalid' end
        local prior=self.approachRequest;local action=prior and self:inputAction(prior.id)
        local distance=U.dist(myHero.pos,target.pos)
        if prior and U.same(prior.target,target) and distance<(prior.distance or distance)-15 then
            prior.distance=distance;prior.progressAt=c:now()
        end
        local stalled=prior and action and action.sentAt and c:now()-(prior.progressAt or c:now())>=.6
            and (c.sdk.Attack.ServerStart or 0)<=(prior.attackStart or 0)
        local rejected=action and action.state=='cancelled_before_send' and not action.sentAt and action.aim and action.aim.exhausted
        if prior and U.same(prior.target,target) and (rejected or stalled) then
            if stalled then require('lho.aim').reject(self,action,target) end
            if not prior.recoveryYielded then
                -- Let independent spells use the released cursor this callback.
                -- Recovery is not another immediate high-frequency aim retry.
                prior.recoveryYielded=true;return false,'attack_approach_recovery_yield'
            end
            -- A nil/wrong host hover must not strand Lee just outside AA range.
            -- Move on verified ground into range; never turn ambiguous aim into
            -- an attack on an arbitrary overlapping monster.
            local goal=U.toward(target.pos,myHero.pos,math.max(70,c:attackRange(target)-35))
            local ground=require('lho.ground');local point=ground.select(c,goal)
            if not point or U.dist(point,target.pos)>=distance-15 then
                -- Search empty ground inside attack range, including when the
                -- camp has already been dragged outside its preferred leash ring.
                local scene=ground.scene(c);local radius=math.max(70,c:attackRange(target)-35)
                local dx,dz=(myHero.pos.x-target.pos.x)/math.max(1,distance),(myHero.pos.z-target.pos.z)/math.max(1,distance)
                for _,angle in ipairs({.55,-.55,1.1,-1.1,1.57,-1.57}) do
                    local p={x=target.pos.x+(dx*math.cos(angle)-dz*math.sin(angle))*radius,y=target.pos.y,
                        z=target.pos.z+(dx*math.sin(angle)+dz*math.cos(angle))*radius}
                    if U.vector(p):To2D().onScreen and not ground.blocker(c,p,scene)
                        and c.terrain:walkLine(myHero.pos,p,myHero.boundingRadius or 35) then point=p;break end
                end
            end
            if point and U.dist(point,target.pos)<U.dist(myHero.pos,target.pos)-15
                and U.dist(myHero.pos,point)>25 and c.terrain:walkLine(myHero.pos,point,myHero.boundingRadius or 35) then
                if not prior.recoveryAt or c:now()-prior.recoveryAt>.35 then
                    local moved=self:move(point,owner)
                    if moved then
                        prior.recoveryAt=c:now()
                        if c.config.capture then c:log('attack_approach_recovery',{target=U.id(target),reason=action.reason,pos=point}) end
                        return true,'recovering attack approach on clear ground'
                    end
                else return true,'waiting for approach recovery' end
            end
        end
        self:cancelMoveIntent(owner)
        if prior and prior.cycle==cycle and U.same(prior.target,target) and action
            and action.state~='cancelled_before_send' then
            if not action.sentAt then return true,'attack approach waiting' end
            local distance=U.dist(myHero.pos,target.pos)
            if distance<(prior.distance or distance)-15 then
                prior.distance=distance;prior.progressAt=c:now()
            end
            -- A delivered click is not proof that the game accepted the order.
            -- Keep a progressing approach; reassert only after a bounded stall.
            if c:now()-(prior.progressAt or c:now())<.6 then return true,'attack approach already issued' end
        end
        if prior and action and not action.sentAt then self.scope:Cancel(prior.id,'Attack approach changed') end
        local ok,why,timing=self:request{type='attack',approach=true,targetKind='object',target=target,
            verifyTarget=target,owner=owner,priority='normal',expires=api:Now()+150,validate=valid,
            retryKey='attack-approach:'..tostring(U.id(target)),
            aimCandidates=function()return require('lho.aim').points(self,target,true)end,
            aimFallback=function(point)return require('lho.aim').isolated(c,target,point)end}
        if timing then
            self.approachRequest={id=timing.cursorID,target=target,cycle=cycle,
                distance=U.dist(myHero.pos,target.pos),progressAt=c:now(),attackStart=c.sdk.Attack.ServerStart}
            if c.config.capture then c:log('kite_attack_approach',{cursorID=timing.cursorID,target=U.id(target),
                separation=U.dist(myHero.pos,target.pos),attackRange=c:attackRange(target),
                attackStart=c.sdk.Attack.ServerStart,cycle=c.sdk.Attack:GetAnimation(),
                cooldownLeft=math.max(0,c.sdk.Attack.ServerStart+c.sdk.Attack:GetAnimation()-c:now())}) end
        end
        return ok,why
    end
    function a:recall()
        return self:keyAction(HK_RECALL or 66,'farm','key',function()
            return c.config:get('autoJungle') and not c.input.farmPaused and not c:recalling()
                and c.farm:recallSafe(true)
        end)
    end
    function a:recallStatus(id,finished)
        local r=self:inputAction(id)
        if finished and r and not r.sentAt then
            self.scope:Cancel(id,'Recall recovery finished');r=self:inputAction(id)
        end
        if r and (r.sentAt or r.state=='cancelled_before_send') then
            for signature,request in pairs(self.keyRequests) do
                if request==id then self.keyRequests[signature]=nil end
            end
        end
        return r
    end
    function a:cancel(owner)
        self.ownerGeneration[owner]=(self.ownerGeneration[owner] or 0)+1
        self.dependencies[owner]=nil
        self.scope:CancelOwner(owner,'LHO owner cancelled')
        for signature in pairs(self.keyRequests) do if signature:sub(1,#owner+1)==owner..':' then self.keyRequests[signature]=nil end end
        for slot,e in pairs(self.pending) do if e.owner==owner then
            local r=self:inputAction(e.cursorID)
            e.gameplayCancelled=true;e.cancelledAt=e.cancelledAt or c:now()
            self:quarantine(slot,e,r)
            -- Owner cancellation ends future intent, not an issued cast's
            -- observation window. Keep that slot until its original bounded
            -- observation completes; a new mode must not resend an in-flight
            -- Q just because delayed spell metadata still reports it ready.
            -- Uncertain sends retain their separate reconciliation contract.
            if not r or not r.sentAt or r.state=='send_uncertain' then
                self.pending[slot]=nil
                if r and not r.sentAt then e.status='cancelled' end
            end
        end end
    end
    function a:releaseMinimap() self.minimapLease=nil end
    function a:sampleCursor() end
    function a:ownsCursorPoint(owner,point)
        local id=self.owners[owner];local s=self.api:GetAvailability()
        return id and s.activeID==id and self:inputAction(id)~=nil
    end
    function a:ownsHoverAim(target,owner)
        local aim=self.hoverAim
        return aim and aim.owner==owner and U.same(aim.target,target)
            and self.api:GetAvailability().activeID==aim.id
    end
    function a:prepareHover(target,owner)
        if type(Game.GetUnderMouseObject)~='function' then return false,'Target verification unavailable' end
        if self:cursorBusy() and not self:ownsHoverAim(target,owner) then return false,'Waiting for input' end
        local point=U.vector(target.pos):To2D();if not point.onScreen then return false,'Target offscreen' end
        local ok,hovered=pcall(Game.GetUnderMouseObject)
        if ok and U.same(hovered,target) then local p=Game.cursorPos();return true,{x=p.x,y=p.y} end
        local aim=self.hoverAim
        if aim and self:ownsHoverAim(target,owner) then return false,'Waiting for hover' end
        local accepted,_,timing=self:dispatchCursor(nil,{x=point.x,y=point.y},owner,false,nil,nil,function()return U.valid(target)end)
        if accepted then self.hoverAim={owner=owner,target=target,point=point,at=c:now(),id=timing.cursorID} end
        return false,'Waiting for hover'
    end
    function a:canChainWard(slot,target,owner,anticipation)
        if self.originalGG then return false end
        return c.config:get('wardFastCursor') and self:wardDependency(slot,target,owner,anticipation)
            and self.owners[owner]~=nil
    end
    function a:canChainInsecKick(slot,target,owner)
        if self.originalGG then return false end
        if slot~=3 or c:dash() or not c:enemyValid(target) or U.dist(myHero.pos,target.pos)>c.profile.rRange
            or c.combat:kickProtected(target) then return false end
        if owner=='insec' and (not c.combat.insec or not c.combat:kickValid(c.combat.insec)) then return false end
        local last=self.history[#self.history]
        local action=last and self:inputAction(last.cursorID)
        return last and not last.gameplayCancelled and last.owner==owner and last.status=='observed'
            and action and not action.jobCancelled
    end
end

end
modules["lho.config"] = function(require)
local U=require('lho.util')
local C={}
local drawingModes={{'Combo','Combo','COMBO','fight'},{'Harass','Harass','HARASS','harass'},
    {'LaneClear','Lane clear','LANECLEAR','clear'},{'JungleClear','Jungle clear','JUNGLECLEAR','clear'},
    {'LastHit','Last hit','LASTHIT','gg_last'},{'Flee','Flee','FLEE','flee'},
    {'AutoJungle','Auto-jungle',nil,'farm'},{'Insec','Insec',nil,'insec'}}
local drawingGroups={drawQRange='Q',drawWRange='W',drawERange='E',drawRRange='R',
    drawWardRange='WardRange',drawHUD='Status',drawWard='Wardjump',drawInsec='Insec',damageBars='Damage'}
C.defaults={
    guideOpen=false,guideKey=119,guidePreviousKey=118,guideNextKey=120,guidePage=1,guideScale=100,
    enabled=true,cursorKey=5,allyKey=6,wardKey=84,autoJungleKey=74,qAssistKey=71,smiteKey=78,secureKey=0,autoJungle=false,
    lastAbilities=true,lastQ=true,lastW=false,lastE=true,waveAbilities=true,waveQ=true,waveW=true,waveE=true,waveHarass=false,
    jungleAbilities=true,jungleQ=true,jungleQ2=true,jungleW=true,jungleE=true,jungleQ2MeleeOnly=true,jungleQ2RangeScale=2,
    autoClearAbilities=true,autoClearQ=true,autoClearQ2=true,autoClearW=true,autoClearE=true,
    clearKrugE=true,farmPreserveQ=true,
    waveSoften=true,waveHorizon=3,farmCameraKey=90,farmQTravel=true,farmQAdjust=false,farmQBlind=true,clearQTiming=true,
    laneEstimates=true,laneDamageMargin=10,csGoldPriority=true,
    farmFollowCamera=true,openingRoute=3,farmKite=true,farmKiteDistance=260,farmKiteLeash=350,farmPreferHome=true,farmHomeOnly=true,farmLocalEnemyStart=true,
    farmMinimap=true,farmRestoreCamera=true,farmSurvivalLevel=5,
    potions=true,potionJungle=true,potionAuto=true,potionFight=true,potionHP=85,
    itemCleave=true,itemTargeted=true,itemSlow=true,itemSpeed=true,itemCleanse=true,itemShield=true,
    expiryW=true,expiryE=true,recastReserve=50,
    autosmite=true,smiteCamps=true,smiteProjectionFallback=true,smitePreaim=true,smiteMargin=10,smiteEpicMargin=0,smiteOverride=0,
    wardAssist=true,assistRadius=120,reuseRadius=55,wardRange=600,wardTimeout=900,cancelOnly=false,
    wardApproach=true,wardWalkRange=0,wardJumpTimeout=2000,wardFastCursor=true,wardFollowCursor=true,
    wardEarlyW=true,wardEarlyDelay=20,insecLandingMargin=180,insecCloseWard=true,
    aimLock=2,insecFlash=true,insecPreviewKey=18,insecTimeout=5,comboQ=true,comboQ2=false,comboW=true,comboW2=true,comboE=true,comboE2=true,comboR=true,
    harassQ=true,harassQ2=false,harassW=false,harassW2=false,harassE=true,harassE2=true,harassR=false,
    qOnlySelected=false,comboConserveR=true,comboWardRetry=2500,
    insecQ=true,insecBridges=true,insecW=true,insecChains=true,insecWalk=120,insecLead=120,insecOrbwalk=true,insecFlashFallback=true,
    insecAngle=35,insecStandDistance=325,insecAutoLead=true,insecDashEstimate=250,
    insecMouseTarget=true,insecMouseRadius=200,insecTrackAlly=true,drawInsecTolerance=false,
    insecPreferStructures=true,insecBasePlatform=true,
    multi=true,multiHits=3,collateralKills=true,autoMultiR=true,combatEstimates=true,combatDamageMargin=25,comboWard=true,items=true,hitchance=1,q2Safety=true,
    comboPassive=true,comboBurst=true,comboKickFollow=true,comboKickHP=65,comboIsolate=true,comboWardPreserveQ=false,
    comboSmartChase=true,comboWalkWait=1000,comboWardGain=550,comboChaseE2=true,
    idleDefense=true,reserveW=true,shieldHP=35,allyShieldHP=25,killQ=true,killE=true,killQ2=false,killR=true,
    clearEnergy=15,recallHP=25,level=true,invade=false,epicAssist=false,farmBuffRespawn=300,farmSmallRespawn=135,farmWightRespawn=50,
    draw=true,diagnostics=false,fileLogging=false,playtestLogging=false,combatLogging=false,performanceLogging=false,terrainVerified=false,mechanicsVerified=false,rangeVerified=false,
    smiteVerified=false,monsterQCap=0,farmQRespawn=true,
    defensiveR=true,
    comboIgnite=false,igniteExecute=true,
    damageBars=true,damageSafe=true,damageMax=true,damageText=true,damageSelected=false,
    damageQ=true,damageE=true,damageR=true,damageItems=true,damageSummoners=true,damageAutos=2,
    damageWidth=100,damageX=25,damageY=-13,damageHeight=4,damageHorizon=3,drawHUD=true,drawWard=true,drawInsec=true,
    drawQRange=2,drawWRange=false,drawERange=false,drawRRange=false,drawWardRange=false}
local sections={
    {'Keys','Extra controls (standard modes use Orbama)',{{'cursorKey','Cursor insec (Mouse4)',5},{'allyKey','Ally insec (Mouse5)',6},
        {'insecPreviewKey','Hold preview modifier; release to confirm (Alt)',18},
        {'wardKey','Ward preview / release',84},{'autoJungleKey','Auto-jungle toggle',74},{'qAssistKey','Q1-only assist',71},
        {'smiteKey','Autosmite toggle',78},{'secureKey','Optional objective secure (unbound)',0}}},
    {'Ward','Wardjump',{{'wardAssist','Wall assistance'},{'assistRadius','Assistance radius',nil,30,240},
        {'wardApproach','Walk into range after releasing T'},{'wardWalkRange','Approach travel limit (0 = unlimited)',nil,0,20000},
        {'wardFastCursor','Chain confirmed ward to W through owned GG cursor'},
        {'wardFollowCursor','After T wardjump: move once toward latest cursor'},
        {'wardEarlyW','Test: one early W before ward observation (all wardjumps)'},
        {'wardEarlyDelay','Early W test delay (ms)',nil,5,100},
        {'reuseRadius','Existing target tolerance',nil,10,100},{'wardRange','Maximum placement range (native margin also applies)',nil,100,700},
        {'wardTimeout','Ward observation timeout (ms)',nil,300,1800},
        {'wardJumpTimeout','Observed ward: W retry window (ms)',nil,500,4000},{'cancelOnly','Cancel without movement (requires input adapter)'}}},
    {'Combat','Combo',{{'comboQ','Use Q1'},{'comboQ2','Use Q2 automatically (default: manual)'},
        {'comboW','Use W1'},{'comboW2','Use W2'},{'comboE','Use E1'},{'comboE2','Use E2'},{'comboR','Use R'},
        {'comboConserveR','Save R when another timely finish is available'},
        {'qOnlySelected','Champion Q1: only the selected enemy'},
        {'comboWard','Chase wardjump only for a clear advantage'},{'comboWardRetry','Minimum time between Combo ward requests (ms)',nil,1000,5000},
        {'multi','Kick champions into other champions'},{'multiHits','Total R hits: 2 = target + 1, 3 = target + 2',nil,2,5},
        {'collateralKills','R: kill distant enemies with a kicked champion'},
        {'autoMultiR','Idle: automatic multi-kick / collateral execute (no reposition)'},
        {'combatEstimates','Allow conservative unverified champion damage estimates'},
        {'combatDamageMargin','Champion execute HP margin',nil,0,150},
        {'comboPassive','Combo: weave available passive attacks'},
        {'comboBurst','Combo: prioritize timely lethal actions over passive weaving'},
        {'comboKickFollow','Combo: Q-marked duel R followed by Q2'},
        {'comboIsolate','Combo: kick marked target away from its nearby team'},
        {'comboWalkWait','Chase: walk when reachable within (ms)',nil,200,2000},
        {'comboWardGain','Chase: minimum time saved by wardjump (ms)',nil,100,1500},
        {'comboChaseE2','Chase: use available marked E2 slow before ward entry'},
        {'insecFlash','Insec: allow Flash'},
        {'insecLandingMargin','Insec: minimum final ward landing distance from target',nil,80,250},
        {'insecCloseWard','Insec: allow closer aligned ward when needed (minimum 80)'},
        {'insecFlashFallback','Without Alt: Flash only if no ward is ready'},
        {'insecTimeout','Insec timeout (seconds)',nil,2,10},
        {'insecQ','Insec: Q1 / confirmed Q2 entry'},{'insecBridges','Insec: other champions / minions / camps as Q bridges'},
        {'insecMouseTarget','Insec: mouse target fallback when GG has no selection'},
        {'insecMouseRadius','Insec: mouse selection radius',nil,75,350},
        {'insecTrackAlly','Ally insec: follow the chosen recipient before commitment'},
        {'insecPreferStructures','Ally insec: prioritize a kick into friendly turret range'},
        {'insecBasePlatform','Ally insec: include known base platform'},
        {'drawInsecTolerance','Insec drawing: show angle tolerance rays'},
        {'insecW','Insec: existing W targets / ward placement'},{'insecChains','Insec: combine Q, W and Flash'},
        {'insecWalk','Insec: maximum final walking correction',nil,0,180},
        {'insecOrbwalk','Insec: orbwalk to cursor before engage'},
        {'insecAngle','Insec: satisfactory angle (+/- degrees)',nil,5,60},
        {'insecStandDistance','Insec: preferred distance behind target',nil,150,350},
        {'insecAutoLead','Insec: predict ward handoff and dash duration'},
        {'insecDashEstimate','Insec: initial dash duration estimate (ms)',nil,100,500},
        {'insecLead','Insec: moving target placement prediction (ms)',nil,0,300},
        {'q2Safety','Avoid turret Q2 in ordinary combo'},{'items','Item actives'},{'hitchance','Q hitchance',nil,1,3},
        {'comboIgnite','Use equipped Ignite in fight'},{'igniteExecute','Ignite only when lethal'}}},
    {'Harass','Harass (Orbama bind)',{{'harassQ','Use Q1'},{'harassQ2','Use Q2 (dash)'},{'harassW','Use W1'},
        {'harassW2','Use W2'},{'harassE','Use E1'},{'harassE2','Use E2'},{'harassR','Use R'}}},
    {'Idle','Background assists',{{'idleDefense','Automatic defensive W'},
        {'reserveW','Reserve combat W for mobility / lethal shield (jungle W allowed)'},
        {'expiryW','Use W2 shortly before recast expires (also manual W1)'},{'expiryE','Use E2 before expiry with a marked target'},
        {'recastReserve','Energy to reserve after expiry assist',nil,0,100},{'shieldHP','Self shield HP %',nil,10,80},
        {'allyShieldHP','Ally shield HP %',nil,10,60},{'killQ','Q1 killsteal'},{'killE','E killsteal'},
        {'killQ2','Q2 killsteal (dash)'},{'killR','R killsteal'}}},
    {'Activator','Items / potions',{{'potions','Health potions / refillable sustain'},
        {'potionJungle','Potions in GG jungle clear'},{'potionAuto','Potions in auto-jungle'},{'potionFight','Potions in champion combat'},
        {'potionHP','Potion use below HP % (also checks missing health)',nil,30,95},
        {'itemCleave','Tiamat / Hydra / Stridebreaker actives'},{'itemTargeted','Champion-targeted damage actives'},
        {'itemSlow','Randuin slow'},{'itemSpeed','Movement / attack-speed actives'},
        {'itemCleanse','QSS / Mercurial cleanse'},{'itemShield','Locket shield'}}},
    {'Smite','Smite',{{'autosmite','Autosmite ON / OFF'},{'smiteCamps','Execute ordinary camps in every mode'},
        {'smiteProjectionFallback','Allow isolated target aim when host hover is empty'},
        {'smitePreaim','Prepare exact boss hover shortly before lethal HP'},
        {'smiteMargin','Ordinary camp health margin',nil,0,100},{'smiteEpicMargin','Epic objective health margin',nil,0,100},
        {'smiteOverride','Exact damage override (0 = live / profile)',nil,0,2000}}},
    {'Farm','Farming / recovery',{{'autoJungle','Auto-jungle ON / OFF'},{'clearEnergy','Minimum energy %',nil,0,80},{'recallHP','Recall HP %',nil,10,60},
        {'farmFollowCamera','Auto-jungle: follow Lee with camera'},{'farmCameraKey','Native camera lock key (Z)'},
        {'farmRestoreCamera','Restore camera if this plugin locked it'},{'farmMinimap','Use minimap for offscreen auto-jungle travel'},
        {'farmQAdjust','Allow small Q aim detours (default OFF)'},
        {'farmSurvivalLevel','Prioritize damage mitigation through level',nil,1,10},
        {'farmLocalEnemyStart','Finish nearby enemy camp when starting'}, {'farmHomeOnly','Route only camps on our side (excludes river)'},{'farmPreferHome','Prefer available camps on our side'},{'invade','Route into enemy jungle from outside'},
        {'defensiveR','Use R to disengage, then pause'},
        {'farmBuffRespawn','Buff respawn estimate (seconds)',nil,30,600},
        {'farmSmallRespawn','Small-camp respawn estimate (seconds)',nil,20,300},
        {'farmWightRespawn','Wight respawn estimate (seconds)',nil,20,300},
        {'level','Auto level skills'}}},
    {'Wave','GG waveclear abilities',{
        {'csGoldPriority','Both lane modes: prioritize gold when CS must be lost'},
        {'waveAbilities','Abilities ON / OFF'},{'waveQ','Use Q1 for otherwise-missed last hits'},{'waveW','Use W (passive / sustain)'},
        {'waveE','Use E1 (rescue / safe wave damage)'},{'waveHarass','Harass during waveclear (last hits first)'},
        {'waveSoften','Use E on healthy minions with a safe CS forecast'},{'waveHorizon','CS forecast horizon (seconds)',nil,2,5},
        {'laneEstimates','Lane Q/E: allow profile estimates before verification'},
        {'laneDamageMargin','Lane spell damage safety margin %',nil,0,40}}},
    {'LastHit','GG last-hit abilities',{{'lastAbilities','Abilities ON / OFF'},{'lastQ','Use Q1 only to rescue CS'},
        {'lastW','Use W passive only to rescue CS'},{'lastE','Use E1 only to rescue CS'}}},
    {'Jungle','GG jungle clear abilities',{{'jungleAbilities','Abilities ON / OFF'},{'jungleQ','Use Q1'},
        {'clearQTiming','Estimate AA / Q2 finish time (both jungle modes)'},
        {'jungleQ2','Use Q2 recast'},{'jungleQ2MeleeOnly','Limit clearing Q2 range (travel separate)'},
        {'jungleQ2RangeScale','Clearing Q2 range: attack range multiplier',nil,1,4},
        {'jungleW','Use W1 / W2'},{'jungleE','Use E1 / E2'},
        {'clearKrugE','Normal: reserve E for imminent Krug splits (both modes)'}}},
    {'AutoClear','Auto-jungle abilities',{{'autoClearAbilities','Abilities ON / OFF'},{'farmQTravel','Use confirmed Q1 / Q2 to reach camps'},
        {'farmKite','Kite melee camp targets between attacks'},{'farmKiteDistance','Maximum kite travel (return time reserved)',nil,30,400},
        {'farmKiteLeash','Conservative monster pursuit radius',nil,150,450},
        {'farmQBlind','Probe unseen known camps with Q; skip unconfirmed camp'},{'autoClearQ','Use Q1'},
        {'farmQRespawn','Allow one fog probe after the estimated respawn time'},
        {'autoClearQ2','Use Q2 recast'},{'autoClearW','Use W1 / W2'},{'autoClearE','Use E1 / E2'},
        {'farmPreserveQ','Preserve Q1 near camp end for a useful next engage'}}},
    {'Drawings','Drawings',{{'drawWard','Wardjump preview'},{'drawInsec','Insec preview'},
        {'drawQRange','Q range'},{'drawWRange','W range'},{'drawERange','E range'},{'drawRRange','R range'},
        {'drawWardRange','Ward placement range'},
        {'damageBars','Enemy health-bar damage'},{'damageSafe','Conservative estimate'},{'damageMax','Maximum-resource estimate'},
        {'damageText','Damage numbers / incomplete status'},{'damageSelected','Selected target only'},
        {'damageQ','Include Q'},{'damageE','Include E'},{'damageR','Include R in maximum'},
        {'damageItems','Include modeled item actives'},{'damageSummoners','Include damaging summoners'},
        {'damageAutos','Maximum planned attacks',nil,0,5},{'damageHorizon','Estimate window (seconds)',nil,1,5},
        {'damageWidth','Health-bar width',nil,50,200},{'damageX','Health-bar X offset',nil,-200,200},
        {'damageY','Health-bar Y offset',nil,-200,200},{'damageHeight','Damage strip height',nil,1,10}}},
    {'Validation','Calibration / verification',{{'terrainVerified','Terrain provider verified for this mode'},
        {'mechanicsVerified','Champion damage / buffs verified'}, {'rangeVerified','Ward range verified'},
        {'monsterQCap','Measured conservative Q monster cap (0 = no Q damage budget)',nil,0,3000},
        {'smiteVerified','Smite profile measured (diagnostic status)'},{'diagnostics','Record diagnostic events'},
        {'fileLogging','Persist errors / ward / input diagnostics'},{'combatLogging','Full-match combat / sightings / outcome recording'},
        {'performanceLogging','Measure LHO component times (5-second summaries)'},
        {'playtestLogging','Temporary detailed jungle capture (20 minutes)'}}},
}
function C.new(profile)
    local self={values={},nodes={}}
    local revisedDefaults={comboIgnite='comboIgniteOptInR23',killQ2='killQ2OptInR52',killR='killRR23',comboWardPreserveQ='comboWardPreserveQOptInR25'}
    for k,v in pairs(C.defaults) do self.values[k]=v end
    if profile.id=='classic' then self.values.farmSmallRespawn=75 end
    -- Boolean false must not fall through to the initial default.
    function self:get(k)
        if k=='diagnostics' or k=='fileLogging' or k=='playtestLogging' or k=='combatLogging' or k=='performanceLogging' or k=='drawHUD' then return false end
        local node=self.nodes[k];if not node then return self.values[k] end
        local scope=U.buffScopeKey()
        if not scope then return node:Value() end
        if self.readScope~=scope then self.readScope=scope;self.readCache={} end
        local cached=self.readCache[k]
        if cached~=nil then return cached end
        local value=node:Value();self.readCache[k]=value;return value
    end
    function self:set(k,v)
        self.writeSerial=self.writeSerial or {};self.writeSerial[k]=(self.writeSerial[k] or 0)+1
        self.values[k]=v;if self.nodes[k] then self.nodes[k]:Value(v) end
        if self.readCache then self.readCache[k]=nil end
        self.capture=self:get('fileLogging') or self:get('diagnostics')
    end
    function self:key(k)
        -- New menu IDs avoid inheriting the old duplicated V/C bindings.
        if k=='farmKey' then k='autoJungleKey' elseif k=='qKey' then k='qAssistKey' end
        local n=self.nodes[k];return n and n:Key() or self.values[k]
    end
    function self:visible(key,sdk,mode)
        local enabled=self:get(key)
        if key=='drawQRange' then enabled=enabled~=1 end
        if not enabled then return false end
        local options=self.drawingOptions and self.drawingOptions[key]
        if not options then
            if key~='drawQRange' or self:get(key)==3 then return true end
            local active=sdk and sdk.Orbwalker and sdk.Orbwalker.Modes
            local index=sdk and sdk.ORBWALKER_MODE_HARASS
            if active and index then return active[index]==true end
            return mode=='harass'
        end
        if options.Always:Value() then return true end
        local active=sdk and sdk.Orbwalker and sdk.Orbwalker.Modes
        for _,entry in ipairs(drawingModes) do
            if options[entry[1]]:Value() then
                local index=entry[3] and sdk and sdk['ORBWALKER_MODE_'..entry[3]]
                local held
                if active and index then held=active[index]==true
                else held=mode==entry[4] end
                if entry[1]=='Insec' then held=mode=='cursor' or mode=='ally' end
                if held then return true end
            end
        end
        return false
    end
    -- Original-GG does not load Orbama's optional local recording profile.
    -- Read it independently without loading/replacing the provider or publishing
    -- globals. An explicitly supplied profile (including enabled=false) wins.
    local test={}
    if test.enabled then
        self.values.fileLogging=true;self.values.playtestLogging=true;self.values.combatLogging=true
        self.values.performanceLogging=test.profile==true
        for k,v in pairs(test.lho or {}) do if self.values[k]~=nil and type(v)==type(self.values[k]) then self.values[k]=v end end
    end
    self.capture=self.values.fileLogging or self.values.diagnostics
    self.menuEntries={}
    local smiteEquipped=false
    if myHero and myHero.GetSpellData then for slot=4,5 do
        local spell=myHero:GetSpellData(slot)
        if spell and (spell.name or ''):lower():find('smite',1,true) then smiteEquipped=true end
    end end
    local developer={wardEarlyW=true,wardEarlyDelay=true,wardFastCursor=true,wardRange=true,wardTimeout=true,
        wardJumpTimeout=true,insecDashEstimate=true,insecLead=true,smiteOverride=true,
        cancelOnly=true,smiteProjectionFallback=true,smitePreaim=true,
        insecAutoLead=true,insecLead=true,insecDashEstimate=true,farmRestoreCamera=true,
        farmBuffRespawn=true,farmSmallRespawn=true,farmWightRespawn=true,
        combatEstimates=true,laneEstimates=true,clearQTiming=true}
    local function destination(section,key)
        if section=='Validation' or developer[key] then return nil end
        if key:match('^insec') and key~='insecPreviewKey' then return 'Insec' end
        if key=='drawInsecTolerance' then return 'Drawings' end
        if section=='Keys' then return 'Controls' end
        if section=='Combat' then return 'Combat' end
        if section=='Idle' then return 'Assists' end
        if section=='Harass' then return 'Harass' end
        if section=='Wave' or section=='LastHit' or section=='Jungle' then return section end
        if section=='Ward' then return 'Wardjump' end
        if section=='Activator' or section=='Smite' then return 'SmiteItems' end
        if section=='Drawings' then return 'Drawings' end
        return 'Farming'
    end
    if MenuElement then
        local iconFor=require('lho.menuicons').new()
        self.menu=MenuElement({type=MENU,id='LeeHarveyOsward_'..profile.id,name='Lee Harvey Osward'})
        self.menu:MenuElement({id='enabled',name='Enabled',value=true,leftIcon=iconFor('enabled')});self.nodes.enabled=self.menu.enabled
        local groups={{'Guide','Guide'},{'Controls','Controls'},{'Combat','Combo'},{'Harass','Harass'},
            {'Assists','Background assists'},{'Insec','Insec'},{'Wave','Waveclear'},
            {'LastHit','Last hit'},{'Jungle','Jungle clear'},{'Wardjump','Wardjump'},
            {'Farming','Auto-jungle'},{'SmiteItems','Smite and items'},{'Drawings','Drawings'}}
        for _,group in ipairs(groups) do
            local icon=iconFor(group[1])
            local args={id=group[1],name=group[2],type=MENU,leftIcon=icon}
            local ok=pcall(self.menu.MenuElement,self.menu,args)
            if not ok and not self.menu[group[1]] then args.leftIcon=nil;self.menu:MenuElement(args) end
        end
        local migration=_G.SDK and SDK.MenuMigration
        if not migration then
            local ok,module=pcall(require,'Orbama.menus')
            if ok then migration=module end
        end
        self.drawingOptions={}
        local function drawingBranch(key)
            if drawingGroups[key] then return drawingGroups[key] end
            if key:match('^damage') then return 'Damage' end
            if key=='drawInsecTolerance' then return 'Insec' end
        end
        local function add(group,args,oldPath,advanced,semanticKey)
            local key=semanticKey or args.id
            args.leftIcon=iconFor(key)
            local parent=self.menu[group];local path=group
            local branch=group=='Drawings' and drawingBranch(args.id)
            if branch then
                local names={Damage='Damage estimates',Status='Status panel',WardRange='Ward range',Wardjump='Wardjump preview',Insec='Insec preview'}
                if not parent[branch] then
                    local icon=iconFor(branch)
                    parent:MenuElement({id=branch,name=names[branch] or branch..' range',type=MENU,leftIcon=icon})
                end
                parent=parent[branch];path=path..'.'..branch
            end
            local priorPath=path
            local category
            if group=='Combat' then
                if key:match('^combo[QWER]%d?$') or key=='q2Safety' or key=='hitchance' or key=='qOnlySelected' then category='Abilities'
                elseif key:match('^comboWard') or key=='comboWalkWait' or key=='comboChaseE2' then category='Chase'
                elseif key=='multi' or key=='multiHits' or key=='collateralKills' or key=='autoMultiR'
                    or key=='comboConserveR' or key=='comboKickFollow' or key=='comboIsolate' then category='Finishes' end
            elseif group=='Insec' then
                if key:match('^insecFlash') then category='Flash'
                elseif key=='insecQ' or key=='insecW' or key=='insecBridges' or key=='insecChains' or key=='insecCloseWard' then category='Resources'
                elseif key=='aimLock' or key:match('^insecMouse') or key=='insecTrackAlly' or key=='insecPreferStructures' or key=='insecBasePlatform' then category='Targeting' end
            elseif group=='SmiteItems' then
                category=key:match('^potion') and 'Potions' or (key:match('^smite') or key=='autosmite') and 'Smite' or 'Items'
            end
            if category then
                local names={Abilities='Abilities',Chase='Chase / ward use',Finishes='Kick / finishing',Resources='Approach tools',Targeting='Target / kick direction'}
                if not parent[category] then parent:MenuElement({id=category,name=names[category] or category,type=MENU,leftIcon=iconFor(category)}) end
                parent=parent[category];path=path..'.'..category
            end
            if advanced then
                if not parent.Advanced then parent:MenuElement({id='Advanced',name='Advanced',type=MENU}) end
                parent=parent.Advanced;path=path..'.Advanced'
            end
            if migration then
                migration:Apply(args,'LeeHarveyOsward_'..profile.id,oldPath,path..'.'..args.id)
                if category then migration:Apply(args,'LeeHarveyOsward_'..profile.id,priorPath..(advanced and '.Advanced' or '')..'.'..args.id,path..'.'..args.id) end
                if args.id:match('^draw[QWER]Range') or args.id=='drawWardRange' then
                    migration:Apply(args,'LeeHarveyOsward_'..profile.id,'Drawings.Ranges.'..args.id,path..'.'..args.id)
                end
                if advanced then migration:Apply(args,'LeeHarveyOsward_'..profile.id,group..'.Advanced.'..args.id,path..'.'..args.id) end
                local previous=group=='Assists' and 'Combat.Advanced'
                    or (group=='Wave' or group=='LastHit' or group=='Jungle') and ('Farming'..(advanced and '.Advanced' or ''))
                if previous then migration:Apply(args,'LeeHarveyOsward_'..profile.id,previous..'.'..args.id,path..'.'..args.id) end
            end
            if drawingGroups[args.id] then
                local key=args.id;local legacy=args.value
                args.name='Enabled';args.drop=nil
                if key=='drawQRange' then args.value=legacy~=1 end
                if migration then migration:Apply(args,'LeeHarveyOsward_'..profile.id,path..'.'..key,path..'.'..key) end
                parent:MenuElement(args);local enabled=parent[args.id]
                local options={};self.drawingOptions[key]=options
                local function visibility(id,label,value)
                    local option={id=id,name=label,value=value}
                    if migration then migration:Apply(option,'LeeHarveyOsward_'..profile.id,path..'.'..id,path..'.'..id) end
                    parent:MenuElement(option);options[id]=parent[id]
                end
                visibility('Always','Always',key~='drawQRange' or legacy==3)
                for _,entry in ipairs(drawingModes) do visibility(entry[1],entry[2],key=='drawQRange' and legacy==2 and entry[1]=='Harass') end
                if key=='drawQRange' then
                    return {Value=function(_,value)
                        if value~=nil then
                            enabled:Value(value~=1);options.Always:Value(value==3)
                            for _,entry in ipairs(drawingModes) do options[entry[1]]:Value(value==2 and entry[1]=='Harass') end
                        end
                        return enabled:Value() and (options.Always:Value() and 3 or 2) or 1
                    end}
                end
                return enabled
            end
            parent:MenuElement(args);return parent[args.id]
        end
        local labels={cursorKey='Hold: kick toward cursor',allyKey='Hold: kick toward team / turret',insecPreviewKey='Hold for preview; release to confirm',
            wardKey='Hold: aim wardjump / release: jump',qAssistKey='Hold: Q1 assist',secureKey='Hold: Q + Smite objective assist',
            wardApproach='Walk into jump range after release',wardFollowCursor='Move toward cursor after jump',insecFlashFallback='Without preview: Flash only with no ready ward',
            farmCameraKey='Camera lock key',combatEstimates='Conservative damage estimates',
            laneEstimates='Conservative lane damage',insecMouseTarget='No selection: use enemy near cursor',
            insecPreferStructures='Prefer landing inside friendly turret range',insecBasePlatform='Also consider our base platform',
            insecTrackAlly='Track ally until direction locks',insecCloseWard='Allow a closer ward for a valid kick',
            insecBridges='Use other units as Q stepping stones',insecChains='Combine Q, W and allowed Flash',
            multiHits='Minimum total champions hit',autoMultiR='Also kick while idle, without repositioning',
            comboKickFollow='Follow a duel kick with marked Q2',comboIsolate='Kick a marked enemy away from their team',
            comboPassive='Weave passive attacks',comboBurst='Prioritize a lethal finish',
            expiryW='Use W2 before it expires',expiryE='Use E2 before expiry if a marked enemy is nearby',
            waveSoften='Damage healthy minions when last hits stay safe',laneDamageMargin='Extra lane damage margin (%)',
            farmQBlind='Q-probe known camps in fog',farmQRespawn='Allow a fog probe after estimated respawn',
            jungleQ2MeleeOnly='Save long-range Q2 for travel',jungleQ2RangeScale='Clearing Q2 range / attack range',
            damageText='Show estimated damage numbers',damageMax='Estimate with maximum allowed resources',
            damageSafe='Show conservative estimate',insecOrbwalk='Attack and move while waiting for an approach'}
        for _,section in ipairs(sections) do
            for _,row in ipairs(section[3]) do
                local key=row[1];local group=destination(section[1],key)
                if not group and section[1]~='Validation' and migration then
                    local saved={id=key,value=self.values[key]}
                    migration:Apply(saved,'LeeHarveyOsward_'..profile.id,section[1]..'.'..key,section[1]..'.Advanced.'..key)
                    local previous=key:match('^insec') and 'Insec' or section[1]=='Ward' and 'Wardjump'
                        or section[1]=='Smite' and 'SmiteItems' or section[1]=='Farm' and 'Farming'
                    if previous then migration:Apply(saved,'LeeHarveyOsward_'..profile.id,previous..'.'..key,previous..'.Advanced.'..key) end
                    self.values[key]=saved.value
                end
                local relevant=not (key=='farmWightRespawn' and profile.id~='classic'
                    or key=='clearKrugE' and profile.id~='normal')
                if (section[1]=='Smite' or key=='smiteKey') and not smiteEquipped then relevant=false end
                self.menuEntries[#self.menuEntries+1]={key=key,old=section[1],group=group,category=not group and 'development' or row[4] and 'tuning' or 'gameplay',relevant=relevant}
                if group and relevant then
                    local label=labels[key] or row[2]:gsub('GG ',''):gsub(' %(Mouse%d%)',''):gsub('Test: ','')
                    local args={id=revisedDefaults[key] or key,name=label,value=self.values[key]}
                    if key=='hitchance' then args.id='qAccuracyR54';args.name='Q prediction confidence' end
                    if key=='smiteCamps' then args.id='smiteExecuteCamps' end
                    if key=='farmKiteDistance' then args.id='farmKiteTravelR19' end
                    if section[1]=='Keys' or key=='farmCameraKey' then args.key=self.values[key];args.value=nil
                    elseif key=='hitchance' then args.drop={'Normal','High','Immobile only'}
                    elseif key=='drawQRange' then args.drop={'Off','During harass','Always'}
                    elseif row[4] then args.min=row[4];args.max=row[5];args.step=1 end
                    local advanced=group~='Controls' and row[4]~=nil
                    self.nodes[key]=add(group,args,section[1]..'.'..args.id,advanced,key)
                end
            end
        end
        self.nodes.aimLock=add('Insec',{id='aimLock',name='Lock kick direction',value=self.values.aimLock,drop={'On press','When approach commits','Keep tracking until kick'}},'Combat.aimLock')
        self.nodes.openingRoute=add('Farming',{id='openingRouteR15',name='Opening route',value=self.values.openingRoute,
            drop={'Adaptive','Red start','Blue start'}},'Farm.openingRouteR15')
        self.menu:MenuElement({id='draw',name='Drawings enabled',value=self.values.draw,leftIcon=iconFor('draw')});self.nodes.draw=self.menu.draw
        local function guide(key,label,extra)
            local args={id=key,name=label,value=self.values[key]}
            for k,v in pairs(extra or {}) do args[k]=v end
            if args.key then args.value=nil end
            local oldDefault=key=='guidePreviousKey' and 33 or key=='guideNextKey' and 34
            if oldDefault then
                -- Move saved r79 defaults to adjacent F keys, preserving custom
                -- bindings and any deliberate choice saved under the new IDs.
                args.id=key..'R80'
                if migration then
                    local root='LeeHarveyOsward_'..profile.id
                    migration:Apply(args,root,'Guide.'..key,'Guide.'..args.id)
                    local saved=migration.saved and migration.saved[root]
                    local current=saved and saved.Guide and saved.Guide[args.id]
                    if args.key==oldDefault and not (current and type(current.__key)=='number') then args.key=self.values[key] end
                end
            end
            self.nodes[key]=add('Guide',args,'Guide.'..args.id,false,key)
        end
        guide('guideOpen','Show / hide guide')
        guide('guideKey','Open / close guide',{key=self.values.guideKey})
        guide('guidePage','Topic',{drop=require('lho.guide').titles})
        guide('guidePreviousKey','Previous topic',{key=self.values.guidePreviousKey})
        guide('guideNextKey','Next topic',{key=self.values.guideNextKey})
        guide('guideScale','Text size (%)',{min=80,max=150,step=5})
        -- Aliases preserve existing plugin button insertion without duplicate menu nodes.
        self.menu.Farm=self.menu.Farming;self.menu.Ward=self.menu.Wardjump;self.menu.Keys=self.menu.Controls
        self.menu.Smite=self.menu.SmiteItems
        self.bindings=require('lho.bindings').new(self,_G.SDK)
    end
    self:set('autoJungle',false) -- Loading/reloading never starts an autonomous route.
    self:set('guideOpen',false) -- Help is temporary, never reopened by a saved toggle.
    return self
end
return C

end
modules["lho.damage"] = function(require)
local U=require('lho.util')
local D={};D.__index=D
function D.new(ctx) return setmetatable({ctx=ctx,cache={}},D) end
function D:ignite(target,ownedSlot)
    local c=self.ctx
    for slot=4,5 do
        if U.name(c:spell(slot).name)=='summonerdot' and c:ready(slot) and (not c.actions.pending[slot] or slot==ownedSlot)
            and U.dist(myHero.pos,target.pos)<=600 and not U.buff(target,{summonerdot=true},c:now()) then
            if not c.config:get('mechanicsVerified') then return slot,0,false end
            return slot,math.max(0,50+20*(myHero.levelData.lvl or 1)-(target.hpRegen or 0)*5),true
        end
    end
end
function D:castIgnite(target)
    local c=self.ctx
    if not c.config:get('comboIgnite') or not c:enemyValid(target) then return false end
    local slot,damage,verified=self:ignite(target)
    if not slot or not verified then return false end
    if c.config:get('igniteExecute') and damage<(target.health or 0)+(target.allShield or 0)+10 then return false end
    return c.actions:cast(slot,target,'fight',{urgent=true,interrupt=true,validate=function()
        local current,value,known=self:ignite(target,slot)
        return current==slot and known and c.config:get('comboIgnite') and c:enemyValid(target)
            and (not c.config:get('igniteExecute') or value>=U.typedHP(target,'true')+10),'ignite_no_longer_eligible'
    end})
end
function D:item(slot,target)
    local c=self.ctx;local item=myHero:GetItemData(slot);local id=item and item.itemID
    local rule=c.actives:rule(id)
    if not rule or not c.config:get(rule.group) or not c:ready(slot) or c.actions.pending[slot] then return nil end
    if rule.damage==false then return {damage=0,range=rule.range,type='physical',name=tostring(id)} end
    -- A mode-matched measured adapter can extend unknown item formulas. Its
    -- output is post-resistance damage, before shields; never an instruction to cast.
    local provider=_G.LHO_Damage
    if provider and provider.mode==c.profile.id and provider.item then
        local ok,value=pcall(provider.item,id,myHero,target)
        if ok and type(value)=='table' and value.verified==true and type(value.damage)=='number'
            and value.damage>=0 and value.damage<100000 and (value.type=='physical' or value.type=='magic' or value.type=='true') then
            return {damage=value.damage,type=value.type,range=rule.range,name=tostring(id)}
        end
    end
    local raw,dtype,kind
    if c.profile.id=='classic' and c.config:get('mechanicsVerified') then
        if id==773077 or id==773074 then raw=(myHero.totalDamage or 0)*.6;kind='physical'
        elseif id==773144 then raw=100;kind='magic'
        elseif id==773153 then raw=math.max(100,(target.maxHealth or 0)*.15);kind='magic' end
    end
    if raw then
        dtype=kind=='magic' and c.sdk.DAMAGE_TYPE_MAGICAL or c.sdk.DAMAGE_TYPE_PHYSICAL
        return {damage=c.sdk.Damage:CalculateDamage(myHero,target,dtype,raw),type=kind,range=rule.range,name=tostring(id)}
    end
    return {damage=0,range=rule.range,unknown=true,name=tostring(id)}
end
function D:estimate(target,maximum)
    local c=self.ctx;local cfg=c.config
    local out={damage=0,parts={},unknown={},maximum=maximum}
    if not c:enemyValid(target) then return out end
    local hp=target.health;local generic=target.allShield or 0
    local physical=target.shieldAD or 0;local magic=target.shieldAP or 0
    local energy=myHero.mana or 0;local elapsed=0;local distance=U.dist(myHero.pos,target.pos)
    local horizon=cfg:get('damageHorizon')
    local function add(name,damage,kind,time,cost)
        cost=cost or 0;time=time or 0
        if hp<=0 or cost>energy or elapsed+time>horizon then return false end
        energy=energy-cost;elapsed=elapsed+time
        hp=math.min(target.maxHealth or target.health,hp+math.max(0,target.hpRegen or 0)*time)
        damage=math.max(0,damage or 0)
        local remaining=damage
        if kind=='physical' then local use=math.min(physical,remaining);physical=physical-use;remaining=remaining-use
        elseif kind=='magic' then local use=math.min(magic,remaining);magic=magic-use;remaining=remaining-use end
        local use=math.min(generic,remaining);generic=generic-use;remaining=remaining-use
        hp=math.max(0,hp-remaining);out.parts[#out.parts+1]=name
        if hp==0 then out.lethal=true;if not out.aggregated then out.killTime=elapsed end end
        return true
    end
    local function ready(slot) return c:ready(slot) and not c.actions.pending[slot] end
    local function spellDamage(slot,stage,health)
        if maximum then return c:combatDamage(slot,target,stage,health) end
        return c:damage(slot,target,stage,health)
    end
    out.estimated=maximum and cfg:get('combatEstimates') and not cfg:get('mechanicsVerified') and not c.profile.damageVerified
    if not cfg:get('mechanicsVerified') then out.unknown[#out.unknown+1]='spell damage unverified' end
    local qMarked=c:stage(0)==2 and c:mark(target)~=nil
    local markUntil=qMarked and c:markLeft(target) or 0
    if maximum and cfg:get('damageQ') and cfg:get('comboQ') and c:stage(0)==1 and ready(0) then
        local p=c.spells:predict(target)
        if p and #c.spells:blockers(target,p)==0 then
            if add('Q1*',spellDamage(0,1),'physical',.25+distance/c.profile.qSpeed,c:spell(0).mana) then
                qMarked=true;markUntil=elapsed+3
            end
        end
    end
    local function q2()
        if maximum and cfg:get('damageQ') and cfg:get('comboQ') and qMarked and ready(0)
            and distance<=c.profile.q2Range and elapsed+.15<markUntil
            and not (cfg:get('q2Safety') and c:underTurret(target.pos)) then
            local cost=c:stage(0)==2 and c:spell(0).mana or 30
            if add('Q2*',spellDamage(0,2,math.min(target.maxHealth or target.health,hp+math.max(0,target.hpRegen or 0)*(.15+distance/1800))),'physical',.15+distance/1800,cost) then
                qMarked=false;distance=0;return true
            end
        end
    end
    -- In melee, reserve Q2 until after E/attacks/R to benefit from missing HP.
    -- At range, Q2 must be spent to reach E/R; never count both sequences.
    if distance>c.profile.rRange then q2() end
    if cfg:get('damageE') and cfg:get('comboE') and c:stage(2)==1 and ready(2) and distance<=c.profile.eRange then
        add('E1',spellDamage(2,1),'magic',.25,c:spell(2).mana)
    end
    if maximum and cfg:get('damageItems') and cfg:get('items') then
        for slot=6,11 do
            local item=self:item(slot,target)
            if item and distance<=item.range then
                if item.unknown then out.unknown[#out.unknown+1]='item '..item.name
                elseif item.damage>0 then add('Item '..item.name,item.damage,item.type,.05) end
            end
        end
    end
    if distance<=c:attackRange(target) then
        local cycle=c.sdk.Attack.GetAnimation and c.sdk.Attack:GetAnimation() or 1/math.max(.5,myHero.attackSpeed or 1)
        for i=1,maximum and cfg:get('damageAutos') or math.min(1,cfg:get('damageAutos')) do
            -- Plain attacks avoid repeatedly counting a one-use item proc.
            local damage=c.sdk.Damage:GetAutoAttackDamage(myHero,target,maximum and i==1)
            add('AA',damage,'physical',i==1 and c:windup() or cycle)
        end
    end
    if maximum and cfg:get('damageR') and cfg:get('comboR') and ready(3) and distance<=c.profile.rRange then
        if add('R',spellDamage(3,1),'physical',.5,c:spell(3).mana) then distance=distance+c.profile.kickDistance end
    end
    q2()
    if maximum and cfg:get('damageSummoners') and cfg:get('comboIgnite') then
        -- Cast-range eligibility uses the actual starting position, not an
        -- assumed second future gap-close after kicking the target away.
        local slot,damage,verified=self:ignite(target)
        if slot then
            if not verified then out.unknown[#out.unknown+1]='Ignite unverified'
            elseif hp>0 then out.aggregated=true;out.killTime=nil;add('Ignite (window)',(50+20*(myHero.levelData.lvl or 1))*math.min(1,horizon/5),'true',math.max(0,horizon-elapsed)) end
        end
    end
    if maximum and cfg:get('damageItems') then
        local conditional={[6692]=true,[6610]=true,[3153]=true,[3748]=true,[773153]=true,[773209]=true}
        for slot=6,11 do
            local item=myHero:GetItemData(slot)
            if item and conditional[item.itemID] then out.unknown[#out.unknown+1]='conditional/repeated item procs' end
        end
    end
    if maximum and cfg:get('damageSummoners') then
        for slot=4,5 do
            local name=U.name(c:spell(slot).name)
            if ready(slot) and (name:find('smiteavatar',1,true) or name=='s5summonersmiteplayerganker'
                or name=='s5summonersmiteduel' or name:find('snowball',1,true) or name=='summonermark') then
                out.unknown[#out.unknown+1]='champion summoner damage not modeled'
            end
        end
    end
    out.damage=math.max(0,target.health-hp)
    out.remainingHP=hp;out.partial=#out.unknown>0;out.elapsed=elapsed;out.energyLeft=energy
    return out
end
function D:both(target)
    local id=U.id(target) or target;local now=self.ctx:now();local cached=self.cache[id]
    if cached and now-cached.at<.1 and cached.health==target.health then return cached.safe,cached.max end
    local safe,max=self:estimate(target,false),self:estimate(target,true)
    -- Resource-using branches can exhaust the time/energy budget; the available
    -- conservative branch is always an alternative to that sequence.
    if max.damage<safe.damage then max.damage=safe.damage;max.parts=safe.parts;max.remainingHP=safe.remainingHP;max.lethal=safe.lethal;max.killTime=safe.killTime;max.aggregated=safe.aggregated;max.elapsed=safe.elapsed end
    self.cache[id]={at=now,health=target.health,safe=safe,max=max}
    return safe,max
end
return D

end
modules["lho.display"] = function(require)
-- Local deployment calibration recorded 2026-09-08: game.cfg renders at
-- 5120x2160, Game.Resolution reports 4096x1728, and native posMM uses render
-- pixels. Apply only to out-of-bounds points with this exact API resolution.
-- Other resolutions retain native coordinates and require new evidence.
return {apiWidth=4096,apiHeight=1728,renderWidth=5120,renderHeight=2160}

end
modules["lho.emergencyshield"] = function(require)
-- Evidence-gated self shield. Unknown spell damage is deliberately not lethal.
-- Current native coverage: already airborne, targeted basic-attack missiles.
local U=require('lho.util');local P=require('lho.profiles')
local E={};E.__index=E
local function matches(value,unit)
    if type(value)=='table' or type(value)=='userdata' then return U.same(value,unit) end
    return value~=nil and value~=0 and (value==unit.handle or value==unit.networkID)
end
function E.new(c)return setmetatable({ctx=c},E)end
function E:lead()
    local c=self.ctx
    -- Dispatch/host jitter allowance, not a claim of a zero-latency shield.
    return U.clamp(.10+(c.latency or 0)+2*(c.jitter or 0),.12,.30)
end
function E:eligible()
    local c=self.ctx
    return c.config:get('reserveW') and c.config:get('idleDefense') and not c:blocked()
        and c:stage(1)==1 and c:ready(1) and not c.wards.pending and not c.combat.insec
        and not c:combatTransit() and not c.input:held('wardKey')
        and not c.input:held('cursorKey') and not c.input:held('allyKey')
        and not myHero.isImmortal and not U.buff(myHero,P.immortal,c:now())
end
function E:source(value)
    local c=self.ctx
    for _,list in ipairs({c.enemies or {},c.minions or {},c.turrets or {}}) do
        for _,unit in ipairs(list) do
            if matches(value,unit) and unit.valid~=false and unit.team~=myHero.team then return unit end
        end
    end
end
function E:packet(missile,lead)
    local c=self.ctx;local d=missile and missile.missileData
    if not d or missile.valid==false or missile.dead or not matches(d.target,myHero)
        or not U.position(missile.pos) or not U.finite(d.speed) or d.speed<=0 then return end
    local name=U.name(d.name)
    if not name:find('basicattack',1,true) and not name:find('critattack',1,true) then return end
    local source=self:source(d.owner)
    if not source or not c.sdk.Damage or not c.sdk.Damage.GetAutoAttackDamage then return end
    local remaining=math.max(0,U.dist(missile.pos,myHero.pos)-(myHero.boundingRadius or 0))/d.speed
    if remaining<=0 or remaining>lead then return end
    local ok,damage=pcall(c.sdk.Damage.GetAutoAttackDamage,c.sdk.Damage,source,myHero)
    if not ok or not U.finite(damage) or damage<=0 then return end
    return {id=U.id(missile),source=U.id(source),damage=damage,remaining=remaining}
end
function E:evidence()
    if not self:eligible() or not Game.MissileCount or not Game.Missile then return end
    local ok,count=pcall(Game.MissileCount)
    if not ok or not U.finite(count) or count<0 or count>512 then return end
    local packets,seen,total,last={},{},0,0;local lead=self:lead()
    for i=1,math.floor(count) do
        local yes,missile=pcall(Game.Missile,i)
        if yes then
            local packet=self:packet(missile,lead)
            if packet and packet.id and not seen[packet.id] then
                seen[packet.id]=true;packets[#packets+1]=packet
                total=total+packet.damage;last=math.max(last,packet.remaining)
            end
        end
    end
    -- Count all existing shield pools conservatively: SDK AA damage can mix
    -- types. Never treat a typed shield as absent merely because AA is physical.
    local effective=(myHero.health or 0)+(myHero.allShield or 0)+(myHero.shieldAD or 0)+(myHero.shieldAP or 0)
        +math.max(0,myHero.hpRegen or 0)*last
    if total<effective or total<=0 then return end
    return {packets=packets,damage=total,effectiveHP=effective,remaining=last,at=self.ctx:now(),
        evidence='Observed targeted AA missiles; SDK damage estimate; survival not guaranteed'}
end
function E:tick()
    local c=self.ctx
    if c.actions.pending[1] then return false end
    local now=c:now()
    -- Decision scanning is bounded; final send validation always samples fresh.
    if now<(self.nextScan or 0) then return false end
    self.nextScan=now+.025
    local threat=self:evidence();if not threat then return false end
    local function valid()
        local fresh=self:evidence()
        if not fresh then return false,'lethal_incoming_evidence_gone' end
        -- Revalidate the same threat, not a different replacement opportunity.
        local ids={};for _,p in ipairs(fresh.packets) do ids[p.id]=true end
        for _,p in ipairs(threat.packets) do if not ids[p.id] then return false,'incoming_missile_gone' end end
        return true
    end
    local accepted=c.spells:w(myHero,'defense',true,nil,valid)
    if accepted and c.config.capture then c:log('emergency_shield_requested',threat) end
    return accepted
end
return E

end
modules["lho.eventqueue"] = function(require)
local Q={};Q.__index=Q
local function ring()return {rows={},head=1,count=0}end
local function pop(r)
    if r.count==0 then return end
    local value=r.rows[r.head];r.rows[r.head]=nil;r.head=r.head%256+1;r.count=r.count-1;return value
end
local function push(r,value)r.rows[(r.head+r.count-1)%256+1]=value;r.count=r.count+1 end
function Q.new()return setmetatable({high=ring(),low=ring(),count=0,dropped=0,serial=0,aggregated=0},Q)end
function Q:push(event,periodic)
    local last=self.last
    if last and last.queued and (event.kind=='cast_blocked' or event.kind=='smite_hover_blocked')
        and event.kind==last.event.kind and event.owner==last.event.owner and event.slot==last.event.slot
        and event.target==last.event.target and event.reason==last.event.reason then
        last.event.repeatCount=(last.event.repeatCount or 1)+1;last.event.lastTime=event.time
        self.aggregated=self.aggregated+1;return
    end
    if self.count==256 then
        self.dropped=self.dropped+1
        if periodic and self.low.count==0 then return end
        local removed=pop(self.low.count>0 and self.low or self.high);removed.queued=false;self.count=self.count-1
    end
    self.serial=self.serial+1;local row={event=event,serial=self.serial,queued=true}
    push(periodic and self.low or self.high,row);self.count=self.count+1;self.last=row
end
function Q:pop()
    local h,l=self.high.rows[self.high.head],self.low.rows[self.low.head]
    local source=h and (not l or h.serial<l.serial) and self.high or self.low
    local row=pop(source);if not row then return end
    row.queued=false;self.count=self.count-1;return row.event
end
return Q

end
modules["lho.farm"] = function(require)
local U=require('lho.util');local P=require('lho.profiles')
local F={};F.__index=F
function F.new(ctx,actions,spells,smite)
    return setmetatable({ctx=ctx,actions=actions,spells=spells,smite=smite,known={},state='idle'},F)
end
function F:startRoute()
    self.threatRetreat=nil;self.recoveryTrigger=nil;self.pressureSample=nil
    self.recoveryWanted=nil;self.recallReconcile=nil;self.recallObserved=false;self.recallAction=nil;self.retreatCamp=nil;self.retreatMove=nil
    local c=self.ctx;local choice=c.config:get('openingRoute')
    self.camp=nil;self.progressAt=nil;self.progressCamp=nil;self.opening=nil
    self.actions.routeStop=nil;c.routeFailureReason=nil
    self.actions.lastRouteGoal=nil;self.actions.routeObservation=nil;self.actions.routeCommand=nil
    self.travelTarget=nil;self.travelJob=nil;self.probe=nil
    self:updateCamps()
    self.localException=nil;self.returningHome=nil
    local localStart,nearest,engaged=nil,650,false
    if c.config:get('farmLocalEnemyStart') then
        for _,camp in pairs(self.known) do
            if not P.epics[camp.category] and camp.team and camp.team~=0 and c:threats(camp.pos,1000)==0 then
                for _,m in ipairs(camp.members or {}) do
                    local distance=U.dist(myHero.pos,m.pos)
                    local fighting=(m.health or 0)<(m.maxHealth or m.health or 0)
                        or U.same(c.attackTarget,m)
                    if self:ordinaryTarget(m) and distance<=650 and
                        (not localStart or fighting and not engaged or fighting==engaged and distance<nearest) then
                        localStart,nearest,engaged=camp,distance,fighting
                    end
                end
            end
        end
    end
    if localStart and localStart.team~=myHero.team then self.localException=localStart.id end
    local anchor=localStart or self:choose()
    -- The opening preference applies only when leaving base before first spawn.
    -- Restarting J in the jungle always starts a new nearest-camp decision.
    local spawn=self:spawn()
    local nearbyAlive=anchor and anchor.availability=='observed_alive' and U.dist(myHero.pos,self:walkDestination(anchor))<1600
    -- A level-one player choosing a jungle half chooses its buff opening.
    -- An already engaged camp still wins; later restarts remain nearest-camp.
    local atBase=spawn and U.dist(myHero.pos,spawn)<900
    if not localStart and not atBase and c:now()<180 and (myHero.levelData.lvl or 1)==1 and choice>1 then
        local engaged=false
        for _,m in ipairs(anchor and anchor.members or {}) do
            if U.valid(m) and m.health<m.maxHealth and U.dist(myHero.pos,m.pos)<500 then engaged=true;break end
        end
        if not engaged then
            local nearest=math.huge
            for _,camp in pairs(self.known) do
                local distance=U.dist(myHero.pos,self:walkDestination(camp))
                if camp.team==myHero.team and (camp.category=='Red' or camp.category=='Blue')
                    and (self:staging(camp) or camp.availability~='observed_empty' and not camp.awaitingRespawn)
                    and c:threats(camp.pos,1000)==0 and not c:underTurret(camp.pos) and distance<nearest then
                    anchor,nearest=camp,distance
                end
            end
        end
    end
    if not nearbyAlive and spawn and U.dist(myHero.pos,spawn)<900 and c:now()<180 and (myHero.levelData.lvl or 1)==1 and choice>1 then
        local category=P.openings[c.profile.id][choice-1][1]
        for _,camp in pairs(self.known) do
            if camp.team==myHero.team and camp.category==category and self:staging(camp)
                and c:threats(camp.pos,1000)==0 then anchor=camp;break end
        end
    end
    if anchor then
        self.camp=anchor
        if choice>1 then
            local blue=anchor.category=='Blue' or anchor.category=='Wolves' or anchor.category=='Gromp' or anchor.category=='Wight'
            choice=blue and 3 or 2
        end
        if c.config.capture then c:log('route_start_anchor',{name=anchor.category}) end
    end
    self.opening=(not self.localException and choice>1 and c:now()<300 and (myHero.levelData.lvl or 1)<=5)
        and {order=P.openings[c.profile.id][choice-1],index=1} or nil
    if anchor and self.opening then
        for index,category in ipairs(self.opening.order) do
            if category==anchor.category then self.opening.index=index;break end
        end
    end
end
function F:respawnDuration(camp)
    local c=self.ctx;local provider=_G.LHO_Camps
    local override=provider and provider.mode==c.profile.id and provider.respawn and provider.respawn[camp.category]
    if type(override)=='number' and override>=10 and override<=900 then camp.timerSource='provider';return override end
    local measured=self.respawnSamples and self.respawnSamples[camp.category]
    if measured and measured.count>=2 then camp.timerSource='measured';return measured.seconds end
    camp.timerSource='profile estimate'
    if camp.category=='Red' or camp.category=='Blue' then return c.config:get('farmBuffRespawn') end
    if camp.category=='Wight' then return c.config:get('farmWightRespawn') end
    local seconds=P.respawns[c.profile.id][camp.category]
    if P.epics[camp.category] or camp.category=='River' then return seconds end
    if seconds then return c.config:get('farmSmallRespawn') end
    camp.timerSource='unknown category';return nil
end
function F:respawnObserved(camp,now,nativeTransition)
    if nativeTransition and camp.killTimePrecise and camp.awaitingRespawn and camp.killedAt and camp.nativeDownSeen
        and camp.lastNativeAt and now-camp.lastNativeAt<1 then
        local elapsed=now-camp.killedAt
        local expected=P.respawns[self.ctx.profile.id][camp.category]
        if elapsed>=10 and elapsed<=600 and (self.ctx.profile.id=='classic'
            or expected and math.abs(elapsed-expected)<=math.max(3,expected*.1)) then
            self.respawnSamples=self.respawnSamples or {}
            local old=self.respawnSamples[camp.category]
            if old and math.abs(old.seconds-elapsed)<2 then old.seconds=(old.seconds*old.count+elapsed)/(old.count+1);old.count=old.count+1
            else self.respawnSamples[camp.category]={seconds=elapsed,count=1} end
            if self.ctx.config.capture then self.ctx:log('camp_respawn_measured',{camp=camp.id,name=camp.category,seconds=elapsed}) end
        end
    end
    if self.ctx.config.capture then self.ctx:log('camp_respawn_confirmed',{camp=camp.id,name=camp.category,killedAt=camp.killedAt,
        expectedAt=camp.expectedAt,source=nativeTransition and 'native transition' or 'live monster'}) end
    camp.awaitingRespawn=false;camp.expectedAt=nil;camp.nativeDownSeen=nil;camp.blockedUntil=0
    camp.retiredMembers=nil;camp.knownMembers=nil;camp.emptyObservedAt=nil
end
function F:completed(camp,precise)
    -- Repeated death notifications must not restart an already running timer.
    if camp.awaitingRespawn then return end
    camp.retiredMembers=camp.retiredMembers or {}
    for _,m in ipairs(camp.members or {}) do
        local id=U.id(m);if id and not self:krugRemnant(m) then camp.retiredMembers[id]=true end
    end
    for id,row in pairs(camp.knownMembers or {}) do
        if not self:krugRemnant(row.unit) or row.dead then camp.retiredMembers[id]=true end
    end
    camp.killedAt=self.ctx:now();camp.killTimePrecise=precise~=false;camp.layout=nil;camp.seenAlive=true;camp.awaitingRespawn=true
    local duration=self:respawnDuration(camp)
    camp.expectedAt=duration and duration>0 and camp.killedAt+duration or nil;camp.blockedUntil=0
    camp.availability='observed_empty'
    if self.ctx.config.capture then self.ctx:log('camp_down',{camp=camp.id,name=camp.category,team=camp.team,profile=self.ctx.profile.id,
        killedAt=camp.killedAt,precise=camp.killTimePrecise,nativeUp=camp.nativeUp,
        expectedAt=camp.expectedAt,timer=camp.timerSource or 'profile estimate'}) end
    camp.focus=nil;camp.mainID=nil;camp.mainHealth=nil
    camp.kiteCenter=nil;camp.kiteHealth=nil;camp.kiteRecoverUntil=nil;camp.kiteDirection=nil
    local o=self.opening
    if o then
        for index=o.index,#o.order do
            if o.order[index]==camp.category then o.index=index+1;break end
        end
        if o.index>#o.order then self.opening=nil end
    end
end
function F:krugRemnant(unit)
    return self.ctx.profile.id=='normal' and U.name(unit and unit.charName)=='srukrugminimini'
end
function F:hasRemnants(camp)
    if self.ctx.profile.id~='normal' or camp.category~='Krugs' then return false end
    for _,m in ipairs(camp.members or {}) do
        if self:krugRemnant(m) and U.valid(m) then return true end
    end
    return false
end
function F:splitPending(camp)
    return camp and self.ctx.profile.id=='normal' and camp.category=='Krugs'
        and self.ctx:now()<(camp.splitUntil or 0)
end
function F:spawn()
    self.spawnPoints=self.spawnPoints or {}
    if self.spawnPos and not U.position(self.spawnPos) then self.spawnPos=nil end
    for _,team in ipairs({100,200}) do
        if self.spawnPoints[team] and not U.position(self.spawnPoints[team]) then self.spawnPoints[team]=nil end
    end
    if self.spawnPos and self.spawnPoints[100] and self.spawnPoints[200] then return self.spawnPos end
    local now=self.ctx:now()
    if Game.ObjectCount and Game.Object and now>(self.spawnScanAt or -2)+.5 then
        self.spawnScanAt=now
        local count=U.count(Game.ObjectCount(),65536)
        local first=self.spawnScanIndex or 1;if first>count then first=1 end
        local last=math.min(count,first+63)
        for i=first,last do
            local o=Game.Object(i)
            if o and ((Obj_AI_SpawnPoint and o.type==Obj_AI_SpawnPoint) or U.name(o.charName)=='spawnpoint') and U.position(o.pos) then
                local team=(o.team==100 or o.team==200) and o.team or o.isAlly and myHero.team
                if team then self.spawnPoints[team]=U.copy(o.pos) end
                if team==myHero.team then self.spawnPos=U.copy(o.pos) end
            end
        end
        self.spawnScanIndex=last>=count and 1 or last+1
    end
    if self.ctx.profile.id=='normal' then
        self.spawnPoints[100]=self.spawnPoints[100] or {x=400,y=180,z=420}
        self.spawnPoints[200]=self.spawnPoints[200] or {x=14300,y=180,z=14350}
        return self.spawnPos or self.spawnPoints[myHero.team]
    end
    -- Discover Classic spawn at load/respawn instead of copying a different map.
    if not self.spawnPos and U.position(myHero.pos) and (self.ctx:now()<25 or self.ctx:now()<180 and (myHero.levelData.lvl or 1)==1
        and (myHero.pos.x<1500 and myHero.pos.z<1500 or myHero.pos.x>13000 and myHero.pos.z>13000)) then
        self.spawnPos=U.copy(myHero.pos)
    end
    return self.spawnPos
end
function F:campTeam(pos)
    self:spawn()
    local spawns=self.spawnPoints
    if spawns and spawns[100] and spawns[200] then
        -- Relative proximity to both bases, never a fixed distance from ours.
        return U.dist(pos,spawns[100])<U.dist(pos,spawns[200]) and 100 or 200
    end
end
function F:updateCamps()
    local c=self.ctx;local now=c:now()
    local finished=self.camp and #(self.camp.members or {})>0
    if finished then for _,m in ipairs(self.camp.members) do if U.valid(m) then finished=false;break end end end
    if not finished and now<(self.scanAt or -1)+.4 then return end;self.scanAt=now
    local map=require(c.profile.id=='normal' and 'lho.normalcampdata' or 'lho.campdata')
    if not self.mapSeeded and c.profile.id==map.mode and Game.mapID==map.mapID then
        self.mapSeeded=true
        for _,data in ipairs(map.camps) do
            local id='map:'..data.name
            self.known[id]={id=id,pos=U.copy(data.pos),mapPos=U.copy(data.pos),category=data.category,team=data.team,
                availability='unknown',blockedUntil=0,mapNumber=data.number,fromMap=true}
            -- Walking-only correction from the Classic playtest at 144.523s:
            -- the untouched blue-side Wraith was east of the camp icon/wall.
            -- This is never used to authorize a fog Q or infer availability.
            if data.name=='Camp_Order_Wraiths' then
                self.known[id].walkPos={x=7443.1166992188,y=0,z=5663.0053710938}
            end
        end
    end
    for index,object in ipairs(c.camps or {}) do
        if object.pos then
            local number=tonumber((object.name or ''):match('monsterCamp_(%d+)'))
            local nativeID=U.id(object)
            local id=tostring(object.name and object.name~='' and object.name or nativeID and nativeID~=0 and nativeID or index)
            if self.mapSeeded then
                local nearest,distance=nil,c.profile.id=='normal' and 650 or 1100
                for key,known in pairs(self.known) do
                    local d=U.dist(known.mapPos or known.pos,object.pos)
                    if known.fromMap and d<distance and (c.profile.id~='normal' or not P.epics[known.category]) then nearest,distance=key,d end
                end
                -- Native indices differ from asset camp numbers in BOTH maps.
                -- Only spatial identity connects a timer to its actual camp.
                id=nearest
            end
            if id then
            local camp=self.known[id] or {id=id,pos=U.copy(object.pos),availability='unknown',blockedUntil=0}
            local locationMatches=not camp.fromMap or U.dist(camp.mapPos or camp.pos,object.pos)<1100
            camp.object=object
            if locationMatches then camp.pos=U.copy(object.pos) end
            if locationMatches then
                camp.nativeAim=U.copy(object.pos)
                if not camp.aimPos then camp.walkPos=U.copy(object.pos) end
            end
            local category=(c.profile.id=='normal' and P.campNames[number]) or P.category(object.name)
            if not camp.fromMap and (category~='Camp' or not camp.category) then camp.category=category end
            if camp.fromMap then -- Keep the extracted map's camp identity and side.
            elseif c.profile.id=='normal' and number then
                camp.team=(number<=5 or number==13) and 100 or ((number>=7 and number<=11) or number==14) and 200 or 0
            else
                camp.team=(object.team==100 or object.team==200) and object.team or camp.team
                if P.epics[camp.category] then camp.team=0 end
                if not camp.team then camp.team=self:campTeam(camp.pos) end
            end
            if locationMatches and type(object.isCampUp)=='boolean' then
                local previous=camp.nativeUp;camp.nativeUp=object.isCampUp
                if not object.isCampUp then
                    camp.layout=nil
                    -- Before the first observed spawn a native up/down flicker
                    -- is not evidence that somebody cleared this opening camp.
                    local opening=now<180 and (myHero.levelData.lvl or 1)==1 and not camp.seenAlive
                    if previous==true and not camp.awaitingRespawn and not opening then
                        self:completed(camp,now-(camp.lastNativeAt or -math.huge)<1)
                    end
                    camp.nativeDownSeen=true;camp.availability='observed_empty'
                elseif not camp.awaitingRespawn and (not camp.emptyObservedAt or previous==false)
                    or camp.awaitingRespawn and previous==false and camp.expectedAt and now>=camp.expectedAt-2 then
                    if camp.awaitingRespawn then self:respawnObserved(camp,now,previous==false) end
                    camp.availability='observed_alive';camp.observedAt=now
                end
                -- Continuous stale true cannot erase a directly observed kill.
                camp.lastNativeAt=now
            elseif not camp.awaitingRespawn and camp.availability=='observed_alive' and now-(camp.observedAt or 0)>5 then camp.availability='unknown' end
            self.known[id]=camp
            end
        end
    end
    if next(self.known)==nil and c.profile.id=='normal' then
        for i,p in ipairs(P.centers) do self.known['fallback'..i]={id='fallback'..i,pos={x=p[1],y=myHero.pos.y,z=p[2]},team=p[3],category=p[4],availability='unknown',blockedUntil=0} end
    end
    local current={};local memberOwner={}
    for _,m in ipairs(c.minions or {}) do if U.id(m) then current[U.id(m)]=m end end
    for _,camp in pairs(self.known) do
        camp.knownMembers=camp.knownMembers or {}
        for _,m in ipairs(camp.members or {}) do
            local id=U.id(m)
            if id and not camp.knownMembers[id] then
                camp.knownMembers[id]={unit=m,pos=U.copy(m.pos),visible=m.visible,lastSeen=now}
            end
        end
        local allDead,hasOriginal=true,false
        for id,row in pairs(camp.knownMembers) do
            memberOwner[id]=camp
            local m=row.unit;local fresh=current[id]
            local observed=fresh or m
            if fresh and U.valid(fresh) and not row.deathConfirmed then
                -- A filtered snapshot can briefly omit a live monster. It must
                -- not permanently retire that identity on the next observation.
                row.dead=nil;row.unit=fresh;row.missingAt=nil
                if camp.retiredMembers then camp.retiredMembers[id]=nil end
            elseif observed.dead or (observed.health or 0)<=0 then
                if not row.deathConfirmed and c.profile.id=='normal' and camp.category=='Krugs'
                    and (U.name(m.charName)=='srukrug' or U.name(m.charName)=='srukrugmini') then
                    camp.splitUntil=now+2
                end
                row.dead=true;row.deathConfirmed=true
            end
            if row.dead then
                camp.retiredMembers=camp.retiredMembers or {};camp.retiredMembers[id]=true
            end
            if not self:krugRemnant(m) then
                hasOriginal=true;if not row.dead then allDead=false end
            end
        end
        if hasOriginal and allDead and not camp.awaitingRespawn then
            camp.availability='observed_empty';camp.blockedUntil=now+20
            if camp.clearStartedAt then
                if c.config.capture then c:log('camp_clear_completed',{name=camp.category,duration=now-camp.clearStartedAt,health=U.hp(myHero),startHealth=camp.startHealth}) end
                camp.clearStartedAt=nil
            end
            self:completed(camp)
        end
        camp.members={}
    end
    for _,m in ipairs(c.minions or {}) do
        if m.team==300 and U.valid(m) and P.jungleEntity(m) then
            local category=P.category(m.charName)
            local best,distance=nil,math.huge
            for _,camp in pairs(self.known) do
                local compatible=category=='Camp' and not P.epics[camp.category] or category==camp.category or camp.category=='Camp'
                -- Classic camp markers are not monster spawn coordinates.
                -- Preserve a known member while it moves within its camp; a
                -- typed monster may join its matching marker across that offset.
                local d=math.min(U.dist(camp.mapPos or camp.pos,m.pos),U.dist(camp.pos,m.pos))
                local radius=c.profile.id=='classic' and camp.fromMap and category==camp.category and 1100 or 650
                if c.profile.id=='normal' and camp.fromMap and category==camp.category then radius=1800 end
                if memberOwner[U.id(m)]==camp then radius=math.huge end
                if compatible and d<radius then
                    local score=d-(memberOwner[U.id(m)]==camp and 2000 or 0)
                    if score<distance then best,distance=camp,score end
                end
            end
            if not best then
                -- Live monsters provide local discovery, including Classic Wight.
                local id='observed:'..tostring(U.id(m))
                best={id=id,pos=U.copy(m.pos),category=P.category(m.charName),team=self:campTeam(m.pos),
                    availability='unknown',blockedUntil=0,members={}}
                self.known[id]=best
            end
            local remnant=best and best.category=='Krugs' and self:krugRemnant(m)
            if best and (best.nativeUp~=false or remnant) and not (best.retiredMembers and best.retiredMembers[U.id(m)]) then
                best.members[#best.members+1]=m
                if best.awaitingRespawn and not remnant then self:respawnObserved(best,now) end
                best.knownMembers=best.knownMembers or {}
                local memberID=U.id(m)
                if memberID then best.knownMembers[memberID]={unit=m,pos=U.copy(m.pos),visible=m.visible,lastSeen=now} end
                best.emptyObservedAt=nil
                best.availability=best.awaitingRespawn and 'clearing_remnants' or 'observed_alive';best.observedAt=now
                best.seenAlive=true;best.blockedUntil=0
                if not m.pathing or not m.pathing.hasMovePath then
                    if m.health>=(m.maxHealth or m.health) and (m.maxHealth or 0)>=(best.aimHealth or 0) then
                        best.aimPos=U.copy(m.pos);best.aimHealth=m.maxHealth or 0
                        best.walkPos=U.copy(m.pos)
                    end
                end
                local cat=P.category(m.charName);if cat~='Camp' then best.category=cat end
            end
        end
    end
    for _,camp in pairs(self.known) do
        if camp.awaitingRespawn and not self:hasRemnants(camp) then camp.availability='observed_empty' end
        self:rememberLayout(camp)
    end
end
function F:epicSoon()
    for _,camp in pairs(self.known) do
        if P.epics[camp.category] and U.dist(myHero.pos,camp.pos)<3000 then
            for _,m in ipairs(camp.members or {}) do
                if U.valid(m) and m.health<(m.maxHealth or m.health)
                    and (self:alliesTaking(camp) or m.health<(m.maxHealth or m.health)*.5) then return true end
            end
        end
    end
    return false
end
function F:alliesTaking(camp)
    for _,a in ipairs(self.ctx.allies or {}) do
        if U.dist(a.pos,camp.pos)<1000 then
            local target=a.attackData and a.attackData.target
            local spell=a.activeSpell
            for _,m in ipairs(camp.members or {}) do
                if target==m.handle or (spell and spell.valid and spell.target==m.handle) then return true end
            end
        end
    end
    return false
end
function F:homeAvailable()
    if not self.ctx.config:get('farmPreferHome') then return false end
    for _,camp in pairs(self.known) do
        local travel=U.dist(myHero.pos,self:walkDestination(camp))/math.max(200,myHero.ms or 350)
        local due=camp.expectedAt and camp.expectedAt<=self.ctx:now()+travel
        local available=camp.nativeUp~=false and not camp.awaitingRespawn and camp.availability~='observed_empty'
        if camp.team==myHero.team and not P.epics[camp.category] and (available or due or self:staging(camp))
            and self.ctx:now()>=(camp.blockedUntil or 0) and self.ctx:threats(camp.pos,1000)==0
            and not self.ctx:underTurret(camp.pos) then return true end
    end
    return false
end
function F:sideAllowed(camp,home)
    if self.returningHome then return camp.team==myHero.team end
    if self.localException==camp.id and not P.epics[camp.category] then return true end
    if self.ctx.config:get('farmHomeOnly') and (camp.team~=nil or self.mapSeeded) then return camp.team==myHero.team end
    return not home or camp.team==myHero.team or camp.team==0
end
function F:ordinaryTarget(target)
    return U.valid(target) and target.team==300 and P.jungleEntity(target) and not P.epics[P.category(target.charName)]
end
function F:routeDistance(camp)
    local c=self.ctx;local destination=self:walkDestination(camp);local straight=U.dist(myHero.pos,destination)
    if not c.terrain:trusted() then return straight,'unverified straight distance' end
    self.routeCosts=self.routeCosts or {}
    local row=self.routeCosts[camp.id];local terrain=c.terrain
    if not row or row.provider~=terrain.provider or row.wall~=terrain.provider.isWall
        or U.dist(row.origin,myHero.pos)>150 or U.dist(row.destination,destination)>100 then
        row={origin=U.copy(myHero.pos),destination=U.copy(destination),provider=terrain.provider,wall=terrain.provider.isWall}
        row.work=coroutine.create(function()
            if terrain:walkLine(row.origin,row.destination,myHero.boundingRadius or 35) then return straight end
            local path,length=require('lho.navigation').approach(terrain,row.origin,row.destination,220,straight*2+1500,
                function()coroutine.yield()end,function(p)return terrain:walkLine(p,row.destination,myHero.boundingRadius or 35)end,8)
            return path and length+U.dist(path[#path] or row.origin,row.destination)
        end)
        self.routeCosts[camp.id]=row
    end
    -- One bounded solver slice for the whole controller per state cycle.
    if not row.done and self.routeCostAt~=c:now() then
        self.routeCostAt=c:now()
        local ok,value=coroutine.resume(row.work)
        if not ok or coroutine.status(row.work)=='dead' then row.done=true;row.cost=ok and value or nil end
    end
    return row.cost or straight,row.cost and 'verified terrain route' or 'unverified straight distance'
end
function F:choose(exclude,preview)
    local c=self.ctx;local now=c:now();local candidates={};local nearest=math.huge
    local home=self:homeAvailable()
    if now>=300 and not preview then self.opening=nil end
    for _,camp in pairs(self.known) do
        local distance=U.dist(myHero.pos,self:walkDestination(camp))
        local localEnemy=distance<1600
        local teamAllowed=camp.team==0 or camp.team==myHero.team or localEnemy or c.config:get('invade')
        local epic=P.epics[camp.category]
        local staging=self:staging(camp)
        local available=staging or camp.availability~='observed_empty' or camp.expectedAt~=nil
        if camp~=exclude and available and (teamAllowed or self.localException==camp.id) and self:sideAllowed(camp,home) and (staging or now>=(camp.blockedUntil or 0)) and c:threats(camp.pos,1000)==0
            and not epic and not c:underTurret(camp.pos) then
            local hp=0;for _,m in ipairs(camp.members or {}) do hp=hp+m.health end
            if distance<500 and hp>0 then
                for _,m in ipairs(camp.members) do
                    if m.health<(m.maxHealth or m.health) then
                        if c.config.capture and not preview then c:trace('route_choice',{selected=camp.id,reason='Finish nearby damaged camp',distance=distance},'choice',1) end
                        return camp
                    end
                end
            end
            local routeDistance,routeSource=self:routeDistance(camp)
            local travel=routeDistance/math.max(200,myHero.ms or 350)
            local wait=not self:hasRemnants(camp) and camp.expectedAt and math.max(0,camp.expectedAt-now-travel) or 0
            local cost=routeDistance+wait*math.max(200,myHero.ms or 350)
            candidates[#candidates+1]={camp=camp,cost=cost,distance=distance,wait=wait,routeSource=routeSource};nearest=math.min(nearest,cost)
        end
    end
    -- Honour the first-clear order instead of recomputing a greedy nearest
    -- neighbour after every kill (Blue -> Wolves -> Wight backtracks).
    -- A stolen, unavailable or threatened camp is skipped, never waited for
    -- ahead of live work. After this one clear, ordinary respawn ranking wins.
    local opening=now<300 and self.opening
    if opening then
        for index=opening.index,#opening.order do
            for _,entry in ipairs(candidates) do
                local camp=entry.camp
                if camp.team==myHero.team and camp.category==opening.order[index]
                    and not camp.killedAt and not camp.awaitingRespawn
                    and (camp.availability~='observed_empty' or self:staging(camp)) then
                    if not preview then opening.index=index end
                    if c.config.capture and not preview then c:trace('route_choice',{selected=camp.id,reason='First-clear order',index=index},'choice',1) end
                    return camp
                end
            end
        end
        if not preview then self.opening=nil end
    end
    local best,bestValue,bestCost=nil,-1,math.huge
    for _,entry in ipairs(candidates) do
        local camp=entry.camp
        if entry.cost<=nearest+250 then
            local value=(camp.category=='Red' or camp.category=='Blue') and 2 or 1
            if value>bestValue or value==bestValue and (entry.cost<bestCost or entry.cost==bestCost and tostring(camp.id)<tostring(best and best.id)) then
                best,bestValue,bestCost=camp,value,entry.cost
            end
        end
    end
    if c.config:get('playtestLogging') and not preview then
        local rows={}
        for _,entry in ipairs(candidates) do
            rows[#rows+1]={id=entry.camp.id,category=entry.camp.category,team=entry.camp.team,
                distance=entry.distance,wait=entry.wait,cost=entry.cost,routeSource=entry.routeSource,state=entry.camp.availability}
        end
        if c.config.capture then c:trace('route_choice',{selected=best and best.id,homeAvailable=home,candidates=rows,
            reason='Distance plus spawn wait; buff priority within 250'},'choice',1) end
    end
    return best
end
function F:staging(camp)
    -- Initial absence is not a killed camp. Walk to the opening before spawn;
    -- use actual visible monsters to end staging rather than guessing a timer.
    return self.ctx:now()<180 and (myHero.levelData.lvl or 1)==1 and not camp.seenAlive and not camp.killedAt
        and not P.epics[camp.category] and camp.team==myHero.team
end
function F:pause(reason)
    self.travelTarget=nil;self.travelJob=nil;self.probe=nil
    self.ctx.input:pauseFarm(reason);self.ctx.status=reason or 'Farming paused';self.state='paused'
    self.ctx.attackTarget=nil;self.ctx.moveTarget=nil
end
function F:kiteLine(origin,destination)
    local terrain=self.ctx.terrain;local radius=myHero.boundingRadius or 35
    -- Live positions can overlap conservative static-grid padding. Egress only
    -- permits leaving that padding; its centerline never crosses a wall.
    if terrain.egressLine then return terrain:egressLine(origin,destination,radius) end
    return terrain:walkLine(origin,destination,radius)
end
function F:kiteClick(point,target,center,leash,scene)
    local c=self.ctx;local distance=U.dist(myHero.pos,point)
    if distance<1 then return point end
    -- The click is a steering ray, not the turnaround waypoint. Only actual
    -- travel is leash-bounded. A straight, empty ray avoids native wall detours.
    for _,length in ipairs({math.max(distance,1000),math.max(distance,800),math.max(distance,600),math.max(distance,400),math.max(distance,250),distance}) do
        local click=U.toward(myHero.pos,point,length)
        if U.vector(click):To2D().onScreen~=false and self:kiteLine(myHero.pos,click)
            and not require('lho.ground').blocker(c,click,scene) then return click end
    end
    return nil
end
function F:kiteDecision(target,reason)
    local c=self.ctx;local camp=self.camp
    if not c.config.capture or not camp then return end
    local attack=c.sdk.Attack;local row=self.kiteDiagnostic or {};self.kiteDiagnostic=row
    row.reason=reason;row.at=c:now();row.target=U.id(target);row.name=target.charName
    row.range=target.range;row.main=camp.mainID;row.enabled=c.config:get('farmKite')
    row.autoAttacking=c.sdk.Orbwalker:IsAutoAttacking();row.canMove=c.sdk.Orbwalker:CanMove()
    row.ready=attack and attack.IsReady and attack:IsReady();row.serverStart=attack and attack.ServerStart
    row.castEnd=attack and attack.CastEndTime;row.cycle=attack and attack.GetAnimation and attack:GetAnimation()
    row.separation=U.dist(myHero.pos,target.pos);row.center=camp.kiteCenter;row.leash=c.config:get('farmKiteLeash')
    row.latency=c.latency;row.jitter=c.jitter;row.speed=myHero.ms
    row.position=U.copy(myHero.pos);row.targetPosition=U.copy(target.pos)
end
function F:kitePursuers(target)
    local out={}
    for _,m in ipairs(self.camp and self.camp.members or {target}) do
        if U.valid(m) and (m.range or 0)<=250 then
            out[#out+1]={pos=U.copy(m.pos),stop=math.max(75,m.range or 100)+(m.boundingRadius or 45)+(myHero.boundingRadius or 35)}
        end
    end
    return out
end
function F:kiteBound(point,target,center,leash,reserve,pursuers)
    local radius=U.dist(point,center)
    if radius<=leash then return true,false end
    -- The leash belongs to pursuing monsters, not Lee's hitbox. Permit a
    -- bounded outer arc when the preferred inner ring has no usable step.
    -- Reserve overshoot room for one delayed callback; check every melee pursuer.
    local margin=math.max(25,(myHero.ms or 350)*(reserve or .15))
    if radius>math.max(leash,U.dist(myHero.pos,center))+80 then return false end
    local checked=false
    local inward=radius<U.dist(myHero.pos,center)-15
    for _,m in ipairs(pursuers or self:kitePursuers(target)) do
        checked=true
        local gap=U.dist(m.pos,point)
        local chase=gap>m.stop and U.toward(m.pos,point,gap-m.stop) or m.pos
        local chasedRadius=U.dist(chase,center)
        if chasedRadius>leash-margin and not (inward and chasedRadius<=U.dist(m.pos,center)+1) then return false end
    end
    return checked,true
end
function F:kite(target)
    local c=self.ctx;local camp=self.camp;local attack=c.sdk.Attack
    if not camp then return end
    local name=U.name(target.charName)
    if (target.range or 0)>250 or name:find('wraith',1,true) or name:find('wight',1,true)
        or name:find('gromp',1,true) then self.kiteStep=nil;self:kiteDecision(target,'ranged_target');return end
    -- Remember the largest member, including after it dies. A surviving small
    -- monster must not become the "main" monster just because it is alone.
    for _,m in ipairs(camp.members or {}) do
        if (m.maxHealth or 0)>(camp.mainHealth or 0) then camp.mainHealth=m.maxHealth;camp.mainID=U.id(m) end
    end
    if not c.config:get('farmKite') or c:dash()
        or not attack or not attack.IsReady then self.kiteStep=nil;self:kiteDecision(target,'attack_or_movement_gate');return end
    if attack:IsReady() then
        if self.kiteStep and U.dist(myHero.pos,target.pos)>c:attackRange(target) then
            self.kiteStep.phase='attack'
        else self.kiteStep=nil end
        self:kiteDecision(target,'attack_ready');return
    end
    local cycle=attack.GetAnimation and attack:GetAnimation() or 1
    local started=attack.ServerStart
    if not started or started<=0 then self:kiteDecision(target,'missing_attack_start');return end -- No invented attack timing.
    local remaining=started+cycle-c:now()
    local finish=attack.CastEndTime and attack.CastEndTime>=started and attack.CastEndTime or started+c:windup()
    local preparing=c:now()<finish or c.sdk.Orbwalker:IsAutoAttacking() or not c.sdk.Orbwalker:CanMove()
    if remaining<=0 then self:kiteDecision(target,'attack_windup_or_ready');return end
    if preparing and self.kiteStep and self.kiteStep.started==started and self.kiteStep.target==U.id(target)
        and self.kiteStep.cycle==cycle then return end
    if not camp.kiteCenter then
        local center=camp.aimPos or camp.pos;local health=0
        local layout=camp.spawnLayout
        if layout and layout.mode==c.profile.id and layout.mapID==Game.mapID then
            for _,row in ipairs(layout.rows) do
                if (row.maxHealth or 0)>health then center=row.pos;health=row.maxHealth end
            end
        end
        camp.kiteCenter=U.copy(center)
    end
    local center=camp.kiteCenter;local leash=c.config:get('farmKiteLeash')
    local observed=camp.kiteHealth
    if observed and observed.id==U.id(target) and c:now()-observed.at<.5
        and target.health>observed.hp+math.max(30,target.maxHealth*.02) then
        camp.kiteRecoverUntil=c:now()+2;self.kiteStep=nil
        if c.config.capture then c:log('kite_reset_suspected',{target=U.id(target),health=target.health,previous=observed.hp}) end
    end
    camp.kiteHealth={id=U.id(target),hp=target.health,at=c:now()}
    -- Crossing the preferred leash ring is a reason to turn inward, not to
    -- disable kiting for the rest of the fight. Actual resets still suspend it.
    if U.dist(target.pos,center)>leash+150 or c:now()<(camp.kiteRecoverUntil or 0) then self.kiteStep=nil;self:kiteDecision(target,'leash_or_reset');return end
    local speed=math.max(1,myHero.ms or 350);local ownRange=math.max(30,c:attackRange(target)-10)
    local separation=U.dist(myHero.pos,target.pos)
    local timing=c.sdk.Input and c.sdk.Input.Timing
    -- Callback jitter is different from network ping. Refresh this reserve at
    -- most four times a second, keeping statistical work out of the fast path.
    if not self.kiteReserveAt or c:now()>=self.kiteReserveAt+.25 then
        self.kiteReserveAt=c:now()
        self.kiteReserve=timing and timing.reserve and U.clamp(timing:reserve()*.001,0,.2) or .06
    end
    local reserve=c.latency+math.max(.016,self.kiteReserve or .06)
    local returnTime=math.max(0,separation-ownRange)/speed
    local key=tostring(U.id(target))..':'..tostring(started)
    local step=self.kiteStep
    if step and step.key==key and step.cycle and math.abs(step.cycle-cycle)>.001 then
        self.kiteStep=nil;self.kiteSearch=nil;step=nil
    end
    local function publish(point)
        if not preparing then return point end
    end
    if step and step.key==key and step.phase=='attack' then return end
    local passedWaypoint=step and step.key==key and step.phase=='out'
        and (U.dist(myHero.pos,step.pos)<=25 or step.origin
            and (myHero.pos.x-step.origin.x)*(step.pos.x-step.origin.x)
                +(myHero.pos.z-step.origin.z)*(step.pos.z-step.origin.z)
                >=math.max(0,U.dist(step.origin,step.pos)-25)*U.dist(step.origin,step.pos))
    -- Begin returning while the attack is still cooling down. Use a stationary
    -- target for this budget: a chasing monster may help, but is not promised.
    local reachedOut=passedWaypoint and separation>ownRange
    if reachedOut or (separation>ownRange or self.kiteStep and self.kiteStep.key==key and self.kiteStep.phase=='out')
        and remaining<=returnTime+reserve then
        self.kiteStep={key=key,pos=U.copy(target.pos),phase='attack',target=U.id(target),started=started}
        if c.config.capture then c:log('kite_attack_due',{target=U.id(target),remaining=remaining,
            returnTime=returnTime,reserve=reserve,separation=separation}) end
        return -- The target attack order performs the approach, without a ground move.
    end
    if self.kiteStep and self.kiteStep.key==key then
        local p=self.kiteStep.pos
        if self.kiteStep.phase=='return' and separation<=ownRange or passedWaypoint or U.dist(myHero.pos,p)<=25 then
            -- The monster may have followed us faster than expected. Replan
            -- along the camp boundary instead of waiting at a reached waypoint.
            self.kiteStep=nil;self.kiteSearch=nil
        elseif U.dist(myHero.pos,p)>25 and self:kiteBound(p,target,center,leash,reserve) and self:kiteLine(myHero.pos,p) then
            -- Reuse the geometric ray for this attack instead of recomputing it
            -- on every Draw. Dispatch still checks current projected blockers.
            return publish(self.kiteStep.phase=='out' and self.kiteStep.click or p)
        else
            self.kiteStep=nil
        end
    end
    local budget=math.max(0,remaining-math.max(0,finish-c:now())-reserve)*speed
    local distance=math.min(c.config:get('farmKiteDistance'),budget)
    if distance<30 then self:kiteDecision(target,'insufficient_movement_time');return end
    local away=U.toward(target.pos,myHero.pos,1)
    local dx,dz=away.x-target.pos.x,away.z-target.pos.z
    if U.dist(myHero.pos,target.pos)<1 then dx,dz=1,0 end
    local enemyRange=((target.range or 0)>0 and target.range or 125)+(target.boundingRadius or 45)+(myHero.boundingRadius or 35)+25
    local direction=camp.kiteDirection or 1;local best,bestAngle,bestClick;local candidates={}
    local search=self.kiteSearch
    if search and search.key==key and c:now()<search.at+.08 and U.dist(myHero.pos,search.origin)<20
        and U.dist(target.pos,search.target)<20 then return end
    self.kiteSearch={key=key,at=c:now(),origin=U.copy(myHero.pos),target=U.copy(target.pos)}
    self:kiteDecision(target,'searching_or_following_plan')
    local scene=require('lho.ground').scene(c)
    local pursuers=self:kitePursuers(target)
    -- Outward first; near the edge, turn tangentially and then inward. Keep a
    -- consistent rotation across attacks instead of flipping left/right.
    local radial=U.dist(myHero.pos,center)
    for _,angle in ipairs({0,.55,1.1,1.57,2.1,2.65,3.14,-.55,-1.1,-1.57,-2.1,-2.65}) do
        local a=angle*direction
        local x,z=dx*math.cos(a)-dz*math.sin(a),dx*math.sin(a)+dz*math.cos(a)
        for _,scale in ipairs({1,.75,.5}) do
            local length=distance*scale
            local p={x=myHero.pos.x+x*length,y=myHero.pos.y,z=myHero.pos.z+z*length}
            local gap=U.dist(p,target.pos);local back=math.max(0,gap-ownRange)
            local bounded,outer=self:kiteBound(p,target,center,leash,reserve,pursuers)
            local inward=radial>leash-40 and U.dist(p,center)<radial-15
                and gap>=math.max((target.boundingRadius or 45)+(myHero.boundingRadius or 35)+15,math.min(separation,enemyRange)-25)
            if length>=30 and length+back<=budget and bounded
                and (gap>=enemyRange or gap>separation+15 or inward)
                and self:kiteLine(myHero.pos,p)
                and (back==0 or self:kiteLine(p,U.toward(target.pos,p,ownRange))) then
                local value=math.min(gap-enemyRange,45)*4+length*.15
                    + (angle>0 and 12 or angle<0 and -12 or 0)-math.abs(angle)*5
                    - (outer and 1000+math.max(0,U.dist(p,center)-leash) or 0)
                    + (inward and math.min(80,radial-U.dist(p,center)) or 0)
                candidates[#candidates+1]={pos=p,score=value,angle=angle}
            end
        end
    end
    table.sort(candidates,function(a,b)return a.score>b.score end)
    for _,candidate in ipairs(candidates) do
        local click=self:kiteClick(candidate.pos,target,center,leash,scene)
        if click then best,bestAngle,bestClick=candidate.pos,candidate.angle,click;break end
    end
    if best then
        self:kiteDecision(target,'outward_plan')
        if bestAngle<0 then camp.kiteDirection=-direction else camp.kiteDirection=direction end
        self.kiteStep={key=key,started=started,target=U.id(target),cycle=cycle,pos=best,click=bestClick,origin=U.copy(myHero.pos),phase='out',preparedAt=c:now(),castEnd=finish}
        if c.config.capture then c:log('kite_planned',{target=U.id(target),origin=U.copy(myHero.pos),destination=U.copy(best),
            center=U.copy(center),remaining=remaining,enemyRange=enemyRange,ownRange=ownRange,
                separation=U.dist(best,target.pos),travel=U.dist(myHero.pos,best),budget=budget,click=U.copy(bestClick),
                preparedDuringWindup=preparing,cycle=cycle,castEnd=finish,reserve=reserve}) end
        return publish(bestClick)
    end
    self:kiteDecision(target,'no_feasible_ground_and_return_budget')
end
function F:fastKite()
    local c=self.ctx;local camp=self.camp
    if (self.state~='clearing' and self.state~='finishing') or not camp or camp.nativeUp==false or camp.awaitingRespawn
        or not c.config:get('autoJungle') or c.input.farmPaused
        or c:blocked() or c:recalling() or c.wards.pending or c.combat.insec then return false end
    local target=camp.focus or c.attackTarget
    if not self:ordinaryTarget(target) then return false end
    -- Draw/post-attack can run before the next planning Tick. Dispatch a ready
    -- attack there too, through the same scoped API and native readiness gates.
    if U.same(c.attackTarget,target) and c.actions.attack and c.sdk.Orbwalker:CanAttack()
        and U.dist(myHero.pos,target.pos)<=c:attackRange(target) then
        return c.actions:attack(target,'farm')
    end
    local point=self:kite(target)
    local step=self.kiteStep
    if step and step.phase=='attack' and c.actions.attackApproach then
        return c.actions:attackApproach(target,'farm',step.key)
    end
    if not point then return false end
    local accepted,reason=self.actions:move(point,'farm');local id=self.actions.lastCursorAction
    if accepted and id and id~=self.kiteMoveID then
        self.kiteMoveID=id
        if c.config.capture then c:log('kite_move_request',{cursorID=id,target=U.id(target),destination=U.copy(point),
            attackStart=c.sdk.Attack.ServerStart,castEnd=c.sdk.Attack.CastEndTime,
            windupDeltaMs=c.sdk.Attack.CastEndTime and (c:now()-c.sdk.Attack.CastEndTime)*1000,
            phase=self.kiteStep and self.kiteStep.phase,preparedAt=self.kiteStep and self.kiteStep.preparedAt}) end
    end
    return accepted,reason
end
function F:clear(target)
    if not self:ordinaryTarget(target) then self.ctx.attackTarget=nil;return end
    -- Attacking and kiting intentionally replace the travel destination.
    -- Retire its endpoint check before GG issues the first combat order.
    self.actions.routeObservation=nil;self.actions.routeCommand=nil;self.actions.routeStop=nil
    if self.camp then self.camp.lastFoughtAt=self.ctx:now() end
    local c=self.ctx;c.attackTarget=target;c.moveTarget=nil
    -- GG remains responsible for attack readiness and windup cancellation.
    -- Retreat/return planning runs during cooldown; GG starts the next attack.
    local kite=self:kite(target)
    if kite then c.moveTarget=kite
    elseif self.kiteStep and self.kiteStep.phase=='attack' and c.actions.attackApproach then
        c.actions:attackApproach(target,'farm',self.kiteStep.key)
    elseif U.dist(myHero.pos,target.pos)>c:attackRange(target) then
        -- A monster's body is an attack destination, not a ground-click point.
        -- Keep the attack owner while approaching, including after a kite step
        -- or a focus change to another member of this same camp.
        if c.actions.attackApproach then
            c.actions:attackApproach(target,'farm','camp:'..tostring(self.camp and self.camp.id))
        else c.moveTarget=target.pos end
    end
    c.clear:tick(target,'farm')
end
function F:priority(m)
    local hits=m.health/math.max(1,self.ctx:aaDamage(m))
    -- Remove cheap camp attackers first; do not spend a full buff-sized clear
    -- on a small monster. AoE can finish the remaining small units together.
    return hits<=4 and -100000+hits or -(m.maxHealth or m.health)
end
function F:selectTarget(camp)
    if ((camp.nativeUp==false or camp.awaitingRespawn) and not self:hasRemnants(camp)) or P.epics[camp.category] then return end
    local c=self.ctx;local now=c:now();local units={};local main
    for _,m in ipairs(camp.members or {}) do if self:ordinaryTarget(m) then
        units[#units+1]=m
        if not main or (m.maxHealth or m.health)>(main.maxHealth or main.health) then main=m end
    end end
    local current=camp.focus;local early=(myHero.levelData.lvl or 1)<=c.config:get('farmSurvivalLevel') or U.hp(myHero)<40
    local smite=c.config:get('autosmite') and c.smite:ready() and not self:epicSoon() and c.smite:damage() or 0
    -- Invocation-local values: retain fresh HP each decision without querying
    -- SDK damage/buffs repeatedly for focus retention and diagnostic output.
    local hitCounts,scores={},{}
    local cycle=c.sdk.Attack.GetAnimation and c.sdk.Attack:GetAnimation() or 1
    local eLearned=(c:spell(2).level or 0)>0
    local function hits(m)
        if hitCounts[m]~=nil then return hitCounts[m] end
        local hp=m.health+(m.allShield or 0)
        if U.same(m,main) and c.smite:campTarget(m) and c.smite:inRange(m) then hp=hp-smite+c.config:get('smiteMargin') end
        local count=math.max(0,math.ceil(hp/math.max(1,c:aaDamage(m))))
        hitCounts[m]=count;return count
    end
    local function score(m)
        local count=hits(m);local move=math.max(0,U.dist(myHero.pos,m.pos)-c:attackRange(m))/math.max(1,myHero.ms or 350)
        if early then
            -- Weighted completion-time rule: remove damage sources according to
            -- remaining kill time / incoming DPS. Actual monster stats take
            -- priority; max-health scaling is an explicit fallback estimate.
            local damage=m.totalDamage or m.attackData and m.attackData.damage or math.max(8,(m.maxHealth or m.health)*.035)
            local rate=m.attackSpeed or (m.attackData and m.attackData.animationTime and 1/math.max(.2,m.attackData.animationTime)) or .7
            return (count*cycle+move)/math.max(1,damage*rate)
        end
        -- With AoE available, hit the durable member while cleave/E wears down
        -- the rest. Otherwise choose quick cleanup with minimal movement.
        if count<=2 then return -100+count+move end
        -- E entering cooldown must not flip focus back to healthy companions.
        -- Continue damaging the durable member between successive AoE cycles.
        if #units>1 and eLearned and count>2 then return -(m.maxHealth or m.health)/1000+move end
        return count*cycle+move
    end
    local best,bestScore=nil,math.huge
    for _,m in ipairs(units) do local value=score(m);scores[m]=value;if value<bestScore then best,bestScore=m,value end end
    if current then
        -- Host wrappers can change between scans for the same network identity.
        -- Retention must use this scan's object, health and cached score.
        local observed
        for _,m in ipairs(units) do if U.same(m,current) then observed=m;break end end
        if observed and (hits(observed)<=2 or scores[observed]<=bestScore+math.max(.05,math.abs(bestScore)*.25) or now<(camp.focusUntil or 0)) then best=observed end
    end
    if best and not U.same(best,current) then
        camp.focusUntil=now+.6
        if c.config.capture then c:log('camp_focus',{target=U.id(best),name=best.charName,policy=early and 'damage mitigation' or 'clear speed',remainingAttacks=hits(best)}) end
    end
    camp.focus=best
    return best
end
function F:localTarget(lane,jungle)
    local c=self.ctx;c:refresh();self:updateCamps()
    if lane==nil then lane=true end;if jungle==nil then jungle=true end
    if self.localCamp and jungle then
        local best,score=nil,math.huge
        for _,m in ipairs(self.localCamp.members or {}) do
            if U.valid(m) and U.dist(myHero.pos,m.pos)<=c:attackRange(m)+150 then
                local value=self:priority(m);if value<score then best,score=m,value end
            end
        end
        if best then return self:selectTarget(self.localCamp) or best end
    end
    self.localCamp=nil
    local anchor,distance=nil,math.huge
    for _,m in ipairs(c.minions or {}) do
        if U.valid(m) and m.team~=myHero.team and (m.team==300 and jungle or m.team~=300 and lane) then
            local d=U.dist(myHero.pos,m.pos)
            if d>1100 then d=math.huge end
            if d<distance then anchor,distance=m,d end
        end
    end
    if not anchor or anchor.team~=300 then return anchor end
    for _,camp in pairs(self.known) do
        local contains=false
        for _,m in ipairs(camp.members or {}) do if U.same(m,anchor) then contains=true;break end end
        if contains then
            self.localCamp=camp
            local best,score=nil,math.huge
            for _,m in ipairs(camp.members) do
                if U.valid(m) and U.dist(myHero.pos,m.pos)<=1100 then
                    local value=self:priority(m);if value<score then best,score=m,value end
                end
            end
            return self:selectTarget(camp) or best
        end
    end
    return anchor
end
function F:recovery()
    if self.ctx:recalling() or self.state=='recalling' then self.localException=nil end
    local c=self.ctx;local spawn=self:spawn();local now=c:now()
    if not spawn then c.status='Spawn position needs observation';return false end
    if U.dist(myHero.pos,spawn)<550 then
        if self.state~='base' then self.camp=nil;self.localException=nil;self.returningHome=true end
        if self.recallAction then self.actions:recallStatus(self.recallAction,true) end
        if self.state=='recalling' then if c.config.capture then c:log('farm_recall_arrived',{pos=U.copy(myHero.pos),spawn=U.copy(spawn)}) end end
        self.recallEndedAt=nil;self.recallObserved=false;self.recallAction=nil;self.recallLegacy=nil
        self.state='base';c.attackTarget=nil;c.moveTarget=nil
        if U.hp(myHero)<95 then c.status='Healing at base';return true end
        self.state='routing';self.recallAt=nil;self.recoveryWanted=nil;self.retreatCamp=nil;self.retreatMove=nil;self.recallReconcile=nil;self.recallSentTick=nil;return false
    end
    if c.input.farmPaused or not c.config:get('autoJungle') then return false end
    -- Full missile enumeration is needed before recovery, not on every healthy
    -- clear tick. The old path discarded that result in this exact case anyway.
    if self.lastRecoveryHP and myHero.health<self.lastRecoveryHP-.1 then self.lastHurtAt=now end
    self.lastRecoveryHP=myHero.health
    local low=U.hp(myHero)<c.config:get('recallHP')
    local wanted=self.recoveryWanted or low
    local awaiting=self.recallAction or self.recallLegacy or self.recallObserved or self.recallReconcile or c:recalling()
    local pressure=self:championPressure();local turret=c:underTurret(myHero.pos)
    if self.threatRetreat and not wanted and not awaiting then
        local safety=self:combatSafety(true)
        if pressure.count==0 and not turret and safety.monsters==0 and safety.missiles==0 and not safety.recentDamage and not safety.unknown then
            self.threatRetreat=nil;self.retreatCamp=nil;self.retreatMove=nil
            self:recoveryTransition('routing','threat_cleared_without_recall');return false
        end
        return self:retreat()
    end
    -- Do not begin another full camp on the reserve used to finish the last one.
    -- This only raises recovery intent before an engagement, never abandons one.
    if not wanted and not awaiting and self.camp and (not self.camp.lastFoughtAt or now-self.camp.lastFoughtAt>5)
        and U.hp(myHero)<math.min(50,c.config:get('recallHP')*2)
        and U.dist(myHero.pos,self:walkDestination(self.camp))<1100 then
        local forecast=self:finishForecast()
        if not forecast.safe then wanted=true end
    end
    if not wanted and not awaiting and pressure.count==0 and not turret then return false end
    if not wanted and not awaiting then
        self.threatRetreat=true;self.recoveryTrigger=turret and 'enemy_turret' or pressure.reason
        self:beginRetreat('immediate_threat',false);return self:retreat()
    end
    self.threatRetreat=nil
    self.recoveryTrigger=self.recoveryTrigger or (low and 'low_health' or 'insufficient_camp_reserve')
    local safe=self:recallSafe(true)
    local recallRecord=self.recallAction and self.actions:recallStatus(self.recallAction)
    if c:recalling() then
        self.recoveryWanted=true;self.localException=nil;self.recallObserved=true
        self:recoveryTransition('recalling','recall_observed');c.attackTarget=nil;c.moveTarget=nil;return true
    end
    if self.recallObserved then
        self.recallEndedAt=self.recallEndedAt or now
        if safe and now-self.recallEndedAt<.75 then c.status='Checking recall arrival';return true end
        self.recallObserved=false;self.recallAction=nil;self.recallLegacy=nil;self.recallReconcile=U.copy(myHero.pos)
        self:beginRetreat('recall_interrupted_by_game_state');return self:retreat()
    end
    if self.recallAction or self.recallLegacy then
        local r=recallRecord
        if r and r.state=='cancelled_before_send' then
            self.recallAction=nil;self:beginRetreat('recall_cancelled_before_send')
        elseif r and not r.sentAt then
            if not safe then
                self.actions:recallStatus(self.recallAction,true);self.recallAction=nil
                self:beginRetreat('threat_before_recall_send');return self:retreat()
            end
            self:recoveryTransition('recall_pending','awaiting_input');c.attackTarget=nil;c.moveTarget=nil
            c.status='Recall waiting for input';return true
        else
            local tick=self.actions.inputNow and self.actions:inputNow() or now*1000
            self.recallSentTick=r and r.sentAt or self.recallSentTick or tick
            local reserve=math.max(0,c.jitter or 0)*3
            if c.sdk.Input and c.sdk.Input.Timing and c.sdk.Input.Timing.reserve then reserve=math.max(reserve,c.sdk.Input.Timing:reserve()*.001) end
            local budget=math.min(3,1+reserve)*1000
            if tick-self.recallSentTick<budget and safe then
                self:recoveryTransition('recall_pending','awaiting_confirmation');c.attackTarget=nil;c.moveTarget=nil
                c.status='Recall awaiting confirmation';return true
            end
            self.recallAction=nil;self.recallLegacy=nil;self.recallSentTick=nil;self.recallReconcile=U.copy(myHero.pos)
            self:beginRetreat(safe and 'recall_confirmation_timeout' or 'threat_after_recall_send')
            return self:retreat()
        end
    end
    if self.recallReconcile then
        -- Positive movement away from the failed channel is a new game state;
        -- elapsed time or unchanged readiness alone does not replay B.
        if U.dist(myHero.pos,self.recallReconcile)<80 then return self:retreat() end
        self.recallReconcile=nil
    end
    if not wanted and safe then return false end
    if not wanted and self:combatSafety().champions==0 and not self:combatSafety().turret then return false end
    self.recoveryWanted=true
    -- Walking back into fountain range is faster than an eight-second recall
    -- from the platform edge. Only movement and health determine this boundary.
    if safe and U.dist(myHero.pos,spawn)<1200 then
        self:recoveryTransition('returning_base','near_fountain_walk')
        c.attackTarget=nil;c.moveTarget=U.copy(spawn);return true
    end
    if self.state~='retreating' and self.camp then
        local forecast=self:finishForecast()
        if c.config.capture then c:trace('finish_forecast',forecast,'finish_forecast',.5) end
        if forecast.safe then
            self:recoveryTransition('finishing','finish_active_camp',forecast)
            local target=self:selectTarget(self.camp)
            if target then self:clear(target);return true end
        end
    end
    if not safe then self:beginRetreat('unsafe_to_recall');return self:retreat() end
    if self.state~='recall_pending' then
        self.actions:cancel('farm');self.actions:cancel('escape')
        self.probe=nil;self.travelTarget=nil;self.travelJob=nil;self.opening=nil;self.localException=nil
        self.actions.routeStop=nil;self.actions.routeObservation=nil;self.actions.routeCommand=nil
        self:recoveryTransition('recall_pending','safe_recall_window')
    end
    c.attackTarget=nil;c.moveTarget=nil
    if c.actions:cursorBusy() or self.actions.api and self.actions.api:GetAvailability().cleanupPending then c.status='Recall waiting for input';return true end
    local accepted,why,submitted,id
    if self.actions.recall then accepted,why,submitted,id=self.actions:recall()
    else
        local input=c.sdk.Input
        if input and (input.Uncertain or not input:Available()) then c.status='Recall waiting for input';return true end
        local ok,result=pcall(Control.CastSpell,HK_RECALL or 66);accepted=ok and result~=false;submitted=accepted
    end
    local r=id and c.actions:inputAction(id)
    self.recallAction=(accepted or submitted or r and (r.state=='waiting' or r.state=='requested')) and id or nil
    if not accepted and not submitted then c.status='Recall waiting for input';return true end
    self.recallAt=now;self.recallSentTick=r and r.sentAt;self.recallObserved=false;self.recallEndedAt=nil
    if not self.actions.api then self.state='recalling';self.recallLegacy=true;self.recallSentTick=now*1000 end
    if c.config.capture then c:log('farm_recall_requested',{cursorID=id,submitted=submitted}) end
    c.status='Recall awaiting confirmation';return true
end
function F:tick()
    local c=self.ctx;self:updateCamps()
    if c.input.farmPaused then c.status='Auto-jungle paused | press '..U.keyLabel(c.config:key('farmKey'));return end
    if self:recovery() then return end
    if self:splitPending(self.camp) and not self:selectTarget(self.camp) then
        c.attackTarget=nil;c.moveTarget=nil;self.state='clearing'
        c.status='Waiting for Krug split';return
    end
    if self.localException then
        local camp=self.known[self.localException];local alive=false
        for _,m in ipairs(camp and camp.members or {}) do
            if m.valid~=false and not m.dead and (m.health or 0)>0 then alive=true;break end
        end
        if not alive and camp and (camp.availability=='observed_empty' or camp.killedAt) then
            self.localException=nil;self.returningHome=true;self.camp=nil;self.opening=nil
        end
    end
    local engaged=false
    for _,m in ipairs(c.minions or {}) do
        if m.team==300 and U.valid(m) and m.health<(m.maxHealth or m.health) and U.dist(myHero.pos,m.pos)<500 then engaged=true;break end
    end
    if c.leveling.pending then return end
    self.actions:followCamera() -- Camera requests must never consume a routing tick.
    if self.returningHome and self.camp and self.camp.team==myHero.team
        and U.dist(myHero.pos,self:walkDestination(self.camp))<650 then self.returningHome=nil end
    if self.camp and P.epics[self.camp.category] then
        self.camp=nil;self.probe=nil;self.travelTarget=nil;self.travelJob=nil
    end
    if self.camp and not self:staging(self.camp) and (c:now()<(self.camp.blockedUntil or 0) or self.camp.availability=='observed_empty' and not self.camp.expectedAt) then
        self.camp=nil;self.progressAt=nil
    end
    -- Vision changes while walking, without another J press. A nearby live
    -- camp takes precedence over a distant route or pending blind probe.
    local home=self:homeAvailable()
    local openingWait=self.camp and self:staging(self.camp)
    local localCamp,distance=nil,650
    for _,known in pairs(self.known) do
        if c:now()>=(known.blockedUntil or 0) and not P.epics[known.category] and self:sideAllowed(known,home)
            and c:threats(known.pos,1000)==0 then
            for _,m in ipairs(known.members or {}) do
                local d=U.dist(myHero.pos,m.pos)
                if self:ordinaryTarget(m) and d<distance then localCamp,distance=known,d end
            end
        end
    end
    local engagedHere=false
    if self.camp and self:hasRemnants(self.camp) and self.camp.lastFoughtAt
        and c:now()-self.camp.lastFoughtAt<3 then engagedHere=true end
    for _,m in ipairs(self.camp and self.camp.members or {}) do
        local attacking=m.attackData and m.attackData.target
        local spell=m.activeSpell
        local us=attacking==myHero.handle or attacking==myHero.networkID
            or spell and spell.valid and (spell.target==myHero.handle or spell.target==myHero.networkID)
        if self:ordinaryTarget(m) and (U.dist(myHero.pos,m.pos)<=c:attackRange(m)+150
            or us or self.camp.lastFoughtAt and c:now()-self.camp.lastFoughtAt<3
                and U.dist(myHero.pos,m.pos)<900) then engagedHere=true;break end
    end
    local finishing=engagedHere and self.camp and self.camp.lastFoughtAt and c:now()-self.camp.lastFoughtAt<2
    if self.camp and not finishing and not self:sideAllowed(self.camp,home) then
        self.camp=nil;self.probe=nil;self.travelTarget=nil;self.travelJob=nil;self.progressAt=nil;engagedHere=false
    end
    local followingOpening=self.opening and self.camp and not self.camp.killedAt
        and self.camp.category==self.opening.order[self.opening.index]
    local currentDistance=math.huge
    for _,m in ipairs(self.camp and self.camp.members or {}) do
        if self:ordinaryTarget(m) then currentDistance=math.min(currentDistance,U.dist(myHero.pos,m.pos)) end
    end
    if localCamp and localCamp~=self.camp and distance+200<currentDistance
        and not (self.camp and self.localException==self.camp.id) and not engagedHere and not openingWait and not followingOpening then
        self.camp=localCamp;self.progressAt=nil;self.probe=nil;self.travelTarget=nil;self.travelJob=nil
        if c.config.capture then c:log('route_visible_anchor',{name=localCamp.category}) end
    end
    if self.camp and (self.camp.expectedAt or self.returningHome) and not engagedHere and not openingWait and c:now()>(self.rerankAt or 0) then
        self.rerankAt=c:now()+1;self.camp=self:choose()
    end
    self.camp=self.camp or self:choose()
    local camp=self.camp
    if not camp then c.status='No eligible camp known: waiting for camp observations';return end
    if P.epics[camp.category] then
        self.camp=nil;c.status='Bosses excluded from auto-jungle';return
    end
    -- Choosing a new camp can happen after this tick's initial recovery check.
    -- Re-evaluate before a same-tick Q entry, not only on the next callback.
    if not engagedHere and U.hp(myHero)<math.min(50,c.config:get('recallHP')*2)
        and self:recovery() then return end
    local selected=self:selectTarget(camp);local best=selected and {unit=selected}
    if selected and U.dist(myHero.pos,selected.pos)<=c:attackRange(selected)+40 then self.probe=nil end
    if self.probe and self:probeCamp(camp) then return end
    if best then
        local targetDistance=U.dist(myHero.pos,best.unit.pos)
        local continuing=camp.lastFoughtAt and c:now()-camp.lastFoughtAt<3 and targetDistance<900
        if not continuing and self:travel(camp,best.unit) then return end
        local localAttack=targetDistance<=650 and U.vector(best.unit.pos):To2D().onScreen~=false
        if not continuing and not localAttack then
            self.state='routing';c.moveTarget=best.unit.pos;c.status='Walking to '..camp.category;return
        end
        if not camp.clearStartedAt then camp.clearStartedAt=c:now();camp.startHealth=U.hp(myHero) end
        self.state='clearing';c.status='Clearing '..(camp.category or 'camp')
        local m=best.unit
        if self.lastCampHP and m.health>self.lastCampHP+200 and self.lastCampTarget==U.id(m)
            and self.lastCampHPAt and c:now()-self.lastCampHPAt<.75 then
            -- Regeneration is a reason to stop pulling, not to repeatedly leave
            -- and reacquire this camp against the same stale health baseline.
            camp.kiteRecoverUntil=c:now()+2;self.kiteStep=nil
            if c.config.capture then c:log('camp_reset',{name=camp.category,previous=self.lastCampHP,
                health=m.health,action='Stop kiting and reengage current camp'}) end
        end
        self.lastCampHP=m.health;self.lastCampTarget=U.id(m);self.lastCampHPAt=c:now();self:clear(m);return
    end
    if self:staging(camp) then
        local destination=self:walkDestination(camp)
        self.state='staging';c.status='Opening camp: '..camp.category..' | '..(U.dist(myHero.pos,destination)>220 and 'walking before spawn' or 'waiting for spawn')
        if U.dist(myHero.pos,destination)>220 then c.moveTarget=destination end
        return
    end
    if camp.expectedAt and camp.availability~='observed_alive' then
        local wait=math.max(0,camp.expectedAt-c:now())
        if wait==0 and self:probeCamp(camp) then return end
        self.state='respawn';c.status=wait>0 and string.format('Next %s | respawn ~%.0fs [%s]',camp.category,wait,camp.timerSource or 'estimate')
            or 'Next '..camp.category..' | estimated timer elapsed; spawn unconfirmed'
        if U.dist(myHero.pos,self:walkDestination(camp))>220 then c.moveTarget=self:walkDestination(camp)
        elseif wait==0 then
            camp.arrivedAt=camp.arrivedAt or c:now()
            if c:now()-camp.arrivedAt>5 then
                camp.blockedUntil=c:now()+15;camp.arrivedAt=nil;self.camp=nil
            end
        end
        return
    end
    if self:probeCamp(camp) then return end
    if U.dist(myHero.pos,self:walkDestination(camp))<250 then
        camp.arrivedAt=camp.arrivedAt or c:now()
        if c:now()-camp.arrivedAt>1.3 then
            camp.availability='observed_empty';camp.emptyObservedAt=c:now();camp.blockedUntil=c:now()+20;camp.arrivedAt=nil
            if c.config.capture then c:log('camp_empty',{name=camp.category}) end;self.camp=nil
        end
        return
    end
    camp.arrivedAt=nil;self.state='routing';c.status='Routing: '..(camp.category or camp.id)..' ['..camp.availability..']'
    c.moveTarget=self:walkDestination(camp)
    if self.progressCamp~=camp.id then self.progressCamp=camp.id;self.progressAt=nil end
    if not self.progressAt or U.dist(myHero.pos,self.progressPos)>60 then self.progressAt=c:now();self.progressPos=U.copy(myHero.pos)
    elseif c:now()-self.progressAt>4 then
        camp.blockedUntil=c:now()+20;self.camp=nil;self.progressAt=nil;if c.config.capture then c:log('route_stalled') end
    end
end
-- Formation estimates are separate from availability. A camp icon is never
-- used as a monster position, and known deaths veto every estimated shot.
function F:rememberLayout(camp)
    if #(camp.members or {})==0 then return end
    local rows={};local c=self.ctx
    for _,m in ipairs(camp.members) do
        if not U.valid(m) or m.health<(m.maxHealth or m.health) or m.pathing and m.pathing.hasMovePath then
            camp.layout=nil;return
        end
        rows[#rows+1]={unit=m,pos=U.copy(m.pos),health=m.health,maxHealth=m.maxHealth,
            radius=m.boundingRadius or 45,at=c:now()}
    end
    camp.layout={rows=rows,at=c:now(),mode=c.profile.id,mapID=Game.mapID}
    local counts=c.profile.id=='classic' and {Red=3,Blue=3,Wolves=3,Wraiths=4,Golems=2,Wight=1}
        or {Red=1,Blue=1,Wolves=3,Raptors=6,Krugs=2,Gromp=1}
    if #rows==counts[camp.category] then
        local saved={}
        for _,row in ipairs(rows) do saved[#saved+1]={pos=U.copy(row.pos),health=row.health,
            maxHealth=row.maxHealth,radius=row.radius,name=row.unit.charName} end
        camp.spawnLayout={rows=saved,at=c:now(),mode=c.profile.id,mapID=Game.mapID}
    end
end
function F:entryAvailable(camp)
    if camp.nativeUp==false then return false end
    if not camp.awaitingRespawn then return true end
    -- A timer can authorize an explicitly estimated probe, never an alive
    -- observation. Stale native true alone cannot erase our recorded kill.
    return self.ctx.config:get('farmQRespawn') and camp.nativeUp==true and camp.expectedAt
        and self.ctx:now()>=camp.expectedAt+.25 and not (camp.probeMissedAt and camp.probeMissedAt>=(camp.killedAt or 0))
end
function F:entryDiagnostic(camp,reason)
    local c=self.ctx;local distance=U.dist(myHero.pos,self:walkDestination(camp))
    self.entryDecision={camp=camp.id,reason=reason,distance=distance,at=c:now()}
    if distance>c.profile.qRange+150 or c:now()<(self.entryLogAt or 0) then return end
    self.entryLogAt=c:now()+1
    if c.config.capture then c:log('camp_entry_decision',{camp=camp.id,reason=reason,distance=distance,rank=c:spell(0).level,
        cd=c:spell(0).currentCd,energy=myHero.mana,nativeUp=camp.nativeUp,waiting=camp.awaitingRespawn,
        expectedAt=camp.expectedAt,source=self.entryCandidateCamp==camp.id and self.entrySource or nil,
        targets=self.entryCandidateCamp==camp.id and self.entryCandidates or nil}) end
end
function F:fogLayout(camp)
    local c=self.ctx
    if camp.nativeUp~=true or not self:entryAvailable(camp) or camp.availability=='observed_empty' and not camp.awaitingRespawn
        or camp.lastFoughtAt and c:now()-camp.lastFoughtAt<20 then return end
    local layout=camp.layout
    if layout and (layout.mode~=c.profile.id or layout.mapID~=Game.mapID) then return end
    if layout and layout.mode==c.profile.id and layout.mapID==Game.mapID and c:now()-layout.at<=30 then
        for _,row in ipairs(layout.rows) do
            local m=row.unit
            if not m or m.dead or m.valid==false or (m.health or 0)<row.health
                or m.pathing and m.pathing.hasMovePath or U.dist(m.pos,row.pos)>15 then return end
        end
        return layout.rows,'recent stationary observation'
    end
    layout=camp.spawnLayout
    if layout and layout.mode==c.profile.id and layout.mapID==Game.mapID then return layout.rows,'learned spawn estimate' end
    local recorded=require(c.profile.id=='normal' and 'lho.normalcampobservations' or 'lho.campobservations')
    if recorded.mode==c.profile.id and recorded.mapID==Game.mapID then
        local saved=recorded.camps[camp.id]
        if saved then return saved.rows,'recorded spawn estimate' end
    end
end
function F:qEntryUpper(m)
    local c=self.ctx;local rank=c:spell(0).level or 0
    if rank<=0 then return false end
    local bonus=myHero.bonusDamage or math.max(0,(myHero.totalDamage or 0)-(myHero.baseDamage or 0))
    local raw=(c.profile.qBase[rank] or 0)+c.profile.qRatio*bonus
    -- Upper-side estimate: never use a disabled/unverified damage overlay's
    -- zero as proof that a small monster will survive. Ignore monster caps.
    local damage=raw
    if m then
        local ok;ok,damage=pcall(c.sdk.Damage.CalculateDamage,c.sdk.Damage,myHero,m,c.sdk.DAMAGE_TYPE_PHYSICAL,raw)
        if not ok or type(damage)~='number' or damage~=damage or math.abs(damage)==math.huge then return end
    end
    local upper=math.max(raw,damage)
    -- Classic Butcher amplifies spell damage too. Source: pinned 16.17.1
    -- Pinned mode item data. Use the strongest unique passive, not their sum.
    if c.profile.id=='classic' then
        local amps=c.profile.qMonsterAmplifiers;local multiplier=1
        local shared=c.sdk.SharedData;local inventory=shared and shared:GetInventory()
        for slot=6,11 do
            local item=inventory and inventory.ageMs<=80 and inventory.slots[slot] or myHero:GetItemData(slot)
            multiplier=math.max(multiplier,item and amps[item.itemID] or 1)
        end
        upper=upper*multiplier
    end
    if c.profile.q1DataMap and c.profile.q1DataMap==Game.mapID then upper=upper*1.1
    elseif not c.profile.damageVerified and not c.config:get('mechanicsVerified') then upper=upper*2 end
    return upper+25
end
function F:qSurvives(m,delay,health)
    local c=self.ctx;local upper=self:qEntryUpper(m)
    if not upper then return false end
    local hp=health or math.min(m.health,c:healthAt(m,delay))
    return hp>upper
end
function F:entryShot(camp,origin,fog)
    local c=self.ctx;origin=origin or myHero.pos
    self.entryCandidates=c.config.capture and {};self.entrySource=nil;self.entryCandidateCamp=camp.id
    if P.epics[camp.category] or not self:entryAvailable(camp) then return end
    local rows,source={}
    if fog then
        rows,source=self:fogLayout(camp);self.entrySource=source
        if not rows then self.entryShotReason='No eligible formation for this camp / spawn state';return end
    else
        for _,m in ipairs(camp.members or {}) do if self:ordinaryTarget(m) then
            rows[#rows+1]={unit=m,pos=m.pos,radius=m.boundingRadius or 45,maxHealth=m.maxHealth}
        end end
    end
    local best,bestScore,bestHealth
    for _,row in ipairs(rows) do
        local m=row.unit;local aim=row.pos;local distance=U.dist(origin,aim)
        local inRange=distance<=c.profile.qRange
        local delay=.25+distance/c.profile.qSpeed+c.latency
        -- A distant candidate cannot be selected. Avoid damage, inventory,
        -- health prediction and collision host calls until it enters Q range.
        local upper=inRange and self:qEntryUpper(m) or nil
        local hp=inRange and (fog and row.health or m and math.min(m.health,c:healthAt(m,delay))) or nil
        local survives=upper and hp and hp>upper
        local report=c.config.capture and {name=row.name or m and m.charName,health=hp,upper=upper,distance=distance}
        if report then
            self.entryCandidates[#self.entryCandidates+1]=report
            report.reason=not inRange and 'Out of Q range' or not survives and 'Q1 survival reserve' or 'Collision'
        end
        if survives then
            local clear=#c.spells:blockers(m,aim,origin)==0
            for _,other in ipairs(rows) do if other~=row then
                local distance,t=U.segment(other.pos,origin,aim)
                local uncertainty=fog and 25 or 0
                if t>0 and t<1 and distance<c.profile.qRadius+other.radius+uncertainty then clear=false;break end
            end end
            if clear then
                local score=U.dist(origin,aim);local health=row.maxHealth or row.health or m.health
                if report and score<=c.profile.qRange then report.reason='Eligible' end
                if score<=c.profile.qRange and (not bestHealth or health>bestHealth or health==bestHealth and score<bestScore) then
                    best,bestScore,bestHealth=row,score,health
                end
            end
        end
    end
    if best then best.source=source or 'visible monster' end
    self.entryShotReason=best and 'Clear surviving target found' or 'No clear surviving target in Q range'
    return best
end
function F:walkDestination(camp)
    -- Camp icon/manager coordinates may sit beside the monsters or have no
    -- ground height. Prefer a live member's actual world position for walking.
    local main
    for _,m in ipairs(camp.members or {}) do
        if self:ordinaryTarget(m) and (not main or (m.maxHealth or m.health)>(main.maxHealth or main.health)) then main=m end
    end
    return main and main.pos or camp.walkPos or camp.pos
end
function F:travel(camp,target)
    local c=self.ctx;local now=c:now()
    if camp.nativeUp==false or camp.awaitingRespawn or (c:spell(0).level or 0)==0 or P.epics[camp.category] or not c.config:get('farmQTravel') or not c.config:get('autoClearAbilities') or not c.config:get('autoClearQ')
        or not c.config:get('autoClearQ2') or c:dash() or c:threats(camp.pos,1000)>0 or c:underTurret(camp.pos) then
        self.travelTarget=nil;self.travelJob=nil;return false
    end
    if U.dist(myHero.pos,target.pos)<=c:attackRange(target)+40 then
        self.travelTarget=nil;self.travelJob=nil;return false
    end
    if self.travelTarget then
        local found=false
        for _,m in ipairs(camp.members or {}) do
            if U.valid(m) and c:mark(m) then
                found=true
                if c.spells:q2(m,'farm',false,true,true) then self.travelTarget=nil;self.travelJob=nil;if c.config.capture then c:log('camp_q2_entry') end;return true end
            end
        end
        if now>(self.travelUntil or 0) or not U.valid(self.travelTarget) then self.travelTarget=nil
        elseif found or c:stage(0)==1 then c.moveTarget=self:walkDestination(camp);return true
        else self.travelTarget=nil end
    end
    if not c:ready(0) or c:stage(0)~=1 then return false end
    -- If the selected visible monster is already quicker to reach on a clear
    -- walking line, skip expensive formation damage/collision enumeration.
    -- Pending Q follow-ups above still run; a wall preserves the entry search.
    if U.dist(myHero.pos,target.pos)<=650 and not self:entryFaster(target.pos)
        and self:kiteLine(myHero.pos,target.pos) then return false end
    -- Seeing an outer small monster must not disable the earlier, durable
    -- main-monster shot from the same camp's recorded formation.
    if c.config:get('farmQBlind') then
        local fogShot=self:entryShot(camp,myHero.pos,true)
        if fogShot and not U.valid(fogShot.unit) and self:probeCamp(camp) then return true end
    end
    local shot=self:entryShot(camp)
    if shot and self:entryFaster(shot.pos) and U.dist(myHero.pos,shot.pos)<=c.profile.qRange and c.spells:q1(shot.unit,'farm',false,function()
        return self:entryAvailable(camp) and self:qSurvives(shot.unit,
            .25+U.dist(myHero.pos,shot.unit.pos)/c.profile.qSpeed+c.latency),'entry_target_may_die'
    end) then
        self.travelTarget=shot.unit;self.travelUntil=now+2;c.moveTarget=self:walkDestination(camp)
        if c.config.capture then c:log('camp_q1_entry',{target=U.id(shot.unit),name=shot.unit.charName,
            health=shot.unit.health,upper=self:qEntryUpper(shot.unit),camp=camp.id,source=shot.source}) end
        return true
    end
    -- Reposition around small blockers for a durable target, instead of firing
    -- a travel Q that would kill its first collision and remove the recast.
    local durable
    for _,m in ipairs(camp.members or {}) do
        if U.valid(m) and self:qSurvives(m,1) and (not durable or m.maxHealth>durable.maxHealth) then durable=m end
    end
    return durable and self:entryPath(camp,durable) or false
end
function F:entryFaster(destination,origin)
    local c=self.ctx;origin=origin or myHero.pos
    local distance=U.dist(origin,destination)
    local walk=math.max(0,U.dist(myHero.pos,destination)-250)/math.max(1,myHero.ms or 350)
    local jump=U.dist(myHero.pos,origin)/math.max(1,myHero.ms or 350)+.25+distance/c.profile.qSpeed+distance/1800+c.latency
    return jump+.08<walk
end
function F:entryPath(camp,target)
    local c=self.ctx;local now=c:now()
    -- Opportunistic micro-adjustments only. The normal route remains one
    -- native click to the camp, never a separate stop at the Q range boundary.
    if self.returningHome or not c.config:get('farmQAdjust') or not c.terrain:trusted() or not c:ready(0) or c:stage(0)~=1 then
        self.travelJob=nil;return false
    end
    if U.dist(myHero.pos,camp.pos)>c.profile.qRange+90 then return false end
    local job=self.travelJob
    if job then
        if job.camp==camp.id and now<job.deadline and U.dist(myHero.pos,job.pos)>25 then
            c.moveTarget=job.pos;return true
        end
        self.travelJob=nil;self.microRetryAt=now+.5
        -- Never stop at an old aim point when the shot has become invalid.
        c.moveTarget=self:walkDestination(camp);return false
    end
    if now<(self.microRetryAt or 0) then return false end
    local toward=U.toward(myHero.pos,camp.pos,1)
    local dx,dz=toward.x-myHero.pos.x,toward.z-myHero.pos.z
    for _,offset in ipairs({45,-45,90,-90}) do
        local point={x=myHero.pos.x-dz*offset,y=myHero.pos.y,z=myHero.pos.z+dx*offset}
        if c.terrain:walkLine(myHero.pos,point,math.min(45,myHero.boundingRadius or 35)) then
            local shot=self:entryShot(camp,point,target==nil)
            if shot and U.dist(point,shot.pos)<=c.profile.qRange and self:entryFaster(shot.pos,point) then
                self.travelJob={camp=camp.id,pos=point,deadline=now+.6};c.moveTarget=point
                c.status='Small Q aim adjustment: '..camp.category;return true
            end
        end
    end
    return false
end
function F:probeCamp(camp)
    local c=self.ctx;local now=c:now()
    if not self:entryAvailable(camp) or (c:spell(0).level or 0)==0 or not c.config:get('farmQTravel') or not c.config:get('farmQBlind') or not c.config:get('autoClearAbilities')
        or not c.config:get('autoClearQ') or not c.config:get('autoClearQ2') or c:dash()
        or P.epics[camp.category] or c:threats(camp.pos,1000)>0 or c:underTurret(camp.pos) then
        self:entryDiagnostic(camp,not self:entryAvailable(camp) and 'Spawn not eligible for a probe'
            or (c:spell(0).level or 0)==0 and 'Q not learned' or 'Entry disabled or unsafe')
        self.probe=nil;return false
    end
    local probe=self.probe
    if probe and probe.camp~=camp.id then self.probe=nil;probe=nil end
    if probe and c.actions.syncWindow then
        local state=c.actions:syncWindow(probe)
        if state=='waiting' or state=='uncertain' then c.status='Waiting for Q input';return true end
        if state=='cancelled' then self.probe=nil;self.travelJob=nil;return false end
    end
    if probe then
        -- Fresh object enumeration avoids the camp grouping's 400 ms cache
        -- delaying a confirmed Q2. Never dash to a champion hit by the probe.
        if Game.MinionCount and Game.Minion then for i=1,U.count(Game.MinionCount(),4096) do
            local m=Game.Minion(i)
            if U.valid(m) and m.team==300 and U.dist(m.pos,camp.pos)<700 and c:mark(m) then
                local found=false;camp.members=camp.members or {}
                for _,known in ipairs(camp.members) do if U.same(known,m) then found=true;break end end
                if not found then camp.members[#camp.members+1]=m end
                if camp.awaitingRespawn then self:respawnObserved(camp,now) end
                camp.availability='observed_alive';camp.observedAt=now
                if c.spells:q2(m,'farm',false,true,true) then self.probe=nil;self.travelJob=nil;if c.config.capture then c:log('camp_probe_confirmed',{name=camp.category}) end;return true end
            end
        end end
        if now<=probe.deadline then c.moveTarget=self:walkDestination(camp);c.status='Walking / waiting for camp Q mark: '..camp.category;return true end
        self.probe=nil;self.travelJob=nil
        local visible=false;for _,m in ipairs(camp.members or {}) do if U.valid(m) then visible=true end end
        if not visible then
            camp.availability='unknown';camp.blockedUntil=now+20;camp.probeMissedAt=now;self.camp=nil;self.progressAt=nil
            c.status='Camp probe missed; selecting next camp';if c.config.capture then c:log('camp_probe_missed',{name=camp.category}) end;return true
        end
        if c.config.capture then c:log('camp_probe_missed_visible',{name=camp.category}) end;return false
    end
    if not c:ready(0) or c:stage(0)~=1 or camp.availability=='observed_empty' and not camp.awaitingRespawn then
        self:entryDiagnostic(camp,'Q unavailable / stage / empty camp');return false
    end
    local shot=self:entryShot(camp,myHero.pos,true)
    if not shot then self:entryDiagnostic(camp,self.entryShotReason or 'No eligible shot');return self:entryPath(camp) end
    local aim=U.copy(shot.pos)
    local route=self.camp
    if self:entryFaster(aim) and c.spells:q1Camp(aim,function()
        -- Camp observations, routing and menu changes can invalidate a fog
        -- probe while the input owner is busy. Do not shoot the old intent.
        if self.camp~=route or not self:entryAvailable(camp) or camp.availability=='observed_empty' and not camp.awaitingRespawn
            or not c.config:get('farmQTravel')
            or not c.config:get('farmQBlind') or not c.config:get('autoClearQ2')
            or c:threats(camp.pos,1000)>0 or c:underTurret(camp.pos) then return false,'camp_entry_changed' end
        return true
    end) then
        self.probe={camp=camp.id,aim=aim,event=c.actions.pending[0],deadline=now+.25+U.dist(myHero.pos,aim)/c.profile.qSpeed+math.max(.4,c.latency*2+c.jitter*3+.2)}
        c.status='Q approach: '..camp.category..' ['..shot.source..(camp.awaitingRespawn and '; respawn estimated' or '')..']'
        self:entryDiagnostic(camp,'Q probe requested')
        if c.config.capture then c:log('camp_probe_requested',{name=camp.category,origin=U.copy(myHero.pos),destination=aim,
            source=shot.source,respawnEstimate=camp.awaitingRespawn or false,
            targetName=shot.name or shot.unit and shot.unit.charName,distance=U.dist(myHero.pos,aim)}) end;return true
    end
    self:entryDiagnostic(camp,not self:entryFaster(aim) and 'Walking is faster from current position' or 'Q dispatch / visible collision blocked')
    return self:entryPath(camp)
end
function F:fastTick()
    local c=self.ctx;local camp=self.camp
    if self.recallAction or self.state=='recalling' or not camp or not self:entryAvailable(camp) or P.epics[camp.category] or not (self.probe or self.travelTarget) or c.input.farmPaused or not c.config:get('autoJungle')
        or not c.config:get('farmQTravel') or not c.config:get('autoClearAbilities') or not c.config:get('autoClearQ2')
        or self.probe and not c.config:get('farmQBlind') or c:threats(camp.pos,1000)>0
        or c:blocked() or c:recalling() or c:dash() then return false end
    self.actions:tick()
    if Game.MinionCount and Game.Minion then for index=1,U.count(Game.MinionCount(),4096) do
        local m=Game.Minion(index)
        if U.valid(m) and m.team==300 and U.dist(m.pos,camp.pos)<700 and c:mark(m) then
            if camp.awaitingRespawn then self:respawnObserved(camp,c:now()) end
            if c.spells:q2(m,'farm',false,true,true) then
                self.probe=nil;self.travelTarget=nil;self.travelJob=nil
                if c.config.capture then c:log('camp_q2_entry',{target=U.id(m),immediate=true}) end;return true
            end
        end
    end end
    return false
end
require('lho.recovery')(F)
return F

end
modules["lho.forecast"] = function(require)
-- Input-free, bounded search. Actions describe legal transitions, not named combos.
-- Times are conservative impact boundaries; projectile flight is not treated as
-- a free extra attack. Only the already observed attack may overlap a spell.
local F={}
local function copy(s)
    local n={};for k,v in pairs(s) do n[k]=v end
    n.used={};for k,v in pairs(s.used) do n.used[k]=v end
    return n
end
local function hit(s,damage,kind)
    local shield=kind=='magic' and 'magic' or kind=='physical' and 'physical'
    if shield then local use=math.min(s[shield],damage);s[shield]=s[shield]-use;damage=damage-use end
    local use=math.min(s.shield,damage);s.shield=s.shield-use
    s.hp=math.max(0,s.hp-damage+use)
end
local function advance(s,t,model)
    if model.pending and not s.pendingDone and model.pending.at<=t then
        local at=math.max(s.t,model.pending.at)
        s.hp=math.min(model.maxHP,s.hp+model.regen*(at-s.t));s.t=at
        hit(s,model.pending.damage,'physical');s.pendingDone=true
        if s.hp<=0 then return end
    end
    s.hp=math.min(model.maxHP,s.hp+model.regen*math.max(0,t-s.t));s.t=t
end
local function better(a,b,model)
    if not b then return true end
    local al,bl=a.hp<=0,b.hp<=0
    if al~=bl then return al end
    if al then
        -- Inside the allowed survival/escape window, save resources first.
        if a.cost~=b.cost then return a.cost<b.cost end
        return a.t<b.t
    end
    local function score(s)
        return (model.hp-s.hp+s.utility)/math.max(.25,s.t)-s.cost*model.resourceWeight
    end
    return score(a)>score(b)
end
function F.solve(model)
    local root={hp=model.hp,shield=model.shield or 0,physical=model.physical or 0,magic=model.magic or 0,
        energy=model.energy,t=0,cost=0,utility=0,used={},autos=0,aaAt=model.aaAt or 0,
        distance=model.distance,mark=model.mark or 0,conditional=false}
    local frontier={root};local best,lethal,expanded=nil,nil,0
    local width=model.width or 8;local limit=model.limit or 192
    for depth=1,model.depth or 6 do
        local nextLevel={}
        for _,node in ipairs(frontier) do
            for _,a in ipairs(model.actions) do
                if expanded>=limit then break end
                expanded=expanded+1
                if (a.repeatable or not node.used[a.id]) and (a.energy or 0)<=node.energy then
                    local delay=a.delay(node)
                    if delay and delay>=0 and node.t+delay<=model.horizon then
                        local n=copy(node);local finish=node.t+delay
                        advance(n,finish,model)
                        if n.hp>0 then
                            local amount=a.damage and a.damage(n) or 0
                            hit(n,math.max(0,amount),a.kind)
                            n.energy=n.energy-(a.energy or 0);n.cost=n.cost+(a.cost or 0)
                            n.utility=n.utility+(a.utility or 0);n.used[a.id]=true
                            n.first=n.first or a.id;n.firstAt=n.firstAt or node.t
                            n.path=(n.path and n.path..' > ' or '')..a.id
                            if a.apply then a.apply(n,node,delay) end
                        end
                        if better(n,best,model) then best=n end
                        if n.hp<=0 and not n.conditional and better(n,lethal,model) then lethal=n end
                        if n.hp>0 then
                            -- Keep a small ordered beam; no global sort or unbounded graph.
                            local at=#nextLevel+1
                            for j,v in ipairs(nextLevel) do if better(n,v,model) then at=j;break end end
                            if at<=width then table.insert(nextLevel,at,n);if #nextLevel>width then table.remove(nextLevel) end end
                        end
                    end
                end
            end
            if expanded>=limit then break end
        end
        frontier=nextLevel
        if #frontier==0 or expanded>=limit then break end
    end
    -- An observed lethal attack needs no additional command at all.
    if model.pending and model.pending.at<=model.horizon then
        local wait=copy(root);advance(wait,model.pending.at,model)
        if wait.hp<=0 and better(wait,lethal,model) then lethal=wait;best=wait end
    end
    return {best=best,lethal=lethal,expanded=expanded,horizon=model.horizon}
end
return F

end
modules["lho.ggbridge"] = function(require)
-- Local signature adapter, not an SDK replacement. All scheduling is ActionClient's.
return function(c)
    local create=require('ActionClient')
    local client=create(_G,{name='LHO',active=function()return not c.ggClosed end})
    local caps=client:Capabilities()
    caps.resolveBeforeHandoff=true -- Not cursor-phase resolveWorldTarget support.
    local api={version=1,provider='OriginalGG',client=client}
    local scope={id=client.id}
    function api:Now()return client:Now()end
    function api:GetCapabilities()return caps end
    function api:RegisterScope()return scope end
    function api:GetAvailability()
        local available=client:Available()
        return {available=available,busy=not available,uncertain=false,cleanupPending=not available}
    end
    function scope:GetAction(id)
        local r=client:Poll(id);local q=client.jobs[id]
        if r and q then r.expires=q.expires end
        return r
    end
    function scope:Request(q)
        -- No private cursor control, hover verification, handoffs or modifier input.
        if q.type~='cast' and q.type~='attack' and q.type~='move' then return nil,'GG_unsupported_type:'..tostring(q.type)end
        if q.targetKind=='screen' then return nil,'GG_screen_transport_unavailable'end
        for _,name in ipairs({'verifyTarget','handoff','aimCandidates','aimFallback','dependency'})do
            if q[name] then return nil,'GG_unsupported_option:'..name end
        end
        local slot=q.resource and tonumber(q.resource:match('^slot:(%d+)$'))
        local modes={fight={'COMBO'},harass={'HARASS'},clear={'LANECLEAR','JUNGLECLEAR'},gg_last={'LASTHIT'}}
        local origin=require('lho.intent').origin(c,q.owner)
        local names=modes[origin];local context
        if names then
            context={modes={}}
            for _,name in ipairs(names)do context.modes[#context.modes+1]=c.sdk['ORBWALKER_MODE_'..name] end
        end
        return client:Submit{type=q.type,kind=q.targetKind,target=q.target,keys=q.keys,
            owner=q.owner,priority=q.priority,expires=q.expires,targetID=q.intentTargetID,
            resource=q.resource,resolve=q.resolveWorldTarget,context=context,
            mechanical=function(resolved)return not c:blocked() and (not q.validate or q.validate(nil,resolved))end,
            reconcile=function()
                local active=myHero.activeSpell
                return not c:blocked() and (not active or not active.valid)
                    and (slot==nil or c:ready(slot))
            end}
    end
    function scope:Cancel(id,reason)return client:Cancel(id,reason)end
    function scope:CancelOwner(owner,reason)return client:CancelOwner(owner,reason)end
    function scope:Observe(id,evidence)return client:Observe(id,evidence)end
    function scope:Close(reason)c.ggClosed=true;return client:Close(reason)end
    function api:Pump(actions)
        -- Consume only results whose gameplay observation is no longer pending.
        local retained={}
        for _,event in pairs(actions.pending)do if event.cursorID then retained[event.cursorID]=true end end
        for _,lock in pairs(actions.slotUncertainty or {})do
            if lock.event.cursorID then retained[lock.event.cursorID]=true end
        end
        for _,id in pairs(actions.keyRequests)do retained[id]=true end
        for id in pairs(client.jobs)do
            if not retained[id]then
                local r=client:Poll(id)
                if r and (r.mechanical or r.state=='cancelled_before_send')then client:Finish(id)
                else client:Reconcile(id)end
            end
        end
        local previous=c.synthetic;c.synthetic=true
        local ok,why=pcall(client.Tick,client)
        c.synthetic=previous
        if not ok then error(why)end
    end
    return api
end

end
modules["lho.ground"] = function(require)
-- Ground clicks are contextual inputs. Keep their endpoint off visible bodies.
-- This geometric guard is conservative; it is not pixel-perfect hover proof.
local U=require('lho.util')
local G={}
function G.blocker(c,pos,scene)
    return G.screenBlocker(c,U.vector(pos):To2D(),nil,scene)
end
function G.scene(c)
    local resolution=Game.Resolution and Game.Resolution()
    local scale=math.max(.75,math.min(3,(resolution and resolution.y or 1080)/1080))
    local seen,scene={},{}
    for _,list in ipairs({c.minions or {},c.heroes or {},c.turrets or {},c.wardObjects or {}}) do
        for _,m in ipairs(list) do
            local id=U.id(m)
            if id and not seen[id] and not U.same(m,myHero) and U.valid(m) then
                seen[id]=true
                local q=U.vector(m.pos):To2D()
                if q and q.onScreen~=false then
                    local radius=math.max(25,m.boundingRadius or 45)
                    local edge=U.vector({x=m.pos.x+radius,y=m.pos.y,z=m.pos.z}):To2D()
                    local width=math.max(18*scale,edge and math.abs(edge.x-q.x) or 0)
                    -- Model silhouettes extend upward from ground projection.
                    scene[#scene+1]={unit=m,x=q.x,width=width+8*scale,top=q.y-100*scale,bottom=q.y+width*.5+8*scale}
                end
            end
        end
    end
    return scene
end
function G.screenBlocker(c,p,ignore,scene)
    if not p or p.onScreen==false then return nil end
    -- A scene is shared only within this synchronous candidate search. Final
    -- input validation calls without it, projecting the current scene afresh.
    for _,row in ipairs(scene or G.scene(c)) do
        if not U.same(row.unit,ignore) and math.abs(p.x-row.x)<=row.width and p.y>=row.top and p.y<=row.bottom then return row.unit end
    end
end
function G.select(c,pos)
    local scene=G.scene(c)
    if not G.blocker(c,pos,scene) then return U.copy(pos) end
    local distance=U.dist(myHero.pos,pos);if distance<1 then return nil,'ground_direction_missing' end
    local radius=myHero.boundingRadius or 35
    local kite=c.mode=='farm' and c.farm and c.farm.kiteStep
    local camp=kite and c.farm.camp
    -- Bounded extension on the same unobstructed ray. Never ask native
    -- pathfinding to get around a wall merely to obtain an empty click point.
    for _,extra in ipairs({80,160,240,320}) do
        local p=U.toward(myHero.pos,pos,distance+extra)
        local outward=kite and kite.phase=='out'
        local inside=outward or not camp or not camp.kiteCenter or U.dist(p,camp.kiteCenter)<=c.config:get('farmKiteLeash')
        local clear=outward and c.farm:kiteLine(myHero.pos,p) or not outward and c.terrain:walkLine(myHero.pos,p,radius)
        if inside and U.vector(p):To2D().onScreen and clear
            and not G.blocker(c,p,scene) then return p end
    end
    -- If the ray is occupied or meets terrain, search nearby empty rays. Keep
    -- manual intent generally forward; an outward kite must increase separation.
    local dx,dz=(pos.x-myHero.pos.x)/distance,(pos.z-myHero.pos.z)/distance
    local target=kite and kite.phase=='out' and camp and camp.focus
    local separation=target and U.dist(myHero.pos,target.pos)
    for _,angle in ipairs({.35,-.35,.7,-.7,1.05,-1.05}) do
        local x,z=dx*math.cos(angle)-dz*math.sin(angle),dx*math.sin(angle)+dz*math.cos(angle)
        for _,length in ipairs({300,220,140,80}) do
            local p={x=myHero.pos.x+x*length,y=myHero.pos.y,z=myHero.pos.z+z*length}
            local inside=not camp or not camp.kiteCenter or U.dist(p,camp.kiteCenter)<=c.config:get('farmKiteLeash')
            local useful=target and U.dist(p,target.pos)>separation+15
                or not target and U.dist(p,pos)<distance
            if useful and inside and U.vector(p):To2D().onScreen and c.terrain:walkLine(myHero.pos,p,radius)
                and not G.blocker(c,p,scene) then return p end
        end
    end
    return nil,'ground_click_occupied'
end
return G

end
modules["lho.guide"] = function(require)
-- Interactive help edits the same settings as the native menu.
local U=require('lho.util')
local Links=require('lho.guidelinks')
local UI=require('lho.guideui')
local G={};G.__index=G
G.titles={'Quick start','Wardjump: tap','Wardjump: plan','Insec: controls','Insec: team & turret',
    'Insec: preview','Combo & chase','Harass & assists','Lane & jungle clear','Auto-jungle',
    'Smite & objectives','Items & leveling','Drawings & settings'}
function G.new(ctx) return setmetatable({ctx=ctx,down={}},G) end
function G:modeKey(name)
    local sdk=self.ctx.sdk;local orb=sdk.Orbwalker or {};local id=sdk['ORBWALKER_MODE_'..name]
    local list=id and orb.MenuKeys and orb.MenuKeys[id];local labels,seen={},{}
    for _,node in ipairs(list or {}) do
        local key=node.Key and node:Key()
        if key and key~=0 and not seen[key] then labels[#labels+1]=U.keyLabel(key);seen[key]=true end
    end
    return #labels>0 and table.concat(labels,' / ') or 'see orbwalker menu'
end
function G:page(index)
    local c=self.ctx;local cfg=c.config
    local function key(name)return U.keyLabel(cfg:key(name))end
    local function state(name)return cfg:get(name) and 'ON' or 'OFF'end
    local ward,preview=key('wardKey'),key('insecPreviewKey')
    local pages={
        {'Current bindings and active assists',{
            {'STANDARD MODES','Combo: '..self:modeKey('COMBO')..'   |   Harass: '..self:modeKey('HARASS')..'\nLane clear: '..self:modeKey('LANECLEAR')..'\nJungle clear: '..self:modeKey('JUNGLECLEAR')..'   |   Last hit: '..self:modeKey('LASTHIT')},
            {'LEE SIN','Wardjump: '..ward..'   |   Q1 assist: '..key('qAssistKey')..'\nCursor Insec: '..key('cursorKey')..'   |   Team Insec: '..key('allyKey')..'\nInsec preview: also hold '..preview..'.'},
            {'BACKGROUND','Auto-jungle: '..key('autoJungleKey')..' ['..state('autoJungle')..']\nAutosmite: '..key('smiteKey')..' ['..state('autosmite')..']\nOpening this guide does not pause gameplay or assists.'}},
            'Change these keys under Guide > Key bindings or in the matching feature menu.'},
        {'Jump directly toward your cursor',{
            {'01  AIM','Place your cursor on clear ground within reach. Tap and release '..ward..'. A straightforward jump needs no minimum hold time.'},
            {'02  JUMP','Lee reuses a suitable nearby W target when possible. Otherwise, he places an available ward and follows with W. W1, energy, range and a valid target must all be available.'},
            {'03  FOLLOW THROUGH','Right-click cancels remaining wardjump steps. "Move toward cursor after jump" ['..state('wardFollowCursor')..'] sends one movement command toward your latest cursor position after the jump.'}},
            'Tap for a direct jump. At a wall, wait for a valid preview first.'},
        {'Prepare one jump with wall assistance or an approach',{
            {'HOLD TO PLAN','Hold '..ward..' and aim at the wall you want to cross. Green means a direct jump; yellow means a valid assisted landing or approach. Do not confirm a red preview or "planning".'},
            {'RELEASE TO COMMIT','Releasing accepts the shown plan if it is still valid. Approach assistance ['..state('wardApproach')..'] lets Lee walk into range first. A briefly occupied cursor can make that one request wait.'},
            {'RE-AIM OR CANCEL','Before ward placement, holding again replans. After the ward input was sent, pressing again continues that same jump. Right-click cancels. Only one jump is queued at a time.'}},
            'Changed terrain conditions, unavailable W or an invalid ward can stop the plan. Success is not guaranteed.'},
        {'Choose the target and where to kick it',{
            {'CURSOR INSEC  '..key('cursorKey'),'Select an enemy with the orbwalker, then hold this key. Your cursor sets the kick direction. If mouse fallback is enabled, an enemy near the cursor can be used when nothing is selected.'},
            {'MOVE OR CANCEL','Right-click still controls movement while you hold Insec. The intention stays active and replans from your new position. Releasing the Insec key cancels the remaining steps.'},
            {'LOCK THE DIRECTION','"Lock kick direction" can lock on press, when the approach commits, or keep tracking until the kick. Current choice: '..({'on press','when the approach commits','track until the kick'})[cfg:get('aimLock') or 2]..'. Keep holding while waiting for a valid plan.'}},
            'The kick arrow shows where the enemy will travel.'},
        {'Team Insec  '..key('allyKey'),{
            {'FRIENDLY TURRETS','Turret priority ['..state('insecPreferStructures')..'] prefers a living friendly turret when the predicted landing is inside its range. Simply kicking toward a turret is not enough.'},
            {'ALLIES AND FALLBACK','Otherwise, Lee chooses a valid nearby ally and considers nearby threats. With no recipient, the destination is your position when you started holding the key. Dead recipients are excluded.'},
            {'TRACKING AND BASE','Ally tracking ['..state('insecTrackAlly')..'] follows the recipient before direction locks. The base option ['..state('insecBasePlatform')..'] also allows a landing deep inside a known friendly base platform.'}},
            'A turret or platform landing does not guarantee a kill.'},
        {'Inspect the route before allowing it',{
            {'PREVIEW','Hold '..preview..' together with '..key('cursorKey')..' or '..key('allyKey')..'. Check the target, kick arrow and listed steps. Release only '..preview..' while continuing to hold Insec.'},
            {'FLASH','"Allow Flash" ['..state('insecFlash')..'] enables proposals. Confirming a preview permits its shown Flash. Without a preview, fallback ['..state('insecFlashFallback')..'] requires no ready ward and no W step already committed.'},
            {'APPROACH TOOLS','Allowed Q, W and Flash steps can be combined. Q bridges use another enemy, minion or camp as an intermediate target. W and wards are planned around reaching a valid final kick position.'}},
            'If no complete route is shown, hold '..preview..' again to review the preview.'},
        {'Fight with the resources you have allowed',{
            {'SPELLS AND PASSIVE','Q1/Q2, W1/W2, E1/E2 and R have separate switches. Combo Q2 is '..state('comboQ2')..'. Lee weaves useful passive attacks, but a timely lethal finish can take priority.'},
            {'CHASE','Lee compares walking with a wardjump. A chase ward needs a clear time advantage; E2 can slow the target first. Reserving W keeps mobility available. Ordinary Combo Q2 turret safety is '..state('q2Safety')..'.'},
            {'KICKS','Multikick counts the primary target: '..tostring(cfg:get('multiHits'))..' means the target plus '..tostring((cfg:get('multiHits') or 3)-1)..' extra hits. Collateral kills, saving R, isolation and marked R > Q2 follow-up are separate options.'}},
            'Idle multikick ['..state('autoMultiR')..'] can kick without a held Combo, but does not reposition for it.'},
        {'Harass, Q assistance and automatic recasts',{
            {'TARGETED ASSISTANCE','Harass ['..self:modeKey('HARASS')..'] has its own spell permissions. Hold '..key('qAssistKey')..' for Q1 assistance only. "Only the selected enemy" restricts champion Q1 to the orbwalker selection.'},
            {'SHIELDS AND RECASTS','Defensive W is '..state('idleDefense')..'. Reserved W stays available for mobility or a lifesaving shield. Expiry W2 and expiry E2 can recast before their windows close, while respecting the energy reserve.'},
            {'KILLSTEAL','Q1, Q2, E and R have separate permissions. Q2 killsteal ['..state('killQ2')..'] is a dash and needs your own valid Q mark. An expected hit is not a confirmed mark.'}},
            'Under Orbama, eligible held Combo/Harass casts can survive ordinary movement commands.'},
        {'Local clearing and last-hitting have different goals',{
            {'LAST HIT','With '..self:modeKey('LASTHIT')..', enabled Q/W/E rescue CS you would otherwise miss. This mode avoids simply softening the wave and accounts for known incoming attacks.'},
            {'WAVECLEAR','With '..self:modeKey('LANECLEAR')..', E can prepare safe area damage. Optional Harass gives last hits priority. Gold priority helps choose when not every minion can be reached.'},
            {'JUNGLE CLEAR','With '..self:modeKey('JUNGLECLEAR')..', Lee clears a nearby camp without starting a route. The Q2 range limit saves long dashes during clearing. W1/W2 for passive and sustain remain separately configurable.'}},
            'Lane and jungle bindings come from your active orbwalker and can be shared or separate.'},
        {'Start a route from the camp you choose',{
            {'START AND STOP','Press '..key('autoJungleKey')..' near your chosen camp. Routing favors your side according to your settings. Pressing again, manual clicks or entering a combat mode stops it. Reloading always leaves it off.'},
            {'TRAVEL AND CAMPS','Q can shorten travel. Fog probes test known camps; a missed Q alone does not prove a stolen camp. Kiting moves between safe attacks while staying near the camp. Routing does not start bosses on its own.'},
            {'RECOVERY AND CAMERA','Lee finishes a camp if survivable or escapes before recalling. Routing stays enabled through recovery. Camera follow uses your lock key '..key('farmCameraKey')..'; manual camera input takes priority.'}},
            'Route and approach settings are under Auto-jungle. There is no shopping automation.'},
        {'Autosmite also works without a held mode',{
            {'AUTOSMITE  '..key('smiteKey'),'The toggle is '..state('autosmite')..'. Eligible visible objectives in range are checked against their current lethal HP. Selecting a champion does not block objective Smite.'},
            {'ORDINARY CAMPS','Camp Smite ['..state('smiteCamps')..'] also permits ordinary monsters in any mode. The HP margin adds a safety buffer, not extra Smite damage. Smite options are hidden when Smite is not equipped.'},
            {'Q + SMITE ASSIST  '..key('secureKey'),'Hold this optional key to prepare a visible epic with Q. Q2 requires a confirmed mark and enough Q2/Smite damage to finish. This assist only has a hotkey if you assign one.'}},
            'A valid Smite still needs a safe input opportunity.'},
        {'Use owned items and assign skill points',{
            {'ITEMS AND POTIONS','Item permissions cover targeted damage, cleave, slow, speed, QSS and shielding. Potions have Combat potions, Jungle-clear potions and Auto-jungle potions switches. The HP threshold and missing health also apply.'},
            {'IGNITE','Combo Ignite is '..state('comboIgnite')..'. "Ignite only when lethal" ['..state('igniteExecute')..'] restricts use to a predicted finish. Having the spell equipped alone does not authorize its use.'},
            {'AUTO LEVEL','Auto level is '..state('level')..'. It unlocks W, E, then Q; afterward it prioritizes Q, W, E and takes R when eligible. Wardjump, Insec and manually held modifier keys take priority.'}},
            'Only owned items are used. The script does not buy items.'},
        {'Choose which information stays on screen',{
            {'RANGES AND PREVIEWS','Q range, W range, E range, R range, Ward range and Status panel each have their own switches. Mode filters stay in the menu; Always takes priority. Wardjump preview and Insec preview also need a valid plan.'},
            {'DAMAGE','Green shows the conservative estimate; orange uses more allowed resources. Q, E, R, items, summoners and planned attacks are selectable. "partial" means some damage effects are not modeled.'},
            {'YOUR SETTINGS','Edit shortcuts in each feature menu or Guide > Key bindings. Orbwalker shortcuts update the original mode bindings. Advanced holds range, timing and safety margins. Guide > Text size adjusts this panel.'}},
            'Drawings do not execute actions. Keys and ON/OFF labels follow your current settings.'}
    }
    local page=pages[index] or pages[1]
    return {title=G.titles[index] or G.titles[1],subtitle=page[1],cards=page[2],note=page[3]}
end
function G:event(msg,key)
    local c=self.ctx;local cfg=c.config
    if msg==513 or msg==514 then return self:mouse(msg) end
    if msg~=256 and msg~=257 and msg~=260 and msg~=261 then return false end
    if c.synthetic or c.sdk.Input and c.sdk.Input:IsSyntheticEvent() then return false end
    local injected=c.injected and c.injected[key]
    if injected and c:now()<(injected.untilTime or (injected.at or 0)+.08) then return false end
    if msg==257 or msg==261 then
        local owned=self.down[key];self.down[key]=nil;return owned==true
    end
    if c:chatOpen() or Game.IsOnTop and not Game.IsOnTop() then self.down={};return false end
    local toggle=cfg:key('guideKey');local open=cfg:get('guideOpen')
    local previous,nextKey=cfg:key('guidePreviousKey'),cfg:key('guideNextKey')
    if key==0 or not (key==toggle or open and (key==previous or key==nextKey)) then return false end
    -- A help binding must not swallow a ward release or a combat-mode edge.
    if c.input:isModeKey(key) or key==cfg:key('farmCameraKey') then return false end
    for slot=0,5 do if c.actions:key(slot)==key then return false end end
    if self.down[key] then return true end
    self.down[key]=true
    self.mouseDown=nil;self.hits={}
    if key==toggle then cfg:set('guideOpen',not open)
    else
        local page=cfg:get('guidePage') or 1
        cfg:set('guidePage',(page-1+(key==nextKey and 1 or -1))%#G.titles+1)
    end
    return true
end
function G:mouse(msg)
    local c=self.ctx;local cfg=c.config
    if c.synthetic or c.sdk.Input and c.sdk.Input:IsSyntheticEvent()
        or c.sdk.NativeTransport and c.sdk.NativeTransport.InFlight
        or c.sdk.Cursor and c.sdk.Cursor.Step>0 then return false end
    if c:chatOpen() or Game.IsOnTop and not Game.IsOnTop() then self.mouseDown=nil;return false end
    local prior=self.mouseDown
    if msg==514 then self.mouseDown=nil end
    if not cfg:get('guideOpen') or self.hitPage~=cfg:get('guidePage') then return prior~=nil end
    local pointer=UI.pointer();local inside=UI.inside(pointer,self.panel)
    local hit
    for _,candidate in ipairs(self.hits or {}) do if UI.inside(pointer,candidate) then hit=candidate;break end end
    if msg==513 then
        self.mouseDown=inside and {link=hit and hit.link,page=self.hitPage} or nil
        return inside==true
    end
    if prior and hit and prior.page==self.hitPage and prior.link
        and prior.link.key==hit.link.key and prior.link.topic==hit.link.topic then
        local link=hit.link
        if link.close then cfg:set('guideOpen',false)
        elseif Links.activate(cfg,link) then
            if link.key=='autoJungle' or link.key=='autosmite' then
                local enabled=cfg:get(link.key);local owner=link.key=='autoJungle' and 'farm' or 'autosmite'
                c.actions:physicalIntent(owner,enabled)
                if not enabled then c.actions:cancel(owner) end
                if link.key=='autoJungle' then c.input.farmPaused=false;c.input.pressed.farmKey=enabled end
            end
        end
        self.content=nil;self.hits={}
    end
    return prior~=nil or inside==true
end
function G:draw()
    local c=self.ctx;local cfg=c.config
    if c:chatOpen() or Game.IsOnTop and not Game.IsOnTop() then self.down={};self.hits={};self.mouseDown=nil;return end
    if not cfg:get('guideOpen') or not Draw or not Draw.Rect or not Draw.Text or not Draw.Color then self.hits={};return end
    local size=Game.Resolution and Game.Resolution() or {x=1920,y=1080}
    local width,height=size.x or 1920,size.y or 1080
    local scale=math.min((width-32)/850,(height-32)/620,math.max(.8,math.min(1.4,height/1080))*(cfg:get('guideScale') or 100)/100)
    if scale<=0 then return end
    local x,y=math.floor((width-850*scale)/2),math.floor((height-620*scale)/2)
    local pageIndex=math.max(1,math.min(#G.titles,cfg:get('guidePage') or 1))
    local now=c:now()
    if not self.content or self.contentIndex~=pageIndex or now>=(self.contentAt or 0)+.2 then
        self.content=self:page(pageIndex);self.contentIndex=pageIndex;self.contentAt=now;self.spanCache={}
    end
    local page=self.content;local ui=UI.new(self,x,y,scale,pageIndex)
    ui:rect(5,7,850,620,{0,0,0},100);ui:rect(0,0,850,620,{13,21,29})
    ui:rect(0,0,850,3,{91,231,186});ui:rect(0,3,218,617,{18,29,38})
    ui:text('LEE HARVEY OSWARD',22,25,16,{91,231,186})
    ui:text('FIELD GUIDE',22,52,25,{237,244,248})
    ui:text('CLICK TO CONFIGURE',22,91,12,{139,184,255})
    for index,title in ipairs(G.titles) do
        local rowY=126+(index-1)*30
        local hover=ui:hit(12,rowY-4,194,28,{topic=index,label=title})
        if index==pageIndex or hover then ui:rect(12,rowY-4,194,28,index==pageIndex and {30,57,65} or {31,43,59}) end
        if index==pageIndex then ui:rect(12,rowY-4,3,28,{91,231,186}) end
        ui:text(string.format('%02d',index),23,rowY,12,index==pageIndex and {91,231,186} or {102,126,144})
        ui:text(title,48,rowY,13,index==pageIndex and {242,249,252} or {170,187,199})
    end
    local rules=Links.rules(pageIndex)
    ui:rich(page.title,244,25,575,25,rules,{237,244,248},true)
    local cursorY=66+ui:rich(page.subtitle,244,66,575,15,rules,{142,163,180},true)
    cursorY=math.max(110,cursorY+16)
    for index,card in ipairs(page.cards) do
        local cardRules=Links.rules(pageIndex,index)
        local h=ui:rich(card[2],252,0,558,14,cardRules,nil,false)
        local cardHeight=40+h
        ui:rect(236,cursorY,594,cardHeight,{21,33,44})
        ui:rich(card[1],252,cursorY+12,558,13,cardRules,{164,187,209},true)
        ui:rich(card[2],252,cursorY+33,558,14,cardRules,nil,true)
        cursorY=cursorY+cardHeight+10
    end
    local noteY=math.max(cursorY+3,526)
    ui:rich(page.note,244,noteY,575,13,rules,{180,195,211},true)
    ui:rect(218,576,632,1,{44,61,74})
    ui:text(ui:hint(),244,583,12,{139,184,255})
    local previous=(pageIndex-2)%#G.titles+1;local following=pageIndex%#G.titles+1
    ui:hit(240,601,150,18,{topic=previous,label='Previous topic'})
    ui:hit(404,601,150,18,{topic=following,label='Next topic'})
    ui:hit(690,601,130,18,{close=true,label='Close guide'})
    ui:text(U.keyLabel(cfg:key('guidePreviousKey'))..'  Previous',244,601,12,{163,184,198})
    ui:text(U.keyLabel(cfg:key('guideNextKey'))..'  Next',410,601,12,{163,184,198})
    ui:text(U.keyLabel(cfg:key('guideKey'))..'  Close',720,601,12,{91,231,186})
end
return G

end
modules["lho.guidefont"] = function(require)
-- Segoe UI 14px advance estimates for native guide layout.
return {[32]=4.000,[33]=4.000,[34]=5.000,[35]=8.000,[36]=8.000,[37]=11.000,[38]=11.000,[39]=3.000,[40]=4.000,[41]=4.000,[42]=6.000,[43]=10.000,[44]=3.000,[45]=6.000,[46]=3.000,[47]=5.000,[48]=8.000,[49]=8.000,[50]=8.000,[51]=8.000,[52]=8.000,[53]=8.000,[54]=8.000,[55]=8.000,[56]=8.000,[57]=8.000,[58]=3.000,[59]=3.000,[60]=10.000,[61]=10.000,[62]=10.000,[63]=6.000,[64]=13.000,[65]=9.000,[66]=8.000,[67]=9.000,[68]=10.000,[69]=7.000,[70]=7.000,[71]=10.000,[72]=10.000,[73]=4.000,[74]=5.000,[75]=8.000,[76]=7.000,[77]=13.000,[78]=10.000,[79]=11.000,[80]=8.000,[81]=11.000,[82]=8.000,[83]=7.000,[84]=7.000,[85]=10.000,[86]=9.000,[87]=13.000,[88]=8.000,[89]=8.000,[90]=8.000,[91]=4.000,[92]=5.000,[93]=4.000,[94]=10.000,[95]=6.000,[96]=4.000,[97]=7.000,[98]=8.000,[99]=6.000,[100]=8.000,[101]=7.000,[102]=4.000,[103]=8.000,[104]=8.000,[105]=3.000,[106]=3.000,[107]=7.000,[108]=3.000,[109]=12.000,[110]=8.000,[111]=8.000,[112]=8.000,[113]=8.000,[114]=5.000,[115]=6.000,[116]=5.000,[117]=8.000,[118]=7.000,[119]=10.000,[120]=6.000,[121]=7.000,[122]=6.000,[123]=4.000,[124]=3.000,[125]=4.000,[126]=10.000}

end
modules["lho.guidelinks"] = function(require)
-- Explicit feature names keep a mention tied to the setting it describes.
local L={}
local common={
    {'autoJungle','Auto-jungle','Routing'}, {'autosmite','Autosmite'},
    {'wardFollowCursor','Move toward cursor after jump'}, {'wardApproach','Approach assistance'},
    {'wardAssist','wall assistance'}, {'insecMouseTarget','mouse fallback'},
    {'aimLock','Lock kick direction'}, {'insecPreferStructures','Turret priority','friendly turrets'},
    {'insecTrackAlly','Ally tracking'}, {'insecBasePlatform','base option'},
    {'insecFlash','Allow Flash'},
    {'insecBridges','Q bridges'}, {'insecChains','combined'},
    {'comboPassive','passive attacks'}, {'comboBurst','timely lethal finish'},
    {'comboWard','chase ward'}, {'comboChaseE2','E2 can slow'},
    {'reserveW','Reserving W','Reserved W'}, {'q2Safety','Q2 turret safety'},
    {'multi','Multikick'}, {'autoMultiR','Idle multikick'}, {'collateralKills','Collateral kills'},
    {'comboConserveR','saving R'}, {'comboIsolate','isolation'}, {'comboKickFollow','marked R > Q2 follow-up'},
    {'qOnlySelected','Only the selected enemy'}, {'idleDefense','Defensive W'},
    {'expiryW','Expiry W2'}, {'expiryE','expiry E2'},
    {'killQ2','Q2 killsteal'}, {'waveHarass','Optional Harass'}, {'csGoldPriority','Gold priority'},
    {'jungleQ2MeleeOnly','Q2 range limit'}, {'farmQTravel','Q can shorten travel'},
    {'farmQBlind','Fog probes'}, {'farmKite','Kiting'}, {'farmFollowCamera','Camera follow'},
    {'smiteCamps','Camp Smite'}, {'comboIgnite','Combo Ignite'}, {'igniteExecute','Ignite only when lethal'},
    {'level','Auto level'}, {'damageSafe','conservative estimate'}, {'damageMax','more allowed resources'},
    {'draw','Drawings'}, {'items','Item permissions'}, {'potions','Potions'},
    {'potionFight','Combat potions'}, {'potionJungle','Jungle-clear potions'}, {'potionAuto','Auto-jungle potions'},
    {'drawQRange','Q range'}, {'drawWRange','W range'}, {'drawERange','E range'}, {'drawRRange','R range'},
    {'drawWardRange','Ward range'}, {'drawHUD','Status panel'},
}
local contextual={
    [6]={{'insecQ','Q'},{'insecW','W'},{'insecFlash','Flash'},{'insecFlashFallback','fallback'}},
    [7]={{'comboQ','Q1'},{'comboQ2','Q2'},{'comboW','W1'},{'comboW2','W2'},
        {'comboE','E1'},{'comboE2','E2'},{'comboR','R'}},
    [8]={{'expiryW','W2'},{'expiryE','E2'},{'killQ','Q1'},{'killE','E'},{'killR','R'}},
    [9]={{'lastAbilities','LAST HIT'},{'waveAbilities','WAVECLEAR'},{'jungleAbilities','JUNGLE CLEAR'},
        {'waveSoften','safe area damage'},{'jungleW','W1/W2'}},
    [12]={{'itemTargeted','targeted damage'},{'itemCleave','cleave'},{'itemSlow','slow'},
        {'itemSpeed','speed'},{'itemCleanse','QSS'},{'itemShield','shielding'}},
    [13]={{'drawQRange','Q defaults'},{'drawWard','Wardjump preview','Wardjump'},{'drawInsec','Insec preview','Insec'},
        {'damageBars','DAMAGE'},{'damageQ','Q'},{'damageE','E'},{'damageR','R'},
        {'damageItems','items'},{'damageSummoners','summoners'}},
}
local topics={{2,'Wardjump'},{4,'Cursor Insec','Insec'},{5,'Team Insec'},
    {6,'Insec preview','preview modifier'},{7,'Combo'},{8,'Harass','Q1 assist','Q1 assistance','Killsteal'},
    {9,'Lane clear','Jungle clear','Last hit','Waveclear'},{11,'Q + Smite assist'},
    {12,'Items & leveling'}}
local cache={}
function L.rules(page,card)
    local cacheKey=page*10+(card or 0)
    if cache[cacheKey] then return cache[cacheKey] end
    local result={}
    local function add(rows,topic)
        for _,row in ipairs(rows or {}) do for i=2,#row do
            result[#result+1]={label=row[i],key=not topic and row[1] or nil,topic=topic and row[1] or nil,order=#result+1}
        end end
    end
    -- Spell names in Harass and farming paragraphs must use that mode's switches.
    if page==8 and card==1 then
        add({{'harassQ','Q1'},{'harassQ2','Q2'},{'harassW','W1'},{'harassW2','W2'},
            {'harassE','E1'},{'harassE2','E2'},{'harassR','R'}})
    elseif page==9 then
        local prefix=card==1 and 'last' or card==2 and 'wave' or 'jungle'
        add({{prefix..'Q','Q'},{prefix..'W','W'},{prefix..'E','E'}})
    end
    add(contextual[page]);add(common);add(topics,true)
    table.sort(result,function(a,b)return #a.label==#b.label and a.order<b.order or #a.label>#b.label end)
    cache[cacheKey]=result
    return result
end
function L.spans(text,rules)
    local spans={};local lower=text:lower();local at=1;local plain=''
    local function flush()if plain~='' then spans[#spans+1]={text=plain};plain='' end end
    while at<=#text do
        local match
        for _,rule in ipairs(rules) do
            local last=at+#rule.label-1
            if lower:sub(at,last)==rule.label:lower()
                and (at==1 or not lower:sub(at-1,at-1):match('[%w_]'))
                and (last==#text or not lower:sub(last+1,last+1):match('[%w_]')) then match=rule;break end
        end
        if match then
            flush();spans[#spans+1]={text=text:sub(at,at+#match.label-1),link=match};at=at+#match.label
        else plain=plain..text:sub(at,at);at=at+1 end
    end
    flush();return spans
end
function L.active(cfg,link)
    if not link.key then return nil end
    local value=cfg:get(link.key)
    if link.key=='drawQRange' then return value~=1 end
    if link.key=='aimLock' then return nil end
    return type(value)=='boolean' and value or false
end
function L.activate(cfg,link)
    if link.topic then cfg:set('guidePage',link.topic);return true end
    local key=link.key;local value=cfg:get(key)
    if key=='aimLock' then cfg:set(key,(value or 1)%3+1);return true end
    if key=='drawQRange' then
        -- The legacy numeric setter resets mode filters. Keep those independent
        -- choices when the guide changes only the Enabled switch.
        local options=cfg.drawingOptions and cfg.drawingOptions[key];local saved={}
        for name,node in pairs(options or {}) do saved[name]=node:Value() end
        cfg:set(key,value==1 and 2 or 1)
        for name,setting in pairs(saved) do options[name]:Value(setting) end
        return true
    end
    if type(value)=='boolean' then cfg:set(key,not value);return true end
    return false
end
return L

end
modules["lho.guideui"] = function(require)
local Links=require('lho.guidelinks')
local widths=require('lho.guidefont')
local UI={};UI.__index=UI
local colors={on={91,231,186},off={247,145,154},topic={139,184,255},cycle={206,170,255},text={222,233,242}}
local function advance(s,font)
    local width=0
    for i=1,#s do width=width+(widths[s:byte(i)] or 8) end
    return width*font/14
end
function UI.pointer()
    if not Game.cursorPos then return end
    local ok,p=pcall(Game.cursorPos)
    if ok and p and type(p.x)=='number' and type(p.y)=='number' then return p end
end
function UI.inside(p,r)
    return p and p.x>=r.x and p.x<r.x+r.w and p.y>=r.y and p.y<r.y+r.h
end
function UI.new(guide,x,y,scale,page)
    guide.hits={};guide.hitPage=page
    guide.panel={x=x,y=y,w=850*scale,h=620*scale}
    return setmetatable({guide=guide,x=x,y=y,scale=scale,pointer=UI.pointer()},UI)
end
function UI:rect(x,y,w,h,color,a)
    local s=self.scale
    Draw.Rect(math.floor(self.x+x*s),math.floor(self.y+y*s),math.ceil(w*s),math.ceil(h*s),
        Draw.Color(a or 250,color[1],color[2],color[3]))
end
function UI:text(label,x,y,font,color)
    local s=self.scale
    Draw.Text(label,math.max(10,math.floor(font*s)),math.floor(self.x+x*s),math.floor(self.y+y*s),
        Draw.Color(255,color[1],color[2],color[3]))
end
function UI:hit(x,y,w,h,link)
    local s=self.scale
    local hit={x=self.x+x*s,y=self.y+y*s,w=w*s,h=h*s,link=link}
    self.guide.hits[#self.guide.hits+1]=hit
    if UI.inside(self.pointer,hit) then self.hover=link;return true end
end
function UI:rich(label,x,y,width,font,rules,base,draw)
    local lineHeight=math.max(18,font+4);local px,py=0,0
    local measured=math.max(10,math.floor(font*self.scale))/self.scale
    local space=advance(' ',measured)
    local guide=self.guide;guide.spanCache=guide.spanCache or {}
    local cached=guide.spanCache[rules]
    if not cached then cached={};guide.spanCache[rules]=cached end
    if not cached[label] then cached[label]=Links.spans(label,rules) end
    for _,span in ipairs(cached[label]) do
        local leading=span.text:match('^(%s+)')
        if leading then
            if leading:find('\n',1,true) then px=0;py=py+lineHeight else px=px+space end
        end
        for word,gap in span.text:gmatch('([^%s]+)(%s*)') do
            local w=advance(word,measured)+.35
            if px>0 and px+w>width then px=0;py=py+lineHeight end
            if draw then
                local color=base or colors.text
                if span.link then
                    local active=Links.active(self.guide.ctx.config,span.link)
                    color=span.link.topic and colors.topic or active==nil and colors.cycle or active and colors.on or colors.off
                    if self:hit(x+px-1,y+py,w+2,lineHeight,span.link) then
                        self:rect(x+px-2,y+py-1,w+4,lineHeight,{40,58,73})
                    end
                    self:rect(x+px,y+py+font+2,w,1,color,180)
                end
                self:text(word,x+px,y+py,font,color)
            end
            px=px+w
            if gap:find('\n',1,true) then px=0;py=py+lineHeight
            elseif #gap>0 then px=px+space end
        end
    end
    return py+lineHeight
end
function UI:hint()
    local link=self.hover;local cfg=self.guide.ctx.config
    if not link then return 'Mint: on   /   Coral: off   /   Blue: topic' end
    if link.close then return 'Close the guide' end
    if link.topic then return 'Open '..self.guide.titles[link.topic] end
    if link.key=='aimLock' then return 'Click to change when the kick direction locks' end
    return 'Click to '..(Links.active(cfg,link) and 'disable ' or 'enable ')..link.label
end
return UI

end
modules["lho.input"] = function(require)
local U=require('lho.util')
local I={};I.__index=I
local holds={'cursorKey','allyKey','wardKey','qKey','secureKey'}
local modifiers={[16]={16,160,161},[17]={17,162,163},[18]={18,164,165}}
local canonical={[160]=16,[161]=16,[162]=17,[163]=17,[164]=18,[165]=18}
function I.new(ctx) return setmetatable({ctx=ctx,down={},pressed={},released={},suspended={},wardCancelled=false,farmPaused=false},I) end
function I:held(name) local key=self.ctx.config:key(name);return key and key~=0 and self.down[key]==true end
function I:previewHeld()
    local key=self.ctx.config:key('insecPreviewKey')
    if key==18 then return self.down[18] or self.down[164] or self.down[165] or false end
    return key and key~=0 and self.down[key]==true or false
end
function I:insecMovementHeld()
    local c=self.ctx;local pending=c.wards and c.wards.pending
    return (self:held('cursorKey') or self:held('allyKey')) and not c:blocked()
        and not self:held('wardKey') and not (pending and pending.owner=='ward')
end
function I:pauseFarm(reason)
    if self.ctx.farm then
        self.ctx.farm.localException=nil;self.ctx.farm.returningHome=nil;self.ctx.farm.recallAction=nil;self.ctx.farm.recoveryWanted=nil;self.ctx.farm.recallReconcile=nil;self.ctx.farm.recallLegacy=nil
    end
    if self.ctx.config:get('autoJungle') then
        local c=self.ctx
        self.lastFarmStop={reason=reason or 'Input / mode takeover',state=c.farm.state,
            pos=U.copy(myHero.pos),spawn=U.copy(c.farm.spawnPos),recalling=c:recalling(),
            status=c.status,mode=c.mode,input=self.lastPhysicalEvent,
            levelPending=c.leveling.pending~=nil,cursorStep=c.sdk.Cursor.Step}
        if c.config.capture then c:log('farm_stopped',self.lastFarmStop) end
    end
    self.farmPaused=true;self.ctx.config:set('autoJungle',false)
end
function I:event(msg,param)
    local c=self.ctx;local now=c:now()
    if c.sdk.Input and c.sdk.Input:IsSyntheticEvent() then return true end
    if c.synthetic or c.sdk.NativeTransport and c.sdk.NativeTransport.InFlight then return true end
    -- Cursor movement caused by the SDK is not player intent. Preserve real deviations.
    if msg==512 then
        if c.sdk.Actions or c.sdk.Input then c.aim=c:playerPosition();return end
        local cursor=c.sdk.Cursor
        if cursor and cursor.Step>0 and c.cursorLease and cursor.CastPos==c.cursorLease.castPos and Game.cursorPos then
            local p=Game.cursorPos();local expected=cursor.correctedCastPos
            if expected and U.screenDist(p,expected)>8 and U.screenDist(p,cursor.CursorPos)>8 then
                cursor.CursorPos={x=p.x,y=p.y};c.aim=U.copy(mousePos or c.aim)
            end
        end
        return
    end
    if msg==516 then
        if not c.sdk.Input and now<(c.syntheticMouseUntil or -1) then return end
        self.lastPhysicalEvent={message=msg,key=2,param=param,at=now}
        -- A real movement click may interrupt the provider's current input, but
        -- does not withdraw a held Insec intention. Its controller reconciles
        -- already-sent actions and replans unsent steps from the new position.
        -- Standalone T retains its explicit right-click cancellation contract.
        if self:insecMovementHeld() then
            self:pauseFarm('Physical right-click');self.cancel=false
            c.aim=c:playerPosition()
            if c.config.capture then c:log('insec_manual_movement',{message=msg,param=param,
                phase=c.combat.insec and c.combat.insec.phase,
                evidence='Right-click retains held Insec; provider still owns input reconciliation'}) end
            return
        end
        self.wardCancelled=true;self:pauseFarm('Physical right-click');self.cancel=true
        if c.sdk.Input and c.sdk.Input.Capabilities.withholdInput and c.config:get('cancelOnly') and _G.LHO_InputAdapter and _G.LHO_InputAdapter.consume then
            _G.LHO_InputAdapter.consume(msg,param)
        end
        return
    end
    if msg==513 then
        if not c.sdk.Input and now<(c.syntheticMouseUntil or -1) then return end
        self.lastPhysicalEvent={message=msg,key=1,param=param,at=now}
        if c.sdk.TargetSelector and c.sdk.TargetSelector.GetTarget then
            -- GG has processed selection before SDK.OnWndMsg. Never shadow its
            -- selection, toggle it again, or keep a stale independent lock.
            c.selected=nil;c.selectionOwned=false;self:pauseFarm('Physical left-click');return
        end
        local selected,dist=nil,180
        for _,e in ipairs(c.enemies or {}) do
            local d=U.dist(c.aim,e.pos)
            if d<dist then selected,dist=e,d end
        end
        -- GG processes the same click first. Re-toggling its selection here would erase it.
        c.selected=selected;c.selectionOwned=true
        self:pauseFarm('Physical left-click')
        return
    end
    local key,down
    if msg==256 or msg==260 then key,down=param,true
    elseif msg==257 or msg==261 then key,down=param,false
    elseif msg==523 or msg==524 then
        -- Raw Windows: XBUTTON index in high word. Some GoS builds emit VK 5/6.
        local high=math.floor((param or 0)/65536)%65536
        key=high==1 and 5 or high==2 and 6 or ((param==5 or param==6) and param or nil)
        down=msg==523
    end
    if not key then return end
    if self.releasedSamples then self.releasedSamples[key]=nil end
    if not down then self.suspended[key]=nil end
    if down and self.suspended[key] then return end
    local injected=c.injected[key]
    local family=modifiers[canonical[key] or key]
    if not injected and family then
        for _,alias in ipairs(family) do if c.injected[alias] then injected=c.injected[alias];break end end
    end
    -- One chord can emit both generic and side-specific Windows modifiers.
    -- Bound each representation separately so neither consumes the other's echo.
    if injected and family and now<(injected.untilTime or injected.at+.08) then
        injected.modifierEchoes=injected.modifierEchoes or {}
        local left=injected.modifierEchoes[key]
        if left==nil then left=injected.remaining end
        if left>0 then injected.modifierEchoes[key]=left-1;return true end
    end
    if injected and not family and now<(injected.untilTime or injected.at+.08) and injected.remaining>0 then
        injected.remaining=injected.remaining-1;return true
    end
    if c:blocked() then if not down then self.down[key]=nil end;return end
    local was=self.down[key]
    self.down[key]=down
    if was~=down and key==c.config:key('allyKey') and c.combat then
        c.combat.allyHoldOrigin=down and U.copy(myHero.pos) or nil
    end
    if down and not was then
        for slot=0,3 do if key==c.actions:key(slot) then
            c.manualSpellSerial=(c.manualSpellSerial or 0)+1;c.manualSpells=c.manualSpells or {}
            c.manualSpells[slot]={at=now,serial=c.manualSpellSerial,before=slot<3 and require('lho.recasts').snapshot(c,slot)}
        end end
    end
    if was~=down and c.actions.physicalIntent then
        local owners={cursorKey='insec',allyKey='insec',wardKey='ward',qKey='q',secureKey='secure'}
        for name,owner in pairs(owners) do if key==c.config:key(name) then
            c.actions:physicalIntent(owner,down)
            if not down and owner~='ward' then c.actions:cancel(owner) end
        end end
        local modes={COMBO='fight',HARASS='harass',LANECLEAR='clear',JUNGLECLEAR='clear',LASTHIT='gg_last'}
        local seen={}
        for mode,owner in pairs(modes) do
            local menus=c.sdk.Orbwalker.MenuKeys and c.sdk.Orbwalker.MenuKeys[c.sdk['ORBWALKER_MODE_'..mode]]
            for _,binding in ipairs(menus or {}) do
                if binding.Key and binding:Key()==key and not seen[owner] then
                    seen[owner]=true;c.actions:physicalIntent(owner,down)
                    -- Last-hit shares the lane spell controller, not its input
                    -- owner name. Cancel before the next scheduler opportunity.
                    if owner=='gg_last' then c.actions:physicalIntent('clear',down) end
                    if not down then c.actions:cancel(owner=='gg_last' and 'clear' or owner) end
                end
            end
        end
    end
    if was~=down then self.lastTransition={key=key,message=msg,down=down,at=now} end
    if down and not was then self.lastPhysicalEvent={key=key,message=msg,at=now} end
    if was~=down and (c.config:get('diagnostics') or c.config:get('playtestLogging') or c.config:get('combatLogging')) then
        if c.config.capture then c:log('input_event',{message=msg,param=param,key=key,down=down,evidence='Not recognized as an injected echo'}) end
    end
    if down and not was then
        if key==c.config:key('farmCameraKey') then c.actions.cameraOwned=nil end -- Physical camera takeover owns the final state.
        if key==c.config:key('farmKey') then
            if c.config.capture then c:log('farm_toggle',{enabled=not c.config:get('autoJungle')}) end
            c.config:set('autoJungle',not c.config:get('autoJungle'));self.farmPaused=false
            c.actions:physicalIntent('farm',c.config:get('autoJungle'))
            if not c.config:get('autoJungle') then c.actions:cancel('farm') end
            self.pressed.farmKey=c.config:get('autoJungle');return
        end
        if key==c.config:key('smiteKey') then
            c.config:set('autosmite',not c.config:get('autosmite'))
            c.actions:physicalIntent('autosmite',c.config:get('autosmite'))
            if not c.config:get('autosmite') then c.actions:cancel('autosmite') end
            if c.config.capture then c:log('smite_toggle',{enabled=c.config:get('autosmite'),key=key}) end;return
        end
        for _,name in ipairs(holds) do
            if key==c.config:key(name) and key~=0 then
                self.pressed[name]=true
                if name=='wardKey' then self.wardCancelled=false end
                self:pauseFarm('Assist key '..U.keyLabel(key))
            end
        end
        if key==81 or key==87 or key==69 or key==82 or key==66
            or key==c.config:key('farmCameraKey') then self:pauseFarm('Manual key '..U.keyLabel(key)) end
    elseif not down and was then
        for _,name in ipairs(holds) do if key==c.config:key(name) then self.released[name]=true end end
    end
end
function I:clearEdges() self.pressed={};self.released={};self.cancel=false end
function I:isModeKey(key)
    local c=self.ctx
    for _,name in ipairs(holds) do if c.config:key(name)==key and key~=0 then return true end end
    for _,name in ipairs({'farmKey','smiteKey'}) do if c.config:key(name)==key and key~=0 then return true end end
    local preview=c.config:key('insecPreviewKey')
    if key==preview or canonical[key]==preview then return true end
    for _,bindings in pairs(c.sdk.Orbwalker.MenuKeys or {}) do
        for _,binding in ipairs(bindings) do if binding.Key and binding:Key()==key then return true end end
    end
    return false
end
function I:reconcileSuspended()
    local c=self.ctx;local now=c:now()
    if c:blocked() or now<(self.pollAt or 0) or not next(self.suspended) then return end
    self.pollAt=now+.1;self.releasedSamples=self.releasedSamples or {}
    for key in pairs(self.suspended) do
        if not self:isModeKey(key) then self.suspended[key]=nil;self.releasedSamples[key]=nil
        else
        local family=modifiers[canonical[key] or key] or {key}
        local released=true
        for _,alias in ipairs(family) do
            local input=c.sdk.Input
            local ok,state
            if input and input.ReadKeyState then ok,state=pcall(input.ReadKeyState,input,alias)
            elseif Control.IsKeyDown then ok,state=pcall(Control.IsKeyDown,alias) end
            if not ok or state~=false then released=false;break end
        end
        if released then
            if self.releasedSamples[key] and now-self.releasedSamples[key]>=.09 then
                self.suspended[key]=nil;self.down[key]=nil;self.releasedSamples[key]=nil
                if c.config.capture then c:log('input_suspension_cleared',{key=key,evidence='Two focused host key-state samples report released; no input sent'}) end
            else self.releasedSamples[key]=now end
        else self.releasedSamples[key]=nil end
        end
    end
end
function I:reset(preserveFarm)
    if self.ctx.combat then self.ctx.combat.allyHoldOrigin=nil end
    self.releasedSamples={};self.pollAt=nil;self.wardContinuation=nil
    -- Only an automation mode can resume held intent. Chat characters, TCO,
    -- camera keys and unrelated input must never reserve the entire controller.
    for key,down in pairs(self.down) do if down and self:isModeKey(key) then self.suspended[key]=true end end
    self.down={};self:clearEdges();self.wardCancelled=true
    if not preserveFarm then
        local c=self.ctx
        self:pauseFarm(myHero.dead and 'Champion died' or not c.config:get('enabled') and 'Controller disabled'
            or c:chatOpen() and 'Chat opened'
            or Game.IsOnTop and not Game.IsOnTop() and 'Game lost focus' or 'Input state reset')
    end
end
return I

end
modules["lho.insec"] = function(require)
-- Bounded, resource-aware search. Only the next hop is issued; every later hop
-- is provisional and is rebuilt from observed positions before dispatch.
local U=require('lho.util')
local WardNames=require('lho.wardnames')
local I={};I.__index=I
local function cheaper(a,b) return a.cost==b.cost and a.time<b.time or a.cost<b.cost end
local function enqueue(heap,node)
    local n=#heap+1;heap[n]=node
    while n>1 do
        local parent=math.floor(n/2);if not cheaper(node,heap[parent]) then break end
        heap[n]=heap[parent];n=parent;heap[n]=node
    end
end
local function dequeue(heap)
    local top=heap[1];local last=table.remove(heap)
    if #heap>0 then
        local n=1;heap[1]=last
        while n*2<=#heap do
            local child=n*2
            if child+1<=#heap and cheaper(heap[child+1],heap[child]) then child=child+1 end
            if not cheaper(heap[child],last) then break end
            heap[n]=heap[child];n=child;heap[n]=last
        end
    end
    return top
end
function I.new(combat) return setmetatable({b=combat,ctx=combat.ctx},I) end
-- A close landing is an explicit fallback policy, not a global relaxation of
-- the configured ordinary landing margin. The kick angle/range still applies.
function I:landingMargin(step)
    if step and step.closeLanding and self.ctx.config:get('insecCloseWard') then return 80 end
    return self.ctx.config:get('insecLandingMargin')
end
function I:q2Continuation(i,unit,previous)
    local c=self.ctx
    if self.b.insec~=i or not c:enemyValid(i.target) or self.b:kickProtected(i.target)
        or not self:spellReady(3,true) or not U.valid(unit) then return nil end
    local future={};for k,v in pairs(i) do future[k]=v end
    future.used={};for k,v in pairs(i.used or {}) do future.used[k]=v end;future.used.q=true
    local dash=c.config:get('insecDashEstimate')/1000
    local horizon=dash+self.b.tactics:wardArrival()+c.latency+.25
    local function predict(u,lead)
        if not (u.pathing and u.pathing.hasMovePath) then return U.copy(u.pos) end
        if not u.GetPrediction then return nil end
        local ok,p=pcall(u.GetPrediction,u,math.huge,lead)
        if ok and U.position(p) then return U.copy(p) end
    end
    local center=predict(i.target,horizon);local landing=predict(unit,dash)
    if not center or not landing then return nil end
    local aim=i.destination or c.aim
    if i.locked and i.direction then aim={x=center.x+i.direction.x*1200,y=center.y,z=center.z+i.direction.z*1200} end
    if not aim or U.dist(center,aim)<10 then return nil end
    future.plannedTarget=center;future.plannedEndpoint=U.toward(center,aim,c.profile.kickDistance)
    future.stand=U.toward(center,aim,-math.min(c.config:get('insecStandDistance'),c.profile.rRange-45))
    local reserved=c:spell(0).mana or 0
    -- Fresh dispatch validation adapts the already selected continuation; it
    -- never repeats the full search or sends an input from the callback.
    local plan=previous and self:adapt(future,previous) or self:plan(future,landing,future.used,reserved)
    if plan and self:validate(future,plan,landing,reserved) then return plan end
end
function I:resourceOrderValid(i,steps)
    for n,step in ipairs(steps) do
        if step.kind=='ward' and n<#steps then
            -- A held insec never spends its ward merely to get Q in range.
            -- Preserve W for the kick-side reposition. Extra repositioning
            -- after the ward requires a shown/confirmed Flash continuation.
            if not (i.preview or i.flashConsent and i.contract) then return false end
            local flash=false
            for j=n+1,#steps do if steps[j].kind=='flash' then flash=true end end
            if not flash then return false end
        end
    end
    return true
end
function I:finishSideValid(i,step,from)
    if not step then return true end
    if step.kind=='q' and U.same(step.unit,i.target) then
        -- Q2 approaches the marked champion from the launch side. Comparing
        -- its current center with a forecast target center can falsely invent
        -- a landing behind them (Ward -> Q -> R). Require the actual approach
        -- side to agree too; a later ward/Flash or a different Q bridge remains valid.
        local near=U.toward(i.target.pos,from,100)
        return self.b:aligned(i.target,i.endpoint,near)
    end
    if step.kind=='ward' then
        return U.dist(step.pos,i.plannedTarget or i.target.pos)+1e-6>=self:landingMargin(step)
    end
    return true
end
function I:flashAllowed(i)
    if not self.ctx.config:get('insecFlash') then return false,'Flash proposals disabled' end
    if i and i.preview then return true,'Preview only: Flash may be proposed' end
    if i and i.flashConsent and i.contract then return true,'Flash explicitly approved with Alt release' end
    if self.ctx.config:get('insecFlashFallback') and i and not i.contract and not i.wardCommitted
        and not (i.used and i.used.w) and not self.ctx.wards:slot() then
        return true,'Flash fallback: no ready ward; no W already committed'
    end
    return false,'Ready ward / W committed / Flash needs Alt confirmation'
end
function I:spellReady(slot,forecast)
    local c=self.ctx
    if c:ready(slot) then return true end
    local spell=c:spell(slot)
    -- A current cast lock is not a future cooldown. Forecasts may retain the
    -- resource, but every actual dispatch still uses native readiness.
    return forecast and (slot>3 or (spell.level or 0)>0) and (spell.currentCd or 0)<=0
        and (spell.mana or 0)<=(myHero.mana or 0) or false
end
function I:flashSlot(forecast)
    local c=self.ctx
    for slot=4,5 do
        if U.name(c:spell(slot).name)=='summonerflash' and self:spellReady(slot,forecast) and not c.actions.pending[slot] then return slot end
    end
end
function I:units(target)
    local c=self.ctx;local q={target};local w={};local seen={[U.id(target) or target]=true};local wSeen={}
    if c.config:get('insecBridges') then
        for _,list in ipairs({c.enemies or {},c.minions or {}}) do for _,u in ipairs(list) do
            if U.valid(u) and u.team~=myHero.team and not seen[U.id(u) or u]
                and U.dist(myHero.pos,u.pos)<2200 then q[#q+1]=u;seen[U.id(u) or u]=true end
        end end
    end
    -- Bound expensive collision checks without changing the selected champion.
    table.sort(q,function(a,b)
        if U.same(a,b) then return false end
        if U.same(a,target) then return true elseif U.same(b,target) then return false end
        return U.dist(a.pos,target.pos)<U.dist(b.pos,target.pos)
    end)
    while #q>12 do table.remove(q) end
    for _,list in ipairs({c.wards:objects(),c.allies or {},c.minions or {}}) do for _,u in ipairs(list) do
        local name=U.name(u.charName)
        if U.valid(u) and not wSeen[U.id(u) or u] and u.team==myHero.team and not U.same(u,myHero) and name~='bluetrinket'
            and name~='farsightward' and name~='zombieward' and U.dist(myHero.pos,u.pos)<1800 then
            w[#w+1]=u;wSeen[U.id(u) or u]=true
        end
    end end
    table.sort(w,function(a,b)return U.dist(a.pos,target.pos)<U.dist(b.pos,target.pos) end)
    while #w>12 do table.remove(w) end
    return q,w
end
function I:plan(i,origin,used,reservedEnergy,checkpoint)
    local c=self.ctx;local forecast=origin~=nil;origin=origin or myHero.pos;used=used or i.used or {}
    local energyBudget=math.max(0,(myHero.mana or 0)-(reservedEnergy or 0)-(c:spell(3).mana or 0))
    local qUnits,wUnits=self:units(i.target)
    local stage=c:stage(0);local qReady=c.config:get('insecQ') and self:spellReady(0,forecast) and not used.q and not c.actions.pending[0]
    local qMana=c:spell(0).mana or 0;local wMana=c:spell(1).mana or 0
    local rank=math.max(1,c:spell(0).level or 1)
    local qDamage=(c.profile.qBase[rank] or 180)+c.profile.qRatio*(myHero.bonusDamage or 0)
    i.qOptions={ready=qReady,stage=stage,used=not not used.q,candidates={}}
    local marks={}
    if stage==2 then for _,u in ipairs(qUnits) do marks[u]=c:mark(u)~=nil end end
    local wReady=c.config:get('insecW') and self:spellReady(1,forecast) and c:stage(1)==1 and not c.actions.pending[1] and not used.w
    local flashAllowed,flashReason=self:flashAllowed(i)
    i.flashReason=flashReason
    local flash=flashAllowed and not used.f and self:flashSlot(forecast)
    local wardSlot=wReady and c.wards:slot()
    if i.contract then
        wardSlot=nil
        for n=i.contractIndex or 1,#i.contract do
            if i.contract[n].kind=='ward' then wardSlot=wReady and c.wards:itemSlot(i.contract[n].itemID);break end
        end
    end
    local wardRange=c.wards:range(wardSlot)
    i.resources={qReady=not not qReady,wReady=not not wReady,wardReady=wardSlot~=nil,
        wardSlot=wardSlot,flashReady=flash~=nil and flash~=false,flashReason=flashReason}
    local maxDepth=c.config:get('insecChains') and 3 or 1
    local best,expanded=nil,0;local collisionCache={};local visited={};local goals={i.stand}
    local wardArrival=self.b.tactics:wardArrival()
    -- Alternative distances on the same kick ray let tight wall boundaries
    -- work without changing the requested direction. No landing inside walls.
    for _,d in ipairs({180,300}) do
        local center=i.plannedTarget or i.target.pos
        local dx,dz=i.stand.x-center.x,i.stand.z-center.z
        goals[#goals+1]=U.toward(center,{x=center.x+dx,z=center.z+dz},d)
    end
    if c.config:get('insecCloseWard') then
        for _,d in ipairs({140,100,80}) do
            if d<c.config:get('insecLandingMargin') then
                goals[#goals+1]=U.toward(i.plannedTarget or i.target.pos,i.plannedEndpoint or i.endpoint,-d)
            end
        end
    end
    local function ground(p) return c.terrain:wall(p)==false end
    local function expected(node) return i.contract and i.contract[(i.contractIndex or 1)+#node.steps] end
    local function permits(node,kind,unit)
        if not i.contract then return true end
        local e=expected(node)
        return e and e.kind==kind and (not e.unitID or e.unitID==U.id(unit))
    end
    local function qClear(u,from)
        local key=tostring(U.id(u))..':'..math.floor(from.x)..':'..math.floor(from.z)
        if collisionCache[key]==nil then
            if checkpoint then checkpoint() end
            local p=u.pos
            if U.dist(from,myHero.pos)<1 then p=c.spells:predict(u) end
            collisionCache[key]=p~=nil and #c.spells:blockers(u,p,from)==0 and not c.spells:projectileWall(p,from,U.id(u))
        end
        return collisionCache[key]
    end
    local function terminal(node)
        if not self:resourceOrderValid(i,node.steps) then return false end
        local last=node.steps[#node.steps]
        local before=#node.steps>1 and node.steps[#node.steps-1].pos or origin
        if not self:finishSideValid(i,last,before) then return false end
        if self.b:planAligned(i,node.pos) then return true end
        for _,goal in ipairs(goals) do
            local d=U.dist(node.pos,goal)
            local walkTime=d/math.max(1,myHero.ms or 350)
            local viable=true
            if d<=c.config:get('insecWalk') and i.target.GetPrediction and i.target.pathing and i.target.pathing.hasMovePath then
                local ok,future=pcall(i.target.GetPrediction,i.target,math.huge,node.time+walkTime+c.latency+.25)
                local center=i.plannedTarget or i.target.pos;local endpoint=i.plannedEndpoint or i.endpoint
                local aim=ok and U.position(future) and {x=future.x+endpoint.x-center.x,y=future.y,z=future.z+endpoint.z-center.z}
                viable=aim and self.b:aligned({pos=future},aim,goal)
            end
            if d<=c.config:get('insecWalk') and viable and ground(goal) and c.terrain:walkLine(node.pos,goal,35) then
                node.walk=goal;node.walkDistance=U.dist(goal,i.plannedTarget or i.target.pos)
                node.walkTime=walkTime;return true
            end
        end
    end
    local queue={{pos=origin,used={q=used.q,w=used.w,f=used.f},steps={},cost=0,time=0,energy=0}}
    local function push(node,kind,p,unit,cost,energy,dt)
        if not permits(node,kind,unit) or not ground(p) or node.energy+energy>energyBudget then return end
        local steps={};for n,s in ipairs(node.steps) do steps[n]=s end
        local step={kind=kind,pos=U.copy(p),unit=unit}
        if kind=='ward' then step.itemID=myHero:GetItemData(wardSlot).itemID end
        for _,goal in ipairs(goals) do
            if (kind=='ward' or kind=='flash') and U.dist(p,goal)<1 then step.goalDistance=U.dist(goal,i.plannedTarget or i.target.pos);break end
        end
        if kind=='ward' and step.goalDistance and step.goalDistance<c.config:get('insecLandingMargin') then
            step.closeLanding=c.config:get('insecCloseWard') and true or nil
        end
        steps[#steps+1]=step
        local mask={q=node.used.q,w=node.used.w,f=node.used.f}
        mask[kind=='q' and 'q' or kind=='flash' and 'f' or 'w']=true
        -- An optimistic remaining-distance bound discards bridge detours that
        -- cannot reach even R range with every remaining resource. This does
        -- not replace terrain/collision or exact kick-alignment validation.
        local reach=c.profile.rRange+c.config:get('insecWalk')
        if qReady and not mask.q then reach=reach+math.max(c.profile.qRange,c.profile.q2Range) end
        if wReady and not mask.w then reach=reach+c.profile.wRange end
        if flash and not mask.f then reach=reach+400 end
        if U.dist(p,i.target.pos)>reach then return end
        local key=(mask.q and 'q' or '')..(mask.w and 'w' or '')..(mask.f and 'f' or '')
            ..':'..math.floor(p.x/5)..':'..math.floor(p.z/5)
        local total=node.cost+cost;local time=node.time+dt;local prior=visited[key]
        if prior and (prior.cost<total or prior.cost==total and prior.time<=time) then return end
        visited[key]={cost=total,time=time}
        if #queue>=512 or best and total>best.cost then return end
        enqueue(queue,{pos=p,steps=steps,used=mask,cost=total,time=time,energy=node.energy+energy})
    end
    while #queue>0 and expanded<96 do
        local node=dequeue(queue);expanded=expanded+1
        if checkpoint then checkpoint() end
        if best and node.cost>best.cost then break end
        if terminal(node) then
            node.time=node.time+(node.walkTime or 0)
            if not best or node.cost<best.cost or node.cost==best.cost and node.time<best.time then best=node end
        elseif #node.steps<maxDepth then
            if wReady and not node.used.w then
                for _,u in ipairs(wUnits) do if permits(node,'w',u) and U.dist(node.pos,u.pos)<=c.profile.wRange then
                    push(node,'w',u.pos,u,1,wMana,.2)
                end end
                if wardSlot and permits(node,'ward') then
                    local destinations={};for _,goal in ipairs(goals) do
                        destinations[#destinations+1]=U.dist(node.pos,goal)<=wardRange and goal or U.toward(node.pos,goal,wardRange-15)
                    end
                    for _,u in ipairs(qUnits) do
                        -- Enables W -> Q -> Flash as well as Q -> W -> Flash.
                        if U.dist(node.pos,u.pos)>c.profile.qRange then destinations[#destinations+1]=U.toward(node.pos,u.pos,wardRange-15) end
                    end
                    for _,p in ipairs(destinations) do push(node,'ward',p,nil,3,wMana,wardArrival) end
                end
            end
            if qReady and not node.used.q then
                for _,u in ipairs(qUnits) do
                    local d=U.dist(node.pos,u.pos);local marked=marks[u]
                    local viable=permits(node,'q',u) and (marked and d<=c.profile.q2Range or stage==1 and d<=c.profile.qRange and qClear(u,node.pos))
                    if #node.steps==0 then
                        i.qOptions.candidates[#i.qOptions.candidates+1]={id=U.id(u),name=u.charName,pos=U.copy(u.pos),
                            hp=u.health,distance=d,marked=not not marked,
                            reason=not permits(node,'q',u) and 'Confirmed resources exclude this bridge'
                                or d>(marked and c.profile.q2Range or c.profile.qRange) and 'Out of Q range'
                                or not viable and 'Prediction / collision / Q stage'
                                or not marked and u.health<=qDamage+20 and 'Q1 may kill bridge'
                                or d<=100 and 'No useful Q displacement' or 'Entry candidate; continuation still required'}
                    end
                    -- A bridge killed by Q1 cannot carry Q2. Unknown monster
                    -- coefficients get a conservative raw upper estimate here.
                    if viable and (marked or u.health>qDamage+20) and d>100 then
                        local energy=marked and qMana or qMana+50
                        push(node,'q',u.pos,u,2,energy,marked and .2 or .25+d/c.profile.qSpeed+.2)
                    end
                end
            end
            if flash and not node.used.f and permits(node,'flash') then
                local destinations={};for _,goal in ipairs(goals) do
                    destinations[#destinations+1]=U.dist(node.pos,goal)<=400 and goal or U.toward(node.pos,goal,390)
                end
                for _,u in ipairs(qUnits) do if U.dist(node.pos,u.pos)>c.profile.qRange then
                    destinations[#destinations+1]=U.toward(node.pos,u.pos,390)
                end end
                for _,p in ipairs(destinations) do push(node,'flash',p,nil,20,0,.08) end
            end
        end
    end
    if best then
        local labels={};for _,s in ipairs(best.steps) do
            local label=s.kind=='ward' and 'Ward / W' or s.kind=='flash' and 'Flash' or s.kind=='w' and 'Existing W'
                or ((stage==2 and 'Q2' or 'Q1 > Q2')..' ['..(s.unit.charName or 'bridge')..']')
            if s.kind=='ward' then label=label..' ['..(WardNames[s.itemID] or 'item '..tostring(s.itemID))..']' end
            labels[#labels+1]=label
        end
        if best.walk then labels[#labels+1]='Walk correction' end
        labels[#labels+1]='R';best.label=table.concat(labels,' > ')
    end
    i.searchNodes=expanded;return best
end
-- Search can yield between bounded graph/collision operations. Drawing never
-- invokes this search. A confirmed resource contract greatly narrows the graph.
function I:search(i,origin,reserved)
    if i.contract then return self:plan(i,origin,nil,reserved) end
    local now=self.ctx:now();local j=i.search
    local context=origin and 'forecast' or 'current'
    if not j or j.context~=context or j.reserved~=(reserved or 0) or j.target~=U.id(i.target)
        or j.done and now-j.at>=.06 or not j.done and now-j.at>.75 then
        local snapshot={};for k,v in pairs(i) do snapshot[k]=v end
        snapshot.stand=U.copy(i.stand);snapshot.endpoint=U.copy(i.endpoint)
        snapshot.used={};for k,v in pairs(i.used or {}) do snapshot.used[k]=v end
        j={at=now,origin=U.copy(origin or myHero.pos),context=context,reserved=reserved or 0,
            target=U.id(i.target),snapshot=snapshot,operations=0}
        j.work=coroutine.create(function()return self:plan(snapshot,j.origin,nil,reserved,function()coroutine.yield()end)end)
        i.search=j
    end
    if not j.done and j.stepAt~=now then
        j.stepAt=now
        local started=GetTickCount and GetTickCount()
        for n=1,24 do
            j.operations=j.operations+1
            local ok,result=coroutine.resume(j.work)
            if not ok then j.done=true;j.result=nil;if self.ctx.config.capture then self.ctx:trace('insec_search_error',{reason=tostring(result)},'search',1) end;break end
            if coroutine.status(j.work)=='dead' then j.done=true;j.result=result;break end
            -- Bound work between native calls. One native prediction call can
            -- still overrun; Lua cannot interrupt that call safely.
            if n>=2 and started and GetTickCount()-started>=2 then break end
        end
        if j.done then
            i.searchNodes=j.snapshot.searchNodes or 0
            if self.ctx.config.capture then self.ctx:trace('insec_search_timing',{elapsed=now-j.at,nodes=i.searchNodes,operations=j.operations,found=j.result~=nil},'search',1) end
            i.qOptions=j.snapshot.qOptions
            i.resources=j.snapshot.resources;i.flashReason=j.snapshot.flashReason
            if self.ctx.config.capture then self.ctx:trace('insec_q_options',{target=U.id(i.target),options=i.qOptions,found=j.result~=nil},'options',.5) end
        end
    end
    if j.done then return j.result end
    return i.plan
end
function I:blockedReason(i)
    if i.contract then return 'Confirmed plan blocked; hold Alt to revise' end
    local r=i.resources
    if r and not r.qReady then return 'Waiting for Q readiness / a complete kick route' end
    if r and not r.wardReady and not r.flashReady then
        return 'No ready ward or authorized Flash; no Q-only kick route'
    end
    if r and not r.wReady and not r.flashReady then return 'W unavailable; no Q-only kick route' end
    return 'No complete kick route: checking range, collision and landing'
end
function I:adapt(i,plan)
    if not plan then return end
    local out={steps={},label=plan.label,cost=plan.cost,time=plan.time,walkDistance=plan.walkDistance}
    if plan.walk then out.walk=plan.walkDistance and U.toward(i.plannedTarget or i.target.pos,i.plannedEndpoint or i.endpoint,-plan.walkDistance) or U.copy(plan.walk) end
    for _,s in ipairs(plan.steps) do
        local p=s.unit and s.unit.pos or s.pos
        if s.goalDistance then p=U.toward(i.plannedTarget or i.target.pos,i.plannedEndpoint or i.endpoint,-s.goalDistance) end
        out.steps[#out.steps+1]={kind=s.kind,pos=U.copy(p),unit=s.unit,itemID=s.itemID,goalDistance=s.goalDistance,closeLanding=s.closeLanding}
    end
    return out
end
function I:validate(i,plan,origin,reserved)
    if not plan or not self:resourceOrderValid(i,plan.steps) then return false end
    local c=self.ctx;local from=origin or myHero.pos;local energy=(myHero.mana or 0)-(reserved or 0)-(c:spell(3).mana or 0)
    for n,step in ipairs(plan.steps) do
        if n==#plan.steps and not self:finishSideValid(i,step,from) then return false end
        if i.contract then
            local expected=i.contract[(i.contractIndex or 1)+n-1]
            if not expected or expected.kind~=step.kind or expected.unitID and expected.unitID~=U.id(step.unit)
                or expected.itemID and expected.itemID~=step.itemID then return false end
        end
        if not step.pos or c.terrain:wall(step.pos)~=false then return false end
        local d=U.dist(from,step.pos)
        if step.kind=='q' then
            if not U.valid(step.unit) or not self:spellReady(0,origin~=nil) then return false end
            local marked=c:mark(step.unit) and c:stage(0)==2
            if marked then if d>c.profile.q2Range then return false end
            elseif step.unit.health<=((c.profile.qBase[c:spell(0).level or 1] or 0)+c.profile.qRatio*(myHero.bonusDamage or 0))+20
                or c:stage(0)~=1 or d>c.profile.qRange or #c.spells:blockers(step.unit,step.pos,from)>0
                or c.spells:projectileWall(step.pos,from,U.id(step.unit)) then return false end
            energy=energy-(c:spell(0).mana or 0)-(marked and 0 or 50)
        elseif step.kind=='w' or step.kind=='ward' then
            local wardSlot=step.kind=='ward' and c.wards:itemSlot(step.itemID)
            if step.kind=='ward' and not wardSlot then return false end
            if not self:spellReady(1,origin~=nil) or c:stage(1)~=1 or c.actions.pending[1]
                or d>(step.kind=='ward' and c.wards:range(wardSlot) or c.profile.wRange) then return false end
            if step.kind=='w' and (not U.valid(step.unit) or step.unit.team~=myHero.team) then return false end
            energy=energy-(c:spell(1).mana or 0)
        elseif step.kind=='flash' then
            if not self:flashAllowed(i) or not self:flashSlot(origin~=nil) or d>400 then return false end
        else return false end
        if energy<0 then return false end
        from=step.pos
    end
    if plan.walk then
        if U.dist(from,plan.walk)>c.config:get('insecWalk') or not c.terrain:walkLine(from,plan.walk,35) then return false end
        from=plan.walk
    end
    return self.b:planAligned(i,from)
end
function I:committed(i,aim)
    if self.ctx.config:get('aimLock')~=3 and not i.locked then
        i.destination=U.copy(aim);i.locked=true
        local d=U.toward(i.target.pos,aim,1);i.direction={x=d.x-i.target.pos.x,z=d.z-i.target.pos.z}
    end
end
function I:tick(i,aim)
    local c=self.ctx;local now=c:now();i.used=i.used or {};i.orbwalking=false
    -- Requesting a ward reserves W; it does not prove that W was consumed.
    -- Keep the exact attempt identity so a later cancelled input can release
    -- its reservation without confusing another jump or replaying a sent W.
    local ward=i.wardAttempt
    if ward and c.wards.pending~=ward then
        if ward.cancelled and c:stage(1)==1 and c:ready(1) and not c.actions.pending[1] and not c:dash() then
            local wEvent=ward.event and ward.event.slot==1 and ward.event or ward.earlyEvent
            local state=wEvent and c.actions.inputAction and c.actions:inputAction(wEvent.cursorID)
            local unsent=not wEvent or state and state.state=='cancelled_before_send' and not state.sentAt
                or not c.actions.api and wEvent.status=='cancelled' and not wEvent.keyAt
            if unsent then
                local placement=ward.event and c.actions.inputAction and c.actions:inputAction(ward.event.cursorID)
                local placementUnsent=placement and placement.state=='cancelled_before_send' and not placement.sentAt
                    or not c.actions.api and ward.event and ward.event.status=='cancelled' and not ward.event.keyAt
                i.used.w=nil;i.search=nil;i.plan=nil;i.phase='replan'
                if placementUnsent then i.wardCommitted=nil end
                if i.contract and ward.contractIndex and placementUnsent then
                    i.contractIndex=ward.contractIndex
                end
                if c.config.capture then c:log('insec_resource_released',{resource='w',reason=ward.cancelReason,evidence='Cancelled jump; W not sent and still ready'}) end
                i.wardAttempt=nil
            end
        elseif not ward.cancelled or c:stage(1)==2 then i.wardAttempt=nil end
    end
    if c.actions.syncWindow then
        for _,name in ipairs({'flight','qWait'}) do
            local window=i[name]
            if window then
                local state=c.actions:syncWindow(window)
                if state=='waiting' or state=='uncertain' then i.resource='Waiting for input confirmation';return end
                if state=='cancelled' then
                    local event=window.event
                    if event then
                        local resource=event.slot==0 and 'q' or event.slot==1 and 'w' or event.slot>=4 and 'f'
                        if resource then i.used[resource]=nil end
                        if event.contractIndex then i.contractIndex=event.contractIndex end
                    end
                    i[name]=nil;i.search=nil;i.plan=nil;i.phase='replan'
                end
            end
        end
    end
    -- Even while a hop is in flight the overlay tracks the current target.
    -- Already-issued movement cannot be retargeted by pretending its endpoint
    -- moved. Replan only from its confirmed landing before spending more.
    if c.wards.pending then
        local p=c.wards.pending
        if p.owner=='insec' then
            i.plan=self:search(i,p.target and p.target.pos or p.pos,p.state~='jumping' and (c:spell(1).mana or 0) or 0)
            i.resource=i.plan and ('Wardjump in flight > '..i.plan.label) or 'Wardjump: kick currently unreachable'
            if not i.plan and (i.contract or i.search and i.search.done) and p.state~='jumping' then
                c.wards:cancel('Target moved beyond remaining insec resources')
            end
        end
        return
    end
    if i.flight then
        local f=i.flight
        i.plan=self:search(i,f.unit and f.unit.pos or f.pos)
        i.resource=i.plan and ('In flight > '..i.plan.label) or 'In flight: kick currently unreachable'
        if c:dash() then return end
        if U.dist(myHero.pos,f.origin)>60 and (not f.event or f.event.status=='observed' or f.event.status=='completed') then i.flight=nil;i.search=nil;i.plan=nil
        elseif now>f.deadline then i.flight=nil;i.search=nil;i.plan=nil;i.phase='replan'
        else return end
    end
    if c:dash() then return end
    if self.b:kickValid(i) then
        local ok,event=c.spells:r(i.target,'insec',true)
        if ok then i.phase='kick';i.event=event end
        return
    end
    if i.qWait then
        local q=i.qWait
        -- Q can hit a different valid anchor after the prediction was made.
        -- Adopt observed owned marks, then validate the complete continuation.
        -- An explicitly confirmed anchor remains part of the user's contract.
        if not i.contract and c:stage(0)==2 and not c:mark(q.unit) then
            for _,unit in ipairs(self:units(i.target)) do
                if U.valid(unit) and c:mark(unit) then
                    if c.config.capture then c:log('insec_q_anchor_changed',{expected=U.id(q.unit),observed=U.id(unit)}) end
                    q.unit=unit;i.search=nil;i.plan=nil;break
                end
            end
        end
        local marked=U.valid(q.unit) and c:mark(q.unit) and c:stage(0)==2
        -- The missile arrival deadline is not the Q2 recast deadline. CC or
        -- another native cast lock can outlast arrival while the mark survives.
        if marked then
            q.markSeen=true;q.deadline=now+c:markLeft(q.unit)
            i.plan=self:q2Continuation(i,q.unit)
            if i.plan then
                local continuation=i.plan
                local ok,event=c.spells:q2(q.unit,'insec',true,nil,nil,function()
                    return self:q2Continuation(i,q.unit,continuation)~=nil,'insec_continuation_unreachable'
                end)
                if c.config.capture then c:trace('insec_q2_decision',{target=U.id(q.unit),marked=true,markLeft=c:markLeft(q.unit),
                    qReady=c:ready(0),rReady=c:ready(3),plan=i.plan.label,requested=ok},'q2',.15) end
                if ok then
                    i.qWait=nil;i.search=nil;i.phase='Q2 entry';i.flight={origin=U.copy(myHero.pos),pos=U.copy(q.unit.pos),unit=q.unit,event=event,deadline=now+1}
                end
            else
                i.resource='Q marked; kick currently unreachable'
                if c.config.capture then c:trace('insec_q2_decision',{target=U.id(q.unit),marked=true,markLeft=c:markLeft(q.unit),
                    requested=false,reason='No valid continuation from Q2 landing'},'q2',.15) end
            end
            return
        elseif not U.valid(q.unit) or now>q.deadline or q.markSeen and c:stage(0)~=2 then
            if c.config.capture then c:trace('insec_q_wait_ended',{target=U.id(q.unit),markSeen=q.markSeen,
                deadline=q.deadline,stage=c:stage(0)},'qwait',.15) end
            i.qWait=nil;i.used.q=nil;i.search=nil;i.phase='replan'
        else return end
    end
    local plan=self:adapt(i,self:search(i));i.plan=plan
    if plan and not self:validate(i,plan) then plan=nil end
    if c.config.capture then c:trace('insec_plan',{target=U.id(i.target),targetPos=U.copy(i.target.pos),origin=U.copy(myHero.pos),
        stand=U.copy(i.stand),endpoint=U.copy(i.endpoint),plan=plan and plan.label,
        wardSlot=c.wards:slot(),wStage=c:stage(1),wReady=c:ready(1),flashReason=i.flashReason,
        energy=myHero.mana,expanded=i.searchNodes,resources=i.resources,
        blocked=not plan and self:blockedReason(i) or nil},tostring(U.id(i.target)),.5) end
    if not plan then
        i.orbwalking=true;i.phase='cursor orbwalk';i.resource=self:blockedReason(i)
        return
    end
    i.resource=plan.label;i.phase='replan'
    local step=plan.steps[1]
    if not step then if plan.walk then c.actions:move(plan.walk,'insec') end;return end
    local ok,event
    if step.kind=='ward' then
        self.b:geometry(i,true)
        plan=self:adapt(i,plan)
        if not self:validate(i,plan) then i.search=nil;return end
        i.plan=plan;step=plan.steps[1]
        i.resource=#plan.steps==1 and not plan.walk and 'Ward / W' or plan.label
        ok=c.wards:start(step.pos,'insec',true,step.itemID)
        if ok then
            i.used.w=true;i.wardCommitted=true;i.phase='wardjump';i.wardAttempt=c.wards.pending
            if i.wardAttempt then i.wardAttempt.contractIndex=i.contractIndex or 1 end
        end
    elseif step.kind=='w' then
        if c.wards:jumpable(step.unit) then ok,event=c.spells:w(step.unit,'insec',true) end
        if ok then i.used.w=true;i.phase='W entry' end
    elseif step.kind=='flash' then
        if c:ready(3) then ok,event=c.spells:flash(step.pos,'insec') end
        if ok then i.used.f=true;i.phase='Flash' end
    elseif step.kind=='q' then
        if c:stage(0)==2 then
            local continuation=self:q2Continuation(i,step.unit)
            if continuation then
                ok,event=c.spells:q2(step.unit,'insec',true,nil,nil,function()
                    return self:q2Continuation(i,step.unit,continuation)~=nil,'insec_continuation_unreachable'
                end)
            else i.resource='Q marked; predicted kick landing unavailable';i.search=nil end
            if ok then i.used.q=true;i.phase='Q2 entry' end
        else
            -- Re-predict and collision-check from the actual casting position.
            ok,event=c.spells:q1(step.unit,'insec',false)
            if ok then
                i.used.q=true;i.phase='Waiting for Q mark'
                i.qWait={unit=step.unit,event=event,deadline=now+.25+U.dist(myHero.pos,step.unit.pos)/c.profile.qSpeed+math.max(.4,c.latency*2+c.jitter*3)}
            end
        end
    end
    if ok then
        if event then event.contractIndex=i.contractIndex or 1 end
        i.commitAt=i.commitAt or now
        if i.contract then i.contractIndex=(i.contractIndex or 1)+1 end
        i.search=nil
        self:committed(i,aim)
        if event and not i.qWait then i.flight={origin=U.copy(myHero.pos),pos=U.copy(step.pos),unit=step.unit,event=event,deadline=now+1} end
        if c.config.capture then c:log('insec_hop',{name=step.kind,plan=plan.label,target=U.id(i.target),origin=U.copy(myHero.pos),
            destination=U.copy(step.pos),wardSlot=c.wards:slot(),flashReason=i.flashReason}) end
    end
end
return I

end
modules["lho.intent"] = function(require)
-- Lee gameplay policy only. Orbama owns queuing, input, priorities and cleanup.
local I={}
local held={fight=true,harass=true,clear=true,gg_last=true,q=true,secure=true,farm=true}
function I.origin(c,owner)
    if owner=='clear' and c.mode=='gg_last' then return 'gg_last' end
    if owner=='harass' and c.mode=='clear' then return 'clear' end
    if held[owner] and c.mode==owner then return owner end
end
function I.valid(c,origin)
    if not origin then return true end
    if c.mode~=origin then return false,'mode_changed' end
    if origin=='farm' and (not c.config:get('autoJungle') or c.input.farmPaused) then
        return false,'autojungle_stopped'
    end
    return true
end
function I.priority(owner,execute)
    if execute then return 'critical' end
    if owner=='ward' or owner=='insec' or owner=='fight' or owner=='defense' or owner=='secure' then return 'interactive' end
    if owner=='farm' or owner=='clear' or owner=='expiry' then return 'background' end
    return 'normal'
end
return I

end
modules["lho.kickplan"] = function(require)
-- At most five champion primaries and five kick directions. No summoners.
local U=require('lho.util')
local K={};K.__index=K
function K.new(ctx) return setmetatable({ctx=ctx},K) end
function K:predict(unit,delay)
    local now=self.ctx:now()
    if self.predictionAt~=now then self.predictionAt=now;self.predictions={} end
    -- Share equivalent arrival estimates across the bounded direction search.
    -- Never carry predictions into the next game tick.
    local bucket=math.floor(delay/.025+.5);local key=tostring(U.id(unit))..':'..bucket
    local cached=self.predictions[key]
    if cached then return cached.valid and cached.pos or nil end
    local predicted
    if unit.GetPrediction and unit.pathing and unit.pathing.hasMovePath then
        local ok,p=pcall(unit.GetPrediction,unit,math.huge,bucket*.025)
        if ok and p and type(p.x)=='number' and type(p.z)=='number' and p.x==p.x and p.z==p.z
            and math.abs(p.x)<100000 and math.abs(p.z)<100000 then predicted=U.copy(p) end
    else predicted=U.copy(unit.pos) end
    self.predictions[key]={valid=predicted~=nil,pos=predicted}
    return predicted
end
function K:evaluate(primary,origin,ward)
    local c=self.ctx;local b=c.combat
    if not c:enemyValid(primary) or b:kickProtected(primary) then return end
    local delay=.25+(ward and b.tactics:wardArrival() or 0)
    local start=self:predict(primary,delay)
    if not start or U.dist(origin,start)>c.profile.rRange or U.dist(origin,start)<25 then return end
    local endpoint=U.toward(origin,start,U.dist(origin,start)+c.profile.kickDistance)
    local result={primary=primary,origin=U.copy(origin),endpoint=endpoint,hits=1,kills=0,secondaryKills=0,
        damage=0,ward=ward,hitIDs={[U.id(primary)]=true},impactDelay=delay}
    local damage=c:combatDamage(3,primary)
    local margin=c.config:get('combatDamageMargin')
    local lock=c:locked()
    local function add(unit,value,secondary)
        result.damage=result.damage+math.min(value,U.effectiveHP(unit))
        if U.same(unit,lock) then result.lockDamage=math.min(value,U.effectiveHP(unit)) end
        if value>=U.effectiveHP(unit)+margin+(unit.hpRegen or 0)*(delay+.6) then
            result.kills=result.kills+1
            if U.same(unit,lock) then result.lockKill=1 end
            if secondary then result.secondaryKills=result.secondaryKills+1 end
        end
    end
    add(primary,damage,false)
    -- Current normal League retains the flying body after death (Riot 26.10).
    -- Do not import that mechanic into Classic; omit uncertain lethal carriers.
    local carrier=c.profile.id=='normal' or primary.health>c:spellDamageEstimate(3,primary)+margin
    if carrier then
        for _,enemy in ipairs(c.enemies or {}) do
            if c:enemyValid(enemy) and not result.hitIDs[U.id(enemy)] and not b:kickProtected(enemy) then
                local _,fraction=U.segment(enemy.pos,start,endpoint)
                local predicted=self:predict(enemy,delay+.6*fraction)
                if predicted then
                    local d,t=U.segment(predicted,start,endpoint)
                    local radius=math.min(100,primary.boundingRadius or 65)+(enemy.boundingRadius or 65)
                    if t>0 and t<1 and d<=radius-10 then
                        result.hits=result.hits+1;result.hitIDs[U.id(enemy)]=true
                        -- Base R against the secondary target's own resistances.
                        -- Unverified bonus-health collateral is not counted.
                        add(enemy,c:combatDamage(3,enemy),true)
                    end
                end
            end
        end
    end
    if lock and not result.hitIDs[U.id(lock)] then return end
    result.worthwhile=result.hits>=2 and ((c.config:get('multi') and result.hits>=math.max(2,c.config:get('multiHits')))
        or (c.config:get('collateralKills') and result.secondaryKills>0))
    result.score=result.kills*10000+result.hits*1000+result.damage*.05-(ward and 200 or 0)
    return result
end
function K:better(candidate,best)
    if not best then return true end
    -- Lexicographic priorities cannot be overturned by a damage-score scale.
    for _,field in ipairs({'lockKill','lockDamage','kills','hits','damage'}) do
        local a,b=candidate[field] or 0,best[field] or 0
        if a~=b then return a>b end
    end
    return best.ward and not candidate.ward
end
function K:best(reposition)
    local c=self.ctx;local best
    if #(c.enemies or {})<2 or not c.config:get('multi') and not c.config:get('collateralKills') then return end
    reposition=reposition and c.config:get('comboWard') and c.config:get('comboW') and c.wards:available()
        and not c.wards.pending and c:now()>=(c.wards.fightRetryAt or 0)
    local wardRange=reposition and c.wards:range() or 0
    -- No prediction or ward search for a single eligible champion. The second
    -- champion may be outside R range, but must be reachable by the kicked body.
    local nearby=0
    local reach=c.profile.rRange+c.profile.kickDistance+wardRange+250
    for _,enemy in ipairs(c.enemies or {}) do
        if c:enemyValid(enemy) and U.dist(myHero.pos,enemy.pos)<=reach and not c.combat:kickProtected(enemy) then nearby=nearby+1 end
    end
    if nearby<2 then return end
    if not c.config:get('collateralKills') and nearby<math.max(2,c.config:get('multiHits')) then return end
    for n,primary in ipairs(c.enemies or {}) do
        if n>5 then break end
        if c:enemyValid(primary) and U.dist(myHero.pos,primary.pos)<=c.profile.rRange+wardRange+100
            and not c.combat:kickProtected(primary) then
            local direct=self:evaluate(primary,myHero.pos,false)
            if direct and direct.worthwhile and self:better(direct,best) then best=direct end
            if reposition and U.dist(myHero.pos,primary.pos)<wardRange+c.profile.rRange then
                for m,other in ipairs(c.enemies or {}) do
                    if m>5 then break end
                    if c:enemyValid(other) and not U.same(primary,other) then
                        local arrival=.25+c.combat.tactics:wardArrival()
                        local collateral=.6*U.clamp(U.dist(primary.pos,other.pos)/c.profile.kickDistance,0,1)
                        local a,b=self:predict(primary,arrival),self:predict(other,arrival+collateral)
                        local stand=a and b and U.toward(a,b,-180)
                        if stand and U.dist(myHero.pos,stand)<=wardRange and not c:underTurret(stand)
                            and c.terrain:wall(stand)==false and c.wards:canStart(stand) then
                            local plan=self:evaluate(primary,stand,true)
                            if plan and plan.worthwhile and (not direct or not direct.worthwhile
                                or plan.kills>direct.kills or plan.hits>direct.hits)
                                and self:better(plan,best) then best=plan end
                        end
                    end
                end
            end
        end
    end
    return best
end
return K

end
modules["lho.leveling"] = function(require)
-- Skill allocation is independent of farming, inventory and recovery.
local L={};L.__index=L
function L.new(ctx) return setmetatable({ctx=ctx,nextAt=0},L) end
function L:cancel()
    if self.ctx.actions.api then self.ctx.actions:cancel('level') end
    self.pending=nil;self.request=nil
end
function L:eligible(slot,rank)
    local c=self.ctx
    return c.config:get('level') and not c:blocked() and not c:recalling() and not c:dash()
        and not c.wards.pending and not c.combat.insec and not c.input:held('wardKey')
        and ((myHero.levelData or {}).lvlPts or 0)>0 and (c:spell(slot).level or 0)==rank
end
function L:submit(keys,validate)
    local c=self.ctx
    if c.actions.api then return c.actions:keyAction(keys,'level','chord',validate) end
    if c.sdk.Input and c.sdk.Input.SendKeys then return c.sdk.Input:SendKeys(keys,'level') end
    return false,'Owned key dispatcher unavailable',false
end
function L:tick()
    local c=self.ctx;local now=c:now()
    if not c.config:get('level') then self:cancel();return end
    if self.pending then
        local p=self.pending
        if (c:spell(p.slot).level or 0)>p.rank then
            if c.config.capture then c:log('skill_level_confirmed',{name=tostring(p.slot)}) end
            self.pending=nil
        elseif now>=p.deadline then
            if c.config.capture then c:log('skill_level_unconfirmed',{name=tostring(p.slot)}) end
            self.pending=nil;self.nextAt=now+2
        end
        return
    end
    local data=myHero.levelData or {};local points=data.lvlPts or 0
    if points<=0 then self:cancel();return end
    if now<self.nextAt or c:blocked() or c:recalling() or c:dash() or c.wards.pending
        or c.combat.insec or c.input:held('wardKey') or c.actions:cursorBusy() then return end
    local slot;local lvl=data.lvl or 1;local ranks={}
    for s=0,3 do ranks[s]=c:spell(s).level or 0 end
    if lvl>=6 and ranks[3]<math.min(3,math.floor((lvl-1)/5)) then slot=3 end
    if slot==nil then
        for _,s in ipairs({1,2,0}) do if ranks[s]==0 then slot=s;break end end
        if slot==nil then for _,s in ipairs({0,1,2}) do if ranks[s]<math.min(5,math.ceil(lvl/2)) then slot=s;break end end end
    end
    if slot==nil then return end
    if Control.IsKeyDown and (Control.IsKeyDown(16) or Control.IsKeyDown(17) or Control.IsKeyDown(18)) then return end
    local rank=ranks[slot];local keys={HK_LUS or 17,({HK_Q,HK_W,HK_E,HK_R})[slot+1]}
    local ok,accepted,reason,sent=pcall(self.submit,self,keys,function()return self:eligible(slot,rank) end)
    if ok and accepted or ok and sent then
        -- An uncertain submission is observed, never immediately replayed.
        self.pending={slot=slot,rank=rank,deadline=now+.7};self.nextAt=now+.3
    elseif not ok or reason~='waiting' then
        self.nextAt=now+1
        if c.config.capture then c:log('skill_level_declined',{reason=tostring(ok and reason or accepted)}) end
    end
end
return L

end
modules["lho.menuicons"] = function(require)
-- Semantic menu icons, independent of the active provider. Missing art stays empty.
local M={}
local art={Q='/LHO_LeeSinQ.png',W='/LHO_LeeSinW.png',E='/LHO_LeeSinE.png',R='/LHO_LeeSinR.png',
    passive='/LHO_Passive.png',hero='/LHO_LeeSin.png',guide='/LHO_Guide.png',ward='/3340.png',
    target='/Gamsteron_TargetSelector.png',move='/Gamsteron_Orbwalker.png',draw='/Gamsteron_Drawings.png',
    smite='/Gamsteron_Spell_SummonerSmite.png',flash='/Gamsteron_Spell_SummonerFlash.png',
    ignite='/Gamsteron_Spell_SummonerDot.png',potion='/2003.png',minion='/Gamsteron_Minion.png',
    items='/ActivatorScriptLogo.png',cleanse='/3140.png',shield='/3190.png',slow='/3143.png',speed='/3142.png'}
local exact={Controls='hero',Combat='target',Harass='Q',Assists='W',Insec='R',Wave='minion',
    LastHit='minion',Jungle='smite',Wardjump='ward',Farming='move',SmiteItems='items',Drawings='draw',Guide='guide',
    Status='hero',Damage='target',WardRange='ward',Abilities='passive',Chase='move',Finishes='R',
    Targeting='target',Resources='ward',Flash='flash',Potions='potion',Items='items',Smite='smite',
    cursorKey='R',allyKey='R',insecPreviewKey='R',wardKey='ward',autoJungleKey='move',qAssistKey='Q',
    smiteKey='smite',secureKey='smite',guideKey='guide',guideOpen='guide',guidePage='guide',
    comboPassive='passive',comboBurst='target',comboConserveR='R',comboKickFollow='R',comboIsolate='R',
    multi='R',multiHits='R',collateralKills='R',autoMultiR='R',defensiveR='R',
    idleDefense='W',reserveW='W',shieldHP='W',allyShieldHP='W',expiryW='W',expiryE='E',
    itemCleanse='cleanse',itemShield='shield',itemSlow='slow',itemSpeed='speed',itemCleave='items',
    itemTargeted='items',items='items',damageItems='items',damageSummoners='ignite',
    drawQRange='Q',drawWRange='W',drawERange='E',drawRRange='R',drawWardRange='ward',
    drawHUD='hero',drawWard='ward',drawInsec='R',drawInsecTolerance='R',draw='draw',enabled='hero',
    qOnlySelected='Q',hitchance='Q',q2Safety='Q',clearKrugE='E',clearQTiming='Q',
    farmPreserveQ='Q',farmQTravel='Q',farmQBlind='Q',farmQRespawn='Q',farmQAdjust='Q',
    jungleQ2MeleeOnly='Q',jungleQ2RangeScale='Q',waveSoften='E',
    insecQ='Q',insecBridges='Q',insecW='W',insecChains='ward',insecCloseWard='ward',
    insecLandingMargin='ward',insecMouseTarget='target',insecMouseRadius='target',insecTrackAlly='target',
    aimLock='target',insecWalk='move',insecOrbwalk='move',comboWard='ward',comboWardRetry='ward',
    comboWardGain='ward',comboWalkWait='move',comboChaseE2='E',wardFollowCursor='move',wardApproach='move',
    wardAssist='ward',reuseRadius='ward',assistRadius='ward',wardWalkRange='move',
    comboIgnite='ignite',igniteExecute='ignite',autoJungle='move',openingRoute='move',
    farmKite='move',farmKiteDistance='move',farmKiteLeash='move',damageBars='target'}
function M.new()
    local cache={}
    local function resolve(symbol)
        local path=art[symbol];if not path then return nil end
        if cache[path]~=nil then return cache[path] or nil end
        local found=false
        if SPRITE_PATH and type(FileExist)=='function' then
            local base=SPRITE_PATH;if not base:match('[/\\]$') then base=base..'/' end
            local ok,exists=pcall(FileExist,base..'MenuElement'..path);found=ok and exists
        end
        cache[path]=found and path or false;return cache[path] or nil
    end
    return function(key)
        local symbol=exact[key] or (art[key] and key)
        if not symbol then
            if key:match('^potion') then symbol='potion'
            elseif key:match('^smite') or key=='autosmite' then symbol='smite'
            elseif key:match('^insecFlash') then symbol='flash'
            else
                for _,prefix in ipairs({'combo','harass','kill','wave','last','jungle','autoClear','damage'}) do
                    local spell=key:match('^'..prefix..'([QWER])%d?$')
                    if spell then symbol=spell;break end
                end
            end
        end
        return resolve(symbol)
    end
end
return M

end
modules["lho.navdata"] = function(require)
-- Generated by tools/build_lho_navigation.py; static map assets, not live terrain.
return {["normal"]={["x"]=-1.1048965454101562,["z"]=32.75579833984375,["maxX"]=14718.400390625,["maxZ"]=14792.2109375,["cell"]=50.0,["nx"]=295,["nz"]=296,["gates"]={[100]={[15433]=true,[15434]=true,[15728]=true,[15729]=true,[15730]=true,[15731]=true,[15732]=true,[15733]=true,[16023]=true,[16024]=true,[16025]=true,[16026]=true,[16027]=true,[16028]=true,[16318]=true,[16319]=true,[16320]=true,[16321]=true,[16322]=true,[16323]=true,[16613]=true,[16614]=true,[16615]=true,[16616]=true,[16617]=true,[16618]=true,[16908]=true,[16909]=true,[16910]=true,[16911]=true,[16912]=true,[17203]=true,[17204]=true,[17205]=true,[17206]=true,[17207]=true,[17502]=true,[27485]=true,[27486]=true,[27487]=true,[27488]=true,[27489]=true,[27490]=true,[27491]=true,[27780]=true,[27781]=true,[27782]=true,[27783]=true,[27784]=true,[27785]=true,[27786]=true,[28076]=true,[28077]=true,[28078]=true,[28079]=true,[28080]=true,[28081]=true,[28371]=true,[28372]=true,[28373]=true,[28374]=true,[28375]=true,[28376]=true,[28666]=true,[28667]=true,[28668]=true,[28669]=true,[28670]=true,[28671]=true,[28672]=true},[200]={[58944]=true,[58945]=true,[58946]=true,[58947]=true,[58948]=true,[58949]=true,[59238]=true,[59239]=true,[59240]=true,[59241]=true,[59242]=true,[59243]=true,[59244]=true,[59534]=true,[59535]=true,[59536]=true,[59537]=true,[59538]=true,[59539]=true,[59829]=true,[59830]=true,[59831]=true,[59832]=true,[59833]=true,[59834]=true,[60124]=true,[60125]=true,[60126]=true,[60127]=true,[60128]=true,[60129]=true,[60130]=true,[70408]=true,[70409]=true,[70703]=true,[70704]=true,[70705]=true,[70706]=true,[70707]=true,[70998]=true,[70999]=true,[71000]=true,[71001]=true,[71002]=true,[71293]=true,[71294]=true,[71295]=true,[71296]=true,[71297]=true,[71588]=true,[71589]=true,[71590]=true,[71591]=true,[71592]=true,[71883]=true,[71884]=true,[71885]=true,[71886]=true,[71887]=true,[72178]=true,[72179]=true,[72180]=true,[72181]=true,[72182]=true,[72476]=true,[72477]=true}},["mapID"]=11,["rows"]={"fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff7","fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff7","f10cfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff7","f008fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff7","3000effffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff7","1000cffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff7","10000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff7","10000cfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff7","100000fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff7","100000cffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff7","10000000000000000000000efffffffffffffffffffffffffffffffffffffffffffffffff7","100000000000000000000008fffffffffffffffffffffffffffffffffffffffffffffffff7","100000000000000000000000fffffffffffffffffffffffffffffffffffffffffffffffff7","300000000000000000000000cffffffffffffffffffffffffffffffffffffffffffffffff7","7000000000000000000000000000000000000000000cfffffffffffffffffffffffffffff7","f100000000000000000000000000000000000000000000000000effffffffffffffffffff7","f70000000000000000000000000000000000000000000000000000effffffffffffffffff7","ff0000000000000000000000000000000000000000000000000060000ffffffffffffffff7","ff10000000000000000000000000000000000000000000000000f00000fffffffffffffff7","ff10000000000000000000000000000000000000000000000000f100008ffffffffffffff7","ff10000000000000030000000000000000000000000000000000f100000cfffff1cffffff7","ff30000000000000cf0000000000000000000000000000000000f0000000cffff08ffffff7","ff30000000000000cf1007000000000000000000000000000000000000000cff700efffff7","ff30000000000000ef108f0000000000000000000000000000000000000000ff3008fffff7","ff30000000000000ef108f0000000000000000000000000000000000000000000000fffff7","ff30000c00000000cf108f0000000000000000000000000000000000000000000000effff7","ff30008f70000000cf10070000000000000000000000000000000000000000000000cffff7","ff3000cff0000000070000000000000000f0000000000000000000000000000000008ffff7","ff3000eff1000000000000000000000000f100000000000000000000000000000c108ffff7","ff3000eff1000000000000000000000000f100000000000000000000000000000e100ffff7","ff3000fff3000000000000000000000000f000000000000000000000000000000f000ffff7","ff3000fff30000000000000000000000004000000000000000000000000000008f100efff7","ff3000fff300000000000000f000000000000000000000000000000000000000cf300cfff7","ff3000fff3c1000000000008f1000000000000000000000000000000000000008f730cfff7","ff3000fff3e3000000000008f1000000effffff30ffff70000000000000000000ff30cfff7","ff3000eff1e3000000000008f10ef700effffff30ffff700ffff7000000000000ef30cfff7","ff3000eff1e3000000000008f10ef700fffffff30ffff308fffff100000000000cf10cfff7","ff3000cff0c1000000000008f10ef300fffffff30ffff308fffff3000000000008f00efff7","ff30008f7000000000000008f10ef308fffffff30ffff108fffff300f000000000700ffff7","ff30000c0000000000000008f10ef10cfffffff30ffff00cfffff308f300000000208ffff7","ff3000000000000000000008f10ef10cffffff3000fff00cfffff308f70000000000cffff7","ff300000000000000000000cf10ef10cffffff00000f700cfffff10cf70000000000effff7","ff300000c00000000000000cf00ef10cfffff7000000700cfffff00cff0000000000effff7","ff300000e10000000000000cf00ef10cfffff3000000000efff0000eff0000000000effff7","ff300000f10000000008100cf00ef10cfffff1000000000eff30000eff1000000000effff7","ff300000e1000000000c300cf00ef10cfffff0000000000fff00000eff1000000000effff7","ff300000e1000000000e700cf00ef100ffff70000000000ff300000eff1000000000effff7","ff30000000000000000e700cf00ef100cfff300e100000000000000eff3000000000effff7","ff30000000000000000c300cf00ef1000fff100f300000000000000fff3000000000effff7","ff300000000000000008100cf00ef10008ff008f700000000000000fff7000000000effff7","ff300000000000000000000cf00ef300000000cf700000000000008fff7000000000effff7","ff300000000000000000000cf00ef700000000eff00e1000000000cfff7000000000effff7","ff300000000000000000000e700eff10000000eff00e700000e100cfff7000000000effff7","ff300000000000000000000e700eff70000000eff00ef30008f100efff7000000000cffff7","ff300000000000000000000e700efff1000000fff00eff000ef300ffff7000000000cffff7","ff300000000000000000000e700efff1000000fff10fff308ff308ffff3000000000cffff7","ff300000000000000000000e700efff1000000fff10ffffffff008ffff10000000008ffff7","ff300000000000000000000e300efff0000000fff10fffffff700cffff00000000008ffff7","ff300000000000000000000e300efff0000000fffffffffff7000efff700000000000ffff7","ff300000000000000000000e300eff70000000effffffffff1000efff300000000000ffff7","ff3000000000000c3000000f300eff30000000efffffffff10000efff000000000000ffff7","ff3000000000000e7000000f300eff30000000effffffff300000eff7000000000000efff7","ff3000000000000ff000000f300eff1000c100e30effff3000000cff3000000000000efff7","ff3000000000000ff000008f300eff108ff700e00cffff10000008ff0000000000000efff7","ff3000000000000ff000008f1008ff00cff70000000eff00000000e7000000c300000cfff7","ff3000000000000e700000cf0008f700cff700000008f70000cf0000000008f700000cfff7","ff3000000000000c300000ef0008f700eff700000000f30000ff000000000cff000008fff7","ff300c1000000000000000f70008f300fff700000000c1000cff000000000eff100008fff7","ff300f3000000000000008f70008f300fff70000000000000fff000000000fff300008fff7","ff300f7000000000000008f300000008fff7000000000000cfff000000008fff300008fff7","ff300f700000000000000cf300000008fff30008f0000000ffff10000000cfff700008fff7","ff300f700000000008700cf10000000cfff1000cf100000cffff10000000cfff700008fff7","ff300f700000000008700ef10000000eff70000ef700000effff3e000000efff700000fff7","ff300e300000000008f00ef00000000eff10000eff00000fffffff300000effff00000fff7","ff300c100000000008700cf00000000ff700000eff00008fffffff700000effff00000fff7","ff300000000000000030087000ff108ff100000cff1000cffffffff00000fffff00000eff7","ff300000000000000000003000ff108ff1000000ff3000ef78fffff00000fffff10000eff7","ff300000000030000000000008ff108ff1000000ef7000ff30cffff00000fffff10000eff7","ff30000000087000000000000cff308ff1000000eff008ff108ffff00008fffff10000eff7","ff300000000cf000000000000cff308ff108f100eff008ff000ffff00008fffff10000cff7","ff300000000cf000000000000eff708ff108f100eff008f7000eff700008fffff10000cff7","ff30000000087000000000000eff700ff10cf100eff00cf3000cff700008fffff10000cff7","ff3000000000300000000000cfff700ff10cf100eff00cf00008ff700008fffff10000cff7","ff700e100000000000000000effff00ef10cf700eff00c700000ff30000cfffff10000cff7","ff700e300000000000000000effff00ef10cff00eff00c700000ef30000cfffff10000cff7","ff700e300000000000000000cffff10cf10cff7cfff00e300000cf30000cfffff10000cff7","ff700e10000000000c300000cffff10cf10cfffffff00e300000cf10000cfffff10000cff7","fff00800000000000f7000008ffff308f10cfffffff00e300000cf00000efffff100078ff7","fff00000000000008f7000000ffff300e10cfffffff00e300000e300000efffff1008f8ff7","fff0000000000000ef7000000efff700000cfffffff00e300000f100000ef7cff1008f8ff7","fff100000000000cff7000000cfff7000000efffff700c700008f000000f10cff1008f8ff7","fff100000000008fff30000008ffff0000008fffff700c70000c7000000f108ff100078ff7","fff10000000000cfff00000000ffff0000000cffff700c70000c3000008f000ff100008ff7","fff100000000cffff300000003efff10000000cfff300cf00008100000c7000ff100008ff7","fff30000cffffffff000000087cfff300000000000000cf00000000000e3000ff100008ff7","fff30000efffffff30000000c78fff300000000000000ef10000000000e1000ff100008ff7","fff30000effffff700000000870eff308300000000000ef70000000000f1000ef100008ff7","fff30000effffff3000000008708f300e300000000000fff1000000008f0000cf100008ff7","fff30000cfff70000000000000000000e700000000008fffff0000000c700000f100008ff7","fff30000cfff10000000000000000000e70000000000cfffff0000000c300000e100008ff7","fff30000000000000000000000000000e70000000000efffff0000000e3081008100008ff7","fff30000000000000000f00000000000e70000000008fffff30000000f1081000000008ff7","fff7000000000000000cf10000000000e7000000000cfffff00000008f0081000000008ff7","fff7000000000000008ff30000000000e7000000000cffff30000000870081000000008ff7","fff700000000000000fff70000000c30ef00ff30000cffff000000008700c1000000008ff7","fff70000000000000effff0000000c30ef00ff30000cfff1000000008700c1000000008ff7","fff7000000000000cfffff1000000cffff00ff30000cff10000000000700e1000000008ff7","fff700000000000effffff30000008ffff00ff300008f100000000000f00e1000000008ff7","fff700000000000fffffff70000000ffff00ff3000000000000000000f00e10c0000008ff7","fff700000000000ffffffff0000000efff00ff3000000000000000000e00f10e3000008ff7","fff7000000cf000efffffff1000000cfff00ff3000000000000000c00e00f10ef100008ff7","fff700008fff100cfffffff30000008fff00ff1000000000000000f00c00f30ef300008ff7","fff700008fff700cfffffff70000000fffffff0000000000000008f00000f30cf300008ff7","fff700008ffff008ffffffff0000000efffff7000000000000000cf10000f30cf300008ff7","fff700008ffff008ffffffff1000000cfffff1000000000000000ef10000f30cf700008ff7","fff700008ffff008fff00eff10000008fffff0000830000000000ff30000f30cf700008ff7","fff300008ffff008ff10087000000000ffff70000f3000000000cff70000f30cf700008ff7","fff300008ffff008f700003000000000efff1000ef1000000000fff70008f308f700008ff7","fff300008fff3008f100000000000000cfff0008f7000000000effff000cf708f700008ff7","fff300008fff100cf0000000000000008ff7000cf100000000cfffff000ef708f700008ff7","fff300008fff000ef0000000000000008ff3000ff000000000effff7000ff708f700008ff7","fff300008fff000e70000000000000000ff000cf3000000000effff3008ff700f700008ff7","fff300008fff000f3000f0008f0000000e7000ef0000000000cffff100cff700f700008ff7","fff300008fff008f1008f100ff300000000008f700000000000ffff100eff300f700008ff7","fff300008fff00cf0008f300ff70000000000cf300000000000efff100fff300f700008ff7","fff300008fff00ef0000ff00eff0870000000ef000000000000cfff108fff300f700008ff7","fff300008fff00f70000ef10eff1870000000f70000000000008fff00cfff100f700008ff7","fff300008fff00f30000ef10cff3c70000008f30000000cf1000fff00cff7000f700008ff7","fff300008fff00f30000cf10cff787000000cf10000000ff7000eff000ff0000f700008ff7","fff300008fff00f10000cf30cfff13000000cf10000008fff000eff000c30000f700008ff7","fff300008fff10f10000ef30cfff30000000cf0000000efff100eff000000008f700008ff7","fff3000e8fff10f10000ff30cfff70000000c70000008ffff300eff10000000cf700008ff7","fff3000f9fff10f10008ff708ffff000000083000000effff700eff10000000ef300008ff7","fff3000f9fff10e1000cff708ffff100000000000000fffff700eff1000000cff300008ff7","fff3000f8fff10e10cffff708ffff10000000000000cfffff700eff0000008fff300008ff7","fff300060fff10e10effff708ffff10000000000000ffffff700ff7000000cfff300008ff7","fff300000fff10e10effff708ffff30000000000008ffffff300ff1000000ffff100008ff7","fff300000fff10e10cffff308ffff3000000000000cfffff1008f3000000cfff3000008ff7","fff300000fff10e108ffff308ffff1000000000000fffff30008f3000000cfff0000008ff7","fff300000fff10e100ffff008ffff1000000000000ffff30000cf3000000cff70000008ff7","fff300000fff10c000cff3008ffff1000000000008fff700000cf3000000cff10000008ff7","fff300000fff1000000e10008ffff100000000000cfff300000ef3000000cf700000008ff7","fff300000fff100000000000cffff000000000000cfff100000ef3000000cf300000008ff7","fff300000ff7000000000000efff7000000000000cff7000000ef70000008f100000008ff7","fff300000ff3000000000000ffff700e300000000cff3000000effffff1000000000008ff7","fff300000ff1000000000000ffff300ff000000008ff1000000cffffff3000000000008ff7","fff300000f70000000000000efff108ff000000008ff00000000ffffff3000000000008ff7","fff300000f30000000000000cff7008ff000000000f7000ef300efffff100000e100008ff7","fff300000f000000fffff0008ff300cff000000000e3008ff30000efff100000f100008ff7","fff3000007000008ffffff100f3000eff0000000000000eff700000000000008f100008ff7","fff3000000000008ffffff30000000fff0000000000000fff70000000000000ef100008ff7","fff3000000000008ffffff70000000ff70000000000008fff70000000000000ff100008ff7","fff300000000e300fffffff0000008ff3000000000000cfff70000000000008ff100008ff7","fff300000008f7000000cff000000eff3000000000000efff7000000000000eff100008ff7","fff30000000cf70000008f7000000fff1000000000000ffff7000000000000fff100008ff7","fff30000000ff70000008f7000008fff1000000000000ffff3008ff3000e10fff100008ff7","fff30000008ff70000008f700000efff0000000000008ffff300efff000f10fff100008ff7","fff3000000eff70000008f30000cffff0000000000008ffff300ffff100f10fff100008ff7","fff3000008fff70000008f3000cffff70000000000008ffff108ffff300f10fff100008ff7","fff300000efff30000008f10cffffff70000000000008ffff108fffff00f10fff300008ff7","fff300008ffff0000000ef00effffff10000830000008ffff10cfffff00f10fff300008ff7","fff300008fff3000000cff00efffff700000c70000008ffff10cfffff00f10fff340008ff7","fff300008fff0000000ff700efffff300000e70000008ffff10cff38f00f10fff3f1008ff7","fff30000cff10000000ff700efffff000000f70000000ffff10cff10700f10fff3f1008ff7","fff30000cf700000000ff300cffff7000000f70000000efff10cff00608f10fff3f1008ff7","fff30000cf300000000ff3008ffff1000008f30000000cfff308f700008f10fff3e0008ff7","fff30000cf100000000ff7000ffff000000cf100000008fff308f700008f10fff300008ff7","fff30000cf0000cf000ff7000eff3000000ef0000000c1fff308f700008f10fff300008ff7","fff30000cf0008ff100fff0008ff0000000f30000000e1eff700f700008f10eff300008ff7","fff30000cf000eff700fff1000c30000008f10000000e3cff700f700008f10eff300008ff7","fff30000cf008fff700fff3000000000008f00000000e18fff00ef0000cf10eff300008ff7","fff30000cf008fff300fff700000000000c700000000c10fff10cf0000ef00eff300008ff7","fff30000cf008fff100ffff10000000000f300000000000eff108f0000e700eff300008ff7","fff30000cf00cfff000ffff30000000008f100000000000cff00060000f300eff300008ff7","fff30000cf00cff7000fffff000000000cf0000e100000081000000008f100eff300008ff7","fff30000cf10cff3008fffff000000000f70000f70000000000000000cf000fff300008ff7","fff30000cf10cff100effff7000000008f10008ff0000000000000000e7000fff300008ff7","fff30000cf30cff000effff100000000ef0000cff1000000000000000f7000fff300008ff7","fff30000cf30cf7000cfff7000000000f70000fff3000000000000000f300cfff300008ff7","fff30000cf708f3000cfff000000000cf10008fff700000000000000cf300efff30000cff7","fff300008f708f10008ff7000000000c30000effff00000000000000ff300efff30000cff7","fff300008f708f10000ff1000000000000000fffff30000000ff100cff300efff30000cff7","fff300008ff08f10000ff0000000000000008fffff70000000ff300fff300efff10000cff7","fff300008ff00f10000f3000000000000000cffffff0000000fff8ffff300efff10000cff7","fff300008ff00f10600e1000000000000000fffffff1000000efffffff7008fff10000cff7","fff300008ff00f10600e0000000000000008ff10eff3000000cfffffff7000fff00000cff7","fff300000ef10f10e0060000000000000008ff10eff70000008ffffffff000e1000000cff7","fff7000000f10f00e1000000000000000008ff10efff0000008ffffffff00000000000cff7","fff7000000c00f00e1000000000000000008ff10efff1000000fffffff700000000000cff7","fff7000000000f00e100000000008f100008ff10efff3000000effffff3000000000008ff7","fff7000000000700e1000000000cff700008ff10efff7000000cfffff30000000000008ff7","fff7000000000700e3000000008fff700000cf10e70870000008ffff700000000000008ff7","fff7000000000700e300000000efff7000000000c70000000000efff000000000000008ff7","fff7000000000300e300000008ffff3000000000c70000000000cff1000000000000008ff7","fff7000000000300e30000000effff1000000000c700000000000f70000000000000008ff7","fff7000000000300f10000008fffff0000000000c700000000000e00000000000000008ff7","fff7000007000300f1000000effff70000000000c700000000000000000000000000008ff7","fff700000f100008f1000000effff30000000000c7000000000000000000000cf700008ff7","fff700000f300008f0000000cffff10000000000870000000000000000000cffff00008ff7","fff700000f70000cf000000000eff000000000008700c100c10000000008ffffff00008ff7","fff700000f70000c7000000000eff000000000008708ff00e3000000000cffffff00008ff7","fff700000ff0000e7000000000cff000000000000008fff0e300000000efffffff00008ff7","fff700000ff1000f30000000008ff008ff7000000008fff3e30000000cfffffff700008ff7","fff700000ff1008f30000830000ff00cffff00000008fff7c1000000fffffff30000008ff7","fff700000ff3008f30000c70000ff00cffff70000000ffff0000000cfff700000000000ff7","fff700000ff300cf10000e70000ef00cfffff3000000ffff1000000efff300000000000ff7","fff7c3000ff700ef10008f30000cf00effffff000000efff3000000ffff000000000000ff7","fff7e3000fff00ff0000cf10000cf00effffff700300efff7000000fff1000000000000ef7","fff7e3000fffffff0000ef10000cf00effffff700f00cffff100000ff70000000008300ef7","fff7c3000ffffff70000ff10000cf00effffff700f10cffff300000ef1000000000c700ef7","fff781000ffffff70008ff10000cf00effffff700f308ffff700000c70000000000c700ef7","fff700000ffffff3000cff10000cf00eff3cff700f700fffff00000830000000000c700ef7","fff700000ffffff3000cff30000c700eff00ef700f700fffff000000000000000008300ef7","fff700000ffffff1000eff70000e700eff008f700ff00effff000000000000000000000cf7","fff700000ffffff1000efff0000e700eff000f700ff00efff1000000000000000000000cf7","fff700000ffffff0000efff1008f300eff000f700ff10cfff0000000000008100000000cf7","ffff00000ffffff0000efff300cf300eff000f700ff10cfff000000000000c300000000cf7","ffff00000fffff70000fffff00ef300eff000f300ff10cff7000000000000e700000000cf7","ffff00000fffff70000ffffff8ff100cff0000000ff10cff3000000000000e700000000cf7","ffff00000fffff30000fffffffff0008ff0000000ff10cff3000000000000c300000000cf7","ffff00000fffff30000efffffff70008ff1000000ff10cff10000000000008100000000cf7","ffff00000effff10000efffffff30000ff7000000ff108ff000e100e000000000008300cf7","ffff10000effff10000cfffffff10000eff000008ff00000000f300f10000000000e700cf7","ffff10000effff000000fffffff00000cff00000ef700000000f300f10000000000ff00cf7","ffff10000cffff00000000fffff000008ff0000cff700000008f300f10000000000ff00cf7","ffff10000cfff700000000efff3000000f70000fff300000008f300e00000000000ff10cf7","ffff10000cfff300000000efff0000000c30008fff30000000cf100000000000000ff00cf7","ffff100008fff100000000eff1000000000000cfff10000000cf100000000000000ff00cf7","ffff100000fff100000000cf70000300000000cfff108f3000cf000008100000000e700cf7","ffff300000fff0000000008f00008f00000000cfff008f3000e700000e700000000c300cf7","ffff300000ef7000000000030000cf30000000cfff00cf3000e700000ff000000000000cf7","ffff300000cf3000000700000000ef70000000cff700ef3000f300000ff000000000000cf7","ffff3000008f000000ff10000000fff1000000cff300eff000f300000ff000000000000cf7","ffff30000000000008ff30000008ffff700f008f7000fff000f300000ff000000000000cf7","ffff3000000000000cff7000000cfffff0cf00000000fff000f300000ff000000000000cf7","ffff3000000000000eff700000cfffffffff00000008fff008f100000e7000000000000cf7","ffff7000000000000fff70000cffffffffff0000000cfff008f100000c3000000000000cf7","ffff7000000000008fff70008fffffffffff0000000cfff008f10000000000000000000cf7","ffff700000000000ffff7000efffffffffff0000000efff00cf00000000000000000000cf7","ffff700000000000ffff700cfffffff10fff0000000efff00c700000000000000000000cf7","fffff00000000008ffff300ffffffff00fff0000000ffff00c700000000000000000000cf7","fffff0000000000cffff108f7000fff00fff0000000ffff00c700000000000000000000cf7","fffff0000000000effff108f1000cff00eff0000000efff00c700000000000000000000cf7","fffff0000000000fffff000700000ff00eff00000008fff00c700000000000000000000cf7","fffff0000000000ffff7000000000cf00eff00000000eff00c700000000000000000000cf7","fffff0000000000ffff30000000000600ef700000000cff00e7000000000000000000008f7","fffff0000000000ffff30000000000000cf7000000000ff00f3000000000000000000008f7","fffff0000000000ffff10000000000000cf300ef70000ff00f3000600000000000000008f7","fffff0000000000efff000000000000008f100fff3000ff00f3000f00000000000000008f7","fffff0000000000efff000000e100000000008ffff000ff00f3008f10000000003000008f7","fffff0000000000eff7000000ff0000000000cffff300ff00f3008f10000000087000008f7","fffff0000000000eff7000008ff0000000000effff700ff00f3000f0000000008f000008f7","fffff0000000000cff7000008ff0000000000fffff700ff00f3000600000000087000008f7","fffff00000000008ff300cfffff0000000008fffff700ff00f3000000000000087000008f7","fffff00000000000ff300efffff000f00000efffff700ff00f3000000000000000000008f7","fffff00000000000cf100fffff7008ff0008ffffff708f700f3000000000000000000008f7","fffff000000000000e100fffff700cff700fffffff708f700f3000000000000000000008f7","ffff70000000000000008fffff700efff18fffffff308f700f300000000000000cf00008f7","ffff30800000000000008fffff300efff18fffffff308f700f300000000000000ef10008f7","ffff10c10000000000008fffff300ffff18fffffff108f700f300000000000c38ff30008f7","ffff00e30000000000000effff300ffff18fffffff008f300f300000000000c78ff70008f7","fff700f70000000000000cffff108ffff18fffffff000e100f300000000000c7cff70008f7","fff708ff000000000000000000008ffff18ffffff70000000f300000000000c3cfff0008f7","fff708ff10000000000000000000000000000000000000000e10000000000001cfff0008f7","fff708df30000000000000000000000000000000000000000000000000000000cfff0008f7","fff7008f7000000000000000000000000000000e000000000000000000000000cfff0008f7","ffff000f3000000000000000000000000000000e100000000000000000000000cff70008f7","ffff100e1000000000000000000000000000000f1000000000000000000000008ff70008f7","ffff300f0000000000000000000000000000000e1000000000000000700000008ff30008f7","ffff70070000000000000000000000000000000e000000000000000cf00000000ff10008f7","fffff00000000000000000000000000000000000000000000000700ef10000000cf00008f7","fffff10000000000000000000000000000000000000000000008f00ef100000000000008f7","fffff30000000000000000000000000000000000000000000008f00ef300000000000008f7","fffff70000000000000000000000000000000000000000000008f00ef100000000000000f7","ffffff008fff3000000004000000000000000000000000000000700ef100000000000000f7","ffffff10cffff30000000f000000000000000000000000000000000cf100000000000000f7","ffffff30efffff1000000f10000000000000000000000000000000087000000000000000e7","ffffff70fffffff000000f10000000000000000000000000000000000000000000000000e7","ffffffffffffffff00000e00000000000000000000000000000000000000000000000000c7","fffffffffffffffff0000000000000000000000000000000000000000000000000000000c7","fffffffffffffffffff3000000000000000000000000000000000000000000000000000087","ffffffffffffffffffffffff10000000000000000000000000000000000000000000000007","ffffffffffffffffffffffffffffffffffffffff0000000ef7000000000000000000000006","fffffffffffffffffffffffffffffffffffffffffffffffffff70000000000000000000004","ffffffffffffffffffffffffffffffffffffffffffffffffffff0000000000000000000004","ffffffffffffffffffffffffffffffffffffffffffffffffffff1000000000000000000004","ffffffffffffffffffffffffffffffffffffffffffffffffffff700000000000008ff10004","fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff30004","fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff70004","ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff0004","ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff1007","ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff1087","ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff10c7","ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff10e7","ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff30f7","fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff7"},["mode"]="normal",["sha256"]="b7551b91dcdc3dec0228ff2df63483399b0b040552d2115b65d9fe1faf35bd93"},["classic"]={["x"]=0.0,["z"]=0.0,["maxX"]=16000.0,["maxZ"]=16000.0,["cell"]=50.0,["nx"]=321,["nz"]=321,["gates"]={[100]={[19365]=true,[19366]=true,[19367]=true,[19368]=true,[19371]=true,[19686]=true,[19687]=true,[19688]=true,[19689]=true,[19690]=true,[19691]=true,[19692]=true,[20007]=true,[20008]=true,[20009]=true,[20010]=true,[20011]=true,[20012]=true,[20013]=true,[20327]=true,[20328]=true,[20329]=true,[20330]=true,[20331]=true,[20332]=true,[20333]=true,[20648]=true,[20649]=true,[20650]=true,[20651]=true,[20652]=true,[20653]=true,[20654]=true,[20973]=true,[20974]=true,[20975]=true,[21296]=true,[31841]=true,[31842]=true,[31843]=true,[31844]=true,[31845]=true,[31846]=true,[32162]=true,[32163]=true,[32164]=true,[32165]=true,[32166]=true,[32167]=true,[32168]=true,[32483]=true,[32484]=true,[32485]=true,[32486]=true,[32487]=true,[32488]=true,[32489]=true,[32804]=true,[32805]=true,[32806]=true,[32807]=true,[32808]=true,[32809]=true,[32810]=true,[33125]=true,[33126]=true,[33127]=true,[33128]=true,[33129]=true,[33130]=true,[33131]=true,[33132]=true,[33446]=true,[33447]=true,[33448]=true},[200]={[65736]=true,[65737]=true,[65738]=true,[65739]=true,[65740]=true,[65741]=true,[66058]=true,[66059]=true,[66060]=true,[66061]=true,[66062]=true,[66380]=true,[66381]=true,[66382]=true,[66383]=true,[66701]=true,[66702]=true,[66703]=true,[66704]=true,[67022]=true,[67023]=true,[67024]=true,[67025]=true,[67026]=true,[67343]=true,[67344]=true,[67345]=true,[67346]=true,[67347]=true,[67663]=true,[67664]=true,[67665]=true,[67666]=true,[67667]=true,[67668]=true,[77571]=true,[77572]=true,[77573]=true,[77574]=true,[77892]=true,[77893]=true,[77894]=true,[77895]=true,[77896]=true,[77897]=true,[77898]=true,[78213]=true,[78214]=true,[78215]=true,[78216]=true,[78217]=true,[78218]=true,[78534]=true,[78535]=true,[78536]=true,[78537]=true,[78538]=true,[78539]=true,[78855]=true,[78856]=true,[78857]=true,[78858]=true,[78859]=true,[78860]=true,[79176]=true,[79177]=true,[79178]=true,[79179]=true,[79180]=true,[79181]=true}},["mapID"]=453,["rows"]={"ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff1","ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff1","ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff1","ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff1","ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff1","ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff1","ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff1","ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff1","ffff70ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff1","ffff30efffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff1","ffff30ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff1","ffff106cffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff1","fff10000efffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff1","fff100000fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff1","fff100000cffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff1","fff1000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff1","fff1000000cffffffffff0008fffffffffffffffffffffffffffffffffffffffffffffffffffffff1","fff1000000000000000000000cffffffffffffffffffffffffffffffffffffffffffffffffffffff1","fff10000000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffff1","fff300000000000000000000008ffffff1008fffffffffffffffffffffffffffffffffffffffffff1","ffff00000000000000000000000000c3000000000000fff30000008fffffffffffffffffffffffff1","ffff3000000000000000000000000000000000000000000000000000cfffffffffffffffffffffff1","ffff700000000000000000000000000000000000000000000000000000ffffffffffffffffffffff1","fffff000000000000000000000000000000000000000000000000000000fffffffffffffffffffff1","fffff1000000000000000000000000000000000000000000000000000000efffffffffffffffffff1","fffff30000000000000000000000000000000000000000000000000000000fffffffffffffffffff1","fffff30000000000000000000000000000000000000000000000000000000cffffffffffffffffff1","fffff300000000000000000000000000000000000000000000000000000000ffffffffffffffffff1","fffff300000000000000000000000000000000000000000000000000000000cfffffffffffffffff1","fffff3000000000000000000000000000000000000000000000000000000000fffffffffffffffff1","fffff1000000000000000000000000000000000000000000000000000000000cffffffffffffffff1","fffff00000000000000000000000000000000000000000000000000000000000ffffffffffffffff1","fffff00000000000000000000000000000000000000000000000000000000000cfffffffffffffff1","ffff7000000000000000000000000000000000000000000000000000000000000fffffffffffffff1","fffff000000000000000000000000000000000000000000000000000000000000cffffffffffffff1","fffff0000000000000000000000000000000000000000000000000000000000000ffffffffffffff1","fffff1000000000000000000000000000000000000000000000000000000000000efffffffffffff1","fffff1000000000000000000000000000000000000000000000000000000000000cfffffffffffff1","fffff10000000000000000000000000000000000000000000000000000000000008fffffffffffff1","fffff10000000000000000000007000300000000000000000000000000000000000fffffffffffff1","fffff1000000000000000000008f00ef0000cfffff10cff30000000000000000000effffffffffff1","fffff1000000000000000000008f00ef100cffffff30ffff308fff1000000000000cffffffffffff1","fffff1000000000000000000008f00ef308fffffff30ffff308fffff100000000008ffffffffffff1","fffff1000000000000000000008f00ef30cfffffff30ffff30cfffff100000000008ffffffffffff1","fffff1000000000000000000008f10ef30cfffffff30ffff30cfffff100000000000ffffffffffff1","fffff1000000000000000000008f10ef30cfffffff10ffff30efffff100600000000efffffffffff1","fffff1000000000000000000008f10ef30efffff1000efff30ffffff100f00000000cfffffffffff1","fffff1000000000000000000008f10ef30efffff000000ef10ffffff108f300000008fffffffffff1","fffff1000000000000000000008f10ef30effff70000000f08ffffff108f700000000fffffffffff1","fffff100000000000000000000cf00ef30effff30000000c08fffff300cff00000000effffffffff1","fffff100000000000000003000cf00ef30effff3000000000cfff30000cff10000000cffffffffff1","fffff10000000000000000f300cf00ef30cffff10000000008fff00000cff300000008ffffffffff1","fffff10000000000000000f300cf00ef308ffff10000000000ff300000eff300000008ffffffffff1","fffff10000000000000000f300cf00ef700efff0000000000000000000eff300000000ffffffffff1","fffff10000000000000000f300cf00ef7008ff7008f100000000000000eff300000000efffffffff1","fffff10000000000000000f300cf00eff000ef7008f300000000000000fff300000000cfffffffff1","fffff100000000000000000000cf00eff1000c300cf300000000000000fff3000000008fffffffff1","fffff100000000000000000000cf00eff30000000ef700000000000008fff3000000008fffffffff1","fffff100000000000000000000cf00eff70000000ef7000f0000c00008fff3000000008fffffffff1","fffff100000000000000000000cf00efff0000000eff00eff008ff000cfff3000000000fffffffff1","fffff100000000000000000000ef00efff1000000fff00fff7ffff100efff1000000000fffffffff1","fffff100000000000000000000ef00efff1000000fff18ffffffff100fff70000000000effffffff1","fffff100000000000000000000ef00efff1000000fff18ffffffff108fff30000000000effffffff1","fffff100000000000000000000f700efff1000000fff3cfffffff300cfff10000000000cffffffff1","fffff100000000000000000000f700efff0000000fffffffffff7000cfff10000000000cffffffff1","fffff100000000000000000000e700efff0000000fffffffffff0000cfff000000000008ffffffff1","fffff100000000000000000000f700eff7000f100ffffffffff30000eff7000000000008ffffffff1","fffff100000000000000000000f100eff3008f700fffffffff700000cff3000000000008ffffffff1","fffff100000000000000000008f100eff300ef700fffffffff100000cff1000000000000ffffffff1","fffff100000000000000000008f100eff108fff00e108ffff7000000cff0000000000000ffffffff1","fffff100000000000000000008f100eff10efff000000cfff1000e100f70000000000000ffffffff1","fffff10000000000000000000cf100fff00ffff0000000fff0000f300000000000000000efffffff1","fffff10000000000000000000cf100fff00ffff0000000ef70008f7000000000c1000000efffffff1","fffff10000000000000000000ef000ef708ffff00000008f1000ff7000000000cf700000cfffffff1","fffff10000000000000000000ef000cf10cffff000000000000cfff000000000eff30000cfffffff1","fffff10000000000000000000ef0000000efff7000000000000efff000000000eff30000cfffffff1","fffff10000000000000000000f70000000efff7000060000008ffff000000000fff70000cfffffff1","fffff10000000000000000000f70000000fff300008f700000cffff100000000ffff00008fffffff1","fffff10000000000000000000f30000000fff00000ef700000fffff700000000ffff00008fffffff1","fffff10000000000000000008f10000008ff700000eff00008fffffff0000008ffff00008fffffff1","fffff10000000000000000008f100c7008ff700000cff0000cfffffff1000008ffff00008fffffff1","fffff10000000000000000008f000ef008ff3000008ff1000efffffff300000cffff00000fffffff1","fffff100000000810000000006000ff10cff1000000ff3000ffffffff700000cffff00000fffffff1","fffff1000000008f0000000000008ff10cff1000000ff3008ff10ffff700000cffff00000fffffff1","fffff100000000cf100000000000cff10cff0000000ef700cf700cfff700000effff00000fffffff1","fffff100000000cf100000000000cff30cff0000000ef700cf3008fff700000effff00000fffffff1","fffff100000000cf100000000000eff30cff10cf000eff00ef1000fff300000fffff00000effffff1","fffff300000000cf100000000000fff308ff10cf100fff00ef0000eff300000fffff00000effffff1","fffff3000000000000000000000cfff708ff30ef300fff00ef0000cff300008fffff00000effffff1","fffff3000000000000000000000efff700ff30ef708fff10e70000cff300008fffff00000effffff1","fffff3000000000000000000000effff00ff30eff08fff10e700008ff300008fffff00000effffff1","fffff3000000000000000000000effff00ff30eff3efff10e700008ff100008fffff10000cffffff1","fffff3000000000000000000000effff10ff30efffffff10f30000cff000008fffff10000cffffff1","fffff30000000000000083000008ffff30cf30efffffff10f30000cff000008fffff10000cffffff1","fffff300000000000008f7000000ffff300f10efffffff00f10000cf700000cfffff10000cffffff1","fffff30000000000000ff7000000efff700000efffffff00f10000cf100000cfffff100008ffffff1","fffff3000000000000efff000000cffff000008fffffff00f30000c7000000e70fff100008ffffff1","fffff300000000000cfff70000000ffff000000effffff00f3000083000000e30cff100008ffffff1","fffff300000000000ffff30000000efff1000008fffff700e7000080000000f100ff100008ffffff1","fffff30000000f1cfffff10000000cfff1000000cffff700c7000000000008f000ef100008ffffff1","ffffff00000cffffffff3000000008fff30000000000e000cf000000000008f000ef100000ffffff1","ffffff30000cfffffff70000000000eff300000000000000cf00000000000c7000ef100000ffffff1","ffffff30000cffffff700000000000cff30e300000000000ef10000000000e3000cf100000ffffff1","ffffff30000cfffff30000000000008ff10f700000000000ff30000000000f1000cf100000ffffff1","ffffff30000cfffcf000000000000007008f700000000008ff38300000008f00008f100000ffffff1","ffffff3000008f100000000000000000008ff0000000000eff7f70000000c700000f100000ffffff1","ffffff30000000000000000200000000008ff0000000000fffff70000000c300000e100000ffffff1","ffffff3000000000000000c700000000000ff0000000008fffff10000000e1081000000000ffffff1","ffffff3000000000000008ff00000000000ff000000000cffff700000000f00c1000000000ffffff1","ffffff300000000000000eff30000000008ff000f00000cffff300000000700c1000000008ffffff1","ffffff30000000000000cfff70000000e7cff00cf30000cffff000000008700e1000000008ffffff1","ffffff3000000000000efffff0000000efcff00ef30000cfff3000000008700e1000000008ffffff1","ffffff300000000000effffff1000000effff00ff30000cff00000000008700e1000000008ffffff1","ffffff300000000000fffffff3000000cffff00ff3000081000000000000700f1040000008ffffff1","ffffff300000000000fffffff70000008ffff08ff3000000000000000000700f10c3000008ffffff1","ffffff30000000f300ffffffff0000000efff08ff1000000000000000000e00f10c7000008ffffff1","ffffff300000cff300ffffffff1000000efff1eff1000000000000000000e00f30cf000008ffffff1","ffffff300000fff700ffffffff1000000cfffffff0000000000000000000e08f30cf100008ffffff1","ffffff300000ffff00ffffffff30000008ffffff70000000000000000000c08f30cf300008ffffff1","ffffff300000ffff00ffffffff70000000ffffff70000000000000000e10008f30cf300008ffffff1","ffffff300000ffff00effffffff0000000ffffff30000000000000008f30008f30cf300008ffffff1","ffffff300000ffff00cfff10fff0000000efffff1000000000000000ef30008f30cf300008ffffff1","ffffff300000ffff00cff700cf10000000cfffff0000000000000000ff3000cf30cf700008ffffff1","ffffff300000ffff00cff10083000000008ffff7000cf0000000000eff3000cf70cf700008ffffff1","ffffff300000ffff00ef700000000000000ffff3000f7000000000cfff3000ef70cf700008ffffff1","ffffff300000ffff00ef300000000000000efff000cf3000000008ffff3000ff708f700008ffffff1","ffffff300000fff700ff000000000000000cff3000ff000000000effff1008ff708f700008ffffff1","ffffff300000fff700f700000000e0000008ff1008f7000000000effff100cff700f700008ffffff1","ffffff300000fff708f70087000ef1000000ef000ef1000000000cffff100eff700e700008ffffff1","ffffff300000fff30cf300cf700ff300000000000ff00000000008ffff100eff700e700008ffffff1","ffffff300000fff30ef100cff00ff70000000000cf300000000000ffff000fff700e700008ffffff1","ffffff300000fff30ff0008ff10fff0000000000ef100000000000efff000fff700e700008ffffff1","ffffff300000fff10f70000ff10fff1000000000ff000000000000cfff000fff300e700008ffffff1","ffffff300000fff10f70000ff30fff3000000008f30000000000008fff000fff100f700008ffffff1","ffffff300000fff10f70000ef30eff700000000cf30000000ff0000fff000ff7008f700008ffffff1","ffffff300000fff10f70000ef70efff00000000cf1000000cff3000eff000ef0008f300008ffffff1","ffffff300000fff10f30000ef70cfff10000000cf0000000fff7000eff00000000cf300008ffffff1","ffffff300000fff10f30000eff0cfff3000000087000000cffff100ef700000000ef300008ffffff1","ffffff300000fff10f30000fff0cfff7000000000000000fffff300ff700000008ff300000ffffff1","ffffff300000fff10f30e78fff18ffff00000000000000cfffff300ff30000000cff300000ffffff1","ffffff300000fff10f30ffffff08ffff10000000000000efffff300ff1000000ffff100000ffffff1","ffffff300000fff10f30ffffff08ffff30000000000008ffffff308ff0000008ffff000000ffffff1","ffffff300000fff10f30fffff708ffff3000000000000cffffff308ff000000cfff7000000ffffff1","ffffff300000fff10f30fffff708ffff3000000000000ffffff000cf7000000cfff3000000ffffff1","ffffff300000fff10e30effff308ffff3000000000008fffff0000cf7000000efff1000000ffffff1","ffffff300000fff30e308ffff108ffff300000000000cffff30000ef3000000eff70000000ffffff1","ffffff300000fff30e100efff00cffff100000000000cffff00000ff3000000eff10000000ffffff1","ffffff100000fff3040008ff700fffff100000000000cfff300000ff3000000eff00000000ffffff1","ffffff300000fff10000000f000fffff000000000000cfff100000ff7000000ef300000000ffffff1","ffffff300000ff7000000000008ffff7000000000000cff7000000ffffcff00cf000000000ffffff1","ffffff300000ff3000000000008ffff7000000000000cff3000000fffffff1083000000000ffffff1","ffffff300000ff000000000000cffff30000000000008ff1000000effffff1000000000000ffffff1","ffffff300000f70000000000008ffff000c7000000000ff000ff108ffffff0000000000000ffffff1","ffffff300000f300000efff7000fff7000ff000000000ef00eff300fffff70000000000000ffffff1","ffffff300000f100000ffffff00eff3008ff0000000000000fff7000cfff30000008000000ffffff1","ffffff3000003000008ffffff30cff000cff0000000000008ffff000000e0000000f100000ffffff1","ffffff3000000000008ffffff700f1000eff000000000000cffff0000000000000cf300000ffffff1","ffffff3000000008108fffffff0020000ff7000000000000cffff0000000000008ff300000ffffff1","ffffff300000000f300fffffff0000008ff3000000000000effff000000000000eff300000ffffff1","ffffff300000008f700effffff000000eff1000000000000ffff7000000000000fff300000ffffff1","ffffff30000000ef70000008ff000008fff0000000000000ffff7000870000008fff300000ffffff1","ffffff30000000ff70000008ff00000eff70000000000008ffff7008ff7000008fff300000ffffff1","ffffff30000008ff70000008ff00008fff30000000000008ffff308ffff300e08fff300000ffffff1","ffffff3000000eff7000000cff0000ffff30000000000008ffff108ffff700f18fff300000ffffff1","ffffff300000efff3000000ef7000cffff10000000000008ffff10cffff708f10fff300000ffffff1","ffffff300000ffff3000000ef308ffffff00000000000008ffff10cfffff08f10fff100000ffffff1","ffffff300008ffff0000000ff10cfffff700000c10000008ffff10cfffff08f10fff100000ffffff1","ffffff300008fff70000008ff10efffff300000e70000008ffff10efffff08f10fff100000ffffff1","ffffff30000cfff3000000cff00efffff100000f70000008ffff30eff3ff08f10fff100000ffffff1","ffffff30000cff70000000ef700cfffff000008f70000000ffff30eff1c70cf10fff100000ffffff1","ffffff30000cff00000000ef300cffff700000cf30000000efff30cff0870cf10fff100000ffffff1","ffffff30000cf700000000ef3008ffff100000ef10000000cfff30cf70000cf10fff100000ffffff1","ffffff30000cf300000000ff7000ffff000000ef000000008fff70cf70000cf10fff100000ffffff1","ffffff30000cf1008ff100ff7000eff3000000f7000000000fff70cf70000ef10fff100000ffffff1","ffffff30000cf100eff300fff000cff0000008f1000000000eff70cff0000ef00fff100000ffffff1","ffffff30000cf100fff300fff1000f0000000cf0000000000cff708ff0000ef00fff100000ffffff1","ffffff30000cf108fff300fff300000000000e300000000008ff708ff0000ff00fff100000ffffff1","ffffff30000cf108fff300fff700000000000f100000000000ff700ff1000ff00fff300000ffffff1","ffffff30000cf108fff100ffff00000000008f000000000000ef700cf1008f700fff300000ffffff1","ffffff30000cf108fff000ffff1000000000c7000000000000cf3008f1008f700fff300000ffffff1","ffffff30000cf108ff7008ffff7000000000e30000e00000008f0000f000cf700fff300000ffffff1","ffffff30000cf108ff300cfffff000000000f10000f30000000000000000cf308fff300000ffffff1","ffffff30000cf308ff100effff7000000008f0000cf70000000000000000ef008fff300000ffffff1","ffffff30000cf308ff000effff100000000e70000eff1000000000000000ef008fff300008ffffff1","ffffff30000cf308ff000effff000000000f30000fff7000000000000008ff00cfff300008ffffff1","ffffff30000cf308f7000cfff3000000008f1000cffff000000000e0000ef700efff300008ffffff1","ffffff300008f708f7000cfff100000000c70000effff30000000cf1008ff700efff300008ffffff1","ffffff300008f708f30008ff7000000000830000fffff70000000ff300eff700efff300008ffffff1","ffffff300008f708f30008ff300000000000000cffffff0000000fff08fff700efff300008ffffff1","ffffff300008f70cf10000ff000000000000000effffff1000000efffffff300efff100008ffffff1","ffffff300008f70cf10000f3000000000000000ff7cfff3000000cfffffff300efff100008ffffff1","ffffff300008ff0cf10800e1000000000000008ff70fff7000000cfffffff700efff100008ffffff1","ffffff300008ff0cf00c0060000000000000008ff30efff0000008ffffffff00cff0000008ffffff1","ffffff300000ff0cf00c1000000000000000008ff10efff1000000ffffffff000300000008ffffff1","ffffff3000000f0cf00c1000000000000000008ff10cfff3000000efffffff000000000008ffffff1","ffffff300000080c700c10000000008ff100008ff00cfff7000000cfffffff000000000008ffffff1","ffffff300000000c700c1000000008fff300008ff00cfff70000008ffffff7000000000008ffffff1","ffffff3000000008700e100000000ffff300008f700cfff30000000ffffff0000000000008ffffff1","ffffff3000000008700e100000008ffff300000f100ef1000000000effff10000000000008ffffff1","ffffff3000000008700f10000000cffff3000000000ef0000000000cfff100000000000008ffffff1","ffffff3000000008700f00000000effff3000000000ef00000000008ff3000000000000008ffffff1","ffffff3000000008308f0000000cfffff1000000000e700000000000ff000000000000000cffffff1","ffffff300000200000c70000000efffff0000000000e700000000000e1000000000000000cffffff1","ffffff300000f00000c70000000effff70000000000e7000000000004000000000cf30000cffffff1","ffffff300000f10000e70000000effff10000000000c7000000000000000000fbfff30000cffffff1","ffffff300000f70000f3000000000fff1000000000083081000000000000000fffff30000effffff1","ffffff300000ff0000f3000000000cff100000000000008ff100000000000effffff70000effffff1","ffffff300000ff1008f10000000000ff000000000000008ff30000000000cfffffff70000cffffff1","ffffff300000ff1008f10000000000ef008ff1000000008fff0000000008ffffffff70000cffffff1","ffffff300000ff300cf00000c30000ef00cffff00000008fff100000000effff700000000cffffff1","ffffff100000ff300ef00000f30000cf00effff70000000fff300000008fffff700000000cffffff1","ffffff100000ff700e700008f300008f00ffffff7000000eff70000000cfff10000000000cffffff1","ffffff100000fff00f70000cf300008f00fffffff000000efff0000000eff1000000000008ffffff1","ffffff300000fff70f30000ef100008f08fffffff100600cfff1000000ef70000000000008ffffff1","ffffff300000ffffff30000ff100008f08fffffff300f00cfff7000000cf10000000000008ffffff1","ffffff300000ffffff10000ff100008f08ffffeff308f308ffff0000000000000000000008ffffff1","ffffff300000ffffff10008ff10000cf08fff78ff308f708ffff1000000000000000000008ffffff1","ffffff300000ffffff00008ff30000cf08fff30ff308f700ffff3000000000000000000000ffffff1","ffffff300000ffffff0000cff30000ef08fff10ef308ff00ffff3000000000000000000000ffffff1","ffffff700000ffffff0000cff70000ef08fff00ef308ff00efff1000000000000000000000ffffff1","ffffff700000fffff70000cfff0000ff00fff00cf308ff00efff000000000000e000000000ffffff1","ffffff700000fffff70000efff0008ff00fff008f308ff10cff7000000000000f300000000ffffff1","ffffff700000fffff30000efff100cff00eff000f308ff10cff3000000000000f300000000efffff1","ffffff700000fffff30000efff300ef700eff000e308ff108ff3000000000000f300000000efffff1","fffffff00000fffff10000efff700ff300cff0000008ff108ff1000000000000f300000000efffff1","fffffff00000fffff10000effff3eff100cff0000008ff100ff1000000000000e100000000efffff1","fffffff00000fffff00000effffffff0008ff100000cff100ef0006000000000c000000000efffff1","fffffff00000ffff700000efffffff70000ff300000cff000cf000f1000000000000000000efffff1","fffffff00000ffff300000cfffffff30000ef300000eff00087000f1000000000000000000efffff1","fffffff00008ffff1000008fffffff10000cf300000fff00003008f1000000000000000000efffff1","fffffff10008ffff00000000efffff00000cf300008fff0000000cf1000000000000000000efffff1","fffffff10000ffff000000008ffff3000000f30000fff70000000cf0000000000000000000efffff1","fffffff10000eff7000000000efff1000000e10008fff70000000ef0000000000000000000efffff1","fffffff10000cff3000000000cff3000000000000cfff30000000ef0000000000000000000efffff1","fffffff100008ff30000000000f30000100000000efff100f3000e70000000000000000000efffff1","fffffff100000ff10000000000000008700000000efff10cf7000e70000000000000000000efffff1","fffffff100000ef1000000000000000cf10000000efff00ef7000e70000000000000000000efffff1","fffffff300000cf0000000000000000ef70000000eff700fff000f30000000000000000000efffff1","fffffff3000000f000000cf30000000fff1000000eff700fff000f30000000000000000000cfffff1","fffffff30000000000008ff7000000cffff100000eff308fff000f10000000000000000000cfffff1","fffffff3000000000000cfff000000ffffff7cf008ff308fff000f10000000000000000000cfffff1","fffffff3000000000000efff1000effffffffff000e300cfff10cf00000000000000000000cfffff1","fffffff3000000000000ffff100efffffffffff0000000cfff10cf10000000000000000000cfffff1","fffffff7000000000008ffff008ffffffffffff1000000efff10cf00000000000000000000cfffff1","fffffff700000000000effff00cffffffffffff1000000ffff10cf00000000000000000000cfffff1","fffffff700000000000fffff00ffffffff3ffff1000000ffff10cf00000000000000000000cfffff1","ffffffff00000000008ffff700fff9ffff1cfff0000000ffff10cf00000000000000000000cfffff1","ffffffff0000000000cffff108ff10efff18fff0000000efff10c700000000000000000000cfffff1","ffffffff0000000000effff00000008fff08fff0000000efff10c300000000000000000000cfffff1","ffffffff1000000000ffff700000000ef708fff0000000cfff10c300000000000000000000cfffff1","ffffffff1000000000ffff30000000000008fff00000008fff10e300000000000000000000cfffff1","ffffffff1000000000ffff10000000000000ff700000000fff10e300000000000000000000cfffff1","ffffffff3000000000ffff00000000000000ef300e30000eff00e300000000000000000000cfffff1","ffffffff3000000000fff700000000000000cf100ef7000eff00e3008f0000000000000000cfffff1","ffffffff3000000000fff7000000000000000f000fff100cff00f300cf1000000000000000cfffff1","ffffffff3000000000eff70000008100000000000fff700cff00f300ef1000000000000000cfffff1","ffffffff7000000000eff700000cf700000000000ffff00cff00f300cf0000000000000000cfffff1","ffffffff7000000000cff700000fff00000000008ffff30cff00f3008f00000000000000008fffff1","ffffffff7000000000cff70000cfff0000000000cffff70cff08f3000100000000000000008fffff1","fffffffff0000000008ff700cfffff0000000008ffffff0cff08f3000000000000000000008fffff1","fffffffff1000000000ff300ffffff008000000cffffff0cff08f3000000000000000000008fffff1","fffffffff30000000000f308ffffff00cff7008ffffff70cff00f3000000000000000000008fffff1","fffffffff70000000000000cffffff00efff18fffffff30cff00f1000000000000000000008fffff1","ffffffffff0000000000000cffffff00ffff1cfffffff308f700f1000000000000000000008fffff1","ffffffffff1000000000000cfffff708ffff0cfffffff108f700f1000000000000000000008fffff1","ffffffffff30000000000008fffff70cffff0cfffffff008f700f1000000000000000000000fffff1","ffffffffff70000000000000fffff30cffff0cffffff7008f700f1000000000000000000000fffff1","ffffffffff700000000000008ffff10cffff08ffffff30000700e1000000000000000000000fffff1","fffffffffff0000000000000000f7008ff000000000000000000e1000000000000000000000fffff1","fffffffffff10000000000000000000030000000000000000000e1000000000000000000000fffff1","fffffffffff3000000000000000000000000000000000000000000000000000000000000000effff1","fffffffffff7000000000000000000000000000000000000000000000000000000000000000effff1","ffffffffffff000000000000000000000000000000000000000000000000000000000000000effff1","ffffffffffff300000000000000000000000000000000000000000000000000000000000000effff1","fffffffffffff00000000000000000000000000000000000000000000000000000000000000effff1","fffffffffffff30000000000000000000000000000000000000000000000000000000000000cffff1","fffffffffffff70000000000000000000000000000000000000000000000000000000000000cffff1","ffffffffffffff1000000000000000000000000000000000000000000000000000000000000cffff1","ffffffffffffff7000000000000000000000000000000000000000000000000000000000000cffff1","fffffffffffffff100000000000000000000000000000000000000000000000000000000000cffff1","fffffffffffffff3000000000000000000000000000000000000000000000000000000000008ffff1","ffffffffffffffff100000000000000000000000000000000000000000000000000000000008ffff1","fffffffffffffffff10000000000000000000000000000000000000000000000000000000008ffff1","ffffffffffffffffff3000000000000000000000000000000000000000000000000000000008ffff1","fffffffffffffffffff300000000000000000000000000000000000000000000000000000008ffff1","ffffffffffffffffffff70000000000000000000000000000000000000000000000000000008ffff1","fffffffffffffffffffff7000000000000000000000000000000000000000000000000000008ffff1","fffffffffffffffffffffffffff3000000000000000000000000000000000000000000000008ffff1","fffffffffffffffffffffffffffffffffffffffffffffffffffff10000000000000000000008ffff1","ffffffffffffffffffffffffffffffffffffffffffffffffffffff0000000000000000000000ffff1","fffffffffffffffffffffffffffffffffffffffffffffffffffffff0000000000000000000008fff1","fffffffffffffffffffffffffffffffffffffffffffffffffffffff7000000000000000810008fff1","ffffffffffffffffffffffffffffffffffffffffffffffffffffffff700000000000810f30008fff1","ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffdf70008fff1","ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff70008fff1","fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff0008fff1","fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff0008fff1","fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff30cffff1","fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff70cffff1","ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff0effff1","ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff0effff1","ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff1","ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff1","ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff1","ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff1","ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff1","ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff1","ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff1","ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff1","ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff1","ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff1","ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff1","ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff1","ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff1","ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff1","ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff1","ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff1","ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff1","ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff1","ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff1","ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff1"},["mode"]="classic",["sha256"]="9a8f02985fa9ab4eb4bb8954341fcb16dd4fd559282ad5e79e547b224cfcbafc"}}

end
modules["lho.navigation"] = function(require)
return require('ChampionMobility.navigation')(require('lho.util'),require('lho.navdata'))

end
modules["lho.normalcampdata"] = function(require)
-- Map-11 spatial identities; asset anchors corrected by recorded stationary monsters.
return {["mode"]="normal",["mapID"]=11,["camps"]={{["name"]="Order_Owlbear",["category"]="Gromp",["team"]=100,["pos"]={["y"]=51.777317047119,["z"]=8450.984375,["x"]=2110.6279296875},["observed"]=true},{["name"]="Order_Blue",["category"]="Blue",["team"]=100,["pos"]={["y"]=52.035930633545,["z"]=7901.0541992188,["x"]=3821.4885253906},["observed"]=true},{["name"]="Order_Wolves",["category"]="Wolves",["team"]=100,["pos"]={["y"]=52.463195800781,["z"]=6443.9838867188,["x"]=3780.6279296875},["observed"]=true},{["name"]="Order_Wraiths",["category"]="Raptors",["team"]=100,["pos"]={["x"]=6823.8950195313,["y"]=54.782833099365,["z"]=5507.755859375},["observed"]=true},{["name"]="Order_Red",["category"]="Red",["team"]=100,["pos"]={["x"]=7765.244140625,["y"]=53.956443786621,["z"]=4020.1870117188},["observed"]=true},{["name"]="Order_Small_Golems",["category"]="Krugs",["team"]=100,["pos"]={["x"]=8482.470703125,["y"]=50.648094177246,["z"]=2705.9479980469},["observed"]=true},{["name"]="Chaos_OwlBear",["category"]="Gromp",["team"]=200,["pos"]={["y"]=51.699584960938,["z"]=6428.4287109375,["x"]=12679.630859375},["observed"]=true},{["name"]="Chaos_Blue",["category"]="Blue",["team"]=200,["pos"]={["y"]=51.723640441895,["z"]=6990.8442382813,["x"]=11031.728515625},["observed"]=true},{["name"]="Chaos_Wolves",["category"]="Wolves",["team"]=200,["pos"]={["y"]=62.090503692627,["z"]=8387.408203125,["x"]=11008.15234375},["observed"]=true},{["name"]="Chaos_Wraiths",["category"]="Raptors",["team"]=200,["pos"]={["y"]=52.347938537598,["z"]=9471.388671875,["x"]=7986.9970703125},["observed"]=true},{["name"]="Chaos_Red",["category"]="Red",["team"]=200,["pos"]={["y"]=56.282676696777,["z"]=10900.546875,["x"]=7101.869140625},["observed"]=true},{["name"]="Chaos_Small_Golems",["category"]="Krugs",["team"]=200,["pos"]={["x"]=6317.0922851563,["y"]=56.47679901123,["z"]=12146.458007813},["observed"]=true},{["name"]="Baron_Crab",["category"]="River",["team"]=0,["pos"]={["x"]=4400.0,["y"]=0.0,["z"]=9600.0}},{["name"]="Dragon_Crab",["category"]="River",["team"]=0,["pos"]={["x"]=10500.0,["y"]=0.0,["z"]=5170.0}},{["name"]="Dragon",["category"]="Dragon",["team"]=0,["pos"]={["x"]=9900.0,["y"]=0.0,["z"]=4350.0}},{["name"]="Baron",["category"]="Baron",["team"]=0,["pos"]={["x"]=4900.0,["y"]=0.0,["z"]=10408.0}}}}

end
modules["lho.normalcampobservations"] = function(require)
-- Recorded map-11 full stationary formations; estimates, never proof of current availability.
return {["mode"]="normal",["mapID"]=11,["estimated"]=true,["camps"]={["map:Order_Wraiths"]={["rows"]={{["pos"]={["x"]=6823.8950195313,["y"]=54.782833099365,["z"]=5507.755859375},["health"]=1200.0,["maxHealth"]=1200.0,["name"]="SRU_Razorbeak",["radius"]=75.0},{["pos"]={["x"]=6852.2290039063,["y"]=48.527000427246,["z"]=5227.083984375},["health"]=500.0,["maxHealth"]=500.0,["name"]="SRU_RazorbeakMini",["radius"]=50.0},{["pos"]={["x"]=7060.4580078125,["y"]=54.988708496094,["z"]=5499.2739257813},["health"]=500.0,["maxHealth"]=500.0,["name"]="SRU_RazorbeakMini",["radius"]=50.0},{["pos"]={["x"]=7106.2290039063,["y"]=48.714130401611,["z"]=5266.083984375},["health"]=500.0,["maxHealth"]=500.0,["name"]="SRU_RazorbeakMini",["radius"]=50.0},{["pos"]={["x"]=6949.8696289063,["y"]=57.342666625977,["z"]=5585.83984375},["health"]=500.0,["maxHealth"]=500.0,["name"]="SRU_RazorbeakMini",["radius"]=50.0},{["pos"]={["x"]=6962.7177734375,["y"]=50.31254196167,["z"]=5354.3540039063},["health"]=500.0,["maxHealth"]=500.0,["name"]="SRU_RazorbeakMini",["radius"]=50.0}},["at"]=64.581573486328,["session"]="2026-09-09-r23@0.856:163849968",["source"]="C:\\Users\\MuriD\\dev\\autolol\\tests\\results\\r23-live-review-20260909T151652Z\\normal-events.json"},["map:Order_Red"]={["rows"]={{["pos"]={["x"]=7765.244140625,["y"]=53.956443786621,["z"]=4020.1870117188},["health"]=2300.0,["maxHealth"]=2300.0,["name"]="SRU_Red",["radius"]=120.0}},["at"]=159.45994567871,["session"]="2026-09-09-r23@82.751:163931859",["source"]="C:\\Users\\MuriD\\dev\\autolol\\tests\\results\\r23-live-review-20260909T151652Z\\normal-events.json"},["map:Order_Small_Golems"]={["rows"]={{["pos"]={["x"]=8482.470703125,["y"]=50.648094177246,["z"]=2705.9479980469},["health"]=1400.0,["maxHealth"]=1400.0,["name"]="SRU_Krug",["radius"]=100.0},{["pos"]={["x"]=8275.470703125,["y"]=51.130001068115,["z"]=2688.9479980469},["health"]=650.0,["maxHealth"]=650.0,["name"]="SRU_KrugMini",["radius"]=50.0}},["at"]=162.72109985352,["session"]="2026-09-09-r23@82.751:163931859",["source"]="C:\\Users\\MuriD\\dev\\autolol\\tests\\results\\r23-live-review-20260909T151652Z\\normal-events.json"},["map:Chaos_Small_Golems"]={["rows"]={{["pos"]={["x"]=6317.0922851563,["y"]=56.47679901123,["z"]=12146.458007813},["health"]=1819.9998779297,["maxHealth"]=1819.9998779297,["name"]="SRU_Krug",["radius"]=100.0},{["pos"]={["x"]=6547.0922851563,["y"]=56.47679901123,["z"]=12156.458007813},["health"]=844.99993896484,["maxHealth"]=844.99993896484,["name"]="SRU_KrugMini",["radius"]=50.0}},["at"]=253.37214660645,["session"]="2026-09-09-r23@82.751:163931859",["source"]="C:\\Users\\MuriD\\dev\\autolol\\tests\\results\\r23-live-review-20260909T151652Z\\normal-events.json"},["map:Order_Blue"]={["rows"]={{["pos"]={["y"]=52.035930633545,["z"]=7901.0541992188,["x"]=3821.4885253906},["health"]=3220.0,["maxHealth"]=3220.0,["name"]="SRU_Blue",["radius"]=131.0}},["at"]=396.11608886719,["session"]="2026-09-09-r23@328.496:164177609",["source"]="C:\\Users\\MuriD\\dev\\autolol\\tests\\results\\r23-live-review-20260909T151652Z\\normal-events.json"},["map:Order_Owlbear"]={["rows"]={{["pos"]={["y"]=51.777317047119,["z"]=8450.984375,["x"]=2110.6279296875},["health"]=2870.0,["maxHealth"]=2870.0,["name"]="SRU_Gromp",["radius"]=120.0}},["at"]=427.36407470703,["session"]="2026-09-09-r23@328.496:164177609",["source"]="C:\\Users\\MuriD\\dev\\autolol\\tests\\results\\r23-live-review-20260909T151652Z\\normal-events.json"},["map:Order_Wolves"]={["rows"]={{["pos"]={["y"]=52.463195800781,["z"]=6443.9838867188,["x"]=3780.6279296875},["health"]=2240.0,["maxHealth"]=2240.0,["name"]="SRU_Murkwolf",["radius"]=80.0},{["pos"]={["y"]=52.461395263672,["z"]=6593.9838867188,["x"]=3730.6279296875},["health"]=882.0,["maxHealth"]=882.0,["name"]="SRU_MurkwolfMini",["radius"]=50.0},{["pos"]={["y"]=52.465576171875,["z"]=6443.9838867188,["x"]=3980.6279296875},["health"]=882.0,["maxHealth"]=882.0,["name"]="SRU_MurkwolfMini",["radius"]=50.0}},["at"]=452.64886474609,["session"]="2026-09-09-r23@328.496:164177609",["source"]="C:\\Users\\MuriD\\dev\\autolol\\tests\\results\\r23-live-review-20260909T151652Z\\normal-events.json"},["map:Chaos_OwlBear"]={["rows"]={{["pos"]={["y"]=51.699584960938,["z"]=6428.4287109375,["x"]=12679.630859375},["health"]=2870.0,["maxHealth"]=2870.0,["name"]="SRU_Gromp",["radius"]=120.0}},["at"]=608.65991210938,["session"]="2026-09-09-r23@328.496:164177609",["source"]="C:\\Users\\MuriD\\dev\\autolol\\tests\\results\\r23-live-review-20260909T151652Z\\normal-events.json"},["map:Chaos_Blue"]={["rows"]={{["pos"]={["y"]=51.723640441895,["z"]=6990.8442382813,["x"]=11031.728515625},["health"]=3450.0,["maxHealth"]=3450.0,["name"]="SRU_Blue",["radius"]=131.0}},["at"]=612.73748779297,["session"]="2026-09-09-r23@328.496:164177609",["source"]="C:\\Users\\MuriD\\dev\\autolol\\tests\\results\\r23-live-review-20260909T151652Z\\normal-events.json"},["map:Chaos_Wolves"]={["rows"]={{["pos"]={["y"]=62.090503692627,["z"]=8387.408203125,["x"]=11008.15234375},["health"]=2720.0,["maxHealth"]=2720.0,["name"]="SRU_Murkwolf",["radius"]=80.0},{["pos"]={["y"]=62.232624053955,["z"]=8217.408203125,["x"]=11058.15234375},["health"]=1071.0,["maxHealth"]=1071.0,["name"]="SRU_MurkwolfMini",["radius"]=50.0},{["pos"]={["y"]=62.946868896484,["z"]=8442.0068359375,["x"]=10842.231445313},["health"]=1071.0,["maxHealth"]=1071.0,["name"]="SRU_MurkwolfMini",["radius"]=50.0}},["at"]=926.73052978516,["session"]="2026-09-09-r23@876.955:164726062",["source"]="C:\\Users\\MuriD\\dev\\autolol\\tests\\results\\r23-live-review-20260909T151652Z\\normal-events.json"},["map:Chaos_Wraiths"]={["rows"]={{["pos"]={["y"]=52.347938537598,["z"]=9471.388671875,["x"]=7986.9970703125},["health"]=2040.0,["maxHealth"]=2040.0,["name"]="SRU_Razorbeak",["radius"]=75.0},{["pos"]={["y"]=52.363792419434,["z"]=9451.388671875,["x"]=7756.9970703125},["health"]=850.0,["maxHealth"]=850.0,["name"]="SRU_RazorbeakMini",["radius"]=50.0},{["pos"]={["y"]=52.445014953613,["z"]=9312.3896484375,["x"]=7886.9965820313},["health"]=850.0,["maxHealth"]=850.0,["name"]="SRU_RazorbeakMini",["radius"]=50.0},{["pos"]={["y"]=51.871074676514,["z"]=9724.083984375,["x"]=7724.2290039063},["health"]=850.0,["maxHealth"]=850.0,["name"]="SRU_RazorbeakMini",["radius"]=50.0},{["pos"]={["y"]=51.42586517334,["z"]=9772.083984375,["x"]=7997.2290039063},["health"]=850.0,["maxHealth"]=850.0,["name"]="SRU_RazorbeakMini",["radius"]=50.0},{["pos"]={["y"]=52.26575088501,["z"]=9610.4736328125,["x"]=7854.3891601563},["health"]=850.0,["maxHealth"]=850.0,["name"]="SRU_RazorbeakMini",["radius"]=50.0}},["at"]=937.10479736328,["session"]="2026-09-09-r23@876.955:164726062",["source"]="C:\\Users\\MuriD\\dev\\autolol\\tests\\results\\r23-live-review-20260909T151652Z\\normal-events.json"},["map:Chaos_Red"]={["rows"]={{["pos"]={["y"]=56.282676696777,["z"]=10900.546875,["x"]=7101.869140625},["health"]=4140.0,["maxHealth"]=4140.0,["name"]="SRU_Red",["radius"]=120.0}},["at"]=1062.0516357422,["session"]="2026-09-09-r23@876.955:164726062",["source"]="C:\\Users\\MuriD\\dev\\autolol\\tests\\results\\r23-live-review-20260909T151652Z\\normal-events.json"}}}

end
modules["lho.overlay"] = function(require)
local U=require('lho.util')
local O={};O.__index=O
function O.new(ctx) return setmetatable({ctx=ctx},O) end
local colors,provider={},nil
local function color(r,g,b)
    if provider~=Draw.Color then colors={};provider=Draw.Color end
    local key=r*65536+g*256+b
    if colors[key]==nil then colors[key]=Draw.Color(230,r,g,b) end
    return colors[key]
end
local function circle(p,r,col)
    if U.position(p) and U.finite(r) and r>0 and r<20000 then Draw.Circle(U.vector(p),r,2,col) end
end
local function line(a,b,col)
    if not U.position(a) or not U.position(b) then return end
    local p,q=U.vector(a):To2D(),U.vector(b):To2D()
    if p.onScreen and q.onScreen and U.finite(p.x) and U.finite(p.y) and U.finite(q.x) and U.finite(q.y) then
        Draw.Line(p.x,p.y,q.x,q.y,2,col)
    end
end
local function arrow(a,b,col)
    if not U.position(a) or not U.position(b) then return end
    local p,q=U.vector(a):To2D(),U.vector(b):To2D()
    if not p.onScreen or not q.onScreen or not U.finite(p.x) or not U.finite(p.y)
        or not U.finite(q.x) or not U.finite(q.y) then return end
    local dx,dy=q.x-p.x,q.y-p.y;local length=math.sqrt(dx*dx+dy*dy)
    if length<8 then return end
    dx,dy=dx/length,dy/length
    local size=math.min(18,length*.3);local bx,by=q.x-dx*size,q.y-dy*size
    Draw.Line(p.x,p.y,q.x,q.y,3,col)
    Draw.Line(q.x,q.y,bx-dy*size*.55,by+dx*size*.55,3,col)
    Draw.Line(q.x,q.y,bx+dy*size*.55,by-dx*size*.55,3,col)
end
function O:insecDrawing(i)
    local c=self.ctx;local green,amber,white=color(65,225,165),color(255,195,75),color(220,225,235)
    -- Rendering consumes the last controller geometry. It must not change the
    -- plan, destination, prediction lead or resource contract on a Draw call.
    local view={};for key,value in pairs(i) do view[key]=value end
    local old=i.geometryTarget or i.target.pos;local predicted=i.plannedTarget or old
    local start={x=i.target.pos.x+predicted.x-old.x,y=i.target.pos.y,z=i.target.pos.z+predicted.z-old.z}
    local aim=i.destination or c.aim
    if i.kind=='ally' and not i.locked and c.config:get('insecTrackAlly') and U.valid(i.recipient) then aim=i.recipient.pos end
    if i.locked and i.direction then aim={x=start.x+i.direction.x*1200,y=start.y,z=start.z+i.direction.z*1200} end
    local stand,endpoint=c.combat:direction({pos=start},aim)
    view.plannedTarget=start;view.plannedEndpoint=endpoint;view.stand=stand
    local display=c.combat.planner:adapt(view,i.plan);i.displayPlan=display
    circle(i.target.pos,85,amber);circle(stand,28,amber)
    if endpoint then
        -- Short directional arrow remains readable when the true endpoint is
        -- offscreen. Its head is at the destination, never at the kicked unit.
        arrow(start,U.toward(start,endpoint,math.min(550,U.dist(start,endpoint))),green)
        circle(endpoint,35,green)
        if c.config:get('drawInsecTolerance') then
            local ray=U.toward(start,endpoint,320);local dx,dz=ray.x-start.x,ray.z-start.z
            local angle=math.rad(c.config:get('insecAngle'));local cs,sn=math.cos(angle),math.sin(angle)
            for _,side in ipairs({-1,1}) do
                line(start,{x=start.x+dx*cs-dz*sn*side,y=start.y,z=start.z+dx*sn*side+dz*cs},color(35,95,75))
            end
        end
    end
    if i.recipient and U.position(i.recipient.pos) and not i.recipient.dead and (i.recipient.health or 0)>0 then
        circle(i.recipient.pos,65,green)
        local p=U.vector(i.recipient.pos):To2D()
        if p.onScreen then Draw.Text('KICK TO '..(i.recipient.charName or 'ALLY'),13,p.x+18,p.y-30,green) end
    end
    if display then
        local from=myHero.pos
        for n,step in ipairs(display.steps) do
            line(from,step.pos,amber);circle(step.pos,22,amber);from=step.pos
            local p=U.vector(step.pos):To2D()
            if p.onScreen then
                local name=step.kind=='q' and 'Q' or step.kind=='ward' and 'WARD > W' or step.kind:upper()
                Draw.Text(n..' '..name,12,p.x+12,p.y+10,amber)
            end
        end
        if display.walk then line(from,display.walk,amber) end
    end
    if i.alignment and not i.preview then line(myHero.pos,i.alignment.pos,amber) end
    local size=Game.Resolution and Game.Resolution() or {x=1920,y=1080}
    local x,y=math.max(12,size.x*.5-230),math.max(80,size.y-230)
    if Draw.Rect then Draw.Rect(x,y,460,84,Draw.Color(210,15,22,29)) end
    Draw.Text((i.preview and 'PREVIEW  ' or 'INSEC  ')..(i.target.charName or 'TARGET')..'  |  '..(i.kind=='ally' and 'TO ALLY' or 'TO CURSOR'),16,x+12,y+8,white)
    local fallback=i.flashReason and i.flashReason:find('Flash fallback:',1,true)
    local flash=i.flashConsent and 'FLASH APPROVED' or i.preview and 'FLASH MAY BE PROPOSED' or fallback and 'FLASH: NO WARD FALLBACK' or 'NO FLASH'
    local details=flash..'  |  '..(i.resource or 'Finding approach')
    if #details>66 then details=details:sub(1,63)..'...' end
    Draw.Text(details,13,x+12,y+31,amber)
    local previewKey=U.keyLabel(c.config:key('insecPreviewKey'))
    Draw.Text(i.preview and 'Release '..previewKey..': confirm shown route' or i.confirmBlocked and 'Hold '..previewKey..' to revise the plan'
        or 'Hold: continue   Right-click: move   Release: cancel',12,x+12,y+56,white)
end
function O:damageBars()
    local c=self.ctx;local cfg=c.config
    if not cfg:visible('damageBars',c.sdk,c.mode) or not c.damageModel or not Draw.Rect then return end
    local width,height=cfg:get('damageWidth'),cfg:get('damageHeight')
    local selected=cfg:get('damageSelected') and c:locked()
    for _,target in ipairs(c.enemies or {}) do
        local screen=U.valid(target) and U.vector(target.pos):To2D()
        local bar=screen and screen.onScreen and target.hpBar
        local native=bar and U.finite(bar.x) and U.finite(bar.y) and bar.onScreen~=false and (bar.x~=0 or bar.y~=0)
        if not native and screen and screen.onScreen and U.finite(screen.x) and U.finite(screen.y) then
            bar={x=screen.x-width*.5-cfg:get('damageX'),y=screen.y-70-cfg:get('damageY')}
        end
        if bar and U.finite(bar.x) and U.finite(bar.y) and bar.onScreen~=false
            and bar.x>=-width and bar.y>=-100
            and U.finite(target.maxHealth) and target.maxHealth>0
            and (not cfg:get('damageSelected') or U.same(target,selected)) and c:enemyValid(target) then
            local safe,max=c.damageModel:both(target);local cap=math.max(1,target.maxHealth or target.health or 1)
            local x,y=bar.x+cfg:get('damageX'),bar.y+cfg:get('damageY')
            local hp=U.clamp(target.health/cap,0,1)*width
            local function strip(result,offset,col)
                if not U.finite(result.damage) then return end
                local loss=U.clamp(result.damage/cap,0,target.health/cap)*width
                Draw.Rect(x,y+offset,hp,height,color(25,30,35))
                if loss>0 then Draw.Rect(x+hp-loss,y+offset,loss,height,col) end
            end
            if cfg:get('damageSafe') then strip(safe,0,color(65,225,165)) end
            if cfg:get('damageMax') then strip(max,height+1,color(255,175,75)) end
            if cfg:get('damageText') then
                local labels={}
                if cfg:get('damageSafe') and U.finite(safe.damage) then labels[#labels+1]='CON ~'..math.floor(safe.damage) end
                if cfg:get('damageMax') and U.finite(max.damage) then labels[#labels+1]=(max.estimated and 'MAX EST ~' or 'MAX ~')..math.floor(max.damage) end
                if #labels>0 then Draw.Text(table.concat(labels,' / ')..((safe.partial or max.partial) and ' *partial' or ''),12,x,y+height*2+3,color(230,230,240)) end
            end
        end
    end
end
function O:ranges()
    local c=self.ctx;local cfg=c.config
    if myHero.dead or not cfg:get('draw') or not Draw.Circle then return end
    if cfg:visible('drawQRange',c.sdk,c.mode) then circle(myHero.pos,c.profile.qRange,color(90,175,235)) end
    if cfg:visible('drawWRange',c.sdk,c.mode) then circle(myHero.pos,c.profile.wRange,color(65,225,165)) end
    if cfg:visible('drawERange',c.sdk,c.mode) then circle(myHero.pos,c.profile.eRange,color(255,195,75)) end
    if cfg:visible('drawRRange',c.sdk,c.mode) then circle(myHero.pos,c.profile.rRange,color(255,90,100)) end
    if cfg:visible('drawWardRange',c.sdk,c.mode) then circle(myHero.pos,c.wards:range(),color(220,225,235)) end
end
function O:draw()
    local c=self.ctx;if not Draw then return end
    if c.guide and c.config:get('guideOpen') then c.guide:draw();return end
    if not c.config:get('draw') then return end
    local white,green,amber,red=color(220,225,235),color(65,225,165),color(255,195,75),color(255,90,100)
    self:ranges()
    self:damageBars()
    local p=c.wards.previewState
    if c.config:visible('drawWard',c.sdk,c.mode) and c.input:held('wardKey') and not c.input.wardCancelled and p then
        local col=not p.valid and red or (p.kind=='assisted' or p.kind=='approach') and amber or green
        circle(p.pos,45,col);line(p.raw,p.pos,col)
        if p.path then
            local from=myHero.pos
            for _,point in ipairs(p.path) do line(from,point,amber);from=point end
            circle(p.stand,35,amber);line(p.stand,p.pos,col)
            if p.walkTo then circle(p.walkTo,20,white) end
        end
        if p.raw then circle(p.raw,15,white) end
        if p.pos then
            local s=U.vector(p.pos):To2D()
            if s.onScreen then
                local label=p.valid and p.kind or p.reason or 'Invalid'
                if c.config:get('diagnostics') and c.terrain.provider and c.terrain.provider.static then label=label..' [static map grid]' end
                Draw.Text(label,16,s.x+15,s.y,col)
            end
        end
    end
    local i=c.combat.insec
    if i and c.config:visible('drawInsec',c.sdk,c.mode) then
        self:insecDrawing(i)
    end
    if c.config:visible('drawWard',c.sdk,c.mode) and c.wards.pending then
        local pending=c.wards.pending;circle(pending.pos,45,amber)
        if pending.path then
            local from=myHero.pos
            for index=pending.index,#pending.path do line(from,pending.path[index],amber);from=pending.path[index] end
            line(from,pending.pos,green)
        end
    end
end
return O

end
modules["lho.profiles"] = function(require)
-- Runtime identifiers: repository ClassicAIO + Riot Data Dragon 16.17.1.
-- Classic combat coefficients are candidates, deliberately gated until measured.
local P={version='16.17.1',build='2026-09-23-r82',neutralTeam=300}
P.classicSmiteTargets={s3lizardelder=true,s3ancientgolem=true,lizardelder=true,ancientgolem=true,
    giantwolf=true,wraith=true,greatwraith=true,golem=true,wight=true,red=true,blue=true}
P.normalSmiteTargets={srured=true,srublue=true,srumurkwolf=true,srurazorbeak=true,
    srukrug=true,srugromp=true,srucrab=true,sruscuttlecrab=true,red=true,blue=true}
P.smites={summonersmite=600,s5summonersmiteplayerganker=1000,s5summonersmiteduel=1000,
    summonersmiteavataroffensive=1400,summonersmiteavatarutility=1400,summonersmiteavatardefensive=1400}
P.normal={id='normal',hero='LeeSin',qRange=1100,qSpeed=1800,qRadius=60,wRange=700,
    eRange=450,e2Range=600,rRange=375,kickDistance=1200,q2Range=1300,smiteRange=500,
    qBase={60,90,120,150,180},qRatio=1.15,eBase={35,60,85,110,135},eRatio=.9,
    rBase={175,400,625},rRatio=2,damageVerified=false,
    yellowWard=3340,
    wards={[2055]='stack',[2056]='stack',[3340]='charge',[3851]='charge',[3853]='charge',
        [3855]='charge',[3857]='charge',[3859]='charge',[3860]='charge',[3863]='charge',
        [3864]='charge',[3866]='charge',[3867]='charge',[3869]='charge',[3870]='charge',[3871]='charge',
        [3876]='charge',[3877]='charge',[4641]='stored',[4643]='stored'}}
P.classic={id='classic',hero='Jade_LeeSin',qRange=1100,qSpeed=1800,qRadius=60,wRange=700,
    -- Q1 BaseDamage/ADRatio confirmed in research/leesin/jade_leesin.bin.json.
    -- This narrow provenance does not certify Q2, item procs or other modes.
    q1DataMap=453,
    qMonsterAmplifiers={[771039]=1.1,[771080]=1.2,[773207]=1.3,[773209]=1.3},
    eRange=350,e2Range=500,rRange=375,kickDistance=1200,q2Range=1300,smiteRange=760,
    qBase={50,80,110,140,170},qRatio=.9,eBase={60,95,130,165,200},eRatio=1,
    rBase={200,400,600},rRatio=2,damageVerified=false,
    yellowWard=773340,
    wardInventoryCharges={[772045]=true,[772049]=true},
    wards={[772043]='stack',[772044]='stack',[772045]='charge',[772049]='charge',
        [772050]='stack',[773154]='cooldown',[773160]='cooldown',[773340]='charge'}}
P.qMarks={leesinqone=true,leesinqonemanager=true,leesinqprimed=true,leesinq2=true}
P.passive={leesinpassivebuff=true,leesinpassivecosmetic=true,leesinpassive=true}
P.eMarks={leesineone=true,leesinetempest=true,leesineonemanager=true}
P.immortal={judicatorintervention=true,kindredrnodeathbuff=true,undyingrage=true,
    kayler=true,zileanchronoshift=true,tryndamereundyingrage=true,zhonyasringshield=true}
-- Host flag disambiguation from pinned GG IsHeroImmortal; observed on normal
-- Jinx in the 55-minute trace. Not proof of a successful resurrection.
P.reviveReady={willrevive=true}
-- Names also used by repository Leona/KillerLib defensive-target checks;
-- GGPrediction documents runtime buff type 4 as SpellShield.
P.kickBlocked={morganae=true,bansheesveil=true,sivire=true,nocturneshroudofdarkness=true,
    olafragnarok=true,poppydiplomaticimmunity=true,malzaharpassiveshield=true}
P.epics={Dragon=true,Elder=true,Baron=true,Herald=true,Grubs=true,Atakhan=true}
-- Seconds after camp death, not first-spawn times. Boss values are estimates
-- until a native transition is recorded; see docs/LHO-R17-PLAYTEST.md.
P.respawns={
    -- Standard SR: 11.10 established 135s small camps. The 26.1 reductions
    -- to 120s / 270s apply to Swiftplay, not this profile (26.17 review).
    normal={Red=300,Blue=300,Wolves=135,Raptors=135,Krugs=135,Gromp=135,River=150,
        Dragon=300,Elder=360,Baron=360,Herald=0,Grubs=0,Atakhan=0},
    classic={Red=300,Blue=300,Wolves=75,Wraiths=75,Golems=75,Wight=50,Dragon=360,Baron=420}}
function P.get(hero)
    if hero=='LeeSin' then return P.normal elseif hero=='Jade_LeeSin' then return P.classic end
end
function P.category(name)
    name=(name or ''):lower()
    if name:find('dragon',1,true) then return name:find('elder',1,true) and 'Elder' or 'Dragon' end
    if name:find('baron',1,true) then return 'Baron' end
    if name:find('herald',1,true) then return 'Herald' end
    if name:find('horde',1,true) or name:find('voidgrub',1,true) then return 'Grubs' end
    if name:find('atakhan',1,true) then return 'Atakhan' end
    if name:find('ancientgolem',1,true) or name:find('sru_blue',1,true) then return 'Blue' end
    if name:find('lizardelder',1,true) or name:find('sru_red',1,true) then return 'Red' end
    if name:find('crab',1,true) or name:find('scuttle',1,true) then return 'River' end
    if name:find('wight',1,true) or name:find('greatwraith',1,true) then return 'Wight' end
    if name:find('wraith',1,true) then return 'Wraiths' end
    if name:find('gromp',1,true) then return 'Gromp' end
    if name:find('wolf',1,true) or name:find('wolves',1,true) then return 'Wolves' end
    if name:find('razorbeak',1,true) or name:find('raptor',1,true) then return 'Raptors' end
    if name:find('krug',1,true) then return 'Krugs' end
    if name:find('golem',1,true) then return 'Golems' end
    return 'Camp'
end
function P.jungleEntity(unit)
    local name=(unit and unit.charName or ''):lower()
    -- Map assets also contain non-camp props / the moving blue-buff spirit.
    -- Their names must not revive a cleared camp or become routing anchors.
    return name~='sru_spiritwolf' and name~='sru_baronspawn' and not name:find('_prop',1,true)
        and not name:find('plant',1,true)
end
P.openings={
    normal={{'Red','Krugs','Raptors','Wolves','Blue','Gromp'},{'Blue','Gromp','Wolves','Raptors','Red','Krugs'}},
    classic={{'Red','Golems','Wraiths','Wolves','Blue','Wight'},{'Blue','Wight','Wolves','Wraiths','Red','Golems'}}}
-- Fallback discovery centers only for regular SR. Classic uses observed Camp objects.
P.centers={{3735,7890,100,'Blue'},{3781,6444,100,'Wolves'},{2112,8450,100,'Gromp'},
    {6824,5508,100,'Raptors'},{7772,4028,100,'Red'},{8482,2706,100,'Krugs'},
    {11032,7002,200,'Blue'},{11008,8386,200,'Wolves'},{12702,6444,200,'Gromp'},
    {7987,9471,200,'Raptors'},{7108,10892,200,'Red'},{6317,12146,200,'Krugs'},
    {10423,5181,0,'River'},{4397,9610,0,'River'}}
P.campNames={ [1]='Blue',[2]='Wolves',[3]='Raptors',[4]='Red',[5]='Krugs',[6]='Dragon',
    [7]='Blue',[8]='Wolves',[9]='Raptors',[10]='Red',[11]='Krugs',[12]='Baron',
    [13]='Gromp',[14]='Gromp',[15]='River',[16]='River',[17]='Herald'}
return P

end
modules["lho.recasts"] = function(require)
local U=require('lho.util')
local R={}
-- Normalized aliases are explicit per profile; cosmetic values are presence
-- transitions only, never a remaining-attack count or standalone cast proof.
R.rules={
    normal={buffs={leesinpassivebuff=true,leesinpassive=true,leesinwtwo=true,leesinironwill=true}},
    classic={buffs={leesinpassivebuff=true,leesinpassivecosmetic=true,leesinwtwo=true,leesinironwill=true}}
}
local names={'leesinqtwo','leesinwtwo','leesinetwo'}
local function buffToken(c)
    local scope=U.buffScopeKey();local now=c:now();local cached=c.recastBuffCache
    if scope and cached and cached.scope==scope and cached.at==now then return cached.tokens end
    local out={};local aliases=R.rules[c.profile.id].buffs
    for _,b in ipairs(U.buffs(myHero)) do
        local name=U.name(b.name);local ends=U.buffEnd(b)
        if aliases[name] and (b.count==nil or b.count>0) and ends and ends>now and ends<=now+5 then
            out[name]=tostring(b.startTime or 0)..':'..tostring(ends)
        end
    end
    if scope then c.recastBuffCache={scope=scope,at=now,tokens=out} end
    return out
end
function R.snapshot(c,slot,sampledSpell,sampledStage)
    local d=sampledSpell or c:spell(slot);local now=c:now();local window=c.clear and c.clear.windows[slot]
    return {at=now,stage=sampledStage or c:stage(slot,nil,d),cd=d.currentCd or 0,mana=myHero.mana,cost=d.mana,
        window=window,buffs=buffToken(c),manual=c.manualSpellSerial or 0,name=d.name,
        origin=U.copy(myHero.pos)}
end
function R.evidence(c,slot,before,sentAt,manual,sampledAfter)
    if not before then return false,{reason='missing_before_sample'} end
    local now=c:now();local active=myHero.activeSpell
    local after=sampledAfter or R.snapshot(c,slot)
    local lower=sentAt or before.at
    local detail={sent=sentAt~=nil,window=before.window and before.window-lower,
        transition=after.stage~=before.stage or after.cd>before.cd+.05,
        resource=U.finite(before.mana) and U.finite(after.mana) and U.finite(before.cost) and before.cost>0
            and before.mana-after.mana>=math.max(1,before.cost*.8) or false}
    local physical=c.manualSpells and c.manualSpells[slot]
    local competing=sentAt and (c.manualSpellSerial or 0)>(before.manual or 0)
    if active and active.valid and U.name(active.name)==names[slot+1] and U.finite(active.startTime)
        and active.startTime>=lower and active.startTime<=now and now-active.startTime<.75 then
        detail.reason='active_spell';detail.at=active.startTime
        if not competing then return true,detail end
        detail.reason='manual_competition';return false,detail
    end
    detail.buff=false;detail.specificBuff=false
    for name,token in pairs(after.buffs) do
        if before.buffs[name]~=token then
            detail.buff=true
            -- Iron Will itself is evidence of W2. Net energy can stay flat or
            -- increase when passive attacks/refill occur across the input queue.
            -- A generic passive refresh alone cannot identify this spell.
            if slot==1 and (name=='leesinwtwo' or name=='leesinironwill') then detail.specificBuff=true end
        end
    end
    local path=myHero.pathing
    detail.dash=slot==0 and c:dash() and path and path.endPos and before.targetPos
        and U.dist(path.endPos,before.targetPos)<180 and U.dist(before.origin,path.endPos)>50 or false
    local requested=sentAt~=nil or manual and physical and physical.at>=before.at and physical.at<=now
    local timely=U.finite(lower) and now>=lower and now-lower<=.75
        and before.window and before.window>lower+.1 and now<before.window
    detail.reason=competing and 'manual_competition' or not requested and 'no_send_or_manual_input'
        or not timely and 'expired_or_unknown_recast_window' or not detail.transition and 'missing_stage_transition'
        or not detail.resource and not detail.dash and not detail.specificBuff and 'missing_specific_effect'
        or not detail.buff and not detail.dash and 'missing_new_buff_or_dash' or 'correlated_recast_effect'
    detail.at=now
    return not competing and requested and timely and detail.transition and (detail.resource or detail.dash or detail.specificBuff)
        and (detail.buff or detail.dash) or false,detail
end
return R

end
modules["lho.recovery"] = function(require)
local U=require('lho.util')
local function targetsHero(value)
    if type(value)=='table' or type(value)=='userdata' then return U.same(value,myHero) end
    return value~=nil and (value==myHero.handle or value==myHero.networkID)
end
return function(F)
    -- Awareness range is deliberately larger than the range at which we give
    -- up an ongoing clear. A laner 1,400 units away is not a recall request.
    function F:championPressure()
        local c=self.ctx;local now=c:now();local sample=self.pressureSample
        if sample and sample.at==now then return sample end
        local row={at=now,count=0}
        for _,enemy in ipairs(c.enemies or {}) do
            if U.valid(enemy) and enemy.team~=myHero.team then
                local distance=U.dist(myHero.pos,enemy.pos)
                if distance<=1400 then
                    local active=enemy.activeSpell
                    local targeting=active and active.valid and targetsHero(active.target)
                        and (active.castEndTime or active.endTime or now)>=now
                    local reach=U.clamp((enemy.range or 125)+(enemy.boundingRadius or 35)
                        +(myHero.boundingRadius or 35)+200,550,850)
                    local path=enemy.pathing;local closing=false
                    if path and path.hasMovePath and U.position(path.endPos) then
                        local predicted=U.toward(enemy.pos,path.endPos,math.min(U.dist(enemy.pos,path.endPos),(enemy.ms or 350)*.6))
                        closing=U.dist(predicted,myHero.pos)<reach and distance<reach+200
                    end
                    if targeting or distance<=reach or closing then
                        row.count=row.count+1
                        if not row.distance or distance<row.distance then
                            row.target=U.id(enemy);row.name=enemy.charName;row.distance=distance
                            row.reason=targeting and 'targeting_lee' or closing and 'approaching' or 'close_enemy'
                        end
                    end
                end
            end
        end
        self.pressureSample=row;return row
    end
    function F:combatSafety(fresh)
        local c=self.ctx;local now=c:now()
        if not fresh and self.safetySample and self.safetySample.at==now then return self.safetySample end
        if self.lastRecoveryHP and myHero.health<self.lastRecoveryHP-.1 then self.lastHurtAt=now end
        self.lastRecoveryHP=myHero.health
        local row={at=now,monsters=0,missiles=0,attacks=0,champions=c:threats(myHero.pos,1400),turret=c:underTurret(myHero.pos)}
        local seen={}
        local function check(m)
            local id=U.id(m);if not id or seen[id] or not U.valid(m) or m.team~=300 then return end;seen[id]=true
            local a=m.activeSpell;local attack=m.attackData
            local targeting=targetsHero(m.targetID) or targetsHero(m.target) or a and a.valid and targetsHero(a.target)
                or attack and targetsHero(attack.target)
            local close=U.dist(myHero.pos,m.pos)<=math.max(450,(m.range or 0)+100)
            -- Nearby members of a damaged/engaged camp are not safe just because
            -- their native target field is absent between two attacks.
            if targeting and U.dist(myHero.pos,m.pos)<=math.max(900,(m.range or 0)+200) or close and (m.health<(m.maxHealth or m.health) or U.same(c.attackTarget,m)
                or self.camp and self.camp.lastFoughtAt and now-self.camp.lastFoughtAt<2) then row.monsters=row.monsters+1 end
            if a and a.valid and targetsHero(a.target) and (a.castEndTime or now)>=now then row.attacks=row.attacks+1 end
        end
        for _,m in ipairs(c.minions or {}) do check(m) end
        for _,m in ipairs((self.camp or self.retreatCamp or {}).members or {}) do check(m) end
        if Game.MissileCount and Game.Missile then
            local ok,count=pcall(Game.MissileCount)
            if not ok or not U.finite(count) or count>4096 then row.unknown=true
            else for i=1,U.count(count,4096) do
                local yes,m=pcall(Game.Missile,i);local d=yes and m and m.missileData
                if not yes then row.unknown=true end
                if m and m.valid~=false and not m.dead and d and targetsHero(d.target or d.targetID) then row.missiles=row.missiles+1 end
            end end
        else row.unknown=true end
        local active=myHero.activeSpell
        if active and active.valid and active.isAutoAttack and (active.castEndTime or now)>=now then row.attacks=row.attacks+1 end
        row.recentDamage=self.lastHurtAt and now-self.lastHurtAt<1 or false
        row.safe=not row.unknown and row.monsters==0 and row.missiles==0 and row.attacks==0
            and row.champions==0 and not row.turret and not row.recentDamage
        self.safetySample=row;return row
    end
    function F:recallSafe(fresh) return self:combatSafety(fresh).safe end
    function F:finishForecast()
        local c=self.ctx;local camp=self.camp;local reserve=math.max(50,myHero.maxHealth*.08)
        local result={reserve=reserve,health=myHero.health,remainingHP=myHero.health,incoming=0,safe=false,members=0,reason='insufficient_data'}
        if not camp then return result end
        local units={};local cycle=c.sdk.Attack.GetAnimation and c.sdk.Attack:GetAnimation()
        if not U.finite(cycle) or cycle<=0 then return result end
        for _,m in ipairs(camp.members or {}) do
            if m.valid~=false and not m.dead and (m.health or 0)>0 then
                if not U.valid(m) or not U.finite(m.totalDamage) or not U.finite(m.attackSpeed) or m.attackSpeed<=0 then return result end
                local read,aa=pcall(c.aaDamage,c,m);if not read or not U.finite(aa) or aa<=0 then return result end
                local ok,damage=pcall(c.sdk.Damage.CalculateDamage,c.sdk.Damage,m,myHero,c.sdk.DAMAGE_TYPE_PHYSICAL,m.totalDamage)
                if not ok or not U.finite(damage) then return result end
                units[#units+1]={unit=m,hp=m.health,aa=aa,damage=math.max(0,damage),rate=m.attackSpeed}
            end
        end
        result.members=#units;if #units==0 or #units>12 then return result end
        local safety=self:combatSafety();if self:championPressure().count>0 or safety.turret or safety.missiles>0 or safety.unknown then return result end
        -- Reuse the clear model's actual attack damage and passive window. Do
        -- not credit unverified shields, future lifesteal or an unacquired Smite.
        c.clear:observe();local passive=c.clear.passiveLeft;local energy=myHero.mana or 0
        local focus=camp.focus
        table.sort(units,function(a,b)
            if U.same(a.unit,focus)~=U.same(b.unit,focus) then return U.same(a.unit,focus) end
            return a.hp/a.aa<b.hp/b.aa
        end)
        local elapsed=0;local hp=myHero.health;local spells={} -- Unknown shield expiry is not future health.
        for _,row in ipairs(units) do
            local m=row.unit;local remaining=row.hp
            for _,slot in ipairs({2,0}) do
                local stage=c:stage(slot,m);local cost=c:spell(slot).mana or 0
                local plan={stage=stage};local allowed=false
                if slot==2 then allowed=c.spells:allowed(slot,m,'farm',plan)
                elseif stage==2 then allowed=c.spells:allowed(slot,m,'farm',plan) end
                local enabled=c.config:get('autoClearAbilities') and c.config:get(slot==2 and 'autoClearE' or 'autoClearQ2')
                local damage=enabled and not spells[slot] and allowed and cost<=energy and c:damage(slot,m,stage) or 0
                if damage>0 then
                    remaining=remaining-damage;energy=energy-cost;spells[slot]=true;elapsed=elapsed+.25
                    if slot==2 and stage==1 then
                        for _,other in ipairs(units) do
                            if other~=row and not other.finished and c.spells:allowed(2,other.unit,'farm',{stage=1}) then
                                other.hp=math.max(0,other.hp-c:damage(2,other.unit,1))
                            end
                        end
                    end
                end
            end
            local hits=math.max(0,math.ceil(remaining/row.aa))
            local boosted=math.min(hits,passive);passive=math.max(0,passive-boosted)
            elapsed=elapsed+math.max(0,U.dist(myHero.pos,m.pos)-c:attackRange(m))/math.max(1,myHero.ms or 350)
                +(boosted+(hits-boosted)*1.5)*cycle -- Margin after the observed passive window is spent.
            if elapsed>8 then result.reason='clear_horizon_exceeded';return result end
            local incoming=0
            for _,other in ipairs(units) do if not other.finished then
                incoming=incoming+other.damage*math.max(1,math.ceil(elapsed*other.rate))
            end end
            -- Bound each alive attacker's total exposure up to this kill point.
            local total=(result.finishedDamage or 0)+incoming
            result.incoming=math.max(result.incoming,total);result.remainingHP=hp-result.incoming
            if result.remainingHP<reserve then result.reason='below_reserve';return result end
            row.finished=true;result.finishedDamage=(result.finishedDamage or 0)+row.damage*math.max(1,math.ceil(elapsed*row.rate))
        end
        result.safe=true;result.elapsed=elapsed;result.reason='clear_above_reserve';return result
    end
    function F:recoveryTransition(state,reason,forecast)
        if self.state~=state or self.recoveryReason~=reason then
            self.state=state;self.recoveryReason=reason
            if self.ctx.config.capture then
                local f=forecast or {};self.ctx:log('recovery_transition',{state=state,reason=reason,health=myHero.health,
                    trigger=self.recoveryTrigger,recallWanted=self.recoveryWanted==true,pressure=self:championPressure(),
                    camp=self.camp and self.camp.id,remainingHP=f.remainingHP,incoming=f.incoming,reserve=f.reserve,members=f.members})
            end
        end
    end
    function F:beginRetreat(reason,recallWanted)
        if self.state~='retreating' then
            self.actions:cancel('farm');self.retreatCamp=self.camp;self.camp=nil
            self.probe=nil;self.travelTarget=nil;self.travelJob=nil;self.opening=nil
            self.retreatMove=nil;self.localException=nil;self.returningHome=true
        end
        if recallWanted~=false then self.recoveryWanted=true end
        self:recoveryTransition('retreating',reason)
    end
    function F:retreat()
        local c=self.ctx;local now=c:now();local spawn=self:spawn()
        c.attackTarget=nil
        if not spawn then c.status='Retreat destination unavailable';return true end
        local goal;local move=self.retreatMove
        local ground=require('lho.ground');local scene
        if move and now-move.at<=.75 then goal=move.goal
        else
            scene=ground.scene(c)
            local direct=U.toward(myHero.pos,spawn,1);local dx,dz=direct.x-myHero.pos.x,direct.z-myHero.pos.z
            local best=math.huge;local radius=myHero.boundingRadius or 35
            for _,angle in ipairs({0,.6,-.6,1.2,-1.2,1.8,-1.8,3.14}) do
                local x,z=dx*math.cos(angle)-dz*math.sin(angle),dx*math.sin(angle)+dz*math.cos(angle)
                for _,distance in ipairs({500,250,100}) do
                    local p={x=myHero.pos.x+x*distance,y=myHero.pos.y,z=myHero.pos.z+z*distance}
                    if c.terrain:egressLine(myHero.pos,p,radius) and not c:underTurret(p) and not ground.blocker(c,p,scene) then
                        local score=U.dist(p,spawn)+c:threats(p,700)*1000
                        if score<best then best=score;goal=p end
                        break
                    end
                end
            end
        end
        if not goal then
            -- A coarse navigation grid must never turn retreat into standing
            -- still. Native pathfinding owns the route to a visible free point.
            -- The cursor dispatcher still verifies the click and avoids bodies.
            local best=math.huge;scene=scene or ground.scene(c)
            for step=0,15 do
                local angle=step*math.pi/8
                for _,distance in ipairs({500,250,100}) do
                    local p={x=myHero.pos.x+math.cos(angle)*distance,y=myHero.pos.y,z=myHero.pos.z+math.sin(angle)*distance}
                    if c.terrain:walkWall(p)==false and U.vector(p):To2D().onScreen and not c:underTurret(p) and not ground.blocker(c,p,scene) then
                        local score=U.dist(p,spawn)+c:threats(p,700)*1000
                        if score<best then best=score;goal=p end
                    end
                end
            end
            if c.config.capture then c:trace('retreat_ground_fallback',{goal=U.copy(goal),origin=U.copy(myHero.pos),
                reason='No clearance-safe direct ray; native walking route'},'retreat_ground',1) end
        end
        c.moveTarget=goal
        local move=self.retreatMove
        if move and U.dist(myHero.pos,move.origin)>35 then
            if not move.observed and c.config.capture then c:log('recovery_progress',{cursorID=move.id,distance=U.dist(myHero.pos,move.origin)}) end
            move.observed=true
        end
        if goal and (not move or now-move.at>.75) then
            local accepted=self.actions:move(goal,'escape')
            if accepted then self.retreatMove={at=now,origin=U.copy(myHero.pos),id=self.actions.lastCursorAction,goal=U.copy(goal)} end
        end
        if c:ready(1) then
            local ally=c.wards:existing(U.toward(myHero.pos,spawn,600),250)
            if ally and U.dist(ally.pos,spawn)<U.dist(myHero.pos,spawn) then c.spells:w(ally,'escape',true)
            else c.spells:w(myHero,'escape',true) end
        end
        if c.config:get('defensiveR') then
            for _,enemy in ipairs(c.enemies or {}) do
                if c:enemyValid(enemy) and U.dist(myHero.pos,enemy.pos)<=c.profile.rRange then c.spells:r(enemy,'escape',true);break end
            end
        end
        if c.actives then c.actives:defense('escape');c.actives:potions('escape') end
        if not goal then
            -- Retain retaliation while unable to move; do not silently surrender
            -- all attacks to a failed terrain query.
            local nearest,distance=nil,math.huge
            for _,m in ipairs(self.retreatCamp and self.retreatCamp.members or {}) do
                local d=U.dist(myHero.pos,m.pos)
                if self:ordinaryTarget(m) and d<=c:attackRange(m) and d<distance then nearest,distance=m,d end
            end
            c.attackTarget=nearest
            if nearest then c.clear:tick(nearest,'farm') end
        end
        c.status=goal and 'Retreating; auto-jungle remains enabled' or 'Retreat path unavailable; defending while retrying'
        return true
    end
end

end
modules["lho.runtime"] = function(require)
local U=require('lho.util')
local P=require('lho.profiles')
local R={}; R.__index=R
function R.new(profile,config)
    return setmetatable({profile=profile,config=config,sdk=_G.SDK,events={},cacheAt=-1,latency=.05,
        jitter=0,selected=nil,mode='idle',synthetic=false,injected={},status='Idle',verification={},metrics={}},R)
end
function R:now() return Game.Timer() end
function R:playerPosition()
    if self.sdk.Actions and self.sdk.Actions.GetPlayerPosition then return self.sdk.Actions:GetPlayerPosition() end
    return self.sdk.Input and self.sdk.Input:GetPlayerPosition() or U.copy(mousePos or self.aim or myHero.pos)
end
function R:log()end
function R:chatOpen()
    if self.sdk.Input and self.sdk.Input.IsChatOpen then return self.sdk.Input:IsChatOpen() end
    return Game.IsChatOpen and Game.IsChatOpen() or false
end
function R:blocked()
    return not self.config:get('enabled') or myHero.dead or self:chatOpen()
        or (Game.IsOnTop and not Game.IsOnTop())
end
function R:recalling()
    if self.sdk.IsRecalling then return self.sdk.IsRecalling(myHero) end
    return U.buff(myHero,{recall=true,recallimproved=true},self:now())~=nil
end
function R:refresh()
    local now=self:now()
    if now<(self.cacheAt or 0)+.08 then return end
    self.cacheAt=now
    local ms=Game.Latency and Game.Latency() or 50
    if type(ms)=='number' and ms>=0 and ms<=2000 then
        local sample=ms/1000
        self.jitter=self.jitter*.8+math.abs(sample-self.latency)*.2
        self.latency=self.latency*.8+sample*.2
    end
    self.heroes={};self.enemies={};self.allies={};self.minions={};self.wardObjects={};self.turrets={};self.camps={}
    for _,entry in ipairs({{'Hero','heroes'},{'Minion','minions'},{'Ward','wardObjects'},{'Turret','turrets'},{'Camp','camps'}}) do
        local shared=self.sdk.SharedData
        local kind=entry[2]=='wardObjects' and 'wards' or entry[2]
        local snapshot=shared and shared:GetObjects(kind)
        if snapshot and snapshot.ageMs<=80 then self[entry[2]]=snapshot.objects
        else
            local count,get=Game[entry[1]..'Count'],Game[entry[1]]
            if count and get then for i=1,U.count(count(),entry[1]=='Minion' and 4096 or 512) do
                local unit=get(i);if unit then self[entry[2]][#self[entry[2]]+1]=unit end
            end end
        end
    end
    local monsters={}
    for _,m in ipairs(self.minions) do if m.team==300 and P.jungleEntity(m) then monsters[#monsters+1]=m end end
    self.monsterCache={source=self.minions,units=monsters}
    for _,h in ipairs(self.heroes) do
        if U.valid(h) and not U.same(h,myHero) then
            local list=h.team==myHero.team and self.allies or self.enemies;list[#list+1]=h
        end
    end
end
function R:spellSlot(slot)
    -- Inventory positions are 6..12; native spell-slot constants are a
    -- separate API. Do not assume ITEM_1..ITEM_7 equal those positions.
    return slot>=6 and slot<=12 and (_G['ITEM_'..(slot-5)] or slot) or slot
end
function R:spell(slot) return myHero:GetSpellData(self:spellSlot(slot)) or {} end
function R:stage(slot,markedTarget,sampledSpell)
    local spell=sampledSpell or self:spell(slot);local name=U.name(spell.name)
    if slot==0 and (name=='leesinqone' or name=='leesinqmanager' or name=='leesinqoneability') then
        local scope=U.buffScopeKey();local cached=self.qStageCache
        if scope and cached and cached.scope==scope and cached.name==name and cached.toggle==spell.toggleState
            and cached.minions==self.minions and cached.enemies==self.enemies then
            if cached.stage~=2 and U.valid(markedTarget) and self:mark(markedTarget,name) then cached.stage=2 end
            return cached.stage
        end
        local function resolved(stage)
            if scope then self.qStageCache={scope=scope,name=name,toggle=spell.toggleState,
                minions=self.minions,enemies=self.enemies,stage=stage} end
            return stage
        end
        if U.valid(markedTarget) and self:mark(markedTarget,name) then return resolved(2) end
        for _,list in ipairs({self.minions or {},self.enemies or {}}) do
            for _,unit in ipairs(list) do
                if unit.team~=myHero.team and U.valid(unit) and self:mark(unit,name) then return resolved(2) end
            end
        end
        local fallback=name=='leesinqmanager' and (spell.toggleState==2 and 2 or spell.toggleState==1 and 1 or 0)
            or name=='leesinqone' and spell.toggleState==2 and 2 or 1
        return resolved(fallback)
    end
    if slot==0 and (name=='leesinqone' or name=='leesinqmanager') and spell.toggleState==2 then return 2 end
    if slot==0 and name=='leesinqmanager' and spell.toggleState==1 then return 1 end
    if name:find('two',1,true) or name:match('[qwe]2$') or name=='ironwill' or name=='cripple' then return 2 end
    if name:find('one',1,true) or name:match('[qwe]1$') or name=='safeguard' or name=='tempest' then return 1 end
    return 0
end
function R:ready(slot)
    local d=self:spell(slot)
    if slot>=6 and (d.currentCd or 0)>0 then return false end
    return (slot>3 or (d.level or 0)>0) and (d.mana or 0)<=(myHero.mana or 0) and Game.CanUseSpell(self:spellSlot(slot))==0
end
function R:mark(unit,spellName)
    local mark=U.buff(unit,P.qMarks,self:now(),U.id(myHero))
    if not mark and myHero.handle and myHero.handle~=U.id(myHero) then mark=U.buff(unit,P.qMarks,self:now(),myHero.handle) end
    -- Recorded in both runtimes: the active QOne debuff's sourcenID equals
    -- the monster's ID, not Lee's. Accept that representation only while our
    -- own slot explicitly exposes QTwo, and only for an unambiguous target.
    -- Foreign caster IDs retain the existing ownership rule.
    if not mark and U.name(spellName or self:spell(0).name)=='leesinqtwo' then
        local function recipientMark(target)
            local b=U.buff(target,{leesinqone=true},self:now(),U.id(target))
            local source=b and (b.sourcenID and b.sourcenID~=0 and b.sourcenID or b.sourceID)
            return b and source==U.id(target) and b or nil
        end
        mark=recipientMark(unit)
        if mark then
            local scan=self.recipientMarkScan;local id=U.id(unit)
            if scan and scan.at==self:now() and scan.target==id then return not scan.ambiguous and mark or nil end
            local ambiguous=false
            for _,list in ipairs({self.minions or {},self.enemies or {}}) do
                for _,other in ipairs(list) do
                    if U.valid(other) and not U.same(other,unit) and recipientMark(other) then ambiguous=true;break end
                end
                if ambiguous then break end
            end
            self.recipientMarkScan={at=self:now(),target=id,ambiguous=ambiguous}
            if ambiguous then return nil end
        end
    end
    return mark
end
function R:trace(kind,fields,key,interval)
    local persistent=self.config:get('combatLogging') and (fields and (fields.owner=='autosmite' or fields.owner=='insec' or fields.owner=='fight')
        or kind:match('^smite_') or kind:match('^insec_') or kind:match('^combo_'))
    if not persistent and (not self.config:get('playtestLogging') or self.playtestState=='finished') then return end
    self.traceLimits=self.traceLimits or {};key=kind..':'..tostring(key or '')
    if self:now()<(self.traceLimits[key] or 0) then return end
    self.traceLimits[key]=self:now()+(interval or 1);self:log(kind,fields)
end
function R:markLeft(unit)
    local b=self:mark(unit)
    return b and math.max(0,(U.buffEnd(b) or (self:now()+.2))-self:now()) or 0
end
function R:passive() return self.clear and self:now()<self.clear.passiveUntil and self.clear.passiveLeft or 0 end
function R:dash() return myHero.pathing and myHero.pathing.isDashing end
function R:combatTransit()
    local now=self:now();local active=myHero.activeSpell
    if self:dash() then self.combatDashActive=true;return true end
    if self.combatDashActive then self.combatDashActive=nil;self.combatDashEndedAt=now end
    if active and active.valid and U.name(active.name):find('leesinqtwo',1,true)
        and U.finite(active.startTime) and active.startTime>(self.combatDashEndedAt or -math.huge)
        and now-active.startTime>=0 and now-active.startTime<.8 then return true end
    local press=self.manualSpells and self.manualSpells[0]
    -- Bridge the physical-Q2 to native-dash acknowledgement gap, without
    -- treating an unacknowledged press as an indefinitely active dash.
    return press and press.before and press.before.stage==2 and press.at>(self.combatDashEndedAt or -math.huge)
        and now-press.at>=0 and now-press.at<.20 or false
end
function R:abilityEnabled(slot,stage,owner,target,abilityPolicy)
    local jungleW=slot==1 and (U.same(target,myHero) or stage==2 and target==nil)
        and (owner=='farm' and abilityPolicy=='autoClear' or owner=='clear' and abilityPolicy=='jungle')
    if slot==1 and self.config:get('reserveW') and not jungleW then
        -- Controller policy: explicit mobility owns W, ordinary rotations do not.
        if owner=='defense' then return stage==1 and U.same(target,myHero) end
        if owner~='ward' and owner~='insec' and owner~='escape' then return false end
        if stage~=1 or owner=='escape' and (not target or U.same(target,myHero)) then return false end
    end
    local mode=owner
    if owner=='expiry' or owner=='defense' or owner=='killsteal' then mode=self.mode end
    local prefix=mode=='fight' and 'combo' or mode=='harass' and 'harass'
    if prefix and slot>=0 and slot<=3 then
        local key=({[0]='Q',[1]='W',[2]='E',[3]='R'})[slot]
        if not self.config:get(prefix..key..(stage==2 and '2' or '')) then return false end
    end
    if slot==0 and stage==1 and self.config:get('qOnlySelected') and target and target.type==myHero.type and target.team~=300
        and target.team~=myHero.team and mode~='insec' and mode~='farm' then
        local selector=self.sdk.TargetSelector;local selected=selector and selector.Selected or self.selected
        if not U.same(target,selected) then return false end
    end
    return true
end
function R:pendingAttackDamage(target,delay)
    local active=myHero.activeSpell;local now=self:now()
    if not target or not active or not active.valid or active.isStopped then return 0 end
    local name=U.name(active.name)
    if not active.isAutoAttack and not name:find('basicattack',1,true) and not name:find('critattack',1,true) then return 0 end
    local id=active.target
    if not id or id==0 or id~=target.handle and id~=target.networkID then return 0 end
    local finish=active.castEndTime;local start=active.startTime
    if not U.finite(finish) or not U.finite(start) or start>now or finish<start or finish-start>1.5
        or finish>now+delay or now>finish+math.min(.12,self.latency*.5+.06) then return 0 end
    local attack=self.finishingAttack
    if not attack or attack.start~=start or attack.target~=U.id(target) then
        attack={start=start,target=U.id(target),health=target.health};self.finishingAttack=attack
    end
    -- Once damage is visible, never subtract that auto again from remaining HP.
    if target.health<attack.health-.5 then return 0 end
    return math.max(0,self:aaDamage(target)),math.max(0,finish-now)
end
function R:attackFinishesBefore(target,delay)
    return target and self:pendingAttackDamage(target,delay)>=U.typedHP(target,'physical')+5 or false
end
function R:attackRange(target)
    if self.sdk.Data and self.sdk.Data.GetAutoAttackRange then return self.sdk.Data:GetAutoAttackRange(myHero,target) end
    return (myHero.range or 125)+(myHero.boundingRadius or 65)+(target and target.boundingRadius or 0)
end
function R:jungleQ2Range(target)
    return math.min(self.profile.q2Range,self:attackRange(target)*U.clamp(self.config:get('jungleQ2RangeScale') or 2,1,4))
end
function R:windup()
    return self.sdk.Attack and self.sdk.Attack.GetWindup and self.sdk.Attack:GetWindup() or .25
end
function R:healthAt(target,delay)
    local hp=self.sdk.HealthPrediction
    if hp and hp.GetPrediction then
        local ok,value=pcall(hp.GetPrediction,hp,target,math.max(0,delay))
        if ok and type(value)=='number' and value==value and value>-math.huge and value<math.huge then return value end
    end
    return target.health or 0
end
function R:aaDamage(target)
    local d=self.sdk.Damage
    if d and d.GetAutoAttackDamage then return d:GetAutoAttackDamage(myHero,target,true) end
    return (myHero.totalDamage or 0)*100/(100+math.max(0,target.armor or 0))
end
function R:damage(slot,target,stage,healthOverride)
    if not self.config:get('mechanicsVerified') and not self.profile.damageVerified then return 0 end
    return self:spellDamageEstimate(slot,target,stage,healthOverride)
end
function R:combatDamage(slot,target,stage,healthOverride)
    local damage=self:damage(slot,target,stage,healthOverride)
    if self.config:get('mechanicsVerified') or self.profile.damageVerified then return damage end
    if self.config:get('combatEstimates') and self:enemyValid(target) then
        -- Deliberately separate from objective/Smite guaranteed damage.
        return self:spellDamageEstimate(slot,target,stage,healthOverride)*.9
    end
    return 0
end
function R:spellDamageEstimate(slot,target,stage,healthOverride)
    local p=self.profile;local rank=self:spell(slot).level or 0
    if rank==0 then return 0 end
    local bonus=myHero.bonusDamage or math.max(0,(myHero.totalDamage or 0)-(myHero.baseDamage or 0))
    local raw,dtype=0,self.sdk.DAMAGE_TYPE_PHYSICAL
    if slot==0 then
        raw=(p.qBase[rank] or 0)+p.qRatio*bonus
        if stage==2 then
            local missing=math.max(0,(target.maxHealth or 0)-(healthOverride or target.health or 0))
            if p.id=='classic' then raw=raw+missing*.08
            else raw=raw*(1+missing/math.max(1,target.maxHealth or 1)) end
            -- Never count an unmeasured monster execute amplification as guaranteed.
            if target.team==300 then raw=(p.qBase[rank] or 0)+p.qRatio*bonus end
        end
    elseif slot==2 then raw=(p.eBase[rank] or 0)+p.eRatio*(p.id=='normal' and (myHero.totalDamage or 0) or bonus);dtype=self.sdk.DAMAGE_TYPE_MAGICAL
    elseif slot==3 then raw=(p.rBase[rank] or 0)+p.rRatio*bonus end
    if slot==0 and target.team==300 then
        local cap=self.config:get('monsterQCap')
        if not cap or cap<=0 then return 0 end
        raw=math.min(raw,cap)
    end
    if self.sdk.Damage and self.sdk.Damage.CalculateDamage then
        return self.sdk.Damage:CalculateDamage(myHero,target,dtype,raw,true,slot==3)
    end
    local resist=dtype==self.sdk.DAMAGE_TYPE_MAGICAL and (target.magicResist or 0) or (target.armor or 0)
    return raw*(resist>=0 and 100/(100+resist) or 2-100/(100-resist))
end
function R:enemyValid(target)
    if not U.valid(target) or target.team==myHero.team or target.team==300 then return false end
    local now=self:now()
    if U.buff(target,P.immortal,now) then return false end
    -- The host may flag a ready resurrection as immortal. GG explicitly
    -- distinguishes willrevive from active invulnerability. A living,
    -- targetable carrier is still a combat target; an unknown flag stays gated.
    if target.isImmortal and not U.buff(target,P.reviveReady,now) then return false end
    return true
end
function R:locked()
    local selector=self.sdk.TargetSelector
    local target
    if selector and selector.GetSelectedTarget then target=selector:GetSelectedTarget()
    elseif selector and selector.GetTarget then target=selector.Selected else target=self.selected end
    if selector and selector.GetTarget and selector.MenuCheckSelected and not selector.MenuCheckSelected:Value() then return nil end
    if not self.selectionOwned and not target and not (selector and selector.GetSelectedTarget) then target=selector and selector.Selected end
    if target and (target.dead or (target.health or 0)<=0) then self.selected=nil;return nil end
    return target
end
function R:target(range)
    local selector=self.sdk.TargetSelector
    if selector and selector.GetTarget then
        local target=selector:GetTarget(range,self.sdk.DAMAGE_TYPE_PHYSICAL or 1,false)
        return self:enemyValid(target) and U.dist(myHero.pos,target.pos)<=range and target or nil
    end
    local lock=self:locked()
    if lock then return self:enemyValid(lock) and U.dist(myHero.pos,lock.pos)<=range and lock or nil end
    local best,score=nil,math.huge
    for _,e in ipairs(self.enemies or {}) do
        if self:enemyValid(e) and U.dist(myHero.pos,e.pos)<=range then
            local mouseDistance=U.dist(self.aim,e.pos)
            local value=U.effectiveHP(e)/math.max(1,self:aaDamage(e)) + U.dist(myHero.pos,e.pos)/100
            if mouseDistance<300 then value=value-30+mouseDistance/20 end
            if value<score then best,score=e,value end
        end
    end
    return best
end
function R:underTurret(pos)
    for _,t in ipairs(self.turrets or {}) do
        if t.team~=myHero.team and not t.dead and U.dist(pos,t.pos)<(t.boundingRadius or 80)+775+(myHero.boundingRadius or 65) then return true end
    end
    return false
end
function R:threats(pos,range)
    local count=0
    for _,e in ipairs(self.enemies or {}) do if U.dist(e.pos,pos)<range then count=count+1 end end
    return count
end
return R

end
modules["lho.smite"] = function(require)
local U=require('lho.util');local P=require('lho.profiles')
local S={};S.__index=S
function S.new(ctx,actions) return setmetatable({ctx=ctx,actions=actions},S) end
function S:resolve()
    for slot=4,5 do
        local d=self.ctx:spell(slot);local name=(d.name or ''):lower()
        if name=='summonersmite_jade' then return slot,true,d end
        if P.smites[U.name(name)] then return slot,false,d end
    end
end
function S:damage()
    local override=self.ctx.config:get('smiteOverride')
    if override>0 then return override end
    local slot,classic,d=self:resolve();if not slot then return 0 end
    if classic then
        -- Live Classic exposes its current true-damage value on Lee himself.
        local buff=U.buff(myHero,{smitedamagebuff=true},self.ctx:now())
        local value=buff and buff.stacks
        if buff and (buff.count==nil or buff.count>0) and type(value)=='number' and value>=100 and value<=2000 then return value end
        return 460+30*U.clamp((myHero.levelData and myHero.levelData.lvl) or 1,1,18)
    end
    return P.smites[U.name(d.name)] or 0
end
function S:ready(validatingOwnedRequest)
    local slot,classic,d=self:resolve()
    if not slot or not self.ctx:ready(slot) or not validatingOwnedRequest and self.actions.pending[slot] then return false end
    return classic or (type(d.ammo)=='number' and d.ammo>0)
end
function S:inRange(target)
    local _,classic=self:resolve()
    local range=classic and 760 or 500
    -- Center-to-center is deliberately conservative until edge semantics are measured.
    return U.dist(myHero.pos,target.pos)<=range
end
function S:cast(target,owner,requireLethal)
    if not self:ready() or not U.valid(target) or target.team==myHero.team or target.isImmortal or not self:inRange(target) then return false end
    local slot,classic=self:resolve()
    -- Normal minion damage is not interchangeable with monster damage.
    if target.team~=300 and not (classic and Obj_AI_Minion and target.type==Obj_AI_Minion) then return false end
    if not self:campTarget(target) then return false end
    local margin=self:margin(target)
    if requireLethal and (target.health or 0)+(target.allShield or 0)>self:damage()-margin then return false end
    local function validAtKeypress()
        if not self:ready(true) or self:resolve()~=slot then return false,'smite_slot_or_readiness_changed' end
        if not U.valid(target) or not self:campTarget(target) or target.isImmortal then return false,'smite_target_unavailable' end
        if not self:inRange(target) then return false,'smite_out_of_range' end
        if requireLethal and target.health+(target.allShield or 0)>self:damage()-self:margin(target) then return false,'smite_not_lethal' end
        return (owner=='secure' or self.ctx.config:get('autosmite')) and not self.ctx:blocked() and self:ready(true)
            and self:resolve()==slot
            and U.valid(target) and self:campTarget(target) and not target.isImmortal and self:inRange(target)
            and (not requireLethal or target.health+(target.allShield or 0)<=self:damage()-self:margin(target))
    end
    local accepted,event=self.actions:cast(slot,target,owner,{urgent=true,interrupt=true,delay=.02,verifyHover=true,
        smiteExecute=requireLethal==true,validate=validAtKeypress})
    if accepted and self.ctx.config.capture then
        self.outcome={target=target,event=event,at=self.ctx:now(),health=target.health,damage=self:damage()}
    end
    if accepted then if self.ctx.config.capture then self.ctx:log('smite_execute_requested',{target=U.id(target),name=target.charName,
        health=target.health,shield=target.allShield,damage=self:damage(),margin=margin,slot=slot,
        distance=U.dist(myHero.pos,target.pos),owner=owner}) end end
    return accepted
end
function S:margin(target)
    return self.ctx.config:get(P.epics[P.category(target.charName)] and 'smiteEpicMargin' or 'smiteMargin')
end
function S:campTarget(target)
    if not target or target.team~=300 or not P.jungleEntity(target) then return false end
    local name=U.name(target.charName)
    if P.epics[P.category(target.charName)] then return true end
    -- Identity, never relative HP: a surviving/scaled companion must not
    -- become the main monster when the large monster dies or leaves vision.
    local names=self.ctx.profile.id=='classic' and P.classicSmiteTargets or P.normalSmiteTargets
    return names[name]==true
end
function S:auto(epicsOnly)
    local c=self.ctx
    local outcome=self.outcome
    if outcome then
        local event=outcome.event;local now=c:now()
        if event.status=='observed' or event.status=='unconfirmed' or event.gameplayCancelled or now-outcome.at>1 then
            local target=outcome.target
            local action=self.actions.api and self.actions:inputAction(event.cursorID)
            if c.config.capture then c:log('smite_outcome',{target=U.id(target),name=target.charName,
                healthBefore=outcome.health,healthAfter=target.health,dead=target.dead,valid=target.valid,
                damage=outcome.damage,request=event.id,cursorID=event.cursorID,status=event.status,
                sentAt=action and action.sentAt,aimSource=action and action.aim and action.aim.source,
                evidence='Concurrent damage may contribute; target HP is not exclusive Smite attribution'}) end
            self.outcome=nil
        end
    end
    local stamp=epicsOnly and 'epicAt' or 'fullAt'
    if self[stamp]==c:now() then return false end
    self[stamp]=c:now()
    local best,rank=nil,-1
    local enabled=c.config:get('autosmite')
    local cache=c.monsterCache
    local targets=cache and cache.source==c.minions and cache.units or c.minions or {}
    -- Re-enumerate in a nearby objective contest so replacement wrappers and
    -- fresh health do not wait for the general 80 ms object-cache refresh.
    local freshScan=false
    for _,m in ipairs(targets) do
        if m and m.team==300 and P.epics[P.category(m.charName)] and U.dist(myHero.pos,m.pos)<1400
            then freshScan=true;break end
    end
    -- A boss appearing in vision must not first wait for the ordinary cache.
    -- Profile-bound camp anchors are only a reason to enumerate, never proof
    -- that an objective exists, is visible, or is legally smiteable.
    if not freshScan then
        for _,camp in pairs(c.farm and c.farm.known or {}) do
            if P.epics[camp.category] and U.dist(myHero.pos,camp.pos)<1400 then freshScan=true;break end
        end
    end
    if freshScan and Game.MinionCount and Game.Minion then
        targets={}
        for i=1,U.count(Game.MinionCount(),4096) do local fresh=Game.Minion(i);if fresh then targets[#targets+1]=fresh end end
    end
    if #targets==0 and not self.contest then
        self.decision=enabled and 'No eligible monster in range' or 'Toggle OFF';return false
    end
    local ready=self:ready();local damage=self:damage()
    local reserve=not epicsOnly and c.farm and c.farm:epicSoon()
    self.decision=not enabled and 'Toggle OFF' or not ready and 'Cooldown / no charge / pending input' or 'No eligible monster in range'
    local rows=c.config.capture and {};local objectiveCount=0;local warm;local now=c:now();self.objectiveHealth=self.objectiveHealth or {}
    for _,m in ipairs(targets) do
        local cat=P.category(m.charName);local epic=P.epics[cat]
        if epic and m.team==300 and U.dist(myHero.pos,m.pos)<1600 and objectiveCount<8 then
            objectiveCount=objectiveCount+1
            local id=U.id(m);local prior=id and self.objectiveHealth[id]
            local seen=m.visible~=false;local hp=seen and m.health or nil
            local dt=prior and now-prior.at;local dps=hp and prior and dt>0 and dt<.5 and math.max(0,(prior.hp-hp)/dt) or 0
            if id and hp then self.objectiveHealth[id]={hp=hp,at=now} end
            if rows then rows[#rows+1]={id=id,name=m.charName,category=cat,hp=hp,shield=seen and m.allShield or nil,
                maxHP=seen and m.maxHealth or nil,visible=seen,valid=m.valid,dead=m.dead,targetable=m.isTargetable,
                pos=U.copy(m.pos),distance=U.dist(myHero.pos,m.pos),inRange=self:inRange(m),eligible=self:campTarget(m),
                lethal=U.valid(m) and m.health+(m.allShield or 0)<=damage-self:margin(m),damage=damage,margin=self:margin(m),dps=dps} end
            -- A short falling-health window prepares only the hover, not Smite.
            -- No fixed HP forecast is ever accepted as proof of a lethal cast.
            local window=math.min(damage*.5,math.max(75,dps*(c.latency+.06)))
            if c.config:get('smitePreaim') and enabled and ready and dps>0 and U.valid(m) and self:inRange(m)
                and self:campTarget(m) and m.health>damage and m.health+(m.allShield or 0)<=damage+window then warm=m end
        end
        if enabled and ready and U.valid(m) and m.team==300 and P.jungleEntity(m) and self:inRange(m) then
            local lethal=damage-self:margin(m)
            if (epic or not epicsOnly and c.config:get('smiteCamps') and self:campTarget(m)
                and not reserve) and m.health+(m.allShield or 0)<=lethal then
                local score=(cat=='Baron' or cat=='Elder') and 4 or epic and 3 or (cat=='Red' or cat=='Blue') and 2 or 1
                if score>rank then best,rank=m,score end
            elseif not epic and reserve then self.decision='Reserved for active nearby objective'
            elseif m.health+(m.allShield or 0)>lethal then self.decision='Waiting for lethal health' end
        end
    end
    for id,sample in pairs(self.objectiveHealth) do if now-sample.at>2 then self.objectiveHealth[id]=nil end end
    local ok=false
    if best then
        ok=self:cast(best,'autosmite',true)
        self.decision=ok and 'Execute requested' or 'Execute waiting for dispatcher'
    elseif warm and not c:blocked() and not c:recalling() and not c.leveling.pending
        and not c.input:previewHeld() and not (c.combat.insec and c.combat.insec.preview)
        and (not c.actions:cursorBusy() or c.actions:ownsHoverAim(warm,'autosmite')) then
        local aimed,reason=c.actions:prepareHover(warm,'autosmite')
        self.decision=aimed and 'Objective hover confirmed; waiting for lethal health' or reason
    end
    -- Persistent, bounded objective evidence survives the 20-minute playtest
    -- window. Dispatch takes priority over serialization and disk I/O.
    if rows and (#rows>0 or self.contest) then
        local slot,classic,spell=self:resolve();local block=c.actions.lastBlock
        local state=tostring(enabled)..':'..tostring(ready)..':'..tostring(self.decision)
        local edge=false;for _,row in ipairs(rows) do if row.lethal then edge=true end end
        if ok or edge~=self.lethalEdge or now>=(self.contestAt or 0)
            or state~=self.contestState and now-(self.lastSampleAt or -1)>=.05 or #rows==0 then
            if c.config.capture then c:log('objective_sample',{objectives=rows,enabled=enabled,ready=ready,slot=slot,classic=classic,
                cooldown=spell and spell.currentCd,ammo=spell and spell.ammo,damage=damage,mode=c.mode,
                decision=self.decision,attempted=ok,origin=U.copy(myHero.pos),cursorStep=c.sdk.Cursor.Step,
                block=block and now-block.at<.2 and block or nil,chat=Game.IsChatOpen and Game.IsChatOpen(),
                focused=Game.IsOnTop and Game.IsOnTop(),leeDead=myHero.dead}) end
            self.contestAt=now+(edge and .05 or .1);self.contestState=state;self.lethalEdge=edge;self.lastSampleAt=now
        end
    end
    self.contest=objectiveCount>0
    return ok
end
function S:clear(target,owner)
    if not self.ctx.config:get('autosmite') or not self:ready() or not U.valid(target) then return false end
    if self:auto(true) then return true end
    if P.epics[P.category(target.charName)] then return self:cast(target,'autosmite',true) end
    if not self.ctx.config:get('smiteCamps') then return false end
    -- Attack priority may be a small monster while the buff is already lethal.
    for _,camp in pairs(self.ctx.farm and self.ctx.farm.known or {}) do
        local found=false
        for _,m in ipairs(camp.members or {}) do if U.same(m,target) then found=true;break end end
        if found then
            for _,m in ipairs(camp.members or {}) do
                if U.valid(m) and self:campTarget(m) and (not self:campTarget(target)
                    or (m.maxHealth or 0)>(target.maxHealth or 0)) then target=m end
            end
            break
        end
    end
    if not self:campTarget(target) then return false end
    if self.ctx.farm and self.ctx.farm:epicSoon() then return false end
    return self:cast(target,'autosmite',true)
end
function S:followAim()
    local c=self.ctx;local aim=self.actions.hoverAim
    if not aim or aim.owner~='autosmite' or not c.config:get('autosmite') or c:blocked() then return false end
    if not self.actions:ownsHoverAim(aim.target,'autosmite') then return false end
    if not P.epics[P.category(aim.target.charName)] and (not c.config:get('smiteCamps') or c.farm:epicSoon()) then return false end
    return self:cast(aim.target,'autosmite',true)
end
return S

end
modules["lho.spells"] = function(require)
local U=require('lho.util');local P=require('lho.profiles')
local S={};S.__index=S
local collisionOptions={padding=0,trim=0}
local function finite(value) return type(value)=='number' and value==value and math.abs(value)<math.huge end
local function pathEnd(target)
    return target and (target.posTo or target.pathing and target.pathing.endPos or target.pos)
end
function S.new(ctx,actions,smite) pcall(require,'GGPrediction');return setmetatable({ctx=ctx,actions=actions,smite=smite},S) end
function S:q1Status(target,owner,reason)
    local c=self.ctx;if not c.config.capture then return end
    self.q1Decision={at=c:now(),target=U.id(target),owner=owner,reason=reason}
    c:trace('q1_decision',self.q1Decision,tostring(U.id(target))..':'..tostring(owner)..':'..reason,.5)
end
function S:q1Useful(target,pos)
    if not target then return true end -- Fog probes have separate camp evidence.
    local c=self.ctx;local delay=.25+U.dist(myHero.pos,pos or target.pos)/c.profile.qSpeed
    local reason,predicted
    if c:attackFinishesBefore(target,delay) then reason='own_attack_finishes_first'
    elseif target.team==300 or target.type and myHero.type and target.type~=myHero.type then
        predicted=c:healthAt(target,delay)
        if predicted<=0 then reason='target_dies_before_q1' end
    end
    if not reason then return true end
    if c.config.capture then
        local active=myHero.activeSpell
        c:trace('q1_conserved',{target=U.id(target),reason=reason,health=target.health,predictedHP=predicted,
            impactDelay=delay,ownAttackTarget=active and active.target,ownAttackEnd=active and active.castEndTime},
            tostring(U.id(target))..':'..reason,.25)
    end
    return false,reason
end
-- Shared, input-free rules for planning and the final send boundary.
function S:allowed(slot,target,owner,plan)
    local c=self.ctx;local stage=plan.stage
    if not c:abilityEnabled(slot,stage,owner,target,plan.abilityPolicy) then return false,'disabled_for_mode' end
    if plan.abilityPolicy then
        local prefix=plan.abilityPolicy
        local ability=({[0]=stage==2 and 'Q2' or 'Q',[1]='W',[2]='E'})[slot]
        if not c.config:get(prefix..'Abilities') or ability and not c.config:get(prefix..ability) then return false,'disabled_for_mode' end
    end
    if plan.waveHarass and (not c.config:get('waveHarass') or not c.config:get('harassQ')) then return false,'wave_harass_disabled' end
    if owner=='killsteal' then
        local option=slot==0 and (stage==2 and 'killQ2' or 'killQ') or slot==2 and 'killE' or slot==3 and 'killR'
        if option and not c.config:get(option) then return false,'killsteal_disabled' end
        local lock=c:locked()
        if lock and not U.same(target,lock) then return false,'selected_target_changed' end
    elseif owner=='expiry' then
        if not c.config:get(slot==1 and 'expiryW' or 'expiryE')
            or c.wards.pending or c.combat.insec or c.input:held('wardKey')
            or (myHero.mana or 0)-(c:spell(slot).mana or 0)<c.config:get('recastReserve') then return false,'expiry_assist_unavailable' end
    end
    if (owner=='fight' or owner=='harass' or owner=='expiry' or owner=='killsteal') and c:combatTransit() then return false,'engage_in_flight' end
    if c:blocked() or not c:ready(slot) then return false,'spell_unavailable' end
    if slot<3 and c:stage(slot,target)~=stage then return false,'spell_stage_changed' end
    if target and not U.valid(target) then return false,'target_unavailable' end
    if slot==0 then
        if c:dash() then return false,'dash_active' end
        if owner=='farm' and target and P.epics[P.category(target.charName)] then return false,'boss_excluded' end
        if stage==2 then
            if not target or not c:mark(target) then return false,'q2_mark_missing' end
            if U.dist(myHero.pos,target.pos)>c.profile.q2Range then return false,'q2_out_of_range' end
            local travel=plan.travel and owner=='farm' and c.config:get('farmQTravel')
                and ((plan.travelTarget and c.farm.travelTarget==plan.travelTarget)
                    or (plan.probe and c.farm.probe==plan.probe))
            if not travel and (owner=='farm' or owner=='clear') and c.config:get('jungleQ2MeleeOnly')
                and U.dist(myHero.pos,target.pos)>c:jungleQ2Range(target) then return false,'q2_clear_range' end
            if not plan.deliberate and c.config:get('q2Safety') and c:underTurret(target.pos) then return false,'q2_turret_safety' end
        else
            local pos=plan.shot
            if not pos or U.dist(myHero.pos,pos)>c.profile.qRange then return false,'q1_shot_out_of_range' end
            local useful,reason=self:q1Useful(target,pos);if not useful then return false,reason end
            local collisionEnd=pos
            if target then
                -- Preserve an already accepted confidence decision briefly on
                -- the SAME path. GG's high-confidence 150ms new-path window can
                -- end while this request waits for the cursor. Recompute the
                -- intercept at normal confidence, and still validate this exact
                -- shot and its collision; a changed path gets the full policy.
                local predicted=self:planPrediction(target,plan)
                if not predicted then return false,'q1_prediction_unavailable' end
                -- A line spell continues beyond its original aiming point.
                -- Validate the ray, then collision only as far as the refreshed
                -- target intercept. A blocker behind the target is irrelevant.
                local origin=myHero.pos;local length=U.dist(origin,pos)
                if length<1 then return false,'q1_shot_no_longer_suitable' end
                local dx,dz=(pos.x-origin.x)/length,(pos.z-origin.z)/length
                local along=(predicted.x-origin.x)*dx+(predicted.z-origin.z)*dz
                local across=math.abs((predicted.x-origin.x)*dz-(predicted.z-origin.z)*dx)
                if along<=0 or along>c.profile.qRange or across>c.profile.qRadius+(target.boundingRadius or 35)*.5 then
                    if c.config.capture then c:trace('q1_ray_rejected',{target=U.id(target),along=along,across=across,
                        allowedAcross=c.profile.qRadius+(target.boundingRadius or 35)*.5,
                        origin=U.copy(origin),shot=U.copy(pos),prediction=U.copy(predicted)},tostring(U.id(target)),.4) end
                    return false,'q1_shot_no_longer_suitable'
                end
                collisionEnd={x=origin.x+dx*along,y=pos.y,z=origin.z+dz*along}
            end
            if self:projectileWall(collisionEnd,nil,U.id(target)) then return false,'q1_projectile_blocked' end
            local blockers=self:blockers(target,collisionEnd)
            if #blockers>0 then self:traceCollision(target,collisionEnd,blockers,'dispatch');return false,'q1_collision' end
        end
    elseif slot==2 then
        if not target then return plan.independent==true,'e_target_required' end
        if U.dist(myHero.pos,target.pos)>(stage==2 and c.profile.e2Range or c.profile.eRange) then return false,'e_out_of_range' end
        if stage==1 and target.team==300 and (owner=='farm' or owner=='clear')
            and not self:eHits(target) then return false,'e_impact_out_of_range' end
        if stage==2 and not U.buff(target,P.eMarks,c:now()) then return false,'e2_mark_missing' end
    elseif slot==1 then
        if c:dash() then return false,'dash_active' end
        if stage==1 and (not target or target.team~=myHero.team or U.dist(myHero.pos,target.pos)>c.profile.wRange) then return false,'w_target_or_range' end
    elseif slot==3 then
        if not c:enemyValid(target) or U.dist(myHero.pos,target.pos)>c.profile.rRange or c:dash()
            or c.combat:kickProtected(target) then return false,'r_target_or_protection' end
    elseif U.name(c:spell(slot).name)=='summonerflash' then
        if not plan.shot or U.dist(myHero.pos,plan.shot)>400 or c.terrain:wall(plan.shot)==true then return false,'flash_position_invalid' end
        if owner=='insec' and not c.combat.planner:flashAllowed(c.combat.insec) then return false,'flash_not_authorized' end
    end
    if owner=='killsteal' and target and c:combatDamage(slot,target,stage)
        <U.typedHP(target,slot==2 and 'magic' or 'physical')+c.config:get('combatDamageMargin')+(target.hpRegen or 0)*.8 then
        return false,'kill_no_longer_lethal'
    end
    return true
end
function S:submit(slot,castTarget,target,owner,opts,plan)
    opts=opts or {};plan=plan or {};plan.stage=plan.stage or (slot<3 and self.ctx:stage(slot,target))
    if slot<3 and not plan.abilityPolicy then
        if owner=='farm' and not plan.travel then plan.abilityPolicy='autoClear'
        elseif owner=='clear' then
            plan.abilityPolicy=self.ctx.mode=='gg_last' and 'last' or target and target.team==300 and 'jungle'
                or target and not U.same(target,myHero) and 'wave' or nil
        end
    end
    if owner=='clear' and slot==0 and target then
        for _,enemy in ipairs(self.ctx.enemies or {}) do
            if U.same(enemy,target) then plan.waveHarass=true;break end
        end
    end
    local extra=opts.validate
    opts.abilityPolicy=plan.abilityPolicy
    opts.validate=function()
        local ok,why=self:allowed(slot,target,owner,plan);if not ok then return false,why end
        if extra then return extra() end;return true
    end
    local ok,why=opts.validate();if not ok then return false,why end
    if slot==0 and plan.stage==1 and target and self.actions.capabilities
        and (self.actions.capabilities.resolveWorldTarget or self.actions.capabilities.resolveBeforeHandoff) then
        plan.resolvePrediction=true
        local function resolve(context)
            if not U.valid(target) or not self.ctx:ready(0) or self.ctx:stage(0)~=1 or self.ctx:dash() then return nil,'spell_unavailable' end
            -- One fresh prediction per resolver pass. Repeated mechanical
            -- checks in that same pass may reuse it while geometry is identical.
            plan.predictionSample=nil
            local point=self:planPrediction(target,plan)
            if not point then return nil,'q1_prediction_unavailable' end
            local valid,reason
            -- Once positioned, keep the existing ray only if fresh prediction,
            -- collision and every gameplay condition still approve that ray.
            -- Following each tiny intercept change can otherwise starve send.
            if context and (context.revision or 0)>0 and context.position then
                plan.shot=U.copy(context.position)
                valid,reason=opts.validate()
                if valid then point=plan.shot end
            end
            if not valid then plan.shot=U.copy(point);valid,reason=opts.validate() end
            if not valid then return nil,reason end
            return {position=U.copy(point),data={targetID=U.id(target),origin=U.copy(myHero.pos),
                flightDuration=.25+U.dist(myHero.pos,point)/self.ctx.profile.qSpeed+self.ctx.latency+2*self.ctx.jitter+.10}}
        end
        opts.resolveWorldTarget=function(context)return U.withBuffScope(resolve,context)end
    end
    return self.actions:cast(slot,castTarget,owner,opts)
end
function S:planPrediction(target,plan)
    local c=self.ctx;local accepted=plan.prediction
    local sample=plan.predictionSample;local now=c:now();local path=pathEnd(target)
    local policy=c.config:get('hitchance')
    if plan.resolvePrediction and sample and sample.at==now and sample.policy==policy
        and target.visible==sample.visible and U.dist(myHero.pos,sample.origin)<.001
        and U.dist(target.pos,sample.target)<.001 and U.dist(path,sample.path)<.001 then
        return U.copy(sample.point)
    end
    local continuous=accepted and accepted.policy==c.config:get('hitchance') and accepted.policy<=2
        and c:now()-accepted.at<=.25 and target.visible~=false
        and U.dist(pathEnd(target),accepted.path)<1
    local point=self:predict(target,continuous and (_G.GGPrediction and GGPrediction.HITCHANCE_NORMAL or 2) or nil)
    if point and plan.resolvePrediction then
        plan.predictionSample={at=now,policy=policy,visible=target.visible,origin=U.copy(myHero.pos),target=U.copy(target.pos),path=U.copy(path),point=U.copy(point)}
    end
    return point
end
local function pointKey(p) return p and (tostring(p.x)..','..tostring(p.y)..','..tostring(p.z)) or '-' end
function S:memo(kind,key,fn)
    local cycle=U.buffScopeKey()
    if not cycle then return fn() end
    if self.memoCycle~=cycle or self.memoTime~=self.ctx:now() then self.memoCycle=cycle;self.memoTime=self.ctx:now();self.memoData={} end
    local full=kind..':'..key;local cached=self.memoData[full]
    if cached then return cached.value end
    local value=fn();self.memoData[full]={value=value};return value
end
function S:predictionFailure(kind,err)
    self.failures=self.failures or {}
    local reason=tostring(err)
    if self.failures[kind]~=reason then
        self.failures[kind]=reason;if self.ctx.config.capture then self.ctx:log('prediction_unavailable',{name=kind,reason=reason}) end
    end
end
function S:collisionRaw(origin,pos,types,targetID)
    local gg=_G.GGPrediction;local p=self.ctx.profile
    local options=gg.CollisionOptions and collisionOptions or nil
    local ok,wall,objects,count=pcall(gg.GetCollision,gg,U.copy(origin),U.copy(pos),p.qSpeed,.25,p.qRadius,types,targetID,options)
    if not ok or objects~=nil and type(objects)~='table' then
        self:predictionFailure('collision',not ok and wall or 'Invalid collision object list')
        return true,{},0 -- Unknown obstruction must not turn into a clear shot.
    end
    for _,unit in ipairs(objects or {}) do
        if (type(unit)~='table' and type(unit)~='userdata') or not unit.pos then
            self:predictionFailure('collision','Invalid collision object');return true,{},0
        end
    end
    return wall,objects,count
end
function S:collision(origin,pos,types,targetID)
    local key=pointKey(origin)..':'..pointKey(pos)..':'..table.concat(types,',')..':'..tostring(targetID)
    local row=self:memo('collision',key,function()
        local wall,objects,count=self:collisionRaw(origin,pos,types,targetID)
        return {wall=wall,objects=objects,count=count}
    end)
    local objects={};for i,v in ipairs(row.objects or {})do objects[i]=v end
    return row.wall,objects,row.count
end
function S:projectileWall(pos,origin,targetID)
    local gg=_G.GGPrediction;origin=origin or myHero.pos
    if not gg or not gg.GetCollision then return false end
    return self:collision(origin,pos,{gg.COLLISION_YASUOWALL or 3},targetID)==true
end
function S:predictRaw(target,required)
    local c=self.ctx;local p=c.profile;local gg=_G.GGPrediction
    if not U.valid(target) or U.dist(myHero.pos,target.pos)>p.qRange then return nil end
    if not gg then
        -- No unqualified raw-position shots at moving champions.
        if target.team==300 or not (target.pathing and target.pathing.hasMovePath) then return U.copy(target.pos) end
        return nil
    end
    local minion=target.team==300 or target.type~=myHero.type
    for _,m in ipairs(c.minions or {}) do if U.same(m,target) then minion=true;break end end
    local ok,pos=pcall(function()
        -- Prediction output is consumed synchronously and copied below. Reuse
        -- one model per range policy instead of rebuilding its methods each cast.
        local signature=tostring(p.qRange)..':'..tostring(p.qSpeed)..':'..tostring(p.qRadius)
        if self.predictionProvider~=gg or self.predictionFactory~=gg.SpellPrediction or self.predictionSignature~=signature then
            self.predictionModels={};self.predictionProvider=gg;self.predictionFactory=gg.SpellPrediction;self.predictionSignature=signature
        end
        local key=minion and 'minion' or 'hero';local prediction=self.predictionModels[key]
        if not prediction then
            prediction=gg:SpellPrediction({Type=gg.SPELLTYPE_LINE,Delay=.25,Radius=p.qRadius,
                Range=minion and math.huge or p.qRange,Speed=p.qSpeed,Collision=false})
            self.predictionModels[key]=prediction
        end
        prediction:GetPrediction(target,myHero)
        local hitchance=required or ({gg.HITCHANCE_NORMAL or 2,gg.HITCHANCE_HIGH or 3,gg.HITCHANCE_IMMOBILE or 4})[c.config:get('hitchance')]
        if minion then hitchance=gg.HITCHANCE_NORMAL or 2 end
        if not prediction.CastPosition or not prediction:CanHit(hitchance) then
            if c.config.capture then c:trace('q1_prediction_rejected',{target=U.id(target),name=target.charName,
                reason=prediction.LastFailureReason or (not prediction.CastPosition and 'prediction_unavailable' or 'provider_rejected'),
                required=hitchance,actual=prediction.HitChance,distance=U.dist(myHero.pos,target.pos),
                pos=U.copy(prediction.CastPosition),impact=prediction.TimeToHit},tostring(U.id(target)),.4) end
            return nil
        end
        local pos=U.copy(prediction.CastPosition)
        if minion then pos.y=target.pos.y or 0 end -- Bypass GG's champion range-margin conversion.
        if not finite(pos.x) or not finite(pos.y) or not finite(pos.z) then error('Invalid predicted position') end
        return pos
    end)
    if not ok then self:predictionFailure('position',pos);return nil end
    if not pos then return nil end
    if U.dist(myHero.pos,pos)>p.qRange then return nil end
    if self:projectileWall(pos,nil,U.id(target)) then return nil end
    return pos
end
function S:blockersRaw(target,pos,origin)
    local result={};local c=self.ctx
    origin=origin or myHero.pos
    local known={};local gg=_G.GGPrediction
    if gg and gg.GetCollision then
        local collision,objects=self:collision(origin,pos,{gg.COLLISION_MINION or 0,gg.COLLISION_ENEMYHERO or 2},U.id(target))
        if collision and (not objects or #objects==0) then result[#result+1]={unknownCollision=true} end
        for _,u in ipairs(objects or {}) do
            result[#result+1]=u;if U.id(u) then known[U.id(u)]=true end
        end
    end
    for _,list in ipairs({c.minions or {},c.enemies or {}}) do
        for _,u in ipairs(list) do
            if U.valid(u) and u.team~=myHero.team and not U.same(u,target) and not known[U.id(u)] then
                local d,t=U.segment(u.pos,origin,pos)
                local hit=t>0 and t<1 and d<c.profile.qRadius+(u.boundingRadius or 45)
                if not hit and u.GetPrediction and u.pathing and u.pathing.hasMovePath then
                    local ok,predicted=pcall(function()return U.copy(u:GetPrediction(c.profile.qSpeed,.25))end)
                    if not ok or not predicted or not finite(predicted.x) or not finite(predicted.z) then
                        self:predictionFailure('blocker',not ok and predicted or 'Blocker prediction unavailable')
                        result[#result+1]={unknownCollision=true}
                    else d,t=U.segment(predicted,origin,pos);hit=t>0 and t<1 and d<c.profile.qRadius+(u.boundingRadius or 45) end
                end
                if hit then result[#result+1]=u end
            end
        end
    end
    return result
end
function S:predict(target,required)
    local key=tostring(U.id(target))..':'..pointKey(target and target.pos)..':'..pointKey(myHero.pos)..':'..pointKey(pathEnd(target))
        ..':'..tostring(required or self.ctx.config:get('hitchance'))..':'..tostring(target and target.visible)
        ..':'..tostring(required~=nil)
    local value=self:memo('predict',key,function()return self:predictRaw(target,required)end)
    return value and U.copy(value)
end
function S:blockers(target,pos,origin)
    local key=tostring(U.id(target))..':'..pointKey(origin or myHero.pos)..':'..pointKey(pos)
    local value=self:memo('blockers',key,function()return self:blockersRaw(target,pos,origin)end)
    local out={};for i,v in ipairs(value)do out[i]=v end;return out
end
function S:traceCollision(target,pos,blockers,phase)
    local c=self.ctx;if not c.config.capture then return end
    local u=blockers[1];local distance=u and u.pos and U.segment(u.pos,myHero.pos,pos)
    c:trace('q1_collision_rejected',{target=U.id(target),phase=phase,blocker=U.id(u),
        blockerName=u and u.charName,blockerPos=u and U.copy(u.pos),blockerRadius=u and u.boundingRadius,
        rayDistance=distance,qRadius=c.profile.qRadius,origin=U.copy(myHero.pos),shot=U.copy(pos),count=#blockers,
        preciseProvider=_G.GGPrediction and GGPrediction.CollisionOptions==true},tostring(U.id(target))..':'..phase,.4)
end
function S:q1(target,owner,smiteBlocker,validate)
    local c=self.ctx
    if not c:abilityEnabled(0,1,owner,target) then self:q1Status(target,owner,'disabled_for_mode');return false end
    if owner=='farm' and P.epics[P.category(target and target.charName)] then return false end
    if not c:ready(0) or c:stage(0)~=1 or c:dash() then self:q1Status(target,owner,'unavailable_stage_or_dash');return false end
    if not self:q1Useful(target) then return false end
    local pos=self:predict(target);if not pos then self:q1Status(target,owner,'prediction_rejected');return false end
    local blockers=self:blockers(target,pos)
    if #blockers>0 then
        self:q1Status(target,owner,'collision')
        self:traceCollision(target,pos,blockers,'planning')
        if smiteBlocker and #blockers==1 and c.config:get('autosmite') and blockers[1].team==300 and self.smite:clear(blockers[1],owner) then
            self.afterSmite={target=target,owner=owner,untilTime=c:now()+.7};return true
        end
        return false
    end
    local ok,event=self:submit(0,pos,target,owner,{intendedTarget=target,validate=validate},
        {stage=1,shot=U.copy(pos),prediction={at=c:now(),path=U.copy(pathEnd(target)),policy=c.config:get('hitchance')}})
    self:q1Status(target,owner,ok and 'requested_not_yet_proven_sent' or type(event)=='string' and event or 'dispatch_declined')
    if ok then
        local duration=.25+U.dist(myHero.pos,pos)/c.profile.qSpeed+c.latency+2*c.jitter+.10
        self.q1Flight={target=U.id(target),event=event,duration=duration,
            untilTime=(event.dispatchAt or c:now())+duration}
    end
    return ok,event
end
function S:q1Reservation(target)
    local flight=self.q1Flight;local c=self.ctx
    if not flight or flight.target~=U.id(target) then return nil end
    local event=flight.event;local sent=event.keyAt
    if self.actions.api then
        local action=self.actions:inputAction(event.cursorID)
        if not action or action.state=='cancelled_before_send' then return nil end
        if action.sentAt then
            sent=sent or c:now()-math.max(0,self.actions:inputNow()-action.sentAt)*.001
            local data=action.resolution and action.resolution.data
            if data and U.finite(data.flightDuration) then flight.duration=data.flightDuration end
        elseif not action.jobCancelled and not event.gameplayCancelled and not event.cancelled
            and event.status~='cancelled' and (action.state=='waiting' or action.state=='requested')
            and self.actions:inputNow()<(action.expires or 0) then
            return flight,'queued',math.max(0,(action.expires-self.actions:inputNow())*.001)
        else return nil end
    else
        if event.cancelled or event.status=='cancelled' then return nil end
        sent=sent or event.dispatchAt
    end
    -- Cancellation cannot unsend a projectile. A queued intent, however, has
    -- no flight time until its actual send timestamp is known.
    if not sent then return nil end
    local deadline=sent+flight.duration
    if c:now()<deadline then return flight,'in_flight',deadline-c:now() end
end
function S:q2(target,owner,deliberate,entry,travelEntry,validate)
    local c=self.ctx;local reason
    local plan={stage=2,deliberate=deliberate,travel=travelEntry,travelTarget=c.farm.travelTarget,probe=c.farm.probe}
    local allowed;allowed,reason=self:allowed(0,target,owner,plan)
    if not allowed then
        -- The same rule is checked again by submit immediately before sending.
    else
        local ok,event=self:submit(0,nil,target,owner,{delay=.15,urgent=entry,interrupt=entry,stage=2,intendedTarget=target,validate=validate},plan)
        if ok then
            self.q2LastRequest=c:now();self.q2Decision='Q2 key sent'
            if owner=='farm' or owner=='clear' then c.qDebug={at=c:now(),text='Q2: key sent | '..tostring(c:spell(0).name)} end
            return ok,event
        end
        reason=not c:ready(0) and 'Native castability / energy'
            or c.sdk.Orbwalker:IsAutoAttacking() and 'Attack windup' or 'Dispatcher reservation'
    end
    self.q2Decision=reason
    if owner=='farm' or owner=='clear' then c.qDebug={at=c:now(),text='Q2: '..reason..' | '..tostring(c:spell(0).name)} end
    if c:now()>=(self.q2LogAt or 0) then
        self.q2LogAt=c:now()+1;local d=c:spell(0)
        if c.config.capture then c:log('q2_blocked',{reason=reason,owner=owner,name=d.name,toggleState=d.toggleState,cd=d.currentCd,
            useState=Game.CanUseSpell(0),energy=myHero.mana,cost=d.mana,markLeft=target and c:markLeft(target),
            target=U.id(target),stage=c:stage(0),pending=self.actions.pending[0]~=nil}) end
    end
    return false
end
function S:q1Camp(pos,validate)
    return self:submit(0,U.copy(pos),nil,'farm',{delay=.25,validate=validate},{stage=1,shot=U.copy(pos)})
end
function S:eHits(target,origin)
    local c=self.ctx;origin=origin or myHero.pos
    if not U.valid(target) then return false end
    local point=target.pos;local path=target.pathing
    if path and path.hasMovePath and path.endPos then
        point=U.toward(point,path.endPos,math.min(U.dist(point,path.endPos),(target.ms or 0)*(.25+c.latency)))
    end
    -- Tempest stops Lee to cast: never credit future approach movement as its
    -- origin. Keep a small measured-latency allowance on a moving local origin.
    local moving=myHero.pathing and myHero.pathing.hasMovePath
    local margin=moving and (myHero.ms or 0)*(c.latency+c.jitter+.016) or 0
    return U.dist(origin,point)<=c.profile.eRange-margin
end
function S:e(target,owner,validate)
    return self:submit(2,nil,target,owner,{intendedTarget=target,validate=validate},{stage=self.ctx:stage(2),independent=false})
end
function S:w(target,owner,interrupt,abilityPolicy,validate)
    local stage=self.ctx:stage(1)
    if stage~=1 and stage~=2 then return false end
    target=stage==1 and (target or myHero) or nil
    return self:submit(1,target,target,owner,{interrupt=stage==1 and interrupt or nil,validate=validate,
        verifyHover=stage==1 and target and not U.same(target,myHero) or nil},{stage=stage,abilityPolicy=abilityPolicy})
end
function S:r(target,owner,interrupt,validate)
    return self:submit(3,target,target,owner,{interrupt=interrupt,urgent=owner=='insec',validate=validate})
end

function S:flash(pos,owner)
    for slot=4,5 do
        if U.name(self.ctx:spell(slot).name)=='summonerflash' then
            return self:submit(slot,pos,nil,owner,{interrupt=true,delay=.05},{shot=U.copy(pos)})
        end
    end
    return false
end
return S

end
modules["lho.tactics"] = function(require)
local U=require('lho.util');local P=require('lho.profiles');local F=require('lho.forecast')
local T={};T.__index=T
function T.new(combat) return setmetatable({b=combat,ctx=combat.ctx},T) end
function T:wardArrival()
    local c=self.ctx
    local handoff=c.metrics.wardPlacementToW or math.max(.08,c.latency*.5)
    local dash=c.metrics.wardDashDuration or c.config:get('insecDashEstimate')/1000
    return U.clamp(handoff+dash,.1,.65)
end

-- A policy horizon is not a claim that enemy spell damage is fully known.
-- Low health, nearby additional enemies and turret exposure shorten the time
-- for which a cheaper alternative may postpone an otherwise lethal R.
function T:window(target)
    local c=self.ctx;local extra=0
    for _,enemy in ipairs(c.enemies or {}) do
        if not U.same(enemy,target) and c:enemyValid(enemy) and U.dist(enemy.pos,myHero.pos)<900 then extra=extra+1 end
    end
    local health=U.clamp((myHero.health or 0)/math.max(1,myHero.maxHealth or 1),0,1)
    local horizon=U.clamp(.25+health*1.25-extra*.25,.25,1.5)
    if c:underTurret(myHero.pos) then horizon=math.min(horizon,.35) end
    return horizon,extra
end

function T:model(target,owner,horizon,options)
    local c=self.ctx;options=options or {};owner=owner or 'fight'
    local mode=owner=='killsteal' and (c.mode=='harass' and 'harass' or 'fight') or owner
    local prefix=mode=='harass' and 'harass' or 'combo'
    local distance=U.dist(myHero.pos,target.pos);local range=c:attackRange(target)
    local attack=c.sdk.Attack or {};local cycle=attack.GetAnimation and attack:GetAnimation() or 1/math.max(.5,myHero.attackSpeed or 1)
    cycle=math.max(.15,cycle);local windup=math.max(.02,c:windup())
    local pending,impact=c:pendingAttackDamage(target,horizon)
    local readyAA=attack.IsReady and attack:IsReady()
    local nextAA=readyAA and 0 or U.finite(attack.ServerStart) and math.max(0,attack.ServerStart+cycle-c:now()) or math.huge
    if pending>0 then nextAA=math.max(nextAA,cycle-(c:now()-(myHero.activeSpell.startTime or c:now()))) end
    local at,immobile,speed=self.b:chaseMotion(target)
    local future=at(horizon);local toward=U.dist(myHero.pos,future)-distance
    local retreat=horizon>0 and toward/horizon or 0
    local ownSpeed=math.max(1,myHero.ms or 350)
    local gap=math.max(0,distance-range)
    local background=owner=='killsteal' and c.mode~='fight' and c.mode~='harass'
    local autosEnabled=not options.noAutos and not background and attack.IsReady and c.sdk.Orbwalker.AttackEnabled~=false
    local plain=(autosEnabled or pending>0) and c.sdk.Damage:GetAutoAttackDamage(myHero,target,false) or 0
    -- SDK returns an aggregate for proc-inclusive attacks. Without a component
    -- split, do not pretend magic on-hit damage bypasses a target's magic shield.
    local typedShield=(target.shieldAP or 0)>0
    if typedShield then pending=math.min(pending,plain) end
    -- Do not promise attacks through a wall or into a turret. No path search
    -- inside the combinatorial search; terrain is checked once per assessment.
    local walkTo=U.toward(myHero.pos,future,math.max(0,U.dist(myHero.pos,future)-range+10))
    local corridor=distance<=range and retreat<=0 or autosEnabled and gap<=ownSpeed*horizon
        and c.terrain:walkLine(myHero.pos,walkTo,myHero.boundingRadius or 35)==true
    local movement=c.moveTarget or c.aim or myHero.pathing and myHero.pathing.endPos
    local movingToward=false
    if movement and U.position(movement) then
        local mx,mz=movement.x-myHero.pos.x,movement.z-myHero.pos.z
        local tx,tz=future.x-myHero.pos.x,future.z-myHero.pos.z
        local length=math.sqrt((mx*mx+mz*mz)*(tx*tx+tz*tz))
        movingToward=length>1 and (mx*tx+mz*tz)/length>.5
    end
    local chaseSafe=autosEnabled and corridor and movingToward and not c:underTurret(future)
    local approach=gap==0 and 0 or chaseSafe and ownSpeed>retreat and gap/(ownSpeed-retreat) or math.huge
    local actions={};local lookup={}
    local samples,availability={},{}
    local function spell(slot)
        if not samples[slot] then samples[slot]=c:spell(slot) end
        return samples[slot]
    end
    local m={hp=(target.health or 0)+(c.config:get('combatDamageMargin') or 0),maxHP=(target.maxHealth or target.health)+(c.config:get('combatDamageMargin') or 0),
        regen=math.max(0,target.hpRegen or 0),shield=target.allShield or 0,physical=target.shieldAD or 0,magic=target.shieldAP or 0,
        energy=math.max(0,(myHero.mana or 0)-(options.reserveEnergy or 0)),distance=distance,horizon=horizon,actions=actions,aaAt=nextAA,resourceWeight=2,
        mark=c:mark(target) and c:markLeft(target) or 0}
    if pending>0 then m.pending={damage=pending,at=impact or 0} end
    local function add(a) actions[#actions+1]=a;lookup[a.id]=a end
    local function permitted(slot,stage)
        local key=({[0]='Q',[1]='W',[2]='E',[3]='R'})[slot]..(stage==2 and '2' or '')
        if owner=='killsteal' and c.mode~='fight' and c.mode~='harass' then
            local option=slot==0 and (stage==2 and 'killQ2' or 'killQ') or slot==2 and stage==1 and 'killE'
            if not option or not c.config:get(option) then return false end
        end
        if not c.config:get(prefix..key) or not c:abilityEnabled(slot,stage,mode,target) or c.actions.pending[slot] then return false end
        if availability[slot]==nil then availability[slot]=c:ready(slot) end
        return availability[slot]
    end
    local function inRange(s,r) return s.distance+math.max(0,retreat)*s.t<=r end
    if autosEnabled then
        local firstDamage=c:aaDamage(target)
        if typedShield then firstDamage=math.min(firstDamage,plain) end
        add({id='AA',kind='physical',repeatable=true,cost=0,delay=function(s)
            local start=math.max(s.t,s.aaAt,approach)
            if s.autos>0 and retreat>0 then
                if not chaseSafe or ownSpeed<=retreat then return nil end
                start=math.max(start,s.t+retreat*windup/(ownSpeed-retreat))
            end
            if not chaseSafe and (distance>range or retreat>0 and distance+retreat*(start+windup)>range) then return nil end
            return start+windup-s.t
        end,damage=function(s)return s.autos==0 and pending==0 and firstDamage or plain end,
        apply=function(s,old,dt)s.autos=s.autos+1;s.aaAt=s.t-windup+cycle;s.distance=math.min(s.distance,range);s.firstAt=old.firstAt or old.t+dt-windup end})
    end
    local qStage=c:stage(0,target,spell(0));local q1=false
    if qStage==1 and permitted(0,1) and distance<=c.profile.qRange then
        local aim=c.spells:predict(target)
        local blockers=aim and c.spells:blockers(target,aim)
        local reason=not aim and 'prediction_rejected' or #blockers>0 and 'collision'
            or c.spells:projectileWall(aim) and 'projectile_wall'
            or not c.spells:q1Useful(target,aim) and 'target_dies_before_q' or 'available_to_planner'
        q1=reason=='available_to_planner'
        if blockers and #blockers>0 then c.spells:traceCollision(target,aim,blockers,'planner') end
        c.spells:q1Status(target,owner,reason)
        if q1 then
            local dmg=c:combatDamage(0,target,1);local delay=.25+U.dist(myHero.pos,aim)/c.profile.qSpeed
            add({id='Q1',slot=0,stage=1,kind='physical',energy=spell(0).mana or 0,cost=1,
                delay=function(s)if inRange(s,c.profile.qRange) then return delay end end,
                damage=function()return dmg end,apply=function(s)s.mark=s.t+3 end})
        end
    end
    if not options.excludeQ2 and (qStage==2 and m.mark>0 or q1) and permitted(0,2) and not (c.config:get('q2Safety') and c:underTurret(target.pos)) then
        local full=c:combatDamage(0,target,2,target.maxHealth);local low=c:combatDamage(0,target,2,0)
        add({id='Q2',slot=0,stage=2,kind='physical',energy=qStage==2 and (spell(0).mana or 0) or 30,cost=1.5,
            delay=function(s)
                local dt=.15+(s.distance+math.max(0,retreat)*s.t)/1800
                if s.mark>s.t+dt and inRange(s,c.profile.q2Range) then return dt end
            end,damage=function(s)return full+(low-full)*U.clamp(1-s.hp/math.max(1,target.maxHealth),0,1) end,
            apply=function(s)s.mark=0;s.distance=0;if qStage~=2 then s.conditional=true end end})
    end
    local eStage=c:stage(2,nil,spell(2))
    if eStage==1 and permitted(2,1) and distance<=c.profile.eRange then
        local dmg=c:combatDamage(2,target,1)
        add({id='E1',slot=2,stage=1,kind='magic',energy=spell(2).mana or 0,cost=1,
            delay=function(s)if inRange(s,c.profile.eRange) then return .25 end end,damage=function()return dmg end})
    elseif eStage==2 and permitted(2,2) and distance<=c.profile.e2Range and U.buff(target,P.eMarks,c:now()) then
        -- Utility only: do not invent a mode-independent slow coefficient or
        -- count speculative slow-enabled attacks as guaranteed kill damage.
        local refresh=distance<=range and c:passive()==0
        if speed>0 and immobile<horizon and distance>range*.75 or refresh then
            add({id='E2',slot=2,stage=2,energy=spell(2).mana or 0,cost=.5,utility=refresh and c:aaDamage(target)*.2 or math.min(100,math.max(20,gap*.3)),
                delay=function(s)if inRange(s,c.profile.e2Range) then return .05 end end})
        end
    end
    local wStage=c:stage(1,nil,spell(1))
    if permitted(1,wStage) and distance<=range then
        local missing=math.max(0,(myHero.maxHealth or 0)-(myHero.health or 0))
        local refresh=c:passive()==0 and c:aaDamage(target)*.2 or 0
        -- Utility is a scheduling preference, never extra damage or a claim of
        -- measured W shielding/healing. Unknown coefficients cannot prove a kill.
        local utility=refresh+math.min(100,missing*.15)
        if utility>0 then add({id=wStage==2 and 'W2' or 'W1',slot=1,stage=wStage,
            energy=spell(1).mana or 0,cost=.5,utility=utility,delay=function()return .05 end}) end
    end
    if c.config:get('items') and mode=='fight' then
        for slot=6,11 do
            local useful,rule=c.actives:itemAllowed(slot,target)
            if useful and c:ready(slot) and not c.actions.pending[slot] then
                local item=c.damageModel:item(slot,target);local slotValue=slot
                if item and not item.unknown and item.damage>0 then
                    add({id='Item'..slot,slot=slotValue,kind=item.type,cost=.5,
                        delay=function(s)if inRange(s,rule.range) then return .05 end end,damage=function()return item.damage end})
                end
            end
        end
    end
    if mode=='fight' and c.config:get('comboIgnite') then
        local slot,damage,known=c.damageModel:ignite(target)
        if slot and known and (not c.config:get('igniteExecute') or damage>=U.typedHP(target,'true')+10) then
            -- Ignite's full duration must elapse before claiming its full damage.
            add({id='Ignite',slot=slot,kind='true',cost=4,delay=function(s)if inRange(s,600) then return 5 end end,
                damage=function()return damage+math.max(0,target.hpRegen or 0)*5 end})
        end
    end
    m.lookup=lookup;m.approach=approach;m.targetSpeed=speed;m.immobile=immobile
    return m
end
function T:assess(target,owner,horizon,options)
    if not self.ctx:enemyValid(target) then return {expanded=0} end
    local model=self:model(target,owner,horizon or self:window(target),options)
    local result=F.solve(model);result.model=model
    result.estimated=not (self.ctx.config:get('mechanicsVerified') or self.ctx.profile.damageVerified)
    return result
end
function T:cast(id,target,owner)
    local c=self.ctx
    if id=='Q1' then return c.spells:q1(target,owner,false)
    elseif id=='Q2' then return c.spells:q2(target,owner,false)
    elseif id=='E1' or id=='E2' then return c.spells:e(target,owner)
    elseif id=='W1' or id=='W2' then return c.spells:w(myHero,owner)
    elseif id=='Ignite' then return c.damageModel:castIgnite(target)
    elseif id and id:sub(1,4)=='Item' then
        local slot=tonumber(id:sub(5));local ok,rule=c.actives:itemAllowed(slot,target)
        if ok then return c.actions:cast(slot,rule.targeted and target or nil,owner,{intendedTarget=target,
            validate=function()return c.actives:itemAllowed(slot,target)end}) end
    end
    return false
end
return T

end
modules["lho.terrain"] = function(require)
local T=require('ChampionMobility.terrain')(require('lho.util'),require('lho.navigation'))
local new=T.new
T.new=function(ctx)return new(ctx,_G.LHO_Terrain)end
return T

end
modules["lho.util"] = function(require)
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

end
modules["lho.wardnames"] = function(require)
-- Display names for supported ward items; no recipes, prices or purchase policy.
return {
    [2055]='Control Ward',
    [2056]='Stealth Ward',
    [3340]='Stealth Ward',
    [772043]='Vision Ward',
    [772044]='Sight Ward',
    [772045]='Ruby Sightstone',
    [772049]='Sightstone',
    [772050]='Explorer Ward',
    [773154]="Wriggle's Lantern",
    [773160]='Feral Flare',
    [773340]='Yellow Trinket',
}

end
modules["lho.wards"] = function(require)
local U=require('lho.util')
local Shared=require('ChampionMobility.wards')(U)
local W={};W.__index=W
function W.new(ctx,actions,terrain) return setmetatable({ctx=ctx,actions=actions,terrain=terrain},W) end
function W:available()
    return self.ctx:ready(1) and self.ctx:stage(1)==1 and not self.actions.pending[1]
end
function W:objects(force)
    local count=Game.WardCount and U.count(Game.WardCount(),512) or 0
    if not force and self.objectCache and self.objectAt==self.ctx:now() and self.objectCount==count then return self.objectCache end
    local result={}
    if Game.WardCount and Game.Ward then for i=1,count do local w=Game.Ward(i);if w then result[#result+1]=w end end end
    self.objectCache=result;self.objectAt=self.ctx:now();self.objectCount=count
    return result
end
function W:jumpable(u)
    local n=U.name(u and u.charName)
    return U.valid(u) and u.team==myHero.team and not U.same(u,myHero)
        and n~='bluetrinket' and n~='farsightward' and n~='zombieward'
        and U.dist(myHero.pos,u.pos)<=self.ctx.profile.wRange
end
W.itemReady=Shared.itemReady
W.hasCharges=Shared.hasCharges
function W:diagnostics(reason)
    if not self.ctx.config.capture then return end
    local c=self.ctx;local rows={}
    for slot=6,12 do
        local item=myHero:GetItemData(slot);local d=c:spell(slot)
        if item and (item.itemID or 0)>0 then rows[#rows+1]={slot=slot,id=item.itemID,name=d.name,
            spellSlot=c:spellSlot(slot),hotkey=self.actions:key(slot),
            supported=c.profile.wards[item.itemID]~=nil,cd=d.currentCd,useState=Game.CanUseSpell(c:spellSlot(slot)),
            spellAmmo=d.ammo,itemAmmo=item.ammo,stacks=item.stacks,stackCount=item.stackCount,ready=self:itemReady(slot,item)} end
    end
    if c.config.capture then c:log('ward_resolution',{reason=reason,wStage=c:stage(1),wReady=c:ready(1),items=rows}) end
end
W.slot=Shared.slot
function W:itemSlot(id) return self:slot(id) end
function W:canStart(destination)
    local c=self.ctx
    if not destination or not self:available() or c:dash() then return false end
    if self:existing(destination) then return true end
    return self:slot()~=nil and U.dist(myHero.pos,destination)<=self:range()
        and self.terrain:wall(destination)==false
end
function W:range(slot)
    slot=slot or self:slot();local range=slot and self.ctx:spell(slot).range
    local configured=self.ctx.config:get('wardRange')
    if not range or range<=0 or range>700 then range=configured
    else range=math.min(configured,math.max(50,range-25)) end
    return math.min(range,self.ctx.profile.wRange-15)
end
function W:existing(pos,tolerance)
    local result,dist=nil,tolerance or self.ctx.config:get('reuseRadius')
    local units={};for _,w in ipairs(self:objects()) do units[#units+1]=w end
    for _,u in ipairs(self.ctx.allies or {}) do units[#units+1]=u end
    for _,u in ipairs(self.ctx.minions or {}) do if u.team==myHero.team then units[#units+1]=u end end
    for _,u in ipairs(units) do
        local d=U.dist(pos,u.pos)
        if self:jumpable(u) and d<=dist then result,dist=u,d end
    end
    return result
end
function W:advance(job)
    if job.done or job.stepAt==self.ctx:now() then return job.result end
    job.stepAt=self.ctx:now()
    local ok,result=coroutine.resume(job.work)
    if not ok then
        job.done=true;job.result={valid=false,pos=job.raw,raw=job.raw,reason='Navigation calculation failed'}
        if self.ctx.config.capture then self.ctx:log('ward_planner_error',{reason=tostring(result)}) end
    elseif coroutine.status(job.work)=='dead' then job.done=true;job.result=result
    else job.result={valid=false,kind='planning',pos=job.raw,raw=job.raw,reason='Calculating approach',job=job} end
    return job.result
end
function W:resetPreview()
    self.previewCache=nil;self.previewState=nil;self.lastValid=nil
end
function W:planUsable(p)
    if not p or not p.valid or not self:available() or self.ctx:dash() then return false end
    if p.provider~=self.terrain.provider or p.wall~=(self.terrain.provider and self.terrain.provider.isWall)
        or self.terrain:wall(p.pos)~=false then return false end
    if p.kind=='assisted' and not self.ctx.config:get('wardAssist') then return false end
    if p.kind~='approach' then return self:canStart(p.pos) end
    if not self.ctx.config:get('wardApproach') or not self:slot() or not p.path or #p.path==0
        or U.dist(p.stand,p.pos)>self:range() then return false end
    local limit=self.ctx.config:get('wardWalkRange')
    if limit>0 and U.dist(myHero.pos,p.walkTo or p.stand)>limit then return false end
    if p.nativeRoute then
        local hit,out=self.terrain:crossing(p.walkTo,p.pos)
        local toward=(myHero.pos.x-p.walkTo.x)*(p.pos.x-p.walkTo.x)+(myHero.pos.z-p.walkTo.z)*(p.pos.z-p.walkTo.z)
        return hit~=nil and out~=nil and toward<=self:range()*35
            and self.terrain:clearance(p.walkTo,math.min(45,myHero.boundingRadius or 35),true)
    end
    local from=myHero.pos;local radius=math.min(45,myHero.boundingRadius or 35)
    -- Static routes need no repeat segment scan while Lee remains stationary.
    -- Live/custom providers always recheck; provider/function changes invalidate
    -- the whole plan above. A moving Lee gets a new connection check.
    if self.terrain.provider.static and p.checkedRadius==radius and U.dist(p.checkedOrigin,from)<.001 then return true end
    for _,point in ipairs(p.path) do
        if not self.terrain:walkLine(from,point,radius) then return false end
        from=point
    end
    p.checkedOrigin=U.copy(myHero.pos);p.checkedRadius=radius
    return true
end
function W:publish(p)
    if p.valid then
        p.provider=self.terrain.provider;p.wall=self.terrain.provider and self.terrain.provider.isWall
        self.lastValid=p;self.previewState=p
    elseif self:planUsable(self.lastValid) then self.previewState=self.lastValid
    else
        self.lastValid=nil
        self.previewState=p.kind=='planning' and {valid=false,pos=p.pos,raw=p.raw,reason='No verified landing yet'} or p
    end
    -- Calculations remain internal; a valid visible plan stays the release plan.
    return self.previewState.valid and self.previewState or p
end
function W:releasePreview(raw)
    local shown=self.previewState
    if shown and (shown.kind=='approach' or shown.kind=='assisted') then
        if self:planUsable(shown) then return shown end
        return {valid=false,pos=shown.pos,reason='Displayed wardjump is no longer reachable'}
    end
    -- No hold duration is required for a straightforward tap. Never commit an
    -- unfinished approach calculation that was not shown before release.
    local p=self:preview(raw)
    if p.kind=='planning' then return self.previewState end
    return p
end
function W:preview(raw,force)
    local now=self.ctx:now();local job=self.previewCache;local range=self:range()
    if raw and U.dist(myHero.pos,raw)<=range and self.terrain:wall(raw)==false then
        self.previewCache=nil
        local ready=self:available() and (self:slot() or self:existing(raw))~=nil
        return self:publish({valid=ready,pos=U.copy(raw),raw=U.copy(raw),kind='exact',
            reason=not ready and 'Safeguard or ward unavailable' or nil})
    end
    local cfg=self.ctx.config;local provider=self.terrain.provider;local static=provider and provider.static
    local sameContext=job and job.range==range and job.provider==provider and job.wall==(provider and provider.isWall)
        and job.assist==cfg:get('wardAssist') and job.approach==cfg:get('wardApproach')
        and job.radius==cfg:get('assistRadius') and job.maxWalk==cfg:get('wardWalkRange')
    local sameGeometry=sameContext and U.dist(job.origin,myHero.pos)<.001 and U.dist(job.raw,raw)<.001
    -- The common tap path never creates or resumes a pathfinding coroutine.
    local direct=sameGeometry and static and job.direct
        or self.terrain:landing(myHero.pos,raw,range,self.previewState)
    if direct.valid and direct.kind~='clamped' then
        self.previewCache=nil
        if not self:available() then direct.valid=false;direct.reason='Safeguard unavailable / already requested'
        elseif not self:slot() and not self:existing(direct.pos) then direct.valid=false;direct.reason='No jumpable ward available' end
        return self:publish(direct)
    end
    -- Finish the running job while the cursor moves. Restarting at each pixel
    -- starved the solver and erased its visible result on every refresh.
    if not sameContext or force or (job.done and (not sameGeometry or (not static and now-job.at>.2)))
        or (not sameGeometry and now-job.at>.35 and (U.dist(job.raw,raw)>80 or U.dist(job.origin,myHero.pos)>100)) then
        job={at=now,origin=U.copy(myHero.pos),raw=U.copy(raw),range=range,provider=self.terrain.provider,
            wall=self.terrain.provider and self.terrain.provider.isWall,direct=direct,
            assist=cfg:get('wardAssist'),approach=cfg:get('wardApproach'),radius=cfg:get('assistRadius'),maxWalk=cfg:get('wardWalkRange')}
        local previous=self.previewState
        job.work=coroutine.create(function()
            return self.terrain:plan(job.origin,job.raw,range,previous,function()coroutine.yield()end,job.direct)
        end)
        self.previewCache=job
    end
    local p=self:advance(job)
    if not self:available() then p={valid=false,pos=raw,raw=raw,reason='Safeguard unavailable / already requested'}
    elseif (p.valid or p.kind=='planning') and not self:slot() and not self:existing(p.pos) then
        p={valid=false,pos=raw,raw=raw,reason='No jumpable ward available'}
    end
    if p.valid then
        p.provider=self.terrain.provider;p.wall=self.terrain.provider and self.terrain.provider.isWall
        if not self:planUsable(p) then p={valid=false,pos=raw,raw=raw,reason='Calculated path is no longer reachable'} end
    end
    return self:publish(p)
end
function W:fastTick(actionsUpdated)
    local p=self.pending
    if not p or (p.state~='approaching' and p.state~='placing' and p.state~='waiting_w' and p.state~='jumping') then return end
    if not actionsUpdated then self.actions:tick() end
    self:tick()
end
function W:start(destination,owner,exact,resource,validate,followValidate)
    local c=self.ctx
    if c.config:get('reserveW') and owner=='fight' then return false end
    if self.pending or not destination or not self:available() or c:dash() then return false end
    if owner=='fight' and (c:combatTransit() or c:now()<(self.fightRetryAt or 0)) then return false end
    if validate and not validate() then return false end
    if owner=='fight' and c:underTurret(destination) then return false end
    local existing=not resource and self:existing(destination)
    if existing and owner=='fight' and c:underTurret(existing.pos) then return false end
    if existing then
        local ok,event=self.actions:cast(1,existing,owner,{interrupt=true,verifyHover=true,validate=followValidate or validate})
        if ok then self.pending={owner=owner,pos=U.copy(existing.pos),target=existing,state='jumping',event=event,at=c:now(),
            deadline=c:now()+c.config:get('wardJumpTimeout')/1000} end
        return ok
    end
    local slot=self:itemSlot(resource);if not slot then return false end
    local placementRange,nativeRange=self:range(slot),c:spell(slot).range
    local p=exact and {valid=U.dist(myHero.pos,destination)<=placementRange and self.terrain:wall(destination)==false,pos=U.copy(destination)}
        or self.terrain:landing(myHero.pos,destination,placementRange,self.previewState)
    if not p.valid then return false end
    if U.dist(myHero.pos,p.pos)>placementRange then return false end
    local ids={};for _,w in ipairs(self:objects()) do if U.id(w) then ids[U.id(w)]=true end end
    local ok,event=self.actions:cast(slot,p.pos,owner,{interrupt=true,urgent=true,delay=.02,wardItem=true,validate=validate})
    if not ok then return false end
    if owner=='fight' then self.fightRetryAt=c:now()+c.config:get('comboWardRetry')/1000 end
    self.pending={owner=owner,validate=followValidate or validate,pos=U.copy(p.pos),ids=ids,at=c:now(),wardDispatchAt=event.keyAt or (not self.actions.api and event.dispatchAt),
        wardDispatchTick=event.keyTick or event.dispatchTick,state='placing',event=event,
        deadline=c:now()+math.max(c.config:get('wardTimeout')/1000,c.latency*2+.25)+2*c.jitter}
    -- A consumable can disappear immediately after dispatch. Log the captured
    -- pre-cast inventory instead of dereferencing the now-empty slot.
    local before=event.before
    if c.config.capture then c:log('ward_requested',{pos=U.copy(p.pos),origin=U.copy(myHero.pos),distance=U.dist(myHero.pos,p.pos),
        placementRange=placementRange,nativeRange=nativeRange,owner=owner,slot=slot,item=before.item,
        spellAmmo=before.ammo,itemAmmo=before.itemAmmo,stacks=before.stacks,stackCount=before.stackCount}) end
    return true
end
function W:requestPlan(plan,owner)
    self:diagnostics(plan and (plan.reason or plan.kind) or 'No plan')
    if not plan or self.pending then return false end
    if plan.kind=='planning' and plan.job then
        self.pending={state='planning',owner=owner,pos=U.copy(plan.raw),job=plan.job,at=self.ctx:now(),deadline=self.ctx:now()+3}
        self.ctx.input:pauseFarm();self.stopRequested=nil;return true
    end
    if not plan.valid then return false end
    self.stopRequested=nil
    if plan.kind~='approach' then return self:request(plan.pos,owner) end
    if not self.ctx:ready(1) or self.ctx:stage(1)~=1 or not self:slot() or not plan.path or #plan.path==0 then return false end
    local c=self.ctx;local now=c:now()
    self.pending={state='approaching',owner=owner,pos=U.copy(plan.pos),walkTo=U.copy(plan.walkTo or plan.path[#plan.path]),at=now,
        provider=self.terrain.provider,wall=self.terrain.provider and self.terrain.provider.isWall,crossWall=plan.crossWall,
        lastPos=U.copy(myHero.pos),progressAt=now,deadline=now+5+plan.walkDistance/math.max(150,myHero.ms or 350)*2}
    c.input:pauseFarm();if c.config.capture then c:log('ward_approach_started',{distance=plan.walkDistance,nodes=plan.expanded}) end
    return true
end
function W:request(destination,owner)
    if self.pending then return false end
    self:diagnostics('Wardjump released')
    local at=self.ctx:now()
    if self:start(destination,owner,true) then
        self.ctx.metrics.releaseToPlacement=self.ctx:now()-at
        if self.ctx.config.capture then self.ctx:log('ward_release_dispatch',{delay=self.ctx:now()-at}) end;return true
    end
    -- A release during GG's cursor restoration is queued, never silently lost.
    local c=self.ctx
    if c:ready(1) and c:stage(1)==1 and (self.actions:cursorBusy() or self.actions.issuedTick==at) then
        self.pending={state='queued',owner=owner,pos=U.copy(destination),at=at,
            deadline=at+math.max(.25,c.latency+3*c.jitter)}
        return true
    end
    return false
end
function W:earlyW(p)
    local c=self.ctx;local now=c:now()
    if not c.config:get('wardEarlyW') or p.earlyTried or p.state~='placing' or self.actions.api and not p.wardDispatchAt
        or now<(p.wardDispatchAt or p.at)+c.config:get('wardEarlyDelay')/1000 then return end
    if p.owner=='insec' and not c.combat:wardFollowValid(p) then return end
    local function valid()
        if p.validate and not p.validate() then return false end
        if self.pending~=p or p.state~='placing' or p.event.cancelled or c:blocked() or c:dash()
            or c:stage(1)~=1 or not c:ready(1) or U.dist(myHero.pos,p.pos)>c.profile.wRange then return false end
        if p.owner=='fight' and c:underTurret(p.pos) then return false end
        -- Do not knowingly redirect the speculative W to Lee or another ally.
        -- The exact ward identity is checked again when enumeration catches up.
        local hover
        if Game.GetUnderMouseObject then
            local ok,value=pcall(Game.GetUnderMouseObject);if not ok then return false end;hover=value
            if not hover then p.emptyHoverAt=c:now() end
        end
        if U.valid(hover) and hover.team==myHero.team then
            if U.same(hover,myHero) or not U.name(hover.charName):find('ward',1,true)
                or p.ids[U.id(hover)] or U.dist(hover.pos,p.pos)>90 then return false end
            local owner=hover.ownerID or hover.ownerNetworkID
            if owner and owner~=0 and owner~=myHero.networkID and owner~=myHero.handle then return false end
        end
        return true
    end
    local ok,event=self.actions:cast(1,p.pos,p.owner,{interrupt=true,urgent=true,stage=1,
        wardAnticipation=p,validate=valid})
    if ok then
        p.earlyTried=true;p.earlyEvent=event
        if c.config.capture then c:log('ward_early_w_requested',{owner=p.owner,request=event.id,placementRequest=p.event.id,
            configuredMs=c.config:get('wardEarlyDelay'),requestDelayMs=(event.at-(p.wardDispatchAt or p.at))*1000,
            wallDelayMs=(event.keyTick or event.dispatchTick) and p.wardDispatchTick and (event.keyTick or event.dispatchTick)-p.wardDispatchTick,
            pos=U.copy(p.pos),wardObserved=false}) end
    end
end
function W:earlyObserved(p,stage)
    local c=self.ctx;local event=p.earlyEvent
    if not event then return false end
    local used=(stage or c:stage(1))==2 or event.status=='observed' or event.status=='completed'
    if used and not p.earlyObservedAt then
        p.earlyObservedAt=c:now()
        if c.config.capture then c:log('ward_early_w_observed',{owner=p.owner,request=event.id,stage=c:stage(1),dashing=not not c:dash(),
            delayMs=(c:now()-(event.dispatchAt or event.at))*1000,origin=U.copy(myHero.pos),destination=U.copy(p.pos)}) end
    end
    return used
end
function W:confirmedWValid(p)
    local c=self.ctx
    return self.pending==p and not c:blocked() and not c:dash() and c:stage(1)==1 and c:ready(1)
        and (not p.validate or p.validate())
        and self:jumpable(p.target) and (p.owner~='fight' or not c:underTurret(p.target.pos))
        and (p.owner~='insec' or c.combat:wardFollowValid(p))
end
function W:timing(p)
    local e=p.event;if not e then return end
    local r=self.actions:inputAction(e.cursorID)
    local sent=r and r.sentAt and self.ctx:now()-math.max(0,self.actions:inputNow()-r.sentAt)*.001
        or not self.actions.api and (e.keyAt or e.dispatchAt)
    if not sent or p.wSentAt then return end
    p.wSentAt=sent
    local c=self.ctx
    local placement=(p.placementEvent or p.event)
    local ward=placement and self.actions:inputAction(placement.cursorID)
    local placementTick=ward and ward.sentAt
    local function delta(last,first)if last and first and last>=first then return (last-first)*.001 end end
    local placementAt,observedAt,mechanicalAt
    if self.actions.api then
        placementAt=placementTick;observedAt=p.observedTick;mechanicalAt=r and r.mechanical and r.mechanical.at
        c.metrics.wardPlacementToW=delta(r and r.sentAt,placementTick)
        c.metrics.wardObservationToW=delta(r and r.sentAt,p.observedTick)
    else
        placementAt=p.wardDispatchAt;observedAt=p.observed;mechanicalAt=e.observedAt
        c.metrics.wardPlacementToW=p.wardDispatchAt and sent-p.wardDispatchAt
        c.metrics.wardObservationToW=p.observed and sent-p.observed
    end
    if c.config.capture then c:log('ward_timing',{owner=p.owner,request=e.id,cursorID=e.cursorID,
        requestedAt=r and r.requestedAt or e.at,sentAt=r and r.sentAt or sent,
        queue=r and r.sentAt and r.sentAt>=r.requestedAt and (r.sentAt-r.requestedAt)*.001 or not r and sent-e.at or nil,
        timebase=r and 'monotonic milliseconds' or 'Game.Timer seconds',gameTime=c:now(),placementSentAt=placementAt,
        wardObservedAt=observedAt,placementToW=c.metrics.wardPlacementToW,
        observationToW=c.metrics.wardObservationToW,mechanicalAt=mechanicalAt,
        sendCompletedAt=r and r.sendCompletedAt,holdUntil=r and r.holdUntil,releasedAt=r and r.releasedAt}) end
end
function W:tick()
    if self.stopRequested then
        if self.ctx:now()>self.stopRequested or self.actions:move(myHero.pos,'ward') then self.stopRequested=nil end
    end
    local p=self.pending;if not p then return end
    local c=self.ctx;local now=c:now()
    if c:blocked() or now>p.deadline then self:cancel('Ward request expired');return end
    if self.actions.api and p.event and p.event.cursorID then
        local action=self.actions:inputAction(p.event.cursorID)
        if action and action.state=='cancelled_before_send' then
            -- A fresh T may safely interrupt an unissued object-W at the provider.
            -- Re-enter the existing confirmed-target path only for that explicit
            -- continuation, with the same target/deadline and a bounded budget.
            if p.continuationAction==action.id and p.owner=='ward' and p.state=='jumping' and p.placementEvent
                and not action.sentAt and (p.continuations or 0)<2 and self:confirmedWValid(p) then
                p.continuations=(p.continuations or 0)+1;p.continuationAction=nil
                p.event=p.placementEvent;p.state='waiting_w';p.wSentAt=nil
                if c.config.capture then c:log('ward_w_continuation',{request=action.id,
                    target=U.id(p.target),attempt=p.continuations,reason='Repeated T interrupted unissued W'}) end
                action=self.actions:inputAction(p.event.cursorID)
            else self:cancel('Ward input cancelled');return end
        end
        if action and not action.sentAt then return end
        if action and action.sentAt and not p.event.sendObservedByWard then
            p.event.sendObservedByWard=true
            local sent=now-math.max(0,self.actions.api:Now()-action.sentAt)*.001
            if p.state=='placing' then p.wardDispatchAt=sent;p.deadline=sent+c.config:get('wardTimeout')/1000+2*c.jitter end
        end
    end
    if p.owner=='fight' and p.state~='jumping' and c:underTurret(p.target and p.target.pos or p.pos) then
        self:cancel('Combo ward landing entered turret range');return
    end
    if p.state=='planning' then
        if not c:ready(1) or c:stage(1)~=1 or not self:slot() or c:recalling() then self:cancel('Approach resources changed');return end
        local result=self:advance(p.job)
        if p.job.done then
            if U.dist(p.job.origin,myHero.pos)>=20 then
                result=self:preview(p.pos,true)
                if result.kind=='planning' then p.job=result.job;return end
            end
            self.pending=nil
            if not self:requestPlan(result,p.owner) then c.status=result.reason or 'No wardjump approach available' end
        end
        return
    elseif p.state=='approaching' then
        if not c.config:get('wardApproach') or not c:ready(1) or c:stage(1)~=1 or not self:slot()
            or self.terrain:wall(p.pos)~=false or c:recalling() then self:cancel('Approach resources / context changed');return end
        if U.dist(myHero.pos,p.lastPos)>25 then p.lastPos=U.copy(myHero.pos);p.progressAt=now;p.moveObserved=true end
        if self:canStart(p.pos) then
            if p.crossWall then
                local hit,out=self.terrain:crossing(myHero.pos,p.pos)
                if not hit or not out then self:cancel('Crossing no longer lies between Lee and landing');return end
            end
            self.pending=nil
            if self:request(p.pos,p.owner) then if c.config.capture then c:log('ward_approach_arrived',{delay=now-p.at}) end else self.pending=p end
            return
        end
        if p.provider~=self.terrain.provider or p.wall~=(self.terrain.provider and self.terrain.provider.isWall)
            or not self.terrain:clearance(p.walkTo,math.min(45,myHero.boundingRadius or 35)) then
            self:cancel('Approach destination changed');return
        end
        if p.moveID then
            local move=self.actions:inputAction(p.moveID)
            if not move or move.state=='cancelled_before_send' then self:cancel('Approach input cancelled');return end
            p.moveSentAt=move.sentAt and now-math.max(0,self.actions:inputNow()-move.sentAt)*.001
            if move.state=='send_uncertain' then self:waitReason(p,'Approach input uncertain');return end
            if not p.moveSentAt then return end
        end
        local path=myHero.pathing
        if p.moveSentAt and path and path.hasMovePath then p.moveObserved=true end
        if p.moveObserved and p.moveIssued and p.moveSentAt and now-p.moveSentAt>.25 and path and not path.hasMovePath then
            -- Native path ended short: stay across the selected local wall.
            local hit,out=self.terrain:crossing(myHero.pos,p.pos)
            local alternate=out and U.toward(myHero.pos,p.pos,U.dist(myHero.pos,out)+16)
            if hit and alternate and self:canStart(alternate) then p.pos=alternate;return self:tick() end
            if not p.corrected then
                p.corrected=true
                local nextPoint=self.terrain:nearBoundary(p.walkTo,p.pos)
                if U.dist(myHero.pos,nextPoint)>25 then
                    p.walkTo=nextPoint;p.moveIssued=nil;p.moveID=nil;p.moveSentAt=nil;p.moveObserved=nil;p.progressAt=now
                else self:cancel('Native approach ended before reachable landing');return end
            else self:cancel('Correction ended before reachable landing');return end
        end
        if now-p.progressAt>1.5 and (not p.moveID or p.moveSentAt) then self:cancel('Approach stalled');return end
        if not p.moveIssued then
            p.moveIssued=self.actions:move(p.walkTo,p.owner)
            if p.moveIssued then
                p.moveID=self.actions.lastCursorAction;p.moveRequestedAt=now
                if not self.actions.api then p.moveSentAt=now end
                if c.config.capture then c:log('ward_approach_move',{destination=p.walkTo,landing=p.pos,cursorID=p.moveID,correction=p.corrected==true}) end
            end
        end
        return
    elseif p.state=='queued' then
        if c:stage(1)~=1 or not c:ready(1) then self:cancel('Safeguard unavailable');return end
        self.pending=nil
        if self:start(p.pos,p.owner,true) then c.metrics.releaseToPlacement=now-p.at;if c.config.capture then c:log('ward_release_dispatch',{delay=now-p.at}) end
        else self.pending=p end
        return
    elseif p.state=='placing' then
        if c:stage(1)==2 and not p.earlyEvent then self:cancel('Safeguard used elsewhere');return end
        self:earlyObserved(p)
        local function accept(w,source)
            if not w then return false end
            local owner=w.ownerID or w.ownerNetworkID
            if U.id(w) and not p.ids[U.id(w)] and w.valid~=false and w.team==myHero.team and w.pos and not w.dead and U.dist(p.pos,w.pos)<=90
                and (not owner or owner==0 or owner==myHero.networkID or owner==myHero.handle) then
                p.observed=now;p.observedTick=self.actions.api and self.actions:inputNow();p.target=w;p.state='waiting_w';p.placementEvent=p.event
                p.deadline=now+c.config:get('wardJumpTimeout')/1000+2*c.jitter
                if c.config.capture then c:log('ward_first_observation',{source=source,target=U.id(w),delay=now-(p.wardDispatchAt or p.at),owner=p.owner,
                    earlyRequest=p.earlyEvent and p.earlyEvent.id,earlyWObserved=p.earlyObservedAt~=nil}) end
                return true
            end
        end
        -- Native hover can expose the new ward before WardCount/Ward does.
        -- Use that earliest object signal, retaining the same GG-owned handoff.
        if c.config:get('wardFastCursor') and Game.GetUnderMouseObject then
            local ok,hovered=pcall(Game.GetUnderMouseObject)
            if ok and hovered and U.name(hovered.charName):find('ward',1,true) and self:jumpable(hovered) then
                accept(hovered,'native hover')
            end
        end
        if p.state=='placing' then
            for _,w in ipairs(self:objects(true)) do if accept(w,'ward enumeration') then break end end
        end
        if p.state=='placing' then self:earlyW(p) end
    end
    -- Discovering the ward and dispatching W happen in the same callback.
    if p.state=='waiting_w' then
        -- Read the stage once for this transition. Host metadata can advance
        -- between reads, before Actions publishes the matching observation.
        -- A sent early W is historical input, not an unspent W prerequisite.
        p.followStage=c:stage(1)
        if self:earlyObserved(p,p.followStage) then
            p.state='jumping';p.event=p.earlyEvent;p.pos=U.copy(p.target.pos)
            self:timing(p)
        end
    end
    if p.state=='waiting_w' then
        if p.validate then
            local valid,reason=p.validate()
            if not valid then self:cancel(reason or 'Ward follow-up no longer useful');return end
        end
        if p.owner=='insec' and not c.combat:wardFollowValid(p) then
            self:cancel('Target moved beyond remaining insec resources');return
        end
        if p.followStage==2 then self:cancel('Safeguard used elsewhere');return end
        if p.followStage~=1 then self:waitReason(p,'W stage metadata');return end
        if p.target.dead or p.target.valid==false then self:cancel('Jump ward destroyed');return end
        if self:jumpable(p.target) and not c:dash() then
            -- A rejected early ground cast must not occupy the normal W slot
            -- until the generic acknowledgement timeout. Only replace our own
            -- speculative request, and only with W1 still ready at observation.
            if self.actions.api and p.earlyEvent and p.earlyEvent.cursorID then
                local early=self.actions:inputAction(p.earlyEvent.cursorID)
                if early and not early.sentAt and early.state~='cancelled_before_send' then
                    self.actions.scope:Cancel(early.id,'Confirmed object replaces unsent speculative cast')
                    p.earlyEvent.status='cancelled'
                elseif early and early.state=='send_uncertain' then
                    self:waitReason(p,'Early W send uncertain');return
                elseif early and early.sentAt then
                    -- Empty hover can establish an early no-target trial. If
                    -- hover was nonempty, wait for the action acknowledgement
                    -- window instead, then reconcile against current ready W1
                    -- and the confirmed ward. This is one new object-targeted
                    -- attempt, not a replay or proof the first input never ran.
                    local sent=now-math.max(0,self.actions.api:Now()-early.sentAt)*.001
                    local empty=p.emptyHoverAt and math.abs(p.emptyHoverAt-sent)<.03
                    local expired=p.earlyEvent.status=='unconfirmed' and now>p.earlyEvent.deadline
                    local ready=(empty or expired)
                        and now-sent>=math.max(.12,c.latency*2+3*c.jitter)
                        and early.releasedAt and c:ready(1) and c:stage(1)==1
                        and not c:dash() and p.earlyEvent.status~='observed'
                    if not ready then self:waitReason(p,'Early W awaiting mechanical evidence');return end
                    p.earlyEvent.status=empty and 'no_target' or 'unconfirmed';p.earlyNoEffectAt=now
                    p.earlyReconciliation=empty and 'empty_hover' or 'acknowledgement_expired_W1_ready'
                end
            end
            if p.earlyEvent and self.actions.pending[1]==p.earlyEvent and c:ready(1) then
                self.actions.pending[1]=nil;p.earlyEvent.status='unconfirmed';p.earlyEvent.intentStatus='superseded'
            end
            if p.earlyEvent and not p.fallbackReported then
                p.fallbackReported=true;p.earlyEvent.intentStatus='superseded'
                if c.config.capture then c:log('ward_early_w_fallback',{owner=p.owner,request=p.earlyEvent.id,target=U.id(p.target),
                    reason=p.earlyReconciliation or 'unsent_replacement',
                    delayMs=(now-(p.earlyEvent.dispatchAt or p.earlyEvent.at))*1000}) end
            end
            -- W is object-targeted: a settled screen coordinate alone does not
            -- establish that a newly spawned ward is actually under the cursor.
            -- Use the shared bounded identity/candidate path, with no projection
            -- fallback and no replay of an already issued W.
            local ok,event=self.actions:cast(1,p.target,p.owner,{interrupt=true,urgent=true,wardFollowup=true,verifyHover=true,
                validate=function()return self:confirmedWValid(p)end})
            if ok then
                p.state='jumping';p.event=event;p.pos=U.copy(p.target.pos)
                self:timing(p)
            else self:waitReason(p,not c:ready(1) and 'W not ready' or self.actions:cursorBusy() and 'GG cursor unavailable' or 'Cast dispatcher declined') end
        else self:waitReason(p,c:dash() and 'Lee is dashing' or 'Ward targetability / visibility / range') end
    end
    if p.state=='jumping' then
        self:timing(p)
        if c:dash() and not p.dashStartedAt then p.dashStartedAt=now end
        if p.owner=='ward' and not p.followIssued and c.config:get('wardFollowCursor') and (c:dash() or c:stage(1)==2) then
            if not self.actions:cursorBusy() then c.aim=c:playerPosition() end
            p.followIssued=self.actions:move(c.aim,'ward')
            if p.followIssued then if c.config.capture then c:log('ward_follow_move',{destination=U.copy(c.aim),duringDash=not not c:dash()}) end end
        end
        if not c:dash() and U.dist(myHero.pos,p.pos)<140 and (c:stage(1)==2 or p.event.status=='observed') then
            local duration=p.dashStartedAt and now-p.dashStartedAt or nil
            if duration and duration>=.02 and duration<=.8 then
                c.metrics.wardDashDuration=c.metrics.wardDashDuration and c.metrics.wardDashDuration*.75+duration*.25 or duration
            end
            p.event.status='completed';self.lastCompleted=now;self.pending=nil;if c.config.capture then c:log('wardjump_completed',{owner=p.owner,target=U.id(p.target),request=p.event.id,duration=now-p.at,dashEndAt=now,dashStartAt=p.dashStartedAt,wSentAt=p.wSentAt,wObservedAt=p.event.observedAt,landing=U.copy(myHero.pos),destination=U.copy(p.pos)}) end
        elseif not self.actions.api and p.event.status=='unconfirmed' and self:available() and self:jumpable(p.target) and not c:dash() then
            local ok,event=self.actions:cast(1,p.target,p.owner,{interrupt=true,urgent=true,verifyHover=true,
                validate=function()return self:confirmedWValid(p)end})
            if ok then p.event=event;if c.config.capture then c:log('ward_w_retry',{target=U.id(p.target)}) end end
        end
    end
end
function W:waitReason(p,reason)
    if p.waitReason==reason then return end
    p.waitReason=reason
    if self.ctx.config.capture then self.ctx:log('ward_handoff_wait',{reason=reason,delay=self.ctx:now()-p.at}) end
end
-- Repeated standalone T is continuation after resource commitment. Before
-- commitment it remains a new preview/re-aim; right-click still explicitly cancels.
function W:retainCommitted()
    local p=self.pending;local c=self.ctx
    if not p or p.owner~='ward' or c:blocked() or c:now()>p.deadline
        or (p.state~='placing' and p.state~='waiting_w' and p.state~='jumping') then return false end
    local event=p.placementEvent or p.event
    local action=event and self.actions:inputAction(event.cursorID)
    local issued=self.actions.api and action and (action.sentAt or action.state=='send_uncertain')
        or not self.actions.api and event and event.keyAt
    if not issued then return false end
    local current=p.event and self.actions:inputAction(p.event.cursorID)
    p.continuationAction=p.state=='jumping' and current and not current.sentAt
        and current.state~='send_uncertain' and current.id or nil
    if c.config.capture then c:log('wardjump_continued',{owner=p.owner,state=p.state,
        placementRequest=event.id,target=U.id(p.target),destination=U.copy(p.pos),
        reason='Repeated T retains committed jump',deadline=p.deadline}) end
    return true
end
function W:cancel(reason,stop)
    self.stopRequested=stop and self.pending and self.pending.state=='approaching' and self.ctx:now()+.4 or nil
    if self.pending then
        self.pending.cancelled=true;self.pending.cancelReason=reason
        self.actions:cancel(self.pending.owner)
        if self.ctx.config.capture then self.ctx:log('wardjump_cancelled',{reason=reason,owner=self.pending.owner,state=self.pending.state,
            earlyRequest=self.pending.earlyEvent and self.pending.earlyEvent.id,earlyWObserved=self.pending.earlyObservedAt~=nil,
            destination=U.copy(self.pending.pos),target=U.id(self.pending.target)}) end
        self.pending=nil
    end
end
return W

end
modules["lho.wave"] = function(require)
local U=require('lho.util')
local Wave={};Wave.__index=Wave
function Wave.new(ctx) return setmetatable({ctx=ctx,reserved={}},Wave) end
function Wave:value(m)
    if not self.ctx.config:get('csGoldPriority') then return 0 end
    if type(m.goldBounty)=='number' and m.goldBounty>0 then return m.goldBounty end
    -- Fallback ordering weights, not a claim about the live gold payout.
    local name=U.name(m.charName)
    if name:find('siege',1,true) or name:find('cannon',1,true) or name:find('super',1,true) then return 60 end
    if name:find('ranged',1,true) or name:find('caster',1,true) or name:find('wizard',1,true) then return 14 end
    return 21
end
function Wave:prefer(m,best,deadline,bestDeadline,nextAttack)
    if not best then return true end
    if deadline<=nextAttack and bestDeadline<=nextAttack and self:value(m)~=self:value(best) then
        return self:value(m)>self:value(best)
    end
    if deadline~=bestDeadline then return deadline<bestDeadline end
    if self:value(m)~=self:value(best) then return self:value(m)>self:value(best) end
    return m.health<best.health or m.health==best.health and U.id(m)<U.id(best)
end
function Wave:healthAt(m,delay)
    local now=self.ctx:now()
    if self.forecastAt~=now then self.forecastAt=now;self.forecasts={} end
    local id=U.id(m);local row=self.forecasts[id]
    if not row or row.health~=m.health then row={health=m.health,values={}};self.forecasts[id]=row end
    local key=math.floor(delay*1000+.5)
    if row.values[key]==nil then row.values[key]=self.ctx:healthAt(m,delay) end
    return row.values[key]
end
function Wave:units(anchor)
    local out={}
    for id,r in pairs(self.reserved) do if self.ctx:now()>r.untilTime then self.reserved[id]=nil end end
    for _,m in ipairs(self.ctx.minions or {}) do
        if U.valid(m) and m.team~=myHero.team and m.team~=300 and U.dist(m.pos,myHero.pos)<=self.ctx.profile.qRange then out[#out+1]=m end
    end
    return out
end
function Wave:impact(m)
    return self.ctx:windup()+self.ctx.latency*.5
end
function Wave:cycle()
    local a=self.ctx.sdk.Attack
    return a and a.GetAnimation and a:GetAnimation() or 1/math.max(.5,myHero.attackSpeed or 1)
end
function Wave:attackWait()
    local c=self.ctx;local a=c.sdk.Attack
    if not a or not a.IsReady or a:IsReady() then return 0 end
    -- GG timestamps use Game.Timer seconds. Do not add another latency term
    -- to its readiness calculation; impact() accounts for our travel budget.
    if a.ServerStart then return math.max(0,a.ServerStart+self:cycle()-c:now()) end
    return self:cycle()
end
function Wave:damage(slot,m)
    local c=self.ctx
    if not U.valid(m) or m.team==myHero.team or m.team==300 then return 0 end
    local lane=false
    for _,unit in ipairs(c.minions or {}) do if U.same(m,unit) then lane=true;break end end
    if not lane then return 0 end
    local verified=c.config:get('mechanicsVerified') or c.profile.damageVerified
    if not verified and not c.config:get('laneEstimates') then return 0 end
    return c:spellDamageEstimate(slot,m,1)*(1-c.config:get('laneDamageMargin')/100)
end
function Wave:reservedTarget(m)
    local r=self.reserved[U.id(m)]
    if r and (not U.valid(m) or self.ctx:now()>r.untilTime or r.event.status=='unconfirmed' or r.event.cancelled) then
        self.reserved[U.id(m)]=nil;return false
    end
    return r~=nil
end
function Wave:reserve(units,event,delay)
    for _,m in ipairs(units) do self.reserved[U.id(m)]={event=event,untilTime=self.ctx:now()+delay+.2} end
end
function Wave:attackTarget(anchor)
    local c=self.ctx;local last,lastHP,lastDeadline=nil,math.huge,math.huge;local push,pushHP=nil,-1;local incoming=false
    local cycle=self:cycle();local wait=self:attackWait()
    for _,m in ipairs(self:units(anchor)) do
        if not self:reservedTarget(m) and U.dist(myHero.pos,m.pos)<=c:attackRange(m) then
            local hp=self:healthAt(m,wait+self:impact(m));local nextHP=self:healthAt(m,wait+self:impact(m)+cycle)
            if hp>0 and hp<=c:aaDamage(m) then
                local deadline=math.huge
                if nextHP<=0 then
                    for step=1,4 do
                        local delay=wait+self:impact(m)+cycle*step/4
                        if self:healthAt(m,delay)<=0 then deadline=delay;break end
                    end
                end
                if self:prefer(m,last,deadline,lastDeadline,wait+self:impact(m)+cycle) then
                    last,lastHP,lastDeadline=m,hp,deadline
                end
            end
            if hp>c:aaDamage(m) and nextHP<=c:aaDamage(m) then incoming=true end
            if hp>c:aaDamage(m) and hp>pushHP then push,pushHP=m,hp end
        end
    end
    return last or (not incoming and push or nil),last~=nil,incoming
end
-- Bounded earliest-deadline AA simulation. Forecasts are estimates: reject
-- wave softening if any newly endangered minion lacks an AA/Q rescue slot.
function Wave:schedule(units,damage,castDelay,boost,effectAt)
    local c=self.ctx;local horizon=c.config:get('waveHorizon');local step=.1
    local saved,deadlines={},{};local at=self:attackWait()+c:windup()+c.latency*.5+(castDelay or 0)
    local attackable,attackDamage={},{};local cycle=self:cycle()
    local function hp(m,t)return self:healthAt(m,t)-(t>=(effectAt or 0) and damage and damage[U.id(m)] or 0)end
    for _,m in ipairs(units) do
        attackable[m]=U.dist(myHero.pos,m.pos)<=c:attackRange(m)
        if attackable[m] then attackDamage[m]=c:aaDamage(m) end
        if not self:reservedTarget(m) then
            if hp(m,0)<=0 then deadlines[U.id(m)]=0
            elseif hp(m,horizon)<=0 then
                -- Minion damage forecasts are normally non-increasing. Locate
                -- the first death boundary without querying every grid sample.
                local lo,hi=0,horizon
                for _=1,7 do local mid=(lo+hi)/2;if hp(m,mid)<=0 then hi=mid else lo=mid end end
                deadlines[U.id(m)]=hi
            end
        end
    end
    local attacks=0
    while at<=horizon do
        local best,deadline=nil,math.huge
        for _,m in ipairs(units) do
            local id=U.id(m);local health=hp(m,at)
            if not saved[id] and not self:reservedTarget(m) and attackable[m]
                and health>0 and health<=attackDamage[m]
                and self:prefer(m,best,deadlines[id] or math.huge,deadline,at+cycle) then
                best,deadline=m,deadlines[id] or math.huge
            end
        end
        if best then
            saved[U.id(best)]=at;attacks=attacks+1
            at=at+cycle/(boost and attacks<=2 and 1.2 or 1)
        else at=at+step end
    end
    return saved,deadlines
end
function Wave:canSoften(units,slot,primary,rescue,lastOnly)
    local c=self.ctx;local damage={};local affected=0;local delay=.25+c.latency*.5
    if slot==0 then delay=delay+U.dist(myHero.pos,primary.pos)/c.profile.qSpeed
        if self:healthAt(primary,delay)<=0 then return false end
    end
    for _,m in ipairs(units) do
        if slot==2 and U.dist(myHero.pos,m.pos)<=c.profile.eRange or slot==0 and U.same(m,primary) then
            -- Use the full estimate for future HP depletion, the lower estimate
            -- for claiming kills. The uncertainty band never certifies a kill.
            damage[U.id(m)]=c:spellDamageEstimate(slot,m,1);affected=affected+1
        end
    end
    if affected==0 or slot==2 and affected<2 and not rescue then return false end
    local saved,deadlines=self:schedule(units,damage,.25,false,delay)
    local baseline=rescue and self:schedule(units) or nil
    local qAvailable=slot~=0 and c.config:get(lastOnly and 'lastQ' or 'waveQ') and c:stage(0)==1 and c:ready(0)
        and (myHero.mana or 0)>=(c:spell(slot).mana or 0)+(c:spell(0).mana or 0)
    local qRescue,required=nil,{}
    for _,m in ipairs(units) do
        local id=U.id(m);local hit=damage[id] or 0;local hp=self:healthAt(m,delay)
        local killed=hit>0 and hp>0 and hp<=self:damage(slot,m)
        local protect=not rescue or baseline[id] or hit>0 and self:healthAt(m,c.config:get('waveHorizon'))>0
        if not killed and not self:reservedTarget(m) and deadlines[id] and protect then required[id]=m end
        if required[id] and not saved[id] then
            local qDelay=.25+.25+U.dist(myHero.pos,m.pos)/c.profile.qSpeed+c.latency*.5
            local after=self:healthAt(m,qDelay)-hit
            local point=qAvailable and c.spells:predict(m)
            if qAvailable and point and after>0 and after<=self:damage(0,m) and #c.spells:blockers(m,point)==0 then
                qAvailable=false;qRescue=id
            else return false end
        end
    end
    if qRescue then
        local remaining={};for _,m in ipairs(units) do if U.id(m)~=qRescue then remaining[#remaining+1]=m end end
        local later=self:schedule(remaining,damage,.5,false,delay)
        for id in pairs(required) do if id~=qRescue and not later[id] then return false end end
    end
    return true
end
function Wave:cast(slot,target,units,delay)
    local c=self.ctx;local ok,event
    if slot==0 then ok,event=c.spells:q1(target,'clear',false)
    elseif slot==2 then ok,event=c.spells:e(target,'clear')
    else ok,event=c.spells:w(myHero,'clear',nil,c.mode=='gg_last' and 'last' or 'wave') end
    if ok then
        if slot~=1 then
            if c.actions.api then self.castEvent=event;self.castUntil=nil
            else self.castUntil=c:now()+.25 end
        end
        self:reserve(units or {},event,delay or .25);return true
    end
    return false
end
function Wave:attackLocked()
    local c=self.ctx;local event=self.castEvent
    if event then
        local action=c.actions:inputAction(event.cursorID)
        if not action or action.state=='cancelled_before_send' or event.cancelled then
            self.castEvent=nil;self.castUntil=nil
        elseif action.sentAt then
            local sent=c:now()-math.max(0,c.actions:inputNow()-action.sentAt)*.001
            self.castUntil=sent+.25
            if c:now()>=self.castUntil then self.castEvent=nil end
        end
    end
    return c:now()<(self.castUntil or 0)
end
function Wave:tick(anchor,beforeAttack,lastOnly)
    self.forecastAt=nil
    local c=self.ctx;local units=self:units(anchor);local aa,hasLastHit,incoming=self:attackTarget(anchor)
    if not c.config:get(lastOnly and 'lastAbilities' or 'waveAbilities') then return false end
    if not c.config:get('mechanicsVerified') and not c.profile.damageVerified then
        c.status=c.config:get('laneEstimates') and 'Lane Q/E: profile estimates (margin applied)' or 'Lane Q/E paused: damage estimates disabled'
    end
    if c.sdk.Orbwalker:IsAutoAttacking() or self:attackLocked() then return false end
    local useQ=c.config:get(lastOnly and 'lastQ' or 'waveQ');local useE=c.config:get(lastOnly and 'lastE' or 'waveE')
    local eKills,qSaves={},{}
    local eDelay=.25+c.latency*.5
    local cycle=self:cycle();local wait=self:attackWait()
    local aaSaved=self:schedule(units)
    for _,m in ipairs(units) do
        if not self:reservedTarget(m) then
            local ehp=self:healthAt(m,eDelay)
            if useE and c:stage(2)==1 and c:ready(2) and U.dist(myHero.pos,m.pos)<=c.profile.eRange and ehp>0 and ehp<=self:damage(2,m) then
                eKills[#eKills+1]=m
            end
            if useQ and not aaSaved[U.id(m)] and c:stage(0)==1 and c:ready(0) then
                local point=c.spells:predict(m)
                if point then
                    local qDelay=.25+U.dist(myHero.pos,point)/c.profile.qSpeed+c.latency*.5
                    local qhp=self:healthAt(m,qDelay)
                    local aaLater=self:healthAt(m,wait+self:impact(m)+(U.same(m,aa) and 0 or cycle))
                    if qhp>0 and qhp<=self:damage(0,m)
                        and (aaLater<=0 or U.dist(myHero.pos,m.pos)>c:attackRange(m)) then
                        qSaves[#qSaves+1]={unit=m,delay=qDelay,hp=qhp}
                    end
                end
            end
        end
    end
    table.sort(qSaves,function(a,b)
        local av,bv=self:value(a.unit),self:value(b.unit)
        if av~=bv then return av>bv end
        if a.hp~=b.hp then return a.hp<b.hp end
        return U.id(a.unit)<U.id(b.unit)
    end)
    local eRescue=#eKills==1 and (not hasLastHit or not U.same(eKills[1],aa)
        and self:healthAt(eKills[1],wait+self:impact(eKills[1])+cycle)<=0)
    local waitForAA=false
    if beforeAttack and hasLastHit then
        local killsAA=false;local canWait=true
        for _,m in ipairs(eKills) do
            if U.same(m,aa) then killsAA=true end
            if self:healthAt(m,self:impact(aa)+eDelay)<=0 then canWait=false end
        end
        waitForAA=not killsAA and canWait
    end
    local eNeeded=not lastOnly
    for _,m in ipairs(eKills) do if not aaSaved[U.id(m)] then eNeeded=true end end
    if (#eKills>=2 or eRescue) and not waitForAA and eNeeded and self:canSoften(units,2,nil,true,lastOnly) then
        if self:cast(2,eKills[1],eKills,eDelay) then return true end
    end
    -- Let GG issue an imminent last hit first; save a different minion after
    -- that windup instead of cancelling an attack which was already committed.
    if beforeAttack and hasLastHit then
        for _,candidate in ipairs(qSaves) do
            if not U.same(candidate.unit,aa) and self:healthAt(candidate.unit,candidate.delay+self:impact(aa))<=0
                and self:healthAt(aa,.25+self:impact(aa))>0 then
                if self:cast(0,candidate.unit,{candidate.unit},candidate.delay) then return true end
            end
        end
    else
        for _,candidate in ipairs(qSaves) do
            if self:cast(0,candidate.unit,{candidate.unit},candidate.delay) then return true end
        end
    end
    if not beforeAttack and not hasLastHit and not incoming then
        if not lastOnly and c.config:get('waveSoften') then
            if useE and c:stage(2)==1 and c:ready(2) and self:canSoften(units,2) then
                for _,m in ipairs(units) do if U.dist(myHero.pos,m.pos)<=c.profile.eRange and self:damage(2,m)>0 then
                    if self:cast(2,m,eKills,eDelay) then return true end;break
                end end
            end
        end
        if c.config:get(lastOnly and 'lastW' or 'waveW') and not c.clear:weaving() then
            local useful=not lastOnly and U.hp(myHero)<90 and #units>=2
            if lastOnly then
                local faster,deadlines=self:schedule(units,nil,0,true)
                for id in pairs(deadlines) do if not aaSaved[id] and faster[id] then useful=true end end
            end
            if useful then return self:cast(1,myHero) end
        end
    end
    if not lastOnly and useQ and c.config:get('harassQ') and not beforeAttack and not hasLastHit and not incoming and #qSaves==0 and #eKills==0 and c.config:get('waveHarass') then
        local target=c:target(c.profile.qRange)
        if target then return c.spells:q1(target,'clear',false) end
    end
    return false
end
return Wave

end
modules["Orbama.menus"] = function(require)
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

end
modules["ActionClient"] = function(require)
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
end
modules["ChampionMobility.navigation"] = function(require)
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
modules["ChampionMobility.terrain"] = function(require)
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
modules["ChampionMobility.wards"] = function(require)
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
local function load(name)
 if cache[name] ~= nil then return cache[name] end
 local factory = modules[name]
 if not factory then return externalRequire(name) end
 local result = factory(load)
 cache[name] = result
 return result
end
local function boot()
 if _G.LeeHarveyOsward then return end
 if not _G.SDK or not _G.SDK.Orbwalker or not _G.SDK.Cursor or not _G.SDK.Attack or not _G.SDK.Damage
  or not _G.SDK.OnTick or not _G.SDK.OnDraw or not _G.SDK.OnWndMsg then
  print("[LHO] Enable Orbama or Original-GG before loading Lee Harvey Osward.")
 return end
 local app
 local ok, err = xpcall(function()
 app = load("lho.app").new({originalGG=not _G.SDK.OrbamaVersion})
 app:install()
 end,
  function(e) return debug and debug.traceback and debug.traceback(tostring(e), 2) or tostring(e) end)
 if not ok then
  if app then pcall(app.ctx.log, app.ctx, "controller_error", {reason=tostring(err)}); pcall(app.Shutdown, app) end
  print("[LHO] Load failed: " .. tostring(err)); return
 end
 _G.LeeHarveyOsward = app
end
if _G.SDK then boot() elseif Callback and Callback.Add then Callback.Add("Load", boot)
else print("[LHO] Game callback API unavailable; enable Orbama and reload.") end
return _G.LeeHarveyOsward
