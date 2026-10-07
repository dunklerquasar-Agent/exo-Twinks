-- spec/ui_professions_spec.lua
-- Berufe-Tab (0.15.0)
local mock = require("spec.wow_mock")

describe("ExoTwinksUI / Berufe-Tab", function()
	local Exo, Tab

	local function seedProfessions(charKey, professions)
		local char = Exo.Store:GetOrCreateCharacter(charKey)
		local _, realm, name = Exo.Schema.ParseCharKey(charKey)
		char.meta.name = name
		char.meta.realm = realm
		char.meta.classID = 2
		Exo.Store:WriteCharacterData(charKey, "professions", professions)
	end

	before_each(function()
		mock.Reset()
		Exo = mock.LoadExoCore()
		mock.SimulateLogin()
		mock.LoadExoUI()
		Tab = Exo.UI.ProfessionsTab
		Tab.query = ""
	end)

	describe("BuildRows (Uebersicht)", function()
		it("leere Zeilen ohne Berufsdaten; Leerzustand im Render (1.19.0)", function()
			assert.same({}, Tab.BuildRows(""))
			local content = CreateFrame("Frame")
			Tab:Render(content)
			local es = content._emptyState
			assert.is_true(es.host:IsShown())
			assert.truthy(es.title:GetText():find("Noch keine Berufsdaten", 1, true))
			assert.truthy(es.hint:GetText():find("Berufsfensters erfasst", 1, true))
		end)

		it("pro Char eine Kopfzeile + eine Zeile je Beruf", function()
			seedProfessions("Default.Testrealm.Anna", {
				[171] = { name = "Alchemie", rank = 132, maxRank = 175,
					recipes = { [1] = "A", [2] = "B", [3] = "C" } },
				[182] = { name = "Kraeuterkunde", rank = 150, maxRank = 175, recipes = {} },
			})
			local rows = Tab.BuildRows("")
			assert.is_true(rows[1].header)
			assert.matches("Anna", rows[1].label)
			assert.matches("Alchemie", rows[2].text)
			assert.matches("132/175", rows[2].text)
			assert.matches("3 Rezepte", rows[2].text)
			assert.matches("Kraeuterkunde", rows[3].text)
			assert.matches("Berufsfenster einmal oeffnen", rows[3].text)
		end)
	end)

	describe("BuildRows (Rezept-Suche)", function()
		before_each(function()
			seedProfessions("Default.Testrealm.Anna", {
				[171] = { name = "Alchemie", rank = 175, maxRank = 175,
					recipes = { [2259] = "Elixier der Loewen" } },
			})
		end)

		it("zeigt Treffer mit 'kann:'-Liste", function()
			local rows = Tab.BuildRows("elixier")
			assert.equal(1, #rows)
			assert.matches("Elixier der Loewen", rows[1].text)
			assert.matches("Alchemie", rows[1].text)
			assert.matches("kann:", rows[1].text)
			assert.matches("Anna", rows[1].text)
		end)

		it("keine Treffer -> Leerzustand im Render (1.19.0)", function()
			assert.same({}, Tab.BuildRows("fasnacht"))
			local content = CreateFrame("Frame")
			Tab.query = "fasnacht"
			Tab:Render(content)
			local es = content._emptyState
			assert.is_true(es.host:IsShown())
			assert.truthy(es.title:GetText():find("Keine Rezepte gefunden", 1, true))
		end)
	end)

	describe("Render + Registrierung", function()
		it("Berufe ist 7. Reiter (vor Designer)", function()
			assert.equal(Tab, Exo.UI.tabsById["professions"])
			assert.equal("professions", Exo.UI.tabs[7].id)
			assert.equal("mail", Exo.UI.tabs[8].id)
			assert.equal("designer", Exo.UI.tabs[10].id)
		end)

		it("Render befuellt Scroller und Footer", function()
			seedProfessions("Default.Testrealm.Anna", {
				[171] = { name = "Alchemie", rank = 175, maxRank = 175,
					recipes = { [2259] = "Elixier der Loewen" } },
			})
			local content = CreateFrame("Frame")
			Tab:Render(content)
			assert.is_true(#Tab._GetScroller():GetData() >= 2)
			assert.matches("Berufsfenster", Tab._GetFooter():GetText())

			Tab.query = "elixier"
			Tab:Render(content)
			assert.matches("1 Rezept gefunden", Tab._GetFooter():GetText())
		end)
	end)
end)
