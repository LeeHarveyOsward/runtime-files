-- Classic values retained from the pinned GG/Jade profile, not modern SR.
local P={buff='Jade_VayneW_Debuff'}
local function multiplicity(value)
    return (value==1 or value==2) and value or 0
end
function P.Stacks(buff,at,source)
    if not buff or (buff.count or 0)<=0 then return 0 end
    local expires=buff.expireTime
    if not expires or expires<=0 then expires=buff.endTime end
    if expires and expires>0 and expires<=at then return 0 end
    local owner=buff.source
    if source and owner and owner~=0 then
        if type(owner)=='number' then
            if owner~=source.handle and owner~=source.networkID then return 0 end
        elseif (type(owner)=='table' or type(owner)=='userdata') and owner.networkID and owner.networkID~=source.networkID then return 0 end
    end
    -- Hosts expose stack multiplicity in either field. Count can be only the
    -- active-buff flag; never infer an extra hit from an issued attack command.
    -- Live Classic can expose count=2 alongside stacks=9. Validate each field
    -- independently so an unrelated/invalid value cannot erase a valid mark.
    return math.max(multiplicity(buff.count),multiplicity(buff.stacks))
end
function P.Damage(source,target)
    local spell=source:GetSpellData(1);local rank=spell and spell.level or 0
    if rank<1 or rank>5 or not target or not target.maxHealth then return 0 end
    local damage=10+10*rank+(0.03+0.01*rank)*target.maxHealth
    return target.team==300 and math.min(damage,200) or damage
end
-- Short, bounded planning horizon. Existing item/on-hit damage is supplied by
-- the SDK. This is an estimate, not a promise about future health or movement.
function P.AttacksToKill(health,base,stacks,proc)
    if base<=0 then return math.huge end
    for n=1,6 do
        health=health-base
        stacks=stacks+1
        if stacks==3 then health=health-proc;stacks=0 end
        if health<=0 then return n end
    end
    return math.huge
end
return P
