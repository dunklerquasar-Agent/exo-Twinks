-- spec/tooltip_spec.lua
local mock = require("spec.wow_mock")

describe("Tooltip-Service ('Besessen von ...')", function()
	local Exo

	local function seed()
		local Store = Exo.Store
		local anna = Store:GetOrCreateCharacter("Default.Testrealm.Anna")
		anna.meta.name = "Anna"
		local borg = Store:GetOrCreateCharacter("Default.Testrealm.Borg")
		borg.meta.name = "Borg"

		Store:WriteCharacterData("Default.Testrealm.Anna", "bags", {
			[0] = { size = 16, free = 14, items = { [1] = { id = 777, count = 10 } } },
		})
		Store:WriteCharacterData("Default.Testrealm.Anna", "bank", {
			[-1] = { size = 28, free = 27, items = { [3] = { id = 777, count = 2 } } },
		})
		Store:WriteCharacterData("Default.Testrealm.Borg", "bags", {
			[0] = { size = 16, free = 15, items = { [1] = { id = 777, count = 5 } } },
		})
		Store:WriteAccountData("warbandBank", {
			[13] = { size = 98, free = 97, items = { [1] = { id = 777, count = 5 } } },
		})
	end

	before_each(function()
		mock.Reset()
		Exo = mock.LoadExoCore()
		mock.SimulateLogin()
		seed()
	end)

	it("haengt Gesamtzahl, Char-Zeilen und Kriegsmeute an den Tooltip", function()
		local tooltip = mock.HoverItem(777)

		assert.equal(4, #tooltip.lines)
		assert.truthy(tooltip.lines[1]:find("22 insgesamt", 1, true))
		assert.truthy(tooltip.lines[2]:find("Anna: 12 (Taschen 10, Bank 2)", 1, true)) -- meiste zuerst
		assert.truthy(tooltip.lines[3]:find("Borg: 5 (Taschen 5)", 1, true))
		assert.truthy(tooltip.lines[4]:find("Kriegsmeute: 5", 1, true))
	end)

	it("zeigt den Bank-Reiter an (1.11.1)", function()
		-- Bank-Tab 2 = Container 7 (seit 11.2: Charbank-Tabs ab Bag 6)
		Exo.Store:WriteCharacterData("Default.Testrealm.Anna", "bank", {
			[7] = { size = 98, free = 95, items = { [3] = { id = 777, count = 3 } } },
		})
		local tooltip = mock.HoverItem(777)
		local found = false
		for _, line in ipairs(tooltip.lines) do
			if line:find("Bank 3 (Reiter 2)", 1, true) then found = true end
		end
		assert.is_true(found)
	end)

	it("zeigt mehrere Bank-Reiter mit Einzelmengen (1.11.1)", function()
		Exo.Store:WriteCharacterData("Default.Testrealm.Anna", "bank", {
			[6] = { size = 98, free = 96, items = { [1] = { id = 777, count = 2 } } },
			[9] = { size = 98, free = 94, items = { [5] = { id = 777, count = 4 } } },
		})
		local tooltip = mock.HoverItem(777)
		local found = false
		for _, line in ipairs(tooltip.lines) do
			if line:find("Bank 6 (Reiter 1: 2, Reiter 4: 4)", 1, true) then found = true end
		end
		assert.is_true(found)
	end)

	it("zeigt den Kriegsmeuten-Reiter an (1.11.1)", function()
		-- Seed legt das Item in Container 13 = KM-Reiter 2
		local tooltip = mock.HoverItem(777)
		local found = false
		for _, line in ipairs(tooltip.lines) do
			if line:find("Kriegsmeute: 5 (Reiter 2)", 1, true) then found = true end
		end
		assert.is_true(found)
	end)

	it("TabSuffix ist rein: leer, einzeln, mehrfach sortiert", function()
		local Tooltip = Exo.Services.Tooltip
		assert.equal("", Tooltip.TabSuffix(nil))
		assert.equal("", Tooltip.TabSuffix({}))
		assert.equal(" (Reiter 3)", Tooltip.TabSuffix({ [3] = 7 }))
		assert.equal(" (Reiter 1: 2, Reiter 5: 9)",
			Tooltip.TabSuffix({ [5] = 9, [1] = 2 }))
	end)

	it("alte Bank-Container (-1) bekommen KEINEN Reiter-Zusatz", function()
		-- Seed nutzt Container -1 (Legacy-Hauptbank) -> Zeile bleibt wie bisher
		local tooltip = mock.HoverItem(777)
		assert.truthy(tooltip.lines[2]:find("Anna: 12 (Taschen 10, Bank 2)", 1, true))
		assert.is_nil(tooltip.lines[2]:find("Bank 2 (Reiter", 1, true))
	end)

	it("fuegt NICHTS an, wenn niemand das Item besitzt", function()
		local tooltip = mock.HoverItem(424242)
		assert.equal(0, #tooltip.lines)
	end)

	it("Daten ohne Item-ID werden ignoriert (kein Fehler)", function()
		assert.has_no.errors(function()
			mock.HoverItem(nil)
		end)
	end)

	it("BuildLines ist rein und sortiert Chars nach Anzahl", function()
		local lines = Exo.Services.Tooltip.BuildLines({
			total = 9, warband = 0,
			chars = {
				["Default.R.Wenig"] = { bags = 2, bank = 0 },
				["Default.R.Viel"] = { bags = 7, bank = 0 },
			},
		})
		assert.equal(3, #lines)
		assert.truthy(lines[2]:find("Viel", 1, true))
		assert.truthy(lines[3]:find("Wenig", 1, true))
	end)

	it("BuildLines mit total=0 liefert leere Liste", function()
		assert.same({}, Exo.Services.Tooltip.BuildLines({ total = 0, warband = 0, chars = {} }))
	end)

	it("reagiert live auf Bestandsaenderungen (Cache-Invalidierung)", function()
		assert.truthy(mock.HoverItem(777).lines[1]:find("22", 1, true))

		Exo.Store:WriteCharacterData("Default.Testrealm.Borg", "bags", {
			[0] = { size = 16, free = 16, items = {} },
		})

		assert.truthy(mock.HoverItem(777).lines[1]:find("17", 1, true))
	end)
end)
