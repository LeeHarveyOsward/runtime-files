-- Runtime identifiers: repository ClassicAIO + Riot Data Dragon 16.17.1.
-- Classic combat coefficients are candidates, deliberately gated until measured.
local P={version='16.17.1',build='2026-09-23-r79',neutralTeam=300}
P.classicSmiteTargets={s3lizardelder=true,s3ancientgolem=true,lizardelder=true,ancientgolem=true,
    giantwolf=true,wraith=true,greatwraith=true,golem=true,wight=true,red=true,blue=true}
P.normalSmiteTargets={srured=true,srublue=true,srumurkwolf=true,srurazorbeak=true,
    srukrug=true,srugromp=true,srucrab=true,sruscuttlecrab=true,red=true,blue=true}
P.smites={summonersmite=600,s5summonersmiteplayerganker=1000,s5summonersmiteduel=1000,
    summonersmiteavataroffensive=1400,summonersmiteavatarutility=1400,summonersmiteavatardefensive=1400}
P.normal={id='normal',hero='LeeSin',qRange=1100,qSpeed=1800,qRadius=60,wRange=700,
    eRange=450,e2Range=600,rRange=375,kickDistance=1200,q2Range=1300,smiteRange=500,
    qBase={60,90,120,150,180},qRatio=1.15,eBase={35,60,85,110,135},eRatio=.9,
    rBase={175,400,625},rRatio=2,damageVerified=false,
    yellowWard=3340,
    wards={[2055]='stack',[2056]='stack',[3340]='charge',[3851]='charge',[3853]='charge',
        [3855]='charge',[3857]='charge',[3859]='charge',[3860]='charge',[3863]='charge',
        [3864]='charge',[3866]='charge',[3867]='charge',[3869]='charge',[3870]='charge',[3871]='charge',
        [3876]='charge',[3877]='charge',[4641]='stored',[4643]='stored'}}
P.classic={id='classic',hero='Jade_LeeSin',qRange=1100,qSpeed=1800,qRadius=60,wRange=700,
    -- Q1 BaseDamage/ADRatio confirmed in research/leesin/jade_leesin.bin.json.
    -- This narrow provenance does not certify Q2, item procs or other modes.
    q1DataMap=453,
    qMonsterAmplifiers={[771039]=1.1,[771080]=1.2,[773207]=1.3,[773209]=1.3},
    eRange=350,e2Range=500,rRange=375,kickDistance=1200,q2Range=1300,smiteRange=760,
    qBase={50,80,110,140,170},qRatio=.9,eBase={60,95,130,165,200},eRatio=1,
    rBase={200,400,600},rRatio=2,damageVerified=false,
    yellowWard=773340,
    wardInventoryCharges={[772045]=true,[772049]=true},
    wards={[772043]='stack',[772044]='stack',[772045]='charge',[772049]='charge',
        [772050]='stack',[773154]='cooldown',[773160]='cooldown',[773340]='charge'}}
P.qMarks={leesinqone=true,leesinqonemanager=true,leesinqprimed=true,leesinq2=true}
P.passive={leesinpassivebuff=true,leesinpassivecosmetic=true,leesinpassive=true}
P.eMarks={leesineone=true,leesinetempest=true,leesineonemanager=true}
P.immortal={judicatorintervention=true,kindredrnodeathbuff=true,undyingrage=true,
    kayler=true,zileanchronoshift=true,tryndamereundyingrage=true,zhonyasringshield=true}
-- Host flag disambiguation from pinned GG IsHeroImmortal; observed on normal
-- Jinx in the 55-minute trace. Not proof of a successful resurrection.
P.reviveReady={willrevive=true}
-- Names also used by repository Leona/KillerLib defensive-target checks;
-- GGPrediction documents runtime buff type 4 as SpellShield.
P.kickBlocked={morganae=true,bansheesveil=true,sivire=true,nocturneshroudofdarkness=true,
    olafragnarok=true,poppydiplomaticimmunity=true,malzaharpassiveshield=true}
P.epics={Dragon=true,Elder=true,Baron=true,Herald=true,Grubs=true,Atakhan=true}
-- Seconds after camp death, not first-spawn times. Boss values are estimates
-- until a native transition is recorded; see docs/LHO-R17-PLAYTEST.md.
P.respawns={
    -- Standard SR: 11.10 established 135s small camps. The 26.1 reductions
    -- to 120s / 270s apply to Swiftplay, not this profile (26.17 review).
    normal={Red=300,Blue=300,Wolves=135,Raptors=135,Krugs=135,Gromp=135,River=150,
        Dragon=300,Elder=360,Baron=360,Herald=0,Grubs=0,Atakhan=0},
    classic={Red=300,Blue=300,Wolves=75,Wraiths=75,Golems=75,Wight=50,Dragon=360,Baron=420}}
function P.get(hero)
    if hero=='LeeSin' then return P.normal elseif hero=='Jade_LeeSin' then return P.classic end
end
function P.category(name)
    name=(name or ''):lower()
    if name:find('dragon',1,true) then return name:find('elder',1,true) and 'Elder' or 'Dragon' end
    if name:find('baron',1,true) then return 'Baron' end
    if name:find('herald',1,true) then return 'Herald' end
    if name:find('horde',1,true) or name:find('voidgrub',1,true) then return 'Grubs' end
    if name:find('atakhan',1,true) then return 'Atakhan' end
    if name:find('ancientgolem',1,true) or name:find('sru_blue',1,true) then return 'Blue' end
    if name:find('lizardelder',1,true) or name:find('sru_red',1,true) then return 'Red' end
    if name:find('crab',1,true) or name:find('scuttle',1,true) then return 'River' end
    if name:find('wight',1,true) or name:find('greatwraith',1,true) then return 'Wight' end
    if name:find('wraith',1,true) then return 'Wraiths' end
    if name:find('gromp',1,true) then return 'Gromp' end
    if name:find('wolf',1,true) or name:find('wolves',1,true) then return 'Wolves' end
    if name:find('razorbeak',1,true) or name:find('raptor',1,true) then return 'Raptors' end
    if name:find('krug',1,true) then return 'Krugs' end
    if name:find('golem',1,true) then return 'Golems' end
    return 'Camp'
end
function P.jungleEntity(unit)
    local name=(unit and unit.charName or ''):lower()
    -- Map assets also contain non-camp props / the moving blue-buff spirit.
    -- Their names must not revive a cleared camp or become routing anchors.
    return name~='sru_spiritwolf' and name~='sru_baronspawn' and not name:find('_prop',1,true)
        and not name:find('plant',1,true)
end
P.openings={
    normal={{'Red','Krugs','Raptors','Wolves','Blue','Gromp'},{'Blue','Gromp','Wolves','Raptors','Red','Krugs'}},
    classic={{'Red','Golems','Wraiths','Wolves','Blue','Wight'},{'Blue','Wight','Wolves','Wraiths','Red','Golems'}}}
-- Fallback discovery centers only for regular SR. Classic uses observed Camp objects.
P.centers={{3735,7890,100,'Blue'},{3781,6444,100,'Wolves'},{2112,8450,100,'Gromp'},
    {6824,5508,100,'Raptors'},{7772,4028,100,'Red'},{8482,2706,100,'Krugs'},
    {11032,7002,200,'Blue'},{11008,8386,200,'Wolves'},{12702,6444,200,'Gromp'},
    {7987,9471,200,'Raptors'},{7108,10892,200,'Red'},{6317,12146,200,'Krugs'},
    {10423,5181,0,'River'},{4397,9610,0,'River'}}
P.campNames={ [1]='Blue',[2]='Wolves',[3]='Raptors',[4]='Red',[5]='Krugs',[6]='Dragon',
    [7]='Blue',[8]='Wolves',[9]='Raptors',[10]='Red',[11]='Krugs',[12]='Baron',
    [13]='Gromp',[14]='Gromp',[15]='River',[16]='River',[17]='Herald'}
return P
