-- ExoTwinksCore/Collectors/GuildTax.lua
-- Gildensteuer (1.2.0, persoenliches Feature): bei aktivierter Steuer wird
-- fuer jede EINNAHME (positive Goldaenderung) des eingeloggten Charakters
-- der konfigurierte Prozentsatz seiner Gilde als "offen" verbucht.
--
-- WICHTIG: Das Addon bucht NIE selbst Gold ab (von WoW nicht erlaubt) --
-- es fuehrt nur Buch. Zuruecksetzen: Designer-Button oder Shift-Klick im
-- Uebersicht-Modul "Gildensteuer".
--
-- Quellen (einzeln aktivierbar, guildtax.source.*):
--   loot  - Standard: alles, was ohne offenes Sonderfenster reinkommt
--           (Loot, Quests, Haendlerverkauf) [Standard: an]
--   mail  - Gold bei geoeffnetem Briefkasten (AH-Erloese, Post) [Standard: an]
--   trade - Gold bei offenem Handelsfenster (oft Twink-Umbuchung) [Standard: aus]
--
-- Optionen: guildtax.enabled (bool), guildtax.rate.<Gilde> (Prozent 0-25),
--           guildtax.source.loot/mail/trade (bool)
-- Datenlayout (Sektion "guildtax"): { income = Kupfer, owed = Kupfer }

local Collector = {}
local _, Exo = ...
Exo.Collectors = Exo.Collectors or {}
Exo.Collectors.GuildTax = Collector

local mailOpen, tradeOpen = false, false
local lastGold = nil

Collector.SOURCE_DEFAULTS = { loot = true, mail = true, trade = false }

function Collector.IsEnabled()
	return Exo.API.GetOption("guildtax.enabled", false) == true
end

function Collector.GetRate(guildName)
	if not guildName or guildName == "" then return 0 end
	local rate = tonumber(Exo.API.GetOption("guildtax.rate." .. guildName, 0)) or 0
	return math.max(0, math.min(25, rate))
end

function Collector.IsSourceEnabled(source)
	local fallback = Collector.SOURCE_DEFAULTS[source]
	if fallback == nil then return false end
	return Exo.API.GetOption("guildtax.source." .. source, fallback) == true
end

function Collector.CurrentSource()
	if mailOpen then return "mail" end
	if tradeOpen then return "trade" end
	return "loot"
end

-- Steuer fuer einen Betrag berechnen (rein, testbar)
function Collector.TaxFor(amount, rate)
	return math.floor(amount * rate / 100 + 0.5)
end

function Collector.OnMoneyChanged()
	local Store = Exo.Store
	if not Store:IsReady() then return end

	local gold = Exo.WowAPI.GetMoney()
	local previous = lastGold
	lastGold = gold
	if previous == nil then return end -- Baseline nach Login

	local delta = gold - previous
	if delta <= 0 or not Collector.IsEnabled() then return end
	if not Collector.IsSourceEnabled(Collector.CurrentSource()) then return end

	local rate = Collector.GetRate(Exo.WowAPI.GetGuildName())
	if rate <= 0 then return end

	local charKey = Store:GetCurrentKey()
	local char = Store:GetCharacter(charKey)
	local data = (char and char.guildtax) or {}
	Store:WriteCharacterData(charKey, "guildtax", {
		income = (data.income or 0) + delta,
		owed = (data.owed or 0) + Collector.TaxFor(delta, rate),
	})
end

-- Offenen Betrag eines Chars auf 0 setzen (Designer-Button / Shift-Klick)
function Collector.ResetChar(charKey)
	local Store = Exo.Store
	if not Store:IsReady() or not Store:GetCharacter(charKey) then return end
	Store:WriteCharacterData(charKey, "guildtax", { income = 0, owed = 0 })
end

function Collector.ResetAll()
	for _, charKey in ipairs(Exo.Store:GetCharacterKeys()) do
		Collector.ResetChar(charKey)
	end
end

-- Event-Verkabelung ---------------------------------------------------------------

local Bus = Exo.EventBus

Bus:RegisterWowEvent("PLAYER_ENTERING_WORLD", function()
	lastGold = Exo.WowAPI.GetMoney() -- Baseline, kein Delta
end, Collector)

Bus:RegisterWowEvent("PLAYER_MONEY", Collector.OnMoneyChanged, Collector)

Bus:RegisterWowEvent("MAIL_SHOW", function() mailOpen = true end, Collector)
Bus:RegisterWowEvent("MAIL_CLOSED", function() mailOpen = false end, Collector)
Bus:RegisterWowEvent("TRADE_SHOW", function() tradeOpen = true end, Collector)
Bus:RegisterWowEvent("TRADE_CLOSED", function() tradeOpen = false end, Collector)
