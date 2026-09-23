-- Internal preparation; public callback lists and their ordering are untouched.
return function(cached, item, health, orb, input, env)
    local attack=orb.Attack
    if type(attack)=='function' then
        function orb:Attack(unit,record)
            local before=input.LastActionID
            local result=attack(self,unit,record)
            if input.DiagnosticsEnabled then
                local id=input.LastActionID~=before and input.LastActionID or record and record.id
                local action=id and input:GetAction(id)
                local row=self.LastAttackDiagnostic or {}
                row.at=env.time();row.target=unit and (unit.networkID or unit.handle)
                row.accepted=result==true;row.inputID=id;row.state=action and action.state
                row.reason=action and action.reason or result~=true and (not unit and 'no_target_selected' or 'attack_gated_before_input') or nil
                self.LastAttackDiagnostic=row
                if unit then
                    -- A subsequent nil-target tick must not erase evidence of
                    -- the last real attack attempt. Reuse private records;
                    -- GetControlState returns detached snapshots to consumers.
                    local targeted=self.LastTargetedAttackDiagnostic or {}
                    for key in pairs(targeted) do targeted[key]=nil end
                    for key,value in pairs(row) do targeted[key]=value end
                    self.LastTargetedAttackDiagnostic=targeted
                end
            end
            return result
        end
    end
    function item:Prepare()
        -- Invalidate independently of item automation, but enumerate inventory
        -- only when a consumer requests it. Reuse the two private maps.
        self.Snapshots=self.Snapshots or {};self.CachedItems=self.CachedItems or {}
        for id in pairs(self.Snapshots) do self.Snapshots[id]=nil end
        for id in pairs(self.CachedItems) do self.CachedItems[id]=nil end
    end
    function item:GetSnapshot(unit)
        self.Snapshots=self.Snapshots or {}
        local id=unit.networkID or unit.handle or unit
        if not self.Snapshots[id] then
            local snapshot={ids={},slots={},at=env.clock and env.clock() or 0}
            for i,slot in ipairs(env.slots) do
                local value=unit:GetItemData(slot)
                -- Copy the fields we expose; host userdata can change in place.
                if value and value.itemID and value.itemID>0 then
                    snapshot.slots[slot]={itemID=value.itemID,stacks=value.stacks,stackCount=value.stackCount,ammo=value.ammo,currentCd=value.currentCd}
                    snapshot.ids[value.itemID]=i
                end
            end
            self.Snapshots[id]=snapshot; self.CachedItems[id]=snapshot.ids
        end
        return self.Snapshots[id]
    end
    function orb:Prepare()
        local enabled=self:IsEnabled()
        self.Modes=enabled and self:GetModes() or {}
        self.IsNone=true
        for _,value in pairs(self.Modes) do if value then self.IsNone=false;break end end
        if not enabled then
            if self.WasEnabled~=false then input:CancelAll('disabled') end
            item.QssPending=nil
        end
        self.WasEnabled=enabled
        local active=enabled and self.Modes[env.combo] and not env.hero.dead
            and (not input.env.focus or input.env.focus())
            and (not input.env.chat or not input.env.chat())
        if active and not input.ForceTCOUp then input:AcquireKey(env.tco,'orbwalker')
        else input:ReleaseKey(env.tco,'orbwalker') end
        self.TCOComboActive=not not active
    end
    -- Read-only control diagnostics for any plugin. No calls to movement hooks
    -- and no mutation of bindings, keys or external movement ownership.
    function orb:GetControlState()
        local row={enabled=self:IsEnabled(),attackEnabled=self.AttackEnabled,movementEnabled=self.MovementEnabled,
            menuAttack=self.Menu.AttackEnabled:Value(),menuMovement=self.Menu.MovementEnabled:Value(),
            none=self.IsNone,dead=env.hero.dead==true,bindings={},modes={},
            forceMovement=self.ForceMovement~=nil,forceTarget=self.ForceTarget~=nil,
            cursorPhase=input.Step,uncertain=input.Uncertain==true,chat=input:IsChatOpen(),
            targetChampionsOnly=input:ReadKeyState(env.tco),targetFilterKey=env.tco,
            targetFilterPhysical=input.Physical[env.tco]==true,
            targetFilterOwner=input.KeysOwned[env.tco],
            targetFilterRecoveryAttempts=input.TCORecovery and input.TCORecovery.attempts,
            ctrl=input:ReadKeyState(17),alt=input:ReadKeyState(18),
            attackKey=input.env.attackKey and input.env.attackKey()}
        if self.LastAttackDiagnostic then
            row.lastAttack={};for key,value in pairs(self.LastAttackDiagnostic) do row.lastAttack[key]=value end
        end
        if self.LastTargetedAttackDiagnostic then
            row.lastTargetedAttack={};for key,value in pairs(self.LastTargetedAttackDiagnostic) do row.lastTargetedAttack[key]=value end
        end
        for mode,value in pairs(self.Modes or {}) do row.modes[mode]=value end
        for mode,bindings in pairs(self.MenuKeys or {}) do
            local out={};row.bindings[mode]=out
            for _,binding in ipairs(bindings) do
                local key=binding.Key and binding:Key()
                out[#out+1]={key=key,active=binding:Value(),hostDown=key and input:ReadKeyState(key)}
            end
        end
        return row
    end
    function cached:RefreshCritical(kind)
        if kind=='ward' then self.TempCacheBuffer.w=0; self.WardsSaved=false; self.Wards={}
        elseif kind=='target' then self.TempCacheBuffer.m=0; self.MinionsSaved=false; self.Minions={} end
    end
    function health:DispatchCallbacks()
        if self.PendingSpellResets then
            self.PendingSpellResets=false
            for i=1,#self.Spells do self.Spells[i]:Reset() end
        end
        local pending=self.PendingUnkillable or {};self.PendingUnkillable=nil
        for i=1,#pending do pending[i].callback(pending[i].target) end
        if self.PendingSpellTicks then
            self.PendingSpellTicks=false
            for i=1,#self.Spells do self.Spells[i]:Tick() end
        end
    end
    function health:GetIncoming(handle)
        self.PredictionWork=self.PredictionWork or {indexVisits=0,candidates=0,queries=0}
        local work=self.PredictionWork
        if not self.IncomingReady then
            self.IncomingIndex=self.IncomingIndex or {}
            for _,bucket in pairs(self.IncomingIndex) do for id in pairs(bucket) do bucket[id]=nil end end
            for id,attack in pairs(self.ActiveAttacks) do
                work.indexVisits=work.indexVisits+1
                local target=attack.Target
                if target then
                    local bucket=self.IncomingIndex[target]
                    if not bucket then bucket={};self.IncomingIndex[target]=bucket end
                    bucket[id]=attack
                end
            end
            -- Empty target buckets do not grow across a long session.
            for id,bucket in pairs(self.IncomingIndex) do if next(bucket)==nil then self.IncomingIndex[id]=nil end end
            self.IncomingReady=true
        end
        self.EmptyIncoming=self.EmptyIncoming or {}
        work.queries=work.queries+1
        return self.IncomingIndex[handle] or self.EmptyIncoming
    end
end
