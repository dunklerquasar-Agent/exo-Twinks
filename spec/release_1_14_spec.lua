-- spec/release_1_14_spec.lua
-- Lager-Charaktere + "Lagerplatz"-Tooltip (1.14.0), angelehnt an
-- Altoholics "Could be stored on": Items alter Erweiterungen zeigen im
-- Tooltip, auf welchem markierten Char sie eingelagert gehoeren.
local mock = require("spec.wow_mock")

local ERZ = 801      -- Cata-Erz:      Handelsware, Metall & Stein (Bergbau)
local KRAUT = 802    -- MoP-Kraut:     Handelsware, Kraeuter (Kraeuterkunde)
local SCHWERT = 803  -- Cata-Waffe:    keine Handelsware
local AKTUELL = 804  -- Midnight-Item: aktuelle Erweiterung -> nie Hinweis

describe("Release 1.14.0: Lager-Charaktere + Lagerplatz-Tooltip", function()
	local Exo

	local function seed()
		local Store = Exo.Store
		local anna = Store:GetOrCreateCharacter("Default.Testrealm.Anna")
		anna.meta.name = "Anna"
		local bodo = Store:GetOrCreateCharacter("Default.Testrealm.Bodo")
		bodo.meta.name = "Bodo"

		-- Anna hat das Erz in den Taschen (Tooltip zeigt nur Besitz-Items)
		Store:WriteCharacterData("Default.Testrealm.Anna", "bags", {
			[0] = { size = 16, free = 15, items = { [1] = { id = ERZ, count = 20 } } },
		})

		mock.SetItemDetails({
			[ERZ] = { expansion = 3, classID = 7, subclassID = 7 },
			[KRAUT] = { expansion = 4, classID = 7, subclassID = 9 },
			[SCHWERT] = { expansion = 3, classID = 2, subclassID = 7 },
			[AKTUELL] = { expansion = 11, classID = 7, subclassID = 7 },
		})
	end

	before_each(function()
		mock.Reset()
		Exo = mock.LoadExoCore()
		mock.SimulateLogin()
		seed()
	end)

	it("Set/Get/Loeschen einer Lager-Markierung", function()
		local key = "Default.Testrealm.Bodo"
		Exo.API.SetStorageDesignation(key, 3, "Bergbau")
		local entry = Exo.API.GetStorageDesignation(key)
		assert.equal(3, entry.expansion)
		assert.equal("Bergbau", entry.profession)
		assert.equal("Cata-Bergbau", Exo.API.StorageLabel(entry))

		Exo.API.SetStorageDesignation(key, nil, nil)
		assert.is_nil(Exo.API.GetStorageDesignation(key))
	end)

	it("Berufs-Bank: Handelsware findet den passenden Berufs-Char", function()
		Exo.API.SetStorageDesignation("Default.Testrealm.Bodo", nil, "Bergbau")
		local charKey, label = Exo.API.FindStorageChar(ERZ)
		assert.equal("Default.Testrealm.Bodo", charKey)
		assert.equal("Bergbau", label)
		-- Kraut passt nicht zu Bergbau -> kein Treffer
		assert.is_nil(Exo.API.FindStorageChar(KRAUT))
	end)

	it("Berufs-Bank hat Vorrang vor Erweiterungs-Bank", function()
		Exo.API.SetStorageDesignation("Default.Testrealm.Anna", 3, nil)
		Exo.API.SetStorageDesignation("Default.Testrealm.Bodo", nil, "Bergbau")
		-- Erz (Handelsware): Berufs-Bank Bodo gewinnt
		assert.equal("Default.Testrealm.Bodo", (Exo.API.FindStorageChar(ERZ)))
		-- Schwert (keine Handelsware): Erweiterungs-Bank Anna
		local charKey, label = Exo.API.FindStorageChar(SCHWERT)
		assert.equal("Default.Testrealm.Anna", charKey)
		assert.equal("Cata", label)
	end)

	it("aktuelle Erweiterung und versteckte Chars liefern nie einen Treffer", function()
		Exo.API.SetStorageDesignation("Default.Testrealm.Bodo", 11, "Bergbau")
		assert.is_nil(Exo.API.FindStorageChar(AKTUELL))

		Exo.API.SetStorageDesignation("Default.Testrealm.Bodo", 3, nil)
		Exo.API.SetCharacterHidden("Default.Testrealm.Bodo", true)
		assert.is_nil(Exo.API.FindStorageChar(SCHWERT))
	end)

	it("Tooltip zeigt die Lagerplatz-Zeile fuer Altbestand im Besitz", function()
		Exo.API.SetStorageDesignation("Default.Testrealm.Bodo", 3, "Bergbau")
		local lines = mock.HoverItem(ERZ).lines
		local found
		for _, line in ipairs(lines) do
			if line:find("Lagerplatz:", 1, true)
				and line:find("Bodo (Cata-Bergbau)", 1, true) then
				found = true
			end
		end
		assert.truthy(found)
	end)

	describe("Designer-Buttons", function()
		before_each(function() mock.LoadExoUI() end)

		it("je Char gibt es Erweiterungs- und Berufs-Button; Klick schaltet weiter", function()
			local Tab = Exo.UI.DesignerTab
			local content = CreateFrame("Frame")
			Tab:Render(content)

			local expBtn = Tab._GetButtons().storageExp["Default.Testrealm.Anna"]
			local profBtn = Tab._GetButtons().storageProf["Default.Testrealm.Anna"]
			assert.is_not_nil(expBtn)
			assert.is_not_nil(profBtn)

			-- Zyklus: aus -> Classic (0); Beruf: aus -> Bergbau
			expBtn._scripts.OnClick(expBtn)
			profBtn._scripts.OnClick(profBtn)
			local entry = Exo.API.GetStorageDesignation("Default.Testrealm.Anna")
			assert.equal(0, entry.expansion)
			assert.equal("Bergbau", entry.profession)
			assert.equal("Erweiterung: Classic",
				Tab.StorageExpLabel("Default.Testrealm.Anna"))
			assert.equal("Beruf: Bergbau",
				Tab.StorageProfLabel("Default.Testrealm.Anna"))
		end)

		it("kompletter Erweiterungs-Zyklus endet wieder bei aus", function()
			local Tab = Exo.UI.DesignerTab
			for _ = 1, 11 do Tab.CycleStorageExpansion("Default.Testrealm.Bodo") end
			assert.equal(10,
				Exo.API.GetStorageDesignation("Default.Testrealm.Bodo").expansion)
			Tab.CycleStorageExpansion("Default.Testrealm.Bodo")
			assert.is_nil(Exo.API.GetStorageDesignation("Default.Testrealm.Bodo"))
		end)
	end)
end)
