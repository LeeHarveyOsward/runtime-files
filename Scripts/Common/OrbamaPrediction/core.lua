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
