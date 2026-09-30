-- spec/warbound_spec.lua
-- Kriegsmeutengebunden-Uebersicht (1.7.0): Erkennung warbound Items und
-- eigene Ansicht "Kriegsmeute" im Inventar-Tab (Char X hat dieses Teil).
local mock = require("spec.wow_mock")

describe("Kriegsmeutengebunden-Uebersicht (1.7.0)", function()
	local Exo, Tab

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
				[2] = { id = 903, count = 1 },
				[3] = { id = 777, count = 20 }, -- BoE -> darf nicht auftauchen
			} },
		})
		Store:WriteCharacterData("Default.Testrealm.Anna", "bank", {
			[6] = { size = 98, free = 97, items = { [1] = { id = 901, count = 1 } } },
		})

		-- Borg hat NUR normale Items -> taucht gar nicht auf
		local borg = Store:GetOrCreateCharacter("Default.Testrealm.Borg")
		borg.meta.name = "Borg"
		borg.meta.realm = "Testrealm"
		Store:WriteCharacterData("Default.Testrealm.Borg", "bags", {
			[0] = { size = 16, free = 15, items = { [1] = { id = 777, count = 5 } } },
		})

		-- Caro auf anderem Realm (alphabetisch VOR Testrealm)
		local caro = Store:GetOrCreateCharacter("Default.Arealm.Caro")
		caro.meta.name = "Caro"
		caro.meta.realm = "Arealm"
		Store:WriteCharacterData("Default.Arealm.Caro", "bags", {
			[0] = { size = 16, free = 15, items = { [1] = { id = 902, count = 1 } } },
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
		Tab = Exo.UI.InventoryTab
		Tab.targetIndex = 1
		Tab.sortBy, Tab.sortDesc = "total", true
		Tab.viewMode = "list"
		Tab.mode = "browse"
		Tab.groupModeIndex = 1
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
			-- Borg (nur BoE) fehlt
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

	describe("Inventar-Tab, Modus Kriegsmeute", function()
		it("BuildWarboundRows: Kopfzeile je Char, Items darunter", function()
			local rows = Tab.BuildWarboundRows(Tab.GatherWarbound(), "total", true)
			assert.equal(5, #rows) -- Caro-Kopf, 1 Item, Anna-Kopf, 2 Items
			assert.is_true(rows[1].section)
			assert.truthy(rows[1].label:find("Caro"))
			assert.equal(902, rows[2].itemID)
			assert.is_true(rows[3].section)
			assert.truthy(rows[3].label:find("Anna"))
			assert.equal(901, rows[4].itemID) -- total 3 vor total 1
			assert.equal(903, rows[5].itemID)
			assert.equal("Kriegsgebundenes Schwert", rows[4].name)
		end)

		it("Render blendet Browse-UI aus und fuellt die Liste", function()
			local content = CreateFrame("Frame")
			Tab:Render(content)
			assert.is_not_nil(Tab._GetModeButtons().warbound)

			Tab:SetMode("warbound")
			local scroller = Tab._GetScroller()
			assert.equal(5, #scroller.items)
			assert.is_true(scroller.items[1].section)
			assert.truthy(Tab._GetFooter():GetText():find("bei 2 Charakteren"))
			assert.truthy(Tab._GetFooter():GetText():find("5 Stueck"))
		end)

		it("Header-Sortierung wirkt auch in der Kriegsmeuten-Ansicht", function()
			local content = CreateFrame("Frame")
			Tab:Render(content)
			Tab:SetMode("warbound")
			Tab:OnHeaderClick("name") -- Namen aufsteigend
			local data = Tab._GetScroller().items
			-- Anna-Sektion: "Gebunden-bis-Anlegen-Helm" vor "Kriegsgebundenes Schwert"
			assert.equal(903, data[4].itemID)
			assert.equal(901, data[5].itemID)
		end)

		it("zeigt Leer-Hinweis ohne warbound Items", function()
			Exo.Store:DeleteCharacter("Default.Testrealm.Anna")
			Exo.Store:DeleteCharacter("Default.Arealm.Caro")
			local content = CreateFrame("Frame")
			Tab:Render(content)
			Tab:SetMode("warbound")
			assert.truthy(Tab._GetFooter():GetText():find("Keine kriegsmeutengebundenen"))
		end)

		it("Rueckkehr zum Bestand zeigt wieder den Ziel-Button", function()
			local content = CreateFrame("Frame")
			Tab:Render(content)
			Tab:SetMode("warbound")
			Tab:SetMode("browse")
			assert.is_true(Tab._GetTargetButton():IsShown())
		end)
	end)
end)
