-- spec/ui_reputations_spec.lua
-- Ruf-Tab (0.17.0)
local mock = require("spec.wow_mock")

describe("ExoTwinksUI / Ruf-Tab", function()
	local Exo, Tab

	local function seedReps(charKey, reps)
		local char = Exo.Store:GetOrCreateCharacter(charKey)
		local _, realm, name = Exo.Schema.ParseCharKey(charKey)
		char.meta.name = name
		char.meta.realm = realm
		char.meta.classID = 2
		Exo.Store:WriteCharacterData(charKey, "reputations", reps)
	end

	before_each(function()
		mock.Reset()
		Exo = mock.LoadExoCore()
		mock.SimulateLogin()
		mock.LoadExoUI()
		Tab = Exo.UI.ReputationsTab
		Tab.query = ""
	end)

	describe("StandingText", function()
		it("faerbt nach Bedeutung und zeigt Fortschritt", function()
			local text = Tab.StandingText({ standingID = 6, value = 1200, max = 12000 })
			assert.matches("|cff1eff00", text) -- Geehrt = gruen
			assert.matches("Geehrt", text)
			assert.matches("1.200/12.000", text)

			assert.matches("|cffffd700", Tab.StandingText({ standingID = 5, value = 0, max = 6000 }))
			assert.matches("|cff808080", Tab.StandingText({ standingID = 4, value = 0, max = 3000 }))
			assert.matches("|cffff4538", Tab.StandingText({ standingID = 2, value = 0, max = 3000 }))
			-- Ehrfuerchtig: kein Fortschrittsanhang
			local exalted = Tab.StandingText({ standingID = 8, value = 0, max = 0 })
			assert.matches("Ehrfuerchtig", exalted)
			assert.is_nil(exalted:find("/", 1, true))
		end)
	end)

	describe("BuildRows", function()
		before_each(function()
			seedReps("Default.Testrealm.Anna", {
				[2590] = { name = "Rat von Dornogal", standingID = 6, value = 100, max = 12000 },
				[2600] = { name = "Die Severed Threads", standingID = 4, value = 0, max = 3000 },
			})
			seedReps("Default.Testrealm.Bob", {
				[2590] = { name = "Rat von Dornogal", standingID = 8, value = 0, max = 0 },
			})
		end)

		it("Kopfzeile je Fraktion, bester Stand zuerst", function()
			local rows = Tab.BuildRows("")
			assert.is_true(rows[1].header)
			assert.equal("Die Severed Threads", rows[1].label) -- alphabetisch
			assert.matches("Anna", rows[2].text)
			assert.is_true(rows[3].header)
			assert.equal("Rat von Dornogal", rows[3].label)
			assert.matches("Bob", rows[4].text)       -- Ehrfuerchtig vor Geehrt
			assert.matches("Ehrfuerchtig", rows[4].text)
			assert.matches("Anna", rows[5].text)
		end)

		it("Filter grenzt auf Fraktionsnamen ein", function()
			local rows = Tab.BuildRows("dornogal")
			assert.equal("Rat von Dornogal", rows[1].label)
			assert.equal(3, #rows) -- Kopf + 2 Chars
		end)

		it("leere Zeilen ohne Daten; Leerzustand im Render (1.19.0)", function()
			mock.Reset()
			Exo = mock.LoadExoCore()
			mock.SimulateLogin()
			mock.LoadExoUI()
			Tab = Exo.UI.ReputationsTab
			assert.same({}, Tab.BuildRows(""))
			local content = CreateFrame("Frame")
			Tab:Render(content)
			local es = content._emptyState
			assert.is_true(es.host:IsShown())
			assert.truthy(es.title:GetText():find("Noch keine Ruf-Daten", 1, true))
		end)
	end)

	describe("Registrierung", function()
		it("Ruf ist 9. Reiter (vor Designer)", function()
			assert.equal(Tab, Exo.UI.tabsById["reputations"])
			assert.equal("reputations", Exo.UI.tabs[9].id)
			assert.equal("designer", Exo.UI.tabs[10].id)
		end)
	end)
end)
