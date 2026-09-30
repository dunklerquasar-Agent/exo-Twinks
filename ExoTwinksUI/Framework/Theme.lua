-- ExoTwinksUI/Framework/Theme.lua
-- Designer-Unterbau: uebersetzt gespeicherte Optionen (Exo.API.GetOption)
-- in das zentrale Farbschema (Widgets.COLORS). Der AlterEgo-/ElvUI-Look
-- (flache Flaechen, 1px Kante, Akzentfarbe) bleibt erhalten -- nur die
-- Werte sind konfigurierbar.

local Theme = {}
Exo.UI = Exo.UI or {}
Exo.UI.Theme = Theme

-- Standardwerte = bisheriger fest verdrahteter Look
Theme.DEFAULTS = {
	accent  = "1784d1", -- ElvUI-Blau
	bgAlpha = 0.92,     -- Fenster-Deckkraft
	bgShade = 0.06,     -- Fenster-Helligkeit (0 = schwarz)
	density = "normal", -- Zeilendichte: normal | compact
}

-- Semantic Colors (fest, nicht konfigurierbar): einheitliche Bedeutung
-- ueberall im UI -- positiv/erledigt, negativ/fehlt, Warnung/offen.
Theme.SEMANTIC = {
	positiveHex = "1eff00",
	negativeHex = "ff4538",
	warningHex  = "ffd700",
	mutedHex    = "808080",
}

-- Kurzform: Text semantisch einfaerben, z. B. Theme.Color("5/8", "warning")
function Theme.Color(text, kind)
	local hex = Theme.SEMANTIC[(kind or "muted") .. "Hex"] or Theme.SEMANTIC.mutedHex
	return "|cff" .. hex .. tostring(text) .. "|r"
end

function Theme.HexToRGB(hex)
	if type(hex) ~= "string" or #hex < 6 then hex = Theme.DEFAULTS.accent end
	return tonumber(hex:sub(1, 2), 16) / 255,
		tonumber(hex:sub(3, 4), 16) / 255,
		tonumber(hex:sub(5, 6), 16) / 255
end

-- Liest die gespeicherten Optionen und schreibt sie nach Widgets.COLORS.
-- Ohne gespeicherte Optionen aendert sich nichts am Standard-Look.
function Theme.Load()
	local COLORS = Exo.UI.Widgets.COLORS
	local hex = Exo.API.GetOption("theme.accent", Theme.DEFAULTS.accent)
	local r, g, b = Theme.HexToRGB(hex)
	COLORS.accent = { r, g, b, 1 }
	COLORS.accentHex = hex

	local alpha = tonumber(Exo.API.GetOption("theme.bgAlpha", Theme.DEFAULTS.bgAlpha))
		or Theme.DEFAULTS.bgAlpha
	local shade = tonumber(Exo.API.GetOption("theme.bgShade", Theme.DEFAULTS.bgShade))
		or Theme.DEFAULTS.bgShade
	COLORS.bg = { shade, shade, shade, alpha }
	COLORS.panel = { shade + 0.04, shade + 0.04, shade + 0.04, 1 }

	-- Dichte-Modus auf alle Listen anwenden (VirtualScroll laedt nach Theme,
	-- daher zur Laufzeit geprueft)
	local density = Exo.API.GetOption("theme.density", Theme.DEFAULTS.density)
	if Exo.UI.VirtualScroll and Exo.UI.VirtualScroll.ApplyDensity then
		Exo.UI.VirtualScroll.ApplyDensity(density == "compact" and 0.8 or 1)
	end
end

-- Option setzen + sofort anwenden (Fenster neu einfaerben, aktiven Tab rendern)
function Theme.Set(key, value)
	Exo.API.SetOption(key, value)
	Theme.Load()
	if Exo.UI.ApplyTheme then Exo.UI:ApplyTheme() end
end

-- Alles zuruecksetzen auf den Standard-Look
function Theme.Reset()
	Exo.API.SetOption("theme.accent", nil)
	Exo.API.SetOption("theme.bgAlpha", nil)
	Exo.API.SetOption("theme.bgShade", nil)
	Exo.API.SetOption("theme.density", nil)
	Theme.Load()
	if Exo.UI.ApplyTheme then Exo.UI:ApplyTheme() end
end
