-- spec/guildbank_spec.lua
-- Gildenbank-Collector + Integration in Zaehler/Suche (0.16.0)
local mock = require("spec.wow_mock")

describe("GuildBank-Collector + Integration", function()
	local Exo

	before_each(function()
		mock.Reset()
		Exo = mock.LoadExoCore()
		mock.SimulateLogin()
		mock.SetGuildBank("Die Nachtwache", {
			[1] = { [1] = { id = 777, count = 40 }, [5] = { id = 555, count = 3 } },
		})
	end)

	it("GUILDBANKFRAME_OPENED scannt alle Tabs im BagSet-Format", function()
		mock.FireEvent("GUILDBANKFRAME_OPENED")
		local guilds = Exo.Store:GetGuilds()
		local guild = guilds["Die Nachtwache"]
		assert.is_table(guild)
		assert.equal(98, guild.bank[1].size)
		assert.equal(96, guild.bank[1].free)
		assert.same({ id = 777, count = 40 }, guild.bank[1].items[1])
		assert.is_number(guild.scannedAt)
	end)

	it("ohne Gilde wird nichts geschrieben", function()
		mock.SetGuildBank(nil, {})
		mock.FireEvent("GUILDBANKFRAME_OPENED")
		local count = 0
		for _ in pairs(Exo.Store:GetGuilds()) do count = count + 1 end
		assert.equal(0, count)
	end)

	it("Aenderungen bei offener Bank werden entprellt uebernommen", function()
		mock.FireEvent("GUILDBANKFRAME_OPENED")
		mock.SetGuildBank("Die Nachtwache", {
			[1] = { [1] = { id = 777, count = 99 } },
		})
		mock.FireEvent("GUILDBANKBAGSLOTS_CHANGED")
		mock.AdvanceTime(0.5)
		assert.equal(99, Exo.Store:GetGuilds()["Die Nachtwache"].bank[1].items[1].count)
	end)

	describe("Integration", function()
		before_each(function()
			mock.FireEvent("GUILDBANKFRAME_OPENED")
		end)

		it("GetItemCounts zaehlt Gildenbank mit (getrennt ausgewiesen)", function()
			local counts = Exo.API.GetItemCounts(777)
			assert.equal(40, counts.total)
			assert.equal(40, counts.guilds["Die Nachtwache"])
		end)

		it("SearchItems liefert guilds-Feld; Ort-Filter 'guild' greift", function()
			mock.LoadExoUI()
			local Search = Exo.UI.SearchTab
			mock.SetItemNames({ [777] = "Friedensblume", [555] = "Kupferbarren" })

			local results = Search.GatherResults("friedensblume")
			assert.equal(1, #results)
			assert.equal(40, results[1].guilds["Die Nachtwache"])
			assert.matches("Gildenbank Die Nachtwache 40",
				Search.BuildBreakdown(results[1]))

			-- Ort-Filter: Gildenbank
			local filtered = Search.ApplyFilters(results,
				{ quality = 0, location = "guild" })
			assert.equal(1, #filtered)
			filtered = Search.ApplyFilters(results,
				{ quality = 0, location = "bags" })
			assert.equal(0, #filtered)
		end)
	end)
end)
