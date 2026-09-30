# exo-Twinks — Bauplan nach 1.2.0

> Stand: 2026-09-27, Basis v1.2.0 (335 Tests gruen).
> Grundlage: `docs/FEEDBACK-GROK.md` (Tier 1/2), abgeglichen mit dem
> tatsaechlichen Code-Stand. NUR Plan — noch nichts implementiert.
> Loest die Rest-Roadmap aus `docs/PLAN-REDESIGN-1.0.md` ab.

## Faktencheck zuerst: Was davon ist schon (teilweise) da?

| Feedback-Punkt | Befund im Code (v1.2.0) |
|---|---|
| 2. "Gelbe Hinweise, wenn Rezepte nie gescannt" | **Schon drin** seit 1.1.1 (Berufe-Tab-Warnzeile + Scan-Status-Modul) |
| 3. "Bank markieren" | Bank-Twink-Flag schon drin (0.17.0); Gruppen/Rollen + Filter fehlen |
| 4. Freie Slots | `GetBagSpace` + Modul "Taschenplaetze" da; Groesse/Typ je Tasche + Matrix-Zeile fehlen |
| 5. Gildenbank | Scan liegt bereits im BagSet-Format pro Tab vor -> Browse ist fast nur UI |
| 7. Warband | Ist Inventar-Ziel + Such-Ort-Filter; nur freie Slots fehlen |
| 8. Mail-Inhalte | Items (id/count/name) werden seit 0.16.0 pro Mail GESPEICHERT — nur die Anzeige fehlt! Aufwand ist "gering", nicht "mittel" |
| 1. Auktionen | Schema-Platzhalter `auctions = {}` existiert -> additiv, keine Migration |

## Release-Kette

### v1.2.1 — "Geschenkte" Features ✓ (ausgeliefert)
Punkte 8 + 5 + 7 — geringer Aufwand, weil nur Anzeige/Verkabelung:
1. **Mail-Inhalte** (Punkt 8): Post-Tab zeigt pro Mail die Anhaenge als
   Itemnamen in Seltenheitsfarbe (`Format.ItemName` + `GetItemQuality`);
   Shift-Klick auf die Mail-Zeile = Itemlink in den Chat (Muster 0.16.0).
   Kein neuer Scan — `mails.list[].items` liegt komplett vor.
2. **Gildenbank-Browse** (Punkt 5): `Inventory.GetTargets()` um einen
   Eintrag je Gilde erweitern (`__guild:<Name>`, Daten via `Store:GetGuilds()`
   im identischen BagSet-Format wie Kriegsmeute) -> Liste/Symbole,
   Gruppierung, Sortierung und Suche funktionieren automatisch mit.
   Optional: Tab-Filter je Gildenbank-Tab spaeter (1.4.0).
3. **Warband-Freiplaetze** (Punkt 7): `API.GetWarbandSpace()` (tally wie
   GetBagSpace ueber account.warbandBank) + Zeile im Modul
   "Taschenplaetze" + Footer im Inventar, wenn Ziel = Kriegsmeute.
- Tests: ~8 (Mail-Anzeige/Link, Gilden-Ziel Browse+Zaehler, WarbandSpace).

### v1.3.0 — Auktionen (Punkt 1) ✓ (ausgeliefert)
- **Collector `Auctions.lua`**: AUCTION_HOUSE_SHOW ->
  `C_AuctionHouse.GetOwnedAuctions()` (+ OWNED_AUCTIONS_UPDATED entprellt).
  Sektion `auctions` = { scannedAt, list = { itemID, qty, buyout, bid,
  timeLeftBand } }. Ablauf wie bei Mails: Restzeit-Band + Scan-Zeit
  speichern, offline weiterrechnen.
- **Anzeige**: Uebersicht-Modul "Auktionen" (je Char: N Auktionen,
  Buyout-Summe, ablaufend rot/gelb) + Fundort "Auktionshaus" in
  Suche/Tooltips (ItemCounts um Quelle "auctions" erweitern — gleiches
  Muster wie "guild" in 0.16.0).
- **APIs**: GetAuctions(charKey), GetAuctionSummary(). **Slash**: /exo ah.
- Risiko: C_AuctionHouse liefert Owned-Liste erst nach AH-Oeffnung
  (ggf. QueryOwnedAuctions noetig) -> im Wrapper kapseln, Mock simuliert.

### v1.4.0 — Berufe-Tiefe: Materialien + "Kann craften?" (Punkt 2) ✓ (ausgeliefert)
- **Rezeptformat erweitern**: `recipes[id] = { name, reagents = { {itemID,
  qty} } }` via `C_TradeSkillUI.GetRecipeSchematic` beim Rezept-Scan.
  ABWAERTSKOMPATIBEL lesen: alter Wert ist String (nur Name) -> Leser
  behandeln `string | table` (kein Schema-Bruch, KEINE Migration; alte
  Eintraege werden beim naechsten Berufsfenster-Besuch angereichert).
- **API `CanCraft(recipeID)`**: Materialabgleich gegen `GetItemCounts`
  (Taschen+Bank+Warband+Gildenbank) -> { craftable, missing = {itemID,
  need, have} }.
- **UI**: Rezept-Suche zeigt gruen "craftbar" / gelb "es fehlen: 2x Erz"
  (Semantic Colors); Klick auf Treffer listet Material-Status im Chat.
- Aufwand mittel-hoch: groesster Brocken der Liste, eigenes Release.

### v1.5.0 — Alt-Gruppen/Rollen + Bag-Details (Punkte 3 + 4) ✓ (ausgeliefert)
- **Rollen** (verallgemeinert die Bank-Twink-Markierung): Option
  `role.<charKey>` = bank|crafter|gatherer|main|<frei>. Setzen im
  Charakter-Detail (Zyklus-Button ersetzt den reinen Bank-Toggle;
  Bank-Flag wird als role=bank uebernommen).
- **Filter**: Charaktere-Matrix + Uebersicht-Charmodul + Such-Schnellfilter
  "Rolle: Alle/Bank/Crafter/..." (Zyklus-Button, Muster AH-Filter 0.13.0).
- **Bag-Details** (Punkt 4): Containers-Scan speichert je Tasche zusaetzlich
  `bagItemID` (GetInventoryItemID der Taschen-Slots) -> Groesse/Typ/Name
  der Tasche bekannt. Neue Matrix-Zeilengruppe "Taschen" (Designer-Toggle,
  Muster charRow.*) + Upgrade-Hinweis "kleinste Tasche < 20 Plaetze" gelb.

### v1.6.0 — Equipment-Intelligenz (Punkt 6) ✓ (ausgeliefert - PLAN KOMPLETT)
- **"Bester Slot accountweit"**: reine Funktion ueber `GetEquipment` aller
  Chars -> im Detail-Panel dritte Info je Slot ("best: 489 @ Anna").
- **Upgrade-Hinweis**: Slots > X iLvl unter dem Char-Schnitt rot markieren.
- Set-Bonus-Skizze: NICHT geplant (Datenpflege-Falle, wenig Nutzen).

## Bewusst NICHT geplant (mit Grund)
- Dungeon-Teleports: Secure-Button/Combat-Restriktionen, nicht testbar.
- Multi-Account-Live-Sync: SV-Kopie reicht, dokumentiert im README.
- Neuer Monolith-Tab pro Feature: neue Inhalte docken als Uebersicht-Module,
  Inventar-Ziele oder Detail-Sektionen an — Navigation bleibt bei 7 Reitern.

## Leitplanken (gelten fuer jedes Release)
1. Reine, getestete Datenfunktionen; UI nur duenne Schicht (busted + luacheck 0/0).
2. Neue Schema-Sektionen nur additiv; erste STRUKTUR-Aenderung -> Migration 002.
3. Alles Konfigurierbare ueber Exo.API.GetOption/SetOption + Designer.
4. Jedes Release: CHANGELOG-Block (mit assert auf Marker!), README-Abgleich, Beta-ZIP.
