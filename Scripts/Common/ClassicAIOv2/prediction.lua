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
