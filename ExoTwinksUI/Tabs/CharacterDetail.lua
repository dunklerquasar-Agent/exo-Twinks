-- ExoTwinksUI/Tabs/CharacterDetail.lua
-- Deep-Dive-Panel (0.14.0): Klick auf einen Charakter in der Matrix oeffnet
-- die Detail-Ansicht -- Allgemein, Equipment Stueck-fuer-Stueck, Mythic+,
-- Schatzkammer, Raid-IDs und Waehrungen. Optional laesst sich ein zweiter
-- Charakter danebenlegen (Compare): bei Zahlenwerten wird der bessere gruen,
-- der schlechtere rot markiert.
-- Datenlogik (BuildDetailRows/NextCompareKey) ist rein und testbar.

local Detail = {}
Exo.UI.CharacterDetail = Detail

-- Ausruestungs-Slots in Anzeige-Reihenfolge (InvSlot-ID + deutsches Label)
Detail.SLOT_ORDER = {
	{ 1, "Kopf" }, { 2, "Hals" }, { 3, "Schultern" }, { 15, "Ruecken" },
	{ 5, "Brust" }, { 9, "Handgelenke" }, { 10, "Haende" }, { 6, "Guertel" },
	{ 7, "Beine" }, { 8, "Fuesse" }, { 11, "Ring 1" }, { 12, "Ring 2" },
	{ 13, "Schmuck 1" }, { 14, "Schmuck 2" }, { 16, "Waffenhand" }, { 17, "Schildhand" },
}

-- Equipment-Intelligenz (1.6.0) ----------------------------------------------------

-- Slots gelten als Upgrade-Kandidat, wenn sie so weit unterm Schnitt liegen
local UPGRADE_GAP = 15

-- Bester Wert je Ausruestungs-Slot ueber ALLE Charaktere (rein, testbar).
-- -> { [slotID] = { ilvl, charKey, name } }
function Detail.GetBestSlots()
	local best = {}
	for _, charKey in ipairs(Exo.API.GetCharacterKeys()) do
		local equipment = Exo.API.GetEquipment(charKey)
		local meta = Exo.API.GetCharacterInfo(charKey)
		local name = (meta and meta.name ~= "" and meta.name) or charKey
		for slotID, slot in pairs((equipment and equipment.slots) or {}) do
			local ilvl = slot.ilvl or 0
			if ilvl > 0 and (not best[slotID] or ilvl > best[slotID].ilvl) then
				best[slotID] = { ilvl = ilvl, charKey = charKey, name = name }
			end
		end
	end
	return best
end

-- Daten-Kontext fuer einen Charakter (alles ueber die Public API)
local function ctxFor(charKey)
	if not charKey then return nil end
	local summary = Exo.API.GetCharacterSummary(charKey)
	if not summary then return nil end
	return {
		key = charKey,
		summary = summary,
		equipment = Exo.API.GetEquipment(charKey) or { ilvl = 0, slots = {} },
		mplus = Exo.API.GetMythicPlus(charKey),
		locks = Exo.API.GetRaidLocks(charKey) or {},
		currencies = Exo.API.GetCurrencies(charKey) or {},
	}
end

-- Vergleich zweier Zahlenwerte: besserer gruen, schlechterer rot
local function colorPair(row)
	local a, b = row.rawA, row.rawB
	if a and b and a ~= b and a > 0 and b > 0 then
		local Theme = Exo.UI.Theme
		if a > b then
			row.a = Theme.Color(row.a, "positive")
			row.b = Theme.Color(row.b, "negative")
		else
			row.a = Theme.Color(row.a, "negative")
			row.b = Theme.Color(row.b, "positive")
		end
	end
	return row
end

local function header(rows, label)
	rows[#rows + 1] = { header = true, label = label }
end

-- Union dynamischer Labels (Dungeons/Raids/Waehrungen) beider Charaktere
local function unionKeys(mapA, mapB)
	local seen, list = {}, {}
	for key in pairs(mapA or {}) do
		if not seen[key] then seen[key] = true; list[#list + 1] = key end
	end
	for key in pairs(mapB or {}) do
		if not seen[key] then seen[key] = true; list[#list + 1] = key end
	end
	table.sort(list)
	return list
end

local function lockMap(locks)
	local Chars = Exo.UI.CharactersTab
	local map = {}
	for _, lock in ipairs(locks) do
		local letter = (Chars and Chars.DIFF_LETTER and Chars.DIFF_LETTER[lock.difficultyName])
			or (lock.difficultyName or ""):sub(1, 1)
		map[(lock.name or "?") .. " " .. letter] = string.format("%d/%d",
			lock.bossesKilled or 0, lock.bossesTotal or 0)
	end
	return map
end

local function currencyMap(currencies)
	local Format = Exo.UI.Format
	local map = {}
	for _, entry in pairs(currencies) do
		local text = Format.GroupDigits(entry.qty or 0)
		if (entry.max or 0) > 0 then
			text = text .. " / " .. Format.GroupDigits(entry.max)
		end
		map[entry.name or "?"] = text
	end
	return map
end

local function dungeonMap(mplus)
	local map = {}
	for _, dungeon in pairs((mplus and mplus.dungeons) or {}) do
		map[dungeon.name or "?"] = string.format("+%d (%d)",
			dungeon.level or 0, dungeon.score or 0)
	end
	return map
end

-- Kernfunktion: Zeilen fuer das Detail-Panel (optional mit Vergleichs-Char).
-- Zeilenformen: { header = true, label } | { label, a, b, rawA, rawB }
function Detail.BuildDetailRows(charKey, compareKey)
	local A = ctxFor(charKey)
	if not A then return {} end
	local B = ctxFor(compareKey)
	local Format = Exo.UI.Format
	local rows = {}

	local function pick(fn) return fn(A), B and fn(B) or nil end

	header(rows, "Allgemein")
	local levelA, levelB = pick(function(c) return c.summary.level or 0 end)
	rows[#rows + 1] = { label = "Level", a = tostring(levelA),
		b = B and tostring(levelB), rawA = levelA, rawB = levelB }
	local ilvlA, ilvlB = pick(function(c) return c.summary.ilvl or 0 end)
	rows[#rows + 1] = colorPair{ label = "Itemlevel", a = tostring(ilvlA),
		b = B and tostring(ilvlB), rawA = ilvlA, rawB = ilvlB }
	local goldA, goldB = pick(function(c) return c.summary.gold or 0 end)
	rows[#rows + 1] = { label = "Gold", a = Format.Gold(goldA),
		b = B and Format.Gold(goldB) }
	rows[#rows + 1] = { label = "Gespielt",
		a = (A.summary.played or 0) > 0 and Format.Duration(A.summary.played) or "-",
		b = B and ((B.summary.played or 0) > 0 and Format.Duration(B.summary.played) or "-") }
	rows[#rows + 1] = { label = "Zone", a = A.summary.zone or "-",
		b = B and (B.summary.zone or "-") }
	rows[#rows + 1] = { label = "Zuletzt online",
		a = A.summary.isCurrent and "jetzt" or Format.TimeAgo(A.summary.lastSeen),
		b = B and (B.summary.isCurrent and "jetzt" or Format.TimeAgo(B.summary.lastSeen)) }

	header(rows, "Equipment")
	-- Ohne Vergleich (1.6.0): Spalte b zeigt den besten Wert im Account;
	-- deutlich unterdurchschnittliche Slots werden rot markiert.
	local Theme = Exo.UI.Theme
	local bestSlots = (not B) and Detail.GetBestSlots() or nil
	for _, slotDef in ipairs(Detail.SLOT_ORDER) do
		local slotID, slotLabel = slotDef[1], slotDef[2]
		local slotA = A.equipment.slots[slotID]
		local slotB = B and B.equipment.slots[slotID]
		local rawA = slotA and slotA.ilvl or 0
		local rawB = B and (slotB and slotB.ilvl or 0) or nil
		local row = colorPair{
			label = slotLabel,
			a = rawA > 0 and tostring(rawA) or "-",
			b = B and ((rawB or 0) > 0 and tostring(rawB) or "-") or nil,
			rawA = rawA, rawB = rawB,
		}
		if bestSlots then
			local best = bestSlots[slotID]
			if best and rawA > 0 and best.ilvl <= rawA then
				row.b = Theme.Color("dein Bestwert", "positive")
			elseif best and best.ilvl > rawA then
				row.b = Theme.Color(string.format("best: %d @ %s",
					best.ilvl, best.name), "muted")
			end
			-- Upgrade-Hinweis: deutlich unter dem eigenen Schnitt
			if rawA > 0 and ilvlA > 0 and rawA <= ilvlA - UPGRADE_GAP then
				row.a = Theme.Color(tostring(rawA), "negative")
			end
		end
		rows[#rows + 1] = row
	end

	local Chars = Exo.UI.CharactersTab
	header(rows, "Mythic+")
	local ratingA, ratingB = pick(function(c)
		return (c.mplus and c.mplus.rating) or 0
	end)
	rows[#rows + 1] = colorPair{ label = "Wertung",
		a = ratingA > 0 and tostring(ratingA) or "-",
		b = B and ((ratingB or 0) > 0 and tostring(ratingB) or "-") or nil,
		rawA = ratingA, rawB = ratingB }
	local dngA, dngB = dungeonMap(A.mplus), B and dungeonMap(B.mplus) or nil
	for _, name in ipairs(unionKeys(dngA, dngB)) do
		rows[#rows + 1] = { label = name, a = dngA[name] or "-",
			b = B and (dngB[name] or "-") }
	end
	if Chars and Chars.VAULT_ROWS then
		for _, vaultDef in ipairs(Chars.VAULT_ROWS) do
			rows[#rows + 1] = {
				label = "Schatzkammer " .. vaultDef.label,
				a = Chars.FormatVaultCell(A.mplus, vaultDef.vaultType),
				b = B and Chars.FormatVaultCell(B.mplus, vaultDef.vaultType),
			}
		end
	end

	header(rows, "Raid-IDs")
	local locksA, locksB = lockMap(A.locks), B and lockMap(B.locks) or nil
	local lockNames = unionKeys(locksA, locksB)
	if #lockNames == 0 then
		-- Einheitlicher Leerzustand-Text (1.19.0)
		rows[#rows + 1] = { label = Exo.UI.EmptyState.Text("Noch keine aktiven Raid-IDs"),
			a = "", b = B and "" }
	end
	for _, name in ipairs(lockNames) do
		rows[#rows + 1] = { label = name, a = locksA[name] or "-",
			b = B and (locksB[name] or "-") }
	end

	header(rows, "Questlog")
	local questsA = {}
	for _, quest in ipairs(Exo.API.GetQuests(charKey)) do
		questsA[quest.questID] = quest.title
	end
	local questsB = nil
	if compareKey then
		questsB = {}
		for _, quest in ipairs(Exo.API.GetQuests(compareKey)) do
			questsB[quest.questID] = quest.title
		end
	end
	local questIDs = unionKeys(questsA, questsB)
	if #questIDs == 0 then
		-- Einheitlicher Leerzustand-Text (1.19.0)
		rows[#rows + 1] = { label = Exo.UI.EmptyState.Text("Noch keine aktiven Quests"),
			a = "", b = B and "" }
	end
	for _, questID in ipairs(questIDs) do
		rows[#rows + 1] = {
			label = questsA[questID] or (questsB and questsB[questID]) or "?",
			a = questsA[questID] and "im Log" or "-",
			b = B and (questsB[questID] and "im Log" or "-") or nil,
		}
	end

	header(rows, "Waehrungen")
	local curA, curB = currencyMap(A.currencies), B and currencyMap(B.currencies) or nil
	local curNames = unionKeys(curA, curB)
	if #curNames == 0 then
		-- Einheitlicher Leerzustand-Text (1.19.0)
		rows[#rows + 1] = { label = Exo.UI.EmptyState.Text("Noch keine Waehrungen"),
			a = "", b = B and "" }
	end
	for _, name in ipairs(curNames) do
		rows[#rows + 1] = { label = name, a = curA[name] or "-",
			b = B and (curB[name] or "-") }
	end

	return rows
end

-- Rollen (1.5.0): verallgemeinert die Bank-Twink-Markierung -------------------------

Detail.ROLES = {
	{ id = "main", label = "Main" },
	{ id = "bank", label = "Bank" },
	{ id = "crafter", label = "Crafter" },
	{ id = "gatherer", label = "Sammler" },
}
Detail.ROLE_LABELS = {}
for _, role in ipairs(Detail.ROLES) do Detail.ROLE_LABELS[role.id] = role.label end

function Detail.GetRole(charKey)
	local role = Exo.API.GetOption("role." .. tostring(charKey), nil)
	if role ~= nil then return role end
	-- Migration: alte Bank-Twink-Markierung (bankalt.*) lesen
	if Exo.API.GetOption("bankalt." .. tostring(charKey), false) == true then
		return "bank"
	end
	return nil
end

function Detail.SetRole(charKey, role)
	Exo.API.SetOption("role." .. tostring(charKey), role)
	Exo.API.SetOption("bankalt." .. tostring(charKey), nil) -- Alt-Flag aufraeumen
end

-- Zyklus: keine -> Main -> Bank -> Crafter -> Sammler -> keine
function Detail.CycleRole(charKey)
	local current = Detail.GetRole(charKey)
	if current == nil then
		Detail.SetRole(charKey, Detail.ROLES[1].id)
		return
	end
	for index, role in ipairs(Detail.ROLES) do
		if role.id == current then
			Detail.SetRole(charKey, Detail.ROLES[index + 1] and Detail.ROLES[index + 1].id or nil)
			return
		end
	end
	Detail.SetRole(charKey, nil)
end

-- Abwaertskompatibel (Bank-Twink-API aus 0.17.0)
function Detail.IsBankAlt(charKey)
	return Detail.GetRole(charKey) == "bank"
end

function Detail.ToggleBankAlt(charKey)
	if Detail.IsBankAlt(charKey) then
		Detail.SetRole(charKey, nil)
	else
		Detail.SetRole(charKey, "bank")
	end
end

-- Naechster Vergleichs-Charakter im Zyklus: nil -> Char1 -> Char2 -> ... -> nil
function Detail.NextCompareKey(detailKey, currentCompare)
	local keys = {}
	for _, key in ipairs(Exo.API.GetCharacterKeys()) do
		if key ~= detailKey then keys[#keys + 1] = key end
	end
	table.sort(keys)
	if #keys == 0 then return nil end
	if currentCompare == nil then return keys[1] end
	for i, key in ipairs(keys) do
		if key == currentCompare then return keys[i + 1] end -- nil nach dem letzten
	end
	return keys[1]
end

-- UI ------------------------------------------------------------------------------

local VISIBLE_ROWS = 13
local ROW_HEIGHT = 20
local COL_LABEL_X, COL_A_X, COL_B_X = 4, 210, 456

local function charLabel(charKey)
	local meta = Exo.API.GetCharacterInfo(charKey)
	local name = (meta and meta.name ~= "" and meta.name) or charKey
	return Exo.UI.Format.ClassName(name, meta and meta.classID)
end

local function buildPanel(host)
	local W = Exo.WowAPI
	local Widgets = Exo.UI.Widgets

	local panel = { host = host }

	panel.backButton = Widgets.Button(host, "< Matrix", 80, 20, function()
		local Chars = Exo.UI.CharactersTab
		Chars.detailKey, Chars.compareKey = nil, nil
		Chars:Render(Chars._content)
	end)
	panel.backButton:SetPoint("TOPLEFT", 4, 0)

	panel.title = Widgets.Label(host, "", "GameFontNormal")
	panel.title:SetPoint("TOPLEFT", 96, -4)

	panel.compareButton = Widgets.Button(host, "Vergleich: -", 200, 20, function()
		local Chars = Exo.UI.CharactersTab
		Chars.compareKey = Detail.NextCompareKey(Chars.detailKey, Chars.compareKey)
		Chars:Render(Chars._content)
	end)
	panel.compareButton:SetPoint("TOPRIGHT", -4, 0)

	-- Rollen-Zuweisung (1.5.0): Klick schaltet Main/Bank/Crafter/Sammler durch
	panel.bankButton = Widgets.Button(host, "Rolle: -", 130, 20, function()
		local Chars = Exo.UI.CharactersTab
		Detail.CycleRole(Chars.detailKey)
		Chars:Render(Chars._content)
	end)
	panel.bankButton:SetPoint("TOPRIGHT", -210, 0)

	local listHost = W.CreateFrame("Frame", nil, host)
	listHost:SetPoint("TOPLEFT", 0, -26)
	listHost:SetPoint("BOTTOMRIGHT", 0, 20)

	panel.scroller = Exo.UI.VirtualScroll.New{
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
			row.labelCell = Widgets.Label(row, "")
			row.labelCell:SetPoint("LEFT", COL_LABEL_X, 0)
			row.labelCell:SetWidth(200)
			row.labelCell:SetWordWrap(false)
			row.aCell = Widgets.Label(row, "")
			row.aCell:SetPoint("LEFT", COL_A_X, 0)
			row.aCell:SetWidth(236)
			row.aCell:SetWordWrap(false)
			row.bCell = Widgets.Label(row, "")
			row.bCell:SetPoint("LEFT", COL_B_X, 0)
			row.bCell:SetWidth(230)
			row.bCell:SetWordWrap(false)
			return row
		end,
		updateRow = function(row, item, absoluteIndex)
			if item.header then
				row.bg:SetColorTexture(1, 1, 1, 0.09)
				row.labelCell:SetText(string.format("|cff%s%s|r",
					Exo.UI.Widgets.COLORS.accentHex, item.label))
				row.aCell:SetText("")
				row.bCell:SetText("")
			else
				row.bg:SetColorTexture(1, 1, 1, (absoluteIndex % 2 == 0) and 0.04 or 0)
				row.labelCell:SetText("|cffffd700" .. item.label .. "|r")
				row.aCell:SetText(item.a or "")
				row.bCell:SetText(item.b or "")
			end
		end,
	}

	panel.footer = Widgets.Label(host, "", "GameFontNormal")
	panel.footer:SetPoint("BOTTOMLEFT", 4, 2)
	return panel
end

-- Vom Charaktere-Tab aufgerufen: Panel (lazy) bauen und rendern
function Detail:Render(host, detailKey, compareKey)
	if self._host ~= host then
		self._host = host
		self._panel = buildPanel(host)
	end
	local panel = self._panel

	local title = charLabel(detailKey)
	if compareKey then
		title = title .. "  |cff808080vs|r  " .. charLabel(compareKey)
	end
	panel.title:SetText(title)
	panel.compareButton:SetText(compareKey
		and ("Vergleich: " .. charLabel(compareKey)) or "Vergleich: -")
	panel.compareButton:SetSelected(compareKey ~= nil)

	local role = Detail.GetRole(detailKey)
	panel.bankButton:SetText("Rolle: " .. (Detail.ROLE_LABELS[role] or "-"))
	panel.bankButton:SetSelected(role ~= nil)

	panel.scroller:SetData(Detail.BuildDetailRows(detailKey, compareKey))
	panel.footer:SetText(compareKey
		and "Gruen = besserer Wert, Rot = schlechterer. Klick auf Vergleich wechselt den Char."
		or "Equipment: grau = bester Wert im Account, rot = deutlich unter deinem Schnitt.")
end

-- Test-Helfer
function Detail._GetPanel() return Detail._panel end
