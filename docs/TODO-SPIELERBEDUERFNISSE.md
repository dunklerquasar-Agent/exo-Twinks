# To-do's: Spielerbeduerfnisse (Altoholic-Nutzer)

> Quelle: Zusammenfassung der Kernbeduerfnisse von Alt-Spielern (Sep 2026).
> Leitidee: **Maximale Transparenz ueber den ganzen Account, ohne umloggen —
> mit moeglichst wenig Aufwand.**
>
> Status-Legende: ✅ umgesetzt · 🔜 auf der Roadmap (Version) · ⬜ offen/neu
> Roadmap-Referenz: `docs/PLAN-3IN1.md` (0.11.0 → 1.0.0)

---

## 1. Uebersicht ueber alle Alts auf einen Blick

- [x] ✅ Charaktere-Tab im AlterEgo-Stil: Matrix aller Chars (Gold, Item-Level,
      Weeklies, Vault, Currencies)
- [ ] ⬜ Spielzeit (/played) je Char + Gesamt erfassen und anzeigen
- [x] ✅ Rest-XP / Level-Fortschritt anzeigen (Zeilen Level/Erholt; bestaetigt 1.10.0)
- [ ] ⬜ Gesamtsummen-Zeile: Gold pro Realm und ueber den ganzen Account
- [x] ✅ Chars ausblenden (1.11.0); Rollen-Filter Main/Bank/... seit 1.5.0

## 2. Inventar & Suche ueber alle Charaktere  *(laut User am wichtigsten)*

- [x] ✅ Taschen + Bank + Kriegsmeute-Bank aller Chars im Inventar-Tab
- [x] ✅ Gruppierung: Typ / Unterart / Seltenheit / Erweiterung (0.10.3),
      Liste ⇄ Symbole (0.10.2), Seltenheitsfarben
- [x] ✅ Suche-Tab: Item-Suche ueber alle Chars mit Fundort-Anzeige
- [x] ✅ Tooltip-Hinweis: „Du hast X davon auf anderen Chars"
- [ ] 🔜 (0.12.0) Briefkasten/Mailbox erfassen + durchsuchbar
- [ ] 🔜 (0.12.0) Gildenbank erfassen + durchsuchbar
- [ ] 🔜 (0.12.0) Shift-Klick-Itemlinks in Liste und Suche
- [ ] ⬜ AH-artige Suchfilter: Mindest-/Maximallevel, Qualitaet, Typ/Unterart
      als Filter (nicht nur Gruppierung) — Ausbau des Suche-Tabs

## 3. Berufe & Rezepte

- [ ] 🔜 (0.13.0) Berufe-Uebersicht: alle Professionen + Skill-Level je Char
- [ ] 🔜 (0.13.0) Rezepte: bekannt/unbekannt je Char
- [ ] ⬜ „Kann ich das craften?": Materialbedarf gegen Bestaende aller Chars
      pruefen (baut auf Inventar-Daten auf)

## 4. Weitere Infos zentral

- [ ] 🔜 (0.13.0) Equipment-Ansicht: Ausruestung aller Alts vergleichen
- [x] ✅ Raid-/M+-Lockouts + Great Vault je Char (SavedInstances-Ersatz)
- [x] ✅ Currencies je Char (Season.lua pflegt die Liste)
- [ ] ⬜ Quest-Logs: wer hat welche Quest angenommen/abgeschlossen?
- [ ] ⬜ Reputationen: Fraktions-Standing aller Chars („alle mind. Geehrt?")
- [ ] ⬜ Mail-Warnungen: Ablaufdatum eingehender Post (gehoert zu 0.12.0 Mailbox)
- [ ] ⬜ Spaeter/optional: Achievements, Mounts, Pets, Talente

## 5. Multi-Account / Multi-Realm

- [x] ✅ Datenmodell ist multi-realm-/multi-account-faehig
      (CharKey = Account.Realm.Name; Realm-uebergreifende Anzeige)
- [ ] ⬜ Account-uebergreifendes Teilen der Daten (Export/Import oder
      Sync zwischen zwei WoW-Accounts)

---

## Einordnung in die Roadmap

| Version | Deckt Beduerfnis ab |
|---|---|
| 0.11.0 | Minimap-Button/Broker-Tooltip (Uebersicht ohne Fenster oeffnen) |
| 0.12.0 | Mailbox, Gildenbank, Itemlinks → Punkt 2 komplett |
| 0.13.0 | Equipment + Berufe/Rezepte → Punkte 3 und 4 (teilweise) |
| 1.0.0  | M+-Komfort (Ansagen/Teleport/Affixe) + Feinschliff |
| danach | Neue Kandidaten aus dieser Liste: /played + Rest-XP,
Gold-Summen, Bank-Alt-Gruppen, Questlog, Reputationen, Suchfilter |

## 6. Community-Wuensche (Recherche Okt 2026, docs/RECHERCHE-SPIELERWUENSCHE-2026.md)

- [x] ✅ Fensterposition merken + Reset-Button (1.10.0)
- [x] ✅ Fenster-Skalierung 70-130 % im Designer (1.10.0)
- [x] ✅ Eingeloggten Char in der Matrix hervorheben (1.10.0)
- [x] ✅ Vault-Status im Minimap-Tooltip (1.10.0)
- [x] ✅ Charaktere ausblenden im Designer (1.11.0)
- [x] ✅ Post-Indikator mit Ablauf-Warnung in der Matrix (1.11.0)
- [ ] ⬜ !keys-Chat-Antwort, Export, PvP-Spalten (M1/M3/M4, danach)

## 7. Item-Kern (Kernmechanik laut User, Okt 2026 - docs/ITEM-KERN-AUDIT.md)

- [x] ✅ Post-Anhaenge im Item-Index: Tooltip "Post X" + Ort-Filter (1.12.0)
- [x] ✅ Angelegte Items im Index: Tooltip "Angelegt X" + Ort-Filter (1.12.0)
- [x] ✅ Bank-/KM-Reiter im Tooltip (1.11.1)
- [ ] ⬜ "Kann ich das craften?" - Materialbedarf vs. Bestand (naechster Kern-Ausbau)
- [ ] ⬜ AH-artige Suchfilter: Mindest-/Max-iLvl als Filter
