local L={};L.__index=L
local combatOwners={fight=true,insec=true,killsteal=true,q=true,defense=true,harass=true,autosmite=true}
local function combatEvent(event)
    local k=event.kind or ''
    return k:match('^combat_') or k:match('^champion_') or k:match('^insec_') or k:match('^fight_') or k:match('^combo_')
        or k:match('^objective_') or k:match('^smite_') or k:match('^callback_')
        or combatOwners[event.owner] or k=='loaded' or k=='mode_changed' or k=='input_event'
        or k=='controller_error' or k=='q2_cast_observed'
end
local journal={smite_toggle=true,ward_timing=true,wardjump_completed=true,ward_requested=true,insec_confirmed=true,loaded=true,farm_stopped=true,farm_toggle=true,mode_changed=true,
    insec_started=true,insec_plan=true,insec_hop=true,insec_cancelled=true,insec_completed=true,insec_flash_blocked=true,
    insec_kick_retry=true,fight_kick_requested=true,fight_kick_follow=true,fight_kick_cancelled=true,
    insec_state=true,wardjump_cancelled=true,
    recovery_transition=true,recovery_progress=true,recast_evidence=true,passive_credit=true,orbama_input_errors=true,
    controller_error=true,playtest_error=true,farm_recall_requested=true,farm_recall_arrived=true,
    skill_level_unconfirmed=true,skill_level_declined=true,input_event=true,input_suspension_cleared=true,q_aim_observed=true,q_aim_unknown=true,q_aim_not_sent=true,
    
    orbama_input=true,orbama_timing=true,orbama_log_gap=true,route_input_aborted=true,route_input_uncertain=true,move_requested=true,
    camera_restore_deferred=true,camera_restore_unknown=true,camera_lock_declined=true,
    
    camera_lock_requested=true,camera_restored=true,route_endpoint_mismatch=true,
    smite_execute_requested=true,smite_hover_blocked=true,camp_down=true,camp_respawn_measured=true,camp_probe_requested=true,camp_q2_entry=true}
local important={farm_stopped=true,farm_toggle=true,farm_recall_requested=true,farm_recall_arrived=true,
    skill_level_unconfirmed=true,loaded=true,controller_error=true,prediction_unavailable=true,ward_resolution=true,ward_requested=true,ward_handoff_wait=true,
    wardjump_cancelled=true,cast_unconfirmed=true,cast_rejected=true,route_stalled=true,
    camp_focus=true,camera_lock_requested=true,camera_restored=true,potion_used=true,
    route_move_failed=true,route_ground_failed=true,route_visible_anchor=true,camp_probe_requested=true,camp_probe_confirmed=true,
    route_move_started=true,route_move_observed=true,route_move_unobserved=true,
    minimap_calibrated=true,camp_q2_entry=true,ward_follow_move=true,q2_wait=true,q2_blocked=true,camp_down=true,jungle_q_state=true,route_endpoint_mismatch=true,q2_cast_observed=true}
local function encode(v,depth,seen)
    local kind=type(v)
    if kind=='string' then return string.format('%q',v) end
    if kind~='table' then return (kind=='number' or kind=='boolean') and tostring(v) or string.format('%q',tostring(v)) end
    if depth>7 or seen[v] then return '"[bounded]"' end
    seen[v]=true;local out={};local n=0
    for k,value in pairs(v) do
        n=n+1;if n>384 then out[#out+1]='["__truncated"]=true';break end
        out[#out+1]='['..string.format('%q',tostring(k))..']='..encode(value,depth+1,seen)
    end
    seen[v]=nil;return '{'..table.concat(out,',')..'}'
end
function L.new(ctx)
    local base=COMMON_PATH or SCRIPT_PATH or ''
    if base~='' and not base:match('[/\\]$') then base=base..'/' end
    local path=base..(ctx.config:get('playtestLogging') and require('lho.playtest').filename or 'LeeHarveyOsward.log')
    return setmetatable({ctx=ctx,base=base,path=_G.LHO_LogPath or path,journalPath=base..'LeeHarveyOsward-events.log'},L)
end
function L:write(path,text)
    if self.writeBatch then
        local row=self.writeBatch.paths[path]
        if not row then row={};self.writeBatch.paths[path]=row;self.writeBatch.order[#self.writeBatch.order+1]=path end
        row[#row+1]=text;return true
    end
    if not io or not io.open then return false end
    self.ioMetrics=self.ioMetrics or {opens=0,writes=0,bytes=0,failures=0}
    local metrics=self.ioMetrics;metrics.opens=metrics.opens+1
    self.segments=self.segments or {}
    local destination=self.segments[path] or path
    local file=io.open(destination,'a');if not file then metrics.failures=metrics.failures+1;return false end
    local ok,size=pcall(file.seek,file,'end')
    local limit=self.ctx and self.ctx.config:get('playtestLogging') and 33554432 or 262144
    if path:find('LeeHarveyOsward-combat-',1,true) then limit=8388608 end
    if ok and size and size>limit then
        -- Preserve previous evidence. Never truncate a full live log.
        pcall(file.close,file)
        self.part=(self.part or 0)+1
        local session=self.ctx and self.ctx.traceSession or 'unknown'
        destination=path..'.part-'..session:gsub('[^%w%-%.]','_')..'-'..self.part..'.log'
        file=io.open(destination,'a');if not file then return false end
        metrics.opens=metrics.opens+1
        self.segments[path]=destination
    end
    local written,result=pcall(file.write,file,text,'\n')
    local closed,closeResult=pcall(file.close,file)
    local success=written and result~=nil and closed and closeResult~=nil
    if success then metrics.writes=metrics.writes+1;metrics.bytes=metrics.bytes+#text+1 else metrics.failures=metrics.failures+1 end
    return success
end
function L:writeCombat(event,text)
    self.combatBuffer=self.combatBuffer or {};self.combatBytes=self.combatBytes or 0
    self.combatBuffer[#self.combatBuffer+1]=text;self.combatBytes=self.combatBytes+#text+1
    -- Health samples share the next frame/edge write, normally within 0.3s.
    if event.kind=='combat_health_delta' and self.combatBytes<65536 then return true end
    local payload=table.concat(self.combatBuffer,'\n')
    self.combatBuffer={};self.combatBytes=0
    return self:write(self.combatPath,payload)
end
local function snapshot(value,depth,seen)
    if type(value)~='table' then return value end
    if depth>7 or seen[value] then return '[bounded]' end
    seen[value]=true;local result={};local count=0
    for k,v in pairs(value) do
        count=count+1;if count>384 then result.__truncated=true;break end
        result[k]=snapshot(v,depth+1,seen)
    end
    seen[value]=nil;return result
end
function L:record(event)
    if self.ctx.sdk.Input then
        if _G.LHO_LogPath==false or not self.ctx.config:get('fileLogging') then return end
        self.pending=self.pending or require('lho.eventqueue').new()
        local periodic=event.kind=='playtest_tick' or event.kind=='playtest_detail' or event.kind=='orbama_timing'
            or event.kind=='combat_frame' or event.kind=='combat_health_delta' or event.kind=='objective_sample'
            or (event.kind or ''):match('_snapshot$')~=nil
        self.pending:push(snapshot(event,0,{}),periodic)
        self.dropped=self.pending.dropped
        return
    end
    return self:writeRecord(event)
end
function L:pendingCount()return self.pending and self.pending.count or 0 end
function L:flush()
    local input=self.ctx.sdk.Input
    if input and (input.Active or (input.InFlight or 0)>0) then return end
    if input and input.GetDiagnosticEvents and self.ctx.log and self.ctx.config:get('fileLogging') and _G.LHO_LogPath~=false then
        local events,dropped=input:GetDiagnosticEvents(self.inputSequence or 0,64)
        if dropped>0 then self.inputDropped=(self.inputDropped or 0)+dropped;self.ctx:log('orbama_log_gap',{dropped=dropped,total=self.inputDropped}) end
        if input.GetDiagnosticErrors then
            local errors,lost=input:GetDiagnosticErrors(self.errorSequence or 0,64)
            if #errors>0 then
                self.errorSequence=errors[#errors].sequence
                self.ctx:log('orbama_input_errors',{events=errors,dropped=lost,retainedSeparately=true})
            end
        end
        if #events>0 then
            self.inputSequence=events[#events].sequence
            self.ctx:log('orbama_input',{events=events,inputBuild=self.ctx.sdk.OrbamaVersion})
        end
        if self.ctx:now()>=(self.nextTimingLog or 0) then
            self.nextTimingLog=self.ctx:now()+2
            self.ctx:log('orbama_timing',{timing=input.Timing:summary(),capabilities=input.Capabilities,
                inputSession=input.SessionID,
                inputMode=input.GGCompatible and 'GG-compatible phases' or 'experimental adaptive phases',
                hostCalls=input.Metrics.hostCalls,cursorReads=input.Metrics.cursorReads,
                unknown=input.Metrics.unknown,misdirected=input.Metrics.misdirected,loggerDropped=self.dropped or 0})
        end
    end
    -- Serialize the bounded event batch once, then open/seek/close each physical
    -- log only once. Never hold handles over a reload or while cursor input runs.
    local batch={paths={},order={}};self.writeBatch=batch
    for _=1,math.min(4,self.pending and self.pending.count or 0) do
        local event=self.pending:pop()
        event.logBuffered=true;event.logFlushedAt=self.ctx:now()
        self:writeRecord(event)
    end
    self.writeBatch=nil
    for _,path in ipairs(batch.order) do
        local ok,written=pcall(self.write,self,path,table.concat(batch.paths[path],'\n'))
        if not ok or not written then
            if path==self.path then self.retryAt=self.ctx:now()+60;self.ctx.logFile='File logging unavailable'
            elseif path==self.journalPath then self.journalRetryAt=self.ctx:now()+60;self.ctx.eventLogFile='Event journal unavailable'
            elseif path==self.combatPath then self.combatRetryAt=self.ctx:now()+60;self.ctx.combatLogFile='Combat file logging unavailable' end
        elseif path==self.path then self.ctx.logFile=self.segments and self.segments[path] or path
        elseif path==self.journalPath then self.ctx.eventLogFile=self.segments and self.segments[path] or path
        elseif path==self.combatPath then self.ctx.combatLogFile=self.segments and self.segments[path] or path end
    end
end
function L:writeRecord(event)
    if _G.LHO_LogPath==false or not self.ctx.config:get('fileLogging') then return end
    if self.ctx:now()<(self.retryAt or 0) then return end
    local playtest=self.ctx.config:get('playtestLogging') and self.ctx.playtestState~='finished'
    local combat=self.ctx.config:get('combatLogging') and combatEvent(event)
    local combatOnly=(event.kind or ''):match('^combat_') or (event.kind or ''):match('^champion_')
    local ordinary=not combatOnly and (important[event.kind] or journal[event.kind] or self.ctx.config:get('diagnostics') or playtest)
    if not ordinary and not combat then return end
    -- File/serialization failures must never become another controller error.
    local ok,result=pcall(function()
        local text=encode(event,0,{})
        if event.kind=='controller_error' then
            local snapshotOK,snapshot=pcall(self.ctx.snapshot,self.ctx)
            local recent={};for n=math.max(1,#self.ctx.events-60),#self.ctx.events do recent[#recent+1]=self.ctx.events[n] end
            text=text..'\nrecent='..encode(recent,0,{})..'\nsnapshot='..encode(snapshotOK and snapshot or tostring(snapshot),0,{})
        end
        local written=not ordinary or self:write(self.path,text)
        if not written then return false end
        local combatWritten=true
        if combat and self.ctx:now()>=(self.combatRetryAt or 0) then
            if not self.combatPath then
                self.combatPath=self.base..'LeeHarveyOsward-combat-'..tostring(event.session or self.ctx.traceSession or 'unknown'):gsub('[^%w%-%.]','_')..'.log'
            end
            local ok,value=pcall(self.writeCombat,self,event,text)
            combatWritten=ok and value
            self.ctx.combatLogFile=combatWritten and (self.segments and self.segments[self.combatPath] or self.combatPath) or 'Combat file logging unavailable'
            if combatWritten then self.combatRetryAt=nil else self.combatRetryAt=self.ctx:now()+60 end
        end
        if ordinary and written and journal[event.kind] and self.ctx:now()>=(self.journalRetryAt or 0) then
            local journalOK,result=pcall(self.write,self,self.journalPath,text)
            self.ctx.eventLogFile=journalOK and result and (self.segments and self.segments[self.journalPath] or self.journalPath) or 'Event journal unavailable'
            if journalOK and result then self.journalRetryAt=nil else self.journalRetryAt=self.ctx:now()+60 end
        end
        return written and (ordinary or combatWritten)
    end)
    self.ctx.logFile=ok and result and (self.segments and self.segments[self.path] or self.path) or 'File logging unavailable'
    -- A denied io.open can print its own sandbox error. Never retry per tick.
    if ok and result then self.retryAt=nil else self.retryAt=self.ctx:now()+60 end
end
return L
