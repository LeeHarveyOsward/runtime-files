local U=require('lho.util')
local R={}
-- Normalized aliases are explicit per profile; cosmetic values are presence
-- transitions only, never a remaining-attack count or standalone cast proof.
R.rules={
    normal={buffs={leesinpassivebuff=true,leesinpassive=true,leesinwtwo=true,leesinironwill=true}},
    classic={buffs={leesinpassivebuff=true,leesinpassivecosmetic=true,leesinwtwo=true,leesinironwill=true}}
}
local names={'leesinqtwo','leesinwtwo','leesinetwo'}
local function buffToken(c)
    local scope=U.buffScopeKey();local now=c:now();local cached=c.recastBuffCache
    if scope and cached and cached.scope==scope and cached.at==now then return cached.tokens end
    local out={};local aliases=R.rules[c.profile.id].buffs
    for _,b in ipairs(U.buffs(myHero)) do
        local name=U.name(b.name);local ends=U.buffEnd(b)
        if aliases[name] and (b.count==nil or b.count>0) and ends and ends>now and ends<=now+5 then
            out[name]=tostring(b.startTime or 0)..':'..tostring(ends)
        end
    end
    if scope then c.recastBuffCache={scope=scope,at=now,tokens=out} end
    return out
end
function R.snapshot(c,slot,sampledSpell,sampledStage)
    local d=sampledSpell or c:spell(slot);local now=c:now();local window=c.clear and c.clear.windows[slot]
    return {at=now,stage=sampledStage or c:stage(slot,nil,d),cd=d.currentCd or 0,mana=myHero.mana,cost=d.mana,
        window=window,buffs=buffToken(c),manual=c.manualSpellSerial or 0,name=d.name,
        origin=U.copy(myHero.pos)}
end
function R.evidence(c,slot,before,sentAt,manual,sampledAfter)
    if not before then return false,{reason='missing_before_sample'} end
    local now=c:now();local active=myHero.activeSpell
    local after=sampledAfter or R.snapshot(c,slot)
    local lower=sentAt or before.at
    local detail={sent=sentAt~=nil,window=before.window and before.window-lower,
        transition=after.stage~=before.stage or after.cd>before.cd+.05,
        resource=U.finite(before.mana) and U.finite(after.mana) and U.finite(before.cost) and before.cost>0
            and before.mana-after.mana>=math.max(1,before.cost*.8) or false}
    local physical=c.manualSpells and c.manualSpells[slot]
    local competing=sentAt and (c.manualSpellSerial or 0)>(before.manual or 0)
    if active and active.valid and U.name(active.name)==names[slot+1] and U.finite(active.startTime)
        and active.startTime>=lower and active.startTime<=now and now-active.startTime<.75 then
        detail.reason='active_spell';detail.at=active.startTime
        if not competing then return true,detail end
        detail.reason='manual_competition';return false,detail
    end
    detail.buff=false;detail.specificBuff=false
    for name,token in pairs(after.buffs) do
        if before.buffs[name]~=token then
            detail.buff=true
            -- Iron Will itself is evidence of W2. Net energy can stay flat or
            -- increase when passive attacks/refill occur across the input queue.
            -- A generic passive refresh alone cannot identify this spell.
            if slot==1 and (name=='leesinwtwo' or name=='leesinironwill') then detail.specificBuff=true end
        end
    end
    local path=myHero.pathing
    detail.dash=slot==0 and c:dash() and path and path.endPos and before.targetPos
        and U.dist(path.endPos,before.targetPos)<180 and U.dist(before.origin,path.endPos)>50 or false
    local requested=sentAt~=nil or manual and physical and physical.at>=before.at and physical.at<=now
    local timely=U.finite(lower) and now>=lower and now-lower<=.75
        and before.window and before.window>lower+.1 and now<before.window
    detail.reason=competing and 'manual_competition' or not requested and 'no_send_or_manual_input'
        or not timely and 'expired_or_unknown_recast_window' or not detail.transition and 'missing_stage_transition'
        or not detail.resource and not detail.dash and not detail.specificBuff and 'missing_specific_effect'
        or not detail.buff and not detail.dash and 'missing_new_buff_or_dash' or 'correlated_recast_effect'
    detail.at=now
    return not competing and requested and timely and detail.transition and (detail.resource or detail.dash or detail.specificBuff)
        and (detail.buff or detail.dash) or false,detail
end
return R
