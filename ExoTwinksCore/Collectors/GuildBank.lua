-- ExoTwinksCore/Collectors/GuildBank.lua
-- Gildenbank (0.16.0): beim Oeffnen der Gildenbank werden alle Tabs im
-- BagSet-Format erfasst (gleiches Layout wie Taschen/Bank -> die Item-Suche
-- und die Zaehler koennen sie direkt mitverwenden).

local Collector = {}
local _, Exo = ...
Exo.Collectors = Exo.Collectors or {}
Exo.Collectors.GuildBank = Collector

local SCAN_DEBOUNCE = 0.5
local guildBankOpen = false

function Collector.ScanGuildBank()
	local Store = Exo.Store
	if not Store:IsReady() or not guildBankOpen then return end

	local guildName = Exo.WowAPI.GetGuildName()
	if not guildName then return end

	local bank = Exo.WowAPI.GetGuildBankContents()
	if bank then
		Store:WriteGuildBank(guildName, bank)
	end
end

function Collector.IsGuildBankOpen()
	return guildBankOpen
end

-- Event-Verkabelung ---------------------------------------------------------------

local Bus = Exo.EventBus

Bus:RegisterWowEvent("GUILDBANKFRAME_OPENED", function()
	guildBankOpen = true
	Collector.ScanGuildBank()
end, Collector)

Bus:RegisterWowEvent("GUILDBANKFRAME_CLOSED", function()
	guildBankOpen = false
end, Collector)

Bus:RegisterWowEvent("GUILDBANKBAGSLOTS_CHANGED", function()
	if guildBankOpen then
		Exo.Scheduler:Debounce("guildbank-scan", SCAN_DEBOUNCE, Collector.ScanGuildBank)
	end
end, Collector)
