-- spec/release_1_0_spec.lua
-- 1.0.0-Feinschliff: Minimap-Tooltip, /exo keys, Affixe, Uebersicht-Modul,
-- Minimap-Toggle im Designer.
local mock = require("spec.wow_mock")

describe("Release 1.0.0", function()
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
		if opts.mplus then
			Exo.Store:WriteCharacterData(charKey, "mythicplus", opts.mplus)
		end
	end

	before_each(function()
		mock.Reset()
		Exo = mock.LoadExoCore()
		mock.SimulateLogin()
	end)

	describe("Minimap-Tooltip", function()
		it("listet Chars nach iLvl, Gesamtgold und Mail-Warnung", function()
			seedChar("Default.Testrealm.Anna", { ilvl = 480, gold = 1000000, level = 90 })
			seedChar("Default.Testrealm.Bob", { ilvl = 460, gold = 500000, level = 88 })
			Exo.Store:WriteCharacterData("Default.Testrealm.Anna", "mails", {
				scannedAt = Exo.WowAPI.Now(),
				list = { { sender = "X", subject = "bald", money = 0,
					daysLeft = 1, items = {} } },
			})
			local lines = Exo.BuildMinimapTooltipLines()
			assert.matches("Anna", lines[1]) -- hoechstes iLvl zuerst
			assert.matches("iLvl 480", lines[1])
			assert.matches("100g", lines[1])
			assert.matches("Bob", lines[2])
			local all = table.concat(lines, "\n")
			assert.matches("Gesamt: 150g", all)
			assert.matches("1 Mail%(s%) laufen bald ab", all)
		end)
	end)

	describe("GetKeystones + /exo keys", function()
		before_each(function()
			seedChar("Default.Testrealm.Anna", { mplus = { rating = 3000,
				keystone = { mapID = 199, name = "Black Rook Hold", level = 16 },
				dungeons = {}, vault = {} } })
			seedChar("Default.Testrealm.Bob", { mplus = { rating = 2000,
				keystone = { mapID = 244, name = "Atal'Dazar", level = 12 },
				dungeons = {}, vault = {} } })
		end)

		it("GetKeystones sortiert hoechsten Stein zuerst", function()
			local keys = Exo.API.GetKeystones()
			assert.equal(2, #keys)
			assert.equal(16, keys[1].level)
			assert.equal("Anna", keys[1].name)
			assert.equal("Atal'Dazar", keys[2].mapName)
		end)

		it("/exo keys sagt in der Gruppe an", function()
			mock.SetGroup("party")
			_G.SlashCmdList["EXO"]("keys")
			local sent = mock.GetSentChat()
			assert.equal(1, #sent)
			assert.equal("PARTY", sent[1].channel)
			assert.matches("Anna Black Rook Hold %+16", sent[1].message)
			assert.matches("Bob Atal'Dazar %+12", sent[1].message)
		end)

		it("solo wird lokal ausgegeben (kein Chat-Versand)", function()
			mock.SetGroup(nil)
			_G.SlashCmdList["EXO"]("keys")
			assert.equal(0, #mock.GetSentChat())
		end)
	end)

	describe("Uebersicht-Modul 'Mythic+ Woche'", function()
		it("zeigt Affixe und Keystones", function()
			mock.LoadExoUI()
			mock.SetAffixes({ { id = 9, name = "Tyrannisch" }, { id = 10, name = "Verstaerkt" } })
			seedChar("Default.Testrealm.Anna", { mplus = { rating = 3000,
				keystone = { mapID = 199, name = "Black Rook Hold", level = 16 },
				dungeons = {}, vault = {} } })
			local rows = Exo.UI.OverviewTab.BuildModuleRows("keys")
			assert.matches("Tyrannisch, Verstaerkt", rows[1].text)
			assert.matches("Black Rook Hold", rows[2].text)
			assert.matches("%+16", rows[2].text)
		end)
	end)

	describe("Designer: Minimap-Toggle", function()
		it("ToggleMinimap versteckt/zeigt Button und speichert die Option", function()
			mock.LoadExoUI()
			local Designer = Exo.UI.DesignerTab
			assert.is_true(Designer.IsMinimapShown())
			Designer.ToggleMinimap()
			assert.is_false(Designer.IsMinimapShown())
			assert.is_true(Exo.API.GetOption("minimap.hide", false))
			assert.is_false(Exo.MinimapButton:IsShown())
			Designer.ToggleMinimap()
			assert.is_true(Exo.MinimapButton:IsShown())
		end)

		it("ResetAll blendet den Minimap-Button wieder ein", function()
			mock.LoadExoUI()
			local Designer = Exo.UI.DesignerTab
			Designer.ToggleMinimap()
			Designer.ResetAll()
			assert.is_true(Designer.IsMinimapShown())
			assert.is_true(Exo.MinimapButton:IsShown())
		end)
	end)
end)
