-- Sport-dashboard-only displays and controls for Build 42.
-- Runtime state is intentionally kept on the local dashboard instance.  The
-- only vehicle mutation in this file is the vanilla, server-authoritative
-- toggleHeater client command.

if isServer() then return end

pcall(require, "Vehicles/ISUI/ISVehicleDashboard")
pcall(require, "YourDash/DashboardCore")
pcall(require, "Vehicles/ISUI/Z_PatchVehicleDashboard")
pcall(require, "ISUI/ISImage")
pcall(require, "ISUI/ISPanel")
pcall(require, "ISUI/Fireplace/ISKnob")

if not ISVehicleDashboard or not YourDash then return end
if type(YourDash.GetDashboardTexture) ~= "function" or type(YourDash.GetLayout) ~= "function" then return end
if ISVehicleDashboard.__YourDashSportPatched then return end
ISVehicleDashboard.__YourDashSportPatched = true

local MAIN_MODE_MPH = 1
local MAIN_MODE_KPH = 2
local MAIN_MODE_INSTANT_MPG = 3
local MAIN_MODE_AVERAGE_MPG = 4
local MAIN_MODE_ENGINE_CONDITION = 5
local MAIN_MODE_COUNT = 5

local AC_MODE_INSIDE = 1
local AC_MODE_OUTSIDE = 2
local AC_MODE_SET = 3
local AC_MODE_COUNT = 3

local AC_RAW_LEVELS = { -25, -15, -8, 0, 8, 15, 25 }
local AC_SETPOINTS_C = { 16, 18, 20, 22, 24, 26, 28 }
local MPG_KM_PER_LITRE_TO_US = 2.352145833
local INSTANT_MPG_WINDOW_SECONDS = 15.0
local TELEPORT_STEP_LIMIT_SQUARES = 25.0
local DEGREE_SYMBOL = "\194\176"

local function clamp(value, low, high)
    value = tonumber(value) or low
    if value < low then return low end
    if value > high then return high end
    return value
end

local function roundNearest(value)
    value = tonumber(value) or 0
    if value >= 0 then return math.floor(value + 0.5) end
    return math.ceil(value - 0.5)
end

local function finiteNumber(value)
    value = tonumber(value)
    if value == nil or value ~= value or value == math.huge or value == -math.huge then return nil end
    return value
end

local function safeCall(object, methodName, ...)
    if object == nil then return nil end
    local okMethod, method = pcall(function() return object[methodName] end)
    if not okMethod or type(method) ~= "function" then return nil end
    local ok, value = pcall(method, object, ...)
    if not ok then return nil end
    return value
end

local function currentScale()
    return YourDash.GetScale and YourDash.GetScale() or 1
end

local function scaled(value)
    if YourDash.ScaledCoord then return YourDash.ScaledCoord(value) end
    return roundNearest((tonumber(value) or 0) * currentScale())
end

local function actualTextureSize(texture)
    if not texture then return 0, 0 end
    local width = safeCall(texture, "getWidthOrig") or safeCall(texture, "getWidth") or 0
    local height = safeCall(texture, "getHeightOrig") or safeCall(texture, "getHeight") or 0
    return width, height
end

local function setImageTexture(dashboard, image, texture)
    if not image or not texture then return end
    if dashboard._setImageTextureAndSize then
        dashboard:_setImageTextureAndSize(image, texture)
        return
    end
    local width, height = actualTextureSize(texture)
    image.texture = texture
    image:setWidth(width)
    image:setHeight(height)
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

local function nearestLevelIndex(rawTemperature)
    rawTemperature = tonumber(rawTemperature) or 0
    local bestIndex, bestDistance = 1, math.huge
    for index = 1, #AC_RAW_LEVELS do
        local distance = math.abs(rawTemperature - AC_RAW_LEVELS[index])
        if distance < bestDistance then
            bestIndex, bestDistance = index, distance
        end
    end
    return bestIndex
end

local function getFuelAmount(vehicle)
    local tank = vehicle and safeCall(vehicle, "getPartById", "GasTank") or nil
    return finiteNumber(tank and safeCall(tank, "getContainerContentAmount") or nil)
end

local function getEngineCondition(vehicle)
    local engine = vehicle and safeCall(vehicle, "getPartById", "Engine") or nil
    return clamp(engine and safeCall(engine, "getCondition") or 0, 0, 100)
end

local function getHeaterState(vehicle)
    local heater = vehicle and safeCall(vehicle, "getHeater") or nil
    if not heater then return nil, false, 0 end
    local data = safeCall(heater, "getModData")
    if not data then return heater, false, 0 end
    return heater, data.active == true, tonumber(data.temperature) or 0
end

local function hasHeaterPower(vehicle)
    if not vehicle then return false end
    return safeCall(vehicle, "isEngineRunning") == true or safeCall(vehicle, "isKeysInIgnition") == true
end

local function sendHeaterCommand(dashboard, active, rawTemperature)
    if not dashboard or not dashboard.character or not dashboard.vehicle then return false end
    if not sendClientCommand then return false end
    sendClientCommand(dashboard.character, "vehicle", "toggleHeater", {
        on = active == true,
        temp = tonumber(rawTemperature) or 0,
    })
    return true
end

local function playCharacterSound(dashboard, soundName)
    if dashboard and dashboard.character and dashboard.character.playSound then
        pcall(function() dashboard.character:playSound(soundName) end)
    end
end

local function temperatureUsesCelsius()
    if not getCore then return true end
    local ok, core = pcall(getCore)
    if not ok or not core then return true end
    local value = safeCall(core, "getOptionTemperatureDisplayCelsius")
    if value ~= nil then return value == true end
    value = safeCall(core, "getOptionDisplayAsCelsius")
    if value ~= nil then return value == true end
    value = safeCall(core, "isCelsius")
    if value ~= nil then return value == true end
    return true
end

local function displayTemperatureValue(celsius)
    celsius = finiteNumber(celsius) or 0
    if Temperature and Temperature.getRoundedDisplayTemperature then
        local ok, value = pcall(Temperature.getRoundedDisplayTemperature, celsius)
        if ok and finiteNumber(value) then return roundNearest(value) end
    end
    if temperatureUsesCelsius() then return roundNearest(celsius) end
    return roundNearest(celsius * 9 / 5 + 32)
end

local function temperatureUnitLetter()
    return temperatureUsesCelsius() and "C" or "F"
end

local function getClimateManagerInstance()
    if ClimateManager and ClimateManager.getInstance then
        local ok, value = pcall(ClimateManager.getInstance)
        if ok and value then return value end
    end
    if getClimateManager then
        local ok, value = pcall(getClimateManager)
        if ok and value then return value end
    end
    return nil
end

local function getInsideTemperature(dashboard)
    local manager = getClimateManagerInstance()
    local value = manager and dashboard.character
        and safeCall(manager, "getAirTemperatureForCharacter", dashboard.character, false) or nil
    -- Some older B42 builds do not expose the character helper.  Their vehicle
    -- reading is a cabin delta, so add it to ambient temperature.
    if finiteNumber(value) == nil then
        local ambient = manager and finiteNumber(safeCall(manager, "getTemperature")) or 0
        local cabinDelta = dashboard.vehicle
            and finiteNumber(safeCall(dashboard.vehicle, "getInsideTemperature")) or 0
        value = ambient + cabinDelta
    end
    return finiteNumber(value) or 0
end

local function getOutsideTemperature(dashboard)
    local manager = getClimateManagerInstance()
    if not manager then return 0 end
    local value = safeCall(manager, "getTemperature")
    return finiteNumber(value) or 0
end

local function makeImage(dashboard, texture)
    if not texture then return nil end
    local width, height = actualTextureSize(texture)
    local image = ISImage:new(0, 0, width, height, texture)
    image:initialise()
    image:instantiate()
    image.backgroundColor = { r = 0, g = 0, b = 0, a = 0 }
    dashboard:addChild(image)
    return image
end

local function resetTripState(state, vehicle)
    state.distanceKm = 0
    state.fuelLitres = 0
    state.instantDistanceKm = 0
    state.instantFuelLitres = 0
    state.pendingInstantDistanceKm = 0
    state.samples = {}
    state.clock = 0
    state.lastX = finiteNumber(vehicle and safeCall(vehicle, "getX") or nil)
    state.lastY = finiteNumber(vehicle and safeCall(vehicle, "getY") or nil)
    state.lastFuel = getFuelAmount(vehicle)
    state.justReset = true
end

local function newTripState(vehicle)
    local state = {
        vehicle = vehicle,
        engineWasRunning = false,
        distanceKm = 0,
        fuelLitres = 0,
        instantDistanceKm = 0,
        instantFuelLitres = 0,
        pendingInstantDistanceKm = 0,
        samples = {},
        clock = 0,
        lastX = nil,
        lastY = nil,
        lastFuel = nil,
    }
    resetTripState(state, vehicle)
    return state
end

local function pruneInstantSamples(state)
    local cutoff = state.clock - INSTANT_MPG_WINDOW_SECONDS
    while #state.samples > 0 and state.samples[1].time < cutoff do
        local sample = table.remove(state.samples, 1)
        state.instantDistanceKm = math.max(0, state.instantDistanceKm - sample.distanceKm)
        state.instantFuelLitres = math.max(0, state.instantFuelLitres - sample.fuelLitres)
    end
end

local function updateTripState(dashboard, dt)
    local vehicle = dashboard.vehicle
    local state = dashboard.__YourDashSportTrip
    local created = false
    if not state or state.vehicle ~= vehicle then
        state = newTripState(vehicle)
        dashboard.__YourDashSportTrip = state
        created = true
    end
    state.justReset = created
    if not vehicle then return state end

    dt = clamp(dt or 0, 0, 0.25)
    state.clock = state.clock + dt
    local running = safeCall(vehicle, "isEngineRunning") == true
    local x = finiteNumber(safeCall(vehicle, "getX"))
    local y = finiteNumber(safeCall(vehicle, "getY"))
    local fuel = getFuelAmount(vehicle)

    if running and not state.engineWasRunning then
        resetTripState(state, vehicle)
        state.clock = state.clock + dt
        x, y, fuel = state.lastX, state.lastY, state.lastFuel
    elseif running then
        local distanceKm = 0
        if x and y and state.lastX and state.lastY then
            local dx, dy = x - state.lastX, y - state.lastY
            local distanceSquares = math.sqrt(dx * dx + dy * dy)
            if distanceSquares <= TELEPORT_STEP_LIMIT_SQUARES then
                -- Matches B42's own ISVehicleRoadtripDebug conversion.
                distanceKm = distanceSquares / 100
            end
        end

        local fuelLitres = 0
        if fuel and state.lastFuel and state.lastFuel > fuel then
            fuelLitres = state.lastFuel - fuel
        elseif fuel and state.lastFuel and fuel > state.lastFuel then
            -- Refuelling never counts as negative consumption.  It also starts
            -- a fresh instant-measurement interval so pre-fill distance is not
            -- paired with a later post-fill tank decrement.
            state.pendingInstantDistanceKm = 0
        end

        state.distanceKm = state.distanceKm + distanceKm
        state.fuelLitres = state.fuelLitres + fuelLitres
        state.pendingInstantDistanceKm = (state.pendingInstantDistanceKm or 0) + distanceKm
        -- B42 replicates tank amounts in discrete steps.  Commit distance only
        -- when its matching positive fuel decrement arrives; otherwise merely
        -- hold the last valid instant MPG instead of letting zero-fuel frames
        -- inflate the rolling ratio.
        if fuelLitres > 0 then
            local pairedDistanceKm = state.pendingInstantDistanceKm or 0
            table.insert(state.samples, {
                time = state.clock,
                distanceKm = pairedDistanceKm,
                fuelLitres = fuelLitres,
            })
            state.instantDistanceKm = state.instantDistanceKm + pairedDistanceKm
            state.instantFuelLitres = state.instantFuelLitres + fuelLitres
            state.pendingInstantDistanceKm = 0
        end
    end

    state.engineWasRunning = running
    state.lastX, state.lastY, state.lastFuel = x, y, fuel
    pruneInstantSamples(state)
    return state
end

local function mpgFrom(distanceKm, fuelLitres)
    distanceKm = math.max(0, tonumber(distanceKm) or 0)
    fuelLitres = math.max(0, tonumber(fuelLitres) or 0)
    -- Fuel replication is quantized, especially in multiplayer.  Returning no
    -- sample here lets the display hold its last valid value instead of jumping
    -- to 99.9 between discrete tank updates.
    if fuelLitres <= 0.000001 then return nil end
    if distanceKm <= 0.000001 then return 0 end
    return clamp(distanceKm / fuelLitres * MPG_KM_PER_LITRE_TO_US, 0, 99.9)
end

function ISVehicleDashboard:_YourDashSportRefreshCaches(dt)
    local state = updateTripState(self, dt)
    local cache = self.__YourDashSportCache
    if not cache then
        cache = { fastAge = 0.5, averageAge = 2.5, instantMpg = 0, averageMpg = 0 }
        self.__YourDashSportCache = cache
    end
    if state.justReset then
        cache.instantMpg, cache.averageMpg = 0, 0
    end
    cache.fastAge = (cache.fastAge or 0) + dt
    cache.averageAge = (cache.averageAge or 0) + dt

    if cache.fastAge >= 0.5 then
        cache.fastAge = cache.fastAge - 0.5
        local kph = math.abs(finiteNumber(safeCall(self.vehicle, "getCurrentSpeedKmHour")) or 0)
        cache.kph = clamp(kph, 0, 199)
        cache.mph = clamp(kph * 0.621371192237, 0, 199)
        local instantMpg = mpgFrom(state.instantDistanceKm, state.instantFuelLitres)
        if instantMpg ~= nil then cache.instantMpg = instantMpg end
        cache.engineCondition = getEngineCondition(self.vehicle)
    end
    if cache.averageAge >= 2.5 then
        cache.averageAge = cache.averageAge - 2.5
        local averageMpg = mpgFrom(state.distanceKm, state.fuelLitres)
        if averageMpg ~= nil then cache.averageMpg = averageMpg end
    end
end

function ISVehicleDashboard:_YourDashSportMainText()
    local cache = self.__YourDashSportCache or {}
    local mode = self.__YourDashSportMainMode or MAIN_MODE_MPH
    if mode == MAIN_MODE_KPH then
        return string.format("%d KM/H", roundNearest(clamp(cache.kph or 0, 0, 199)))
    elseif mode == MAIN_MODE_INSTANT_MPG then
        return string.format("%.1f MPG", clamp(cache.instantMpg or 0, 0, 99.9))
    elseif mode == MAIN_MODE_AVERAGE_MPG then
        return string.format("AVG %.1f", clamp(cache.averageMpg or 0, 0, 99.9))
    elseif mode == MAIN_MODE_ENGINE_CONDITION then
        return string.format("ENG %d%%", roundNearest(clamp(cache.engineCondition or 0, 0, 100)))
    end
    return string.format("%d MPH", roundNearest(clamp(cache.mph or 0, 0, 199)))
end

function ISVehicleDashboard:_YourDashSportMainRows()
    local cache = self.__YourDashSportCache or {}
    local mode = self.__YourDashSportMainMode or MAIN_MODE_MPH
    if mode == MAIN_MODE_INSTANT_MPG then
        return "CURRENT", string.format("%.1f MPG", clamp(cache.instantMpg or 0, 0, 99.9))
    elseif mode == MAIN_MODE_AVERAGE_MPG then
        return "AVG", string.format("%.1f MPG", clamp(cache.averageMpg or 0, 0, 99.9))
    end
    return nil, self:_YourDashSportMainText()
end

function ISVehicleDashboard:_YourDashSportACRows()
    local mode = self.__YourDashSportACMode or AC_MODE_INSIDE
    local celsius, label
    if mode == AC_MODE_OUTSIDE then
        label, celsius = "OUT", getOutsideTemperature(self)
    elseif mode == AC_MODE_SET then
        local _, _, raw = getHeaterState(self.vehicle)
        local index = nearestLevelIndex(raw)
        label, celsius = "SET", AC_SETPOINTS_C[index]
    else
        label, celsius = "IN", getInsideTemperature(self)
    end
    local value = tostring(displayTemperatureValue(celsius)) .. DEGREE_SYMBOL .. temperatureUnitLetter()
    return label, value
end

function ISVehicleDashboard:_YourDashSportACText()
    local label, value = self:_YourDashSportACRows()
    return label .. " " .. value
end

local function drawCentered(layer, text, rect, red, green, blue, maximumZoom)
    if not layer or not rect or not text then return end
    local font = YourDash.GetUIFont and YourDash.GetUIFont() or (UIFont and UIFont.Small)
    local x, y = scaled(rect.x or 0), scaled(rect.y or 0)
    local width, height = scaled(rect.width or 0), scaled(rect.height or 0)
    local opticalOffsetX = scaled(rect.textOffsetX or 0)
    local fontHeight = YourDash.FontHeightForScale and YourDash.FontHeightForScale() or nil
    local textWidth = nil
    if not fontHeight and getTextManager and font then
        local ok, manager = pcall(getTextManager)
        if ok and manager then fontHeight = safeCall(manager, "getFontHeight", font) end
    end
    if getTextManager and font then
        local ok, manager = pcall(getTextManager)
        if ok and manager then textWidth = safeCall(manager, "MeasureStringX", font, text) end
    end
    fontHeight = tonumber(fontHeight) or height

    -- B42's smallest normal UI font is still 16 px high.  The authored 0.75x
    -- sport LCDs are narrower than several valid temperature/MPG strings, so
    -- fit only overflowing text with the engine's zoomed-text renderer.  This
    -- preserves the complete label and configured C/F unit instead of clipping
    -- or changing the information at the smallest dashboard size.
    textWidth = tonumber(textWidth)
    if textWidth and textWidth > 0 and layer.drawTextZoomed then
        local availableWidth = math.max(1, width - 2)
        local availableHeight = math.max(1, height - 1)
        local zoom = math.min(maximumZoom or 1, availableWidth / textWidth, availableHeight / fontHeight)
        if zoom < 0.999 then
            layer:drawTextZoomed(text,
                x + (width - textWidth * zoom) / 2 + opticalOffsetX,
                y + (height - fontHeight * zoom) / 2,
                zoom, red, green, blue, 1, font)
            return
        end
    end
    layer:drawTextCentre(text, x + width / 2 + opticalOffsetX, y + (height - fontHeight) / 2,
        red, green, blue, 1, font)
end

-- The bitmap UI fonts reserve almost half of each line-height above/below the
-- visible capital/digit pixels.  Treating two LCD rows as disjoint line boxes
-- therefore makes the first row needlessly tiny.  These ratios cover the
-- measured Small/Medium/Large B42 fonts (4/6/6 px top bearing and at most
-- 9/12/14 px visible ink in 16/23/26 px line heights).
local LCD_INK_TOP_RATIO = 0.25
local LCD_INK_HEIGHT_RATIO = 0.56
local LCD_MAX_LABEL_ZOOM = 1.00
local LCD_MAX_VALUE_ZOOM = 1.25

local function drawPackedLCDText(layer, text, x, width, originY, textWidth, zoom,
        opticalOffsetX, red, green, blue, font)
    if math.abs(zoom - 1) > 0.001 and layer.drawTextZoomed then
        layer:drawTextZoomed(text,
            x + (width - textWidth * zoom) / 2 + opticalOffsetX,
            originY, zoom, red, green, blue, 1, font)
        return
    end
    layer:drawTextCentre(text, x + width / 2 + opticalOffsetX, originY,
        red, green, blue, 1, font)
end

local function drawTwoLineDisplay(layer, label, value, rect, red, green, blue)
    if not layer or not rect or not label or not value then return end
    local font = YourDash.GetUIFont and YourDash.GetUIFont() or (UIFont and UIFont.Small)
    local x, y = scaled(rect.x or 0), scaled(rect.y or 0)
    local width, height = scaled(rect.width or 0), scaled(rect.height or 0)
    local opticalOffsetX = scaled(rect.textOffsetX or 0)
    local fontHeight = YourDash.FontHeightForScale and YourDash.FontHeightForScale() or nil
    local labelWidth, valueWidth = nil, nil
    if getTextManager and font then
        local ok, manager = pcall(getTextManager)
        if ok and manager then
            fontHeight = fontHeight or safeCall(manager, "getFontHeight", font)
            labelWidth = safeCall(manager, "MeasureStringX", font, label)
            valueWidth = safeCall(manager, "MeasureStringX", font, value)
        end
    end
    fontHeight = tonumber(fontHeight)
    labelWidth, valueWidth = tonumber(labelWidth), tonumber(valueWidth)

    -- Retain the conservative legacy path if a custom font manager does not
    -- expose measurements.  Normal B42 clients always use the packed path.
    if not fontHeight or fontHeight <= 0 or not labelWidth or labelWidth <= 0 or
            not valueWidth or valueWidth <= 0 then
        local labelHeight = math.max(1, math.floor((tonumber(rect.height) or 0) * 0.35))
        local valueHeight = math.max(1, (tonumber(rect.height) or 0) - labelHeight)
        drawCentered(layer, label, {
            x = rect.x, y = rect.y, width = rect.width, height = labelHeight,
            textOffsetX = rect.textOffsetX,
        }, red, green, blue, 0.72)
        drawCentered(layer, value, {
            x = rect.x, y = (rect.y or 0) + labelHeight,
            width = rect.width, height = valueHeight,
            textOffsetX = rect.textOffsetX,
        }, red, green, blue, 1.0)
        return
    end

    local availableWidth = math.max(1, width - 2)
    local labelZoom = math.min(LCD_MAX_LABEL_ZOOM, availableWidth / labelWidth)
    local valueZoom = math.min(LCD_MAX_VALUE_ZOOM, availableWidth / valueWidth)
    local inkTop = fontHeight * LCD_INK_TOP_RATIO
    local inkHeight = fontHeight * LCD_INK_HEIGHT_RATIO
    local gap = math.max(1, scaled(1))

    -- Width is fitted first.  If an unusually large/custom font still makes
    -- the measured ink stack too tall, reduce both rows proportionally.
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

    drawPackedLCDText(layer, label, x, width, labelOriginY, labelWidth, labelZoom,
        opticalOffsetX, red, green, blue, font)
    drawPackedLCDText(layer, value, x, width, valueOriginY, valueWidth, valueZoom,
        opticalOffsetX, red, green, blue, font)
end

function ISVehicleDashboard:_YourDashSportDrawOverlay(layer)
    if (self.__YourDashFamily or "standard") ~= "sport" or not self.vehicle then return end
    local layout = YourDash.GetLayout and YourDash.GetLayout(self) or nil
    if not layout then return end

    if layout.displays and layout.displays.main then
        local label, value = self:_YourDashSportMainRows()
        if label then
            drawTwoLineDisplay(layer, label, value, layout.displays.main, 0.13, 0.07, 0.02)
        else
            drawCentered(layer, value, layout.displays.main, 0.13, 0.07, 0.02)
        end
    end

    local _, heaterActive = getHeaterState(self.vehicle)
    if heaterActive and layout.ac and layout.ac.display then
        local label, value = self:_YourDashSportACRows()
        drawTwoLineDisplay(layer, label, value, layout.ac.display, 0.10, 0.13, 0.04)
    end

    local clock = layout.clock
    local textures = self.__YourDashSportTextures or {}
    if clock and clock.background and textures.clock then
        local clockX, clockY = scaled(clock.background.x), scaled(clock.background.y)
        local clockW, clockH = actualTextureSize(textures.clock)
        layer:drawTextureScaled(textures.clock, clockX, clockY, clockW, clockH, 1)

        local gameTime = nil
        if getGameTime then
            local ok, value = pcall(getGameTime)
            if ok then gameTime = value end
        end
        if not gameTime and GameTime and GameTime.getInstance then
            local ok, value = pcall(GameTime.getInstance)
            if ok then gameTime = value end
        end
        local hourValue = gameTime and finiteNumber(safeCall(gameTime, "getHour")) or nil
        local minute = gameTime and finiteNumber(safeCall(gameTime, "getMinutes")) or nil
        if hourValue == nil or minute == nil then
            local timeOfDay = gameTime and finiteNumber(safeCall(gameTime, "getTimeOfDay")) or 0
            timeOfDay = (timeOfDay or 0) % 24
            hourValue = math.floor(timeOfDay)
            minute = (timeOfDay % 1) * 60
        end
        local hour = (hourValue % 12) + minute / 60
        -- The exported clock face is trimmed by a pixel or two in the larger
        -- packs, so derive the hand pivot from its real dimensions instead of
        -- scaling the 1x center independently.
        local pivotX, pivotY = clockX + clockW / 2, clockY + clockH / 2
        -- DrawTextureAngle advances clockwise for these authored hand assets.
        if textures.clockHour then
            layer:DrawTextureAngle(textures.clockHour, pivotX, pivotY, hour * 30)
        end
        if textures.clockMinute then
            layer:DrawTextureAngle(textures.clockMinute, pivotX, pivotY, minute * 6)
        end
    end
end

function ISVehicleDashboard:_YourDashSportLoadTextures(force)
    local scaleKey = YourDash.GetScaleKey and YourDash.GetScaleKey() or "1x"
    if not force and self.__YourDashSportTextureKey == scaleKey then return end
    self.__YourDashSportTextureKey = scaleKey
    local function texture(name)
        return YourDash.GetDashboardTexture("sport", "dash", name)
    end
    self.__YourDashSportTextures = {
        acOff = texture("ac_off.png"),
        acOn = texture("ac_on.png"),
        fanButton = texture("fan_btn.png"),
        acDisplayButton = texture("disp_btn_ac.png"),
        tempKnob = texture("temp_slider.png"),
        gaugeDisplayButton = texture("disp_btn_gauge.png"),
        clock = texture("clock.png"),
        clockMinute = texture("clock_needle_long.png"),
        clockHour = texture("clock_needle_short.png"),
    }
end

function ISVehicleDashboard:onYourDashSportGaugeDisplay()
    self.__YourDashSportMainMode = ((self.__YourDashSportMainMode or MAIN_MODE_MPH) % MAIN_MODE_COUNT) + 1
    playCharacterSound(self, "VehicleACButton")
end

function ISVehicleDashboard:onYourDashSportACDisplay()
    self.__YourDashSportACMode = ((self.__YourDashSportACMode or AC_MODE_INSIDE) % AC_MODE_COUNT) + 1
    playCharacterSound(self, "VehicleACButton")
end

function ISVehicleDashboard:onYourDashSportFan()
    if getGameSpeed and getGameSpeed() == 0 then return end
    if getGameSpeed and getGameSpeed() > 1 and setGameSpeed then setGameSpeed(1) end
    local heater, active, raw = getHeaterState(self.vehicle)
    if not heater or not hasHeaterPower(self.vehicle) then return end
    if sendHeaterCommand(self, not active, raw) then playCharacterSound(self, "VehicleACButton") end
end

function ISVehicleDashboard:_YourDashSportKnobChanged(knob)
    if not knob or not self.vehicle or not hasHeaterPower(self.vehicle) then return end
    local heater, active = getHeaterState(self.vehicle)
    if not heater then return end
    local raw = knob:getValue()
    self.__YourDashSportACMode = AC_MODE_SET
    self.__YourDashSportTempIndex = nearestLevelIndex(raw)
    if sendHeaterCommand(self, active, raw) then playCharacterSound(self, "VehicleACSetTemperature") end
end

function ISVehicleDashboard:_YourDashSportCreateKnob(texture)
    if not texture or not ISKnob then return nil end
    local knob = ISKnob:new(0, 0, texture, nil, "", self.character)
    knob:initialise()
    knob:instantiate()
    knob.target = self
    knob.switchSound = "KnobSwitch"
    knob.onMouseUpFct = ISVehicleDashboard._YourDashSportKnobChanged
    knob:addValue(0, 0)
    knob:addValue(30, 8)
    knob:addValue(60, 15)
    knob:addValue(90, 25)
    knob:addValue(270, -25)
    knob:addValue(300, -15)
    knob:addValue(330, -8)

    local vanillaMouseDown = knob.onMouseDown
    function knob:onMouseDown(x, y)
        if self.__disabled then return false end
        return vanillaMouseDown(self, x, y)
    end

    function knob:render()
        local value = self.values and self.values[self.selected]
        if self.tex and value then
            self:DrawTextureAngle(self.tex, self.width / 2, self.height / 2, value.angle)
        end
    end

    -- Same snap sectors as the vanilla vehicle AC knob, with the center at
    -- the actual compact sprite center (the stock panel reserves 20px title).
    function knob:onMouseMove(dx, dy)
        if self.__disabled or not self.dragging then return end
        local mouseX, mouseY = self:getMouseX(), self:getMouseY()
        local radians = math.atan2(mouseY - self.height / 2, mouseX - self.width / 2) + math.pi
        local degrees = (radians * 180 / math.pi + 270) % 360
        local previousSelection = self.selected
        local lastAngle = self.values[#self.values].angle
        if degrees >= lastAngle + (360 - lastAngle) / 2 then
            self.selected = 1
        else
            local previousAngle = 0
            for index = 1, #self.values do
                local angle = self.values[index].angle
                local nextAngle = (index == #self.values) and 360 or self.values[index + 1].angle
                if degrees >= previousAngle + (angle - previousAngle) / 2 and
                    degrees < angle + (nextAngle - angle) / 2
                then
                    self.selected = index
                    break
                end
                previousAngle = angle
            end
        end
        if previousSelection ~= self.selected then
            self:playSwitchSound()
            if self.target then
                self.target.__YourDashSportACMode = AC_MODE_SET
                self.target.__YourDashSportTempIndex = nearestLevelIndex(self:getValue())
            end
        end
    end
    knob.onMouseMoveOutside = knob.onMouseMove

    self:addChild(knob)
    return knob
end

function ISVehicleDashboard:_YourDashSportEnsureControls()
    self:_YourDashSportLoadTextures(false)
    local textures = self.__YourDashSportTextures or {}

    if not self.__YourDashSportACBackground and textures.acOff then
        self.__YourDashSportACBackground = makeImage(self, textures.acOff)
    end
    if self.__YourDashSportACBackground and textures.acOff then
        setImageTexture(self, self.__YourDashSportACBackground, textures.acOff)
        -- The AC bezel is a separately-exported visual layer.  ISImage's
        -- background alpha is also its texture opacity, so keep it opaque
        -- while making it mouse-transparent.
        self.__YourDashSportACBackground.backgroundColor = { r=1, g=1, b=1, a=1 }
        setMouseTransparent(self.__YourDashSportACBackground)
    end

    if not self.__YourDashSportOverlay then
        local layer = ISPanel:new(0, 0, 1, 1)
        layer:initialise()
        layer:instantiate()
        layer.backgroundColor = { r = 0, g = 0, b = 0, a = 0 }
        layer.borderColor = { r = 0, g = 0, b = 0, a = 0 }
        layer.target = self
        setMouseTransparent(layer)
        function layer:prerender() end
        function layer:render()
            if self.target then self.target:_YourDashSportDrawOverlay(self) end
        end
        self:addChild(layer)
        self.__YourDashSportOverlay = layer
    end

    if not self.__YourDashSportGaugeDisplayButton and textures.gaugeDisplayButton then
        local button = makeImage(self, textures.gaugeDisplayButton)
        button.target = self
        button.onclick = ISVehicleDashboard.onYourDashSportGaugeDisplay
        button.mouseovertext = "Cycle gauge display"
        if self._installPressedEffect then self:_installPressedEffect(button, 0.96) end
        self.__YourDashSportGaugeDisplayButton = button
    end
    if not self.__YourDashSportFanButton and textures.fanButton then
        local button = makeImage(self, textures.fanButton)
        button.target = self
        button.onclick = ISVehicleDashboard.onYourDashSportFan
        if self._installPressedEffect then self:_installPressedEffect(button, 0.96) end
        self.__YourDashSportFanButton = button
    end
    if not self.__YourDashSportACDisplayButton and textures.acDisplayButton then
        local button = makeImage(self, textures.acDisplayButton)
        button.target = self
        button.onclick = ISVehicleDashboard.onYourDashSportACDisplay
        button.mouseovertext = "Cycle climate display"
        if self._installPressedEffect then self:_installPressedEffect(button, 0.96) end
        self.__YourDashSportACDisplayButton = button
    end
    if not self.__YourDashSportTempKnob and textures.tempKnob then
        self.__YourDashSportTempKnob = self:_YourDashSportCreateKnob(textures.tempKnob)
    end

    -- Refresh existing child textures after a scale change.
    setImageTexture(self, self.__YourDashSportGaugeDisplayButton, textures.gaugeDisplayButton)
    setImageTexture(self, self.__YourDashSportFanButton, textures.fanButton)
    setImageTexture(self, self.__YourDashSportACDisplayButton, textures.acDisplayButton)
    if self.__YourDashSportTempKnob and textures.tempKnob then
        local width, height = actualTextureSize(textures.tempKnob)
        self.__YourDashSportTempKnob.tex = textures.tempKnob
        self.__YourDashSportTempKnob:setWidth(width)
        self.__YourDashSportTempKnob:setHeight(height)
    end
end

function ISVehicleDashboard:_YourDashSportPositionControls()
    if not self.backgroundTex then return end
    self:_YourDashSportEnsureControls()
    local layout = YourDash.GetLayout and YourDash.GetLayout(self) or nil
    local controls = layout and layout.controls or nil
    local ac = layout and layout.ac or nil
    if not controls or not ac then return end
    local baseX, baseY = self.backgroundTex:getX(), self.backgroundTex:getY()

    local function position(element, point)
        if not element or not point then return end
        element:setX(baseX + scaled(point.x or 0))
        element:setY(baseY + scaled(point.y or 0))
    end

    position(self.__YourDashSportGaugeDisplayButton, controls.gaugeDisplayButton)
    position(self.__YourDashSportACBackground, ac.background)
    position(self.__YourDashSportFanButton, ac.fan)
    position(self.__YourDashSportACDisplayButton, ac.displayButton)
    position(self.__YourDashSportTempKnob, ac.knob)

    if self.__YourDashSportOverlay then
        self.__YourDashSportOverlay:setX(baseX)
        self.__YourDashSportOverlay:setY(baseY)
        self.__YourDashSportOverlay:setWidth(self.backgroundTex:getWidth())
        self.__YourDashSportOverlay:setHeight(self.backgroundTex:getHeight())
    end
end

function ISVehicleDashboard:_YourDashSportUpdateVisibility()
    local sport = self.vehicle ~= nil and (self.__YourDashFamily or "standard") == "sport"
    local heater = sport and getHeaterState(self.vehicle) or nil
    local hasHeater = heater ~= nil

    if self.__YourDashSportOverlay then self.__YourDashSportOverlay:setVisible(sport) end
    if self.__YourDashSportGaugeDisplayButton then self.__YourDashSportGaugeDisplayButton:setVisible(sport) end
    -- The sport AC bezel is permanent dashboard artwork; only its controls are
    -- conditional on the vehicle actually exposing a heater.
    if self.__YourDashSportACBackground then self.__YourDashSportACBackground:setVisible(sport) end
    if self.__YourDashSportFanButton then self.__YourDashSportFanButton:setVisible(sport and hasHeater) end
    if self.__YourDashSportACDisplayButton then self.__YourDashSportACDisplayButton:setVisible(sport and hasHeater) end
    if self.__YourDashSportTempKnob then self.__YourDashSportTempKnob:setVisible(sport and hasHeater) end

    if sport then
        -- These are the standard/heavy linear controls owned by the existing
        -- AC module; the sport dashboard supplies its own rotary controls.
        if self.heaterTex then self.heaterTex:setVisible(false) end
        if self.acTempSlider then self.acTempSlider:setVisible(false) end
        if self.__YourDashACBackground then self.__YourDashACBackground:setVisible(false) end
    end
end

function ISVehicleDashboard:_YourDashSportUpdateAC()
    if (self.__YourDashFamily or "standard") ~= "sport" or not self.vehicle then return end
    local heater, active, raw = getHeaterState(self.vehicle)
    local textures = self.__YourDashSportTextures or {}
    if not heater then
        -- The bezel remains part of every sport dashboard, but a vehicle with
        -- no heater must never inherit the lit state from the previous car.
        if textures.acOff and self.__YourDashSportACBackground then
            setImageTexture(self, self.__YourDashSportACBackground, textures.acOff)
        end
        return
    end
    local backgroundTexture = active and textures.acOn or textures.acOff
    if backgroundTexture then setImageTexture(self, self.__YourDashSportACBackground, backgroundTexture) end

    local powered = hasHeaterPower(self.vehicle)
    if self.__YourDashSportFanButton then
        self.__YourDashSportFanButton.__disabled = not powered
        self.__YourDashSportFanButton.onclick = powered and ISVehicleDashboard.onYourDashSportFan or nil
        self.__YourDashSportFanButton.target = self
    end
    if self.__YourDashSportTempKnob then
        self.__YourDashSportTempKnob.__disabled = not powered
        if not self.__YourDashSportTempKnob.dragging then
            local index = nearestLevelIndex(raw)
            self.__YourDashSportTempIndex = index
            self.__YourDashSportTempKnob:setKnobPosition(AC_RAW_LEVELS[index])
        end
    end
end

local oldCreateChildren = ISVehicleDashboard.createChildren
local oldSetVehicle = ISVehicleDashboard.setVehicle
local oldOnResolutionChange = ISVehicleDashboard.onResolutionChange
local oldPrerender = ISVehicleDashboard.prerender

function ISVehicleDashboard:createChildren()
    self.__YourDashSportCreatingChildren = true
    if oldCreateChildren then oldCreateChildren(self) end
    self.__YourDashSportCreatingChildren = false
    self.__YourDashSportMainMode = self.__YourDashSportMainMode or MAIN_MODE_MPH
    self.__YourDashSportACMode = self.__YourDashSportACMode or AC_MODE_INSIDE
    self:_YourDashSportEnsureControls()
    self:_YourDashSportPositionControls()
    self:_YourDashSportUpdateVisibility()
    if self._YourDashFinalizeWearOrder then self:_YourDashFinalizeWearOrder() end
end

function ISVehicleDashboard:setVehicle(vehicle)
    local previousVehicle = self.vehicle
    if oldSetVehicle then oldSetVehicle(self, vehicle) end
    if previousVehicle ~= vehicle then
        self.__YourDashSportTrip = newTripState(vehicle)
        self.__YourDashSportCache = { fastAge = 0.5, averageAge = 2.5 }
        self.__YourDashSportMainMode = MAIN_MODE_MPH
        self.__YourDashSportACMode = AC_MODE_INSIDE
    end
    self:_YourDashSportEnsureControls()
    self:_YourDashSportPositionControls()
    self:_YourDashSportUpdateVisibility()
    if self._YourDashFinalizeWearOrder then self:_YourDashFinalizeWearOrder() end
end

function ISVehicleDashboard:onResolutionChange()
    if oldOnResolutionChange then oldOnResolutionChange(self) end
    -- Vanilla calls this virtually from the middle of createChildren().  Wait
    -- until the wrapped chain has finished so our overlay remains the topmost
    -- dashboard layer and the sport buttons remain clickable.
    if self.__YourDashSportCreatingChildren then return end
    self:_YourDashSportLoadTextures(false)
    self:_YourDashSportEnsureControls()
    self:_YourDashSportPositionControls()
    self:_YourDashSportUpdateVisibility()
    if self._YourDashFinalizeWearOrder then self:_YourDashFinalizeWearOrder() end
end

function ISVehicleDashboard:prerender()
    if oldPrerender then oldPrerender(self) end
    if not self.vehicle or not ISUIHandler.allUIVisible then
        self:_YourDashSportUpdateVisibility()
        return
    end
    self:_YourDashSportLoadTextures(false)
    self:_YourDashSportEnsureControls()
    self:_YourDashSportPositionControls()
    self:_YourDashSportUpdateVisibility()
    if self._YourDashFinalizeWearOrder then self:_YourDashFinalizeWearOrder() end
    if (self.__YourDashFamily or "standard") ~= "sport" then return end

    local dt = UIManager and UIManager.getSecondsSinceLastRender and UIManager.getSecondsSinceLastRender() or (1 / 30)
    dt = clamp(dt or (1 / 30), 0, 0.25)
    self:_YourDashSportRefreshCaches(dt)
    self:_YourDashSportUpdateAC()
end
