-- spec/release_1_4_spec.lua
-- Berufe-Tiefe (1.4.0): Reagenzien-Scan, CanCraft, Craft-Status im UI.
local mock = require("spec.wow_mock")

describe("Release 1.4.0 (Berufe-Tiefe)", function()
	local Exo

	local function currentChar()
		return Exo.Store:GetCharacter(Exo.Store:GetCurrentKey())
	end

	local function scanAlchemy()
		mock.SetProfessions({
			{ name = "Alchemie", rank = 100, maxRank = 175, skillLineID = 171 },
		})
		mock.FireEvent("SKILL_LINES_CHANGED")
		mock.AdvanceTime(0.5)
		mock.SetTradeSkill(171, {
			{ id = 2259, name = "Elixier der Loewen", reagents = {
				{ itemID = 777, qty = 3 }, { itemID = 555, qty = 1 } } },
			{ id = 3450, name = "Simpler Trank" }, -- ohne Reagenzien-Daten
		})
		mock.FireEvent("TRADE_SKILL_LIST_UPDATE")
		mock.AdvanceTime(0.5)
	end

	before_each(function()
		mock.Reset()
		Exo = mock.LoadExoCore()
		mock.SimulateLogin()
		mock.SetItemNames({ [777] = "Friedensblume", [555] = "Kupferbarren" })
		scanAlchemy()
	end)

	describe("Reagenzien-Scan", function()
		it("speichert Pflicht-Materialien im neuen Rezeptformat", function()
			local recipe = currentChar().professions[171].recipes[2259]
			assert.equal("Elixier der Loewen", recipe.name)
			assert.same({ { itemID = 777, qty = 3 }, { itemID = 555, qty = 1 } },
				recipe.reagents)
		end)

		it("SearchRecipes versteht neues UND altes Format", function()
			-- alter String-Eintrag eines anderen Chars
			local char = Exo.Store:GetOrCreateCharacter("Default.Testrealm.Alt")
			char.meta.name = "Alt"
			Exo.Store:WriteCharacterData("Default.Testrealm.Alt", "professions", {
				[171] = { name = "Alchemie", rank = 1, maxRank = 175,
					recipes = { [2259] = "Elixier der Loewen" } },
			})
			local results = Exo.API.SearchRecipes("elixier")
			assert.equal(1, #results)
			assert.equal(2, #results[1].knownBy) -- beide Formate gefunden
		end)
	end)

	describe("CanCraft", function()
		it("nil bei unbekanntem Rezept oder fehlenden Reagenzien-Daten", function()
			assert.is_nil(Exo.API.CanCraft(99999))
			assert.is_nil(Exo.API.CanCraft(3450)) -- ohne Reagenzien gescannt
		end)

		it("prueft Bestaende ueber alle Quellen (ohne Auktionen)", function()
			-- 2x Friedensblume in Taschen, 1x in Kriegsmeute -> 3 von 3;
			-- Kupferbarren nur als eigene Auktion -> zaehlt NICHT
			Exo.Store:WriteCharacterData(Exo.Store:GetCurrentKey(), "bags", {
				[0] = { size = 16, free = 14, items = {
					[1] = { id = 777, count = 2 } } },
			})
			Exo.Store:WriteAccountData("warbandBank", {
				[13] = { size = 98, free = 97, items = { [1] = { id = 777, count = 1 } } },
			})
			Exo.Store:WriteCharacterData(Exo.Store:GetCurrentKey(), "auctions", {
				scannedAt = Exo.WowAPI.Now(),
				list = { { itemID = 555, qty = 5, buyout = 100, timeLeftBand = 3 } },
			})

			local result = Exo.API.CanCraft(2259)
			assert.is_false(result.craftable)
			assert.equal(3, result.reagents[1].have)  -- Friedensblume komplett
			assert.equal(0, result.reagents[2].have)  -- AH zaehlt nicht
			assert.equal(1, result.reagents[2].need)

			-- Kupferbarren in die Bank -> craftbar
			Exo.Store:WriteCharacterData(Exo.Store:GetCurrentKey(), "bank", {
				[-1] = { size = 28, free = 27, items = { [1] = { id = 555, count = 1 } } },
			})
			result = Exo.API.CanCraft(2259)
			assert.is_true(result.craftable)
		end)
	end)

	describe("UI", function()
		before_each(function()
			mock.LoadExoUI()
		end)

		it("CraftStatusText: gruen / gelb mit Fehlliste / grau", function()
			local Tab = Exo.UI.ProfessionsTab
			assert.matches("Materialien unbekannt", Tab.CraftStatusText(3450))
			local status = Tab.CraftStatusText(2259)
			assert.matches("|cffffd700", status)
			assert.matches("es fehlen:", status)
			assert.matches("3x Friedensblume", status)

			Exo.Store:WriteCharacterData(Exo.Store:GetCurrentKey(), "bags", {
				[0] = { size = 16, free = 12, items = {
					[1] = { id = 777, count = 3 }, [2] = { id = 555, count = 1 } } },
			})
			assert.matches("|cff1eff00craftbar|r", Tab.CraftStatusText(2259))
		end)

		it("Suche-Zeile traegt recipeID; Klick erzeugt Material-Report", function()
			local Tab = Exo.UI.ProfessionsTab
			local rows = Tab.BuildRows("elixier")
			assert.equal(2259, rows[1].recipeID)

			local report = Tab.MaterialReport(2259, "Elixier der Loewen")
			local all = table.concat(report, "\n")
			assert.matches("3x Friedensblume %(0 vorhanden%)", all)
			assert.matches("1x Kupferbarren", all)
			assert.matches("es fehlt etwas", all)

			-- Klick-Verkabelung: Zeile rendert und druckt in den Chat
			Tab.query = "elixier"
			Tab:Render(CreateFrame("Frame"))
			local row = Tab._GetScroller().rows[1]
			assert.equal(2259, row._recipeID)
			local before = #mock.printed
			row._scripts.OnMouseDown(row)
			assert.is_true(#mock.printed > before)
		end)
	end)
end)
