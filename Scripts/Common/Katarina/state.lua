local U=require('kata.util');local Profiles=require('kata.profiles')
local S={};S.__index=S
function S.new(c)return setmetatable({c=c,objects={},daggers={},consumed={},expected={},spells={},events={},serial=0,scanIndex=1,scanSeen={},scanEpoch=0},S)end
function S:spell(slot)return self.c.hero:GetSpellData(slot)or {}end
function S:ready(slot)
    local d=self:spell(slot)
    return (slot>=4 or (d.level or 0)>0) and (d.currentCd or 0)<=0 and Game.CanUseSpell(slot)==0
end
function S:channel()
    local c=self.c;local a=c.hero.activeSpell
    return (a and a.valid and c.profile.rNames[U.name(a.name)] and a.isStopped~=true)
        or U.buff(c.hero,c.profile.channels,Game.Timer())~=nil
end
function S:mark(o)return U.buff(o,self.c.profile.marks,Game.Timer(),U.id(self.c.hero))end
function S:interruptIncoming()
    local c=self.c;local names=Profiles.interrupts[c.profile.id]
    for _,o in ipairs(c.enemies)do
        local a=U.valid(o)and o.activeSpell
        if a and a.valid and names[U.name(a.name)]and(a.target==U.id(c.hero)or a.target==c.hero.handle)
            and(a.castEndTime or a.endTime or 0)>=Game.Timer()-.05 then return true end
    end
    return false
end
function S:emit(slot,source,at)
    self.serial=self.serial+1
    self.events[slot]={serial=self.serial,at=at or Game.Timer(),slot=slot,source=source,pos=U.copy(self.c.hero.pos)}
end
function S:refresh()
    local c=self.c;local now=Game.Timer();self.now=now
    for _,kind in ipairs({'heroes','minions','wards','turrets'})do
        local list=c.sdk.SharedData and c.sdk.SharedData:GetObjects(kind)
        if not list then
            list={};local stem=({heroes='Hero',minions='Minion',wards='Ward',turrets='Turret'})[kind]
            local count,get=Game[stem..'Count'],Game[stem]
            if count and get then for i=1,U.count(count(),kind=='heroes'and 20 or 512)do local o=get(i);if o then list[#list+1]=o end end end
        end
        self.objects[kind]=list
    end
    c.enemies={};c.allies={};c.minions=self.objects.minions
    for _,o in ipairs(self.objects.heroes)do if not U.same(o,c.hero)then
        if o.team==c.hero.team then c.allies[#c.allies+1]=o else c.enemies[#c.enemies+1]=o end
    end end
    local active=c.hero.activeSpell
    for slot=0,12 do
        local d=self:spell(slot);local prev=self.spells[slot]
        local start=d.castTime
        -- Host castTime may be cooldown end, as in Orbama's attack-reset contract.
        if U.finite(start)and start>now+.05 then start=start-(d.cd or d.currentCd or 0)end
        if U.finite(start)and start>0 and start<=now+.05 and prev and start>(prev.castTime or 0)then self:emit(slot,'spell_cast_time',start)end
        if prev and prev.cd<=0 and(d.currentCd or 0)>0 then self:emit(slot,'cooldown_transition',now)end
        if slot<4 and active and active.valid and c.profile.spellNames[slot][U.name(active.name)]then
            local t=active.startTime
            if U.finite(t)and (not prev or prev.activeStart~=t)then self:emit(slot,'active_spell',t)end
        end
        self.spells[slot]={name=d.name,cd=d.currentCd or 0,castTime=start,activeStart=active and active.valid and active.startTime}
    end
    if c.profile.id=='normal'then
        self:scan()
        if active and active.valid and U.name(active.name)=='katarinadaggerpickuppbaoe'and active.startTime~=self.lastPickup then
            self.lastPickup=active.startTime
            local near={}
            for _,d in pairs(self.daggers)do if U.dist(c.hero.pos,d.pos)<=c.profile.daggerPickup then near[#near+1]=d end end
            if #near==1 then
                local d=near[1];d.state='consumed';self.consumed[d.id]=d.expires;self.daggers[d.id]=nil
                c:log('effect_dagger_pickup',{target=d.object},'observed passive; unique nearby dagger')
            elseif #near>1 then
                for _,d in ipairs(near)do d.ambiguousPickup=true;d.state='pickup_unresolved'end
            end
        end
    end
end
function S:expect(slot,origin,target)
    if self.c.profile.id=='classic'and slot==0 and target then
        self.qFlight={target=U.id(target),expires=Game.Timer()+.25+U.dist(origin,target.pos)/self.c.profile.qSpeed};return
    end
    if self.c.profile.id~='normal'or (slot~=0 and slot~=1)then return end
    local pos=slot==1 and U.copy(origin)or target and U.toward(target.pos,origin,-350)
    if not pos then return end
    local now=Game.Timer();self.expected[#self.expected+1]={slot=slot,pos=pos,at=now,land=now+(slot==1 and 1.25 or U.dist(origin,target.pos)/self.c.profile.qSpeed+1),expires=now+6}
    while #self.expected>8 do table.remove(self.expected,1)end
end
function S:acceptDagger(o,index)
    if not o then return end
    local name=U.name(o.name or o.charName)
    -- Most particles are unrelated. Reject by name before native position,
    -- identity and ownership reads; discovery cadence and budget stay intact.
    if not name:find('katarina',1,true)or not name:find('_w_indicator',1,true)then return end
    if name:find('enemy',1,true)then return end
    local c=self.c;local id=U.id(o)
    if not id or not U.position(o.pos)or o.valid==false or o.dead then return end
    if self.consumed[id]and self.consumed[id]>Game.Timer()then return end
    -- Only a dagger-specific marker plus ownership/cast correlation qualifies.
    local owner=o.ownerID or o.ownerNetworkID or(o.owner and U.id(o.owner))
    if owner and owner~=0 and owner~=U.id(c.hero)and owner~=c.hero.handle then return end
    local now=Game.Timer();local match,ambiguity
    for _,x in ipairs(self.expected)do
        if now>=x.at and now<=x.expires and U.dist(o.pos,x.pos)<110 then
            if match then ambiguity=true end;match=x
        end
    end
    if (not owner or owner==0)and(not match or ambiguity)then return end
    local old=self.daggers[id]
    if old and old.object~=o and U.dist(old.pos,o.pos)>10 then old=nil end
    if not old then
        local count=0;for _ in pairs(self.daggers)do count=count+1 end;if count>=16 then return end
        local land=match and match.land or now+c.profile.daggerLand
        local expire=o.expireTime and o.expireTime>now and o.expireTime or land+c.profile.daggerDuration
        old={id=id,object=o,pos=U.copy(o.pos),land=land,expires=expire,source=match and match.slot,owned=true,state='observed'}
        self.daggers[id]=old
    end
    old.lastSeen=now;old.epoch=self.scanEpoch;old.pos=U.copy(o.pos);old.index=index or old.index
    old.state=now>=old.land and 'pickup_candidate'or 'observed'
    self.scanSeen[id]=true
end
function S:scan()
    local now=Game.Timer()
    for id,expiry in pairs(self.consumed)do if now>expiry then self.consumed[id]=nil end end
    for i=#self.expected,1,-1 do if now>self.expected[i].expires then table.remove(self.expected,i)end end
    for id,d in pairs(self.daggers)do
        if now>d.expires or d.object.valid==false or d.object.dead then self.daggers[id]=nil
        elseif now>=d.land then d.state='pickup_candidate'end
    end
    local count=Game.ParticleCount and U.count(Game.ParticleCount(),8192)or 0
    local get=Game.Particle
    if count==0 and Game.ObjectCount then count=U.count(Game.ObjectCount(),8192);get=Game.Object end
    if not get or count==0 then return end
    -- Refresh at most sixteen known marker identities before the bounded new-object
    -- scan, so a large particle list cannot starve already discovered daggers.
    for id,d in pairs(self.daggers)do if d.index then
        local object=get(d.index)
        if U.id(object)==id then self:acceptDagger(object,d.index)else self.daggers[id]=nil end
    end end
    if self.scanIndex>count then self.scanIndex=1;self.scanEpoch=self.scanEpoch+1;self.scanSeen={}end
    -- A fixed slice, independent of particle-count changes; catches replacements.
    for _=1,math.min(count,256)do
        self:acceptDagger(get(self.scanIndex),self.scanIndex);self.scanIndex=self.scanIndex+1
        if self.scanIndex>count then self.scanIndex=1;self.scanEpoch=self.scanEpoch+1;break end
    end
end
function S:daggerValid(d)return d and self.daggers[d.id]==d and not d.ambiguousPickup and d.owned and Game.Timer()>=d.land and Game.Timer()<d.expires and d.object.valid~=false and not d.object.dead and Game.Timer()-d.lastSeen<=.35 end
function S:enemiesNear(pos,range)
    local n=0;for _,o in ipairs(self.c.enemies)do if U.valid(o)and U.dist(pos,o.pos)<=range then n=n+1 end end;return n
end
function S:turret(pos)
    for _,t in ipairs(self.objects.turrets or {})do if U.valid(t)and t.team~=self.c.hero.team and U.dist(pos,t.pos)<(t.range or 775)+(t.boundingRadius or 80)then return true end end
    return false
end
return S
