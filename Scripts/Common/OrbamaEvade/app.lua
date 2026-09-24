local G=require('evade.geometry')
local Terrain=require('evade.terrain')
local Threats=require('evade.threats')
local Planner=require('evade.planner')
local Observer=require('evade.observer')
local Defenses=require('evade.defenses')
local Metrics=require('evade.diagnostics')
local createClient=require('ActionClient')
local A={};A.__index=A
function A.new(g)
    local self=setmetatable({g=g,sdk=g.SDK,active=true,intervening=false,reason='starting',serial=0,
        build='OrbamaEvade-2',permissions={items=true,ultimates=false,summoners=false},enabled=true,
        nextDecision=0,nextMove=0,pending={},hooks={},adapters={}},A)
    self.clock=function()return self.sdk.Actions:Now()end
    self.client=createClient(g,{name='OrbamaEvade',active=function()return self.active end})
    self.terrain=Terrain.new(nil,g.myHero.team);self.threats=Threats.new()
    self.planner=Planner.new(self.terrain,self.threats);self.defenses=Defenses.new()
    self.observer=Observer.new(g,self.threats,require('evade.catalog'));self.metrics=Metrics.new(self.clock)
    return self
end
function A:GetState()
    return {active=self.active and self.intervening,enabled=self.enabled,reason=self.reason,build=self.build,
        threatRevision=self.threats.revision,terrainRevision=self.terrain.revision,profile=self.profile,
        threats=#self.threats.list,coverage='partial',mapReady=self.terrain.grid~=nil,decisionAt=self.decisionAt}
end
function A:Evading()return self.active and self.intervening end
function A:Context()
    local h=self.g.myHero;local now=self.g.Game.Timer()
    local aim=self.sdk.Actions:GetPlayerPosition()
    local spell=h.activeSpell;local windup=spell and spell.valid and spell.isAutoAttack and math.max(0,(spell.castEndTime or now)-now)or 0
    return {origin=G.copy(h.pos),now=now,speed=h.ms,radius=h.boundingRadius,heroID=h.networkID,
        budgetClock=self.clock,decisionBudgetMs=4,
        profile=h.charName:match('^Jade_')and 'classic'or 'normal',intent=G.copy(aim or h.pos),
        delay=.035+windup,stats={health=h.health,armor=h.armor,magicResist=h.magicResist,
            shield=h.allShield or 0,physicalShield=h.shieldAD or 0,magicShield=h.shieldAP or 0}}
end
function A:EvaluatePath(path,context)return self.planner:Evaluate(path,context or self:Context())end
function A:EvaluateDefense(option,path,context)
    if type(option)~='table'or option.validated~=true then return {safe=false,known=false,reason='defense_unverified'}end
    local ctx=context or self:Context()
    if option.profile~=ctx.profile then return {safe=false,known=false,reason='defense_profile_mismatch'}end
    return self.planner:Evaluate(path or {ctx.origin},ctx,option.effect)
end
function A:RegisterDefense(name,adapter)return self.defenses:Register(name,adapter)end
function A:RegisterController(name,adapter)
    local old=self.adapters[name]
    if old and old.active then local ok,active=pcall(old.active);if ok and active==false then self.adapters[name]=nil end end
    if self.adapters[name]or type(adapter)~='table'or type(adapter.committed)~='function'or type(adapter.yield)~='function'then return false end
    self.adapters[name]=adapter;return true
end
function A:ReleaseCommitments(result)
    local policies={};for _,a in pairs(self.adapters)do policies[#policies+1]=a end
    for _,c in pairs(self.sdk.ActionClientHub and self.sdk.ActionClientHub.clients or {})do
        if not c.closed and c:IsActive()and c.evadePolicy then policies[#policies+1]=c.evadePolicy end
    end
    for _,a in ipairs(policies)do
        local ok,committed=pcall(a.committed)
        if not ok then return false,'controller_state_unknown'end
        if committed then
            if not result.lethal or result.unknown then return false,'champion_commitment'end
            local yes,released=pcall(a.yield,{likelyDeath=true,expires=self.clock()+100,reason='evade_likely_death'})
            if not yes or released~=true then return false,'champion_release_pending'end
        end
    end
    return true
end
-- Called by a map observation adapter. A map ID alone never selects a variant.
function A:BindTerrain(observation)
    local maps=require('evade.mapdata')
    if type(observation)~='table'or observation.observed~=true or observation.mapID~=self.g.Game.mapID
        or type(observation.variant)~='string'or type(observation.source)~='string'
        or type(observation.liveWall)~='function' then return false,'map_observation_required'end
    local map=maps[observation.mapID];local name=map and map.variants[observation.variant]
    local factory=name and map.grids[name]
    if not factory then return false,'map_variant_unavailable'end
    local grid=factory()
    if observation.navigationHash~=grid.sha256 then return false,'map_asset_mismatch'end
    self:Cancel('terrain_changed');self.terrain.grid=grid;self.terrain.live=observation.liveWall
    self.terrain.revision=self.terrain.revision+1;self.terrain:SetUnknown(false)
    self.mapID=observation.mapID;self.profile=observation.variant;return true
end
function A:Cancel(reason)
    self.serial=self.serial+1;self.intervening=false;self.reason=reason
    self.client:CancelOwner('walking',reason);self.client:CancelOwner('defense',reason)
    self.client:SetBlocked('evade','attack',false);self.client:SetBlocked('evade','move',false)
    self.route=nil
end
function A:Bypass()
    return self.menu and self.menu.Bypass:Value()or self.bypass==true
end
function A:Available()
    return self.active and self.enabled and not self:Bypass()and not self.g.myHero.dead
        and self.g.Game.IsOnTop()and not self.g.Game.IsChatOpen()
end
function A:PrepareMove(route,context)
    -- Route evaluation always runs before positioning. The certificate and guard
    -- retain only immutable revisions, coordinates and a short monotonic expiry.
    local destination=G.copy(route.path[1]);local deadline=self.clock()+100
    local generation=self.serial;local certificate
    local function guard()
        return self:Available()and generation==self.serial and certificate~=nil
            and certificate.threat==self.threats.revision and certificate.terrain==self.terrain.revision
            and self.clock()<=certificate.expires,'evade_preparation_stale'
    end
    local intent={type='move',kind='world',target=destination,owner='walking',resource='evade:movement',
        priority='critical',expires=deadline,prevalidateWorldMove=true,
        commitGuard=guard,mechanical=function()return guard()end,
        resolve=function()
            if not self:Available()or self.serial~=generation then return nil,'evade_cancelled'end
            local fresh=self:Context();fresh.delay=.035
            local evaluated=self:EvaluatePath(route.path,fresh)
            if not evaluated.known or not evaluated.safe then return nil,'evade_route_changed'end
            certificate={threat=self.threats.revision,terrain=self.terrain.revision,expires=math.min(deadline,self.clock()+20)}
            return {position=destination,data={threatRevision=certificate.threat,terrainRevision=certificate.terrain}}
        end,
        reconcile=function()return true end}
    return intent
end
function A:Collect()
    self.client:Collect()
    for id,record in pairs(self.pending)do
        local r=self.client:Poll(id)
        if r and r.sentAt and not record.measured then
            record.measured=true
            self.metrics:Sample('queue_ms',r.acquiredAt and r.acquiredAt-r.requestedAt or 0)
            if r.positionedAt then self.metrics:Sample('position_to_send_ms',r.sentAt-r.positionedAt)end
        end
        if not r or r.state=='cancelled_before_send'then self.client:Finish(id);self.pending[id]=nil
        elseif r.releasedAt and not r.cleanupPending then
            if r.acquiredAt then self.metrics:Sample('cursor_ownership_ms',r.releasedAt-r.acquiredAt)end
            -- Release input/resource bookkeeping, preserving historical uncertainty.
            self.client:Finish(id,'input settled; gameplay effect unverified');self.pending[id]=nil
        end
    end
end
function A:Tick()
    if not self.active then return end
    self:Collect()
    if self.menu then self.enabled=self.menu.Enabled:Value();self.permissions.items=self.menu.Items:Value()
        self.permissions.ultimates=self.menu.Ultimates:Value();self.permissions.summoners=self.menu.Summoners:Value()end
    if not self:Available()then self:Cancel(self:Bypass()and 'bypass'or 'inactive_context');return end
    local now=self.g.Game.Timer();local start=self.clock()
    local ok,why=self.observer:Tick(now);self.metrics:Sample('observation_host_calls',self.observer.hostCalls or 0)
    if not ok then self:Cancel(why);return end
    if self.mapID and self.mapID~=self.g.Game.mapID then self.terrain.grid=nil;self.terrain:SetUnknown(true)end
    if not self.terrain.grid then self:Cancel('map_variant_unknown');return end
    if now<self.nextDecision then return end;self.nextDecision=now+.025
    if #self.threats.list==0 then self:Cancel('no_modeled_threat');return end
    local ctx=self:Context();local best,baseline=self.planner:Plan(ctx,self.route)
    self.decisionAt=now;self.metrics:Sample('decision_ms',self.clock()-start)
    if best then self.metrics:Sample('candidates',best.candidates);self.metrics:Sample('search_nodes',best.nodes)end
    if baseline.safe then self:Cancel('current_route_clear');return end
    if not best or not best.known then self:Cancel('no_evaluated_route');return end
    local released,reason=self:ReleaseCommitments(baseline)
    if not released then self:Cancel(reason);return end
    local chosen
    for _,candidate in ipairs(self.defenses:Options(ctx,self.permissions))do
        local option=candidate.option
        local result=self:EvaluateDefense(option,option.path or {ctx.origin},ctx)
        result.resourceCost=option.cost or 0
        if self.planner:Better(result,best,ctx)then best=result;chosen=candidate end
    end
    self.intervening=true;self.reason=chosen and 'defensive_action'or 'walking';self.route=best
    self.client:SetBlocked('evade','attack',true);self.client:SetBlocked('evade','move',true)
    if next(self.pending)or start<self.nextMove then return end
    if chosen then
        local intent=self.defenses:Prepare(chosen,ctx)
        if intent then
            intent.owner='defense';intent.priority='critical';intent.expires=math.min(intent.expires or start+100,start+100)
            if baseline.lethal and not baseline.unknown then self.client:RequestEmergencyRelease(intent.resource,{likelyDeath=true,expires=start+100})end
            local id,status=self.client:Submit(intent);if id then self.pending[id]={}else self.reason=status end
        end
    elseif best.safe and best.path and G.dist(best.path[1],ctx.origin)>5 then
        local id,status=self.client:Submit(self:PrepareMove(best,ctx))
        if id then self.pending[id]={};self.nextMove=start+60 else self.reason=status end
    else self:Cancel('no_safe_executable_response')end
end
function A:Shutdown()
    if not self.active then return end;self:Cancel('unload');self.active=false;self.client:Close('unload')
    for _,h in ipairs(self.hooks)do for i=#h.list,1,-1 do if h.list[i]==h.fn then table.remove(h.list,i)end end end
    if self.sdk.Evade==self then self.sdk.Evade=nil end
    if self.g.JustEvade==self.compat then self.g.JustEvade=nil end
end
function A:Install()
    self.sdk.Evade=self
    local function attach(list,fn)list[#list+1]=fn;self.hooks[#self.hooks+1]={list=list,fn=fn}end
    attach(self.sdk.OnTick,function()
        local ok,err=pcall(self.Tick,self);if not ok then self:Cancel('runtime_error');self.metrics:Event('error',tostring(err))end
    end)
    if self.g.MenuElement then
        self.menu=self.g.MenuElement({type=self.g.MENU,id='OrbamaEvade',name='Orbama Evade'})
        for _,v in ipairs({{id='Enabled',name='Enable evade',value=true},{id='Bypass',name='Hold to bypass',key=17},
            {id='Items',name='Defensive items',value=true},{id='Ultimates',name='Use ultimates',value=false},
            {id='Summoners',name='Use summoner spells',value=false}})do self.menu:MenuElement(v)end
    end
    self.compat={Evading=function()return self:Evading()end}
    if not self.g.JustEvade then self.g.JustEvade=self.compat end
    if self.g.Callback and self.g.Callback.Add then self.g.Callback.Add('UnLoad',function()self:Shutdown()end)end
    -- Optional host adapter, never inferred from a map number or champion name.
    if type(self.g.OrbamaEvadeMapObservation)=='function'then
        local ok,observation=pcall(self.g.OrbamaEvadeMapObservation)
        if ok then self:BindTerrain(observation)end
    end
end
function A.boot(g)
    -- Host library order is not provider readiness. Keep one inert bootstrap
    -- until Orbama publishes its API, without loading or replacing any provider.
    local pending=g.OrbamaEvadeBootstrap
    if pending and pending.waiting then return end
    local state={waiting=true};g.OrbamaEvadeBootstrap=state
    local function stop()
        state.waiting=false
        if g.OrbamaEvadeBootstrap==state then g.OrbamaEvadeBootstrap=nil end
        if g.Callback and g.Callback.Del then
            if state.tick then pcall(g.Callback.Del,'Tick',state.tick)end
            if state.unload then pcall(g.Callback.Del,'UnLoad',state.unload)end
        end
    end
    local function attempt()
        if not state.waiting then return end
        local sdk=g.SDK
        if not sdk or not sdk.OrbamaVersion or not sdk.Actions or type(sdk.OnTick)~='table' then return end
        if sdk.Evade then stop();return sdk.Evade end
        if g.JustEvade or g.ExtLibEvade then
            stop();if g.print then g.print('[OrbamaEvade] Another evade provider is present; unload it before enabling OrbamaEvade.')end;return
        end
        local caps=type(sdk.Actions.GetCapabilities)=='function'and sdk.Actions:GetCapabilities()
        if not caps or not caps.prevalidateWorldMove then
            stop();if g.print then g.print('[OrbamaEvade] Reload the updated Orbama provider first.')end;return
        end
        stop();local self=A.new(g);self:Install();return self
    end
    local ready=attempt()
    if not state.waiting then return ready end
    if g.Callback and g.Callback.Add then
        state.tick=attempt;state.unload=stop
        g.Callback.Add('Tick',state.tick);g.Callback.Add('UnLoad',state.unload)
        if g.print then g.print('[OrbamaEvade] Waiting for Orbama to initialize.')end
    else
        stop();if g.print then g.print('[OrbamaEvade] Orbama is unavailable and the host has no startup callback.')end
    end
end
return A
