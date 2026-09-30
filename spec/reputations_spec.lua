-- spec/reputations_spec.lua
-- Ruf- und Quest-Collector + Konto-APIs (0.17.0)
local mock = require("spec.wow_mock")

describe("Reputations/Quests-Collector + Konto-APIs", function()
	local Exo

	local function currentChar()
		return Exo.Store:GetCharacter(Exo.Store:GetCurrentKey())
	end

	before_each(function()
		mock.Reset()
		Exo = mock.LoadExoCore()
		mock.SimulateLogin()
	end)

	describe("Reputations-Collector", function()
		it("scannt Fraktionen bei UPDATE_FACTION (entprellt)", function()
			mock.SetReputations({
				{ factionID = 2590, name = "Rat von Dornogal",
					standingID = 6, value = 1200, max = 12000 },
			})
			mock.FireEvent("UPDATE_FACTION")
			mock.AdvanceTime(1)

			local reps = currentChar().reputations
			assert.equal("Rat von Dornogal", reps[2590].name)
			assert.equal(6, reps[2590].standingID)
			assert.equal(1200, reps[2590].value)
			assert.equal(12000, reps[2590].max)
		end)
	end)

	describe("Quests-Collector", function()
		it("scannt das Questlog bei QUEST_LOG_UPDATE (entprellt)", function()
			mock.SetQuestLog({
				{ questID = 101, title = "Die letzte Schlacht" },
				{ questID = 202, title = "Kraeuter sammeln" },
			})
			mock.FireEvent("QUEST_LOG_UPDATE")
			mock.AdvanceTime(1)

			local quests = currentChar().quests
			assert.equal("Die letzte Schlacht", quests[101])
			assert.equal("Kraeuter sammeln", quests[202])
		end)
	end)

	describe("Konto-APIs", function()
		it("GetReputations sortiert nach Fraktionsname", function()
			Exo.Store:WriteCharacterData(Exo.Store:GetCurrentKey(), "reputations", {
				[2] = { name = "Zeta", standingID = 8, value = 0, max = 0 },
				[1] = { name = "Alpha", standingID = 4, value = 10, max = 3000 },
			})
			local list = Exo.API.GetReputations(Exo.Store:GetCurrentKey())
			assert.equal("Alpha", list[1].name)
			assert.equal("Zeta", list[2].name)
		end)

		it("GetQuests sortiert nach Titel", function()
			Exo.Store:WriteCharacterData(Exo.Store:GetCurrentKey(), "quests", {
				[9] = "Zuletzt", [3] = "Anfang",
			})
			local list = Exo.API.GetQuests(Exo.Store:GetCurrentKey())
			assert.equal("Anfang", list[1].title)
			assert.equal("Zuletzt", list[2].title)
		end)

		it("GetGoldByRealm summiert pro Realm, absteigend nach Gold", function()
			local function seed(charKey, gold)
				local char = Exo.Store:GetOrCreateCharacter(charKey)
				local _, realm, name = Exo.Schema.ParseCharKey(charKey)
				char.meta.name = name
				char.meta.realm = realm
				char.gold = gold
			end
			seed("Default.Arm.Eins", 100)
			seed("Default.Reich.Zwei", 5000)
			seed("Default.Reich.Drei", 5000)

			local list = Exo.API.GetGoldByRealm()
			-- Login-Char hat 0 Gold auf eigenem Realm -> letzter Platz
			assert.equal("Reich", list[1].realm)
			assert.equal(10000, list[1].gold)
			assert.equal(2, list[1].chars)
			assert.equal("Arm", list[2].realm)
		end)
	end)
end)
