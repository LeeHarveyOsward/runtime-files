local U=require('lho.util')
local D={};D.__index=D
function D.new(ctx) return setmetatable({ctx=ctx,cache={}},D) end
function D:ignite(target,ownedSlot)
    local c=self.ctx
    for slot=4,5 do
        if U.name(c:spell(slot).name)=='summonerdot' and c:ready(slot) and (not c.actions.pending[slot] or slot==ownedSlot)
            and U.dist(myHero.pos,target.pos)<=600 and not U.buff(target,{summonerdot=true},c:now()) then
            if not c.config:get('mechanicsVerified') then return slot,0,false end
            return slot,math.max(0,50+20*(myHero.levelData.lvl or 1)-(target.hpRegen or 0)*5),true
        end
    end
end
function D:castIgnite(target)
    local c=self.ctx
    if not c.config:get('comboIgnite') or not c:enemyValid(target) then return false end
    local slot,damage,verified=self:ignite(target)
    if not slot or not verified then return false end
    if c.config:get('igniteExecute') and damage<(target.health or 0)+(target.allShield or 0)+10 then return false end
    return c.actions:cast(slot,target,'fight',{urgent=true,interrupt=true,validate=function()
        local current,value,known=self:ignite(target,slot)
        return current==slot and known and c.config:get('comboIgnite') and c:enemyValid(target)
            and (not c.config:get('igniteExecute') or value>=U.typedHP(target,'true')+10),'ignite_no_longer_eligible'
    end})
end
function D:item(slot,target)
    local c=self.ctx;local item=myHero:GetItemData(slot);local id=item and item.itemID
    local rule=c.actives:rule(id)
    if not rule or not c.config:get(rule.group) or not c:ready(slot) or c.actions.pending[slot] then return nil end
    if rule.damage==false then return {damage=0,range=rule.range,type='physical',name=tostring(id)} end
    -- A mode-matched measured adapter can extend unknown item formulas. Its
    -- output is post-resistance damage, before shields; never an instruction to cast.
    local provider=_G.LHO_Damage
    if provider and provider.mode==c.profile.id and provider.item then
        local ok,value=pcall(provider.item,id,myHero,target)
        if ok and type(value)=='table' and value.verified==true and type(value.damage)=='number'
            and value.damage>=0 and value.damage<100000 and (value.type=='physical' or value.type=='magic' or value.type=='true') then
            return {damage=value.damage,type=value.type,range=rule.range,name=tostring(id)}
        end
    end
    local raw,dtype,kind
    if c.profile.id=='classic' and c.config:get('mechanicsVerified') then
        if id==773077 or id==773074 then raw=(myHero.totalDamage or 0)*.6;kind='physical'
        elseif id==773144 then raw=100;kind='magic'
        elseif id==773153 then raw=math.max(100,(target.maxHealth or 0)*.15);kind='magic' end
    end
    if raw then
        dtype=kind=='magic' and c.sdk.DAMAGE_TYPE_MAGICAL or c.sdk.DAMAGE_TYPE_PHYSICAL
        return {damage=c.sdk.Damage:CalculateDamage(myHero,target,dtype,raw),type=kind,range=rule.range,name=tostring(id)}
    end
    return {damage=0,range=rule.range,unknown=true,name=tostring(id)}
end
function D:estimate(target,maximum)
    local c=self.ctx;local cfg=c.config
    local out={damage=0,parts={},unknown={},maximum=maximum}
    if not c:enemyValid(target) then return out end
    local hp=target.health;local generic=target.allShield or 0
    local physical=target.shieldAD or 0;local magic=target.shieldAP or 0
    local energy=myHero.mana or 0;local elapsed=0;local distance=U.dist(myHero.pos,target.pos)
    local horizon=cfg:get('damageHorizon')
    local function add(name,damage,kind,time,cost)
        cost=cost or 0;time=time or 0
        if hp<=0 or cost>energy or elapsed+time>horizon then return false end
        energy=energy-cost;elapsed=elapsed+time
        hp=math.min(target.maxHealth or target.health,hp+math.max(0,target.hpRegen or 0)*time)
        damage=math.max(0,damage or 0)
        local remaining=damage
        if kind=='physical' then local use=math.min(physical,remaining);physical=physical-use;remaining=remaining-use
        elseif kind=='magic' then local use=math.min(magic,remaining);magic=magic-use;remaining=remaining-use end
        local use=math.min(generic,remaining);generic=generic-use;remaining=remaining-use
        hp=math.max(0,hp-remaining);out.parts[#out.parts+1]=name
        if hp==0 then out.lethal=true;if not out.aggregated then out.killTime=elapsed end end
        return true
    end
    local function ready(slot) return c:ready(slot) and not c.actions.pending[slot] end
    local function spellDamage(slot,stage,health)
        if maximum then return c:combatDamage(slot,target,stage,health) end
        return c:damage(slot,target,stage,health)
    end
    out.estimated=maximum and cfg:get('combatEstimates') and not cfg:get('mechanicsVerified') and not c.profile.damageVerified
    if not cfg:get('mechanicsVerified') then out.unknown[#out.unknown+1]='spell damage unverified' end
    local qMarked=c:stage(0)==2 and c:mark(target)~=nil
    local markUntil=qMarked and c:markLeft(target) or 0
    if maximum and cfg:get('damageQ') and cfg:get('comboQ') and c:stage(0)==1 and ready(0) then
        local p=c.spells:predict(target)
        if p and #c.spells:blockers(target,p)==0 then
            if add('Q1*',spellDamage(0,1),'physical',.25+distance/c.profile.qSpeed,c:spell(0).mana) then
                qMarked=true;markUntil=elapsed+3
            end
        end
    end
    local function q2()
        if maximum and cfg:get('damageQ') and cfg:get('comboQ') and qMarked and ready(0)
            and distance<=c.profile.q2Range and elapsed+.15<markUntil
            and not (cfg:get('q2Safety') and c:underTurret(target.pos)) then
            local cost=c:stage(0)==2 and c:spell(0).mana or 30
            if add('Q2*',spellDamage(0,2,math.min(target.maxHealth or target.health,hp+math.max(0,target.hpRegen or 0)*(.15+distance/1800))),'physical',.15+distance/1800,cost) then
                qMarked=false;distance=0;return true
            end
        end
    end
    -- In melee, reserve Q2 until after E/attacks/R to benefit from missing HP.
    -- At range, Q2 must be spent to reach E/R; never count both sequences.
    if distance>c.profile.rRange then q2() end
    if cfg:get('damageE') and cfg:get('comboE') and c:stage(2)==1 and ready(2) and distance<=c.profile.eRange then
        add('E1',spellDamage(2,1),'magic',.25,c:spell(2).mana)
    end
    if maximum and cfg:get('damageItems') and cfg:get('items') then
        for slot=6,11 do
            local item=self:item(slot,target)
            if item and distance<=item.range then
                if item.unknown then out.unknown[#out.unknown+1]='item '..item.name
                elseif item.damage>0 then add('Item '..item.name,item.damage,item.type,.05) end
            end
        end
    end
    if distance<=c:attackRange(target) then
        local cycle=c.sdk.Attack.GetAnimation and c.sdk.Attack:GetAnimation() or 1/math.max(.5,myHero.attackSpeed or 1)
        for i=1,maximum and cfg:get('damageAutos') or math.min(1,cfg:get('damageAutos')) do
            -- Plain attacks avoid repeatedly counting a one-use item proc.
            local damage=c.sdk.Damage:GetAutoAttackDamage(myHero,target,maximum and i==1)
            add('AA',damage,'physical',i==1 and c:windup() or cycle)
        end
    end
    if maximum and cfg:get('damageR') and cfg:get('comboR') and ready(3) and distance<=c.profile.rRange then
        if add('R',spellDamage(3,1),'physical',.5,c:spell(3).mana) then distance=distance+c.profile.kickDistance end
    end
    q2()
    if maximum and cfg:get('damageSummoners') and cfg:get('comboIgnite') then
        -- Cast-range eligibility uses the actual starting position, not an
        -- assumed second future gap-close after kicking the target away.
        local slot,damage,verified=self:ignite(target)
        if slot then
            if not verified then out.unknown[#out.unknown+1]='Ignite unverified'
            elseif hp>0 then out.aggregated=true;out.killTime=nil;add('Ignite (window)',(50+20*(myHero.levelData.lvl or 1))*math.min(1,horizon/5),'true',math.max(0,horizon-elapsed)) end
        end
    end
    if maximum and cfg:get('damageItems') then
        local conditional={[6692]=true,[6610]=true,[3153]=true,[3748]=true,[773153]=true,[773209]=true}
        for slot=6,11 do
            local item=myHero:GetItemData(slot)
            if item and conditional[item.itemID] then out.unknown[#out.unknown+1]='conditional/repeated item procs' end
        end
    end
    if maximum and cfg:get('damageSummoners') then
        for slot=4,5 do
            local name=U.name(c:spell(slot).name)
            if ready(slot) and (name:find('smiteavatar',1,true) or name=='s5summonersmiteplayerganker'
                or name=='s5summonersmiteduel' or name:find('snowball',1,true) or name=='summonermark') then
                out.unknown[#out.unknown+1]='champion summoner damage not modeled'
            end
        end
    end
    out.damage=math.max(0,target.health-hp)
    out.remainingHP=hp;out.partial=#out.unknown>0;out.elapsed=elapsed;out.energyLeft=energy
    return out
end
function D:both(target)
    local id=U.id(target) or target;local now=self.ctx:now();local cached=self.cache[id]
    if cached and now-cached.at<.1 and cached.health==target.health then return cached.safe,cached.max end
    local safe,max=self:estimate(target,false),self:estimate(target,true)
    -- Resource-using branches can exhaust the time/energy budget; the available
    -- conservative branch is always an alternative to that sequence.
    if max.damage<safe.damage then max.damage=safe.damage;max.parts=safe.parts;max.remainingHP=safe.remainingHP;max.lethal=safe.lethal;max.killTime=safe.killTime;max.aggregated=safe.aggregated;max.elapsed=safe.elapsed end
    self.cache[id]={at=now,health=target.health,safe=safe,max=max}
    return safe,max
end
return D
