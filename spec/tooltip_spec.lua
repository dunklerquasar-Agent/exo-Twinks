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
