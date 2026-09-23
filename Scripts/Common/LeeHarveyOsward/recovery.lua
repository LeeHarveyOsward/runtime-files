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
