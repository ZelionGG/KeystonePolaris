local AddOnName, KeystonePolaris = ...
local L = LibStub("AceLocale-3.0"):GetLocale(AddOnName)
local _G = _G
local GetCVarBool = _G.GetCVarBool

-- Inform secure button / macro

function KeystonePolaris:UpdateInformButtonFrameLayer()
    local btn = self.informSecureButton
    if not btn then return end

    local strata = "MEDIUM"
    local frameLevel = 1
    if self.displayFrame then
        strata = self.displayFrame:GetFrameStrata() or strata
        frameLevel = (self.displayFrame:GetFrameLevel() or 0) + 1
    end

    btn:SetFrameStrata(strata)
    btn:SetFrameLevel(frameLevel)
end

-- Secure action button (macro) for manual sends in lockdown contexts
function KeystonePolaris:EnsureInformSecureButton(macroText)
    if not self.informSecureButton then
        local btn = CreateFrame("Button", "KeystonePolarisSecureInformButton", UIParent, "SecureActionButtonTemplate, UIPanelButtonTemplate, BackdropTemplate")
        btn:SetSize(160, 28)
        btn:SetText(L["INFORM_GROUP"])
        btn:EnableMouse(true)
        local useKeyDown = GetCVarBool and GetCVarBool("ActionButtonUseKeyDown")
        if useKeyDown then
            btn:RegisterForClicks("LeftButtonDown")
        else
            btn:RegisterForClicks("LeftButtonUp")
        end

        -- Remove default UIPanelButton textures (avoid red/purple background)
        if btn.Left then btn.Left:SetTexture(""); btn.Left:Hide() end
        if btn.Right then btn.Right:SetTexture(""); btn.Right:Hide() end
        if btn.Middle then btn.Middle:SetTexture(""); btn.Middle:Hide() end
        if btn.DisabledLeft then btn.DisabledLeft:SetTexture(""); btn.DisabledLeft:Hide() end
        if btn.DisabledRight then btn.DisabledRight:SetTexture(""); btn.DisabledRight:Hide() end
        if btn.DisabledMiddle then btn.DisabledMiddle:SetTexture(""); btn.DisabledMiddle:Hide() end

        -- Style similar to Test Mode overlay (black bg, gold border/text)
        local backdrop = {
            bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
            edgeFile = "Interface\\ChatFrame\\ChatFrameBackground",
            tile = true, tileSize = 16, edgeSize = 1,
        }
        if btn.SetBackdrop then
            btn:SetBackdrop(backdrop)
            btn:SetBackdropColor(0, 0, 0, 0.7)
            btn:SetBackdropBorderColor(1, 0.82, 0, 1)
        elseif BackdropTemplateMixin and BackdropTemplateMixin.SetBackdrop then
            BackdropTemplateMixin.SetBackdrop(btn, backdrop)
            btn:SetBackdropColor(0, 0, 0, 0.7)
            btn:SetBackdropBorderColor(1, 0.82, 0, 1)
        end
        if btn.GetFontString then
            local fs = btn:GetFontString()
            if fs then
                fs:SetTextColor(1, 0.82, 0, 1)
                fs:ClearAllPoints()
                fs:SetPoint("CENTER", btn, "CENTER", 0, 0)
            end
        end

        -- Cooldown bar overlay
        local bar = CreateFrame("StatusBar", nil, btn, "BackdropTemplate")
        bar:ClearAllPoints()
        bar:SetPoint("TOPLEFT", btn, "TOPLEFT", 1, -1)
        bar:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -1, 1)
        bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
        bar:SetStatusBarColor(0.45, 0.45, 0.45, 0.75)
        bar:Hide()
        btn.cooldownBar = bar

        btn.cooldownDuration = 20
        btn.cooldownEndTime = nil
        btn.fadeDuration = 0.15

        local function startCooldown(button)
            button.cooldownEndTime = GetTime() + (button.cooldownDuration or 20)
            if KeystonePolaris.SetInformButtonMouseEnabled then
                KeystonePolaris:SetInformButtonMouseEnabled(false)
            else
                button:EnableMouse(false)
            end
        end

        btn:SetScript("OnUpdate", function(button)
            if not button.cooldownEndTime then return end
            local now = GetTime()
            local remaining = button.cooldownEndTime - now
            if remaining <= 0 then
                button.cooldownEndTime = nil
                button.cooldownBar:Hide()
                button:SetText(L["INFORM_GROUP"])
                if KeystonePolaris.SetInformButtonMouseEnabled then
                    KeystonePolaris:SetInformButtonMouseEnabled(true)
                else
                    button:EnableMouse(true)
                end
                return
            end
            local pct = math.max(0, math.min(1, remaining / (button.cooldownDuration or 20)))
            button.cooldownBar:Show()
            button.cooldownBar:SetMinMaxValues(0,1)
            button.cooldownBar:SetValue(pct)
            button:SetText(string.format("%ds", math.ceil(remaining)))
            if KeystonePolaris.SetInformButtonMouseEnabled then
                KeystonePolaris:SetInformButtonMouseEnabled(false)
            else
                button:EnableMouse(false)
            end
        end)

        btn:SetScript("PostClick", function(button)
            startCooldown(button)
        end)

        btn:Hide()
        self.informSecureButton = btn
        btn:ClearAllPoints()
        if self.displayFrame then
            btn:SetPoint("TOP", self.displayFrame, "BOTTOM", 0, -6)
        else
            btn:SetPoint("CENTER")
        end
        if self.UpdateInformButtonFrameLayer then
            self:UpdateInformButtonFrameLayer()
        end
    end

    local btn = self.informSecureButton

    if macroText then
        if InCombatLockdown() then
            self._pendingInformMacro = macroText
            if self.EnsureInformWatcher then
                self:EnsureInformWatcher()
            end
        else
            btn:SetAttribute("type", "macro")
            btn:SetAttribute("macrotext", macroText)
        end
    end
end

function KeystonePolaris:HideInformButton()
    local btn = self.informSecureButton
    if not btn then return end

    btn.cooldownEndTime = nil
    if btn.cooldownBar then btn.cooldownBar:Hide() end
    if btn.SetText then btn:SetText(L["INFORM_GROUP"]) end

    if InCombatLockdown() then
        self._pendingInformVisibility = false
        self._pendingInformMouseEnabled = true
        if self.ApplyInformCombatVisualState then
            self:ApplyInformCombatVisualState(false)
        end
        if self.EnsureInformWatcher then
            self:EnsureInformWatcher()
        end
        return
    end

    if self.SetInformButtonMouseEnabled then
        self:SetInformButtonMouseEnabled(true)
    else
        btn:EnableMouse(true)
    end
    btn:Hide()
end

function KeystonePolaris:EnsureInformWatcher()
    if self._informWatcher then return end

    local f = CreateFrame("Frame")
    f:RegisterEvent("PLAYER_REGEN_ENABLED")
    f:SetScript("OnEvent", function()
        if self._pendingInformVisibility ~= nil then
            local desired = self._pendingInformVisibility
            self._pendingInformVisibility = nil
            self:ApplyInformVisibility(desired)
        end

        if self._pendingInformMouseEnabled ~= nil and self.informSecureButton and not InCombatLockdown() then
            self.informSecureButton:EnableMouse(self._pendingInformMouseEnabled)
            self._pendingInformMouseEnabled = nil
        end

        if self._pendingInformMacro and self.informSecureButton and not InCombatLockdown() then
            self.informSecureButton:SetAttribute("type", "macro")
            self.informSecureButton:SetAttribute("macrotext", self._pendingInformMacro)
            self._pendingInformMacro = nil
        end
    end)

    self._informWatcher = f
end

function KeystonePolaris:SetInformButtonMouseEnabled(enabled)
    local btn = self.informSecureButton
    if not btn then return end

    local target = enabled and true or false
    if InCombatLockdown() then
        self._pendingInformMouseEnabled = target
        if self.EnsureInformWatcher then
            self:EnsureInformWatcher()
        end
        return
    end

    btn:EnableMouse(target)
end

-- Apply visibility and reset state for the secure Inform button
function KeystonePolaris:ApplyInformVisibility(shouldShow)
    local btn = self.informSecureButton
    if not btn then return end

    local desired = shouldShow and true or false
    if InCombatLockdown() then
        self._pendingInformVisibility = desired
        if self.ApplyInformCombatVisualState then
            self:ApplyInformCombatVisualState(desired)
        end
        if self.EnsureInformWatcher then
            self:EnsureInformWatcher()
        end
        return
    end

    if desired then
        btn:SetAlpha(1)
        if btn.SetText then btn:SetText(L["INFORM_GROUP"]) end
        if self.SetInformButtonMouseEnabled then
            self:SetInformButtonMouseEnabled(true)
        else
            btn:EnableMouse(true)
        end
        btn:Show()
    else
        btn.cooldownEndTime = nil
        if btn.cooldownBar then btn.cooldownBar:Hide() end
        btn:SetAlpha(1)
        if btn.SetText then btn:SetText(L["INFORM_GROUP"]) end
        if self.SetInformButtonMouseEnabled then
            self:SetInformButtonMouseEnabled(true)
        else
            btn:EnableMouse(true)
        end
        btn:Hide()
    end
end

function KeystonePolaris:ApplyInformCombatVisualState(shouldShow)
    local btn = self.informSecureButton
    if not btn then return end

    if shouldShow then
        btn:SetAlpha(1)
        if btn.SetText then btn:SetText(L["INFORM_GROUP"]) end
    else
        btn:SetAlpha(0.1)
        if btn.SetText then btn:SetText(L["INFORM_GROUP"]) end
    end
end

function KeystonePolaris:PrepareInformMacro(message)
    local currentDungeonID = C_ChallengeMode.GetActiveChallengeMapID()
    if not currentDungeonID or not (self.DUNGEONS and self.DUNGEONS[currentDungeonID]) then
        if self.HideInformButton then self:HideInformButton() end
        return
    end

    local resolvedMessage = message
    if not resolvedMessage or resolvedMessage == "" then
        local fakePercent = "12.34%"
        if self.BuildInformMessage then
            resolvedMessage = self:BuildInformMessage(12.34)
        else
            resolvedMessage = "[Keystone Polaris]: " .. L["WE_STILL_NEED"] .. " " .. fakePercent
        end
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

    local macroText = string.format("/%s %s", slash, tostring(resolvedMessage or ""))
    self:EnsureInformSecureButton(macroText)
    local btn = self.informSecureButton
    btn:SetAlpha(1)
    btn.cooldownEndTime = nil
    if btn.cooldownBar then btn.cooldownBar:Hide() end
    btn:SetText(L["INFORM_GROUP"])
    if self.SetInformButtonMouseEnabled then
        self:SetInformButtonMouseEnabled(true)
    else
        btn:EnableMouse(true) -- IMPORTANT
    end
    self:ApplyInformVisibility(false)
end

function KeystonePolaris:InformGroup(percentage)
    if not self.db.profile.general.informGroup then return end

    local percentageStr = string.format("%.2f%%", percentage)
    -- Don't send message if percentage is 0
    if percentageStr == "0.00%" then return end
    local message
    if self.BuildInformMessage then
        message = self:BuildInformMessage(percentage)
    else
        message = "[Keystone Polaris]: " .. L["WE_STILL_NEED"] .. " " .. percentageStr
    end
    -- Prepare secure macro button for manual send
    self:PrepareInformMacro(message)
end
