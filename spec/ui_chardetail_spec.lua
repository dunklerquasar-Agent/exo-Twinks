-- spec/ui_chardetail_spec.lua
-- Detail-Panel + Compare (0.14.0)
local mock = require("spec.wow_mock")

describe("ExoTwinksUI / Charakter-Detail (Deep-Dive)", function()
	local Exo, Detail, Chars

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
		char.equipment = {
			avgItemLevelEquipped = opts.ilvl or 0,
			slots = opts.slots or {},
		}
		if opts.mplus then
			Exo.Store:WriteCharacterData(charKey, "mythicplus", opts.mplus)
		end
		if opts.locks then
			Exo.Store:WriteCharacterData(charKey, "instanceLocks", opts.locks)
		end
		if opts.currencies then
			Exo.Store:WriteCharacterData(charKey, "currencies", opts.currencies)
		end
	end

	local function findRow(rows, label)
		for _, row in ipairs(rows) do
			if row.label == label then return row end
		end
	end

	before_each(function()
		mock.Reset()
		Exo = mock.LoadExoCore()
		mock.SimulateLogin()
		mock.LoadExoUI()
		Detail = Exo.UI.CharacterDetail
		Chars = Exo.UI.CharactersTab
		Chars.detailKey, Chars.compareKey = nil, nil

		seedChar("Default.Testrealm.Anna", {
			classID = 2, ilvl = 480, gold = 1234567,
			slots = { [1] = { id = 1001, ilvl = 489 }, [5] = { id = 1002, ilvl = 470 } },
			mplus = { rating = 2500, dungeons = {
				[199] = { name = "Black Rook Hold", level = 12, score = 141, inTime = true } },
				vault = { { type = 1, index = 1, progress = 4, threshold = 4, level = 10 } } },
			locks = { { name = "Amirdrassil", lockID = 1, resetAt = 9999999999,
				difficultyID = 15, difficultyName = "Heroisch", extended = false,
				isRaid = true, maxPlayers = 30, bossesKilled = 5, bossesTotal = 9 } },
			currencies = { [3008] = { name = "Valorstones", qty = 250, max = 2000 } },
		})
		seedChar("Default.Testrealm.Bob", {
			classID = 5, ilvl = 460, gold = 100,
			slots = { [1] = { id = 2001, ilvl = 450 } },
		})
	end)

	describe("BuildDetailRows (ein Charakter)", function()
		it("liefert alle Sektionen mit Werten", function()
			local rows = Detail.BuildDetailRows("Default.Testrealm.Anna")
			assert.is_true(rows[1].header)
			assert.equal("Allgemein", rows[1].label)
			assert.equal("480", findRow(rows, "Itemlevel").a)
			assert.equal("489", findRow(rows, "Kopf").a)
			assert.equal("-", findRow(rows, "Hals").a) -- leerer Slot
			assert.equal("2500", findRow(rows, "Wertung").a)
			assert.equal("+12 (141)", findRow(rows, "Black Rook Hold").a)
			assert.equal("5/9", findRow(rows, "Amirdrassil H").a)
			assert.equal("250 / 2.000", findRow(rows, "Valorstones").a)
			-- ohne Vergleich bleibt Spalte b leer
			assert.is_nil(findRow(rows, "Itemlevel").b)
		end)

		it("unbekannter Charakter -> keine Zeilen", function()
			assert.same({}, Detail.BuildDetailRows("Default.Nix.Niemand"))
		end)
	end)

	describe("BuildDetailRows (Vergleich)", function()
		it("fuellt Spalte b und markiert den besseren Wert gruen", function()
			local rows = Detail.BuildDetailRows(
				"Default.Testrealm.Anna", "Default.Testrealm.Bob")
			local ilvl = findRow(rows, "Itemlevel")
			assert.matches("|cff1eff00480|r", ilvl.a) -- Anna besser -> gruen
			assert.matches("|cffff4538460|r", ilvl.b) -- Bob schlechter -> rot
			local head = findRow(rows, "Kopf")
			assert.matches("489", head.a)
			assert.matches("450", head.b)
			-- Bobs fehlende Daten -> "-" statt Farbe
			assert.equal("-", findRow(rows, "Wertung").b)
			assert.equal("-", findRow(rows, "Black Rook Hold").b)
		end)
	end)

	describe("Questlog + Bank-Twink (0.17.0)", function()
		it("Questlog-Sektion mit 'auch im Log'-Vergleich", function()
			Exo.Store:WriteCharacterData("Default.Testrealm.Anna", "quests",
				{ [101] = "Die letzte Schlacht" })
			Exo.Store:WriteCharacterData("Default.Testrealm.Bob", "quests",
				{ [101] = "Die letzte Schlacht", [202] = "Kraeuter sammeln" })
			local rows = Detail.BuildDetailRows(
				"Default.Testrealm.Anna", "Default.Testrealm.Bob")
			local quest = findRow(rows, "Die letzte Schlacht")
			assert.equal("im Log", quest.a)
			assert.equal("im Log", quest.b)
			local only = findRow(rows, "Kraeuter sammeln")
			assert.equal("-", only.a)
			assert.equal("im Log", only.b)
		end)

		it("ToggleBankAlt setzt/entfernt die Markierung", function()
			assert.is_false(Detail.IsBankAlt("Default.Testrealm.Anna"))
			Detail.ToggleBankAlt("Default.Testrealm.Anna")
			assert.is_true(Detail.IsBankAlt("Default.Testrealm.Anna"))
			Detail.ToggleBankAlt("Default.Testrealm.Anna")
			assert.is_false(Detail.IsBankAlt("Default.Testrealm.Anna"))
		end)
	end)

	describe("NextCompareKey", function()
		it("zykliert durch alle anderen Chars und endet bei nil", function()
			local detailKey = "Default.Testrealm.Anna"
			local first = Detail.NextCompareKey(detailKey, nil)
			assert.is_not_nil(first)
			assert.is_not_equal(detailKey, first)
			-- den kompletten Zyklus durchlaufen: irgendwann wieder nil
			local seen, current = 0, first
			while current ~= nil and seen < 10 do
				current = Detail.NextCompareKey(detailKey, current)
				seen = seen + 1
			end
			assert.is_nil(current)
		end)
	end)

	describe("Integration mit dem Charaktere-Tab", function()
		it("OpenDetail versteckt die Matrix und rendert das Panel", function()
			local content = CreateFrame("Frame")
			Chars:Render(content)
			assert.is_false(Chars._detailHost:IsShown())

			Chars:OpenDetail("Default.Testrealm.Anna")
			assert.is_true(Chars._detailHost:IsShown())
			assert.is_false(Chars._GetScroller():GetFrame():IsShown())
			local panel = Detail._GetPanel()
			assert.is_table(panel)
			assert.matches("Anna", panel.title:GetText())
			assert.is_true(#panel.scroller:GetData() > 10)

			-- Zurueck zur Matrix
			Chars.detailKey = nil
			Chars:Render(content)
			assert.is_false(Chars._detailHost:IsShown())
			assert.is_true(Chars._GetScroller():GetFrame():IsShown())
		end)

		it("Vergleichs-Button-Zyklus aktualisiert Titel und Spalten", function()
			local content = CreateFrame("Frame")
			Chars:Render(content)
			Chars:OpenDetail("Default.Testrealm.Anna")
			Chars.compareKey = Detail.NextCompareKey(Chars.detailKey, nil)
			Chars:Render(content)
			local panel = Detail._GetPanel()
			assert.matches("vs", panel.title:GetText())
			assert.matches("Vergleich:", panel.compareButton:GetText())
		end)
	end)
end)
