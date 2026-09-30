-- spec/release_1_5_spec.lua
-- Alt-Rollen + Bag-Details (1.5.0)
local mock = require("spec.wow_mock")

describe("Release 1.5.0 (Rollen + Bag-Details)", function()
	local Exo, Detail

	local function seedChar(charKey, opts)
		opts = opts or {}
		local char = Exo.Store:GetOrCreateCharacter(charKey)
		local _, realm, name = Exo.Schema.ParseCharKey(charKey)
		char.meta.name = name
		char.meta.realm = realm
		char.meta.classID = opts.classID or 1
		char.equipment = { avgItemLevelEquipped = opts.ilvl or 100, slots = {} }
		if opts.bags then
			Exo.Store:WriteCharacterData(charKey, "bags", opts.bags)
		end
		return char
	end

	before_each(function()
		mock.Reset()
		Exo = mock.LoadExoCore()
		mock.SimulateLogin()
		mock.LoadExoUI()
		Detail = Exo.UI.CharacterDetail
	end)

	describe("Rollen", function()
		it("CycleRole schaltet keine -> Main -> Bank -> ... -> keine", function()
			local key = "Default.Testrealm.Anna"
			seedChar(key)
			assert.is_nil(Detail.GetRole(key))
			Detail.CycleRole(key)
			assert.equal("main", Detail.GetRole(key))
			Detail.CycleRole(key)
			assert.equal("bank", Detail.GetRole(key))
			Detail.CycleRole(key)
			Detail.CycleRole(key)
			assert.equal("gatherer", Detail.GetRole(key))
			Detail.CycleRole(key)
			assert.is_nil(Detail.GetRole(key))
		end)

		it("migriert die alte Bank-Twink-Markierung", function()
			local key = "Default.Testrealm.Alt"
			seedChar(key)
			Exo.API.SetOption("bankalt." .. key, true) -- Altbestand (0.17.0)
			assert.equal("bank", Detail.GetRole(key))
			assert.is_true(Detail.IsBankAlt(key))
			Detail.SetRole(key, "crafter") -- raeumt das Alt-Flag auf
			assert.is_nil(Exo.API.GetOption("bankalt." .. key))
			assert.equal("crafter", Detail.GetRole(key))
		end)

		it("Uebersicht zeigt den Rollen-Tag", function()
			seedChar("Default.Testrealm.Anna")
			Detail.SetRole("Default.Testrealm.Anna", "crafter")
			local rows = Exo.UI.OverviewTab.BuildModuleRows("chars")
			local all = ""
			for _, row in ipairs(rows) do all = all .. row.text .. "\n" end
			assert.matches("%[Crafter%]", all)
		end)
	end)

	describe("Matrix-Rollen-Filter", function()
		before_each(function()
			seedChar("Default.Testrealm.Anna", { ilvl = 480 })
			seedChar("Default.Testrealm.Bob", { ilvl = 460 })
			Detail.SetRole("Default.Testrealm.Bob", "bank")
			Exo.UI.CharactersTab.roleFilter = nil
		end)

		it("filtert BuildMatrix nach Rolle", function()
			local Chars = Exo.UI.CharactersTab
			assert.is_true(#Chars.BuildMatrix().chars >= 3) -- inkl. Login-Char
			Chars.roleFilter = "bank"
			local matrix = Chars.BuildMatrix()
			assert.equal(1, #matrix.chars)
			assert.equal("Bob", matrix.chars[1].name)
			Chars.roleFilter = nil
		end)

		it("CycleRoleFilter laeuft durch alle Rollen zurueck zu Alle", function()
			local Chars = Exo.UI.CharactersTab
			Chars:CycleRoleFilter()
			assert.equal("main", Chars.roleFilter)
			for _ = 1, 3 do Chars:CycleRoleFilter() end
			assert.equal("gatherer", Chars.roleFilter)
			Chars:CycleRoleFilter()
			assert.is_nil(Chars.roleFilter)
		end)
	end)

	describe("Suche: Rollen-Filter", function()
		it("behaelt nur Treffer von Chars der Rolle", function()
			seedChar("Default.Testrealm.Anna", { bags = {
				[0] = { size = 16, free = 15, items = { [1] = { id = 777, count = 5 } } } } })
			seedChar("Default.Testrealm.Bob", { bags = {
				[0] = { size = 16, free = 15, items = { [1] = { id = 778, count = 2 } } } } })
			Detail.SetRole("Default.Testrealm.Bob", "bank")
			mock.SetItemNames({ [777] = "Friedensblume", [778] = "Silberblatt" })

			local Search = Exo.UI.SearchTab
			Search.ResetFilters()
			local results = Search.GatherResults("bl") -- beide Items
			assert.equal(2, #results)
			local filtered = Search.ApplyFilters(results,
				{ quality = 0, location = "all", role = "bank" })
			assert.equal(1, #filtered)
			assert.equal(778, filtered[1].itemID)
		end)
	end)

	describe("Bag-Details", function()
		it("Scan speichert die ItemID der ausgeruesteten Tasche", function()
			mock.SetContainer(0, 16)
			mock.SetContainer(1, 20)
			mock.SetEquippedBag(1, 194017) -- z. B. Sackpack
			mock.FireEvent("BAG_UPDATE")
			mock.AdvanceTime(0.5)
			local bags = Exo.Store:GetCharacter(Exo.Store:GetCurrentKey()).bags
			assert.equal(194017, bags[1].bagItemID)
			assert.is_nil(bags[0].bagItemID) -- Rucksack hat keine
		end)

		it("GetBagSpace meldet die kleinste ausgeruestete Tasche", function()
			local key = "Default.Testrealm.Anna"
			seedChar(key, { bags = {
				[0] = { size = 16, free = 10, items = {} },
				[1] = { size = 12, free = 2, items = {} },
				[2] = { size = 30, free = 20, items = {} },
			} })
			local space = Exo.API.GetBagSpace(key)
			assert.equal(12, space.smallestBag) -- Rucksack (id 0) zaehlt nicht
		end)

		it("Matrix-Zelle 'Taschen frei' farbcodiert; Modul warnt vor kleinen Taschen", function()
			local key = "Default.Testrealm.Anna"
			seedChar(key, { bags = {
				[0] = { size = 16, free = 1, items = {} },
				[1] = { size = 12, free = 2, items = {} },
			} })
			local Chars = Exo.UI.CharactersTab
			local cell = Chars.CellText({ kind = "bags" }, { key = key, summary = {} })
			assert.matches("|cffff4538", cell) -- 3 frei -> rot
			assert.matches("3 frei", cell)

			local rows = Exo.UI.OverviewTab.BuildModuleRows("bags")
			local all = ""
			for _, row in ipairs(rows) do all = all .. row.text .. "\n" end
			assert.matches("kleinste Tasche: 12 Plaetze", all)
		end)
	end)
end)
