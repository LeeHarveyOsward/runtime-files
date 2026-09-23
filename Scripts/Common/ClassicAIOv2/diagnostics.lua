-- Optional bounded playtest journal. Writes only beneath the host's own path.
return function(g,C)
    local config=g.ClassicAIOv2Diagnostics
    if config==nil then local ok,value=pcall(g.require or require,'ClassicAIOv2Diagnostics');if ok then config=value end end
    if type(config)~='table' or config.enabled~=true then return nil end
    local base=g.COMMON_PATH or g.SCRIPT_PATH
    if type(base)~='string' or base=='' or not g.io or not g.io.open then return nil end
    if not base:match('[/\\]$') then base=base..'/' end
    local clock=g.GetTickCount
    local D={queue={},queueKinds={},queuePriority={},sequence=0,bytes=0,dropped=0,droppedByKind={},droppedByReason={},inputLost=0,nextSnapshot=0,nextFlush=0,part=1,throttle={},callbackCalls=0,callbackTotal=0,callbackMax=0,tickMax=0}
    local session=string.format('%.0f-%.0f',g.Game.Timer()*1000,clock())
    D.prefix=base..'ClassicAIOv2-playtest-'..session
    function D:RestoreInput()
        if self.ownsInput then
            if g.SDK.Input and g.SDK.Input.DiagnosticsEnabled==true then g.SDK.Input.DiagnosticsEnabled=self.inputEnabled end
            self.ownsInput=false
        end
    end
    function D:Disable(reason)
        self.failed=true;self.queue={};self.queueKinds={};self.queuePriority={};C.diagnostics.loggingError=tostring(reason);self:RestoreInput()
    end
    local function quote(v)return '"'..v:gsub('[%z\1-\31\\"]',function(c)
        if c=='"' then return '\\"' elseif c=='\\' then return '\\\\' end
        return string.format('\\u%04x',string.byte(c))end)..'"'end
    local function encode(v,depth)
        local t=type(v)
        if t=='number' then return v==v and math.abs(v)<math.huge and tostring(v) or 'null' end
        if t=='boolean' then return tostring(v) end
        if t=='string' then return quote(v:sub(1,1500)) end
        if t~='table' or depth>5 then return 'null' end
        local out={};local n=0
        for k,x in pairs(v)do
            n=n+1;if n>64 then break end
            out[#out+1]=quote(tostring(k))..':'..encode(x,depth+1)
        end
        return '{'..table.concat(out,',')..'}'
    end
    local critical={loaded=true,stopped=true,active_spell=true,callback_error=true,input_gap=true,
        cast_request=true,cast_state=true,cast_evidence=true,cast_observed=true,cast_finished=true}
    local inputCritical={host_error=true,aborted=true,position_failed=true,release_failed=true,return_failed=true}
    function D:Drop(kind,reason)
        self.dropped=self.dropped+1
        -- Caller-controlled diagnostic kinds cannot grow accounting indefinitely.
        if not self.droppedByKind[kind] then
            local count=0;for _ in pairs(self.droppedByKind)do count=count+1 end
            if count>=31 then kind='other' end
        end
        self.droppedByKind[kind]=(self.droppedByKind[kind] or 0)+1
        self.droppedByReason[reason]=(self.droppedByReason[reason] or 0)+1
    end
    function D:Record(kind,row,throttle)
        if self.failed then return end
        local now=clock();row=row or {}
        if throttle then
            local key=kind..':'..tostring(row.key or '')..':'..tostring(row.target or '')
            if now<(self.throttle[key] or 0)then return end
            self.throttle[key]=now+throttle
        end
        self.sequence=self.sequence+1
        local priority=(critical[kind] or kind=='input' and inputCritical[row.inputKind]) and 3 or kind=='input' and 1 or 2
        if priority==1 and #self.queue>=192 then self:Drop(kind,'input_budget');return end
        if #self.queue>=256 then
            local victim
            if priority==3 then
                for i,p in ipairs(self.queuePriority)do if p<3 then victim=i;break end end
            end
            if not victim then self:Drop(kind,'queue_full');return end
            self:Drop(self.queueKinds[victim],'evicted_for_critical')
            table.remove(self.queue,victim);table.remove(self.queueKinds,victim);table.remove(self.queuePriority,victim)
        end
        row.kind=kind;row.gameTime=g.Game.Timer();row.at=now;row.journalSequence=self.sequence
        self.queue[#self.queue+1]=encode(row,0)
        self.queueKinds[#self.queue]=kind;self.queuePriority[#self.queue]=priority
    end
    function D:Flush(force)
        if self.failed or #self.queue==0 then return end
        local input=g.SDK.Input
        if not force and (clock()<self.nextFlush or input and (input.Active or (input.InFlight or 0)>0))then return end
        self.nextFlush=clock()+1000
        local path=self.prefix..'-'..self.part..'.jsonl'
        local payload=table.concat(self.queue,'\n')..'\n'
        if self.dropped~=(self.reportedDropped or 0) or self.inputLost~=(self.reportedInputLost or 0) then
            payload=payload..encode({kind='log_loss',at=clock(),gameTime=g.Game.Timer(),dropped=self.dropped,
                byKind=self.droppedByKind,byReason=self.droppedByReason,inputLost=self.inputLost,
                semantics='cumulative; inputLost is upstream and separate from local dropped'},0)..'\n'
        end
        local ok,why=pcall(function()
            local f=assert(g.io.open(path,'a'))
            local wrote,err=pcall(function()assert(f:write(payload))end)
            local closed=pcall(f.close,f)
            if not wrote then error(err)end;assert(closed)
        end)
        if not ok then self:Disable(why);return end
        self.reportedDropped=self.dropped;self.reportedInputLost=self.inputLost
        self.queue={};self.queueKinds={};self.queuePriority={};self.bytes=self.bytes+#payload;self.path=path;C.diagnostics.logPath=path
        if self.bytes>=8388608 then self.part=self.part+1;self.bytes=0 end
    end
    local function pos(p)return p and {x=p.x,z=p.z}end
    local function unit(u)
        if not u then return nil end
        local cast=u.activeSpell;local b=g.SDK.BuffManager:GetBuff(u,'Jade_VayneW_Debuff')
        return {id=u.networkID,name=u.charName,hp=u.health,maxHP=u.maxHealth,pos=pos(u.pos),visible=u.visible,dead=u.dead,
            path=pos(u.pathing and u.pathing.endPos),dashing=u.pathing and u.pathing.isDashing,
            attackTarget=u.attackData and u.attackData.target,
            spell=cast and cast.valid and {name=cast.name,target=cast.target,start=cast.startTime,isAA=cast.isAutoAttack},
            w=b and {count=b.count,stacks=b.stacks,expires=b.expireTime,endTime=b.endTime}}
    end
    local function heroState()
        local buffs,items={},{}
        for i=0,math.min(g.myHero.buffCount or 0,128) do
            local b=g.myHero:GetBuff(i)
            if b and b.name and b.name~='' and (b.count or 0)>0 then
                buffs[#buffs+1]={name=b.name,count=b.count,stacks=b.stacks,expires=b.expireTime,endTime=b.endTime}
                if #buffs>=32 then break end
            end
        end
        if g.myHero.GetItemData and g.ITEM_1 then
            for slot=g.ITEM_1,g.ITEM_1+6 do
                local item=g.myHero:GetItemData(slot)
                if item and item.itemID and item.itemID~=0 then
                    local spell=g.myHero:GetSpellData(slot)
                    items[#items+1]={slot=slot,id=item.itemID,ammo=item.ammo,stacks=item.stacks,
                        spell=spell and spell.name,cd=spell and spell.currentCd,spellAmmo=spell and spell.ammo}
                end
            end
        end
        return buffs,items
    end
    function D:Tick()
        local now=clock();if self.lastTick then self.tickMax=math.max(self.tickMax,now-self.lastTick)end;self.lastTick=now
        local cast=g.myHero.activeSpell
        if cast and cast.valid then
            local key=tostring(cast.name)..':'..tostring(cast.startTime)..':'..tostring(cast.target)
            if key~=self.lastSpell then self.lastSpell=key;self:Record('active_spell',unit(g.myHero))end
        end
        if now>=self.nextSnapshot then
            self.nextSnapshot=now+500
            for k,expires in pairs(self.throttle)do if expires<now-30000 then self.throttle[k]=nil end end
            local enemies={};for i,u in ipairs(g.SDK.ObjectManager:GetEnemyHeroes(1600))do if i>5 then break end;enemies[i]=unit(u)end
            local minions={};for i,u in ipairs(g.SDK.ObjectManager:GetEnemyMinions(900))do if i>16 then break end;minions[i]=unit(u)end
            local spells={};for slot=0,3 do local s=g.myHero:GetSpellData(slot);spells[slot]={name=s.name,rank=s.level,cd=s.currentCd,cost=s.mana,ready=g.Game.CanUseSpell(slot)}end
            local orb=g.SDK.Orbwalker
            local buffs,items=heroState()
            self:Record('frame',{hero=unit(g.myHero),mana=g.myHero.mana,modes=orb.Modes,selected=unit(g.SDK.TargetSelector.Selected),
                lastTarget=unit(orb.LastTarget),spells=spells,enemies=enemies,minions=minions,metrics=C.metrics,
                attackEnabled=orb.AttackEnabled,movementEnabled=orb.MovementEnabled,lastReject=C.diagnostics.lastReject,
                buffs=buffs,items=items,
                callbackCalls=self.callbackCalls,callbackTotalMs=self.callbackTotal,callbackMaxMs=self.callbackMax,
                tickGapMaxMs=self.tickMax,dropped=self.dropped})
            self.callbackCalls=0;self.callbackTotal=0;self.callbackMax=0;self.tickMax=0
        end
        local input=g.SDK.Input
        if input and input.GetDiagnosticEvents then
            local rows,lost=input:GetDiagnosticEvents(self.inputSequence or 0,64)
            if lost>0 then self.inputLost=self.inputLost+lost;self:Record('input_gap',{lost=lost})end
            for _,r in ipairs(rows)do self.inputSequence=r.sequence;r.inputKind=r.kind;self:Record('input',r)end
        end
        self:Flush()
    end
    if g.SDK.Input then D.inputEnabled=g.SDK.Input.DiagnosticsEnabled;D.ownsInput=true;g.SDK.Input.DiagnosticsEnabled=true end
    function D:Close(reason)
        self:Record('stopped',{reason=reason});self:Flush(true)
        self:RestoreInput()
    end
    D:Record('loaded',{version=C.version,orbama=g.SDK.OrbamaVersion,champion=g.myHero.charName,session=session})
    D:Flush(true)
    return D
end
