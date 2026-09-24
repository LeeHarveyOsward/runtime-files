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
