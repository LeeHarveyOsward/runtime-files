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
