if isServer() then return end

require "Vehicles/ISUI/ISVehicleDashboard"
require "ISUI/ISImage"
require "YourDash/DashboardCore"

if ISVehicleDashboard.__DashACPatched then return end
ISVehicleDashboard.__DashACPatched = true

ISVehicleDashboard.AC_TEMP_LEVELS = ISVehicleDashboard.AC_TEMP_LEVELS or { -25, -15, -8, 0, 8, 15, 25 }

local function clamp(value, low, high)
    if value < low then return low end
    if value > high then return high end
    return value
end

local function nearestIndex(levels, value)
    local best, distance = 1, math.huge
    for index = 1, #levels do
        local nextDistance = math.abs((value or 0) - levels[index])
        if nextDistance < distance then best, distance = index, nextDistance end
    end
    return best
end

local function setImage(dash, image, texture)
    if not image or not texture then return end
    if dash._setImageTextureAndSize then
        dash:_setImageTextureAndSize(image, texture)
    else
        image.texture = texture
        image:setWidth(texture:getWidthOrig())
        image:setHeight(texture:getHeightOrig())
    end
end

local function setMouseTransparent(element)
    if not element then return end
    element.wantMouseEvents = false
    if element.setWantMouseEvents then
        element:setWantMouseEvents(false)
    elseif element.javaObject and element.javaObject.setConsumeMouseEvents then
        element.javaObject:setConsumeMouseEvents(false)
    end
end

local function scaled(value)
    local scale = YourDash.GetScale and YourDash.GetScale() or 1
    return math.floor((value or 0) * scale + 0.5)
end

local function point(section, name, fallbackX, fallbackY)
    local value = section and section[name] or nil
    return scaled(value and (value.x or value[1]) or fallbackX),
        scaled(value and (value.y or value[2]) or fallbackY), value
end

function ISVehicleDashboard:_getHeaterPart()
    if not self.vehicle then return nil end
    local heater = self.vehicle:getHeater()
    if not heater then return nil end
    return heater
end

function ISVehicleDashboard:_sendHeaterCommand(on, temperature)
    if not self.character then return end
    sendClientCommand(self.character, "vehicle", "toggleHeater", {
        on = on == true,
        temp = temperature or 0,
    })
end

function ISVehicleDashboard:onClickACFan()
    if getGameSpeed() == 0 then return end
    if getGameSpeed() > 1 then setGameSpeed(1) end
    local heater = self:_getHeaterPart()
    if not heater or not self.character then return end
    if not (self.vehicle:isEngineRunning() or self.vehicle:isKeysInIgnition()) then return end
    local data = heater:getModData()
    self:_sendHeaterCommand(not (data.active == true), data.temperature or 0)
    self.character:playSound("VehicleACButton")
end

function ISVehicleDashboard:_updateACTempSliderPos()
    if not self.acTempSlider or not self.__acMinX or not self.__acMaxX then return end
    local levels = self.AC_TEMP_LEVELS
    local index = clamp(self.__acTempIndex or 1, 1, #levels)
    local ratio = #levels > 1 and ((index - 1) / (#levels - 1)) or 0
    self.acTempSlider:setX(math.floor(self.__acMinX + (self.__acMaxX - self.__acMinX) * ratio + 0.5))
    self.acTempSlider:setY(self.__acY or 0)
end

function ISVehicleDashboard:_setACTempIndex(index, doSend)
    local levels = self.AC_TEMP_LEVELS
    index = clamp(index, 1, #levels)
    local previous = self.__acTempIndex
    self.__acTempIndex = index
    self:_updateACTempSliderPos()
    if doSend and previous ~= index then
        local heater = self:_getHeaterPart()
        if not heater then return end
        local data = heater:getModData()
        self:_sendHeaterCommand(data.active == true, levels[index])
        if self.character then self.character:playSound("VehicleACSetTemperature") end
    end
end

function ISVehicleDashboard:_setACTempFromPointerX(pointerX, doSend)
    if not self.acTempSlider or not self.__acMinX or not self.__acMaxX then return end
    local centerMin = self.__acMinX + self.acTempSlider:getWidth() * 0.5
    local centerMax = self.__acMaxX + self.acTempSlider:getWidth() * 0.5
    if centerMax == centerMin then return end
    local ratio = clamp((pointerX - centerMin) / (centerMax - centerMin), 0, 1)
    local index = math.floor(ratio * (#self.AC_TEMP_LEVELS - 1) + 0.5) + 1
    self:_setACTempIndex(index, doSend)
end

function ISVehicleDashboard:_YourDashEnsureACBackground(texture)
    if not texture then
        if self.__YourDashACBackground then self.__YourDashACBackground:setVisible(false) end
        return
    end
    local image = self.__YourDashACBackground
    if not image then
        image = ISImage:new(0, 0, texture:getWidthOrig(), texture:getHeightOrig(), texture)
        image:initialise()
        image:instantiate()
        -- ISImage uses backgroundColor as the texture tint/opacity.  Alpha zero
        -- made the separately-exported heavy AC panel completely invisible.
        image.backgroundColor = { r=1, g=1, b=1, a=1 }
        image.onclick, image.target, image.mouseovertext = nil, nil, nil
        setMouseTransparent(image)
        self:addChild(image)
        self.__YourDashACBackground = image
    end
    setImage(self, image, texture)
    image.backgroundColor = { r=1, g=1, b=1, a=1 }
    setMouseTransparent(image)
    image:setVisible(true)
end

function ISVehicleDashboard:_ensureACControls()
    local family = self.__YourDashFamily or "standard"
    local key = family .. ":" .. (YourDash.GetScaleKey and YourDash.GetScaleKey() or "1x")
    if self.__acControlsKey == key then return end
    self.__acControlsKey = key

    if family == "sport" then
        if self.heaterTex then self.heaterTex:setVisible(false) end
        if self.acTempSlider then self.acTempSlider:setVisible(false) end
        if self.__YourDashACBackground then self.__YourDashACBackground:setVisible(false) end
        return
    end

    self.__fan_off = YourDash.GetDashboardTexture(family, "dash", "fan_off.png")
    self.__fan_on = YourDash.GetDashboardTexture(family, "dash", "fan_on.png") or self.__fan_off
    self.__temp_slider = YourDash.GetDashboardTexture(family, "dash", "temp_slider.png")
    self:_YourDashEnsureACBackground(YourDash.GetDashboardTexture(family, "dash", "ac.png"))

    if self.heaterTex and self.__fan_off then
        setImage(self, self.heaterTex, self.__fan_off)
        self.heaterTex.target = self
        self.heaterTex.onclick = ISVehicleDashboard.onClickACFan
        self.heaterTex.backgroundColor = { r=0, g=0, b=0, a=0 }
        if self._installPressedEffect then
            self:_installPressedEffect(self.heaterTex, family == "heavy" and 1.0 or 0.96)
        end
        -- Heavy has authored up/down switch textures; never layer a generic
        -- click shrink on top.  Restore the standard animation after a family
        -- hot-swap on the same dashboard instance.
        self.heaterTex.__pressedScale = family == "heavy" and 1.0 or 0.96
    end

    if self.__temp_slider then
        if not self.acTempSlider then
            local knob = ISImage:new(0, 0, self.__temp_slider:getWidthOrig(), self.__temp_slider:getHeightOrig(), self.__temp_slider)
            knob:initialise()
            knob:instantiate()
            knob.target = self
            knob.backgroundColor = { r=0, g=0, b=0, a=0 }
            function knob:render()
                if self.texture then self:drawTextureScaled(self.texture, 0, 0, self.width, self.height, 1) end
            end
            function knob:onMouseDown(x, y)
                if self.__disabled then return false end
                local dash = self.target
                dash.__acDragging = true
                if self.setCapture then self:setCapture(true) end
                dash:_setACTempFromPointerX(self:getX() + x, true)
                return true
            end
            function knob:onMouseMove(dx, dy)
                if self.__disabled then return end
                local dash = self.target
                if dash.__acDragging then dash:_setACTempFromPointerX(self:getX() + self:getMouseX(), true) end
            end
            knob.onMouseMoveOutside = knob.onMouseMove
            function knob:onMouseUp(x, y)
                self.target.__acDragging = false
                if self.setCapture then self:setCapture(false) end
                return true
            end
            knob.onMouseUpOutside = knob.onMouseUp
            self:addChild(knob)
            self.acTempSlider = knob
        else
            setImage(self, self.acTempSlider, self.__temp_slider)
        end
    end

    -- The separately-added heavy AC bezel is newer than vanilla's heater
    -- control in the child stack.  Keep both interactive controls above it;
    -- otherwise the opaque bezel can visually cover the fan switch even
    -- though its visibility flag is true.
    if self.heaterTex and self.heaterTex.bringToTop then self.heaterTex:bringToTop() end
    if self.acTempSlider and self.acTempSlider.bringToTop then self.acTempSlider:bringToTop() end
end

function ISVehicleDashboard:_positionACControls()
    if not self.backgroundTex then return end
    self:_ensureACControls()
    if (self.__YourDashFamily or "standard") == "sport" then return end

    local layout = YourDash.GetLayout and YourDash.GetLayout(self) or nil
    local ac = layout and layout.ac or {}
    local sliderX, sliderY, slider = point(ac, "slider", 624, 131)
    local fanX, fanY = point(ac, "fan", 592, 127)
    local bgX, bgY = point(ac, "background", 0, 0)
    local travel = scaled(slider and slider.travel or 88)
    local baseX, baseY = self.backgroundTex:getX(), self.backgroundTex:getY()

    if self.__YourDashACBackground and ac.background then
        self.__YourDashACBackground:setX(baseX + bgX)
        self.__YourDashACBackground:setY(baseY + bgY)
    end
    if self.acTempSlider then
        self.__acMinX, self.__acMaxX = baseX + sliderX, baseX + sliderX + travel
        self.__acY = baseY + sliderY
        self:_updateACTempSliderPos()
    end
    if self.heaterTex then
        self.heaterTex:setX(baseX + fanX)
        self.heaterTex:setY(baseY + fanY)
    end
end

function ISVehicleDashboard:_updateACControls()
    self:_ensureACControls()
    if (self.__YourDashFamily or "standard") == "sport" then
        if self.heaterTex then self.heaterTex:setVisible(false) end
        if self.acTempSlider then self.acTempSlider:setVisible(false) end
        return
    end

    local heater = self:_getHeaterPart()
    local available = heater ~= nil
    local family = self.__YourDashFamily or "standard"
    local showHeavyArtwork = family == "heavy"
    if self.heaterTex then self.heaterTex:setVisible(available or showHeavyArtwork) end
    if self.acTempSlider then self.acTempSlider:setVisible(available or showHeavyArtwork) end
    if self.__YourDashACBackground then
        -- Heavy dashboard artwork exports this bezel as a separate permanent
        -- layer.  Standard has the bezel baked into the dashboard, so never
        -- resurrect a retained heavy texture after changing vehicles.
        self.__YourDashACBackground:setVisible(self.__YourDashFamily == "heavy")
    end
    if not heater then
        if self.heaterTex then
            if self.__fan_off and self.heaterTex.texture ~= self.__fan_off then
                setImage(self, self.heaterTex, self.__fan_off)
            end
            self.heaterTex.__disabled = true
            self.heaterTex.onclick = nil
            self.heaterTex.mouseovertext = nil
        end
        if self.acTempSlider then self.acTempSlider.__disabled = true end
        self:_positionACControls()
        return
    end

    local data = heater:getModData()
    local active = data.active == true
    local hasPower = self:_hasBatteryPower()
    -- Heavy is a mechanical-looking authored switch, so its texture follows
    -- the commanded state even with power removed.  Standard retains its
    -- powered indicator behavior.
    local visuallyOn = active and (family == "heavy" or hasPower)
    local texture = visuallyOn and self.__fan_on or self.__fan_off
    if self.heaterTex and texture and self.heaterTex.texture ~= texture then setImage(self, self.heaterTex, texture) end

    if self.heaterTex then
        local canToggle = self.vehicle:isEngineRunning() or self.vehicle:isKeysInIgnition()
        self.heaterTex.__disabled = not canToggle
        self.heaterTex.onclick = canToggle and ISVehicleDashboard.onClickACFan or nil
        self.heaterTex.target = self
        self.heaterTex.mouseovertext = canToggle and
            (active and getText("ContextMenu_Turn_Off") or getText("ContextMenu_Turn_On")) or
            getText("UI_Vehicle_HeaterNeedKey")
    end

    if not self.__acDragging then
        self.__acTempIndex = nearestIndex(self.AC_TEMP_LEVELS, data.temperature or 0)
        self:_updateACTempSliderPos()
    end
    if self.acTempSlider then self.acTempSlider.__disabled = false end
    self:_positionACControls()
end

local oldCreateChildren = ISVehicleDashboard.createChildren
function ISVehicleDashboard:createChildren()
    oldCreateChildren(self)
    self:_ensureACControls()
    self:_positionACControls()
end

local oldOnResolutionChange = ISVehicleDashboard.onResolutionChange
function ISVehicleDashboard:onResolutionChange()
    if oldOnResolutionChange then oldOnResolutionChange(self) end
    self:_positionACControls()
end

local oldPrerender = ISVehicleDashboard.prerender
function ISVehicleDashboard:prerender()
    if not self.vehicle or not ISUIHandler.allUIVisible then return end
    if oldPrerender then oldPrerender(self) end
    self:_updateACControls()
end
