-- spec/currencies_spec.lua
local mock = require("spec.wow_mock")

describe("Currencies-Collector", function()
	local Exo

	local function currentChar()
		return Exo.Store:GetCharacter(Exo.Store:GetCurrentKey())
	end

	before_each(function()
		mock.Reset()
		Exo = mock.LoadExoCore()
		mock.SimulateLogin()

		mock.SetCurrencies({
			{ header = "Saison der Entdeckungen" },
			{ id = 3008, name = "Valorsteine", qty = 750, max = 2000 },
			{ id = 2245, name = "Flugsteine", qty = 12345, max = 0 },
			{ header = "Legacy" },
			{ id = 1166, name = "Kriegsressourcen", qty = 400, max = 0 },
		})
	end)

	it("scannt entprellt und ueberspringt Header-Zeilen", function()
		mock.FireEvent("CURRENCY_DISPLAY_UPDATE")
		mock.FireEvent("CURRENCY_DISPLAY_UPDATE") -- Sturm

		assert.same({}, currentChar().currencies)
		mock.AdvanceTime(1)

		local currencies = currentChar().currencies
		-- seit 1.17.0 kommen cat/catOrder (Kategorie + Spiel-Reihenfolge) dazu
		assert.same({ name = "Valorsteine", qty = 750, max = 2000,
			cat = "Saison der Entdeckungen", catOrder = 1 }, currencies[3008])
		assert.same({ name = "Flugsteine", qty = 12345, max = 0,
			cat = "Saison der Entdeckungen", catOrder = 1 }, currencies[2245])
		assert.same({ name = "Kriegsressourcen", qty = 400, max = 0,
			cat = "Legacy", catOrder = 2 }, currencies[1166])

		local count = 0
		for _ in pairs(currencies) do count = count + 1 end
		assert.equal(3, count) -- Header nicht gespeichert
	end)

	it("PLAYER_ENTERING_WORLD stoesst initialen Scan an", function()
		mock.FireEvent("PLAYER_ENTERING_WORLD")
		mock.AdvanceTime(1)
		assert.equal(750, currentChar().currencies[3008].qty)
	end)

	it("Folge-Update ueberschreibt mit aktuellem Stand", function()
		mock.FireEvent("CURRENCY_DISPLAY_UPDATE")
		mock.AdvanceTime(1)

		mock.SetCurrencies({
			{ id = 3008, name = "Valorsteine", qty = 900, max = 2000 },
		})
		mock.FireEvent("CURRENCY_DISPLAY_UPDATE")
		mock.AdvanceTime(1)

		local currencies = currentChar().currencies
		assert.equal(900, currencies[3008].qty)
		assert.is_nil(currencies[2245]) -- nicht mehr in der Liste
	end)
end)
