-- Collectors/Equipment.lua (Neuimplementierung, Phase-2-Wiederholung)
-- Angelegte Ausruestung (Item-ID + ilvl pro Slot) und Durchschnitts-Itemlevel.
--
-- Event-Strategie:
--   PLAYER_ENTERING_WORLD / PLAYER_EQUIPMENT_CHANGED -> Scan entprellt
--   (PLAYER_EQUIPMENT_CHANGED feuert beim Umziehen pro Slot einzeln)
--   ITEM_CHANGED -> Scan entprellt: feuert, wenn ein Item AN ORT UND STELLE
--   aufgewertet wird (M+-/Saison-Aufwertung eines angelegten Items)

local _, Exo = ...

local Collector = {}
Exo.Collectors = Exo.Collectors or {}
Exo.Collectors.Equipment = Collector

local SCAN_DEBOUNCE = 0.5

function Collector.Scan()
	local Store = Exo.Store
	if not Store:IsReady() then return end

	local W = Exo.WowAPI
	local slots = {}

	for slot = W.EQUIPMENT_SLOTS.first, W.EQUIPMENT_SLOTS.last do
		local itemID, ilvl = W.GetInventoryItem(slot)
		if itemID then
			slots[slot] = { id = itemID, ilvl = ilvl }
		end
	end

	local avgOverall, avgEquipped = W.GetAverageItemLevel()

	Store:WriteCharacterData(Store:GetCurrentKey(), "equipment", {
		avgItemLevel = avgOverall,
		avgItemLevelEquipped = avgEquipped,
		slots = slots,
	})
end

local function debouncedScan()
	Exo.Scheduler:Debounce("equipment-scan", SCAN_DEBOUNCE, Collector.Scan)
end

Exo.EventBus:RegisterWowEvent("PLAYER_ENTERING_WORLD", debouncedScan, Collector)
Exo.EventBus:RegisterWowEvent("PLAYER_EQUIPMENT_CHANGED", debouncedScan, Collector)
Exo.EventBus:RegisterWowEvent("ITEM_CHANGED", debouncedScan, Collector)
