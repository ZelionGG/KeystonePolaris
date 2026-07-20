local AddOnName, KeystonePolaris = ...
local L = LibStub("AceLocale-3.0"):GetLocale(AddOnName)
local _G = _G

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
    if self.db.profile.progressBar then
        self._savedProgressBarPosition = {
            position = self.db.profile.progressBar.position,
            xOffset = self.db.profile.progressBar.xOffset,
            yOffset = self.db.profile.progressBar.yOffset,
        }
    end

    self._testMode = true
    self._positioningMode = true
    self._progressBarPositioning = true
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
    if self.EnableProgressBarPreview then self:EnableProgressBarPreview() end
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
    self._progressBarPositioning = false
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
    if not save and self._savedProgressBarPosition and self.db.profile.progressBar then
        self.db.profile.progressBar.position = self._savedProgressBarPosition.position
        self.db.profile.progressBar.xOffset = self._savedProgressBarPosition.xOffset
        self.db.profile.progressBar.yOffset = self._savedProgressBarPosition.yOffset
    end
    self._savedPosition = nil
    self._savedProgressBarPosition = nil

    self:HidePositioningBorder()

    if self.testDimOverlay then self.testDimOverlay:Hide() end
    if self.gridOverlay then self.gridOverlay:Hide() end
    if self.displayFrame and self._prevDisplayStrata then
        self.displayFrame:SetFrameStrata(self._prevDisplayStrata)
        self._prevDisplayStrata = nil
    end
    if self.progressBarFrame and self._prevProgressBarStrata then
        self.progressBarFrame:SetFrameStrata(self._prevProgressBarStrata)
        self._prevProgressBarStrata = nil
    end

    if self.positioningToolbar then self.positioningToolbar:Hide() end

    if self.DisableProgressBarPreview then self:DisableProgressBarPreview() end
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
        if self.progressBarFrame then
            self._prevProgressBarStrata = self._prevProgressBarStrata or self.progressBarFrame:GetFrameStrata()
            self.progressBarFrame:SetFrameStrata("TOOLTIP")
        end
    else
        if self.testDimOverlay then self.testDimOverlay:Hide() end
        if not (self.db.profile.general.positioningShowGrid and self._positioningMode) then
            if self.displayFrame and self._prevDisplayStrata then
                self.displayFrame:SetFrameStrata(self._prevDisplayStrata)
                self._prevDisplayStrata = nil
            end
            if self.progressBarFrame and self._prevProgressBarStrata then
                self.progressBarFrame:SetFrameStrata(self._prevProgressBarStrata)
                self._prevProgressBarStrata = nil
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
        if self.progressBarFrame then
            self._prevProgressBarStrata = self._prevProgressBarStrata or self.progressBarFrame:GetFrameStrata()
            self.progressBarFrame:SetFrameStrata("TOOLTIP")
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
