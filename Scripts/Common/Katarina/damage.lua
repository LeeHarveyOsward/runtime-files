local U=require('kata.util');local P=require('kata.profiles')
local D={};D.__index=D
-- Installed KatarinaPassive TotalDamage level table, ranks 1..18.
local passive={68.184616,72.138458,76.861542,82.353844,88.615387,95.646156,103.446152,112.015381,121.353844,131.461533,142.338455,153.984619,166.399994,179.584610,193.538467,208.261536,223.753845,240.015381}
function D.new(c)return setmetatable({c=c},D)end
function D:protected(o)return o.isImmortal==true or U.buff(o,P.protection,Game.Timer())~=nil end
function D:spellShield(o)return U.buff(o,P.spellShield,Game.Timer())~=nil end
function D:mitigate(o,kind,raw)
    if kind=='true'then return math.max(0,raw)end
    local c=self.c;local dtype=kind=='magic'and c.sdk.DAMAGE_TYPE_MAGICAL or c.sdk.DAMAGE_TYPE_PHYSICAL
    return math.max(0,c.sdk.Damage:CalculateDamage(c.hero,o,dtype,raw))
end
function D:raw(slot,o)
    local c=self.c;local p,h=c.profile,c.hero;local ap,ad=h.ap or 0,h.totalDamage or 0;local bonus=h.bonusDamage or math.max(0,ad-(h.baseDamage or ad))
    local level=h.levelData and h.levelData.lvl or 1
    if slot=='passive'then
        if p.id~='normal'then return 0,0 end
        return (passive[level]or 0)+.6*bonus+(.7+(level>=6 and .1 or 0)+(level>=11 and .1 or 0)+(level>=16 and .1 or 0))*ap,0
    end
    if slot=='AA'then return 0,ad end
    local rank=c.state:spell(slot).level or 0;if rank<=0 then return 0,0 end
    if slot==0 then return (p.qBase[rank]or 0)+p.qAP*ap,0
    elseif slot==1 then return p.id=='classic'and((p.wBase[rank]or 0)+p.wAP*ap+p.wAD*bonus)or 0,0
    elseif slot==2 then return (p.eBase[rank]or 0)+p.eAP*ap+p.eAD*ad,0
    elseif slot==3 then
        local physical=p.id=='normal'and .16*(1+3.125*math.max(0,h.bonusAttackSpeed or 0))*bonus or 0
        return (p.rBase[rank]or 0)+p.rAP*ap+(p.rAD or 0)*bonus,physical
    end
    return 0,0
end
function D:mark(o)
    local c=self.c;local rank=c.state:spell(0).level or 0
    if c.profile.id=='classic'and rank>0 and c.state:mark(o)then return (c.profile.markBase[rank]or 0)+c.profile.markAP*(c.hero.ap or 0)end
    return 0
end
function D:parts(slot,o,seconds,sim)
    sim=sim or {};sim.procs=sim.procs or {}
    if slot==3 then
        local duration=self.c.profile.rDuration;local active=self.c.hero.activeSpell
        if self.c.state:channel()and active and U.finite(active.startTime)and active.startTime>0 then
            duration=math.max(0,duration-(Game.Timer()-active.startTime))
        end
        local ticks=math.floor(math.max(0,math.min(seconds or .5,duration))*self.c.profile.rTicks+1e-6)
        local total={magic=0,physical=0,trueDamage=0}
        local work=self:pool(o,sim.hp or o.health);work.markUsed=sim.markUsed;work.procs=sim.procs
        local baseMagic,basePhysical,onhitRatio
        for tick=1,ticks do
            if work.hp<=0 then break end
            if U.dist(self.c.hero.pos,U.predict(o,tick/self.c.profile.rTicks))<=self.c.profile.rRange then
            if baseMagic==nil then
                baseMagic,basePhysical=self:raw(3,o)
                if self.c.profile.id=='normal'then onhitRatio=self.c.profile.rOnHit[self.c.state:spell(3).level]or 0 end
            end
            local m,p=baseMagic,basePhysical
            if not work.markUsed then m=m+self:mark(o);work.markUsed=true end
            if self.c.profile.id=='normal'then
                local a,b=self.c.items:onhit(o,work,3)
                m=m+a*onhitRatio;p=p+b*onhitRatio
            end
            local hit={magic=self:mitigate(o,'magic',m),physical=self:mitigate(o,'physical',p),trueDamage=0}
            total.magic=total.magic+hit.magic;total.physical=total.physical+hit.physical;self:apply(work,hit)
            end
        end
        sim.markUsed=work.markUsed;return total
    end
    local magic,physical=self:raw(slot,o);local trueDamage=0
    if slot==4 or slot==5 then trueDamage=(50+20*(self.c.hero.levelData.lvl or 1))*math.min(1,(seconds or 5)/5);magic=0;physical=0 end
    if slot~='passive'and slot~=0 and slot~=4 and slot~=5 and not(sim and sim.markUsed)then magic=magic+self:mark(o);if sim then sim.markUsed=true end end
    if slot=='AA'or self.c.profile.id=='normal'and(slot==2 or slot=='passive'or slot==3)then
        local m,p=self.c.items:onhit(o,sim,slot);magic=magic+m;physical=physical+p
    end
    return {magic=self:mitigate(o,'magic',magic),physical=self:mitigate(o,'physical',physical),trueDamage=trueDamage}
end
function D:pool(o,hp)return {hp=hp or o.health,magic=o.shieldAP or 0,physical=o.shieldAD or 0,all=o.allShield or 0,markUsed=false,procs={}}end
function D:apply(pool,parts)
    for _,kind in ipairs({'magic','physical','trueDamage'})do
        local value=parts[kind]or 0
        if pool[kind]then local n=math.min(value,pool[kind]);pool[kind]=pool[kind]-n;value=value-n end
        local n=math.min(value,pool.all);pool.all=pool.all-n;value=value-n;pool.hp=math.max(0,pool.hp-value)
    end
    return pool.hp
end
function D:lethal(slot,o,seconds)
    if self:protected(o)or(slot~='AA'and self:spellShield(o))then return false end
    local pool=self:pool(o,(o.health or 0)+10+(o.hpRegen or 0)*(seconds or .3))
    return self:apply(pool,self:parts(slot,o,seconds,pool))<=0
end
function D:amount(slot,o,seconds)local x=self:parts(slot,o,seconds,{});return x.magic+x.physical+x.trueDamage end
return D
