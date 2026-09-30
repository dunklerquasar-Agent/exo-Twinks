-- ExoTwinksUI/Framework/Window.lua
-- Minimales Hauptfenster mit Tab-System (Vorstufe des Phase-3-Frameworks).
-- Komplett in Lua, kein XML (Architektur-Regel 5).

local UI = Exo.UI or {}
Exo.UI = UI

UI.tabs = {}          -- Reihenfolge der Registrierung = Reihenfolge der Reiter
UI.tabsById = {}
UI.activeTabId = nil

local window          -- Hauptframe (lazy erzeugt)
local TAB_HEIGHT = 24
local WINDOW_W, WINDOW_H = 720, 420
local SIDEBAR_W = 110 -- Breite der linken Navigation (Designer: nav.position = "left")

local function navIsLeft()
	return Exo.API.GetOption("nav.position", "top") == "left"
end

-- Tab-Registrierung ----------------------------------------------------------------
-- tab = { id, label, Render = function(self, contentFrame) ... }

function UI:RegisterTab(tab)
	assert(tab and tab.id and tab.label and type(tab.Render) == "function",
		"UI:RegisterTab: braucht id, label und Render()")
	assert(not self.tabsById[tab.id], "UI:RegisterTab: Tab-ID doppelt: " .. tostring(tab.id))
	self.tabs[#self.tabs + 1] = tab
	self.tabsById[tab.id] = tab
end

-- Fensteraufbau ----------------------------------------------------------------------

local function createWindow()
	local W = Exo.WowAPI

	window = W.CreateFrame("Frame", "ExoTwinksMainWindow", UIParent, "BackdropTemplate")

	-- ESC schliesst das Fenster (1.1.1)
	if type(UISpecialFrames) == "table" then
		table.insert(UISpecialFrames, "ExoTwinksMainWindow")
	end
	-- Gemerkte Groesse anwenden (Designer: "Groesse merken"), nie kleiner als Standard
	local savedW = tonumber(Exo.API.GetOption("window.width")) or WINDOW_W
	local savedH = tonumber(Exo.API.GetOption("window.height")) or WINDOW_H
	window:SetSize(math.max(WINDOW_W, savedW), math.max(WINDOW_H, savedH))
	window:SetPoint("CENTER")
	window:SetMovable(true)
	window:EnableMouse(true)
	window:RegisterForDrag("LeftButton")
	window:SetScript("OnDragStart", function(self) self:StartMoving() end)
	window:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)

	-- Vergroesserbar: Griff unten rechts, Mindestgroesse = Standardgroesse
	window:SetResizable(true)
	if window.SetResizeBounds then
		window:SetResizeBounds(WINDOW_W, WINDOW_H)
	end
	local grip = W.CreateFrame("Button", nil, window)
	grip:SetSize(16, 16)
	grip:SetPoint("BOTTOMRIGHT", -2, 2)
	grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
	grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
	grip:SetScript("OnMouseDown", function()
		window:StartSizing("BOTTOMRIGHT")
	end)
	grip:SetScript("OnMouseUp", function()
		window:StopMovingOrSizing()
		-- Groesse merken (Designer-Option, Standard: an)
		if Exo.API.GetOption("window.remember", true) then
			local w, h = window:GetWidth(), window:GetHeight()
			if type(w) == "number" and type(h) == "number" then
				Exo.API.SetOption("window.width", math.floor(w + 0.5))
				Exo.API.SetOption("window.height", math.floor(h + 0.5))
			end
		end
		UI:RefreshActiveTab() -- Zeilen/Spalten an neue Groesse anpassen
	end)
	window.resizeGrip = grip
	-- Flacher ElvUI-Look: deckende dunkle Flaeche + 1px schwarze Kante
	Exo.UI.Widgets.Skin(window, Exo.UI.Widgets.COLORS.bg)

	-- Titel (Akzentfarbe im ElvUI-Stil)
	local title = window:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	title:SetPoint("TOPLEFT", 12, -10)
	title:SetText(string.format("|cff%sexo-Twinks|r v%s", Exo.UI.Widgets.COLORS.accentHex, Exo.version))
	window.title = title

	-- Account-Summary: Gold gesamt, Alts, iLvl-Schnitt, offene Vaults
	local summary = window:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	summary:SetPoint("TOPRIGHT", -34, -14)
	summary:SetJustifyH("RIGHT")
	window.summary = summary

	-- Schliessen-Button (flach, "X")
	local close = Exo.UI.Widgets.Button(window, "X", 20, 20, function() UI:Hide() end)
	close:SetPoint("TOPRIGHT", -6, -6)

	-- Tab-Leiste
	local previous
	window.tabButtons = {}
	for _, tab in ipairs(UI.tabs) do
		local btn = Exo.UI.Widgets.Button(window, tab.label, 130, TAB_HEIGHT, function()
			UI:SelectTab(tab.id)
		end)
		if previous then
			btn:SetPoint("LEFT", previous, "RIGHT", 4, 0)
		else
			btn:SetPoint("TOPLEFT", 12, -36)
		end
		window.tabButtons[tab.id] = btn
		previous = btn
	end

	-- Ein Content-Frame pro Tab (Show/Hide beim Wechsel)
	window.contents = {}
	for _, tab in ipairs(UI.tabs) do
		local content = W.CreateFrame("Frame", nil, window)
		content:SetPoint("TOPLEFT", 12, -(40 + TAB_HEIGHT + 8))
		content:SetPoint("BOTTOMRIGHT", -12, 12)
		content:Hide()
		window.contents[tab.id] = content
	end

	window:Hide()
end

-- Steuerung -----------------------------------------------------------------------

function UI:SelectTab(tabId)
	local tab = self.tabsById[tabId]
	if not tab or not window then return end

	for id, content in pairs(window.contents) do
		if id == tabId then
			content:Show()
		else
			content:Hide()
		end
	end
	for id, btn in pairs(window.tabButtons) do
		btn:SetSelected(id == tabId)
	end
	self.activeTabId = tabId
	-- Letzten Reiter merken (1.4.3)
	if Exo.API and Exo.Store and Exo.Store:IsReady() then
		Exo.API.SetOption("window.lastTab", tabId)
	end
	tab:Render(window.contents[tabId])
end

-- Navigations-Layout anwenden (Designer: nav.position = "top" | "left"):
-- Tab-Buttons horizontal oben ODER als Sidebar links; Content-Frames folgen.
function UI:ApplyNavLayout()
	if not window then return end
	local left = navIsLeft()
	for _, content in pairs(window.contents) do
		content:ClearAllPoints()
		if left then
			content:SetPoint("TOPLEFT", 12 + SIDEBAR_W + 8, -40)
		else
			content:SetPoint("TOPLEFT", 12, -(40 + TAB_HEIGHT + 8))
		end
		content:SetPoint("BOTTOMRIGHT", -12, 12)
	end
	self:ApplyTabVisibility() -- ordnet die Buttons im aktiven Layout an
	self:RefreshActiveTab()
end

-- Account-Summary (reine Funktion, testbar): "5 Twinks - 12.345 g - ..."
function UI.BuildAccountSummary()
	local keys = Exo.API.GetCharacterKeys()
	if #keys == 0 then return "" end

	local gold, ilvlSum, ilvlCount, vaultOpen = 0, 0, 0, 0
	for _, key in ipairs(keys) do
		local s = Exo.API.GetCharacterSummary(key)
		if s then
			gold = gold + (s.gold or 0)
			if (s.ilvl or 0) > 0 then
				ilvlSum, ilvlCount = ilvlSum + s.ilvl, ilvlCount + 1
			end
			local mplus = Exo.API.GetMythicPlus(key)
			for _, slot in ipairs((mplus and mplus.vault) or {}) do
				if (slot.progress or 0) >= (slot.threshold or math.huge) then
					vaultOpen = vaultOpen + 1
					break
				end
			end
		end
	end

	local Format = Exo.UI.Format
	local parts = {
		Format.Count(#keys, "Twink", "Twinks"),
		Format.Gold(gold),
	}
	if ilvlCount > 0 then
		parts[#parts + 1] = string.format("iLvl-Schnitt %d",
			math.floor(ilvlSum / ilvlCount + 0.5))
	end
	if vaultOpen > 0 then
		parts[#parts + 1] = Exo.UI.Theme.Color(vaultOpen .. "x Vault offen", "positive")
	end
	-- Gildensteuer (1.4.2): offener Betrag direkt im Fensterkopf
	if Exo.Collectors and Exo.Collectors.GuildTax
		and Exo.Collectors.GuildTax.IsEnabled() then
		local report = Exo.API.GetGuildTaxReport()
		if report.totalOwed > 0 then
			parts[#parts + 1] = Exo.UI.Theme.Color(
				"Steuer offen: " .. Format.Gold(report.totalOwed), "warning")
		end
	end
	return table.concat(parts, "  |cff808080-|r  ")
end

function UI:UpdateSummary()
	if window and window.summary then
		window.summary:SetText(UI.BuildAccountSummary())
	end
end

-- Theme live anwenden (Designer): Fenster neu einfaerben, Titel, Tab-Buttons,
-- danach aktiven Tab neu rendern.
function UI:ApplyTheme()
	if not window then return end
	local Widgets = Exo.UI.Widgets
	Widgets.Skin(window, Widgets.COLORS.bg)
	window.title:SetText(string.format(
		"|cff%sexo-Twinks|r v%s", Widgets.COLORS.accentHex, Exo.version))
	for id, btn in pairs(window.tabButtons) do
		btn:SetSelected(id == self.activeTabId)
	end
	self:RefreshActiveTab()
end

-- Fenstergroesse setzen (Designer-Presets) + optional merken
function UI:SetWindowSize(w, h)
	if not window then return end
	window:SetSize(math.max(WINDOW_W, w), math.max(WINDOW_H, h))
	if Exo.API.GetOption("window.remember", true) then
		Exo.API.SetOption("window.width", w)
		Exo.API.SetOption("window.height", h)
	end
	self:RefreshActiveTab()
end

function UI:GetWindow() return window end

function UI:RefreshActiveTab()
	if window and window:IsShown() and self.activeTabId then
		local tab = self.tabsById[self.activeTabId]
		tab:Render(window.contents[self.activeTabId])
		self:UpdateSummary()
	end
end

-- Tab-Sichtbarkeit anwenden (Designer: "tab.hidden.<id>"): versteckte Reiter
-- ausblenden, sichtbare neu aneinanderreihen. Der Designer selbst ist nie versteckt.
function UI:ApplyTabVisibility()
	if not window then return end
	local function isHidden(tabId)
		return tabId ~= "designer" and Exo.API.GetOption("tab.hidden." .. tabId, false)
	end
	local left = navIsLeft()

	-- Breite oben adaptiv: alle sichtbaren Reiter muessen in die Leiste passen
	local visibleCount = 0
	for _, tab in ipairs(UI.tabs) do
		if not isHidden(tab.id) then visibleCount = visibleCount + 1 end
	end
	local barWidth = (window:GetWidth() or WINDOW_W) - 24
	local topWidth = 130
	if visibleCount > 0 then
		topWidth = math.min(130, math.floor((barWidth - (visibleCount - 1) * 4) / visibleCount))
	end

	local previous
	for _, tab in ipairs(UI.tabs) do
		local btn = window.tabButtons[tab.id]
		if isHidden(tab.id) then
			btn:Hide()
		else
			btn:Show()
			btn:ClearAllPoints()
			btn:SetSize(left and SIDEBAR_W or topWidth, TAB_HEIGHT)
			if previous then
				if left then
					btn:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", 0, -4)
				else
					btn:SetPoint("LEFT", previous, "RIGHT", 4, 0)
				end
			else
				btn:SetPoint("TOPLEFT", 12, left and -40 or -36)
			end
			previous = btn
		end
	end
	-- Aktiver Tab versteckt? Dann auf den ersten sichtbaren wechseln.
	if self.activeTabId and isHidden(self.activeTabId) then
		for _, tab in ipairs(UI.tabs) do
			if not isHidden(tab.id) then
				self:SelectTab(tab.id)
				break
			end
		end
	end
end

function UI:Show()
	if Exo.UI.Theme then Exo.UI.Theme.Load() end -- Designer-Optionen -> Farbschema
	if not window then
		createWindow()
	end
	window:Show()
	local startTab = self.activeTabId
	if not startTab then
		-- gemerkten Reiter wiederherstellen (1.4.3), sofern er existiert
		local remembered = Exo.API.GetOption("window.lastTab", nil)
		if remembered and self.tabsById[remembered] then
			startTab = remembered
		end
	end
	self:SelectTab(startTab or (self.tabs[1] and self.tabs[1].id))
	self:ApplyNavLayout() -- beinhaltet ApplyTabVisibility + Render
	self:UpdateSummary()
end

function UI:Hide()
	if window then
		window:Hide()
	end
end

function UI:IsShown()
	return window ~= nil and window:IsShown()
end

function UI:Toggle()
	if self:IsShown() then
		self:Hide()
	else
		self:Show()
	end
end

-- Live-Aktualisierung: Datenaenderungen refreshen den sichtbaren Tab
Exo.EventBus:Register("EXO_CHAR_UPDATED", function()
	UI:RefreshActiveTab()
end, UI)
Exo.EventBus:Register("EXO_ACCOUNT_UPDATED", function()
	UI:RefreshActiveTab()
end, UI)
