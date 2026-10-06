-- spec/ui_designer_spec.lua
-- Designer-Tab (0.11.0): Options-API, Theme, Zeilen-Toggles, Inventar-Standards.
local mock = require("spec.wow_mock")

describe("Designer (0.11.0)", function()
	local Exo, Tab

	before_each(function()
		mock.Reset()
		Exo = mock.LoadExoCore()
		mock.SimulateLogin()
		mock.LoadExoUI()
		Tab = Exo.UI.DesignerTab
		Exo.UI.Theme.Load()
	end)

	describe("Options-API (Core)", function()
		it("liefert den Default, solange nichts gesetzt ist", function()
			assert.equal("fallback", Exo.API.GetOption("gibt.es.nicht", "fallback"))
			assert.is_true(Exo.API.GetOption("window.remember", true))
		end)

		it("speichert und liest Werte (accountweit)", function()
			assert.is_true(Exo.API.SetOption("theme.accent", "ffd700"))
			assert.equal("ffd700", Exo.API.GetOption("theme.accent", "1784d1"))
			-- false ist ein gueltiger gespeicherter Wert (nicht mit Default verwechseln)
			Exo.API.SetOption("charRow.gold", false)
			assert.is_false(Exo.API.GetOption("charRow.gold", true))
			-- nil loescht -> Default greift wieder
			Exo.API.SetOption("charRow.gold", nil)
			assert.is_true(Exo.API.GetOption("charRow.gold", true))
		end)
	end)

	describe("Theme", function()
		it("laedt Standardwerte ohne gespeicherte Optionen", function()
			local C = Exo.UI.Widgets.COLORS
			assert.equal("1784d1", C.accentHex)
			assert.near(0.92, C.bg[4], 0.001)
		end)

		it("uebernimmt Akzentfarbe und Hintergrund aus den Optionen", function()
			Exo.API.SetOption("theme.accent", "ffd700")
			Exo.API.SetOption("theme.bgAlpha", 0.70)
			Exo.API.SetOption("theme.bgShade", 0.12)
			Exo.UI.Theme.Load()
			local C = Exo.UI.Widgets.COLORS
			assert.equal("ffd700", C.accentHex)
			assert.near(1.0, C.accent[1], 0.01)   -- ff
			assert.near(0.84, C.accent[2], 0.01)  -- d7
			assert.near(0.70, C.bg[4], 0.001)
			assert.near(0.12, C.bg[1], 0.001)
		end)

		it("Reset stellt den Standard-Look wieder her", function()
			Exo.UI.Theme.Set("theme.accent", "a335ee")
			assert.equal("a335ee", Exo.UI.Widgets.COLORS.accentHex)
			Exo.UI.Theme.Reset()
			assert.equal("1784d1", Exo.UI.Widgets.COLORS.accentHex)
		end)
	end)

	describe("Charaktere-Zeilen ein-/ausblenden", function()
		local function rowKinds()
			local matrix = Exo.UI.CharactersTab.BuildMatrix()
			local kinds = {}
			for _, row in ipairs(matrix.rows) do kinds[row.kind] = true end
			return kinds
		end

		it("Standard: alle Zeilen an", function()
			local kinds = rowKinds()
			assert.is_true(kinds.gold)
			assert.is_true(kinds.ilvl)
			assert.is_true(kinds.vaultstatus)
		end)

		it("ToggleCharRow blendet Gruppen aus und wieder ein", function()
			Tab.ToggleCharRow("gold")
			assert.is_false(Tab.IsCharRowEnabled("gold"))
			assert.is_nil(rowKinds().gold)

			Tab.ToggleCharRow("mplus")
			local kinds = rowKinds()
			assert.is_nil(kinds.rating)
			assert.is_nil(kinds.keystone)

			Tab.ToggleCharRow("vault")
			kinds = rowKinds()
			assert.is_nil(kinds.vaultstatus)
			assert.is_nil(kinds.vault)

			Tab.ToggleCharRow("gold") -- wieder an
			assert.is_true(rowKinds().gold)
		end)
	end)

	describe("Inventar-Standards", function()
		it("SetInventoryView/Group wirken sofort und persistent", function()
			Tab.SetInventoryView("icons")
			Tab.SetInventoryGroup("quality")
			local Inventory = Exo.UI.InventoryTab
			assert.equal("icons", Inventory.viewMode)
			assert.equal("quality", Inventory.GROUP_MODES[Inventory.groupModeIndex].id)

			-- ApplyDefaultOptions stellt die Standards nach einem Reset des States her
			Inventory.viewMode, Inventory.groupModeIndex = "list", 1
			Inventory.ApplyDefaultOptions()
			assert.equal("icons", Inventory.viewMode)
			assert.equal("quality", Inventory.GROUP_MODES[Inventory.groupModeIndex].id)
		end)
	end)

	describe("Freie Akzentfarbe (Hex)", function()
		it("akzeptiert RRGGBB, #RRGGBB und Grossschreibung", function()
			assert.is_true(Tab.SetAccentHex("2ecc71"))
			assert.equal("2ecc71", Exo.UI.Widgets.COLORS.accentHex)
			assert.is_true(Tab.SetAccentHex("#FF8800"))
			assert.equal("ff8800", Exo.UI.Widgets.COLORS.accentHex)
		end)

		it("lehnt ungueltige Eingaben ab und aendert nichts", function()
			local before = Exo.UI.Widgets.COLORS.accentHex
			assert.is_false(Tab.SetAccentHex("rot"))
			assert.is_false(Tab.SetAccentHex("12345"))
			assert.is_false(Tab.SetAccentHex(""))
			assert.equal(before, Exo.UI.Widgets.COLORS.accentHex)
		end)
	end)

	describe("Reiter ein-/ausblenden", function()
		it("ToggleTab speichert die Sichtbarkeit", function()
			assert.is_true(Tab.IsTabShown("characters"))
			Tab.ToggleTab("characters")
			assert.is_false(Tab.IsTabShown("characters"))
			assert.is_true(Exo.API.GetOption("tab.hidden.characters", false))
			Tab.ToggleTab("characters")
			assert.is_true(Tab.IsTabShown("characters"))
		end)
	end)

	describe("Render + ResetAll", function()
		it("baut Buttons und markiert den gespeicherten Zustand", function()
			local content = CreateFrame("Frame")
			Tab:Render(content)
			local buttons = Tab._GetButtons()
			assert.is_table(buttons.accent)
			assert.is_true(buttons.accent["1784d1"]._selected)     -- Standard-Akzent
			assert.is_true(buttons.charRows.gold._selected)        -- Zeile an
			assert.is_true(buttons.remember.remember._selected)    -- Groesse merken an

			Tab.ToggleCharRow("gold")
			Tab.SetAccent("ffd700")
			Tab:RefreshStates()
			assert.is_false(buttons.charRows.gold._selected)
			assert.is_true(buttons.accent.ffd700._selected)
			assert.is_false(buttons.accent["1784d1"]._selected)
		end)

		it("ResetAll setzt Theme, Zeilen, Tabs und Uebersicht zurueck", function()
			Tab.SetAccent("ff4538")
			Tab.ToggleCharRow("weeklies")
			Tab.SetInventoryView("icons")
			Tab.ToggleTab("characters")
			Exo.UI.OverviewTab.MoveModuleForward("inventory")
			Tab.ResetAll()
			assert.equal("1784d1", Exo.UI.Widgets.COLORS.accentHex)
			assert.is_true(Tab.IsCharRowEnabled("weeklies"))
			assert.is_nil(Exo.API.GetOption("inventory.defaultView"))
			assert.is_true(Tab.IsTabShown("characters"))
			assert.same({ "chars", "currencies", "locks", "inventory", "realms",
				"keys", "bags", "scan", "tax", "auctions" },
				Exo.UI.OverviewTab.GetOrder())
		end)

		it("Inhalt liegt im Scrollbereich; Mausrad scrollt begrenzt (1.17.1)", function()
			local content = CreateFrame("Frame")
			Tab:Render(content)
			assert.is_table(Tab._scroll)
			assert.is_true((Tab._designerHeight or 0) > 0)

			-- Klemm-Logik deterministisch pruefen: Inhalt 1000px,
			-- Sichthoehe im Mock = Fallback 400 -> Range 600
			Tab._designerHeight = 1000
			local wheel = Tab._scroll:GetScript("OnMouseWheel")
			assert.is_function(wheel)
			wheel(Tab._scroll, -1) -- runter
			assert.is_true(Tab._scrollPos > 0)
			for _ = 1, 200 do wheel(Tab._scroll, -1) end
			assert.equal(600, Tab._scrollPos)   -- unten begrenzt
			for _ = 1, 500 do wheel(Tab._scroll, 1) end
			assert.equal(0, Tab._scrollPos)     -- oben begrenzt
		end)

		it("Modul-Buttons existieren fuer alle Uebersicht-Module", function()
			local content = CreateFrame("Frame")
			Tab:Render(content)
			local buttons = Tab._GetButtons()
			local count = 0
			for _ in pairs(buttons.ovShow or {}) do count = count + 1 end
			assert.equal(#Exo.UI.OverviewTab.MODULES, count)
			assert.is_nil(buttons.ovOrder) -- Reihenfolge jetzt per Shift-Klick
		end)
	end)
end)
