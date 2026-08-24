-- media/lua/client/YourDash/Z_PatchVehicleDashboard_Passenger.lua
if isServer() then return end

require "ISUI/ISPanel"
require "ISUI/ISImage"
require "Vehicles/ISUI/ISVehicleDashboard"
require "Vehicles/ISUI/ISVehiclePartMenu"
require "Vehicles/VehicleUtils"
require "YourDash/DashboardCore"

-- Ensure AC functions exist (guard in that file prevents double-patch).
pcall(function() require "Vehicles/ISUI/Z_PatchVehicleDashboard_AC" end)
-- Sport passenger controls resolve the driver's proven rotary/text handlers at
-- UI-creation time.  RadioRouter owns the deterministic ZZZ sport-patch load
-- order, so do not pull it forward from this later passenger module.

-- Guard: don’t load twice
if ISVehicleDashboard.__YourDashPassengerDashLoaded then return end
ISVehicleDashboard.__YourDashPassengerDashLoaded = true

YourDash = YourDash or {}

local function paxScale()
    local value = YourDash.GetScale and tonumber(YourDash.GetScale()) or 1
    if value ~= 0.75 and value ~= 1 and value ~= 1.4 and value ~= 2 then
        return 1
    end
    return value
end

local function paxScaleKey()
    return YourDash.GetScaleKey and YourDash.GetScaleKey() or "1x"
end

local function paxScaled(value, scale)
    value = (tonumber(value) or 0) * (scale or paxScale())
    if value < 0 then return math.ceil(value - 0.5) end
    return math.floor(value + 0.5)
end

local function paxRawTexture(path)
    if not path or not getTexture then return nil end
    local ok, texture = pcall(getTexture, path)
    if ok then return texture end
    return nil
end

local function paxSafeCall(object, methodName, ...)
    if object == nil then return nil end
    local okMethod, method = pcall(function() return object[methodName] end)
    if not okMethod or type(method) ~= "function" then return nil end
    local ok, value = pcall(method, object, ...)
    if ok then return value end
    return nil
end

local function paxSetMouseTransparent(element)
    if not element then return end
    element.wantMouseEvents = false
    if element.setWantMouseEvents then
        element:setWantMouseEvents(false)
    elseif element.javaObject and element.javaObject.setConsumeMouseEvents then
        element.javaObject:setConsumeMouseEvents(false)
    end
end

local PAX_SPORT_AC_RAW_LEVELS = { -25, -15, -8, 0, 8, 15, 25 }

local function paxNearestSportTempIndex(value)
    value = tonumber(value) or 0
    local bestIndex, bestDistance = 1, math.huge
    for index = 1, #PAX_SPORT_AC_RAW_LEVELS do
        local distance = math.abs(value - PAX_SPORT_AC_RAW_LEVELS[index])
        if distance < bestDistance then
            bestIndex, bestDistance = index, distance
        end
    end
    return bestIndex
end

-- =========================================================
-- Passenger dash panel (separate UI, reuses ISVehicleDashboard helpers)
-- =========================================================
YourDashPassengerDashboard = ISVehicleDashboard:derive("YourDashPassengerDashboard")
YourDashPassengerDashboard.instances = YourDashPassengerDashboard.instances or {}

-- =========================
-- Config.  All positions are authored against each family's 1x passenger art.
-- =========================

-- These two legacy toggles are intentionally the only passenger assets kept
-- at the old shared path.  They are rendered at the active scale below.
YourDashPassengerDashboard.PAX_BTN_RETRACT   = "media/ui/vehicles/passenger/btn_retract.png"
YourDashPassengerDashboard.PAX_BTN_EXPAND    = "media/ui/vehicles/passenger/btn_expand.png"

-- Seat policy: show ONLY for seat index 1 by default (front passenger)
YourDashPassengerDashboard.PAX_SEAT_INDEX = 1

YourDashPassengerDashboard.PAX_OFFSET_X = 0      -- +right / -left
YourDashPassengerDashboard.PAX_OFFSET_Y = 0      -- +down / -up (after bar offset)

YourDashPassengerDashboard.PAX_TIP_RETRACT = "collapse passenger dash"
YourDashPassengerDashboard.PAX_TIP_EXPAND  = "expand passenger dash"

YourDashPassengerDashboard.PAX_LAYOUTS_1X = {
    standard = {
        toggle = { x = 22, y = 18 },
        door = { x = 168, y = 102 },
        window = { x = 198, y = 93 },
        ac = {
            fan = { x = 24, y = 98 },
            slider = { x = 57, y = 105, travel = 86 },
        },
        radioPremium = { x = 10, y = 35 },
        radioStandard = { x = 50, y = 30 },
        barPad = 10,
        barFallback = 70,
    },
    heavy = {
        toggle = { x = 5, y = 5 },
        door = { x = 170, y = 85 },
        window = { x = 204, y = 72 },
        ac = {
            background = { x = 1, y = 68 },
            fan = { x = 22, y = 69 },
            -- Center the handle on the black rail; y=92 placed it over COLD/HOT.
            slider = { x = 45, y = 74, travel = 91 },
        },
        -- Lift each exact-size radio just enough to clear the baked window
        -- glyph while preserving the requested right-side horizontal alignment.
        radioPremium = { x = 31, y = -3 },
        radioStandard = { x = 54, y = 7 },
        barPad = 10,
        barFallback = 70,
    },
    sport = {
        toggle = { x = 5, y = 8 },
        door = { x = 168, y = 90 },
        doorLED = { x = 173, y = 125 },
        window = { x = 194, y = 78 },
        -- The red passenger export is the tightest canvas (227x137 at 1x),
        -- so the complete climate/clock row is authored to that boundary.
        ac = {
            background = { x = 1, y = 77 },
            display = { x = 8, y = 80, width = 31, height = 23, textOffsetX = 2 },
            fan = { x = 10, y = 104 },
            displayButton = { x = 10, y = 120 },
            knob = { x = 49, y = 90 },
        },
        clock = { x = 108, y = 80 },
        -- Both tiers end at x=223 at 1x, inside even the 227px red panel.
        radioPremium = { x = 27, y = 8 },
        radioStandard = { x = 50, y = 12 },
        barPad = 10,
        barFallback = 70,
    },
}

function YourDashPassengerDashboard:_paxGetLayout1x()
    local family = self.__YourDashFamily or "standard"
    return self.PAX_LAYOUTS_1X[family] or self.PAX_LAYOUTS_1X.standard
end

function YourDashPassengerDashboard:_paxSetToggleTexture(texture)
    local button = self.paxToggleBtn
    if not button or not texture then return end
    button.texture = texture
    local scale = self.__YourDashScale or paxScale()
    button:setWidth(paxScaled(texture:getWidthOrig(), scale))
    button:setHeight(paxScaled(texture:getHeightOrig(), scale))
end

function YourDashPassengerDashboard:_paxApplyTexturePack(profile, isInit)
    profile = profile or (self.vehicle and YourDash.GetVehicleProfile(self.vehicle)) or {
        family = "standard", accent = "base",
    }

    local family = profile.family or "standard"
    if family ~= "standard" and family ~= "heavy" and family ~= "sport" then
        family = "standard"
    end
    local accent = profile.accent or "base"
    if accent ~= "base" and accent ~= "lux" and accent ~= "sport" then accent = "base" end
    if family ~= "sport" then accent = "base" end

    local scale = paxScale()
    local scaleKey = paxScaleKey()
    local packKey = family .. ":" .. accent .. ":" .. scaleKey

    self.__YourDashFamily = family
    self.__YourDashAccent = accent
    self.__YourDashScale = scale
    self.__YourDashScaleKey = scaleKey
    self.__YourDashLarge = scaleKey == "2x" -- compatibility only; no layout depends on it
    self.__paxPackKey = packKey

    local expandedName = "passenger_dash.png"
    local retractedName = "passenger_retracted.png"
    if family == "sport" then
        expandedName = "passenger_dash_" .. accent .. ".png"
        retractedName = "passenger_retracted_" .. accent .. ".png"
    end

    local function passengerTex(name)
        return YourDash.GetDashboardTexture and
            YourDash.GetDashboardTexture(family, "passenger", name) or nil
    end
    local function dashTex(name)
        return YourDash.GetDashboardTexture and
            YourDash.GetDashboardTexture(family, "dash", name) or nil
    end

    local expanded = passengerTex(expandedName)
    local retracted = passengerTex(retractedName)
    if family == "sport" and accent ~= "base" then
        expanded = expanded or passengerTex("passenger_dash_base.png")
        retracted = retracted or passengerTex("passenger_retracted_base.png")
    end
    self.__pax_bg_expanded = expanded or self.__pax_bg_expanded
    self.__pax_bg_retracted = retracted or expanded or self.__pax_bg_retracted or self.__pax_bg_expanded

    -- Deliberately bypass YourDash.GetTexture: only the retained 1x originals
    -- exist, and the ISImage render scales them to the selected pack.
    self.__pax_btn_retract = paxRawTexture(self.PAX_BTN_RETRACT)
    self.__pax_btn_expand = paxRawTexture(self.PAX_BTN_EXPAND) or self.__pax_btn_retract

    if family == "heavy" then
        self.__lock_off = dashTex("btn_off.png")
        self.__lock_on = dashTex("btn_on.png") or self.__lock_off
        self.__lock_partial = self.__lock_off
        self.__window_switch = dashTex("window_switch.png")
        self.__window_switch_push = dashTex("window_switch_down.png") or self.__window_switch
        self.__window_switch_pull = dashTex("window_switch_up.png") or self.__window_switch
    elseif family == "sport" then
        self.__lock_off = dashTex("lock_off.png")
        self.__lock_on = self.__lock_off
        self.__lock_partial = self.__lock_off
        self.__window_switch = dashTex("window_switch.png")
        self.__window_switch_push = dashTex("window_switch_down.png") or self.__window_switch
        self.__window_switch_pull = dashTex("window_switch_up.png") or self.__window_switch
    else
        self.__lock_off = dashTex("lock_off.png")
        self.__lock_partial = dashTex("lock_partial.png") or self.__lock_off
        self.__lock_on = dashTex("lock_on.png") or self.__lock_off
        self.__window_switch = dashTex("window_switch.png")
        self.__window_switch_push = dashTex("window_switch_push.png") or self.__window_switch
        self.__window_switch_pull = dashTex("window_switch_pull.png") or self.__window_switch
    end

    if family == "sport" then
        self.__paxSportACOff = dashTex("ac_off.png")
        self.__paxSportACOn = dashTex("ac_on.png") or self.__paxSportACOff
        self.__paxSportFanButtonTex = dashTex("fan_btn.png")
        self.__paxSportACDisplayButtonTex = dashTex("disp_btn_ac.png")
        self.__paxSportTempKnobTex = dashTex("temp_slider.png")
        self.__paxSportClockTex = dashTex("clock.png")
        self.__paxSportClockMinuteTex = dashTex("clock_needle_long.png")
        self.__paxSportClockHourTex = dashTex("clock_needle_short.png")
        self.__paxSportLEDOff = dashTex("led_off.png")
        self.__paxSportLEDOn = dashTex("led_on.png") or self.__paxSportLEDOff
        self.__paxSportLEDPartial = dashTex("led_partial.png") or self.__paxSportLEDOff
    end

    local layout = self:_paxGetLayout1x()
    local radioPremium = layout.radioPremium or {}
    local radioStandard = layout.radioStandard or {}
    -- Radio modules scale these 1x anchors themselves.
    self.RADIO_UI_X, self.RADIO_UI_Y = radioPremium.x or 0, radioPremium.y or 0
    self.RADIO_VALUE_UI_X, self.RADIO_VALUE_UI_Y = radioStandard.x or 0, radioStandard.y or 0

    if self.backgroundTex then self:_paxApplyBGTexture() end
    if self.paxToggleBtn then self:_paxRefreshToggleTexture() end
    if self.doorTex and self.__lock_off then
        self:_setImageTextureAndSize(self.doorTex, self.__lock_off)
        -- Heavy lock artwork already contains its released/pressed depth.
        self.doorTex.__pressedScale = family == "heavy" and 1.0 or 0.96
    end
    if self.windowTex and self.__window_switch then self:_setImageTextureAndSize(self.windowTex, self.__window_switch) end

    -- These helpers retarget existing controls by family/scale; they do not
    -- recreate controls whose ISImage instances already exist.  Never invoke
    -- them from new(), before the panel and its children are instantiated.
    if self.__paxChildrenCreated then
        if self._ensureACControls then pcall(function() self:_ensureACControls() end) end
        if self._ensureRadioControls then pcall(function() self:_ensureRadioControls() end) end
        if self._ensureValueRadioControls then pcall(function() self:_ensureValueRadioControls() end) end
        if self._paxEnsureSportExtras then self:_paxEnsureSportExtras() end
    end

    if (not isInit) and self.onResolutionChange then self:onResolutionChange() end
end

-- =========================================================
-- Fallback helpers (only define if your driver patch didn't)
-- =========================================================
if not ISVehicleDashboard._setImageTextureAndSize then
	function ISVehicleDashboard:_setImageTextureAndSize(img, tex)
		if not img or not tex then return end
		img.texture = tex
		if img.setWidth and tex.getWidthOrig then img:setWidth(tex:getWidthOrig()) end
		if img.setHeight and tex.getHeightOrig then img:setHeight(tex:getHeightOrig()) end
	end
end

if not ISVehicleDashboard._setImageEnabled then
	function ISVehicleDashboard:_setImageEnabled(img, enabled, mouseovertext, onclickFn, target)
		if not img then return end
		img.__disabled = not enabled
		img.target = target or self
		img.onclick = enabled and onclickFn or nil
		img.mouseovertext = enabled and mouseovertext or nil
		img.backgroundColor = { r=0, g=0, b=0, a=0 }
	end
end

if not ISVehicleDashboard._installPressedEffect then
	function ISVehicleDashboard:_installPressedEffect(img, pressedScale)
		if not img or img.__YourDashPressedInstalled then return end
		img.__YourDashPressedInstalled = true
		img.__pressedScale = pressedScale or 0.96
		img.__pressed = false
		img.__disabled = img.__disabled or false

		local function resetPressed(selfBtn) selfBtn.__pressed = false end

		local _down = img.onMouseDown
		function img:onMouseDown(x, y)
			if self.__disabled then return false end
			self.__pressed = true
			if _down then return _down(self, x, y) end
			return true
		end

		local _up = img.onMouseUp
		function img:onMouseUp(x, y)
			resetPressed(self)
			if self.__disabled then return false end
			if _up then return _up(self, x, y) end
			return true
		end

		local _upOut = img.onMouseUpOutside
		function img:onMouseUpOutside(x, y)
			resetPressed(self)
			if _upOut then return _upOut(self, x, y) end
			return true
		end

		function img:render()
			if not self.texture then return end
			local w, h = self.width, self.height
			if not w or not h then return end

			local scale = 1.0
			if (not self.__disabled) and self.__pressed then
				scale = self.__pressedScale
			end

			local dw = w * scale
			local dh = h * scale
			local dx = (w - dw) * 0.5
			local dy = (h - dh) * 0.5
			self:drawTextureScaled(self.texture, dx, dy, dw, dh, self.alpha or 1)
		end
	end
end

if not ISVehicleDashboard._getSeatWindowPart then
	function ISVehicleDashboard:_getSeatWindowPart()
		if not self.vehicle or not self.character then return nil end
		local seat = self.vehicle:getSeat(self.character)
		local door = self.vehicle:getPassengerDoor(seat)
		if not door then return nil end

		local windowPart = VehicleUtils.getChildWindow(door)
		if not windowPart then return nil end

		if windowPart.getItemType and windowPart:getItemType()
			and windowPart.getInventoryItem and (not windowPart:getInventoryItem()) then
			return nil
		end

		local w = windowPart.getWindow and windowPart:getWindow() or nil
		if not w or (w.isOpenable and not w:isOpenable()) or (w.isDestroyed and w:isDestroyed()) then
			return nil
		end

		return windowPart
	end
end

if not ISVehicleDashboard._hasBatteryPower then
	function ISVehicleDashboard:_hasBatteryPower()
		return self.vehicle and (self.vehicle:getBatteryCharge() or 0) > 0
	end
end

if not ISVehicleDashboard.onClickWindow then
	function ISVehicleDashboard:onClickWindow()
		if getGameSpeed() == 0 then return end
		if getGameSpeed() > 1 then setGameSpeed(1) end
		if not self.vehicle then return end

		local windowPart = self:_getSeatWindowPart()
		if not windowPart then return end

		local w = windowPart:getWindow()
		local shouldOpen = not w:isOpen()
		ISVehiclePartMenu.onOpenCloseWindow(self.character, windowPart, shouldOpen)
	end
end

-- =========================================================
-- Instance management
-- =========================================================
function YourDashPassengerDashboard.get(playerNum)
	local inst = YourDashPassengerDashboard.instances[playerNum]
	if inst then return inst end

	local chr = getSpecificPlayer(playerNum)
	if not chr then return nil end

	local o = YourDashPassengerDashboard:new(playerNum, chr)
	o:initialise()
	o:instantiate()
	o:setVisible(false)

	YourDashPassengerDashboard.instances[playerNum] = o
	return o
end

-- =========================================================
-- Constructor
-- =========================================================
function YourDashPassengerDashboard:new(playerNum, chr)
    local o = ISPanel:new(0, 0, 10, 10)
    setmetatable(o, self)
    self.__index = self

    o.playerNum  = playerNum
    o.character  = chr
    o.vehicle    = nil

    o.backgroundColor = { r=0, g=0, b=0, a=0 }
    o.borderColor     = { r=0, g=0, b=0, a=0 }

    -- State
    o.__paxRetracted = false
    o.__paxChildrenCreated = false
    o.__paxLastBarH = nil

    o.__YourDashFamily = "standard"
    o.__YourDashAccent = "base"
    o:_paxApplyTexturePack(nil, true)

    return o
end


-- =========================================================
-- Layout helpers
-- =========================================================
function YourDashPassengerDashboard:_paxRelPos(ox, oy, btnW, btnH)
	local bgW = self.backgroundTex and self.backgroundTex:getWidth() or self.width
	local bgH = self.backgroundTex and self.backgroundTex:getHeight() or self.height

	local x = ox or 0
	local y = oy or 0

	if x < 0 then x = bgW + x - (btnW or 0) end
	if y < 0 then y = bgH + y - (btnH or 0) end

	return x, y
end

function YourDashPassengerDashboard:_paxGetBarHeight()
	-- Best-effort: hotbar height (B42 item bar)
	local h = 0

	if getPlayerHotbar then
		local hb = getPlayerHotbar(self.playerNum)
		if hb and (not hb.isVisible or hb:isVisible()) then
			h = (hb.getHeight and hb:getHeight()) or hb.height or 0
		end
	end

	if (not h) or h <= 0 then
		local layout = self:_paxGetLayout1x()
		h = paxScaled(layout.barFallback or 70, self.__YourDashScale or paxScale())
	end

	return h
end

-- The shared AC module reads driver-cluster layout data.  Passenger art has
-- different slots, so keep all proven AC commands/dragging behavior and only
-- override its positioning hook for this derived panel.
function YourDashPassengerDashboard:_YourDashEnsureACBackground(_texture)
    -- The standard and heavy passenger PNGs already contain their AC face.
    -- Avoid adding a duplicate opaque child above the fan/slider controls.
    if self.__YourDashACBackground then self.__YourDashACBackground:setVisible(false) end
end

function YourDashPassengerDashboard:_positionACControls()
    if not self.backgroundTex then return end
    if self._ensureACControls then pcall(function() self:_ensureACControls() end) end
    if (self.__YourDashFamily or "standard") == "sport" then return end

    local layout = self:_paxGetLayout1x()
    local ac = layout.ac or {}
    local scale = self.__YourDashScale or paxScale()
    local baseX = self.backgroundTex:getX()
    local baseY = self.backgroundTex:getY()

    if self.__YourDashACBackground then
        local background = ac.background
        if background then
            self.__YourDashACBackground:setX(baseX + paxScaled(background.x, scale))
            self.__YourDashACBackground:setY(baseY + paxScaled(background.y, scale))
        end
    end

    local slider = ac.slider
    if self.acTempSlider and slider then
        self.__acMinX = baseX + paxScaled(slider.x, scale)
        self.__acMaxX = self.__acMinX + paxScaled(slider.travel or 0, scale)
        self.__acY = baseY + paxScaled(slider.y, scale)
        if self._updateACTempSliderPos then self:_updateACTempSliderPos() end
    end

    local fan = ac.fan
    if self.heaterTex and fan then
        self.heaterTex:setX(baseX + paxScaled(fan.x, scale))
        self.heaterTex:setY(baseY + paxScaled(fan.y, scale))
    end
end

-- =========================================================
-- Sport passenger climate row, lock LED, and analog clock
-- =========================================================
local function paxMakeImage(parent, texture, opaque)
    if not texture then return nil end
    local image = ISImage:new(0, 0, texture:getWidthOrig(), texture:getHeightOrig(), texture)
    image:initialise()
    image:instantiate()
    image.backgroundColor = opaque and { r=1, g=1, b=1, a=1 } or { r=0, g=0, b=0, a=0 }
    parent:addChild(image)
    return image
end

function YourDashPassengerDashboard:_paxSetSportImage(image, texture, opaque)
    if not image or not texture then return end
    self:_setImageTextureAndSize(image, texture)
    if opaque then image.backgroundColor = { r=1, g=1, b=1, a=1 } end
end

function YourDashPassengerDashboard:onPaxSportFan()
    if ISVehicleDashboard.onYourDashSportFan then
        return ISVehicleDashboard.onYourDashSportFan(self)
    end
    -- Guarded fallback still uses the shared AC module's vanilla MP command.
    if self.onClickACFan then return self:onClickACFan() end
end

function YourDashPassengerDashboard:onPaxSportACDisplay()
    if ISVehicleDashboard.onYourDashSportACDisplay then
        return ISVehicleDashboard.onYourDashSportACDisplay(self)
    end
    self.__YourDashSportACMode = ((self.__YourDashSportACMode or 1) % 3) + 1
end

local function paxDrawFittedCentre(layer, text, rect, scale, maximumZoom)
    if not layer or not text or not rect then return end
    local font = YourDash.GetUIFont and YourDash.GetUIFont() or (UIFont and UIFont.Small)
    if not font then return end

    local x = paxScaled(rect.x, scale)
    local y = paxScaled(rect.y, scale)
    local width = paxScaled(rect.width, scale)
    local height = paxScaled(rect.height, scale)
    local opticalOffsetX = paxScaled(rect.textOffsetX or 0, scale)
    local fontHeight = YourDash.FontHeightForScale and YourDash.FontHeightForScale() or nil
    local textWidth = nil
    if getTextManager then
        local ok, manager = pcall(getTextManager)
        if ok and manager then
            fontHeight = fontHeight or paxSafeCall(manager, "getFontHeight", font)
            textWidth = paxSafeCall(manager, "MeasureStringX", font, text)
        end
    end
    fontHeight = tonumber(fontHeight) or height
    textWidth = tonumber(textWidth)

    if textWidth and textWidth > 0 and layer.drawTextZoomed then
        local zoom = math.min(maximumZoom or 1,
            math.max(1, width - 2) / textWidth,
            math.max(1, height - 1) / fontHeight)
        if zoom < 0.999 then
            layer:drawTextZoomed(text,
                x + (width - textWidth * zoom) / 2 + opticalOffsetX,
                y + (height - fontHeight * zoom) / 2,
                zoom, 0.10, 0.13, 0.04, 1, font)
            return
        end
    end
    layer:drawTextCentre(text, x + width / 2 + opticalOffsetX,
        y + (height - fontHeight) / 2, 0.10, 0.13, 0.04, 1, font)
end

local function paxDrawTwoLineACDisplay(layer, label, value, rect, scale)
    if not rect or not label or not value then return end
    local font = YourDash.GetUIFont and YourDash.GetUIFont() or (UIFont and UIFont.Small)
    local x = paxScaled(rect.x, scale)
    local y = paxScaled(rect.y, scale)
    local width = paxScaled(rect.width, scale)
    local height = paxScaled(rect.height, scale)
    local opticalOffsetX = paxScaled(rect.textOffsetX or 0, scale)
    local fontHeight = YourDash.FontHeightForScale and YourDash.FontHeightForScale() or nil
    local labelWidth, valueWidth = nil, nil
    if getTextManager and font then
        local ok, manager = pcall(getTextManager)
        if ok and manager then
            fontHeight = fontHeight or paxSafeCall(manager, "getFontHeight", font)
            labelWidth = paxSafeCall(manager, "MeasureStringX", font, label)
            valueWidth = paxSafeCall(manager, "MeasureStringX", font, value)
        end
    end
    fontHeight = tonumber(fontHeight)
    labelWidth, valueWidth = tonumber(labelWidth), tonumber(valueWidth)

    -- Match the driver's conservative fallback when text measurements are not
    -- available, while normal B42 clients use the larger packed rows below.
    if not fontHeight or fontHeight <= 0 or not labelWidth or labelWidth <= 0 or
            not valueWidth or valueWidth <= 0 then
        local rawHeight = tonumber(rect.height) or 0
        local labelHeight = math.max(1, math.floor(rawHeight * 0.35))
        local valueHeight = math.max(1, rawHeight - labelHeight)
        paxDrawFittedCentre(layer, label, {
            x = rect.x, y = rect.y, width = rect.width, height = labelHeight,
            textOffsetX = rect.textOffsetX,
        }, scale, 0.72)
        paxDrawFittedCentre(layer, value, {
            x = rect.x, y = (rect.y or 0) + labelHeight,
            width = rect.width, height = valueHeight,
            textOffsetX = rect.textOffsetX,
        }, scale, 1.0)
        return
    end

    local availableWidth = math.max(1, width - 2)
    local labelZoom = math.min(1.00, availableWidth / labelWidth)
    local valueZoom = math.min(1.25, availableWidth / valueWidth)
    local inkTop = fontHeight * 0.25
    local inkHeight = fontHeight * 0.56
    local gap = math.max(1, paxScaled(1, scale))
    local totalInkHeight = inkHeight * (labelZoom + valueZoom)
    local availableInkHeight = math.max(1, height - gap)
    if totalInkHeight > availableInkHeight then
        local fit = availableInkHeight / totalInkHeight
        labelZoom, valueZoom = labelZoom * fit, valueZoom * fit
        totalInkHeight = availableInkHeight
    end

    local packedHeight = totalInkHeight + gap
    local packedTop = y + (height - packedHeight) / 2
    local labelOriginY = packedTop - inkTop * labelZoom
    local valueInkTop = packedTop + inkHeight * labelZoom + gap
    local valueOriginY = valueInkTop - inkTop * valueZoom

    local function drawLine(text, textWidth, zoom, originY)
        if math.abs(zoom - 1) > 0.001 and layer.drawTextZoomed then
            layer:drawTextZoomed(text,
                x + (width - textWidth * zoom) / 2 + opticalOffsetX,
                originY, zoom, 0.10, 0.13, 0.04, 1, font)
            return
        end
        layer:drawTextCentre(text, x + width / 2 + opticalOffsetX, originY,
            0.10, 0.13, 0.04, 1, font)
    end

    drawLine(label, labelWidth, labelZoom, labelOriginY)
    drawLine(value, valueWidth, valueZoom, valueOriginY)
end

function YourDashPassengerDashboard:_paxDrawSportOverlay(layer)
    if self.__paxRetracted or (self.__YourDashFamily or "standard") ~= "sport" then return end
    local layout = self:_paxGetLayout1x()
    local scale = self.__YourDashScale or paxScale()

    local heater = self.vehicle and paxSafeCall(self.vehicle, "getHeater") or nil
    local data = heater and paxSafeCall(heater, "getModData") or nil
    if data and data.active == true and layout.ac and layout.ac.display then
        local drewRows = false
        if self._YourDashSportACRows then
            local ok, label, value = pcall(self._YourDashSportACRows, self)
            if ok and label and value then
                paxDrawTwoLineACDisplay(layer, label, value, layout.ac.display, scale)
                drewRows = true
            end
        end
        -- Compatibility for an older ZZZ module or a partially-loaded UI.
        if not drewRows and self._YourDashSportACText then
            local ok, text = pcall(self._YourDashSportACText, self)
            if ok and text then paxDrawFittedCentre(layer, text, layout.ac.display, scale) end
        end
    end

    local clockPoint = layout.clock
    local clockTexture = self.__paxSportClockTex
    if clockPoint and clockTexture then
        local x = paxScaled(clockPoint.x, scale)
        local y = paxScaled(clockPoint.y, scale)
        local width = clockTexture:getWidthOrig()
        local height = clockTexture:getHeightOrig()
        layer:drawTextureScaled(clockTexture, x, y, width, height, 1)

        local gameTime = nil
        if getGameTime then
            local ok, value = pcall(getGameTime)
            if ok then gameTime = value end
        end
        if not gameTime and GameTime and GameTime.getInstance then
            local ok, value = pcall(GameTime.getInstance)
            if ok then gameTime = value end
        end
        local hourValue = tonumber(gameTime and paxSafeCall(gameTime, "getHour"))
        local minute = tonumber(gameTime and paxSafeCall(gameTime, "getMinutes"))
        if hourValue == nil or minute == nil then
            local timeOfDay = tonumber(gameTime and paxSafeCall(gameTime, "getTimeOfDay")) or 0
            timeOfDay = timeOfDay % 24
            hourValue = math.floor(timeOfDay)
            minute = (timeOfDay % 1) * 60
        end
        local hour = (hourValue % 12) + minute / 60
        local pivotX, pivotY = x + width / 2, y + height / 2
        -- DrawTextureAngle's positive direction is clockwise in the dashboard UI.
        if self.__paxSportClockHourTex then
            layer:DrawTextureAngle(self.__paxSportClockHourTex, pivotX, pivotY, hour * 30)
        end
        if self.__paxSportClockMinuteTex then
            layer:DrawTextureAngle(self.__paxSportClockMinuteTex, pivotX, pivotY, minute * 6)
        end
    end
end

function YourDashPassengerDashboard:_paxEnsureSportExtras()
    if (self.__YourDashFamily or "standard") ~= "sport" then return end

    if not self.__paxSportACBackground and self.__paxSportACOff then
        self.__paxSportACBackground = paxMakeImage(self, self.__paxSportACOff, true)
        paxSetMouseTransparent(self.__paxSportACBackground)
    end
    self:_paxSetSportImage(self.__paxSportACBackground, self.__paxSportACOff, true)

    if not self.__paxSportFanButton and self.__paxSportFanButtonTex then
        local button = paxMakeImage(self, self.__paxSportFanButtonTex, false)
        button.target = self
        button.onclick = YourDashPassengerDashboard.onPaxSportFan
        self:_installPressedEffect(button, 0.96)
        self.__paxSportFanButton = button
    end
    self:_paxSetSportImage(self.__paxSportFanButton, self.__paxSportFanButtonTex, false)

    if not self.__paxSportACDisplayButton and self.__paxSportACDisplayButtonTex then
        local button = paxMakeImage(self, self.__paxSportACDisplayButtonTex, false)
        button.target = self
        button.onclick = YourDashPassengerDashboard.onPaxSportACDisplay
        button.mouseovertext = "Cycle climate display"
        self:_installPressedEffect(button, 0.96)
        self.__paxSportACDisplayButton = button
    end
    self:_paxSetSportImage(self.__paxSportACDisplayButton, self.__paxSportACDisplayButtonTex, false)

    if not self.__paxSportTempKnob and self.__paxSportTempKnobTex and self._YourDashSportCreateKnob then
        self.__paxSportTempKnob = self:_YourDashSportCreateKnob(self.__paxSportTempKnobTex)
    elseif self.__paxSportTempKnob and self.__paxSportTempKnobTex then
        self.__paxSportTempKnob.tex = self.__paxSportTempKnobTex
        self.__paxSportTempKnob:setWidth(self.__paxSportTempKnobTex:getWidthOrig())
        self.__paxSportTempKnob:setHeight(self.__paxSportTempKnobTex:getHeightOrig())
    end

    if not self.__paxSportDoorLED and self.__paxSportLEDOff then
        self.__paxSportDoorLED = paxMakeImage(self, self.__paxSportLEDOff, true)
        paxSetMouseTransparent(self.__paxSportDoorLED)
    end
    self:_paxSetSportImage(self.__paxSportDoorLED, self.__paxSportLEDOff, true)

    if not self.__paxSportOverlay then
        local overlay = ISPanel:new(0, 0, 1, 1)
        overlay:initialise()
        overlay:instantiate()
        overlay.backgroundColor = { r=0, g=0, b=0, a=0 }
        overlay.borderColor = { r=0, g=0, b=0, a=0 }
        overlay.target = self
        paxSetMouseTransparent(overlay)
        function overlay:prerender() end
        function overlay:render()
            if self.target then self.target:_paxDrawSportOverlay(self) end
        end
        self:addChild(overlay)
        self.__paxSportOverlay = overlay
    end
end

function YourDashPassengerDashboard:_paxPositionSportExtras()
    if not self.backgroundTex then return end
    if (self.__YourDashFamily or "standard") ~= "sport" then
        self:_paxHideSportExtras()
        return
    end
    self:_paxEnsureSportExtras()
    local layout = self:_paxGetLayout1x()
    local scale = self.__YourDashScale or paxScale()
    local ac = layout.ac or {}

    local function position(element, point)
        if not element or not point then return end
        element:setX(paxScaled(point.x, scale))
        element:setY(paxScaled(point.y, scale))
    end
    position(self.__paxSportACBackground, ac.background)
    position(self.__paxSportFanButton, ac.fan)
    position(self.__paxSportACDisplayButton, ac.displayButton)
    position(self.__paxSportTempKnob, ac.knob)
    position(self.__paxSportDoorLED, layout.doorLED)

    if self.__paxSportOverlay then
        self.__paxSportOverlay:setX(0)
        self.__paxSportOverlay:setY(0)
        self.__paxSportOverlay:setWidth(self.backgroundTex:getWidth())
        self.__paxSportOverlay:setHeight(self.backgroundTex:getHeight())
    end
end

function YourDashPassengerDashboard:_paxHideSportExtras()
    if self.__paxSportACBackground then self.__paxSportACBackground:setVisible(false) end
    if self.__paxSportFanButton then self.__paxSportFanButton:setVisible(false) end
    if self.__paxSportACDisplayButton then self.__paxSportACDisplayButton:setVisible(false) end
    if self.__paxSportTempKnob then self.__paxSportTempKnob:setVisible(false) end
    if self.__paxSportDoorLED then self.__paxSportDoorLED:setVisible(false) end
    if self.__paxSportOverlay then self.__paxSportOverlay:setVisible(false) end
end

function YourDashPassengerDashboard:_paxUpdateSportExtras(hasBatteryPower)
    local show = not self.__paxRetracted and (self.__YourDashFamily or "standard") == "sport"
    if not show then
        self:_paxHideSportExtras()
        return
    end
    self:_paxEnsureSportExtras()

    local heater = self.vehicle and paxSafeCall(self.vehicle, "getHeater") or nil
    local data = heater and paxSafeCall(heater, "getModData") or nil
    local active = data and data.active == true
    local rawTemperature = data and tonumber(data.temperature) or 0
    local backgroundTexture = active and self.__paxSportACOn or self.__paxSportACOff
    self:_paxSetSportImage(self.__paxSportACBackground, backgroundTexture, true)
    if self.__paxSportACBackground then self.__paxSportACBackground:setVisible(true) end

    local hasHeater = heater ~= nil
    local powered = self.vehicle and
        (paxSafeCall(self.vehicle, "isEngineRunning") == true or
         paxSafeCall(self.vehicle, "isKeysInIgnition") == true)

    if self.__paxSportFanButton then
        self.__paxSportFanButton:setVisible(hasHeater)
        self.__paxSportFanButton.__disabled = not powered
        self.__paxSportFanButton.target = self
        self.__paxSportFanButton.onclick = powered and YourDashPassengerDashboard.onPaxSportFan or nil
    end
    if self.__paxSportACDisplayButton then
        self.__paxSportACDisplayButton:setVisible(hasHeater)
        self.__paxSportACDisplayButton.__disabled = not hasHeater
        self.__paxSportACDisplayButton.target = self
        self.__paxSportACDisplayButton.onclick = hasHeater and YourDashPassengerDashboard.onPaxSportACDisplay or nil
    end
    if self.__paxSportTempKnob then
        self.__paxSportTempKnob:setVisible(hasHeater)
        self.__paxSportTempKnob.__disabled = not powered
        if hasHeater and not self.__paxSportTempKnob.dragging and self.__paxSportTempKnob.setKnobPosition then
            local index = paxNearestSportTempIndex(rawTemperature)
            self.__paxSportTempKnob:setKnobPosition(PAX_SPORT_AC_RAW_LEVELS[index])
        end
    end

    if self.__paxSportDoorLED then
        local ledTexture = self.__paxSportLEDOff
        if hasBatteryPower then
            if self.vehicle:areAllDoorsLocked() then
                ledTexture = self.__paxSportLEDOn
            elseif self.vehicle:isAnyDoorLocked() then
                ledTexture = self.__paxSportLEDPartial
            end
        end
        self:_paxSetSportImage(self.__paxSportDoorLED, ledTexture, true)
        self.__paxSportDoorLED:setVisible(true)
    end
    if self.__paxSportOverlay then self.__paxSportOverlay:setVisible(true) end
end

function YourDashPassengerDashboard:_paxApplyBGTexture()
	local tex = self.__paxRetracted and self.__pax_bg_retracted or self.__pax_bg_expanded
	if not tex or not self.backgroundTex then return end

	if self.backgroundTex.texture ~= tex then
		self.backgroundTex.texture = tex
	end

	self.backgroundTex:setWidth(tex:getWidthOrig())
	self.backgroundTex:setHeight(tex:getHeightOrig())
	self:setWidth(tex:getWidthOrig())
	self:setHeight(tex:getHeightOrig())
end

function YourDashPassengerDashboard:_paxRefreshToggleTexture()
    if not self.paxToggleBtn then return end

    local tex = self.__paxRetracted and self.__pax_btn_expand or self.__pax_btn_retract
    if tex then self:_paxSetToggleTexture(tex) end

    -- Hover text
    self.paxToggleBtn.mouseovertext =
        (self.__paxRetracted == true)
        and (self.PAX_TIP_EXPAND or "expand passenger dash")
        or  (self.PAX_TIP_RETRACT or "collaspe passenger dash")
end

function YourDashPassengerDashboard:_paxHideAllExpandedControls()
	-- Door / window
	if self.doorTex then self.doorTex:setVisible(false) end
	if self.windowTex then self.windowTex:setVisible(false) end

	-- AC
	if self.heaterTex then self.heaterTex:setVisible(false) end
	if self.acTempSlider then self.acTempSlider:setVisible(false) end
	if self.__YourDashACBackground then self.__YourDashACBackground:setVisible(false) end
	self.__acDragging = false
	self:_paxHideSportExtras()

	-- Radio (both UIs, router helpers if present)
	if self._yourDashHidePremiumRadioUI then pcall(function() self:_yourDashHidePremiumRadioUI() end) end
	if self._yourDashHideValueRadioUI   then pcall(function() self:_yourDashHideValueRadioUI() end) end

	-- Stop hold-repeat if user retracts mid-hold
	if self._radioValueStopFreqHold then pcall(function() self:_radioValueStopFreqHold() end) end
	if self._radioValueDisarmSet   then pcall(function() self:_radioValueDisarmSet() end) end
	if self._radioStopFreqHold     then pcall(function() self:_radioStopFreqHold() end) end
	if self._radioDisarmSet        then pcall(function() self:_radioDisarmSet() end) end
end

-- =========================================================
-- Toggle click
-- =========================================================
function YourDashPassengerDashboard:onClickPaxToggle()
	self.__paxRetracted = not (self.__paxRetracted == true)
	self:_paxApplyBGTexture()
	self:_paxRefreshToggleTexture()
	self:onResolutionChange()

	if self.__paxRetracted then
		self:_paxHideAllExpandedControls()
	end
end

-- =========================================================
-- UI build
-- =========================================================
function YourDashPassengerDashboard:createChildren()
	if self.__paxChildrenCreated then return end
	self.__paxChildrenCreated = true

	-- Background
	local bg = self.__pax_bg_expanded
	if not bg then return end

	self.backgroundTex = ISImage:new(0, 0, bg:getWidthOrig(), bg:getHeightOrig(), bg)

    self.backgroundTex.backgroundColor = { r=0, g=0, b=0, a=0 }
    self.backgroundTex.alpha = 1

    function self.backgroundTex:render()
        if not self.texture then return end
        self:drawTextureScaled(self.texture, 0, 0, self.width, self.height, self.alpha or 1)
    end

	self.backgroundTex:initialise()
	self.backgroundTex:instantiate()
	self.backgroundTex.backgroundColor = { r=0, g=0, b=0, a=0 }
	self:addChild(self.backgroundTex)

	self:setWidth(bg:getWidthOrig())
	self:setHeight(bg:getHeightOrig())

	-- Toggle button (always visible)
	if self.__pax_btn_retract or self.__pax_btn_expand then
		local ttex = self.__pax_btn_retract or self.__pax_btn_expand
		self.paxToggleBtn = ISImage:new(0, 0, ttex:getWidthOrig(), ttex:getHeightOrig(), ttex)
		self.paxToggleBtn:initialise()
		self.paxToggleBtn:instantiate()
		self.paxToggleBtn.target = self
		self.paxToggleBtn.onclick = YourDashPassengerDashboard.onClickPaxToggle
		self.paxToggleBtn.backgroundColor = { r=0, g=0, b=0, a=0 }
		self:addChild(self.paxToggleBtn)
		self:_installPressedEffect(self.paxToggleBtn, 0.96)
	end

	-- Door lock button (reuse lock textures + onClickDoors)
	if self.__lock_off then
		self.doorTex = ISImage:new(0, 0, self.__lock_off:getWidthOrig(), self.__lock_off:getHeightOrig(), self.__lock_off)
		self.doorTex:initialise()
		self.doorTex:instantiate()
		self.doorTex.backgroundColor = { r=0, g=0, b=0, a=0 }
		self:addChild(self.doorTex)

		self:_setImageEnabled(self.doorTex, true, getText("Tooltip_Dashboard_LockedDoors"), ISVehicleDashboard.onClickDoors, self)
		self:_installPressedEffect(self.doorTex, self.__YourDashFamily == "heavy" and 1.0 or 0.96)
	end

	-- Window button (reuse your window logic + textures)
	if self.__window_switch then
		self.windowTex = ISImage:new(0, 0, self.__window_switch:getWidthOrig(), self.__window_switch:getHeightOrig(), self.__window_switch)
		self.windowTex:initialise()
		self.windowTex:instantiate()
		self.windowTex.backgroundColor = { r=0, g=0, b=0, a=0 }
		self.windowTex.target = self
		self.windowTex.onclick = ISVehicleDashboard.onClickWindow
		self:addChild(self.windowTex)

		self:_installPressedEffect(self.windowTex, 1.0)

		-- Heavy/sport switches use their upper and lower halves as explicit
		-- close/open commands.  Standard keeps the proven toggle behaviour.
		local _down = self.windowTex.onMouseDown
		function self.windowTex:onMouseDown(x, y)
			if self.__disabled then return false end
			self.__pressed = true

			local dash = self.target
			local wp = dash and dash:_getSeatWindowPart() or nil
			local family = dash and (dash.__YourDashFamily or "standard") or "standard"
			local directional = family == "heavy" or family == "sport"
			if dash then dash.__YourDashWindowCommand = nil end
			if wp and directional then
				local state = y < (self.height * 0.5) and "up" or "down"
				dash.__YourDashWindowCommand = state
				local stateTexture = state == "up" and dash.__window_switch_pull or dash.__window_switch_push
				dash:_setImageTextureAndSize(self, stateTexture or dash.__window_switch)
			elseif wp then
				local w = wp:getWindow()
				if w and w:isOpen() then
					dash:_setImageTextureAndSize(self, dash.__window_switch_pull or dash.__window_switch)
				else
					dash:_setImageTextureAndSize(self, dash.__window_switch_push or dash.__window_switch)
				end
			else
				dash:_setImageTextureAndSize(self, dash.__window_switch)
			end

			if _down then return _down(self, x, y) end
			return true
		end

		local _up = self.windowTex.onMouseUp
		function self.windowTex:onMouseUp(x, y)
			self.__pressed = false
			local dash = self.target
			if dash and dash.__window_switch then
				dash:_setImageTextureAndSize(self, dash.__window_switch)
			end
			if self.__disabled then
				if dash then dash.__YourDashWindowCommand = nil end
				return false
			end
			local result = true
			if _up then result = _up(self, x, y) end
			if dash then dash.__YourDashWindowCommand = nil end
			return result
		end

		local _upOut = self.windowTex.onMouseUpOutside
		function self.windowTex:onMouseUpOutside(x, y)
			self.__pressed = false
			local dash = self.target
			if dash and dash.__window_switch then
				dash:_setImageTextureAndSize(self, dash.__window_switch)
			end
			if dash then dash.__YourDashWindowCommand = nil end
			if _upOut then return _upOut(self, x, y) end
			return true
		end
	end

	-- AC: create a heaterTex slot so your AC patch can reuse it
	self.heaterTex = ISImage:new(0, 0, 1, 1, nil)
	self.heaterTex:initialise()
	self.heaterTex:instantiate()
	self.heaterTex.backgroundColor = { r=0, g=0, b=0, a=0 }
	self:addChild(self.heaterTex)

	-- Let your AC patch build slider + set fan button visuals
	if self._ensureACControls then pcall(function() self:_ensureACControls() end) end

	-- Let your radio scripts build both UIs (router will choose at runtime)
	if self._ensureRadioControls then pcall(function() self:_ensureRadioControls() end) end
	if self._ensureValueRadioControls then pcall(function() self:_ensureValueRadioControls() end) end
	self:_paxEnsureSportExtras()

	self:_paxApplyBGTexture()
	self:_paxRefreshToggleTexture()
	self:onResolutionChange()

	-- Start expanded: ensure expanded controls are visible (they'll still self-hide if parts missing)
	if self.__paxRetracted then
		self:_paxHideAllExpandedControls()
	end
end

-- =========================================================
-- Set vehicle (show/hide + UI manager)
-- =========================================================
function YourDashPassengerDashboard:setVehicle(vehicle)
	local previousVehicle = self.vehicle
	self.vehicle = vehicle
	if previousVehicle ~= vehicle and self._yourDashResetRadioTransientState then
		self:_yourDashResetRadioTransientState()
	end
	if previousVehicle ~= vehicle then self.__YourDashSportACMode = 1 end

	if not vehicle then
		self:setVisible(false)
		if self.removeFromUIManager then self:removeFromUIManager() end
		return
	end

	local profile = YourDash.GetVehicleProfile and YourDash.GetVehicleProfile(vehicle, true) or nil
	self:_paxApplyTexturePack(profile, false)

	self:setVisible(true)
	if self.addToUIManager then self:addToUIManager() end
	self:onResolutionChange()
end

-- =========================================================
-- Positioning (above hotbar)
-- =========================================================
function YourDashPassengerDashboard:onResolutionChange()
	if not self.backgroundTex then return end

    local layout = self:_paxGetLayout1x()
    local scale = self.__YourDashScale or paxScale()
    local OFFX = paxScaled(self.PAX_OFFSET_X or 0, scale)
    local OFFY = paxScaled(self.PAX_OFFSET_Y or 0, scale)
    local PAD = paxScaled(layout.barPad or 10, scale)

	local screenLeft   = getPlayerScreenLeft(self.playerNum)
	local screenTop    = getPlayerScreenTop(self.playerNum)
	local screenWidth  = getPlayerScreenWidth(self.playerNum)
	local screenHeight = getPlayerScreenHeight(self.playerNum)

	self:setWidth(self.backgroundTex:getWidth())
	self:setHeight(self.backgroundTex:getHeight())

	local barH = self:_paxGetBarHeight()
    local pad  = PAD or 0

    local x = screenLeft + (screenWidth - self.width) / 2 + (OFFX or 0)
    local y = screenTop + screenHeight - self.height - barH - pad + (OFFY or 0)

    local toggle = layout.toggle or {}
    local door = layout.door or {}
    local window = layout.window or {}
    local TX, TY = paxScaled(toggle.x, scale), paxScaled(toggle.y, scale)
    local DX, DY = paxScaled(door.x, scale), paxScaled(door.y, scale)
    local WX, WY = paxScaled(window.x, scale), paxScaled(window.y, scale)

	self:setX(x)
	self:setY(y)

	-- background local origin
	self.backgroundTex:setX(0)
	self.backgroundTex:setY(0)

	-- Toggle button
    if self.paxToggleBtn then
        local bx, by = self:_paxRelPos(TX or 0, TY or 0, self.paxToggleBtn:getWidth(), self.paxToggleBtn:getHeight())
        self.paxToggleBtn:setX(bx)
        self.paxToggleBtn:setY(by)
    end

    if self.doorTex then
        local bx, by = self:_paxRelPos(DX or 0, DY or 0, self.doorTex:getWidth(), self.doorTex:getHeight())
        self.doorTex:setX(bx)
        self.doorTex:setY(by)
    end

    if self.windowTex then
        local bx, by = self:_paxRelPos(WX or 0, WY or 0, self.windowTex:getWidth(), self.windowTex:getHeight())
        self.windowTex:setX(bx)
        self.windowTex:setY(by)
    end

	-- Passenger-family AC positions.
	if self._positionACControls then pcall(function() self:_positionACControls() end) end
	self:_paxPositionSportExtras()

	-- Radio positions (both; router chooses which is visible)
	if self._positionRadioControls then pcall(function() self:_positionRadioControls() end) end
	if self._positionValueRadioControls then pcall(function() self:_positionValueRadioControls() end) end
end

-- =========================================================
-- Update each frame (simple + reliable)
-- =========================================================
function YourDashPassengerDashboard:prerender()
	if not self.vehicle or not ISUIHandler.allUIVisible then return end

	-- Family/accent and all four texture packs hot-swap in place.
	local profile = YourDash.GetVehicleProfile and YourDash.GetVehicleProfile(self.vehicle) or nil
	local family = profile and profile.family or "standard"
	local accent = profile and profile.accent or "base"
	if family ~= "sport" then accent = "base" end
	local wantedPack = family .. ":" .. accent .. ":" .. paxScaleKey()
	if self.__paxPackKey ~= wantedPack then self:_paxApplyTexturePack(profile, false) end


	-- Auto-hide if seat changed (extra safety for instant seat swaps)
	local chr = self.character
	local v = chr and chr:getVehicle() or nil
	if v ~= self.vehicle then
		self:setVehicle(nil)
		return
	end

	local seat = (self.vehicle.getSeat and self.vehicle:getSeat(chr)) or -1
	if seat ~= (self.PAX_SEAT_INDEX or 1) then
		self:setVehicle(nil)
		return
	end

	-- Hotbar height can change (rare): reposition if it does
	local barH = self:_paxGetBarHeight()
	if self.__paxLastBarH ~= barH then
		self.__paxLastBarH = barH
		self:onResolutionChange()
	end

	self:_paxRefreshToggleTexture()

	-- Retracted: show only background + toggle
	if self.__paxRetracted then
		self:_paxHideAllExpandedControls()
		return
	end

	-- Expanded controls: update visibility/state
	local hasPower = self:_hasBatteryPower()

	-- Door icon texture (reuse your driver logic: freeze to off when no power)
	if self.doorTex and self.__lock_off then
		local doorTexture = self.__lock_off
		if hasPower then
			if self.vehicle:areAllDoorsLocked() then
				doorTexture = self.__lock_on
			elseif self.vehicle:isAnyDoorLocked() then
				doorTexture = self.__lock_partial
			end
		end
		if doorTexture and self.doorTex.texture ~= doorTexture then
			-- Heavy ON/OFF exports differ by one pixel in height; retain the
			-- authored state geometry instead of stretching either texture.
			self:_setImageTextureAndSize(self.doorTex, doorTexture)
		end
		self.doorTex.backgroundColor = { r=0, g=0, b=0, a=0 }
		self.doorTex:setVisible(true)
	end

	-- Window button: only if window exists for this seat
	if self.windowTex then
		local windowPart = self:_getSeatWindowPart()
		if not windowPart then
			self.windowTex:setVisible(false)
			self.windowTex.__disabled = true
			self.windowTex.onclick = nil
			self.windowTex.mouseovertext = nil
		else
			self.windowTex:setVisible(true)
			self.windowTex.__disabled = false
			self.windowTex.onclick = ISVehicleDashboard.onClickWindow
			self.windowTex.target = self

			local w = windowPart:getWindow()
			if w and w:isOpen() then
				self.windowTex.mouseovertext = getText("ContextMenu_Close_window")
			else
				self.windowTex.mouseovertext = getText("ContextMenu_Open_window")
			end
		end

		-- return to neutral texture when not pressed
		if (not self.windowTex.__pressed) and self.__window_switch then
			if self.windowTex.texture ~= self.__window_switch then
				self:_setImageTextureAndSize(self.windowTex, self.__window_switch)
			end
		end
	end

	-- AC update (your AC patch handles heater existence + key/engine gating)
	if self._updateACControls then pcall(function() self:_updateACControls() end) end
	self:_paxUpdateSportExtras(hasPower)

	-- Radio update via router (premium/value/none)
	if self._yourDashUpdateRoutedRadio then
		pcall(function() self:_yourDashUpdateRoutedRadio() end)
	else
		-- fallback if router isn't present for any reason
		if self._updateRadioControls then pcall(function() self:_updateRadioControls() end) end
		if self._updateValueRadioControls then pcall(function() self:_updateValueRadioControls() end) end
	end
end

-- IMPORTANT:
-- We do NOT want your driver-dashboard needle render() on this passenger panel.
-- So render as a plain panel (children render normally).
function YourDashPassengerDashboard:render()
	ISPanel.render(self)
end

-- =========================================================
-- Event hooks
-- =========================================================
function YourDashPassengerDashboard._shouldShowFor(character)
	if not character then return false end
	if not instanceof(character, "IsoPlayer") then return false end
	if not character:isLocalPlayer() then return false end

	local v = character:getVehicle()
	if not v then return false end

	local seat = (v.getSeat and v:getSeat(character)) or -1
	return seat == (YourDashPassengerDashboard.PAX_SEAT_INDEX or 1)
end

function YourDashPassengerDashboard.onEnterVehicle(character)
	if not YourDashPassengerDashboard._shouldShowFor(character) then return end
	local pn = character:getPlayerNum()
	local dash = YourDashPassengerDashboard.get(pn)
	if dash then dash:setVehicle(character:getVehicle()) end
end

function YourDashPassengerDashboard.onExitVehicle(character)
	if not instanceof(character, "IsoPlayer") or not character:isLocalPlayer() then return end
	local pn = character:getPlayerNum()
	local dash = YourDashPassengerDashboard.get(pn)
	if dash then dash:setVehicle(nil) end
end

function YourDashPassengerDashboard.onSwitchVehicleSeat(character)
	if not instanceof(character, "IsoPlayer") or not character:isLocalPlayer() then return end
	local pn = character:getPlayerNum()
	local dash = YourDashPassengerDashboard.get(pn)
	if not dash then return end

	if YourDashPassengerDashboard._shouldShowFor(character) then
		dash:setVehicle(character:getVehicle())
	else
		dash:setVehicle(nil)
	end
end

function YourDashPassengerDashboard.onGameStart()
	if isServer() then return end
	for i = 1, getNumActivePlayers() do
		local pl = getSpecificPlayer(i-1)
		if pl and not pl:isDead() and pl:getVehicle() then
			if YourDashPassengerDashboard._shouldShowFor(pl) then
				local dash = YourDashPassengerDashboard.get(pl:getPlayerNum())
				if dash then dash:setVehicle(pl:getVehicle()) end
			end
		end
	end
end

Events.OnEnterVehicle.Add(YourDashPassengerDashboard.onEnterVehicle)
Events.OnExitVehicle.Add(YourDashPassengerDashboard.onExitVehicle)
Events.OnSwitchVehicleSeat.Add(YourDashPassengerDashboard.onSwitchVehicleSeat)
Events.OnGameStart.Add(YourDashPassengerDashboard.onGameStart)
