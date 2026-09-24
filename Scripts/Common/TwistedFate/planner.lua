-- Pure bounded event simulation. No input, objects, clock or global callbacks.
-- Unknown item effects are omitted, never counted as confirmed kill damage.
local M={horizon=3,width=8,limit=256}
local function clone(s)
    local o={};for k,v in pairs(s)do if k~='events'then o[k]=v end end
    o.events={};for i,e in ipairs(s.events)do o.events[i]=e end;return o
end
local function damage(s,packet)
    s.expected=s.expected+(packet.expected or 0)
    for _,kind in ipairs({'physical','magical','trueDamage'})do
        local n=packet[kind] or 0;local key=kind=='physical' and 'physicalShield' or kind=='magical' and 'magicalShield'
        if key then local used=math.min(s[key],n);s[key]=s[key]-used;n=n-used end
        local used=math.min(s.shield,n);s.shield=s.shield-used;n=n-used
        s.hp=s.hp-n;if s.hp<=0 then return end
    end
end
local function advance(s,t,p)
    table.sort(s.events,function(a,b)return a.at<b.at end)
    while s.events[1] and s.events[1].at<=t and s.hp>0 do
        local e=table.remove(s.events,1)
        s.hp=math.min(p.hp,s.hp+p.regen*math.max(0,e.at-s.t));s.t=e.at
        if e.lock then
            s.card=e.lock;s.pendingCard=false
            if p.reset then s.nextAA=math.max(s.t,s.windupEnd)end
        else
            damage(s,e.packet)
            local control=math.min(e.control or 0,math.max(0,M.horizon-e.at))
            s.control=s.control+math.max(0,control-math.max(0,s.controlUntil-e.at))
            s.controlUntil=math.max(s.controlUntil,e.at+control)
            if e.mana then s.mana=math.min(p.maxMana,s.mana+e.mana)end
            if s.hp<=0 then s.killAt=e.at end
        end
    end
    if s.hp>0 then s.hp=math.min(p.hp,s.hp+p.regen*math.max(0,t-s.t));s.t=t end
end
local function first(s,kind,color)if not s.first then s.first=kind;s.color=color end end
local function score(s,p)
    local damageDone=p.hp-math.max(0,s.hp)
    if s.hp<=0 then return 100000-s.killAt*100-s.spent end
    return damageDone+math.min(s.hp,s.expected)+s.control*p.controlValue-s.spent*.12
end
function M.solve(p)
    p.regen=p.regen or 0;p.controlValue=p.controlValue or 0
    local start={t=0,hp=p.hp,shield=p.shield or 0,physicalShield=p.physicalShield or 0,magicalShield=p.magicalShield or 0,
        mana=p.mana,nextAA=p.nextAA or 0,windupEnd=0,card=p.card,e=p.e or 0,events={},spent=0,control=0,
        usedQ=false,usedW=p.card~=nil,attacks=0,expected=0,extraBits=0,controlUntil=0}
    for _,event in ipairs(p.incoming or {})do start.events[#start.events+1]=event end
    local beam={start};local best=clone(start);advance(best,M.horizon,p);best.score=score(best,p)
    local count=0
    -- Always include a complete legal AA-only baseline. Beam pruning must not
    -- win merely because it evaluated fewer future attacks on the other branch.
    local baseline=clone(start)
    while p.attack and baseline.hp>0 and count<64 do
        if baseline.attacks>0 and not p.repeatReachable then break end
        local at=math.max(baseline.t,baseline.nextAA)
        if at+p.windup+p.flight>M.horizon then break end
        if at>baseline.t then first(baseline,'wait');advance(baseline,at,p)end
        first(baseline,'attack');count=count+1
        baseline.events[#baseline.events+1]={at=at+p.windup+p.flight,
            packet=p.attack(baseline.card,baseline.e==3,baseline.attacks,baseline.hp),
            control=baseline.card=='gold' and p.stun or 0,mana=baseline.card=='blue' and p.blueMana or 0}
        baseline.card=nil;baseline.e=p.hasE and (baseline.e+1)%4 or 0
        baseline.attacks=baseline.attacks+1;baseline.nextAA=at+p.period
        baseline.windupEnd=at+p.windup;advance(baseline,baseline.windupEnd,p)
    end
    advance(baseline,M.horizon,p);baseline.score=score(baseline,p)
    if baseline.score>best.score then best=baseline end
    for depth=1,64 do
        local nextBeam={}
        for _,s in ipairs(beam)do
            if count>=M.limit then break end
            local function offer(n)
                if count>=M.limit then return end
                count=count+1
                local final=clone(n);advance(final,M.horizon,p);final.score=score(final,p)
                if final.score>best.score then best=final end
                n.bound=final.score;nextBeam[#nextBeam+1]=n
            end
            if s.hp>0 and s.t<M.horizon then
                if p.attack and s.t>=s.nextAA and (s.attacks==0 or p.repeatReachable)then
                    local n=clone(s);first(n,'attack')
                    local packet=p.attack(n.card,n.e==3,n.attacks,n.hp);local at=s.t+p.windup+p.flight
                    local control=n.card=='gold' and p.stun or 0
                    n.events[#n.events+1]={at=at,packet=packet,control=control,mana=n.card=='blue' and p.blueMana or 0}
                    n.card=nil;n.e=p.hasE and (n.e+1)%4 or 0;n.attacks=n.attacks+1
                    n.windupEnd=s.t+p.windup;n.nextAA=s.t+p.period
                    advance(n,n.windupEnd,p);offer(n)
                end
                if p.q and not s.usedQ and s.mana>=p.qCost+p.reserveQ and not s.pendingCard then
                    local n=clone(s);first(n,'q');n.usedQ=true;n.mana=n.mana-p.qCost;n.spent=n.spent+p.qCost
                    n.events[#n.events+1]={at=s.t+p.qImpact,packet=p.q}
                    advance(n,s.t+p.qCast,p);offer(n)
                end
                if p.cards and not s.usedW and s.mana>=p.wCost then
                    for _,row in ipairs(p.cards)do
                        local recovery=row.color=='blue' and math.min(p.blueMana,p.maxMana-(s.mana-p.wCost)) or 0
                        if s.mana-p.wCost+recovery>=p.reserveW then
                        local n=clone(s);first(n,'card',row.color);n.usedW=true;n.pendingCard=true
                        n.mana=n.mana-p.wCost;n.spent=n.spent+p.wCost
                        n.events[#n.events+1]={at=s.t+row.wait,lock=row.color}
                        advance(n,s.t+.001,p);offer(n)
                        end
                    end
                end
                for i,row in ipairs(p.extras or {})do
                    local flag=2^(i-1)
                    if math.floor(s.extraBits/flag)%2==0 and s.mana>=row.cost and s.t+row.delay<=M.horizon then
                        local n=clone(s)
                        if not n.first then first(n,'extra');n.extra=row.id end
                        n.extraBits=n.extraBits+flag;n.mana=n.mana-row.cost;n.spent=n.spent+row.cost+(row.opportunityCost or 0)
                        n.events[#n.events+1]={at=s.t+row.delay,packet=row.packet or {},control=row.control or 0}
                        advance(n,s.t+row.castTime,p);offer(n)
                    end
                end
                local at=s.nextAA>s.t and s.nextAA or M.horizon
                for _,e in ipairs(s.events)do if e.at>s.t then at=math.min(at,e.at)end end
                if at>s.t then local n=clone(s);first(n,'wait');advance(n,math.min(at,M.horizon),p);offer(n)end
            end
        end
        table.sort(nextBeam,function(a,b)return a.bound>b.bound end)
        beam={};for i=1,math.min(M.width,#nextBeam)do beam[i]=nextBeam[i]end
        if #beam==0 or count>=M.limit then break end
    end
    best.transitions=count;return best
end
return M
