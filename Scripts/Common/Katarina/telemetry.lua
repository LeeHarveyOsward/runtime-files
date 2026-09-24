-- Read-only observations. Health deltas cannot attribute damage to this script.
local U=require('kata.util')
local T={};T.__index=T
function T.new(c)return setmetatable({c=c,units={},scopes={},samples={},sampleIndex=0,draws=0,ticks=0,rejections={}},T)end
function T:enabled()return self.c.config:get('diagnostics')and not self.failed end
function T:safe(method,...)
    if not self:enabled()then return end
    local ok,err=pcall(self[method],self,...)
    if not ok then self.failed=true;self.c:record('diagnostic_error',{reason=tostring(err)})end
end
function T:wrap(object,method,scope)
    local original=object[method];if type(original)~='function'then return end
    object[method]=function(...)
        if not self:enabled()then return original(...)end
        local start=self.c.actions.client:Now()
        local function finish(...)
            local elapsed=math.max(0,self.c.actions.client:Now()-start)
            local row=self.scopes[scope]or {calls=0,totalMs=0,maxMs=0,over16=0}
            self.scopes[scope]=row;row.calls=row.calls+1;row.totalMs=row.totalMs+elapsed
            row.maxMs=math.max(row.maxMs,elapsed);if elapsed>16 then row.over16=row.over16+1 end
            return ...
        end
        return finish(original(...))
    end
end
function T:install()
    local c=self.c
    for _,row in ipairs({{c.state,'refresh','state'},{c.items,'refresh','inventory'},
        {c.actions,'tick','actions'},{c.planner,'combat','combat'},{c.planner,'farm','farm'},
        {c.mobility,'tick','mobility'},{c.logger,'flush','log_io'}})do self:wrap(row[1],row[2],row[3])end
end
function T:reject(a,reason)
    if not self:enabled()then return end
    local key=tostring(reason or 'unspecified');local row=self.rejections[key]
    if not row then local n=0;for _ in pairs(self.rejections)do n=n+1 end;if n>=24 then return end
        row={count=0};self.rejections[key]=row end
    row.count=row.count+1;row.slot=a.slot;row.target=U.id(a.combatTarget or a.target);row.owner=a.owner
end
function T:draw()
    local now=self.c.actions.client:Now();self.draws=self.draws+1
    if self.lastDraw then self.drawGap=math.max(self.drawGap or 0,now-self.lastDraw)end;self.lastDraw=now
end
function T:sample(o,now)
    local c=self.c;local id=U.id(o);if not id then return end
    local seen=o==c.hero or o.visible==true
    if not seen then self.units[id]=nil;return {id=id,name=o.charName,visible=false}end
    local old=self.units[id];local hp=o.health
    local row={id=id,name=o.charName,visible=true,hp=hp,maxHP=o.maxHealth,pos=U.copy(o.pos),dead=o.dead,
        targetable=o.isTargetable,immortal=o.isImmortal,shield=o.allShield,shieldAD=o.shieldAD,shieldAP=o.shieldAP}
    local a=o.activeSpell
    if a and a.valid then row.activeSpell={name=a.name,start=a.startTime,ending=a.endTime,target=a.target,auto=a.isAutoAttack}end
    if old and now-old.at<1.2 and hp and old.hp and hp~=old.hp then
        c:record('health_delta',{target=id,before=old.hp,after=hp,interval=now-old.at,attribution='unavailable'})
    end
    if old and old.dead~=o.dead then c:record('life_state',{target=id,dead=o.dead})end
    row.mark=c.profile.id=='classic'and c.state:mark(o)~=nil or nil
    -- Relevant raw buffs, bounded independently of host buff count.
    row.buffs={}
    if o.GetBuff then for i=0,math.min(o.buffCount or 0,64)do
        local b=o:GetBuff(i);local name=b and U.name(b.name)
        if name and(name:find('katarina',1,true)or name:find('deathlotus',1,true))and #row.buffs<12 then
            row.buffs[#row.buffs+1]={name=b.name,count=b.count,expires=b.expireTime,ending=b.endTime,source=b.sourceID,sourcenID=b.sourcenID}
        end
    end end
    self.units[id]={at=now,hp=hp,dead=o.dead};return row
end
function T:tick(elapsed)
    local c=self.c;local ms=c.actions.client:Now();local now=Game.Timer()
    self.window=self.window or ms;self.ticks=self.ticks+1
    self.sampleIndex=self.sampleIndex%256+1;self.samples[self.sampleIndex]=elapsed
    if self.lastTick then self.tickGap=math.max(self.tickGap or 0,ms-self.lastTick)end;self.lastTick=ms
    local input=c.sdk.Input
    if input and input.GetDiagnosticEvents and ms>=(self.nextInput or 0)then
        self.nextInput=ms+100
        if self.inputSequence==nil then self.inputSequence=input.Metrics and input.Metrics.sequence or 0 end
        local events,lost=input:GetDiagnosticEvents(self.inputSequence,64)
        if lost and lost>0 then c:record('cursor_events_lost',{count=lost})end
        for _,event in ipairs(events)do
            self.inputSequence=math.max(self.inputSequence,event.sequence or 0)
            if event.kind=='released'or event.kind=='dependent_handoff'then
                c:record('cursor_interval',{id=event.id,owner=event.owner,action=event.actionType,reason=event.reason,
                    requestedAt=event.requestedAt,acquiredAt=event.acquiredAt,positionedAt=event.positionedAt,
                    sentAt=event.sentAt,holdUntil=event.holdUntil,releasedAt=event.releasedAt,
                    returnRequestedAt=event.returnRequestedAt,returnObservedAt=event.returnObservedAt,
                    source='provider input event; not proof of spell or hit'})
            end
        end
    end
    if now>=(self.nextSnapshot or 0)then
        self.nextSnapshot=now+.5
        local units={};units[1]=self:sample(c.hero,now)
        for i=1,math.min(#c.enemies,10)do units[#units+1]=self:sample(c.enemies[i],now)end
        local spells={};for slot=0,5 do local s=c.state:spell(slot)
            spells[tostring(slot)]={name=s.name,level=s.level,cd=s.currentCd,castTime=s.castTime,state=Game.CanUseSpell(slot),ready=c.state:ready(slot)}end
        local pending={};for resource,q in pairs(c.actions.pending)do pending[tostring(resource)]={id=q.id,state=q.status,age=now-q.at,sentTime=q.sentTime}end
        local p=c.preview
        c:record('snapshot',{mode=c:mode()or 'idle',available=c:available(),channel=c.state:channel()==true,
            chat=Game.IsChatOpen(),focus=Game.IsOnTop(),health=c.hero.health,mana=c.hero.mana,champions=units,spells=spells,pending=pending,
            plan=p and {slot=p.slot,target=U.id(p.combatTarget or p.target),kind=p.kind,estimate=p.estimate,pos=p.pos},
            rejections=self.rejections,cursorStep=c.sdk.Cursor and c.sdk.Cursor.Step,manualGeneration=c.manualGeneration})
        self.rejections={}
    end
    if ms-self.window>=2000 then
        table.sort(self.samples);local duration=ms-self.window
        c:record('performance',{windowMs=duration,ticks=self.ticks,drawCallbacks=self.draws,tickGapMaxMs=self.tickGap,
            drawGapMaxMs=self.drawGap,controllerP95Ms=self.samples[math.max(1,math.ceil(#self.samples*.95))],
            controllerMaxMs=self.samples[#self.samples],scopes=self.scopes,scopeTimes='inclusive; do not sum nested scopes',
            clock='monotonic milliseconds; quantized',hostFPS=type(Game.FPS)=='function'and Game.FPS()or nil,
            ioRecords=c.logger.records,ioFlushes=c.logger.flushes})
        self.window=ms;self.ticks=0;self.draws=0;self.scopes={};self.samples={};self.sampleIndex=0;self.tickGap=0;self.drawGap=0
    end
end
return T
