local C={};C.__index=C
local defaults={enabled=true,comboQ=true,comboW=true,comboE=true,comboR=true,harassQ=true,harassW=true,harassE=false,
    lastQ=true,lastW=true,lastE=false,laneQ=true,laneW=true,laneE=false,jungleQ=true,jungleW=true,jungleE=false,
    idleKill=false,turret=false,ignite=true,offensiveWards=true,stasis=true,items=true,smartR=true,
    draw=true,diagnostics=false,wardAssist=true,wardApproach=true,wardRange=600,reuseRadius=100,wardWalkRange=600,
    wardAssistRadius=300,terrainVerified=false,wardFollowCursor=false,wardTolerance=75,minHP=25,maxEnemies=2,
    clearHits=3,stasisHP=20,assistRadius=300}
function C.new(profile)
    local self=setmetatable({values={},nodes={}},C)
    for k,v in pairs(defaults)do self.values[k]=v end
    -- Explicit local recording profile, separate from saved gameplay settings.
    local test=_G.OrbamaTestConfig
    if not test then local ok,value=pcall(require,'OrbamaTestConfig');if ok then test=value end end
    self.capture=type(test)=='table'and test.enabled==true and type(test.katarina)=='table'and test.katarina.diagnostics==true
    if MenuElement then
        self.menu=MenuElement({id='KatarinaController',name='Kata Hari - '..profile.id,type=MENU})
        local labels={combo='Combo',harass='Harass',last='Last hit',lane='Lane clear',jungle='Jungle clear'}
        for _,mode in ipairs({'combo','harass','last','lane','jungle'})do
            self.menu:MenuElement({id=mode,name=labels[mode],type=MENU})
            for _,letter in ipairs({'Q','W','E','R'})do local id=mode..letter
                if defaults[id]~=nil then self.menu[mode]:MenuElement({id=letter,name='Use '..letter,value=defaults[id]});self.nodes[id]=self.menu[mode][letter]end
            end
        end
        local options={{'enabled','Enabled'},{'turret','Allow turret entry'},{'idleKill','Killsecure without held mode'},
            {'ignite','Combo Ignite'},{'items','Offensive item actives'},{'stasis','Emergency stasis'},
            {'smartR','Situational ultimate cancellation'},{'wardAssist','Wall assistance'},{'wardApproach','Approach nearby wall'},
            {'draw','Draw plan'},{'diagnostics','Diagnostic log'}}
        if profile.id=='classic'then options[#options+1]={'offensiveWards','Spend wards for lethal combos'}end
        for _,row in ipairs(options)do self.menu:MenuElement({id=row[1],name=row[2],value=defaults[row[1]]});self.nodes[row[1]]=self.menu[row[1]]end
        for _,row in ipairs({{'minHP','Minimum entry HP %',0,100},{'maxEnemies','Maximum nearby enemies',1,5},{'clearHits','Waveclear minimum hits',1,8},{'stasisHP','Emergency HP %',1,50}})do
            self.menu:MenuElement({id=row[1],name=row[2],value=defaults[row[1]],min=row[3],max=row[4],step=1});self.nodes[row[1]]=self.menu[row[1]]
        end
        self.menu:MenuElement({id='jump',name='Jump toward mouse (hold)',key=string.byte('T')})
        self.menu:MenuElement({id='extended',name='Allow Flash / movement items in Combo (hold)',key=string.byte('G')})
        self.nodes.jump=self.menu.jump;self.nodes.extended=self.menu.extended
    end
    return self
end
function C:get(k)if k=='diagnostics'and self.capture then return true end;local node=self.nodes[k];if node then return node:Value()end;return self.values[k]end
function C:close()if self.menu and self.menu.Hide then pcall(self.menu.Hide,self.menu,true)end end
return C
