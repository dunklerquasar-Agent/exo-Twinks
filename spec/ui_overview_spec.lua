-- spec/ui_overview_spec.lua
-- Uebersicht-Tab (0.11.1): stapelbare Module, Ein-/Ausklappen, Reihenfolge.
local mock = require("spec.wow_mock")

describe("ExoTwinksUI / Uebersicht-Tab (stapelbare Panels)", function()
	local Exo, Tab

	local function seedChar(charKey, opts)
		opts = opts or {}
		local char = Exo.Store:GetOrCreateCharacter(charKey)
		local _, realm, name = Exo.Schema.ParseCharKey(charKey)
		char.meta.name = name
		char.meta.realm = realm
		char.meta.classID = opts.classID or 1
		char.meta.level = opts.level or 90
		char.meta.lastSeen = opts.lastSeen or 1700000000
		char.gold = opts.gold or 0
		char.equipment = { avgItemLevelEquipped = opts.ilvl or 400, slots = {} }
		if opts.currencies then
			Exo.Store:WriteCharacterData(charKey, "currencies", opts.currencies)
		end
		if opts.locks then
			Exo.Store:WriteCharacterData(charKey, "instanceLocks", opts.locks)
		end
		if opts.bags then
			Exo.Store:WriteCharacterData(charKey, "bags", opts.bags)
		end
	end

	before_each(function()
		mock.Reset()
		Exo = mock.LoadExoCore()
		mock.SimulateLogin()
		mock.LoadExoUI()
		Tab = Exo.UI.OverviewTab
	end)

	describe("Modul-Verwaltung", function()
		it("Standard-Reihenfolge: chars ... keys, bags, scan", function()
			assert.same({ "chars", "currencies", "locks", "inventory", "realms",
				"keys", "bags", "scan", "tax", "auctions" }, Tab.GetOrder())
		end)

		it("MoveModuleForward schiebt ein Modul nach vorn und speichert", function()
			Tab.MoveModuleForward("locks")
			assert.same({ "chars", "locks", "currencies", "inventory", "realms",
				"keys", "bags", "scan", "tax", "auctions" }, Tab.GetOrder())
			-- ganz vorn: kein Wechsel mehr
			Tab.MoveModuleForward("chars")
			assert.equal("chars", Tab.GetOrder()[1])
		end)

		it("ignoriert kaputte gespeicherte Reihenfolgen", function()
			Exo.API.SetOption("overview.order", "quatsch,locks,locks")
			local order = Tab.GetOrder()
			assert.equal("locks", order[1])
			assert.equal(10, #order) -- alle Module vorhanden, keine Duplikate
		end)

		it("ToggleModuleShown blendet Module aus der Zeilenliste aus", function()
			Tab.ToggleModuleShown("currencies")
			for _, row in ipairs(Tab.BuildRows()) do
				assert.is_not_equal("currencies", row.module)
			end
			Tab.ToggleModuleShown("currencies")
			assert.is_true(Tab.IsModuleShown("currencies"))
		end)
	end)

	describe("BuildRows", function()
		before_each(function()
			seedChar("Default.Testrealm.Anna", {
				classID = 2, ilvl = 480, gold = 1234567,
				currencies = { [3008] = { name = "Valorstones", qty = 250, max = 2000 } },
				locks = { { name = "Amirdrassil", lockID = 1, resetAt = 9999999999,
					difficultyID = 15, difficultyName = "Heroisch", extended = false,
					isRaid = true, maxPlayers = 30, bossesKilled = 5, bossesTotal = 9 } },
				bags = { bag0 = { size = 20, items = { [1] = { id = 777, count = 12 } } } },
			})
		end)

		it("liefert Kopfzeile + Inhalt je Modul", function()
			local rows = Tab.BuildRows()
			assert.is_true(rows[1].header)
			assert.equal("chars", rows[1].module)
			assert.matches("Anna", rows[2].text)
			assert.matches("480", rows[2].text)
		end)

		it("eingeklappte Module zeigen nur die Kopfzeile", function()
			Tab.ToggleCollapsed("chars")
			local rows = Tab.BuildRows()
			assert.is_true(rows[1].header)
			assert.is_true(rows[1].collapsed)
			-- Zeile 2 ist direkt die naechste Kopfzeile
			assert.is_true(rows[2].header)
			assert.equal("currencies", rows[2].module)
		end)

		it("Waehrungs- und Lock-Zeilen enthalten die Daten", function()
			local byModule = {}
			local current
			for _, row in ipairs(Tab.BuildRows()) do
				if row.header then
					current = row.module
					byModule[current] = {}
				else
					table.insert(byModule[current], row.text)
				end
			end
			assert.matches("Valorstones", byModule.currencies[1])
			assert.matches("250", byModule.currencies[1])
			assert.matches("Amirdrassil", byModule.locks[1])
			assert.matches("5/9", byModule.locks[1])
			assert.matches("12", byModule.inventory[1]) -- 12 Stueck in Taschen
		end)

		it("Module ohne Daten zeigen 'Keine Daten.'", function()
			mock.Reset()
			Exo = mock.LoadExoCore()
			mock.SimulateLogin()
			mock.LoadExoUI()
			Tab = Exo.UI.OverviewTab
			local rows = Tab.BuildRows()
			-- Modul "currencies": Kopfzeile + genau eine "Keine Daten."-Zeile
			for index, row in ipairs(rows) do
				if row.header and row.module == "currencies" then
					assert.matches("Keine Daten", rows[index + 1].text)
				end
			end
		end)
	end)

	describe("Modul 'Gold pro Realm' (0.17.0)", function()
		it("summiert je Realm inkl. Gesamtzeile", function()
			seedChar("Default.Reich.Zwei", { gold = 5000 })
			seedChar("Default.Reich.Drei", { gold = 5000 })
			local rows = Tab.BuildModuleRows("realms")
			assert.matches("Reich", rows[1].text)
			assert.matches("2 Charaktere", rows[1].text)
			assert.matches("Gesamt", rows[#rows].text)
		end)
	end)

	describe("Render", function()
		it("befuellt den Scroller; Header-Klick klappt ein/aus", function()
			seedChar("Default.Testrealm.Anna", {})
			local content = CreateFrame("Frame")
			Tab:Render(content)
			local data = Tab._GetScroller():GetData()
			assert.is_true(#data >= 5) -- 4 Header + mind. 1 Inhaltszeile
			assert.is_true(data[1].header)

			Tab.ToggleCollapsed(data[1].module)
			Tab:Render(content)
			local collapsed = Tab._GetScroller():GetData()
			assert.is_true(collapsed[1].collapsed)
		end)
	end)
end)
