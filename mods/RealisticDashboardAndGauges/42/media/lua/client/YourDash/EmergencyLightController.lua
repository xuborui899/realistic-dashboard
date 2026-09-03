if isServer() then return end

require "ISUI/ISPanel"
require "ISUI/ISImage"
require "ISUI/Fireplace/ISKnob"
require "YourDash/DashboardCore"

YourDash = YourDash or {}
local YD = YourDash

if YD.EmergencyLightController and YD.EmergencyLightController.__loaded then
    return YD.EmergencyLightController
end

local ELC = {}
YD.EmergencyLightController = ELC
ELC.__loaded = true

local Controller = ISPanel:derive("YourDashEmergencyLightController")
ELC.Controller = Controller

local function round(value)
    value = tonumber(value) or 0
    if value < 0 then return math.ceil(value - 0.5) end
    return math.floor(value + 0.5)
end

local function safeMethod(object, methodName, ...)
    if object == nil then return nil end
    local okMethod, method = pcall(function() return object[methodName] end)
    if not okMethod or type(method) ~= "function" then return nil end
    local ok, value = pcall(method, object, ...)
    if ok then return value end
    return nil
end

local function isMouseOver(element)
    if not element or not element.isMouseOver then return false end
    local ok, value = pcall(element.isMouseOver, element)
    return ok and value == true
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

local function setTexture(image, texture)
    if not image or not texture then return end
    image.texture = texture
    image:setWidth(texture:getWidthOrig())
    image:setHeight(texture:getHeightOrig())
    image.autoScale = false
    image.noAspect = false
end

local function getTextOr(key, fallback)
    if getText then
        local ok, value = pcall(getText, key)
        if ok and value and value ~= key then return value end
    end
    return fallback
end

local function scaleKey()
    return YD.GetScaleKey and YD.GetScaleKey() or "1x"
end

local function scaleValue(key)
    return YD.GetScale and YD.GetScale(key) or 1
end

local function assetTexture(key, name)
    local path = "media/ui/vehicles/emergency light controller/" .. key .. "/" .. name
    if YD.LoadTexture then return YD.LoadTexture(path) end
    if getTexture then return getTexture(path) end
    return nil
end

local function buttonTexture(key, name)
    local path = "media/ui/vehicles/buttons/" .. key .. "/" .. name
    if YD.LoadTexture then return YD.LoadTexture(path) end
    if getTexture then return getTexture(path) end
    return nil
end

local function circularDistance(a, b)
    local distance = math.abs((a or 0) - (b or 0)) % 360
    return math.min(distance, 360 - distance)
end

local SIREN_BUTTONS = {
    standby = {
        mode = 0, x = 8, y = 10,
        off = "siren_standby.png",
        tooltip = function() return getTextOr("IGUI_VehicleLightbar_STANDBY", "standby") end,
    },
    yelp = {
        mode = 1, x = 42, y = 10,
        off = "siren_yelp_off.png", on = "siren_yelp_on.png",
        tooltip = function() return getTextOr("IGUI_VehicleLightbar_YELP", "yelp") end,
    },
    wail = {
        mode = 2, x = 8, y = 36,
        off = "siren_wail_off.png", on = "siren_wail_on.png",
        tooltip = function() return getTextOr("IGUI_VehicleLightbar_WAIL", "wail") end,
    },
    alarm = {
        mode = 3, x = 42, y = 36,
        off = "siren_alarm_off.png", on = "siren_alarm_on.png",
        tooltip = function() return getTextOr("IGUI_VehicleLightbar_ALARM", "alarm") end,
    },
}

local FAMILY_VERTICAL_OFFSETS_1X = {
    standard = 8,
    heavy = 3,
    sport = 3,
}

function Controller:new(owner)
    local o = ISPanel:new(0, 0, 1, 1)
    setmetatable(o, self)
    self.__index = self

    o.owner = owner
    o.vehicle = nil
    o.expanded = true
    o.__active = false
    o.__managed = false
    o.__childrenCreated = false
    o.__textureKey = nil
    o.__buttons = {}
    -- Position the visible plate, not this padded outer container, against the screen edge.
    o.keepOnScreen = false
    o.backgroundColor = { r = 0, g = 0, b = 0, a = 0 }
    o.borderColor = { r = 0, g = 0, b = 0, a = 0 }
    o:noBackground()
    return o
end

function Controller:_loadTextures(force)
    local key = scaleKey()
    if not force and self.__textureKey == key and self.__textures then return true end

    local textures = {
        cap = assetTexture(key, "controller_cap.png"),
        plate = assetTexture(key, "controller.png"),
        shadow = assetTexture(key, "controller_shadow.png"),
        wailOff = assetTexture(key, "siren_wail_off.png"),
        wailOn = assetTexture(key, "siren_wail_on.png"),
        alarmOff = assetTexture(key, "siren_alarm_off.png"),
        alarmOn = assetTexture(key, "siren_alarm_on.png"),
        yelpOff = assetTexture(key, "siren_yelp_off.png"),
        yelpOn = assetTexture(key, "siren_yelp_on.png"),
        standby = assetTexture(key, "siren_standby.png"),
        knobBase = assetTexture(key, "light_knob_base.png"),
        knobHandle = assetTexture(key, "light_knob_handle.png"),
        ledOff = assetTexture(key, "light_led_off.png"),
        ledOn = assetTexture(key, "light_led_on.png"),
        collapse = buttonTexture(key, "btn_elc_collapse.png"),
        expand = buttonTexture(key, "btn_elc_expand.png"),
    }

    for _, texture in pairs(textures) do
        if not texture then return false end
    end

    self.__textures = textures
    self.__textureKey = key
    self.__scale = scaleValue(key)
    if self.__childrenCreated then self:_applyTextures() end
    return true
end

function Controller:_newImage(texture, transparent)
    local image = ISImage:new(0, 0, texture and texture:getWidthOrig() or 1,
        texture and texture:getHeightOrig() or 1, texture)
    image:initialise()
    image:instantiate()
    image.backgroundColor = { r = 1, g = 1, b = 1, a = 1 }
    if transparent then setMouseTransparent(image) end
    self:addChild(image)
    return image
end

function Controller:_createToggle()
    local image = self:_newImage(self.__textures.collapse, false)
    image.__controller = self
    image.__pressed = false
    image.mouseovertext = "collapse emergency light controller"

    function image:onMouseDown(_x, _y)
        self.__pressed = true
        return true
    end

    function image:onMouseUp(_x, _y)
        local controller = self.__controller
        local pressed = self.__pressed == true
        self.__pressed = false
        if pressed and controller then controller:setExpanded(not controller.expanded) end
        return true
    end

    function image:onMouseUpOutside(_x, _y)
        self.__pressed = false
        return true
    end

    function image:prerender()
        local controller = self.__controller
        local texture = self.texture
        if not controller or not texture then return end
        local alpha = isMouseOver(self) and 0.60 or 0.40
        local shrink = self.__pressed and 0.96 or 1.0
        local width = self.width * shrink
        local height = self.height * shrink
        self:drawTextureScaled(texture, (self.width - width) * 0.5,
            (self.height - height) * 0.5, width, height, alpha)
        self:updateTooltip()
    end

    self.toggle = image
end

function Controller:_createSirenButton(key, definition)
    local off = self:_newImage(self.__textures[definition.offKey], true)
    local on = nil
    if definition.onKey then on = self:_newImage(self.__textures[definition.onKey], true) end

    local hit = ISImage:new(0, 0, 1, 1, nil)
    hit:initialise()
    hit:instantiate()
    hit.__controller = self
    hit.__buttonKey = key
    hit.__pressed = false
    hit.backgroundColor = { r = 1, g = 1, b = 1, a = 0 }
    hit.mouseovertext = definition.tooltip()

    function hit:onMouseDown(_x, _y)
        if self.__disabled then return false end
        self.__pressed = true
        local controller = self.__controller
        if controller then controller:_layoutButtonVisual(controller.__buttons[self.__buttonKey]) end
        return true
    end

    function hit:onMouseUp(_x, _y)
        local controller = self.__controller
        local pressed = self.__pressed == true
        self.__pressed = false
        if controller then
            local button = controller.__buttons[self.__buttonKey]
            controller:_layoutButtonVisual(button)
            if pressed then controller:_activateSiren(button) end
        end
        return true
    end

    function hit:onMouseUpOutside(_x, _y)
        self.__pressed = false
        local controller = self.__controller
        if controller then controller:_layoutButtonVisual(controller.__buttons[self.__buttonKey]) end
        return true
    end

    self:addChild(hit)
    self.__buttons[key] = {
        key = key,
        mode = definition.mode,
        x = definition.x,
        y = definition.y,
        offKey = definition.offKey,
        onKey = definition.onKey,
        tooltip = definition.tooltip,
        off = off,
        on = on,
        hit = hit,
    }
end

function Controller:_createKnob()
    local knob = ISKnob:new(0, 0, self.__textures.knobHandle, self.__textures.knobBase, "",
        self.owner and self.owner.character or nil)
    knob:initialise()
    knob:instantiate()
    knob.target = self
    knob.switchSound = "VehicleSetLights"
    -- DrawTextureAngle rotates the supplied upright handle clockwise.
    -- OFF is west, then 1, 2, and 3 sweep clockwise across the top to east.
    knob:addValue(270, 0)
    knob:addValue(315, 1)
    knob:addValue(45, 2)
    knob:addValue(90, 3)
    knob.onMouseUpFct = function(controller, element)
        if controller then controller:_setLightbarLightsMode(element:getValue()) end
    end

    function knob:render()
        local controller = self.target
        if not controller then return end
        local textures = controller.__textures or {}
        if textures.knobBase then self:drawTexture(textures.knobBase, 0, 0, 1) end
        local selected = self.values[self.selected]
        if selected and textures.knobHandle then
            self:DrawTextureAngle(textures.knobHandle, self.width * 0.5, self.height * 0.5, selected.angle)
        end
        if ISUIElement and ISUIElement.render then ISUIElement.render(self) end
    end

    function knob:onMouseMove(_dx, _dy)
        if not self.dragging then return end
        local centerX = self.width * 0.5
        local centerY = self.height * 0.5
        local radians = math.atan2(self:getMouseY() - centerY, self:getMouseX() - centerX) + math.pi
        local degrees = (radians * 180 / math.pi + 270) % 360
        local nearest, distance = self.selected, math.huge
        for index = 1, #self.values do
            local candidate = circularDistance(degrees, self.values[index].angle)
            if candidate < distance then
                nearest, distance = index, candidate
            end
        end
        if nearest and nearest ~= self.selected then
            self.selected = nearest
            self:playSwitchSound()
        end
    end

    function knob:onMouseMoveOutside(dx, dy)
        self:onMouseMove(dx, dy)
    end

    self:addChild(knob)
    self.knob = knob
end

function Controller:_createLED()
    self.ledOff = self:_newImage(self.__textures.ledOff, true)
    self.ledOn = self:_newImage(self.__textures.ledOn, true)
end

function Controller:_build()
    if self.__childrenCreated or not self:_loadTextures() then return end

    self.cap = self:_newImage(self.__textures.cap, true)
    self.plate = self:_newImage(self.__textures.plate, true)
    self:_createToggle()

    self:_createSirenButton("standby", {
        mode = 0, x = 8, y = 10, offKey = "standby",
        tooltip = SIREN_BUTTONS.standby.tooltip,
    })
    self:_createSirenButton("yelp", {
        mode = 1, x = 42, y = 10, offKey = "yelpOff", onKey = "yelpOn",
        tooltip = SIREN_BUTTONS.yelp.tooltip,
    })
    self:_createSirenButton("wail", {
        mode = 2, x = 8, y = 36, offKey = "wailOff", onKey = "wailOn",
        tooltip = SIREN_BUTTONS.wail.tooltip,
    })
    self:_createSirenButton("alarm", {
        mode = 3, x = 42, y = 36, offKey = "alarmOff", onKey = "alarmOn",
        tooltip = SIREN_BUTTONS.alarm.tooltip,
    })
    self:_createKnob()
    self:_createLED()
    self.shadow = self:_newImage(self.__textures.shadow, true)

    self.__childrenCreated = true
    self:_applyTextures()
end

function Controller:_applyTextures()
    if not self.__childrenCreated then return end
    local textures = self.__textures
    setTexture(self.cap, textures.cap)
    setTexture(self.plate, textures.plate)
    setTexture(self.shadow, textures.shadow)
    for _, button in pairs(self.__buttons) do
        setTexture(button.off, textures[button.offKey])
        if button.on and button.onKey then setTexture(button.on, textures[button.onKey]) end
        button.hit.mouseovertext = button.tooltip()
    end
    self.knob.tex = textures.knobHandle
    self.knob.valuesBg = textures.knobBase
    self.knob:setWidth(textures.knobBase:getWidthOrig())
    self.knob:setHeight(textures.knobBase:getHeightOrig())
    setTexture(self.ledOff, textures.ledOff)
    setTexture(self.ledOn, textures.ledOn)
    setTexture(self.toggle, self.expanded and textures.collapse or textures.expand)
    self:_syncToggle()
    self:_layout()
end

function Controller:_sizeCentered(image, texture, centerX, centerY, shrink)
    if not image or not texture then return end
    shrink = shrink or 1
    local width = math.max(1, round(texture:getWidthOrig() * shrink))
    local height = math.max(1, round(texture:getHeightOrig() * shrink))
    image:setX(round(centerX - width * 0.5))
    image:setY(round(centerY - height * 0.5))
    image:setWidth(width)
    image:setHeight(height)
    image.autoScale = true
    image.noAspect = true
end

function Controller:_layoutButtonVisual(button)
    if not button or not self.__textures then return end
    local scale = self.__scale or 1
    local plateX = self.__plateX or 0
    local plateY = self.__plateY or 0
    local offTexture = self.__textures[button.offKey]
    if not offTexture then return end

    local x = plateX + round(button.x * scale)
    local y = plateY + round(button.y * scale)
    local centerX = x + offTexture:getWidthOrig() * 0.5
    local centerY = y + offTexture:getHeightOrig() * 0.5
    local shrink = button.hit.__pressed and 0.94 or 1.0
    self:_sizeCentered(button.off, offTexture, centerX, centerY, shrink)
    if button.on and button.onKey then
        self:_sizeCentered(button.on, self.__textures[button.onKey], centerX, centerY, shrink)
    end
    button.hit:setX(x)
    button.hit:setY(y)
    button.hit:setWidth(offTexture:getWidthOrig())
    button.hit:setHeight(offTexture:getHeightOrig())
end

function Controller:_layout()
    if not self.__childrenCreated or not self.__textures then return end
    local scale = self.__scale or 1
    local textures = self.__textures
    -- The glow textures carry transparent margins, but their visible pixels stay
    -- within the controller plate. Keep this root hitbox clear of the radio below.
    local glowPadding = 0
    local gap = math.max(1, round(2 * scale))
    local plateWidth = textures.plate:getWidthOrig()
    local plateHeight = textures.plate:getHeightOrig()
    local toggleWidth = self.toggle and self.toggle:getWidth() or 0
    local toggleHeight = self.toggle and self.toggle:getHeight() or 0

    self.__plateX = glowPadding
    self.__plateY = glowPadding
    self:setWidth(self.__plateX + plateWidth + gap + toggleWidth + glowPadding)
    self:setHeight(glowPadding + plateHeight + glowPadding)

    self.plate:setX(self.__plateX)
    self.plate:setY(self.__plateY)
    self.cap:setX(self.__plateX)
    self.cap:setY(self.__plateY)
    self.toggle:setX(self.__plateX + plateWidth + gap)
    self.toggle:setY(self.__plateY + round((plateHeight - toggleHeight) * 0.5))

    for _, button in pairs(self.__buttons) do self:_layoutButtonVisual(button) end

    self.knob:setX(self.__plateX + round(94 * scale))
    self.knob:setY(self.__plateY + round(14 * scale))

    local ledCenterX = self.__plateX + round(90 * scale)
    local ledCenterY = self.__plateY + round(49 * scale)
    self:_sizeCentered(self.ledOff, textures.ledOff, ledCenterX, ledCenterY)
    self:_sizeCentered(self.ledOn, textures.ledOn, ledCenterX, ledCenterY)

    local plateCenterX = self.__plateX + plateWidth * 0.5
    local plateBottomY = self.__plateY + plateHeight
    local shadowWidth = textures.shadow:getWidthOrig()
    local shadowHeight = textures.shadow:getHeightOrig()
    self.shadow:setX(round(plateCenterX - shadowWidth * 0.5))
    self.shadow:setY(round(plateBottomY - shadowHeight))
end

function Controller:_hasLightbar(vehicle)
    return safeMethod(vehicle, "hasLightbar") == true
end

function Controller:_getSirenMode()
    return math.max(0, tonumber(safeMethod(self.vehicle, "getLightbarSirenMode")) or 0)
end

function Controller:_getLightsMode()
    return math.max(0, tonumber(safeMethod(self.vehicle, "getLightbarLightsMode")) or 0)
end

function Controller:_playSound(name)
    if not getSoundManager then return end
    local ok, manager = pcall(getSoundManager)
    if ok and manager and manager.playUISound then pcall(manager.playUISound, manager, name) end
end

function Controller:_setLightbarSirenMode(mode)
    local owner = self.owner
    if not owner or not owner.character or not self.vehicle or not sendClientCommand then return end
    sendClientCommand(owner.character, "vehicle", "setLightbarSirenMode", { mode = mode })
    self:_playSound("VehicleSetSiren")
end

function Controller:_setLightbarLightsMode(mode)
    local owner = self.owner
    if not owner or not owner.character or not self.vehicle or not sendClientCommand then return end
    sendClientCommand(owner.character, "vehicle", "setLightbarLightsMode", { mode = mode })
end

function Controller:_activateSiren(button)
    if not button then return end
    local current = self:_getSirenMode()
    local mode = button.mode == 0 and 0 or ((current == button.mode) and 0 or button.mode)
    self:_setLightbarSirenMode(mode)
end

function Controller:_syncToggle()
    if not self.toggle or not self.__textures then return end
    setTexture(self.toggle, self.expanded and self.__textures.collapse or self.__textures.expand)
    self.toggle.mouseovertext = self.expanded
        and "collapse emergency light controller"
        or "expand emergency light controller"
end

function Controller:_syncState()
    if not self.__childrenCreated then return end
    if not self.expanded then return end
    local siren = self:_getSirenMode()
    local lights = self:_getLightsMode()

    for _, button in pairs(self.__buttons) do
        local active = button.mode > 0 and siren == button.mode
        button.off:setVisible(not active)
        if button.on then button.on:setVisible(active) end
        button.hit:setVisible(self.expanded)
    end

    if self.knob and not self.knob.dragging then self.knob:setKnobPosition(lights) end
    if self.ledOff then self.ledOff:setVisible(lights == 0) end
    if self.ledOn then self.ledOn:setVisible(lights > 0) end
end

function Controller:_syncVisibility()
    local controlsVisible = self.__active and self.expanded
    if self.cap then self.cap:setVisible(controlsVisible) end
    if self.toggle then self.toggle:setVisible(self.__active) end
    if self.plate then self.plate:setVisible(controlsVisible) end
    for _, button in pairs(self.__buttons) do
        button.off:setVisible(controlsVisible and not (button.mode > 0 and self:_getSirenMode() == button.mode))
        if button.on then button.on:setVisible(controlsVisible and self:_getSirenMode() == button.mode) end
        button.hit:setVisible(controlsVisible)
    end
    if self.knob then
        self.knob:setVisible(controlsVisible)
        if not controlsVisible then self.knob.dragging = false end
    end
    if self.ledOff then self.ledOff:setVisible(controlsVisible and self:_getLightsMode() == 0) end
    if self.ledOn then self.ledOn:setVisible(controlsVisible and self:_getLightsMode() > 0) end
    if self.shadow then self.shadow:setVisible(controlsVisible) end
end

function Controller:setExpanded(expanded)
    expanded = expanded == true
    if self.expanded == expanded then return end
    self.expanded = expanded
    self:_syncToggle()
    self:_syncVisibility()
    self:position()
end

function Controller:_setManaged(active)
    self.__active = active == true
    if self.__active then
        self:setVisible(true)
        if not self.__managed and self.addToUIManager then
            self:addToUIManager()
            self.__managed = true
            if self.bringToTop then self:bringToTop() end
        end
    else
        self:setVisible(false)
        if self.__managed and self.removeFromUIManager then
            self:removeFromUIManager()
            self.__managed = false
        end
    end
    self:_syncVisibility()
end

function Controller:_currentRadio()
    local owner = self.owner
    if not owner then return nil end
    local which = nil
    if owner._yourDashPickRadioUI then
        local ok, value = pcall(owner._yourDashPickRadioUI, owner)
        if ok then which = value end
    end
    if which == "value" and owner.valueRadioBG then return owner.valueRadioBG end
    if which == "premium" and owner.radioBG then return owner.radioBG end
    return owner.radioBG or owner.valueRadioBG
end

function Controller:_fallbackRadioRect()
    local owner = self.owner
    local background = owner and owner.backgroundTex or nil
    if not owner or not background then return nil end

    local which = "premium"
    if owner._yourDashPickRadioUI then
        local ok, value = pcall(owner._yourDashPickRadioUI, owner)
        if ok and value == "value" then which = "value" end
    end

    local x, y = nil, nil
    if owner._paxGetLayoutPoint then
        x, y = owner:_paxGetLayoutPoint(which == "value" and "radioStandard" or "radioPremium")
    elseif YD.GetLayoutPoint then
        x, y = YD.GetLayoutPoint(owner, "radio", which == "value" and "standard" or "premium")
    end
    if x == nil or y == nil then x, y = 0, 0 end

    local bx = safeMethod(background, "getAbsoluteX") or ((owner:getX() or 0) + (background:getX() or 0))
    local by = safeMethod(background, "getAbsoluteY") or ((owner:getY() or 0) + (background:getY() or 0))
    local scale = self.__scale or 1
    return bx + x, by + y, round(200 * scale), round(60 * scale)
end

function Controller:position()
    if not self.__active or not self.__childrenCreated then return end
    local radio = self:_currentRadio()
    local x, y, width, height = nil, nil, nil, nil
    if radio then
        x = safeMethod(radio, "getAbsoluteX")
        y = safeMethod(radio, "getAbsoluteY")
        width = safeMethod(radio, "getWidth")
        height = safeMethod(radio, "getHeight")
    end
    if x == nil or y == nil or not width or width <= 0 then
        x, y, width, height = self:_fallbackRadioRect()
    end
    if x == nil or y == nil then return end

    local plateWidth = self.__textures.plate:getWidthOrig()
    local plateHeight = self.__textures.plate:getHeightOrig()
    local gap = math.max(1, round(2 * (self.__scale or 1)))
    local plateX = round(x + ((width or plateWidth) - plateWidth) * 0.5)
    local plateY = round(y - plateHeight - gap)
    local profile = YD.GetVehicleProfile and YD.GetVehicleProfile(self.vehicle) or nil
    local family = YD.NormalizeFamily and YD.NormalizeFamily(profile and profile.family) or nil
    plateY = plateY - round((FAMILY_VERTICAL_OFFSETS_1X[family] or 0) * (self.__scale or 1))

    local owner = self.owner
    local playerNum = owner and owner.playerNum or 0
    local screenLeft = getPlayerScreenLeft and getPlayerScreenLeft(playerNum) or 0
    local screenTop = getPlayerScreenTop and getPlayerScreenTop(playerNum) or 0
    local screenWidth = getPlayerScreenWidth and getPlayerScreenWidth(playerNum) or 0
    local screenHeight = getPlayerScreenHeight and getPlayerScreenHeight(playerNum) or 0
    if screenWidth > 0 then
        plateX = math.max(screenLeft, math.min(plateX, screenLeft + screenWidth - plateWidth))
    end
    if screenHeight > 0 then
        plateY = math.max(screenTop, math.min(plateY, screenTop + screenHeight - plateHeight))
    end

    self:setX(plateX - (self.__plateX or 0))
    self:setY(plateY - (self.__plateY or 0))
end

function ELC.Ensure(owner)
    if not owner then return nil end
    local controller = owner.__YourDashEmergencyLightController
    if controller then
        controller.owner = owner
        if controller:_loadTextures() then controller:_build() end
        return controller
    end

    controller = Controller:new(owner)
    controller:initialise()
    controller:instantiate()
    if controller.setAlwaysOnTop then controller:setAlwaysOnTop(true) end
    owner.__YourDashEmergencyLightController = controller
    if controller:_loadTextures() then controller:_build() end
    return controller
end

function ELC.SetVehicle(owner, vehicle, resetExpanded)
    local controller = ELC.Ensure(owner)
    if not controller then return end
    controller.owner = owner
    controller.vehicle = vehicle
    if vehicle and resetExpanded then
        controller.expanded = true
        controller:_syncToggle()
    end
    if not vehicle then
        controller:_setManaged(false)
        return
    end
    ELC.Update(owner, true)
end

function ELC.Update(owner, allowed)
    local controller = ELC.Ensure(owner)
    if not controller then return end
    controller.owner = owner
    controller.vehicle = owner and owner.vehicle or nil
    if not controller:_loadTextures() then
        controller:_setManaged(false)
        return
    end
    controller:_build()

    local ownerVisible = true
    if owner and owner.isVisible then
        local ok, visible = pcall(owner.isVisible, owner)
        if ok then ownerVisible = visible == true end
    end
    local active = allowed ~= false and ownerVisible and controller:_hasLightbar(controller.vehicle)
    controller:_setManaged(active)
    if not active then return end
    controller:_layout()
    controller:_syncState()
    controller:position()
end

function ELC.Position(owner)
    local controller = owner and owner.__YourDashEmergencyLightController or nil
    if controller then controller:position() end
end

return ELC
