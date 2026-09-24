local U=require('kata.util');local Ward=require('ChampionMobility.wards')(U)
local Nav=require('ChampionMobility.navigation')(U,require('kata.navdata'))
local Terrain=require('ChampionMobility.terrain')(U,Nav)
local M={};M.__index=M
function M.new(c)
    local wardContext={profile=c.profile,spell=function(_,slot)return c:spell(slot)end,ready=function(_,slot)return c.state:ready(slot)end}
    local self=setmetatable({c=c,ctx=wardContext,actions=c.actions,doneHeld=false},M)
    self.terrain=Terrain.new(c);return self
end
M.itemReady=Ward.itemReady;M.slot=Ward.slot;M.hasCharges=Ward.hasCharges
function M:cancel(reason)
    if self.pending then self.c.actions:cancel(self.pending.owner,reason);self.pending=nil end
    self.preview=nil;self.job=nil
end
function M:existing(pos)
    local best,dist
    for _,o in ipairs(self.c:anchors())do local d=U.dist(o.pos,pos)
        if self.c:anchorValid(o)and d<150 and(not dist or d<dist)then best,dist=o,d end
    end
    return best
end
function M:start(pos,owner,target)
    local c=self.c
    if self.pending or not c:ready(2)then return false end
    local anchor=self:existing(pos)
    if anchor then
        local a={slot=2,target=anchor,anchor=anchor,dagger=c.state.daggers[U.id(anchor)],owner=owner,escape=owner~='combo',release=true,
            pos=c.profile.id=='normal'and c:landing(anchor,nil,nil,c.state.daggers[U.id(anchor)])or nil}
        local ok,record=c.actions:submit(a)
        if ok then self.pending={state='jumping',owner=owner,event=record,at=Game.Timer(),expires=Game.Timer()+2};return true end
        return false
    end
    if c.profile.id=='normal'then return false end
    local slot=self:slot();if not slot or U.dist(c.hero.pos,pos)>c.config:get('wardRange')or self.terrain:wall(pos)~=false then return false end
    if not c.planner:safe(pos,target,owner~='combo')then return false end
    if owner=='combo'and(not U.valid(target)or not c.planner:estimate(target,pos,2).lethal or not c.planner:safe(pos,target))then return false end
    local ids={};for _,w in ipairs(c.state.objects.wards or {})do if U.id(w)then ids[U.id(w)]=true end end
    local p={state='placing',owner=owner,pos=U.copy(pos),ids=ids,target=target,at=Game.Timer(),expires=Game.Timer()+2}
    local ok,record=c.actions:submit({slot=slot,pos=pos,owner=owner,ward=true,release=true,
        validate=function()return c.state:ready(2)and self:itemReady(slot,nil,true)and self:hasCharges(slot)and self.terrain:wall(pos)==false and c.planner:safe(pos,target,owner~='combo')
            and U.dist(c.hero.pos,pos)<=c.config:get('wardRange')and(owner~='combo'or U.valid(target)and c.planner:estimate(target,pos,2).lethal and c.planner:safe(pos,target))end})
    if ok then p.event=record;self.pending=p;return true end
    return false
end
function M:advance()
    local c=self.c;local p=self.pending;if not p then return false end
    if not c:ownerActive(p.owner)or Game.Timer()>p.expires then self:cancel('jump_context_expired');return false end
    if p.state=='placing'then
        local raw=c.actions.client:Poll(p.event.id)
        if raw and raw.state=='cancelled_before_send'then self:cancel('ward_not_sent');return false end
        if raw and raw.sentAt then
            local match
            for i=1,U.count(Game.WardCount and Game.WardCount()or 0,512)do local w=Game.Ward(i)
                local owner=w and(w.ownerID or w.ownerNetworkID)
                if U.valid(w)and w.team==c.hero.team and not p.ids[U.id(w)]and U.dist(w.pos,p.pos)<90
                    and(not owner or owner==0 or owner==U.id(c.hero)or owner==c.hero.handle)then
                    if match then self:cancel('ambiguous_new_wards');return false end;match=w
                end
            end
            if match then
                c.actions.client:Observe(p.event.id,{kind='mechanical',unique=true,at=c.actions.client:Now(),source='new_ward_identity'})
                p.event.observed=true;p.anchor=match;p.state='ward_ready'
            end
        end
    end
    if p.state=='ward_ready'then
        if not c:anchorValid(p.anchor)then self:cancel('ward_lost');return false end
        local function check()
            return U.valid(p.anchor)and c:anchorValid(p.anchor)and(p.owner~='combo'or U.valid(p.target)and c.planner:estimate(p.target,p.anchor.pos,2).lethal and c.planner:safe(p.anchor.pos,p.target))
        end
        if not check()then self:cancel('followup_no_longer_valid');return false end
        local ok,event=c.actions:submit({slot=2,target=p.anchor,anchor=p.anchor,owner=p.owner,escape=p.owner~='combo',release=true,validate=check})
        if ok then p.event=event;p.state='jumping'end
    end
    if p.state=='jumping'then
        if p.event.observed then self.doneHeld=true;self.pending=nil;return false end
        if p.event.finished then self:cancel('jump_unconfirmed');return false end
    end
    return true
end
function M:plan(raw)
    local c=self.c;local p
    if not c.config:get('wardAssist')then return end
    if c.profile.id=='classic'then
        local direct=self.terrain:landing(c.hero.pos,raw,math.min(c.profile.eRange,c.config:get('wardRange')),self.preview)
        if direct and direct.valid then self.preview=direct;return direct end
        if not c.config:get('wardApproach')then return direct end
        if not self.job or U.dist(self.job.raw,raw)>75 then
            self.job={raw=U.copy(raw),work=coroutine.create(function()
                return self.terrain:plan(U.copy(c.hero.pos),raw,math.min(c.profile.eRange,c.config:get('wardRange')),self.preview,function()coroutine.yield()end,direct)
            end)}
        end
        local ok,result=coroutine.resume(self.job.work)
        if not ok then self.job=nil;return end
        if coroutine.status(self.job.work)=='dead'then self.job=nil;if result and result.valid then self.preview=result end end
        p=self.preview
    else
        -- W stays on the near side. Only a real, correlated dagger authorizes E.
        local entry,exit=self.terrain:cursorCrossing(c.hero.pos,raw,250)
        if entry and exit and U.dist(entry,exit)<=200 then
            local near=U.toward(entry,c.hero.pos,45);local far=U.toward(exit,raw,40)
            if self.terrain:wall(near)==false and self.terrain:wall(far)==false and U.dist(near,far)<=c.profile.eOffset then
                p={valid=true,stand=near,pos=far,kind='modern_wall'};self.preview=p
            end
        end
    end
    return p
end
function M:tick(owner)
    local c=self.c
    if self:advance()then return true end
    if not owner then self.doneHeld=false;self.job=nil;self.preview=nil;return false end
    if self.doneHeld then return true end
    local raw=c:mouse();if not raw then return true end
    if not c:ready(2)then return true end
    if self:start(raw,owner)then return true end
    local p=self:plan(raw);if not p or not p.valid then return true end
    if p.kind=='modern_wall'then
        if U.dist(c.hero.pos,p.stand)>30 then
            if U.dist(c.hero.pos,p.stand)<=c.config:get('wardWalkRange')and self.terrain:walkLine(c.hero.pos,p.stand,35)then c.actions:submit({kind='move',pos=p.stand,owner=owner,release=true})end
        else
            local dagger
            for _,d in pairs(c.state.daggers)do if c.state:daggerValid(d)and U.dist(d.pos,p.stand)<=50 then dagger=d;break end end
            if dagger then
                local ok,record=c.actions:submit({slot=2,owner=owner,pos=p.pos,anchor=dagger.object,dagger=dagger,side=U.copy(p.pos),escape=true,release=true})
                if ok then self.pending={state='jumping',owner=owner,event=record,expires=Game.Timer()+2}end
            elseif c:ready(1)then c.actions:submit({slot=1,owner=owner,prepareWall=true,release=true})end
        end
    elseif U.dist(c.hero.pos,p.pos)<=math.min(c.profile.eRange,c.config:get('wardRange'))then self:start(p.pos,owner)
    elseif c.config:get('wardApproach')and p.walkTo and U.dist(c.hero.pos,p.walkTo)<=c.config:get('wardWalkRange')then
        c.actions:submit({kind='move',pos=p.walkTo,owner=owner,release=true,validate=function()return self.terrain:wall(p.walkTo)==false end})
    end
    return true
end
return M
