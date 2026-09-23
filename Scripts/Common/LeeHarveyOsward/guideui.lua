local Links=require('lho.guidelinks')
local widths=require('lho.guidefont')
local UI={};UI.__index=UI
local colors={on={91,231,186},off={247,145,154},topic={139,184,255},cycle={206,170,255},text={222,233,242}}
local function advance(s,font)
    local width=0
    for i=1,#s do width=width+(widths[s:byte(i)] or 8) end
    return width*font/14
end
function UI.pointer()
    if not Game.cursorPos then return end
    local ok,p=pcall(Game.cursorPos)
    if ok and p and type(p.x)=='number' and type(p.y)=='number' then return p end
end
function UI.inside(p,r)
    return p and p.x>=r.x and p.x<r.x+r.w and p.y>=r.y and p.y<r.y+r.h
end
function UI.new(guide,x,y,scale,page)
    guide.hits={};guide.hitPage=page
    guide.panel={x=x,y=y,w=850*scale,h=620*scale}
    return setmetatable({guide=guide,x=x,y=y,scale=scale,pointer=UI.pointer()},UI)
end
function UI:rect(x,y,w,h,color,a)
    local s=self.scale
    Draw.Rect(math.floor(self.x+x*s),math.floor(self.y+y*s),math.ceil(w*s),math.ceil(h*s),
        Draw.Color(a or 250,color[1],color[2],color[3]))
end
function UI:text(label,x,y,font,color)
    local s=self.scale
    Draw.Text(label,math.max(10,math.floor(font*s)),math.floor(self.x+x*s),math.floor(self.y+y*s),
        Draw.Color(255,color[1],color[2],color[3]))
end
function UI:hit(x,y,w,h,link)
    local s=self.scale
    local hit={x=self.x+x*s,y=self.y+y*s,w=w*s,h=h*s,link=link}
    self.guide.hits[#self.guide.hits+1]=hit
    if UI.inside(self.pointer,hit) then self.hover=link;return true end
end
function UI:rich(label,x,y,width,font,rules,base,draw)
    local lineHeight=math.max(18,font+4);local px,py=0,0
    local measured=math.max(10,math.floor(font*self.scale))/self.scale
    local space=advance(' ',measured)
    local guide=self.guide;guide.spanCache=guide.spanCache or {}
    local cached=guide.spanCache[rules]
    if not cached then cached={};guide.spanCache[rules]=cached end
    if not cached[label] then cached[label]=Links.spans(label,rules) end
    for _,span in ipairs(cached[label]) do
        local leading=span.text:match('^(%s+)')
        if leading then
            if leading:find('\n',1,true) then px=0;py=py+lineHeight else px=px+space end
        end
        for word,gap in span.text:gmatch('([^%s]+)(%s*)') do
            local w=advance(word,measured)+.35
            if px>0 and px+w>width then px=0;py=py+lineHeight end
            if draw then
                local color=base or colors.text
                if span.link then
                    local active=Links.active(self.guide.ctx.config,span.link)
                    color=span.link.topic and colors.topic or active==nil and colors.cycle or active and colors.on or colors.off
                    if self:hit(x+px-1,y+py,w+2,lineHeight,span.link) then
                        self:rect(x+px-2,y+py-1,w+4,lineHeight,{40,58,73})
                    end
                    self:rect(x+px,y+py+font+2,w,1,color,180)
                end
                self:text(word,x+px,y+py,font,color)
            end
            px=px+w
            if gap:find('\n',1,true) then px=0;py=py+lineHeight
            elseif #gap>0 then px=px+space end
        end
    end
    return py+lineHeight
end
function UI:hint()
    local link=self.hover;local cfg=self.guide.ctx.config
    if not link then return 'Mint: on   /   Coral: off   /   Blue: topic' end
    if link.close then return 'Close the guide' end
    if link.topic then return 'Open '..self.guide.titles[link.topic] end
    if link.key=='aimLock' then return 'Click to change when the kick direction locks' end
    return 'Click to '..(Links.active(cfg,link) and 'disable ' or 'enable ')..link.label
end
return UI
