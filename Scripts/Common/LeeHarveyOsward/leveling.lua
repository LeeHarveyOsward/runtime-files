-- Skill allocation is independent of farming, inventory and recovery.
local L={};L.__index=L
function L.new(ctx) return setmetatable({ctx=ctx,nextAt=0},L) end
function L:cancel()
    if self.ctx.actions.api then self.ctx.actions:cancel('level') end
    self.pending=nil;self.request=nil
end
function L:eligible(slot,rank)
    local c=self.ctx
    return c.config:get('level') and not c:blocked() and not c:recalling() and not c:dash()
        and not c.wards.pending and not c.combat.insec and not c.input:held('wardKey')
        and ((myHero.levelData or {}).lvlPts or 0)>0 and (c:spell(slot).level or 0)==rank
end
function L:submit(keys,validate)
    local c=self.ctx
    if c.actions.api then return c.actions:keyAction(keys,'level','chord',validate) end
    if c.sdk.Input and c.sdk.Input.SendKeys then return c.sdk.Input:SendKeys(keys,'level') end
    return false,'Owned key dispatcher unavailable',false
end
function L:tick()
    local c=self.ctx;local now=c:now()
    if not c.config:get('level') then self:cancel();return end
    if self.pending then
        local p=self.pending
        if (c:spell(p.slot).level or 0)>p.rank then
            if c.config.capture then c:log('skill_level_confirmed',{name=tostring(p.slot)}) end
            self.pending=nil
        elseif now>=p.deadline then
            if c.config.capture then c:log('skill_level_unconfirmed',{name=tostring(p.slot)}) end
            self.pending=nil;self.nextAt=now+2
        end
        return
    end
    local data=myHero.levelData or {};local points=data.lvlPts or 0
    if points<=0 then self:cancel();return end
    if now<self.nextAt or c:blocked() or c:recalling() or c:dash() or c.wards.pending
        or c.combat.insec or c.input:held('wardKey') or c.actions:cursorBusy() then return end
    local slot;local lvl=data.lvl or 1;local ranks={}
    for s=0,3 do ranks[s]=c:spell(s).level or 0 end
    if lvl>=6 and ranks[3]<math.min(3,math.floor((lvl-1)/5)) then slot=3 end
    if slot==nil then
        for _,s in ipairs({1,2,0}) do if ranks[s]==0 then slot=s;break end end
        if slot==nil then for _,s in ipairs({0,1,2}) do if ranks[s]<math.min(5,math.ceil(lvl/2)) then slot=s;break end end end
    end
    if slot==nil then return end
    if Control.IsKeyDown and (Control.IsKeyDown(16) or Control.IsKeyDown(17) or Control.IsKeyDown(18)) then return end
    local rank=ranks[slot];local keys={HK_LUS or 17,({HK_Q,HK_W,HK_E,HK_R})[slot+1]}
    local ok,accepted,reason,sent=pcall(self.submit,self,keys,function()return self:eligible(slot,rank) end)
    if ok and accepted or ok and sent then
        -- An uncertain submission is observed, never immediately replayed.
        self.pending={slot=slot,rank=rank,deadline=now+.7};self.nextAt=now+.3
    elseif not ok or reason~='waiting' then
        self.nextAt=now+1
        if c.config.capture then c:log('skill_level_declined',{reason=tostring(ok and reason or accepted)}) end
    end
end
return L
