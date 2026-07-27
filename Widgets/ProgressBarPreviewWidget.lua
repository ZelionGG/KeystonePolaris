local AddOnName, KeystonePolaris = ...
local AceGUI = LibStub("AceGUI-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale(AddOnName, true)

local widgetType = "KeystonePolaris_ProgressBarPreview"
local widgetVersion = 1

local CreateFrame = CreateFrame
local CreateColor = CreateColor
local ipairs = ipairs
local math_ceil = math.ceil
local math_max = math.max
local math_min = math.min
local pairs = pairs
local string_format = string.format

local function CreateColorFromTable(color)
    return CreateColor(color.r, color.g, color.b, color.a or 1)
end

local function GetSectionBoundaries(thresholds)
    local boundaries = { 0 }
    for _, threshold in ipairs(thresholds) do
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

local function GetCalloutReservedHeight(addon, pb)
    if not addon:GetProgressBarValue("showCallout") then return 0 end
    return (pb.calloutFontSize or 10) + 18
end

local function ApplyCalloutStyle(callout, pb)
    local currentFontFile = callout.text:GetFont()
    local fontName = pb.calloutFont or KeystonePolaris.db.profile.text.font
    local fontFile = KeystonePolaris.LSM and KeystonePolaris.LSM:Fetch("font", fontName, true)
    if fontFile or currentFontFile then
        callout.text:SetFont(fontFile or currentFontFile, pb.calloutFontSize or 10, KeystonePolaris:GetFontFlags())
    end

    local textColor = pb.calloutTextColor or { r = 1, g = 0.82, b = 0, a = 1 }
    callout.text:SetTextColor(textColor.r, textColor.g, textColor.b, textColor.a or 1)

    local backgroundColor = pb.calloutBackgroundColor or { r = 0, g = 0, b = 0, a = 0.8 }
    callout.bg:SetColorTexture(backgroundColor.r, backgroundColor.g, backgroundColor.b, backgroundColor.a or 0.8)
end

local function BuildPreviewThresholds(addon, dungeonKey)
    local dungeonData = addon.GlobalDungeonLookup and addon.GlobalDungeonLookup[dungeonKey]
    if not dungeonData or not dungeonData.bosses then return {}, nil end

    local thresholds = {}
    for _, target in ipairs(addon:GetOrderedBossTargets(dungeonKey)) do
        local pct = target.percent
        if pct and pct > 0 and pct < 100 then
            thresholds[#thresholds + 1] = {
                percent = pct,
                bossIndex = target.bossIndex,
                bossNum = target.bossNum,
            }
        end
    end

    return thresholds, dungeonData
end

local function UpdateBorder(widget, addon)
    local borderStyle = addon:GetProgressBarValue("borderStyle")
    if borderStyle == "NONE" then
        widget.borderFrame:SetBackdrop(nil)
        return
    end

    local pb = addon.db.profile.progressBar
    local edgeFile
    if borderStyle == "SOLID" then
        edgeFile = "Interface\\Buttons\\WHITE8X8"
    elseif borderStyle == "LSM_BORDER" then
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

local function UpdateCallout(widget, thresholds, currentPct, displayWidth, dungeonKey, sectionStates, bossKillStates, scenario)
    local addon = KeystonePolaris
    local pb = addon.db.profile.progressBar
    if not addon:GetProgressBarValue("showCallout") or not thresholds or #thresholds == 0 then
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

    local milestoneThresholds
    if addon:GetProgressBarValue("showMilestoneTicks") and addon.GetProgressBarMilestoneThresholds then
        milestoneThresholds = addon:GetProgressBarMilestoneThresholds(dungeonKey, scenario)
    end

    local anchorPct, remaining, label = addon:ResolveProgressBarCallout(
        dungeonKey,
        currentPct,
        bossKillStates,
        milestoneThresholds
    )
    if not anchorPct then
        widget.callout:Hide()
        return
    end

    ApplyCalloutStyle(widget.callout, pb)
    widget.callout.text:SetText(string_format(L["PROGRESS_BAR_CALLOUT_FORMAT"], remaining, label))
    widget.callout:SetSize(widget.callout.text:GetStringWidth() + 12, widget.callout.text:GetStringHeight() + 8)
    widget.callout.bg:SetAllPoints(widget.callout)

    local xPos = displayWidth * (anchorPct / 100)
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

    local dungeonKey = addon.ResolveProgressBarPreviewDungeonKey(addon)
    local thresholds = BuildPreviewThresholds(addon, dungeonKey)
    local currentPct, bossKillStates = addon.BuildProgressBarPreviewScenarioState(thresholds, scenario)
    local sectionStates = addon:GetProgressBarSectionStates(dungeonKey, currentPct, bossKillStates, thresholds) or {}

    local frameWidth = widget.frame:GetWidth()
    if not frameWidth or frameWidth <= 20 then
        frameWidth = pb.width + 20
    end
    local displayWidth = math_min(pb.width, math_max(80, frameWidth - 20))
    local calloutExtra = GetCalloutReservedHeight(addon, pb)
    local previewHeight = math_max(70, pb.height + calloutExtra + 24)
    local contentOffsetY = 0

    if addon:GetProgressBarValue("showCallout") then
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
    UpdateBorder(widget, addon)

    for _, seg in pairs(widget.segments) do
        seg:Hide()
    end
    for _, tick in pairs(widget.ticks) do
        tick:Hide()
    end
    for _, tick in pairs(widget.milestoneTicks or {}) do
        tick:Hide()
    end

    local completedColor, inProgressColor, missingColor = addon:GetProgressBarColors()
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
                return addon:GetProgressBarGradientColor(positionPct)
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
            local progressEnd = math_max(segStart, math_min(currentPct, segEnd))
            segIdx = drawSpan(segIdx, segStart, progressEnd, "inProgress")
        elseif state == "missing" then
            local completedEnd = math_max(segStart, math_min(currentPct, segEnd))
            segIdx = drawSpan(segIdx, segStart, completedEnd, "inProgress")
            segIdx = drawSpan(segIdx, completedEnd, segEnd, "missing")
        end
    end

    for idx, threshold in ipairs(thresholds) do
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

    if addon:GetProgressBarValue("showMilestoneTicks") and addon.GetProgressBarMilestoneThresholds then
        local milestoneThresholds = addon:GetProgressBarMilestoneThresholds(dungeonKey, scenario)
        local milestoneTickWidth = pb.milestoneTickWidth or 1
        local milestoneOverflow = math_max(0, math_ceil((pb.tickOverflow or 0) / 2))
        local upcomingTickColor = pb.milestoneTickColor or { r = 1, g = 0.82, b = 0, a = 1 }
        widget.milestoneTicks = widget.milestoneTicks or {}

        for idx, threshold in ipairs(milestoneThresholds) do
            local tick = widget.milestoneTicks[idx]
            if not tick then
                tick = (widget.milestoneOverlay or widget.barFrame):CreateTexture(nil, "OVERLAY", nil, 1)
                widget.milestoneTicks[idx] = tick
            end

            local passed = currentPct >= threshold.percent
            if passed then
                tick:Hide()
            else
                tick:SetColorTexture(upcomingTickColor.r, upcomingTickColor.g, upcomingTickColor.b, upcomingTickColor.a)
                tick:SetSize(milestoneTickWidth, pb.height + milestoneOverflow * 2)

                local milestoneXPos = displayWidth * (threshold.percent / 100)
                if isRTL then
                    milestoneXPos = displayWidth - milestoneXPos
                end

                tick:ClearAllPoints()
                tick:SetPoint("CENTER", widget.barFrame, "LEFT", milestoneXPos, 0)
                tick:Show()
            end
        end
    end

    UpdateCallout(widget, thresholds, currentPct, displayWidth, dungeonKey, sectionStates, bossKillStates, scenario)
end

local methods = {}

function methods.OnAcquire(self)
    self.scenarioIndex = KeystonePolaris._previewScenario or 1
    self:SetHeight(90)
    self:SetFullWidth(true)
    KeystonePolaris._progressBarPreviewWidget = self
    RenderPreview(self, self.scenarioIndex)
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

    local milestoneOverlay = CreateFrame("Frame", nil, barFrame)
    milestoneOverlay:SetAllPoints(barFrame)
    milestoneOverlay:SetFrameLevel(borderFrame:GetFrameLevel() + 1)
    milestoneOverlay:EnableMouse(false)

    local callout = CreateFrame("Frame", nil, frame)
    callout:SetFrameLevel(milestoneOverlay:GetFrameLevel() + 1)
    local calloutText = callout:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    calloutText:SetPoint("CENTER", callout, "CENTER", 0, 0)
    callout.text = calloutText
    local calloutBg = callout:CreateTexture(nil, "BACKGROUND")
    callout.bg = calloutBg
    ApplyCalloutStyle(callout, KeystonePolaris.db.profile.progressBar)
    callout:Hide()

    local widget = {
        type = widgetType,
        frame = frame,
        barFrame = barFrame,
        background = background,
        borderFrame = borderFrame,
        milestoneOverlay = milestoneOverlay,
        callout = callout,
        segments = {},
        ticks = {},
        milestoneTicks = {},
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
