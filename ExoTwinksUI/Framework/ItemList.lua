-- ExoTwinksUI/Framework/ItemList.lua
-- Wiederverwendbare, virtualisierte Item-Liste (1.9.0): Titel, sortierbare
-- Spalten-Header, Zeilen mit Icon + Hover-Tooltip + Shift-Klick-Itemlink,
-- optionale Kopfzeilen (section) und Fusszeile. Seit 1.9.1 zusaetzlich mit
-- umschaltbarer SYMBOL-Ansicht (Icon-Raster wie im Inventar).
-- Genutzt von den Reitern "Bank", "KM-Bank" und "KM-Items".

local ItemList = {}
Exo.UI.ItemList = ItemList

local ROW_HEIGHT = 20
local VISIBLE_ROWS = 14

-- Symbolansicht
local ICON_SIZE = 32
local ICON_GAP = 4
local ICON_ROW_HEIGHT = 38
local ICON_VISIBLE_ROWS = 7
ItemList.ICONS_PER_ROW = 18 -- Fallback, wenn die Fensterbreite unbekannt ist

-- Namen/Qualitaet/Icon fuer rohe API-Items aufloesen (in-place)
function ItemList.Enrich(items)
	for _, item in ipairs(items) do
		item.name = Exo.WowAPI.GetItemName(item.itemID) or ("Item " .. item.itemID)
		item.quality = Exo.WowAPI.GetItemQuality(item.itemID)
		item.icon = Exo.WowAPI.GetItemIcon(item.itemID)
	end
	return items
end

-- Standard-Text der Namensspalte: farbiger Name + graue Item-ID
function ItemList.NameText(r)
	return string.format("%s |cff808080(%d)|r",
		Exo.UI.Format.ItemName(r.name, r.quality), r.itemID)
end

function ItemList.Sort(items, sortBy, sortDesc)
	table.sort(items, function(a, b)
		local va, vb = a[sortBy], b[sortBy]
		if va == vb then return a.name < b.name end
		if sortDesc then va, vb = vb, va end
		return va < vb
	end)
	return items
end

-- Header-Klick: gleiche Spalte = Richtung drehen, sonst Spalte wechseln
-- (Zahlen absteigend, Namen aufsteigend). Rendert den Tab neu.
function ItemList.OnHeaderClick(tab, colId)
	if tab.sortBy == colId then
		tab.sortDesc = not tab.sortDesc
	else
		tab.sortBy = colId
		tab.sortDesc = (colId ~= "name")
	end
	if tab._content then tab:Render(tab._content) end
end

-- Liste <-> Symbole umschalten (1.9.1)
function ItemList.OnViewClick(tab)
	tab.viewMode = (tab.viewMode == "icons") and "list" or "icons"
	if tab._content then tab:Render(tab._content) end
end

-- Wie viele Icons passen nebeneinander? Abhaengig von der Fensterbreite,
-- Fallback wenn die Breite (noch) nicht bekannt ist (z. B. im Test-Mock).
function ItemList.IconsPerRow(content)
	local width = content and content:GetWidth()
	if type(width) ~= "number" or width <= 0 then return ItemList.ICONS_PER_ROW end
	return math.max(4, math.floor((width - 8) / (ICON_SIZE + ICON_GAP)))
end

-- Listen-Zeilen (sections + items) in Icon-Zeilen umpacken:
-- { {section=true,...}, {icons={item,...}}, ... } (max perRow pro Zeile)
function ItemList.BuildIconRows(rows, perRow)
	perRow = perRow or ItemList.ICONS_PER_ROW
	local out, chunk = {}, nil
	for _, row in ipairs(rows) do
		if row.section then
			out[#out + 1] = row
			chunk = nil
		else
			if not chunk or #chunk.icons >= perRow then
				chunk = { icons = {} }
				out[#out + 1] = chunk
			end
			chunk.icons[#chunk.icons + 1] = row
		end
	end
	return out
end

local function columnOffset(columns, index)
	local x = 4
	for i = 1, index - 1 do
		x = x + columns[i].width + 6
	end
	return x
end

-- Icon-Slot bei Bedarf erzeugen (Tooltip + Shift-Klick wie Listenzeilen)
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
	slot:SetScript("OnMouseDown", function(frame)
		if frame._itemID and Exo.WowAPI.IsShiftDown() then
			Exo.WowAPI.InsertItemLink(frame._itemID)
		end
	end)
	slot:Hide()
	row.slots[i] = slot
	return slot
end

local function sectionText(item)
	return string.format(
		"|cffffd700%s|r  |cff808080(%s, %s Stueck)|r", item.label,
		Exo.UI.Format.Count(item.count, "Item", "Items"),
		Exo.UI.Format.GroupDigits(item.pieces))
end

-- Baut Titel, Sortier-Header, Liste, Symbol-Raster, Umschalt-Button und
-- Fusszeile in den Tab. opts (optional): { viewX = x-Offset des
-- "Symbole"-Buttons von TOPRIGHT (Standard -4) }.
-- Erwartet am Tab: OnHeaderClick(colId) und Render(content).
function ItemList.Build(tab, content, columns, titleText, opts)
	local Widgets = Exo.UI.Widgets
	opts = opts or {}

	tab._title = Widgets.Label(content, titleText, "GameFontNormal")
	tab._title:SetPoint("TOPLEFT", 4, 0)

	-- Umschalter Liste <-> Symbole (Beschriftung = Zielansicht)
	tab._viewButton = Widgets.Button(content, "Symbole", 90, 20, function()
		ItemList.OnViewClick(tab)
	end)
	tab._viewButton:SetPoint("TOPRIGHT", opts.viewX or -4, 0)

	tab._headerButtons = {}
	for index, col in ipairs(columns) do
		local btn = Widgets.Button(content, col.label, col.width, 18, function()
			tab:OnHeaderClick(col.id)
		end)
		btn:SetPoint("TOPLEFT", columnOffset(columns, index), -22)
		tab._headerButtons[col.id] = btn
	end

	local listHost = Exo.WowAPI.CreateFrame("Frame", nil, content)
	listHost:SetPoint("TOPLEFT", 0, -44)
	listHost:SetPoint("BOTTOMRIGHT", 0, 20)

	tab._scroller = Exo.UI.VirtualScroll.New{
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
			row.icon = row:CreateTexture(nil, "ARTWORK")
			row.icon:SetSize(16, 16)
			row.icon:SetPoint("LEFT", 4, 0)
			row.cells = {}
			for index, col in ipairs(columns) do
				local cell = Widgets.Label(row, "")
				local shift = (col.id == "name") and 20 or 0
				cell:SetPoint("LEFT", columnOffset(columns, index) + shift, 0)
				cell:SetWidth(col.width - shift)
				cell:SetWordWrap(false)
				row.cells[col.id] = cell
			end
			Widgets.AddRowHighlight(row)
			row:EnableMouse(true)
			-- Hover-Tooltip: Item unter der Maus im GameTooltip zeigen
			row:SetScript("OnEnter", function(frame)
				if frame._itemID then
					GameTooltip:SetOwner(frame, "ANCHOR_RIGHT")
					GameTooltip:SetItemByID(frame._itemID)
					GameTooltip:Show()
				end
			end)
			row:SetScript("OnLeave", function() GameTooltip:Hide() end)
			row:SetScript("OnMouseDown", function(frame)
				if frame._itemID and Exo.WowAPI.IsShiftDown() then
					Exo.WowAPI.InsertItemLink(frame._itemID)
				end
			end)
			return row
		end,
		updateRow = function(row, item, absoluteIndex)
			if item.section then
				-- false statt nil: Mock-Frames liefern fuer nil-Felder Stubs
				row._itemID = false
				row.icon:Hide()
				row.bg:SetColorTexture(1, 1, 1, 0.09)
				row.cells.name:SetText(sectionText(item))
				for _, col in ipairs(columns) do
					if col.id ~= "name" then row.cells[col.id]:SetText("") end
				end
				return
			end
			row._itemID = item.itemID
			row.icon:SetTexture(item.icon)
			row.icon:Show()
			row.bg:SetColorTexture(1, 1, 1, (absoluteIndex % 2 == 0) and 0.04 or 0)
			for _, col in ipairs(columns) do
				local text
				if col.text then
					text = col.text(item)
				else
					local value = item[col.id]
					text = (value and value > 0) and tostring(value) or "-"
				end
				row.cells[col.id]:SetText(text)
			end
		end,
	}

	-- Symbolansicht: eigener Scroller (groessere Zeilen, Icon-Raster).
	-- WICHTIG: der inaktive Scroller wird in Present() VERSTECKT, sonst
	-- faengt sein leerer Frame das Mausrad ab.
	local iconHost = Exo.WowAPI.CreateFrame("Frame", nil, content)
	iconHost:SetPoint("TOPLEFT", 0, -44)
	iconHost:SetPoint("BOTTOMRIGHT", 0, 20)

	tab._iconScroller = Exo.UI.VirtualScroll.New{
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
			row.label = Exo.UI.Widgets.Label(row, "")
			row.label:SetPoint("LEFT", 4, 0)
			row.slots = {}
			return row
		end,
		updateRow = function(row, item)
			if item.section then
				row.bg:SetColorTexture(1, 1, 1, 0.09)
				row.label:SetText(sectionText(item))
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
					slot._itemID = false -- false statt nil (Mock-Auto-Stub)
					slot:Hide()
				end
			end
		end,
	}

	tab._footer = Widgets.Label(content, "", "GameFontNormal")
	tab._footer:SetPoint("BOTTOMLEFT", 4, 2)
end

-- Zeigt die fertigen Zeilen in der aktiven Ansicht des Tabs an
-- (tab.viewMode "list" oder "icons") und schaltet die Scroller/Header um.
function ItemList.Present(tab, rows)
	if tab.viewMode == "icons" then
		local perRow = ItemList.IconsPerRow(tab._content)
		tab._scroller:SetData({})
		tab._scroller:GetFrame():Hide()
		for _, btn in pairs(tab._headerButtons) do btn:Hide() end
		tab._iconScroller:SetData(ItemList.BuildIconRows(rows, perRow))
		tab._iconScroller:GetFrame():Show()
	else
		tab._iconScroller:SetData({})
		tab._iconScroller:GetFrame():Hide()
		for _, btn in pairs(tab._headerButtons) do btn:Show() end
		tab._scroller:SetData(rows)
		tab._scroller:GetFrame():Show()
	end
	tab._viewButton:SetText(tab.viewMode == "icons" and "Liste" or "Symbole")
end
