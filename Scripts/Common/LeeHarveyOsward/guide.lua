-- Interactive help edits the same settings as the native menu.
local U=require('lho.util')
local Links=require('lho.guidelinks')
local UI=require('lho.guideui')
local G={};G.__index=G
G.titles={'Quick start','Wardjump: tap','Wardjump: plan','Insec: controls','Insec: team & turret',
    'Insec: preview','Combo & chase','Harass & assists','Lane & jungle clear','Auto-jungle',
    'Smite & objectives','Items & leveling','Drawings & settings'}
function G.new(ctx) return setmetatable({ctx=ctx,down={}},G) end
function G:modeKey(name)
    local sdk=self.ctx.sdk;local orb=sdk.Orbwalker or {};local id=sdk['ORBWALKER_MODE_'..name]
    local list=id and orb.MenuKeys and orb.MenuKeys[id];local labels,seen={},{}
    for _,node in ipairs(list or {}) do
        local key=node.Key and node:Key()
        if key and key~=0 and not seen[key] then labels[#labels+1]=U.keyLabel(key);seen[key]=true end
    end
    return #labels>0 and table.concat(labels,' / ') or 'see orbwalker menu'
end
function G:page(index)
    local c=self.ctx;local cfg=c.config
    local function key(name)return U.keyLabel(cfg:key(name))end
    local function state(name)return cfg:get(name) and 'ON' or 'OFF'end
    local ward,preview=key('wardKey'),key('insecPreviewKey')
    local pages={
        {'Current bindings and active assists',{
            {'STANDARD MODES','Combo: '..self:modeKey('COMBO')..'   |   Harass: '..self:modeKey('HARASS')..'\nLane clear: '..self:modeKey('LANECLEAR')..'\nJungle clear: '..self:modeKey('JUNGLECLEAR')..'   |   Last hit: '..self:modeKey('LASTHIT')},
            {'LEE SIN','Wardjump: '..ward..'   |   Q1 assist: '..key('qAssistKey')..'\nCursor Insec: '..key('cursorKey')..'   |   Team Insec: '..key('allyKey')..'\nInsec preview: also hold '..preview..'.'},
            {'BACKGROUND','Auto-jungle: '..key('autoJungleKey')..' ['..state('autoJungle')..']\nAutosmite: '..key('smiteKey')..' ['..state('autosmite')..']\nOpening this guide does not pause gameplay or assists.'}},
            'Change these keys under Guide > Key bindings or in the matching feature menu.'},
        {'Jump directly toward your cursor',{
            {'01  AIM','Place your cursor on clear ground within reach. Tap and release '..ward..'. A straightforward jump needs no minimum hold time.'},
            {'02  JUMP','Lee reuses a suitable nearby W target when possible. Otherwise, he places an available ward and follows with W. W1, energy, range and a valid target must all be available.'},
            {'03  FOLLOW THROUGH','Right-click cancels remaining wardjump steps. "Move toward cursor after jump" ['..state('wardFollowCursor')..'] sends one movement command toward your latest cursor position after the jump.'}},
            'Tap for a direct jump. At a wall, wait for a valid preview first.'},
        {'Prepare one jump with wall assistance or an approach',{
            {'HOLD TO PLAN','Hold '..ward..' and aim at the wall you want to cross. Green means a direct jump; yellow means a valid assisted landing or approach. Do not confirm a red preview or "planning".'},
            {'RELEASE TO COMMIT','Releasing accepts the shown plan if it is still valid. Approach assistance ['..state('wardApproach')..'] lets Lee walk into range first. A briefly occupied cursor can make that one request wait.'},
            {'RE-AIM OR CANCEL','Before ward placement, holding again replans. After the ward input was sent, pressing again continues that same jump. Right-click cancels. Only one jump is queued at a time.'}},
            'Changed terrain conditions, unavailable W or an invalid ward can stop the plan. Success is not guaranteed.'},
        {'Choose the target and where to kick it',{
            {'CURSOR INSEC  '..key('cursorKey'),'Select an enemy with the orbwalker, then hold this key. Your cursor sets the kick direction. If mouse fallback is enabled, an enemy near the cursor can be used when nothing is selected.'},
            {'MOVE OR CANCEL','Right-click still controls movement while you hold Insec. The intention stays active and replans from your new position. Releasing the Insec key cancels the remaining steps.'},
            {'LOCK THE DIRECTION','"Lock kick direction" can lock on press, when the approach commits, or keep tracking until the kick. Current choice: '..({'on press','when the approach commits','track until the kick'})[cfg:get('aimLock') or 2]..'. Keep holding while waiting for a valid plan.'}},
            'The kick arrow shows where the enemy will travel.'},
        {'Team Insec  '..key('allyKey'),{
            {'FRIENDLY TURRETS','Turret priority ['..state('insecPreferStructures')..'] prefers a living friendly turret when the predicted landing is inside its range. Simply kicking toward a turret is not enough.'},
            {'ALLIES AND FALLBACK','Otherwise, Lee chooses a valid nearby ally and considers nearby threats. With no recipient, the destination is your position when you started holding the key. Dead recipients are excluded.'},
            {'TRACKING AND BASE','Ally tracking ['..state('insecTrackAlly')..'] follows the recipient before direction locks. The base option ['..state('insecBasePlatform')..'] also allows a landing deep inside a known friendly base platform.'}},
            'A turret or platform landing does not guarantee a kill.'},
        {'Inspect the route before allowing it',{
            {'PREVIEW','Hold '..preview..' together with '..key('cursorKey')..' or '..key('allyKey')..'. Check the target, kick arrow and listed steps. Release only '..preview..' while continuing to hold Insec.'},
            {'FLASH','"Allow Flash" ['..state('insecFlash')..'] enables proposals. Confirming a preview permits its shown Flash. Without a preview, fallback ['..state('insecFlashFallback')..'] requires no ready ward and no W step already committed.'},
            {'APPROACH TOOLS','Allowed Q, W and Flash steps can be combined. Q bridges use another enemy, minion or camp as an intermediate target. W and wards are planned around reaching a valid final kick position.'}},
            'If no complete route is shown, hold '..preview..' again to review the preview.'},
        {'Fight with the resources you have allowed',{
            {'SPELLS AND PASSIVE','Q1/Q2, W1/W2, E1/E2 and R have separate switches. Combo Q2 is '..state('comboQ2')..'. Lee weaves useful passive attacks, but a timely lethal finish can take priority.'},
            {'CHASE','Lee compares walking with a wardjump. A chase ward needs a clear time advantage; E2 can slow the target first. Reserving W keeps mobility available. Ordinary Combo Q2 turret safety is '..state('q2Safety')..'.'},
            {'KICKS','Multikick counts the primary target: '..tostring(cfg:get('multiHits'))..' means the target plus '..tostring((cfg:get('multiHits') or 3)-1)..' extra hits. Collateral kills, saving R, isolation and marked R > Q2 follow-up are separate options.'}},
            'Idle multikick ['..state('autoMultiR')..'] can kick without a held Combo, but does not reposition for it.'},
        {'Harass, Q assistance and automatic recasts',{
            {'TARGETED ASSISTANCE','Harass ['..self:modeKey('HARASS')..'] has its own spell permissions. Hold '..key('qAssistKey')..' for Q1 assistance only. "Only the selected enemy" restricts champion Q1 to the orbwalker selection.'},
            {'SHIELDS AND RECASTS','Defensive W is '..state('idleDefense')..'. Reserved W stays available for mobility or a lifesaving shield. Expiry W2 and expiry E2 can recast before their windows close, while respecting the energy reserve.'},
            {'KILLSTEAL','Q1, Q2, E and R have separate permissions. Q2 killsteal ['..state('killQ2')..'] is a dash and needs your own valid Q mark. An expected hit is not a confirmed mark.'}},
            'Under Orbama, eligible held Combo/Harass casts can survive ordinary movement commands.'},
        {'Local clearing and last-hitting have different goals',{
            {'LAST HIT','With '..self:modeKey('LASTHIT')..', enabled Q/W/E rescue CS you would otherwise miss. This mode avoids simply softening the wave and accounts for known incoming attacks.'},
            {'WAVECLEAR','With '..self:modeKey('LANECLEAR')..', E can prepare safe area damage. Optional Harass gives last hits priority. Gold priority helps choose when not every minion can be reached.'},
            {'JUNGLE CLEAR','With '..self:modeKey('JUNGLECLEAR')..', Lee clears a nearby camp without starting a route. The Q2 range limit saves long dashes during clearing. W1/W2 for passive and sustain remain separately configurable.'}},
            'Lane and jungle bindings come from your active orbwalker and can be shared or separate.'},
        {'Start a route from the camp you choose',{
            {'START AND STOP','Press '..key('autoJungleKey')..' near your chosen camp. Routing favors your side according to your settings. Pressing again, manual clicks or entering a combat mode stops it. Reloading always leaves it off.'},
            {'TRAVEL AND CAMPS','Q can shorten travel. Fog probes test known camps; a missed Q alone does not prove a stolen camp. Kiting moves between safe attacks while staying near the camp. Routing does not start bosses on its own.'},
            {'RECOVERY AND CAMERA','Lee finishes a camp if survivable or escapes before recalling. Routing stays enabled through recovery. Camera follow uses your lock key '..key('farmCameraKey')..'; manual camera input takes priority.'}},
            'Route and approach settings are under Auto-jungle. There is no shopping automation.'},
        {'Autosmite also works without a held mode',{
            {'AUTOSMITE  '..key('smiteKey'),'The toggle is '..state('autosmite')..'. Eligible visible objectives in range are checked against their current lethal HP. Selecting a champion does not block objective Smite.'},
            {'ORDINARY CAMPS','Camp Smite ['..state('smiteCamps')..'] also permits ordinary monsters in any mode. The HP margin adds a safety buffer, not extra Smite damage. Smite options are hidden when Smite is not equipped.'},
            {'Q + SMITE ASSIST  '..key('secureKey'),'Hold this optional key to prepare a visible epic with Q. Q2 requires a confirmed mark and enough Q2/Smite damage to finish. This assist only has a hotkey if you assign one.'}},
            'A valid Smite still needs a safe input opportunity.'},
        {'Use owned items and assign skill points',{
            {'ITEMS AND POTIONS','Item permissions cover targeted damage, cleave, slow, speed, QSS and shielding. Potions have Combat potions, Jungle-clear potions and Auto-jungle potions switches. The HP threshold and missing health also apply.'},
            {'IGNITE','Combo Ignite is '..state('comboIgnite')..'. "Ignite only when lethal" ['..state('igniteExecute')..'] restricts use to a predicted finish. Having the spell equipped alone does not authorize its use.'},
            {'AUTO LEVEL','Auto level is '..state('level')..'. It unlocks W, E, then Q; afterward it prioritizes Q, W, E and takes R when eligible. Wardjump, Insec and manually held modifier keys take priority.'}},
            'Only owned items are used. The script does not buy items.'},
        {'Choose which information stays on screen',{
            {'RANGES AND PREVIEWS','Q range, W range, E range, R range, Ward range and Status panel each have their own switches. Mode filters stay in the menu; Always takes priority. Wardjump preview and Insec preview also need a valid plan.'},
            {'DAMAGE','Green shows the conservative estimate; orange uses more allowed resources. Q, E, R, items, summoners and planned attacks are selectable. "partial" means some damage effects are not modeled.'},
            {'YOUR SETTINGS','Edit shortcuts in each feature menu or Guide > Key bindings. Orbwalker shortcuts update the original mode bindings. Advanced holds range, timing and safety margins. Guide > Text size adjusts this panel.'}},
            'Drawings do not execute actions. Keys and ON/OFF labels follow your current settings.'}
    }
    local page=pages[index] or pages[1]
    return {title=G.titles[index] or G.titles[1],subtitle=page[1],cards=page[2],note=page[3]}
end
function G:event(msg,key)
    local c=self.ctx;local cfg=c.config
    if msg==513 or msg==514 then return self:mouse(msg) end
    if msg~=256 and msg~=257 and msg~=260 and msg~=261 then return false end
    if c.synthetic or c.sdk.Input and c.sdk.Input:IsSyntheticEvent() then return false end
    local injected=c.injected and c.injected[key]
    if injected and c:now()<(injected.untilTime or (injected.at or 0)+.08) then return false end
    if msg==257 or msg==261 then
        local owned=self.down[key];self.down[key]=nil;return owned==true
    end
    if c:chatOpen() or Game.IsOnTop and not Game.IsOnTop() then self.down={};return false end
    local toggle=cfg:key('guideKey');local open=cfg:get('guideOpen')
    local previous,nextKey=cfg:key('guidePreviousKey'),cfg:key('guideNextKey')
    if key==0 or not (key==toggle or open and (key==previous or key==nextKey)) then return false end
    -- A help binding must not swallow a ward release or a combat-mode edge.
    if c.input:isModeKey(key) or key==cfg:key('farmCameraKey') then return false end
    for slot=0,5 do if c.actions:key(slot)==key then return false end end
    if self.down[key] then return true end
    self.down[key]=true
    self.mouseDown=nil;self.hits={}
    if key==toggle then cfg:set('guideOpen',not open)
    else
        local page=cfg:get('guidePage') or 1
        cfg:set('guidePage',(page-1+(key==nextKey and 1 or -1))%#G.titles+1)
    end
    return true
end
function G:mouse(msg)
    local c=self.ctx;local cfg=c.config
    if c.synthetic or c.sdk.Input and c.sdk.Input:IsSyntheticEvent()
        or c.sdk.NativeTransport and c.sdk.NativeTransport.InFlight
        or c.sdk.Cursor and c.sdk.Cursor.Step>0 then return false end
    if c:chatOpen() or Game.IsOnTop and not Game.IsOnTop() then self.mouseDown=nil;return false end
    local prior=self.mouseDown
    if msg==514 then self.mouseDown=nil end
    if not cfg:get('guideOpen') or self.hitPage~=cfg:get('guidePage') then return prior~=nil end
    local pointer=UI.pointer();local inside=UI.inside(pointer,self.panel)
    local hit
    for _,candidate in ipairs(self.hits or {}) do if UI.inside(pointer,candidate) then hit=candidate;break end end
    if msg==513 then
        self.mouseDown=inside and {link=hit and hit.link,page=self.hitPage} or nil
        return inside==true
    end
    if prior and hit and prior.page==self.hitPage and prior.link
        and prior.link.key==hit.link.key and prior.link.topic==hit.link.topic then
        local link=hit.link
        if link.close then cfg:set('guideOpen',false)
        elseif Links.activate(cfg,link) then
            if link.key=='autoJungle' or link.key=='autosmite' then
                local enabled=cfg:get(link.key);local owner=link.key=='autoJungle' and 'farm' or 'autosmite'
                c.actions:physicalIntent(owner,enabled)
                if not enabled then c.actions:cancel(owner) end
                if link.key=='autoJungle' then c.input.farmPaused=false;c.input.pressed.farmKey=enabled end
            end
        end
        self.content=nil;self.hits={}
    end
    return prior~=nil or inside==true
end
function G:draw()
    local c=self.ctx;local cfg=c.config
    if c:chatOpen() or Game.IsOnTop and not Game.IsOnTop() then self.down={};self.hits={};self.mouseDown=nil;return end
    if not cfg:get('guideOpen') or not Draw or not Draw.Rect or not Draw.Text or not Draw.Color then self.hits={};return end
    local size=Game.Resolution and Game.Resolution() or {x=1920,y=1080}
    local width,height=size.x or 1920,size.y or 1080
    local scale=math.min((width-32)/850,(height-32)/620,math.max(.8,math.min(1.4,height/1080))*(cfg:get('guideScale') or 100)/100)
    if scale<=0 then return end
    local x,y=math.floor((width-850*scale)/2),math.floor((height-620*scale)/2)
    local pageIndex=math.max(1,math.min(#G.titles,cfg:get('guidePage') or 1))
    local now=c:now()
    if not self.content or self.contentIndex~=pageIndex or now>=(self.contentAt or 0)+.2 then
        self.content=self:page(pageIndex);self.contentIndex=pageIndex;self.contentAt=now;self.spanCache={}
    end
    local page=self.content;local ui=UI.new(self,x,y,scale,pageIndex)
    ui:rect(5,7,850,620,{0,0,0},100);ui:rect(0,0,850,620,{13,21,29})
    ui:rect(0,0,850,3,{91,231,186});ui:rect(0,3,218,617,{18,29,38})
    ui:text('LEE HARVEY OSWARD',22,25,16,{91,231,186})
    ui:text('FIELD GUIDE',22,52,25,{237,244,248})
    ui:text('CLICK TO CONFIGURE',22,91,12,{139,184,255})
    for index,title in ipairs(G.titles) do
        local rowY=126+(index-1)*30
        local hover=ui:hit(12,rowY-4,194,28,{topic=index,label=title})
        if index==pageIndex or hover then ui:rect(12,rowY-4,194,28,index==pageIndex and {30,57,65} or {31,43,59}) end
        if index==pageIndex then ui:rect(12,rowY-4,3,28,{91,231,186}) end
        ui:text(string.format('%02d',index),23,rowY,12,index==pageIndex and {91,231,186} or {102,126,144})
        ui:text(title,48,rowY,13,index==pageIndex and {242,249,252} or {170,187,199})
    end
    local rules=Links.rules(pageIndex)
    ui:rich(page.title,244,25,575,25,rules,{237,244,248},true)
    local cursorY=66+ui:rich(page.subtitle,244,66,575,15,rules,{142,163,180},true)
    cursorY=math.max(110,cursorY+16)
    for index,card in ipairs(page.cards) do
        local cardRules=Links.rules(pageIndex,index)
        local h=ui:rich(card[2],252,0,558,14,cardRules,nil,false)
        local cardHeight=40+h
        ui:rect(236,cursorY,594,cardHeight,{21,33,44})
        ui:rich(card[1],252,cursorY+12,558,13,cardRules,{164,187,209},true)
        ui:rich(card[2],252,cursorY+33,558,14,cardRules,nil,true)
        cursorY=cursorY+cardHeight+10
    end
    local noteY=math.max(cursorY+3,526)
    ui:rich(page.note,244,noteY,575,13,rules,{180,195,211},true)
    ui:rect(218,576,632,1,{44,61,74})
    ui:text(ui:hint(),244,583,12,{139,184,255})
    local previous=(pageIndex-2)%#G.titles+1;local following=pageIndex%#G.titles+1
    ui:hit(240,601,150,18,{topic=previous,label='Previous topic'})
    ui:hit(404,601,150,18,{topic=following,label='Next topic'})
    ui:hit(690,601,130,18,{close=true,label='Close guide'})
    ui:text(U.keyLabel(cfg:key('guidePreviousKey'))..'  Previous',244,601,12,{163,184,198})
    ui:text(U.keyLabel(cfg:key('guideNextKey'))..'  Next',410,601,12,{163,184,198})
    ui:text(U.keyLabel(cfg:key('guideKey'))..'  Close',720,601,12,{91,231,186})
end
return G
