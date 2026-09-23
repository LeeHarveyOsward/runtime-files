return function(g, modules, champion)
    local sdk=g.SDK;local registry=g.ClassicAIOv2
    if registry and registry.Shutdown then registry:Shutdown('superseded') end
    local C={version='2.1.8-dev',generation=(registry and registry.generation or 0)+1,enabled=true,
        pending={},resources={},history={},quarantine={},observedSpells={},spellStates={},locks={},menus={},diagnostics={},metrics={requested=0,sent=0,observed=0,rejected=0},claims={}}
    g.ClassicAIOv2=C
    function C:Trace(kind,row,throttle)
        if not self.logger then return end
        local ok,err=pcall(self.logger.Record,self.logger,kind,row,throttle)
        if not ok then self.logger:Disable(err)end
    end
    local function point(v) return v and {x=v.x,y=v.y or 0,z=v.z} end
    local function clone(t)
        local o={};for k,v in pairs(t)do o[k]=v end;return setmetatable(o,getmetatable(t))
    end
    function C:Active()
        if not self.enabled or g.ClassicAIOv2~=self or g.SDK~=sdk then return false end
        if rawget(g,'Classic'..champion) or package.loaded['ClassicAIO\\Heroes\\Classic'..champion] then
            self:Shutdown('ClassicAIO v1 loaded');return false
        end
        return true
    end
    function C:Cancel(owner,reason)
        for _,q in pairs(self.pending)do if not owner or q.owner==owner then q.cancelled=true;q.callbacks={};self.adapter:Cancel(q.id,reason or "owner_cancelled")end end
    end
    function C:Shutdown(reason)
        if not self.enabled then return end
        if self.logger then pcall(self.logger.Close,self.logger,reason)end
        self.enabled=false;self.reason=reason;self.locks={}
        if self.adapter then self.adapter:Close(reason) end
        self.pending={};self.resources={}
    end
    local clientOptions={name='ClassicAIOv2',active=function()return C:Active()end}
    if sdk.Actions and sdk.Actions.GetCapabilities and sdk.Actions:GetCapabilities().createClient then
        C.adapter=sdk.Actions:CreateClient(clientOptions)
    else C.adapter=modules.actionClient(g,clientOptions)end
    local A=C.adapter
    local keyedMechanical=A:Capabilities().keyedMechanicalObservation==true
    function C:Available()
        return self:Active() and not g.myHero.dead and not g.Game.IsChatOpen() and g.Game.IsOnTop()
    end
    local env=setmetatable({},{__index=g});env._G=env;C.env=env
    env.os=setmetatable({clock=function()return A:Now()/1000 end},{__index=g.os})
    env.SDK=setmetatable({},{__index=sdk});env.V2=C
    local prediction=modules.prediction(assert(g.GGPrediction,'Prediction provider must be loaded'),g.myHero,g.Vector)
    env.GGPrediction=prediction.facade;C.prediction=prediction
    local slots={}
    for _,name in ipairs({'Q','W','E','R','SUMMONER_1','SUMMONER_2'})do slots[g['HK_'..name]]=g['_'..name] or g[name] end
    for i=1,7 do if g['HK_ITEM_'..i] then slots[g['HK_ITEM_'..i]]=g['ITEM_'..i] end end
    function C:Stamp(key)
        local slot=slots[key];local d=slot and g.myHero:GetSpellData(slot)
        if not d then return '' end
        return tostring(d.name)..':'..tostring(d.currentCd)..':'..tostring(d.toggleState)..':'..tostring(d.ammo)
    end
    function C:Invoke(fn,selfObject,args,name)
        if not self:Active() then return end
        local old=self.decision;local previousContext=self.executionContext
        local declaration=self.policy and self.policy.methods[name]
        if not previousContext and declaration then self.executionContext=declaration(selfObject) end
        if not old and name~='Tick' and name~='OnTick' and name~='Draw' and name~='__init' and name~='LoadMenu' then
            self.decision={name=name,menuReads={}}
        end
        local began=self.logger and g.GetTickCount()
        local results={pcall(fn,selfObject,unpack(args))};self.decision=old;self.executionContext=previousContext
        if began then
            local elapsed=math.max(0,g.GetTickCount()-began);local l=self.logger
            l.callbackCalls=l.callbackCalls+1;l.callbackTotal=l.callbackTotal+elapsed;l.callbackMax=math.max(l.callbackMax,elapsed)
        end
        if not results[1] then self:Trace('callback_error',{method=name,error=tostring(results[2])});self:Shutdown('champion_callback_error');error(results[2],0) end
        return unpack(results,2)
    end
    env.class=function(name)
        local class={};class.__index=class
        setmetatable(class,{__call=function(t,...)
            for k,fn in pairs(t)do if type(fn)=='function' then
                local original,method=fn,k
                t[k]=function(object,...)return C:Invoke(original,object,{...},method)end
            end end
            local object=setmetatable({},t);C.champion=object
            object:__init(...);return object
        end});env[name]=class;return class
    end
    local function guarded(fn)
        return function(...)if C:Active() then return fn(...) end end
    end
    env.Callback={Add=function(event,fn)
        g.Callback.Add(event,guarded(function(...)
            if event=='Tick' then C:Observe();C:MaintainClaims() end
            return fn(...)
        end))
    end}
    env.DelayAction=function(fn,delay,args)
        local generation=C.generation
        g.DelayAction(function()if C:Active() and C.generation==generation then fn(unpack(args or {}))end end,delay)
    end
    local orb=setmetatable({},{__index=sdk.Orbwalker});env.SDK.Orbwalker=orb
    function orb:SetAttack(allowed) C.locks.attack=not allowed;A:SetBlocked("champion","attack",not allowed) end
    function orb:SetMovement(allowed) C.locks.move=not allowed;A:SetBlocked("champion","move",not allowed) end
    for _,name in ipairs({'OnPreAttack','OnPreMovement','OnPostAttack','OnPostAttackTick','OnAttack'})do
        if sdk.Orbwalker[name] then
            orb[name]=function(_,fn)
                return sdk.Orbwalker[name](sdk.Orbwalker,guarded(function(...)
                    local args=select(1,...);local mutable=type(args)=="table"
                    local was=mutable and args.Process
                    local result=fn(...)
                    if mutable and was==false then args.Process=false end
                    return result
                end))
            end
        end
    end
    -- Never lend SDK's raw Cursor to champion code.
    env.SDK.Cursor=setmetatable({Add=function(_,key,target)return C:Cast(key,target,{independent=false,owner='manual'})end},
        {__index=function(_,key)if key=='Step' then return 0 end end})
    env.Control=setmetatable({CastSpell=function(key,target)return C:Cast(key,target)end,
        KeyDown=function()return false end,KeyUp=function()return false end},{__index=g.Control})
    env.require=function(name)
        if name=='GGPrediction' or name=='ClassicAIO\\Utils' then return true end
        return g.require(name)
    end
    local config=g.ClassicAIOv2Config or {};C.config=config
    C.ggAutomationApproved=config.ggAutomationApproved
    local function routeMenu(parent,args,path,legacyPath)
        local spec=clone(args);spec.leftIcon=nil
        local values=config.values or {};local migration=config.migration or {}
        if values[path]~=nil then spec.value=values[path]
        elseif migration.enabled==true and migration.values and migration.values[legacyPath]~=nil then
            local old=migration.values[legacyPath]
            if spec.value==nil or type(old)==type(spec.value) then spec.value=old end
        end
        local menu
        if parent then menu=parent.raw(parent.node,spec) or parent.node[spec.id]
        else menu=g.MenuElement(spec)end
        if not menu then return menu end
        local rawValue=menu.Value
        if rawValue then menu.Value=function(node,...)
            local result=rawValue(node,...)
            if select('#',...)==0 and C.decision and C.decision.menuReads then C.decision.menuReads[node]=result end
            return result
        end end
        local raw=menu.MenuElement
        menu.MenuElement=function(node,child)
            return routeMenu({node=node,raw=raw},child,path..'.'..tostring(child.id),legacyPath..'.'..tostring(child.id))
        end
        return menu
    end
    env.MenuElement=function(args)
        local spec=clone(args);local legacy=spec.id
        spec.id=spec.id:gsub('Classic_AIO','ClassicAIOv2'):gsub('ClassicActivator','ClassicAIOv2Activator')
        spec.name=spec.name:gsub('Classic AIO','Classic AIO v2')
        local menu=routeMenu(nil,spec,spec.id,legacy);C.menus[spec.id]=menu;return menu
    end
    function C:ModeContext(mode,condition)
        local names={Combo='COMBO',Harass='HARASS',LaneClear='LANECLEAR',LastHit='LASTHIT',Flee='FLEE'}
        local modeID=sdk['ORBWALKER_MODE_'..names[mode]]
        if mode=='LaneClear' and not sdk.Orbwalker.Modes[modeID] and sdk.Orbwalker.Modes[sdk.ORBWALKER_MODE_JUNGLECLEAR] then modeID=sdk.ORBWALKER_MODE_JUNGLECLEAR end
        return {mode=mode,modes={modeID},condition=function()return env.GetMode()==mode and (not condition or condition())end,
            combat=mode=='Combo' or mode=='Harass',priority=(mode=='LaneClear' or mode=='LastHit') and 'background' or 'normal'}
    end
    function C:HeldContext(held)return {held=held,priority='interactive'}end
    function C:Fresh(fn,...)
        local previous=self.validating;self.validating=true
        local result={pcall(fn,...)};self.validating=previous
        if not result[1]then error(result[2],0)end
        return unpack(result,2)
    end
    function C:RegisterPolicy(policy)
        self.policy=policy
        if policy.channel then A:Condition('champion','channel',function(q)return self:Fresh(policy.channel,self.champion,q)end,policy.exceptions)end
    end
    function C:Cast(key,target,options)
        options=options or {};local binding=target and prediction.bindings[target]
        local targetObject=options.intentTarget or target and target.pos and target or binding and binding.target
        local targetID=targetObject and (targetObject.networkID or targetObject.handle)
        self.lastIntent=nil
        if not self:Available() then return false end
        local slot=options.slot or slots[key];if options.slot then slots[key]=options.slot end
        local resource=slot and 'slot:'..slot or 'key:'..key
        local kind=not target and 'none' or target.pos and 'object' or target.z~=nil and 'world' or 'screen'
        local mode=env.GetMode and env.GetMode();local decision=self.decision
        local owner=options.owner or (decision and decision.name or 'activator')
        local declaration=self.policy and self.policy.methods[owner]
        local context=self.executionContext or (declaration and declaration(self.champion)) or options.context
        if options.context then context=options.context end
        local combat=context and context.combat==true
        local now=A:Now();local spell=slot and g.myHero:GetSpellData(slot)
        local q={key=key,resource=resource,keys=options.keys or {key},type=options.type,kind=kind,target=kind=='world' and point(target) or target,
            targetID=targetID,object=targetObject,owner=owner,mode=context and context.mode or nil,context=context,exceptions=options.exceptions,
            replace=options.replace or 'higher_priority',equivalence=options.equivalence,
            survivePointerMotion=options.survivePointerMotion,
            independent=options.independent~=false and combat and kind~='screen',
            priority=options.priority or (context and context.priority or 'normal'),expires=now+(options.ttl or 250),
            callbacks={},stamp=self:Stamp(key),spellName=spell and spell.name,
            toggleState=spell and spell.toggleState,ammo=spell and spell.ammo,cooldown=spell and spell.currentCd,requestGameTime=g.Game.Timer(),previousCastStart=g.myHero.activeSpell and g.myHero.activeSpell.startTime,requestedAt=now,range=options.range or binding and binding.settings.Range,itemID=slot and slot>=g.ITEM_1 and g.myHero:GetItemData(slot).itemID}
        q.observe=options.observe
        q.start=function()return self:Available()end
        q.continue=function()return not q.cancelled and self:Available() and A:ContextValid(q,'continuation') end
        local menuReads={};for node,value in pairs(decision and decision.menuReads or {})do menuReads[node]=value end
        local validate=modules.policies(self,q,slot,options)
        q.reconcile=function()
            local cast=g.myHero.activeSpell
            return not g.myHero.dead and slot~=nil and g.Game.CanUseSpell(slot)==0
                and g.myHero:GetSpellData(slot).currentCd==0 and not (cast and cast.valid and not cast.isAutoAttack)
        end
        q.mechanical=function(resolved)
            if not q.continue() or not A:ContextValid(q) then return false,'context_changed' end
            if self:Stamp(key)~=q.stamp then return false,'spell_state_changed' end
            if slot then
                local current=g.myHero:GetSpellData(slot)
                if g.Game.CanUseSpell(slot)~=0 or not current or current.level==0 then return false,'spell_unavailable' end
                local paid=self.policy and self.policy.costPaid and self.policy.costPaid(self.champion,q,slot)
                if not paid and type(current.mana)=='number' and current.mana>g.myHero.mana then return false,'insufficient_mana' end
            end
            if q.itemID and g.myHero:GetItemData(slot).itemID~=q.itemID then return false,'item_changed' end
            if targetObject and (not env.IsValid(targetObject) or (targetObject.networkID or targetObject.handle)~=targetID) then return false,'target_invalid' end
            if q.range and q.target then
                local p=resolved and resolved.position or (q.kind=='object' and q.target.pos or q.target)
                if not p or env.GetDistance(p,g.myHero.pos)>q.range then return false,'target_out_of_range' end
            end
            for node,value in pairs(menuReads)do if node:Value()~=value then return false,'settings_changed'end end
            if binding and resolved then
                local valid,reason=prediction:Validate(binding,resolved)
                if not valid then return false,reason end
            end
            return validate(resolved)
        end
        local mechanical=q.mechanical;q.mechanical=function(resolved)
            local valid,reason=self:Fresh(mechanical,resolved)
            q.lastValidationReason=not valid and (reason or 'champion_condition_changed') or nil
            return valid,reason
        end
        if options.resolve and kind=='world' then q.resolve=options.resolve end
        if binding then
            q.resolve=function()
                if not q.continue() or not env.IsValid(targetObject) then return nil,'intent_ended' end
                return prediction:Resolve(binding)
            end
        end
        if not q.start() then return false end
        self.metrics.requested=self.metrics.requested+1
        local id,reason=A:Submit(q)
        local initial=id and A:Poll(id)
        if self.logger and reason~='deduplicated' then self:Trace('cast_request',{id=id,key=key,owner=owner,target=targetID,priority=q.priority,
            reason=initial and initial.reason or reason,submission=reason,state=initial and initial.state,
            validation=q.lastValidationReason,spell=q.spellName},not id and 500 or nil)end
        if not id then self.metrics.rejected=self.metrics.rejected+1;self.diagnostics.lastReject=reason;return false end
        if initial and initial.state=='cancelled_before_send' then
            self.metrics.rejected=self.metrics.rejected+1;self.diagnostics.lastReject=initial.reason or initial.state
            A:Finish(id)
            return false
        end
        if reason=='deduplicated' then return true,id end
        local prior=self.resources[resource]
        if prior and prior.id~=id then
            prior.cancelled=true;prior.callbacks={};self.pending[prior.key]=nil
        end
        q.id=id;self.pending[key]=q;self.resources[resource]=q;self.lastIntent=q
        return true,id
    end
    function C:RunDecision(name,fn)
        local old=self.decision;local previousContext=self.executionContext
        local declaration=self.policy and self.policy.methods[name]
        if not self.executionContext and declaration then self.executionContext=declaration(self.champion) end
        self.decision={name=name,menuReads={}}
        local ok,result=pcall(fn);self.decision=old;self.executionContext=previousContext;if not ok then error(result,0)end;return result
    end
    function C:Delayed(key,delay,fn)
        self.delayed=self.delayed or {};if self.delayed[key] then return end
        self.delayed[key]=true
        env.DelayAction(function()self.delayed[key]=nil;self:RunDecision(key,fn)end,delay)
    end
    function C:AfterCast(key,fn)
        local q=self.lastIntent
        if q and q.key==key and self.pending[key]==q then q.callbacks[#q.callbacks+1]=fn end
    end
    function C:Observe()
        for slot=0,3 do
            local d=g.myHero:GetSpellData(slot);local old=self.spellStates[slot]
            if d then
                if old and (d.currentCd>(old.cd or 0) or d.name~=old.name or d.toggleState~=old.toggle) then self.observedSpells[slot]=g.Game.Timer() end
                self.spellStates[slot]={cd=d.currentCd,name=d.name,toggle=d.toggleState}
            end
        end
        for key,q in pairs(self.pending)do
            local r=A:Poll(q.id)
            if self.logger then
                local status=r and (tostring(r.state)..':'..tostring(r.observedAt)..':'..tostring(r.reason)..':'..tostring(r.interrupted)..':'..tostring(r.competitor)) or 'missing'
                if q.logStatus~=status then q.logStatus=status;self:Trace('cast_state',{id=q.id,key=key,owner=q.owner,target=q.targetID,state=r and r.state,reason=r and r.reason,validation=q.lastValidationReason,sentAt=r and r.sentAt,observedAt=r and r.observedAt,interrupted=r and r.interrupted,competitor=r and r.competitor,interferenceCause=r and r.interferenceCause,interferenceID=r and r.interferenceID})end
            end
            if not r or r.state=='cancelled_before_send' then self.pending[key]=nil;self.metrics.rejected=self.metrics.rejected+1
            else
                if r.jobCancelled then q.cancelled=true;q.callbacks={} end
                if r.state=='send_uncertain' or r.interrupted or r.competitor then q.ambiguous=true end
                if r.sentAt and not q.sentAt then q.sentAt=r.sentAt;self.metrics.sent=self.metrics.sent+1 end
                if not r.sentAt and not q.continue() then A:Cancel(q.id,'mode_or_context_ended')
                elseif r.sentAt then
                    local slot=slots[key];local d=slot and g.myHero:GetSpellData(slot)
                    local changed
                    if q.observe then changed=q.observe()
                    else
                        local cast=g.myHero.activeSpell
                        local started=cast and cast.valid and not cast.isAutoAttack and cast.name==q.spellName
                            and cast.startTime and cast.startTime~=q.previousCastStart and cast.startTime>=q.requestGameTime
                        changed=started or d and (d.name~=q.spellName or d.toggleState~=q.toggleState or type(d.currentCd)=='number' and d.currentCd>(q.cooldown or 0)
                            or type(d.ammo)=='number' and type(q.ammo)=='number' and d.ammo<q.ammo)
                    end
                    -- A mechanical change can be real while its attribution remains ambiguous.
                    -- Journal it once without confirming this action or invoking its callbacks.
                    if changed and self.logger and not q.evidenceLogged then
                        q.evidenceLogged=true
                        local cast=g.myHero.activeSpell
                        self:Trace('cast_evidence',{id=q.id,key=key,owner=q.owner,target=q.targetID,sentAt=q.sentAt,
                            ambiguous=q.ambiguous==true,customObserver=q.observe~=nil,spell=d and d.name,cooldown=d and d.currentCd,initialCooldown=q.cooldown,
                            toggle=d and d.toggleState,ammo=d and d.ammo,activeSpell=cast and cast.valid and cast.name,
                            activeStart=cast and cast.valid and cast.startTime,interrupted=r.interrupted,competitor=r.competitor,
                            interferenceCause=r.interferenceCause,interferenceID=r.interferenceID,commandReceipt=r.commandReceipt})
                    end
                    local receipt=not q.observe and keyedMechanical and r.commandReceipt
                    if changed and (not q.ambiguous or receipt) then
                        local observedAt=A:Now()
                        local evidence={kind='mechanical',at=observedAt,source='spell_state_transition',unique=true}
                        if receipt then
                            evidence.attribution='command_key';evidence.key=receipt.key
                            evidence.generation=receipt.generation;evidence.session=receipt.session
                        end
                        local accepted,why=A:Observe(q.id,evidence)
                        q.observationReason=why
                        if accepted then
                            q.observedAt=observedAt;self.metrics.observed=self.metrics.observed+1
                            if self.logger then self:Trace('cast_observed',{id=q.id,key=key,owner=q.owner,target=q.targetID,sentAt=q.sentAt,observedAt=observedAt,attribution=evidence.attribution,aimAmbiguous=q.ambiguous==true})end
                            for _,fn in ipairs(q.callbacks)do if self:Active() and q.continue() then fn(q) end end
                            self.pending[key]=nil
                        else q.ambiguous=true end
                    end
                    if self.pending[key] and not q.observedAt and A:Now()>q.expires+750 then
                        q.outcome='unobserved_handoff'
                        if A:Reconcile(q.id) then self.pending[key]=nil end
                    end
                end
            end
            if not self.pending[key] then
                if self.logger then self:Trace('cast_finished',{id=q.id,key=key,owner=q.owner,target=q.targetID,
                    state=r and r.state,reason=r and r.reason,validation=q.lastValidationReason,observationReason=q.observationReason,
                    outcome=q.outcome or (q.observedAt and 'mechanically_observed' or not q.sentAt and 'rejected_before_send' or 'unobserved'),
                    sentAt=q.sentAt,observedAt=q.observedAt,ambiguous=q.ambiguous==true})end
                A:Finish(q.id)
                if self.resources[q.resource]==q then self.resources[q.resource]=nil end
                self.history[#self.history+1]={id=q.id,owner=q.owner,key=q.key,resource=q.resource,outcome=q.outcome,sentAt=q.sentAt,observedAt=q.observedAt};if #self.history>128 then table.remove(self.history,1)end
            end
        end
    end
    function C:Automation(name,on)
        if A.name=='Orbama' then
            if on and not self.claims[name] then self.claims[name]=A:Claim(name,true)==true
            elseif not on and self.claims[name] then A:Claim(name,false);self.claims[name]=nil end
            return on and self.claims[name]==true
        end
        local provider=name=='qss' and sdk.ItemManager or sdk.SummonerSpell
        local menu=provider and provider[name=='qss' and 'MenuQss' or 'MenuCleanse']
        if menu and menu.Enabled and menu.Enabled:Value() then return false end
        -- An unknown provider configuration is never guessed to be conflict-free.
        return on and self.ggAutomationApproved and self.ggAutomationApproved[name]==true
    end
    function C:MaintainClaims() if env.V2RefreshClaims then env.V2RefreshClaims()end end
    function C:Chord(modifier,key) return self:Cast(key,nil,{keys={modifier,key},type='chord',independent=false}) end
    function C:HasObservedSpell() return g.myHero.activeSpell and g.myHero.activeSpell.valid and not g.myHero.activeSpell.isAutoAttack end
    local logOK,logger=pcall(modules.diagnostics,g,C)
    if logOK then C.logger=logger else C.diagnostics.loggingError=tostring(logger)end
    g.Callback.Add('Tick',function()
        if C:Active()then
            C:Observe();C:MaintainClaims();A:Tick()
            if C.logger and not C.logger.failed then
                local ok,err=pcall(C.logger.Tick,C.logger)
                if not ok then C.logger:Disable(err)end
            end
        end
    end)
    g.Callback.Add('Load',function()C:Active()end)
    g.Callback.Add('WndMsg',function(msg,key)
        if not C:Active() or msg~=256 then return end
        for k,q in pairs(C.pending)do
            if k==key and not A:IsSending() and not (sdk.Input and sdk.Input.LastInputEdge and sdk.Input.LastInputEdge.classification~='new manual press or unmatched echo') then
                local r=A:Poll(q.id)
                if r and r.sentAt then q.ambiguous=true else A:Cancel(q.id,'manual_spell')end
            end
        end
    end)
    C.env=env;return C
end
