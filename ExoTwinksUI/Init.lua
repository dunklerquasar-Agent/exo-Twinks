-- ExoTwinksUI/Init.lua
-- Abschluss des UI-Ladevorgangs. Frisch erfasste Locks direkt anzeigen:
-- beim ersten Oeffnen einmal RaidInfo anfordern, damit die Daten aktuell sind.

Exo.WowAPI.RequestRaidInfo()
Exo.Log:Debug("ExoTwinksUI geladen: %d Tab(s) registriert.", #Exo.UI.tabs)
