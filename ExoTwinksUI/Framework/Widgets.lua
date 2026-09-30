-- ExoTwinksUI/Framework/Widgets.lua
-- Kleine Widget-Factories: einheitliche Erzeugung von Labels und Buttons.
-- Haelt die Tabs frei von CreateFrame-Boilerplate.

local Widgets = {}
Exo.UI = Exo.UI or {}
Exo.UI.Widgets = Widgets

function Widgets.Label(parent, text, template)
	local label = parent:CreateFontString(nil, "OVERLAY", template or "GameFontHighlight")
	label:SetJustifyH("LEFT")
	label:SetText(text or "")
	return label
end

-- ElvUI-Farbschema (zentral, damit Window/Tabs dieselben Werte nutzen)
Widgets.COLORS = {
	bg       = { 0.06, 0.06, 0.06, 0.92 },  -- Fenster-Hintergrund
	panel    = { 0.10, 0.10, 0.10, 1.00 },  -- Button-/Panel-Flaeche
	border   = { 0, 0, 0, 1 },              -- 1px schwarze Kante
	accent   = { 0.09, 0.52, 0.82, 1 },     -- ElvUI-Blau (#1784d1)
	accentHex = "1784d1",
}

-- Flacher Backdrop im ElvUI-Stil: deckende Flaeche + 1px schwarze Kante
function Widgets.Skin(frame, bgColor)
	if not frame.SetBackdrop then return end
	frame:SetBackdrop({
		bgFile = "Interface\\Buttons\\WHITE8x8",
		edgeFile = "Interface\\Buttons\\WHITE8x8",
		edgeSize = 1,
	})
	local c = bgColor or Widgets.COLORS.panel
	frame:SetBackdropColor(c[1], c[2], c[3], c[4])
	local b = Widgets.COLORS.border
	frame:SetBackdropBorderColor(b[1], b[2], b[3], b[4])
end

-- Flacher ElvUI-Button: dunkle Flaeche, 1px Kante, Hover/Auswahl in Akzentblau
function Widgets.Button(parent, label, width, height, onClick)
	local button = Exo.WowAPI.CreateFrame("Button", nil, parent, "BackdropTemplate")
	button:SetSize(width or 100, height or 22)
	Widgets.Skin(button)

	local text = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	text:SetPoint("CENTER", 0, 0)
	text:SetText(label or "")
	button._label = text
	button.SetText = function(self, value) self._label:SetText(value or "") end
	button.GetText = function(self) return self._label:GetText() end

	button._selected = false
	button.SetSelected = function(self, selected)
		self._selected = selected and true or false
		if not self.SetBackdropColor then return end
		local a, p = Widgets.COLORS.accent, Widgets.COLORS.panel
		if self._selected then
			self:SetBackdropColor(a[1], a[2], a[3], 0.35)
			self:SetBackdropBorderColor(a[1], a[2], a[3], 1)
		else
			self:SetBackdropColor(p[1], p[2], p[3], p[4])
			local b = Widgets.COLORS.border
			self:SetBackdropBorderColor(b[1], b[2], b[3], b[4])
		end
	end

	button:SetScript("OnEnter", function(self)
		if self.SetBackdropBorderColor then
			local a = Widgets.COLORS.accent
			self:SetBackdropBorderColor(a[1], a[2], a[3], 1)
		end
	end)
	button:SetScript("OnLeave", function(self)
		if not self._selected and self.SetBackdropBorderColor then
			local b = Widgets.COLORS.border
			self:SetBackdropBorderColor(b[1], b[2], b[3], b[4])
		end
	end)

	if onClick then
		button:SetScript("OnClick", onClick)
	end
	return button
end

-- Hover-Aufhellung fuer klickbare Listenzeilen (1.4.3): der HIGHLIGHT-
-- Layer zeigt sich automatisch bei Maus-over -- "klickbar" wird sichtbar.
function Widgets.AddRowHighlight(row)
	local highlight = row:CreateTexture(nil, "HIGHLIGHT")
	highlight:SetAllPoints(row)
	highlight:SetColorTexture(1, 1, 1, 0.07)
	row.highlight = highlight
	row:EnableMouse(true)
	return highlight
end
