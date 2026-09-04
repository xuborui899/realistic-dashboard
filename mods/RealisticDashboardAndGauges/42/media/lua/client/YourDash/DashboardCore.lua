-- Shared B42 dashboard configuration and lookup helpers.
--
-- This module deliberately does not patch ISVehicleDashboard.  It owns only
-- stable data and defensive helper functions so the UI patches can require it
-- in a deterministic order.

YourDash = YourDash or {}

local YD = YourDash

if YD.__DashboardCoreLoaded then
    return YD
end

local function clamp(value, minimum, maximum)
    if value < minimum then return minimum end
    if value > maximum then return maximum end
    return value
end

local function roundNearest(value)
    value = tonumber(value) or 0
    if value >= 0 then
        return math.floor(value + 0.5)
    end
    return math.ceil(value - 0.5)
end

local function fillMissing(destination, defaults)
    destination = destination or {}
    for key, value in pairs(defaults or {}) do
        if type(value) == "table" then
            if type(destination[key]) ~= "table" then
                destination[key] = {}
            end
            fillMissing(destination[key], value)
        elseif destination[key] == nil then
            destination[key] = value
        end
    end
    return destination
end

local function newWeakKeyTable()
    local result = {}
    -- Kahlua supports weak tables, but retain a normal-table fallback for
    -- standalone tooling and unusual embedded runtimes.
    pcall(setmetatable, result, { __mode = "k" })
    return result
end

local function safeMethod(object, methodName, ...)
    if object == nil or methodName == nil then return nil, false end

    local okMethod, method = pcall(function()
        return object[methodName]
    end)
    if not okMethod or type(method) ~= "function" then
        return nil, false
    end

    local ok, value = pcall(method, object, ...)
    if not ok then return nil, false end
    return value, true
end

-- Some hotbar mods draw their hover labels inside the hotbar panel itself.
-- Keep a hovered hotbar above the vehicle dashboard so those labels remain
-- readable without depending on a particular hotbar implementation.
function YD.KeepHoveredHotbarAboveDashboard(owner)
    if not owner or not getPlayerHotbar then return end

    local playerNum = tonumber(owner.playerNum)
    if playerNum == nil then return end

    local ok, hotbar = pcall(getPlayerHotbar, playerNum)
    if not ok or not hotbar or not hotbar.bringToTop then return end

    local hovered = safeMethod(hotbar, "isMouseOver")
    if hovered == true then
        pcall(hotbar.bringToTop, hotbar)
    end
end

-- Vanilla ISImage tooltips reserve 220 pixels even for a short label and pin
-- themselves directly below the image. Keep dashboard labels text-sized, then
-- use the normal near-cursor offset so they do not sit under the pointer.
function YD.PositionCompactTooltip(element, tooltip, dashboard)
    if not element or not tooltip then return end

    local buttonTooltip = element.__YourDashButtonTooltip == true
        or element.__YourDashPressedInstalled == true
        or element.__disabled ~= nil
        or element.onclick ~= nil
    if buttonTooltip and YD.AreButtonTooltipsEnabled and not YD.AreButtonTooltipsEnabled() then
        if tooltip.setVisible then tooltip:setVisible(false) end
        return
    end

    tooltip.defaultMyWidth = 0
    tooltip.nameMarginX = 0
    tooltip.maxLineWidth = 1000
    tooltip.followMouse = true
    tooltip.desiredX = nil
    tooltip.desiredY = nil
    tooltip.__YourDashCompactTooltip = true
    if tooltip.javaObject and tooltip.javaObject.setConsumeMouseEvents then
        tooltip.javaObject:setConsumeMouseEvents(false)
    end

    if not tooltip.description or tooltip.description == "" then return end
    if tooltip.doLayout then pcall(tooltip.doLayout, tooltip) end
end

function YD.InstallCompactTooltip(element, dashboard)
    if not element then return end
    if element.__YourDashCompactTooltipInstalled then
        element.__YourDashTooltipDashboard = dashboard or element.__YourDashTooltipDashboard
        return
    end

    local baseUpdateTooltip = element.updateTooltip
    if type(baseUpdateTooltip) ~= "function" then return end

    element.__YourDashCompactTooltipInstalled = true
    element.__YourDashTooltipDashboard = dashboard
    element.updateTooltip = function(self, ...)
        baseUpdateTooltip(self, ...)
        if self.tooltipUI then
            YD.PositionCompactTooltip(self, self.tooltipUI, self.__YourDashTooltipDashboard)
        end
    end
end

function YD.InstallCompactTooltipTree(root, dashboard)
    if not root then return end

    local visited = {}
    local function visit(element)
        if not element or visited[element] then return end
        visited[element] = true
        YD.InstallCompactTooltip(element, dashboard or root)

        local children = element.childrenInOrder or element.children
        if children then
            for _, child in pairs(children) do
                visit(child)
            end
        end
    end

    visit(root)
end

local function cleanRelativePath(value)
    if value == nil then return nil end
    local path = tostring(value)
    path = string.gsub(path, "\\", "/")
    path = string.gsub(path, "^/+", "")
    path = string.gsub(path, "/+$", "")
    if path == "" then return nil end

    -- Assets never need parent-directory traversal.  Rejecting it also keeps
    -- cache keys canonical.
    if path == ".."
        or string.find(path, "../", 1, true)
        or string.find(path, "/..", 1, true)
    then
        return nil
    end

    return path
end

-- -------------------------------------------------------------------------
-- Four texture sizes / B42 ModOptions integration
-- -------------------------------------------------------------------------

YD.MODOPT_ID = YD.MODOPT_ID or "RealisticDash"
YD.MODOPT_NAME = YD.MODOPT_NAME or "Realistic Dashboard & Gauges"
YD.OPT_TEXSIZE_ID = YD.OPT_TEXSIZE_ID or "TextureSize"
YD.OPT_SHORTCUT_BUTTONS_ID = YD.OPT_SHORTCUT_BUTTONS_ID or "SeatSleepShortcuts"
YD.OPT_BUTTON_TOOLTIPS_ID = YD.OPT_BUTTON_TOOLTIPS_ID or "ButtonTooltips"
YD.OPT_ENGINE_CONDITION_HOVER_ID = YD.OPT_ENGINE_CONDITION_HOVER_ID or "EngineConditionHover"

-- This is a per-player UI preference.  Only an absent option gets the default;
-- an existing saved choice is always respected on later game launches.
if YD._shortcutButtonsEnabled == nil then
    YD._shortcutButtonsEnabled = true
end
if YD._buttonTooltipsEnabled == nil then
    YD._buttonTooltipsEnabled = true
end
if YD._engineConditionHoverEnabled == nil then
    YD._engineConditionHoverEnabled = false
end

function YD.AreSeatSleepShortcutButtonsEnabled()
    return YD._shortcutButtonsEnabled ~= false
end

function YD.SetSeatSleepShortcutButtonsEnabled(value)
    local enabled = value ~= false
    local changed = YD._shortcutButtonsEnabled ~= enabled
    YD._shortcutButtonsEnabled = enabled
    return changed
end

function YD.AreButtonTooltipsEnabled()
    return YD._buttonTooltipsEnabled ~= false
end

function YD.GetClockTime12Hour()
    local gameTime = nil
    if getGameTime then
        local ok, value = pcall(getGameTime)
        if ok then gameTime = value end
    end
    if not gameTime and GameTime and GameTime.getInstance then
        local ok, value = pcall(GameTime.getInstance)
        if ok then gameTime = value end
    end
    if not gameTime then return nil end

    local hour = safeMethod(gameTime, "getHour")
    local minute = safeMethod(gameTime, "getMinutes")
    hour = tonumber(hour)
    minute = tonumber(minute)
    if hour == nil or minute == nil then
        local timeOfDay = tonumber(safeMethod(gameTime, "getTimeOfDay")) or 0
        timeOfDay = timeOfDay % 24
        hour = math.floor(timeOfDay)
        minute = (timeOfDay % 1) * 60
    end

    hour = math.floor(hour or 0) % 24
    minute = roundNearest(minute or 0)
    if minute >= 60 then
        hour = (hour + math.floor(minute / 60)) % 24
        minute = minute % 60
    elseif minute < 0 then
        local borrowedHours = math.ceil(-minute / 60)
        hour = (hour - borrowedHours) % 24
        minute = minute + borrowedHours * 60
    end

    local displayHour = hour % 12
    if displayHour == 0 then displayHour = 12 end
    return string.format("Time: %d:%02d", displayHour, minute)
end

function YD.SetButtonTooltipsEnabled(value)
    local enabled = value ~= false
    local changed = YD._buttonTooltipsEnabled ~= enabled
    YD._buttonTooltipsEnabled = enabled
    return changed
end

function YD.AreEngineConditionHoverEnabled()
    return YD._engineConditionHoverEnabled == true
end

function YD.SetEngineConditionHoverEnabled(value)
    local enabled = value == true
    local changed = YD._engineConditionHoverEnabled ~= enabled
    YD._engineConditionHoverEnabled = enabled
    return changed
end

YD.TEXTURE_SIZES = YD.TEXTURE_SIZES or {
    { key = "0.75x", scale = 0.75, label = "Small (0.75x)", fontKey = "NewSmall" },
    { key = "1x",    scale = 1.00, label = "Regular (1x)",   fontKey = "Small" },
    { key = "1.4x",  scale = 1.40, label = "Large (1.4x)",   fontKey = "Medium" },
    { key = "2x",    scale = 2.00, label = "Extra Large (2x)", fontKey = "Large" },
}

-- New installs default to Regular (1x); persisted ModOptions selections win.
YD.DEFAULT_TEXTURE_SIZE_INDEX = 2
YD._textureSizeIndex = tonumber(YD._textureSizeIndex) or YD.DEFAULT_TEXTURE_SIZE_INDEX
YD._scaleListeners = YD._scaleListeners or newWeakKeyTable()

function YD.NormalizeTextureSizeIndex(value)
    if value == nil then
        value = YD._textureSizeIndex or YD.DEFAULT_TEXTURE_SIZE_INDEX
    end

    if type(value) == "string" then
        for index = 1, #YD.TEXTURE_SIZES do
            if YD.TEXTURE_SIZES[index].key == value then
                return index
            end
        end
        value = tonumber(value)
    end

    value = tonumber(value) or YD.DEFAULT_TEXTURE_SIZE_INDEX
    value = math.floor(value + 0.5)
    return clamp(value, 1, #YD.TEXTURE_SIZES)
end

function YD.TextureSizeIndex()
    return YD.NormalizeTextureSizeIndex(YD._textureSizeIndex)
end

function YD.TextureSize(value)
    return YD.TEXTURE_SIZES[YD.NormalizeTextureSizeIndex(value)]
end

function YD.ScaleKey(value)
    local size = YD.TextureSize(value)
    return size and size.key or "1x"
end

function YD.Scale(value)
    local size = YD.TextureSize(value)
    return size and size.scale or 1.0
end

-- Getter aliases keep call sites readable and provide a narrow compatibility
-- bridge for the existing dashboard/radio patches while they are migrated.
YD.GetScaleKey = YD.ScaleKey
YD.GetScale = YD.Scale

function YD.Round(value)
    return roundNearest(value)
end

function YD.ScaledCoord(value, sizeIndexOrKey)
    return roundNearest((tonumber(value) or 0) * YD.Scale(sizeIndexOrKey))
end

YD.ScaleCoord = YD.ScaledCoord
YD.RoundScaled = YD.ScaledCoord

function YD.ScaledPoint(x, y, sizeIndexOrKey)
    return YD.ScaledCoord(x, sizeIndexOrKey), YD.ScaledCoord(y, sizeIndexOrKey)
end

function YD.FontKeyForScale(sizeIndexOrKey)
    local size = YD.TextureSize(sizeIndexOrKey)
    return (size and size.fontKey) or "Small"
end

function YD.FontForScale(sizeIndexOrKey)
    local key = YD.FontKeyForScale(sizeIndexOrKey)
    if UIFont then
        return UIFont[key] or UIFont.Small or UIFont.Medium or UIFont.Large
    end
    return nil
end

YD.GetUIFont = YD.FontForScale

function YD.FontHeightForScale(sizeIndexOrKey)
    local font = YD.FontForScale(sizeIndexOrKey)
    if not font or not getTextManager then return nil end

    local ok, manager = pcall(getTextManager)
    if not ok or not manager or not manager.getFontHeight then return nil end

    local okHeight, height = pcall(function()
        return manager:getFontHeight(font)
    end)
    if okHeight then return height end
    return nil
end

-- Physical line heights used while the dashboard layouts were authored.
-- B42's UI Font Size option replaces the backing atlas; renderers divide
-- these reference heights by the loaded atlas height so the final dashboard
-- text occupies the same pixels on every client.  A compact font step is used
-- by the two-row sport climate/LCD layouts.
YD.REFERENCE_FONT_HEIGHTS = YD.REFERENCE_FONT_HEIGHTS or {
    ["0.75x"] = { base = 16, compact = 16 },
    ["1x"] = { base = 16, compact = 16 },
    ["1.4x"] = { base = 23, compact = 16 },
    ["2x"] = { base = 26, compact = 23 },
}

function YD.ReferenceFontHeightForScale(sizeIndexOrKey, fontStep)
    local key = YD.ScaleKey(sizeIndexOrKey)
    local heights = YD.REFERENCE_FONT_HEIGHTS[key] or YD.REFERENCE_FONT_HEIGHTS["1x"]
    if (tonumber(fontStep) or 0) < 0 then return heights.compact end
    return heights.base
end

function YD.FontNormalizationZoom(font, sizeIndexOrKey, fontStep)
    if not font or not getTextManager then return 1 end
    local ok, manager = pcall(getTextManager)
    if not ok or not manager or not manager.getFontHeight then return 1 end
    local okHeight, actualHeight = pcall(function() return manager:getFontHeight(font) end)
    actualHeight = okHeight and tonumber(actualHeight) or nil
    if not actualHeight or actualHeight <= 0 then return 1 end
    return YD.ReferenceFontHeightForScale(sizeIndexOrKey, fontStep) / actualHeight
end

function YD.AddScaleChangeListener(listener)
    if type(listener) ~= "function" then return false end
    YD._scaleListeners[listener] = true
    return true
end

function YD.RemoveScaleChangeListener(listener)
    if listener == nil then return end
    YD._scaleListeners[listener] = nil
end

local function notifyScaleChanged()
    local index = YD.TextureSizeIndex()
    local key = YD.ScaleKey(index)
    local scale = YD.Scale(index)
    for listener in pairs(YD._scaleListeners or {}) do
        pcall(listener, index, key, scale)
    end
end

function YD.SetTextureSizeIndex(value, silent)
    local index = YD.NormalizeTextureSizeIndex(value)
    if YD._textureSizeIndex == index then return false end
    YD._textureSizeIndex = index
    if silent ~= true then notifyScaleChanged() end
    return true
end

local function getModOptionsSection(createIfMissing)
    if not PZAPI or not PZAPI.ModOptions then return nil end

    local ok, section = pcall(function()
        return PZAPI.ModOptions:getOptions(YD.MODOPT_ID)
    end)
    if not ok then section = nil end

    if not section and createIfMissing then
        ok, section = pcall(function()
            return PZAPI.ModOptions:create(YD.MODOPT_ID, YD.MODOPT_NAME)
        end)
        if not ok then section = nil end
    end

    return section
end

local function getSectionOption(section, optionId)
    if not section or not section.getOption then return nil end
    local ok, option = pcall(function()
        return section:getOption(optionId)
    end)
    if ok then return option end
    return nil
end

function YD.ReadTextureSizeOption(section)
    section = section or getModOptionsSection(false)
    local option = getSectionOption(section, YD.OPT_TEXSIZE_ID)
    if not option or not option.getValue then
        YD.SetTextureSizeIndex(YD.DEFAULT_TEXTURE_SIZE_INDEX, true)
        return YD.TextureSizeIndex()
    end

    local ok, value = pcall(function()
        return option:getValue()
    end)
    if not ok then value = YD.DEFAULT_TEXTURE_SIZE_INDEX end
    YD.SetTextureSizeIndex(value)
    return YD.TextureSizeIndex()
end

function YD.ReadShortcutButtonsOption(section)
    section = section or getModOptionsSection(false)
    local option = getSectionOption(section, YD.OPT_SHORTCUT_BUTTONS_ID)
    if not option or not option.getValue then
        YD.SetSeatSleepShortcutButtonsEnabled(true)
        return YD.AreSeatSleepShortcutButtonsEnabled()
    end

    local ok, value = pcall(function()
        return option:getValue()
    end)
    if not ok or value == nil then value = true end
    YD.SetSeatSleepShortcutButtonsEnabled(value == true)
    return YD.AreSeatSleepShortcutButtonsEnabled()
end

function YD.ReadButtonTooltipsOption(section)
    section = section or getModOptionsSection(false)
    local option = getSectionOption(section, YD.OPT_BUTTON_TOOLTIPS_ID)
    if not option or not option.getValue then
        YD.SetButtonTooltipsEnabled(true)
        return YD.AreButtonTooltipsEnabled()
    end

    local ok, value = pcall(function()
        return option:getValue()
    end)
    if not ok or value == nil then value = true end
    YD.SetButtonTooltipsEnabled(value == true)
    return YD.AreButtonTooltipsEnabled()
end

function YD.ReadEngineConditionHoverOption(section)
    section = section or getModOptionsSection(false)
    local option = getSectionOption(section, YD.OPT_ENGINE_CONDITION_HOVER_ID)
    if not option or not option.getValue then
        YD.SetEngineConditionHoverEnabled(false)
        return YD.AreEngineConditionHoverEnabled()
    end

    local ok, value = pcall(function()
        return option:getValue()
    end)
    if not ok or value == nil then value = false end
    YD.SetEngineConditionHoverEnabled(value == true)
    return YD.AreEngineConditionHoverEnabled()
end

function YD.RegisterTextureSizeOption()
    -- Build 42 normally already has this available.  The guarded require makes
    -- the module harmless in standalone tests and early loading phases.
    pcall(require, "PZAPI/ModOptions")

    local section = getModOptionsSection(true)
    if not section then return nil end

    local option = getSectionOption(section, YD.OPT_TEXSIZE_ID)
    if not option and section.addComboBox then
        pcall(function()
            if section.addTitle then section:addTitle("UI Size") end
            if section.addDescription then
                section:addDescription("Choose the dashboard asset resolution.")
            end

            local combo = section:addComboBox(
                YD.OPT_TEXSIZE_ID,
                "Dashboard texture size",
                nil
            )
            if combo and combo.addItem then
                for index = 1, #YD.TEXTURE_SIZES do
                    local size = YD.TEXTURE_SIZES[index]
                    combo:addItem(size.label, index == YD.DEFAULT_TEXTURE_SIZE_INDEX)
                end
            end
        end)
        option = getSectionOption(section, YD.OPT_TEXSIZE_ID)
    end

    -- Cooperate with other options in the same section instead of replacing
    -- their apply behavior.
    if not section.__YourDashCoreTextureApplyWrapped then
        section.__YourDashCoreTextureApplyWrapped = true
        local previousApply = section.apply
        section.apply = function(self, ...)
            if previousApply then pcall(previousApply, self, ...) end
            YD.ReadTextureSizeOption(self)
        end
    end

    YD.ReadTextureSizeOption(section)
    return option
end

function YD.RegisterShortcutButtonsOption()
    pcall(require, "PZAPI/ModOptions")

    local section = getModOptionsSection(true)
    if not section then return nil end

    local option = getSectionOption(section, YD.OPT_SHORTCUT_BUTTONS_ID)
    if not option and section.addTickBox then
        pcall(function()
            if section.addSeparator then section:addSeparator() end
            if section.addTitle then section:addTitle("Dashboard shortcuts") end
            if section.addDescription then
                section:addDescription("Show the seat-switch and sleep shortcuts beside vehicle dashboards.")
            end
            option = section:addTickBox(
                YD.OPT_SHORTCUT_BUTTONS_ID,
                "Show seat-switch and sleep shortcuts",
                true
            )
        end)
        option = option or getSectionOption(section, YD.OPT_SHORTCUT_BUTTONS_ID)
    end

    if not section.__YourDashCoreShortcutApplyWrapped then
        section.__YourDashCoreShortcutApplyWrapped = true
        local previousApply = section.apply
        section.apply = function(self, ...)
            if previousApply then pcall(previousApply, self, ...) end
            YD.ReadShortcutButtonsOption(self)
        end
    end

    YD.ReadShortcutButtonsOption(section)
    return option
end

function YD.RegisterEngineConditionHoverOption()
    pcall(require, "PZAPI/ModOptions")

    local section = getModOptionsSection(true)
    if not section then return nil end

    local buttonOption = getSectionOption(section, YD.OPT_BUTTON_TOOLTIPS_ID)
    local engineOption = getSectionOption(section, YD.OPT_ENGINE_CONDITION_HOVER_ID)
    if section.addTickBox then
        pcall(function()
            if not section.__YourDashCoreTooltipSectionAdded then
                if section.addSeparator then section:addSeparator() end
                if section.addTitle then section:addTitle("Tooltips") end
                if section.addDescription then
                    section:addDescription("Choose which dashboard tooltips to show.")
                end
                section.__YourDashCoreTooltipSectionAdded = true
            end

            if not buttonOption then
                buttonOption = section:addTickBox(
                    YD.OPT_BUTTON_TOOLTIPS_ID,
                    "Show button tooltips",
                    true
                )
            end
            if not engineOption then
                engineOption = section:addTickBox(
                    YD.OPT_ENGINE_CONDITION_HOVER_ID,
                    "Show engine condition when hovering mouse over check/stop engine light",
                    false
                )
            end
        end)
        buttonOption = buttonOption or getSectionOption(section, YD.OPT_BUTTON_TOOLTIPS_ID)
        engineOption = engineOption or getSectionOption(section, YD.OPT_ENGINE_CONDITION_HOVER_ID)
    end

    if not section.__YourDashCoreTooltipApplyWrapped then
        section.__YourDashCoreTooltipApplyWrapped = true
        local previousApply = section.apply
        section.apply = function(self, ...)
            if previousApply then pcall(previousApply, self, ...) end
            YD.ReadButtonTooltipsOption(self)
            YD.ReadEngineConditionHoverOption(self)
        end
    end

    YD.ReadButtonTooltipsOption(section)
    YD.ReadEngineConditionHoverOption(section)
    return engineOption
end

function YD.InstallDashboardCoreEvents()
    if YD.__DashboardCoreEventsInstalled then return end
    YD.__DashboardCoreEventsInstalled = true

    if Events and Events.OnGameBoot and Events.OnGameBoot.Add then
        pcall(function()
            Events.OnGameBoot.Add(function()
                YD.RegisterTextureSizeOption()
                YD.RegisterShortcutButtonsOption()
                YD.RegisterEngineConditionHoverOption()
            end)
        end)
    end
    if Events and Events.OnGameStart and Events.OnGameStart.Add then
        pcall(function()
            Events.OnGameStart.Add(function()
                YD.ReadTextureSizeOption()
                YD.ReadShortcutButtonsOption()
                YD.ReadButtonTooltipsOption()
                YD.ReadEngineConditionHoverOption()
            end)
        end)
    end
end

-- -------------------------------------------------------------------------
-- Texture paths and cache
-- -------------------------------------------------------------------------

YD._textureCache = YD._textureCache or {}

function YD.InvalidateTextureCache(prefix)
    if prefix == nil or prefix == "" then
        YD._textureCache = {}
        return
    end

    prefix = tostring(prefix)
    for path in pairs(YD._textureCache or {}) do
        if string.find(path, prefix, 1, true) == 1 then
            YD._textureCache[path] = nil
        end
    end
end

function YD.LoadTexture(path)
    path = cleanRelativePath(path)
    if not path then return nil end

    local cached = YD._textureCache[path]
    if cached ~= nil then
        return cached or nil
    end

    if not getTexture then return nil end
    local ok, texture = pcall(getTexture, path)
    if not ok then texture = nil end
    YD._textureCache[path] = texture or false
    return texture
end

function YD.NormalizeFamily(family)
    if family == 1 then return "standard" end
    if family == 2 then return "heavy" end
    if family == 3 then return "sport" end
    if family == nil then return "standard" end

    local key = string.lower(tostring(family))
    if key == "standard" or key == "normal" then return "standard" end
    if key == "heavy" or key == "heavy-duty" or key == "heavyduty" then return "heavy" end
    if key == "sport" or key == "sports" then return "sport" end
    return nil
end

function YD.DashboardTexturePath(family, group, fileName, sizeIndexOrKey)
    family = YD.NormalizeFamily(family)
    group = cleanRelativePath(group)
    fileName = cleanRelativePath(fileName)
    if not family or not group or not fileName then return nil end

    return "media/ui/vehicles/" .. family .. "/" .. group .. "/"
        .. YD.ScaleKey(sizeIndexOrKey) .. "/" .. fileName
end

function YD.RadioTexturePath(tier, fileName, sizeIndexOrKey)
    if tier == nil then return nil end
    tier = string.lower(tostring(tier))
    if tier == "value" then tier = "standard" end
    if tier ~= "standard" and tier ~= "premium" then return nil end

    fileName = cleanRelativePath(fileName)
    if not fileName then return nil end

    return "media/ui/vehicles/radio/" .. tier .. "/"
        .. YD.ScaleKey(sizeIndexOrKey) .. "/" .. fileName
end

function YD.ResolveDashboardTexture(family, group, fileName, sizeIndexOrKey, fallbackSizeKey)
    local path = YD.DashboardTexturePath(family, group, fileName, sizeIndexOrKey)
    local texture = path and YD.LoadTexture(path) or nil
    local usedKey = YD.ScaleKey(sizeIndexOrKey)

    if not texture and fallbackSizeKey and YD.ScaleKey(fallbackSizeKey) ~= usedKey then
        usedKey = YD.ScaleKey(fallbackSizeKey)
        path = YD.DashboardTexturePath(family, group, fileName, usedKey)
        texture = path and YD.LoadTexture(path) or nil
    end

    return texture, path, usedKey
end

function YD.ResolveRadioTexture(tier, fileName, sizeIndexOrKey, fallbackSizeKey)
    local path = YD.RadioTexturePath(tier, fileName, sizeIndexOrKey)
    local texture = path and YD.LoadTexture(path) or nil
    local usedKey = YD.ScaleKey(sizeIndexOrKey)

    if not texture and fallbackSizeKey and YD.ScaleKey(fallbackSizeKey) ~= usedKey then
        usedKey = YD.ScaleKey(fallbackSizeKey)
        path = YD.RadioTexturePath(tier, fileName, usedKey)
        texture = path and YD.LoadTexture(path) or nil
    end

    return texture, path, usedKey
end

function YD.GetDashboardTexture(family, group, fileName, sizeIndexOrKey, fallbackFamily)
    -- A family string in argument four is a convenient shorthand for a
    -- one-off family fallback while retaining the current selected scale.
    local maybeFamily = YD.NormalizeFamily(sizeIndexOrKey)
    if maybeFamily and type(sizeIndexOrKey) == "string" and
        sizeIndexOrKey ~= "0.75x" and sizeIndexOrKey ~= "1x" and
        sizeIndexOrKey ~= "1.4x" and sizeIndexOrKey ~= "2x"
    then
        fallbackFamily = maybeFamily
        sizeIndexOrKey = nil
    end

    local texture, path, usedKey = YD.ResolveDashboardTexture(family, group, fileName, sizeIndexOrKey)
    if not texture and fallbackFamily then
        texture, path, usedKey = YD.ResolveDashboardTexture(fallbackFamily, group, fileName, sizeIndexOrKey)
    end
    return texture, path, usedKey
end

function YD.GetRadioTexture(tier, fileName, sizeIndexOrKey)
    return YD.ResolveRadioTexture(tier, fileName, sizeIndexOrKey)
end

-- -------------------------------------------------------------------------
-- Vehicle family / sport-accent classification
-- -------------------------------------------------------------------------

YD._vehicleProfileCache = YD._vehicleProfileCache or newWeakKeyTable()

local function shortScriptName(scriptName)
    if scriptName == nil then return nil end
    local name = tostring(scriptName)
    return string.match(name, "([^%.]+)$") or name
end

function YD.CountDistinctPassengerDoors(vehicle)
    if not vehicle then return 0 end

    local maximum = safeMethod(vehicle, "getMaxPassengers")
    maximum = tonumber(maximum) or 0
    maximum = clamp(math.floor(maximum), 0, 64)

    local seen = {}
    local count = 0
    for seat = 0, maximum - 1 do
        local door = safeMethod(vehicle, "getPassengerDoor", seat)
        if door then
            local partId = safeMethod(door, "getId")
            local identity = partId and ("id:" .. tostring(partId)) or door
            if not seen[identity] then
                seen[identity] = true
                count = count + 1
            end
        end
    end

    return count
end

function YD.ClassifyVehicle(vehicle)
    local script = safeMethod(vehicle, "getScript")
    local mechanicTypeValue = safeMethod(script, "getMechanicType")
    local mechanicType = tonumber(mechanicTypeValue) or 1
    mechanicType = math.floor(mechanicType)

    local family = YD.NormalizeFamily(mechanicType) or "standard"
    -- Prefer the live script object.  Debug vehicle respawning can reuse the
    -- same BaseVehicle wrapper while replacing its script, leaving a cached
    -- vehicle-level name stale for a frame.
    local scriptName = safeMethod(script, "getName")
        or safeMethod(script, "getFullName")
        or safeMethod(vehicle, "getScriptName")
        or ""
    local shortName = shortScriptName(scriptName) or ""
    local doorCount = YD.CountDistinctPassengerDoors(vehicle)

    local accent = "base"
    if family == "sport" then
        if shortName == "CarLuxury" then
            accent = "lux"
        elseif doorCount == 2 then
            accent = "sport"
        end
    end

    local accentColor = "black"
    if accent == "lux" then
        accentColor = "wood"
    elseif accent == "sport" then
        accentColor = "red"
    end

    return {
        family = family,
        accent = accent,
        accentColor = accentColor,
        dashFile = family == "sport" and ("dash_" .. accent .. ".png") or "dash.png",
        mechanicType = mechanicType,
        scriptName = tostring(scriptName),
        shortScriptName = shortName,
        passengerDoorCount = doorCount,
        key = family .. ":" .. accent,
        identity = tostring(mechanicType) .. ":" .. shortName .. ":" .. tostring(doorCount),
    }
end

function YD.GetVehicleProfile(vehicle, refresh)
    if not vehicle then
        return YD.ClassifyVehicle(nil)
    end

    local cached = YD._vehicleProfileCache[vehicle]
    -- Rebuild a cheap candidate even when the Java object is unchanged.  This
    -- makes debug respawns/script swaps deterministic while preserving the old
    -- cached table when the live mechanic type, script name, and door topology
    -- are still identical.
    local profile = YD.ClassifyVehicle(vehicle)
    if refresh ~= true and cached and cached.identity == profile.identity then
        return cached
    end
    YD._vehicleProfileCache[vehicle] = profile
    return profile
end

function YD.InvalidateVehicleProfile(vehicle)
    if vehicle == nil then
        YD._vehicleProfileCache = newWeakKeyTable()
    else
        YD._vehicleProfileCache[vehicle] = nil
    end
end

YD.VehicleProfile = YD.GetVehicleProfile
YD.InvalidateProfile = YD.InvalidateVehicleProfile

function YD.InvalidateDashboardCoreCaches(vehicle)
    YD.InvalidateTextureCache()
    YD.InvalidateVehicleProfile(vehicle)
end

-- -------------------------------------------------------------------------
-- One-scale layout data.  Coordinates are authored at 1x and should be fed
-- through ScaledCoord/ScaledPoint.  Sparse sections intentionally allow later
-- art-tuning without duplicating all four resolutions.
-- -------------------------------------------------------------------------

local DEFAULT_LAYOUTS_1X = {
    standard = {
        canvas = { width = 745, height = 172 },
        gauges = {
            dash = { x = 0, y = 0 },
            rpm = { x = 211, y = 110 },
            speed = { x = 428, y = 110 },
            fuel = { x = 320, y = 58 },
        },
        warnings = {
            cruise = { x = 388, y = 127 },
            battery = { x = 296, y = 123 },
            brake = { x = 295, y = 97 },
            check = { x = 201, y = 125 },
            stop = { x = 231, y = 139 },
            door = { x = 324, y = 120 },
            fuel = { x = 325, y = 97 },
            light = { x = 257, y = 27 },
        },
        controls = {
            speedreg = { x = 388, y = 127 },
            gear = { x = 176, y = 128 },
            engine = { x = 208, y = 68 },
            battery = { x = 234, y = 68 },
            lights = { x = 66, y = 130 },
            ignition = { x = 540, y = 128 },
            fuelArrow = { x = 331, y = 53 },
            fuelArrowLeft = { x = 331, y = 53 },
            fuelArrowRight = { x = 331, y = 53 },
            door = { x = 36, y = 64 },
            trunk = { x = 79, y = 64 },
            window = { x = 15, y = 109 }, windowDown = { x = 15, y = 110 }, windowUp = { x = 15, y = 108 },
        },
        ac = {
            fan = { x = 592, y = 127 },
            slider = { x = 622, y = 131, travel = 92 },
        },
        radio = {
            standard = { x = 550, y = 62 },
            premium = { x = 539, y = 57 },
        },
        radioStandard = { x = 550, y = 62 },
        radioPremium = { x = 539, y = 57 },
        passenger = {
            toggle = { x = 22, y = 18 },
            door = { x = 214, y = 98 },
            window = { x = 244, y = 89 },
            acFan = { x = 24, y = 98 },
            acSlider = { x = 57, y = 105, travel = 127 },
            radioPremium = { x = 10, y = 35 },
            radioStandard = { x = 50, y = 30 },
        },
    },
    heavy = {
        canvas = { width = 735, height = 180 },
        -- Red pivot pixels embedded in the supplied 1x gauge art.
        gauges = {
            dash = { x = 0, y = 0 },
            rpm = { x = 168, y = 97 },
            speed = { x = 324, y = 99 },
            fuel = { x = 457, y = 61 },
            voltage = { x = 457, y = 108 },
        },
        warnings = {
            check = { x = 137, y = 137 }, stop = { x = 169, y = 137 },
            fuel = { x = 414, y = 118 }, brake = { x = 443, y = 118 },
            battery = { x = 472, y = 118 }, cruise = { x = 323, y = 130 },
            door = { x = 426, y = 139 }, light = { x = 461, y = 139 },
        },
        controls = {
            speedreg = { x = 323, y = 130 }, gear = { x = 299, y = 136 },
            door = { x = 13, y = 90 }, trunk = { x = 52, y = 90 },
            doorLED = { x = 15, y = 82 }, trunkLED = { x = 54, y = 82 },
            window = { x = 8, y = 132 }, windowDown = { x = 8, y = 132 }, windowUp = { x = 8, y = 132 },
            lights = { x = 11, y = 106 },
            ignition = { x = 526, y = 136 },
            fuelArrowLeft = { x = 414, y = 55 }, fuelArrowRight = { x = 483, y = 55 },
            fuelArrow = { x = 414, y = 55 },
        },
        ac = {
            background = { x = 570, y = 128 }, fan = { x = 590, y = 128 },
            slider = { x = 613, y = 135, travel = 91 },
        },
        radio = { standard = { x = 540, y = 72 }, premium = { x = 529, y = 67 } },
        radioStandard = { x = 540, y = 72 },
        radioPremium = { x = 529, y = 67 },
        passenger = {},
    },
    sport = {
        canvas = { width = 758, height = 179 },
        -- Red pivot pixels embedded in the supplied 1x gauge art.
        gauges = {
            dash = { x = 0, y = 0 },
            rpm = { x = 169, y = 96 },
            speed = { x = 314, y = 94 },
            fuel = { x = 445, y = 96 },
            voltage = { x = 475, y = 96 },
        },
        warnings = {
            stop = { x = 120, y = 162 }, check = { x = 146, y = 162 },
            light = { x = 172, y = 162 }, cruise = { x = 198, y = 162 },
            door = { x = 411, y = 162 }, fuel = { x = 437, y = 162 },
            brake = { x = 463, y = 162 }, battery = { x = 489, y = 162 },
        },
        controls = {
            speedreg = { x = 198, y = 162 }, gear = { x = 166, y = 115 },
            door = { x = 30, y = 69 }, trunk = { x = 65, y = 69 },
            doorLED = { x = 35, y = 104 }, trunkLED = { x = 70, y = 104 },
            window = { x = 11, y = 115 }, windowDown = { x = 11, y = 113 }, windowUp = { x = 11, y = 117 },
            lights = { x = 61, y = 128 },
            ignition = { x = 546, y = 129 },
            fuelArrowLeft = { x = 433, y = 134 }, fuelArrowRight = { x = 437, y = 119 },
            fuelArrow = { x = 433, y = 134 }, gaugeDisplayButton = { x = 385, y = 139 },
        },
        ac = {
            background = { x = 592, y = 117 },
            display = {
                x = 599, y = 120, width = 31, height = 23, textOffsetX = 0, textOffsetY = 1,
                textByScale = {
                    ["0.75x"] = { fontStep = -1, labelMaxZoom = 0.82, valueMaxZoom = 0.92, textPaddingY = 1 },
                    ["1x"] = { fontStep = -1, labelMaxZoom = 0.86, valueMaxZoom = 0.96, textPaddingY = 1 },
                },
            },
            fan = { x = 601, y = 144 }, displayButton = { x = 601, y = 160 },
            knob = { x = 640, y = 130 },
        },
        radio = { standard = { x = 557, y = 60 }, premium = { x = 546, y = 55 } },
        radioStandard = { x = 557, y = 60 },
        radioPremium = { x = 546, y = 55 },
        displays = { main = { x = 280, y = 139, width = 68, height = 25, textOffsetX = 0, textOffsetY = 1, fontStep = -1, valueMaxZoom = 1.0 } },
        clock = { background = { x = 699, y = 119 }, pivot = { x = 727, y = 147 } },
        passenger = {},
    },
}

-- Coordinates in this table are authored in final pixels for the named scale.
-- Missing points fall back to DEFAULT_LAYOUTS_1X and are scaled normally.
local DEFAULT_LAYOUTS_BY_SCALE = {
    ["0.75x"] = {
        standard = {
            controls = {
                gear = { x = 131, y = 93 },
            },
        },
        heavy = {
            controls = {
                door = { x = 10, y = 68 },
                gear = { x = 223, y = 99 },
                window = { x = 7, y = 100 },
            },
            ac = {
                fan = { x = 444, y = 96 },
            },
        },
        sport = {
            controls = {
                gear = { x = 123, y = 83 },
            },
        },
    },
    ["1x"] = {},
    ["1.4x"] = {
        standard = {
            controls = {
                gear = { x = 247, y = 178 },
            },
        },
        heavy = {
            controls = {
                door = { x = 19, y = 126 },
                trunkBlank = { x = 74, y = 126 },
                window = { x = 12, y = 186 },
            },
            ac = {
                fan = { x = 827, y = 179 },
            },
        },
        sport = {
            controls = {
                gear = { x = 232, y = 159 },
            },
        },
    },
    ["2x"] = {
        standard = {
            controls = {
                gear = { x = 353, y = 256 },
            },
        },
        heavy = {
            controls = {
                door = { x = 27, y = 180 },
                trunkBlank = { x = 105, y = 180 },
                window = { x = 17, y = 265 },
            },
            ac = {
                fan = { x = 1181, y = 256 },
            },
        },
    },
}

YD.Layouts1x = fillMissing(YD.Layouts1x or {}, DEFAULT_LAYOUTS_1X)
YD.LayoutsByScale = fillMissing(YD.LayoutsByScale or {}, DEFAULT_LAYOUTS_BY_SCALE)

function YD.GetLayout1x(family)
    family = YD.NormalizeFamily(family) or "standard"
    return YD.Layouts1x[family] or YD.Layouts1x.standard
end

local function layoutFamily(subject)
    local family = subject
    if type(subject) ~= "string" and type(subject) ~= "number" then
        local ok, value = pcall(function()
            return subject and subject.__YourDashFamily
        end)
        family = ok and value or nil

        if family == nil and subject ~= nil then
            local vehicle = subject
            local script = safeMethod(vehicle, "getScript")
            if script == nil then
                local okVehicle, dashboardVehicle = pcall(function()
                    return subject.vehicle
                end)
                if okVehicle then vehicle = dashboardVehicle end
                script = safeMethod(vehicle, "getScript")
            end
            if script ~= nil then
                family = YD.GetVehicleProfile(vehicle).family
            end
        end
    end
    return YD.NormalizeFamily(family) or "standard"
end

local function pointXY(point)
    if type(point) ~= "table" then return nil, nil end
    return tonumber(point.x or point[1]), tonumber(point.y or point[2])
end

-- Accept either a family name/mechanic type or a dashboard-like object.  The
-- returned table remains authored at 1x; callers decide which coordinates to
-- scale, avoiding accidental double-scaling of dimensions.
function YD.GetLayout(subject)
    return YD.GetLayout1x(layoutFamily(subject))
end

function YD.GetLayoutPoint(subject, sectionName, pointName, sizeIndexOrKey)
    local family = layoutFamily(subject)
    local scaleKey = YD.ScaleKey(sizeIndexOrKey)
    local scaleLayout = YD.LayoutsByScale and YD.LayoutsByScale[scaleKey]
    local scaleFamily = scaleLayout and scaleLayout[family]
    local scaleSection = scaleFamily and scaleFamily[sectionName]
    local scalePoint = scaleSection and scaleSection[pointName]
    local x, y = pointXY(scalePoint)
    if x ~= nil and y ~= nil then return x, y, scalePoint end

    local layout = YD.GetLayout1x(family)
    local section = layout and layout[sectionName]
    local point = section and section[pointName]
    if not point then return nil, nil end
    x, y = pointXY(point)
    if x == nil or y == nil then return nil, nil end
    local scaledX, scaledY = YD.ScaledPoint(x, y, sizeIndexOrKey)
    return scaledX, scaledY, point
end

-- -------------------------------------------------------------------------
-- Gauge mappings (degrees; west is zero, matching the authored descriptions)
-- -------------------------------------------------------------------------

local DEFAULT_GAUGE_MAPPINGS = {
    standard = {
        rpm = {
            needle = "long", units = "rpm",
            minValue = 0, maxValue = 7000, minAngle = 0, maxAngle = 210,
        },
        speed = {
            needle = "long", units = "mph",
            points = {
                { value = 0, angle = 0 },
                { value = 20, angle = 22.5 },
                { value = 120, angle = 210 },
            },
        },
        fuel = {
            needle = "short", units = "ratio",
            minValue = 0, maxValue = 1, minAngle = 20, maxAngle = 160,
        },
    },
    heavy = {
        rpm = {
            needle = "mid", units = "rpm",
            minValue = 0, maxValue = 6000, minAngle = -30, maxAngle = 210,
        },
        speed = {
            needle = "long", units = "mph",
            points = {
                { value = 0, angle = -30 },
                { value = 5, angle = -30 },
                { value = 90, angle = 225 },
            },
        },
        fuel = {
            needle = "short", units = "ratio",
            minValue = 0, maxValue = 1, minAngle = 25, maxAngle = 155,
        },
        voltage = {
            needle = "short", units = "volts",
            minValue = 8, maxValue = 18, minAngle = 25, maxAngle = 155,
        },
    },
    sport = {
        rpm = {
            needle = "mid", units = "rpm",
            minValue = 0, maxValue = 7000, minAngle = -45, maxAngle = 225,
        },
        speed = {
            needle = "long", units = "mph",
            minValue = 0, maxValue = 160, minAngle = -45, maxAngle = 225,
        },
        fuel = {
            needle = "short", units = "ratio",
            minValue = 0, maxValue = 1, minAngle = -65, maxAngle = 65,
        },
        voltage = {
            needle = "short", units = "volts", mirrored = true, mirrorOf = "fuel",
            minValue = 8, maxValue = 16, minAngle = 245, maxAngle = 115,
        },
    },
}

YD.GaugeMappings = fillMissing(YD.GaugeMappings or {}, DEFAULT_GAUGE_MAPPINGS)

function YD.GetGaugeMapping(family, gaugeName)
    family = YD.NormalizeFamily(family) or "standard"
    local familyMappings = YD.GaugeMappings[family] or YD.GaugeMappings.standard
    return familyMappings and familyMappings[gaugeName] or nil
end

function YD.MapGaugeAngle(family, gaugeName, value)
    local mapping = YD.GetGaugeMapping(family, gaugeName)
    value = tonumber(value)
    if not mapping or value == nil then return nil end

    local points = mapping.points
    if type(points) == "table" and #points > 0 then
        if value <= points[1].value then return points[1].angle end
        if value >= points[#points].value then return points[#points].angle end

        for index = 2, #points do
            local right = points[index]
            if value <= right.value then
                local left = points[index - 1]
                local width = right.value - left.value
                if width == 0 then return right.angle end
                local t = (value - left.value) / width
                return left.angle + (right.angle - left.angle) * t
            end
        end
        return points[#points].angle
    end

    local minimum = tonumber(mapping.minValue) or 0
    local maximum = tonumber(mapping.maxValue) or 1
    if mapping.clamp ~= false then value = clamp(value, minimum, maximum) end
    if maximum == minimum then return tonumber(mapping.minAngle) or 0 end

    local t = (value - minimum) / (maximum - minimum)
    local minAngle = tonumber(mapping.minAngle) or 0
    local maxAngle = tonumber(mapping.maxAngle) or minAngle
    return minAngle + (maxAngle - minAngle) * t
end

YD.InstallDashboardCoreEvents()
YD.__DashboardCoreLoaded = true

return YD
