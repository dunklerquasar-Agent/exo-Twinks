-- ExoTwinksUI/Tabs/Overview.lua
-- Reiter "Uebersicht": alles auf EINER Flaeche -- stapelbare Panels im
-- SavedInstances-Stil. Jedes Modul hat eine klickbare Kopfzeile zum
-- Ein-/Ausklappen; Sichtbarkeit und Reihenfolge der Module konfiguriert
-- der Designer-Tab. Alles wird accountweit gespeichert:
--   overview.order            Reihenfolge (kommagetrennte Modul-IDs)
--   overview.show.<id>        Modul sichtbar (Standard: true)
--   overview.collapsed.<id>   Modul eingeklappt (Standard: false)

local Tab = {
	id = "overview",
	label = "Uebersicht",
}
Exo.UI.OverviewTab = Tab

local VISIBLE_ROWS = 15
local ROW_HEIGHT = 20

Tab.MODULES = {
	{ id = "chars", label = "Charaktere" },
	{ id = "currencies", label = "Waehrungen" },
	{ id = "locks", label = "Raid-IDs" },
	{ id = "inventory", label = "Inventar" },
	{ id = "realms", label = "Gold pro Realm" },
	{ id = "keys", label = "Mythic+ Woche" },
	{ id = "bags", label = "Taschenplaetze" },
	{ id = "scan", label = "Scan-Status" },
	{ id = "tax", label = "Gildensteuer" },
	{ id = "auctions", label = "Auktionen" },
}

local MODULE_LABELS = {}
for _, m in ipairs(Tab.MODULES) do MODULE_LABELS[m.id] = m.label end

-- Modul-Verwaltung (Optionen; rein, testbar) -------------------------------------------

-- Aktuelle Reihenfolge: gespeicherte Liste, unbekannte IDs raus, fehlende hinten dran
function Tab.GetOrder()
	local saved = Exo.API.GetOption("overview.order", "")
	local order, seen = {}, {}
	for id in tostring(saved):gmatch("[^,]+") do
		if MODULE_LABELS[id] and not seen[id] then
			order[#order + 1] = id
			seen[id] = true
		end
	end
	for _, m in ipairs(Tab.MODULES) do
		if not seen[m.id] then order[#order + 1] = m.id end
	end
	return order
end

-- Modul eine Position nach vorn schieben (Designer: "Klick = nach vorn")
function Tab.MoveModuleForward(id)
	local order = Tab.GetOrder()
	for index = 2, #order do
		if order[index] == id then
			order[index], order[index - 1] = order[index - 1], order[index]
			break
		end
	end
	Exo.API.SetOption("overview.order", table.concat(order, ","))
	return order
end

function Tab.IsModuleShown(id)
	return Exo.API.GetOption("overview.show." .. id, true) ~= false
end

function Tab.ToggleModuleShown(id)
	Exo.API.SetOption("overview.show." .. id, not Tab.IsModuleShown(id))
end

function Tab.IsCollapsed(id)
	return Exo.API.GetOption("overview.collapsed." .. id, false) and true or false
end

-- Modul einen Platz nach hinten schieben (Alt-Klick auf die Kopfzeile)
function Tab.MoveModuleBackward(id)
	local order = Tab.GetOrder()
	for index, moduleID in ipairs(order) do
		if moduleID == id then
			if index < #order then
				order[index], order[index + 1] = order[index + 1], order[index]
				Exo.API.SetOption("overview.order", table.concat(order, ","))
			end
			return
		end
	end
end

function Tab.ToggleCollapsed(id)
	Exo.API.SetOption("overview.collapsed." .. id, not Tab.IsCollapsed(id))
end

-- Inhalts-Zeilen je Modul (rein, testbar) ----------------------------------------------

-- Alle Chars nach Itemlevel absteigend (wie die Charaktere-Matrix)
local function sortedSummaries()
	local list = {}
	for _, charKey in ipairs(Exo.API.GetCharacterKeys()) do
		local summary = Exo.API.GetCharacterSummary(charKey)
		if summary then list[#list + 1] = summary end
	end
	table.sort(list, function(a, b)
		if (a.ilvl or 0) ~= (b.ilvl or 0) then return (a.ilvl or 0) > (b.ilvl or 0) end
		return (a.name or "") < (b.name or "")
	end)
	return list
end

local function buildCharRows()
	local Format = Exo.UI.Format
	local rows = {}
	for _, s in ipairs(sortedSummaries()) do
		local mplus = Exo.API.GetMythicPlus(s.key)
		local parts = {
			Format.ClassName(s.name, s.classID),
			"Lv " .. (s.level or 0),
			"iLvl |cffffffff" .. math.floor(s.ilvl or 0) .. "|r",
			Format.Gold(s.gold or 0),
		}
		if mplus and (mplus.rating or 0) > 0 then
			parts[#parts + 1] = "M+ " .. mplus.rating -- Farb-Diaet (1.4.3)
		end
		if s.lastSeen and s.lastSeen > 0 then
			parts[#parts + 1] = "|cff808080" .. Format.TimeAgo(s.lastSeen) .. "|r"
		end
		-- Rollen-Tag (1.5.0): [Main]/[Bank]/[Crafter]/[Sammler]
		local Detail = Exo.UI.CharacterDetail
		local role = Detail and Detail.GetRole and Detail.GetRole(s.key)
		if role then
			parts[#parts + 1] = "|cff808080[" .. (Detail.ROLE_LABELS[role] or role) .. "]|r"
		end
		rows[#rows + 1] = { text = table.concat(parts, "   ") }
	end
	return rows
end

local function buildCurrencyRows()
	local rows = {}
	for _, s in ipairs(sortedSummaries()) do
		local currencies = Exo.API.GetCurrencies(s.key)
		local ids = {}
		for id in pairs(currencies) do ids[#ids + 1] = id end
		-- 1.17.0: aktuelle Erweiterung zuerst (Spiel-Reihenfolge der
		-- Kategorien), innerhalb der Kategorie alphabetisch
		table.sort(ids, function(a, b)
			local oa = currencies[a].catOrder or 9999
			local ob = currencies[b].catOrder or 9999
			if oa ~= ob then return oa < ob end
			return (currencies[a].name or "") < (currencies[b].name or "")
		end)
		local parts = {}
		for _, id in ipairs(ids) do
			if #parts >= 4 then break end
			local c = currencies[id]
			local text = (c.name or ("Waehrung " .. id)) .. " |cffffffff"
				.. Exo.UI.Format.GroupDigits(c.qty or 0) .. "|r"
			if (c.max or 0) > 0 then
				text = text .. "|cff808080/" .. Exo.UI.Format.GroupDigits(c.max) .. "|r"
			end
			parts[#parts + 1] = text
		end
		if #parts > 0 then
			rows[#rows + 1] = { text = Exo.UI.Format.ClassName(s.name, s.classID)
				.. ":  " .. table.concat(parts, " - ") }
		end
	end
	return rows
end

local function buildLockRows()
	local rows = {}
	for _, s in ipairs(sortedSummaries()) do
		local locks = Exo.API.GetRaidLocks(s.key)
		local parts = {}
		for _, lock in ipairs(locks) do
			local letter = (lock.difficultyName or "?"):sub(1, 1)
			parts[#parts + 1] = string.format("%s |cffffffff%s %d/%d|r",
				lock.name or "?", letter, lock.bossesKilled or 0, lock.bossesTotal or 0)
		end
		if #parts > 0 then
			rows[#rows + 1] = { text = Exo.UI.Format.ClassName(s.name, s.classID)
				.. ":  " .. table.concat(parts, " - ") }
		end
	end
	return rows
end

local function buildInventoryRows()
	local Format = Exo.UI.Format
	local rows = {}
	for _, s in ipairs(sortedSummaries()) do
		local items, distinct, bags, bank = Exo.API.GetCharacterItems(s.key), 0, 0, 0
		for _, item in ipairs(items) do
			distinct = distinct + 1
			bags = bags + (item.bags or 0)
			bank = bank + (item.bank or 0)
		end
		if distinct > 0 then
			rows[#rows + 1] = { text = string.format(
				"%s:  %s  |cff808080(Taschen %s, Bank %s Stueck)|r",
				Format.ClassName(s.name, s.classID),
				Format.Count(distinct, "Item", "Items"),
				Format.GroupDigits(bags), Format.GroupDigits(bank)) }
		end
	end
	local warband, pieces = Exo.API.GetWarbandItems(), 0
	for _, item in ipairs(warband) do pieces = pieces + (item.total or 0) end
	if #warband > 0 then
		rows[#rows + 1] = { text = string.format(
			"|cff00ccffKriegsmeute|r:  %s, %s Stueck",
			Format.Count(#warband, "Item", "Items"), Format.GroupDigits(pieces)) }
	end
	return rows
end

-- Gold pro Realm (0.17.0)
local function buildRealmRows()
	local Format = Exo.UI.Format
	local rows = {}
	local total = 0
	for _, entry in ipairs(Exo.API.GetGoldByRealm()) do
		total = total + entry.gold
		rows[#rows + 1] = { text = string.format("%s:  %s  |cff808080(%s)|r",
			entry.realm, Format.Gold(entry.gold),
			Format.Count(entry.chars, "Charakter", "Charaktere")) }
	end
	if #rows > 1 then
		rows[#rows + 1] = { text = "|cffffd700Gesamt|r:  " .. Format.Gold(total) }
	end
	return rows
end

-- Mythic+ Woche (1.0.0): aktuelle Affixe + Schluesselsteine aller Twinks
local function buildKeysRows()
	local Format = Exo.UI.Format
	local rows = {}
	local affixes = Exo.WowAPI.GetCurrentAffixes()
	if #affixes > 0 then
		rows[#rows + 1] = { text = "|cffffd700Affixe|r:  " .. table.concat(affixes, ", ") }
	end
	for _, keystone in ipairs(Exo.API.GetKeystones()) do
		rows[#rows + 1] = { text = string.format("%s:  %s |cffffd700+%d|r",
			Format.ClassName(keystone.name, keystone.classID),
			keystone.mapName, keystone.level) }
	end
	return rows
end

-- Taschenplaetze (1.1.0): "wer braucht groessere Taschen?" -- wenigste freie zuerst
local function buildBagRows()
	local Format = Exo.UI.Format
	local entries = {}
	for _, s in ipairs(sortedSummaries()) do
		local space = Exo.API.GetBagSpace(s.key)
		if space and (space.bagsSize > 0 or space.bankSize > 0) then
			entries[#entries + 1] = { summary = s, space = space }
		end
	end
	table.sort(entries, function(a, b)
		return a.space.bagsFree < b.space.bagsFree
	end)

	local rows = {}
	for _, entry in ipairs(entries) do
		local space = entry.space
		local kind = "muted"
		if space.bagsFree < 5 then kind = "negative"
		elseif space.bagsFree < 15 then kind = "warning" end
		local bagsText = Exo.UI.Theme.Color(
			string.format("Taschen %d/%d frei", space.bagsFree, space.bagsSize), kind)
		local bankText = space.bankSize > 0
			and string.format("  -  Bank %d/%d frei", space.bankFree, space.bankSize)
			or "  -  |cff808080Bank nicht gescannt|r"
		-- Upgrade-Hinweis (1.5.0): kleine Taschen anmeckern
		local upgradeText = ""
		if space.smallestBag and space.smallestBag < 20 then
			upgradeText = "  -  " .. Exo.UI.Theme.Color(
				string.format("kleinste Tasche: %d Plaetze", space.smallestBag),
				"warning")
		end
		rows[#rows + 1] = { text = string.format("%s:  %s%s%s",
			Format.ClassName(entry.summary.name, entry.summary.classID),
			bagsText, bankText, upgradeText) }
	end

	-- Kriegsmeuten-Bank (1.2.1)
	local warband = Exo.API.GetWarbandSpace()
	if warband and warband.size > 0 then
		rows[#rows + 1] = { text = string.format(
			"|cff00ccffKriegsmeute|r:  %d/%d frei", warband.free, warband.size) }
	end
	return rows
end

-- Scan-Status (1.1.0): welche manuellen Scans fehlen noch?
local function buildScanRows()
	local Format = Exo.UI.Format
	local rows = {}
	for _, s in ipairs(sortedSummaries()) do
		local status = Exo.API.GetScanStatus(s.key)
		if status then
			local missing = {}
			if not status.bank then missing[#missing + 1] = "Bank besuchen" end
			if not status.mails then missing[#missing + 1] = "Briefkasten oeffnen" end
			if #status.missingRecipes > 0 then
				missing[#missing + 1] = "Rezepte erfassen ("
					.. table.concat(status.missingRecipes, ", ") .. ")"
			end
			if #missing > 0 then
				rows[#rows + 1] = {
					text = string.format("%s:  %s",
						Format.ClassName(s.name, s.classID),
						Exo.UI.Theme.Color(table.concat(missing, ", "), "warning")),
					-- Klick auf die Zeile gibt den Hinweis in den Chat (1.1.1)
					hint = string.format("%s - %s", s.name,
						table.concat(missing, ", ")),
				}
			end
		end
	end
	if #rows == 0 then
		rows[#rows + 1] = { text = Exo.UI.Theme.Color(
			"Alle Scans vorhanden - nichts zu tun.", "positive") }
	end
	return rows
end

-- Gildensteuer (1.2.0): offen je Gilde/Char; Shift-Klick auf eine
-- Char-Zeile setzt dessen Steuer auf 0.
local function buildTaxRows()
	local Format = Exo.UI.Format
	local Theme = Exo.UI.Theme
	local rows = {}

	if not (Exo.Collectors.GuildTax and Exo.Collectors.GuildTax.IsEnabled()) then
		rows[#rows + 1] = { text =
			"|cff808080Gildensteuer ist aus. Aktivieren: Reiter Designer.|r" }
		return rows
	end

	local report = Exo.API.GetGuildTaxReport()
	for _, guild in ipairs(report.guilds) do
		rows[#rows + 1] = { text = string.format(
			"|cffffd700%s|r  (%g%%):  %s offen",
			guild.guild, guild.rate, Format.Gold(guild.owed)) }
		if #guild.chars == 0 then
			rows[#rows + 1] = { text = "    |cff808080Noch kein Twink dieser "
				.. "Gilde eingeloggt - Gilde wird beim Login erkannt.|r" }
		end
		for _, char in ipairs(guild.chars) do
			if char.owed > 0 or char.income > 0 then
				rows[#rows + 1] = {
					text = string.format("    %s:  %s offen  |cff808080(von %s Einnahmen)|r",
						Format.ClassName(char.name, char.classID),
						char.owed > 0 and Theme.Color(Format.Gold(char.owed), "warning")
							or Format.Gold(0),
						Format.Gold(char.income)),
					taxKey = char.charKey,
					hint = char.name .. " - Shift-Klick setzt die Steuer auf 0.",
				}
			end
		end
	end

	if #rows == 0 then
		rows[#rows + 1] = { text =
			"|cff808080Kein Steuersatz gesetzt: Designer > Steuersaetze (Klick).|r" }
	elseif report.totalOwed > 0 then
		rows[#rows + 1] = { text = "|cffffd700Gesamt offen|r:  "
			.. Format.Gold(report.totalOwed) }
	end
	return rows
end

-- Auktionen (1.3.0): je Char aktive Auktionen, Buyout-Summe, Verkaeufe,
-- naechster Ablauf (Band) farbcodiert.
local AUCTION_BAND_LABEL = {
	[0] = "unter 30 Min", [1] = "unter 2 Std",
	[2] = "unter 12 Std", [3] = "unter 48 Std",
}

local function buildAuctionRows()
	local Format = Exo.UI.Format
	local Theme = Exo.UI.Theme
	local rows = {}
	local summary = Exo.API.GetAuctionSummary()
	for _, char in ipairs(summary.chars) do
		local parts = {
			Format.ClassName(char.name, char.classID) .. ":",
			Format.Count(char.count, "Auktion", "Auktionen"),
		}
		if char.buyoutTotal > 0 then
			parts[#parts + 1] = "Buyout " .. Format.Gold(char.buyoutTotal)
		end
		if char.soldCount > 0 then
			parts[#parts + 1] = Theme.Color(char.soldCount .. " verkauft", "positive")
		end
		if char.soonestBand then
			local label = "laeuft " .. (AUCTION_BAND_LABEL[char.soonestBand] or "?") .. " ab"
			local kind = char.soonestBand <= 0 and "negative"
				or (char.soonestBand == 1 and "warning" or "muted")
			parts[#parts + 1] = Theme.Color(label, kind)
		end
		rows[#rows + 1] = { text = table.concat(parts, "  ") }
	end
	if #rows == 0 then
		rows[#rows + 1] = { text =
			"|cff808080Keine Auktionsdaten. Auktionshaus einmal oeffnen.|r" }
	elseif summary.totalCount > 0 then
		rows[#rows + 1] = { text = string.format(
			"|cffffd700Gesamt|r:  %s, Buyout %s",
			Format.Count(summary.totalCount, "Auktion", "Auktionen"),
			Format.Gold(summary.totalBuyout)) }
	end
	return rows
end

local BUILDERS = {
	chars = buildCharRows,
	currencies = buildCurrencyRows,
	locks = buildLockRows,
	inventory = buildInventoryRows,
	realms = buildRealmRows,
	keys = buildKeysRows,
	bags = buildBagRows,
	scan = buildScanRows,
	tax = buildTaxRows,
	auctions = buildAuctionRows,
}

function Tab.BuildModuleRows(id)
	local builder = BUILDERS[id]
	return builder and builder() or {}
end

-- Gesamte Zeilenliste: Kopfzeile je Modul + Inhalt (wenn ausgeklappt)
function Tab.BuildRows()
	local rows = {}
	for _, id in ipairs(Tab.GetOrder()) do
		if Tab.IsModuleShown(id) then
			local collapsed = Tab.IsCollapsed(id)
			rows[#rows + 1] = {
				header = true, module = id,
				label = MODULE_LABELS[id], collapsed = collapsed,
			}
			if not collapsed then
				local content = Tab.BuildModuleRows(id)
				if #content == 0 then
					content = { { text = "|cff808080Keine Daten.|r" } }
				end
				for _, row in ipairs(content) do rows[#rows + 1] = row end
			end
		end
	end
	return rows
end

-- Aufbau -------------------------------------------------------------------------------

local function buildUI(self, content)
	local Widgets = Exo.UI.Widgets

	local host = Exo.WowAPI.CreateFrame("Frame", nil, content)
	host:SetPoint("TOPLEFT", 0, -4)
	host:SetPoint("BOTTOMRIGHT", 0, 20)

	self._scroller = Exo.UI.VirtualScroll.New{
		parent = host,
		visibleRows = VISIBLE_ROWS,
		rowHeight = ROW_HEIGHT,
		createRow = function(parent, rowIndex)
			local row = Exo.WowAPI.CreateFrame("Frame", nil, parent)
			row:SetHeight(ROW_HEIGHT)
			row:SetPoint("TOPLEFT", 0, -((rowIndex - 1) * ROW_HEIGHT))
			row:SetPoint("TOPRIGHT", 0, -((rowIndex - 1) * ROW_HEIGHT))
			row.bg = row:CreateTexture(nil, "BACKGROUND")
			row.bg:SetAllPoints(row)
			row.bg:SetColorTexture(1, 1, 1, 0)
			row.text = Widgets.Label(row, "")
			row.text:SetPoint("LEFT", 4, 0)
			row.text:SetPoint("RIGHT", -4, 0)
			row.text:SetWordWrap(false)
			-- Kopfzeilen sind klickbar (ein-/ausklappen)
			row:EnableMouse(true)
			Exo.UI.Widgets.AddRowHighlight(row)
			row:SetScript("OnMouseDown", function(frame)
				if frame._module then
					-- Shift-Klick: nach vorn, Alt-Klick: nach hinten, Klick: auf/zu
					if Exo.WowAPI.IsShiftDown() then
						Tab.MoveModuleForward(frame._module)
					elseif Exo.WowAPI.IsAltDown() then
						Tab.MoveModuleBackward(frame._module)
					else
						Tab.ToggleCollapsed(frame._module)
					end
					Exo.UI:RefreshActiveTab()
				elseif frame._taxKey and Exo.WowAPI.IsShiftDown() then
					-- Gildensteuer (1.2.0): Shift-Klick setzt den Char auf 0
					if Exo.Collectors.GuildTax then
						Exo.Collectors.GuildTax.ResetChar(frame._taxKey)
						print("|cff69ccf0exo-Twinks:|r Gildensteuer zurueckgesetzt.")
						Exo.UI:RefreshActiveTab()
					end
				elseif frame._hint then
					-- Scan-Status (1.1.1): Klick gibt den Hinweis in den Chat
					print("|cff69ccf0exo-Twinks:|r " .. frame._hint)
				end
			end)
			return row
		end,
		updateRow = function(row, item, absoluteIndex)
			-- Hinweis: bewusst `false` statt nil -- der Test-Mock liefert fuer
			-- unbekannte Frame-Felder Auto-Stubs; false ist in beiden Welten falsy.
			if item.header then
				row._module = item.module
				row._hint = false
				row._taxKey = false
				row.bg:SetColorTexture(1, 1, 1, 0.09)
				local marker = item.collapsed and "[+]" or "[-]"
				row.text:SetText(string.format("|cff%s%s  %s|r",
					Exo.UI.Widgets.COLORS.accentHex, marker, item.label))
			else
				row._module = false
				row._hint = item.hint or false
				row._taxKey = item.taxKey or false
				row.bg:SetColorTexture(1, 1, 1, (absoluteIndex % 2 == 0) and 0.04 or 0)
				row.text:SetText(item.text or "")
			end
		end,
	}

	self._footer = Widgets.Label(content,
		"Kopfzeile: Klick = auf/zu, Shift-Klick = nach vorn, Alt-Klick = nach "
		.. "hinten. Sichtbarkeit: Reiter Designer.",
		"GameFontDisableSmall")
	self._footer:SetPoint("BOTTOMLEFT", 4, 2)
end

-- Rendern ------------------------------------------------------------------------------

-- Erststart (1.4.3): beim allerersten Oeffnen nur die wichtigsten Module
-- aufgeklappt (Charaktere, Mythic+ Woche, Scan-Status) -- keine Textwand.
-- Greift NUR, wenn der Nutzer noch nie etwas an der Uebersicht verstellt hat.
local FIRSTRUN_EXPANDED = { chars = true, keys = true, scan = true }

function Tab.ApplyFirstRunDefaults()
	if Exo.API.GetOption("overview.initialized", false) then return end
	Exo.API.SetOption("overview.initialized", true)
	if Exo.API.GetOption("overview.order", "") ~= "" then return end -- schon benutzt
	for _, m in ipairs(Tab.MODULES) do
		if not FIRSTRUN_EXPANDED[m.id]
			and Exo.API.GetOption("overview.collapsed." .. m.id) == nil then
			Exo.API.SetOption("overview.collapsed." .. m.id, true)
		end
	end
end

function Tab:Render(content)
	Tab.ApplyFirstRunDefaults()
	if self._content ~= content then
		self._content = content
		buildUI(self, content)
	end
	self._scroller:SetData(Tab.BuildRows())
end

-- Test-Helfer
function Tab._GetScroller() return Tab._scroller end

Exo.UI:RegisterTab(Tab)
