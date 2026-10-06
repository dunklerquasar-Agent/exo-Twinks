-- spec/release_1_16_spec.lua
-- Waehrungen komplett (1.16.0): Der Scan erfasst SAEMTLICHE Waehrungen des
-- Charakters -- auch unter zugeklappten Kategorien und unter "Nicht
-- verwendet"; der Klapp-Zustand des Spielers bleibt unveraendert.
-- Zusaetzlich wird das Account-weit-Flag (acc) gespeichert.
local mock = require("spec.wow_mock")

describe("Release 1.16.0: Waehrungen komplett", function()
	local Exo

	local function currentChar()
		return Exo.Store:GetCharacter(Exo.Store:GetCurrentKey())
	end

	before_each(function()
		mock.Reset()
		Exo = mock.LoadExoCore()
		mock.SimulateLogin()

		mock.SetCurrencies({
			{ header = "Midnight" },
			{ id = 3008, name = "Valorsteine", qty = 750, max = 2000 },
			{ id = 2032, name = "Handelsvorrat", qty = 580, max = 1000, acc = true },
			{ header = "Legion", collapsed = true },
			{ id = 1155, name = "Uralter Mana", qty = 300, max = 2000 },
			{ id = 1220, name = "Ordensressourcen", qty = 9100, max = 0 },
			{ header = "Nicht verwendet", collapsed = true },
			{ id = 395, name = "Gerechtigkeitspunkte", qty = 4000, max = 0 },
		})
	end)

	it("erfasst auch Waehrungen unter zugeklappten Kategorien", function()
		Exo.Collectors.Currencies.Scan()
		local c = currentChar().currencies

		assert.equal(750, c[3008].qty)              -- sichtbar
		assert.equal(300, c[1155].qty)              -- unter zugeklapptem "Legion"
		assert.equal(9100, c[1220].qty)             -- dito
		assert.equal(4000, c[395].qty)              -- unter "Nicht verwendet"

		local count = 0
		for _ in pairs(c) do count = count + 1 end
		assert.equal(5, count) -- alle 5 Waehrungen, keine Header
	end)

	it("stellt den Klapp-Zustand danach exakt wieder her", function()
		Exo.Collectors.Currencies.Scan()
		-- "Legion" und "Nicht verwendet" muessen wieder zugeklappt sein:
		-- sichtbar sind dann nur 3 Header + 2 Midnight-Waehrungen
		assert.equal(5, C_CurrencyInfo.GetCurrencyListSize())
		local legion
		for i = 1, C_CurrencyInfo.GetCurrencyListSize() do
			local info = C_CurrencyInfo.GetCurrencyListInfo(i)
			if info.isHeader and info.name == "Legion" then legion = info end
		end
		assert.is_false(legion.isHeaderExpanded)
	end)

	it("speichert das Account-weit-Flag und reicht es ueber die API durch", function()
		Exo.Collectors.Currencies.Scan()
		local key = Exo.Store:GetCurrentKey()
		local currencies = Exo.API.GetCurrencies(key)
		assert.is_true(currencies[2032].acc)        -- Handelsvorrat account-weit
		assert.is_nil(currencies[3008].acc)         -- Valorsteine charakterbezogen
	end)

	it("Komplett-Scan laeuft auch ueber den Event-Weg (entprellt)", function()
		mock.FireEvent("CURRENCY_DISPLAY_UPDATE")
		mock.AdvanceTime(1)
		assert.equal(300, currentChar().currencies[1155].qty)
	end)
end)
