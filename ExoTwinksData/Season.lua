-- ExoTwinksData/Season.lua
-- Saisonabhaengige Daten - PRO SAISON PFLEGEN (einzige Datei, die sich pro
-- Saison aendert). Alles andere im Addon ist saisonunabhaengig.

Exo.Data = Exo.Data or {}
Exo.Data.version = "data-2026.09.0"

-- Wochenaufgaben fuer die "Weeklies"-Zeile im Charaktere-Tab.
-- Format: { id = QuestID, label = "Anzeigename" }
-- QuestIDs findet man z. B. auf Wowhead ("Woechentlich"-Quests der Saison).
-- Solange die Liste leer ist, wird die Weeklies-Zeile ausgeblendet.
Exo.Data.WeeklyQuests = {
	-- Beispiele (IDs pro Saison eintragen):
	-- { id = 83333, label = "Woechentliches Event" },
	-- { id = 82449, label = "Weltboss" },
	-- { id = 83366, label = "Grosse Schatzkammer: Bonus" },
}

-- Waehrungen fuer die "Waehrungen"-Sektion im Charaktere-Tab.
-- Format: Liste von Currency-IDs (Reihenfolge = Anzeige-Reihenfolge).
-- Leer = Automatik: alle Waehrungen mit Wochen-/Gesamt-Cap, die irgendein
-- Char besitzt (damit erscheinen Wappen/Crests auch ohne Pflege automatisch).
Exo.Data.TrackedCurrencies = {
	-- Beispiel: 3008, -- Runenwappen
}
