# Plan: Quick Wins aus der Spielerwunsch-Recherche

Basis: `docs/RECHERCHE-SPIELERWUENSCHE-2026.md` · Stand: 1.9.2 (436 Tests)
Zwei kleine Releases: **v1.10.0** (Q1–Q5) und **v1.11.0** (Q6–Q8).
Jedes Release läuft durch den Standard-Flow: Tests/luacheck → TOC/CHANGELOG →
ZIP → GitHub Branch/PR/Selbst-Merge/Release (Regelwerk v1.1).

**Vorab-Befund aus dem Code:** `Exo.API`-Summaries liefern `restXP`, `xp`,
`xpMax` und `isCurrent` bereits; der Designer hat schon eine Options-
Infrastruktur (`GetOption`/`SetOption`) und einen "Fenstergröße merken"-Toggle.
→ Q1, Q3, Q4 sind fast reine UI-Arbeit.

---

## Release 1: v1.10.0 — "Community-Wünsche I" (Q1–Q5)

### Q1 Fensterposition merken  *(AlterEgo-Issue #191 u. a.)*
- **Umsetzung:** `Framework/Window.lua`: im `OnDragStop`-Script zusätzlich
  Punkt+Offsets via `window:GetPoint()` nach `SetOption("window.pos", {...})`;
  beim Erzeugen des Fensters `GetOption("window.pos")` anwenden (Fallback:
  CENTER). Off-Screen-Schutz: Werte clampen.
- **Designer:** Button "Fensterposition zurücksetzen" neben dem bestehenden
  "Fenstergröße merken"-Toggle.
- **Tests (3):** DragStop speichert; Neuaufbau stellt Position wieder her;
  Reset-Button löscht Option.
- **Aufwand: S** · Risiko: gering (Mock-Frames können GetPoint — prüfen,
  sonst Stub ergänzen).

### Q2 Fenster-Skalierung  *(AlterEgo-Issue #99)*
- **Umsetzung:** Option `window.scale` (0.7–1.3, Default 1.0);
  `window:SetScale()` beim Aufbau + live bei Änderung.
- **Designer:** Zyklus-Button wie beim Steuersatz (70 % → 80 % → … → 130 %)
  statt echtem Slider — nutzt vorhandenes `Cycle…`-Muster, kein neues Widget.
- **Tests (2):** Option ändert Scale; ungültige Werte werden geklemmt.
- **Aufwand: S** · Risiko: gering.

### Q3 Eigenen Charakter in der Matrix hervorheben  *(AlterEgo-Issue #97)*
- **Umsetzung:** `Tabs/Characters.lua` (+ ggf. Overview): bei
  `summary.isCurrent` Zeilen-Hintergrund in Akzentfarbe (Designer-Accent,
  ~25 % Alpha) + Name mit Pfeil-Präfix.
- **Tests (2):** aktuelle Char-Zeile markiert, andere nicht; Re-Render stabil.
- **Aufwand: S** · Daten vorhanden (`isCurrent`).

### Q4 Rest-XP / Level-Fortschritt anzeigen  *(AltVault/Armory-Wunsch)*
- **Umsetzung:** `Tabs/Characters.lua`: Spalte "XP" für Chars unter Maxlevel:
  `Lv 73 · 45 % · Ruhe 120 %` (Ruhebonus = restXP/xpMax). Maxlevel-Chars: "—".
  Overview-Summary optional: "3 Chars im Levelbereich".
- **Tests (2):** Anzeige unter Maxlevel korrekt berechnet; Maxlevel zeigt "—".
- **Aufwand: S** · Daten vorhanden (`xp`, `xpMax`, `restXP`, Collector läuft).

### Q5 Minimap-Tooltip: Vault-Status  *(AlterEgo-Reddit-Wunsch)*
- **Umsetzung:** `Services/Minimap.lua`: Zeilenformat um Vault-Kürzel
  erweitern, z. B. `Name  Lv 80  iLvl 684  12345g  Vault 2/3/1`
  (M+/Raid/Welt-Slots aus vorhandenen Vault-Daten via `Exo.API`).
  Kopfzeile "Vault offen: N Chars" ergänzen (Zähler existiert im Window-Summary).
- **Tests (2):** Tooltip-Zeile enthält Vault-Teil; Chars ohne Daten ohne Teil.
- **Aufwand: S** · Daten vorhanden (Vault-Collector seit SavedInstances-Ersatz).

**v1.10.0 gesamt:** ~11 neue Tests (→ ~447), Dateien: Window.lua,
Characters.lua, Minimap.lua, Designer.lua + 3–4 Specs. Kein Collector-,
kein Schema-Eingriff → geringes Regressionsrisiko.

---

## Release 2: v1.11.0 — "Community-Wünsche II" (Q6–Q8)

### Q6 Charaktere ausblenden  *(WoWthing-Feature, stand schon im TODO)*
- **Umsetzung:** Option `hiddenChars = { [charKey]=true }`;
  `API.GetCharacterKeys()` erhält Parameter `includeHidden`; Standard-Ansichten
  filtern, Designer zeigt alle Chars mit Checkbox (Muster `ToggleCharRow`).
  Daten werden WEITER gesammelt — nur die Anzeige filtert.
- **Tests (4):** versteckter Char fehlt in Summaries/Inventar-Aggregation;
  Designer-Liste zeigt ihn; Toggle zurück; Suche findet optional weiterhin
  (Entscheidung: Suche zeigt versteckte mit grauem Hinweis).
- **Aufwand: M** · Achtung: alle Aggregationen (ItemCounts, Tooltip) müssen
  denselben Filter nutzen → zentral in Public.lua lösen, nicht pro Tab.

### Q7 "Runs diese Woche X/8"  *(AlterEgo-Reddit-Wunsch)*
- **Umsetzung:** M+-Collector speichert bereits Runs/Vault-Progress →
  Zähler (Anzahl M+-Runs der Woche, Cap 8 für volle Vault-Reihe) als
  Spalte im Characters-Tab + Overview-Zeile.
- **Tests (2):** Zählung aus Vault-Daten; 0-Runs-Anzeige.
- **Aufwand: S–M** (prüfen, ob Run-Anzahl schon im Schema liegt, sonst
  Collector minimal erweitern).

### Q8 Post-Indikator mit Ablauf-Warnung  *(AltVault-Feature)*
- **Umsetzung:** Mail-Daten (0.12.0-Collector) liefern Absender+Ablauf →
  Spalte 📨 im Characters-Tab: gelb < 7 Tage, rot < 3 Tage bis Mail-Verfall;
  Tooltip mit Details. Overview: "2 Chars mit ablaufender Post".
- **Tests (3):** Schwellwert-Farben; keine Mail = leer; Tooltip-Inhalt.
- **Aufwand: M** · Ablaufdatum muss im Mail-Collector erfasst sein — prüfen,
  ggf. `daysLeft` beim Scan ergänzen (kleiner Schema-Zusatz, abwärtskompatibel).

**v1.11.0 gesamt:** ~9 neue Tests (→ ~456).

---

## Reihenfolge & Abgrenzung

1. v1.10.0 bauen (alle 5 in einem Branch `agent/release-1.10.0` — zusammen-
   hängende UI-Arbeit, ein PR)
2. Feedback des Users abwarten (in-game-Eindruck, besonders Scale/Position)
3. v1.11.0 bauen (Branch `agent/release-1.11.0`)
4. Danach aus der Recherche-Mittelklasse priorisieren (M1 `!keys`, M3 Export …)

**Bewusst NICHT in diesen Releases:** Schriftarten (Font-Dateien/Locale-
Problematik, AlterEgo kämpft selbst damit), Rating-Wizard, Transmog-Tracking,
Gold-Zeitreihe — siehe Recherche-Dokument Abschnitt "HOCH / bewusst nicht".

**TODO-Pflege:** Nach jedem Release die erledigten Punkte in
`docs/TODO-SPIELERBEDUERFNISSE.md` auf ✅ setzen (Rest-XP und
Chars-ausblenden stehen dort bereits als ⬜).
