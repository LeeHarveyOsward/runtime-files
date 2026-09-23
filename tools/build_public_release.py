"""Build public sources and standalone release scripts without capture modules."""
from pathlib import Path
import hashlib
import json
import re
import sys
import zlib

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools'))
from build_orbama_lua import render as orbama
from build_lho import render_bundle as lho

VERSION=1
ORIGIN='https://raw.githubusercontent.com/LeeHarveyOsward/runtime-files'
OUT=ROOT/'dist/public-runtime'

def between(body,start,end,replacement):
    assert body.count(start)==1,start
    first=body.index(start);last=body.index(end,first)
    return body[:first]+replacement+body[last:]

def lho_module(name,body):
    if name=='performance':
        return "local function skip()end\nreturn {new=function()return {install=skip,pulse=skip,begin=skip,finish=skip,abort=skip,flush=skip}end}"
    if name=='telemetry':
        return "return {new=function()return {safe=function()end,enabled=function()return false end}end}"
    if name=='runtime':
        body=between(body,'function R:log(', 'function R:chatOpen()', 'function R:log()end\n')
        body=between(body,'function R:snapshot(', 'return R', '')
    if name=='app':
        body=between(body,"    if c.config:get('playtestLogging') then\n",'    if c.sdk.Input or', '')
        body=between(body,'function App:Snapshot()', 'function App:Shutdown()', '')
        body=body.replace("print('[LHO] Controller stopped: '..tostring(err)..' | log: '..tostring(c.logFile or 'unavailable'))", "print('[LHO] Controller stopped. Reload the runtime.')")
        body=body.replace("    print('[LHO] Loaded '..c.profile.id..'. Terrain: '..(c.terrain.provider and c.terrain.provider.kind or 'unavailable')..'.')",'')
        body=body.replace("    if c.config:get('playtestLogging') then print('[LHO] PLAYTEST LOG: '..tostring(c.logFile or 'not written')) end",'')
        body=body.replace("    c.performance=require('lho.performance').new(c);c.performance:install(self)",'')
        body=body.replace("            c.performance:pulse(name)",'').replace("            local token=c.performance:begin(name)",'')
        body=body.replace("                local phases=c.performance:abort()",'')
        body=body.replace("phases=phases",'')
        body=body.replace("            if ok then c.performance:finish(token) end",'')
        body=body.replace("U.endBuffScope();if c.config:get('performanceLogging') then pcall(c.performance.flush,c.performance) end",'U.endBuffScope()')
        body=body.replace("    c.telemetry=require('lho.telemetry').new(c)",'')
        body=body.replace("    if c.config:get('combatLogging') then c.telemetry:safe('tick') end",'')
        body=body.replace("        c.telemetry:safe('postAttack')",'').replace("    c.telemetry:safe('shutdown')",'')
    if name=='config':
        body=between(body,'    local test=_G.OrbamaTestConfig','    if test.enabled then','    local test={}\n')
        body=body.replace("    function self:get(k)\n", "    function self:get(k)\n        if k=='diagnostics' or k=='fileLogging' or k=='playtestLogging' or k=='combatLogging' or k=='performanceLogging' or k=='drawHUD' then return false end\n")
        body=body.replace("{'drawHUD','Status panel'},",'')
    if name=='overlay':
        body=between(body,'    -- Session heartbeat',"    if not c.config:get('draw') then return end",'')
        body=between(body,"    if c.config:visible('drawHUD',c.sdk,c.mode) then",'    local p=c.wards.previewState','')
    return body

def orbama_module(name,body):
    if name=='performance':
        return "return function()return {enabled=false,Call=function(_,name,fn,...)return fn(...)end,Wrap=function()end,Snapshot=function()return {enabled=false}end,EmitMetrics=function()end}end"
    if name=='input':
        body=between(body,'    function cursor:record(', '    function cursor:GetPendingButtons()',
            '    function cursor:record()end\n    function cursor:GetDiagnosticEvents()return {},0 end\n    function cursor:GetDiagnosticErrors()return {},0 end\n')
        body=between(body,'    function cursor:GetDiagnostics()', '    local canonicalKey=',
            '''    function cursor:GetDiagnostics()return {pendingButtons=self:GetPendingButtons()}end
    function cursor:call(fn,...)
        self.InFlight=(self.InFlight or 0)+1
        local ok,value=pcall(fn,...);self.InFlight=self.InFlight-1
        return ok and value~=false,value
    end
''')
    return body

def payloads():
    provider=orbama(orbama_module)
    provider=between(provider,'if _G.OrbamaTestConfig==nil then', '\nlocal GameTimer', '')
    provider=provider.replace('(_G.OrbamaTestConfig or {})','({})').replace('_G.OrbamaTestConfig or {}','{}')
    controller=lho(lho_module,omit=('logger','playtest','performance','telemetry'))
    prediction=(ROOT/'Scripts/Common/OrbamaPrediction/core.lua').read_text(encoding='utf-8')
    controller="if not myHero or (myHero.charName~='LeeSin' and myHero.charName~='Jade_LeeSin') then return end\nif not _G.GGPrediction then\n(function()\n"+prediction+"\nend)()\nend\n"+controller
    return {'Orbama':provider,'LeeHarveyOsward':controller}

def bootstrap(name,payload):
    sha=(ROOT/'Scripts/Common/Release/sha256.lua').read_text(encoding='utf-8')
    client=(ROOT/'Scripts/Common/Release/client.lua').read_text(encoding='utf-8')
    return ("-- Release "+str(VERSION)+"\nlocal client=_G.OrbamaReleaseClient\nif not client then\n"
        "local hash=(function()\n"+sha+"\nend)()\nlocal create=(function()\n"+client+
        "\nend)()\nclient=create(_G,hash,"+str(VERSION)+","+json.dumps(ORIGIN)+")\n"
        "_G.OrbamaReleaseClient=client\nend\nreturn client:Boot("+json.dumps(name)+",function()\n"+
        payload+"\nend,"+str(VERSION)+")\n")

def build():
    bodies=payloads();manifest='R1\n'+str(VERSION)+'\n'
    files={}
    for name,body in bodies.items():
        data=body.encode('utf-8')
        manifest+=f'{name} {hashlib.sha256(data).hexdigest()} {len(data)} {zlib.adler32(data)}\n'
        files[f'release/{VERSION}/{name}.lua']=data
        files[name+'.lua']=bootstrap(name,body).encode('utf-8')
    files['release/manifest']=manifest.encode()
    for directory in ('Orbama','LeeHarveyOsward','ActionClient','ChampionMobility','CombatProfiles','OrbamaPrediction','Release'):
        for path in (ROOT/'Scripts/Common'/directory).glob('*.lua'):
            files[path.relative_to(ROOT).as_posix()]=path.read_bytes()
    for name in ('build_public_release.py','build_orbama_lua.py','build_lho.py','build_gg_test.py','build_action_client.py','orbama_patches.py'):
        files['tools/'+name]=(ROOT/'tools'/name).read_bytes()
    files['reference/GGOrbwalker-3.075.lua']=(ROOT/'reference/GGOrbwalker-3.075.lua').read_bytes()
    for name,data in files.items():
        path=OUT/name;path.parent.mkdir(parents=True,exist_ok=True);path.write_bytes(data)
    return files

if __name__=='__main__':
    files=build()
    print(json.dumps({'root':str(OUT),'files':len(files),'version':VERSION,'manifest':files['release/manifest'].decode()},indent=2))
