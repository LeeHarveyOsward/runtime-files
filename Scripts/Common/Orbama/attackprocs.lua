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
