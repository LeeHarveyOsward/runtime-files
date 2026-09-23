-- Temporary local playtest capture. Bundled into the installation file; no
-- in-game dependency on the source tree or a Python process.
local U=require('lho.util')
local D={filename='LeeHarveyOsward-playtest.log',duration=10800}
function D.tick(c)
    if not c.config:get('playtestLogging') then
        c.playtestStarted=nil;c.playtestNext=nil;c.playtestDetailNext=nil;c.playtestConfig=nil
        c.playtestState='disabled';return
    end
    local now=c:now()
    if not c.playtestStarted then
        c.playtestStarted=now;c.playtestState='running'
        c:log('playtest_started',{duration=D.duration,interval=.25,detailInterval=1})
    end
    if now-c.playtestStarted>=D.duration then
        if c.playtestState~='finished' then c:log('playtest_finished',{duration=now-c.playtestStarted});c.playtestState='finished' end
        return
    end
    if now<(c.playtestNext or 0) then return end
    c.playtestNext=now+.25
    local mapSample=now>=(c.playtestMapNext or 0)
    if mapSample then c.playtestMapNext=now+1 end
    local function buffs(unit)
        local rows={}
        for i=0,math.min(32,unit.buffCount or 0) do
            local b=unit.GetBuff and unit:GetBuff(i)
            if b and b.name and b.name~='' then rows[#rows+1]={name=b.name,count=b.count,stacks=b.stacks,
                expireTime=b.expireTime,endTime=b.endTime,source=b.sourcenID,sourceID=b.sourceID} end
        end
        return rows
    end
    local ok,data=pcall(function()
        local q=c:spell(0);local mobs={};local camps={};local nativeCamps={}
        for _,m in ipairs(c.minions or {}) do
            if m.team==300 and U.dist(myHero.pos,m.pos)<1500 and #mobs<16 then
                mobs[#mobs+1]={id=U.id(m),name=m.charName,pos=U.copy(m.pos),hp=m.health,maxHP=m.maxHealth,
                    visible=m.visible,valid=m.valid,dead=m.dead,targetable=m.isTargetable,buffCount=m.buffCount,
                    buffs=buffs(m),marked=c:mark(m)~=nil,attackRange=c:attackRange(m),q2ClearRange=c:jungleQ2Range(m),
                    radius=m.boundingRadius,moving=m.pathing and m.pathing.hasMovePath}
            end
        end
        if mapSample then for _,camp in pairs(c.farm.known) do
            local members={};for _,m in ipairs(camp.members or {}) do members[#members+1]=U.id(m) end
            camps[#camps+1]={id=camp.id,name=camp.category,team=camp.team,pos=U.copy(camp.pos),nativeUp=camp.nativeUp,
                state=camp.availability,expectedAt=camp.expectedAt,killedAt=camp.killedAt,waiting=camp.awaitingRespawn,
                walkPos=U.copy(camp.walkPos),members=members,mapPos=U.copy(camp.mapPos)}
        end
        for _,o in ipairs(c.camps or {}) do
            nativeCamps[#nativeCamps+1]={id=U.id(o),name=o.name,pos=U.copy(o.pos),posMM=U.copy(o.posMM),up=o.isCampUp}
        end end
        local active=myHero.activeSpell;local path=myHero.pathing;local pending=c.actions.pending[0]
        local hover={available=type(Game.GetUnderMouseObject)=='function'}
        if hover.available then
            local read,value=pcall(Game.GetUnderMouseObject);hover.ok=read;hover.returnType=type(value);hover.returnedNil=read and value==nil
            if read and (type(value)=='table' or type(value)=='userdata') then hover.id=U.id(value);hover.handle=value.handle;hover.name=value.charName end
        end
        if c.sdk.Orbwalker.GetControlState and now>=(c.playtestControlsAt or 0) then
            c.playtestControlsAt=now+1;c.playtestControls=c.sdk.Orbwalker:GetControlState()
        end
        return {build=require('lho.profiles').build,profile=c.profile.id,mapID=Game.mapID,mode=c.mode,status=c.status,
            hero={id=U.id(myHero),handle=myHero.handle,pos=U.copy(myHero.pos),energy=myHero.mana,buffs=buffs(myHero),
                hp=myHero.health,maxHP=myHero.maxHealth,gold=myHero.gold,level=myHero.levelData and myHero.levelData.lvl,
                passive=c:passive()},
            weaving={remaining=c.clear.passiveLeft,untilTime=c.clear.passiveUntil,castAt=c.clear.passiveCastAt,
                finishedAttack=c.clear.finishedAttack,lastAttackAt=c.lastAttackFinished,
                nativeCastEnd=c.sdk.Attack and c.sdk.Attack.CastEndTime,qTiming=c.clear.qTiming},
            q={name=q.name,stage=c:stage(0),rank=q.level,cd=q.currentCd,cost=q.mana,toggle=q.toggleState,
                nativeState=Game.CanUseSpell(0),pending=pending and pending.status,decision=c.spells.q2Decision,
                q1Decision=c.spells.q1Decision,
                outcome=c.q2Outcome and c.q2Outcome.text},
            smite={enabled=c.config:get('autosmite'),camps=c.config:get('smiteCamps'),
                decision=c.smite.decision,damage=c.smite:damage(),ready=c.smite:ready(),slot=c.smite:resolve()},
            activeSpell=active and {name=active.name,valid=active.valid,startTime=active.startTime,target=active.target,
                castEndTime=active.castEndTime,isAutoAttack=active.isAutoAttack,isStopped=active.isStopped},
            path=path and {moving=path.hasMovePath,dashing=path.isDashing,endPos=U.copy(path.endPos)},
            hover=hover,
            input={cursorStep=c.sdk.Cursor.Step,chat=Game.IsChatOpen and Game.IsChatOpen(),
                chatEffective=c:chatOpen(),chatLatched=c.sdk.Input and c.sdk.Input.ChatLatched==true or false,
                 suspendedKeys=c.input.suspended,downKeys=c.input.down,preAttack=c.lastPreAttack,orbwalker=c.playtestControls,orbwalkerAt=c.playtestControlsAt and c.playtestControlsAt-1,
                dispatcher=c.sdk.Input and c.sdk.Input.GetState and c.sdk.Input:GetState(),
                focused=Game.IsOnTop and Game.IsOnTop(),autoAttacking=c.sdk.Orbwalker:IsAutoAttacking()},
            config={jungleQ2=c.config:get('jungleQ2'),autoClearQ2=c.config:get('autoClearQ2'),
                meleeOnly=c.config:get('jungleQ2MeleeOnly'),enabled=c.config:get('enabled'),autoJungle=c.config:get('autoJungle')},
            recovery={state=c.farm.state,paused=c.input.farmPaused,spawn=U.copy(c.farm.spawnPos),
                recalling=c:recalling(),recallAt=c.farm.recallAt,endedAt=c.farm.recallEndedAt,lastStop=c.input.lastFarmStop},
            selectedCamp=c.farm.camp and c.farm.camp.id,entryDecision=c.farm.entryDecision,passiveDecision=c.clear.passiveDecision,
            campState=c.farm.camp and {state=c.farm.camp.availability,nativeUp=c.farm.camp.nativeUp,expectedAt=c.farm.camp.expectedAt},
            kite=c.farm.kiteStep,kiteDiagnostic=c.farm.kiteDiagnostic,attackTarget=U.id(c.attackTarget),
            moveTarget=U.copy(c.moveTarget),mobs=mobs,camps=mapSample and camps or nil,nativeCamps=mapSample and nativeCamps or nil,
            mapSampleAt=c.playtestMapNext-1,
            projection={resolution=Game.Resolution and U.copy(Game.Resolution()),
                cursor=Game.cursorPos and U.copy(Game.cursorPos()),mouseWorld=U.copy(mousePos),
                heroScreen=U.copy(U.vector(myHero.pos):To2D()),heroMinimap=U.copy(myHero.posMM)}}
    end)
    c:log(ok and 'playtest_tick' or 'playtest_error',ok and data or {reason=tostring(data)})
    c.playtestSampleSequence=c.traceSequence;c.playtestSampleAt=now
    if now<(c.playtestDetailNext or 0) then return end
    c.playtestDetailNext=now+1
    local detailOK,detail=pcall(function()
        local out=c:snapshot(true);out.pending={}
        for slot,event in pairs(c.actions.pending) do
            out.pending[slot]={request=event.id,status=event.status,owner=event.owner,stage=event.stage,
                at=event.at,deadline=event.deadline,name=event.name,cancelled=event.cancelled}
        end
        local config=out.config;out.config=nil;local changed={};local any=false
        for key,value in pairs(config) do
            if not c.playtestConfig or c.playtestConfig[key]~=value then changed[key]=value;any=true end
        end
        if any then c:log('playtest_config',{initial=c.playtestConfig==nil,values=changed}) end
        c.playtestConfig=config
        local orb=c.sdk.Orbwalker;local lease=c.cursorLease
        out.orbwalker={attackEnabled=orb.AttackEnabled,movementEnabled=orb.MovementEnabled,
            autoAttacking=orb:IsAutoAttacking(),cursorStep=c.sdk.Cursor and c.sdk.Cursor.Step,
            leaseOwner=lease and lease.owner}
        out.latency=c.latency;out.jitter=c.jitter
        out.route={command=c.actions.routeCommand,observation=c.actions.routeObservation,
            failure=c.routeFailureReason,cameraOwned=c.actions.cameraOwned~=nil}
        out.sampleSequence=c.playtestSampleSequence
        return out
    end)
    c:log(detailOK and 'playtest_detail' or 'playtest_error',detailOK and detail or {reason=tostring(detail)})
end
return D
