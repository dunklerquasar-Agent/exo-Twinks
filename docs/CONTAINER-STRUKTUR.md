# Container-Struktur (Audit 1.6.3)

Referenz, welcher Bereich wie erfasst wird. Alle IDs kommen seit 1.6.2/1.6.3
zur LAUFZEIT vom Client (Enum.BagIndex); Konstanten sind nur noch Fallback.

| Bereich | IDs (Quelle) | Fallback | Scan-Trigger | Ablage |
|---|---|---|---|---|
| Rucksack + Taschen + Reagenzientasche | `Enum.BagIndex.Backpack, Bag_1..N, ReagentBag` via `W.GetCharacterBagIDs()` | 0-5 | Login + BAG_UPDATE (entprellt 0,5 s) | `char.bags[bagID]` |
| Charakterbank | `Enum.BagIndex.CharacterBankTab_1..N` via `W.GetBankBagIDs()` | -1, 6-12, -3 (Reagenzienbank) | Bankbesuch (sofort + Nachfass-Scan nach 1 s) + BAG_UPDATE der Tab-IDs | `char.bank[bagID]` |
| Kriegsmeutenbank | `Enum.BagIndex.AccountBankTab_1..N` via `W.GetWarbandBagIDs()` (beginnt seit 11.2 bei 12!) | 13-17 | wie Charakterbank | `account.warbandBank[bagID]` |
| Gildenbank | Tabs `1..GetNumGuildBankTabs()`, Slots `MAX_GUILDBANK_SLOTS_PER_TAB` (Fallback 98), Tab-Name via `GetGuildBankTabInfo` | 98 Slots | Gildenbank oeffnen + GUILDBANKBAGSLOTS_CHANGED (entprellt) | `guilds[Name].bank[tab]` (+ `.name`) |

## Einheitliches BagSet-Format

Alle vier Bereiche nutzen dieselbe Struktur -- deshalb funktionieren Suche,
Zaehler, Tooltips und Inventar-Browse ueberall identisch:

    [bagID] = {
        size = n,           -- Plaetze gesamt
        free = n,           -- freie Plaetze
        items = { [slot] = { id = itemID, count = n } },
        bagItemID = itemID, -- nur Char-Taschen 1-5: die Tasche selbst
        name = "Mats",      -- nur Gildenbank: Tab-Beschriftung
    }

## Wichtige Erkenntnisse aus den Bugfixes

- 1.6.1: Warband-Inhalte laden oft NACH `BANKFRAME_OPENED` -> Nachfass-Scan.
- 1.6.2: Seit Patch 11.2 beginnen die Kriegsmeuten-Tabs bei ID 12 --
  feste ID-Listen sind verboten, immer `Enum.BagIndex` fragen.
- 1.6.3: Bank-TABS haben keine Inventar-Slots mehr ->
  `ContainerIDToInventoryID` nur noch fuer Char-Taschen 1-5 aufrufen.
