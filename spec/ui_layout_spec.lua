-- spec/ui_layout_spec.lua
-- 0.12.0: Sidebar-Navigation, Dichte-Modus, Semantic Colors, Account-Summary.
local mock = require("spec.wow_mock")

describe("Layout 0.12.0 (Sidebar + Designer 2.0)", function()
	local Exo

	local function seedChar(charKey, opts)
		opts = opts or {}
		local char = Exo.Store:GetOrCreateCharacter(charKey)
		local _, realm, name = Exo.Schema.ParseCharKey(charKey)
		char.meta.name = name
		char.meta.realm = realm
		char.meta.level = opts.level or 90
		char.gold = opts.gold or 0
		char.equipment = { avgItemLevelEquipped = opts.ilvl or 0, slots = {} }
		if opts.mplus then
			Exo.Store:WriteCharacterData(charKey, "mythicplus", opts.mplus)
		end
	end

	before_each(function()
		mock.Reset()
		Exo = mock.LoadExoCore()
		mock.SimulateLogin()
		mock.LoadExoUI()
	end)

	describe("Dichte-Modus (VirtualScroll)", function()
		local function build(visibleRows, rowHeight)
			return Exo.UI.VirtualScroll.New{
				parent = CreateFrame("Frame"),
				visibleRows = visibleRows, rowHeight = rowHeight,
				createRow = function(parent) return CreateFrame("Frame", nil, parent) end,
				updateRow = function() end,
			}
		end

		it("ApplyDensity(0.8) verkleinert die Zeilenhoehe aller Listen", function()
			local scroller = build(5, 20)
			Exo.UI.VirtualScroll.ApplyDensity(0.8)
			assert.equal(16, scroller.rowHeight)
			Exo.UI.VirtualScroll.ApplyDensity(1)
			assert.equal(20, scroller.rowHeight)
		end)

		it("neue Scroller uebernehmen den aktiven Faktor", function()
			Exo.UI.VirtualScroll.ApplyDensity(0.8)
			local scroller = build(5, 20)
			assert.equal(16, scroller.rowHeight)
		end)

		it("fixedRowHeight (Icon-Raster) bleibt unangetastet", function()
			local scroller = Exo.UI.VirtualScroll.New{
				parent = CreateFrame("Frame"),
				visibleRows = 5, rowHeight = 38, fixedRowHeight = true,
				createRow = function(parent) return CreateFrame("Frame", nil, parent) end,
				updateRow = function() end,
			}
			Exo.UI.VirtualScroll.ApplyDensity(0.8)
			assert.equal(38, scroller.rowHeight)
		end)

		it("kompakt = mehr sichtbare Zeilen bei gleicher Hoehe", function()
			local scroller = build(5, 20)
			scroller.frame.GetHeight = function() return 160 end
			scroller:SetData({ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12 })
			assert.equal(8, scroller.visibleRows) -- 160/20
			Exo.UI.VirtualScroll.ApplyDensity(0.8)
			assert.equal(10, scroller.visibleRows) -- 160/16
		end)

		it("Theme.Load liest die Dichte-Option", function()
			local scroller = build(5, 20)
			Exo.API.SetOption("theme.density", "compact")
			Exo.UI.Theme.Load()
			assert.equal(16, scroller.rowHeight)
			Exo.UI.Theme.Reset()
			assert.equal(20, scroller.rowHeight)
		end)
	end)

	describe("Semantic Colors", function()
		it("stellt feste Bedeutungsfarben bereit", function()
			local S = Exo.UI.Theme.SEMANTIC
			assert.equal("1eff00", S.positiveHex)
			assert.equal("ff4538", S.negativeHex)
			assert.equal("ffd700", S.warningHex)
		end)

		it("Theme.Color faerbt Text semantisch ein", function()
			assert.equal("|cff1eff00ok|r", Exo.UI.Theme.Color("ok", "positive"))
			assert.equal("|cffff45383 fehlen|r", Exo.UI.Theme.Color("3 fehlen", "negative"))
			-- unbekannte Art -> neutral grau
			assert.equal("|cff808080x|r", Exo.UI.Theme.Color("x"))
		end)
	end)

	describe("Account-Summary", function()
		it("zaehlt direkt nach dem Login den aktuellen Charakter", function()
			-- SimulateLogin registriert den eingeloggten Char automatisch
			assert.matches("1 Twink", Exo.UI.BuildAccountSummary())
		end)

		it("summiert Gold, zaehlt Twinks, mittelt iLvl, zaehlt offene Vaults", function()
			seedChar("Default.Testrealm.Anna", { gold = 1000000, ilvl = 480,
				mplus = { rating = 3000, dungeons = {}, vault = {
					{ type = 1, index = 1, progress = 4, threshold = 4, level = 10 } } } })
			seedChar("Default.Testrealm.Bob", { gold = 500000, ilvl = 460 })
			-- 2 geseedete Chars + der eingeloggte Testchar
			local text = Exo.UI.BuildAccountSummary()
			assert.matches("3 Twinks", text)
			assert.matches("150", text)               -- 1.500.000 Kupfer = 150 g
			assert.matches("iLvl%-Schnitt 470", text)
			assert.matches("1x Vault offen", text)
		end)
	end)

	describe("Designer-Handler", function()
		it("SetNavPosition speichert die Option (ohne Fenster kein Fehler)", function()
			local Designer = Exo.UI.DesignerTab
			Designer.SetNavPosition("left")
			assert.equal("left", Exo.API.GetOption("nav.position", "top"))
			Designer.SetNavPosition("top")
			assert.equal("top", Exo.API.GetOption("nav.position", "top"))
		end)

		it("SetDensity wirkt sofort ueber das Theme", function()
			local Designer = Exo.UI.DesignerTab
			Designer.SetDensity("compact")
			assert.equal("compact", Exo.API.GetOption("theme.density"))
			assert.equal(0.8, Exo.UI.VirtualScroll._densityFactor)
			Designer.SetDensity("normal")
			assert.equal(1, Exo.UI.VirtualScroll._densityFactor)
		end)

		it("ResetAll setzt Navigation und Dichte zurueck", function()
			local Designer = Exo.UI.DesignerTab
			Designer.SetNavPosition("left")
			Designer.SetDensity("compact")
			Designer.ResetAll()
			assert.is_nil(Exo.API.GetOption("nav.position"))
			assert.is_nil(Exo.API.GetOption("theme.density"))
			assert.equal(1, Exo.UI.VirtualScroll._densityFactor)
		end)
	end)
end)
