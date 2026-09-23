local U=require('lho.util')
local toggles={autoJungle='farm',autosmite='autosmite'}
return function(a)
    a.slotUncertainty={};a.ownerGeneration={};a.activation={};a.releasedIntent={}
    a.toggleObserved={}
    for key in pairs(toggles) do a.toggleObserved[key]={value=a.ctx.config:get(key),serial=(a.ctx.config.writeSerial or {})[key]} end
    function a:physicalIntent(owner,down)
        if not down then self.releasedIntent[owner]=true;return end
        if self.releasedIntent[owner] then
            self.activation[owner]=(self.activation[owner] or 0)+1;self.releasedIntent[owner]=nil
        end
    end
    function a:quarantine(slot,event,r)
        if not self.api or not r or r.state~='send_uncertain' then return end
        if not event.keyAt and r.sentAt then event.keyTick=r.sentAt;event.keyAt=self.ctx:now()-(self.api:Now()-r.sentAt)*.001 end
        self.slotUncertainty[slot]=self.slotUncertainty[slot] or {event=event,at=self.ctx:now()}
        event.status='input_uncertain';self.pending[slot]=nil
    end
    function a:refreshUncertainty()
        local c=self.ctx;local now=c:now()
        -- Menu changes are observable separately from internal config:set()
        -- writes. Hotkey toggles already report their physical event directly.
        for key,owner in pairs(toggles) do
            local seen=self.toggleObserved[key];local value=c.config:get(key);local serial=(c.config.writeSerial or {})[key]
            if seen.serial==serial and value~=seen.value then
                self:physicalIntent(owner,value);if not value then self:cancel(owner) end
            end
            seen.value=value;seen.serial=serial
        end
        for slot,lock in pairs(self.slotUncertainty) do
            local e=lock.event;local d=c:spell(slot);local stage=slot<3 and c:stage(slot)
            local active=myHero.activeSpell
            local observed=active and active.valid and U.name(active.name)==U.name(e.before.name)
                and U.finite(active.startTime) and active.startTime>=(e.keyAt or e.at) and active.startTime<=now
            if slot<3 and e.stage==2 then
                local yes,evidence=require('lho.recasts').evidence(c,slot,e.recastBefore,e.keyAt)
                observed=yes;e.recastEvidence=evidence
            end
            if slot<3 and e.stage==1 and (stage==2 or (d.currentCd or 0)>(e.before.cd or 0)+.05) then observed=true end
            if slot>=3 and (d.currentCd or 0)>(e.before.cd or 0)+.05 then observed=true end
            if observed and not lock.executionObserved then
                lock.executionObserved=true;e.executionObservedAt=now
                local at=active and active.valid and U.name(active.name)==U.name(e.before.name) and U.finite(active.startTime) and active.startTime>=(e.keyAt or e.at)
                    and active.startTime<=now and active.startTime or now
                if slot<4 and c.clear then c.clear:executed(slot,e.stage,at) end
                self.scope:Observe(e.cursorID,{kind='mechanical',source='spell_state_after_uncertain_input',unique=true,at=self.api:Now()})
            end
            local newCycle=lock.cooldownSeen and (d.currentCd or 0)==0 and (slot>=3 or stage==1) and c:ready(slot)
            if (d.currentCd or 0)>0 then lock.cooldownSeen=true end
            local availability=self.api:GetAvailability()
            local deliberate=(self.activation[e.owner] or 0)>(e.activation or 0)
            if not availability.cleanupPending and not availability.uncertain and availability.available
                and (lock.executionObserved or newCycle or deliberate) then
                self.slotUncertainty[slot]=nil
                e.resolvedAt=now;e.resolution=lock.executionObserved and 'execution_observed' or newCycle and 'new_ready_cycle' or 'physical_reactivation'
                if c.config.capture then c:log('slot_uncertainty_resolved',{slot=slot,cursorID=e.cursorID,reason=e.resolution}) end
            end
        end
    end
end
