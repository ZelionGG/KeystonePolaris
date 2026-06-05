local AddOnName, KeystonePolaris = ...
local L = LibStub("AceLocale-3.0"):GetLocale(AddOnName)

local CreateFrame = CreateFrame
local CreateColor = CreateColor
local GameTooltip = GameTooltip
local C_ChallengeMode = C_ChallengeMode
local C_ScenarioInfo = C_ScenarioInfo
local ipairs = ipairs
local pairs = pairs
local math_ceil = math.ceil
local math_max = math.max
local math_min = math.min
local string_format = string.format
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

function KeystonePolaris:GetProgressBarValue(key)
    local pb = self.db and self.db.profile and self.db.profile.progressBar
    if not pb then return nil end
    local value = pb[key]
    if value ~= nil then
        return value
    end
    local defaults = self.defaults and self.defaults.profile and self.defaults.profile.progressBar
    return defaults and defaults[key]
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

local function GetProgressBarCursorPct(addon, frame)
    local pb = addon.db.profile.progressBar
    local barWidth = pb.width
    local cursorX = select(1, GetCursorPosition()) / UIParent:GetEffectiveScale()
    local frameLeft = frame:GetLeft() or 0
    local relativeX = cursorX - frameLeft

    if pb.direction == "RIGHT_TO_LEFT" then
        relativeX = barWidth - relativeX
    end

    return (relativeX / barWidth) * 100
end

local function PreferObjectiveCandidate(candidate, best)
    if not best then
        return true
    end
    if candidate.percent < best.percent then
        return true
    end
    if candidate.percent > best.percent then
        return false
    end

    local candidateOrder = candidate.logicalOrder or math.huge
    local bestOrder = best.logicalOrder or math.huge
    return candidateOrder < bestOrder
end

local function GetProgressBarCurrentPct(addon)
    if addon._progressBarPreview then
        return addon._progressBarPreviewPct or 0
    end

    local currentCount, totalCount = addon:GetCurrentForcesInfo()
    if totalCount and totalCount > 0 then
        return (currentCount / totalCount) * 100
    end

    return 0
end

local function BuildTooltipObjectiveCandidates(addon, frame)
    local candidates = {}
    local pb = addon.db.profile.progressBar
    local barWidth = pb.width
    local bossTickTolerance = (math_max((pb.tickWidth or 0) * 0.5, 2) / math_max(barWidth, 1)) * 100
    local milestoneTickTolerance = (math_max((pb.milestoneTickWidth or 1) * 0.5, 2) / math_max(barWidth, 1)) * 100
    local dungeonKey = addon._progressBarDungeonKey
    local currentPct = GetProgressBarCurrentPct(addon)

    if dungeonKey then
        for logicalOrder, target in ipairs(addon:GetOrderedBossTargets(dungeonKey)) do
            local pct = target.percent
            if pct and pct > 0 then
                candidates[#candidates + 1] = {
                    type = "boss",
                    percent = pct,
                    bossIndex = target.bossIndex,
                    logicalOrder = logicalOrder,
                    tickTolerance = bossTickTolerance,
                }
            end
        end
    end

    if addon:GetProgressBarValue("showMilestoneTicks") then
        for _, threshold in ipairs(frame.milestoneThresholds or {}) do
            if currentPct < threshold.percent then
                candidates[#candidates + 1] = {
                    type = "milestone",
                    percent = threshold.percent,
                    milestone = threshold,
                    tickTolerance = milestoneTickTolerance,
                }
            end
        end
    end

    return candidates
end

local function ObjectiveMatches(hitA, hitB)
    if not hitA or not hitB or hitA.type ~= hitB.type then
        return false
    end

    if hitA.type == "milestone" then
        return hitA.milestone.milestoneIndex == hitB.milestone.milestoneIndex
            and hitA.percent == hitB.percent
    end

    return hitA.bossIndex == hitB.bossIndex and hitA.percent == hitB.percent
end

local function GetNearestObjectiveHit(addon, frame)
    if not addon._progressBarDungeonKey then
        return nil
    end

    local candidates = BuildTooltipObjectiveCandidates(addon, frame)
    if #candidates == 0 then
        return nil
    end

    local cursorPct = GetProgressBarCursorPct(addon, frame)

    local closestHit = nil
    local closestDistance = nil
    for _, candidate in ipairs(candidates) do
        local distance = math.abs(cursorPct - candidate.percent)
        if distance <= candidate.tickTolerance
            and (not closestDistance
                or distance < closestDistance
                or (distance == closestDistance and PreferObjectiveCandidate(candidate, closestHit))) then
            closestHit = candidate
            closestDistance = distance
        end
    end
    if closestHit then
        return closestHit
    end

    local nearestRight = nil
    for _, candidate in ipairs(candidates) do
        if cursorPct <= candidate.percent and PreferObjectiveCandidate(candidate, nearestRight) then
            nearestRight = candidate
        end
    end
    if nearestRight then
        return nearestRight
    end

    local segmentBoss = nil
    for _, candidate in ipairs(candidates) do
        if candidate.type == "boss" and cursorPct >= candidate.percent then
            if not segmentBoss or candidate.percent > segmentBoss.percent then
                segmentBoss = candidate
            end
        end
    end
    if segmentBoss then
        return segmentBoss
    end

    for _, candidate in ipairs(candidates) do
        if candidate.type == "boss" then
            if not segmentBoss or candidate.percent > segmentBoss.percent then
                segmentBoss = candidate
            end
        end
    end

    return segmentBoss or candidates[1]
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

function KeystonePolaris:GetOrderedBossTargets(dungeonKey)
    local dungeonData = self.GlobalDungeonLookup and self.GlobalDungeonLookup[dungeonKey]
    if not dungeonData or not dungeonData.bosses then return {} end

    local dungeonId = self.GetDungeonIdByKey and self:GetDungeonIdByKey(dungeonKey) or nil
    local order = self.GetDungeonSectionOrder and self:GetDungeonSectionOrder(dungeonId, dungeonKey)
    local adv = self.db and self.db.profile and self.db.profile.advanced and self.db.profile.advanced[dungeonKey]
    local useAdvancedRoutes = self.db and self.db.profile and self.db.profile.general
        and self.db.profile.general.advancedOptionsEnabled
    local targets = {}

    if not order then
        order = {}
        for idx = 1, #dungeonData.bosses do
            order[idx] = idx
        end
    end

    for logicalIdx, bossIdx in ipairs(order) do
        local boss = dungeonData.bosses[bossIdx]
        if boss then
            local bossNumber = self.GetBossNumberString and self:GetBossNumberString(bossIdx) or tostring(bossIdx)
            local percent = useAdvancedRoutes and adv and adv["Boss" .. bossNumber] or boss[2]
            targets[logicalIdx] = {
                bossIndex = bossIdx,
                bossNum = boss[1],
                percent = percent or 100,
            }
        end
    end

    return targets
end

local function GetBossProgressTargets(addon, dungeonKey)
    return addon:GetOrderedBossTargets(dungeonKey)
end

local function GetNextAliveBossTarget(targets, bossKillStates)
    if not targets or #targets == 0 then return nil end

    for _, target in ipairs(targets) do
        local bossKilled = bossKillStates and bossKillStates[target.bossIndex] or false
        if not bossKilled then
            return target
        end
    end

    return targets[#targets]
end

local function GetCalloutRemainingPercent(target, currentPct)
    if not target or not target.percent then return 0 end

    local remaining = target.percent - currentPct
    if remaining < 0 then
        remaining = 0
    end
    if remaining < 0.05 and remaining > 0 then
        remaining = 0
    end
    return remaining
end

local function BuildCalloutObjectiveCandidates(addon, dungeonKey, currentPct, bossKillStates, milestoneThresholds)
    local candidates = {}

    if dungeonKey then
        for logicalOrder, target in ipairs(addon:GetOrderedBossTargets(dungeonKey)) do
            local pct = target.percent
            if pct and pct > 0 and currentPct < pct then
                local bossKilled = bossKillStates and bossKillStates[target.bossIndex] or false
                if not bossKilled then
                    candidates[#candidates + 1] = {
                        type = "boss",
                        percent = pct,
                        bossIndex = target.bossIndex,
                        logicalOrder = logicalOrder,
                    }
                end
            end
        end
    end

    if addon:GetProgressBarValue("showMilestoneTicks") and milestoneThresholds then
        for _, threshold in ipairs(milestoneThresholds) do
            if currentPct < threshold.percent then
                candidates[#candidates + 1] = {
                    type = "milestone",
                    percent = threshold.percent,
                    milestone = threshold,
                }
            end
        end
    end

    return candidates
end

local function GetNextCalloutObjective(candidates, currentPct)
    local nextTarget = nil
    for _, candidate in ipairs(candidates) do
        if currentPct < candidate.percent and PreferObjectiveCandidate(candidate, nextTarget) then
            nextTarget = candidate
        end
    end
    return nextTarget
end

local function GetCalloutObjectiveLabel(addon, dungeonKey, objective)
    if objective.type == "milestone" then
        local milestone = objective.milestone
        local label = milestone and milestone.label
        if not label or label == "" then
            label = string_format(L["MILESTONE"], milestone.milestoneIndex or 0)
        end
        return label
    end

    if objective.bossIndex and dungeonKey then
        return addon:GetBossName(dungeonKey, objective.bossIndex) or ("Boss " .. tostring(objective.bossIndex))
    end

    return ""
end

function KeystonePolaris:ResolveProgressBarCallout(dungeonKey, currentPct, bossKillStates, milestoneThresholds)
    if not dungeonKey then
        return nil
    end

    local candidates = BuildCalloutObjectiveCandidates(self, dungeonKey, currentPct, bossKillStates, milestoneThresholds)
    local objective = GetNextCalloutObjective(candidates, currentPct)
    if not objective then
        return nil
    end

    return objective.percent, GetCalloutRemainingPercent(objective, currentPct), GetCalloutObjectiveLabel(self, dungeonKey, objective)
end

local function GetCurrentBossTarget(addon, dungeonKey, _currentPct, bossKillStates)
    return GetNextAliveBossTarget(GetBossProgressTargets(addon, dungeonKey), bossKillStates)
end

local function SplitTooltipLine(formattedText)
    local label, value = formattedText:match("^(.-:%s*)(.+)$")
    if label and value then
        return label, value
    end

    return formattedText, ""
end

local function GetTooltipBossGroup(addon, dungeonKey, thresholdPercent)
    local group = {}

    for _, target in ipairs(addon:GetOrderedBossTargets(dungeonKey)) do
        if target.percent == thresholdPercent then
            group[#group + 1] = target
        end
    end

    return group
end

local function IsBossGroupSectionReached(addon, dungeonKey, bossGroup, bossKillStates)
    if #bossGroup == 0 then
        return false
    end

    local orderedTargets = addon:GetOrderedBossTargets(dungeonKey)
    local firstGroupLogicalIdx = nil

    for logicalIdx, orderedTarget in ipairs(orderedTargets) do
        for _, groupTarget in ipairs(bossGroup) do
            if orderedTarget.bossIndex == groupTarget.bossIndex then
                if not firstGroupLogicalIdx or logicalIdx < firstGroupLogicalIdx then
                    firstGroupLogicalIdx = logicalIdx
                end
                break
            end
        end
    end

    if not firstGroupLogicalIdx or firstGroupLogicalIdx <= 1 then
        return true
    end

    for logicalIdx = 1, firstGroupLogicalIdx - 1 do
        local priorTarget = orderedTargets[logicalIdx]
        if priorTarget and priorTarget.bossIndex and not bossKillStates[priorTarget.bossIndex] then
            return false
        end
    end

    return true
end

local function GetTooltipBossStatus(addon, dungeonKey, target, bossGroup, bossKillStates)
    local isBossKilled = target and target.bossIndex and bossKillStates[target.bossIndex] or false

    if isBossKilled then
        return "Done", "ff00ff00", 0, 1, 0
    end

    if #bossGroup > 1 then
        if not IsBossGroupSectionReached(addon, dungeonKey, bossGroup, bossKillStates) then
            return "Upcoming", "ff808080", 0.5, 0.5, 0.5
        end

        for _, groupTarget in ipairs(bossGroup) do
            local groupKilled = groupTarget.bossIndex and bossKillStates[groupTarget.bossIndex]
            if not groupKilled then
                if groupTarget.bossIndex == target.bossIndex then
                    return "Current", "ffffff00", 1, 1, 0
                end
                return "Upcoming", "ff808080", 0.5, 0.5, 0.5
            end
        end
        return "Upcoming", "ff808080", 0.5, 0.5, 0.5
    end

    local currentTarget = GetCurrentBossTarget(addon, dungeonKey, 0, bossKillStates)
    if currentTarget and target and currentTarget.bossIndex == target.bossIndex then
        return "Current", "ffffff00", 1, 1, 0
    end

    return "Upcoming", "ff808080", 0.5, 0.5, 0.5
end

local function GetObjectiveTooltipKey(addon, hit)
    if hit.type == "milestone" then
        return string_format("milestone:%d:%.2f", hit.milestone.milestoneIndex or 0, hit.percent or 0)
    end

    local dungeonKey = addon._progressBarDungeonKey
    local bossGroup = GetTooltipBossGroup(addon, dungeonKey, hit.percent)
    local bossKillStates = addon:GetBossKillStates(dungeonKey)
    local stateParts = {}
    for _, target in ipairs(bossGroup) do
        stateParts[#stateParts + 1] = string_format(
            "%d:%d",
            target.bossIndex or 0,
            bossKillStates[target.bossIndex] and 1 or 0
        )
    end

    return string_format("boss:%.2f:%s", hit.percent or 0, table.concat(stateParts, ","))
end

local function IsObjectiveCurrentTarget(hit, currentPct, candidates)
    local nextTarget = nil
    for _, candidate in ipairs(candidates) do
        if currentPct < candidate.percent and PreferObjectiveCandidate(candidate, nextTarget) then
            nextTarget = candidate
        end
    end

    return nextTarget and ObjectiveMatches(hit, nextTarget)
end

local function GetTooltipMilestoneStatus(milestone, currentPct, isCurrentTarget)
    if currentPct >= (milestone.percent or 0) then
        return "Complete", "ff00ff00", 0, 1, 0
    end

    if isCurrentTarget then
        return "Current", "ffffff00", 1, 1, 0
    end

    return "Upcoming", "ff808080", 0.5, 0.5, 0.5
end

local function AppendMilestoneTooltipLines(addon, milestone, currentPct, isCurrentTarget)
    local label = milestone.label
    if not label or label == "" then
        label = string_format(L["MILESTONE"], milestone.milestoneIndex or 0)
    end

    local thresholdLabel, thresholdValue = SplitTooltipLine(string_format(L["PROGRESS_BAR_THRESHOLD"], milestone.percent or 0))
    GameTooltip:AddDoubleLine(thresholdLabel, thresholdValue, 1, 0.82, 0, 1, 1, 1)

    local _, totalCount = addon:GetCurrentForcesInfo()
    if totalCount and totalCount > 0 then
        local neededCount = math_ceil(totalCount * (milestone.percent or 0) / 100)
        local countLabel, countValue = SplitTooltipLine(string_format(L["PROGRESS_BAR_COUNT"], neededCount))
        GameTooltip:AddDoubleLine(countLabel, countValue, 1, 0.82, 0, 1, 1, 1)
    end

    local triggerType = milestone.triggerType
    if triggerType and triggerType ~= "none" then
        local matchText = milestone.matchText
        if matchText and matchText ~= "" then
            local triggerLabel, triggerValue = SplitTooltipLine(string_format(L["PROGRESS_BAR_MILESTONE_TRIGGER"], matchText))
            GameTooltip:AddDoubleLine(triggerLabel, triggerValue, 1, 0.82, 0, 1, 1, 1)
        end
    end

    GameTooltip:AddLine(" ")

    local statusText, indicatorColor, statusR, statusG, statusB = GetTooltipMilestoneStatus(milestone, currentPct, isCurrentTarget)
    GameTooltip:AddDoubleLine(
        "|c" .. indicatorColor .. "> |r" .. label,
        statusText,
        1,
        1,
        1,
        statusR,
        statusG,
        statusB
    )
end

local function AppendBossTooltipLines(addon, section)
    local dungeonKey = section.dungeonKey
    local bossGroup = GetTooltipBossGroup(addon, dungeonKey, section.segEnd)
    local thresholdLabel, thresholdValue = SplitTooltipLine(string_format(L["PROGRESS_BAR_THRESHOLD"], section.segEnd))

    GameTooltip:AddDoubleLine(thresholdLabel, thresholdValue, 1, 0.82, 0, 1, 1, 1)

    local _, totalCount = addon:GetCurrentForcesInfo()
    local bossKillStates = addon:GetBossKillStates(dungeonKey)
    if totalCount and totalCount > 0 then
        local neededCount = math_ceil(totalCount * section.segEnd / 100)
        local countLabel, countValue = SplitTooltipLine(string_format(L["PROGRESS_BAR_COUNT"], neededCount))
        GameTooltip:AddDoubleLine(countLabel, countValue, 1, 0.82, 0, 1, 1, 1)
    end

    GameTooltip:AddLine(" ")

    for _, target in ipairs(bossGroup) do
        local bossName = addon:GetBossName(dungeonKey, target.bossIndex) or ("Boss " .. tostring(target.bossIndex))
        local statusText, indicatorColor, statusR, statusG, statusB = GetTooltipBossStatus(addon, dungeonKey, target, bossGroup, bossKillStates)
        GameTooltip:AddDoubleLine(
            "|c" .. indicatorColor .. "> |r" .. bossName,
            statusText,
            1,
            1,
            1,
            statusR,
            statusG,
            statusB
        )
    end
end

function KeystonePolaris:InitializeProgressBar()
    if self.progressBarFrame then return end

    local pb = self.db.profile.progressBar

    local frame = CreateFrame("Frame", "KeystonePolarisProgressBar", UIParent, "BackdropTemplate")
    frame:SetSize(pb.width, pb.height)
    frame:SetPoint(pb.position, UIParent, pb.position, pb.xOffset, self:GetProgressBarValue("yOffset"))
    frame:SetFrameStrata("MEDIUM")
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)

    local borderFrame = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    borderFrame:SetAllPoints(frame)
    borderFrame:SetFrameLevel(frame:GetFrameLevel() + 10)
    borderFrame:EnableMouse(false)
    frame.borderFrame = borderFrame

    local milestoneOverlay = CreateFrame("Frame", nil, frame)
    milestoneOverlay:SetAllPoints(frame)
    milestoneOverlay:SetFrameLevel(borderFrame:GetFrameLevel() + 1)
    milestoneOverlay:EnableMouse(false)
    frame.milestoneOverlay = milestoneOverlay

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
    frame.milestoneTicks = {}
    frame.milestoneThresholds = {}

    frame:SetScript("OnEnter", function(self_frame)
        self_frame._lastTooltipSectionKey = nil
        KeystonePolaris:ShowProgressBarTooltip(self_frame)
        self_frame:SetScript("OnUpdate", function(update_frame)
            KeystonePolaris:ShowProgressBarTooltip(update_frame)
        end)
    end)
    frame:SetScript("OnLeave", function(self_frame)
        self_frame:SetScript("OnUpdate", nil)
        self_frame._lastTooltipSectionKey = nil
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
    callout.bg = bg

    ApplyCalloutStyle(callout, KeystonePolaris.db.profile.progressBar)

    callout:Hide()
    parentFrame.callout = callout
end

function KeystonePolaris:UpdateProgressBarCallout(segmentIndex, currentPct, sectionStates)
    local frame = self.progressBarFrame
    if not frame or not frame.callout then return end

    local pb = self.db.profile.progressBar
    if not self:GetProgressBarValue("showCallout") then
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

    local dungeonKey = self._progressBarDungeonKey
    local bossKillStates
    if self._progressBarPreview then
        bossKillStates = {}
        local scenario = self._progressBarPreviewScenarioRef
        local bossesKilled = scenario and scenario.bossesKilled or 0
        for idx = 1, bossesKilled do
            bossKillStates[idx] = true
        end
    else
        bossKillStates = self:GetBossKillStates(dungeonKey)
    end

    local anchorPct, remaining, label = self:ResolveProgressBarCallout(
        dungeonKey,
        currentPct,
        bossKillStates,
        frame.milestoneThresholds
    )
    if not anchorPct then
        frame.callout:Hide()
        return
    end

    local calloutText = string_format(L["PROGRESS_BAR_CALLOUT_FORMAT"], remaining, label)

    local callout = frame.callout
    ApplyCalloutStyle(callout, pb)
    callout.text:SetText(calloutText)

    local textWidth = callout.text:GetStringWidth() + 12
    local textHeight = callout.text:GetStringHeight() + 8
    callout:SetSize(textWidth, textHeight)
    callout.bg:SetAllPoints(callout)

    local barWidth = pb.width
    local isRTL = pb.direction == "RIGHT_TO_LEFT"
    local xPos = barWidth * (anchorPct / 100)
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

    for idx, tick in ipairs(frame.ticks) do
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
            local progressEnd = math_max(segStart, math_min(currentPct, segEnd))
            segIdx = drawSpan(segIdx, segStart, progressEnd, "inProgress")
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

    local borderStyle = self:GetProgressBarValue("borderStyle")

    if borderStyle == "NONE" then
        borderFrame:SetBackdrop(nil)
        return
    end

    local edgeFile
    local edgeSize = pb.borderSize
    local insets = pb.borderInsets

    if borderStyle == "SOLID" then
        edgeFile = "Interface\\Buttons\\WHITE8X8"
    elseif borderStyle == "LSM_BORDER" then
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

    local thresholds = {}
    for _, target in ipairs(self:GetOrderedBossTargets(dungeonKey)) do
        local pct = target.percent
        if pct and pct > 0 and pct < 100 then
            thresholds[#thresholds + 1] = {
                percent = pct,
                bossIndex = target.bossIndex,
                bossNum = target.bossNum,
            }
        end
    end

    local tickParent = frame.borderFrame or frame
    for idx, threshold in ipairs(thresholds) do
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

function KeystonePolaris:GetProgressBarMilestoneThresholds(dungeonKey, scenario)
    scenario = scenario or (self._progressBarPreview and self._progressBarPreviewScenarioRef)
    if scenario and type(scenario.previewMilestones) == "table" and #scenario.previewMilestones > 0 then
        return scenario.previewMilestones
    end

    local dungeonId = self:GetDungeonIdByKey(dungeonKey)
    if not dungeonId then return {} end

    local thresholds = {}
    for _, milestone in ipairs(self:GetSortedMilestones(dungeonId)) do
        local pct = tonumber(milestone.neededPercent) or 0
        if pct > 0 and pct < 100 then
            thresholds[#thresholds + 1] = {
                percent = pct,
                milestoneIndex = milestone.milestoneIndex,
                label = milestone.label,
                triggerType = milestone.triggerType,
                matchText = milestone.matchText,
            }
        end
    end
    return thresholds
end

function KeystonePolaris:BuildProgressBarMilestoneTicks(dungeonKey)
    local frame = self.progressBarFrame
    if not frame then return end

    for _, tick in pairs(frame.milestoneTicks or {}) do
        tick:Hide()
        tick:SetParent(nil)
    end
    frame.milestoneTicks = {}
    frame.milestoneThresholds = {}

    if not self:GetProgressBarValue("showMilestoneTicks") or not dungeonKey then
        return
    end

    local pb = self.db.profile.progressBar
    local barWidth = pb.width
    local barHeight = pb.height
    local milestoneTickWidth = pb.milestoneTickWidth or 1
    local milestoneOverflow = math_max(0, math_ceil((pb.tickOverflow or 0) / 2))
    local scenario = self._progressBarPreview and self._progressBarPreviewScenarioRef
    local thresholds = self:GetProgressBarMilestoneThresholds(dungeonKey, scenario)
    local tickParent = frame.milestoneOverlay or frame

    for idx, threshold in ipairs(thresholds) do
        local tick = tickParent:CreateTexture(nil, "OVERLAY", nil, 1)
        local color = pb.milestoneTickColor or { r = 1, g = 0.82, b = 0, a = 1 }
        tick:SetColorTexture(color.r, color.g, color.b, color.a)
        tick:SetSize(milestoneTickWidth, barHeight + milestoneOverflow * 2)

        local xPos = barWidth * (threshold.percent / 100)
        if pb.direction == "RIGHT_TO_LEFT" then
            xPos = barWidth - xPos
        end
        tick:SetPoint("CENTER", frame, "LEFT", xPos, 0)
        tick:Show()

        frame.milestoneTicks[idx] = tick
    end

    frame.milestoneThresholds = thresholds
end

function KeystonePolaris:UpdateProgressBarMilestoneTicks(currentPct)
    local frame = self.progressBarFrame
    if not frame or not frame.milestoneThresholds or not self:GetProgressBarValue("showMilestoneTicks") then
        return
    end

    local pb = self.db.profile.progressBar
    local upcomingColor = pb.milestoneTickColor or { r = 1, g = 0.82, b = 0, a = 1 }

    for idx, tick in ipairs(frame.milestoneTicks) do
        local threshold = frame.milestoneThresholds[idx]
        local passed = threshold and currentPct >= threshold.percent
        if passed then
            tick:Hide()
        else
            tick:SetColorTexture(upcomingColor.r, upcomingColor.g, upcomingColor.b, upcomingColor.a)
            tick:Show()
        end
    end
end

function KeystonePolaris:ShowProgressBarTooltip(frame)
    local hit = GetNearestObjectiveHit(self, frame)
    if not hit then
        GameTooltip:Hide()
        frame._lastTooltipSectionKey = nil
        return
    end

    local tooltipKey = GetObjectiveTooltipKey(self, hit)
    if frame._lastTooltipSectionKey == tooltipKey and GameTooltip:IsOwned(frame) then
        return
    end

    frame._lastTooltipSectionKey = tooltipKey

    local currentCount, totalCount = self:GetCurrentForcesInfo()
    local currentPct = (totalCount and totalCount > 0) and ((currentCount / totalCount) * 100) or 0
    local candidates = BuildTooltipObjectiveCandidates(self, frame)
    local isCurrentTarget = IsObjectiveCurrentTarget(hit, currentPct, candidates)

    GameTooltip:SetOwner(frame, "ANCHOR_TOP")
    GameTooltip:ClearLines()

    if hit.type == "milestone" then
        AppendMilestoneTooltipLines(self, hit.milestone, currentPct, isCurrentTarget)
    else
        AppendBossTooltipLines(self, {
            dungeonKey = self._progressBarDungeonKey,
            segEnd = hit.percent,
            bossIndex = hit.bossIndex,
        })
    end

    GameTooltip:Show()
end

function KeystonePolaris:GetProgressBarSectionStates(dungeonKey, currentPct, bossKillStates)
    local thresholds = self.progressBarFrame and self.progressBarFrame.tickThresholds
    if not thresholds or #thresholds == 0 then return nil end

    local states = {}

    local boundaries = { 0 }
    local bossIndices = {}
    for i, t in ipairs(thresholds) do
        boundaries[#boundaries + 1] = t.percent
        bossIndices[i] = t.bossIndex
    end
    boundaries[#boundaries + 1] = 100

    if not bossIndices[#boundaries - 1] then
        local targets = self:GetOrderedBossTargets(dungeonKey)
        bossIndices[#boundaries - 1] = targets[#targets] and targets[#targets].bossIndex or nil
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

    if not self:GetProgressBarValue("enabled") then
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
        self:BuildProgressBarMilestoneTicks(dungeonKey)
    end

    local currentCount, totalCount = self:GetCurrentForcesInfo()
    local currentPct = (totalCount and totalCount > 0) and ((currentCount / totalCount) * 100) or 0

    local bossKillStates = self:GetBossKillStates(dungeonKey)
    local sectionStates = self:GetProgressBarSectionStates(dungeonKey, currentPct, bossKillStates)
    self:UpdateProgressBarTickColors(bossKillStates)
    self:UpdateProgressBarMilestoneTicks(currentPct)
    self:UpdateProgressBarSegments(currentPct, sectionStates)
    self:UpdateProgressBarCallout(nil, currentPct, sectionStates)
    frame:Show()
end

function KeystonePolaris:RefreshProgressBarOptionsPreview()
    local widget = self._progressBarPreviewWidget
    if widget and widget.RefreshPreview then
        widget:RefreshPreview()
    end
end

function KeystonePolaris:RefreshProgressBar()
    local frame = self.progressBarFrame
    if frame then
        local pb = self.db.profile.progressBar

        frame:SetSize(pb.width, pb.height)

        if not self._progressBarDragging then
            frame:ClearAllPoints()
            frame:SetPoint(pb.position, UIParent, pb.position, pb.xOffset, self:GetProgressBarValue("yOffset"))
        end

        frame.background:SetColorTexture(pb.backgroundColor.r, pb.backgroundColor.g, pb.backgroundColor.b, pb.backgroundColor.a or 0.7)

        self:ApplyProgressBarBorder()

        if self._progressBarDungeonKey then
            self:BuildProgressBarTicks(self._progressBarDungeonKey)
            self:BuildProgressBarMilestoneTicks(self._progressBarDungeonKey)
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
            self:UpdateProgressBarMilestoneTicks(currentPct)
            self:UpdateProgressBarSegments(currentPct, sectionStates)
            self:UpdateProgressBarCallout(nil, currentPct, sectionStates)
        end
    end

    self:RefreshProgressBarOptionsPreview()
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
    if not currentDungeonID or not self:GetProgressBarValue("enabled") then
        self.progressBarFrame:Hide()
        self._progressBarDungeonKey = nil
    end
end
