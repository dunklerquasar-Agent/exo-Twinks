-- Core/Init.lua
-- Bootstrap: einziger Ort mit _G-Beruehrung (globaler Name "Exo" + Slash + Compartment).
-- Verkabelt Scheduler-Tick, ADDON_LOADED und die /exo-Kommandos.

local addonName, Exo = ...

-- Einziger globaler Name des gesamten Projekts:
_G.Exo = Exo

Exo.name = addonName
Exo.version = Exo.WowAPI.GetMetadata("Version") or "0.0.0"

local Log = Exo.Log
local EventBus = Exo.EventBus
local Scheduler = Exo.Scheduler

-- Lifecycle -------------------------------------------------------------------

local function onAddonLoaded(_, loadedName)
	if loadedName ~= addonName then return end

	-- SavedVariables sind ab jetzt verfuegbar -> Store initialisiert,
	-- migriert und registriert den aktuellen Charakter.
	-- Uebernahme der eigenen SavedVariables aus einer frueheren Version.
	if ExoTwinksDB == nil and AltoCoreDB ~= nil then
		ExoTwinksDB = AltoCoreDB
		AltoCoreDB = nil
	end
	ExoTwinksDB = Exo.Store:Init(ExoTwinksDB)

	Log:Info("exo-Twinks v%s geladen (%s, %d Charakter(e) in DB)",
		Exo.version,
		Exo.Store:GetCurrentKey(),
		Exo.Store:CountCharacters())

	EventBus:Fire("EXO_CORE_READY")
end

EventBus:RegisterWowEvent("ADDON_LOADED", onAddonLoaded, Exo)

-- Scheduler-Taktung -----------------------------------------------------------

local ticker = Exo.WowAPI.CreateFrame("Frame")
ticker:SetScript("OnUpdate", function()
	Scheduler:OnTick(Exo.WowAPI.GetTime())
end)

-- UI on demand ------------------------------------------------------------------

local function toggleUI()
	if not Exo.WowAPI.IsAddOnLoaded("ExoTwinksUI") then
		local loaded = Exo.WowAPI.LoadAddOn("ExoTwinksUI")
		if not loaded then
			Log:Warn("ExoTwinksUI konnte nicht geladen werden (Addon fehlt oder ist deaktiviert).")
			return
		end
	end
	if Exo.UI and Exo.UI.Toggle then
		Exo.UI:Toggle()
	else
		Log:Warn("ExoTwinksUI geladen, aber Exo.UI.Toggle fehlt (Phase 3).")
	end
end

-- Slash-Kommandos ---------------------------------------------------------------

local subcommands = {}

subcommands.version = function()
	Log.emit(string.format("|cff69ccf0exo-Twinks|r Version %s", Exo.version))
end

-- /exo vault: offene Schatzkammer-Belohnungen aller Twinks (lokale Ausgabe)
subcommands.vault = function()
	local parts = {}
	for _, charKey in ipairs(Exo.API.GetCharacterKeys()) do
		local mplus = Exo.API.GetMythicPlus(charKey)
		local open = 0
		for _, slot in ipairs((mplus and mplus.vault) or {}) do
			if (slot.progress or 0) >= (slot.threshold or math.huge) then
				open = open + 1
			end
		end
		if open > 0 then
			local meta = Exo.API.GetCharacterInfo(charKey)
			parts[#parts + 1] = string.format("%s %d",
				(meta and meta.name ~= "" and meta.name) or charKey, open)
		end
	end
	if #parts == 0 then
		Log.emit("|cff69ccf0exo-Twinks:|r keine offenen Schatzkammer-Belohnungen.")
	else
		Log.emit("|cff69ccf0exo-Twinks|r Schatzkammer offen (Slots): "
			.. table.concat(parts, ", "))
	end
end

-- /exo mail: bald ablaufende Mails aller Twinks (lokale Ausgabe)
subcommands.mail = function()
	local expiring = Exo.API.GetExpiringMails(7)
	if #expiring == 0 then
		Log.emit("|cff69ccf0exo-Twinks:|r keine Mails laufen innerhalb von 7 Tagen ab.")
		return
	end
	Log.emit(string.format("|cff69ccf0exo-Twinks:|r %d Mail(s) laufen bald ab:", #expiring))
	for index, mail in ipairs(expiring) do
		if index > 5 then
			Log.emit(string.format("  ... und %d weitere.", #expiring - 5))
			break
		end
		local meta = Exo.API.GetCharacterInfo(mail.charKey)
		Log.emit(string.format("  %s: '%s' von %s (%.1f Tage)",
			(meta and meta.name ~= "" and meta.name) or mail.charKey,
			mail.subject ~= "" and mail.subject or "kein Betreff",
			mail.sender, mail.daysLeft))
	end
end

-- /exo tax: Gildensteuer-Bericht | /exo tax rate <prozent> setzt den Satz
-- fuer die Gilde des eingeloggten Charakters (0 loescht den Satz)
subcommands.tax = function(arg)
	local sub, value = tostring(arg or ""):match("^(%S*)%s*(.-)%s*$")

	if sub == "rate" then
		local guild = Exo.WowAPI.GetGuildName()
		if not guild then
			Log.emit("|cff69ccf0exo-Twinks:|r Dieser Charakter ist in keiner Gilde.")
			return
		end
		local percent = tonumber(value)
		if not percent or percent < 0 or percent > 25 then
			Log.emit("|cff69ccf0exo-Twinks:|r Nutzung: /exo tax rate <0-25>")
			return
		end
		Exo.API.SetOption("guildtax.rate." .. guild, percent > 0 and percent or nil)
		Log.emit(string.format(
			"|cff69ccf0exo-Twinks:|r Gildensteuer fuer '%s': %g%%.", guild, percent))
		return
	end

	if Exo.API.GetOption("guildtax.enabled", false) ~= true then
		Log.emit("|cff69ccf0exo-Twinks:|r Gildensteuer ist aus (Designer > Gildensteuer).")
	end
	local report = Exo.API.GetGuildTaxReport()
	if #report.guilds == 0 then
		Log.emit("|cff69ccf0exo-Twinks:|r Kein Steuersatz gesetzt. /exo tax rate 5")
		return
	end
	for _, guild in ipairs(report.guilds) do
		Log.emit(string.format("|cff69ccf0exo-Twinks|r %s (%g%%): %dg offen",
			guild.guild, guild.rate, math.floor(guild.owed / 10000)))
		for _, char in ipairs(guild.chars) do
			if char.owed > 0 then
				Log.emit(string.format("  %s: %dg %ds offen", char.name,
					math.floor(char.owed / 10000),
					math.floor(char.owed / 100) % 100))
			end
		end
	end
end

-- /exo ah: eigene Auktionen aller Twinks (lokale Ausgabe)
subcommands.ah = function()
	local summary = Exo.API.GetAuctionSummary()
	if #summary.chars == 0 then
		Log.emit("|cff69ccf0exo-Twinks:|r keine Auktionsdaten. AH einmal oeffnen.")
		return
	end
	for _, char in ipairs(summary.chars) do
		local extra = char.soldCount > 0
			and string.format(", %d verkauft", char.soldCount) or ""
		Log.emit(string.format("  %s: %d Auktionen, Buyout %dg%s",
			char.name, char.count, math.floor(char.buyoutTotal / 10000), extra))
	end
	Log.emit(string.format("|cff69ccf0exo-Twinks|r Gesamt: %d Auktionen, Buyout %dg",
		summary.totalCount, math.floor(summary.totalBuyout / 10000)))
end

-- /exo keys: Schluesselsteine aller Twinks ansagen (Gruppe/Schlachtzug oder lokal)
subcommands.keys = function()
	local keystones = Exo.API.GetKeystones()
	if #keystones == 0 then
		Log.emit("|cff69ccf0exo-Twinks:|r keine Schluesselsteine bekannt.")
		return
	end
	local parts = {}
	for _, keystone in ipairs(keystones) do
		parts[#parts + 1] = string.format("%s %s +%d",
			keystone.name, keystone.mapName, keystone.level)
	end
	Exo.WowAPI.AnnounceChat("Schluesselsteine: " .. table.concat(parts, ", "))
end

-- /exo demo an|aus: Beispiel-Charaktere fuer Screenshots (1.15.0)
subcommands.demo = function(arg)
	local Demo = Exo.DemoMode
	if arg == "an" or arg == "on" then
		local ok, err = Demo.Enable()
		if ok then
			Log.emit("|cff69ccf0exo-Twinks|r Demo-Modus AN: 8 Beispiel-Chars aktiv,"
				.. " echte Chars ausgeblendet. Beenden mit /exo demo aus")
		elseif err == "already_on" then
			Log.emit("|cff69ccf0exo-Twinks|r Demo-Modus laeuft bereits.")
		end
	elseif arg == "aus" or arg == "off" then
		local ok, err = Demo.Disable()
		if ok then
			Log.emit("|cff69ccf0exo-Twinks|r Demo-Modus AUS: echte Chars wiederhergestellt.")
		elseif err == "already_off" then
			Log.emit("|cff69ccf0exo-Twinks|r Demo-Modus ist nicht aktiv.")
		end
	else
		Log.emit(string.format("|cff69ccf0exo-Twinks|r Demo-Modus ist %s - /exo demo an|aus",
			Demo.IsActive() and "AN" or "AUS"))
	end
end

subcommands.debug = function(arg)
	if arg == "off" then
		Log:SetVerbose(false)
		Log.emit("|cff69ccf0exo-Twinks|r Debug-Modus AUS")
	elseif arg == "dump" then
		local entries = Log:GetEntries()
		Log.emit(string.format("|cff69ccf0exo-Twinks|r Log-Puffer (%d Eintraege):", #entries))
		for _, e in ipairs(entries) do
			Log.emit(string.format("  [%.1f][%s] %s", e.time, Log:LevelName(e.level), e.msg))
		end
	else
		Log:SetVerbose(true)
		Log:SetLevel("DEBUG")
		Log.emit("|cff69ccf0exo-Twinks|r Debug-Modus AN (/exo debug off zum Deaktivieren, /exo debug dump fuer Puffer)")
	end
end

subcommands.help = function()
	Log.emit("|cff69ccf0exo-Twinks|r Kommandos:")
	Log.emit("  /exo           - UI oeffnen/schliessen (auch /twinks, /alto)")
	Log.emit("  /exo version  - Version anzeigen")
	Log.emit("  /exo keys      - Schluesselsteine aller Twinks ansagen")
	Log.emit("  /exo vault     - offene Schatzkammer-Belohnungen")
	Log.emit("  /exo mail      - bald ablaufende Mails")
	Log.emit("  /exo tax       - Gildensteuer-Bericht | tax rate <0-25>")
	Log.emit("  /exo ah        - eigene Auktionen aller Twinks")
	Log.emit("  /exo demo      - Beispiel-Chars fuer Screenshots: an | aus")
	Log.emit("  /exo debug     - Debug-Modus an | off | dump")
	Log.emit("  /exo help      - diese Hilfe")
end

local function onSlashCommand(msg)
	msg = tostring(msg or "")
	local cmd, arg = msg:match("^%s*(%S*)%s*(.-)%s*$")
	cmd = cmd:lower()

	if cmd == "" then
		toggleUI()
	elseif subcommands[cmd] then
		subcommands[cmd](arg ~= "" and arg:lower() or nil)
	else
		Log.emit(string.format("|cff69ccf0exo-Twinks|r Unbekanntes Kommando '%s' - /exo help", cmd))
	end
end

Exo.WowAPI.RegisterSlashCommand("EXO", { "/exo", "/twinks", "/alto", "/altong" }, onSlashCommand)

-- Addon-Compartment (Minimap-Dropdown) --------------------------------------------

_G.ExoTwinks_OnAddonCompartmentClick = function()
	toggleUI()
end

-- Keybinding-Beschriftungen (Bindings.xml)
_G.BINDING_HEADER_EXOTWINKS = "exo-Twinks"
_G.BINDING_NAME_EXO_TOGGLE = "exo-Twinks-Fenster ein-/ausblenden"

-- Fuer Tests exportiert:
Exo._internal = Exo._internal or {}
Exo._internal.onSlashCommand = onSlashCommand
Exo._internal.toggleUI = toggleUI
