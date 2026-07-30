-- media/lua/client/YourDash/Z_PatchVehicleDashboard.lua
if isServer() then return end

-- Load vanilla
require "Vehicles/ISUI/ISVehicleDashboard"
require "Vehicles/ISUI/ISVehiclePartMenu"
require "ISUI/ISPanel"


-- Guard: don’t patch twice
if ISVehicleDashboard.__YourDashPatched then return end
ISVehicleDashboard.__YourDashPatched = true

-- =========================
-- Warning light offsets (relative to backgroundTex)
-- =========================
ISVehicleDashboard.WARN_CRUISE_X = ISVehicleDashboard.WARN_CRUISE_X or 411
ISVehicleDashboard.WARN_CRUISE_Y = ISVehicleDashboard.WARN_CRUISE_Y or 128

ISVehicleDashboard.WARN_BATTERY_X = ISVehicleDashboard.WARN_BATTERY_X or 321
ISVehicleDashboard.WARN_BATTERY_Y = ISVehicleDashboard.WARN_BATTERY_Y or 123

ISVehicleDashboard.WARN_BRAKE_X = ISVehicleDashboard.WARN_BRAKE_X or 318
ISVehicleDashboard.WARN_BRAKE_Y = ISVehicleDashboard.WARN_BRAKE_Y or 97

ISVehicleDashboard.WARN_CHECK_X = ISVehicleDashboard.WARN_CHECK_X or 225
ISVehicleDashboard.WARN_CHECK_Y = ISVehicleDashboard.WARN_CHECK_Y or 127

ISVehicleDashboard.WARN_STOP_X = ISVehicleDashboard.WARN_STOP_X or 254
ISVehicleDashboard.WARN_STOP_Y = ISVehicleDashboard.WARN_STOP_Y or 139

ISVehicleDashboard.WARN_DOOR_X = ISVehicleDashboard.WARN_DOOR_X or 349
ISVehicleDashboard.WARN_DOOR_Y = ISVehicleDashboard.WARN_DOOR_Y or 122

ISVehicleDashboard.WARN_FUEL_X = ISVehicleDashboard.WARN_FUEL_X or 349
ISVehicleDashboard.WARN_FUEL_Y = ISVehicleDashboard.WARN_FUEL_Y or 98

ISVehicleDashboard.WARN_LIGHT_X = ISVehicleDashboard.WARN_LIGHT_X or 281
ISVehicleDashboard.WARN_LIGHT_Y = ISVehicleDashboard.WARN_LIGHT_Y or 27

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

    img.onclick = nil
    img.target = nil
    img.mouseovertext = nil

    img.__fade = 0
    img.backgroundColor = { r=1, g=1, b=1, a=0 } -- start invisible, we’ll fade it

    img:setVisible(false)
    img.__YourDashWarn = true
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
    local fadeTime   = on and self.WARN_FADE_IN_TIME or self.WARN_FADE_OUT_TIME
    img.__fade = self._ease(img.__fade, targetFade, fadeTime, dt)

    -- global voltage sag dimmer (set in prerender)
    local dim = (self.__elecDimAlpha or 1.0) * (self.__impactDimAlpha or 1.0)

    -- extra alpha multiplier (blink etc)
    local mul = alphaMul or 1.0

    local a = dim * mul * img.__fade

    if a <= 0.01 then
        img:setVisible(false)
    else
        img:setVisible(true)
        if not img.backgroundColor then img.backgroundColor = { r=1, g=1, b=1, a=a } end
        img.backgroundColor.r = 1
        img.backgroundColor.g = 1
        img.backgroundColor.b = 1
        img.backgroundColor.a = a
    end

    -- Tooltip only when logically ON (not during fade-out)
    img.mouseovertext = on and tooltip or nil
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

-- Crank dim depends on battery charge (0..1)
ISVehicleDashboard.CRANK_DIM_ALPHA_MIN = ISVehicleDashboard.CRANK_DIM_ALPHA_MIN or 0.20 -- very low charge
ISVehicleDashboard.CRANK_DIM_ALPHA_MAX = ISVehicleDashboard.CRANK_DIM_ALPHA_MAX or 0.80 -- full charge
ISVehicleDashboard.CRANK_DIM_GAMMA     = ISVehicleDashboard.CRANK_DIM_GAMMA     or 2.0  -- curve; <1 = less harsh at mid charge
ISVehicleDashboard.CRANK_DIM_DELAY = ISVehicleDashboard.CRANK_DIM_DELAY or 0.50 -- seconds after cranking starts

-- Starter “kick” dip (big initial voltage drop, then recover to base crank alpha)
ISVehicleDashboard.CRANK_KICK_AMOUNT  = ISVehicleDashboard.CRANK_KICK_AMOUNT  or 0.19 -- subtract from base alpha at the very start
ISVehicleDashboard.CRANK_KICK_HOLD    = ISVehicleDashboard.CRANK_KICK_HOLD    or 0.5 -- seconds to hold the big dip
ISVehicleDashboard.CRANK_KICK_RECOVER = ISVehicleDashboard.CRANK_KICK_RECOVER or 0.18 -- seconds to ramp back to base
ISVehicleDashboard.CRANK_DIM_TIME_DOWN = ISVehicleDashboard.CRANK_DIM_TIME_DOWN or 0.03
ISVehicleDashboard.CRANK_DIM_TIME_UP   = ISVehicleDashboard.CRANK_DIM_TIME_UP   or 0.12

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

function ISVehicleDashboard:onClickWindow()
    if getGameSpeed() == 0 then return end
    if getGameSpeed() > 1 then setGameSpeed(1) end
    if not self.vehicle then return end

    local windowPart = self:_getSeatWindowPart()
    if not windowPart then return end

    local w = windowPart:getWindow()
    local shouldOpen = not w:isOpen() -- if open now -> close; else open
    ISVehiclePartMenu.onOpenCloseWindow(self.character, windowPart, shouldOpen)
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

-- =========================
-- Stain layer (below dash.png)
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

    local path = string.format("media/ui/vehicles/stain/level_%d_%d.png", level, variant)
    local tex = getTexture(path)
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

        local var, tex = self:_pickStainVariant(level)
        self.__stainVariant = var
        self.__stainTex = tex
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

-- load crack texture for a level (supports BOTH naming schemes)
-- preferred: cracks/level_1.png .. level_4.png
-- fallback:  cracks/level_1_1.png .. level_4_1.png (if you kept old pattern)
function ISVehicleDashboard:_getCrackTex(level)
    self.__YourDashCrackCache = self.__YourDashCrackCache or {}
    local cached = self.__YourDashCrackCache[level]
    if cached ~= nil then
        return cached or nil
    end

    local tex = getTexture(string.format("media/ui/vehicles/cracks/level_%d.png", level))
    if not tex then
        tex = getTexture(string.format("media/ui/vehicles/cracks/level_%d_1.png", level))
    end

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

-- Mark warn lights so we don't accidentally move them above glass
-- Add this line inside _newWarnImage after instantiate():
-- img.__YourDashWarn = true

function ISVehicleDashboard:_YourDashMoveChildToTop(child)
    if not child then return end
    if child == self.backgroundTex then return end
    if child == self.__YourDashGlassOverlay then return end
    if child.__YourDashWarn then return end

    if child.bringToTop then
        child:bringToTop()
        return
    end
    if self.removeChild and self.addChild then
        self:removeChild(child)
        self:addChild(child)
    end
end

function ISVehicleDashboard:_YourDashBringControlsAboveGlass()
    -- known vanilla/custom controls
    self:_YourDashMoveChildToTop(self.doorTex)
    self:_YourDashMoveChildToTop(self.trunkTex)
    self:_YourDashMoveChildToTop(self.lightsTex)
    self:_YourDashMoveChildToTop(self.windowTex)
    self:_YourDashMoveChildToTop(self.ignitionTex)

    -- AC
    self:_YourDashMoveChildToTop(self.heaterTex)
    self:_YourDashMoveChildToTop(self.acTempSlider)

    -- Also bring any other clickable child (radio buttons, etc.)
    if self.children then
        for i = 1, #self.children do
            local c = self.children[i]
            if c and c.onclick and (not c.__YourDashWarn) and c ~= self.backgroundTex and c ~= self.__YourDashGlassOverlay then
                self:_YourDashMoveChildToTop(c)
            end
        end
    end
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

    -- Don’t consume mouse
    o.onclick = nil
    function o:onMouseDown() return false end
    function o:onMouseUp() return false end
    function o:onMouseMove(dx,dy) end
    function o:onMouseMoveOutside(dx,dy) end
    function o:onMouseUpOutside(x,y) return false end
    if o.setConsumeMouseEvents then o:setConsumeMouseEvents(false) end

    function o:render()
        local dash = self.target or self.parent
        if not dash then return end
        local w, h = self.width, self.height
        if w <= 0 or h <= 0 then return end

        -- ORDER: cracks below stain below dash overlay
        if dash.__crackTex then self:drawTextureScaled(dash.__crackTex, 0, 0, w, h, 1) end
        if dash.__stainTex then self:drawTextureScaled(dash.__stainTex, 0, 0, w, h, 1) end
        if dash.__dashTex  then self:drawTextureScaled(dash.__dashTex,  0, 0, w, h, 1) end
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


-- =========================
-- Patch: new()
-- =========================
local _oldNew = ISVehicleDashboard.new
function ISVehicleDashboard:new(playerNum, chr)
    local o = _oldNew(self, playerNum, chr)

    local function tex(p1, p2)
        local t = getTexture(p1)
        if (not t) and p2 then t = getTexture(p2) end
        return t
    end

    -- Gauge (always) + gauge_lid (only in lid mode) + dash overlay (always on top of gauge)
    o.__bg_day = tex("media/ui/vehicles/gauge.png") or o.dashboardBG
    o.__bg_lid = tex("media/ui/vehicles/gauge_lid.png") or o.__bg_day

    -- New: dash layer (drawn above gauge(+lid), below buttons)
    o.__dashTex = tex("media/ui/vehicles/dash.png")

    if o.__bg_day then
        o.dashboardBG = o.__bg_day
        o:setWidth(o.dashboardBG:getWidth())
        o:setHeight(o.dashboardBG:getHeight())
    end

    o.__stainTex = nil
    o.__stainLevel = nil
    o.__stainVariant = nil
    o.__stainSeatCond = nil
    o.__YourDashStainCache = o.__YourDashStainCache or {}

    o.__crackTex = nil
    o.__crackLevel = nil
    o.__windshieldCond = nil
    o.__YourDashCrackCache = o.__YourDashCrackCache or {}



    -- Warning light textures
    o.__warn_cruise  = getTexture("media/ui/vehicles/warning_cruise.png")
    o.__warn_battery = getTexture("media/ui/vehicles/warning_battery.png")
    o.__warn_brake   = getTexture("media/ui/vehicles/warning_brake.png")
    o.__warn_check   = getTexture("media/ui/vehicles/warning_check.png")
    o.__warn_stop    = getTexture("media/ui/vehicles/warning_stop.png")
    o.__warn_door    = getTexture("media/ui/vehicles/warning_door.png")
    o.__warn_fuel    = getTexture("media/ui/vehicles/warning_fuel.png")
    o.__warn_light   = getTexture("media/ui/vehicles/warning_light.png")

    -- Needles (day + lid)
    o.__needleLong_day  = tex("media/ui/vehicles/needle_long.png")
    o.__needleLong_lid  = tex("media/ui/vehicles/needle_long_lid.png") or o.__needleLong_day
    o.__needleShort_day = tex("media/ui/vehicles/needle_short.png")
    o.__needleShort_lid = tex("media/ui/vehicles/needle_short_lid.png") or o.__needleShort_day
    o.needleCenter = tex("media/ui/vehicles/needle_center.png")

    -- Fuel arrows (day + lid)
    o.__fuelL_day = tex("media/ui/vehicles/fuelL.png")
    o.__fuelR_day = tex("media/ui/vehicles/fuelR.png")
    o.__fuelL_lid = tex("media/ui/vehicles/fuelL_lid.png") or o.__fuelL_day
    o.__fuelR_lid = tex("media/ui/vehicles/fuelR_lid.png") or o.__fuelR_day

    -- Initial (day)
    o.needleLong   = o.__needleLong_day
    o.needleShort  = o.__needleShort_day
    o.leftSideFuelTex  = o.__fuelL_day
    o.rightSideFuelTex = o.__fuelR_day

    -- Door lock textures
    o.__lock_off     = getTexture("media/ui/vehicles/lock_off.png")
    o.__lock_partial = getTexture("media/ui/vehicles/lock_partial.png") or o.__lock_off
    o.__lock_on      = getTexture("media/ui/vehicles/lock_on.png")      or o.__lock_off
    if o.__lock_off then
        o.iconDoor = o.__lock_off
    end

    -- Trunk textures + blank
    o.__trunk_off = getTexture("media/ui/vehicles/trunk_off.png")
    o.__trunk_on  = getTexture("media/ui/vehicles/trunk_on.png") or o.__trunk_off
    o.__blank_btn = getTexture("media/ui/vehicles/blank_btn.png")
    if o.__trunk_off then
        o.iconTrunk = o.__trunk_off
    end

    -- Light knob
    o.__light_knob = getTexture("media/ui/vehicles/light_knob.png")
    if o.__light_knob then
        o.iconLights = o.__light_knob
    end

    -- Window switch
    o.__window_switch      = getTexture("media/ui/vehicles/window_switch.png")
    o.__window_switch_push = getTexture("media/ui/vehicles/window_switch_push.png") or o.__window_switch
    o.__window_switch_pull = getTexture("media/ui/vehicles/window_switch_pull.png") or o.__window_switch

    -- Offsets
    o.dashOffset  = { x = 0,    y = 0}
    o.rpmOffset   = { x = 235, y = 111}
    o.speedOffset = { x = 452, y = 111}
    o.fuelOffset  = { x = 343, y = 59}

    o.__lidMode = false
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
    end

    -- Fuel arrow lid overlays (drawn on top of day arrows, only when lid mode is on)
    local function _makeOverlay(tex)
        if not tex then return nil end
        local img = ISImage:new(0, 0, tex:getWidthOrig(), tex:getHeightOrig(), tex)
        img:initialise()
        img:instantiate()
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
        if p.setConsumeMouseEvents then p:setConsumeMouseEvents(false) end

        function p:render()
            local dash = self.target
            if not dash or not dash.vehicle then return end

            -- values already updated in dash:prerender()
            local rpmVal   = math.max(0, math.min(1, dash.rpmValue  or 0.0))
            local speedVal = math.max(0, math.min(1, dash.speedValue or 0.0))
            local fuelVal  = math.max(0, math.min(1, dash.fuelValue  or 0.0))

            local rpmAngle  = math.deg(dash.RPM_MIN_ANGLE + (dash.RPM_MAX_ANGLE - dash.RPM_MIN_ANGLE) * rpmVal)
            local fuelAngle = math.deg(dash.FUEL_MIN_ANGLE + (dash.FUEL_MAX_ANGLE - dash.FUEL_MIN_ANGLE) * fuelVal)

            local mph = speedVal * 120.0
            if mph < 0 then mph = 0 elseif mph > 120 then mph = 120 end

            local speedAngle
            if mph <= 20.0 then
                speedAngle = mph * 1.125
            else
                speedAngle = 22.5 + (mph - 20.0) * 1.875
            end
            if speedAngle < 0 then speedAngle = 0 elseif speedAngle > 210 then speedAngle = 210 end

            local baseX = (dash.dashOffset and dash.dashOffset.x) or 0
            local baseY = (dash.dashOffset and dash.dashOffset.y) or 0

            local longDay  = dash.__needleLong_day
            local longLid  = dash.__needleLong_lid
            local shortDay = dash.__needleShort_day
            local shortLid = dash.__needleShort_lid

            local hasLongLid  = longLid  and longDay  and (longLid  ~= longDay)
            local hasShortLid = shortLid and shortDay and (shortLid ~= shortDay)

            -- 1) DAY needles (static)
            if longDay then
                if dash.rpmOffset then
                    self:DrawTextureAngle(longDay, baseX + dash.rpmOffset.x,   baseY + dash.rpmOffset.y,   rpmAngle)
                end
                if dash.speedOffset then
                    self:DrawTextureAngle(longDay, baseX + dash.speedOffset.x, baseY + dash.speedOffset.y, speedAngle)
                end
            end
            if shortDay and dash.fuelOffset then
                self:DrawTextureAngle(shortDay, baseX + dash.fuelOffset.x, baseY + dash.fuelOffset.y, fuelAngle)
            end

            -- 2) LID needles (lit overlay, sag + crash)
            local lidActive = (dash.__lidMode == true)
            if lidActive then
                local lidAlpha = (dash.__lidOverlayAlpha ~= nil) and dash.__lidOverlayAlpha or 1.0
                local glow = (dash.__elecDimAlpha or 1.0) * (dash.__impactDimAlpha or 1.0) * lidAlpha

                if glow > 0.001 then
                    local oldA = 1.0
                    if self.getAlpha then oldA = self:getAlpha() elseif self.alpha then oldA = self.alpha end
                    if self.setAlpha then self:setAlpha(glow) else self.alpha = glow end

                    if hasLongLid then
                        if dash.rpmOffset then
                            self:DrawTextureAngle(longLid, baseX + dash.rpmOffset.x,   baseY + dash.rpmOffset.y,   rpmAngle)
                        end
                        if dash.speedOffset then
                            self:DrawTextureAngle(longLid, baseX + dash.speedOffset.x, baseY + dash.speedOffset.y, speedAngle)
                        end
                    end
                    if hasShortLid and dash.fuelOffset then
                        self:DrawTextureAngle(shortLid, baseX + dash.fuelOffset.x, baseY + dash.fuelOffset.y, fuelAngle)
                    end

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
        self:_installPressedEffect(self.doorTex, 0.96)
    end

    -- Trunk button
    if self.trunkTex and self.__trunk_off then
        self:_setImageTextureAndSize(self.trunkTex, self.__trunk_off)
        self:_setImageEnabled(self.trunkTex, true, nil, ISVehicleDashboard.onClickTrunk, self)
        self:_installPressedEffect(self.trunkTex, 0.96)
    end

    -- Lights knob (reuse lightsTex)
    if self.lightsTex and self.__light_knob then
        self:_setImageTextureAndSize(self.lightsTex, self.__light_knob)
        self:_setImageEnabled(self.lightsTex, true, getText("Tooltip_Dashboard_Headlights"), ISVehicleDashboard.onClickHeadlights, self)

    function self.lightsTex:render()
        if not self.texture then return end
        local dash = self.target or self.parent
        local ang = (dash and dash.__lightKnobAngle) or 0

        -- draw in THIS element's local coords (not parent coords)
        local cx = (self.width  or 0) * 0.5
        local cy = (self.height or 0) * 0.5

        -- Use the 8-arg overload explicitly (removes overload ambiguity)
        self:DrawTextureAngle(self.texture, cx, cy, ang, 1, 1, 1, (self.alpha or 1))
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

        self:_installPressedEffect(self.windowTex, 1)
        self:addChild(self.windowTex)
        self:_setImageTextureAndSize(self.windowTex, self.__window_switch)
        self.windowTex.__pressed = false

        local _down = self.windowTex.onMouseDown
        function self.windowTex:onMouseDown(x, y)
            if self.__disabled then return false end
            self.__pressed = true

            local dash = self.target
            local wp = dash and dash:_getSeatWindowPart() or nil
            if wp then
                local w = wp:getWindow()
                if w and w:isOpen() then
                    dash:_setImageTextureAndSize(self, dash.__window_switch_pull)
                else
                    dash:_setImageTextureAndSize(self, dash.__window_switch_push)
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

    -- Background stacking: day always, lid drawn on top (inside backgroundTex render)
    if self.backgroundTex and (not self.backgroundTex.__YourDashBgStacked) then
        self.backgroundTex.__YourDashBgStacked = true
        self.backgroundTex.target = self -- so render can read dash state/tex
        function self.backgroundTex:render()
        if not self.texture then return end
        local dash = self.target or self.parent
        local w, h = self.width, self.height
        local function drawScaled(ui, tex, x, y, w, h, a)
            if not tex then return end
            a = tonumber(a) or 1
            if ui.drawTextureScaled then
                -- works across versions
                ui:drawTextureScaled(tex, x, y, w, h, a)
            else
                -- B41: DrawTextureScaled(Texture,x,y,w,h,r,g,b,a)
                ui:DrawTextureScaled(tex, x, y, w, h, 1, 1, 1, a)
            end
        end


        -- base cluster
        drawScaled(self, self.texture, 0, 0, w, h, (self.alpha or 1))

        -- lid/backlight layer
        local lidTex = dash and dash.__bg_lid or nil
        local lidAlpha = 0
        if dash then
            lidAlpha = (dash.__lidOverlayAlpha ~= nil) and dash.__lidOverlayAlpha or (dash.__lidMode and 1.0 or 0.0)
        end
        lidAlpha = tonumber(lidAlpha) or 0

        if lidTex and lidAlpha > 0 then
            local elec   = (dash and dash.__elecDimAlpha) or 1.0
            local impact = (dash and dash.__impactDimAlpha) or 1.0
            drawScaled(self, lidTex, 0, 0, w, h, lidAlpha * elec * impact)
        end

        -- cracks / stain / dash overlay
        local crackTex = dash and dash.__crackTex or nil
        if crackTex then drawScaled(self, crackTex, 0, 0, w, h, (self.alpha or 1)) end

        local stainTex = dash and dash.__stainTex or nil
        if stainTex then drawScaled(self, stainTex, 0, 0, w, h, (self.alpha or 1)) end

        local dashTex = dash and dash.__dashTex or nil
        if dashTex then drawScaled(self, dashTex, 0, 0, w, h, (self.alpha or 1)) end
        end

    end

    self:_YourDashEnsureGlassOverlay()
    self:_YourDashPositionGlassOverlay()
    self:_YourDashBringControlsAboveGlass()

    self:onResolutionChange()
end

-- =========================
-- Patch: setVehicle()
-- =========================
local _oldSetVehicle = ISVehicleDashboard.setVehicle
function ISVehicleDashboard:setVehicle(vehicle)
    _oldSetVehicle(self, vehicle)

    if not vehicle then
        self.rpmValue, self.rpmVel = 0.0, 0.0
        self.speedValue, self.speedVel = 0.0, 0.0
        return
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
    _oldPrerender(self)

    local hasPower = self:_hasBatteryPower()
    local lidOn = self.vehicle:getHeadlightsOn() and hasPower

    self:_applyLidMode(lidOn)

    local engineSpeedValue = 0.0
    local speedValue = 0.0
    if self.vehicle:isEngineRunning() then
        engineSpeedValue = math.max(0, math.min(1, (self.vehicle:getEngineSpeed() - 0) / (7000 - 0)))
        speedValue       = math.max(0, math.min(1, math.abs(self.vehicle:getCurrentSpeedKmHour()) / 120))
    end

    local dt = UIManager.getSecondsSinceLastRender()
    if not dt or dt <= 0 then dt = 1/30 end

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

    self.rpmValue = (self.rpmValue == nil) and engineSpeedValue or self.rpmValue
    self.rpmVel   = self.rpmVel or 0.0
    local st = (engineSpeedValue > self.rpmValue) and self.NEEDLE_SMOOTHTIME_UP or self.NEEDLE_SMOOTHTIME_DOWN
    self.rpmValue, self.rpmVel = self._smoothDamp(self.rpmValue, engineSpeedValue, self.rpmVel, st, self.NEEDLE_MAXSPEED, dt)

    self.speedValue = (self.speedValue == nil) and speedValue or self.speedValue
    self.speedVel   = self.speedVel or 0.0
    local st2 = (speedValue > self.speedValue) and self.NEEDLE_SMOOTHTIME_UP or self.NEEDLE_SMOOTHTIME_DOWN
    self.speedValue, self.speedVel = self._smoothDamp(self.speedValue, speedValue, self.speedVel, st2, self.NEEDLE_MAXSPEED, dt)


    -- Door icon (don't swap when no power)
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
            -- Freeze to unpowered/unlid look
            self.doorTex.texture = self.__lock_off
        end
        self.doorTex.backgroundColor = { r=0, g=0, b=0, a=0 }
    end

    -- Trunk icon (don't swap when no power)
    if self.trunkTex and self.__blank_btn and self.vehicle then
        local hasTrunk = (self.vehicle:getPartById("TruckBed") ~= nil)
        self.trunkTex:setVisible(true)

        if not hasTrunk then
            self.trunkTex.texture = self.__blank_btn
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


    -- Lights knob angle + untint
    self.__lightKnobAngle = (self.vehicle and self.vehicle:getHeadlightsOn()) and 0 or -90
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

            local w = windowPart:getWindow()
            if w:isOpen() then
                self.windowTex.mouseovertext = getText("ContextMenu_Close_window")
            else
                self.windowTex.mouseovertext = getText("ContextMenu_Open_window")
            end
        end

        if (not self.windowTex.__pressed) and self.__window_switch then
            if self.windowTex.texture ~= self.__window_switch then
                self:_setImageTextureAndSize(self.windowTex, self.__window_switch)
            end
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
                local showGear = hasPower and (keysInIgnition or (hotwired and engineRunning))
                self.btn_partSpeed:setVisible(showGear)
                if not showGear then
                    -- extra insurance: even if something forces visible, there's nothing to draw
                    self.btn_partSpeed.name = ""
                end
            end

            -- Detect "cranking"
            local cranking = false
            if v.isStarting and v:isStarting() then
                cranking = true
            elseif v.isEngineStarted and v:isEngineStarted() and (not engineRunning) then
                -- fallback (some builds use this state name)
                cranking = true
            end

            -- Voltage sag dimmer during cranking (smooth + delayed start + starter kick dip)
            self.__elecDimAlpha = self.__elecDimAlpha or 1.0
            self.__crankDimDelayT = self.__crankDimDelayT or 0
            self.__crankDimPrev = self.__crankDimPrev or false

            if cranking then
                if not self.__crankDimPrev then
                    self.__crankDimDelayT = 0
                end
                self.__crankDimDelayT = self.__crankDimDelayT + dt
            else
                self.__crankDimDelayT = 0
            end
            self.__crankDimPrev = cranking

            -- “Sag active” starts after your delay (so the kick won’t expire during the delay)
            self.__crankSagPrev = self.__crankSagPrev or false
            local sagActive = cranking and (self.__crankDimDelayT >= self.CRANK_DIM_DELAY)

            -- Kick starts exactly when sag becomes active
            if sagActive and (not self.__crankSagPrev) then
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

            -- reset when cranking ends
            if not cranking then
                self.__crankBattFlickerActive = false
                self.__crankBattFlickerT = 0
            end

            if not cranking then
                self.__crankKickActive = false
                self.__crankKickT = 0
            end
            self.__crankSagPrev = sagActive

            local dimTarget = 1.0
            if sagActive then
                local baseAlpha = self:_getCrankDimAlphaFromCharge()

                -- Kick envelope: hold at (base - amount), then smooth ramp back to base
                local kick = 0.0
                if self.__crankKickActive then
                    self.__crankKickT = (self.__crankKickT or 0) + dt

                    local amt  = self.CRANK_KICK_AMOUNT  or 0.15
                    local hold = self.CRANK_KICK_HOLD    or 0.05
                    local rec  = self.CRANK_KICK_RECOVER or 0.18

                    if self.__crankKickT <= hold then
                        kick = amt
                    elseif rec > 0 and self.__crankKickT <= (hold + rec) then
                        local u = (self.__crankKickT - hold) / rec -- 0..1
                        if u < 0 then u = 0 elseif u > 1 then u = 1 end
                        -- smoothstep for a nicer ramp
                        local s = u*u*(3 - 2*u)
                        kick = amt * (1 - s)
                    else
                        self.__crankKickActive = false
                        kick = 0.0
                    end
                end

                dimTarget = baseAlpha - kick
                if dimTarget < 0 then dimTarget = 0 end
            end

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

                    local baseVisible = false
                    if baseImg then
                        if baseImg.isVisible then
                            baseVisible = (baseImg:isVisible() == true)
                        elseif baseImg.getIsVisible then
                            baseVisible = (baseImg:getIsVisible() == true)
                        else
                            baseVisible = true -- exists but no visible method; assume true
                        end
                    end

                    local show = (lidActive == true) and baseVisible  -- ALWAYS boolean

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

                        -- per your timing spec (staggered, not same time)
                        self.__warnChkRelease = {
                            light   = 0.5,  -- headlights indicator
                            door    = 0.5,  -- door indicator

                            brake   = 0.5,
                            stop    = 1.25,
                            check   = 1.5,
                            battery = 1.5,
                            cruise  = 0.5,

                            fuel    = 0.5,
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
                local checkOn  = engineRunning and (engCond < 70)
                local stopOn   = engineRunning and (engCond < 30)
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

                -- STOP blink multiplier with ramp (uses WARN_FADE_* times)
                local stopAlpha = 1.0
                if stopOn and (not inBulbCheck("stop")) then
                    self.__warnStopT = (self.__warnStopT or 0) + (dt or 1/30)

                    -- target brightness for this half-cycle
                    local phase = math.floor(self.__warnStopT * (self.WARN_STOP_BLINK_HZ or 0.7) * 2) % 2
                    local target = (phase == 0) and 1.0 or (self.WARN_STOP_BLINK_DIM or 0)

                    -- smooth the multiplier itself
                    self.__warnStopBlink = self.__warnStopBlink or target
                    local fadeTime = (target > self.__warnStopBlink) and (self.WARN_FADE_IN_TIME or 0.05)
                                                            or (self.WARN_FADE_OUT_TIME or 0.10)
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

    if self.speedregulatorTex then
        self.speedregulatorTex:setX(self.backgroundTex:getX() + 333)
        self.speedregulatorTex:setY(self.backgroundTex:getY() + 98)
    end
    if self.btn_partSpeed then
        self.btn_partSpeed:setX(self.backgroundTex:getX() + 200)
        self.btn_partSpeed:setY(self.backgroundTex:getY() + 122)
    end
    if self.engineTex then
        self.engineTex:setX(self.backgroundTex:getX() + 208)
        self.engineTex:setY(self.backgroundTex:getY() + 68)
    end
    if self.batteryTex then
        self.batteryTex:setX(self.engineTex:getX() + 26)
        self.batteryTex:setY(self.engineTex:getY())
    end

    if self.lightsTex then
        self.lightsTex:setX(self.backgroundTex:getX() + 93)
        self.lightsTex:setY(self.backgroundTex:getY() + 120)
    end

    if self.ignitionTex then
        self.ignitionTex:setX(self.backgroundTex:getX() + 564)
        self.ignitionTex:setY(self.backgroundTex:getY() + 128)
    end

    if self.leftSideFuel then
        self.leftSideFuel:setX(self.backgroundTex:getX() + 356)
        self.leftSideFuel:setY(self.backgroundTex:getY() + 54)
    end
    if self.rightSideFuel then
        self.rightSideFuel:setX(self.backgroundTex:getX() + 356)
        self.rightSideFuel:setY(self.backgroundTex:getY() + 54)
    end

    if self.leftSideFuelLid then
        self.leftSideFuelLid:setX(self.backgroundTex:getX() + 356)
        self.leftSideFuelLid:setY(self.backgroundTex:getY() + 54)
    end

    if self.rightSideFuelLid then
        self.rightSideFuelLid:setX(self.backgroundTex:getX() + 356)
        self.rightSideFuelLid:setY(self.backgroundTex:getY() + 54)
    end
    
    if self.doorTex then
        self.doorTex:setX(self.backgroundTex:getX() + 51)
        self.doorTex:setY(self.backgroundTex:getY() + 64)
    end
    if self.trunkTex then
        self.trunkTex:setX(self.backgroundTex:getX() + 98)
        self.trunkTex:setY(self.backgroundTex:getY() + 64)
    end
    if self.windowTex then
        self.windowTex:setX(self.backgroundTex:getX() + 32)
        self.windowTex:setY(self.backgroundTex:getY() + 112)
    end

    -- Warning lights positions
    if self.backgroundTex then
        local bx = self.backgroundTex:getX()
        local by = self.backgroundTex:getY()

        if self.warnCruiseTex then
            self.warnCruiseTex:setX(bx + self.WARN_CRUISE_X)
            self.warnCruiseTex:setY(by + self.WARN_CRUISE_Y)
        end
        if self.warnBatteryTex then
            self.warnBatteryTex:setX(bx + self.WARN_BATTERY_X)
            self.warnBatteryTex:setY(by + self.WARN_BATTERY_Y)
        end
        if self.warnBrakeTex then
            self.warnBrakeTex:setX(bx + self.WARN_BRAKE_X)
            self.warnBrakeTex:setY(by + self.WARN_BRAKE_Y)
        end
        if self.warnCheckTex then
            self.warnCheckTex:setX(bx + self.WARN_CHECK_X)
            self.warnCheckTex:setY(by + self.WARN_CHECK_Y)
        end
        if self.warnStopTex then
            self.warnStopTex:setX(bx + self.WARN_STOP_X)
            self.warnStopTex:setY(by + self.WARN_STOP_Y)
        end
        if self.warnDoorTex then
            self.warnDoorTex:setX(bx + self.WARN_DOOR_X)
            self.warnDoorTex:setY(by + self.WARN_DOOR_Y)
        end
        if self.warnFuelTex then
            self.warnFuelTex:setX(bx + self.WARN_FUEL_X)
            self.warnFuelTex:setY(by + self.WARN_FUEL_Y)
        end
        if self.warnLightTex then
            self.warnLightTex:setX(bx + self.WARN_LIGHT_X)
            self.warnLightTex:setY(by + self.WARN_LIGHT_Y)
        end

        if self.__YourDashNeedleLayer and self.backgroundTex then
            self.__YourDashNeedleLayer:setX(self.backgroundTex:getX())
            self.__YourDashNeedleLayer:setY(self.backgroundTex:getY())
            self.__YourDashNeedleLayer:setWidth(self.backgroundTex:getWidth())
            self.__YourDashNeedleLayer:setHeight(self.backgroundTex:getHeight())
        end
        if self._YourDashPositionGlassOverlay then self:_YourDashPositionGlassOverlay() end
        if self._YourDashBringControlsAboveGlass then self:_YourDashBringControlsAboveGlass() end
    end
end
