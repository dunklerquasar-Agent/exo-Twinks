-- spec/release_1_10_spec.lua
-- Community-Wuensche I (1.10.0): Fensterposition merken, Skalierung,
-- Hervorhebung des eingeloggten Chars, Vault-Status im Minimap-Tooltip.
local mock = require("spec.wow_mock")

describe("Release 1.10.0: Community-Wuensche I", function()
	local Exo

	before_each(function()
		mock.Reset()
		Exo = mock.LoadExoCore()
		mock.SimulateLogin()
		mock.LoadExoUI()
	end)

	describe("Fensterposition merken (Q1)", function()
		it("OnDragStop speichert die Position als Option", function()
			Exo.UI:Show()
			local window = Exo.UI:GetWindow()
			window:SetPoint("TOPLEFT", _G.UIParent, "TOPLEFT", 120, -80)
			window._scripts.OnDragStop(window)

			local pos = Exo.API.GetOption("window.pos")
			assert.equal("TOPLEFT", pos.point)
			assert.equal(120, pos.x)
			assert.equal(-80, pos.y)
		end)

		it("gespeicherte Position wird beim Fensteraufbau angewendet", function()
			Exo.API.SetOption("window.pos",
				{ point = "TOPLEFT", relPoint = "TOPLEFT", x = 60, y = -40 })
			Exo.UI:Show()
			local p = Exo.UI:GetWindow()._point
			assert.equal("TOPLEFT", p.point)
			assert.equal(60, p.x)
			assert.equal(-40, p.y)
		end)

		it("ResetWindowPosition loescht die Option und zentriert", function()
			Exo.API.SetOption("window.pos",
				{ point = "TOPLEFT", relPoint = "TOPLEFT", x = 60, y = -40 })
			Exo.UI:Show()
			Exo.UI.DesignerTab.ResetWindowPosition()

			assert.is_nil(Exo.API.GetOption("window.pos"))
			assert.equal("CENTER", Exo.UI:GetWindow()._point.point)
		end)

		it("ohne gespeicherte Position bleibt es zentriert", function()
			Exo.UI:Show()
			assert.equal("CENTER", Exo.UI:GetWindow()._point.point)
		end)
	end)

	describe("Fenster-Skalierung (Q2)", function()
		it("ClampScale klemmt auf 0.7-1.3 und faellt auf 1 zurueck", function()
			assert.equal(1, Exo.UI.ClampScale(nil))
			assert.equal(1, Exo.UI.ClampScale("quark"))
			assert.equal(0.7, Exo.UI.ClampScale(0.3))
			assert.equal(1.3, Exo.UI.ClampScale(9))
			assert.equal(1.1, Exo.UI.ClampScale(1.1))
		end)

		it("CycleWindowScale schaltet weiter und wendet live an", function()
			Exo.UI:Show()
			assert.equal(1.1, Exo.UI.DesignerTab.CycleWindowScale()) -- 1.0 -> 1.1
			assert.equal(1.1, Exo.API.GetOption("window.scale"))
			assert.equal(1.1, Exo.UI:GetWindow():GetScale())
		end)

		it("CycleWindowScale springt nach 130 % auf 70 % zurueck", function()
			Exo.API.SetOption("window.scale", 1.3)
			assert.equal(0.7, Exo.UI.DesignerTab.CycleWindowScale())
		end)

		it("gespeicherte Skalierung wird beim Fensteraufbau angewendet", function()
			Exo.API.SetOption("window.scale", 1.2)
			Exo.UI:Show()
			assert.equal(1.2, Exo.UI:GetWindow():GetScale())
		end)

		it("GetScaleLabel formatiert Prozentwert", function()
			Exo.API.SetOption("window.scale", 0.9)
			assert.equal("Skalierung: 90 %", Exo.UI.DesignerTab.GetScaleLabel())
		end)
	end)

	describe("Eingeloggten Char hervorheben (Q3)", function()
		local Tab
		before_each(function() Tab = Exo.UI.CharactersTab end)

		it("ColumnHighlight: current schlaegt Zebra", function()
			local current = { summary = { isCurrent = true } }
			local other = { summary = { isCurrent = false } }
			assert.equal("current", Tab.ColumnHighlight(current, 1))
			assert.equal("current", Tab.ColumnHighlight(current, 2))
			assert.equal("zebra", Tab.ColumnHighlight(other, 2))
			assert.is_nil(Tab.ColumnHighlight(other, 3))
			assert.is_nil(Tab.ColumnHighlight(nil, 2))
		end)

		it("HeaderText markiert den eingeloggten Char mit Akzent-Pfeil", function()
			local current = { name = "Exo", classID = 8, summary = { isCurrent = true } }
			local other = { name = "Bankchar", classID = 1, summary = { isCurrent = false } }
			assert.truthy(Tab.HeaderText(current):find("1784d1", 1, true))
			assert.truthy(Tab.HeaderText(current):find("Exo", 1, true))
			assert.is_nil(Tab.HeaderText(other):find("1784d1", 1, true))
			assert.equal("", Tab.HeaderText(nil))
		end)
	end)

	describe("Vault-Status im Minimap-Tooltip (Q5)", function()
		it("MinimapVaultShort zaehlt freigeschaltete Slots je Kategorie", function()
			local mplus = { vault = {
				{ type = 1, progress = 4, threshold = 4 }, -- M+ frei
				{ type = 1, progress = 2, threshold = 8 }, -- M+ nicht frei
				{ type = 3, progress = 2, threshold = 2 }, -- Raid frei
				{ type = 6, progress = 0, threshold = 3 }, -- Welt nicht frei
			} }
			assert.equal("V 1/1/0", Exo.MinimapVaultShort(mplus))
			assert.is_nil(Exo.MinimapVaultShort({ vault = {} }))
			assert.is_nil(Exo.MinimapVaultShort(nil))
		end)

		it("Tooltip-Zeile enthaelt Vault-Teil + Legende", function()
			local key = Exo.Store:GetCurrentKey()
			Exo.Store:WriteCharacterData(key, "mythicplus", {
				rating = 1500,
				vault = { { type = 1, index = 1, progress = 4, threshold = 4 } },
			})
			local lines = Exo.BuildMinimapTooltipLines()
			local hasVault, hasLegend = false, false
			for _, line in ipairs(lines) do
				if line:find("V 0/1/0", 1, true) then hasVault = true end
				if line:find("Schatzkammer Raid/M+/Welt", 1, true) then hasLegend = true end
			end
			assert.is_true(hasVault)
			assert.is_true(hasLegend)
		end)

		it("ohne Vault-Daten keine Legende", function()
			local lines = Exo.BuildMinimapTooltipLines()
			for _, line in ipairs(lines) do
				assert.is_nil(line:find("Schatzkammer Raid", 1, true))
			end
		end)
	end)
end)
