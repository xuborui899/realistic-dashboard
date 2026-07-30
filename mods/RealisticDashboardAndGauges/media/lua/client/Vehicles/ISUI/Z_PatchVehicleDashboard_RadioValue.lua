-- media/lua/client/YourDash/Z_PatchVehicleDashboard_RadioValue.lua
if isServer() then return end

require "Vehicles/ISUI/ISVehicleDashboard"
require "ISUI/ISImage"
require "TimedActions/ISTimedActionQueue"
require "RadioCom/ISRadioAction"
require "RadioCom/RadioWindowModules/RWMPanel" -- PresetEntry.new
-- require "YourDash/Z_PatchVehicleDashboard_RadioRouter"

-- Guard: don’t patch twice
if ISVehicleDashboard.__DashRadioValuePatched then return end
ISVehicleDashboard.__DashRadioValuePatched = true

-- =========================================================
-- Config
-- =========================================================
ISVehicleDashboard.RADIO_VALUE_UI_X = ISVehicleDashboard.RADIO_VALUE_UI_X or 600
ISVehicleDashboard.RADIO_VALUE_UI_Y = ISVehicleDashboard.RADIO_VALUE_UI_Y or 55

ISVehicleDashboard.RADIO_VALUE_POWER_OFF_X = ISVehicleDashboard.RADIO_VALUE_POWER_OFF_X or 19
ISVehicleDashboard.RADIO_VALUE_POWER_OFF_Y = ISVehicleDashboard.RADIO_VALUE_POWER_OFF_Y or 19

ISVehicleDashboard.RADIO_VALUE_VOL_DOWN_OFF_X = ISVehicleDashboard.RADIO_VALUE_VOL_DOWN_OFF_X or 11
ISVehicleDashboard.RADIO_VALUE_VOL_DOWN_OFF_Y = ISVehicleDashboard.RADIO_VALUE_VOL_DOWN_OFF_Y or 36

ISVehicleDashboard.RADIO_VALUE_VOL_UP_OFF_X = ISVehicleDashboard.RADIO_VALUE_VOL_UP_OFF_X or 11
ISVehicleDashboard.RADIO_VALUE_VOL_UP_OFF_Y = ISVehicleDashboard.RADIO_VALUE_VOL_UP_OFF_Y or 3

ISVehicleDashboard.RADIO_VALUE_SET_OFF_X = ISVehicleDashboard.RADIO_VALUE_SET_OFF_X or 163
ISVehicleDashboard.RADIO_VALUE_SET_OFF_Y = ISVehicleDashboard.RADIO_VALUE_SET_OFF_Y or 38

ISVehicleDashboard.RADIO_VALUE_FREQ_UP_OFF_X = ISVehicleDashboard.RADIO_VALUE_FREQ_UP_OFF_X or 36
ISVehicleDashboard.RADIO_VALUE_FREQ_UP_OFF_Y = ISVehicleDashboard.RADIO_VALUE_FREQ_UP_OFF_Y or 11

ISVehicleDashboard.RADIO_VALUE_FREQ_DOWN_OFF_X = ISVehicleDashboard.RADIO_VALUE_FREQ_DOWN_OFF_X or 3
ISVehicleDashboard.RADIO_VALUE_FREQ_DOWN_OFF_Y = ISVehicleDashboard.RADIO_VALUE_FREQ_DOWN_OFF_Y or 11

ISVehicleDashboard.RADIO_VALUE_MUTE_OFF_X = ISVehicleDashboard.RADIO_VALUE_MUTE_OFF_X or 128
ISVehicleDashboard.RADIO_VALUE_MUTE_OFF_Y = ISVehicleDashboard.RADIO_VALUE_MUTE_OFF_Y or 38

-- Channel buttons (per-button offsets, relative to radioBG top-left)
ISVehicleDashboard.RADIO_VALUE_CH1_OFF_X = ISVehicleDashboard.RADIO_VALUE_CH1_OFF_X or 126
ISVehicleDashboard.RADIO_VALUE_CH1_OFF_Y = ISVehicleDashboard.RADIO_VALUE_CH1_OFF_Y or 9
ISVehicleDashboard.RADIO_VALUE_CH2_OFF_X = ISVehicleDashboard.RADIO_VALUE_CH2_OFF_X or 148
ISVehicleDashboard.RADIO_VALUE_CH2_OFF_Y = ISVehicleDashboard.RADIO_VALUE_CH2_OFF_Y or 9
ISVehicleDashboard.RADIO_VALUE_CH3_OFF_X = ISVehicleDashboard.RADIO_VALUE_CH3_OFF_X or 170
ISVehicleDashboard.RADIO_VALUE_CH3_OFF_Y = ISVehicleDashboard.RADIO_VALUE_CH3_OFF_Y or 9
ISVehicleDashboard.RADIO_VALUE_CH4_OFF_X = ISVehicleDashboard.RADIO_VALUE_CH4_OFF_X or 126
ISVehicleDashboard.RADIO_VALUE_CH4_OFF_Y = ISVehicleDashboard.RADIO_VALUE_CH4_OFF_Y or 23
ISVehicleDashboard.RADIO_VALUE_CH5_OFF_X = ISVehicleDashboard.RADIO_VALUE_CH5_OFF_X or 148
ISVehicleDashboard.RADIO_VALUE_CH5_OFF_Y = ISVehicleDashboard.RADIO_VALUE_CH5_OFF_Y or 23
ISVehicleDashboard.RADIO_VALUE_CH6_OFF_X = ISVehicleDashboard.RADIO_VALUE_CH6_OFF_X or 170
ISVehicleDashboard.RADIO_VALUE_CH6_OFF_Y = ISVehicleDashboard.RADIO_VALUE_CH6_OFF_Y or 23

-- Text positions (relative to radioBG local coords)
ISVehicleDashboard.RADIO_VALUE_TEXT_VOL_X = ISVehicleDashboard.RADIO_VALUE_TEXT_VOL_X or 62
ISVehicleDashboard.RADIO_VALUE_TEXT_VOL_Y = ISVehicleDashboard.RADIO_VALUE_TEXT_VOL_Y or 19
ISVehicleDashboard.RADIO_VALUE_TEXT_FREQ_X = ISVehicleDashboard.RADIO_VALUE_TEXT_FREQ_X or -76 -- negative = from right edge
ISVehicleDashboard.RADIO_VALUE_TEXT_FREQ_Y = ISVehicleDashboard.RADIO_VALUE_TEXT_FREQ_Y or 19

-- Optional "set?" center position (relative to radioBG local coords)
ISVehicleDashboard.RADIO_VALUE_TEXT_SET_X = ISVehicleDashboard.RADIO_VALUE_TEXT_SET_X or 0
ISVehicleDashboard.RADIO_VALUE_TEXT_SET_Y = ISVehicleDashboard.RADIO_VALUE_TEXT_SET_Y or 19

-- Behavior
ISVehicleDashboard.RADIO_VALUE_VOL_STEP = ISVehicleDashboard.RADIO_VALUE_VOL_STEP or 0.1
ISVehicleDashboard.RADIO_VALUE_FREQ_STEP = ISVehicleDashboard.RADIO_VALUE_FREQ_STEP or 100

-- Hold-repeat for freq buttons
ISVehicleDashboard.RADIO_VALUE_FREQ_HOLD_DELAY = ISVehicleDashboard.RADIO_VALUE_FREQ_HOLD_DELAY or 0.8
ISVehicleDashboard.RADIO_VALUE_FREQ_REPEAT_INTERVAL = ISVehicleDashboard.RADIO_VALUE_FREQ_REPEAT_INTERVAL or 0.2

-- Preset policy: pad vanilla list to 6 with 88.0 MHz
ISVehicleDashboard.RADIO_VALUE_PRESET_PAD_FREQ = ISVehicleDashboard.RADIO_VALUE_PRESET_PAD_FREQ or 88000 -- 88.0 MHz
ISVehicleDashboard.RADIO_VALUE_PRESET_PAD_NAME = ISVehicleDashboard.RADIO_VALUE_PRESET_PAD_NAME or " "
ISVehicleDashboard.RADIO_VALUE_PRESET_WRITE_NAME = ISVehicleDashboard.RADIO_VALUE_PRESET_WRITE_NAME or " "

-- LCD style
ISVehicleDashboard.RADIO_VALUE_TEXT_FONT = ISVehicleDashboard.RADIO_VALUE_TEXT_FONT or UIFont.Small
ISVehicleDashboard.RADIO_VALUE_TEXT_A = ISVehicleDashboard.RADIO_VALUE_TEXT_A or 0.95
ISVehicleDashboard.RADIO_VALUE_TEXT_RGB = ISVehicleDashboard.RADIO_VALUE_TEXT_RGB or { r=0.22, g=0.20, b=0.1 }
ISVehicleDashboard.RADIO_VALUE_LCD_SCALE = ISVehicleDashboard.RADIO_VALUE_LCD_SCALE or 1.0

-- SET timeout
ISVehicleDashboard.RADIO_VALUE_SET_TIMEOUT_S = ISVehicleDashboard.RADIO_VALUE_SET_TIMEOUT_S or 10.0


-- =========================================================
-- Helpers
-- =========================================================
local function clamp(v, a, b)
    if v < a then return a end
    if v > b then return b end
    return v
end
-- Single-player pause lock (MP unaffected)
local function _ydIsPausedSP()
    return (not isClient()) and (getGameSpeed and getGameSpeed() == 0)
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

local function fmtMHzNumberOnly(freq)
    if not freq then return "--.-" end
    return string.format("%.1f", (freq or 0) / 1000)
end

-- =========================================================
-- Radio device access (define if missing so this file is standalone)
-- =========================================================
if not ISVehicleDashboard._getVehicleRadioPart then
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
end

if not ISVehicleDashboard._radioHasPower then
    function ISVehicleDashboard:_radioHasPower(dd)
        if not dd then return false end
        local ok = false
        if dd.getPower and dd:getPower() > 0 then ok = true end
        if (not ok) and dd.canBePoweredHere and dd:canBePoweredHere() then ok = true end
        return ok
    end
end

if not ISVehicleDashboard._radioCanOperate then
    function ISVehicleDashboard:_radioCanOperate(dd)
        return dd and dd.getIsTurnedOn and dd:getIsTurnedOn() and self:_radioHasPower(dd)
    end
end

local function playTuneSound(dd)
    if not dd then return end
    local sound = "TuneIn"
    if dd.getIsTelevision and dd:getIsTelevision() then sound = "TelevisionZap" end
    if dd.isVehicleDevice and dd:isVehicleDevice() then sound = "VehicleRadioTuneIn" end
    if dd.stopOrTriggerSoundByName then dd:stopOrTriggerSoundByName(sound) end
    if dd.playSoundSend then dd:playSoundSend(sound, false) end
end

-- =========================================================
-- Preset helpers (VALUE-only namespace)
-- =========================================================
function ISVehicleDashboard:_radioValueGetDevicePresetsObj(dd)
    return dd and dd.getDevicePresets and dd:getDevicePresets() or nil
end

function ISVehicleDashboard:_radioValueGetDevicePresetList(dd)
    local dp = self:_radioValueGetDevicePresetsObj(dd)
    return dp and dp.getPresets and dp:getPresets() or nil
end

function ISVehicleDashboard:_radioValueEnsurePresetList6(dd)
    local list = self:_radioValueGetDevicePresetList(dd)
    if not list then return nil end

    local target = 6
    local padFreq = self.RADIO_VALUE_PRESET_PAD_FREQ or 88000
    local padName = self.RADIO_VALUE_PRESET_PAD_NAME or " "

    if list:size() < target then
        if not (PresetEntry and PresetEntry.new) then
            print("[YourDash RadioValue] PresetEntry.new missing; cannot pad preset list.")
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

function ISVehicleDashboard:_radioValueGetPresetEntry1to6(dd, idx)
    if not idx or idx < 1 or idx > 6 then return nil end
    local list = self:_radioValueEnsurePresetList6(dd)
    if not list then return nil end
    if idx > list:size() then return nil end
    return list:get(idx - 1)
end

function ISVehicleDashboard:_radioValueWritePreset1to6(dd, idx, freq)
    local preset = self:_radioValueGetPresetEntry1to6(dd, idx)
    if not preset then return false end

    if preset.setFrequency then preset:setFrequency(freq) end
    if preset.setName then preset:setName(self.RADIO_VALUE_PRESET_WRITE_NAME or " ") end

    if dd.transmitPresets then pcall(function() dd:transmitPresets() end) end
    if dd.updateSimple then pcall(function() dd:updateSimple() end) end
    return true
end


-- =========================================================
-- Actions: power / volume / mute / set / channels / freq hold
-- =========================================================
function ISVehicleDashboard:_radioValueDisarmSet()
    self.__radioValueSetArmed = false
    self.__radioValueSetArmedT = 0
end

function ISVehicleDashboard:onClickRadioValuePower()
    self:_radioValueDisarmSet()
    self:_radioValueStopFreqHold()

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

function ISVehicleDashboard:_radioValueSetVolumeDelta(delta)
    self:_radioValueDisarmSet()

    if getGameSpeed() == 0 then return end
    if getGameSpeed() > 1 then setGameSpeed(1) end
    if not self.vehicle or not self.character then return end

    local part = self:_getVehicleRadioPart()
    if not part then return end
    local dd = part:getDeviceData()
    if not self:_radioCanOperate(dd) then return end

    local v = (dd.getDeviceVolume and dd:getDeviceVolume()) or 0
    local nv = clamp((v or 0) + (delta or 0), 0, 1)

    -- If adjusting volume while muted and volume becomes > 0 => unmute
    if self.__radioValueMuted == true and nv > 0 then
        self.__radioValueMuted = false
        self.__radioValuePrevVol = nil
    end

    if dd.setDeviceVolume then dd:setDeviceVolume(nv) end
    if dd.updateSimple then dd:updateSimple() end
end

function ISVehicleDashboard:onClickRadioValueVolUp()
    self:_radioValueSetVolumeDelta(self.RADIO_VALUE_VOL_STEP or 0.1)
end

function ISVehicleDashboard:onClickRadioValueVolDown()
    self:_radioValueSetVolumeDelta(-(self.RADIO_VALUE_VOL_STEP or 0.1))
end

function ISVehicleDashboard:onClickRadioValueMute()
    self:_radioValueDisarmSet()
    self:_radioValueStopFreqHold()

    if not self.vehicle or not self.character then return end
    local part = self:_getVehicleRadioPart()
    if not part then return end
    local dd = part:getDeviceData()
    if not self:_radioCanOperate(dd) then return end

    if self.__radioValueMuted ~= true then
        local v = (dd.getDeviceVolume and dd:getDeviceVolume()) or 0
        self.__radioValuePrevVol = v
        self.__radioValueMuted = true
        if dd.setDeviceVolume then dd:setDeviceVolume(0) end
        if dd.updateSimple then dd:updateSimple() end
    else
        local restore = self.__radioValuePrevVol
        if restore == nil then restore = 0.5 end
        self.__radioValueMuted = false
        self.__radioValuePrevVol = nil
        if dd.setDeviceVolume then dd:setDeviceVolume(restore) end
        if dd.updateSimple then dd:updateSimple() end
    end
end

function ISVehicleDashboard:onClickRadioValueSet()
    self:_radioValueStopFreqHold()

    if not self.vehicle or not self.character then return end
    local part = self:_getVehicleRadioPart()
    if not part then return end
    local dd = part:getDeviceData()
    if not self:_radioCanOperate(dd) then
        self:_radioValueDisarmSet()
        return
    end

    if self.__radioValueSetArmed == true then
        self:_radioValueDisarmSet()
    else
        self.__radioValueSetArmed = true
        self.__radioValueSetArmedT = 0
    end
end

function ISVehicleDashboard:_radioValueOnClickChannelIndex(idx)
    self.__radioValueSetArmedT = 0
    self:_radioValueStopFreqHold()

    if not self.vehicle or not self.character then return end

    local part = self:_getVehicleRadioPart()
    if not part then return end
    local dd = part:getDeviceData()
    if not dd then return end
    if not self:_radioCanOperate(dd) then
        self:_radioValueDisarmSet()
        return
    end

    -- Ensure list padded before doing anything
    self:_radioValueEnsurePresetList6(dd)

    if self.__radioValueSetArmed == true then
        local cur = dd.getChannel and dd:getChannel() or nil
        if cur then
            self:_radioValueWritePreset1to6(dd, idx, cur)
        end
        self:_radioValueDisarmSet()
        return
    end

    local preset = self:_radioValueGetPresetEntry1to6(dd, idx)
    if not preset then return end
    local fq = preset.getFrequency and preset:getFrequency() or nil
    if not fq then return end

    playTuneSound(dd)
    if dd.setChannel then
        local ok = pcall(function() dd:setChannel(fq, true) end)
        if not ok then dd:setChannel(fq) end
    end
    if dd.updateSimple then dd:updateSimple() end
end

function ISVehicleDashboard:onClickRadioValueChan1() self:_radioValueOnClickChannelIndex(1) end
function ISVehicleDashboard:onClickRadioValueChan2() self:_radioValueOnClickChannelIndex(2) end
function ISVehicleDashboard:onClickRadioValueChan3() self:_radioValueOnClickChannelIndex(3) end
function ISVehicleDashboard:onClickRadioValueChan4() self:_radioValueOnClickChannelIndex(4) end
function ISVehicleDashboard:onClickRadioValueChan5() self:_radioValueOnClickChannelIndex(5) end
function ISVehicleDashboard:onClickRadioValueChan6() self:_radioValueOnClickChannelIndex(6) end

function ISVehicleDashboard:_radioValueStopFreqHold()
    self.__radioValueFreqHoldActive = false
    self.__radioValueFreqHoldDir = 0
    self.__radioValueFreqHoldT = 0
    self.__radioValueFreqHoldRepT = 0
end

function ISVehicleDashboard:_radioValueStepFrequency(dir, playSoundNow)
    local part = self:_getVehicleRadioPart()
    if not part then return end
    local dd = part:getDeviceData()
    if not self:_radioCanOperate(dd) then return end

    local step = self.RADIO_VALUE_FREQ_STEP or 100
    local f = dd.getChannel and dd:getChannel() or 0
    local mn = dd.getMinChannelRange and dd:getMinChannelRange() or f
    local mx = dd.getMaxChannelRange and dd:getMaxChannelRange() or f

    local nf = f + (dir * step)
    if nf > mx then nf = mn end
    if nf < mn then nf = mx end

    if playSoundNow then playTuneSound(dd) end
    if dd.setChannel then
        local ok = pcall(function() dd:setChannel(nf, true) end)
        if not ok then dd:setChannel(nf) end
    end
    if dd.updateSimple then dd:updateSimple() end
end

function ISVehicleDashboard:_radioValueBeginFreqHold(dir)
    -- Changing freq cancels SET mode
    self:_radioValueDisarmSet()

    local part = self:_getVehicleRadioPart()
    if not part then return false end
    local dd = part:getDeviceData()
    if not self:_radioCanOperate(dd) then return false end
    if self.__radioValueMuted == true then
        -- keep muted; allow changing freq silently
    end

    self.__radioValueFreqHoldActive = true
    self.__radioValueFreqHoldDir = dir
    self.__radioValueFreqHoldT = 0
    self.__radioValueFreqHoldRepT = 0

    self:_radioValueStepFrequency(dir, true)
    return true
end


-- =========================================================
-- Build UI
-- =========================================================
function ISVehicleDashboard:_ensureValueRadioControls()
    if self.__radioValueControlsReady then return end
    self.__radioValueControlsReady = true

    local base = "media/ui/vehicles/radio_value/"

    self.__rv_bg_off   = getTexture(base .. "radio_background_off.png")
    self.__rv_bg_on    = getTexture(base .. "radio_background_on.png") or self.__rv_bg_off

    self.__rv_pwr_btn  = getTexture(base .. "radio_power_btn.png")
    self.__rv_vol_up   = getTexture(base .. "radio_vol_up.png")
    self.__rv_vol_down = getTexture(base .. "radio_vol_down.png")
    self.__rv_set_btn  = getTexture(base .. "radio_set_btn.png")
    self.__rv_freq_up   = getTexture(base .. "radio_freq_up.png")
    self.__rv_freq_down = getTexture(base .. "radio_freq_down.png")
    self.__rv_mute_btn  = getTexture(base .. "radio_pause.png") -- reuse pause texture as mute

    self.__rv_chan = self.__rv_chan or {
        getTexture(base .. "radio_chan_1.png"),
        getTexture(base .. "radio_chan_2.png"),
        getTexture(base .. "radio_chan_3.png"),
        getTexture(base .. "radio_chan_4.png"),
        getTexture(base .. "radio_chan_5.png"),
        getTexture(base .. "radio_chan_6.png"),
    }

    -- Background + text renderer
    if self.__rv_bg_off and not self.valueRadioBG then
        self.valueRadioBG = ISImage:new(0, 0,
            self.__rv_bg_off:getWidthOrig(),
            self.__rv_bg_off:getHeightOrig(),
            self.__rv_bg_off
        )
        self.valueRadioBG:initialise()
        self.valueRadioBG:instantiate()
        self.valueRadioBG.target = self
        self.valueRadioBG.backgroundColor = { r=0, g=0, b=0, a=0 }
        self.valueRadioBG.alpha = 1

        function self.valueRadioBG:render()
            if not self.texture then return end
            self:drawTextureScaled(self.texture, 0, 0, self.width, self.height, self.alpha or 1)

            local dash = self.target
            if not dash then return end

            local font = dash.RADIO_VALUE_TEXT_FONT or UIFont.Small
            local rgb  = dash.RADIO_VALUE_TEXT_RGB or { r=1, g=1, b=1 }
            local a    = dash.RADIO_VALUE_TEXT_A   or 0.95

            if dash.__radioValueSetArmed == true then
                self:drawTextCentre("set?",
                    (self.width * 0.5) + (dash.RADIO_VALUE_TEXT_SET_X or 0),
                    (dash.RADIO_VALUE_TEXT_SET_Y or 0),
                    rgb.r, rgb.g, rgb.b, a, font
                )
                return
            end

            local left  = dash.__radioValueTextLeft  or ""
            local right = dash.__radioValueTextRight or ""

            if left ~= "" then
                self:drawText(left,
                    (dash.RADIO_VALUE_TEXT_VOL_X or 0),
                    (dash.RADIO_VALUE_TEXT_VOL_Y or 0),
                    rgb.r, rgb.g, rgb.b, a, font
                )
            end

            if right ~= "" then
                self:drawTextRight(right,
                    self.width + (dash.RADIO_VALUE_TEXT_FREQ_X or 0),
                    (dash.RADIO_VALUE_TEXT_FREQ_Y or 0),
                    rgb.r, rgb.g, rgb.b, a, font
                )
            end
        end

        self:addChild(self.valueRadioBG)
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

    makeBtn("valueRadioPowerBtn",   self.__rv_pwr_btn,  ISVehicleDashboard.onClickRadioValuePower)
    makeBtn("valueRadioVolUpBtn",   self.__rv_vol_up,   ISVehicleDashboard.onClickRadioValueVolUp)
    makeBtn("valueRadioVolDownBtn", self.__rv_vol_down, ISVehicleDashboard.onClickRadioValueVolDown)
    makeBtn("valueRadioSetBtn",     self.__rv_set_btn,  ISVehicleDashboard.onClickRadioValueSet)
    makeBtn("valueRadioMuteBtn",    self.__rv_mute_btn, ISVehicleDashboard.onClickRadioValueMute)

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
        if _ydIsPausedSP() then return false end
        dash:_radioValueBeginFreqHold(dir)
        self:setCapture(true)
        return true
    end


        local function endHold(selfBtn)
            local dash = selfBtn.target
            if dash then dash:_radioValueStopFreqHold() end
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

    makeHoldBtn("valueRadioFreqUpBtn",   self.__rv_freq_up,   1)
    makeHoldBtn("valueRadioFreqDownBtn", self.__rv_freq_down, -1)

    self.valueRadioChanBtn = self.valueRadioChanBtn or {}
    for i = 1, 6 do
        if self.__rv_chan[i] and not self.valueRadioChanBtn[i] then
            local fn =
                (i == 1 and ISVehicleDashboard.onClickRadioValueChan1) or
                (i == 2 and ISVehicleDashboard.onClickRadioValueChan2) or
                (i == 3 and ISVehicleDashboard.onClickRadioValueChan3) or
                (i == 4 and ISVehicleDashboard.onClickRadioValueChan4) or
                (i == 5 and ISVehicleDashboard.onClickRadioValueChan5) or
                (i == 6 and ISVehicleDashboard.onClickRadioValueChan6)

            local img = ISImage:new(0, 0,
                self.__rv_chan[i]:getWidthOrig(),
                self.__rv_chan[i]:getHeightOrig(),
                self.__rv_chan[i]
            )
            img:initialise()
            img:instantiate()
            img.target = self
            img.__handler = fn
            img.onclick = fn
            img.backgroundColor = { r=0, g=0, b=0, a=0 }
            img.alpha = 1
            self:addChild(img)
            self.valueRadioChanBtn[i] = img

            if self._installPressedEffect then
                self:_installPressedEffect(img, 0.98)
            else
                installPressedEffectFallback(img, 0.98)
            end
        end
    end
end


-- =========================================================
-- Position UI
-- =========================================================
function ISVehicleDashboard:_positionValueRadioControls()
    if not self.backgroundTex then return end
    self:_ensureValueRadioControls()
    if not self.valueRadioBG then return end

    local bx = self.backgroundTex:getX() + (self.RADIO_VALUE_UI_X or 0)
    local by = self.backgroundTex:getY() + (self.RADIO_VALUE_UI_Y or 0)

    self.valueRadioBG:setX(bx)
    self.valueRadioBG:setY(by)

    local function place(img, ox, oy)
        if not img then return end
        img:setX(bx + (ox or 0))
        img:setY(by + (oy or 0))
    end

    place(self.valueRadioPowerBtn,   self.RADIO_VALUE_POWER_OFF_X,     self.RADIO_VALUE_POWER_OFF_Y)
    place(self.valueRadioVolDownBtn, self.RADIO_VALUE_VOL_DOWN_OFF_X,  self.RADIO_VALUE_VOL_DOWN_OFF_Y)
    place(self.valueRadioVolUpBtn,   self.RADIO_VALUE_VOL_UP_OFF_X,    self.RADIO_VALUE_VOL_UP_OFF_Y)
    place(self.valueRadioSetBtn,     self.RADIO_VALUE_SET_OFF_X,       self.RADIO_VALUE_SET_OFF_Y)
    place(self.valueRadioFreqUpBtn,  self.RADIO_VALUE_FREQ_UP_OFF_X,   self.RADIO_VALUE_FREQ_UP_OFF_Y)
    place(self.valueRadioFreqDownBtn,self.RADIO_VALUE_FREQ_DOWN_OFF_X, self.RADIO_VALUE_FREQ_DOWN_OFF_Y)
    place(self.valueRadioMuteBtn,    self.RADIO_VALUE_MUTE_OFF_X,      self.RADIO_VALUE_MUTE_OFF_Y)

    if self.valueRadioChanBtn then
        place(self.valueRadioChanBtn[1], self.RADIO_VALUE_CH1_OFF_X, self.RADIO_VALUE_CH1_OFF_Y)
        place(self.valueRadioChanBtn[2], self.RADIO_VALUE_CH2_OFF_X, self.RADIO_VALUE_CH2_OFF_Y)
        place(self.valueRadioChanBtn[3], self.RADIO_VALUE_CH3_OFF_X, self.RADIO_VALUE_CH3_OFF_Y)
        place(self.valueRadioChanBtn[4], self.RADIO_VALUE_CH4_OFF_X, self.RADIO_VALUE_CH4_OFF_Y)
        place(self.valueRadioChanBtn[5], self.RADIO_VALUE_CH5_OFF_X, self.RADIO_VALUE_CH5_OFF_Y)
        place(self.valueRadioChanBtn[6], self.RADIO_VALUE_CH6_OFF_X, self.RADIO_VALUE_CH6_OFF_Y)
    end
end


-- =========================================================
-- Update each frame
-- =========================================================
function ISVehicleDashboard:_updateValueRadioControls()
    self:_ensureValueRadioControls()

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

    if self.valueRadioBG then self.valueRadioBG:setVisible(hasRadio) end
    if self.valueRadioPowerBtn then self.valueRadioPowerBtn:setVisible(hasRadio) end
    if self.valueRadioVolUpBtn then self.valueRadioVolUpBtn:setVisible(hasRadio) end
    if self.valueRadioVolDownBtn then self.valueRadioVolDownBtn:setVisible(hasRadio) end
    if self.valueRadioSetBtn then self.valueRadioSetBtn:setVisible(hasRadio) end
    if self.valueRadioFreqUpBtn then self.valueRadioFreqUpBtn:setVisible(hasRadio) end
    if self.valueRadioFreqDownBtn then self.valueRadioFreqDownBtn:setVisible(hasRadio) end
    if self.valueRadioMuteBtn then self.valueRadioMuteBtn:setVisible(hasRadio) end

    if self.valueRadioChanBtn then
        for i = 1, 6 do
            if self.valueRadioChanBtn[i] then self.valueRadioChanBtn[i]:setVisible(hasRadio) end
        end
    end

    if not hasRadio then
        self:_radioValueDisarmSet()
        self:_radioValueStopFreqHold()
        self.__radioValueTextLeft = ""
        self.__radioValueTextRight = ""
        return
    end

    local dd = part:getDeviceData()
    if not dd then
        self:_radioValueDisarmSet()
        self:_radioValueStopFreqHold()
        self.__radioValueTextLeft = ""
        self.__radioValueTextRight = ""
        return
    end
    local spPaused = _ydIsPausedSP()

    -- If player pauses mid-hold, stop it so it can't keep stepping in UI-time
    if spPaused and self.__radioValueFreqHoldActive then
        self:_radioValueStopFreqHold()
        if self.valueRadioFreqUpBtn and self.valueRadioFreqUpBtn.setCapture then
            pcall(function() self.valueRadioFreqUpBtn:setCapture(false) end)
        end
        if self.valueRadioFreqDownBtn and self.valueRadioFreqDownBtn.setCapture then
            pcall(function() self.valueRadioFreqDownBtn:setCapture(false) end)
        end
    end

    -- Always keep preset list padded (policy)
    self:_radioValueEnsurePresetList6(dd)

    local isOn = (dd.getIsTurnedOn and dd:getIsTurnedOn()) == true

    local canToggle = false
    if dd.getIsBatteryPowered and dd.getPower and dd:getIsBatteryPowered() then
        canToggle = (dd:getPower() > 0)
    end
    if (not canToggle) and dd.canBePoweredHere then
        canToggle = (dd:canBePoweredHere() == true)
    end

    -- Background swap
    if self.valueRadioBG and self.__rv_bg_off then
        local want = isOn and (self.__rv_bg_on or self.__rv_bg_off) or self.__rv_bg_off
        if self.valueRadioBG.texture ~= want then
            setImageTextureAndSize(self, self.valueRadioBG, want)
        end
    end

    if not isOn then
        self:_radioValueDisarmSet()
        self:_radioValueStopFreqHold()
        if self.__radioValueMuted == true then
            self.__radioValueMuted = false
            self.__radioValuePrevVol = nil
        end
    end

    local canOperate = self:_radioCanOperate(dd)

    -- Text payload (used by valueRadioBG:render)
    self.__radioValueTextLeft = ""
    self.__radioValueTextRight = ""

    if canOperate then
        if self.__radioValueSetArmed == true then
            -- render() will draw "set?" and hide left/right
            self.__radioValueTextLeft = ""
            self.__radioValueTextRight = ""
        else
            local v = (dd.getDeviceVolume and dd:getDeviceVolume()) or 0
            local v10 = math.floor(clamp(v or 0, 0, 1) * 10 + 0.5)
            self.__radioValueTextLeft = tostring(v10)

            local curF = dd.getChannel and dd:getChannel() or nil
            self.__radioValueTextRight = fmtMHzNumberOnly(curF)
        end
    end

    -- Power
    if self.valueRadioPowerBtn then
        setEnabled(self, self.valueRadioPowerBtn, canToggle,
            isOn and getText("ContextMenu_Turn_Off") or getText("ContextMenu_Turn_On"),
            ISVehicleDashboard.onClickRadioValuePower
        )
    end

    -- Volume
    if self.valueRadioVolUpBtn then
        setEnabled(self, self.valueRadioVolUpBtn, canOperate, getText("IGUI_RadioVolume"), ISVehicleDashboard.onClickRadioValueVolUp)
    end
    if self.valueRadioVolDownBtn then
        setEnabled(self, self.valueRadioVolDownBtn, canOperate, getText("IGUI_RadioVolume"), ISVehicleDashboard.onClickRadioValueVolDown)
    end

    -- SET
    if self.valueRadioSetBtn then
        setEnabled(self, self.valueRadioSetBtn, canOperate, "Set", ISVehicleDashboard.onClickRadioValueSet)
        self.valueRadioSetBtn.alpha = (self.__radioValueSetArmed == true) and 1.0 or 0.85
    end

    -- Mute
    if self.valueRadioMuteBtn then
        local tip = (self.__radioValueMuted == true) and "Unmute" or "Mute"
        setEnabled(self, self.valueRadioMuteBtn, canOperate, tip, ISVehicleDashboard.onClickRadioValueMute)
        self.valueRadioMuteBtn.alpha = 1.0
    end

    -- Channels
    local presetList = self:_radioValueGetDevicePresetList(dd)
    if self.valueRadioChanBtn then
        for i = 1, 6 do
            local img = self.valueRadioChanBtn[i]
            if img then
                local enabled = canOperate and presetList and (i <= presetList:size())

                local tip = "CH" .. tostring(i)
                if presetList and (i <= presetList:size()) then
                    local preset = presetList:get(i - 1)
                    local fq = preset and preset.getFrequency and preset:getFrequency() or nil
                    if fq then
                        tip = string.format("CH%d: %sMHz", i, fmtMHzNumberOnly(fq))
                    end
                end

                setEnabled(self, img, enabled, tip, img.__handler)
                img.alpha = 1.0
            end
        end
    end


    -- Freq up/down (hold)
    local freqEnabled = canOperate and (not spPaused)

    if self.valueRadioFreqUpBtn then
        setEnabled(self, self.valueRadioFreqUpBtn, freqEnabled, "Freq +", nil)
        self.valueRadioFreqUpBtn.__disabled = not freqEnabled
    end
    if self.valueRadioFreqDownBtn then
        setEnabled(self, self.valueRadioFreqDownBtn, freqEnabled, "Freq -", nil)
        self.valueRadioFreqDownBtn.__disabled = not freqEnabled
    end

    -- Hold-repeat update
    if (not spPaused) and self.__radioValueFreqHoldActive then
        if not canOperate then
            self:_radioValueStopFreqHold()
        else
            local dt = UIManager.getSecondsSinceLastRender()
            if not dt or dt <= 0 then dt = 1/30 end

            self.__radioValueFreqHoldT = (self.__radioValueFreqHoldT or 0) + dt

            local delay    = self.RADIO_VALUE_FREQ_HOLD_DELAY or 0.8
            local interval = self.RADIO_VALUE_FREQ_REPEAT_INTERVAL or 0.2

            if self.__radioValueFreqHoldT >= delay then
                self.__radioValueFreqHoldRepT = (self.__radioValueFreqHoldRepT or 0) + dt
                while self.__radioValueFreqHoldRepT >= interval do
                    self.__radioValueFreqHoldRepT = self.__radioValueFreqHoldRepT - interval
                    self:_radioValueStepFrequency(self.__radioValueFreqHoldDir or 0, false)
                end
            end
        end
    end

    -- Auto-cancel SET after timeout
    if (not spPaused) and (self.__radioValueSetArmed == true) then
        local dt2 = UIManager.getSecondsSinceLastRender()
        if not dt2 or dt2 <= 0 then dt2 = 1/30 end

        self.__radioValueSetArmedT = (self.__radioValueSetArmedT or 0) + dt2
        if (self.__radioValueSetArmedT or 0) >= (self.RADIO_VALUE_SET_TIMEOUT_S or 10.0) then
            self:_radioValueDisarmSet()
        end
    end

    self:_positionValueRadioControls()
end

if ISVehicleDashboard.__YourDashRadioRouterActive then
    return
end
-- =========================================================
-- Hooks
-- =========================================================
local _oldCreateChildren = ISVehicleDashboard.createChildren
function ISVehicleDashboard:createChildren()
    if _oldCreateChildren then _oldCreateChildren(self) end
    self:_ensureValueRadioControls()
    self:_positionValueRadioControls()
end

local _oldOnRes = ISVehicleDashboard.onResolutionChange
function ISVehicleDashboard:onResolutionChange()
    if _oldOnRes then _oldOnRes(self) end
    self:_positionValueRadioControls()
end

local _oldPrerender = ISVehicleDashboard.prerender
function ISVehicleDashboard:prerender()
    if _oldPrerender then _oldPrerender(self) end
    if not self.vehicle or not ISUIHandler.allUIVisible then return end
    self:_updateValueRadioControls()
end
