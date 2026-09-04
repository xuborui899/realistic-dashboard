if isServer() then return end

require "YourDash/DashboardCore"
require "YourDash/EmergencyLightController"
require "Vehicles/ISUI/ISVehicleDashboard"

-- Guard: don’t patch twice
if ISVehicleDashboard.__YourDashRadioRouterPatched then return end
ISVehicleDashboard.__YourDashRadioRouterPatched = true

-- =========================================================
-- Capture CURRENT dashboard methods BEFORE loading radio modules.
-- IMPORTANT: load this router AFTER your main dashboard patch.
-- =========================================================
local _baseCreateChildren = ISVehicleDashboard.createChildren
local _baseOnRes          = ISVehicleDashboard.onResolutionChange
local _basePrerender      = ISVehicleDashboard.prerender
local _baseSetVehicle     = ISVehicleDashboard.setVehicle
local ELC                 = YourDash.EmergencyLightController

-- Tell submodules not to hook dashboard methods (if they support it)
ISVehicleDashboard.__YourDashRadioRouterActive = true

-- Load helper-only radio modules from their actual client module paths.
-- Fail loudly here if either module is absent; a half-installed router would hide
-- the vanilla radio icon without providing a replacement.
require "Vehicles/ISUI/Z_PatchVehicleDashboard_RadioPremium"
require "Vehicles/ISUI/Z_PatchVehicleDashboard_RadioValue"

function ISVehicleDashboard:_yourDashResetRadioTransientState()
    self.__yourDashRadioPartVehicle = nil
    self.__yourDashRadioPartId = nil

    self.__radioSource = nil
    self.__radioMuted = false
    self.__radioPrevVol = nil
    self.__radioCdPaused = false
    self.__radioCdMutedByPause = false
    self.__radioCdPrevVol = nil
    self.__radioMediaNameCache = nil
    self.__radioLoading = false
    self.__radioLoadingCdPausedAfter = nil
    self.__radioLoadingRestoreVolAfter = nil
    self.__radioLoadingRestoreVolValue = nil
    self.__radioLoadingExpectedSource = nil
    self.__radioLoadingJustStarted = nil
    self.__radioLoadingTargetPlaying = nil
    self.__radioSetArmed = false
    self.__radioSetArmedT = 0
    self.__radioTuneScanActive = false
    self.__radioFreqHoldActive = false
    self.__radioMarqueeText = nil
    self.__radioMarqueeOffset = 0
    self.__radioTextLeft, self.__radioTextMid, self.__radioTextRight = nil, nil, nil

    self.__radioValueMuted = false
    self.__radioValuePrevVol = nil
    self.__radioValueSetArmed = false
    self.__radioValueSetArmedT = 0
    self.__radioValueFreqHoldActive = false
    self.__radioValueTextLeft, self.__radioValueTextRight = nil, nil
end

-- =========================================================
-- Safe radio part finder: returns an INSTALLED radio part or nil.
-- Works for motorcycles/no-radio vehicles and weird modded part IDs.
-- =========================================================
function ISVehicleDashboard:_yourDashFindInstalledRadioPart()
    local v = self and self.vehicle
    if not v then return nil end

    -- Try cached id for THIS vehicle instance
    if self.__yourDashRadioPartVehicle == v and self.__yourDashRadioPartId then
        local ok, p = pcall(function()
            if v.getPartById then return v:getPartById(self.__yourDashRadioPartId) end
            return nil
        end)
        if ok and p then
            local okInv, inv = pcall(function()
                return p.getInventoryItem and p:getInventoryItem() or nil
            end)
            if okInv and inv then return p end
        end
        self.__yourDashRadioPartId = nil
    end

    -- Vanilla ID
    local ok, p = pcall(function()
        if v.getPartById then return v:getPartById("Radio") end
        return nil
    end)
    if ok and p then
        local okInv, inv = pcall(function()
            return p.getInventoryItem and p:getInventoryItem() or nil
        end)
        if okInv and inv then
            self.__yourDashRadioPartVehicle = v
            self.__yourDashRadioPartId = "Radio"
            return p
        end
        return nil
    end

    -- Fallback: scan parts for installed Base.Radio*
    local okCnt, cnt = pcall(function()
        return (v.getPartCount and v:getPartCount()) or 0
    end)
    cnt = (okCnt and cnt) or 0

    for i = 0, cnt - 1 do
        local part = v:getPartByIndex(i)
        if part and part.getInventoryItem then
            local okInv, inv = pcall(function() return part:getInventoryItem() end)
            if okInv and inv and inv.getFullType then
                local okFt, ft = pcall(function() return inv:getFullType() end)
                if okFt and ft and string.find(ft, "Base.Radio", 1, true) then
                    local okId, id = pcall(function()
                        return part.getId and part:getId() or nil
                    end)
                    if okId and id then
                        self.__yourDashRadioPartVehicle = v
                        self.__yourDashRadioPartId = id
                    end
                    return part
                end
            end
        end
    end

    return nil
end

-- =========================================================
-- Hard override: this is the SIMPLE motorcycle fix you asked for.
-- If there is no radio part, this returns nil and NEVER throws.
-- =========================================================
function ISVehicleDashboard:_getVehicleRadioPart()
    return self:_yourDashFindInstalledRadioPart()
end

function ISVehicleDashboard:_yourDashGetInstalledRadioFullType()
    local part = self:_yourDashFindInstalledRadioPart()
    if not part then return nil end

    local okInv, inv = pcall(function()
        return part.getInventoryItem and part:getInventoryItem() or nil
    end)
    if not okInv or not inv then return nil end

    local okFt, ft = pcall(function()
        return inv.getFullType and inv:getFullType() or nil
    end)
    if okFt then return ft end
    return nil
end

function ISVehicleDashboard:_yourDashPickRadioUI()
    local ft = self:_yourDashGetInstalledRadioFullType()
    if not ft then return nil end
    if ft == "Base.RadioRed" then return "premium" end
    return "value"
end

-- ---------------------------------------------------------
-- Hide helpers (same idea as yours)
-- ---------------------------------------------------------
function ISVehicleDashboard:_yourDashHidePremiumRadioUI()
    if self.radioBG then self.radioBG:setVisible(false) end
    if self.radioPowerBtn then self.radioPowerBtn:setVisible(false) end
    if self.radioVolUpBtn then self.radioVolUpBtn:setVisible(false) end
    if self.radioVolDownBtn then self.radioVolDownBtn:setVisible(false) end
    if self.radioTuneBtn then self.radioTuneBtn:setVisible(false) end
    if self.radioSetBtn then self.radioSetBtn:setVisible(false) end
    if self.radioFreqUpBtn then self.radioFreqUpBtn:setVisible(false) end
    if self.radioFreqDownBtn then self.radioFreqDownBtn:setVisible(false) end
    if self.radioSrcBtn then self.radioSrcBtn:setVisible(false) end
    if self.radioLoadDiskBtn then self.radioLoadDiskBtn:setVisible(false) end
    if self.radioPauseBtn then self.radioPauseBtn:setVisible(false) end
    if self.radioChanBtn then
        for i = 1, 6 do
            if self.radioChanBtn[i] then self.radioChanBtn[i]:setVisible(false) end
        end
    end
end

function ISVehicleDashboard:_yourDashHideValueRadioUI()
    if self.valueRadioBG then self.valueRadioBG:setVisible(false) end
    if self.valueRadioPowerBtn then self.valueRadioPowerBtn:setVisible(false) end
    if self.valueRadioVolUpBtn then self.valueRadioVolUpBtn:setVisible(false) end
    if self.valueRadioVolDownBtn then self.valueRadioVolDownBtn:setVisible(false) end
    if self.valueRadioSetBtn then self.valueRadioSetBtn:setVisible(false) end
    if self.valueRadioFreqUpBtn then self.valueRadioFreqUpBtn:setVisible(false) end
    if self.valueRadioFreqDownBtn then self.valueRadioFreqDownBtn:setVisible(false) end
    if self.valueRadioMuteBtn then self.valueRadioMuteBtn:setVisible(false) end
    if self.valueRadioChanBtn then
        for i = 1, 6 do
            if self.valueRadioChanBtn[i] then self.valueRadioChanBtn[i]:setVisible(false) end
        end
    end
end

-- ---------------------------------------------------------
-- Dispatch update: if no radio -> hide both and stop.
-- ---------------------------------------------------------
function ISVehicleDashboard:_yourDashUpdateRoutedRadio()
    local which = self:_yourDashPickRadioUI()

    if which == "premium" then
        self:_yourDashHideValueRadioUI()
        if self._updateRadioControls then self:_updateRadioControls() end
        return
    end

    if which == "value" then
        self:_yourDashHidePremiumRadioUI()
        if self._updateValueRadioControls then self:_updateValueRadioControls() end
        return
    end

    -- none (motorcycles etc.)
    self:_yourDashHidePremiumRadioUI()
    self:_yourDashHideValueRadioUI()
end

function ISVehicleDashboard:_yourDashPositionRoutedRadio()
    local which = self:_yourDashPickRadioUI()
    if which == "premium" then
        if self._positionRadioControls then self:_positionRadioControls() end
    elseif which == "value" then
        if self._positionValueRadioControls then self:_positionValueRadioControls() end
    end
end

-- =========================================================
-- Router owns hooks (using BASE methods captured pre-modules)
-- =========================================================
function ISVehicleDashboard:setVehicle(vehicle)
    local previousVehicle = self.vehicle
    if _baseSetVehicle then _baseSetVehicle(self, vehicle) end
    if previousVehicle ~= vehicle then self:_yourDashResetRadioTransientState() end
    if ELC then ELC.SetVehicle(self, vehicle, previousVehicle ~= vehicle) end
end

function ISVehicleDashboard:createChildren()
    if _baseCreateChildren then _baseCreateChildren(self) end
    if self._ensureRadioControls then pcall(function() self:_ensureRadioControls() end) end
    if self._ensureValueRadioControls then pcall(function() self:_ensureValueRadioControls() end) end
    self:_yourDashPositionRoutedRadio()
    if ELC then
        ELC.Ensure(self)
        ELC.Position(self)
    end
end

function ISVehicleDashboard:onResolutionChange()
    if _baseOnRes then _baseOnRes(self) end
    self:_yourDashPositionRoutedRadio()
    if ELC then ELC.Position(self) end
end

function ISVehicleDashboard:prerender()
    if _basePrerender then _basePrerender(self) end
    if not self.vehicle or not ISUIHandler.allUIVisible then
        if ELC then ELC.Update(self, false) end
        return
    end
    self:_yourDashUpdateRoutedRadio()
    if YourDash.KeepHoveredHotbarAboveDashboard then
        YourDash.KeepHoveredHotbarAboveDashboard(self)
    end
    if ELC then ELC.Update(self, true) end
end

-- Extra safety: if Premium/Value update gets called from anywhere, bail on no-radio vehicles.
do
    local _oldPremiumUpdate = ISVehicleDashboard._updateRadioControls
    if _oldPremiumUpdate then
        function ISVehicleDashboard:_updateRadioControls(...)
            if not self:_yourDashFindInstalledRadioPart() then
                self:_yourDashHidePremiumRadioUI()
                return
            end
            return _oldPremiumUpdate(self, ...)
        end
    end

    local _oldValueUpdate = ISVehicleDashboard._updateValueRadioControls
    if _oldValueUpdate then
        function ISVehicleDashboard:_updateValueRadioControls(...)
            if not self:_yourDashFindInstalledRadioPart() then
                self:_yourDashHideValueRadioUI()
                return
            end
            return _oldValueUpdate(self, ...)
        end
    end
end

-- Make the sport layer the deterministic final dashboard wrapper.  The file
-- also has a guard, so its normal alphabetical auto-load remains harmless.
require "Vehicles/ISUI/ZZZ_YourDashSport"
