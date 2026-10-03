-- spec/release_1_13_spec.lua
-- "In KM-Bank einlagern"-Button (1.13.0): alles Kriegsmeutengebundene
-- aus den Taschen in die Kriegsmeuten-Bank.
local mock = require("spec.wow_mock")

describe("Release 1.13.0: KM-Einlagern-Button", function()
	local Exo

	local function seedBags()
		-- Tasche 0: Slot 1 = wb-Flag (bis zum Anlegen), Slot 2 = normales Item,
		-- Slot 3 = dauerhaft kriegsmeutengebunden (Bind-Typ 8)
		mock.SetContainer(0, 16, {
			[1] = { id = 777, count = 5 },
			[2] = { id = 555, count = 1 },
			[3] = { id = 901, count = 2 },
		})
		mock.SetWarboundSlots({ [0] = { [1] = true } })
		mock.SetItemDetails({ [901] = { bindType = 8 } })
	end

	before_each(function()
		mock.Reset()
		Exo = mock.LoadExoCore()
		mock.SimulateLogin()
		seedBags()
	end)

	it("Bank zu: liefert nil + bank_closed, nichts wird bewegt", function()
		local moved, err = Exo.API.DepositWarboundToBank()
		assert.is_nil(moved)
		assert.equal("bank_closed", err)
		assert.equal(0, #mock.GetUsedContainerItems())
	end)

	it("Bank offen: lagert NUR Kriegsmeutengebundenes ein (wb-Flag + Typ 7/8)", function()
		mock.FireEvent("BANKFRAME_OPENED")
		local moved = Exo.API.DepositWarboundToBank()
		assert.equal(2, moved)

		local used = mock.GetUsedContainerItems()
		assert.equal(2, #used)
		assert.equal(1, used[1].slot) -- wb-Flag-Item
		assert.equal(3, used[2].slot) -- dauerhaft kriegsmeutengebunden
		-- Ziel: Kriegsmeuten-Bank (Enum.BankType.Account)
		assert.equal(_G.Enum.BankType.Account, used[1].bankType)
		-- normales Item (Slot 2) bleibt in der Tasche
		for _, call in ipairs(used) do assert.not_equal(2, call.slot) end
	end)

	it("nach BANKFRAME_CLOSED ist Einlagern wieder gesperrt", function()
		mock.FireEvent("BANKFRAME_OPENED")
		mock.FireEvent("BANKFRAME_CLOSED")
		local moved, err = Exo.API.DepositWarboundToBank()
		assert.is_nil(moved)
		assert.equal("bank_closed", err)
	end)

	describe("UI-Button", function()
		before_each(function() mock.LoadExoUI() end)

		it("beide KM-Tabs haben den Einlagern-Button", function()
			local content1 = CreateFrame("Frame")
			Exo.UI.WarbandBankTab:Render(content1)
			assert.is_not_nil(Exo.UI.WarbandBankTab._GetDepositButton())

			local content2 = CreateFrame("Frame")
			Exo.UI.WarboundTab:Render(content2)
			assert.is_not_nil(Exo.UI.WarboundTab._GetDepositButton())
		end)

		it("Klick bei geschlossener Bank zeigt Hinweis im Footer", function()
			local content = CreateFrame("Frame")
			Exo.UI.WarboundTab:Render(content)
			local btn = Exo.UI.WarboundTab._GetDepositButton()
			btn._scripts.OnClick(btn)
			assert.truthy(Exo.UI.WarboundTab._GetFooter():GetText()
				:find("geoeffneter Bank", 1, true))
		end)

		it("Klick bei offener Bank meldet eingelagerte Stapel", function()
			mock.FireEvent("BANKFRAME_OPENED")
			local content = CreateFrame("Frame")
			Exo.UI.WarbandBankTab:Render(content)
			local btn = Exo.UI.WarbandBankTab._GetDepositButton()
			btn._scripts.OnClick(btn)
			assert.truthy(Exo.UI.WarbandBankTab._GetFooter():GetText()
				:find("2 Stapel", 1, true))
		end)
	end)
end)
