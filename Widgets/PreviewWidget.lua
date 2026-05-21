local AddOnName, KeystonePolaris = ...
local AceGUI = LibStub("AceGUI-3.0")
local LSM = LibStub("LibSharedMedia-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale(AddOnName, true)

local widgetType = "KeystonePolaris_Preview"
local widgetVersion = 1

-- Scenario definitions (reused from RenderTestText in Display.lua)
local TOTAL_COUNT = 220
local SCENARIOS = {
    {
        name = L["PREVIEW_IDLE"] or "Mid-dungeon (idle)",
        currentPercent = 45.0, neededPercent = 50.0, pullPercent = 0.0,
        isBossKilled = false, colorKey = "inProgress", inCombat = false,
    },
    {
        name = L["PREVIEW_PULLING"] or "Mid-dungeon (pulling)",
        currentPercent = 45.0, neededPercent = 50.0, pullPercent = 3.0,
        isBossKilled = false, colorKey = "inProgress", inCombat = true,
        requiresMDT = true,
    },
    {
        name = L["PREVIEW_PROJECTED"] or "Projected completes section",
        currentPercent = 62.0, neededPercent = 68.0, pullPercent = 8.0,
        isBossKilled = false, colorKey = "inProgress", inCombat = true,
        requiresMDT = true,
    },
    {
        name = L["PREVIEW_SECTION_DONE"] or "Section complete",
        currentPercent = 74.0, neededPercent = 70.0, pullPercent = 0.0,
        isBossKilled = false, colorKey = "finished", inCombat = false,
    },
    {
        name = L["PREVIEW_MISSING"] or "Missing (boss killed)",
        currentPercent = 62.0, neededPercent = 68.0, pullPercent = 8.0,
        isBossKilled = true, colorKey = "missing", inCombat = true,
    },
    {
        name = L["PREVIEW_ALMOST_DONE"] or "Almost done (pulling)",
        currentPercent = 98.0, neededPercent = 100.0, pullPercent = 3.0,
        isBossKilled = false, colorKey = "inProgress", inCombat = true,
        requiresMDT = true,
    },
    {
        name = L["PREVIEW_DUNGEON_DONE"] or "Dungeon complete",
        isDungeonDone = true, colorKey = "finished", inCombat = false,
    },
}

-- Build fmtData from a scenario definition
local function BuildFmtData(s)
    local currentCount = math.floor((s.currentPercent / 100) * TOTAL_COUNT + 0.5)
    local pullCount = math.floor((s.pullPercent / 100) * TOTAL_COUNT + 0.5)
    local sectionRequiredCount = math.ceil((s.neededPercent / 100) * TOTAL_COUNT)
    local remainingCount = math.max(0, sectionRequiredCount - currentCount)
    return {
        currentCount = currentCount,
        totalCount = TOTAL_COUNT,
        pullCount = pullCount,
        remainingCount = remainingCount,
        sectionRequiredPercent = s.neededPercent,
        sectionRequiredCount = sectionRequiredCount,
    }
end

-- Render the preview text for a given scenario index
local function RenderPreview(widget, scenarioIndex)
    local addon = KeystonePolaris
    if not (addon and addon.db and addon.db.profile and addon.FormatMainDisplayText) then return end

    local s = SCENARIOS[scenarioIndex]
    if not s then return end

    local text, textColor
    if s.isDungeonDone then
        text = L["DUNGEON_DONE"] or "Dungeon finished"
        textColor = addon.db.profile.color[s.colorKey]
    else
        local cfg = addon.db.profile.general.mainDisplay
        local formatMode = (cfg and cfg.formatMode) or "percent"
        local remainingPercent = math.max(0, s.neededPercent - s.currentPercent)
        local fmtData = BuildFmtData(s)

        local base
        if s.currentPercent >= s.neededPercent and not s.isBossKilled then
            base = L["DONE"] or "Section percentage done"
        else
            if formatMode == "count" then
                base = tostring(fmtData.remainingCount)
            else
                base = string.format("%.2f%%", remainingPercent)
            end
        end

        -- Temporarily override combat context for projected values
        local origTest = addon._testMode
        local origCtx = addon._testCombatContext
        addon._testMode = true
        addon._testCombatContext = s.inCombat

        -- Ensure color cache is populated
        if addon.UpdateColorCache then addon:UpdateColorCache() end
        text = addon:FormatMainDisplayText(base, s.currentPercent, s.pullPercent, remainingPercent, fmtData)

        addon._testMode = origTest
        addon._testCombatContext = origCtx

        textColor = addon.db.profile.color[s.colorKey]
    end

    -- Update the widget's FontString
    local fontPath = LSM:Fetch("font", addon.db.profile.text.font)
    local fontSize = addon.db.profile.general.fontSize or 12
    local textOpacity = addon.db.profile.general.textOpacity or 1
    widget.previewText:SetFont(fontPath, fontSize, "OUTLINE")
    if textColor then
        widget.previewText:SetTextColor(textColor.r, textColor.g, textColor.b, 1)
    end
    widget.previewText:SetAlpha(textOpacity)
    widget.previewText:SetText(text or "")

    -- Apply text alignment based on settings
    local cfg = addon.db.profile.general.mainDisplay
    if cfg and cfg.multiLine then
        local align = cfg.textAlign or "CENTER"
        widget.previewText:SetJustifyH(align)
    else
        widget.previewText:SetJustifyH("CENTER")
    end

    -- Adjust frame height based on line count
    local lineCount = 1
    if text then
        local _, count = text:gsub("\n", "")
        lineCount = count + 1
    end
    local height = math.max(60, (lineCount * fontSize) + 20)
    widget.frame:SetHeight(height)
    if widget.SetHeight then widget:SetHeight(height) end
end

-- Widget methods
local methods = {}

function methods.OnAcquire(self)
    self.scenarioIndex = 1
    self:SetHeight(80)
    self:SetFullWidth(true)
    KeystonePolaris._previewWidget = self
end

function methods.OnRelease(self)
    self.scenarioIndex = nil
    if KeystonePolaris._previewWidget == self then
        KeystonePolaris._previewWidget = nil
    end
end

function methods.SetValue(self, value)
    self.scenarioIndex = value or 1
    RenderPreview(self, self.scenarioIndex)
end

function methods.GetValue(self)
    return self.scenarioIndex
end

function methods.SetLabel(_, _)
    -- No label needed for preview
end

function methods.SetDisabled(self, disabled)
    if disabled then
        self.frame:SetAlpha(0.5)
    else
        self.frame:SetAlpha(1.0)
    end
end

function methods.SetText(_, _)
    -- Not used; rendering is driven by SetValue/scenario
end

function methods.SetList(_, _)
    -- Not applicable
end

function methods.RefreshPreview(self)
    RenderPreview(self, self.scenarioIndex or 1)
end

-- Constructor
local function Constructor()
    local frame = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    frame:SetHeight(80)
    frame:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    frame:SetBackdropColor(0.1, 0.1, 0.1, 0.9)
    frame:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.8)

    local text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    text:SetPoint("LEFT", frame, "LEFT", 10, 0)
    text:SetPoint("RIGHT", frame, "RIGHT", -10, 0)
    text:SetWordWrap(true)

    local widget = {}
    widget.type = widgetType
    widget.frame = frame
    widget.previewText = text
    frame.obj = widget

    for method, func in pairs(methods) do
        widget[method] = func
    end

    -- Listen for config changes to auto-refresh
    local ACR = LibStub("AceConfigRegistry-3.0", true)
    if ACR then
        ACR.RegisterCallback(widget, "ConfigTableChange", function(_, appName)
            -- scenarioIndex is nil when widget is released back to the AceGUI pool
            if appName == AddOnName and widget.scenarioIndex then
                RenderPreview(widget, widget.scenarioIndex)
            end
        end)
    end

    AceGUI:RegisterAsWidget(widget)
    return widget
end

AceGUI:RegisterWidgetType(widgetType, Constructor, widgetVersion)

-- Export scenarios for the dropdown in Options.lua
KeystonePolaris.PreviewScenarios = SCENARIOS
