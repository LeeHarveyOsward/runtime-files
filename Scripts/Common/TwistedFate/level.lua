local P=require('CombatProfiles.twisted_fate')
local ItemStats=require('tf.itemstats')
local L={};L.__index=L
function L.new(c)return setmetatable({c=c,bins={},lastSample=-1},L)end
function L:sample(mode,model)
    local now=math.floor(Game.Timer());if now==self.lastSample then return end;self.lastSample=now
    local slot=now%60+1
    local stats={ap=0,bonusDamage=0,totalDamage=self.c.hero.baseDamage or 0,attackSpeed=0}
    for _,item in pairs(self.c.state.inventory.slots)do
        local row=ItemStats[item.itemID]
        if not row then self.reason='unknown_permanent_item_stats';return end
        stats.ap=stats.ap+row.ap;stats.bonusDamage=stats.bonusDamage+row.ad;stats.attackSpeed=stats.attackSpeed+row['as']
    end
    stats.totalDamage=stats.totalDamage+stats.bonusDamage
    self.permanent=stats
    self.bins[slot]={at=now,attacks=model.attack and 3/math.max(.1,model.period) or 0,q=model.q and 1 or 0,
        control=(model.controlValue or 0)>0 and 1 or 0,mana=self.c.hero.mana/math.max(1,self.c.hero.maxMana),
        -- Base AD is permanent; transient AS/AP buffs never determine rank choice.
        baseAD=self.c.hero.baseDamage or 0}
end
function L.choose(p,ranks,level,history)
    if P.LegalRank(3,ranks[3],level)then return 3,'ultimate_rank'end
    if ranks[0]+ranks[1]+ranks[2]==0 then return 1,'first_card'end
    if not history or history.n==0 then return nil,'awaiting_representative_play'end
    local scores={};local stats=history.stats or {}
    for slot=0,2 do if P.LegalRank(slot,ranks[slot],level)then
        if slot==0 then scores[slot]=(P.Q(p,ranks[slot]+1,stats)-P.Q(p,ranks[slot],stats))*history.q
        elseif slot==1 then
            scores[slot]=(P.Card(p,'blue',ranks[slot]+1,stats)-P.Card(p,'blue',ranks[slot],stats))*history.attacks/4
                +history.control*25+math.max(0,1-history.mana)*25
        elseif p.eBase then
            scores[slot]=(P.E(p,ranks[slot]+1,stats)-P.E(p,ranks[slot],stats))*history.attacks/4
                +(P.Rank(p.eAS,ranks[slot]+1)-P.Rank(p.eAS,ranks[slot]))*history.baseAD*history.attacks
        else scores[slot]=(history.teleports or 0)*(ranks[slot]==0 and 100 or 15)end
    end end
    local best,value,second=nil,-1,-1
    for slot=0,2 do if scores[slot]then
        if scores[slot]>value then second=value;best=slot;value=scores[slot]else second=math.max(second,scores[slot])end
    end end
    if value<=0 or value-second<1 then return nil,'rank_utility_ambiguous'end
    return best,'observed_marginal_utility'
end
function L:tick()
    local c=self.c;local h=c.hero;local s=c.state
    if not c.config:get('level') or s.channeling or s:windupActive() or not h.levelData or (h.levelData.lvlPts or 0)<=0 then return end
    local r={};for slot=0,3 do r[slot]=h:GetSpellData(slot).level end
    local hist={n=0,q=0,attacks=0,control=0,mana=0,baseAD=0,teleports=0,stats=self.permanent}
    for _,at in ipairs(self.teleports or {})do if Game.Timer()-at<60 then hist.teleports=hist.teleports+1 end end
    for _,b in pairs(self.bins)do if Game.Timer()-b.at<60 then
        hist.n=hist.n+1;for _,k in ipairs({'q','attacks','control','mana','baseAD'})do hist[k]=hist[k]+b[k]end
    end end
    if hist.n>0 then for _,k in ipairs({'q','attacks','control','mana','baseAD'})do hist[k]=hist[k]/hist.n end end
    local slot,reason=L.choose(c.profile,r,h.levelData.lvl,hist);self.reason=reason
    if slot==nil then return end
    local rank=r[slot];local points=h.levelData.lvlPts
    c.actions:submit(slot,{owner='level',priority='background',type='chord',keys={HK_LUS or 17,({[0]=HK_Q,[1]=HK_W,[2]=HK_E,[3]=HK_R})[slot]},
        expires=c.actions.client:Now()+200,
        mechanical=function()
            return c.config:get('level') and h.levelData.lvlPts>0 and h:GetSpellData(slot).level==rank
                and P.LegalRank(slot,rank,h.levelData.lvl) and not s:channel() and not s:windupActive()
        end},function()return h:GetSpellData(slot).level>rank and h.levelData.lvlPts<points end)
end
return L
