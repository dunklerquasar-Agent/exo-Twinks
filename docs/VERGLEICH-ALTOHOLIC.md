# Codegroessen-Vergleich: AltoNG 0.7.0 vs. Altoholic Retail (Stand 2026-09)

Alle Zahlen selbst gemessen am Original-Paket (`Altoholic-Retail-komplett.zip`)
und am AltoNG-Repo. LOC = Zeilen inkl. Kommentare/Leerzeilen, sofern nicht anders angegeben.

## Gesamtbild

| Metrik                     | Altoholic Retail | AltoNG 0.7.0     | Faktor |
|----------------------------|------------------|------------------|--------|
| Addon-Ordner               | 27               | 3                | 9x     |
| Release-ZIP                | 1,75 MB          | 50 KB            | 35x    |
| Entpackt                   | 7,4 MB           | 184 KB           | 40x    |
| Lua-Dateien                | 503              | 30               | 17x    |
| Lua-LOC                    | 132.522          | 3.474            | 38x    |
| XML-UI-LOC                 | ~9.000 (146 Dateien) | 6 (nur Bindings.xml) | -  |
| TOC-Dateien                | 70               | 3                | 23x    |
| Unit-Tests                 | 0                | 195 (2.928 LOC, nicht ausgeliefert) | - |

AltoNG netto (ohne Kommentare/Leerzeilen): ~2.500 LOC Logik.

## Woraus Altoholics 132.522 Lua-LOC bestehen ("Ballast-Analyse")

| Kategorie                                   | LOC     | Anteil | Bewertung |
|---------------------------------------------|---------|--------|-----------|
| Eingebettete Libraries                      | 64.519  | 49%    | Groesstenteils statische Datenbanken, als "Libs" getarnt: LibBabble-Boss (604 KB!), RaidLoots (261 KB), craftLevels (158 KB), DungeonLoots (142 KB), craftInfo (131 KB), LibDeflate, LibPeriodicTable ... |
| Locales (Uebersetzungen, ~230 Dateien)      | 18.882  | 14%    | Alle Sprachen immer im Paket; AltoNG nutzt (bislang) direkt deutsche Strings |
| Eigentlicher Feature-Code                   | ~49.000 | 37%    | Verteilt auf 25 Module + 9.000 LOC XML-Layouts |

### Konkrete Ballast-Posten

1. **Doppelt/dreifach eingebettete Libs** im selben Paket:
   LibBabble-3.0 (3x), LibStub, LibSerialize, LibBit64, ChatThrottleLib,
   LibBabble-Faction-3.0 (je 2x) - identische Dateien mehrfach installiert.
2. **32 Classic-Varianten-TOCs** (Vanilla/TBC/Cata/Mists) im *Retail*-Paket -
   fuer einen Retail-Spieler komplett tot.
3. **Alt-/Nischen-Module** (~15.000 LOC), die Blizzard heute selbst abdeckt
   oder deren Content tot ist:
   - DataStore_Garrisons (1.410 LOC - WoD-Garnisonen, Content von 2014)
   - DataStore_Talents (3.273) + Altoholic_Grids (4.847 - Talent-/Pet-/Mount-Raster)
   - Achievements (3.057 ueber 2 Module), Agenda (1.334), Pets (630), Stats (397), Spells (231)
4. **DataStore_Inventory: 16.633 LOC** - davon der Grossteil LibBabble-Boss +
   InstanceLoot-Datenbanken, nur ~1.500 LOC echte Logik.
5. **9.000 LOC XML-UI** - ungetestet und schwer wartbar; AltoNG baut die
   komplette UI in Lua (Architektur-Regel 5).
6. **Redundante Infrastruktur**: AddonFactory (5.705) + DataStore-Core (5.496) +
   Altoholic-Hauptmodul (44.038 inkl. Libs) pflegen je eigene Event-/Options-/
   Comm-Schichten - AltoNG: EventBus + Scheduler + Store = ~600 LOC.

## Fairness: was der Vergleich NICHT sagt

Altoholic kann derzeit mehr als AltoNG: Berufe/Rezepte, Post, Ruf, Quests,
Auktionen, Gildenbank, Erfolge, Haustiere, Ausruestungs-Detailansicht.
Der faire Vergleich ist daher der **Feature-normierte**:

Die Funktionen, die AltoNG heute abdeckt (Konto-Uebersicht, Item-Suche,
Container-Erfassung, Raid-IDs, Tooltip-Besitzzaehler, Legacy-Import),
belegen im Original grob:
Altoholic_Summary (11.202) + Altoholic_Search (1.597) + DataStore_Containers
(1.963) + DataStore_Characters (615) + anteilig Hauptmodul/DataStore-Core
= **konservativ > 20.000 LOC** - gegenueber **3.474 LOC** in AltoNG (Faktor ~6),
zusaetzlich mit 195 Unit-Tests statt 0.

## Fazit

- Nur ~37% von Altoholic ist ueberhaupt Feature-Code; die Haelfte des Pakets
  sind (teils mehrfach kopierte) Libraries und eingefrorene Item-Datenbanken.
- Genau diesen Teil ersetzt AltoNG durch Live-Client-APIs (Itemnamen via
  GetItemInfo statt 600-KB-Namenslisten) und den geplanten AltoData-Ordner
  fuer *generierte* statische Daten.
- Pro abgedecktem Feature ist AltoNG ca. 6x kompakter, vollstaendig getestet
  und ohne XML - der 38x-Gesamtfaktor wird mit jedem Phase-5-Feature etwas
  kleiner werden, der Qualitaetsabstand (Tests, eine Datenquelle, ein Global)
  bleibt strukturell.
