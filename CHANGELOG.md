# Changelog

Format: [Keep a Changelog](https://keepachangelog.com/de/1.1.0/), Versionierung: SemVer.

## [1.10.0] - Community-Wuensche I
### Neu (aus der Spielerwunsch-Recherche, docs/RECHERCHE-SPIELERWUENSCHE-2026.md)
- Fensterposition wird gemerkt und beim naechsten Oeffnen wiederhergestellt;
  Designer: neuer Button "Position zentrieren".
- Fenster-Skalierung 70-130 % als Zyklus-Button im Designer ("Skalierung: X %").
- Charaktere-Matrix: der eingeloggte Charakter wird hervorgehoben
  (Akzent-Spalte + Pfeil im Spaltenkopf).
- Minimap-Tooltip zeigt je Char den Schatzkammer-Status "V Raid/M+/Welt".
### Hinweis
- Rest-XP/Level-Fortschritt und "Runs diese Woche" waren bereits vorhanden
  (Zeilen "Level"/"Erholt"/"Schatzkammer" im Charaktere-Tab).

## [1.9.2] - Korrekte Itemlevel bei M+-aufgewerteten Items
### Behoben (User-Report: z. B. Siegel-Ring zeigte falsches Itemlevel)
- Itemlevel angelegter Ausruestung wird jetzt ueber die Item-INSTANZ ermittelt
  (C_Item.GetCurrentItemLevel) statt ueber den Itemlink - bei saisonal
  aufwertbaren Items (M+-Aufwertungssystem) traegt der Link nur das
  Basis-Level. Link-Abfrage bleibt als Fallback fuer alte Clients.
- Neuer Trigger ITEM_CHANGED: Wird ein angelegtes Item beim Haendler an Ort
  und Stelle aufgewertet, scannt das Addon die Ausruestung sofort neu.

## [1.9.1] - Symbolansicht fuer Bank, KM-Bank und KM-Items
### Behoben (User-Report: Umschalten auf Symbole ging nicht)
- Die Reiter "Bank", "KM-Bank" und "KM-Items" haben jetzt denselben
  Liste/Symbole-Umschalter wie das Inventar (Button oben rechts).
- Symbol-Raster mit Qualitaetsrahmen, Stueckzahl am Icon, Hover-Tooltip
  und Shift-Klick-Itemlink; Charakter-Kopfzeilen bleiben in KM-Items
  auch im Symbol-Modus erhalten.
- Anzahl der Icons pro Zeile passt sich der Fensterbreite an.

## [1.9.0] - Eigener Bank-Reiter je Charakter
### Neu (Nutzerwunsch: Bank separat)
- Neuer Reiter "Bank": zeigt die CHARAKTERBANK jedes einzelnen
  Charakters separat (Auswahl per Aufklapp-Liste) - das Gegenstueck zum
  Reiter "KM-Bank", der die Kriegsmeutenbank des gesamten Accounts zeigt.
- Fusszeile mit Stueckzahl und freien Bankplaetzen des gewaehlten Chars;
  Scan-Hinweis, wenn der Char seine Bank noch nie besucht hat.
- Wie ueberall: Hover-Tooltip, Shift-Klick-Itemlink, sortierbare Spalten.
- Neue API: Exo.API.GetCharacterBankItems(charKey).
### Intern
- Listen-Mechanik (Tooltip/Sortierung/Zeilenaufbau) in das gemeinsame
  Framework-Modul Exo.UI.ItemList ausgelagert (genutzt von Bank,
  KM-Bank und KM-Items) - weniger doppelter Code.

## [1.8.1] - KM-Items zeigt nur noch verschiebbare Teile
### Behoben (User-Report: bereits gebundene Items in der Liste)
- "Bis zum Anlegen"-Items, die schon angelegt wurden, sind seelengebunden
  und lassen sich NICHT mehr in die Kriegsmeutenbank verschieben - der
  Item-Typ meldet aber weiterhin "kriegsmeutengebunden". Solche Teile
  tauchten deshalb faelschlich im Reiter "KM-Items" auf.
- Fix: "Bis zum Anlegen" zaehlt nur noch ueber die beim Scan geprueften
  EXEMPLARE (wirklich noch verschiebbar). Dauerhaft accountgebundene
  Items (Erbstuecke & Co.) bleiben gelistet - die sind immer verschiebbar.
- Titelzeile des Reiters weist jetzt darauf hin ("nur verschiebbare").
### Hinweis
- Nach dem Update einmal einloggen (Taschen scannen automatisch) und
  fuer Bank-Bestaende die Bank oeffnen, damit die Exemplar-Pruefung
  ueberall frisch ist.

## [1.8.0] - Zwei eigene Kriegsmeute-Reiter + Hover-Tooltips
### Neu (Nutzerwunsch: "getrennt")
- Eigener Reiter "KM-Bank": der Inhalt der Kriegsmeutenbank selbst als
  sortierbare Liste, Fusszeile mit Stueckzahl und freien Plaetzen.
- Eigener Reiter "KM-Items": alle kriegsmeutengebundenen Items je
  Charakter ("Rabisu hat 10 Items, Myrnia 5, ..."), mit Kopfzeile und
  Item-/Stueck-Zaehler pro Char.
- HOVER-TOOLTIP: In beiden Listen (und jetzt auch in der Inventar-
  Bestandsliste) oeffnet das Ueberfahren einer Item-Zeile den normalen
  Spiel-Tooltip; Shift-Klick postet weiterhin den Itemlink.
- Beide Reiter lassen sich im Designer ein-/ausblenden.
### Geaendert
- Der Modus "Kriegsmeute" im Inventar-Reiter ist in den neuen Reiter
  "KM-Items" umgezogen (Inventar hat wieder nur Bestand|Suche).

## [1.7.1] - Bugfix: "bis zum Anlegen" wurde nicht erkannt
### Behoben (User-Report: warbound Items fehlten in der Uebersicht)
- "Kriegsmeutengebunden bis zum Anlegen" haengt oft am konkreten
  EXEMPLAR, nicht an der Item-ID (der Item-Typ ist meist normales BoE).
  Solche Teile fehlten in der Kriegsmeuten-Ansicht komplett.
- Fix: Die Exemplar-Bindung wird jetzt direkt beim Taschen-/Bank-Scan
  am Platz erkannt (C_Item.IsBoundToAccountUntilEquip) und in der
  Datenbank mitgespeichert.
- Bonus: Damit funktioniert die Anzeige auch fuer Items, deren Infos
  der Client noch nicht geladen hat (vorher fiel die Erkennung auf
  nicht gecachte GetItemInfo-Daten herein).
### Hinweis
- Taschen werden beim Einloggen automatisch neu gescannt; fuer die
  BANK-Bestaende einmal die Bank mit dem jeweiligen Char oeffnen.

## [1.7.0] - Kriegsmeutengebunden-Uebersicht
### Neu
- Inventar-Tab hat einen dritten Modus "Kriegsmeute": eine eigene
  Uebersicht aller KRIEGSMEUTENGEBUNDENEN Items - gruppiert je Charakter
  ("Char X hat dieses und dieses warbound Teil in Taschen/Bank").
- Erkannt werden alle drei Bindungsarten: Accountgebunden,
  Kriegsmeutengebunden und "Kriegsmeutengebunden bis zum Anlegen"
  (Enum.ItemBind 7/8/9, dynamisch vom Client).
- Gleiche Spalten wie der Bestand (Anzahl/Taschen/Bank), sortierbar per
  Header-Klick; Shift-Klick verlinkt das Item in den Chat; Fusszeile
  zaehlt Items, Charaktere und Stueck.
- Neue API fuer Bastler: Exo.API.GetWarboundByCharacter().

## [1.6.4] - Bugfix: doppelt gezaehlte Kriegsmeuten-Items
### Behoben (Screenshot-Report: "2464 insgesamt" statt 616)
- Vor dem 1.6.2-Fix landete Kriegsmeuten-Tab 1 faelschlich in der
  CHARAKTER-Bank jedes Chars, der die Bank besucht hat. Diese Altlasten
  blieben in der Datenbank kleben und wurden im Tooltip pro Char als
  "Bank" gezaehlt (4 Chars x 616 = 2464).
- Fix: Beim Login werden automatisch alle Bank-Eintraege entfernt, deren
  Bag-ID heute ein Kriegsmeuten-Tab ist - fuer ALLE gespeicherten Chars,
  ohne dass jeder einzeln die Bank besuchen muss. Echte Bankfaecher
  bleiben unangetastet.
- Danach zeigt der Tooltip den Bestand korrekt einmal als "Kriegsmeute"
  (Bank einmal oeffnen, falls der Warband-Scan noch aussteht).

## [1.6.3] - Container-Struktur-Audit
### Geaendert
- Alle vier Container-Bereiche auf einheitlich dynamische IDs gestellt
  (Referenz: docs/CONTAINER-STRUKTUR.md):
  - Rucksack/Taschen/Reagenzientasche: IDs aus Enum.BagIndex
    (Backpack, Bag_1..N, ReagentBag), Fallback 0-5.
  - Charakterbank + Kriegsmeutenbank: bereits seit 1.6.2 Enum-basiert.
  - Gildenbank: Slots pro Tab vom Client (MAX_GUILDBANK_SLOTS_PER_TAB,
    Fallback 98) statt hart 98; Tab-NAMEN werden jetzt mitgespeichert
    ("Mats", "Raid-Zeug", ...) fuer kuenftige Anzeigen.
### Behoben
- GetBagItemID wird nur noch fuer echte Char-Taschen (1-5) aufgerufen --
  Bank-TABS des 11.2-Layouts haben keine Inventar-Slots; der alte
  Bereich (bis 12) war ein API-Fehler-Risiko.

## [1.6.2] - Bugfix Kriegsmeutenbank, Teil 2
### Behoben (In-game-Bugreport: "Petbattle-Items fehlen komplett")
- Treffer, Verdacht bestaetigt: Es wurde ein ganzes FACH der Kriegsmeuten-
  bank nicht ausgelesen. Seit dem Bank-Umbau (Patch 11.2) beginnen die
  Kriegsmeuten-Tabs bei Bag-ID 12 - das Addon scannte fest 13-17 und
  hat damit TAB 1 komplett verpasst (dort lagen die Petbattle-Items).
- Fix: Die Bag-IDs kommen jetzt zur Laufzeit aus Enum.BagIndex
  (AccountBankTab_1..N, CharacterBankTab_1..N). Damit stimmen auch die
  Charakterbank-Tabs des neuen Layouts; aeltere Clients nutzen
  automatisch die bisherigen IDs als Fallback.
- Nach dem Update: Bank einmal oeffnen - alle Tabs (inkl. Tab 1) werden
  neu erfasst und tauchen in Suche, Tooltips und Inventar auf.

## [1.6.1] - Bugfix Kriegsmeutenbank
### Behoben (In-game-Bugreport)
- Kriegsmeutenbank zeigte weniger Items als tatsaechlich vorhanden:
  - Der Client laedt die Inhalte der Warband-Tabs oft erst NACH dem
    Bank-Oeffnen-Event nach -- der einmalige Sofort-Scan erwischte dann
    nur einen Teil. Jetzt wird 1 Sekunde nach dem Oeffnen automatisch
    nachgefasst (gilt auch fuer die Charakter-Bank).
  - BAG_UPDATE-Events fuer Warband-Tabs (13-17) und Bank-Taschen (6-12)
    wurden ignoriert -- Einzahlungen/Nachzuegler bei offener Bank loesen
    jetzt einen entprellten Rescan des richtigen Bereichs aus.
- Tipp: einmal die Bank oeffnen (und kurz offen lassen) genuegt, um den
  Bestand zu korrigieren.

## [1.6.0] - Equipment-Intelligenz (Bauplan komplett)
### Hinzugefuegt
- "Bester Slot accountweit": Im Charakter-Detail (ohne Vergleich) zeigt
  die zweite Spalte je Ausruestungs-Slot, wo der beste Wert liegt -
  grau "best: 489 @ Anna" oder gruen "dein Bestwert".
- Upgrade-Hinweise: Slots, die 15+ Itemlevel unter dem Schnitt des Chars
  liegen, werden rot markiert - AH-Einkaufsliste auf einen Blick.
- Neue UI-API: CharacterDetail.GetBestSlots().
### Hinweise
- Set-Bonus-Skizze bewusst NICHT umgesetzt (Datenpflege-Falle, s. Plan).
- Damit ist docs/PLAN-NACH-1.2.md vollstaendig abgearbeitet.

## [1.5.0] - Alt-Rollen + Bag-Details
### Hinzugefuegt
- Rollen fuer Twinks: Main, Bank, Crafter, Sammler. Zuweisen im
  Charakter-Detail ("Rolle:"-Button, Klick schaltet durch). Die alte
  Bank-Twink-Markierung wird automatisch als Rolle "Bank" uebernommen.
- Rollen-Filter:
  - Charaktere-Matrix: Button "Rolle: Alle" links oben filtert die
    Spalten (Alle -> Main -> Bank -> Crafter -> Sammler).
  - Item-Suche: neuer Schnellfilter "Rolle" in der Filterleiste.
  - Uebersicht zeigt Rollen-Tags ([Main]/[Bank]/[Crafter]/[Sammler]).
- Bag-Details:
  - Der Taschen-Scan merkt sich die ItemID jeder ausgeruesteten Tasche.
  - Neue Matrix-Zeile "Taschen frei" (farbcodiert: rot < 5, gelb < 15),
    im Designer unter "Charaktere: Zeilen" abschaltbar.
  - GetBagSpace liefert die kleinste ausgeruestete Tasche; das Modul
    "Taschenplaetze" warnt bei Taschen unter 20 Plaetzen
    ("kleinste Tasche: 12 Plaetze").
- Neue APIs: CharacterDetail.GetRole/SetRole/CycleRole (UI-seitig),
  GetBagSpace().smallestBag.

## [1.4.3] - UI-Poliersprint (aus dem Spieler-Review)
### Geaendert
- Klickbares sieht jetzt klickbar aus: alle interaktiven Listenzeilen
  (Uebersicht-Kopfzeilen/Hinweise/Steuer, Suche, Inventar, Post, Berufe,
  Ziel-Aufklappliste) hellen sich bei Maus-over auf.
- Item-Icons (16px) vor den Namen in der Item-Suche, der Inventar-Liste
  und der Post (Icon des ersten Anhangs).
- Uebersicht-Erststart ohne Textwand: beim ALLERERSTEN Oeffnen sind nur
  Charaktere, Mythic+ Woche und Scan-Status aufgeklappt. Greift nur, wenn
  die Uebersicht noch nie benutzt/verstellt wurde; alles bleibt wie
  gewohnt per Klick aufklappbar (und wird gespeichert).
- Das Fenster merkt sich den zuletzt aktiven Reiter (window.lastTab).
- Farb-Diaet in der Uebersicht: Sekundaeres konsequent grau, eine
  Signalfarbe pro Zeile (M+-Wertung in der Charzeile ohne Extra-Farbe).

## [1.4.2] - Gildensteuer sichtbar + Saetze im UI
### Behoben/Geaendert (In-game-Feedback)
- Steuersaetze sind jetzt DIREKT IM UI einstellbar: Designer >
  "Steuersaetze (Klick)" - je bekannte Gilde ein Button, Klick schaltet
  0 -> 1 -> 2 -> 3 -> 5 -> 10 -> 15 -> 20 -> 0 Prozent. Kein Slash noetig
  (/exo tax rate bleibt fuer krumme Werte).
- Der offene Betrag ist jetzt ersichtlich:
  - Fensterkopf (Account-Summary) zeigt "Steuer offen: Xg" in gelb,
    sobald die Steuer aktiv ist und etwas offen steht.
  - Gilden mit gesetztem Satz erscheinen im Uebersicht-Modul auch dann,
    wenn ihre Chars noch nicht (seit 1.2.0) eingeloggt waren - mit
    Hinweis "Gilde wird beim Login erkannt".
  - Modul-Hinweis verweist auf den Designer statt aufs Slash-Kommando.
- Neue API: Exo.API.GetGuildTaxRates().

## [1.4.1] - Ziel-Aufklappliste im Inventar
### Geaendert
- Inventar: Klick auf den Charakter-Button klappt jetzt eine Liste ALLER
  Ziele auf (Charaktere, Kriegsmeute, Gildenbanken) - Ziel direkt
  anklicken statt durchzyklieren. Aktuelles Ziel ist akzentfarben
  hinterlegt, lange Listen scrollen per Mausrad (max. 12 sichtbar).
  Die Liste schliesst bei Auswahl, erneutem Klick oder Moduswechsel.

## [1.4.0] - Berufe-Tiefe: Materialien + "Kann craften?"
### Hinzugefuegt
- Rezept-Scan erfasst jetzt die Pflicht-Reagenzien jedes Rezepts
  (C_TradeSkillUI.GetRecipeSchematic). Neues Rezeptformat { name, reagents };
  alte String-Eintraege bleiben lesbar und werden beim naechsten
  Berufsfenster-Besuch automatisch angereichert - KEINE Migration noetig.
- Neue API Exo.API.CanCraft(recipeID): Materialabgleich gegen alle
  Bestaende (Taschen, Bank, Kriegsmeute, Gildenbank). Eigene Auktionen
  zaehlen bewusst NICHT (nicht greifbar).
- Rezept-Suche zeigt den Craft-Status je Treffer:
  gruen "craftbar" | gelb "es fehlen: 3x Friedensblume, ..." |
  grau "Materialien unbekannt" (Berufsfenster erneut oeffnen).
- Klick auf einen Treffer druckt den vollstaendigen Material-Report in
  den Chat (+/- je Material, vorhanden/benoetigt, Fazit).

## [1.3.0] - Auktionen
### Hinzugefuegt
- Auktions-Collector: beim Oeffnen des Auktionshauses werden die eigenen
  Auktionen erfasst (Item, Menge, Buyout, Gebot, Restzeit-Band, verkauft).
  Die Restzeit rechnet offline weiter (Band + Scan-Zeitpunkt, wie Mails).
- Uebersicht-Modul "Auktionen": je Char aktive Auktionen, Buyout-Summe,
  Verkaeufe (gruen) und naechster Ablauf (unter 30 Min rot, unter 2 Std
  gelb); Gesamtzeile.
- Auktionen zaehlen als Bestand: Item-Tooltips ("AH 20"), Fundorte der
  Suche und neuer Ort-Filter "Auktionshaus". Verkaufte zaehlen nicht.
- /exo ah: Auktions-Bericht im Chat.
- Neue APIs: Exo.API.GetAuctions(charKey), GetAuctionSummary().

## [1.2.1] - "Geschenkte" Features (Daten waren schon da)
### Hinzugefuegt
- Post zeigt die Item-Anhaenge jeder Mail als Namen in Seltenheitsfarbe
  (max. 3, dann "+n weitere"); Shift-Klick auf eine Mail-Zeile fuegt alle
  Anhaenge als Itemlinks in den Chat ein.
- Gildenbank-Browse: jede gescannte Gildenbank ist jetzt ein eigenes Ziel
  im Inventar ("Gildenbank: <Name>") - mit Liste/Symbolen, Gruppierung
  und Sortierung wie gewohnt. Neue API: Exo.API.GetGuildItems(name).
- Kriegsmeuten-Freiplaetze: neue API Exo.API.GetWarbandSpace();
  Zeile im Uebersicht-Modul "Taschenplaetze" und im Inventar-Footer,
  wenn die Kriegsmeute als Ziel gewaehlt ist.

## [1.2.0] - Gildensteuer
### Hinzugefuegt
- Gildensteuer (persoenliches Feature): bei aktivierter Steuer wird fuer
  jede Einnahme des eingeloggten Chars der Prozentsatz seiner Gilde als
  "offen" verbucht (z. B. Gilde X 5%%, Gilde Y 2%%).
  - Saetze setzen: /exo tax rate <0-25> (gilt fuer die Gilde des
    eingeloggten Chars; 0 loescht den Satz).
  - Quellen einzeln waehlbar (Designer > Gildensteuer): Loot/Quests/
    Haendler [an], Post/AH [an], Handelsfenster [aus].
  - Uebersicht-Modul "Gildensteuer": offen je Gilde und Char, Gesamtzeile;
    Shift-Klick auf eine Char-Zeile setzt dessen Steuer auf 0.
  - Designer-Zeile: Aktiv-Schalter, Quellen-Schalter, "Alles auf 0"-Button.
  - /exo tax: Bericht im Chat.
  - WICHTIG: Das Addon bucht nie selbst Gold ab (von WoW nicht erlaubt) --
    es fuehrt nur Buch; ueberwiesen wird manuell.
- meta.guild: Gildenname wird jetzt pro Charakter erfasst.
- Neue APIs: Exo.API.GetGuildTax(charKey), GetGuildTaxReport().

### Intern
- Schema-Sektion "guildtax" (additiv, keine Migration noetig).
- Uebersicht-Zeilenfelder nutzen false statt nil (Mock-Kompatibilitaet).

## [1.1.1] - Feinschliff-Patch
### Hinzugefuegt
- Scan-Status ist jetzt actionable: Klick auf eine Zeile gibt den Hinweis
  ("Anna - Bank besuchen, ...") in den Chat.
- Uebersicht: Alt-Klick auf eine Modul-Kopfzeile schiebt das Modul nach
  hinten (Shift-Klick weiterhin nach vorn).
- Post: Warn-Zusammenfassung als erste Zeile ("2 Mails laufen in unter
  3 Tagen ab!"); Footer zaehlt einheitlich "N Mails bei M Charakteren".
- Ruf-Footer zaehlt Fraktionen; Berufe: 0 Rezepte -> gelbe Warnzeile
  "Rezepte unbekannt - Berufsfenster einmal oeffnen".
- Rezeptsuche sortiert Treffer mit den meisten Koennern zuerst.
- ESC schliesst das Hauptfenster (UISpecialFrames).
- Suchfelder: Enter uebernimmt/entfokussiert, Escape leert das Feld;
  Hex-Eingabe im Designer uebernimmt per Enter, Dauerhinweis "Format: RRGGBB".
- /exo help listet jetzt auch keys, vault und mail.
- Minimap-Tooltip: Zeile "Scan unvollstaendig: X Chars" (nur wenn noetig).

## [1.1.0] - Community-Feedback-Release
### Hinzugefuegt
- Uebersicht-Modul "Taschenplaetze": wer braucht groessere Taschen?
  Wenigste freie Plaetze zuerst, rot unter 5 / gelb unter 15 freien Slots;
  Hinweis, wenn die Bank noch nie gescannt wurde.
- Uebersicht-Modul "Scan-Status": pro Char fehlende manuelle Scans
  (Bank besuchen, Briefkasten oeffnen, Rezepte erfassen je Beruf) -
  gruene Entwarnung, wenn alles da ist. Neue API: Exo.API.GetScanStatus.
- Shift-Klick auf eine Modul-Kopfzeile der Uebersicht schiebt das Modul
  nach vorn (ersetzt die Reihenfolge-Buttons im Designer).
- /exo vault: offene Schatzkammer-Belohnungen aller Twinks im Chat.
- /exo mail: bald ablaufende Mails (7 Tage) im Chat.
- Minimap-Tooltip zeigt zusaetzlich den hoechsten Schluesselstein.
### Geaendert
- Item-Suche zeigt maximal 300 Zeilen (Footer nennt die Gesamtzahl) -
  fluessig auch bei 1000+ Treffern.
- Designer: Uebersicht-Module jetzt zweizeilig (8 Module).
### Geprueft (Review-Punkte, die bereits erledigt waren)
- Uebersicht speichert Reihenfolge + Ein-/Ausklapp-Zustand bereits seit 0.11.1.
- Detail/Compare behaelt die Scroll-Position (SetData klemmt den Offset).
- Search.lua ist bewusst Modul ohne Tab-Registrierung (Suche lebt im Inventar).
- Schema-Migrationen: naechste STRUKTUR-Aenderung bekommt Migration 002 (VERSION=2).

## [1.0.0] - Release
### Hinzugefuegt
- Minimap-Button mit Kompakt-Tooltip (Top-Chars, Gesamtgold, Mail-Warnung);
  im Designer ausblendbar.
- /exo keys: Schluesselsteine aller Twinks im Gruppen-/Schlachtzugschat ansagen.
- Uebersicht-Modul "Mythic+ Woche" (Wochen-Affixe + alle Keystones).
- Helligkeitsstufe "Hell"; neue API Exo.API.GetKeystones(); README neu.
### Hinweise
- Dungeon-Teleports bewusst auf nach 1.0 verschoben (Secure-Button-Restriktionen).

## [0.17.0] - Beta 22 (Konto-Transparenz)
### Hinzugefuegt
- Reiter "Ruf": Reputations-Matrix ueber alle Twinks, farbcodiert (gruen ab
  Geehrt), mit Fraktions-Suche; automatischer Scan bei Ruf-Aenderungen.
- Questlog aller Alts (automatisch erfasst) als Sektion im Charakter-Detail,
  im Vergleich mit "im Log"/"-".
- Uebersicht-Modul "Gold pro Realm" inkl. Gesamtsumme.
- Bank-Twink-Markierung (Detail-Panel); "[Bank]"-Tag in der Uebersicht.
- APIs: GetReputations, GetQuests, GetGoldByRealm.
### Geaendert
- Obere Tab-Leiste: adaptive Reiter-Breite (7 Reiter bei 720px).

## [0.16.0] - Beta 21 (Wirtschaft & Post)
### Hinzugefuegt
- Reiter "Post": alle Briefkaesten mit farbiger Ablauf-Warnung (<3 Tage rot,
  <7 Tage gelb); Scan beim Oeffnen des Briefkastens.
- Gildenbank-Scan: zaehlt in Tooltips, Suche (Ort-Filter "Gildenbank") und
  Fundorten mit.
- Shift-Klick-Itemlinks in Suche- und Inventar-Liste.
- APIs: GetMails, GetExpiringMails, GetGuilds; guilds-Feld in Item-Zaehlern.

## [0.15.0] - Beta 20 (Berufe + Rezepte)
### Hinzugefuegt
- Reiter "Berufe": Skill-Staende aller Twinks + accountweite Rezept-Suche
  ("Wer kann X craften?").
- Professions-Collector: Kopfdaten automatisch, Rezepte beim Oeffnen des
  Berufsfensters; verlernte Berufe verschwinden verlustfrei.
- APIs: GetProfessions, SearchRecipes.

## [0.14.0] - Beta 19 (Charaktere: Deep-Dive + Vergleich)
### Hinzugefuegt
- Detail-Panel per Klick auf den Spaltenkopf: Allgemein, Equipment je Slot,
  Mythic+, Schatzkammer, Raid-IDs, Waehrungen.
- Compare-Modus: zweiter Char daneben, bessere Zahlenwerte gruen/rot.
- API: GetEquipment.

## [0.13.0] - Beta 18 (Inventar + Suche vereint)
### Hinzugefuegt
- Inventar mit Modi "Bestand" und "Suche" (Suche-Reiter entfaellt).
- AH-Filter: Qualitaet, Typ, Ort, Realm.
- Reagenzienbank im Bank-Scan; freie Taschenplaetze (GetBagSpace) im Footer.

## [0.12.0] - Beta 17 (Sidebar + Designer 2.0)
### Hinzugefuegt
- Sidebar-Navigation (Designer: oben/links), Dichte-Modus Normal/Kompakt.
- Account-Summary im Fensterkopf; Semantic Colors (Theme.SEMANTIC/Color).

## [0.11.2] - Beta 16 (grosse Umbenennung)
### Geaendert
- Global Alto -> Exo; SavedVariables AltoCoreDB -> ExoTwinksDB mit
  automatischer Daten-Uebernahme; Events ALTO_* -> EXO_*;
  Frame ExoTwinksMainWindow; Binding EXO_TOGGLE.
  Slash-Kommandos unveraendert (/exo, /twinks, /alto).

## [0.11.1] - Beta 15 (Uebersicht + Designer-Ausbau)
### Hinzugefuegt
- Reiter "Uebersicht": stapelbare, ein-/ausklappbare Module
  (SavedInstances-Stil), Reihenfolge/Sichtbarkeit im Designer.
- Designer: freie Hex-Akzentfarbe, Reiter ein-/ausblenden.

## [0.11.0] - Beta 14 (Designer)
### Hinzugefuegt
- Reiter "Designer": Akzentfarbe (6 Presets), Deckkraft, Helligkeit,
  Fenster-Presets + "Groesse merken", Matrix-Zeilen-Gruppen,
  Inventar-Standards, "Alles zuruecksetzen" - alles sofort ohne /reload.

## [0.10.4] - Beta 13
### Behoben
- Symbolansicht zeigt alle Items und scrollt korrekt; Fenster vergroesserbar.

## [0.10.3] - Beta 12
### Hinzugefuegt
- BetterBags-artige Gruppierungen (Typ/Unterart/Seltenheit/Erweiterung).

## Aeltere Versionen (0.1.0 - 0.10.2)

### Added (0.10.2 - Inventar: Symbolansicht + Prioritaet aktuelle Erweiterung)
- Umschalt-Button "Symbole"/"Liste" oben rechts im Inventar-Tab: Symbolansicht
  zeigt die Items als Icon-Raster (18 pro Zeile) mit Qualitaetsrahmen in
  Seltenheitsfarbe, Stueckzahl im Icon und Item-Tooltip beim Hovern
  (GameTooltip:SetItemByID); Typ-Kopfzeilen bleiben auch im Raster erhalten.
- Gruppierung priorisiert die aktuelle Erweiterung: Midnight-Items stehen in
  jeder Kategorie VOR Altbestand aus frueheren Erweiterungen (danach greift die
  gewaehlte Spaltensortierung); Basis: expansionID des Items + GetExpansionLevel.
- Neue WowAPI-Wrapper GetItemExpansion/GetCurrentExpansion/GetItemIcon.

### Added (0.10.1 - Inventar: Typ-Gruppierung + Seltenheitsfarben)
- Inventar-Tab: Items sind jetzt nach Itemklasse gruppiert (Waffen, Ruestung,
  Edelsteine, Verbrauchbar, Handwerksmaterial, ... - Blizzard-Reihenfolge,
  Unbekanntes unter "Sonstiges") mit Typ-Kopfzeilen inkl. Item- und Stueckzahl
  ("Ruestung (12 Items, 340 Stueck)").
- Itemnamen im Inventar UND in der Suche in Seltenheitsfarbe (grau/weiss/gruen/
  blau/epic-lila/legendaer-orange/artefakt/erbstueck).
- Header-Sortierung wirkt jetzt innerhalb jeder Gruppe; Fusszeile zaehlt
  Kategorien mit ("34 Items in 6 Kategorien, 1.234 Stueck gesamt").
- Neue WowAPI-Wrapper GetItemQuality/GetItemClass (GetItemInfoInstant, kein
  Server-Roundtrip); Format.ItemName + QUALITY_COLORS.

### Added (0.10.0 - Weeklies + Waehrungs-Caps: der SavedInstances-Ersatz)
- Neue Zeile "Weeklies" im Charaktere-Tab: erledigte Wochenaufgaben pro Char als
  "2/4" (gruen = alle, gelb = teilweise, grau = keine) mit Tooltip je Quest
  ("Weltboss: erledigt / offen"). Die Questliste ist saisonabhaengig und wird in
  ExoTwinksData/Season.lua gepflegt (Zeile erscheint erst bei gepflegter Liste).
- Neue Sektion "Waehrungen": pro Waehrung eine Zeile, Zellen als "320/480" mit
  Cap-Ampel (rot = am Cap, gelb = ab 75 %, weiss darunter; ohne Cap nur die Menge).
  Ohne Pflege zeigt die Automatik alle Cap-Waehrungen, die irgendein Char besitzt
  (Wappen/Crests erscheinen also sofort); Season.lua kann Auswahl + Reihenfolge festlegen.
- Neuer Collector Weeklies (C_QuestLog.IsQuestFlaggedCompleted, Events
  PLAYER_ENTERING_WORLD/QUEST_TURNED_IN); neue APIs GetCurrencies, GetWeeklies,
  GetWeeklyQuestList, GetTrackedCurrencies; Schema-Sektion "weeklies".
- ExoTwinksData laedt jetzt immer (statt LoadOnDemand) und enthaelt Season.lua -
  die einzige Datei, die pro Saison gepflegt wird.

### Fixed (0.9.6 - Beta-Feedback aus dem In-game-Screenshot)
- Levelcap-Charaktere: "Level 90" statt "90.0" und Erholt "-" statt rotem "0%"
  (Cap kommt live von GetMaxLevelForPlayerExpansion, unter dem Cap unveraendert).
- Spalten-Zebra endet jetzt an der letzten belegten Spalte - keine grauen
  Streifen mehr im leeren Bereich rechts.

### Added (0.9.5 - Schatzkammer-Erinnerung + Vault-Tooltip)
- Addon-Liste: die drei Module erscheinen jetzt als EINE aufklappbare Gruppe
  "exo-Twinks" (TOC-Direktive "## Group", seit Patch 11.1.0) mit einheitlichem
  Icon und Kategorie "Sonstiges".
- Neue Zeile "Schatzkammer" im Charaktere-Tab: gruenes "Abholen!", wenn Belohnungen
  der Vorwoche in der Grossen Schatzkammer bereitliegen (wie AlterEgo); sonst grauer
  Wochen-Run-Zaehler.
- Schatzkammer-Tooltip beim Hovern der Vault-Zellen: Abhol-Hinweis, M+-Runs der
  Woche, Freischalt-Status je Slot ("Slot 3 (8 Runs): noch 2 Run(s)") und die
  besten Runs der Woche (gruen = in der Zeit).
- Collector erweitert: C_WeeklyRewards.HasAvailableRewards + C_MythicPlus.GetRunHistory
  (Wochen-Historie, Top-8-Runs); neue API-Felder vaultRewards/runsThisWeek/topRuns.

### Changed (0.9.0 - Umbenennung + AlterEgo-Umbau)
- **Addon heisst jetzt "exo-Twinks"** (Ordner ExoTwinksCore/ExoTwinksUI/ExoTwinksData).
  Slash-Kommandos: /exo und /twinks, /alto und /altong bleiben als Aliase.
  WICHTIG fuer Bestandsdaten: in WTF\Account\<ACC>\SavedVariables die Datei
  AltoCore.lua in ExoTwinksCore.lua umbenennen (Variable bleibt AltoCoreDB).
- **Neuer Haupt-Tab "Charaktere" im AlterEgo-Stil** ersetzt Uebersicht, Mythic+ und
  Schlachtzuege: EINE transponierte Matrix (Beschriftungen links in Gold, Charaktere
  als Spalten in Klassenfarbe, vertikales Spalten-Zebra) mit den Zeilen Realm, Level,
  Gold, Gespielt, Erholt, Zuletzt online, Itemlevel, M+-Wertung, Schluesselstein,
  Schatzkammer (3 Kategorien), Raid-IDs, Season-Best pro Dungeon sowie pro Raid einer
  Sektion mit Reset-Timer und einer Boss-Quadrat-Zeile je Schwierigkeit
  (Quadrat = Boss, gefuellt = tot, Farbe = Schwierigkeit).
- Spalten sortiert nach Itemlevel (absteigend); Fusszeile mit Gesamtgold des Accounts.
- 3-in-1-Plan dokumentiert in docs/PLAN-3IN1.md (Mockup: docs/mockup-alterego.html).

### Added (0.8.0 - Mythic+-Tab im AlterEgo-Stil)
- Neuer Tab "Mythic+": Matrix wie im Addon AlterEgo (Cleanroom-Nachbau ueber offizielle
  Blizzard-APIs, kein fremder Code) - Charaktere als Spalten (Klassenfarbe), Zeilen:
  Itemlevel, M+-Wertung (Farbstufen wie im Spiel: weiss/gruen/blau/lila/orange/ab 3000
  Artefakt-Beige), aktueller Schluesselstein als Kuerzel ("BRH +16"), grosse Schatzkammer
  (Schlachtzuege / Mythisch+ / Welt als "2/3" mit Ampelfarbe) sowie die Season-Bestleistung
  pro Dungeon ("+18 168", gruen = in der Zeit, grau = ueberzogen).
- Neuer Collector MythicPlus: sammelt Wertung, eigenen Keystone (Taschenscan),
  Dungeon-Bestwerte und Schatzkammer-Fortschritt bei Login, M+-Abschluss,
  Schatzkammer-Update und Taschenaenderung (entprellt, 1 s).
- Neue Kern-API GetMythicPlus(charKey) inkl. Format.Rating (Farbstufen) und Format.Abbrev
  (Dungeon-Kuerzel); 14 neue Tests (209 gesamt).

### Added (0.7.0 - Schlachtzuege als SavedInstances-Matrix)
- Schlachtzuege-Tab komplett umgebaut nach User-Vorbild SavedInstances: Matrix mit Charakteren als Spalten (Klassenfarbe) und Schlachtzuegen als Zeilen; Zellen zeigen den Fortschritt kompakt als "9/9M" (N gruen / H blau / M lila / LFR grau, "*" = verlaengerte ID), mehrere Schwierigkeiten desselben Raids stehen nebeneinander.
- Reset-Spalte mit fruehestem Reset pro Raid; Zeilen nach naechstem Reset sortiert.
- Bei mehr als 6 Charakteren mit Locks blaettert ein Button seitenweise durch die Spalten ("Chars 1/2 >").
- Fusszeile mit Zaehlern und Farb-Legende.

### Fixed (0.6.1 - Beta-Feedback Suche-Layout)
- Suche: Anzahl-Spalte ueberlappte lange deutsche Itemnamen (Screenshot "Mysterioese Himmelssplitter (255826)43") -> Namensspalte auf 296px verbreitert, Anzahl/Fundorte nach rechts verschoben, Spaltenueberschriften ergaenzt, Zebra-Streifen wie in den anderen Tabs.
- Alle Listen-Tabs: Zellen werden jetzt auf ihre Spaltenbreite gekappt (SetWidth + SetWordWrap(false)) statt in die Nachbarspalte zu laufen.

### Added (0.6.0 - Item-Uebersicht + Suche-Ausbau)
- Neuer Tab "Inventar": komplette Item-Uebersicht pro Charakter (Taschen + Bank, Stacks aggregiert) und fuer die Kriegsmeutenbank; Charakter-Wechsel per Zyklus-Button (klassengefaerbte Labels), Spalten Item/Anzahl/Taschen/Bank per Header-Klick sortierbar; Fusszeile "N Items, M Stueck gesamt"; Hinweis bei Chars ohne Daten.
- Neue Kern-APIs (getestet): GetCharacterItems(charKey) und GetWarbandItems().
- Suche: Charakternamen in den Fundorten jetzt in Klassenfarbe; Statuszeile zeigt zusaetzlich die Gesamtstueckzahl der Treffer.

### Added (0.5.1 - Vollstaendiger Legacy-Import)
- /alto import uebernimmt jetzt auch Taschen, Reagenzientasche und Bank aller alten Charaktere (DataStore_Containers, bit-dekodiert), die Kriegsmeutenbank (DataStore_Containers_Warbank) sowie das Itemlevel (DataStore_Inventory) - Tooltip und Suche kennen damit sofort den kompletten Altbestand (Beta-Feedback: Exo zeigte 16, Altoholic 25).
- Bereits vorhandene Charaktere werden um FEHLENDE Sektionen ergaenzt (z.B. Bank vor dem ersten Bankbesuch, iLvl), eigene Scans werden nie ueberschrieben; Chat-Meldung weist ergaenzte Chars aus.

### Added (0.5.0 - Uebersicht im Altoholic-Umfang, Optik im ElvUI-Stil)
- Uebersicht-Tab komplett ueberarbeitet: Charaktere nach Realm gruppiert mit Realm-Headern und Summenzeilen pro Realm (Level-Summe, Geld, Spielzeit, iLvl-Schnitt) - Layout wie die Altoholic-Kontouebersicht.
- Neue Spalten: Stufe mit XP-Fortschritt als Nachkommastelle (80.3), Erholt-% mit Ampelfarbe (gruen/gelb/rot), Geld als volle g/s/c-Anzeige mit Muenzfarben, Zuletzt online ("4 Tagen", aktueller Char gruen "Online").
- Charakternamen in Klassenfarbe (alle 13 Klassen).
- Fusszeile im Altoholic-Layout: links "Charaktere: N, Realms: M", rechts "Summen: X Lv / Geld / Spielzeit".
- ElvUI-Optik: flaches dunkles Fenster mit 1px-Kante statt Blizzard-Dialograhmen, flache Buttons mit Hover-Akzent in ElvUI-Blau, aktiver Tab hervorgehoben, Zebra-Streifen in der Liste, Realm-Header mit Akzentfarbe.
- Neue Format-Helfer (alle getestet): Money, LevelProgress, RestPercent/RestText, TimeAgo, ClassName, GroupDigits.

### Fixed
- In-Game-Feedback (Screenshot Beta 1): Fenster-Hintergrund war zu transparent (Spielwelt schien durch) -> deckend dunkler Backdrop (WHITE8x8 + SetBackdropColor). Fusszeile zeigte "1 Charaktere" -> Format.Count mit korrektem Singular/Plural (auch fuer Such-Treffer).
- In-Game-Bugreport Beta 1: "/alto" oeffnete das ALTE Altoholic-Fenster, wenn beide Addons installiert sind (nichtdeterministischer Slash-Hash-Konflikt). Neuer Services/Compat benennt die /alto-Tokens des alten Altoholic beim Login um -- /alto gehoert jetzt deterministisch AltoNG, das alte Fenster bleibt ueber /altoholic erreichbar (einmaliger Chat-Hinweis).

### Added
- Phase 4: Tooltip & Suche (Meilenstein M4 = Beta 1)
  - API/ItemCounts: accountweiter Item-Index (itemID -> Taschen/Bank pro Char + Kriegsmeute); lazy Aufbau, Invalidierung nur bei bags/bank/warbandBank-Aenderungen -> Tooltip-Zugriffe treffen den warmen Cache
  - Services/Tooltip (AltoCore): "Besessen von ..."-Zeilen an Item-Tooltips via TooltipDataProcessor; Chars nach Anzahl sortiert, Quellen aufgeschluesselt (Taschen/Bank), Kriegsmeuten-Zeile; keine Zeilen bei 0 Besitz
  - Tabs/Search: accountweite Live-Suche (Namens-Teilstring case-insensitive oder exakte Item-ID), Tipp-Entprellung 0.3s, Treffer nach Gesamtanzahl sortiert, Fundort-Aufschluesselung pro Zeile, virtualisierte Ergebnisliste
  - API.SearchItems(matcher) + WowAPI.GetItemName/AddItemTooltipPostCall
  - spec/: 25 neue Tests (Aggregation, Cache-Invalidierung/-Warmhaltung, Kopier-Schutz, Tooltip-Zeilen, Such-Matching, Debounce)
- Phase 3: UI-Grundgeruest + Uebersicht (Meilenstein M3, erste Alpha)
  - Framework/Format: zentrale Formatierung (Duration, Gold mit Tausenderpunkten); RaidLocks delegiert
  - Framework/Widgets: Label-/Button-Factories
  - Framework/VirtualScroll: virtualisierte Liste (nur N sichtbare Widget-Zeilen, Mausrad, Offset-Klemmung)
  - Tabs/Summary: Uebersicht aller Charaktere - sortierbare Spalten (Name, Realm, Level, ilvl, Gold, Spielzeit, Zone), Realm-/Fraktions-Filter (Zyklus-Buttons), Summen-Fusszeile; Standard-Tab
  - API: GetCharacterSummary (anzeigefertige Char-Daten), GetRealms
  - Services/Minimap (AltoCore): Minimap-Button, laedt AltoUI on demand
  - Bindings.xml + Keybinding "Exo-Fenster ein-/ausblenden"
  - spec/: 22 neue Tests (VirtualScroll-Virtualisierung/Klemmung/Mausrad, GatherRows-Filter/-Sortierung, Totals, Header-Klick, Filter-Zyklus, Minimap-Toggle)
- Phase 2: Collectors P0 (Meilenstein M2)
  - Collectors/Characters: Level/Klasse/Zone/XP/Ruhebonus/Gold/Spielzeit; PLAYER_MONEY nur Gold (billig), Vollscan bei Level-Up/Zonenwechsel (entprellt), RequestTimePlayed einmal pro Sitzung, lastSeen-Stempel bei PLAYER_LOGOUT
  - Collectors/Containers: Taschen (BAG_UPDATE-Stuerme entprellt), Bank + Kriegsmeutenbank nur bei offener Bank (BANKFRAME_OPENED/CLOSED-Sitzungslogik); freie Slots pro Tasche
  - Collectors/Currencies: Waehrungsliste mit Header-Filter, CURRENCY_DISPLAY_UPDATE entprellt
  - Collectors/Equipment: Item-ID + ilvl pro Slot, Durchschnitts-Itemlevel (gesamt/angelegt)
  - Store:WriteAccountData fuer accountweite Daten (Kriegsmeutenbank) + Event ALTO_ACCOUNT_UPDATED
  - Schema: neue Sektion bank, meta um xp/xpMax/restXP erweitert
  - WowAPI: Bag-ID-Bereiche zentral definiert (BAG_IDS/BANK_IDS/WARBAND_IDS), Wrapper fuer C_Container/C_CurrencyInfo/C_Item
  - spec/: 22 neue Tests (alle vier Collectors inkl. Entprellung, Bank-Sitzungslogik, Header-Filter, Slot-Wechsel)
- Zwischenschritt "Schlachtzuege-Tab" (vertikaler Durchstich durch alle Schichten):
  - Collectors/InstanceLocks: erfasst gespeicherte Instanz-IDs eventgetrieben (PLAYER_ENTERING_WORLD/BOSS_KILL -> RequestRaidInfo gedrosselt, UPDATE_INSTANCE_INFO -> Scan entprellt); resetAt als absoluter Unix-Timestamp
  - API/Public: erste stabile Query-Schicht (GetCharacterKeys/GetCharacterInfo/GetInstanceLocks/GetRaidLocks mit Ablauf-Filter, RegisterCallback); Rueckgaben sind Kopien
  - AltoUI: Hauptfenster mit Tab-System (Framework/Window) + Reiter "Schlachtzuege" (Tabs/RaidLocks): alle Raid-IDs aller Charaktere, sortiert nach naechstem Reset, mit Boss-Progress, Schwierigkeit und Verlaengert-Markierung; Live-Refresh bei ALTO_CHAR_UPDATED
  - Schema: neue Sektion instanceLocks
  - spec/: 17 neue Tests (Collector-Drossel/-Entprellung, API-Filter/-Kopien, GatherRows/Render, Fenster-Integration)
- Phase 1: Storage & Datenmodell
  - Storage/Schema: deklariertes SV-Schema v1 (chars/guilds/account), non-destruktives ApplyDefaults, CharKey-Helfer
  - Storage/Migrations: nummerierter, idempotenter Migrations-Runner mit Downgrade-Schutz und Lueckenerkennung
  - Storage/Store: einziger SavedVariables-Zugriffspunkt (GetOrCreate/Delete/Iterate, WriteCharacterData mit Schema-Validierung, Events ALTO_STORE_READY/CHAR_ADDED/CHAR_UPDATED/CHAR_DELETED)
  - Storage/LegacyImport: non-destruktiver Import aus altem Altoholic/DataStore (inkl. BaseInfo-Bitfeld-Dekodierung: Level/classID/raceID), Scan/Import/Login-Hinweis
  - Slash: `/alto import` (anzeigen | confirm | dismiss)
  - spec/: 36 neue Tests (Schema, Migrations, Store, LegacyImport) inkl. realistischer Legacy-Fixture
- Phase 0: Monorepo-Skelett mit 3 TOC-Zielen (AltoCore, AltoUI LoadOnDemand, AltoData)
- Core/EventBus: Pub/Sub fuer interne + WoW-Events, fehlertoleranter Dispatch
- Core/Scheduler: After/Debounce/Throttle + budgetierte Task-Queue (getaktet via OnUpdate)
- Core/Log: Level-Logging mit Ringpuffer, `/alto debug dump`
- Core/WowAPI: zentraler, mockbarer Wrapper um alle WoW-API-Aufrufe
- Slash-Kommandos `/alto`, `/altong` (version, debug, help, UI-Toggle on demand)
- spec/: busted-Testsuite mit WoW-API-Mock (EventBus, Scheduler, Log, Init)
- CI: luacheck + busted via GitHub Actions, Release-Packaging via BigWigs-Packager
