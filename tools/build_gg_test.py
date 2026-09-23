"""Build a pinned experimental GG fork; the reference GG file stays untouched."""
from pathlib import Path
import hashlib
import json

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "reference/GGOrbwalker-3.075.lua"
MODULE = ROOT / "experiments/gg_adaptive_cursor.lua"
OUT = ROOT / "experiments/build/adaptive/Orbama.lua"
BASE_SHA = "cfb06dda0e10f99e66eb25ac9742e4306d50f6b16de8e18ff98d840b3196422d"

MENU = '''
Menu.Main:MenuElement({type=MENU,id='AdaptiveCursorTest',name='EXPERIMENT: adaptive cursor'})
do
    local menu=Menu.Main.AdaptiveCursorTest
    menu:MenuElement({id='Enabled',name='Adaptive timing (experimental)',value=true})
    menu:MenuElement({id='TrialStart',name='Initial trial hold (ms; 0 = next callback)',value=0,min=0,max=60,step=1})
    menu:MenuElement({id='MaxHold',name='Stop increasing at (ms)',value=120,min=30,max=200,step=5})
    menu:MenuElement({id='Samples',name='Matching samples per timing before consistent',value=30,min=10,max=200,step=10})
    menu:MenuElement({id='LearnMoves',name='Learn from ordinary movement',value=true})
    menu:MenuElement({id='LearnSpells',name='Learn from ordinary position spells',value=true})
    menu:MenuElement({id='LearnAttacks',name='Also test basic-attack input',value=false})
    menu:MenuElement({id='LearnCritical',name='Also experiment during critical actions',value=false})
    menu:MenuElement({id='NextActionGap',name='Extra gap AFTER cursor release (ms)',value=0,min=0,max=80,step=1})
    menu:MenuElement({id='Status',name='Show calibration status',value=true})
    menu:MenuElement({id='Reset',name='Reset calibration (toggle off/on to repeat)',value=false})
end
'''


def render():
    raw = SOURCE.read_bytes()
    if hashlib.sha256(raw).hexdigest() != BASE_SHA:
        raise RuntimeError("Reference GG changed: review and repin before building the fork.")
    source = raw.decode("utf-8").replace("\r\n", "\n")
    source = source.replace('local __name__ = "GGOrbwalker"', 'local __name__ = "Orbama"', 1)
    guard = 'if _G.GGUpdate then\n\treturn\nend'
    assert source.count(guard) == 1
    source = source.replace(guard, '''if _G.SDK and _G.SDK.OrbamaVersion then return _G.SDK end
if _G.SDK or _G.GGUpdate then
    print('[Orbama] Another SDK is active. Disable GGOrbwalker and reload the complete script runtime.')
    return
end''', 1)
    source = source.replace('id = "GGOrbwalker", name = "GG Orbwalker"', 'id = "GGOrbwalker", name = "Orbama"', 1)
    begin = source.index('\nif\n\tGGUpdate:New({')
    end = source.index('\n--#region headers', begin)
    source = source[:begin] + '\n-- Local experimental fork: automatic self-overwrite disabled.\n' + source[end:]
    marker = '\nlocal initialLatency = Game.Latency()'
    assert source.count(marker) == 1
    source = source.replace(marker, '\n' + MENU + marker)
    module = MODULE.read_text(encoding="utf-8")
    integration = '''
-- GG adaptive test: retains the original attack, movement and target engines.
do
    local createAdaptive = (function()
MODULE
    end)()
    local extraSpellKeys={{key=HK_SUMMONER_1,slot=SUMMONER_1},{key=HK_SUMMONER_2,slot=SUMMONER_2}}
    for i,slot in ipairs(ItemSlots) do extraSpellKeys[#extraSpellKeys+1]={key=ItemKeys[i],slot=slot} end
    Cursor=createAdaptive(Cursor,{
        hero=myHero,clock=GetTickCount,time=Game.Timer,screen=Game.cursorPos,
        mouseWorld=function()return mousePos end,latency=Game.Latency,resolution=Game.Resolution,mapID=Game.mapID,
        chat=Game.IsChatOpen,focus=Game.IsOnTop,moveKey=MOUSEEVENTF_RIGHTDOWN,
        attackKey=function()return Menu.Main.AttackTKey:Key() end,
        spellKeys={HK_Q,HK_W,HK_E,HK_R},extraSpellKeys=extraSpellKeys,menu=Menu.Main.AdaptiveCursorTest,
        fallback=function()return MenuDelay:Value() end,logBase=COMMON_PATH or SCRIPT_PATH,
        draw=function(row)
            local p=row.profile
            local detail=p and (tostring(row.hold)..'ms '..(row.learning and 'trial' or 'fallback')..' | '..p.status..' | '..p.success..' samples / '..p.directions..' directions') or 'waiting for observable actions'
            Draw.Text('ORBAMA CURSOR TEST | '..tostring(row.class or '')..' | '..detail,13,20,310,Draw.Color(255,240,190,70))
        end
    })
end
'''.replace('MODULE', module)
    marker = '\n-- Track Crescendum\'s outgoing'
    assert source.count(marker) == 1
    source = source.replace(marker, '\n' + integration + marker)
    marker = '\n\t\t--tickTest = 2'
    assert source.count(marker) == 1
    source = source.replace(marker, '\n\t\tCursor:AdaptiveFlush()' + marker)
    marker = '\n\t\tData:WndMsg(msg, wParam)'
    assert source.count(marker) == 1
    source = source.replace(marker, '\n\t\tCursor:AdaptiveInput(msg, wParam)' + marker)
    source += "\nSDK.OrbamaVersion='Orbama-test-1'\n_G.Orbama=SDK\nreturn SDK\n"
    return '-- GENERATED ORBAMA EXPERIMENT; see docs/GG-ADAPTIVE-TEST.md\n' + source


if __name__ == '__main__':
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(render(), encoding="utf-8", newline="\n")
    report = {"reference": str(SOURCE), "reference_sha256": BASE_SHA,
              "artifact": str(OUT), "sha256": hashlib.sha256(OUT.read_bytes()).hexdigest()}
    manifest = ROOT/'experiments/build/manifest.json'
    manifest.parent.mkdir(parents=True, exist_ok=True)
    manifest.write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
    print('Built Orbama:', OUT)
