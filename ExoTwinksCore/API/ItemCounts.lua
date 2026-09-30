-- API/ItemCounts.lua
-- Accountweiter Item-Index: itemID -> wer besitzt wieviel (Taschen/Bank/Kriegsmeute).
-- Herzstueck fuer Tooltip ("Besessen von ...") und die Suche.
--
-- Performance-Konzept:
--   * Der Index wird LAZY beim ersten Zugriff gebaut (ein Durchlauf ueber alle Chars)
--   * und bei Datenaenderungen nur INVALIDIERT (nicht sofort neu gebaut).
--   * Tooltip-Zugriffe treffen damit fast immer den fertigen Cache -> O(1).

local _, Exo = ...

local API = Exo.API

local cache = nil -- itemID -> { total, warband, guilds = { [name] = n }, chars = { [charKey] = { bags, bank } } }

-- Aufbau ---------------------------------------------------------------------------

local function addToIndex(itemID, charKey, source, count)
	local entry = cache[itemID]
	if not entry then
		entry = { total = 0, warband = 0, guilds = {}, chars = {} }
		cache[itemID] = entry
	end
	entry.total = entry.total + count

	if source == "warband" then
		entry.warband = entry.warband + count
	elseif source == "guild" then
		entry.guilds[charKey] = (entry.guilds[charKey] or 0) + count
	else
		local charEntry = entry.chars[charKey]
		if not charEntry then
			charEntry = { bags = 0, bank = 0, auctions = 0 }
			entry.chars[charKey] = charEntry
		end
		charEntry[source] = charEntry[source] + count
	end
end

local function indexBagSet(bagSet, charKey, source)
	if type(bagSet) ~= "table" then return end
	for _, bag in pairs(bagSet) do
		if type(bag) == "table" and type(bag.items) == "table" then
			for _, item in pairs(bag.items) do
				if item.id then
					addToIndex(item.id, charKey, source, item.count or 1)
				end
			end
		end
	end
end

local function buildCache()
	cache = {}
	if not Exo.Store:IsReady() then return end

	for _, charKey in ipairs(Exo.Store:GetCharacterKeys()) do
		local char = Exo.Store:GetCharacter(charKey)
		indexBagSet(char.bags, charKey, "bags")
		indexBagSet(char.bank, charKey, "bank")
		-- Auktionshaus (1.3.0): aktive Auktionen zaehlen als Bestand
		local auctions = char.auctions and char.auctions.list
		for _, auction in ipairs(auctions or {}) do
			if auction.itemID and not auction.sold then
				addToIndex(auction.itemID, charKey, "auctions", auction.qty or 1)
			end
		end
	end
	indexBagSet(Exo.Store:GetAccount().warbandBank, nil, "warband")
	-- Gildenbanken (0.16.0): "charKey" ist hier der Gildenname
	for guildName, guild in pairs(Exo.Store:GetGuilds()) do
		indexBagSet(guild.bank, guildName, "guild")
	end
end

local function ensureCache()
	if not cache then
		buildCache()
	end
end

local function copyEntry(itemID, entry)
	local copy = { itemID = itemID, total = entry.total, warband = entry.warband,
		guilds = {}, chars = {} }
	for charKey, charEntry in pairs(entry.chars) do
		copy.chars[charKey] = { bags = charEntry.bags, bank = charEntry.bank,
			auctions = charEntry.auctions or 0 }
	end
	for guildName, count in pairs(entry.guilds or {}) do
		copy.guilds[guildName] = count
	end
	return copy
end

-- Oeffentliche API -------------------------------------------------------------------

-- Liefert immer eine (Kopie einer) Count-Struktur, auch bei 0 Treffern.
function API.GetItemCounts(itemID)
	ensureCache()
	local entry = cache[itemID]
	if not entry then
		return { itemID = itemID, total = 0, warband = 0, chars = {} }
	end
	return copyEntry(itemID, entry)
end

-- Durchsucht alle bekannten Items; matcher(itemID) -> boolean.
-- Rueckgabe: Array von Count-Kopien (unsortiert; Sortierung ist Sache des Aufrufers).
function API.SearchItems(matcher)
	ensureCache()
	local results = {}
	for itemID, entry in pairs(cache) do
		if matcher(itemID) then
			results[#results + 1] = copyEntry(itemID, entry)
		end
	end
	return results
end

-- Invalidierung ------------------------------------------------------------------------

local function invalidate()
	cache = nil
end

Exo.EventBus:Register("EXO_CHAR_UPDATED", function(_, _, section)
	if section == "bags" or section == "bank" or section == "auctions" then
		invalidate()
	end
end, API)

Exo.EventBus:Register("EXO_ACCOUNT_UPDATED", function(_, section)
	if section == "warbandBank" then
		invalidate()
	end
end, API)

Exo.EventBus:Register("EXO_CHAR_DELETED", invalidate, API)
Exo.EventBus:Register("EXO_GUILD_UPDATED", invalidate, API)
Exo.EventBus:Register("EXO_LEGACY_IMPORT_DONE", invalidate, API)

-- Inventar-Uebersicht ------------------------------------------------------------------

-- Aggregiert ein Bag-Set (bags/bank) eines Charakters in byId
local function aggregateBagSet(bagSet, byId, field)
	if type(bagSet) ~= "table" then return end
	for _, bag in pairs(bagSet) do
		if type(bag) == "table" and type(bag.items) == "table" then
			for _, item in pairs(bag.items) do
				if item.id then
					local entry = byId[item.id]
					if not entry then
						entry = { itemID = item.id, bags = 0, bank = 0, total = 0 }
						byId[item.id] = entry
					end
					local count = item.count or 1
					entry[field] = entry[field] + count
					entry.total = entry.total + count
					if item.wb then entry.wb = true end
				end
			end
		end
	end
end

local function toArray(byId)
	local list = {}
	for _, entry in pairs(byId) do
		list[#list + 1] = entry
	end
	return list
end

-- Alle Items EINES Charakters, aggregiert ueber Taschen + Bank.
-- Rueckgabe: Array von { itemID, bags, bank, total } (unsortiert, immer Kopien).
function API.GetCharacterItems(charKey)
	local char = Exo.Store:IsReady() and Exo.Store:GetCharacter(charKey)
	if not char then return {} end

	local byId = {}
	aggregateBagSet(char.bags, byId, "bags")
	aggregateBagSet(char.bank, byId, "bank")
	return toArray(byId)
end

-- Nur die BANK eines Charakters (1.9.0, Reiter "Bank"), gleiche Struktur.
function API.GetCharacterBankItems(charKey)
	local char = Exo.Store:IsReady() and Exo.Store:GetCharacter(charKey)
	if not char then return {} end

	local byId = {}
	aggregateBagSet(char.bank, byId, "bank")
	return toArray(byId)
end

-- Alle Items der Kriegsmeutenbank (accountweit), gleiche Struktur (Zaehler in total).
function API.GetWarbandItems()
	if not Exo.Store:IsReady() then return {} end

	local byId = {}
	aggregateBagSet(Exo.Store:GetAccount().warbandBank, byId, "bags")
	for _, entry in pairs(byId) do
		entry.bags, entry.bank = 0, 0 -- Kriegsmeute kennt keine Taschen/Bank-Aufteilung
	end
	return toArray(byId)
end

-- Kriegsmeutengebundene Items je Charakter (1.7.0): welcher Char hortet
-- welche warbound Teile in Taschen und Bank? Chars ohne Treffer werden
-- weggelassen. Rueckgabe: Array { charKey, name, realm, classID, items },
-- items im GetCharacterItems-Format { itemID, bags, bank, total }.
function API.GetWarboundByCharacter()
	local result = {}
	for _, charKey in ipairs(API.GetCharacterKeys()) do
		local filtered = {}
		for _, entry in ipairs(API.GetCharacterItems(charKey)) do
			-- Nur VERSCHIEBBARE Teile (1.8.1): Exemplar-Flag oder dauerhaft
			-- accountgebundener Typ; bereits angelegte 'bis zum Anlegen'-Items
			-- sind seelengebunden und bleiben draussen.
			if entry.wb or Exo.WowAPI.IsPermanentWarbound(entry.itemID) then
				filtered[#filtered + 1] = entry
			end
		end
		if #filtered > 0 then
			local meta = API.GetCharacterInfo(charKey) or {}
			result[#result + 1] = {
				charKey = charKey,
				name = meta.name or charKey,
				realm = meta.realm or "",
				classID = meta.classID,
				items = filtered,
			}
		end
	end
	table.sort(result, function(a, b)
		if a.realm ~= b.realm then return a.realm < b.realm end
		return a.name < b.name
	end)
	return result
end

-- Items einer Gildenbank (1.2.1), gleiches Format wie GetWarbandItems.
function API.GetGuildItems(guildName)
	if not Exo.Store:IsReady() then return {} end
	local guild = Exo.Store:GetGuilds()[guildName]
	if not guild then return {} end

	local byId = {}
	aggregateBagSet(guild.bank, byId, "bags")
	for _, entry in pairs(byId) do
		entry.bags, entry.bank = 0, 0
	end
	return toArray(byId)
end
