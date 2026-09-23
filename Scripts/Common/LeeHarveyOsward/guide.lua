-- Read-only gameplay help. Navigation never sends input or starts an intention.
local U=require('lho.util')
local G={};G.__index=G
G.titles={'Schnellstart','Wardjump: tippen','Wardjump: planen','Insec: steuern','Insec: Team & Turm',
    'Insec: Vorschau','Combo & Verfolgung','Harass & Helfer','Lane & Jungle clear','Auto-jungle',
    'Smite & Objectives','Items & Skillpunkte','Anzeigen & Optionen'}
function G.new(ctx) return setmetatable({ctx=ctx,down={}},G) end
function G:modeKey(name)
    local sdk=self.ctx.sdk;local orb=sdk.Orbwalker or {};local id=sdk['ORBWALKER_MODE_'..name]
    local list=id and orb.MenuKeys and orb.MenuKeys[id];local labels,seen={},{}
    for _,node in ipairs(list or {}) do
        local key=node.Key and node:Key()
        if key and key~=0 and not seen[key] then labels[#labels+1]=U.keyLabel(key);seen[key]=true end
    end
    return #labels>0 and table.concat(labels,' / ') or 'im Orbwalker-Menue'
end
function G:page(index)
    local c=self.ctx;local cfg=c.config
    local function key(name)return U.keyLabel(cfg:key(name))end
    local function state(name)return cfg:get(name) and 'AN' or 'AUS'end
    local ward,preview=key('wardKey'),key('insecPreviewKey')
    local pages={
        {'Aktuelle Belegung und aktive Helfer',{
            {'STANDARDMODI','Combo: '..self:modeKey('COMBO')..'   |   Harass: '..self:modeKey('HARASS')..'\nLane clear: '..self:modeKey('LANECLEAR')..'\nJungle clear: '..self:modeKey('JUNGLECLEAR')..'   |   Last hit: '..self:modeKey('LASTHIT')},
            {'LEE SIN','Wardjump: '..ward..'   |   Q1-Hilfe: '..key('qAssistKey')..'\nCursor-Insec: '..key('cursorKey')..'   |   Team-Insec: '..key('allyKey')..'\nInsec-Vorschau: '..preview..' zusaetzlich halten.'},
            {'HINTERGRUND','Auto-jungle: '..key('autoJungleKey')..' ['..state('autoJungle')..']\nAutosmite: '..key('smiteKey')..' ['..state('autosmite')..']\nOeffnen des Guides pausiert das Spiel und die Helfer nicht.'}},
            'Tasten werden aus deinen aktuellen Menuebelegungen gelesen.'},
        {'Direkt zum Cursor springen',{
            {'01  ZIELEN','Cursor auf einen erreichbaren, freien Landepunkt setzen. '..ward..' kurz druecken und loslassen. Fuer einen einfachen Sprung ist keine Mindesthaltezeit noetig.'},
            {'02  SPRINGEN','Ein passendes nahes W-Ziel wird wiederverwendet. Sonst setzt Lee einen verfuegbaren Ward und folgt mit W. W1, Energie, Reichweite und ein gueltiges Ziel muessen passen.'},
            {'03  DANACH','Rechtsklick bricht den noch offenen Wardjump ab. "Move toward cursor after jump" ['..state('wardFollowCursor')..'] bewegt Lee danach einmal zum aktuellen Cursor.'}},
            'Tippen ist der direkte Weg. Fuer Mauern erst eine gueltige Vorschau abwarten.'},
        {'Einen Sprung mit Wandhilfe oder Anlauf vormerken',{
            {'HALTEN','Halte '..ward..' und ziele an die gewuenschte Mauer. Gruen zeigt einen direkten Sprung, Gelb eine gueltige Hilfe oder einen Anlauf. Rot oder "planning" noch nicht bestaetigen.'},
            {'AUFTRAG UEBERNEHMEN','Loslassen uebernimmt den angezeigten, weiterhin gueltigen Plan. Mit Anlaufhilfe ['..state('wardApproach')..'] laeuft Lee erst in Reichweite. Ein kurz belegter Cursor kann den Sprung begrenzt warten lassen.'},
            {'NEU ZIELEN ODER ABBRECHEN','Vor der Wardplatzierung plant erneutes Halten neu. Nach gesendetem Ward setzt erneutes Druecken denselben Sprung fort. Rechtsklick bricht ab. Es wird nur ein Sprung vorgemerkt.'}},
            'Keine Erfolgsgarantie: geaenderte Geometrie, fehlendes W oder ein ungueltiger Ward stoppen den Plan.'},
        {'Du waehlst das Ziel und die Kickrichtung.',{
            {'CURSOR-INSEC  '..key('cursorKey'),'Gegner im Orbwalker auswaehlen, dann die Taste halten. Der Cursor gibt die gewuenschte Kickrichtung an. Ohne Auswahl kann ein Gegner nahe am Cursor dienen, wenn der Fallback aktiviert ist.'},
            {'BEWEGEN UND ABBRECHEN','Solange die Insec-Taste gehalten wird, steuerst du mit Rechtsklick die Bewegung weiter. Der Insec bleibt aktiv und plant neu. Loslassen beendet die noch offenen Schritte.'},
            {'RICHTUNG FESTLEGEN','"Lock kick direction": beim Druecken, beim verbindlichen Ansatz oder laufend bis zum Kick. Aktuell: '..({'beim Druecken','beim Ansatz','bis zum Kick nachfuehren'})[cfg:get('aimLock') or 2]..'. Ohne passenden Plan kannst du weiter halten.'}},
            'Der Kickpfeil zeigt die Flugrichtung des Gegners, nicht Lees Anlaufrichtung.'},
        {'Team-Insec  '..key('allyKey'),{
            {'FREUNDLICHE TUERME','Mit Turmprioritaet ['..state('insecPreferStructures')..'] gewinnt ein lebender eigener Turm, wenn die berechnete Landung in seiner Reichweite liegt. Nur in Richtung Turm zu kicken reicht nicht.'},
            {'ALLIIERTE UND RUECKFALL','Sonst waehlt Lee einen gueltigen nahen Verbuendeten und beruecksichtigt Gefahren in dessen Naehe. Ohne Empfaenger gilt deine Position beim Beginn des Haltens. Tote Empfaenger fallen weg.'},
            {'NACHFUEHREN UND BASIS','Ally-Tracking ['..state('insecTrackAlly')..'] folgt dem Empfaenger vor der Richtungsbindung. Die Basisoption ['..state('insecBasePlatform')..'] erlaubt auch eine Landung tief auf einer bekannten eigenen Plattform.'}},
            'Turm- oder Plattformlandung beschreibt die Geometrie, keinen garantierten Kill.'},
        {'Erst den Weg pruefen, dann freigeben.',{
            {'VORSCHAU','Halte '..preview..' zusammen mit '..key('cursorKey')..' oder '..key('allyKey')..'. Pruefe Ziel, Kickpfeil und angezeigte Schritte. Lass nur '..preview..' los, waehrend du Insec weiter haeltst.'},
            {'FLASH','"Allow Flash" ['..state('insecFlash')..'] erlaubt Vorschlaege. Eine bestaetigte Vorschau darf den gezeigten Flash nutzen. Ohne Vorschau gilt der Fallback ['..state('insecFlashFallback')..'] nur ohne bereiten Ward und ohne bereits gebundenen W-Schritt.'},
            {'ANLAUF','Erlaubte Q-, W- und Flash-Schritte koennen kombiniert werden. Q-Bruecken nutzen andere Gegner, Minions oder Camps als Zwischenziel. W und Ward werden fuer eine erreichbare Kickposition eingeplant.'}},
            'Kein sichtbarer vollstaendiger Plan? '..preview..' erneut halten und die Vorschau pruefen.'},
        {'Kaempfen mit deinen Ressourcenfreigaben.',{
            {'SPELLS UND PASSIVE','Q1/Q2, W1/W2, E1/E2 und R sind einzeln schaltbar. Q2-Combo ist aktuell '..state('comboQ2')..'. Passive-Angriffe werden verwoben; ein rechtzeitiger toedlicher Abschluss kann Vorrang bekommen.'},
            {'VERFOLGUNG','Lee vergleicht Laufen und Wardjump. Ein Chase-Ward braucht einen klaren Zeitvorteil; E2 kann vorher bremsen. W-Reservierung spart Mobilitaet. Die normale Combo-Q2-Turmpruefung ist '..state('q2Safety')..'.'},
            {'KICKS','Multikick zaehlt den gekickten Gegner mit: '..tostring(cfg:get('multiHits'))..' bedeutet Ziel plus '..tostring((cfg:get('multiHits') or 3)-1)..' weitere Treffer. Kollateral-Kills, R sparen, Isolation und markiertes R > Q2 sind getrennte Optionen.'}},
            'Idle-Multikick ['..state('autoMultiR')..'] darf ohne gehaltene Combo kicken, aber nicht dafuer repositionieren.'},
        {'Harass, Q-Hilfe und automatische Recasts.',{
            {'GEZIELT HELFEN','Harass ['..self:modeKey('HARASS')..'] hat eigene Spellfreigaben. '..key('qAssistKey')..' halten hilft nur mit Q1. "Only the selected enemy" begrenzt Champion-Q1 auf die Orbwalker-Auswahl.'},
            {'SCHUTZ UND RECASTS','Defensives W ist '..state('idleDefense')..'. Reserviertes W bleibt fuer Mobilitaet oder einen lebensrettenden Schild frei. Ablaufhilfe kann W2 und E2 vor Ablauf verwenden; sie beachtet die Energiereserve.'},
            {'KILLSTEAL','Q1, Q2, E und R haben getrennte Freigaben. Q2-Killsteal ['..state('killQ2')..'] ist ein Dash und benoetigt eine eigene gueltige Q-Markierung. Ein noch nicht beobachteter Treffer gilt nicht als Markierung.'}},
            'Gueltige gehaltene Combo-/Harass-Casts koennen unter Orbama normale Bewegung ueberstehen.'},
        {'Lokales Clear und Last Hit bleiben getrennt.',{
            {'LAST HIT','Unter '..self:modeKey('LASTHIT')..' retten aktivierte Q/W/E sonst verpasste CS. Der Modus soll die Wave nicht einfach anschaedigen. Bekannte anfliegende Angriffe werden beruecksichtigt.'},
            {'WAVECLEAR','Unter '..self:modeKey('LANECLEAR')..' darf E sichere Flaechentreffer vorbereiten. Optionales Harass hat Nachrang vor Last Hits. Goldprioritaet hilft, wenn nicht alle Minions erreichbar sind.'},
            {'JUNGLE CLEAR','Unter '..self:modeKey('JUNGLECLEAR')..' bearbeitet Lee ein nahes Camp, ohne Route zu starten. Q2-Reichweitenlimit spart lange Dashes beim Clear. W1/W2 fuer Passive und Sustain bleiben separat erlaubt.'}},
            'Lane- und Jungle-Tasten kommen vom aktiven Orbwalker. Sie duerfen gleich oder getrennt sein.'},
        {'Eine bewusste Route statt automatischem Loslaufen.',{
            {'START UND STOPP','Neben deinem gewuenschten Camp '..key('autoJungleKey')..' druecken. Die Route bevorzugt je nach Einstellung eigene Camps. Erneutes Druecken, manuelle Klicks oder ein Kampfmodus stoppen sie. Nach Reload ist sie aus.'},
            {'UNTERWEGS','Q kann den Weg abkuerzen. Fog-Probes testen bekannte Camps; ein verfehltes Q beweist keinen Diebstahl. Kiting bewegt zwischen sicheren Angriffen und bleibt beim Camp. Bosse werden nicht autonom begonnen.'},
            {'ERHOLUNG UND KAMERA','Bei Gefahr kaempft Lee weiter, wenn das Ende ueberlebbar ist, oder flieht vor dem Recall. Die Route bleibt durch Erholung erhalten. Kamera-Follow nutzt deine Lock-Taste '..key('farmCameraKey')..'; manuelle Kameraeingabe hat Vorrang.'}},
            'Die Routen- und Anlaufoptionen stehen unter Auto-jungle. Es gibt keine Kaufautomation.'},
        {'Autosmite arbeitet auch ohne gehaltenen Modus.',{
            {'AUTOSMITE  '..key('smiteKey'),'Der Schalter ist aktuell '..state('autosmite')..'. Ein geeignetes sichtbares Objective in Reichweite wird bei aktuell toedlichen HP geprueft. Ein ausgewaehlter Champion blockiert das nicht.'},
            {'NORMALE CAMPS','Camp-Smite ['..state('smiteCamps')..'] erlaubt auch normale Monster in allen Modi. Die HP-Marge ist eine zusaetzliche Reserve; sie erhoeht nicht den Smite-Schaden. Ohne ausgeruesteten Smite sind die Optionen ausgeblendet.'},
            {'Q + SMITE ASSIST  '..key('secureKey'),'Die optionale Taste halten, um ein sichtbares Epic mit Q vorzubereiten. Q2 braucht eine bestaetigte Markierung und einen ausreichenden Q2-/Smite-Abschluss. Die Taste ist nur aktiv, wenn du sie belegst.'}},
            'Ein gueltiger Smite braucht weiterhin einen freien, sicheren Eingabezeitpunkt.'},
        {'Vorhandene Items nutzen, Skills automatisch steigern.',{
            {'ITEMS UND TRAENKE','Itemfreigaben trennen Schaden, Cleave, Slow, Tempo, QSS und Schild. Potions haben eigene Freigaben fuer Kampf, Jungle clear und Auto-jungle sowie eine HP-Schwelle. Fehlende Gesundheit wird mitgeprueft.'},
            {'IGNITE','Combo-Ignite ist '..state('comboIgnite')..'. "Ignite only when lethal" ['..state('igniteExecute')..'] begrenzt die Nutzung auf einen berechneten Abschluss. Ein vorhandener Spell allein ist keine Freigabe.'},
            {'AUTO LEVEL','Auto level ist '..state('level')..'. Zuerst werden W, E, Q freigeschaltet; danach Q vor W vor E, R bei verfuegbarem Rang. Wardjump, Insec und manuell gehaltene Modifiertasten haben Vorrang.'}},
            'Nur vorhandene Items werden verwendet. Das Skript kauft keine Items.'},
        {'Nur die Informationen einblenden, die du brauchst.',{
            {'REICHWEITEN UND VORSCHAU','Jede Anzeige hat Enabled, Always und eigene Modusfilter. Always hat Vorrang. Q ist standardmaessig nur in Harass sichtbar. Eine Wardjump-/Insec-Vorschau braucht zusaetzlich einen tatsaechlichen Plan.'},
            {'SCHADEN','Gruen zeigt die konservative Schaetzung, Orange die Variante mit mehr Ressourcen. Q, E, R, Items, Summoner und geplante Angriffe sind waehlbar. "partial" bedeutet, dass nicht alle Schadensanteile modelliert sind.'},
            {'DEIN SETUP','Controls aendert nur LHO-Sondertasten; Standardmodi stellst du im Orbwalker ein. Advanced enthaelt Reichweiten-, Zeit- und Sicherheitsabstaende. Guide > Textgroesse passt diese Leseflaeche an.'}},
            'Die Anzeige fuehrt nichts aus. Alle Tasten und AN/AUS-Angaben folgen deinen aktuellen Einstellungen.'}
    }
    local page=pages[index] or pages[1]
    return {title=G.titles[index] or G.titles[1],subtitle=page[1],cards=page[2],note=page[3]}
end
function G:event(msg,key)
    local c=self.ctx;local cfg=c.config
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
    if key==toggle then cfg:set('guideOpen',not open)
    else
        local page=cfg:get('guidePage') or 1
        cfg:set('guidePage',(page-1+(key==nextKey and 1 or -1))%#G.titles+1)
    end
    return true
end
local function wrap(text,limit)
    local lines={}
    for paragraph in (text..'\n'):gmatch('(.-)\n') do
        local line=''
        for word in paragraph:gmatch('%S+') do
            if #line>0 and #line+#word+1>limit then lines[#lines+1]=line;line=word
            else line=line=='' and word or line..' '..word end
        end
        lines[#lines+1]=line
    end
    return lines
end
function G:draw()
    local c=self.ctx;local cfg=c.config
    if c:chatOpen() or Game.IsOnTop and not Game.IsOnTop() then self.down={};return end
    if not cfg:get('guideOpen') or not Draw or not Draw.Rect or not Draw.Text or not Draw.Color then return end
    local size=Game.Resolution and Game.Resolution() or {x=1920,y=1080}
    local width,height=size.x or 1920,size.y or 1080
    local scale=math.min((width-32)/850,(height-32)/620,math.max(.8,math.min(1.4,height/1080))*(cfg:get('guideScale') or 100)/100)
    if scale<=0 then return end
    local x,y=math.floor((width-850*scale)/2),math.floor((height-620*scale)/2)
    local function rect(px,py,w,h,r,g,b,a)Draw.Rect(math.floor(x+px*scale),math.floor(y+py*scale),math.ceil(w*scale),math.ceil(h*scale),Draw.Color(a or 250,r,g,b))end
    local function text(s,px,py,font,r,g,b)Draw.Text(s,math.max(10,math.floor(font*scale)),math.floor(x+px*scale),math.floor(y+py*scale),Draw.Color(255,r,g,b))end
    local pageIndex=math.max(1,math.min(#G.titles,cfg:get('guidePage') or 1))
    local now=c:now()
    if not self.content or self.contentIndex~=pageIndex or now>=(self.contentAt or 0)+.2 then
        self.content=self:page(pageIndex);self.contentIndex=pageIndex;self.contentAt=now
    end
    local page=self.content
    rect(5,7,850,620,0,0,0,100);rect(0,0,850,620,13,21,29)
    rect(0,0,850,3,67,221,174);rect(0,3,218,617,18,29,38)
    text('LEE HARVEY OSWARD',22,25,16,67,221,174)
    text('SPIELGUIDE',22,52,25,237,244,248)
    text(c.profile.id=='classic' and 'CLASSIC' or 'NORMAL',22,91,12,142,163,180)
    for index,title in ipairs(G.titles) do
        local rowY=126+(index-1)*30
        if index==pageIndex then rect(12,rowY-4,194,28,30,57,65);rect(12,rowY-4,3,28,67,221,174) end
        text(string.format('%02d',index),23,rowY,12,index==pageIndex and 67 or 102,index==pageIndex and 221 or 126,index==pageIndex and 174 or 144)
        text(title,48,rowY,13,index==pageIndex and 242 or 170,index==pageIndex and 249 or 187,index==pageIndex and 252 or 199)
    end
    text(page.title,244,25,25,237,244,248)
    local cursorY=66
    for _,line in ipairs(wrap(page.subtitle,61)) do text(line,244,cursorY,15,142,163,180);cursorY=cursorY+20 end
    cursorY=math.max(110,cursorY+16)
    for _,card in ipairs(page.cards) do
        local lines=wrap(card[2],66);local cardHeight=40+#lines*18
        rect(236,cursorY,594,cardHeight,21,33,44)
        text(card[1],252,cursorY+12,13,67,221,174)
        for index,line in ipairs(lines) do text(line,252,cursorY+33+(index-1)*18,14,222,233,242) end
        cursorY=cursorY+cardHeight+10
    end
    local noteY=math.max(cursorY+3,535)
    for _,line in ipairs(wrap(page.note,70)) do text(line,244,noteY,13,243,195,113);noteY=noteY+17 end
    rect(218,583,632,1,44,61,74)
    text(U.keyLabel(cfg:key('guidePreviousKey'))..' / '..U.keyLabel(cfg:key('guideNextKey'))..'  Thema wechseln',244,594,13,163,184,198)
    text(U.keyLabel(cfg:key('guideKey'))..'  Schliessen',670,594,13,67,221,174)
end
return G
