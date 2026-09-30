-- spec/itemcounts_spec.lua
local mock = require("spec.wow_mock")

describe("Exo.API ItemCounts", function()
	local Exo

	-- Standardbestand: Heilkraut (777) verteilt ueber 2 Chars + Kriegsmeute
	local function seed()
		local Store = Exo.Store
		Store:GetOrCreateCharacter("Default.Testrealm.Anna")
		Store:GetOrCreateCharacter("Default.Testrealm.Borg")

		Store:WriteCharacterData("Default.Testrealm.Anna", "bags", {
			[0] = { size = 16, free = 14, items = {
				[1] = { id = 777, count = 10 },
				[2] = { id = 888, count = 1 },
			} },
		})
		Store:WriteCharacterData("Default.Testrealm.Anna", "bank", {
			[-1] = { size = 28, free = 27, items = {
				[3] = { id = 777, count = 2 },
			} },
		})
		Store:WriteCharacterData("Default.Testrealm.Borg", "bags", {
			[0] = { size = 16, free = 15, items = {
				[1] = { id = 777, count = 5 },
			} },
		})
		Store:WriteAccountData("warbandBank", {
			[13] = { size = 98, free = 97, items = {
				[1] = { id = 777, count = 5 },
			} },
		})
	end

	before_each(function()
		mock.Reset()
		Exo = mock.LoadExoCore()
		mock.SimulateLogin()
		seed()
	end)

	describe("GetItemCounts", function()
		it("aggregiert Taschen, Bank und Kriegsmeute korrekt", function()
			local counts = Exo.API.GetItemCounts(777)

			assert.equal(22, counts.total) -- 10+2+5+5
			assert.equal(5, counts.warband)
			assert.same({ bags = 10, bank = 2, auctions = 0 },
				counts.chars["Default.Testrealm.Anna"])
			assert.same({ bags = 5, bank = 0, auctions = 0 },
				counts.chars["Default.Testrealm.Borg"])
		end)

		it("unbekanntes Item liefert Null-Struktur", function()
			local counts = Exo.API.GetItemCounts(999999)
			assert.equal(0, counts.total)
			assert.same({}, counts.chars)
		end)

		it("Rueckgabe ist eine Kopie (Cache nicht manipulierbar)", function()
			local counts = Exo.API.GetItemCounts(777)
			counts.total = 0
			counts.chars["Default.Testrealm.Anna"].bags = 0

			local fresh = Exo.API.GetItemCounts(777)
			assert.equal(22, fresh.total)
			assert.equal(10, fresh.chars["Default.Testrealm.Anna"].bags)
		end)
	end)

	describe("Cache-Invalidierung", function()
		it("Taschen-Update eines Chars aktualisiert die Counts", function()
			assert.equal(22, Exo.API.GetItemCounts(777).total) -- Cache aufgebaut

			Exo.Store:WriteCharacterData("Default.Testrealm.Borg", "bags", {
				[0] = { size = 16, free = 16, items = {} }, -- Borg hat alles verbraucht
			})

			assert.equal(17, Exo.API.GetItemCounts(777).total)
		end)

		it("Kriegsmeuten-Update invalidiert ebenfalls", function()
			assert.equal(22, Exo.API.GetItemCounts(777).total)
			Exo.Store:WriteAccountData("warbandBank", {})
			assert.equal(17, Exo.API.GetItemCounts(777).total)
		end)

		it("Charakter-Loeschung invalidiert", function()
			assert.equal(22, Exo.API.GetItemCounts(777).total)
			Exo.Store:DeleteCharacter("Default.Testrealm.Anna")
			assert.equal(10, Exo.API.GetItemCounts(777).total) -- 5 Borg + 5 KM
		end)

		it("Updates anderer Sektionen invalidieren NICHT (Cache bleibt warm)", function()
			assert.equal(22, Exo.API.GetItemCounts(777).total)
			-- Gold-Update darf den Item-Cache nicht wegwerfen; Counts bleiben korrekt
			Exo.Store:WriteCharacterData("Default.Testrealm.Anna", "gold", 1)
			assert.equal(22, Exo.API.GetItemCounts(777).total)
		end)
	end)

	describe("SearchItems", function()
		it("liefert alle Items, deren itemID der Matcher akzeptiert", function()
			local results = Exo.API.SearchItems(function(itemID)
				return itemID == 777 or itemID == 888
			end)

			assert.equal(2, #results)
			local byId = {}
			for _, r in ipairs(results) do byId[r.itemID] = r end
			assert.equal(22, byId[777].total)
			assert.equal(1, byId[888].total)
		end)

		it("leeres Ergebnis ohne Treffer", function()
			assert.same({}, Exo.API.SearchItems(function() return false end))
		end)
	end)
end)
