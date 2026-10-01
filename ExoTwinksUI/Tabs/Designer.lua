-- ExoTwinksUI/Tabs/Designer.lua
-- Reiter "Designer": fuegt alle Ansichten unter einem konfigurierbaren
-- AlterEgo-Look zusammen. Alles wird accountweit gespeichert (Exo.API.SetOption)
-- und sofort live angewendet -- kein /reload noetig.
--
-- Konfigurierbar:
--   * Akzentfarbe: 6 Presets ODER freie Hex-Eingabe (RRGGBB)
--   * Hintergrund: Deckkraft + Helligkeit
--   * Fenstergroesse: Presets + "Groesse merken" (Griff unten rechts)
--   * Reiter: einzelne Tabs ein-/ausblenden
--   * Uebersicht: Module ein-/ausblenden + Reihenfolge
--   * Inventar-Standards: Ansicht (Liste/Symbole) + Gruppierung
--   * Charaktere-Tab: einzelne Zeilen-Gruppen ein-/ausblenden

local Tab = {
	id = "designer",
	label = "Designer",
}
Exo.UI.DesignerTab = Tab

-- Auswahlwerte (rein, testbar) ---------------------------------------------------------

Tab.ACCENTS = {
	{ hex = "1784d1", label = "ElvUI-Blau" },
	{ hex = "00b4ff", label = "AE-Blau" },
	{ hex = "1eff00", label = "Gruen" },
	{ hex = "ffd700", label = "Gold" },
	{ hex = "ff4538", label = "Rot" },
	{ hex = "a335ee", label = "Lila" },
}

Tab.BG_ALPHAS = {
	{ value = 0.70, label = "70%" },
	{ value = 0.85, label = "85%" },
	{ value = 0.92, label = "92%" },
	{ value = 1.00, label = "100%" },
}

Tab.BG_SHADES = {
	{ value = 0.03, label = "Schwarz" },
	{ value = 0.06, label = "Dunkel" },
	{ value = 0.12, label = "Grau" },
	{ value = 0.20, label = "Hell" },
}

Tab.WINDOW_SIZES = {
	{ w = 720, h = 420, label = "720 x 420" },
	{ w = 900, h = 520, label = "900 x 520" },
	{ w = 1100, h = 650, label = "1100 x 650" },
}

-- Zeilen-Gruppen der Charaktere-Matrix (Option: "charRow.<id>")
Tab.CHAR_ROWS = {
	{ id = "gold", label = "Gold" },
	{ id = "bags", label = "Taschen" },
	{ id = "played", label = "Gespielt" },
	{ id = "rest", label = "Erholt" },
	{ id = "lastSeen", label = "Zuletzt online" },
	{ id = "ilvl", label = "Itemlevel" },
	{ id = "mplus", label = "Mythic+" },
	{ id = "vault", label = "Schatzkammer" },
	{ id = "raids", label = "Raids" },
	{ id = "weeklies", label = "Weeklies" },
	{ id = "currencies", label = "Waehrungen" },
}

Tab.INV_VIEWS = {
	{ id = "list", label = "Liste" },
	{ id = "icons", label = "Symbole" },
}

Tab.NAV_POSITIONS = {
	{ id = "top", label = "Oben (Tabs)" },
	{ id = "left", label = "Links (Sidebar)" },
}

Tab.DENSITIES = {
	{ id = "normal", label = "Normal" },
	{ id = "compact", label = "Kompakt" },
}

-- Sichtbarkeit steuerbarer Reiter (Designer selbst ist immer sichtbar)
Tab.TABS = {
	{ id = "overview", label = "Uebersicht" },
	{ id = "characters", label = "Charaktere" },
	{ id = "inventory", label = "Inventar" },
	{ id = "professions", label = "Berufe" },
	{ id = "mail", label = "Post" },
	{ id = "reputations", label = "Ruf" },
}

-- Handler (rein ueber Optionen, testbar) -----------------------------------------------

function Tab.SetAccent(hex)
	Exo.UI.Theme.Set("theme.accent", hex)
end

-- Freie Farbwahl: akzeptiert "RRGGBB", "#RRGGBB", Gross-/Kleinschreibung.
-- Rueckgabe true bei Erfolg, false bei ungueltiger Eingabe.
function Tab.SetAccentHex(input)
	local hex = tostring(input or ""):gsub("^%s*#?", ""):gsub("%s+$", ""):lower()
	if not hex:match("^%x%x%x%x%x%x$") then return false end
	Tab.SetAccent(hex)
	return true
end

function Tab.SetBgAlpha(value)
	Exo.UI.Theme.Set("theme.bgAlpha", value)
end

function Tab.SetBgShade(value)
	Exo.UI.Theme.Set("theme.bgShade", value)
end

function Tab.ToggleCharRow(id)
	local key = "charRow." .. id
	local enabled = Exo.API.GetOption(key, true) ~= false
	Exo.API.SetOption(key, not enabled)
end

function Tab.IsCharRowEnabled(id)
	return Exo.API.GetOption("charRow." .. id, true) ~= false
end

function Tab.SetInventoryView(viewID)
	Exo.API.SetOption("inventory.defaultView", viewID)
	local Inventory = Exo.UI.InventoryTab
	if Inventory then Inventory.viewMode = viewID end
end

function Tab.SetInventoryGroup(groupID)
	Exo.API.SetOption("inventory.defaultGroup", groupID)
	local Inventory = Exo.UI.InventoryTab
	if Inventory then
		for index, mode in ipairs(Inventory.GROUP_MODES) do
			if mode.id == groupID then Inventory.groupModeIndex = index end
		end
	end
end

function Tab.SetNavPosition(position)
	Exo.API.SetOption("nav.position", position)
	if Exo.UI.ApplyNavLayout then Exo.UI:ApplyNavLayout() end
end

function Tab.SetDensity(mode)
	Exo.UI.Theme.Set("theme.density", mode)
end

-- Gildensteuer (1.2.0/1.4.2)

-- Alle bekannten Gilden: aus Char-Metas, gescannten Gildenbanken und
-- bereits konfigurierten Saetzen (sortiert, ohne Duplikate)
function Tab.GetKnownGuilds()
	local seen, list = {}, {}
	local function add(name)
		if name and name ~= "" and not seen[name] then
			seen[name] = true
			list[#list + 1] = name
		end
	end
	for _, charKey in ipairs(Exo.API.GetCharacterKeys()) do
		local meta = Exo.API.GetCharacterInfo(charKey)
		add(meta and meta.guild)
	end
	for _, guild in ipairs(Exo.API.GetGuilds()) do add(guild.name) end
	for _, entry in ipairs(Exo.API.GetGuildTaxRates()) do add(entry.guild) end
	table.sort(list)
	return list
end

-- Klick auf einen Gilden-Button schaltet den Satz eine Stufe weiter
Tab.TAX_RATE_STEPS = { 0, 1, 2, 3, 5, 10, 15, 20 }

function Tab.CycleTaxRate(guild)
	local current = tonumber(Exo.API.GetOption("guildtax.rate." .. guild, 0)) or 0
	local nextRate = 0
	for index, step in ipairs(Tab.TAX_RATE_STEPS) do
		if step == current then
			nextRate = Tab.TAX_RATE_STEPS[index + 1] or 0
			break
		elseif step > current then
			nextRate = step -- krummer Wert (z. B. 7 via Slash) -> naechste Stufe
			break
		end
	end
	Exo.API.SetOption("guildtax.rate." .. guild, nextRate > 0 and nextRate or nil)
	Tab:RefreshStates()
	if Exo.UI.RefreshActiveTab then Exo.UI:RefreshActiveTab() end
end

function Tab.ToggleGuildTax()
	local Collector = Exo.Collectors and Exo.Collectors.GuildTax
	local enabled = Collector and Collector.IsEnabled()
	if enabled then
		Exo.API.SetOption("guildtax.enabled", nil)
	else
		Exo.API.SetOption("guildtax.enabled", true)
	end
	Tab:RefreshStates()
	if Exo.UI.RefreshActiveTab then Exo.UI:RefreshActiveTab() end
end

function Tab.ToggleTaxSource(source)
	local Collector = Exo.Collectors and Exo.Collectors.GuildTax
	if not Collector then return end
	if Collector.IsSourceEnabled(source) then
		Exo.API.SetOption("guildtax.source." .. source, false)
	else
		Exo.API.SetOption("guildtax.source." .. source, true)
	end
	Tab:RefreshStates()
end

-- Minimap-Button ein-/ausblenden (1.0.0)
function Tab.IsMinimapShown()
	return Exo.API.GetOption("minimap.hide", false) ~= true
end

function Tab.ToggleMinimap()
	if Tab.IsMinimapShown() then
		Exo.API.SetOption("minimap.hide", true)
	else
		Exo.API.SetOption("minimap.hide", nil)
	end
	local button = Exo.MinimapButton
	if button then
		if Tab.IsMinimapShown() then button:Show() else button:Hide() end
	end
end

-- Fenster-Skalierung zyklisch durchschalten (1.10.0): 70 % -> ... -> 130 % -> 70 %
Tab.SCALE_STEPS = { 0.7, 0.8, 0.9, 1.0, 1.1, 1.2, 1.3 }

function Tab.CycleWindowScale()
	local current = tonumber(Exo.API.GetOption("window.scale")) or 1
	local nextScale = Tab.SCALE_STEPS[1]
	for index, step in ipairs(Tab.SCALE_STEPS) do
		if math.abs(step - current) < 0.01 then
			nextScale = Tab.SCALE_STEPS[index + 1] or Tab.SCALE_STEPS[1]
			break
		end
	end
	Exo.API.SetOption("window.scale", nextScale)
	if Exo.UI.ApplyWindowScale then Exo.UI:ApplyWindowScale() end
	return nextScale
end

-- Button-Beschriftung "Skalierung: 110 %" (rein, testbar)
function Tab.GetScaleLabel()
	local scale = tonumber(Exo.API.GetOption("window.scale")) or 1
	return string.format("Skalierung: %d %%", math.floor(scale * 100 + 0.5))
end

function Tab.ResetWindowPosition()
	if Exo.UI.ResetWindowPosition then
		Exo.UI:ResetWindowPosition()
	else
		Exo.API.SetOption("window.pos", nil)
	end
end

function Tab.ToggleRememberSize()
	local remember = Exo.API.GetOption("window.remember", true)
	Exo.API.SetOption("window.remember", not remember)
end

function Tab.IsTabShown(tabId)
	return Exo.API.GetOption("tab.hidden." .. tabId, false) ~= true
end

function Tab.ToggleTab(tabId)
	Exo.API.SetOption("tab.hidden." .. tabId, Tab.IsTabShown(tabId))
	if Exo.UI.ApplyTabVisibility then Exo.UI:ApplyTabVisibility() end
end

function Tab.ResetAll()
	-- Theme zurueck auf Standard
	Exo.UI.Theme.Reset()
	-- Zeilen, Inventar-Standards, Fenster, Tabs, Uebersicht
	for _, row in ipairs(Tab.CHAR_ROWS) do
		Exo.API.SetOption("charRow." .. row.id, nil)
	end
	Exo.API.SetOption("inventory.defaultView", nil)
	Exo.API.SetOption("inventory.defaultGroup", nil)
	Exo.API.SetOption("window.remember", nil)
	Exo.API.SetOption("window.width", nil)
	Exo.API.SetOption("window.height", nil)
	Exo.API.SetOption("nav.position", nil)
	if Exo.UI.ApplyNavLayout then Exo.UI:ApplyNavLayout() end
	Exo.API.SetOption("minimap.hide", nil)
	if Exo.MinimapButton then Exo.MinimapButton:Show() end
	-- Gildensteuer: Schalter/Quellen zuruecksetzen -- Saetze (guildtax.rate.*)
	-- und offene Betraege bleiben bewusst erhalten (Nutzdaten, kein Design)
	Exo.API.SetOption("guildtax.enabled", nil)
	for _, source in ipairs({ "loot", "mail", "trade" }) do
		Exo.API.SetOption("guildtax.source." .. source, nil)
	end
	for _, t in ipairs(Tab.TABS) do
		Exo.API.SetOption("tab.hidden." .. t.id, nil)
	end
	local Overview = Exo.UI.OverviewTab
	if Overview then
		Exo.API.SetOption("overview.order", nil)
		for _, m in ipairs(Overview.MODULES) do
			Exo.API.SetOption("overview.show." .. m.id, nil)
			Exo.API.SetOption("overview.collapsed." .. m.id, nil)
		end
	end
	if Exo.UI.ApplyTabVisibility then Exo.UI:ApplyTabVisibility() end
end

-- Aufbau -------------------------------------------------------------------------------

local ROW_STEP = 21      -- vertikaler Abstand zwischen Zeilen (15 Zeilen-Budget)
local LABEL_W = 150      -- Breite der Beschriftungs-Spalte links

local function buildUI(self, content)
	local Widgets = Exo.UI.Widgets
	local y = -4
	self._buttons = {}   -- [gruppe][key] = Button (fuer RefreshStates)

	-- Eine Zeile: Label links, Buttons rechts.
	-- Eintraege: {group, key, label, width, onClick}
	local function row(caption, entries, defaultWidth)
		local label = Widgets.Label(content, caption, "GameFontNormal")
		label:SetPoint("TOPLEFT", 4, y - 3)
		local x = LABEL_W
		for _, entry in ipairs(entries) do
			local width = entry.width or defaultWidth
			local btn = Widgets.Button(content, entry.label, width, 20, function()
				entry.onClick()
				self:RefreshStates()
				Exo.UI:RefreshActiveTab()
			end)
			btn:SetPoint("TOPLEFT", x, y)
			self._buttons[entry.group] = self._buttons[entry.group] or {}
			self._buttons[entry.group][entry.key] = btn
			x = x + width + 6
		end
		y = y - ROW_STEP
		return x
	end

	-- Akzentfarbe: Presets
	local accents = {}
	for _, a in ipairs(Tab.ACCENTS) do
		accents[#accents + 1] = {
			group = "accent", key = a.hex,
			label = string.format("|cff%s%s|r", a.hex, a.label),
			onClick = function() Tab.SetAccent(a.hex) end,
		}
	end
	row("Akzentfarbe", accents, 84)

	-- Akzentfarbe: freie Hex-Eingabe
	local hexLabel = Widgets.Label(content, "Eigene Farbe", "GameFontNormal")
	hexLabel:SetPoint("TOPLEFT", 4, y - 3)
	local hexBox = Exo.WowAPI.CreateFrame("EditBox", nil, content, "InputBoxTemplate")
	hexBox:SetSize(90, 20)
	hexBox:SetPoint("TOPLEFT", LABEL_W + 6, y)
	hexBox:SetAutoFocus(false)
	hexBox:SetMaxLetters(7)
	self._hexBox = hexBox
	local function applyHex()
		local ok = Tab.SetAccentHex(hexBox:GetText())
		self._hexStatus:SetText(ok and "Format: RRGGBB"
			or "|cffff4538Ungueltig - Format: RRGGBB|r")
		self:RefreshStates()
	end
	-- Enter uebernimmt direkt (1.1.1)
	hexBox:SetScript("OnEnterPressed", function(box)
		applyHex()
		if box.ClearFocus then box:ClearFocus() end
	end)
	local hexApply = Widgets.Button(content, "Uebernehmen", 100, 20, applyHex)
	hexApply:SetPoint("TOPLEFT", LABEL_W + 102, y)
	self._hexStatus = Widgets.Label(content, "Format: RRGGBB", "GameFontDisableSmall")
	self._hexStatus:SetPoint("TOPLEFT", LABEL_W + 210, y - 3)
	y = y - ROW_STEP

	-- Hintergrund
	local alphas = {}
	for _, a in ipairs(Tab.BG_ALPHAS) do
		alphas[#alphas + 1] = {
			group = "bgAlpha", key = a.value, label = a.label,
			onClick = function() Tab.SetBgAlpha(a.value) end,
		}
	end
	row("Deckkraft", alphas, 84)
	local shades = {}
	for _, s in ipairs(Tab.BG_SHADES) do
		shades[#shades + 1] = {
			group = "bgShade", key = s.value, label = s.label,
			onClick = function() Tab.SetBgShade(s.value) end,
		}
	end
	row("Helligkeit", shades, 84)

	-- Fenster
	local sizes = {}
	for _, s in ipairs(Tab.WINDOW_SIZES) do
		sizes[#sizes + 1] = {
			group = "size", key = s.label, label = s.label,
			onClick = function() Exo.UI:SetWindowSize(s.w, s.h) end,
		}
	end
	sizes[#sizes + 1] = {
		group = "remember", key = "remember", label = "Groesse merken", width = 120,
		onClick = function() Tab.ToggleRememberSize() end,
	}
	sizes[#sizes + 1] = {
		group = "minimap", key = "minimap", label = "Minimap-Button", width = 116,
		onClick = function() Tab.ToggleMinimap() end,
	}
	-- 1.10.0: Skalierung (zyklisch) + Fensterposition zuruecksetzen
	sizes[#sizes + 1] = {
		group = "scale", key = "scale", label = Tab.GetScaleLabel(), width = 120,
		onClick = function()
			Tab.CycleWindowScale()
			if self._content then self:Render(self._content) end
		end,
	}
	sizes[#sizes + 1] = {
		group = "resetpos", key = "resetpos", label = "Position zentrieren", width = 130,
		onClick = function() Tab.ResetWindowPosition() end,
	}
	row("Fenster", sizes, 84)

	-- Layout: Navigation (oben/links) + Zeilendichte
	local layout = {}
	for _, n in ipairs(Tab.NAV_POSITIONS) do
		layout[#layout + 1] = {
			group = "nav", key = n.id, label = n.label, width = 110,
			onClick = function() Tab.SetNavPosition(n.id) end,
		}
	end
	for _, d in ipairs(Tab.DENSITIES) do
		layout[#layout + 1] = {
			group = "density", key = d.id, label = "Dichte: " .. d.label, width = 120,
			onClick = function() Tab.SetDensity(d.id) end,
		}
	end
	row("Layout", layout, 110)

	-- Reiter ein-/ausblenden
	local tabs = {}
	for _, t in ipairs(Tab.TABS) do
		tabs[#tabs + 1] = {
			group = "tabs", key = t.id, label = t.label,
			onClick = function() Tab.ToggleTab(t.id) end,
		}
	end
	row("Reiter anzeigen", tabs, 84)

	-- Uebersicht: Module (zwei Zeilen; Reihenfolge aendert man per
	-- Shift-Klick auf die Modul-Kopfzeile direkt in der Uebersicht)
	local Overview = Exo.UI.OverviewTab
	if Overview then
		local firstHalf, secondHalf = {}, {}
		local half = math.ceil(#Overview.MODULES / 2)
		for index, m in ipairs(Overview.MODULES) do
			local target = index <= half and firstHalf or secondHalf
			target[#target + 1] = {
				group = "ovShow", key = m.id, label = m.label,
				onClick = function() Overview.ToggleModuleShown(m.id) end,
			}
		end
		row("Uebersicht: Module", firstHalf, 100)
		if #secondHalf > 0 then
			row("", secondHalf, 100)
		end
	end

	-- Gildensteuer (1.2.0)
	local tax = {
		{ group = "taxOn", key = "on", label = "Aktiv", width = 70,
			onClick = function() Tab.ToggleGuildTax() end },
	}
	for _, source in ipairs({
		{ id = "loot", label = "Quelle: Loot", width = 100 },
		{ id = "mail", label = "Quelle: Post", width = 100 },
		{ id = "trade", label = "Quelle: Handel", width = 110 },
	}) do
		tax[#tax + 1] = {
			group = "taxSource", key = source.id, label = source.label,
			width = source.width,
			onClick = function() Tab.ToggleTaxSource(source.id) end,
		}
	end
	tax[#tax + 1] = {
		group = "taxReset", key = "reset", label = "Alles auf 0", width = 90,
		onClick = function()
			if Exo.Collectors.GuildTax then
				Exo.Collectors.GuildTax.ResetAll()
				if Exo.UI.RefreshActiveTab then Exo.UI:RefreshActiveTab() end
			end
		end,
	}
	row("Gildensteuer", tax, 90)

	-- Steuersaetze je Gilde (1.4.2): Klick schaltet 0 -> 1 -> 2 -> 3 -> 5
	-- -> 10 -> 15 -> 20 -> 0 Prozent. Kein Slash-Kommando mehr noetig.
	local guilds = Tab.GetKnownGuilds()
	local rates = {}
	for index, guild in ipairs(guilds) do
		if index > 4 then break end -- Platzbudget; weitere per /exo tax rate
		rates[#rates + 1] = {
			group = "taxRate", key = guild, label = guild, width = 130,
			onClick = function() Tab.CycleTaxRate(guild) end,
		}
	end
	if #rates == 0 then
		rates[#rates + 1] = {
			group = "taxRate", key = "__none", width = 260,
			label = "Keine Gilde erkannt - Twinks einloggen",
			onClick = function() end,
		}
	end
	row("Steuersaetze (Klick)", rates, 130)

	-- Inventar-Standards: Ansicht + Gruppierung in einer Zeile
	local inv = {}
	for _, v in ipairs(Tab.INV_VIEWS) do
		inv[#inv + 1] = {
			group = "invView", key = v.id, label = v.label, width = 70,
			onClick = function() Tab.SetInventoryView(v.id) end,
		}
	end
	local Inventory = Exo.UI.InventoryTab
	for _, mode in ipairs(Inventory and Inventory.GROUP_MODES or {}) do
		inv[#inv + 1] = {
			group = "invGroup", key = mode.id, label = mode.label, width = 90,
			onClick = function() Tab.SetInventoryGroup(mode.id) end,
		}
	end
	row("Inventar-Standard", inv, 84)

	-- Charaktere-Matrix: Zeilen-Gruppen (2 Zeilen a 5 Buttons)
	local half = math.ceil(#Tab.CHAR_ROWS / 2)
	local first, second = {}, {}
	for index, r in ipairs(Tab.CHAR_ROWS) do
		local entry = {
			group = "charRows", key = r.id, label = r.label,
			onClick = function() Tab.ToggleCharRow(r.id) end,
		}
		if index <= half then first[#first + 1] = entry else second[#second + 1] = entry end
	end
	row("Charaktere: Zeilen", first, 88)
	row("", second, 88)

	-- Fusszeile: Zuruecksetzen + Hinweis
	local reset = Widgets.Button(content, "Alles zuruecksetzen", 160, 20, function()
		Tab.ResetAll()
		self:RefreshStates()
		Exo.UI:RefreshActiveTab()
	end)
	reset:SetPoint("BOTTOMLEFT", 4, 2)
	self._resetButton = reset

	local hint = Widgets.Label(content,
		"Alle Einstellungen wirken sofort und gelten accountweit.", "GameFontDisableSmall")
	hint:SetPoint("BOTTOMLEFT", 174, 6)
end

-- Markiert die Buttons entsprechend der gespeicherten Optionen
function Tab:RefreshStates()
	if not self._buttons then return end
	local API = Exo.API
	local Theme = Exo.UI.Theme

	local accent = API.GetOption("theme.accent", Theme.DEFAULTS.accent)
	for hex, btn in pairs(self._buttons.accent or {}) do
		btn:SetSelected(hex == accent)
	end
	local alpha = tonumber(API.GetOption("theme.bgAlpha", Theme.DEFAULTS.bgAlpha)) or 0
	for value, btn in pairs(self._buttons.bgAlpha or {}) do
		btn:SetSelected(math.abs(value - alpha) < 0.001)
	end
	local shade = tonumber(API.GetOption("theme.bgShade", Theme.DEFAULTS.bgShade)) or 0
	for value, btn in pairs(self._buttons.bgShade or {}) do
		btn:SetSelected(math.abs(value - shade) < 0.001)
	end

	local remember = API.GetOption("window.remember", true)
	for _, btn in pairs(self._buttons.remember or {}) do
		btn:SetSelected(remember and true or false)
	end
	-- Skalierungs-Button zeigt den aktuellen Wert (1.10.0)
	for _, btn in pairs(self._buttons.scale or {}) do
		btn:SetText(Tab.GetScaleLabel())
		btn:SetSelected(math.abs((tonumber(API.GetOption("window.scale")) or 1) - 1) > 0.01)
	end
	for _, btn in pairs(self._buttons.minimap or {}) do
		btn:SetSelected(Tab.IsMinimapShown())
	end

	local GuildTax = Exo.Collectors and Exo.Collectors.GuildTax
	if GuildTax then
		for _, btn in pairs(self._buttons.taxOn or {}) do
			btn:SetSelected(GuildTax.IsEnabled())
		end
		for source, btn in pairs(self._buttons.taxSource or {}) do
			btn:SetSelected(GuildTax.IsSourceEnabled(source))
		end
		for guild, btn in pairs(self._buttons.taxRate or {}) do
			if guild ~= "__none" then
				local rate = GuildTax.GetRate(guild)
				local name = guild
				if #name > 14 then name = name:sub(1, 13) .. ".." end
				btn:SetText(string.format("%s: %g%%", name, rate))
				btn:SetSelected(rate > 0)
			end
		end
	end

	local nav = API.GetOption("nav.position", "top")
	for id, btn in pairs(self._buttons.nav or {}) do
		btn:SetSelected(id == nav)
	end
	local density = API.GetOption("theme.density", Theme.DEFAULTS.density)
	for id, btn in pairs(self._buttons.density or {}) do
		btn:SetSelected(id == density)
	end

	for id, btn in pairs(self._buttons.tabs or {}) do
		btn:SetSelected(Tab.IsTabShown(id))
	end

	local Overview = Exo.UI.OverviewTab
	if Overview then
		for id, btn in pairs(self._buttons.ovShow or {}) do
			btn:SetSelected(Overview.IsModuleShown(id))
		end
	end

	local view = API.GetOption("inventory.defaultView", "list")
	for id, btn in pairs(self._buttons.invView or {}) do
		btn:SetSelected(id == view)
	end
	local group = API.GetOption("inventory.defaultGroup", "type")
	for id, btn in pairs(self._buttons.invGroup or {}) do
		btn:SetSelected(id == group)
	end

	for id, btn in pairs(self._buttons.charRows or {}) do
		btn:SetSelected(Tab.IsCharRowEnabled(id))
	end
end

-- Rendern ------------------------------------------------------------------------------

function Tab:Render(content)
	if self._content ~= content then
		self._content = content
		buildUI(self, content)
	end
	self:RefreshStates()
end

-- Test-Helfer
function Tab._GetButtons() return Tab._buttons end
function Tab._GetResetButton() return Tab._resetButton end
function Tab._GetHexBox() return Tab._hexBox end

Exo.UI:RegisterTab(Tab)
