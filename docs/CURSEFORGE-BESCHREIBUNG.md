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
