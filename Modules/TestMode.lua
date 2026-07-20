local AddOnName, KeystonePolaris = ...
local L = LibStub("AceLocale-3.0"):GetLocale(AddOnName)

-- ---------------------------------------------------------------------------
-- Test Mode Logic
-- ---------------------------------------------------------------------------

-- Simulated combat context for Test Mode
function KeystonePolaris:IsCombatContext()
    if self._testMode then
        if self._testCombatContext == nil then
            return true -- default to "in combat" when starting test mode
        end
        return self._testCombatContext and true or false
    end
    return UnitAffectingCombat and UnitAffectingCombat("player")
end

-- Start ticker to alternate simulated combat context
function KeystonePolaris:StartTestModeTicker()
    -- Cancel existing ticker if any
    if self._testTicker then
        self._testTicker:Cancel()
        self._testTicker = nil
    end
    -- Begin with out-of-combat to show transitions clearly
    self._testCombatContext = false
    self._testScenario = 1
    local period = 3 -- seconds; can be made configurable later
    self._testTicker = C_Timer.NewTicker(period, function()
        -- Alternate combat context
        self._testCombatContext = not self._testCombatContext
        -- Rotate scenarios (1..7)
        self._testScenario = ((self._testScenario or 1) % 7) + 1
        if self.UpdatePercentageText then self:UpdatePercentageText() end
    end)
end

function KeystonePolaris:StopTestModeTicker()
    if self._testTicker then
        self._testTicker:Cancel()
        self._testTicker = nil
    end
    self._testCombatContext = nil
    self._testScenario = nil
end

-- Lightweight overlay to indicate Test Mode is active
function KeystonePolaris:ShowTestOverlay()
    if not self.testModeOverlay then
        local f = CreateFrame("Frame", "KPL_TestModeOverlay", UIParent, "BackdropTemplate")
        f:SetFrameStrata("FULLSCREEN_DIALOG")
        f:SetSize(800, 56)
        -- Anchor above the main display frame
        if self.displayFrame then
            f:SetPoint("BOTTOM", self.displayFrame, "TOP", 0, 8)
        else
            f:SetPoint("TOP", UIParent, "TOP", 0, -20)
        end
        -- Simple border style
        f:SetBackdrop({ bgFile = "Interface\\ChatFrame\\ChatFrameBackground", edgeFile = "Interface\\ChatFrame\\ChatFrameBackground", tile = true, tileSize = 16, edgeSize = 1 })
        f:SetBackdropColor(0, 0, 0, 0.35)
        f:SetBackdropBorderColor(1, 0.82, 0, 1)
        -- Ensure 1px border on all sides (some UI scales can hide the right edge with edgeFile-only)
        if not f.border then f.border = {} end
        local br, bgc, bb, ba = 1, 0.82, 0, 1
        if not f.border.top then f.border.top = f:CreateTexture(nil, "BORDER") end
        f.border.top:SetColorTexture(br, bgc, bb, ba)
        f.border.top:ClearAllPoints()
        f.border.top:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
        f.border.top:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)
        f.border.top:SetHeight(1)

        if not f.border.bottom then f.border.bottom = f:CreateTexture(nil, "BORDER") end
        f.border.bottom:SetColorTexture(br, bgc, bb, ba)
        f.border.bottom:ClearAllPoints()
        f.border.bottom:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 0)
        f.border.bottom:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)
        f.border.bottom:SetHeight(1)

        if not f.border.left then f.border.left = f:CreateTexture(nil, "BORDER") end
        f.border.left:SetColorTexture(br, bgc, bb, ba)
        f.border.left:ClearAllPoints()
        f.border.left:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
        f.border.left:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 0)
        f.border.left:SetWidth(1)

        if not f.border.right then f.border.right = f:CreateTexture(nil, "BORDER") end
        f.border.right:SetColorTexture(br, bgc, bb, ba)
        f.border.right:ClearAllPoints()
        f.border.right:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)
        f.border.right:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)
        f.border.right:SetWidth(1)

        local title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
        -- Layout paddings
        f._padLeft, f._padRight, f._padTop, f._padBottom = 16, 16, 12, 14
        local padTop = f._padTop
        local padLeft, padRight = f._padLeft, f._padRight
        local gap = 4

        title:SetPoint("TOP", f, "TOP", 0, -padTop)
        title:SetText((self.L and self.L["TEST_MODE_OVERLAY"]) or (L and L["TEST_MODE_OVERLAY"]))
        title:SetTextColor(1, 0.82, 0, 1)
        local tf, ts, tflags = title:GetFont(); if tf then title:SetFont(tf, (ts or 14) + 4, tflags) end

        local hint = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        hint:SetPoint("TOP", title, "BOTTOM", 0, -gap)
        hint:SetText((self.L and self.L["TEST_MODE_OVERLAY_HINT"]) or (L and L["TEST_MODE_OVERLAY_HINT"]))
        -- Apply configured font (LSM) for title and hint
        local fontPath = self.LSM and self.LSM:Fetch('font', self.db and self.db.profile and self.db.profile.text and self.db.profile.text.font) or nil
        local baseSize = (self.db and self.db.profile and self.db.profile.general and self.db.profile.general.fontSize) or 12
        if fontPath then
            local b = baseSize or 12
            title:SetFont(fontPath, b + 2, self:GetFontFlags())
            hint:SetFont(fontPath, math.max(8, b - 2), self:GetFontFlags())
        else
            local hf, hs, hflags = hint:GetFont(); if hf then hint:SetFont(hf, (hs or 12) + 3, hflags) end
        end

        -- Store refs for later width recalculation
        f.title = title
        f.hint = hint

        -- Auto-size overlay width/height based on hint + title with paddings
        local hintW = hint:GetStringWidth() or 0
        local titleW = title:GetStringWidth() or 0
        local contentW = math.max(hintW, titleW)
        local width = math.max(240, math.floor(contentW + padLeft + padRight))
        local height = (title:GetStringHeight() or 0) + gap + (hint:GetStringHeight() or 0) + f._padTop + f._padBottom
        f:SetSize(width, math.max(40, math.floor(height)))

        -- Right-click to cancel Test Mode and reopen settings
        f:EnableMouse(true)
        f:SetScript("OnMouseUp", function(_, btn)
            if btn == "RightButton" then
                self._testMode = false
                if self.HideTestOverlay then self:HideTestOverlay() end
                if self.StopTestModeTicker then self:StopTestModeTicker() end
                if self.UpdatePercentageText then self:UpdatePercentageText() end
                if self.Refresh then self:Refresh() end
                if self.ToggleConfig then
                    self:ToggleConfig()
                elseif Settings and Settings.OpenToCategory then
                    Settings.OpenToCategory(self.optionsCategoryId or "Keystone Polaris")
                end
            end
        end)

        self.testModeOverlay = f
    end
    -- Create and show a dedicated full-screen dim overlay for Test Mode
    if not self.testDimOverlay then
        local dim = CreateFrame("Frame", "KPL_TestDimOverlay", UIParent, "BackdropTemplate")
        dim:SetFrameStrata("FULLSCREEN_DIALOG")
        dim:SetAllPoints(UIParent)
        dim:SetBackdrop({ bgFile = "Interface\\ChatFrame\\ChatFrameBackground", tile = true, tileSize = 16 })
        dim:SetBackdropColor(0, 0, 0, 0.7)
        dim:EnableMouse(false)
        self.testDimOverlay = dim
    end
    self.testDimOverlay:Show()

    -- Ensure display text is drawn above the dim overlay
    if self.displayFrame then
        self._prevDisplayStrata = self.displayFrame:GetFrameStrata()
        self.displayFrame:SetFrameStrata("TOOLTIP")
    end
    self.testModeOverlay:Show()
end

function KeystonePolaris:HideTestOverlay()
    if self.testModeOverlay then
        self.testModeOverlay:Hide()
    end
    if self.testDimOverlay then self.testDimOverlay:Hide() end
    -- Restore original strata for the display
    if self.displayFrame and self._prevDisplayStrata then
        self.displayFrame:SetFrameStrata(self._prevDisplayStrata)
        self._prevDisplayStrata = nil
    end
end

-- Render a configuration preview while Test Mode is enabled
function KeystonePolaris:RenderTestText()
    if not (self.displayFrame and self.displayFrame.text and self.db and self.db.profile) then return end
    local cfg = self.db.profile.general and self.db.profile.general.mainDisplay or nil
    local formatMode = (cfg and cfg.formatMode) or "percent"
    local scenario = self._testScenario or 1

    -- Shared baseline
    local totalCount = 220
    local textColor = self.db.profile.color.inProgress

    if scenario == 7 then
        -- Scenario 7: Dungeon finished
        self.displayFrame.text:SetText(L["DUNGEON_DONE"] or "Dungeon finished")
        textColor = self.db.profile.color.finished
    else
        local currentPercent, neededPercent, pullPercent, isBossKilled
        if scenario == 1 then
            -- 1) Nominal out of combat (white)
            currentPercent = 45.0
            neededPercent = 50.0
            pullPercent = 0.0
            isBossKilled = false
            textColor = self.db.profile.color.inProgress
        elseif scenario == 2 then
            -- 2) Nominal in combat (white), small pull
            currentPercent = 45.0
            neededPercent = 50.0
            pullPercent = 3.0
            isBossKilled = false
            textColor = self.db.profile.color.inProgress
        elseif scenario == 3 then
            -- 3) Nominal: projected finishes the section (white)
            currentPercent = 62.0
            neededPercent = 68.0
            pullPercent = 8.0
            isBossKilled = false
            textColor = self.db.profile.color.inProgress
        elseif scenario == 4 then
            -- 4) Nominal: section already done (green)
            currentPercent = 74.0
            neededPercent = 70.0
            pullPercent = 0.0
            isBossKilled = false
            textColor = self.db.profile.color.finished
        elseif scenario == 5 then
            -- 5) Late: projected finishes the section (red Missing)
            currentPercent = 62.0
            neededPercent = 68.0
            pullPercent = 8.0
            isBossKilled = true -- simulate boss done context for missing state
            textColor = self.db.profile.color.missing
        elseif scenario == 6 then
            -- 6) Nominal with projected Dungeon finished (white, IC)
            currentPercent = 98.0
            neededPercent = 100.0
            pullPercent = 3.0
            isBossKilled = false
            textColor = self.db.profile.color.inProgress
        end

        local remainingPercent = math.max(0, neededPercent - currentPercent)
        local currentCount = math.floor((currentPercent / 100) * totalCount + 0.5)
        local pullCount = math.floor((pullPercent / 100) * totalCount + 0.5)
        local sectionRequiredCount = math.ceil((neededPercent / 100) * totalCount)
        local remainingCount = math.max(0, sectionRequiredCount - currentCount)

        local fmtData = {
            currentCount = currentCount,
            totalCount = totalCount,
            pullCount = pullCount,
            remainingCount = remainingCount,
            sectionRequiredPercent = neededPercent,
            sectionRequiredCount = sectionRequiredCount,
        }

        local base
        if scenario == 4 then
            base = L["DONE"] or "Section percentage done"
        else
            if formatMode == "count" then
                base = tostring(remainingCount)
            else
                base = string.format("%.2f%%", remainingPercent)
            end
        end

        -- Force combat context per scenario when needed for projected display
        local originalCtx = self._testCombatContext
        -- Force combat per scenario for projected parts visibility
        if scenario == 1 or scenario == 4 or scenario == 7 then
            self._testCombatContext = false
        elseif scenario == 2 or scenario == 3 or scenario == 5 or scenario == 6 then
            self._testCombatContext = true
        end
        local text = self:FormatMainDisplayText(base, currentPercent, pullPercent, remainingPercent, fmtData, isBossKilled, false)
        self._testCombatContext = originalCtx
        self.displayFrame.text:SetText(text)
    end

    -- Apply chosen color and layout
    self.displayFrame.text:SetTextColor(textColor.r, textColor.g, textColor.b, textColor.a)
end

-- Disable Test Mode programmatically with a reason and inform the player
function KeystonePolaris:DisableTestMode(reason)
    if not self._testMode then return end
    if self._positioningMode then
        self:ExitPositioningMode(true)
    end
    self._testMode = false
    if self.HideTestOverlay then self:HideTestOverlay() end
    if self.StopTestModeTicker then self:StopTestModeTicker() end
    if self.UpdatePercentageText then self:UpdatePercentageText() end
    if self.Refresh then self:Refresh() end
    -- Localize reason if provided
    local suffix = ""
    if type(reason) == "string" and reason ~= "" then
        local r = reason
        local reasonKey
        if r == "entered combat" or r == "entered_combat" then
            reasonKey = "TEST_MODE_REASON_ENTERED_COMBAT"
        elseif r == "started dungeon" or r == "started_dungeon" then
            reasonKey = "TEST_MODE_REASON_STARTED_DUNGEON"
        elseif r == "changed zone" or r == "changed_zone" then
            reasonKey = "TEST_MODE_REASON_CHANGED_ZONE"
        end
        local RL = (self.L or L)
        local localized = (reasonKey and RL and RL[reasonKey]) and RL[reasonKey] or r
        suffix = " (" .. localized .. ")"
    end
    local loc = (self.L and self.L["TEST_MODE_DISABLED"]) or (L and L["TEST_MODE_DISABLED"]) or "Test Mode disabled automatically%s"
    local prefix = (self.GetChatPrefix and self:GetChatPrefix()) or "Keystone Polaris"
    local msg = prefix .. ": " .. string.format(loc, suffix)
    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        DEFAULT_CHAT_FRAME:AddMessage(msg)
    else
        print(msg)
    end
end
