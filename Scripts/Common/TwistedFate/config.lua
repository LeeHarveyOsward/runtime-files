local M={}
function M.new(p)
    local menu=MenuElement({id='OrbamaTwistedFate',name='Card Marx - '..p.id,type=MENU})
    local nodes={}
    local function add(id,name,value,parent)
        parent=parent or menu;parent:MenuElement({id=id,name=name,value=value});nodes[id]=parent[id]
    end
    add('enabled','Enabled',true)
    menu:MenuElement({id='cards',name='Manual card (tap to select)',type=MENU})
    for _,row in ipairs({{'gold','Gold',84},{'red','Red',71},{'blue','Blue',72}})do
        menu.cards:MenuElement({id=row[1],name=row[2]..': tap to select / hold to repeat',key=row[3],toggle=false});nodes[row[1]]=menu.cards[row[1]]
    end
    for _,name in ipairs({'COMBO','HARASS','LASTHIT','LANECLEAR','JUNGLECLEAR','FLEE'})do
        menu:MenuElement({id=name,name=name,type=MENU})
        add(name..'Q','Use Q',name~='FLEE',menu[name]);add(name..'W','Use cards',true,menu[name])
    end
    add('interrupt','Gold: interrupt channels',true)
    add('peel','Gold: defend against approaching enemies',true)
    add('autoHarass','Harass without held mode',false)
    add('farmHarass','Harass during LaneClear',false)
    add('teleportCards','Prepare card after manual Gate',true)
    if p.autoRVerified then add('classicR','R slow in Combo / Flee',true)end
    add('defense','Defensive items and summoners',true)
    add('offense','Offensive items and Ignite / Exhaust',true)
    add('ghost','Ghost in Combo / Flee',false)
    add('level','Dynamic skill leveling',true)
    add('draw','Draw current intention',true)
    add('diagnostics','Record bounded diagnostics',false)
    local c={menu=menu,nodes=nodes}
    function c:get(id)return self.nodes[id] and self.nodes[id]:Value()end
    function c:key(id)return self.nodes[id] and self.nodes[id]:Key()end
    return c
end
return M
