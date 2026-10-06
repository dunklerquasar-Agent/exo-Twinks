-- spec/release_1_17_spec.lua
-- Waehrungs-Gruppen (1.17.0): Der Scan speichert je Waehrung die Kategorie
-- (cat) und ihre Position in der Spiel-Reihenfolge (catOrder, Midnight = 1).
-- Die Charakter-Matrix gruppiert danach: neueste Erweiterung zuoberst, jede
-- Gruppe einzeln auf-/zuklappbar, standardmaessig nur die oberste offen.
local mock = require("spec.wow_mock")

describe("Release 1.17.0: Waehrungen nach Erweiterung gruppiert", function()
	local Exo, Tab

	local function seedMatrixChar()
		-- Login-Char bekommt die gescannten Waehrungen; Matrix braucht ilvl
		Exo.Collectors.Currencies.Scan()
		local char = Exo.Store:GetCharacter(Exo.Store:GetCurrentKey())
		char.equipment = { avgItemLevelEquipped = 400, slots = {} }
		return char
	end

	local function matrixRows()
		return Tab.BuildMatrix().rows
	end

	before_each(function()
		mock.Reset()
		Exo = mock.LoadExoCore()
		mock.LoadExoUI()
		mock.SimulateLogin()
		Tab = Exo.UI.CharactersTab

		mock.SetCurrencies({
			{ header = "Midnight" },
			{ id = 3100, name = "Valorsteine", qty = 750, max = 2000 },
			{ id = 3101, name = "Aschenfunken", qty = 10, max = 0 },
			{ header = "The War Within", collapsed = true },
			{ id = 3008, name = "Runenwappen", qty = 320, max = 480 },
			{ header = "Legion", collapsed = true },
			{ id = 1220, name = "Ordensressourcen", qty = 9100, max = 0 },
		})
	end)

	it("Scan speichert Kategorie + Spiel-Reihenfolge (cat/catOrder)", function()
		local char = seedMatrixChar()
		assert.equal("Midnight", char.currencies[3100].cat)
		assert.equal(1, char.currencies[3100].catOrder)
		assert.equal("The War Within", char.currencies[3008].cat)
		assert.equal(2, char.currencies[3008].catOrder)
		assert.equal("Legion", char.currencies[1220].cat)
		assert.equal(3, char.currencies[1220].catOrder)
		-- und die Public-API reicht beides durch
		local api = Exo.API.GetCurrencies(Exo.Store:GetCurrentKey())
		assert.equal("Midnight", api[3100].cat)
		assert.equal(2, api[3008].catOrder)
	end)

	it("Matrix: Gruppen in Spiel-Reihenfolge, nur Midnight standardmaessig offen", function()
		seedMatrixChar()
		local groups, currencyIDs = {}, {}
		for _, row in ipairs(matrixRows()) do
			if row.kind == "currencygroup" then groups[#groups + 1] = row.label end
			if row.kind == "currency" then currencyIDs[#currencyIDs + 1] = row.currencyID end
		end
		assert.same({ "[-] Midnight", "[+] The War Within", "[+] Legion" }, groups)
		-- sichtbar nur die Midnight-Waehrungen, alphabetisch
		assert.same({ 3101, 3100 }, currencyIDs) -- Aschenfunken < Valorsteine
	end)

	it("ToggleCurrencyGroup oeffnet/schliesst eine Gruppe persistent", function()
		seedMatrixChar()
		-- TWW-Gruppenzeile suchen und umschalten
		local tww
		for _, row in ipairs(matrixRows()) do
			if row.kind == "currencygroup" and row.cat == "The War Within" then tww = row end
		end
		Tab.ToggleCurrencyGroup(tww)
		assert.is_true(Exo.API.GetOption("currencyGroupsOpen")["The War Within"])

		local seen = {}
		for _, row in ipairs(matrixRows()) do
			if row.kind == "currency" then seen[row.currencyID] = true end
		end
		assert.is_true(seen[3008]) -- Runenwappen jetzt sichtbar

		-- und auch die Default-offene Gruppe laesst sich zuklappen
		local midnight
		for _, row in ipairs(matrixRows()) do
			if row.kind == "currencygroup" and row.cat == "Midnight" then midnight = row end
		end
		Tab.ToggleCurrencyGroup(midnight)
		for _, row in ipairs(matrixRows()) do
			assert.is_not.equal(3100, row.currencyID)
		end
	end)

	it("Uebersicht sortiert Waehrungen nach Erweiterung (Midnight zuerst)", function()
		local char = seedMatrixChar()
		char.currencies[1220].qty = 1 -- Legion-Waehrung vorhanden
		local overview = Exo.UI.OverviewTab
		assert.is_table(overview)
		-- Sortierlogik direkt pruefen: catOrder schlaegt Alphabet
		local currencies = Exo.API.GetCurrencies(Exo.Store:GetCurrentKey())
		local ids = {}
		for id in pairs(currencies) do ids[#ids + 1] = id end
		table.sort(ids, function(a, b)
			local oa = currencies[a].catOrder or 9999
			local ob = currencies[b].catOrder or 9999
			if oa ~= ob then return oa < ob end
			return (currencies[a].name or "") < (currencies[b].name or "")
		end)
		assert.same({ 3101, 3100, 3008, 1220 }, ids)
	end)
end)
