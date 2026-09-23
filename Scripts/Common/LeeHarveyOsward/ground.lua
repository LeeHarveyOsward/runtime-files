-- Ground clicks are contextual inputs. Keep their endpoint off visible bodies.
-- This geometric guard is conservative; it is not pixel-perfect hover proof.
local U=require('lho.util')
local G={}
function G.blocker(c,pos,scene)
    return G.screenBlocker(c,U.vector(pos):To2D(),nil,scene)
end
function G.scene(c)
    local resolution=Game.Resolution and Game.Resolution()
    local scale=math.max(.75,math.min(3,(resolution and resolution.y or 1080)/1080))
    local seen,scene={},{}
    for _,list in ipairs({c.minions or {},c.heroes or {},c.turrets or {},c.wardObjects or {}}) do
        for _,m in ipairs(list) do
            local id=U.id(m)
            if id and not seen[id] and not U.same(m,myHero) and U.valid(m) then
                seen[id]=true
                local q=U.vector(m.pos):To2D()
                if q and q.onScreen~=false then
                    local radius=math.max(25,m.boundingRadius or 45)
                    local edge=U.vector({x=m.pos.x+radius,y=m.pos.y,z=m.pos.z}):To2D()
                    local width=math.max(18*scale,edge and math.abs(edge.x-q.x) or 0)
                    -- Model silhouettes extend upward from ground projection.
                    scene[#scene+1]={unit=m,x=q.x,width=width+8*scale,top=q.y-100*scale,bottom=q.y+width*.5+8*scale}
                end
            end
        end
    end
    return scene
end
function G.screenBlocker(c,p,ignore,scene)
    if not p or p.onScreen==false then return nil end
    -- A scene is shared only within this synchronous candidate search. Final
    -- input validation calls without it, projecting the current scene afresh.
    for _,row in ipairs(scene or G.scene(c)) do
        if not U.same(row.unit,ignore) and math.abs(p.x-row.x)<=row.width and p.y>=row.top and p.y<=row.bottom then return row.unit end
    end
end
function G.select(c,pos)
    local scene=G.scene(c)
    if not G.blocker(c,pos,scene) then return U.copy(pos) end
    local distance=U.dist(myHero.pos,pos);if distance<1 then return nil,'ground_direction_missing' end
    local radius=myHero.boundingRadius or 35
    local kite=c.mode=='farm' and c.farm and c.farm.kiteStep
    local camp=kite and c.farm.camp
    -- Bounded extension on the same unobstructed ray. Never ask native
    -- pathfinding to get around a wall merely to obtain an empty click point.
    for _,extra in ipairs({80,160,240,320}) do
        local p=U.toward(myHero.pos,pos,distance+extra)
        local outward=kite and kite.phase=='out'
        local inside=outward or not camp or not camp.kiteCenter or U.dist(p,camp.kiteCenter)<=c.config:get('farmKiteLeash')
        local clear=outward and c.farm:kiteLine(myHero.pos,p) or not outward and c.terrain:walkLine(myHero.pos,p,radius)
        if inside and U.vector(p):To2D().onScreen and clear
            and not G.blocker(c,p,scene) then return p end
    end
    -- If the ray is occupied or meets terrain, search nearby empty rays. Keep
    -- manual intent generally forward; an outward kite must increase separation.
    local dx,dz=(pos.x-myHero.pos.x)/distance,(pos.z-myHero.pos.z)/distance
    local target=kite and kite.phase=='out' and camp and camp.focus
    local separation=target and U.dist(myHero.pos,target.pos)
    for _,angle in ipairs({.35,-.35,.7,-.7,1.05,-1.05}) do
        local x,z=dx*math.cos(angle)-dz*math.sin(angle),dx*math.sin(angle)+dz*math.cos(angle)
        for _,length in ipairs({300,220,140,80}) do
            local p={x=myHero.pos.x+x*length,y=myHero.pos.y,z=myHero.pos.z+z*length}
            local inside=not camp or not camp.kiteCenter or U.dist(p,camp.kiteCenter)<=c.config:get('farmKiteLeash')
            local useful=target and U.dist(p,target.pos)>separation+15
                or not target and U.dist(p,pos)<distance
            if useful and inside and U.vector(p):To2D().onScreen and c.terrain:walkLine(myHero.pos,p,radius)
                and not G.blocker(c,p,scene) then return p end
        end
    end
    return nil,'ground_click_occupied'
end
return G
