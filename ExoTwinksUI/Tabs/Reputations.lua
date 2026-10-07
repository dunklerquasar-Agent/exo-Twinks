-- ExoTwinksUI/Tabs/Reputations.lua
-- Reiter "Ruf" (0.17.0): Reputations-Matrix ueber alle Twinks.
-- Pro Fraktion eine Kopfzeile, darunter je Char der Stand (farbcodiert:
-- gruen ab Geehrt, gelb Wohlwollend, grau Neutral, rot darunter) --
-- beantwortet "sind alle Alts >= Geehrt bei X?" auf einen Blick.
-- Datenlogik (BuildRows/StandingText) ist rein und testbar.

local Tab = {
	id = "reputations",
	label = "Ruf",
	query = "",
}
Exo.UI.ReputationsTab = Tab

local VISIBLE_ROWS = 14
local ROW_HEIGHT = 20
local QUERY_DEBOUNCE = 0.3

-- Standing-IDs 1-8 -> deutsches Label + Bedeutungsfarbe
Tab.STANDINGS = {
	[1] = { label = "Verhasst", kind = "negative" },
	[2] = { label = "Feindselig", kind = "negative" },
	[3] = { label = "Unfreundlich", kind = "negative" },
	[4] = { label = "Neutral", kind = "muted" },
	[5] = { label = "Wohlwollend", kind = "warning" },
	[6] = { label = "Geehrt", kind = "positive" },
	[7] = { label = "Respektvoll", kind = "positive" },
	[8] = { label = "Ehrfuerchtig", kind = "positive" },
}

local function charLabel(charKey)
	local meta = Exo.API.GetCharacterInfo(charKey)
	local name = (meta and meta.name ~= "" and meta.name) or charKey
	return Exo.UI.Format.ClassName(name, meta and meta.classID)
end

-- Farbcodierter Standing-Text inkl. Fortschritt: "Geehrt (1.200/12.000)"
function Tab.StandingText(rep)
	local standing = Tab.STANDINGS[rep.standingID] or Tab.STANDINGS[4]
	local text = standing.label
	if (rep.max or 0) > 0 and rep.standingID < 8 then
		local Format = Exo.UI.Format
		text = string.format("%s (%s/%s)", text,
			Format.GroupDigits(rep.value or 0), Format.GroupDigits(rep.max))
	end
	return Exo.UI.Theme.Color(text, standing.kind)
end

-- Zeilen: { header = true, label } | { text }
function Tab.BuildRows(query)
	query = (query or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
	local rows = {}

	-- Union aller Fraktionen + Staende je Char einsammeln
	local factions = {} -- [factionID] = { name, perChar = { {charKey, rep} } }
	for _, charKey in ipairs(Exo.API.GetCharacterKeys()) do
		for _, rep in ipairs(Exo.API.GetReputations(charKey)) do
			local faction = factions[rep.factionID]
			if not faction then
				faction = { name = rep.name, perChar = {} }
				factions[rep.factionID] = faction
			end
			faction.perChar[#faction.perChar + 1] = { charKey = charKey, rep = rep }
		end
	end

	local sorted = {}
	for _, faction in pairs(factions) do
		if query == "" or faction.name:lower():find(query, 1, true) then
			sorted[#sorted + 1] = faction
		end
	end
	table.sort(sorted, function(a, b) return a.name < b.name end)

	for _, faction in ipairs(sorted) do
		rows[#rows + 1] = { header = true, label = faction.name }
		table.sort(faction.perChar, function(a, b)
			if a.rep.standingID ~= b.rep.standingID then
				return a.rep.standingID > b.rep.standingID -- bester Stand zuerst
			end
			return a.charKey < b.charKey
		end)
		for _, entry in ipairs(faction.perChar) do
			rows[#rows + 1] = { text = string.format("%s  %s",
				charLabel(entry.charKey), Tab.StandingText(entry.rep)) }
		end
	end

	-- leer: Render zeigt den zentrierten Leerzustand (1.19.0)
	return rows
end

function Tab:OnQueryChanged(text)
	self.query = text or ""
	Exo.Scheduler:Debounce("reputations-query", QUERY_DEBOUNCE, function()
		if self._content then
			self:Render(self._content)
		end
	end)
end

-- Aufbau ---------------------------------------------------------------------------

local function buildUI(self, content)
	local W = Exo.WowAPI
	local Widgets = Exo.UI.Widgets

	-- Einheitlicher Leerzustand (1.19.0) -- Flaeche der Ergebnis-Liste
	Exo.UI.EmptyState.Attach(content, { top = 26, bottom = 20 })

	local label = Widgets.Label(content, "Fraktion suchen:", "GameFontNormal")
	label:SetPoint("TOPLEFT", 4, -4)

	local editBox = W.CreateFrame("EditBox", nil, content, "InputBoxTemplate")
	editBox:SetSize(220, 20)
	editBox:SetPoint("TOPLEFT", 120, 0)
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

	local listHost = W.CreateFrame("Frame", nil, content)
	listHost:SetPoint("TOPLEFT", 0, -26)
	listHost:SetPoint("BOTTOMRIGHT", 0, 20)

	self._scroller = Exo.UI.VirtualScroll.New{
		parent = listHost,
		visibleRows = VISIBLE_ROWS,
		rowHeight = ROW_HEIGHT,
		createRow = function(parent, rowIndex)
			local row = W.CreateFrame("Frame", nil, parent)
			row:SetHeight(ROW_HEIGHT)
			row:SetPoint("TOPLEFT", 0, -((rowIndex - 1) * ROW_HEIGHT))
			row:SetPoint("TOPRIGHT", 0, -((rowIndex - 1) * ROW_HEIGHT))
			row.bg = row:CreateTexture(nil, "BACKGROUND")
			row.bg:SetAllPoints(row)
			row.bg:SetColorTexture(1, 1, 1, 1)
			row.text = Widgets.Label(row, "")
			row.text:SetPoint("LEFT", 4, 0)
			row.text:SetWidth(680)
			row.text:SetWordWrap(false)
			return row
		end,
		updateRow = function(row, item, absoluteIndex)
			if item.header then
				row.bg:SetColorTexture(1, 1, 1, 0.09)
				row.text:SetText(string.format("|cff%s%s|r",
					Exo.UI.Widgets.COLORS.accentHex, item.label))
			else
				row.bg:SetColorTexture(1, 1, 1, (absoluteIndex % 2 == 0) and 0.04 or 0)
				row.text:SetText(item.text)
			end
		end,
	}

	self._footer = Widgets.Label(content, "", "GameFontNormal")
	self._footer:SetPoint("BOTTOMLEFT", 4, 2)
end

function Tab:Render(content)
	if self._content ~= content then
		self._content = content
		buildUI(self, content)
	end
	local rows = Tab.BuildRows(self.query)
	self._scroller:SetData(rows)

	local trimmed = (self.query or ""):gsub("^%s+", ""):gsub("%s+$", "")
	if #rows == 0 then
		-- Einheitlicher Leerzustand (1.19.0)
		local ES = Exo.UI.EmptyState
		if trimmed == "" then
			ES.Show(content, "Noch keine Ruf-Daten.",
				"Mit jedem Twink einmal einloggen.")
		else
			ES.Show(content, "Keine Fraktion gefunden.")
		end
		self._footer:SetText("")
	else
		Exo.UI.EmptyState.Hide(content)
		-- Footer (1.1.1): Zaehlung + Legende
		local factions = 0
		for _, row in ipairs(rows) do
			if row.header then factions = factions + 1 end
		end
		self._footer:SetText(string.format("%s.  Gruen = Geehrt oder besser.",
			Exo.UI.Format.Count(factions, "Fraktion", "Fraktionen")))
	end
end

-- Test-Helfer
function Tab._GetScroller() return Tab._scroller end
function Tab._GetFooter() return Tab._footer end

Exo.UI:RegisterTab(Tab)
