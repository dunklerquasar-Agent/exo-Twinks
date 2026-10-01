-- spec/release_1_11_spec.lua
-- Community-Wuensche II (1.11.0): Charaktere ausblenden + Post-Indikator.
local mock = require("spec.wow_mock")

describe("Release 1.11.0: Community-Wuensche II", function()
	local Exo

	local function seedChar(key, name, realm)
		local char = Exo.Store:GetOrCreateCharacter(key)
		char.meta = char.meta or {}
		char.meta.name = name
		char.meta.realm = realm or "Blackhand"
		char.meta.level = 90
		return char
	end

	before_each(function()
		mock.Reset()
		Exo = mock.LoadExoCore()
		mock.SimulateLogin()
		mock.LoadExoUI()
	end)

	describe("Charaktere ausblenden (Q6)", function()
		it("versteckter Char fehlt in GetCharacterKeys, includeHidden liefert alle", function()
			seedChar("Acc.Blackhand.Bankalt", "Bankalt")
			local before = #Exo.API.GetCharacterKeys()

			Exo.API.SetCharacterHidden("Acc.Blackhand.Bankalt", true)
			assert.equal(before - 1, #Exo.API.GetCharacterKeys())
			assert.equal(before, #Exo.API.GetCharacterKeys(true))
			assert.is_true(Exo.API.IsCharacterHidden("Acc.Blackhand.Bankalt"))

			Exo.API.SetCharacterHidden("Acc.Blackhand.Bankalt", false)
			assert.equal(before, #Exo.API.GetCharacterKeys())
		end)

		it("versteckter Char verschwindet aus der Charaktere-Matrix", function()
			seedChar("Acc.Blackhand.Bankalt", "Bankalt")
			local Tab = Exo.UI.CharactersTab
			local before = #Tab.BuildMatrix().chars

			Exo.API.SetCharacterHidden("Acc.Blackhand.Bankalt", true)
			local matrix = Tab.BuildMatrix()
			assert.equal(before - 1, #matrix.chars)
			for _, char in ipairs(matrix.chars) do
				assert.not_equal("Acc.Blackhand.Bankalt", char.key)
			end
		end)

		it("Item-Zaehlung rechnet versteckte Chars heraus", function()
			local key = "Acc.Blackhand.Bankalt"
			seedChar(key, "Bankalt")
			Exo.Store:WriteCharacterData(key, "bags", {
				[0] = { size = 16, free = 10, items = { [1] = { id = 777, count = 5 } } },
			})

			assert.equal(5, Exo.API.GetItemCounts(777).total)
			Exo.API.SetCharacterHidden(key, true)
			local counts = Exo.API.GetItemCounts(777)
			assert.equal(0, counts.total)
			assert.is_nil(counts.chars[key])
		end)

		it("Designer-Toggle schaltet um; ResetAll blendet alle wieder ein", function()
			seedChar("Acc.Blackhand.Bankalt", "Bankalt")
			local Designer = Exo.UI.DesignerTab
			Designer.ToggleCharHidden("Acc.Blackhand.Bankalt")
			assert.is_true(Exo.API.IsCharacterHidden("Acc.Blackhand.Bankalt"))

			Designer.ResetAll()
			assert.is_false(Exo.API.IsCharacterHidden("Acc.Blackhand.Bankalt"))
		end)
	end)

	describe("Post-Indikator (Q8)", function()
		local Tab
		before_each(function() Tab = Exo.UI.CharactersTab end)

		it("FormatMailCell: leer, neutral, gelb, rot", function()
			assert.equal("-", Tab.FormatMailCell(nil))
			assert.equal("-", Tab.FormatMailCell({ mails = {} }))

			local neutral = Tab.FormatMailCell({ mails = { { daysLeft = 20 } } })
			assert.equal("1 Mail", neutral)

			local yellow = Tab.FormatMailCell({ mails = {
				{ daysLeft = 20 }, { daysLeft = 5.4 } } })
			assert.truthy(yellow:find("ffd700", 1, true))
			assert.truthy(yellow:find("2 Mails", 1, true))
			assert.truthy(yellow:find("5 T.", 1, true))

			local red = Tab.FormatMailCell({ mails = { { daysLeft = 2.2 } } })
			assert.truthy(red:find("ff3333", 1, true))
			assert.truthy(red:find("2 T.!", 1, true))
		end)

		it("Matrix enthaelt Post-Zeile und warnt bei ablaufender Mail", function()
			local key = Exo.Store:GetCurrentKey()
			Exo.Store:WriteCharacterData(key, "mails", {
				scannedAt = Exo.WowAPI.Now(),
				list = { { sender = "Nachbar", subject = "Erze", daysLeft = 2 } },
			})

			local matrix = Tab.BuildMatrix()
			local mailRow
			for _, row in ipairs(matrix.rows) do
				if row.kind == "mail" then mailRow = row end
			end
			assert.is_not_nil(mailRow)

			local me
			for _, char in ipairs(matrix.chars) do
				if char.key == key then me = char end
			end
			assert.truthy(Tab.CellText(mailRow, me):find("ff3333", 1, true))
		end)

		it("Post-Zeile laesst sich im Designer abschalten", function()
			Exo.API.SetOption("charRow.mail", false)
			for _, row in ipairs(Tab.BuildMatrix().rows) do
				assert.not_equal("mail", row.kind)
			end
		end)
	end)
end)
