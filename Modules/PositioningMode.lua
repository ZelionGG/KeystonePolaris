local AddOnName, KeystonePolaris = ...
local L = LibStub("AceLocale-3.0"):GetLocale(AddOnName)
local _G = _G

local function GetRoleMarkerStrataFrame(self)
    if self.GetRoleMarkerAnchorFrame then
        return self:GetRoleMarkerAnchorFrame()
    end
    return self.roleMarkerButton
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
    self:CreatePositioningOffsetPopup()
end

function KeystonePolaris:CreatePositioningOffsetPopup()
    if self.positioningOffsetPopup then return self.positioningOffsetPopup end

    local popup = CreateFrame("Frame", "KPL_PositioningOffsetPopup", UIParent, "BasicFrameTemplateWithInset")
    popup:SetSize(200, 118)
    popup:SetFrameStrata("TOOLTIP")
    popup:SetFrameLevel(200)
    popup:EnableMouse(true)
    popup:SetMovable(true)
    popup:SetClampedToScreen(true)
    popup:RegisterForDrag("LeftButton")
    popup:SetScript("OnDragStart", function() popup:StartMoving() end)
    popup:SetScript("OnDragStop", function() popup:StopMovingOrSizing() end)
    popup.TitleText:SetText(L["X_OFFSET"])

    popup.CloseButton:SetScript("OnClick", function()
        popup:Hide()
    end)

    local function MakeOffsetSlider(widgetName, label, y)
        local offsetSlider = CreateFrame("Slider", widgetName, popup, "OptionsSliderTemplate")
        offsetSlider:SetPoint("LEFT", popup, "LEFT", 16, 0)
        offsetSlider:SetPoint("RIGHT", popup, "RIGHT", -16, 0)
        offsetSlider:SetPoint("TOP", popup, "TOP", 0, y)
        offsetSlider:SetHeight(17)
        offsetSlider:SetValueStep(1)
        offsetSlider:SetObeyStepOnDrag(true)
        local offsetName = offsetSlider:GetName()
        _G[offsetName .. "Low"]:SetText("")
        _G[offsetName .. "High"]:SetText("")
        _G[offsetName .. "Text"]:SetText(label .. ": 0")
        return offsetSlider
    end

    local xSlider = MakeOffsetSlider("KPL_PosXOffset", L["X_OFFSET"], -36)
    xSlider:SetScript("OnValueChanged", function(_, value)
        if self._positioningOffsetSliderLock then return end
        self:SetPositioningFocusOffset("xOffset", math.floor(value + 0.5))
        _G[xSlider:GetName() .. "Text"]:SetText(L["X_OFFSET"] .. ": " .. math.floor(value + 0.5))
    end)
    popup.xOffsetSlider = xSlider

    local ySlider = MakeOffsetSlider("KPL_PosYOffset", L["Y_OFFSET"], -72)
    ySlider:SetScript("OnValueChanged", function(_, value)
        if self._positioningOffsetSliderLock then return end
        self:SetPositioningFocusOffset("yOffset", math.floor(value + 0.5))
        _G[ySlider:GetName() .. "Text"]:SetText(L["Y_OFFSET"] .. ": " .. math.floor(value + 0.5))
    end)
    popup.yOffsetSlider = ySlider

    if ElvUI then
        local E = unpack(ElvUI)
        if E and E.Skins then
            local S = E:GetModule('Skins')
            if S.HandleFrame then
                pcall(S.HandleFrame, S, popup)
            end
            if S.HandleCloseButton and popup.CloseButton then
                pcall(S.HandleCloseButton, S, popup.CloseButton)
            end
            if S.HandleSliderFrame then
                S:HandleSliderFrame(xSlider)
                S:HandleSliderFrame(ySlider)
            end
        end
    end

    popup:Hide()
    self.positioningOffsetPopup = popup
    return popup
end

function KeystonePolaris:EnterPositioningMode(focus)
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
    if self.SaveRoleMarkerPositioningState then
        self:SaveRoleMarkerPositioningState()
    end

    self._testMode = true
    self._positioningMode = true
    self._progressBarPositioning = true
    self:StartTestModeTicker()
    self:UpdatePercentageText()

    self.displayFrame:SetMovable(true)
    self.displayFrame:EnableMouse(true)
    self.displayFrame:RegisterForDrag("LeftButton")
    self.displayFrame:SetScript("OnDragStart", function()
        self:SetPositioningFocus("display")
        self.displayFrame:StartMoving()
    end)
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
        self:RefreshPositioningOffsetSliders()
    end)
    self.displayFrame:SetScript("OnMouseUp", function(_, mouseButton)
        if mouseButton == "LeftButton" or mouseButton == "RightButton" then
            self:SetPositioningFocus("display")
            self:ShowPositioningOffsetPopup()
        end
    end)

    self.displayFrame:Show()
    if self.EnableProgressBarPreview then self:EnableProgressBarPreview() end
    if self.BeginRoleMarkerPositioning then self:BeginRoleMarkerPositioning() end
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
    self:SetPositioningFocus(focus)
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
        self.displayFrame:SetScript("OnMouseUp", nil)
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
    if self.FinishRoleMarkerPositioning then
        self:FinishRoleMarkerPositioning(save)
    end
    self._savedPosition = nil
    self._savedProgressBarPosition = nil
    self._positioningFocus = nil

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
    local roleMarkerFrame = GetRoleMarkerStrataFrame(self)
    if roleMarkerFrame and self._prevRoleMarkerStrata then
        roleMarkerFrame:SetFrameStrata(self._prevRoleMarkerStrata)
        self._prevRoleMarkerStrata = nil
    end

    if self.positioningToolbar then self.positioningToolbar:Hide() end
    if self.positioningOffsetPopup then self.positioningOffsetPopup:Hide() end

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

function KeystonePolaris:ResolvePositioningFocus(focus)
    if focus == "roleMarker" then
        local db = self.db and self.db.profile and self.db.profile.roleMarker
        if db and db.enabled and (self.roleMarkerButton or self.roleMarkerTitleFrame) then
            return "roleMarker"
        end
    elseif focus == "progressBar" then
        if self.GetProgressBarValue and self:GetProgressBarValue("enabled") and self.progressBarFrame then
            return "progressBar"
        end
    end
    return "display"
end

function KeystonePolaris:GetPositioningFocusFrame()
    local focus = self._positioningFocus or "display"
    if focus == "roleMarker" then
        local frame = self.GetRoleMarkerAnchorFrame and self:GetRoleMarkerAnchorFrame() or self.roleMarkerButton
        if frame then
            return frame, false
        end
    end
    if focus == "progressBar" and self.progressBarFrame then
        return self.progressBarFrame, false
    end
    return self.displayFrame, true
end

function KeystonePolaris:GetPositioningFocusOffsets()
    local focus = self._positioningFocus or "display"
    if focus == "roleMarker" then
        local db = self.db and self.db.profile and self.db.profile.roleMarker
        return (db and db.xOffset) or 0, (db and db.yOffset) or 0
    end
    if focus == "progressBar" then
        local pb = self.db and self.db.profile and self.db.profile.progressBar
        return (pb and pb.xOffset) or 0, (self.GetProgressBarValue and self:GetProgressBarValue("yOffset")) or 0
    end
    local general = self.db and self.db.profile and self.db.profile.general
    return (general and general.xOffset) or 0, (general and general.yOffset) or 0
end

function KeystonePolaris:SetPositioningFocusOffset(axis, value)
    local focus = self._positioningFocus or "display"
    if focus == "roleMarker" then
        local db = self.db and self.db.profile and self.db.profile.roleMarker
        if not db then return end
        db[axis] = value
        if self.ApplyRoleMarkerPosition then self:ApplyRoleMarkerPosition(true) end
    elseif focus == "progressBar" then
        local pb = self.db and self.db.profile and self.db.profile.progressBar
        if not pb then return end
        pb[axis] = value
        if self.ApplyProgressBarPosition then self:ApplyProgressBarPosition() end
    else
        local general = self.db and self.db.profile and self.db.profile.general
        if not general then return end
        general[axis] = value
        local df = self.displayFrame
        if df then
            df:ClearAllPoints()
            df:SetPoint(general.position, UIParent, general.position, general.xOffset, general.yOffset)
        end
    end
    self:RefreshPositioningBorder()
end

function KeystonePolaris:GetPositioningFocusTitle()
    local focus = self._positioningFocus or "display"
    if focus == "roleMarker" then
        return L["KPL_RM_HEADER"]
    end
    if focus == "progressBar" then
        return L["PROGRESS_BAR"]
    end
    return L["DISPLAY"]
end

function KeystonePolaris:AnchorPositioningOffsetPopup()
    local popup = self.positioningOffsetPopup
    if not popup then return end

    local x, y = GetCursorPosition()
    local scale = UIParent:GetEffectiveScale()
    if not x or not y or not scale or scale == 0 then return end
    x, y = x / scale, y / scale
    popup:ClearAllPoints()
    popup:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x + 4, y - 4)
end

function KeystonePolaris:RefreshPositioningOffsetSliders()
    local popup = self.positioningOffsetPopup
    if not popup or not popup.xOffsetSlider or not popup.yOffsetSlider then return end

    local xOff, yOff = self:GetPositioningFocusOffsets()
    local xMax = math.ceil(GetScreenWidth())
    local yMax = math.ceil(GetScreenHeight())
    self._positioningOffsetSliderLock = true
    popup.xOffsetSlider:SetMinMaxValues(-xMax, xMax)
    popup.xOffsetSlider:SetValue(xOff)
    _G[popup.xOffsetSlider:GetName() .. "Text"]:SetText(L["X_OFFSET"] .. ": " .. math.floor(xOff + 0.5))
    popup.yOffsetSlider:SetMinMaxValues(-yMax, yMax)
    popup.yOffsetSlider:SetValue(yOff)
    _G[popup.yOffsetSlider:GetName() .. "Text"]:SetText(L["Y_OFFSET"] .. ": " .. math.floor(yOff + 0.5))
    self._positioningOffsetSliderLock = false
    if popup.TitleText then
        popup.TitleText:SetText(self:GetPositioningFocusTitle())
    end
end

function KeystonePolaris:ShowPositioningOffsetPopup()
    if not self._positioningMode then return end
    if not self.positioningOffsetPopup then
        self:CreatePositioningOffsetPopup()
    end
    self:RefreshPositioningOffsetSliders()
    self.positioningOffsetPopup:Show()
    self:AnchorPositioningOffsetPopup()
end

function KeystonePolaris:SetPositioningFocus(focus)
    if not self._positioningMode then return end
    self._positioningFocus = self:ResolvePositioningFocus(focus)
    self:ShowPositioningBorder()
    if self.positioningOffsetPopup then
        self:RefreshPositioningOffsetSliders()
    end
end

function KeystonePolaris:UpdatePositioningBorderAnimation()
    local anchor = self._borderAnchor
    local state = self._borderAnimationState
    if not (self._positioningMode and anchor and state and self._borderTexturePool) then return end

    local target, useTextBounds = self:GetPositioningFocusFrame()
    if target then
        local layoutW, layoutH = self:LayoutPositioningBorderAnchor(target, useTextBounds, 4)
        if layoutW then
            state.width = layoutW
            state.height = layoutH
        end
    end

    local w = anchor:GetWidth() or state.width
    local h = anchor:GetHeight() or state.height
    if w > 0 then state.width = w end
    if h > 0 then state.height = h end
    w = state.width
    h = state.height
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

local function UnionFrameRect(left, right, top, bottom, frame)
    if not frame or not frame:IsShown() then
        return left, right, top, bottom
    end
    local fl, fr, ft, fb = frame:GetLeft(), frame:GetRight(), frame:GetTop(), frame:GetBottom()
    if not fl or not fr or not ft or not fb then
        return left, right, top, bottom
    end
    return math.min(left, fl), math.max(right, fr), math.max(top, ft), math.min(bottom, fb)
end

function KeystonePolaris:LayoutPositioningBorderAnchor(target, useTextBounds, pad)
    local anchor = self._borderAnchor
    if not anchor or not target then return end
    pad = pad or 4
    anchor:ClearAllPoints()

    if useTextBounds then
        local text = target.text
        if not text then return end
        local w = (text:GetStringWidth() or 0) + pad * 2
        local h = (text:GetStringHeight() or 0) + pad * 2
        if w <= pad * 2 or h <= pad * 2 then return end

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
        return w, h
    end

    local left, right, top, bottom = target:GetLeft(), target:GetRight(), target:GetTop(), target:GetBottom()
    if left and self._positioningFocus == "progressBar" then
        left, right, top, bottom = UnionFrameRect(left, right, top, bottom, target.callout)
    end

    if left and right and top and bottom then
        local tl, tr, tt, tb = target:GetLeft(), target:GetRight(), target:GetTop(), target:GetBottom()
        local screenW = (tr and tl) and (tr - tl) or 0
        local screenH = (tt and tb) and (tt - tb) or 0
        local sx = (screenW > 0) and ((target:GetWidth() or screenW) / screenW) or 1
        local sy = (screenH > 0) and ((target:GetHeight() or screenH) / screenH) or 1
        local w = (right - left) * sx + pad * 2
        local h = (top - bottom) * sy + pad * 2
        if w <= pad * 2 or h <= pad * 2 then return end
        anchor:SetPoint("TOPLEFT", target, "TOPLEFT", (left - tl) * sx - pad, (top - tt) * sy + pad)
        anchor:SetSize(w, h)
        return w, h
    end

    local w = (target:GetWidth() or 0) + pad * 2
    local h = (target:GetHeight() or 0) + pad * 2
    if w <= pad * 2 or h <= pad * 2 then return end
    anchor:SetPoint("TOPLEFT", target, "TOPLEFT", -pad, pad)
    anchor:SetPoint("BOTTOMRIGHT", target, "BOTTOMRIGHT", pad, -pad)
    return w, h
end

function KeystonePolaris:ShowPositioningBorder()
    local target, useTextBounds = self:GetPositioningFocusFrame()
    if not target then return end

    if not self._borderAnchor then
        self._borderAnchor = CreateFrame("Frame", nil, target)
    else
        self._borderAnchor:SetParent(target)
    end
    local anchor = self._borderAnchor
    anchor:SetFrameStrata(target:GetFrameStrata() or "TOOLTIP")
    anchor:SetFrameLevel((target:GetFrameLevel() or 0) + 20)

    local w, h = self:LayoutPositioningBorderAnchor(target, useTextBounds, 4)
    if not w then return end
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
    if not self._positioningMode then return end

    if self._borderAnchor and self._borderAnimationState then
        local target, useTextBounds = self:GetPositioningFocusFrame()
        if target then
            self:LayoutPositioningBorderAnchor(target, useTextBounds, 4)
            self:UpdatePositioningBorderAnimation()
        end
        return
    end

    self:ShowPositioningBorder()
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
        local roleMarkerFrame = GetRoleMarkerStrataFrame(self)
        if roleMarkerFrame then
            self._prevRoleMarkerStrata = self._prevRoleMarkerStrata or roleMarkerFrame:GetFrameStrata()
            roleMarkerFrame:SetFrameStrata("TOOLTIP")
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
            local restoreRoleMarker = GetRoleMarkerStrataFrame(self)
            if restoreRoleMarker and self._prevRoleMarkerStrata then
                restoreRoleMarker:SetFrameStrata(self._prevRoleMarkerStrata)
                self._prevRoleMarkerStrata = nil
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
        local roleMarkerFrame = GetRoleMarkerStrataFrame(self)
        if roleMarkerFrame then
            self._prevRoleMarkerStrata = self._prevRoleMarkerStrata or roleMarkerFrame:GetFrameStrata()
            roleMarkerFrame:SetFrameStrata("TOOLTIP")
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
