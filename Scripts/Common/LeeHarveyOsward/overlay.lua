local U=require('lho.util')
local O={};O.__index=O
function O.new(ctx) return setmetatable({ctx=ctx},O) end
local colors,provider={},nil
local function color(r,g,b)
    if provider~=Draw.Color then colors={};provider=Draw.Color end
    local key=r*65536+g*256+b
    if colors[key]==nil then colors[key]=Draw.Color(230,r,g,b) end
    return colors[key]
end
local function circle(p,r,col)
    if U.position(p) and U.finite(r) and r>0 and r<20000 then Draw.Circle(U.vector(p),r,2,col) end
end
local function line(a,b,col)
    if not U.position(a) or not U.position(b) then return end
    local p,q=U.vector(a):To2D(),U.vector(b):To2D()
    if p.onScreen and q.onScreen and U.finite(p.x) and U.finite(p.y) and U.finite(q.x) and U.finite(q.y) then
        Draw.Line(p.x,p.y,q.x,q.y,2,col)
    end
end
local function arrow(a,b,col)
    if not U.position(a) or not U.position(b) then return end
    local p,q=U.vector(a):To2D(),U.vector(b):To2D()
    if not p.onScreen or not q.onScreen or not U.finite(p.x) or not U.finite(p.y)
        or not U.finite(q.x) or not U.finite(q.y) then return end
    local dx,dy=q.x-p.x,q.y-p.y;local length=math.sqrt(dx*dx+dy*dy)
    if length<8 then return end
    dx,dy=dx/length,dy/length
    local size=math.min(18,length*.3);local bx,by=q.x-dx*size,q.y-dy*size
    Draw.Line(p.x,p.y,q.x,q.y,3,col)
    Draw.Line(q.x,q.y,bx-dy*size*.55,by+dx*size*.55,3,col)
    Draw.Line(q.x,q.y,bx+dy*size*.55,by-dx*size*.55,3,col)
end
function O:insecDrawing(i)
    local c=self.ctx;local green,amber,white=color(65,225,165),color(255,195,75),color(220,225,235)
    -- Rendering consumes the last controller geometry. It must not change the
    -- plan, destination, prediction lead or resource contract on a Draw call.
    local view={};for key,value in pairs(i) do view[key]=value end
    local old=i.geometryTarget or i.target.pos;local predicted=i.plannedTarget or old
    local start={x=i.target.pos.x+predicted.x-old.x,y=i.target.pos.y,z=i.target.pos.z+predicted.z-old.z}
    local aim=i.destination or c.aim
    if i.kind=='ally' and not i.locked and c.config:get('insecTrackAlly') and U.valid(i.recipient) then aim=i.recipient.pos end
    if i.locked and i.direction then aim={x=start.x+i.direction.x*1200,y=start.y,z=start.z+i.direction.z*1200} end
    local stand,endpoint=c.combat:direction({pos=start},aim)
    view.plannedTarget=start;view.plannedEndpoint=endpoint;view.stand=stand
    local display=c.combat.planner:adapt(view,i.plan);i.displayPlan=display
    circle(i.target.pos,85,amber);circle(stand,28,amber)
    if endpoint then
        -- Short directional arrow remains readable when the true endpoint is
        -- offscreen. Its head is at the destination, never at the kicked unit.
        arrow(start,U.toward(start,endpoint,math.min(550,U.dist(start,endpoint))),green)
        circle(endpoint,35,green)
        if c.config:get('drawInsecTolerance') then
            local ray=U.toward(start,endpoint,320);local dx,dz=ray.x-start.x,ray.z-start.z
            local angle=math.rad(c.config:get('insecAngle'));local cs,sn=math.cos(angle),math.sin(angle)
            for _,side in ipairs({-1,1}) do
                line(start,{x=start.x+dx*cs-dz*sn*side,y=start.y,z=start.z+dx*sn*side+dz*cs},color(35,95,75))
            end
        end
    end
    if i.recipient and U.position(i.recipient.pos) and not i.recipient.dead and (i.recipient.health or 0)>0 then
        circle(i.recipient.pos,65,green)
        local p=U.vector(i.recipient.pos):To2D()
        if p.onScreen then Draw.Text('KICK TO '..(i.recipient.charName or 'ALLY'),13,p.x+18,p.y-30,green) end
    end
    if display then
        local from=myHero.pos
        for n,step in ipairs(display.steps) do
            line(from,step.pos,amber);circle(step.pos,22,amber);from=step.pos
            local p=U.vector(step.pos):To2D()
            if p.onScreen then
                local name=step.kind=='q' and 'Q' or step.kind=='ward' and 'WARD > W' or step.kind:upper()
                Draw.Text(n..' '..name,12,p.x+12,p.y+10,amber)
            end
        end
        if display.walk then line(from,display.walk,amber) end
    end
    if i.alignment and not i.preview then line(myHero.pos,i.alignment.pos,amber) end
    local size=Game.Resolution and Game.Resolution() or {x=1920,y=1080}
    local x,y=math.max(12,size.x*.5-230),math.max(80,size.y-230)
    if Draw.Rect then Draw.Rect(x,y,460,84,Draw.Color(210,15,22,29)) end
    Draw.Text((i.preview and 'PREVIEW  ' or 'INSEC  ')..(i.target.charName or 'TARGET')..'  |  '..(i.kind=='ally' and 'TO ALLY' or 'TO CURSOR'),16,x+12,y+8,white)
    local fallback=i.flashReason and i.flashReason:find('Flash fallback:',1,true)
    local flash=i.flashConsent and 'FLASH APPROVED' or i.preview and 'FLASH MAY BE PROPOSED' or fallback and 'FLASH: NO WARD FALLBACK' or 'NO FLASH'
    local details=flash..'  |  '..(i.resource or 'Finding approach')
    if #details>66 then details=details:sub(1,63)..'...' end
    Draw.Text(details,13,x+12,y+31,amber)
    local previewKey=U.keyLabel(c.config:key('insecPreviewKey'))
    Draw.Text(i.preview and 'Release '..previewKey..': confirm shown route' or i.confirmBlocked and 'Hold '..previewKey..' to revise the plan'
        or 'Hold: continue   Right-click: move   Release: cancel',12,x+12,y+56,white)
end
function O:damageBars()
    local c=self.ctx;local cfg=c.config
    if not cfg:visible('damageBars',c.sdk,c.mode) or not c.damageModel or not Draw.Rect then return end
    local width,height=cfg:get('damageWidth'),cfg:get('damageHeight')
    local selected=cfg:get('damageSelected') and c:locked()
    for _,target in ipairs(c.enemies or {}) do
        local screen=U.valid(target) and U.vector(target.pos):To2D()
        local bar=screen and screen.onScreen and target.hpBar
        local native=bar and U.finite(bar.x) and U.finite(bar.y) and bar.onScreen~=false and (bar.x~=0 or bar.y~=0)
        if not native and screen and screen.onScreen and U.finite(screen.x) and U.finite(screen.y) then
            bar={x=screen.x-width*.5-cfg:get('damageX'),y=screen.y-70-cfg:get('damageY')}
        end
        if bar and U.finite(bar.x) and U.finite(bar.y) and bar.onScreen~=false
            and bar.x>=-width and bar.y>=-100
            and U.finite(target.maxHealth) and target.maxHealth>0
            and (not cfg:get('damageSelected') or U.same(target,selected)) and c:enemyValid(target) then
            local safe,max=c.damageModel:both(target);local cap=math.max(1,target.maxHealth or target.health or 1)
            local x,y=bar.x+cfg:get('damageX'),bar.y+cfg:get('damageY')
            local hp=U.clamp(target.health/cap,0,1)*width
            local function strip(result,offset,col)
                if not U.finite(result.damage) then return end
                local loss=U.clamp(result.damage/cap,0,target.health/cap)*width
                Draw.Rect(x,y+offset,hp,height,color(25,30,35))
                if loss>0 then Draw.Rect(x+hp-loss,y+offset,loss,height,col) end
            end
            if cfg:get('damageSafe') then strip(safe,0,color(65,225,165)) end
            if cfg:get('damageMax') then strip(max,height+1,color(255,175,75)) end
            if cfg:get('damageText') then
                local labels={}
                if cfg:get('damageSafe') and U.finite(safe.damage) then labels[#labels+1]='CON ~'..math.floor(safe.damage) end
                if cfg:get('damageMax') and U.finite(max.damage) then labels[#labels+1]=(max.estimated and 'MAX EST ~' or 'MAX ~')..math.floor(max.damage) end
                if #labels>0 then Draw.Text(table.concat(labels,' / ')..((safe.partial or max.partial) and ' *partial' or ''),12,x,y+height*2+3,color(230,230,240)) end
            end
        end
    end
end
function O:ranges()
    local c=self.ctx;local cfg=c.config
    if myHero.dead or not cfg:get('draw') or not Draw.Circle then return end
    if cfg:visible('drawQRange',c.sdk,c.mode) then circle(myHero.pos,c.profile.qRange,color(90,175,235)) end
    if cfg:visible('drawWRange',c.sdk,c.mode) then circle(myHero.pos,c.profile.wRange,color(65,225,165)) end
    if cfg:visible('drawERange',c.sdk,c.mode) then circle(myHero.pos,c.profile.eRange,color(255,195,75)) end
    if cfg:visible('drawRRange',c.sdk,c.mode) then circle(myHero.pos,c.profile.rRange,color(255,90,100)) end
    if cfg:visible('drawWardRange',c.sdk,c.mode) then circle(myHero.pos,c.wards:range(),color(220,225,235)) end
end
function O:draw()
    local c=self.ctx;if not Draw then return end
    if c.guide and c.config:get('guideOpen') then c.guide:draw();return end
    -- Session heartbeat remains visible even if ordinary plugin drawings were
    -- disabled in a saved menu. It also reports file-write failure explicitly.
    if c.config:get('playtestLogging') then
        local state=c.playtestState=='finished' and 'FINISHED' or (c.logFile and c.logFile~='File logging unavailable' and 'WRITING' or 'UNAVAILABLE')
        Draw.Text('LHO '..require('lho.profiles').build..' | LIVE LOG: '..state..' | #'..tostring(c.playtestSampleSequence or 0)..
            ' @ '..string.format('%.2fs',c.playtestSampleAt or c:now()),16,30,455,color(255,195,75))
        if c.qDebug then Draw.Text(c.qDebug.text,14,30,476,color(255,195,75)) end
        local stopped=c.input.lastFarmStop
        if stopped then Draw.Text('Last auto-jungle stop @ '..string.format('%.1fs',stopped.time or 0)..': '..stopped.reason,
            14,30,497,color(255,195,75)) end
    end
    if not c.config:get('draw') then return end
    local white,green,amber,red=color(220,225,235),color(65,225,165),color(255,195,75),color(255,90,100)
    self:ranges()
    self:damageBars()
    if c.config:visible('drawHUD',c.sdk,c.mode) then
    Draw.Text('Lee Harvey Osward | '..c.profile.id,18,30,190,white)
    Draw.Text(c.status or c.mode,16,30,213,white)
    if c.config:get('diagnostics') and c.qDebug and c:now()-c.qDebug.at<1 and (c.mode=='clear' or c.mode=='farm') then
        Draw.Text(c.qDebug.text,14,30,282,amber)
    end
    Draw.Text('Auto-jungle ['..U.keyLabel(c.config:key('farmKey'))..']: '..(c.config:get('autoJungle') and 'ON' or 'OFF'),14,30,259,white)
    local now=c:now();local level=myHero.levelData and myHero.levelData.lvl
    if not self.smiteDisplayAt or now>=self.smiteDisplayAt+.2 or self.smiteDisplayLevel~=level then
        self.smiteDisplay=c.smite:damage();self.smiteDisplayAt=now;self.smiteDisplayLevel=level
    end
    Draw.Text('Autosmite ['..U.keyLabel(c.config:key('smiteKey'))..']: '..(c.config:get('autosmite') and 'ON' or 'OFF')..
        ' | damage '..self.smiteDisplay,16,30,236,c.config:get('autosmite') and green or amber)
    end
    local p=c.wards.previewState
    if c.config:visible('drawWard',c.sdk,c.mode) and c.input:held('wardKey') and not c.input.wardCancelled and p then
        local col=not p.valid and red or (p.kind=='assisted' or p.kind=='approach') and amber or green
        circle(p.pos,45,col);line(p.raw,p.pos,col)
        if p.path then
            local from=myHero.pos
            for _,point in ipairs(p.path) do line(from,point,amber);from=point end
            circle(p.stand,35,amber);line(p.stand,p.pos,col)
            if p.walkTo then circle(p.walkTo,20,white) end
        end
        if p.raw then circle(p.raw,15,white) end
        if p.pos then
            local s=U.vector(p.pos):To2D()
            if s.onScreen then
                local label=p.valid and p.kind or p.reason or 'Invalid'
                if c.config:get('diagnostics') and c.terrain.provider and c.terrain.provider.static then label=label..' [static map grid]' end
                Draw.Text(label,16,s.x+15,s.y,col)
            end
        end
    end
    local i=c.combat.insec
    if i and c.config:visible('drawInsec',c.sdk,c.mode) then
        self:insecDrawing(i)
    end
    if c.config:visible('drawWard',c.sdk,c.mode) and c.wards.pending then
        local pending=c.wards.pending;circle(pending.pos,45,amber)
        if pending.path then
            local from=myHero.pos
            for index=pending.index,#pending.path do line(from,pending.path[index],amber);from=pending.path[index] end
            line(from,pending.pos,green)
        end
    end
end
return O
