-- ExoTwinksUI/Framework/ItemList.lua
-- Wiederverwendbare, virtualisierte Item-Liste (1.9.0): Titel, sortierbare
-- Spalten-Header, Zeilen mit Icon + Hover-Tooltip + Shift-Klick-Itemlink,
-- optionale Kopfzeilen (section) und Fusszeile. Genutzt von den Reitern
-- "Bank", "KM-Bank" und "KM-Items".

local ItemList = {}
Exo.UI.ItemList = ItemList

local ROW_HEIGHT = 20
local VISIBLE_ROWS = 14

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

local function columnOffset(columns, index)
	local x = 4
	for i = 1, index - 1 do
		x = x + columns[i].width + 6
	end
	return x
end

-- Baut Titel, Sortier-Header, Liste und Fusszeile in den Tab.
-- Erwartet am Tab: OnHeaderClick(colId); setzt tab._title/_headerButtons/
-- _scroller/_footer.
function ItemList.Build(tab, content, columns, titleText)
	local Widgets = Exo.UI.Widgets

	tab._title = Widgets.Label(content, titleText, "GameFontNormal")
	tab._title:SetPoint("TOPLEFT", 4, 0)

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
				row.cells.name:SetText(string.format(
					"|cffffd700%s|r  |cff808080(%s, %s Stueck)|r", item.label,
					Exo.UI.Format.Count(item.count, "Item", "Items"),
					Exo.UI.Format.GroupDigits(item.pieces)))
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

	tab._footer = Widgets.Label(content, "", "GameFontNormal")
	tab._footer:SetPoint("BOTTOMLEFT", 4, 2)
end
