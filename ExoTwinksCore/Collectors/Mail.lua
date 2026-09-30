-- ExoTwinksCore/Collectors/Mail.lua
-- Briefkasten (0.16.0): beim Oeffnen des Briefkastens werden alle Mails
-- erfasst (Absender, Betreff, Gold, Anhaenge, Restlaufzeit). Die
-- Restlaufzeit wird zusammen mit dem Scan-Zeitpunkt gespeichert, damit die
-- Ablauf-Warnung auch offline korrekt weiterlaeuft.
--
-- Datenlayout (Sektion "mails"):
--   { scannedAt, list = { { sender, subject, money, daysLeft, items } } }

local Collector = {}
local _, Exo = ...
Exo.Collectors = Exo.Collectors or {}
Exo.Collectors.Mail = Collector

local SCAN_DEBOUNCE = 0.5
local mailOpen = false

function Collector.ScanInbox()
	local Store = Exo.Store
	if not Store:IsReady() or not mailOpen then return end

	Store:WriteCharacterData(Store:GetCurrentKey(), "mails", {
		scannedAt = Exo.WowAPI.Now(),
		list = Exo.WowAPI.GetInboxMails(),
	})
end

function Collector.IsMailOpen()
	return mailOpen
end

-- Event-Verkabelung ---------------------------------------------------------------

local Bus = Exo.EventBus

Bus:RegisterWowEvent("MAIL_SHOW", function()
	mailOpen = true
	-- MAIL_INBOX_UPDATE folgt, sobald der Client die Liste hat
end, Collector)

Bus:RegisterWowEvent("MAIL_INBOX_UPDATE", function()
	if mailOpen then
		Exo.Scheduler:Debounce("mail-inbox", SCAN_DEBOUNCE, Collector.ScanInbox)
	end
end, Collector)

Bus:RegisterWowEvent("MAIL_CLOSED", function()
	mailOpen = false
end, Collector)
