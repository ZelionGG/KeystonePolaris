local AddOnName, KeystonePolaris = ...
local L = LibStub("AceLocale-3.0"):GetLocale(AddOnName)

-- Cache globals
local CreateFrame = CreateFrame
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

-- ---------------------------------------------------------------------------
-- Progress Bar Initialization
-- ---------------------------------------------------------------------------

function KeystonePolaris:InitializeProgressBar()
    if self.progressBarFrame then return end

    local pb = self.db.profile.progressBar

    -- Parent frame with backdrop support
    local frame = CreateFrame("Frame", "KeystonePolarisProgressBar", UIParent, "BackdropTemplate")
    frame:SetSize(pb.width, pb.height)
    frame:SetPoint(pb.position, UIParent, pb.position, pb.xOffset, pb.yOffset)
    frame:SetFrameStrata("MEDIUM")
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)

    -- Drag to position
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self_frame)
        if KeystonePolaris._progressBarPositioning or KeystonePolaris._optionsPreviewActive then
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

    -- Background texture (unfilled portion)
    local bg = frame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(frame)
    bg:SetColorTexture(pb.backgroundColor.r, pb.backgroundColor.g, pb.backgroundColor.b, pb.backgroundColor.a or 0.7)
    frame.background = bg

    -- Segment texture pool (replaces StatusBar)
    frame.segments = {}

    -- Tick mark storage
    frame.ticks = {}
    frame.tickThresholds = {}

    -- Tooltip on hover
    frame:SetScript("OnEnter", function(self_frame)
        KeystonePolaris:ShowProgressBarTooltip(self_frame)
    end)
    frame:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    -- Store reference
    self.progressBarFrame = frame

    -- Apply border
    self:ApplyProgressBarBorder()

    -- Callout frame
    self:CreateProgressBarCallout(frame)

    -- Hide by default (shown during M+ or preview)
    frame:Hide()
end

-- ---------------------------------------------------------------------------
-- Callout
-- ---------------------------------------------------------------------------

function KeystonePolaris.CreateProgressBarCallout(_, parentFrame)
    local callout = CreateFrame("Frame", nil, parentFrame)
    callout:SetFrameStrata("HIGH")

    -- Text label
    local text = callout:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    text:SetPoint("CENTER", callout, "CENTER", 0, 0)
    callout.text = text

    -- Background
    local bg = callout:CreateTexture(nil, "BACKGROUND")
    bg:SetColorTexture(0, 0, 0, 0.8)
    callout.bg = bg

    callout:Hide()
    parentFrame.callout = callout
end

function KeystonePolaris:UpdateProgressBarCallout(segmentIndex, currentPct)
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

    -- Find the current (in-progress or first incomplete) segment
    local activeIdx = segmentIndex
    if not activeIdx then
        -- Find from current percentage
        local boundaries = { 0 }
        for _, t in pairs(thresholds) do
            boundaries[#boundaries + 1] = t.percent
        end
        boundaries[#boundaries + 1] = 100

        for i = 1, #boundaries - 1 do
            if currentPct < boundaries[i + 1] then
                activeIdx = i
                break
            end
        end
        if not activeIdx then
            activeIdx = #thresholds + 1 -- last segment
        end
    end

    -- Get segment boundaries
    local boundaries = { 0 }
    for _, t in pairs(thresholds) do
        boundaries[#boundaries + 1] = t.percent
    end
    boundaries[#boundaries + 1] = 100

    if activeIdx > #boundaries - 1 then
        frame.callout:Hide()
        return
    end

    local segStart = boundaries[activeIdx]
    local segEnd = boundaries[activeIdx + 1]
    local segCenter = (segStart + segEnd) / 2

    -- Get boss name for this segment
    local bossIdx
    if activeIdx <= #thresholds then
        bossIdx = thresholds[activeIdx].bossIndex
    else
        -- Last segment — use last threshold's boss
        bossIdx = thresholds[#thresholds] and thresholds[#thresholds].bossIndex
    end

    local bossName = ""
    if bossIdx and self._progressBarDungeonKey then
        bossName = self:GetBossName(self._progressBarDungeonKey, bossIdx) or ("Boss " .. bossIdx)
    end

    -- Format callout text
    local calloutText = string_format(L["PROGRESS_BAR_CALLOUT_FORMAT"], segEnd, bossName)

    local callout = frame.callout
    callout.text:SetText(calloutText)

    -- Size the callout to fit text
    local textWidth = callout.text:GetStringWidth() + 12
    local textHeight = callout.text:GetStringHeight() + 8
    callout:SetSize(textWidth, textHeight)
    callout.bg:SetAllPoints(callout)

    -- Position callout centered over segment
    local barWidth = pb.width
    local isRTL = pb.direction == "RIGHT_TO_LEFT"
    local xPos = barWidth * (segCenter / 100)
    if isRTL then
        xPos = barWidth - xPos
    end

    callout:ClearAllPoints()

    if pb.calloutPosition == "BELOW" then
        callout:SetPoint("TOP", frame, "BOTTOM", xPos - barWidth / 2, -2)
    else -- ABOVE
        callout:SetPoint("BOTTOM", frame, "TOP", xPos - barWidth / 2, 2)
    end

    callout:Show()
end

-- ---------------------------------------------------------------------------
-- Colors
-- ---------------------------------------------------------------------------

function KeystonePolaris:GetProgressBarColors()
    local pb = self.db.profile.progressBar
    if pb.overrideColors then
        return pb.completedColor, pb.inProgressColor, pb.missingColor
    end
    local textColors = self.db.profile.color
    return textColors.finished, textColors.inProgress, textColors.missing
end

-- ---------------------------------------------------------------------------
-- Segments
-- ---------------------------------------------------------------------------

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

    -- Hide all existing segments
    for _, seg in pairs(frame.segments) do
        seg:Hide()
    end

    -- Build segment boundaries: 0, threshold1, threshold2, ..., 100
    local boundaries = { 0 }
    for _, t in pairs(thresholds) do
        boundaries[#boundaries + 1] = t.percent
    end
    boundaries[#boundaries + 1] = 100

    local segIdx = 0
    for i = 1, #boundaries - 1 do
        local segStart = boundaries[i]
        local segEnd = boundaries[i + 1]
        local state = sectionStates and sectionStates[i] or "upcoming"

        -- Determine fill width within this segment
        local segWidth = (segEnd - segStart) / 100 * barWidth
        local fillWidth

        if state == "upcoming" then
            fillWidth = 0
        elseif state == "inProgress" then
            -- Partial fill: how much of this segment is filled
            local fillPct = math_max(0, math_min(currentPct, segEnd) - segStart)
            local segRange = segEnd - segStart
            fillWidth = (segRange > 0) and (fillPct / segRange * segWidth) or 0
        else
            -- completed or missing: full segment
            fillWidth = segWidth
        end

        if fillWidth > 0 then
            segIdx = segIdx + 1
            local seg = frame.segments[segIdx]
            if not seg then
                seg = frame:CreateTexture(nil, "ARTWORK")
                frame.segments[segIdx] = seg
            end

            seg:SetTexture(barTexture)
            seg:SetSize(fillWidth, pb.height)
            seg:ClearAllPoints()

            local xOffset = segStart / 100 * barWidth
            if isRTL then
                -- For RTL, position from the right side
                local rightOffset = (100 - segStart) / 100 * barWidth
                seg:SetPoint("RIGHT", frame, "RIGHT", -(rightOffset - fillWidth), 0)
            else
                seg:SetPoint("LEFT", frame, "LEFT", xOffset, 0)
            end

            -- Apply color based on state
            if state == "completed" then
                seg:SetVertexColor(completedColor.r, completedColor.g, completedColor.b, completedColor.a or 1)
            elseif state == "missing" then
                seg:SetVertexColor(missingColor.r, missingColor.g, missingColor.b, missingColor.a or 1)
            else -- inProgress
                seg:SetVertexColor(inProgressColor.r, inProgressColor.g, inProgressColor.b, inProgressColor.a or 1)
            end

            seg:Show()
        end
    end
end

-- ---------------------------------------------------------------------------
-- Border
-- ---------------------------------------------------------------------------

function KeystonePolaris:ApplyProgressBarBorder()
    local frame = self.progressBarFrame
    if not frame then return end

    local pb = self.db.profile.progressBar

    if pb.borderStyle == "NONE" then
        frame:SetBackdrop(nil)
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

    frame:SetBackdrop({
        edgeFile = edgeFile,
        edgeSize = edgeSize,
        insets = { left = insets, right = insets, top = insets, bottom = insets },
    })
    frame:SetBackdropBorderColor(pb.borderColor.r, pb.borderColor.g, pb.borderColor.b, pb.borderColor.a)
end

-- ---------------------------------------------------------------------------
-- Tick Marks
-- ---------------------------------------------------------------------------

function KeystonePolaris:BuildProgressBarTicks(dungeonKey)
    local frame = self.progressBarFrame
    if not frame then return end

    -- Clear existing ticks
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

    -- Collect boss thresholds from user-customized values (advanced options)
    local adv = self.db.profile.advanced[dungeonKey]
    local thresholds = {}
    for i, boss in pairs(dungeonData.bosses) do
        local pct
        if adv then
            pct = adv["Boss" .. tostring(boss[1])]
        end
        if not pct then
            pct = boss[2] -- default from dungeon data
        end
        -- Skip the 100% mark (end of bar) and 0% marks
        if pct and pct > 0 and pct < 100 then
            thresholds[#thresholds + 1] = {
                percent = pct,
                bossIndex = i,
                bossNum = boss[1],
            }
        end
    end

    -- Sort by percentage
    table_sort(thresholds, function(a, b) return a.percent < b.percent end)

    -- Create tick textures
    for idx, threshold in pairs(thresholds) do
        local tick = frame:CreateTexture(nil, "OVERLAY")
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

    -- Store thresholds for tooltip hit-testing
    frame.tickThresholds = thresholds
end

-- ---------------------------------------------------------------------------
-- Tooltip
-- ---------------------------------------------------------------------------

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

    -- Find which segment the cursor is in
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
    -- If past all thresholds, we're in the final segment
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

    -- Show count info if in an active M+
    local currentCount, totalCount = self:GetCurrentForcesInfo()
    if totalCount and totalCount > 0 then
        local neededCount = math_ceil(totalCount * segEnd / 100)
        GameTooltip:AddLine(string_format(L["PROGRESS_BAR_COUNT"], neededCount), 1, 1, 1)

        local currentPct = (currentCount / totalCount) * 100
        if currentPct >= segEnd then
            GameTooltip:AddLine(L["PROGRESS_BAR_STATUS_COMPLETE"], 0, 1, 0)
        elseif currentPct >= segStart then
            GameTooltip:AddLine(L["PROGRESS_BAR_STATUS_CURRENT"], 1, 1, 0)
        else
            GameTooltip:AddLine(L["PROGRESS_BAR_STATUS_UPCOMING"], 0.5, 0.5, 0.5)
        end
    end

    GameTooltip:Show()
end

-- ---------------------------------------------------------------------------
-- Section State Resolution
-- ---------------------------------------------------------------------------

function KeystonePolaris:GetProgressBarSectionStates(dungeonKey, currentPct, bossKillStates)
    local thresholds = self.progressBarFrame and self.progressBarFrame.tickThresholds
    if not thresholds or #thresholds == 0 then return nil end

    local states = {}

    -- Build segment boundaries
    local boundaries = { 0 }
    local bossIndices = {}
    for i, t in pairs(thresholds) do
        boundaries[#boundaries + 1] = t.percent
        bossIndices[i] = t.bossIndex
    end
    boundaries[#boundaries + 1] = 100

    -- Resolve final segment boss index (threshold >= 100, filtered out of ticks)
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

-- ---------------------------------------------------------------------------
-- Boss Kill States
-- ---------------------------------------------------------------------------

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

-- ---------------------------------------------------------------------------
-- Updates
-- ---------------------------------------------------------------------------

function KeystonePolaris:UpdateProgressBar()
    local frame = self.progressBarFrame
    if not frame then return end

    local pb = self.db.profile.progressBar
    if not pb.enabled then
        frame:Hide()
        return
    end

    -- If previewing, the preview function handles everything
    if self._progressBarPreview then return end

    -- Check for active M+ dungeon
    local currentDungeonID = C_ChallengeMode.GetActiveChallengeMapID()
    if not currentDungeonID or not self.DUNGEONS[currentDungeonID] then
        frame:Hide()
        self._progressBarDungeonKey = nil
        return
    end

    -- Resolve dungeon key
    local dungeonKey = self:GetDungeonKeyById(currentDungeonID)
    if not dungeonKey then
        frame:Hide()
        return
    end

    -- Rebuild ticks if dungeon changed
    if self._progressBarDungeonKey ~= dungeonKey then
        self._progressBarDungeonKey = dungeonKey
        self:BuildProgressBarTicks(dungeonKey)
    end

    -- Get current percentage
    local currentCount, totalCount = self:GetCurrentForcesInfo()
    local currentPct = (totalCount and totalCount > 0) and ((currentCount / totalCount) * 100) or 0

    -- Update segments with live section states
    local bossKillStates = self:GetBossKillStates(dungeonKey)
    local sectionStates = self:GetProgressBarSectionStates(dungeonKey, currentPct, bossKillStates)
    self:UpdateProgressBarSegments(currentPct, sectionStates)
    self:UpdateProgressBarCallout(nil, currentPct)
    frame:Show()
end

function KeystonePolaris:RefreshProgressBar()
    local frame = self.progressBarFrame
    if not frame then return end

    local pb = self.db.profile.progressBar

    -- Update size
    frame:SetSize(pb.width, pb.height)

    -- Update position (skip during drag)
    if not self._progressBarDragging then
        frame:ClearAllPoints()
        frame:SetPoint(pb.position, UIParent, pb.position, pb.xOffset, pb.yOffset)
    end

    -- Update background
    frame.background:SetColorTexture(pb.backgroundColor.r, pb.backgroundColor.g, pb.backgroundColor.b, pb.backgroundColor.a or 0.7)

    -- Update border
    self:ApplyProgressBarBorder()

    -- Rebuild ticks and segments (sizes/positions may have changed)
    if self._progressBarDungeonKey then
        self:BuildProgressBarTicks(self._progressBarDungeonKey)
        local currentPct, bossKillStates
        if self._progressBarPreview then
            -- Preview: read from stored scenario
            currentPct = self._progressBarPreviewPct or 0
            local scenario = self._progressBarPreviewScenarioRef
            local bossesKilled = scenario and scenario.bossesKilled or 0
            bossKillStates = {}
            for idx = 1, bossesKilled do
                bossKillStates[idx] = true
            end
        else
            -- Live: read from dungeon data
            local currentCount, totalCount = self:GetCurrentForcesInfo()
            currentPct = (totalCount and totalCount > 0) and ((currentCount / totalCount) * 100) or 0
            bossKillStates = self:GetBossKillStates(self._progressBarDungeonKey)
        end
        local sectionStates = self:GetProgressBarSectionStates(self._progressBarDungeonKey, currentPct, bossKillStates)
        self:UpdateProgressBarSegments(currentPct, sectionStates)
        self:UpdateProgressBarCallout(nil, currentPct)
    end
end

-- ---------------------------------------------------------------------------
-- Preview Mode
-- ---------------------------------------------------------------------------

function KeystonePolaris:EnableProgressBarPreview()
    if not self.progressBarFrame then
        self:InitializeProgressBar()
    end

    self._progressBarPreview = true

    -- Find first current-season dungeon for sample data
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

    -- Fallback: use first dungeon in GlobalDungeonLookup
    if not previewDungeonKey and self.GlobalDungeonLookup then
        previewDungeonKey = (next(self.GlobalDungeonLookup))
    end

    if previewDungeonKey then
        self._progressBarDungeonKey = previewDungeonKey
        self:BuildProgressBarTicks(previewDungeonKey)

        -- Use shared scenario picker for percentage and boss kills
        local scenarios = self.PreviewScenarios
        local scenarioIdx = self._previewScenario or 1
        local scenario = scenarios and scenarios[scenarioIdx]
        local pct = (scenario and scenario.barPercent) or 74
        self._progressBarPreviewPct = pct
        self._progressBarPreviewScenarioRef = scenario

        local bossesKilled = scenario and scenario.bossesKilled or 0
        local bossKillStates = {}
        for idx = 1, bossesKilled do
            bossKillStates[idx] = true
        end

        local sectionStates = self:GetProgressBarSectionStates(previewDungeonKey, pct, bossKillStates)
        self:UpdateProgressBarSegments(pct, sectionStates)
        self:UpdateProgressBarCallout(nil, pct)
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

    -- Only hide if not in an active M+ dungeon
    local currentDungeonID = C_ChallengeMode.GetActiveChallengeMapID()
    if not currentDungeonID or not self.db.profile.progressBar.enabled then
        self.progressBarFrame:Hide()
        self._progressBarDungeonKey = nil
    end
end
