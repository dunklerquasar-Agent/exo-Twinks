# AltoNG „3-in-1“-Plan: AlterEgo + Altoholic + SavedInstances ersetzen

> Ziel: **Ein** Addon, das die drei täglich genutzten Addons vollständig ablöst.
> Design-Leitlinie (User-Wunsch): **Die Optik von AlterEgo** — dunkles, flaches
> Datagrid, Zeilen-Beschriftungen links, Charaktere als Spalten, alles in einem Fenster.
> Stand der Analyse: 2026-09-26, AltoNG v0.8.0 (209 Tests, 0 luacheck-Warnungen).

---

## 1. Was die drei Addons können (Ist-Analyse)

### 1.1 AlterEgo (Design-Vorbild)

**Optik laut Screenshots (genau analysiert):**
- Ein einziges großes Fenster, sehr dunkel (#0d0d12-artig), komplett flach, keine Blizzard-Rahmen.
- **Transponierte Matrix:** Beschriftungen als linke Spalte (gelb/gold: Character, Realm,
  Item Level, Rating, Current Keystone, Vault, Raids, Dungeons, Mythic Plus, je Dungeon
  eine Zeile, dann Raid-Name + LFR/Normal/Heroic/Mythic), **Charaktere als Spalten** in
  Klassenfarbe. Spalten haben abwechselnd leicht unterschiedliche Hintergründe (Zebra vertikal).
- Kopfbereich: Titelleiste mit Addon-Name links, Icon-Buttons rechts (Ansagen, Charaktere,
  Sortierung, Einstellungen, X), mittig Affix-Icons der Woche.
- Zeilen im Detail:
  - *Item Level* farbig nach Höhe, *Rating* in M+-Farbstufen, *Current Keystone* als „BRH +16“.
  - *Vault*-Zeile: „Rewards“ in Grün, wenn Belohnungen abholbar sind (Erinnerungsfunktion).
  - *Raids*-Zeile: kompakte Schwierigkeits-Kürzel („M HC -“) farbig (M lila, HC blau).
  - *Dungeons*-Zeile: drei Vault-Level („17 16 -“) farbig.
  - **Pro Dungeon zwei Unterspalten** (früher Fortified/Tyrannical, mit Affix-Icons im
    Spaltenkopf); Zellen wie „23 ◆“ mit Vault-/Loot-Icons, Farbcodierung nach Stufe.
  - **Raid-Fortschritt als Quadrat-Raster:** pro Schwierigkeit eine Zeile kleiner Kästchen,
    ein Kästchen pro Boss, gefüllt = tot (lila bei M, usw.).
- **Tooltips:** z. B. „Vault Progress“ mit „Runs this Week: 54“, Verbesserungshinweis
  („Complete 3 Mythic Level 19 or higher…“) und Liste der besten Runs mit Punkten/iLvl.
- Dungeon-Namen sind klickbar → **Teleport** zum Dungeon (Hero's Path).

**Funktionsumfang (CurseForge/GitHub, Stand Sept. 2026):**
- Alle Chars realm-/fraktionsübergreifend; M+-Rating, Season-Best je Dungeon (+je Affix),
  aktueller Keystone, Raid-Lockouts + Boss-Kills, Great-Vault-Fortschritt + Abhol-Erinnerung.
- Saison-Währungen (Crests/Wappen, Flightstones/Funken, Katalysator, Delve-Bounty).
- Equipment-Fenster je Char (Items, Upgrade-Track, Verzauberungen, Sockel), sortierbare Spalten.
- Wochen-Affix-Plan der ganzen Saison; Gildeninfo-Zeile (optional); 60+-Char-Scrollbar.
- Komfort: Keystone in Party/Gilde posten (auch automatisch nach Loot), Instanz-Reset ansagen,
  Teleport-Klick, Keybinds + Minimap, Filter/Sortierung/Farb-Einstellungen.

### 1.2 Altoholic (Datenlieferant, bereits vermessen)

132.522 LOC Lua, davon nur ~37 % Feature-Code (Rest Libs/Locales/Altlasten). Kernfeatures:
- **Kontoübersicht:** alle Chars je Realm mit Level, Klasse, Gold, /played, Ruhebonus, iLvl, Beruf.
- **Suche:** accountweite Item-Suche über Taschen/Bank/Kriegsmeute (+ Gildenbank).
- **Container:** Tascheninhalte aller Chars, Bank, Kriegsmeutenbank.
- **Tooltip-Zähler:** „Wer hat wie viele davon?“ direkt im Item-Tooltip.
- **Briefkasten** (inkl. Ablauf-Warnung), **Auktionen/Gebote**, **Gildenbank**.
- **Berufe:** Rezeptlisten je Char, „Wer kann Item X herstellen?“, Kochen/Angeln-Skills.
- **Ruf/Fraktionen, Quests (Questlog je Char), Ausrüstungs-Übersicht, Talente**.
- Ballast, den wir bewusst NICHT nachbauen: Haustiere/Mounts/Erfolge-Grids, Garnison/Auftragstisch,
  Agenda/Kalender, Statistik-Panels (zusammen ~15.000 LOC Altlast).

### 1.3 SavedInstances (Wochen-Pflichten)

- **Tooltip-Matrix** (Minimap/Broker-Klick): Chars als Spalten, Zeilen = Raids/Instanzen mit
  Lockouts („9/9M“ etc.), optional abgelaufene IDs; Sekundär-Tooltip je Lockout mit Boss-Status.
- **Weekly/Daily-Quests** je Char (Mouseover: welche erledigt), Weltbosse, Feiertags-Bosse,
  LFR-Loot-Lockouts.
- **Währungen** mit Wochen-/Gesamt-Cap und Farbwarnung (konfigurierbar).
- **Berufs-Cooldowns** (Transmutationen etc.).
- Instanzen-pro-Stunde-Limit-Tracker, Favoriten („Einkaufsliste“), Chat-Link von Lockouts.
- Ballast/Altlasten: MoP-Farm, Timeless Isle, Garnison-Invasionen, Bonuswürfe → NICHT nachbauen.

---

## 2. Was AltoNG v0.8.0 schon abdeckt

| Bereich | Status |
|---|---|
| Kontoübersicht (Gold, Level, /played, Ruhebonus, iLvl, Realm-Gruppen) | ✅ Tab „Übersicht“ |
| Accountweite Item-Suche (Taschen/Bank/Kriegsmeute) | ✅ Tab „Suche“ |
| Item-Übersicht je Char + Kriegsmeutenbank | ✅ Tab „Inventar“ |
| Item-Tooltip-Zähler („Exo: N insgesamt“) | ✅ |
| Raid-Lockouts als Matrix (SavedInstances-Stil) | ✅ Tab „Schlachtzüge“ |
| M+: Rating, Keystone, Season-Best je Dungeon, Vault-Slots | ✅ Tab „Mythic+“ (0.8.0) |
| Altoholic-Datenimport (Bestandsdaten übernehmen) | ✅ |
| **AlterEgo-Optik (transponierte Matrix, ein Grid)** | ⚠️ nur im M+-Tab angenähert |

---

## 3. Gap-Analyse: Was zum vollständigen Ersatz fehlt

Priorität: **A** = ohne das ist das Alt-Addon nicht abschaltbar, **B** = wichtig, **C** = Komfort.

### Ersetzt AlterEgo
| # | Feature | Prio |
|---|---|---|
| G1 | **Komplett-Umbau der UI auf AlterEgo-Optik** (siehe Abschnitt 4) | A |
| G2 | Raid-Fortschritt als Boss-Quadrat-Raster je Schwierigkeit (LFR/N/H/M) | A |
| G3 | Vault-Zeile mit „Rewards!“-Erinnerung (Belohnung abholbar) + Vault-Tooltip mit Verbesserungshinweis („noch 3 Runs +19…“) und Top-Runs-Liste | A |
| G4 | Saison-Währungen je Char (Wappen/Crests, Funken, Katalysator-Ladungen) | B |
| G5 | Equipment-Ansicht je Char (Slots, iLvl, Verzauberung/Sockel-Check) | B |
| G6 | Keystone/Reset in Chat posten; Auto-Ansage neuer Keystone | C |
| G7 | Teleport-Klick auf Dungeon-Namen (Hero's Path, SecureActionButton) | C |
| G8 | Affix-Anzeige der Woche (+ Saisonplan) | C |

### Ersetzt SavedInstances
| # | Feature | Prio |
|---|---|---|
| G9 | Weekly-/Daily-Quest-Tracker je Char (konfigurierbare Quest-Liste: Weltboss, Wochenevent, Gewölbe-Weeklies) | A |
| G10 | Währungs-Caps mit Farbwarnung (in Währungszeilen aus G4 integriert) | B |
| G11 | Abgelaufene/alle Lockouts optional anzeigen; Boss-Detail-Tooltip je Lockout | B |
| G12 | **Minimap-/Broker-Tooltip** mit Kompakt-Matrix (SavedInstances-Ersatz für den „Schnellblick“) | B |
| G13 | Berufs-Cooldowns | C |

### Ersetzt Altoholic (Rest)
| # | Feature | Prio |
|---|---|---|
| G14 | Item-Qualitätsfarben + Shift-Klick-Itemlinks in Suche/Inventar | A |
| G15 | Briefkasten-Tracking (+ Ablauf-Warnung) | B |
| G16 | Gildenbank-Bestand in Suche/Zähler | B |
| G17 | Berufe/Rezepte: „Wer kann das herstellen?“ | B |
| G18 | Ruf/Fraktionen je Char | C |
| G19 | Auktionen/Gebote | C |

---

## 4. UI-Umbau: die AlterEgo-Optik als neues Gesicht (v0.9.0)

Kernentscheidung: Die heutige „Übersicht“, „Mythic+“ und „Schlachtzüge“ verschmelzen zu
**einer transponierten Charakter-Matrix im AlterEgo-Stil** — dem neuen Haupt-Tab „Charaktere“.

**Layout (wie Screenshot):**
```
┌────────────────────────────────────────────────────────────────────┐
│ + AltoNG        [Affix-Icons Woche]        [Ansage][Sort][Opt][X]  │
├──────────────┬─────────┬─────────┬─────────┬─────────┬────────────┤
│ Charakter    │ Liquidora│ Liquidorn│ …  (Klassenfarbe, 6-8/Seite) │
│ Realm        │ Silvermoon│ …                                       │
│ Gold         │ 1.234g  │ …          ← Altoholic-Zeilen            │
│ Gespielt     │ 12d 4h  │ …                                        │
│ Item-Level   │ 489     │ …   (farbig nach Höhe)                   │
│ Wertung      │ 3044    │ …   (M+-Farbstufen)                      │
│ Keystone     │ BRH +16 │ …                                        │
│ Vault        │ Rewards!│ …   (grün wenn abholbar, Tooltip)        │
│ Raids        │ M HC -  │ …   (Kürzel farbig)                      │
│ Dungeons     │ 17 16 - │ …   (3 Vault-Level)                      │
│ Weeklies     │ 2/4     │ …   ← SavedInstances-Zeile               │
│ Wappen       │ 320/480 │ …   (Cap-Farbwarnung)                    │
│ ── Mythic+ ──┼─────────┼───                                       │
│  Atal'Dazar  │ 23 ◆    │ …   (Season-Best, Tooltip: Punkte)       │
│  …je Dungeon │         │                                          │
│ ── Raidname ─┼─────────┼───                                       │
│  LFR         │ ■■■□□□□ │ …   (Quadrat je Boss)                    │
│  Normal      │ ■■■■□□□ │                                          │
│  Heroisch    │ ■■□□□□□ │                                          │
│  Mythisch    │ ■□□□□□□ │                                          │
└──────────────┴─────────┴──────────────────────────────────────────┘
```

**Design-System (aus den Screenshots abgeleitet):**
- Hintergrund #0d0d12 @ 95 %, Zeilen-Hover heller, vertikales Spalten-Zebra.
- Labels links in Gold (#ffd100), Charakternamen in Klassenfarbe, Sektionstrenner als
  eingefärbte Zwischenzeilen (wie „Mythic Plus“ / Raid-Name im Screenshot).
- Scrollbar bei vielen Zeilen (VirtualScroll haben wir schon); horizontale Seiten bei >6-8 Chars
  (Blätter-Button existiert schon) — dein 30+-Char-Account ist der Härtetest.
- Zeilen einzeln ein-/ausblendbar (Einstellungen) — wie AlterEgo-Filter.
- **Suche** und **Inventar** bleiben eigene Tabs (das kann AlterEgo nicht, kommt von Altoholic),
  bekommen aber dieselbe dunkle Optik.

Technisch bleibt alles beim bewährten Muster: reine Buildmatrix-Funktionen (testbar),
Rendering getrennt, Daten nur über `Exo.API`. Kein AlterEgo-Code — Cleanroom wie bisher.

---

## 5. Roadmap (Versionen)

| Version | Inhalt | ersetzt danach |
|---|---|---|
| **0.9.0** | G1+G2: Haupt-Tab „Charaktere“ in AlterEgo-Optik (transponierte Matrix, Sektionen, Boss-Quadrate, Spalten-Zebra, Tooltips); alte Tabs Übersicht/Mythic+/Schlachtzüge gehen darin auf | AlterEgo optisch |
| **0.9.5** | G3: Vault-„Rewards!“-Erinnerung + Vault-Tooltip (Top-Runs, Verbesserungshinweis) | — |
| **0.10.0** | G9+G10+G4: Weekly-Quest-Zeilen, Währungen mit Caps | **SavedInstances** ✂ |
| **0.11.0** | Designer-Tab: konfigurierbarer AlterEgo-Look (Farben, Fenster, Standards, Matrix-Zeilen) ✓ | — |
| **0.11.1** | G12: Minimap-Button/Broker mit Kompakt-Tooltip-Matrix; G11 Lockout-Details | — |
| **0.12.0** | G14: Qualitätsfarben + Itemlinks; G15 Briefkasten; G16 Gildenbank | — |
| **0.13.0** | G5: Equipment-Ansicht; G17 Berufe/Rezepte | **Altoholic** ✂ |
| **1.0.0** | G6+G7+G8: Keystone-Ansagen, Teleport-Klick, Affixplan; Feinschliff, Einstellungen | **AlterEgo** ✂ |
| 1.1+ | G13 Berufs-CDs, G18 Ruf, G19 Auktionen (Kür) | — |

**Übergangsphase:** Die drei Addons laufen parallel weiter, bis die jeweilige Zeile in der
Tabelle erreicht ist — AltoNG liest keine fremden SavedVariables zur Laufzeit (nur der
einmalige Altoholic-Import), es gibt also keine Konflikte.

## 6. Grenzen / Risiken (ehrlich)

- **Teleport & Chat-Ansagen** brauchen SecureActionButtons bzw. Hardware-Events —
  machbar, aber nur in-game testbar (nicht im Test-Framework simulierbar).
- **Währungs- und Quest-IDs sind saisonabhängig** (Midnight S2/S3): dafür kommt eine kleine
  Datentabelle in AltoData, die pro Saison gepflegt wird (genau dafür ist AltoData da).
- **Affix-je-Dungeon-Historie** (AlterEgos 2 Unterspalten) stammt aus einer Zeit mit
  Fortified/Tyrannical-Wochen; aktuell zeigt die API einen Season-Best. Wir starten mit
  einer Spalte pro Dungeon und rüsten nach, falls die API wieder zwei liefert.
- **Boss-Kill-Raster** braucht `GetSavedInstanceEncounterInfo` — liefert nur Daten, solange
  der Lockout aktiv ist (gleiches Verhalten wie AlterEgo/SavedInstances).
