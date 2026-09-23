-- Contextual editors share the original native key node, including its save ID.
-- Mirrors have no ID: the host documents anonymous parameters as unsaved.
local B={};B.__index=B
local function read(node)
    if not node or type(node.Key)~='function' then return end
    local ok,key=pcall(node.Key,node)
    if ok and type(key)=='number' then return key end
end
local function write(node,key)
    if read(node)==key then return true end
    -- GoS native key parameters expose __key. Do not assume Key is a setter:
    -- several providers implement it as a getter only. Check both before/after.
    local old=read(node)
    if old==nil or node.__key~=old then return false end
    local ok=pcall(function()node.__key=key end)
    if ok and read(node)==key then return true end
    pcall(function()node.__key=old end)
    return false
end
function B.new(config,sdk)
    local self=setmetatable({config=config,entries={},nextSync=0},B)
    if not config.menu then return self end
    local menu=config.menu;local icon=require('lho.menuicons').new()
    menu.Guide:MenuElement({id='Bindings',name='Key bindings',type=MENU})
    local help=menu.Guide.Bindings
    local function branch(parent,id,name)
        if not parent[id] then parent:MenuElement({id=id,name=name,type=MENU,leftIcon=icon(id)}) end
        return parent[id]
    end
    local function editor(parent,node,label,semantic)
        if not parent or read(node)==nil then return end
        -- Unknown menu implementations keep their original editor; never show
        -- a second independent binding that cannot update the real input node.
        if node.__key~=read(node) then return end
        local entry={source=node,last=read(node)}
        local args={name=label,key=entry.last,leftIcon=icon(semantic),
            tooltip='Changes the same binding everywhere, including the original Controls menu.'}
        args.onKeyChange=function(key)
            if type(key)~='number' or key<0 or key%1~=0 then return end
            if write(node,key) then self:sync(true) end
        end
        entry.mirror=parent:MenuElement(args)
        if entry.mirror then self.entries[#self.entries+1]=entry end
    end
    local function own(parent,key,label,helpGroup)
        editor(parent,config.nodes[key],label,key)
        editor(branch(help,helpGroup,helpGroup),config.nodes[key],label,key)
    end
    own(menu.Wardjump,'wardKey','Hold / release wardjump','Wardjump')
    own(menu.Insec,'cursorKey','Hold: kick toward cursor','Insec')
    own(menu.Insec,'allyKey','Hold: kick toward team / turret','Insec')
    own(menu.Insec,'insecPreviewKey','Preview modifier','Insec')
    editor(menu.Drawings.Wardjump,config.nodes.wardKey,'Hold / release wardjump','wardKey')
    editor(menu.Drawings.Insec,config.nodes.cursorKey,'Hold: kick toward cursor','cursorKey')
    editor(menu.Drawings.Insec,config.nodes.allyKey,'Hold: kick toward team / turret','allyKey')
    editor(menu.Drawings.Insec,config.nodes.insecPreviewKey,'Preview modifier','insecPreviewKey')
    editor(menu.Insec.Flash,config.nodes.insecPreviewKey,'Preview / Flash modifier','insecPreviewKey')
    own(menu.Harass,'qAssistKey','Hold: Q1 assist','Assists')
    editor(menu.Assists,config.nodes.qAssistKey,'Hold: Q1 assist','qAssistKey')
    own(menu.Farming,'autoJungleKey','Toggle auto-jungle','Farming')
    editor(branch(help,'Farming','Farming'),config.nodes.farmCameraKey,'Camera lock key','farmCameraKey')
    own(menu.SmiteItems.Smite,'smiteKey','Toggle autosmite','Smite')
    own(menu.SmiteItems.Smite,'secureKey','Hold: Q + Smite objective assist','Smite')
    for _,row in ipairs({{'guideKey','Open / close guide'},{'guidePreviousKey','Previous topic'},
        {'guideNextKey','Next topic'}}) do
        editor(menu.Controls,config.nodes[row[1]],row[2],row[1])
        editor(branch(help,'Guide','Guide'),config.nodes[row[1]],row[2],row[1])
    end
    local modes={{'COMBO','Combat','Combo'},{'HARASS','Harass','Harass'},
        {'LANECLEAR','Wave','Lane clear'},{'JUNGLECLEAR','Jungle','Jungle clear'},
        {'LASTHIT','LastHit','Last hit'},{'FLEE','Controls','Flee'}}
    local orb=sdk and sdk.Orbwalker
    for _,row in ipairs(modes) do
        local id=sdk and sdk['ORBWALKER_MODE_'..row[1]]
        local nodes=orb and orb.MenuKeys and id~=nil and orb.MenuKeys[id]
        for index,node in ipairs(nodes or {}) do
            local label=row[3]..' key'..(index>1 and ' '..index or '')
            editor(menu[row[2]],node,label,row[2])
            editor(branch(help,'Modes','Orbwalker modes'),node,label,row[2])
        end
    end
    return self
end
function B:sync(force)
    local now=Game and Game.Timer and Game.Timer() or 0
    if not force and now<self.nextSync then return end
    self.nextSync=now+.1
    for _,entry in ipairs(self.entries) do
        local key=read(entry.source)
        if key~=nil and read(entry.mirror)~=key then write(entry.mirror,key) end
        entry.last=key
    end
end
return B
