-- spec/guildtax_spec.lua
-- Gildensteuer (1.2.0): Erfassung, Quellen, Reset, Bericht, UI, Slash.
local mock = require("spec.wow_mock")

describe("Gildensteuer", function()
	local Exo, Collector

	local function currentTax()
		return Exo.API.GetGuildTax(Exo.Store:GetCurrentKey())
	end

	local function earn(delta)
		mock.SetMoney((_G.GetMoney() or 0) + delta)
		mock.FireEvent("PLAYER_MONEY")
	end

	before_each(function()
		mock.Reset()
		Exo = mock.LoadExoCore()
		mock.SetGuildBank("Nachtwache", {}) -- setzt nur den Gildennamen
		mock.SetMoney(100000)
		mock.SimulateLogin()
		mock.FireEvent("PLAYER_ENTERING_WORLD") -- Gold-Baseline
		Collector = Exo.Collectors.GuildTax
		Exo.API.SetOption("guildtax.enabled", true)
		Exo.API.SetOption("guildtax.rate.Nachtwache", 5)
	end)

	describe("Erfassung", function()
		it("verbucht bei Einnahmen den Steuersatz der Gilde", function()
			earn(10000) -- 1g Einnahme
			assert.equal(10000, currentTax().income)
			assert.equal(500, currentTax().owed) -- 5%
			earn(10000)
			assert.equal(1000, currentTax().owed) -- kumuliert
		end)

		it("ignoriert Ausgaben und inaktive Steuer", function()
			earn(-5000)
			assert.equal(0, currentTax().owed)
			Exo.API.SetOption("guildtax.enabled", nil)
			earn(10000)
			assert.equal(0, currentTax().owed)
		end)

		it("ohne Steuersatz passiert nichts", function()
			Exo.API.SetOption("guildtax.rate.Nachtwache", nil)
			earn(10000)
			assert.equal(0, currentTax().owed)
		end)

		it("TaxFor rundet kaufmaennisch", function()
			assert.equal(500, Collector.TaxFor(10000, 5))
			assert.equal(1, Collector.TaxFor(10, 5))   -- 0.5 -> 1
			assert.equal(0, Collector.TaxFor(9, 5))    -- 0.45 -> 0
		end)
	end)

	describe("Quellen", function()
		it("Post zaehlt standardmaessig, Handel nicht", function()
			mock.FireEvent("MAIL_SHOW")
			earn(10000)
			assert.equal(500, currentTax().owed)
			mock.FireEvent("MAIL_CLOSED")

			mock.FireEvent("TRADE_SHOW")
			earn(10000)
			assert.equal(500, currentTax().owed) -- unveraendert
			mock.FireEvent("TRADE_CLOSED")
		end)

		it("Quellen sind einzeln umschaltbar", function()
			Exo.API.SetOption("guildtax.source.trade", true)
			mock.FireEvent("TRADE_SHOW")
			earn(10000)
			assert.equal(500, currentTax().owed)
			mock.FireEvent("TRADE_CLOSED")

			Exo.API.SetOption("guildtax.source.loot", false)
			earn(10000)
			assert.equal(500, currentTax().owed) -- Loot deaktiviert
		end)
	end)

	describe("Reset + Bericht", function()
		local function seedTaxChar(charKey, guild, owed, income)
			local char = Exo.Store:GetOrCreateCharacter(charKey)
			local _, realm, name = Exo.Schema.ParseCharKey(charKey)
			char.meta.name = name
			char.meta.realm = realm
			char.meta.guild = guild
			Exo.Store:WriteCharacterData(charKey, "guildtax",
				{ income = income, owed = owed })
		end

		it("ResetChar setzt income und owed auf 0", function()
			earn(10000)
			Collector.ResetChar(Exo.Store:GetCurrentKey())
			assert.equal(0, currentTax().owed)
			assert.equal(0, currentTax().income)
		end)

		it("Bericht gruppiert nach Gilde, hoechste Schuld zuerst", function()
			Exo.API.SetOption("guildtax.rate.Andere", 2)
			seedTaxChar("Default.Testrealm.Anna", "Nachtwache", 700, 14000)
			seedTaxChar("Default.Testrealm.Bob", "Nachtwache", 900, 18000)
			seedTaxChar("Default.Testrealm.Zoe", "Andere", 200, 10000)

			local report = Exo.API.GetGuildTaxReport()
			assert.equal(2, #report.guilds)
			assert.equal("Andere", report.guilds[1].guild) -- alphabetisch
			assert.equal("Nachtwache", report.guilds[2].guild)
			assert.equal(1600, report.guilds[2].owed)
			assert.equal("Bob", report.guilds[2].chars[1].name) -- 900 vor 700
			assert.equal(1800, report.totalOwed)
		end)
	end)

	describe("UI", function()
		before_each(function() mock.LoadExoUI() end)

		it("Modul zeigt Aus-Hinweis bzw. Betraege mit taxKey", function()
			Exo.API.SetOption("guildtax.enabled", nil)
			local rows = Exo.UI.OverviewTab.BuildModuleRows("tax")
			assert.matches("Gildensteuer ist aus", rows[1].text)

			Exo.API.SetOption("guildtax.enabled", true)
			earn(10000)
			rows = Exo.UI.OverviewTab.BuildModuleRows("tax")
			assert.matches("Nachtwache", rows[1].text)
			assert.matches("5%%", rows[1].text)
			assert.is_string(rows[2].taxKey)
			assert.matches("offen", rows[2].text)
		end)

		it("Shift-Klick auf eine Steuer-Zeile setzt den Char zurueck", function()
			earn(10000)
			local Tab = Exo.UI.OverviewTab
			Tab:Render(CreateFrame("Frame"))
			local row = Tab._GetScroller().rows[1]
			row._module = false -- Mock-Frames stubben nil-Felder; false = leer
			row._hint = false
			row._taxKey = Exo.Store:GetCurrentKey()
			mock.SetShiftDown(true)
			row._scripts.OnMouseDown(row)
			mock.SetShiftDown(false)
			assert.equal(0, currentTax().owed)
		end)

		it("Designer-Schalter togglen Steuer und Quellen", function()
			local Designer = Exo.UI.DesignerTab
			Designer.ToggleGuildTax()
			assert.is_false(Collector.IsEnabled())
			Designer.ToggleGuildTax()
			assert.is_true(Collector.IsEnabled())
			Designer.ToggleTaxSource("trade")
			assert.is_true(Collector.IsSourceEnabled("trade"))
			Designer.ToggleTaxSource("trade")
			assert.is_false(Collector.IsSourceEnabled("trade"))
		end)
	end)

	describe("Sichtbarkeit + Saetze im UI (1.4.2)", function()
		before_each(function() mock.LoadExoUI() end)

		it("GetGuildTaxRates listet konfigurierte Saetze", function()
			Exo.API.SetOption("guildtax.rate.Andere", 2)
			local rates = Exo.API.GetGuildTaxRates()
			assert.equal(2, #rates)
			assert.equal("Andere", rates[1].guild)
			assert.equal(5, rates[2].rate) -- Nachtwache aus dem Setup
		end)

		it("Report zeigt Gilden mit Satz auch ohne eingeloggte Chars", function()
			Exo.API.SetOption("guildtax.rate.Geisterhaus", 3)
			local report = Exo.API.GetGuildTaxReport()
			local found
			for _, guild in ipairs(report.guilds) do
				if guild.guild == "Geisterhaus" then found = guild end
			end
			assert.is_table(found)
			assert.equal(3, found.rate)
			assert.equal(0, #found.chars)
			-- Modul erklaert die fehlenden Chars
			local rows = Exo.UI.OverviewTab.BuildModuleRows("tax")
			local all = ""
			for _, row in ipairs(rows) do all = all .. row.text .. "\n" end
			assert.matches("Geisterhaus", all)
			assert.matches("Gilde wird beim Login erkannt", all)
		end)

		it("CycleTaxRate schaltet die Stufen durch (inkl. krummer Werte)", function()
			local Designer = Exo.UI.DesignerTab
			Exo.API.SetOption("guildtax.rate.Nachtwache", nil)
			Designer.CycleTaxRate("Nachtwache") -- 0 -> 1
			assert.equal(1, Exo.API.GetOption("guildtax.rate.Nachtwache"))
			Designer.CycleTaxRate("Nachtwache") -- 1 -> 2
			Designer.CycleTaxRate("Nachtwache") -- 2 -> 3
			Designer.CycleTaxRate("Nachtwache") -- 3 -> 5
			assert.equal(5, Exo.API.GetOption("guildtax.rate.Nachtwache"))
			Exo.API.SetOption("guildtax.rate.Nachtwache", 7) -- krumm (Slash)
			Designer.CycleTaxRate("Nachtwache") -- -> 10
			assert.equal(10, Exo.API.GetOption("guildtax.rate.Nachtwache"))
			Exo.API.SetOption("guildtax.rate.Nachtwache", 20)
			Designer.CycleTaxRate("Nachtwache") -- 20 -> 0 (geloescht)
			assert.is_nil(Exo.API.GetOption("guildtax.rate.Nachtwache"))
		end)

		it("Designer baut Satz-Buttons fuer bekannte Gilden", function()
			local Designer = Exo.UI.DesignerTab
			Designer:Render(CreateFrame("Frame"))
			local buttons = Designer._GetButtons()
			local btn = buttons.taxRate and buttons.taxRate["Nachtwache"]
			assert.is_table(btn)
			assert.matches("Nachtwache: 5%%", btn:GetText())
			assert.is_true(btn._selected)
		end)

		it("Fensterkopf zeigt den offenen Betrag", function()
			earn(200000) -- 20g -> 1g Steuer offen
			local summary = Exo.UI.BuildAccountSummary()
			assert.matches("Steuer offen:", summary)
			assert.matches("|cffffd700", summary)
		end)
	end)

	describe("/exo tax", function()
		it("rate setzt den Satz der aktuellen Gilde", function()
			_G.SlashCmdList["EXO"]("tax rate 7")
			assert.equal(7, Exo.API.GetOption("guildtax.rate.Nachtwache"))
			_G.SlashCmdList["EXO"]("tax rate 0")
			assert.is_nil(Exo.API.GetOption("guildtax.rate.Nachtwache"))
		end)

		it("Bericht listet offene Betraege", function()
			earn(200000) -- 20g -> 1g Steuer
			local before = #mock.printed
			_G.SlashCmdList["EXO"]("tax")
			local out = table.concat(mock.printed, "\n", before + 1)
			assert.matches("Nachtwache", out)
			assert.matches("1g offen", out)
		end)
	end)
end)
