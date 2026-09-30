-- ExoTwinksUI/Tabs/Inventory.lua
-- Reiter "Inventar": Item-Uebersicht eines einzelnen Charakters (Taschen + Bank,
-- aggregiert pro Item), der Kriegsmeutenbank oder einer Gildenbank.
-- Charakter-Auswahl per Aufklapp-Liste am Ziel-Button (1.4.1),
-- Spalten sortierbar per Header-Klick.
-- Datenlogik (GetTargets/GatherItems/SortItems) ist rein und testbar.

local Tab = {
	id = "inventory",
	label = "Inventar",
	sortBy = "total",
	sortDesc = true,
	targetIndex = 1,
	mode = "browse", -- "browse" (Bestand) | "search" (eingebettete Suche)
	viewMode = "list", -- "list" | "icons"
	groupModeIndex = 1,
}
Exo.UI.InventoryTab = Tab

local VISIBLE_ROWS = 13
local ROW_HEIGHT = 20
local WARBAND_KEY = "__warband"
local GUILD_PREFIX = "__guild:" -- Browse-Ziel je Gildenbank (1.2.1)

-- Symbolansicht
local ICON_SIZE = 32
local ICON_GAP = 4
local ICON_ROW_HEIGHT = 38
local ICON_VISIBLE_ROWS = 7
Tab.ICONS_PER_ROW = 18

-- Spalten ------------------------------------------------------------------------

Tab.COLUMNS = {
	{ id = "name", label = "Item", width = 300,
	  get = function(r) return r.name end,
	  text = function(r) return string.format("%s |cff808080(%d)|r",
			Exo.UI.Format.ItemName(r.name, r.quality), r.itemID) end },
	{ id = "total", label = "Anzahl", width = 60,
	  get = function(r) return r.total end },
	{ id = "bags", label = "Taschen", width = 65,
	  get = function(r) return r.bags end,
	  text = function(r) return r.bags > 0 and tostring(r.bags) or "-" end },
	{ id = "bank", label = "Bank", width = 60,
	  get = function(r) return r.bank end,
	  text = function(r) return r.bank > 0 and tostring(r.bank) or "-" end },
}

local function columnById(colId)
	for _, col in ipairs(Tab.COLUMNS) do
		if col.id == colId then return col end
	end
end

-- Datenlogik (rein, testbar) ---------------------------------------------------------

-- Auswahlliste: alle Charaktere (Realm-sortiert) + Kriegsmeutenbank am Ende.
-- Rueckgabe: Array von { key, label } -- label mit Klassenfarbe und Realm.
function Tab.GetTargets()
	local targets = {}
	for _, charKey in ipairs(Exo.API.GetCharacterKeys()) do
		local meta = Exo.API.GetCharacterInfo(charKey)
		if meta then
			targets[#targets + 1] = {
				key = charKey,
				realm = meta.realm or "",
				name = meta.name or charKey,
				label = string.format("%s (%s)",
					Exo.UI.Format.ClassName(meta.name, meta.classID), meta.realm or "?"),
			}
		end
	end
	table.sort(targets, function(a, b)
		if a.realm ~= b.realm then return a.realm < b.realm end
		return a.name < b.name
	end)
	targets[#targets + 1] = { key = WARBAND_KEY, label = "|cff1784d1Kriegsmeutenbank|r" }
	-- Gildenbanken (1.2.1): gescannte Gilden als eigene Browse-Ziele
	for _, guild in ipairs(Exo.API.GetGuilds()) do
		targets[#targets + 1] = {
			key = GUILD_PREFIX .. guild.name,
			label = "|cff1784d1Gildenbank:|r " .. guild.name,
		}
	end
	return targets
end

-- Items des gewaehlten Ziels, mit aufgeloesten Namen, Qualitaet und Itemklasse
function Tab.GatherItems(targetKey)
	local items
	if targetKey == WARBAND_KEY then
		items = Exo.API.GetWarbandItems()
	elseif targetKey:sub(1, #GUILD_PREFIX) == GUILD_PREFIX then
		items = Exo.API.GetGuildItems(targetKey:sub(#GUILD_PREFIX + 1))
	else
		items = Exo.API.GetCharacterItems(targetKey)
	end
	for _, item in ipairs(items) do
		item.name = Exo.WowAPI.GetItemName(item.itemID) or ("Item " .. item.itemID)
		item.quality = Exo.WowAPI.GetItemQuality(item.itemID)
		item.classID, item.typeName, item.subclassID, item.subTypeName =
			Exo.WowAPI.GetItemClass(item.itemID)
		item.icon = Exo.WowAPI.GetItemIcon(item.itemID)
		-- Aktuelle Erweiterung priorisieren: Midnight-Items stehen in jeder
		-- Kategorie vor Altbestand aus frueheren Erweiterungen
		local expansion = Exo.WowAPI.GetItemExpansion(item.itemID)
		item.expansion = expansion
		item.isCurrentExpac = expansion ~= nil
			and expansion >= Exo.WowAPI.GetCurrentExpansion()
	end
	return items
end

-- Anzeige-Reihenfolge der Itemklassen (Enum.ItemClass); Rest nach Typname
Tab.CLASS_ORDER = {
	[2] = 1,   -- Waffen
	[4] = 2,   -- Ruestung
	[3] = 3,   -- Edelsteine
	[8] = 4,   -- Gegenstandsaufwertung (Verzauberungen etc.)
	[0] = 5,   -- Verbrauchbar
	[7] = 6,   -- Handwerksmaterial
	[5] = 7,   -- Reagenzien
	[9] = 8,   -- Rezepte
	[1] = 9,   -- Behaelter
	[12] = 10, -- Quest
	[15] = 11, -- Verschiedenes
}

-- Gruppierungs-Modi (Vorbild BetterBags: Typ/Unterart-Kategorien sowie die
-- Sortier-Presets "Erweiterungs-Reihenfolge" und "Seltenheit")
Tab.GROUP_MODES = {
	{ id = "type", label = "Typ" },
	{ id = "subtype", label = "Unterart" },
	{ id = "quality", label = "Seltenheit" },
	{ id = "expansion", label = "Erweiterung" },
}

Tab.QUALITY_LABELS = {
	[0] = "Schlecht", [1] = "Verbreitet", [2] = "Ungewoehnlich", [3] = "Selten",
	[4] = "Episch", [5] = "Legendaer", [6] = "Artefakt", [7] = "Erbstueck",
}

Tab.EXPANSION_NAMES = {
	[0] = "Classic", [1] = "Burning Crusade", [2] = "Wrath of the Lich King",
	[3] = "Cataclysm", [4] = "Mists of Pandaria", [5] = "Warlords of Draenor",
	[6] = "Legion", [7] = "Battle for Azeroth", [8] = "Shadowlands",
	[9] = "Dragonflight", [10] = "The War Within", [11] = "Midnight",
}

-- Gruppenschluessel/-beschriftung/-reihenfolge fuer ein Item je Modus
function Tab.GroupInfo(item, mode)
	if mode == "subtype" then
		return string.format("%s/%s", item.classID or -1, item.subclassID or -1),
			item.subTypeName or item.typeName or "Sonstiges",
			Tab.CLASS_ORDER[item.classID] or (item.classID and 50 or 99)
	elseif mode == "quality" then
		local quality = item.quality
		return quality or -1,
			Tab.QUALITY_LABELS[quality] or "Unbekannt",
			-(quality or -1) -- hoechste Seltenheit zuerst
	elseif mode == "expansion" then
		local expansion = item.expansion
		return expansion or -1,
			Tab.EXPANSION_NAMES[expansion] or "Unbekannt",
			-(expansion or -1) -- neueste Erweiterung zuerst
	end
	-- Standard: Itemklasse (Typ)
	return item.classID or -1,
		item.typeName or "Sonstiges",
		Tab.CLASS_ORDER[item.classID] or (item.classID and 50 or 99)
end

-- Gruppiert sortierte Items nach Modus und setzt Sektions-Kopfzeilen davor.
-- Rueckgabe: Zeilenliste { {section=true,label,count,pieces}, item, item, ... }
function Tab.BuildRows(items, sortBy, sortDesc, groupMode)
	groupMode = groupMode or Tab.GROUP_MODES[Tab.groupModeIndex].id
	local groups, byKey = {}, {}
	for _, item in ipairs(items) do
		local key, label, order = Tab.GroupInfo(item, groupMode)
		local group = byKey[key]
		if not group then
			group = { label = label, order = order, items = {} }
			byKey[key] = group
			groups[#groups + 1] = group
		end
		group.items[#group.items + 1] = item
	end
	table.sort(groups, function(a, b)
		if a.order ~= b.order then return a.order < b.order end
		return a.label < b.label
	end)

	local rows = {}
	for _, group in ipairs(groups) do
		Tab.SortItems(group.items, sortBy, sortDesc)
		local pieces = 0
		for _, item in ipairs(group.items) do pieces = pieces + item.total end
		rows[#rows + 1] = { section = true, label = group.label,
			count = #group.items, pieces = pieces }
		for _, item in ipairs(group.items) do
			rows[#rows + 1] = item
		end
	end
	return rows
end

-- Symbolansicht: gleiche Gruppierung, aber Items als Icon-Raster
-- Rueckgabe: { {section=true,...}, {icons={item,...}}, ... } (max perRow pro Zeile)
-- Wie viele Icons passen nebeneinander? Haengt von der Fensterbreite ab
-- (vergroesserbares Fenster); Fallback auf ICONS_PER_ROW, wenn die Breite
-- (noch) nicht bekannt ist (z. B. im Test-Mock).
function Tab.IconsPerRow(content)
	local width = content and content:GetWidth()
	if type(width) ~= "number" or width <= 0 then return Tab.ICONS_PER_ROW end
	return math.max(4, math.floor((width - 8) / (ICON_SIZE + ICON_GAP)))
end

function Tab.BuildIconRows(items, sortBy, sortDesc, perRow, groupMode)
	perRow = perRow or Tab.ICONS_PER_ROW
	local listRows = Tab.BuildRows(items, sortBy, sortDesc, groupMode)
	local rows, chunk = {}, nil
	for _, row in ipairs(listRows) do
		if row.section then
			rows[#rows + 1] = row
			chunk = nil
		else
			if not chunk or #chunk.icons >= perRow then
				chunk = { icons = {} }
				rows[#rows + 1] = chunk
			end
			chunk.icons[#chunk.icons + 1] = row
		end
	end
	return rows
end

function Tab.SortItems(items, sortBy, sortDesc)
	local col = columnById(sortBy) or columnById("total")
	table.sort(items, function(a, b)
		-- Prioritaet 1: Items der aktuellen Erweiterung zuerst
		if (a.isCurrentExpac or false) ~= (b.isCurrentExpac or false) then
			return a.isCurrentExpac and true or false
		end
		local va, vb = col.get(a), col.get(b)
		if va == vb then
			return a.name < b.name
		end
		if sortDesc then va, vb = vb, va end
		return va < vb
	end)
	return items
end

-- Interaktion --------------------------------------------------------------------------

function Tab:GetSelectedTarget()
	local targets = Tab.GetTargets()
	if self.targetIndex > #targets then self.targetIndex = 1 end
	return targets[self.targetIndex]
end

-- Ziel-Auswahl (1.4.1): Klick auf den Charakter-Button klappt eine Liste
-- aller Ziele auf (Chars, Kriegsmeute, Gildenbanken) -- direkt waehlbar
-- statt durchklicken. CycleTarget bleibt als Alternative erhalten.
local DROPDOWN_ROW_HEIGHT = 18
local DROPDOWN_MAX_VISIBLE = 12
local DROPDOWN_WIDTH = 260

function Tab:CycleTarget()
	local targets = Tab.GetTargets()
	self.targetIndex = self.targetIndex % #targets + 1
	if self._targetButton then
		self._targetButton:SetText(targets[self.targetIndex].label)
	end
	if self._content then self:Render(self._content) end
end

function Tab:SelectTarget(index)
	local targets = Tab.GetTargets()
	if targets[index] then
		self.targetIndex = index
	end
	self:CloseTargetDropdown()
	if self._content then self:Render(self._content) end
end

function Tab:CloseTargetDropdown()
	if self._targetDropdown then
		self._targetDropdown:Hide()
	end
end

function Tab:OpenTargetDropdown()
	local dropdown = self._targetDropdown
	if not dropdown then return end
	local targets = Tab.GetTargets()
	local visible = math.min(#targets, DROPDOWN_MAX_VISIBLE)
	dropdown:SetSize(DROPDOWN_WIDTH, visible * DROPDOWN_ROW_HEIGHT + 8)
	self._dropdownScroller.visibleRows = visible
	self._dropdownScroller:SetData(targets)
	dropdown:Show()
end

function Tab:OnTargetClick()
	if self._targetDropdown and self._targetDropdown:IsShown() then
		self:CloseTargetDropdown()
	else
		self:OpenTargetDropdown()
	end
end

function Tab:OnHeaderClick(colId)
	if self.sortBy == colId then
		self.sortDesc = not self.sortDesc
	else
		self.sortBy = colId
		self.sortDesc = (colId ~= "name") -- Zahlen absteigend, Namen aufsteigend
	end
	if self._content then self:Render(self._content) end
end

function Tab:OnViewClick()
	self.viewMode = self.viewMode == "list" and "icons" or "list"
	if self._viewButton then
		self._viewButton:SetText(self.viewMode == "list" and "Symbole" or "Liste")
	end
	if self._content then self:Render(self._content) end
end

function Tab:SetMode(mode)
	self.mode = mode
	self:CloseTargetDropdown()
	if self._content then self:Render(self._content) end
end

function Tab:GetGroupMode()
	return Tab.GROUP_MODES[self.groupModeIndex] or Tab.GROUP_MODES[1]
end

function Tab:OnGroupClick()
	self.groupModeIndex = self.groupModeIndex % #Tab.GROUP_MODES + 1
	if self._groupButton then
		self._groupButton:SetText("Gruppe: " .. self:GetGroupMode().label)
	end
	if self._content then self:Render(self._content) end
end

-- Aufbau -------------------------------------------------------------------------------

local function columnOffset(index)
	local x = 4
	for i = 1, index - 1 do
		x = x + Tab.COLUMNS[i].width + 6
	end
	return x
end

-- Erzeugt Icon-Slots erst bei Bedarf: bei breiterem Fenster passen mehr
-- als ICONS_PER_ROW Icons nebeneinander.
local function ensureSlot(row, i)
	local slot = row.slots[i]
	if slot then return slot end
	slot = Exo.WowAPI.CreateFrame("Frame", nil, row)
	slot:SetSize(ICON_SIZE, ICON_SIZE)
	slot:SetPoint("LEFT", 4 + (i - 1) * (ICON_SIZE + ICON_GAP), 0)
	slot:EnableMouse(true)
	-- Qualitaetsrahmen (1px Rand hinter dem Icon)
	slot.border = slot:CreateTexture(nil, "BACKGROUND")
	slot.border:SetAllPoints(slot)
	slot.border:SetColorTexture(0, 0, 0, 1)
	slot.icon = slot:CreateTexture(nil, "ARTWORK")
	slot.icon:SetPoint("TOPLEFT", 1, -1)
	slot.icon:SetPoint("BOTTOMRIGHT", -1, 1)
	slot.count = Exo.UI.Widgets.Label(slot, "")
	slot.count:SetPoint("BOTTOMRIGHT", -1, 1)
	slot:SetScript("OnEnter", function(frame)
		if frame._itemID then
			GameTooltip:SetOwner(frame, "ANCHOR_RIGHT")
			GameTooltip:SetItemByID(frame._itemID)
			GameTooltip:Show()
		end
	end)
	slot:SetScript("OnLeave", function() GameTooltip:Hide() end)
	slot:Hide()
	row.slots[i] = slot
	return slot
end

local function buildUI(self, content)
	local Widgets = Exo.UI.Widgets

	-- Modus-Umschalter: Bestand (Browse) | Suche (accountweit mit Filtern)
	self._modeButtons = {}
	self._modeButtons.browse = Widgets.Button(content, "Bestand", 64, 20, function()
		self:SetMode("browse")
	end)
	self._modeButtons.browse:SetPoint("TOPLEFT", 4, 0)
	self._modeButtons.search = Widgets.Button(content, "Suche", 64, 20, function()
		self:SetMode("search")
	end)
	self._modeButtons.search:SetPoint("TOPLEFT", 72, 0)

	-- Charakter-Auswahl
	self._targetButton = Widgets.Button(content, "", 200, 20, function()
		self:OnTargetClick()
	end)
	self._targetButton:SetPoint("TOPLEFT", 144, 0)

	-- Aufklappbare Ziel-Liste (1.4.1) unter dem Charakter-Button
	local dropdown = Exo.WowAPI.CreateFrame("Frame", nil, content)
	dropdown:SetPoint("TOPLEFT", self._targetButton, "BOTTOMLEFT", 0, -2)
	dropdown:SetSize(DROPDOWN_WIDTH, 100)
	dropdown:SetFrameStrata("DIALOG")
	dropdown.bg = dropdown:CreateTexture(nil, "BACKGROUND")
	dropdown.bg:SetAllPoints(dropdown)
	dropdown.bg:SetColorTexture(0.05, 0.05, 0.05, 0.97)
	dropdown:Hide()
	self._targetDropdown = dropdown

	local dropdownHost = Exo.WowAPI.CreateFrame("Frame", nil, dropdown)
	dropdownHost:SetPoint("TOPLEFT", 4, -4)
	dropdownHost:SetPoint("BOTTOMRIGHT", -4, 4)

	self._dropdownScroller = Exo.UI.VirtualScroll.New{
		parent = dropdownHost,
		visibleRows = DROPDOWN_MAX_VISIBLE,
		rowHeight = DROPDOWN_ROW_HEIGHT,
		fixedRowHeight = true, -- kompakte Auswahl-Liste, Dichte-Modus egal
		createRow = function(parent, rowIndex)
			local row = Exo.WowAPI.CreateFrame("Frame", nil, parent)
			row:SetHeight(DROPDOWN_ROW_HEIGHT)
			row:SetPoint("TOPLEFT", 0, -((rowIndex - 1) * DROPDOWN_ROW_HEIGHT))
			row:SetPoint("TOPRIGHT", 0, -((rowIndex - 1) * DROPDOWN_ROW_HEIGHT))
			row.bg = row:CreateTexture(nil, "BACKGROUND")
			row.bg:SetAllPoints(row)
			row.bg:SetColorTexture(1, 1, 1, 1)
			row.text = Widgets.Label(row, "")
			row.text:SetPoint("LEFT", 6, 0)
			row.text:SetWidth(DROPDOWN_WIDTH - 16)
			row.text:SetWordWrap(false)
			Widgets.AddRowHighlight(row)
			row:EnableMouse(true)
			row:SetScript("OnMouseDown", function(frame)
				if frame._targetIndex then
					Tab:SelectTarget(frame._targetIndex)
				end
			end)
			return row
		end,
		updateRow = function(row, target, absoluteIndex)
			row._targetIndex = absoluteIndex
			if absoluteIndex == Tab.targetIndex then
				local accent = Exo.UI.Widgets.COLORS.accent
				row.bg:SetColorTexture(accent[1], accent[2], accent[3], 0.30)
			else
				row.bg:SetColorTexture(1, 1, 1, (absoluteIndex % 2 == 0) and 0.05 or 0)
			end
			row.text:SetText(target.label)
		end,
	}

	-- Host fuer die eingebettete Suche (Modus "Suche"); eigene Flaeche unter
	-- der Modus-Zeile, damit sich die UIs nicht ueberlagern
	self._searchHost = Exo.WowAPI.CreateFrame("Frame", nil, content)
	self._searchHost:SetPoint("TOPLEFT", 0, -26)
	self._searchHost:SetPoint("BOTTOMRIGHT", 0, 0)
	self._searchHost:Hide()

	-- Umschalter Liste <-> Symbole (Beschriftung = Zielansicht)
	self._viewButton = Widgets.Button(content, "Symbole", 90, 20, function()
		self:OnViewClick()
	end)
	self._viewButton:SetPoint("TOPRIGHT", -4, 0)

	-- Gruppierungs-Modus (Typ / Unterart / Seltenheit / Erweiterung)
	self._groupButton = Widgets.Button(content, "Gruppe: Typ", 150, 20, function()
		self:OnGroupClick()
	end)
	self._groupButton:SetPoint("TOPRIGHT", -100, 0)

	-- Spalten-Header
	self._headerButtons = {}
	for index, col in ipairs(Tab.COLUMNS) do
		local btn = Widgets.Button(content, col.label, col.width, 18, function()
			self:OnHeaderClick(col.id)
		end)
		btn:SetPoint("TOPLEFT", columnOffset(index), -26)
		self._headerButtons[col.id] = btn
	end

	-- Virtualisierte Liste mit Zebra-Streifen
	local listHost = Exo.WowAPI.CreateFrame("Frame", nil, content)
	listHost:SetPoint("TOPLEFT", 0, -48)
	listHost:SetPoint("BOTTOMRIGHT", 0, 20)

	self._scroller = Exo.UI.VirtualScroll.New{
		parent = listHost,
		visibleRows = VISIBLE_ROWS,
		rowHeight = ROW_HEIGHT,
		createRow = function(parent, rowIndex)
			local row = Exo.WowAPI.CreateFrame("Frame", nil, parent)
			row:SetHeight(ROW_HEIGHT)
			row:SetPoint("TOPLEFT", 0, -((rowIndex - 1) * ROW_HEIGHT))
			row:SetPoint("TOPRIGHT", 0, -((rowIndex - 1) * ROW_HEIGHT))
			row.bg = row:CreateTexture(nil, "BACKGROUND")
			row.bg:SetAllPoints(row)
			row.bg:SetColorTexture(1, 1, 1, 1)
			-- Item-Icon in der Namensspalte (1.4.3)
			row.icon = row:CreateTexture(nil, "ARTWORK")
			row.icon:SetSize(16, 16)
			row.icon:SetPoint("LEFT", columnOffset(1), 0)
			row.cells = {}
			for index, col in ipairs(Tab.COLUMNS) do
				local cell = Widgets.Label(row, "")
				local shift = (col.id == "name") and 20 or 0
				cell:SetPoint("LEFT", columnOffset(index) + shift, 0)
				cell:SetWidth(col.width - shift) -- kappt Ueberlaenge statt zu ueberlappen
				cell:SetWordWrap(false)
				row.cells[col.id] = cell
			end
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
		updateRow = function(row, item, absoluteIndex)
			if item.section then
				-- Typ-Kopfzeile: "Ruestung (12 Items, 340 Stueck)"
				row._itemID = nil
				row.icon:Hide()
				row.bg:SetColorTexture(1, 1, 1, 0.09)
				row.cells.name:SetText(string.format(
					"|cffffd700%s|r  |cff808080(%s, %s Stueck)|r", item.label,
					Exo.UI.Format.Count(item.count, "Item", "Items"),
					Exo.UI.Format.GroupDigits(item.pieces)))
				row.cells.total:SetText("")
				row.cells.bags:SetText("")
				row.cells.bank:SetText("")
				return
			end
			row._itemID = item.itemID
			row.icon:SetTexture(Exo.WowAPI.GetItemIcon(item.itemID))
			row.icon:Show()
			row.bg:SetColorTexture(1, 1, 1, (absoluteIndex % 2 == 0) and 0.04 or 0)
			for _, col in ipairs(Tab.COLUMNS) do
				local text = col.text and col.text(item) or tostring(col.get(item) or "")
				row.cells[col.id]:SetText(text)
			end
		end,
	}

	-- Symbolansicht: eigener Scroller (groessere Zeilen, Icon-Raster)
	local iconHost = Exo.WowAPI.CreateFrame("Frame", nil, content)
	iconHost:SetPoint("TOPLEFT", 0, -48)
	iconHost:SetPoint("BOTTOMRIGHT", 0, 20)

	self._iconScroller = Exo.UI.VirtualScroll.New{
		parent = iconHost,
		visibleRows = ICON_VISIBLE_ROWS,
		rowHeight = ICON_ROW_HEIGHT,
		fixedRowHeight = true, -- Icon-Slots sind 32px: Dichte-Modus ausgenommen
		createRow = function(parent, rowIndex)
			local row = Exo.WowAPI.CreateFrame("Frame", nil, parent)
			row:SetHeight(ICON_ROW_HEIGHT)
			row:SetPoint("TOPLEFT", 0, -((rowIndex - 1) * ICON_ROW_HEIGHT))
			row:SetPoint("TOPRIGHT", 0, -((rowIndex - 1) * ICON_ROW_HEIGHT))
			row.bg = row:CreateTexture(nil, "BACKGROUND")
			row.bg:SetAllPoints(row)
			row.bg:SetColorTexture(1, 1, 1, 0)
			row.label = Widgets.Label(row, "")
			row.label:SetPoint("LEFT", 4, 0)
			row.slots = {}
			return row
		end,
		updateRow = function(row, item)
			if item.section then
				row.bg:SetColorTexture(1, 1, 1, 0.09)
				row.label:SetText(string.format(
					"|cffffd700%s|r  |cff808080(%s, %s Stueck)|r", item.label,
					Exo.UI.Format.Count(item.count, "Item", "Items"),
					Exo.UI.Format.GroupDigits(item.pieces)))
				for i = 1, #row.slots do row.slots[i]:Hide() end
				return
			end
			row.bg:SetColorTexture(1, 1, 1, 0)
			row.label:SetText("")
			for i = 1, math.max(#row.slots, #item.icons) do
				local entry = item.icons[i]
				local slot = entry and ensureSlot(row, i) or row.slots[i]
				if entry then
					slot._itemID = entry.itemID
					slot.icon:SetTexture(entry.icon)
					local hex = Exo.UI.Format.QUALITY_COLORS[entry.quality]
					if hex then
						slot.border:SetColorTexture(
							tonumber(hex:sub(1, 2), 16) / 255,
							tonumber(hex:sub(3, 4), 16) / 255,
							tonumber(hex:sub(5, 6), 16) / 255, 1)
					else
						slot.border:SetColorTexture(0, 0, 0, 1)
					end
					slot.count:SetText(entry.total > 1
						and "|cffffffff" .. entry.total .. "|r" or "")
					slot:Show()
				else
					slot._itemID = nil
					slot:Hide()
				end
			end
		end,
	}

	-- Fusszeile
	self._footer = Widgets.Label(content, "", "GameFontNormal")
	self._footer:SetPoint("BOTTOMLEFT", 4, 2)
end

-- Rendern ------------------------------------------------------------------------------------

-- Designer-Standards (einmalig beim ersten Rendern): Standard-Ansicht und
-- Standard-Gruppierung aus den gespeicherten Optionen uebernehmen.
function Tab.ApplyDefaultOptions()
	local view = Exo.API.GetOption("inventory.defaultView")
	if view == "icons" or view == "list" then Tab.viewMode = view end
	local groupID = Exo.API.GetOption("inventory.defaultGroup")
	for index, mode in ipairs(Tab.GROUP_MODES) do
		if mode.id == groupID then Tab.groupModeIndex = index end
	end
end

function Tab:Render(content)
	if self._content ~= content then
		self._content = content
		self.ApplyDefaultOptions()
		buildUI(self, content)
	end

	-- Modus-Buttons markieren; im Suche-Modus die Browse-UI komplett verstecken
	for id, btn in pairs(self._modeButtons) do btn:SetSelected(id == self.mode) end
	if self.mode == "search" then
		self:CloseTargetDropdown()
		self._targetButton:Hide()
		self._groupButton:Hide()
		self._viewButton:Hide()
		for _, btn in pairs(self._headerButtons) do btn:Hide() end
		self._scroller:GetFrame():Hide()
		self._iconScroller:GetFrame():Hide()
		self._footer:Hide()
		self._searchHost:Show()
		Exo.UI.SearchTab:Render(self._searchHost)
		return
	end
	self._searchHost:Hide()
	self._targetButton:Show()
	self._groupButton:Show()
	self._viewButton:Show()
	self._footer:Show()

	local target = self:GetSelectedTarget()
	self._targetButton:SetText(target and target.label or "-")

	local items = target and Tab.GatherItems(target.key) or {}
	local rows

	-- Ansicht umschalten: Liste (Spalten + Sortier-Header) oder Symbol-Raster.
	-- WICHTIG: der inaktive Scroller wird VERSTECKT, sonst faengt sein (leerer)
	-- Frame das Mausrad ab und die aktive Ansicht laesst sich nicht scrollen.
	local groupMode = self:GetGroupMode()
	if self.viewMode == "icons" then
		rows = Tab.BuildIconRows(items, self.sortBy, self.sortDesc,
			Tab.IconsPerRow(content), groupMode.id)
		self._scroller:SetData({})
		self._scroller:GetFrame():Hide()
		self._iconScroller:SetData(rows)
		self._iconScroller:GetFrame():Show()
		for _, btn in pairs(self._headerButtons) do btn:Hide() end
	else
		rows = Tab.BuildRows(items, self.sortBy, self.sortDesc, groupMode.id)
		self._iconScroller:SetData({})
		self._iconScroller:GetFrame():Hide()
		self._scroller:SetData(rows)
		self._scroller:GetFrame():Show()
		for _, btn in pairs(self._headerButtons) do btn:Show() end
	end
	self._viewButton:SetText(self.viewMode == "list" and "Symbole" or "Liste")
	self._groupButton:SetText("Gruppe: " .. groupMode.label)

	-- Freie Plaetze (0.13.0/1.2.1): Charaktere UND Kriegsmeute
	local freeText = ""
	if target then
		if target.key == WARBAND_KEY then
			local space = Exo.API.GetWarbandSpace()
			if space and space.size > 0 then
				freeText = string.format("  |cff808080Frei: %d/%d Plaetze|r",
					space.free, space.size)
			end
		elseif target.key:sub(1, #GUILD_PREFIX) ~= GUILD_PREFIX then
			local space = Exo.API.GetBagSpace(target.key)
			if space and (space.bagsSize > 0 or space.bankSize > 0) then
				freeText = string.format("  |cff808080Frei: Taschen %d/%d, Bank %d/%d|r",
					space.bagsFree, space.bagsSize, space.bankFree, space.bankSize)
			end
		end
	end

	if #items == 0 then
		self._footer:SetText(
			"Keine Daten. Charakter einmal einloggen (Bank: Bank besuchen) oder /exo import nutzen."
			.. freeText)
	else
		local pieces, types = 0, 0
		for _, item in ipairs(items) do
			pieces = pieces + item.total
		end
		for _, row in ipairs(rows) do
			if row.section then types = types + 1 end
		end
		local Format = Exo.UI.Format
		self._footer:SetText(string.format("%s in %s, %s Stueck gesamt%s",
			Format.Count(#items, "Item", "Items"),
			Format.Count(types, "Kategorie", "Kategorien"),
			Format.GroupDigits(pieces), freeText))
	end
end

-- Test-Helfer
function Tab._GetScroller() return Tab._scroller end
function Tab._GetIconScroller() return Tab._iconScroller end
function Tab._GetFooter() return Tab._footer end
function Tab._GetTargetButton() return Tab._targetButton end
function Tab._GetViewButton() return Tab._viewButton end
function Tab._GetGroupButton() return Tab._groupButton end
function Tab._GetModeButtons() return Tab._modeButtons end
function Tab._GetSearchHost() return Tab._searchHost end
function Tab._GetTargetDropdown() return Tab._targetDropdown end
function Tab._GetDropdownScroller() return Tab._dropdownScroller end

Exo.UI:RegisterTab(Tab)
