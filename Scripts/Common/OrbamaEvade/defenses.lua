-- Profiles/adapters register verified effects. Readiness and legality remain
-- with the controller which owns the resource; no slot-only damage guesses.
local F={};F.__index=F
function F.new()return setmetatable({adapters={},revision=0},F)end
function F:Register(name,adapter)
    if type(name)~='string'or self.adapters[name]or type(adapter)~='table'
        or type(adapter.options)~='function'or type(adapter.prepare)~='function'
        or type(adapter.source)~='string'or adapter.validated~=true then return false,'verified_adapter_required'end
    self.adapters[name]=adapter;self.revision=self.revision+1;return true
end
function F:Remove(name)self.adapters[name]=nil;self.revision=self.revision+1 end
function F:Options(ctx,permissions)
    local result={}
    for name,a in pairs(self.adapters)do
        local ok,options=pcall(a.options,ctx)
        if ok and type(options)=='table'then for i=1,math.min(#options,16)do local v=options[i]
            if #result>=32 then return result end
            if v.validated==true and v.profile==ctx.profile and v.resource~=nil
                and (not v.ultimate or permissions.ultimates)and(not v.summoner or permissions.summoners)
                and(not v.item or permissions.items)then
                result[#result+1]={adapter=name,option=v}
            end
        end end
    end
    return result
end
function F:Prepare(candidate,ctx)
    local a=self.adapters[candidate.adapter];if not a then return nil,'adapter_removed'end
    local ok,value,why=pcall(a.prepare,candidate.option,ctx)
    if not ok then return nil,'defense_prepare_error'end
    if type(value)~='table'or type(value.mechanical)~='function'then return nil,why or 'defense_declined'end
    return value
end
return F
