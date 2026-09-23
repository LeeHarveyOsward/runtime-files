local U=require('lho.util');local P=require('lho.profiles')
local F={};F.__index=F
function F.new(ctx,actions,spells,smite)
    return setmetatable({ctx=ctx,actions=actions,spells=spells,smite=smite,known={},state='idle'},F)
end
function F:startRoute()
    self.threatRetreat=nil;self.recoveryTrigger=nil;self.pressureSample=nil
    self.recoveryWanted=nil;self.recallReconcile=nil;self.recallObserved=false;self.recallAction=nil;self.retreatCamp=nil;self.retreatMove=nil
    local c=self.ctx;local choice=c.config:get('openingRoute')
    self.camp=nil;self.progressAt=nil;self.progressCamp=nil;self.opening=nil
    self.actions.routeStop=nil;c.routeFailureReason=nil
    self.actions.lastRouteGoal=nil;self.actions.routeObservation=nil;self.actions.routeCommand=nil
    self.travelTarget=nil;self.travelJob=nil;self.probe=nil
    self:updateCamps()
    self.localException=nil;self.returningHome=nil
    local localStart,nearest,engaged=nil,650,false
    if c.config:get('farmLocalEnemyStart') then
        for _,camp in pairs(self.known) do
            if not P.epics[camp.category] and camp.team and camp.team~=0 and c:threats(camp.pos,1000)==0 then
                for _,m in ipairs(camp.members or {}) do
                    local distance=U.dist(myHero.pos,m.pos)
                    local fighting=(m.health or 0)<(m.maxHealth or m.health or 0)
                        or U.same(c.attackTarget,m)
                    if self:ordinaryTarget(m) and distance<=650 and
                        (not localStart or fighting and not engaged or fighting==engaged and distance<nearest) then
                        localStart,nearest,engaged=camp,distance,fighting
                    end
                end
            end
        end
    end
    if localStart and localStart.team~=myHero.team then self.localException=localStart.id end
    local anchor=localStart or self:choose()
    -- The opening preference applies only when leaving base before first spawn.
    -- Restarting J in the jungle always starts a new nearest-camp decision.
    local spawn=self:spawn()
    local nearbyAlive=anchor and anchor.availability=='observed_alive' and U.dist(myHero.pos,self:walkDestination(anchor))<1600
    -- A level-one player choosing a jungle half chooses its buff opening.
    -- An already engaged camp still wins; later restarts remain nearest-camp.
    local atBase=spawn and U.dist(myHero.pos,spawn)<900
    if not localStart and not atBase and c:now()<180 and (myHero.levelData.lvl or 1)==1 and choice>1 then
        local engaged=false
        for _,m in ipairs(anchor and anchor.members or {}) do
            if U.valid(m) and m.health<m.maxHealth and U.dist(myHero.pos,m.pos)<500 then engaged=true;break end
        end
        if not engaged then
            local nearest=math.huge
            for _,camp in pairs(self.known) do
                local distance=U.dist(myHero.pos,self:walkDestination(camp))
                if camp.team==myHero.team and (camp.category=='Red' or camp.category=='Blue')
                    and (self:staging(camp) or camp.availability~='observed_empty' and not camp.awaitingRespawn)
                    and c:threats(camp.pos,1000)==0 and not c:underTurret(camp.pos) and distance<nearest then
                    anchor,nearest=camp,distance
                end
            end
        end
    end
    if not nearbyAlive and spawn and U.dist(myHero.pos,spawn)<900 and c:now()<180 and (myHero.levelData.lvl or 1)==1 and choice>1 then
        local category=P.openings[c.profile.id][choice-1][1]
        for _,camp in pairs(self.known) do
            if camp.team==myHero.team and camp.category==category and self:staging(camp)
                and c:threats(camp.pos,1000)==0 then anchor=camp;break end
        end
    end
    if anchor then
        self.camp=anchor
        if choice>1 then
            local blue=anchor.category=='Blue' or anchor.category=='Wolves' or anchor.category=='Gromp' or anchor.category=='Wight'
            choice=blue and 3 or 2
        end
        if c.config.capture then c:log('route_start_anchor',{name=anchor.category}) end
    end
    self.opening=(not self.localException and choice>1 and c:now()<300 and (myHero.levelData.lvl or 1)<=5)
        and {order=P.openings[c.profile.id][choice-1],index=1} or nil
    if anchor and self.opening then
        for index,category in ipairs(self.opening.order) do
            if category==anchor.category then self.opening.index=index;break end
        end
    end
end
function F:respawnDuration(camp)
    local c=self.ctx;local provider=_G.LHO_Camps
    local override=provider and provider.mode==c.profile.id and provider.respawn and provider.respawn[camp.category]
    if type(override)=='number' and override>=10 and override<=900 then camp.timerSource='provider';return override end
    local measured=self.respawnSamples and self.respawnSamples[camp.category]
    if measured and measured.count>=2 then camp.timerSource='measured';return measured.seconds end
    camp.timerSource='profile estimate'
    if camp.category=='Red' or camp.category=='Blue' then return c.config:get('farmBuffRespawn') end
    if camp.category=='Wight' then return c.config:get('farmWightRespawn') end
    local seconds=P.respawns[c.profile.id][camp.category]
    if P.epics[camp.category] or camp.category=='River' then return seconds end
    if seconds then return c.config:get('farmSmallRespawn') end
    camp.timerSource='unknown category';return nil
end
function F:respawnObserved(camp,now,nativeTransition)
    if nativeTransition and camp.killTimePrecise and camp.awaitingRespawn and camp.killedAt and camp.nativeDownSeen
        and camp.lastNativeAt and now-camp.lastNativeAt<1 then
        local elapsed=now-camp.killedAt
        local expected=P.respawns[self.ctx.profile.id][camp.category]
        if elapsed>=10 and elapsed<=600 and (self.ctx.profile.id=='classic'
            or expected and math.abs(elapsed-expected)<=math.max(3,expected*.1)) then
            self.respawnSamples=self.respawnSamples or {}
            local old=self.respawnSamples[camp.category]
            if old and math.abs(old.seconds-elapsed)<2 then old.seconds=(old.seconds*old.count+elapsed)/(old.count+1);old.count=old.count+1
            else self.respawnSamples[camp.category]={seconds=elapsed,count=1} end
            if self.ctx.config.capture then self.ctx:log('camp_respawn_measured',{camp=camp.id,name=camp.category,seconds=elapsed}) end
        end
    end
    if self.ctx.config.capture then self.ctx:log('camp_respawn_confirmed',{camp=camp.id,name=camp.category,killedAt=camp.killedAt,
        expectedAt=camp.expectedAt,source=nativeTransition and 'native transition' or 'live monster'}) end
    camp.awaitingRespawn=false;camp.expectedAt=nil;camp.nativeDownSeen=nil;camp.blockedUntil=0
    camp.retiredMembers=nil;camp.knownMembers=nil;camp.emptyObservedAt=nil
end
function F:completed(camp,precise)
    -- Repeated death notifications must not restart an already running timer.
    if camp.awaitingRespawn then return end
    camp.retiredMembers=camp.retiredMembers or {}
    for _,m in ipairs(camp.members or {}) do
        local id=U.id(m);if id and not self:krugRemnant(m) then camp.retiredMembers[id]=true end
    end
    for id,row in pairs(camp.knownMembers or {}) do
        if not self:krugRemnant(row.unit) or row.dead then camp.retiredMembers[id]=true end
    end
    camp.killedAt=self.ctx:now();camp.killTimePrecise=precise~=false;camp.layout=nil;camp.seenAlive=true;camp.awaitingRespawn=true
    local duration=self:respawnDuration(camp)
    camp.expectedAt=duration and duration>0 and camp.killedAt+duration or nil;camp.blockedUntil=0
    camp.availability='observed_empty'
    if self.ctx.config.capture then self.ctx:log('camp_down',{camp=camp.id,name=camp.category,team=camp.team,profile=self.ctx.profile.id,
        killedAt=camp.killedAt,precise=camp.killTimePrecise,nativeUp=camp.nativeUp,
        expectedAt=camp.expectedAt,timer=camp.timerSource or 'profile estimate'}) end
    camp.focus=nil;camp.mainID=nil;camp.mainHealth=nil
    camp.kiteCenter=nil;camp.kiteHealth=nil;camp.kiteRecoverUntil=nil;camp.kiteDirection=nil
    local o=self.opening
    if o then
        for index=o.index,#o.order do
            if o.order[index]==camp.category then o.index=index+1;break end
        end
        if o.index>#o.order then self.opening=nil end
    end
end
function F:krugRemnant(unit)
    return self.ctx.profile.id=='normal' and U.name(unit and unit.charName)=='srukrugminimini'
end
function F:hasRemnants(camp)
    if self.ctx.profile.id~='normal' or camp.category~='Krugs' then return false end
    for _,m in ipairs(camp.members or {}) do
        if self:krugRemnant(m) and U.valid(m) then return true end
    end
    return false
end
function F:splitPending(camp)
    return camp and self.ctx.profile.id=='normal' and camp.category=='Krugs'
        and self.ctx:now()<(camp.splitUntil or 0)
end
function F:spawn()
    self.spawnPoints=self.spawnPoints or {}
    if self.spawnPos and not U.position(self.spawnPos) then self.spawnPos=nil end
    for _,team in ipairs({100,200}) do
        if self.spawnPoints[team] and not U.position(self.spawnPoints[team]) then self.spawnPoints[team]=nil end
    end
    if self.spawnPos and self.spawnPoints[100] and self.spawnPoints[200] then return self.spawnPos end
    local now=self.ctx:now()
    if Game.ObjectCount and Game.Object and now>(self.spawnScanAt or -2)+.5 then
        self.spawnScanAt=now
        local count=U.count(Game.ObjectCount(),65536)
        local first=self.spawnScanIndex or 1;if first>count then first=1 end
        local last=math.min(count,first+63)
        for i=first,last do
            local o=Game.Object(i)
            if o and ((Obj_AI_SpawnPoint and o.type==Obj_AI_SpawnPoint) or U.name(o.charName)=='spawnpoint') and U.position(o.pos) then
                local team=(o.team==100 or o.team==200) and o.team or o.isAlly and myHero.team
                if team then self.spawnPoints[team]=U.copy(o.pos) end
                if team==myHero.team then self.spawnPos=U.copy(o.pos) end
            end
        end
        self.spawnScanIndex=last>=count and 1 or last+1
    end
    if self.ctx.profile.id=='normal' then
        self.spawnPoints[100]=self.spawnPoints[100] or {x=400,y=180,z=420}
        self.spawnPoints[200]=self.spawnPoints[200] or {x=14300,y=180,z=14350}
        return self.spawnPos or self.spawnPoints[myHero.team]
    end
    -- Discover Classic spawn at load/respawn instead of copying a different map.
    if not self.spawnPos and U.position(myHero.pos) and (self.ctx:now()<25 or self.ctx:now()<180 and (myHero.levelData.lvl or 1)==1
        and (myHero.pos.x<1500 and myHero.pos.z<1500 or myHero.pos.x>13000 and myHero.pos.z>13000)) then
        self.spawnPos=U.copy(myHero.pos)
    end
    return self.spawnPos
end
function F:campTeam(pos)
    self:spawn()
    local spawns=self.spawnPoints
    if spawns and spawns[100] and spawns[200] then
        -- Relative proximity to both bases, never a fixed distance from ours.
        return U.dist(pos,spawns[100])<U.dist(pos,spawns[200]) and 100 or 200
    end
end
function F:updateCamps()
    local c=self.ctx;local now=c:now()
    local finished=self.camp and #(self.camp.members or {})>0
    if finished then for _,m in ipairs(self.camp.members) do if U.valid(m) then finished=false;break end end end
    if not finished and now<(self.scanAt or -1)+.4 then return end;self.scanAt=now
    local map=require(c.profile.id=='normal' and 'lho.normalcampdata' or 'lho.campdata')
    if not self.mapSeeded and c.profile.id==map.mode and Game.mapID==map.mapID then
        self.mapSeeded=true
        for _,data in ipairs(map.camps) do
            local id='map:'..data.name
            self.known[id]={id=id,pos=U.copy(data.pos),mapPos=U.copy(data.pos),category=data.category,team=data.team,
                availability='unknown',blockedUntil=0,mapNumber=data.number,fromMap=true}
            -- Walking-only correction from the Classic playtest at 144.523s:
            -- the untouched blue-side Wraith was east of the camp icon/wall.
            -- This is never used to authorize a fog Q or infer availability.
            if data.name=='Camp_Order_Wraiths' then
                self.known[id].walkPos={x=7443.1166992188,y=0,z=5663.0053710938}
            end
        end
    end
    for index,object in ipairs(c.camps or {}) do
        if object.pos then
            local number=tonumber((object.name or ''):match('monsterCamp_(%d+)'))
            local nativeID=U.id(object)
            local id=tostring(object.name and object.name~='' and object.name or nativeID and nativeID~=0 and nativeID or index)
            if self.mapSeeded then
                local nearest,distance=nil,c.profile.id=='normal' and 650 or 1100
                for key,known in pairs(self.known) do
                    local d=U.dist(known.mapPos or known.pos,object.pos)
                    if known.fromMap and d<distance and (c.profile.id~='normal' or not P.epics[known.category]) then nearest,distance=key,d end
                end
                -- Native indices differ from asset camp numbers in BOTH maps.
                -- Only spatial identity connects a timer to its actual camp.
                id=nearest
            end
            if id then
            local camp=self.known[id] or {id=id,pos=U.copy(object.pos),availability='unknown',blockedUntil=0}
            local locationMatches=not camp.fromMap or U.dist(camp.mapPos or camp.pos,object.pos)<1100
            camp.object=object
            if locationMatches then camp.pos=U.copy(object.pos) end
            if locationMatches then
                camp.nativeAim=U.copy(object.pos)
                if not camp.aimPos then camp.walkPos=U.copy(object.pos) end
            end
            local category=(c.profile.id=='normal' and P.campNames[number]) or P.category(object.name)
            if not camp.fromMap and (category~='Camp' or not camp.category) then camp.category=category end
            if camp.fromMap then -- Keep the extracted map's camp identity and side.
            elseif c.profile.id=='normal' and number then
                camp.team=(number<=5 or number==13) and 100 or ((number>=7 and number<=11) or number==14) and 200 or 0
            else
                camp.team=(object.team==100 or object.team==200) and object.team or camp.team
                if P.epics[camp.category] then camp.team=0 end
                if not camp.team then camp.team=self:campTeam(camp.pos) end
            end
            if locationMatches and type(object.isCampUp)=='boolean' then
                local previous=camp.nativeUp;camp.nativeUp=object.isCampUp
                if not object.isCampUp then
                    camp.layout=nil
                    -- Before the first observed spawn a native up/down flicker
                    -- is not evidence that somebody cleared this opening camp.
                    local opening=now<180 and (myHero.levelData.lvl or 1)==1 and not camp.seenAlive
                    if previous==true and not camp.awaitingRespawn and not opening then
                        self:completed(camp,now-(camp.lastNativeAt or -math.huge)<1)
                    end
                    camp.nativeDownSeen=true;camp.availability='observed_empty'
                elseif not camp.awaitingRespawn and (not camp.emptyObservedAt or previous==false)
                    or camp.awaitingRespawn and previous==false and camp.expectedAt and now>=camp.expectedAt-2 then
                    if camp.awaitingRespawn then self:respawnObserved(camp,now,previous==false) end
                    camp.availability='observed_alive';camp.observedAt=now
                end
                -- Continuous stale true cannot erase a directly observed kill.
                camp.lastNativeAt=now
            elseif not camp.awaitingRespawn and camp.availability=='observed_alive' and now-(camp.observedAt or 0)>5 then camp.availability='unknown' end
            self.known[id]=camp
            end
        end
    end
    if next(self.known)==nil and c.profile.id=='normal' then
        for i,p in ipairs(P.centers) do self.known['fallback'..i]={id='fallback'..i,pos={x=p[1],y=myHero.pos.y,z=p[2]},team=p[3],category=p[4],availability='unknown',blockedUntil=0} end
    end
    local current={};local memberOwner={}
    for _,m in ipairs(c.minions or {}) do if U.id(m) then current[U.id(m)]=m end end
    for _,camp in pairs(self.known) do
        camp.knownMembers=camp.knownMembers or {}
        for _,m in ipairs(camp.members or {}) do
            local id=U.id(m)
            if id and not camp.knownMembers[id] then
                camp.knownMembers[id]={unit=m,pos=U.copy(m.pos),visible=m.visible,lastSeen=now}
            end
        end
        local allDead,hasOriginal=true,false
        for id,row in pairs(camp.knownMembers) do
            memberOwner[id]=camp
            local m=row.unit;local fresh=current[id]
            local observed=fresh or m
            if fresh and U.valid(fresh) and not row.deathConfirmed then
                -- A filtered snapshot can briefly omit a live monster. It must
                -- not permanently retire that identity on the next observation.
                row.dead=nil;row.unit=fresh;row.missingAt=nil
                if camp.retiredMembers then camp.retiredMembers[id]=nil end
            elseif observed.dead or (observed.health or 0)<=0 then
                if not row.deathConfirmed and c.profile.id=='normal' and camp.category=='Krugs'
                    and (U.name(m.charName)=='srukrug' or U.name(m.charName)=='srukrugmini') then
                    camp.splitUntil=now+2
                end
                row.dead=true;row.deathConfirmed=true
            end
            if row.dead then
                camp.retiredMembers=camp.retiredMembers or {};camp.retiredMembers[id]=true
            end
            if not self:krugRemnant(m) then
                hasOriginal=true;if not row.dead then allDead=false end
            end
        end
        if hasOriginal and allDead and not camp.awaitingRespawn then
            camp.availability='observed_empty';camp.blockedUntil=now+20
            if camp.clearStartedAt then
                if c.config.capture then c:log('camp_clear_completed',{name=camp.category,duration=now-camp.clearStartedAt,health=U.hp(myHero),startHealth=camp.startHealth}) end
                camp.clearStartedAt=nil
            end
            self:completed(camp)
        end
        camp.members={}
    end
    for _,m in ipairs(c.minions or {}) do
        if m.team==300 and U.valid(m) and P.jungleEntity(m) then
            local category=P.category(m.charName)
            local best,distance=nil,math.huge
            for _,camp in pairs(self.known) do
                local compatible=category=='Camp' and not P.epics[camp.category] or category==camp.category or camp.category=='Camp'
                -- Classic camp markers are not monster spawn coordinates.
                -- Preserve a known member while it moves within its camp; a
                -- typed monster may join its matching marker across that offset.
                local d=math.min(U.dist(camp.mapPos or camp.pos,m.pos),U.dist(camp.pos,m.pos))
                local radius=c.profile.id=='classic' and camp.fromMap and category==camp.category and 1100 or 650
                if c.profile.id=='normal' and camp.fromMap and category==camp.category then radius=1800 end
                if memberOwner[U.id(m)]==camp then radius=math.huge end
                if compatible and d<radius then
                    local score=d-(memberOwner[U.id(m)]==camp and 2000 or 0)
                    if score<distance then best,distance=camp,score end
                end
            end
            if not best then
                -- Live monsters provide local discovery, including Classic Wight.
                local id='observed:'..tostring(U.id(m))
                best={id=id,pos=U.copy(m.pos),category=P.category(m.charName),team=self:campTeam(m.pos),
                    availability='unknown',blockedUntil=0,members={}}
                self.known[id]=best
            end
            local remnant=best and best.category=='Krugs' and self:krugRemnant(m)
            if best and (best.nativeUp~=false or remnant) and not (best.retiredMembers and best.retiredMembers[U.id(m)]) then
                best.members[#best.members+1]=m
                if best.awaitingRespawn and not remnant then self:respawnObserved(best,now) end
                best.knownMembers=best.knownMembers or {}
                local memberID=U.id(m)
                if memberID then best.knownMembers[memberID]={unit=m,pos=U.copy(m.pos),visible=m.visible,lastSeen=now} end
                best.emptyObservedAt=nil
                best.availability=best.awaitingRespawn and 'clearing_remnants' or 'observed_alive';best.observedAt=now
                best.seenAlive=true;best.blockedUntil=0
                if not m.pathing or not m.pathing.hasMovePath then
                    if m.health>=(m.maxHealth or m.health) and (m.maxHealth or 0)>=(best.aimHealth or 0) then
                        best.aimPos=U.copy(m.pos);best.aimHealth=m.maxHealth or 0
                        best.walkPos=U.copy(m.pos)
                    end
                end
                local cat=P.category(m.charName);if cat~='Camp' then best.category=cat end
            end
        end
    end
    for _,camp in pairs(self.known) do
        if camp.awaitingRespawn and not self:hasRemnants(camp) then camp.availability='observed_empty' end
        self:rememberLayout(camp)
    end
end
function F:epicSoon()
    for _,camp in pairs(self.known) do
        if P.epics[camp.category] and U.dist(myHero.pos,camp.pos)<3000 then
            for _,m in ipairs(camp.members or {}) do
                if U.valid(m) and m.health<(m.maxHealth or m.health)
                    and (self:alliesTaking(camp) or m.health<(m.maxHealth or m.health)*.5) then return true end
            end
        end
    end
    return false
end
function F:alliesTaking(camp)
    for _,a in ipairs(self.ctx.allies or {}) do
        if U.dist(a.pos,camp.pos)<1000 then
            local target=a.attackData and a.attackData.target
            local spell=a.activeSpell
            for _,m in ipairs(camp.members or {}) do
                if target==m.handle or (spell and spell.valid and spell.target==m.handle) then return true end
            end
        end
    end
    return false
end
function F:homeAvailable()
    if not self.ctx.config:get('farmPreferHome') then return false end
    for _,camp in pairs(self.known) do
        local travel=U.dist(myHero.pos,self:walkDestination(camp))/math.max(200,myHero.ms or 350)
        local due=camp.expectedAt and camp.expectedAt<=self.ctx:now()+travel
        local available=camp.nativeUp~=false and not camp.awaitingRespawn and camp.availability~='observed_empty'
        if camp.team==myHero.team and not P.epics[camp.category] and (available or due or self:staging(camp))
            and self.ctx:now()>=(camp.blockedUntil or 0) and self.ctx:threats(camp.pos,1000)==0
            and not self.ctx:underTurret(camp.pos) then return true end
    end
    return false
end
function F:sideAllowed(camp,home)
    if self.returningHome then return camp.team==myHero.team end
    if self.localException==camp.id and not P.epics[camp.category] then return true end
    if self.ctx.config:get('farmHomeOnly') and (camp.team~=nil or self.mapSeeded) then return camp.team==myHero.team end
    return not home or camp.team==myHero.team or camp.team==0
end
function F:ordinaryTarget(target)
    return U.valid(target) and target.team==300 and P.jungleEntity(target) and not P.epics[P.category(target.charName)]
end
function F:routeDistance(camp)
    local c=self.ctx;local destination=self:walkDestination(camp);local straight=U.dist(myHero.pos,destination)
    if not c.terrain:trusted() then return straight,'unverified straight distance' end
    self.routeCosts=self.routeCosts or {}
    local row=self.routeCosts[camp.id];local terrain=c.terrain
    if not row or row.provider~=terrain.provider or row.wall~=terrain.provider.isWall
        or U.dist(row.origin,myHero.pos)>150 or U.dist(row.destination,destination)>100 then
        row={origin=U.copy(myHero.pos),destination=U.copy(destination),provider=terrain.provider,wall=terrain.provider.isWall}
        row.work=coroutine.create(function()
            if terrain:walkLine(row.origin,row.destination,myHero.boundingRadius or 35) then return straight end
            local path,length=require('lho.navigation').approach(terrain,row.origin,row.destination,220,straight*2+1500,
                function()coroutine.yield()end,function(p)return terrain:walkLine(p,row.destination,myHero.boundingRadius or 35)end,8)
            return path and length+U.dist(path[#path] or row.origin,row.destination)
        end)
        self.routeCosts[camp.id]=row
    end
    -- One bounded solver slice for the whole controller per state cycle.
    if not row.done and self.routeCostAt~=c:now() then
        self.routeCostAt=c:now()
        local ok,value=coroutine.resume(row.work)
        if not ok or coroutine.status(row.work)=='dead' then row.done=true;row.cost=ok and value or nil end
    end
    return row.cost or straight,row.cost and 'verified terrain route' or 'unverified straight distance'
end
function F:choose(exclude,preview)
    local c=self.ctx;local now=c:now();local candidates={};local nearest=math.huge
    local home=self:homeAvailable()
    if now>=300 and not preview then self.opening=nil end
    for _,camp in pairs(self.known) do
        local distance=U.dist(myHero.pos,self:walkDestination(camp))
        local localEnemy=distance<1600
        local teamAllowed=camp.team==0 or camp.team==myHero.team or localEnemy or c.config:get('invade')
        local epic=P.epics[camp.category]
        local staging=self:staging(camp)
        local available=staging or camp.availability~='observed_empty' or camp.expectedAt~=nil
        if camp~=exclude and available and (teamAllowed or self.localException==camp.id) and self:sideAllowed(camp,home) and (staging or now>=(camp.blockedUntil or 0)) and c:threats(camp.pos,1000)==0
            and not epic and not c:underTurret(camp.pos) then
            local hp=0;for _,m in ipairs(camp.members or {}) do hp=hp+m.health end
            if distance<500 and hp>0 then
                for _,m in ipairs(camp.members) do
                    if m.health<(m.maxHealth or m.health) then
                        if c.config.capture and not preview then c:trace('route_choice',{selected=camp.id,reason='Finish nearby damaged camp',distance=distance},'choice',1) end
                        return camp
                    end
                end
            end
            local routeDistance,routeSource=self:routeDistance(camp)
            local travel=routeDistance/math.max(200,myHero.ms or 350)
            local wait=not self:hasRemnants(camp) and camp.expectedAt and math.max(0,camp.expectedAt-now-travel) or 0
            local cost=routeDistance+wait*math.max(200,myHero.ms or 350)
            candidates[#candidates+1]={camp=camp,cost=cost,distance=distance,wait=wait,routeSource=routeSource};nearest=math.min(nearest,cost)
        end
    end
    -- Honour the first-clear order instead of recomputing a greedy nearest
    -- neighbour after every kill (Blue -> Wolves -> Wight backtracks).
    -- A stolen, unavailable or threatened camp is skipped, never waited for
    -- ahead of live work. After this one clear, ordinary respawn ranking wins.
    local opening=now<300 and self.opening
    if opening then
        for index=opening.index,#opening.order do
            for _,entry in ipairs(candidates) do
                local camp=entry.camp
                if camp.team==myHero.team and camp.category==opening.order[index]
                    and not camp.killedAt and not camp.awaitingRespawn
                    and (camp.availability~='observed_empty' or self:staging(camp)) then
                    if not preview then opening.index=index end
                    if c.config.capture and not preview then c:trace('route_choice',{selected=camp.id,reason='First-clear order',index=index},'choice',1) end
                    return camp
                end
            end
        end
        if not preview then self.opening=nil end
    end
    local best,bestValue,bestCost=nil,-1,math.huge
    for _,entry in ipairs(candidates) do
        local camp=entry.camp
        if entry.cost<=nearest+250 then
            local value=(camp.category=='Red' or camp.category=='Blue') and 2 or 1
            if value>bestValue or value==bestValue and (entry.cost<bestCost or entry.cost==bestCost and tostring(camp.id)<tostring(best and best.id)) then
                best,bestValue,bestCost=camp,value,entry.cost
            end
        end
    end
    if c.config:get('playtestLogging') and not preview then
        local rows={}
        for _,entry in ipairs(candidates) do
            rows[#rows+1]={id=entry.camp.id,category=entry.camp.category,team=entry.camp.team,
                distance=entry.distance,wait=entry.wait,cost=entry.cost,routeSource=entry.routeSource,state=entry.camp.availability}
        end
        if c.config.capture then c:trace('route_choice',{selected=best and best.id,homeAvailable=home,candidates=rows,
            reason='Distance plus spawn wait; buff priority within 250'},'choice',1) end
    end
    return best
end
function F:staging(camp)
    -- Initial absence is not a killed camp. Walk to the opening before spawn;
    -- use actual visible monsters to end staging rather than guessing a timer.
    return self.ctx:now()<180 and (myHero.levelData.lvl or 1)==1 and not camp.seenAlive and not camp.killedAt
        and not P.epics[camp.category] and camp.team==myHero.team
end
function F:pause(reason)
    self.travelTarget=nil;self.travelJob=nil;self.probe=nil
    self.ctx.input:pauseFarm(reason);self.ctx.status=reason or 'Farming paused';self.state='paused'
    self.ctx.attackTarget=nil;self.ctx.moveTarget=nil
end
function F:kiteLine(origin,destination)
    local terrain=self.ctx.terrain;local radius=myHero.boundingRadius or 35
    -- Live positions can overlap conservative static-grid padding. Egress only
    -- permits leaving that padding; its centerline never crosses a wall.
    if terrain.egressLine then return terrain:egressLine(origin,destination,radius) end
    return terrain:walkLine(origin,destination,radius)
end
function F:kiteClick(point,target,center,leash,scene)
    local c=self.ctx;local distance=U.dist(myHero.pos,point)
    if distance<1 then return point end
    -- The click is a steering ray, not the turnaround waypoint. Only actual
    -- travel is leash-bounded. A straight, empty ray avoids native wall detours.
    for _,length in ipairs({math.max(distance,1000),math.max(distance,800),math.max(distance,600),math.max(distance,400),math.max(distance,250),distance}) do
        local click=U.toward(myHero.pos,point,length)
        if U.vector(click):To2D().onScreen~=false and self:kiteLine(myHero.pos,click)
            and not require('lho.ground').blocker(c,click,scene) then return click end
    end
    return nil
end
function F:kiteDecision(target,reason)
    local c=self.ctx;local camp=self.camp
    if not c.config.capture or not camp then return end
    local attack=c.sdk.Attack;local row=self.kiteDiagnostic or {};self.kiteDiagnostic=row
    row.reason=reason;row.at=c:now();row.target=U.id(target);row.name=target.charName
    row.range=target.range;row.main=camp.mainID;row.enabled=c.config:get('farmKite')
    row.autoAttacking=c.sdk.Orbwalker:IsAutoAttacking();row.canMove=c.sdk.Orbwalker:CanMove()
    row.ready=attack and attack.IsReady and attack:IsReady();row.serverStart=attack and attack.ServerStart
    row.castEnd=attack and attack.CastEndTime;row.cycle=attack and attack.GetAnimation and attack:GetAnimation()
    row.separation=U.dist(myHero.pos,target.pos);row.center=camp.kiteCenter;row.leash=c.config:get('farmKiteLeash')
    row.latency=c.latency;row.jitter=c.jitter;row.speed=myHero.ms
    row.position=U.copy(myHero.pos);row.targetPosition=U.copy(target.pos)
end
function F:kitePursuers(target)
    local out={}
    for _,m in ipairs(self.camp and self.camp.members or {target}) do
        if U.valid(m) and (m.range or 0)<=250 then
            out[#out+1]={pos=U.copy(m.pos),stop=math.max(75,m.range or 100)+(m.boundingRadius or 45)+(myHero.boundingRadius or 35)}
        end
    end
    return out
end
function F:kiteBound(point,target,center,leash,reserve,pursuers)
    local radius=U.dist(point,center)
    if radius<=leash then return true,false end
    -- The leash belongs to pursuing monsters, not Lee's hitbox. Permit a
    -- bounded outer arc when the preferred inner ring has no usable step.
    -- Reserve overshoot room for one delayed callback; check every melee pursuer.
    local margin=math.max(25,(myHero.ms or 350)*(reserve or .15))
    if radius>math.max(leash,U.dist(myHero.pos,center))+80 then return false end
    local checked=false
    local inward=radius<U.dist(myHero.pos,center)-15
    for _,m in ipairs(pursuers or self:kitePursuers(target)) do
        checked=true
        local gap=U.dist(m.pos,point)
        local chase=gap>m.stop and U.toward(m.pos,point,gap-m.stop) or m.pos
        local chasedRadius=U.dist(chase,center)
        if chasedRadius>leash-margin and not (inward and chasedRadius<=U.dist(m.pos,center)+1) then return false end
    end
    return checked,true
end
function F:kite(target)
    local c=self.ctx;local camp=self.camp;local attack=c.sdk.Attack
    if not camp then return end
    local name=U.name(target.charName)
    if (target.range or 0)>250 or name:find('wraith',1,true) or name:find('wight',1,true)
        or name:find('gromp',1,true) then self.kiteStep=nil;self:kiteDecision(target,'ranged_target');return end
    -- Remember the largest member, including after it dies. A surviving small
    -- monster must not become the "main" monster just because it is alone.
    for _,m in ipairs(camp.members or {}) do
        if (m.maxHealth or 0)>(camp.mainHealth or 0) then camp.mainHealth=m.maxHealth;camp.mainID=U.id(m) end
    end
    if not c.config:get('farmKite') or c:dash()
        or not attack or not attack.IsReady then self.kiteStep=nil;self:kiteDecision(target,'attack_or_movement_gate');return end
    if attack:IsReady() then
        if self.kiteStep and U.dist(myHero.pos,target.pos)>c:attackRange(target) then
            self.kiteStep.phase='attack'
        else self.kiteStep=nil end
        self:kiteDecision(target,'attack_ready');return
    end
    local cycle=attack.GetAnimation and attack:GetAnimation() or 1
    local started=attack.ServerStart
    if not started or started<=0 then self:kiteDecision(target,'missing_attack_start');return end -- No invented attack timing.
    local remaining=started+cycle-c:now()
    local finish=attack.CastEndTime and attack.CastEndTime>=started and attack.CastEndTime or started+c:windup()
    local preparing=c:now()<finish or c.sdk.Orbwalker:IsAutoAttacking() or not c.sdk.Orbwalker:CanMove()
    if remaining<=0 then self:kiteDecision(target,'attack_windup_or_ready');return end
    if preparing and self.kiteStep and self.kiteStep.started==started and self.kiteStep.target==U.id(target)
        and self.kiteStep.cycle==cycle then return end
    if not camp.kiteCenter then
        local center=camp.aimPos or camp.pos;local health=0
        local layout=camp.spawnLayout
        if layout and layout.mode==c.profile.id and layout.mapID==Game.mapID then
            for _,row in ipairs(layout.rows) do
                if (row.maxHealth or 0)>health then center=row.pos;health=row.maxHealth end
            end
        end
        camp.kiteCenter=U.copy(center)
    end
    local center=camp.kiteCenter;local leash=c.config:get('farmKiteLeash')
    local observed=camp.kiteHealth
    if observed and observed.id==U.id(target) and c:now()-observed.at<.5
        and target.health>observed.hp+math.max(30,target.maxHealth*.02) then
        camp.kiteRecoverUntil=c:now()+2;self.kiteStep=nil
        if c.config.capture then c:log('kite_reset_suspected',{target=U.id(target),health=target.health,previous=observed.hp}) end
    end
    camp.kiteHealth={id=U.id(target),hp=target.health,at=c:now()}
    -- Crossing the preferred leash ring is a reason to turn inward, not to
    -- disable kiting for the rest of the fight. Actual resets still suspend it.
    if U.dist(target.pos,center)>leash+150 or c:now()<(camp.kiteRecoverUntil or 0) then self.kiteStep=nil;self:kiteDecision(target,'leash_or_reset');return end
    local speed=math.max(1,myHero.ms or 350);local ownRange=math.max(30,c:attackRange(target)-10)
    local separation=U.dist(myHero.pos,target.pos)
    local timing=c.sdk.Input and c.sdk.Input.Timing
    -- Callback jitter is different from network ping. Refresh this reserve at
    -- most four times a second, keeping statistical work out of the fast path.
    if not self.kiteReserveAt or c:now()>=self.kiteReserveAt+.25 then
        self.kiteReserveAt=c:now()
        self.kiteReserve=timing and timing.reserve and U.clamp(timing:reserve()*.001,0,.2) or .06
    end
    local reserve=c.latency+math.max(.016,self.kiteReserve or .06)
    local returnTime=math.max(0,separation-ownRange)/speed
    local key=tostring(U.id(target))..':'..tostring(started)
    local step=self.kiteStep
    if step and step.key==key and step.cycle and math.abs(step.cycle-cycle)>.001 then
        self.kiteStep=nil;self.kiteSearch=nil;step=nil
    end
    local function publish(point)
        if not preparing then return point end
    end
    if step and step.key==key and step.phase=='attack' then return end
    local passedWaypoint=step and step.key==key and step.phase=='out'
        and (U.dist(myHero.pos,step.pos)<=25 or step.origin
            and (myHero.pos.x-step.origin.x)*(step.pos.x-step.origin.x)
                +(myHero.pos.z-step.origin.z)*(step.pos.z-step.origin.z)
                >=math.max(0,U.dist(step.origin,step.pos)-25)*U.dist(step.origin,step.pos))
    -- Begin returning while the attack is still cooling down. Use a stationary
    -- target for this budget: a chasing monster may help, but is not promised.
    local reachedOut=passedWaypoint and separation>ownRange
    if reachedOut or (separation>ownRange or self.kiteStep and self.kiteStep.key==key and self.kiteStep.phase=='out')
        and remaining<=returnTime+reserve then
        self.kiteStep={key=key,pos=U.copy(target.pos),phase='attack',target=U.id(target),started=started}
        if c.config.capture then c:log('kite_attack_due',{target=U.id(target),remaining=remaining,
            returnTime=returnTime,reserve=reserve,separation=separation}) end
        return -- The target attack order performs the approach, without a ground move.
    end
    if self.kiteStep and self.kiteStep.key==key then
        local p=self.kiteStep.pos
        if self.kiteStep.phase=='return' and separation<=ownRange or passedWaypoint or U.dist(myHero.pos,p)<=25 then
            -- The monster may have followed us faster than expected. Replan
            -- along the camp boundary instead of waiting at a reached waypoint.
            self.kiteStep=nil;self.kiteSearch=nil
        elseif U.dist(myHero.pos,p)>25 and self:kiteBound(p,target,center,leash,reserve) and self:kiteLine(myHero.pos,p) then
            -- Reuse the geometric ray for this attack instead of recomputing it
            -- on every Draw. Dispatch still checks current projected blockers.
            return publish(self.kiteStep.phase=='out' and self.kiteStep.click or p)
        else
            self.kiteStep=nil
        end
    end
    local budget=math.max(0,remaining-math.max(0,finish-c:now())-reserve)*speed
    local distance=math.min(c.config:get('farmKiteDistance'),budget)
    if distance<30 then self:kiteDecision(target,'insufficient_movement_time');return end
    local away=U.toward(target.pos,myHero.pos,1)
    local dx,dz=away.x-target.pos.x,away.z-target.pos.z
    if U.dist(myHero.pos,target.pos)<1 then dx,dz=1,0 end
    local enemyRange=((target.range or 0)>0 and target.range or 125)+(target.boundingRadius or 45)+(myHero.boundingRadius or 35)+25
    local direction=camp.kiteDirection or 1;local best,bestAngle,bestClick;local candidates={}
    local search=self.kiteSearch
    if search and search.key==key and c:now()<search.at+.08 and U.dist(myHero.pos,search.origin)<20
        and U.dist(target.pos,search.target)<20 then return end
    self.kiteSearch={key=key,at=c:now(),origin=U.copy(myHero.pos),target=U.copy(target.pos)}
    self:kiteDecision(target,'searching_or_following_plan')
    local scene=require('lho.ground').scene(c)
    local pursuers=self:kitePursuers(target)
    -- Outward first; near the edge, turn tangentially and then inward. Keep a
    -- consistent rotation across attacks instead of flipping left/right.
    local radial=U.dist(myHero.pos,center)
    for _,angle in ipairs({0,.55,1.1,1.57,2.1,2.65,3.14,-.55,-1.1,-1.57,-2.1,-2.65}) do
        local a=angle*direction
        local x,z=dx*math.cos(a)-dz*math.sin(a),dx*math.sin(a)+dz*math.cos(a)
        for _,scale in ipairs({1,.75,.5}) do
            local length=distance*scale
            local p={x=myHero.pos.x+x*length,y=myHero.pos.y,z=myHero.pos.z+z*length}
            local gap=U.dist(p,target.pos);local back=math.max(0,gap-ownRange)
            local bounded,outer=self:kiteBound(p,target,center,leash,reserve,pursuers)
            local inward=radial>leash-40 and U.dist(p,center)<radial-15
                and gap>=math.max((target.boundingRadius or 45)+(myHero.boundingRadius or 35)+15,math.min(separation,enemyRange)-25)
            if length>=30 and length+back<=budget and bounded
                and (gap>=enemyRange or gap>separation+15 or inward)
                and self:kiteLine(myHero.pos,p)
                and (back==0 or self:kiteLine(p,U.toward(target.pos,p,ownRange))) then
                local value=math.min(gap-enemyRange,45)*4+length*.15
                    + (angle>0 and 12 or angle<0 and -12 or 0)-math.abs(angle)*5
                    - (outer and 1000+math.max(0,U.dist(p,center)-leash) or 0)
                    + (inward and math.min(80,radial-U.dist(p,center)) or 0)
                candidates[#candidates+1]={pos=p,score=value,angle=angle}
            end
        end
    end
    table.sort(candidates,function(a,b)return a.score>b.score end)
    for _,candidate in ipairs(candidates) do
        local click=self:kiteClick(candidate.pos,target,center,leash,scene)
        if click then best,bestAngle,bestClick=candidate.pos,candidate.angle,click;break end
    end
    if best then
        self:kiteDecision(target,'outward_plan')
        if bestAngle<0 then camp.kiteDirection=-direction else camp.kiteDirection=direction end
        self.kiteStep={key=key,started=started,target=U.id(target),cycle=cycle,pos=best,click=bestClick,origin=U.copy(myHero.pos),phase='out',preparedAt=c:now(),castEnd=finish}
        if c.config.capture then c:log('kite_planned',{target=U.id(target),origin=U.copy(myHero.pos),destination=U.copy(best),
            center=U.copy(center),remaining=remaining,enemyRange=enemyRange,ownRange=ownRange,
                separation=U.dist(best,target.pos),travel=U.dist(myHero.pos,best),budget=budget,click=U.copy(bestClick),
                preparedDuringWindup=preparing,cycle=cycle,castEnd=finish,reserve=reserve}) end
        return publish(bestClick)
    end
    self:kiteDecision(target,'no_feasible_ground_and_return_budget')
end
function F:fastKite()
    local c=self.ctx;local camp=self.camp
    if (self.state~='clearing' and self.state~='finishing') or not camp or camp.nativeUp==false or camp.awaitingRespawn
        or not c.config:get('autoJungle') or c.input.farmPaused
        or c:blocked() or c:recalling() or c.wards.pending or c.combat.insec then return false end
    local target=camp.focus or c.attackTarget
    if not self:ordinaryTarget(target) then return false end
    -- Draw/post-attack can run before the next planning Tick. Dispatch a ready
    -- attack there too, through the same scoped API and native readiness gates.
    if U.same(c.attackTarget,target) and c.actions.attack and c.sdk.Orbwalker:CanAttack()
        and U.dist(myHero.pos,target.pos)<=c:attackRange(target) then
        return c.actions:attack(target,'farm')
    end
    local point=self:kite(target)
    local step=self.kiteStep
    if step and step.phase=='attack' and c.actions.attackApproach then
        return c.actions:attackApproach(target,'farm',step.key)
    end
    if not point then return false end
    local accepted,reason=self.actions:move(point,'farm');local id=self.actions.lastCursorAction
    if accepted and id and id~=self.kiteMoveID then
        self.kiteMoveID=id
        if c.config.capture then c:log('kite_move_request',{cursorID=id,target=U.id(target),destination=U.copy(point),
            attackStart=c.sdk.Attack.ServerStart,castEnd=c.sdk.Attack.CastEndTime,
            windupDeltaMs=c.sdk.Attack.CastEndTime and (c:now()-c.sdk.Attack.CastEndTime)*1000,
            phase=self.kiteStep and self.kiteStep.phase,preparedAt=self.kiteStep and self.kiteStep.preparedAt}) end
    end
    return accepted,reason
end
function F:clear(target)
    if not self:ordinaryTarget(target) then self.ctx.attackTarget=nil;return end
    -- Attacking and kiting intentionally replace the travel destination.
    -- Retire its endpoint check before GG issues the first combat order.
    self.actions.routeObservation=nil;self.actions.routeCommand=nil;self.actions.routeStop=nil
    if self.camp then self.camp.lastFoughtAt=self.ctx:now() end
    local c=self.ctx;c.attackTarget=target;c.moveTarget=nil
    -- GG remains responsible for attack readiness and windup cancellation.
    -- Retreat/return planning runs during cooldown; GG starts the next attack.
    local kite=self:kite(target)
    if kite then c.moveTarget=kite
    elseif self.kiteStep and self.kiteStep.phase=='attack' and c.actions.attackApproach then
        c.actions:attackApproach(target,'farm',self.kiteStep.key)
    elseif U.dist(myHero.pos,target.pos)>c:attackRange(target) then
        -- A monster's body is an attack destination, not a ground-click point.
        -- Keep the attack owner while approaching, including after a kite step
        -- or a focus change to another member of this same camp.
        if c.actions.attackApproach then
            c.actions:attackApproach(target,'farm','camp:'..tostring(self.camp and self.camp.id))
        else c.moveTarget=target.pos end
    end
    c.clear:tick(target,'farm')
end
function F:priority(m)
    local hits=m.health/math.max(1,self.ctx:aaDamage(m))
    -- Remove cheap camp attackers first; do not spend a full buff-sized clear
    -- on a small monster. AoE can finish the remaining small units together.
    return hits<=4 and -100000+hits or -(m.maxHealth or m.health)
end
function F:selectTarget(camp)
    if ((camp.nativeUp==false or camp.awaitingRespawn) and not self:hasRemnants(camp)) or P.epics[camp.category] then return end
    local c=self.ctx;local now=c:now();local units={};local main
    for _,m in ipairs(camp.members or {}) do if self:ordinaryTarget(m) then
        units[#units+1]=m
        if not main or (m.maxHealth or m.health)>(main.maxHealth or main.health) then main=m end
    end end
    local current=camp.focus;local early=(myHero.levelData.lvl or 1)<=c.config:get('farmSurvivalLevel') or U.hp(myHero)<40
    local smite=c.config:get('autosmite') and c.smite:ready() and not self:epicSoon() and c.smite:damage() or 0
    -- Invocation-local values: retain fresh HP each decision without querying
    -- SDK damage/buffs repeatedly for focus retention and diagnostic output.
    local hitCounts,scores={},{}
    local cycle=c.sdk.Attack.GetAnimation and c.sdk.Attack:GetAnimation() or 1
    local eLearned=(c:spell(2).level or 0)>0
    local function hits(m)
        if hitCounts[m]~=nil then return hitCounts[m] end
        local hp=m.health+(m.allShield or 0)
        if U.same(m,main) and c.smite:campTarget(m) and c.smite:inRange(m) then hp=hp-smite+c.config:get('smiteMargin') end
        local count=math.max(0,math.ceil(hp/math.max(1,c:aaDamage(m))))
        hitCounts[m]=count;return count
    end
    local function score(m)
        local count=hits(m);local move=math.max(0,U.dist(myHero.pos,m.pos)-c:attackRange(m))/math.max(1,myHero.ms or 350)
        if early then
            -- Weighted completion-time rule: remove damage sources according to
            -- remaining kill time / incoming DPS. Actual monster stats take
            -- priority; max-health scaling is an explicit fallback estimate.
            local damage=m.totalDamage or m.attackData and m.attackData.damage or math.max(8,(m.maxHealth or m.health)*.035)
            local rate=m.attackSpeed or (m.attackData and m.attackData.animationTime and 1/math.max(.2,m.attackData.animationTime)) or .7
            return (count*cycle+move)/math.max(1,damage*rate)
        end
        -- With AoE available, hit the durable member while cleave/E wears down
        -- the rest. Otherwise choose quick cleanup with minimal movement.
        if count<=2 then return -100+count+move end
        -- E entering cooldown must not flip focus back to healthy companions.
        -- Continue damaging the durable member between successive AoE cycles.
        if #units>1 and eLearned and count>2 then return -(m.maxHealth or m.health)/1000+move end
        return count*cycle+move
    end
    local best,bestScore=nil,math.huge
    for _,m in ipairs(units) do local value=score(m);scores[m]=value;if value<bestScore then best,bestScore=m,value end end
    if current then
        -- Host wrappers can change between scans for the same network identity.
        -- Retention must use this scan's object, health and cached score.
        local observed
        for _,m in ipairs(units) do if U.same(m,current) then observed=m;break end end
        if observed and (hits(observed)<=2 or scores[observed]<=bestScore+math.max(.05,math.abs(bestScore)*.25) or now<(camp.focusUntil or 0)) then best=observed end
    end
    if best and not U.same(best,current) then
        camp.focusUntil=now+.6
        if c.config.capture then c:log('camp_focus',{target=U.id(best),name=best.charName,policy=early and 'damage mitigation' or 'clear speed',remainingAttacks=hits(best)}) end
    end
    camp.focus=best
    return best
end
function F:localTarget(lane,jungle)
    local c=self.ctx;c:refresh();self:updateCamps()
    if lane==nil then lane=true end;if jungle==nil then jungle=true end
    if self.localCamp and jungle then
        local best,score=nil,math.huge
        for _,m in ipairs(self.localCamp.members or {}) do
            if U.valid(m) and U.dist(myHero.pos,m.pos)<=c:attackRange(m)+150 then
                local value=self:priority(m);if value<score then best,score=m,value end
            end
        end
        if best then return self:selectTarget(self.localCamp) or best end
    end
    self.localCamp=nil
    local anchor,distance=nil,math.huge
    for _,m in ipairs(c.minions or {}) do
        if U.valid(m) and m.team~=myHero.team and (m.team==300 and jungle or m.team~=300 and lane) then
            local d=U.dist(myHero.pos,m.pos)
            if d>1100 then d=math.huge end
            if d<distance then anchor,distance=m,d end
        end
    end
    if not anchor or anchor.team~=300 then return anchor end
    for _,camp in pairs(self.known) do
        local contains=false
        for _,m in ipairs(camp.members or {}) do if U.same(m,anchor) then contains=true;break end end
        if contains then
            self.localCamp=camp
            local best,score=nil,math.huge
            for _,m in ipairs(camp.members) do
                if U.valid(m) and U.dist(myHero.pos,m.pos)<=1100 then
                    local value=self:priority(m);if value<score then best,score=m,value end
                end
            end
            return self:selectTarget(camp) or best
        end
    end
    return anchor
end
function F:recovery()
    if self.ctx:recalling() or self.state=='recalling' then self.localException=nil end
    local c=self.ctx;local spawn=self:spawn();local now=c:now()
    if not spawn then c.status='Spawn position needs observation';return false end
    if U.dist(myHero.pos,spawn)<550 then
        if self.state~='base' then self.camp=nil;self.localException=nil;self.returningHome=true end
        if self.recallAction then self.actions:recallStatus(self.recallAction,true) end
        if self.state=='recalling' then if c.config.capture then c:log('farm_recall_arrived',{pos=U.copy(myHero.pos),spawn=U.copy(spawn)}) end end
        self.recallEndedAt=nil;self.recallObserved=false;self.recallAction=nil;self.recallLegacy=nil
        self.state='base';c.attackTarget=nil;c.moveTarget=nil
        if U.hp(myHero)<95 then c.status='Healing at base';return true end
        self.state='routing';self.recallAt=nil;self.recoveryWanted=nil;self.retreatCamp=nil;self.retreatMove=nil;self.recallReconcile=nil;self.recallSentTick=nil;return false
    end
    if c.input.farmPaused or not c.config:get('autoJungle') then return false end
    -- Full missile enumeration is needed before recovery, not on every healthy
    -- clear tick. The old path discarded that result in this exact case anyway.
    if self.lastRecoveryHP and myHero.health<self.lastRecoveryHP-.1 then self.lastHurtAt=now end
    self.lastRecoveryHP=myHero.health
    local low=U.hp(myHero)<c.config:get('recallHP')
    local wanted=self.recoveryWanted or low
    local awaiting=self.recallAction or self.recallLegacy or self.recallObserved or self.recallReconcile or c:recalling()
    local pressure=self:championPressure();local turret=c:underTurret(myHero.pos)
    if self.threatRetreat and not wanted and not awaiting then
        local safety=self:combatSafety(true)
        if pressure.count==0 and not turret and safety.monsters==0 and safety.missiles==0 and not safety.recentDamage and not safety.unknown then
            self.threatRetreat=nil;self.retreatCamp=nil;self.retreatMove=nil
            self:recoveryTransition('routing','threat_cleared_without_recall');return false
        end
        return self:retreat()
    end
    -- Do not begin another full camp on the reserve used to finish the last one.
    -- This only raises recovery intent before an engagement, never abandons one.
    if not wanted and not awaiting and self.camp and (not self.camp.lastFoughtAt or now-self.camp.lastFoughtAt>5)
        and U.hp(myHero)<math.min(50,c.config:get('recallHP')*2)
        and U.dist(myHero.pos,self:walkDestination(self.camp))<1100 then
        local forecast=self:finishForecast()
        if not forecast.safe then wanted=true end
    end
    if not wanted and not awaiting and pressure.count==0 and not turret then return false end
    if not wanted and not awaiting then
        self.threatRetreat=true;self.recoveryTrigger=turret and 'enemy_turret' or pressure.reason
        self:beginRetreat('immediate_threat',false);return self:retreat()
    end
    self.threatRetreat=nil
    self.recoveryTrigger=self.recoveryTrigger or (low and 'low_health' or 'insufficient_camp_reserve')
    local safe=self:recallSafe(true)
    local recallRecord=self.recallAction and self.actions:recallStatus(self.recallAction)
    if c:recalling() then
        self.recoveryWanted=true;self.localException=nil;self.recallObserved=true
        self:recoveryTransition('recalling','recall_observed');c.attackTarget=nil;c.moveTarget=nil;return true
    end
    if self.recallObserved then
        self.recallEndedAt=self.recallEndedAt or now
        if safe and now-self.recallEndedAt<.75 then c.status='Checking recall arrival';return true end
        self.recallObserved=false;self.recallAction=nil;self.recallLegacy=nil;self.recallReconcile=U.copy(myHero.pos)
        self:beginRetreat('recall_interrupted_by_game_state');return self:retreat()
    end
    if self.recallAction or self.recallLegacy then
        local r=recallRecord
        if r and r.state=='cancelled_before_send' then
            self.recallAction=nil;self:beginRetreat('recall_cancelled_before_send')
        elseif r and not r.sentAt then
            if not safe then
                self.actions:recallStatus(self.recallAction,true);self.recallAction=nil
                self:beginRetreat('threat_before_recall_send');return self:retreat()
            end
            self:recoveryTransition('recall_pending','awaiting_input');c.attackTarget=nil;c.moveTarget=nil
            c.status='Recall waiting for input';return true
        else
            local tick=self.actions.inputNow and self.actions:inputNow() or now*1000
            self.recallSentTick=r and r.sentAt or self.recallSentTick or tick
            local reserve=math.max(0,c.jitter or 0)*3
            if c.sdk.Input and c.sdk.Input.Timing and c.sdk.Input.Timing.reserve then reserve=math.max(reserve,c.sdk.Input.Timing:reserve()*.001) end
            local budget=math.min(3,1+reserve)*1000
            if tick-self.recallSentTick<budget and safe then
                self:recoveryTransition('recall_pending','awaiting_confirmation');c.attackTarget=nil;c.moveTarget=nil
                c.status='Recall awaiting confirmation';return true
            end
            self.recallAction=nil;self.recallLegacy=nil;self.recallSentTick=nil;self.recallReconcile=U.copy(myHero.pos)
            self:beginRetreat(safe and 'recall_confirmation_timeout' or 'threat_after_recall_send')
            return self:retreat()
        end
    end
    if self.recallReconcile then
        -- Positive movement away from the failed channel is a new game state;
        -- elapsed time or unchanged readiness alone does not replay B.
        if U.dist(myHero.pos,self.recallReconcile)<80 then return self:retreat() end
        self.recallReconcile=nil
    end
    if not wanted and safe then return false end
    if not wanted and self:combatSafety().champions==0 and not self:combatSafety().turret then return false end
    self.recoveryWanted=true
    -- Walking back into fountain range is faster than an eight-second recall
    -- from the platform edge. Only movement and health determine this boundary.
    if safe and U.dist(myHero.pos,spawn)<1200 then
        self:recoveryTransition('returning_base','near_fountain_walk')
        c.attackTarget=nil;c.moveTarget=U.copy(spawn);return true
    end
    if self.state~='retreating' and self.camp then
        local forecast=self:finishForecast()
        if c.config.capture then c:trace('finish_forecast',forecast,'finish_forecast',.5) end
        if forecast.safe then
            self:recoveryTransition('finishing','finish_active_camp',forecast)
            local target=self:selectTarget(self.camp)
            if target then self:clear(target);return true end
        end
    end
    if not safe then self:beginRetreat('unsafe_to_recall');return self:retreat() end
    if self.state~='recall_pending' then
        self.actions:cancel('farm');self.actions:cancel('escape')
        self.probe=nil;self.travelTarget=nil;self.travelJob=nil;self.opening=nil;self.localException=nil
        self.actions.routeStop=nil;self.actions.routeObservation=nil;self.actions.routeCommand=nil
        self:recoveryTransition('recall_pending','safe_recall_window')
    end
    c.attackTarget=nil;c.moveTarget=nil
    if c.actions:cursorBusy() or self.actions.api and self.actions.api:GetAvailability().cleanupPending then c.status='Recall waiting for input';return true end
    local accepted,why,submitted,id
    if self.actions.recall then accepted,why,submitted,id=self.actions:recall()
    else
        local input=c.sdk.Input
        if input and (input.Uncertain or not input:Available()) then c.status='Recall waiting for input';return true end
        local ok,result=pcall(Control.CastSpell,HK_RECALL or 66);accepted=ok and result~=false;submitted=accepted
    end
    local r=id and c.actions:inputAction(id)
    self.recallAction=(accepted or submitted or r and (r.state=='waiting' or r.state=='requested')) and id or nil
    if not accepted and not submitted then c.status='Recall waiting for input';return true end
    self.recallAt=now;self.recallSentTick=r and r.sentAt;self.recallObserved=false;self.recallEndedAt=nil
    if not self.actions.api then self.state='recalling';self.recallLegacy=true;self.recallSentTick=now*1000 end
    if c.config.capture then c:log('farm_recall_requested',{cursorID=id,submitted=submitted}) end
    c.status='Recall awaiting confirmation';return true
end
function F:tick()
    local c=self.ctx;self:updateCamps()
    if c.input.farmPaused then c.status='Auto-jungle paused | press '..U.keyLabel(c.config:key('farmKey'));return end
    if self:recovery() then return end
    if self:splitPending(self.camp) and not self:selectTarget(self.camp) then
        c.attackTarget=nil;c.moveTarget=nil;self.state='clearing'
        c.status='Waiting for Krug split';return
    end
    if self.localException then
        local camp=self.known[self.localException];local alive=false
        for _,m in ipairs(camp and camp.members or {}) do
            if m.valid~=false and not m.dead and (m.health or 0)>0 then alive=true;break end
        end
        if not alive and camp and (camp.availability=='observed_empty' or camp.killedAt) then
            self.localException=nil;self.returningHome=true;self.camp=nil;self.opening=nil
        end
    end
    local engaged=false
    for _,m in ipairs(c.minions or {}) do
        if m.team==300 and U.valid(m) and m.health<(m.maxHealth or m.health) and U.dist(myHero.pos,m.pos)<500 then engaged=true;break end
    end
    if c.leveling.pending then return end
    self.actions:followCamera() -- Camera requests must never consume a routing tick.
    if self.returningHome and self.camp and self.camp.team==myHero.team
        and U.dist(myHero.pos,self:walkDestination(self.camp))<650 then self.returningHome=nil end
    if self.camp and P.epics[self.camp.category] then
        self.camp=nil;self.probe=nil;self.travelTarget=nil;self.travelJob=nil
    end
    if self.camp and not self:staging(self.camp) and (c:now()<(self.camp.blockedUntil or 0) or self.camp.availability=='observed_empty' and not self.camp.expectedAt) then
        self.camp=nil;self.progressAt=nil
    end
    -- Vision changes while walking, without another J press. A nearby live
    -- camp takes precedence over a distant route or pending blind probe.
    local home=self:homeAvailable()
    local openingWait=self.camp and self:staging(self.camp)
    local localCamp,distance=nil,650
    for _,known in pairs(self.known) do
        if c:now()>=(known.blockedUntil or 0) and not P.epics[known.category] and self:sideAllowed(known,home)
            and c:threats(known.pos,1000)==0 then
            for _,m in ipairs(known.members or {}) do
                local d=U.dist(myHero.pos,m.pos)
                if self:ordinaryTarget(m) and d<distance then localCamp,distance=known,d end
            end
        end
    end
    local engagedHere=false
    if self.camp and self:hasRemnants(self.camp) and self.camp.lastFoughtAt
        and c:now()-self.camp.lastFoughtAt<3 then engagedHere=true end
    for _,m in ipairs(self.camp and self.camp.members or {}) do
        local attacking=m.attackData and m.attackData.target
        local spell=m.activeSpell
        local us=attacking==myHero.handle or attacking==myHero.networkID
            or spell and spell.valid and (spell.target==myHero.handle or spell.target==myHero.networkID)
        if self:ordinaryTarget(m) and (U.dist(myHero.pos,m.pos)<=c:attackRange(m)+150
            or us or self.camp.lastFoughtAt and c:now()-self.camp.lastFoughtAt<3
                and U.dist(myHero.pos,m.pos)<900) then engagedHere=true;break end
    end
    local finishing=engagedHere and self.camp and self.camp.lastFoughtAt and c:now()-self.camp.lastFoughtAt<2
    if self.camp and not finishing and not self:sideAllowed(self.camp,home) then
        self.camp=nil;self.probe=nil;self.travelTarget=nil;self.travelJob=nil;self.progressAt=nil;engagedHere=false
    end
    local followingOpening=self.opening and self.camp and not self.camp.killedAt
        and self.camp.category==self.opening.order[self.opening.index]
    local currentDistance=math.huge
    for _,m in ipairs(self.camp and self.camp.members or {}) do
        if self:ordinaryTarget(m) then currentDistance=math.min(currentDistance,U.dist(myHero.pos,m.pos)) end
    end
    if localCamp and localCamp~=self.camp and distance+200<currentDistance
        and not (self.camp and self.localException==self.camp.id) and not engagedHere and not openingWait and not followingOpening then
        self.camp=localCamp;self.progressAt=nil;self.probe=nil;self.travelTarget=nil;self.travelJob=nil
        if c.config.capture then c:log('route_visible_anchor',{name=localCamp.category}) end
    end
    if self.camp and (self.camp.expectedAt or self.returningHome) and not engagedHere and not openingWait and c:now()>(self.rerankAt or 0) then
        self.rerankAt=c:now()+1;self.camp=self:choose()
    end
    self.camp=self.camp or self:choose()
    local camp=self.camp
    if not camp then c.status='No eligible camp known: waiting for camp observations';return end
    if P.epics[camp.category] then
        self.camp=nil;c.status='Bosses excluded from auto-jungle';return
    end
    -- Choosing a new camp can happen after this tick's initial recovery check.
    -- Re-evaluate before a same-tick Q entry, not only on the next callback.
    if not engagedHere and U.hp(myHero)<math.min(50,c.config:get('recallHP')*2)
        and self:recovery() then return end
    local selected=self:selectTarget(camp);local best=selected and {unit=selected}
    if selected and U.dist(myHero.pos,selected.pos)<=c:attackRange(selected)+40 then self.probe=nil end
    if self.probe and self:probeCamp(camp) then return end
    if best then
        local targetDistance=U.dist(myHero.pos,best.unit.pos)
        local continuing=camp.lastFoughtAt and c:now()-camp.lastFoughtAt<3 and targetDistance<900
        if not continuing and self:travel(camp,best.unit) then return end
        local localAttack=targetDistance<=650 and U.vector(best.unit.pos):To2D().onScreen~=false
        if not continuing and not localAttack then
            self.state='routing';c.moveTarget=best.unit.pos;c.status='Walking to '..camp.category;return
        end
        if not camp.clearStartedAt then camp.clearStartedAt=c:now();camp.startHealth=U.hp(myHero) end
        self.state='clearing';c.status='Clearing '..(camp.category or 'camp')
        local m=best.unit
        if self.lastCampHP and m.health>self.lastCampHP+200 and self.lastCampTarget==U.id(m)
            and self.lastCampHPAt and c:now()-self.lastCampHPAt<.75 then
            -- Regeneration is a reason to stop pulling, not to repeatedly leave
            -- and reacquire this camp against the same stale health baseline.
            camp.kiteRecoverUntil=c:now()+2;self.kiteStep=nil
            if c.config.capture then c:log('camp_reset',{name=camp.category,previous=self.lastCampHP,
                health=m.health,action='Stop kiting and reengage current camp'}) end
        end
        self.lastCampHP=m.health;self.lastCampTarget=U.id(m);self.lastCampHPAt=c:now();self:clear(m);return
    end
    if self:staging(camp) then
        local destination=self:walkDestination(camp)
        self.state='staging';c.status='Opening camp: '..camp.category..' | '..(U.dist(myHero.pos,destination)>220 and 'walking before spawn' or 'waiting for spawn')
        if U.dist(myHero.pos,destination)>220 then c.moveTarget=destination end
        return
    end
    if camp.expectedAt and camp.availability~='observed_alive' then
        local wait=math.max(0,camp.expectedAt-c:now())
        if wait==0 and self:probeCamp(camp) then return end
        self.state='respawn';c.status=wait>0 and string.format('Next %s | respawn ~%.0fs [%s]',camp.category,wait,camp.timerSource or 'estimate')
            or 'Next '..camp.category..' | estimated timer elapsed; spawn unconfirmed'
        if U.dist(myHero.pos,self:walkDestination(camp))>220 then c.moveTarget=self:walkDestination(camp)
        elseif wait==0 then
            camp.arrivedAt=camp.arrivedAt or c:now()
            if c:now()-camp.arrivedAt>5 then
                camp.blockedUntil=c:now()+15;camp.arrivedAt=nil;self.camp=nil
            end
        end
        return
    end
    if self:probeCamp(camp) then return end
    if U.dist(myHero.pos,self:walkDestination(camp))<250 then
        camp.arrivedAt=camp.arrivedAt or c:now()
        if c:now()-camp.arrivedAt>1.3 then
            camp.availability='observed_empty';camp.emptyObservedAt=c:now();camp.blockedUntil=c:now()+20;camp.arrivedAt=nil
            if c.config.capture then c:log('camp_empty',{name=camp.category}) end;self.camp=nil
        end
        return
    end
    camp.arrivedAt=nil;self.state='routing';c.status='Routing: '..(camp.category or camp.id)..' ['..camp.availability..']'
    c.moveTarget=self:walkDestination(camp)
    if self.progressCamp~=camp.id then self.progressCamp=camp.id;self.progressAt=nil end
    if not self.progressAt or U.dist(myHero.pos,self.progressPos)>60 then self.progressAt=c:now();self.progressPos=U.copy(myHero.pos)
    elseif c:now()-self.progressAt>4 then
        camp.blockedUntil=c:now()+20;self.camp=nil;self.progressAt=nil;if c.config.capture then c:log('route_stalled') end
    end
end
-- Formation estimates are separate from availability. A camp icon is never
-- used as a monster position, and known deaths veto every estimated shot.
function F:rememberLayout(camp)
    if #(camp.members or {})==0 then return end
    local rows={};local c=self.ctx
    for _,m in ipairs(camp.members) do
        if not U.valid(m) or m.health<(m.maxHealth or m.health) or m.pathing and m.pathing.hasMovePath then
            camp.layout=nil;return
        end
        rows[#rows+1]={unit=m,pos=U.copy(m.pos),health=m.health,maxHealth=m.maxHealth,
            radius=m.boundingRadius or 45,at=c:now()}
    end
    camp.layout={rows=rows,at=c:now(),mode=c.profile.id,mapID=Game.mapID}
    local counts=c.profile.id=='classic' and {Red=3,Blue=3,Wolves=3,Wraiths=4,Golems=2,Wight=1}
        or {Red=1,Blue=1,Wolves=3,Raptors=6,Krugs=2,Gromp=1}
    if #rows==counts[camp.category] then
        local saved={}
        for _,row in ipairs(rows) do saved[#saved+1]={pos=U.copy(row.pos),health=row.health,
            maxHealth=row.maxHealth,radius=row.radius,name=row.unit.charName} end
        camp.spawnLayout={rows=saved,at=c:now(),mode=c.profile.id,mapID=Game.mapID}
    end
end
function F:entryAvailable(camp)
    if camp.nativeUp==false then return false end
    if not camp.awaitingRespawn then return true end
    -- A timer can authorize an explicitly estimated probe, never an alive
    -- observation. Stale native true alone cannot erase our recorded kill.
    return self.ctx.config:get('farmQRespawn') and camp.nativeUp==true and camp.expectedAt
        and self.ctx:now()>=camp.expectedAt+.25 and not (camp.probeMissedAt and camp.probeMissedAt>=(camp.killedAt or 0))
end
function F:entryDiagnostic(camp,reason)
    local c=self.ctx;local distance=U.dist(myHero.pos,self:walkDestination(camp))
    self.entryDecision={camp=camp.id,reason=reason,distance=distance,at=c:now()}
    if distance>c.profile.qRange+150 or c:now()<(self.entryLogAt or 0) then return end
    self.entryLogAt=c:now()+1
    if c.config.capture then c:log('camp_entry_decision',{camp=camp.id,reason=reason,distance=distance,rank=c:spell(0).level,
        cd=c:spell(0).currentCd,energy=myHero.mana,nativeUp=camp.nativeUp,waiting=camp.awaitingRespawn,
        expectedAt=camp.expectedAt,source=self.entryCandidateCamp==camp.id and self.entrySource or nil,
        targets=self.entryCandidateCamp==camp.id and self.entryCandidates or nil}) end
end
function F:fogLayout(camp)
    local c=self.ctx
    if camp.nativeUp~=true or not self:entryAvailable(camp) or camp.availability=='observed_empty' and not camp.awaitingRespawn
        or camp.lastFoughtAt and c:now()-camp.lastFoughtAt<20 then return end
    local layout=camp.layout
    if layout and (layout.mode~=c.profile.id or layout.mapID~=Game.mapID) then return end
    if layout and layout.mode==c.profile.id and layout.mapID==Game.mapID and c:now()-layout.at<=30 then
        for _,row in ipairs(layout.rows) do
            local m=row.unit
            if not m or m.dead or m.valid==false or (m.health or 0)<row.health
                or m.pathing and m.pathing.hasMovePath or U.dist(m.pos,row.pos)>15 then return end
        end
        return layout.rows,'recent stationary observation'
    end
    layout=camp.spawnLayout
    if layout and layout.mode==c.profile.id and layout.mapID==Game.mapID then return layout.rows,'learned spawn estimate' end
    local recorded=require(c.profile.id=='normal' and 'lho.normalcampobservations' or 'lho.campobservations')
    if recorded.mode==c.profile.id and recorded.mapID==Game.mapID then
        local saved=recorded.camps[camp.id]
        if saved then return saved.rows,'recorded spawn estimate' end
    end
end
function F:qEntryUpper(m)
    local c=self.ctx;local rank=c:spell(0).level or 0
    if rank<=0 then return false end
    local bonus=myHero.bonusDamage or math.max(0,(myHero.totalDamage or 0)-(myHero.baseDamage or 0))
    local raw=(c.profile.qBase[rank] or 0)+c.profile.qRatio*bonus
    -- Upper-side estimate: never use a disabled/unverified damage overlay's
    -- zero as proof that a small monster will survive. Ignore monster caps.
    local damage=raw
    if m then
        local ok;ok,damage=pcall(c.sdk.Damage.CalculateDamage,c.sdk.Damage,myHero,m,c.sdk.DAMAGE_TYPE_PHYSICAL,raw)
        if not ok or type(damage)~='number' or damage~=damage or math.abs(damage)==math.huge then return end
    end
    local upper=math.max(raw,damage)
    -- Classic Butcher amplifies spell damage too. Source: pinned 16.17.1
    -- Pinned mode item data. Use the strongest unique passive, not their sum.
    if c.profile.id=='classic' then
        local amps=c.profile.qMonsterAmplifiers;local multiplier=1
        local shared=c.sdk.SharedData;local inventory=shared and shared:GetInventory()
        for slot=6,11 do
            local item=inventory and inventory.ageMs<=80 and inventory.slots[slot] or myHero:GetItemData(slot)
            multiplier=math.max(multiplier,item and amps[item.itemID] or 1)
        end
        upper=upper*multiplier
    end
    if c.profile.q1DataMap and c.profile.q1DataMap==Game.mapID then upper=upper*1.1
    elseif not c.profile.damageVerified and not c.config:get('mechanicsVerified') then upper=upper*2 end
    return upper+25
end
function F:qSurvives(m,delay,health)
    local c=self.ctx;local upper=self:qEntryUpper(m)
    if not upper then return false end
    local hp=health or math.min(m.health,c:healthAt(m,delay))
    return hp>upper
end
function F:entryShot(camp,origin,fog)
    local c=self.ctx;origin=origin or myHero.pos
    self.entryCandidates=c.config.capture and {};self.entrySource=nil;self.entryCandidateCamp=camp.id
    if P.epics[camp.category] or not self:entryAvailable(camp) then return end
    local rows,source={}
    if fog then
        rows,source=self:fogLayout(camp);self.entrySource=source
        if not rows then self.entryShotReason='No eligible formation for this camp / spawn state';return end
    else
        for _,m in ipairs(camp.members or {}) do if self:ordinaryTarget(m) then
            rows[#rows+1]={unit=m,pos=m.pos,radius=m.boundingRadius or 45,maxHealth=m.maxHealth}
        end end
    end
    local best,bestScore,bestHealth
    for _,row in ipairs(rows) do
        local m=row.unit;local aim=row.pos;local distance=U.dist(origin,aim)
        local inRange=distance<=c.profile.qRange
        local delay=.25+distance/c.profile.qSpeed+c.latency
        -- A distant candidate cannot be selected. Avoid damage, inventory,
        -- health prediction and collision host calls until it enters Q range.
        local upper=inRange and self:qEntryUpper(m) or nil
        local hp=inRange and (fog and row.health or m and math.min(m.health,c:healthAt(m,delay))) or nil
        local survives=upper and hp and hp>upper
        local report=c.config.capture and {name=row.name or m and m.charName,health=hp,upper=upper,distance=distance}
        if report then
            self.entryCandidates[#self.entryCandidates+1]=report
            report.reason=not inRange and 'Out of Q range' or not survives and 'Q1 survival reserve' or 'Collision'
        end
        if survives then
            local clear=#c.spells:blockers(m,aim,origin)==0
            for _,other in ipairs(rows) do if other~=row then
                local distance,t=U.segment(other.pos,origin,aim)
                local uncertainty=fog and 25 or 0
                if t>0 and t<1 and distance<c.profile.qRadius+other.radius+uncertainty then clear=false;break end
            end end
            if clear then
                local score=U.dist(origin,aim);local health=row.maxHealth or row.health or m.health
                if report and score<=c.profile.qRange then report.reason='Eligible' end
                if score<=c.profile.qRange and (not bestHealth or health>bestHealth or health==bestHealth and score<bestScore) then
                    best,bestScore,bestHealth=row,score,health
                end
            end
        end
    end
    if best then best.source=source or 'visible monster' end
    self.entryShotReason=best and 'Clear surviving target found' or 'No clear surviving target in Q range'
    return best
end
function F:walkDestination(camp)
    -- Camp icon/manager coordinates may sit beside the monsters or have no
    -- ground height. Prefer a live member's actual world position for walking.
    local main
    for _,m in ipairs(camp.members or {}) do
        if self:ordinaryTarget(m) and (not main or (m.maxHealth or m.health)>(main.maxHealth or main.health)) then main=m end
    end
    return main and main.pos or camp.walkPos or camp.pos
end
function F:travel(camp,target)
    local c=self.ctx;local now=c:now()
    if camp.nativeUp==false or camp.awaitingRespawn or (c:spell(0).level or 0)==0 or P.epics[camp.category] or not c.config:get('farmQTravel') or not c.config:get('autoClearAbilities') or not c.config:get('autoClearQ')
        or not c.config:get('autoClearQ2') or c:dash() or c:threats(camp.pos,1000)>0 or c:underTurret(camp.pos) then
        self.travelTarget=nil;self.travelJob=nil;return false
    end
    if U.dist(myHero.pos,target.pos)<=c:attackRange(target)+40 then
        self.travelTarget=nil;self.travelJob=nil;return false
    end
    if self.travelTarget then
        local found=false
        for _,m in ipairs(camp.members or {}) do
            if U.valid(m) and c:mark(m) then
                found=true
                if c.spells:q2(m,'farm',false,true,true) then self.travelTarget=nil;self.travelJob=nil;if c.config.capture then c:log('camp_q2_entry') end;return true end
            end
        end
        if now>(self.travelUntil or 0) or not U.valid(self.travelTarget) then self.travelTarget=nil
        elseif found or c:stage(0)==1 then c.moveTarget=self:walkDestination(camp);return true
        else self.travelTarget=nil end
    end
    if not c:ready(0) or c:stage(0)~=1 then return false end
    -- If the selected visible monster is already quicker to reach on a clear
    -- walking line, skip expensive formation damage/collision enumeration.
    -- Pending Q follow-ups above still run; a wall preserves the entry search.
    if U.dist(myHero.pos,target.pos)<=650 and not self:entryFaster(target.pos)
        and self:kiteLine(myHero.pos,target.pos) then return false end
    -- Seeing an outer small monster must not disable the earlier, durable
    -- main-monster shot from the same camp's recorded formation.
    if c.config:get('farmQBlind') then
        local fogShot=self:entryShot(camp,myHero.pos,true)
        if fogShot and not U.valid(fogShot.unit) and self:probeCamp(camp) then return true end
    end
    local shot=self:entryShot(camp)
    if shot and self:entryFaster(shot.pos) and U.dist(myHero.pos,shot.pos)<=c.profile.qRange and c.spells:q1(shot.unit,'farm',false,function()
        return self:entryAvailable(camp) and self:qSurvives(shot.unit,
            .25+U.dist(myHero.pos,shot.unit.pos)/c.profile.qSpeed+c.latency),'entry_target_may_die'
    end) then
        self.travelTarget=shot.unit;self.travelUntil=now+2;c.moveTarget=self:walkDestination(camp)
        if c.config.capture then c:log('camp_q1_entry',{target=U.id(shot.unit),name=shot.unit.charName,
            health=shot.unit.health,upper=self:qEntryUpper(shot.unit),camp=camp.id,source=shot.source}) end
        return true
    end
    -- Reposition around small blockers for a durable target, instead of firing
    -- a travel Q that would kill its first collision and remove the recast.
    local durable
    for _,m in ipairs(camp.members or {}) do
        if U.valid(m) and self:qSurvives(m,1) and (not durable or m.maxHealth>durable.maxHealth) then durable=m end
    end
    return durable and self:entryPath(camp,durable) or false
end
function F:entryFaster(destination,origin)
    local c=self.ctx;origin=origin or myHero.pos
    local distance=U.dist(origin,destination)
    local walk=math.max(0,U.dist(myHero.pos,destination)-250)/math.max(1,myHero.ms or 350)
    local jump=U.dist(myHero.pos,origin)/math.max(1,myHero.ms or 350)+.25+distance/c.profile.qSpeed+distance/1800+c.latency
    return jump+.08<walk
end
function F:entryPath(camp,target)
    local c=self.ctx;local now=c:now()
    -- Opportunistic micro-adjustments only. The normal route remains one
    -- native click to the camp, never a separate stop at the Q range boundary.
    if self.returningHome or not c.config:get('farmQAdjust') or not c.terrain:trusted() or not c:ready(0) or c:stage(0)~=1 then
        self.travelJob=nil;return false
    end
    if U.dist(myHero.pos,camp.pos)>c.profile.qRange+90 then return false end
    local job=self.travelJob
    if job then
        if job.camp==camp.id and now<job.deadline and U.dist(myHero.pos,job.pos)>25 then
            c.moveTarget=job.pos;return true
        end
        self.travelJob=nil;self.microRetryAt=now+.5
        -- Never stop at an old aim point when the shot has become invalid.
        c.moveTarget=self:walkDestination(camp);return false
    end
    if now<(self.microRetryAt or 0) then return false end
    local toward=U.toward(myHero.pos,camp.pos,1)
    local dx,dz=toward.x-myHero.pos.x,toward.z-myHero.pos.z
    for _,offset in ipairs({45,-45,90,-90}) do
        local point={x=myHero.pos.x-dz*offset,y=myHero.pos.y,z=myHero.pos.z+dx*offset}
        if c.terrain:walkLine(myHero.pos,point,math.min(45,myHero.boundingRadius or 35)) then
            local shot=self:entryShot(camp,point,target==nil)
            if shot and U.dist(point,shot.pos)<=c.profile.qRange and self:entryFaster(shot.pos,point) then
                self.travelJob={camp=camp.id,pos=point,deadline=now+.6};c.moveTarget=point
                c.status='Small Q aim adjustment: '..camp.category;return true
            end
        end
    end
    return false
end
function F:probeCamp(camp)
    local c=self.ctx;local now=c:now()
    if not self:entryAvailable(camp) or (c:spell(0).level or 0)==0 or not c.config:get('farmQTravel') or not c.config:get('farmQBlind') or not c.config:get('autoClearAbilities')
        or not c.config:get('autoClearQ') or not c.config:get('autoClearQ2') or c:dash()
        or P.epics[camp.category] or c:threats(camp.pos,1000)>0 or c:underTurret(camp.pos) then
        self:entryDiagnostic(camp,not self:entryAvailable(camp) and 'Spawn not eligible for a probe'
            or (c:spell(0).level or 0)==0 and 'Q not learned' or 'Entry disabled or unsafe')
        self.probe=nil;return false
    end
    local probe=self.probe
    if probe and probe.camp~=camp.id then self.probe=nil;probe=nil end
    if probe and c.actions.syncWindow then
        local state=c.actions:syncWindow(probe)
        if state=='waiting' or state=='uncertain' then c.status='Waiting for Q input';return true end
        if state=='cancelled' then self.probe=nil;self.travelJob=nil;return false end
    end
    if probe then
        -- Fresh object enumeration avoids the camp grouping's 400 ms cache
        -- delaying a confirmed Q2. Never dash to a champion hit by the probe.
        if Game.MinionCount and Game.Minion then for i=1,U.count(Game.MinionCount(),4096) do
            local m=Game.Minion(i)
            if U.valid(m) and m.team==300 and U.dist(m.pos,camp.pos)<700 and c:mark(m) then
                local found=false;camp.members=camp.members or {}
                for _,known in ipairs(camp.members) do if U.same(known,m) then found=true;break end end
                if not found then camp.members[#camp.members+1]=m end
                if camp.awaitingRespawn then self:respawnObserved(camp,now) end
                camp.availability='observed_alive';camp.observedAt=now
                if c.spells:q2(m,'farm',false,true,true) then self.probe=nil;self.travelJob=nil;if c.config.capture then c:log('camp_probe_confirmed',{name=camp.category}) end;return true end
            end
        end end
        if now<=probe.deadline then c.moveTarget=self:walkDestination(camp);c.status='Walking / waiting for camp Q mark: '..camp.category;return true end
        self.probe=nil;self.travelJob=nil
        local visible=false;for _,m in ipairs(camp.members or {}) do if U.valid(m) then visible=true end end
        if not visible then
            camp.availability='unknown';camp.blockedUntil=now+20;camp.probeMissedAt=now;self.camp=nil;self.progressAt=nil
            c.status='Camp probe missed; selecting next camp';if c.config.capture then c:log('camp_probe_missed',{name=camp.category}) end;return true
        end
        if c.config.capture then c:log('camp_probe_missed_visible',{name=camp.category}) end;return false
    end
    if not c:ready(0) or c:stage(0)~=1 or camp.availability=='observed_empty' and not camp.awaitingRespawn then
        self:entryDiagnostic(camp,'Q unavailable / stage / empty camp');return false
    end
    local shot=self:entryShot(camp,myHero.pos,true)
    if not shot then self:entryDiagnostic(camp,self.entryShotReason or 'No eligible shot');return self:entryPath(camp) end
    local aim=U.copy(shot.pos)
    local route=self.camp
    if self:entryFaster(aim) and c.spells:q1Camp(aim,function()
        -- Camp observations, routing and menu changes can invalidate a fog
        -- probe while the input owner is busy. Do not shoot the old intent.
        if self.camp~=route or not self:entryAvailable(camp) or camp.availability=='observed_empty' and not camp.awaitingRespawn
            or not c.config:get('farmQTravel')
            or not c.config:get('farmQBlind') or not c.config:get('autoClearQ2')
            or c:threats(camp.pos,1000)>0 or c:underTurret(camp.pos) then return false,'camp_entry_changed' end
        return true
    end) then
        self.probe={camp=camp.id,aim=aim,event=c.actions.pending[0],deadline=now+.25+U.dist(myHero.pos,aim)/c.profile.qSpeed+math.max(.4,c.latency*2+c.jitter*3+.2)}
        c.status='Q approach: '..camp.category..' ['..shot.source..(camp.awaitingRespawn and '; respawn estimated' or '')..']'
        self:entryDiagnostic(camp,'Q probe requested')
        if c.config.capture then c:log('camp_probe_requested',{name=camp.category,origin=U.copy(myHero.pos),destination=aim,
            source=shot.source,respawnEstimate=camp.awaitingRespawn or false,
            targetName=shot.name or shot.unit and shot.unit.charName,distance=U.dist(myHero.pos,aim)}) end;return true
    end
    self:entryDiagnostic(camp,not self:entryFaster(aim) and 'Walking is faster from current position' or 'Q dispatch / visible collision blocked')
    return self:entryPath(camp)
end
function F:fastTick()
    local c=self.ctx;local camp=self.camp
    if self.recallAction or self.state=='recalling' or not camp or not self:entryAvailable(camp) or P.epics[camp.category] or not (self.probe or self.travelTarget) or c.input.farmPaused or not c.config:get('autoJungle')
        or not c.config:get('farmQTravel') or not c.config:get('autoClearAbilities') or not c.config:get('autoClearQ2')
        or self.probe and not c.config:get('farmQBlind') or c:threats(camp.pos,1000)>0
        or c:blocked() or c:recalling() or c:dash() then return false end
    self.actions:tick()
    if Game.MinionCount and Game.Minion then for index=1,U.count(Game.MinionCount(),4096) do
        local m=Game.Minion(index)
        if U.valid(m) and m.team==300 and U.dist(m.pos,camp.pos)<700 and c:mark(m) then
            if camp.awaitingRespawn then self:respawnObserved(camp,c:now()) end
            if c.spells:q2(m,'farm',false,true,true) then
                self.probe=nil;self.travelTarget=nil;self.travelJob=nil
                if c.config.capture then c:log('camp_q2_entry',{target=U.id(m),immediate=true}) end;return true
            end
        end
    end end
    return false
end
require('lho.recovery')(F)
return F
