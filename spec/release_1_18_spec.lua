-- spec/release_1_18_spec.lua
-- Uebersicht "Waehrungen" im Altoholic-Stil (1.18.0): pro Char nur die
-- Waehrungen der aktuellen Erweiterung (oberste Spiel-Kategorie), Cap-
-- Waehrungen zuerst; account-weite Waehrungen (z. B. Haendlerdevisen)
-- erscheinen einmalig in der Modul-Kopfzeile statt je Char.
local mock = require("spec.wow_mock")

describe("Release 1.18.0: Uebersicht-Waehrungen relevant + Account-Kopfzeile", function()
	local Exo, Tab

	local function seedChar(charKey, currencies)
		local char = Exo.Store:GetOrCreateCharacter(charKey)
		local _, realm, name = Exo.Schema.ParseCharKey(charKey)
		char.meta.name = name
		char.meta.realm = realm
		char.meta.classID = 1
		char.meta.level = 90
		char.meta.lastSeen = 1700000000
		char.equipment = { avgItemLevelEquipped = 400, slots = {} }
		Exo.Store:WriteCharacterData(charKey, "currencies", currencies)
	end

	local function currencyModule()
		local headerLabel, texts = nil, {}
		local current
		for _, row in ipairs(Tab.BuildRows()) do
			if row.header then
				current = row.module
				if current == "currencies" then headerLabel = row.label end
			elseif current == "currencies" then
				texts[#texts + 1] = row.text
			end
		end
		return headerLabel, texts
	end

	before_each(function()
		mock.Reset()
		Exo = mock.LoadExoCore()
		mock.SimulateLogin()
		mock.LoadExoUI()
		Tab = Exo.UI.OverviewTab

		seedChar("Default.Testrealm.Anna", {
			[3100] = { name = "Valorsteine", qty = 750, max = 2000,
				cat = "Midnight", catOrder = 1 },
			[3101] = { name = "Aschenfunken", qty = 10, max = 0,
				cat = "Midnight", catOrder = 1 },
			[3008] = { name = "Runenwappen", qty = 320, max = 480,
				cat = "The War Within", catOrder = 2 },
			[2032] = { name = "Haendlerdevisen", qty = 11480, max = 0, acc = true,
				cat = "Spielweisen", catOrder = 4 },
			[1220] = { name = "Ordensressourcen", qty = 9100, max = 0,
				cat = "Legion", catOrder = 3 },
		})
	end)

	it("zeigt je Char nur Waehrungen der aktuellen Erweiterung", function()
		local _, texts = currencyModule()
		assert.equal(1, #texts)
		assert.matches("Valorsteine", texts[1])
		assert.matches("Aschenfunken", texts[1])
		-- alte Erweiterungen fliegen raus
		assert.is_nil(texts[1]:find("Runenwappen"))
		assert.is_nil(texts[1]:find("Ordensressourcen"))
	end)

	it("Cap-Waehrungen stehen vor Waehrungen ohne Cap", function()
		local _, texts = currencyModule()
		assert.is_true(texts[1]:find("Valorsteine") < texts[1]:find("Aschenfunken"))
	end)

	it("account-weite Waehrungen stehen einmalig in der Kopfzeile", function()
		local headerLabel, texts = currencyModule()
		assert.matches("Haendlerdevisen", headerLabel)
		assert.matches("11.480", headerLabel, 1, true)
		-- ... und nicht mehr in den Char-Zeilen
		assert.is_nil(texts[1]:find("Haendlerdevisen"))
	end)

	it("Kopfzeile nimmt den hoechsten Wert ueber alle Chars", function()
		seedChar("Default.Testrealm.Berta", {
			[2032] = { name = "Haendlerdevisen", qty = 11900, max = 0, acc = true,
				cat = "Spielweisen", catOrder = 4 },
		})
		local headerLabel = currencyModule()
		assert.matches("11.900", headerLabel, 1, true)
	end)

	it("Fallback ohne Kategorie-Daten: alles anzeigen wie bisher", function()
		mock.Reset()
		Exo = mock.LoadExoCore()
		mock.SimulateLogin()
		mock.LoadExoUI()
		Tab = Exo.UI.OverviewTab
		seedChar("Default.Testrealm.Alt", {
			[3008] = { name = "Runenwappen", qty = 320, max = 480 },
			[2245] = { name = "Flugsteine", qty = 12530 },
		})
		local headerLabel, texts = currencyModule()
		assert.matches("Runenwappen", texts[1])
		assert.matches("Flugsteine", texts[1])
		assert.is_nil(headerLabel:find("Account")) -- kein acc-Flag -> kein Suffix
	end)
end)
