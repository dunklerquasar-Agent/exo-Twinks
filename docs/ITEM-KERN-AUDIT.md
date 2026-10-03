# Item-Kern-Audit: Wo werden Items erfasst, gezählt, gefunden?

> Leitsatz des Users (Okt 2026): **exo-Twinks ist im Kern ein Item-Manage-Addon
> über alle Twinks hinweg.** Dieses Dokument ist die Abdeckungsmatrix des
> Item-Kerns und wird bei jeder Änderung an Collectors/ItemCounts gepflegt.

## Abdeckungsmatrix (Stand 1.12.0)

| Quelle | Gesammelt (Collector) | Im Item-Index (Tooltip/Suche) | Eigene Ansicht |
|---|---|---|---|
| Taschen (Bag 0-5, inkl. Reagenzientasche) | ✅ Containers | ✅ `bags` | Inventar-Tab |
| Charakterbank (Bag 6-11, Reiter 1-6) | ✅ Containers (bei Bankbesuch) | ✅ `bank` + `bankTabs` (Reiter!) | Bank-Tab |
| Kriegsmeuten-Bank (Bag 12-16, Reiter 1-5) | ✅ Containers (bei Bankbesuch) | ✅ `warband` + `warbandTabs` (Reiter!) | KM-Bank-Tab |
| Kriegsmeutengebundene Items | ✅ (wb-Flag + Bind-Typ 7/8) | ✅ (Teil von bags/bank) | KM-Items-Tab |
| Gildenbank(en) | ✅ GuildBank (bei Besuch) | ✅ `guilds[name]` | Suche/Tooltip |
| Auktionen (aktiv, unverkauft) | ✅ Auctions | ✅ `auctions` | Suche/Tooltip |
| **Post-Anhänge** | ✅ Mail (bei Briefkastenbesuch) | ✅ **`mail` (NEU 1.12.0)** | Mail-Tab |
| **Angelegte Ausrüstung** | ✅ Equipment | ✅ **`equipped` (NEU 1.12.0)** | Charaktere-Detail |
| Leerraum/Void Storage | — (von Blizzard entfernt) | — | — |

**Vor 1.12.0 waren Post-Anhänge und angelegte Items für Tooltip & Suche
unsichtbar** — genau die zwei Orte, an denen man Items „verliert"
(tagelang in der Post / am vergessenen Twink angelegt). Lücke geschlossen.

## Der Item-Datenfluss

```
Collectors (Events)          Index (lazy Cache)            Verbraucher
Containers/Mail/Equipment →  ItemCounts.buildCache()   →   Tooltip ("Besessen von ...")
Auctions/GuildBank        →  invalidate() bei:         →   Suche-Tab (Filter: Ort/Qualität/
Warband                      bags|bank|auctions|mails|      Typ/Rolle/Realm)
                             equipment|warbandBank|Gilde →  Inventar/Bank/KM-Tabs (eigene
                                                            Aggregation GetCharacterItems)
```

## Garantien des Item-Kerns (durch Tests abgesichert)

1. **Jede indexierte Quelle erscheint im Tooltip** mit Einzelmenge
   (`Taschen/Bank (Reiter N)/AH/Post/Angelegt`, Kriegsmeute mit Reitern, Gildenbank).
2. **Jede indexierte Quelle ist in der Suche filterbar** (Ort-Filter).
3. **Versteckte Chars** (1.11.0) werden aus ALLEN Quellen herausgerechnet.
4. **Cache-Invalidierung** bei jeder Schreiboperation einer indexierten Quelle.
5. Legacy-Daten (alte Container-IDs) bleiben zählbar, nur ohne Reiter-Detail.

## Bekannte Grenzen / Kandidaten für später

- Post-/Bank-/Gildenbank-Scans brauchen je einen Besuch mit dem Char
  (WoW-API-Grenze, gilt für alle Addons dieser Art).
- Handwerks-Check „Kann ich X craften?" (Materialbedarf vs. Bestand) — offen,
  wäre der nächste Kern-Ausbau (nutzt GetItemCounts direkt).
- AH-artige Suchfilter (Mindest-iLvl etc.) — Ausbau des Suche-Tabs, offen.
