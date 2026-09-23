-- Explicit feature names keep a mention tied to the setting it describes.
local L={}
local common={
    {'autoJungle','Auto-jungle','Routing'}, {'autosmite','Autosmite'},
    {'wardFollowCursor','Move toward cursor after jump'}, {'wardApproach','Approach assistance'},
    {'wardAssist','wall assistance'}, {'insecMouseTarget','mouse fallback'},
    {'aimLock','Lock kick direction'}, {'insecPreferStructures','Turret priority','friendly turrets'},
    {'insecTrackAlly','Ally tracking'}, {'insecBasePlatform','base option'},
    {'insecFlash','Allow Flash'},
    {'insecBridges','Q bridges'}, {'insecChains','combined'},
    {'comboPassive','passive attacks'}, {'comboBurst','timely lethal finish'},
    {'comboWard','chase ward'}, {'comboChaseE2','E2 can slow'},
    {'reserveW','Reserving W','Reserved W'}, {'q2Safety','Q2 turret safety'},
    {'multi','Multikick'}, {'autoMultiR','Idle multikick'}, {'collateralKills','Collateral kills'},
    {'comboConserveR','saving R'}, {'comboIsolate','isolation'}, {'comboKickFollow','marked R > Q2 follow-up'},
    {'qOnlySelected','Only the selected enemy'}, {'idleDefense','Defensive W'},
    {'expiryW','Expiry W2'}, {'expiryE','expiry E2'},
    {'killQ2','Q2 killsteal'}, {'waveHarass','Optional Harass'}, {'csGoldPriority','Gold priority'},
    {'jungleQ2MeleeOnly','Q2 range limit'}, {'farmQTravel','Q can shorten travel'},
    {'farmQBlind','Fog probes'}, {'farmKite','Kiting'}, {'farmFollowCamera','Camera follow'},
    {'smiteCamps','Camp Smite'}, {'comboIgnite','Combo Ignite'}, {'igniteExecute','Ignite only when lethal'},
    {'level','Auto level'}, {'damageSafe','conservative estimate'}, {'damageMax','more allowed resources'},
    {'draw','Drawings'}, {'items','Item permissions'}, {'potions','Potions'},
    {'potionFight','Combat potions'}, {'potionJungle','Jungle-clear potions'}, {'potionAuto','Auto-jungle potions'},
    {'drawQRange','Q range'}, {'drawWRange','W range'}, {'drawERange','E range'}, {'drawRRange','R range'},
    {'drawWardRange','Ward range'}, {'drawHUD','Status panel'},
}
local contextual={
    [6]={{'insecQ','Q'},{'insecW','W'},{'insecFlash','Flash'},{'insecFlashFallback','fallback'}},
    [7]={{'comboQ','Q1'},{'comboQ2','Q2'},{'comboW','W1'},{'comboW2','W2'},
        {'comboE','E1'},{'comboE2','E2'},{'comboR','R'}},
    [8]={{'expiryW','W2'},{'expiryE','E2'},{'killQ','Q1'},{'killE','E'},{'killR','R'}},
    [9]={{'lastAbilities','LAST HIT'},{'waveAbilities','WAVECLEAR'},{'jungleAbilities','JUNGLE CLEAR'},
        {'waveSoften','safe area damage'},{'jungleW','W1/W2'}},
    [12]={{'itemTargeted','targeted damage'},{'itemCleave','cleave'},{'itemSlow','slow'},
        {'itemSpeed','speed'},{'itemCleanse','QSS'},{'itemShield','shielding'}},
    [13]={{'drawQRange','Q defaults'},{'drawWard','Wardjump preview','Wardjump'},{'drawInsec','Insec preview','Insec'},
        {'damageBars','DAMAGE'},{'damageQ','Q'},{'damageE','E'},{'damageR','R'},
        {'damageItems','items'},{'damageSummoners','summoners'}},
}
local topics={{2,'Wardjump'},{4,'Cursor Insec','Insec'},{5,'Team Insec'},
    {6,'Insec preview','preview modifier'},{7,'Combo'},{8,'Harass','Q1 assist','Q1 assistance','Killsteal'},
    {9,'Lane clear','Jungle clear','Last hit','Waveclear'},{11,'Q + Smite assist'},
    {12,'Items & leveling'}}
local cache={}
function L.rules(page,card)
    local cacheKey=page*10+(card or 0)
    if cache[cacheKey] then return cache[cacheKey] end
    local result={}
    local function add(rows,topic)
        for _,row in ipairs(rows or {}) do for i=2,#row do
            result[#result+1]={label=row[i],key=not topic and row[1] or nil,topic=topic and row[1] or nil,order=#result+1}
        end end
    end
    -- Spell names in Harass and farming paragraphs must use that mode's switches.
    if page==8 and card==1 then
        add({{'harassQ','Q1'},{'harassQ2','Q2'},{'harassW','W1'},{'harassW2','W2'},
            {'harassE','E1'},{'harassE2','E2'},{'harassR','R'}})
    elseif page==9 then
        local prefix=card==1 and 'last' or card==2 and 'wave' or 'jungle'
        add({{prefix..'Q','Q'},{prefix..'W','W'},{prefix..'E','E'}})
    end
    add(contextual[page]);add(common);add(topics,true)
    table.sort(result,function(a,b)return #a.label==#b.label and a.order<b.order or #a.label>#b.label end)
    cache[cacheKey]=result
    return result
end
function L.spans(text,rules)
    local spans={};local lower=text:lower();local at=1;local plain=''
    local function flush()if plain~='' then spans[#spans+1]={text=plain};plain='' end end
    while at<=#text do
        local match
        for _,rule in ipairs(rules) do
            local last=at+#rule.label-1
            if lower:sub(at,last)==rule.label:lower()
                and (at==1 or not lower:sub(at-1,at-1):match('[%w_]'))
                and (last==#text or not lower:sub(last+1,last+1):match('[%w_]')) then match=rule;break end
        end
        if match then
            flush();spans[#spans+1]={text=text:sub(at,at+#match.label-1),link=match};at=at+#match.label
        else plain=plain..text:sub(at,at);at=at+1 end
    end
    flush();return spans
end
function L.active(cfg,link)
    if not link.key then return nil end
    local value=cfg:get(link.key)
    if link.key=='drawQRange' then return value~=1 end
    if link.key=='aimLock' then return nil end
    return type(value)=='boolean' and value or false
end
function L.activate(cfg,link)
    if link.topic then cfg:set('guidePage',link.topic);return true end
    local key=link.key;local value=cfg:get(key)
    if key=='aimLock' then cfg:set(key,(value or 1)%3+1);return true end
    if key=='drawQRange' then
        -- The legacy numeric setter resets mode filters. Keep those independent
        -- choices when the guide changes only the Enabled switch.
        local options=cfg.drawingOptions and cfg.drawingOptions[key];local saved={}
        for name,node in pairs(options or {}) do saved[name]=node:Value() end
        cfg:set(key,value==1 and 2 or 1)
        for name,setting in pairs(saved) do options[name]:Value(setting) end
        return true
    end
    if type(value)=='boolean' then cfg:set(key,not value);return true end
    return false
end
return L
