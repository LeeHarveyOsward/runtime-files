local U=require('lho.util')
local A={}
function A.reject(actions,record,target)
    if not record or not record.sentAt or not record.aim or record.aim.source~='client_projection' then return end
    local old=actions.aimTrial
    if old and old.action==record.id then return end
    actions.aimTrial={target=U.id(target),action=record.id,at=actions.ctx:now(),
        index=old and old.target==U.id(target) and (old.index+1)%5 or 1}
    actions.bodyPoint=nil
end
-- Read-only candidate provider; successful observations update the cache elsewhere.
function A.points(actions,target,preferIsolated)
    local p=U.vector(target.pos):To2D();local size=Game.Resolution and Game.Resolution()
    if not p or p.onScreen==false or not size then return {} end
    local origin=U.vector(myHero.pos):To2D();local old=actions.bodyPoint
    local out={};local scale=math.max(.5,math.min(3,size.y/1080))
    local function add(x,y)
        if x<0 or y<0 or x>=size.x or y>=size.y then return end
        for _,q in ipairs(out) do if U.screenDist(q,{x=x,y=y})<2 then return end end
        if #out<5 then out[#out+1]={x=x,y=y} end
    end
    if old and U.same(old.target,target) and actions:inputNow()-old.at>=0 and actions:inputNow()-old.at<1000
        and old.width==size.x and old.height==size.y and U.screenDist(old.projection,p)<12
        and U.screenDist(old.origin,origin)<12 then add(old.point.x,old.point.y) end
    -- When the host has no hover identity, start with an isolated body point
    -- instead of spending a positioning phase on ground that cannot qualify.
    if preferIsolated then
        local scene=require('lho.ground').scene(actions.ctx)
        -- Evaluate lateral candidates too before acquiring the cursor. Otherwise
        -- a reachable side of a crowded monster may be last in the list and
        -- never reached before the bounded positioning budget expires.
        local offsets={{0,60},{0,30},{0,15},{-18,30},{18,30}}
        local trial=actions.aimTrial
        local start=trial and trial.target==U.id(target) and actions.ctx:now()-trial.at<5 and trial.index or 0
        for i=1,#offsets do
            local offset=offsets[(start+i-1)%#offsets+1]
            local point={x=p.x+offset[1]*scale,y=p.y-offset[2]*scale}
            if A.isolated(actions.ctx,target,point,scene) then add(point.x,point.y);break end
        end
    end
    add(p.x,p.y);add(p.x,p.y-60*scale);add(p.x,p.y-30*scale)
    add(p.x-18*scale,p.y-45*scale);add(p.x+18*scale,p.y-45*scale)
    return out
end
function A.isolated(c,target,point,scene)
    if not U.valid(target) or target.team~=300 or not point then return false end
    local screen=U.vector(target.pos):To2D();local size=Game.Resolution and Game.Resolution()
    if not screen.onScreen or not size then return false end
    local scale=math.max(.5,math.min(3,size.y/1080))
    -- Only a central body point, never an unrelated ground position. Nearby
    -- projected bodies reject this approximation; native identity wins always.
    if math.abs(point.x-screen.x)>20*scale or point.y>screen.y-10*scale or point.y<screen.y-80*scale then return false end
    return not require('lho.ground').screenBlocker(c,point,target,scene)
end
function A.remember(actions,r,target)
    local aim=r and r.aim
    if not aim or not aim.hoverConfirmed or not aim.position or not r.sentAt then return end
    local size=Game.Resolution and Game.Resolution();if not size then return end
    actions.bodyPoint={target=target,point=U.copy(aim.position),projection=U.vector(target.pos):To2D(),
        origin=U.vector(myHero.pos):To2D(),at=aim.confirmedAt,width=size.x,height=size.y}
end
return A
