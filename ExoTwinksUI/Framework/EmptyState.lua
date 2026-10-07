-- ExoTwinksUI/Framework/EmptyState.lua
-- Einheitlicher Leerzustand (1.19.0): zeigt in der Inhaltsflaeche eines
-- Reiters zentriert einen Hinweis, wenn noch keine Daten vorliegen --
-- statt einer leeren Flaechen mit verstreuten Fusszeilen-Texten.
--
-- Botschaften-Muster (in ALLEN Reitern gleich):
--   Titel: "Noch keine <Datenart>."   (was fehlt)
--   Tipp:  "<Handlung>."              (wie der Nutzer Daten bekommt)
-- Bei Suchen mit 0 Treffern: "Keine <X> gefunden." (ohne Tipp).
--
-- Nutzung:
--   1) Build-Zeit  (einmalig):  Exo.UI.EmptyState.Attach(content, { top = 44, bottom = 20 })
--   2) Render-Zeit (jeder Lauf):
--        leer:  Exo.UI.EmptyState.Show(content, "Noch keine Bankdaten.",
--                                       "Mit diesem Charakter einmal die Bank oeffnen.")
--        nicht: Exo.UI.EmptyState.Hide(content)
--
-- ItemList-Reiter (Bank, KM-Bank, KM-Items) erledigen das automatisch in
-- ItemList.Present() aus den Tab-Feldern emptyTitle/emptyHint.

local ES = {}
Exo.UI.EmptyState = ES

local TITLE_FONT = "GameFontNormal"
local HINT_FONT = "GameFontHighlightSmall"
local GRAY = "|cff808080"

-- Anchor-Standard: Liste liegt zwischen Titelzeile (top) und Fusszeile
-- (bottom) -- deckt die Inhaltsflaeche der ItemList-Reiter ab.
local DEFAULT_MARGIN = { top = 44, bottom = 20 }

-- Zentrierter Leerzustand in einer Inhaltsflaeche erzeugen.
-- Idempotent: zweiter Aufruf liefert denselben Zustand zurueck.
-- margin: { top = px unter dem Fenstertitel, bottom = px ueber dem Footer }
function ES.Attach(content, margin)
	-- type-Check: Test-Mock-Frame liefern fuer unbekannte Felder Stubs
	local existing = content._emptyState
	if type(existing) == "table" then return existing end
	margin = margin or DEFAULT_MARGIN

	local host = Exo.WowAPI.CreateFrame("Frame", nil, content)
	host:SetPoint("TOPLEFT", 0, -margin.top)
	host:SetPoint("BOTTOMRIGHT", 0, margin.bottom)

	local title = Exo.UI.Widgets.Label(host, "", TITLE_FONT)
	title:SetPoint("CENTER", 0, 8)
	title:SetJustifyH("CENTER")

	local hint = Exo.UI.Widgets.Label(host, "", HINT_FONT)
	hint:SetPoint("TOP", title, "BOTTOM", 0, 6)
	hint:SetJustifyH("CENTER")

	host:Hide()
	content._emptyState = { host = host, title = title, hint = hint }
	return content._emptyState
end

-- Leerzustand anzeigen (Titel + optionaler Tipp).
function ES.Show(content, title, hint)
	local es = ES.Attach(content)
	es.title:SetText(GRAY .. title .. "|r")
	if hint and hint ~= "" then
		es.hint:SetText(GRAY .. hint .. "|r")
		es.hint:Show()
	else
		es.hint:SetText("")
		es.hint:Hide()
	end
	es.host:Show()
end

-- Leerzustand ausblenden (Daten vorhanden).
function ES.Hide(content)
	local es = content._emptyState
	if type(es) == "table" then
		es.host:Hide()
	end
end

-- Fertiger grauer Text fur Reiter, die Zeilenlisten zeichnen und keinen
-- zentrierten Widget-Bereich haben (z. B. Uebersicht-Module):
--   "Noch keine Daten."  (+ optionaler Tipp in derselben Zeile)
function ES.Text(title, hint)
	local out = GRAY .. title .. "|r"
	if hint and hint ~= "" then
		out = out .. "  " .. GRAY .. hint .. "|r"
	end
	return out
end

return ES
