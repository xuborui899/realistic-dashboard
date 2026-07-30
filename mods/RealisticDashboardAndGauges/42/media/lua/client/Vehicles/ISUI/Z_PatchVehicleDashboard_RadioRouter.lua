-- media/lua/client/YourDash/Z_PatchVehicleDashboard_RadioRouter.lua
if isServer() then return end

require "Vehicles/ISUI/ISVehicleDashboard"

-- Guard: don’t patch twice
if ISVehicleDashboard.__YourDashRadioRouterPatched then return end
ISVehicleDashboard.__YourDashRadioRouterPatched = true

-- Tell submodules not to hook dashboard methods.
ISVehicleDashboard.__YourDashRadioRouterActive = true
require "YourDash/Z_PatchVehicleDashboard_RadioPremium"
require "YourDash/Z_PatchVehicleDashboard_RadioValue"
-- keep the flag true so late requires still won’t hook

-- ---------------------------------------------------------
-- Detect installed vehicle radio: premium vs value vs none
-- ---------------------------------------------------------
function ISVehicleDashboard:_yourDashGetInstalledRadioFullType()
    local part = self._getVehicleRadioPart and self:_getVehicleRadioPart() or nil
    if not part then return nil end

    local item = part.getInventoryItem and part:getInventoryItem() or nil
    if not item then return nil end

    if item.getFullType then
        return item:getFullType()
    end
    return nil
end

function ISVehicleDashboard:_yourDashPickRadioUI()
    local ft = self:_yourDashGetInstalledRadioFullType()
    if not ft then return nil end            -- no radio installed
    if ft == "Base.RadioRed" then return "premium" end
    return "value"
end

-- ---------------------------------------------------------
-- Hide helpers (avoid leftover UI when switching cars)
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
-- Dispatch update
-- ---------------------------------------------------------
function ISVehicleDashboard:_yourDashUpdateRoutedRadio()
    local which = self:_yourDashPickRadioUI()

    if which == "premium" then
        self:_yourDashHideValueRadioUI()
        if self._updateRadioControls then
            self:_updateRadioControls()
        end
        return
    end

    if which == "value" then
        self:_yourDashHidePremiumRadioUI()
        if self._updateValueRadioControls then
            self:_updateValueRadioControls()
        end
        return
    end

    -- none
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

-- ---------------------------------------------------------
-- Hooks (router owns the hooks)
-- ---------------------------------------------------------
local _oldCreateChildren = ISVehicleDashboard.createChildren
function ISVehicleDashboard:createChildren()
    if _oldCreateChildren then _oldCreateChildren(self) end

    -- Lazy-create both sets so switching cars is seamless
    if self._ensureRadioControls then self:_ensureRadioControls() end
    if self._ensureValueRadioControls then self:_ensureValueRadioControls() end

    self:_yourDashPositionRoutedRadio()
end

local _oldOnRes = ISVehicleDashboard.onResolutionChange
function ISVehicleDashboard:onResolutionChange()
    if _oldOnRes then _oldOnRes(self) end
    self:_yourDashPositionRoutedRadio()
end

local _oldPrerender = ISVehicleDashboard.prerender
function ISVehicleDashboard:prerender()
    if _oldPrerender then _oldPrerender(self) end
    if not self.vehicle or not ISUIHandler.allUIVisible then return end
    self:_yourDashUpdateRoutedRadio()
end

-- require "YourDash/ZZ_PatchVehicleDashboard_PassengerDash"

