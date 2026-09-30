-- ExoTwinksUI/Framework/VirtualScroll.lua
-- Virtualisierte Liste: es existieren nur `visibleRows` Widget-Zeilen,
-- egal ob 5 oder 5000 Datensaetze -- gescrollt wird per Offset ins Daten-Array.
-- (Eigene schlanke Implementierung; deterministisch testbar.)
--
-- Verwendung:
--   local scroller = VirtualScroll.New{
--       parent = frame, visibleRows = 12, rowHeight = 20,
--       createRow = function(parent, index) ... return rowWidget end,
--       updateRow = function(rowWidget, item, absoluteIndex) ... end,
--   }
--   scroller:SetData(items)

local VirtualScroll = {}
VirtualScroll.__index = VirtualScroll
Exo.UI = Exo.UI or {}
Exo.UI.VirtualScroll = VirtualScroll

-- Dichte-Modus (Designer): globaler Faktor auf die Zeilenhoehe aller Listen.
-- Scroller mit `fixedRowHeight = true` (z. B. Icon-Raster) sind ausgenommen.
VirtualScroll._instances = {}
VirtualScroll._densityFactor = 1

local function densityHeight(base, factor)
	return math.max(14, math.floor(base * factor + 0.5))
end

function VirtualScroll.New(opts)
	assert(type(opts) == "table" and opts.parent, "VirtualScroll.New: parent erforderlich")
	assert(type(opts.createRow) == "function", "VirtualScroll.New: createRow erforderlich")
	assert(type(opts.updateRow) == "function", "VirtualScroll.New: updateRow erforderlich")

	local self = setmetatable({
		visibleRows = opts.visibleRows or 10,
		rowHeight = opts.rowHeight or 20,
		baseRowHeight = opts.rowHeight or 20,
		fixedRowHeight = opts.fixedRowHeight or false,
		createRow = opts.createRow,
		updateRow = opts.updateRow,
		items = {},
		offset = 0,
		rows = {},
	}, VirtualScroll)

	-- Aktiven Dichte-Faktor sofort uebernehmen (Scroller kann nach dem
	-- Umschalten der Dichte erzeugt werden)
	if not self.fixedRowHeight and VirtualScroll._densityFactor ~= 1 then
		self.rowHeight = densityHeight(self.baseRowHeight, VirtualScroll._densityFactor)
	end
	VirtualScroll._instances[#VirtualScroll._instances + 1] = self

	local frame = Exo.WowAPI.CreateFrame("Frame", nil, opts.parent)
	frame:SetAllPoints(opts.parent)
	frame:EnableMouseWheel(true)
	frame:SetScript("OnMouseWheel", function(_, delta)
		self:Scroll(-delta) -- Rad hoch (delta +1) = nach oben scrollen
	end)
	self.frame = frame

	for i = 1, self.visibleRows do
		local row = opts.createRow(frame, i)
		row:Hide()
		self.rows[i] = row
	end

	return self
end

-- Neue Zeilenhoehe anwenden: alle vorhandenen Zeilen neu verankern.
-- (Alle Listen-Zeilen folgen dem Muster TOPLEFT/TOPRIGHT + Hoehe.)
function VirtualScroll:SetRowHeight(height)
	if height == self.rowHeight then return end
	self.rowHeight = height
	for i, row in ipairs(self.rows) do
		row:ClearAllPoints()
		row:SetHeight(height)
		row:SetPoint("TOPLEFT", 0, -((i - 1) * height))
		row:SetPoint("TOPRIGHT", 0, -((i - 1) * height))
	end
	self:Refresh()
end

-- Designer: Dichte umschalten (factor 1 = normal, 0.8 = kompakt).
-- Wirkt auf alle existierenden und kuenftigen Listen-Scroller.
function VirtualScroll.ApplyDensity(factor)
	VirtualScroll._densityFactor = factor or 1
	for _, scroller in ipairs(VirtualScroll._instances) do
		if not scroller.fixedRowHeight then
			scroller:SetRowHeight(densityHeight(scroller.baseRowHeight, VirtualScroll._densityFactor))
		end
	end
end

function VirtualScroll:GetFrame() return self.frame end
function VirtualScroll:GetData() return self.items end
function VirtualScroll:GetOffset() return self.offset end

function VirtualScroll:MaxOffset()
	return math.max(0, #self.items - self.visibleRows)
end

function VirtualScroll:SetData(items)
	self.items = items or {}
	self:SetOffset(self.offset) -- klemmt auf neuen Bereich und refresht
end

function VirtualScroll:SetOffset(offset)
	self.offset = math.max(0, math.min(offset, self:MaxOffset()))
	self:Refresh()
end

function VirtualScroll:Scroll(step)
	self:SetOffset(self.offset + step)
end

-- Passt die Zeilenzahl an die tatsaechliche Frame-Hoehe an (vergroesserbares Fenster).
-- Fehlende Zeilen werden bei Bedarf erzeugt; im Test-Mock (GetHeight liefert nichts)
-- bleibt die konfigurierte Zeilenzahl unveraendert.
function VirtualScroll:_SyncVisibleRows()
	local height = self.frame:GetHeight()
	if type(height) ~= "number" or height <= 0 then return end
	local wanted = math.max(1, math.floor(height / self.rowHeight))
	if wanted == self.visibleRows then return end
	for i = #self.rows + 1, wanted do
		local row = self.createRow(self.frame, i)
		row:Hide()
		self.rows[i] = row
	end
	self.visibleRows = wanted
	self.offset = math.max(0, math.min(self.offset, self:MaxOffset()))
end

function VirtualScroll:Refresh()
	self:_SyncVisibleRows()
	for i = 1, #self.rows do
		local item = i <= self.visibleRows and self.items[self.offset + i] or nil
		local row = self.rows[i]
		if item then
			self.updateRow(row, item, self.offset + i)
			row:Show()
		else
			row:Hide()
		end
	end
end
