return function(U)
local W={}
function W:itemReady(slot,item,owned)
    local c=self.ctx;item=item or myHero:GetItemData(slot)
    if not item or not c.profile.wards[item.itemID] then return false end
    local d=c:spell(slot)
    if (d.currentCd or 0)>0 or self.actions.pending[slot] and not owned then return false end
    if c.profile.wardInventoryCharges and c.profile.wardInventoryCharges[item.itemID]
        and U.finite(item.ammo) and item.ammo>=0 and item.ammo==0 then return false end
    if c:ready(slot) then return true end
    -- GG's item readiness uses currentCd. Classic Sightstone can expose zero
    -- spell ammo while its inventory has charges; do not let the summoner /
    -- spell-ammo readiness check veto that supported inventory representation.
    if c.profile.wardInventoryCharges and c.profile.wardInventoryCharges[item.itemID]
        or c.profile.id=='classic' and c.profile.wards[item.itemID]=='stack' then
        return d.currentCd==0 and math.max(d.ammo or 0,item.ammo or 0,U.stackCount(item))>0 and (owned or not self.actions.pending[slot])
    end
    return false
end
function W:hasCharges(slot,item)
    local c=self.ctx;item=item or myHero:GetItemData(slot)
    local kind=item and c.profile.wards[item.itemID];if not kind then return false end
    local charge=c:spell(slot).ammo
    if c.profile.wardInventoryCharges and c.profile.wardInventoryCharges[item.itemID]then
        charge=U.finite(item.ammo)and item.ammo>=0 and item.ammo or math.max(charge or 0,U.stackCount(item))
    elseif charge==nil or charge<0 then
        charge=item.ammo
        if(charge==nil or charge<0)and kind~='stored'then charge=item.stackCount end
    end
    local count=math.max(U.stackCount(item),item.ammo or 0)
    return kind=='cooldown'or((kind=='charge'or kind=='stored')and charge and charge>0)
        or(kind=='stack'and(count>0 or charge and charge>0))or false
end
function W:slot(itemID)
    local c=self.ctx;local best,bestRank=nil,math.huge
    for slot=6,12 do
        local item=myHero:GetItemData(slot);local kind=item and c.profile.wards[item.itemID]
        if kind and (not itemID or item.itemID==itemID) and self:itemReady(slot,item) then
            local available=self:hasCharges(slot,item)
            if available then
                -- Resource preference is independent of the inventory slot and
                -- of how the item reports readiness / charges.
                local rank=item.itemID==c.profile.yellowWard and 1 or kind=='charge' and 2
                    or kind=='cooldown' and 3 or 4
                if c.profile.id=='classic' and kind=='stack' then rank=item.itemID==772043 and 5 or 4 end
                if rank<bestRank then best,bestRank=slot,rank end
            end
        end
    end
    return best
end

return W
end
