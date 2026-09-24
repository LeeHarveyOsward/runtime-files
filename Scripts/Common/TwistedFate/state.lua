local U=require('tf.util')
local P=require('CombatProfiles.twisted_fate')
local S={};S.__index=S
function S.new(c)return setmetatable({c=c,events={},serial=0,lastAttack=0,lastSpell='',previousStage='unknown'},S)end
function S:buff(unit,name)return self.c.sdk.BuffManager:GetBuff(unit,name)end
function S:channel()
    local h=self.c.hero;local a=h.activeSpell
    if self.c.sdk.IsRecalling(h) then return true,'recall',0 end
    if a and a.valid and U.lower(a.name)==U.lower(self.c.profile.gateName)
        and ((a.endTime or a.castEndTime or 0)>Game.Timer() or a.isChanneling)then
        return true,'gate',a.endTime or a.castEndTime or 0
    end
    return false,nil,0
end
function S:flight()
    local c=self.c;local now=Game.Timer();local attack=self.cardAttack
    if not attack or now-attack.seen>5 then self.cardFlight=nil;return end
    if not Game.MissileCount or now<(self.nextMissileScan or 0)then return end
    self.nextMissileScan=now+.04;local found
    for i=1,math.min(256,Game.MissileCount())do
        local missile=Game.Missile(i);local d=missile and missile.missileData
        if d and missile.pos then
            local owner=d.owner
            if type(owner)=='table' or type(owner)=='userdata'then owner=U.id(owner)end
            if owner==c.hero.networkID or owner==c.hero.handle then
                for color,name in pairs(c.profile.attacks)do
                    if U.lower(d.name or missile.name)==U.lower(name)then
                        local id=U.id(missile);local target=d.target
                        if type(target)=='table' or type(target)=='userdata'then target=U.id(target)end
                        found={id=id,target=target,color=color,missile=missile,speed=(d.speed or 0)>0 and d.speed or 1500}
                        if self.cardFlight and self.cardFlight.id==id then found.packet=self.cardFlight.packet
                        else
                            for _,list in ipairs({self.heroes,self.minions})do for _,u in ipairs(list)do
                                if u.networkID==target or u.handle==target then found.packet=c.combat:packet(u,color,attack.eReady);break end
                            end end
                            c:record('card_projectile_observed',{id=id,target=target,color=color})
                        end
                        break
                    end
                end
            end
        end
        if found then break end
    end
    if not found and self.cardFlight then
        c:record('card_projectile_disappeared',{id=self.cardFlight.id,target=self.cardFlight.target,effect='unknown'})
    end
    self.cardFlight=found
end
function S:refresh()
    local c=self.c;local h=c.hero;local now=Game.Timer();self.now=now
    self.mode,self.modeID=U.mode(c.sdk)
    self.spells={};for slot=0,5 do self.spells[slot]=h:GetSpellData(slot)end
    self.stage,self.color,self.cardExpiry=P.CardState(c.profile,self.spells[1].name,
        function(n)return self:buff(h,n)end,now)
    self.eReady=c.profile.eBuff and P.AliveBuff(self:buff(h,c.profile.eBuff),now) or false
    self.channeling,self.channelKind,self.channelEnd=self:channel()
    self.heroes={};self.minions={}
    for _,kind in ipairs({'heroes','minions'})do
        local row=c.sdk.SharedData:GetObjects(kind)
        if row then self[kind]=row.objects end
    end
    self.inventory=c.sdk.SharedData:GetInventory()
    local attack=c.sdk.SharedData:GetAttack().castEndTime or 0
    if attack>self.lastAttack and attack<=now+2 then
        self.lastAttack=attack;self.serial=self.serial+1
        if c.config:get('diagnostics')then
            local ad=h.attackData;local active=h.activeSpell
            local target=ad and ad.target or active and active.valid and active.target
            if type(target)=='table' or type(target)=='userdata'then target=U.id(target)end
            c:record('attack_observed',{castEnd=attack,target=target,mode=self.mode,
                card=self.color,eReady=self.eReady,serverStart=c.sdk.Attack.ServerStart,
                windup=c.sdk.Attack:GetWindup(),period=c.sdk.Attack:GetAnimation()})
        end
    end
    local a=h.activeSpell
    local spellToken=a and a.valid and (tostring(a.name)..':'..tostring(a.startTime or a.castEndTime)) or ''
    if spellToken~='' and spellToken~=self.lastSpell then
        self.lastSpell=spellToken;self.spellEvent={name=U.lower(a.name),at=now,serial=self.serial+1}
        self.serial=self.serial+1
        c:record('spell_observed',{name=a.name,start=a.startTime,castEnd=a.castEndTime,ending=a.endTime,channel=a.isChanneling,target=a.target})
        for color,name in pairs(c.profile.attacks)do
            if U.lower(a.name)==U.lower(name)then
                self.cardAttack={color=color,target=a.target,seen=now,castEnd=a.castEndTime or now,eReady=self.eReady}
                c:record('card_attack_observed',{color=color,target=a.target,castEnd=a.castEndTime})
            end
        end
    end
    if self.stage~=self.previousStage or self.color~=self.previousColor then
        self.cardEvent={stage=self.stage,color=self.color,at=now,serial=self.serial+1};self.serial=self.serial+1
        c:record('card_observed',{stage=self.stage,color=self.color,expiry=self.cardExpiry})
        if self.previousStage=='held' and self.stage~='held'then
            c:record('card_removed',{reason=(self.previousExpiry or 0)>0 and now>=self.previousExpiry and 'expired' or 'consumed_or_removed'})
        end
        self.previousStage=self.stage;self.previousColor=self.color
    end
    self.previousExpiry=self.cardExpiry
    self:flight()
end
function S:ready(slot,lock)
    local d=self.c.hero:GetSpellData(slot)
    return d and (slot>=4 or d.level>0) and Game.CanUseSpell(slot)==0 and (lock or self.c.hero.mana>=(d.mana or math.huge))
end
function S:cost(slot)local d=self.c.hero:GetSpellData(slot);return d and d.mana or math.huge end
function S:identity(id,list)
    for _,u in ipairs(list or self.heroes)do if U.id(u)==id and U.target(u)then return u end end
end
function S:protection(unit)
    local o={cc=0,spellShield=false,dodge=false,immune=false,invulnerable=false}
    U.buffs(unit,function(b)
        if P.AliveBuff(b,Game.Timer())then
            local n=U.lower(b.name);local remain=math.max(0,P.Expiry(b)-Game.Timer())
            if b.type==4 then o.spellShield=true end
            if b.type==5 or b.type==8 or b.type==12 or b.type==22 or b.type==23 or b.type==25 or b.type==29 or b.type==30 or b.type==35 then o.cc=math.max(o.cc,remain)end
            if b.type==18 or b.type==38 then o.invulnerable=true end
            if b.type==17 then o.dodge=true end
            if b.type==16 then o.immune=true end
            if n=='jaxcounterstrike' or n=='nilahw' or n=='shenwbuff' then o.dodge=true end
            if n=='olafragnarok' or n=='morganae' then o.immune=true end
            if n=='sivirshield' or n=='nocturneshroudofdarkness' then o.spellShield=true end
        end
    end)
    return o
end
function S:windupActive()return (self.c.sdk.Attack.CastEndTime or 0)>Game.Timer()end
function S:reserve(exclude)
    local h=self.c.hero;local reserve=0;local nearby=false
    for _,u in ipairs(self.heroes)do if u.team~=h.team and U.target(u) and U.dist(h,u)<1100 then nearby=true;break end end
    if nearby and exclude~=1 and (self.spells[1].level or 0)>0 then reserve=reserve+self:cost(1)end
    if (self.mode=='COMBO' or self.mode=='HARASS') and exclude~=0 and self.spells[0].level>0 then reserve=reserve+self:cost(0)end
    if self.channelKind=='gate' then
        if exclude~=1 then reserve=reserve+self:cost(1)end
        if exclude~=0 and self.spells[0].level>0 then reserve=reserve+self:cost(0)end
    end
    return math.min(h.maxMana or math.huge,reserve)
end
return S
