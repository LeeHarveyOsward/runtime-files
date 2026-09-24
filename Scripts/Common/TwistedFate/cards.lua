local U=require('tf.util')
local P=require('CombatProfiles.twisted_fate')
local C={};C.__index=C
function C.new(c)return setmetatable({c=c,keys={},phase='idle',cycle={},manual=nil},C)end
function C:request(color,manual,reason)
    local c=self.c
    if self.manual and not manual then return self.manual.color==color end
    if manual then
        c.actions:cancel('cards','manual_card_changed')
        self.manual={color=color,requestedAt=Game.Timer()}
        c:record('manual_card_requested',{color=color,reason=reason})
    end
    self.desired=color;self.reason=reason;return true
end
function C:waitFor(color)
    local s=self.c.state
    if s.stage=='held' then return s.color==color and 0 or math.huge end
    if s.stage=='selecting' and s.color==color then return 0 end
    -- Scheduling estimate only, never evidence of a lock or a color transition.
    return self.cycle[color] or (s.stage=='selecting' and .8 or 1.2)
end
function C:intentActive(color)
    if self.desired~=color then return false end
    if self.manual then return true end
    return self.autoUntil~=nil and Game.Timer()<self.autoUntil
        and (not self.autoMode or self.c.sdk.Orbwalker.Modes[self.autoMode])
        and (not self.autoCondition or self.autoCondition())
end
function C:tick()
    local c=self.c;local s=c.state;local now=Game.Timer()
    for _,color in ipairs(P.colors)do
        local down=c.config:get(color)==true
        if down and not self.keys[color]then self:request(color,true,'manual')end
        self.keys[color]=down
    end
    if self.lastColor and s.stage=='selecting' and s.color~=self.lastColor then
        local elapsed=now-(self.lastColorAt or now)
        if elapsed>.1 and elapsed<2 then
            -- Used only for estimates; direct spell-name observation selects the lock.
            for _,color in ipairs(P.colors)do self.cycle[color]=math.min(1.5,elapsed*2)end
        end
        self.lastColorAt=now
    elseif s.stage=='selecting' and not self.lastColor then self.lastColorAt=now end
    self.lastColor=s.stage=='selecting' and s.color or nil
    if self.manual then
        if s.stage=='held' and s.color==self.manual.color then self.manual.observed=true end
        if self.manual.observed and s.stage~='held' then
            if c.config:get(self.manual.color)==true then self.manual.observed=nil
            else self.manual=nil;self.desired=nil end
        end
    end
    if self.manual then self.desired=self.manual.color end
    -- A colour tap alone only reserves a card. An explicitly held attack/farm
    -- mode authorizes using it; rolling cards never block ordinary attacks.
    local usingCard=s.mode=='COMBO' or s.mode=='HARASS' or s.mode=='LASTHIT'
        or s.mode=='LANECLEAR' or s.mode=='JUNGLECLEAR'
    c.actions.client:SetBlocked('manual_card','attack',self.manual~=nil and s.stage=='held'
        and not usingCard)
    self.phase=s.cardFlight and 'projectile_observed' or s.cardAttack and now<=s.cardAttack.castEnd and 'attack_observed' or s.stage
    if not self.desired or s.stage=='held' or s.stage=='unknown' then return end
    if not self:intentActive(self.desired)then return end
    if s.channeling then
        -- No W1 during a manual channel. W2 exception needs profile live evidence.
        if not(s.stage=='selecting' and c.profile.channelW2 and s.channelKind=='gate')then return end
    end
    local color=self.desired
    local isLock=s.stage=='selecting'
    if isLock and s.color~=color then return end
    if s:windupActive()then
        if self.waitReason~='attack_windup' then c:record('card_wait',{reason='attack_windup',color=color,stage=s.stage})end
        self.waitReason='attack_windup';return
    end -- locking must never cancel a current windup
    if not s:ready(1,isLock)then
        if self.waitReason~='spell_not_ready' then c:record('card_wait',{reason='spell_not_ready',color=color,stage=s.stage})end
        self.waitReason='spell_not_ready';return
    end
    self.waitReason=nil
    local expected=isLock and c.profile.locks[color] or c.profile.wName
    local id,why=c.actions:submit(1,{owner='cards',priority=self.manual and 'interactive' or 'normal',independent=true,
        tfStage=expected,tfLock=isLock,expires=c.actions.client:Now()+120,
        context={condition=function()return self:intentActive(color)end},
        mechanical=function()
            local d=c.hero:GetSpellData(1)
            local channel,kind=s:channel()
            if self.desired~=color then return false,'card_intent_changed' end
            if U.lower(d.name)~=U.lower(expected)then return false,'card_color_changed' end
            if not s:ready(1,isLock)then return false,'card_not_ready'end
            if s:windupActive()then return false,'attack_windup'end
            if channel and not(isLock and kind=='gate' and c.profile.channelW2)then return false,'manual_channel'end
            return true
        end},function(p)
            local e=s.cardEvent
            return e and e.serial>p.serial and (isLock and e.stage=='held' and e.color==color or not isLock and e.stage=='selecting')
        end)
    if id then
        self.phase=isLock and 'lock_requested' or 'selection_requested'
        self.lastReject=nil
    elseif self.lastReject~=why then
        self.lastReject=why;c:record('card_wait',{reason=why,color=color,stage=s.stage,w=expected})
    end
end
function C:auto(color,reason,condition)
    if self.manual then return false end
    self.autoMode=(reason=='combat' or reason=='clear' or reason=='save_cs') and self.c.state.modeID or nil
    self.autoCondition=condition
    self.autoUntil=Game.Timer()+.25;return self:request(color,false,reason)
end
function C:clear()
    self.desired=nil;self.manual=nil;self.autoUntil=nil;self.phase='idle';self.c.actions:cancel('cards','context_unavailable')
    self.c.actions.client:SetBlocked('manual_card','attack',false)
end
return C
