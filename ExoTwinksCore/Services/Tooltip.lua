-- Services/Tooltip.lua
-- Haengt "Besessen von ..."-Zeilen an Item-Tooltips (moderne
-- TooltipDataProcessor-API). Lebt in ExoTwinksCore: Tooltips muessen auch ohne
-- geoeffnetes ExoTwinksUI funktionieren.
--
-- Beispiel-Ausgabe:
--   exo-Twinks: 17 insgesamt
--     Anna: 12 (Taschen 10, Bank 2)
--     Borg: 5 (Taschen 5)
--     Kriegsmeute: 5

local _, Exo = ...

local Tooltip = {}
Exo.Services = Exo.Services or {}
Exo.Services.Tooltip = Tooltip

-- Zeilen-Komposition (rein, testbar) ------------------------------------------------

-- Reiter-Zusatz (1.11.1): " (Reiter 2)" bei einem Reiter,
-- " (Reiter 1: 3, Reiter 4: 2)" wenn das Item in mehreren Reitern liegt
function Tooltip.TabSuffix(tabs)
	if type(tabs) ~= "table" then return "" end
	local ids = {}
	for tab in pairs(tabs) do ids[#ids + 1] = tab end
	if #ids == 0 then return "" end
	table.sort(ids)
	if #ids == 1 then return string.format(" (Reiter %d)", ids[1]) end
	local parts = {}
	for _, tab in ipairs(ids) do
		parts[#parts + 1] = string.format("Reiter %d: %d", tab, tabs[tab])
	end
	return " (" .. table.concat(parts, ", ") .. ")"
end

local function sourceText(charEntry)
	local parts = {}
	if charEntry.bags > 0 then parts[#parts + 1] = "Taschen " .. charEntry.bags end
	if charEntry.bank > 0 then
		parts[#parts + 1] = "Bank " .. charEntry.bank
			.. Tooltip.TabSuffix(charEntry.bankTabs)
	end
	if (charEntry.auctions or 0) > 0 then parts[#parts + 1] = "AH " .. charEntry.auctions end
	if (charEntry.mail or 0) > 0 then parts[#parts + 1] = "Post " .. charEntry.mail end
	if (charEntry.equipped or 0) > 0 then
		parts[#parts + 1] = "Angelegt " .. charEntry.equipped
	end
	return table.concat(parts, ", ")
end

-- Gesamtmenge eines Chars ueber alle Quellen (1.12.0)
local function charTotal(charEntry)
	return charEntry.bags + charEntry.bank + (charEntry.auctions or 0)
		+ (charEntry.mail or 0) + (charEntry.equipped or 0)
end

function Tooltip.BuildLines(counts)
	if not counts or counts.total == 0 then return {} end

	local lines = {
		string.format("|cff69ccf0exo-Twinks:|r %d insgesamt", counts.total),
	}

	-- Charaktere nach Anzahl absteigend, dann Name
	local charRows = {}
	for charKey, charEntry in pairs(counts.chars) do
		local meta = Exo.API.GetCharacterInfo(charKey)
		charRows[#charRows + 1] = {
			name = (meta and meta.name ~= "" and meta.name) or charKey,
			count = charTotal(charEntry),
			entry = charEntry,
		}
	end
	table.sort(charRows, function(a, b)
		if a.count ~= b.count then return a.count > b.count end
		return a.name < b.name
	end)

	for _, row in ipairs(charRows) do
		lines[#lines + 1] = string.format("  %s: %d (%s)", row.name, row.count, sourceText(row.entry))
	end

	if counts.warband > 0 then
		lines[#lines + 1] = string.format("  Kriegsmeute: %d%s",
			counts.warband, Tooltip.TabSuffix(counts.warbandTabs))
	end

	-- Gildenbanken (0.16.0)
	local guildNames = {}
	for guildName in pairs(counts.guilds or {}) do
		guildNames[#guildNames + 1] = guildName
	end
	table.sort(guildNames)
	for _, guildName in ipairs(guildNames) do
		lines[#lines + 1] = string.format("  Gildenbank %s: %d",
			guildName, counts.guilds[guildName])
	end

	return lines
end

-- Tooltip-Hook ------------------------------------------------------------------------

local function onItemTooltip(tooltip, data)
	if not (data and data.id) then return end
	if not Exo.Store:IsReady() then return end

	local counts = Exo.API.GetItemCounts(data.id)
	if counts.total == 0 then return end

	for _, line in ipairs(Tooltip.BuildLines(counts)) do
		tooltip:AddLine(line)
	end
end

Exo.WowAPI.AddItemTooltipPostCall(onItemTooltip)
