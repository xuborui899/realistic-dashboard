-- media/lua/client/YourDash/Z_PatchVehicleDashboard_AC.lua
if isServer() then return end

require "Vehicles/ISUI/ISVehicleDashboard"
require "ISUI/ISImage"
require "ISUI/ISPanel"

-- Guard: don’t patch twice
if ISVehicleDashboard.__DashACPatched then return end
ISVehicleDashboard.__DashACPatched = true

-- =========================
-- Config (tune these)
-- =========================
ISVehicleDashboard.AC_TEMP_LEVELS   = ISVehicleDashboard.AC_TEMP_LEVELS   or { -25, -15, -8, 0, 8, 15, 25 }
ISVehicleDashboard.AC_SLIDER_X      = ISVehicleDashboard.AC_SLIDER_X      or 683
ISVehicleDashboard.AC_SLIDER_Y      = ISVehicleDashboard.AC_SLIDER_Y      or 132
ISVehicleDashboard.AC_SLIDER_TRAVEL = ISVehicleDashboard.AC_SLIDER_TRAVEL or 127
ISVehicleDashboard.AC_FAN_X         = ISVehicleDashboard.AC_FAN_X         or 653
ISVehicleDashboard.AC_FAN_Y         = ISVehicleDashboard.AC_FAN_Y         or 125

-- 2x ("large") offsets (RAW numbers, easy to tune later)
ISVehicleDashboard.AC_SLIDER_X_LARGE      = ISVehicleDashboard.AC_SLIDER_X_LARGE      or 1366
ISVehicleDashboard.AC_SLIDER_Y_LARGE      = ISVehicleDashboard.AC_SLIDER_Y_LARGE      or 264
ISVehicleDashboard.AC_SLIDER_TRAVEL_LARGE = ISVehicleDashboard.AC_SLIDER_TRAVEL_LARGE or 254
ISVehicleDashboard.AC_FAN_X_LARGE         = ISVehicleDashboard.AC_FAN_X_LARGE         or 1307
ISVehicleDashboard.AC_FAN_Y_LARGE         = ISVehicleDashboard.AC_FAN_Y_LARGE         or 249

-- =========================
-- Helpers
-- =========================
local function clamp(v, a, b)
    if v < a then return a end
    if v > b then return b end
    return v
end
local function _ydWantLarge()
    return (YourDash and YourDash.UseLargeTextures and YourDash.UseLargeTextures()) == true
end

local function _ydToLargePath(path)
    if YourDash and YourDash._toLargePath then
        return YourDash._toLargePath(path)
    end
    if not path then return nil end
    if string.find(path, "/large/", 1, true) then return path end
    return (string.gsub(path, "(.*/)([^/]+)$", "%1large/%2"))
end

-- returns (tex, usedLargeFile)
local function _ydGetTexWithFlag(path, wantLarge)
    if wantLarge then
        local lp = _ydToLargePath(path)
        local t = lp and getTexture(lp) or nil
        if t then return t, true end
    end
    local t = getTexture(path)
    return t, false
end

local function _ydScaleIfFallback(wantLarge, usedLargeFile)
    -- If Large pack selected but we fell back to regular file, auto scale 2x
    if wantLarge and (usedLargeFile ~= true) then return 2 end
    return 1
end

local function nearestIndex(levels, value)
    local bestI, bestD = 1, math.huge
    for i = 1, #levels do
        local d = math.abs((value or 0) - levels[i])
        if d < bestD then
            bestD = d
            bestI = i
        end
    end
    return bestI
end

local function setImageTextureAndSize(dash, img, tex, scale)
    if not img or not tex then return end
    local s = scale or 1

    -- If we don't need scaling, prefer your dashboard helper (keeps behavior consistent)
    if dash and dash._setImageTextureAndSize and (s == 1) then
        dash:_setImageTextureAndSize(img, tex)
        return
    end

    img.texture = tex

    local w = tex.getWidthOrig and tex:getWidthOrig() or img.width
    local h = tex.getHeightOrig and tex:getHeightOrig() or img.height
    if img.setWidth and w then img:setWidth(w * s) end
    if img.setHeight and h then img:setHeight(h * s) end
end


local function installPressedEffectFallback(img, pressedScale)
    if not img or img.__pressedEffectInstalled then return end
    img.__pressedEffectInstalled = true
    img.__pressedScale = pressedScale or 0.96
    img.__pressed = false
    img.__disabled = img.__disabled or false

    local function resetPressed(self) self.__pressed = false end

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

-- =========================
-- Heater access + sender
-- =========================
function ISVehicleDashboard:_getHeaterPart()
    if not self.vehicle then return nil end
    local heater = self.vehicle:getHeater()
    if not heater then return nil end
    local md = heater:getModData()
    if md.temperature == nil then md.temperature = 0 end
    if md.active == nil then md.active = false end
    return heater
end

function ISVehicleDashboard:_sendHeaterCommand(on, temp)
    if not self.character then return end
    sendClientCommand(self.character, "vehicle", "toggleHeater", { on = (on == true), temp = temp or 0 })
end

-- =========================
-- Fan button click
-- =========================
function ISVehicleDashboard:onClickACFan()
    if getGameSpeed() == 0 then return end
    if getGameSpeed() > 1 then setGameSpeed(1) end
    if not self.vehicle or not self.character then return end

    local heater = self:_getHeaterPart()
    if not heater then return end

    -- Match vanilla : OK is disabled without engine/keys
    if not (self.vehicle:isEngineRunning() or self.vehicle:isKeysInIgnition()) then
        return
    end

    local md = heater:getModData()
    md.active = not (md.active == true)

    self:_sendHeaterCommand(md.active, md.temperature)
    self.character:playSound("VehicleACButton")
end

-- =========================
-- Slider logic
-- =========================
function ISVehicleDashboard:_updateACTempSliderPos()
    if not self.acTempSlider then return end
    if not self.__acMinX or not self.__acMaxX or not self.__acY then return end

    local levels = self.AC_TEMP_LEVELS or {}
    local n = #levels
    if n <= 1 then
        self.acTempSlider:setX(self.__acMinX)
        self.acTempSlider:setY(self.__acY)
        return
    end

    local idx = clamp(self.__acTempIndex or 1, 1, n)
    local t = (idx - 1) / (n - 1)
    local x = self.__acMinX + (self.__acMaxX - self.__acMinX) * t

    self.acTempSlider:setX(x)
    self.acTempSlider:setY(self.__acY)
end

function ISVehicleDashboard:_setACTempIndex(idx, doSend)
    local levels = self.AC_TEMP_LEVELS or {}
    local n = #levels
    if n == 0 then return end

    idx = clamp(idx, 1, n)

    local prev = self.__acTempIndex
    if prev == idx and not doSend then
        self:_updateACTempSliderPos()
        return
    end

    self.__acTempIndex = idx
    self:_updateACTempSliderPos()

    if doSend and prev ~= idx then
        local heater = self:_getHeaterPart()
        if not heater then return end
        local md = heater:getModData()
        md.temperature = levels[idx]
        self:_sendHeaterCommand(md.active == true, md.temperature)
        if self.character then self.character:playSound("VehicleACSetTemperature") end
    end
end

function ISVehicleDashboard:_setACTempFromPointerX(pointerX, doSend)
    if not self.acTempSlider then return end
    if not self.__acMinX or not self.__acMaxX then return end

    local levels = self.AC_TEMP_LEVELS or {}
    local n = #levels
    if n <= 1 then return end

    local knobW = self.acTempSlider:getWidth()
    local minC = self.__acMinX + knobW * 0.5
    local maxC = self.__acMaxX + knobW * 0.5
    local denom = (maxC - minC)
    if denom == 0 then return end

    local t = (pointerX - minC) / denom
    t = clamp(t, 0, 1)

    local idx = math.floor(t * (n - 1) + 0.5) + 1
    self:_setACTempIndex(idx, doSend)
end

-- =========================
-- Build UI
-- =========================
function ISVehicleDashboard:_ensureACControls()
    local wantLarge = _ydWantLarge()

    -- Rebuild/retarget textures if pack changed
    if self.__acControlsReady and (self.__acPackLarge == wantLarge) then
        return
    end
    self.__acControlsReady = true
    self.__acPackLarge = wantLarge

    -- Textures (try /large/, else fallback)
    local fanOff, fanOffLarge = _ydGetTexWithFlag("media/ui/vehicles/fan_off.png", wantLarge)
    local fanOn,  fanOnLarge  = _ydGetTexWithFlag("media/ui/vehicles/fan_on.png",  wantLarge)
    local knob,   knobLarge   = _ydGetTexWithFlag("media/ui/vehicles/temp_slider.png", wantLarge)

    self.__fan_off = fanOff
    self.__fan_on  = fanOn or fanOff
    self.__temp_slider = knob

    self.__fan_off_isLarge = (fanOffLarge == true)
    self.__fan_on_isLarge  = (fanOnLarge  == true) or (fanOffLarge == true) -- if fan_on missing, treat like off
    self.__temp_slider_isLarge = (knobLarge == true)

    -- Per-texture UI scaling if we fell back
    local fanOffScale = _ydScaleIfFallback(wantLarge, self.__fan_off_isLarge)
    local fanOnScale  = _ydScaleIfFallback(wantLarge, self.__fan_on_isLarge)
    local knobScale   = _ydScaleIfFallback(wantLarge, self.__temp_slider_isLarge)

    -- Fan button reuses vanilla heaterTex slot
    if self.heaterTex and self.__fan_off then
        setImageTextureAndSize(self, self.heaterTex, self.__fan_off, fanOffScale)
        self.heaterTex.target = self
        self.heaterTex.onclick = ISVehicleDashboard.onClickACFan
        self.heaterTex.backgroundColor = { r=0, g=0, b=0, a=0 }

        if self._installPressedEffect then
            self:_installPressedEffect(self.heaterTex, 0.96)
        else
            installPressedEffectFallback(self.heaterTex, 0.96)
        end
    end

    -- Slider knob (visible render, no tint)
    if self.__temp_slider then
        if not self.acTempSlider then
            self.acTempSlider = ISImage:new(0, 0,
                (self.__temp_slider:getWidthOrig()  * knobScale),
                (self.__temp_slider:getHeightOrig() * knobScale),
                self.__temp_slider
            )
            self.acTempSlider:initialise()
            self.acTempSlider:instantiate()
            self.acTempSlider.target = self
            self.acTempSlider.backgroundColor = { r=0, g=0, b=0, a=0 }
            self.acTempSlider.alpha = 1

            function self.acTempSlider:render()
                if not self.texture then return end
                self:drawTextureScaled(self.texture, 0, 0, self.width, self.height, self.alpha or 1)
            end

            -- Make slider draggable
            self.__acDragging = false

            local function beginDrag(ui, x)
                local dash = ui.target
                if not dash then return false end
                dash.__acDragging = true
                ui:setCapture(true)
                dash:_setACTempFromPointerX(ui:getX() + x, true)
                return true
            end

            local function dragMove(ui)
                local dash = ui.target
                if not dash or not dash.__acDragging then return end
                dash:_setACTempFromPointerX(ui:getX() + ui:getMouseX(), true)
            end

            local function endDrag(ui)
                local dash = ui.target
                if dash then dash.__acDragging = false end
                ui:setCapture(false)
                return true
            end

            function self.acTempSlider:onMouseDown(x, y) return beginDrag(self, x) end
            function self.acTempSlider:onMouseMove(dx, dy) dragMove(self) end
            function self.acTempSlider:onMouseMoveOutside(dx, dy) dragMove(self) end
            function self.acTempSlider:onMouseUp(x, y) return endDrag(self) end
            function self.acTempSlider:onMouseUpOutside(x, y) return endDrag(self) end

            self:addChild(self.acTempSlider)
        else
            -- Hot-swap existing slider texture + size
            setImageTextureAndSize(self, self.acTempSlider, self.__temp_slider, knobScale)
        end
    end
end


-- =========================
-- Position UI
-- =========================
function ISVehicleDashboard:_positionACControls()
    if not self.backgroundTex then return end
    self:_ensureACControls()

    local useLarge = (self.__acPackLarge == true)
    local function pick(reg, large, def)
        if useLarge then
            if large ~= nil then return large end
            if reg   ~= nil then return reg end
            return def
        else
            if reg   ~= nil then return reg end
            if large ~= nil then return large end
            return def
        end
    end

    local SLX = pick(self.AC_SLIDER_X,      self.AC_SLIDER_X_LARGE,      0)
    local SLY = pick(self.AC_SLIDER_Y,      self.AC_SLIDER_Y_LARGE,      0)
    local STR = pick(self.AC_SLIDER_TRAVEL, self.AC_SLIDER_TRAVEL_LARGE, 0)
    local FX  = pick(self.AC_FAN_X,         self.AC_FAN_X_LARGE,         0)
    local FY  = pick(self.AC_FAN_Y,         self.AC_FAN_Y_LARGE,         0)

    if self.acTempSlider then
        self.acTempSlider:setX(self.backgroundTex:getX() + SLX)
        self.acTempSlider:setY(self.backgroundTex:getY() + SLY)

        self.__acMinX = self.backgroundTex:getX() + SLX
        self.__acMaxX = self.__acMinX + STR
        self.__acY    = self.backgroundTex:getY() + SLY

        self:_updateACTempSliderPos()
    end

    if self.heaterTex then
        self.heaterTex:setX(self.backgroundTex:getX() + FX)
        self.heaterTex:setY(self.backgroundTex:getY() + FY)
    end
end


-- =========================
-- Update visuals each frame
-- =========================
function ISVehicleDashboard:_updateACControls()
    self:_ensureACControls()

    local heater = self:_getHeaterPart()
    local hasHeater = heater ~= nil

    if self.heaterTex then self.heaterTex:setVisible(hasHeater) end
    if self.acTempSlider then self.acTempSlider:setVisible(hasHeater) end
    if not hasHeater then return end

    local md = heater:getModData()
    local active = (md.active == true)

    -- Fan icon + tooltip + disable like vanilla ACUI OK button
    if self.heaterTex and self.__fan_off then
        -- detect “has power” (use your helper if present, else fallback)
        local hasPower = true
        if self._hasBatteryPower then
            hasPower = (self:_hasBatteryPower() == true)
        elseif self.vehicle then
            hasPower = (self.vehicle:getBatteryCharge() or 0) > 0
        end

        -- Texture: when no power, freeze to unlid/off texture (no swapping)
        local tex
        if hasPower then
            tex = active and (self.__fan_on or self.__fan_off) or self.__fan_off
        else
            tex = self.__fan_off
        end

        local wantLarge = (self.__acPackLarge == true)
        local usedLargeFile = false
        if tex == self.__fan_on then
            usedLargeFile = (self.__fan_on_isLarge == true)
        else
            usedLargeFile = (self.__fan_off_isLarge == true)
        end
        local s = _ydScaleIfFallback(wantLarge, usedLargeFile)

        if (self.heaterTex.texture ~= tex)
            or (self.heaterTex.getWidth and tex.getWidthOrig and self.heaterTex:getWidth() ~= tex:getWidthOrig() * s)
            or (self.heaterTex.getHeight and tex.getHeightOrig and self.heaterTex:getHeight() ~= tex:getHeightOrig() * s)
        then
            setImageTextureAndSize(self, self.heaterTex, tex, s)
        end


        local canToggle = (self.vehicle:isEngineRunning() or self.vehicle:isKeysInIgnition())
        self.heaterTex.__disabled = not canToggle
        self.heaterTex.onclick = canToggle and ISVehicleDashboard.onClickACFan or nil
        self.heaterTex.target = self

        if not canToggle then
            self.heaterTex.mouseovertext = getText("UI_Vehicle_HeaterNeedKey")
        else
            -- keep tooltip logic as-is (even if texture is frozen)
            self.heaterTex.mouseovertext = active and getText("ContextMenu_Turn_Off") or getText("ContextMenu_Turn_On")
        end

        self.heaterTex.backgroundColor = { r=0, g=0, b=0, a=0 }
    end


    -- Keep slider snapped to current heater temperature (unless dragging)
    if not self.__acDragging then
        local idx = nearestIndex(self.AC_TEMP_LEVELS or {}, md.temperature or 0)
        if self.__acTempIndex ~= idx then
            self.__acTempIndex = idx
        end
        self:_updateACTempSliderPos()
    end
    -- Ensure offsets update when user switches texture pack
    self:_positionACControls()
end

-- =========================
-- Hooks
-- =========================
local _oldCreateChildren = ISVehicleDashboard.createChildren
function ISVehicleDashboard:createChildren()
    _oldCreateChildren(self)
    self:_ensureACControls()
    self:_positionACControls()
end

local _oldOnRes = ISVehicleDashboard.onResolutionChange
function ISVehicleDashboard:onResolutionChange()
    if _oldOnRes then _oldOnRes(self) end
    self:_positionACControls()
end

local _oldPrerender = ISVehicleDashboard.prerender
function ISVehicleDashboard:prerender()
    if not self.vehicle or not ISUIHandler.allUIVisible then return end
    if _oldPrerender then _oldPrerender(self) end
    self:_updateACControls()
end
