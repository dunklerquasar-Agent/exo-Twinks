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

	-- Komplett-Scan (1.16.0): zugeklappte Kategorien (inkl. "Nicht verwendet")
	-- voruebergehend oeffnen, sonst fehlen deren Waehrungen in der Liste.
	-- Seit 1.17.0 wird zusaetzlich die Kategorie (cat) + ihre Position in der
	-- Spiel-Reihenfolge (catOrder, Midnight = 1) je Waehrung gespeichert.
	local reCollapse = W.ExpandAllCurrencyHeaders()
	local cat, catOrder = nil, 0
	for index = 1, W.GetCurrencyCount() do
		local headerName = W.GetCurrencyHeader(index)
		if headerName then
			cat, catOrder = headerName, catOrder + 1
		else
			local currencyID, name, qty, max, acc = W.GetCurrencyEntry(index)
			if currencyID then
				currencies[currencyID] = { name = name, qty = qty, max = max,
					acc = acc or nil, cat = cat,
					catOrder = cat and catOrder or nil }
			end
		end
	end
	W.CollapseCurrencyHeaders(reCollapse)

	Store:WriteCharacterData(Store:GetCurrentKey(), "currencies", currencies)
end

local function debouncedScan()
	Exo.Scheduler:Debounce("currencies-scan", SCAN_DEBOUNCE, Collector.Scan)
end

Exo.EventBus:RegisterWowEvent("PLAYER_ENTERING_WORLD", debouncedScan, Collector)
Exo.EventBus:RegisterWowEvent("CURRENCY_DISPLAY_UPDATE", debouncedScan, Collector)
