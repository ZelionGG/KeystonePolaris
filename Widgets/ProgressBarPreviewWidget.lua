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

local function GetSectionBoundaries(thresholds)
    local boundaries = { 0 }
    for _, threshold in pairs(thresholds) do
        boundaries[#boundaries + 1] = threshold.percent
    end
    boundaries[#boundaries + 1] = 100
    return boundaries
end

local function GetActiveSectionIndex(sectionStates)
    if not sectionStates or #sectionStates == 0 then return nil end

    for idx = 1, #sectionStates do
        if sectionStates[idx] ~= "completedBoss" then
            return idx
        end
    end

    return #sectionStates
end

local function PositionProgressSpan(texture, parent, totalWidth, height, isRTL, startPct, endPct)
    local spanPct = math_max(0, endPct - startPct)
    local spanWidth = (spanPct / 100) * totalWidth
    if spanWidth <= 0 then
        texture:Hide()
        return false
    end

    texture:SetSize(spanWidth, height)
    texture:ClearAllPoints()

    local xOffset = (startPct / 100) * totalWidth
    if isRTL then
        local rightOffset = ((100 - startPct) / 100) * totalWidth
        texture:SetPoint("RIGHT", parent, "RIGHT", -(rightOffset - spanWidth), 0)
    else
        texture:SetPoint("LEFT", parent, "LEFT", xOffset, 0)
    end

    return true
end

local function ApplyProgressSpanColor(texture, useGradient, isRTL, startPct, endPct, state, completedColor, inProgressColor, missingColor, gradientColorFn)
    local leftEdgePct = isRTL and endPct or startPct
    local rightEdgePct = isRTL and startPct or endPct

    if useGradient and (state == "completed" or state == "completedBoss") then
        texture:SetGradient(
            "HORIZONTAL",
            gradientColorFn(leftEdgePct),
            gradientColorFn(rightEdgePct)
        )
        return
    end

    local solidColor = inProgressColor
    if state == "completed" or state == "completedBoss" then
        solidColor = completedColor
    elseif state == "missing" then
        solidColor = missingColor
    end

    local color = CreateColorFromTable(solidColor)
    texture:SetGradient("HORIZONTAL", color, color)
end

local function GetCompletedVisualColor(pb, completedColor)
    if pb.useGradient then
        return pb.gradientStartColor
    end

    return completedColor
end

local function GetPreviewScenarioSectionIndex(sectionCount, mode)
    if sectionCount <= 1 then return 1 end
    if mode == "almostDone" then return sectionCount end
    if sectionCount >= 3 then return 2 end
    return 1
end

local function BuildPreviewScenarioState(thresholds, scenario)
    local fallbackPct = (scenario and scenario.barPercent) or 0
    local fallbackBossesKilled = (scenario and scenario.bossesKilled) or 0
    local bossKillStates = {}

    if not scenario then
        return fallbackPct, bossKillStates
    end

    if not thresholds or #thresholds == 0 or not scenario.progressBarMode then
        for idx = 1, fallbackBossesKilled do
            bossKillStates[idx] = true
        end
        return fallbackPct, bossKillStates
    end

    local boundaries = GetSectionBoundaries(thresholds)
    local sectionCount = #boundaries - 1
    local sectionIdx = GetPreviewScenarioSectionIndex(sectionCount, scenario.progressBarMode)
    local segStart = boundaries[sectionIdx]
    local segEnd = boundaries[sectionIdx + 1]
    local segMid = segStart + ((segEnd - segStart) * 0.5)
    local segNearEnd = segStart + ((segEnd - segStart) * 0.9)

    if scenario.progressBarMode == "dungeonDone" then
        for idx = 1, #thresholds do
            bossKillStates[idx] = true
        end
        return 100, bossKillStates
    end

    local bossesKilled = sectionIdx - 1
    local currentPct = segMid

    if scenario.progressBarMode == "sectionDone" then
        bossesKilled = math_max(0, sectionIdx - 1)
        currentPct = segEnd
    elseif scenario.progressBarMode == "missing" then
        bossesKilled = sectionIdx
        currentPct = segMid
    elseif scenario.progressBarMode == "almostDone" then
        bossesKilled = math_max(0, sectionIdx - 1)
        currentPct = segNearEnd
    end

    for idx = 1, bossesKilled do
        bossKillStates[idx] = true
    end

    return currentPct, bossKillStates
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

        if currentPct >= segEnd and isBossKilled then
            states[i] = "completedBoss"
        elseif currentPct >= segEnd then
            states[i] = "completed"
        elseif isBossKilled then
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

local function UpdateCallout(widget, thresholds, currentPct, displayWidth, dungeonKey, sectionStates)
    local addon = KeystonePolaris
    local pb = addon.db.profile.progressBar
    if not pb.showCallout or not thresholds or #thresholds == 0 then
        widget.callout:Hide()
        return
    end

    local boundaries = GetSectionBoundaries(thresholds)

    local activeIdx = GetActiveSectionIndex(sectionStates)
    if not activeIdx then
        for i = 1, #boundaries - 1 do
            if currentPct < boundaries[i + 1] then
                activeIdx = i
                break
            end
        end
        if not activeIdx then
            activeIdx = #thresholds + 1
        end
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
    local currentPct, bossKillStates = BuildPreviewScenarioState(thresholds, scenario)
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
    local doneTickColor = GetCompletedVisualColor(pb, completedColor)

    local boundaries = GetSectionBoundaries(thresholds)

    local function drawSpan(segIdx, startPct, endPct, state)
        if endPct <= startPct then return segIdx end

        segIdx = segIdx + 1
        local seg = widget.segments[segIdx]
        if not seg then
            seg = widget.barFrame:CreateTexture(nil, "ARTWORK")
            widget.segments[segIdx] = seg
        end

        seg:SetTexture(barTexture)
        if not PositionProgressSpan(seg, widget.barFrame, displayWidth, pb.height, isRTL, startPct, endPct) then
            return segIdx
        end

        ApplyProgressSpanColor(
            seg,
            pb.useGradient,
            isRTL,
            startPct,
            endPct,
            state,
            completedColor,
            inProgressColor,
            missingColor,
            function(positionPct)
                return GetProgressBarGradientColor(addon, positionPct)
            end
        )
        seg:Show()
        return segIdx
    end

    local segIdx = 0
    for i = 1, #boundaries - 1 do
        local segStart = boundaries[i]
        local segEnd = boundaries[i + 1]
        local state = sectionStates[i] or "upcoming"

        if state == "completed" or state == "completedBoss" then
            segIdx = drawSpan(segIdx, segStart, segEnd, "completed")
        elseif state == "inProgress" then
            segIdx = drawSpan(segIdx, segStart, segEnd, "inProgress")
        elseif state == "missing" then
            local completedEnd = math_max(segStart, math_min(currentPct, segEnd))
            segIdx = drawSpan(segIdx, segStart, completedEnd, "inProgress")
            segIdx = drawSpan(segIdx, completedEnd, segEnd, "missing")
        end
    end

    for idx, threshold in pairs(thresholds) do
        local tick = widget.ticks[idx]
        if not tick then
            tick = widget.borderFrame:CreateTexture(nil, "OVERLAY", nil, 7)
            widget.ticks[idx] = tick
        end

        local bossKilled = threshold.bossIndex and bossKillStates and bossKillStates[threshold.bossIndex] or false
        local tickColor = bossKilled and doneTickColor or pb.tickColor
        tick:SetColorTexture(tickColor.r, tickColor.g, tickColor.b, tickColor.a)
        tick:SetSize(pb.tickWidth, pb.height + pb.tickOverflow * 2)

        local xPos = displayWidth * (threshold.percent / 100)
        if isRTL then
            xPos = displayWidth - xPos
        end

        tick:ClearAllPoints()
        tick:SetPoint("CENTER", widget.barFrame, "LEFT", xPos, 0)
        tick:Show()
    end

    UpdateCallout(widget, thresholds, currentPct, displayWidth, dungeonKey, sectionStates)
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
