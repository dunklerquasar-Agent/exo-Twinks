-- ExoTwinksUI/Tabs/Characters.lua
-- Haupt-Tab "Charaktere" im AlterEgo-Stil: EINE transponierte Matrix mit den
-- Charakteren als Spalten (Klassenfarbe) und Zeilen-Beschriftungen links in
-- Gold. Vereint die frueheren Tabs Uebersicht, Mythic+ und Schlachtzuege:
--   Allgemein : Realm, Level, Gold, Gespielt, Erholt, Zuletzt online, Itemlevel
--   Mythic+   : Wertung, Schluesselstein, Schatzkammer (3 Kategorien),
--               Season-Best pro Dungeon
--   Raids     : "M HC"-Kurzzeile plus pro Raid ein Abschnitt mit einer Zeile
--               je Schwierigkeit und einem Quadrat pro Boss (gefuellt = tot)
-- Datenlogik (BuildMatrix/CellText/BossCellData) ist rein und testbar.

local Tab = {
	id = "characters",
	label = "Charaktere",
	page = 1,
}
Exo.UI.CharactersTab = Tab

local VISIBLE_ROWS = 13
local ROW_HEIGHT = 20
Tab.CHARS_PER_PAGE = 6

local NAME_X, NAME_W = 4, 200
local CELL_W = 76
-- 6 Spalten: 214 + 5*80 + 76 = 690 <= 696 (Content-Breite)
local function cellX(index) return NAME_X + NAME_W + 10 + (index - 1) * (CELL_W + 4) end

-- Boss-Quadrate (Raid-Fortschritt)
local SQUARE, SQUARE_GAP, MAX_BOSSES = 6, 1, 10

-- Schatzkammer-Kategorien (Enum.WeeklyRewardChartType)
Tab.VAULT_ROWS = {
	{ vaultType = 3, label = "Raids" },
	{ vaultType = 1, label = "Mythic+" },
	{ vaultType = 6, label = "Welt" },
}

-- Schwierigkeiten: Reihenfolge + Kuerzel + Farbe (wie fruehere Raid-Matrix)
Tab.DIFF_LETTER = {
	["Mythisch"] = "M", ["Mythic"] = "M",
	["Heroisch"] = "H", ["Heroic"] = "H",
	["Normal"] = "N",
	["Schlachtzugsbrowser"] = "LFR", ["Raid Finder"] = "LFR", ["LFR"] = "LFR",
}
Tab.DIFF_COLOR = { M = "a335ee", H = "0070dd", N = "1eff00", LFR = "9d9d9d" }
Tab.DIFF_ORDER = { LFR = 1, N = 2, H = 3, M = 4 }
Tab.DIFF_NAME = { LFR = "LFR", N = "Normal", H = "Heroisch", M = "Mythisch" }

-- Zellen-Formatierung (rein, testbar) ---------------------------------------------

function Tab.FormatRatingCell(mplus)
	if (mplus.rating or 0) <= 0 then return "-" end
	return Exo.UI.Format.Rating(mplus.rating)
end

function Tab.FormatKeystoneCell(mplus)
	local key = mplus.keystone
	if not key then return "-" end
	return string.format("%s +%d", Exo.UI.Format.Abbrev(key.name), key.level or 0)
end

-- "2/3" Slots einer Kategorie freigeschaltet; gruen wenn alle, gelb wenn teilweise
function Tab.FormatVaultCell(mplus, vaultType)
	local unlocked, total = 0, 0
	for _, activity in ipairs(mplus.vault or {}) do
		if activity.type == vaultType then
			total = total + 1
			if (activity.progress or 0) >= (activity.threshold or math.huge) then
				unlocked = unlocked + 1
			end
		end
	end
	if total == 0 then return "-" end
	local color = unlocked >= total and "1eff00" or unlocked > 0 and "ffd700" or "9d9d9d"
	return string.format("|cff%s%d/%d|r", color, unlocked, total)
end

-- "+18 168": Level (gruen = in der Zeit, grau = ueberzogen) + Score
function Tab.FormatDungeonCell(mplus, mapID)
	local best = mplus.dungeons and mplus.dungeons[mapID]
	if not best then return "-" end
	local color = best.inTime and "1eff00" or "9d9d9d"
	return string.format("|cff%s+%d|r |cff808080%d|r", color, best.level or 0, best.score or 0)
end

-- Schatzkammer-Statuszeile: Abhol-Erinnerung wie in AlterEgo
function Tab.FormatVaultStatusCell(mplus)
	if mplus.vaultRewards then return "|cff1eff00Abholen!|r" end
	if (mplus.runsThisWeek or 0) > 0 then
		return string.format("|cff808080%d Runs|r", mplus.runsThisWeek)
	end
	return "-"
end

-- Schatzkammer-Tooltip (rein, testbar): Zeilen fuer einen Char
function Tab.BuildVaultTooltip(mplus)
	local lines = { "|cffffd700Grosse Schatzkammer|r" }
	if mplus.vaultRewards then
		lines[#lines + 1] = "|cff1eff00Belohnungen abholbar - besuch die Schatzkammer!|r"
	end
	lines[#lines + 1] = string.format("M+-Runs diese Woche: %d", mplus.runsThisWeek or 0)

	-- M+-Slots mit Freischalt-Status
	local slots = {}
	for _, activity in ipairs(mplus.vault or {}) do
		if activity.type == 1 then slots[#slots + 1] = activity end
	end
	table.sort(slots, function(a, b) return (a.index or 0) < (b.index or 0) end)
	for _, slot in ipairs(slots) do
		if (slot.progress or 0) >= (slot.threshold or math.huge) then
			lines[#lines + 1] = string.format(
				"Slot %d (%d Runs): |cff1eff00frei, Stufe +%d|r",
				slot.index or 0, slot.threshold or 0, slot.level or 0)
		else
			lines[#lines + 1] = string.format(
				"Slot %d (%d Runs): |cff9d9d9dnoch %d Run(s)|r",
				slot.index or 0, slot.threshold or 0,
				(slot.threshold or 0) - (slot.progress or 0))
		end
	end

	if #(mplus.topRuns or {}) > 0 then
		lines[#lines + 1] = " "
		lines[#lines + 1] = "|cffffd700Beste Runs diese Woche:|r"
		for _, run in ipairs(mplus.topRuns) do
			lines[#lines + 1] = string.format("|cff%s+%d|r %s",
				run.completed and "1eff00" or "9d9d9d", run.level or 0, run.name or "?")
		end
	end
	return lines
end

-- Weeklies: "2/4" - gruen alle, gelb teilweise, grau keine
function Tab.FormatWeekliesCell(weeklies, quests)
	if not quests or #quests == 0 then return "-" end
	local done = 0
	for _, quest in ipairs(quests) do
		if weeklies and weeklies[quest.id] then done = done + 1 end
	end
	local color = done >= #quests and "1eff00" or done > 0 and "ffd700" or "9d9d9d"
	return string.format("|cff%s%d/%d|r", color, done, #quests)
end

-- Weeklies-Tooltip (rein, testbar)
function Tab.BuildWeekliesTooltip(weeklies, quests)
	local lines = { "|cffffd700Wochenaufgaben|r" }
	for _, quest in ipairs(quests or {}) do
		if weeklies and weeklies[quest.id] then
			lines[#lines + 1] = string.format("%s: |cff1eff00erledigt|r", quest.label or quest.id)
		else
			lines[#lines + 1] = string.format("%s: |cff9d9d9doffen|r", quest.label or quest.id)
		end
	end
	return lines
end

-- Waehrung: "320/480" mit Cap-Ampel (rot = voll, gelb = ab 75%), ohne Cap nur Menge
function Tab.FormatCurrencyCell(currencies, currencyID)
	local c = currencies and currencies[currencyID]
	if not c or (c.qty or 0) == 0 and not c.max then return c and "0" or "-" end
	if (c.max or 0) > 0 then
		local color = c.qty >= c.max and "ff4040"
			or c.qty >= c.max * 0.75 and "ffd700" or "ffffff"
		return string.format("|cff%s%s/%s|r", color,
			Exo.UI.Format.GroupDigits(c.qty), Exo.UI.Format.GroupDigits(c.max))
	end
	return Exo.UI.Format.GroupDigits(c.qty or 0)
end

-- Raid-Kurzzeile: Locks eines Chars -> "M HC" (farbige Kuerzel, hoechste zuerst)
function Tab.FormatRaidsCell(locks)
	if not locks or #locks == 0 then return "-" end
	local letters = {}
	for _, lock in ipairs(locks) do
		local letter = Tab.DIFF_LETTER[lock.difficultyName or ""]
			or (lock.difficultyName or "?"):sub(1, 1):upper()
		letters[#letters + 1] = letter
	end
	table.sort(letters, function(a, b)
		return (Tab.DIFF_ORDER[a] or 0) > (Tab.DIFF_ORDER[b] or 0)
	end)
	local parts = {}
	for _, letter in ipairs(letters) do
		parts[#parts + 1] = string.format("|cff%s%s|r", Tab.DIFF_COLOR[letter] or "ffffff", letter)
	end
	return table.concat(parts, " ")
end

-- Boss-Quadrate: Lock -> { killed, total, color } (sequentiell gefuellt)
function Tab.BossCellData(lock)
	if not lock then return nil end
	local letter = Tab.DIFF_LETTER[lock.difficultyName or ""] or "N"
	return {
		killed = math.min(lock.bossesKilled or 0, MAX_BOSSES),
		total = math.min(lock.bossesTotal or 0, MAX_BOSSES),
		color = Tab.DIFF_COLOR[letter] or "ffffff",
	}
end

-- Matrix-Aufbau (rein, testbar) ------------------------------------------------------

-- Alle Chars als Spalten (Itemlevel absteigend), Zeilen:
--   feste Zeilen -> Mythic+-Sektion (Dungeons) -> pro Raid eine Sektion mit
--   einer Boss-Quadrat-Zeile je Schwierigkeit.
function Tab.BuildMatrix()
	local chars, dungeonNames = {}, {}
	local raids, raidOrder = {}, {}

	local currencyNames, autoCurrencies = {}, {}

	for _, charKey in ipairs(Exo.API.GetCharacterKeys()) do
		local summary = Exo.API.GetCharacterSummary(charKey)
		if summary then
			local mplus = Exo.API.GetMythicPlus(charKey)
			local locks = Exo.API.GetRaidLocks(charKey)
			local currencies = Exo.API.GetCurrencies(charKey)
			chars[#chars + 1] = {
				key = charKey,
				name = (summary.name ~= "" and summary.name) or charKey,
				classID = summary.classID,
				summary = summary,
				mplus = mplus,
				raidLocks = locks,
				currencies = currencies,
				weeklies = Exo.API.GetWeeklies(charKey),
			}
			for id, c in pairs(currencies) do
				currencyNames[id] = c.name or ("Waehrung " .. id)
				if (c.max or 0) > 0 then autoCurrencies[id] = true end
			end
			for mapID, dungeon in pairs(mplus.dungeons) do
				dungeonNames[mapID] = dungeon.name
			end
			for _, lock in ipairs(locks) do
				local raid = raids[lock.name]
				if not raid then
					raid = { name = lock.name, resetAt = lock.resetAt or 0, diffs = {}, cells = {} }
					raids[lock.name] = raid
					raidOrder[#raidOrder + 1] = raid
				end
				if (lock.resetAt or 0) < raid.resetAt then raid.resetAt = lock.resetAt or 0 end
				local letter = Tab.DIFF_LETTER[lock.difficultyName or ""] or "N"
				raid.diffs[letter] = true
				raid.cells[letter] = raid.cells[letter] or {}
				raid.cells[letter][charKey] = lock
			end
		end
	end

	table.sort(chars, function(a, b)
		if a.summary.ilvl ~= b.summary.ilvl then return a.summary.ilvl > b.summary.ilvl end
		return a.name < b.name
	end)

	-- Rollen-Filter (1.5.0): nur Chars der gewaehlten Rolle anzeigen
	if Tab.roleFilter then
		local Detail = Exo.UI.CharacterDetail
		local filtered = {}
		for _, char in ipairs(chars) do
			if Detail and Detail.GetRole(char.key) == Tab.roleFilter then
				filtered[#filtered + 1] = char
			end
		end
		chars = filtered
	end

	-- Designer: Zeilen-Gruppen sind per Option abschaltbar (Standard: alles an)
	local function rowOn(key)
		return Exo.API.GetOption("charRow." .. key, true) ~= false
	end

	local rows = {
		{ kind = "realm", label = "Realm" },
		{ kind = "level", label = "Level" },
	}
	if rowOn("gold") then rows[#rows + 1] = { kind = "gold", label = "Gold" } end
	if rowOn("bags") then rows[#rows + 1] = { kind = "bags", label = "Taschen frei" } end
	if rowOn("played") then rows[#rows + 1] = { kind = "played", label = "Gespielt" } end
	if rowOn("rest") then rows[#rows + 1] = { kind = "rest", label = "Erholt" } end
	if rowOn("lastSeen") then
		rows[#rows + 1] = { kind = "lastSeen", label = "Zuletzt online" }
	end
	if rowOn("ilvl") then rows[#rows + 1] = { kind = "ilvl", label = "Itemlevel" } end
	if rowOn("mplus") then
		rows[#rows + 1] = { kind = "rating", label = "M+ Wertung" }
		rows[#rows + 1] = { kind = "keystone", label = "Schluesselstein" }
	end
	if rowOn("vault") then
		rows[#rows + 1] = { kind = "vaultstatus", label = "Schatzkammer" }
		for _, vaultRow in ipairs(Tab.VAULT_ROWS) do
			rows[#rows + 1] = { kind = "vault", label = vaultRow.label, vaultType = vaultRow.vaultType }
		end
	end
	if rowOn("raids") then
		rows[#rows + 1] = { kind = "raids", label = "Raid-IDs" }
	end

	-- Weeklies-Zeile (nur wenn die Saisonliste in ExoTwinksData gepflegt ist)
	local weeklyQuests = Exo.API.GetWeeklyQuestList()
	if rowOn("weeklies") and #weeklyQuests > 0 then
		rows[#rows + 1] = { kind = "weeklies", label = "Weeklies", quests = weeklyQuests }
	end

	-- Waehrungs-Sektion: gepflegte Saisonliste, sonst Automatik (alle mit Cap)
	local currencyIDs = Exo.API.GetTrackedCurrencies()
	if #currencyIDs == 0 then
		for id in pairs(autoCurrencies) do currencyIDs[#currencyIDs + 1] = id end
		table.sort(currencyIDs, function(a, b)
			return (currencyNames[a] or "") < (currencyNames[b] or "")
		end)
		while #currencyIDs > 8 do table.remove(currencyIDs) end
	end
	if rowOn("currencies") and #currencyIDs > 0 then
		rows[#rows + 1] = { kind = "section", label = "Waehrungen" }
		for _, id in ipairs(currencyIDs) do
			rows[#rows + 1] = { kind = "currency",
				label = currencyNames[id] or ("Waehrung " .. id), currencyID = id }
		end
	end

	-- Mythic+-Sektion: ein Dungeon pro Zeile (alphabetisch)
	local mapIDs = {}
	for mapID in pairs(dungeonNames) do mapIDs[#mapIDs + 1] = mapID end
	if rowOn("mplus") and #mapIDs > 0 then
		table.sort(mapIDs, function(a, b) return dungeonNames[a] < dungeonNames[b] end)
		rows[#rows + 1] = { kind = "section", label = "Mythic+ (Season-Best)" }
		for _, mapID in ipairs(mapIDs) do
			rows[#rows + 1] = { kind = "dungeon", label = dungeonNames[mapID], mapID = mapID }
		end
	end

	-- Raid-Sektionen: naechster Reset zuerst, Boss-Quadrate je Schwierigkeit
	table.sort(raidOrder, function(a, b)
		if a.resetAt ~= b.resetAt then return a.resetAt < b.resetAt end
		return a.name < b.name
	end)
	for _, raid in ipairs(raidOrder) do
		if not rowOn("raids") then break end
		rows[#rows + 1] = { kind = "section", label = raid.name, resetAt = raid.resetAt }
		local letters = {}
		for letter in pairs(raid.diffs) do letters[#letters + 1] = letter end
		table.sort(letters, function(a, b)
			return (Tab.DIFF_ORDER[a] or 0) < (Tab.DIFF_ORDER[b] or 0)
		end)
		for _, letter in ipairs(letters) do
			rows[#rows + 1] = {
				kind = "bossrow",
				label = Tab.DIFF_NAME[letter] or letter,
				diff = letter,
				cells = raid.cells[letter],
			}
		end
	end

	return { chars = chars, rows = rows }
end

-- Char auf Maxlevel? (dann keine XP-/Erholt-Anzeige)
local function isMaxLevel(summary)
	local cap = Exo.WowAPI.GetMaxPlayerLevel()
	return cap > 0 and (summary.level or 0) >= cap
end

-- Zelle fuer (Zeile, Char) -- zentraler Dispatcher (Textzellen)
-- Spalten-Hervorhebung (rein, testbar, 1.10.0):
-- "current" = eingeloggter Char (Akzentfarbe) | "zebra" | nil
function Tab.ColumnHighlight(char, columnIndex)
	if char and char.summary and char.summary.isCurrent then return "current" end
	if char and columnIndex % 2 == 0 then return "zebra" end
	return nil
end

-- Spaltenkopf (rein, testbar, 1.10.0): eingeloggter Char bekommt einen Akzent-Pfeil
function Tab.HeaderText(char)
	if not char then return "" end
	local text = Exo.UI.Format.ClassName(char.name, char.classID)
	if char.summary and char.summary.isCurrent then
		return "|cff" .. Exo.UI.Widgets.COLORS.accentHex .. "\226\150\182|r " .. text
	end
	return text
end

function Tab.CellText(row, char)
	local s, mplus = char.summary, char.mplus
	if row.kind == "realm" then
		return s.realm or "-"
	elseif row.kind == "bags" then
		-- Freie Taschenplaetze, farbcodiert (1.5.0)
		local space = Exo.API.GetBagSpace(char.key)
		if not space or space.bagsSize == 0 then return "-" end
		local text = space.bagsFree .. " frei"
		if space.bagsFree < 5 then
			return Exo.UI.Theme.Color(text, "negative")
		elseif space.bagsFree < 15 then
			return Exo.UI.Theme.Color(text, "warning")
		end
		return text
	elseif row.kind == "level" then
		if isMaxLevel(s) then return tostring(s.level) end
		return Exo.UI.Format.LevelProgress(s.level, s.xp, s.xpMax)
	elseif row.kind == "gold" then
		return "|cffffd700" .. Exo.UI.Format.Gold(s.gold) .. "|r"
	elseif row.kind == "played" then
		return (s.played or 0) > 0 and Exo.UI.Format.Duration(s.played) or "-"
	elseif row.kind == "rest" then
		if isMaxLevel(s) then return "-" end
		return Exo.UI.Format.RestText(Exo.UI.Format.RestPercent(s.restXP, s.xpMax))
	elseif row.kind == "lastSeen" then
		if s.isCurrent then return "|cff1eff00online|r" end
		return Exo.UI.Format.TimeAgo(s.lastSeen, Exo.WowAPI.Now())
	elseif row.kind == "ilvl" then
		return (s.ilvl or 0) > 0 and string.format("%.0f", s.ilvl) or "-"
	elseif row.kind == "rating" then
		return Tab.FormatRatingCell(mplus)
	elseif row.kind == "keystone" then
		return Tab.FormatKeystoneCell(mplus)
	elseif row.kind == "vaultstatus" then
		return Tab.FormatVaultStatusCell(mplus)
	elseif row.kind == "vault" then
		return Tab.FormatVaultCell(mplus, row.vaultType)
	elseif row.kind == "raids" then
		return Tab.FormatRaidsCell(char.raidLocks)
	elseif row.kind == "weeklies" then
		return Tab.FormatWeekliesCell(char.weeklies, row.quests)
	elseif row.kind == "currency" then
		return Tab.FormatCurrencyCell(char.currencies, row.currencyID)
	elseif row.kind == "dungeon" then
		return Tab.FormatDungeonCell(mplus, row.mapID)
	end
	return "" -- section/bossrow: keine Textzelle
end

-- Seitenweise Spalten
function Tab.PageChars(chars, page)
	local pages = math.max(1, math.ceil(#chars / Tab.CHARS_PER_PAGE))
	if page > pages then page = 1 end
	local first = (page - 1) * Tab.CHARS_PER_PAGE + 1
	local slice = {}
	for i = first, math.min(first + Tab.CHARS_PER_PAGE - 1, #chars) do
		slice[#slice + 1] = chars[i]
	end
	return slice, page, pages
end

function Tab:OnPageClick()
	self.page = self.page + 1
	if self._content then self:Render(self._content) end
end

-- Zell-Tooltip: Schatzkammer-Zeilen zeigen den Vault-Tooltip des Chars
function Tab:OnCellEnter(anchor, item, colIndex)
	if not item then return end
	local char = self._pageChars and self._pageChars[colIndex]
	if not char then return end
	local lines
	if item.kind == "vaultstatus" or item.kind == "vault" then
		lines = Tab.BuildVaultTooltip(char.mplus)
	elseif item.kind == "weeklies" then
		lines = Tab.BuildWeekliesTooltip(char.weeklies, item.quests)
	else
		return
	end

	GameTooltip:SetOwner(anchor, "ANCHOR_RIGHT")
	for _, line in ipairs(lines) do
		GameTooltip:AddLine(line, 1, 1, 1)
	end
	GameTooltip:Show()
end

-- Aufbau ---------------------------------------------------------------------------

local function buildUI(self, content)
	local Widgets = Exo.UI.Widgets

	-- Rollen-Filter (1.5.0), links oben vor den Kopfzellen
	self._roleButton = Widgets.Button(content, "Rolle: Alle", 130, 18, function()
		self:CycleRoleFilter()
	end)
	self._roleButton:SetPoint("TOPLEFT", 4, 0)

	-- Kopfzellen sind Buttons (0.14.0): Klick oeffnet das Detail-Panel
	self._headerCells = {}
	for i = 1, Tab.CHARS_PER_PAGE do
		local cell = Widgets.Button(content, "", CELL_W, 18, function()
			local char = self._pageChars and self._pageChars[i]
			if char then self:OpenDetail(char.key) end
		end)
		cell:SetPoint("TOPLEFT", cellX(i), 0)
		self._headerCells[i] = cell
	end

	-- Host fuer das Detail-Panel (Deep-Dive), lazy befuellt
	self._detailHost = Exo.WowAPI.CreateFrame("Frame", nil, content)
	self._detailHost:SetPoint("TOPLEFT", 0, 0)
	self._detailHost:SetPoint("BOTTOMRIGHT", 0, 0)
	self._detailHost:Hide()

	self._pageButton = Widgets.Button(content, "", 110, 18, function()
		self:OnPageClick()
	end)
	self._pageButton:SetPoint("BOTTOMRIGHT", -4, 0)
	self._pageButton:Hide()

	local listHost = Exo.WowAPI.CreateFrame("Frame", nil, content)
	listHost:SetPoint("TOPLEFT", 0, -24)
	listHost:SetPoint("BOTTOMRIGHT", 0, 20)

	self._scroller = Exo.UI.VirtualScroll.New{
		parent = listHost,
		visibleRows = VISIBLE_ROWS,
		rowHeight = ROW_HEIGHT,
		createRow = function(parent, rowIndex)
			local row = Exo.WowAPI.CreateFrame("Frame", nil, parent)
			row:SetSize(700, ROW_HEIGHT)
			row:SetPoint("TOPLEFT", 0, -((rowIndex - 1) * ROW_HEIGHT))
			row.bg = row:CreateTexture(nil, "BACKGROUND")
			row.bg:SetAllPoints(row)
			row.bg:SetColorTexture(1, 1, 1, 1)
			row.nameCell = Widgets.Label(row, "")
			row.nameCell:SetPoint("LEFT", NAME_X, 0)
			row.nameCell:SetWidth(NAME_W)
			row.nameCell:SetWordWrap(false)
			row.cells = {}
			row.colbg = {}
			row.squares = {}
			for i = 1, Tab.CHARS_PER_PAGE do
				-- vertikales Spalten-Zebra (AlterEgo-Optik)
				local colbg = row:CreateTexture(nil, "BACKGROUND", nil, 1)
				colbg:SetPoint("LEFT", cellX(i) - 2, 0)
				colbg:SetSize(CELL_W + 4, ROW_HEIGHT)
				colbg:SetColorTexture(1, 1, 1, 0.035)
				colbg:Hide() -- sichtbar nur unter belegten geraden Spalten (updateRow)
				row.colbg[i] = colbg

				local cell = Widgets.Label(row, "")
				cell:SetPoint("LEFT", cellX(i), 0)
				cell:SetWidth(CELL_W)
				cell:SetWordWrap(false)
				row.cells[i] = cell

				-- Hover-Zone fuer Zell-Tooltips (Schatzkammer)
				local hover = Exo.WowAPI.CreateFrame("Frame", nil, row)
				hover:SetPoint("LEFT", cellX(i) - 2, 0)
				hover:SetSize(CELL_W + 4, ROW_HEIGHT)
				hover:EnableMouse(true)
				local colIndex = i
				hover:SetScript("OnEnter", function(frame)
					Tab:OnCellEnter(frame, row._item, colIndex)
				end)
				hover:SetScript("OnLeave", function()
					GameTooltip:Hide()
				end)

				-- Boss-Quadrate (nur in bossrow-Zeilen sichtbar)
				row.squares[i] = {}
				for j = 1, MAX_BOSSES do
					local square = row:CreateTexture(nil, "ARTWORK")
					square:SetSize(SQUARE, SQUARE)
					square:SetPoint("LEFT", cellX(i) + (j - 1) * (SQUARE + SQUARE_GAP), 0)
					square:Hide()
					row.squares[i][j] = square
				end
			end
			return row
		end,
		updateRow = function(row, item, absoluteIndex)
			row._item = item
			local isSection = item.kind == "section"
			if isSection then
				row.bg:SetColorTexture(1, 1, 1, 0.09)
				local label = "|cffffd700" .. item.label .. "|r"
				if item.resetAt then
					label = label .. string.format("  |cff808080Reset %s|r",
						Exo.UI.Format.Duration(item.resetAt - Exo.WowAPI.Now()))
				end
				row.nameCell:SetText(label)
			elseif item.kind == "dungeon" or item.kind == "bossrow"
				or item.kind == "vault" or item.kind == "currency" then
				row.bg:SetColorTexture(1, 1, 1, (absoluteIndex % 2 == 0) and 0.03 or 0)
				row.nameCell:SetText("  " .. item.label)
			else
				row.bg:SetColorTexture(1, 1, 1, (absoluteIndex % 2 == 0) and 0.03 or 0)
				row.nameCell:SetText("|cffffd700" .. item.label .. "|r")
			end

			for i = 1, Tab.CHARS_PER_PAGE do
				local char = self._pageChars and self._pageChars[i]
				-- Spalten-Hintergrund: eingeloggter Char in Akzentfarbe, sonst Zebra (1.10.0)
				local highlight = Tab.ColumnHighlight(char, i)
				if highlight == "current" then
					local a = Exo.UI.Widgets.COLORS.accent
					row.colbg[i]:SetColorTexture(a[1], a[2], a[3], 0.16)
					row.colbg[i]:Show()
				elseif highlight == "zebra" then
					row.colbg[i]:SetColorTexture(1, 1, 1, 0.035)
					row.colbg[i]:Show()
				else
					row.colbg[i]:Hide()
				end
				local showSquares = false
				if char and item.kind == "bossrow" then
					local data = Tab.BossCellData(item.cells and item.cells[char.key])
					if data and data.total > 0 then
						showSquares = true
						row.cells[i]:SetText("")
						local r = tonumber(data.color:sub(1, 2), 16) / 255
						local g = tonumber(data.color:sub(3, 4), 16) / 255
						local b = tonumber(data.color:sub(5, 6), 16) / 255
						for j = 1, MAX_BOSSES do
							local square = row.squares[i][j]
							if j <= data.total then
								if j <= data.killed then
									square:SetColorTexture(r, g, b, 1)
								else
									square:SetColorTexture(1, 1, 1, 0.12)
								end
								square:Show()
							else
								square:Hide()
							end
						end
					end
				end
				if not showSquares then
					for j = 1, MAX_BOSSES do row.squares[i][j]:Hide() end
					row.cells[i]:SetText((char and not isSection) and Tab.CellText(item, char) or "")
				end
			end
		end,
	}

	self._footer = Widgets.Label(content, "", "GameFontNormal")
	self._footer:SetPoint("BOTTOMLEFT", 4, 2)
end

-- Rendern ---------------------------------------------------------------------------

-- Rollen-Filter durchschalten (1.5.0): Alle -> Main -> Bank -> Crafter -> Sammler
function Tab:CycleRoleFilter()
	local Detail = Exo.UI.CharacterDetail
	local roles = (Detail and Detail.ROLES) or {}
	local nextFilter = nil
	if self.roleFilter == nil then
		nextFilter = roles[1] and roles[1].id or nil
	else
		for index, role in ipairs(roles) do
			if role.id == self.roleFilter then
				nextFilter = roles[index + 1] and roles[index + 1].id or nil
				break
			end
		end
	end
	self.roleFilter = nextFilter
	self.page = 1
	if self._content then self:Render(self._content) end
end

function Tab:OpenDetail(charKey)
	self.detailKey = charKey
	self.compareKey = nil
	if self._content then self:Render(self._content) end
end

function Tab:Render(content)
	if self._content ~= content then
		self._content = content
		buildUI(self, content)
	end

	-- Detail-Modus (0.14.0): Matrix ausblenden, Deep-Dive-Panel rendern
	if self.detailKey then
		for _, cell in ipairs(self._headerCells) do cell:Hide() end
		self._roleButton:Hide()
		self._pageButton:Hide()
		self._scroller:GetFrame():Hide()
		self._footer:SetText("")
		self._detailHost:Show()
		Exo.UI.CharacterDetail:Render(self._detailHost, self.detailKey, self.compareKey)
		return
	end
	self._detailHost:Hide()
	for _, cell in ipairs(self._headerCells) do cell:Show() end
	self._scroller:GetFrame():Show()

	-- Rollen-Filter-Button aktualisieren (1.5.0)
	self._roleButton:Show()
	local Detail = Exo.UI.CharacterDetail
	local roleLabel = self.roleFilter
		and (Detail and Detail.ROLE_LABELS[self.roleFilter] or self.roleFilter)
		or "Alle"
	self._roleButton:SetText("Rolle: " .. roleLabel)
	self._roleButton:SetSelected(self.roleFilter ~= nil)

	local matrix = Tab.BuildMatrix()
	local pageChars, page, pages = Tab.PageChars(matrix.chars, self.page)
	self.page = page
	self._pageChars = pageChars

	for i = 1, Tab.CHARS_PER_PAGE do
		local char = pageChars[i]
		self._headerCells[i]:SetText(Tab.HeaderText(char))
	end

	if pages > 1 then
		self._pageButton:SetText(string.format("Chars %d/%d  >", page, pages))
		self._pageButton:Show()
	else
		self._pageButton:Hide()
	end

	if #matrix.chars == 0 then
		self._scroller:SetData({})
		self._footer:SetText("Noch keine Charakterdaten. Einfach mit jedem Twink einmal einloggen.")
	else
		self._scroller:SetData(matrix.rows)
		local totalGold = 0
		for _, char in ipairs(matrix.chars) do
			totalGold = totalGold + (char.summary.gold or 0)
		end
		self._footer:SetText(string.format(
			"%s  |  Gesamt: |cffffd700%s|r  |  Raids: |cff9d9d9dLFR|r |cff1eff00N|r |cff0070ddH|r |cffa335eeM|r, Quadrat = Boss",
			Exo.UI.Format.Count(#matrix.chars, "Charakter", "Charaktere"),
			Exo.UI.Format.Gold(totalGold)))
	end
end

-- Test-Helfer
function Tab._GetScroller() return Tab._scroller end
function Tab._GetFooter() return Tab._footer end
function Tab._GetHeaderCells() return Tab._headerCells end
function Tab._GetPageButton() return Tab._pageButton end

Exo.UI:RegisterTab(Tab)
