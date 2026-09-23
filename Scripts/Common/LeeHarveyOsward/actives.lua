local U=require('lho.util')
local I={};I.__index=I
-- Explicit active mechanics from Riot 16.17.1. Passive-only items are absent.
local normal={
    [3077]={range=400,group='itemCleave'},[3074]={range=400,group='itemCleave'},
    [3748]={range=300,group='itemCleave',reset=true},[6698]={range=400,group='itemCleave'},
    [6631]={range=400,group='itemCleave'},[3143]={range=500,group='itemSlow',damage=false,champion=true},
    [3142]={range=700,group='itemSpeed',damage=false,champion=true},
    [2065]={range=700,group='itemSpeed',damage=false,champion=true},
    [3146]={range=600,group='itemTargeted',targeted=true,champion=true},
    [3140]={range=0,group='itemCleanse',damage=false,cleanse=true},[3139]={range=0,group='itemCleanse',damage=false,cleanse=true},
    [3190]={range=600,group='itemShield',damage=false,shield=true}}
local classic={
    [773077]={range=400,group='itemCleave'},[773074]={range=400,group='itemCleave'},
    [773143]={range=500,group='itemSlow',damage=false,champion=true},
    [773144]={range=450,group='itemTargeted',targeted=true,champion=true},
    [773153]={range=450,group='itemTargeted',targeted=true,champion=true},
    [773146]={range=600,group='itemTargeted',targeted=true,champion=true},
    [773142]={range=600,group='itemSpeed',damage=false,attackSpeed=true},
    [773069]={range=700,group='itemSpeed',damage=false,champion=true},
    [773140]={range=0,group='itemCleanse',damage=false,cleanse=true},[773139]={range=0,group='itemCleanse',damage=false,cleanse=true},
    [773190]={range=600,group='itemShield',damage=false,shield=true}}
local potions={normal={[2003]={heal=120,duration=15},[2031]={heal=100,duration=12,charge=true},[2033]={heal=100,duration=12,charge=true}},
    classic={[772003]={heal=150,duration=15},[773521]={heal=150,duration=15},[772041]={heal=120,duration=12,charge=true}}}
local healing={regenerationpotion=true,healthpotion=true,item2003=true,itemcrystalflask=true,
    itemminiregenpotion=true,itemdarkcrystalflask=true,crystalflask=true}
local cleanseTypes={[5]=true,[7]=true,[8]=true,[9]=true,[10]=true,[12]=true,[22]=true,[23]=true,[25]=true,[26]=true,[29]=true,[35]=true}
function I.new(ctx,actions) return setmetatable({ctx=ctx,actions=actions},I) end
function I:rule(id) return (self.ctx.profile.id=='classic' and classic or normal)[id] end
function I:potionAllowed(slot,owner,owned)
    local c=self.ctx;local now=c:now()
    local enabled=owner=='farm' and c.config:get('potionAuto') or owner=='clear' and c.config:get('potionJungle') or owner=='fight' and c.config:get('potionFight')
    if not c.config:get('potions') or not enabled or c:blocked() or c:recalling() or c:dash()
        or (c.farm and c.farm:spawn() and U.dist(myHero.pos,c.farm:spawn())<550) or U.hp(myHero)>c.config:get('potionHP') or U.buff(myHero,healing,now)
        or not owned and now<(self.potionUntil or 0) then return false end
    local item=myHero:GetItemData(slot);local rule=item and potions[c.profile.id][item.itemID]
    if not rule or myHero.maxHealth-myHero.health<rule.heal*.8 then return false end
    local spell=c:spell(slot)
    local count=rule.charge and math.max(spell.ammo or 0,item.ammo or 0,c.profile.id=='classic' and U.stackCount(item) or 0) or U.stackCount(item)
    return count>0 and c:ready(slot),rule
end
function I:potions(owner)
    if self.potionRequest then
        local pending=self.potionRequest;local r=self.actions:inputAction(pending.event.cursorID)
        if r and r.sentAt then
            self.potionUntil=self.ctx:now()-math.max(0,self.actions:inputNow()-r.sentAt)*.001+pending.duration
            self.potionRequest=nil
        elseif pending.event.gameplayCancelled or r and r.state=='cancelled_before_send' then self.potionRequest=nil
        else return false end
    end
    for slot=6,11 do
        local allowed,rule=self:potionAllowed(slot,owner)
        if allowed then
            local accepted,event=self.actions:cast(slot,nil,owner,{validate=function()
                -- Our provisional potion lock belongs to this request only.
                local ok=self:potionAllowed(slot,owner,true);return ok,'potion_no_longer_needed'
            end})
            if accepted then
                if self.actions.api then self.potionRequest={event=event,duration=rule.duration}
                else self.potionUntil=self.ctx:now()+rule.duration end
                return true
            end
        end
    end
    return false
end
function I:needsCleanse()
    if self.ctx.actions.originalGG then return false end -- GG owns QSS; no claim/cancel API.
    local found=false;local now=self.ctx:now()
    for _,b in ipairs(U.buffs(myHero)) do
        if (U.buffEnd(b) or now+1)>now+.15 then
            if b.type==30 or b.type==31 then return false end
            if cleanseTypes[b.type] then found=true end
        end
    end
    return found
end
function I:needsShield(range)
    local c=self.ctx
    for _,list in ipairs({{myHero},c.allies or {}}) do for _,ally in ipairs(list) do
        if U.valid(ally) and U.dist(myHero.pos,ally.pos)<=range and U.hp(ally)<=c.config:get('shieldHP')
            and c:threats(ally.pos,700)>0 then return true end
    end end
    return false
end
function I:defenseAllowed(slot)
    local c=self.ctx;local item=myHero:GetItemData(slot);local rule=item and self:rule(item.itemID)
    if not c.config:get('items') or not c.config:get('idleDefense') or not rule or not c.config:get(rule.group) then return false end
    if rule.cleanse and self.actions.capabilities and self.actions.capabilities.automationClaims then
        self.actions:syncAutomation()
        if not self.actions.qssClaim then return false end
    end
    return rule.cleanse and self:needsCleanse() or rule.shield and self:needsShield(rule.range)
        or rule.group=='itemSlow' and U.hp(myHero)<=c.config:get('shieldHP') and c:threats(myHero.pos,rule.range)>0
end
function I:defense(owner)
    for slot=6,11 do
        if self:defenseAllowed(slot) and self.actions:cast(slot,nil,owner or 'defense',{interrupt=true,
            validate=function()return self:defenseAllowed(slot),'defense_no_longer_needed' end}) then return true end
    end
    return false
end
function I:itemAllowed(slot,target)
    local c=self.ctx
    if not c.config:get('items') or not U.valid(target) or c:dash() or c.sdk.Orbwalker:IsAutoAttacking() then return false end
    local champion=target.team~=300 and target.team~=myHero.team and target.type==myHero.type
    local item=myHero:GetItemData(slot);local rule=item and self:rule(item.itemID)
    if not rule or not c.config:get(rule.group) or rule.cleanse or rule.shield or rule.champion and not champion
        or U.dist(myHero.pos,target.pos)>rule.range then return false end
    local useful=true
    if rule.reset then useful=c.lastAttackFinished and c:now()-c.lastAttackFinished<.3 and U.dist(myHero.pos,target.pos)<=c:attackRange(target) end
    if rule.group=='itemSpeed' then useful=rule.attackSpeed and (champion or target.health>c:aaDamage(target)*4)
        or champion and U.dist(myHero.pos,target.pos)>c:attackRange(target)+50 end
    return useful,rule
end
function I:tick(target,owner)
    for slot=6,11 do
        local useful,rule=self:itemAllowed(slot,target)
        if useful and self.actions:cast(slot,rule.targeted and target or nil,owner,{intendedTarget=target,
            validate=function()return self:itemAllowed(slot,target) end}) then return true end
    end
    return false
end
return I
