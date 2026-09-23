local U=require('lho.util')
local I={};I.__index=I
local holds={'cursorKey','allyKey','wardKey','qKey','secureKey'}
local modifiers={[16]={16,160,161},[17]={17,162,163},[18]={18,164,165}}
local canonical={[160]=16,[161]=16,[162]=17,[163]=17,[164]=18,[165]=18}
function I.new(ctx) return setmetatable({ctx=ctx,down={},pressed={},released={},suspended={},wardCancelled=false,farmPaused=false},I) end
function I:held(name) local key=self.ctx.config:key(name);return key and key~=0 and self.down[key]==true end
function I:previewHeld()
    local key=self.ctx.config:key('insecPreviewKey')
    if key==18 then return self.down[18] or self.down[164] or self.down[165] or false end
    return key and key~=0 and self.down[key]==true or false
end
function I:insecMovementHeld()
    local c=self.ctx;local pending=c.wards and c.wards.pending
    return (self:held('cursorKey') or self:held('allyKey')) and not c:blocked()
        and not self:held('wardKey') and not (pending and pending.owner=='ward')
end
function I:pauseFarm(reason)
    if self.ctx.farm then
        self.ctx.farm.localException=nil;self.ctx.farm.returningHome=nil;self.ctx.farm.recallAction=nil;self.ctx.farm.recoveryWanted=nil;self.ctx.farm.recallReconcile=nil;self.ctx.farm.recallLegacy=nil
    end
    if self.ctx.config:get('autoJungle') then
        local c=self.ctx
        self.lastFarmStop={reason=reason or 'Input / mode takeover',state=c.farm.state,
            pos=U.copy(myHero.pos),spawn=U.copy(c.farm.spawnPos),recalling=c:recalling(),
            status=c.status,mode=c.mode,input=self.lastPhysicalEvent,
            levelPending=c.leveling.pending~=nil,cursorStep=c.sdk.Cursor.Step}
        if c.config.capture then c:log('farm_stopped',self.lastFarmStop) end
    end
    self.farmPaused=true;self.ctx.config:set('autoJungle',false)
end
function I:event(msg,param)
    local c=self.ctx;local now=c:now()
    if c.sdk.Input and c.sdk.Input:IsSyntheticEvent() then return true end
    if c.synthetic or c.sdk.NativeTransport and c.sdk.NativeTransport.InFlight then return true end
    -- Cursor movement caused by the SDK is not player intent. Preserve real deviations.
    if msg==512 then
        if c.sdk.Actions or c.sdk.Input then c.aim=c:playerPosition();return end
        local cursor=c.sdk.Cursor
        if cursor and cursor.Step>0 and c.cursorLease and cursor.CastPos==c.cursorLease.castPos and Game.cursorPos then
            local p=Game.cursorPos();local expected=cursor.correctedCastPos
            if expected and U.screenDist(p,expected)>8 and U.screenDist(p,cursor.CursorPos)>8 then
                cursor.CursorPos={x=p.x,y=p.y};c.aim=U.copy(mousePos or c.aim)
            end
        end
        return
    end
    if msg==516 then
        if not c.sdk.Input and now<(c.syntheticMouseUntil or -1) then return end
        self.lastPhysicalEvent={message=msg,key=2,param=param,at=now}
        -- A real movement click may interrupt the provider's current input, but
        -- does not withdraw a held Insec intention. Its controller reconciles
        -- already-sent actions and replans unsent steps from the new position.
        -- Standalone T retains its explicit right-click cancellation contract.
        if self:insecMovementHeld() then
            self:pauseFarm('Physical right-click');self.cancel=false
            c.aim=c:playerPosition()
            if c.config.capture then c:log('insec_manual_movement',{message=msg,param=param,
                phase=c.combat.insec and c.combat.insec.phase,
                evidence='Right-click retains held Insec; provider still owns input reconciliation'}) end
            return
        end
        self.wardCancelled=true;self:pauseFarm('Physical right-click');self.cancel=true
        if c.sdk.Input and c.sdk.Input.Capabilities.withholdInput and c.config:get('cancelOnly') and _G.LHO_InputAdapter and _G.LHO_InputAdapter.consume then
            _G.LHO_InputAdapter.consume(msg,param)
        end
        return
    end
    if msg==513 then
        if not c.sdk.Input and now<(c.syntheticMouseUntil or -1) then return end
        self.lastPhysicalEvent={message=msg,key=1,param=param,at=now}
        if c.sdk.TargetSelector and c.sdk.TargetSelector.GetTarget then
            -- GG has processed selection before SDK.OnWndMsg. Never shadow its
            -- selection, toggle it again, or keep a stale independent lock.
            c.selected=nil;c.selectionOwned=false;self:pauseFarm('Physical left-click');return
        end
        local selected,dist=nil,180
        for _,e in ipairs(c.enemies or {}) do
            local d=U.dist(c.aim,e.pos)
            if d<dist then selected,dist=e,d end
        end
        -- GG processes the same click first. Re-toggling its selection here would erase it.
        c.selected=selected;c.selectionOwned=true
        self:pauseFarm('Physical left-click')
        return
    end
    local key,down
    if msg==256 or msg==260 then key,down=param,true
    elseif msg==257 or msg==261 then key,down=param,false
    elseif msg==523 or msg==524 then
        -- Raw Windows: XBUTTON index in high word. Some GoS builds emit VK 5/6.
        local high=math.floor((param or 0)/65536)%65536
        key=high==1 and 5 or high==2 and 6 or ((param==5 or param==6) and param or nil)
        down=msg==523
    end
    if not key then return end
    if self.releasedSamples then self.releasedSamples[key]=nil end
    if not down then self.suspended[key]=nil end
    if down and self.suspended[key] then return end
    local injected=c.injected[key]
    local family=modifiers[canonical[key] or key]
    if not injected and family then
        for _,alias in ipairs(family) do if c.injected[alias] then injected=c.injected[alias];break end end
    end
    -- One chord can emit both generic and side-specific Windows modifiers.
    -- Bound each representation separately so neither consumes the other's echo.
    if injected and family and now<(injected.untilTime or injected.at+.08) then
        injected.modifierEchoes=injected.modifierEchoes or {}
        local left=injected.modifierEchoes[key]
        if left==nil then left=injected.remaining end
        if left>0 then injected.modifierEchoes[key]=left-1;return true end
    end
    if injected and not family and now<(injected.untilTime or injected.at+.08) and injected.remaining>0 then
        injected.remaining=injected.remaining-1;return true
    end
    if c:blocked() then if not down then self.down[key]=nil end;return end
    local was=self.down[key]
    self.down[key]=down
    if was~=down and key==c.config:key('allyKey') and c.combat then
        c.combat.allyHoldOrigin=down and U.copy(myHero.pos) or nil
    end
    if down and not was then
        for slot=0,3 do if key==c.actions:key(slot) then
            c.manualSpellSerial=(c.manualSpellSerial or 0)+1;c.manualSpells=c.manualSpells or {}
            c.manualSpells[slot]={at=now,serial=c.manualSpellSerial,before=slot<3 and require('lho.recasts').snapshot(c,slot)}
        end end
    end
    if was~=down and c.actions.physicalIntent then
        local owners={cursorKey='insec',allyKey='insec',wardKey='ward',qKey='q',secureKey='secure'}
        for name,owner in pairs(owners) do if key==c.config:key(name) then
            c.actions:physicalIntent(owner,down)
            if not down and owner~='ward' then c.actions:cancel(owner) end
        end end
        local modes={COMBO='fight',HARASS='harass',LANECLEAR='clear',JUNGLECLEAR='clear',LASTHIT='gg_last'}
        local seen={}
        for mode,owner in pairs(modes) do
            local menus=c.sdk.Orbwalker.MenuKeys and c.sdk.Orbwalker.MenuKeys[c.sdk['ORBWALKER_MODE_'..mode]]
            for _,binding in ipairs(menus or {}) do
                if binding.Key and binding:Key()==key and not seen[owner] then
                    seen[owner]=true;c.actions:physicalIntent(owner,down)
                    -- Last-hit shares the lane spell controller, not its input
                    -- owner name. Cancel before the next scheduler opportunity.
                    if owner=='gg_last' then c.actions:physicalIntent('clear',down) end
                    if not down then c.actions:cancel(owner=='gg_last' and 'clear' or owner) end
                end
            end
        end
    end
    if was~=down then self.lastTransition={key=key,message=msg,down=down,at=now} end
    if down and not was then self.lastPhysicalEvent={key=key,message=msg,at=now} end
    if was~=down and (c.config:get('diagnostics') or c.config:get('playtestLogging') or c.config:get('combatLogging')) then
        if c.config.capture then c:log('input_event',{message=msg,param=param,key=key,down=down,evidence='Not recognized as an injected echo'}) end
    end
    if down and not was then
        if key==c.config:key('farmCameraKey') then c.actions.cameraOwned=nil end -- Physical camera takeover owns the final state.
        if key==c.config:key('farmKey') then
            if c.config.capture then c:log('farm_toggle',{enabled=not c.config:get('autoJungle')}) end
            c.config:set('autoJungle',not c.config:get('autoJungle'));self.farmPaused=false
            c.actions:physicalIntent('farm',c.config:get('autoJungle'))
            if not c.config:get('autoJungle') then c.actions:cancel('farm') end
            self.pressed.farmKey=c.config:get('autoJungle');return
        end
        if key==c.config:key('smiteKey') then
            c.config:set('autosmite',not c.config:get('autosmite'))
            c.actions:physicalIntent('autosmite',c.config:get('autosmite'))
            if not c.config:get('autosmite') then c.actions:cancel('autosmite') end
            if c.config.capture then c:log('smite_toggle',{enabled=c.config:get('autosmite'),key=key}) end;return
        end
        for _,name in ipairs(holds) do
            if key==c.config:key(name) and key~=0 then
                self.pressed[name]=true
                if name=='wardKey' then self.wardCancelled=false end
                self:pauseFarm('Assist key '..U.keyLabel(key))
            end
        end
        if key==81 or key==87 or key==69 or key==82 or key==66
            or key==c.config:key('farmCameraKey') then self:pauseFarm('Manual key '..U.keyLabel(key)) end
    elseif not down and was then
        for _,name in ipairs(holds) do if key==c.config:key(name) then self.released[name]=true end end
    end
end
function I:clearEdges() self.pressed={};self.released={};self.cancel=false end
function I:isModeKey(key)
    local c=self.ctx
    for _,name in ipairs(holds) do if c.config:key(name)==key and key~=0 then return true end end
    for _,name in ipairs({'farmKey','smiteKey'}) do if c.config:key(name)==key and key~=0 then return true end end
    local preview=c.config:key('insecPreviewKey')
    if key==preview or canonical[key]==preview then return true end
    for _,bindings in pairs(c.sdk.Orbwalker.MenuKeys or {}) do
        for _,binding in ipairs(bindings) do if binding.Key and binding:Key()==key then return true end end
    end
    return false
end
function I:reconcileSuspended()
    local c=self.ctx;local now=c:now()
    if c:blocked() or now<(self.pollAt or 0) or not next(self.suspended) then return end
    self.pollAt=now+.1;self.releasedSamples=self.releasedSamples or {}
    for key in pairs(self.suspended) do
        if not self:isModeKey(key) then self.suspended[key]=nil;self.releasedSamples[key]=nil
        else
        local family=modifiers[canonical[key] or key] or {key}
        local released=true
        for _,alias in ipairs(family) do
            local input=c.sdk.Input
            local ok,state
            if input and input.ReadKeyState then ok,state=pcall(input.ReadKeyState,input,alias)
            elseif Control.IsKeyDown then ok,state=pcall(Control.IsKeyDown,alias) end
            if not ok or state~=false then released=false;break end
        end
        if released then
            if self.releasedSamples[key] and now-self.releasedSamples[key]>=.09 then
                self.suspended[key]=nil;self.down[key]=nil;self.releasedSamples[key]=nil
                if c.config.capture then c:log('input_suspension_cleared',{key=key,evidence='Two focused host key-state samples report released; no input sent'}) end
            else self.releasedSamples[key]=now end
        else self.releasedSamples[key]=nil end
        end
    end
end
function I:reset(preserveFarm)
    if self.ctx.combat then self.ctx.combat.allyHoldOrigin=nil end
    self.releasedSamples={};self.pollAt=nil;self.wardContinuation=nil
    -- Only an automation mode can resume held intent. Chat characters, TCO,
    -- camera keys and unrelated input must never reserve the entire controller.
    for key,down in pairs(self.down) do if down and self:isModeKey(key) then self.suspended[key]=true end end
    self.down={};self:clearEdges();self.wardCancelled=true
    if not preserveFarm then
        local c=self.ctx
        self:pauseFarm(myHero.dead and 'Champion died' or not c.config:get('enabled') and 'Controller disabled'
            or c:chatOpen() and 'Chat opened'
            or Game.IsOnTop and not Game.IsOnTop() and 'Game lost focus' or 'Input state reset')
    end
end
return I
