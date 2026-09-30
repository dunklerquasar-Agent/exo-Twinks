-- Storage/LegacyImport.lua
-- Einmaliger, non-destruktiver Import aus dem alten Altoholic/DataStore (Thaoky).
--
-- Gelesene Legacy-SavedVariables (Struktur per Code-Analyse von DataStore 2026-09 verifiziert):
--   DataStore_CharacterIDs      = { Set = { ["Default.Realm.Name"] = id }, ... }
--   DataStore_Characters_Info   = { [id] = { name, money, played, playedThisLevel,
--                                            zone, subZone, lastLogoutTimestamp,
--                                            BaseInfo = level         (Bits 0-6)
--                                                     + classID * 2^7 (Bits 7-10)
--                                                     + raceID  * 2^11(Bits 11-17)
--                                                     + gender  * 2^18(Bits 18-19) } }
--   DataStore_Containers_Characters = { [id] = { Containers = { [bagID] = {
--                                       items = { [slot] = count      (Bits 0-15)
--                                                        + itemID*2^16 (Bits 16+) },
--                                       info  = ... + size*2^3 (Bits 3-9) ... } } } }
--     bagID 0-5 = Taschen (inkl. Reagenzientasche 5), 6-12/98/-1/-7 = Bank(-Tabs)
--   DataStore_Containers_Warbank    = { [tabID 13-17] = { items = ... } }  (accountweit)
--   DataStore_Inventory_Characters  = { [id] = { averageItemLvl = zahl } }
--
-- Garantien:
--  * Legacy-Daten werden NUR gelesen, niemals veraendert oder geloescht.
--  * Bereits vorhandene Charaktere in der neuen DB werden uebersprungen
--    (neue Daten gewinnen immer gegen alte).

local _, Exo = ...

local LegacyImport = {}
Exo.LegacyImport = LegacyImport

local MAX_LOGOUT_TIMESTAMP = 5000000000 -- Sentinel des Originals fuer "gerade eingeloggt"

-- Bit-Dekodierung (Lua 5.1-kompatibel, ohne bit-Library)
local function getBits(value, startBit, numBits)
	return math.floor(value / 2 ^ startBit) % 2 ^ numBits
end

local function decodeBaseInfo(baseInfo)
	baseInfo = tonumber(baseInfo) or 0
	return getBits(baseInfo, 0, 7),   -- level
	       getBits(baseInfo, 7, 4),   -- classID
	       getBits(baseInfo, 11, 7)   -- raceID
end

-- Container-Konvertierung -----------------------------------------------------------
-- Legacy: items[slot] = count (Bits 0-15) + itemID * 2^16 (Bits 16+)
-- Neu:    { size, free, items = { [slot] = { id, count } } }  (Format der Collectors)

local BAG_MAX = 5 -- Taschen 0-5 (inkl. Reagenzientasche); alles andere = Bank

-- Schema-Defaults sind leere Tabellen -> "keine Daten" heisst nil ODER leer
local function isEmpty(t)
	return type(t) ~= "table" or next(t) == nil
end

local function convertContainer(legacyBag)
	local items, used, maxSlot = {}, 0, 0
	for slot, packed in pairs(legacyBag.items or {}) do
		local value = tonumber(packed)
		if type(slot) == "number" and value and value >= 2 ^ 16 then
			local count = value % 2 ^ 16
			items[slot] = { id = math.floor(value / 2 ^ 16), count = count > 0 and count or 1 }
			used = used + 1
			if slot > maxSlot then maxSlot = slot end
		end
	end
	local size = legacyBag.info and getBits(legacyBag.info, 3, 7) or 0
	if size < maxSlot then size = maxSlot end
	return { size = size, free = math.max(0, size - used), items = items }
end

-- Taschen + Bank eines Legacy-Charakters uebernehmen.
-- Nur fehlende Sektionen werden gefuellt (neue Daten gewinnen immer).
local function importContainers(char, id)
	local db = Exo.WowAPI.GetGlobal("DataStore_Containers_Characters")
	local legacy = type(db) == "table" and db[id]
	local containers = type(legacy) == "table" and legacy.Containers
	if type(containers) ~= "table" then return false end

	local bags, bank = {}, {}
	for bagID, bag in pairs(containers) do
		if type(bagID) == "number" and type(bag) == "table"
			and type(bag.items) == "table" and next(bag.items) then
			local converted = convertContainer(bag)
			if bagID >= 0 and bagID <= BAG_MAX then
				bags[bagID] = converted
			else
				bank[bagID] = converted
			end
		end
	end

	local changed = false
	if isEmpty(char.bags) and next(bags) then
		char.bags = bags
		changed = true
	end
	if isEmpty(char.bank) and next(bank) then
		char.bank = bank
		changed = true
	end
	return changed
end

-- Itemlevel aus DataStore_Inventory (nur wenn noch keine eigenen Equipment-Daten da sind)
local function importEquipment(char, id)
	if not isEmpty(char.equipment) then return false end
	local db = Exo.WowAPI.GetGlobal("DataStore_Inventory_Characters")
	local legacy = type(db) == "table" and db[id]
	local ail = type(legacy) == "table" and tonumber(legacy.averageItemLvl)
	if ail and ail > 0 then
		char.equipment = { avgItemLevel = ail, avgItemLevelEquipped = ail, slots = {} }
		return true
	end
	return false
end

-- Kriegsmeutenbank (accountweit, Tabs 13-17) -- nur wenn wir selbst noch nichts gescannt haben
local function importWarband()
	local account = Exo.Store:GetAccount()
	if not isEmpty(account.warbandBank) then
		return false
	end
	local db = Exo.WowAPI.GetGlobal("DataStore_Containers_Warbank")
	if type(db) ~= "table" then return false end

	local tabs = {}
	for tabID, tab in pairs(db) do
		if type(tabID) == "number" and type(tab) == "table"
			and type(tab.items) == "table" and next(tab.items) then
			tabs[tabID] = convertContainer(tab)
		end
	end
	if next(tabs) then
		Exo.Store:WriteAccountData("warbandBank", tabs)
		return true
	end
	return false
end

-- Scan: was ist da? ---------------------------------------------------------------
-- Liefert einen Report, ohne irgendetwas zu schreiben.

function LegacyImport:Scan()
	local W = Exo.WowAPI
	local ids = W.GetGlobal("DataStore_CharacterIDs")
	local infos = W.GetGlobal("DataStore_Characters_Info")

	local report = {
		found = false,
		total = 0,        -- Legacy-Charaktere insgesamt
		importable = 0,   -- davon noch nicht in der neuen DB
		keys = {},
	}

	if type(ids) ~= "table" or type(ids.Set) ~= "table" or type(infos) ~= "table" then
		return report
	end

	report.found = true
	for charKey, id in pairs(ids.Set) do
		if type(infos[id]) == "table" then
			report.total = report.total + 1
			if not Exo.Store:GetCharacter(charKey) then
				report.importable = report.importable + 1
				report.keys[#report.keys + 1] = charKey
			end
		end
	end
	table.sort(report.keys)
	return report
end

-- Import ----------------------------------------------------------------------------
-- Rueckgabe: imported, skipped, supplemented
--   imported     = neu angelegte Charaktere
--   skipped      = bereits vorhandene (Meta/Gold NICHT ueberschrieben)
--   supplemented = vorhandene Chars, denen fehlende Taschen/Bank/iLvl ergaenzt wurden

function LegacyImport:Import()
	local W = Exo.WowAPI
	local report = self:Scan()
	if not report.found then
		return 0, 0, 0
	end

	local ids = W.GetGlobal("DataStore_CharacterIDs")
	local infos = W.GetGlobal("DataStore_Characters_Info")

	local imported, skipped, supplemented = 0, 0, 0

	for charKey, id in pairs(ids.Set) do
		local info = infos[id]
		-- ohne Info-Datensatz: still ueberspringen; vorhandene Chars: nur Luecken fuellen
		if type(info) == "table" and Exo.Store:GetCharacter(charKey) then
			skipped = skipped + 1
			local char = Exo.Store:GetCharacter(charKey)
			local changed = importContainers(char, id)
			if importEquipment(char, id) then changed = true end
			if changed then
				supplemented = supplemented + 1
				Exo.EventBus:Fire("EXO_CHAR_UPDATED", charKey, "legacy-import")
				Exo.Log:Debug("Legacy-Import: %s um Taschen/Bank/iLvl ergaenzt", charKey)
			end
		elseif type(info) == "table" then
			local char = Exo.Store:GetOrCreateCharacter(charKey)
			local account, realm, name = Exo.Schema.ParseCharKey(charKey)

			local level, classID, raceID = decodeBaseInfo(info.BaseInfo)
			local meta = char.meta
			meta.name = info.name or name or ""
			meta.realm = realm or ""
			meta.account = account or "Default"
			meta.level = level
			meta.classID = classID
			meta.raceID = raceID
			meta.zone = info.zone or ""
			meta.playedTotal = tonumber(info.played) or 0

			local logout = tonumber(info.lastLogoutTimestamp) or 0
			meta.lastSeen = (logout > 0 and logout < MAX_LOGOUT_TIMESTAMP) and logout or 0

			char.gold = tonumber(info.money) or 0

			-- Inventar + Itemlevel gehoeren zum Vollimport eines neuen Charakters
			importContainers(char, id)
			importEquipment(char, id)

			imported = imported + 1
			Exo.EventBus:Fire("EXO_CHAR_UPDATED", charKey, "legacy-import")
			Exo.Log:Debug("Legacy-Import: %s (Level %d)", charKey, level)
		end
	end

	local warbandImported = importWarband()

	if imported > 0 or supplemented > 0 or warbandImported then
		Exo.Log:Info("Legacy-Import: %d Charakter(e) uebernommen, %d uebersprungen, %d ergaenzt.",
			imported, skipped, supplemented)
		Exo.EventBus:Fire("EXO_LEGACY_IMPORT_DONE", imported, skipped)
	end
	return imported, skipped, supplemented
end
