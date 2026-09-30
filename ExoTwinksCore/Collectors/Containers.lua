-- Collectors/Containers.lua (Neuimplementierung, Phase-2-Wiederholung)
-- Tascheninhalte (immer) sowie Bank + Kriegsmeutenbank (nur bei Bankbesuch:
-- der Client liefert Bankdaten ausschliesslich bei geoeffneter Bank).
--
-- Event-Strategie:
--   BAG_UPDATE / PLAYER_ENTERING_WORLD -> Taschen-Scan ENTPRELLT (Event-Stuerme!)
--   BANKFRAME_OPENED                   -> Sitzung an, Bank + Kriegsmeute sofort
--   PLAYERBANKSLOTS_CHANGED            -> Bank-Rescan entprellt (nur bei offener Bank)
--   BANKFRAME_CLOSED                   -> Sitzung aus
--
-- Datenlayout (Sektionen "bags"/"bank" bzw. account.warbandBank):
--   [bagID] = { size = n, free = n, items = { [slot] = { id, count } } }

local _, Exo = ...

local Collector = {}
Exo.Collectors = Exo.Collectors or {}
Exo.Collectors.Containers = Collector

local BAG_DEBOUNCE = 0.5
local bankIsOpen = false

-- Scan-Kern -----------------------------------------------------------------------

local function scanBag(bagID)
	local W = Exo.WowAPI
	local size = W.GetContainerNumSlots(bagID)
	if size == 0 then return nil end -- Tasche existiert nicht

	local bag = { size = size, free = 0, items = {} }
	bag.bagItemID = Exo.WowAPI.GetBagItemID(bagID) -- nil fuer Rucksack/Spezialfaecher
	for slot = 1, size do
		local itemID, count = W.GetContainerItem(bagID, slot)
		if itemID then
			bag.items[slot] = { id = itemID, count = count }
			-- Exemplar-Bindung (1.7.1): "kriegsmeutengebunden bis zum
			-- Anlegen" nur am konkreten Stueck erkennbar -> mitspeichern
			if W.IsSlotWarbound(bagID, slot) then
				bag.items[slot].wb = true
			end
		else
			bag.free = bag.free + 1
		end
	end
	return bag
end

local function scanBagList(bagIDs)
	local result = {}
	for _, bagID in ipairs(bagIDs) do
		result[bagID] = scanBag(bagID)
	end
	return result
end

-- Scans ------------------------------------------------------------------------------

function Collector.ScanBags()
	local Store = Exo.Store
	if not Store:IsReady() then return end

	-- Dynamisch (1.6.3): Rucksack + Taschen + Reagenzientasche aus Enum
	Store:WriteCharacterData(Store:GetCurrentKey(), "bags",
		scanBagList(Exo.WowAPI.GetCharacterBagIDs()))
end

function Collector.ScanBank()
	local Store = Exo.Store
	if not Store:IsReady() or not bankIsOpen then return end

	-- Dynamisch (1.6.2): Enum.BagIndex-Tabs, sonst klassische IDs --
	-- nicht vorhandene Faecher liefern Groesse 0 und werden ignoriert
	Store:WriteCharacterData(Store:GetCurrentKey(), "bank",
		scanBagList(Exo.WowAPI.GetBankBagIDs()))
end

function Collector.ScanWarband()
	local Store = Exo.Store
	if not Store:IsReady() or not bankIsOpen then return end

	-- Dynamisch (1.6.2): seit 11.2 beginnen die Kriegsmeuten-Tabs bei 12 --
	-- die alte feste Liste 13-17 hat Tab 1 komplett verpasst (Bugreport)!
	Store:WriteAccountData("warbandBank",
		scanBagList(Exo.WowAPI.GetWarbandBagIDs()))
end

-- Datenbereinigung (1.6.4): Vor dem 1.6.2-Fix landeten die Kriegsmeuten-
-- Tabs faelschlich in der CHAR-Bank (die alte feste Range 6-12 enthielt
-- ID 12 = Warband-Tab 1). Ergebnis: dieselben Items wurden pro Char als
-- "Bank" gezaehlt (z. B. 4x 616 = 2464 statt 616). Diese Altlasten werden
-- beim Login entfernt -- ohne dass jeder Char die Bank besuchen muss.
function Collector.CleanupStaleBankTabs()
	local Store = Exo.Store
	if not Store:IsReady() then return end

	local warbandIDs = {}
	for _, id in ipairs(Exo.WowAPI.GetWarbandBagIDs()) do
		warbandIDs[id] = true
	end

	for _, charKey in ipairs(Store:GetCharacterKeys()) do
		local char = Store:GetCharacter(charKey)
		local bank = char and char.bank
		if bank then
			local changed = false
			for bagID in pairs(bank) do
				if warbandIDs[bagID] then
					bank[bagID] = nil
					changed = true
				end
			end
			if changed then
				-- feuert EXO_CHAR_UPDATED -> Zaehler-Cache wird ungueltig
				Store:WriteCharacterData(charKey, "bank", bank)
			end
		end
	end
end

function Collector.IsBankOpen()
	return bankIsOpen
end

-- Event-Verkabelung ---------------------------------------------------------------------

local Bus = Exo.EventBus

local function debouncedBagScan()
	Exo.Scheduler:Debounce("containers-bags", BAG_DEBOUNCE, Collector.ScanBags)
end

local function debouncedBankScan()
	Exo.Scheduler:Debounce("containers-bank", BAG_DEBOUNCE, Collector.ScanBank)
end

local function debouncedWarbandScan()
	Exo.Scheduler:Debounce("containers-warband", BAG_DEBOUNCE, Collector.ScanWarband)
end

Bus:RegisterWowEvent("PLAYER_ENTERING_WORLD", debouncedBagScan, Collector)

-- Altlasten-Bereinigung sobald der Store steht (1.6.4)
Bus:Register("EXO_CORE_READY", Collector.CleanupStaleBankTabs, Collector)

-- BAG_UPDATE feuert MIT bagID -- auch fuer Bank- (6-12) und Kriegsmeuten-
-- Tabs (13-17), waehrend die Bank offen ist. Vorher wurde hier immer nur
-- der Taschen-Scan angestossen -> Aenderungen/Nachzuegler in der
-- Kriegsmeutenbank gingen verloren (Bugreport 1.6.1).
local function listContains(list, value)
	for _, entry in ipairs(list) do
		if entry == value then return true end
	end
	return false
end

Bus:RegisterWowEvent("BAG_UPDATE", function(_, bagID)
	if type(bagID) == "number" and bagID > Exo.WowAPI.BAG_IDS.last then
		-- Bank-/Kriegsmeuten-Bereich: per Mitgliedschaft routen (1.6.2),
		-- die IDs sind seit dem Bank-Umbau nicht mehr fest
		if listContains(Exo.WowAPI.GetWarbandBagIDs(), bagID) then
			if bankIsOpen then debouncedWarbandScan() end
			return
		elseif listContains(Exo.WowAPI.GetBankBagIDs(), bagID) then
			if bankIsOpen then debouncedBankScan() end
			return
		end
	end
	debouncedBagScan()
end, Collector)

Bus:RegisterWowEvent("BANKFRAME_OPENED", function()
	bankIsOpen = true
	Collector.ScanBank()
	Collector.ScanWarband()
	-- Nachzuegler-Scan (1.6.1): der Client laedt die Inhalte der
	-- Kriegsmeuten-Tabs oft erst NACH dem Event nach -- einmal spaeter
	-- nachfassen, sonst fehlen Items.
	Exo.Scheduler:Debounce("containers-warband-late", 1.0, Collector.ScanWarband)
	Exo.Scheduler:Debounce("containers-bank-late", 1.0, Collector.ScanBank)
end, Collector)

Bus:RegisterWowEvent("BANKFRAME_CLOSED", function()
	bankIsOpen = false
end, Collector)

Bus:RegisterWowEvent("PLAYERBANKSLOTS_CHANGED", function()
	if bankIsOpen then
		Exo.Scheduler:Debounce("containers-bank", BAG_DEBOUNCE, Collector.ScanBank)
	end
end, Collector)
