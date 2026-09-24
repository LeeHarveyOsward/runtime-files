local U=require('tf.util')
local P=require('CombatProfiles.twisted_fate')
local E={};E.__index=E
-- Exact mode IDs; intentionally no arithmetic Jade aliases. Active eligibility
-- follows the workspace's dated Riot 16.17.1 extraction (lho.actives). Passive
-- damage needs separate proc/charge/cooldown evidence and is not inferred here.
local active={normal={
    [3140]={kind='qss'},[3139]={kind='qss'},[3157]={kind='stasis'},
    [3190]={kind='shield'},[3143]={kind='slow',range=500},
    [3142]={kind='speed',range=700},[2065]={kind='speed',range=700},
    [3146]={kind='target',range=600,slow=.25,duration=1.5}},classic={
    [773140]={kind='qss'},[773139]={kind='qss'},[773157]={kind='stasis'},
    [773190]={kind='shield'},[773143]={kind='slow',range=500},
    [773142]={kind='speed',range=600},[773069]={kind='speed',range=700},
    [773144]={kind='target',range=450},[773153]={kind='target',range=450,slow=.30,duration=3},[773146]={kind='target',range=600,slow=.40,duration=2}}}
E.coverage={
    cardCrit={status='supported',scope='asset coefficient times live crit chance; no random crit assumption'},
    stackedDeck={status='supported',scope='normal only; observed ready buff, target tower factor'},
    spellblade={status='unresolved',reason='mode-specific trigger, ICD and target rules require extracted item data'},
    onHit={status='unresolved',reason='SDK aggregate is not a typed, reusable proc model'},
    energized={status='unresolved',reason='charges and consumed range extension require host verification'},
    splash={status='unresolved',reason='splash must not be added to primary target twice'},
    chain={status='unresolved',reason='secondary victim and proc ICD unknown'},
    spellEffects={status='unresolved',reason='trigger and duration not profiled'},
    shopping={status='inapplicable',reason='explicitly outside controller scope'}}
local splashIDs={[3074]=true,[3085]=true,[3087]=true,[3748]=true,[773074]=true}
local cleanseTypes={[5]=true,[7]=true,[8]=true,[9]=true,[10]=true,[12]=true,[22]=true,[23]=true,[26]=true,[29]=true,[35]=true}
function E.new(c)return setmetatable({c=c,claims={}},E)end
function E:hasUnknownSplash()
    for _,row in pairs(self.c.state.inventory.slots)do if splashIDs[row.itemID]then return true end end
    return false
end
function E:cc(qss)
    local found=false;local air=false
    U.buffs(self.c.hero,function(b)
        if P.AliveBuff(b,Game.Timer()) and P.Expiry(b)>Game.Timer()+.15 then
            if b.type==30 or b.type==31 then air=true end
            if cleanseTypes[b.type] or qss and b.type==25 then found=true end
        end
    end)
    return found and not air
end
function E:threat()
    local c=self.c
    for _,u in ipairs(c.state.heroes)do
        if u.team~=c.hero.team and U.target(u) and U.dist(c.hero,u)<800 then
            local a=u.activeSpell
            if a and a.valid and (a.target==c.hero.handle or a.target==c.hero.networkID) then return true end
            if U.dist(c.hero,u)<(u.range or 125)+150 then return true end
        end
    end
    return false
end
function E:claimsUpdate()
    local c=self.c;local wanted=c.config:get('defense') and c.config:get('enabled') and c.active
    for _,name in ipairs({'qss','cleanse'})do
        if wanted and not self.claims[name]then self.claims[name]=c.actions.client:Claim(name,true)==true
        elseif not wanted and self.claims[name]then c.actions.client:Claim(name,false);self.claims[name]=nil end
    end
end
function E:allowedItem(slot,row,target)
    local c=self.c;local item=c.hero:GetItemData(slot)
    if not item or item.itemID~=row.id or not c.state:ready(slot)then return false end
    local low=c.hero.health/math.max(1,c.hero.maxHealth)<.25
    if row.kind=='qss'then return c.config:get('defense') and self.claims.qss and self:cc(true)end
    if row.kind=='stasis'then return c.config:get('defense') and c.hero.health/c.hero.maxHealth<.15 and self:threat()end
    if row.kind=='shield'then return c.config:get('defense') and low and self:threat()end
    if not c.config:get('offense') or not U.target(target)then return false end
    local mode=U.mode(c.sdk)
    if mode~='COMBO' and mode~='HARASS'then return false end
    if U.dist(c.hero,target)>row.range or c.state:windupActive()then return false end
    if row.kind=='speed'then return U.dist(c.hero,target)>c.sdk.Data:GetAutoAttackRange(c.hero,target)end
    return not c.state:protection(target).invulnerable
end
function E:tick()
    local c=self.c;self:claimsUpdate()
    local target
    -- Stable inventory slot order, defensive candidates before offensive candidates.
    for pass=1,1 do for slot=6,12 do
        local item=c.state.inventory.slots[slot];local rule=item and active[c.profile.id][item.itemID]
        if rule then
            local row=U.copy(rule);row.id=item.itemID
            local defensive=row.kind=='qss' or row.kind=='shield' or row.kind=='stasis'
            if (pass==1)==defensive and self:allowedItem(slot,row,target)then
                return c.actions:submit(slot,{owner='item',priority=defensive and 'critical' or 'normal',
                    keys={_G['HK_ITEM_'..(slot-5)]},kind=row.kind=='target' and 'object' or 'none',
                    target=row.kind=='target' and target or nil,targetID=row.kind=='target' and U.id(target) or nil,
                    mechanical=function()return self:allowedItem(slot,row,target)end})
            end
        end
    end end
    for slot=4,5 do
        local name=U.lower(c.hero:GetSpellData(slot).name)
        if c.state:ready(slot)then
            local function useful()
                if U.lower(c.hero:GetSpellData(slot).name)~=name or not c.state:ready(slot)then return false end
                if name=='summonerboost'then return c.config:get('defense') and self.claims.cleanse and self:cc(false)end
                if name=='summonerheal' or name=='summonerbarrier'then
                    return c.config:get('defense') and c.hero.health/c.hero.maxHealth<.25 and self:threat()
                end
                local mode=U.mode(c.sdk)
                if name=='summonerhaste' and c.config:get('ghost') and (mode=='COMBO' or mode=='FLEE')then
                    target=c.combat:target(800);return U.target(target)
                end
                if not c.config:get('offense') or (mode~='COMBO' and mode~='HARASS') or not U.target(target)then return false end
                -- Offensive targeted summoners are evaluated by the combat search.
                -- Ignite's host tooltip is not a reliable typed damage contract;
                -- until profiled, no invented damage threshold can authorize it.
                return false
            end
            if useful()then
                return c.actions:submit(slot,{owner='summoner',priority='critical',kind=name=='summonerexhaust' and 'object' or 'none',
                    target=name=='summonerexhaust' and target or nil,targetID=name=='summonerexhaust' and U.id(target) or nil,
                    mechanical=useful})
            end
        end
    end
end
function E:candidates(target)
    local c=self.c;local rows={};local protection=c.state:protection(target)
    if protection.invulnerable or protection.immune or protection.spellShield then return rows end
    for slot=6,12 do
        local item=c.state.inventory.slots[slot];local rule=item and active[c.profile.id][item.itemID]
        if rule and rule.slow then
            local row=U.copy(rule);row.id=item.itemID
            if self:allowedItem(slot,row,target) and protection.cc<row.duration then
                rows[#rows+1]={id=slot,slot=slot,row=row,cost=0,delay=.05,castTime=.05,
                    control=(row.duration-protection.cc)*row.slow,opportunityCost=15,packet={}}
            end
        end
    end
    if c.profile.autoRVerified and c.config:get('classicR') and c.state:ready(3)
        and c.hero.mana>=c.state:cost(3)+c.state:reserve(3)
        and (c.state.mode=='COMBO' or c.state.mode=='FLEE') and U.dist(c.hero,target)<1000 then
        rows[#rows+1]={id=3,slot=3,cost=c.state:cost(3),delay=.25,castTime=.25,
            control=math.max(0,P.Rank(c.profile.rDuration,c.state.spells[3].level)-protection.cc)*c.profile.rSlow,
            opportunityCost=50,packet={}}
    end
    if c.config:get('offense') and (c.state.mode=='COMBO' or c.state.mode=='HARASS') and self:threat()then
        for slot=4,5 do
            local spell=c.hero:GetSpellData(slot)
            local range=(spell.range or 0)>0 and spell.range or c.profile.id=='normal' and 650 or 0
            if U.lower(spell.name)=='summonerexhaust' and c.state:ready(slot) and U.dist(c.hero,target)<=range then
                -- Utility budget, not a claim about exact slow duration or damage reduction.
                rows[#rows+1]={id=slot,slot=slot,cost=0,delay=.05,castTime=.05,control=.5,opportunityCost=100,packet={}}
            end
        end
    end
    return rows
end
function E:execute(slot,target,mode)
    local c=self.c;local chosen
    for _,row in ipairs(self:candidates(target))do if row.slot==slot then chosen=row;break end end
    if not chosen then return false end
    local targetID=U.id(target)
    return c.actions:submit(slot,{owner='planned_active',priority='normal',context={modes={mode}},
        keys={slot==3 and HK_R or slot==4 and HK_SUMMONER_1 or slot==5 and HK_SUMMONER_2 or _G['HK_ITEM_'..(slot-5)]},
        kind=slot==3 and 'none' or 'object',target=slot~=3 and target or nil,targetID=targetID,
        mechanical=function()
            if U.id(target)~=targetID or not U.target(target)then return false end
            for _,row in ipairs(self:candidates(target))do if row.slot==slot then return true end end
            return false
        end})
end
return E
