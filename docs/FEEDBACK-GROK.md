# Externes Feedback (Grok) — Empfohlene naechste Funktionen

> Quelle: Grok-Konversation (vom User am 2026-09-27 uebergeben, nach v1.2.0).
> Wortlaut unveraendert gespeichert. Tier 3 ("heute weniger relevant") war
> in der Uebergabe nicht enthalten.
> Bewertung und Umsetzungsplan: siehe `docs/PLAN-NACH-1.2.md`.

Ziel: **breiter und tiefer werden**, ohne wieder zum Altoholic-Monolithen
zu werden. Prioritaet = Nutzen fuer typische Twink-/Altoholic-Spieler x
Passung zur bestehenden Architektur.

## Tier 1 — Hoher Nutzen, passt perfekt (als Naechstes)

### 1. Auktionen (AH-Listings der Alts)
- Was liegt auf dem AH? Von welchem Char? Preis, Restzeit, Gebote.
- Warum: Klassiker bei Altoholic, fehlt bei Exo noch (steht schon in der Roadmap).
- Aufwand: mittel (Collector + Uebersicht-Modul oder eigener Unterbereich im Inventar).
- Bonus: /exo ah analog zu keys/mail/vault.

### 2. Berufe vertiefen (Materialien + "kann craften?")
- Pro Rezept: benoetigte Materialien + ob sie accountweit vorhanden sind (wie Item-Counts).
- Gelbe Hinweise, wenn Beruf gelernt, aber Rezepte noch nie gescannt.
- Warum: Groesste inhaltliche Luecke zu Altoholic. Exo hat schon Skill + Suche —
  das ist der logische naechste Schritt.
- Aufwand: mittel-hoch, aber sehr spuerbar.

### 3. Alt-Gruppen / Bank-Rollen
- Charaktere als "Bank", "Gatherer", "Crafter", eigene Gruppen markieren.
- Filter in Uebersicht, Inventar und Suche ("nur Bank-Twinks", "nur Gruppe Raid").
- Warum: Altoholic hat das, und mit vielen Alts wird die Matrix sonst unuebersichtlich.
- Aufwand: eher UI + Optionen, Datenmodell ist schon da (meta).

### 4. Bag-Space richtig (Altoholic-Niveau)
- Nicht nur freie Slots, sondern: Taschengroesse, Typ (Normal/Reagenz/...),
  wer braucht Upgrade.
- Optional eigene Zeile in der Charakter-Matrix.
- Warum: Das Modul "Taschenplaetze" ist gut — die klassische
  Bag-Usage-Ansicht fehlt noch.
- Aufwand: gering-mittel.

## Tier 2 — Stark, aber etwas spezieller

### 5. Gildenbank tiefer
- Nicht nur "zaehlt in Tooltips/Suche", sondern eigener Browse
  (Tabs, Inhalt pro Gilde).
- Warum: Altoholic ist hier stark; wer mehrere Gilden/Bank-Alts hat,
  merkt den Unterschied.
- Aufwand: mittel.

### 6. Equipment-Vergleich ausbauen
- Schon vorhanden — ausbauen zu: "bester Slot accountweit",
  Upgrade-Hinweise, eventuell Set-Bonus-Skizze.
- Warum: Beim AH-Einkaufen und Twink-Gear sehr nuetzlich.
- Aufwand: mittel.

### 7. Warband-Bank & Account-Bank klarer
- Eigene Ansicht / Filter "nur Warband", freie Slots der Account-Bank.
- Warum: Retail-Mechanik, die Altoholic historisch nachruesten musste —
  Exo kann das sauber machen.
- Aufwand: gering-mittel.

### 8. Mail vertiefen
- Inhalt der Mails (Item-Links), nicht nur Anzahl + Ablauf.
- Warum: "Was liegt in der Post?" ist ein Dauerbrenner.
- Aufwand: mittel (API-Limits beachten).
