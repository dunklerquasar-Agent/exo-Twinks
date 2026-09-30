-- spec/ui_search_spec.lua
local mock = require("spec.wow_mock")

describe("ExoTwinksUI / Suche-Tab", function()
	local Exo, Tab

	local function seed()
		local Store = Exo.Store
		local anna = Store:GetOrCreateCharacter("Default.Testrealm.Anna")
		anna.meta.name = "Anna"

		Store:WriteCharacterData("Default.Testrealm.Anna", "bags", {
			[0] = { size = 16, free = 13, items = {
				[1] = { id = 777, count = 10 },  -- Friedensblume
				[2] = { id = 778, count = 4 },   -- Silberblatt
				[3] = { id = 555, count = 1 },   -- Kupferbarren
			} },
		})
		Store:WriteAccountData("warbandBank", {
			[13] = { size = 98, free = 97, items = { [1] = { id = 778, count = 20 } } },
		})

		mock.SetItemNames({
			[777] = "Friedensblume",
			[778] = "Silberblatt",
			[555] = "Kupferbarren",
		})
	end

	before_each(function()
		mock.Reset()
		Exo = mock.LoadExoCore()
		mock.SimulateLogin()
		mock.LoadExoUI()
		Tab = Exo.UI.SearchTab
		Tab.query = ""
		seed()
	end)

	describe("GatherResults", function()
		it("findet Items per Namens-Teilstring (case-insensitive)", function()
			local results = Tab.GatherResults("blume")
			assert.equal(1, #results)
			assert.equal("Friedensblume", results[1].name)
			assert.equal(10, results[1].total)
		end)

		it("sortiert nach Gesamtanzahl absteigend", function()
			local results = Tab.GatherResults("blatt") -- Silberblatt (24), aber nur 1 Treffer
			assert.equal(1, #results)
			assert.equal(24, results[1].total) -- 4 Taschen + 20 Kriegsmeute

			results = Tab.GatherResults("er") -- Silberblatt 24, Kupferbarren 1
			assert.equal(2, #results)
			assert.equal("Silberblatt", results[1].name)
			assert.equal("Kupferbarren", results[2].name)
		end)

		it("numerische Eingabe sucht exakte Item-ID", function()
			local results = Tab.GatherResults("555")
			assert.equal(1, #results)
			assert.equal("Kupferbarren", results[1].name)
		end)

		it("unter 2 Zeichen: keine Suche", function()
			assert.same({}, Tab.GatherResults("b"))
			assert.same({}, Tab.GatherResults(""))
			assert.same({}, Tab.GatherResults("   "))
		end)

		it("Items ohne bekannten Namen werden bei Textsuche uebersprungen", function()
			mock.SetItemNames({ [777] = "Friedensblume" }) -- 778/555 unbekannt
			local results = Tab.GatherResults("er")
			assert.same({}, results)
		end)
	end)

	describe("BuildBreakdown", function()
		it("nennt Chars mit Quellen und die Kriegsmeute", function()
			local counts = Exo.API.GetItemCounts(778)
			local text = Tab.BuildBreakdown(counts)
			assert.truthy(text:find("Anna 4 (Taschen 4)", 1, true))
			assert.truthy(text:find("Kriegsmeute 20", 1, true))
		end)
	end)

	describe("AH-Filter (0.13.0)", function()
		before_each(function()
			Tab.ResetFilters()
			Exo.Store:GetOrCreateCharacter("Default.Testrealm.Anna").meta.realm = "Testrealm"
			mock.SetItemDetails({
				[777] = { quality = 2, classID = 7, type = "Handwerksmaterial" },
				[778] = { quality = 4, classID = 7, type = "Handwerksmaterial" },
				[555] = { quality = 3, classID = 2, type = "Waffe" },
			})
			-- Kupferbarren zusaetzlich in Annas Bank (fuer den Ort-Filter)
			Exo.Store:WriteCharacterData("Default.Testrealm.Anna", "bank", {
				[-1] = { size = 28, free = 27, items = { [1] = { id = 555, count = 5 } } },
			})
		end)

		local function ids(results)
			local list = {}
			for _, r in ipairs(results) do list[#list + 1] = r.itemID end
			table.sort(list)
			return list
		end

		it("Qualitaet: Epic+ laesst nur epische Items durch", function()
			local results = Tab.ApplyFilters(Tab.GatherResults("er"),
				{ quality = 4, location = "all" })
			assert.same({ 778 }, ids(results))
		end)

		it("Typ-Filter: nur Waffen", function()
			local results = Tab.ApplyFilters(Tab.GatherResults("er"),
				{ quality = 0, classID = 2, location = "all" })
			assert.same({ 555 }, ids(results))
		end)

		it("Ort-Filter: Bank bzw. Kriegsmeute", function()
			local results = Tab.ApplyFilters(Tab.GatherResults("er"),
				{ quality = 0, location = "bank" })
			assert.same({ 555 }, ids(results)) -- nur Kupferbarren liegt in einer Bank
			results = Tab.ApplyFilters(Tab.GatherResults("er"),
				{ quality = 0, location = "warband" })
			assert.same({ 778 }, ids(results)) -- nur Silberblatt in der Kriegsmeute
		end)

		it("Realm-Filter behaelt nur Treffer des angegebenen Realms", function()
			local filters = { quality = 0, location = "all", realmOnly = true }
			local results = Tab.ApplyFilters(Tab.GatherResults("blume"), filters, "Testrealm")
			assert.same({ 777 }, ids(results))
			results = Tab.ApplyFilters(Tab.GatherResults("blume"), filters, "Anderswo")
			assert.same({}, ids(results))
		end)

		it("Zyklus-Buttons aktualisieren Text und Auswahl-Markierung", function()
			local content = CreateFrame("Frame")
			Tab:Render(content)
			local buttons = Tab._GetFilterButtons()
			assert.equal("Qualitaet: Alle", buttons.quality:GetText())
			Tab:CycleFilter("quality", Tab.QUALITY_STEPS)
			assert.equal("Qualitaet: Gruen+", buttons.quality:GetText())
			assert.is_true(buttons.quality._selected)
			Tab:ToggleRealmOnly()
			assert.equal("Realm: Aktueller", buttons.realm:GetText())
		end)
	end)

	describe("Render + Live-Suche", function()
		local content

		before_each(function()
			content = CreateFrame("Frame")
			Tab:Render(content)
		end)

		it("zeigt anfangs den Eingabe-Hinweis", function()
			assert.truthy(Tab._GetFooter():GetText():find("Mindestens 2 Zeichen", 1, true))
		end)

		it("Tippen rendert entprellt neu", function()
			Tab:OnQueryChanged("blu")
			assert.equal(0, #Tab._GetScroller():GetData()) -- Debounce laeuft

			mock.AdvanceTime(0.3)

			local data = Tab._GetScroller():GetData()
			assert.equal(1, #data)
			assert.equal("Friedensblume", data[1].name)
			assert.truthy(Tab._GetFooter():GetText():find("1 Treffer", 1, true))
		end)

		it("schnelles Weitertippen loest nur EINE Suche aus", function()
			Tab:OnQueryChanged("bl")
			Tab:OnQueryChanged("blu")
			Tab:OnQueryChanged("blum")
			mock.AdvanceTime(0.3)

			assert.equal("blum", Tab.query)
			assert.equal(1, #Tab._GetScroller():GetData())
		end)

		it("Suche ist KEIN eigener Reiter mehr (lebt im Inventar-Tab)", function()
			assert.is_nil(Exo.UI.tabsById["search"])
			assert.equal(Tab, Exo.UI.SearchTab) -- Modul bleibt verfuegbar
		end)
	end)
end)
