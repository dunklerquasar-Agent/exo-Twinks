-- spec/fixtures/legacy_datastore.lua
-- Realistische Nachbildung der SavedVariables des alten DataStore (Thaoky, Stand 2026-09).
-- Struktur per Code-Analyse verifiziert:
--   DataStore_CharacterIDs.Set["Default.Realm.Name"] = id
--   DataStore_Characters_Info[id] = { name, money, played, zone, lastLogoutTimestamp, BaseInfo }
--   BaseInfo = level + classID*2^7 + raceID*2^11 + gender*2^18  (bit-gepackt!)

local fixture = {}

local function packBaseInfo(level, classID, raceID, gender)
	return level + classID * 2 ^ 7 + raceID * 2 ^ 11 + (gender or 2) * 2 ^ 18
end

-- Container-Item: Bits 0-15 Anzahl, Bits 16+ Item-ID
local function packItem(itemID, count)
	return count + itemID * 2 ^ 16
end

-- Container-Info: Bits 3-9 = Taschengroesse (Rest hier irrelevant)
local function packBagInfo(size)
	return size * 2 ^ 3
end

fixture.packBaseInfo = packBaseInfo
fixture.packItem = packItem
fixture.packBagInfo = packBagInfo

-- Installiert die Legacy-Globals in _G (wie ein geladenes altes DataStore)
function fixture.Install()
	_G.DataStore_CharacterIDs = {
		Set = {
			["Default.Testrealm.Altfried"] = 1,
			["Default.Testrealm.Bankalt"] = 2,
			["Default.Zweitrealm.Magierin"] = 3,
		},
		List = {
			"Default.Testrealm.Altfried",
			"Default.Testrealm.Bankalt",
			"Default.Zweitrealm.Magierin",
		},
	}

	_G.DataStore_Characters_Info = {
		[1] = {
			name = "Altfried",
			money = 5000000,                            -- 500 Gold
			played = 360000,
			zone = "Dornogal",
			lastLogoutTimestamp = 1650000000,
			BaseInfo = packBaseInfo(80, 2, 1, 2),       -- Level 80, Paladin (2), Mensch (1)
		},
		[2] = {
			name = "Bankalt",
			money = 123,
			played = 7200,
			zone = "Sturmwind",
			lastLogoutTimestamp = 5000000000,           -- Sentinel: "gerade eingeloggt"
			BaseInfo = packBaseInfo(10, 5, 4, 3),       -- Level 10, Priester (5), Nachtelf (4)
		},
		[3] = {
			name = "Magierin",
			money = 987654321,
			played = 1200000,
			zone = "Silbermond",
			lastLogoutTimestamp = 1700000123,
			BaseInfo = packBaseInfo(72, 8, 10, 3),      -- Level 72, Magier (8), Blutelf (10)
		},
	}

	-- Taschen/Bank (DataStore_Containers): Altfried hat Honigwaben in Tasche,
	-- Reagenzientasche UND Bank -- das Repro-Szenario aus dem Beta-Test.
	_G.DataStore_Containers_Characters = {
		[1] = {
			Containers = {
				[0] = { -- Ruecksack, 32 Plaetze
					info = packBagInfo(32),
					items = { [1] = packItem(228741, 16), [4] = packItem(190320, 3) },
				},
				[5] = { -- Reagenzientasche
					info = packBagInfo(36),
					items = { [2] = packItem(228741, 4) },
				},
				[6] = { -- Bank-Tab 1
					info = packBagInfo(98),
					items = { [10] = packItem(228741, 7) },
				},
				[7] = { items = {} }, -- leerer Bank-Tab: darf nicht auftauchen
			},
		},
		-- id 2 (Bankalt): absichtlich KEINE Containerdaten
		[3] = {
			Containers = {
				[0] = { -- kein info-Feld: Groesse muss aus max. Slot fallen
					items = { [3] = packItem(190320, 5) },
				},
			},
		},
	}

	-- Kriegsmeutenbank (accountweit, Tabs 13-17)
	_G.DataStore_Containers_Warbank = {
		[13] = {
			name = "Tab 1",
			items = { [1] = packItem(228741, 100) },
		},
	}

	-- Itemlevel (DataStore_Inventory)
	_G.DataStore_Inventory_Characters = {
		[1] = { averageItemLvl = 481.6, overallAIL = 483.2 },
		[3] = { averageItemLvl = 302.5 },
	}
end

return fixture
