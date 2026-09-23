local U=require('lho.util')
local Wave={};Wave.__index=Wave
function Wave.new(ctx) return setmetatable({ctx=ctx,reserved={}},Wave) end
function Wave:value(m)
    if not self.ctx.config:get('csGoldPriority') then return 0 end
    if type(m.goldBounty)=='number' and m.goldBounty>0 then return m.goldBounty end
    -- Fallback ordering weights, not a claim about the live gold payout.
    local name=U.name(m.charName)
    if name:find('siege',1,true) or name:find('cannon',1,true) or name:find('super',1,true) then return 60 end
    if name:find('ranged',1,true) or name:find('caster',1,true) or name:find('wizard',1,true) then return 14 end
    return 21
end
function Wave:prefer(m,best,deadline,bestDeadline,nextAttack)
    if not best then return true end
    if deadline<=nextAttack and bestDeadline<=nextAttack and self:value(m)~=self:value(best) then
        return self:value(m)>self:value(best)
    end
    if deadline~=bestDeadline then return deadline<bestDeadline end
    if self:value(m)~=self:value(best) then return self:value(m)>self:value(best) end
    return m.health<best.health or m.health==best.health and U.id(m)<U.id(best)
end
function Wave:healthAt(m,delay)
    local now=self.ctx:now()
    if self.forecastAt~=now then self.forecastAt=now;self.forecasts={} end
    local id=U.id(m);local row=self.forecasts[id]
    if not row or row.health~=m.health then row={health=m.health,values={}};self.forecasts[id]=row end
    local key=math.floor(delay*1000+.5)
    if row.values[key]==nil then row.values[key]=self.ctx:healthAt(m,delay) end
    return row.values[key]
end
function Wave:units(anchor)
    local out={}
    for id,r in pairs(self.reserved) do if self.ctx:now()>r.untilTime then self.reserved[id]=nil end end
    for _,m in ipairs(self.ctx.minions or {}) do
        if U.valid(m) and m.team~=myHero.team and m.team~=300 and U.dist(m.pos,myHero.pos)<=self.ctx.profile.qRange then out[#out+1]=m end
    end
    return out
end
function Wave:impact(m)
    return self.ctx:windup()+self.ctx.latency*.5
end
function Wave:cycle()
    local a=self.ctx.sdk.Attack
    return a and a.GetAnimation and a:GetAnimation() or 1/math.max(.5,myHero.attackSpeed or 1)
end
function Wave:attackWait()
    local c=self.ctx;local a=c.sdk.Attack
    if not a or not a.IsReady or a:IsReady() then return 0 end
    -- GG timestamps use Game.Timer seconds. Do not add another latency term
    -- to its readiness calculation; impact() accounts for our travel budget.
    if a.ServerStart then return math.max(0,a.ServerStart+self:cycle()-c:now()) end
    return self:cycle()
end
function Wave:damage(slot,m)
    local c=self.ctx
    if not U.valid(m) or m.team==myHero.team or m.team==300 then return 0 end
    local lane=false
    for _,unit in ipairs(c.minions or {}) do if U.same(m,unit) then lane=true;break end end
    if not lane then return 0 end
    local verified=c.config:get('mechanicsVerified') or c.profile.damageVerified
    if not verified and not c.config:get('laneEstimates') then return 0 end
    return c:spellDamageEstimate(slot,m,1)*(1-c.config:get('laneDamageMargin')/100)
end
function Wave:reservedTarget(m)
    local r=self.reserved[U.id(m)]
    if r and (not U.valid(m) or self.ctx:now()>r.untilTime or r.event.status=='unconfirmed' or r.event.cancelled) then
        self.reserved[U.id(m)]=nil;return false
    end
    return r~=nil
end
function Wave:reserve(units,event,delay)
    for _,m in ipairs(units) do self.reserved[U.id(m)]={event=event,untilTime=self.ctx:now()+delay+.2} end
end
function Wave:attackTarget(anchor)
    local c=self.ctx;local last,lastHP,lastDeadline=nil,math.huge,math.huge;local push,pushHP=nil,-1;local incoming=false
    local cycle=self:cycle();local wait=self:attackWait()
    for _,m in ipairs(self:units(anchor)) do
        if not self:reservedTarget(m) and U.dist(myHero.pos,m.pos)<=c:attackRange(m) then
            local hp=self:healthAt(m,wait+self:impact(m));local nextHP=self:healthAt(m,wait+self:impact(m)+cycle)
            if hp>0 and hp<=c:aaDamage(m) then
                local deadline=math.huge
                if nextHP<=0 then
                    for step=1,4 do
                        local delay=wait+self:impact(m)+cycle*step/4
                        if self:healthAt(m,delay)<=0 then deadline=delay;break end
                    end
                end
                if self:prefer(m,last,deadline,lastDeadline,wait+self:impact(m)+cycle) then
                    last,lastHP,lastDeadline=m,hp,deadline
                end
            end
            if hp>c:aaDamage(m) and nextHP<=c:aaDamage(m) then incoming=true end
            if hp>c:aaDamage(m) and hp>pushHP then push,pushHP=m,hp end
        end
    end
    return last or (not incoming and push or nil),last~=nil,incoming
end
-- Bounded earliest-deadline AA simulation. Forecasts are estimates: reject
-- wave softening if any newly endangered minion lacks an AA/Q rescue slot.
function Wave:schedule(units,damage,castDelay,boost,effectAt)
    local c=self.ctx;local horizon=c.config:get('waveHorizon');local step=.1
    local saved,deadlines={},{};local at=self:attackWait()+c:windup()+c.latency*.5+(castDelay or 0)
    local attackable,attackDamage={},{};local cycle=self:cycle()
    local function hp(m,t)return self:healthAt(m,t)-(t>=(effectAt or 0) and damage and damage[U.id(m)] or 0)end
    for _,m in ipairs(units) do
        attackable[m]=U.dist(myHero.pos,m.pos)<=c:attackRange(m)
        if attackable[m] then attackDamage[m]=c:aaDamage(m) end
        if not self:reservedTarget(m) then
            if hp(m,0)<=0 then deadlines[U.id(m)]=0
            elseif hp(m,horizon)<=0 then
                -- Minion damage forecasts are normally non-increasing. Locate
                -- the first death boundary without querying every grid sample.
                local lo,hi=0,horizon
                for _=1,7 do local mid=(lo+hi)/2;if hp(m,mid)<=0 then hi=mid else lo=mid end end
                deadlines[U.id(m)]=hi
            end
        end
    end
    local attacks=0
    while at<=horizon do
        local best,deadline=nil,math.huge
        for _,m in ipairs(units) do
            local id=U.id(m);local health=hp(m,at)
            if not saved[id] and not self:reservedTarget(m) and attackable[m]
                and health>0 and health<=attackDamage[m]
                and self:prefer(m,best,deadlines[id] or math.huge,deadline,at+cycle) then
                best,deadline=m,deadlines[id] or math.huge
            end
        end
        if best then
            saved[U.id(best)]=at;attacks=attacks+1
            at=at+cycle/(boost and attacks<=2 and 1.2 or 1)
        else at=at+step end
    end
    return saved,deadlines
end
function Wave:canSoften(units,slot,primary,rescue,lastOnly)
    local c=self.ctx;local damage={};local affected=0;local delay=.25+c.latency*.5
    if slot==0 then delay=delay+U.dist(myHero.pos,primary.pos)/c.profile.qSpeed
        if self:healthAt(primary,delay)<=0 then return false end
    end
    for _,m in ipairs(units) do
        if slot==2 and U.dist(myHero.pos,m.pos)<=c.profile.eRange or slot==0 and U.same(m,primary) then
            -- Use the full estimate for future HP depletion, the lower estimate
            -- for claiming kills. The uncertainty band never certifies a kill.
            damage[U.id(m)]=c:spellDamageEstimate(slot,m,1);affected=affected+1
        end
    end
    if affected==0 or slot==2 and affected<2 and not rescue then return false end
    local saved,deadlines=self:schedule(units,damage,.25,false,delay)
    local baseline=rescue and self:schedule(units) or nil
    local qAvailable=slot~=0 and c.config:get(lastOnly and 'lastQ' or 'waveQ') and c:stage(0)==1 and c:ready(0)
        and (myHero.mana or 0)>=(c:spell(slot).mana or 0)+(c:spell(0).mana or 0)
    local qRescue,required=nil,{}
    for _,m in ipairs(units) do
        local id=U.id(m);local hit=damage[id] or 0;local hp=self:healthAt(m,delay)
        local killed=hit>0 and hp>0 and hp<=self:damage(slot,m)
        local protect=not rescue or baseline[id] or hit>0 and self:healthAt(m,c.config:get('waveHorizon'))>0
        if not killed and not self:reservedTarget(m) and deadlines[id] and protect then required[id]=m end
        if required[id] and not saved[id] then
            local qDelay=.25+.25+U.dist(myHero.pos,m.pos)/c.profile.qSpeed+c.latency*.5
            local after=self:healthAt(m,qDelay)-hit
            local point=qAvailable and c.spells:predict(m)
            if qAvailable and point and after>0 and after<=self:damage(0,m) and #c.spells:blockers(m,point)==0 then
                qAvailable=false;qRescue=id
            else return false end
        end
    end
    if qRescue then
        local remaining={};for _,m in ipairs(units) do if U.id(m)~=qRescue then remaining[#remaining+1]=m end end
        local later=self:schedule(remaining,damage,.5,false,delay)
        for id in pairs(required) do if id~=qRescue and not later[id] then return false end end
    end
    return true
end
function Wave:cast(slot,target,units,delay)
    local c=self.ctx;local ok,event
    if slot==0 then ok,event=c.spells:q1(target,'clear',false)
    elseif slot==2 then ok,event=c.spells:e(target,'clear')
    else ok,event=c.spells:w(myHero,'clear',nil,c.mode=='gg_last' and 'last' or 'wave') end
    if ok then
        if slot~=1 then
            if c.actions.api then self.castEvent=event;self.castUntil=nil
            else self.castUntil=c:now()+.25 end
        end
        self:reserve(units or {},event,delay or .25);return true
    end
    return false
end
function Wave:attackLocked()
    local c=self.ctx;local event=self.castEvent
    if event then
        local action=c.actions:inputAction(event.cursorID)
        if not action or action.state=='cancelled_before_send' or event.cancelled then
            self.castEvent=nil;self.castUntil=nil
        elseif action.sentAt then
            local sent=c:now()-math.max(0,c.actions:inputNow()-action.sentAt)*.001
            self.castUntil=sent+.25
            if c:now()>=self.castUntil then self.castEvent=nil end
        end
    end
    return c:now()<(self.castUntil or 0)
end
function Wave:tick(anchor,beforeAttack,lastOnly)
    self.forecastAt=nil
    local c=self.ctx;local units=self:units(anchor);local aa,hasLastHit,incoming=self:attackTarget(anchor)
    if not c.config:get(lastOnly and 'lastAbilities' or 'waveAbilities') then return false end
    if not c.config:get('mechanicsVerified') and not c.profile.damageVerified then
        c.status=c.config:get('laneEstimates') and 'Lane Q/E: profile estimates (margin applied)' or 'Lane Q/E paused: damage estimates disabled'
    end
    if c.sdk.Orbwalker:IsAutoAttacking() or self:attackLocked() then return false end
    local useQ=c.config:get(lastOnly and 'lastQ' or 'waveQ');local useE=c.config:get(lastOnly and 'lastE' or 'waveE')
    local eKills,qSaves={},{}
    local eDelay=.25+c.latency*.5
    local cycle=self:cycle();local wait=self:attackWait()
    local aaSaved=self:schedule(units)
    for _,m in ipairs(units) do
        if not self:reservedTarget(m) then
            local ehp=self:healthAt(m,eDelay)
            if useE and c:stage(2)==1 and c:ready(2) and U.dist(myHero.pos,m.pos)<=c.profile.eRange and ehp>0 and ehp<=self:damage(2,m) then
                eKills[#eKills+1]=m
            end
            if useQ and not aaSaved[U.id(m)] and c:stage(0)==1 and c:ready(0) then
                local point=c.spells:predict(m)
                if point then
                    local qDelay=.25+U.dist(myHero.pos,point)/c.profile.qSpeed+c.latency*.5
                    local qhp=self:healthAt(m,qDelay)
                    local aaLater=self:healthAt(m,wait+self:impact(m)+(U.same(m,aa) and 0 or cycle))
                    if qhp>0 and qhp<=self:damage(0,m)
                        and (aaLater<=0 or U.dist(myHero.pos,m.pos)>c:attackRange(m)) then
                        qSaves[#qSaves+1]={unit=m,delay=qDelay,hp=qhp}
                    end
                end
            end
        end
    end
    table.sort(qSaves,function(a,b)
        local av,bv=self:value(a.unit),self:value(b.unit)
        if av~=bv then return av>bv end
        if a.hp~=b.hp then return a.hp<b.hp end
        return U.id(a.unit)<U.id(b.unit)
    end)
    local eRescue=#eKills==1 and (not hasLastHit or not U.same(eKills[1],aa)
        and self:healthAt(eKills[1],wait+self:impact(eKills[1])+cycle)<=0)
    local waitForAA=false
    if beforeAttack and hasLastHit then
        local killsAA=false;local canWait=true
        for _,m in ipairs(eKills) do
            if U.same(m,aa) then killsAA=true end
            if self:healthAt(m,self:impact(aa)+eDelay)<=0 then canWait=false end
        end
        waitForAA=not killsAA and canWait
    end
    local eNeeded=not lastOnly
    for _,m in ipairs(eKills) do if not aaSaved[U.id(m)] then eNeeded=true end end
    if (#eKills>=2 or eRescue) and not waitForAA and eNeeded and self:canSoften(units,2,nil,true,lastOnly) then
        if self:cast(2,eKills[1],eKills,eDelay) then return true end
    end
    -- Let GG issue an imminent last hit first; save a different minion after
    -- that windup instead of cancelling an attack which was already committed.
    if beforeAttack and hasLastHit then
        for _,candidate in ipairs(qSaves) do
            if not U.same(candidate.unit,aa) and self:healthAt(candidate.unit,candidate.delay+self:impact(aa))<=0
                and self:healthAt(aa,.25+self:impact(aa))>0 then
                if self:cast(0,candidate.unit,{candidate.unit},candidate.delay) then return true end
            end
        end
    else
        for _,candidate in ipairs(qSaves) do
            if self:cast(0,candidate.unit,{candidate.unit},candidate.delay) then return true end
        end
    end
    if not beforeAttack and not hasLastHit and not incoming then
        if not lastOnly and c.config:get('waveSoften') then
            if useE and c:stage(2)==1 and c:ready(2) and self:canSoften(units,2) then
                for _,m in ipairs(units) do if U.dist(myHero.pos,m.pos)<=c.profile.eRange and self:damage(2,m)>0 then
                    if self:cast(2,m,eKills,eDelay) then return true end;break
                end end
            end
        end
        if c.config:get(lastOnly and 'lastW' or 'waveW') and not c.clear:weaving() then
            local useful=not lastOnly and U.hp(myHero)<90 and #units>=2
            if lastOnly then
                local faster,deadlines=self:schedule(units,nil,0,true)
                for id in pairs(deadlines) do if not aaSaved[id] and faster[id] then useful=true end end
            end
            if useful then return self:cast(1,myHero) end
        end
    end
    if not lastOnly and useQ and c.config:get('harassQ') and not beforeAttack and not hasLastHit and not incoming and #qSaves==0 and #eKills==0 and c.config:get('waveHarass') then
        local target=c:target(c.profile.qRange)
        if target then return c.spells:q1(target,'clear',false) end
    end
    return false
end
return Wave
