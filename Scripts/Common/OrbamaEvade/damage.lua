-- Forecasts consume identified effects, never generic getdmg(slot) guesses.
local G=require('evade.geometry')
local D={}
function D.resistance(value,percent,flat)
    if not G.finite(value)then return nil end
    if value<0 then return 2-100/(100-value)end
    return 100/(100+math.max(0,value*(1-(percent or 0))-(flat or 0)))
end
function D.amount(effect,stats)
    if not effect or not G.finite(effect.raw)or effect.raw<0 then return nil,'damage_unknown'end
    if effect.kind=='true' then return effect.raw end
    local resist=effect.kind=='physical'and stats.armor or effect.kind=='magical'and stats.magicResist
    if resist==nil then return nil,'damage_type_unknown'end
    local scale=D.resistance(resist,effect.percentPen,effect.flatPen)
    return scale and effect.raw*scale*(stats.damageMultiplier or 1)or nil
end
function D.forecast(hits,stats,defense)
    local health=stats.health;local general=stats.shield or 0;local physical=stats.physicalShield or 0;local magic=stats.magicShield or 0
    local result={damage=0,cc=0,unknown=false,lethal=false,hits={},health=health}
    if not G.finite(health)then result.unknown=true;return result end
    local ordered={};for _,h in ipairs(hits)do ordered[#ordered+1]=h end
    table.sort(ordered,function(a,b)return a.at<b.at or a.at==b.at and tostring(a.id)<tostring(b.id)end)
    local seen={};local spellShield=stats.spellShieldCharges or 0
    for _,h in ipairs(ordered)do
        local id=h.damageID or h.id
        if not seen[id] and not h.alreadyApplied and not h.externalCounted then
            seen[id]=true;local blocked=false
            if stats.invulnerableUntil and h.at<=stats.invulnerableUntil then blocked=true end
            if defense and h.at>=defense.starts and h.at<=defense.ends then
                if defense.kind=='invulnerable' or defense.kind=='stasis'then blocked=true end
                if defense.kind=='spellShield'and h.blockable and not defense.consumed then blocked=true;defense={kind='spent',starts=0,ends=0}end
            end
            if not blocked and spellShield>0 and h.blockable then spellShield=spellShield-1;blocked=true end
            if not blocked then
                local amount=D.amount(h.damage,stats)
                if amount==nil then result.unknown=true else
                    local typed=h.damage.kind=='physical'and physical or h.damage.kind=='magical'and magic or 0
                    local used=math.min(typed,amount);amount=amount-used
                    if h.damage.kind=='physical'then physical=physical-used elseif h.damage.kind=='magical'then magic=magic-used end
                    used=math.min(general,amount);general=general-used;amount=amount-used
                    result.damage=result.damage+amount;health=health-amount
                end
                result.cc=result.cc+(h.cc or 0);result.hits[#result.hits+1]=h.id
            end
            if health<=0 then result.lethal=true;break end
        end
    end
    result.health=health;return result
end
return D
