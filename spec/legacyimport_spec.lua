-- spec/legacyimport_spec.lua
local mock = require("spec.wow_mock")
local fixture = require("spec.fixtures.legacy_datastore")

describe("LegacyImport", function()
	local Exo

	before_each(function()
		mock.Reset()
		Exo = mock.LoadExoCore()
		mock.SimulateLogin()
	end)

	describe("Scan", function()
		it("meldet 'nichts gefunden' ohne Legacy-Daten", function()
			local report = Exo.LegacyImport:Scan()
			assert.is_false(report.found)
			assert.equal(0, report.total)
		end)

		it("findet alle Legacy-Charaktere und schreibt dabei NICHTS", function()
			fixture.Install()
			local before = Exo.Store:CountCharacters()

			local report = Exo.LegacyImport:Scan()

			assert.is_true(report.found)
			assert.equal(3, report.total)
			assert.equal(3, report.importable)
			assert.equal(before, Exo.Store:CountCharacters()) -- nichts angelegt
		end)

		it("zaehlt bereits vorhandene Charaktere nicht als importierbar", function()
			fixture.Install()
			Exo.Store:GetOrCreateCharacter("Default.Testrealm.Altfried")

			local report = Exo.LegacyImport:Scan()
			assert.equal(3, report.total)
			assert.equal(2, report.importable)
		end)
	end)

	describe("Import", function()
		it("uebernimmt Meta-Daten inkl. dekodiertem BaseInfo-Bitfeld", function()
			fixture.Install()
			local imported, skipped = Exo.LegacyImport:Import()

			assert.equal(3, imported)
			assert.equal(0, skipped)

			local char = Exo.Store:GetCharacter("Default.Testrealm.Altfried")
			assert.equal("Altfried", char.meta.name)
			assert.equal("Testrealm", char.meta.realm)
			assert.equal(80, char.meta.level)      -- aus Bits 0-6
			assert.equal(2, char.meta.classID)     -- aus Bits 7-10 (Paladin)
			assert.equal(1, char.meta.raceID)      -- aus Bits 11-17 (Mensch)
			assert.equal(5000000, char.gold)
			assert.equal(360000, char.meta.playedTotal)
			assert.equal("Dornogal", char.meta.zone)
			assert.equal(1650000000, char.meta.lastSeen)
		end)

		it("behandelt den Logout-Sentinel (5 Mrd.) als 'unbekannt'", function()
			fixture.Install()
			Exo.LegacyImport:Import()

			local bankalt = Exo.Store:GetCharacter("Default.Testrealm.Bankalt")
			assert.equal(0, bankalt.meta.lastSeen)
		end)

		it("ueberspringt vorhandene Charaktere (neue Daten gewinnen)", function()
			fixture.Install()
			local existing = Exo.Store:GetOrCreateCharacter("Default.Testrealm.Altfried")
			existing.gold = 111
			existing.meta.level = 81

			local imported, skipped = Exo.LegacyImport:Import()

			assert.equal(2, imported)
			assert.equal(1, skipped)
			assert.equal(111, existing.gold)       -- nicht ueberschrieben
			assert.equal(81, existing.meta.level)
		end)

		it("ist idempotent: zweiter Import ist ein No-Op", function()
			fixture.Install()
			Exo.LegacyImport:Import()
			local imported, skipped = Exo.LegacyImport:Import()

			assert.equal(0, imported)
			assert.equal(3, skipped)
		end)

		it("laesst die Legacy-Daten selbst unangetastet", function()
			fixture.Install()
			Exo.LegacyImport:Import()

			assert.equal(3, #_G.DataStore_CharacterIDs.List)
			assert.equal("Altfried", _G.DataStore_Characters_Info[1].name)
		end)

		it("uebernimmt Taschen und Bank (bit-dekodiert, im Collector-Format)", function()
			fixture.Install()
			Exo.LegacyImport:Import()

			local char = Exo.Store:GetCharacter("Default.Testrealm.Altfried")
			-- Ruecksack: 2 Items, Groesse aus info-Bits
			assert.equal(32, char.bags[0].size)
			assert.equal(30, char.bags[0].free)
			assert.same({ id = 228741, count = 16 }, char.bags[0].items[1])
			assert.same({ id = 190320, count = 3 }, char.bags[0].items[4])
			-- Reagenzientasche zaehlt zu den Taschen
			assert.same({ id = 228741, count = 4 }, char.bags[5].items[2])
			-- Bank-Tab 6 landet in der Bank-Sektion
			assert.same({ id = 228741, count = 7 }, char.bank[6].items[10])
			-- leerer Bank-Tab 7 wird nicht angelegt
			assert.is_nil(char.bank[7])
		end)

		it("faellt ohne info-Feld auf den hoechsten belegten Slot zurueck", function()
			fixture.Install()
			Exo.LegacyImport:Import()

			local mage = Exo.Store:GetCharacter("Default.Zweitrealm.Magierin")
			assert.equal(3, mage.bags[0].size)
			assert.same({ id = 190320, count = 5 }, mage.bags[0].items[3])
		end)

		it("uebernimmt das Itemlevel aus DataStore_Inventory", function()
			fixture.Install()
			Exo.LegacyImport:Import()

			local char = Exo.Store:GetCharacter("Default.Testrealm.Altfried")
			assert.equal(481.6, char.equipment.avgItemLevelEquipped)
			-- Bankalt hat keine Inventory-Daten -> Equipment bleibt leer (Schema-Default)
			assert.is_nil(next(Exo.Store:GetCharacter("Default.Testrealm.Bankalt").equipment))
		end)

		it("uebernimmt die Kriegsmeutenbank, aber nur wenn noch nichts gescannt wurde", function()
			fixture.Install()
			Exo.LegacyImport:Import()

			local warband = Exo.Store:GetAccount().warbandBank
			assert.same({ id = 228741, count = 100 }, warband[13].items[1])

			-- eigener Scan vorhanden -> Import darf NICHT ueberschreiben
			mock.Reset()
			fixture.Install()
			Exo = mock.LoadExoCore()
			mock.SimulateLogin()
			Exo.Store:WriteAccountData("warbandBank", { [13] = { size = 98, free = 98, items = {} } })
			Exo.LegacyImport:Import()
			assert.is_nil(next(Exo.Store:GetAccount().warbandBank[13].items))
		end)

		it("ergaenzt vorhandenen Charakteren fehlende Bank/iLvl, ohne Taschen zu ueberschreiben", function()
			fixture.Install()
			-- Altfried existiert schon (z.B. eingeloggt) und hat eigene Taschendaten
			local existing = Exo.Store:GetOrCreateCharacter("Default.Testrealm.Altfried")
			existing.bags = { [0] = { size = 20, free = 19, items = { [1] = { id = 999, count = 1 } } } }

			local imported, skipped, supplemented = Exo.LegacyImport:Import()

			assert.equal(2, imported)
			assert.equal(1, skipped)
			assert.equal(1, supplemented)
			-- eigene Taschen unangetastet (neue Daten gewinnen)
			assert.same({ id = 999, count = 1 }, existing.bags[0].items[1])
			-- fehlende Bank + iLvl aus den Altdaten ergaenzt
			assert.same({ id = 228741, count = 7 }, existing.bank[6].items[10])
			assert.equal(481.6, existing.equipment.avgItemLevelEquipped)
		end)

		it("Repro Beta-Test: Tooltip-Zaehler kennen nach dem Import Bank + fremde Chars", function()
			fixture.Install()
			Exo.LegacyImport:Import()

			-- Heisse Honigwabe (228741): 16+4 Taschen + 7 Bank (Altfried) + 100 Kriegsmeute
			local counts = Exo.API.GetItemCounts(228741)
			assert.equal(127, counts.total)
			assert.equal(100, counts.warband)
			assert.equal(20, counts.chars["Default.Testrealm.Altfried"].bags)
			assert.equal(7, counts.chars["Default.Testrealm.Altfried"].bank)
		end)

		it("feuert EXO_LEGACY_IMPORT_DONE mit Zaehlern", function()
			fixture.Install()
			local got
			Exo.EventBus:Register("EXO_LEGACY_IMPORT_DONE", function(_, imported, skipped)
				got = { imported, skipped }
			end)

			Exo.LegacyImport:Import()
			assert.same({ 3, 0 }, got)
		end)
	end)

	describe("/alto import Kommandos", function()
		local function run(msg) _G.SlashCmdList["EXO"](msg) end

		it("'import' listet importierbare Charaktere", function()
			fixture.Install()
			run("import")

			local out = table.concat(mock.printed, "\n")
			assert.truthy(out:find("Default.Zweitrealm.Magierin", 1, true))
			assert.truthy(out:find("confirm", 1, true))
		end)

		it("'import confirm' fuehrt den Import aus", function()
			fixture.Install()
			run("import confirm")

			assert.equal(4, Exo.Store:CountCharacters()) -- 3 + Testchar
			assert.truthy(mock.printed[#mock.printed]:find("3 uebernommen", 1, true))
		end)

		it("'import dismiss' unterdrueckt den Login-Hinweis dauerhaft", function()
			run("import dismiss")
			assert.is_true(Exo.Store:GetAccount().options.legacyImportDismissed)
		end)

		it("Login-Hinweis erscheint, wenn Altdaten importierbar sind", function()
			mock.Reset()
			fixture.Install()
			Exo = mock.LoadExoCore()
			mock.SimulateLogin()

			local out = table.concat(mock.printed, "\n")
			assert.truthy(out:find("importierbare", 1, true))
		end)
	end)
end)
