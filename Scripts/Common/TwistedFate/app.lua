local P=require('CombatProfiles.twisted_fate')
local U=require('tf.util')
local App={};App.__index=App
App.build='CardMarx-10'
function App.new()
    return setmetatable({hero=myHero,sdk=SDK,active=true,build=App.build,records={},recordIndex=0},App)
end
function App:initialize()
    local c=self
    c.profile=assert(P.Profile(myHero.charName));c.config=require('tf.config').new(c.profile)
    c.state=require('tf.state').new(c)
    c.actions=require('tf.actions').new(c);c.cards=require('tf.cards').new(c)
    c.q=require('tf.q').new(c);c.combat=require('tf.combat').new(c)
    c.effects=require('tf.effects').new(c);c.farm=require('tf.farm').new(c);c.level=require('tf.level').new(c)
    c.log=require('tf.log').new(c)
    c.telemetry=require('tf.telemetry').new(c)
    c.state:refresh();return c
end
function App:record(event,fields)
    if not self.config:get('diagnostics')then return end
    self.recordIndex=self.recordIndex%256+1
    self.records[self.recordIndex]={game=Game.Timer(),ms=self.actions and self.actions.client:Now(),event=event,data=fields,
        build=self.build,profile=self.profile.id}
    if self.log then self.log:write(event,fields)end
end
function App:blocked()
    return not self.config:get('enabled') or self.hero.dead or Game.IsChatOpen() or not Game.IsOnTop()
end
function App:tick()
    if not self.active then return end
    self.state:refresh();self.actions:tick();self.combat:pollAttack();self.plan=nil
    if self:blocked()then
        self.cards:clear()
        for _,owner in ipairs({'combat_attack','farm_attack','interrupt','peel','q','level','item','summoner','classic_r','planned_active'})do self.actions:cancel(owner,'context_unavailable')end
        self.actions.client:SetBlocked('gate','attack',false);self.actions.client:SetBlocked('gate','move',false)
        self.effects:claimsUpdate();return
    end
    if self.sdk.Evade and type(self.sdk.Evade.Evading)=='function'and self.sdk.Evade:Evading()then
        self.actions.client:SetBlocked('gate','attack',false);self.actions.client:SetBlocked('gate','move',false);return
    end
    local s=self.state
    if self.config:get('diagnostics') and Game.Timer()>=(self.nextSnapshot or 0)then
        self.nextSnapshot=Game.Timer()+1
        self:record('snapshot',{stage=s.stage,color=s.color,mode=s.mode,w=self.hero:GetSpellData(1).name,
            attackCastEnd=s.lastAttack,channel=s.channelKind,channelEnd=s.channelEnd,mana=self.hero.mana,
            health=self.hero.health,cardExpiry=s.cardExpiry,pending=next(self.actions.pending)~=nil})
    end
    self.actions.client:SetBlocked('gate','attack',s.channeling)
    self.actions.client:SetBlocked('gate','move',s.channeling)
    if self.wasGate and not s.channeling then
        self.level.teleports=self.level.teleports or {};table.insert(self.level.teleports,Game.Timer())
        if #self.level.teleports>16 then table.remove(self.level.teleports,1)end
        if self.config:get('teleportCards') and not self.cards.manual then self.cards:auto('gold','arrival')end
    end
    self.wasGate=s.channelKind=='gate'
    if self.wasGate and self.config:get('teleportCards') and s.stage=='selecting' and not self.cards.manual then
        self.cards:auto('gold','manual_gate')
    end
    self.cards:tick()
    if s.channeling then return end
    self.effects:tick()
    if s.mode=='FLEE'then self.combat:classicR()end
    local urgent=self.combat:interrupt() or self.combat:peel()
    if not urgent then
        if s.mode=='COMBO' or s.mode=='HARASS'then self.combat:tick(s.mode,s.modeID)
        elseif s.mode=='LASTHIT' or s.mode=='LANECLEAR' or s.mode=='JUNGLECLEAR'then
            local mode,id=s.mode,s.modeID
            if self.sdk.Orbwalker.Modes[self.sdk.ORBWALKER_MODE_LANECLEAR] and self.sdk.Orbwalker.Modes[self.sdk.ORBWALKER_MODE_JUNGLECLEAR] then
                local nearest,distance=nil,math.huge
                for _,m in ipairs(s.minions)do if U.target(m) and m.team~=self.hero.team then
                    local d=U.dist(self.hero,m);if d<distance then nearest=m;distance=d end
                end end
                if nearest and nearest.team==300 then mode='JUNGLECLEAR';id=self.sdk.ORBWALKER_MODE_JUNGLECLEAR end
            end
            self.farm:tick(mode,id)
            if s.mode=='LANECLEAR' and self.config:get('farmHarass')then self.combat:tick('HARASS',s.modeID)end
        elseif s.mode=='FLEE'then self.combat:flee()
        elseif self.config:get('autoHarass') and s.mode=='NONE'then self.combat:tick('HARASS',nil)end
    end
    self.level:tick()
end
function App:draw()
    if not self.active or not self.config:get('draw')then return end
    local p=self.hero.pos:To2D();local color=self.cards.manual and self.cards.manual.color or self.cards.desired
    Draw.Text('Card Marx '..self.profile.id..' | '..self.cards.phase..(color and ' / '..color or ''),16,p.x-80,p.y+50,Draw.Color(255,240,210,80))
    if self.plan and U.target(self.plan.target)then Draw.Circle(self.plan.target.pos,90,2,Draw.Color(220,240,210,80))end
end
function App:performance()
    if not self.config:get('diagnostics') or Game.Timer()<(self.nextPerformance or 0)then return end
    self.nextPerformance=Game.Timer()+2
    local profiler=self.sdk.Performance
    if not profiler or not profiler.enabled then return end
    local snapshot=profiler:Snapshot()
    for _,name in ipairs({'tick','tf_controller','health','damage_attack','cursor','input','shared_data',
        'inventory_prepare','mode_prepare','sdk_callbacks','tf_state','tf_flight','tf_actions','tf_combat',
        'tf_model','tf_q','tf_farm','tf_farm_log','tf_effects','tf_log_io','tf_cards','tf_interrupt','tf_peel','tf_level'})do
        local row=snapshot.subsystems[name]
        if row then self:record('performance',{scope=name,calls=row.calls,exclusiveTotal=row.total,
            exclusiveP95=row.p95,exclusiveMax=row.max,inclusiveTotal=row.inclusive.total,
            inclusiveP95=row.inclusive.p95,inclusiveMax=row.inclusive.max,over50=row.over50,
            resolution=snapshot.resolution})end
    end
    self:record('diagnostic_io',{records=self.log.records,flushes=self.log.flushes,pendingBytes=self.log.pendingBytes})
end
function App:install()
    local profiler=self.sdk.Performance
    if profiler and profiler.Wrap then
        for _,row in ipairs({{self.state,'refresh','tf_state'},{self.state,'flight','tf_flight'},
            {self.actions,'tick','tf_actions'},{self.combat,'tick','tf_combat'},{self.combat,'model','tf_model'},
            {self.q,'plan','tf_q'},{self.farm,'tick','tf_farm'},{self.farm,'diagnostics','tf_farm_log'},
            {self.effects,'tick','tf_effects'},{self.log,'flush','tf_log_io'},
            {self.cards,'tick','tf_cards'},{self.combat,'interrupt','tf_interrupt'},
            {self.combat,'peel','tf_peel'},{self.level,'tick','tf_level'}})do
            profiler:Wrap(row[1],row[2],row[3])
        end
    end
    self.tickFn=function()
        local ok,err=pcall(function()
            if self.sdk.Performance and self.sdk.Performance.enabled then
                return self.sdk.Performance:Call('tf_controller',function()self:tick()end)
            end
            return self:tick()
        end)
        if ok then
            local diagnosticsOK=pcall(function()self:performance();self.telemetry:tick();self.log:flush()end)
            if not diagnosticsOK then self.log.disabled=true end
        end
        if not ok then print('[CardMarx] stopped: '..tostring(err));self:Shutdown()end
    end
    self.drawFn=function()self.telemetry:draw();self:draw()end
    table.insert(self.sdk.OnUrgent,self.tickFn);table.insert(self.sdk.OnDraw,self.drawFn)
    self.log:write('loaded',{fingerprint=self.fingerprint,mechanics=P.revision,provider=self.sdk.OrbamaVersion})
    print('[CardMarx] '..self.build..' profile='..self.profile.id..' mechanics='..P.revision..' provider='..self.sdk.OrbamaVersion)
end
function App:Shutdown()
    if not self.active then return end
    self.active=false;U.remove(self.sdk.OnUrgent,self.tickFn);U.remove(self.sdk.OnDraw,self.drawFn)
    if self.actions and self.actions.client then self.actions:close()end
    if self.log then self.log:flush(true)end
    if self.actions and self.actions.client and next(self.actions.client.jobs) and self.sdk.OnMaintenance then
        local cleanup
        cleanup=function()
            self.actions.client:Collect()
            if not next(self.actions.client.jobs)then U.remove(self.sdk.OnMaintenance,cleanup)end
        end
        table.insert(self.sdk.OnMaintenance,cleanup)
    end
    if _G.OrbamaTwistedFate==self then _G.OrbamaTwistedFate=nil end
end
return App
