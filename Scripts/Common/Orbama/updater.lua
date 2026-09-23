-- Compatible asynchronous helper. A callback, never elapsed time or a stale file,
-- authorizes reading a download. Replacement is staged and rollback-capable.
local U={Callbacks={},ActivePaths={},serial=0}
function U:__init() self.Callbacks={} end
function U:Trim(s) return (s:gsub('^%s+',''):gsub('%s+$','')) end
function U:ReadFile(path)
    local rows={};local f=io.open(path,'r');if not f then return rows end
    for line in f:lines() do local s=self:Trim(line);if #s>0 then rows[#rows+1]=s end end
    f:close();return rows
end
function U:DownloadFile(url,path,done)
    local ok,err=pcall(DownloadFileAsync,url,path,function(...) if done then done(...) end end)
    return ok,err
end
local function number(s)
    if type(s)~='string' or not s:match('^%d+%.?%d*$') then return end
    local n=tonumber(s);if n and n>=0 and n<math.huge then return n end
end
local function replace(stage,path)
    local previous=stage..'.previous'
    local file=io.open(path,'rb');local exists=file~=nil;if file then file:close() end
    if exists then
        -- Do not destroy an earlier backup when its ownership is unknown.
        local old=io.open(previous,'rb')
        if old then old:close();return false,'backup already exists' end
        local ok,err=os.rename(path,previous);if not ok then return false,err end
    end
    local ok,err=os.rename(stage,path)
    if not ok and exists then os.rename(previous,path) end
    return ok,err
end
function U:New(args)
    self.serial=self.serial+1
    local job={Step=1,Version=tonumber(args.version),VersionUrl=args.versionUrl,VersionPath=args.versionPath,
        ScriptUrl=args.scriptUrl,ScriptPath=args.scriptPath,ScriptName=args.scriptName,
        suffix='.orbama-stage-'..tostring(GetTickCount())..'-'..self.serial}
    function job:finish()
        self.Step=0
        if self.ScriptPath and U.ActivePaths[self.ScriptPath]==self then U.ActivePaths[self.ScriptPath]=nil end
    end
    function job:fail(reason) self.Error=tostring(reason);self:finish() end
    function job:download(url,path,nextStep)
        self.Waiting=true;self.Deadline=GetTickCount()+30000
        local token={};self.Token=token
        local ok,err=U:DownloadFile(url,path,function(success)
            if self.Step==0 or self.Token~=token then return end
            if success==false then self:fail('download callback reported failure');return end
            self.Waiting=false;self.Step=nextStep
        end)
        if not ok then self:fail(err) end
    end
    function job:DownloadVersion()
        if not self.Version or self.Version<0 or self.Version>=math.huge
            or not self.VersionUrl or not self.VersionPath or not self.ScriptPath or not self.ScriptUrl then
            self:fail('invalid update arguments');return
        end
        self.StageVersion=self.VersionPath..self.suffix
        self.StageScript=self.ScriptPath..self.suffix
        self:download(self.VersionUrl,self.StageVersion,2)
    end
    function job:CanUpdate() return self.NewVersion~=nil and self.NewVersion>self.Version end
    function job:OnTick()
        if self.Step==0 then return end
        if self.Waiting then
            if GetTickCount()>self.Deadline then self:fail('download timeout; late callback ignored') end
            return
        end
        if self.Step==2 then
            local rows=U:ReadFile(self.StageVersion)
            self.NewVersion=#rows==1 and number(rows[1]) or nil
            if not self.NewVersion then self:fail('invalid version data');return end
            local f=io.open(self.ScriptPath,'rb');local exists=f~=nil;if f then f:close() end
            if self:CanUpdate() or not exists then
                self.Step=3;self:download(self.ScriptUrl,self.StageScript,4)
            else self:finish() end
        elseif self.Step==4 then
            local f=io.open(self.StageScript,'rb');local content=f and f:read('*a');if f then f:close() end
            if not content or #content==0 or not loadstring(content) then self:fail('incomplete or invalid Lua download');return end
            local ok,err=replace(self.StageScript,self.ScriptPath)
            if not ok then self:fail(err);return end
            self:finish();self.Completed=true
            print(tostring(self.ScriptName)..' - downloaded and validated; reload to activate.')
        end
    end
    if job.ScriptPath and self.ActivePaths[job.ScriptPath] then job:fail('update already pending for this path');return job end
    if job.ScriptPath then self.ActivePaths[job.ScriptPath]=job end
    job:DownloadVersion();self.Callbacks[#self.Callbacks+1]=job;return job
end
function U:OnTick() for _,job in ipairs(self.Callbacks) do job:OnTick() end end
return U
