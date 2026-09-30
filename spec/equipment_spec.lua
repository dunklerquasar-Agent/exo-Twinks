-- spec/equipment_spec.lua
local mock = require("spec.wow_mock")

describe("Equipment-Collector", function()
	local Exo

	local function currentChar()
		return Exo.Store:GetCharacter(Exo.Store:GetCurrentKey())
	end

	before_each(function()
		mock.Reset()
		Exo = mock.LoadExoCore()
		mock.SimulateLogin()

		mock.SetEquipment({
			[1] = { id = 212071, ilvl = 639 },   -- Kopf
			[5] = { id = 212074, ilvl = 645 },   -- Brust
			[16] = { id = 222566, ilvl = 658 },  -- Waffe
		}, 641.5, 638.2)
	end)

	it("scannt Slots + Durchschnitts-Itemlevel entprellt", function()
		mock.FireEvent("PLAYER_EQUIPMENT_CHANGED", 1, false)
		mock.FireEvent("PLAYER_EQUIPMENT_CHANGED", 5, false) -- Sturm beim Umziehen

		assert.same({}, currentChar().equipment)
		mock.AdvanceTime(0.5)

		local eq = currentChar().equipment
		assert.same({ id = 212071, ilvl = 639 }, eq.slots[1])
		assert.same({ id = 222566, ilvl = 658 }, eq.slots[16])
		assert.is_nil(eq.slots[2]) -- leerer Slot nicht gespeichert
		assert.equal(641.5, eq.avgItemLevel)
		assert.equal(638.2, eq.avgItemLevelEquipped)
	end)

	it("PLAYER_ENTERING_WORLD stoesst initialen Scan an", function()
		mock.FireEvent("PLAYER_ENTERING_WORLD")
		mock.AdvanceTime(0.5)
		assert.equal(639, currentChar().equipment.slots[1].ilvl)
	end)

	it("Itemwechsel ueberschreibt den Slot", function()
		mock.FireEvent("PLAYER_EQUIPMENT_CHANGED", 16, false)
		mock.AdvanceTime(0.5)

		mock.SetEquipment({
			[16] = { id = 999999, ilvl = 678 },
		}, 650, 650)
		mock.FireEvent("PLAYER_EQUIPMENT_CHANGED", 16, false)
		mock.AdvanceTime(0.5)

		local eq = currentChar().equipment
		assert.equal(999999, eq.slots[16].id)
		assert.is_nil(eq.slots[1]) -- ausgezogen
	end)
end)
