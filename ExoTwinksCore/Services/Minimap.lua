-- Services/Minimap.lua
-- Minimap-Button zum Oeffnen des Exo-Fensters. Lebt in ExoTwinksCore, damit er
-- auch ohne geladenes ExoTwinksUI existiert (Klick laedt die UI on demand).
-- Der Klick-Handler bindet Exo._internal.toggleUI spaet (Init laedt zuletzt).

local _, Exo = ...

local W = Exo.WowAPI

local button = W.CreateFrame("Button", "ExoTwinksMinimapButton", Minimap)
button:SetSize(31, 31)
button:SetFrameStrata("MEDIUM")
button:SetPoint("TOPLEFT", Minimap, "TOPLEFT", -4, -100)
button:RegisterForClicks("LeftButtonUp")

local icon = button:CreateTexture(nil, "BACKGROUND")
if icon then
	icon:SetTexture("Interface\\Icons\\inv_drink_13")
	icon:SetSize(20, 20)
	icon:SetPoint("CENTER")
end

button:SetScript("OnClick", function()
	if Exo._internal and Exo._internal.toggleUI then
		Exo._internal.toggleUI()
	end
end)

-- Vault-Kurzform "V 1/2/0" = freigeschaltete Slots Raid/M+/Welt (rein, testbar, 1.10.0)
function Exo.MinimapVaultShort(mplus)
	if not mplus or type(mplus.vault) ~= "table" or #mplus.vault == 0 then return nil end
	local function unlockedOf(vaultType)
		local unlocked = 0
		for _, activity in ipairs(mplus.vault) do
			if activity.type == vaultType
				and (activity.progress or 0) >= (activity.threshold or math.huge) then
				unlocked = unlocked + 1
			end
		end
		return unlocked
	end
	-- Reihenfolge wie im Charaktere-Tab: Raids(3) / Mythic+(1) / Welt(6)
	return string.format("V %d/%d/%d", unlockedOf(3), unlockedOf(1), unlockedOf(6))
end

-- Kompakt-Tooltip (1.0.0): Top-Chars, Gold gesamt, Mail-Warnung (rein, testbar)
function Exo.BuildMinimapTooltipLines()
	local lines = {}
	if not (Exo.Store and Exo.Store:IsReady() and Exo.API) then return lines end

	local chars, totalGold = {}, 0
	for _, charKey in ipairs(Exo.API.GetCharacterKeys()) do
		local summary = Exo.API.GetCharacterSummary(charKey)
		if summary then
			totalGold = totalGold + (summary.gold or 0)
			chars[#chars + 1] = summary
		end
	end
	table.sort(chars, function(a, b) return (a.ilvl or 0) > (b.ilvl or 0) end)

	local shown = math.min(#chars, 8)
	local anyVault = false
	for i = 1, shown do
		local s = chars[i]
		-- Vault-Status je Char anhaengen (1.10.0)
		local vault = Exo.MinimapVaultShort(Exo.API.GetMythicPlus(s.key))
		if vault then anyVault = true end
		lines[#lines + 1] = string.format("%s  Lv %d  iLvl %d  %dg%s",
			(s.name ~= "" and s.name) or s.key, s.level or 0,
			math.floor(s.ilvl or 0), math.floor((s.gold or 0) / 10000),
			vault and ("  |cff1784d1" .. vault .. "|r") or "")
	end
	if anyVault then
		lines[#lines + 1] = "|cff808080V = Schatzkammer Raid/M+/Welt|r"
	end
	if #chars > shown then
		lines[#lines + 1] = string.format("|cff808080+ %d weitere|r", #chars - shown)
	end
	lines[#lines + 1] = string.format("|cffffd700Gesamt: %dg (%d Chars)|r",
		math.floor(totalGold / 10000), #chars)

	-- Hoechster Schluesselstein (1.1.0)
	local keystones = Exo.API.GetKeystones and Exo.API.GetKeystones() or {}
	if #keystones > 0 then
		lines[#lines + 1] = string.format("Top-Key: %s %s +%d",
			keystones[1].name, keystones[1].mapName, keystones[1].level)
	end

	-- Scan-Luecken (1.1.1): nur anzeigen, wenn wirklich etwas fehlt
	if Exo.API.GetScanStatus then
		local incomplete = 0
		for _, key in ipairs(Exo.API.GetCharacterKeys()) do
			local status = Exo.API.GetScanStatus(key)
			if status and (not status.bank or not status.mails
				or #status.missingRecipes > 0) then
				incomplete = incomplete + 1
			end
		end
		if incomplete > 0 then
			lines[#lines + 1] = string.format(
				"|cffffd700Scan unvollstaendig: %d Chars|r", incomplete)
		end
	end

	local expiring = Exo.API.GetExpiringMails and Exo.API.GetExpiringMails(3) or {}
	if #expiring > 0 then
		lines[#lines + 1] = string.format("|cffff4538%d Mail(s) laufen bald ab!|r", #expiring)
	end
	return lines
end

button:SetScript("OnEnter", function(self)
	if GameTooltip then
		GameTooltip:SetOwner(self, "ANCHOR_LEFT")
		GameTooltip:SetText("exo-Twinks")
		for _, line in ipairs(Exo.BuildMinimapTooltipLines()) do
			GameTooltip:AddLine(line, 1, 1, 1)
		end
		GameTooltip:AddLine("Klick: Fenster oeffnen/schliessen", 0.6, 0.6, 0.6)
		GameTooltip:Show()
	end
end)

-- Sichtbarkeit gemaess Option (Designer: "Minimap-Button")
Exo.EventBus:Register("EXO_CORE_READY", function()
	if Exo.API and Exo.API.GetOption("minimap.hide", false) == true then
		button:Hide()
	end
end, button)

button:SetScript("OnLeave", function()
	if GameTooltip then
		GameTooltip:Hide()
	end
end)

Exo.MinimapButton = button
