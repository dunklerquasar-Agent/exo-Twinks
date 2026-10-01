-- spec/ui_characters_spec.lua
-- Haupt-Tab "Charaktere" (AlterEgo-Matrix): Zellen-Formate, Matrix-Aufbau,
-- Boss-Quadrate, Blaettern und Fenster-Integration.
local mock = require("spec.wow_mock")

describe("ExoTwinksUI / Charaktere-Tab (AlterEgo-Matrix)", function()
	local Exo, Tab

	local function seedChar(charKey, opts)
		local char = Exo.Store:GetOrCreateCharacter(charKey)
		local _, realm, name = Exo.Schema.ParseCharKey(charKey)
		char.meta.name = name
		char.meta.realm = realm
		char.meta.classID = opts.classID or 1
		char.meta.level = opts.level or 90
		char.meta.playedTotal = opts.played or 360000
		char.meta.lastSeen = opts.lastSeen or 1700000000
		char.gold = opts.gold or 0
		char.equipment = { avgItemLevelEquipped = opts.ilvl or 400, slots = {} }
		if opts.mplus then
			Exo.Store:WriteCharacterData(charKey, "mythicplus", opts.mplus)
		end
		if opts.locks then
			Exo.Store:WriteCharacterData(charKey, "instanceLocks", opts.locks)
		end
	end

	local function fullMplus()
		return {
			rating = 3044,
			keystone = { mapID = 199, name = "Black Rook Hold", level = 16 },
			dungeons = {
				[199] = { name = "Black Rook Hold", level = 23, score = 178, inTime = true },
				[244] = { name = "Atal'Dazar", level = 24, score = 180, inTime = false },
			},
			vault = {
				{ type = 1, index = 1, progress = 8, threshold = 1, level = 20 },
				{ type = 1, index = 2, progress = 8, threshold = 4, level = 19 },
				{ type = 1, index = 3, progress = 6, threshold = 8, level = 0 },
			},
		}
	end

	local function raidLocks()
		return {
			{ name = "Amirdrassil", lockID = 1, resetAt = 1700100000, difficultyID = 16,
				difficultyName = "Mythisch", extended = false, isRaid = true,
				maxPlayers = 20, bossesKilled = 3, bossesTotal = 9 },
			{ name = "Amirdrassil", lockID = 2, resetAt = 1700100000, difficultyID = 15,
				difficultyName = "Heroisch", extended = false, isRaid = true,
				maxPlayers = 30, bossesKilled = 9, bossesTotal = 9 },
		}
	end

	before_each(function()
		mock.Reset()
		Exo = mock.LoadExoCore()
		mock.SimulateLogin()
		mock.LoadExoUI()
		Tab = Exo.UI.CharactersTab
		Tab.page = 1
		Exo.Store:DeleteCharacter(Exo.Store:GetCurrentKey())
	end)

	describe("Zellen-Formate", function()
		it("Raid-Kurzzeile: hoechste Schwierigkeit zuerst, farbig", function()
			assert.equal("|cffa335eeM|r |cff0070ddH|r", Tab.FormatRaidsCell(raidLocks()))
			assert.equal("-", Tab.FormatRaidsCell({}))
		end)

		it("BossCellData: Kill-Zaehler + Schwierigkeitsfarbe", function()
			local data = Tab.BossCellData(raidLocks()[1])
			assert.same({ killed = 3, total = 9, color = "a335ee" }, data)
			assert.is_nil(Tab.BossCellData(nil))
		end)

		it("Wertung/Keystone/Vault/Dungeon wie im Mythic+-Tab", function()
			local mplus = fullMplus()
			assert.equal("|cffe6cc803044|r", Tab.FormatRatingCell(mplus))
			assert.equal("BRH +16", Tab.FormatKeystoneCell(mplus))
			assert.equal("|cffffd7002/3|r", Tab.FormatVaultCell(mplus, 1))
			assert.equal("|cff1eff00+23|r |cff808080178|r", Tab.FormatDungeonCell(mplus, 199))
		end)
	end)

	describe("BuildMatrix", function()
		it("alle Chars als Spalten, Itemlevel absteigend sortiert", function()
			seedChar("Default.Testrealm.Zwerg", { ilvl = 489, classID = 5 })
			seedChar("Default.Testrealm.Anton", { ilvl = 437, classID = 8 })

			local matrix = Tab.BuildMatrix()
			assert.equal(2, #matrix.chars)
			assert.equal("Zwerg", matrix.chars[1].name) -- 489 vor 437 trotz Name
			assert.equal("Anton", matrix.chars[2].name)
		end)

		it("feste Zeilen + Mythic+-Sektion + Raid-Sektion mit Boss-Zeilen", function()
			seedChar("Default.Testrealm.Liquidora",
				{ ilvl = 489, mplus = fullMplus(), locks = raidLocks() })

			local matrix = Tab.BuildMatrix()
			local kinds, labels = {}, {}
			for i, row in ipairs(matrix.rows) do
				kinds[i], labels[i] = row.kind, row.label
			end

			-- 16 feste (inkl. "Taschen frei" 1.5.0 + "Post" 1.11.0) + 1 Sektion
			-- + 2 Dungeons + 1 Raid-Sektion + 2 Boss-Zeilen = 22
			assert.equal(22, #matrix.rows)
			assert.equal("realm", kinds[1])
			assert.equal("bags", kinds[4]) -- neu in 1.5.0, direkt nach Gold
			assert.equal("mail", kinds[8]) -- neu in 1.11.0, nach "Zuletzt online"
			assert.equal("vaultstatus", kinds[12])
			assert.equal("raids", kinds[16])
			assert.equal("section", kinds[17])
			assert.equal("Mythic+ (Season-Best)", labels[17])
			assert.equal("Atal'Dazar", labels[18]) -- alphabetisch
			assert.equal("Black Rook Hold", labels[19])
			assert.equal("section", kinds[20])
			assert.equal("Amirdrassil", labels[20])
			assert.equal(1700100000, matrix.rows[20].resetAt)
			-- Schwierigkeiten aufsteigend: Heroisch vor Mythisch
			assert.equal("Heroisch", labels[21])
			assert.equal("Mythisch", labels[22])
			assert.equal("H", matrix.rows[21].diff)
		end)

		it("ohne M+/Raid-Daten: nur die 16 festen Zeilen", function()
			seedChar("Default.Testrealm.Frisch", { ilvl = 0 })
			assert.equal(16, #Tab.BuildMatrix().rows)
		end)
	end)

	describe("CellText", function()
		it("dispatcht alle Textzeilen-Arten", function()
			seedChar("Default.Testrealm.Liquidora", {
				ilvl = 489, classID = 5, gold = 1245320000, played = 366000,
				lastSeen = 1700000000 - 7200, mplus = fullMplus(), locks = raidLocks(),
			})
			local matrix = Tab.BuildMatrix()
			local char = matrix.chars[1]
			local byKind = {}
			for _, row in ipairs(matrix.rows) do byKind[row.kind] = byKind[row.kind] or row end

			assert.equal("Testrealm", Tab.CellText(byKind.realm, char))
			assert.equal("|cffffd700124.532 g|r", Tab.CellText(byKind.gold, char))
			assert.equal("4T 5h", Tab.CellText(byKind.played, char))
			assert.equal("2 Stunden", Tab.CellText(byKind.lastSeen, char))
			assert.equal("489", Tab.CellText(byKind.ilvl, char))
			assert.equal("|cffe6cc803044|r", Tab.CellText(byKind.rating, char))
			assert.equal("BRH +16", Tab.CellText(byKind.keystone, char))
			assert.equal("|cffa335eeM|r |cff0070ddH|r", Tab.CellText(byKind.raids, char))
			assert.equal("", Tab.CellText(byKind.section, char)) -- Sektionen ohne Zellen
		end)

		it("Levelcap: Level ohne Nachkommastelle, Erholt '-' (Beta-Feedback 0.9.5)", function()
			mock.SetMaxPlayerLevel(90)
			seedChar("Default.Testrealm.Maxi", { ilvl = 302, level = 90 })
			local char = Tab.BuildMatrix().chars[1]
			-- Server liefert am Cap teils weiter xpMax > 0 / restXP = 0:
			char.summary.xp, char.summary.xpMax, char.summary.restXP = 0, 100000, 0

			assert.equal("90", Tab.CellText({ kind = "level" }, char))
			assert.equal("-", Tab.CellText({ kind = "rest" }, char))
		end)

		it("unter dem Cap: Level mit Fortschritt, Erholt mit Ampel", function()
			mock.SetMaxPlayerLevel(90)
			seedChar("Default.Testrealm.Klein", { ilvl = 100, level = 80 })
			local char = Tab.BuildMatrix().chars[1]
			char.summary.xp, char.summary.xpMax, char.summary.restXP = 30000, 100000, 150000

			assert.equal("80.3", Tab.CellText({ kind = "level" }, char))
			assert.equal("|cff00ff00100%|r", Tab.CellText({ kind = "rest" }, char))
		end)

		it("eingeloggter Char zeigt 'online'", function()
			local currentKey = "Default.Testrealm.Ich"
			seedChar(currentKey, { ilvl = 100 })
			-- Store haelt den aktuellen Char-Key aus SimulateLogin; neu anlegen:
			local matrix = Tab.BuildMatrix()
			for _, char in ipairs(matrix.chars) do
				if char.summary.isCurrent then
					assert.equal("|cff1eff00online|r",
						Tab.CellText({ kind = "lastSeen" }, char))
				end
			end
		end)
	end)

	describe("Schatzkammer-Erinnerung + Tooltip (0.9.5)", function()
		it("Statuszelle: Abholen! / Run-Zaehler / '-'", function()
			assert.equal("|cff1eff00Abholen!|r",
				Tab.FormatVaultStatusCell({ vaultRewards = true }))
			assert.equal("|cff80808012 Runs|r",
				Tab.FormatVaultStatusCell({ vaultRewards = false, runsThisWeek = 12 }))
			assert.equal("-", Tab.FormatVaultStatusCell({}))
		end)

		it("BuildVaultTooltip: Abhol-Hinweis, Slot-Status und Top-Runs", function()
			local mplus = fullMplus()
			mplus.vaultRewards = true
			mplus.runsThisWeek = 12
			mplus.topRuns = {
				{ mapID = 199, name = "Black Rook Hold", level = 23, completed = true },
				{ mapID = 244, name = "Atal'Dazar", level = 18, completed = false },
			}

			local lines = Tab.BuildVaultTooltip(mplus)
			assert.equal("|cffffd700Grosse Schatzkammer|r", lines[1])
			assert.equal("|cff1eff00Belohnungen abholbar - besuch die Schatzkammer!|r", lines[2])
			assert.equal("M+-Runs diese Woche: 12", lines[3])
			-- Slots aufsteigend nach Index; Slot 3 (8 Runs) hat erst 6 -> noch 2
			assert.equal("Slot 1 (1 Runs): |cff1eff00frei, Stufe +20|r", lines[4])
			assert.equal("Slot 2 (4 Runs): |cff1eff00frei, Stufe +19|r", lines[5])
			assert.equal("Slot 3 (8 Runs): |cff9d9d9dnoch 2 Run(s)|r", lines[6])
			assert.equal("|cffffd700Beste Runs diese Woche:|r", lines[8])
			assert.equal("|cff1eff00+23|r Black Rook Hold", lines[9])
			assert.equal("|cff9d9d9d+18|r Atal'Dazar", lines[10])
		end)

		it("ohne Belohnung/Runs: kompakter Tooltip", function()
			local lines = Tab.BuildVaultTooltip({ vault = {}, topRuns = {} })
			assert.equal(2, #lines)
			assert.equal("M+-Runs diese Woche: 0", lines[2])
		end)

		it("OnCellEnter zeigt nur fuer Schatzkammer-Zeilen einen Tooltip", function()
			seedChar("Default.Testrealm.Liquidora", { ilvl = 489, mplus = fullMplus() })
			local content = CreateFrame("Frame")
			Tab:Render(content)
			local anchor = CreateFrame("Frame")
			-- kein Fehler bei vaultstatus/vault und stilles Ignorieren sonst:
			Tab:OnCellEnter(anchor, { kind = "vaultstatus" }, 1)
			Tab:OnCellEnter(anchor, { kind = "gold" }, 1)
			Tab:OnCellEnter(anchor, { kind = "vault", vaultType = 1 }, 99) -- kein Char
		end)
	end)

	describe("Weeklies + Waehrungen (0.10.0)", function()
		local quests = {
			{ id = 90001, label = "Weltboss" },
			{ id = 90002, label = "Woechentliches Event" },
		}

		it("Weeklies-Zelle: 2/2 gruen, 1/2 gelb, 0/2 grau", function()
			assert.equal("|cff1eff002/2|r",
				Tab.FormatWeekliesCell({ [90001] = true, [90002] = true }, quests))
			assert.equal("|cffffd7001/2|r",
				Tab.FormatWeekliesCell({ [90001] = true, [90002] = false }, quests))
			assert.equal("|cff9d9d9d0/2|r", Tab.FormatWeekliesCell({}, quests))
			assert.equal("-", Tab.FormatWeekliesCell({}, {}))
		end)

		it("Weeklies-Tooltip: erledigt/offen je Quest", function()
			local lines = Tab.BuildWeekliesTooltip({ [90001] = true }, quests)
			assert.equal("|cffffd700Wochenaufgaben|r", lines[1])
			assert.equal("Weltboss: |cff1eff00erledigt|r", lines[2])
			assert.equal("Woechentliches Event: |cff9d9d9doffen|r", lines[3])
		end)

		it("Waehrungs-Zelle: Cap-Ampel rot/gelb/weiss, ohne Cap nur Menge", function()
			local currencies = {
				[3008] = { name = "Runenwappen", qty = 480, max = 480 },
				[3009] = { name = "Wappen", qty = 400, max = 480 },
				[3010] = { name = "Splitter", qty = 100, max = 480 },
				[2245] = { name = "Flugsteine", qty = 12530 },
			}
			assert.equal("|cffff4040480/480|r", Tab.FormatCurrencyCell(currencies, 3008))
			assert.equal("|cffffd700400/480|r", Tab.FormatCurrencyCell(currencies, 3009))
			assert.equal("|cffffffff100/480|r", Tab.FormatCurrencyCell(currencies, 3010))
			assert.equal("12.530", Tab.FormatCurrencyCell(currencies, 2245))
			assert.equal("-", Tab.FormatCurrencyCell(currencies, 999))
		end)

		it("BuildMatrix: Weeklies-Zeile + Waehrungs-Sektion (Automatik: nur mit Cap)", function()
			Exo.Data = {
				WeeklyQuests = quests,
				TrackedCurrencies = {},
			}
			seedChar("Default.Testrealm.Liquidora", { ilvl = 400 })
			local char = Exo.Store:GetCharacter("Default.Testrealm.Liquidora")
			char.currencies = {
				[3008] = { name = "Runenwappen", qty = 320, max = 480 },
				[2245] = { name = "Flugsteine", qty = 12530 }, -- kein Cap -> Automatik ignoriert
			}
			char.weeklies = { [90001] = true }

			local matrix = Tab.BuildMatrix()
			local byKind, sections = {}, {}
			for _, row in ipairs(matrix.rows) do
				byKind[row.kind] = byKind[row.kind] or row
				if row.kind == "section" then sections[#sections + 1] = row.label end
			end

			assert.is_table(byKind.weeklies)
			assert.same({ "Waehrungen" }, sections)
			assert.equal("Runenwappen", byKind.currency.label)
			assert.equal(3008, byKind.currency.currencyID)

			local c = matrix.chars[1]
			assert.equal("|cffffd7001/2|r", Tab.CellText(byKind.weeklies, c))
			assert.equal("|cffffffff320/480|r", Tab.CellText(byKind.currency, c))
			Exo.Data = nil
		end)

		it("gepflegte TrackedCurrencies-Liste hat Vorrang und Reihenfolge", function()
			Exo.Data = { WeeklyQuests = {}, TrackedCurrencies = { 2245, 3008 } }
			seedChar("Default.Testrealm.Liquidora", { ilvl = 400 })
			local char = Exo.Store:GetCharacter("Default.Testrealm.Liquidora")
			char.currencies = {
				[3008] = { name = "Runenwappen", qty = 320, max = 480 },
				[2245] = { name = "Flugsteine", qty = 12530 },
			}

			local ids = {}
			for _, row in ipairs(Tab.BuildMatrix().rows) do
				if row.kind == "currency" then ids[#ids + 1] = row.currencyID end
			end
			assert.same({ 2245, 3008 }, ids)
			Exo.Data = nil
		end)
	end)

	describe("Render", function()
		it("Kopfzeile klassengefaerbt, Footer mit Gesamtgold", function()
			seedChar("Default.Testrealm.Liquidora",
				{ ilvl = 489, classID = 8, gold = 50000, mplus = fullMplus() })
			local content = CreateFrame("Frame")
			Tab:Render(content)

			assert.equal("|cff69ccf0Liquidora|r", Tab._GetHeaderCells()[1]:GetText())
			assert.is_true(#Tab._GetScroller():GetData() >= 14)
			local footer = Tab._GetFooter():GetText()
			assert.truthy(footer:find("1 Charakter", 1, true))
			assert.truthy(footer:find("5 g", 1, true))
		end)

		it("ohne Chars: Hinweis statt Matrix", function()
			local content = CreateFrame("Frame")
			Tab:Render(content)
			assert.equal(0, #Tab._GetScroller():GetData())
			assert.truthy(Tab._GetFooter():GetText():find("Noch keine Charakterdaten", 1, true))
		end)

		it("blaettert ab 7 Charakteren", function()
			for i = 1, 7 do
				seedChar("Default.Testrealm.Char" .. i, { ilvl = 400 + i })
			end
			local content = CreateFrame("Frame")
			Tab:Render(content)

			assert.is_true(Tab._GetPageButton():IsShown())
			Tab:OnPageClick()
			assert.equal(2, Tab.page)
			Tab:OnPageClick()
			assert.equal(1, Tab.page)
		end)
	end)

	describe("Fenster-Integration", function()
		it("Reihenfolge: Uebersicht, Charaktere, Inventar, Bank, KM-Bank, KM-Items, Berufe, Post, Designer", function()
			assert.equal(Tab, Exo.UI.tabsById["characters"])
			assert.equal("overview", Exo.UI.tabs[1].id)
			assert.equal("characters", Exo.UI.tabs[2].id)
			assert.equal("inventory", Exo.UI.tabs[3].id)
			assert.equal("bank", Exo.UI.tabs[4].id)
			assert.equal("warbandbank", Exo.UI.tabs[5].id)
			assert.equal("warbound", Exo.UI.tabs[6].id)
			assert.equal("professions", Exo.UI.tabs[7].id)
			assert.equal("mail", Exo.UI.tabs[8].id)
			assert.equal("reputations", Exo.UI.tabs[9].id)
			assert.equal("designer", Exo.UI.tabs[10].id)
		end)
	end)
end)
