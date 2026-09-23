local U=require('lho.util');local P=require('lho.profiles')
local App={};App.__index=App
function App.new(options)
    local p=assert(P.get(myHero.charName),'Unsupported champion')
    local c=require('lho.runtime').new(p,require('lho.config').new(p))
    c.originalGG=options and options.originalGG==true
    c.actions=require('lho.actions').new(c)
    c.input=require('lho.input').new(c)
    c.terrain=require('lho.terrain').new(c)
    c.wards=require('lho.wards').new(c,c.actions,c.terrain)
    c.smite=require('lho.smite').new(c,c.actions)
    c.spells=require('lho.spells').new(c,c.actions,c.smite)
    c.emergencyShield=require('lho.emergencyshield').new(c)
    c.combat=require('lho.combat').new(c,c.actions,c.spells,c.wards)
    c.leveling=require('lho.leveling').new(c)
    c.farm=require('lho.farm').new(c,c.actions,c.spells,c.smite)
    c.clear=require('lho.clear').new(c)
    c.wave=require('lho.wave').new(c)
    c.actives=require('lho.actives').new(c,c.actions)
    c.damageModel=require('lho.damage').new(c)
    c.overlay=require('lho.overlay').new(c)
    c.guide=require('lho.guide').new(c)
    c.telemetry=require('lho.telemetry').new(c)
    c.aim=c:playerPosition()
    return setmetatable({ctx=c,active=true,hooks={},build=require('lho.profiles').build},App)
end
function App:ggMode(name)
    local c=self.ctx;local id=c.sdk['ORBWALKER_MODE_'..name]
    if id==nil then return false end
    local orb=c.sdk.Orbwalker
    if orb.HasMode then return orb:HasMode(id) end
    return orb.Modes and orb.Modes[id] or false
end
function App:localClearTarget()
    return self.ctx.farm:localTarget(self:ggMode('LANECLEAR'),self:ggMode('JUNGLECLEAR'))
end
function App:mode()
    local c=self.ctx;local i=c.input
    if c:blocked() then return 'blocked' end
    i:reconcileSuspended()
    if next(i.suspended) then return 'reserved' end
    if i:held('wardKey') then return 'ward' end
    if i:held('cursorKey') then return 'cursor' end
    if i:held('allyKey') then return 'ally' end
    if i:held('secureKey') then return 'secure' end
    if i:held('qKey') then return 'q' end
    if c.wards.pending then return 'ward_pending' end
    if self:ggMode('COMBO') then return 'fight' end
    if self:ggMode('LASTHIT') then return 'gg_last' end
    if self:ggMode('LANECLEAR') or self:ggMode('JUNGLECLEAR') then return 'clear' end
    if self:ggMode('HARASS') then return 'harass' end
    if self:ggMode('FLEE') then return 'gg' end
    if c.config:get('autoJungle') then return 'farm' end
    return 'idle'
end
function App:impact(target)
    local c=self.ctx;local speed=c.sdk.Attack and c.sdk.Attack.GetProjectileSpeed and c.sdk.Attack:GetProjectileSpeed() or math.huge
    return c:windup()+c.latency*.5+(speed>0 and U.dist(myHero.pos,target.pos)/speed or 0)
end
function App:laneMinion(target)
    if not U.valid(target) or target.team==300 or target.team==myHero.team then return false end
    for _,m in ipairs(self.ctx.minions or {}) do if U.same(m,target) then return true end end
    return false
end
function App:preAttack(args)
    if not self.active then return end
    local c=self.ctx;local mode=self:mode()
    if not c.config:get('enabled') then return end
    if c.actions:smiteOwnsInput() then args.Process=false;return end
    if mode=='idle' then return end
    if mode=='blocked' or c.wards.pending or c.leveling.pending or c:dash()
        or mode=='fight' and c:combatTransit() then args.Process=false;return end
    if not args.Process then return end
    if (mode=='gg_last' or mode=='clear') and self:laneMinion(args.Target) and c.wave:attackLocked() then
        args.Process=false;return
    end
    if mode=='gg_last' then
        if self:laneMinion(args.Target) then
            if c.wave:tick(args.Target,true,true) then args.Process=false
            else
                local other,last=c.wave:attackTarget(args.Target)
                if other and last then args.Target=other
                elseif c.wave:reservedTarget(args.Target) then args.Process=false end
            end
        end
        return
    end
    if mode=='harass' or mode=='gg' then return end
    local target
    if mode=='fight' then
        -- GG already chose this attack using its own priorities and selection.
        if c.sdk.TargetSelector and c.sdk.TargetSelector.GetTarget then
            target=args.Target
            if c:enemyValid(target) then c.attackFocus={target=target,at=c:now(),selected=c:locked()} end
        else target=c:target(c.profile.q2Range) end
    elseif mode=='clear' then
        local anchor=self:localClearTarget()
        if anchor and anchor.team~=300 then
            if c.wave:tick(anchor,true) then args.Process=false;return end
            target=c.wave:attackTarget(anchor)
        else target=anchor end
    elseif mode=='farm' then
        target=c.attackTarget
        if P.epics[P.category(args.Target and args.Target.charName)] or P.epics[P.category(target and target.charName)] then args.Process=false;return end
        if target and not self:laneMinion(target) and target.team~=300 then target=nil end
    elseif mode=='cursor' or mode=='ally' then
        if self.insecSuppressed or not c.combat:insecOrbwalkAllowed() then args.Process=false;return end
        target=c.attackTarget
    end
    if args.Approach then
        args.Process=mode=='farm' and U.valid(target) and U.same(target,args.Target)
            and (c.farm.kiteStep and c.farm.kiteStep.phase=='attack'
                or (c.farm.state=='clearing' or c.farm.state=='finishing')
                    and U.dist(myHero.pos,target.pos)>c:attackRange(target)) or false
        return
    end
    if not U.valid(target) or U.dist(myHero.pos,target.pos)>c:attackRange(target) then args.Process=false;return end
    args.Target=target
    if (mode=='farm' or mode=='clear' and target.team==300) and c.clear:tick(target,mode,true) then args.Process=false end
end
function App:preMove(args)
    if not self.active then return end
    local c=self.ctx;local mode=self:mode()
    if not c.config:get('enabled') then return end
    if c.actions:smiteOwnsInput() then args.Process=false;return end
    if mode=='idle' then return end
    if (mode=='cursor' or mode=='ally') and not c.dispatchMovement then args.Process=false;return end
    if (c.wards.pending and not ((c.wards.pending.state=='approaching'
        or c.wards.pending.state=='jumping' and c.wards.pending.owner=='ward' and c.config:get('wardFollowCursor')) and c.dispatchMovement))
        or c.leveling.pending or mode=='blocked' then args.Process=false;return end
    -- Local clear inherits GG cursor orbwalking immediately, including when
    -- jungle and lane clear share a key. Routing/kiting ownership belongs to J.
    if mode=='fight' or mode=='clear' or mode=='gg_last' or mode=='harass' or mode=='gg' then
        if not c.sdk.Orbwalker.ForceMovement then
            local destination=args.Target or (c.sdk.Cursor.GetPlayerPosition and c.sdk.Cursor:GetPlayerPosition()) or c.aim or mousePos
            if destination then
                local point=require('lho.ground').select(c,destination.pos or destination)
                if point then args.Target=U.vector(point) else args.Process=false end
            end
        end
        return
    end
    if not c.dispatchMovement or c.sdk.Orbwalker.ForceMovement then args.Process=false;return end
    args.Target=U.vector(c.dispatchMovement)
end
function App:cancel(reason,manual)
    local c=self.ctx;c.wards:cancel(reason);c.combat:cancel();c.leveling:cancel()
    if c.mode=='cursor' or c.mode=='ally' then c.actions:cancel(c.mode) end
    c.actions:releaseMinimap(true,manual)
    c.actions.routeStop=nil;c.actions.routeObservation=nil
    c.spells.afterSmite=nil;c.combat.rFollow=nil;c.combat.multiTarget=nil
    c.attackTarget=nil;c.moveTarget=nil
end
function App:event(msg,param)
    if not self.active then return end
    local c=self.ctx
    if c.guide and c.guide:event(msg,param) then return end
    c.input:event(msg,param)
    if c.input.pressed.wardKey and c.input:held('wardKey') and not c.synthetic then
        c.input.wardContinuation=c.wards:retainCommitted()
        if not c.input.wardContinuation then c.wards:cancel('Wardjump re-aim',true);c.wards:resetPreview() end
        c.input.pressed.wardKey=nil
    end
    if msg==516 and c.input.cancel then c.localManualMovement=true end
    if c.input.cancel then
        self:cancel('Manual cancellation',true)
        c.input.pressed.cursorKey=nil;c.input.pressed.allyKey=nil
    end
    -- WndMsg can contain an entire tap between frames. Commit on the release event.
    if c.input.released.wardKey then
        c.input.released.wardKey=nil
        local continuation=c.input.wardContinuation;c.input.wardContinuation=nil
        if not continuation and not c.input.wardCancelled and not c:blocked() then
            if not c.actions:cursorBusy() then c.aim=c:playerPosition() end
            local preview=c.wards:releasePreview(c.aim)
            if preview.valid then
                if not c.wards:requestPlan(preview,'ward') then c.status='Wardjump could not be accepted' end
            else c.status=preview.reason or 'Invalid wardjump';c.wards:diagnostics(c.status);if c.config.capture then c:log('ward_invalid',{reason=c.status}) end end
        end
    end
    if c.combat.insec then
        local bind=c.combat.insec.kind=='cursor' and 'cursorKey' or 'allyKey'
        if not c.input:held(bind) then c.combat:cancel() end
        if c.combat.insec and not c.input:previewHeld() then c.combat:confirmPreview() end
    end
end
function App:secure()
    local c=self.ctx;local best
    for _,m in ipairs(c.minions or {}) do
        if m.team==300 and U.valid(m) and P.epics[P.category(m.charName)] and U.dist(myHero.pos,m.pos)<=c.profile.qRange then
            if not best or m.health<best.health then best=m end
        end
    end
    if not best then c.status='Secure: no visible epic in reach';return end
    c.status='Securing '..P.category(best.charName)
    if c.smite:cast(best,'secure',true) then return end
    if c:mark(best) then
        -- Current health only: never assume another player's future damage.
        local budget=c:damage(0,best,2)+(c.smite:ready() and c.smite:damage() or 0)
        if budget>=U.effectiveHP(best)+c.config:get('smiteMargin') then c.spells:q2(best,'secure',false) end
    elseif c:stage(0)==1 then c.spells:q1(best,'secure',false) end
end
function App:tick()
    if not self.active then return end
    local c=self.ctx;c.actions:tick();c:refresh()
    -- A lethal objective gets the first legal cast opportunity before Q2,
    -- auto-leveling or ordinary combat can consume this tick's dispatcher.
    local previewInput=c.input:previewHeld() and (c.input:held('cursorKey') or c.input:held('allyKey'))
    if not c:blocked() then c.smite:auto() end
    c.wards:fastTick(true)
    c.combat:fastKick()
    -- Release a prepared post-attack move before diagnostic snapshots and
    -- other controllers can consume this callback's response window.
    if self:mode()=='farm' then c.farm:fastKite();c.farm:fastTick() end
    if c.config:get('combatLogging') then c.telemetry:safe('tick') end
    if c.config:get('playtestLogging') then
        local token=c.performance and c.performance:begin('playtest.tick')
        require('lho.playtest').tick(c)
        if c.performance then c.performance:finish(token) end
    end
    if c.sdk.Input or not c.actions:cursorBusy() then c.aim=c:playerPosition() end
    local mode=self:mode()
    local ggOwned=mode=='fight' or mode=='clear' or mode=='gg_last' or mode=='harass' or mode=='gg'
    if ggOwned then c.input:pauseFarm('GG mode '..mode) end
    if mode=='blocked' then
        local resume=c.config:get('autoJungle') and c.config:get('enabled') and not myHero.dead
        self:cancel('Chat / focus / champion unavailable',true);c.input:reset(resume)
        c.mode='blocked';c.status='Paused: chat / focus / unavailable';return
    end
    -- Skill allocation is independent of GG mode and auto-jungle ownership.
    if not previewInput then c.leveling:tick() end
    if c.input.cancel then self:cancel('Manual cancellation',true) end
    if mode~=c.mode then
        if mode=='clear' or c.mode=='clear' then c.farm.localCamp=nil;c.localManualMovement=false end
        if c.mode=='fight' then c.combat.rFollow=nil;c.combat.multiTarget=nil;c.attackFocus=nil;c.actions:cancel('fight') end
        if c.mode=='harass' then c.actions:cancel('harass') end
        if c.mode=='clear' or c.mode=='gg_last' then c.actions:cancel('clear');c.actions:cancel('harass') end
        if c.mode=='q' or c.mode=='secure' then c.actions:cancel(c.mode) end
        if c.mode=='cursor' or c.mode=='ally' then c.actions:cancel(c.mode) end
        if c.mode=='farm' and mode~='farm' then
            c.attackTarget=nil;c.actions:cancel('farm')
        end
        c.spells.afterSmite=nil;if c.config.capture then c:log('mode_changed',{name=mode}) end;c.mode=mode
    end
    c.attackTarget=nil;c.moveTarget=nil
    if mode=='farm' and (c.input.pressed.farmKey or not self.autoWasOn) then
        c.actions.cameraToggleAt=nil;c.actions.cameraAt=nil
        c.actions.cameraSample=nil;c.actions.cameraFollowing=nil
        c.actions.cameraLostSamples=0;c.actions.cameraResumeAt=nil
        c.input.farmPaused=false
        c.farm.camp=nil;c.farm.waveCenter=nil;c.farm.progressAt=nil;c.farm.state='routing'
        c.farm:startRoute()
    end
    self.autoWasOn=c.config:get('autoJungle')
    if mode=='cursor' or mode=='ally' then
        local bind=mode=='cursor' and 'cursorKey' or 'allyKey'
        if c.input.pressed[bind] or self.insecMode~=mode then
            c.combat:cancel();self.insecSuppressed=false
            self.insecCompletedStart=c.combat.completedSerial or 0
        end
        self.insecMode=mode
        if c.input.cancel then self.insecSuppressed=true end
        if not c.combat.insec and not self.insecSuppressed then
            local r=c:spell(3)
            if (c.combat.completedSerial or 0)~=(self.insecCompletedStart or 0) then c.status='Insec completed; release bind'
            elseif (r.level or 0)==0 or (r.currentCd or 0)>0 then c.status='Insec held: waiting for R'
            else c.combat:startInsec(mode) end
        elseif self.insecSuppressed then c.status='Insec cancelled; release bind to rearm' end
    else
        self.insecMode=nil;self.insecSuppressed=nil
        if c.combat.insec then c.combat:cancel() end
    end
    c.wards:tick()
    -- Ambient execution is independent of held modes. Explicit positioning,
    -- Recall and cursor ownership still govern whether dispatch is legal.
    if not c.wards.pending and not c.combat.insec and mode~='ward' and mode~='secure' then c.smite:auto() end
    local expiryAllowed=mode~='ward' and mode~='cursor' and mode~='ally' and mode~='secure' and mode~='reserved'
    if expiryAllowed and c.config:get('reserveW') and c.combat:defense() then c.status='Lethal incoming attack: self shield'
    elseif expiryAllowed and not (mode=='fight' and c.combat.rFollow) and c.clear:expiryTick() then c.status='Recast expiry assist'
    elseif mode=='ward' then
        if c.input.wardContinuation then c.status='Wardjump: '..(c.wards.pending and c.wards.pending.state or 'completed; release T')
        elseif not c.input.wardCancelled then c.wards:preview(c.aim);c.status='Wardjump: release to jump; right-click cancels' end
    elseif mode=='cursor' or mode=='ally' then c.combat:insecTick();c.combat:orbwalkInsec(self.insecSuppressed)
    elseif c.wards.pending then c.status='Wardjump: '..c.wards.pending.state
    elseif c:recalling() then c.status='Recalling';if mode=='farm' then c.farm:recovery() end
    elseif mode=='fight' then
        c.status='Fight'
        if c:combatTransit() then c.smite:auto()
        elseif c.combat.rFollow then c.combat:fight()
        elseif not c.actives:defense('fight') and not c.actives:potions('fight') and not c.combat:defense() and not c.smite:auto() then c.combat:fight() end
    elseif mode=='farm' then c.farm:tick();if c.attackTarget then c.actives:tick(c.attackTarget,'farm') end
    elseif mode=='clear' then
        c.status='GG local clear: nearest enabled wave / camp'
        local target=self:localClearTarget()
        if target then
            if target.team==300 then c.clear:tick(target,'clear');c.actives:tick(target,'clear')
            else c.wave:tick(target,false) end
        end
    elseif mode=='secure' then self:secure()
    elseif mode=='harass' then
        c.status='Harass';c.combat:harass('harass')
    elseif mode=='q' then
        c.status='Q1 assist';local target=c:target(c.profile.qRange);if target then c.spells:q1(target,'q',false) end
    elseif mode=='gg_last' then
        c.status='GG Last Hit'
        if c.config:get('lastAbilities') and not c.sdk.Orbwalker:IsAutoAttacking() then
            for _,m in ipairs(c.minions or {}) do
                if self:laneMinion(m) and U.dist(myHero.pos,m.pos)<=c.profile.qRange then
                    c.wave:tick(m,false,true);break
                end
            end
        end
    elseif mode=='gg' then c.status='GG orbwalker'
    elseif mode=='paused' then c.status='Auto-jungle stopped: press '..U.keyLabel(c.config:key('farmKey'))
    elseif mode=='reserved' then c.status=next(c.input.suspended) and 'Release held keys to resume' or 'Last-hit mode disabled'
    else
        c.status=c.routeFailureReason or 'Manual play'
        if not c.smite:auto() and not c.combat:defense() and not c.actives:defense() then
            if not (c.config:get('autoMultiR') and c.combat:multi(nil,false)) then c.combat:killsteal() end
        end
    end
    local follow=c.spells.afterSmite
    if follow then
        if c:now()>follow.untilTime or follow.owner~=mode or not U.valid(follow.target) then c.spells.afterSmite=nil
        elseif c.spells:q1(follow.target,follow.owner,false) then c.spells.afterSmite=nil end
    end
    if not ggOwned and not c.wards.pending and not c.leveling.pending and not c:dash() then
        local attacked=false
        if mode=='farm' and c.attackTarget and P.epics[P.category(c.attackTarget.charName)] then c.attackTarget=nil end
        if c.attackTarget then
            local requestState,requestReason
            if c.actions.attack then attacked,requestReason,requestState=c.actions:attack(c.attackTarget,mode) else attacked=c.sdk.Orbwalker:Attack(c.attackTarget) end
            if attacked then if c.config.capture then c:log('attack_accepted',{target=U.id(c.attackTarget),mode=mode,health=c.attackTarget.health,
                inputState=requestState,cursorID=c.actions.attackRequest,
                predictedHealth=c:healthAt(c.attackTarget,self:impact(c.attackTarget))}) end end
        end
        if not attacked and c.moveTarget then
            local ok,reason=c.actions:move(c.moveTarget,mode)
            if mode=='farm' and not ok and reason and not c.status:find(reason,1,true) then c.status=c.status..' | '..reason end
        end
    end
    if c.config.capture then c.verification={damage=c.config:get('mechanicsVerified'),terrain=c.terrain:trusted() and true or false,
        wardRange=c.config:get('rangeVerified'),smite=c.config:get('smiteVerified'),
        terrainProvider=c.terrain.provider and c.terrain.provider.kind or 'none',
        terrainStatic=c.terrain.provider and c.terrain.provider.static or false,gameplay='NOT RECORDED'} end
    c.input:clearEdges()
end
function App:install()
    local c=self.ctx;local sdk=c.sdk
    c.performance=require('lho.performance').new(c);c.performance:install(self)
    local function attach(list,fn) list[#list+1]=fn;self.hooks[#self.hooks+1]={list=list,fn=fn} end
    local function guarded(fn,label)
        local name='callback.'..(label or 'hook')
        return function(...)
            if not self.active then return end
            c.performance:pulse(name)
            local token=c.performance:begin(name)
            if (self.inCallback or 0)==0 then U.beginBuffScope() else U.invalidateBuffScope() end
            self.inCallback=(self.inCallback or 0)+1
            local values={...};local count=select('#',...)
            local ok,err=xpcall(function()return fn(unpack(values,1,count))end,function(error)
                return debug and debug.traceback and debug.traceback(tostring(error),2) or tostring(error)
            end)
            if not ok then
                local phases=c.performance:abort()
                local args=select(1,...);if type(args)=='table' and args.Process~=nil then args.Process=false end
                pcall(c.log,c,'controller_error',{reason=tostring(err),phases=phases});pcall(self.Shutdown,self)
                print('[LHO] Controller stopped: '..tostring(err)..' | log: '..tostring(c.logFile or 'unavailable'))
            end
            self.inCallback=self.inCallback-1
            if ok then c.performance:finish(token) end
            if self.inCallback==0 then U.endBuffScope();if c.config:get('performanceLogging') then pcall(c.performance.flush,c.performance) end else U.invalidateBuffScope() end
        end
    end
    if sdk.OnUrgent then attach(sdk.OnUrgent,guarded(function()
        c:refresh();c.actions:tick()
        if not c:blocked() then c.smite:auto();c.wards:fastTick(true);c.combat:fastKick() end
    end,'urgent')) end
    attach(sdk.OnTick,guarded(function() self:tick() end,'tick'))
    if sdk.OnMaintenance then
        attach(sdk.OnMaintenance,function()if c.logger then pcall(c.logger.flush,c.logger) end end)
    end
    attach(sdk.OnDraw,guarded(function()
        if not c:blocked() then c.actions:tick();if not c.smite:auto() then c.smite:followAim() end end
        c.wards:fastTick();c.combat:fastKick();if self:mode()=='farm' then c.farm:fastTick();c.farm:fastKite() end;c.overlay:draw()
    end,'draw'))
    attach(sdk.OnWndMsg,guarded(function(msg,param) self:event(msg,param) end))
    local pre=guarded(function(args)
        local original=args.Target;self:preAttack(args)
        if c.config.capture then c.lastPreAttack={at=c:now(),mode=self:mode(),process=args.Process,
            original=U.id(original),target=U.id(args.Target),waveLock=c.wave:attackLocked(),
            wardPending=c.wards.pending~=nil,levelPending=c.leveling.pending~=nil} end
    end)
    self.hooks[#self.hooks+1]={list=sdk.Orbwalker.OnPreAttackCb,fn=pre};sdk.Orbwalker:OnPreAttack(pre)
    local move=guarded(function(args) self:preMove(args) end)
    self.hooks[#self.hooks+1]={list=sdk.Orbwalker.OnMoveCb,fn=move};sdk.Orbwalker:OnPreMovement(move)
    local post=guarded(function()
        c.telemetry:safe('postAttack')
        if c.clear:attackFinished() then if c.config.capture then c:log('attack_finished') end end
        local mode=self:mode()
        if mode=='farm' then c.farm:fastKite() end
        if mode=='gg_last' or mode=='clear' then
            local anchor=mode=='clear' and self:localClearTarget()
            if mode=='gg_last' then for _,m in ipairs(c.minions or {}) do if self:laneMinion(m) then anchor=m;break end end end
            if anchor and anchor.team~=300 then c.wave:tick(anchor,false,mode=='gg_last') end
        end
    end)
    self.hooks[#self.hooks+1]={list=sdk.Orbwalker.OnPostAttackCb,fn=post};sdk.Orbwalker:OnPostAttack(post)
    c:refresh();c.farm:spawn();if c.config.capture then c:log('loaded',{name=c.profile.id,build=require('lho.profiles').build,
        provider=c.originalGG and 'OriginalGG' or 'Orbama',capabilities=c.actions.capabilities}) end
    print('[LHO] Loaded '..c.profile.id..'. Terrain: '..(c.terrain.provider and c.terrain.provider.kind or 'unavailable')..'.')
    if c.config:get('playtestLogging') then print('[LHO] PLAYTEST LOG: '..tostring(c.logFile or 'not written')) end
end
function App:Snapshot() return self.ctx:snapshot() end
local function serialize(value,seen)
    if type(value)=='string' then return string.format('%q',value) end
    if type(value)=='number' or type(value)=='boolean' then return tostring(value) end
    if type(value)~='table' then return 'nil' end
    seen=seen or {};if seen[value] then return 'nil' end;seen[value]=true
    local rows={};for k,v in pairs(value) do rows[#rows+1]='['..serialize(k)..']='..serialize(v,seen) end
    seen[value]=nil;table.sort(rows);return '{'..table.concat(rows,',')..'}'
end
function App:ExportDiagnostics(path)
    if not io or not io.open then return false,'File output unavailable' end
    path=path or ((SCRIPT_PATH or '')..'LHO-diagnostics-'..self.ctx.profile.id..'.lua')
    -- Construct the snapshot before opening/truncating the destination. Export
    -- is also callable outside guarded game callbacks, so return failures.
    local snapshotOK,text=pcall(function()return 'return '..serialize(self:Snapshot())..'\n'end)
    if not snapshotOK then return false,tostring(text) end
    local opened,f,err=pcall(io.open,path,'w');if not opened or not f then return false,tostring(not opened and f or err) end
    local written,result,writeError=pcall(f.write,f,text)
    local closed,closeResult,closeError=pcall(f.close,f)
    if not written or not result then return false,tostring(not written and result or writeError) end
    if not closed or not closeResult then return false,tostring(not closed and closeResult or closeError) end
    return true,path
end
function App:Shutdown()
    if not self.active then return end
    self.active=false
    local c=self.ctx
    if c.actions.scope then c.actions.scope:Close('LHO shutdown')
    elseif c.sdk.Input then
    for _,owner in ipairs({'ward','insec','autosmite','secure','level','defense','farm','combat','camera','fight','harass','clear','q','killsteal','expiry'}) do
            pcall(c.sdk.Input.Cancel,c.sdk.Input,owner,'LHO shutdown')
        end
    end
    -- Cleanup steps are independent: one broken native input method must not
    -- leave every later callback registered or another held modifier behind.
    c.telemetry:safe('shutdown')
    pcall(c.wards.cancel,c.wards,'Plugin shutdown')
    pcall(c.combat.cancel,c.combat);pcall(c.leveling.cancel,c.leveling)
    pcall(c.input.reset,c.input)
    pcall(c.actions.restoreCameraOnShutdown or c.actions.restoreCamera,c.actions)
    pcall(c.actions.releaseMinimap,c.actions,true)
    c.spells.afterSmite=nil;c.combat.rFollow=nil;c.combat.multiTarget=nil
    c.attackTarget=nil;c.moveTarget=nil;c.synthetic=false;c.dispatchMovement=nil
    for _,h in ipairs(self.hooks) do
        if h.list then
            for i=#h.list,1,-1 do
                if h.list[i]==h.fn then
                    -- Never shorten an SDK callback array while it is being iterated.
                    if (self.inCallback or 0)>0 then h.list[i]=function() end else table.remove(h.list,i) end
                end
            end
        end
    end
    self.hooks={}
    -- The crash event may still be buffered when normal hooks are detached.
    -- Drain it in maintenance, outside cursor/host input calls, then detach.
    if c.sdk.OnMaintenance and c.logger and c.logger:pendingCount()>0 then
        local list=c.sdk.OnMaintenance;local logger=c.logger
        local index=#list+1
        list[index]=function()
            pcall(logger.flush,logger)
            if logger:pendingCount()==0 then list[index]=function()end end
        end
    end
    if _G.LeeHarveyOsward==self then _G.LeeHarveyOsward=nil end
end
return App
