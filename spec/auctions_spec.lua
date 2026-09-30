-- spec/auctions_spec.lua
-- Auktionen (1.3.0): Collector, APIs, Zaehler-Integration, Modul, /exo ah.
local mock = require("spec.wow_mock")

describe("Auktionen", function()
	local Exo

	local function currentKey() return Exo.Store:GetCurrentKey() end

	local function openAndScan(auctions)
		mock.SetOwnedAuctions(auctions)
		mock.FireEvent("AUCTION_HOUSE_SHOW")
		mock.FireEvent("OWNED_AUCTIONS_UPDATED")
		mock.AdvanceTime(0.5)
	end

	before_each(function()
		mock.Reset()
		Exo = mock.LoadExoCore()
		mock.SimulateLogin()
	end)

	describe("Collector", function()
		it("scannt nur bei offenem AH (entprellt)", function()
			mock.SetOwnedAuctions({ { itemID = 777, qty = 20, buyout = 50000, band = 2 } })
			mock.FireEvent("OWNED_AUCTIONS_UPDATED")
			mock.AdvanceTime(1)
			assert.same({}, Exo.Store:GetCharacter(currentKey()).auctions)

			openAndScan({ { itemID = 777, qty = 20, buyout = 50000, band = 2 },
				{ itemID = 555, qty = 1, buyout = 90000, band = 0, sold = true } })
			local data = Exo.Store:GetCharacter(currentKey()).auctions
			assert.is_number(data.scannedAt)
			assert.equal(2, #data.list)
			assert.equal(777, data.list[1].itemID)
			assert.is_true(data.list[2].sold)
		end)
	end)

	describe("APIs", function()
		it("GetAuctions berechnet expiresBy und sortiert nach Ablauf", function()
			openAndScan({
				{ itemID = 777, qty = 20, buyout = 50000, band = 3 },
				{ itemID = 555, qty = 1, buyout = 90000, band = 0 },
			})
			local data = Exo.API.GetAuctions(currentKey())
			assert.equal(555, data.auctions[1].itemID) -- Band 0 zuerst
			assert.equal(data.scannedAt + 1800, data.auctions[1].expiresBy)
			assert.equal(data.scannedAt + 172800, data.auctions[2].expiresBy)
			assert.is_nil(Exo.API.GetAuctions("Default.Nix.Niemand"))
		end)

		it("GetAuctionSummary trennt aktiv/verkauft und summiert Buyout", function()
			openAndScan({
				{ itemID = 777, qty = 20, buyout = 50000, band = 1 },
				{ itemID = 778, qty = 5, buyout = 20000, band = 3 },
				{ itemID = 555, qty = 1, buyout = 90000, band = 0, sold = true },
			})
			local summary = Exo.API.GetAuctionSummary()
			assert.equal(1, #summary.chars)
			assert.equal(2, summary.chars[1].count)
			assert.equal(1, summary.chars[1].soldCount)
			assert.equal(70000, summary.chars[1].buyoutTotal)
			assert.equal(1, summary.chars[1].soonestBand) -- verkauftes Band 0 zaehlt nicht
			assert.equal(70000, summary.totalBuyout)
		end)
	end)

	describe("Integration in Zaehler + Suche", function()
		before_each(function()
			mock.LoadExoUI()
			mock.SetItemNames({ [777] = "Friedensblume" })
			openAndScan({
				{ itemID = 777, qty = 20, buyout = 50000, band = 2 },
				{ itemID = 777, qty = 5, buyout = 10000, band = 1, sold = true },
			})
		end)

		it("GetItemCounts zaehlt aktive Auktionen (verkaufte nicht)", function()
			local counts = Exo.API.GetItemCounts(777)
			assert.equal(20, counts.total)
			local charEntry = counts.chars[currentKey()]
			assert.equal(20, charEntry.auctions)
		end)

		it("Suche: Breakdown nennt AH, Ort-Filter 'auctions' greift", function()
			local Search = Exo.UI.SearchTab
			Search.ResetFilters()
			local results = Search.GatherResults("friedensblume")
			assert.equal(1, #results)
			assert.matches("AH 20", Search.BuildBreakdown(results[1]))
			assert.equal(1, #Search.ApplyFilters(results,
				{ quality = 0, location = "auctions" }))
			assert.equal(0, #Search.ApplyFilters(results,
				{ quality = 0, location = "bags" }))
		end)

		it("Tooltip-Zeile nennt AH-Bestand", function()
			local lines = Exo.Services.Tooltip.BuildLines(Exo.API.GetItemCounts(777))
			local all = table.concat(lines, "\n")
			assert.matches("AH 20", all)
		end)
	end)

	describe("Modul + Slash", function()
		before_each(function()
			openAndScan({
				{ itemID = 777, qty = 20, buyout = 1230000, band = 0 },
				{ itemID = 555, qty = 1, buyout = 0, band = 3, sold = true },
			})
		end)

		it("Uebersicht-Modul zeigt Char, Buyout, verkauft und Ablauf", function()
			mock.LoadExoUI()
			local rows = Exo.UI.OverviewTab.BuildModuleRows("auctions")
			assert.matches("1 Auktion", rows[1].text)
			assert.matches("123", rows[1].text)                -- Buyout-Gold
			assert.matches("1 verkauft", rows[1].text)
			assert.matches("unter 30 Min", rows[1].text)
			assert.matches("|cffff4538", rows[1].text)         -- Band 0 = rot
			assert.matches("Gesamt", rows[#rows].text)
		end)

		it("/exo ah gibt den Bericht aus", function()
			local before = #mock.printed
			_G.SlashCmdList["EXO"]("ah")
			local out = table.concat(mock.printed, "\n", before + 1)
			assert.matches("1 Auktionen, Buyout 123g", out)
			assert.matches("1 verkauft", out)
			assert.matches("Gesamt: 1 Auktionen", out)
		end)
	end)
end)
