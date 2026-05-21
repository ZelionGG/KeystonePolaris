local AddOnName, KeystonePolaris = ...
local AceGUI = LibStub("AceGUI-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale(AddOnName, true)

local widgetType = "KeystonePolaris_ProgressBarPreview"
local widgetVersion = 1

local CreateFrame = CreateFrame
local CreateColor = CreateColor
local math_max = math.max
local math_min = math.min
local pairs = pairs
local table_sort = table.sort
local string_format = string.format

local function Lerp(startValue, endValue, amount)
    return startValue + (endValue - startValue) * amount
end

local function CreateColorFromTable(color)
    return CreateColor(color.r, color.g, color.b, color.a or 1)
end

local function InterpolateColor(startColor, endColor, amount)
    return CreateColor(
        Lerp(startColor.r, endColor.r, amount),
        Lerp(startColor.g, endColor.g, amount),
        Lerp(startColor.b, endColor.b, amount),
        Lerp(startColor.a or 1, endColor.a or 1, amount)
    )
end

local function GetProgressBarColors(addon)
    local pb = addon.db.profile.progressBar
    if pb.overrideColors then
        return pb.completedColor, pb.inProgressColor, pb.missingColor
    end
    local textColors = addon.db.profile.color
    return textColors.finished, textColors.inProgress, textColors.missing
end

local function GetProgressBarGradientColor(addon, positionPct)
    local pb = addon.db.profile.progressBar
    local amount = math_max(0, math_min(positionPct / 100, 1))
    return InterpolateColor(pb.gradientStartColor, pb.gradientEndColor, amount)
end

local function ResolvePreviewDungeonKey(addon)
    if addon._progressBarDungeonKey and addon.GlobalDungeonLookup and addon.GlobalDungeonLookup[addon._progressBarDungeonKey] then
        return addon._progressBarDungeonKey
    end

    local currentDate
    if C_DateAndTime and C_DateAndTime.GetCurrentCalendarTime then
        local t = C_DateAndTime.GetCurrentCalendarTime()
        currentDate = string_format("%04d-%02d-%02d", t.year, t.month, t.monthDay)
    else
        currentDate = "2026-01-01"
    end

    local seasonId = addon.GetSeasonByDate and addon:GetSeasonByDate(currentDate)
    if seasonId then
        local seasonTable = addon[seasonId .. "_DUNGEONS"]
        if seasonTable then
            for dungeonId in pairs(seasonTable) do
                if type(dungeonId) == "number" and addon.GetDungeonKeyById then
                    local dungeonKey = addon:GetDungeonKeyById(dungeonId)
                    if dungeonKey then
                        return dungeonKey
                    end
                end
            end
        end
    end

    if addon.GlobalDungeonLookup then
        return next(addon.GlobalDungeonLookup)
    end
end

local function BuildPreviewThresholds(addon, dungeonKey)
    local dungeonData = addon.GlobalDungeonLookup and addon.GlobalDungeonLookup[dungeonKey]
    if not dungeonData or not dungeonData.bosses then return {}, nil end

    local adv = addon.db and addon.db.profile and addon.db.profile.advanced and addon.db.profile.advanced[dungeonKey]
    local thresholds = {}
    for i, boss in pairs(dungeonData.bosses) do
        local pct
        if adv then
            pct = adv["Boss" .. tostring(boss[1])]
        end
        if not pct then
            pct = boss[2]
        end
        if pct and pct > 0 and pct < 100 then
            thresholds[#thresholds + 1] = {
                percent = pct,
                bossIndex = i,
                bossNum = boss[1],
            }
        end
    end

    table_sort(thresholds, function(a, b) return a.percent < b.percent end)
    return thresholds, dungeonData
end

local function BuildPreviewBossKillStates(scenario)
    local states = {}
    local bossesKilled = scenario and scenario.bossesKilled or 0
    for idx = 1, bossesKilled do
        states[idx] = true
    end
    return states
end

local function BuildPreviewSectionStates(addon, dungeonKey, thresholds, dungeonData, currentPct, bossKillStates)
    if not thresholds or #thresholds == 0 then return {} end

    local states = {}
    local boundaries = { 0 }
    local bossIndices = {}
    for i, t in pairs(thresholds) do
        boundaries[#boundaries + 1] = t.percent
        bossIndices[i] = t.bossIndex
    end
    boundaries[#boundaries + 1] = 100

    if not bossIndices[#boundaries - 1] and dungeonData and dungeonData.bosses then
        local adv = addon.db and addon.db.profile and addon.db.profile.advanced and addon.db.profile.advanced[dungeonKey]
        for bi, boss in pairs(dungeonData.bosses) do
            local pct = adv and adv["Boss" .. tostring(boss[1])] or boss[2]
            if pct and pct >= 100 then
                bossIndices[#boundaries - 1] = bi
                break
            end
        end
        if not bossIndices[#boundaries - 1] then
            bossIndices[#boundaries - 1] = #dungeonData.bosses
        end
    end

    for i = 1, #boundaries - 1 do
        local segEnd = boundaries[i + 1]
        local bossIdx = bossIndices[i]
        local isBossKilled = bossKillStates and bossIdx and bossKillStates[bossIdx] or false

        if currentPct >= segEnd then
            states[i] = "completed"
        elseif isBossKilled and currentPct < segEnd then
            states[i] = "missing"
        elseif currentPct > boundaries[i] then
            states[i] = "inProgress"
        else
            states[i] = "upcoming"
        end
    end

    return states
end

local function UpdateBorder(widget, pb)
    if pb.borderStyle == "NONE" then
        widget.borderFrame:SetBackdrop(nil)
        return
    end

    local edgeFile
    if pb.borderStyle == "SOLID" then
        edgeFile = "Interface\\Buttons\\WHITE8X8"
    elseif pb.borderStyle == "LSM_BORDER" then
        edgeFile = KeystonePolaris.LSM:Fetch("border", pb.borderTexture)
    end

    widget.borderFrame:SetBackdrop({
        edgeFile = edgeFile,
        edgeSize = pb.borderSize,
        insets = {
            left = pb.borderInsets,
            right = pb.borderInsets,
            top = pb.borderInsets,
            bottom = pb.borderInsets,
        },
    })
    widget.borderFrame:SetBackdropBorderColor(pb.borderColor.r, pb.borderColor.g, pb.borderColor.b, pb.borderColor.a)
end

local function UpdateCallout(widget, thresholds, currentPct, displayWidth, dungeonKey)
    local addon = KeystonePolaris
    local pb = addon.db.profile.progressBar
    if not pb.showCallout or not thresholds or #thresholds == 0 then
        widget.callout:Hide()
        return
    end

    local boundaries = { 0 }
    for _, t in pairs(thresholds) do
        boundaries[#boundaries + 1] = t.percent
    end
    boundaries[#boundaries + 1] = 100

    local activeIdx
    for i = 1, #boundaries - 1 do
        if currentPct < boundaries[i + 1] then
            activeIdx = i
            break
        end
    end
    if not activeIdx then
        activeIdx = #thresholds + 1
    end

    if activeIdx > #boundaries - 1 then
        widget.callout:Hide()
        return
    end

    local segStart = boundaries[activeIdx]
    local segEnd = boundaries[activeIdx + 1]
    local segCenter = (segStart + segEnd) / 2

    local bossIdx
    if activeIdx <= #thresholds then
        bossIdx = thresholds[activeIdx].bossIndex
    else
        bossIdx = thresholds[#thresholds] and thresholds[#thresholds].bossIndex
    end

    local bossName = ""
    if bossIdx and addon.GetBossName then
        bossName = addon:GetBossName(dungeonKey, bossIdx) or ("Boss " .. bossIdx)
    end

    widget.callout.text:SetText(string_format(L["PROGRESS_BAR_CALLOUT_FORMAT"], segEnd, bossName))
    widget.callout:SetSize(widget.callout.text:GetStringWidth() + 12, widget.callout.text:GetStringHeight() + 8)
    widget.callout.bg:SetAllPoints(widget.callout)

    local xPos = displayWidth * (segCenter / 100)
    if pb.direction == "RIGHT_TO_LEFT" then
        xPos = displayWidth - xPos
    end

    widget.callout:ClearAllPoints()
    if pb.calloutPosition == "BELOW" then
        widget.callout:SetPoint("TOP", widget.barFrame, "BOTTOM", xPos - displayWidth / 2, -4)
    else
        widget.callout:SetPoint("BOTTOM", widget.barFrame, "TOP", xPos - displayWidth / 2, 4)
    end
    widget.callout:Show()
end

local function RenderPreview(widget, scenarioIndex)
    local addon = KeystonePolaris
    if not (addon and addon.db and addon.db.profile and addon.LSM and addon.PreviewScenarios) then return end

    local pb = addon.db.profile.progressBar
    local scenario = addon.PreviewScenarios[scenarioIndex]
    if not scenario then return end

    local dungeonKey = ResolvePreviewDungeonKey(addon)
    local thresholds, dungeonData = BuildPreviewThresholds(addon, dungeonKey)
    local bossKillStates = BuildPreviewBossKillStates(scenario)
    local currentPct = scenario.barPercent or 0
    local sectionStates = BuildPreviewSectionStates(addon, dungeonKey, thresholds, dungeonData, currentPct, bossKillStates)

    local frameWidth = widget.frame:GetWidth()
    if not frameWidth or frameWidth <= 20 then
        frameWidth = pb.width + 20
    end
    local displayWidth = math_min(pb.width, math_max(80, frameWidth - 20))
    local calloutExtra = pb.showCallout and 28 or 0
    local previewHeight = math_max(70, pb.height + calloutExtra + 24)
    local contentOffsetY = 0

    if pb.showCallout then
        if pb.calloutPosition == "ABOVE" then
            contentOffsetY = -(calloutExtra / 2)
        else
            contentOffsetY = calloutExtra / 2
        end
    end

    widget.frame:SetHeight(previewHeight)
    if widget.SetHeight then widget:SetHeight(previewHeight) end

    widget.barFrame:SetSize(displayWidth, pb.height)
    widget.barFrame:ClearAllPoints()
    widget.barFrame:SetPoint("CENTER", widget.frame, "CENTER", 0, contentOffsetY)

    widget.background:SetColorTexture(pb.backgroundColor.r, pb.backgroundColor.g, pb.backgroundColor.b, pb.backgroundColor.a or 0.7)
    UpdateBorder(widget, pb)

    for _, seg in pairs(widget.segments) do
        seg:Hide()
    end
    for _, tick in pairs(widget.ticks) do
        tick:Hide()
    end

    local completedColor, inProgressColor, missingColor = GetProgressBarColors(addon)
    local barTexture = addon.LSM:Fetch("statusbar", pb.barTexture)
    local isRTL = pb.direction == "RIGHT_TO_LEFT"

    local boundaries = { 0 }
    for _, t in pairs(thresholds) do
        boundaries[#boundaries + 1] = t.percent
    end
    boundaries[#boundaries + 1] = 100

    local segIdx = 0
    for i = 1, #boundaries - 1 do
        local segStart = boundaries[i]
        local segEnd = boundaries[i + 1]
        local state = sectionStates[i] or "upcoming"
        local segWidth = (segEnd - segStart) / 100 * displayWidth
        local fillWidth

        if state == "upcoming" then
            fillWidth = 0
        elseif state == "inProgress" then
            local fillPct = math_max(0, math_min(currentPct, segEnd) - segStart)
            local segRange = segEnd - segStart
            fillWidth = (segRange > 0) and (fillPct / segRange * segWidth) or 0
        else
            fillWidth = segWidth
        end

        if fillWidth > 0 then
            segIdx = segIdx + 1
            local seg = widget.segments[segIdx]
            if not seg then
                seg = widget.barFrame:CreateTexture(nil, "ARTWORK")
                widget.segments[segIdx] = seg
            end

            seg:SetTexture(barTexture)
            seg:SetSize(fillWidth, pb.height)
            seg:ClearAllPoints()

            local xOffset = segStart / 100 * displayWidth
            if isRTL then
                local rightOffset = (100 - segStart) / 100 * displayWidth
                seg:SetPoint("RIGHT", widget.barFrame, "RIGHT", -(rightOffset - fillWidth), 0)
            else
                seg:SetPoint("LEFT", widget.barFrame, "LEFT", xOffset, 0)
            end

            local fillEnd = segStart + ((fillWidth / displayWidth) * 100)
            local leftEdgePct = isRTL and fillEnd or segStart
            local rightEdgePct = isRTL and segStart or fillEnd

            if pb.useGradient and state == "completed" then
                seg:SetGradient(
                    "HORIZONTAL",
                    GetProgressBarGradientColor(addon, leftEdgePct),
                    GetProgressBarGradientColor(addon, rightEdgePct)
                )
            else
                local solidColor = inProgressColor
                if state == "completed" then
                    solidColor = completedColor
                elseif state == "missing" then
                    solidColor = missingColor
                end
                local color = CreateColorFromTable(solidColor)
                seg:SetGradient("HORIZONTAL", color, color)
            end

            seg:Show()
        end
    end

    for idx, threshold in pairs(thresholds) do
        local tick = widget.ticks[idx]
        if not tick then
            tick = widget.barFrame:CreateTexture(nil, "OVERLAY")
            widget.ticks[idx] = tick
        end

        tick:SetColorTexture(pb.tickColor.r, pb.tickColor.g, pb.tickColor.b, pb.tickColor.a)
        tick:SetSize(pb.tickWidth, pb.height + pb.tickOverflow * 2)

        local xPos = displayWidth * (threshold.percent / 100)
        if isRTL then
            xPos = displayWidth - xPos
        end

        tick:ClearAllPoints()
        tick:SetPoint("CENTER", widget.barFrame, "LEFT", xPos, 0)
        tick:Show()
    end

    UpdateCallout(widget, thresholds, currentPct, displayWidth, dungeonKey)
end

local methods = {}

function methods.OnAcquire(self)
    self.scenarioIndex = 1
    self:SetHeight(90)
    self:SetFullWidth(true)
    KeystonePolaris._progressBarPreviewWidget = self
end

function methods.OnRelease(self)
    self.scenarioIndex = nil
    if KeystonePolaris._progressBarPreviewWidget == self then
        KeystonePolaris._progressBarPreviewWidget = nil
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
    self.frame:SetAlpha(disabled and 0.5 or 1.0)
end

function methods.SetText(_, _)
    -- Not used
end

function methods.SetList(_, _)
    -- Not applicable
end

function methods.RefreshPreview(self)
    RenderPreview(self, self.scenarioIndex or 1)
end

local function Constructor()
    local frame = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    frame:SetHeight(90)
    frame:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    frame:SetBackdropColor(0.1, 0.1, 0.1, 0.9)
    frame:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.8)

    local barFrame = CreateFrame("Frame", nil, frame)
    local background = barFrame:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints(barFrame)

    local borderFrame = CreateFrame("Frame", nil, barFrame, "BackdropTemplate")
    borderFrame:SetAllPoints(barFrame)
    borderFrame:SetFrameLevel(barFrame:GetFrameLevel() + 10)

    local callout = CreateFrame("Frame", nil, frame)
    callout:SetFrameStrata("HIGH")
    local calloutText = callout:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    calloutText:SetPoint("CENTER", callout, "CENTER", 0, 0)
    callout.text = calloutText
    local calloutBg = callout:CreateTexture(nil, "BACKGROUND")
    calloutBg:SetColorTexture(0, 0, 0, 0.8)
    callout.bg = calloutBg
    callout:Hide()

    local widget = {
        type = widgetType,
        frame = frame,
        barFrame = barFrame,
        background = background,
        borderFrame = borderFrame,
        callout = callout,
        segments = {},
        ticks = {},
    }
    frame.obj = widget

    for method, func in pairs(methods) do
        widget[method] = func
    end

    local ACR = LibStub("AceConfigRegistry-3.0", true)
    if ACR then
        ACR.RegisterCallback(widget, "ConfigTableChange", function(_, appName)
            if appName == AddOnName and widget.scenarioIndex then
                RenderPreview(widget, widget.scenarioIndex)
            end
        end)
    end

    AceGUI:RegisterAsWidget(widget)
    return widget
end

AceGUI:RegisterWidgetType(widgetType, Constructor, widgetVersion)
