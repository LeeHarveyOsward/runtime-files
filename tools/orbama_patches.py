"""Reviewable, count-checked corrections to the pinned GG source."""

def correctness(s):
    def rep(old, new, count=1):
        nonlocal s
        assert s.count(old) == count, (old[:100], s.count(old), count)
        s = s.replace(old, new)
    # Legacy Flash helper shipped enabled with F -> P. That opens the shop
    # for ordinary F-bound Flash. Saved Enabled=true alone is not remap consent.
    rep('self.Menu:MenuElement({id = "Enabled", name = "Enabled", value = true})\n        self.Menu:MenuElement({id = "Flashlol"',
        'self.Menu:MenuElement({id = "Enabled", name = "Enabled", value = false})\n        self.Menu:MenuElement({id = "CustomBinding", name = "Enable custom Flash key remapping", value = false})\n        self.Menu:MenuElement({id = "Flashlol"')
    rep('self.Menu.Flashgos:Value()\n\t\t\tand self.Menu.Enabled:Value()',
        'self.Menu.Flashgos:Value()\n            and self.Menu.CustomBinding:Value()\n            and self.Menu.Flashgos:Key() ~= self.Menu.Flashlol:Key()\n\t\t\tand self.Menu.Enabled:Value()')
    rep('self.Timer = GetTickCount()\n\t\t\tControl.Flash()', 'Control.Flash()')
    rep('''_G.Control.Flash = function()
	if Cursor.Step == 0 then
		Cursor:Add(FlashHelper.Menu.Flashlol:Key(), myHero.pos:Extended(Vector(mousePos), 600))
		return
	end
	FlashHelper.Flash = FlashHelper.Menu.Flashlol:Key()
end''', '''_G.Control.Flash = function()
    -- An explicit programmatic request uses the current Flash summoner slot.
    -- A custom output key requires separate, deliberate remapping opt-in.
    if not FlashHelper:IsReady() or not Cursor:Available() or Cursor.Step ~= 0 or Cursor.Active then return false end
    local key = FlashHelper.FlashSpell == SUMMONER_1 and HK_SUMMONER_1 or HK_SUMMONER_2
    if FlashHelper.Menu.CustomBinding:Value() then key = FlashHelper.Menu.Flashlol:Key() end
    local accepted = Cursor:Add(key, myHero.pos:Extended(Vector(mousePos), 600))
    if accepted then FlashHelper.Timer = GetTickCount() end
    return accepted
end''')
    # Valid high ping is not missing data. Falling back at 250 ms understated
    # the same network delay that governs attack and input acknowledgment.
    for name in ('initialLatency', 'latency'):
        rep(f'{name} < 250 and {name} or Menu.Main.Latency:Value()',
            f'type({name}) == "number" and {name} == {name} and {name} >= 0 and {name} < math.huge and {name} or Menu.Main.Latency:Value()')
    rep('baseResistance = math_max(target.armor - target.bonusArmor, 0)', 'baseResistance = target.armor - target.bonusArmor')
    rep('baseResistance = math_max(target.magicResist - target.bonusMagicResist, 0)', 'baseResistance = target.magicResist - target.bonusMagicResist')
    rep('resistance = resistance - penetrationFlat', 'resistance = math_max(0, resistance - penetrationFlat)')
    rep('local isMoving = obj.pathing.hasMovePath', 'local isMoving = obj.pathing and obj.pathing.hasMovePath')
    # Neutral allegiance is explicit; hosts need not label neutral monsters
    # isEnemy. This includes future boss species without a name whitelist.
    rep('obj.isEnemy and obj.team == 300', 'obj.team == 300')
    rep('aaData == nil\n\t\t\t\t\tor aaData.target == nil', 'aaData ~= nil and aaData.projectileSpeed ~= nil and aaData.windUpTime ~= nil\n                    and aaData.animationTime ~= nil and aaData.animationTime > 0 and (aaData.target == nil')
    rep('or self.ActiveAttacks[attackerHandle] == nil\n\t\t\t\tthen', 'or self.ActiveAttacks[attackerHandle] == nil)\n\t\t\t\tthen')
    rep('local item = args.From:GetItemData(slot)', 'local item = Item:GetSnapshot(args.From).slots[slot]', 2)
    rep('\t\tself.CachedItems = {}\n\t\tif self:UseQss()', '\t\tif self:UseQss()')
    start = s.index('\tGetItemById = function(self, unit, id)')
    end = s.index('\n\tIsReady =', start)
    s = s[:start] + '''\tGetItemById = function(self, unit, id)
        return self:GetSnapshot(unit).ids[id]
    end,
''' + s[end:]
    rep('myHero:GetSpellData(ItemSlots[item]).currentCd == 0', 'unit:GetSpellData(ItemSlots[item]).currentCd == 0')
    rep('self.Hotkey = ItemKeys[item]', 'self.Hotkey = ItemKeys[item]\n            self.ReadySlot = ItemSlots[item]\n            self.ReadyItem = id')
    rep('\t\tif not qssReady then', '\t\tif self.QssPending or not qssReady then')
    rep('''DelayAction(function()
					Control.CastSpell(self.Hotkey)
				end, self.MenuQss.Delay:Value())''', '''local slot, id, key = self.ReadySlot, self.ReadyItem, self.Hotkey
                local generation = Cursor.Generation
                local job = {}; self.QssPending = job
                DelayAction(function()
                    if self.QssPending ~= job then return end
                    self.QssPending = nil
                    local item = myHero:GetItemData(slot)
                    local spell = myHero:GetSpellData(slot)
                    if Cursor.Generation ~= generation or not Orbwalker:IsEnabled()
                        or not self.MenuQss.Enabled:Value() or myHero.dead
                        or GetTickCount() < SummonerSpell.CleanseStartTime + 200
                        or not item or item.itemID ~= id or not spell or spell.currentCd ~= 0 then return end
                    local current = Buff:GetBuffs(myHero)
                    local currentTypes = GetBuffTypes(self.MenuQssBuffs)
                    for j=1,#current do
                        if current[j].duration > 0 and currentTypes[current[j].type] then
                            Cursor:SendKeys(key, "qss"); return
                        end
                    end
                end, self.MenuQss.Delay:Value())''')
    rep('\t\t\t\t\tControl.CastSpell(self.Hotkey)', '\t\t\t\t\tCursor:SendKeys(self.Hotkey, "qss")')
    rep('\tUseCleanse = function(self, s1, s2)', '\tUseCleanse = function(self, s1, s2)\n        if Cursor.Automation and not Cursor.Automation:AllowsBuiltin("cleanse") then return false end')
    rep('\tUseQss = function(self)', '\tUseQss = function(self)\n        if Cursor.Automation and not Cursor.Automation:AllowsBuiltin("qss") then return false end')
    rep('local job = {}; self.QssPending = job', 'local job = {}; self.QssPending = job\n                local claimEpoch = Cursor.Automation and Cursor.Automation:GetAutomation("qss").epoch')
    rep('if Cursor.Generation ~= generation or not Orbwalker:IsEnabled()', 'if Cursor.Automation and not Cursor.Automation:AllowsBuiltin("qss",claimEpoch) then return end\n                    if Cursor.Generation ~= generation or not Orbwalker:IsEnabled()')
    # Copy AND deduplicate before filtering/sorting either public TS entry point.
    rep('a = a or 20000\n\t\tdmgType', '''a = a or 20000
        if type(a) == "table" then
            local copy, seen = {}, {}
            for i=1,#a do
                local id = a[i].networkID or a[i].handle or a[i]
                if not seen[id] then seen[id]=true; copy[#copy+1]=a[i] end
            end
            a=copy
        end
		dmgType''', 2)
    rep('table_insert(stackA, obj)\n\t\t\t\t\tend', 'table_insert(stackA, obj)\n                        break\n\t\t\t\t\tend')
    # Prediction caches are public and must expire even when farming is skipped.
    rep('local healthTimer = GameTimer()', 'local healthTimer = GameTimer()\n        self.TargetsHealth = {}\n        self.AttackersDamage = {}\n        self.IsLastHitable = false')
    rep('local healthTimer = GameTimer()', 'local healthTimer = GameTimer()\n        self.IncomingReady = false\n        self.PendingUnkillable = nil\n        self.PendingSpellTicks = false')
    rep('for attackerHandle, attack in pairs(self.ActiveAttacks) do', 'for attackerHandle, attack in pairs(self:GetIncoming(handle)) do\n            self.PredictionWork.candidates = self.PredictionWork.candidates + 1', 2)
    start = s.index('\tOnTick = function(self)', s.index('Orbwalker = {'))
    end = s.index('\t\tif Cursor.Step > 0 then', start)
    s = s[:start] + '''\tOnTick = function(self)
        if not self:IsEnabled() then return end
''' + s[end:]
    rep('IsEnabled = function(self)\n\t\treturn true', 'IsEnabled = function(self)\n\t\treturn self.Menu.Enabled:Value() == true')
    # Defer public health callbacks and spell dispatch to their original phase.
    rep('self.OnUnkillableC[i](target)', 'self.PendingUnkillable = self.PendingUnkillable or {}\n                self.PendingUnkillable[#self.PendingUnkillable+1] = {callback=self.OnUnkillableC[i],target=target}')
    rep('self.Spells[i]:Tick()', 'self.PendingSpellTicks = true')
    rep('self.Spells[i]:Reset()', 'self.PendingSpellResets = true')
    # Cache normalized buff names without changing the public name field.
    rep('local _b = b\n\t\tfunction metatable', 'local _b = b\n        members.lowerName = (b.name or ""):lower()\n\t\tfunction metatable')
    s = s.replace('buff.name:lower()', '(buff.lowerName or buff.name:lower())')
    s = s.replace('buffs[i].name:lower()', '(buffs[i].lowerName or buffs[i].name:lower())')
    # Discovery tracks identity regardless of visibility; consumer filtering remains live.
    for plural, singular, key, period in [('Minions', 'Minion', 'm', '.20'), ('Wards','Ward','w','.10'), ('Turrets','Turret','t','.50')]:
        start = s.index('\tFetchCached' + plural + ' =')
        end = s.index('\n\tend,', start) + len('\n\tend,')
        s = s[:start] + f'''\tFetchCached{plural} = function(self)
        local timer, count = GameTimer(), Game{singular}Count()
        if self.DiscoveryCounts == nil then self.DiscoveryCounts = {{}} end
        if self.DiscoveryCounts.{key} ~= count or self.TempCacheBuffer.{key} <= timer then
            self.DiscoveryCounts.{key} = count
            ClearArray(self.TempCached{plural})
            if count and count > 0 and count < 1000 then
                for i=1,count do
                    local o=Game{singular}(i)
                    if o and o.valid and not o.dead then table_insert(self.TempCached{plural}, o) end
                end
            end
            self.TempCacheBuffer.{key} = timer + {period}
        end
        return self.TempCached{plural}
    end,''' + s[end:]
    # Public result arrays survive subsequent cycles. Private discovery buffers stay reused.
    for name in ['Heroes','Minions','Turrets','Wards','Plants']:
        old=f'for i = #self.{name}, 1, -1 do\n\t\t\t\tself.{name}[i] = nil\n\t\t\tend'
        rep(old, f'self.{name} = {{}}')
    return s
