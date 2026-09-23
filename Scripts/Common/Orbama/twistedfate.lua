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
