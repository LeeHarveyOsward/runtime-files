"""Pinned Lua-first ORBAMA build. Native/adaptive experiments remain separate."""
from pathlib import Path
import hashlib
import json
import re
import sys
sys.path.insert(0, str(Path(__file__).resolve().parent))
from build_gg_test import BASE_SHA, ROOT, SOURCE
from orbama_patches import correctness
from build_action_client import render as action_client

OUT = ROOT / 'Scripts/Orbama.lua'
BUILD = 'Orbama-lua-47'
MODULES = ROOT / 'Scripts/Common/Orbama'

def module(name):
    return '(function()\n' + (MODULES / (name + '.lua')).read_text(encoding='utf-8') + '\nend)()'

def replace(source, old, new, count=1):
    assert source.count(old) == count, (old[:100], source.count(old), count)
    return source.replace(old, new)

def render(transform=None):
    def module(name):
        body=(MODULES / (name + '.lua')).read_text(encoding='utf-8')
        if transform: body=transform(name,body)
        return '(function()\n'+body+'\nend)()'
    raw = SOURCE.read_bytes()
    assert hashlib.sha256(raw).hexdigest() == BASE_SHA, 'GG reference changed; review before repinning'
    source = raw.decode('utf-8').replace('\r\n', '\n')
    source = replace(source, 'local __name__ = "GGOrbwalker"', 'local __name__ = "Orbama"')
    source = replace(source, 'if _G.GGUpdate then\n\treturn\nend', '''if _G.SDK and _G.SDK.OrbamaVersion then return _G.SDK end
if _G.SDK or _G.GGUpdate then
    print('[Orbama] Another SDK is active; reload the complete script runtime.')
    return
end''')
    begin = source.index('_G.GGUpdate = {}')
    end = source.index('--#region headers', begin)
    source = source[:begin] + '_G.GGUpdate = ' + module('updater') + '''
Callback.Add("Tick", function() GGUpdate:OnTick() end)
-- Self-overwrite intentionally disabled.

''' + source[end:]
    source = replace(source, 'id = "GGOrbwalker", name = "GG Orbwalker"', 'id = "GGOrbwalker", name = "Orbama"')
    source = correctness(source)
    start=source.index('\tGetHeroPriority = function(self, name)',source.index('\nData = {'))
    end=source.index('\tGetTotalShield = function(self, obj)',start)
    source=source[:start]+source[end:]
    source=replace(source, '\nData.HardCCMoveTypes =', '\ndo\nlocal install='+module('heroes')+'\ninstall(Data,Obj_AI_Hero)\nend\n\nData.HardCCMoveTypes =')
    source=replace(source, '\t\tif Data.HEROES[name] then\n\t\t\treturn Data.HEROES[name][1]\n\t\tend\n\t\treturn 1\n\tend,', '\t\treturn Data:GetHeroPriority(name)\n\tend,')
    source=replace(source, 'local GetTickCount = GetTickCount', """local NativeTickCount=GetTickCount
local tickLast=NativeTickCount();local tickMonotonic=tickLast
local function GetTickCount()
    local value=NativeTickCount();local elapsed=value-tickLast
    if elapsed< -2147483648 then elapsed=elapsed+4294967296 end
    tickLast=value;tickMonotonic=tickMonotonic+math.max(0,elapsed);return tickMonotonic
end
if _G.OrbamaTestConfig==nil then
    local ok,config=pcall(require,'OrbamaTestConfig')
    _G.OrbamaTestConfig=ok and type(config)=='table' and config or {}
end""")
    source = replace(source, '\nlocal initialLatency = Game.Latency()', '''
local testConfig=_G.OrbamaTestConfig or {}
local function setting(value) return {Value=function(_,v)if v~=nil then value=v end;return value end} end
Menu.Main.OrbamaLua={LearnMoves=setting(testConfig.learnMoves==true),AutoMovementTiming=setting(true),
    GGCompatibility=setting(testConfig.ggCompatible~=false),DetailedInput=setting(testConfig.enabled==true),
    Profile=setting(testConfig.enabled==true and testConfig.profile==true),ReleaseGapTrial=setting(false)}

local initialLatency = Game.Latency()''')
    source = replace(source, 'Control.SetCursorPos(pos.x, pos.y)', 'self:SetPosition(pos, "action")')
    source = replace(source, '\tStepSetToCastPos = function(self)\n\t\tlocal pos', '\tProjectCastPosition = function(self)\n\t\tlocal pos')
    source = replace(source, '\t\tself.correctedCastPos = pos\n\t\tself:SetPosition(pos, "action")', '''\t\treturn pos
\tend,
\tStepSetToCastPos = function(self)
\t\tlocal pos = self:ProjectCastPosition()
\t\tself.correctedCastPos = pos
\t\tself:SetPosition(pos, "action")''')
    source = replace(source, 'Control.SetCursorPos(self.CursorPos.x, self.CursorPos.y)', 'self:SetPosition(self.CursorPos, "return")')
    start=source.index('\tStepPressKey = function(self)', source.index('\nCursor = {'))
    end=source.index('\n\tStepWaitForResponse =', start)
    source=source[:start]+'\tStepPressKey = function() return false end,\n'+source[end:]
    marker = "\n-- Track Crescendum's outgoing"
    integration = '''
do
    local timing = TIMING
    local create = INPUT
    Cursor = create(Cursor, {
        clock=GetTickCount, screen=Game.cursorPos,
        world=function()
            if type(Game.mousePos)=='function' then
                local ok,p=pcall(Game.mousePos)
                if ok and p and type(p.x)=='number' and type(p.z)=='number' then return p end
            end
            return mousePos
        end,
        liveWorld=Game.mousePos,
        set=Control.SetCursorPos, down=Control.KeyDown, up=Control.KeyUp,
        isDown=Control.IsKeyDown, mouse=Control.mouse_event,
        focus=Game.IsOnTop, chat=Game.IsChatOpen, resolution=Game.Resolution,
        fallback=function()return MenuDelay:Value() end,
        tco=HK_TCO, heroType=Obj_AI_Hero, moveKey=MOUSEEVENTF_RIGHTDOWN, recoverLatchedTCO=true,
        executeAttack=function(record)return Orbwalker:Attack(record.target,record)end,
        executeApproach=APPROACH{orb=function()return Orbwalker end,isDown=Control.IsKeyDown,
            canAttack=function()return Data:HeroCanAttack()end,
            targetable=function(unit)return ChampionInfo:CustomIsTargetable(unit)end,
            send=function(unit,record)return Control.Attack(unit,record)end},
        hero=myHero, attackKey=function()return Menu.Main.AttackTKey:Key() end,
        enabled=function()return Orbwalker: IsEnabled() end,
        timing=timing,deferMoves=true,strictMovement=true,ggCompatible=true,
        cancelPending=function()FlashHelper.Flash=nil;EvadeSupport=nil end,
    })
    local installWorld=WORLD
    installWorld(Cursor,GetTickCount)
    Cursor.DiagnosticsEnabled=(_G.OrbamaTestConfig or {}).enabled==true
    GameIsChatOpen=function()return Cursor:IsChatOpen()end
    Control.KeyDown=function(key)return Cursor:AcquireKey(key,'control')end
    Control.KeyUp=function(key)return Cursor:ReleaseKey(key,'control')end
end
'''.replace('TIMING', module('timing')).replace('INPUT', module('input')).replace('WORLD', module('world')).replace('APPROACH', module('approach'))
    source = replace(source, marker, integration + marker)
    marker = '\n_G.SDK = {'
    profile='(function()\n'+(ROOT/'Scripts/Common/CombatProfiles/classic_vayne.lua').read_text(encoding='utf-8')+'\nend)()'
    source=replace(source,marker,'\ndo\nlocal install='+module('attackprocs')+'\ninstall(Damage,Health,Buff,Data,Attack,myHero,GameTimer,'+profile+',Menu.Orbwalker.Farming,Object)\nend\n'+marker)
    tf_profile='(function()\n'+(ROOT/'Scripts/Common/CombatProfiles/twisted_fate.lua').read_text(encoding='utf-8')+'\nend)()'
    source=replace(source,marker,'\ndo\nlocal install='+module('twistedfate')+'\ninstall(Damage,Buff,GameTimer,'+tf_profile+',DAMAGE_TYPE_MAGICAL)\nend\n'+marker)
    source=replace(source,'Damage:GetAutoAttackDamage(myHero, target, true, self.StaticAutoAttackDamage)',
                   'Damage:GetAutoAttackDamageAt(myHero, target, time + target.distance / speed, self.StaticAutoAttackDamage)')
    source = replace(source, marker, '\ndo\nlocal install = ' + module('selection') + '\nMenu.Target:MenuElement({id="SelectedFogGrace",name="Reserve unseen selection (ms)",value=1500,min=0,max=3000,step=100})\ninstall(Target,GameTimer,function()return Menu.Target.SelectedFogGrace:Value()/1000 end)\nend\n' + marker)
    # Preparation uses existing engines; public hook registration is unchanged.
    source = replace(source, marker, '\ndo\nlocal prepare = ' + module('prepare') + '\nprepare(Cached, Item, Health, Orbwalker, Cursor, {clock=GetTickCount, time=GameTimer, slots=ItemSlots, keys=ItemKeys, control=Control, tco=HK_TCO, combo=ORBWALKER_MODE_COMBO, hero=myHero})\nend\n' + marker)
    source = replace(source, '\t\tFlashHelper:OnTick()\n\t\tCached:Reset()\n\t\tCursor:OnTick()', '\t\tCached:Reset()\n\t\tItem:Prepare()\n\t\tOrbwalker:Prepare()\n\t\tFlashHelper:OnTick()\n\t\tCursor:OnTick()')
    source = replace(source, '\t\tAttack:OnTick()\n\t\tOrbwalker:OnTick()', '\t\tAttack:OnTick()\n\t\tHealth:OnTick()\n\t\tTarget:OnTick()\n\t\tOrbwalker:OnTick()')
    source = replace(source, '\t\tItem:OnTick()\n\t\tTarget:OnTick()\n\t\tHealth:OnTick()', '\t\tItem:OnTick()\n\t\tHealth:DispatchCallbacks()')
    source = replace(source, '\t\tData:WndMsg(msg, wParam)', '\t\tCursor:OnInput(msg, wParam)\n\t\tData:WndMsg(msg, wParam)')
    source = replace(source, '\t\t--tickTest = 2', '''        if not Cursor.Active then
            for _,fn in ipairs(SDK.OnMaintenance) do if SDK.Performance.enabled then SDK.Performance:Call('maintenance',fn) else fn() end end
        end
		--tickTest = 2''')
    source = replace(source, '\t\tCached:Reset()\n\t\tItem:Prepare()', '''        if Cursor.Step==0 then Cursor.GGCompatible=Menu.Main.OrbamaLua.GGCompatibility:Value() end
        Cursor.Timing.enabled=not Cursor.GGCompatible and (Menu.Main.OrbamaLua.AutoMovementTiming:Value() or Menu.Main.OrbamaLua.LearnMoves:Value())
        Cursor.Timing.removeSecondWait=not Cursor.GGCompatible and Menu.Main.OrbamaLua.ReleaseGapTrial:Value() and Cursor.ReleaseGapValidated==true
        Cursor.DetailedDiagnostics=Menu.Main.OrbamaLua.DetailedInput:Value()
        Cursor.DiagnosticsEnabled=(_G.OrbamaTestConfig or {}).enabled==true
		Cached:Reset()
		Item:Prepare()''')
    # Entire Tick including prep, SDK callbacks and maintenance; preserve error propagation.
    source = replace(source, '\tCallback.Add("Tick", function()\n\t\t--[[if tickTest', '\tlocal function OrbamaTick()\n\t\t--[[if tickTest')
    source = replace(source, '\t\t--tickTest = 2\n\tend)', '\t\t--tickTest = 2\n    end\n    Callback.Add("Tick", function()\n        SDK.Performance.enabled=Menu.Main.OrbamaLua.Profile:Value()\n        if SDK.Performance.enabled then return SDK.Performance:Call(\'tick\',OrbamaTick) end\n        return OrbamaTick()\n    end)')
    source = replace(source, '\t\t\tticks[i]()', "\t\t\tif SDK.Performance.enabled then SDK.Performance:Call('sdk_callbacks',ticks[i]) else ticks[i]() end")
    source=replace(source, '\tCallback.Add("Draw", function()\n', '\tlocal function OrbamaDraw()\n')
    source=replace(source, '\t\t--drawTest = 2\n\tend)', '\t\t--drawTest = 2\n    end\n    Callback.Add("Draw",function()\n        SDK.Performance.enabled=Menu.Main.OrbamaLua.Profile:Value()\n        return SDK.Performance:Call("draw",OrbamaDraw)\n    end)')
    # All targetless SDK input also passes ownership checks.
    source=replace(source, '\tAttack = function(self, unit)', '\tAttack = function(self, unit, actionRecord)')
    source=replace(source, 'if not Control.Attack(args.Target) then', 'if not Control.Attack(args.Target, actionRecord) then')
    source=replace(source, '_G.Control.Attack = function(target)', '_G.Control.Attack = function(target, actionRecord)')
    source=replace(source, 'local issued = Cursor:Add(AttackKey:Key(), target)', 'local issued\n            if actionRecord then issued=Cursor:DispatchRecord(actionRecord,AttackKey:Key(),target)\n            else issued=Cursor:Add(AttackKey:Key(),target) end')
    source = replace(source, '\t\t\tCastKey(key)\n\t\t\treturn true', '\t\t\treturn Cursor:SendKeys(key, "control")')
    source = replace(source, '\t\t\tCursor:Add(MOUSEEVENTF_RIGHTDOWN, pos)\n\t\telseif not a then', '\t\t\tif not Cursor:Add(MOUSEEVENTF_RIGHTDOWN, pos) then return false end\n\t\telseif not a then')
    source = replace(source, '\t\t\tCastKey(MOUSEEVENTF_RIGHTDOWN)', '\t\t\tif not Cursor:MoveAtCursor() then return false end')
    source = replace(source, '\t\t\tlocal unit = Game.GetUnderMouseObject()\n\t\t\tif unit and unit.isEnemy and unit.isTargetable then\n\t\t\t\treturn false\n\t\t\tend\n', '')
    # Internal intent consumers must never read the temporarily displaced world cursor.
    source = source.replace('Vector(mousePos)', 'Vector(Cursor:GetPlayerPosition())')
    source = source.replace('GetDistance(mousePos,', 'GetDistance(Cursor:GetPlayerPosition(),')
    source = source.replace('IsInRange(mePos, mousePos,', 'IsInRange(mePos, Cursor:GetPlayerPosition(),')
    source = source.replace('Draw.Circle(mousePos,', 'Draw.Circle(Cursor:GetPlayerPosition(),')
    source += "\nSDK.OrbamaVersion='" + BUILD + "'\nSDK.Input=Cursor\nSDK.OnMaintenance={}\nSDK.GetPlayerPosition=function()return Cursor:GetPlayerPosition()end\n_G.Orbama=SDK\nreturn SDK\n"
    profiling='''
do
    local create = MODULE
    local profiler=create(GetTickCount)
    SDK.Performance=profiler
    if (_G.OrbamaTestConfig or {}).enabled==true then
    for name,object in pairs({cursor=Cursor,attack=Attack,orbwalker=Orbwalker,health=Health,
        target=Target,items=Item,summoners=SummonerSpell,champions=ChampionInfo,actions=Action}) do
        profiler:Wrap(object,'OnTick',name)
    end
    profiler:Wrap(Cursor,'call','host')
    profiler:Wrap(Cursor,'dispatch','input')
    profiler:Wrap(Cached,'Reset','cache_reset')
    profiler:Wrap(Item,'Prepare','inventory_prepare')
    profiler:Wrap(Orbwalker,'Prepare','mode_prepare')
    -- Nested exclusive scopes distinguish host-heavy damage work from health
    -- prediction. No new caching or changes to gameplay freshness.
    profiler:Wrap(Damage,'GetStaticAutoAttackDamage','damage_static')
    profiler:Wrap(Damage,'GetAutoAttackDamageAt','damage_attack')
    profiler:Wrap(Health,'SetLastHitable','health_last_hit')
    profiler:Wrap(Health,'LocalGetPrediction','health_prediction')
    profiler:Wrap(Health,'GetIncoming','health_incoming')
    table.insert(SDK.OnMaintenance,function()profiler:EmitMetrics(Cursor)end)
    end
end
'''.replace('MODULE',module('performance'))
    source=source.replace('\n_G.Orbama=SDK\nreturn SDK\n', profiling+'\n_G.Orbama=SDK\nreturn SDK\n')
    source=source.replace('\n_G.Orbama=SDK\nreturn SDK\n', '\nSDK.MenuMigration=CommunityMenuMigration\nSDK.SharedData='+module('data')+'(Game,GetTickCount,Item,myHero,Attack)\n_G.Orbama=SDK\nreturn SDK\n')
    source=source.replace('\n_G.Orbama=SDK\nreturn SDK\n', '\nSDK.Actions='+module('community')+'(Cursor,GetTickCount,'+module('scheduler')+')\nSDK.OnUrgent={}\nif (_G.OrbamaTestConfig or {}).enabled then\n    SDK.Performance:Wrap(SDK.SharedData,"Prepare","shared_data")\n    SDK.Performance:Wrap(SDK.Actions,"Pump","scheduler")\nend\nSDK.Actions.onRegister=function(scope)\n    local parent=Menu.Main.Plugins\n    local args={id=scope.name,name=scope.name,type=MENU}\n    if not parent[scope.name] then parent:MenuElement(args) end;local group=parent[scope.name]\n    group:MenuElement({id="Limit",name="Priority limit",value=parent.DefaultLimit:Value(),drop={"Background","Normal","Interactive","Critical"}})\n    scope.readLimit=function()return math.max(1,math.min(4,group.Limit:Value()))end\nend\n_G.Orbama=SDK\nreturn SDK\n')
    client_install='\nlocal createActionClient=(function()\n'+action_client()+'\nend)()\nfunction SDK.Actions:CreateClient(options)return createActionClient(_G,options)end\n_G.Orbama=SDK\nreturn SDK\n'
    source=source.replace('\n_G.Orbama=SDK\nreturn SDK\n',client_install)
    source=replace(source, '\t\tTarget:OnTick()\n\t\tOrbwalker:OnTick()', '''\t\tTarget:OnTick()
        SDK.SharedData:Prepare()
        for _,fn in ipairs(SDK.OnUrgent) do
            if SDK.Performance.enabled then SDK.Performance:Call('urgent_callbacks',fn) else fn() end
        end
        SDK.Actions:Tick(2)
\t\tOrbwalker:OnTick()''')
    source=replace(source, '\t\t--tickTest = 2', '        SDK.Actions:Tick()\n\t\t--tickTest = 2')
    menu_start=source.index('Menu = {')
    menu_end=source.index('local testConfig=',menu_start)
    menus=source[menu_start:menu_end]
    menus=re.sub(r'([A-Za-z_][A-Za-z_0-9.]*)\:MenuElement\(',r'CommunityMenuElement(\1,',menus)
    # Flash helper is created before the Menu table, through the same router.
    source=source[:menu_start]+menus+source[menu_end:]
    source=source.replace('main:MenuElement({type = MENU, id = "PMenuFH"', 'CommunityMenuElement(main,{type = MENU, id = "PMenuFH"')
    source=source.replace('FlashHelper = {', 'local CommunityMenuMigration='+module('menus')+'\nlocal CommunityMenuElement=CommunityMenuMigration:Orbama()\nFlashHelper = {',1)
    return '-- GENERATED LUA-FIRST ORBAMA; tools/build_orbama_lua.py\n' + source

if __name__ == '__main__':
    (ROOT/'experiments/build').mkdir(parents=True,exist_ok=True)
    OUT.write_text(render(), encoding='utf-8', newline='\n')
    manifest = {'build': BUILD, 'reference_sha256': BASE_SHA,
                'artifact_sha256': hashlib.sha256(OUT.read_bytes()).hexdigest(),
                'modules': {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(MODULES.glob('*.lua'))},
                'live_gameplay_tested': False}
    (ROOT/'experiments/build/lua-manifest.json').write_text(json.dumps(manifest, indent=2)+'\n', encoding='utf-8')
    print('Built', BUILD, manifest['artifact_sha256'])
