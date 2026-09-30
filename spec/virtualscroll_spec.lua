-- spec/virtualscroll_spec.lua
local mock = require("spec.wow_mock")

describe("VirtualScroll", function()
	local Exo, scroller, rendered

	-- Baut einen Scroller mit 10 sichtbaren Zeilen; rendered[i] = Text der Widget-Zeile i
	local function build(visibleRows)
		rendered = {}
		scroller = Exo.UI.VirtualScroll.New{
			parent = CreateFrame("Frame"),
			visibleRows = visibleRows or 10,
			createRow = function(parent, index)
				local row = CreateFrame("Frame", nil, parent)
				row._index = index
				return row
			end,
			updateRow = function(row, item)
				rendered[row._index] = item
			end,
		}
	end

	local function items(n)
		local list = {}
		for i = 1, n do list[i] = "item-" .. i end
		return list
	end

	before_each(function()
		mock.Reset()
		Exo = mock.LoadExoCore()
		mock.SimulateLogin()
		mock.LoadExoUI()
		build()
	end)

	it("zeigt initial die ersten visibleRows Eintraege", function()
		scroller:SetData(items(25))
		assert.equal("item-1", rendered[1])
		assert.equal("item-10", rendered[10])
	end)

	it("erzeugt nur visibleRows Widget-Zeilen, egal wie viele Daten", function()
		scroller:SetData(items(5000))
		assert.equal(10, #scroller.rows) -- Virtualisierung!
	end)

	it("Scroll verschiebt den Ausschnitt", function()
		scroller:SetData(items(25))
		scroller:Scroll(5)
		assert.equal("item-6", rendered[1])
		assert.equal("item-15", rendered[10])
	end)

	it("klemmt den Offset an beiden Enden", function()
		scroller:SetData(items(25))
		scroller:Scroll(9999)
		assert.equal(15, scroller:GetOffset()) -- 25 - 10
		assert.equal("item-25", rendered[10])

		scroller:Scroll(-9999)
		assert.equal(0, scroller:GetOffset())
	end)

	it("Mausrad steuert den Scroll (hoch = zurueck)", function()
		scroller:SetData(items(25))
		local wheel = scroller:GetFrame():GetScript("OnMouseWheel")

		wheel(scroller:GetFrame(), -1) -- Rad runter
		assert.equal(1, scroller:GetOffset())
		wheel(scroller:GetFrame(), 1)  -- Rad hoch
		assert.equal(0, scroller:GetOffset())
	end)

	it("blendet Zeilen ohne Daten aus", function()
		scroller:SetData(items(3))
		assert.is_true(scroller.rows[3]:IsShown())
		assert.is_false(scroller.rows[4]:IsShown())
	end)

	it("SetData mit kleinerer Liste klemmt den Offset", function()
		scroller:SetData(items(25))
		scroller:Scroll(15)
		scroller:SetData(items(12))
		assert.equal(2, scroller:GetOffset()) -- 12 - 10
	end)

	describe("dynamische Zeilenzahl (vergroesserbares Fenster, 0.10.4)", function()
		it("erzeugt mehr Zeilen, wenn der Frame hoeher wird", function()
			build(5)
			scroller.frame.GetHeight = function() return 200 end -- 200 / 20px = 10 Zeilen
			scroller:SetData(items(25))
			assert.equal(10, scroller.visibleRows)
			assert.equal("item-10", rendered[10])
			assert.is_true(scroller.rows[10]:IsShown())
		end)

		it("blendet ueberzaehlige Zeilen aus, wenn der Frame kleiner wird", function()
			build(5)
			scroller.frame.GetHeight = function() return 200 end
			scroller:SetData(items(25)) -- erst gross: 10 Zeilen
			scroller.frame.GetHeight = function() return 60 end -- dann klein: 3 Zeilen
			scroller:Refresh()
			assert.equal(3, scroller.visibleRows)
			assert.is_true(scroller.rows[3]:IsShown())
			assert.is_false(scroller.rows[4]:IsShown())
		end)

		it("ohne messbare Hoehe bleibt die konfigurierte Zeilenzahl", function()
			build(5)
			scroller:SetData(items(25)) -- Mock: GetHeight liefert nichts
			assert.equal(5, scroller.visibleRows)
		end)
	end)
end)
