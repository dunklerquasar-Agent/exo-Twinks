-- spec/professions_spec.lua
-- Berufe-Collector + Public API (0.15.0)
local mock = require("spec.wow_mock")

describe("Professions-Collector + API", function()
	local Exo

	local function currentChar()
		return Exo.Store:GetCharacter(Exo.Store:GetCurrentKey())
	end

	before_each(function()
		mock.Reset()
		Exo = mock.LoadExoCore()
		mock.SetProfessions({
			{ name = "Alchemie", rank = 132, maxRank = 175, skillLineID = 171 },
			{ name = "Kraeuterkunde", rank = 150, maxRank = 175, skillLineID = 182 },
		})
		mock.SimulateLogin()
	end)

	describe("ScanHeaders", function()
		it("erfasst Berufe bei PLAYER_ENTERING_WORLD (entprellt)", function()
			mock.FireEvent("PLAYER_ENTERING_WORLD")
			mock.AdvanceTime(0.5)
			local profs = currentChar().professions
			assert.equal("Alchemie", profs[171].name)
			assert.equal(132, profs[171].rank)
			assert.equal(175, profs[171].maxRank)
			assert.equal("Kraeuterkunde", profs[182].name)
		end)

		it("verlernter Beruf verschwindet, Rezepte des anderen bleiben", function()
			mock.FireEvent("PLAYER_ENTERING_WORLD")
			mock.AdvanceTime(0.5)
			mock.SetTradeSkill(171, { { id = 2259, name = "Elixier der Loewen" } })
			mock.FireEvent("TRADE_SKILL_LIST_UPDATE")
			mock.AdvanceTime(0.5)

			mock.SetProfessions({
				{ name = "Alchemie", rank = 140, maxRank = 175, skillLineID = 171 },
			})
			mock.FireEvent("SKILL_LINES_CHANGED")
			mock.AdvanceTime(0.5)

			local profs = currentChar().professions
			assert.is_nil(profs[182])
			assert.equal(140, profs[171].rank)
			assert.equal("Elixier der Loewen", profs[171].recipes[2259].name) -- blieb erhalten
		end)
	end)

	describe("ScanRecipes", function()
		it("erfasst erlernte Rezepte nur bei offenem Berufsfenster", function()
			mock.FireEvent("PLAYER_ENTERING_WORLD")
			mock.AdvanceTime(0.5)

			-- Fenster zu -> kein Scan
			mock.FireEvent("TRADE_SKILL_LIST_UPDATE")
			mock.AdvanceTime(0.5)
			assert.same({}, currentChar().professions[171].recipes)

			mock.SetTradeSkill(171, {
				{ id = 2259, name = "Elixier der Loewen" },
				{ id = 3450, name = "Elixier des Verteidigers" },
				{ id = 9999, name = "Unbekanntes Rezept", learned = false },
			})
			mock.FireEvent("TRADE_SKILL_LIST_UPDATE")
			mock.AdvanceTime(0.5)

			local recipes = currentChar().professions[171].recipes
			assert.equal("Elixier der Loewen", recipes[2259].name)
			assert.equal("Elixier des Verteidigers", recipes[3450].name)
			assert.is_nil(recipes[9999]) -- nicht erlernt
		end)
	end)

	describe("Public API", function()
		local function seedProfessions(charKey, professions)
			Exo.Store:GetOrCreateCharacter(charKey)
			Exo.Store:WriteCharacterData(charKey, "professions", professions)
		end

		it("GetProfessions liefert sortierte Liste mit Rezept-Zaehler", function()
			seedProfessions("Default.Testrealm.Anna", {
				[171] = { name = "Alchemie", rank = 175, maxRank = 175,
					recipes = { [1] = "A", [2] = "B" } },
				[164] = { name = "Schmiedekunst", rank = 20, maxRank = 175, recipes = {} },
			})
			local list = Exo.API.GetProfessions("Default.Testrealm.Anna")
			assert.equal(2, #list)
			assert.equal("Alchemie", list[1].name)
			assert.equal(2, list[1].recipeCount)
			assert.equal("Schmiedekunst", list[2].name)
			assert.equal(0, list[2].recipeCount)
		end)

		it("SearchRecipes findet Rezepte ueber alle Chars ('wer kann X?')", function()
			seedProfessions("Default.Testrealm.Anna", {
				[171] = { name = "Alchemie", rank = 175, maxRank = 175,
					recipes = { [2259] = "Elixier der Loewen" } },
			})
			seedProfessions("Default.Testrealm.Bob", {
				[171] = { name = "Alchemie", rank = 100, maxRank = 175,
					recipes = { [2259] = "Elixier der Loewen", [77] = "Fläschchen X" } },
			})
			local results = Exo.API.SearchRecipes("elixier")
			assert.equal(1, #results)
			assert.equal("Elixier der Loewen", results[1].name)
			assert.equal("Alchemie", results[1].profession)
			assert.same({ "Default.Testrealm.Anna", "Default.Testrealm.Bob" },
				results[1].knownBy)
		end)

		it("SearchRecipes: unter 2 Zeichen keine Ergebnisse", function()
			assert.same({}, Exo.API.SearchRecipes("e"))
			assert.same({}, Exo.API.SearchRecipes(nil))
		end)
	end)
end)
