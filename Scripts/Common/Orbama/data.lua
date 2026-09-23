-- Shared identities with explicit refresh age. Lists are caller-owned; host objects remain live.
return function(game,clock,item,hero,attack)
    local data={version=1,rows={},cycle=0}
    local kinds={heroes='Hero',minions='Minion',wards='Ward',turrets='Turret',camps='Camp'}
    function data:Prepare()
        self.cycle=self.cycle+1
        for kind,name in pairs(kinds) do
            local count,get=game[name..'Count'],game[name]
            if count and get then
                local n=math.max(0,math.min(kind=='minions' and 4096 or 512,count()))
                local row=self.rows[kind]
                if not row or n~=row.count or clock()-row.at>=80 then
                    row={at=clock(),count=n,objects={}}
                    for i=1,n do local obj=get(i);if obj then row.objects[#row.objects+1]=obj end end
                    self.rows[kind]=row
                end
            end
        end
    end
    function data:GetObjects(kind)
        local r=self.rows[kind];if not r then return nil,'unavailable' end
        local list={};for i,obj in ipairs(r.objects) do list[i]=obj end
        return {objects=list,refreshedAt=r.at,ageMs=math.max(0,clock()-r.at),cycle=self.cycle,identityOnly=true}
    end
    function data:GetInventory()
        local r=item:GetSnapshot(hero);local slots={}
        for slot,entry in pairs(r.slots) do local row={};for k,v in pairs(entry) do row[k]=v end;slots[slot]=row end
        return {slots=slots,refreshedAt=r.at,ageMs=math.max(0,clock()-(r.at or clock())),cycle=self.cycle}
    end
    function data:GetAttack()
        return {castEndTime=attack.CastEndTime,timebase='Game.Timer seconds',observedAt=clock()}
    end
    return data
end
