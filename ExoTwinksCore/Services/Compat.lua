-- Services/Compat.lua
-- Koexistenz mit dem ALTEN Altoholic waehrend der Migrationsphase.
--
-- Problem: Das alte Altoholic registriert ebenfalls "/alto". WoW loest
-- Slash-Konflikte ueber eine Hash-Tabelle auf, die beim ERSTEN Befehl lazy
-- aus den SLASH_*-Globals gebaut wird -- welcher Eintrag gewinnt, ist
-- praktisch Zufall (pairs-Reihenfolge).
--
-- Loesung: Beim Login (nach dem Laden aller Addons, aber vor der ersten
-- Slash-Eingabe) benennen wir die "/alto"-Tokens des alten Altoholic um.
-- Das alte Fenster bleibt ueber /altoholic voll erreichbar; /alto gehoert
-- damit deterministisch exo-Twinks.

local _, Exo = ...

local Compat = {}
Exo.Services = Exo.Services or {}
Exo.Services.Compat = Compat

local notified = false -- Hinweis nur einmal pro Sitzung

-- Benennt alle "/alto"-Tokens des alten Altoholic um.
-- Rueckgabe: true, wenn mindestens ein Token umgebogen wurde.
function Compat.ReclaimSlashCommand()
	local W = Exo.WowAPI
	if not W.IsAddOnLoaded("Altoholic") then
		return false
	end

	local changed = false
	for i = 1, 10 do
		local token = "SLASH_ALTOHOLIC" .. i
		local value = W.GetGlobal(token)
		if type(value) == "string" and value:lower() == "/alto" then
			W.SetGlobal(token, "/altoholicold" .. i)
			changed = true
		end
	end
	return changed
end

Exo.EventBus:RegisterWowEvent("PLAYER_ENTERING_WORLD", function()
	if Compat.ReclaimSlashCommand() and not notified then
		notified = true
		Exo.Log.emit("|cff69ccf0exo-Twinks|r Altes Altoholic erkannt: '/alto' oeffnet jetzt exo-Twinks. " ..
			"Das alte Fenster bleibt ueber /altoholic erreichbar.")
	end
end, Compat)
