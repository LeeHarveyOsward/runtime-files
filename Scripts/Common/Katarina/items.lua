local U=require('kata.util')
local I={};I.__index=I
-- Explicit scope: no stacking/periodic/rune damage is invented for unsupported effects.
-- Modern on-hit values below match the active Orbama item mechanics; provenance in docs.
local normal={
    [3115]={onhit='nashor'},[3153]={onhit='bork'},[3091]={onhit='wits'},[3124]={onhit='rage'},[3302]={onhit='rage'},
    [6672]={onhit='kraken',attackOnly=true},
    [3100]={onhit='lich',buff={lichbane=true}},[3057]={onhit='sheen',buff={sheen=true}},[3078]={onhit='trinity',buff={['3078trinityforce']=true}},
    [3157]={active='stasis',range=0},[3152]={active='move',range=275},[3146]={active='target',range=600,unknownDamage=true}}
local classic={
    [773157]={active='stasis',range=0},[773128]={active='amplify',range=750,maxHP=.15,amp=1.2},
    [773146]={active='target',range=600,unknownDamage=true},[773144]={active='target',range=450,raw=100},
    [773153]={active='target',range=450,maxHP=.15}}
local labels={[3157]="Zhonya's Hourglass",[773157]="Zhonya's Hourglass",[3152]='Hextech Rocketbelt',
    [3146]='Hextech Gunblade',[773146]='Hextech Gunblade',[773128]='Deathfire Grasp',
    [773144]='Bilgewater Cutlass',[773153]='Blade of the Ruined King'}
function I.new(c)return setmetatable({c=c,inventory={},catalog=c.profile.id=='classic'and classic or normal},I)end
function I:refresh()
    self.inventory={}
    for slot=6,12 do local item=self.c.hero:GetItemData(slot);if item and(item.itemID or 0)>0 then
        self.inventory[slot]={id=item.itemID,rule=self.catalog[item.itemID],data=item}
        if self.c.config.menu and self.catalog[item.itemID]and self.catalog[item.itemID].active then
            local key='item'..item.itemID
            if not self.c.config.nodes[key]then self.c.config.menu:MenuElement({id=key,name='Use '..labels[item.itemID],value=true});self.c.config.nodes[key]=self.c.config.menu[key]end
        end
    end end
end
function I:enabled(id)local v=self.c.config:get('item'..id);return v~=false end
function I:damage(rule,target)
    local raw=rule.raw or rule.maxHP and rule.maxHP*(target.maxHealth or 0)or 0
    if self.c.profile.id=='classic'and rule.active=='target'and rule.maxHP then raw=math.max(100,raw)end
    return self.c.damage:mitigate(target,'magic',raw)
end
function I:onhit(o,sim,trigger)
    local h=self.c.hero;local m,p=0,0;sim=sim or {};sim.procs=sim.procs or {}
    for _,item in pairs(self.inventory)do local r=item.rule
        if r and r.onhit and(not r.attackOnly or trigger=='AA')and(not r.buff or not sim.procs.spellblade and U.buff(h,r.buff,Game.Timer()))then
            local value=0
            if r.onhit=='nashor'then m=m+15+.15*(h.ap or 0)
            elseif r.onhit=='wits'then m=m+45
            elseif r.onhit=='rage'then m=m+30
            elseif r.onhit=='bork'then value=(sim.hp or o.health)*.09;if o.type~=h.type then value=math.min(100,value)end;p=p+value
            elseif r.onhit=='kraken'then
                local buff=U.buff(h,{['6672buff']=true},Game.Timer())
                if not sim.procs.kraken and buff and buff.count==2 then
                    local level=h.levelData.lvl;p=p+(150+math.max(0,level-8)*5)*(1+.75*(1-math.min(1,(sim.hp or o.health)/math.max(1,o.maxHealth))))
                    sim.procs.kraken=true
                end
            elseif r.onhit=='lich'then m=m+.75*(h.baseDamage or 0)+.4*(h.ap or 0)
            elseif r.onhit=='sheen'then p=p+(h.baseDamage or 0)
            elseif r.onhit=='trinity'then p=p+2*(h.baseDamage or 0)end
            if r.buff then sim.procs.spellblade=true end
        end
    end
    return m,p
end
function I:stasisNeeded()
    local c=self.c
    if not c.config:get('stasis')then return false end
    local hp=c.sdk.HealthPrediction or c.sdk.Health
    if hp and hp.GetIncoming and next(hp:GetIncoming(c.hero.handle))and c:healthPrediction(c.hero,.45)<=0 then return true end
    if U.hp(c.hero)>c.config:get('stasisHP')then return false end
    -- Require an attributable attack/cast targeting Katarina, not just nearby enemies.
    for _,o in ipairs(c.enemies)do
        local a=U.valid(o)and o.activeSpell
        if a and a.valid and(a.target==U.id(c.hero)or a.target==c.hero.handle)
            and(a.castEndTime or a.endTime or 0)>=Game.Timer()then return true end
    end
    return false
end
function I:activeCandidate(target,mode)
    for slot,item in pairs(self.inventory)do local r=item.rule
        if r and r.active and self:enabled(item.id)and self.c:ready(slot)then
            if r.active=='stasis'and self:stasisNeeded()then return {slot=slot,owner='defense',rule=r,itemID=item.id,release=true,priority='critical'}end
            if mode=='combo'and U.valid(target)and self.c.config:get('items')and not self.c.damage:protected(target)then
                if (r.active=='target'or r.active=='amplify')and U.dist(self.c.hero.pos,target.pos)<=r.range then
                    return {slot=slot,target=target,owner=mode,rule=r,itemID=item.id,score=r.active=='amplify'and 700 or 80}
                end
            end
        end
    end
end
return I
