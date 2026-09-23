-- Shared, input-free TF mechanics. Rank arrays start at rank ONE; rank zero is zero.
-- Source: research/twistedfate/manifest.json and spell-summary.json, 2026-09-20.
-- Installed assets are not a claim of server/live verification. Distances: world units;
-- durations: seconds; ratios: fractions. Costs/readiness come from live spell objects.
local M={revision='tf-mechanics-1', provenance={
    normal='2c65ae046e3924879008a1abb17563b00d292a06f84e75a191aa0c5009c8d0bf',
    classic='946645b5d7588a5e9a5fbe3626b1debf912cd3d302c9023b9cfc97de54d48461',
    scope='installed assets; patch and live behavior not independently established',
    reset='https://www.leagueoflegends.com/en-us/news/game-updates/patch-14-2-notes/'}}
local normal={id='normal',name='TwistedFate',qName='WildCards',wName='PickACard',
    eName='CardmasterStack',rName='Destiny',gateName='Gate',gateSlot=3,
    qBase={60,105,150,195,240},qAP=.85,qBonusAD=.5,
    q={range=1450,speed=1000,delay=.25,radius=40,angle=28*math.pi/180,
       geometryScope='range/speed/mMissileWidth=40: missile asset; delay/fan: historical scripts, pending measurement'},
    wAP={blue=1,red=.7,gold=.5},wMana={50,75,100,125,150},
    locks={blue='BlueCardLock',red='RedCardLock',gold='GoldCardLock'},
    held={blue='BlueCardPreAttack',red='RedCardPreAttack',gold='GoldCardPreAttack'},
    attacks={blue='BlueCardAttack',red='RedCardAttack',gold='GoldCardAttack'},
    eBuff='cardmasterstackparticle',eBase={65,90,115,140,165},eAP=.4,eBonusAD=.2,
    eAS={.15,.25,.35,.45,.55},towerE=.5,lockReset=true,
    channelW1=false,channelW2=false,liveVerified=false}
local classic={id='classic',name='Jade_TwistedFate',qName='Jade_TwistedFateWildCards',
    wName='Jade_TwistedFatePickACard',eName='Jade_TwistedFateE',rName='Jade_TwistedFateDestiny',
    gateName='Jade_TwistedFateE',gateSlot=2,qBase={60,110,160,210,260},qAP=.65,qBonusAD=0,
    q={range=1450,speed=1000,delay=.25,radius=40,angle=28*math.pi/180,
       geometryScope='range/speed/mMissileWidth=40: Classic missile asset; delay/fan: pending Classic measurement'},
    wAP={blue=.4,red=.4,gold=.4},wMana={50,75,100,125,150},
    locks={blue='Jade_TwistedFate_BlueCardLock',red='Jade_TwistedFate_RedCardLock',gold='Jade_TwistedFate_GoldCardLock'},
    held={blue='Jade_TwistedFate_BlueCardPreAttack',red='Jade_TwistedFate_RedCardPreAttack',gold='Jade_TwistedFate_GoldCardPreAttack'},
    attacks={blue='Jade_TwistedFate_BlueCardAttack',red='Jade_TwistedFate_RedCardAttack',gold='Jade_TwistedFate_GoldCardAttack'},
    gateDuration=3,gateWithR=1.5,rSlow=.30,rDuration={4,5,6},
    -- W2 during E is a guide hypothesis, never enabled by a menu or a timer.
    channelW1=false,channelW2=false,lockReset=false,autoRVerified=false,liveVerified=false}
M.profiles={TwistedFate=normal,Jade_TwistedFate=classic}
M.colors={'blue','red','gold'}
-- Normal base: Riot patch 26.1; Classic base/IE: pinned Riot item 773031 tooltip.
function M.CritMultiplier(p,items)
    local value=2
    for _,item in pairs(items or {})do
        if p.id=='normal' and item.itemID==3031 then value=2.3 end
        if p.id=='classic' and item.itemID==773031 then value=2.5 end
    end
    return value
end
-- Only explicit numeric effects from pinned Riot 16.17.1 item descriptions.
-- research/shop/en_US.json SHA256 cfc41c11dc27161a969469975386d386babc645278980bf3a06f251a541e881d
-- Missing tooltip placeholders and unobserved stacks are intentionally omitted.
M.itemRules={normal={
    [1043]={physical=15},[3124]={magical=30},
    [3042]={manaPhysical=.012,championsOnly=true},
    [3094]={magical=40,energized=true}},classic={
    [773091]={magical=42},[773153]={currentHealthPhysical=.05,minionCap=60}}}
function M.ItemAttack(p,stats,target,items,proc)
    local result={physical=0,magical=0,trueDamage=0};local seen={}
    for _,item in pairs(items or {})do
        local id=item.itemID;local row=M.itemRules[p.id][id]
        if row and not seen[id]then
            seen[id]=true
            if (not row.championsOnly or target.hero) and (not row.energized or proc and proc.energized)then
                local physical=(row.physical or 0)+(row.manaPhysical or 0)*(stats.maxMana or 0)
                if row.currentHealthPhysical then
                    local extra=(target.health or 0)*row.currentHealthPhysical
                    if target.minion then extra=math.min(extra,row.minionCap)end
                    physical=physical+extra
                end
                result.physical=result.physical+physical;result.magical=result.magical+(row.magical or 0)
            end
        end
    end
    return result
end
local base={blue={40,60,80,100,120},red={30,45,60,75,90},gold={15,22.5,30,37.5,45}}
local crit={blue=.575,red=.35,gold=.25}
function M.Profile(name) return M.profiles[name] end
function M.Rank(values,rank) return values and values[rank or 0] or 0 end
function M.Q(p,rank,stats)
    if not p or rank<1 or rank>5 then return 0 end
    return M.Rank(p.qBase,rank)+p.qAP*(stats.ap or 0)+p.qBonusAD*(stats.bonusDamage or 0)
end
-- Full replacement attack damage, NOT an addition to the physical base attack.
function M.Card(p,color,rank,stats)
    if not p or not base[color] or rank<1 or rank>5 then return 0 end
    return (base[color][rank]+(stats.totalDamage or 0)+p.wAP[color]*(stats.ap or 0))
        *(1+crit[color]*math.max(0,math.min(1,stats.critChance or 0)))
end
function M.E(p,rank,stats,tower)
    if not p or not p.eBase or rank<1 or rank>5 then return 0 end
    return (p.eBase[rank]+p.eAP*(stats.ap or 0)+p.eBonusAD*(stats.bonusDamage or 0))*(tower and p.towerE or 1)
end
function M.Expiry(buff)
    if not buff then return 0 end
    local at=buff.expireTime
    if not at or at<=0 then at=buff.endTime end
    return at or 0
end
function M.AliveBuff(buff,at)
    if not buff or buff.valid==false or (buff.count or 0)<=0 then return false end
    local expiry=M.Expiry(buff)
    return expiry==0 or expiry>at
end
function M.CardState(p,spellName,getBuff,at)
    for _,color in ipairs(M.colors)do
        local b=getBuff(p.held[color])
        if M.AliveBuff(b,at) then return 'held',color,M.Expiry(b) end
    end
    local name=string.lower(spellName or '')
    for _,color in ipairs(M.colors)do
        if name==string.lower(p.locks[color]) then return 'selecting',color,0 end
    end
    if name==string.lower(p.wName) then return 'idle',nil,0 end
    return 'unknown',nil,0
end
function M.Attack(p,stats,wrank,erank,color,eReady,tower,critMultiplier)
    local physical,magical=stats.totalDamage or 0,0
    if color and wrank>0 then physical=0;magical=M.Card(p,color,wrank,stats) end
    if not color and (stats.critChance or 0)>=1 then physical=physical*(critMultiplier or 2)end
    if eReady then magical=magical+M.E(p,erank,stats,tower) end
    return {physical=physical,magical=magical,trueDamage=0}
end
function M.BlueRecovery(p,rank,mana,maxMana)
    return math.max(0,math.min(M.Rank(p.wMana,rank),(maxMana or 0)-(mana or 0)))
end
function M.Stun(rank) return rank>0 and (.75+.25*rank) or 0 end
function M.LegalRank(slot,rank,level)
    if slot==3 then return rank<3 and level>=({6,11,16})[rank+1] end
    return rank<5 and level>=rank*2+1
end
return M
