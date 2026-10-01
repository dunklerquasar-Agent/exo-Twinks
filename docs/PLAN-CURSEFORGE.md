# Plan: exo-Twinks auf CurseForge veröffentlichen

Stand: 2026-10-01 · Addon-Version: 1.9.2 · Ziel: WoW Retail (Midnight, 12.x)

---

## Phase 0 — Vorentscheidungen (einmalig, 10 Min)

| Entscheidung | Empfehlung | Warum |
|---|---|---|
| **Account** | Dein persönlicher CurseForge-Account (nicht der GitHub-Bot) | CurseForge verlangt einen echten Autor; die Bot-Regel gilt nur für GitHub |
| **Projektname** | `exo-Twinks` | Muss auf CurseForge einmalig sein — vorher in der Suche prüfen |
| **Lizenz** | "All Rights Reserved" ODER MIT/GPLv3 | ARR = niemand darf forken; MIT/GPL = Community-freundlich. Für ein Hobby-Addon ist GPLv3 bei WoW-Addons üblich |
| **Quellcode-Link** | Weglassen | Das GitHub-Repo ist privat — CurseForge braucht keinen Link |
| **Monetarisierung (Author Rewards Points)** | Erstmal aus | Kann später jederzeit aktiviert werden |

---

## Phase 1 — Addon CurseForge-tauglich machen (Code, mache ich)

### 1.1 TOC-Metadaten ergänzen (alle 3 TOCs)
```
## Interface: <aktuelle Buildnummer>   <- in-game: /dump select(4, GetBuildInfo())
## Author: <dein Nick>
## X-Curse-Project-ID: <ID nach Projekterstellung>
## X-Website: https://www.curseforge.com/wow/addons/exo-twinks
```
- `## Interface` MUSS zur aktuellen Spielversion passen, sonst zeigt
  CurseForge/der Client das Addon als "veraltet" an.
- `## Group`, `## Category`, `## IconTexture` haben wir schon. ✔

### 1.2 Curse-Release-ZIP bauen (anders als unser bisheriges ZIP!)
- **Nur die drei Addon-Ordner im ZIP-Root** — keine losen Dateien:
  ```
  exo-Twinks-1.9.2.zip
  ├── ExoTwinksCore/
  ├── ExoTwinksData/
  └── ExoTwinksUI/
  ```
- README/CHANGELOG/INSTALL.txt raus aus dem Root (der CurseForge-Client
  installiert sonst Müll bzw. lehnt das Paket ab). CHANGELOG kann stattdessen
  **in** einen der Ordner (z. B. `ExoTwinksCore/CHANGELOG.md`).
- Multi-Ordner-Addons sind auf CurseForge normal (Altoholic macht es genauso).

### 1.3 Qualitäts-Check vor dem ersten Upload
- Kein obfuskierter Code (haben wir nicht ✔), keine externen Downloads ✔,
  keine Werbung/Tracking im Addon ✔ — alles Pflicht laut Curse-Richtlinien.
- Testlauf in-game auf aktuellem Patch ohne Lua-Fehler.

---

## Phase 2 — Projekt auf CurseForge anlegen (machst du, ~20 Min, einmalig)

1. **Account**: https://www.curseforge.com → Sign Up / Login (Twitch-Login geht auch).
2. **Projekt erstellen**: "Start a Project" → Spiel **World of Warcraft** → Typ **Addon**.
3. **Pflichtfelder ausfüllen**:
   - Name: `exo-Twinks`
   - Summary (1 Satz, EN empfohlen): *"Altoholic-style account overview: characters, bags, banks, warband bank & warbound items — with icon/list views and powerful item search."*
   - Description: ausführlich, am besten zweisprachig EN + DE
     (Vorlage: unser README + Discord-Changelog; ich bereite den Text vor)
   - Kategorien: **Inventory**, **Bags & Inventory**, ggf. **Data Export**
   - Lizenz (aus Phase 0)
   - Projekt-Icon: 400×400 PNG (kann ich generieren)
4. **2–4 Screenshots hochladen**: Übersicht, Inventar-Symbolansicht, Bank,
   Charaktere-Detail. (Machst du in-game: Fenster öffnen → Druck-Taste →
   Screenshots-Ordner.)
5. **Erste Datei hochladen** (Phase 3) — ohne Datei bleibt das Projekt unsichtbar.
6. **Moderation abwarten**: Neue Projekte werden manuell geprüft,
   dauert normalerweise 1–3 Werktage. Erst danach ist es öffentlich sichtbar
   und im CurseForge-Client finbar.

---

## Phase 3 — Erster Datei-Upload (machst du im Browser, 5 Min)

1. Projektseite → **Files** → **Upload File**.
2. ZIP aus Phase 1.2 auswählen.
3. **Display Name**: `exo-Twinks 1.9.2`
4. **Release Type**: anfangs **Beta** (ehrlich + senkt Erwartungen),
   später **Release** wenn stabil.
5. **Game Version**: aktuellen 12.x-Patch ankreuzen (Pflichtfeld).
6. **Changelog** einfügen (nehmen wir aus CHANGELOG.md, ich liefere pro
   Release einen fertigen EN/DE-Text).
7. Hochladen → Datei wird automatisch gescannt (wenige Minuten bis Stunden).

---

## Phase 4 — Updates automatisieren (mache ich, ab dem 2. Release)

CurseForge hat eine **Upload-API** — damit passt der Release-Flow in unseren
bestehenden Agent-Workflow:

1. **Du einmalig**: CurseForge → Account → **API Tokens** → Token erzeugen
   und mir wie den GitHub-Token über das Regelwerk-Dokument geben
   (gleiche Regeln: nie ausgeben, nie committen, nach Nutzung Credentials weg).
2. **Projekt-ID** notieren (steht rechts auf der Projektseite).
3. **Ich bei jedem Release zusätzlich**:
   ```
   POST https://wow.curseforge.com/api/projects/<ID>/upload-file
   Header: X-Api-Token: <token>
   metadata: { changelog, changelogType: "markdown",
               displayName: "exo-Twinks X.Y.Z",
               gameVersions: [<ID der 12.x-Version>],
               releaseType: "beta" | "release" }
   file: exo-Twinks-X.Y.Z-curse.zip
   ```
   (Game-Version-IDs hole ich vorher per `GET /api/game/versions`.)
4. **Neuer Gesamt-Release-Flow** dann:
   Tests/luacheck → TOC/CHANGELOG-Bump → GitHub-Branch/PR/Merge/Release →
   **Curse-ZIP bauen → CurseForge-Upload per API** → Kurzreport.
   Regelwerk würde ich dafür auf v1.2 erweitern.

Alternative statt eigener API-Calls: **BigWigs Packager** als GitHub Action
(packt + lädt bei Git-Tag automatisch zu CurseForge hoch). Lohnt sich, wenn
wir sowieso schon auf GitHub releasen — braucht aber `.pkgmeta`-Datei und das
Token als GitHub-Secret. Können wir als Ausbaustufe machen.

---

## Phase 5 — Nach der Veröffentlichung (laufend)

- **Patch-Day-Pflege**: Bei jedem WoW-Patch `## Interface` bumpen + Game
  Version beim Upload ankreuzen, sonst "outdated"-Markierung.
- **Kommentare/Issues**: CurseForge-Kommentare regelmäßig lesen; Bugreports
  bringst du mir, ich fixe → neues Release.
- **Projektseite pflegen**: Screenshots nach größeren UI-Änderungen erneuern.
- **Discord-Post** mit CurseForge-Link, sobald das Projekt freigeschaltet ist.
- Optional später: Spiegel-Upload auf **Wago.io** und **WoWInterface**
  (gleiche ZIPs, eigene Accounts).

---

## Aufgabenverteilung kompakt

| Wer | Was |
|---|---|
| **Du (einmalig)** | CurseForge-Account, Projekt anlegen, Beschreibung/Icon/Screenshots einpflegen, ersten Upload machen, API-Token erzeugen |
| **Du (laufend)** | Screenshots bei UI-Änderungen, Kommentare im Blick behalten |
| **Ich (einmalig)** | TOC-Metadaten, Curse-ZIP-Bau in den Release-Flow, EN/DE-Beschreibungstext, Icon-Entwurf, Regelwerk v1.2 |
| **Ich (laufend)** | Jedes Release automatisch auch zu CurseForge hochladen (API), Changelogs EN/DE |

**Empfohlene Reihenfolge zum Start:** Phase 0 entscheiden → ich baue Phase 1
→ du machst Phase 2+3 → sobald Projekt freigeschaltet: Phase 4 einrichten.
