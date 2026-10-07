-- API/Public.lua
-- Oeffentliche, stabile Query-Schicht (Exo.API).
-- REGEL 2: UI und Dritt-Addons lesen AUSSCHLIESSLICH hierueber, nie den Store direkt.
-- Rueckgaben sind Kopien oder unkritische Referenzen -- Schreibzugriffe der
-- Aufrufer duerfen die DB nie korrumpieren (Kopie bei Arrays).

local _, Exo = ...

local API = {}
Exo.API = API

-- Charaktere ----------------------------------------------------------------------

-- Versteckte Charaktere (1.11.0): Option "hiddenChars" = { [charKey] = true }.
-- Daten werden weiter gesammelt -- nur die Anzeige/Aggregation filtert.
function API.IsCharacterHidden(charKey)
	local hidden = API.GetOption("hiddenChars")
	return type(hidden) == "table" and hidden[charKey] == true
end

function API.SetCharacterHidden(charKey, isHidden)
	local hidden = API.GetOption("hiddenChars")
	if type(hidden) ~= "table" then hidden = {} end
	hidden[charKey] = isHidden and true or nil
	API.SetOption("hiddenChars", hidden)
end

-- Lager-Charaktere (1.14.0): Option "storageChars" =
-- { [charKey] = { expansion = n?, profession = s? } }. Der Tooltip zeigt
-- fuer Items ALTER Erweiterungen, auf welchem Char sie gelagert gehoeren
-- ("Lagerplatz") -- zeigt, auf welchen Charakteren ein Item liegt.

API.STORAGE_PROFESSIONS = { "Bergbau", "Kraeuterkunde", "Schneiderei",
	"Lederverarbeitung", "Verzauberkunst", "Juwelenschleifen",
	"Ingenieurskunst", "Inschriftenkunde", "Kochkunst" }

API.EXPANSION_SHORT = { [0] = "Classic", [1] = "BC", [2] = "WotLK",
	[3] = "Cata", [4] = "MoP", [5] = "WoD", [6] = "Legion", [7] = "BfA",
	[8] = "SL", [9] = "DF", [10] = "TWW", [11] = "Midnight" }

-- Handelswaren-Subklasse (Enum.ItemClass.Tradegoods = 7) -> zustaendiger Beruf
local SUBCLASS_TO_PROF = {
	[1] = "Ingenieurskunst",   -- Teile
	[4] = "Juwelenschleifen",  -- Juwelenschleifen
	[5] = "Schneiderei",       -- Stoff
	[6] = "Lederverarbeitung", -- Leder
	[7] = "Bergbau",           -- Metall & Stein
	[8] = "Kochkunst",         -- Kochkunst
	[9] = "Kraeuterkunde",     -- Kraeuter
	[12] = "Verzauberkunst",   -- Verzauberkunst
	[16] = "Inschriftenkunde", -- Inschriftenkunde
}

function API.GetStorageDesignation(charKey)
	local storage = API.GetOption("storageChars")
	return type(storage) == "table" and storage[charKey] or nil
end

-- expansion und profession beide nil -> Markierung entfernen
function API.SetStorageDesignation(charKey, expansion, profession)
	local storage = API.GetOption("storageChars")
	if type(storage) ~= "table" then storage = {} end
	if expansion == nil and profession == nil then
		storage[charKey] = nil
	else
		storage[charKey] = { expansion = expansion, profession = profession }
	end
	API.SetOption("storageChars", storage)
end

-- Beschriftung einer Markierung: "Cata-Bergbau", "MoP" oder "Bergbau"
function API.StorageLabel(entry)
	if not entry then return nil end
	local exp = entry.expansion and API.EXPANSION_SHORT[entry.expansion]
	if exp and entry.profession then return exp .. "-" .. entry.profession end
	return exp or entry.profession
end

-- Findet den Lager-Charakter fuer ein Item nach konsistenten Regeln:
-- nur Items FRUEHERER Erweiterungen; Berufs-Banken haben Vorrang vor
-- reinen Erweiterungs-Banken; versteckte Chars werden uebersprungen.
-- Rueckgabe: charKey, label | nil
function API.FindStorageChar(itemID)
	local W = Exo.WowAPI
	local exp = W.GetItemExpansion(itemID)
	if exp == nil or exp >= W.GetCurrentExpansion() then return nil end
	local storage = API.GetOption("storageChars")
	if type(storage) ~= "table" then return nil end

	local tradegoods = (_G.Enum and _G.Enum.ItemClass
		and _G.Enum.ItemClass.Tradegoods) or 7
	local classID, _, subclassID = W.GetItemClass(itemID)
	local prof = classID == tradegoods and SUBCLASS_TO_PROF[subclassID] or nil

	local keys = {}
	for charKey in pairs(storage) do
		if not API.IsCharacterHidden(charKey) then keys[#keys + 1] = charKey end
	end
	table.sort(keys)

	-- 1. Durchgang: Berufs-Bank (Erweiterung muss passen, falls gesetzt)
	if prof then
		for _, charKey in ipairs(keys) do
			local entry = storage[charKey]
			if entry.profession == prof
				and (entry.expansion == nil or entry.expansion == exp) then
				return charKey, API.StorageLabel(entry)
			end
		end
	end
	-- 2. Durchgang: Erweiterungs-Bank
	for _, charKey in ipairs(keys) do
		local entry = storage[charKey]
		if entry.expansion == exp then
			return charKey, API.StorageLabel(entry)
		end
	end
	return nil
end

-- Ohne Argument: nur sichtbare Chars; includeHidden=true liefert alle (Designer)
function API.GetCharacterKeys(includeHidden)
	if not Exo.Store:IsReady() then return {} end
	local keys = Exo.Store:GetCharacterKeys()
	if includeHidden then return keys end
	local visible = {}
	for _, key in ipairs(keys) do
		if not API.IsCharacterHidden(key) then visible[#visible + 1] = key end
	end
	return visible
end

function API.GetCharacterInfo(charKey)
	if not Exo.Store:IsReady() then return nil end
	local char = Exo.Store:GetCharacter(charKey)
	return char and char.meta or nil
end

-- Anzeigefertige Zusammenfassung eines Charakters (fuer Uebersichts-Listen)
function API.GetCharacterSummary(charKey)
	if not Exo.Store:IsReady() then return nil end
	local char = Exo.Store:GetCharacter(charKey)
	if not char then return nil end

	local meta = char.meta
	local equipment = char.equipment or {}
	return {
		key = charKey,
		name = meta.name,
		realm = meta.realm,
		faction = meta.faction,
		level = meta.level,
		classID = meta.classID,
		zone = meta.zone,
		lastSeen = meta.lastSeen,
		played = meta.playedTotal,
		gold = char.gold or 0,
		ilvl = equipment.avgItemLevelEquipped or equipment.avgItemLevel or 0,
		xp = meta.xp or 0,
		xpMax = meta.xpMax or 0,
		restXP = meta.restXP,
		isCurrent = (charKey == Exo.Store:GetCurrentKey()),
	}
end

-- Alles Kriegsmeutengebundene aus den Taschen in die KM-Bank einlagern (1.13.0).
-- Geht nur bei geoeffneter Bank. -> Anzahl eingelagerter Stapel | nil, "bank_closed"
function API.DepositWarboundToBank()
	local Containers = Exo.Collectors and Exo.Collectors.Containers
	if not (Containers and Containers.IsBankOpen and Containers.IsBankOpen()) then
		return nil, "bank_closed"
	end
	local W = Exo.WowAPI
	local moved = 0
	for bagID = 0, 5 do
		for slot = 1, W.GetContainerNumSlots(bagID) do
			local itemID = W.GetContainerItem(bagID, slot)
			if itemID and (W.IsSlotWarbound(bagID, slot)
				or W.IsPermanentWarbound(itemID)) then
				W.DepositToWarbandBank(bagID, slot)
				moved = moved + 1
			end
		end
	end
	return moved
end

-- Sortierte Liste aller Realms, auf denen Charaktere bekannt sind
function API.GetRealms()
	local seen, realms = {}, {}
	for _, key in ipairs(API.GetCharacterKeys()) do
		local meta = API.GetCharacterInfo(key)
		if meta and meta.realm ~= "" and not seen[meta.realm] then
			seen[meta.realm] = true
			realms[#realms + 1] = meta.realm
		end
	end
	table.sort(realms)
	return realms
end

-- Mythic+ ---------------------------------------------------------------------------

-- Mythic+-Daten eines Charakters (immer eine tiefe Kopie, nie die DB selbst).
-- { rating, keystone = {mapID,name,level} | nil,
--   dungeons = { [mapID] = {name,level,score,inTime} }, vault = { {type,index,progress,threshold,level} } }
function API.GetMythicPlus(charKey)
	local empty = { rating = 0, keystone = nil, dungeons = {}, vault = {},
		vaultRewards = false, runsThisWeek = 0, topRuns = {} }
	if not Exo.Store:IsReady() then return empty end
	local char = Exo.Store:GetCharacter(charKey)
	local mp = char and char.mythicplus
	if type(mp) ~= "table" or mp.rating == nil then return empty end

	local copy = { rating = mp.rating or 0, keystone = nil, dungeons = {}, vault = {} }
	if mp.keystone then
		copy.keystone = { mapID = mp.keystone.mapID, name = mp.keystone.name, level = mp.keystone.level }
	end
	for mapID, d in pairs(mp.dungeons or {}) do
		copy.dungeons[mapID] = { name = d.name, level = d.level, score = d.score, inTime = d.inTime }
	end
	for i, a in ipairs(mp.vault or {}) do
		copy.vault[i] = { type = a.type, index = a.index,
			progress = a.progress, threshold = a.threshold, level = a.level }
	end
	copy.vaultRewards = mp.vaultRewards and true or false
	copy.runsThisWeek = mp.runsThisWeek or 0
	copy.topRuns = {}
	for i, run in ipairs(mp.topRuns or {}) do
		copy.topRuns[i] = { mapID = run.mapID, name = run.name,
			level = run.level, completed = run.completed }
	end
	return copy
end

-- Waehrungen eines Charakters: { [currencyID] = { name, qty, max } } (Kopie)
function API.GetCurrencies(charKey)
	if not Exo.Store:IsReady() then return {} end
	local char = Exo.Store:GetCharacter(charKey)
	local copy = {}
	for id, c in pairs((char and char.currencies) or {}) do
		copy[id] = { name = c.name, qty = c.qty, max = c.max, acc = c.acc,
			cat = c.cat, catOrder = c.catOrder }
	end
	return copy
end

-- Wochenaufgaben eines Charakters: { [questID] = true/false } (Kopie)
function API.GetWeeklies(charKey)
	if not Exo.Store:IsReady() then return {} end
	local char = Exo.Store:GetCharacter(charKey)
	local copy = {}
	for id, done in pairs((char and char.weeklies) or {}) do
		copy[id] = done and true or false
	end
	return copy
end

-- Saisonliste der Wochenaufgaben aus ExoTwinksData (Kopie, leer wenn ungepflegt)
function API.GetWeeklyQuestList()
	local list = {}
	for i, quest in ipairs((Exo.Data and Exo.Data.WeeklyQuests) or {}) do
		list[i] = { id = quest.id, label = quest.label }
	end
	return list
end

-- Saisonliste der angezeigten Waehrungen aus ExoTwinksData (Kopie)
function API.GetTrackedCurrencies()
	local list = {}
	for i, id in ipairs((Exo.Data and Exo.Data.TrackedCurrencies) or {}) do
		list[i] = id
	end
	return list
end

-- Instanz-Locks --------------------------------------------------------------------

-- Liefert die noch GUELTIGEN Locks eines Charakters (abgelaufene werden gefiltert).
-- opts.includeExpired = true  -> auch abgelaufene
-- opts.raidsOnly = true       -> nur Schlachtzuege
function API.GetInstanceLocks(charKey, opts)
	opts = opts or {}
	if not Exo.Store:IsReady() then return {} end

	local char = Exo.Store:GetCharacter(charKey)
	if not char or type(char.instanceLocks) ~= "table" then return {} end

	local now = Exo.WowAPI.Now()
	local result = {}
	for _, lock in ipairs(char.instanceLocks) do
		local valid = opts.includeExpired or (lock.resetAt or 0) > now
		local typeOk = (not opts.raidsOnly) or lock.isRaid
		if valid and typeOk then
			-- flache Kopie: Aufrufer koennen die DB nicht veraendern
			local copy = {}
			for k, v in pairs(lock) do copy[k] = v end
			result[#result + 1] = copy
		end
	end
	return result
end

function API.GetRaidLocks(charKey)
	return API.GetInstanceLocks(charKey, { raidsOnly = true })
end

-- Ausruestung eines Charakters: { ilvl, slots = { [invSlot] = { id, ilvl } } }
function API.GetEquipment(charKey)
	if not Exo.Store:IsReady() then return nil end
	local char = Exo.Store:GetCharacter(charKey)
	if not char then return nil end
	local equipment = char.equipment or {}
	return {
		ilvl = equipment.avgItemLevelEquipped or equipment.avgItemLevel or 0,
		slots = equipment.slots or {},
	}
end

-- Freie/belegte Taschenplaetze eines Charakters (Taschen und Bank getrennt).
-- Rueckgabe: { bagsFree, bagsSize, bankFree, bankSize } oder nil.
function API.GetBagSpace(charKey)
	if not Exo.Store:IsReady() then return nil end
	local char = Exo.Store:GetCharacter(charKey)
	if not char then return nil end

	local function tally(bagSet)
		local free, size = 0, 0
		for _, bag in pairs(bagSet or {}) do
			if type(bag) == "table" and (bag.size or 0) > 0 then
				size = size + bag.size
				local bagFree = bag.free
				if bagFree == nil then -- aeltere Scans ohne free-Feld
					local occupied = 0
					for _ in pairs(bag.items or {}) do occupied = occupied + 1 end
					bagFree = bag.size - occupied
				end
				free = free + bagFree
			end
		end
		return free, size
	end

	local space = {}
	space.bagsFree, space.bagsSize = tally(char.bags)
	space.bankFree, space.bankSize = tally(char.bank)
	-- Kleinste ausgeruestete Tasche (1.5.0): "wer braucht ein Upgrade?"
	for bagID, bag in pairs(char.bags or {}) do
		if type(bag) == "table" and type(bagID) == "number" and bagID > 0
			and (bag.size or 0) > 0 then
			if not space.smallestBag or bag.size < space.smallestBag then
				space.smallestBag = bag.size
			end
		end
	end
	return space
end

-- Berufe eines Charakters (0.15.0), sortiert nach Name.
-- -> { { skillLineID, name, rank, maxRank, recipeCount }, ... }
function API.GetProfessions(charKey)
	if not Exo.Store:IsReady() then return {} end
	local char = Exo.Store:GetCharacter(charKey)
	if not char then return {} end

	local list = {}
	for skillLineID, prof in pairs(char.professions or {}) do
		local count = 0
		for _ in pairs(prof.recipes or {}) do count = count + 1 end
		list[#list + 1] = {
			skillLineID = skillLineID,
			name = prof.name or "?",
			rank = prof.rank or 0,
			maxRank = prof.maxRank or 0,
			recipeCount = count,
		}
	end
	table.sort(list, function(a, b) return a.name < b.name end)
	return list
end

-- Rezept-Suche ueber alle Charaktere: "Wer kann X craften?" (0.15.0)
-- -> { { recipeID, name, profession, knownBy = { charKey, ... } }, ... }
function API.SearchRecipes(query)
	if not Exo.Store:IsReady() then return {} end
	query = (query or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
	if #query < 2 then return {} end

	local byRecipe = {}
	for _, charKey in ipairs(API.GetCharacterKeys()) do
		local char = Exo.Store:GetCharacter(charKey)
		for _, prof in pairs((char and char.professions) or {}) do
			for recipeID, recipeEntry in pairs(prof.recipes or {}) do
				-- Dual-Format (1.4.0): String (alt) oder { name, reagents } (neu)
				local recipeName = type(recipeEntry) == "table"
					and recipeEntry.name or recipeEntry
				if type(recipeName) == "string"
					and recipeName:lower():find(query, 1, true) then
					local entry = byRecipe[recipeID]
					if not entry then
						entry = {
							recipeID = recipeID,
							name = recipeName,
							profession = prof.name or "?",
							knownBy = {},
						}
						byRecipe[recipeID] = entry
					end
					entry.knownBy[#entry.knownBy + 1] = charKey
				end
			end
		end
	end

	local results = {}
	for _, entry in pairs(byRecipe) do
		table.sort(entry.knownBy)
		results[#results + 1] = entry
	end
	table.sort(results, function(a, b)
		if #a.knownBy ~= #b.knownBy then return #a.knownBy > #b.knownBy end
		if a.name ~= b.name then return a.name < b.name end
		return a.recipeID < b.recipeID
	end)
	return results
end

-- Briefkasten (0.16.0) ----------------------------------------------------------------

-- Mails eines Charakters inkl. berechnetem Ablauf-Zeitpunkt.
-- -> { scannedAt, mails = { { sender, subject, money, items, expiresAt, daysLeft } } }
function API.GetMails(charKey)
	if not Exo.Store:IsReady() then return nil end
	local char = Exo.Store:GetCharacter(charKey)
	if not char or not char.mails or not char.mails.list then return nil end

	local scannedAt = char.mails.scannedAt or 0
	local now = Exo.WowAPI.Now()
	local mails = {}
	for _, mail in ipairs(char.mails.list) do
		local expiresAt = scannedAt + math.floor((mail.daysLeft or 0) * 86400)
		mails[#mails + 1] = {
			sender = mail.sender,
			subject = mail.subject,
			money = mail.money or 0,
			items = mail.items or {},
			expiresAt = expiresAt,
			daysLeft = math.max(0, (expiresAt - now) / 86400),
		}
	end
	table.sort(mails, function(a, b) return a.expiresAt < b.expiresAt end)
	return { scannedAt = scannedAt, mails = mails }
end

-- Ablaufende Mails ueber ALLE Charaktere (Standard: innerhalb von 3 Tagen).
-- -> { { charKey, sender, subject, daysLeft, expiresAt }, ... } sortiert nach Ablauf
function API.GetExpiringMails(withinDays)
	withinDays = withinDays or 3
	local results = {}
	for _, charKey in ipairs(API.GetCharacterKeys()) do
		local mailbox = API.GetMails(charKey)
		for _, mail in ipairs((mailbox and mailbox.mails) or {}) do
			if mail.daysLeft <= withinDays then
				results[#results + 1] = {
					charKey = charKey,
					sender = mail.sender,
					subject = mail.subject,
					daysLeft = mail.daysLeft,
					expiresAt = mail.expiresAt,
				}
			end
		end
	end
	table.sort(results, function(a, b) return a.expiresAt < b.expiresAt end)
	return results
end

-- Gildenbanken (0.16.0): { { name, scannedAt }, ... } sortiert nach Name
function API.GetGuilds()
	if not Exo.Store:IsReady() then return {} end
	local list = {}
	for _, guild in pairs(Exo.Store:GetGuilds()) do
		list[#list + 1] = { name = guild.name, scannedAt = guild.scannedAt }
	end
	table.sort(list, function(a, b) return (a.name or "") < (b.name or "") end)
	return list
end

-- Konto-Transparenz (0.17.0) ----------------------------------------------------------

-- Ruf-Staende eines Charakters, sortiert nach Fraktionsname.
-- -> { { factionID, name, standingID, value, max }, ... }
function API.GetReputations(charKey)
	if not Exo.Store:IsReady() then return {} end
	local char = Exo.Store:GetCharacter(charKey)
	if not char then return {} end
	local list = {}
	for factionID, rep in pairs(char.reputations or {}) do
		list[#list + 1] = {
			factionID = factionID,
			name = rep.name or "?",
			standingID = rep.standingID or 4,
			value = rep.value or 0,
			max = rep.max or 0,
		}
	end
	table.sort(list, function(a, b) return a.name < b.name end)
	return list
end

-- Aktive Quests eines Charakters, sortiert nach Titel.
-- -> { { questID, title }, ... }
function API.GetQuests(charKey)
	if not Exo.Store:IsReady() then return {} end
	local char = Exo.Store:GetCharacter(charKey)
	if not char then return {} end
	local list = {}
	for questID, title in pairs(char.quests or {}) do
		if type(title) == "string" then
			list[#list + 1] = { questID = questID, title = title }
		end
	end
	table.sort(list, function(a, b)
		if a.title ~= b.title then return a.title < b.title end
		return a.questID < b.questID
	end)
	return list
end

-- Gold-Summen pro Realm (absteigend nach Gold).
-- -> { { realm, gold, chars }, ... }
function API.GetGoldByRealm()
	local byRealm = {}
	for _, charKey in ipairs(API.GetCharacterKeys()) do
		local summary = API.GetCharacterSummary(charKey)
		if summary then
			local realm = summary.realm ~= "" and summary.realm or "?"
			local entry = byRealm[realm]
			if not entry then
				entry = { realm = realm, gold = 0, chars = 0 }
				byRealm[realm] = entry
			end
			entry.gold = entry.gold + (summary.gold or 0)
			entry.chars = entry.chars + 1
		end
	end
	local list = {}
	for _, entry in pairs(byRealm) do list[#list + 1] = entry end
	table.sort(list, function(a, b)
		if a.gold ~= b.gold then return a.gold > b.gold end
		return a.realm < b.realm
	end)
	return list
end

-- Schluesselsteine aller Charaktere, hoechster zuerst (1.0.0).
-- -> { { charKey, name, classID, mapName, level }, ... }
function API.GetKeystones()
	local list = {}
	for _, charKey in ipairs(API.GetCharacterKeys()) do
		local mplus = API.GetMythicPlus(charKey)
		local keystone = mplus and mplus.keystone
		if keystone and (keystone.level or 0) > 0 then
			local meta = API.GetCharacterInfo(charKey)
			list[#list + 1] = {
				charKey = charKey,
				name = (meta and meta.name ~= "" and meta.name) or charKey,
				classID = meta and meta.classID,
				mapName = keystone.name or "?",
				level = keystone.level,
			}
		end
	end
	table.sort(list, function(a, b)
		if a.level ~= b.level then return a.level > b.level end
		return a.name < b.name
	end)
	return list
end

-- Scan-Status (1.1.0): welche manuellen Scans fehlen diesem Charakter noch?
-- -> { bank = bool, mails = bool, missingRecipes = { "Alchemie", ... } } oder nil
function API.GetScanStatus(charKey)
	if not Exo.Store:IsReady() then return nil end
	local char = Exo.Store:GetCharacter(charKey)
	if not char then return nil end

	local missingRecipes = {}
	for _, prof in pairs(char.professions or {}) do
		if next(prof.recipes or {}) == nil then
			missingRecipes[#missingRecipes + 1] = prof.name or "?"
		end
	end
	table.sort(missingRecipes)

	return {
		bank = next(char.bank or {}) ~= nil,
		mails = type(char.mails) == "table" and char.mails.scannedAt ~= nil,
		missingRecipes = missingRecipes,
	}
end

-- Gildensteuer (1.2.0) ----------------------------------------------------------------

-- Steuerstand eines Charakters. -> { income, owed } (Kupfer, 0 wenn nie erfasst)
function API.GetGuildTax(charKey)
	if not Exo.Store:IsReady() then return { income = 0, owed = 0 } end
	local char = Exo.Store:GetCharacter(charKey)
	local data = (char and char.guildtax) or {}
	return { income = data.income or 0, owed = data.owed or 0 }
end

-- Alle konfigurierten Steuersaetze. -> { { guild, rate } } sortiert nach Name
function API.GetGuildTaxRates()
	if not Exo.Store:IsReady() then return {} end
	local list = {}
	for key, value in pairs(Exo.Store:GetAccount().options or {}) do
		local guild = key:match("^guildtax%.rate%.(.+)$")
		local rate = guild and tonumber(value)
		if guild and rate and rate > 0 then
			list[#list + 1] = { guild = guild, rate = rate }
		end
	end
	table.sort(list, function(a, b) return a.guild < b.guild end)
	return list
end

-- Bericht ueber alle Gilden mit Steuersatz oder offenen Betraegen.
-- -> { guilds = { { guild, rate, owed, income,
--                   chars = { { charKey, name, classID, owed, income } } } },
--      totalOwed }
function API.GetGuildTaxReport()
	local byGuild = {}
	local totalOwed = 0
	for _, charKey in ipairs(API.GetCharacterKeys()) do
		local meta = API.GetCharacterInfo(charKey)
		local guild = meta and meta.guild or ""
		if guild ~= "" then
			local tax = API.GetGuildTax(charKey)
			local rate = Exo.Collectors.GuildTax
				and Exo.Collectors.GuildTax.GetRate(guild) or 0
			if rate > 0 or tax.owed > 0 then
				local entry = byGuild[guild]
				if not entry then
					entry = { guild = guild, rate = rate, owed = 0, income = 0, chars = {} }
					byGuild[guild] = entry
				end
				entry.owed = entry.owed + tax.owed
				entry.income = entry.income + tax.income
				totalOwed = totalOwed + tax.owed
				entry.chars[#entry.chars + 1] = {
					charKey = charKey,
					name = (meta.name ~= "" and meta.name) or charKey,
					classID = meta.classID,
					owed = tax.owed,
					income = tax.income,
				}
			end
		end
	end

	-- Gilden mit konfiguriertem Satz erscheinen auch OHNE zugeordnete Chars
	-- (meta.guild wird erst beim naechsten Login des Chars erkannt)
	for _, entry in ipairs(API.GetGuildTaxRates()) do
		if not byGuild[entry.guild] then
			byGuild[entry.guild] = { guild = entry.guild, rate = entry.rate,
				owed = 0, income = 0, chars = {} }
		end
	end

	local guilds = {}
	for _, entry in pairs(byGuild) do
		table.sort(entry.chars, function(a, b)
			if a.owed ~= b.owed then return a.owed > b.owed end
			return a.name < b.name
		end)
		guilds[#guilds + 1] = entry
	end
	table.sort(guilds, function(a, b) return a.guild < b.guild end)
	return { guilds = guilds, totalOwed = totalOwed }
end

-- Freie/gesamte Plaetze der Kriegsmeuten-Bank (1.2.1). -> { free, size } | nil
function API.GetWarbandSpace()
	if not Exo.Store:IsReady() then return nil end
	local free, size = 0, 0
	for _, bag in pairs(Exo.Store:GetAccount().warbandBank or {}) do
		if type(bag) == "table" and (bag.size or 0) > 0 then
			size = size + bag.size
			local bagFree = bag.free
			if bagFree == nil then -- aeltere Scans ohne free-Feld
				local occupied = 0
				for _ in pairs(bag.items or {}) do occupied = occupied + 1 end
				bagFree = bag.size - occupied
			end
			free = free + bagFree
		end
	end
	return { free = free, size = size }
end

-- Auktionen (1.3.0) -------------------------------------------------------------------

-- Maximale Restsekunden je Restzeit-Band (Enum.AuctionHouseTimeLeft)
local AUCTION_BAND_SECONDS = { [0] = 1800, [1] = 7200, [2] = 43200, [3] = 172800 }

-- Auktionen eines Charakters inkl. spaetestem Ablauf (offline weitergerechnet).
-- -> { scannedAt, auctions = { { itemID, qty, buyout, bid, sold,
--      timeLeftBand, expiresBy } } } | nil (nie gescannt)
function API.GetAuctions(charKey)
	if not Exo.Store:IsReady() then return nil end
	local char = Exo.Store:GetCharacter(charKey)
	if not char or not char.auctions or not char.auctions.list then return nil end

	local scannedAt = char.auctions.scannedAt or 0
	local auctions = {}
	for _, auction in ipairs(char.auctions.list) do
		auctions[#auctions + 1] = {
			itemID = auction.itemID,
			qty = auction.qty or 1,
			buyout = auction.buyout or 0,
			bid = auction.bid or 0,
			sold = auction.sold or false,
			timeLeftBand = auction.timeLeftBand or 3,
			expiresBy = scannedAt
				+ (AUCTION_BAND_SECONDS[auction.timeLeftBand or 3] or 172800),
		}
	end
	table.sort(auctions, function(a, b) return a.expiresBy < b.expiresBy end)
	return { scannedAt = scannedAt, auctions = auctions }
end

-- Zusammenfassung ueber alle Charaktere mit Auktionen.
-- -> { chars = { { charKey, name, classID, count, soldCount, buyoutTotal,
--      soonestBand } }, totalCount, totalBuyout }
function API.GetAuctionSummary()
	local chars, totalCount, totalBuyout = {}, 0, 0
	for _, charKey in ipairs(API.GetCharacterKeys()) do
		local data = API.GetAuctions(charKey)
		if data and #data.auctions > 0 then
			local entry = { charKey = charKey, count = 0, soldCount = 0,
				buyoutTotal = 0, soonestBand = nil }
			local meta = API.GetCharacterInfo(charKey)
			entry.name = (meta and meta.name ~= "" and meta.name) or charKey
			entry.classID = meta and meta.classID
			for _, auction in ipairs(data.auctions) do
				if auction.sold then
					entry.soldCount = entry.soldCount + 1
				else
					entry.count = entry.count + 1
					entry.buyoutTotal = entry.buyoutTotal + auction.buyout
					if not entry.soonestBand
						or auction.timeLeftBand < entry.soonestBand then
						entry.soonestBand = auction.timeLeftBand
					end
				end
			end
			if entry.count > 0 or entry.soldCount > 0 then
				totalCount = totalCount + entry.count
				totalBuyout = totalBuyout + entry.buyoutTotal
				chars[#chars + 1] = entry
			end
		end
	end
	table.sort(chars, function(a, b)
		if a.buyoutTotal ~= b.buyoutTotal then return a.buyoutTotal > b.buyoutTotal end
		return a.name < b.name
	end)
	return { chars = chars, totalCount = totalCount, totalBuyout = totalBuyout }
end

-- "Kann ich das craften?" (1.4.0): Materialabgleich gegen ALLE Bestaende
-- (Taschen, Bank, Kriegsmeute, Gildenbank -- Auktionen zaehlen NICHT, das
-- liegt ja gerade nicht greifbar herum).
-- -> nil, wenn Rezept unbekannt oder noch im Alt-Format ohne Reagenzien;
--    sonst { craftable = bool, reagents = { { itemID, need, have } } }
function API.CanCraft(recipeID)
	if not Exo.Store:IsReady() then return nil end

	-- Rezept in irgendeinem Beruf irgendeines Chars finden (neues Format)
	local recipe
	for _, charKey in ipairs(API.GetCharacterKeys()) do
		local char = Exo.Store:GetCharacter(charKey)
		for _, prof in pairs((char and char.professions) or {}) do
			local entry = prof.recipes and prof.recipes[recipeID]
			if type(entry) == "table" and type(entry.reagents) == "table" then
				recipe = entry
				break
			end
		end
		if recipe then break end
	end
	if not recipe or #recipe.reagents == 0 then return nil end

	local reagents = {}
	local craftable = true
	for _, reagent in ipairs(recipe.reagents) do
		local counts = API.GetItemCounts(reagent.itemID)
		local have = counts.total
		for _, charEntry in pairs(counts.chars) do
			have = have - (charEntry.auctions or 0)
		end
		if have < reagent.qty then craftable = false end
		reagents[#reagents + 1] = {
			itemID = reagent.itemID,
			need = reagent.qty,
			have = have,
		}
	end
	return { craftable = craftable, reagents = reagents }
end

-- Einstellungen (accountweit, z. B. Designer-/UI-Optionen) ----------------------------
-- Flache String-Keys ("theme.accent", "charRow.gold", ...); Werte sind
-- Strings/Zahlen/Booleans. `nil` loescht den Eintrag.

function API.GetOption(key, default)
	if not Exo.Store:IsReady() then return default end
	local options = Exo.Store:GetAccount().options
	local value = options[key]
	if value == nil then return default end
	return value
end

function API.SetOption(key, value)
	if not Exo.Store:IsReady() then return false end
	Exo.Store:GetAccount().options[key] = value
	return true
end

-- Events fuer Dritt-Addons (duenner Alias auf den EventBus) ---------------------------

function API.RegisterCallback(event, fn, owner)
	Exo.EventBus:Register(event, fn, owner)
end

function API.UnregisterCallback(event, ownerOrFn)
	Exo.EventBus:Unregister(event, ownerOrFn)
end
