return function(env,hash,builtin,origin)
    local names={'Orbama','LeeHarveyOsward'}
    local client={version=builtin,state='current',loaded={}}
    local function checksum(text)
        local a,b=1,0
        for offset=1,#text,4096 do
            for i=offset,math.min(offset+4095,#text) do a=a+text:byte(i);b=b+a end
            a=a%65521;b=b%65521
        end
        return b*65536+a
    end
    local base=env.COMMON_PATH
    if type(base)=='string' and not base:match('[/\\]$') then base=base..'/' end
    local function path(slot,name)return base..'runtime-'..slot..'-'..name end
    local function read(file,limit)
        local ok,value=pcall(function()
            local f=env.io.open(file,'rb');if not f then return end
            local data=f:read(limit+1);f:close()
            if data and #data<=limit then return data end
        end)
        if ok then return value end
    end
    local function write(file,data)
        local ok,result=pcall(function()
            local f=env.io.open(file,'wb');if not f then return false end
            local written=f:write(data);local closed=f:close()
            return written~=nil and closed~=nil
        end)
        return ok and result and read(file,#data)==data
    end
    local function parse(text)
        if type(text)~='string' or #text>512 then return end
        local version,a,asize,acrc,b,bsize,bcrc=text:match('^R1\n(%d+)\nOrbama (%x+) (%d+) (%d+)\nLeeHarveyOsward (%x+) (%d+) (%d+)\n$')
        version=tonumber(version);asize=tonumber(asize);bsize=tonumber(bsize);acrc=tonumber(acrc);bcrc=tonumber(bcrc)
        if not version or version<1 or version>999999999 or #a~=64 or #b~=64
            or asize<1 or bsize<1 or asize>4000000 or bsize>4000000
            or acrc>4294967295 or bcrc>4294967295 then return end
        return {version=version,text=text,Orbama={hash=a,size=asize,checksum=acrc},LeeHarveyOsward={hash=b,size=bsize,checksum=bcrc}}
    end
    local function validate(slot,manifest,pause)
        local chunks={}
        for _,name in ipairs(names) do
            local item=manifest[name];local body=read(path(slot,name..'.lua'),item.size)
            if not body or #body~=item.size or checksum(body)~=item.checksum then return end
            local fn=env.loadstring(body,'@runtime/'..name..'.lua')
            if not fn then return end
            chunks[name]=fn
        end
        return chunks
    end
    if base and env.io and env.loadstring then
        local choices={}
        for _,slot in ipairs({'a','b'}) do
            local candidate=parse(read(path(slot,'manifest'),512))
            if candidate and candidate.version>builtin then candidate.slot=slot;choices[#choices+1]=candidate end
        end
        table.sort(choices,function(a,b)return a.version>b.version end)
        for _,candidate in ipairs(choices) do
            local chunks=validate(candidate.slot,candidate)
            if chunks then client.version=candidate.version;client.slot=candidate.slot;client.chunks=chunks;break end
        end
    end
    function client:Boot(name,fallback,version)
        if self.loaded[name] then return self.loaded[name].value end
        if not self.chunks and version~=self.version then error('Runtime files belong to different releases; install the matching pair.') end
        local record={};self.loaded[name]=record
        local fn=self.chunks and self.chunks[name] or fallback
        -- Never retry another implementation after a chunk might have installed callbacks.
        record.value=fn();return record.value
    end
    local job,waiting,deadline,nextCheck,generation=nil,nil,0,0,0
    local function now()return env.GetTickCount()/1000 end
    local function fail()
        generation=generation+1;waiting=nil;job=nil;client.state='unavailable';nextCheck=now()+600
    end
    local function request(url,accept)
        generation=generation+1;local token=generation
        waiting=true;deadline=now()+45
        local ok=pcall(env.GetWebResultAsync,url,function(body)
            if token~=generation or not waiting then return end
            waiting=nil
            if type(body)~='string' or #body>4000000 then fail();return end
            accept(body)
        end)
        if not ok then fail() end
    end
    local function begin()
        client.state='checking';nextCheck=now()+600
        request(origin..'/main/release/manifest',function(text)
            local manifest=parse(text)
            if not manifest then fail();return end
            if manifest.version<=client.version then client.state='current';return end
            local slot=client.slot=='a' and 'b' or 'a';local index=1
            local function download()
                local name=names[index]
                if not name then
                    if write(path(slot,'manifest'),manifest.text) then client.state='ready';client.pending=manifest.version
                    else fail() end
                    return
                end
                local item=manifest[name]
                request(origin..'/main/release/'..manifest.version..'/'..name..'.lua',function(body)
                    job=coroutine.create(function()
                        if #body~=item.size or hash(body,coroutine.yield)~=item.hash or checksum(body)~=item.checksum
                            or not env.loadstring(body,'@update/'..name..'.lua') then fail();return end
                        if not write(path(slot,name..'.lua'),body) then fail();return end
                        index=index+1;job=nil;download()
                    end)
                end)
            end
            download()
        end)
    end
    function client:Tick()
        if self.state=='ready' then return end
        if waiting and now()>deadline then fail();return end
        if job then
            local current=job
            local ok=coroutine.resume(current)
            if not ok then fail()
            elseif current==job and coroutine.status(current)=='dead' then job=nil end
        elseif not waiting and now()>=nextCheck then begin() end
    end
    if base and env.io and env.loadstring and env.GetWebResultAsync and env.GetTickCount and env.Callback then
        env.Callback.Add('Tick',function()
            local sdk=env.SDK;local input=sdk and sdk.Input
            if input and (input.Step~=0 or input.InFlight and input.InFlight>0) then return end
            local modes=sdk and sdk.Orbwalker and sdk.Orbwalker.Modes
            if modes then for _,active in pairs(modes) do if active then return end end end
            local spell=env.myHero and env.myHero.activeSpell
            if spell and spell.valid then return end
            local ok=pcall(client.Tick,client)
            if not ok then fail() end
        end)
    end
    return client
end
