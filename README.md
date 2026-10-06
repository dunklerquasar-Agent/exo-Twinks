# exo-Twinks 1.17.0

Der Account-Manager fuer World of Warcraft (Retail/Midnight): vereint die
Kernfunktionen von **Altoholic**, **AlterEgo** und **SavedInstances** in
einem Addon mit einheitlicher, frei konfigurierbarer Oberflaeche.

## Download & Installation

**[Neueste Version als ZIP herunterladen](https://github.com/dunklerquasar-Agent/exo-Twinks/releases/latest/download/exo-Twinks.zip)**
(Link zeigt immer auf das aktuellste Release.)

1. ZIP entpacken.
2. Die drei Ordner `ExoTwinksCore`, `ExoTwinksData`, `ExoTwinksUI` nach
   `World of Warcraft/_retail_/Interface/AddOns/` kopieren.
3. Spiel neu starten oder `/reload` -- oeffnen mit `/exo`.

## Module

| Ordner | Aufgabe |
|---|---|
| `ExoTwinksCore` | Datenerfassung, Speicher, Public API (`Exo.API`) |
| `ExoTwinksData` | Statische Daten (Erweiterungen, Presets) |
| `ExoTwinksUI` | Oberflaeche (laedt on demand beim ersten Oeffnen) |

Alle drei Ordner nach `Interface/AddOns/` kopieren. In der Blizzard-
Addon-Liste erscheinen sie als Gruppe **exo-Twinks**.

## Bedienung

- Oeffnen: `/exo`, `/twinks` (Alias: `/alto`, `/altong`), Minimap-Button
  oder Tastenkuerzel (Tastaturbelegung > AddOns).
- `/exo keys` sagt die Schluesselsteine aller Twinks im Gruppenchat an.
- `/exo ah` zeigt die eigenen Auktionen aller Twinks.
- `/exo vault` / `/exo mail`: Schatzkammer- bzw. Mail-Kurzbericht im Chat.
- Gildensteuer: Saetze im Designer unter \"Steuersaetze\" anklicken;
  offener Betrag steht im Fensterkopf und im Uebersicht-Modul.
  `/exo tax` = Bericht, `/exo tax rate 7` = krummer Satz.
- `/exo import` uebernimmt Daten aus einer alten Altoholic-Installation.
- `/exo version`, `/exo debug` fuer Diagnose.

## Reiter

1. **Uebersicht** - stapelbare Panels (SavedInstances-Stil): Charaktere,
   Waehrungen, Raid-IDs, Inventar, Gold pro Realm, Mythic+ Woche,
   Taschenplaetze, Scan-Status, Gildensteuer, Auktionen. Kopfzeile klicken = ein-/ausklappen,
   Shift-Klick = Modul nach vorn, Alt-Klick = nach hinten.
2. **Charaktere** - AlterEgo-Matrix (Chars als Spalten). Klick auf einen
   Namen oeffnet das Detail-Panel: Equipment je Slot, M+, Schatzkammer,
   Raid-IDs, Questlog, Waehrungen - inkl. **Vergleich** zweier Chars
   (besserer Wert gruen), \"bester Slot accountweit\" mit Upgrade-
   Hinweisen und Rollen-Zuweisung (Main/Bank/Crafter/
   Sammler) - Rollen filtern Matrix und Item-Suche.
3. **Inventar** - Modi "Bestand" (Liste/Symbole, Gruppierungen) und
   "Suche" (accountweit, AH-Filter: Qualitaet/Typ/Ort/Realm).
   Shift-Klick fuegt den Itemlink in den Chat ein.
4. **Berufe** - Skill-Staende aller Twinks + Rezept-Suche
   ("Wer kann X craften?") inkl. Material-Check: gruen = craftbar,
   gelb = es fehlen Materialien (Klick = Report im Chat).
   Rezepte + Reagenzien werden beim Oeffnen des Berufsfensters erfasst.
5. **Post** - alle Briefkaesten mit farbiger Ablauf-Warnung
   (rot unter 3 Tagen).
6. **Ruf** - Reputations-Matrix, gruen ab Geehrt, mit Fraktions-Suche.
7. **Designer** - alles konfigurieren, sofort und ohne /reload:
   Akzentfarbe (Presets + freie Hex-Eingabe), Deckkraft, Helligkeit
   (inkl. "Hell"), Navigation oben/links (Sidebar), Zeilendichte,
   Fenstergroesse, Reiter- und Modul-Sichtbarkeit, Matrix-Zeilen,
   Minimap-Button. "Alles zuruecksetzen" stellt den Standard wieder her.

## Automatische Erfassung

Taschen, Gold, Level, Equipment, Waehrungen, M+/Vault, Raid-IDs,
Weeklies, Ruf und Questlog: automatisch beim Spielen. Bank und
Kriegsmeutenbank: beim Bankbesuch. Gildenbank: beim Oeffnen der
Gildenbank. Briefkasten: beim Oeffnen der Post. Auktionen: beim Oeffnen des AH. Rezepte: beim Oeffnen
des Berufsfensters. Bestaende anderer Chars erscheinen in Item-Tooltips.

## Daten & Multi-Account

SavedVariables: `ExoTwinksDB` (accountweit, `WTF/Account/<ACCOUNT>/SavedVariables/`).
Aeltere Installationen (`AltoCoreDB`) werden beim ersten Login automatisch
uebernommen. Mehrere WoW-Accounts: jede Lizenz hat ihre eigene DB; ein
Sync-Tool von Drittanbietern kann die Datei kopieren, solange WoW
geschlossen ist (Schema ist versioniert und migriert selbststaendig).

## Entwicklung

- Tests: `busted spec` (495 Tests), Statik: `luacheck ExoTwinksCore
  ExoTwinksUI ExoTwinksData spec`
- Architektur: ein Global `Exo`; UI liest ausschliesslich `Exo.API`;
  interne Events `EXO_*` via `Exo.EventBus` (auch fuer Dritt-Addons).
- Roadmap nach 1.0: Dungeon-Teleports (Secure Buttons), Auktionen,
  Import/Export von Designer-Profilen. Siehe `docs/PLAN-REDESIGN-1.0.md`.

## Lizenz & Quellcode

exo-Twinks ist Open Source unter der **GNU General Public License v3.0**
(siehe LICENSE): Jeder darf das Addon nutzen, veraendern und weitergeben --
Aenderungen muessen unter derselben Lizenz offengelegt werden.

Quellcode, Issues und Releases: https://github.com/dunklerquasar-Agent/exo-Twinks
