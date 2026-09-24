local U=require('kata.util')
local A={};A.__index=A
function A.new(c)
    local self=setmetatable({c=c,pending={},history={}},A)
    self.client=c.sdk.Actions:CreateClient({name='Katarina',active=function()return c.active and c.sdk==SDK end})
    if self.client.CooperateWithEvade then
        self.client:CooperateWithEvade({committed=function()return c.state:channel()==true or self.pending[3]~=nil end,
            yield=function(evidence)
                if not evidence.likelyDeath then return false end
                self.client:YieldUnsent();c.mobility:cancel('evade_emergency')
                self.client:SetBlocked('channel','attack',false);self.client:SetBlocked('channel','move',false)
                return true
            end})
        self.client:RegisterEmergencyYield(function(resource)return self.client:YieldUnsent(resource)end)
    end
    self.client:Condition('channel','channel',function(q)
        return q.resource=='slot:3'or not c.state:channel()and not self.pending[3]
    end,{release=true})
    return self
end
function A:key(slot)
    if slot<6 then return ({[0]=HK_Q,[1]=HK_W,[2]=HK_E,[3]=HK_R,[4]=HK_SUMMONER_1,[5]=HK_SUMMONER_2})[slot]end
    return ({[6]=HK_ITEM_1,[7]=HK_ITEM_2,[8]=HK_ITEM_3,[9]=HK_ITEM_4,[10]=HK_ITEM_5,[11]=HK_ITEM_6,[12]=HK_ITEM_7})[slot]
end
function A:context(owner)
    local c=self.c
    return {condition=function()return c:available()and c:ownerActive(owner)end}
end
function A:submit(a)
    local c=self.c;local resource=a.slot or a.kind or 'move'
    local prior=self.pending[resource]
    if prior then
        if prior.a.owner==a.owner and U.id(prior.a.target)==U.id(a.target)and a.priority then self.client:UpdatePriority(prior.id,a.priority)end
        return false,'resource_pending'
    end
    local key=a.slot and self:key(a.slot)
    if a.slot and not key then return false,'missing_slot_key'end
    local origin=U.copy(c.hero.pos);local identity=U.id(a.anchor or a.target)
    local q={owner=a.owner,resource=a.slot and 'slot:'..a.slot or resource,priority=a.priority or 'normal',
        expires=self.client:Now()+(a.ttl or 350),context=self:context(a.owner),targetID=identity,
        exceptions=a.release and {channel='release'}or nil,
        mechanical=function(resolved)
            if a.slot and not c.state:ready(a.slot)then return false,'spell_not_ready'end
            if identity and U.id(a.anchor or a.target)~=identity then return false,'target_identity_changed'end
            return c:legal(a,resolved and resolved.position)
        end,
        reconcile=function()
            local active=c.hero.activeSpell
            -- Shutdown may retire this client while its physical send settles.
            -- A fresh readable cooldown permits releasing the lease without declaring a hit.
            local spell=a.slot and c.state:spell(a.slot)
            return c.sdk==SDK and c.hero==myHero and not(active and active.valid)
                and(not a.slot or U.finite(spell.currentCd)and(spell.currentCd>0 or c.state:ready(a.slot)))
        end,
        independent=a.owner=='combo'or a.owner=='harass'}
    local selfCast=a.slot==1 or a.slot==3 or a.rule and a.rule.active=='stasis'
    local aim=not selfCast and(a.pos or a.target)or nil
    if a.pos then
        q.kind='world'
        if a.anchor then q.resolve=function()
            local pos=c:landing(a.anchor,a.target,a.side,a.dagger)
            if not pos or U.dist(pos,a.pos)>160 then return nil,'landing_budget_exceeded'end
            return {position=pos}
        end end
    elseif a.target and not selfCast then q.kind='object'else q.kind='none'end
    if a.kind=='move'then q.kind='world';q.independent=false end
    local id,why
    if a.kind=='move'then
        if a.release then self.client:SetBlocked('channel','move',false)end
        id,why=self.client:Move(aim,q)
    elseif a.kind=='attack'then id,why=self.client:Attack(a.target,q)
    else id,why=self.client:Cast(key,aim,q)end
    if not id then c:log('rejected',a,why);return false,why end
    a.actionID=id
    local record={id=id,a=a,origin=origin,event=c.state.serial,at=Game.Timer(),resource=resource,
        generation=c.manualGeneration or 0,oldCd=a.slot and c.state:spell(a.slot).currentCd}
    self.pending[resource]=record;c:log('requested',a,id);return true,record
end
function A:tick()
    local c=self.c;self.client:Tick()
    for resource,q in pairs(self.pending)do
        local r=self.client:Poll(q.id)
        if r then
            if q.status~=r.state then q.status=r.state;c:log(r.state,q.a,r.reason)end
            if r.sentAt and not q.sentTime then q.sentTime=Game.Timer()-(self.client:Now()-r.sentAt)/1000 end
            if r.sentAt and not r.mechanical and not q.observed then
                local event=q.a.slot and c.state.events[q.a.slot]
                local attributable=(c.manualGeneration or 0)==q.generation
                local observed=attributable and event and event.serial>q.event and event.at>=q.sentTime-.02
                -- Blink evidence needs actual displacement, an intended endpoint and no competing manual spell.
                if not observed and attributable and q.a.slot==2 then
                    local pos=q.a.pos or(q.a.target and q.a.target.pos)
                    observed=pos and not c.state:ready(2)and U.dist(q.origin,c.hero.pos)>100 and U.dist(c.hero.pos,pos)<100 and Game.Timer()-q.sentTime<.5
                end
                if observed then
                    local ok=self.client:Observe(q.id,{kind='mechanical',unique=true,source=event and event.source or 'blink_position',at=self.client:Now()})
                    if ok then
                        q.observed=true;c.state:expect(q.a.slot,q.origin,q.a.target);c:log('mechanical',q.a,q.id)
                        if q.a.slot==2 and q.a.owner=='harass'then c.trade={origin=q.origin,at=Game.Timer(),expires=Game.Timer()+2,target=q.a.combatTarget or q.a.target}end
                    end
                end
            end
            if r.state=='cancelled_before_send'or q.observed or r.mechanical then
                self.client:Finish(q.id)
            elseif r.sentAt then self.client:Reconcile(q.id)end
            if not self.client.jobs[q.id]then
                q.finished=true;self.history[#self.history+1]=q
                if #self.history>32 then table.remove(self.history,1)end
                self.pending[resource]=nil
            end
        end
    end
end
function A:cancel(owner,why)
    -- Do not remove the permanent channel condition by cancelling its owner.
    for _,q in pairs(self.pending)do if not owner or q.a.owner==owner then self.client:Cancel(q.id,why)end end
end
function A:close()self.client:Close('Katarina shutdown')end
return A
