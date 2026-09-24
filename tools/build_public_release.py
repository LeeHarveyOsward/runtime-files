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
from build_classic_v2 import render as classic, CHAMPIONS
from build_katarina import render as katarina
from build_twisted_fate import render as twisted_fate
from build_evade import render as evade

VERSION=6
ORIGIN='https://raw.githubusercontent.com/LeeHarveyOsward/runtime-files'
OUT=ROOT/'dist/public-runtime'

def public_filename(component):
    return 'ClassicAIO_Orbama.lua' if component=='ClassicAIOv2' else component+'.lua'

CHANNELS={'ClassicAIOv2':'classic','OrbamaEvade':'evade','KataHari':'katahari','CardMarx':'cardmarx'}

def controller_module(name,body):
    if name=='kata.app':
        body=between(body,"    self.logger=require('kata.log')",'    return self','')
        body=between(body,'function App:record(', 'function App:decide()',
            'function App:record()end\nfunction App:flushLog()end\nfunction App:log()end\nfunction App:tick()if self.active then self:decide()end end\n')
        body=body.replace("    if self.telemetry then self.telemetry:safe('draw')end\n",'')
        body=body.replace("    if self.sdk.OnMaintenance then attach(self.sdk.OnMaintenance,function()self:flushLog()end)end\n",'')
        body=body.replace('metrics={ticks=0,totalMs=0,maxMs=0},','')
    if name=='kata.config':
        body=body.replace("{'diagnostics','Diagnostic log'},",'').replace(",{'diagnostics','Diagnostic log'}",'')
        body=body.replace("function C:get(k)","function C:get(k)if k=='diagnostics'then return false end;")
    if name=='tf.app':
        body=body.replace(',records={},recordIndex=0','')
        body=between(body,"    c.log=require('tf.log')",'    c.state:refresh()', '')
        body=between(body,'function App:record(', 'function App:blocked()', 'function App:record()end\n')
        body=between(body,"    if self.config:get('diagnostics') and Game.Timer()", "    self.actions.client:SetBlocked('gate','attack',s.channeling)", '')
        body=between(body,'function App:performance()', '    self.tickFn=function()', 'function App:install()\n')
        body=between(body,'        if ok then\n', '        if not ok then', '')
        body=body.replace('self.telemetry:draw();','')
        body=between(body,"    self.log:write('loaded'",'end\nfunction App:Shutdown()', '')
        body=body.replace('    if self.log then self.log:flush(true)end\n','')
    if name=='tf.config':
        body=body.replace("    add('diagnostics','Record bounded diagnostics',false)\n",'')
        body=body.replace('function c:get(id)',"function c:get(id)if id=='diagnostics'then return false end;")
    return body

def evade_module(name,body):
    if name=='diagnostics':
        return 'local function skip()end\nreturn {new=function()return {Sample=skip,Event=skip,Snapshot=function()return {}end}end}'
    return body

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

def classic_module(name,body):
    if name=='core':
        body=body.replace("version='2.1.11-dev'","version='2.1.11'")
        body=between(body,'    function C:Trace(', '    local function point', '    function C:Trace()end\n')
        body=body.replace('        if self.logger then pcall(self.logger.Close,self.logger,reason)end\n','')
        body=body.replace('        local began=self.logger and g.GetTickCount()\n','')
        body=between(body,'        if began then\n','        if not results[1]', '')
        body=between(body,"        if self.logger and reason~='deduplicated'",'        if not id then','')
        body=between(body,'            if self.logger then\n',"            if not r or r.state",'')
        body=between(body,'                    -- A mechanical change can be real', '                    local receipt=', '')
        body=between(body,"                            if self.logger then self:Trace('cast_observed'",'                            for _,fn', '')
        body=between(body,"        if self.logger then self:Trace('cast_finished'",'        A:Finish', '')
        body=between(body,'    local logOK,logger=',"    g.Callback.Add('Tick'",'')
        body=between(body,'            if C.logger and not C.logger.failed then\n','        end\n    end)', '')
        assert 'logger' not in body
    if name=='bundle':
        body=body.replace('Classic data; no runtime updates.','Classic data; release payload.')
        body=between(body,' if not(active and active.active) then\n', ' if active and active.active', '')
        body=re.sub(r'^\s*print\(["\']Classic AIO[^\n]+\n','\n',body,flags=re.M)
    return body

def payloads():
    provider=orbama(orbama_module)
    provider=between(provider,'if _G.OrbamaTestConfig==nil then', '\nlocal GameTimer', '')
    provider=provider.replace('(_G.OrbamaTestConfig or {})','({})').replace('_G.OrbamaTestConfig or {}','{}')
    controller=lho(lho_module,omit=('logger','playtest','performance','telemetry'))
    prediction=(ROOT/'Scripts/Common/OrbamaPrediction/core.lua').read_text(encoding='utf-8')
    controller="if not myHero or (myHero.charName~='LeeSin' and myHero.charName~='Jade_LeeSin') then return end\nif not _G.GGPrediction then\n(function()\n"+prediction+"\nend)()\nend\n"+controller
    classic_body=classic(classic_module,omit=('diagnostics',))
    classic_body="if SDK and SDK.OrbamaVersion and not _G.GGPrediction then\n(function()\n"+prediction+"\nend)()\nend\n"+classic_body
    kata=katarina(controller_module,omit=('kata.log','kata.telemetry'))
    tf=twisted_fate(controller_module,omit=('tf.log','tf.telemetry'))
    tf="if myHero and (myHero.charName=='TwistedFate' or myHero.charName=='Jade_TwistedFate') and SDK and SDK.OrbamaVersion and not _G.GGPrediction then\n(function()\n"+prediction+"\nend)()\nend\n"+tf
    return {'Orbama':provider,'LeeHarveyOsward':controller,'ClassicAIOv2':classic_body,
        'OrbamaEvade':evade(transform=evade_module),'KataHari':kata,'CardMarx':tf}

def bootstrap(name,payload):
    sha=(ROOT/'Scripts/Common/Release/sha256.lua').read_text(encoding='utf-8')
    client=(ROOT/'Scripts/Common/Release/client.lua').read_text(encoding='utf-8')
    is_classic=name=='ClassicAIOv2'
    singleton='ClassicAIOv2ReleaseClient' if is_classic else 'OrbamaReleaseClient'
    options=",{names={'ClassicAIOv2'},channel='classic',cachePrefix='runtime-classic-'}" if is_classic else ''
    if name in CHANNELS and not is_classic:
        channel=CHANNELS[name]
        singleton=name+'ReleaseClient'
        options=",{names={'"+name+"'},channel='"+channel+"',cachePrefix='runtime-"+channel+"-'}"
    guard=''
    if name in ('KataHari','CardMarx'):
        hero='Katarina' if name=='KataHari' else 'TwistedFate'
        guard="if not myHero or (myHero.charName~='"+hero+"' and myHero.charName~='Jade_"+hero+"') then return end\n"
    if is_classic:
        supported='{'+','.join('['+json.dumps(c)+']=true' for c in CHAMPIONS)+'}'
        guard="local supported="+supported+"\nif not myHero or not supported[myHero.charName:match('^Jade_(.+)$') or ''] then return end\nif not SDK then print('[ClassicAIOv2] SDK required');return end\n"
    return ("-- Release "+str(VERSION)+"\n"+guard+"local client=_G."+singleton+"\nif not client then\n"
        "local hash=(function()\n"+sha+"\nend)()\nlocal create=(function()\n"+client+
        "\nend)()\nclient=create(_G,hash,"+str(VERSION)+","+json.dumps(ORIGIN)+options+")\n"
        "_G."+singleton+"=client\nend\nreturn client:Boot("+json.dumps(name)+",function()\n"+
        payload+"\nend,"+str(VERSION)+")\n")

def build():
    bodies=payloads();manifests={name:'R1\n'+str(VERSION)+'\n' for name in ('release',*CHANNELS.values())}
    files={}
    for name,body in bodies.items():
        data=body.encode('utf-8')
        channel=CHANNELS.get(name,'release')
        manifests[channel]+=f'{name} {hashlib.sha256(data).hexdigest()} {len(data)} {zlib.adler32(data)}\n'
        files[f'{channel}/{VERSION}/{name}.lua']=data
        files[public_filename(name)]=bootstrap(name,body).encode('utf-8')
    for channel,manifest in manifests.items():files[channel+'/manifest']=manifest.encode()
    for channel in manifests:
        for path in (ROOT/channel).glob('*/*.lua'):
            if path.parent.name.isdigit() and int(path.parent.name)<VERSION:
                files[path.relative_to(ROOT).as_posix()]=path.read_bytes()
    for directory in ('Orbama','LeeHarveyOsward','ClassicAIOv2','ActionClient','ChampionMobility','CombatProfiles','OrbamaPrediction','Release','Katarina','TwistedFate','OrbamaEvade'):
        for path in (ROOT/'Scripts/Common'/directory).rglob('*'):
            if not path.is_file() or path.suffix not in ('.lua','.json'):continue
            files[path.relative_to(ROOT).as_posix()]=path.read_bytes()
    for name in ('build_public_release.py','build_orbama_lua.py','build_lho.py','build_classic_v2.py','build_gg_test.py','build_action_client.py','orbama_patches.py','build_katarina.py','build_twisted_fate.py','build_evade.py'):
        files['tools/'+name]=(ROOT/'tools'/name).read_bytes()
    files['reference/GGOrbwalker-3.075.lua']=(ROOT/'reference/GGOrbwalker-3.075.lua').read_bytes()
    from build_installer_manifest import installer_files
    files.update(installer_files(files, VERSION))
    files['tools/build_installer_manifest.py']=(ROOT/'tools/build_installer_manifest.py').read_bytes()
    for name in ('install.ps1','INSTALL.md','README.md'):
        files['installer/'+name]=(ROOT/'installer'/name).read_bytes()
    for name in ('installer_spec.ps1','run_installer.py'):
        files['tests/'+name]=(ROOT/'tests'/name).read_bytes()
    for name,data in files.items():
        path=OUT/name;path.parent.mkdir(parents=True,exist_ok=True);path.write_bytes(data)
    return files

if __name__=='__main__':
    files=build()
    print(json.dumps({'root':str(OUT),'files':len(files),'version':VERSION,'manifest':files['release/manifest'].decode()},indent=2))
