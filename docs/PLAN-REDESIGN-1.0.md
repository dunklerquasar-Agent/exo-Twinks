# exo-Twinks — Redesign-Plan bis 1.0

> Stand: 2026-09-27 (nach v0.11.1 / Beta 15).
> Grundlage: Redesign-Analyse (Sidebar/IA, Charaktere-Split, Inventar+Suche,
> P0–P3-Features) + `docs/TODO-SPIELERBEDUERFNISSE.md`.
> Design-Leitlinie bleibt: **AlterEgo-Optik**, flach, Akzentfarbe, Designer-konfigurierbar.

## Bereits erledigt (nicht erneut einplanen)

- Item-Counts in Tooltips („X auf CharA/Bank") — seit Phase 2
- Kriegsmeuten-Bank im Scan, Inventar-Tab, Übersicht
- Designer: Theme (Akzent inkl. Hex, Deckkraft, Helligkeit), Fenster-Presets,
  „Größe merken", Tab-Sichtbarkeit, Matrix-Zeilen, Inventar-Standards
- Übersicht-Tab: stapelbare Panels (Reihenfolge/Sichtbarkeit im Designer)
- Slash: `/exo`, `/twinks` primär; `/alto` Alias

## Release-Plan

### v0.11.2 — Umbenennung „alles Exo“ (SOFORT)
- Internes Global `Exo` → `Exo` (Code, Specs, luacheck)
- SavedVariables `AltoCoreDB` → `ExoTwinksDB` **mit automatischer Übernahme**
  alter Daten (AltoCoreDB bleibt eine Übergangszeit in der TOC gelistet)
- Frame `AltoMainWindow` → `ExoTwinksMainWindow`
- Legacy-Import von echtem Altoholic bleibt unverändert bestehen

### v0.12.0 — Paket A: Sidebar + Designer 2.0 ✓ (Beta 17)
- Sidebar-Navigation links (skaliert besser als 6–8 horizontale Tabs);
  im Designer umschaltbar: „Navigation: Oben (Tabs) / Links (Sidebar)"
- Dichte-Modus: Normal / Kompakt (Zeilenhöhe 20 → 16, mehr Zeilen sichtbar)
- Semantic Colors zentral (positiv/negativ/warnung) statt verstreuter Hexwerte
- Account-Summary-Header: Gold gesamt, Anzahl Alts, Ø-iLvl, Vault-offen

### v0.13.0 — Paket C: Inventar + Suche vereint ✓ (Beta 18)
- Ein Tab „Inventar" mit zwei Modi: **Browse** (heutige Liste/Icons/Gruppen)
  und **Suche** (AH-ähnliche Filterleiste: Name, Qualität, Typ/Unterart,
  Min-Level, Standort Taschen/Bank/Kriegsmeute, Realm)
- Container-Scan tiefer: freie Slots je Char, Taschen-Typen, Reagenzienbank
- Schnellfilter: „Nur dieser Realm", „Nur Bank-Alts" (nutzt Char-Gruppen)

### v0.14.0 — Paket B: Charaktere Overview + Detail ✓ (Beta 19)
- Overview-Modus: schmale Matrix (6–8 wichtigste Zeilen, Designer wählt)
- Deep-Dive: Klick auf Char-Spalte → Detail-Panel (Equipment Stück-für-Stück,
  M+-Runs, Locks, Currencies, Rest-XP/gespielt)
- Compare-Modus: 2–3 Chars nebeneinander

### v0.15.0 — Paket D: Berufe + Rezepte (P1) ✓ (Beta 20)
- Profession-Collector: Berufe + Skill je Char, bekannte Rezepte
- Berufe-Ansicht: Matrix Berufe×Chars; Rezept-Suche „wer kann X craften?"
- „Kann ich das craften?": Materialabgleich gegen Bestände aller Chars

### v0.16.0 — Wirtschaft & Post (P1) ✓ (Beta 21)
- Mail-Übersicht: was liegt bei wem, Absender, **Ablauf-Warnung**
- Gildenbank-Scan + Suche-Integration
- Shift-Klick-Itemlinks in allen Listen

### v0.17.0 — Konto-Transparenz (P2/P3) ✓ (Beta 22)
- Reputationen-Matrix („alle Alts ≥ Geehrt bei X?")
- Quest-Log über alle Alts
- /played + Rest-XP-Vervollständigung, Gold-Summen pro Realm/Account
- Bank-Alt-Markierung & Char-Gruppen

### v1.0.0 — Feinschliff ✓ (Release)
- Minimap-Button/Broker mit Kompakt-Tooltip (aus alter Roadmap G12)
- M+-Komfort: Keystone-Ansagen, Teleport-Klick, Affixplan (G6–G8)
- Dark/Light-Varianten, Einstellungen-Doku, Multi-Account-Sync dokumentiert
- Alte Roadmap `PLAN-3IN1.md` gilt als abgelöst durch dieses Dokument

## Prinzipien für alle Pakete

1. Reine, testbare Datenfunktionen (busted) — UI nur dünne Schicht darüber
2. Alles Konfigurierbare läuft über `Exo.API.GetOption/SetOption` + Designer
3. Kein /reload für Einstellungen; Struktur-Umbauten klar kommuniziert
4. Jedes Release: busted grün, luacheck 0/0, CHANGELOG, Beta-ZIP

---
**Hinweis (nach v1.2.0):** Diese Roadmap ist abgeschlossen. Die
Weiterentwicklung ist in `docs/PLAN-NACH-1.2.md` geplant
(Grundlage: `docs/FEEDBACK-GROK.md`).
