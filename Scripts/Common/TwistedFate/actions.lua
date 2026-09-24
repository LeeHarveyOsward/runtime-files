local U=require('tf.util')
local A={};A.__index=A
function A.new(c)
    local self=setmetatable({c=c,pending={},uncertain={}},A)
    c.actions=self -- retain ownership if a later constructor step fails
    self.client=c.sdk.Actions:CreateClient({name='TwistedFate',active=function()return c.active and c.config:get('enabled')end})
    if self.client.CooperateWithEvade then
        self.client:CooperateWithEvade({committed=function()return c.state:channel()==true end,
            yield=function(evidence)
                if not evidence.likelyDeath then return false end
                self.client:YieldUnsent();c.cards:clear()
                self.client:SetBlocked('gate','attack',false);self.client:SetBlocked('gate','move',false)
                return true
            end})
        self.client:RegisterEmergencyYield(function(resource)return self.client:YieldUnsent(resource)end)
    end
    self.client:Condition('channel','manual_channel',function(q)
        local active,kind=c.state:channel()
        return not active or kind=='gate' and q.tfLock==true and c.profile.channelW2==true
    end)
    return self
end
function A:submit(slot,q,observe)
    local c=self.c;local client=self.client
    if self.uncertain[slot] then return nil,'awaiting_fresh_state' end
    q.resource='slot:'..slot;q.owner=q.owner or 'combat';q.priority=q.priority or 'normal'
    q.expires=q.expires or client:Now()+220
    q.keys=q.keys or {({[0]=HK_Q,[1]=HK_W,[2]=HK_E,[3]=HK_R,[4]=HK_SUMMONER_1,[5]=HK_SUMMONER_2})[slot]}
    q.kind=q.kind or 'none';q.type=q.type or 'cast'
    q.equivalence=q.equivalence or (q.owner..':'..slot..':'..tostring(q.targetID or '')..':'..tostring(q.tfStage or ''))
    local before=c.hero:GetSpellData(slot);local beforeName=before.name;local beforeRank=before.level
    local beforeCD=before.currentCd or 0;local serial=c.state.serial
    q.reconcile=function(record)
        local d=c.hero:GetSpellData(slot)
        if not d or not d.name then return false end
        -- Reconciliation releases the old resource, never declares the cast successful.
        self.uncertain[slot]={name=d.name,rank=d.level,cd=d.currentCd or 0,stage=c.state.stage,color=c.state.color,
            id=record and record.id,freshReadyReplan=slot==0 and q.freshReadyReplan==true}
        c:record('resource_reconciled',{slot=slot,id=record and record.id,reason='historical_send_unresolved',
            name=d.name,rank=d.level,cooldown=d.currentCd,ready=Game.CanUseSpell(slot)})
        return true
    end
    local id,why=client:Submit(q)
    if id and not self.pending[id]then
        self.pending[id]={slot=slot,name=beforeName,rank=beforeRank,cd=beforeCD,serial=serial,observe=observe,owner=q.owner}
        c:record('requested',{id=id,slot=slot,owner=q.owner,mode=c.state.mode,target=q.targetID,stage=q.tfStage,lock=q.tfLock,
            desired=c.cards and c.cards.desired,observed=c.state.color})
    end
    return id,why
end
function A:busy(slot)
    if self.uncertain[slot]then return true,'awaiting_fresh_state' end
    for id,p in pairs(self.pending)do if p.slot==slot and self.client.jobs[id]then return true,'pending' end end
    return false
end
function A:tick()
    local c=self.c;local client=self.client;client:Tick()
    for slot,b in pairs(self.uncertain)do
        local d=c.hero:GetSpellData(slot)
        if d and (d.name~=b.name or d.level~=b.rank or (d.currentCd or 0)>b.cd+.05
            or slot==1 and (c.state.stage~=b.stage or c.state.color~=b.color))then
            self.uncertain[slot]=nil
        elseif b.freshReadyReplan and d and d.level>0 and (d.currentCd or 0)<=0
            and U.lower(d.name)==U.lower(c.profile.qName) and c.state:ready(slot) and not c.state:channel()
            and (not b.id or not client.jobs[b.id]) and client:Available() then
            -- The client already waited for transport cleanup and reconciled
            -- the historical send. Two fresh ready observations may reopen Q
            -- for a NEW plan; this neither confirms nor replays that old cast.
            local at=Game.Timer();local active=c.hero.activeSpell
            if active and active.valid and U.lower(active.name)==U.lower(c.profile.qName) then b.readyAt=nil
            elseif b.readyAt and at>b.readyAt then
                self.uncertain[slot]=nil
                c:record('resource_reopened',{slot=slot,id=b.id,reason='fresh_ready_observed',historicalExecution='unknown'})
            else b.readyAt=at end
        else b.readyAt=nil
        end
    end
    for id,p in pairs(self.pending)do
        local r=client:Poll(id)
        if r then
            if c.config:get('diagnostics') and (p.loggedState~=r.state or p.loggedSent~=r.sentAt)then
                p.loggedState=r.state;p.loggedSent=r.sentAt
                c:record('action_state',{id=id,slot=p.slot,owner=p.owner,state=r.state,reason=r.reason,
                    requestedAt=r.requestedAt,sentAt=r.sentAt,releasedAt=r.releasedAt,cleanupPending=r.cleanupPending,
                    interrupted=r.interrupted,competitor=r.competitor})
            end
            if r.sentAt and not r.mechanical then
                local d=c.hero:GetSpellData(p.slot)
                -- A cooldown transition is a resource observation; a timer is not.
                local seen=p.observe and p.observe(p) or not p.observe and d and
                    (d.level~=p.rank or (d.currentCd or 0)>p.cd+.05)
                if seen then
                    local evidence={kind='mechanical',unique=true,at=client:Now(),source='fresh_tf_state'}
                    local receipt=r.commandReceipt
                    if client:Capabilities().keyedMechanicalObservation and receipt then
                        evidence.attribution='command_key';evidence.key=receipt.key
                        evidence.generation=receipt.generation;evidence.session=receipt.session
                    end
                    local accepted,why=client:Observe(id,evidence)
                    if p.observationReason~=tostring(accepted)..':'..tostring(why)then
                        p.observationReason=tostring(accepted)..':'..tostring(why)
                        c:record('action_observation',{id=id,accepted=accepted,reason=why,attribution=evidence.attribution})
                    end
                    r=client:Poll(id) or r
                end
            end
            client:Reconcile(id)
            if not r.sentAt and r.state=='cancelled_before_send' then client:Finish(id)end
        end
        if not client.jobs[id]then self.pending[id]=nil;c:record('completed',{id=id,state=r and r.state,
            mechanical=r and r.mechanical~=nil and r.mechanical~=false or false,reason=r and r.reason,sentAt=r and r.sentAt})end
    end
end
function A:cancel(owner,reason)
    self.client:CancelOwner(owner,reason)
    -- Explicit new player intent may reopen a reconciled resource, with fresh validation.
    if owner=='cards' then self.uncertain[1]=nil end
end
function A:close()
    self.client:Close('tf_shutdown');self:tick();self.client:Collect()
end
return A
