-- media/lua/client/YourDash/Z_PatchVehicleDashboard.lua
if isServer() then return end

-- Load vanilla
require "Vehicles/ISUI/ISVehicleDashboard"
require "Vehicles/ISUI/ISVehiclePartMenu"
require "Vehicles/ISUI/ISVehicleMenu"
require "ISUI/ISPanel"
require "YourDash/DashboardCore"


-- Guard: don’t patch twice
if ISVehicleDashboard.__YourDashPatched then return end
ISVehicleDashboard.__YourDashPatched = true

-- B42 UI elements consume mouse input by default, even when they have no
-- onclick handler.  All full-canvas and decorative layers must explicitly use
-- the Lua wrapper below or they sit above and block the real dashboard buttons.
local function YourDash_SetMouseTransparent(element)
    if not element then return end
    element.wantMouseEvents = false
    if element.setWantMouseEvents then
        element:setWantMouseEvents(false)
    elseif element.javaObject and element.javaObject.setConsumeMouseEvents then
        element.javaObject:setConsumeMouseEvents(false)
    end
end

local function YourDash_ButtonTexture(name)
    if not name or not getTexture then return nil end
    local scaleKey = YourDash.GetScaleKey and YourDash.GetScaleKey() or "1x"
    local ok, texture = pcall(getTexture, string.format("media/ui/vehicles/buttons/%s/%s", scaleKey, name))
    if ok then return texture end
    return nil
end

-- The sport warning exports keep the authored warning tile unchanged but add
-- a blurred glow canvas around it.  These are exact source-pixel insets for
-- each authored texture pack; using a calculated scale would put 1.4x one
-- pixel off because that export rounds its inset up to 51 pixels.
local SPORT_WARNING_GLOW_INSET = {
    ["0.75x"] = 27,
    ["1x"] = 36,
    ["1.4x"] = 51,
    ["2x"] = 72,
}

local function YourDash_Text(key, fallback)
    if getText then
        local ok, text = pcall(getText, key)
        if ok and text and text ~= key then return text end
    end
    return fallback or key
end

local function YourDash_IsMouseOver(element)
    if not element or not element.isMouseOver then return false end
    local ok, value = pcall(element.isMouseOver, element)
    return ok and value == true
end

local function YourDash_UpdateHoverAlpha(element)
    if not element then return end
    element.alpha = YourDash_IsMouseOver(element) and 1.0 or 0.5
end

local function YourDash_IsSeatInstalled(vehicle, seat)
    if not vehicle or seat == nil then return false end
    if vehicle.isSeatInstalled then
        local ok, installed = pcall(vehicle.isSeatInstalled, vehicle, seat)
        if ok then return installed == true end
    end
    if vehicle.getPartForSeatContainer then
        local ok, part = pcall(vehicle.getPartForSeatContainer, vehicle, seat)
        return ok and part ~= nil
    end
    return false
end

local function YourDash_ServerBool(name, default)
    if not isClient or not isClient() then return default end
    local options = getServerOptions and getServerOptions() or nil
    if options and options.getBoolean then
        local ok, value = pcall(options.getBoolean, options, name)
        if ok then return value == true end
    end
    return default
end

local function YourDash_CanSleepInVehicle(playerObj, vehicle)
    if not playerObj or not vehicle then return false, YourDash_Text("ContextMenu_Sleep", "sleep") end
    if isClient and isClient() and not YourDash_ServerBool("SleepAllowed", false) then
        return false, YourDash_Text("ContextMenu_Sleep", "sleep")
    end

    local sleepNeeded = (not isClient or not isClient()) or YourDash_ServerBool("SleepNeeded", false)
    local stats = playerObj.getStats and playerObj:getStats() or nil
    if sleepNeeded and stats and stats.get and CharacterStat and CharacterStat.FATIGUE and
            stats:get(CharacterStat.FATIGUE) <= 0.3 then
        return false, YourDash_Text("IGUI_Sleep_NotTiredEnough", "not tired enough")
    end

    if vehicle.isStopped and not vehicle:isStopped() then
        return false, YourDash_Text("IGUI_PlayerText_CanNotSleepInMovingCar", "cannot sleep in a moving car")
    end

    if sleepNeeded and stats then
        local zombies = (stats.getNumVisibleZombies and stats:getNumVisibleZombies() > 0) or
            (stats.getNumChasingZombies and stats:getNumChasingZombies() > 0) or
            (stats.getNumVeryCloseZombies and stats:getNumVeryCloseZombies() > 0)
        if zombies then
            return false, YourDash_Text("IGUI_Sleep_NotSafe", "not safe")
        end
    end

    if sleepNeeded and playerObj.getHoursSurvived and playerObj.getLastHourSleeped and
            ((playerObj:getHoursSurvived() - playerObj:getLastHourSleeped()) <= 1) then
        return false, YourDash_Text("ContextMenu_NoSleepTooEarly", "too early to sleep")
    end

    local sleepingTabletEffect = playerObj.getSleepingTabletEffect and (playerObj:getSleepingTabletEffect() or 0) or 0
    if sleepingTabletEffect < 2000 then
        local moodles = playerObj.getMoodles and playerObj:getMoodles() or nil
        local fatigue = stats and stats.get and CharacterStat and CharacterStat.FATIGUE and stats:get(CharacterStat.FATIGUE) or 1
        if moodles and moodles.getMoodleLevel and MoodleType then
            if MoodleType.PAIN and moodles:getMoodleLevel(MoodleType.PAIN) >= 2 and fatigue <= 0.85 then
                return false, YourDash_Text("ContextMenu_PainNoSleep", "too much pain")
            end
            if MoodleType.PANIC and moodles:getMoodleLevel(MoodleType.PANIC) >= 1 then
                return false, YourDash_Text("ContextMenu_PanicNoSleep", "too panicked")
            end
        end
    end

    return true, YourDash_Text("ContextMenu_Sleep", "sleep")
end

local HEAVY_LIGHT_ALIGN_X = { ["0.75x"] = 1, ["1x"] = 2, ["1.4x"] = 3, ["2x"] = 4 }
local HEAVY_LIGHT_HITBOX = {
    ["0.75x"] = { x = 17, y = 17, width = 39, height = 39 },
    ["1x"] = { x = 23, y = 23, width = 51, height = 51 },
    ["1.4x"] = { x = 32, y = 32, width = 72, height = 72 },
    ["2x"] = { x = 46, y = 46, width = 102, height = 102 },
}

-- =========================
-- YourDash: texture-size and damage-overlay options
-- =========================
YourDash = YourDash or {}

-- Use your mod's ID/name here (you listed Mod ID: RealisticDash)
YourDash.MODOPT_ID   = YourDash.MODOPT_ID   or "RealisticDash"
YourDash.MODOPT_NAME = YourDash.MODOPT_NAME or "Realistic Dashboard & Gauges"

-- Native B42 ModOptions option id (ComboBox); DashboardCore owns four entries.
YourDash.OPT_TEXSIZE_ID = "TextureSize"

-- Damage overlay intensity (cracks + stain)
-- 1=Full(90%), 2=Medium(65%), 3=Low(40%), 4=Off(0%)
YourDash.OPT_WEARFX_ID = "WearFX"

YourDash._wearFxLevel = YourDash._wearFxLevel or 1
YourDash._wearFxAlpha = YourDash._wearFxAlpha or 0.90

local function YourDash_WearAlphaFromLevel(level)
    if level == 1 then return 0.90 end
    if level == 2 then return 0.65 end
    if level == 3 then return 0.40 end
    return 0.0
end

function YourDash.GetWearFxAlpha()
    return YourDash._wearFxAlpha or 0.90
end

function YourDash.SetWearFxLevel(level)
    local lv = tonumber(level) or 1
    if lv < 1 then lv = 1 elseif lv > 4 then lv = 4 end
    YourDash._wearFxLevel = lv
    YourDash._wearFxAlpha = YourDash_WearAlphaFromLevel(lv)
end


function YourDash.UseLargeTextures()
    return YourDash.GetScaleKey and YourDash.GetScaleKey() == "2x"
end

local function YourDash_RefreshAllDashboards()
    for playerNum = 0, 3 do
        local dash = getPlayerVehicleDashboard and getPlayerVehicleDashboard(playerNum) or nil
        if dash and dash._YourDashApplyTextureSet then
            dash:_YourDashApplyTextureSet(YourDash.UseLargeTextures())
        end
    end
end

function YourDash.SetUseLargeTextures(v)
    v = (v == true)
    if YourDash.SetTextureSizeIndex then YourDash.SetTextureSizeIndex(v and 4 or 2) end
    YourDash_RefreshAllDashboards()
end

local function YourDash_ReadSavedOption()
    local sizeIndex = YourDash.DEFAULT_TEXTURE_SIZE_INDEX or 2
    local wearLevel = 1

    -- Build 42 native ModOptions
    if PZAPI and PZAPI.ModOptions then
        local sec = PZAPI.ModOptions:getOptions(YourDash.MODOPT_ID)
        if sec then
            local optSize = sec:getOption(YourDash.OPT_TEXSIZE_ID)
            sizeIndex = optSize and optSize:getValue() or sizeIndex

            local optWear = sec:getOption(YourDash.OPT_WEARFX_ID)
            local idxWear = optWear and optWear:getValue() or 1
            wearLevel = idxWear
        end

    -- Optional fallback: Build 41 "ModOptions" mod
    elseif YourDash.OPTIONS_B41 then
        sizeIndex = (YourDash.OPTIONS_B41.UseLargeTextures == true) and 4 or 2
        wearLevel = tonumber(YourDash.OPTIONS_B41.WearFxLevel) or 1
    end

    if YourDash.SetTextureSizeIndex then YourDash.SetTextureSizeIndex(sizeIndex) end
    YourDash.SetWearFxLevel(wearLevel)
end


local function YourDash_RegisterModOptions()
    -- Ensure native ModOptions is loaded (B42)
    pcall(require, "PZAPI/ModOptions")
    if YourDash.RegisterTextureSizeOption then YourDash.RegisterTextureSizeOption() end

    if PZAPI and PZAPI.ModOptions then
        local sec = PZAPI.ModOptions:getOptions(YourDash.MODOPT_ID)
        if not sec then
            sec = PZAPI.ModOptions:create(YourDash.MODOPT_ID, YourDash.MODOPT_NAME)
        end

        if sec and (not sec.__YourDash_Added) then
            sec.__YourDash_Added = true

            sec:addTitle("Damage overlays")
            sec:addDescription("Choose effect opacity for dynamic cracks and stains.")
            local wear = sec:addComboBox(YourDash.OPT_WEARFX_ID, "Cracks & stains intensity", nil)

            wear:addItem("Full (default)", true)
            wear:addItem("Medium", false)
            wear:addItem("Low", false)
            wear:addItem("Off", false)
        end

        if sec then
            local previousApply = sec.apply
            sec.apply = function(self, ...)
                if previousApply then previousApply(self, ...) end
                local optSize = self:getOption(YourDash.OPT_TEXSIZE_ID)
                local idxSize = optSize and optSize:getValue() or (YourDash.DEFAULT_TEXTURE_SIZE_INDEX or 2)
                if YourDash.SetTextureSizeIndex then YourDash.SetTextureSizeIndex(idxSize) end

                local optWear = self:getOption(YourDash.OPT_WEARFX_ID)
                local idxWear = optWear and optWear:getValue() or 1
                YourDash.SetWearFxLevel(idxWear)
            end
        end
    else
        -- Build 41 ModOptions (optional fallback)
        YourDash.OPTIONS_B41 = YourDash.OPTIONS_B41 or { UseLargeTextures = false }
        if ModOptions and ModOptions.getInstance then
            ModOptions:getInstance(YourDash.OPTIONS_B41, YourDash.MODOPT_ID, YourDash.MODOPT_NAME)
        end
    end
end

Events.OnGameBoot.Add(YourDash_RegisterModOptions)
Events.OnGameStart.Add(YourDash_ReadSavedOption)

-- Standard-family 1x fallbacks.  DashboardCore owns the authoritative
-- per-family coordinates and scales them for all four texture packs.
ISVehicleDashboard.WARN_CRUISE_X,  ISVehicleDashboard.WARN_CRUISE_Y  = 388, 127
ISVehicleDashboard.WARN_BATTERY_X, ISVehicleDashboard.WARN_BATTERY_Y = 296, 123
ISVehicleDashboard.WARN_BRAKE_X,   ISVehicleDashboard.WARN_BRAKE_Y   = 295, 97
ISVehicleDashboard.WARN_CHECK_X,   ISVehicleDashboard.WARN_CHECK_Y   = 201, 125
ISVehicleDashboard.WARN_STOP_X,    ISVehicleDashboard.WARN_STOP_Y    = 231, 139
ISVehicleDashboard.WARN_DOOR_X,    ISVehicleDashboard.WARN_DOOR_Y    = 324, 120
ISVehicleDashboard.WARN_FUEL_X,    ISVehicleDashboard.WARN_FUEL_Y    = 325, 97
ISVehicleDashboard.WARN_LIGHT_X,   ISVehicleDashboard.WARN_LIGHT_Y   = 257, 27

ISVehicleDashboard.CTRL_SPEEDREG_X, ISVehicleDashboard.CTRL_SPEEDREG_Y = 388, 127
ISVehicleDashboard.CTRL_GEAR_X,     ISVehicleDashboard.CTRL_GEAR_Y     = 176, 128
ISVehicleDashboard.CTRL_ENGINE_X,   ISVehicleDashboard.CTRL_ENGINE_Y   = 208, 68
ISVehicleDashboard.CTRL_BATTERY_X,  ISVehicleDashboard.CTRL_BATTERY_Y  = 234, 68
ISVehicleDashboard.CTRL_LIGHTS_X,   ISVehicleDashboard.CTRL_LIGHTS_Y   = 66, 130
ISVehicleDashboard.CTRL_IGNITION_X, ISVehicleDashboard.CTRL_IGNITION_Y = 540, 128
ISVehicleDashboard.CTRL_FUEL_ARROW_X, ISVehicleDashboard.CTRL_FUEL_ARROW_Y = 331, 53
ISVehicleDashboard.CTRL_DOOR_X,     ISVehicleDashboard.CTRL_DOOR_Y     = 36, 64
ISVehicleDashboard.CTRL_TRUNK_X,    ISVehicleDashboard.CTRL_TRUNK_Y    = 79, 64
ISVehicleDashboard.CTRL_WINDOW_X,   ISVehicleDashboard.CTRL_WINDOW_Y   = 15, 109

ISVehicleDashboard.GAUGE_DASH_X,  ISVehicleDashboard.GAUGE_DASH_Y  = 0, 0
ISVehicleDashboard.GAUGE_RPM_X,   ISVehicleDashboard.GAUGE_RPM_Y   = 211, 110
ISVehicleDashboard.GAUGE_SPEED_X, ISVehicleDashboard.GAUGE_SPEED_Y = 428, 110
ISVehicleDashboard.GAUGE_FUEL_X,  ISVehicleDashboard.GAUGE_FUEL_Y  = 320, 58

-- Blink tuning for STOP light
ISVehicleDashboard.WARN_STOP_BLINK_HZ   = ISVehicleDashboard.WARN_STOP_BLINK_HZ or 0.7
ISVehicleDashboard.WARN_STOP_BLINK_DIM  = ISVehicleDashboard.WARN_STOP_BLINK_DIM or 0

-- =========================
-- Crash flash (vanilla "hard hit" detection -> 3 quick dips)
-- =========================
ISVehicleDashboard.CRASH_DIM_PULSES      = ISVehicleDashboard.CRASH_DIM_PULSES      or 3
ISVehicleDashboard.CRASH_DIM_PULSE_TIME  = ISVehicleDashboard.CRASH_DIM_PULSE_TIME  or 0.18 -- seconds per dip
ISVehicleDashboard.CRASH_DIM_MIN_ALPHA   = ISVehicleDashboard.CRASH_DIM_MIN_ALPHA   or 0.18 -- how dark at dip bottom
ISVehicleDashboard.CRASH_DIM_SMOOTH_TIME = ISVehicleDashboard.CRASH_DIM_SMOOTH_TIME or 0.03 -- smoothness of dip edges

-- =========================
-- Hook vanilla crash trigger (uses vanilla detection logic)
-- =========================
local _oldDamageFlick = ISVehicleDashboard.damageFlick
function ISVehicleDashboard.damageFlick(character)
    if _oldDamageFlick then _oldDamageFlick(character) end

    -- Start our 3-dip dim sequence on the local player's dashboard
    local dash = nil
    if instanceof(character, "IsoPlayer") and character:isLocalPlayer() then
        dash = getPlayerVehicleDashboard(character:getPlayerNum())
    end
    if dash then
        -- kill vanilla long flicker so we only show our effect
        dash.flickingTimer = 0

        dash.__impactFlashActive = true
        dash.__impactFlashT = 0
        dash.__impactDimAlpha = dash.__impactDimAlpha or 1.0
    end
end

-- =========================
-- Warn-light helpers
-- =========================
function ISVehicleDashboard:_newWarnImage(tex)
    if not tex then return nil end

    local img = ISImage:new(0, 0, tex:getWidthOrig(), tex:getHeightOrig(), tex)
    img:initialise()
    img:instantiate()
    YourDash_SetMouseTransparent(img)

    img.onclick = nil
    img.target = nil
    img.mouseovertext = nil

    img.__fade = 0
    img.backgroundColor = { r=1, g=1, b=1, a=0 } -- start invisible, we’ll fade it

    img:setVisible(false)
    img.__YourDashWarn = true
    function img:render()
        local offTex = self.__offTexture
        if offTex then
            self:drawTextureScaled(offTex, 0, 0, self.width, self.height, 1.0)
        end
        local a = self.backgroundColor and self.backgroundColor.a or 0
        if self.texture and a > 0.001 then
            self:drawTextureScaled(self.texture, 0, 0, self.width, self.height, a)
        end
    end
    self:addChild(img)
    return img
end

function ISVehicleDashboard:_setWarn(img, on, tooltip, alphaMul, dt)
    if not img then return end
    on = (on == true)

    -- dt (pass it from prerender for consistency, but optional)
    if not dt or dt <= 0 then
        dt = UIManager.getSecondsSinceLastRender()
        if not dt or dt <= 0 then dt = 1/30 end
    end

    -- per-icon fade target
    img.__fade = img.__fade or 0
    local targetFade = on and 1.0 or 0.0
    local response = self:_YourDashWarningResponse()
    local fadeTime = on and response.fadeIn or response.fadeOut
    img.__fade = self._ease(img.__fade, targetFade, fadeTime, dt)

    -- global voltage sag dimmer (set in prerender)
    local dim = (self.__elecDimAlpha or 1.0) * (self.__impactDimAlpha or 1.0)

    -- extra alpha multiplier (blink etc)
    local mul = alphaMul or 1.0

    local a = dim * mul * img.__fade

    if a <= 0.01 and not img.__offTexture then
        img:setVisible(false)
    else
        img:setVisible(true)
        if not img.backgroundColor then img.backgroundColor = { r=1, g=1, b=1, a=a } end
        img.backgroundColor.r = 1
        img.backgroundColor.g = 1
        img.backgroundColor.b = 1
        img.backgroundColor.a = a
    end

    -- Tooltip only when logically ON (not during fade-out) (temporary disabled)
    -- img.mouseovertext = on and tooltip or nil
    img.mouseovertext = nil
    img.onclick = nil
    img.target = nil
end

function ISVehicleDashboard:_getEngineCondition()
    if not self.vehicle then return 100 end
    local part = self.vehicle:getPartById("Engine")
    if not part then return 100 end
    local c = part:getCondition()
    if c == nil then return 100 end
    return c
end

function ISVehicleDashboard:_anyDoorOpenOrMissing()
    local v = self.vehicle
    if not v then return false end

    for i = 0, v:getPartCount() - 1 do
        local part = v:getPartByIndex(i)
        if part then
            local door = part:getDoor() -- VehiclePart:getDoor() :contentReference[oaicite:6]{index=6}
            if door then
                -- missing/uninstalled
                if part:getItemType() and not part:getInventoryItem() then
                    return true
                end
                -- open
                if door:isOpen() then -- VehicleDoor:isOpen() :contentReference[oaicite:7]{index=7}
                    return true
                end
            end
        end
    end
    return false
end

-- =========================
-- Smooth dim + fade tuning
-- =========================
ISVehicleDashboard.CRANK_DIM_TIME  = ISVehicleDashboard.CRANK_DIM_TIME  or 0.1  -- seconds to ease in/out

ISVehicleDashboard.WARN_FADE_IN_TIME  = ISVehicleDashboard.WARN_FADE_IN_TIME  or 0.05
ISVehicleDashboard.WARN_FADE_OUT_TIME = ISVehicleDashboard.WARN_FADE_OUT_TIME or 0.1

-- Keep the proven standard response as the baseline while giving each authored
-- cluster its own physical character.  These tables affect presentation only;
-- no vehicle state or gauge mapping is changed.
ISVehicleDashboard.YOURDASH_NEEDLE_RESPONSE = ISVehicleDashboard.YOURDASH_NEEDLE_RESPONSE or {
    standard = { up = 0.30, down = 0.30, voltageDrop = 0.08, voltageRecover = 0.35 },
    sport    = { up = 0.16, down = 0.20, voltageDrop = 0.05, voltageRecover = 0.22 },
    heavy    = { up = 0.48, down = 0.55, voltageDrop = 0.12, voltageRecover = 0.50 },
}

ISVehicleDashboard.YOURDASH_WARNING_RESPONSE = ISVehicleDashboard.YOURDASH_WARNING_RESPONSE or {
    standard = { fadeIn = 0.05,  fadeOut = 0.10, bulbPersistence = 1.00 },
    sport    = { fadeIn = 0.025, fadeOut = 0.055, bulbPersistence = 0.65 },
    heavy    = { fadeIn = 0.09,  fadeOut = 0.18, bulbPersistence = 1.35 },
}

-- Crank dim depends on battery charge (0..1)
ISVehicleDashboard.CRANK_DIM_ALPHA_MIN = ISVehicleDashboard.CRANK_DIM_ALPHA_MIN or 0.20 -- very low charge
ISVehicleDashboard.CRANK_DIM_ALPHA_MAX = ISVehicleDashboard.CRANK_DIM_ALPHA_MAX or 0.85 -- full charge
ISVehicleDashboard.CRANK_DIM_GAMMA     = ISVehicleDashboard.CRANK_DIM_GAMMA     or 2.0  -- curve; <1 = less harsh at mid charge
ISVehicleDashboard.CRANK_DIM_DELAY = ISVehicleDashboard.CRANK_DIM_DELAY or 0.50 -- seconds after cranking starts

-- Starter “kick” dip (big initial voltage drop, then recover to base crank alpha)
ISVehicleDashboard.CRANK_KICK_AMOUNT  = ISVehicleDashboard.CRANK_KICK_AMOUNT  or 0.19 -- subtract from base alpha at the very start
ISVehicleDashboard.CRANK_KICK_HOLD    = ISVehicleDashboard.CRANK_KICK_HOLD    or 0.5 -- seconds to hold the big dip
ISVehicleDashboard.CRANK_KICK_RECOVER = ISVehicleDashboard.CRANK_KICK_RECOVER or 0.18 -- seconds to ramp back to base
ISVehicleDashboard.CRANK_DIM_TIME_DOWN = ISVehicleDashboard.CRANK_DIM_TIME_DOWN or 0.03
ISVehicleDashboard.CRANK_DIM_TIME_UP   = ISVehicleDashboard.CRANK_DIM_TIME_UP   or 0.12
ISVehicleDashboard.CRANK_VOLTAGE_KICK_DROP = ISVehicleDashboard.CRANK_VOLTAGE_KICK_DROP or 1.20

-- Battery light “unstable voltage” flicker right when sag starts
ISVehicleDashboard.CRANK_BATT_FLICKER_TIME  = ISVehicleDashboard.CRANK_BATT_FLICKER_TIME  or 1
ISVehicleDashboard.CRANK_BATT_FLICKER_HZ    = ISVehicleDashboard.CRANK_BATT_FLICKER_HZ    or 4.0
ISVehicleDashboard.CRANK_BATT_FLICKER_DEPTH = ISVehicleDashboard.CRANK_BATT_FLICKER_DEPTH or 0.25 -- subtract from final alpha


-- Exponential approach (simple, stable, no velocity state)
function ISVehicleDashboard._ease(current, target, smoothTime, dt)
    if not dt or dt <= 0 then return current end
    if not smoothTime or smoothTime <= 0 then return target end
    local k = 1 - math.exp(-dt / smoothTime)
    return current + (target - current) * k
end

function ISVehicleDashboard:_getCrankDimAlphaFromCharge()
    local v = self.vehicle
    if not v then return self.CRANK_DIM_ALPHA_MAX end

    local charge = v:getBatteryCharge() or 0
    -- just in case some mod returns percent
    if charge > 1.0 then charge = charge / 100.0 end
    if charge < 0 then charge = 0 elseif charge > 1 then charge = 1 end

    local gamma = self.CRANK_DIM_GAMMA or 1.0
    local c = math.pow(charge, gamma)

    return self.CRANK_DIM_ALPHA_MIN + (self.CRANK_DIM_ALPHA_MAX - self.CRANK_DIM_ALPHA_MIN) * c
end

function ISVehicleDashboard:_YourDashNeedleResponse()
    local profiles = self.YOURDASH_NEEDLE_RESPONSE or {}
    return profiles[self.__YourDashFamily or "standard"] or profiles.standard or {
        up = self.NEEDLE_SMOOTHTIME_UP or 0.30,
        down = self.NEEDLE_SMOOTHTIME_DOWN or 0.30,
        voltageDrop = 0.08,
        voltageRecover = 0.35,
    }
end

function ISVehicleDashboard:_YourDashWarningResponse()
    local profiles = self.YOURDASH_WARNING_RESPONSE or {}
    return profiles[self.__YourDashFamily or "standard"] or profiles.standard or {
        fadeIn = self.WARN_FADE_IN_TIME or 0.05,
        fadeOut = self.WARN_FADE_OUT_TIME or 0.10,
        bulbPersistence = 1.0,
    }
end

function ISVehicleDashboard:_YourDashIsCranking()
    local vehicle = self.vehicle
    if not vehicle or vehicle:isEngineRunning() then return false end
    if vehicle.isStarting and vehicle:isStarting() then return true end
    return vehicle.isEngineStarted and vehicle:isEngineStarted() == true
end

-- Advance the starter envelope once per frame, then share the exact phase with
-- both the illuminated bulb dimmer and the voltage needle.  The normalized
-- kick is 1 during the initial starter hit and eases back to 0 while cranking,
-- producing the visible partial voltage recovery rather than two unrelated
-- effects that can drift by a frame.
function ISVehicleDashboard:_YourDashUpdateCrankEnvelope(cranking, dt)
    dt = tonumber(dt) or (1 / 30)
    if dt < 0 then dt = 0 elseif dt > 0.25 then dt = 0.25 end
    cranking = cranking == true

    self.__crankDimDelayT = self.__crankDimDelayT or 0
    self.__crankDimPrev = self.__crankDimPrev == true
    if cranking then
        if not self.__crankDimPrev then self.__crankDimDelayT = 0 end
        self.__crankDimDelayT = self.__crankDimDelayT + dt
    else
        self.__crankDimDelayT = 0
    end
    self.__crankDimPrev = cranking

    self.__crankSagPrev = self.__crankSagPrev == true
    local sagActive = cranking and self.__crankDimDelayT >= (self.CRANK_DIM_DELAY or 0)
    if sagActive and not self.__crankSagPrev then
        self.__crankKickT = 0
        self.__crankKickActive = true
        self.__crankBattFlickerActive = true
        self.__crankBattFlickerT = 0
    end

    if self.__crankBattFlickerActive then
        self.__crankBattFlickerT = (self.__crankBattFlickerT or 0) + dt
        if self.__crankBattFlickerT >= (self.CRANK_BATT_FLICKER_TIME or 0) then
            self.__crankBattFlickerActive = false
        end
    end

    if not cranking then
        self.__crankBattFlickerActive = false
        self.__crankBattFlickerT = 0
        self.__crankKickActive = false
        self.__crankKickT = 0
    end
    self.__crankSagPrev = sagActive

    local kick01 = 0
    if sagActive and self.__crankKickActive then
        self.__crankKickT = (self.__crankKickT or 0) + dt
        local hold = self.CRANK_KICK_HOLD or 0.05
        local recover = self.CRANK_KICK_RECOVER or 0.18
        if self.__crankKickT <= hold then
            kick01 = 1
        elseif recover > 0 and self.__crankKickT <= hold + recover then
            local u = (self.__crankKickT - hold) / recover
            if u < 0 then u = 0 elseif u > 1 then u = 1 end
            local smoothstep = u * u * (3 - 2 * u)
            kick01 = 1 - smoothstep
        else
            self.__crankKickActive = false
            kick01 = 0
        end
    end

    local dimTarget = 1
    if sagActive then
        dimTarget = self:_getCrankDimAlphaFromCharge() -
            (self.CRANK_KICK_AMOUNT or 0.15) * kick01
        if dimTarget < 0 then dimTarget = 0 end
    end

    self.__YourDashCranking = cranking
    self.__YourDashCrankSagActive = sagActive
    self.__YourDashCrankKick01 = kick01
    self.__YourDashCrankDimTarget = dimTarget
    return sagActive, kick01
end

-- =========================
-- Config + helpers
-- =========================
ISVehicleDashboard.NEEDLE_SMOOTHTIME_UP   = ISVehicleDashboard.NEEDLE_SMOOTHTIME_UP   or 0.3
ISVehicleDashboard.NEEDLE_SMOOTHTIME_DOWN = ISVehicleDashboard.NEEDLE_SMOOTHTIME_DOWN or 0.3
ISVehicleDashboard.NEEDLE_MAXSPEED        = ISVehicleDashboard.NEEDLE_MAXSPEED        or 1e9

ISVehicleDashboard.RPM_MIN_ANGLE   = math.rad(0)
ISVehicleDashboard.RPM_MAX_ANGLE   = math.rad(210)

ISVehicleDashboard.FUEL_MIN_ANGLE  = math.rad(20)
ISVehicleDashboard.FUEL_MAX_ANGLE  = math.rad(160)

function ISVehicleDashboard:_getSeatWindowPart()
    if not self.vehicle or not self.character then return nil end

    local seat = self.vehicle:getSeat(self.character)
    local door = self.vehicle:getPassengerDoor(seat)
    if not door then return nil end

    local windowPart = VehicleUtils.getChildWindow(door)
    if not windowPart then return nil end

    if windowPart:getItemType() and not windowPart:getInventoryItem() then
        return nil
    end

    local w = windowPart:getWindow()
    if not w or not w:isOpenable() or w:isDestroyed() then
        return nil
    end

    return windowPart
end

function ISVehicleDashboard:_hasBatteryPower()
    return self.vehicle:getBatteryCharge() > 0
end

function ISVehicleDashboard:_YourDashSetSideButtonTexture(button, texture)
    if not button or not texture then return end
    button.texture = texture
    button:setWidth(texture:getWidthOrig())
    button:setHeight(texture:getHeightOrig())
end

function ISVehicleDashboard:_YourDashRequestSeatSwitch(seatTo)
    local character = self.character
    local vehicle = (character and character.getVehicle and character:getVehicle()) or self.vehicle
    if not character or not vehicle or not ISVehicleMenu or not ISVehicleMenu.onSwitchSeat then return end

    if getGameSpeed then
        if getGameSpeed() == 0 then return end
        if getGameSpeed() > 1 and setGameSpeed then setGameSpeed(1) end
    end

    if not YourDash_IsSeatInstalled(vehicle, seatTo) then return end
    if vehicle.getCharacter and vehicle:getCharacter(seatTo) then return end

    local currentSeat = vehicle.getSeat and vehicle:getSeat(character) or -1
    if currentSeat == -1 or currentSeat == seatTo then return end
    if vehicle.canSwitchSeat and not vehicle:canSwitchSeat(currentSeat, seatTo) then return end

    if ISVehicleMenu.moveItemsFromSeat and vehicle.getPartForSeatContainer then
        local okPart, seatPart = pcall(vehicle.getPartForSeatContainer, vehicle, seatTo)
        local container = okPart and seatPart and seatPart.getItemContainer and seatPart:getItemContainer() or nil
        if container and container.getCapacity and container.getCapacityWeight then
            local minWeight = (container:getCapacity() or 0) / 4
            local weight = container:getCapacityWeight() or 0
            if weight > minWeight and not ISVehicleMenu.moveItemsFromSeat(character, vehicle, seatTo, true, false) then
                return
            end
        end
    end

    return ISVehicleMenu.onSwitchSeat(character, seatTo)
end

function ISVehicleDashboard:onYourDashMoveToPassenger()
    return self:_YourDashRequestSeatSwitch(1)
end

function ISVehicleDashboard:onYourDashSleep()
    local character = self.character
    local vehicle = (character and character.getVehicle and character:getVehicle()) or self.vehicle
    if not character or not vehicle or not ISVehicleMenu or not ISVehicleMenu.onSleep then return end

    if getGameSpeed then
        if getGameSpeed() == 0 then return end
        if getGameSpeed() > 1 and setGameSpeed then setGameSpeed(1) end
    end

    if not YourDash_CanSleepInVehicle(character, vehicle) then return end
    return ISVehicleMenu.onSleep(character, vehicle)
end

function ISVehicleDashboard:_YourDashEnsureSideButtons()
    if self.__YourDashSideButtonsCreated then return end

    local function makeButton(texture, onclick, tooltip)
        if not texture then return nil end
        local button = ISImage:new(0, 0, texture:getWidthOrig(), texture:getHeightOrig(), texture)
        button:initialise()
        button:instantiate()
        button.target = self
        button.onclick = onclick
        button.mouseovertext = tooltip
        button.alpha = 0.5
        button.backgroundColor = { r=0, g=0, b=0, a=0 }
        self:addChild(button)
        self:_installPressedEffect(button, 0.96)
        return button
    end

    self.__YourDashMoveSeatButton = makeButton(
        self.__YourDashMovePassengerTex or YourDash_ButtonTexture("btn_move_to_passenger.png"),
        ISVehicleDashboard.onYourDashMoveToPassenger,
        "move to passenger seat"
    )
    self.__YourDashSleepButton = makeButton(
        self.__YourDashSleepTex or YourDash_ButtonTexture("btn_sleep.png"),
        ISVehicleDashboard.onYourDashSleep,
        YourDash_Text("ContextMenu_Sleep", "sleep")
    )
    self.__YourDashSideButtonsCreated =
        self.__YourDashMoveSeatButton ~= nil or self.__YourDashSleepButton ~= nil
end

function ISVehicleDashboard:_YourDashPositionSideButtons()
    if not self.backgroundTex then return end
    local seatButton = self.__YourDashMoveSeatButton
    local sleepButton = self.__YourDashSleepButton
    if not seatButton and not sleepButton then return end

    local scale = YourDash.GetScale and YourDash.GetScale() or 1
    local gap = math.max(1, math.floor(2 * scale + 0.5))
    local x = self.backgroundTex:getX() + self.backgroundTex:getWidth() + gap
    local stackH = 0
    if seatButton then stackH = stackH + seatButton:getHeight() end
    if sleepButton then
        if stackH > 0 then stackH = stackH + gap end
        stackH = stackH + sleepButton:getHeight()
    end
    local y = math.max(self.backgroundTex:getY(),
        self.backgroundTex:getY() + self.backgroundTex:getHeight() - stackH)
    local right = self.backgroundTex:getX() + self.backgroundTex:getWidth()
    local bottom = self.backgroundTex:getY() + self.backgroundTex:getHeight()

    if seatButton then
        seatButton:setX(x)
        seatButton:setY(y)
        right = math.max(right, x + seatButton:getWidth())
        bottom = math.max(bottom, y + seatButton:getHeight())
        y = y + seatButton:getHeight() + gap
    end
    if sleepButton then
        sleepButton:setX(x)
        sleepButton:setY(y)
        right = math.max(right, x + sleepButton:getWidth())
        bottom = math.max(bottom, y + sleepButton:getHeight())
    end

    self:setWidth(math.max(self:getWidth() or 0, right))
    self:setHeight(math.max(self:getHeight() or 0, bottom))
end

function ISVehicleDashboard:_YourDashUpdateSideButtons()
    self:_YourDashEnsureSideButtons()

    if self.__YourDashMoveSeatButton then
        self.__YourDashMoveSeatButton:setVisible(true)
        self.__YourDashMoveSeatButton.target = self
        self.__YourDashMoveSeatButton.onclick = ISVehicleDashboard.onYourDashMoveToPassenger
        self.__YourDashMoveSeatButton.mouseovertext = "move to passenger seat"
        self.__YourDashMoveSeatButton.__disabled = false
        YourDash_UpdateHoverAlpha(self.__YourDashMoveSeatButton)
    end
    if self.__YourDashSleepButton then
        local canSleep, sleepTip = YourDash_CanSleepInVehicle(self.character, self.vehicle)
        self.__YourDashSleepButton:setVisible(true)
        self.__YourDashSleepButton.target = self
        self.__YourDashSleepButton.onclick = canSleep and ISVehicleDashboard.onYourDashSleep or nil
        self.__YourDashSleepButton.mouseovertext = sleepTip or YourDash_Text("ContextMenu_Sleep", "sleep")
        self.__YourDashSleepButton.__disabled = not canSleep
        YourDash_UpdateHoverAlpha(self.__YourDashSleepButton)
    end
end

-- Vehicle alarms drive BaseVehicle:setHeadlightsOn() directly for each flash,
-- so getHeadlightsOn() is not a stable representation of the driver's switch
-- while an alarm is active.  Keep the last non-alarm state for the dashboard
-- control and optimistically update it when this control is clicked.
function ISVehicleDashboard:_YourDashIsAlarmActive()
    local vehicle = self.vehicle
    if not vehicle or not vehicle.isAlarmActive then return false end
    local ok, active = pcall(vehicle.isAlarmActive, vehicle)
    return ok and active == true
end

function ISVehicleDashboard:_YourDashGetHeadlightSwitchState()
    local vehicle = self.vehicle
    if not vehicle then return false end

    local actual = vehicle:getHeadlightsOn() == true
    if self:_YourDashIsAlarmActive() then
        if self.__YourDashHeadlightSwitchOn == nil then
            self.__YourDashHeadlightSwitchOn = actual
        end
        return self.__YourDashHeadlightSwitchOn == true
    end

    local pending = (self.__YourDashHeadlightSwitchPending or 0) > 0
    if pending and actual ~= (self.__YourDashHeadlightSwitchOn == true) then
        return self.__YourDashHeadlightSwitchOn == true
    end

    self.__YourDashHeadlightSwitchPending = 0
    self.__YourDashHeadlightSwitchOn = actual
    return actual
end

function ISVehicleDashboard:_YourDashPositionWindowState(state)
    if not self.windowTex or not self.backgroundTex then return end
    local layout = YourDash.GetLayout and YourDash.GetLayout(self) or nil
    local controls = layout and layout.controls or nil
    local point = controls and controls.window or nil
    local scale = YourDash.GetScale and YourDash.GetScale() or 1
    local x, y = nil, nil
    if YourDash.GetLayoutPoint then
        x, y = YourDash.GetLayoutPoint(self, "controls", "window")
    end
    if (x == nil or y == nil) and not point then return end
    x = x or math.floor((point.x or point[1] or 0) * scale + 0.5)
    y = y or math.floor((point.y or point[2] or 0) * scale + 0.5)
    self.windowTex:setX(self.backgroundTex:getX() + x)
    self.windowTex:setY(self.backgroundTex:getY() + y)
end

function ISVehicleDashboard:_YourDashElectricalLoadUnits()
    local v = self.vehicle
    if not v then return 0 end
    local units = v:getHeadlightsOn() and 1.0 or 0.0

    local heater = v.getHeater and v:getHeater() or v:getPartById("Heater")
    local hmd = heater and heater:getModData() or nil
    if hmd and hmd.active then units = units + 1.4 end -- 0.000035 / vanilla 0.000025 rate

    for i = 0, v:getPartCount() - 1 do
        local part = v:getPartByIndex(i)
        local data = part and part.getDeviceData and part:getDeviceData() or nil
        if data and data.getIsTurnedOn and data:getIsTurnedOn() then
            units = units + 1.0
            break
        end
    end

    local okLights, lightbarLights = pcall(function() return v:getLightbarLightsMode() end)
    if okLights and lightbarLights and lightbarLights > 0 then units = units + 1.0 end
    local okSiren, lightbarSiren = pcall(function() return v:getLightbarSirenMode() end)
    if okSiren and lightbarSiren and lightbarSiren > 0 then units = units + 1.0 end
    return units
end

function ISVehicleDashboard:_YourDashUpdateVoltage(dt, cranking)
    local v = self.vehicle
    if not v then self.__YourDashVoltage = 8.0 return end
    local charge = v:getBatteryCharge() or 0
    if charge > 1 then charge = charge / 100 end
    if charge < 0 then charge = 0 elseif charge > 1 then charge = 1 end

    local running = v:isEngineRunning()
    if cranking == nil then cranking = self:_YourDashIsCranking() end
    cranking = cranking == true and not running
    local keyed = v:isKeysInIgnition() or v:isHotwired()

    -- Battery charge is quantized and may replicate in discrete steps.  A
    -- per-frame derivative turns each step into a voltage spike, so sample it
    -- over a one-second window and low-pass the resulting presentation load.
    local sampleDt = dt or (1 / 30)
    if sampleDt < 0 then sampleDt = 0 elseif sampleDt > 0.25 then sampleDt = 0.25 end
    if self.__YourDashBatterySampleCharge == nil or cranking then
        self.__YourDashBatterySampleCharge = charge
        self.__YourDashBatterySampleAge = 0
        self.__YourDashMeasuredDrop = cranking and 0 or (self.__YourDashMeasuredDrop or 0)
    else
        self.__YourDashBatterySampleAge = (self.__YourDashBatterySampleAge or 0) + sampleDt
        if self.__YourDashBatterySampleAge >= 1.0 then
            local age = self.__YourDashBatterySampleAge
            local delta = self.__YourDashBatterySampleCharge - charge
            local rawDrop = 0
            if delta > 0 then rawDrop = math.min(0.6, (delta / age) * 200) end
            local alpha = 1 - math.exp(-age / 2.5)
            local filtered = self.__YourDashMeasuredDrop or 0
            self.__YourDashMeasuredDrop = filtered + (rawDrop - filtered) * alpha
            self.__YourDashBatterySampleCharge = charge
            self.__YourDashBatterySampleAge = 0
        end
    end
    local measuredDrop = self.__YourDashMeasuredDrop or 0

    local target
    if running then
        target = 14.6
    elseif cranking then
        if self.__YourDashCrankSagActive then
            -- The steady starter load remains the requested 8V..11V by battery
            -- charge.  The shared first-phase kick drops it farther, then the
            -- same envelope that drives bulb dimming recovers partway.
            target = 8.0 + 3.0 * charge -
                (self.CRANK_VOLTAGE_KICK_DROP or 1.20) * (self.__YourDashCrankKick01 or 0)
        else
            -- isStarting() includes the short pre-starter phase.  Hold normal
            -- keyed voltage until the common delayed sag envelope engages.
            target = charge > 0 and (10.0 + 2.8 * charge) or 8.0
        end
    elseif keyed and charge > 0 then
        target = 10.0 + 2.8 * charge
    else
        target = 8.0
    end

    if not cranking and (keyed or running) then
        -- Relative weights come from B42's own battery-drain rates; volts are only presentation.
        self.__YourDashLoadSampleT = (self.__YourDashLoadSampleT or 0) - (dt or 1/30)
        if self.__YourDashLoadSampleT <= 0 then
            self.__YourDashLoadUnits = self:_YourDashElectricalLoadUnits()
            self.__YourDashLoadSampleT = 0.20
        end
        target = target - math.min(1.0, (self.__YourDashLoadUnits or 0) * 0.18) - measuredDrop
    end
    if target < 7.5 then target = 7.5 elseif target > 15.0 then target = 15.0 end

    self.__YourDashVoltage = self.__YourDashVoltage or target
    self.__YourDashVoltageVel = self.__YourDashVoltageVel or 0
    local response = self:_YourDashNeedleResponse()
    local smooth = target < self.__YourDashVoltage and
        (response.voltageDrop or 0.08) or (response.voltageRecover or 0.35)
    self.__YourDashVoltage, self.__YourDashVoltageVel = self._smoothDamp(
        self.__YourDashVoltage, target, self.__YourDashVoltageVel, smooth, 100, dt or 1/30)
end

function ISVehicleDashboard:onClickWindow()
    if getGameSpeed() == 0 then return end
    if getGameSpeed() > 1 then setGameSpeed(1) end
    if not self.vehicle then return end

    local windowPart = self:_getSeatWindowPart()
    if not windowPart then return end

    local w = windowPart:getWindow()
    local family = self.__YourDashFamily or "standard"
    local command = self.__YourDashWindowCommand
    local directional = family == "heavy" or family == "sport"
    local shouldOpen
    if directional and command then
        -- Upper half raises/closes; lower half lowers/opens, irrespective of
        -- the window's current state.
        shouldOpen = command == "down"
    else
        -- Preserve the proven single-action standard switch behavior.
        shouldOpen = not w:isOpen()
    end
    if shouldOpen == w:isOpen() then return end
    ISVehiclePartMenu.onOpenCloseWindow(self.character, windowPart, shouldOpen)
end

local _YourDashOldOnClickHeadlights = ISVehicleDashboard.onClickHeadlights
function ISVehicleDashboard:onClickHeadlights()
    -- Mirror vanilla's paused-game guard before changing the optimistic UI
    -- state, otherwise a rejected click briefly shows the opposite position.
    if getGameSpeed and getGameSpeed() == 0 then return end
    if self.vehicle then
        self.__YourDashHeadlightSwitchOn = not self:_YourDashGetHeadlightSwitchState()
        self.__YourDashHeadlightSwitchPending = 1.0
    end
    if _YourDashOldOnClickHeadlights then
        return _YourDashOldOnClickHeadlights(self)
    end
end

function ISVehicleDashboard:_applyLidMode(lidOn)
    lidOn = (lidOn == true)
    if self.__lidMode == lidOn then return end
    self.__lidMode = lidOn
    -- No swapping anymore.
    -- Gauge lid is drawn in backgroundTex:render()
    -- Needle lid is drawn in ISVehicleDashboard:render()
    -- Fuel arrow lid is drawn via overlay ISImages we create.
end

function ISVehicleDashboard:_drawLidOverlay()
    local tex = self.__bg_lid
    if not tex then return end

    -- You can animate this later for “flashing”:
    -- set self.__lidOverlayAlpha = 0..1 anywhere you want.
    local alpha = (self.__lidOverlayAlpha ~= nil) and self.__lidOverlayAlpha or (self.__lidMode and 1.0 or 0.0)
    if alpha <= 0 then return end

    local x, y, w, h = 0, 0, tex:getWidthOrig(), tex:getHeightOrig()
    if self.backgroundTex then
        x = self.backgroundTex:getX()
        y = self.backgroundTex:getY()
        w = self.backgroundTex:getWidth()
        h = self.backgroundTex:getHeight()
    end

    self:drawTextureScaled(tex, x, y, w, h, alpha)
end

function ISVehicleDashboard._smoothDamp(current, target, velocity, smoothTime, maxSpeed, dt)
    if smoothTime < 1e-4 then smoothTime = 1e-4 end
    local omega = 2.0 / smoothTime
    local x = omega * dt
    local exp = 1.0 / (1.0 + x + 0.48*x*x + 0.235*x*x*x)

    local change = current - target
    local originalTo = target

    local maxChange = maxSpeed * smoothTime
    if change >  maxChange then change =  maxChange
    elseif change < -maxChange then change = -maxChange end

    target = current - change
    local temp = (velocity + omega * change) * dt
    velocity = (velocity - omega * temp) * exp

    local output = target + (change + temp) * exp

    local origToCurrent = originalTo - current
    local outMinusOrig  = output - originalTo
    if (origToCurrent > 0 and outMinusOrig > 0) or (origToCurrent < 0 and outMinusOrig < 0) then
        output = originalTo
        velocity = 0.0
    end
    return output, velocity
end

function ISVehicleDashboard:_installPressedEffect(img, pressedScale)
    if not img or img.__YourDashPressedInstalled then return end
    img.__YourDashPressedInstalled = true
    img.__pressedScale = pressedScale or 0.96
    img.__pressed = false
    img.__disabled = img.__disabled or false

    local function resetPressed(self)
        self.__pressed = false
    end

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

function ISVehicleDashboard:_installStaticTextureRender(img)
    if not img or img.__YourDashStaticRenderInstalled then return end
    img.__YourDashStaticRenderInstalled = true

    function img:render()
        if not self.texture then return end
        local w, h = self.width, self.height
        if not w or not h then return end
        self:drawTextureScaled(self.texture, 0, 0, w, h, self.alpha or 1)
    end
end

function ISVehicleDashboard:_setImageEnabled(img, enabled, mouseovertext, onclickFn, target)
    if not img then return end
    img.__disabled = not enabled
    img.target = target or self
    img.onclick = enabled and onclickFn or nil
    img.mouseovertext = enabled and mouseovertext or nil
    img.backgroundColor = { r=0, g=0, b=0, a=0 }
end

function ISVehicleDashboard:_setImageTextureAndSize(img, tex)
    if not img or not tex then return end
    img.texture = tex
    img:setWidth(tex:getWidthOrig())
    img:setHeight(tex:getHeightOrig())
end

function ISVehicleDashboard:_YourDashApplyLightTexture(tex)
    if not self.lightsTex or not tex then return end
    self:_setImageTextureAndSize(self.lightsTex, tex)

    if (self.__YourDashFamily or "standard") == "heavy" then
        local scaleKey = YourDash.GetScaleKey and YourDash.GetScaleKey() or "1x"
        local hitbox = HEAVY_LIGHT_HITBOX[scaleKey] or HEAVY_LIGHT_HITBOX["1x"]
        self.lightsTex.__YourDashLightHitbox = hitbox
        self.lightsTex.__YourDashTextureWidth = tex:getWidthOrig()
        self.lightsTex.__YourDashTextureHeight = tex:getHeightOrig()
        self.lightsTex:setWidth(hitbox.width)
        self.lightsTex:setHeight(hitbox.height)
    else
        self.lightsTex.__YourDashLightHitbox = nil
        self.lightsTex.__YourDashTextureWidth = nil
        self.lightsTex.__YourDashTextureHeight = nil
    end
end

function ISVehicleDashboard:_YourDashPositionLightsControl(x, y)
    if not self.lightsTex or not self.backgroundTex then return end

    local offsetX, offsetY = 0, 0
    if (self.__YourDashFamily or "standard") == "heavy" then
        local scaleKey = YourDash.GetScaleKey and YourDash.GetScaleKey() or "1x"
        local hitbox = self.lightsTex.__YourDashLightHitbox or HEAVY_LIGHT_HITBOX[scaleKey] or HEAVY_LIGHT_HITBOX["1x"]
        offsetX = hitbox.x or 0
        offsetY = hitbox.y or 0
    end

    self.lightsTex:setX(self.backgroundTex:getX() + (x or 0) + offsetX)
    self.lightsTex:setY(self.backgroundTex:getY() + (y or 0) + offsetY)
end

-- =========================
-- Gear label font (btn_partSpeed) scaling for Large pack
-- =========================
ISVehicleDashboard.GEAR_FONT_REG   = ISVehicleDashboard.GEAR_FONT_REG   or UIFont.Small
ISVehicleDashboard.GEAR_FONT_LARGE = ISVehicleDashboard.GEAR_FONT_LARGE or UIFont.Large
-- (If you want it HUGE, try UIFont.Massive)

-- Dashboard coordinates were authored against these physical line heights.
-- B42 swaps the backing font atlas when its UI Font Size option changes, so
-- scale the loaded atlas back to a fixed dashboard-pixel height.  This keeps
-- both the gear size and its baseline stable at every resolution/font option.
local GEAR_REFERENCE_FONT_HEIGHT = {
    ["0.75x"] = 16,
    ["1x"] = 16,
    ["1.4x"] = 23,
    ["2x"] = 26,
}

local function _yourDashNormalizedGearPrerender(label)
    local text = label.translation or label.name or ""
    local font = label.font or UIFont.Small
    local zoom = tonumber(label.__YourDashGearFontZoom) or 1

    if label.textColor then
        label.r = label.textColor.r
        label.g = label.textColor.g
        label.b = label.textColor.b
        label.a = label.textColor.a
    end

    local tm = getTextManager and getTextManager() or nil
    local width = tm and tm.MeasureStringX and tm:MeasureStringX(font, text) or 0
    local renderedWidth = math.max(1, math.ceil(width * zoom))
    if label.setWidth then label:setWidth(renderedWidth) else label.width = renderedWidth end

    if label.drawTextZoomed then
        local x = label.center and -(renderedWidth * 0.5) or 0
        label:drawTextZoomed(text, x, 0, zoom, label.r, label.g, label.b, label.a, font)
    elseif label.center then
        label:drawTextCentre(text, 0, 0, label.r, label.g, label.b, label.a, font)
    else
        label:drawText(text, 0, 0, label.r, label.g, label.b, label.a, font)
    end

    if label.updateTooltip then label:updateTooltip() end
end

function ISVehicleDashboard:_YourDashApplyGearFont(useLarge)
    if not self.btn_partSpeed then return end
    useLarge = (useLarge == true)

    local font = (YourDash.GetUIFont and YourDash.GetUIFont()) or
        (useLarge and (self.GEAR_FONT_LARGE or UIFont.Large) or (self.GEAR_FONT_REG or UIFont.Small))

    -- Works across versions: some builds have setFont, some just expose .font
    if self.btn_partSpeed.setFont then
        self.btn_partSpeed:setFont(font)
    else
        self.btn_partSpeed.font = font
    end

    -- Normalize the loaded font to the asset pack's physical pixel height.
    local tm = getTextManager and getTextManager() or nil
    local h = tm and tm.getFontHeight and tm:getFontHeight(font) or nil
    if h then
        local scaleKey = YourDash.GetScaleKey and YourDash.GetScaleKey() or "1x"
        local referenceH = YourDash.ReferenceFontHeightForScale and
            YourDash.ReferenceFontHeightForScale(scaleKey, 0) or
            GEAR_REFERENCE_FONT_HEIGHT[scaleKey] or 16
        self.btn_partSpeed.__YourDashGearFontZoom = referenceH / math.max(1, h)

        if self.btn_partSpeed.setHeight then
            self.btn_partSpeed:setHeight(referenceH)
        else
            self.btn_partSpeed.height = referenceH
        end
    else
        self.btn_partSpeed.__YourDashGearFontZoom = 1
    end

    if not self.btn_partSpeed.__YourDashNormalizedGearRender then
        self.btn_partSpeed.__YourDashNormalizedGearRender = true
        self.btn_partSpeed.prerender = _yourDashNormalizedGearPrerender
    end
end


-- =========================
-- Apply family/scale texture set and data-driven offsets.
-- =========================
function ISVehicleDashboard:_YourDashApplyOffsets(useLarge)
    local layout = YourDash.GetLayout and YourDash.GetLayout(self) or nil
    local gauges = layout and (layout.gauges or layout.gauge) or nil
    local scale = YourDash.GetScale and YourDash.GetScale() or (useLarge and 2 or 1)
    local function point(name, fallbackX, fallbackY)
        if YourDash.GetLayoutPoint then
            local x, y = YourDash.GetLayoutPoint(self, "gauges", name)
            if x ~= nil and y ~= nil then return { x = x, y = y } end
        end
        local p = gauges and gauges[name] or nil
        local x = p and (p.x or p[1]) or fallbackX
        local y = p and (p.y or p[2]) or fallbackY
        return { x = math.floor((x or 0) * scale + 0.5), y = math.floor((y or 0) * scale + 0.5) }
    end

    self.dashOffset    = point("dash",  0, 0)
    self.rpmOffset     = point("rpm",   self.GAUGE_RPM_X, self.GAUGE_RPM_Y)
    self.speedOffset   = point("speed", self.GAUGE_SPEED_X, self.GAUGE_SPEED_Y)
    self.fuelOffset    = point("fuel",  self.GAUGE_FUEL_X, self.GAUGE_FUEL_Y)
    self.voltageOffset = point("voltage", self.GAUGE_FUEL_X, self.GAUGE_FUEL_Y)
end

function ISVehicleDashboard:_YourDashScaleIgnition()
    local img = self.ignitionTex
    local tex = img and img.texture or nil
    if not img or not tex then return end
    local scale = YourDash.GetScale and YourDash.GetScale() or 1
    local w = math.max(1, math.floor(tex:getWidthOrig() * scale + 0.5))
    local h = math.max(1, math.floor(tex:getHeightOrig() * scale + 0.5))
    img:setWidth(w)
    img:setHeight(h)
    img.autoScale = true
    img.scaledWidth, img.scaledHeight = w, h
end

function ISVehicleDashboard:_YourDashEnsureStateLEDs()
    local function ensure(field)
        local img = self[field]
        if not img and self.__led_off then
            img = ISImage:new(0, 0, self.__led_off:getWidthOrig(), self.__led_off:getHeightOrig(), self.__led_off)
            img:initialise()
            img:instantiate()
            img.backgroundColor = { r=1, g=1, b=1, a=1 }
            img.onclick, img.target, img.mouseovertext = nil, nil, nil
            YourDash_SetMouseTransparent(img)
            self:addChild(img)
            self[field] = img
        end
        if img then
            if self.__led_off then
                self:_setImageTextureAndSize(img, self.__led_off)
                img:setVisible(true)
            else
                img:setVisible(false)
            end
        end
    end
    ensure("__YourDashDoorLED")
    ensure("__YourDashTrunkLED")
end

function ISVehicleDashboard:_YourDashHasTrunkLock()
    return self.vehicle and (self.vehicle:getPartById("TruckBed") ~= nil)
end

function ISVehicleDashboard:_YourDashUpdateDashBaseForTrunk()
    local useNoTrunk = self.__YourDashFamily == "heavy" and
        self.__dashTexNoTrunk and
        self.vehicle and
        (not self:_YourDashHasTrunkLock())
    self.__dashTex = useNoTrunk and self.__dashTexNoTrunk or (self.__dashTexDefault or self.__dashTex)
end

function ISVehicleDashboard:_YourDashPositionTrunkControl(hasTrunkLock)
    if not self.trunkTex or not self.backgroundTex then return end

    local layout = YourDash.GetLayout and YourDash.GetLayout(self) or nil
    local controls = layout and layout.controls or nil
    local scale = YourDash.GetScale and YourDash.GetScale() or 1
    local function pos(name, fallbackX, fallbackY)
        if YourDash.GetLayoutPoint then
            local x, y = YourDash.GetLayoutPoint(self, "controls", name)
            if x ~= nil and y ~= nil then return x, y end
        end
        local p = controls and controls[name] or nil
        local x = p and (p.x or p[1]) or fallbackX
        local y = p and (p.y or p[2]) or fallbackY
        return math.floor((x or 0) * scale + 0.5), math.floor((y or 0) * scale + 0.5)
    end

    local x, y = pos("trunk", self.CTRL_TRUNK_X, self.CTRL_TRUNK_Y)
    if hasTrunkLock == false then
        x, y = pos("trunkBlank", x / scale, y / scale)
    end
    self.trunkTex:setX(self.backgroundTex:getX() + x)
    self.trunkTex:setY(self.backgroundTex:getY() + y)
end

function ISVehicleDashboard:_YourDashApplyTextureSet(_useLarge, isInit)
    local family = self.__YourDashFamily or "standard"
    local accent = self.__YourDashAccent or "base"
    local scaleKey = YourDash.GetScaleKey and YourDash.GetScaleKey() or "1x"
    local setKey = family .. ":" .. accent .. ":" .. scaleKey
    self.__YourDashRetainedStainLevel = self.__stainLevel
    self.__YourDashRetainedStainVariant = self.__stainVariant
    self.__YourDashTextureKey = setKey
    self.__YourDashLarge = (scaleKey == "2x") -- compatibility for older helper modules

    self.__YourDashStainCache = {}
    self.__YourDashCrackCache = {}
    self.__stainTex, self.__crackTex = nil, nil
    self.__stainLevel, self.__crackLevel = nil, nil

    local function rawTex(whichFamily, group, name)
        local path = string.format("media/ui/vehicles/%s/%s/%s/%s", whichFamily, group, scaleKey, name)
        return getTexture(path)
    end
    local function tex(name, fallbackFamily)
        local t = nil
        if YourDash.GetDashboardTexture then
            t = YourDash.GetDashboardTexture(family, "dash", name, fallbackFamily)
        else
            t = rawTex(family, "dash", name)
        end
        if (not t) and fallbackFamily then t = rawTex(fallbackFamily, "dash", name) end
        return t
    end

    self.__bg_day = tex("gauge.png") or self.dashboardBG
    self.__bg_lid = tex("gauge_lid.png") or self.__bg_day
    local dashName = "dash.png"
    if family == "sport" then dashName = "dash_" .. accent .. ".png" end
    self.__dashTexDefault = tex(dashName) or tex("dash_base.png") or tex("dash.png")
    self.__dashTexNoTrunk = (family == "heavy") and (tex("dash_no_trunk.png") or self.__dashTexDefault) or nil
    self.__dashTex = self.__dashTexDefault
    self:_YourDashUpdateDashBaseForTrunk()
    self.__dashShadowTex = tex("dash_shadow.png")

    if self.__bg_day then self.dashboardBG = self.__bg_day end
    if self.dashboardBG then
        self:setWidth(self.dashboardBG:getWidthOrig())
        self:setHeight(self.dashboardBG:getHeightOrig())
    end

    local warningNames = { "cruise", "battery", "brake", "check", "stop", "door", "fuel", "light" }
    for _, name in ipairs(warningNames) do
        self["__warn_" .. name] = tex("warning_" .. name .. ".png")
        self["__warn_" .. name .. "_off"] = (family == "heavy") and tex("warning_" .. name .. "_off.png") or nil
    end

    local warningImages = {
        cruise=self.warnCruiseTex, battery=self.warnBatteryTex, brake=self.warnBrakeTex,
        check=self.warnCheckTex, stop=self.warnStopTex, door=self.warnDoorTex,
        fuel=self.warnFuelTex, light=self.warnLightTex,
    }
    for name, img in pairs(warningImages) do
        local onTex = self["__warn_" .. name]
        if img and onTex then self:_setImageTextureAndSize(img, onTex) end
        if img then img.__offTexture = self["__warn_" .. name .. "_off"] end
    end

    self.__needleLong_day  = tex("needle_long.png")
    self.__needleLong_lid  = tex("needle_long_lid.png") or self.__needleLong_day
    self.__needleMid_day   = tex("needle_mid.png")
    self.__needleMid_lid   = tex("needle_mid_lid.png") or self.__needleMid_day
    self.__needleShort_day = tex("needle_short.png")
    self.__needleShort_lid = tex("needle_short_lid.png") or self.__needleShort_day
    self.needleCenter      = tex("needle_center.png")

    self.__fuelL_day = tex("fuelL.png")
    self.__fuelR_day = tex("fuelR.png")
    self.__fuelL_lid = tex("fuelL_lid.png") or self.__fuelL_day
    self.__fuelR_lid = tex("fuelR_lid.png") or self.__fuelR_day
    self.needleLong, self.needleShort = self.__needleLong_day, self.__needleShort_day
    self.leftSideFuelTex, self.rightSideFuelTex = self.__fuelL_day, self.__fuelR_day

    if self.leftSideFuel and self.__fuelL_day then self:_setImageTextureAndSize(self.leftSideFuel, self.__fuelL_day) end
    if self.rightSideFuel and self.__fuelR_day then self:_setImageTextureAndSize(self.rightSideFuel, self.__fuelR_day) end
    if self.leftSideFuelLid and self.__fuelL_lid then self:_setImageTextureAndSize(self.leftSideFuelLid, self.__fuelL_lid) end
    if self.rightSideFuelLid and self.__fuelR_lid then self:_setImageTextureAndSize(self.rightSideFuelLid, self.__fuelR_lid) end

    if family == "heavy" then
        self.__lock_off, self.__lock_partial, self.__lock_on = tex("btn_off.png"), tex("btn_off.png"), tex("btn_on.png")
        self.__trunk_off, self.__trunk_on = tex("btn_off.png"), tex("btn_on.png")
        -- The exported filenames are logically reversed: *_on is the released
        -- OFF artwork and *_off is the pressed ON artwork.
        self.__light_knob_off, self.__light_knob_on = tex("light_knob_on.png"), tex("light_knob_off.png")
        self.__light_knob = self.__light_knob_off or self.__light_knob_on
        self.__window_switch = tex("window_switch.png")
        self.__window_switch_push = tex("window_switch_down.png") or self.__window_switch
        self.__window_switch_pull = tex("window_switch_up.png") or self.__window_switch
    else
        self.__lock_off = tex("lock_off.png")
        self.__lock_partial = tex("lock_partial.png") or self.__lock_off
        self.__lock_on = tex("lock_on.png") or self.__lock_off
        self.__trunk_off = tex("trunk_off.png")
        self.__trunk_on = tex("trunk_on.png") or self.__trunk_off
        self.__light_knob_off, self.__light_knob_on = nil, nil
        self.__light_knob = tex("light_knob.png")
        self.__window_switch = tex("window_switch.png")
        self.__window_switch_push = tex("window_switch_down.png") or tex("window_switch_push.png") or self.__window_switch
        self.__window_switch_pull = tex("window_switch_up.png") or tex("window_switch_pull.png") or self.__window_switch
    end
    self.__blank_btn = tex("blank_btn.png")
    self.__led_off, self.__led_partial, self.__led_on = tex("led_off.png"), tex("led_partial.png"), tex("led_on.png")

    if self.__lock_off then self.iconDoor = self.__lock_off end
    if self.__trunk_off then self.iconTrunk = self.__trunk_off end
    if self.__light_knob then self.iconLights = self.__light_knob end
    if self.doorTex and self.__lock_off then self:_setImageTextureAndSize(self.doorTex, self.__lock_off) end
    if self.trunkTex and self.__trunk_off then self:_setImageTextureAndSize(self.trunkTex, self.__trunk_off) end
    if self.lightsTex and self.__light_knob then self:_YourDashApplyLightTexture(self.__light_knob) end
    if self.windowTex and self.__window_switch then
        self:_setImageTextureAndSize(self.windowTex, self.__window_switch)
        self:_YourDashPositionWindowState("neutral")
    end
    self.__YourDashMovePassengerTex = YourDash_ButtonTexture("btn_move_to_passenger.png")
    self.__YourDashSleepTex = YourDash_ButtonTexture("btn_sleep.png")
    if self.__YourDashMoveSeatButton and self.__YourDashMovePassengerTex then
        self:_YourDashSetSideButtonTexture(self.__YourDashMoveSeatButton, self.__YourDashMovePassengerTex)
    end
    if self.__YourDashSleepButton and self.__YourDashSleepTex then
        self:_YourDashSetSideButtonTexture(self.__YourDashSleepButton, self.__YourDashSleepTex)
    end
    -- Heavy binary controls carry their pressed/released depth in separate
    -- textures.  Do not add the generic click-scale animation on top.
    local binaryPressedScale = family == "heavy" and 1.0 or 0.96
    if self.doorTex then self.doorTex.__pressedScale = binaryPressedScale end
    if self.trunkTex then self.trunkTex.__pressedScale = binaryPressedScale end
    if self.children then self:_YourDashEnsureStateLEDs() end

    if self.backgroundTex and self.dashboardBG then
        self.backgroundTex.texture = self.dashboardBG
        self.backgroundTex:setWidth(self.dashboardBG:getWidthOrig())
        self.backgroundTex:setHeight(self.dashboardBG:getHeightOrig())
    end

    self:_YourDashApplyOffsets(self.__YourDashLarge)
    if (not isInit) and self.onResolutionChange then self:onResolutionChange() end
end

-- =========================
-- Stain layer (rendered by the final glass/wear overlay)
-- =========================
ISVehicleDashboard.STAIN_VARIANTS_PER_LEVEL = ISVehicleDashboard.STAIN_VARIANTS_PER_LEVEL or 5

-- Condition -> level mapping (edit if you want different breakpoints)
function ISVehicleDashboard:_stainLevelFromSeatCondition(cond)
    cond = cond or 100
    if cond < 0 then cond = 0 elseif cond > 100 then cond = 100 end

    if cond >= 90 then return 1 end
    if cond >= 75 then return 2 end
    if cond >= 60 then return 3 end
    if cond >= 45 then return 4 end
    return 5
end

function ISVehicleDashboard:_getDriverSeatPart()
    local v = self.vehicle
    if not v then return nil end

    -- Prefer the actual seat the dashboard owner is sitting in
    local seat = 0
    if self.character and v.getSeat then
        local s = v:getSeat(self.character)
        if s ~= nil and s >= 0 then seat = s end
    end

    -- Best: ask vehicle for the seat's container part (seat part)
    if v.getPartForSeatContainer then
        local p = v:getPartForSeatContainer(seat)
        if p then return p end
    end

    -- Fallbacks (some mods/scripts use these ids)
    return v:getPartById("SeatFrontLeft")
        or v:getPartById("SeatFrontRight")
        or v:getPartById("SeatFront")
        or v:getPartById("Seat")
end

function ISVehicleDashboard:_getStainTex(level, variant)
    self.__YourDashStainCache = self.__YourDashStainCache or {}
    local key = tostring(level) .. "_" .. tostring(variant)
    local cached = self.__YourDashStainCache[key]
    if cached == false then return nil end
    if cached then return cached end

    local name = string.format("level_%d_%d.png", level, variant)
    local tex = YourDash.GetDashboardTexture and
        YourDash.GetDashboardTexture(self.__YourDashFamily or "standard", "stain", name) or nil
    self.__YourDashStainCache[key] = tex or false
    return tex
end

function ISVehicleDashboard:_pickStainVariant(level)
    local n = self.STAIN_VARIANTS_PER_LEVEL or 5

    -- try random a few times first
    for _ = 1, n do
        local v = ZombRand(n) + 1
        local tex = self:_getStainTex(level, v)
        if tex then return v, tex end
    end

    -- then deterministic fallback
    for v = 1, n do
        local tex = self:_getStainTex(level, v)
        if tex then return v, tex end
    end

    return nil, nil
end

function ISVehicleDashboard:_updateStainLayer()
    if not self.vehicle then
        self.__stainTex = nil
        self.__stainLevel = nil
        self.__stainVariant = nil
        self.__stainSeatCond = nil
        return
    end

    local seatPart = self:_getDriverSeatPart()
    local cond = 100
    if seatPart and seatPart.getCondition then
        local c = seatPart:getCondition()
        if c ~= nil then cond = c end
    end

    -- Only update when condition changed enough to cross a level boundary
    local level = self:_stainLevelFromSeatCondition(cond)

    if (self.__stainLevel ~= level) then
        self.__stainLevel = level
        self.__stainSeatCond = cond

        local var, tex = nil, nil
        if self.__YourDashRetainedStainLevel == level and self.__YourDashRetainedStainVariant then
            var = self.__YourDashRetainedStainVariant
            tex = self:_getStainTex(level, var)
        end
        if not tex then var, tex = self:_pickStainVariant(level) end
        self.__stainVariant = var
        self.__stainTex = tex
        self.__YourDashRetainedStainLevel = nil
        self.__YourDashRetainedStainVariant = nil
    end
end

-- =========================
-- Cracks layer (below stain) - 4 levels, NO variants
-- =========================

-- hide cracks if windshield condition is above this
ISVehicleDashboard.CRACK_HIDE_ABOVE = ISVehicleDashboard.CRACK_HIDE_ABOVE or 80

-- thresholds for 4 levels (tweak however you like)
-- cond <= 80 shows cracks:
-- 80..61 -> level 1
-- 60..41 -> level 2
-- 40..21 -> level 3
-- 20..0  -> level 4
function ISVehicleDashboard:_crackLevelFromWindshieldCondition(cond)
    cond = cond or 100
    if cond < 0 then cond = 0 elseif cond > 100 then cond = 100 end

    if cond > (self.CRACK_HIDE_ABOVE or 80) then
        return nil
    end

    if cond >= 55 then return 1 end
    if cond >= 30 then return 2 end
    if cond >= 10 then return 3 end
    return 4
end

-- Load the single authored crack texture for a level.
function ISVehicleDashboard:_getCrackTex(level)
    self.__YourDashCrackCache = self.__YourDashCrackCache or {}
    local cached = self.__YourDashCrackCache[level]
    if cached ~= nil then
        return cached or nil
    end

    local family = self.__YourDashFamily or "standard"
    local name = string.format("level_%d.png", level)
    local tex = YourDash.GetDashboardTexture and YourDash.GetDashboardTexture(family, "cracks", name) or nil


    self.__YourDashCrackCache[level] = tex or false
    return tex
end

function ISVehicleDashboard:_updateCrackLayer()
    if not self.vehicle then
        self.__crackTex = nil
        self.__crackLevel = nil
        self.__windshieldCond = nil
        return
    end

    local cond = self:_getWindshieldCondition()
    if cond == nil then
        self.__crackTex = nil
        self.__crackLevel = nil
        self.__windshieldCond = nil
        return
    end

    local level = self:_crackLevelFromWindshieldCondition(cond)

    -- no cracks
    if not level then
        self.__crackTex = nil
        self.__crackLevel = nil
        self.__windshieldCond = cond
        return
    end

    -- only swap texture when level changes
    if self.__crackLevel ~= level then
        self.__crackLevel = level
        self.__windshieldCond = cond
        self.__crackTex = self:_getCrackTex(level)
    end
end

-- =========================
-- Windshield condition helper (needed by cracks)
-- =========================
function ISVehicleDashboard:_getWindshieldPart()
    local v = self.vehicle
    if not v then return nil end

    -- Common ids (vanilla + mods)
    local p =
        v:getPartById("Windshield") or
        v:getPartById("WindshieldFront") or
        v:getPartById("Windscreen") or
        v:getPartById("WindscreenFront")

    if p then return p end

    -- Fallback: scan for anything containing windshield/windscreen (prefer "front")
    local best, bestScore = nil, -999
    for i = 0, v:getPartCount() - 1 do
        local part = v:getPartByIndex(i)
        if part and part.getId then
            local id = part:getId()
            if id then
                local s = string.lower(tostring(id))
                if string.find(s, "windshield", 1, true) or string.find(s, "windscreen", 1, true) then
                    local score = 0
                    if s == "windshield" or s == "windscreen" then score = score + 8 end
                    if string.find(s, "front", 1, true) then score = score + 4 end
                    if string.find(s, "rear",  1, true) then score = score - 4 end
                    if score > bestScore then
                        bestScore = score
                        best = part
                    end
                end
            end
        end
    end

    return best
end

function ISVehicleDashboard:_getWindshieldCondition()
    local part = self:_getWindshieldPart()
    if not part then return nil end

    -- Missing/uninstalled part -> treat as destroyed
    if part.getItemType and part:getItemType()
        and part.getInventoryItem and (not part:getInventoryItem()) then
        return 0
    end

    local cond = 100
    if part.getCondition then
        local c = part:getCondition()
        if c ~= nil then cond = c end
    end

    -- If it has a window and it's destroyed, force worst condition
    if part.getWindow then
        local w = part:getWindow()
        if w and w.isDestroyed and w:isDestroyed() then
            cond = 0
        end
    end

    return cond
end

function ISVehicleDashboard:_YourDashEnsureGlassOverlay()
    if self.__YourDashGlassOverlay then return end
    if not self.backgroundTex then return end

    local o = ISPanel:new(0, 0, 1, 1)
    o:initialise()
    o:instantiate()
    o.backgroundColor = { r=0, g=0, b=0, a=0 }
    o.borderColor     = { r=0, g=0, b=0, a=0 }
    o.target = self
    o.__YourDashGlass = true

    -- This visual layer covers the whole dashboard, so it must be truly
    -- click-through.  B42 exposes setWantMouseEvents(), not
    -- setConsumeMouseEvents(), on Lua UI elements.
    o.onclick = nil
    function o:onMouseDown() return false end
    function o:onMouseUp() return false end
    function o:onMouseMove(dx,dy) end
    function o:onMouseMoveOutside(dx,dy) end
    function o:onMouseUpOutside(x,y) return false end
    YourDash_SetMouseTransparent(o)

    function o:render()
        local dash = self.target or self.parent
        if not dash then return end
        local w, h = self.width, self.height
        if w <= 0 or h <= 0 then return end

        local wearA = (YourDash and YourDash.GetWearFxAlpha and YourDash.GetWearFxAlpha()) or 0.90

        local function drawWear(tex, alpha)
            if not tex then return end
            local tw = tex:getWidthOrig()
            self:drawTexture(tex, math.floor((w - tw) * 0.5), 0, alpha)
        end

        -- Physical glass effects sit above the instruments.  Use each authored
        -- canvas at its native pack resolution; several sport canvases include
        -- a deliberate one-pixel padding difference from the gauge texture.
        if wearA > 0 then
            drawWear(dash.__crackTex, wearA)
            drawWear(dash.__stainTex, wearA)
        end

        -- The base/ticks/shadow stack is rendered by backgroundTex.  This
        -- final panel is only the physical glass wear layer.
    end


    self.__YourDashGlassOverlay = o
    self:addChild(o)
end

function ISVehicleDashboard:_YourDashPositionGlassOverlay()
    local o = self.__YourDashGlassOverlay
    if not o or not self.backgroundTex then return end
    o:setX(self.backgroundTex:getX())
    o:setY(self.backgroundTex:getY())
    o:setWidth(self.backgroundTex:getWidth())
    o:setHeight(self.backgroundTex:getHeight())
end

function ISVehicleDashboard:_YourDashFinalizeWearOrder()
    local overlay = self.__YourDashGlassOverlay
    if not overlay then return end
    if overlay.bringToTop then
        overlay:bringToTop()
    elseif self.removeChild and self.addChild then
        self:removeChild(overlay)
        self:addChild(overlay)
    end
end


-- =========================
-- Patch: new()
-- =========================
local _oldNew = ISVehicleDashboard.new
function ISVehicleDashboard:new(playerNum, chr)
    local o = _oldNew(self, playerNum, chr)

    -- Vehicle profile is resolved in setVehicle(); standard is the safe startup pack.
    o.__YourDashFamily = "standard"
    o.__YourDashAccent = "base"

    -- Apply selected texture pack + offsets
    local useLarge = YourDash and YourDash.UseLargeTextures and YourDash.UseLargeTextures() or false
    o:_YourDashApplyOffsets(useLarge)
    o:_YourDashApplyTextureSet(useLarge, true)

    -- State init
    o.__lidMode = false

    -- Stain/crack init
    o.__stainTex = nil
    o.__stainLevel = nil
    o.__stainVariant = nil
    o.__stainSeatCond = nil
    o.__YourDashStainCache = o.__YourDashStainCache or {}

    o.__crackTex = nil
    o.__crackLevel = nil
    o.__windshieldCond = nil
    o.__YourDashCrackCache = o.__YourDashCrackCache or {}

    return o
end


-- =========================
-- Patch: createChildren()
-- =========================
local _oldCreateChildren = ISVehicleDashboard.createChildren
function ISVehicleDashboard:createChildren()
    _oldCreateChildren(self)

    -- Remove old vanilla icons
    if self.engineTex then
        self.engineTex:setVisible(false)
        self.engineTex.onclick = nil
        self.engineTex.mouseovertext = nil
        self.engineTex.backgroundColor = { r=0, g=0, b=0, a=0 }
    end
    if self.batteryTex then
        self.batteryTex:setVisible(false)
        self.batteryTex.onclick = nil
        self.batteryTex.mouseovertext = nil
        self.batteryTex.backgroundColor = { r=0, g=0, b=0, a=0 }
    end
    if self.speedregulatorTex then
        self.speedregulatorTex:setVisible(false)
        self.speedregulatorTex.onclick = nil
        self.speedregulatorTex.mouseovertext = nil
    end

    -- Gear letter color (btn_partSpeed is an ISLabel)
    if self.btn_partSpeed then
        local r,g,b = 0.22, 0.20, 0.10
        -- works across versions: either fields or setter exists
        if self.btn_partSpeed.setColor then
            self.btn_partSpeed:setColor(r,g,b)
        else
            self.btn_partSpeed.r = r
            self.btn_partSpeed.g = g
            self.btn_partSpeed.b = b
        end
        -- keep existing alpha (vanilla uses ~0.85)
        self.btn_partSpeed.a = self.btn_partSpeed.a or 0.85
        local useLarge = YourDash and YourDash.UseLargeTextures and YourDash.UseLargeTextures() or false
        self:_YourDashApplyGearFont(useLarge)
    end

    -- Fuel arrow lid overlays (drawn on top of day arrows, only when lid mode is on)
    local function _makeOverlay(tex)
        if not tex then return nil end
        local img = ISImage:new(0, 0, tex:getWidthOrig(), tex:getHeightOrig(), tex)
        img:initialise()
        img:instantiate()
        YourDash_SetMouseTransparent(img)
        img.onclick = nil
        img.target = nil
        img.mouseovertext = nil
        img.backgroundColor = { r=1, g=1, b=1, a=0 }
        img:setVisible(false)
        self:addChild(img)
        return img
    end

    -- Only create overlays if lid texture is actually different from day texture
    if self.__fuelL_lid and self.__fuelL_day and (self.__fuelL_lid ~= self.__fuelL_day) then
        self.leftSideFuelLid = self.leftSideFuelLid or _makeOverlay(self.__fuelL_lid)
    end
    if self.__fuelR_lid and self.__fuelR_day and (self.__fuelR_lid ~= self.__fuelR_day) then
        self.rightSideFuelLid = self.rightSideFuelLid or _makeOverlay(self.__fuelR_lid)
    end

    -- Create warning lights (non-clickable, tooltip only when on)
    self.warnCruiseTex  = self.warnCruiseTex  or self:_newWarnImage(self.__warn_cruise)
    self.warnBatteryTex = self.warnBatteryTex or self:_newWarnImage(self.__warn_battery)
    self.warnBrakeTex   = self.warnBrakeTex   or self:_newWarnImage(self.__warn_brake)
    self.warnCheckTex   = self.warnCheckTex   or self:_newWarnImage(self.__warn_check)
    self.warnStopTex    = self.warnStopTex    or self:_newWarnImage(self.__warn_stop)
    self.warnDoorTex    = self.warnDoorTex    or self:_newWarnImage(self.__warn_door)
    self.warnFuelTex    = self.warnFuelTex    or self:_newWarnImage(self.__warn_fuel)
    self.warnLightTex   = self.warnLightTex   or self:_newWarnImage(self.__warn_light)
    self.warnCruiseTex.__offTexture  = self.__warn_cruise_off
    self.warnBatteryTex.__offTexture = self.__warn_battery_off
    self.warnBrakeTex.__offTexture   = self.__warn_brake_off
    self.warnCheckTex.__offTexture   = self.__warn_check_off
    self.warnStopTex.__offTexture    = self.__warn_stop_off
    self.warnDoorTex.__offTexture    = self.__warn_door_off
    self.warnFuelTex.__offTexture    = self.__warn_fuel_off
    self.warnLightTex.__offTexture   = self.__warn_light_off


    -- =========================
    -- Needle layer (drawn as a CHILD so glass overlay can cover it)
    -- =========================
    if not self.__YourDashNeedleLayer then
        local p = ISPanel:new(0, 0, 1, 1)
        p:initialise()
        p:instantiate()
        p.backgroundColor = { r=0, g=0, b=0, a=0 }
        p.borderColor     = { r=0, g=0, b=0, a=0 }
        p.target = self
        p.__YourDashNeedles = true
        p.onclick = nil
        YourDash_SetMouseTransparent(p)

        function p:render()
            local dash = self.target
            if not dash or not dash.vehicle then return end

            local family = dash.__YourDashFamily or "standard"
            local rpmVal = math.max(0, math.min(1, dash.rpmValue or 0.0))
            local speedVal = math.max(0, math.min(1, dash.speedValue or 0.0))
            local fuelVal = math.max(0, math.min(1, dash.fuelValue or 0.0))
            local rpm = rpmVal * 7000
            local mph = math.max(0, dash.__YourDashSmoothMPH or 0)
            local volts = dash.__YourDashVoltage or 8.0

            local rpmAngle, speedAngle, fuelAngle, voltageAngle
            if family == "heavy" then
                rpmAngle = -30 + math.min(rpm, 6000) / 6000 * 240
                if mph <= 5 then
                    speedAngle = -30
                else
                    speedAngle = -30 + ((math.min(mph, 90) - 5) / 10) * 30
                end
                -- Heavy short-needle artwork is authored pointing +90 degrees
                -- at texture angle zero.  Subtract that baked-in direction so
                -- the physical endpoints remain 25 degrees through 155 degrees
                -- from west.  Voltage spans the printed 8V..18V scale.
                fuelAngle = (25 + fuelVal * 130) - 90
                voltageAngle = (25 + math.max(0, math.min(1, (volts - 8) / 10)) * 130) - 90
            elseif family == "sport" then
                rpmAngle = -45 + math.min(rpm, 7000) / 7000 * 270
                speedAngle = -45 + math.min(mph, 160) / 160 * 270
                fuelAngle = -65 + fuelVal * 130
                voltageAngle = 245 - math.max(0, math.min(1, (volts - 8) / 8)) * 130
            else
                -- Preserve the proven standard-dash mappings exactly.
                rpmAngle = math.deg(dash.RPM_MIN_ANGLE + (dash.RPM_MAX_ANGLE - dash.RPM_MIN_ANGLE) * rpmVal)
                fuelAngle = math.deg(dash.FUEL_MIN_ANGLE + (dash.FUEL_MAX_ANGLE - dash.FUEL_MIN_ANGLE) * fuelVal)
                local legacyMph = speedVal * 120.0
                if legacyMph <= 20.0 then
                    speedAngle = legacyMph * 1.125
                else
                    speedAngle = 22.5 + (legacyMph - 20.0) * 1.875
                end
                if speedAngle < 0 then speedAngle = 0 elseif speedAngle > 210 then speedAngle = 210 end
            end

            local baseX = (dash.dashOffset and dash.dashOffset.x) or 0
            local baseY = (dash.dashOffset and dash.dashOffset.y) or 0

            local longDay, longLid = dash.__needleLong_day, dash.__needleLong_lid
            local midDay, midLid = dash.__needleMid_day, dash.__needleMid_lid
            local shortDay, shortLid = dash.__needleShort_day, dash.__needleShort_lid
            local rpmDay, rpmLid = longDay, longLid
            if family == "heavy" or family == "sport" then rpmDay, rpmLid = midDay or longDay, midLid or longLid end

            local function drawNeedles(rpmTex, speedTex, fuelTex, voltageTex)
                if rpmTex and dash.rpmOffset then
                    self:DrawTextureAngle(rpmTex, baseX + dash.rpmOffset.x, baseY + dash.rpmOffset.y, rpmAngle)
                end
                if speedTex and dash.speedOffset then
                    self:DrawTextureAngle(speedTex, baseX + dash.speedOffset.x, baseY + dash.speedOffset.y, speedAngle)
                end
                if fuelTex and dash.fuelOffset then
                    self:DrawTextureAngle(fuelTex, baseX + dash.fuelOffset.x, baseY + dash.fuelOffset.y, fuelAngle)
                end
                if family ~= "standard" and voltageTex and dash.voltageOffset then
                    self:DrawTextureAngle(voltageTex, baseX + dash.voltageOffset.x, baseY + dash.voltageOffset.y, voltageAngle)
                end
            end

            -- 1) DAY needles (static)
            drawNeedles(rpmDay, longDay, shortDay, shortDay)

            -- 2) LID needles (lit overlay, sag + crash)
            local lidActive = (dash.__lidMode == true)
            if lidActive then
                local lidAlpha = (dash.__lidOverlayAlpha ~= nil) and dash.__lidOverlayAlpha or 1.0
                local glow = (dash.__elecDimAlpha or 1.0) * (dash.__impactDimAlpha or 1.0) * lidAlpha

                if glow > 0.001 then
                    local oldA = 1.0
                    if self.getAlpha then oldA = self:getAlpha() elseif self.alpha then oldA = self.alpha end
                    if self.setAlpha then self:setAlpha(glow) else self.alpha = glow end

                    drawNeedles(rpmLid, longLid, shortLid, shortLid)

                    if self.setAlpha then self:setAlpha(oldA) else self.alpha = oldA end
                end
            end

            -- 3) Needle center cap (static, under glass)
            if dash.needleCenter then
                self:drawTexture(dash.needleCenter, 0, 0, 1)
            end
        end

        self.__YourDashNeedleLayer = p
        self:addChild(p)
    end

    -- Door button
    if self.doorTex and self.__lock_off then
        self:_setImageTextureAndSize(self.doorTex, self.__lock_off)
        self:_setImageEnabled(self.doorTex, true, getText("Tooltip_Dashboard_LockedDoors"), ISVehicleDashboard.onClickDoors, self)
        self:_installPressedEffect(self.doorTex, self.__YourDashFamily == "heavy" and 1.0 or 0.96)
    end

    -- Trunk button
    if self.trunkTex and self.__trunk_off then
        self:_setImageTextureAndSize(self.trunkTex, self.__trunk_off)
        self:_setImageEnabled(self.trunkTex, true, nil, ISVehicleDashboard.onClickTrunk, self)
        self:_installPressedEffect(self.trunkTex, self.__YourDashFamily == "heavy" and 1.0 or 0.96)
    end

    -- Lights knob (reuse lightsTex)
    if self.lightsTex and self.__light_knob then
        self:_YourDashApplyLightTexture(self.__light_knob)
        self:_setImageEnabled(self.lightsTex, true, getText("Tooltip_Dashboard_Headlights"), ISVehicleDashboard.onClickHeadlights, self)
        -- Only the sport switch uses the generic press shrink.  Standard is a
        -- rotating knob; heavy has authored OFF/ON depth textures.
        self:_installPressedEffect(self.lightsTex, 0.96)

        function self.lightsTex:render()
            if not self.texture then return end
            local dash = self.target or self.parent
            local family = (dash and dash.__YourDashFamily) or "standard"

            if family == "sport" then
                local scale = ((not self.__disabled) and self.__pressed) and (self.__pressedScale or 0.96) or 1.0
                local dw, dh = self.width * scale, self.height * scale
                self:drawTextureScaled(self.texture,
                    (self.width - dw) * 0.5, (self.height - dh) * 0.5,
                    dw, dh, self.alpha or 1)
                return
            end

            local ang = family == "heavy" and 0 or ((dash and dash.__lightKnobAngle) or 0)
            local textureW = self.__YourDashTextureWidth or self.width
            local textureH = self.__YourDashTextureHeight or self.height
            local hitbox = self.__YourDashLightHitbox
            local cx = self.x + (textureW * 0.5)
            local cy = self.y + (textureH * 0.5)
            if family == "heavy" and hitbox then
                cx = cx - (hitbox.x or 0)
                cy = cy - (hitbox.y or 0)
            end
            if family == "heavy" and dash then
                cx = cx + (dash.__YourDashHeavyLightAlignX or 0)
                cy = cy + (dash.__YourDashHeavyLightAlignY or 0)
            end
            self.parent:DrawTextureAngle(self.texture, cx, cy, ang)
        end
    end

    -- Window button
    if self.__window_switch then
        self.windowTex = ISImage:new(0, 0,
            self.__window_switch:getWidthOrig(),
            self.__window_switch:getHeightOrig(),
            self.__window_switch
        )
        self.windowTex:initialise()
        self.windowTex:instantiate()
        self.windowTex.target = self
        self.windowTex.onclick = ISVehicleDashboard.onClickWindow
        self.windowTex.backgroundColor = { r=0, g=0, b=0, a=0 }

        self:_installStaticTextureRender(self.windowTex)
        self:addChild(self.windowTex)
        self:_setImageTextureAndSize(self.windowTex, self.__window_switch)
        self.windowTex.__pressed = false

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
                dash:_YourDashPositionWindowState(state)
            elseif wp then
                local w = wp:getWindow()
                if w and w:isOpen() then
                    dash:_setImageTextureAndSize(self, dash.__window_switch_pull)
                    dash:_YourDashPositionWindowState("up")
                else
                    dash:_setImageTextureAndSize(self, dash.__window_switch_push)
                    dash:_YourDashPositionWindowState("down")
                end
            else
                dash:_setImageTextureAndSize(self, dash.__window_switch)
                dash:_YourDashPositionWindowState("neutral")
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
                dash:_YourDashPositionWindowState("neutral")
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
                dash:_YourDashPositionWindowState("neutral")
            end
            if dash then dash.__YourDashWindowCommand = nil end
            if _upOut then return _upOut(self, x, y) end
            return true
        end

        local _move = self.windowTex.onMouseMove
        function self.windowTex:onMouseMove(dx, dy)
            local dash = self.target
            local family = dash and (dash.__YourDashFamily or "standard") or "standard"
            if family == "heavy" or family == "sport" then
                local isUp = self:getMouseY() < (self.height * 0.5)
                self.mouseovertext = getText(isUp and "ContextMenu_Close_window" or "ContextMenu_Open_window")
            end
            if _move then return _move(self, dx, dy) end
        end
    end

    self:_YourDashEnsureSideButtons()

    -- Background stacking: day always, lid drawn on top (inside backgroundTex render)
    if self.backgroundTex and (not self.backgroundTex.__YourDashBgStacked) then
        self.backgroundTex.__YourDashBgStacked = true
        self.backgroundTex.target = self -- so render can read dash state/tex
        function self.backgroundTex:render()
            local dash = self.target or self.parent

            local w, h = self.width, self.height

            local function drawCenteredTop(tex, alpha)
                if not tex then return end
                local tw = tex:getWidthOrig()
                self:drawTexture(tex, math.floor((w - tw) * 0.5), 0, alpha or 1)
            end

            -- New masked artwork order: base dash -> printed/lit ticks -> shadow.
            drawCenteredTop(dash and dash.__dashTex, self.alpha or 1)

            if self.texture then
                self:drawTextureScaled(self.texture, 0, 0, w, h, self.alpha or 1)
            end

            -- lid/backlight layer flashes + cranking-dims
            local lidTex = dash and dash.__bg_lid or nil
            local lidAlpha = 0
            if dash then
                lidAlpha = (dash.__lidOverlayAlpha ~= nil) and dash.__lidOverlayAlpha or (dash.__lidMode and 1.0 or 0.0)
            end
            if lidTex and lidAlpha > 0 then
                local elec   = (dash and dash.__elecDimAlpha) or 1.0
                local impact = (dash and dash.__impactDimAlpha) or 1.0
                self:drawTextureScaled(lidTex, 0, 0, w, h, lidAlpha * elec * impact)
            end
            drawCenteredTop(dash and dash.__dashShadowTex, self.alpha or 1)
        end

    end

    self:_YourDashEnsureGlassOverlay()
    self:_YourDashEnsureStateLEDs()
    self:_YourDashPositionGlassOverlay()
    self:_YourDashFinalizeWearOrder()

    self:onResolutionChange()
end

-- =========================
-- Patch: setVehicle()
-- =========================
local _oldSetVehicle = ISVehicleDashboard.setVehicle
function ISVehicleDashboard:setVehicle(vehicle)
    local previousVehicle = self.vehicle
    _oldSetVehicle(self, vehicle)

    if previousVehicle ~= vehicle then
        self.__YourDashSmoothMPH, self.__YourDashSmoothMPHVel = 0.0, 0.0
        self.__YourDashBatterySampleCharge = nil
        self.__YourDashBatterySampleAge = nil
        self.__YourDashMeasuredDrop = nil
        self.__YourDashVoltage, self.__YourDashVoltageVel = nil, nil
        self.__YourDashLoadSampleT, self.__YourDashLoadUnits = nil, nil
        self.__YourDashHeadlightSwitchOn = vehicle and vehicle:getHeadlightsOn() == true or false
        self.__YourDashHeadlightSwitchPending = 0
        self.__YourDashWindowCommand = nil
        self.__YourDashCranking = false
        self.__YourDashCrankSagActive = false
        self.__YourDashCrankKick01 = 0
        self.__YourDashCrankDimTarget = 1
        self.__crankDimDelayT, self.__crankDimPrev, self.__crankSagPrev = 0, false, false
        self.__crankKickT, self.__crankKickActive = 0, false
        self.__crankBattFlickerT, self.__crankBattFlickerActive = 0, false
        self.__elecDimAlpha = 1
        self.__warnChkState, self.__warnChkT = 0, 0
        self.__warnChkRelease, self.__warnChkPrevCranking = nil, false
        self.__stainTex, self.__stainLevel, self.__stainVariant, self.__stainSeatCond = nil, nil, nil, nil
        self.__crackTex, self.__crackLevel, self.__windshieldCond = nil, nil, nil
        self.__YourDashRetainedStainLevel, self.__YourDashRetainedStainVariant = nil, nil
    end

    if not vehicle then
        self.rpmValue, self.rpmVel = 0.0, 0.0
        self.speedValue, self.speedVel = 0.0, 0.0
        self.__YourDashSmoothMPH, self.__YourDashSmoothMPHVel = 0.0, 0.0
        self.__YourDashBatterySampleCharge = nil
        self.__YourDashBatterySampleAge = nil
        self.__YourDashMeasuredDrop = nil
        return
    end

    local profile = YourDash.GetVehicleProfile and YourDash.GetVehicleProfile(vehicle) or nil
    local family = profile and (profile.family or profile[1]) or "standard"
    local accent = profile and (profile.accent or profile[2]) or "base"
    if self.__YourDashFamily ~= family or self.__YourDashAccent ~= accent then
        self.__YourDashFamily = family
        self.__YourDashAccent = accent
        self:_YourDashApplyTextureSet(false, false)
    end

    if self.fuelGauge then self.fuelGauge:setVisible(false) end
    if self.engineGauge then self.engineGauge:setVisible(false) end
    if self.speedGauge then self.speedGauge:setVisible(false) end
end

-- =========================
-- Patch: prerender()
-- =========================
local _oldPrerender = ISVehicleDashboard.prerender
function ISVehicleDashboard:prerender()
    if not self.vehicle or not ISUIHandler.allUIVisible then return end
    -- Script identity may change in place for debug-respawned vehicles.  Core
    -- validates its cache identity; re-read the lightweight profile each frame
    -- so this dashboard can swap family/accent without a new vehicle object.
    if YourDash.GetVehicleProfile then
        local profile = YourDash.GetVehicleProfile(self.vehicle)
        local family = profile and (profile.family or profile[1]) or "standard"
        local accent = profile and (profile.accent or profile[2]) or "base"
        if family ~= self.__YourDashFamily or accent ~= self.__YourDashAccent then
            self.__YourDashFamily, self.__YourDashAccent = family, accent
            self:_YourDashApplyTextureSet(false, false)
        end
    end
    -- Hot-swap when size, family, or sports accent changes.
    local scaleKey = YourDash.GetScaleKey and YourDash.GetScaleKey() or "1x"
    local wantedTextureKey = (self.__YourDashFamily or "standard") .. ":" ..
        (self.__YourDashAccent or "base") .. ":" .. scaleKey
    if self.__YourDashTextureKey ~= wantedTextureKey then
        self:_YourDashApplyTextureSet(scaleKey == "2x", false)
    end
    self:_YourDashUpdateDashBaseForTrunk()

    _oldPrerender(self)
    self:_YourDashScaleIgnition()

    local hasPower = self:_hasBatteryPower()
    local lidOn = self.vehicle:getHeadlightsOn() and hasPower

    self:_applyLidMode(lidOn)

    local engineSpeedValue = 0.0
    local speedValue = 0.0
    self.__YourDashRPM = 0
    self.__YourDashSpeedMPH = 0
    if self.vehicle:isEngineRunning() then
        self.__YourDashRPM = math.max(0, self.vehicle:getEngineSpeed() or 0)
        local speedKph = math.abs(self.vehicle:getCurrentSpeedKmHour() or 0)
        self.__YourDashSpeedMPH = speedKph * 0.621371192237
        engineSpeedValue = math.max(0, math.min(1, self.__YourDashRPM / 7000))
        speedValue = math.max(0, math.min(1, speedKph / 120))
    end

    local dt = UIManager.getSecondsSinceLastRender()
    if not dt or dt <= 0 then dt = 1/30 end
    if (self.__YourDashHeadlightSwitchPending or 0) > 0 then
        self.__YourDashHeadlightSwitchPending = math.max(0,
            self.__YourDashHeadlightSwitchPending - math.min(dt, 0.25))
    end

    local cranking = self:_YourDashIsCranking()
    self:_YourDashUpdateCrankEnvelope(cranking, dt)
    self:_YourDashUpdateVoltage(dt, cranking)

    self:_updateStainLayer()
    self:_updateCrackLayer()


    -- =========================
    -- Crash flash dim multiplier (3 quick dips)
    -- =========================
    self.__impactDimAlpha = self.__impactDimAlpha or 1.0

    local impactTarget = 1.0
    if self.__impactFlashActive then
        self.__impactFlashT = (self.__impactFlashT or 0) + dt

        local pulseT  = self.CRASH_DIM_PULSE_TIME
        local pulses  = self.CRASH_DIM_PULSES
        local totalT  = pulseT * pulses

        if self.__impactFlashT < totalT then
            local u   = (self.__impactFlashT % pulseT) / pulseT   -- 0..1 within current dip
            local tri = 1 - math.abs(2*u - 1)                     -- 0 at edges, 1 at center
            impactTarget = 1 - tri * (1 - self.CRASH_DIM_MIN_ALPHA)
        else
            self.__impactFlashActive = false
            self.__impactFlashT = 0
            impactTarget = 1.0
        end
    end

    self.__impactDimAlpha = self._ease(self.__impactDimAlpha, impactTarget, self.CRASH_DIM_SMOOTH_TIME, dt)

    local needleResponse = self:_YourDashNeedleResponse()
    local needleSmoothUp = needleResponse.up or self.NEEDLE_SMOOTHTIME_UP
    local needleSmoothDown = needleResponse.down or self.NEEDLE_SMOOTHTIME_DOWN

    self.rpmValue = (self.rpmValue == nil) and engineSpeedValue or self.rpmValue
    self.rpmVel   = self.rpmVel or 0.0
    local st = (engineSpeedValue > self.rpmValue) and needleSmoothUp or needleSmoothDown
    self.rpmValue, self.rpmVel = self._smoothDamp(self.rpmValue, engineSpeedValue, self.rpmVel, st, self.NEEDLE_MAXSPEED, dt)

    self.speedValue = (self.speedValue == nil) and speedValue or self.speedValue
    self.speedVel   = self.speedVel or 0.0
    local st2 = (speedValue > self.speedValue) and needleSmoothUp or needleSmoothDown
    self.speedValue, self.speedVel = self._smoothDamp(self.speedValue, speedValue, self.speedVel, st2, self.NEEDLE_MAXSPEED, dt)

    local targetMph = self.__YourDashSpeedMPH or 0
    self.__YourDashSmoothMPH = self.__YourDashSmoothMPH or targetMph
    self.__YourDashSmoothMPHVel = self.__YourDashSmoothMPHVel or 0
    local mphSmooth = (targetMph > self.__YourDashSmoothMPH) and needleSmoothUp or needleSmoothDown
    self.__YourDashSmoothMPH, self.__YourDashSmoothMPHVel = self._smoothDamp(
        self.__YourDashSmoothMPH, targetMph, self.__YourDashSmoothMPHVel,
        mphSmooth, self.NEEDLE_MAXSPEED, dt)


    -- Door icon (don't swap when no power)
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
            self:_setImageTextureAndSize(self.doorTex, doorTexture)
        end
        self.doorTex.backgroundColor = { r=0, g=0, b=0, a=0 }
    end

    -- Trunk icon (don't swap when no power)
    if self.trunkTex and self.__blank_btn and self.vehicle then
        local hasTrunk = self:_YourDashHasTrunkLock()
        self:_YourDashPositionTrunkControl(hasTrunk)
        self.trunkTex:setVisible(true)

        if not hasTrunk then
            self:_setImageTextureAndSize(self.trunkTex, self.__blank_btn)
            self.trunkTex.onclick = nil
            self.trunkTex.mouseovertext = nil
            self.trunkTex.__disabled = true
            self.trunkTex.backgroundColor = { r=0, g=0, b=0, a=0 }
        else
            -- Always keep it clickable when trunk exists
            self.trunkTex.__disabled = false
            self.trunkTex.onclick = ISVehicleDashboard.onClickTrunk
            self.trunkTex.target  = self

            if hasPower then
                if self.vehicle:isTrunkLocked() then
                    self:_setImageTextureAndSize(self.trunkTex, self.__trunk_on)
                    self.trunkTex.mouseovertext = getText("Tooltip_Dashboard_TrunkLocked")
                else
                    self:_setImageTextureAndSize(self.trunkTex, self.__trunk_off)
                    self.trunkTex.mouseovertext = getText("Tooltip_Dashboard_TrunkUnlocked")
                end
            else
                -- Freeze to unpowered/unlid look
                self:_setImageTextureAndSize(self.trunkTex, self.__trunk_off)
                self.trunkTex.mouseovertext = nil
            end

            self.trunkTex.backgroundColor = { r=0, g=0, b=0, a=0 }
        end
    end

    local function setStateLED(img, texture)
        if not img then return end
        if texture and img.texture ~= texture then self:_setImageTextureAndSize(img, texture) end
        img:setVisible(texture ~= nil)
    end
    if self.__led_off then
        local doorLED = self.__led_off
        if hasPower then
            if self.vehicle:areAllDoorsLocked() then doorLED = self.__led_on
            elseif self.vehicle:isAnyDoorLocked() then doorLED = self.__led_partial or self.__led_off end
        end
        local trunkLED = nil
        if self:_YourDashHasTrunkLock() then
            trunkLED = self.__led_off
            if hasPower and self.vehicle:isTrunkLocked() then
                trunkLED = self.__led_on
            end
        end
        setStateLED(self.__YourDashDoorLED, doorLED)
        setStateLED(self.__YourDashTrunkLED, trunkLED)
    else
        setStateLED(self.__YourDashDoorLED, nil)
        setStateLED(self.__YourDashTrunkLED, nil)
    end


    -- Lights knob angle + untint
    local lightSwitchOn = self:_YourDashGetHeadlightSwitchState()
    if self.__YourDashFamily == "heavy" and self.lightsTex then
        local t = lightSwitchOn and self.__light_knob_on or self.__light_knob_off
        if t and self.lightsTex.texture ~= t then self:_YourDashApplyLightTexture(t) end
        -- Measured from the hollow circular base rather than the pressed
        -- artwork's outer shadow.  The logical-ON (*_off filename) export is
        -- left-shifted by 1/2/3/4 px across the four authored scales.
        local scaleKey = YourDash.GetScaleKey and YourDash.GetScaleKey() or "1x"
        self.__YourDashHeavyLightAlignX = lightSwitchOn and (HEAVY_LIGHT_ALIGN_X[scaleKey] or 0) or 0
        self.__YourDashHeavyLightAlignY = 0
        self.__lightKnobAngle = 0
    elseif self.__YourDashFamily == "standard" then
        -- The redesigned standard texture is already authored 90 degrees from
        -- the legacy knob.  Use its new baseline instead of applying the old
        -- rotation a second time.
        self.__lightKnobAngle = lightSwitchOn and 90 or 0
    else
        -- Sport is a simple momentary-looking switch: it has no persistent
        -- indicator or rotation, only the press shrink installed above.
        self.__lightKnobAngle = 0
        self.__YourDashHeavyLightAlignX, self.__YourDashHeavyLightAlignY = 0, 0
    end
    if self.lightsTex then
        self.lightsTex.backgroundColor = { r=0, g=0, b=0, a=0 }
    end

    -- Window hover text
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

            local family = self.__YourDashFamily or "standard"
            if family == "heavy" or family == "sport" then
                local isUp = self.windowTex:getMouseY() < (self.windowTex.height * 0.5)
                self.windowTex.mouseovertext = getText(isUp and "ContextMenu_Close_window" or "ContextMenu_Open_window")
            else
                local w = windowPart:getWindow()
                if w:isOpen() then
                    self.windowTex.mouseovertext = getText("ContextMenu_Close_window")
                else
                    self.windowTex.mouseovertext = getText("ContextMenu_Open_window")
                end
            end
        end

        if (not self.windowTex.__pressed) and self.__window_switch then
            if self.windowTex.texture ~= self.__window_switch then
                self:_setImageTextureAndSize(self.windowTex, self.__window_switch)
            end
            self:_YourDashPositionWindowState("neutral")
        end
    end

    -- =========================
    -- Warning lights update (with startup bulb-check)
    -- =========================
    do
        local v = self.vehicle
        if v then
            local hasPower      = self:_hasBatteryPower()
            local engineRunning = v:isEngineRunning()
            local keysInIgnition = v:isKeysInIgnition()
            local hotwired       = v:isHotwired()
            local keyOrHotwired  = keysInIgnition or hotwired

            -- Gear label only when dash is "on": battery power + key inserted OR hotwired
            if self.btn_partSpeed then
                local showGear = hasPower and
                    (keysInIgnition or (hotwired and engineRunning))
                self.btn_partSpeed:setVisible(showGear)
                if not showGear then
                    -- extra insurance: even if something forces visible, there's nothing to draw
                    self.btn_partSpeed.name = ""
                end
            end

            -- The starter phase was advanced once before voltage sampling so
            -- warning bulbs and the voltage needle consume the same envelope.
            local cranking = self.__YourDashCranking == true
            local dimTarget = self.__YourDashCrankDimTarget or 1.0
            self.__elecDimAlpha = self.__elecDimAlpha or 1.0

            -- Faster when dropping, slower when recovering (more “realistic” starter dip)
            local smoothTime = (dimTarget < (self.__elecDimAlpha or 1.0)) and (self.CRANK_DIM_TIME_DOWN or self.CRANK_DIM_TIME)
                                                                or (self.CRANK_DIM_TIME_UP   or self.CRANK_DIM_TIME)

            self.__elecDimAlpha = self._ease(self.__elecDimAlpha, dimTarget, smoothTime, dt)

            -- Fuel arrows: day stays static; ONLY lid overlay is affected by sag + crash
            do
                local lidActive = (self.__lidMode == true)
                local glow = (self.__elecDimAlpha or 1.0) * (self.__impactDimAlpha or 1.0)

                -- Ensure day arrows stay static (in case anything tints them)
                local function forceStatic(img)
                    if not img then return end
                    img.backgroundColor = img.backgroundColor or { r=1, g=1, b=1, a=1 }
                    img.backgroundColor.r, img.backgroundColor.g, img.backgroundColor.b, img.backgroundColor.a = 1, 1, 1, 1
                end
                forceStatic(self.leftSideFuel)
                forceStatic(self.rightSideFuel)

                local function updateOverlay(baseImg, overlayImg)
                    if not overlayImg then return end
                    local show = lidActive and baseImg and baseImg:isVisible()
                    overlayImg:setVisible(show)
                    overlayImg.backgroundColor = overlayImg.backgroundColor or { r=1, g=1, b=1, a=0 }
                    overlayImg.backgroundColor.r, overlayImg.backgroundColor.g, overlayImg.backgroundColor.b = 1, 1, 1
                    overlayImg.backgroundColor.a = show and glow or 0
                end

                updateOverlay(self.leftSideFuel,  self.leftSideFuelLid)
                updateOverlay(self.rightSideFuel, self.rightSideFuelLid)
            end

            -- Init bulb-check state
            self.__warnChkState        = self.__warnChkState or 0   -- 0=idle, 1=cranking(all on), 2=post-start(stagger off)
            self.__warnChkT            = self.__warnChkT or 0
            self.__warnChkPrevCranking = self.__warnChkPrevCranking or false
            self.__warnChkRelease      = self.__warnChkRelease or nil

            -- No power -> no warning lights + abort any procedure
            if not hasPower then
                self.__warnChkState = 0
                self.__warnChkT = 0
                self.__warnChkRelease = nil
                self.__warnChkPrevCranking = false
                self.__warnStopT = 0

                self:_setWarn(self.warnCruiseTex,  false)
                self:_setWarn(self.warnBatteryTex, false)
                self:_setWarn(self.warnBrakeTex,   false)
                self:_setWarn(self.warnCheckTex,   false)
                self:_setWarn(self.warnStopTex,    false)
                self:_setWarn(self.warnDoorTex,    false)
                self:_setWarn(self.warnFuelTex,    false)
                self:_setWarn(self.warnLightTex,   false)
            else
                -- Start bulb-check exactly when cranking begins
                if cranking and (not self.__warnChkPrevCranking) then
                    self.__warnChkState = 1
                    self.__warnChkT = 0
                    self.__warnChkRelease = nil
                end
                self.__warnChkPrevCranking = cranking

                -- Advance/exit procedure
                if self.__warnChkState == 1 then
                    -- If engine started successfully -> go to post-start stagger
                    if engineRunning then
                        self.__warnChkState = 2
                        self.__warnChkT = 0

                        -- Preserve the stagger order while scaling how long
                        -- incandescent bulb-check glow persists per cluster.
                        local warningResponse = self:_YourDashWarningResponse()
                        local persistence = warningResponse.bulbPersistence or 1.0
                        local function release(seconds) return seconds * persistence end
                        self.__warnChkRelease = {
                            light   = release(0.5),  -- headlights indicator
                            door    = release(0.5),  -- door indicator

                            brake   = release(0.5),
                            stop    = release(1.25),
                            check   = release(1.5),
                            battery = release(1.5),
                            cruise  = release(0.5),

                            fuel    = release(0.5),
                        }
                    elseif not cranking then
                        -- Cranking ended but engine didn't start -> abort immediately
                        self.__warnChkState = 0
                        self.__warnChkT = 0
                        self.__warnChkRelease = nil
                    end
                elseif self.__warnChkState == 2 then
                    -- If engine is turned off during the procedure -> abort immediately
                    if not engineRunning then
                        self.__warnChkState = 0
                        self.__warnChkT = 0
                        self.__warnChkRelease = nil
                    else
                        self.__warnChkT = self.__warnChkT + (dt or 1/30)
                    end
                end

                local function inBulbCheck(name)
                    if self.__warnChkState == 1 then
                        return true -- all steady on during crank
                    end
                    if self.__warnChkState == 2 and self.__warnChkRelease then
                        local rel = self.__warnChkRelease[name]
                        return rel and (self.__warnChkT < rel)
                    end
                    return false
                end

                -- ===== Normal (non-check) conditions (your rules) =====
                local charge  = v:getBatteryCharge() or 0
                local engCond = self:_getEngineCondition()

                local doorOnRaw  = self:_anyDoorOpenOrMissing()
                local lightOnRaw = v:getHeadlightsOn()

                local fuelPct = v:getRemainingFuelPercentage() or 0
                if fuelPct > 1.0 then fuelPct = fuelPct / 100.0 end
                local fuelLowRaw = (fuelPct >= 0) and (fuelPct < 0.10)

                -- need engine running
                local cruiseOn = engineRunning and v:isRegulator()
                local checkOn      = engineRunning and (engCond < 70)

                -- STOP: steady <40, flashing <20
                local stopSteadyOn = engineRunning and (engCond < 40)
                local stopFlashOn  = engineRunning and (engCond < 20)
                local stopOn       = stopSteadyOn

                local fuelOn   = engineRunning and fuelLowRaw

                -- need key or hotwire
                local batteryOn
                if keysInIgnition then
                    -- original behavior for keyed cars
                    batteryOn = ((not engineRunning) or (charge < 0.40))
                elseif hotwired then
                    -- hotwired cars: no battery light unless the engine is running
                    batteryOn = engineRunning and (charge < 0.40)
                else
                    batteryOn = false
                end
                local brakeOn   = keyOrHotwired and isKeyDown(Keyboard.KEY_SPACE)

                -- just needs power
                local doorOn  = doorOnRaw
                local lightOn = lightOnRaw

                -- show cruise speed in hover text
                local setSpeed = v:getRegulatorSpeed() or 0
                if setSpeed < 0 then setSpeed = 0 end
                local mph = math.floor(setSpeed + 0.5)

                local cruiseTip = "Cruise control: " .. tostring(mph) .. " mph"

                local stopAlpha = 1.0
                if stopFlashOn and (not inBulbCheck("stop")) then
                    self.__warnStopT = (self.__warnStopT or 0) + (dt or 1/30)

                    local phase = math.floor(self.__warnStopT * (self.WARN_STOP_BLINK_HZ or 0.7) * 2) % 2
                    local target = (phase == 0) and 1.0 or (self.WARN_STOP_BLINK_DIM or 0)

                    self.__warnStopBlink = self.__warnStopBlink or target
                    local warningResponse = self:_YourDashWarningResponse()
                    local fadeTime = (target > self.__warnStopBlink) and warningResponse.fadeIn
                                                            or warningResponse.fadeOut
                    self.__warnStopBlink = self._ease(self.__warnStopBlink, target, fadeTime, (dt or 1/30))

                    stopAlpha = self.__warnStopBlink
                else
                    self.__warnStopT = 0
                    self.__warnStopBlink = nil
                end



                local function apply(name, img, normalOn, tip, normalAlpha)
                    if inBulbCheck(name) then
                        self:_setWarn(img, true, tip, 1.0)  -- steady on during check
                    else
                        self:_setWarn(img, normalOn, tip, normalAlpha)
                    end
                end

                local function batteryFlickerSub()
                    if not self.__crankBattFlickerActive then return 0 end
                    local t = self.__crankBattFlickerT or 0
                    local hz = self.CRANK_BATT_FLICKER_HZ or 9.0
                    local depth = self.CRANK_BATT_FLICKER_DEPTH or 0.30

                    local u   = (t * hz) % 1.0
                    local tri = 1 - math.abs(2*u - 1)   -- 0..1..0
                    return depth * tri                  -- 0..depth
                end

                local function applyBattery(img, normalOn, tip)
                    -- during bulb-check it’s “on”, but we STILL want the flicker if active
                    local on = normalOn or inBulbCheck("battery")

                    self:_setWarn(img, on, tip, 1.0, dt)

                    if on and img and img.backgroundColor and img:isVisible() then
                        local sub = batteryFlickerSub()
                        if sub > 0 then
                            local a = (img.backgroundColor.a or 0) - sub
                            if a < 0 then a = 0 end
                            img.backgroundColor.a = a
                            if a <= 0.01 then img:setVisible(false) end
                        end
                    end
                end

                apply("cruise", self.warnCruiseTex, cruiseOn, cruiseTip)
                applyBattery(self.warnBatteryTex, batteryOn, "Battery warning")
                apply("brake",   self.warnBrakeTex,   brakeOn,   "Parking brake on")
                apply("check",   self.warnCheckTex,   checkOn,   "Check engine")
                apply("stop",    self.warnStopTex,    stopOn,    "Engine condition critical!", stopAlpha)
                apply("door",    self.warnDoorTex,    doorOn,    "Door open")
                apply("fuel",    self.warnFuelTex,    fuelOn,    "Low fuel")
                apply("light",   self.warnLightTex,   lightOn,   "Headlights on")
            end
        end
    end

    -- keep vanilla engine/battery hidden even though oldPrerender may touch them
    if self.engineTex then self.engineTex:setVisible(false) end
    if self.batteryTex then self.batteryTex:setVisible(false) end
    self:_YourDashUpdateSideButtons()
    self:_YourDashPositionSideButtons()

end

-- =========================
-- Patch: render()
-- =========================
local _oldRender = ISVehicleDashboard.render
function ISVehicleDashboard:render()
end

-- =========================
-- Patch: onResolutionChange()
-- =========================
local _oldOnRes = ISVehicleDashboard.onResolutionChange
function ISVehicleDashboard:onResolutionChange()
    _oldOnRes(self)
    if not self.backgroundTex then return end

    local layout = YourDash.GetLayout and YourDash.GetLayout(self) or nil
    local controls = layout and layout.controls or {}
    local warnings = layout and layout.warnings or {}
    local scale = YourDash.GetScale and YourDash.GetScale() or 1
    local useLarge = scale >= 1.4
    self:_YourDashApplyGearFont(useLarge)
    local function pos(sectionName, section, name, fallbackX, fallbackY)
        if YourDash.GetLayoutPoint then
            local x, y = YourDash.GetLayoutPoint(self, sectionName, name)
            if x ~= nil and y ~= nil then return x, y end
        end
        local p = section and section[name] or nil
        local x = p and (p.x or p[1]) or fallbackX
        local y = p and (p.y or p[2]) or fallbackY
        return math.floor((x or 0) * scale + 0.5), math.floor((y or 0) * scale + 0.5)
    end

    local SPEEDREG_X, SPEEDREG_Y = pos("controls", controls, "speedreg", self.CTRL_SPEEDREG_X, self.CTRL_SPEEDREG_Y)
    local GEAR_X, GEAR_Y = pos("controls", controls, "gear", self.CTRL_GEAR_X, self.CTRL_GEAR_Y)
    local ENGINE_X, ENGINE_Y = pos("controls", controls, "engine", self.CTRL_ENGINE_X, self.CTRL_ENGINE_Y)
    local BATTERY_X, BATTERY_Y = pos("controls", controls, "battery", self.CTRL_BATTERY_X, self.CTRL_BATTERY_Y)
    local LIGHTS_X, LIGHTS_Y = pos("controls", controls, "lights", self.CTRL_LIGHTS_X, self.CTRL_LIGHTS_Y)
    local IGNITION_X, IGNITION_Y = pos("controls", controls, "ignition", self.CTRL_IGNITION_X, self.CTRL_IGNITION_Y)
    local FUEL_X, FUEL_Y = pos("controls", controls, "fuelArrow", self.CTRL_FUEL_ARROW_X, self.CTRL_FUEL_ARROW_Y)
    local FUEL_L_X, FUEL_L_Y = pos("controls", controls, "fuelArrowLeft", FUEL_X / scale, FUEL_Y / scale)
    local FUEL_R_X, FUEL_R_Y = pos("controls", controls, "fuelArrowRight", FUEL_X / scale, FUEL_Y / scale)
    local DOOR_X, DOOR_Y = pos("controls", controls, "door", self.CTRL_DOOR_X, self.CTRL_DOOR_Y)
    local TRUNK_X, TRUNK_Y = pos("controls", controls, "trunk", self.CTRL_TRUNK_X, self.CTRL_TRUNK_Y)
    local DOOR_LED_X, DOOR_LED_Y = pos("controls", controls, "doorLED", DOOR_X / scale, DOOR_Y / scale)
    local TRUNK_LED_X, TRUNK_LED_Y = pos("controls", controls, "trunkLED", TRUNK_X / scale, TRUNK_Y / scale)
    local WINDOW_X, WINDOW_Y = pos("controls", controls, "window", self.CTRL_WINDOW_X, self.CTRL_WINDOW_Y)

    local WCX, WCY = pos("warnings", warnings, "cruise", self.WARN_CRUISE_X, self.WARN_CRUISE_Y)
    local WBX, WBY = pos("warnings", warnings, "battery", self.WARN_BATTERY_X, self.WARN_BATTERY_Y)
    local WRX, WRY = pos("warnings", warnings, "brake", self.WARN_BRAKE_X, self.WARN_BRAKE_Y)
    local WKX, WKY = pos("warnings", warnings, "check", self.WARN_CHECK_X, self.WARN_CHECK_Y)
    local WSX, WSY = pos("warnings", warnings, "stop", self.WARN_STOP_X, self.WARN_STOP_Y)
    local WDX, WDY = pos("warnings", warnings, "door", self.WARN_DOOR_X, self.WARN_DOOR_Y)
    local WFX, WFY = pos("warnings", warnings, "fuel", self.WARN_FUEL_X, self.WARN_FUEL_Y)
    local WLX, WLY = pos("warnings", warnings, "light", self.WARN_LIGHT_X, self.WARN_LIGHT_Y)

    if self.__YourDashFamily == "sport" then
        local scaleKey = YourDash.GetScaleKey and YourDash.GetScaleKey() or "1x"
        local inset = SPORT_WARNING_GLOW_INSET[scaleKey] or SPORT_WARNING_GLOW_INSET["1x"]
        WCX, WCY = WCX - inset, WCY - inset
        WBX, WBY = WBX - inset, WBY - inset
        WRX, WRY = WRX - inset, WRY - inset
        WKX, WKY = WKX - inset, WKY - inset
        WSX, WSY = WSX - inset, WSY - inset
        WDX, WDY = WDX - inset, WDY - inset
        WFX, WFY = WFX - inset, WFY - inset
        WLX, WLY = WLX - inset, WLY - inset
    end


    if self.speedregulatorTex then
        self.speedregulatorTex:setX(self.backgroundTex:getX() + SPEEDREG_X)
        self.speedregulatorTex:setY(self.backgroundTex:getY() + SPEEDREG_Y)
    end
    if self.btn_partSpeed then
        self.btn_partSpeed:setX(self.backgroundTex:getX() + GEAR_X)
        self.btn_partSpeed:setY(self.backgroundTex:getY() + GEAR_Y)
    end
    if self.engineTex then
        self.engineTex:setX(self.backgroundTex:getX() + ENGINE_X)
        self.engineTex:setY(self.backgroundTex:getY() + ENGINE_Y)
    end
    if self.batteryTex then
        self.batteryTex:setX(self.backgroundTex:getX() + BATTERY_X)
        self.batteryTex:setY(self.backgroundTex:getY() + BATTERY_Y)
    end
    if self.lightsTex then
        self:_YourDashPositionLightsControl(LIGHTS_X, LIGHTS_Y)
    end
    if self.ignitionTex then
        self.ignitionTex:setX(self.backgroundTex:getX() + IGNITION_X)
        self.ignitionTex:setY(self.backgroundTex:getY() + IGNITION_Y)
        self:_YourDashScaleIgnition()
    end

    if self.leftSideFuel then
        self.leftSideFuel:setX(self.backgroundTex:getX() + FUEL_L_X)
        self.leftSideFuel:setY(self.backgroundTex:getY() + FUEL_L_Y)
    end
    if self.rightSideFuel then
        self.rightSideFuel:setX(self.backgroundTex:getX() + FUEL_R_X)
        self.rightSideFuel:setY(self.backgroundTex:getY() + FUEL_R_Y)
    end
    if self.leftSideFuelLid then
        self.leftSideFuelLid:setX(self.backgroundTex:getX() + FUEL_L_X)
        self.leftSideFuelLid:setY(self.backgroundTex:getY() + FUEL_L_Y)
    end
    if self.rightSideFuelLid then
        self.rightSideFuelLid:setX(self.backgroundTex:getX() + FUEL_R_X)
        self.rightSideFuelLid:setY(self.backgroundTex:getY() + FUEL_R_Y)
    end

    if self.doorTex then
        self.doorTex:setX(self.backgroundTex:getX() + DOOR_X)
        self.doorTex:setY(self.backgroundTex:getY() + DOOR_Y)
    end
    if self.trunkTex then
        self:_YourDashPositionTrunkControl(self.vehicle and self:_YourDashHasTrunkLock() or nil)
    end
    if self.windowTex then
        self.windowTex:setX(self.backgroundTex:getX() + WINDOW_X)
        self.windowTex:setY(self.backgroundTex:getY() + WINDOW_Y)
    end
    if self.__YourDashDoorLED then
        self.__YourDashDoorLED:setX(self.backgroundTex:getX() + DOOR_LED_X)
        self.__YourDashDoorLED:setY(self.backgroundTex:getY() + DOOR_LED_Y)
    end
    if self.__YourDashTrunkLED then
        self.__YourDashTrunkLED:setX(self.backgroundTex:getX() + TRUNK_LED_X)
        self.__YourDashTrunkLED:setY(self.backgroundTex:getY() + TRUNK_LED_Y)
    end


    -- Warning lights positions
    if self.backgroundTex then
        local bx = self.backgroundTex:getX()
        local by = self.backgroundTex:getY()

        if self.warnCruiseTex then
            self.warnCruiseTex:setX(bx + WCX)
            self.warnCruiseTex:setY(by + WCY)
        end
        if self.warnBatteryTex then
            self.warnBatteryTex:setX(bx + WBX)
            self.warnBatteryTex:setY(by + WBY)
        end
        if self.warnBrakeTex then
            self.warnBrakeTex:setX(bx + WRX)
            self.warnBrakeTex:setY(by + WRY)
        end
        if self.warnCheckTex then
            self.warnCheckTex:setX(bx + WKX)
            self.warnCheckTex:setY(by + WKY)
        end
        if self.warnStopTex then
            self.warnStopTex:setX(bx + WSX)
            self.warnStopTex:setY(by + WSY)
        end
        if self.warnDoorTex then
            self.warnDoorTex:setX(bx + WDX)
            self.warnDoorTex:setY(by + WDY)
        end
        if self.warnFuelTex then
            self.warnFuelTex:setX(bx + WFX)
            self.warnFuelTex:setY(by + WFY)
        end
        if self.warnLightTex then
            self.warnLightTex:setX(bx + WLX)
            self.warnLightTex:setY(by + WLY)
        end


        if self.__YourDashNeedleLayer and self.backgroundTex then
            self.__YourDashNeedleLayer:setX(self.backgroundTex:getX())
            self.__YourDashNeedleLayer:setY(self.backgroundTex:getY())
            self.__YourDashNeedleLayer:setWidth(self.backgroundTex:getWidth())
            self.__YourDashNeedleLayer:setHeight(self.backgroundTex:getHeight())
        end
        if self._YourDashPositionGlassOverlay then self:_YourDashPositionGlassOverlay() end
        if self._YourDashFinalizeWearOrder then self:_YourDashFinalizeWearOrder() end
    end
    self:_YourDashPositionSideButtons()

end
