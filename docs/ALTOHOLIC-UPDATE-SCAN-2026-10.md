# Altoholic Update-Scan (Stand: 04.10.2026)

Quellen: GitHub `thaoky/Altoholic_Retail` (Changelog.txt, Commits), CurseForge Projekt 13402.

## Eckdaten
- Autor: Thaoky (Ein-Mann-Projekt, „#ArmyOfOne"), seit Dez. 2007 (fast 19 Jahre)
- 26,2 Mio. Downloads, License: All Rights Reserved
- Aktuelle Version: **12.1.005 vom 02.10.2026** (vor 2 Tagen!) — Addon wird aktiv gepflegt
- Architektur: Altoholic + 7 Submodule + ~15 DataStore_*-Module + AddonFactory (eigene Repos)
- Neues Nebenprojekt: **Altoholic Forever** (für „WoW Forever") in Entwicklung seit 12.1.002

## Updates 2026 (Midnight-Ära) im Detail

| Version | Datum | Inhalt |
|---|---|---|
| 12.1.005 | 02.10.2026 | Lua-Error beim Bank-Öffnen (Containers), 2 Lua-Errors bei Quest-Abgabe |
| 12.1.004 | 02.10.2026 | Auktionen-Liste im Characters-Tab gefixt; AH-Einträge-Löschen gefixt; `SanitizeCharacters()` entfernt ungültige Char-Keys automatisch |
| 12.1.003 | 30.09.2026 | **Tooltip-Zähler fehlten bei anlegbaren Items** (gefixt); anlegbare Items in Taschen fälschlich als „equipped" gemeldet; eigenes PanelTabButton-Template (weg von Blizzard-PanelTemplates) |
| 12.1.002 | 22.09.2026 | Alte API-Calls modernisiert (GetItemInfo, GetItemIcon …) für 12.1.5 + WoW Forever; Start „Altoholic Forever" |
| 12.1.001 | 16.08.2026 | Minimap-Button-Rechtsklick-Move gefixt; Delay-String-Lua-Error |
| 12.0.004 | 07.07.2026 | Mail: nil-Sender-Fix; Achievement-Batch-Scan zurückgedreht (C_Timer-Stottern); ToC-Fix |
| 12.0.003 | 06.07.2026 | Sammel-Fixes durch Community (GovtGeek) — **Thaoky war monatelang abwesend** |
| 12.0.002 | ~03/2026 | Tooltip-Error-Fix (ebenfalls GovtGeek) |
| 12.0.001 | 21.01.2026 | Reines Kompatibilitäts-Update für 12.0-Pre-Patch |

## Relevante ältere Meilensteine (11.2.x, TWW-Ende 2025)
- 11.2.006 (09/2025): Warband-Bank iterierbar; **Suche durchsucht endlich auch die Warband-Bank** (GH #66 — war lange Lücke!); Auctionator-Konflikt (doppelte Zähler) gefixt
- 11.2.002 (08/2025): Umbau auf neue Spieler-Bank-Reiter (6×98 Slots) — alle Alts mussten Bank neu besuchen
- 11.2.001 (08/2025): Reagenzbank + Leerenlager entfernt (Blizzard-Änderung)
- 11.0.00x (2024): Warband-Bank-Erstsupport, Tooltip-Option dafür, „Could be stored on"-Bank-Markierungen (Alt als „Cataclysm-Mining-Bank" markierbar)

## Muster & Einordnung für exo-Twinks

**1. Tempo/Stabilität:** 12.0-Zyklus (Jan–Jul 2026) war faktisch tot — nur 1 Pre-Patch-Bump, dann 6 Monate Pause (Autor abwesend, Community-Notfixes). Das deckt sich mit der Reddit-Abwanderung zu AlterEgo. Seit Aug. 2026 wieder aktiv, aber die 2026-Releases sind **fast ausschließlich Bugfixes**, keine Features.

**2. Dieselben Baustellen wie wir:** Tooltip-Zähler bei equippable Items (12.1.003) und „equipped"-Fehlklassifizierung — exakt unser Item-Kern-Terrain (unsere 1.12.0 hat Post+Angelegt sauber getrennt). Warband-Bank-Suche kam bei Altoholic erst Sep. 2025 — wir hatten das von Anfang an.

**3. Was Altoholic hat und wir (noch) nicht:**
- „Could be stored on"-Hinweis im Tooltip (Alt als Profession-/Expansion-Bank markieren)
- Quest-Log-übergreifend („welche Alts haben diese Quest")
- Agenda/Kalender, Achievements-, Grids-, Guild-Tab (bewusst nicht unser Scope)
- Auktions-Spalten (höchstes/niedrigstes Buyout, nächster Ablauf)

**4. Features ohne Gegenstück bei Altoholic (unser Vorsprung):**
- KM-Items-Übersicht pro Char (wb-Flag-Erkennung) + **Einlagern-Button (1.13.0)**
- Gildensteuer-Tracking, AlterEgo-artige Matrix, M+/Vault-Minimap-Kurzinfo

**5. Keine Lizenz-Änderung:** weiterhin All Rights Reserved — kein Code übernehmbar, nur Konzepte.
