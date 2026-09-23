-- Startup-only setting migration. Never edits the host's shared save file.
local M={saved={},icons={}}
-- Host save files are data, not executable modules. In particular, do not use
-- setfenv/loadfile here: restricted hosts may reject environment mutation.
function M:ParseSaveContent(text)
    if type(text)~='string' or #text>2097152 then return nil,'save_size' end
    local i,nodes=1,0
    if text:sub(1,3)=='\239\187\191' then i=4 end
    local function space()
        while true do
            local _,last=text:find('^%s*',i);i=(last or i-1)+1
            if text:sub(i,i+1)~='--' then return end
            if text:sub(i+2,i+3)=='[[' then
                local close=text:find(']]',i+4,true);assert(close,'unfinished comment');i=close+2
            else local close=text:find('\n',i+2,true);i=close and close+1 or #text+1 end
        end
    end
    local function take(token)space();assert(text:sub(i,i+#token-1)==token,'invalid save token');i=i+#token end
    local function quoted()
        local quote=text:sub(i,i);i=i+1;local out={}
        while i<=#text do
            local char=text:sub(i,i);i=i+1
            if char==quote then return table.concat(out) end
            if char=='\\' then
                char=text:sub(i,i);i=i+1
                local escapes={a='\a',b='\b',f='\f',n='\n',r='\r',t='\t',v='\v',['\\']='\\',['"']='"',["'"]="'"}
                if char:match('%d') then
                    local digits=char
                    for _=1,2 do local nextChar=text:sub(i,i);if not nextChar:match('%d')then break end;digits=digits..nextChar;i=i+1 end
                    local byte=tonumber(digits);assert(byte<=255,'invalid escape');char=string.char(byte)
                else char=assert(escapes[char],'unsupported escape') end
            end
            out[#out+1]=char
        end
        error('unfinished string')
    end
    local value
    value=function(depth)
        nodes=nodes+1;assert(depth<=32 and nodes<=100000,'save_complexity');space()
        local char=text:sub(i,i)
        if char=='{' then
            i=i+1;local result={};space()
            while text:sub(i,i)~='}' do
                take('[');local key=value(depth+1)
                assert(type(key)=='string' or type(key)=='number','invalid save key')
                take(']');take('=');result[key]=value(depth+1);space()
                if text:sub(i,i)==',' or text:sub(i,i)==';'then i=i+1;space()
                else assert(text:sub(i,i)=='}','missing separator') end
            end
            i=i+1;return result
        elseif char=='"' or char=="'" then return quoted()
        elseif text:sub(i,i+3)=='true' then i=i+4;return true
        elseif text:sub(i,i+4)=='false' then i=i+5;return false
        elseif text:sub(i,i+2)=='nil' then i=i+3;return nil
        end
        local literal=text:match('^[+-]?%d+%.?%d*[eE][+-]?%d+',i) or text:match('^[+-]?%d+%.?%d*',i)
        local number=literal and tonumber(literal)
        assert(number and number==number and math.abs(number)~=math.huge,'invalid save value')
        i=i+#literal;return number
    end
    local ok,result=pcall(function()take('return');local result=value(0);space();assert(i>#text and type(result)=='table','invalid save root');return result end)
    if ok then return result end
    return nil,tostring(result)
end
do
    local base=COMMON_PATH or (SCRIPT_PATH and SCRIPT_PATH..'Common/')
    if base and io and type(io.open)=='function' then
        if not base:match('[/\\]$') then base=base..'/' end
        local ok,file=pcall(io.open,base..'MenuElement.save','rb')
        if ok and file then
            local read,text=pcall(file.read,file,2097153);pcall(file.close,file)
            if read then
                local value,reason=M:ParseSaveContent(text)
                if value then M.saved=value;M.status='loaded_data' else M.status=reason end
            else M.status='read_failed' end
        else M.status='unavailable' end
    end
end
local function at(t,path)
    for part in path:gmatch('[^.]+') do t=type(t)=='table' and t[part] or nil end
    return t
end
function M:Apply(args,root,oldPath,newPath)
    local saved=self.saved[root] or {};local current=at(saved,newPath)
    local previous=at(saved,oldPath)
    local field=args.key~=nil and '__key' or '__active'
    local expected=args.key~=nil and 'number' or type(args.value)
    local value
    if type(current)=='table' then value=current[field] end
    if type(value)~=expected then
        value=nil
        if type(previous)=='table' then value=previous[field] end
    end
    if type(value)==expected then
        if field=='__key' then args.key=value else args.value=value end
    end
    return args
end
function M:Icon(path,fallback)
    if self.icons[path]~=nil then return self.icons[path] or nil end
    local selected
    for _,candidate in ipairs({path,fallback}) do
        local base=SPRITE_PATH
        if base and FileExist then
            if not base:match('[/\\]$') then base=base..'/' end
            local ok,exists=pcall(FileExist,base..'MenuElement'..candidate)
            if ok and exists then selected=candidate;break end
        end
    end
    self.icons[path]=selected or false;return selected
end
local drawingModes={{'Combo','Combo','COMBO'},{'Harass','Harass','HARASS'},
    {'LaneClear','Lane clear','LANECLEAR'},{'JungleClear','Jungle clear','JUNGLECLEAR'},
    {'LastHit','Last hit','LASTHIT'},{'Flee','Flee','FLEE'}}
function M:Drawing(parent,args,root,oldPath,newPath)
    local id=args.id
    self:Apply(args,root,oldPath,oldPath)
    parent:MenuElement({id=id..'Display',name=args.name,type=MENU,leftIcon=args.leftIcon})
    local menu=parent[id..'Display'];local nodes={}
    local function add(key,label,value)
        local option={id=key,name=label,value=value}
        self:Apply(option,root,newPath..'.'..key,newPath..'.'..key)
        menu:MenuElement(option);nodes[key]=menu[key]
    end
    add('Enabled','Enabled',args.value)
    add('Always','Always',true)
    for _,mode in ipairs(drawingModes) do add(mode[1],mode[2],false) end
    local facade={args=args,menu=menu}
    function facade:Value(value)
        if value~=nil then nodes.Enabled:Value(value);return value end
        if not nodes.Enabled:Value() then return false end
        if nodes.Always:Value() then return true end
        local sdk=_G.SDK;local active=sdk and sdk.Orbwalker and sdk.Orbwalker.Modes
        if active then for _,mode in ipairs(drawingModes) do
            local index=sdk['ORBWALKER_MODE_'..mode[3]]
            if index and active[index] and nodes[mode[1]]:Value() then return true end
        end end
        return false
    end
    parent[id]=facade;return facade
end
function M:Orbama()
    local root;local paths={};local actual={};local groups={}
    local definitions={{'Controls','Controls','/Gamsteron_Loader.png'},
        {'Target','Targeting','/Gamsteron_TargetSelector.png'},
        {'Orbwalker','Attack & Movement','/Gamsteron_Orbwalker.png'},
        {'Automation','Automation','/Gamsteron_Spell_SummonerDot.png'},
        {'Plugins','Plugins and priorities','/Gamsteron_Spell_SummonerHaste.png'},
        {'Drawings','Appearance','/Gamsteron_Drawings.png'}}
    local hidden={SetCursorMultipleTimes=true,GeneralSpace=true,VersionSpaceA=true,VersionSpaceB=true}
    local function valueNode(args)
        local value=args.value;local key=args.key
        return {Value=function(_,v)if v~=nil then value=v end;return value end,
            Key=function(_,v)if v~=nil then key=v end;return key end,args=args}
    end
    local iconsByParent={}
    local function uniqueIcon(parent,args)
        if not args.leftIcon then return end
        local used=iconsByParent[parent] or {};iconsByParent[parent]=used
        if used[args.leftIcon] then args.leftIcon=nil else used[args.leftIcon]=true end
    end
    return function(parent,args)
        if not root then
            root=parent;paths[root]='';actual[root]=''
            for _,d in ipairs(definitions) do
                local args={id=d[1],name=d[2],type=MENU,leftIcon=self:Icon(d[3])}
                uniqueIcon(root,args);root:MenuElement(args)
                groups[d[1]]=root[d[1]];actual[root[d[1]]]=d[1];paths[root[d[1]]]=d[1]
            end
            groups.Plugins:MenuElement({id='DefaultLimit',name='Default priority limit',value=4,
                drop={'Background','Normal','Interactive','Critical'}})
        end
        local old=paths[parent];if old==nil then uniqueIcon(parent,args);parent:MenuElement(args);return parent[args.id] end
        local oldPath=old=='' and args.id or old..'.'..args.id
        if old=='Drawings' and args.id~='Enabled' and type(args.value)=='boolean' then
            return self:Drawing(parent,args,'GGOrbwalker',oldPath,'Drawings.'..args.id..'Display')
        end
        if parent==root and groups[args.id] then return groups[args.id] end
        if old=='' and hidden[args.id] then local node=valueNode(args);parent[args.id]=node;return node end
        local destination=parent
        if old=='' and (args.id=='Loader' or args.id=='Items' or args.id=='SummonerSpells' or args.id=='PMenuFH') then destination=groups.Automation
        elseif old=='' and args.id=='AttackTKey' then destination=groups.Controls
        elseif old=='' and (args.id=='Latency' or args.id=='CursorDelay' or args.id=='Humanizer') then destination=groups.Orbwalker
        elseif old=='Orbwalker' and args.id=='Keys' then
            parent.Keys=groups.Controls;paths[groups.Controls]='Orbwalker.Keys';return groups.Controls
        end
        local newPath=actual[destination]..'.'..args.id
        self:Apply(args,'GGOrbwalker',oldPath,newPath)
        uniqueIcon(destination,args)
        destination:MenuElement(args);local node=destination[args.id]
        parent[args.id]=node;paths[node]=oldPath;actual[node]=newPath
        return node
    end
end
return M
