local U=require('kata.util');local Profiles=require('kata.profiles')
local App={};App.__index=App
function App.new()
    return setmetatable({hero=myHero,sdk=SDK,active=true,build=Profiles.build,callbacks={},manualGeneration=0,metrics={ticks=0,totalMs=0,maxMs=0},enemies={},allies={},minions={}},App)
end
function App:init()
    self.profile=assert(Profiles.select(myHero.charName))
    self.config=require('kata.config').new(self.profile)
    self.state=require('kata.state').new(self)
    self.actions=require('kata.actions').new(self)
    self.session=tostring(self.actions.client:Now())
    self.items=require('kata.items').new(self)
    self.damage=require('kata.damage').new(self)
    self.planner=require('kata.planner').new(self)
    self.mobility=require('kata.mobility').new(self)
    self.logger=require('kata.log').new(self)
    self.telemetry=require('kata.telemetry').new(self)
    self.telemetry:install()
    return self
end
function App:now()return Game.Timer()end
function App:spell(slot)return self.state:spell(slot)end
function App:ready(slot)return not self.actions.pending[slot]and self.state:ready(slot)end
function App:mouse()
    local p=Game.mousePos
    if type(p)=='function'then local ok,value=pcall(p);p=ok and value or nil end
    return U.copy(p)or U.copy(mousePos)
end
function App:mode()
    local m=self.sdk.Orbwalker.Modes
    for _,row in ipairs({{'flee','ORBWALKER_MODE_FLEE'},{'combo','ORBWALKER_MODE_COMBO'},{'harass','ORBWALKER_MODE_HARASS'},
        {'last','ORBWALKER_MODE_LASTHIT'},{'lane','ORBWALKER_MODE_LANECLEAR'},{'jungle','ORBWALKER_MODE_JUNGLECLEAR'}})do
        if self.sdk[row[2]]and m[self.sdk[row[2]]]then return row[1]end
    end
end
function App:ownerActive(owner)
    if owner=='defense'then return true end
    if owner=='jump'then return self.config:get('jump')==true and not self.mobility.doneHeld end
    if owner=='idle'then return self.config:get('idleKill')and not self:mode()end
    if owner=='lane'or owner=='jungle'then
        local mode=self:mode();local id=self.sdk[owner=='lane'and 'ORBWALKER_MODE_LANECLEAR'or 'ORBWALKER_MODE_JUNGLECLEAR']
        return (mode=='lane'or mode=='jungle')and self.sdk.Orbwalker.Modes[id]==true
    end
    return self:mode()==owner
end
function App:available()
    return self.active and self.sdk==SDK and self.hero==myHero and myHero.charName==self.profile.hero and self.config:get('enabled')
        and not myHero.dead and not Game.IsChatOpen()and Game.IsOnTop()
        and not U.buff(myHero,{recall=true,recallimproved=true,zhonyasringshield=true},Game.Timer())
end
function App:anchorValid(o,origin)
    local d=self.state.daggers[U.id(o)]
    if d then return self.profile.id=='normal'and self.state:daggerValid(d)and U.dist(origin or self.hero.pos,d.pos)<=self.profile.eRange end
    if not U.valid(o)or U.same(o,self.hero)or U.dist(origin or self.hero.pos,o.pos)>self.profile.eRange then return false end
    local id=U.id(o)
    for _,w in ipairs(self.state.objects.wards or {})do if U.id(w)==id then
        local n=U.name(w.charName)
        return self.profile.id=='classic'and w.team==self.hero.team and n~='bluetrinket'and n~='farsightward'and n~='zombieward'
    end end
    -- A new ward can precede SharedData's identity refresh.
    if U.name(o.charName):find('ward',1,true)then return self.profile.id=='classic'and o.team==self.hero.team and U.name(o.charName)~='farsightward'and U.name(o.charName)~='zombieward'end
    for _,kind in ipairs({'heroes','minions'})do for _,x in ipairs(self.state.objects[kind]or {})do if U.id(x)==id then return true end end end
    return false
end
function App:anchors()
    local out,seen={},{}
    local function add(o)if #out<64 and U.id(o)and not seen[U.id(o)]and self:anchorValid(o)then out[#out+1]=o;seen[U.id(o)]=true end end
    for _,o in ipairs(self.state.objects.heroes or {})do add(o)end
    for _,d in pairs(self.state.daggers)do add(d.object)end
    for _,o in ipairs(self.state.objects.minions or {})do add(o)end
    if self.profile.id=='classic'then for _,o in ipairs(self.state.objects.wards or {})do add(o)end end
    return out
end
function App:landing(anchor,target,side,dagger)
    if not self:anchorValid(anchor)then return end
    local pos=dagger and dagger.pos or anchor.pos
    if self.profile.id=='classic'then return U.copy(pos)end
    if side then if U.dist(pos,side)<=self.profile.eOffset then return U.copy(side)else return end end
    local toward=target and U.predict(target,.15)or self:mouse()or self.hero.pos
    return U.toward(pos,toward,math.min(100,U.dist(pos,toward)))
end
function App:hasReturn(pos,used)
    -- E has just been spent. An ally in range is not an immediately available escape.
    return U.dist(pos,self.hero.pos)<=550 and not self.state:turret(pos)
        and self.mobility.terrain:walkLine(pos,self.hero.pos,self.hero.boundingRadius or 35)==true
end
function App:attackRange(o)return(self.hero.range or 125)+(self.hero.boundingRadius or 35)+(o.boundingRadius or 35)end
function App:healthPrediction(o,delay)
    local hp=self.sdk.HealthPrediction or self.sdk.Health
    if hp and hp.GetPrediction then return hp:GetPrediction(o,delay)end
    return o.health
end
function App:aaSaves(o,deadline)
    local attack=self.sdk.Attack
    if U.dist(self.hero.pos,o.pos)>self:attackRange(o)then return false end
    local delay=attack and attack.GetWindup and attack:GetWindup()or .3
    if delay>deadline or (self.sdk.Orbwalker.CanAttack and not self.sdk.Orbwalker:CanAttack())then return false end
    return self.damage:amount('AA',o)>=self:healthPrediction(o,delay)
end
function App:legal(a,resolved,farmFacts)
    if not self:available()or not self:ownerActive(a.owner)then return false,'context_ended'end
    if a.validate then local ok,why=a.validate();if not ok then return false,why or 'dependent_validation'end end
    local pos=resolved or a.pos;local t=a.combatTarget or a.target
    if a.slot and a.slot<=3 and(a.owner=='combo'or a.owner=='harass'or a.owner=='lane'or a.owner=='jungle'or a.owner=='last')then
        if not self.config:get(a.owner..({'Q','W','E','R'})[a.slot+1])then return false,'spell_setting_disabled'end
    end
    if a.farm and U.valid(t)then
        local impact=a.slot==0 and .25+U.dist(self.hero.pos,t.pos)/self.profile.qSpeed or .2
        -- Only the synchronous planner lends these facts. They are never put
        -- on the action; queued dispatch calls legal() without them.
        local facts=farmFacts and farmFacts.target==t and farmFacts.impact==impact
            and farmFacts.at==Game.Timer()and farmFacts.observedHP==t.health and farmFacts
        local hp=facts and facts.hp or self:healthPrediction(t,impact)
        if hp<=0 then return false,'already_dying_to_incoming_hit'end
        if a.owner=='last'then
            local damage=facts and facts.damage or self.damage:amount(a.slot,t)
            local saved
            if facts and facts.aaSaved~=nil then saved=facts.aaSaved else saved=self:aaSaves(t,impact)end
            if damage<hp or saved then return false,'last_hit_no_longer_needed'end
        end
    end
    if self.state:channel()and a.owner=='combo'and a.release then
        local emptyMove=a.kind=='move'and self.config:get('smartR')and self.state:enemiesNear(self.hero.pos,self.profile.rRange)==0
        if not emptyMove and(not a.slot or a.slot>=6 or not U.valid(t)or not self.damage:lethal(a.slot,t,.3)or self.damage:lethal(3,t,.34))then
            return false,'r_followup_no_longer_better'
        end
    end
    if a.extended and(not self.config:get('extended')or self:mode()~='combo')then return false,'extended_consent_ended'end
    if a.kind=='move'then return U.position(pos)and self.mobility.terrain:wall(pos)==false,'movement_terrain_unknown'end
    if a.kind=='attack'then return U.valid(t)and U.dist(self.hero.pos,t.pos)<=self:attackRange(t),'attack_invalid'end
    if a.ward then return true end
    if a.rule then
        local item=self.hero:GetItemData(a.slot)
        if not item or item.itemID~=a.itemID or not self.items:enabled(a.itemID)then return false,'item_changed'end
        if a.rule.active=='stasis'then return self.items:stasisNeeded(),'stasis_not_needed'end
        if a.rule.active=='move'then return a.extended and self.planner:safe(pos,t),'movement_item_unsafe'end
        return U.valid(t)and U.dist(self.hero.pos,t.pos)<=a.rule.range and not self.damage:protected(t),'item_target_invalid'
    end
    if a.slot==1 and a.prepareWall then return a.owner=='jump'or a.owner=='flee','wall_context'end
    if not U.valid(t)and not a.dagger then return false,'invalid_target'end
    if t and t.team~=self.hero.team and not a.escape and(self.damage:protected(t)or self.damage:spellShield(t))then return false,'target_protected'end
    if a.slot==0 then return U.dist(self.hero.pos,t.pos)<=self.profile.qRange,'q_range'end
    if a.slot==1 then return U.dist(self.hero.pos,t.pos)<=self.profile.wRange,'w_range'end
    if a.slot==2 then
        local anchor=a.anchor or t;local landing=pos or anchor.pos
        if not self:anchorValid(anchor)then return false,'e_anchor_invalid'end
        if self.profile.id=='normal'and U.dist(landing,anchor.pos)>self.profile.eOffset then return false,'e_offset'end
        if pos and self.mobility.terrain:wall(pos)~=false then return false,'e_terrain_unknown'end
        if not self.planner:safe(landing,t,a.escape)then return false,'e_safety'end
        -- Avoid selecting a different overlapping E anchor at the outgoing aim.
        if pos then for _,o in ipairs(self:anchors())do
            if not U.same(o,anchor)and U.dist(o.pos,pos)+5<U.dist(anchor.pos,pos)then return false,'e_ambiguous_anchor'end
        end end
        if a.owner=='harass'and(not self:hasReturn(landing,anchor)or self.state:enemiesNear(landing,450)>1)then return false,'harass_no_return'end
        return true
    end
    if a.slot==3 then return not self.state:channel()and not self.state:interruptIncoming()and self.state:enemiesNear(self.hero.pos,self.profile.rActivation)>0,'r_activation_or_observed_interrupt'end
    if a.slot==4 or a.slot==5 then
        local name=U.name(self.state:spell(a.slot).name)
        if name=='summonerflash'then return a.extended and U.dist(self.hero.pos,pos)<=400 and self.mobility.terrain:wall(pos)==false and self.planner:safe(pos,t),'flash_invalid'end
        return name=='summonerdot'and U.dist(self.hero.pos,t.pos)<=600 and self.config:get('ignite')and self.damage:lethal(a.slot,t,5),'ignite_not_lethal'
    end
    return false,'unsupported_action'
end
function App:record(event,data)
    if self.logger then self.logger:write(event,data)end
end
function App:flushLog(force)
    if self.logger then self.logger:flush(force)end
end
function App:log(event,a,detail)
    if not self.config:get('diagnostics')then return end
    local pos=a and(a.pos or a.target and a.target.pos)
    local spell=a and a.slot and self.state:spell(a.slot)or {}
    self:record(event,{id=a and a.actionID,slot=a and a.slot,owner=a and a.owner,target=a and U.id(a.target),
        pos=U.copy(pos),spell=spell.name,cd=spell.currentCd,detail=detail,mode=self:mode()or 'idle'})
end
function App:tick()
    if not self.active then return end
    local started=self.actions.client:Now()
    self:decide()
    if not self.sdk.OnMaintenance then self:flushLog()end
    local elapsed=self.actions.client:Now()-started;self.metrics.ticks=self.metrics.ticks+1;self.metrics.totalMs=self.metrics.totalMs+elapsed;self.metrics.maxMs=math.max(self.metrics.maxMs,elapsed)
    self.telemetry:safe('tick',elapsed)
end
function App:decide()
    self.state:refresh();self.items:refresh();self.actions:tick()
    if not self:available()then
        self.actions:cancel(nil,'unavailable');self.mobility:cancel('unavailable')
        self.actions.client:SetBlocked('channel','attack',false);self.actions.client:SetBlocked('channel','move',false);return
    end
    if self.sdk.Evade and type(self.sdk.Evade.Evading)=='function'and self.sdk.Evade:Evading()then
        self.actions.client:SetBlocked('channel','attack',false);self.actions.client:SetBlocked('channel','move',false);return
    end
    local channel=self.state:channel()
    local protect=channel==true or self.actions.pending[3]~=nil
    self.actions.client:SetBlocked('channel','attack',protect);self.actions.client:SetBlocked('channel','move',protect)
    local mode=self:mode();local owner=self.config:get('jump')and 'jump'or(mode=='flee'and 'flee'or nil)
    if mode~='harass'then self.trade=nil end
    local defense=self.items:activeCandidate(nil,nil)
    if defense then self.actions:submit(defense);return end
    if self.mobility:tick(owner)then return end
    local action
    if mode=='combo'or mode=='harass'then action=self.planner:combat(mode)
    elseif mode=='lane'or mode=='jungle'or mode=='last'then
        if not channel then
            action=self.planner:farm(mode)
            if not action and mode=='lane'and self:ownerActive('jungle')then action=self.planner:farm('jungle')end
        end
    elseif not mode and self.config:get('idleKill')and not channel then
        for _,o in ipairs(self.enemies)do if U.valid(o)and self:ready(0)and self.damage:lethal(0,o)then
            local a={slot=0,target=o,owner='idle'};if self:legal(a)then action=a;break end
        end end
    end
    if channel and self.config:get('smartR')and self.state:enemiesNear(self.hero.pos,self.profile.rRange)==0 and mode=='combo'then
        local pos=self:mouse();if pos then action={kind='move',pos=pos,owner='combo',release=true}end
    end
    self.preview=action
    if action then if action.kind=='wardplan'then self.mobility:start(action.pos,action.owner,action.target)else self.actions:submit(action)end end
end
function App:draw()
    if self.telemetry then self.telemetry:safe('draw')end
    if not self.active or not self.config:get('draw')or not Draw then return end
    local p=self.mobility.preview or self.preview
    if p and p.pos and Draw.Circle then Draw.Circle(U.vector(p.pos),65,2,Draw.Color(220,120,230,180))end
    local action=self.preview;local target=action and(action.combatTarget or action.target)
    if U.valid(target)and Draw.Circle then
        Draw.Circle(target.pos,target.boundingRadius or 45,1,Draw.Color(200,220,170,70))
        local screen=target.pos2D
        if screen and screen.onScreen~=false and Draw.Text and action.estimate then Draw.Text('~'..math.floor(action.estimate)..' damage',14,screen.x,screen.y-30,Draw.Color(220,220,230,200))end
    end
end
function App:event(msg,param)
    if not self.active then return end
    local cursor=self.sdk.Cursor
    if cursor and cursor.IsSyntheticEvent and cursor:IsSyntheticEvent()then return end
    if msg==256 and(param==HK_Q or param==HK_W or param==HK_E or param==HK_R)then self.manualGeneration=self.manualGeneration+1;self.actions:cancel(nil,'manual_spell')end
    if msg==516 then
        self.trade=nil
        self.mobility:cancel('manual_pointer');self.mobility.doneHeld=true
        -- A physical right click can interrupt R; never replay or suppress it.
        self.actions.client:SetBlocked('channel','move',false)
    end
end
function App:install()
    local function attach(list,fn)
        assert(type(list)=='table','SDK callback list unavailable')
        local wrapper=function(...)if not self.active then return end;local ok,why=pcall(fn,...);if not ok then self:log('error',nil,why);self:Shutdown('callback_error');print('[Katarina] '..tostring(why))end end
        list[#list+1]=wrapper;self.callbacks[#self.callbacks+1]={list=list,fn=wrapper}
    end
    attach(self.sdk.OnTick,function()self:tick()end);attach(self.sdk.OnDraw,function()self:draw()end);attach(self.sdk.OnWndMsg,function(m,p)self:event(m,p)end)
    if self.sdk.OnMaintenance then attach(self.sdk.OnMaintenance,function()self:flushLog()end)end
    if Callback and Callback.Add then self.unload=function()self:Shutdown('unload')end;Callback.Add('UnLoad',self.unload)end
    self.loadedAt=Game.Timer();self.state:refresh();self.items:refresh();self:log('controller_ready',nil,self.build);self:flushLog(true)
end
function App:Shutdown(reason)
    if not self.active then return end;self.active=false
    if self.actions then self.actions:close()end
    for _,row in ipairs(self.callbacks)do for i=#row.list,1,-1 do if row.list[i]==row.fn then table.remove(row.list,i)end end end
    self.callbacks={}
    if self.unload and Callback and Callback.Del then pcall(Callback.Del,'UnLoad',self.unload)end
    if self.config then self.config:close()end
    if self.logger then self:record('shutdown',{reason=reason});pcall(self.flushLog,self,true)end
    if _G.KatarinaController==self then _G.KatarinaController=nil end
end
return App
