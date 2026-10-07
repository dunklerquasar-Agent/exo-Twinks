-- ExoTwinksUI/Tabs/Professions.lua
-- Reiter "Berufe" (0.15.0): ohne Suchbegriff eine Uebersicht aller Berufe
-- pro Charakter (Skill x/y + Anzahl erfasster Rezepte); mit Suchbegriff die
-- accountweite Rezept-Suche "Wer kann X craften?".
-- Rezepte werden beim Oeffnen des Berufsfensters je Char erfasst.
-- Datenlogik (BuildRows) ist rein und testbar.

local Tab = {
	id = "professions",
	label = "Berufe",
	query = "",
}
Exo.UI.ProfessionsTab = Tab

local VISIBLE_ROWS = 14
local ROW_HEIGHT = 20
local QUERY_DEBOUNCE = 0.3
local MIN_QUERY_LEN = 2

-- Anzeigename (klassengefaerbt) fuer einen charKey
local function charLabel(charKey)
	local meta = Exo.API.GetCharacterInfo(charKey)
	local name = (meta and meta.name ~= "" and meta.name) or charKey
	return Exo.UI.Format.ClassName(name, meta and meta.classID)
end

-- Zeilen bauen: { header = true, label } | { text }
function Tab.BuildRows(query)
	local Format = Exo.UI.Format
	local rows = {}
	query = (query or ""):gsub("^%s+", ""):gsub("%s+$", "")

	-- Modus 1: Rezept-Suche
	if #query >= MIN_QUERY_LEN then
		local results = Exo.API.SearchRecipes(query)
		if #results == 0 then
			return rows -- leer: Render zeigt den zentrierten Leerzustand (1.19.0)
		end
		for _, result in ipairs(results) do
			local names = {}
			for _, charKey in ipairs(result.knownBy) do
				names[#names + 1] = charLabel(charKey)
			end
			rows[#rows + 1] = { text = string.format("%s |cff808080(%s)|r  %s %s  %s",
				result.name, result.profession,
				Exo.UI.Theme.Color("kann:", "positive"), table.concat(names, ", "),
				Tab.CraftStatusText(result.recipeID)),
				recipeID = result.recipeID, recipeName = result.name }
		end
		return rows
	end

	-- Modus 2: Berufs-Uebersicht pro Charakter
	local chars = {}
	for _, charKey in ipairs(Exo.API.GetCharacterKeys()) do
		local professions = Exo.API.GetProfessions(charKey)
		if #professions > 0 then
			chars[#chars + 1] = { key = charKey, professions = professions }
		end
	end
	table.sort(chars, function(a, b) return a.key < b.key end)

	if #chars == 0 then
		return rows -- leer: Render zeigt den zentrierten Leerzustand (1.19.0)
	end

	for _, char in ipairs(chars) do
		rows[#rows + 1] = { header = true, label = charLabel(char.key) }
		for _, prof in ipairs(char.professions) do
			local recipes = prof.recipeCount > 0
				and Format.Count(prof.recipeCount, "Rezept", "Rezepte")
				or Exo.UI.Theme.Color(
					"Rezepte unbekannt - Berufsfenster einmal oeffnen", "warning")
			rows[#rows + 1] = { text = string.format("%s  |cffffd700%d/%d|r  %s",
				prof.name, prof.rank, prof.maxRank, recipes) }
		end
	end
	return rows
end

-- Craft-Status eines Rezepts (1.4.0, rein): gruen craftbar, gelb mit
-- Fehlliste (max. 2 Materialien), grau wenn Reagenzien unbekannt.
function Tab.CraftStatusText(recipeID)
	local Theme = Exo.UI.Theme
	local result = Exo.API.CanCraft(recipeID)
	if not result then
		return Theme.Color("Materialien unbekannt", "muted")
	end
	if result.craftable then
		return Theme.Color("craftbar", "positive")
	end
	local missing = {}
	for _, reagent in ipairs(result.reagents) do
		if reagent.have < reagent.need and #missing < 2 then
			local name = Exo.WowAPI.GetItemName(reagent.itemID)
				or ("Item " .. reagent.itemID)
			missing[#missing + 1] = string.format("%dx %s",
				reagent.need - reagent.have, name)
		end
	end
	return Theme.Color("es fehlen: " .. table.concat(missing, ", "), "warning")
end

-- Material-Report fuer den Chat (Klick auf eine Trefferzeile)
function Tab.MaterialReport(recipeID, recipeName)
	local result = Exo.API.CanCraft(recipeID)
	local lines = { string.format("Materialien fuer '%s':", recipeName or "?") }
	if not result then
		lines[#lines + 1] = "  unbekannt - Berufsfenster einmal (erneut) oeffnen."
		return lines
	end
	for _, reagent in ipairs(result.reagents) do
		local name = Exo.WowAPI.GetItemName(reagent.itemID)
			or ("Item " .. reagent.itemID)
		local ok = reagent.have >= reagent.need
		lines[#lines + 1] = string.format("  %s %dx %s (%d vorhanden)",
			ok and "|cff1eff00+|r" or "|cffff4538-|r", reagent.need, name, reagent.have)
	end
	lines[#lines + 1] = result.craftable
		and "  => alle Materialien vorhanden." or "  => es fehlt etwas."
	return lines
end

function Tab:OnQueryChanged(text)
	self.query = text or ""
	Exo.Scheduler:Debounce("professions-query", QUERY_DEBOUNCE, function()
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

	local label = Widgets.Label(content, "Rezept suchen:", "GameFontNormal")
	label:SetPoint("TOPLEFT", 4, -4)

	local editBox = W.CreateFrame("EditBox", nil, content, "InputBoxTemplate")
	editBox:SetSize(220, 20)
	editBox:SetPoint("TOPLEFT", 110, 0)
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
			-- Klick auf einen Treffer: Material-Report in den Chat (1.4.0)
			row:EnableMouse(true)
			Widgets.AddRowHighlight(row)
			row:SetScript("OnMouseDown", function(frame)
				if frame._recipeID then
					for _, line in ipairs(
						Tab.MaterialReport(frame._recipeID, frame._recipeName)) do
						print("|cff69ccf0exo-Twinks:|r " .. line)
					end
				end
			end)
			return row
		end,
		updateRow = function(row, item, absoluteIndex)
			if item.header then
				row._recipeID, row._recipeName = false, false
				row.bg:SetColorTexture(1, 1, 1, 0.09)
				row.text:SetText(item.label)
			else
				-- false statt nil (Mock-Auto-Stubs, siehe Overview.lua)
				row._recipeID = item.recipeID or false
				row._recipeName = item.recipeName or false
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

	local trimmed = self.query:gsub("^%s+", ""):gsub("%s+$", "")
	local ES = Exo.UI.EmptyState
	if #rows == 0 then
		-- Einheitlicher Leerzustand (1.19.0)
		if #trimmed >= MIN_QUERY_LEN then
			ES.Show(content, "Keine Rezepte gefunden.")
		else
			ES.Show(content, "Noch keine Berufsdaten.",
				"Mit jedem Twink einmal einloggen; Rezepte werden beim Oeffnen "
				.. "des Berufsfensters erfasst.")
		end
		self._footer:SetText("")
	elseif #trimmed >= MIN_QUERY_LEN then
		ES.Hide(content)
		-- Suchmodus: jede Zeile ist ein Treffer
		self._footer:SetText(
			Exo.UI.Format.Count(#rows, "Rezept", "Rezepte") .. " gefunden")
	else
		ES.Hide(content)
		self._footer:SetText(
			"Tipp: Berufsfenster einmal oeffnen, damit Rezepte erfasst werden.")
	end
end

-- Test-Helfer
function Tab._GetScroller() return Tab._scroller end
function Tab._GetFooter() return Tab._footer end

Exo.UI:RegisterTab(Tab)
