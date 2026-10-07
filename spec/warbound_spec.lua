-- spec/warbound_spec.lua
-- Kriegsmeute-Reiter (1.8.0): "KM-Bank" (Inhalt der Kriegsmeutenbank) und
-- "KM-Items" (kriegsmeutengebundene Items je Charakter) als eigene Reiter,
-- inkl. Hover-Tooltip. Dazu die Erkennungslogik aus 1.7.0/1.7.1.
local mock = require("spec.wow_mock")

describe("Kriegsmeute-Reiter (1.8.0)", function()
	local Exo, BankTab, ItemsTab

	-- 901 = Warbound (ToBnetAccount), 902 = BoA (ToWoWAccount),
	-- 903 = "Kriegsmeutengebunden bis zum Anlegen", 777 = normales BoE
	local function seed()
		local Store = Exo.Store

		local anna = Store:GetOrCreateCharacter("Default.Testrealm.Anna")
		anna.meta.name = "Anna"
		anna.meta.realm = "Testrealm"
		anna.meta.classID = 8 -- Magier
		Store:WriteCharacterData("Default.Testrealm.Anna", "bags", {
			[0] = { size = 16, free = 12, items = {
				[1] = { id = 901, count = 2 },
				[2] = { id = 903, count = 1, wb = true }, -- noch NICHT angelegt
				[3] = { id = 777, count = 20 }, -- BoE -> darf nicht auftauchen
			} },
		})
		Store:WriteCharacterData("Default.Testrealm.Anna", "bank", {
			[6] = { size = 98, free = 97, items = { [1] = { id = 901, count = 1 } } },
		})

		-- Borg hat NUR normale Items -> taucht in KM-Items nicht auf
		local borg = Store:GetOrCreateCharacter("Default.Testrealm.Borg")
		borg.meta.name = "Borg"
		borg.meta.realm = "Testrealm"
		Store:WriteCharacterData("Default.Testrealm.Borg", "bags", {
			[0] = { size = 16, free = 14, items = {
				[1] = { id = 777, count = 5 },
				-- Typ 9, aber OHNE wb-Flag = schon angelegt -> seelengebunden,
				-- nicht mehr verschiebbar, darf NICHT auftauchen (1.8.1)
				[2] = { id = 903, count = 1 },
			} },
		})

		-- Caro auf anderem Realm (alphabetisch VOR Testrealm)
		local caro = Store:GetOrCreateCharacter("Default.Arealm.Caro")
		caro.meta.name = "Caro"
		caro.meta.realm = "Arealm"
		Store:WriteCharacterData("Default.Arealm.Caro", "bags", {
			[0] = { size = 16, free = 15, items = { [1] = { id = 902, count = 1 } } },
		})

		-- Kriegsmeutenbank selbst (fuer den KM-Bank-Reiter)
		Store:WriteAccountData("warbandBank", {
			[12] = { size = 98, free = 96, items = {
				[1] = { id = 901, count = 40 },
				[2] = { id = 777, count = 7 },
			} },
		})

		mock.SetItemNames({
			[901] = "Kriegsgebundenes Schwert",
			[902] = "Erbstueck-Umhang",
			[903] = "Gebunden-bis-Anlegen-Helm",
			[777] = "Friedensblume",
		})
		mock.SetItemDetails({
			[901] = { bindType = 8, quality = 4, icon = 1111 },
			[902] = { bindType = 7, quality = 7, icon = 2222 },
			[903] = { bindType = 9, quality = 3, icon = 3333 },
			[777] = { bindType = 2, quality = 1, icon = 4444 },
		})
	end

	before_each(function()
		mock.Reset()
		Exo = mock.LoadExoCore()
		mock.SimulateLogin()
		mock.LoadExoUI()
		BankTab = Exo.UI.WarbandBankTab
		ItemsTab = Exo.UI.WarboundTab
		BankTab.sortBy, BankTab.sortDesc = "total", true
		ItemsTab.sortBy, ItemsTab.sortDesc = "total", true
		BankTab.viewMode, ItemsTab.viewMode = "list", "list"
		Exo.Store:DeleteCharacter(Exo.Store:GetCurrentKey())
		seed()
	end)

	describe("WowAPI.IsWarbound", function()
		it("erkennt alle drei Kriegsmeuten-Bindungstypen (7/8/9)", function()
			assert.is_true(Exo.WowAPI.IsWarbound(901))
			assert.is_true(Exo.WowAPI.IsWarbound(902))
			assert.is_true(Exo.WowAPI.IsWarbound(903))
		end)

		it("lehnt BoE und unbekannte Items ab", function()
			assert.is_false(Exo.WowAPI.IsWarbound(777))
			assert.is_false(Exo.WowAPI.IsWarbound(999999)) -- kein bindType -> false
		end)
	end)

	describe("API.GetWarboundByCharacter", function()
		it("liefert nur Chars mit warbound Items, Realm/Name-sortiert", function()
			local groups = Exo.API.GetWarboundByCharacter()
			assert.equal(2, #groups)
			assert.equal("Caro", groups[1].name) -- Arealm vor Testrealm
			assert.equal("Anna", groups[2].name)
			for _, group in ipairs(groups) do
				assert.is_not.equal("Borg", group.name)
			end
		end)

		it("aggregiert Taschen + Bank pro Item", function()
			local groups = Exo.API.GetWarboundByCharacter()
			local anna = groups[2]
			local byId = {}
			for _, item in ipairs(anna.items) do byId[item.itemID] = item end
			assert.equal(2, #anna.items)          -- 901 + 903, kein 777
			assert.equal(2, byId[901].bags)
			assert.equal(1, byId[901].bank)
			assert.equal(3, byId[901].total)
			assert.equal(1, byId[903].total)
			assert.is_nil(byId[777])
		end)
	end)

	describe("Nur verschiebbare Items (1.8.1)", function()
		it("IsPermanentWarbound: 7/8 ja, 9 und BoE nein", function()
			assert.is_true(Exo.WowAPI.IsPermanentWarbound(901))  -- ToBnetAccount
			assert.is_true(Exo.WowAPI.IsPermanentWarbound(902))  -- ToWoWAccount
			assert.is_false(Exo.WowAPI.IsPermanentWarbound(903)) -- bis zum Anlegen
			assert.is_false(Exo.WowAPI.IsPermanentWarbound(777)) -- BoE
		end)

		it("bereits angelegte 'bis zum Anlegen'-Items bleiben draussen", function()
			-- Borg hat Item 903 OHNE wb-Flag (= beim Scan schon seelengebunden)
			local groups = Exo.API.GetWarboundByCharacter()
			for _, group in ipairs(groups) do
				assert.is_not.equal("Borg", group.name)
			end
			-- Annas 903 MIT wb-Flag (noch nicht angelegt) ist weiter dabei
			local anna = groups[2]
			local found = false
			for _, item in ipairs(anna.items) do
				if item.itemID == 903 then found = true end
			end
			assert.is_true(found)
		end)
	end)

	describe("Exemplar-Bindung 'bis zum Anlegen' (1.7.1)", function()
		-- 555 ist vom TYP her BoE (bindType 2) -- nur das konkrete Exemplar
		-- in Tasche 0, Platz 4 ist "kriegsmeutengebunden bis zum Anlegen".
		local function seedLiveBags()
			mock.SetContainer(0, 16, {
				[4] = { id = 555, count = 1 },
				[5] = { id = 777, count = 3 }, -- normales BoE daneben
			})
			mock.SetWarboundSlots({ [0] = { [4] = true } })
			mock.SetItemNames({ [555] = "Klinge der Meute", [777] = "Friedensblume" })
			mock.SetItemDetails({
				[555] = { bindType = 2, quality = 3, icon = 5555 },
				[777] = { bindType = 2, quality = 1, icon = 4444 },
			})
		end

		it("ScanBags speichert das wb-Flag am Exemplar", function()
			seedLiveBags()
			Exo.Collectors.Containers.ScanBags()
			local me = Exo.Store:GetCharacter(Exo.Store:GetCurrentKey())
			assert.is_true(me.bags[0].items[4].wb)
			assert.is_nil(me.bags[0].items[5].wb)
		end)

		it("BoE-Typ mit warbound Exemplar erscheint in der Uebersicht", function()
			seedLiveBags()
			Exo.Collectors.Containers.ScanBags()
			local groups = Exo.API.GetWarboundByCharacter()
			local found, wrong = false, false
			for _, group in ipairs(groups) do
				for _, item in ipairs(group.items) do
					if item.itemID == 555 then found = true end
					if item.itemID == 777 then wrong = true end
				end
			end
			assert.is_true(found)   -- Exemplar-Bindung erkannt
			assert.is_false(wrong)  -- normales BoE bleibt draussen
		end)

		it("wb-Flag wirkt auch OHNE gecachte Item-Infos", function()
			-- Item 888 ist dem Client voellig unbekannt (kein GetItemInfo);
			-- das beim Scan gespeicherte Flag muss trotzdem reichen.
			local Store = Exo.Store
			local dora = Store:GetOrCreateCharacter("Default.Testrealm.Dora")
			dora.meta.name = "Dora"
			dora.meta.realm = "Testrealm"
			Store:WriteCharacterData("Default.Testrealm.Dora", "bags", {
				[0] = { size = 16, free = 15, items = {
					[1] = { id = 888, count = 1, wb = true },
				} },
			})
			local rows = ItemsTab.BuildWarboundRows(ItemsTab.GatherWarbound(), "total", true)
			local label
			for _, row in ipairs(rows) do
				if row.itemID == 888 then label = row.name end
			end
			assert.equal("Item 888", label) -- Fallback-Name, solange ungecacht
		end)
	end)

	describe("Reiter KM-Items (kriegsmeutengebunden je Charakter)", function()
		it("ist als eigener Reiter registriert", function()
			assert.equal(ItemsTab, Exo.UI.tabsById["warbound"])
			assert.equal("KM-Items", ItemsTab.label)
		end)

		it("BuildWarboundRows: Kopfzeile je Char, Items darunter", function()
			local rows = ItemsTab.BuildWarboundRows(ItemsTab.GatherWarbound(), "total", true)
			assert.equal(5, #rows) -- Caro-Kopf, 1 Item, Anna-Kopf, 2 Items
			assert.is_true(rows[1].section)
			assert.truthy(rows[1].label:find("Caro"))
			assert.equal(902, rows[2].itemID)
			assert.is_true(rows[3].section)
			assert.truthy(rows[3].label:find("Anna"))
			assert.equal(901, rows[4].itemID) -- total 3 vor total 1
			assert.equal(903, rows[5].itemID)
		end)

		it("Render fuellt Liste und Fusszeile ('Anna hat 2 Items...')", function()
			local content = CreateFrame("Frame")
			ItemsTab:Render(content)
			local scroller = ItemsTab._GetScroller()
			assert.equal(5, #scroller.items)
			assert.is_true(scroller.items[1].section)
			-- Kopfzeile traegt die Item-Anzahl des Chars
			assert.equal(2, scroller.items[3].count) -- Anna hat 2 Items
			assert.truthy(ItemsTab._GetFooter():GetText():find("bei 2 Charakteren"))
			assert.truthy(ItemsTab._GetFooter():GetText():find("5 Stueck"))
		end)

		it("Hover ueber eine Item-Zeile triggert den GameTooltip", function()
			local content = CreateFrame("Frame")
			ItemsTab:Render(content)
			local shownID
			_G.GameTooltip.SetItemByID = function(_, id) shownID = id end
			local row = ItemsTab._GetScroller().rows[2] -- Caros Erbstueck-Umhang
			row._scripts.OnEnter(row)
			assert.equal(902, shownID)
			-- Kopfzeilen (Char-Sektionen) zeigen KEINEN Tooltip
			shownID = nil
			local headerRow = ItemsTab._GetScroller().rows[1]
			headerRow._scripts.OnEnter(headerRow)
			assert.is_nil(shownID)
		end)

		it("Header-Klick sortiert um", function()
			local content = CreateFrame("Frame")
			ItemsTab:Render(content)
			ItemsTab:OnHeaderClick("name") -- Namen aufsteigend
			local items = ItemsTab._GetScroller().items
			-- Anna-Sektion: "Gebunden-bis-Anlegen-Helm" vor "Kriegsgebundenes Schwert"
			assert.equal(903, items[4].itemID)
			assert.equal(901, items[5].itemID)
		end)

		it("zeigt Leer-Hinweis ohne warbound Items", function()
			Exo.Store:DeleteCharacter("Default.Testrealm.Anna")
			Exo.Store:DeleteCharacter("Default.Arealm.Caro")
			local content = CreateFrame("Frame")
			ItemsTab:Render(content)
			assert.truthy(ItemsTab._GetFooter():GetText():find("Keine kriegsmeutengebundenen"))
		end)
	end)

	describe("Reiter KM-Bank (Kriegsmeutenbank selbst)", function()
		it("ist als eigener Reiter registriert", function()
			assert.equal(BankTab, Exo.UI.tabsById["warbandbank"])
			assert.equal("KM-Bank", BankTab.label)
		end)

		it("listet den Bank-Inhalt mit Fusszeile inkl. freier Plaetze", function()
			local content = CreateFrame("Frame")
			BankTab:Render(content)
			local items = BankTab._GetScroller().items
			assert.equal(2, #items)
			assert.equal(901, items[1].itemID) -- 40 Stueck zuerst (total desc)
			assert.equal(777, items[2].itemID)
			assert.truthy(BankTab._GetFooter():GetText():find("2 Items"))
			assert.truthy(BankTab._GetFooter():GetText():find("47 Stueck"))
			assert.truthy(BankTab._GetFooter():GetText():find("Frei: 96/98"))
		end)

		it("Hover triggert den GameTooltip auch hier", function()
			local content = CreateFrame("Frame")
			BankTab:Render(content)
			local shownID
			_G.GameTooltip.SetItemByID = function(_, id) shownID = id end
			local row = BankTab._GetScroller().rows[1]
			row._scripts.OnEnter(row)
			assert.equal(901, shownID)
		end)

		it("zeigt Scan-Hinweis, wenn die Kriegsmeutenbank leer/ungescannt ist", function()
			Exo.Store:WriteAccountData("warbandBank", {})
			local content = CreateFrame("Frame")
			BankTab:Render(content)
			assert.truthy(BankTab._GetFooter():GetText():find("Bankfach oeffnen"))
		end)
	end)

	describe("Symbolansicht (1.9.1)", function()
		it("KM-Items: Char-Kopfzeilen bleiben, Items werden Icon-Zeilen", function()
			local content = CreateFrame("Frame")
			ItemsTab:Render(content)
			Exo.UI.ItemList.OnViewClick(ItemsTab)
			assert.equal("icons", ItemsTab.viewMode)
			local rows = ItemsTab._GetIconScroller().items
			assert.equal(4, #rows) -- Caro-Kopf, 1 Icon-Zeile, Anna-Kopf, 1 Icon-Zeile
			assert.is_true(rows[1].section)
			assert.equal(1, #rows[2].icons)
			assert.is_true(rows[3].section)
			assert.equal(2, #rows[4].icons)
			assert.equal("Liste", ItemsTab._GetViewButton():GetText())
		end)

		it("KM-Bank: Icon-Raster mit Stueckzahl am Slot", function()
			local content = CreateFrame("Frame")
			BankTab:Render(content)
			Exo.UI.ItemList.OnViewClick(BankTab)
			local rows = BankTab._GetIconScroller().items
			assert.equal(1, #rows)
			assert.equal(2, #rows[1].icons)
			-- Slot 1 = Item 901 (40 Stueck, total-desc sortiert)
			local slot = BankTab._GetIconScroller().rows[1].slots[1]
			assert.equal(901, slot._itemID)
			assert.truthy(slot.count:GetText():find("40"))
		end)

		it("Umschalten zurueck zur Liste zeigt wieder Zeilen + Header", function()
			local content = CreateFrame("Frame")
			BankTab:Render(content)
			Exo.UI.ItemList.OnViewClick(BankTab)
			Exo.UI.ItemList.OnViewClick(BankTab)
			assert.equal("list", BankTab.viewMode)
			assert.equal(2, #BankTab._GetScroller().items)
			assert.equal(0, #BankTab._GetIconScroller().items)
		end)
	end)

	describe("Inventar-Tab aufgeraeumt", function()
		it("hat den Kriegsmeute-Modus nicht mehr (nur Bestand|Suche)", function()
			local Tab = Exo.UI.InventoryTab
			Tab.targetIndex, Tab.mode, Tab.viewMode = 1, "browse", "list"
			local content = CreateFrame("Frame")
			Tab:Render(content)
			local buttons = Tab._GetModeButtons()
			assert.is_not_nil(buttons.browse)
			assert.is_not_nil(buttons.search)
			assert.is_nil(buttons.warbound)
			assert.is_nil(Tab.GatherWarbound) -- Logik lebt jetzt im KM-Items-Reiter
		end)
	end)
end)
