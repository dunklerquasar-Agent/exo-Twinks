-- Collectors/Currencies.lua (Neuimplementierung, Phase-2-Wiederholung)
-- Alle Waehrungen des aktuellen Charakters, gespeichert nach Currency-ID.
-- Header-Zeilen filtert bereits der WowAPI-Wrapper (GetCurrencyEntry -> nil).
--
-- Event-Strategie:
--   PLAYER_ENTERING_WORLD / CURRENCY_DISPLAY_UPDATE -> Scan entprellt
--   (CURRENCY_DISPLAY_UPDATE feuert bei jedem Waehrungsgewinn, oft mehrfach)

local _, Exo = ...

local Collector = {}
Exo.Collectors = Exo.Collectors or {}
Exo.Collectors.Currencies = Collector

local SCAN_DEBOUNCE = 1

function Collector.Scan()
	local Store = Exo.Store
	if not Store:IsReady() then return end

	local W = Exo.WowAPI
	local currencies = {}

	for index = 1, W.GetCurrencyCount() do
		local currencyID, name, qty, max = W.GetCurrencyEntry(index)
		if currencyID then
			currencies[currencyID] = { name = name, qty = qty, max = max }
		end
	end

	Store:WriteCharacterData(Store:GetCurrentKey(), "currencies", currencies)
end

local function debouncedScan()
	Exo.Scheduler:Debounce("currencies-scan", SCAN_DEBOUNCE, Collector.Scan)
end

Exo.EventBus:RegisterWowEvent("PLAYER_ENTERING_WORLD", debouncedScan, Collector)
Exo.EventBus:RegisterWowEvent("CURRENCY_DISPLAY_UPDATE", debouncedScan, Collector)
