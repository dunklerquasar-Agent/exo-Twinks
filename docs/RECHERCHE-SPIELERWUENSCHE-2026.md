# Recherche: Spielerwünsche bei vergleichbaren Addons (Okt 2026)

Quellen: Reddit-Threads zu Altoholic/AlterEgo/SavedInstances, AlterEgo-GitHub-Issues,
AltVault-Featureliste (wowinterface), WoWthing-Featureliste.
Bewertung: **Aufwand** = leicht (< 1 Release) · mittel (1 Release) · hoch (mehrere) ·
**Status** = ✅ haben wir · 🔶 teilweise · ❌ fehlt

---

## 1. Was Spieler an den Vorbildern loben/vermissen (Kernaussagen)

| Quelle | Aussage |
|---|---|
| r/wow zu Altoholic | "zu schwergewichtig" — Spieler wollen LEICHTE Addons; BagSync/Baganator nur wegen **Tooltip-Anzahl auf anderen Chars** genutzt |
| r/wowaddons 11.2 | Altoholic **wochenlang kaputt nach Patches** → Abwanderung zu AlterEgo; "AlterEgo ist alles, was Altoholic hätte sein sollen" |
| AlterEgo-Nutzer | Lob: schneller Blick auf **Vault-Slots, iLvl, Raid-Fortschritt**; tägliche Nutzung wegen Übersichtlichkeit |
| AlterEgo-Issues | Meist-gewünscht: **Fenster skalieren**, **Schriftart/-größe**, **eigenen Char hervorheben**, Fensterposition merken, Minimap-Tooltip mit Kurzübersicht, `!keys`-Chat-Antwort, Portal-Besitz-Anzeige, "Runs diese Woche X/8" |
| AlterEgo v1.3.4 (Midnight) | **Stat-Squish**: Itemlevel stimmen erst nach Relog aller Chars — Datenpflege nach Squish ist ein echtes Problemfeld |
| AltVault-Featureliste | Rested XP, **Post-Indikator**, "kann WoW-Token leisten", gespielte Zeit/letzter Login, PvP-Infos, Gildeninfos |
| WoWthing | Currencies auch aus alten Erweiterungen, Gold-Verlauf, Chars **ausblenden/filtern**, Holiday-/Weltboss-Lockouts |
| r/wow (Armory-Nutzer) | Wunsch nach **Export** ("wie simple armory") |

---

## 2. Abgleich mit exo-Twinks + Aufwandsbewertung

### 🟢 Haben wir schon (gut fürs CurseForge-Marketing!)
- Tooltip "X davon auf anderen Chars" (DER BagSync-Killer-Wunsch) ✅
- Vault/M+/Lockouts/Weeklies je Char (SavedInstances-Ersatz) ✅
- Item-Suche über alle Chars, Liste⇄Symbole, Gruppierungen ✅
- Currencies, Mail, Berufe, Reputationen, gespielte Zeit ✅
- Leichtgewichtig + 436 automatische Tests (= Patch-Day-Robustheit,
  genau die Altoholic-Schwäche!) ✅

### 🟡 QUICK WINS — leicht integrierbar, hoher Wunsch-Faktor
| # | Wunsch | Aufwand | Umsetzung in unserer Architektur |
|---|---|---|---|
| Q1 | **Fensterposition merken** | leicht | OnDragStop → Position in ExoTwinksDB.options; beim Öffnen wiederherstellen |
| Q2 | **Fenster-Skalierung** | leicht | `window:SetScale(opt)`; Regler im Designer-Tab (0.7–1.3) |
| Q3 | **Eigenen Char in der Matrix hervorheben** | leicht | Characters-Tab: Zeile mit `Store:GetCurrentKey()` einfärben |
| Q4 | **Rest-XP anzeigen** | leicht | `GetXPExhaustion()` in Characters-Collector; Spalte/Detail |
| Q5 | **Minimap-Tooltip: Vault-Status je Char** | leicht | Minimap.lua-Tooltip um Vault-Spalte ergänzen (Daten vorhanden) |
| Q6 | **Chars ausblenden/anordnen** | leicht-mittel | options.hiddenChars + Filter in Public.lua; UI im Designer |
| Q7 | **"Runs diese Woche X/8"** | leicht | M+-Daten vorhanden → Zähler in Characters-/Overview-Tab |
| Q8 | **Post-Indikator** (Char hat ablaufende Mail) | leicht | Mail-Daten vorhanden → Icon/Spalte + Ablauf-Warnfarbe |

### 🟠 MITTEL — ein eigenes Release wert
| # | Wunsch | Aufwand | Anmerkung |
|---|---|---|---|
| M1 | `!keys`-Antwort im Chat + Keystone-Ansage | mittel | CHAT_MSG-Events + Keystone-Daten (vorhanden); Opt-in! |
| M2 | Schriftgröße (erst mal OHNE Fontwechsel) | mittel | Ein globaler Font-Scale im Designer; echte Font-Dateien = später |
| M3 | Export (CSV/Markdown der Übersicht) | mittel | EditBox-Popup mit generiertem Text (Copy&Paste, kein IO nötig) |
| M4 | PvP-Infos (Ehre/Eroberung/Rating) | mittel | Neuer Mini-Collector, Spalten in Characters |
| M5 | Stat-Squish-Hygiene | mittel | Daten-Versionsstempel je Char; nach Squish/Major-Patch alte iLvl als "veraltet" grau markieren statt falsch anzeigen |
| M6 | Portal-Besitz (M+-Teleports) | mittel | Achievement-Check je Dungeon; passt zu Roadmap "M+-Komfort 1.0.0" |

### 🔴 HOCH / bewusst NICHT (Fokus halten)
- Transmog-/Mount-/Pet-Collection-Tracking (WoWthing-Domäne) — eigenes Universum
- "Rating-Wizard" (beste Score-Gewinne) — AlterEgo-Autor hat es selbst verworfen
- Gold-Verlauf als Zeitreihe — nettes Extra, aber Speicher+UI-Aufwand
- Account-übergreifender Sync — steht schon als "später" im TODO

---

## 3. Empfehlung

**v1.10.0 "Community-Wünsche":** Q1+Q2+Q3+Q4+Q5 (alle leicht, decken die
häufigsten AlterEgo-Wünsche ab) — danach **v1.11.0:** Q6+Q7+Q8.
M1–M6 einzeln nach Priorität des Users. Die 🟢-Punkte gehören prominent in die
CurseForge-Beschreibung ("the BagSync tooltip + the AlterEgo overview in one").

> Abgleich: Q4/Q6 standen schon als ⬜ in `docs/TODO-SPIELERBEDUERFNISSE.md`
> (Rest-XP, Bank-Alt-Gruppen) — die Recherche bestätigt deren Nachfrage.
