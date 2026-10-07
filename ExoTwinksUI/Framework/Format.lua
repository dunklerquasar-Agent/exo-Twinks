-- ExoTwinksUI/Framework/Format.lua
-- Zentrale Anzeige-Formatierung. Reine Funktionen, vollstaendig testbar.

local Format = {}
Exo.UI = Exo.UI or {}
Exo.UI.Format = Format

-- Sekunden -> "3T 4h" / "5h 12m" / "42m" (nie negativ)
function Format.Duration(seconds)
	seconds = math.max(0, math.floor(tonumber(seconds) or 0))
	local days = math.floor(seconds / 86400)
	local hours = math.floor((seconds % 86400) / 3600)
	local minutes = math.floor((seconds % 3600) / 60)

	if days > 0 then
		return string.format("%dT %dh", days, hours)
	elseif hours > 0 then
		return string.format("%dh %dm", hours, minutes)
	else
		return string.format("%dm", minutes)
	end
end

-- Kupfer -> "1.234.567 g" (nur Goldanteil, mit Tausenderpunkten)
function Format.Gold(copper)
	local gold = math.floor((tonumber(copper) or 0) / 10000)
	local grouped = tostring(gold):reverse():gsub("(%d%d%d)", "%1."):reverse():gsub("^%.", "")
	return grouped .. " g"
end

-- Zaehlwort mit korrektem Singular/Plural: Count(1, "Charakter", "Charaktere") -> "1 Charakter"
function Format.Count(n, singular, plural)
	n = tonumber(n) or 0
	return string.format("%d %s", n, n == 1 and singular or plural)
end

-- Ganzzahl mit Tausenderpunkten: 815878 -> "815.878"
function Format.GroupDigits(n)
	n = math.floor(tonumber(n) or 0)
	local grouped = tostring(n):reverse():gsub("(%d%d%d)", "%1."):reverse():gsub("^%.", "")
	return grouped
end

-- Kupfer -> volle Geldanzeige "24.387g 85s 47c" (Muenz-Kuerzel eingefaerbt)
function Format.Money(copper)
	copper = math.floor(tonumber(copper) or 0)
	local gold = math.floor(copper / 10000)
	local silver = math.floor((copper % 10000) / 100)
	local rest = copper % 100
	return string.format("%s|cffffd700g|r %d|cffc7c7cfs|r %d|cffeda55fc|r",
		Format.GroupDigits(gold), silver, rest)
end

-- Level mit XP-Fortschritt als Nachkommastelle: 80 + 30% -> "80.3"
function Format.LevelProgress(level, xp, xpMax)
	level = tonumber(level) or 0
	xp, xpMax = tonumber(xp) or 0, tonumber(xpMax) or 0
	local frac = 0
	if xpMax > 0 then
		frac = math.min(9, math.floor((xp / xpMax) * 10))
	end
	return string.format("%d.%d", level, frac)
end

-- Ruhebonus in Prozent: 100 = voll ausgeruht (1,5 Level Ruhe-XP). nil wenn unbekannt.
function Format.RestPercent(restXP, xpMax)
	restXP, xpMax = tonumber(restXP), tonumber(xpMax)
	if not restXP or not xpMax or xpMax <= 0 then return nil end
	return math.min(100, math.floor((restXP / (xpMax * 1.5)) * 100 + 0.5))
end

-- Ruhebonus-Anzeige mit Ampelfarbe: 100% gruen, >=30% gelb, sonst rot
function Format.RestText(percent)
	if percent == nil then return "-" end
	local color = percent >= 100 and "|cff00ff00" or percent >= 30 and "|cffffd700" or "|cffff4040"
	return string.format("%s%d%%|r", color, percent)
end

-- "Zuletzt online": Zeitstempel -> "5 Minuten" / "11 Stunden" / "4 Tagen" / "11 Monaten"
function Format.TimeAgo(lastSeen, now)
	lastSeen = tonumber(lastSeen) or 0
	if lastSeen <= 0 then return "-" end
	-- 1.18.1: fehlt `now`, gilt die aktuelle Zeit. Vorher wurde nil zu 0 und
	-- JEDER Zeitstempel zu "1 Minute" (Uebersicht/Vergleich zeigten bei allen
	-- Chars "1 Minute").
	now = tonumber(now) or (Exo.WowAPI and Exo.WowAPI.Now()) or 0
	local diff = math.max(0, now - lastSeen)
	if diff < 3600 then
		return Format.Count(math.max(1, math.floor(diff / 60)), "Minute", "Minuten")
	elseif diff < 86400 then
		return Format.Count(math.floor(diff / 3600), "Stunde", "Stunden")
	elseif diff < 86400 * 30 then
		return Format.Count(math.floor(diff / 86400), "Tag", "Tagen")
	end
	return Format.Count(math.floor(diff / (86400 * 30)), "Monat", "Monaten")
end

-- Klassenfarben (classID 1..13, Blizzard-Standardpalette)
Format.CLASS_COLORS = {
	[1] = "c79c6e",  -- Krieger
	[2] = "f58cba",  -- Paladin
	[3] = "abd473",  -- Jaeger
	[4] = "fff569",  -- Schurke
	[5] = "ffffff",  -- Priester
	[6] = "c41f3b",  -- Todesritter
	[7] = "0070de",  -- Schamane
	[8] = "69ccf0",  -- Magier
	[9] = "9482c9",  -- Hexenmeister
	[10] = "00ff96", -- Moench
	[11] = "ff7d0a", -- Druide
	[12] = "a330c9", -- Daemonenjaeger
	[13] = "33937f", -- Rufer
}

-- Name in Klassenfarbe: ClassName("Anna", 8) -> "|cff69ccf0Anna|r"
function Format.ClassName(name, classID)
	local hex = Format.CLASS_COLORS[tonumber(classID) or 0]
	if not hex then return tostring(name or "") end
	return string.format("|cff%s%s|r", hex, tostring(name or ""))
end

-- Mythic+-Wertung mit Farbverlauf (angelehnt an die Client-Darstellung)
Format.RATING_STEPS = {
	{ 3000, "e6cc80" },  -- "legendary"
	{ 2500, "ff8000" },  -- orange
	{ 2000, "a335ee" },  -- lila
	{ 1500, "0070dd" },  -- blau
	{ 750,  "1eff00" },  -- gruen
	{ 0,    "ffffff" },
}

function Format.Rating(rating)
	rating = tonumber(rating) or 0
	for _, step in ipairs(Format.RATING_STEPS) do
		if rating >= step[1] then
			return string.format("|cff%s%d|r", step[2], rating)
		end
	end
	return tostring(rating)
end

-- Kuerzel eines Dungeon-Namens: "Black Rook Hold" -> "BRH" (max. 4 Zeichen)
function Format.Abbrev(name)
	local letters = {}
	for word in tostring(name or ""):gmatch("[^%s:%-']+") do
		local first = word:sub(1, 1)
		if first:match("%a") then
			letters[#letters + 1] = first:upper()
		end
	end
	local abbrev = table.concat(letters)
	if #abbrev < 2 then
		abbrev = tostring(name or ""):sub(1, 4)
	end
	return abbrev:sub(1, 4)
end

-- Item-Qualitaetsfarben (0 schlecht .. 7 erbstueck, Blizzard-Palette)
Format.QUALITY_COLORS = {
	[0] = "9d9d9d", [1] = "ffffff", [2] = "1eff00", [3] = "0070dd",
	[4] = "a335ee", [5] = "ff8000", [6] = "e6cc80", [7] = "00ccff",
}

-- Itemname in Qualitaetsfarbe; unbekannte Qualitaet bleibt ungefaerbt
function Format.ItemName(name, quality)
	local color = Format.QUALITY_COLORS[quality]
	if not color then return name end
	return string.format("|cff%s%s|r", color, name)
end
