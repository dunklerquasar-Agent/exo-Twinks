-- ExoTwinksUI/Tabs/Search.lua
-- Reiter "Suche": accountweite Item-Suche ueber alle Taschen, Baenke und die
-- Kriegsmeutenbank. Live-Suche mit Entprellung beim Tippen.
--
-- Suchlogik:
--   * numerische Eingabe  -> exakte Item-ID
--   * Text (>= 2 Zeichen) -> Namens-Teilstring, Gross-/Kleinschreibung egal
-- Ergebnis sortiert nach Gesamtanzahl absteigend.

local Tab = {
	id = "search",
	label = "Suche",
	query = "",
}
Exo.UI.SearchTab = Tab

local MIN_QUERY_LEN = 2
local MAX_RESULTS = 300 -- Schutz bei sehr grossen Accounts (1.1.0)
local QUERY_DEBOUNCE = 0.3
local VISIBLE_ROWS = 13
local ROW_HEIGHT = 20

-- AH-aehnliche Filter (0.13.0): Mindest-Qualitaet, Typ, Standort, Realm.
-- Zyklische Buttons; Index 1 = "Alle" (kein Filter).
Tab.QUALITY_STEPS = {
	{ min = 0, label = "Qualitaet: Alle" },
	{ min = 2, label = "Qualitaet: Gruen+" },
	{ min = 3, label = "Qualitaet: Blau+" },
	{ min = 4, label = "Qualitaet: Epic+" },
}
Tab.CLASS_STEPS = {
	{ id = nil, label = "Typ: Alle" },
	{ id = 2, label = "Typ: Waffe" },
	{ id = 4, label = "Typ: Ruestung" },
	{ id = 0, label = "Typ: Verbrauchbar" },
	{ id = 7, label = "Typ: Handwerk" },
}
Tab.LOCATION_STEPS = {
	{ id = "all", label = "Ort: Alle" },
	{ id = "bags", label = "Ort: Taschen" },
	{ id = "bank", label = "Ort: Bank" },
	{ id = "warband", label = "Ort: Kriegsmeute" },
	{ id = "guild", label = "Ort: Gildenbank" },
	{ id = "auctions", label = "Ort: Auktionshaus" },
	{ id = "mail", label = "Ort: Post" },
	{ id = "equipped", label = "Ort: Angelegt" },
}

Tab.ROLE_STEPS = {
	{ id = nil, label = "Rolle: Alle" },
	{ id = "main", label = "Rolle: Main" },
	{ id = "bank", label = "Rolle: Bank" },
	{ id = "crafter", label = "Rolle: Crafter" },
	{ id = "gatherer", label = "Rolle: Sammler" },
}

Tab.filterIndex = { quality = 1, class = 1, location = 1, role = 1 }
Tab.realmOnly = false

function Tab.ResetFilters()
	Tab.filterIndex = { quality = 1, class = 1, location = 1, role = 1 }
	Tab.realmOnly = false
end

-- Aktive Filterwerte aus den Indizes ableiten
function Tab.GetFilters()
	return {
		quality = Tab.QUALITY_STEPS[Tab.filterIndex.quality].min,
		classID = Tab.CLASS_STEPS[Tab.filterIndex.class].id,
		location = Tab.LOCATION_STEPS[Tab.filterIndex.location].id,
		role = Tab.ROLE_STEPS[Tab.filterIndex.role].id,
		realmOnly = Tab.realmOnly,
	}
end

-- Realm des eingeloggten Charakters (fuer "Realm: Aktueller")
function Tab.GetCurrentRealm()
	for _, key in ipairs(Exo.API.GetCharacterKeys()) do
		local summary = Exo.API.GetCharacterSummary(key)
		if summary and summary.isCurrent then return summary.realm end
	end
	return nil
end

-- Prueft ein Suchergebnis gegen die Filter (rein, testbar)
function Tab.MatchesFilters(result, filters, currentRealm)
	if (filters.quality or 0) > 0 then
		local quality = Exo.WowAPI.GetItemQuality(result.itemID)
		if not quality or quality < filters.quality then return false end
	end
	if filters.classID ~= nil then
		local classID = Exo.WowAPI.GetItemClass(result.itemID)
		if classID ~= filters.classID then return false end
	end
	local location = filters.location or "all"
	if location == "warband" then
		if (result.warband or 0) == 0 then return false end
	elseif location == "guild" then
		local found = false
		for _, count in pairs(result.guilds or {}) do
			if count > 0 then found = true break end
		end
		if not found then return false end
	elseif location == "bags" or location == "bank" or location == "auctions"
		or location == "mail" or location == "equipped" then
		local found = false
		for _, entry in pairs(result.chars or {}) do
			if (entry[location] or 0) > 0 then found = true break end
		end
		if not found then return false end
	end
	if filters.role then
		local Detail = Exo.UI.CharacterDetail
		local found = false
		for charKey, entry in pairs(result.chars or {}) do
			if (entry.bags or 0) + (entry.bank or 0) + (entry.auctions or 0)
				+ (entry.mail or 0) + (entry.equipped or 0) > 0
				and Detail and Detail.GetRole(charKey) == filters.role then
				found = true
				break
			end
		end
		if not found then return false end
	end
	if filters.realmOnly then
		local found = false
		for charKey, entry in pairs(result.chars or {}) do
			if (entry.bags or 0) + (entry.bank or 0) + (entry.mail or 0)
				+ (entry.equipped or 0) > 0 then
				local meta = Exo.API.GetCharacterInfo(charKey)
				if meta and meta.realm == currentRealm then found = true break end
			end
		end
		if not found then return false end
	end
	return true
end

function Tab.ApplyFilters(results, filters, currentRealm)
	filters = filters or Tab.GetFilters()
	currentRealm = currentRealm or Tab.GetCurrentRealm()
	local filtered = {}
	for _, result in ipairs(results) do
		if Tab.MatchesFilters(result, filters, currentRealm) then
			filtered[#filtered + 1] = result
		end
	end
	return filtered
end

-- Suchlogik (rein, testbar) -----------------------------------------------------------

function Tab.GatherResults(query)
	query = (query or ""):gsub("^%s+", ""):gsub("%s+$", "")

	local numericID = tonumber(query)
	if not numericID and #query < MIN_QUERY_LEN then
		return {}
	end

	local matcher
	if numericID then
		matcher = function(itemID) return itemID == numericID end
	else
		local needle = query:lower()
		matcher = function(itemID)
			local name = Exo.WowAPI.GetItemName(itemID)
			return name ~= nil and name:lower():find(needle, 1, true) ~= nil
		end
	end

	local results = Exo.API.SearchItems(matcher)
	for _, result in ipairs(results) do
		result.name = Exo.WowAPI.GetItemName(result.itemID) or ("Item " .. result.itemID)
	end

	table.sort(results, function(a, b)
		if a.total ~= b.total then return a.total > b.total end
		return a.name < b.name
	end)
	return results
end

-- Kompakte Fundort-Angabe: "Anna 12 (Taschen 10, Bank 2), Kriegsmeute 5"
function Tab.BuildBreakdown(counts)
	local parts = {}

	local charRows = {}
	for charKey, entry in pairs(counts.chars) do
		local meta = Exo.API.GetCharacterInfo(charKey)
		local plainName = (meta and meta.name ~= "" and meta.name) or charKey
		charRows[#charRows + 1] = {
			plain = plainName,
			-- Klassenfarbe, wenn die Klasse bekannt ist (sonst ungefaerbt)
			name = Exo.UI.Format.ClassName(plainName, meta and meta.classID),
			entry = entry,
		}
	end
	-- Gesamtmenge eines Chars ueber alle Quellen (1.12.0)
	local function charTotal(entry)
		return entry.bags + entry.bank + (entry.auctions or 0)
			+ (entry.mail or 0) + (entry.equipped or 0)
	end
	table.sort(charRows, function(a, b)
		local ca, cb = charTotal(a.entry), charTotal(b.entry)
		if ca ~= cb then return ca > cb end
		return a.plain < b.plain
	end)

	for _, row in ipairs(charRows) do
		local sources = {}
		if row.entry.bags > 0 then sources[#sources + 1] = "Taschen " .. row.entry.bags end
		if row.entry.bank > 0 then sources[#sources + 1] = "Bank " .. row.entry.bank end
		if (row.entry.auctions or 0) > 0 then
			sources[#sources + 1] = "AH " .. row.entry.auctions
		end
		if (row.entry.mail or 0) > 0 then
			sources[#sources + 1] = "Post " .. row.entry.mail
		end
		if (row.entry.equipped or 0) > 0 then
			sources[#sources + 1] = "Angelegt " .. row.entry.equipped
		end
		parts[#parts + 1] = string.format("%s %d (%s)", row.name,
			charTotal(row.entry), table.concat(sources, ", "))
	end

	if counts.warband > 0 then
		parts[#parts + 1] = "Kriegsmeute " .. counts.warband
	end

	-- Gildenbanken (0.16.0)
	local guildNames = {}
	for guildName in pairs(counts.guilds or {}) do
		guildNames[#guildNames + 1] = guildName
	end
	table.sort(guildNames)
	for _, guildName in ipairs(guildNames) do
		parts[#parts + 1] = string.format("Gildenbank %s %d",
			guildName, counts.guilds[guildName])
	end

	return table.concat(parts, ", ")
end

-- Interaktion ---------------------------------------------------------------------------

-- Zyklische Filter-Buttons: naechster Schritt + Button-Text + neu rendern
function Tab:CycleFilter(which, steps)
	self.filterIndex[which] = self.filterIndex[which] % #steps + 1
	self:RefreshFilterButtons()
	if self._content then self:Render(self._content) end
end

function Tab:ToggleRealmOnly()
	self.realmOnly = not self.realmOnly
	self:RefreshFilterButtons()
	if self._content then self:Render(self._content) end
end

function Tab:RefreshFilterButtons()
	local buttons = self._filterButtons
	if not buttons then return end
	buttons.quality:SetText(Tab.QUALITY_STEPS[self.filterIndex.quality].label)
	buttons.quality:SetSelected(self.filterIndex.quality > 1)
	buttons.class:SetText(Tab.CLASS_STEPS[self.filterIndex.class].label)
	buttons.class:SetSelected(self.filterIndex.class > 1)
	buttons.location:SetText(Tab.LOCATION_STEPS[self.filterIndex.location].label)
	buttons.location:SetSelected(self.filterIndex.location > 1)
	buttons.role:SetText(Tab.ROLE_STEPS[self.filterIndex.role].label)
	buttons.role:SetSelected(self.filterIndex.role > 1)
	buttons.realm:SetText(self.realmOnly and "Realm: Aktueller" or "Realm: Alle")
	buttons.realm:SetSelected(self.realmOnly)
end

function Tab:OnQueryChanged(text)
	self.query = text or ""
	Exo.Scheduler:Debounce("search-query", QUERY_DEBOUNCE, function()
		if self._content then
			self:Render(self._content)
		end
	end)
end

-- Aufbau -----------------------------------------------------------------------------------

local function buildUI(self, content)
	local W = Exo.WowAPI
	local Widgets = Exo.UI.Widgets

	-- Einheitlicher Leerzustand (1.19.0) -- Flaeche der Ergebnis-Liste
	Exo.UI.EmptyState.Attach(content, { top = 72, bottom = 20 })

	-- Suchfeld
	local label = Widgets.Label(content, "Suche:", "GameFontNormal")
	label:SetPoint("TOPLEFT", 4, -4)

	local editBox = W.CreateFrame("EditBox", nil, content, "InputBoxTemplate")
	editBox:SetSize(220, 20)
	editBox:SetPoint("TOPLEFT", 60, 0)
	editBox:SetAutoFocus(false)
	editBox:SetScript("OnTextChanged", function(box)
		Tab:OnQueryChanged(box:GetText())
	end)
	editBox:SetScript("OnEnterPressed", function(box)
		if box.ClearFocus then box:ClearFocus() end
	end)
	editBox:SetScript("OnEscapePressed", function(box)
		box:SetText("")
		if box.ClearFocus then box:ClearFocus() end
	end)
	self._editBox = editBox

	-- Filterleiste (AH-aehnlich): Qualitaet | Typ | Ort | Realm
	self._filterButtons = {}
	local filterDefs = {
		{ key = "quality", width = 118, onClick = function()
			Tab:CycleFilter("quality", Tab.QUALITY_STEPS) end },
		{ key = "class", width = 140, onClick = function()
			Tab:CycleFilter("class", Tab.CLASS_STEPS) end },
		{ key = "location", width = 148, onClick = function()
			Tab:CycleFilter("location", Tab.LOCATION_STEPS) end },
		{ key = "role", width = 118, onClick = function()
			Tab:CycleFilter("role", Tab.ROLE_STEPS) end },
		{ key = "realm", width = 104, onClick = function() Tab:ToggleRealmOnly() end },
	}
	local x = 4
	for _, def in ipairs(filterDefs) do
		local btn = Widgets.Button(content, "", def.width, 20, def.onClick)
		btn:SetPoint("TOPLEFT", x, -26)
		self._filterButtons[def.key] = btn
		x = x + def.width + 6
	end
	self:RefreshFilterButtons()

	-- Spaltenueberschriften (deutsche Itemnamen sind lang -> Name bekommt viel Platz)
	local COL_NAME_X, COL_NAME_W = 4, 296
	local COL_COUNT_X = 306
	local COL_WHERE_X, COL_WHERE_W = 360, 344

	local headName = Widgets.Label(content, "Item", "GameFontNormal")
	headName:SetPoint("TOPLEFT", COL_NAME_X, -54)
	local headCount = Widgets.Label(content, "Anzahl", "GameFontNormal")
	headCount:SetPoint("TOPLEFT", COL_COUNT_X, -54)
	local headWhere = Widgets.Label(content, "Fundorte", "GameFontNormal")
	headWhere:SetPoint("TOPLEFT", COL_WHERE_X, -54)

	-- Ergebnisliste (virtualisiert): Item | Anzahl | Fundorte
	local listHost = W.CreateFrame("Frame", nil, content)
	listHost:SetPoint("TOPLEFT", 0, -72)
	listHost:SetPoint("BOTTOMRIGHT", 0, 20)

	self._scroller = Exo.UI.VirtualScroll.New{
		parent = listHost,
		visibleRows = VISIBLE_ROWS,
		rowHeight = ROW_HEIGHT,
		createRow = function(parent, rowIndex)
			local row = W.CreateFrame("Frame", nil, parent)
			row:SetSize(700, ROW_HEIGHT)
			row:SetPoint("TOPLEFT", 0, -((rowIndex - 1) * ROW_HEIGHT))
			row.bg = row:CreateTexture(nil, "BACKGROUND")
			row.bg:SetAllPoints(row)
			row.bg:SetColorTexture(1, 1, 1, 1)
			-- Item-Icon (1.4.3)
			row.icon = row:CreateTexture(nil, "ARTWORK")
			row.icon:SetSize(16, 16)
			row.icon:SetPoint("LEFT", COL_NAME_X, 0)
			row.nameCell = Widgets.Label(row, "")
			row.nameCell:SetPoint("LEFT", COL_NAME_X + 20, 0)
			row.nameCell:SetWidth(COL_NAME_W - 20) -- kappt Ueberlaenge statt zu ueberlappen
			row.nameCell:SetWordWrap(false)
			row.countCell = Widgets.Label(row, "")
			row.countCell:SetPoint("LEFT", COL_COUNT_X, 0)
			row.whereCell = Widgets.Label(row, "")
			row.whereCell:SetPoint("LEFT", COL_WHERE_X, 0)
			row.whereCell:SetWidth(COL_WHERE_W)
			row.whereCell:SetWordWrap(false)
			-- Shift-Klick: Itemlink in den Chat (0.16.0)
			row:EnableMouse(true)
			Widgets.AddRowHighlight(row)
			row:SetScript("OnMouseDown", function()
				if row._itemID and Exo.WowAPI.IsShiftDown() then
					Exo.WowAPI.InsertItemLink(row._itemID)
				end
			end)
			return row
		end,
		updateRow = function(row, result, absoluteIndex)
			row._itemID = result.itemID
			row.icon:SetTexture(Exo.WowAPI.GetItemIcon(result.itemID))
			row.bg:SetColorTexture(1, 1, 1, (absoluteIndex % 2 == 0) and 0.04 or 0)
			row.nameCell:SetText(string.format("%s |cff808080(%d)|r",
				Exo.UI.Format.ItemName(result.name,
					Exo.WowAPI.GetItemQuality(result.itemID)), result.itemID))
			row.countCell:SetText(tostring(result.total))
			row.whereCell:SetText(Tab.BuildBreakdown(result))
		end,
	}

	-- Statuszeile
	self._footer = Widgets.Label(content, "", "GameFontNormal")
	self._footer:SetPoint("BOTTOMLEFT", 4, 2)
end

-- Rendern -------------------------------------------------------------------------------------

function Tab:Render(content)
	if self._content ~= content then
		self._content = content
		buildUI(self, content)
	end

	local results = Tab.ApplyFilters(Tab.GatherResults(self.query))

	-- Ergebnis-Limit (1.1.0): UI bleibt auch bei 1000+ Treffern fluessig
	local shown = results
	if #results > MAX_RESULTS then
		shown = {}
		for i = 1, MAX_RESULTS do shown[i] = results[i] end
	end
	self._scroller:SetData(shown)

	local trimmed = self.query:gsub("^%s+", ""):gsub("%s+$", "")
	local ES = Exo.UI.EmptyState
	if trimmed == "" or (#trimmed < MIN_QUERY_LEN and not tonumber(trimmed)) then
		-- Eingabe-Zustand (kein Leerzustand) -- Liste bleibt leer
		ES.Hide(content)
		self._footer:SetText("Mindestens " .. MIN_QUERY_LEN .. " Zeichen eingeben (oder eine Item-ID).")
	elseif #results == 0 then
		-- Einheitlicher Leerzustand (1.19.0)
		ES.Show(content, "Keine Treffer.", "Suchbegriff oder Filter anpassen.")
		self._footer:SetText("")
	else
		ES.Hide(content)
		local pieces = 0
		for _, result in ipairs(results) do
			pieces = pieces + result.total
		end
		local Format = Exo.UI.Format
		local text = string.format("%s, %s Stueck gesamt",
			Format.Count(#results, "Treffer", "Treffer"), Format.GroupDigits(pieces))
		if #results > MAX_RESULTS then
			text = text .. string.format("  |cffffd700(zeige die ersten %d - Filter nutzen)|r",
				MAX_RESULTS)
		end
		self._footer:SetText(text)
	end
end

-- Test-Helfer
function Tab._GetScroller() return Tab._scroller end
function Tab._GetFooter() return Tab._footer end
function Tab._GetFilterButtons() return Tab._filterButtons end

-- Seit 0.13.0 KEIN eigener Reiter mehr: die Suche lebt als Modus im
-- Inventar-Tab (Exo.UI.InventoryTab bettet SearchTab:Render ein).
