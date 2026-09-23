-- Input-free, bounded search. Actions describe legal transitions, not named combos.
-- Times are conservative impact boundaries; projectile flight is not treated as
-- a free extra attack. Only the already observed attack may overlap a spell.
local F={}
local function copy(s)
    local n={};for k,v in pairs(s) do n[k]=v end
    n.used={};for k,v in pairs(s.used) do n.used[k]=v end
    return n
end
local function hit(s,damage,kind)
    local shield=kind=='magic' and 'magic' or kind=='physical' and 'physical'
    if shield then local use=math.min(s[shield],damage);s[shield]=s[shield]-use;damage=damage-use end
    local use=math.min(s.shield,damage);s.shield=s.shield-use
    s.hp=math.max(0,s.hp-damage+use)
end
local function advance(s,t,model)
    if model.pending and not s.pendingDone and model.pending.at<=t then
        local at=math.max(s.t,model.pending.at)
        s.hp=math.min(model.maxHP,s.hp+model.regen*(at-s.t));s.t=at
        hit(s,model.pending.damage,'physical');s.pendingDone=true
        if s.hp<=0 then return end
    end
    s.hp=math.min(model.maxHP,s.hp+model.regen*math.max(0,t-s.t));s.t=t
end
local function better(a,b,model)
    if not b then return true end
    local al,bl=a.hp<=0,b.hp<=0
    if al~=bl then return al end
    if al then
        -- Inside the allowed survival/escape window, save resources first.
        if a.cost~=b.cost then return a.cost<b.cost end
        return a.t<b.t
    end
    local function score(s)
        return (model.hp-s.hp+s.utility)/math.max(.25,s.t)-s.cost*model.resourceWeight
    end
    return score(a)>score(b)
end
function F.solve(model)
    local root={hp=model.hp,shield=model.shield or 0,physical=model.physical or 0,magic=model.magic or 0,
        energy=model.energy,t=0,cost=0,utility=0,used={},autos=0,aaAt=model.aaAt or 0,
        distance=model.distance,mark=model.mark or 0,conditional=false}
    local frontier={root};local best,lethal,expanded=nil,nil,0
    local width=model.width or 8;local limit=model.limit or 192
    for depth=1,model.depth or 6 do
        local nextLevel={}
        for _,node in ipairs(frontier) do
            for _,a in ipairs(model.actions) do
                if expanded>=limit then break end
                expanded=expanded+1
                if (a.repeatable or not node.used[a.id]) and (a.energy or 0)<=node.energy then
                    local delay=a.delay(node)
                    if delay and delay>=0 and node.t+delay<=model.horizon then
                        local n=copy(node);local finish=node.t+delay
                        advance(n,finish,model)
                        if n.hp>0 then
                            local amount=a.damage and a.damage(n) or 0
                            hit(n,math.max(0,amount),a.kind)
                            n.energy=n.energy-(a.energy or 0);n.cost=n.cost+(a.cost or 0)
                            n.utility=n.utility+(a.utility or 0);n.used[a.id]=true
                            n.first=n.first or a.id;n.firstAt=n.firstAt or node.t
                            n.path=(n.path and n.path..' > ' or '')..a.id
                            if a.apply then a.apply(n,node,delay) end
                        end
                        if better(n,best,model) then best=n end
                        if n.hp<=0 and not n.conditional and better(n,lethal,model) then lethal=n end
                        if n.hp>0 then
                            -- Keep a small ordered beam; no global sort or unbounded graph.
                            local at=#nextLevel+1
                            for j,v in ipairs(nextLevel) do if better(n,v,model) then at=j;break end end
                            if at<=width then table.insert(nextLevel,at,n);if #nextLevel>width then table.remove(nextLevel) end end
                        end
                    end
                end
            end
            if expanded>=limit then break end
        end
        frontier=nextLevel
        if #frontier==0 or expanded>=limit then break end
    end
    -- An observed lethal attack needs no additional command at all.
    if model.pending and model.pending.at<=model.horizon then
        local wait=copy(root);advance(wait,model.pending.at,model)
        if wait.hp<=0 and better(wait,lethal,model) then lethal=wait;best=wait end
    end
    return {best=best,lethal=lethal,expanded=expanded,horizon=model.horizon}
end
return F
