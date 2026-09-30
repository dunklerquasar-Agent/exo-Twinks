-- spec/weeklies_spec.lua
local mock = require("spec.wow_mock")

describe("Collector: Weeklies + API", function()
	local Exo

	before_each(function()
		mock.Reset()
		Exo = mock.LoadExoCore()
		mock.SimulateLogin()
		mock.LoadExoData()
		-- Saisonliste (in echt aus ExoTwinksData/Season.lua)
		Exo.Data.WeeklyQuests = {
			{ id = 90001, label = "Weltboss" },
			{ id = 90002, label = "Woechentliches Event" },
			{ id = 90003, label = "Delve-Bonus" },
		}
	end)

	it("scannt die Saisonliste gegen den Quest-Flag-Status", function()
		mock.SetCompletedQuests({ [90001] = true, [90003] = true })
		mock.FireEvent("PLAYER_ENTERING_WORLD")
		mock.AdvanceTime(1.5)

		local weeklies = Exo.API.GetWeeklies(Exo.Store:GetCurrentKey())
		assert.is_true(weeklies[90001])
		assert.is_false(weeklies[90002])
		assert.is_true(weeklies[90003])
	end)

	it("QUEST_TURNED_IN aktualisiert entprellt", function()
		mock.FireEvent("PLAYER_ENTERING_WORLD")
		mock.AdvanceTime(1.5)
		assert.is_false(Exo.API.GetWeeklies(Exo.Store:GetCurrentKey())[90001])

		mock.SetCompletedQuests({ [90001] = true })
		mock.FireEvent("QUEST_TURNED_IN")
		mock.AdvanceTime(1.5)
		assert.is_true(Exo.API.GetWeeklies(Exo.Store:GetCurrentKey())[90001])
	end)

	it("leere Saisonliste -> leere Sektion, kein Fehler", function()
		Exo.Data.WeeklyQuests = {}
		mock.FireEvent("PLAYER_ENTERING_WORLD")
		mock.AdvanceTime(1.5)
		assert.same({}, Exo.API.GetWeeklies(Exo.Store:GetCurrentKey()))
	end)

	it("API-Listen sind Kopien aus ExoTwinksData", function()
		local list = Exo.API.GetWeeklyQuestList()
		assert.equal(3, #list)
		assert.equal("Weltboss", list[1].label)
		list[1].label = "kaputt"
		assert.equal("Weltboss", Exo.API.GetWeeklyQuestList()[1].label)

		Exo.Data.TrackedCurrencies = { 3008, 2245 }
		assert.same({ 3008, 2245 }, Exo.API.GetTrackedCurrencies())
	end)

	it("GetCurrencies liefert Kopien", function()
		mock.SetCurrencies({ { id = 3008, name = "Runenwappen", qty = 320, max = 480 } })
		mock.FireEvent("CURRENCY_DISPLAY_UPDATE")
		mock.AdvanceTime(1.5)

		local key = Exo.Store:GetCurrentKey()
		local a = Exo.API.GetCurrencies(key)
		assert.equal(320, a[3008].qty)
		a[3008].qty = 999
		assert.equal(320, Exo.API.GetCurrencies(key)[3008].qty)
	end)
end)
