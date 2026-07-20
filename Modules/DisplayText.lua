local AddOnName, KeystonePolaris = ...
local L = LibStub("AceLocale-3.0"):GetLocale(AddOnName)

-- Display text formatting and live percentage updates

local function formatProjectedValue(base, value, hexColor, suffix)
    local displayed = suffix or tostring(value)
    return string.format("%s (|cff%s%s|r)", base, hexColor, displayed)
end

local function appendSupplementaryDisplayText(baseText, extraText, cfg)
    if not extraText or extraText == "" then
        return baseText
    end
    if not baseText or baseText == "" then
        return extraText
    end
    if cfg and cfg.multiLine then
        return baseText .. "\n" .. extraText
    end
    local sep = (cfg and cfg.singleLineSeparator) and tostring(cfg.singleLineSeparator) or " | "
    return baseText .. sep .. extraText
end

KeystonePolaris.AppendSupplementaryDisplayText = appendSupplementaryDisplayText

-- ---------------------------------------------------------------------------
-- Logic & Formatting
-- ---------------------------------------------------------------------------

-- Update the displayed percentage text based on dungeon progress
function KeystonePolaris:UpdatePercentageText()
    if not self.displayFrame then return end

    -- Test Mode: render preview and bypass real dungeon state
    if self._testMode then
        if self.RenderTestText then self:RenderTestText() end
        return
    end

    -- Initialize dungeon tracking if needed
    self:InitiateDungeon()

    -- Check if we're in a supported dungeon
    local currentDungeonID = C_ChallengeMode.GetActiveChallengeMapID()
    if currentDungeonID == nil or not self.DUNGEONS[currentDungeonID] then
        if self.progressBarFrame and not self._progressBarPreview then
            self.progressBarFrame:Hide()
            self._progressBarDungeonKey = nil
        end
        self.displayFrame.text:SetText("")
        return
    end

    -- Get current enemy forces counts and percentage
    local currentCount, totalCount = self:GetCurrentForcesInfo()
    local currentPercentage = (totalCount and totalCount > 0) and ((currentCount / totalCount) * 100) or self:GetCurrentPercentage()
    -- Try to get current pull percent from MDT
    local currentPullPercent = self:GetCurrentPullPercent()
    local currentPullCount = tonumber(self.realPull and self.realPull.sum) or 0

    -- Skip sections that have 0 or negative percentage requirements
    if not self.currentSectionOrder then
        self:BuildSectionOrder(self.currentDungeonID)
    end
    local skipOrder = self.currentSectionOrder
    while skipOrder and self.currentSection <= #skipOrder do
        local idx = skipOrder[self.currentSection]
        local dungeon = self.DUNGEONS[self.currentDungeonID]
        if not idx or not dungeon or not dungeon[idx] or dungeon[idx][2] > 0 then
            break
        end
        self.currentSection = self.currentSection + 1
    end

    local bossSection = self:GetDungeonData()
    local cfg = self.db.profile.general.mainDisplay
    local milestonesEnabled = cfg and cfg.showMilestones ~= false
    local milestoneMaxThreshold = bossSection and (tonumber(bossSection.neededPercent) or nil) or nil
    local activeMilestone = milestonesEnabled and self.GetActiveMilestone and self:GetActiveMilestone(self.currentDungeonID, currentPercentage, milestoneMaxThreshold) or nil
    local completedMilestone = milestonesEnabled and self.GetJustCompletedMilestone and self:GetJustCompletedMilestone(self.currentDungeonID, currentPercentage, milestoneMaxThreshold) or nil
    if completedMilestone then
        self._milestoneDoneTextUntil = GetTime() + 2
    end
    local showMilestoneDoneText = self._milestoneDoneTextUntil and GetTime() < self._milestoneDoneTextUntil

    if not bossSection then
        local doneColor = self.db.profile.color.finished
        local doneText = self:FormatMainDisplayText(L["DUNGEON_DONE"], currentPercentage, currentPullPercent, nil, nil)
        if showMilestoneDoneText and self.BuildMilestoneDoneDisplayText then
            doneText = appendSupplementaryDisplayText(doneText, self:BuildMilestoneDoneDisplayText(), cfg)
        elseif activeMilestone then
            doneText = appendSupplementaryDisplayText(doneText, self:BuildMilestoneDisplayText(activeMilestone), cfg)
        end
        self.displayFrame.text:SetText(doneText)
        self.displayFrame.text:SetTextColor(doneColor.r, doneColor.g, doneColor.b, doneColor.a)
        self:AdjustDisplayFrameSize()
        self:ApplyTextLayout()
        if self.HideInformButton then self:HideInformButton() end
        return
    end

    local neededPercent = tonumber(bossSection.neededPercent) or 0

    -- Calculate remaining needed (percent and count)
    local remainingPercent = neededPercent - currentPercentage
    if remainingPercent < 0 then
        remainingPercent = 0.00
    end
    if remainingPercent < 0.05 and remainingPercent > 0.00 then
        remainingPercent = 0.00
    end

    local isSectionTriggerMet = self:IsSectionTriggerMet(bossSection)

    local shouldInfom = bossSection.shouldInform == true
    local haveInformed = bossSection.haveInformed == true

    local remainingCount = 0
    if totalCount and totalCount > 0 then
        local neededCount = math.ceil((neededPercent / 100) * totalCount)
        remainingCount = math.max(0, neededCount - (currentCount or 0))
    end

    local formatMode = cfg and cfg.formatMode or "percent"
    local fmtData = {
        currentCount = currentCount or 0,
        totalCount = totalCount or 0,
        pullCount = currentPullCount or 0,
        remainingCount = remainingCount or 0,
        sectionRequiredPercent = neededPercent or 0,
        sectionRequiredCount = ((totalCount and totalCount > 0) and math.ceil((neededPercent / 100) * totalCount) or 0),
    }
    local displayPercent = string.format("%.2f%%", remainingPercent)
    local displayCount = tostring(remainingCount)
    local color = self.db.profile.color.inProgress
    local displayText

    if remainingPercent > 0 and isSectionTriggerMet then
        if shouldInfom and not haveInformed and self.db.profile.general.informGroup then
            self:InformGroup(remainingPercent)
            if self.MarkSectionInformed then
                self:MarkSectionInformed(bossSection)
            end
        end
        color = self.db.profile.color.missing
        local base = (formatMode == "count") and displayCount or displayPercent
        displayText = self:FormatMainDisplayText(base, currentPercentage, currentPullPercent, remainingPercent, fmtData)
    elseif remainingPercent > 0 and not isSectionTriggerMet then
        local base = (formatMode == "count") and displayCount or displayPercent
        displayText = self:FormatMainDisplayText(base, currentPercentage, currentPullPercent, remainingPercent, fmtData)
    elseif remainingPercent <= 0 and not isSectionTriggerMet then
        color = self.db.profile.color.finished
        if(currentPercentage >= 100) then
            displayText = self:FormatMainDisplayText(L["FINISHED"], currentPercentage, currentPullPercent, remainingPercent, fmtData)
        else
            displayText = self:FormatMainDisplayText(L["DONE"], currentPercentage, currentPullPercent, remainingPercent, fmtData)
        end
        if self.HideInformButton then self:HideInformButton() end
    elseif remainingPercent <= 0 and isSectionTriggerMet then
        color = self.db.profile.color.finished
        if(currentPercentage >= 100) then
            displayText = self:FormatMainDisplayText(L["FINISHED"], currentPercentage, currentPullPercent, remainingPercent, fmtData)
        else
            displayText = self:FormatMainDisplayText(L["SECTION_DONE"], currentPercentage, currentPullPercent, remainingPercent, fmtData)
        end
        self.currentSection = self.currentSection + 1
        if self.currentSectionOrder and self.currentSection <= #self.currentSectionOrder then
            C_Timer.After(2, function()
                local order = self.currentSectionOrder
                local dungeon = self.DUNGEONS[self.currentDungeonID]
                local sectionIndex = order and order[self.currentSection]
                local nextRequired = 0
                if dungeon and sectionIndex and dungeon[sectionIndex] then
                    nextRequired = dungeon[sectionIndex][2] - currentPercentage
                end
                if nextRequired < 0 then
                    nextRequired = 0.00
                end
                if currentPercentage >= 100 then
                    color = self.db.profile.color.finished
                    self.displayFrame.text:SetText(self:FormatMainDisplayText(L["FINISHED"], currentPercentage, currentPullPercent, nil, fmtData))
                else
                    if nextRequired == 0 then
                        color = self.db.profile.color.finished
                        self.displayFrame.text:SetText(self:FormatMainDisplayText(L["DONE"], currentPercentage, currentPullPercent, nil, fmtData))
                    else
                        color = self.db.profile.color.inProgress
                        local nextNeededPercent = 0
                        if dungeon and sectionIndex and dungeon[sectionIndex] then
                            nextNeededPercent = dungeon[sectionIndex][2]
                        end
                        local nextNeededCount = (totalCount and totalCount > 0) and math.ceil((nextNeededPercent / 100) * totalCount) or 0
                        local nextRemainingCount = (totalCount and totalCount > 0) and math.max(0, nextNeededCount - (currentCount or 0)) or 0
                        local baseNext
                        if (cfg and cfg.formatMode == "count") and (totalCount and totalCount > 0) then
                            baseNext = tostring(nextRemainingCount)
                        else
                            baseNext = string.format("%.2f%%", nextRequired)
                        end
                        local fmtNext = {
                            currentCount = currentCount or 0,
                            totalCount = totalCount or 0,
                            pullCount = currentPullCount or 0,
                            remainingCount = nextRemainingCount or 0,
                            sectionRequiredPercent = nextNeededPercent or 0,
                            sectionRequiredCount = nextNeededCount or 0,
                        }
                        local nextText = self:FormatMainDisplayText(baseNext, currentPercentage, currentPullPercent, nextRequired, fmtNext)
                        local nextMilestone = self.GetActiveMilestone and self:GetActiveMilestone(self.currentDungeonID, currentPercentage, nextNeededPercent) or nil
                        if showMilestoneDoneText and self.BuildMilestoneDoneDisplayText then
                            nextText = appendSupplementaryDisplayText(nextText, self:BuildMilestoneDoneDisplayText(), cfg)
                        elseif nextMilestone then
                            nextText = appendSupplementaryDisplayText(nextText, self:BuildMilestoneDisplayText(nextMilestone), cfg)
                        end
                        self.displayFrame.text:SetText(nextText)
                    end
                end
                self.displayFrame.text:SetTextColor(color.r, color.g, color.b, color.a)
                self:AdjustDisplayFrameSize()
                self:ApplyTextLayout()
            end)
        else
            self.displayFrame.text:SetText(self:FormatMainDisplayText(L["DUNGEON_DONE"], currentPercentage, currentPullPercent, nil, fmtData))
        end
    end

    local bossShouldShowInform = (remainingPercent > 0) and isSectionTriggerMet and shouldInfom and self.db.profile.general.informGroup

    if activeMilestone and not showMilestoneDoneText then
        local milestoneRemaining = tonumber(activeMilestone.remainingPercent) or 0
        if not bossShouldShowInform and activeMilestone.shouldInform and not activeMilestone.haveInformed and activeMilestone.triggerMet and milestoneRemaining > 0 and self.db.profile.general.informGroup then
            if self.BuildInformMessage then
                self:PrepareInformMacro(self:BuildInformMessage(milestoneRemaining, activeMilestone.informSuffix))
            else
                self:InformGroup(milestoneRemaining)
            end
            if self.MarkSectionInformed then
                self:MarkSectionInformed(activeMilestone)
            end
            activeMilestone.haveInformed = true
        end
        if displayText and displayText ~= "" then
            displayText = appendSupplementaryDisplayText(displayText, self:BuildMilestoneDisplayText(activeMilestone), cfg)
        end
    elseif showMilestoneDoneText and self.BuildMilestoneDoneDisplayText then
        if displayText and displayText ~= "" then
            displayText = appendSupplementaryDisplayText(displayText, self:BuildMilestoneDoneDisplayText(), cfg)
        end
    end

    if displayText and displayText ~= "" then
        self.displayFrame.text:SetText(displayText)
    end

    local milestoneShouldShowInform = false
    if activeMilestone and not showMilestoneDoneText and not bossShouldShowInform then
        local milestoneRemaining = tonumber(activeMilestone.remainingPercent) or 0
        milestoneShouldShowInform = milestoneRemaining > 0 and activeMilestone.triggerMet and activeMilestone.shouldInform and self.db.profile.general.informGroup
    end
    local shouldShowInform = bossShouldShowInform or milestoneShouldShowInform
    local informBtn = self.informSecureButton
    if shouldShowInform and not InCombatLockdown() and self.EnsureInformSecureButton then
        local prefix = (self.GetChatPrefix and self:GetChatPrefix(true, true)) or "[Keystone Polaris]"
        local informPercent = remainingPercent
        if milestoneShouldShowInform and activeMilestone then
            informPercent = tonumber(activeMilestone.remainingPercent) or 0
        end
        local message
        if self.BuildInformMessage then
            local suffixOverride = nil
            if milestoneShouldShowInform and activeMilestone then
                suffixOverride = activeMilestone.informSuffix
            end
            message = self:BuildInformMessage(informPercent, suffixOverride)
        else
            message = prefix .. ": " .. L["WE_STILL_NEED"] .. " " .. string.format("%.2f%%", informPercent)
        end
        local selected = self.db
            and self.db.profile
            and self.db.profile.general
            and self.db.profile.general.informChannel
            or "PARTY"
        local slash
        if selected == "PARTY" then
            slash = "p"
        elseif selected == "SAY" then
            slash = "s"
        elseif selected == "YELL" then
            slash = "y"
        else
            slash = "s"
        end
        local macroText = string.format("/%s %s", slash, tostring(message or ""))
        self:EnsureInformSecureButton(macroText)
        informBtn = self.informSecureButton
    elseif not informBtn and self.db.profile.general.informGroup and self.EnsureInformSecureButton then
        self:EnsureInformSecureButton()
        informBtn = self.informSecureButton
    end

    if informBtn then
        if InCombatLockdown() then
            if self.ApplyInformCombatVisualState then
                self:ApplyInformCombatVisualState(shouldShowInform)
            end
            self._pendingInformVisibility = shouldShowInform
            if self.EnsureInformWatcher then
                self:EnsureInformWatcher()
            end
        else
            self:ApplyInformVisibility(shouldShowInform)
        end
    end

    self.displayFrame.text:SetTextColor(color.r, color.g, color.b, color.a)
    self:AdjustDisplayFrameSize()
    self:ApplyTextLayout()
end


-- Helper for coloring prefix text
local function colorizePrefix(text, hexColor)
    return string.format("|cff%s%s|r", hexColor or "cccccc", tostring(text or ""))
end

local function getMilestonePrefixHex(self)
    if not self.colorCache.prefix then
        self:UpdateColorCache()
    end
    local cfg = self.db and self.db.profile and self.db.profile.general and self.db.profile.general.mainDisplay
    if cfg and cfg.customMilestonePrefixColor then
        return self.colorCache.milestonePrefix or self.colorCache.prefix or "cccccc"
    end
    return self.colorCache.prefix or "cccccc"
end

function KeystonePolaris:BuildMilestoneDisplayText(milestone)
    if type(milestone) ~= "table" then return "" end

    if not self.colorCache.prefix then self:UpdateColorCache() end
    local cfg = self.db and self.db.profile and self.db.profile.general and self.db.profile.general.mainDisplay or nil
    local hexMilestonePrefix = getMilestonePrefixHex(self)
    local hexMissing = self.colorCache.missing or "ff0000"
    local hexFinished = self.colorCache.finished or "00ff00"

    local label = milestone.label
    if type(label) ~= "string" or label == "" then
        if self.GetMilestoneTriggerDisplayText then
            label = self.GetMilestoneTriggerDisplayText(milestone)
        else
            label = milestone.matchText
        end
    end
    if type(label) ~= "string" or label == "" then
        label = L["MILESTONE"]
    end

    local milestonePrefixText = (cfg and cfg.milestoneLabel) or L["MILESTONE_DISPLAY_DEFAULT"]
    local prefix = colorizePrefix(milestonePrefixText, hexMilestonePrefix)
    local remaining = tonumber(milestone.remainingPercent) or 0
    local valueText
    if remaining > 0 then
        local percentText = string.format("%.2f%%", remaining)
        local isMissedMilestone = milestone.triggerMet == true and milestone.triggerMatchedNow ~= true
        if isMissedMilestone then
            valueText = string.format("|cff%s%s|r", hexMissing, percentText)
        else
            valueText = percentText
        end
    elseif milestone.triggerMet then
        valueText = string.format("|cff%s%s|r", hexFinished, L["DONE"])
    else
        valueText = "0.00%"
    end

    return string.format("%s %s - %s", prefix, label, valueText)
end

function KeystonePolaris:BuildMilestoneDoneDisplayText()
    if not self.colorCache.finished then self:UpdateColorCache() end
    local hexFinished = self.colorCache.finished or "00ff00"
    return string.format("|cff%s%s|r", hexFinished, L["MILESTONE_PERCENTAGE_DONE"])
end

-- FormatMainDisplayText: builds the final display string with optional Current/Pull/Required parts and projected values.
function KeystonePolaris:FormatMainDisplayText(baseText, currentPercent, currentPullPercent, remainingNeeded, fmtData)
    local cfg = self.db and self.db.profile and self.db.profile.general and self.db.profile.general.mainDisplay or nil
    if not cfg then return baseText end

    -- If dungeon percentage is done (100%) or dungeon is fully done, show only the end text (no extras appended)
    if type(baseText) == "string" and (baseText == L["FINISHED"] or baseText == L["DUNGEON_DONE"]) then
        return baseText
    end

    local extras = {}

    -- Ensure cache is populated (lazy load if needed)
    if not self.colorCache.prefix then self:UpdateColorCache() end

    -- Use cached hex colors
    local hexPrefix = self.colorCache.prefix or "cccccc"
    local hexFinished = self.colorCache.finished or "00ff00"

    -- Display logic notes:
    -- - Projected values (the parenthesized part) are shown only while in combat (showProj below).
    -- - Base Current can be highlighted even out of combat if it already meets the section requirement.
    -- - All comparisons use greater-than-or-equal (>=); values are already rounded to two decimals.

    if cfg.showCurrentPercent and (currentPercent ~= nil) then
        local label = colorizePrefix(cfg.currentLabel or L["CURRENT_DEFAULT"], hexPrefix)
        local inCombat = self:IsCombatContext()
        local showProj = (cfg.showProjected and inCombat and not self.isMidnight) and true or false
        if (cfg.formatMode == "count") and fmtData then
            -- Current (count) base highlighting:
            -- If currentCount >= sectionRequiredCount, color the base value in finished green (works out of combat too).
            local cc = tonumber(fmtData.currentCount) or 0
            local tt = tonumber(fmtData.totalCount) or 0
            local pullC = tonumber(fmtData.pullCount) or 0
            local ccStr = tostring(cc)
            do
                local reqC = tonumber(fmtData.sectionRequiredCount) or 0
                if reqC > 0 and cc >= reqC then
                    ccStr = string.format("|cff%s%s|r", hexFinished, ccStr)
                end
            end
            local baseStr = string.format("%s %s/%d", label, ccStr, tt)
            if showProj and (pullC or 0) > 0 then
                -- Current (count) projected highlighting (combat only):
                -- If (currentCount + pullCount) >= sectionRequiredCount, color the parenthesized value in finished green.
                local projC = cc + pullC
                if projC < 0 then projC = 0 end
                if tt > 0 and projC > tt then projC = tt end
                local paren = string.format("%d/%d", projC, tt)
                local reqC = tonumber(fmtData.sectionRequiredCount) or 0
                if inCombat and reqC > 0 and projC >= reqC then
                    paren = string.format("|cff%s%s|r", hexFinished, paren)
                end
                baseStr = string.format("%s (%s)", baseStr, paren)
            end
            table.insert(extras, baseStr)
        else
            -- Current (percent) base highlighting:
            -- If currentPercent >= sectionRequiredPercent, color the base value in finished green (works out of combat too).
            local cur = tonumber(currentPercent) or 0
            local pull = tonumber(currentPullPercent) or 0
            local proj = cur + pull
            if proj < 0 then proj = 0 end
            if proj > 100 then proj = 100 end
            local curStr = string.format("%.2f%%", cur)
            if fmtData and tonumber(fmtData.sectionRequiredPercent) then
                local req = tonumber(fmtData.sectionRequiredPercent) or 0
                if req > 0 and cur >= req then
                    curStr = string.format("|cff%s%s|r", hexFinished, curStr)
                end
            end
            local baseStr = string.format("%s %s", label, curStr)
            if showProj and ((currentPullPercent or 0) > 0) then
                -- Current (percent) projected highlighting (combat only):
                -- If (currentPercent + pullPercent) >= sectionRequiredPercent, color the parenthesized value in finished green.
                local paren = string.format("%.2f%%", proj)
                if inCombat and fmtData and tonumber(fmtData.sectionRequiredPercent) then
                    local req = tonumber(fmtData.sectionRequiredPercent) or 0
                    if req > 0 and proj >= req then
                        paren = string.format("|cff%s%s|r", hexFinished, paren)
                    end
                end
                baseStr = string.format("%s (%s)", baseStr, paren)
            end
            table.insert(extras, baseStr)
        end
    end
    if cfg.showCurrentPullPercent and (currentPullPercent ~= nil) and self:IsCombatContext() and not self.isMidnight then
        -- Pull highlighting:
        -- If Pull >= section required (percent or count), color Pull in finished green. Not gated by combat.
        local label = colorizePrefix(cfg.pullLabel or L["PULL_DEFAULT"], hexPrefix)
        if cfg.formatMode == "count" and fmtData then
            local pullCount = tonumber(fmtData.pullCount) or 0
            if pullCount > 0 then
                local value = tostring(pullCount)
                local reqC = tonumber(fmtData.sectionRequiredCount) or 0
                if reqC > 0 and pullCount >= reqC then
                    value = string.format("|cff%s%s|r", hexFinished, value)
                end
                table.insert(extras, string.format("%s %s", label, value))
            end
        else
            local pullPct = tonumber(currentPullPercent) or 0
            if pullPct > 0 then
                local value = string.format("%.2f%%", pullPct)
                -- Highlight pull if it meets or exceeds the total required for the current section
                if fmtData and tonumber(fmtData.sectionRequiredPercent) then
                    local req = tonumber(fmtData.sectionRequiredPercent) or 0
                    if req > 0 and pullPct >= req then
                        value = string.format("|cff%s%s|r", hexFinished, value)
                    end
                end
                table.insert(extras, string.format("%s %s", label, value))
            end
        end

    end

    -- Optionally show the base required text prefix if it's numeric
    local isNumericPercent = type(baseText) == "string" and baseText:find("%%$") and tonumber((baseText:gsub("%%",""))) ~= nil
    local isNumericCount = type(baseText) == "string" and baseText:find("^%d+$") ~= nil
    local base
    if isNumericPercent then
        if cfg.showRequiredText == false then
            base = baseText
        else
            local rlabel = colorizePrefix(cfg.requiredLabel or L["REQUIRED_DEFAULT"], hexPrefix)
            base = rlabel .. " " .. baseText
        end
    elseif isNumericCount and (cfg.formatMode == "count") then
        if cfg.showRequiredText == false then
            base = baseText
        else
            local rlabel = colorizePrefix(cfg.requiredLabel or L["REQUIRED_DEFAULT"], hexPrefix)
            base = rlabel .. " " .. baseText
        end
    else
        base = baseText -- keep DONE/SECTION DONE/FINISHED as-is without label
    end

    -- Required (projected) behavior (combat only):
    -- - If the base is numeric, append a parenthesized projected value.
    -- - If the projection completes the target:
    --     * Last section: (FINISHED) only if projected total >= 100 and all bosses are killed; otherwise (DONE).
    --     * Other sections: (DONE).
    -- - Else: show the numeric projected value (percent or count).
    -- The suffix is colored using the finished color.
    -- Note: projected values are hidden out of combat via the showProjected + UnitAffectingCombat gate.
    -- Optionally append projected value next to numeric Required base (do not replace base label)
    if cfg.showProjected and self:IsCombatContext() and not self.isMidnight then
        if isNumericPercent and (type(remainingNeeded) == "number") then
            local pull = tonumber(currentPullPercent) or 0
            local projReq = (tonumber(remainingNeeded) or 0) - pull
            if projReq < 0 then projReq = 0 end
            if projReq > 100 then projReq = 100 end
            -- Round to two decimals to avoid printing 0.00% instead of DONE when the true value is an epsilon > 0
            local projReqRounded = math.floor((projReq * 100) + 0.5) / 100
            local projTotal = tonumber(currentPercent or 0) + (tonumber(currentPullPercent) or 0)
            if projTotal < 0 then projTotal = 0 end
            if projTotal > 100 then projTotal = 100 end
            if projReqRounded <= 0 then
                -- Distinction: Section done vs Dungeon percentage done vs Dungeon finished (projected)
                local suffix
                local isLastSection = false
                if self.currentSectionOrder then
                    isLastSection = (self.currentSection == #self.currentSectionOrder)
                elseif self.DUNGEONS and self.currentDungeonID and self.DUNGEONS[self.currentDungeonID] then
                    isLastSection = (self.currentSection == #self.DUNGEONS[self.currentDungeonID])
                end
                if projTotal >= 100 then
                    suffix = L["FINISHED"]
                elseif isLastSection then
                    suffix = L["DONE"]
                else
                    suffix = L["DONE"]
                end
                base = string.format("%s (|cff%s%s|r)", base, hexFinished, suffix)
            else
                base = string.format("%s (%.2f%%)", base, projReqRounded)
            end
        elseif isNumericCount and (cfg.formatMode == "count") and fmtData then
            local cc   = tonumber(fmtData.currentCount) or 0
            local tt   = tonumber(fmtData.totalCount) or 0
            local remC = tonumber(fmtData.remainingCount) or 0
            local pullC = tonumber(fmtData.pullCount) or 0
            local projC = remC - pullC
            if projC < 0 then projC = 0 end
            if projC == 0 then
                local suffix
                local projShare = 0
                if tt > 0 then projShare = ((cc + pullC) / tt) * 100 end
                if projShare > 100 then projShare = 100 end
                local isLastSection = false
                if self.currentSectionOrder then
                    isLastSection = (self.currentSection == #self.currentSectionOrder)
                elseif self.DUNGEONS and self.currentDungeonID and self.DUNGEONS[self.currentDungeonID] then
                    isLastSection = (self.currentSection == #self.DUNGEONS[self.currentDungeonID])
                end
                if projShare >= 100 then
                    suffix = L["FINISHED"]
                elseif isLastSection then
                    suffix = L["DONE"]
                else
                    suffix = L["DONE"]
                end
                local col = self.db.profile.color.finished or { r = 0, g = 1, b = 0 }
                local hex = string.format("%02x%02x%02x", math.floor((col.r or 1)*255), math.floor((col.g or 1)*255), math.floor((col.b or 1)*255))
                base = formatProjectedValue(base, projC, hex, suffix)
            else
                base = formatProjectedValue(base, projC, hexFinished, tostring(projC))
            end
        end
    end

    -- Optionally insert the section required value right after the base required and before Current percent
    if (isNumericPercent or isNumericCount) and cfg.showSectionRequiredText and fmtData then
        local sLabel = colorizePrefix(cfg.sectionRequiredLabel or L["REQUIRED_DEFAULT"], hexPrefix)
        local sValue
        if cfg.formatMode == "count" and tonumber(fmtData.totalCount or 0) > 0 then
            if fmtData.sectionRequiredCount then sValue = tostring(tonumber(fmtData.sectionRequiredCount) or 0) end
        else
            if fmtData.sectionRequiredPercent then sValue = string.format("%.2f%%", tonumber(fmtData.sectionRequiredPercent) or 0) end
        end
        if sValue then
            -- Put at the beginning so it appears before Current percent in the extras list
            table.insert(extras, 1, string.format("%s %s", sLabel, sValue))
        end
    end

    if #extras == 0 then return base end

    if base == nil or base == "" then
        if cfg.multiLine then
            return table.concat(extras, "\n")
        else
            local sep = tostring(cfg.singleLineSeparator or " | ")
            return table.concat(extras, sep)
        end
    end

    if cfg.multiLine then
        return base .. "\n" .. table.concat(extras, "\n")
    else
        local sep = tostring(cfg.singleLineSeparator or " | ")
        return base .. sep .. table.concat(extras, sep)
    end
end
