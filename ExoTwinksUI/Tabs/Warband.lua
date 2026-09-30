-- ExoTwinksUI/Tabs/Warband.lua
-- Zwei Reiter rund um die Kriegsmeute (1.8.0, Nutzerwunsch "getrennt"):
--   "KM-Bank":  der Inhalt der Kriegsmeutenbank selbst (gesamter Account)
--   "KM-Items": alle KRIEGSMEUTENGEBUNDENEN Items, gruppiert je Charakter
--               ("Rabisu hat 10 Items, Myrnia 5, ...") -- seit 1.8.1 nur
--               noch die tatsaechlich verschiebbaren Exemplare.
-- Listen-Mechanik (Tooltip, Shift-Klick, Sortier-Header) kommt seit 1.9.0
-- aus dem gemeinsamen Framework-Modul Exo.UI.ItemList.

local L = Exo.UI.ItemList

-- Reiter 1: KM-Bank (Inhalt der Kriegsmeutenbank) ---------------------------------

local BankTab = {
	id = "warbandbank",
	label = "KM-Bank",
	sortBy = "total",
	sortDesc = true,
	viewMode = "list", -- "list" | "icons" (1.9.1)
}
Exo.UI.WarbandBankTab = BankTab

BankTab.COLUMNS = {
	{ id = "name", label = "Item", width = 320, text = L.NameText },
	{ id = "total", label = "Anzahl", width = 70,
	  text = function(r) return tostring(r.total) end },
}

function BankTab.GatherItems()
	return L.Enrich(Exo.API.GetWarbandItems())
end

function BankTab:OnHeaderClick(colId) L.OnHeaderClick(self, colId) end

function BankTab:Render(content)
	if self._content ~= content then
		self._content = content
		L.Build(self, content, self.COLUMNS, "|cff1784d1Kriegsmeutenbank|r")
	end

	local items = L.Sort(self.GatherItems(), self.sortBy, self.sortDesc)
	L.Present(self, items)

	local freeText = ""
	local space = Exo.API.GetWarbandSpace()
	if space and space.size > 0 then
		freeText = string.format("  |cff808080Frei: %d/%d Plaetze|r",
			space.free, space.size)
	end
	if #items == 0 then
		self._footer:SetText(
			"Keine Daten. Kriegsmeutenbank einmal am Bankfach oeffnen." .. freeText)
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
function BankTab._GetScroller() return BankTab._scroller end
function BankTab._GetIconScroller() return BankTab._iconScroller end
function BankTab._GetViewButton() return BankTab._viewButton end
function BankTab._GetFooter() return BankTab._footer end

-- Reiter 2: KM-Items (kriegsmeutengebunden, je Charakter) -------------------------

local ItemsTab = {
	id = "warbound",
	label = "KM-Items",
	sortBy = "total",
	sortDesc = true,
	viewMode = "list", -- "list" | "icons" (1.9.1)
}
Exo.UI.WarboundTab = ItemsTab

ItemsTab.COLUMNS = {
	{ id = "name", label = "Item", width = 300, text = L.NameText },
	{ id = "total", label = "Anzahl", width = 60,
	  text = function(r) return tostring(r.total) end },
	{ id = "bags", label = "Taschen", width = 65 },
	{ id = "bank", label = "Bank", width = 60 },
}

-- Kriegsmeutengebunden-Uebersicht: welcher Charakter hat welche warbound
-- Items in Taschen/Bank? Gruppen = Charaktere.
function ItemsTab.GatherWarbound()
	local groups = Exo.API.GetWarboundByCharacter()
	for _, group in ipairs(groups) do
		group.label = string.format("%s (%s)",
			Exo.UI.Format.ClassName(group.name, group.classID),
			group.realm ~= "" and group.realm or "?")
		L.Enrich(group.items)
	end
	return groups
end

-- Zeilen: Kopfzeile je Charakter ("Rabisu (Realm) -- 10 Items, 23 Stueck"),
-- darunter dessen warbound Items.
function ItemsTab.BuildWarboundRows(groups, sortBy, sortDesc)
	local rows = {}
	for _, group in ipairs(groups) do
		L.Sort(group.items, sortBy, sortDesc)
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

function ItemsTab:OnHeaderClick(colId) L.OnHeaderClick(self, colId) end

function ItemsTab:Render(content)
	if self._content ~= content then
		self._content = content
		L.Build(self, content, self.COLUMNS,
			"|cff1784d1Kriegsmeutengebundene Items je Charakter|r"
			.. "  |cff808080(nur verschiebbare -- bereits angelegte sind ausgeblendet)|r")
	end

	local groups = self.GatherWarbound()
	L.Present(self, self.BuildWarboundRows(groups, self.sortBy, self.sortDesc))

	if #groups == 0 then
		self._footer:SetText("Keine kriegsmeutengebundenen Items gefunden."
			.. " Tipp: Charaktere einmal einloggen (Bank zaehlt nach Bankbesuch).")
	else
		local kinds, pieces = 0, 0
		for _, group in ipairs(groups) do
			kinds = kinds + #group.items
			for _, item in ipairs(group.items) do pieces = pieces + item.total end
		end
		local Format = Exo.UI.Format
		self._footer:SetText(string.format("%s bei %s, %s Stueck gesamt",
			Format.Count(kinds, "kriegsmeutengebundenes Item", "kriegsmeutengebundene Items"),
			Format.Count(#groups, "Charakter", "Charakteren"),
			Format.GroupDigits(pieces)))
	end
end

-- Test-Helfer
function ItemsTab._GetScroller() return ItemsTab._scroller end
function ItemsTab._GetIconScroller() return ItemsTab._iconScroller end
function ItemsTab._GetViewButton() return ItemsTab._viewButton end
function ItemsTab._GetFooter() return ItemsTab._footer end

Exo.UI:RegisterTab(BankTab)
Exo.UI:RegisterTab(ItemsTab)
