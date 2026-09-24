local U=require('kata.util')
local P={};P.__index=P
function P.new(c)return setmetatable({c=c},P)end
function P:safe(pos,target,escape)
    local c=self.c
    if not U.position(pos)then return false end
    if not c.config:get('turret')and c.state:turret(pos)then return false end
    if escape then return c.state:enemiesNear(pos,550)<=c.state:enemiesNear(c.hero.pos,550)end
    if c.state:interruptIncoming()then return false end
    if U.hp(c.hero)<c.config:get('minHP')then return false end
    if c:healthPrediction(c.hero,.45)<=0 then return false end
    return c.state:enemiesNear(pos,650)<=c.config:get('maxEnemies')
end
function P:target(range)
    local c=self.c;local ts=c.sdk.TargetSelector
    local selected=ts.GetSelectedTarget and ts:GetSelectedTarget()or ts.Selected
    if ts.MenuCheckSelected and not ts.MenuCheckSelected:Value()then selected=nil end
    if U.valid(selected)and selected.team~=c.hero.team and U.dist(c.hero.pos,selected.pos)<=range then return selected end
    if ts.GetTarget then local o=ts:GetTarget(range,c.sdk.DAMAGE_TYPE_MAGICAL);if U.valid(o)and not c.damage:protected(o)then return o end end
    local best,score
    for _,o in ipairs(c.enemies)do if U.valid(o)and U.dist(c.hero.pos,o.pos)<=range and not c.damage:protected(o)then
        local s=(o.health or 0)+U.dist(c.hero.pos,o.pos)*.2
        if not score or s<score then best,score=o,s end
    end end
    return best
end
function P:estimate(target,origin,exclude)
    local c=self.c;local best={lethal=false,time=0,damage=0,parts={}}
    if not U.valid(target)or c.damage:protected(target)or c.damage:spellShield(target)then return best end
    -- Finite short horizons; no assumed takedown or dagger reset in any branch.
    local usable,aims,safeAt={},{},{}
    for slot=0,2 do usable[slot]=slot~=exclude and c.config:get('combo'..({'Q','W','E'})[slot+1])and c:ready(slot)end
    usable.AA=exclude~='AA'
    for _,sequence in ipairs({{0,2,1,'AA'},{2,1,0,'AA'},{0,1,'AA'},{'AA',2,0,1}})do
        local pool=c.damage:pool(target,(target.health or 0)+10);local time=0
        local pos=origin;local used={}
        for _,slot in ipairs(sequence)do
            local range=slot==0 and c.profile.qRange or slot==2 and c.profile.eRange or slot==1 and c.profile.wRange or c:attackRange(target)
            local aim
            if usable[slot]then
                local at=time+.25;aim=aims[at]
                if not aim then aim=U.predict(target,at);aims[at]=aim end
            end
            local safe=true
            if aim and slot==2 and U.dist(pos,aim)<=range then
                local at=time+.25
                if safeAt[at]==nil then safeAt[at]=self:safe(aim,target)end
                safe=safeAt[at]
            end
            if aim and U.dist(pos,aim)<=range and safe then
                time=time+.25;pool.hp=pool.hp+(target.hpRegen or 0)*.25
                c.damage:apply(pool,c.damage:parts(slot,target,.25,pool));used[#used+1]=slot
                if slot==2 then pos=aim end
                if pool.hp<=0 then break end
            end
        end
        local result={lethal=pool.hp<=0,time=time,damage=math.max(0,target.health-pool.hp),parts=used}
        if result.lethal and(not best.lethal or result.time<best.time)or not best.lethal and result.damage>best.damage then best=result end
    end
    return best
end
function P:combat(mode)
    local c=self.c
    if c.state:channel()and not c.config:get('smartR')then return end
    if mode=='harass'and c.trade then
        local trade=c.trade
        if U.dist(c.hero.pos,trade.origin)<60 or Game.Timer()>trade.expires then c.trade=nil
        elseif Game.Timer()-trade.at>.55 or not U.valid(trade.target)then
            local a={kind='move',pos=trade.origin,owner='harass',validate=function()
                return c.mobility.terrain:walkLine(c.hero.pos,trade.origin,c.hero.boundingRadius or 35)==true
            end}
            if c:legal(a)then return a end
            c.trade=nil
        end
    end
    local target=self:target(c.profile.eRange+600)
    if not target then return end
    local d=U.dist(c.hero.pos,target.pos);local candidates={}
    local function add(a,score)
        a.owner=mode;a.target=a.target or target;a.score=score
        local legal,why=c:legal(a)
        if legal then
            local direct=a.slot~=2 or U.same(a.anchor,target)or c.profile.id=='normal'and a.pos and U.dist(a.pos,target.pos)<=150
            local damage=direct and a.slot and a.slot<6 and c.damage:amount(a.slot,target,a.slot==3 and .5 or .25)or 0
            if a.rule then damage=c.items:damage(a.rule,target)end
            a.score=a.score+damage
            a.estimate=damage
            if direct and a.slot and a.slot<6 and c.damage:lethal(a.slot,target,a.slot==3 and .5 or .3)then a.score=a.score+2000;a.lethal=true end
            if a.rule and damage>0 and c.damage:apply(c.damage:pool(target,target.health+10),{magic=damage})<=0 then a.score=a.score+2000;a.lethal=true end
            candidates[#candidates+1]=a
        elseif c.telemetry then c.telemetry:reject(a,why)
        end
    end
    if c:ready(0)and c.config:get(mode..'Q')and d<=c.profile.qRange then add({slot=0},60)end
    if c:ready(1)and c.config:get(mode..'W')and d<=c.profile.wRange then
        -- A pending, actually observed Q may need a mark before spending W.
        local q=c.state.qFlight
        local wait=c.profile.id=='classic'and q and q.target==U.id(target)and not c.state:mark(target)and Game.Timer()<q.expires
        if not wait or c.damage:lethal(1,target)then add({slot=1},c.profile.id=='normal'and 180 or 100)end
    end
    if c:ready(2)and c.config:get(mode..'E')then
        local targetPos=U.predict(target,.2)
        for _,anchor in ipairs(c:anchors())do
            local pos=c:landing(anchor,target)
            if pos and U.dist(pos,targetPos)<=c.profile.wRange and self:safe(pos,target)then
                if mode~='harass'or c:hasReturn(pos,anchor)then
                    local extended=d>c.profile.wRange and 90 or -100
                    local dagger=c.state.daggers[U.id(anchor)]
                    add({slot=2,anchor=anchor,pos=c.profile.id=='normal'and pos or nil,target=c.profile.id=='classic'and anchor or target,
                        combatTarget=target,dagger=dagger},extended+(dagger and U.dist(pos,dagger.pos)<=c.profile.daggerPickup and c.damage:amount('passive',target)or 0))
                end
            end
        end
    end
    if mode=='combo'and c:ready(3)and c.config:get('comboR')and d<=c.profile.rActivation then
        local short=self:estimate(target,c.hero.pos,3)
        if not short.lethal then add({slot=3},30+c.state:enemiesNear(c.hero.pos,450)*40)end
    end
    if mode=='combo'and c.config:get('ignite')then
        for slot=4,5 do if c:ready(slot)and U.name(c.state:spell(slot).name)=='summonerdot'and d<=600
            and not U.buff(target,{summonerdot=true},Game.Timer())and c.damage:lethal(slot,target,5)then add({slot=slot},10)end end
    end
    local item=c.items:activeCandidate(target,mode);if item then add(item,item.score or 0)end
    local best
    for _,a in ipairs(candidates)do if not best or a.score>best.score then best=a end end
    if best and c.state:channel()then
        if not c.config:get('smartR')or not best.lethal or best.slot==3 then return end
        if c.damage:lethal(3,target,.34)then return end
        best.release=true
    end
    if not best and mode=='combo'and not c.state:channel()then
        if c.profile.id=='classic'and c.config:get('offensiveWards')and c:ready(2)and c.mobility:slot()and d>c.profile.eRange then
            local pos=U.toward(c.hero.pos,target.pos,math.min(580,d-150))
            local result=self:estimate(target,pos,2)
            if result.lethal and self:safe(pos,target)then return {kind='wardplan',owner='combo',pos=pos,target=target,lethal=true}end
        end
        if c.config:get('extended')and d>c.profile.eRange then
            local pos=U.toward(c.hero.pos,target.pos,math.min(375,d-100))
            if self:safe(pos,target)and self:estimate(target,pos).lethal then
                for slot=4,5 do if c:ready(slot)and U.name(c.state:spell(slot).name)=='summonerflash'then return {slot=slot,owner=mode,pos=pos,extended=true,target=target}end end
                for slot,x in pairs(c.items.inventory)do if x.rule and x.rule.active=='move'and c:ready(slot)and c.items:enabled(x.id)then
                    pos=U.toward(c.hero.pos,target.pos,x.rule.range)
                    if self:safe(pos,target)and self:estimate(target,pos).lethal then return {slot=slot,owner=mode,pos=pos,extended=true,rule=x.rule,itemID=x.id,target=target}end
                end end
            end
        end
    end
    return best
end
function P:farm(mode)
    local c=self.c;local usable={};local any=false
    for slot=0,2 do
        usable[slot]=c.config:get(mode..({'Q','W','E'})[slot+1])and c:ready(slot)
            and not(slot==1 and mode=='last'and c.profile.id=='normal')
        any=any or usable[slot]
    end
    if not any then return end
    local best,score;local nearby={};local hits=0
    for i=1,math.min(#c.minions,128)do local o=c.minions[i]
        if U.valid(o)and U.dist(c.hero.pos,o.pos)<=c.profile.eRange and(mode=='jungle'and o.team==300 or mode~='jungle'and o.team~=300 and o.team~=c.hero.team)then
            if #nearby<32 then nearby[#nearby+1]=o end
            if U.dist(c.hero.pos,o.pos)<=c.profile.wRange then hits=hits+1 end
        end
    end
    for _,o in ipairs(nearby)do
        local eligible=U.valid(o)and(mode=='jungle'and o.team==300 or mode~='jungle'and o.team~=c.hero.team and o.team~=300)
        if eligible and U.dist(c.hero.pos,o.pos)<c.profile.eRange then
            for slot=0,2 do if usable[slot]and not(slot==1 and (mode=='lane'or c.profile.id=='normal')and hits<c.config:get('clearHits'))then
                local a={slot=slot,owner=mode,target=o,farm=true,anchor=slot==2 and o or nil}
                if c.profile.id=='normal'and slot==2 then a.pos=c:landing(o,o)end
                local impact=slot==0 and .25+U.dist(c.hero.pos,o.pos)/c.profile.qSpeed or slot==1 and c.profile.id=='normal'and 1.25 or .2
                local at,observedHP=Game.Timer(),o.health
                local hp=c:healthPrediction(o,impact)
                local damage=c.damage:amount(slot,o)
                local aaSaved=mode=='last'and hp>0 and damage>=hp and c:aaSaves(o,impact)or false
                local valid=hp>0 and(mode~='last'or damage>=hp and not aaSaved)
                if slot==1 and c.profile.id=='normal'then valid=mode~='last'and hits>=c.config:get('clearHits')end
                if slot==1 and mode=='lane'then valid=valid and hits>=c.config:get('clearHits')end
                local facts=valid and {target=o,impact=impact,hp=hp,damage=damage,aaSaved=aaSaved,at=at,observedHP=observedHP}
                if valid and c:legal(a,nil,facts)then
                    local s=(damage>=hp and 1000 or 0)+(slot==1 and hits*100 or 0)-(o.health or 0)*.01
                    if not score or s>score then best,score=a,s end
                end
            end end
        end
    end
    return best
end
return P
