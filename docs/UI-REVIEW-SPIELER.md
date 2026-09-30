# UI-Review aus Spielersicht (Stand v1.4.2)

> Methode: Ich spiele typische Twink-Szenarien im Kopf durch und bewerte,
> was das UI mir dabei gibt -- ehrlich, inkl. der Stellen, wo es hakt.
> Fakten gegen den Code geprueft (Tooltips, Icons, Persistenz, Seitengroessen).

## Die 30-Sekunden-Wahrheit

Das Addon ist funktional auf Augenhoehe mit Altoholic+AlterEgo+SavedInstances --
aber es ist ein **Text-Interface**. Es liest sich wie ein sehr gutes Cockpit
fuer Leute, die Tabellen moegen. Ein Durchschnittsspieler, der Icons, Hover-
Feedback und "Klick mich!"-Signale gewohnt ist, muss sich erst einarbeiten.
Die Staerke (Dichte, Konfigurierbarkeit) ist gleichzeitig die Schwaeche
(Einstiegshuerde, versteckte Interaktionen).

## Szenario-Test

### "Ich logge ein: Was ist heute zu tun?" - Note 2
Uebersicht-Tab liefert das sofort: Vault offen, Keys, ablaufende Mails,
Scan-Luecken. ABER: 10 Module, alle aufgeklappt -> beim ersten Oeffnen eine
Textwand, das Wichtige steht evtl. unterhalb des Scrollbereichs. Dass ich
Module ein-/ausklappen und sortieren kann, rettet es -- wenn ich es weiss.

### "Welchem Twink gebe ich dieses Item?" - Note 2+
Detail-Panel + Vergleich (gruen/rot) ist exzellent und schlaegt Altoholic.
ABER: Der Einstieg ist unsichtbar -- dass die CHARNAMEN IN DER MATRIX
KLICKBAR sind, sieht man ihnen nicht an (kein Hover, kein Pfeil, kein
Unterstrich). Das beste Feature des Addons haengt an einem Geheimklick.

### "Wo ist mein Zeug?" - Note 2
Suche mit AH-Filtern, Fundort-Aufschluesselung, Ort-Filter bis Gildenbank/AH:
stark. ABER: Ergebnisliste ist reiner Text -- ohne Item-Icons scanne ich
langsamer als im AH. Und die Suche versteckt sich als zweiter Modus im
Inventar-Tab; "Suche" als Wort ist auf einem 64px-Button leicht uebersehbar.

### "Kann ich das craften?" - Note 2
Gruen/gelb-Status direkt in der Trefferzeile ist genau richtig. Der
Material-Report auf Klick landet aber im CHAT statt im Fenster -- fuehlt
sich nach Konsole an, nicht nach UI.

### "Gildensteuer einrichten" (frisch in 1.4.2) - Note 3+
Jetzt machbar (Klick-Saetze im Designer, Betrag im Fensterkopf). ABER die
Kette Designer > Aktiv > Steuersaetze > Uebersicht-Modul verteilt EIN
Feature auf drei Orte. Ein eigener kleiner Steuer-Block mit allem an einem
Fleck waere spielerfreundlicher.

### "Ich habe 14 Twinks" - Note 3
Matrix zeigt 6 Chars pro Seite, Blaettern unten rechts. Kein Realm-Filter,
keine Rollen-Filter (kommt erst 1.5.0), kein "Favoriten zuerst". Die
Uebersicht-Module listen alle Chars -> lange Listen.

## Was aus Spielersicht richtig gut ist

1. EIN Fenster, 7 klare Reiter, ESC schliesst, Minimap-Button mit
   nuetzlichem Tooltip, /exo-Kurzbefehle: die Huelle stimmt.
2. Live-Designer ohne /reload ist besser als bei fast jedem Addon
   dieser Groesse (Akzentfarbe, Dichte, Sidebar, Reiter ausblenden).
3. Konsistente Bedeutungsfarben (gruen/gelb/rot/grau) ueberall.
4. Ablauf-Warnungen (Mails, Auktionen) rechnen offline weiter - selten.
5. "Scan-Status" sagt aktiv, WAS zu tun ist - vorbildliches Onboarding.
6. Klassenfarben + Zebra + Akzent-Kopfzeilen: einheitliche Optik.

## Die Top-Probleme, priorisiert (Spieler-Wirkung x Fixaufwand)

| # | Problem | Wirkung | Fix-Idee | Aufwand |
|---|---|---|---|---|
| 1 | Klickbare Dinge sehen nicht klickbar aus (Matrix-Koepfe, Modul-Kopfzeilen, Scan-/Steuer-Zeilen) | hoch | Hover-Aufhellung auf allen interaktiven Zeilen + Cursor-Hinweis im Tooltip ("Klick: Details") | gering |
| 2 | Keine Item-Icons in Suche/Post/Berufe-Treffern | hoch | 16px-Icon vor dem Namen (W.GetItemIcon existiert schon!) | gering-mittel |
| 3 | Uebersicht-Erststart = Textwand | mittel | Beim ALLERERSTEN Start nur chars/keys/scan aufgeklappt (einmalige Option overview.firstrun) | gering |
| 4 | Material-Report/Scan-Hinweise landen im Chat | mittel | Kleines Info-Panel im Fenster (wiederverwendbar), Chat nur als Option | mittel |
| 5 | Suche als Mini-Button versteckt | mittel | Suchfeld-Icon/Feld direkt in der Kopfzeile des Fensters (globale Suche) | mittel |
| 6 | Kein Tooltip auf Matrix-Zellen (ausser Vault/Weeklies) | mittel | Zellen-Tooltip mit Langform (z. B. exakte Zeit statt "vor 3 T") | mittel |
| 7 | Aktiver Tab/Scrollpositionen nicht gemerkt | gering | Option "window.lastTab" analog Groesse-merken | gering |
| 8 | Designer = 15 Zeilen gemischter Themen | mittel | Zwei Spalten oder Mini-Sektionen mit Trennlinien; Steuer-Zeilen visuell buendeln | mittel |
| 9 | 6 Chars/Seite ohne Filter | mittel (bei vielen Twinks) | kommt mit 1.5.0-Rollenfiltern; zusaetzlich Realm-Zyklus-Button | eingeplant |
| 10 | Farb-Overload in Uebersicht-Zeilen (5+ Farben pro Zeile) | gering | Sekundaeres konsequent grau, nur EINE Signalfarbe pro Zeile | gering |

## Empfehlung (Punkte 1, 2, 3, 7, 10 -> umgesetzt in v1.4.3)

Ein "UI-Poliersprint" v1.4.3 mit den Punkten 1, 2, 3, 7 und 10 (alles
gering) wuerde die gefuehlte Qualitaet staerker heben als jedes neue
Feature. Punkte 4-6 und 8 als v1.5.x-Begleiter zum Rollen-Release.

## Bewusst NICHT kritisiert

- Blizzard-Dropdowns/Standard-Widgets fehlen: Absicht (AlterEgo-Flat-Look).
- Keine Maus-Drag-Sortierung der Module: Shift/Alt-Klick ist ein fairer,
  testbarer Kompromiss.
- Text statt Grafik bei Raid-Fortschritt: die Boss-Quadrate sind gut.
