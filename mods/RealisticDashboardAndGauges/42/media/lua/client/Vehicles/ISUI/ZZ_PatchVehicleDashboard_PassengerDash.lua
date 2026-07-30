-- media/lua/client/YourDash/Z_PatchVehicleDashboard_Passenger.lua
if isServer() then return end

require "ISUI/ISPanel"
require "ISUI/ISImage"
require "Vehicles/ISUI/ISVehicleDashboard"
require "Vehicles/ISUI/ISVehiclePartMenu"
require "Vehicles/VehicleUtils"

-- Ensure AC functions exist (guard in that file prevents double-patch)
pcall(function() require "YourDash/Z_PatchVehicleDashboard_AC" end)

-- Guard: don’t load twice
if ISVehicleDashboard.__YourDashPassengerDashLoaded then return end
ISVehicleDashboard.__YourDashPassengerDashLoaded = true

-- =========================================================
-- Passenger dash panel (separate UI, reuses ISVehicleDashboard helpers)
-- =========================================================
YourDashPassengerDashboard = ISVehicleDashboard:derive("YourDashPassengerDashboard")
YourDashPassengerDashboard.instances = YourDashPassengerDashboard.instances or {}

-- =========================
-- Config (tune these)
-- =========================

-- Background textures
YourDashPassengerDashboard.PAX_BG_EXPANDED   = "media/ui/vehicles/passenger/passenger_dash.png"
YourDashPassengerDashboard.PAX_BG_RETRACTED  = "media/ui/vehicles/passenger/passenger_retracted.png"

-- Toggle button textures
YourDashPassengerDashboard.PAX_BTN_RETRACT   = "media/ui/vehicles/passenger/btn_retract.png"
YourDashPassengerDashboard.PAX_BTN_EXPAND    = "media/ui/vehicles/passenger/btn_expand.png"

-- Seat policy: show ONLY for seat index 1 by default (front passenger)
YourDashPassengerDashboard.PAX_SEAT_INDEX = 1

-- Positioning
YourDashPassengerDashboard.PAX_OFFSET_X = 0      -- +right / -left
YourDashPassengerDashboard.PAX_OFFSET_Y = 0      -- +down / -up (after bar offset)
YourDashPassengerDashboard.PAX_BAR_PAD   = 10    -- extra pixels above the item/hotbar
YourDashPassengerDashboard.PAX_BAR_FALLBACK_H = 70 -- used if we can't detect bar height

-- Toggle button placement (relative to background local coords)
-- Supports negative: -10 means "10px from right/bottom edge"
YourDashPassengerDashboard.PAX_TOGGLE_X = 22
YourDashPassengerDashboard.PAX_TOGGLE_Y = 18

-- Door + window buttons placement (relative to background local coords)
YourDashPassengerDashboard.PAX_DOOR_X   = 214
YourDashPassengerDashboard.PAX_DOOR_Y   = 98
YourDashPassengerDashboard.PAX_WINDOW_X = 244
YourDashPassengerDashboard.PAX_WINDOW_Y = 89

-- Passenger-specific AC placement (instance fields override global defaults)
YourDashPassengerDashboard.PAX_AC_FAN_X         = 24
YourDashPassengerDashboard.PAX_AC_FAN_Y         = 98
YourDashPassengerDashboard.PAX_AC_SLIDER_X      = 57
YourDashPassengerDashboard.PAX_AC_SLIDER_Y      = 105
YourDashPassengerDashboard.PAX_AC_SLIDER_TRAVEL = 127

-- Passenger-specific radio placement (instance fields override global defaults)
-- Premium radio uses RADIO_UI_X/Y; Value radio uses RADIO_VALUE_UI_X/Y
YourDashPassengerDashboard.PAX_RADIO_UI_X       = 10
YourDashPassengerDashboard.PAX_RADIO_UI_Y       = 35
YourDashPassengerDashboard.PAX_RADIO_VALUE_UI_X = 50
YourDashPassengerDashboard.PAX_RADIO_VALUE_UI_Y = 30

YourDashPassengerDashboard.PAX_TIP_RETRACT = "collapse passenger dash"
YourDashPassengerDashboard.PAX_TIP_EXPAND  = "expand passenger dash"


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

	-- Textures
	o.__pax_bg_expanded  = getTexture(self.PAX_BG_EXPANDED)
	o.__pax_bg_retracted = getTexture(self.PAX_BG_RETRACTED) or o.__pax_bg_expanded

	o.__pax_btn_retract  = getTexture(self.PAX_BTN_RETRACT)
	o.__pax_btn_expand   = getTexture(self.PAX_BTN_EXPAND) or o.__pax_btn_retract

	-- Reuse textures (same as driver dash)
	o.__lock_off     = getTexture("media/ui/vehicles/lock_off.png")
	o.__lock_partial = getTexture("media/ui/vehicles/lock_partial.png") or o.__lock_off
	o.__lock_on      = getTexture("media/ui/vehicles/lock_on.png")      or o.__lock_off

	o.__window_switch      = getTexture("media/ui/vehicles/window_switch.png")
	o.__window_switch_push = getTexture("media/ui/vehicles/window_switch_push.png") or o.__window_switch
	o.__window_switch_pull = getTexture("media/ui/vehicles/window_switch_pull.png") or o.__window_switch

	-- State
	o.__paxRetracted = false

	-- Instance overrides for AC/radio positioning (do NOT affect driver dash)
	o.AC_FAN_X         = self.PAX_AC_FAN_X
	o.AC_FAN_Y         = self.PAX_AC_FAN_Y
	o.AC_SLIDER_X      = self.PAX_AC_SLIDER_X
	o.AC_SLIDER_Y      = self.PAX_AC_SLIDER_Y
	o.AC_SLIDER_TRAVEL = self.PAX_AC_SLIDER_TRAVEL

	o.RADIO_UI_X        = self.PAX_RADIO_UI_X
	o.RADIO_UI_Y        = self.PAX_RADIO_UI_Y
	o.RADIO_VALUE_UI_X  = self.PAX_RADIO_VALUE_UI_X
	o.RADIO_VALUE_UI_Y  = self.PAX_RADIO_VALUE_UI_Y

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
		h = self.PAX_BAR_FALLBACK_H or 0
	end

	return h
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
    if tex and self.paxToggleBtn.texture ~= tex then
        self:_setImageTextureAndSize(self.paxToggleBtn, tex)
    end

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
	self.__acDragging = false

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
		self:_installPressedEffect(self.doorTex, 0.96)
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

		-- Press shows push/pull depending on current state (same as your driver dash)
		local _down = self.windowTex.onMouseDown
		function self.windowTex:onMouseDown(x, y)
			if self.__disabled then return false end
			self.__pressed = true

			local dash = self.target
			local wp = dash and dash:_getSeatWindowPart() or nil
			if wp then
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
			if self.__disabled then return false end
			if _up then return _up(self, x, y) end
			return true
		end

		local _upOut = self.windowTex.onMouseUpOutside
		function self.windowTex:onMouseUpOutside(x, y)
			self.__pressed = false
			local dash = self.target
			if dash and dash.__window_switch then
				dash:_setImageTextureAndSize(self, dash.__window_switch)
			end
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
	self.vehicle = vehicle

	if not vehicle then
		self:setVisible(false)
		if self.removeFromUIManager then self:removeFromUIManager() end
		return
	end

	self:setVisible(true)
	if self.addToUIManager then self:addToUIManager() end
	self:onResolutionChange()
end

-- =========================================================
-- Positioning (above hotbar)
-- =========================================================
function YourDashPassengerDashboard:onResolutionChange()
	if not self.backgroundTex then return end

	local screenLeft   = getPlayerScreenLeft(self.playerNum)
	local screenTop    = getPlayerScreenTop(self.playerNum)
	local screenWidth  = getPlayerScreenWidth(self.playerNum)
	local screenHeight = getPlayerScreenHeight(self.playerNum)

	self:setWidth(self.backgroundTex:getWidth())
	self:setHeight(self.backgroundTex:getHeight())

	local barH = self:_paxGetBarHeight()
	local pad  = self.PAX_BAR_PAD or 0

	local x = screenLeft + (screenWidth - self.width) / 2 + (self.PAX_OFFSET_X or 0)
	local y = screenTop + screenHeight - self.height - barH - pad + (self.PAX_OFFSET_Y or 0)

	self:setX(x)
	self:setY(y)

	-- background local origin
	self.backgroundTex:setX(0)
	self.backgroundTex:setY(0)

	-- Toggle button
	if self.paxToggleBtn then
		local bx, by = self:_paxRelPos(self.PAX_TOGGLE_X or 0, self.PAX_TOGGLE_Y or 0, self.paxToggleBtn:getWidth(), self.paxToggleBtn:getHeight())
		self.paxToggleBtn:setX(bx)
		self.paxToggleBtn:setY(by)
	end

	-- Door / window
	if self.doorTex then
		local bx, by = self:_paxRelPos(self.PAX_DOOR_X or 0, self.PAX_DOOR_Y or 0, self.doorTex:getWidth(), self.doorTex:getHeight())
		self.doorTex:setX(bx)
		self.doorTex:setY(by)
	end
	if self.windowTex then
		local bx, by = self:_paxRelPos(self.PAX_WINDOW_X or 0, self.PAX_WINDOW_Y or 0, self.windowTex:getWidth(), self.windowTex:getHeight())
		self.windowTex:setX(bx)
		self.windowTex:setY(by)
	end

	-- AC positions (uses instance overrides AC_* we set in new())
	if self._positionACControls then pcall(function() self:_positionACControls() end) end

	-- Radio positions (both; router chooses which is visible)
	if self._positionRadioControls then pcall(function() self:_positionRadioControls() end) end
	if self._positionValueRadioControls then pcall(function() self:_positionValueRadioControls() end) end
end

-- =========================================================
-- Update each frame (simple + reliable)
-- =========================================================
function YourDashPassengerDashboard:prerender()
	if not self.vehicle or not ISUIHandler.allUIVisible then return end

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
		if hasPower then
			if self.vehicle:areAllDoorsLocked() then
				self.doorTex.texture = self.__lock_on
			elseif self.vehicle:isAnyDoorLocked() then
				self.doorTex.texture = self.__lock_partial
			else
				self.doorTex.texture = self.__lock_off
			end
		else
			self.doorTex.texture = self.__lock_off
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
