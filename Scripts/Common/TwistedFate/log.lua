-- Three bounded parts in the host's tested Common directory. Logging failures
-- disable this logger once; no absolute development paths or sandbox bypass.
local L={};L.__index=L
local function encode(v,depth)
    local kind=type(v)
    if kind=='nil'then return 'null' end
    if kind=='boolean'then return tostring(v)end
    if kind=='number'then return v==v and math.abs(v)<math.huge and tostring(v) or 'null'end
    if kind=='string'then return '"'..v:gsub('[%z\1-\31\\"]',function(ch)
        if ch=='"'then return '\\"'elseif ch=='\\'then return '\\\\'end
        return string.format('\\u%04x',string.byte(ch))end)..'"'end
    if kind~='table' or (depth or 0)>3 then return 'null'end
    local parts={};local n=0
    for k,x in pairs(v)do n=n+1;if n>32 then break end;parts[#parts+1]=encode(tostring(k))..':'..encode(x,(depth or 0)+1)end
    return '{'..table.concat(parts,',')..'}'
end
function L.new(c)
    local root=COMMON_PATH or SCRIPT_PATH
    return setmetatable({c=c,part=1,bytes=0,pending={},pendingBytes=0,flushes=0,records=0,disabled=not(root and io and io.open),root=root,
        session=tostring(GetTickCount())..'-'..tostring(math.floor(Game.Timer()*1000))},L)
end
function L:flush(force)
    if self.disabled or #self.pending==0 then return end
    if not force and Game.Timer()<(self.nextFlush or 0)then return end
    self.nextFlush=Game.Timer()+.25
    local ok=pcall(function()
        local root=self.root;if not root:match('[/\\]$')then root=root..'/'end
        local path=root..'TwistedFate-playtest-'..self.part..'.jsonl'
        local prefix=self.bytes==0 and not self.pendingHeader and self.header or ''
        local body=prefix..table.concat(self.pending)
        local file=assert(io.open(path,self.bytes==0 and 'w' or 'a'))
        local written,wrote,err=pcall(file.write,file,body)
        local closed,closeResult=pcall(file.close,file)
        assert(written and wrote,err);assert(closed and closeResult~=false)
        self.flushes=self.flushes+1;self.bytes=self.bytes+#body
        if self.bytes>262144 then self.part=self.part%3+1;self.bytes=0 end
    end)
    self.pending={};self.pendingBytes=0;self.pendingHeader=nil
    if not ok then self.disabled=true end
end
function L:write(kind,fields)
    if self.disabled then return end
    local ok=pcall(function()
        local line=encode({kind=kind,session=self.session,gameTime=Game.Timer(),inputMs=self.c.actions.client:Now(),
            build=self.c.build,profile=self.c.profile.id,data=fields})..'\n'
        if kind=='loaded'then self.header=line;self.pendingHeader=true end
        -- Copy the original header, including its original clocks, into each
        -- rotated part so a bounded capture can still identify the loaded build.
        self.pending[#self.pending+1]=line;self.pendingBytes=self.pendingBytes+#line;self.records=self.records+1
        if kind=='loaded' or self.pendingBytes>=16384 or #self.pending>=64 then self:flush(true)end
    end)
    if not ok then self.disabled=true;self.pending={};self.pendingBytes=0 end
end
return L
