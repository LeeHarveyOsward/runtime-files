local G=require('evade.geometry')
local O={};O.__index=O
function O.new(g,threats,catalog)
    return setmetatable({g=g,threats=threats,catalog=catalog,heroes={},loaded={},seen={},unknown={},nextRoster=0,maxMissiles=1024},O)
end
function O:Roster(now)
    if now<self.nextRoster then return end;self.nextRoster=now+.5
    local game=self.g.Game
    for i=1,math.min(game.HeroCount(),64)do
        local h=game.Hero(i)
        if h and h.charName and h.team~=self.g.myHero.team then
            local f=self.catalog[h.charName]
            if f and not self.loaded[h.charName]then self.loaded[h.charName]=f()end
            if h.networkID then self.heroes[h.networkID]=h end
            if h.handle then self.heroes[h.handle]=h end
        end
    end
end
function O:Tick(now)
    self:Roster(now);local game=self.g.Game;self.hostCalls=0
    if type(game.MissileCount)~='function'or type(game.Missile)~='function'then return false,'missile_api_missing'end
    local count=game.MissileCount();self.hostCalls=1
    if count>self.maxMissiles then self.threats.overflow=true;self.scanOverflow=true;return false,'missile_scan_budget'end
    if self.scanOverflow then
        self.scanOverflow=nil;self.threats.overflow=self.threats.overflowUntil~=nil and now<=self.threats.overflowUntil
    end
    local present={}
    for i=1,count do
        local m=game.Missile(i);self.hostCalls=self.hostCalls+1
        local d=m and m.missileData
        if d and m.isEnemy and m.team and m.team<300 then
            local owner=self.heroes[d.owner];local set=owner and self.loaded[owner.charName]
            local definition=set and (set[m.name]or set[d.name])
            local id=m.networkID or m.handle
            if id then
                id='missile:'..tostring(id);present[id]=true
                if definition and definition.eligible and d.target==0 and G.point(m.pos)and G.point(d.endPos)
                    and G.finite(d.speed)and d.speed>0 and G.finite(d.width)and d.width>0 then
                    local previous=self.seen[id];local pos=G.copy(m.pos)
                    -- Require two attributable samples. Unexpected motion invalidates
                    -- the fixed-trajectory model rather than silently fitting it.
                    local confirmed=false
                    if previous and previous.owner==d.owner and previous.alias==definition.name and now>previous.at then
                        local elapsed=now-previous.at;local distance=G.dist(previous.pos,pos)
                        local expected=previous.speed*elapsed
                        local off=G.segment(pos,previous.pos,previous.endpoint)
                        confirmed=elapsed<=.25 and math.abs(distance-expected)<=math.max(30,expected*.3)
                            and off<=20 and G.dist(previous.endpoint,d.endPos)<=20
                            and math.abs(d.speed-definition.speed)<=math.max(20,definition.speed*.1)
                    end
                    self.seen[id]={pos=pos,at=now,speed=d.speed,owner=d.owner,alias=definition.name,endpoint=G.copy(d.endPos)}
                    if confirmed then
                        local distance=G.dist(pos,d.endPos)
                        self.threats:Observe({id=id,damageID=id,casterID=d.owner,profile=definition.profile,
                            evidence='observed',ability=definition.id,source=definition.source,shape='missile',origin=pos,
                            b=G.copy(d.endPos),radius=math.max(d.width,definition.radius),speed=d.speed,
                            starts=now,launch=now,ends=now+distance/d.speed,blockable=true})
                    else self.threats:Remove(id)end
                else
                    self.threats:Remove(id)
                    -- Bounded diagnostics only; unknown objects are not invented threats.
                    if not self.unknown[m.name or '?']and self.unknownCount~=128 then
                        self.unknown[m.name or '?']=true;self.unknownCount=(self.unknownCount or 0)+1
                    end
                end
            end
        end
    end
    for id in pairs(self.seen)do if not present[id]then self.threats:Remove(id);self.seen[id]=nil end end
    self.threats:Expire(now);return true
end
return O
