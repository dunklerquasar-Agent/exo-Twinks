-- spec/mail_spec.lua
-- Mail-Collector + Ablauf-API (0.16.0)
local mock = require("spec.wow_mock")

describe("Mail-Collector + API", function()
	local Exo

	local function currentChar()
		return Exo.Store:GetCharacter(Exo.Store:GetCurrentKey())
	end

	before_each(function()
		mock.Reset()
		Exo = mock.LoadExoCore()
		mock.SimulateLogin()
	end)

	describe("ScanInbox", function()
		before_each(function()
			mock.SetInbox({
				{ sender = "Bob", subject = "Kraeuter", money = 0, daysLeft = 2.5,
					items = { { id = 777, count = 20, name = "Friedensblume" } } },
				{ sender = "Auktionshaus", subject = "Verkauf", money = 150000, daysLeft = 29 },
			})
		end)

		it("scannt nur bei geoeffnetem Briefkasten (entprellt)", function()
			mock.FireEvent("MAIL_INBOX_UPDATE")
			mock.AdvanceTime(1)
			assert.same({}, currentChar().mails)

			mock.FireEvent("MAIL_SHOW")
			mock.FireEvent("MAIL_INBOX_UPDATE")
			mock.AdvanceTime(0.5)

			local mails = currentChar().mails
			assert.is_number(mails.scannedAt)
			assert.equal(2, #mails.list)
			assert.equal("Bob", mails.list[1].sender)
			assert.equal(2.5, mails.list[1].daysLeft)
			assert.same({ id = 777, count = 20, name = "Friedensblume" },
				mails.list[1].items[1])
			assert.equal(150000, mails.list[2].money)
		end)

		it("nach MAIL_CLOSED wird nicht mehr gescannt", function()
			mock.FireEvent("MAIL_SHOW")
			mock.FireEvent("MAIL_INBOX_UPDATE")
			mock.AdvanceTime(0.5)
			mock.FireEvent("MAIL_CLOSED")

			mock.SetInbox({})
			mock.FireEvent("MAIL_INBOX_UPDATE")
			mock.AdvanceTime(1)
			assert.equal(2, #currentChar().mails.list) -- alter Stand bleibt
		end)
	end)

	describe("API", function()
		local function seedMails(charKey, scannedAt, list)
			Exo.Store:GetOrCreateCharacter(charKey)
			Exo.Store:WriteCharacterData(charKey, "mails",
				{ scannedAt = scannedAt, list = list })
		end

		it("GetMails berechnet Ablauf und Rest-Tage, sortiert nach Ablauf", function()
			local now = Exo.WowAPI.Now()
			seedMails("Default.Testrealm.Anna", now - 86400, {
				{ sender = "A", subject = "spaet", money = 0, daysLeft = 10, items = {} },
				{ sender = "B", subject = "frueh", money = 0, daysLeft = 2, items = {} },
			})
			local mailbox = Exo.API.GetMails("Default.Testrealm.Anna")
			assert.equal(2, #mailbox.mails)
			assert.equal("frueh", mailbox.mails[1].subject) -- laeuft zuerst ab
			-- daysLeft: 2 Tage ab Scan, Scan war vor 1 Tag -> ~1 Tag verbleibt
			assert.is_true(mailbox.mails[1].daysLeft > 0.9
				and mailbox.mails[1].daysLeft < 1.1)
		end)

		it("GetExpiringMails sammelt ueber alle Chars innerhalb der Frist", function()
			local now = Exo.WowAPI.Now()
			seedMails("Default.Testrealm.Anna", now, {
				{ sender = "A", subject = "bald", money = 0, daysLeft = 1, items = {} },
			})
			seedMails("Default.Testrealm.Bob", now, {
				{ sender = "B", subject = "lange", money = 0, daysLeft = 25, items = {} },
			})
			local expiring = Exo.API.GetExpiringMails(3)
			assert.equal(1, #expiring)
			assert.equal("bald", expiring[1].subject)
			assert.equal("Default.Testrealm.Anna", expiring[1].charKey)
		end)

		it("GetMails nil ohne Scan", function()
			assert.is_nil(Exo.API.GetMails("Default.Nix.Niemand"))
		end)
	end)
end)
