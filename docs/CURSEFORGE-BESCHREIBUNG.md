# CurseForge-Projekttexte für exo-Twinks

> Copy-&-Paste-Vorlagen für die Projektseite. Die EN-Summary und -Beschreibung
> sind bewusst mit den Suchbegriffen formuliert, nach denen die internationale
> Community sucht: *alt manager, altoholic alternative, account-wide, warband*.

---

## Projektname
```
exo-Twinks
```

## Summary (Pflichtfeld, 1 Satz, EN)
```
exo-Twinks — Alt & Warband Manager: Altoholic-style account-wide overview of all
your characters (alts), bags, banks, warband bank, gold, professions, Great
Vault & raid lockouts. With item search and "on other characters" tooltips.
```

## Kategorien (beim Anlegen ankreuzen)
- Bags & Inventory
- Professions
- Roleplay/Leveling (optional)
- **Hauptkategorie:** Inventory

---

## Beschreibung (EN, Hauptteil der Projektseite)

```markdown
# exo-Twinks — Alt & Warband Manager

**The account-wide overview for players with an alt problem.** exo-Twinks is an
Altoholic-style alt manager combined with an AlterEgo-style character matrix
and SavedInstances-style weekly tracking — in one lightweight addon.

> Note: The addon UI is currently **German-only**. English localization is on
> the roadmap. All data features work regardless of client language.

## Why another alt addon?

If you search for an **Altoholic alternative**, an **alt manager**, or a
**warband bank search**, this is what exo-Twinks does:

### 🔍 Find your stuff — account-wide
* **Item search across all characters**: bags, banks, warband bank, guild
  banks, mail and auctions of every alt
* **Tooltip counts**: hover any item and see "you have X on other characters"
  (the feature people install BagSync/Syndicator for)
* List ⇄ **icon view** everywhere, grouping by type / subtype / rarity / expansion

### 📊 All characters at a glance (AlterEgo-style matrix)
* Gold, item level, bag space, rested XP, played time, last online
* **Mythic+ rating, keystone, season-best per dungeon**
* **Great Vault** progress (raid / M+ / world) + "collect your rewards!" reminder
* Raid lockouts with per-boss kill squares, weeklies, currencies
* **Mail indicator** with expiry warning — never lose mail items again
* Your logged-in character is highlighted; hide any character you don't care about

### 🏦 Warband ready (The War Within / Midnight)
* Separate tabs for **warband bank**, per-character banks and
  **warbound items** (including "bind until equipped" detection)
* Built for the modern container API (11.x/12.x)

### 🛠 Quality of life
* Minimap button with at-a-glance tooltip (top chars, gold, vault status)
* Fully skinnable flat UI (ElvUI-style), window scale 70–130 %,
  remembers size & position
* Designer tab: toggle every row/tab/module — **one** settings page, no maze
* Imports your existing **Altoholic/DataStore** data on first login

### ⚙️ Reliability
* **457 automated tests** run against every release — built to survive patch days
* Lightweight: event-driven collectors, no combat log usage (12.0-safe)

## Getting started
Install, log in — done. Open with `/exo`, `/twinks`, the minimap button or a
keybinding. Your characters appear as you log them in once.

## Feedback
Bug reports and feature requests are welcome in the comments.
```

---

## Beschreibung (DE, optional als zweiter Abschnitt anhängen)

```markdown
---

# 🇩🇪 Deutsche Beschreibung

**Die Account-Übersicht für alle mit einem Twink-Problem.** exo-Twinks vereint
Altoholic (Item-Suche über alle Chars), AlterEgo (Charakter-Matrix mit M+/Vault)
und SavedInstances (IDs & Weeklies) in einem leichtgewichtigen Addon — komplett
auf Deutsch.

* 🔍 **Item-Suche über alle Twinks**: Taschen, Banken, Kriegsmeuten-Bank,
  Gildenbanken, Post und Auktionen; Tooltip zeigt „X davon auf anderen Chars"
* 📊 **Charaktere-Matrix**: Gold, Itemlevel, M+-Wertung, Schlüsselstein,
  Schatzkammer, Raid-IDs, Weeklies, Währungen, Post-Ablauf-Warnung
* 🏦 **Kriegsmeute**: eigene Reiter für KM-Bank, Char-Banken und
  kriegsmeutengebundene Items
* 🛠 **Designer**: alles an einer Stelle anpassbar (Farben, Zeilen, Reiter,
  Skalierung 70–130 %, Chars ausblenden)
* 📥 Übernimmt vorhandene **Altoholic/DataStore-Daten** automatisch
* ✅ 457 automatische Tests pro Release — gebaut, um Patch-Days zu überleben

Öffnen mit `/exo`, `/twinks`, Minimap-Button oder Tastenkürzel.
```

---

## Changelog-Vorlage für Datei-Uploads (EN + DE)

```markdown
## vX.Y.Z
**EN:** <1-3 bullets, what changed>
**DE:** <1-3 Punkte, was sich geändert hat>
```

## Upload-Einstellungen (Erinnerung)
- Datei: `exo-Twinks-X.Y.Z-curse.zip` (nur die 3 Ordner im Root!)
- Display Name: `exo-Twinks X.Y.Z`
- Game Version: aktuell **12.1.0** (Interface 120100) — bei jedem Patch prüfen
- Release Type: anfangs **Beta**
- Projekt-Icon: `docs/curseforge-icon.png` (400×400)
```

---

## Entschieden (06.10.2026)

- **Lizenz: All Rights Reserved** (wie Altoholic und AlterEgo).
- **Upload-Automatik: JA** -- der Agent laedt kuenftig bei jedem Release das
  Curse-ZIP automatisch hoch, sobald Projekt-ID + API-Token vorliegen.

## Noch offen (User-Schritte)

1. Projekt auf https://console.curseforge.com anlegen (Name, Summary,
   Kategorien, Icon, Beschreibung -- alles aus dieser Datei).
2. Nach Freigabe: **Projekt-ID** durchgeben (Projektseite, "About Project").
3. **API-Token** erzeugen (https://authors.curseforge.com/account/api-tokens)
   und in die Regelwerk-Datei in den Uploads legen (NICHT in den Chat).

Danach (Agent): Upload von v1.14.0+ via
`POST https://wow.curseforge.com/api/projects/<ID>/upload-file`
(Header `X-Api-Token`; Metadaten: gameVersions=12.1.0, releaseType=release,
changelog aus CHANGELOG.md; Datei = exo-Twinks-<version>-curse.zip).

---

## Transparenz-Block (ans ENDE der Projektbeschreibung anhaengen, EN)

```markdown
## Transparency

exo-Twinks is developed **AI-assisted** (code written with AI tooling, reviewed
and quality-gated by 481 automated tests + static analysis on every release).
The **project icon is AI-generated**. All screenshots show the real in-game UI
with no AI modification.
```

> Hintergrund: CurseForge verlangt einen sichtbaren Hinweis nur fuer
> AI-Showcase-Bilder, die den Inhalt falsch darstellen koennten (Moderation
> Policies, "AI Misleading Content Disclosure"). r/wowaddons verlangt bei
> Release-Posts einen AI-Disclaimer (Regel 1). Der Block oben deckt beides ab.
> WICHTIG: Screenshots immer echt aus dem Spiel -- NIE AI-generiert.

---

## Screenshot-Plan (User macht die Aufnahmen im Spiel)

> **Privatsphaere geloest (1.15.0):** Vor den Aufnahmen `/exo demo an`
> eingeben -- das Addon zeigt dann 8 erfundene Beispiel-Chars statt der
> echten. Danach `/exo demo aus`. Screenshots bleiben damit 100% echte
> In-Game-Aufnahmen ohne persoenliche Daten.

Aufnahme: Druck-Taste (Screenshot landet in
`World of Warcraft/_retail_/Screenshots/`); vorher mit `/exo` das Fenster
oeffnen. Am besten 16:9, UI-Skalierung Standard, aussagekraeftige Daten
(mehrere Chars eingeloggt gewesen).

| # | Motiv | Was sichtbar sein soll |
|---|-------|------------------------|
| 1 | Charaktere-Tab (Matrix) | Mehrere Chars: Gold, iLvl, M+-Rating, Great Vault, Post-Indikator |
| 2 | Item-Suche | Suchbegriff + Treffer ueber mehrere Chars/Orte (Taschen, Bank, KM-Bank) |
| 3 | Item-Tooltip | Hover ueber ein Item mit "exo-Twinks: N insgesamt" + Char-Zeilen (DAS Killer-Feature) |
| 4 | Inventar-Tab | Symbolansicht mit Gruppierung (z. B. nach Typ) |
| 5 | KM-Bank-Tab | Inhalt + Button "In KM-Bank einlagern" |
| 6 | Uebersicht/Vault | Wochen-Fortschritt, Lockouts (SavedInstances-Ersatz zeigen) |

Reihenfolge beim Hochladen = Reihenfolge in der Galerie; Screenshot 3
(Tooltip) oder 1 (Matrix) als erstes Bild waehlen, das ist das Aushaengeschild.
Keine Bearbeitung noetig; zuschneiden auf das Fenster ist ok (kein AI-Upscaling).
