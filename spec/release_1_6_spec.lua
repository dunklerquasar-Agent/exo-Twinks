-- spec/release_1_6_spec.lua
-- Equipment-Intelligenz (1.6.0): bester Slot accountweit + Upgrade-Hinweise.
local mock = require("spec.wow_mock")

describe("Release 1.6.0 (Equipment-Intelligenz)", function()
	local Exo, Detail

	local function seedChar(charKey, ilvl, slots)
		local char = Exo.Store:GetOrCreateCharacter(charKey)
		local _, realm, name = Exo.Schema.ParseCharKey(charKey)
		char.meta.name = name
		char.meta.realm = realm
		char.meta.classID = 1
		char.equipment = { avgItemLevelEquipped = ilvl, slots = slots or {} }
	end

	local function findRow(rows, label)
		for _, row in ipairs(rows) do
			if row.label == label then return row end
		end
	end

	before_each(function()
		mock.Reset()
		Exo = mock.LoadExoCore()
		mock.SimulateLogin()
		mock.LoadExoUI()
		Detail = Exo.UI.CharacterDetail
		seedChar("Default.Testrealm.Anna", 480, {
			[1] = { id = 1001, ilvl = 489 },  -- Kopf: Annas Bestwert
			[5] = { id = 1002, ilvl = 460 },  -- Brust: Bob ist besser
			[7] = { id = 1003, ilvl = 450 },  -- Beine: 30 unter Schnitt -> rot
		})
		seedChar("Default.Testrealm.Bob", 470, {
			[1] = { id = 2001, ilvl = 470 },
			[5] = { id = 2002, ilvl = 480 },
		})
	end)

	describe("GetBestSlots", function()
		it("findet den hoechsten Wert je Slot ueber alle Chars", function()
			local best = Detail.GetBestSlots()
			assert.equal(489, best[1].ilvl)
			assert.equal("Anna", best[1].name)
			assert.equal(480, best[5].ilvl)
			assert.equal("Bob", best[5].name)
			assert.is_nil(best[2]) -- niemand hat einen Hals
		end)
	end)

	describe("Detail-Panel ohne Vergleich", function()
		it("zeigt 'dein Bestwert' bzw. 'best: X @ Char' in Spalte b", function()
			local rows = Detail.BuildDetailRows("Default.Testrealm.Anna")
			assert.matches("dein Bestwert", findRow(rows, "Kopf").b)
			assert.matches("|cff1eff00", findRow(rows, "Kopf").b)
			assert.matches("best: 480 @ Bob", findRow(rows, "Brust").b)
			assert.matches("|cff808080", findRow(rows, "Brust").b)
			assert.is_nil(findRow(rows, "Hals").b) -- kein Wert im Account
		end)

		it("markiert Slots deutlich unter dem Schnitt rot", function()
			local rows = Detail.BuildDetailRows("Default.Testrealm.Anna")
			-- Beine 450 bei Schnitt 480 (Gap 30 >= 15) -> rot
			assert.matches("|cffff4538450|r", findRow(rows, "Beine").a)
			-- Brust 460 bei Schnitt 480 (Gap 20 >= 15) -> ebenfalls rot
			assert.matches("|cffff4538460|r", findRow(rows, "Brust").a)
			-- Kopf 489 ueber Schnitt -> unveraendert
			assert.equal("489", findRow(rows, "Kopf").a)
		end)
	end)

	describe("Detail-Panel mit Vergleich", function()
		it("Spalte b bleibt der Vergleichs-Char (kein 'best:'-Text)", function()
			local rows = Detail.BuildDetailRows(
				"Default.Testrealm.Anna", "Default.Testrealm.Bob")
			local kopf = findRow(rows, "Kopf")
			assert.matches("489", kopf.a)
			assert.matches("470", kopf.b)
			assert.is_nil(kopf.b:find("best:", 1, true))
			assert.is_nil(kopf.b:find("Bestwert", 1, true))
		end)
	end)
end)
