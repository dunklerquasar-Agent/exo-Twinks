-- spec/mythicplus_spec.lua
local mock = require("spec.wow_mock")

describe("Collector: MythicPlus + API.GetMythicPlus", function()
	local Exo

	local function seedMock()
		mock.SetMythicPlus({
			rating = 2532,
			keystone = { mapID = 199, level = 19 },
			maps = { [199] = "Neltharions Hort", [244] = "Atal'Dazar" },
			best = {
				[199] = { level = 18, score = 143, inTime = true },
				[244] = { level = 20, score = 160, inTime = false },
			},
			vault = {
				{ type = 1, index = 1, progress = 8, threshold = 1, level = 20 },
				{ type = 1, index = 2, progress = 8, threshold = 4, level = 19 },
				{ type = 1, index = 3, progress = 8, threshold = 8, level = 18 },
				{ type = 3, index = 1, progress = 2, threshold = 2, level = 16 },
				{ type = 3, index = 2, progress = 2, threshold = 4, level = 0 },
			},
		})
	end

	before_each(function()
		mock.Reset()
		Exo = mock.LoadExoCore()
		mock.SimulateLogin()
	end)

	it("PLAYER_ENTERING_WORLD scannt Wertung, Keystone, Dungeons und Schatzkammer", function()
		seedMock()
		mock.FireEvent("PLAYER_ENTERING_WORLD")
		mock.AdvanceTime(1.5) -- Debounce

		local mp = Exo.API.GetMythicPlus(Exo.Store:GetCurrentKey())
		assert.equal(2532, mp.rating)
		assert.equal(19, mp.keystone.level)
		assert.equal("Neltharions Hort", mp.keystone.name)
		assert.equal(18, mp.dungeons[199].level)
		assert.is_true(mp.dungeons[199].inTime)
		assert.equal(20, mp.dungeons[244].level)
		assert.is_false(mp.dungeons[244].inTime)
		assert.equal(5, #mp.vault)
		assert.equal(8, mp.vault[1].progress)
	end)

	it("CHALLENGE_MODE_COMPLETED aktualisiert die Daten (entprellt)", function()
		mock.FireEvent("PLAYER_ENTERING_WORLD")
		mock.AdvanceTime(1.5)
		assert.equal(0, Exo.API.GetMythicPlus(Exo.Store:GetCurrentKey()).rating)

		seedMock()
		mock.FireEvent("CHALLENGE_MODE_COMPLETED")
		mock.AdvanceTime(1.5)
		assert.equal(2532, Exo.API.GetMythicPlus(Exo.Store:GetCurrentKey()).rating)
	end)

	it("ohne Keystone bleibt keystone nil", function()
		mock.SetMythicPlus({ rating = 100 })
		mock.FireEvent("WEEKLY_REWARDS_UPDATE")
		mock.AdvanceTime(1.5)

		local mp = Exo.API.GetMythicPlus(Exo.Store:GetCurrentKey())
		assert.equal(100, mp.rating)
		assert.is_nil(mp.keystone)
	end)

	it("sammelt Abhol-Status und Wochen-Runs fuer den Schatzkammer-Tooltip", function()
		mock.SetMythicPlus({
			rating = 2000,
			hasRewards = true,
			maps = { [199] = "Neltharions Hort", [244] = "Atal'Dazar" },
			history = {
				{ mapChallengeModeID = 244, level = 20, completed = true },
				{ mapChallengeModeID = 199, level = 22, completed = true },
				{ mapChallengeModeID = 244, level = 18, completed = false },
			},
		})
		mock.FireEvent("WEEKLY_REWARDS_UPDATE")
		mock.AdvanceTime(1.5)

		local mp = Exo.API.GetMythicPlus(Exo.Store:GetCurrentKey())
		assert.is_true(mp.vaultRewards)
		assert.equal(3, mp.runsThisWeek)
		-- Top-Runs nach Level absteigend
		assert.equal(22, mp.topRuns[1].level)
		assert.equal("Neltharions Hort", mp.topRuns[1].name)
		assert.is_true(mp.topRuns[1].completed)
		assert.equal(20, mp.topRuns[2].level)
		assert.is_false(mp.topRuns[3].completed)
	end)

	it("API liefert Kopien und einen leeren Datensatz fuer unbekannte Chars", function()
		seedMock()
		mock.FireEvent("PLAYER_ENTERING_WORLD")
		mock.AdvanceTime(1.5)

		local key = Exo.Store:GetCurrentKey()
		local a = Exo.API.GetMythicPlus(key)
		a.rating = 9999
		a.dungeons[199].level = 99
		local b = Exo.API.GetMythicPlus(key)
		assert.equal(2532, b.rating)
		assert.equal(18, b.dungeons[199].level)

		local empty = Exo.API.GetMythicPlus("Default.Nix.Nemo")
		assert.equal(0, empty.rating)
		assert.same({}, empty.dungeons)
		assert.is_false(empty.vaultRewards)
		assert.equal(0, empty.runsThisWeek)
		assert.same({}, empty.topRuns)
	end)
end)
