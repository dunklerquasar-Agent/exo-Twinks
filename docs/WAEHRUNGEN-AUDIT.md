# Währungs-Audit (Stand: v1.16.0)

Ziel (User): **Sämtliche Währungen, die in Retail von einem Char besessen
werden können, erfassen.** Status: ✅ erreicht (seit 1.16.0).

## Wie der Scan funktioniert

Quelle ist die Währungsliste des Spiels (`C_CurrencyInfo.GetCurrencyList*`)
— dieselbe Datenbasis wie das Blizzard-Währungsfenster (Charakterfenster →
Währungen). Dort führt WoW **jede** Währung, die der Charakter jemals
besessen hat, über alle Erweiterungen hinweg, einsortiert in Kategorien.

Ablauf bei jedem Scan (Login + jeder Währungsgewinn, entprellt 1 s):
1. `W.ExpandAllCurrencyHeaders()` — alle zugeklappten Kategorien öffnen,
   **inklusive „Nicht verwendet"**.
2. Alle Zeilen lesen; Header überspringen; je Währung speichern:
   `currencies[id] = { name, qty, max, acc? }`
   - `max`: Saison-/Gesamt-Cap (0 = kein Cap)
   - `acc = true`: account-weite / übertragbare Währung
     (isAccountWide oder isAccountTransferable)
3. `W.CollapseCurrencyHeaders(...)` — Klapp-Zustand exakt wiederherstellen
   (der Spieler merkt nichts).

## Was damit abgedeckt ist

| Kategorie | erfasst? |
|---|---|
| Aktuelle Erweiterung (Midnight: Valorsteine, Flugsteine, …) | ✅ |
| Alle alten Erweiterungen (Classic bis TWW), auch zugeklappt | ✅ seit 1.16.0 |
| PvP (Ehre, Eroberung, Abzeichen) | ✅ |
| Dungeon/Raid (Siegel, Runen, Steine) | ✅ |
| Event-/Saisonwährungen (Zeitwanderung, Feiertage, Remix/Bronze) | ✅ |
| Handelsposten (Handelsvorrat — account-weit) | ✅ inkl. acc-Flag |
| Kategorie „Nicht verwendet" | ✅ seit 1.16.0 |
| Caps (z. B. 750/2000) + Wochen-Caps als max | ✅ |
| Gold | ✅ separat (gold-Section, eigene Matrix-Zeile) |

Nicht erfasst (bewusst): interne/versteckte Tracking-"Währungen", die
Blizzard komplett aus der Spieler-UI ausblendet (Quest-Zähler u. Ä.) —
sie sind für Spieler bedeutungslos und tauchen in keinem Addon auf.

## Anzeige im Addon

- **Charaktere-Matrix**: eine Zeile pro Währung (Union über alle Chars),
  Format `qty/max` mit Cap-Ampel (rot = voll, gelb = ab 75 %);
  Währungen mit Cap werden automatisch eingeblendet.
- **Übersicht → Modul „Waehrungen"**: alphabetische Liste je Char.
- Datenzugriff für alles Weitere: `Exo.API.GetCurrencies(charKey)`.

## Garantien (Tests)

spec/release_1_16_spec.lua: zugeklappte Kategorien werden erfasst;
Klapp-Zustand wird wiederhergestellt; acc-Flag via API; Event-Weg.
spec/currencies_spec.lua: Entprellung, Header-Filterung, Grundformat.

## Offene Ausbau-Ideen

- Matrix-Markierung für account-weite Währungen (z. B. Symbol-Präfix).
- Währungs-Gesamtsumme über die Kriegsmeute (acc-Währungen nur 1×).
- Filter „nur Währungen der aktuellen Saison" im Übersichts-Modul.
