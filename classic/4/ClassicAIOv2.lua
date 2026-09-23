if SDK and SDK.OrbamaVersion and not _G.GGPrediction then
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
-- GENERATED: tools/build_classic_v2.py; Classic data; release payload.
local modules={}
modules.actionClient=(function()
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
modules.vayneProfile=(function()
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

end)()
modules["prediction"]=(function()
-- Local facade: the application's global prediction provider is never replaced.
return function(provider, hero, vector)
    local P={bindings=setmetatable({},{__mode='k'}),cache={}}
    local function point(p) return p and {x=p.x,y=p.y or 0,z=p.z} end
    local function settingsCopy(t)
        local out={};for k,v in pairs(t)do out[k]=type(v)=='table' and settingsCopy(v) or v end;return out
    end
    function P:Resolve(binding)
        local object=binding.object
        if binding.aoe then
            local results=object:GetAOEPrediction(binding.source or hero)
            for _,r in ipairs(results or {}) do
                if r.Unit and r.Unit.networkID==binding.target.networkID and r.Count>=binding.minCount then
                    return {position=point(r.CastPosition),data={targetID=binding.target.networkID,count=r.Count}}
                end
            end
            return nil,'aoe_conditions_changed'
        end
        object:GetPrediction(binding.target,binding.source or hero)
        if not object:CanHit(binding.hc or 2) then return nil,'prediction_declined' end
        local p=point(object.CastPosition);if not p then return nil,'prediction_missing' end
        return {position=p,data={targetID=binding.target.networkID,hitChance=object.HitChance,
            source=point((binding.source or hero).pos),target=point(binding.target.pos)}}
    end
    function P:Validate(binding,resolved)
        local spell=binding.object
        if not spell.Collision then return true end
        local p=resolved and resolved.position
        if not p then return false,'prediction_missing' end
        -- Recheck the actual outgoing ray without running the champion decision
        -- or recalculating all prediction/AOE candidates. Keep provider defaults
        -- and collision allowance; no extra latency or widened obstacle padding.
        local wall,_,count=provider:GetCollision((binding.source or hero).pos,p,
            spell.Speed,spell.Delay,spell.Radius,spell.CollisionTypes,binding.target.networkID)
        if wall or count>(spell.MaxCollision or 0) then return false,'prediction_collision_changed' end
        return true
    end
    local facade=setmetatable({},{__index=provider})
    function facade:SpellPrediction(settings)
        local settings=settingsCopy(settings)
        local object=provider:SpellPrediction(settings)
        local wrapper={}
        function wrapper:GetPrediction(target,source)
            self.target=target;self.source=source;object:GetPrediction(target,source)
            self.CastPosition=object.CastPosition and vector(object.CastPosition)
            self.UnitPosition=object.UnitPosition and vector(object.UnitPosition)
            self.HitChance=object.HitChance
            if self.CastPosition then P.bindings[self.CastPosition]={object=object,target=target,source=source,settings=settings,hc=2} end
            return self
        end
        function wrapper:CanHit(hc)
            local ok=object:CanHit(hc)
            if self.CastPosition and P.bindings[self.CastPosition] then P.bindings[self.CastPosition].hc=hc end
            return ok
        end
        function wrapper:GetAOEPrediction(source)
            local out={}
            for _,r in ipairs(object:GetAOEPrediction(source) or {}) do
                local item={};for k,v in pairs(r)do item[k]=v end
                item.CastPosition=vector(r.CastPosition)
                P.bindings[item.CastPosition]={object=object,target=r.Unit,source=source,settings=settings,aoe=true,minCount=r.Count}
                out[#out+1]=item
            end
            return out
        end
        return setmetatable(wrapper,{__index=object})
    end
    P.facade=facade;return P
end

end)()
modules["policies"]=(function()
-- Shared mechanical predicates; gameplay extensions are registered in each champion module.
-- Does not execute a decision method, enumerate alternative targets, or start timers.
return function(C,q,slot,options)
    local e=C.env;local h=e.myHero;local object=C.champion
    local letter=({[0]='Q',[1]='W',[2]='E',[3]='R'})[slot]
    local spell=letter and (object[letter..'Spell'] or object[letter])
    if not q.range and letter then q.range=type(spell)=='table' and spell.Range or object[letter..'Range'] end
    local method=q.owner
    local menu=e.Menu and (e.Menu[method] or e.Menu[method:lower()])
    if (method=='LaneClear' or method=='JungleClear') and e.Menu.Clear then menu=e.Menu.Clear[method] or e.Menu.Clear end
    if method=='FarmHarass' then menu=e.Menu.Harass end
    local function value(t,k)return t and t[k] and t[k].Value and t[k]:Value() end
    return function(resolved)
        if options.validate then
            local valid,reason=options.validate(q,resolved)
            if not valid then return false,reason or 'spell_condition_changed' end
        end
        if letter then
            if value(menu,letter)==false or value(menu,'Enabled')==false then return false,'disabled'end
            local mana=value(menu,'Mana')
            if type(mana)=='number' and h.maxMana>0 and h.mana/h.maxMana*100<mana then return false,'mana_policy'end
            -- Recasts may have already paid their start cost. The host remains the mechanical readiness authority.
            if q.object and q.range and e.GetDistance(q.object.pos,h.pos)>q.range then return false,'target_out_of_range'end
            if q.target and q.kind=='world' and q.range and e.GetDistance((resolved and resolved.position)or q.target,h.pos)>q.range then return false,'point_out_of_range'end
        end
        if method=='KillSteal' and q.object and letter and object['Get'..letter..'Dmg'] then
            local kind=C.policy and C.policy.damageTypes and C.policy.damageTypes[letter]
            if not kind then return false,'kill_damage_type_undeclared'end
            local shield=kind=='physical' and (q.object.shieldAD or 0) or kind=='magical' and (q.object.shieldAP or 0)
                or kind=='mixed' and ((q.object.shieldAD or 0)+(q.object.shieldAP or 0))
            if shield==nil or shield==false then return false,'kill_damage_type_unsupported'end
            local damage=object['Get'..letter..'Dmg'](object,q.object)
            if C.policy.killBonus then damage=damage+C.policy.killBonus(object,q,slot)end
            if damage<q.object.health+(q.object.hpRegen or 0)+shield then return false,'kill_threshold_changed'end
        end
        if C.policy and C.policy.validate then return C.policy.validate(object,q,slot,resolved)end
        return true
    end
end

end)()
modules["core"]=(function()
return function(g, modules, champion)
    local sdk=g.SDK;local registry=g.ClassicAIOv2
    if registry and registry.Shutdown then registry:Shutdown('superseded') end
    local C={version='2.1.8',generation=(registry and registry.generation or 0)+1,enabled=true,
        pending={},resources={},history={},quarantine={},observedSpells={},spellStates={},locks={},menus={},diagnostics={},metrics={requested=0,sent=0,observed=0,rejected=0},claims={}}
    g.ClassicAIOv2=C
    function C:Trace()end
    local function point(v) return v and {x=v.x,y=v.y or 0,z=v.z} end
    local function clone(t)
        local o={};for k,v in pairs(t)do o[k]=v end;return setmetatable(o,getmetatable(t))
    end
    function C:Active()
        if not self.enabled or g.ClassicAIOv2~=self or g.SDK~=sdk then return false end
        if rawget(g,'Classic'..champion) or package.loaded['ClassicAIO\\Heroes\\Classic'..champion] then
            self:Shutdown('ClassicAIO v1 loaded');return false
        end
        return true
    end
    function C:Cancel(owner,reason)
        for _,q in pairs(self.pending)do if not owner or q.owner==owner then q.cancelled=true;q.callbacks={};self.adapter:Cancel(q.id,reason or "owner_cancelled")end end
    end
    function C:Shutdown(reason)
        if not self.enabled then return end
        self.enabled=false;self.reason=reason;self.locks={}
        if self.adapter then self.adapter:Close(reason) end
        self.pending={};self.resources={}
    end
    local clientOptions={name='ClassicAIOv2',active=function()return C:Active()end}
    if sdk.Actions and sdk.Actions.GetCapabilities and sdk.Actions:GetCapabilities().createClient then
        C.adapter=sdk.Actions:CreateClient(clientOptions)
    else C.adapter=modules.actionClient(g,clientOptions)end
    local A=C.adapter
    local keyedMechanical=A:Capabilities().keyedMechanicalObservation==true
    function C:Available()
        return self:Active() and not g.myHero.dead and not g.Game.IsChatOpen() and g.Game.IsOnTop()
    end
    local env=setmetatable({},{__index=g});env._G=env;C.env=env
    env.os=setmetatable({clock=function()return A:Now()/1000 end},{__index=g.os})
    env.SDK=setmetatable({},{__index=sdk});env.V2=C
    local prediction=modules.prediction(assert(g.GGPrediction,'Prediction provider must be loaded'),g.myHero,g.Vector)
    env.GGPrediction=prediction.facade;C.prediction=prediction
    local slots={}
    for _,name in ipairs({'Q','W','E','R','SUMMONER_1','SUMMONER_2'})do slots[g['HK_'..name]]=g['_'..name] or g[name] end
    for i=1,7 do if g['HK_ITEM_'..i] then slots[g['HK_ITEM_'..i]]=g['ITEM_'..i] end end
    function C:Stamp(key)
        local slot=slots[key];local d=slot and g.myHero:GetSpellData(slot)
        if not d then return '' end
        return tostring(d.name)..':'..tostring(d.currentCd)..':'..tostring(d.toggleState)..':'..tostring(d.ammo)
    end
    function C:Invoke(fn,selfObject,args,name)
        if not self:Active() then return end
        local old=self.decision;local previousContext=self.executionContext
        local declaration=self.policy and self.policy.methods[name]
        if not previousContext and declaration then self.executionContext=declaration(selfObject) end
        if not old and name~='Tick' and name~='OnTick' and name~='Draw' and name~='__init' and name~='LoadMenu' then
            self.decision={name=name,menuReads={}}
        end
        local results={pcall(fn,selfObject,unpack(args))};self.decision=old;self.executionContext=previousContext
        if not results[1] then self:Trace('callback_error',{method=name,error=tostring(results[2])});self:Shutdown('champion_callback_error');error(results[2],0) end
        return unpack(results,2)
    end
    env.class=function(name)
        local class={};class.__index=class
        setmetatable(class,{__call=function(t,...)
            for k,fn in pairs(t)do if type(fn)=='function' then
                local original,method=fn,k
                t[k]=function(object,...)return C:Invoke(original,object,{...},method)end
            end end
            local object=setmetatable({},t);C.champion=object
            object:__init(...);return object
        end});env[name]=class;return class
    end
    local function guarded(fn)
        return function(...)if C:Active() then return fn(...) end end
    end
    env.Callback={Add=function(event,fn)
        g.Callback.Add(event,guarded(function(...)
            if event=='Tick' then C:Observe();C:MaintainClaims() end
            return fn(...)
        end))
    end}
    env.DelayAction=function(fn,delay,args)
        local generation=C.generation
        g.DelayAction(function()if C:Active() and C.generation==generation then fn(unpack(args or {}))end end,delay)
    end
    local orb=setmetatable({},{__index=sdk.Orbwalker});env.SDK.Orbwalker=orb
    function orb:SetAttack(allowed) C.locks.attack=not allowed;A:SetBlocked("champion","attack",not allowed) end
    function orb:SetMovement(allowed) C.locks.move=not allowed;A:SetBlocked("champion","move",not allowed) end
    for _,name in ipairs({'OnPreAttack','OnPreMovement','OnPostAttack','OnPostAttackTick','OnAttack'})do
        if sdk.Orbwalker[name] then
            orb[name]=function(_,fn)
                return sdk.Orbwalker[name](sdk.Orbwalker,guarded(function(...)
                    local args=select(1,...);local mutable=type(args)=="table"
                    local was=mutable and args.Process
                    local result=fn(...)
                    if mutable and was==false then args.Process=false end
                    return result
                end))
            end
        end
    end
    -- Never lend SDK's raw Cursor to champion code.
    env.SDK.Cursor=setmetatable({Add=function(_,key,target)return C:Cast(key,target,{independent=false,owner='manual'})end},
        {__index=function(_,key)if key=='Step' then return 0 end end})
    env.Control=setmetatable({CastSpell=function(key,target)return C:Cast(key,target)end,
        KeyDown=function()return false end,KeyUp=function()return false end},{__index=g.Control})
    env.require=function(name)
        if name=='GGPrediction' or name=='ClassicAIO\\Utils' then return true end
        return g.require(name)
    end
    local config=g.ClassicAIOv2Config or {};C.config=config
    C.ggAutomationApproved=config.ggAutomationApproved
    local function routeMenu(parent,args,path,legacyPath)
        local spec=clone(args);spec.leftIcon=nil
        local values=config.values or {};local migration=config.migration or {}
        if values[path]~=nil then spec.value=values[path]
        elseif migration.enabled==true and migration.values and migration.values[legacyPath]~=nil then
            local old=migration.values[legacyPath]
            if spec.value==nil or type(old)==type(spec.value) then spec.value=old end
        end
        local menu
        if parent then menu=parent.raw(parent.node,spec) or parent.node[spec.id]
        else menu=g.MenuElement(spec)end
        if not menu then return menu end
        local rawValue=menu.Value
        if rawValue then menu.Value=function(node,...)
            local result=rawValue(node,...)
            if select('#',...)==0 and C.decision and C.decision.menuReads then C.decision.menuReads[node]=result end
            return result
        end end
        local raw=menu.MenuElement
        menu.MenuElement=function(node,child)
            return routeMenu({node=node,raw=raw},child,path..'.'..tostring(child.id),legacyPath..'.'..tostring(child.id))
        end
        return menu
    end
    env.MenuElement=function(args)
        local spec=clone(args);local legacy=spec.id
        spec.id=spec.id:gsub('Classic_AIO','ClassicAIOv2'):gsub('ClassicActivator','ClassicAIOv2Activator')
        spec.name=spec.name:gsub('Classic AIO','Classic AIO v2')
        local menu=routeMenu(nil,spec,spec.id,legacy);C.menus[spec.id]=menu;return menu
    end
    function C:ModeContext(mode,condition)
        local names={Combo='COMBO',Harass='HARASS',LaneClear='LANECLEAR',LastHit='LASTHIT',Flee='FLEE'}
        local modeID=sdk['ORBWALKER_MODE_'..names[mode]]
        if mode=='LaneClear' and not sdk.Orbwalker.Modes[modeID] and sdk.Orbwalker.Modes[sdk.ORBWALKER_MODE_JUNGLECLEAR] then modeID=sdk.ORBWALKER_MODE_JUNGLECLEAR end
        return {mode=mode,modes={modeID},condition=function()return env.GetMode()==mode and (not condition or condition())end,
            combat=mode=='Combo' or mode=='Harass',priority=(mode=='LaneClear' or mode=='LastHit') and 'background' or 'normal'}
    end
    function C:HeldContext(held)return {held=held,priority='interactive'}end
    function C:Fresh(fn,...)
        local previous=self.validating;self.validating=true
        local result={pcall(fn,...)};self.validating=previous
        if not result[1]then error(result[2],0)end
        return unpack(result,2)
    end
    function C:RegisterPolicy(policy)
        self.policy=policy
        if policy.channel then A:Condition('champion','channel',function(q)return self:Fresh(policy.channel,self.champion,q)end,policy.exceptions)end
    end
    function C:Cast(key,target,options)
        options=options or {};local binding=target and prediction.bindings[target]
        local targetObject=options.intentTarget or target and target.pos and target or binding and binding.target
        local targetID=targetObject and (targetObject.networkID or targetObject.handle)
        self.lastIntent=nil
        if not self:Available() then return false end
        local slot=options.slot or slots[key];if options.slot then slots[key]=options.slot end
        local resource=slot and 'slot:'..slot or 'key:'..key
        local kind=not target and 'none' or target.pos and 'object' or target.z~=nil and 'world' or 'screen'
        local mode=env.GetMode and env.GetMode();local decision=self.decision
        local owner=options.owner or (decision and decision.name or 'activator')
        local declaration=self.policy and self.policy.methods[owner]
        local context=self.executionContext or (declaration and declaration(self.champion)) or options.context
        if options.context then context=options.context end
        local combat=context and context.combat==true
        local now=A:Now();local spell=slot and g.myHero:GetSpellData(slot)
        local q={key=key,resource=resource,keys=options.keys or {key},type=options.type,kind=kind,target=kind=='world' and point(target) or target,
            targetID=targetID,object=targetObject,owner=owner,mode=context and context.mode or nil,context=context,exceptions=options.exceptions,
            replace=options.replace or 'higher_priority',equivalence=options.equivalence,
            survivePointerMotion=options.survivePointerMotion,
            independent=options.independent~=false and combat and kind~='screen',
            priority=options.priority or (context and context.priority or 'normal'),expires=now+(options.ttl or 250),
            callbacks={},stamp=self:Stamp(key),spellName=spell and spell.name,
            toggleState=spell and spell.toggleState,ammo=spell and spell.ammo,cooldown=spell and spell.currentCd,requestGameTime=g.Game.Timer(),previousCastStart=g.myHero.activeSpell and g.myHero.activeSpell.startTime,requestedAt=now,range=options.range or binding and binding.settings.Range,itemID=slot and slot>=g.ITEM_1 and g.myHero:GetItemData(slot).itemID}
        q.observe=options.observe
        q.start=function()return self:Available()end
        q.continue=function()return not q.cancelled and self:Available() and A:ContextValid(q,'continuation') end
        local menuReads={};for node,value in pairs(decision and decision.menuReads or {})do menuReads[node]=value end
        local validate=modules.policies(self,q,slot,options)
        q.reconcile=function()
            local cast=g.myHero.activeSpell
            return not g.myHero.dead and slot~=nil and g.Game.CanUseSpell(slot)==0
                and g.myHero:GetSpellData(slot).currentCd==0 and not (cast and cast.valid and not cast.isAutoAttack)
        end
        q.mechanical=function(resolved)
            if not q.continue() or not A:ContextValid(q) then return false,'context_changed' end
            if self:Stamp(key)~=q.stamp then return false,'spell_state_changed' end
            if slot then
                local current=g.myHero:GetSpellData(slot)
                if g.Game.CanUseSpell(slot)~=0 or not current or current.level==0 then return false,'spell_unavailable' end
                local paid=self.policy and self.policy.costPaid and self.policy.costPaid(self.champion,q,slot)
                if not paid and type(current.mana)=='number' and current.mana>g.myHero.mana then return false,'insufficient_mana' end
            end
            if q.itemID and g.myHero:GetItemData(slot).itemID~=q.itemID then return false,'item_changed' end
            if targetObject and (not env.IsValid(targetObject) or (targetObject.networkID or targetObject.handle)~=targetID) then return false,'target_invalid' end
            if q.range and q.target then
                local p=resolved and resolved.position or (q.kind=='object' and q.target.pos or q.target)
                if not p or env.GetDistance(p,g.myHero.pos)>q.range then return false,'target_out_of_range' end
            end
            for node,value in pairs(menuReads)do if node:Value()~=value then return false,'settings_changed'end end
            if binding and resolved then
                local valid,reason=prediction:Validate(binding,resolved)
                if not valid then return false,reason end
            end
            return validate(resolved)
        end
        local mechanical=q.mechanical;q.mechanical=function(resolved)
            local valid,reason=self:Fresh(mechanical,resolved)
            q.lastValidationReason=not valid and (reason or 'champion_condition_changed') or nil
            return valid,reason
        end
        if options.resolve and kind=='world' then q.resolve=options.resolve end
        if binding then
            q.resolve=function()
                if not q.continue() or not env.IsValid(targetObject) then return nil,'intent_ended' end
                return prediction:Resolve(binding)
            end
        end
        if not q.start() then return false end
        self.metrics.requested=self.metrics.requested+1
        local id,reason=A:Submit(q)
        local initial=id and A:Poll(id)
        if not id then self.metrics.rejected=self.metrics.rejected+1;self.diagnostics.lastReject=reason;return false end
        if initial and initial.state=='cancelled_before_send' then
            self.metrics.rejected=self.metrics.rejected+1;self.diagnostics.lastReject=initial.reason or initial.state
            A:Finish(id)
            return false
        end
        if reason=='deduplicated' then return true,id end
        local prior=self.resources[resource]
        if prior and prior.id~=id then
            prior.cancelled=true;prior.callbacks={};self.pending[prior.key]=nil
        end
        q.id=id;self.pending[key]=q;self.resources[resource]=q;self.lastIntent=q
        return true,id
    end
    function C:RunDecision(name,fn)
        local old=self.decision;local previousContext=self.executionContext
        local declaration=self.policy and self.policy.methods[name]
        if not self.executionContext and declaration then self.executionContext=declaration(self.champion) end
        self.decision={name=name,menuReads={}}
        local ok,result=pcall(fn);self.decision=old;self.executionContext=previousContext;if not ok then error(result,0)end;return result
    end
    function C:Delayed(key,delay,fn)
        self.delayed=self.delayed or {};if self.delayed[key] then return end
        self.delayed[key]=true
        env.DelayAction(function()self.delayed[key]=nil;self:RunDecision(key,fn)end,delay)
    end
    function C:AfterCast(key,fn)
        local q=self.lastIntent
        if q and q.key==key and self.pending[key]==q then q.callbacks[#q.callbacks+1]=fn end
    end
    function C:Observe()
        for slot=0,3 do
            local d=g.myHero:GetSpellData(slot);local old=self.spellStates[slot]
            if d then
                if old and (d.currentCd>(old.cd or 0) or d.name~=old.name or d.toggleState~=old.toggle) then self.observedSpells[slot]=g.Game.Timer() end
                self.spellStates[slot]={cd=d.currentCd,name=d.name,toggle=d.toggleState}
            end
        end
        for key,q in pairs(self.pending)do
            local r=A:Poll(q.id)
            if not r or r.state=='cancelled_before_send' then self.pending[key]=nil;self.metrics.rejected=self.metrics.rejected+1
            else
                if r.jobCancelled then q.cancelled=true;q.callbacks={} end
                if r.state=='send_uncertain' or r.interrupted or r.competitor then q.ambiguous=true end
                if r.sentAt and not q.sentAt then q.sentAt=r.sentAt;self.metrics.sent=self.metrics.sent+1 end
                if not r.sentAt and not q.continue() then A:Cancel(q.id,'mode_or_context_ended')
                elseif r.sentAt then
                    local slot=slots[key];local d=slot and g.myHero:GetSpellData(slot)
                    local changed
                    if q.observe then changed=q.observe()
                    else
                        local cast=g.myHero.activeSpell
                        local started=cast and cast.valid and not cast.isAutoAttack and cast.name==q.spellName
                            and cast.startTime and cast.startTime~=q.previousCastStart and cast.startTime>=q.requestGameTime
                        changed=started or d and (d.name~=q.spellName or d.toggleState~=q.toggleState or type(d.currentCd)=='number' and d.currentCd>(q.cooldown or 0)
                            or type(d.ammo)=='number' and type(q.ammo)=='number' and d.ammo<q.ammo)
                    end
                    local receipt=not q.observe and keyedMechanical and r.commandReceipt
                    if changed and (not q.ambiguous or receipt) then
                        local observedAt=A:Now()
                        local evidence={kind='mechanical',at=observedAt,source='spell_state_transition',unique=true}
                        if receipt then
                            evidence.attribution='command_key';evidence.key=receipt.key
                            evidence.generation=receipt.generation;evidence.session=receipt.session
                        end
                        local accepted,why=A:Observe(q.id,evidence)
                        q.observationReason=why
                        if accepted then
                            q.observedAt=observedAt;self.metrics.observed=self.metrics.observed+1
                            for _,fn in ipairs(q.callbacks)do if self:Active() and q.continue() then fn(q) end end
                            self.pending[key]=nil
                        else q.ambiguous=true end
                    end
                    if self.pending[key] and not q.observedAt and A:Now()>q.expires+750 then
                        q.outcome='unobserved_handoff'
                        if A:Reconcile(q.id) then self.pending[key]=nil end
                    end
                end
            end
            if not self.pending[key] then
                A:Finish(q.id)
                if self.resources[q.resource]==q then self.resources[q.resource]=nil end
                self.history[#self.history+1]={id=q.id,owner=q.owner,key=q.key,resource=q.resource,outcome=q.outcome,sentAt=q.sentAt,observedAt=q.observedAt};if #self.history>128 then table.remove(self.history,1)end
            end
        end
    end
    function C:Automation(name,on)
        if A.name=='Orbama' then
            if on and not self.claims[name] then self.claims[name]=A:Claim(name,true)==true
            elseif not on and self.claims[name] then A:Claim(name,false);self.claims[name]=nil end
            return on and self.claims[name]==true
        end
        local provider=name=='qss' and sdk.ItemManager or sdk.SummonerSpell
        local menu=provider and provider[name=='qss' and 'MenuQss' or 'MenuCleanse']
        if menu and menu.Enabled and menu.Enabled:Value() then return false end
        -- An unknown provider configuration is never guessed to be conflict-free.
        return on and self.ggAutomationApproved and self.ggAutomationApproved[name]==true
    end
    function C:MaintainClaims() if env.V2RefreshClaims then env.V2RefreshClaims()end end
    function C:Chord(modifier,key) return self:Cast(key,nil,{keys={modifier,key},type='chord',independent=false}) end
    function C:HasObservedSpell() return g.myHero.activeSpell and g.myHero.activeSpell.valid and not g.myHero.activeSpell.isAutoAttack end
    g.Callback.Add('Tick',function()
        if C:Active()then
            C:Observe();C:MaintainClaims();A:Tick()
        end
    end)
    g.Callback.Add('Load',function()C:Active()end)
    g.Callback.Add('WndMsg',function(msg,key)
        if not C:Active() or msg~=256 then return end
        for k,q in pairs(C.pending)do
            if k==key and not A:IsSending() and not (sdk.Input and sdk.Input.LastInputEdge and sdk.Input.LastInputEdge.classification~='new manual press or unmatched echo') then
                local r=A:Poll(q.id)
                if r and r.sentAt then q.ambiguous=true else A:Cancel(q.id,'manual_spell')end
            end
        end
    end)
    C.env=env;return C
end

end)()
modules.runtime=function(env,champion)
local _G,V2,SDK,Control,Callback,DelayAction,MenuElement,GGPrediction,require,os,class=env,env.V2,env.SDK,env.Control,env.Callback,env.DelayAction,env.MenuElement,env.GGPrediction,env.require,env.os,env.class
local Menu,lastQ,lastW,lastE,lastR,V2RefreshClaims
local VayneProfile=modules.vayneProfile
local CheckChatBlock,IsReady,IsValid,GetDistanceSqr,GetDistance,GetEnemyHeroes,IsUnderTurret,IsUnderTurret2,GetBuffs,HaveBuff,HasBuffContainsName,HaveBuffContainsNameNums,GetBuffData,GetEnemyCount,GetMinionCount,GetAllyCount,IsHardCC,GetHardCCDuration,IsInvulnerable,IsSlow,IsPoison,Recalling,HasInvalidDashBuff,GetMode,GetTarget,IsFacingMe,CircleCircleIntersection,FindFirstWallCollision,FindFirstWallCollisionInRectangle,IsCasting,HasItem,ShouldWait,CastSpellAOE
do
local Version = 2.04

lastQ, lastW, lastE, lastR = 0, 0, 0, 0

local blockFlag = false -- Prevent recursive callback
function CheckChatBlock(menuElement, newValue) -- Block menu toggle when chat is open
    if Game.IsChatOpen() and not blockFlag then
        blockFlag = true
        if menuElement then
            menuElement:Value(not newValue)
        end
        blockFlag = false
        return true
    end
    return false
end

function IsReady(spell)
	local spellData = myHero:GetSpellData(spell)
	return spellData.currentCd == 0 and spellData.level > 0 and spellData.mana <= myHero.mana and Game.CanUseSpell(spell) == 0
end

function IsValid(unit)
	return unit and unit.valid and unit.isTargetable and unit.alive and unit.visible and unit.networkID and unit.health > 0 and not unit.dead
end

function GetDistanceSqr(Pos1, Pos2)
	local Pos2 = Pos2 or myHero.pos
	local dx = Pos1.x - Pos2.x
	local dz = (Pos1.z or Pos1.y) - (Pos2.z or Pos2.y)
	return dx^2 + dz^2
end

function GetDistance(Pos1, Pos2)
	return math.sqrt(GetDistanceSqr(Pos1, Pos2))
end

function GetEnemyHeroes()
	local EnemyHeroes = {}
	for i = 1, Game.HeroCount() do
		local Hero = Game.Hero(i)
		if Hero.isEnemy and not Hero.dead then
			table.insert(EnemyHeroes, Hero)
		end
	end
	return EnemyHeroes
end

function IsUnderTurret(unit)
	for _, turret in ipairs(_G.SDK.ObjectManager:GetEnemyTurrets()) do
		local range = (turret.boundingRadius + 750 + unit.boundingRadius / 2)
		if not turret.dead then
			if turret.pos:DistanceTo(unit.pos) < range then
				return true
			end
		end
	end
	return false
end

function IsUnderTurret2(pos)
	for _, turret in ipairs(_G.SDK.ObjectManager:GetEnemyTurrets()) do
		local range = (turret.boundingRadius + 750)
		if not turret.dead then
			if turret.pos:DistanceTo(pos) < range then
				return true
			end
		end
	end
	return false
end

local HardCCTypes = {[5] = true, [8] = true, [9] = true, [12] = true, [23] = true, [25] = true, [29] = true, [30] = true, [35] = true}

function GetBuffs(unit)
    if not V2.validating then return _G.SDK.BuffManager:GetBuffs(unit)end
    -- Send/channel validation needs current host state, even before SDK's next Prepare.
    local out={};local count=unit and unit.buffCount
    if type(count)~='number' or count<0 or count>=10000 then return out end
    for i=0,count do
        local b=unit:GetBuff(i)
        if b and b.count and b.count>0 then
            out[#out+1]={name=b.name,type=b.type,count=b.count,stacks=b.stacks,duration=b.duration,expireTime=b.expireTime,startTime=b.startTime}
        end
    end
    return out
end

function HaveBuff(unit, buffName)
	buffName = buffName:lower()
	local buffs = GetBuffs(unit)
	for i = 1, #buffs do
		local buff = buffs[i]
		if buff.name and buff.name:lower() == buffName then
			return true
		end
	end
	return false
end

function HasBuffContainsName(unit, name)
	name = name:lower()
	local buffs = GetBuffs(unit)
	for i = 1, #buffs do
		local buff = buffs[i]
		if buff.name and buff.name:lower():find(name, 1, true) then
			return true
		end
	end
	return false
end

function HaveBuffContainsNameNums(unit, name)
	name = name:lower()
	local count = 0
	local buffs = GetBuffs(unit)
	for i = 1, #buffs do
		local buff = buffs[i]
		if buff.name and buff.name:lower():find(name, 1, true) then
			count = count + buff.count
		end
	end
	return count
end

function GetBuffData(unit, buffName)
	buffName = buffName:lower()
	local buffs = GetBuffs(unit)
	for i = 1, #buffs do
		local buff = buffs[i]
		if buff.name and buff.name:lower() == buffName then
			return true, buff
		end
	end
	return false, {type = 0, name = "", startTime = 0, expireTime = 0, duration = 0, stacks = 0, count = 0}
end

function GetEnemyCount(range, unit)
	local count = 0
	local Range = range * range
	for _, hero in ipairs(_G.SDK.ObjectManager:GetEnemyHeroes()) do
		if IsValid(hero) and GetDistanceSqr(unit, hero.pos) < Range then
			count = count + 1
		end
	end
	return count
end

function GetMinionCount(range, unit)
	local count = 0
	local Range = range * range
	for _, minion in ipairs(_G.SDK.ObjectManager:GetEnemyMinions()) do
		if IsValid(minion) and GetDistanceSqr(unit, minion.pos) < Range then
			count = count + 1
		end
	end
	return count
end

function GetAllyCount(range, unit)
	local count = 0
	local Range = range * range
	for _, hero in ipairs(_G.SDK.ObjectManager:GetAllyHeroes()) do
		if IsValid(hero) and GetDistanceSqr(unit, hero.pos) < Range then
			count = count + 1
		end
	end
	return count
end

function IsHardCC(unit)
	local buffs = GetBuffs(unit)
	for i = 1, #buffs do
		local buff = buffs[i]
		if HardCCTypes[buff.type] then
			return true
		end
	end
	return false
end

function GetHardCCDuration(unit)
	local MaxDuration = 0
	local buffs = GetBuffs(unit)
	for i = 1, #buffs do
		local buff = buffs[i]
		if HardCCTypes[buff.type] then
			local BuffDuration = buff.duration
			if BuffDuration > MaxDuration then
				MaxDuration = BuffDuration
			end
		end
	end
	return MaxDuration
end

function IsInvulnerable(unit)
	local buffs = GetBuffs(unit)
	for i = 1, #buffs do
		local buff = buffs[i]
		if buff.type == 18 then
			return true
		end
	end
	return false
end

function IsSlow(unit)
	local buffs = GetBuffs(unit)
	for i = 1, #buffs do
		local buff = buffs[i]
		if buff.type == 11 then
			return true
		end
	end
	return false
end

function IsPoison(unit)
	local buffs = GetBuffs(unit)
	for i = 1, #buffs do
		local buff = buffs[i]
		if buff.type == 13 or buff.type == 24 then
			return true
		end
	end
	return false
end

function Recalling(unit)
	local as = unit.activeSpell
	if as and as.valid and as.name:lower():find("recall") then
		return true
	end
	local buffs = GetBuffs(unit)
	for i = 1, #buffs do
		local buff = buffs[i]
		if buff.name:lower():find("recall") then
			return true
		end
	end
	return false
end

function HasInvalidDashBuff(unit)
	local buffs = GetBuffs(unit)
	for i = 1, #buffs do
		local buff = buffs[i]
		if buff.type == 30 or buff.type == 31 or buff.name == "ThreshQ" then
			return true
		end
	end
	return false
end

function GetMode()
	return _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_COMBO] and "Combo"
		or _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_HARASS] and "Harass"
		or _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_LANECLEAR] and "LaneClear"
		or _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_JUNGLECLEAR] and "LaneClear"
		or _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_LASTHIT] and "LastHit"
		or _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_FLEE] and "Flee"
		or nil
end

function GetTarget(range)
	local dmgType = myHero.ap > myHero.totalDamage and _G.SDK.DAMAGE_TYPE_MAGICAL or _G.SDK.DAMAGE_TYPE_PHYSICAL
	return _G.SDK.TargetSelector:GetTarget(range, dmgType)
end

function IsFacingMe(unit)
	local V = Vector((unit.pos - myHero.pos))
	local D = Vector(unit.dir)
	local Angle = 180 - math.deg(math.acos(V*D/(V:Len()*D:Len())))
	if math.abs(Angle) < 90 then
		return true
	end
	return false
end

function CircleCircleIntersection(c1, c2, r1, r2)
	local D = GetDistance(c1,c2)
	if D > r1 + r2 or D <= math.abs(r1 - r2) then return nil end
	local A = (r1 * r1 - r2 * r2 + D * D) / (2 * D)
	local H = math.sqrt(r1 * r1 - A * A)
	local Direction = (c2 - c1):Normalized()
	local PA = c1 + A * Direction
	local S1 = PA + H * Direction:Perpendicular()
	local S2 = PA - H * Direction:Perpendicular()
	return S1, S2
end

function FindFirstWallCollision(startPos, endPos)
	local direction = (endPos - startPos):Normalized()
	local distance = startPos:DistanceTo(endPos)
	local step = 10
	for i = 0, distance, step do
		local checkPos = startPos + direction * i
		if Game.isWall(checkPos) then
			return checkPos
		end
	end
	return nil
end

function FindFirstWallCollisionInRectangle(startPos, endPos, width)
	local direction = (endPos - startPos):Normalized()
	local distance = startPos:DistanceTo(endPos)
	local perpDirection = direction:Perpendicular()
	for i = 0, distance, 10 do
		local centerPos = startPos + direction * i
		for j = -width/2, width/2, 10 do
			local checkPos = centerPos + perpDirection * j
			if Game.isWall(checkPos) then
				return checkPos
			end
		end
	end
	return nil
end

function IsCasting()
	if myHero.activeSpell.valid then
		if myHero.activeSpell.isCharging or
			(Game.Timer() >= myHero.activeSpell.startTime and Game.Timer() <= myHero.activeSpell.castEndTime)
		then
			return true
		end
	end
	return false
end

local slots = {ITEM_1, ITEM_2, ITEM_3, ITEM_4, ITEM_5, ITEM_6}
function HasItem(unit, itemId)
	for i = 1, #slots do
		local slot = slots[i]
		local item = unit:GetItemData(slot)
		if item and item.itemID == itemId then
			return true
		end
	end
	return false
end

function ShouldWait()
	return myHero.dead or Game.IsChatOpen() or
			(_G.JustEvade and _G.JustEvade:Evading()) or
			Recalling(myHero) or
			Control.IsKeyDown(0x11) or
			Control.IsKeyDown(0x12)
end

function CastSpellAOE(spellSlot, spellData, minHitCount, source, mainTarget)
	local SpellPred = GGPrediction:SpellPrediction(spellData)
	local aoeResults = SpellPred:GetAOEPrediction(source)
	if #aoeResults == 0 then
		return false
	end
	if mainTarget then
		for i, result in ipairs(aoeResults) do
			if result.Unit.networkID == mainTarget.networkID and result.Count >= minHitCount then
				if Control.CastSpell(spellSlot, result.CastPosition) then
					return true
				end
			end
		end
	end
	table.sort(aoeResults, function(a, b) return a.Count > b.Count end)
	for i, result in ipairs(aoeResults) do
		if result.Count >= minHitCount then
			if Control.CastSpell(spellSlot, result.CastPosition) then
				return true
			end
		end
	end
	return false
end


end
env.CheckChatBlock=CheckChatBlock
env.IsReady=IsReady
env.IsValid=IsValid
env.GetDistanceSqr=GetDistanceSqr
env.GetDistance=GetDistance
env.GetEnemyHeroes=GetEnemyHeroes
env.IsUnderTurret=IsUnderTurret
env.IsUnderTurret2=IsUnderTurret2
env.GetBuffs=GetBuffs
env.HaveBuff=HaveBuff
env.HasBuffContainsName=HasBuffContainsName
env.HaveBuffContainsNameNums=HaveBuffContainsNameNums
env.GetBuffData=GetBuffData
env.GetEnemyCount=GetEnemyCount
env.GetMinionCount=GetMinionCount
env.GetAllyCount=GetAllyCount
env.IsHardCC=IsHardCC
env.GetHardCCDuration=GetHardCCDuration
env.IsInvulnerable=IsInvulnerable
env.IsSlow=IsSlow
env.IsPoison=IsPoison
env.Recalling=Recalling
env.HasInvalidDashBuff=HasInvalidDashBuff
env.GetMode=GetMode
env.GetTarget=GetTarget
env.IsFacingMe=IsFacingMe
env.CircleCircleIntersection=CircleCircleIntersection
env.FindFirstWallCollision=FindFirstWallCollision
env.FindFirstWallCollisionInRectangle=FindFirstWallCollisionInRectangle
env.IsCasting=IsCasting
env.HasItem=HasItem
env.ShouldWait=ShouldWait
env.CastSpellAOE=CastSpellAOE
do
local slots={ITEM_1,ITEM_2,ITEM_3,ITEM_4,ITEM_5,ITEM_6}
-- =====================================================================================

-- =====================================================================================
-- SECTION 3: Classic Activator (simplified, with per-item submenus)
-- =====================================================================================

local ItemKeys = {HK_ITEM_1, HK_ITEM_2, HK_ITEM_3, HK_ITEM_4, HK_ITEM_5, HK_ITEM_6}

-- Buff type ids
local BUFF_STUN, BUFF_SILENCE, BUFF_TAUNT              = 5, 7, 8
local BUFF_SLOW, BUFF_SNARE                            = 11, 12
local BUFF_SPELL_IMMUNE, BUFF_PHYS_IMMUNE              = 16, 17
local BUFF_FEAR, BUFF_CHARM, BUFF_SUPPRESS, BUFF_BLIND = 22, 23, 25, 26
local BUFF_FLEE                                        = 29
local BUFF_DAMAGE, BUFF_POISON                         = 13, 24

-- Classic item ids
local ITEM_DFG          = 773128
local ITEM_GUNBLADE     = 773146
local ITEM_CUTLASS      = 773144
local ITEM_BOTRK        = 773153
local ITEM_RANDUIN      = 773143
local ITEM_HYDRA        = 773074
local ITEM_TIAMAT       = 773077
local ITEM_TRUE_ICE     = 773092
local ITEM_SOTD         = 773131
local ITEM_YOUMUUS      = 773142
local ITEM_SHURELYAS    = 773069
local ITEM_TWIN_SHADOWS = 773023
local ITEM_OHMWRECKER   = 773056
local ITEM_LOCKET       = 773190
local ITEM_ZHONYAS      = 773157
local ITEM_SERAPH       = 773040
local ITEM_MURAMANA     = 773042
local ITEM_MIKAELS      = 773222
local ITEM_HP_POTION    = 772003
local ITEM_MANA_POTION  = 772004
local ITEM_BISCUIT      = 772009
local ITEM_FLASK        = 772041

local TrackedItems = {
	[ITEM_LOCKET] = "Defensive", [ITEM_ZHONYAS] = "Defensive", [ITEM_SERAPH] = "Defensive",
	[ITEM_RANDUIN] = "Defensive",
	[ITEM_MIKAELS] = "Utility",
	[ITEM_DFG] = "Offensive", [ITEM_GUNBLADE] = "Offensive", [ITEM_CUTLASS] = "Offensive",
	[ITEM_BOTRK] = "Offensive", [ITEM_HYDRA] = "Offensive",
	[ITEM_TIAMAT] = "Offensive", [ITEM_TRUE_ICE] = "Offensive", [ITEM_SOTD] = "Offensive",
	[ITEM_MURAMANA] = "Offensive",
	[ITEM_YOUMUUS] = "Offensive", [ITEM_SHURELYAS] = "Offensive", [ITEM_TWIN_SHADOWS] = "Offensive",
	[ITEM_OHMWRECKER] = "Offensive",
	[ITEM_HP_POTION] = "Consumable", [ITEM_MANA_POTION] = "Consumable",
	[ITEM_BISCUIT] = "Consumable", [ITEM_FLASK] = "Consumable",
}

local RegenBuffNames = {"regenerationpotion", "itemminiregenpotion", "itemcrystalflask", "flaskofcrystalwater"}

local SUM_SMITE    = "SummonerSmite_Jade"
local SUM_IGNITE   = "SummonerDot_Jade"

local SmiteCamps = {
	["s3_dragon"]       = "Dragon",
	["s3_baron"]        = "Baron",
	["s3_lizardelder"]  = "Red",
	["s3_ancientgolem"] = "Blue",
}

local DDRAGON = "https://ddragon.leagueoflegends.com/cdn/16.15.1/img/"

local ActivatorMenuLoaded = false
local ActivatorMenu = nil
local MenuLoadAttempts = 0
local MENU_LOAD_MAX_ATTEMPTS = 300
local LastItemCast = 0
local LastSummonerCast = 0
local CastDelay = 250

local OwnedItems = {}
local OwnedCategories = {Defensive = false, Utility = false, Offensive = false, Consumable = false}
local HasAnyTrackedItem = false
local LastInventoryScan = 0
local InventoryScanInterval = 500
local MuramanaLastToggle = 0
local MuramanaToggleDelay = 1100
local MURAMANA_STATE_OFF = 1
local MURAMANA_STATE_ON = 2

local SummonerSlot = {}
local SummonerHotkey = {}
local SummonersResolved = false

-- ---------------------------------------------------------------------------------
-- small helpers
-- ---------------------------------------------------------------------------------

local function ItemIcon(itemId)
	return DDRAGON .. "item/" .. itemId .. ".png"
end

local function SummonerIcon(name)
	return DDRAGON .. "spell/" .. name .. ".png"
end

local function OwnSummonerIcon()
	for name in pairs(SummonerSlot) do
		return SummonerIcon(name)
	end
	return SummonerIcon(SUM_SMITE)
end

local function SpellIcon(spellName)
	return DDRAGON .. "spell/" .. spellName .. ".png"
end

local function ChampIcon(charName)
	return DDRAGON .. "champion/" .. charName .. ".png"
end

local function HealthPercent(unit)
	return unit.maxHealth > 0 and unit.health / unit.maxHealth * 100 or 100
end

local function ManaPercent(unit)
	return unit.maxMana > 0 and unit.mana / unit.maxMana * 100 or 100
end

local function IsInBase()
	local baseX, baseY, baseZ
	if myHero.team == 100 then
		baseX, baseY, baseZ = 1044, 125, 770
	else
		baseX, baseY, baseZ = 14952, 125, 14700
	end
	return GetDistance(myHero.pos, {x = baseX, y = baseY, z = baseZ}) <= 1200
end

local function ShieldValue(unit)
	return (unit.shieldAD or 0) + (unit.shieldAP or 0)
end

local function HeroLevel(unit)
	return (unit.levelData and unit.levelData.lvl) or 1
end

local function ForEachAlly(range, fn)
	if fn(myHero) then return true end
	for _, ally in ipairs(_G.SDK.ObjectManager:GetAllyHeroes(range)) do
		if IsValid(ally) then
			if fn(ally) then return true end
		end
	end
	return false
end

local function HasBuffType(unit, buffType)
	local buffs = GetBuffs(unit)
	for i = 1, #buffs do
		if buffs[i].type == buffType then return true end
	end
	return false
end

local UndyingBuffNames = {
	["jade_kayler"]                 = true,
	["jade_zilean_chronoshift"]     = true,
	["jade_tryndamereundyingrage"]  = true,
	["jade_jaxe"]                   = true,
	["zhonyasringshield"]           = true,
}

local function HasUndyingBuff(unit)
	local buffs = GetBuffs(unit)
	for i = 1, #buffs do
		if UndyingBuffNames[buffs[i].name:lower()] then return true end
	end
	return false
end

local function HasRegenBuff(unit)
	for i = 1, #RegenBuffNames do
		if HasBuffContainsName(unit, RegenBuffNames[i]) then return true end
	end
	return false
end

local function ValidTarget(unit)
	return IsValid(unit) and not unit.isImmortal and not IsInvulnerable(unit) and not HasUndyingBuff(unit)
end

-- ---------------------------------------------------------------------------------
-- Inventory
-- ---------------------------------------------------------------------------------

local function RefreshItemCache(force)
	local now = GetTickCount()
	if not force and LastInventoryScan > 0 and now < LastInventoryScan + InventoryScanInterval then return end
	LastInventoryScan = now
	OwnedItems = {}
	OwnedCategories = {Defensive = false, Utility = false, Offensive = false, Consumable = false}
	HasAnyTrackedItem = false
	for i = 1, #slots do
		local slot = slots[i]
		local item = myHero:GetItemData(slot)
		local itemId = item and item.itemID or 0
		local category = TrackedItems[itemId]
		if category then
			OwnedItems[itemId] = {slot = slot, hotkey = ItemKeys[i], ammo = item.ammo}
			OwnedCategories[category] = true
			HasAnyTrackedItem = true
		end
	end
end

local function HasClassicItem(itemId)
	return OwnedItems[itemId] ~= nil
end

local function ItemReady(itemId)
	local cached = OwnedItems[itemId]
	if not cached then return nil end
	local item = myHero:GetItemData(cached.slot)
	if not item or item.itemID ~= itemId then
		RefreshItemCache(true)
		cached = OwnedItems[itemId]
		if not cached then return nil end
		item = myHero:GetItemData(cached.slot)
		if not item then return nil end
	end
	if item.ammo ~= nil and item.ammo == 0 and itemId == ITEM_FLASK then return nil end
	local spellData = myHero:GetSpellData(cached.slot)
	if spellData and spellData.currentCd == 0 then
		return cached.hotkey
	end
	return nil
end

local ValidateItem
local function CastItem(itemId, target, condition)
	local hotkey = ItemReady(itemId)
	if not hotkey then return false end
	local accepted=V2:Cast(hotkey,target,{owner='item:'..itemId,priority='interactive',validate=function()
        return ActivatorMenu.Enabled:Value() and ItemReady(itemId)~=nil and ValidateItem(itemId,target) and (not condition or condition())
    end})
    if accepted then V2:AfterCast(hotkey,function() LastItemCast=GetTickCount() end) end
    return accepted
end

local function IsMuramanaActive()
	local cached = OwnedItems[ITEM_MURAMANA]
	if not cached then return nil end
	local spellData = myHero:GetSpellData(cached.slot)
	if not spellData then return nil end
	if spellData.toggleState == MURAMANA_STATE_ON then return true end
	if spellData.toggleState == MURAMANA_STATE_OFF then return false end
	return nil
end

local function SetMuramanaActive(shouldBeActive)
	if not HasClassicItem(ITEM_MURAMANA) then return false end
	local isActive = IsMuramanaActive()
	if isActive == nil or isActive == shouldBeActive then return false end
	local now = GetTickCount()
	if now < MuramanaLastToggle + MuramanaToggleDelay then return false end
	if not CastItem(ITEM_MURAMANA) then return false end
	V2:AfterCast(OwnedItems[ITEM_MURAMANA].hotkey,function() MuramanaLastToggle=GetTickCount() end)
	return true
end

-- ---------------------------------------------------------------------------------
-- Summoner spells
-- ---------------------------------------------------------------------------------

local function ResolveSummoners()
	if SummonersResolved then return end
	local hotkeys = {[SUMMONER_1] = HK_SUMMONER_1, [SUMMONER_2] = HK_SUMMONER_2}
	for _, slot in ipairs({SUMMONER_1, SUMMONER_2}) do
		local data = myHero:GetSpellData(slot)
		if data and data.name and data.name ~= "" then
			SummonerSlot[data.name] = slot
			SummonerHotkey[data.name] = hotkeys[slot]
			SummonersResolved = true
		end
	end
end

local function HasSummoner(name)
	return SummonerSlot[name] ~= nil
end

local function SummonerReady(name)
	local slot = SummonerSlot[name]
	if not slot then return false end
	local data = myHero:GetSpellData(slot)
	return data and data.currentCd == 0 and Game.CanUseSpell(slot) == 0
end

local function CastSummoner(name, target, validate, context)
	local hotkey = SummonerHotkey[name]
	if not hotkey then return false end
	local accepted=V2:Cast(hotkey,target,{owner=name==SUM_SMITE and "objective_smite" or "summoner",priority=name==SUM_SMITE and "critical" or "interactive",ttl=name==SUM_SMITE and 120 or 250,context=context,
        exceptions=name==SUM_SMITE and {channel='non_interrupting_summoner'} or nil,
        validate=function()return ActivatorMenu.Enabled:Value() and SummonerReady(name)~=nil and (not validate or validate())end})
    if accepted then V2:AfterCast(hotkey,function() LastSummonerCast=GetTickCount() end) end
    return accepted
end

local function SmiteDamage()
	return 460 + 30 * HeroLevel(myHero)
end

local function IgniteDamage()
	return 50 + 20 * HeroLevel(myHero)
end

-- ---------------------------------------------------------------------------------
-- Classic item active damage
-- ---------------------------------------------------------------------------------

local BOTRK_DAMAGE_TYPE = _G.SDK.DAMAGE_TYPE_MAGICAL

local function BotrkDamage(target)
	local raw = math.max(100, target.maxHealth * 0.15)
	return _G.SDK.Damage:CalculateDamage(myHero, target, BOTRK_DAMAGE_TYPE, raw)
end

local function DfgDamage(target)
	local raw = target.maxHealth * 0.15
	return _G.SDK.Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_MAGICAL, raw)
end

local function GunbladeDamage(target)
	local raw = 150 + myHero.ap * 0.4
	return _G.SDK.Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_MAGICAL, raw)
end

local function CutlassDamage(target)
	return _G.SDK.Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_MAGICAL, 100)
end

local function LocketShield()
	return 50 + (180 / 17) * (HeroLevel(myHero) - 1)
end

local function SeraphShield()
	return 150 + myHero.mana * 0.2
end

-- ---------------------------------------------------------------------------------
-- Menu
-- ---------------------------------------------------------------------------------

local function LoadActivatorMenu()
	if ActivatorMenuLoaded then return true end
	ResolveSummoners()

	MenuLoadAttempts = MenuLoadAttempts + 1
	local allyNames = {}
	for i = 1, Game.HeroCount() do
		local hero = Game.Hero(i)
		if hero and not hero.isEnemy and not hero.isMe then
			table.insert(allyNames, hero.charName)
		end
	end

	ActivatorMenu = MenuElement({
		type = MENU,
		id = "Classic_AIO_Activator",
		name = "Classic AIO - Activator",
		leftIcon = ItemIcon(ITEM_ZHONYAS),
	})
	ActivatorMenu:MenuElement({id = "Enabled", name = "Enable Activator", value = true})

	-- Consumables
	ActivatorMenu:MenuElement({type = MENU, id = "Potions", name = "Consumables"})
	ActivatorMenu.Potions:MenuElement({id = "Enabled", name = "Auto use consumables", value = true})

	ActivatorMenu.Potions:MenuElement({type = MENU, id = "HealthPotion", name = "Health Potion", leftIcon = ItemIcon(ITEM_HP_POTION)})
	ActivatorMenu.Potions.HealthPotion:MenuElement({id = "Enabled", name = "Use Health Potion", value = true})
	ActivatorMenu.Potions.HealthPotion:MenuElement({id = "HP", name = "Self HP <= x%", value = 50, min = 0, max = 100, step = 5})

	ActivatorMenu.Potions:MenuElement({type = MENU, id = "ManaPotion", name = "Mana Potion", leftIcon = ItemIcon(ITEM_MANA_POTION)})
	ActivatorMenu.Potions.ManaPotion:MenuElement({id = "Enabled", name = "Use Mana Potion", value = true})
	ActivatorMenu.Potions.ManaPotion:MenuElement({id = "Mana", name = "Self Mana <= x%", value = 40, min = 0, max = 100, step = 5})

	ActivatorMenu.Potions:MenuElement({type = MENU, id = "Flask", name = "Crystalline Flask", leftIcon = ItemIcon(ITEM_FLASK)})
	ActivatorMenu.Potions.Flask:MenuElement({id = "Enabled", name = "Use Crystalline Flask", value = true})
	ActivatorMenu.Potions.Flask:MenuElement({id = "HP", name = "Self HP <= x%", value = 50, min = 0, max = 100, step = 5})
	ActivatorMenu.Potions.Flask:MenuElement({id = "Mana", name = "Self Mana <= x%", value = 40, min = 0, max = 100, step = 5})

	ActivatorMenu.Potions:MenuElement({type = MENU, id = "Biscuit", name = "Total Biscuit of Rejuvenation", leftIcon = ItemIcon(ITEM_BISCUIT)})
	ActivatorMenu.Potions.Biscuit:MenuElement({id = "Enabled", name = "Use Total Biscuit", value = true})
	ActivatorMenu.Potions.Biscuit:MenuElement({id = "HP", name = "Self HP <= x%", value = 50, min = 0, max = 100, step = 5})
	ActivatorMenu.Potions.Biscuit:MenuElement({id = "Mana", name = "Self Mana <= x%", value = 40, min = 0, max = 100, step = 5})

	-- Offensive
	ActivatorMenu:MenuElement({type = MENU, id = "Offensive", name = "Offensives"})
	ActivatorMenu.Offensive:MenuElement({id = "Enabled", name = "Enable Offensive Items", value = true})

	ActivatorMenu.Offensive:MenuElement({type = MENU, id = "Muramana", name = "Muramana", leftIcon = ItemIcon(ITEM_MURAMANA)})
	ActivatorMenu.Offensive.Muramana:MenuElement({id = "Enabled", name = "Use Muramana", value = true})
	ActivatorMenu.Offensive.Muramana:MenuElement({id = "Combo", name = "Use in combo", value = true})
	ActivatorMenu.Offensive.Muramana:MenuElement({id = "Mana", name = "Self Mana >= x%", value = 30, min = 0, max = 100, step = 5})
	ActivatorMenu.Offensive.Muramana:MenuElement({id = "Range", name = "Target Distance <=", value = 1200, min = 100, max = 2500, step = 50})

	ActivatorMenu.Offensive:MenuElement({type = MENU, id = "Botrk", name = "Blade of the Ruined King", leftIcon = ItemIcon(ITEM_BOTRK)})
	ActivatorMenu.Offensive.Botrk:MenuElement({id = "Enabled", name = "Use Blade of the Ruined King", value = true})
	ActivatorMenu.Offensive.Botrk:MenuElement({id = "KS", name = "Use as KillSteal", value = true})
	ActivatorMenu.Offensive.Botrk:MenuElement({id = "LifeSaver", name = "Use as LifeSaver", value = true})
	ActivatorMenu.Offensive.Botrk:MenuElement({id = "Combo", name = "Always in combo", value = true})
	ActivatorMenu.Offensive.Botrk:MenuElement({id = "Range", name = "Target Distance <=", value = 450, min = 100, max = 450, step = 25})

	ActivatorMenu.Offensive:MenuElement({type = MENU, id = "Cutlass", name = "Bilgewater Cutlass", leftIcon = ItemIcon(ITEM_CUTLASS)})
	ActivatorMenu.Offensive.Cutlass:MenuElement({id = "Enabled", name = "Use Bilgewater Cutlass", value = true})
	ActivatorMenu.Offensive.Cutlass:MenuElement({id = "KS", name = "Use as KillSteal", value = true})
	ActivatorMenu.Offensive.Cutlass:MenuElement({id = "Combo", name = "Always in combo", value = true})
	ActivatorMenu.Offensive.Cutlass:MenuElement({id = "Range", name = "Target Distance <=", value = 450, min = 100, max = 450, step = 25})

	ActivatorMenu.Offensive:MenuElement({type = MENU, id = "Gunblade", name = "Hextech Gunblade", leftIcon = ItemIcon(ITEM_GUNBLADE)})
	ActivatorMenu.Offensive.Gunblade:MenuElement({id = "Enabled", name = "Use Hextech Gunblade", value = true})
	ActivatorMenu.Offensive.Gunblade:MenuElement({id = "KS", name = "Use as KillSteal", value = true})
	ActivatorMenu.Offensive.Gunblade:MenuElement({id = "Combo", name = "Always in combo", value = true})
	ActivatorMenu.Offensive.Gunblade:MenuElement({id = "Range", name = "Target Distance <=", value = 700, min = 100, max = 700, step = 25})

	ActivatorMenu.Offensive:MenuElement({type = MENU, id = "Dfg", name = "Deathfire Grasp", leftIcon = ItemIcon(ITEM_DFG)})
	ActivatorMenu.Offensive.Dfg:MenuElement({id = "Enabled", name = "Use Deathfire Grasp", value = true})
	ActivatorMenu.Offensive.Dfg:MenuElement({id = "KS", name = "Use as KillSteal", value = true})
	ActivatorMenu.Offensive.Dfg:MenuElement({id = "Combo", name = "Always in combo", value = true})
	ActivatorMenu.Offensive.Dfg:MenuElement({id = "Range", name = "Target Distance <=", value = 750, min = 100, max = 750, step = 25})

	ActivatorMenu.Offensive:MenuElement({type = MENU, id = "Youmuus", name = "Youmuu''s Ghostblade", leftIcon = ItemIcon(ITEM_YOUMUUS)})
	ActivatorMenu.Offensive.Youmuus:MenuElement({id = "Enabled", name = "Use Youmuu''s Ghostblade", value = true})
	ActivatorMenu.Offensive.Youmuus:MenuElement({id = "KS", name = "Use as KillSteal", value = true})
	ActivatorMenu.Offensive.Youmuus:MenuElement({id = "Combo", name = "Always in combo", value = true})

	ActivatorMenu.Offensive:MenuElement({type = MENU, id = "Sotd", name = "Sword of the Divine", leftIcon = ItemIcon(ITEM_SOTD)})
	ActivatorMenu.Offensive.Sotd:MenuElement({id = "Enabled", name = "Use Sword of the Divine", value = true})
	ActivatorMenu.Offensive.Sotd:MenuElement({id = "Combo", name = "Always in combo", value = true})
	ActivatorMenu.Offensive.Sotd:MenuElement({id = "RangeBuffer", name = "Attack Range Buffer", value = 100, min = 0, max = 300, step = 25})

	ActivatorMenu.Offensive:MenuElement({type = MENU, id = "Hydra", name = "Ravenous Hydra / Tiamat", leftIcon = ItemIcon(ITEM_HYDRA)})
	ActivatorMenu.Offensive.Hydra:MenuElement({id = "Enabled", name = "Use Ravenous Hydra / Tiamat", value = true})
	ActivatorMenu.Offensive.Hydra:MenuElement({id = "Range", name = "Enemy Distance <=", value = 400, min = 100, max = 500, step = 25})
	ActivatorMenu.Offensive.Hydra:MenuElement({id = "Combo", name = "Allow in Combo", value = true})

	ActivatorMenu.Offensive:MenuElement({type = MENU, id = "TrueIce", name = "Shard of True Ice", leftIcon = ItemIcon(ITEM_TRUE_ICE)})
	ActivatorMenu.Offensive.TrueIce:MenuElement({id = "Enabled", name = "Use Shard of True Ice", value = true})
	ActivatorMenu.Offensive.TrueIce:MenuElement({id = "Range", name = "Enemy Distance <=", value = 500, min = 100, max = 750, step = 25})

	ActivatorMenu.Offensive:MenuElement({type = MENU, id = "Shurelyas", name = "Shurelya''s Reverie", leftIcon = ItemIcon(ITEM_SHURELYAS)})
	ActivatorMenu.Offensive.Shurelyas:MenuElement({id = "Enabled", name = "Use Shurelya''s Reverie", value = true})
	ActivatorMenu.Offensive.Shurelyas:MenuElement({id = "MinRange", name = "Target Distance >=", value = 650, min = 0, max = 2500, step = 50})
	ActivatorMenu.Offensive.Shurelyas:MenuElement({id = "MaxRange", name = "Target Distance <=", value = 1800, min = 0, max = 2500, step = 50})

	ActivatorMenu.Offensive:MenuElement({type = MENU, id = "TwinShadows", name = "Twin Shadows", leftIcon = ItemIcon(ITEM_TWIN_SHADOWS)})
	ActivatorMenu.Offensive.TwinShadows:MenuElement({id = "Enabled", name = "Use Twin Shadows", value = true})
	ActivatorMenu.Offensive.TwinShadows:MenuElement({id = "MinRange", name = "Target Distance >=", value = 700, min = 0, max = 2500, step = 50})
	ActivatorMenu.Offensive.TwinShadows:MenuElement({id = "MaxRange", name = "Target Distance <=", value = 2500, min = 0, max = 2500, step = 50})

	ActivatorMenu.Offensive:MenuElement({type = MENU, id = "Ohmwrecker", name = "Ohmwrecker", leftIcon = ItemIcon(ITEM_OHMWRECKER)})
	ActivatorMenu.Offensive.Ohmwrecker:MenuElement({id = "Enabled", name = "Use Ohmwrecker", value = true})
	ActivatorMenu.Offensive.Ohmwrecker:MenuElement({id = "Range", name = "Target Distance <=", value = 900, min = 100, max = 950, step = 50})

	-- Defensive
	ActivatorMenu:MenuElement({type = MENU, id = "Defensive", name = "Defensives"})
	ActivatorMenu.Defensive:MenuElement({id = "Enabled", name = "Enable Defensive Items", value = true})

	ActivatorMenu.Defensive:MenuElement({type = MENU, id = "Randuin", name = "Randuin''s Omen", leftIcon = ItemIcon(ITEM_RANDUIN)})
	ActivatorMenu.Defensive.Randuin:MenuElement({id = "Enabled", name = "Use Randuin''s Omen", value = true})
	ActivatorMenu.Defensive.Randuin:MenuElement({id = "Range", name = "Enemy Distance <=", value = 500, min = 100, max = 500, step = 25})

	ActivatorMenu.Defensive:MenuElement({type = MENU, id = "Zhonyas", name = "Zhonya''s Hourglass", leftIcon = ItemIcon(ITEM_ZHONYAS)})
	ActivatorMenu.Defensive.Zhonyas:MenuElement({id = "Enabled", name = "Use Zhonya''s Hourglass", value = true})
	ActivatorMenu.Defensive.Zhonyas:MenuElement({id = "HP", name = "Self HP <= x%", value = 30, min = 0, max = 100, step = 5})
	ActivatorMenu.Defensive.Zhonyas:MenuElement({id = "EnemyRange", name = "Enemy Detection Range", value = 800, min = 200, max = 1200, step = 50})

	ActivatorMenu.Defensive:MenuElement({type = MENU, id = "Seraph", name = "Seraph''s Embrace", leftIcon = ItemIcon(ITEM_SERAPH)})
	ActivatorMenu.Defensive.Seraph:MenuElement({id = "Enabled", name = "Use Seraph''s Embrace", value = true})
	ActivatorMenu.Defensive.Seraph:MenuElement({id = "HP", name = "Self HP <= x%", value = 50, min = 0, max = 100, step = 5})

	ActivatorMenu.Defensive:MenuElement({type = MENU, id = "Locket", name = "Locket of the Iron Solari", leftIcon = ItemIcon(ITEM_LOCKET)})
	ActivatorMenu.Defensive.Locket:MenuElement({id = "Enabled", name = "Use Locket of the Iron Solari", value = true})
	ActivatorMenu.Defensive.Locket:MenuElement({id = "HP", name = "Ally / Self HP <= x%", value = 50, min = 0, max = 100, step = 5})

	-- Cleansers
	ActivatorMenu:MenuElement({type = MENU, id = "Cleansers", name = "Cleansers"})
	ActivatorMenu.Cleansers:MenuElement({id = "Enabled", name = "Use Mikael''s Crucible", value = true})
	ActivatorMenu.Cleansers:MenuElement({id = "Delay", name = "Delay x ms", value = 0, min = 0, max = 1000, step = 50})
	ActivatorMenu.Cleansers:MenuElement({id = "HP", name = "Use only under % HP", value = 80, min = 0, max = 100, step = 5})
	ActivatorMenu.Cleansers:MenuElement({id = "MinDuration", name = "Minimum CC remaining (ms)", value = 250, min = 0, max = 2000, step = 50})
	ActivatorMenu.Cleansers:MenuElement({type = MENU, id = "BuffTypes", name = "Buff type"})
	ActivatorMenu.Cleansers.BuffTypes:MenuElement({id = "Stun", name = "Stun", value = true})
	ActivatorMenu.Cleansers.BuffTypes:MenuElement({id = "Snare", name = "Snare", value = true})
	ActivatorMenu.Cleansers.BuffTypes:MenuElement({id = "Charm", name = "Charm", value = true})
	ActivatorMenu.Cleansers.BuffTypes:MenuElement({id = "Fear", name = "Fear / Flee", value = true})
	ActivatorMenu.Cleansers.BuffTypes:MenuElement({id = "Silence", name = "Silence", value = true})
	ActivatorMenu.Cleansers.BuffTypes:MenuElement({id = "Suppression", name = "Suppression", value = true})
	ActivatorMenu.Cleansers.BuffTypes:MenuElement({id = "Taunt", name = "Taunt", value = true})
	ActivatorMenu.Cleansers.BuffTypes:MenuElement({id = "Blind", name = "Blind", value = true})
	ActivatorMenu.Cleansers.BuffTypes:MenuElement({id = "Slow", name = "Slow", value = false})
	ActivatorMenu.Cleansers:MenuElement({type = MENU, id = "Allies", name = "Mikael''s allies"})
	for _, charName in ipairs(allyNames) do
		ActivatorMenu.Cleansers.Allies:MenuElement({
			id = "Ally" .. charName,
			name = charName:gsub("^Jade_", ""),
			value = true,

		})
	end

	-- Summoners
	if HasSummoner(SUM_SMITE) or HasSummoner(SUM_IGNITE) then
		ActivatorMenu:MenuElement({type = MENU, id = "Summoners", name = "Summoners"})
		if HasSummoner(SUM_SMITE) then
			ActivatorMenu.Summoners:MenuElement({type = MENU, id = "Smite", name = "Smite", leftIcon = SummonerIcon(SUM_SMITE)})
			ActivatorMenu.Summoners.Smite:MenuElement({id = "Enabled", name = "Auto Smite objectives", toggle = true, value = false, key = string.byte("N"),
				callback = function(newValue) if CheckChatBlock(ActivatorMenu.Summoners.Smite.Enabled, newValue) then return end end})

			for _, camp in ipairs({"Dragon", "Baron", "Red", "Blue"}) do
				ActivatorMenu.Summoners.Smite:MenuElement({id = camp, name = camp, value = true})
			end
		end

		if HasSummoner(SUM_IGNITE) then
			ActivatorMenu.Summoners:MenuElement({type = MENU, id = "Ignite", name = "Ignite", leftIcon = SummonerIcon(SUM_IGNITE)})
			ActivatorMenu.Summoners.Ignite:MenuElement({id = "Enabled", name = "Use Ignite", value = true})
			ActivatorMenu.Summoners.Ignite:MenuElement({id = "Mode", name = "Trigger mode", value = 1, drop = {"KillSteal", "Enemy HP <= x%"}})
			ActivatorMenu.Summoners.Ignite:MenuElement({id = "HP", name = "Enemy HP <= x%", value = 20, min = 0, max = 100, step = 5})
			ActivatorMenu.Summoners.Ignite:MenuElement({id = "OnlyCombo", name = "Only in combo", value = true})
		end
	end
	ActivatorMenuLoaded = true
	return true
end

-- ---------------------------------------------------------------------------------
-- Cleansers (Mikael''s Crucible)
-- ---------------------------------------------------------------------------------

local function SelectedCleanseTypes()
	local menu = ActivatorMenu.Cleansers.BuffTypes
	local types = {}
	if menu.Stun:Value() then types[BUFF_STUN] = true end
	if menu.Snare:Value() then types[BUFF_SNARE] = true end
	if menu.Charm:Value() then types[BUFF_CHARM] = true end
	if menu.Fear:Value() then types[BUFF_FEAR] = true; types[BUFF_FLEE] = true end
	if menu.Silence:Value() then types[BUFF_SILENCE] = true end
	if menu.Suppression:Value() then types[BUFF_SUPPRESS] = true end
	if menu.Taunt:Value() then types[BUFF_TAUNT] = true end
	if menu.Blind:Value() then types[BUFF_BLIND] = true end
	if menu.Slow:Value() then types[BUFF_SLOW] = true end
	return types
end

local function Cleansers()
	if not ActivatorMenu.Cleansers.Enabled:Value() then return end
	if not HasClassicItem(ITEM_MIKAELS) or not ItemReady(ITEM_MIKAELS) then return end

	local hpLimit = ActivatorMenu.Cleansers.HP:Value()
	local minDuration = ActivatorMenu.Cleansers.MinDuration:Value() * 0.001
	local delay = ActivatorMenu.Cleansers.Delay:Value()
	local types = SelectedCleanseTypes()

	for _, ally in ipairs(_G.SDK.ObjectManager:GetAllyHeroes(800)) do
		local option = ActivatorMenu.Cleansers.Allies["Ally" .. ally.charName]
		if IsValid(ally) and option and option:Value() and HealthPercent(ally) < hpLimit then
			local buffs = GetBuffs(ally)
			for i = 1, #buffs do
				local buff = buffs[i]
				if types[buff.type] and (buff.duration or 0) >= minDuration then
					if delay > 0 then
						V2:Delayed("mikaels:"..ally.networkID,delay * 0.001,function()
                            if not ActivatorMenu.Enabled:Value() or not ActivatorMenu.Cleansers.Enabled:Value() or not IsValid(ally) then return end
                            for _,current in ipairs(GetBuffs(ally))do
                                if types[current.type] and (current.duration or 0)>=minDuration then CastItem(ITEM_MIKAELS,ally);return end
                            end
                        end)
					else
						CastItem(ITEM_MIKAELS, ally)
					end
					return
				end
			end
		end
	end
end

-- ---------------------------------------------------------------------------------
-- Survival - Seraph''s / Zhonya''s / Barrier for self, Locket / Heal for team
-- ---------------------------------------------------------------------------------

local function Survival()
	local defensiveOn = ActivatorMenu.Defensive.Enabled:Value()
	local enemies = GetEnemyCount(ActivatorMenu.Defensive.Zhonyas.EnemyRange:Value(), myHero.pos)
	local hpPercent = HealthPercent(myHero)

	if enemies > 0 then
		-- Seraph''s Embrace
		if defensiveOn and ActivatorMenu.Defensive.Seraph.Enabled:Value()
			and HasClassicItem(ITEM_SERAPH) and ItemReady(ITEM_SERAPH)
			and hpPercent <= ActivatorMenu.Defensive.Seraph.HP:Value() then
			if CastItem(ITEM_SERAPH) then return end
		end
		-- Zhonya''s Hourglass
		if defensiveOn and ActivatorMenu.Defensive.Zhonyas.Enabled:Value()
			and HasClassicItem(ITEM_ZHONYAS) and ItemReady(ITEM_ZHONYAS)
			and hpPercent <= ActivatorMenu.Defensive.Zhonyas.HP:Value() then
			if CastItem(ITEM_ZHONYAS) then return end
		end
	end

	-- Locket of the Iron Solari
	if defensiveOn and ActivatorMenu.Defensive.Locket.Enabled:Value()
		and HasClassicItem(ITEM_LOCKET) and ItemReady(ITEM_LOCKET) then
		local hpLimit = ActivatorMenu.Defensive.Locket.HP:Value()
		ForEachAlly(700, function(ally)
			if HealthPercent(ally) > hpLimit then return false end
			if GetDistance(ally.pos) > 700 then return false end
			return CastItem(ITEM_LOCKET)
		end)
	end
end

-- ---------------------------------------------------------------------------------
-- Potions
-- ---------------------------------------------------------------------------------

local function PotionManagement()
	if not OwnedCategories.Consumable then return end
	if not ActivatorMenu.Potions.Enabled:Value() then return end
	if HasRegenBuff(myHero) then return end
	if IsInBase() then return end

	local hp = HealthPercent(myHero)
	local mana = ManaPercent(myHero)

	-- Health Potion: low HP, any location (except base)
	if ActivatorMenu.Potions.HealthPotion.Enabled:Value()
		and hp <= ActivatorMenu.Potions.HealthPotion.HP:Value() then
		if CastItem(ITEM_HP_POTION) then return end
	end

	-- Mana Potion: low mana, any location (except base)
	if ActivatorMenu.Potions.ManaPotion.Enabled:Value()
		and mana <= ActivatorMenu.Potions.ManaPotion.Mana:Value() then
		if CastItem(ITEM_MANA_POTION) then return end
	end

	-- Crystalline Flask: low HP or low mana, any location (except base)
	if ActivatorMenu.Potions.Flask.Enabled:Value()
		and (hp <= ActivatorMenu.Potions.Flask.HP:Value() or mana <= ActivatorMenu.Potions.Flask.Mana:Value()) then
		if CastItem(ITEM_FLASK) then return end
	end

	-- Total Biscuit: low HP or low mana, any location (except base)
	if ActivatorMenu.Potions.Biscuit.Enabled:Value()
		and (hp <= ActivatorMenu.Potions.Biscuit.HP:Value() or mana <= ActivatorMenu.Potions.Biscuit.Mana:Value()) then
		if CastItem(ITEM_BISCUIT) then return end
	end
end

-- ---------------------------------------------------------------------------------
-- Offensive items
-- ---------------------------------------------------------------------------------

local function Offensive()
	local menu = ActivatorMenu.Offensive
	if not OwnedCategories.Offensive or not menu.Enabled:Value() then return end

	local combo = GetMode() == "Combo"

	-- Muramana: toggle on during combo with enough mana and a valid target in range, off otherwise.
	if HasClassicItem(ITEM_MURAMANA) then
		local range = menu.Muramana.Range:Value()
		local hasEnoughMana = ManaPercent(myHero) >= menu.Muramana.Mana:Value()
		local canActivate = menu.Muramana.Enabled:Value()
			and menu.Muramana.Combo:Value()
			and combo
			and hasEnoughMana
		local target = canActivate
			and _G.SDK.TargetSelector:GetTarget(range, _G.SDK.DAMAGE_TYPE_PHYSICAL) or nil
		local shouldActivate = target ~= nil and ValidTarget(target) and target.distance <= range or false
		if SetMuramanaActive(shouldActivate) then return end
	end

	-- Blade of the Ruined King
	if HasClassicItem(ITEM_BOTRK) and menu.Botrk.Enabled:Value() and ItemReady(ITEM_BOTRK) then
		local range = menu.Botrk.Range:Value()
		local target = _G.SDK.TargetSelector:GetTarget(range, _G.SDK.DAMAGE_TYPE_PHYSICAL)
		if IsValid(target) and target.distance <= range then
			if menu.Botrk.KS:Value() and ValidTarget(target)
				and BotrkDamage(target) > target.health then
				if CastItem(ITEM_BOTRK, target, function()return ValidTarget(target) and BotrkDamage(target)>target.health end) then return end
			end
			if menu.Botrk.LifeSaver:Value()
				and myHero.health < myHero.maxHealth * 0.5 then
				if CastItem(ITEM_BOTRK, target, function()return myHero.health<myHero.maxHealth*.5 end) then return end
			end
			if menu.Botrk.Combo:Value() and combo then
				if CastItem(ITEM_BOTRK, target, function()return GetMode()=="Combo" end) then return end
			end
		end
	end

	-- Deathfire Grasp
	if HasClassicItem(ITEM_DFG) and menu.Dfg.Enabled:Value() and ItemReady(ITEM_DFG) then
		local range = menu.Dfg.Range:Value()
		local target = _G.SDK.TargetSelector:GetTarget(range, _G.SDK.DAMAGE_TYPE_MAGICAL)
		if IsValid(target) and target.distance <= range then
			if menu.Dfg.KS:Value() and ValidTarget(target)
				and DfgDamage(target) > target.health then
				if CastItem(ITEM_DFG, target, function()return ValidTarget(target) and DfgDamage(target)>target.health end) then return end
			end
			if menu.Dfg.Combo:Value() and combo then
				if CastItem(ITEM_DFG, target, function()return GetMode()=="Combo" end) then return end
			end
		end
	end

	-- Hextech Gunblade
	if HasClassicItem(ITEM_GUNBLADE) and menu.Gunblade.Enabled:Value() and ItemReady(ITEM_GUNBLADE) then
		local range = menu.Gunblade.Range:Value()
		local target = _G.SDK.TargetSelector:GetTarget(range, _G.SDK.DAMAGE_TYPE_MAGICAL)
		if IsValid(target) and target.distance <= range then
			if menu.Gunblade.KS:Value() and ValidTarget(target)
				and GunbladeDamage(target) > target.health then
				if CastItem(ITEM_GUNBLADE, target, function()return ValidTarget(target) and GunbladeDamage(target)>target.health end) then return end
			end
			if menu.Gunblade.Combo:Value() and combo then
				if CastItem(ITEM_GUNBLADE, target, function()return GetMode()=="Combo" end) then return end
			end
		end
	end

	-- Bilgewater Cutlass
	if HasClassicItem(ITEM_CUTLASS) and menu.Cutlass.Enabled:Value() and ItemReady(ITEM_CUTLASS) then
		local range = menu.Cutlass.Range:Value()
		local target = _G.SDK.TargetSelector:GetTarget(range, _G.SDK.DAMAGE_TYPE_MAGICAL)
		if IsValid(target) and target.distance <= range then
			if menu.Cutlass.KS:Value() and ValidTarget(target)
				and CutlassDamage(target) > target.health then
				if CastItem(ITEM_CUTLASS, target, function()return ValidTarget(target) and CutlassDamage(target)>target.health end) then return end
			end
			if menu.Cutlass.Combo:Value() and combo then
				if CastItem(ITEM_CUTLASS, target, function()return GetMode()=="Combo" end) then return end
			end
		end
	end

	-- Shard of True Ice
	if HasClassicItem(ITEM_TRUE_ICE) and menu.TrueIce.Enabled:Value() and combo
		and GetEnemyCount(menu.TrueIce.Range:Value(), myHero.pos) > 0 then
		if CastItem(ITEM_TRUE_ICE, myHero) then return end
	end

	-- Youmuu''s Ghostblade
	if HasClassicItem(ITEM_YOUMUUS) and menu.Youmuus.Enabled:Value() and ItemReady(ITEM_YOUMUUS) then
		local target = _G.SDK.Orbwalker:GetTarget()
		if target and target.type == Obj_AI_Hero and IsValid(target) then
			if menu.Youmuus.KS:Value() and target.health < myHero.maxHealth then
				if CastItem(ITEM_YOUMUUS) then return end
			end
			if menu.Youmuus.Combo:Value() and combo then
				if CastItem(ITEM_YOUMUUS) then return end
			end
		end
	end

	-- Sword of the Divine
	if HasClassicItem(ITEM_SOTD) and menu.Sotd.Enabled:Value() and combo and ItemReady(ITEM_SOTD) then
		local target = _G.SDK.Orbwalker:GetTarget()
		if target and target.type == Obj_AI_Hero and IsValid(target) then
			local range = myHero.range + myHero.boundingRadius + target.boundingRadius + menu.Sotd.RangeBuffer:Value()
			if target.distance <= range then
				if CastItem(ITEM_SOTD) then return end
			end
		end
	end

	-- Ravenous Hydra / Tiamat (combo only: current orbwalker target in range)
	if menu.Hydra.Enabled:Value() then
		local range = menu.Hydra.Range:Value()
		if combo and menu.Hydra.Combo:Value() then
			local target = _G.SDK.Orbwalker:GetTarget()
			if target ~= nil and target.type == Obj_AI_Hero and IsValid(target)
				and target.distance <= range then
				if HasClassicItem(ITEM_HYDRA) then
					if CastItem(ITEM_HYDRA) then return end
				elseif HasClassicItem(ITEM_TIAMAT) then
					if CastItem(ITEM_TIAMAT) then return end
				end
			end
		end
	end

	-- Shurelya''s Reverie / Twin Shadows / Ohmwrecker
	if combo then
		local target = GetTarget(2500)
		if IsValid(target) then
			local distance = target.distance
			if HasClassicItem(ITEM_SHURELYAS) and menu.Shurelyas.Enabled:Value()
				and distance >= math.min(menu.Shurelyas.MinRange:Value(), menu.Shurelyas.MaxRange:Value())
				and distance <= math.max(menu.Shurelyas.MinRange:Value(), menu.Shurelyas.MaxRange:Value()) then
				if CastItem(ITEM_SHURELYAS) then return end
			end
			if HasClassicItem(ITEM_TWIN_SHADOWS) and menu.TwinShadows.Enabled:Value()
				and distance >= math.min(menu.TwinShadows.MinRange:Value(), menu.TwinShadows.MaxRange:Value())
				and distance <= math.max(menu.TwinShadows.MinRange:Value(), menu.TwinShadows.MaxRange:Value()) then
				if CastItem(ITEM_TWIN_SHADOWS) then return end
			end
			if HasClassicItem(ITEM_OHMWRECKER) and menu.Ohmwrecker.Enabled:Value()
				and distance <= menu.Ohmwrecker.Range:Value() and IsUnderTurret(myHero) then
				if CastItem(ITEM_OHMWRECKER) then return end
			end
		end
	end
end

-- ---------------------------------------------------------------------------------
-- Randuin''s Omen
-- ---------------------------------------------------------------------------------

local function Defensive()
	if not OwnedCategories.Defensive or not ActivatorMenu.Defensive.Enabled:Value() then return end
	if ActivatorMenu.Defensive.Randuin.Enabled:Value() and HasClassicItem(ITEM_RANDUIN)
		and GetEnemyCount(ActivatorMenu.Defensive.Randuin.Range:Value(), myHero.pos) > 0 then
		CastItem(ITEM_RANDUIN)
	end
end

-- ---------------------------------------------------------------------------------
-- Smite
-- ---------------------------------------------------------------------------------

local function Smite()
	if not HasSummoner(SUM_SMITE) or not ActivatorMenu.Summoners.Smite then return end
	if not ActivatorMenu.Summoners.Smite.Enabled:Value() then return end
	if not SummonerReady(SUM_SMITE) then return end

	local damage = SmiteDamage()
	for _, mob in ipairs(_G.SDK.ObjectManager:GetMonsters(760, true)) do
		local camp = SmiteCamps[mob.charName:lower()]
		if camp and ActivatorMenu.Summoners.Smite[camp]:Value() and mob.health <= damage then
			if mob.distance <= 760 + myHero.boundingRadius + mob.boundingRadius then
				CastSummoner(SUM_SMITE, mob,function()
                    return IsValid(mob) and SmiteCamps[mob.charName:lower()]==camp
                        and ActivatorMenu.Summoners.Smite.Enabled:Value() and ActivatorMenu.Summoners.Smite[camp]:Value()
                        and mob.health<=SmiteDamage() and GetDistance(mob.pos,myHero.pos)<=760+myHero.boundingRadius+mob.boundingRadius
                end)
				return
			end
		end
	end
end


-- ---------------------------------------------------------------------------------
-- Ignite
-- ---------------------------------------------------------------------------------

local function Ignite()
	if not HasSummoner(SUM_IGNITE) or not ActivatorMenu.Summoners.Ignite then return end
	if not ActivatorMenu.Summoners.Ignite.Enabled:Value() or not SummonerReady(SUM_IGNITE) then return end

	local combo = GetMode() == "Combo"
	if ActivatorMenu.Summoners.Ignite.OnlyCombo:Value() and not combo then return end

	local damage = IgniteDamage()
	local mode = ActivatorMenu.Summoners.Ignite.Mode:Value()
	local hpThreshold = ActivatorMenu.Summoners.Ignite.HP:Value()
	for _, enemy in ipairs(_G.SDK.ObjectManager:GetEnemyHeroes(600)) do
		if ValidTarget(enemy) then
			-- Mode 1: KillSteal
			if mode == 1 and enemy.health <= damage then
				if CastSummoner(SUM_IGNITE, enemy,function()
                    local m=ActivatorMenu.Summoners.Ignite
                    return m.Enabled:Value() and ValidTarget(enemy) and GetDistance(enemy.pos,myHero.pos)<=600
                        and (not m.OnlyCombo:Value() or GetMode()=='Combo')
                        and (mode==1 and enemy.health<=IgniteDamage() or mode==2 and HealthPercent(enemy)<=m.HP:Value())
                end,ActivatorMenu.Summoners.Ignite.OnlyCombo:Value() and V2:ModeContext('Combo') or nil) then return end
			end
			-- Mode 2: Enemy HP <= x%
			if mode == 2 and HealthPercent(enemy) <= hpThreshold then
				if CastSummoner(SUM_IGNITE, enemy,function()
                    local m=ActivatorMenu.Summoners.Ignite
                    return m.Enabled:Value() and ValidTarget(enemy) and GetDistance(enemy.pos,myHero.pos)<=600
                        and (not m.OnlyCombo:Value() or GetMode()=='Combo')
                        and (mode==1 and enemy.health<=IgniteDamage() or mode==2 and HealthPercent(enemy)<=m.HP:Value())
                end,ActivatorMenu.Summoners.Ignite.OnlyCombo:Value() and V2:ModeContext('Combo') or nil) then return end
			end
		end
	end
end

-- ---------------------------------------------------------------------------------
-- Tick
-- ---------------------------------------------------------------------------------

local function ActivatorTick()
	if not LoadActivatorMenu() then return end
	if not ActivatorMenu.Enabled:Value() then return end
	if myHero.dead or Game.IsChatOpen() then return end

	RefreshItemCache()

	Smite()
	Cleansers()
	Survival()
	Ignite()

	if ShouldWait() then return end
	if GetTickCount() < LastItemCast + CastDelay then return end
	if GetTickCount() < LastSummonerCast + CastDelay then return end

	if ActivatorMenu.Potions.Enabled:Value() then
		PotionManagement()
	end

	if not HasAnyTrackedItem then return end
	Offensive()
	Defensive()
end


-- Fresh item checks operate on the already selected item/target; never rerun ActivatorTick.
ValidateItem=function(id,target)
    local defense=ActivatorMenu.Defensive;local offense=ActivatorMenu.Offensive
    if id==ITEM_MIKAELS then
        local m=ActivatorMenu.Cleansers;local option=target and m.Allies['Ally'..target.charName]
        if not m.Enabled:Value() or not target or not IsValid(target) or not option or not option:Value() or HealthPercent(target)>=m.HP:Value() or GetDistance(target.pos,myHero.pos)>800 then return false end
        local types=SelectedCleanseTypes();for _,buff in ipairs(GetBuffs(target))do if types[buff.type] and (buff.duration or 0)>=m.MinDuration:Value()*.001 then return true end end;return false
    end
    if id==ITEM_SERAPH then return defense.Enabled:Value() and defense.Seraph.Enabled:Value() and HealthPercent(myHero)<=defense.Seraph.HP:Value()end
    if id==ITEM_ZHONYAS then return defense.Enabled:Value() and defense.Zhonyas.Enabled:Value() and HealthPercent(myHero)<=defense.Zhonyas.HP:Value() and GetEnemyCount(defense.Zhonyas.EnemyRange:Value(),myHero.pos)>0 end
    if id==ITEM_LOCKET then return defense.Enabled:Value() and defense.Locket.Enabled:Value() and ForEachAlly(600,function(ally)return HealthPercent(ally)<=defense.Locket.HP:Value()end)end
    if id==ITEM_RANDUIN then return defense.Enabled:Value() and defense.Randuin.Enabled:Value() and GetEnemyCount(defense.Randuin.Range:Value(),myHero.pos)>0 end
    local potion=({[ITEM_HP_POTION]='HealthPotion',[ITEM_MANA_POTION]='ManaPotion',[ITEM_FLASK]='Flask',[ITEM_BISCUIT]='Biscuit'})[id]
    if potion then
        local m=ActivatorMenu.Potions[potion]
        return ActivatorMenu.Potions.Enabled:Value() and m.Enabled:Value() and not IsInBase() and not HasRegenBuff(myHero)
            and ((m.HP and HealthPercent(myHero)<=m.HP:Value()) or (m.Mana and ManaPercent(myHero)<=m.Mana:Value()))
    end
    local names={[ITEM_BOTRK]='Botrk',[ITEM_DFG]='Dfg',[ITEM_GUNBLADE]='Gunblade',[ITEM_CUTLASS]='Cutlass',[ITEM_TRUE_ICE]='TrueIce',[ITEM_YOUMUUS]='Youmuus',[ITEM_SOTD]='Sotd',[ITEM_SHURELYAS]='Shurelyas',[ITEM_TWIN_SHADOWS]='TwinShadows',[ITEM_OHMWRECKER]='Ohmwrecker',[ITEM_HYDRA]='Hydra',[ITEM_TIAMAT]='Hydra',[ITEM_MURAMANA]='Muramana'}
    local m=names[id] and offense[names[id]]
    if not m then return false end
    if id~=ITEM_MURAMANA and (not offense.Enabled:Value() or not m.Enabled:Value())then return false end
    if target and target~=myHero and (not IsValid(target) or m.Range and GetDistance(target.pos,myHero.pos)>m.Range:Value())then return false end
    return true
end

V2RefreshClaims=function()
    -- The pinned Classic activator implements Mikaels, not QSS or summoner Cleanse.
    -- It therefore takes no claim for functions it does not implement.
end
Callback.Add("Tick",function()
    V2:RunDecision('Activator',ActivatorTick)
end)

end
env.V2RefreshClaims=V2RefreshClaims
if champion=="Ahri" then
local Version = 1.01


local ClassicAhri=class("ClassicAhri")

function ClassicAhri:__init()		 

	self:LoadMenu()
	Callback.Add("Draw", function() self:Draw() end)
	Callback.Add("Tick", function() self:OnTick() end)
	_G.SDK.Orbwalker:OnPreAttack(function(...) self:OnPreAttack(...) end)
	self.QSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 100, Range = 970, Speed = 1400, Collision = true, CollisionTypes = {GGPrediction.COLLISION_YASUOWALL}}
	self.ESpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 60, Range = 975, Speed = 1550, Collision = true, CollisionTypes = {GGPrediction.COLLISION_MINION, GGPrediction.COLLISION_YASUOWALL}}
	self.selectedTarget = nil
	self.targetTimer = 0
end

function ClassicAhri:LoadMenu()
	local championIcon = "http://ddragon.leagueoflegends.com/cdn/16.15.1/img/champion/"..myHero.charName..".png"
	Menu = MenuElement({type = MENU, id = "Classic_AIO_"..myHero.charName, name = "Classic AIO - "..myHero.charName.." V: "..Version, leftIcon = championIcon})
	Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
	Menu.Combo:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "Qrange", name = "Use Q|Range", value = 900, min = 600, max = 970, step = 10})
	Menu.Combo:MenuElement({id = "W", name = "Use W", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "E", name = "Use E", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "Erange", name = "Use E|Range", value = 900, min = 600, max = 975, step = 10})

	Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
	Menu.Harass:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	Menu.Harass:MenuElement({id = "Qrange", name = "Use Q|Range", value = 900, min = 600, max = 970, step = 10})
	Menu.Harass:MenuElement({id = "W", name = "Use W", toggle = true, value = true})
	Menu.Harass:MenuElement({id = "E", name = "Use E", toggle = true, value = false})
	Menu.Harass:MenuElement({id = "Erange", name = "Use E|Range", value = 900, min = 600, max = 975, step = 10})

	Menu:MenuElement({type = MENU, id = "Clear", name = "Clear"})
	Menu.Clear:MenuElement({id = "Enabled", name = "Use Spell Farm (Mouse Scroll)", toggle = true, value = false, key = 4, callback = function(v) CheckChatBlock(Menu.Clear.Enabled, v) end})
	Menu.Clear:MenuElement({id = "Q", name = "Use Q | Minions >=", value = 3, min = 1, max = 8, step = 1})
	Menu.Clear:MenuElement({id = "W", name = "Use W | Nearby Minions >=", value = 3, min = 1, max = 6, step = 1})
	Menu.Clear:MenuElement({id = "JungleQ", name = "Use Q In Jungle", value = true})
	Menu.Clear:MenuElement({id = "JungleW", name = "Use W In Jungle", value = true})
	Menu.Clear:MenuElement({id = "Mana", name = "Mana Percent >=", value = 30, min = 0, max = 100, step = 5})
	
	Menu:MenuElement({type = MENU, id = "Misc", name = "Misc"})
	Menu.Misc:MenuElement({id = "EAntiDash", name = "Auto E AntiDash", value = true})

	Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
	Menu.Draw:MenuElement({id = "Q", name = "[Q] Range", toggle = true, value = false})
	Menu.Draw:MenuElement({id = "E", name = "[E] Range", toggle = true, value = false})
	Menu.Draw:MenuElement({id = "Farm", name = "Draw Farm Status", value = true})
end

function ClassicAhri:OnTick()
	if ShouldWait() then
		return
	end
	if IsCasting() then return end
	self:AutoE()
	local Mode = GetMode()
	if Mode == "Combo" then
		self:Combo()
	elseif Mode == "Harass" then
		self:Harass()
	elseif Mode == "LaneClear" then
		self:Clear()
	end
end

function ClassicAhri:OnPreAttack(args)
	if GetMode() == "Combo" and IsValid(args.Target) then
		local qReady = Menu.Combo.Q:Value() and IsReady(_Q) and args.Target.distance <= Menu.Combo.Qrange:Value()
		local eReady = Menu.Combo.E:Value() and IsReady(_E) and args.Target.distance <= Menu.Combo.Erange:Value()
		if qReady or eReady then
			args.Process = false
		end
	end
end

function ClassicAhri:AutoE()
	if Menu.Misc.EAntiDash:Value() and IsReady(_E) then
		local enemies = _G.SDK.ObjectManager:GetEnemyHeroes(self.ESpell.Range)
		for i = 1, #enemies do
			local enemy = enemies[i]
			local path = enemy.pathing
			if path and path.isDashing and enemy.posTo then
				if myHero.pos:DistanceTo(enemy.posTo) < myHero.pos:DistanceTo(enemy.pos) then
					self:CastGGPred(HK_E, enemy)
					break
				end
			end
		end
	end
end
	
function ClassicAhri:Combo()
	if Menu.Combo.W:Value() and IsReady(_W) and lastW + 250 < GetTickCount() then
		local target = GetTarget(700)
		if IsValid(target) then
			Control.CastSpell(HK_W)
			V2:AfterCast(HK_W, function() lastW = GetTickCount() end)
		end
	end
	if Menu.Combo.E:Value() and IsReady(_E) then
		local target = GetTarget(Menu.Combo.Erange:Value())
		if IsValid(target) and target.pos:ToScreen().onScreen then
			self:CastGGPred(HK_E, target)
			V2:AfterCast(HK_E,function()self.targetTimer=os.clock();self.selectedTarget=target end)
		end
	end
	if Menu.Combo.Q:Value() and IsReady(_Q) then
		local target = GetTarget(Menu.Combo.Qrange:Value())
		if os.clock() < self.targetTimer + 3 and IsValid(self.selectedTarget) and self.selectedTarget.distance <= Menu.Combo.Qrange:Value() then
			target = self.selectedTarget
		end
		if IsValid(target) and target.pos:ToScreen().onScreen then
			self:CastGGPred(HK_Q, target)
		end
	end
end

function ClassicAhri:Harass()
	if Menu.Harass.W:Value() and IsReady(_W) and lastW + 250 < GetTickCount() then
		local target = GetTarget(700)
		if IsValid(target) then
			Control.CastSpell(HK_W)
			V2:AfterCast(HK_W, function() lastW = GetTickCount() end)
		end
	end
	if Menu.Harass.E:Value() and IsReady(_E) then
		local target = GetTarget(Menu.Harass.Erange:Value())
		if IsValid(target) and target.pos:ToScreen().onScreen then
			self:CastGGPred(HK_E, target)
			V2:AfterCast(HK_E,function()self.targetTimer=os.clock();self.selectedTarget=target end)
		end
	end
	if Menu.Harass.Q:Value() and IsReady(_Q) then
		local target = GetTarget(Menu.Harass.Qrange:Value())
		if os.clock() < self.targetTimer + 3 and IsValid(self.selectedTarget) and self.selectedTarget.distance < Menu.Harass.Qrange:Value() then
			target = self.selectedTarget
		end
		if IsValid(target) and target.pos:ToScreen().onScreen then
			self:CastGGPred(HK_Q, target)
		end
	end
end

function ClassicAhri:Clear()
	if not Menu.Clear.Enabled:Value() then return end
	if myHero.maxMana > 0 and myHero.mana / myHero.maxMana * 100 < Menu.Clear.Mana:Value() then return end
	if not IsUnderTurret(myHero) then
		local minions = _G.SDK.ObjectManager:GetEnemyMinions(self.QSpell.Range)
		if Menu.Clear.Q:Value() > 0 and IsReady(_Q) then
			for _, minion in ipairs(minions) do
				if IsValid(minion) and minion.team ~= 300 and minion.pos2D.onScreen and minion.distance <= self.QSpell.Range and GetMinionCount(180, minion.pos) >= Menu.Clear.Q:Value() then
					Control.CastSpell(HK_Q, minion.pos)
					return
				end
			end
		end
		if Menu.Clear.W:Value() > 0 and IsReady(_W) and lastW + 250 < GetTickCount() and GetMinionCount(700, myHero.pos) >= Menu.Clear.W:Value() then
			Control.CastSpell(HK_W)
			V2:AfterCast(HK_W, function() lastW = GetTickCount() end)
			return
		end
	end
	local monsters = _G.SDK.ObjectManager:GetMonsters(self.QSpell.Range)
	table.sort(monsters, function(a, b) return a.maxHealth > b.maxHealth end)
	local target = monsters[1]
	if not IsValid(target) or not target.pos2D.onScreen then return end
	if Menu.Clear.JungleQ:Value() and IsReady(_Q) then
		Control.CastSpell(HK_Q, target.pos)
		return
	end
	if Menu.Clear.JungleW:Value() and IsReady(_W) and lastW + 250 < GetTickCount() and target.distance <= 700 then
		Control.CastSpell(HK_W)
		V2:AfterCast(HK_W, function() lastW = GetTickCount() end)
	end
end

function ClassicAhri:CastGGPred(spell, target)
	if spell == HK_Q then
		local QPrediction = GGPrediction:SpellPrediction(self.QSpell)
		QPrediction:GetPrediction(target, myHero)
		if QPrediction:CanHit(3) then
			Control.CastSpell(HK_Q, QPrediction.CastPosition)
		end
	elseif spell == HK_E then
		local EPrediction = GGPrediction:SpellPrediction(self.ESpell)
		EPrediction:GetPrediction(target, myHero)
		if EPrediction:CanHit(3) then
			Control.CastSpell(HK_E, EPrediction.CastPosition)
		end
	end
end

function ClassicAhri:Draw()
	if myHero.dead then return end

	if Menu.Draw.Farm:Value() then
		Draw.Text(Menu.Clear.Enabled:Value() and "Spell Farm: On" or "Spell Farm: Off", 16, myHero.pos2D.x - 55, myHero.pos2D.y + 60, Draw.Color(200, 242, 120, 34))
	end
	if Menu.Draw.Q:Value() and IsReady(_Q) then
		Draw.Circle(myHero.pos, self.QSpell.Range, 1, Draw.Color(255, 66, 244, 113))
	end
	if Menu.Draw.E:Value() and IsReady(_E) then
		Draw.Circle(myHero.pos, self.ESpell.Range, 1, Draw.Color(255, 244, 238, 66))
	end
end


-- Explicit request context. Nested helpers inherit their caller's context.
V2:RegisterPolicy({
    methods={
        AutoE=function()return {priority='interactive'}end,
        OnPreAttack=function()local mode=GetMode();return mode and V2:ModeContext(mode) or nil end,

        Combo=function()return V2:ModeContext("Combo")end,
        Harass=function()return V2:ModeContext("Harass")end,
        Clear=function()return V2:ModeContext("LaneClear")end,
    },
    exceptions={non_interrupting_summoner=true},
    channel=function(self,q)return not (myHero.activeSpell and myHero.activeSpell.valid and myHero.activeSpell.isChanneling) end,
    validate=function(self,q,slot,resolved)
        if slot==_R and q.kind=='world' then return not Game.isWall(Vector((resolved and resolved.position)or q.target))end
        return true
    end,
})

ClassicAhri()

end
if champion=="Akali" then
local Version = 1.01


local ClassicAkali=class("ClassicAkali")

function ClassicAkali:__init()

	self.QRange, self.WRange, self.ERange, self.RRange = 550, 700, 325, 675
	self:LoadMenu()
	Callback.Add("Tick", function() self:Tick() end)
	Callback.Add("Draw", function() self:Draw() end)
end

function ClassicAkali:LoadMenu()
	local icon = "http://ddragon.leagueoflegends.com/cdn/16.16.1/img/champion/Akali.png"
	Menu = MenuElement({ type = MENU, id = "Classic_AIO_" .. myHero.charName, name = "Classic AIO - " .. myHero.charName .. " V: " .. Version, leftIcon = icon })
	Menu:MenuElement({ type = MENU, id = "Combo", name = "Combo" })
	for _, spell in ipairs({ "Q", "W", "E", "R" }) do
		Menu.Combo:MenuElement({ id = spell, name = "Use " .. spell, value = true })
	end
	Menu.Combo:MenuElement({ id = "WHP", name = "Use W When HP <= x%", value = 55, min = 0, max = 100, step = 5 })
	Menu.Combo:MenuElement({ id = "RReserve", name = "Keep R Charges", value = 1, min = 0, max = 2, step = 1 })
	Menu.Combo:MenuElement({ id = "SafeR", name = "Do Not R Under Enemy Turret", value = true })

	Menu:MenuElement({ type = MENU, id = "Harass", name = "Harass" })
	Menu.Harass:MenuElement({ id = "Q", name = "Use Q", value = true })
	Menu.Harass:MenuElement({ id = "E", name = "Use E", value = true })
	Menu.Harass:MenuElement({ id = "Mana", name = "Energy Percent >=", value = 40, min = 0, max = 100, step = 5 })

	Menu:MenuElement({ type = MENU, id = "Clear", name = "Clear" })
	Menu.Clear:MenuElement({ id = "Enabled", name = "Use Spell Farm (Mouse Scroll)", toggle = true, value = false, key = 4, callback = function(v) CheckChatBlock(Menu.Clear.Enabled, v) end })
	Menu.Clear:MenuElement({ id = "Q", name = "Use Q Last Hit / Jungle", value = true })
	Menu.Clear:MenuElement({ id = "E", name = "Use E | Nearby Units >=", value = 3, min = 1, max = 8, step = 1 })
	Menu.Clear:MenuElement({ id = "Mana", name = "Energy Percent >=", value = 30, min = 0, max = 100, step = 5 })

	Menu:MenuElement({ type = MENU, id = "KillSteal", name = "KillSteal" })
	for _, spell in ipairs({ "Q", "E", "R" }) do
		Menu.KillSteal:MenuElement({ id = spell, name = "Auto " .. spell, value = true })
	end

	Menu:MenuElement({ type = MENU, id = "Flee", name = "Flee" })
	Menu.Flee:MenuElement({ id = "W", name = "Use W", value = true })
	Menu.Flee:MenuElement({ id = "R", name = "Use R Through Enemy Unit", value = false })
	Menu.Flee:MenuElement({ id = "SafeR", name = "Do Not R Under Enemy Turret", value = true })

	Menu:MenuElement({ type = MENU, id = "Draw", name = "Draw" })
	for _, spell in ipairs({ "Q", "W", "E", "R" }) do
		Menu.Draw:MenuElement({ id = spell, name = "Draw " .. spell .. " Range", value = false })
	end
	Menu.Draw:MenuElement({ id = "Farm", name = "Draw Farm Status", value = true })
end

function ClassicAkali:ResourcePercent()
	return myHero.maxMana > 0 and myHero.mana / myHero.maxMana * 100 or 100
end

function ClassicAkali:RAmmo()
	return myHero:GetSpellData(_R).ammo or 0
end

function ClassicAkali:Marked(target)
	return HaveBuff(target, "Jade_AkaliQ")
end

function ClassicAkali:InAutoAttackRange(target)
	if _G.SDK.Data and _G.SDK.Data.IsInAutoAttackRange then
		return _G.SDK.Data:IsInAutoAttackRange(myHero, target)
	end
	local range = (myHero.range or 125) + (myHero.boundingRadius or 65) + (target.boundingRadius or 65)
	return myHero.pos:DistanceTo(target.pos) <= range
end

function ClassicAkali:CanR(target, safe)
	if not IsValid(target) or myHero.pos:DistanceTo(target.pos) > self.RRange then return false end
	return not safe or IsUnderTurret(myHero) or not IsUnderTurret2(target.pos)
end

function ClassicAkali:Tick()
	if ShouldWait() or IsCasting() then return end
	self:KillSteal()
	local mode = GetMode()
	if mode == "Combo" then
		self:Combo()
	elseif mode == "Harass" then
		self:Harass()
	elseif mode == "LaneClear" then
		self:Clear()
	elseif mode == "Flee" then
		self:Flee()
	end
end

function ClassicAkali:Combo()
	local target = GetTarget(self.RRange)
	if not IsValid(target) or not target.pos2D.onScreen then return end

	local hp = myHero.maxHealth > 0 and myHero.health / myHero.maxHealth * 100 or 100
	if Menu.Combo.W:Value() and IsReady(_W) and hp <= Menu.Combo.WHP:Value() and target.distance <= 500 then
		Control.CastSpell(HK_W, myHero.pos)
		return
	end
	if Menu.Combo.Q:Value() and IsReady(_Q) and target.distance <= self.QRange and not self:Marked(target) then
		Control.CastSpell(HK_Q, target)
		return
	end
	if self:Marked(target) then
		if self:InAutoAttackRange(target) then return end
		if Menu.Combo.R:Value() and IsReady(_R) and self:RAmmo() > Menu.Combo.RReserve:Value() and self:CanR(target, Menu.Combo.SafeR:Value()) then
			Control.CastSpell(HK_R, target)
			return
		end
	end
	if Menu.Combo.E:Value() and IsReady(_E) and target.distance <= self.ERange then
		Control.CastSpell(HK_E)
		return
	end
	if Menu.Combo.R:Value() and IsReady(_R) and self:RAmmo() > Menu.Combo.RReserve:Value() and self:CanR(target, Menu.Combo.SafeR:Value()) then
		Control.CastSpell(HK_R, target)
	end
end

function ClassicAkali:Harass()
	if self:ResourcePercent() < Menu.Harass.Mana:Value() then return end
	local target = GetTarget(self.QRange)
	if not IsValid(target) or not target.pos2D.onScreen then return end
	if Menu.Harass.Q:Value() and IsReady(_Q) and not self:Marked(target) then
		Control.CastSpell(HK_Q, target)
		return
	end
	if Menu.Harass.E:Value() and IsReady(_E) and target.distance <= self.ERange then Control.CastSpell(HK_E) end
end

function ClassicAkali:Clear()
	if not Menu.Clear.Enabled:Value() or self:ResourcePercent() < Menu.Clear.Mana:Value() or IsUnderTurret(myHero) then return end
	local minions = _G.SDK.ObjectManager:GetEnemyMinions(self.QRange)
	local monsters = _G.SDK.ObjectManager:GetMonsters(self.QRange)
	local nearby = GetMinionCount(self.ERange, myHero.pos)
	for _, monster in ipairs(monsters) do
		if IsValid(monster) and monster.distance <= self.ERange then nearby = nearby + 1 end
	end
	if IsReady(_E) and nearby >= Menu.Clear.E:Value() then
		Control.CastSpell(HK_E)
		return
	end
	if Menu.Clear.Q:Value() and IsReady(_Q) then
		for _, minion in ipairs(minions) do
			local health = IsValid(minion) and _G.SDK.HealthPrediction:GetPrediction(minion, 0.25) or 0
			if health > 0 and self:GetQDmg(minion) >= health then
				Control.CastSpell(HK_Q, minion)
				return
			end
		end
		if IsValid(monsters[1]) then Control.CastSpell(HK_Q, monsters[1]) end
	end
end

function ClassicAkali:Flee()
	if Menu.Flee.W:Value() and IsReady(_W) then
		Control.CastSpell(HK_W, myHero.pos)
		return
	end
	if not Menu.Flee.R:Value() or not IsReady(_R) or self:RAmmo() == 0 then return end
	local best, bestDistance = nil, myHero.pos:DistanceTo(mousePos)
	for _, list in ipairs({ _G.SDK.ObjectManager:GetEnemyHeroes(self.RRange), _G.SDK.ObjectManager:GetEnemyMinions(self.RRange), _G.SDK.ObjectManager:GetMonsters(self.RRange) }) do
		for _, unit in ipairs(list) do
			if IsValid(unit) and self:CanR(unit, Menu.Flee.SafeR:Value()) then
				local distance = unit.pos:DistanceTo(mousePos)
				if distance < bestDistance then
					best, bestDistance = unit, distance
				end
			end
		end
	end
	if best then Control.CastSpell(HK_R, best) end
end

function ClassicAkali:KillSteal()
	for _, target in ipairs(_G.SDK.ObjectManager:GetEnemyHeroes(self.RRange)) do
		if IsValid(target) and target.pos2D.onScreen then
			local health = target.health + (target.hpRegen or 0) + (target.shieldAP or 0)
			if Menu.KillSteal.Q:Value() and IsReady(_Q) and target.distance <= self.QRange and self:GetQDmg(target) >= health then
				Control.CastSpell(HK_Q, target)
				return
			end
			if Menu.KillSteal.E:Value() and IsReady(_E) and target.distance <= self.ERange and self:GetEDmg(target) >= health then
				V2:Cast(HK_E, nil, {intentTarget=target})
				return
			end
			if Menu.KillSteal.R:Value() and IsReady(_R) and self:RAmmo() > 0 and self:CanR(target, Menu.Combo.SafeR:Value()) and self:GetRDmg(target) >= health then
				Control.CastSpell(HK_R, target)
				return
			end
		end
	end
end

function ClassicAkali:Magic(target, damage)
	return _G.SDK.Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_MAGICAL, damage)
end

function ClassicAkali:GetQDmg(target)
	local level = myHero:GetSpellData(_Q).level
	if level == 0 then return 0 end
	return self:Magic(target, ({ 45, 70, 95, 120, 145 })[level] + myHero.ap * 0.40)
end

function ClassicAkali:GetEDmg(target)
	local level = myHero:GetSpellData(_E).level
	if level == 0 then return 0 end
	return self:Magic(target, ({ 30, 55, 80, 105, 130 })[level] + myHero.totalDamage * 0.60 + myHero.ap * 0.30)
end

function ClassicAkali:GetRDmg(target)
	local level = myHero:GetSpellData(_R).level
	if level == 0 then return 0 end
	return self:Magic(target, ({ 100, 175, 250 })[level] + myHero.ap * 0.50)
end

function ClassicAkali:Draw()
	if myHero.dead then return end
	if Menu.Draw.Farm:Value() then Draw.Text(Menu.Clear.Enabled:Value() and "Spell Farm: On" or "Spell Farm: Off", 16, myHero.pos2D.x - 55, myHero.pos2D.y + 60, Draw.Color(200, 242, 120, 34)) end
	if Menu.Draw.Q:Value() and IsReady(_Q) then Draw.Circle(myHero.pos, self.QRange, 1, Draw.Color(255, 66, 244, 113)) end
	if Menu.Draw.W:Value() and IsReady(_W) then Draw.Circle(myHero.pos, self.WRange, 1, Draw.Color(255, 244, 238, 66)) end
	if Menu.Draw.E:Value() and IsReady(_E) then Draw.Circle(myHero.pos, self.ERange, 1, Draw.Color(255, 66, 229, 244)) end
	if Menu.Draw.R:Value() and IsReady(_R) then Draw.Circle(myHero.pos, self.RRange, 1, Draw.Color(255, 244, 66, 96)) end
end


-- Explicit request context. Nested helpers inherit their caller's context.
V2:RegisterPolicy({
    damageTypes={Q='magical',E='magical',R='magical'},
    methods={


        Combo=function()return V2:ModeContext("Combo")end,
        Harass=function()return V2:ModeContext("Harass")end,
        Clear=function()return V2:ModeContext("LaneClear")end,
        Flee=function()return V2:ModeContext("Flee")end,
    },
    exceptions={non_interrupting_summoner=true},
    channel=function(self,q)return not (myHero.activeSpell and myHero.activeSpell.valid and myHero.activeSpell.isChanneling) end,
    validate=function(self,q,slot,resolved)
        if slot==_R and q.object then return self:CanR(q.object,q.owner=='Combo' and Menu.Combo.SafeR:Value() or false)end
        if slot==_E and q.owner=='Harass' then return GetEnemyCount(self.ERange,myHero.pos)>0 end
        return true
    end,
})

ClassicAkali()

end
if champion=="Ashe" then
local Version = 1.02


local ClassicAshe=class("ClassicAshe")

function ClassicAshe:__init()

	self:LoadMenu()
	Callback.Add("Draw", function() self:Draw() end)
	Callback.Add("Tick", function() self:Tick() end)
	_G.SDK.Orbwalker:OnPreAttack(function(...) self:OnPreAttack(...) end)
	self.WSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 20, Range = 1200, Speed = 2000, Collision = true, CollisionTypes = {GGPrediction.COLLISION_MINION, GGPrediction.COLLISION_YASUOWALL}}
	self.RSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 130, Range = 12500, Speed = 1800, Collision = true, CollisionTypes = {GGPrediction.COLLISION_YASUOWALL}}
end

function ClassicAshe:LoadMenu()
	local championIcon = "http://ddragon.leagueoflegends.com/cdn/16.15.1/img/champion/"..myHero.charName..".png"
	Menu = MenuElement({type = MENU, id = "Classic_AIO_"..myHero.charName, name = "Classic AIO - "..myHero.charName.." V: "..Version, leftIcon = championIcon})
 
	Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
	Menu.Combo:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "W", name = "Use W", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "Raoe", name = "Use R| AOE", toggle = true, value = true})

	Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
	Menu.Harass:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	Menu.Harass:MenuElement({id = "W", name = "Use W", toggle = true, value = true})
	-- Menu.Harass:MenuElement({id = "Mana", name = "Harass When ManaPercent >= x%", value = 60, min = 0, max = 100, step = 5})

	Menu:MenuElement({type = MENU, id = "Clear", name = "Clear"})
	Menu.Clear:MenuElement({id = "SpellFarm", name = "Use Spell Farm(Mouse Scroll)", toggle = true, value = false, key = 4, callback = function(newValue)
		if CheckChatBlock(Menu.Clear.SpellFarm, newValue) then return end
	end})
	Menu.Clear:MenuElement({id = "SpellHarass", name = "Use Spell Harass(In LaneClear Mode)", toggle = true, value = true, key = string.byte("H"), callback = function(newValue)
		if CheckChatBlock(Menu.Clear.SpellHarass, newValue) then return end
	end})
	Menu.Clear:MenuElement({type = MENU, id = "LaneClear", name = "LaneClear"})
	Menu.Clear.LaneClear:MenuElement({id = "W", name = "Use W", toggle = true, value = true})
	Menu.Clear.LaneClear:MenuElement({id = "Count", name = "If LaneClear Counts >= ", value = 2, min = 1, max = 6, step = 1})
	-- Menu.Clear.LaneClear:MenuElement({id = "Mana", name = "When ManaPercent >= x%", value = 60, min = 0, max = 100, step = 5})
	Menu.Clear:MenuElement({type = MENU, id = "JungleClear", name = "JungleClear"})
	Menu.Clear.JungleClear:MenuElement({id = "W", name = "Use W", toggle = true, value = true})
	-- Menu.Clear.JungleClear:MenuElement({id = "Mana", name = "When ManaPercent >= x%", value = 30, min = 0, max = 100, step = 5})

	Menu:MenuElement({type = MENU, id = "KillSteal", name = "KillSteal"})
	Menu.KillSteal:MenuElement({id = "W", name = "Auto W KillSteal", toggle = true, value = true})

	Menu:MenuElement({type = MENU, id = "Misc", name = "Misc"})
	Menu.Misc:MenuElement({id = "Rsm", name = "Semi-manual R Target near mouse", key = string.byte("T")})

	Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
	Menu.Draw:MenuElement({id = "DrawFarm", name = "Draw Spell Farm Status", toggle = true, value = true})
	Menu.Draw:MenuElement({id = "DrawHarass", name = "Draw Spell Harass Status", toggle = true, value = true})
	Menu.Draw:MenuElement({id = "W", name = "Draw W Range", toggle = true, value = false})
end

function ClassicAshe:OnPreAttack(args)
	local target = args.Target
	if IsValid(target) and IsReady(_Q) and myHero:GetSpellData(_Q).toggleState == 1 then
		if target.type == Obj_AI_Hero then
			if GetMode() == "Combo" and Menu.Combo.Q:Value() or (GetMode() == "Harass" and Menu.Harass.Q:Value()--[[ and myHero.mana/myHero.maxMana >= Menu.Harass.Mana:Value()/100]]) then
				Control.CastSpell(HK_Q)
			end
		end
	end
end

function ClassicAshe:Tick()
	if myHero:GetSpellData(_Q).toggleState == 2 and GetMode() ~= "Combo" and GetMode() ~= "Harass" then
		Control.CastSpell(HK_Q)
	end
	if ShouldWait() then
		return
	end
	if IsCasting() then return end
	self:SemiManualR()
	self:KillSteal()
	local Mode = GetMode()
	if Mode == "Combo" then
		self:Combo()
	elseif Mode == "Harass" then
		self:Harass()
	elseif Mode == "LaneClear" then
		self:FarmHarass()
		self:LaneClear()
		self:JungleClear()
	end
end

function ClassicAshe:KillSteal()
	if Menu.KillSteal.W:Value() and IsReady(_W) then
		local enemies = _G.SDK.ObjectManager:GetEnemyHeroes(self.WSpell.Range)
		for i, target in ipairs(enemies) do
			if IsValid(target) then
				local WDmg = self:GetWDmg(target)
				if WDmg >= target.health + target.hpRegen + target.shieldAD then
					self:CastW(target)
				end
			end
		end
	end
end

function ClassicAshe:SemiManualR()
	if Menu.Misc.Rsm:Value() and IsReady(_R) then
		local target = _G.SDK.TargetSelector.Selected
		if target and target.pos2D.onScreen and target.distance <= self.RSpell.Range then
			self:CastR(target)
			return
		end
		local enemies = _G.SDK.ObjectManager:GetEnemyHeroes(self.RSpell.Range)
		table.sort(enemies, function(a, b) return mousePos:DistanceTo(a.pos) < mousePos:DistanceTo(b.pos) end)
		if IsValid(enemies[1]) and enemies[1].pos2D.onScreen then
			self:CastR(enemies[1])
		end
	end
end

function ClassicAshe:CastW(target)
	local WPrediction = GGPrediction:SpellPrediction(self.WSpell)
	WPrediction:GetPrediction(target, myHero)
	if WPrediction:CanHit(2) then
		Control.CastSpell(HK_W, WPrediction.CastPosition)
	end
end

function ClassicAshe:CastR(target)
	local RPrediction = GGPrediction:SpellPrediction(self.RSpell)
	RPrediction:GetPrediction(target, myHero)
	if RPrediction:CanHit(3) then
		Control.CastSpell(HK_R, RPrediction.CastPosition)
	end
end

function ClassicAshe:Combo()
	if Menu.Combo.W:Value() and IsReady(_W) then
		local target = GetTarget(self.WSpell.Range)
		if IsValid(target) and target.pos2D.onScreen then
			self:CastW(target)
		end
	end
	if Menu.Combo.Raoe:Value() and IsReady(_R) then
		local target = GetTarget(2000)
		if IsValid(target) and target.pos2D.onScreen and GetEnemyCount(250, target.pos) > 2 then
			self:CastR(target)
		end
	end
end

function ClassicAshe:Harass()
	if IsUnderTurret(myHero) then return end
	if Menu.Harass.W:Value() and IsReady(_W) --[[and myHero.mana/myHero.maxMana >= Menu.Harass.Mana:Value()/100 ]]then
		local target = GetTarget(self.WSpell.Range)
		if IsValid(target) and target.pos2D.onScreen then
			self:CastW(target)
		end
	end
end

function ClassicAshe:FarmHarass()
	if Menu.Clear.SpellHarass:Value() then
		self:Harass()
	end
end

function ClassicAshe:LaneClear()
	if Menu.Clear.SpellFarm:Value() then
		if --[[myHero.mana/myHero.maxMana >= Menu.Clear.LaneClear.Mana:Value()/100 and ]]Menu.Clear.LaneClear.W:Value() and IsReady(_W) then
			local minions = _G.SDK.ObjectManager:GetEnemyMinions(self.WSpell.Range)
			for i, minion in ipairs(minions) do
				if IsValid(minion) and minion.team ~= 300 then
					if GetMinionCount(300, minion.pos) >= Menu.Clear.LaneClear.Count:Value() then
						Control.CastSpell(HK_W, minion)
					end
				end
			end
		end
	end
end

function ClassicAshe:JungleClear()
	if --[[myHero.mana/myHero.maxMana >= Menu.Clear.JungleClear.Mana:Value()/100 and ]]Menu.Clear.SpellFarm:Value() then
		if Menu.Clear.JungleClear.W:Value() and IsReady(_W) then
			local minions = _G.SDK.ObjectManager:GetEnemyMinions(600)
			for i, minion in ipairs(minions) do
				if IsValid(minion) and minion.team == 300 then
					Control.CastSpell(HK_W, minion)
				end
			end
		end
	end
end

function ClassicAshe:GetWDmg(target)
	local level = myHero:GetSpellData(_W).level
	if level > 0 then
		local WDmg = ({40, 55, 70, 85, 100})[level] + myHero.totalDamage
		return _G.SDK.Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_PHYSICAL, WDmg)
	else
		return 0
	end
end

function ClassicAshe:Draw()
	if myHero.dead then return end

	if Menu.Draw.DrawFarm:Value() then
		if Menu.Clear.SpellFarm:Value() then
			Draw.Text("Spell Farm: On", 16, myHero.pos2D.x-57, myHero.pos2D.y+58, Draw.Color(200, 242, 120, 34))
		else
			Draw.Text("Spell Farm: Off", 16, myHero.pos2D.x-57, myHero.pos2D.y+58, Draw.Color(200, 242, 120, 34))
		end
	end

	if Menu.Draw.DrawHarass:Value() then
		if Menu.Clear.SpellHarass:Value() then
			Draw.Text("Spell Harass: On", 16, myHero.pos2D.x-57, myHero.pos2D.y+78, Draw.Color(200, 242, 120, 34))
		else
			Draw.Text("Spell Harass: Off", 16, myHero.pos2D.x-57, myHero.pos2D.y+78, Draw.Color(200, 242, 120, 34))
		end
	end

	if Menu.Draw.W:Value() and IsReady(_W) then
		Draw.Circle(myHero.pos, self.WSpell.Range, 1, Draw.Color(255, 66, 229, 244))
	end
end


-- Explicit request context. Nested helpers inherit their caller's context.
V2:RegisterPolicy({
    damageTypes={W='physical'},
    methods={

        OnPreAttack=function()local mode=GetMode();return mode and V2:ModeContext(mode) or nil end,

        Combo=function()return V2:ModeContext("Combo")end,
        Harass=function()return V2:ModeContext("Harass")end,
        LaneClear=function()return V2:ModeContext("LaneClear",function()return Menu.Clear.SpellFarm:Value()end)end,
        JungleClear=function()return V2:ModeContext("LaneClear",function()return Menu.Clear.SpellFarm:Value()end)end,
        FarmHarass=function()return V2:ModeContext("LaneClear",function()return Menu.Clear.SpellHarass:Value() and not IsUnderTurret(myHero)end)end,
        SemiManualR=function()return V2:HeldContext(function()return Menu.Misc.Rsm:Value()end)end,
    },
    costPaid=function(self,q,slot)return slot==_Q and myHero:GetSpellData(_Q).toggleState==2 end,
    exceptions={non_interrupting_summoner=true},
    channel=function(self,q)return not (myHero.activeSpell and myHero.activeSpell.valid and myHero.activeSpell.isChanneling) end,
    validate=function(self,q,slot,resolved)
        if slot==_Q then
            if q.owner=='Combo' or q.owner=='Harass'then return myHero:GetSpellData(_Q).toggleState~=2 end
        end
        return true
    end,
})

ClassicAshe()

end
if champion=="Blitzcrank" then
local Version = 1.01


local ClassicBlitzcrank=class("ClassicBlitzcrank")

function ClassicBlitzcrank:__init()

	self.QSpell = { Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 70, Range = 1079, Speed = 1800, Collision = true, CollisionTypes = { GGPrediction.COLLISION_MINION, GGPrediction.COLLISION_YASUOWALL } }
	self.ERange, self.RRange = 275, 600
	self:LoadMenu()
	Callback.Add("Tick", function() self:Tick() end)
	Callback.Add("Draw", function() self:Draw() end)
	_G.SDK.Orbwalker:OnPreAttack(function(args) self:OnPreAttack(args) end)
end

function ClassicBlitzcrank:LoadMenu()
	local icon = "http://ddragon.leagueoflegends.com/cdn/16.15.1/img/champion/" .. myHero.charName .. ".png"
	Menu = MenuElement({ type = MENU, id = "Classic_AIO_" .. myHero.charName, name = "Classic AIO - " .. myHero.charName .. " V: " .. Version, leftIcon = icon })
	Menu:MenuElement({ type = MENU, id = "Combo", name = "Combo" })
	for _, s in ipairs({ "Q", "W", "E", "R" }) do
		Menu.Combo:MenuElement({ id = s, name = "Use " .. s, value = true })
	end
	Menu.Combo:MenuElement({ id = "RCount", name = "Use R | Enemy Count >=", value = 2, min = 1, max = 5, step = 1 })
	Menu:MenuElement({ type = MENU, id = "Harass", name = "Harass" })
	Menu.Harass:MenuElement({ id = "Q", name = "Use Q", value = true })
	Menu.Harass:MenuElement({ id = "E", name = "Use E", value = true })
	Menu.Harass:MenuElement({ id = "Mana", name = "Mana Percent >=", value = 45, min = 0, max = 100, step = 5 })
	Menu:MenuElement({ type = MENU, id = "Clear", name = "Clear" })
	Menu.Clear:MenuElement({ id = "Enabled", name = "Use Spell Farm (Mouse Scroll)", toggle = true, value = false, key = 4, callback = function(v) CheckChatBlock(Menu.Clear.Enabled, v) end })
	Menu.Clear:MenuElement({ id = "W", name = "Use W In Jungle", value = true })
	Menu.Clear:MenuElement({ id = "E", name = "Use E In Jungle", value = true })
	Menu.Clear:MenuElement({ id = "R", name = "Use R | Nearby Minions >=", value = 5, min = 0, max = 8, step = 1 })
	Menu.Clear:MenuElement({ id = "Mana", name = "Mana Percent >=", value = 30, min = 0, max = 100, step = 5 })
	Menu:MenuElement({ type = MENU, id = "KillSteal", name = "KillSteal" })
	Menu.KillSteal:MenuElement({ id = "Q", name = "Auto Q", value = true })
	Menu.KillSteal:MenuElement({ id = "R", name = "Auto R", value = true })
	Menu:MenuElement({ type = MENU, id = "Misc", name = "Misc" })
	Menu.Misc:MenuElement({ id = "AutoQ", name = "Auto Q Immobilized Target", value = true })
	Menu.Misc:MenuElement({ id = "AntiDash", name = "Auto Q Anti-Dash", value = true })
	Menu:MenuElement({ type = MENU, id = "Draw", name = "Draw" })
	for _, s in ipairs({ "Q", "E", "R" }) do
		Menu.Draw:MenuElement({ id = s, name = "Draw " .. s .. " Range", value = false })
	end
	Menu.Draw:MenuElement({ id = "Farm", name = "Draw Farm Status", value = true })
end

function ClassicBlitzcrank:ManaPercent() return myHero.maxMana > 0 and myHero.mana / myHero.maxMana * 100 or 100 end
function ClassicBlitzcrank:EActive() return HaveBuff(myHero, "Jade_BlitzcrankPowerFist") end

function ClassicBlitzcrank:Tick()
	if ShouldWait() or IsCasting() then return end
	self:AutoQ()
	self:KillSteal()
	local mode = GetMode()
	if mode == "Combo" then
		self:Combo()
	elseif mode == "Harass" then
		self:Harass()
	elseif mode == "LaneClear" then
		self:Clear()
	end
end

function ClassicBlitzcrank:OnPreAttack(args)
	local target = args and args.Target
	if not IsValid(target) or not IsReady(_E) or self:EActive() then return end
	local mode = GetMode()
	if mode == "Combo" and Menu.Combo.E:Value() and target.type == Obj_AI_Hero then
		Control.CastSpell(HK_E)
	elseif mode == "Harass" and Menu.Harass.E:Value() and target.type == Obj_AI_Hero then
		Control.CastSpell(HK_E)
	elseif mode == "LaneClear" and Menu.Clear.Enabled:Value() and Menu.Clear.E:Value() and target.team == 300 then
		Control.CastSpell(HK_E)
	end
end

function ClassicBlitzcrank:Combo()
	local target = GetTarget(self.QSpell.Range)
	if not IsValid(target) or not target.pos2D.onScreen then return end
	if Menu.Combo.R:Value() and IsReady(_R) and GetEnemyCount(self.RRange, myHero.pos) >= Menu.Combo.RCount:Value() then
		Control.CastSpell(HK_R)
		return
	end
	if Menu.Combo.E:Value() and IsReady(_E) and not self:EActive() and target.distance <= self.ERange then
		Control.CastSpell(HK_E)
		return
	end
	if Menu.Combo.Q:Value() and IsReady(_Q) and self:CastQ(target, 2) then return end
	if Menu.Combo.W:Value() and IsReady(_W) and target.distance > self.ERange then Control.CastSpell(HK_W) end
end

function ClassicBlitzcrank:Harass()
	if self:ManaPercent() < Menu.Harass.Mana:Value() then return end
	local target = GetTarget(self.QSpell.Range)
	if not IsValid(target) or not target.pos2D.onScreen then return end
	if Menu.Harass.E:Value() and IsReady(_E) and target.distance <= self.ERange then
		Control.CastSpell(HK_E)
		return
	end
	if Menu.Harass.Q:Value() and IsReady(_Q) then self:CastQ(target, 3) end
end

function ClassicBlitzcrank:Clear()
	if not Menu.Clear.Enabled:Value() or self:ManaPercent() < Menu.Clear.Mana:Value() then return end
	local monsters = _G.SDK.ObjectManager:GetMonsters(self.ERange)
	if Menu.Clear.R:Value() > 0 and IsReady(_R) and GetMinionCount(self.RRange, myHero.pos) >= Menu.Clear.R:Value() then
		Control.CastSpell(HK_R)
		return
	end
	if IsValid(monsters[1]) then
		if Menu.Clear.E:Value() and IsReady(_E) and not self:EActive() then
			Control.CastSpell(HK_E)
			return
		end
		if Menu.Clear.W:Value() and IsReady(_W) then Control.CastSpell(HK_W) end
	end
end

function ClassicBlitzcrank:AutoQ()
	if not IsReady(_Q) then return end
	for _, target in ipairs(_G.SDK.ObjectManager:GetEnemyHeroes(self.QSpell.Range)) do
		if IsValid(target) and target.pos2D.onScreen then
			if Menu.Misc.AntiDash:Value() and target.pathing and target.pathing.isDashing and target.pathing.endPos and target.pathing.endPos:DistanceTo(myHero.pos) <= self.QSpell.Range then
				Control.CastSpell(HK_Q, target.pathing.endPos)
				return
			end
			if Menu.Misc.AutoQ:Value() and IsHardCC(target) then
				if self:CastQ(target, 4) then return end
			end
		end
	end
end

function ClassicBlitzcrank:KillSteal()
	for _, target in ipairs(_G.SDK.ObjectManager:GetEnemyHeroes(self.QSpell.Range)) do
		if IsValid(target) and target.pos2D.onScreen then
			local hp = target.health + (target.hpRegen or 0) + (target.shieldAP or 0)
			if Menu.KillSteal.R:Value() and IsReady(_R) and target.distance <= self.RRange and self:GetRDmg(target) >= hp then
				Control.CastSpell(HK_R)
				return
			end
			if Menu.KillSteal.Q:Value() and IsReady(_Q) and self:GetQDmg(target) >= hp then
				if self:CastQ(target, 3) then return end
			end
		end
	end
end

function ClassicBlitzcrank:CastQ(target, hc)
	local p = GGPrediction:SpellPrediction(self.QSpell)
	p:GetPrediction(target, myHero)
	if p:CanHit(hc or 2) then
		return Control.CastSpell(HK_Q, p.CastPosition)
	end
	return false
end
function ClassicBlitzcrank:Magic(t, d) return _G.SDK.Damage:CalculateDamage(myHero, t, _G.SDK.DAMAGE_TYPE_MAGICAL, d) end
function ClassicBlitzcrank:GetQDmg(t)
	local l = myHero:GetSpellData(_Q).level
	if l == 0 then return 0 end
	return self:Magic(t, ({ 80, 135, 190, 245, 300 })[l] + myHero.ap)
end
function ClassicBlitzcrank:GetRDmg(t)
	local l = myHero:GetSpellData(_R).level
	if l == 0 then return 0 end
	return self:Magic(t, ({ 250, 375, 500 })[l] + myHero.ap)
end

function ClassicBlitzcrank:Draw()
	if myHero.dead then return end
	if Menu.Draw.Farm:Value() then Draw.Text(Menu.Clear.Enabled:Value() and "Spell Farm: On" or "Spell Farm: Off", 16, myHero.pos2D.x - 55, myHero.pos2D.y + 60, Draw.Color(200, 242, 120, 34)) end
	if Menu.Draw.Q:Value() and IsReady(_Q) then Draw.Circle(myHero.pos, self.QSpell.Range, 1, Draw.Color(255, 66, 244, 113)) end
	if Menu.Draw.E:Value() and IsReady(_E) then Draw.Circle(myHero.pos, self.ERange, 1, Draw.Color(255, 244, 238, 66)) end
	if Menu.Draw.R:Value() and IsReady(_R) then Draw.Circle(myHero.pos, self.RRange, 1, Draw.Color(255, 244, 66, 96)) end
end


-- Explicit request context. Nested helpers inherit their caller's context.
V2:RegisterPolicy({
    damageTypes={Q='magical',R='magical'},
    methods={
        AutoQ=function()return {priority='interactive'}end,
        OnPreAttack=function()local mode=GetMode();return mode and V2:ModeContext(mode) or nil end,

        Combo=function()return V2:ModeContext("Combo")end,
        Harass=function()return V2:ModeContext("Harass")end,
        Clear=function()return V2:ModeContext("LaneClear")end,
    },
    exceptions={non_interrupting_summoner=true},
    channel=function(self,q)return not (myHero.activeSpell and myHero.activeSpell.valid and myHero.activeSpell.isChanneling) end,
    validate=function(self,q,slot,resolved)
        if slot==_E then return not self:EActive()end
        if slot==_R and q.owner=='Combo'then return GetEnemyCount(self.RRange,myHero.pos)>=Menu.Combo.RCount:Value()end
        if slot==_R and q.owner=='Clear'then return GetMinionCount(self.RRange,myHero.pos)>=Menu.Clear.R:Value()end
        return true
    end,
})

ClassicBlitzcrank()

end
if champion=="Corki" then
local Version = 1.02


local ClassicCorki=class("ClassicCorki")

function ClassicCorki:__init()

	self:LoadMenu()
	Callback.Add("Draw", function() self:Draw() end)
	Callback.Add("Tick", function() self:Tick() end)
	_G.SDK.Orbwalker:OnPreAttack(function(...) self:OnPreAttack(...) end)
	self.QSpell = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 0.25, Radius = 250, Range = 600, Speed = math.huge, Collision = true, CollisionTypes = {GGPrediction.COLLISION_YASUOWALL}}
	self.ESpell = {Range = 685}
	self.R1Spell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.175, Radius = 40, Range = 1225, Speed = 2000, Collision = true, CollisionTypes = {GGPrediction.COLLISION_YASUOWALL}}
	self.R2Spell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.175, Radius = 40, Range = 1225, Speed = 2000, Collision = true, CollisionTypes = {GGPrediction.COLLISION_YASUOWALL}}
end

function ClassicCorki:LoadMenu()
	local championIcon = "http://ddragon.leagueoflegends.com/cdn/16.15.1/img/champion/"..myHero.charName..".png"
	Menu = MenuElement({type = MENU, id = "Classic_AIO_"..myHero.charName, name = "Classic AIO - "..myHero.charName.." V: "..Version, leftIcon = championIcon})

	Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
	Menu.Combo:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "E", name = "Use E", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "R", name = "Use R", toggle = true, value = true})

	Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
	Menu.Harass:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	Menu.Harass:MenuElement({id = "E", name = "Use E", toggle = true, value = true})
	Menu.Harass:MenuElement({id = "R", name = "Use R", toggle = true, value = true})
	Menu.Harass:MenuElement({id = "Rammo", name = "Minimum R ammo harass", value = 3, min = 0, max = 3, step = 1})
	-- Menu.Harass:MenuElement({id = "Mana", name = "When ManaPercent >= x%", value = 60, min = 0, max = 100, step = 5})

	Menu:MenuElement({type = MENU, id = "Clear", name = "Clear"})
	Menu.Clear:MenuElement({id = "SpellFarm", name = "Use Spell Farm(Mouse Scroll)", toggle = true, value = false, key = 4, callback = function(newValue)
		if CheckChatBlock(Menu.Clear.SpellFarm, newValue) then return end
	end})
	Menu.Clear:MenuElement({id = "SpellHarass", name = "Use Spell Harass(In LaneClear Mode)", toggle = true, value = false, key = string.byte("H"), callback = function(newValue)
		if CheckChatBlock(Menu.Clear.SpellHarass, newValue) then return end
	end})
	Menu.Clear:MenuElement({type = MENU, id = "LaneClear", name = "LaneClear"})
	Menu.Clear.LaneClear:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	Menu.Clear.LaneClear:MenuElement({id = "QCount", name = "If Q CanHit Counts >= ", value = 2, min = 1, max = 6, step = 1})
	Menu.Clear.LaneClear:MenuElement({id = "Rammo", name = "Minimum R ammo lane clear", value = 3, min = 0, max = 3, step = 1})
	Menu.Clear.LaneClear:MenuElement({id = "R", name = "Use R", toggle = true, value = true})
	Menu.Clear.LaneClear:MenuElement({id = "RCount", name = "If R CanHit Counts >= ", value = 2, min = 1, max = 6, step = 1})
	-- Menu.Clear.LaneClear:MenuElement({id = "Mana", name = "When ManaPercent >= x%", value = 60, min = 0, max = 100, step = 5})
	Menu.Clear:MenuElement({type = MENU, id = "JungleClear", name = "JungleClear"})
	Menu.Clear.JungleClear:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	Menu.Clear.JungleClear:MenuElement({id = "R", name = "Use R", toggle = true, value = true})
	-- Menu.Clear.JungleClear:MenuElement({id = "Mana", name = "When ManaPercent >= x%", value = 30, min = 0, max = 100, step = 5})

	Menu:MenuElement({type = MENU, id = "Misc", name = "Misc"})
	Menu.Misc:MenuElement({id = "Qcc", name = "Auto Q On 'CC'", toggle = true, value = true})
	Menu.Misc:MenuElement({id = "SemiR", name = "Semi-manual R Key", key = string.byte("T")})

	Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
	Menu.Draw:MenuElement({id = "DrawFarm", name = "Draw Spell Farm Status", toggle = true, value = true})
	Menu.Draw:MenuElement({id = "DrawHarass", name = "Draw Spell Harass Status", toggle = true, value = true})
	Menu.Draw:MenuElement({id = "Q", name = "Draw Q Range", toggle = true, value = false})
	Menu.Draw:MenuElement({id = "E", name = "Draw E Range", toggle = true, value = false})
	Menu.Draw:MenuElement({id = "R", name = "Draw R Range", toggle = true, value = false})
end

function ClassicCorki:OnPreAttack(args)
	local target = args.Target
	if IsValid(target) and target.type == Obj_AI_Hero then
		if GetMode() == "Combo" and Menu.Combo.E:Value() and IsReady(_E) then
			Control.CastSpell(HK_E, target)
		end
		if GetMode() == "Harass" --[[and myHero.mana/myHero.maxMana >= Menu.Harass.Mana:Value()/100 ]]then 
			if Menu.Harass.E:Value() and IsReady(_E) then
				Control.CastSpell(HK_E, target)
			end
		end
	end
end

function ClassicCorki:Tick()
	if ShouldWait() then
		return
	end
	if IsCasting() then return end
	self:SemiR()
	self:AutoQ()
	local Mode = GetMode()
	if Mode == "Combo" then
		self:Combo()
	elseif Mode == "Harass" then
		self:Harass()
	elseif Mode == "LaneClear" then
		self:FarmHarass()
		self:LaneClear()
		self:JungleClear()
	end
end

function ClassicCorki:Combo()
	if Menu.Combo.Q:Value() and IsReady(_Q) then
		local target = GetTarget(self.QSpell.Range)
		if IsValid(target) and target.pos2D.onScreen then
			self:CastQ(target)
		end
	end

	if Menu.Combo.R:Value() and IsReady(_R) then
		local target = GetTarget(self.R1Spell.Range)
		if IsValid(target) and target.pos2D.onScreen then
			self:CastR(target)
		end
	end
end

function ClassicCorki:AutoQ()
	if Menu.Misc.Qcc:Value() and IsReady(_Q) then
		local enemies = _G.SDK.ObjectManager:GetEnemyHeroes(self.QSpell.Range)
		for i, target in ipairs(enemies) do
			if IsValid(target) and target.pos2D.onScreen and IsHardCC(target) then
				self:CastQ(target)
			end
		end
	end
end

function ClassicCorki:CastQ(target)
	local QPrediction = GGPrediction:SpellPrediction(self.QSpell)
	QPrediction:GetPrediction(target, myHero)
	if QPrediction:CanHit(3) then
		Control.CastSpell(HK_Q, QPrediction.CastPosition)
	end
end

function ClassicCorki:CastR(target)
	if HaveBuff(myHero, "Jade_CorkiR_Check") then
		local R2Prediction = GGPrediction:SpellPrediction(self.R2Spell)
		R2Prediction:GetPrediction(target, myHero)
		if R2Prediction:CanHit(3) then
			local _, collisionObjects, collisionCount = GGPrediction:GetCollision(myHero.pos, R2Prediction.CastPosition, self.R2Spell.Speed, self.R2Spell.Delay, self.R2Spell.Radius, {GGPrediction.COLLISION_MINION}, target.networkID)
			if collisionCount > 0 then
				local minion = collisionObjects[1]
				if minion.pos:DistanceTo(R2Prediction.CastPosition) < 250 then
					Control.CastSpell(HK_R, R2Prediction.CastPosition)
				end
			else
				Control.CastSpell(HK_R, R2Prediction.CastPosition)
			end
		end
	else
		local R1Prediction = GGPrediction:SpellPrediction(self.R1Spell)
		R1Prediction:GetPrediction(target, myHero)
		if R1Prediction:CanHit(3) then
			local _, collisionObjects, collisionCount = GGPrediction:GetCollision(myHero.pos, R1Prediction.CastPosition, self.R1Spell.Speed, self.R1Spell.Delay, self.R1Spell.Radius, {GGPrediction.COLLISION_MINION}, target.networkID)
			if collisionCount > 0 then
				local minion = collisionObjects[1]
				if minion.pos:DistanceTo(R1Prediction.CastPosition) < 100 then
					Control.CastSpell(HK_R, R1Prediction.CastPosition)
				end
			else
				Control.CastSpell(HK_R, R1Prediction.CastPosition)
			end
		end
	end
end

function ClassicCorki:Harass()
	-- if myHero.mana/myHero.maxMana >= Menu.Harass.Mana:Value()/100 then
		if Menu.Harass.Q:Value() and IsReady(_Q) then
			local target = GetTarget(self.QSpell.Range)
			if IsValid(target) and target.pos2D.onScreen then
				self:CastQ(target)
			end
		end

		if Menu.Harass.R:Value() and IsReady(_R) then
			local target = GetTarget(self.R1Spell.Range)
			if IsValid(target) and target.pos2D.onScreen and myHero:GetSpellData(_R).ammo > Menu.Harass.Rammo:Value() then
				self:CastR(target)
			end
		end
	-- end
end

function ClassicCorki:FarmHarass()
	if IsUnderTurret(myHero) then return end
	if Menu.Clear.SpellHarass:Value() then
		self:Harass()
	end
end

function ClassicCorki:LaneClear()
	if IsUnderTurret(myHero) then return end
	if --[[myHero.mana/myHero.maxMana >= Menu.Clear.LaneClear.Mana:Value()/100 and ]]Menu.Clear.SpellFarm:Value() then
		local minions = _G.SDK.ObjectManager:GetEnemyMinions(self.QSpell.Range)
		for i, minion in ipairs(minions) do
			if IsValid(minion) and minion.team ~= 300 and minion.pos2D.onScreen then
				if Menu.Clear.LaneClear.Q:Value() and IsReady(_Q) then
					if GetMinionCount(250, minion.pos) >= Menu.Clear.LaneClear.QCount:Value() then
						Control.CastSpell(HK_Q, minion)
					end
				end
				if Menu.Clear.LaneClear.R:Value() and IsReady(_R) then
					if GetMinionCount(150, minion.pos) >= Menu.Clear.LaneClear.RCount:Value() then
						local endPos = minion.pos:Extended(myHero.pos, 150)
						local _, _, collisionCount = GGPrediction:GetCollision(myHero.pos, endPos, self.R1Spell.Speed, self.R1Spell.Delay, self.R1Spell.Radius, {GGPrediction.COLLISION_MINION}, minion.networkID)
						if collisionCount == 0 and myHero:GetSpellData(_R).ammo > Menu.Clear.LaneClear.Rammo:Value() then
							Control.CastSpell(HK_R, minion)
						end
					end
				end
			end
		end
	end
end

function ClassicCorki:JungleClear()
	if --[[myHero.mana/myHero.maxMana >= Menu.Clear.JungleClear.Mana:Value()/100 and ]]Menu.Clear.SpellFarm:Value() then
		local minions = _G.SDK.ObjectManager:GetEnemyMinions(self.QSpell.Range)
		table.sort(minions, function(a, b) return a.maxHealth > b.maxHealth end)
		for i, minion in ipairs(minions) do
			if IsValid(minion) and minion.team == 300 and minion.pos2D.onScreen then
				if Menu.Clear.JungleClear.Q:Value() and IsReady(_Q) then
					Control.CastSpell(HK_Q, minion)
				end
				if Menu.Clear.JungleClear.R:Value() and IsReady(_R) then
					Control.CastSpell(HK_R, minion)
				end
			end
		end
	end
end

function ClassicCorki:SemiR()
	if Menu.Misc.SemiR:Value() and IsReady(_R) then
		local Rtarget = GetTarget(self.R1Spell.Range)
		if IsValid(Rtarget) and Rtarget.pos2D.onScreen then
			self:CastR(Rtarget)
		end
	end
end

function ClassicCorki:Draw()
	if myHero.dead then return end

	if Menu.Draw.DrawFarm:Value() then
		if Menu.Clear.SpellFarm:Value() then
			Draw.Text("Spell Farm: On", 16, myHero.pos2D.x-57, myHero.pos2D.y+58, Draw.Color(200, 242, 120, 34))
		else
			Draw.Text("Spell Farm: Off", 16, myHero.pos2D.x-57, myHero.pos2D.y+58, Draw.Color(200, 242, 120, 34))
		end
	end

	if Menu.Draw.DrawHarass:Value() then
		if Menu.Clear.SpellHarass:Value() then
			Draw.Text("Spell Harass: On", 16, myHero.pos2D.x-57, myHero.pos2D.y+78, Draw.Color(200, 242, 120, 34))
		else
			Draw.Text("Spell Harass: Off", 16, myHero.pos2D.x-57, myHero.pos2D.y+78, Draw.Color(200, 242, 120, 34))
		end
	end

	if Menu.Draw.Q:Value() and IsReady(_Q) then
		Draw.Circle(myHero.pos, self.QSpell.Range, 1, Draw.Color(255, 66, 244, 113))
	end
	if Menu.Draw.E:Value() and IsReady(_E) then
		Draw.Circle(myHero.pos, self.ESpell.Range, 1, Draw.Color(255, 244, 238, 66))
	end
	if Menu.Draw.R:Value() and IsReady(_R) then
		if HaveBuff(myHero, "Jade_CorkiR_Check") then
			Draw.Circle(myHero.pos, self.R2Spell.Range+50, 1, Draw.Color(255, 244, 66, 104))
		else
			Draw.Circle(myHero.pos, self.R1Spell.Range+50, 1, Draw.Color(255, 244, 66, 104))
		end
	end
end


-- Explicit request context. Nested helpers inherit their caller's context.
V2:RegisterPolicy({
    methods={
        AutoQ=function()return {priority='interactive'}end,
        OnPreAttack=function()local mode=GetMode();return mode and V2:ModeContext(mode) or nil end,

        Combo=function()return V2:ModeContext("Combo")end,
        Harass=function()return V2:ModeContext("Harass")end,
        LaneClear=function()return V2:ModeContext("LaneClear",function()return Menu.Clear.SpellFarm:Value()end)end,
        JungleClear=function()return V2:ModeContext("LaneClear",function()return Menu.Clear.SpellFarm:Value()end)end,
        FarmHarass=function()return V2:ModeContext("LaneClear",function()return Menu.Clear.SpellHarass:Value() and not IsUnderTurret(myHero)end)end,
        SemiR=function()return V2:HeldContext(function()return Menu.Misc.SemiR:Value()end)end,
    },
    exceptions={non_interrupting_summoner=true},
    channel=function(self,q)return not (myHero.activeSpell and myHero.activeSpell.valid and myHero.activeSpell.isChanneling) end,
    validate=function(self,q,slot,resolved)
        if slot==_R then
            if myHero:GetSpellData(_R).ammo==0 then return false end
            local point=resolved and resolved.position or q.target
            if not point then return false end
            local big=HaveBuff(myHero,'Jade_CorkiR_Check');local spell=big and self.R2Spell or self.R1Spell
            local _,objects,count=GGPrediction:GetCollision(myHero.pos,Vector(point),spell.Speed,spell.Delay,spell.Radius,{GGPrediction.COLLISION_MINION},q.targetID)
            if count>0 then return objects[1]~=nil and GetDistance(objects[1].pos,point)<(big and 250 or 100)end
        end
        return true
    end,
})

ClassicCorki()

end
if champion=="Ezreal" then
local Version = 1.02


local function IsUnderAllyTurret(unit)
	for _, turret in ipairs(_G.SDK.ObjectManager:GetAllyTurrets()) do
		local range = (turret.boundingRadius + 750 + unit.boundingRadius / 2)
		if not turret.dead then 
			if turret.pos:DistanceTo(unit.pos) < range then
				return true
			end
		end
	end
	return false
end

local LastChatOpenTimer = 0

--------------------------------------

local ClassicEzreal=class("ClassicEzreal")

function ClassicEzreal:__init()

	self:LoadMenu()
    _G.SDK.Orbwalker:OnPostAttack(function(args)
        local unit=args and args.Target or _G.SDK.Orbwalker.LastTarget
        if unit and myHero.attackData and myHero.attackData.target==unit.handle then self:TrackAATarget(unit) end
    end)
	Callback.Add("Draw", function() self:Draw() end)
	Callback.Add("Tick", function() self:Tick() end)
	Callback.Add("WndMsg", function(msg, wParam) self:OnWndMsg(msg, wParam) end)
	_G.SDK.Orbwalker:OnPreAttack(function(...) self:OnPreAttack(...) end)
	self.QSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 60, Range = 1050, Speed = 2000, Collision = true, CollisionTypes = {GGPrediction.COLLISION_YASUOWALL, GGPrediction.COLLISION_MINION}}
	self.WSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 80, Range = 1050, Speed = 1600, Collision = true, CollisionTypes = {GGPrediction.COLLISION_YASUOWALL}}
	self.RSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 1.00, Radius = 160, Range = 25000, Speed = 2000, Collision = true, CollisionTypes = {GGPrediction.COLLISION_YASUOWALL}}
	self.lastQ = 0
	self.lastW = 0
	self.EHelper = nil
	self.LastE = 0
	self.lastClearSpecial = 0
	self.lastQTarget = nil
	self.lastQExpire = 0
	self.lastAATarget = nil
	self.lastAAExpire = 0
	self.lastAAWillKill = false
end

function ClassicEzreal:LoadMenu()
	local championIcon = "http://ddragon.leagueoflegends.com/cdn/16.15.1/img/champion/"..myHero.charName..".png"
	Menu = MenuElement({type = MENU, id = "Classic_AIO_"..myHero.charName, name = "Classic AIO - "..myHero.charName.." V: "..Version, leftIcon = championIcon})
	Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
	Menu.Combo:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "W", name = "Use W", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "SemiR", name = "Semi-manual R Key", key = string.byte("T")})

	Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
	Menu.Harass:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	Menu.Harass:MenuElement({id = "W", name = "Use W", toggle = true, value = true})
	
	Menu:MenuElement({type = MENU, id = "Clear", name = "Clear"})
	Menu.Clear:MenuElement({id = "SpellFarm", name = "Use Spell Farm(Mouse Scroll)", toggle = true, value = true, key = 4, callback = function(newValue)
		if CheckChatBlock(Menu.Clear.SpellFarm, newValue) then return end
	end})
	Menu.Clear:MenuElement({id = "SpellHarass", name = "Use Spell Harass(In LaneClear Mode)", toggle = true, value = true, key = string.byte("H"), callback = function(newValue)
		if CheckChatBlock(Menu.Clear.SpellHarass, newValue) then return end
	end})
	Menu.Clear:MenuElement({type = MENU, id = "LaneClear", name = "LaneClear"})
	Menu.Clear.LaneClear:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	Menu.Clear.LaneClear:MenuElement({id = "QSpecial", name = "Q Special Minions", toggle = true, value = true})
	--Menu.Clear.LaneClear:MenuElement({id = "Mana", name = "When ManaPercent >= x%", value = 30, min = 0, max = 100, step = 5})
	Menu.Clear:MenuElement({type = MENU, id = "JungleClear", name = "JungleClear"})
	Menu.Clear.JungleClear:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	--Menu.Clear.JungleClear:MenuElement({id = "Mana", name = "When ManaPercent >= x%", value = 30, min = 0, max = 100, step = 5})

	Menu:MenuElement({type = MENU, id = "LastHit", name = "LastHit"})
	Menu.LastHit:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	
	Menu:MenuElement({type = MENU, id = "EHelper", name = "EHelper"})
	Menu.EHelper:MenuElement({id = "Enable", name = "Enable EHelper", toggle = true, value = false})
	Menu.EHelper:MenuElement({id = "efake", name = "Key to use", value = false, key = string.byte("E")})
	Menu.EHelper:MenuElement({id = "elol", name = "key in game", value = false, key = string.byte("L")})
	
	Menu:MenuElement({type = MENU, id = "Auto", name = "AutoR"})
	Menu.Auto:MenuElement({id = "RCC", name = "Auto R CC", toggle = true, value = true})
	Menu.Auto:MenuElement({id = "RKill", name = "Auto R KillSteal", toggle = true, value = true})
	Menu.Auto:MenuElement({id = "RAOE", name = "Auto R AOE", toggle = true, value = true})
	Menu.Auto:MenuElement({id = "RCount", name = "Auto R| AOE Count >=", value = 3, min = 1, max = 5, step = 1})

	Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
	Menu.Draw:MenuElement({id = "DrawFarm", name = "Draw Spell Farm Status", toggle = true, value = true})
	Menu.Draw:MenuElement({id = "DrawHarass", name = "Draw Spell Harass Status", toggle = true, value = true})
	Menu.Draw:MenuElement({id = "Q", name = "Draw Q Range", toggle = true, value = false})
	Menu.Draw:MenuElement({id = "W", name = "Draw W Range", toggle = true, value = false})
end

function ClassicEzreal:OnPreAttack(args)
	local mode = GetMode()
	if mode == "LaneClear" then
		if self.lastQTarget and GetTickCount() < self.lastQExpire then
			if args.Target and args.Target.handle == self.lastQTarget then
				args.Process = false
				return
			end
		else
			self.lastQTarget = nil
		end
	end
	if args.Process and args.Target then
		-- AA intent is not a launched attack. Tracking occurs on the post-attack callback.
	end
end

local LastEFake = 0
function ClassicEzreal:OnWndMsg(msg, wParam)
	if msg == KEY_DOWN and wParam == Menu.EHelper.efake:Key() then
		LastEFake = os.clock()
	end
end

function ClassicEzreal:OnEnemyHeroLoad(enemy)
	if enemy and specialMinionChampions[enemy.charName] then
		self.hasSpecialMinionEnemy = true
	end
end

function ClassicEzreal:TrackAATarget(unit)
	if not IsValid(unit) then return end
	if unit.type ~= Obj_AI_Hero and unit.type ~= Obj_AI_Minion then
		self.lastAAWillKill = false
		return
	end
	local attackSpeed = _G.SDK.Attack:GetProjectileSpeed()
	local flyTime = attackSpeed > 0 and unit.distance / attackSpeed or 0
	local timeToHit = _G.SDK.Attack:GetWindup() + flyTime
	local expireTime = (timeToHit + 0.15) * 1000
	self.lastAATarget = unit.handle
	self.lastAAExpire = GetTickCount() + expireTime
	self.lastAAWillKill = self:CanMyAAKill(unit, unit.type == Obj_AI_Hero)
end

function ClassicEzreal:Tick()
	if Game.IsChatOpen() then
		LastChatOpenTimer = GetTickCount()
	end
	if ShouldWait() then return end
	if IsCasting() then return end
	self:SemiR()
	self:AutoR()
	self:ELogic()
	local Mode = GetMode()
	if Mode == "Combo" then
		self:Combo()
	elseif Mode == "Harass" then
		self:Harass()
	elseif Mode == "LaneClear" then
		if Menu.Clear.SpellFarm:Value() then
			self:FarmHarass()
			self:ClearSpecialMinions()
			self:LaneClear()
			self:JungleClear()
		else
			self:LastHit()
			self:FarmHarass()
		end
	elseif Mode == "LastHit" then
		self:LastHit()
	end
end

function ClassicEzreal:SemiR()
	if Menu.Combo.SemiR:Value() and IsReady(_R) then
		local target = GetTarget(3000)
		if IsValid(target) and target.pos2D.onScreen then
			self:CastR(target)
		end
	end
end

function ClassicEzreal:Combo()
	local target = GetTarget(self.WSpell.Range)
	if IsValid(target) and target.pos:ToScreen().onScreen then
		if Menu.Combo.W:Value() and IsReady(_W) then
			self:CastW(target)
		end
		if Menu.Combo.Q:Value() and IsReady(_Q) then
			local inAARange = _G.SDK.Data:IsInAutoAttackRange(myHero, target)
        	local aaDamage = _G.SDK.Damage:GetAutoAttackDamage(myHero, target)	
        	local canKillWithAA = inAARange and _G.SDK.Orbwalker:CanAttack() and aaDamage >= target.health + target.shieldAD + target.hpRegen
			local aaWillKillTarget = self:WasMyRecentKillAATarget(target)
        	if not canKillWithAA and not aaWillKillTarget then
				self:CastQ(target)
			end
		end
	end
end

function ClassicEzreal:Harass()
	--if myHero.mana/myHero.maxMana >= Menu.Harass.Mana:Value()/100 then
		local target = GetTarget(self.WSpell.Range)
		if IsValid(target) and target.pos:ToScreen().onScreen then
			if Menu.Harass.Q:Value() and IsReady(_Q) then
				self:CastQ(target)
			end
			if Menu.Harass.W:Value() and IsReady(_W) then
				self:CastW(target)
			end
		end
	--end
end

function ClassicEzreal:FarmHarass()
	if IsUnderTurret(myHero) then return end
	if Menu.Clear.SpellHarass:Value() then
		self:Harass()
	end
end

function ClassicEzreal:LaneClear()
	if not IsReady(_Q) or not Menu.Clear.SpellFarm:Value() or not Menu.Clear.LaneClear.Q:Value() then return end
	local minions = _G.SDK.ObjectManager:GetEnemyMinions(self.QSpell.Range)
	if #minions == 0 then return end
	table.sort(minions, function(a, b) return a.distance < b.distance end)
	local target = nil
	local isKillShot = false
	for i, m in ipairs(minions) do
		local isCannon = m.charName and m.charName:find("Siege")
		local shouldSkipAATarget = isCannon and self:WasMyRecentKillAATarget(m) or self:WasMyRecentAATarget(m)
		if IsValid(m) and m.pos2D.onScreen and m.team ~= 300 and not shouldSkipAATarget then
			local t = m.distance / self.QSpell.Speed + self.QSpell.Delay
			local hp = _G.SDK.HealthPrediction:GetPrediction(m, t)
			local QDmg = self:GetQDmg(m)
			if hp > 0 and hp <= QDmg then
				local _, _, coll = GGPrediction:GetCollision(myHero.pos, m.pos, self.QSpell.Speed, self.QSpell.Delay, self.QSpell.Radius / 2, {GGPrediction.COLLISION_MINION}, m.networkID)
				if coll == 0 then
					target = m
					isKillShot = true
					break
				end
			end
			if not target and i == 1 and not isCannon and hp > QDmg and not IsUnderAllyTurret(m) then
				target = m
				isKillShot = false
				break
			end
		end
	end
	if IsValid(target) and IsReady(_Q) then
		if Control.CastSpell(HK_Q, target) then
			if isKillShot then
				local flyTime = (target.distance / self.QSpell.Speed + self.QSpell.Delay) * 1000
				V2:AfterCast(HK_Q, function()
                    self.lastQTarget = target.handle
                    self.lastQExpire = GetTickCount() + flyTime + 100
                end)
			end
		end
	end
end

function ClassicEzreal:ClearSpecialMinions()
	if not IsReady(_Q) or not Menu.Clear.LaneClear.QSpecial:Value() then return end
	local plants = _G.SDK.ObjectManager:GetPlants(self.QSpell.Range)
	if #plants == 0 then return end
	table.sort(plants, function(a, b) return a.distance < b.distance end)
	for _, p in ipairs(plants) do
		if IsValid(p) then
			local _, _, collisionCount = GGPrediction:GetCollision(myHero.pos, p.pos, self.QSpell.Speed, self.QSpell.Delay, self.QSpell.Radius/2, {GGPrediction.COLLISION_MINION}, p.networkID)
			if collisionCount == 0 and IsReady(_Q) then
				Control.CastSpell(HK_Q, p)
				return
			end
		end
	end
end

function ClassicEzreal:JungleClear()
	--if myHero.mana/myHero.maxMana >= Menu.Clear.JungleClear.Mana:Value()/100 and 
	if Menu.Clear.SpellFarm:Value() then
		local minions = _G.SDK.ObjectManager:GetMonsters(800)
		table.sort(minions, function(a, b) return a.maxHealth > b.maxHealth end)
		for _, minion in ipairs(minions) do
			if IsValid(minion) and minion.pos2D.onScreen then
				if Menu.Clear.JungleClear.Q:Value() and IsReady(_Q) then
					Control.CastSpell(HK_Q, minion)
				end
			end
		end
	end
end

function ClassicEzreal:LastHit()
	if Menu.LastHit.Q:Value() and IsReady(_Q) then
		local minions = _G.SDK.ObjectManager:GetEnemyMinions(self.QSpell.Range)
		for _, minion in ipairs(minions) do
			if IsValid(minion) and minion.pos2D.onScreen and not _G.SDK.Data:IsInAutoAttackRange(myHero, minion) then
				local timeToHit = minion.distance / self.QSpell.Speed + self.QSpell.Delay
				local Hp = _G.SDK.HealthPrediction:GetPrediction(minion, timeToHit)
				local QDmg = self:GetQDmg(minion)
				local _, _, collisionCount = GGPrediction:GetCollision(myHero.pos, minion.pos, self.QSpell.Speed, self.QSpell.Delay, self.QSpell.Radius/2, {GGPrediction.COLLISION_MINION}, minion.networkID)
				if Hp > 0 and QDmg >= Hp and collisionCount == 0 then
					Control.CastSpell(HK_Q, minion)
				end
			end
		end
	end
end

function ClassicEzreal:AutoR()
	if not IsReady(_R) or GetEnemyCount(800, myHero.pos) ~= 0 then return end
	for _, enemy in ipairs(_G.SDK.ObjectManager:GetEnemyHeroes(3000)) do
		if IsValid(enemy) and enemy.pos2D.onScreen then
			if Menu.Auto.RCC:Value() and IsHardCC(enemy) then
				self:CastR(enemy)
				return
			end
			if Menu.Auto.RKill:Value() and not HaveBuff(enemy, "sionpassivezombie") then
				local Dmg = self:GetRDmg(enemy) + self:GetWDmg(enemy)
				if Dmg > enemy.health + enemy.shieldAD + enemy.hpRegen * 3 and myHero.pos:DistanceTo(enemy.pos) > self.QSpell.Range then
					if GetAllyCount(500, enemy.pos) == 0 and self.lastQ + 600 < GetTickCount() then
						self:CastR(enemy)
						return
					end
				end
			end
		end
	end		
	if Menu.Auto.RAOE:Value() then
		local RPrediction = GGPrediction:SpellPrediction(self.RSpell)
		local aoeResults = RPrediction:GetAOEPrediction(myHero)
		local bestResult = nil
		for i = 1, #aoeResults do
			local result = aoeResults[i]
			if result.Count >= Menu.Auto.RCount:Value() then
				if not bestResult or result.Count > bestResult.Count then
					bestResult = result
				end
			end
		end
		if bestResult and Vector(bestResult.CastPosition):To2D().onScreen and myHero.pos:DistanceTo(bestResult.CastPosition) < 3000 then
			Control.CastSpell(HK_R, bestResult.CastPosition)
			return
		end
	end
end

function ClassicEzreal:WasMyRecentAATarget(unit)
	return IsValid(unit) and self.lastAATarget == unit.handle and GetTickCount() <= self.lastAAExpire
end

function ClassicEzreal:WasMyRecentKillAATarget(unit)
	return self:WasMyRecentAATarget(unit) and self.lastAAWillKill
end

function ClassicEzreal:CanMyAAKill(unit, includeW)
	if not IsValid(unit) then return false end
	local aaDamage = _G.SDK.Damage:GetAutoAttackDamage(myHero, unit)
	local totalDamage = aaDamage
	if includeW then
		totalDamage = totalDamage + self:GetWDmg(unit)
	end
	return totalDamage >= unit.health + unit.shieldAD + unit.hpRegen
end

function ClassicEzreal:GetQDmg(unit)
	local qLevel = myHero:GetSpellData(_Q).level
	local dmg = (25 * qLevel + 15) + (1.1 * myHero.totalDamage)
	if qLevel > 0 then
		return _G.SDK.Damage:CalculateDamage(myHero, unit, _G.SDK.DAMAGE_TYPE_PHYSICAL, dmg)
	else
		return 0
	end
end

function ClassicEzreal:GetWDmg(unit)
	local wLevel = myHero:GetSpellData(_W).level
	local dmg = (50 * wLevel + 30) + 0.6 * myHero.ap
	if wLevel > 0 then
		return _G.SDK.Damage:CalculateDamage(myHero, unit, _G.SDK.DAMAGE_TYPE_MAGICAL, dmg)
	else
		return 0
	end
end

function ClassicEzreal:GetRDmg(unit)
	local rLevel = myHero:GetSpellData(_R).level
	local dmg = (150 * rLevel + 200) + 1.0 * myHero.ap
	if rLevel > 0 then
		return _G.SDK.Damage:CalculateDamage(myHero, unit, _G.SDK.DAMAGE_TYPE_MAGICAL, dmg)
	else
		return 0
	end
end

function ClassicEzreal:CastQ(unit)
	local QPrediction = GGPrediction:SpellPrediction(self.QSpell)
	QPrediction:GetPrediction(unit, myHero)
	if QPrediction:CanHit(3) then
		if Control.CastSpell(HK_Q, QPrediction.CastPosition) then
			V2:AfterCast(HK_Q, function() self.lastQ = GetTickCount() end)
			return true
		end
	end
	return false
end

function ClassicEzreal:CastW(unit)
	local WPrediction = GGPrediction:SpellPrediction(self.WSpell)
	WPrediction:GetPrediction(unit, myHero)
	if WPrediction:CanHit(3) then
		Control.CastSpell(HK_W, WPrediction.CastPosition)
	end
end

function ClassicEzreal:CastR(unit)
	local RPrediction = GGPrediction:SpellPrediction(self.RSpell)
	RPrediction:GetPrediction(unit, myHero)
	if RPrediction:CanHit(3) then
		Control.CastSpell(HK_R, RPrediction.CastPosition)
	end
end

function ClassicEzreal:ELogic()
	if not Menu.EHelper.Enable:Value() then return end
	local timer = GetTickCount()
	if self.EHelper ~= nil then
		if _G.SDK.Cursor.Step == 0 then
			if V2:Cast(self.EHelper, myHero.pos:Extended(Vector(mousePos), 600),{slot=_E,owner="EHelper",independent=false}) then
                self.EHelper = nil
            end
		end
		return
	end
	if
		not (
			os.clock() < LastEFake + 0.5
			and Game.CanUseSpell(_E) == 0
			and not Control.IsKeyDown(HK_LUS)
			and not myHero.dead
			and not Game.IsChatOpen()
			and Game.IsOnTop()
		)
	then
		return
	end
	if self.LastE and timer < self.LastE + 1000 then
		return
	end
	if timer < LastChatOpenTimer + 1000 then
		return
	end
	if timer < LevelUpKeyTimer + 1000 then
		return
	end
	-- LastE begins only after the E spell state changes.
	if _G.SDK.Cursor.Step == 0 then
		local key=Menu.EHelper.elol:Key()
        if V2:Cast(key, myHero.pos:Extended(Vector(mousePos), 600),{slot=_E,owner="EHelper",independent=false}) then
            V2:AfterCast(key, function() self.LastE=GetTickCount() end)
            return
        end
	end
	self.EHelper = Menu.EHelper.elol:Key()
end

function ClassicEzreal:Draw()
	if myHero.dead then return end
	if Menu.Draw.DrawFarm:Value() then
		if Menu.Clear.SpellFarm:Value() then
			Draw.Text("Spell Farm: On", 16, myHero.pos2D.x-57, myHero.pos2D.y+58, Draw.Color(200, 242, 120, 34))
		else
			Draw.Text("Spell Farm: Off", 16, myHero.pos2D.x-57, myHero.pos2D.y+58, Draw.Color(200, 242, 120, 34))
		end
	end

	if Menu.Draw.DrawHarass:Value() then
		if Menu.Clear.SpellHarass:Value() then
			Draw.Text("Spell Harass: On", 16, myHero.pos2D.x-57, myHero.pos2D.y+78, Draw.Color(200, 242, 120, 34))
		else
			Draw.Text("Spell Harass: Off", 16, myHero.pos2D.x-57, myHero.pos2D.y+78, Draw.Color(200, 242, 120, 34))
		end
	end

	if Menu.Draw.Q:Value() then
		Draw.Circle(myHero.pos, self.QSpell.Range, 1, Draw.Color(255, 66, 244, 113))
	end
	if Menu.Draw.W:Value() and IsReady(_W) then
		Draw.Circle(myHero.pos, self.WSpell.Range, 1, Draw.Color(255, 66, 229, 244))
	end
end


-- Explicit request context. Nested helpers inherit their caller's context.
V2:RegisterPolicy({
    methods={
        AutoR=function()return {priority='interactive'}end,
        OnPreAttack=function()local mode=GetMode();return mode and V2:ModeContext(mode) or nil end,

        Combo=function()return V2:ModeContext("Combo")end,
        Harass=function()return V2:ModeContext("Harass")end,
        LaneClear=function()return V2:ModeContext("LaneClear",function()return Menu.Clear.SpellFarm:Value()end)end,
        JungleClear=function()return V2:ModeContext("LaneClear",function()return Menu.Clear.SpellFarm:Value()end)end,
        FarmHarass=function()return V2:ModeContext("LaneClear",function()return Menu.Clear.SpellHarass:Value() and not IsUnderTurret(myHero)end)end,
        LastHit=function()return V2:ModeContext(GetMode() == "LastHit" and "LastHit" or "LaneClear")end,
        ELogic=function()return V2:HeldContext(function()return Menu.EHelper.Enable:Value() and (Control.IsKeyDown(Menu.EHelper.efake:Key()) or Control.IsKeyDown(Menu.EHelper.elol:Key()))end)end,
        SemiR=function()return V2:HeldContext(function()return Menu.Combo.SemiR:Value()end)end,
    },
    exceptions={non_interrupting_summoner=true},
    channel=function(self,q)return not (myHero.activeSpell and myHero.activeSpell.valid and myHero.activeSpell.isChanneling) end,
    validate=function(self,q,slot,resolved)
        if q.owner=='EHelper' then return Menu.EHelper.Enable:Value() and not Control.IsKeyDown(HK_LUS) and GetTickCount()>=LastChatOpenTimer+1000 and GetTickCount()>=LevelUpKeyTimer+1000 end
        if slot==_Q and (q.owner=='LastHit' or q.owner=='ClearSpecialMinions') and q.object then
            local hp=SDK.HealthPrediction:GetPrediction(q.object,self.QSpell.Delay+GetDistance(q.object.pos,myHero.pos)/self.QSpell.Speed)
            return hp>0 and self:GetQDmg(q.object)>=hp
        end
        return true
    end,
})

ClassicEzreal()

end
if champion=="Fiora" then
local Version = 1.03

if myHero.charName ~= "Jade_Fiora" then return end


local WAttackList = {
	["Jade_Leona"] = {"Jade_LeonaShieldOfDaybreakAttack", "Jade_LeonaShieldOfDaybreak"},
	["Jade_Blitzcrank"] = {"Jade_BlitzcrankPowerFistAttack", "Jade_BlitzcrankPowerFist"},
	["Jade_Garen"] = {"Jade_GarenQAttack", "Jade_GarenQ"},
	["Jade_XinZhao"] = {"Jade_XinZhaoQ_Thrust3", "Jade_XinZhaoQ_Knockup"},
	["Jade_TwistedFate"] = {"Jade_TwistedFate_GoldCardAttack", "Jade_TwistedFate_RedCardAttack", "Jade_TwistedFate_GoldCardLock", "Jade_TwistedFate_RedCardLock"},
	["Jade_Jax"] = {"Jade_JaxWAttack", "Jade_JaxW", "Jade_JaxRPassiveAttack"},
	["Jade_Nasus"] = {"Jade_NasusSiphoningStrikeAttack", "Jade_NasusQ"},
	["Jade_Wukong"] = {"Jade_WukongQ"},
	["Jade_Vayne"] = {"Jade_VayneQ_Attack", "Jade_VayneQ_Bonus"},
	["Jade_Shyvana"] = {"Jade_ShyvanaQ"},
	["Jade_Sivir"] = {"Jade_SivirWAttack", "Jade_SivirW"},
	["Jade_Kassadin"] = {"Jade_KassadinW", "Jade_KassadinW_Buff"},
	["Jade_Nidalee"] = {"Jade_NidaleeTakedown"},
	["Jade_Sona"] = {"Jade_SonaQ_Attack", "Jade_SonaW_Attack", "Jade_SonaE_Attack"},
	["Jade_Shaco"] = {"Jade_ShacoDeceive", "Jade_ShacoDeceiveCritBonus", "Jade_ShacoFromBehind"},
	["Jade_Kennen"] = {"Jade_KennenWPassiveProc"},
	["Jade_Ashe"] = {"Jade_AsheFrostArrow", "Jade_AsheQ"},
	["Jade_KogMaw"] = {"Jade_KogMawWAttack", "Jade_KogMawW"},
	["Jade_Twitch"] = true,
	["Jade_MasterYi"] = {"Jade_MasterYiWujuStyle", "Jade_MasterYiWujuStyleSuperCharged", "Jade_MasterYiDoubleStrike"},
	["Jade_Olaf"] = {"Jade_OlafW"},
	["Jade_DrMundo"] = {"Jade_DrMundoE"},
	["Jade_Chogath"] = {"Jade_ChogathE"},
	["Jade_Poppy"] = {"Jade_PoppyW", "Jade_PoppyW_Stats"},
	["Jade_Fiora"] = {"Jade_FioraE"},
	["Jade_Tristana"] = {"Jade_TristanaQ"},
	["Jade_Teemo"] = {"Jade_TeemoE_Attack", "Jade_TeemoE"},
	["Jade_Taric"] = true,
}

local ClassicFiora=class("ClassicFiora")

function ClassicFiora:__init()
	self.QRange = 600
	self.RRange = 400
	self.lastCast = -math.huge
	self.lastSpell = {}
	self.rPendingUntil = 0
	self.incomingAttacks = {}
	self:LoadMenu()
	Callback.Add("Tick", function() self:Tick() end)
	Callback.Add("Draw", function() self:Draw() end)
	_G.SDK.Orbwalker:OnPreAttack(function(args)
		if self:RActive() then args.Process = false; return end
		self.attackTarget = args.Target
	end)
	_G.SDK.Orbwalker:OnPostAttack(function(args) self:OnPostAttack(args) end)
	_G.SDK.Orbwalker:OnPreMovement(function(args)
		if self:RActive() then args.Process = false end
	end)

end

function ClassicFiora:LoadMenu()
	local championIcon = "https://raw.communitydragon.org/16.18/game/assets/characters/jade_fiora/hud/jade_fiora_square_301.png"
	Menu = MenuElement({type = MENU, id = "Classic_AIO_" .. myHero.charName, name = "Classic AIO - " .. myHero.charName .. " V: " .. Version, leftIcon = championIcon})
	Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
	Menu.Combo:MenuElement({id = "Q", name = "Use Q", value = true})
	Menu.Combo:MenuElement({id = "HoldQ2", name = "Save Second Q For Chase / Expiry", value = true})
	Menu.Combo:MenuElement({id = "SafeQ", name = "Do Not Q Into Enemy Turret", value = true})
	Menu.Combo:MenuElement({id = "QMinion", name = "Q Minion To Close Gap", value = true})
	Menu.Combo:MenuElement({id = "QMinionRange", name = "Gap Close Enemy Range", value = 1000, min = 600, max = 1200, step = 25})
	Menu.Combo:MenuElement({id = "E", name = "Use E After Attack (Reset)", value = true})
	Menu.Combo:MenuElement({id = "R", name = "Use R When Killable", value = true})
	Menu.Combo:MenuElement({id = "RHP", name = "Also R When My HP <= % (0: Off)", value = 25, min = 0, max = 60, step = 5})
	Menu.Combo:MenuElement({id = "SafeR", name = "Do Not R Into Enemy Turret", value = true})
	Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
	Menu.Harass:MenuElement({id = "Q", name = "Use Q", value = true})
	Menu.Harass:MenuElement({id = "E", name = "Use E After Attack", value = true})
	Menu.Harass:MenuElement({id = "Mana", name = "Mana Percent >=", value = 40, min = 0, max = 100, step = 5})
	Menu:MenuElement({type = MENU, id = "Clear", name = "Clear"})
	Menu.Clear:MenuElement({id = "Enabled", name = "Use Spell Farm (Mouse Scroll)", toggle = true, value = false, key = 4, callback = function(v) CheckChatBlock(Menu.Clear.Enabled, v) end})
	Menu.Clear:MenuElement({id = "Mana", name = "Mana Percent >=", value = 30, min = 0, max = 100, step = 5})
	Menu.Clear:MenuElement({id = "LaneQ", name = "Lane / LastHit: Q Last Hit", value = true})
	Menu.Clear:MenuElement({id = "LaneE", name = "Lane: E After Attack", value = true})
	Menu.Clear:MenuElement({id = "JungleQ", name = "Jungle: Use Q", value = true})
	Menu.Clear:MenuElement({id = "JungleW", name = "Jungle: W Incoming Attacks", value = true})
	Menu.Clear:MenuElement({id = "JungleE", name = "Jungle: E After Attack", value = true})
	Menu:MenuElement({type = MENU, id = "KillSteal", name = "KillSteal"})
	Menu.KillSteal:MenuElement({id = "Q", name = "Auto Q", value = true})
	Menu.KillSteal:MenuElement({id = "R", name = "Auto R", value = true})
	Menu:MenuElement({type = MENU, id = "Misc", name = "Misc"})
	Menu.Misc:MenuElement({id = "AutoW", name = "Auto W Incoming Champion Attacks", value = true})
	Menu.Misc:MenuElement({id = "WNormalHP", name = "W: Normal Attacks Only Below My HP % (0 = Never)", value = 70, min = 0, max = 100, step = 5})
	Menu.Misc:MenuElement({id = "WLead", name = "W Before Attack Impact (ms)", value = 200, min = 50, max = 500, step = 25})
	Menu.Misc:MenuElement({id = "FleeQ", name = "Flee: Q Through Enemies Toward Mouse", value = true})
	Menu.Misc:MenuElement({id = "SemiR", name = "Semi-manual R", key = string.byte("T")})
	Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
	Menu.Draw:MenuElement({id = "Q", name = "Draw Q Range", value = false})
	Menu.Draw:MenuElement({id = "R", name = "Draw R Range", value = false})
	Menu.Draw:MenuElement({id = "Farm", name = "Draw Farm Status", value = true})
end

function ClassicFiora:ManaPercent()
	return myHero.maxMana > 0 and myHero.mana / myHero.maxMana * 100 or 100
end

function ClassicFiora:QRecast()
	return HaveBuff(myHero, "Jade_FioraQ_CD")
end

function ClassicFiora:QExpiring()
	local active, buff = GetBuffData(myHero, "Jade_FioraQ_CD")
	return active and buff.expireTime > 0 and buff.expireTime - Game.Timer() <= 0.45
end

function ClassicFiora:RActive()
	if myHero.dead then return false end
	local spell = myHero.activeSpell
	local casting = spell and spell.valid and (spell.name == "Jade_FioraR" or spell.name == "Jade_FioraR_Strike")
		and (spell.isChanneling or Game.Timer() <= (spell.endTime or spell.castEndTime or 0))
	if casting then self.rObservedUntil = Game.Timer() + 3 end
	return Game.Timer() < self.rPendingUntil
		or HaveBuff(myHero, "Jade_FioraR") or HaveBuff(myHero, "Jade_FioraR_Strike")
		or casting or (myHero.isTargetable == false
			and Game.Timer() < math.max(self.rObservedUntil or 0, (self.lastSpell[_R] or -math.huge) + 3))
end

function ClassicFiora:Ready(slot)
	local spell = myHero:GetSpellData(slot)
	-- Q's free second cast can retain the first cast's mana value in spell data.
	return spell.level > 0 and spell.currentCd == 0 and Game.CanUseSpell(slot) == 0
		and ((slot == _Q and self:QRecast()) or spell.mana <= myHero.mana)
end

function ClassicFiora:Cast(slot, key, target, options)
	local now = Game.Timer()
	if not self:Ready(slot) or now - self.lastCast < 0.15 or now - (self.lastSpell[slot] or -math.huge) < 0.3 then return false end
	if not V2:Cast(key,target,options) then return false end
	V2:AfterCast(key,function()
        local observed=Game.Timer();self.lastCast,self.lastSpell[slot]=observed,observed
        if slot==_R then self.rPendingUntil=observed+.4 end
    end)
	return true
end

function ClassicFiora:CanTarget(target, range, safe)
	if not IsValid(target) or not target.pos2D.onScreen or GetDistance(myHero.pos, target.pos) > range then return false end
	if target.type == Obj_AI_Hero and (IsInvulnerable(target) or _G.SDK.ObjectManager:IsHeroImmortal(target, false)) then return false end
	return not safe or IsUnderTurret(myHero) or not IsUnderTurret2(target.pos)
end

function ClassicFiora:CastQ(target, safe)
	if not self:CanTarget(target, self.QRange, safe) then return false end
	if not self:Cast(_Q, HK_Q, target) then return false end
	if target.type == Obj_AI_Hero then self.comboTarget, self.comboTargetUntil = target, Game.Timer() + 4 end
	return true
end

function ClassicFiora:CastQMinion(target)
	-- Dash to an enemy minion only when it leaves the hero inside Q range and closes the gap.
	if not Menu.Combo.QMinion:Value() or target.type ~= Obj_AI_Hero or not self:Ready(_Q) then return false end
	local targetDistance = GetDistance(myHero.pos, target.pos)
	if targetDistance <= self.QRange or targetDistance > Menu.Combo.QMinionRange:Value() then return false end
	local safe, best, bestDistance = Menu.Combo.SafeQ:Value(), nil, nil
	for _, minion in ipairs(_G.SDK.ObjectManager:GetEnemyMinions(self.QRange)) do
		if self:CanTarget(minion, self.QRange, safe) then
			local distance = GetDistance(minion.pos, target.pos)
			if distance <= self.QRange and distance < targetDistance - 100 and (not bestDistance or distance < bestDistance) then
				best, bestDistance = minion, distance
			end
		end
	end
	if best then return self:CastQ(best, safe) end
	return false
end

function ClassicFiora:GetComboTarget()
	local range = math.max(self.QRange, self.RRange)
	if self.comboTargetUntil and Game.Timer() < self.comboTargetUntil and self:CanTarget(self.comboTarget, range, false) then return self.comboTarget end
	return GetTarget(range)
end

function ClassicFiora:CanFarm()
	return Menu.Clear.Enabled:Value() and self:ManaPercent() >= Menu.Clear.Mana:Value() and not IsUnderTurret(myHero)
end

function ClassicFiora:Tick()
	if ShouldWait() or self:RActive() then return end
	if self:AutoW() then return end
	if IsCasting() or (myHero.pathing and myHero.pathing.isDashing) or _G.SDK.Orbwalker:IsAutoAttacking() then return end
	if Menu.Misc.SemiR:Value() then
		local target = GetTarget(self.RRange)
		if self:CanTarget(target, self.RRange, Menu.Combo.SafeR:Value()) and self:Cast(_R, HK_R, target,{context=V2:HeldContext(function()return Menu.Misc.SemiR:Value()end)}) then return end
	end
	local mode = GetMode()
	if mode == "Flee" then self:Flee(); return end
	if self:KillSteal() then return end
	if mode == "Combo" then
		self:Combo()
	elseif mode == "Harass" then
		self:Harass()
	elseif mode == "LaneClear" or mode == "LastHit" then
		self:Clear(mode == "LastHit")
	end
end

function ClassicFiora:OnPostAttack(args)
	local target = (args and args.Target) or self.attackTarget or _G.SDK.Orbwalker:GetTarget()
	self.attackTarget = nil
	if ShouldWait() or self:RActive() or IsCasting() or not IsValid(target) then return end
	local mode = GetMode()
	local useE, useQ, safe = false, false, true
	if mode == "Combo" and target.type == Obj_AI_Hero then
		useE, useQ, safe = Menu.Combo.E:Value(), Menu.Combo.Q:Value(), Menu.Combo.SafeQ:Value()
	elseif mode == "Harass" and target.type == Obj_AI_Hero and self:ManaPercent() >= Menu.Harass.Mana:Value() then
		useE, useQ = Menu.Harass.E:Value(), Menu.Harass.Q:Value()
	elseif mode == "LaneClear" and target.type == Obj_AI_Minion and self:CanFarm() then
		useE = target.team == 300 and Menu.Clear.JungleE:Value() or (target.team ~= 300 and Menu.Clear.LaneE:Value())
	end
	if useE and _G.SDK.Data:IsInAutoAttackRange(myHero, target) and not HaveBuff(myHero, "Jade_FioraE") then
		-- GGOrbwalker already registers Jade_Fiora E as an attack reset.
		if self:Cast(_E, HK_E) then return end
	end
	if useQ and (not self:QRecast() or not Menu.Combo.HoldQ2:Value() or self:QExpiring()) then self:CastQ(target, safe) end
end

function ClassicFiora:Combo()
	local target = self:GetComboTarget()
	if not IsValid(target) and Menu.Combo.QMinion:Value() then target = GetTarget(Menu.Combo.QMinionRange:Value()) end
	if not IsValid(target) then return end
	if Menu.Combo.R:Value() and self:CanTarget(target, self.RRange, Menu.Combo.SafeR:Value()) then
		local hp = target.health + (target.shieldAD or 0) + (target.hpRegen or 0) * 2
		local lowHP = Menu.Combo.RHP:Value() > 0 and myHero.health / myHero.maxHealth * 100 <= Menu.Combo.RHP:Value()
		if self:GetRDmg(target) >= hp or lowHP then
			if self:Cast(_R, HK_R, target) then return end
		end
	end
	if Menu.Combo.Q:Value() and (not _G.SDK.Data:IsInAutoAttackRange(myHero, target) or self:QExpiring()) then
		if not self:CastQ(target, Menu.Combo.SafeQ:Value()) and GetDistance(myHero.pos, target.pos) > self.QRange then self:CastQMinion(target) end
	end
end

function ClassicFiora:Harass()
	if self:ManaPercent() < Menu.Harass.Mana:Value() or not Menu.Harass.Q:Value() then return end
	local target = self:GetComboTarget()
	if IsValid(target) and (not _G.SDK.Data:IsInAutoAttackRange(myHero, target) or self:QExpiring()) then self:CastQ(target, true) end
end

function ClassicFiora:ListedAttack(source)
	if source.charName == "Jade_Vayne" then
		local active, buff = GetBuffData(myHero, "Jade_VayneW_Debuff")
		if active and (buff.count or buff.stacks or 0) >= 2 then return true end
	end
	local names = WAttackList[source.charName]
	if names == true then return true end
	if not names then return false end
	local spell = source.activeSpell
	local spellName = spell and spell.valid and spell.name
	for _, name in ipairs(names) do
		if spellName == name or HaveBuff(source, name) then return true end
	end
	return false
end

function ClassicFiora:AutoW()
	if not self:Ready(_W) or HaveBuff(myHero, "Jade_FioraW") then return false end
	local now = Game.Timer()
	local jungle = GetMode() == "LaneClear" and self:CanFarm() and Menu.Clear.JungleW:Value()
	local sources = {}
	if Menu.Misc.AutoW:Value() then
		for _, unit in ipairs(_G.SDK.ObjectManager:GetEnemyHeroes(1600)) do sources[#sources + 1] = unit end
	end
	if jungle then
		for _, unit in ipairs(_G.SDK.ObjectManager:GetMonsters(800)) do sources[#sources + 1] = unit end
	end
	for _, source in ipairs(sources) do
		local spell = source.activeSpell
		if IsValid(source) and spell and spell.valid and not spell.isStopped and spell.target == myHero.handle
			and (spell.isAutoAttack or _G.SDK.Data:IsAttack(spell.name or "")) then
			local attack = source.attackData or {}
			local launch = spell.castEndTime
			if not launch or launch <= 0 then launch = (spell.startTime or now) + (spell.windup or attack.windUpTime or 0) end
			local speed = spell.speed and spell.speed > 0 and spell.speed or attack.projectileSpeed
			local travel = 0
			if (source.range or 125) >= 300 and speed and speed > 0 then
				travel = math.max(0, GetDistance(source.pos, myHero.pos) - (source.boundingRadius or 0) - myHero.boundingRadius) / speed
			end
			local key = tostring(source.handle) .. ":" .. tostring(launch)
			if not self.incomingAttacks[key] or now <= launch then
				self.incomingAttacks[key] = {source = source, launch = launch, hit = launch + travel, start = spell.startTime}
			end
		end
	end
	local lead = Menu.Misc.WLead:Value() / 1000 + _G.SDK.Data:GetLatency()
	local hpLimit = Menu.Misc.WNormalHP:Value()
	local lowHp = hpLimit > 0 and myHero.maxHealth > 0 and myHero.health / myHero.maxHealth * 100 <= hpLimit
	for key, attack in pairs(self.incomingAttacks) do
		local source, spell = attack.source, attack.source.activeSpell
		local empowered = source.type == Obj_AI_Hero and self:ListedAttack(source)
		local enabled = source.type == Obj_AI_Hero and Menu.Misc.AutoW:Value() and (empowered or lowHp)
			or (source.team == 300 and jungle)
		local cancelled = now < attack.launch and (not spell or not spell.valid or spell.isStopped or spell.target ~= myHero.handle or spell.startTime ~= attack.start)
		if not enabled or cancelled or now > attack.hit + 0.05 then
			self.incomingAttacks[key] = nil
		elseif attack.hit - now <= lead then
			if self:Cast(_W, HK_W) then self.incomingAttacks = {}; return true end
		end
	end
	return false
end

function ClassicFiora:Clear(lastHitOnly)
	if not self:CanFarm() then return end
	if not lastHitOnly and Menu.Clear.JungleQ:Value() then
		local monsters = _G.SDK.ObjectManager:GetMonsters(self.QRange)
		table.sort(monsters, function(a, b) return a.maxHealth > b.maxHealth end)
		for _, monster in ipairs(monsters) do
			if self:CastQ(monster, true) then return end
		end
	end
	if not Menu.Clear.LaneQ:Value() or not self:Ready(_Q) then return end
	for _, minion in ipairs(_G.SDK.ObjectManager:GetEnemyMinions(self.QRange)) do
		if minion.team ~= 300 and self:CanTarget(minion, self.QRange, true) then
			local hp = _G.SDK.HealthPrediction:GetPrediction(minion, 0.1 + GetDistance(myHero.pos, minion.pos) / 1200)
			if hp > 0 and self:GetQDmg(minion) >= hp + (minion.shieldAD or 0) and self:CastQ(minion, true) then return end
		end
	end
end

function ClassicFiora:Flee()
	if not Menu.Misc.FleeQ:Value() or not self:Ready(_Q) then return end
	local best, bestDistance = nil, 0
	local mouseDistance = GetDistance(myHero.pos, mousePos) - 100
	for _, units in ipairs({_G.SDK.ObjectManager:GetEnemyHeroes(self.QRange), _G.SDK.ObjectManager:GetEnemyMinions(self.QRange), _G.SDK.ObjectManager:GetMonsters(self.QRange)}) do
		for _, unit in ipairs(units) do
			local distance = GetDistance(myHero.pos, unit.pos)
			if distance > bestDistance and GetDistance(unit.pos, mousePos) < mouseDistance and self:CanTarget(unit, self.QRange, true) then best, bestDistance = unit, distance end
		end
	end
	if best then self:CastQ(best, true) end
end

function ClassicFiora:KillSteal()
	for _, target in ipairs(_G.SDK.ObjectManager:GetEnemyHeroes(math.max(self.QRange, self.RRange))) do
		local hp = target.health + (target.shieldAD or 0) + (target.hpRegen or 0)
		if Menu.KillSteal.Q:Value() and self:GetQDmg(target) >= hp and self:CastQ(target, true) then return true end
		if Menu.KillSteal.R:Value() and self:CanTarget(target, self.RRange, Menu.Combo.SafeR:Value())
			and self:GetRDmg(target) >= hp + (target.hpRegen or 0) and self:Cast(_R, HK_R, target) then return true end
	end
	return false
end

function ClassicFiora:GetQDmg(target)
	local level = myHero:GetSpellData(_Q).level
	if level == 0 then return 0 end
	-- Jade 16.18 cache: 40/65/90/115/140 + 0.60 bonus AD, physical.
	return _G.SDK.Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_PHYSICAL, 15 + 25 * level + 0.6 * myHero.bonusDamage)
end

function ClassicFiora:GetRDmg(target)
	local level = myHero:GetSpellData(_R).level
	if level == 0 then return 0 end
	local damage = ({160, 330, 500})[level] + 1.15 * myHero.bonusDamage
	-- Blade Waltz: five strikes; repeated hits deal 25%. Only assume all five
	-- hit one champion when no other enemy is inside the 600-unit bounce radius.
	local isolated = true
	for _, enemy in ipairs(_G.SDK.ObjectManager:GetEnemyHeroes()) do
		if enemy.networkID ~= target.networkID and GetDistance(enemy.pos, target.pos) <= 600 then isolated = false; break end
	end
	if isolated then damage = damage * (1 + 4 * 0.25) end
	return _G.SDK.Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_PHYSICAL, damage)
end

function ClassicFiora:Draw()
	if myHero.dead then return end
	if Menu.Draw.Farm:Value() then Draw.Text(Menu.Clear.Enabled:Value() and "Spell Farm: On" or "Spell Farm: Off", 16, myHero.pos2D.x - 55, myHero.pos2D.y + 60, Draw.Color(200, 242, 120, 34)) end
	if Menu.Draw.Q:Value() and self:Ready(_Q) then Draw.Circle(myHero.pos, self.QRange, 1, Draw.Color(255, 66, 244, 113)) end
	if Menu.Draw.R:Value() and self:Ready(_R) then Draw.Circle(myHero.pos, self.RRange, 1, Draw.Color(255, 244, 120, 66)) end
end


-- Explicit request context. Nested helpers inherit their caller's context.
V2:RegisterPolicy({
    damageTypes={Q='physical',R='physical'},
    methods={
        AutoW=function()return {priority='interactive'}end,
        OnPostAttack=function()local mode=GetMode();return mode and V2:ModeContext(mode) or nil end,

        Combo=function()return V2:ModeContext("Combo")end,
        Harass=function()return V2:ModeContext("Harass")end,
        Clear=function()return V2:ModeContext(GetMode() == "LastHit" and "LastHit" or "LaneClear")end,
        Flee=function()return V2:ModeContext("Flee")end,
    },
    costPaid=function(self,q,slot)return slot==_Q and self:QRecast() end,
    exceptions={non_interrupting_summoner=true},
    channel=function(self,q)return not self:RActive() end,
    validate=function(self,q,slot,resolved)
        if slot and slot<=_R then
            if not self:Ready(slot)then return false end
            if q.object and slot==_R then return self:CanTarget(q.object,self.RRange,Menu.Combo.SafeR:Value())end
        end
        return true
    end,
})

ClassicFiora()

end
if champion=="Janna" then
local Version = 1.01


local ClassicJanna=class("ClassicJanna")

function ClassicJanna:__init()

	self.QSpell = { Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.15, Radius = 100, Range = 1100, Speed = 900, Collision = false }
	self.WRange, self.ERange, self.RRange = 550, 800, 600
	self.qStart = 0
	self.qTarget = nil
	self:LoadMenu()
	Callback.Add("Tick", function() self:Tick() end)
	Callback.Add("Draw", function() self:Draw() end)
end

function ClassicJanna:LoadMenu()
	local icon = "http://ddragon.leagueoflegends.com/cdn/16.15.1/img/champion/" .. myHero.charName .. ".png"
	Menu = MenuElement({ type = MENU, id = "Classic_AIO_" .. myHero.charName, name = "Classic AIO - " .. myHero.charName .. " V: " .. Version, leftIcon = icon })
	Menu:MenuElement({ type = MENU, id = "Combo", name = "Combo" })
	Menu.Combo:MenuElement({ id = "Q", name = "Use Q", value = true })
	Menu.Combo:MenuElement({ id = "W", name = "Use W", value = true })
	Menu:MenuElement({ type = MENU, id = "Harass", name = "Harass" })
	Menu.Harass:MenuElement({ id = "Q", name = "Use Q", value = true })
	Menu.Harass:MenuElement({ id = "W", name = "Use W", value = true })
	Menu.Harass:MenuElement({ id = "Mana", name = "Mana Percent >=", value = 40, min = 0, max = 100, step = 5 })
	Menu:MenuElement({ type = MENU, id = "Clear", name = "Clear" })
	Menu.Clear:MenuElement({ id = "Enabled", name = "Use Spell Farm (Mouse Scroll)", toggle = true, value = false, key = 4, callback = function(v) CheckChatBlock(Menu.Clear.Enabled, v) end })
	Menu.Clear:MenuElement({ id = "Q", name = "Use Q | Minions >=", value = 3, min = 1, max = 6, step = 1 })
	Menu.Clear:MenuElement({ id = "W", name = "Use W In Jungle", value = true })
	Menu.Clear:MenuElement({ id = "Mana", name = "Mana Percent >=", value = 30, min = 0, max = 100, step = 5 })
	Menu:MenuElement({ type = MENU, id = "Auto", name = "Auto Support" })
	Menu.Auto:MenuElement({ id = "E", name = "Auto E Shield", toggle = true, value = true })
	Menu.Auto:MenuElement({ type = MENU, id = "Etarget", name = "Use E On" })
	_G.SDK.ObjectManager:OnAllyHeroLoad(function(args)
		Menu.Auto.Etarget:MenuElement({ id = args.charName, name = args.charName, value = true })
	end)
	Menu.Auto:MenuElement({ id = "R", name = "Auto R Self HP <= x%", value = 25, min = 0, max = 100, step = 5 })
	Menu.Auto:MenuElement({ id = "AntiDash", name = "Auto Q Anti-Dash", value = true })
	Menu:MenuElement({ type = MENU, id = "KillSteal", name = "KillSteal" })
	Menu.KillSteal:MenuElement({ id = "W", name = "Auto W", value = true })
	Menu:MenuElement({ type = MENU, id = "Draw", name = "Draw" })
	for _, s in ipairs({ "Q", "W", "E", "R" }) do
		Menu.Draw:MenuElement({ id = s, name = "Draw " .. s .. " Range", value = false })
	end
	Menu.Draw:MenuElement({ id = "Farm", name = "Draw Farm Status", value = true })
end

function ClassicJanna:IsQCharging() return HaveBuff(myHero, "Jade_JannaHowlingGale") or myHero:GetSpellData(_Q).name == "Jade_JannaHowlingGaleSpell" end
function ClassicJanna:IsChannelingR()
	local a = myHero.activeSpell
	return HaveBuff(myHero, "Jade_JannaReapTheWhirlwind") or (a and a.valid and a.name == "Jade_JannaReapTheWhirlwind")
end

function ClassicJanna:Tick()
	local channel = self:IsChannelingR()
	_G.SDK.Orbwalker:SetAttack(not channel)
	_G.SDK.Orbwalker:SetMovement(not channel)
	if channel then return end
	if ShouldWait() then return end
	if self:HandleQ() then return end
	if IsCasting() then return end
	self:AutoR()
	self:AutoE()
	self:AntiDash()
	self:KillSteal()
	local mode = GetMode()
	if mode == "Combo" then
		self:Combo()
	elseif mode == "Harass" then
		self:Harass()
	elseif mode == "LaneClear" then
		self:Clear()
	elseif mode == "Flee" then
		self:Flee()
	end
end

function ClassicJanna:HandleQ()
	if not self:IsQCharging() then return false end
	local elapsed = GetTickCount() - self.qStart
	if elapsed >= 250 and ((IsValid(self.qTarget) and IsHardCC(self.qTarget)) or elapsed >= 650) then
		if Control.CastSpell(HK_Q) then V2:AfterCast(HK_Q,function()self.qTarget=nil end) end
		return true
	end
	return true
end

function ClassicJanna:StartQ(target, hc)
	if not IsReady(_Q) or self:IsQCharging() then return false end
	local p = GGPrediction:SpellPrediction(self.QSpell)
	p:GetPrediction(target, myHero)
	if p:CanHit(hc or 2) then
		if not Control.CastSpell(HK_Q, p.CastPosition) then return false end
		V2:AfterCast(HK_Q, function() self.qStart = GetTickCount() end)
		V2:AfterCast(HK_Q, function() self.qTarget = target end)
		return true
	end
	return false
end

function ClassicJanna:Combo()
	local target = GetTarget(self.QSpell.Range)
	if not IsValid(target) or not target.pos2D.onScreen then return end
	if Menu.Combo.Q:Value() and self:StartQ(target, 2) then return end
	if Menu.Combo.W:Value() and IsReady(_W) and target.distance <= self.WRange then Control.CastSpell(HK_W, target) end
end

function ClassicJanna:Harass()
	if myHero.maxMana > 0 and myHero.mana / myHero.maxMana * 100 < Menu.Harass.Mana:Value() then return end
	local target = GetTarget(self.QSpell.Range)
	if not IsValid(target) or not target.pos2D.onScreen then return end
	if Menu.Harass.Q:Value() and self:StartQ(target, 3) then return end
	if Menu.Harass.W:Value() and IsReady(_W) and target.distance <= self.WRange then Control.CastSpell(HK_W, target) end
end

function ClassicJanna:AutoE()
	if not Menu.Auto.E:Value() or not IsReady(_E) or lastE + 250 >= GetTickCount() then return end
	local enemies = _G.SDK.ObjectManager:GetEnemyHeroes(2500)
	local allies = _G.SDK.ObjectManager:GetAllyHeroes(self.ERange)
	local turrets = _G.SDK.ObjectManager:GetEnemyTurrets(1500)
	for _, ally in ipairs(allies) do
		local option = Menu.Auto.Etarget[ally.charName]
		if IsValid(ally) and option and option:Value() then
			local canuse = IsPoison(ally)
			if not canuse then
				for _, enemy in ipairs(enemies) do
					if IsValid(enemy) then
						local spell = enemy.activeSpell
						if spell and spell.valid then
							if spell.target == ally.handle then
								canuse = true
								break
							else
								local spellWidth = spell.width or 0
								local endPos = spell.startPos:Extended(spell.placementPos, (spell.range or 0) + spellWidth)
								local point, isOnSegment = GGPrediction:ClosestPointOnLineSegment(ally.pos, endPos, enemy.pos)
								local width = ally.boundingRadius + (spellWidth > 0 and spellWidth or 0)
								if isOnSegment and GGPrediction:IsInRange(point, ally.pos, width) then
									canuse = true
									break
								end
							end
						end
					end
				end
				if not canuse then
					for _, turret in ipairs(turrets) do
						if turret and turret.targetID == ally.networkID then
							canuse = true
							break
						end
					end
				end
			end
			if canuse then
				self:CastE(ally)
				V2:AfterCast(HK_E, function() lastE = GetTickCount() end)
				break
			end
		end
	end
end

function ClassicJanna:CastE(unit)
	if unit.isMe then
		return Control.CastSpell(HK_E, myHero)
	else
		Control.CastSpell(HK_E, unit)
	end
end

function ClassicJanna:AutoR()
	if not IsReady(_R) or Menu.Auto.R:Value() == 0 then return end
	local hp = myHero.maxHealth > 0 and myHero.health / myHero.maxHealth * 100 or 100
	if hp <= Menu.Auto.R:Value() and GetEnemyCount(self.RRange, myHero.pos) > 0 then Control.CastSpell(HK_R) end
end

function ClassicJanna:AntiDash()
	if not Menu.Auto.AntiDash:Value() or not IsReady(_Q) then return end
	for _, t in ipairs(_G.SDK.ObjectManager:GetEnemyHeroes(self.QSpell.Range)) do
		if IsValid(t) and t.pathing and t.pathing.isDashing and t.posTo and myHero.pos:DistanceTo(t.posTo) < 500 then
			if self:StartQ(t, 2) then
				V2:AfterCast(HK_Q, function() self.qStart = GetTickCount() - 500 end)
				return
			end
		end
	end
end

function ClassicJanna:Clear()
	if not Menu.Clear.Enabled:Value() or IsUnderTurret(myHero) then return end
	if myHero.maxMana > 0 and myHero.mana / myHero.maxMana * 100 < Menu.Clear.Mana:Value() then return end
	if Menu.Clear.Q:Value() > 0 and IsReady(_Q) then
		for _, m in ipairs(_G.SDK.ObjectManager:GetEnemyMinions(self.QSpell.Range)) do
			if IsValid(m) and GetMinionCount(200, m.pos) >= Menu.Clear.Q:Value() then
				Control.CastSpell(HK_Q, m.pos)
				V2:AfterCast(HK_Q, function() self.qStart = GetTickCount() - 200 end)
				self.qTarget = nil
				return
			end
		end
	end
	if Menu.Clear.W:Value() and IsReady(_W) then
		local monsters = _G.SDK.ObjectManager:GetMonsters(self.WRange)
		if IsValid(monsters[1]) then Control.CastSpell(HK_W, monsters[1]) end
	end
end

function ClassicJanna:Flee()
	if IsReady(_E) then
		Control.CastSpell(HK_E, myHero)
		return
	end
	local target = GetTarget(self.WRange)
	if IsValid(target) and IsReady(_W) then
		Control.CastSpell(HK_W, target)
		return
	end
	if IsReady(_Q) then
		Control.CastSpell(HK_Q, mousePos)
		V2:AfterCast(HK_Q, function() self.qStart = GetTickCount() - 200 end)
	end
end

function ClassicJanna:KillSteal()
	if not Menu.KillSteal.W:Value() or not IsReady(_W) then return end
	for _, t in ipairs(_G.SDK.ObjectManager:GetEnemyHeroes(self.WRange)) do
		if IsValid(t) and t.pos2D.onScreen and self:GetWDmg(t) >= t.health + (t.hpRegen or 0) + (t.shieldAP or 0) then
			Control.CastSpell(HK_W, t)
			return
		end
	end
end

function ClassicJanna:GetWDmg(t)
	local l = myHero:GetSpellData(_W).level
	if l == 0 then return 0 end
	return _G.SDK.Damage:CalculateDamage(myHero, t, _G.SDK.DAMAGE_TYPE_MAGICAL, ({ 60, 115, 170, 225, 280 })[l] + myHero.ap * 0.60)
end
function ClassicJanna:Draw()
	if myHero.dead then return end
	if Menu.Draw.Farm:Value() then Draw.Text(Menu.Clear.Enabled:Value() and "Spell Farm: On" or "Spell Farm: Off", 16, myHero.pos2D.x - 55, myHero.pos2D.y + 60, Draw.Color(200, 242, 120, 34)) end
	if Menu.Draw.Q:Value() and IsReady(_Q) then Draw.Circle(myHero.pos, self.QSpell.Range, 1, Draw.Color(255, 66, 244, 113)) end
	if Menu.Draw.W:Value() and IsReady(_W) then Draw.Circle(myHero.pos, self.WRange, 1, Draw.Color(255, 244, 238, 66)) end
	if Menu.Draw.E:Value() and IsReady(_E) then Draw.Circle(myHero.pos, self.ERange, 1, Draw.Color(255, 66, 229, 244)) end
	if Menu.Draw.R:Value() and IsReady(_R) then Draw.Circle(myHero.pos, self.RRange, 1, Draw.Color(255, 244, 66, 96)) end
end


-- Explicit request context. Nested helpers inherit their caller's context.
V2:RegisterPolicy({
    damageTypes={W='magical'},
    methods={
        AutoE=function()return {priority='interactive'}end,
        AutoR=function()return {priority='interactive'}end,
        AntiDash=function()return {priority='interactive'}end,

        Combo=function()return V2:ModeContext("Combo")end,
        Harass=function()return V2:ModeContext("Harass")end,
        Clear=function()return V2:ModeContext("LaneClear")end,
        Flee=function()return V2:ModeContext("Flee")end,
    },
    costPaid=function(self,q,slot)return slot==_Q and q.owner=='HandleQ' and self:IsQCharging() end,
    exceptions={non_interrupting_summoner=true},
    channel=function(self,q)return not self:IsChannelingR() end,
    validate=function(self,q,slot,resolved)
        if q.owner=='HandleQ' then return slot==_Q and self:IsQCharging()end
        if slot==_Q and self:IsQCharging()then return false end
        if slot==_R and q.owner=='AutoR' then return myHero.health/myHero.maxHealth*100<=Menu.Auto.R:Value() and GetEnemyCount(self.RRange,myHero.pos)>0 end
        return true
    end,
})

ClassicJanna()

end
if champion=="Katarina" then
local Version = 1.02


local ClassicKatarina=class("ClassicKatarina")

function ClassicKatarina:__init()

	self:LoadMenu()
	Callback.Add("Draw", function() self:Draw() end)
	Callback.Add("Tick", function() self:Tick() end)
	self.QSpell = {Range = 675}
	self.WSpell = {Range = 400}
	self.ESpell = {Range = 700}
	self.RSpell = {Range = 500}
	self.comboTarget = nil
	self.comboTargetExpire = 0
	self.rCastLockUntil = 0
	self.rNextCastAttempt = 0
end

function ClassicKatarina:LoadMenu()
	local championIcon = "http://ddragon.leagueoflegends.com/cdn/16.15.1/img/champion/"..myHero.charName..".png"
	Menu = MenuElement({type = MENU, id = "Classic_AIO_"..myHero.charName, name = "Classic AIO - "..myHero.charName.." V: "..Version, leftIcon = championIcon})

	Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
	Menu.Combo:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "W", name = "Use W", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "E", name = "Use E", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "R", name = "Use R", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "RCount", name = "Use R | Enemy Count >=", value = 1, min = 1, max = 5, step = 1})
	Menu.Combo:MenuElement({id = "RMinHP", name = "Use R | Target HP >= x%", value = 15, min = 0, max = 100, step = 5})

	Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
	Menu.Harass:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	Menu.Harass:MenuElement({id = "W", name = "Use W", toggle = true, value = true})
	Menu.Harass:MenuElement({id = "E", name = "Use E", toggle = true, value = false})

	Menu:MenuElement({type = MENU, id = "Clear", name = "Clear"})
	Menu.Clear:MenuElement({id = "SpellFarm", name = "Use Spell Farm(Mouse Scroll)", toggle = true, value = false, key = 4, callback = function(newValue)
		if CheckChatBlock(Menu.Clear.SpellFarm, newValue) then return end
	end})
	Menu.Clear:MenuElement({id = "SpellHarass", name = "Use Spell Harass(In LaneClear Mode)", toggle = true, value = true, key = string.byte("H"), callback = function(newValue)
		if CheckChatBlock(Menu.Clear.SpellHarass, newValue) then return end
	end})
	Menu.Clear:MenuElement({type = MENU, id = "LaneClear", name = "LaneClear"})
	Menu.Clear.LaneClear:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	Menu.Clear.LaneClear:MenuElement({id = "QCount", name = "Use Q | Nearby Minions >=", value = 2, min = 1, max = 6, step = 1})
	Menu.Clear.LaneClear:MenuElement({id = "W", name = "Use W", toggle = true, value = true})
	Menu.Clear.LaneClear:MenuElement({id = "WCount", name = "Use W | Nearby Minions >=", value = 3, min = 1, max = 6, step = 1})
	Menu.Clear:MenuElement({type = MENU, id = "JungleClear", name = "JungleClear"})
	Menu.Clear.JungleClear:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	Menu.Clear.JungleClear:MenuElement({id = "W", name = "Use W", toggle = true, value = true})
	Menu.Clear.JungleClear:MenuElement({id = "E", name = "Use E", toggle = true, value = true})

	Menu:MenuElement({type = MENU, id = "KillSteal", name = "KillSteal"})
	Menu.KillSteal:MenuElement({id = "Q", name = "Auto Q KillSteal", toggle = true, value = true})
	Menu.KillSteal:MenuElement({id = "W", name = "Auto W KillSteal", toggle = true, value = true})
	Menu.KillSteal:MenuElement({id = "E", name = "Auto E KillSteal", toggle = true, value = true})

	Menu:MenuElement({type = MENU, id = "Misc", name = "Misc"})
	Menu.Misc:MenuElement({id = "SafeE", name = "Do Not E Under Enemy Turret", toggle = true, value = true})
	Menu.Misc:MenuElement({id = "FleeE", name = "Use E To Flee", toggle = true, value = true})

	Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
	Menu.Draw:MenuElement({id = "DrawFarm", name = "Draw Spell Farm Status", toggle = true, value = true})
	Menu.Draw:MenuElement({id = "DrawHarass", name = "Draw Spell Harass Status", toggle = true, value = true})
	Menu.Draw:MenuElement({id = "Q", name = "Draw Q Range", toggle = true, value = false})
	Menu.Draw:MenuElement({id = "W", name = "Draw W Range", toggle = true, value = false})
	Menu.Draw:MenuElement({id = "E", name = "Draw E Range", toggle = true, value = false})
	Menu.Draw:MenuElement({id = "R", name = "Draw R Range", toggle = true, value = false})
end

function ClassicKatarina:IsChannelingR()
	local activeSpell = myHero.activeSpell
	return GetTickCount() < self.rCastLockUntil
		or HaveBuff(myHero, "Jade_KatarinaRSound")
		or (activeSpell and activeSpell.valid and activeSpell.name == "Jade_KatarinaR")
end

function ClassicKatarina:Tick()
	local channelingR = self:IsChannelingR()
	_G.SDK.Orbwalker:SetAttack(not channelingR)
	_G.SDK.Orbwalker:SetMovement(not channelingR)
	if channelingR then return end
	if ShouldWait() then return end
	if IsCasting() then return end

	self:KillSteal()
	local mode = GetMode()
	if mode == "Combo" then
		self:Combo()
	elseif mode == "Harass" then
		self:Harass()
	elseif mode == "LaneClear" then
		self:FarmHarass()
		self:LaneClear()
		self:JungleClear()
	elseif mode == "Flee" then
		self:Flee()
	end
end

function ClassicKatarina:GetComboTarget(range)
	if GetTickCount() < self.comboTargetExpire and IsValid(self.comboTarget) then
		if myHero.pos:DistanceTo(self.comboTarget.pos) <= range then
			return self.comboTarget
		end
	end
	return GetTarget(range)
end

function ClassicKatarina:SetComboTarget(target)
	self.comboTarget = target
	self.comboTargetExpire = GetTickCount() + 2500
end

function ClassicKatarina:CanUseE(target)
	if not IsValid(target) or myHero.pos:DistanceTo(target.pos) > self.ESpell.Range then
		return false
	end
	if Menu.Misc.SafeE:Value() and not IsUnderTurret(myHero) and IsUnderTurret2(target.pos) then
		return false
	end
	return true
end

function ClassicKatarina:Combo()
	if Menu.Combo.Q:Value() and IsReady(_Q) then
		local target = self:GetComboTarget(self.QSpell.Range)
		if IsValid(target) and target.pos2D.onScreen then
			self:SetComboTarget(target)
			Control.CastSpell(HK_Q, target)
			return
		end
	end

	if Menu.Combo.E:Value() and IsReady(_E) then
		local target = self:GetComboTarget(self.ESpell.Range)
		if self:CanUseE(target) and target.pos2D.onScreen then
			self:SetComboTarget(target)
			Control.CastSpell(HK_E, target)
			return
		end
	end

	if Menu.Combo.W:Value() and IsReady(_W) then
		local target = self:GetComboTarget(self.WSpell.Range)
		if IsValid(target) and myHero.pos:DistanceTo(target.pos) <= self.WSpell.Range then
			Control.CastSpell(HK_W)
			return
		end
	end

	if Menu.Combo.R:Value() and IsReady(_R) and GetTickCount() >= self.rNextCastAttempt then
		local target = self:GetComboTarget(self.RSpell.Range)
		if IsValid(target) and target.maxHealth > 0 then
			local hpPercent = target.health / target.maxHealth * 100
			if hpPercent >= Menu.Combo.RMinHP:Value() and GetEnemyCount(self.RSpell.Range, myHero.pos) >= Menu.Combo.RCount:Value() then
                if V2:Cast(HK_R,nil,{independent=false,observe=function()
                    return HaveBuff(myHero,'Jade_KatarinaRSound') or myHero.activeSpell.valid and myHero.activeSpell.name=='Jade_KatarinaR'
                end}) then
                    V2:AfterCast(HK_R,function()self.rNextCastAttempt=GetTickCount()+1250 end)
                end
			end
		end
	end
end

function ClassicKatarina:Harass()
	if Menu.Harass.Q:Value() and IsReady(_Q) then
		local target = GetTarget(self.QSpell.Range)
		if IsValid(target) and target.pos2D.onScreen then
			Control.CastSpell(HK_Q, target)
			return
		end
	end
	if Menu.Harass.E:Value() and IsReady(_E) then
		local target = GetTarget(self.ESpell.Range)
		if self:CanUseE(target) and target.pos2D.onScreen then
			Control.CastSpell(HK_E, target)
			return
		end
	end
	if Menu.Harass.W:Value() and IsReady(_W) then
		local target = GetTarget(self.WSpell.Range)
		if IsValid(target) and myHero.pos:DistanceTo(target.pos) <= self.WSpell.Range then
			Control.CastSpell(HK_W)
		end
	end
end

function ClassicKatarina:FarmHarass()
	if Menu.Clear.SpellHarass:Value() and not IsUnderTurret(myHero) then
		self:Harass()
	end
end

function ClassicKatarina:LaneClear()
	if not Menu.Clear.SpellFarm:Value() or IsUnderTurret(myHero) then return end
	local minions = _G.SDK.ObjectManager:GetEnemyMinions(self.QSpell.Range)
	table.sort(minions, function(a, b) return myHero.pos:DistanceTo(a.pos) < myHero.pos:DistanceTo(b.pos) end)

	if Menu.Clear.LaneClear.W:Value() and IsReady(_W) then
		local count = 0
		for _, minion in ipairs(minions) do
			if IsValid(minion) and minion.team ~= 300 and myHero.pos:DistanceTo(minion.pos) <= self.WSpell.Range then
				count = count + 1
			end
		end
		if count >= Menu.Clear.LaneClear.WCount:Value() then
			Control.CastSpell(HK_W)
			return
		end
	end

	if Menu.Clear.LaneClear.Q:Value() and IsReady(_Q) then
		for _, minion in ipairs(minions) do
			if IsValid(minion) and minion.team ~= 300 and minion.pos2D.onScreen then
				if GetMinionCount(450, minion.pos) >= Menu.Clear.LaneClear.QCount:Value() then
					Control.CastSpell(HK_Q, minion)
					return
				end
			end
		end
	end
end

function ClassicKatarina:JungleClear()
	if not Menu.Clear.SpellFarm:Value() then return end
	local monsters = _G.SDK.ObjectManager:GetMonsters(self.ESpell.Range)
	table.sort(monsters, function(a, b) return a.maxHealth > b.maxHealth end)
	local monster = monsters[1]
	if not IsValid(monster) or not monster.pos2D.onScreen then return end

	if Menu.Clear.JungleClear.Q:Value() and IsReady(_Q) and myHero.pos:DistanceTo(monster.pos) <= self.QSpell.Range then
		Control.CastSpell(HK_Q, monster)
		return
	end
	if Menu.Clear.JungleClear.E:Value() and IsReady(_E) and myHero.pos:DistanceTo(monster.pos) <= self.ESpell.Range then
		Control.CastSpell(HK_E, monster)
		return
	end
	if Menu.Clear.JungleClear.W:Value() and IsReady(_W) and myHero.pos:DistanceTo(monster.pos) <= self.WSpell.Range then
		Control.CastSpell(HK_W)
	end
end

function ClassicKatarina:Flee()
	if not Menu.Misc.FleeE:Value() or not IsReady(_E) then return end
	local candidates = {}
	local allyHeroes = _G.SDK.ObjectManager:GetAllyHeroes(self.ESpell.Range)
	local allyMinions = _G.SDK.ObjectManager:GetAllyMinions()
	local enemyMinions = _G.SDK.ObjectManager:GetEnemyMinions(self.ESpell.Range)
	local monsters = _G.SDK.ObjectManager:GetMonsters(self.ESpell.Range)
	local wards = _G.SDK.ObjectManager:GetOtherMinions(self.ESpell.Range)

	for _, unit in ipairs(allyHeroes) do candidates[#candidates + 1] = unit end
	for _, unit in ipairs(allyMinions) do candidates[#candidates + 1] = unit end
	for _, unit in ipairs(enemyMinions) do candidates[#candidates + 1] = unit end
	for _, unit in ipairs(monsters) do candidates[#candidates + 1] = unit end
	for _, unit in ipairs(wards) do candidates[#candidates + 1] = unit end

	local bestTarget = nil
	local bestDistance = myHero.pos:DistanceTo(mousePos)
	for _, unit in ipairs(candidates) do
		if IsValid(unit) and unit.networkID ~= myHero.networkID and myHero.pos:DistanceTo(unit.pos) <= self.ESpell.Range then
			local mouseDistance = unit.pos:DistanceTo(mousePos)
			local safePosition = not Menu.Misc.SafeE:Value() or IsUnderTurret(myHero) or not IsUnderTurret2(unit.pos)
			if safePosition and mouseDistance < bestDistance then
				bestDistance = mouseDistance
				bestTarget = unit
			end
		end
	end
	if bestTarget then
		Control.CastSpell(HK_E, bestTarget)
	end
end

function ClassicKatarina:KillSteal()
	local enemies = _G.SDK.ObjectManager:GetEnemyHeroes(self.ESpell.Range)
	for _, target in ipairs(enemies) do
		if IsValid(target) and target.pos2D.onScreen then
			local magicHealth = target.health + target.hpRegen + target.shieldAP
			if Menu.KillSteal.Q:Value() and IsReady(_Q) and myHero.pos:DistanceTo(target.pos) <= self.QSpell.Range then
				if self:GetQDmg(target) >= magicHealth then
					Control.CastSpell(HK_Q, target)
					return
				end
			end
			local markDamage = HaveBuff(target, "Jade_KatarinaQBuff") and self:GetQMarkDmg(target) or 0
			if Menu.KillSteal.W:Value() and IsReady(_W) and myHero.pos:DistanceTo(target.pos) <= self.WSpell.Range then
				if self:GetWDmg(target) + markDamage >= magicHealth then
					V2:Cast(HK_W, nil, {intentTarget=target})
					return
				end
			end
			if Menu.KillSteal.E:Value() and IsReady(_E) and self:CanUseE(target) then
				if self:GetEDmg(target) + markDamage >= magicHealth then
					Control.CastSpell(HK_E, target)
					return
				end
			end
		end
	end
end

function ClassicKatarina:GetQDmg(target)
	local level = myHero:GetSpellData(_Q).level
	if level == 0 then return 0 end
	local damage = ({60, 85, 110, 135, 160})[level] + myHero.ap * 0.45
	return _G.SDK.Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_MAGICAL, damage)
end

function ClassicKatarina:GetQMarkDmg(target)
	local level = myHero:GetSpellData(_Q).level
	if level == 0 then return 0 end
	local damage = ({15, 30, 45, 60, 75})[level] + myHero.ap * 0.15
	return _G.SDK.Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_MAGICAL, damage)
end

function ClassicKatarina:GetWDmg(target)
	local level = myHero:GetSpellData(_W).level
	if level == 0 then return 0 end
	local damage = ({40, 75, 110, 145, 180})[level] + myHero.ap * 0.25 + myHero.bonusDamage * 0.60
	return _G.SDK.Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_MAGICAL, damage)
end

function ClassicKatarina:GetEDmg(target)
	local level = myHero:GetSpellData(_E).level
	if level == 0 then return 0 end
	local damage = ({60, 85, 110, 135, 160})[level] + myHero.ap * 0.40
	return _G.SDK.Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_MAGICAL, damage)
end

function ClassicKatarina:Draw()
	if myHero.dead then return end
	if Menu.Draw.DrawFarm:Value() then
		Draw.Text(Menu.Clear.SpellFarm:Value() and "Spell Farm: On" or "Spell Farm: Off", 16, myHero.pos2D.x-57, myHero.pos2D.y+58, Draw.Color(200, 242, 120, 34))
	end
	if Menu.Draw.DrawHarass:Value() then
		Draw.Text(Menu.Clear.SpellHarass:Value() and "Spell Harass: On" or "Spell Harass: Off", 16, myHero.pos2D.x-57, myHero.pos2D.y+78, Draw.Color(200, 242, 120, 34))
	end
	if Menu.Draw.Q:Value() and IsReady(_Q) then Draw.Circle(myHero.pos, self.QSpell.Range, 1, Draw.Color(255, 66, 244, 113)) end
	if Menu.Draw.W:Value() and IsReady(_W) then Draw.Circle(myHero.pos, self.WSpell.Range, 1, Draw.Color(255, 244, 238, 66)) end
	if Menu.Draw.E:Value() and IsReady(_E) then Draw.Circle(myHero.pos, self.ESpell.Range, 1, Draw.Color(255, 66, 229, 244)) end
	if Menu.Draw.R:Value() and IsReady(_R) then Draw.Circle(myHero.pos, self.RSpell.Range, 1, Draw.Color(255, 244, 66, 104)) end
end


-- Explicit request context. Nested helpers inherit their caller's context.
V2:RegisterPolicy({
    killBonus=function(self,q,slot) return (slot==_W or slot==_E) and HaveBuff(q.object,"Jade_KatarinaQBuff") and self:GetQMarkDmg(q.object) or 0 end,
    damageTypes={Q='magical',W='magical',E='magical'},
    methods={


        Combo=function()return V2:ModeContext("Combo")end,
        Harass=function()return V2:ModeContext("Harass")end,
        LaneClear=function()return V2:ModeContext("LaneClear",function()return Menu.Clear.SpellFarm:Value()end)end,
        JungleClear=function()return V2:ModeContext("LaneClear",function()return Menu.Clear.SpellFarm:Value()end)end,
        FarmHarass=function()return V2:ModeContext("LaneClear",function()return Menu.Clear.SpellHarass:Value() and not IsUnderTurret(myHero)end)end,
        Flee=function()return V2:ModeContext("Flee")end,
    },
    exceptions={non_interrupting_summoner=true},
    channel=function(self,q)return not self:IsChannelingR() end,
    validate=function(self,q,slot,resolved)
        if slot==_E and q.object then return self:CanUseE(q.object)end
        return true
    end,
})

ClassicKatarina()

end
if champion=="KogMaw" then
local Version = 1.01


local ClassicKogMaw=class("ClassicKogMaw")

function ClassicKogMaw:__init()		 

	self:LoadMenu()
	Callback.Add("Draw", function() self:Draw() end)
	Callback.Add("Tick", function() self:OnTick() end)
	self.QSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 70, Range = 1000, Speed = 1650, Collision = true, CollisionTypes = {GGPrediction.COLLISION_MINION, GGPrediction.COLLISION_YASUOWALL}}
	self.ESpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 120, Range = 1200, Speed = 1350, Collision = true, CollisionTypes = {GGPrediction.COLLISION_YASUOWALL}}
	self.RSpell = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 0.6, Radius = 100, Range = 1400, Speed = math.huge, Collision = false}
end

function ClassicKogMaw:LoadMenu()
	local championIcon = "http://ddragon.leagueoflegends.com/cdn/16.15.1/img/champion/"..myHero.charName..".png"
	Menu = MenuElement({type = MENU, id = "Classic_AIO_"..myHero.charName, name = "Classic AIO - "..myHero.charName.." V: "..Version, leftIcon = championIcon})
	Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
	Menu.Combo:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "Qrange", name = "Use Q|Range", value = 900, min = 600, max = 1000, step = 50})
	Menu.Combo:MenuElement({id = "W", name = "Use W", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "E", name = "Use E", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "Erange", name = "Use E|Range", value = 1100, min = 600, max = 1200, step = 50})
	Menu.Combo:MenuElement({id = "R", name = "Use R", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "Rstack", name = "Use R|Check R stacks", value = true})
	Menu.Combo:MenuElement({id = "Rstacks", name = "Check R stacks|Stop at x stacks", value = 3, min = 1, max = 9, step = 1})

	Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
	Menu.Harass:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	Menu.Harass:MenuElement({id = "Qrange", name = "Use Q|Range", value = 900, min = 600, max = 1000, step = 50})
	Menu.Harass:MenuElement({id = "W", name = "Use W", toggle = true, value = false})
	Menu.Harass:MenuElement({id = "E", name = "Use E", toggle = true, value = false})
	Menu.Harass:MenuElement({id = "Erange", name = "Use E|Range", value = 1100, min = 600, max = 1200, step = 50})
	
	Menu:MenuElement({type = MENU, id = "Misc", name = "Misc"})
	Menu.Misc:MenuElement({id = "SMR", name = "Semi-manual R Key", key = string.byte("T")})
	Menu.Misc:MenuElement({id = "Rks", name = "Auto R KillSteal", value = true})
	Menu.Misc:MenuElement({id = "stopq", name = "Stop using Q when has W", value = false})
	Menu.Misc:MenuElement({id = "stope", name = "Stop using E when has W", value = false})
	Menu.Misc:MenuElement({id = "stopr", name = "Stop using R when has W", value = false})

	Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
	Menu.Draw:MenuElement({id = "Q", name = "[Q] Range", toggle = true, value = false})
	Menu.Draw:MenuElement({id = "E", name = "[E] Range", toggle = true, value = false})
	Menu.Draw:MenuElement({id = "R", name = "[R] Range", toggle = true, value = false})

end

function ClassicKogMaw:OnTick()
	self.QSpell.Delay = myHero.attackData.windUpTime
	self.RSpell.Range = 1100 + 300 * myHero:GetSpellData(_R).level
	if ShouldWait() then
		return
	end

	if IsCasting() then return end

	self:RKS()
	if Menu.Misc.SMR:Value() then
		self:SMR()
	end

	local Mode = GetMode()
	if Mode == "Combo" then
		self:Combo()
	elseif Mode == "Harass" then
		self:Harass()
	end
end

function ClassicKogMaw:SMR()
	if IsReady(_R) then
		local target = GetTarget(self.RSpell.Range)
		if IsValid(target) and target.pos:ToScreen().onScreen then 
			self:CastGGPred(HK_R, target)
		end
	end
end
	
function ClassicKogMaw:Combo()
	if Menu.Combo.Q:Value() and IsReady(_Q) then
		if not Menu.Misc.stopq:Value() or not HaveBuff(myHero, "Jade_KogMawW") then
			local target = _G.SDK.Orbwalker:GetTarget() or GetTarget(Menu.Combo.Qrange:Value())
			if IsValid(target) and target.pos:ToScreen().onScreen then
				self:CastGGPred(HK_Q, target)
			end
		end
	end
	if Menu.Combo.E:Value() and IsReady(_E) then
		if not Menu.Misc.stope:Value() or not HaveBuff(myHero, "Jade_KogMawW") then
			local target = _G.SDK.Orbwalker:GetTarget() or GetTarget(Menu.Combo.Erange:Value())
			if IsValid(target) and target.pos:ToScreen().onScreen then 
				self:CastGGPred(HK_E, target)
			end
		end
	end
	if Menu.Combo.W:Value() and IsReady(_W) then
		local target = GetTarget(610 + 20 * myHero:GetSpellData(_W).level + myHero.boundingRadius * 2)
		if IsValid(target) and target.pos:ToScreen().onScreen then 
			Control.CastSpell(HK_W)
		end
	end
	if Menu.Combo.R:Value() and IsReady(_R) then
		local buff, buffData = GetBuffData(myHero, "Jade_KogMawRcost")
		if Menu.Combo.Rstack:Value() and buff and buffData.count >= Menu.Combo.Rstacks:Value() then
			return
		end
		if Menu.Misc.stopr:Value() and HaveBuff(myHero, "Jade_KogMawW") then
			return
		end
		local target = _G.SDK.Orbwalker:GetTarget()
		local enemies = _G.SDK.ObjectManager:GetEnemyHeroes(self.RSpell.Range)
		if target == nil then target = GetTarget(enemies) end
		if IsValid(target) and target.pos:ToScreen().onScreen then 
			self:CastGGPred(HK_R, target)
		end
	end
end

function ClassicKogMaw:Harass()
	if Menu.Harass.Q:Value() and IsReady(_Q) then
		if not Menu.Misc.stopq:Value() or not HaveBuff(myHero, "Jade_KogMawW") then
			local target = GetTarget(Menu.Harass.Qrange:Value())
			if IsValid(target) and target.pos:ToScreen().onScreen then 
				self:CastGGPred(HK_Q, target)
			end
		end
	end
	if Menu.Harass.E:Value() and IsReady(_E) then
		if not Menu.Misc.stope:Value() or not HaveBuff(myHero, "Jade_KogMawW") then
			local target = GetTarget(Menu.Harass.Erange:Value())
			if IsValid(target) and target.pos:ToScreen().onScreen then 
				self:CastGGPred(HK_E, target)
			end
		end
	end
	if Menu.Harass.W:Value() and IsReady(_W) then
		local target = GetTarget(610 + 20 * myHero:GetSpellData(_W).level + myHero.boundingRadius * 2)
		if IsValid(target) and target.pos:ToScreen().onScreen then 
			Control.CastSpell(HK_W)
		end
	end
end

function ClassicKogMaw:RKS()
	if not (Menu.Misc.Rks:Value() and IsReady(_R)) then
		return
	end
	local RDmg = 140 + (40 * myHero:GetSpellData(_R).level) + (myHero.bonusDamage * 0.5) + (myHero.ap * 0.3)
	for _, unit in ipairs(_G.SDK.ObjectManager:GetEnemyHeroes(self.RSpell.Range)) do
		if IsValid(unit) and unit.pos2D.onScreen then
			local health = unit.health
			local hpRegen = unit.hpRegen
			if _G.SDK.Damage:CalculateDamage(myHero, unit, _G.SDK.DAMAGE_TYPE_MAGICAL, RDmg) > health + (hpRegen * 2) then
				if self:CastGGPred(HK_R, unit) then
					break
				end
			end
		end
	end
end

function ClassicKogMaw:CastGGPred(spell, target)
	if spell == HK_Q then
		local QPrediction = GGPrediction:SpellPrediction(self.QSpell)
		QPrediction:GetPrediction(target, myHero)
		if QPrediction:CanHit(3) then
			return Control.CastSpell(HK_Q, QPrediction.CastPosition)
		end
	elseif spell == HK_E then
		local EPrediction = GGPrediction:SpellPrediction(self.ESpell)
		EPrediction:GetPrediction(target, myHero)
		if EPrediction:CanHit(3) then
			return Control.CastSpell(HK_E, EPrediction.CastPosition)
		end
	elseif spell == HK_R then
		local RPrediction = GGPrediction:SpellPrediction(self.RSpell)
		RPrediction:GetPrediction(target, myHero)
		if RPrediction:CanHit(3) then
			return Control.CastSpell(HK_R, RPrediction.CastPosition)
		end
	end
end

function ClassicKogMaw:Draw()
	if myHero.dead then return end

	if Menu.Draw.Q:Value() and IsReady(_Q) then
		Draw.Circle(myHero.pos, self.QSpell.Range, 1, Draw.Color(255, 66, 244, 113))
	end
	if Menu.Draw.E:Value() and IsReady(_E) then
		Draw.Circle(myHero.pos, self.ESpell.Range, 1, Draw.Color(255, 244, 238, 66))
	end
	if Menu.Draw.R:Value() and IsReady(_R) then
		Draw.Circle(myHero.pos, self.RSpell.Range, 1, Draw.Color(255, 244, 66, 104))
	end
end


-- Explicit request context. Nested helpers inherit their caller's context.
V2:RegisterPolicy({
    methods={


        Combo=function()return V2:ModeContext("Combo")end,
        Harass=function()return V2:ModeContext("Harass")end,
        SMR=function()return V2:HeldContext(function()return Menu.Misc.SMR:Value()end)end,
    },
    exceptions={non_interrupting_summoner=true},
    channel=function(self,q)return not (myHero.activeSpell and myHero.activeSpell.valid and myHero.activeSpell.isChanneling) end,
    validate=function(self,q,slot,resolved)
        local key=({[_Q]='stopq',[_E]='stope',[_R]='stopr'})[slot]
        if key and Menu.Misc[key]:Value() and HaveBuff(myHero,'Jade_KogMawW')then return false end
        if slot==_R then
            if q.owner=='Combo' then local exists,b=GetBuffData(myHero,'Jade_KogMawRcost');if Menu.Combo.Rstack:Value() and exists and b.count>=Menu.Combo.Rstacks:Value()then return false end end
            if q.owner=='RKS' and q.object then
                local damage=140+40*myHero:GetSpellData(_R).level+myHero.bonusDamage*.5+myHero.ap*.3
                return SDK.Damage:CalculateDamage(myHero,q.object,SDK.DAMAGE_TYPE_MAGICAL,damage)>q.object.health+q.object.hpRegen*2
            end
        end
        if slot==_W and (q.owner=='Combo' or q.owner=='Harass')then return GetEnemyCount(610+20*myHero:GetSpellData(_W).level+myHero.boundingRadius*2,myHero.pos)>0 end
        return true
    end,
})

ClassicKogMaw()

end
if champion=="Leona" then
local Version = 1.01


local ClassicLeona=class("ClassicLeona")

function ClassicLeona:__init()

	self.WRange = 450
	self.QRange = 225
	self.ESpell = { Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 80, Range = 875, Speed = 1200, Collision = false }
	self.RSpell = { Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 0.625, Radius = 250, Range = 1200, Speed = math.huge, Collision = false }
	self:LoadMenu()
	Callback.Add("Tick", function() self:Tick() end)
	Callback.Add("Draw", function() self:Draw() end)
	_G.SDK.Orbwalker:OnPreAttack(function(args) self:OnPreAttack(args) end)
end

function ClassicLeona:LoadMenu()
	local icon = "http://ddragon.leagueoflegends.com/cdn/16.15.1/img/champion/" .. myHero.charName .. ".png"
	Menu = MenuElement({ type = MENU, id = "Classic_AIO_" .. myHero.charName, name = "Classic AIO - " .. myHero.charName .. " V: " .. Version, leftIcon = icon })
	Menu:MenuElement({ type = MENU, id = "Combo", name = "Combo" })
	for _, s in ipairs({ "Q", "W", "E", "R" }) do
		Menu.Combo:MenuElement({ id = s, name = "Use " .. s, value = true })
	end
	Menu.Combo:MenuElement({ id = "RCount", name = "Use R | Enemy Count >=", value = 2, min = 1, max = 5, step = 1 })
	Menu:MenuElement({ type = MENU, id = "Harass", name = "Harass" })
	for _, s in ipairs({ "Q", "W", "E" }) do
		Menu.Harass:MenuElement({ id = s, name = "Use " .. s, value = s ~= "W" })
	end
	Menu.Harass:MenuElement({ id = "Mana", name = "Mana Percent >=", value = 40, min = 0, max = 100, step = 5 })
	Menu:MenuElement({ type = MENU, id = "Clear", name = "Clear" })
	Menu.Clear:MenuElement({ id = "Enabled", name = "Use Spell Farm (Mouse Scroll)", toggle = true, value = false, key = 4, callback = function(v) CheckChatBlock(Menu.Clear.Enabled, v) end })
	Menu.Clear:MenuElement({ id = "W", name = "Use W | Nearby Units >=", value = 3, min = 1, max = 8, step = 1 })
	Menu.Clear:MenuElement({ id = "E", name = "Use E In Jungle", value = true })
	Menu.Clear:MenuElement({ id = "Mana", name = "Mana Percent >=", value = 30, min = 0, max = 100, step = 5 })
	Menu:MenuElement({ type = MENU, id = "KillSteal", name = "KillSteal" })
	Menu.KillSteal:MenuElement({ id = "E", name = "Auto E", value = true })
	Menu.KillSteal:MenuElement({ id = "R", name = "Auto R", value = true })
	Menu:MenuElement({ type = MENU, id = "SemiR", name = "Semi-Manual R" })
	Menu.SemiR:MenuElement({ id = "Key", name = "Semi-Manual R Key (Hold)", key = string.byte("T") })
	Menu.SemiR:MenuElement({ id = "Count", name = "Enemy Count >=", value = 1, min = 1, max = 5, step = 1 })
	Menu:MenuElement({ type = MENU, id = "Misc", name = "Misc" })
	Menu.Misc:MenuElement({ id = "AutoW", name = "Auto W When HP <= x%", value = 35, min = 0, max = 100, step = 5 })
	Menu.Misc:MenuElement({ id = "AntiDash", name = "Auto E Anti-Dash", value = true })
	Menu:MenuElement({ type = MENU, id = "Draw", name = "Draw" })
	for _, s in ipairs({ "Q", "W", "E", "R" }) do
		Menu.Draw:MenuElement({ id = s, name = "Draw " .. s .. " Range", value = false })
	end
	Menu.Draw:MenuElement({ id = "Farm", name = "Draw Farm Status", value = true })
end

function ClassicLeona:QActive() return HaveBuff(myHero, "Jade_LeonaShieldOfDaybreak") end
function ClassicLeona:ManaPercent() return myHero.maxMana > 0 and myHero.mana / myHero.maxMana * 100 or 100 end

function ClassicLeona:Tick()
	if ShouldWait() or IsCasting() then return end
	self:AutoW()
	self:AntiDash()
	if self:SemiR() then return end
	self:KillSteal()
	local mode = GetMode()
	if mode == "Combo" then
		self:Combo()
	elseif mode == "Harass" then
		self:Harass()
	elseif mode == "LaneClear" then
		self:Clear()
	end
end

function ClassicLeona:OnPreAttack(args)
	local target = args and args.Target
	if not IsValid(target) or target.type ~= Obj_AI_Hero or self:QActive() or not IsReady(_Q) then return end
	local mode = GetMode()
	if (mode == "Combo" and Menu.Combo.Q:Value()) or (mode == "Harass" and Menu.Harass.Q:Value()) then Control.CastSpell(HK_Q) end
end

function ClassicLeona:AutoW()
	if not IsReady(_W) or Menu.Misc.AutoW:Value() == 0 or GetEnemyCount(700, myHero.pos) == 0 then return end
	local hp = myHero.maxHealth > 0 and myHero.health / myHero.maxHealth * 100 or 100
	if hp <= Menu.Misc.AutoW:Value() then Control.CastSpell(HK_W) end
end

function ClassicLeona:Combo()
	local target = GetTarget(self.RSpell.Range)
	if not IsValid(target) or not target.pos2D.onScreen then return end
	if Menu.Combo.R:Value() and IsReady(_R) and target.distance <= self.RSpell.Range and CastSpellAOE(HK_R, self.RSpell, Menu.Combo.RCount:Value(), myHero, target) then return end
	if Menu.Combo.W:Value() and IsReady(_W) and target.distance <= self.ESpell.Range then
		Control.CastSpell(HK_W)
		return
	end
	if Menu.Combo.E:Value() and IsReady(_E) and target.distance <= self.ESpell.Range and self:CastE(target, 2) then return end
	if Menu.Combo.Q:Value() and IsReady(_Q) and not self:QActive() and target.distance <= self.QRange then Control.CastSpell(HK_Q) end
end

function ClassicLeona:Harass()
	if self:ManaPercent() < Menu.Harass.Mana:Value() then return end
	local target = GetTarget(self.ESpell.Range)
	if not IsValid(target) or not target.pos2D.onScreen then return end
	if Menu.Harass.W:Value() and IsReady(_W) then
		Control.CastSpell(HK_W)
		return
	end
	if Menu.Harass.E:Value() and IsReady(_E) and self:CastE(target, 3) then return end
	if Menu.Harass.Q:Value() and IsReady(_Q) and target.distance <= self.QRange then Control.CastSpell(HK_Q) end
end

function ClassicLeona:Clear()
	if not Menu.Clear.Enabled:Value() or self:ManaPercent() < Menu.Clear.Mana:Value() then return end
	local minions = _G.SDK.ObjectManager:GetEnemyMinions(self.WRange)
	local monsters = _G.SDK.ObjectManager:GetMonsters(self.ESpell.Range)
	local count = 0
	for _, u in ipairs(minions) do
		if IsValid(u) and u.distance <= self.WRange then count = count + 1 end
	end
	for _, u in ipairs(monsters) do
		if IsValid(u) and u.distance <= self.WRange then count = count + 1 end
	end
	if IsReady(_W) and count >= Menu.Clear.W:Value() then
		Control.CastSpell(HK_W)
		return
	end
	if Menu.Clear.E:Value() and IsReady(_E) and IsValid(monsters[1]) then Control.CastSpell(HK_E, monsters[1].pos) end
end

function ClassicLeona:AntiDash()
	if not Menu.Misc.AntiDash:Value() or not IsReady(_E) then return end
	for _, target in ipairs(_G.SDK.ObjectManager:GetEnemyHeroes(self.ESpell.Range)) do
		if IsValid(target) and target.pathing and target.pathing.isDashing and target.pathing.endPos and target.pathing.endPos:DistanceTo(myHero.pos) <= self.ESpell.Range then
			Control.CastSpell(HK_E, target.pathing.endPos)
			return
		end
	end
end

function ClassicLeona:SemiR()
	if not Menu.SemiR.Key:Value() or not IsReady(_R) then return false end
	local target = GetTarget(self.RSpell.Range)
	if not IsValid(target) or not target.pos2D.onScreen then return false end
	local count = Menu.SemiR.Count:Value()
	if count > 1 then return CastSpellAOE(HK_R, self.RSpell, count, myHero, target) and true or false end
	local p = GGPrediction:SpellPrediction(self.RSpell)
	p:GetPrediction(target, myHero)
	if p:CanHit(3) then
		return Control.CastSpell(HK_R, p.CastPosition)
	end
	return false
end

function ClassicLeona:KillSteal()
	for _, target in ipairs(_G.SDK.ObjectManager:GetEnemyHeroes(self.RSpell.Range)) do
		if IsValid(target) and target.pos2D.onScreen then
			local hp = target.health + (target.hpRegen or 0) + (target.shieldAP or 0)
			if Menu.KillSteal.E:Value() and IsReady(_E) and target.distance <= self.ESpell.Range and self:GetEDmg(target) >= hp then
				if self:CastE(target, 3) then return end
			end
			if Menu.KillSteal.R:Value() and IsReady(_R) and self:GetRDmg(target) >= hp then
				local p = GGPrediction:SpellPrediction(self.RSpell)
				p:GetPrediction(target, myHero)
				if p:CanHit(3) then
					Control.CastSpell(HK_R, p.CastPosition)
					return
				end
			end
		end
	end
end

function ClassicLeona:CastE(target, hc)
	local p = GGPrediction:SpellPrediction(self.ESpell)
	p:GetPrediction(target, myHero)
	if p:CanHit(hc or 2) then
		return Control.CastSpell(HK_E, p.CastPosition)
	end
	return false
end
function ClassicLeona:Magic(target, raw) return _G.SDK.Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_MAGICAL, raw) end
function ClassicLeona:GetEDmg(t)
	local l = myHero:GetSpellData(_E).level
	if l == 0 then return 0 end
	return self:Magic(t, ({ 60, 100, 140, 180, 220 })[l] + myHero.ap * 0.40)
end
function ClassicLeona:GetRDmg(t)
	local l = myHero:GetSpellData(_R).level
	if l == 0 then return 0 end
	return self:Magic(t, ({ 150, 250, 350 })[l] + myHero.ap * 0.80)
end

function ClassicLeona:Draw()
	if myHero.dead then return end
	if Menu.Draw.Farm:Value() then Draw.Text(Menu.Clear.Enabled:Value() and "Spell Farm: On" or "Spell Farm: Off", 16, myHero.pos2D.x - 55, myHero.pos2D.y + 60, Draw.Color(200, 242, 120, 34)) end
	if Menu.Draw.Q:Value() and IsReady(_Q) then Draw.Circle(myHero.pos, self.QRange, 1, Draw.Color(255, 66, 244, 113)) end
	if Menu.Draw.W:Value() and IsReady(_W) then Draw.Circle(myHero.pos, self.WRange, 1, Draw.Color(255, 244, 238, 66)) end
	if Menu.Draw.E:Value() and IsReady(_E) then Draw.Circle(myHero.pos, self.ESpell.Range, 1, Draw.Color(255, 66, 229, 244)) end
	if Menu.Draw.R:Value() and IsReady(_R) then Draw.Circle(myHero.pos, self.RSpell.Range, 1, Draw.Color(255, 244, 66, 96)) end
end


-- Explicit request context. Nested helpers inherit their caller's context.
V2:RegisterPolicy({
    damageTypes={E='magical',R='magical'},
    methods={
        AutoW=function()return {priority='interactive'}end,
        AntiDash=function()return {priority='interactive'}end,
        OnPreAttack=function()local mode=GetMode();return mode and V2:ModeContext(mode) or nil end,

        Combo=function()return V2:ModeContext("Combo")end,
        Harass=function()return V2:ModeContext("Harass")end,
        Clear=function()return V2:ModeContext("LaneClear")end,
        SemiR=function()return V2:HeldContext(function()return Menu.SemiR.Key:Value()end)end,
    },
    exceptions={non_interrupting_summoner=true},
    channel=function(self,q)return not (myHero.activeSpell and myHero.activeSpell.valid and myHero.activeSpell.isChanneling) end,
    validate=function(self,q,slot,resolved)
        if slot==_Q then return not self:QActive()end
        return true
    end,
})

ClassicLeona()

end
if champion=="MasterYi" then
local Version = 1.01


local ClassicMasterYi=class("ClassicMasterYi")

function ClassicMasterYi:__init()

	self:LoadMenu()
	Callback.Add("Draw", function() self:Draw() end)
	Callback.Add("Tick", function() self:Tick() end)
	_G.SDK.Orbwalker:OnPreAttack(function(...) self:OnPreAttack(...) end)
	_G.SDK.Orbwalker:OnPostAttack(function(...) self:OnPostAttack(...) end)
	self.QSpell = {Range = 600}
	self.RSearchRange = 1000
	self.meditateStart = 0
	self.wasMeditating = false
end

function ClassicMasterYi:LoadMenu()
	local championIcon = "http://ddragon.leagueoflegends.com/cdn/16.15.1/img/champion/"..myHero.charName..".png"
	Menu = MenuElement({type = MENU, id = "Classic_AIO_"..myHero.charName, name = "Classic AIO - "..myHero.charName.." V: "..Version, leftIcon = championIcon})

	Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
	Menu.Combo:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "QSafe", name = "Do Not Q Under Enemy Turret", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "E", name = "Use E Before Attack", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "R", name = "Use R", toggle = true, value = true})

	Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
	Menu.Harass:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})

	Menu:MenuElement({type = MENU, id = "Clear", name = "Clear"})
	Menu.Clear:MenuElement({id = "SpellFarm", name = "Use Spell Farm(Mouse Scroll)", toggle = true, value = false, key = 4, callback = function(newValue)
		if CheckChatBlock(Menu.Clear.SpellFarm, newValue) then return end
	end})
	Menu.Clear:MenuElement({type = MENU, id = "LaneClear", name = "LaneClear"})
	Menu.Clear.LaneClear:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	Menu.Clear.LaneClear:MenuElement({id = "QCount", name = "Use Q | Nearby Minions >=", value = 3, min = 1, max = 4, step = 1})
	Menu.Clear.LaneClear:MenuElement({id = "E", name = "Use E Before Attack", toggle = true, value = true})
	Menu.Clear:MenuElement({type = MENU, id = "JungleClear", name = "JungleClear"})
	Menu.Clear.JungleClear:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	Menu.Clear.JungleClear:MenuElement({id = "E", name = "Use E Before Attack", toggle = true, value = true})

	Menu:MenuElement({type = MENU, id = "KillSteal", name = "KillSteal"})
	Menu.KillSteal:MenuElement({id = "Q", name = "Auto Q KillSteal", toggle = true, value = true})

	Menu:MenuElement({type = MENU, id = "Misc", name = "Misc"})
	Menu.Misc:MenuElement({id = "AutoW", name = "Auto W At Low HP", toggle = true, value = true})
	Menu.Misc:MenuElement({id = "WHP", name = "Auto W | HP <= x%", value = 30, min = 5, max = 80, step = 5})
	Menu.Misc:MenuElement({id = "WRange", name = "Auto W | Enemy Range", value = 900, min = 300, max = 1500, step = 50})
	Menu.Misc:MenuElement({id = "WChannel", name = "Minimum W Channel Seconds", value = 1, min = 0, max = 3, step = 1})
	Menu.Misc:MenuElement({id = "FleeR", name = "Use R To Flee", toggle = true, value = true})

	Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
	Menu.Draw:MenuElement({id = "DrawFarm", name = "Draw Spell Farm Status", toggle = true, value = true})
	Menu.Draw:MenuElement({id = "Q", name = "Draw Q Range", toggle = true, value = false})
end

function ClassicMasterYi:IsMeditating()
	return HaveBuff(myHero, "Jade_MasterYiMeditate")
end

function ClassicMasterYi:HandleMeditate()
	local meditating = self:IsMeditating()
	if meditating and not self.wasMeditating then
		self.meditateStart = Game.Timer()
	end
	self.wasMeditating = meditating

	local locked = meditating and Game.Timer() < self.meditateStart + Menu.Misc.WChannel:Value()
	_G.SDK.Orbwalker:SetAttack(not locked)
	_G.SDK.Orbwalker:SetMovement(not locked)
	if not meditating then
		self.meditateStart = 0
	end
	return locked
end

function ClassicMasterYi:Tick()
	if self:HandleMeditate() then return end
	if ShouldWait() then return end
	if IsCasting() then return end
	if self:AutoW() then return end

	self:KillSteal()
	local mode = GetMode()
	if mode == "Combo" then
		self:Combo()
	elseif mode == "Harass" then
		self:Harass()
	elseif mode == "LaneClear" then
		self:LaneClear()
		self:JungleClear()
	elseif mode == "Flee" then
		self:Flee()
	end
end

function ClassicMasterYi:OnPreAttack(args)
	local target = args.Target
	if not IsValid(target) or not IsReady(_E) then return end
	local mode = GetMode()
	if mode == "Combo" and Menu.Combo.E:Value() and target.type == Obj_AI_Hero then
		Control.CastSpell(HK_E)
	elseif mode == "LaneClear" and Menu.Clear.SpellFarm:Value() and target.type == Obj_AI_Minion then
		if target.team == 300 and Menu.Clear.JungleClear.E:Value() then
			Control.CastSpell(HK_E)
		elseif target.team ~= 300 and Menu.Clear.LaneClear.E:Value() then
			Control.CastSpell(HK_E)
		end
	end
end

function ClassicMasterYi:OnPostAttack(args)
	if not IsReady(_Q) or lastQ + 250 >= GetTickCount() then return end
	local target = (args and args.Target) or _G.SDK.Orbwalker:GetTarget()
	if not IsValid(target) or myHero.pos:DistanceTo(target.pos) > self.QSpell.Range then return end
	local mode = GetMode()
	if mode == "Combo" and Menu.Combo.Q:Value() and target.type == Obj_AI_Hero then
		if self:CanUseQ(target, Menu.Combo.QSafe:Value()) then
			Control.CastSpell(HK_Q, target)
			V2:AfterCast(HK_Q, function() lastQ = GetTickCount() end)
		end
	elseif mode == "Harass" and Menu.Harass.Q:Value() and target.type == Obj_AI_Hero then
		if self:CanUseQ(target, true) then
			Control.CastSpell(HK_Q, target)
			V2:AfterCast(HK_Q, function() lastQ = GetTickCount() end)
		end
	end
end

function ClassicMasterYi:CanUseQ(target, safeMode)
	if not IsValid(target) or myHero.pos:DistanceTo(target.pos) > self.QSpell.Range then return false end
	if safeMode and not IsUnderTurret(myHero) and IsUnderTurret2(target.pos) then return false end
	return true
end

function ClassicMasterYi:Combo()
	local target = GetTarget(self.RSearchRange)
	if not IsValid(target) then return end
	local inAARange = _G.SDK.Data:IsInAutoAttackRange(myHero, target)

	if Menu.Combo.R:Value() and IsReady(_R) and not HaveBuff(myHero, "Jade_MasterYiHighlander") then
		local aaDamage = _G.SDK.Damage:GetAutoAttackDamage(myHero, target)
		if not inAARange or target.health + target.shieldAD > aaDamage * 2 then
			Control.CastSpell(HK_R)
			return
		end
	end

	if Menu.Combo.Q:Value() and IsReady(_Q) and lastQ + 250 < GetTickCount() then
		if self:CanUseQ(target, Menu.Combo.QSafe:Value()) then
			local qKills = self:GetQDmg(target) >= target.health + target.hpRegen + target.shieldAP
			if not inAARange or qKills then
				Control.CastSpell(HK_Q, target)
				V2:AfterCast(HK_Q, function() lastQ = GetTickCount() end)
			end
		end
	end
end

function ClassicMasterYi:Harass()
	if not Menu.Harass.Q:Value() or not IsReady(_Q) or lastQ + 250 >= GetTickCount() then return end
	local target = GetTarget(self.QSpell.Range)
	if IsValid(target) and not _G.SDK.Data:IsInAutoAttackRange(myHero, target) and self:CanUseQ(target, true) then
		Control.CastSpell(HK_Q, target)
		V2:AfterCast(HK_Q, function() lastQ = GetTickCount() end)
	end
end

function ClassicMasterYi:LaneClear()
	if not Menu.Clear.SpellFarm:Value() or not Menu.Clear.LaneClear.Q:Value() or not IsReady(_Q) then return end
	if IsUnderTurret(myHero) then return end
	local minions = _G.SDK.ObjectManager:GetEnemyMinions(self.QSpell.Range)
	table.sort(minions, function(a, b) return a.maxHealth > b.maxHealth end)
	for _, minion in ipairs(minions) do
		if IsValid(minion) and minion.team ~= 300 and minion.pos2D.onScreen then
			if GetMinionCount(300, minion.pos) >= Menu.Clear.LaneClear.QCount:Value() then
				Control.CastSpell(HK_Q, minion)
				V2:AfterCast(HK_Q, function() lastQ = GetTickCount() end)
				return
			end
		end
	end
end

function ClassicMasterYi:JungleClear()
	if not Menu.Clear.SpellFarm:Value() or not Menu.Clear.JungleClear.Q:Value() or not IsReady(_Q) then return end
	local monsters = _G.SDK.ObjectManager:GetMonsters(self.QSpell.Range)
	table.sort(monsters, function(a, b) return a.maxHealth > b.maxHealth end)
	local monster = monsters[1]
	if IsValid(monster) and monster.pos2D.onScreen then
		Control.CastSpell(HK_Q, monster)
		V2:AfterCast(HK_Q, function() lastQ = GetTickCount() end)
	end
end

function ClassicMasterYi:AutoW()
	if not Menu.Misc.AutoW:Value() or not IsReady(_W) or myHero.maxHealth <= 0 then return false end
	local hpPercent = myHero.health / myHero.maxHealth * 100
	if hpPercent <= Menu.Misc.WHP:Value() and GetEnemyCount(Menu.Misc.WRange:Value(), myHero.pos) > 0 then
		return Control.CastSpell(HK_W) -- HandleMeditate observes the actual channel start.
	end
	return false
end

function ClassicMasterYi:Flee()
	if Menu.Misc.FleeR:Value() and IsReady(_R) and not HaveBuff(myHero, "Jade_MasterYiHighlander") then
		Control.CastSpell(HK_R)
	end
end

function ClassicMasterYi:KillSteal()
	if not Menu.KillSteal.Q:Value() or not IsReady(_Q) or lastQ + 250 >= GetTickCount() then return end
	local enemies = _G.SDK.ObjectManager:GetEnemyHeroes(self.QSpell.Range)
	for _, target in ipairs(enemies) do
		if IsValid(target) and target.pos2D.onScreen and self:CanUseQ(target, Menu.Combo.QSafe:Value()) then
			if self:GetQDmg(target) >= target.health + target.hpRegen + target.shieldAP then
				Control.CastSpell(HK_Q, target)
				V2:AfterCast(HK_Q, function() lastQ = GetTickCount() end)
				return
			end
		end
	end
end

function ClassicMasterYi:GetQDmg(target)
	local level = myHero:GetSpellData(_Q).level
	if level == 0 then return 0 end
	local damage = ({100, 150, 200, 250, 300})[level] + myHero.ap
	return _G.SDK.Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_MAGICAL, damage)
end

function ClassicMasterYi:Draw()
	if myHero.dead then return end
	if Menu.Draw.DrawFarm:Value() then
		Draw.Text(Menu.Clear.SpellFarm:Value() and "Spell Farm: On" or "Spell Farm: Off", 16, myHero.pos2D.x-57, myHero.pos2D.y+58, Draw.Color(200, 242, 120, 34))
	end
	if Menu.Draw.Q:Value() and IsReady(_Q) then
		Draw.Circle(myHero.pos, self.QSpell.Range, 1, Draw.Color(255, 66, 244, 113))
	end
end


-- Explicit request context. Nested helpers inherit their caller's context.
V2:RegisterPolicy({
    damageTypes={Q='magical'},
    methods={
        AutoW=function()return {priority='interactive'}end,
        OnPreAttack=function()local mode=GetMode();return mode and V2:ModeContext(mode) or nil end,
        OnPostAttack=function()local mode=GetMode();return mode and V2:ModeContext(mode) or nil end,

        Combo=function()return V2:ModeContext("Combo")end,
        Harass=function()return V2:ModeContext("Harass")end,
        LaneClear=function()return V2:ModeContext("LaneClear",function()return Menu.Clear.SpellFarm:Value()end)end,
        JungleClear=function()return V2:ModeContext("LaneClear",function()return Menu.Clear.SpellFarm:Value()end)end,
        Flee=function()return V2:ModeContext("Flee")end,
    },
    exceptions={non_interrupting_summoner=true},
    channel=function(self,q)return not self:IsMeditating() end,
    validate=function(self,q,slot,resolved)
        if slot==_Q and q.object and q.object.type==Obj_AI_Hero then return self:CanUseQ(q.object)end
        return true
    end,
})

ClassicMasterYi()

end
if champion=="MissFortune" then
local Version = 1.03


local ClassicMissFortune=class("ClassicMissFortune")

function ClassicMissFortune:__init()

	self:LoadMenu()
	Callback.Add("Draw", function() self:Draw() end)
	Callback.Add("Tick", function() self:Tick() end)
	_G.SDK.Orbwalker:OnPreAttack(function(...) self:OnPreAttack(...) end)
	-- _G.SDK.Orbwalker:OnPostAttack(function(...) self:OnPostAttack(...) end)
	self.QSpell = {Delay = 0.25, Range = 650, Speed = 1400}
	self.ESpell = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 0.25, Radius = 200, Range = 800, Speed = math.huge, Collision = false}
	self.RSpell = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 0.375, Radius = 40, Range = 1350, Speed = 2000, Collision = false}
	-- LastAttackId = 0
end

function ClassicMissFortune:LoadMenu()
	local championIcon = "http://ddragon.leagueoflegends.com/cdn/16.15.1/img/champion/"..myHero.charName..".png"
	Menu = MenuElement({type = MENU, id = "Classic_AIO_"..myHero.charName, name = "Classic AIO - "..myHero.charName.." V: "..Version, leftIcon = championIcon})

	Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
	Menu.Combo:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "Q2", name = "Use Bounce Q", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "W", name = "Use W", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "E", name = "Use E", toggle = true, value = true})

	Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
	Menu.Harass:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	Menu.Harass:MenuElement({id = "Q2", name = "Use Bounce Q", toggle = true, value = true})
	Menu.Harass:MenuElement({id = "E", name = "Use E", toggle = true, value = false})
	-- Menu.Harass:MenuElement({id = "Mana", name = "When ManaPercent >= x%", value = 60, min = 0, max = 100, step = 5})

	Menu:MenuElement({type = MENU, id = "Clear", name = "Clear"})
	Menu.Clear:MenuElement({id = "SpellFarm", name = "Use Spell Farm(Mouse Scroll)", toggle = true, value = false, key = 4, callback = function(newValue)
		if CheckChatBlock(Menu.Clear.SpellFarm, newValue) then return end
	end})
	Menu.Clear:MenuElement({id = "SpellHarass", name = "Use Spell Harass(In LaneClear Mode)", toggle = true, value = false, key = string.byte("H"), callback = function(newValue)
		if CheckChatBlock(Menu.Clear.SpellHarass, newValue) then return end
	end})
	Menu.Clear:MenuElement({type = MENU, id = "LaneClear", name = "LaneClear"})
	Menu.Clear.LaneClear:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	Menu.Clear.LaneClear:MenuElement({id = "W", name = "Use W", toggle = true, value = true})
	Menu.Clear.LaneClear:MenuElement({id = "E", name = "Use E", toggle = true, value = true})
	Menu.Clear.LaneClear:MenuElement({id = "ECount", name = "If E CanHit Counts >= ", value = 3, min = 1, max = 5, step = 1})
	-- Menu.Clear.LaneClear:MenuElement({id = "Mana", name = "When ManaPercent >= x%", value = 60, min = 0, max = 100, step = 5})
	Menu.Clear:MenuElement({type = MENU, id = "JungleClear", name = "JungleClear"})
	Menu.Clear.JungleClear:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	Menu.Clear.JungleClear:MenuElement({id = "W", name = "Use W", toggle = true, value = true})
	Menu.Clear.JungleClear:MenuElement({id = "E", name = "Use E", toggle = true, value = true})
	-- Menu.Clear.JungleClear:MenuElement({id = "Mana", name = "When ManaPercent >= x%", value = 30, min = 0, max = 100, step = 5})

	Menu:MenuElement({type = MENU, id = "KillSteal", name = "KillSteal"})
	Menu.KillSteal:MenuElement({id = "Q", name = "Auto Q KillSteal", toggle = true, value = true})

	Menu:MenuElement({type = MENU, id = "Misc", name = "Misc"})
	Menu.Misc:MenuElement({id = "Qangle", name = "Bounce Q's Angle", value = 60, min = 60, max = 80, step = 5})
	-- Menu.Misc:MenuElement({id = "newTarget", name = "Try change focus after attack(Combo)", toggle = true, value = false})
	Menu.Misc:MenuElement({id = "R", name = "Semi-manual R Key", key = string.byte("T")})

	Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
	Menu.Draw:MenuElement({id = "DrawFarm", name = "Draw Spell Farm Status", toggle = true, value = true})
	Menu.Draw:MenuElement({id = "DrawHarass", name = "Draw Spell Harass Status", toggle = true, value = true})
	Menu.Draw:MenuElement({id = "Q", name = "Draw Q Range", toggle = true, value = false})
	Menu.Draw:MenuElement({id = "E", name = "Draw E Range", toggle = true, value = false})
	Menu.Draw:MenuElement({id = "R", name = "Draw R Range", toggle = true, value = false})
end

function ClassicMissFortune:Tick()
	if ShouldWait() then
		return
	end

	self.QSpell.Delay = myHero.attackData.windUpTime

	if HaveBuff(myHero, "jade_missfortunebulletsound") then
		_G.SDK.Orbwalker:SetAttack(false)
		_G.SDK.Orbwalker:SetMovement(false)
		return
	else
		_G.SDK.Orbwalker:SetAttack(true)
		_G.SDK.Orbwalker:SetMovement(true)
	end
	
	-- self:newTarget()

	if IsCasting() then return end

	self:SemiRLogic()
	self:KillSteal()

	local Mode = GetMode()
	if Mode == "Combo" then
		self:Combo()
	elseif Mode == "Harass" then
		self:Harass()
	elseif Mode == "LaneClear" then
		self:FarmHarass()
		self:LaneClear()
		self:JungleClear()
	end
end

function ClassicMissFortune:OnPreAttack(args)
	local target = args.Target
	-- local manaPercentage = myHero.mana / myHero.maxMana
	if GetMode() == "Combo" and IsValid(target) and target.type == Obj_AI_Hero then
		if Menu.Combo.W:Value() and IsReady(_W) then
			Control.CastSpell(HK_W)
		end
	end
	if GetMode() == "LaneClear" and IsValid(target) and target.type == Obj_AI_Minion then
		local isJungleMinion = target.team == 300
		local isLaneMinion = target.team ~= 300
		-- local minMana = isJungleMinion and Menu.Clear.JungleClear.Mana:Value() or Menu.Clear.LaneClear.Mana:Value()
		if --[[manaPercentage >= minMana / 100 and ]]Menu.Clear.SpellFarm:Value() then
			if (isJungleMinion and Menu.Clear.JungleClear.W:Value() or isLaneMinion and Menu.Clear.LaneClear.W:Value()) and IsReady(_W) then
				Control.CastSpell(HK_W)
			end
		end
	end
end

-- function ClassicMissFortune:OnPostAttack()
	-- local target = _G.SDK.Orbwalker:GetTarget()
	-- if target then
		-- LastAttackId = target.networkID
	-- end
-- end

function ClassicMissFortune:SemiRLogic()
	if Menu.Misc.R:Value() and IsReady(_R) and lastR + 3000 < GetTickCount() then
		local Rtarget = GetTarget(self.RSpell.Range)
		if IsValid(Rtarget) and Rtarget.pos2D.onScreen then
			Control.CastSpell(HK_R, Rtarget)
			V2:AfterCast(HK_R, function() lastR = GetTickCount() end)
		end
	end
end

function ClassicMissFortune:KillSteal()
	if Menu.KillSteal.Q:Value() and IsReady(_Q) then
		local enemies = _G.SDK.ObjectManager:GetEnemyHeroes(self.QSpell.Range+500)
		for i, target in ipairs(enemies) do
			if IsValid(target) and (target.health + (target.hpRegen or 0) + (target.shieldAD or 0)) < self:GetQDmg(target) then
				self:QLogic(target, true)
			end
		end
	end
end

-- function ClassicMissFortune:newTarget()
	-- if Menu.Misc.newTarget:Value() and GetMode() == "Combo" then
		-- local orbT = _G.SDK.Orbwalker:GetTarget()
		-- if IsValid(orbT) and orbT.type == Obj_AI_Hero and orbT.networkID == LastAttackId then
			-- if orbT.health > _G.SDK.Damage:GetAutoAttackDamage(myHero, orbT) * 2 then
				-- local ta = nil
				-- local enemies = _G.SDK.ObjectManager:GetEnemyHeroes(self.QSpell.Range)				--aarange == qrange
				-- for _, enemy in ipairs(enemies) do
					-- if IsValid(enemy) and enemy.networkID ~= LastAttackId then
						-- ta = enemy
						-- break
					-- end
				-- end
				-- if ta then
					-- _G.SDK.Orbwalker.ForceTarget = ta
				-- else
					-- _G.SDK.Orbwalker.ForceTarget = nil
				-- end
			-- else
				-- _G.SDK.Orbwalker.ForceTarget = nil
			-- end
		-- end
	-- else
		-- _G.SDK.Orbwalker.ForceTarget = nil
	-- end
	-- if _G.SDK.Orbwalker.ForceTarget and not _G.SDK.Data:IsInAutoAttackRange(myHero, _G.SDK.Orbwalker.ForceTarget) then
		-- _G.SDK.Orbwalker.ForceTarget = nil
	-- end
-- end

function ClassicMissFortune:Combo()
	if IsReady(_Q) then
		local Qtarget = GetTarget(self.QSpell.Range+500)
		if IsValid(Qtarget) and Qtarget.pos2D.onScreen then
			if Menu.Combo.Q:Value() then
				self:QLogic(Qtarget, Menu.Combo.Q2:Value())
			end
		end
	end

	local Etarget = GetTarget(self.ESpell.Range)
	if IsValid(Etarget) and Etarget.pos2D.onScreen then
		if Menu.Combo.E:Value() and IsReady(_E) and not _G.SDK.Data:IsInAutoAttackRange(myHero, Etarget) then
			if myHero.mana > myHero:GetSpellData(_R).mana + myHero:GetSpellData(_Q).mana + myHero:GetSpellData(_W).mana + myHero:GetSpellData(_E).mana then
				self:CastGGPred(HK_E, Etarget)
			end
		end
	end
end

function ClassicMissFortune:Harass()
	--if myHero.mana/myHero.maxMana >= Menu.Harass.Mana:Value()/100 then
		if IsReady(_Q) then
			local Qtarget = GetTarget(self.QSpell.Range+500)
			if IsValid(Qtarget) and Qtarget.pos2D.onScreen then
				if Menu.Harass.Q:Value() then
					self:QLogic(Qtarget, Menu.Harass.Q2:Value())
				end
			end
		end

		local Etarget = GetTarget(self.ESpell.Range)
		if IsValid(Etarget) and Etarget.pos2D.onScreen then
			if Menu.Harass.E:Value() and IsReady(_E) then
				self:CastGGPred(HK_E, Etarget)
			end
		end
	--end
end

function ClassicMissFortune:FarmHarass()
	if Menu.Clear.SpellHarass:Value() then
		self:Harass()
	end
end

function ClassicMissFortune:LaneClear()
	if IsUnderTurret(myHero) then return end
	if --[[myHero.mana/myHero.maxMana >= Menu.Clear.LaneClear.Mana:Value()/100 and ]]Menu.Clear.SpellFarm:Value() then
		local minions = _G.SDK.ObjectManager:GetEnemyMinions(self.ESpell.Range)
		table.sort(minions, function(a, b) return myHero.pos:DistanceTo(a.pos) < myHero.pos:DistanceTo(b.pos) end)
		for i, minion in ipairs(minions) do
			if IsValid(minion) and minion.team ~= 300 and minion.pos2D.onScreen then
				if Menu.Clear.LaneClear.E:Value() and IsReady(_E) then
					if GetMinionCount(self.ESpell.Radius, minion.pos) >= Menu.Clear.LaneClear.ECount:Value() then
						Control.CastSpell(HK_E, minion)
					end
				end
				if Menu.Clear.LaneClear.Q:Value() and IsReady(_Q) then
					if #minions > 2 and minions[1].pos:DistanceTo(myHero.pos) < self.QSpell.Range then
						Control.CastSpell(HK_Q, minions[1])
					end
				end
			end
		end
	end
end

function ClassicMissFortune:JungleClear()
	if --[[myHero.mana/myHero.maxMana >= Menu.Clear.JungleClear.Mana:Value()/100 and ]]Menu.Clear.SpellFarm:Value() then
		local minions = _G.SDK.ObjectManager:GetEnemyMinions(self.ESpell.Range)
		table.sort(minions, function(a, b) return a.maxHealth > b.maxHealth end)
		for i, minion in ipairs(minions) do
			if IsValid(minion) and minion.team == 300 and minion.pos2D.onScreen then
				if Menu.Clear.JungleClear.E:Value() and IsReady(_E) then
					if not minion.name:lower():find("mini") then
						Control.CastSpell(HK_E, minion)
					else
						if GetMinionCount(self.ESpell.Radius, minion.pos) > 2 then
							Control.CastSpell(HK_E, minion)
						end
					end
				end
				if Menu.Clear.JungleClear.Q:Value() and IsReady(_Q) and myHero.pos:DistanceTo(minion.pos) < self.QSpell.Range then
					Control.CastSpell(HK_Q, minion)
				end
			end
		end
	end
end

function ClassicMissFortune:QLogic(target, UseQBounce)
	if target == nil then return end
	if myHero.pos:DistanceTo(target.pos) <= self.QSpell.Range then
		Control.CastSpell(HK_Q, target)
	else
		if UseQBounce then
			local tarPred = target:GetPrediction(math.huge, self.QSpell.Delay)
			local bounceFirstTar = {}
			local minions = _G.SDK.ObjectManager:GetEnemyMinions(self.QSpell.Range)
			local enemies = _G.SDK.ObjectManager:GetEnemyHeroes(self.QSpell.Range)
			
			local objTable = {}
			for i = 1, #minions do
				local minion = minions[i]
				table.insert(objTable, minion)
			end
			for i = 1, #enemies do
				local enemy = enemies[i]
				table.insert(objTable, enemy)
			end
			
			for i = 1, #objTable do
				local obj = objTable[i]
				if IsValid(obj) and obj.networkID ~= target.networkID then
					local angle = Menu.Misc.Qangle:Value()/2
					local objPred = obj:GetPrediction(math.huge, self.QSpell.Delay)
					local middlePos = myHero.pos:Extended(objPred, myHero.pos:DistanceTo(objPred) + 500)
					local leftVector = (middlePos - objPred):Rotated(0, angle * math.pi / 180, 0)
					local rightVector = (middlePos - objPred):Rotated(0, -angle * math.pi / 180, 0)
					local targetVector = tarPred - objPred
					-- Method 1 -- EXT API: Vector:Angle(Vector) broken, so use Method 2
					-- local Angle1 = leftVector:Angle(rightVector)
					-- local Angle2 = leftVector:Angle(targetVector)
					-- local Angle3 = rightVector:Angle(targetVector)
					-- if objPred:DistanceTo(tarPred) < 420 and Angle2 < Angle1 and Angle3 < Angle1 then
					-- Method 2
					local dotLeft = targetVector:DotProduct(leftVector)
					local dotRight = targetVector:DotProduct(rightVector)
					local crossLeft = targetVector:CrossProduct(leftVector)
					local crossRight = rightVector:CrossProduct(targetVector)
					if objPred:DistanceTo(tarPred) < 420 and dotLeft > 0 and dotRight > 0 and crossLeft * crossRight > 0 then
						bounceFirstTar[#bounceFirstTar + 1] = {tar = obj, dis = objPred:DistanceTo(tarPred)}
					end
				end
			end

			if #bounceFirstTar > 0 then
				table.sort(bounceFirstTar, function(a, b) return a.dis < b.dis end)
				local starTar = bounceFirstTar[1].tar
				local starPos = starTar.pos:Extended(tarPred, starTar.boundingRadius*2)
				local _, _, collisionCount = GGPrediction:GetCollision(starPos, tarPred, self.QSpell.Speed, self.QSpell.Delay, 60, {GGPrediction.COLLISION_MINION}, target.networkID)
				if collisionCount == 0 then
					Control.CastSpell(HK_Q, starTar)
				end
			end
		end
	end
end

function ClassicMissFortune:CastGGPred(spell, unit)
	if spell == HK_E then
		local EPrediction = GGPrediction:SpellPrediction(self.ESpell)
		EPrediction:GetPrediction(unit, myHero)
		if EPrediction:CanHit(3) then
			Control.CastSpell(HK_E, EPrediction.CastPosition)
		end
	end
end

function ClassicMissFortune:GetQDmg(target)
		local level = myHero:GetSpellData(_Q).level
		local QDmg = ({35, 70, 105, 140, 175})[level] + myHero.totalDamage * 0.75
		return _G.SDK.Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_PHYSICAL, QDmg)
end

function ClassicMissFortune:Draw()
	if myHero.dead then return end

	if Menu.Draw.DrawFarm:Value() then
		if Menu.Clear.SpellFarm:Value() then
			Draw.Text("Spell Farm: On", 16, myHero.pos2D.x-57, myHero.pos2D.y+58, Draw.Color(200, 242, 120, 34))
		else
			Draw.Text("Spell Farm: Off", 16, myHero.pos2D.x-57, myHero.pos2D.y+58, Draw.Color(200, 242, 120, 34))
		end
	end

	if Menu.Draw.DrawHarass:Value() then
		if Menu.Clear.SpellHarass:Value() then
			Draw.Text("Spell Harass: On", 16, myHero.pos2D.x-57, myHero.pos2D.y+78, Draw.Color(200, 242, 120, 34))
		else
			Draw.Text("Spell Harass: Off", 16, myHero.pos2D.x-57, myHero.pos2D.y+78, Draw.Color(200, 242, 120, 34))
		end
	end

	if Menu.Draw.Q:Value() and IsReady(_Q) then
		Draw.Circle(myHero.pos, self.QSpell.Range, 1, Draw.Color(255, 66, 244, 113))
	end
	if Menu.Draw.E:Value() and IsReady(_E) then
		Draw.Circle(myHero.pos, self.ESpell.Range, 1, Draw.Color(255, 244, 238, 66))
	end
	if Menu.Draw.R:Value() and IsReady(_R) then
		Draw.Circle(myHero.pos, self.RSpell.Range, 1, Draw.Color(255, 244, 66, 104))
	end
end


-- Explicit request context. Nested helpers inherit their caller's context.
V2:RegisterPolicy({
    damageTypes={Q='physical'},
    methods={

        OnPreAttack=function()local mode=GetMode();return mode and V2:ModeContext(mode) or nil end,
        OnPostAttack=function()local mode=GetMode();return mode and V2:ModeContext(mode) or nil end,

        Combo=function()return V2:ModeContext("Combo")end,
        Harass=function()return V2:ModeContext("Harass")end,
        LaneClear=function()return V2:ModeContext("LaneClear",function()return Menu.Clear.SpellFarm:Value()end)end,
        JungleClear=function()return V2:ModeContext("LaneClear",function()return Menu.Clear.SpellFarm:Value()end)end,
        FarmHarass=function()return V2:ModeContext("LaneClear",function()return Menu.Clear.SpellHarass:Value() and not IsUnderTurret(myHero)end)end,
        SemiRLogic=function()return V2:HeldContext(function()return Menu.Misc.R:Value()end)end,
    },
    exceptions={non_interrupting_summoner=true},
    channel=function(self,q)return not HaveBuff(myHero,"jade_missfortunebulletsound") end,
    validate=function(self,q,slot,resolved)
        if slot==_Q and q.object and q.owner=='LaneClear'then return self:GetQDmg(q.object)>=SDK.HealthPrediction:GetPrediction(q.object,self.QSpell.Delay) end
        return true
    end,
})

ClassicMissFortune()

end
if champion=="Pantheon" then
local Version = 1.01


local ClassicPantheon=class("ClassicPantheon")

function ClassicPantheon:__init()

	self:LoadMenu()
	Callback.Add("Draw", function() self:Draw() end)
	Callback.Add("Tick", function() self:Tick() end)
	self.QSpell = {Range = 600}
	self.WSpell = {Range = 600}
	self.ESpell = {Type = GGPrediction.SPELLTYPE_CONE, Delay = 0.25, Angle = 32, Range = 400, Speed = math.huge, Collision = false}
	self.RSpell = {Range = 5500}
	self.comboTarget = nil
	self.comboTargetExpire = 0
end

function ClassicPantheon:LoadMenu()
	local championIcon = "http://ddragon.leagueoflegends.com/cdn/16.15.1/img/champion/"..myHero.charName..".png"
	Menu = MenuElement({type = MENU, id = "Classic_AIO_"..myHero.charName, name = "Classic AIO - "..myHero.charName.." V: "..Version, leftIcon = championIcon})

	Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
	Menu.Combo:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "W", name = "Use W", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "E", name = "Use E", toggle = true, value = true})

	Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
	Menu.Harass:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	Menu.Harass:MenuElement({id = "W", name = "Use W", toggle = true, value = false})
	Menu.Harass:MenuElement({id = "E", name = "Use E", toggle = true, value = false})

	Menu:MenuElement({type = MENU, id = "Clear", name = "Clear"})
	Menu.Clear:MenuElement({id = "SpellFarm", name = "Use Spell Farm(Mouse Scroll)", toggle = true, value = false, key = 4, callback = function(newValue)
		if CheckChatBlock(Menu.Clear.SpellFarm, newValue) then return end
	end})
	Menu.Clear:MenuElement({id = "SpellHarass", name = "Use Spell Harass(In LaneClear Mode)", toggle = true, value = true, key = string.byte("H"), callback = function(newValue)
		if CheckChatBlock(Menu.Clear.SpellHarass, newValue) then return end
	end})
	Menu.Clear:MenuElement({type = MENU, id = "LaneClear", name = "LaneClear"})
	Menu.Clear.LaneClear:MenuElement({id = "Q", name = "Use Q Last Hit", toggle = true, value = true})
	Menu.Clear.LaneClear:MenuElement({id = "E", name = "Use E", toggle = true, value = true})
	Menu.Clear.LaneClear:MenuElement({id = "ECount", name = "Use E | Nearby Minions >=", value = 3, min = 1, max = 6, step = 1})
	Menu.Clear:MenuElement({type = MENU, id = "JungleClear", name = "JungleClear"})
	Menu.Clear.JungleClear:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	Menu.Clear.JungleClear:MenuElement({id = "W", name = "Use W", toggle = true, value = true})
	Menu.Clear.JungleClear:MenuElement({id = "E", name = "Use E", toggle = true, value = true})

	Menu:MenuElement({type = MENU, id = "KillSteal", name = "KillSteal"})
	Menu.KillSteal:MenuElement({id = "Q", name = "Auto Q KillSteal", toggle = true, value = true})
	Menu.KillSteal:MenuElement({id = "W", name = "Auto W KillSteal", toggle = true, value = true})
	Menu.KillSteal:MenuElement({id = "E", name = "Auto E KillSteal", toggle = true, value = true})

	Menu:MenuElement({type = MENU, id = "Misc", name = "Misc"})
	Menu.Misc:MenuElement({id = "SemiR", name = "Semi-manual R To Mouse", key = string.byte("T")})
	Menu.Misc:MenuElement({id = "RMinRange", name = "Semi R | Minimum Range", value = 1000, min = 0, max = 3000, step = 100})

	Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
	Menu.Draw:MenuElement({id = "DrawFarm", name = "Draw Spell Farm Status", toggle = true, value = true})
	Menu.Draw:MenuElement({id = "DrawHarass", name = "Draw Spell Harass Status", toggle = true, value = true})
	Menu.Draw:MenuElement({id = "Q", name = "Draw Q Range", toggle = true, value = false})
	Menu.Draw:MenuElement({id = "W", name = "Draw W Range", toggle = true, value = false})
	Menu.Draw:MenuElement({id = "E", name = "Draw E Range", toggle = true, value = false})
end

function ClassicPantheon:IsChanneling()
	local activeSpell = myHero.activeSpell
	return HaveBuff(myHero, "Jade_PantheonEChannel")
		or HaveBuff(myHero, "Jade_PantheonR")
		or (activeSpell and activeSpell.valid and (activeSpell.name == "Jade_PantheonE" or activeSpell.name == "Jade_PantheonR"))
end

function ClassicPantheon:Tick()
	local channeling = self:IsChanneling()
	_G.SDK.Orbwalker:SetAttack(not channeling)
	_G.SDK.Orbwalker:SetMovement(not channeling)
	if channeling then return end
	if ShouldWait() then return end
	if IsCasting() then return end

	self:SemiR()
	self:KillSteal()
	local mode = GetMode()
	if mode == "Combo" then
		self:Combo()
	elseif mode == "Harass" then
		self:Harass()
	elseif mode == "LaneClear" then
		self:FarmHarass()
		self:LaneClear()
		self:JungleClear()
	end
end

function ClassicPantheon:GetComboTarget(range)
	if GetTickCount() < self.comboTargetExpire and IsValid(self.comboTarget) then
		if myHero.pos:DistanceTo(self.comboTarget.pos) <= range then
			return self.comboTarget
		end
	end
	return GetTarget(range)
end

function ClassicPantheon:SetComboTarget(target)
	self.comboTarget = target
	self.comboTargetExpire = GetTickCount() + 2000
end

function ClassicPantheon:Combo()
	if Menu.Combo.W:Value() and IsReady(_W) then
		local target = self:GetComboTarget(self.WSpell.Range)
		if IsValid(target) and target.pos2D.onScreen then
			self:SetComboTarget(target)
			Control.CastSpell(HK_W, target)
			return
		end
	end

	if Menu.Combo.E:Value() and IsReady(_E) then
		local target = self:GetComboTarget(self.ESpell.Range)
		if IsValid(target) and target.pos2D.onScreen then
			if self:CastE(target) then return end
		end
	end

	if Menu.Combo.Q:Value() and IsReady(_Q) then
		local target = self:GetComboTarget(self.QSpell.Range)
		if IsValid(target) and target.pos2D.onScreen then
			Control.CastSpell(HK_Q, target)
		end
	end
end

function ClassicPantheon:Harass()
	if Menu.Harass.Q:Value() and IsReady(_Q) then
		local target = GetTarget(self.QSpell.Range)
		if IsValid(target) and target.pos2D.onScreen then
			Control.CastSpell(HK_Q, target)
			return
		end
	end
	if Menu.Harass.W:Value() and IsReady(_W) then
		local target = GetTarget(self.WSpell.Range)
		if IsValid(target) and target.pos2D.onScreen then
			Control.CastSpell(HK_W, target)
			return
		end
	end
	if Menu.Harass.E:Value() and IsReady(_E) then
		local target = GetTarget(self.ESpell.Range)
		if IsValid(target) and target.pos2D.onScreen then
			self:CastE(target)
		end
	end
end

function ClassicPantheon:FarmHarass()
	if Menu.Clear.SpellHarass:Value() and not IsUnderTurret(myHero) then
		self:Harass()
	end
end

function ClassicPantheon:LaneClear()
	if not Menu.Clear.SpellFarm:Value() or IsUnderTurret(myHero) then return end
	local minions = _G.SDK.ObjectManager:GetEnemyMinions(self.QSpell.Range)
	table.sort(minions, function(a, b) return a.distance < b.distance end)

	if Menu.Clear.LaneClear.E:Value() and IsReady(_E) then
		for _, minion in ipairs(minions) do
			if IsValid(minion) and minion.team ~= 300 and minion.pos2D.onScreen and myHero.pos:DistanceTo(minion.pos) <= self.ESpell.Range then
				if GetMinionCount(250, minion.pos) >= Menu.Clear.LaneClear.ECount:Value() then
					Control.CastSpell(HK_E, minion.pos)
					return
				end
			end
		end
	end

	if Menu.Clear.LaneClear.Q:Value() and IsReady(_Q) then
		for _, minion in ipairs(minions) do
			if IsValid(minion) and minion.team ~= 300 and minion.pos2D.onScreen then
				local hp = _G.SDK.HealthPrediction:GetPrediction(minion, 0.25)
				if hp > 0 and self:GetQDmg(minion) >= hp then
					Control.CastSpell(HK_Q, minion)
					return
				end
			end
		end
	end
end

function ClassicPantheon:JungleClear()
	if not Menu.Clear.SpellFarm:Value() then return end
	local monsters = _G.SDK.ObjectManager:GetMonsters(self.QSpell.Range)
	table.sort(monsters, function(a, b) return a.maxHealth > b.maxHealth end)
	local monster = monsters[1]
	if not IsValid(monster) or not monster.pos2D.onScreen then return end

	if Menu.Clear.JungleClear.W:Value() and IsReady(_W) then
		Control.CastSpell(HK_W, monster)
		return
	end
	if Menu.Clear.JungleClear.E:Value() and IsReady(_E) and myHero.pos:DistanceTo(monster.pos) <= self.ESpell.Range then
		Control.CastSpell(HK_E, monster.pos)
		return
	end
	if Menu.Clear.JungleClear.Q:Value() and IsReady(_Q) then
		Control.CastSpell(HK_Q, monster)
	end
end

function ClassicPantheon:SemiR()
	if not Menu.Misc.SemiR:Value() or not IsReady(_R) then return end
	local distance = myHero.pos:DistanceTo(mousePos)
	if distance < Menu.Misc.RMinRange:Value() then return end
	local castPosition = mousePos
	if distance > self.RSpell.Range then
		castPosition = myHero.pos:Extended(mousePos, self.RSpell.Range)
	end
	Control.CastSpell(HK_R, castPosition)
end

function ClassicPantheon:KillSteal()
	local enemies = _G.SDK.ObjectManager:GetEnemyHeroes(self.QSpell.Range)
	for _, target in ipairs(enemies) do
		if IsValid(target) and target.pos2D.onScreen then
			if Menu.KillSteal.Q:Value() and IsReady(_Q) then
				if self:GetQDmg(target) >= target.health + target.hpRegen + target.shieldAD then
					Control.CastSpell(HK_Q, target)
					return
				end
			end
			if Menu.KillSteal.W:Value() and IsReady(_W) then
				if self:GetWDmg(target) >= target.health + target.hpRegen + target.shieldAP then
					Control.CastSpell(HK_W, target)
					return
				end
			end
			if Menu.KillSteal.E:Value() and IsReady(_E) and myHero.pos:DistanceTo(target.pos) <= self.ESpell.Range then
				if self:GetEDmg(target) >= target.health + target.hpRegen + target.shieldAD then
					if self:CastE(target) then return end
				end
			end
		end
	end
end

function ClassicPantheon:CastE(target)
	local prediction = GGPrediction:SpellPrediction(self.ESpell)
	prediction:GetPrediction(target, myHero)
	if prediction:CanHit(2) then
		return Control.CastSpell(HK_E, prediction.CastPosition)
	end
	return false
end

function ClassicPantheon:IsExecuteTarget(target)
	return target.maxHealth > 0 and target.health / target.maxHealth < 0.15
end

function ClassicPantheon:GetQDmg(target)
	local level = myHero:GetSpellData(_Q).level
	if level == 0 then return 0 end
	local damage = ({65, 105, 145, 185, 225})[level] + myHero.bonusDamage * 1.40
	if self:IsExecuteTarget(target) then damage = damage * 2 end
	return _G.SDK.Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_PHYSICAL, damage)
end

function ClassicPantheon:GetWDmg(target)
	local level = myHero:GetSpellData(_W).level
	if level == 0 then return 0 end
	local damage = ({50, 75, 100, 125, 150})[level] + myHero.ap
	return _G.SDK.Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_MAGICAL, damage)
end

function ClassicPantheon:GetEDmg(target)
	local level = myHero:GetSpellData(_E).level
	if level == 0 then return 0 end
	local damage = (({26, 46, 66, 86, 106})[level] + myHero.bonusDamage * 1.20) * 3
	if self:IsExecuteTarget(target) then damage = damage * 2 end
	return _G.SDK.Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_PHYSICAL, damage)
end

function ClassicPantheon:Draw()
	if myHero.dead then return end
	if Menu.Draw.DrawFarm:Value() then
		Draw.Text(Menu.Clear.SpellFarm:Value() and "Spell Farm: On" or "Spell Farm: Off", 16, myHero.pos2D.x-57, myHero.pos2D.y+58, Draw.Color(200, 242, 120, 34))
	end
	if Menu.Draw.DrawHarass:Value() then
		Draw.Text(Menu.Clear.SpellHarass:Value() and "Spell Harass: On" or "Spell Harass: Off", 16, myHero.pos2D.x-57, myHero.pos2D.y+78, Draw.Color(200, 242, 120, 34))
	end
	if Menu.Draw.Q:Value() and IsReady(_Q) then Draw.Circle(myHero.pos, self.QSpell.Range, 1, Draw.Color(255, 66, 244, 113)) end
	if Menu.Draw.W:Value() and IsReady(_W) then Draw.Circle(myHero.pos, self.WSpell.Range, 1, Draw.Color(255, 244, 238, 66)) end
	if Menu.Draw.E:Value() and IsReady(_E) then Draw.Circle(myHero.pos, self.ESpell.Range, 1, Draw.Color(255, 66, 229, 244)) end
end


-- Explicit request context. Nested helpers inherit their caller's context.
V2:RegisterPolicy({
    damageTypes={Q='physical',W='magical',E='physical'},
    methods={


        Combo=function()return V2:ModeContext("Combo")end,
        Harass=function()return V2:ModeContext("Harass")end,
        LaneClear=function()return V2:ModeContext("LaneClear",function()return Menu.Clear.SpellFarm:Value()end)end,
        JungleClear=function()return V2:ModeContext("LaneClear",function()return Menu.Clear.SpellFarm:Value()end)end,
        FarmHarass=function()return V2:ModeContext("LaneClear",function()return Menu.Clear.SpellHarass:Value() and not IsUnderTurret(myHero)end)end,
        SemiR=function()return V2:HeldContext(function()return Menu.Misc.SemiR:Value()end)end,
    },
    exceptions={non_interrupting_summoner=true},
    channel=function(self,q)return not self:IsChanneling() end,
    validate=function(self,q,slot,resolved)
        if slot==_E and q.object then return GetDistance(q.object.pos,myHero.pos)<=self.ESpell.Range end
        return true
    end,
})

ClassicPantheon()

end
if champion=="Ryze" then
local Version = 1.01


local ClassicRyze=class("ClassicRyze")

function ClassicRyze:__init()

	self:LoadMenu()
	Callback.Add("Draw", function() self:Draw() end)
	Callback.Add("Tick", function() self:Tick() end)
	_G.SDK.Orbwalker:OnPreAttack(function(...) self:OnPreAttack(...) end)
	self.QSpell = {Range = 600}
	self.WSpell = {Range = 615}
	self.ESpell = {Range = 615, BounceRange = 400}
	self.comboTarget = nil
	self.comboTargetExpire = 0
end

function ClassicRyze:LoadMenu()
	local championIcon = "http://ddragon.leagueoflegends.com/cdn/16.15.1/img/champion/"..myHero.charName..".png"
	Menu = MenuElement({type = MENU, id = "Classic_AIO_"..myHero.charName, name = "Classic AIO - "..myHero.charName.." V: "..Version, leftIcon = championIcon})

	Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
	Menu.Combo:MenuElement({id = "DisableAA", name = "Disable AA While Spells Ready", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "W", name = "Use W", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "E", name = "Use E", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "R", name = "Use R", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "RCount", name = "Use R | Enemy Count >=", value = 2, min = 1, max = 5, step = 1})
	Menu.Combo:MenuElement({id = "RHP", name = "Use R | Self HP <= x%", value = 35, min = 0, max = 100, step = 5})

	Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
	Menu.Harass:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	Menu.Harass:MenuElement({id = "W", name = "Use W", toggle = true, value = true})
	Menu.Harass:MenuElement({id = "E", name = "Use E", toggle = true, value = true})
	Menu.Harass:MenuElement({id = "Mana", name = "When Mana Percent >= x%", value = 40, min = 0, max = 100, step = 5})

	Menu:MenuElement({type = MENU, id = "Clear", name = "Clear"})
	Menu.Clear:MenuElement({id = "SpellFarm", name = "Use Spell Farm(Mouse Scroll)", toggle = true, value = false, key = 4, callback = function(newValue)
		if CheckChatBlock(Menu.Clear.SpellFarm, newValue) then return end
	end})
	Menu.Clear:MenuElement({id = "SpellHarass", name = "Use Spell Harass(In LaneClear Mode)", toggle = true, value = true, key = string.byte("H"), callback = function(newValue)
		if CheckChatBlock(Menu.Clear.SpellHarass, newValue) then return end
	end})
	Menu.Clear:MenuElement({type = MENU, id = "LaneClear", name = "LaneClear"})
	Menu.Clear.LaneClear:MenuElement({id = "Q", name = "Use Q Last Hit", toggle = true, value = true})
	Menu.Clear.LaneClear:MenuElement({id = "E", name = "Use E", toggle = true, value = true})
	Menu.Clear.LaneClear:MenuElement({id = "ECount", name = "Use E | Nearby Minions >=", value = 3, min = 1, max = 6, step = 1})
	Menu.Clear.LaneClear:MenuElement({id = "Mana", name = "When Mana Percent >= x%", value = 30, min = 0, max = 100, step = 5})
	Menu.Clear:MenuElement({type = MENU, id = "JungleClear", name = "JungleClear"})
	Menu.Clear.JungleClear:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	Menu.Clear.JungleClear:MenuElement({id = "W", name = "Use W", toggle = true, value = true})
	Menu.Clear.JungleClear:MenuElement({id = "E", name = "Use E", toggle = true, value = true})

	Menu:MenuElement({type = MENU, id = "KillSteal", name = "KillSteal"})
	Menu.KillSteal:MenuElement({id = "Q", name = "Auto Q KillSteal", toggle = true, value = true})
	Menu.KillSteal:MenuElement({id = "W", name = "Auto W KillSteal", toggle = true, value = true})
	Menu.KillSteal:MenuElement({id = "E", name = "Auto E KillSteal", toggle = true, value = true})

	Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
	Menu.Draw:MenuElement({id = "DrawFarm", name = "Draw Spell Farm Status", toggle = true, value = true})
	Menu.Draw:MenuElement({id = "DrawHarass", name = "Draw Spell Harass Status", toggle = true, value = true})
	Menu.Draw:MenuElement({id = "Q", name = "Draw Q Range", toggle = true, value = false})
	Menu.Draw:MenuElement({id = "W", name = "Draw W Range", toggle = true, value = false})
	Menu.Draw:MenuElement({id = "E", name = "Draw E Range", toggle = true, value = false})
end

function ClassicRyze:OnPreAttack(args)
	if GetMode() ~= "Combo" or not Menu.Combo.DisableAA:Value() then return end
	local target = args.Target
	if not IsValid(target) or target.type ~= Obj_AI_Hero then return end
	local distance = myHero.pos:DistanceTo(target.pos)
	if V2:HasObservedSpell() then
		args.Process = false
	end
end

function ClassicRyze:Tick()
	if ShouldWait() then return end
	if IsCasting() then return end
	self:KillSteal()
	local mode = GetMode()
	if mode == "Combo" then
		self:Combo()
	elseif mode == "Harass" then
		self:Harass()
	elseif mode == "LaneClear" then
		self:FarmHarass()
		self:LaneClear()
		self:JungleClear()
	end
end

function ClassicRyze:GetComboTarget(range)
	if GetTickCount() < self.comboTargetExpire and IsValid(self.comboTarget) then
		if myHero.pos:DistanceTo(self.comboTarget.pos) <= range then
			return self.comboTarget
		end
	end
	return GetTarget(range)
end

function ClassicRyze:SetComboTarget(target)
	self.comboTarget = target
	self.comboTargetExpire = GetTickCount() + 2500
end

function ClassicRyze:Combo()
	local target = self:GetComboTarget(self.ESpell.Range)
	if not IsValid(target) or not target.pos2D.onScreen then return end
	self:SetComboTarget(target)

	if Menu.Combo.R:Value() and IsReady(_R) and not HaveBuff(myHero, "Jade_RyzeR") then
		local hpPercent = myHero.maxHealth > 0 and myHero.health / myHero.maxHealth * 100 or 100
		if GetEnemyCount(700, myHero.pos) >= Menu.Combo.RCount:Value() or hpPercent <= Menu.Combo.RHP:Value() then
			Control.CastSpell(HK_R)
			return
		end
	end

	if Menu.Combo.E:Value() and IsReady(_E) and not HaveBuff(target, "Jade_RyzeE") then
		Control.CastSpell(HK_E, target)
		return
	end
	if Menu.Combo.Q:Value() and IsReady(_Q) and myHero.pos:DistanceTo(target.pos) <= self.QSpell.Range then
		Control.CastSpell(HK_Q, target)
		return
	end
	if Menu.Combo.W:Value() and IsReady(_W) then
		Control.CastSpell(HK_W, target)
		return
	end
	if Menu.Combo.E:Value() and IsReady(_E) then
		Control.CastSpell(HK_E, target)
	end
end

function ClassicRyze:Harass()
	if myHero.maxMana > 0 and myHero.mana / myHero.maxMana * 100 < Menu.Harass.Mana:Value() then return end
	local target = GetTarget(self.ESpell.Range)
	if not IsValid(target) or not target.pos2D.onScreen then return end

	if Menu.Harass.E:Value() and IsReady(_E) and not HaveBuff(target, "Jade_RyzeE") then
		Control.CastSpell(HK_E, target)
		return
	end
	if Menu.Harass.Q:Value() and IsReady(_Q) and myHero.pos:DistanceTo(target.pos) <= self.QSpell.Range then
		Control.CastSpell(HK_Q, target)
		return
	end
	if Menu.Harass.W:Value() and IsReady(_W) then
		Control.CastSpell(HK_W, target)
		return
	end
	if Menu.Harass.E:Value() and IsReady(_E) then
		Control.CastSpell(HK_E, target)
	end
end

function ClassicRyze:FarmHarass()
	if Menu.Clear.SpellHarass:Value() and not IsUnderTurret(myHero) then
		self:Harass()
	end
end

function ClassicRyze:LaneClear()
	if not Menu.Clear.SpellFarm:Value() or IsUnderTurret(myHero) then return end
	if myHero.maxMana > 0 and myHero.mana / myHero.maxMana * 100 < Menu.Clear.LaneClear.Mana:Value() then return end
	local minions = _G.SDK.ObjectManager:GetEnemyMinions(self.ESpell.Range)
	table.sort(minions, function(a, b) return a.distance < b.distance end)

	if Menu.Clear.LaneClear.E:Value() and IsReady(_E) then
		for _, minion in ipairs(minions) do
			if IsValid(minion) and minion.team ~= 300 and minion.pos2D.onScreen then
				if GetMinionCount(self.ESpell.BounceRange, minion.pos) >= Menu.Clear.LaneClear.ECount:Value() then
					Control.CastSpell(HK_E, minion)
					return
				end
			end
		end
	end

	if Menu.Clear.LaneClear.Q:Value() and IsReady(_Q) then
		for _, minion in ipairs(minions) do
			if IsValid(minion) and minion.team ~= 300 and minion.pos2D.onScreen and myHero.pos:DistanceTo(minion.pos) <= self.QSpell.Range then
				local hp = _G.SDK.HealthPrediction:GetPrediction(minion, 0.25)
				if hp > 0 and self:GetQDmg(minion) >= hp then
					Control.CastSpell(HK_Q, minion)
					return
				end
			end
		end
	end
end

function ClassicRyze:JungleClear()
	if not Menu.Clear.SpellFarm:Value() then return end
	local monsters = _G.SDK.ObjectManager:GetMonsters(self.ESpell.Range)
	table.sort(monsters, function(a, b) return a.maxHealth > b.maxHealth end)
	local monster = monsters[1]
	if not IsValid(monster) or not monster.pos2D.onScreen then return end

	if Menu.Clear.JungleClear.E:Value() and IsReady(_E) then
		Control.CastSpell(HK_E, monster)
		return
	end
	if Menu.Clear.JungleClear.Q:Value() and IsReady(_Q) and myHero.pos:DistanceTo(monster.pos) <= self.QSpell.Range then
		Control.CastSpell(HK_Q, monster)
		return
	end
	if Menu.Clear.JungleClear.W:Value() and IsReady(_W) then
		Control.CastSpell(HK_W, monster)
	end
end

function ClassicRyze:KillSteal()
	local enemies = _G.SDK.ObjectManager:GetEnemyHeroes(self.ESpell.Range)
	for _, target in ipairs(enemies) do
		if IsValid(target) and target.pos2D.onScreen then
			local magicHealth = target.health + target.hpRegen + target.shieldAP
			if Menu.KillSteal.Q:Value() and IsReady(_Q) and myHero.pos:DistanceTo(target.pos) <= self.QSpell.Range then
				if self:GetQDmg(target) >= magicHealth then
					Control.CastSpell(HK_Q, target)
					return
				end
			end
			if Menu.KillSteal.W:Value() and IsReady(_W) then
				if self:GetWDmg(target) >= magicHealth then
					Control.CastSpell(HK_W, target)
					return
				end
			end
			if Menu.KillSteal.E:Value() and IsReady(_E) then
				if self:GetEDmg(target) >= magicHealth then
					Control.CastSpell(HK_E, target)
					return
				end
			end
		end
	end
end

function ClassicRyze:GetQDmg(target)
	local level = myHero:GetSpellData(_Q).level
	if level == 0 then return 0 end
	local damage = ({60, 85, 110, 135, 160})[level] + myHero.ap * 0.40 + myHero.maxMana * 0.065
	return _G.SDK.Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_MAGICAL, damage)
end

function ClassicRyze:GetWDmg(target)
	local level = myHero:GetSpellData(_W).level
	if level == 0 then return 0 end
	local damage = ({60, 95, 130, 165, 200})[level] + myHero.ap * 0.60 + myHero.maxMana * 0.045
	return _G.SDK.Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_MAGICAL, damage)
end

function ClassicRyze:GetEDmg(target)
	local level = myHero:GetSpellData(_E).level
	if level == 0 then return 0 end
	local damage = ({50, 70, 90, 110, 130})[level] + myHero.ap * 0.35 + myHero.maxMana * 0.01
	return _G.SDK.Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_MAGICAL, damage)
end

function ClassicRyze:Draw()
	if myHero.dead then return end
	if Menu.Draw.DrawFarm:Value() then
		Draw.Text(Menu.Clear.SpellFarm:Value() and "Spell Farm: On" or "Spell Farm: Off", 16, myHero.pos2D.x-57, myHero.pos2D.y+58, Draw.Color(200, 242, 120, 34))
	end
	if Menu.Draw.DrawHarass:Value() then
		Draw.Text(Menu.Clear.SpellHarass:Value() and "Spell Harass: On" or "Spell Harass: Off", 16, myHero.pos2D.x-57, myHero.pos2D.y+78, Draw.Color(200, 242, 120, 34))
	end
	if Menu.Draw.Q:Value() and IsReady(_Q) then Draw.Circle(myHero.pos, self.QSpell.Range, 1, Draw.Color(255, 66, 244, 113)) end
	if Menu.Draw.W:Value() and IsReady(_W) then Draw.Circle(myHero.pos, self.WSpell.Range, 1, Draw.Color(255, 244, 238, 66)) end
	if Menu.Draw.E:Value() and IsReady(_E) then Draw.Circle(myHero.pos, self.ESpell.Range, 1, Draw.Color(255, 66, 229, 244)) end
end


-- Explicit request context. Nested helpers inherit their caller's context.
V2:RegisterPolicy({
    damageTypes={Q='magical',W='magical',E='magical'},
    methods={

        OnPreAttack=function()local mode=GetMode();return mode and V2:ModeContext(mode) or nil end,

        Combo=function()return V2:ModeContext("Combo")end,
        Harass=function()return V2:ModeContext("Harass")end,
        LaneClear=function()return V2:ModeContext("LaneClear",function()return Menu.Clear.SpellFarm:Value()end)end,
        JungleClear=function()return V2:ModeContext("LaneClear",function()return Menu.Clear.SpellFarm:Value()end)end,
        FarmHarass=function()return V2:ModeContext("LaneClear",function()return Menu.Clear.SpellHarass:Value() and not IsUnderTurret(myHero)end)end,
    },
    exceptions={non_interrupting_summoner=true},
    channel=function(self,q)return not (myHero.activeSpell and myHero.activeSpell.valid and myHero.activeSpell.isChanneling) end,
    validate=function(self,q,slot,resolved)
        if slot==_E and q.owner=='LaneClear' and q.object then return GetMinionCount(self.ESpell.BounceRange,q.object.pos)>=Menu.Clear.LaneClear.ECount:Value()end
        if slot==_Q and q.owner=='LaneClear' and q.object then local hp=SDK.HealthPrediction:GetPrediction(q.object,.25);return hp>0 and self:GetQDmg(q.object)>=hp end
        if slot==_R and q.owner=='Combo'then return not HaveBuff(myHero,'Jade_RyzeR') and (GetEnemyCount(700,myHero.pos)>=Menu.Combo.RCount:Value() or myHero.health/myHero.maxHealth*100<=Menu.Combo.RHP:Value())end
        return true
    end,
})

ClassicRyze()

end
if champion=="Sivir" then
local Version = 1.01


local shellSpells = {
    ["Jade_AlistarW"] = {charName = "Jade_Alistar", slot = "W", speed = math.huge, delay = 0.51},
    ["Jade_AniviaFrostbite"] = {charName = "Jade_Anivia", slot = "E", speed = 1600, delay = 0.25},
    ["Jade_AnnieQ"] = {charName = "Jade_Annie", slot = "Q", speed = 1400, delay = 0.25},
    ["Jade_BlitzcrankPowerFistAttack"] = {charName = "Jade_Blitzcrank", slot = "E", speed = math.huge, delay = 0.34},
    ["Jade_BrandE"] = {charName = "Jade_Brand", slot = "E", speed = 1800, delay = 0.25},
    ["Jade_BrandR"] = {charName = "Jade_Brand", slot = "R", speed = 1000, delay = 0.25},
    ["Jade_ChogathR"] = {charName = "Jade_Chogath", slot = "R", speed = math.huge, delay = 0.25},
    ["Jade_EvelynnE"] = {charName = "Jade_Evelynn", slot = "E", speed = 902, delay = 0.25},
    ["Jade_FiddlesticksQ"] = {charName = "Jade_Fiddlesticks", slot = "Q", speed = math.huge, delay = 0.25},
    ["Jade_FiddlesticksW"] = {charName = "Jade_Fiddlesticks", slot = "W", speed = math.huge, delay = 0.25},
    ["Jade_FiddlesticksE"] = {charName = "Jade_Fiddlesticks", slot = "E", speed = 1800, delay = 0.40},
    ["Jade_GangplankQ"] = {charName = "Jade_Gangplank", slot = "Q", speed = 2000, delay = 0.25},
    ["Jade_GarenQAttack"] = {charName = "Jade_Garen", slot = "Q", speed = math.huge, delay = 0.39},
    ["Jade_GarenR"] = {charName = "Jade_Garen", slot = "R", speed = math.huge, delay = 0.44},
    ["Jade_JannaSowTheWind"] = {charName = "Jade_Janna", slot = "W", speed = 1600, delay = 0.25},
    ["Jade_JarvanIVCataclysm"] = {charName = "Jade_JarvanIV", slot = "R", speed = math.huge, delay = 0.25},
    ["Jade_JaxQ"] = {charName = "Jade_Jax", slot = "Q", speed = math.huge, delay = 0.25},
    ["Jade_JaxWAttack"] = {charName = "Jade_Jax", slot = "W", speed = math.huge, delay = 0},
    ["Jade_KassadinQ"] = {charName = "Jade_Kassadin", slot = "Q", speed = 1400, delay = 0.25},
    ["Jade_KatarinaQ"] = {charName = "Jade_Katarina", slot = "Q", speed = 1600, delay = 0.25},
    ["Jade_KatarinaE"] = {charName = "Jade_Katarina", slot = "E", speed = math.huge, delay = 0},
    ["Jade_KayleQ"] = {charName = "Jade_Kayle", slot = "Q", speed = 1000, delay = 0.25},
    ["Jade_KogMawQ"] = {charName = "Jade_KogMaw", slot = "Q", speed = 1500, delay = 0.25},
    ["Jade_LeeSinQTwo"] = {charName = "Jade_LeeSin", slot = "Q2", speed = 2200, delay = 0.25},
    ["Jade_LeeSinR"] = {charName = "Jade_LeeSin", slot = "R", speed = 1500, delay = 0.25},
    ["Jade_LeonaShieldOfDaybreakAttack"] = {charName = "Jade_Leona", slot = "Q", speed = math.huge, delay = 0.39},
    ["Jade_LuluW"] = {charName = "Jade_Lulu", slot = "W", speed = 2000, delay = 0.175},
    ["Jade_LuluE"] = {charName = "Jade_Lulu", slot = "E", speed = math.huge, delay = 0.175},
    ["Jade_MalphiteSeismicShard"] = {charName = "Jade_Malphite", slot = "Q", speed = 1200, delay = 0.25},
    ["Jade_MalzaharE"] = {charName = "Jade_Malzahar", slot = "E", speed = 1400, delay = 0.25},
    ["Jade_MalzaharR"] = {charName = "Jade_Malzahar", slot = "R", speed = math.huge, delay = 0.25},
    ["Jade_MasterYiAlphaStrike"] = {charName = "Jade_MasterYi", slot = "Q", speed = 4000, delay = 0.10},
    ["Jade_MissFortuneRicochetShot"] = {charName = "Jade_MissFortune", slot = "Q", speed = 1400, delay = 0.25},
    ["Jade_NasusSiphoningStrikeAttack"] = {charName = "Jade_Nasus", slot = "Q", speed = math.huge, delay = 0.52},
    ["Jade_NasusW"] = {charName = "Jade_Nasus", slot = "W", speed = math.huge, delay = 0.25},
    ["Jade_NidaleeCougarTakedownAttack"] = {charName = "Jade_Nidalee", slot = "Q2", speed = math.huge, delay = 0.35},
    ["Jade_NunuE"] = {charName = "Jade_Nunu", slot = "E", speed = 1000, delay = 0.25},
    ["Jade_OlafE"] = {charName = "Jade_Olaf", slot = "E", speed = math.huge, delay = 0.25},
    ["Jade_PantheonQ"] = {charName = "Jade_Pantheon", slot = "Q", speed = 1200, delay = 0.25},
    ["Jade_PantheonW"] = {charName = "Jade_Pantheon", slot = "W", speed = math.huge, delay = 0.125},
    ["Jade_RammusE"] = {charName = "Jade_Rammus", slot = "E", speed = math.huge, delay = 0.25},
    ["Jade_RyzeQ"] = {charName = "Jade_Ryze", slot = "Q", speed = 1700, delay = 0.25},
    ["Jade_RyzeW"] = {charName = "Jade_Ryze", slot = "W", speed = math.huge, delay = 0.25},
    ["Jade_RyzeE"] = {charName = "Jade_Ryze", slot = "E", speed = 1000, delay = 0.25},
    ["Jade_ShacoTwoShivPoison"] = {charName = "Jade_Shaco", slot = "E", speed = 1500, delay = 0.25},
    ["Jade_SingedFling"] = {charName = "Jade_Singed", slot = "E", speed = math.huge, delay = 0.25},
    ["Jade_SionQ"] = {charName = "Jade_Sion", slot = "Q", speed = 1600, delay = 0.25},
    ["Jade_SkarnerR"] = {charName = "Jade_Skarner", slot = "R", speed = math.huge, delay = 0.25},
    ["Jade_SorakaE"] = {charName = "Jade_Soraka", slot = "E", speed = math.huge, delay = 0.25},
    ["Jade_TaricE"] = {charName = "Jade_Taric", slot = "E", speed = 1750, delay = 0.25},
    ["Jade_TeemoQ"] = {charName = "Jade_Teemo", slot = "Q", speed = 1500, delay = 0.25},
    ["Jade_TristanaE"] = {charName = "Jade_Tristana", slot = "E", speed = 1400, delay = 0.25},
    ["Jade_TristanaR"] = {charName = "Jade_Tristana", slot = "R", speed = 1600, delay = 0.25},
    ["Jade_TwistedFate_BlueCardPreAttack"] = {charName = "Jade_TwistedFate", slot = "Blue W", speed = 1500, delay = 0.125},
    ["Jade_TwistedFate_GoldCardPreAttack"] = {charName = "Jade_TwistedFate", slot = "Gold W", speed = 1500, delay = 0.125},
    ["Jade_TwistedFate_RedCardPreAttack"] = {charName = "Jade_TwistedFate", slot = "Red W", speed = 1500, delay = 0.125},
    ["Jade_VayneE"] = {charName = "Jade_Vayne", slot = "E", speed = 1200, delay = 0.25},
    ["Jade_VeigarBalefulStrike"] = {charName = "Jade_Veigar", slot = "Q", speed = 1200, delay = 0.25},
    ["Jade_VeigarR"] = {charName = "Jade_Veigar", slot = "R", speed = 1400, delay = 0.25},
    ["Jade_WarwickQ"] = {charName = "Jade_Warwick", slot = "Q", speed = 1500, delay = 0.25},
    ["Jade_WarwickR"] = {charName = "Jade_Warwick", slot = "R", speed = math.huge, delay = 0.10},
    ["Jade_WukongQAttack"] = {charName = "Jade_Wukong", slot = "Q", speed = math.huge, delay = 0.35},
    ["Jade_WukongE"] = {charName = "Jade_Wukong", slot = "E", speed = 2200, delay = 0},
    ["Jade_ZileanQ"] = {charName = "Jade_Zilean", slot = "Q", speed = math.huge, delay = 0.25},
    ["Jade_ZileanE"] = {charName = "Jade_Zilean", slot = "E", speed = math.huge, delay = 0.515},
}

local ClassicSivir=class("ClassicSivir")

function ClassicSivir:__init()

    self.Q = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 90, Range = 1250, Speed = 1350, Collision = true, CollisionTypes = {GGPrediction.COLLISION_YASUOWALL}}
    self:LoadMenu()
    Callback.Add("Tick", function() self:Tick() end)
    Callback.Add("Draw", function() self:Draw() end)
end

function ClassicSivir:LoadMenu()

    local championIcon = "http://ddragon.leagueoflegends.com/cdn/16.15.1/img/champion/"..myHero.charName..".png"
    Menu = MenuElement({type = MENU, id = "Classic_AIO_"..myHero.charName, name = "Classic AIO - "..myHero.charName.." V: "..Version, leftIcon = championIcon})

    Menu:MenuElement({type = MENU, id = "combo", name = "Combo"})
        Menu.combo:MenuElement({id = "Q", name = "Use Q Combo", value = true})
        Menu.combo:MenuElement({id = "maxRange", name = "Max Q Range", value = 1150, min = 0, max = 1250, step = 10})
        Menu.combo:MenuElement({id = "W", name = "Use W AOE (2+ Enemy Heroes)", value = true})

    Menu:MenuElement({type = MENU, id = "harass", name = "Harass"})
        Menu.harass:MenuElement({id = "Q", name = "Use Q Harass", value = true})
        Menu.harass:MenuElement({id = "maxRange", name = "Max Q Range", value = 1150, min = 0, max = 1250, step = 10})
        Menu.harass:MenuElement({id = "mana", name = "Only cast spell if mana >", value = 30, min = 0, max = 100, step = 1})

    Menu:MenuElement({type = MENU, id = "auto", name = "Auto Q"})
        Menu.auto:MenuElement({id = "Q", name = "Use Q in Immobile Target", value = true})

    Menu:MenuElement({type = MENU, id = "eSetting", name = "E Setting"})
        Menu.eSetting:MenuElement({id = "eDelay", name = "Xs before Spell hit", value = 0.2, min = 0, max = 1.5, step = 0.01})
        Menu.eSetting:MenuElement({type = MENU, id = "blockSpell", name = "Auto E Block Spell"})
        _G.SDK.ObjectManager:OnEnemyHeroLoad(function(args)
            for k, v in pairs(shellSpells) do
                if v.charName == args.charName then
                    Menu.eSetting.blockSpell:MenuElement({id = k, name = v.charName.." | "..v.slot, value = true})
                end
            end
        end)
        Menu.eSetting:MenuElement({type = MENU, id = "dash", name = "Auto E If Enemy dash on ME"})
        _G.SDK.ObjectManager:OnEnemyHeroLoad(function(args)
            Menu.eSetting.dash:MenuElement({id = args.charName, name = args.charName, value = false})
        end)

    Menu:MenuElement({type = MENU, id = "draw", name = "Draw Setting"})
        Menu.draw:MenuElement({id = "Q", name = "Draw Q", value = false})

end

function ClassicSivir:Draw()
    if myHero.dead then return end
    if Menu.draw.Q:Value() and IsReady(_Q) then
        Draw.Circle(myHero.pos, self.Q.Range,Draw.Color(255,255, 162, 000))
    end

end

function ClassicSivir:Tick()
    if ShouldWait() or IsCasting() then return end

    local mode = GetMode()
    if mode == "Combo" then 
        self:Combo()
    elseif mode == "Harass" then 
        self:Harass()
    end
    if mode ~= "LaneClear" and IsReady(_W) and myHero:GetSpellData(_W).toggleState == 2 and lastW + 300 < GetTickCount() then
        local target = GetTarget(self.Q.Range)
        if mode ~= "Combo" or not Menu.combo.W:Value() or not target or not IsValid(target) or not _G.SDK.Data:IsInAutoAttackRange(myHero, target) or GetEnemyCount(450, target.pos) < 2 then
            Control.CastSpell(HK_W)
            V2:AfterCast(HK_W, function() lastW = GetTickCount() end)
        end
    end
    self:BlockSpell()
    self:AutoQ()
end

function ClassicSivir:Combo() 
    local target = GetTarget(self.Q.Range)
    if target and IsValid(target) then
        if Menu.combo.W:Value() and IsReady(_W) and myHero:GetSpellData(_W).toggleState == 1 and lastW + 300 < GetTickCount() and _G.SDK.Data:IsInAutoAttackRange(myHero, target) and GetEnemyCount(450, target.pos) >= 2 then
            Control.CastSpell(HK_W)
            V2:AfterCast(HK_W, function() lastW = GetTickCount() end)
        end
        if Menu.combo.Q:Value() and myHero.pos:DistanceTo(target.pos) < Menu.combo.maxRange:Value() then
            self:CastQ(target)
        end
    end
end

function ClassicSivir:Harass() 
    local manaPer = myHero.mana/myHero.maxMana
    local target = GetTarget(self.Q.Range)
    if target and IsValid(target) and myHero.pos:DistanceTo(target.pos) < Menu.harass.maxRange:Value() and Menu.harass.mana:Value()/100 < manaPer then
        if Menu.harass.Q:Value() then
            self:CastQ(target)
        end
    end
end

function ClassicSivir:CastQ(target)
    if IsReady(_Q) and target.pos2D.onScreen then
        local Pred = GGPrediction:SpellPrediction(self.Q)
        Pred:GetPrediction(target, myHero)
        if Pred:CanHit(GGPrediction.HITCHANCE_HIGH) then
            Control.CastSpell(HK_Q, Pred.CastPosition)
        end
    end
end

function ClassicSivir:AutoQ()
    for k , target in pairs(_G.SDK.ObjectManager:GetEnemyHeroes()) do 
        if Menu.auto.Q:Value() and myHero.pos:DistanceTo(target.pos) < self.Q.Range and IsValid(target) and IsHardCC(target) then
            self:CastQ(target)
        end
    end
end

function ClassicSivir:BlockSpell()
    if IsReady(_E) then
        for k , hero in pairs(_G.SDK.ObjectManager:GetEnemyHeroes()) do
            if hero.activeSpell.valid and shellSpells[hero.activeSpell.name] ~= nil then
                if hero.activeSpell.target == myHero.handle and Menu.eSetting.blockSpell[hero.activeSpell.name]:Value() then
                    local dt = hero.pos:DistanceTo(myHero.pos)
                    local spell = shellSpells[hero.activeSpell.name]
                    local hitTime = spell.delay + dt/spell.speed
                    local observedStart=hero.activeSpell.startTime or Game.Timer()
                    local deadline=observedStart+hitTime
                    V2:Delayed('shield:'..hero.networkID..':'..observedStart,math.max(0,deadline-Game.Timer()-Menu.eSetting.eDelay:Value()),function()
                        if IsReady(_E) and Game.Timer()<=deadline+.1 and not myHero.dead
                            and Menu.eSetting.blockSpell[hero.activeSpell.name] and Menu.eSetting.blockSpell[hero.activeSpell.name]:Value() then
                            V2:Cast(HK_E,nil,{owner='spellshield',priority='interactive',ttl=100,independent=false})
                        end
                    end)
                    return
                end
            end

            if hero.pathing.isDashing and Menu.eSetting.dash[hero.charName] and Menu.eSetting.dash[hero.charName]:Value() then
                local vct = Vector(hero.pathing.endPos.x,hero.pathing.endPos.y,hero.pathing.endPos.z)
                if vct:DistanceTo(myHero.pos) < 172 then
                    Control.CastSpell(HK_E)
                    return
                end
            end
        end
    end
end


-- Explicit request context. Nested helpers inherit their caller's context.
V2:RegisterPolicy({
    methods={
        AutoQ=function()return {priority='interactive'}end,

        Combo=function()return V2:ModeContext("Combo")end,
        Harass=function()return V2:ModeContext("Harass")end,
    },
    costPaid=function(self,q,slot)return slot==_W and myHero:GetSpellData(_W).toggleState==2 end,
    exceptions={non_interrupting_summoner=true},
    channel=function(self,q)return not (myHero.activeSpell and myHero.activeSpell.valid and myHero.activeSpell.isChanneling) end,
    validate=function(self,q,slot,resolved)
        if slot==_W and (q.owner=='Combo' or q.owner=='Harass')then return myHero:GetSpellData(_W).toggleState~=2 end
        return true
    end,
})

ClassicSivir()

end
if champion=="Skarner" then
local Version = 1.01


local ClassicSkarner=class("ClassicSkarner")

function ClassicSkarner:__init()

	self:LoadMenu()
	Callback.Add("Draw", function() self:Draw() end)
	Callback.Add("Tick", function() self:Tick() end)
	self.QSpell = {Range = 350}
	self.WSpell = {Range = 900}
	self.ESpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 70, Range = 800, Speed = 1800, Collision = true, CollisionTypes = {GGPrediction.COLLISION_YASUOWALL}}
	self.RSpell = {Range = 500}
end

function ClassicSkarner:LoadMenu()
	local championIcon = "http://ddragon.leagueoflegends.com/cdn/16.15.1/img/champion/"..myHero.charName..".png"
	Menu = MenuElement({type = MENU, id = "Classic_AIO_"..myHero.charName, name = "Classic AIO - "..myHero.charName.." V: "..Version, leftIcon = championIcon})

	Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
	Menu.Combo:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "W", name = "Use W", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "E", name = "Use E", toggle = true, value = true})

	Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
	Menu.Harass:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	Menu.Harass:MenuElement({id = "E", name = "Use E", toggle = true, value = true})

	Menu:MenuElement({type = MENU, id = "Clear", name = "Clear"})
	Menu.Clear:MenuElement({id = "SpellFarm", name = "Use Spell Farm(Mouse Scroll)", toggle = true, value = false, key = 4, callback = function(newValue)
		if CheckChatBlock(Menu.Clear.SpellFarm, newValue) then return end
	end})
	Menu.Clear:MenuElement({id = "SpellHarass", name = "Use Spell Harass(In LaneClear Mode)", toggle = true, value = true, key = string.byte("H"), callback = function(newValue)
		if CheckChatBlock(Menu.Clear.SpellHarass, newValue) then return end
	end})
	Menu.Clear:MenuElement({type = MENU, id = "LaneClear", name = "LaneClear"})
	Menu.Clear.LaneClear:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	Menu.Clear.LaneClear:MenuElement({id = "QCount", name = "Use Q | Nearby Minions >=", value = 2, min = 1, max = 6, step = 1})
	Menu.Clear.LaneClear:MenuElement({id = "W", name = "Use W", toggle = true, value = true})
	Menu.Clear.LaneClear:MenuElement({id = "WCount", name = "Use W | Nearby Minions >=", value = 3, min = 1, max = 6, step = 1})
	Menu.Clear.LaneClear:MenuElement({id = "E", name = "Use E", toggle = true, value = true})
	Menu.Clear.LaneClear:MenuElement({id = "ECount", name = "Use E | Nearby Minions >=", value = 3, min = 1, max = 6, step = 1})
	Menu.Clear:MenuElement({type = MENU, id = "JungleClear", name = "JungleClear"})
	Menu.Clear.JungleClear:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	Menu.Clear.JungleClear:MenuElement({id = "W", name = "Use W", toggle = true, value = true})
	Menu.Clear.JungleClear:MenuElement({id = "E", name = "Use E", toggle = true, value = true})

	Menu:MenuElement({type = MENU, id = "KillSteal", name = "KillSteal"})
	Menu.KillSteal:MenuElement({id = "Q", name = "Auto Q KillSteal", toggle = true, value = true})
	Menu.KillSteal:MenuElement({id = "E", name = "Auto E KillSteal", toggle = true, value = true})

	Menu:MenuElement({type = MENU, id = "Misc", name = "Misc"})
	Menu.Misc:MenuElement({id = "SemiR", name = "Semi-manual R Key", key = string.byte("T")})

	Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
	Menu.Draw:MenuElement({id = "DrawFarm", name = "Draw Spell Farm Status", toggle = true, value = true})
	Menu.Draw:MenuElement({id = "DrawHarass", name = "Draw Spell Harass Status", toggle = true, value = true})
	Menu.Draw:MenuElement({id = "Q", name = "Draw Q Range", toggle = true, value = false})
	Menu.Draw:MenuElement({id = "E", name = "Draw E Range", toggle = true, value = false})
	Menu.Draw:MenuElement({id = "R", name = "Draw R Range", toggle = true, value = false})
end

function ClassicSkarner:IsImpaling()
	local activeSpell = myHero.activeSpell
	return HaveBuff(myHero, "Jade_SkarnerR_Buff")
		or (activeSpell and activeSpell.valid and activeSpell.name == "Jade_SkarnerR")
end

function ClassicSkarner:Tick()
	local impaling = self:IsImpaling()
	_G.SDK.Orbwalker:SetAttack(not impaling)
	if ShouldWait() then return end
	if IsCasting() then return end
	if impaling then
		self:ImpaleActions()
		return
	end

	self:SemiR()
	self:KillSteal()
	local mode = GetMode()
	if mode == "Combo" then
		self:Combo()
	elseif mode == "Harass" then
		self:Harass()
	elseif mode == "LaneClear" then
		self:FarmHarass()
		self:LaneClear()
		self:JungleClear()
	end
end

function ClassicSkarner:GetRTarget()
	local selected = _G.SDK.TargetSelector.Selected
	if IsValid(selected) and selected.pos2D.onScreen and myHero.pos:DistanceTo(selected.pos) <= self.RSpell.Range then
		return selected
	end
	return GetTarget(self.RSpell.Range)
end

function ClassicSkarner:Combo()
	if Menu.Combo.E:Value() and IsReady(_E) then
		local target = GetTarget(self.ESpell.Range)
		if IsValid(target) and target.pos2D.onScreen then
			if self:CastE(target) then return end
		end
	end

	if Menu.Combo.W:Value() and IsReady(_W) then
		local target = GetTarget(self.WSpell.Range)
		if IsValid(target) then
			Control.CastSpell(HK_W)
			return
		end
	end

	if Menu.Combo.Q:Value() and IsReady(_Q) then
		local target = GetTarget(self.QSpell.Range)
		if IsValid(target) and myHero.pos:DistanceTo(target.pos) <= self.QSpell.Range then
			Control.CastSpell(HK_Q)
		end
	end
end

function ClassicSkarner:ImpaleActions()
	if Menu.Combo.W:Value() and IsReady(_W) then
		Control.CastSpell(HK_W)
		return
	end
	if Menu.Combo.Q:Value() and IsReady(_Q) and GetEnemyCount(self.QSpell.Range, myHero.pos) > 0 then
		Control.CastSpell(HK_Q)
	end
end

function ClassicSkarner:Harass()
	if Menu.Harass.E:Value() and IsReady(_E) then
		local target = GetTarget(self.ESpell.Range)
		if IsValid(target) and target.pos2D.onScreen then
			if self:CastE(target) then return end
		end
	end
	if Menu.Harass.Q:Value() and IsReady(_Q) then
		local target = GetTarget(self.QSpell.Range)
		if IsValid(target) and myHero.pos:DistanceTo(target.pos) <= self.QSpell.Range then
			Control.CastSpell(HK_Q)
		end
	end
end

function ClassicSkarner:FarmHarass()
	if Menu.Clear.SpellHarass:Value() and not IsUnderTurret(myHero) then
		self:Harass()
	end
end

function ClassicSkarner:LaneClear()
	if not Menu.Clear.SpellFarm:Value() or IsUnderTurret(myHero) then return end
	local minions = _G.SDK.ObjectManager:GetEnemyMinions(self.ESpell.Range)
	table.sort(minions, function(a, b) return a.distance < b.distance end)

	if Menu.Clear.LaneClear.E:Value() and IsReady(_E) then
		for _, minion in ipairs(minions) do
			if IsValid(minion) and minion.team ~= 300 and minion.pos2D.onScreen then
				if GetMinionCount(250, minion.pos) >= Menu.Clear.LaneClear.ECount:Value() then
					Control.CastSpell(HK_E, minion)
					return
				end
			end
		end
	end

	local nearby = 0
	for _, minion in ipairs(minions) do
		if IsValid(minion) and minion.team ~= 300 and myHero.pos:DistanceTo(minion.pos) <= self.QSpell.Range then
			nearby = nearby + 1
		end
	end
	if Menu.Clear.LaneClear.W:Value() and IsReady(_W) and nearby >= Menu.Clear.LaneClear.WCount:Value() then
		Control.CastSpell(HK_W)
		return
	end
	if Menu.Clear.LaneClear.Q:Value() and IsReady(_Q) and nearby >= Menu.Clear.LaneClear.QCount:Value() then
		Control.CastSpell(HK_Q)
	end
end

function ClassicSkarner:JungleClear()
	if not Menu.Clear.SpellFarm:Value() then return end
	local monsters = _G.SDK.ObjectManager:GetMonsters(self.ESpell.Range)
	table.sort(monsters, function(a, b) return a.maxHealth > b.maxHealth end)
	local monster = monsters[1]
	if not IsValid(monster) or not monster.pos2D.onScreen then return end

	if Menu.Clear.JungleClear.E:Value() and IsReady(_E) then
		Control.CastSpell(HK_E, monster)
		return
	end
	if Menu.Clear.JungleClear.W:Value() and IsReady(_W) and myHero.pos:DistanceTo(monster.pos) <= self.WSpell.Range then
		Control.CastSpell(HK_W)
		return
	end
	if Menu.Clear.JungleClear.Q:Value() and IsReady(_Q) and myHero.pos:DistanceTo(monster.pos) <= self.QSpell.Range then
		Control.CastSpell(HK_Q)
	end
end

function ClassicSkarner:SemiR()
	if not Menu.Misc.SemiR:Value() or not IsReady(_R) then return end
	local target = self:GetRTarget()
	if IsValid(target) and target.pos2D.onScreen then
		Control.CastSpell(HK_R, target)
	end
end

function ClassicSkarner:KillSteal()
	local enemies = _G.SDK.ObjectManager:GetEnemyHeroes(self.ESpell.Range)
	for _, target in ipairs(enemies) do
		if IsValid(target) and target.pos2D.onScreen then
			if Menu.KillSteal.E:Value() and IsReady(_E) then
				local magicHealth = target.health + target.hpRegen + target.shieldAP
				if self:GetEDmg(target) >= magicHealth then
					if self:CastE(target) then return end
				end
			end
			if Menu.KillSteal.Q:Value() and IsReady(_Q) and myHero.pos:DistanceTo(target.pos) <= self.QSpell.Range then
				local effectiveHealth = target.health + target.hpRegen + target.shieldAD + target.shieldAP
				if self:GetQDmg(target) >= effectiveHealth then
					V2:Cast(HK_Q, nil, {intentTarget=target})
					return
				end
			end
		end
	end
end

function ClassicSkarner:CastE(target)
	local prediction = GGPrediction:SpellPrediction(self.ESpell)
	prediction:GetPrediction(target, myHero)
	if prediction:CanHit(3) then
		return Control.CastSpell(HK_E, prediction.CastPosition)
	end
	return false
end

function ClassicSkarner:GetQDmg(target)
	local level = myHero:GetSpellData(_Q).level
	if level == 0 then return 0 end
	local physical = ({25, 40, 55, 70, 85})[level] + myHero.bonusDamage * 0.80
	local damage = _G.SDK.Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_PHYSICAL, physical)
	if HaveBuff(myHero, "Jade_SkarnerQ_Energy1") then
		local magical = ({24, 36, 48, 60, 72})[level] + myHero.ap * 0.40
		damage = damage + _G.SDK.Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_MAGICAL, magical)
	end
	return damage
end

function ClassicSkarner:GetEDmg(target)
	local level = myHero:GetSpellData(_E).level
	if level == 0 then return 0 end
	local damage = ({80, 120, 160, 200, 240})[level] + myHero.ap * 0.70
	return _G.SDK.Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_MAGICAL, damage)
end

function ClassicSkarner:Draw()
	if myHero.dead then return end
	if Menu.Draw.DrawFarm:Value() then
		Draw.Text(Menu.Clear.SpellFarm:Value() and "Spell Farm: On" or "Spell Farm: Off", 16, myHero.pos2D.x-57, myHero.pos2D.y+58, Draw.Color(200, 242, 120, 34))
	end
	if Menu.Draw.DrawHarass:Value() then
		Draw.Text(Menu.Clear.SpellHarass:Value() and "Spell Harass: On" or "Spell Harass: Off", 16, myHero.pos2D.x-57, myHero.pos2D.y+78, Draw.Color(200, 242, 120, 34))
	end
	if Menu.Draw.Q:Value() and IsReady(_Q) then Draw.Circle(myHero.pos, self.QSpell.Range, 1, Draw.Color(255, 66, 244, 113)) end
	if Menu.Draw.E:Value() and IsReady(_E) then Draw.Circle(myHero.pos, self.ESpell.Range, 1, Draw.Color(255, 66, 229, 244)) end
	if Menu.Draw.R:Value() and IsReady(_R) then Draw.Circle(myHero.pos, self.RSpell.Range, 1, Draw.Color(255, 244, 66, 104)) end
end


-- Explicit request context. Nested helpers inherit their caller's context.
V2:RegisterPolicy({
    damageTypes={Q='mixed',E='magical'},
    methods={


        Combo=function()return V2:ModeContext("Combo")end,
        Harass=function()return V2:ModeContext("Harass")end,
        LaneClear=function()return V2:ModeContext("LaneClear",function()return Menu.Clear.SpellFarm:Value()end)end,
        JungleClear=function()return V2:ModeContext("LaneClear",function()return Menu.Clear.SpellFarm:Value()end)end,
        FarmHarass=function()return V2:ModeContext("LaneClear",function()return Menu.Clear.SpellHarass:Value() and not IsUnderTurret(myHero)end)end,
        SemiR=function()return V2:HeldContext(function()return Menu.Misc.SemiR:Value()end)end,
    },
    exceptions={non_interrupting_summoner=true},
    channel=function(self,q)return not (myHero.activeSpell and myHero.activeSpell.valid and myHero.activeSpell.isChanneling) end,
    validate=function(self,q,slot,resolved)
        if self:IsImpaling() and q.owner~='ImpaleActions'then return false end
        if q.owner=='ImpaleActions'then return self:IsImpaling() and (slot==_Q or slot==_W)end
        return true
    end,
})

ClassicSkarner()

end
if champion=="Teemo" then
local Version = 1.02


local ClassicTeemo=class("ClassicTeemo")

function ClassicTeemo:__init()

	self.QRange, self.RRange = 680, 230
	self.RSpell = { Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 0.25, Radius = 135, Range = 230, Speed = 1450, Collision = false }
	self.lastRPos = nil
	self.lastRTime = 0
	self:LoadMenu()
	Callback.Add("Tick", function() self:Tick() end)
	Callback.Add("Draw", function() self:Draw() end)
	_G.SDK.Orbwalker:OnPostAttack(function(...) self:OnPostAttack(...) end)
end

function ClassicTeemo:LoadMenu()
	local icon = "http://ddragon.leagueoflegends.com/cdn/16.15.1/img/champion/" .. myHero.charName .. ".png"
	Menu = MenuElement({ type = MENU, id = "Classic_AIO_" .. myHero.charName, name = "Classic AIO - " .. myHero.charName .. " V: " .. Version, leftIcon = icon })
	Menu:MenuElement({ type = MENU, id = "Combo", name = "Combo" })
	Menu.Combo:MenuElement({ id = "Q", name = "Use Q After Attack", value = true })
	Menu.Combo:MenuElement({ id = "W", name = "Use W Chase", value = true })
	Menu.Combo:MenuElement({ id = "R", name = "Use R In Melee Range", value = true })
	Menu:MenuElement({ type = MENU, id = "Harass", name = "Harass" })
	Menu.Harass:MenuElement({ id = "Q", name = "Use Q", value = true })
	Menu.Harass:MenuElement({ id = "Mana", name = "Mana Percent >=", value = 40, min = 0, max = 100, step = 5 })
	Menu:MenuElement({ type = MENU, id = "Clear", name = "Clear" })
	Menu.Clear:MenuElement({ id = "Enabled", name = "Use Spell Farm (Mouse Scroll)", toggle = true, value = false, key = 4, callback = function(v) CheckChatBlock(Menu.Clear.Enabled, v) end })
	Menu.Clear:MenuElement({ id = "Q", name = "Use Q Last Hit", value = true })
	Menu.Clear:MenuElement({ id = "R", name = "Use R In Jungle", value = false })
	Menu.Clear:MenuElement({ id = "Mana", name = "Mana Percent >=", value = 30, min = 0, max = 100, step = 5 })
	Menu:MenuElement({ type = MENU, id = "KillSteal", name = "KillSteal" })
	Menu.KillSteal:MenuElement({ id = "Q", name = "Auto Q", value = true })
	Menu:MenuElement({ type = MENU, id = "Flee", name = "Flee" })
	Menu.Flee:MenuElement({ id = "W", name = "Use W", value = true })
	Menu:MenuElement({ type = MENU, id = "Draw", name = "Draw" })
	Menu.Draw:MenuElement({ id = "Q", name = "Draw Q Range", value = false })
	Menu.Draw:MenuElement({ id = "R", name = "Draw R Range", value = false })
	Menu.Draw:MenuElement({ id = "Farm", name = "Draw Farm Status", value = true })
end

function ClassicTeemo:Tick()
	if ShouldWait() or IsCasting() then return end
	self:KillSteal()
	local mode = GetMode()
	if mode == "Combo" then
		self:Combo()
	elseif mode == "Harass" then
		self:Harass()
	elseif mode == "LaneClear" then
		self:Clear()
	elseif mode == "Flee" and Menu.Flee.W:Value() and IsReady(_W) then
		V2:Cast(HK_W,nil,{context=V2:ModeContext("Flee"),validate=function()return Menu.Flee.W:Value()end})
	end
end

function ClassicTeemo:Combo()
	local t = GetTarget(self.QRange)
	if not IsValid(t) or not t.pos2D.onScreen then return end
	if Menu.Combo.R:Value() and IsReady(_R) and t.distance <= self.RRange and self:CastR(t) then return end
	local aaRange = myHero.range + myHero.boundingRadius + (t.boundingRadius or 0)
	if Menu.Combo.Q:Value() and IsReady(_Q) and t.distance > aaRange then
		Control.CastSpell(HK_Q, t)
		return
	end
	if Menu.Combo.W:Value() and IsReady(_W) and t.distance > aaRange then Control.CastSpell(HK_W) end
end

function ClassicTeemo:OnPostAttack(args)
	if GetMode() ~= "Combo" or not Menu.Combo.Q:Value() or not IsReady(_Q) then return end
	local t = args and (args.Target or args.target) or nil
	if not IsValid(t) and _G.SDK.Orbwalker.GetTarget then t = _G.SDK.Orbwalker:GetTarget() end
	if IsValid(t) and t.type == Obj_AI_Hero and t.distance <= self.QRange then Control.CastSpell(HK_Q, t) end
end

function ClassicTeemo:Harass()
	if myHero.maxMana > 0 and myHero.mana / myHero.maxMana * 100 < Menu.Harass.Mana:Value() then return end
	local t = GetTarget(self.QRange)
	if IsValid(t) and t.pos2D.onScreen and Menu.Harass.Q:Value() and IsReady(_Q) then Control.CastSpell(HK_Q, t) end
end

function ClassicTeemo:CastR(t)
	local p = GGPrediction:SpellPrediction(self.RSpell)
	p:GetPrediction(t, myHero)
	if not p:CanHit(2) then return false end
	if self.lastRPos and GetTickCount() - self.lastRTime < 3000 and GetDistance(self.lastRPos, p.CastPosition) < 150 then return false end
	if not Control.CastSpell(HK_R, p.CastPosition) then return false end
	local placed=Vector(p.CastPosition)
    V2:AfterCast(HK_R, function() self.lastRPos=placed;self.lastRTime=GetTickCount() end)
	return true
end

function ClassicTeemo:Clear()
	if not Menu.Clear.Enabled:Value() or IsUnderTurret(myHero) then return end
	if myHero.maxMana > 0 and myHero.mana / myHero.maxMana * 100 < Menu.Clear.Mana:Value() then return end
	local minions = _G.SDK.ObjectManager:GetEnemyMinions(self.QRange)
	if Menu.Clear.Q:Value() and IsReady(_Q) then
		for _, m in ipairs(minions) do
			local hp = IsValid(m) and _G.SDK.HealthPrediction:GetPrediction(m, 0.25) or 0
			if hp > 0 and self:GetQDmg(m) >= hp then
				Control.CastSpell(HK_Q, m)
				return
			end
		end
	end
	local monsters = _G.SDK.ObjectManager:GetMonsters(self.QRange)
	local t = monsters[1]
	if IsValid(t) then
		if Menu.Clear.Q:Value() and IsReady(_Q) then
			Control.CastSpell(HK_Q, t)
			return
		end
		if Menu.Clear.R:Value() and IsReady(_R) and t.distance <= self.RRange then Control.CastSpell(HK_R, t.pos) end
	end
end

function ClassicTeemo:KillSteal()
	if not Menu.KillSteal.Q:Value() or not IsReady(_Q) then return end
	for _, t in ipairs(_G.SDK.ObjectManager:GetEnemyHeroes(self.QRange)) do
		if IsValid(t) and t.pos2D.onScreen and self:GetQDmg(t) >= t.health + (t.hpRegen or 0) + (t.shieldAP or 0) then
			Control.CastSpell(HK_Q, t)
			return
		end
	end
end
function ClassicTeemo:GetQDmg(t)
	local l = myHero:GetSpellData(_Q).level
	if l == 0 then return 0 end
	return _G.SDK.Damage:CalculateDamage(myHero, t, _G.SDK.DAMAGE_TYPE_MAGICAL, ({ 80, 125, 170, 215, 260 })[l] + myHero.ap * 0.70)
end
function ClassicTeemo:Draw()
	if myHero.dead then return end
	if Menu.Draw.Farm:Value() then Draw.Text(Menu.Clear.Enabled:Value() and "Spell Farm: On" or "Spell Farm: Off", 16, myHero.pos2D.x - 55, myHero.pos2D.y + 60, Draw.Color(200, 242, 120, 34)) end
	if Menu.Draw.Q:Value() and IsReady(_Q) then Draw.Circle(myHero.pos, self.QRange, 1, Draw.Color(255, 66, 244, 113)) end
	if Menu.Draw.R:Value() and IsReady(_R) then Draw.Circle(myHero.pos, self.RRange, 1, Draw.Color(255, 244, 66, 96)) end
end


-- Explicit request context. Nested helpers inherit their caller's context.
V2:RegisterPolicy({
    damageTypes={Q='magical'},
    methods={

        OnPostAttack=function()local mode=GetMode();return mode and V2:ModeContext(mode) or nil end,

        Combo=function()return V2:ModeContext("Combo")end,
        Harass=function()return V2:ModeContext("Harass")end,
        Clear=function()return V2:ModeContext("LaneClear")end,
    },
    exceptions={non_interrupting_summoner=true},
    channel=function(self,q)return not (myHero.activeSpell and myHero.activeSpell.valid and myHero.activeSpell.isChanneling) end,
    validate=function(self,q,slot,resolved)
        if slot==_R and q.kind=='world'then
            local p=Vector((resolved and resolved.position)or q.target)
            if self.lastRPos and GetTickCount()<self.lastRTime+1500 and GetDistance(p,self.lastRPos)<150 then return false end
        end
        return true
    end,
})

ClassicTeemo()

end
if champion=="Tristana" then
local Version = 1.04


local ClassicTristana=class("ClassicTristana")

function ClassicTristana:__init()

	self:LoadMenu()
	Callback.Add("Draw", function() self:Draw() end)
	Callback.Add("Tick", function() self:Tick() end)
	self.ERange =  550
	self.RRange =  600
end

function ClassicTristana:LoadMenu()
	local championIcon = "http://ddragon.leagueoflegends.com/cdn/16.15.1/img/champion/"..myHero.charName..".png"
	Menu = MenuElement({type = MENU, id = "Classic_AIO_"..myHero.charName, name = "Classic AIO - "..myHero.charName.." V: "..Version, leftIcon = championIcon})

	Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
	Menu.Combo:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "E", name = "Use E", toggle = true, value = true})

	Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
	Menu.Harass:MenuElement({id = "E", name = "Use E", toggle = true, value = true})
	-- Menu.Harass:MenuElement({id = "Mana", name = "When ManaPercent >= x%", value = 60, min = 0, max = 100, step = 5})

	Menu:MenuElement({type = MENU, id = "Clear", name = "Clear"})
	Menu.Clear:MenuElement({id = "SpellFarm", name = "Use Spell Farm(Mouse Scroll)", toggle = true, value = false, key = 4, callback = function(newValue)
		if CheckChatBlock(Menu.Clear.SpellFarm, newValue) then return end
	end})
	Menu.Clear:MenuElement({id = "SpellHarass", name = "Use Spell Harass(In LaneClear Mode)", toggle = true, value = false, key = string.byte("H"), callback = function(newValue)
		if CheckChatBlock(Menu.Clear.SpellHarass, newValue) then return end
	end})
	Menu.Clear:MenuElement({type = MENU, id = "LaneClear", name = "LaneClear"})
	Menu.Clear.LaneClear:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	Menu.Clear.LaneClear:MenuElement({id = "QCount", name = "Use Q| Near Minion Counts >= ", value = 3, min = 1, max = 6, step = 1})
	-- Menu.Clear.LaneClear:MenuElement({id = "Mana", name = "When ManaPercent >= x%", value = 30, min = 0, max = 100, step = 5})
	Menu.Clear:MenuElement({type = MENU, id = "JungleClear", name = "JungleClear"})
	Menu.Clear.JungleClear:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	Menu.Clear.JungleClear:MenuElement({id = "E", name = "Use E", toggle = true, value = true})
	-- Menu.Clear.JungleClear:MenuElement({id = "Mana", name = "When ManaPercent >= x%", value = 30, min = 0, max = 100, step = 5})
	
	Menu:MenuElement({type = MENU, id = "KillSteal", name = "KillSteal"})
	Menu.KillSteal:MenuElement({id = "R", name = "Auto R KillSteal", toggle = true, value = true})

	Menu:MenuElement({type = MENU, id = "Misc", name = "Misc"})
	Menu.Misc:MenuElement({id = "Rgap", name = "Auto R Anti Gapcloser", toggle = true, value = true})
	Menu.Misc:MenuElement({id = "RgapRange", name = "AntiGap R Range(dash endPos form self < X)", value = 300, min = 0, max = 600, step = 50})
	Menu.Misc:MenuElement({id = "SemiR", name = "Semi-manual R Key", key = string.byte("T")})

	Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
	Menu.Draw:MenuElement({id = "DrawFarm", name = "Draw Spell Farm Status", toggle = true, value = true})
	Menu.Draw:MenuElement({id = "DrawHarass", name = "Draw Spell Harass Status", toggle = true, value = true})
	Menu.Draw:MenuElement({id = "R", name = "Draw R Range", toggle = true, value = false})
end

function ClassicTristana:Tick()
	self.ERange = myHero.range + myHero.boundingRadius * 2

	if ShouldWait() then
		return
	end
	if IsCasting() then return end
	self:AntiGapcloser()
	self:SemiR()
	self:KillSteal()
	local mode = GetMode()
	if mode == "Combo" then
		self:Combo()
	elseif mode == "Harass" then
		self:Harass()
	elseif mode == "LaneClear" then
		self:LaneClear()
		self:JungleClear()
	end
end

function ClassicTristana:Combo()
	local target = _G.SDK.Orbwalker:GetTarget() or GetTarget(self.ERange)
	if not target then return end
	if Menu.Combo.E:Value() and IsReady(_E) then
		Control.CastSpell(HK_E, target)
	end
	if Menu.Combo.Q:Value() and IsReady(_Q) then
		Control.CastSpell(HK_Q)
	end
end

function ClassicTristana:Harass()
	local target = _G.SDK.Orbwalker:GetTarget() or GetTarget(self.ERange)
	if not target or target.type ~= "AIHeroClient" then return end
	if Menu.Harass.E:Value() and IsReady(_E) then
		Control.CastSpell(HK_E, target)
	end
end

function ClassicTristana:LaneClear()
	if --[[myHero.mana/myHero.maxMana >= Menu.Clear.LaneClear.Mana:Value()/100 and ]]Menu.Clear.SpellFarm:Value() then
		local minions = _G.SDK.ObjectManager:GetEnemyMinions(self.ERange)
		for i, minion in ipairs(minions) do
			if IsValid(minion) and minion.team ~= 300 and minion.pos2D.onScreen then
				if Menu.Clear.LaneClear.Q:Value() and IsReady(_Q) then
					if GetMinionCount(self.ERange, myHero.pos) >= Menu.Clear.LaneClear.QCount:Value() then
						Control.CastSpell(HK_Q)
					end
				end
			end
		end
	end
end

function ClassicTristana:JungleClear()
	if --[[myHero.mana/myHero.maxMana >= Menu.Clear.JungleClear.Mana:Value()/100 and ]]Menu.Clear.SpellFarm:Value() then
		local minions = _G.SDK.ObjectManager:GetEnemyMinions(self.ERange)
		table.sort(minions, function(a, b) return a.maxHealth > b.maxHealth end)
		for i, minion in ipairs(minions) do
			if IsValid(minion) and minion.team == 300 and minion.pos2D.onScreen then
				if Menu.Clear.JungleClear.E:Value() and IsReady(_E) then
					Control.CastSpell(HK_E, minion)
				end
				if Menu.Clear.JungleClear.Q:Value() and IsReady(_Q) then
					Control.CastSpell(HK_Q)
				end
			end
		end
	end
end

function ClassicTristana:AntiGapcloser()
	if Menu.Misc.Rgap:Value() and IsReady(_R) then
		local enemies = _G.SDK.ObjectManager:GetEnemyHeroes(1000)
		for i, target in ipairs(enemies) do
			if IsValid(target) and target.pathing.isDashing and not HasInvalidDashBuff(target) then
				if myHero.pos:DistanceTo(target.pathing.endPos) < Menu.Misc.RgapRange:Value() and IsFacingMe(target) then
					if Control.CastSpell(HK_R, target) then return end
				end
			end	
		end
	end
end

function ClassicTristana:SemiR()
	if Menu.Misc.SemiR:Value() and IsReady(_R) then
		local target = _G.SDK.TargetSelector.Selected
		if IsValid(target) and target.pos2D.onScreen and target.distance <= self.RRange then
			if Control.CastSpell(HK_R, target) then return end
		end
		local enemies = _G.SDK.ObjectManager:GetEnemyHeroes(self.RRange)
		table.sort(enemies, function(a, b) return myHero.pos:DistanceTo(a.pos) < myHero.pos:DistanceTo(b.pos) end)
		for i, enemy in ipairs(enemies) do
			if IsValid(enemy) and enemy.pos2D.onScreen then
				if Control.CastSpell(HK_R, enemy) then return end
			end
		end
	end
end

function ClassicTristana:KillSteal()
	if Menu.KillSteal.R:Value() and IsReady(_R) then
		local enemies = _G.SDK.ObjectManager:GetEnemyHeroes(self.RRange)
		for i, enemy in ipairs(enemies) do
			if IsValid(enemy) and enemy.pos2D.onScreen then
				local Rdmg = self:GetRDmg(enemy) - (enemy.shieldAP or 0) - (enemy.shieldAD or 0)
				if Rdmg >= (enemy.health + (enemy.hpRegen or 0)) then
					if Control.CastSpell(HK_R, enemy) then return end
				end
			end
		end
	end
end

function ClassicTristana:GetRDmg(unit)
	local baseDmg = ({300, 400, 500})[myHero:GetSpellData(_R).level]
	local bonusDmg = myHero.ap * 1.5
	local Rvalue = baseDmg + bonusDmg
	local Rdmg = _G.SDK.Damage:CalculateDamage(myHero, unit, _G.SDK.DAMAGE_TYPE_MAGICAL, Rvalue)
	return Rdmg
end

function ClassicTristana:Draw()
	if myHero.dead then return end

	if Menu.Draw.DrawFarm:Value() then
		if Menu.Clear.SpellFarm:Value() then
			Draw.Text("Spell Farm: On", 16, myHero.pos2D.x-57, myHero.pos2D.y+58, Draw.Color(200, 242, 120, 34))
		else
			Draw.Text("Spell Farm: Off", 16, myHero.pos2D.x-57, myHero.pos2D.y+58, Draw.Color(200, 242, 120, 34))
		end
	end

	if Menu.Draw.DrawHarass:Value() then
		if Menu.Clear.SpellHarass:Value() then
			Draw.Text("Spell Harass: On", 16, myHero.pos2D.x-57, myHero.pos2D.y+78, Draw.Color(200, 242, 120, 34))
		else
			Draw.Text("Spell Harass: Off", 16, myHero.pos2D.x-57, myHero.pos2D.y+78, Draw.Color(200, 242, 120, 34))
		end
	end

	if Menu.Draw.R:Value() then
		Draw.Circle(myHero.pos, self.RRange, 1, Draw.Color(255, 66, 229, 244))
	end
end


-- Explicit request context. Nested helpers inherit their caller's context.
V2:RegisterPolicy({
    damageTypes={R='magical'},
    methods={
        AntiGapcloser=function()return {priority='interactive'}end,

        Combo=function()return V2:ModeContext("Combo")end,
        Harass=function()return V2:ModeContext("Harass")end,
        LaneClear=function()return V2:ModeContext("LaneClear",function()return Menu.Clear.SpellFarm:Value()end)end,
        JungleClear=function()return V2:ModeContext("LaneClear",function()return Menu.Clear.SpellFarm:Value()end)end,
        SemiR=function()return V2:HeldContext(function()return Menu.Misc.SemiR:Value()end)end,
    },
    exceptions={non_interrupting_summoner=true},
    channel=function(self,q)return not (myHero.activeSpell and myHero.activeSpell.valid and myHero.activeSpell.isChanneling) end,
    validate=function(self,q,slot,resolved)
        if q.owner=='AntiGapcloser' and q.object then return q.object.pathing and q.object.pathing.isDashing end
        return true
    end,
})

ClassicTristana()

end
if champion=="Twitch" then
local Version = 1.01


local ClassicTwitch=class("ClassicTwitch")

function ClassicTwitch:__init()

	self:LoadMenu()
	Callback.Add("Draw", function() self:Draw() end)
	Callback.Add("Tick", function() self:OnTick() end)
	self.WSpell = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 0.25, Radius = 275, Range = 950, Speed = 1750, Collision = true, CollisionTypes = {GGPrediction.COLLISION_YASUOWALL}}
	-- self.EBuffs = {}
end

function ClassicTwitch:LoadMenu()
	local championIcon = "http://ddragon.leagueoflegends.com/cdn/16.15.1/img/champion/"..myHero.charName..".png"
	Menu = MenuElement({type = MENU, id = "Classic_AIO_"..myHero.charName, name = "Classic AIO - "..myHero.charName.." V: "..Version, leftIcon = championIcon})
	Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
	Menu.Combo:MenuElement({id = "Q", name = "Use Q", toggle = true, value = false})
	Menu.Combo:MenuElement({id = "W", name = "Use W", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "E", name = "Use E", toggle = true, value = true})
	Menu.Combo:MenuElement({id = 'Estacks', name = 'Use E|X Stacks', value = 6, min = 1, max = 6, step = 1})
	Menu.Combo:MenuElement({id = 'Eenemies', name = 'Use E|X Enemies', value = 1, min = 1, max = 5, step = 1})
	Menu.Combo:MenuElement({id = "R", name = "Use R", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "Rrange", name = 'Use R|X Distance', value = 750, min = 300, max = 1500, step = 50})
	Menu.Combo:MenuElement({id = "Renemies", name = 'Use R|X Enemies', value = 3, min = 1, max = 5, step = 1})

	Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
	Menu.Harass:MenuElement({id = "SpellHarass", name = "Use Spell Harass(In LaneClear Mode)", toggle = true, value = false, key = string.byte("H"), callback = function(newValue)
		if CheckChatBlock(Menu.Harass.SpellHarass, newValue) then return end
	end})
	Menu.Harass:MenuElement({id = "Q", name = "Use Q", toggle = true, value = false})
	Menu.Harass:MenuElement({id = "W", name = "Use W", toggle = true, value = true})
	Menu.Harass:MenuElement({id = "E", name = "Use E", toggle = true, value = true})
	Menu.Harass:MenuElement({id = 'Estacks', name = 'Use E|X Stacks', value = 6, min = 1, max = 6, step = 1})
	Menu.Harass:MenuElement({id = 'Eenemies', name = 'Use E|X Enemies', value = 1, min = 1, max = 5, step = 1})
	
	Menu:MenuElement({type = MENU, id = "Misc", name = "Misc"})
	Menu.Misc:MenuElement({id = 'qrecall', name = 'Invisible Recall Key', key = string.byte('M')})
	Menu.Misc:MenuElement({id = 'stopq', name = 'Stop using W when has Q', value = true})
	Menu.Misc:MenuElement({id = 'stopr', name = 'Stop using W when has R', value = false})
	Menu.Misc:MenuElement({id = "EKill", name = "Auto E KillSteal", toggle = true, value = true})

	Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
	Menu.Draw:MenuElement({id = "DrawHarass", name = "Draw Spell Harass Status", value = true})
	Menu.Draw:MenuElement({id = 'qtimer', name = 'Q Timer', value = true})
	Menu.Draw:MenuElement({id = 'qinvisible', name = 'Q Invisible Range', value = true})
	Menu.Draw:MenuElement({id = 'qnotification', name = 'Q Notification Range', value = true})
end

--[[ function ClassicTwitch:EBuffManager()
	local enemies = _G.SDK.ObjectManager:GetEnemyHeroes(2000)
	for _, hero in ipairs(enemies) do
		local id = hero.networkID
		if self.EBuffs[id] == nil then
			self.EBuffs[id] = { count = 0, duration = 0 }
		end
		local ebuff, ebuffData = GetBuffData(hero, "twitchdeadlyvenom")
		if ebuff and ebuffData.count > 0 and ebuffData.duration > 0 then
			if self.EBuffs[id].count < 6 and ebuffData.duration > self.EBuffs[id].duration then
				self.EBuffs[id].count = self.EBuffs[id].count + 1
			end
			self.EBuffs[id].duration = ebuffData.duration
		else
			self.EBuffs[id].count = 0
			self.EBuffs[id].duration = 0
		end
	end
end ]]

function ClassicTwitch:OnTick()
	if ShouldWait() then
		return
	end

	-- self:EBuffManager()
	self:QRecall()

	if IsCasting() then return end

	self:EKS()
	local Mode = GetMode()
	if Mode == "Combo" then
		self:Combo()
	elseif Mode == "Harass" then
		self:Harass()
	elseif Mode == "LaneClear" then
		self:FarmHarass()
	end
end

function ClassicTwitch:QRecall()
	if Menu.Misc.qrecall:Value() and IsReady(_Q) then
		if Control.CastSpell(HK_Q) then
            V2:AfterCast(HK_Q, function()
                if Menu.Misc and Menu.Misc.qrecall and Menu.Misc.qrecall:Value() then V2:Cast(string.byte("B"),nil,{owner="recall",independent=false,observe=function()return Recalling(myHero)end}) end
            end)
        end
	end
end

function ClassicTwitch:Combo()
	if Menu.Combo.E:Value() and IsReady(_E) then
		local xenemies = 0
		for _, hero in ipairs(_G.SDK.ObjectManager:GetEnemyHeroes(1200)) do
			if IsValid(hero) then -- and self.EBuffs[hero.networkID]
				-- local ecount = self.EBuffs[hero.networkID].count
				local buff, buffData = GetBuffData(hero, "Jade_TwitchPassive_Internal")
				if buff and buffData.stacks > 0 and buffData.stacks >= Menu.Combo.Estacks:Value() then
					xenemies = xenemies + 1
				end
			end
		end
		if xenemies >= Menu.Combo.Eenemies:Value() then
			Control.CastSpell(HK_E)
		end
	end
	if Menu.Combo.R:Value() and IsReady(_R) then
		local enemies = _G.SDK.ObjectManager:GetEnemyHeroes(Menu.Combo.Rrange:Value())
		if #enemies >= Menu.Combo.Renemies:Value() then
			Control.CastSpell(HK_R)
		end
	end
	if Menu.Combo.Q:Value() and IsReady(_Q) then
		local target = _G.SDK.Orbwalker:GetTarget()
		if target ~= nil then
			Control.CastSpell(HK_Q)
		end
	end
	if Menu.Combo.W:Value() and IsReady(_W) then
		if Menu.Misc.stopq:Value() and HaveBuff(myHero, "TwitchHideInShadows") then
			return
		end
		if Menu.Misc.stopr:Value() and Game.Timer() < (V2.observedSpells[_R] or -math.huge) + 5.45 then
			return
		end
		local target = _G.SDK.Orbwalker:GetTarget() or GetTarget(950)
		if IsValid(target) and target.pos:ToScreen().onScreen then 
			self:CastW(target)
		end
	end
end

function ClassicTwitch:Harass()
	if Menu.Harass.E:Value() and IsReady(_E) then
		local xenemies = 0
		for _, hero in ipairs(_G.SDK.ObjectManager:GetEnemyHeroes(1200)) do
			if IsValid(hero) then -- and self.EBuffs[hero.networkID] then
				-- local ecount = self.EBuffs[hero.networkID].count
				-- if ecount > 0 and ecount >= Menu.Harass.Estacks:Value() then
				local buff, buffData = GetBuffData(hero, "Jade_TwitchPassive_Internal")
				if buff and buffData.stacks > 0 and buffData.stacks >= Menu.Harass.Estacks:Value() then
					xenemies = xenemies + 1
				end
			end
		end
		if xenemies >= Menu.Harass.Eenemies:Value() then
			Control.CastSpell(HK_E)
		end
	end
	if Menu.Harass.Q:Value() and IsReady(_Q) then
		local target = _G.SDK.Orbwalker:GetTarget()
		if target ~= nil and target.type == Obj_AI_Hero then
			Control.CastSpell(HK_Q)
		end
	end
	if Menu.Harass.W:Value() and IsReady(_W) then
		if Menu.Misc.stopq:Value() and HaveBuff(myHero, "TwitchHideInShadows") then
			return
		end
		if Menu.Misc.stopr:Value() and Game.Timer() < (V2.observedSpells[_R] or -math.huge) + 5.45 then
			return
		end
		local target = _G.SDK.Orbwalker:GetTarget() or GetTarget(950)
		if IsValid(target) and target.type == Obj_AI_Hero and target.pos:ToScreen().onScreen then 
			self:CastW(target)
		end
	end
end

function ClassicTwitch:FarmHarass()
	if IsUnderTurret(myHero) then return end
	if Menu.Harass.SpellHarass:Value() then
		self:Harass()
	end
end

function ClassicTwitch:EKS()
	if not (Menu.Misc.EKill:Value() and IsReady(_E)) then
		return
	end
	for _, hero in ipairs(_G.SDK.ObjectManager:GetEnemyHeroes(1200)) do
		if IsValid(hero) then -- and self.EBuffs[hero.networkID] then
			-- local ecount = self.EBuffs[hero.networkID].count
			-- if ecount > 0 then
			local buff, buffData = GetBuffData(hero, "Jade_TwitchPassive_Internal")
			if buff and buffData.stacks > 0 then
				local elvl = myHero:GetSpellData(_E).level
				local basedmg = 5 + (elvl * 15)
				local perstack = (10 + (5 * elvl)) * buffData.stacks
				local bonusAD = (myHero.bonusDamage * 0.25 + myHero.ap * 0.2) * buffData.stacks
				local totalDamage = _G.SDK.Damage:CalculateDamage(myHero, hero, _G.SDK.DAMAGE_TYPE_PHYSICAL, (basedmg + perstack + bonusAD))
				if totalDamage >= hero.health + (1.5 * hero.hpRegen) then
					Control.CastSpell(HK_E)
					break
				end
			end
		end
	end
end

function ClassicTwitch:CastW(unit)
	local WPrediction = GGPrediction:SpellPrediction(self.WSpell)
	WPrediction:GetPrediction(unit, myHero)
	if WPrediction:CanHit(3) then
		Control.CastSpell(HK_W, WPrediction.CastPosition)
	end
end

function ClassicTwitch:DrawTextOnHero(hero, text, color)
	local pos2D = hero.pos:To2D()
	local posX = pos2D.x - 50
	local posY = pos2D.y
	Draw.Text(text, 50, posX + 50, posY - 15, color)
end

function ClassicTwitch:Draw()
	if myHero.dead then return end
	if Menu.Draw.DrawHarass:Value() then
		if Menu.Harass.SpellHarass:Value() then
			Draw.Text("Spell Harass: On", 16, myHero.pos2D.x-57, myHero.pos2D.y+78, Draw.Color(200, 242, 120, 34))
		else
			Draw.Text("Spell Harass: Off", 16, myHero.pos2D.x-57, myHero.pos2D.y+78, Draw.Color(200, 242, 120, 34))
		end
	end
	if Menu.Draw.qtimer:Value() then
		local preInvisibleDuration = 1.25 - (Game.Timer() - (V2.observedSpells[_Q] or -math.huge))
		if preInvisibleDuration > 0 then
			self:DrawTextOnHero(myHero, tostring(math.floor(preInvisibleDuration * 1000)), Draw.Color(200, 65, 255, 100))
			return
		end
		local buff, buffData = GetBuffData(myHero, "Jade_TwitchQ")
		if buff then
			self:DrawTextOnHero(myHero, tostring(math.floor(buffData.duration * 1000)), Draw.Color(200, 65, 255, 100))
		end
	end

	if HaveBuff(myHero, "Jade_TwitchQ") then
		if Menu.Draw.qinvisible:Value() then
			Draw.Circle(myHero.pos, 500, 1, Draw.Color(200, 255, 0, 0))
		end
		if Menu.Draw.qnotification:Value() then
			Draw.Circle(myHero.pos, 800, 1, Draw.Color(200, 188, 77, 26))
		end
	end
end


-- Explicit request context. Nested helpers inherit their caller's context.
V2:RegisterPolicy({
    methods={


        Combo=function()return V2:ModeContext("Combo")end,
        Harass=function()return V2:ModeContext("Harass")end,
        FarmHarass=function()return V2:ModeContext("LaneClear",function()return Menu.Harass.SpellHarass:Value() and not IsUnderTurret(myHero)end)end,
        QRecall=function()return V2:HeldContext(function()return Menu.Misc.qrecall:Value()end)end,
    },
    exceptions={non_interrupting_summoner=true},
    channel=function(self,q)return not (myHero.activeSpell and myHero.activeSpell.valid and myHero.activeSpell.isChanneling) end,
    validate=function(self,q,slot,resolved)
        if slot==_W then
            if Menu.Misc.stopq:Value() and HaveBuff(myHero,'TwitchHideInShadows')then return false end
            if Menu.Misc.stopr:Value() and Game.Timer()<(V2.observedSpells[_R]or -math.huge)+5.45 then return false end
        end
        if slot==_E and (q.owner=='Combo' or q.owner=='Harass' or q.owner=='FarmHarass' or q.owner=='EKS')then
            local menu=q.owner=='Combo' and Menu.Combo or Menu.Harass;local count=0
            for _,hero in ipairs(SDK.ObjectManager:GetEnemyHeroes(1200))do if IsValid(hero)then
                local exists,b=GetBuffData(hero,'Jade_TwitchPassive_Internal')
                if exists and b.stacks>0 then
                    if q.owner=='EKS' then
                        local level=myHero:GetSpellData(_E).level
                        local dmg=5+level*15+((10+5*level)+myHero.bonusDamage*.25+myHero.ap*.2)*b.stacks
                        if SDK.Damage:CalculateDamage(myHero,hero,SDK.DAMAGE_TYPE_PHYSICAL,dmg)>=hero.health+1.5*hero.hpRegen then return true end
                    elseif b.stacks>=menu.Estacks:Value()then count=count+1 end
                end
            end end
            return q.owner~='EKS' and count>=menu.Eenemies:Value()
        end
        if slot==_R and q.owner=='Combo'then return GetEnemyCount(Menu.Combo.Rrange:Value(),myHero.pos)>=Menu.Combo.Renemies:Value()end
        return true
    end,
})

ClassicTwitch()

end
if champion=="Vayne" then
local Version = 1.02

-- require("MapPositionGOS")

local ClassicVayne=class("ClassicVayne")

function ClassicVayne:__init()		 

	self:LoadMenu()
	Callback.Add("Draw", function() self:Draw() end)
	Callback.Add("Tick", function() self:OnTick() end)
	self.ESpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 0, Range = 680, Speed = 2200, Collision = true, CollisionTypes = {GGPrediction.COLLISION_YASUOWALL}}
	self.EPrediction=GGPrediction:SpellPrediction(self.ESpell)
end

function ClassicVayne:LoadMenu()
	local championIcon = "https://ddragon.leagueoflegends.com/cdn/16.15.1/img/champion/Vayne.png"
	Menu = MenuElement({type = MENU, id = "Classic_AIO_"..myHero.charName, name = "Classic AIO - "..myHero.charName.." V: "..Version, leftIcon = championIcon})
	Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
	Menu.Combo:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	Menu.Combo:MenuElement({id="AllowDangerousQ",name="Allow Q into additional danger",value=false})
	Menu.Combo:MenuElement({id = "Qmode", name = "Use Q| Cast Mode", value = 1, drop = {"To Side", "To Mouse"}})
	Menu.Combo:MenuElement({id = "Qdistance", name = "To Side - hold distance", value = 500, min = 200, max = 700, step = 50})
	Menu.Combo:MenuElement({id = "E", name = "Use E", toggle = true, value = true})
	Menu.Combo:MenuElement({id="EMargin",name="E wall safety margin",value=20,min=0,max=60,step=5})
	Menu.Combo:MenuElement({id = "R", name = "Use R", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "Renemies", name = "R|minimum number of enemies near vayne", value = 3, min = 1, max = 5, step = 1})
	Menu.Combo:MenuElement({id = "Rdistance", name = "R|enemy distance from vayne", value = 500, min = 250, max = 750, step = 50})

	Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
	Menu.Harass:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	Menu.Harass:MenuElement({id = "E", name = "Use E|only 2 passive", toggle = true, value = false})
	
	Menu:MenuElement({type = MENU, id = "Misc", name = "Misc"})
	Menu.Misc:MenuElement({id = "Eantimelee", name = "Auto E AntiMelee", value = true})
	Menu.Misc:MenuElement({id = "antimeleedis", name = "AntiMelee|enemy distance from vayne", value = 250, min = 200, max = 600, step = 50})
	Menu.Misc:MenuElement({id = "Eantidash", name = "Auto E AntiDash", value = true})

	Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
	Menu.Draw:MenuElement({id = "E", name = "[E] Range", toggle = true, value = false})

end

function ClassicVayne:OnTick()
	if ShouldWait() then
		return
	end
	self:EAntiDash()
	self:EAntiMelee()
	if IsCasting() then return end
	local Mode = GetMode()
	if Mode == "Combo" then
		self:Combo()
	elseif Mode == "Harass" then
		self:Harass()
	end
end

function ClassicVayne:CastSafeQ(point)
    if not point or GetDistance(point,myHero.pos)<1 then return false end
    local endpoint=myHero.pos:Extended(Vector(point),math.min(300,GetDistance(point,myHero.pos)))
    for distance=50,300,50 do
        local sample=myHero.pos:Extended(endpoint,math.min(distance,GetDistance(endpoint,myHero.pos)))
        if Game.isWall(sample) then return false end
    end
    if not Menu.Combo.AllowDangerousQ:Value() then
        if IsUnderTurret2(endpoint) and not IsUnderTurret(myHero) then return false end
        if GetEnemyCount(350,endpoint)>GetEnemyCount(350,myHero.pos) then return false end
    end
    return Control.CastSpell(HK_Q,endpoint)
end

function ClassicVayne:CheckWall(from, to, distance)
    if not from or not to or GetDistanceSqr(from,to)<1 then return false end
    local direction=(to-from):Normalized()
    local side=Vector(-direction.z,0,direction.x)
    local margin=Menu.Combo.EMargin:Value()
    -- A center ray grazing a corner is insufficient evidence for a reliable
    -- stun. All sampled parallel rays must enter terrain within knockback range.
    local center,left,right=false,margin==0,margin==0
    for d=0,distance,20 do
        local p=to+direction*d
        if not center then center=Game.isWall(p) end
        if not left then left=Game.isWall(p+side*margin) end
        if not right then right=Game.isWall(p-side*margin) end
        if center and left and right then return true end
    end
    local p=to+direction*distance
    return (center or Game.isWall(p)) and (left or Game.isWall(p+side*margin)) and (right or Game.isWall(p-side*margin))
end

function ClassicVayne:SilverBolts(target,delay)
    local _,buff=GetBuffData(target,VayneProfile.buff)
    return VayneProfile.Stacks(buff,Game.Timer()+(delay or 0),myHero),VayneProfile.Damage(myHero,target)
end

function ClassicVayne:CanCondemn(target)
    if not IsReady(_E) or not IsValid(target) or target.type~=Obj_AI_Hero then return false end
    local spell=myHero:GetSpellData(_E)
    local range=self.ESpell.Range
    -- Prefer the host's actual cast range if exposed; retain the Classic
    -- reference envelope when absent rather than substituting modern data.
    if spell.range and spell.range>0 then range=math.min(range,spell.range+(target.boundingRadius or 0)+(myHero.boundingRadius or 0)) end
    if GetDistance(target.pos,myHero.pos)>range then return false end
    return not _G.SDK.ObjectManager:IsHeroImmortal(target)
end

function ClassicVayne:CondemnPrediction(target)
    if not self:CanCondemn(target) then return nil end
    local p=self.EPrediction;p:GetPrediction(target,myHero)
    if not p.UnitPosition then return nil end
    -- E is targeted: a moving target's skillshot hit-chance is not a reason to
    -- refuse it. The predicted impact position still determines the wall ray.
    local wall=GGPrediction:GetCollision(myHero.pos,p.UnitPosition,self.ESpell.Speed,
        self.ESpell.Delay,0,self.ESpell.CollisionTypes,target.networkID)
    if wall then return nil end
    return Vector(p.UnitPosition)
end

function ClassicVayne:CanStun(target)
    local impact=self:CondemnPrediction(target)
    local stun=impact and self:CheckWall(myHero.pos,impact,475) or false
    if V2.logger then V2:Trace('condemn_evaluation',{target=target.networkID,stun=stun,reason=not impact and 'invalid_or_prediction_or_projectile_wall' or not stun and 'no_safe_wall' or 'wall',impact=impact and {x=impact.x,z=impact.z},source={x=myHero.pos.x,z=myHero.pos.z}},500)end
    return stun
end

function ClassicVayne:IsDashThreat(target)
    local path=target.pathing
    return path and path.isDashing and target.posTo
        and GetDistance(target.posTo,myHero.pos)<400
        and GetDistanceSqr(target.posTo,myHero.pos)<GetDistanceSqr(target.pos,myHero.pos)
end

function ClassicVayne:IsMeleeThreat(target)
    if target.range>=400 or GetDistance(target.pos,myHero.pos)>Menu.Misc.antimeleedis:Value() then return false end
    local cast=target.activeSpell
    if cast and cast.valid and cast.isAutoAttack and (cast.target==myHero.handle or cast.target==myHero.networkID) then return true end
    if target.pathing and target.pathing.hasMovePath and target.posTo then
        return GetDistanceSqr(target.posTo,myHero.pos)+25<GetDistanceSqr(target.pos,myHero.pos) and IsFacingMe(target)
    end
    return GetDistance(target.pos,myHero.pos)<=target.range+(target.boundingRadius or 0)+(myHero.boundingRadius or 0) and IsFacingMe(target)
end

function ClassicVayne:EAntiMelee()
	if Menu.Misc.Eantimelee:Value() and IsReady(_E) then
		local melees = {}
		local enemies = _G.SDK.ObjectManager:GetEnemyHeroes(Menu.Misc.antimeleedis:Value())
		for i = 1, #enemies do
			local enemy = enemies[i]
			if self:CanCondemn(enemy) and self:IsMeleeThreat(enemy) then
				table.insert(melees, enemy)
			end
		end
		if #melees > 0 then
			table.sort(melees, function(a, b)
				return a.health + (a.totalDamage * 2) + (a.attackSpeed * 100)
					> b.health + (b.totalDamage * 2) + (b.attackSpeed * 100)
			end)
			for i = 1, #melees do
				local target = melees[i]
				if self:CondemnPrediction(target) then
					if V2:Cast(HK_E,target,{ttl=100,independent=false}) then break end
				end
			end
		end
	end
end

function ClassicVayne:EAntiDash()
	if Menu.Misc.Eantidash:Value() and IsReady(_E) then
		local enemies = _G.SDK.ObjectManager:GetEnemyHeroes(self.ESpell.Range)
		for i = 1, #enemies do
			local enemy = enemies[i]
			if self:IsDashThreat(enemy) and self:CondemnPrediction(enemy) then
				if V2:Cast(HK_E,enemy,{priority="interactive",ttl=100,independent=false}) then break end
			end
		end
	end
end

function ClassicVayne:Combo()
	if Menu.Combo.R:Value() and IsReady(_R) then
		local enemies = _G.SDK.ObjectManager:GetEnemyHeroes(Menu.Combo.Rdistance:Value())
		if #enemies >= Menu.Combo.Renemies:Value() then
			Control.CastSpell(HK_R)
		end
	end
	if Menu.Combo.E:Value() and IsReady(_E) then
		for _, enemy in ipairs(_G.SDK.TargetSelector:GetTargets(self.ESpell.Range)) do
			if self:CanStun(enemy) and V2:Cast(HK_E,enemy,{ttl=120,independent=false}) then break end
		end
	end
	if Menu.Combo.Q:Value() and IsReady(_Q) then
		local target = _G.SDK.Orbwalker:GetTarget()
		local aaRange = myHero.range + myHero.boundingRadius * 2
		if IsValid(target) then
			if Menu.Combo.Qmode:Value() == 1 then
				local holdDistance = Menu.Combo.Qdistance:Value()
				local intPos1, intPos2 = CircleCircleIntersection(myHero.pos, target.pos, 300, holdDistance)
				if intPos1 and intPos2 then
					local closest = GetDistance(intPos1, mousePos) < GetDistance(intPos2, mousePos) and intPos1 or intPos2
					self:CastSafeQ(closest)
				end
			else
				if _G.SDK.Cursor.Step == 0 then
					self:CastSafeQ(mousePos)
				end
			end
		end
		if target == nil then target = GetTarget(aaRange + 300) end
		if IsValid(target) and target.distance > aaRange then
			local extended = myHero.pos:Extended(target.pos, 300)
			self:CastSafeQ(extended)
		end
	end
end

function ClassicVayne:Harass()
	if Menu.Harass.Q:Value() and IsReady(_Q) then
		local target = _G.SDK.Orbwalker:GetTarget()
		local aaRange = myHero.range + myHero.boundingRadius * 2
		if IsValid(target) and target.type == Obj_AI_Hero then
			if Menu.Combo.Qmode:Value() == 1 then
				local holdDistance = Menu.Combo.Qdistance:Value()
				local intPos1, intPos2 = CircleCircleIntersection(myHero.pos, target.pos, 300, holdDistance)
				if intPos1 and intPos2 then
					local closest = GetDistance(intPos1, mousePos) < GetDistance(intPos2, mousePos) and intPos1 or intPos2
					self:CastSafeQ(closest)
				end
			else
				if _G.SDK.Cursor.Step == 0 then
					self:CastSafeQ(mousePos)
				end
			end
		end
		if target == nil then target = GetTarget(aaRange + 300) end
		if IsValid(target) and target.distance > aaRange then
			local extended = myHero.pos:Extended(target.pos, 300)
			self:CastSafeQ(extended)
		end
	end
	if Menu.Harass.E:Value() and IsReady(_E) then
		for _, target in ipairs(_G.SDK.ObjectManager:GetEnemyHeroes(self.ESpell.Range + myHero.boundingRadius * 2)) do
			if IsValid(target) and target.pos:ToScreen().onScreen then
				local delay=self.ESpell.Delay+GetDistance(target.pos,myHero.pos)/self.ESpell.Speed
				if self:SilverBolts(target,delay)==2 and self:CondemnPrediction(target) then
					if V2:Cast(HK_E,target,{ttl=120,independent=false}) then break end
				end
			end
		end
	end
end

function ClassicVayne:Draw()
	if myHero.dead then return end
	if Menu.Draw.E:Value() and IsReady(_E) then
		Draw.Circle(myHero.pos, self.ESpell.Range, 1, Draw.Color(255, 244, 238, 66))
	end
end


-- Explicit request context. Nested helpers inherit their caller's context.
V2:RegisterPolicy({
    methods={
        EAntiMelee=function()return {priority='interactive'}end,
        EAntiDash=function()return {priority='interactive'}end,

        Combo=function()return V2:ModeContext("Combo")end,
        Harass=function()return V2:ModeContext("Harass")end,
    },
    exceptions={non_interrupting_summoner=true},
    channel=function(self,q)return not (myHero.activeSpell and myHero.activeSpell.valid and myHero.activeSpell.isChanneling) end,
    validate=function(self,q,slot,resolved)
        if slot==_Q and q.target then
            local endpoint=Vector((resolved and resolved.position)or q.target)
            for d=50,300,50 do if Game.isWall(myHero.pos:Extended(endpoint,math.min(d,GetDistance(endpoint,myHero.pos))))then return false end end
            if not Menu.Combo.AllowDangerousQ:Value() and ((IsUnderTurret2(endpoint) and not IsUnderTurret(myHero)) or GetEnemyCount(350,endpoint)>GetEnemyCount(350,myHero.pos))then return false end
        end
        if slot==_E and q.object then
            if not self:CanCondemn(q.object) then return false end
            if q.owner=='Combo' then
                return self:CanStun(q.object)
            elseif q.owner=='Harass' then
                return self:SilverBolts(q.object,self.ESpell.Delay+GetDistance(q.object.pos,myHero.pos)/self.ESpell.Speed)==2 and self:CondemnPrediction(q.object)~=nil
            elseif q.owner=='EAntiDash' then return self:IsDashThreat(q.object) and self:CondemnPrediction(q.object)~=nil
            elseif q.owner=='EAntiMelee'then return self:IsMeleeThreat(q.object) and self:CondemnPrediction(q.object)~=nil end
        end
        return true
    end,
})

ClassicVayne()

end
env.Menu=Menu
end
local supported={["Ahri"]=true,["Akali"]=true,["Ashe"]=true,["Blitzcrank"]=true,["Corki"]=true,["Ezreal"]=true,["Fiora"]=true,["Janna"]=true,["Katarina"]=true,["KogMaw"]=true,["Leona"]=true,["MasterYi"]=true,["MissFortune"]=true,["Pantheon"]=true,["Ryze"]=true,["Sivir"]=true,["Skarner"]=true,["Teemo"]=true,["Tristana"]=true,["Twitch"]=true,["Vayne"]=true}

local champion=myHero.charName:match('^Jade_(.+)$')
if not champion or not supported[champion] then return end
if not SDK then print('[ClassicAIOv2] SDK required');return end
if champion=='Katarina' and SDK.OrbamaVersion then
 local active=_G.KatarinaController
 if active and active.active and active.profile.hero==myHero.charName then return active end
end
if not GGPrediction then require(SDK.OrbamaVersion and 'OrbamaPrediction' or 'GGPrediction') end
if not GGPrediction then print('[ClassicAIOv2] Prediction provider required');return end
local ctx=modules.core(_G,modules,champion)
if not ctx:Active() then return ctx end
modules.runtime(ctx.env,champion)
return ctx
