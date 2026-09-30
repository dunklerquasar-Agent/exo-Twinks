-- spec/ui_bank_spec.lua
-- Reiter "Bank" (1.9.0): Charakterbank jedes einzelnen Chars separat,
-- mit Aufklapp-Auswahl, Hover-Tooltip und freien Bankplaetzen.
local mock = require("spec.wow_mock")

describe("ExoTwinksUI / Bank-Tab (1.9.0)", function()
	local Exo, Tab

	local function seed()
		local Store = Exo.Store

		local anna = Store:GetOrCreateCharacter("Default.Testrealm.Anna")
		anna.meta.name = "Anna"
		anna.meta.realm = "Testrealm"
		anna.meta.classID = 8
		Store:WriteCharacterData("Default.Testrealm.Anna", "bags", {
			[0] = { size = 16, free = 15, items = { [1] = { id = 777, count = 9 } } },
		})
		Store:WriteCharacterData("Default.Testrealm.Anna", "bank", {
			[6] = { size = 98, free = 96, items = {
				[1] = { id = 901, count = 3 },
				[2] = { id = 777, count = 5 },
			} },
			[7] = { size = 98, free = 97, items = { [1] = { id = 901, count = 2 } } },
		})

		-- Borg war noch nie an der Bank
		local borg = Store:GetOrCreateCharacter("Default.Testrealm.Borg")
		borg.meta.name = "Borg"
		borg.meta.realm = "Testrealm"

		mock.SetItemNames({ [901] = "Kriegsgebundenes Schwert", [777] = "Friedensblume" })
		mock.SetItemDetails({
			[901] = { bindType = 8, quality = 4, icon = 1111 },
			[777] = { bindType = 2, quality = 1, icon = 4444 },
		})
	end

	before_each(function()
		mock.Reset()
		Exo = mock.LoadExoCore()
		mock.SimulateLogin()
		mock.LoadExoUI()
		Tab = Exo.UI.BankTab
		Tab.targetIndex = 1
		Tab.sortBy, Tab.sortDesc = "total", true
		Exo.Store:DeleteCharacter(Exo.Store:GetCurrentKey())
		seed()
	end)

	describe("API.GetCharacterBankItems", function()
		it("liefert NUR Bank-Items (Taschen bleiben draussen)", function()
			local items = Exo.API.GetCharacterBankItems("Default.Testrealm.Anna")
			local byId = {}
			for _, item in ipairs(items) do byId[item.itemID] = item end
			assert.equal(2, #items)
			assert.equal(5, byId[777].total)  -- nicht 14: die 9 aus den Taschen fehlen
			assert.equal(5, byId[901].total)  -- 3 + 2 ueber zwei Bankfaecher
			assert.equal(5, byId[901].bank)
			assert.equal(0, byId[901].bags)
		end)

		it("leere Liste fuer Chars ohne Bankdaten", function()
			assert.same({}, Exo.API.GetCharacterBankItems("Default.Testrealm.Borg"))
			assert.same({}, Exo.API.GetCharacterBankItems("Default.Testrealm.Nix"))
		end)
	end)

	describe("Registrierung", function()
		it("Bank ist 4. Reiter (zwischen Inventar und KM-Bank)", function()
			assert.equal(Tab, Exo.UI.tabsById["bank"])
			assert.equal("inventory", Exo.UI.tabs[3].id)
			assert.equal("bank", Exo.UI.tabs[4].id)
			assert.equal("warbandbank", Exo.UI.tabs[5].id)
		end)

		it("GetTargets: nur Charaktere, Realm/Name-sortiert", function()
			local targets = Tab.GetTargets()
			assert.equal(2, #targets)
			assert.equal("Anna", targets[1].name)
			assert.equal("Borg", targets[2].name)
			for _, target in ipairs(targets) do
				assert.is_nil(target.key:find("__")) -- keine Pseudo-Ziele
			end
		end)
	end)

	describe("Render", function()
		it("zeigt die Bank des gewaehlten Chars mit Fusszeile", function()
			local content = CreateFrame("Frame")
			Tab:Render(content)
			local items = Tab._GetScroller().items
			assert.equal(2, #items)
			assert.equal("2 Items, 10 Stueck gesamt"
				.. "  |cff808080Bank frei: 193/196 Plaetze|r",
				Tab._GetFooter():GetText())
			assert.truthy(Tab._GetTargetButton():GetText():find("Anna"))
		end)

		it("Charwechsel per SelectTarget zeigt Scan-Hinweis fuer Borg", function()
			local content = CreateFrame("Frame")
			Tab:Render(content)
			Tab:SelectTarget(2) -- Borg
			assert.equal(0, #Tab._GetScroller().items)
			assert.truthy(Tab._GetFooter():GetText():find("Bank besuchen"))
		end)

		it("Hover ueber eine Bank-Zeile triggert den GameTooltip", function()
			local content = CreateFrame("Frame")
			Tab:Render(content)
			local shownID
			_G.GameTooltip.SetItemByID = function(_, id) shownID = id end
			local row = Tab._GetScroller().rows[1]
			row._scripts.OnEnter(row)
			assert.is_not_nil(shownID)
		end)

		it("Header-Klick auf 'Item' sortiert nach Namen", function()
			local content = CreateFrame("Frame")
			Tab:Render(content)
			Tab:OnHeaderClick("name")
			local items = Tab._GetScroller().items
			assert.equal(777, items[1].itemID) -- Friedensblume vor Kriegsgeb...
			assert.equal(901, items[2].itemID)
		end)

		it("Aufklapp-Liste oeffnet und waehlt direkt", function()
			local content = CreateFrame("Frame")
			Tab:Render(content)
			Tab:OnTargetClick()
			assert.is_true(Tab._GetTargetDropdown():IsShown())
			local row = Tab._dropdownScroller.rows[2]
			row._scripts.OnMouseDown(row)
			assert.is_false(Tab._GetTargetDropdown():IsShown())
			assert.equal(2, Tab.targetIndex)
			assert.truthy(Tab._GetTargetButton():GetText():find("Borg"))
		end)
	end)
end)
