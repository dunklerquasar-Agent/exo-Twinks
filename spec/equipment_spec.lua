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

	it("aufwertbare Items: echtes Instanz-Level statt Basis-Level aus dem Link", function()
		-- z. B. Siegel-Ring: Link meldet Basis 597, Instanz ist auf 684 aufgewertet
		mock.SetEquipment({
			[11] = { id = 211234, ilvl = 684, baseIlvl = 597 },
		}, 660, 660)
		mock.FireEvent("PLAYER_EQUIPMENT_CHANGED", 11, false)
		mock.AdvanceTime(0.5)

		assert.equal(684, currentChar().equipment.slots[11].ilvl)
	end)

	it("Fallback auf Link-Level, wenn Instanz-API fehlt (alte Clients)", function()
		_G.C_Item.GetCurrentItemLevel = nil
		mock.SetEquipment({
			[11] = { id = 211234, ilvl = 684, baseIlvl = 597 },
		}, 660, 660)
		mock.FireEvent("PLAYER_EQUIPMENT_CHANGED", 11, false)
		mock.AdvanceTime(0.5)

		assert.equal(597, currentChar().equipment.slots[11].ilvl)
	end)

	it("ITEM_CHANGED (Aufwertung an Ort und Stelle) stoesst Rescan an", function()
		mock.SetEquipment({
			[11] = { id = 211234, ilvl = 671, baseIlvl = 597 },
		}, 655, 655)
		mock.FireEvent("PLAYER_ENTERING_WORLD")
		mock.AdvanceTime(0.5)
		assert.equal(671, currentChar().equipment.slots[11].ilvl)

		-- Item wird angelegt beim Haendler aufgewertet -> nur ITEM_CHANGED feuert
		mock.SetEquipment({
			[11] = { id = 211234, ilvl = 684, baseIlvl = 597 },
		}, 660, 660)
		mock.FireEvent("ITEM_CHANGED", "item:211234", "item:211234")
		mock.AdvanceTime(0.5)

		assert.equal(684, currentChar().equipment.slots[11].ilvl)
		assert.equal(660, currentChar().equipment.avgItemLevel)
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
