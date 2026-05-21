local AddOnName, KeystonePolaris = ...
local L = LibStub("AceLocale-3.0"):GetLocale(AddOnName)
local _G = _G
local GetCVarBool = _G.GetCVarBool

-- ---------------------------------------------------------------------------
-- Display Initialization
-- ---------------------------------------------------------------------------

KeystonePolaris.colorCache = {}

local function formatProjectedValue(base, value, hexColor, suffix)
    local displayed = suffix or tostring(value)
    return string.format("%s (|cff%s%s|r)", base, hexColor, displayed)
end

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
        resolvedMessage = "[Keystone Polaris]: " .. L["WE_STILL_NEED"] .. " " .. fakePercent
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

    local safeMessage = tostring(resolvedMessage or ""):gsub("%%", "%%%%")
    local macroText = string.format("/%s %s", slash, safeMessage)
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


function KeystonePolaris:UpdateColorCache()
    if not self.db or not self.db.profile then return end

    local function toHex(color)
        return string.format("%02x%02x%02x",
            math.floor((color.r or 1) * 255),
            math.floor((color.g or 1) * 255),
            math.floor((color.b or 1) * 255)
        )
    end

    local colors = self.db.profile.color
    if colors then
        self.colorCache.prefix = toHex(colors.prefix or {r=1, g=0.7960784, b=0.2})
        self.colorCache.finished = toHex(colors.finished or {r=0, g=1, b=0})
        self.colorCache.inProgress = toHex(colors.inProgress or {r=1, g=1, b=1})
        self.colorCache.missing = toHex(colors.missing or {r=1, g=0, b=0})
    end
end

function KeystonePolaris:InitializeDisplay()
    self:UpdateColorCache()
    self:CreateDisplayFrame()
    self:CreatePositioningToolbar()
end

-- ---------------------------------------------------------------------------
-- Positioning Mode
-- ---------------------------------------------------------------------------

function KeystonePolaris:CreatePositioningToolbar()
    local toolbar = CreateFrame("Frame", "KPL_PositioningToolbar", UIParent, "BasicFrameTemplateWithInset")
    toolbar:SetSize(240, 190)
    toolbar:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    toolbar:SetFrameStrata("TOOLTIP")
    toolbar.TitleText:SetText(self:GetGradientAddonName())

    toolbar:EnableMouse(true)
    toolbar:SetMovable(true)
    toolbar:SetClampedToScreen(true)
    toolbar:RegisterForDrag("LeftButton")
    toolbar:SetScript("OnDragStart", function() toolbar:StartMoving() end)
    toolbar:SetScript("OnDragStop", function() toolbar:StopMovingOrSizing() end)

    toolbar.CloseButton:SetScript("OnClick", function() self:ExitPositioningMode(false) end)

    -- Dim Background checkbox
    local dimCheck = CreateFrame("CheckButton", "KPL_DimCheck", toolbar, "UICheckButtonTemplate")
    dimCheck:SetPoint("TOPLEFT", toolbar, "TOPLEFT", 22, -32)
    local dimText = dimCheck.text or _G["KPL_DimCheckText"]
    if dimText then dimText:SetText(L["DIM_BACKGROUND"]) end
    dimCheck:SetScript("OnClick", function(cb)
        self.db.profile.general.positioningDimBackground = cb:GetChecked() and true or false
        self:UpdatePositioningDim()
    end)
    toolbar.dimCheck = dimCheck

    -- Show Grid checkbox
    local gridCheck = CreateFrame("CheckButton", "KPL_GridCheck", toolbar, "UICheckButtonTemplate")
    gridCheck:SetPoint("TOPLEFT", dimCheck, "BOTTOMLEFT", 0, -2)
    local gridText = gridCheck.text or _G["KPL_GridCheckText"]
    if gridText then gridText:SetText(L["SHOW_GRID"]) end
    gridCheck:SetScript("OnClick", function(cb)
        self.db.profile.general.positioningShowGrid = cb:GetChecked() and true or false
        self:UpdatePositioningGrid()
        self:UpdateGridSliderState()
    end)
    toolbar.gridCheck = gridCheck

    -- Grid Spacing slider
    local slider = CreateFrame("Slider", "KPL_GridSpacing", toolbar, "OptionsSliderTemplate")
    slider:SetPoint("LEFT", toolbar, "LEFT", 22, 0)
    slider:SetPoint("RIGHT", toolbar, "RIGHT", -22, 0)
    slider:SetPoint("TOP", gridCheck, "BOTTOM", 0, -14)
    slider:SetHeight(17)
    slider:SetMinMaxValues(20, 200)
    slider:SetValueStep(5)
    slider:SetObeyStepOnDrag(true)

    local sliderName = slider:GetName()
    _G[sliderName .. "Low"]:SetText("20")
    _G[sliderName .. "High"]:SetText("200")
    _G[sliderName .. "Text"]:SetText(L["GRID_SPACING"] .. ": 60")

    slider:SetValue(self.db.profile.general.positioningGridSpacing or 60)
    slider:SetScript("OnValueChanged", function(_, value)
        value = math.floor(value + 0.5)
        self.db.profile.general.positioningGridSpacing = value
        _G[sliderName .. "Text"]:SetText(L["GRID_SPACING"] .. ": " .. value)
        if self.db.profile.general.positioningShowGrid and self._positioningMode then
            self:RefreshGridLines()
        end
    end)
    toolbar.gridSlider = slider

    -- Button row (bottom)
    local validateBtn = CreateFrame("Button", nil, toolbar, "UIPanelButtonTemplate")
    validateBtn:SetSize(96, 28)
    validateBtn:SetPoint("BOTTOMRIGHT", toolbar, "BOTTOM", -2, 10)
    validateBtn:SetText(L["VALIDATE"])
    validateBtn:SetScript("OnClick", function() self:ExitPositioningMode(true) end)

    local cancelBtn = CreateFrame("Button", nil, toolbar, "UIPanelButtonTemplate")
    cancelBtn:SetSize(96, 28)
    cancelBtn:SetPoint("BOTTOMLEFT", toolbar, "BOTTOM", 2, 10)
    cancelBtn:SetText(L["CANCEL"])
    cancelBtn:SetScript("OnClick", function() self:ExitPositioningMode(false) end)

    toolbar:EnableKeyboard(true)
    toolbar:SetScript("OnKeyDown", function(f, key)
        if key == "ESCAPE" then
            f:SetPropagateKeyboardInput(false)
            self:ExitPositioningMode(false)
        else
            f:SetPropagateKeyboardInput(true)
        end
    end)

    if ElvUI then
        local E = unpack(ElvUI)
        if E and E.Skins then
            local S = E:GetModule('Skins')
            if S.HandleFrame then
                pcall(S.HandleFrame, S, toolbar)
            end
            if S.HandleCloseButton and toolbar.CloseButton then
                pcall(S.HandleCloseButton, S, toolbar.CloseButton)
            end
            S:HandleButton(validateBtn)
            S:HandleButton(cancelBtn)
            if S.HandleCheckBox then S:HandleCheckBox(dimCheck) end
            if S.HandleCheckBox then S:HandleCheckBox(gridCheck) end
            if S.HandleSliderFrame then S:HandleSliderFrame(slider) end
        end
    end

    local combatFrame = CreateFrame("Frame")
    combatFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
    combatFrame:SetScript("OnEvent", function()
        if self._positioningMode then
            self:ExitPositioningMode(true)
        end
    end)

    toolbar:Hide()
    self.positioningToolbar = toolbar
end

function KeystonePolaris:EnterPositioningMode()
    if not self.displayFrame then return end

    self._savedPosition = {
        position = self.db.profile.general.position,
        xOffset = self.db.profile.general.xOffset,
        yOffset = self.db.profile.general.yOffset,
    }

    self._testMode = true
    self._positioningMode = true
    self:StartTestModeTicker()
    self:UpdatePercentageText()

    self.displayFrame:SetMovable(true)
    self.displayFrame:EnableMouse(true)
    self.displayFrame:RegisterForDrag("LeftButton")
    self.displayFrame:SetScript("OnDragStart", function() self.displayFrame:StartMoving() end)
    self.displayFrame:SetScript("OnDragStop", function()
        self.displayFrame:StopMovingOrSizing()
        local centerX, centerY = self.displayFrame:GetCenter()
        local screenWidth = GetScreenWidth()
        local screenHeight = GetScreenHeight()
        local position = self.db.profile.general.position
        local h = self.displayFrame:GetHeight()

        local xOffset = centerX - screenWidth / 2
        local yOffset
        if position == "TOP" then
            yOffset = centerY + h / 2 - screenHeight
        elseif position == "BOTTOM" then
            yOffset = centerY - h / 2
        else
            yOffset = centerY - screenHeight / 2
        end

        self.db.profile.general.xOffset = xOffset
        self.db.profile.general.yOffset = yOffset
    end)

    self.displayFrame:Show()
    self:ShowPositioningBorder()
    self.displayFrame:SetScript("OnSizeChanged", function() self:RefreshPositioningBorder() end)

    if self.positioningToolbar then
        self.positioningToolbar:ClearAllPoints()
        self.positioningToolbar:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        if self.positioningToolbar.dimCheck then
            self.positioningToolbar.dimCheck:SetChecked(self.db.profile.general.positioningDimBackground)
        end
        if self.positioningToolbar.gridCheck then
            self.positioningToolbar.gridCheck:SetChecked(self.db.profile.general.positioningShowGrid)
        end
        if self.positioningToolbar.gridSlider then
            self.positioningToolbar.gridSlider:SetValue(self.db.profile.general.positioningGridSpacing or 60)
        end
        self:UpdateGridSliderState()
        self.positioningToolbar:Show()
    end

    self:UpdatePositioningDim()
    self:UpdatePositioningGrid()
end

function KeystonePolaris:ExitPositioningMode(save)
    self._testMode = false
    self._positioningMode = false
    self:StopTestModeTicker()

    if self.displayFrame then
        self.displayFrame:SetMovable(false)
        self.displayFrame:EnableMouse(false)
        self.displayFrame:RegisterForDrag()
        self.displayFrame:SetScript("OnDragStart", nil)
        self.displayFrame:SetScript("OnDragStop", nil)
        self.displayFrame:SetScript("OnSizeChanged", nil)
    end

    if not save and self._savedPosition then
        self.db.profile.general.position = self._savedPosition.position
        self.db.profile.general.xOffset = self._savedPosition.xOffset
        self.db.profile.general.yOffset = self._savedPosition.yOffset
    end
    self._savedPosition = nil

    self:HidePositioningBorder()

    if self.testDimOverlay then self.testDimOverlay:Hide() end
    if self.gridOverlay then self.gridOverlay:Hide() end
    if self.displayFrame and self._prevDisplayStrata then
        self.displayFrame:SetFrameStrata(self._prevDisplayStrata)
        self._prevDisplayStrata = nil
    end

    if self.positioningToolbar then self.positioningToolbar:Hide() end

    self:UpdatePercentageText()
    self:Refresh()

    if self.ToggleConfig then
        self:ToggleConfig()
    elseif Settings and Settings.OpenToCategory then
        Settings.OpenToCategory(self.optionsCategoryId or "Keystone Polaris")
    end
end

-- ---------------------------------------------------------------------------
-- Positioning Border (dashed bounding box)
-- ---------------------------------------------------------------------------

function KeystonePolaris:UpdatePositioningBorderAnimation()
    local anchor = self._borderAnchor
    local state = self._borderAnimationState
    if not (self._positioningMode and anchor and state and self._borderTexturePool) then return end

    local w = state.width
    local h = state.height
    local dash = state.dash
    local gap = state.gap
    local thickness = state.thickness
    local r, g, b, a = state.r, state.g, state.b, state.a
    local spacing = dash + gap
    local offset = (GetTime() * state.speed) % spacing
    local poolIndex = 0

    local function GetOrCreateDash()
        poolIndex = poolIndex + 1
        local seg = self._borderTexturePool[poolIndex]
        if not seg then
            seg = anchor:CreateTexture(nil, "OVERLAY")
            self._borderTexturePool[poolIndex] = seg
        end
        seg:ClearAllPoints()
        seg:SetColorTexture(r, g, b, a)
        seg:SetAlpha(a)
        seg:Show()
        return seg
    end

    local function CreateDashes(side, totalLen, startPos)
        local isHorizontal = (side == "TOP" or side == "BOTTOM")
        local pos = startPos - spacing
        while pos < totalLen do
            local visibleStart = math.max(pos, 0)
            local visibleEnd = math.min(pos + dash, totalLen)
            local visibleLength = visibleEnd - visibleStart

            if visibleLength > 0 then
                local seg = GetOrCreateDash()
                if isHorizontal then
                    seg:SetSize(visibleLength, thickness)
                    if side == "TOP" then
                        seg:SetPoint("TOPLEFT", anchor, "TOPLEFT", visibleStart, 0)
                    else
                        seg:SetPoint("BOTTOMLEFT", anchor, "BOTTOMLEFT", visibleStart, 0)
                    end
                else
                    seg:SetSize(thickness, visibleLength)
                    if side == "LEFT" then
                        seg:SetPoint("TOPLEFT", anchor, "TOPLEFT", 0, -visibleStart)
                    else
                        seg:SetPoint("TOPRIGHT", anchor, "TOPRIGHT", 0, -visibleStart)
                    end
                end
            end

            pos = pos + spacing
        end
    end

    CreateDashes("TOP", w, offset)
    CreateDashes("RIGHT", h, offset)
    CreateDashes("BOTTOM", w, spacing - offset)
    CreateDashes("LEFT", h, spacing - offset)

    for i = poolIndex + 1, #self._borderTexturePool do
        self._borderTexturePool[i]:Hide()
    end
end

function KeystonePolaris:ShowPositioningBorder()
    if not self.displayFrame or not self.displayFrame.text then return end

    local text = self.displayFrame.text
    local w = text:GetStringWidth() or 0
    local h = text:GetStringHeight() or 0
    if w == 0 or h == 0 then return end

    local pad = 4
    w = w + pad * 2
    h = h + pad * 2

    if not self._borderAnchor then
        self._borderAnchor = CreateFrame("Frame", nil, self.displayFrame)
    end
    local anchor = self._borderAnchor
    anchor:ClearAllPoints()

    local cfg = self.db.profile.general.mainDisplay
    local align = (cfg and cfg.textAlign) or "CENTER"
    local multi = cfg and cfg.multiLine

    if multi and align == "LEFT" then
        anchor:SetPoint("TOPLEFT", text, "TOPLEFT", -pad, pad)
    elseif multi and align == "RIGHT" then
        anchor:SetPoint("TOPRIGHT", text, "TOPRIGHT", pad, pad)
    else
        anchor:SetPoint("CENTER", text, "CENTER", 0, 0)
    end
    anchor:SetSize(w, h)
    anchor:Show()

    self._borderTexturePool = self._borderTexturePool or {}
    self._borderAnimationState = {
        width = w,
        height = h,
        dash = 5,
        gap = 4,
        thickness = 2,
        speed = 25,
        r = 1,
        g = 1,
        b = 1,
        a = 0.65,
    }

    anchor:SetScript("OnUpdate", function()
        self:UpdatePositioningBorderAnimation()
    end)
    self:UpdatePositioningBorderAnimation()
end

function KeystonePolaris:HidePositioningBorder()
    if self._borderTexturePool then
        for _, seg in ipairs(self._borderTexturePool) do
            seg:Hide()
        end
    end
    if self._borderAnchor then
        self._borderAnchor:SetScript("OnUpdate", nil)
        self._borderAnchor:Hide()
    end
    self._borderAnimationState = nil
end

function KeystonePolaris:RefreshPositioningBorder()
    if self._positioningMode then
        self:ShowPositioningBorder()
    end
end

-- ---------------------------------------------------------------------------
-- Positioning Overlays (dim background + alignment grid)
-- ---------------------------------------------------------------------------

function KeystonePolaris:UpdatePositioningDim()
    if self.db.profile.general.positioningDimBackground and self._positioningMode then
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
        if self.displayFrame then
            self._prevDisplayStrata = self._prevDisplayStrata or self.displayFrame:GetFrameStrata()
            self.displayFrame:SetFrameStrata("TOOLTIP")
        end
    else
        if self.testDimOverlay then self.testDimOverlay:Hide() end
        if not (self.db.profile.general.positioningShowGrid and self._positioningMode) then
            if self.displayFrame and self._prevDisplayStrata then
                self.displayFrame:SetFrameStrata(self._prevDisplayStrata)
                self._prevDisplayStrata = nil
            end
        end
    end
end

function KeystonePolaris:EnsureGridOverlay()
    if self.gridOverlay then return self.gridOverlay end
    local f = CreateFrame("Frame", "KPL_GridOverlay", UIParent)
    f:SetFrameStrata("FULLSCREEN_DIALOG")
    f:SetAllPoints(UIParent)
    f:EnableMouse(false)
    f:Hide()
    self.gridOverlay = f
    self._gridLinePool = {}
    return f
end

function KeystonePolaris:RefreshGridLines()
    local overlay = self:EnsureGridOverlay()
    local spacing = self.db.profile.general.positioningGridSpacing or 60
    local sw, sh = GetScreenWidth(), GetScreenHeight()
    local r, g, b, a = 1, 1, 1, 0.15
    local thickness = 1

    self._gridLinePool = self._gridLinePool or {}
    local poolIdx = 0

    local function GetOrCreateLine()
        poolIdx = poolIdx + 1
        local tex = self._gridLinePool[poolIdx]
        if not tex then
            tex = overlay:CreateTexture(nil, "ARTWORK")
            self._gridLinePool[poolIdx] = tex
        end
        tex:ClearAllPoints()
        tex:SetColorTexture(r, g, b, a)
        tex:Show()
        return tex
    end

    local cx = sw / 2
    for x = cx, sw, spacing do
        local line = GetOrCreateLine()
        line:SetSize(thickness, sh)
        line:SetPoint("TOP", overlay, "TOPLEFT", x, 0)
        if x ~= cx then
            local mirror = GetOrCreateLine()
            mirror:SetSize(thickness, sh)
            mirror:SetPoint("TOP", overlay, "TOPLEFT", sw - x, 0)
        end
    end

    local cy = sh / 2
    for y = cy, sh, spacing do
        local line = GetOrCreateLine()
        line:SetSize(sw, thickness)
        line:SetPoint("LEFT", overlay, "BOTTOMLEFT", 0, y)
        if y ~= cy then
            local mirror = GetOrCreateLine()
            mirror:SetSize(sw, thickness)
            mirror:SetPoint("LEFT", overlay, "BOTTOMLEFT", 0, sh - y)
        end
    end

    for i = poolIdx + 1, #self._gridLinePool do
        self._gridLinePool[i]:Hide()
    end
end

function KeystonePolaris:UpdatePositioningGrid()
    if self.db.profile.general.positioningShowGrid and self._positioningMode then
        self:EnsureGridOverlay()
        self:RefreshGridLines()
        self.gridOverlay:Show()
        -- Ensure grid renders above dim overlay but below display/toolbar
        if self.testDimOverlay and self.testDimOverlay:IsShown() then
            self.gridOverlay:SetFrameLevel(self.testDimOverlay:GetFrameLevel() + 1)
        end
        -- Ensure display frame is above grid
        if self.displayFrame then
            self._prevDisplayStrata = self._prevDisplayStrata or self.displayFrame:GetFrameStrata()
            self.displayFrame:SetFrameStrata("TOOLTIP")
        end
    else
        if self.gridOverlay then self.gridOverlay:Hide() end
    end
end

function KeystonePolaris:UpdateGridSliderState()
    if not self.positioningToolbar or not self.positioningToolbar.gridSlider then return end
    local slider = self.positioningToolbar.gridSlider
    if self.db.profile.general.positioningShowGrid then
        slider:Enable()
        slider:SetAlpha(1.0)
    else
        slider:Disable()
        slider:SetAlpha(0.5)
    end
end

-- ---------------------------------------------------------------------------
-- Display Frame
-- ---------------------------------------------------------------------------

-- Create or recreate the main display frame
function KeystonePolaris:CreateDisplayFrame()
    if not self.displayFrame then
        self.displayFrame = CreateFrame("Frame", "KeystonePolarisDisplay", UIParent)
        self.displayFrame:SetSize(200, 30)

        -- Create percentage text
        self.displayFrame.text = self.displayFrame:CreateFontString(nil, "OVERLAY")
        self.displayFrame.text:SetFont(self.LSM:Fetch('font', self.db.profile.text.font), self.db.profile.general.fontSize, "OUTLINE")
        self.displayFrame.text:SetPoint("CENTER")
        self.displayFrame.text:SetText("0.0%") -- Set initial text

        -- Set position from saved variables
        self.displayFrame:ClearAllPoints()
        self.displayFrame:SetPoint(
            self.db.profile.general.position,
            UIParent,
            self.db.profile.general.position,
            self.db.profile.general.xOffset,
            self.db.profile.general.yOffset
        )
    end

    -- Ensure text is visible and settings are applied
    self:ApplyTextLayout()
    self:Refresh()
end

-- Resize the display frame to fit multi-line content when enabled
function KeystonePolaris:AdjustDisplayFrameSize()
    if not self.displayFrame or not self.db or not self.db.profile then return end

    -- Avoid protected calls during combat; defer resize until combat ends
    if InCombatLockdown() then
        self._pendingAdjustAfterCombat = true
        if not self._combatWatcher then
            local f = CreateFrame("Frame")
            f:RegisterEvent("PLAYER_REGEN_ENABLED")
            f:SetScript("OnEvent", function()
                if self._pendingAdjustAfterCombat then
                    self._pendingAdjustAfterCombat = false
                    if self.AdjustDisplayFrameSize then
                        self:AdjustDisplayFrameSize()
                    end
                end
            end)
            self._combatWatcher = f
        end
        return
    end

    local cfg = self.db.profile.general.mainDisplay
    if not (cfg and cfg.multiLine) then
        -- Reset to default height for single-line usage
        self.displayFrame:SetHeight(30)
        return
    end

    local text = self.displayFrame.text:GetText() or ""
    local _, count = text:gsub("\n", "")
    local lines = (count or 0) + 1
    local lineHeight = self.db.profile.general.fontSize or 12
    local padding = 6
    self.displayFrame:SetHeight(lines * lineHeight + padding)
end

-- Apply text layout to support configurable text alignment (LEFT/CENTER/RIGHT)
function KeystonePolaris:ApplyTextLayout()
    if not (self.displayFrame and self.displayFrame.text and self.db and self.db.profile) then return end
    local cfg = self.db.profile.general.mainDisplay
    if not cfg then return end

    local align = cfg.textAlign or "CENTER"
    local multi = cfg.multiLine and true or false
    local maxWidth = tonumber(cfg.maxWidth) or 0

    self.displayFrame.text:ClearAllPoints()

    if multi then
        -- Multi-line: fixed default width (600px); each metric on its own line
        if not InCombatLockdown() then
            self.displayFrame:SetWidth(600)
        end
        self.displayFrame.text:SetPoint("TOPLEFT", self.displayFrame, "TOPLEFT", 0, 0)
        self.displayFrame.text:SetPoint("TOPRIGHT", self.displayFrame, "TOPRIGHT", 0, 0)
        self.displayFrame.text:SetWidth(self.displayFrame:GetWidth())
        self.displayFrame.text:SetWordWrap(true)
        if self.displayFrame.text.SetMaxLines then
            self.displayFrame.text:SetMaxLines(0) -- unlimited lines
        end
        self.displayFrame.text:SetJustifyV("TOP")
    else
        -- Single-line: ALWAYS center-align regardless of option
        self.displayFrame.text:SetPoint("CENTER", self.displayFrame, "CENTER", 0, 0)
        if maxWidth > 0 then
            self.displayFrame.text:SetWidth(maxWidth)
            self.displayFrame.text:SetWordWrap(true)
        else
            -- Autosize to text; no wrapping
            self.displayFrame.text:SetWidth(0)
            self.displayFrame.text:SetWordWrap(false)
        end
        self.displayFrame.text:SetJustifyV("MIDDLE")
        self.displayFrame.text:SetJustifyH("CENTER")
        return
    end

    -- Multi-line justification
    self.displayFrame.text:SetJustifyH(align)
    -- Force reflow so alignment applies immediately
    local _cur = self.displayFrame.text:GetText()
    if _cur ~= nil then
        self.displayFrame.text:SetText(_cur)
    end
end

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

    -- Get data for current section
    local bossID, neededPercent, shouldInfom, haveInformed = self:GetDungeonData()
    if not bossID then return end

    -- Check if criteria info is available for this boss
    if C_ScenarioInfo.GetCriteriaInfo(bossID) then
        -- Check if boss is killed
        local isBossKilled = C_ScenarioInfo.GetCriteriaInfo(bossID).completed

        -- Calculate remaining needed (percent and count)
        local remainingPercent = neededPercent - currentPercentage
        -- Ensure remainingPercent never goes below zero
        if remainingPercent < 0 then
            remainingPercent = 0.00
        end
        -- Round very small values to 0 to avoid showing 0.01%
        if remainingPercent < 0.05 and remainingPercent > 0.00 then
            remainingPercent = 0.00
        end
        local remainingCount = 0
        if totalCount and totalCount > 0 then
            local neededCount = math.ceil((neededPercent / 100) * totalCount)
            remainingCount = math.max(0, neededCount - (currentCount or 0))
        end

        local cfg = self.db.profile.general.mainDisplay
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

        if remainingPercent > 0 and isBossKilled then -- Boss has been killed but percentage is missing
            -- Inform group about missing percentage if enabled
            if shouldInfom and not haveInformed and self.db.profile.general.informGroup then
                self:InformGroup(remainingPercent)
                local order = self.currentSectionOrder
                local idx = order and order[self.currentSection]
                if idx and self.DUNGEONS[self.currentDungeonID] and self.DUNGEONS[self.currentDungeonID][idx] then
                    self.DUNGEONS[self.currentDungeonID][idx][4] = true
                end
            end
            color = self.db.profile.color.missing
            local base = (formatMode == "count") and displayCount or displayPercent
            local allBosses = self:AreAllBossesKilled()
            self.displayFrame.text:SetText(self:FormatMainDisplayText(base, currentPercentage, currentPullPercent, remainingPercent, fmtData, isBossKilled, allBosses))
        elseif remainingPercent > 0 and not isBossKilled then -- Boss has not been killed yet and percentage is missing
            local base = (formatMode == "count") and displayCount or displayPercent
            local allBosses = self:AreAllBossesKilled()
            self.displayFrame.text:SetText(self:FormatMainDisplayText(base, currentPercentage, currentPullPercent, remainingPercent, fmtData, isBossKilled, allBosses))
        elseif remainingPercent <= 0 and not isBossKilled then -- Boss has not been killed yet but percentage is done
            color = self.db.profile.color.finished
            if(currentPercentage >= 100) then
                local allBosses = self:AreAllBossesKilled()
                self.displayFrame.text:SetText(self:FormatMainDisplayText(L["FINISHED"], currentPercentage, currentPullPercent, remainingPercent, fmtData, isBossKilled, allBosses))
            else
                local allBosses = self:AreAllBossesKilled()
                self.displayFrame.text:SetText(self:FormatMainDisplayText(L["DONE"], currentPercentage, currentPullPercent, remainingPercent, fmtData, isBossKilled, allBosses))
            end
            if self.HideInformButton then self:HideInformButton() end
        elseif remainingPercent <= 0 and isBossKilled then -- Boss has been killed and percentage is done
            color = self.db.profile.color.finished
            if(currentPercentage >= 100) then
                local allBosses = self:AreAllBossesKilled()
                self.displayFrame.text:SetText(self:FormatMainDisplayText(L["FINISHED"], currentPercentage, currentPullPercent, remainingPercent, fmtData, isBossKilled, allBosses))
            else
                local allBosses = self:AreAllBossesKilled()
                self.displayFrame.text:SetText(self:FormatMainDisplayText(L["SECTION_DONE"], currentPercentage, currentPullPercent, remainingPercent, fmtData, isBossKilled, allBosses))
            end
            self.currentSection = self.currentSection + 1
            if self.currentSectionOrder and self.currentSection <= #self.currentSectionOrder then -- Next section exists
                C_Timer.After(2, function()
                    local order = self.currentSectionOrder
                    local dungeon = self.DUNGEONS[self.currentDungeonID]
                    local sectionIndex = order and order[self.currentSection]
                    local nextRequired = 0
                    if dungeon and sectionIndex and dungeon[sectionIndex] then
                        nextRequired = dungeon[sectionIndex][2] - currentPercentage
                    end
                        -- Ensure nextRequired never goes below zero
                        if nextRequired < 0 then
                            nextRequired = 0.00
                        end
                    if currentPercentage >= 100 then -- Percentage is already done for the dungeon
                        color = self.db.profile.color.finished
                        local allBosses = self:AreAllBossesKilled()
                        self.displayFrame.text:SetText(self:FormatMainDisplayText(L["FINISHED"], currentPercentage, currentPullPercent, nil, fmtData, isBossKilled, allBosses))
                    else -- Dungeon has not been completed
                        if nextRequired == 0 then
                            color = self.db.profile.color.finished
                            local allBosses = self:AreAllBossesKilled()
                            self.displayFrame.text:SetText(self:FormatMainDisplayText(L["DONE"], currentPercentage, currentPullPercent, nil, fmtData, isBossKilled, allBosses))
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
                            local allBosses = self:AreAllBossesKilled()
                            -- For next section preview, the current section boss context shouldn't mark as killed for the new section; pass false
                            self.displayFrame.text:SetText(self:FormatMainDisplayText(baseNext, currentPercentage, currentPullPercent, nextRequired, fmtNext, false, allBosses))
                        end
                    end
                    self.displayFrame.text:SetTextColor(color.r, color.g, color.b, color.a)
                    -- Adjust frame size if multi-line is enabled
                    self:AdjustDisplayFrameSize()
                    -- Ensure alignment reflects new text layout immediately
                    self:ApplyTextLayout()
                end)
            else
                local allBosses = self:AreAllBossesKilled()
                self.displayFrame.text:SetText(self:FormatMainDisplayText(L["DUNGEON_DONE"], currentPercentage, currentPullPercent, nil, fmtData, isBossKilled, allBosses)) -- Dungeon has been completed
            end
        end
        -- Show the Inform button only when the boss is already dead AND percentage is still missing
        local bossInformEnabled = (shouldInfom ~= false)
        local shouldShowInform = (remainingPercent > 0) and isBossKilled and bossInformEnabled and self.db.profile.general.informGroup
        local informBtn = self.informSecureButton
        if shouldShowInform and not InCombatLockdown() and self.EnsureInformSecureButton then
            local prefix = (self.GetChatPrefix and self:GetChatPrefix(true, true)) or "[Keystone Polaris]"
            local message = prefix .. ": " .. L["WE_STILL_NEED"] .. " " .. string.format("%.2f%%", remainingPercent)
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
            local safeMessage = tostring(message or ""):gsub("%%", "%%%%")
            local macroText = string.format("/%s %s", slash, safeMessage)
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

        -- Apply text color based on status
        self.displayFrame.text:SetTextColor(color.r, color.g, color.b, color.a)
        -- Adjust frame size if multi-line is enabled
        self:AdjustDisplayFrameSize()
        -- Ensure alignment reflects latest text
        self:ApplyTextLayout()
    end
end


function KeystonePolaris:InformGroup(percentage)
    if not self.db.profile.general.informGroup then return end

    local percentageStr = string.format("%.2f%%", percentage)
    -- Don't send message if percentage is 0
    if percentageStr == "0.00%" then return end
    local message = "[Keystone Polaris]: " .. L["WE_STILL_NEED"] .. " " .. percentageStr
    -- Prepare secure macro button for manual send
    self:PrepareInformMacro(message)
end

-- Helper for coloring prefix text
local function colorizePrefix(text, hexColor)
    return string.format("|cff%s%s|r", hexColor or "cccccc", tostring(text or ""))
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
                if self.DUNGEONS and self.currentDungeonID and self.DUNGEONS[self.currentDungeonID] then
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
                if self.DUNGEONS and self.currentDungeonID and self.DUNGEONS[self.currentDungeonID] then
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
            title:SetFont(fontPath, b + 2, "OUTLINE")
            hint:SetFont(fontPath, math.max(8, b - 2), "OUTLINE")
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

-- Refresh the display with current settings
function KeystonePolaris:Refresh()
    if not self.displayFrame then return end

    -- Update frame position (skip during positioning mode — frame is being dragged)
    if not self._positioningMode then
        self.displayFrame:ClearAllPoints()
        self.displayFrame:SetPoint(
            self.db.profile.general.position,
            UIParent,
            self.db.profile.general.position,
            self.db.profile.general.xOffset,
            self.db.profile.general.yOffset
        )
    end

    -- Update font size and font
    self.displayFrame.text:SetFont(self.LSM:Fetch('font', self.db.profile.text.font), self.db.profile.general.fontSize, "OUTLINE")
    -- Update horizontal alignment
    self:ApplyTextLayout()

    -- Update text color
    local color = self.db.profile.color.inProgress
    self.displayFrame.text:SetTextColor(color.r, color.g, color.b, 1)
    self.displayFrame.text:SetAlpha(self.db.profile.general.textOpacity or 1)

    -- Update dungeon data with advanced options if enabled
    if self.UpdateDungeonData then self:UpdateDungeonData() end

    -- Show/hide based on enabled state
    local leaderEnabled   = self.db.profile.general.rolesEnabled.LEADER
    local isLeader        = UnitIsGroupLeader("player")
    local role            = UnitGroupRolesAssigned("player")   -- "TANK", "HEALER", "DAMAGER", ou "NONE"
    local roleEnabled     = self.db.profile.general.rolesEnabled[role]

    local shouldShow = (leaderEnabled and isLeader) or roleEnabled or role == "NONE"

    if not shouldShow then
        if self._testMode then
            self.displayFrame:Show()
        else
            self.displayFrame:Hide()
            return
        end
    end
    self.displayFrame:Show()
end
