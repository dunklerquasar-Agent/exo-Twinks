-- ExoTwinksCore/Collectors/Auctions.lua
-- Eigene Auktionen (1.3.0): beim Oeffnen des Auktionshauses werden die
-- Owned-Auktionen abgefragt und gespeichert. Das Restzeit-Band wird
-- zusammen mit dem Scan-Zeitpunkt abgelegt, damit die Anzeige offline
-- weiterrechnen kann (wie bei Mails).
--
-- Datenlayout (Sektion "auctions"):
--   { scannedAt, list = { { itemID, qty, buyout, bid, timeLeftBand, sold } } }

local Collector = {}
local _, Exo = ...
Exo.Collectors = Exo.Collectors or {}
Exo.Collectors.Auctions = Collector

local SCAN_DEBOUNCE = 0.5
local ahOpen = false

function Collector.ScanOwned()
	local Store = Exo.Store
	if not Store:IsReady() or not ahOpen then return end

	local list = Exo.WowAPI.GetOwnedAuctions()
	if not list then return end -- Client liefert (noch) nichts

	Store:WriteCharacterData(Store:GetCurrentKey(), "auctions", {
		scannedAt = Exo.WowAPI.Now(),
		list = list,
	})
end

function Collector.IsAuctionHouseOpen()
	return ahOpen
end

-- Event-Verkabelung ---------------------------------------------------------------

local Bus = Exo.EventBus

Bus:RegisterWowEvent("AUCTION_HOUSE_SHOW", function()
	ahOpen = true
	Exo.WowAPI.QueryOwnedAuctions() -- Antwort kommt als OWNED_AUCTIONS_UPDATED
end, Collector)

Bus:RegisterWowEvent("AUCTION_HOUSE_CLOSED", function()
	ahOpen = false
end, Collector)

Bus:RegisterWowEvent("OWNED_AUCTIONS_UPDATED", function()
	if ahOpen then
		Exo.Scheduler:Debounce("auctions-owned", SCAN_DEBOUNCE, Collector.ScanOwned)
	end
end, Collector)
