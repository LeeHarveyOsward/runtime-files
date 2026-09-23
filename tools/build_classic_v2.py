"""Offline, deterministic standalone ClassicAIOv2 bundle. No downloads."""
from pathlib import Path
import hashlib,json,sys,re
sys.path.insert(0,str(Path(__file__).resolve().parent))
from build_action_client import render as action_client
ROOT=Path(__file__).resolve().parents[1]
SRC=ROOT/'Scripts/Common/ClassicAIOv2'
OUT=ROOT/'Scripts/ClassicAIOv2.lua'
CHAMPIONS='Ahri Akali Ashe Blitzcrank Corki Ezreal Fiora Janna Katarina KogMaw Leona MasterYi MissFortune Pantheon Ryze Sivir Skarner Teemo Tristana Twitch Vayne'.split()
def runtime():
    """Lexical module isolation; the live host intentionally rejects setfenv."""
    common=(SRC/'common.lua').read_text(encoding='utf-8')
    helpers=re.findall(r'^function\s+(\w+)\s*\(',common,re.M)
    aliases='_G V2 SDK Control Callback DelayAction MenuElement GGPrediction require os class'.split()
    chunks=['modules.runtime=function(env,champion)',
            'local '+','.join(aliases)+'='+','.join('env' if name=='_G' else 'env.'+name for name in aliases),
             'local Menu,lastQ,lastW,lastE,lastR,V2RefreshClaims',
             'local VayneProfile=modules.vayneProfile',
            'local '+','.join(helpers),
            'do\n'+common+'\nend']
    chunks += ['env.'+name+'='+name for name in helpers]
    chunks += ['do\n'+(SRC/'activator.lua').read_text(encoding='utf-8')+'\nend',
               'env.V2RefreshClaims=V2RefreshClaims']
    for name in CHAMPIONS:
        source=(SRC/'champions'/f'{name}.lua').read_text(encoding='utf-8')
        source,count=re.subn(r'\bclass\s+"(\w+)"',r'local \1=class("\1")',source)
        assert count==1,(name,'expected exactly one lexical champion class')
        chunks += ['if champion=='+json.dumps(name)+' then\n'+source+'\nend']
    chunks += ['env.Menu=Menu','end']
    return '\n'.join(chunks)
def render(transform=None,omit=()):
    chunks=['-- GENERATED: tools/build_classic_v2.py; Classic data; no runtime updates.','local modules={}']
    chunks.append('modules.actionClient=(function()\n'+action_client()+'\nend)()')
    chunks.append('modules.vayneProfile=(function()\n'+(ROOT/'Scripts/Common/CombatProfiles/classic_vayne.lua').read_text(encoding='utf-8')+'\nend)()')
    for name in ('prediction','policies','diagnostics','core'):
        if name in omit:continue
        body=(SRC/(name+'.lua')).read_text(encoding='utf-8')
        if transform:body=transform(name,body)
        chunks.append('modules['+json.dumps(name)+']=(function()\n'+body+'\nend)()')
    chunks.append(runtime())
    chunks.append('local supported='+ '{'+','.join('['+json.dumps(c)+']=true' for c in CHAMPIONS)+'}')
    chunks.append('''
local champion=myHero.charName:match('^Jade_(.+)$')
if not champion or not supported[champion] then return end
if not SDK then print('[ClassicAIOv2] SDK required');return end
if champion=='Katarina' and SDK.OrbamaVersion then
 local active=_G.KatarinaController
 if not(active and active.active) then
  -- A missing or failed standalone bundle preserves the original controller.
  pcall(require,'Katarina')
  active=_G.KatarinaController
 end
 if active and active.active and active.profile.hero==myHero.charName then return active end
end
if not GGPrediction then require(SDK.OrbamaVersion and 'OrbamaPrediction' or 'GGPrediction') end
if not GGPrediction then print('[ClassicAIOv2] Prediction provider required');return end
local ctx=modules.core(_G,modules,champion)
if not ctx:Active() then return ctx end
modules.runtime(ctx.env,champion)
return ctx
''')
    result='\n'.join(chunks)
    return transform('bundle',result) if transform else result
if __name__=='__main__':
    (ROOT/'experiments/build').mkdir(parents=True,exist_ok=True)
    OUT.write_text(render(),encoding='utf-8',newline='\n')
    manifest={'version':'2.1.8-dev','champions':CHAMPIONS,'artifact_sha256':hashlib.sha256(OUT.read_bytes()).hexdigest(),
        'sources':{str(p.relative_to(SRC)).replace('\\','/'):hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(SRC.rglob('*.lua'))},'live_verified':False,'shared_action_client_sha256':hashlib.sha256(action_client().encode('utf-8')).hexdigest(),
        'shared_classic_vayne_sha256':hashlib.sha256((ROOT/'Scripts/Common/CombatProfiles/classic_vayne.lua').read_bytes()).hexdigest()}
    (ROOT/'experiments/build/classic-v2-manifest.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8')
    print('ClassicAIOv2',manifest['artifact_sha256'])
