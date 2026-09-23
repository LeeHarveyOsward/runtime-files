local U=require('lho.util')
local C={}
local drawingModes={{'Combo','Combo','COMBO','fight'},{'Harass','Harass','HARASS','harass'},
    {'LaneClear','Lane clear','LANECLEAR','clear'},{'JungleClear','Jungle clear','JUNGLECLEAR','clear'},
    {'LastHit','Last hit','LASTHIT','gg_last'},{'Flee','Flee','FLEE','flee'},
    {'AutoJungle','Auto-jungle',nil,'farm'},{'Insec','Insec',nil,'insec'}}
local drawingGroups={drawQRange='Q',drawWRange='W',drawERange='E',drawRRange='R',
    drawWardRange='WardRange',drawHUD='Status',drawWard='Wardjump',drawInsec='Insec',damageBars='Damage'}
C.defaults={
    enabled=true,cursorKey=5,allyKey=6,wardKey=84,autoJungleKey=74,qAssistKey=71,smiteKey=78,secureKey=0,autoJungle=false,
    lastAbilities=true,lastQ=true,lastW=false,lastE=true,waveAbilities=true,waveQ=true,waveW=true,waveE=true,waveHarass=false,
    jungleAbilities=true,jungleQ=true,jungleQ2=true,jungleW=true,jungleE=true,jungleQ2MeleeOnly=true,jungleQ2RangeScale=2,
    autoClearAbilities=true,autoClearQ=true,autoClearQ2=true,autoClearW=true,autoClearE=true,
    clearKrugE=true,farmPreserveQ=true,
    waveSoften=true,waveHorizon=3,farmCameraKey=90,farmQTravel=true,farmQAdjust=false,farmQBlind=true,clearQTiming=true,
    laneEstimates=true,laneDamageMargin=10,csGoldPriority=true,
    farmFollowCamera=true,openingRoute=3,farmKite=true,farmKiteDistance=260,farmKiteLeash=350,farmPreferHome=true,farmHomeOnly=true,farmLocalEnemyStart=true,
    farmMinimap=true,farmRestoreCamera=true,farmSurvivalLevel=5,
    potions=true,potionJungle=true,potionAuto=true,potionFight=true,potionHP=85,
    itemCleave=true,itemTargeted=true,itemSlow=true,itemSpeed=true,itemCleanse=true,itemShield=true,
    expiryW=true,expiryE=true,recastReserve=50,
    autosmite=true,smiteCamps=true,smiteProjectionFallback=true,smitePreaim=true,smiteMargin=10,smiteEpicMargin=0,smiteOverride=0,
    wardAssist=true,assistRadius=120,reuseRadius=55,wardRange=600,wardTimeout=900,cancelOnly=false,
    wardApproach=true,wardWalkRange=0,wardJumpTimeout=2000,wardFastCursor=true,wardFollowCursor=true,
    wardEarlyW=true,wardEarlyDelay=20,insecLandingMargin=180,insecCloseWard=true,
    aimLock=2,insecFlash=true,insecPreviewKey=18,insecTimeout=5,comboQ=true,comboQ2=false,comboW=true,comboW2=true,comboE=true,comboE2=true,comboR=true,
    harassQ=true,harassQ2=false,harassW=false,harassW2=false,harassE=true,harassE2=true,harassR=false,
    qOnlySelected=false,comboConserveR=true,comboWardRetry=2500,
    insecQ=true,insecBridges=true,insecW=true,insecChains=true,insecWalk=120,insecLead=120,insecOrbwalk=true,insecFlashFallback=true,
    insecAngle=35,insecStandDistance=325,insecAutoLead=true,insecDashEstimate=250,
    insecMouseTarget=true,insecMouseRadius=200,insecTrackAlly=true,drawInsecTolerance=false,
    insecPreferStructures=true,insecBasePlatform=true,
    multi=true,multiHits=3,collateralKills=true,autoMultiR=true,combatEstimates=true,combatDamageMargin=25,comboWard=true,items=true,hitchance=1,q2Safety=true,
    comboPassive=true,comboBurst=true,comboKickFollow=true,comboKickHP=65,comboIsolate=true,comboWardPreserveQ=false,
    comboSmartChase=true,comboWalkWait=1000,comboWardGain=550,comboChaseE2=true,
    idleDefense=true,reserveW=true,shieldHP=35,allyShieldHP=25,killQ=true,killE=true,killQ2=false,killR=true,
    clearEnergy=15,recallHP=25,level=true,invade=false,epicAssist=false,farmBuffRespawn=300,farmSmallRespawn=135,farmWightRespawn=50,
    draw=true,diagnostics=false,fileLogging=false,playtestLogging=false,combatLogging=false,performanceLogging=false,terrainVerified=false,mechanicsVerified=false,rangeVerified=false,
    smiteVerified=false,monsterQCap=0,farmQRespawn=true,
    defensiveR=true,
    comboIgnite=false,igniteExecute=true,
    damageBars=true,damageSafe=true,damageMax=true,damageText=true,damageSelected=false,
    damageQ=true,damageE=true,damageR=true,damageItems=true,damageSummoners=true,damageAutos=2,
    damageWidth=100,damageX=25,damageY=-13,damageHeight=4,damageHorizon=3,drawHUD=true,drawWard=true,drawInsec=true,
    drawQRange=2,drawWRange=false,drawERange=false,drawRRange=false,drawWardRange=false}
local sections={
    {'Keys','Extra controls (standard modes use Orbama)',{{'cursorKey','Cursor insec (Mouse4)',5},{'allyKey','Ally insec (Mouse5)',6},
        {'insecPreviewKey','Hold preview modifier; release to confirm (Alt)',18},
        {'wardKey','Ward preview / release',84},{'autoJungleKey','Auto-jungle toggle',74},{'qAssistKey','Q1-only assist',71},
        {'smiteKey','Autosmite toggle',78},{'secureKey','Optional objective secure (unbound)',0}}},
    {'Ward','Wardjump',{{'wardAssist','Wall assistance'},{'assistRadius','Assistance radius',nil,30,240},
        {'wardApproach','Walk into range after releasing T'},{'wardWalkRange','Approach travel limit (0 = unlimited)',nil,0,20000},
        {'wardFastCursor','Chain confirmed ward to W through owned GG cursor'},
        {'wardFollowCursor','After T wardjump: move once toward latest cursor'},
        {'wardEarlyW','Test: one early W before ward observation (all wardjumps)'},
        {'wardEarlyDelay','Early W test delay (ms)',nil,5,100},
        {'reuseRadius','Existing target tolerance',nil,10,100},{'wardRange','Maximum placement range (native margin also applies)',nil,100,700},
        {'wardTimeout','Ward observation timeout (ms)',nil,300,1800},
        {'wardJumpTimeout','Observed ward: W retry window (ms)',nil,500,4000},{'cancelOnly','Cancel without movement (requires input adapter)'}}},
    {'Combat','Combo',{{'comboQ','Use Q1'},{'comboQ2','Use Q2 automatically (default: manual)'},
        {'comboW','Use W1'},{'comboW2','Use W2'},{'comboE','Use E1'},{'comboE2','Use E2'},{'comboR','Use R'},
        {'comboConserveR','Save R when another timely finish is available'},
        {'qOnlySelected','Champion Q1: only the selected enemy'},
        {'comboWard','Chase wardjump only for a clear advantage'},{'comboWardRetry','Minimum time between Combo ward requests (ms)',nil,1000,5000},
        {'multi','Kick champions into other champions'},{'multiHits','Total R hits: 2 = target + 1, 3 = target + 2',nil,2,5},
        {'collateralKills','R: kill distant enemies with a kicked champion'},
        {'autoMultiR','Idle: automatic multi-kick / collateral execute (no reposition)'},
        {'combatEstimates','Allow conservative unverified champion damage estimates'},
        {'combatDamageMargin','Champion execute HP margin',nil,0,150},
        {'comboPassive','Combo: weave available passive attacks'},
        {'comboBurst','Combo: prioritize timely lethal actions over passive weaving'},
        {'comboKickFollow','Combo: Q-marked duel R followed by Q2'},
        {'comboIsolate','Combo: kick marked target away from its nearby team'},
        {'comboWalkWait','Chase: walk when reachable within (ms)',nil,200,2000},
        {'comboWardGain','Chase: minimum time saved by wardjump (ms)',nil,100,1500},
        {'comboChaseE2','Chase: use available marked E2 slow before ward entry'},
        {'insecFlash','Insec: allow Flash'},
        {'insecLandingMargin','Insec: minimum final ward landing distance from target',nil,80,250},
        {'insecCloseWard','Insec: allow closer aligned ward when needed (minimum 80)'},
        {'insecFlashFallback','Without Alt: Flash only if no ward is ready'},
        {'insecTimeout','Insec timeout (seconds)',nil,2,10},
        {'insecQ','Insec: Q1 / confirmed Q2 entry'},{'insecBridges','Insec: other champions / minions / camps as Q bridges'},
        {'insecMouseTarget','Insec: mouse target fallback when GG has no selection'},
        {'insecMouseRadius','Insec: mouse selection radius',nil,75,350},
        {'insecTrackAlly','Ally insec: follow the chosen recipient before commitment'},
        {'insecPreferStructures','Ally insec: prioritize a kick into friendly turret range'},
        {'insecBasePlatform','Ally insec: include known base platform'},
        {'drawInsecTolerance','Insec drawing: show angle tolerance rays'},
        {'insecW','Insec: existing W targets / ward placement'},{'insecChains','Insec: combine Q, W and Flash'},
        {'insecWalk','Insec: maximum final walking correction',nil,0,180},
        {'insecOrbwalk','Insec: orbwalk to cursor before engage'},
        {'insecAngle','Insec: satisfactory angle (+/- degrees)',nil,5,60},
        {'insecStandDistance','Insec: preferred distance behind target',nil,150,350},
        {'insecAutoLead','Insec: predict ward handoff and dash duration'},
        {'insecDashEstimate','Insec: initial dash duration estimate (ms)',nil,100,500},
        {'insecLead','Insec: moving target placement prediction (ms)',nil,0,300},
        {'q2Safety','Avoid turret Q2 in ordinary combo'},{'items','Item actives'},{'hitchance','Q hitchance',nil,1,3},
        {'comboIgnite','Use equipped Ignite in fight'},{'igniteExecute','Ignite only when lethal'}}},
    {'Harass','Harass (Orbama bind)',{{'harassQ','Use Q1'},{'harassQ2','Use Q2 (dash)'},{'harassW','Use W1'},
        {'harassW2','Use W2'},{'harassE','Use E1'},{'harassE2','Use E2'},{'harassR','Use R'}}},
    {'Idle','Background assists',{{'idleDefense','Automatic defensive W'},
        {'reserveW','Reserve combat W for mobility / lethal shield (jungle W allowed)'},
        {'expiryW','Use W2 shortly before recast expires (also manual W1)'},{'expiryE','Use E2 before expiry with a marked target'},
        {'recastReserve','Energy to reserve after expiry assist',nil,0,100},{'shieldHP','Self shield HP %',nil,10,80},
        {'allyShieldHP','Ally shield HP %',nil,10,60},{'killQ','Q1 killsteal'},{'killE','E killsteal'},
        {'killQ2','Q2 killsteal (dash)'},{'killR','R killsteal'}}},
    {'Activator','Items / potions',{{'potions','Health potions / refillable sustain'},
        {'potionJungle','Potions in GG jungle clear'},{'potionAuto','Potions in auto-jungle'},{'potionFight','Potions in champion combat'},
        {'potionHP','Potion use below HP % (also checks missing health)',nil,30,95},
        {'itemCleave','Tiamat / Hydra / Stridebreaker actives'},{'itemTargeted','Champion-targeted damage actives'},
        {'itemSlow','Randuin slow'},{'itemSpeed','Movement / attack-speed actives'},
        {'itemCleanse','QSS / Mercurial cleanse'},{'itemShield','Locket shield'}}},
    {'Smite','Smite',{{'autosmite','Autosmite ON / OFF'},{'smiteCamps','Execute ordinary camps in every mode'},
        {'smiteProjectionFallback','Allow isolated target aim when host hover is empty'},
        {'smitePreaim','Prepare exact boss hover shortly before lethal HP'},
        {'smiteMargin','Ordinary camp health margin',nil,0,100},{'smiteEpicMargin','Epic objective health margin',nil,0,100},
        {'smiteOverride','Exact damage override (0 = live / profile)',nil,0,2000}}},
    {'Farm','Farming / recovery',{{'autoJungle','Auto-jungle ON / OFF'},{'clearEnergy','Minimum energy %',nil,0,80},{'recallHP','Recall HP %',nil,10,60},
        {'farmFollowCamera','Auto-jungle: follow Lee with camera'},{'farmCameraKey','Native camera lock key (Z)'},
        {'farmRestoreCamera','Restore camera if this plugin locked it'},{'farmMinimap','Use minimap for offscreen auto-jungle travel'},
        {'farmQAdjust','Allow small Q aim detours (default OFF)'},
        {'farmSurvivalLevel','Prioritize damage mitigation through level',nil,1,10},
        {'farmLocalEnemyStart','Finish nearby enemy camp when starting'}, {'farmHomeOnly','Route only camps on our side (excludes river)'},{'farmPreferHome','Prefer available camps on our side'},{'invade','Route into enemy jungle from outside'},
        {'defensiveR','Use R to disengage, then pause'},
        {'farmBuffRespawn','Buff respawn estimate (seconds)',nil,30,600},
        {'farmSmallRespawn','Small-camp respawn estimate (seconds)',nil,20,300},
        {'farmWightRespawn','Wight respawn estimate (seconds)',nil,20,300},
        {'level','Auto level skills'}}},
    {'Wave','GG waveclear abilities',{
        {'csGoldPriority','Both lane modes: prioritize gold when CS must be lost'},
        {'waveAbilities','Abilities ON / OFF'},{'waveQ','Use Q1 for otherwise-missed last hits'},{'waveW','Use W (passive / sustain)'},
        {'waveE','Use E1 (rescue / safe wave damage)'},{'waveHarass','Harass during waveclear (last hits first)'},
        {'waveSoften','Use E on healthy minions with a safe CS forecast'},{'waveHorizon','CS forecast horizon (seconds)',nil,2,5},
        {'laneEstimates','Lane Q/E: allow profile estimates before verification'},
        {'laneDamageMargin','Lane spell damage safety margin %',nil,0,40}}},
    {'LastHit','GG last-hit abilities',{{'lastAbilities','Abilities ON / OFF'},{'lastQ','Use Q1 only to rescue CS'},
        {'lastW','Use W passive only to rescue CS'},{'lastE','Use E1 only to rescue CS'}}},
    {'Jungle','GG jungle clear abilities',{{'jungleAbilities','Abilities ON / OFF'},{'jungleQ','Use Q1'},
        {'clearQTiming','Estimate AA / Q2 finish time (both jungle modes)'},
        {'jungleQ2','Use Q2 recast'},{'jungleQ2MeleeOnly','Limit clearing Q2 range (travel separate)'},
        {'jungleQ2RangeScale','Clearing Q2 range: attack range multiplier',nil,1,4},
        {'jungleW','Use W1 / W2'},{'jungleE','Use E1 / E2'},
        {'clearKrugE','Normal: reserve E for imminent Krug splits (both modes)'}}},
    {'AutoClear','Auto-jungle abilities',{{'autoClearAbilities','Abilities ON / OFF'},{'farmQTravel','Use confirmed Q1 / Q2 to reach camps'},
        {'farmKite','Kite melee camp targets between attacks'},{'farmKiteDistance','Maximum kite travel (return time reserved)',nil,30,400},
        {'farmKiteLeash','Conservative monster pursuit radius',nil,150,450},
        {'farmQBlind','Probe unseen known camps with Q; skip unconfirmed camp'},{'autoClearQ','Use Q1'},
        {'farmQRespawn','Allow one fog probe after the estimated respawn time'},
        {'autoClearQ2','Use Q2 recast'},{'autoClearW','Use W1 / W2'},{'autoClearE','Use E1 / E2'},
        {'farmPreserveQ','Preserve Q1 near camp end for a useful next engage'}}},
    {'Drawings','Drawings',{{'drawHUD','Status panel'},{'drawWard','Wardjump preview'},{'drawInsec','Insec preview'},
        {'drawQRange','Q range'},{'drawWRange','W range'},{'drawERange','E range'},{'drawRRange','R range'},
        {'drawWardRange','Ward placement range'},
        {'damageBars','Enemy health-bar damage'},{'damageSafe','Conservative estimate'},{'damageMax','Maximum-resource estimate'},
        {'damageText','Damage numbers / incomplete status'},{'damageSelected','Selected target only'},
        {'damageQ','Include Q'},{'damageE','Include E'},{'damageR','Include R in maximum'},
        {'damageItems','Include modeled item actives'},{'damageSummoners','Include damaging summoners'},
        {'damageAutos','Maximum planned attacks',nil,0,5},{'damageHorizon','Estimate window (seconds)',nil,1,5},
        {'damageWidth','Health-bar width',nil,50,200},{'damageX','Health-bar X offset',nil,-200,200},
        {'damageY','Health-bar Y offset',nil,-200,200},{'damageHeight','Damage strip height',nil,1,10}}},
    {'Validation','Calibration / verification',{{'terrainVerified','Terrain provider verified for this mode'},
        {'mechanicsVerified','Champion damage / buffs verified'}, {'rangeVerified','Ward range verified'},
        {'monsterQCap','Measured conservative Q monster cap (0 = no Q damage budget)',nil,0,3000},
        {'smiteVerified','Smite profile measured (diagnostic status)'},{'diagnostics','Record diagnostic events'},
        {'fileLogging','Persist errors / ward / input diagnostics'},{'combatLogging','Full-match combat / sightings / outcome recording'},
        {'performanceLogging','Measure LHO component times (5-second summaries)'},
        {'playtestLogging','Temporary detailed jungle capture (20 minutes)'}}},
}
function C.new(profile)
    local self={values={},nodes={}}
    local revisedDefaults={comboIgnite='comboIgniteOptInR23',killQ2='killQ2OptInR52',killR='killRR23',comboWardPreserveQ='comboWardPreserveQOptInR25'}
    for k,v in pairs(C.defaults) do self.values[k]=v end
    if profile.id=='classic' then self.values.farmSmallRespawn=75 end
    -- Boolean false must not fall through to the initial default.
    function self:get(k)
        local node=self.nodes[k];if not node then return self.values[k] end
        local scope=U.buffScopeKey()
        if not scope then return node:Value() end
        if self.readScope~=scope then self.readScope=scope;self.readCache={} end
        local cached=self.readCache[k]
        if cached~=nil then return cached end
        local value=node:Value();self.readCache[k]=value;return value
    end
    function self:set(k,v)
        self.writeSerial=self.writeSerial or {};self.writeSerial[k]=(self.writeSerial[k] or 0)+1
        self.values[k]=v;if self.nodes[k] then self.nodes[k]:Value(v) end
        if self.readCache then self.readCache[k]=nil end
        self.capture=self:get('fileLogging') or self:get('diagnostics')
    end
    function self:key(k)
        -- New menu IDs avoid inheriting the old duplicated V/C bindings.
        if k=='farmKey' then k='autoJungleKey' elseif k=='qKey' then k='qAssistKey' end
        local n=self.nodes[k];return n and n:Key() or self.values[k]
    end
    function self:visible(key,sdk,mode)
        local enabled=self:get(key)
        if key=='drawQRange' then enabled=enabled~=1 end
        if not enabled then return false end
        local options=self.drawingOptions and self.drawingOptions[key]
        if not options then
            if key~='drawQRange' or self:get(key)==3 then return true end
            local active=sdk and sdk.Orbwalker and sdk.Orbwalker.Modes
            local index=sdk and sdk.ORBWALKER_MODE_HARASS
            if active and index then return active[index]==true end
            return mode=='harass'
        end
        if options.Always:Value() then return true end
        local active=sdk and sdk.Orbwalker and sdk.Orbwalker.Modes
        for _,entry in ipairs(drawingModes) do
            if options[entry[1]]:Value() then
                local index=entry[3] and sdk and sdk['ORBWALKER_MODE_'..entry[3]]
                local held
                if active and index then held=active[index]==true
                else held=mode==entry[4] end
                if entry[1]=='Insec' then held=mode=='cursor' or mode=='ally' end
                if held then return true end
            end
        end
        return false
    end
    -- Original-GG does not load Orbama's optional local recording profile.
    -- Read it independently without loading/replacing the provider or publishing
    -- globals. An explicitly supplied profile (including enabled=false) wins.
    local test=_G.OrbamaTestConfig
    if test==nil then
        local ok,value=pcall(require,'OrbamaTestConfig')
        if ok and type(value)=='table' then test=value end
    end
    if type(test)~='table' then test={} end
    if test.enabled then
        self.values.fileLogging=true;self.values.playtestLogging=true;self.values.combatLogging=true
        self.values.performanceLogging=test.profile==true
        for k,v in pairs(test.lho or {}) do if self.values[k]~=nil and type(v)==type(self.values[k]) then self.values[k]=v end end
    end
    self.capture=self.values.fileLogging or self.values.diagnostics
    self.menuEntries={}
    local smiteEquipped=false
    if myHero and myHero.GetSpellData then for slot=4,5 do
        local spell=myHero:GetSpellData(slot)
        if spell and (spell.name or ''):lower():find('smite',1,true) then smiteEquipped=true end
    end end
    local developer={wardEarlyW=true,wardEarlyDelay=true,wardFastCursor=true,wardRange=true,wardTimeout=true,
        wardJumpTimeout=true,insecDashEstimate=true,insecLead=true,smiteOverride=true,
        cancelOnly=true,smiteProjectionFallback=true,smitePreaim=true,
        insecAutoLead=true,insecLead=true,insecDashEstimate=true,farmRestoreCamera=true,
        farmBuffRespawn=true,farmSmallRespawn=true,farmWightRespawn=true}
    local function destination(section,key)
        if section=='Validation' or developer[key] then return nil end
        if key:match('^insec') and key~='insecPreviewKey' then return 'Insec' end
        if key=='drawInsecTolerance' then return 'Drawings' end
        if section=='Keys' then return 'Controls' end
        if section=='Combat' then return 'Combat' end
        if section=='Idle' then return 'Assists' end
        if section=='Harass' then return 'Harass' end
        if section=='Wave' or section=='LastHit' or section=='Jungle' then return section end
        if section=='Ward' then return 'Wardjump' end
        if section=='Activator' or section=='Smite' then return 'SmiteItems' end
        if section=='Drawings' then return 'Drawings' end
        return 'Farming'
    end
    if MenuElement then
        self.menu=MenuElement({type=MENU,id='LeeHarveyOsward_'..profile.id,name='Lee Harvey Osward'})
        self.menu:MenuElement({id='enabled',name='Enabled',value=true});self.nodes.enabled=self.menu.enabled
        local groups={{'Controls','Controls'},{'Combat','Combo'},{'Harass','Harass'},
            {'Assists','Background assists'},{'Insec','Insec'},{'Wave','Waveclear'},
            {'LastHit','Last hit'},{'Jungle','Jungle clear'},{'Wardjump','Wardjump'},
            {'Farming','Auto-jungle'},{'SmiteItems','Smite and items'},{'Drawings','Drawings'}}
        local icons={Controls='/Gamsteron_Loader.png',Combat='/Gamsteron_TargetSelector.png',Harass='/LeeSinQ.png',
            Assists='/Gamsteron_Spell_SummonerBarrier.png',Insec='/Gamsteron_Spell_SummonerFlash.png',
            Wave='/Gamsteron_Minion.png',LastHit='/Gold.png',Jungle='/Gamsteron_Spell_SummonerSmite.png',
            Wardjump='/3340.png',Farming='/Gamsteron_Orbwalker.png',SmiteItems='/2003.png',Drawings='/Gamsteron_Drawings.png'}
        local usedIcons={}
        for _,group in ipairs(groups) do
            local resolver=_G.SDK and SDK.MenuMigration
            local icon=resolver and resolver:Icon(icons[group[1]])
            if icon and usedIcons[icon] then icon=nil end
            if icon then usedIcons[icon]=true end
            local args={id=group[1],name=group[2],type=MENU,leftIcon=icon}
            local ok=pcall(self.menu.MenuElement,self.menu,args)
            if not ok and not self.menu[group[1]] then args.leftIcon=nil;self.menu:MenuElement(args) end
        end
        local migration=_G.SDK and SDK.MenuMigration
        self.drawingOptions={}
        local function drawingBranch(key)
            if drawingGroups[key] then return drawingGroups[key] end
            if key:match('^damage') then return 'Damage' end
            if key=='drawInsecTolerance' then return 'Insec' end
        end
        local function add(group,args,oldPath,advanced)
            local parent=self.menu[group];local path=group
            local branch=group=='Drawings' and drawingBranch(args.id)
            if branch then
                local names={Damage='Damage estimates',Status='Status panel',WardRange='Ward range',Wardjump='Wardjump preview',Insec='Insec preview'}
                if not parent[branch] then
                    local icon=branch:match('^[QWER]$') and migration and migration:Icon('/LeeSin'..branch..'.png')
                    parent:MenuElement({id=branch,name=names[branch] or branch..' range',type=MENU,leftIcon=icon})
                end
                parent=parent[branch];path=path..'.'..branch
            end
            if advanced then
                if not parent.Advanced then parent:MenuElement({id='Advanced',name='Advanced',type=MENU}) end
                parent=parent.Advanced;path=path..'.Advanced'
            end
            if migration then
                migration:Apply(args,'LeeHarveyOsward_'..profile.id,oldPath,path..'.'..args.id)
                if args.id:match('^draw[QWER]Range') or args.id=='drawWardRange' then
                    migration:Apply(args,'LeeHarveyOsward_'..profile.id,'Drawings.Ranges.'..args.id,path..'.'..args.id)
                end
                if advanced then migration:Apply(args,'LeeHarveyOsward_'..profile.id,group..'.Advanced.'..args.id,path..'.'..args.id) end
                local previous=group=='Assists' and 'Combat.Advanced'
                    or (group=='Wave' or group=='LastHit' or group=='Jungle') and ('Farming'..(advanced and '.Advanced' or ''))
                if previous then migration:Apply(args,'LeeHarveyOsward_'..profile.id,previous..'.'..args.id,path..'.'..args.id) end
            end
            if drawingGroups[args.id] then
                local key=args.id;local legacy=args.value
                args.name='Enabled';args.drop=nil
                if key=='drawQRange' then args.value=legacy~=1 end
                if migration then migration:Apply(args,'LeeHarveyOsward_'..profile.id,path..'.'..key,path..'.'..key) end
                parent:MenuElement(args);local enabled=parent[args.id]
                local options={};self.drawingOptions[key]=options
                local function visibility(id,label,value)
                    local option={id=id,name=label,value=value}
                    if migration then migration:Apply(option,'LeeHarveyOsward_'..profile.id,path..'.'..id,path..'.'..id) end
                    parent:MenuElement(option);options[id]=parent[id]
                end
                visibility('Always','Always',key~='drawQRange' or legacy==3)
                for _,entry in ipairs(drawingModes) do visibility(entry[1],entry[2],key=='drawQRange' and legacy==2 and entry[1]=='Harass') end
                if key=='drawQRange' then
                    return {Value=function(_,value)
                        if value~=nil then
                            enabled:Value(value~=1);options.Always:Value(value==3)
                            for _,entry in ipairs(drawingModes) do options[entry[1]]:Value(value==2 and entry[1]=='Harass') end
                        end
                        return enabled:Value() and (options.Always:Value() and 3 or 2) or 1
                    end}
                end
                return enabled
            end
            parent:MenuElement(args);return parent[args.id]
        end
        local labels={cursorKey='Cursor insec',allyKey='Ally insec',insecPreviewKey='Preview modifier',
            wardApproach='Approach after release',wardFollowCursor='Move after jump',insecFlashFallback='Flash fallback',
            farmCameraKey='Camera lock key',combatEstimates='Conservative damage estimates',
            laneEstimates='Conservative lane damage',insecMouseTarget='Mouse target fallback'}
        for _,section in ipairs(sections) do
            for _,row in ipairs(section[3]) do
                local key=row[1];local group=destination(section[1],key)
                if not group and section[1]~='Validation' and migration then
                    local saved={id=key,value=self.values[key]}
                    migration:Apply(saved,'LeeHarveyOsward_'..profile.id,section[1]..'.'..key,section[1]..'.Advanced.'..key)
                    local previous=key:match('^insec') and 'Insec' or section[1]=='Ward' and 'Wardjump'
                        or section[1]=='Smite' and 'SmiteItems' or section[1]=='Farm' and 'Farming'
                    if previous then migration:Apply(saved,'LeeHarveyOsward_'..profile.id,previous..'.'..key,previous..'.Advanced.'..key) end
                    self.values[key]=saved.value
                end
                local relevant=not (key=='farmWightRespawn' and profile.id~='classic'
                    or key=='clearKrugE' and profile.id~='normal')
                if (section[1]=='Smite' or key=='smiteKey') and not smiteEquipped then relevant=false end
                self.menuEntries[#self.menuEntries+1]={key=key,old=section[1],group=group,category=not group and 'development' or row[4] and 'tuning' or 'gameplay',relevant=relevant}
                if group and relevant then
                    local label=labels[key] or row[2]:gsub('GG ',''):gsub(' %(Mouse%d%)',''):gsub('Test: ','')
                    local args={id=revisedDefaults[key] or key,name=label,value=self.values[key]}
                    if key=='hitchance' then args.id='qAccuracyR54';args.name='Q prediction confidence' end
                    if key=='smiteCamps' then args.id='smiteExecuteCamps' end
                    if key=='farmKiteDistance' then args.id='farmKiteTravelR19' end
                    if section[1]=='Keys' or key=='farmCameraKey' then args.key=self.values[key];args.value=nil
                    elseif key=='hitchance' then args.drop={'Normal','High','Immobile only'}
                    elseif key=='drawQRange' then args.drop={'Off','During harass','Always'}
                    elseif row[4] then args.min=row[4];args.max=row[5];args.step=1 end
                    local advanced=group~='Controls' and row[4]~=nil
                    self.nodes[key]=add(group,args,section[1]..'.'..args.id,advanced)
                end
            end
        end
        self.nodes.aimLock=add('Insec',{id='aimLock',name='Aim lock',value=self.values.aimLock,drop={'On press','On commitment','Until kick'}},'Combat.aimLock')
        self.nodes.openingRoute=add('Farming',{id='openingRouteR15',name='Opening route',value=self.values.openingRoute,
            drop={'Adaptive','Red start','Blue start'}},'Farm.openingRouteR15')
        self.menu:MenuElement({id='draw',name='Drawings enabled',value=self.values.draw});self.nodes.draw=self.menu.draw
        -- Aliases preserve existing plugin button insertion without duplicate menu nodes.
        self.menu.Farm=self.menu.Farming;self.menu.Ward=self.menu.Wardjump;self.menu.Keys=self.menu.Controls
        self.menu.Smite=self.menu.SmiteItems
    end
    self:set('autoJungle',false) -- Loading/reloading never starts an autonomous route.
    return self
end
return C
