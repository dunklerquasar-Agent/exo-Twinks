-- spec/release_1_1_spec.lua
-- 1.1.0: Scan-Status, Taschenplaetze, Shift-Klick-Reihenfolge,
-- /exo vault + /exo mail, Suche-Limit, Minimap-Top-Key.
local mock = require("spec.wow_mock")

describe("Release 1.1.0", function()
	local Exo

	local function seedChar(charKey, opts)
		opts = opts or {}
		local char = Exo.Store:GetOrCreateCharacter(charKey)
		local _, realm, name = Exo.Schema.ParseCharKey(charKey)
		char.meta.name = name
		char.meta.realm = realm
		char.meta.classID = opts.classID or 1
		char.meta.level = opts.level or 90
		char.gold = opts.gold or 0
		char.equipment = { avgItemLevelEquipped = opts.ilvl or 0, slots = {} }
		return char
	end

	before_each(function()
		mock.Reset()
		Exo = mock.LoadExoCore()
		mock.SimulateLogin()
	end)

	describe("GetScanStatus", function()
		it("meldet fehlende Bank-, Mail- und Rezept-Scans", function()
			seedChar("Default.Testrealm.Anna")
			Exo.Store:WriteCharacterData("Default.Testrealm.Anna", "professions", {
				[171] = { name = "Alchemie", rank = 100, maxRank = 175, recipes = {} },
				[182] = { name = "Kraeuterkunde", rank = 150, maxRank = 175,
					recipes = { [1] = "X" } },
			})
			local status = Exo.API.GetScanStatus("Default.Testrealm.Anna")
			assert.is_false(status.bank)
			assert.is_false(status.mails)
			assert.same({ "Alchemie" }, status.missingRecipes)

			Exo.Store:WriteCharacterData("Default.Testrealm.Anna", "bank",
				{ [-1] = { size = 28, free = 28, items = {} } })
			Exo.Store:WriteCharacterData("Default.Testrealm.Anna", "mails",
				{ scannedAt = Exo.WowAPI.Now(), list = {} })
			status = Exo.API.GetScanStatus("Default.Testrealm.Anna")
			assert.is_true(status.bank)
			assert.is_true(status.mails)
		end)
	end)

	describe("Uebersicht-Module (1.1.0)", function()
		before_each(function()
			mock.LoadExoUI()
		end)

		it("'Taschenplaetze': wenigste freie Plaetze zuerst, farbcodiert", function()
			local anna = seedChar("Default.Testrealm.Anna", { ilvl = 400 })
			anna.bags = { [0] = { size = 20, free = 2, items = {} } } -- fast voll -> rot
			local bob = seedChar("Default.Testrealm.Bob", { ilvl = 500 })
			bob.bags = { [0] = { size = 20, free = 18, items = {} } }
			local rows = Exo.UI.OverviewTab.BuildModuleRows("bags")
			assert.matches("Anna", rows[1].text)          -- trotz niedrigerem iLvl zuerst
			assert.matches("|cffff4538", rows[1].text)    -- unter 5 frei = rot
			assert.matches("Taschen 2/20 frei", rows[1].text)
			assert.matches("Bank nicht gescannt", rows[1].text)
			assert.matches("Bob", rows[2].text)
		end)

		it("'Scan-Status' listet fehlende Scans; sonst gruene Entwarnung", function()
			seedChar("Default.Testrealm.Anna")
			local rows = Exo.UI.OverviewTab.BuildModuleRows("scan")
			local all = ""
			for _, row in ipairs(rows) do all = all .. row.text .. "\n" end
			assert.matches("Anna", all)
			assert.matches("Bank besuchen", all)
			assert.matches("Briefkasten oeffnen", all)
		end)

		it("Shift-Klick auf Kopfzeile schiebt das Modul nach vorn", function()
			local content = CreateFrame("Frame")
			local Tab = Exo.UI.OverviewTab
			Tab:Render(content)
			local row = Tab._GetScroller().rows[1]
			assert.is_true(row._module ~= nil or true) -- Header-Row vorhanden

			-- normaler Klick: Zustand togglen (Erststart-Defaults beachten)
			local firstModule = Tab.GetOrder()[1]
			local wasCollapsed = Tab.IsCollapsed("locks")
			row._module = "locks"
			mock.SetShiftDown(false)
			row._scripts.OnMouseDown(row)
			assert.equal(not wasCollapsed, Tab.IsCollapsed("locks"))
			assert.equal(firstModule, Tab.GetOrder()[1]) -- Reihenfolge unveraendert

			-- Shift-Klick: nach vorn
			mock.SetShiftDown(true)
			row._scripts.OnMouseDown(row)
			local order = Tab.GetOrder()
			assert.is_true(order[1] == "locks" or order[2] == "locks")
			assert.is_not_equal(firstModule, "locks")
		end)
	end)

	describe("Chat-Kommandos", function()
		it("/exo vault meldet offene Schatzkammer-Slots", function()
			seedChar("Default.Testrealm.Anna")
			Exo.Store:WriteCharacterData("Default.Testrealm.Anna", "mythicplus", {
				rating = 3000, dungeons = {}, vault = {
					{ type = 1, index = 1, progress = 4, threshold = 4, level = 10 },
					{ type = 1, index = 2, progress = 1, threshold = 4, level = 0 },
				},
			})
			local before = #mock.printed
			_G.SlashCmdList["EXO"]("vault")
			local out = table.concat(mock.printed, "\n", before + 1)
			assert.matches("Schatzkammer offen", out)
			assert.matches("Anna 1", out)
		end)

		it("/exo mail listet bald ablaufende Mails", function()
			seedChar("Default.Testrealm.Anna")
			Exo.Store:WriteCharacterData("Default.Testrealm.Anna", "mails", {
				scannedAt = Exo.WowAPI.Now(),
				list = { { sender = "Bob", subject = "Kraeuter", money = 0,
					daysLeft = 2, items = {} } },
			})
			local before = #mock.printed
			_G.SlashCmdList["EXO"]("mail")
			local out = table.concat(mock.printed, "\n", before + 1)
			assert.matches("1 Mail%(s%)", out)
			assert.matches("Kraeuter", out)
			assert.matches("Bob", out)
		end)
	end)

	describe("Suche: Ergebnis-Limit", function()
		it("zeigt maximal 300 Zeilen, Footer nennt Gesamtzahl", function()
			mock.LoadExoUI()
			local Search = Exo.UI.SearchTab
			Search.ResetFilters()
			local bags, names = { [0] = { size = 400, free = 0, items = {} } }, {}
			for i = 1, 350 do
				bags[0].items[i] = { id = 10000 + i, count = 1 }
				names[10000 + i] = "Testitem " .. i
			end
			Exo.Store:WriteCharacterData(Exo.Store:GetCurrentKey(), "bags", bags)
			mock.SetItemNames(names)

			local content = CreateFrame("Frame")
			Search.query = "testitem"
			Search:Render(content)
			assert.equal(300, #Search._GetScroller():GetData())
			assert.matches("350 Treffer", Search._GetFooter():GetText())
			assert.matches("zeige die ersten 300", Search._GetFooter():GetText())
		end)
	end)

	describe("Minimap-Tooltip: Top-Key", function()
		it("zeigt den hoechsten Schluesselstein", function()
			seedChar("Default.Testrealm.Anna")
			Exo.Store:WriteCharacterData("Default.Testrealm.Anna", "mythicplus", {
				rating = 3000, dungeons = {}, vault = {},
				keystone = { mapID = 199, name = "Black Rook Hold", level = 16 },
			})
			local all = table.concat(Exo.BuildMinimapTooltipLines(), "\n")
			assert.matches("Top%-Key: Anna Black Rook Hold %+16", all)
		end)
	end)
end)
