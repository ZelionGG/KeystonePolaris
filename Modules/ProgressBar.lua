local AddOnName, KeystonePolaris = ...
local L = LibStub("AceLocale-3.0"):GetLocale(AddOnName)

local CreateFrame = CreateFrame
local CreateColor = CreateColor
local GameTooltip = GameTooltip
local C_ChallengeMode = C_ChallengeMode
local C_ScenarioInfo = C_ScenarioInfo
local pairs = pairs
local math_ceil = math.ceil
local math_max = math.max
local math_min = math.min
local string_format = string.format
local table_sort = table.sort
local select = select
local GetCursorPosition = GetCursorPosition

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

function KeystonePolaris:InitializeProgressBar()
    if self.progressBarFrame then return end

    local pb = self.db.profile.progressBar

    local frame = CreateFrame("Frame", "KeystonePolarisProgressBar", UIParent, "BackdropTemplate")
    frame:SetSize(pb.width, pb.height)
    frame:SetPoint(pb.position, UIParent, pb.position, pb.xOffset, pb.yOffset)
    frame:SetFrameStrata("MEDIUM")
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)

    local borderFrame = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    borderFrame:SetAllPoints(frame)
    borderFrame:SetFrameLevel(frame:GetFrameLevel() + 10)
    borderFrame:EnableMouse(false)
    frame.borderFrame = borderFrame

    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self_frame)
        if KeystonePolaris._progressBarPositioning or KeystonePolaris._positioningMode then
            self_frame:StartMoving()
            KeystonePolaris._progressBarDragging = true
        end
    end)
    frame:SetScript("OnDragStop", function(self_frame)
        self_frame:StopMovingOrSizing()
        KeystonePolaris._progressBarDragging = false
        local point, _, _, x, y = self_frame:GetPoint()
        KeystonePolaris.db.profile.progressBar.position = point
        KeystonePolaris.db.profile.progressBar.xOffset = x
        KeystonePolaris.db.profile.progressBar.yOffset = y
        LibStub("AceConfigRegistry-3.0"):NotifyChange(AddOnName)
    end)

    local bg = frame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(frame)
    bg:SetColorTexture(pb.backgroundColor.r, pb.backgroundColor.g, pb.backgroundColor.b, pb.backgroundColor.a or 0.7)
    frame.background = bg

    frame.segments = {}
    frame.ticks = {}
    frame.tickThresholds = {}

    frame:SetScript("OnEnter", function(self_frame)
        KeystonePolaris:ShowProgressBarTooltip(self_frame)
    end)
    frame:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    self.progressBarFrame = frame

    self:ApplyProgressBarBorder()
    self:CreateProgressBarCallout(frame)
    frame:Hide()
end

function KeystonePolaris.CreateProgressBarCallout(_, parentFrame)
    local callout = CreateFrame("Frame", nil, parentFrame)
    callout:SetFrameStrata("HIGH")

    local text = callout:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    text:SetPoint("CENTER", callout, "CENTER", 0, 0)
    callout.text = text

    local bg = callout:CreateTexture(nil, "BACKGROUND")
    bg:SetColorTexture(0, 0, 0, 0.8)
    callout.bg = bg

    callout:Hide()
    parentFrame.callout = callout
end

function KeystonePolaris:UpdateProgressBarCallout(segmentIndex, currentPct, sectionStates)
    local frame = self.progressBarFrame
    if not frame or not frame.callout then return end

    local pb = self.db.profile.progressBar
    if not pb.showCallout then
        frame.callout:Hide()
        return
    end

    local thresholds = frame.tickThresholds
    if not thresholds or #thresholds == 0 then
        frame.callout:Hide()
        return
    end

    local activeIdx = segmentIndex
    if not activeIdx then
        activeIdx = GetActiveSectionIndex(sectionStates)
        if not activeIdx then
            local boundaries = GetSectionBoundaries(thresholds)
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
    end

    local boundaries = GetSectionBoundaries(thresholds)

    if activeIdx > #boundaries - 1 then
        frame.callout:Hide()
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
    if bossIdx and self._progressBarDungeonKey then
        bossName = self:GetBossName(self._progressBarDungeonKey, bossIdx) or ("Boss " .. bossIdx)
    end

    local calloutText = string_format(L["PROGRESS_BAR_CALLOUT_FORMAT"], segEnd, bossName)

    local callout = frame.callout
    callout.text:SetText(calloutText)

    local textWidth = callout.text:GetStringWidth() + 12
    local textHeight = callout.text:GetStringHeight() + 8
    callout:SetSize(textWidth, textHeight)
    callout.bg:SetAllPoints(callout)

    local barWidth = pb.width
    local isRTL = pb.direction == "RIGHT_TO_LEFT"
    local xPos = barWidth * (segCenter / 100)
    if isRTL then
        xPos = barWidth - xPos
    end

    callout:ClearAllPoints()

    if pb.calloutPosition == "BELOW" then
        callout:SetPoint("TOP", frame, "BOTTOM", xPos - barWidth / 2, -2)
    else
        callout:SetPoint("BOTTOM", frame, "TOP", xPos - barWidth / 2, 2)
    end

    callout:Show()
end

function KeystonePolaris:GetProgressBarColors()
    local pb = self.db.profile.progressBar
    if pb.overrideColors then
        return pb.completedColor, pb.inProgressColor, pb.missingColor
    end
    local textColors = self.db.profile.color
    return textColors.finished, textColors.inProgress, textColors.missing
end

function KeystonePolaris:GetProgressBarGradientColor(positionPct)
    local pb = self.db.profile.progressBar
    local startColor = pb.gradientStartColor
    local endColor = pb.gradientEndColor
    local amount = math_max(0, math_min(positionPct / 100, 1))
    return InterpolateColor(startColor, endColor, amount)
end

function KeystonePolaris:UpdateProgressBarTickColors(bossKillStates)
    local frame = self.progressBarFrame
    if not frame or not frame.tickThresholds then return end

    local pb = self.db.profile.progressBar
    local completedColor = self:GetProgressBarColors()
    local doneColor = GetCompletedVisualColor(pb, completedColor)

    for idx, tick in pairs(frame.ticks) do
        local threshold = frame.tickThresholds[idx]
        local bossKilled = threshold and threshold.bossIndex and bossKillStates and bossKillStates[threshold.bossIndex] or false
        local color = bossKilled and doneColor or pb.tickColor
        tick:SetColorTexture(color.r, color.g, color.b, color.a)
    end
end

function KeystonePolaris:UpdateProgressBarSegments(currentPct, sectionStates)
    local frame = self.progressBarFrame
    if not frame then return end

    local thresholds = frame.tickThresholds
    if not thresholds then return end

    local pb = self.db.profile.progressBar
    local barWidth = pb.width
    local completedColor, inProgressColor, missingColor = self:GetProgressBarColors()
    local barTexture = self.LSM:Fetch("statusbar", pb.barTexture)
    local isRTL = pb.direction == "RIGHT_TO_LEFT"
    local useGradient = pb.useGradient

    for _, seg in pairs(frame.segments) do
        seg:Hide()
    end

    local boundaries = GetSectionBoundaries(thresholds)

    local function drawSpan(segIdx, startPct, endPct, state)
        if endPct <= startPct then return segIdx end

        segIdx = segIdx + 1
        local seg = frame.segments[segIdx]
        if not seg then
            seg = frame:CreateTexture(nil, "ARTWORK")
            frame.segments[segIdx] = seg
        end

        seg:SetTexture(barTexture)
        if not PositionProgressSpan(seg, frame, barWidth, pb.height, isRTL, startPct, endPct) then
            return segIdx
        end

        ApplyProgressSpanColor(
            seg,
            useGradient,
            isRTL,
            startPct,
            endPct,
            state,
            completedColor,
            inProgressColor,
            missingColor,
            function(positionPct)
                return self:GetProgressBarGradientColor(positionPct)
            end
        )
        seg:Show()
        return segIdx
    end

    local segIdx = 0
    for i = 1, #boundaries - 1 do
        local segStart = boundaries[i]
        local segEnd = boundaries[i + 1]
        local state = sectionStates and sectionStates[i] or "upcoming"

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
end

function KeystonePolaris:ApplyProgressBarBorder()
    local frame = self.progressBarFrame
    if not frame then return end

    local borderFrame = frame.borderFrame
    if not borderFrame then return end

    local pb = self.db.profile.progressBar

    if pb.borderStyle == "NONE" then
        borderFrame:SetBackdrop(nil)
        return
    end

    local edgeFile
    local edgeSize = pb.borderSize
    local insets = pb.borderInsets

    if pb.borderStyle == "SOLID" then
        edgeFile = "Interface\\Buttons\\WHITE8X8"
    elseif pb.borderStyle == "LSM_BORDER" then
        edgeFile = self.LSM:Fetch("border", pb.borderTexture)
    end

    borderFrame:SetBackdrop({
        edgeFile = edgeFile,
        edgeSize = edgeSize,
        insets = { left = insets, right = insets, top = insets, bottom = insets },
    })
    borderFrame:SetBackdropBorderColor(pb.borderColor.r, pb.borderColor.g, pb.borderColor.b, pb.borderColor.a)
end

function KeystonePolaris:BuildProgressBarTicks(dungeonKey)
    local frame = self.progressBarFrame
    if not frame then return end

    for _, tick in pairs(frame.ticks) do
        tick:Hide()
        tick:SetParent(nil)
    end
    frame.ticks = {}
    frame.tickThresholds = {}

    if not dungeonKey then return end

    local pb = self.db.profile.progressBar
    local barWidth = pb.width
    local barHeight = pb.height
    local dungeonData = self.GlobalDungeonLookup and self.GlobalDungeonLookup[dungeonKey]
    if not dungeonData or not dungeonData.bosses then return end

    local adv = self.db.profile.advanced[dungeonKey]
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

    local tickParent = frame.borderFrame or frame
    for idx, threshold in pairs(thresholds) do
        local tick = tickParent:CreateTexture(nil, "OVERLAY", nil, 7)
        tick:SetColorTexture(pb.tickColor.r, pb.tickColor.g, pb.tickColor.b, pb.tickColor.a)
        tick:SetSize(pb.tickWidth, barHeight + pb.tickOverflow * 2)

        local xPos = barWidth * (threshold.percent / 100)
        if pb.direction == "RIGHT_TO_LEFT" then
            xPos = barWidth - xPos
        end
        tick:SetPoint("CENTER", frame, "LEFT", xPos, 0)
        tick:Show()

        frame.ticks[idx] = tick
    end

    frame.tickThresholds = thresholds
end

function KeystonePolaris:ShowProgressBarTooltip(frame)
    local thresholds = frame.tickThresholds
    if not thresholds or #thresholds == 0 then return end
    if not self._progressBarDungeonKey then return end

    local pb = self.db.profile.progressBar
    local barWidth = pb.width
    local cursorX = select(1, GetCursorPosition()) / UIParent:GetEffectiveScale()
    local frameLeft = frame:GetLeft() or 0
    local relativeX = cursorX - frameLeft

    if pb.direction == "RIGHT_TO_LEFT" then
        relativeX = barWidth - relativeX
    end

    local cursorPct = (relativeX / barWidth) * 100

    local segStart = 0
    local segEnd = 100
    local segBossIdx = nil
    for _, t in pairs(thresholds) do
        if cursorPct <= t.percent then
            segEnd = t.percent
            segBossIdx = t.bossIndex
            break
        end
        segStart = t.percent
    end
    if not segBossIdx then
        local dungeonData = self.GlobalDungeonLookup[self._progressBarDungeonKey]
        if dungeonData and dungeonData.bosses then
            segBossIdx = #dungeonData.bosses
        end
    end

    if not segBossIdx then return end

    local dungeonKey = self._progressBarDungeonKey
    local bossName = self:GetBossName(dungeonKey, segBossIdx)

    GameTooltip:SetOwner(frame, "ANCHOR_TOP")
    GameTooltip:AddLine(bossName or ("Boss " .. segBossIdx), 1, 0.82, 0)
    GameTooltip:AddLine(string_format(L["PROGRESS_BAR_THRESHOLD"], segEnd), 1, 1, 1)

    local currentCount, totalCount = self:GetCurrentForcesInfo()
    if totalCount and totalCount > 0 then
        local neededCount = math_ceil(totalCount * segEnd / 100)
        GameTooltip:AddLine(string_format(L["PROGRESS_BAR_COUNT"], neededCount), 1, 1, 1)

        local currentPct = (currentCount / totalCount) * 100
        local bossKillStates = self:GetBossKillStates(dungeonKey)
        local isBossKilled = segBossIdx and bossKillStates[segBossIdx] or false

        if currentPct >= segEnd and isBossKilled then
            GameTooltip:AddLine(L["PROGRESS_BAR_STATUS_COMPLETE"], 0, 1, 0)
        elseif currentPct >= segStart or isBossKilled then
            GameTooltip:AddLine(L["PROGRESS_BAR_STATUS_CURRENT"], 1, 1, 0)
        else
            GameTooltip:AddLine(L["PROGRESS_BAR_STATUS_UPCOMING"], 0.5, 0.5, 0.5)
        end
    end

    GameTooltip:Show()
end

function KeystonePolaris:GetProgressBarSectionStates(dungeonKey, currentPct, bossKillStates)
    local thresholds = self.progressBarFrame and self.progressBarFrame.tickThresholds
    if not thresholds or #thresholds == 0 then return nil end

    local states = {}

    local boundaries = { 0 }
    local bossIndices = {}
    for i, t in pairs(thresholds) do
        boundaries[#boundaries + 1] = t.percent
        bossIndices[i] = t.bossIndex
    end
    boundaries[#boundaries + 1] = 100

    if not bossIndices[#boundaries - 1] then
        local dungeonData = self.GlobalDungeonLookup and self.GlobalDungeonLookup[dungeonKey]
        if dungeonData and dungeonData.bosses then
            local adv = self.db.profile.advanced and self.db.profile.advanced[dungeonKey]
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

function KeystonePolaris:GetBossKillStates(dungeonKey)
    local dungeonID = self:GetDungeonIdByKey(dungeonKey)
    local dungeon = dungeonID and self.DUNGEONS[dungeonID]
    if not dungeon then return {} end

    local killStates = {}
    for bossIdx, bossData in ipairs(dungeon) do
        local bossID = bossData[1]
        local info = bossID and C_ScenarioInfo.GetCriteriaInfo(bossID)
        killStates[bossIdx] = info and info.completed or false
    end
    return killStates
end

function KeystonePolaris:UpdateProgressBar()
    local frame = self.progressBarFrame
    if not frame then return end

    local pb = self.db.profile.progressBar
    if not pb.enabled then
        frame:Hide()
        return
    end

    if self._progressBarPreview then return end

    local currentDungeonID = C_ChallengeMode.GetActiveChallengeMapID()
    if not currentDungeonID or not self.DUNGEONS[currentDungeonID] then
        frame:Hide()
        self._progressBarDungeonKey = nil
        return
    end

    local dungeonKey = self:GetDungeonKeyById(currentDungeonID)
    if not dungeonKey then
        frame:Hide()
        return
    end

    if self._progressBarDungeonKey ~= dungeonKey then
        self._progressBarDungeonKey = dungeonKey
        self:BuildProgressBarTicks(dungeonKey)
    end

    local currentCount, totalCount = self:GetCurrentForcesInfo()
    local currentPct = (totalCount and totalCount > 0) and ((currentCount / totalCount) * 100) or 0

    local bossKillStates = self:GetBossKillStates(dungeonKey)
    local sectionStates = self:GetProgressBarSectionStates(dungeonKey, currentPct, bossKillStates)
    self:UpdateProgressBarTickColors(bossKillStates)
    self:UpdateProgressBarSegments(currentPct, sectionStates)
    self:UpdateProgressBarCallout(nil, currentPct, sectionStates)
    frame:Show()
end

function KeystonePolaris:RefreshProgressBar()
    local frame = self.progressBarFrame
    if not frame then return end

    local pb = self.db.profile.progressBar

    frame:SetSize(pb.width, pb.height)

    if not self._progressBarDragging then
        frame:ClearAllPoints()
        frame:SetPoint(pb.position, UIParent, pb.position, pb.xOffset, pb.yOffset)
    end

    frame.background:SetColorTexture(pb.backgroundColor.r, pb.backgroundColor.g, pb.backgroundColor.b, pb.backgroundColor.a or 0.7)

    self:ApplyProgressBarBorder()

    if self._progressBarDungeonKey then
        self:BuildProgressBarTicks(self._progressBarDungeonKey)
        local currentPct, bossKillStates
        if self._progressBarPreview then
            currentPct = self._progressBarPreviewPct or 0
            local scenario = self._progressBarPreviewScenarioRef
            local bossesKilled = scenario and scenario.bossesKilled or 0
            bossKillStates = {}
            for idx = 1, bossesKilled do
                bossKillStates[idx] = true
            end
        else
            local currentCount, totalCount = self:GetCurrentForcesInfo()
            currentPct = (totalCount and totalCount > 0) and ((currentCount / totalCount) * 100) or 0
            bossKillStates = self:GetBossKillStates(self._progressBarDungeonKey)
        end
        local sectionStates = self:GetProgressBarSectionStates(self._progressBarDungeonKey, currentPct, bossKillStates)
        self:UpdateProgressBarTickColors(bossKillStates)
        self:UpdateProgressBarSegments(currentPct, sectionStates)
        self:UpdateProgressBarCallout(nil, currentPct, sectionStates)
    end
end

function KeystonePolaris:EnableProgressBarPreview()
    if not self.progressBarFrame then
        self:InitializeProgressBar()
    end

    self._progressBarPreview = true

    local currentDate
    if C_DateAndTime and C_DateAndTime.GetCurrentCalendarTime then
        local t = C_DateAndTime.GetCurrentCalendarTime()
        currentDate = string_format("%04d-%02d-%02d", t.year, t.month, t.monthDay)
    else
        currentDate = "2026-01-01"
    end

    local seasonId = self:GetSeasonByDate(currentDate)
    local previewDungeonKey

    if seasonId then
        local seasonTable = self[seasonId .. "_DUNGEONS"]
        if seasonTable then
            for dungeonId in pairs(seasonTable) do
                if type(dungeonId) == "number" then
                    previewDungeonKey = self:GetDungeonKeyById(dungeonId)
                    if previewDungeonKey then break end -- luacheck: ignore 512
                end
            end
        end
    end

    if not previewDungeonKey and self.GlobalDungeonLookup then
        previewDungeonKey = next(self.GlobalDungeonLookup)
    end

    if previewDungeonKey then
        self._progressBarDungeonKey = previewDungeonKey
        self:BuildProgressBarTicks(previewDungeonKey)

        local scenarios = self.PreviewScenarios
        local scenarioIdx = self._previewScenario or 1
        local scenario = scenarios and scenarios[scenarioIdx]
        local pct, bossKillStates = BuildPreviewScenarioState(self.progressBarFrame and self.progressBarFrame.tickThresholds, scenario)
        self._progressBarPreviewPct = pct
        self._progressBarPreviewScenarioRef = scenario

        local sectionStates = self:GetProgressBarSectionStates(previewDungeonKey, pct, bossKillStates)
        self:UpdateProgressBarTickColors(bossKillStates)
        self:UpdateProgressBarSegments(pct, sectionStates)
        self:UpdateProgressBarCallout(nil, pct, sectionStates)
    end

    self:RefreshProgressBar()
    self.progressBarFrame:Show()
end

function KeystonePolaris:DisableProgressBarPreview()
    self._progressBarPreview = false
    self._progressBarPositioning = false
    self._progressBarPreviewPct = nil
    self._progressBarPreviewScenarioRef = nil

    if not self.progressBarFrame then return end

    local currentDungeonID = C_ChallengeMode.GetActiveChallengeMapID()
    if not currentDungeonID or not self.db.profile.progressBar.enabled then
        self.progressBarFrame:Hide()
        self._progressBarDungeonKey = nil
    end
end
