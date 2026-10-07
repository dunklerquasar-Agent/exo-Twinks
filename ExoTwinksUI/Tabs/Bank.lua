-- ExoTwinksUI/Tabs/Bank.lua
-- Reiter "Bank" (1.9.0, Nutzerwunsch): die CHARAKTERBANK jedes einzelnen
-- Charakters separat -- Gegenstueck zum Reiter "KM-Bank" (Kriegsmeutenbank
-- fuer den gesamten Account). Charakter-Auswahl per Aufklapp-Liste,
-- Liste mit Hover-Tooltip/Shift-Klick/Sortier-Headern aus Exo.UI.ItemList.

local L = Exo.UI.ItemList

local Tab = {
	id = "bank",
	label = "Bank",
	sortBy = "total",
	sortDesc = true,
	targetIndex = 1,
	viewMode = "list", -- "list" | "icons" (1.9.1)
}
Exo.UI.BankTab = Tab

local DROPDOWN_ROW_HEIGHT = 18
local DROPDOWN_MAX_VISIBLE = 12
local DROPDOWN_WIDTH = 260

Tab.COLUMNS = {
	{ id = "name", label = "Item", width = 320, text = L.NameText },
	{ id = "total", label = "Anzahl", width = 70,
	  text = function(r) return tostring(r.total) end },
}

-- Datenlogik (rein, testbar) -------------------------------------------------------

-- Auswahlliste: nur Charaktere (Realm-sortiert) -- die Kriegsmeutenbank
-- hat ihren eigenen Reiter "KM-Bank".
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
	return targets
end

function Tab:GetSelectedTarget()
	local targets = Tab.GetTargets()
	if self.targetIndex > #targets then self.targetIndex = 1 end
	return targets[self.targetIndex]
end

-- Interaktion ----------------------------------------------------------------------

function Tab:CycleTarget()
	local targets = Tab.GetTargets()
	if #targets == 0 then return end
	self.targetIndex = self.targetIndex % #targets + 1
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

function Tab:OnHeaderClick(colId) L.OnHeaderClick(self, colId) end

-- Aufbau ---------------------------------------------------------------------------

local function buildSelector(self, content)
	local Widgets = Exo.UI.Widgets

	-- Charakter-Auswahl rechts oben (Aufklapp-Liste wie im Inventar, 1.4.1)
	self._targetButton = Widgets.Button(content, "", 220, 20, function()
		self:OnTargetClick()
	end)
	self._targetButton:SetPoint("TOPRIGHT", -4, 0)

	local dropdown = Exo.WowAPI.CreateFrame("Frame", nil, content)
	dropdown:SetPoint("TOPRIGHT", self._targetButton, "BOTTOMRIGHT", 0, -2)
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
			row.text = Exo.UI.Widgets.Label(row, "")
			row.text:SetPoint("LEFT", 6, 0)
			row.text:SetWidth(DROPDOWN_WIDTH - 16)
			row.text:SetWordWrap(false)
			Exo.UI.Widgets.AddRowHighlight(row)
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
end

-- Rendern --------------------------------------------------------------------------

function Tab:Render(content)
	if self._content ~= content then
		self._content = content
		-- Symbole-Button links neben der Charakter-Auswahl (220 breit bei -4)
		L.Build(self, content, self.COLUMNS, "|cff1784d1Charakterbank|r",
			{ viewX = -232 })
		buildSelector(self, content)
	end

	local target = self:GetSelectedTarget()
	self._targetButton:SetText(target and target.label or "-")

	local items = target
		and L.Sort(L.Enrich(Exo.API.GetCharacterBankItems(target.key)),
			self.sortBy, self.sortDesc)
		or {}
	L.Present(self, items)

	-- Freie Bankplaetze des gewaehlten Charakters
	local freeText = ""
	if target then
		local space = Exo.API.GetBagSpace(target.key)
		if space and space.bankSize > 0 then
			freeText = string.format("  |cff808080Bank frei: %d/%d Plaetze|r",
				space.bankFree, space.bankSize)
		end
	end

	if #items == 0 then
		self._footer:SetText(
			"Keine Bankdaten. Mit diesem Charakter einmal die Bank besuchen."
			.. freeText)
	else
		local pieces = 0
		for _, item in ipairs(items) do pieces = pieces + item.total end
		local Format = Exo.UI.Format
		self._footer:SetText(string.format("%s, %s Stueck gesamt%s",
			Format.Count(#items, "Item", "Items"),
			Format.GroupDigits(pieces), freeText))
	end
end

-- Test-Helfer
function Tab._GetScroller() return Tab._scroller end
function Tab._GetIconScroller() return Tab._iconScroller end
function Tab._GetViewButton() return Tab._viewButton end
function Tab._GetFooter() return Tab._footer end
function Tab._GetTargetButton() return Tab._targetButton end
function Tab._GetTargetDropdown() return Tab._targetDropdown end

Exo.UI:RegisterTab(Tab)
