-- ExoTwinksUI/Tabs/Mail.lua
-- Reiter "Post" (0.16.0): Briefkasten-Uebersicht ueber alle Charaktere --
-- was liegt wo, von wem, mit wieviel Gold/Items -- inkl. Ablauf-Warnung:
--   < 3 Tage  -> rot, < 7 Tage -> gelb, sonst grau.
-- Gescannt wird beim Oeffnen des Briefkastens je Charakter.
-- Datenlogik (BuildRows/ExpiryText) ist rein und testbar.

local Tab = {
	id = "mail",
	label = "Post",
}
Exo.UI.MailTab = Tab

local VISIBLE_ROWS = 14
local ROW_HEIGHT = 20

local function charLabel(charKey)
	local meta = Exo.API.GetCharacterInfo(charKey)
	local name = (meta and meta.name ~= "" and meta.name) or charKey
	return Exo.UI.Format.ClassName(name, meta and meta.classID)
end

-- Ablauf-Angabe mit Dringlichkeitsfarbe (rein, testbar)
function Tab.ExpiryText(daysLeft)
	local Theme = Exo.UI.Theme
	local text
	if daysLeft < 1 then
		text = string.format("laeuft in %.0f Std. ab", math.max(0, daysLeft * 24))
	else
		text = string.format("laeuft in %.0f Tagen ab", daysLeft)
	end
	if daysLeft <= 3 then return Theme.Color(text, "negative") end
	if daysLeft <= 7 then return Theme.Color(text, "warning") end
	return Theme.Color(text, "muted")
end

-- Inhaltsangabe einer Mail (1.2.1): Itemnamen in Seltenheitsfarbe + Gold.
-- Beispiel: "Friedensblume x20, Silberbarren x3, +2 weitere, 12g 34s"
local MAX_SHOWN_ITEMS = 3

function Tab.ContentText(mail)
	local Format = Exo.UI.Format
	local parts = {}
	local items = mail.items or {}
	local shown = math.min(#items, MAX_SHOWN_ITEMS)
	for i = 1, shown do
		local item = items[i]
		local name = item.name or Exo.WowAPI.GetItemName(item.id)
			or ("Item " .. tostring(item.id))
		local text = Format.ItemName(name, Exo.WowAPI.GetItemQuality(item.id))
		if (item.count or 1) > 1 then
			text = text .. " x" .. item.count
		end
		parts[#parts + 1] = text
	end
	if #items > shown then
		parts[#parts + 1] = string.format("|cff808080+%d weitere|r", #items - shown)
	end
	if (mail.money or 0) > 0 then
		parts[#parts + 1] = Format.Gold(mail.money)
	end
	if #parts == 0 then return "|cff808080nur Text|r" end
	return table.concat(parts, ", ")
end

-- Zeilen: { header = true, label } | { text }
function Tab.BuildRows()
	local rows = {}
	local totalMails = 0

	-- Zusammenfassung oben (1.1.1): dringende Mails sofort sichtbar
	local expiring = Exo.API.GetExpiringMails(3)
	if #expiring > 0 then
		local verb = #expiring == 1 and "laeuft" or "laufen"
		rows[#rows + 1] = { text = Exo.UI.Theme.Color(string.format(
			"%s %s in unter 3 Tagen ab!",
			Exo.UI.Format.Count(#expiring, "Mail", "Mails"), verb), "negative") }
	end

	for _, charKey in ipairs(Exo.API.GetCharacterKeys()) do
		local mailbox = Exo.API.GetMails(charKey)
		if mailbox and #mailbox.mails > 0 then
			rows[#rows + 1] = { header = true,
				label = string.format("%s  |cff808080(%s)|r", charLabel(charKey),
					Exo.UI.Format.Count(#mailbox.mails, "Mail", "Mails")) }
			for _, mail in ipairs(mailbox.mails) do
				totalMails = totalMails + 1
				rows[#rows + 1] = {
					text = string.format("%s  |cff808080von|r %s  %s  %s",
						mail.subject ~= "" and mail.subject or "|cff808080(kein Betreff)|r",
						mail.sender, Tab.ContentText(mail), Tab.ExpiryText(mail.daysLeft)),
					-- Shift-Klick fuegt die Anhaenge als Itemlinks ein (1.2.1)
					items = mail.items,
				}
			end
		end
	end

	-- totalMails == 0: Render zeigt den zentrierten Leerzustand (1.19.0)
	return rows
end

-- Aufbau ---------------------------------------------------------------------------

local function buildUI(self, content)
	local W = Exo.WowAPI
	local Widgets = Exo.UI.Widgets

	-- Einheitlicher Leerzustand (1.19.0) -- Flaeche der Mail-Liste
	Exo.UI.EmptyState.Attach(content, { top = 4, bottom = 20 })

	local listHost = W.CreateFrame("Frame", nil, content)
	listHost:SetPoint("TOPLEFT", 0, -4)
	listHost:SetPoint("BOTTOMRIGHT", 0, 20)

	self._scroller = Exo.UI.VirtualScroll.New{
		parent = listHost,
		visibleRows = VISIBLE_ROWS,
		rowHeight = ROW_HEIGHT,
		createRow = function(parent, rowIndex)
			local row = W.CreateFrame("Frame", nil, parent)
			row:SetHeight(ROW_HEIGHT)
			row:SetPoint("TOPLEFT", 0, -((rowIndex - 1) * ROW_HEIGHT))
			row:SetPoint("TOPRIGHT", 0, -((rowIndex - 1) * ROW_HEIGHT))
			row.bg = row:CreateTexture(nil, "BACKGROUND")
			row.bg:SetAllPoints(row)
			row.bg:SetColorTexture(1, 1, 1, 1)
			-- Icon des ersten Anhangs (1.4.3)
			row.icon = row:CreateTexture(nil, "ARTWORK")
			row.icon:SetSize(16, 16)
			row.icon:SetPoint("LEFT", 4, 0)
			row.text = Widgets.Label(row, "")
			row.text:SetPoint("LEFT", 24, 0)
			row.text:SetWidth(660)
			row.text:SetWordWrap(false)
			-- Shift-Klick: Anhaenge als Itemlinks in den Chat (1.2.1)
			row:EnableMouse(true)
			Widgets.AddRowHighlight(row)
			row:SetScript("OnMouseDown", function(frame)
				if frame._mailItems and Exo.WowAPI.IsShiftDown() then
					for _, mailItem in ipairs(frame._mailItems) do
						Exo.WowAPI.InsertItemLink(mailItem.id)
					end
				end
			end)
			return row
		end,
		updateRow = function(row, item, absoluteIndex)
			if item.header then
				row._mailItems = false
				row.icon:Hide()
				row.bg:SetColorTexture(1, 1, 1, 0.09)
				row.text:SetText(item.label)
			else
				if item.items and item.items[1] then
					row.icon:SetTexture(Exo.WowAPI.GetItemIcon(item.items[1].id))
					row.icon:Show()
				else
					row.icon:Hide()
				end
				-- false statt nil (Mock-Auto-Stubs, siehe Overview.lua)
				row._mailItems = (item.items and #item.items > 0) and item.items or false
				row.bg:SetColorTexture(1, 1, 1, (absoluteIndex % 2 == 0) and 0.04 or 0)
				row.text:SetText(item.text)
			end
		end,
	}

	self._footer = Widgets.Label(content, "", "GameFontNormal")
	self._footer:SetPoint("BOTTOMLEFT", 4, 2)
end

function Tab:Render(content)
	if self._content ~= content then
		self._content = content
		buildUI(self, content)
	end

	self._scroller:SetData(Tab.BuildRows())

	-- Footer (1.1.1): einheitliche Zaehlung wie in Inventar/Suche
	local totalMails, charCount = 0, 0
	for _, charKey in ipairs(Exo.API.GetCharacterKeys()) do
		local mailbox = Exo.API.GetMails(charKey)
		if mailbox and #mailbox.mails > 0 then
			charCount = charCount + 1
			totalMails = totalMails + #mailbox.mails
		end
	end
	if totalMails > 0 then
		Exo.UI.EmptyState.Hide(content)
		self._footer:SetText(string.format("%s bei %s.",
			Exo.UI.Format.Count(totalMails, "Mail", "Mails"),
			Exo.UI.Format.Count(charCount, "Charakter", "Charakteren")))
	else
		-- Einheitlicher Leerzustand (1.19.0), zentriert in der Listenflaeche
		Exo.UI.EmptyState.Show(content, "Noch keine Maildaten.",
			"Der Briefkasten wird beim Oeffnen automatisch erfasst.")
		self._footer:SetText("")
	end
end

-- Test-Helfer
function Tab._GetScroller() return Tab._scroller end
function Tab._GetFooter() return Tab._footer end

Exo.UI:RegisterTab(Tab)
