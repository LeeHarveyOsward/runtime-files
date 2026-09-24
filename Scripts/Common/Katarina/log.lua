-- Buffered, bounded diagnostics. Failure disables only logging.
local L={};L.__index=L
local function encode(v,depth)
    local kind=type(v)
    if kind=='nil'then return 'null'end
    if kind=='boolean'then return tostring(v)end
    if kind=='number'then return v==v and math.abs(v)<math.huge and tostring(v)or 'null'end
    if kind=='string'then return '"'..v:sub(1,1024):gsub('[%z\1-\31\\"]',function(ch)
        return string.format('\\u%04x',string.byte(ch))end)..'"'end
    if kind~='table'or(depth or 0)>6 then return 'null'end
    local parts={};local n=0
    for k,x in pairs(v)do n=n+1;if n>40 then break end;parts[#parts+1]=encode(tostring(k))..':'..encode(x,(depth or 0)+1)end
    return '{'..table.concat(parts,',')..'}'
end
function L.new(c)
    return setmetatable({c=c,root=COMMON_PATH or SCRIPT_PATH,part=1,bytes=0,pending={},pendingBytes=0,
        records=0,flushes=0,session=tostring(c.actions.client:Now())..'-'..tostring(math.floor(Game.Timer()*1000))},L)
end
function L:line(kind,data)
    local c=self.c
    return encode({kind=kind,data=data,session=self.session,gameTime=Game.Timer(),inputMs=c.actions.client:Now(),
        build=c.build,profile=c.profile.id})..'\n'
end
function L:write(kind,data)
    if self.disabled or not self.c.config:get('diagnostics')then return end
    local ok=pcall(function()
        if not self.header then
            local c=self.c
            self.header=self:line('loaded',{generation=c.generation,provider=c.sdk.OrbamaVersion,hero=c.hero.charName,
                map=Game.mapID,team=c.hero.team,recordingStartedAt=Game.Timer(),loadedAt=c.loadedAt,
                clock='inputMs: monotonic milliseconds; gameTime: game seconds'})
        end
        local line=self:line(kind,data)
        if self.pendingBytes+#line>32768 or #self.pending>=64 then self.dropped=(self.dropped or 0)+1;return end
        self.pending[#self.pending+1]=line;self.pendingBytes=self.pendingBytes+#line;self.records=self.records+1
    end)
    if not ok then self.disabled=true;self.pending={};self.pendingBytes=0 end
end
function L:flush(force)
    if self.disabled or #self.pending==0 then return end
    if not force and Game.Timer()<(self.nextFlush or 0)then return end
    self.nextFlush=Game.Timer()+.25
    local ok=pcall(function()
        assert(self.root and io and io.open,'log path unavailable')
        local root=self.root..(self.root:match('[/\\]$')and ''or '/')
        local body=(self.bytes==0 and self.header or '')..table.concat(self.pending)
        local f=assert(io.open(root..'KataHari-playtest-'..self.part..'.jsonl',self.bytes==0 and 'w'or 'a'))
        local wrote,result=pcall(f.write,f,body);local closed,value=pcall(f.close,f)
        assert(wrote and result and closed and value~=false,'log write failed')
        self.bytes=self.bytes+#body;self.flushes=self.flushes+1
        if self.bytes>=524288 then self.part=self.part%4+1;self.bytes=0 end
    end)
    self.pending={};self.pendingBytes=0
    if not ok then self.disabled=true end
end
return L
