-- Identity comes from host hero objects. Static combat metadata is deliberately
-- incomplete and must never act as an allowlist for roster events or menus.
return function(Data,heroType)
    local priorities={}
    for name,row in pairs(Data.HEROES) do priorities[name:lower()]=row[1] end
    function Data:GetHeroPriority(name)
        if type(name)~='string' then return 5 end
        local exact=self.HEROES[name]
        if exact then return exact[1] end
        local key=name:lower()
        -- Reuse a UI default only. Do not inherit modern attack timings, damage,
        -- passive handlers or reset data for an unverified Classic champion.
        return priorities[key] or (key:sub(1,5)=='jade_' and priorities[key:sub(6)]) or 5
    end
    function Data:GetHeroData(obj)
        if not obj or obj.type~=heroType then return {} end
        local id,name,team=obj.networkID,obj.charName,obj.team
        if type(id)~='number' or id~=id or id<=0 or id==math.huge
            or type(name)~='string' or name=='' then return {} end
        if team~=100 and team~=200 then return {} end
        local enemy,ally=obj.isEnemy,obj.isAlly
        if type(enemy)~='boolean' or type(ally)~='boolean' or enemy==ally then return {} end
        -- Visibility, death and targetability are transient combat conditions;
        -- they must not prevent a roster entry or erase the user's priority.
        return {valid=true,isEnemy=enemy,isAlly=ally,networkID=id,charName=name,team=team,unit=obj}
    end
end
