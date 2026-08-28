-- media/lua/client/Vehicles/ISUI/Z_PatchVehicleDashboard_RadioPremium.lua
if isServer() then return end

require "YourDash/DashboardCore"
require "Vehicles/ISUI/ISVehicleDashboard"
require "ISUI/ISImage"
require "ISUI/ISPanel"
require "TimedActions/ISBaseTimedAction"
require "TimedActions/ISTimedActionQueue"
require "RadioCom/ISRadioAction"
require "RadioCom/RadioWindowModules/RWMPanel" -- PresetEntry.new
require "ISUI/ISContextMenu"
pcall(function() require "ISUI/ISInventoryPaneContextMenu" end)

if ISVehicleDashboard.__YourDashRadioPremiumLoaded then return end
ISVehicleDashboard.__YourDashRadioPremiumLoaded = true

-- =========================
-- Config
-- =========================


-- OFFSETS ONLY - force apply
ISVehicleDashboard.RADIO_UI_X = 531
ISVehicleDashboard.RADIO_UI_Y = 60

ISVehicleDashboard.RADIO_POWER_OFF_X = 5
ISVehicleDashboard.RADIO_POWER_OFF_Y = 4

ISVehicleDashboard.RADIO_VOL_DOWN_OFF_X = 3
ISVehicleDashboard.RADIO_VOL_DOWN_OFF_Y = 33
ISVehicleDashboard.RADIO_VOL_UP_OFF_X   = 3
ISVehicleDashboard.RADIO_VOL_UP_OFF_Y   = 17

ISVehicleDashboard.RADIO_TUNE_OFF_X = 90
ISVehicleDashboard.RADIO_TUNE_OFF_Y = 44

ISVehicleDashboard.RADIO_SET_OFF_X = 149
ISVehicleDashboard.RADIO_SET_OFF_Y = 3

ISVehicleDashboard.RADIO_FREQ_UP_OFF_X   = 170
ISVehicleDashboard.RADIO_FREQ_UP_OFF_Y   = 17
ISVehicleDashboard.RADIO_FREQ_DOWN_OFF_X = 170
ISVehicleDashboard.RADIO_FREQ_DOWN_OFF_Y = 33

ISVehicleDashboard.RADIO_SRC_OFF_X = 62
ISVehicleDashboard.RADIO_SRC_OFF_Y = 43

ISVehicleDashboard.RADIO_LOAD_OFF_X = 175
ISVehicleDashboard.RADIO_LOAD_OFF_Y = 5

ISVehicleDashboard.RADIO_PAUSE_OFF_X = 116
ISVehicleDashboard.RADIO_PAUSE_OFF_Y = 43

ISVehicleDashboard.RADIO_CHAN_OFF_X = {29, 49, 69, 89, 109, 129}
ISVehicleDashboard.RADIO_CHAN_OFF_Y = {3, 3, 3, 3, 3, 3}

-- Text positions (relative to radioBG local coords)
ISVehicleDashboard.RADIO_TEXT_VOL_X  = 32
ISVehicleDashboard.RADIO_TEXT_VOL_Y  = 24

ISVehicleDashboard.RADIO_TEXT_FREQ_X = -32  -- negative = from right edge
ISVehicleDashboard.RADIO_TEXT_FREQ_Y = 24

ISVehicleDashboard.RADIO_TEXT_VOL_CENTER_X = 48
ISVehicleDashboard.RADIO_TEXT_FREQ_CENTER_X = -52
ISVehicleDashboard.RADIO_TEXT_SIDE_NUMBER_Y = 24
ISVehicleDashboard.RADIO_TEXT_SIDE_BLOCK_W = 42
ISVehicleDashboard.RADIO_TEXT_SIDE_NUMBER_ZOOM = 1.12
ISVehicleDashboard.RADIO_TEXT_MAIN_ZOOM = 1.08

ISVehicleDashboard.RADIO_TEXT_NAME_X = 0    -- 0 = centered
ISVehicleDashboard.RADIO_TEXT_NAME_Y = 24

ISVehicleDashboard.RADIO_TEXT_ARMED_X = 0   -- 0 = centered
ISVehicleDashboard.RADIO_TEXT_ARMED_Y = 24

-- Marquee clip rect (relative to radioBG local coords)
-- These are the 1x fallback values.  The renderer narrows this corridor at
-- runtime from the measured side readouts, which matters at 0.75x where the
-- font cannot shrink in exact proportion with the artwork.
ISVehicleDashboard.RADIO_TEXT_NAME_CLIP_X = 53
ISVehicleDashboard.RADIO_TEXT_NAME_CLIP_Y = 22
ISVehicleDashboard.RADIO_TEXT_NAME_CLIP_W = 72
ISVehicleDashboard.RADIO_TEXT_NAME_CLIP_H = 20

-- Safe interior of the exported premium LCD at 1x.  Keeping all generated
-- text inside this rectangle prevents it spilling onto the bezel.
ISVehicleDashboard.RADIO_TEXT_LCD_X = 31
ISVehicleDashboard.RADIO_TEXT_LCD_RIGHT_PAD = 31
ISVehicleDashboard.RADIO_TEXT_LCD_Y = 22
ISVehicleDashboard.RADIO_TEXT_LCD_H = 20
ISVehicleDashboard.RADIO_TEXT_SIDE_GAP = 2

-- Everything else: original defaults (only set if not already set)
ISVehicleDashboard.RADIO_VOL_STEP = ISVehicleDashboard.RADIO_VOL_STEP or 0.1

ISVehicleDashboard.RADIO_FREQ_STEP = ISVehicleDashboard.RADIO_FREQ_STEP or 100
ISVehicleDashboard.RADIO_FREQ_HOLD_DELAY = ISVehicleDashboard.RADIO_FREQ_HOLD_DELAY or 0.8
ISVehicleDashboard.RADIO_FREQ_REPEAT_INTERVAL = ISVehicleDashboard.RADIO_FREQ_REPEAT_INTERVAL or 0.1

ISVehicleDashboard.RADIO_TUNE_STEP     = ISVehicleDashboard.RADIO_TUNE_STEP     or 100  -- 0.1 MHz
ISVehicleDashboard.RADIO_TUNE_INTERVAL = ISVehicleDashboard.RADIO_TUNE_INTERVAL or 0.2  -- seconds per step

-- Preset policy: pad vanilla list to 6 with 88.0 MHz
ISVehicleDashboard.RADIO_PRESET_PAD_FREQ   = ISVehicleDashboard.RADIO_PRESET_PAD_FREQ or 88000 -- 88.0 MHz
ISVehicleDashboard.RADIO_PRESET_PAD_NAME   = ISVehicleDashboard.RADIO_PRESET_PAD_NAME or " "
ISVehicleDashboard.RADIO_PRESET_WRITE_NAME = ISVehicleDashboard.RADIO_PRESET_WRITE_NAME or " "

-- Text style.  Font size is selected by DashboardCore for the active pack.
ISVehicleDashboard.RADIO_TEXT_A    = ISVehicleDashboard.RADIO_TEXT_A    or 0.95
ISVehicleDashboard.RADIO_TEXT_RGB  = ISVehicleDashboard.RADIO_TEXT_RGB  or { r=0.176, g=0.314, b=0.176 }

-- Marquee (rolling) for channel name
ISVehicleDashboard.RADIO_TEXT_MARQUEE_SPEED_PX_S = ISVehicleDashboard.RADIO_TEXT_MARQUEE_SPEED_PX_S or 15
ISVehicleDashboard.RADIO_TEXT_MARQUEE_GAP_PX     = ISVehicleDashboard.RADIO_TEXT_MARQUEE_GAP_PX     or 20
ISVehicleDashboard.RADIO_TEXT_MARQUEE_DELAY_S    = ISVehicleDashboard.RADIO_TEXT_MARQUEE_DELAY_S    or 2

-- Misc UI timings / strings
ISVehicleDashboard.RADIO_SET_TIMEOUT_S = ISVehicleDashboard.RADIO_SET_TIMEOUT_S or 10.0
ISVehicleDashboard.RADIO_LOADING_TEXT = ISVehicleDashboard.RADIO_LOADING_TEXT or "Loading..."

-- =========================
-- Helpers
-- =========================
local function clamp(v, a, b)
    if v < a then return a end
    if v > b then return b end
    return v
end

local function ydScale()
    local scale = YourDash and YourDash.GetScale and tonumber(YourDash.GetScale()) or 1
    if scale ~= 0.75 and scale ~= 1 and scale ~= 1.4 and scale ~= 2 then
        return 1
    end
    return scale
end

local function ydScaled(value, scale)
    value = tonumber(value) or 0
    scale = scale or ydScale()
    local result = value * scale
    if result < 0 then return math.ceil(result - 0.5) end
    return math.floor(result + 0.5)
end

local function ydPack(scale)
    scale = scale or ydScale()
    if scale == 0.75 then return "0.75x" end
    if scale == 1.4 then return "1.4x" end
    if scale == 2 then return "2x" end
    return "1x"
end

local function ydRadioTex(filename)
    if YourDash and YourDash.GetRadioTexture then
        local texture = YourDash.GetRadioTexture("premium", filename)
        if texture then return texture end
    end
    return getTexture("media/ui/vehicles/radio/premium/" .. ydPack() .. "/" .. filename)
end

local function ydUIFont()
    if YourDash and YourDash.GetUIFont then
        local font = YourDash.GetUIFont()
        if font then return font end
    end
    return UIFont.Small
end

local function ydRadioAnchor(dash, layoutKey, fallbackX, fallbackY, scale)
    local x, y = fallbackX, fallbackY
    local point = nil
    if dash and dash._paxGetRadioAnchor then
        local radioWidth = dash.radioBG and dash.radioBG.getWidth and dash.radioBG:getWidth() or nil
        local ok, px, py = pcall(dash._paxGetRadioAnchor, dash, "premium", fallbackX, fallbackY, scale, radioWidth)
        if ok and px ~= nil and py ~= nil then return px, py end
    end
    if dash and dash._paxGetLayout1x then
        local ok, layout = pcall(dash._paxGetLayout1x, dash)
        point = ok and layout and layout.radioPremium or nil
    elseif YourDash and YourDash.GetLayoutPoint then
        local ok, px, py = pcall(YourDash.GetLayoutPoint, dash, "radio", "premium")
        if ok and px ~= nil and py ~= nil then return px, py end
    elseif YourDash and YourDash.GetLayout then
        local ok, layout = pcall(YourDash.GetLayout, dash)
        point = ok and layout and layout[layoutKey] or nil
    end
    if type(point) == "table" then
        x = tonumber(point.x or point[1]) or x
        y = tonumber(point.y or point[2]) or y
    end
    return ydScaled(x, scale), ydScaled(y, scale)
end

-- =========================
-- Single-player pause lock helpers
-- =========================
local function _ydIsPausedSP()
    -- SP pause shows as gamespeed 0. In MP there’s no real pause; keep usable there.
    return (not isClient()) and (getGameSpeed and getGameSpeed() == 0)
end

local function _ydForceNormalSpeedIfSP()
    -- Only meaningful in SP; MP clients shouldn't try to control global speed.
    if (not isClient()) and getGameSpeed and setGameSpeed then
        local gs = getGameSpeed()
        if gs and gs > 1 then
            setGameSpeed(1)
        end
    end
end

-- Keep Premium Radio above the glass overlay (dash.png / stains / cracks)
function ISVehicleDashboard:_YourDashBringPremiumRadioAboveGlass()
    -- Only relevant if you created a glass overlay child in the main dashboard patch
    if not self.__YourDashGlassOverlay then return end

    local function top(ui)
        if ui and ui.bringToTop then ui:bringToTop() end
    end

    -- IMPORTANT: bring BG first so it stays behind the buttons
    top(self.radioBG)

    top(self.radioPowerBtn)
    top(self.radioVolDownBtn)
    top(self.radioVolUpBtn)
    top(self.radioTuneBtn)
    top(self.radioSetBtn)
    top(self.radioFreqDownBtn)
    top(self.radioFreqUpBtn)
    top(self.radioSrcBtn)
    top(self.radioLoadDiskBtn)
    top(self.radioPauseBtn)

    if self.radioChanBtn then
        for i = 1, 6 do
            top(self.radioChanBtn[i])
        end
    end
end

function ISVehicleDashboard:_radioBeginLoading(targetPlaying, timeout, cdPausedAfter, restoreVolAfter, restoreVolValue)
    self.__radioLoading = true
    self.__radioLoadingTargetPlaying = targetPlaying      -- true/false/nil

    -- Optional state changes to apply ONLY when the target state is reached
    self.__radioLoadingCdPausedAfter = cdPausedAfter      -- true/false/nil
    self.__radioLoadingRestoreVolAfter = (restoreVolAfter == true)
    self.__radioLoadingRestoreVolValue = restoreVolValue

    -- Remember which source we were in when loading began; if user changes source again, cancel
    self.__radioLoadingExpectedSource = self.__radioSource

    -- IMPORTANT: ensure Loading... is visible at least one rendered frame
    self.__radioLoadingJustStarted = true

    -- Nuke marquee state immediately (so old text never flashes)
    self.__radioMarqueeText   = nil
    self.__radioMarqueeOffset = 0
    self.__radioMarqueeDelayT = 0
    self.__radioMarqueeW      = 0
end

function ISVehicleDashboard:_radioClearLoading()
    self.__radioLoading = false
    self.__radioLoadingTargetPlaying = nil
    self.__radioLoadingCdPausedAfter = nil
    self.__radioLoadingRestoreVolAfter = nil
    self.__radioLoadingRestoreVolValue = nil
    self.__radioLoadingExpectedSource = nil
    self.__radioLoadingJustStarted = nil
end

function ISVehicleDashboard:_radioUpdateLoading(dd, dt)
    if self.__radioLoading ~= true then return end

    -- Show at least 1 rendered frame of Loading... even if state already matches
    if self.__radioLoadingJustStarted == true then
        self.__radioLoadingJustStarted = false
        return
    end

    -- Cancel if source changed since loading started (user toggled again)
    if self.__radioLoadingExpectedSource and self.__radioSource ~= self.__radioLoadingExpectedSource then
        self:_radioClearLoading()
        return
    end

    -- Cancel if device disappeared / turned off
    if not dd or not (dd.getIsTurnedOn and dd:getIsTurnedOn() == true) then
        self:_radioClearLoading()
        return
    end

    -- If we're waiting for "playing=true" but disc is gone, cancel
    if self.__radioLoadingTargetPlaying == true and not (dd.hasMedia and dd:hasMedia()) then
        self:_radioClearLoading()
        return
    end

    -- Autodetect completion via isPlayingMedia()
    if self.__radioLoadingTargetPlaying ~= nil and dd.isPlayingMedia then
        local ok, playing = pcall(function() return dd:isPlayingMedia() end)
        if ok and (playing == self.__radioLoadingTargetPlaying) then
            -- Apply optional state only when we actually hit the target state
            if self.__radioLoadingCdPausedAfter ~= nil then
                self.__radioCdPaused = self.__radioLoadingCdPausedAfter
            end

            if self.__radioLoadingRestoreVolAfter == true and dd.setDeviceVolume then
                local v = self.__radioLoadingRestoreVolValue
                if v == nil then v = 0.5 end
                dd:setDeviceVolume(v)
                if dd.updateSimple then pcall(function() dd:updateSimple() end) end
                self.__radioCdMutedByPause = false
            end

            self:_radioClearLoading()
            return
        end
    end

    -- No timeout auto-clear: stays Loading... until state flips (or gets cancelled above).
end


function ISVehicleDashboard:_radioSupportsMedia(dd)
    if not dd then return false end
    if dd.getMediaType then
        local ok, mt = pcall(function() return dd:getMediaType() end)
        if ok and mt ~= nil then return true end
    end
    -- fallback: if hasMedia() exists, it's probably a media-capable device
    return dd.hasMedia ~= nil
end

function ISVehicleDashboard:_radioGetLoadedMediaName(dd)
    if not dd or not (dd.hasMedia and dd:hasMedia()) then return nil end

    -- Correct API: DeviceData:getMediaData() -> MediaData has translated names
    if dd.getMediaData then
        local ok, md = pcall(function() return dd:getMediaData() end)
        if ok and md then
            -- Prefer title if present (often nicer)
            if md.hasTitle and md:hasTitle() and md.getTranslatedTitle then
                local ok2, t = pcall(function() return md:getTranslatedTitle() end)
                if ok2 and t and t ~= "" then return t end
            end

            if md.getTranslatedItemDisplayName then
                local ok2, nm = pcall(function() return md:getTranslatedItemDisplayName() end)
                if ok2 and nm and nm ~= "" then return nm end
            end
        end
    end

    -- Fallback: cache from your load menu
    if self.__radioMediaNameCache and self.__radioMediaNameCache ~= "" then
        return self.__radioMediaNameCache
    end

    return "Disc"
end




local function collectMediaItemsFromInventory(inv, wantMediaType)
    local out = {}
    if not inv or not inv.getItems then return out end
    local items = inv:getItems()
    if not items then return out end

    for i = 0, items:size() - 1 do
        local it = items:get(i)
        if it and it.getMediaType then
            local ok, mt = pcall(function() return it:getMediaType() end)
            if ok and (wantMediaType == nil or mt == wantMediaType) then
                table.insert(out, it)
            end
        end
    end
    return out
end


local YourDashVehicleRadioMediaAction = ISBaseTimedAction:derive("YourDashVehicleRadioMediaAction")

function YourDashVehicleRadioMediaAction:isValid()
    if not self.character or not self.deviceData then return false end
    if self.isRemove == true then
        return self.deviceData.hasMedia and self.deviceData:hasMedia()
    end
    if not self.secondaryItem then return false end
    if not (self.deviceData.hasMedia and self.deviceData.getMediaType) then return false end
    if self.deviceData:hasMedia() then return false end
    if not self.secondaryItem.getMediaType then return false end
    return self.deviceData:getMediaType() == self.secondaryItem:getMediaType()
end

function YourDashVehicleRadioMediaAction:invoke()
    if self.__didInvoke == true then return end
    self.__didInvoke = true
    if not self:isValid() then return end

    if self.isRemove == true then
        local inv = self.character.getInventory and self.character:getInventory() or nil
        if inv and self.deviceData.removeMediaItem then
            self.deviceData:removeMediaItem(inv)
        end
    elseif self.deviceData.addMediaItem then
        self.deviceData:addMediaItem(self.secondaryItem)
    end

    if self.deviceData.updateSimple then
        pcall(function() self.deviceData:updateSimple() end)
    end
end

function YourDashVehicleRadioMediaAction:perform()
    self:invoke()
    ISBaseTimedAction.perform(self)
end

function YourDashVehicleRadioMediaAction:complete()
    self:invoke()
    return true
end

function YourDashVehicleRadioMediaAction:new(character, device, isRemove, secondaryItem)
    local o = ISBaseTimedAction.new(self, character)
    o.character = character
    o.device = device
    o.deviceData = device and device.getDeviceData and device:getDeviceData() or nil
    o.isRemove = isRemove == true
    o.secondaryItem = secondaryItem
    o.stopOnWalk = false
    o.stopOnRun = true
    o.ignoreHandsWounds = true
    o.maxTime = 30
    return o
end



local function measureTextX(font, text)
    if not text or text == "" then return 0 end
    local tm = getTextManager and getTextManager() or nil
    if tm and tm.MeasureStringX then
        return tm:MeasureStringX(font, text)
    end
    -- fallback: rough estimate if MeasureStringX isn't available for some reason
    return string.len(text) * ydScaled(6)
end

local function measureTextHeight(font)
    local tm = getTextManager and getTextManager() or nil
    if tm and tm.getFontHeight then
        return tm:getFontHeight(font)
    end
    return ydScaled(16)
end

local function premiumTextZoomForLCD(dash, scale, font, wantedZoom)
    local zoom = tonumber(wantedZoom) or 1.00
    local lcdH = math.max(1, ydScaled(dash.RADIO_TEXT_LCD_H or 20, scale))
    local fontH = math.max(1, measureTextHeight(font))
    local fitZoom = math.max(0.01, (lcdH - 1) / fontH)
    return math.min(zoom, fitZoom)
end

local function premiumMainTextZoom(dash, scale, font)
    return premiumTextZoomForLCD(dash, scale, font, dash.RADIO_TEXT_MAIN_ZOOM or 1.00)
end

local function drawPremiumCenteredText(panel, text, centerX, y, zoom, r, g, b, a, font)
    if panel.drawTextZoomed then
        local w = measureTextX(font, text) * zoom
        local x = math.floor(centerX - w * 0.5 + 0.5)
        panel:drawTextZoomed(text, x, y, zoom, r, g, b, a, font)
    else
        panel:drawTextCentre(text, centerX, y, r, g, b, a, font)
    end
end

local function premiumSideReadoutText(text, side)
    text = tostring(text or "")
    if text == "" then return "" end

    local lower = string.lower(text)
    if side == "left" then
        local value = string.match(text, "^%s*[Vv][Oo][Ll]%s+(.+)%s*$")
        if value and value ~= "" then return value end
    elseif string.find(lower, "mhz", 1, true) then
        local value = string.match(text, "^%s*([%d%.]+)")
        if value and value ~= "" then return value end
    elseif lower == "cd" then
        return "CD"
    end

    return text
end

local function premiumSideMaxNumberZoom(dash, scale)
    return tonumber(dash.RADIO_TEXT_SIDE_NUMBER_ZOOM) or 1.00
end

local function premiumSideDisplaySpec(dash, width, scale, side, text)
    scale = scale or ydScale()
    local number = premiumSideReadoutText(text, side)
    if number == "" then return nil end

    local numberFont = ydUIFont()
    local maxBlockWidth = math.max(1, ydScaled(dash.RADIO_TEXT_SIDE_BLOCK_W or 34, scale))
    local numberWidthRaw = measureTextX(numberFont, number)
    local numberZoom = premiumTextZoomForLCD(dash, scale, numberFont, premiumSideMaxNumberZoom(dash, scale))

    if numberWidthRaw > 0 then
        numberZoom = math.min(numberZoom, maxBlockWidth / numberWidthRaw)
    end

    local centerX
    if side == "right" then
        centerX = width + ydScaled(dash.RADIO_TEXT_FREQ_CENTER_X or -47, scale)
    else
        centerX = ydScaled(dash.RADIO_TEXT_VOL_CENTER_X or 47, scale)
    end

    local blockWidth = numberWidthRaw * numberZoom
    return {
        number = number,
        centerX = centerX,
        numberY = ydScaled(dash.RADIO_TEXT_SIDE_NUMBER_Y or 19, scale),
        numberFont = numberFont,
        numberZoom = numberZoom,
        numberWidth = numberWidthRaw,
        width = blockWidth,
        left = centerX - blockWidth * 0.5,
        right = centerX + blockWidth * 0.5,
    }
end

-- Calculate the middle carousel from the actual rendered widths of the two
-- side readouts.  A fixed 1x clip scaled down to 0.75x overlaps because the
-- smallest UI font remains 16 pixels high/wide instead of becoming 0.75x.
local function premiumLCDGeometry(dash, width, scale, mainFont, left, right)
    width = tonumber(width) or ydScaled(196, scale)
    scale = scale or ydScale()
    mainFont = mainFont or ydUIFont()
    left = left or ""
    right = right or ""

    local lcdX = ydScaled(dash.RADIO_TEXT_LCD_X or 31, scale)
    local lcdRight = width - ydScaled(dash.RADIO_TEXT_LCD_RIGHT_PAD or 31, scale)
    local lcdY = ydScaled(dash.RADIO_TEXT_LCD_Y or 21, scale)
    local lcdH = math.max(1, ydScaled(dash.RADIO_TEXT_LCD_H or 24, scale))
    local sideGap = math.max(1, ydScaled(dash.RADIO_TEXT_SIDE_GAP or 2, scale))
    local leftSpec = premiumSideDisplaySpec(dash, width, scale, "left", left)
    local rightSpec = premiumSideDisplaySpec(dash, width, scale, "right", right)
    local clipX = lcdX
    local clipRight = lcdRight

    if leftSpec then
        clipX = math.max(clipX, leftSpec.right + sideGap)
    end
    if rightSpec then
        clipRight = math.min(clipRight, rightSpec.left - sideGap)
    end

    -- Defensive fallback for unusual translated fonts.  It remains confined
    -- to the LCD even if both side strings consume nearly all available room.
    if clipRight <= clipX then
        local fallbackX = ydScaled(dash.RADIO_TEXT_NAME_CLIP_X or 53, scale)
        local fallbackW = math.max(1, ydScaled(dash.RADIO_TEXT_NAME_CLIP_W or 72, scale))
        clipX = math.max(lcdX, fallbackX)
        clipRight = math.min(lcdRight, fallbackX + fallbackW)
        if clipRight <= clipX then clipRight = math.min(lcdRight, clipX + 1) end
    end

    return {
        lcdX = lcdX,
        lcdY = lcdY,
        lcdW = math.max(1, lcdRight - lcdX),
        lcdH = lcdH,
        clipX = clipX,
        clipY = lcdY,
        clipW = math.max(1, clipRight - clipX),
        clipH = lcdH,
        leftSide = leftSpec,
        rightSide = rightSpec,
        mainFont = mainFont,
    }
end


function ISVehicleDashboard:_radioDisarmSet()
    self.__radioSetArmed = false
    self.__radioSetArmedT = 0
end

function ISVehicleDashboard:_radioFmtMHz(freq)
    if not freq then return "—.— MHz" end
    return string.format("%.1f MHz", (freq or 0) / 1000)
end

function ISVehicleDashboard:_radioFmtMHzCompact(freq, numberOnly)
    if not freq then return numberOnly and "—.—" or "—.—M" end
    local value = string.format("%.1f", (freq or 0) / 1000)
    return numberOnly and value or (value .. "M")
end

-- Try several ways to get a meaningful “channel name”.
-- Falls back to matching current frequency against presets (first 6).
function ISVehicleDashboard:_radioGetCurrentName(dd)
    if not dd then return nil end
    local cur = dd.getChannel and dd:getChannel() or nil
    if not cur then return nil end

    -- 1) Best: ask the radio system for the channel name at this frequency
    if ZomboidRadio and ZomboidRadio.getInstance then
        local ok, zr = pcall(function() return ZomboidRadio.getInstance() end)
        if ok and zr and zr.getChannelName then
            local ok2, nm = pcall(function() return zr:getChannelName(cur) end)
            if ok2 and nm and nm ~= "" then
                return nm
            end
        end
    end

    -- 2) Fallback: match against your preset list (first 6)
    local list = self:_radioGetDevicePresetList(dd)
    if list then
        for i = 1, math.min(6, list:size()) do
            local p = list:get(i - 1)
            local fq = p and p.getFrequency and p:getFrequency() or nil
            if fq and fq == cur then
                local nm = p.getName and p:getName() or nil
                if nm and nm ~= "" and nm ~= " " then return nm end
            end
        end
    end

    return nil
end



local function setImageTextureAndSize(dash, img, tex)
    if not img or not tex then return end
    if dash and dash._setImageTextureAndSize then
        dash:_setImageTextureAndSize(img, tex)
        return
    end
    img.texture = tex
    if img.setWidth and tex.getWidthOrig then img:setWidth(tex:getWidthOrig()) end
    if img.setHeight and tex.getHeightOrig then img:setHeight(tex:getHeightOrig()) end
end

local function installPressedEffectFallback(img, pressedScale)
    if not img or img.__pressedEffectInstalled then return end
    img.__pressedEffectInstalled = true
    img.__pressedScale = pressedScale or 0.98
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

local function setEnabled(dash, img, enabled, tooltip, onclickFn)
    if not img then return end
    -- Single-player pause: hard-disable all buttons.
    if enabled and _ydIsPausedSP() then
        enabled = false
    end

    local fn = onclickFn or img.__handler

    if dash and dash._setImageEnabled then
        dash:_setImageEnabled(img, enabled, tooltip, fn, dash)
        return
    end

    img.__disabled = not enabled
    img.target = dash
    img.onclick = enabled and fn or nil
    img.mouseovertext = enabled and tooltip or nil
    img.backgroundColor = { r=0, g=0, b=0, a=0 }
end

-- =========================
-- MP sync: share radio source between occupants
-- =========================
local YD_NET_MOD  = "RealisticDash"
local YD_NET_CMD  = "SetRadioSource"
local YD_SRC_KEY  = "RealisticDash_RadioSource"

-- Receive server broadcast and cache it on the vehicle (client-side)
if not ISVehicleDashboard.__YourDashRadioSourceListener then
    ISVehicleDashboard.__YourDashRadioSourceListener = true

    local function onServerCommand(module, command, args)
        if module ~= YD_NET_MOD or command ~= YD_NET_CMD then return end
        if not args or args.vid == nil or args.src == nil then return end

        local vid = tonumber(args.vid)
        local src = tostring(args.src)
        if not vid then return end
        if src ~= "radio" and src ~= "cd" then return end

        local veh = getVehicleById(vid)
        if veh and veh.getModData then
            veh:getModData()[YD_SRC_KEY] = src
        end
    end

    Events.OnServerCommand.Add(onServerCommand)
end

function ISVehicleDashboard:_ydBroadcastRadioSource(src)
    if src ~= "radio" and src ~= "cd" then return end
    if not self.vehicle then return end

    -- local cache (so sender updates instantly)
    if self.vehicle.getModData then
        self.vehicle:getModData()[YD_SRC_KEY] = src
    end

    -- MP: tell server, server will tell everyone else
    if isClient() and sendClientCommand and self.vehicle.getId then
        sendClientCommand(YD_NET_MOD, YD_NET_CMD, { vid = self.vehicle:getId(), src = src })
    end
end

function ISVehicleDashboard:_ydGetSharedRadioSource()
    if not self.vehicle or not self.vehicle.getModData then return nil end
    local src = self.vehicle:getModData()[YD_SRC_KEY]
    if src == "radio" or src == "cd" then return src end
    return nil
end

-- =========================
-- Radio device access
-- =========================
function ISVehicleDashboard:_getVehicleRadioPart()
    if not self.vehicle then return nil end

    local part = self.vehicle:getPartById("Radio")
    if part and part.getDeviceData and part:getDeviceData() then
        if part.getItemType and part:getItemType() and not part:getInventoryItem() then
            return nil
        end
        return part
    end

    local parts = self.vehicle:getParts()
    for i = 0, parts:size() - 1 do
        local p = parts:get(i)
        if p and p.getDeviceData then
            local dd = p:getDeviceData()
            if dd and dd.isVehicleDevice and dd:isVehicleDevice() then
                if p.getItemType and p:getItemType() and not p:getInventoryItem() then
                    -- not installed
                else
                    return p
                end
            end
        end
    end

    return nil
end

function ISVehicleDashboard:_radioHasPower(dd)
    if not dd then return false end
    local ok = false
    if dd.getPower and dd:getPower() > 0 then ok = true end
    if (not ok) and dd.canBePoweredHere and dd:canBePoweredHere() then ok = true end
    return ok
end

function ISVehicleDashboard:_radioCanOperate(dd)
    return dd and dd.getIsTurnedOn and dd:getIsTurnedOn() and self:_radioHasPower(dd)
end

function ISVehicleDashboard:_radioPlayTuneSound(dd)
    if not dd then return end
    local sound = "TuneIn"
    if dd.getIsTelevision and dd:getIsTelevision() then sound = "TelevisionZap" end
    if dd.isVehicleDevice and dd:isVehicleDevice() then sound = "VehicleRadioTuneIn" end
    if dd.stopOrTriggerSoundByName then dd:stopOrTriggerSoundByName(sound) end
    if dd.playSoundSend then dd:playSoundSend(sound, false) end
end

-- =========================
-- Vanilla preset list: pad to 6, use first 6 only
-- =========================
function ISVehicleDashboard:_radioGetDevicePresetsObj(dd)
    return dd and dd.getDevicePresets and dd:getDevicePresets() or nil
end

function ISVehicleDashboard:_radioGetDevicePresetList(dd)
    local dp = self:_radioGetDevicePresetsObj(dd)
    return dp and dp.getPresets and dp:getPresets() or nil
end

function ISVehicleDashboard:_radioEnsurePresetList6(dd)
    local list = self:_radioGetDevicePresetList(dd)
    if not list then return nil end

    local target = 6
    local padFreq = self.RADIO_PRESET_PAD_FREQ or 88000
    local padName = self.RADIO_PRESET_PAD_NAME or " "

    if list:size() < target then
        if not (PresetEntry and PresetEntry.new) then
            print("[YourDash Radio] PresetEntry.new missing; cannot pad preset list.")
            return list
        end
        while list:size() < target do
            list:add(PresetEntry.new(padName, padFreq))
        end
        if dd.transmitPresets then pcall(function() dd:transmitPresets() end) end
        if dd.updateSimple then pcall(function() dd:updateSimple() end) end
    end

    return list
end

function ISVehicleDashboard:_radioGetPresetEntry1to6(dd, idx)
    if not idx or idx < 1 or idx > 6 then return nil end
    local list = self:_radioEnsurePresetList6(dd)
    if not list then return nil end
    if idx > list:size() then return nil end
    return list:get(idx - 1)
end

function ISVehicleDashboard:_radioWritePreset1to6(dd, idx, freq, name)
    local preset = self:_radioGetPresetEntry1to6(dd, idx)
    if not preset then return false end

    if preset.setFrequency then preset:setFrequency(freq) end

    local nm = name
    if nm and type(nm) == "string" then
        nm = nm:gsub("^%s+", ""):gsub("%s+$", "")
    else
        nm = nil
    end

    if preset.setName then
        if nm and nm ~= "" then
            preset:setName(nm)
        else
            preset:setName(self.RADIO_PRESET_WRITE_NAME or " ")
        end
    end

    if dd.transmitPresets then pcall(function() dd:transmitPresets() end) end
    if dd.updateSimple then pcall(function() dd:updateSimple() end) end
    return true
end


-- =========================
-- Actions: power / volume / set / channels
-- =========================
function ISVehicleDashboard:onClickRadioPowerBasic()
    self:_radioStopTuneScan(false)
    self:_radioDisarmSet()

    if getGameSpeed() == 0 then return end
    if getGameSpeed() > 1 then setGameSpeed(1) end
    if not self.vehicle or not self.character then return end

    local part = self:_getVehicleRadioPart()
    if not part then return end
    local dd = part:getDeviceData()
    if not dd then return end

    local canToggle = false
    if dd.getIsBatteryPowered and dd.getPower and dd:getIsBatteryPowered() then
        canToggle = (dd:getPower() > 0)
    end
    if (not canToggle) and dd.canBePoweredHere then
        canToggle = (dd:canBePoweredHere() == true)
    end
    if not canToggle then return end

    ISTimedActionQueue.add(ISRadioAction:new("ToggleOnOff", self.character, part))
end

function ISVehicleDashboard:_radioSetVolumeDelta(delta)
    self:_radioDisarmSet()
    if getGameSpeed() == 0 then return end
    if getGameSpeed() > 1 then setGameSpeed(1) end
    if not self.vehicle or not self.character then return end

    local part = self:_getVehicleRadioPart()
    if not part then return end
    local dd = part:getDeviceData()
    if not self:_radioCanOperate(dd) then return end

    local v = (dd.getDeviceVolume and dd:getDeviceVolume()) or 0
    -- If CD is paused and we muted device to prevent radio bleed,
    -- adjust stored resume volume instead of the actual device volume.
    if self.__radioSource == "cd" and self.__radioCdMutedByPause == true then
        local vStored = self.__radioCdPrevVol or 0
        local nv = clamp(vStored + (delta or 0), 0, 1)
        self.__radioCdPrevVol = nv
        if dd.setDeviceVolume then dd:setDeviceVolume(0) end
        if dd.updateSimple then dd:updateSimple() end
        return
    end
    local nv = clamp((v or 0) + (delta or 0), 0, 1)

    -- If player adjusts volume while muted, consider it unmuting
    if (self.__radioMuted == true) and (nv or 0) > 0 then
        self.__radioMuted = false
        self.__radioPrevVol = nil
    end

    if dd.setDeviceVolume then dd:setDeviceVolume(nv) end
    if dd.updateSimple then dd:updateSimple() end
end

function ISVehicleDashboard:onClickRadioVolUp()
    self:_radioSetVolumeDelta(self.RADIO_VOL_STEP or 0.05)
end

function ISVehicleDashboard:onClickRadioVolDown()
    self:_radioSetVolumeDelta(-(self.RADIO_VOL_STEP or 0.05))
end

function ISVehicleDashboard:onClickRadioSet()
    if (self.__radioSource or "radio") == "cd" then return end

    self:_radioStopTuneScan(false)

    if self.__radioSetArmed == true then
        self:_radioDisarmSet()
    else
        self.__radioSetArmed = true
        self.__radioSetArmedT = 0
    end
end


function ISVehicleDashboard:_radioOnClickChannelIndex(idx)
    self.__radioSetArmedT = 0
    if not self.vehicle or not self.character then return end
    self:_radioStopTuneScan(false)

    local part = self:_getVehicleRadioPart()
    if not part then return end
    local dd = part:getDeviceData()
    if not dd then return end
    if not self:_radioCanOperate(dd) then
        self.__radioSetArmed = false
        return
    end

    -- CD -> RADIO on channel press
    if (self.__radioSource or "radio") == "cd" then
        self.__radioSource = "radio"
        self:_ydBroadcastRadioSource("radio")
        self.__radioSetArmed = false

        -- what volume should radio return to?
        local restoreVal = self.__radioCdPrevVol
        if restoreVal == nil then
            restoreVal = (dd.getDeviceVolume and dd:getDeviceVolume()) or 0.5
        end

        local playing = (dd.isPlayingMedia and dd:isPlayingMedia() == true)

        if playing then
            -- Mark "switchingToRadio" so your per-frame CD-sync doesn't flip back to CD.
            self.__radioCdPrevVol = restoreVal

            -- silence during stop
            if dd.setDeviceVolume then dd:setDeviceVolume(0) end
            if dd.updateSimple then pcall(function() dd:updateSimple() end) end

            if self.__radioMuted == true then
                -- stay muted, but remember what to restore when unmuting
                self.__radioPrevVol = restoreVal
                self:_radioBeginLoading(false, nil, nil, false)
                self.__radioCdMutedByPause = false
            else
                -- restore volume after stop completes
                self.__radioCdMutedByPause = true
                self:_radioBeginLoading(false, nil, nil, true, restoreVal)
            end

            -- stop CD now
            if dd.StopPlayMedia then pcall(function() dd:StopPlayMedia() end) end
            if dd.updateMediaPlaying then pcall(function() dd:updateMediaPlaying() end) end
            if dd.updateSimple then pcall(function() dd:updateSimple() end) end
        else
            -- Not playing: if we were forced silent by CD pause/loading, restore immediately (unless muted)
            if self.__radioCdMutedByPause == true then
                self.__radioCdPrevVol = restoreVal
                if self.__radioMuted == true then
                    self.__radioPrevVol = restoreVal
                    if dd.setDeviceVolume then dd:setDeviceVolume(0) end
                else
                    if dd.setDeviceVolume then dd:setDeviceVolume(restoreVal) end
                end
                if dd.updateSimple then pcall(function() dd:updateSimple() end) end
                self.__radioCdMutedByPause = false
            end
        end

        self.__radioCdPaused = false
    end

    -- Ensure list padded before doing anything
    self:_radioEnsurePresetList6(dd)

    if self.__radioSetArmed == true then
        local cur = dd.getChannel and dd:getChannel() or nil
        if cur then
            local nm = nil
            if (self.__radioSource or "radio") == "radio"
                and (self.__radioMuted ~= true)
                and self:_radioIsReceiving(dd)
            then
                nm = self:_radioGetCurrentName(dd)
            end
            self:_radioWritePreset1to6(dd, idx, cur, nm)
        end
        self.__radioSetArmed = false
        return
    end

    local preset = self:_radioGetPresetEntry1to6(dd, idx)
    if not preset then return end
    local fq = preset.getFrequency and preset:getFrequency() or nil
    if not fq then return end

    self:_radioPlayTuneSound(dd)
    if dd.setChannel then
        local ok = pcall(function() dd:setChannel(fq, true) end)
        if not ok then dd:setChannel(fq) end
    end
    if dd.updateSimple then dd:updateSimple() end
end



function ISVehicleDashboard:onClickRadioChan1() self:_radioOnClickChannelIndex(1) end
function ISVehicleDashboard:onClickRadioChan2() self:_radioOnClickChannelIndex(2) end
function ISVehicleDashboard:onClickRadioChan3() self:_radioOnClickChannelIndex(3) end
function ISVehicleDashboard:onClickRadioChan4() self:_radioOnClickChannelIndex(4) end
function ISVehicleDashboard:onClickRadioChan5() self:_radioOnClickChannelIndex(5) end
function ISVehicleDashboard:onClickRadioChan6() self:_radioOnClickChannelIndex(6) end

-- =========================
-- Tune scan (auto-search)
-- =========================
function ISVehicleDashboard:_radioIsReceiving(dd)
    if not dd then return false end
    local r = (dd.isReceivingSignal and dd:isReceivingSignal()) == true
    if (not r) and dd.getSignalStrength then
        local ss = dd:getSignalStrength()
        if ss and ss > 0 then r = true end
    end
    return r
end

function ISVehicleDashboard:_radioStopTuneScan(resetToStart)
    if not self.__radioTuneScanActive then return end

    local part = self:_getVehicleRadioPart()
    local dd = part and part:getDeviceData() or nil

    if resetToStart and dd and self.__radioTuneScanStartFreq then
        if dd.setChannel then
            pcall(function() dd:setChannel(self.__radioTuneScanStartFreq, true) end)
            if dd.getChannel and dd:getChannel() ~= self.__radioTuneScanStartFreq then
                dd:setChannel(self.__radioTuneScanStartFreq)
            end
        end
        if dd.updateSimple then dd:updateSimple() end
    end

    self.__radioTuneScanActive = false
    self.__radioTuneScanStartFreq = nil
    self.__radioTuneScanT = 0
    self.__radioTuneScanSteps = 0
    self.__radioTuneScanMaxSteps = 0
    self.__radioTuneSawNoSignal = nil
end

function ISVehicleDashboard:_radioTuneStepOnce(dd)
    if not dd then return end
    local step = self.RADIO_TUNE_STEP or 100
    if step <= 0 then step = 100 end

    local f  = dd.getChannel and dd:getChannel() or 0
    local mn = dd.getMinChannelRange and dd:getMinChannelRange() or f
    local mx = dd.getMaxChannelRange and dd:getMaxChannelRange() or f

    local nf = f + step
    if nf > mx then nf = mn end

    if dd.setChannel then
        local ok = pcall(function() dd:setChannel(nf, true) end)
        if not ok then dd:setChannel(nf) end
    end
    if dd.updateSimple then dd:updateSimple() end
end

function ISVehicleDashboard:_radioStartTuneScan()
    if _ydIsPausedSP() then return end
    _ydForceNormalSpeedIfSP()

    local part = self:_getVehicleRadioPart()
    if not part then return end
    local dd = part:getDeviceData()
    if not self:_radioCanOperate(dd) then return end

    self:_radioStopFreqHold()
    self:_radioStopTuneScan(false)

    local startF = dd.getChannel and dd:getChannel() or 0
    if dd.setChannel then pcall(function() dd:setChannel(startF, true) end) end
    if dd.updateSimple then dd:updateSimple() end

    self.__radioTuneScanActive = true
    self.__radioTuneScanStartFreq = startF
    self.__radioTuneScanT = 0
    self.__radioTuneScanSteps = 0

    -- Key rule to prevent “stop after 1 step”:
    -- must see no-signal at least once DURING scan before stopping on signal.
    self.__radioTuneSawNoSignal = (not self:_radioIsReceiving(dd))

    local mn = dd.getMinChannelRange and dd:getMinChannelRange() or startF
    local mx = dd.getMaxChannelRange and dd:getMaxChannelRange() or startF
    local step = self.RADIO_TUNE_STEP or 100
    if step <= 0 then step = 100 end

    local span = math.max(0, (mx - mn))
    self.__radioTuneScanMaxSteps = math.floor(span / step) + 1
    if self.__radioTuneScanMaxSteps < 1 then self.__radioTuneScanMaxSteps = 1 end

    self:_radioPlayTuneSound(dd)

    -- Step immediately
    self:_radioTuneStepOnce(dd)
    self.__radioTuneScanSteps = 1
    self.__radioTuneScanT = 0
end

function ISVehicleDashboard:_radioUpdateTuneScan(dt)
    -- SP: keep game at normal speed while scan is running (pause allowed)
    _ydForceNormalSpeedIfSP()
    if not self.__radioTuneScanActive then return end

    local part = self:_getVehicleRadioPart()
    local dd = part and part:getDeviceData() or nil
    if not self:_radioCanOperate(dd) then
        self:_radioStopTuneScan(false)
        return
    end

    self.__radioTuneScanT = (self.__radioTuneScanT or 0) + (dt or 0)

    local interval = self.RADIO_TUNE_INTERVAL or 0.2
    if interval <= 0 then interval = 0.2 end

    while self.__radioTuneScanT >= interval do
        self.__radioTuneScanT = self.__radioTuneScanT - interval

        local receiving = self:_radioIsReceiving(dd)
        if not receiving then
            self.__radioTuneSawNoSignal = true
        end

        -- stop only after we've seen no-signal at least once
        if receiving and self.__radioTuneSawNoSignal == true then
            self:_radioStopTuneScan(false)
            return
        end

        self:_radioTuneStepOnce(dd)
        self.__radioTuneScanSteps = (self.__radioTuneScanSteps or 0) + 1

        if (self.__radioTuneScanSteps or 0) >= (self.__radioTuneScanMaxSteps or 1) then
            self:_radioStopTuneScan(true)
            return
        end
    end
end

function ISVehicleDashboard:onClickRadioTune()
    if (self.__radioSource or "radio") == "cd" then return end

    -- SP pause: no interaction
    if _ydIsPausedSP() then return end

    -- Seek click should cancel any fast-forward
    _ydForceNormalSpeedIfSP()

    self:_radioDisarmSet()
    if self.__radioTuneScanActive then
        self:_radioStopTuneScan(false)
        return
    end
    self:_radioStartTuneScan()
end



-- =========================
-- Frequency hold-repeat
-- =========================
function ISVehicleDashboard:_radioStopFreqHold()
    self.__radioFreqHoldActive = false
    self.__radioFreqHoldDir = 0
    self.__radioFreqHoldT = 0
    self.__radioFreqHoldRepT = 0
end

function ISVehicleDashboard:_radioStepFrequency(dir, playSound)
    local part = self:_getVehicleRadioPart()
    if not part then return end
    local dd = part:getDeviceData()
    if not self:_radioCanOperate(dd) then return end

    local step = self.RADIO_FREQ_STEP or 200
    local f = dd.getChannel and dd:getChannel() or 0
    local mn = dd.getMinChannelRange and dd:getMinChannelRange() or f
    local mx = dd.getMaxChannelRange and dd:getMaxChannelRange() or f

    local nf = f + (dir * step)
    if nf > mx then nf = mn end
    if nf < mn then nf = mx end

    if playSound then self:_radioPlayTuneSound(dd) end
    if dd.setChannel then
        local ok = pcall(function() dd:setChannel(nf, true) end)
        if not ok then dd:setChannel(nf) end
    end
    if dd.updateSimple then dd:updateSimple() end
end

function ISVehicleDashboard:_radioBeginFreqHold(dir)
    if (self.__radioSource or "radio") == "cd" then return false end
    if self.__radioLoading == true then return false end

    self:_radioDisarmSet()
    self:_radioStopTuneScan(false)

    local part = self:_getVehicleRadioPart()
    if not part then return false end
    local dd = part:getDeviceData()
    if not self:_radioCanOperate(dd) then return false end

    self.__radioFreqHoldActive = true
    self.__radioFreqHoldDir = dir
    self.__radioFreqHoldT = 0
    self.__radioFreqHoldRepT = 0

    self:_radioStepFrequency(dir, true)
    return true
end

function ISVehicleDashboard:onClickRadioSrc()
    self:_radioStopTuneScan(false)
    self:_radioDisarmSet()

    if self.__radioLoading == true then return end
    if getGameSpeed() == 0 then return end
    if getGameSpeed() > 1 then setGameSpeed(1) end
    if not self.vehicle or not self.character then return end

    local part = self:_getVehicleRadioPart()
    if not part then return end
    local dd = part:getDeviceData()
    if not self:_radioCanOperate(dd) then return end
    if not self:_radioSupportsMedia(dd) then return end

    self.__radioSource = self.__radioSource or "radio"
    self.__radioCdMutedByPause = self.__radioCdMutedByPause or false
    self.__radioCdPaused = self.__radioCdPaused or false

    if self.__radioSource == "radio" then
        -- radio -> cd
        self.__radioSource = "cd"
        self:_ydBroadcastRadioSource("cd")
        self.__radioCdPaused = false

        -- Only start CD (and show loading) if a disc exists and isn't already playing
        if dd.hasMedia and dd:hasMedia() then
            local playing = (dd.isPlayingMedia and dd:isPlayingMedia() == true)
            if not playing then
                -- Silence during spin-up/loading; restore after play starts
                if not self.__radioCdMutedByPause then
                    self.__radioCdPrevVol = (dd.getDeviceVolume and dd:getDeviceVolume()) or 0
                    self.__radioCdMutedByPause = true
                end
                local restoreVal = self.__radioCdPrevVol
                if restoreVal == nil then restoreVal = 0.5 end

                if dd.setDeviceVolume then dd:setDeviceVolume(0) end
                if dd.updateSimple then pcall(function() dd:updateSimple() end) end

                self:_radioBeginLoading(true, nil, false, true, restoreVal)
                ISTimedActionQueue.add(ISRadioAction:new("TogglePlayMedia", self.character, part))
            end
        end

    else
        -- cd -> radio
        self.__radioSource = "radio"
        self:_ydBroadcastRadioSource("radio")


        local playing = (dd.isPlayingMedia and dd:isPlayingMedia() == true)
        local queuedStop = false

        -- If CD is currently playing, stop it with timed action + Loading...
        if (dd.hasMedia and dd:hasMedia()) and playing then
            local restoreVal = (dd.getDeviceVolume and dd:getDeviceVolume()) or 0.5

            -- Silence during the stop-delay; restore after stop completes (unless radio is muted)
            if self.__radioMuted == true then
                self.__radioPrevVol = restoreVal
                if dd.setDeviceVolume then dd:setDeviceVolume(0) end
                if dd.updateSimple then pcall(function() dd:updateSimple() end) end
                self:_radioBeginLoading(false, nil, nil, false)
            else
                if dd.setDeviceVolume then dd:setDeviceVolume(0) end
                if dd.updateSimple then pcall(function() dd:updateSimple() end) end
                self:_radioBeginLoading(false, nil, nil, true, restoreVal)
            end

            ISTimedActionQueue.add(ISRadioAction:new("TogglePlayMedia", self.character, part))
            queuedStop = true
        end

        -- If we were volume-forced to 0 by CD paused/loading, and we didn't queue a stop,
        -- restore volume immediately for radio (unless muted).
        if (not queuedStop) and self.__radioCdMutedByPause == true then
            local restore = self.__radioCdPrevVol
            if restore == nil then restore = 0.5 end

            if self.__radioMuted == true then
                self.__radioPrevVol = restore
                if dd.setDeviceVolume then dd:setDeviceVolume(0) end
            else
                if dd.setDeviceVolume then dd:setDeviceVolume(restore) end
            end
            if dd.updateSimple then pcall(function() dd:updateSimple() end) end

            self.__radioCdMutedByPause = false
        end
    end
end



function ISVehicleDashboard:_radioAddMediaAux(item)
    if not item or not self.character then return end
    local part = self:_getVehicleRadioPart()
    if not part then return end
    local dd = part:getDeviceData()
    if not dd then return end
    if item.getWorldItem and item:getWorldItem() and luautils and luautils.walkAdj then
        local square = item:getWorldItem():getSquare()
        if square and not luautils.walkAdj(self.character, square, true) then return end
    end

    if ISInventoryPaneContextMenu and ISInventoryPaneContextMenu.transferIfNeeded then
        pcall(function() ISInventoryPaneContextMenu.transferIfNeeded(self.character, item) end)
    end

    if item.getDisplayName then
        self.__radioMediaNameCache = item:getDisplayName()
    end

    self.__radioSource = "cd"
    self:_ydBroadcastRadioSource("cd")
    self.__radioCdPaused = false
    ISTimedActionQueue.add(YourDashVehicleRadioMediaAction:new(self.character, part, false, item))
end


function ISVehicleDashboard:_radioRemoveMedia()
    if not self.character then return end
    local part = self:_getVehicleRadioPart()
    if not part then return end
    local dd = part:getDeviceData()
    if not dd then return end

    self.__radioMediaNameCache = nil
    ISTimedActionQueue.add(YourDashVehicleRadioMediaAction:new(self.character, part, true, nil))

    self.__radioSource = "radio"
    self:_ydBroadcastRadioSource("radio")
    self.__radioCdPaused = false
end


function ISVehicleDashboard:onClickRadioLoadDisk()
    self:_radioStopTuneScan(false)
    self:_radioDisarmSet()

    if not self.vehicle or not self.character then return end
    local part = self:_getVehicleRadioPart()
    if not part then return end
    local dd = part:getDeviceData()
    if not dd then return end
    if not self:_radioSupportsMedia(dd) then return end

    local inv = self.character:getInventory()
    local wantType = dd.getMediaType and dd:getMediaType() or nil
    local medias = collectMediaItemsFromInventory(inv, wantType)

    local playerNum = self.character:getPlayerNum()
    local anchor = self.radioLoadDiskBtn or self.radioBG
    local x = anchor and anchor.getAbsoluteX and anchor:getAbsoluteX() or 0
    local y = anchor and anchor.getAbsoluteY and anchor:getAbsoluteY() or 0
    local context = ISContextMenu.get(playerNum, x, y)

    if dd.hasMedia and dd:hasMedia() then
        context:addOption(getText("IGUI_media_removeMedia") or "Remove CD", self, ISVehicleDashboard._radioRemoveMedia)
    end

    for _, item in ipairs(medias) do
        context:addOption(item:getDisplayName(), self, ISVehicleDashboard._radioAddMediaAux, item)
    end

    context.mouseOver = 1
    if JoypadState.players[playerNum + 1] then
        context.origin = JoypadState.players[playerNum + 1].focus
        setJoypadFocus(playerNum, context)
    end
end

function ISVehicleDashboard:onClickRadioPause()
    self:_radioStopTuneScan(false)
    self:_radioDisarmSet()

    if not self.vehicle or not self.character then return end
    local part = self:_getVehicleRadioPart()
    if not part then return end
    local dd = part:getDeviceData()
    if not self:_radioCanOperate(dd) then return end

    self.__radioSource = self.__radioSource or "radio"
    self.__radioCdPaused = self.__radioCdPaused or false
    self.__radioCdMutedByPause = self.__radioCdMutedByPause or false

    -- =========================
    -- CD source: pause/play media (timed action + Loading..., keep silent)
    -- =========================
    if self.__radioSource == "cd" and self:_radioSupportsMedia(dd) then
        if self.__radioLoading == true then return end
        if not (dd.hasMedia and dd:hasMedia()) then return end

        local playing = (dd.isPlayingMedia and dd:isPlayingMedia() == true)
        if self.__radioCdPaused == true then playing = false end

        if playing then
            -- PAUSE request: mute immediately; show Loading... until isPlayingMedia() becomes false
            if not self.__radioCdMutedByPause then
                self.__radioCdPrevVol = (dd.getDeviceVolume and dd:getDeviceVolume()) or 0
                self.__radioCdMutedByPause = true
            end
            if dd.setDeviceVolume then dd:setDeviceVolume(0) end
            if dd.updateSimple then pcall(function() dd:updateSimple() end) end

            self:_radioBeginLoading(false, nil, true) -- targetPlaying=false, cdPausedAfter=true
            ISTimedActionQueue.add(ISRadioAction:new("TogglePlayMedia", self.character, part))
        else
            -- PLAY request: mute during load; restore volume only after isPlayingMedia() becomes true
            if not self.__radioCdMutedByPause then
                self.__radioCdPrevVol = (dd.getDeviceVolume and dd:getDeviceVolume()) or 0
                self.__radioCdMutedByPause = true
            end
            local restoreVal = self.__radioCdPrevVol
            if restoreVal == nil then restoreVal = 0.5 end

            if dd.setDeviceVolume then dd:setDeviceVolume(0) end
            if dd.updateSimple then pcall(function() dd:updateSimple() end) end

            self:_radioBeginLoading(true, nil, false, true, restoreVal) -- restore vol when playing=true
            ISTimedActionQueue.add(ISRadioAction:new("TogglePlayMedia", self.character, part))
        end
        return
    end


    -- =========================
    -- RADIO source: mute/unmute (your existing behavior)
    -- =========================
    if self.__radioMuted ~= true then
        local v = (dd.getDeviceVolume and dd:getDeviceVolume()) or 0
        self.__radioPrevVol = v
        self.__radioMuted = true
        if dd.setDeviceVolume then dd:setDeviceVolume(0) end
        if dd.updateSimple then dd:updateSimple() end
    else
        local restore = self.__radioPrevVol
        if restore == nil then restore = 0.5 end
        self.__radioMuted = false
        self.__radioPrevVol = nil
        if dd.setDeviceVolume then dd:setDeviceVolume(restore) end
        if dd.updateSimple then dd:updateSimple() end
    end
end



-- =========================
-- Build UI
-- =========================
function ISVehicleDashboard:_ensureRadioControls()
    local wantScale = ydScale()

    -- Rebuild/retarget textures if pack changed
    if self.__radioControlsReady and (self.__radioPackScale == wantScale) then
        return
    end
    self.__radioControlsReady = true
    self.__radioPackScale = wantScale


    self.__radio_bg_off   = ydRadioTex("radio_background_off.png")
    self.__radio_bg_on    = ydRadioTex("radio_background_on.png") or self.__radio_bg_off

    self.__radio_pwr_btn  = ydRadioTex("radio_power_btn.png")
    self.__radio_vol_up   = ydRadioTex("radio_vol_up.png")
    self.__radio_vol_down = ydRadioTex("radio_vol_down.png")
    self.__radio_tune_btn = ydRadioTex("radio_tune_btn.png")
    self.__radio_set_btn  = ydRadioTex("radio_set_btn.png")
    self.__radio_freq_up   = ydRadioTex("radio_freq_up.png")
    self.__radio_freq_down = ydRadioTex("radio_freq_down.png")
    self.__radio_src_btn   = ydRadioTex("radio_src.png")
    self.__radio_load_btn  = ydRadioTex("radio_load_disk.png")
    self.__radio_pause_btn = ydRadioTex("radio_pause.png")


    self.__radio_chan = {
        ydRadioTex("radio_chan_1.png"),
        ydRadioTex("radio_chan_2.png"),
        ydRadioTex("radio_chan_3.png"),
        ydRadioTex("radio_chan_4.png"),
        ydRadioTex("radio_chan_5.png"),
        ydRadioTex("radio_chan_6.png"),
    }

    -- If UI already exists, update textures + sizes to match the selected pack
    if self.radioBG and self.__radio_bg_off then
        setImageTextureAndSize(self, self.radioBG, self.__radio_bg_off)
    end

    if self.radioPowerBtn and self.__radio_pwr_btn then setImageTextureAndSize(self, self.radioPowerBtn, self.__radio_pwr_btn) end
    if self.radioVolUpBtn and self.__radio_vol_up then setImageTextureAndSize(self, self.radioVolUpBtn, self.__radio_vol_up) end
    if self.radioVolDownBtn and self.__radio_vol_down then setImageTextureAndSize(self, self.radioVolDownBtn, self.__radio_vol_down) end
    if self.radioTuneBtn and self.__radio_tune_btn then setImageTextureAndSize(self, self.radioTuneBtn, self.__radio_tune_btn) end
    if self.radioSetBtn and self.__radio_set_btn then setImageTextureAndSize(self, self.radioSetBtn, self.__radio_set_btn) end
    if self.radioSrcBtn and self.__radio_src_btn then setImageTextureAndSize(self, self.radioSrcBtn, self.__radio_src_btn) end
    if self.radioLoadDiskBtn and self.__radio_load_btn then setImageTextureAndSize(self, self.radioLoadDiskBtn, self.__radio_load_btn) end
    if self.radioPauseBtn and self.__radio_pause_btn then setImageTextureAndSize(self, self.radioPauseBtn, self.__radio_pause_btn) end
    if self.radioFreqUpBtn and self.__radio_freq_up then setImageTextureAndSize(self, self.radioFreqUpBtn, self.__radio_freq_up) end
    if self.radioFreqDownBtn and self.__radio_freq_down then setImageTextureAndSize(self, self.radioFreqDownBtn, self.__radio_freq_down) end

    if self.radioChanBtn and self.__radio_chan then
        for i = 1, 6 do
            if self.radioChanBtn[i] and self.__radio_chan[i] then
                setImageTextureAndSize(self, self.radioChanBtn[i], self.__radio_chan[i])
            end
        end
    end

    if self.__radio_bg_off and not self.radioBG then
        self.radioBG = ISImage:new(0, 0,
            self.__radio_bg_off:getWidthOrig(),
            self.__radio_bg_off:getHeightOrig(),
            self.__radio_bg_off
        )
        self.radioBG:initialise()
        self.radioBG:instantiate()
        self.radioBG.target = self
        self.radioBG.backgroundColor = { r=0, g=0, b=0, a=0 }
        self.radioBG.alpha = 1

        function self.radioBG:render()
            if not self.texture then return end
            self:drawTextureScaled(self.texture, 0, 0, self.width, self.height, self.alpha or 1)

            local dash = self.target
            if not dash then return end

            local scale = dash.__radioPackScale or ydScale()
            local font = ydUIFont()
            local mainZoom = premiumMainTextZoom(dash, scale, font)
            local left  = dash.__radioTextLeft  or ""
            local mid   = dash.__radioTextMid   or ""
            local right = dash.__radioTextRight or ""
            local armed = dash.__radioSetArmed == true
            local geometry = premiumLCDGeometry(dash, self.width, scale, font, left, right)
            local fullGeometry = premiumLCDGeometry(dash, self.width, scale, font, "", "")
            local rgb  = dash.RADIO_TEXT_RGB  or { r=1, g=1, b=1 }
            local a    = dash.RADIO_TEXT_A    or 0.95

            local NAME_X = ydScaled(dash.RADIO_TEXT_NAME_X or 0, scale)
            local NAME_Y = ydScaled(dash.RADIO_TEXT_NAME_Y or 0, scale)

            local ARMX   = ydScaled(dash.RADIO_TEXT_ARMED_X or 0, scale)
            local ARMY   = ydScaled(dash.RADIO_TEXT_ARMED_Y or 0, scale)

            local CLIP_X, CLIP_Y = geometry.clipX, geometry.clipY
            local CLIP_W, CLIP_H = geometry.clipW, geometry.clipH
            local canStencil = (self.setStencilRect ~= nil) and (self.clearStencilRect ~= nil)

            local function drawSideReadout(spec)
                if not spec then return end
                if spec.number ~= "" then
                    local x = math.floor(spec.centerX - spec.numberWidth * spec.numberZoom * 0.5 + 0.5)
                    if self.drawTextZoomed then
                        self:drawTextZoomed(spec.number, x, spec.numberY, spec.numberZoom,
                            rgb.r, rgb.g, rgb.b, a, spec.numberFont)
                    else
                        self:drawTextCentre(spec.number, spec.centerX, spec.numberY,
                            rgb.r, rgb.g, rgb.b, a, spec.numberFont)
                    end
                end
            end

            if dash.__radioLoading == true then
                local msg  = dash.RADIO_LOADING_TEXT or "Loading..."
                if canStencil then
                    self:setStencilRect(fullGeometry.lcdX, fullGeometry.lcdY,
                        fullGeometry.lcdW, fullGeometry.lcdH)
                end
                drawPremiumCenteredText(
                    self,
                    msg,
                    fullGeometry.lcdX + fullGeometry.lcdW * 0.5 + (NAME_X or 0),
                    (NAME_Y or 0),
                    mainZoom, rgb.r, rgb.g, rgb.b, a, font
                )
                if canStencil then self:clearStencilRect() end
                return
            end

            -- Side readouts share one LCD stencil so even an
            -- unexpected frequency value cannot draw onto the bezel.
            if (left ~= "" or right ~= "") and canStencil then
                self:setStencilRect(fullGeometry.lcdX, fullGeometry.lcdY,
                    fullGeometry.lcdW, fullGeometry.lcdH)
            end
            drawSideReadout(geometry.leftSide)
            drawSideReadout(geometry.rightSide)
            if (left ~= "" or right ~= "") and canStencil then self:clearStencilRect() end

            -- CENTER: channel name OR armed message
            if armed then
                if mid ~= "" then
                    if canStencil then
                        self:setStencilRect(fullGeometry.lcdX, fullGeometry.lcdY,
                            fullGeometry.lcdW, fullGeometry.lcdH)
                    end
                    drawPremiumCenteredText(
                        self,
                        mid,
                        fullGeometry.lcdX + fullGeometry.lcdW * 0.5 + (ARMX or 0),
                        (ARMY or 0),
                        mainZoom, rgb.r, rgb.g, rgb.b, a, font
                    )
                    if canStencil then self:clearStencilRect() end
                end
            else
                if mid ~= "" then
                    if dash.__radioMarqueeText == mid then
                        -- Marquee mode (left-anchored inside clip box)
                        local gap = ydScaled(dash.RADIO_TEXT_MARQUEE_GAP_PX or 20, scale)
                        local off = dash.__radioMarqueeOffset or 0
                        local textZoom = self.drawTextZoomed and mainZoom or 1
                        local tw  = dash.__radioMarqueeW or (measureTextX(font, mid) * textZoom)

                        if canStencil then self:setStencilRect(CLIP_X, CLIP_Y, CLIP_W, CLIP_H) end

                        local y  = (NAME_Y or 0)
                        local x1 = (CLIP_X - off) + (NAME_X or 0)
                        if self.drawTextZoomed then
                            self:drawTextZoomed(mid, x1, y, mainZoom, rgb.r, rgb.g, rgb.b, a, font)
                            self:drawTextZoomed(mid, x1 + tw + gap, y, mainZoom, rgb.r, rgb.g, rgb.b, a, font)
                        else
                            self:drawText(mid, x1, y, rgb.r, rgb.g, rgb.b, a, font)
                            self:drawText(mid, x1 + tw + gap, y, rgb.r, rgb.g, rgb.b, a, font)
                        end

                        if canStencil then self:clearStencilRect() end
                    else
                        -- Normal mode (centered), clipped
                        if canStencil then self:setStencilRect(CLIP_X, CLIP_Y, CLIP_W, CLIP_H) end

                        drawPremiumCenteredText(
                            self,
                            mid,
                            (CLIP_X + CLIP_W * 0.5) + (NAME_X or 0),
                            (NAME_Y or 0),
                            mainZoom, rgb.r, rgb.g, rgb.b, a, font
                        )

                        if canStencil then self:clearStencilRect() end
                    end
                end
            end
        end

        self:addChild(self.radioBG)
    end


    local function makeBtn(fieldName, tex, onclickFn)
        if not tex then return end
        if self[fieldName] then return end

        local img = ISImage:new(0, 0, tex:getWidthOrig(), tex:getHeightOrig(), tex)
        img:initialise()
        img:instantiate()
        img.target = self
        img.__handler = onclickFn
        img.onclick = onclickFn
        img.backgroundColor = { r=0, g=0, b=0, a=0 }
        img.alpha = 1
        self:addChild(img)
        self[fieldName] = img

        if self._installPressedEffect then
            self:_installPressedEffect(img, 0.98)
        else
            installPressedEffectFallback(img, 0.98)
        end
    end

    makeBtn("radioPowerBtn",   self.__radio_pwr_btn,  ISVehicleDashboard.onClickRadioPowerBasic)
    makeBtn("radioVolUpBtn",   self.__radio_vol_up,   ISVehicleDashboard.onClickRadioVolUp)
    makeBtn("radioVolDownBtn", self.__radio_vol_down, ISVehicleDashboard.onClickRadioVolDown)
    makeBtn("radioTuneBtn",    self.__radio_tune_btn, ISVehicleDashboard.onClickRadioTune)
    makeBtn("radioSetBtn",     self.__radio_set_btn,  ISVehicleDashboard.onClickRadioSet)
    makeBtn("radioSrcBtn",      self.__radio_src_btn,   ISVehicleDashboard.onClickRadioSrc)
    makeBtn("radioLoadDiskBtn", self.__radio_load_btn,  ISVehicleDashboard.onClickRadioLoadDisk)
    makeBtn("radioPauseBtn",    self.__radio_pause_btn, ISVehicleDashboard.onClickRadioPause)


    self.radioChanBtn = self.radioChanBtn or {}
    for i = 1, 6 do
        if self.__radio_chan[i] and not self.radioChanBtn[i] then
            local fn =
                (i == 1 and ISVehicleDashboard.onClickRadioChan1) or
                (i == 2 and ISVehicleDashboard.onClickRadioChan2) or
                (i == 3 and ISVehicleDashboard.onClickRadioChan3) or
                (i == 4 and ISVehicleDashboard.onClickRadioChan4) or
                (i == 5 and ISVehicleDashboard.onClickRadioChan5) or
                (i == 6 and ISVehicleDashboard.onClickRadioChan6)

            local img = ISImage:new(0, 0,
                self.__radio_chan[i]:getWidthOrig(),
                self.__radio_chan[i]:getHeightOrig(),
                self.__radio_chan[i]
            )
            img:initialise()
            img:instantiate()
            img.target = self
            img.__handler = fn
            img.onclick = fn
            img.backgroundColor = { r=0, g=0, b=0, a=0 }
            img.alpha = 1
            self:addChild(img)
            self.radioChanBtn[i] = img

            if self._installPressedEffect then
                self:_installPressedEffect(img, 0.98)
            else
                installPressedEffectFallback(img, 0.98)
            end
        end
    end

    local function makeHoldBtn(fieldName, tex, dir)
        if not tex then return end
        if self[fieldName] then return end

        local img = ISImage:new(0, 0, tex:getWidthOrig(), tex:getHeightOrig(), tex)
        img:initialise()
        img:instantiate()
        img.target = self
        img.backgroundColor = { r=0, g=0, b=0, a=0 }
        img.alpha = 1

        function img:onMouseDown(x, y)
            local dash = self.target
            if not dash or self.__disabled then return false end
            dash:_radioBeginFreqHold(dir)
            self:setCapture(true)
            return true
        end

        local function endHold(selfBtn)
            local dash = selfBtn.target
            if dash then dash:_radioStopFreqHold() end
            selfBtn:setCapture(false)
            return true
        end

        function img:onMouseUp(x, y) return endHold(self) end
        function img:onMouseUpOutside(x, y) return endHold(self) end

        self:addChild(img)
        self[fieldName] = img

        if self._installPressedEffect then
            self:_installPressedEffect(img, 0.98)
        else
            installPressedEffectFallback(img, 0.98)
        end
    end

    makeHoldBtn("radioFreqUpBtn",   self.__radio_freq_up,   1)
    makeHoldBtn("radioFreqDownBtn", self.__radio_freq_down, -1)
end

-- =========================
-- Position UI
-- =========================
function ISVehicleDashboard:_positionRadioControls()
    if not self.backgroundTex then return end
    self:_ensureRadioControls()
    if not self.radioBG then return end

    local scale = self.__radioPackScale or ydScale()
    local UI_X, UI_Y = ydRadioAnchor(
        self,
        "radioPremium",
        self.RADIO_UI_X or 531,
        self.RADIO_UI_Y or 60,
        scale
    )

    local bx = self.backgroundTex:getX() + UI_X
    local by = self.backgroundTex:getY() + UI_Y


    self.radioBG:setX(bx)
    self.radioBG:setY(by)

    local function place(img, ox, oy)
        if not img then return end
        img:setX(bx + ydScaled(ox or 0, scale))
        img:setY(by + ydScaled(oy or 0, scale))
    end

    place(self.radioPowerBtn,    self.RADIO_POWER_OFF_X,    self.RADIO_POWER_OFF_Y)
    place(self.radioVolDownBtn,  self.RADIO_VOL_DOWN_OFF_X, self.RADIO_VOL_DOWN_OFF_Y)
    place(self.radioVolUpBtn,    self.RADIO_VOL_UP_OFF_X,   self.RADIO_VOL_UP_OFF_Y)
    place(self.radioTuneBtn,     self.RADIO_TUNE_OFF_X,     self.RADIO_TUNE_OFF_Y)
    place(self.radioSetBtn,      self.RADIO_SET_OFF_X,      self.RADIO_SET_OFF_Y)
    place(self.radioFreqUpBtn,   self.RADIO_FREQ_UP_OFF_X,  self.RADIO_FREQ_UP_OFF_Y)
    place(self.radioFreqDownBtn, self.RADIO_FREQ_DOWN_OFF_X,self.RADIO_FREQ_DOWN_OFF_Y)
    place(self.radioSrcBtn,      self.RADIO_SRC_OFF_X,      self.RADIO_SRC_OFF_Y)
    place(self.radioLoadDiskBtn, self.RADIO_LOAD_OFF_X,     self.RADIO_LOAD_OFF_Y)
    place(self.radioPauseBtn,    self.RADIO_PAUSE_OFF_X,    self.RADIO_PAUSE_OFF_Y)

    if self.radioChanBtn then
        for i = 1, 6 do
            local img = self.radioChanBtn[i]
            if img then
                place(img, self.RADIO_CHAN_OFF_X[i], self.RADIO_CHAN_OFF_Y[i])
            end
        end
    end

    if self._YourDashBringPremiumRadioAboveGlass then
        self:_YourDashBringPremiumRadioAboveGlass()
    end

end

-- =========================
-- Update each frame
-- =========================
function ISVehicleDashboard:_updateRadioControls()
    self:_ensureRadioControls()

    -- Hide vanilla radio icon (prevents opening ISRadioWindow)
    if self.radioTex then
        self.radioTex:setVisible(false)
        self.radioTex.onclick = nil
        self.radioTex.__disabled = true
        self.radioTex.mouseovertext = nil
        self.radioTex.backgroundColor = { r=0, g=0, b=0, a=0 }
    end

    local part = self:_getVehicleRadioPart()
    local hasRadio = part ~= nil

    if self.radioBG then self.radioBG:setVisible(hasRadio) end
    if self.radioPowerBtn then self.radioPowerBtn:setVisible(hasRadio) end
    if self.radioVolUpBtn then self.radioVolUpBtn:setVisible(hasRadio) end
    if self.radioVolDownBtn then self.radioVolDownBtn:setVisible(hasRadio) end
    if self.radioTuneBtn then self.radioTuneBtn:setVisible(hasRadio) end
    if self.radioSetBtn then self.radioSetBtn:setVisible(hasRadio) end
    if self.radioFreqUpBtn then self.radioFreqUpBtn:setVisible(hasRadio) end
    if self.radioFreqDownBtn then self.radioFreqDownBtn:setVisible(hasRadio) end
    if self.radioSrcBtn then self.radioSrcBtn:setVisible(hasRadio) end
    if self.radioLoadDiskBtn then self.radioLoadDiskBtn:setVisible(hasRadio) end
    if self.radioPauseBtn then self.radioPauseBtn:setVisible(hasRadio) end

    if self.radioChanBtn then
        for i = 1, 6 do
            if self.radioChanBtn[i] then self.radioChanBtn[i]:setVisible(hasRadio) end
        end
    end

    if not hasRadio then
        self.__radioSetArmed = false
        self:_radioStopFreqHold()
        self:_radioStopTuneScan(false)
        return
    end

    local dd = part:getDeviceData()
    if not dd then
        self.__radioSetArmed = false
        self:_radioStopFreqHold()
        self:_radioStopTuneScan(false)
        return
    end
    local spPaused = _ydIsPausedSP()
    -- SP: block fast-forward while SEEK is active (pause is allowed)
    if self.__radioTuneScanActive == true then
        _ydForceNormalSpeedIfSP() -- only forces when speed > 1, and only in SP (not isClient)
    end


    local dtUI = UIManager.getSecondsSinceLastRender()
    if not dtUI or dtUI <= 0 then dtUI = 1/30 end
    self:_radioUpdateLoading(dd, dtUI)


    -- Always keep preset list padded (policy)
    self:_radioEnsurePresetList6(dd)

    local isOn = (dd.getIsTurnedOn and dd:getIsTurnedOn()) == true

    local canToggle = false
    if dd.getIsBatteryPowered and dd.getPower and dd:getIsBatteryPowered() then
        canToggle = (dd:getPower() > 0)
    end
    if (not canToggle) and dd.canBePoweredHere then
        canToggle = (dd:canBePoweredHere() == true)
    end

    -- Background swap
    if self.radioBG and self.__radio_bg_off then
        local want = isOn and (self.__radio_bg_on or self.__radio_bg_off) or self.__radio_bg_off
        if self.radioBG.texture ~= want then
            setImageTextureAndSize(self, self.radioBG, want)
        end
    end

    if not isOn then
        self.__radioSetArmed = false
        self:_radioStopFreqHold()
        self:_radioStopTuneScan(false)
    end

    local canOperate = self:_radioCanOperate(dd)

    self.__radioSource = self.__radioSource or "radio"
    self.__radioNoMarquee = false

    local supportsMedia = self:_radioSupportsMedia(dd)

    local sharedSource = self:_ydGetSharedRadioSource()
    if sharedSource and sharedSource ~= self.__radioSource then
        self.__radioSource = sharedSource

        -- if we’re being forced to radio by another player, drop CD-only local flags
        if sharedSource == "radio" then
            self.__radioCdPaused = false
            self.__radioCdMutedByPause = false
        end
    end

    -- =========================================================
    -- CD source safety: if NO DISC or disc is NOT playing (ended/paused),
    -- keep the device silent so it doesn't fall back to radio audio.
    -- Also auto-clear cdPaused when playback resumes.
    -- =========================================================
    if canOperate and supportsMedia and (self.__radioSource == "cd") then
        local hasDisc = (dd.hasMedia and dd:hasMedia()) == true
        local playing = hasDisc and (dd.isPlayingMedia and dd:isPlayingMedia() == true)

        if playing then
            -- If playback is actually running, CD isn't paused anymore.
            self.__radioCdPaused = false

            -- If we were silencing due to NO DISC / finished / paused, restore volume now
            -- (unless Loading is handling restore for us).
            if self.__radioCdMutedByPause == true and self.__radioLoading ~= true then
                local restore = self.__radioCdPrevVol
                if restore == nil then restore = 0.5 end
                if dd.setDeviceVolume then dd:setDeviceVolume(restore) end
                if dd.updateSimple then pcall(function() dd:updateSimple() end) end
                self.__radioCdMutedByPause = false
            end
        else
            -- Not playing (NO DISC or finished/paused): force silence
            if self.__radioLoading ~= true then
                if self.__radioCdMutedByPause ~= true then
                    self.__radioCdPrevVol = (dd.getDeviceVolume and dd:getDeviceVolume()) or 0
                    self.__radioCdMutedByPause = true
                end

                -- Treat as paused-ish so your display logic stays consistent
                self.__radioCdPaused = true

                if dd.setDeviceVolume then dd:setDeviceVolume(0) end
                if dd.updateSimple then pcall(function() dd:updateSimple() end) end
            end
        end
    end

    -- =========================
    -- Vanilla UI sync: detect ISRadioAction("TogglePlayMedia") running on this radio
    -- so the dash follows vanilla Play/Pause CD.
    -- =========================
    if self.__radioLoading ~= true and self.character and supportsMedia then
        local q = ISTimedActionQueue.getTimedActionQueue(self.character)
        if q and q.indexOfType and q.queue then
            local idx = q:indexOfType("ISRadioAction")
            if idx == 1 then
                local act = q.queue[idx]
                if act and act.mode == "TogglePlayMedia" and act.device == part then
                    local playing = (dd.isPlayingMedia and dd:isPlayingMedia() == true)
                    local targetPlaying = (not playing)

                    -- If vanilla is starting CD, force CD screen immediately (shows Loading...)
                    if targetPlaying == true then
                        self.__radioSource = "cd"
                    end

                    local restoreAfter = (targetPlaying == true) and (self.__radioCdMutedByPause == true)
                    local restoreVal = self.__radioCdPrevVol
                    if restoreVal == nil then restoreVal = 0.5 end

                    self:_radioBeginLoading(
                        targetPlaying,
                        nil,
                        (targetPlaying == false),   -- cdPausedAfter when stopping
                        restoreAfter,
                        restoreVal
                    )
                end
            end
        end
    end

    -- If CD is already playing (e.g. started elsewhere), show CD screen,
    -- BUT don't fight the user's SRC cd->radio transition while we're loading a stop.
    do
        local cdPlaying = supportsMedia and dd.isPlayingMedia and dd:isPlayingMedia() == true
        if cdPlaying then
            self.__radioCdPaused = false

        local shared = self:_ydGetSharedRadioSource()
        local switchingToRadio =
            (shared == "radio") or
            ((self.__radioLoading == true)
                and (self.__radioLoadingExpectedSource == "radio")
                and (self.__radioLoadingTargetPlaying == false))


            if not switchingToRadio then
                self.__radioSource = "cd"
            end
        end
    end


    -- If media is actually playing, reflect that in source (keeps UI consistent)
    if supportsMedia and dd.isPlayingMedia and dd:isPlayingMedia() == true then
        if self.__radioSource == "cd" then
            self.__radioSource = "cd"
        end
    end
    -- If user is in CD source but device doesn't support media, fall back.
    if self.__radioSource == "cd" and not supportsMedia then
        self.__radioSource = "radio"
    end



    -- Build overlay strings (used by radioBG:render)
    self.__radioTextLeft  = ""
    self.__radioTextMid   = ""
    self.__radioTextRight = ""

    local curF = dd.getChannel and dd:getChannel() or nil
    local displayScale = self.__radioPackScale or ydScale()
    local smallestDisplay = displayScale == 0.75

    -- defaults
    self.__radioTextLeft  = ""
    self.__radioTextRight = ""
    self.__radioTextMid   = ""

    if canOperate then
        if self.__radioSetArmed == true then
            -- Armed: only show the save message (hide VOL + FREQ)
            self.__radioTextMid = string.format("Save %s to?", self:_radioFmtMHz(curF))
            self.__radioTextLeft = ""
            self.__radioTextRight = ""
        else
            -- Left: volume (works for both sources)
            local v = (dd.getDeviceVolume and dd:getDeviceVolume()) or 0
            local v10 = math.floor(clamp(v or 0, 0, 1) * 10 + 0.5)
            self.__radioTextLeft = "VOL " .. tostring(v10)

            if self.__radioSource == "cd" and supportsMedia then
                -- CD source
                self.__radioTextRight = "CD"   -- show at the freq location

                if dd.hasMedia and dd:hasMedia() then
                    local cdPlaying = (dd.isPlayingMedia and dd:isPlayingMedia() == true)
                    if self.__radioCdPaused == true then cdPlaying = false end

                    if cdPlaying then
                        self.__radioTextMid = self:_radioGetLoadedMediaName(dd) or "DISC"
                    else
                        self.__radioTextMid = smallestDisplay and "PAUSED" or "CD PAUSED"
                        self.__radioNoMarquee = true
                    end
                else
                    self.__radioTextMid = smallestDisplay and "NODISC" or "NO DISC"
                    self.__radioNoMarquee = true
                end
            else
                -- RADIO source
                self.__radioTextRight = self:_radioFmtMHz(curF)

                if self.__radioMuted == true then
                    self.__radioTextMid = "MUTED"
                    self.__radioNoMarquee = true
                else
                    if self:_radioIsReceiving(dd) then
                        self.__radioTextMid = self:_radioGetCurrentName(dd) or ""
                    else
                        self.__radioTextMid = ""
                    end
                end
            end
        end
    end

    -- =========================
    -- Marquee state (channel name only, not SET-armed message)
    -- =========================
    do
        local mid = self.__radioTextMid or ""
        local armed = (self.__radioSetArmed == true)
        local forceNoMarquee = (self.__radioNoMarquee == true)

        if armed or forceNoMarquee or mid == "" then
            self.__radioMarqueeText   = nil
            self.__radioMarqueeOffset = 0
            self.__radioMarqueeDelayT = 0
            self.__radioMarqueeW      = 0
        else
            local scale = self.__radioPackScale or ydScale()
            local font = ydUIFont()
            local textZoom = (self.radioBG and self.radioBG.drawTextZoomed) and premiumMainTextZoom(self, scale, font) or 1
            local radioWidth = self.radioBG and self.radioBG:getWidth() or ydScaled(196, scale)
            local geometry = premiumLCDGeometry(self, radioWidth, scale, font,
                self.__radioTextLeft or "", self.__radioTextRight or "")
            local clipW = geometry.clipW
            local w = measureTextX(font, mid) * textZoom


            if w > clipW then
                if self.__radioMarqueeText ~= mid then
                    self.__radioMarqueeText   = mid
                    self.__radioMarqueeOffset = 0
                    self.__radioMarqueeDelayT = 0
                    self.__radioMarqueeW      = w
                end

                local dtm = UIManager.getSecondsSinceLastRender()
                if not dtm or dtm <= 0 then dtm = 1/30 end

                local delay = self.RADIO_TEXT_MARQUEE_DELAY_S or 0.8
                self.__radioMarqueeDelayT = (self.__radioMarqueeDelayT or 0) + dtm

                if (self.__radioMarqueeDelayT or 0) >= delay then
                    local speed = ydScaled(self.RADIO_TEXT_MARQUEE_SPEED_PX_S or 15, scale)
                    local gap   = ydScaled(self.RADIO_TEXT_MARQUEE_GAP_PX or 20, scale)

                    self.__radioMarqueeOffset = (self.__radioMarqueeOffset or 0) + speed * dtm

                    local loopLen = (self.__radioMarqueeW or w) + gap
                    if (self.__radioMarqueeOffset or 0) > loopLen then
                        self.__radioMarqueeOffset = 0
                        self.__radioMarqueeDelayT = 0 -- pause again at the start
                    end
                end
            else
                -- Fits: no marquee
                self.__radioMarqueeText   = nil
                self.__radioMarqueeOffset = 0
                self.__radioMarqueeDelayT = 0
                self.__radioMarqueeW      = w
            end
        end
    end



    -- Power
    if self.radioPowerBtn then
        setEnabled(self, self.radioPowerBtn, canToggle,
            isOn and getText("ContextMenu_Turn_Off") or getText("ContextMenu_Turn_On"),
            ISVehicleDashboard.onClickRadioPowerBasic
        )
    end

    -- Volume (does NOT interrupt tune)
    if self.radioVolUpBtn then
        setEnabled(self, self.radioVolUpBtn, canOperate, getText("IGUI_RadioVolume"), ISVehicleDashboard.onClickRadioVolUp)
    end
    if self.radioVolDownBtn then
        setEnabled(self, self.radioVolDownBtn, canOperate, getText("IGUI_RadioVolume"), ISVehicleDashboard.onClickRadioVolDown)
    end

    -- Tune
    if self.radioTuneBtn then
        local enabled = canOperate and (self.__radioSource ~= "cd")
        setEnabled(self, self.radioTuneBtn, enabled, "Seek for channel", ISVehicleDashboard.onClickRadioTune)
        self.radioTuneBtn.alpha = (self.__radioTuneScanActive == true) and 1.0 or 0.9
    end


    -- SET
    if self.radioSetBtn then
        local enabled = canOperate and (self.__radioSource ~= "cd")
        setEnabled(self, self.radioSetBtn, enabled, "Save current frequency", ISVehicleDashboard.onClickRadioSet)
        self.radioSetBtn.alpha = (self.__radioSetArmed == true) and 1.0 or 0.85
    end


    -- Channels: always use first 6 vanilla presets
    local presetList = self:_radioGetDevicePresetList(dd)
    if self.radioChanBtn then
        for i = 1, 6 do
            local img = self.radioChanBtn[i]
            if img then
                local enabled = canOperate and presetList and (i <= presetList:size())
                local tip = "CH" .. tostring(i)

                if presetList and i <= presetList:size() then
                    local p = presetList:get(i - 1)
                    local fq = p and p.getFrequency and p:getFrequency() or nil
                    local name = p and p.getName and p:getName() or nil
                    if fq then
                        if name and name ~= "" then
                            tip = string.format("CH%d: %.1f MHz  %s", i, fq / 1000, name)
                        else
                            tip = string.format("CH%d: %.1f MHz", i, fq / 1000)
                        end
                    end
                end

                setEnabled(self, img, enabled, tip, img.__handler)
                img.alpha = 1.0
            end
        end
    end

    -- Freq up/down (hold) -- disabled in CD mode
    local freqEnabled = (not spPaused) and canOperate and (self.__radioSource ~= "cd") and (self.__radioLoading ~= true)


    if self.radioFreqUpBtn then
        setEnabled(self, self.radioFreqUpBtn, freqEnabled, "Freq +", nil)
        self.radioFreqUpBtn.__disabled = not freqEnabled
    end
    if self.radioFreqDownBtn then
        setEnabled(self, self.radioFreqDownBtn, freqEnabled, "Freq -", nil)
        self.radioFreqDownBtn.__disabled = not freqEnabled
    end


    -- SRC / LOAD / PAUSE
    if self.radioSrcBtn then
        local canSrc = canOperate and supportsMedia
        setEnabled(self, self.radioSrcBtn, canSrc, "Source", ISVehicleDashboard.onClickRadioSrc)
        self.radioSrcBtn.alpha = (self.__radioSource == "cd") and 1.0 or 0.9
    end

    if self.radioLoadDiskBtn then
        local canLoad = supportsMedia and canToggle
        setEnabled(self, self.radioLoadDiskBtn, canLoad, "Load/Remove CD", ISVehicleDashboard.onClickRadioLoadDisk)
        self.radioLoadDiskBtn.alpha = (dd.hasMedia and dd:hasMedia()) and 1.0 or 0.9
    end

    if self.radioPauseBtn then
        local canPause = false
        local tip = "Mute"
        if self.__radioSource == "cd" and supportsMedia then
            canPause = canOperate and (dd.hasMedia and dd:hasMedia())
            tip = (dd.isPlayingMedia and dd:isPlayingMedia()) and "Pause" or "Play"
        else
            canPause = canOperate
            tip = (self.__radioMuted == true) and "Unmute" or "Mute"
        end
        setEnabled(self, self.radioPauseBtn, canPause, tip, ISVehicleDashboard.onClickRadioPause)
        self.radioPauseBtn.alpha = 1.0
    end


-- Per-frame timers (freeze during SP pause)
if spPaused then
    -- If pause happens mid-hold, stop it so capture can’t get stuck.
    if self.__radioFreqHoldActive then
        self:_radioStopFreqHold()
        if self.radioFreqUpBtn and self.radioFreqUpBtn.setCapture then pcall(function() self.radioFreqUpBtn:setCapture(false) end) end
        if self.radioFreqDownBtn and self.radioFreqDownBtn.setCapture then pcall(function() self.radioFreqDownBtn:setCapture(false) end) end
    end
else
    local dt = nil
    if self.__radioTuneScanActive or self.__radioFreqHoldActive then
        dt = UIManager.getSecondsSinceLastRender()
        if not dt or dt <= 0 then dt = 1/30 end
    end

    if self.__radioTuneScanActive then
        self:_radioUpdateTuneScan(dt)
    end

    if self.__radioFreqHoldActive then
        if not canOperate then
            self:_radioStopFreqHold()
        else
            self.__radioFreqHoldT = (self.__radioFreqHoldT or 0) + dt

            local delay    = self.RADIO_FREQ_HOLD_DELAY or 0.8
            local interval = self.RADIO_FREQ_REPEAT_INTERVAL or 0.12

            if self.__radioFreqHoldT >= delay then
                self.__radioFreqHoldRepT = (self.__radioFreqHoldRepT or 0) + dt
                while self.__radioFreqHoldRepT >= interval do
                    self.__radioFreqHoldRepT = self.__radioFreqHoldRepT - interval
                    self:_radioStepFrequency(self.__radioFreqHoldDir or 0, false)
                end
            end
        end
    end

    -- Auto-cancel SET after timeout (also freezes during pause)
    if self.__radioSetArmed == true then
        local dt2 = UIManager.getSecondsSinceLastRender()
        if not dt2 or dt2 <= 0 then dt2 = 1/30 end

        self.__radioSetArmedT = (self.__radioSetArmedT or 0) + dt2
        if (self.__radioSetArmedT or 0) >= (self.RADIO_SET_TIMEOUT_S or 10.0) then
            self:_radioDisarmSet()
        end
    end
end


    -- Auto-cancel SET after timeout
    if self.__radioSetArmed == true then
        local dt2 = UIManager.getSecondsSinceLastRender()
        if not dt2 or dt2 <= 0 then dt2 = 1/30 end

        self.__radioSetArmedT = (self.__radioSetArmedT or 0) + dt2
        if (self.__radioSetArmedT or 0) >= (self.RADIO_SET_TIMEOUT_S or 10.0) then
            self:_radioDisarmSet()
        end
    end

        self:_positionRadioControls()
    end

-- Dashboard lifecycle hooks are intentionally owned only by RadioRouter.
