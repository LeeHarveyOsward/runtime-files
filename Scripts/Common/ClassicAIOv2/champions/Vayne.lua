local Version = 1.02

-- require("MapPositionGOS")

class "ClassicVayne"

function ClassicVayne:__init()		 
	print("Classic AIO - Vayne Loaded")
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
