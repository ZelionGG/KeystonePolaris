local AddOnName, KeystonePolaris = ...;

local _G = _G
local select = select
local HideUIPanel = _G.HideUIPanel
local AceGUIWidgetLSMlists = _G.AceGUIWidgetLSMlists

local L = LibStub("AceLocale-3.0"):GetLocale(AddOnName, true)

local PreviewScenarioValues = KeystonePolaris.PreviewScenarioValues
local SetPreviewScenario = KeystonePolaris.SetPreviewScenario
local PreviewScenarioDropdown = KeystonePolaris.PreviewScenarioDropdown
local ColumnRow = KeystonePolaris.ColumnRow
local SetColorTable = KeystonePolaris.SetColorTable

local function GetProgressBarWidthSliderMax()
    if GetPhysicalScreenSize then
        return math.ceil((select(1, GetPhysicalScreenSize())))
    end
    return math.ceil(GetScreenWidth())
end

local function ProgressBarWidthUiToSlider(uiWidth)
    local uiMax = GetScreenWidth()
    local sliderMax = GetProgressBarWidthSliderMax()
    if uiMax <= 0 or sliderMax <= 0 then return uiWidth end
    return uiWidth * sliderMax / uiMax
end

local function ProgressBarWidthSliderToUi(sliderValue)
    local uiMax = GetScreenWidth()
    local sliderMax = GetProgressBarWidthSliderMax()
    if sliderMax <= 0 then return sliderValue end
    return sliderValue * uiMax / sliderMax
end

function KeystonePolaris:GetProgressBarOptions()
    return {
        name = L["PROGRESS_BAR"],
        type = "group",
        order = 2,
        childGroups = "tree",
        args = {
            positioning = {
                name = L["POSITIONING"],
                type = "group",
                order = 2,
                args = {
                    enabledRow = ColumnRow(1, {
                        name = L["PROGRESS_BAR_ENABLED"],
                        desc = L["PROGRESS_BAR_ENABLED_DESC"],
                        type = "toggle",
                        get = function() return self:GetProgressBarValue("enabled") end,
                        set = function(_, value)
                            self.db.profile.progressBar.enabled = value
                            if self.UpdateProgressBar then self:UpdateProgressBar() end
                        end,
                    }, {
                        name = L["SHOW_ANCHOR"],
                        type = "execute",
                        func = function()
                            HideUIPanel(SettingsPanel)
                            if self.EnterPositioningMode then
                                self:EnterPositioningMode("progressBar")
                            end
                        end,
                    }),
                    sizeHeader = {
                        type = "header",
                        name = "",
                        order = 2,
                    },
                    widthRow = ColumnRow(3, {
                        name = L["PROGRESS_BAR_WIDTH"],
                        type = "range",
                        min = 50,
                        max = GetProgressBarWidthSliderMax(),
                        step = 1,
                        get = function()
                            return math.floor(ProgressBarWidthUiToSlider(self.db.profile.progressBar.width) + 0.5)
                        end,
                        set = function(_, value)
                            self.db.profile.progressBar.width = ProgressBarWidthSliderToUi(value)
                            if self.ApplyProgressBarLayout then self:ApplyProgressBarLayout() end
                        end,
                    }, {
                        name = L["PROGRESS_BAR_HEIGHT"],
                        type = "range",
                        min = 8, max = 60, step = 1,
                        get = function() return self.db.profile.progressBar.height end,
                        set = function(_, value)
                            self.db.profile.progressBar.height = value
                            if self.ApplyProgressBarLayout then self:ApplyProgressBarLayout() end
                        end,
                    }),
                    offsetRow = ColumnRow(4, {
                        name = L["X_OFFSET"],
                        type = "range",
                        min = -math.ceil(GetScreenWidth()),
                        max = math.ceil(GetScreenWidth()),
                        step = 1,
                        get = function() return self.db.profile.progressBar.xOffset end,
                        set = function(_, value)
                            self.db.profile.progressBar.xOffset = value
                            if self.ApplyProgressBarPosition then self:ApplyProgressBarPosition() end
                        end,
                    }, {
                        name = L["Y_OFFSET"],
                        type = "range",
                        min = -math.ceil(GetScreenHeight()),
                        max = math.ceil(GetScreenHeight()),
                        step = 1,
                        get = function() return self:GetProgressBarValue("yOffset") end,
                        set = function(_, value)
                            self.db.profile.progressBar.yOffset = value
                            if self.ApplyProgressBarPosition then self:ApplyProgressBarPosition() end
                        end,
                    }),
                    directionHeader = {
                        type = "header",
                        name = "",
                        order = 5,
                    },
                    direction = {
                        name = L["PROGRESS_BAR_DIRECTION"],
                        type = "select",
                        order = 6,
                        values = {
                            LEFT_TO_RIGHT = L["PROGRESS_BAR_DIRECTION_LTR"],
                            RIGHT_TO_LEFT = L["PROGRESS_BAR_DIRECTION_RTL"],
                        },
                        get = function() return self.db.profile.progressBar.direction end,
                        set = function(_, value)
                            self.db.profile.progressBar.direction = value
                            if self.ApplyProgressBarLayout then self:ApplyProgressBarLayout() end
                        end,
                    },
                },
            },
            appearance = {
                name = L["APPEARANCE"],
                type = "group",
                order = 1,
                args = {
                    previewScenario = PreviewScenarioDropdown(0.01),
                    preview = {
                        name = "",
                        type = "select",
                        dialogControl = "KeystonePolaris_ProgressBarPreview",
                        order = 0.02,
                        width = "full",
                        values = PreviewScenarioValues,
                        get = function() return KeystonePolaris._previewScenario or 1 end,
                        set = function(_, value) SetPreviewScenario(value) end,
                    },
                    textureRow = ColumnRow(1, {
                        name = L["PROGRESS_BAR_TEXTURE"],
                        type = "select",
                        dialogControl = "LSM30_Statusbar",
                        values = AceGUIWidgetLSMlists.statusbar,
                        style = "dropdown",
                        get = function() return self.db.profile.progressBar.barTexture end,
                        set = function(_, value)
                            self.db.profile.progressBar.barTexture = value
                            if self.ApplyProgressBarPaint then self:ApplyProgressBarPaint() end
                        end,
                    }, {
                        name = L["PROGRESS_BAR_BG_ALPHA"],
                        type = "range",
                        min = 0, max = 1, step = 0.05,
                        isPercent = true,
                        get = function() return self.db.profile.progressBar.backgroundColor.a or 0.7 end,
                        set = function(_, value)
                            self.db.profile.progressBar.backgroundColor.a = value
                            if self.ApplyProgressBarBackground then self:ApplyProgressBarBackground() end
                            if self.ApplyProgressBarPaint then self:ApplyProgressBarPaint() end
                        end,
                    }),
                    bgColor = {
                        name = L["PROGRESS_BAR_BG_COLOR"],
                        type = "color",
                        hasAlpha = false,
                        order = 2,
                        width = 1.25,
                        get = function()
                            local c = self.db.profile.progressBar.backgroundColor
                            return c.r, c.g, c.b
                        end,
                        set = function(_, r, g, b)
                            local backgroundColor = self.db.profile.progressBar.backgroundColor
                            SetColorTable(backgroundColor, r, g, b, backgroundColor.a or 0.7)
                            if self.ApplyProgressBarBackground then self:ApplyProgressBarBackground() end
                            if self.ApplyProgressBarPaint then self:ApplyProgressBarPaint() end
                        end,
                    },
                    colorOverrideHeader = {
                        type = "header",
                        name = L["COLORS"],
                        order = 3,
                    },
                    useGradient = {
                        name = L["PROGRESS_BAR_USE_GRADIENT"],
                        desc = L["PROGRESS_BAR_USE_GRADIENT_DESC"],
                        type = "toggle",
                        order = 3.4,
                        width = "full",
                        get = function() return self.db.profile.progressBar.useGradient end,
                        set = function(_, value)
                            self.db.profile.progressBar.useGradient = value
                            if self.ApplyProgressBarPaint then self:ApplyProgressBarPaint() end
                        end,
                    },
                    gradientColorRow = ColumnRow(3.6, {
                        name = L["PROGRESS_BAR_GRADIENT_START_COLOR"],
                        type = "color",
                        hasAlpha = true,
                        disabled = function() return not self.db.profile.progressBar.useGradient end,
                        get = function()
                            local c = self.db.profile.progressBar.gradientStartColor
                            return c.r, c.g, c.b, c.a
                        end,
                        set = function(_, r, g, b, a)
                            SetColorTable(self.db.profile.progressBar.gradientStartColor, r, g, b, a)
                            if self.ApplyProgressBarPaint then self:ApplyProgressBarPaint() end
                        end,
                    }, {
                        name = L["PROGRESS_BAR_GRADIENT_END_COLOR"],
                        type = "color",
                        hasAlpha = true,
                        disabled = function() return not self.db.profile.progressBar.useGradient end,
                        get = function()
                            local c = self.db.profile.progressBar.gradientEndColor
                            return c.r, c.g, c.b, c.a
                        end,
                        set = function(_, r, g, b, a)
                            SetColorTable(self.db.profile.progressBar.gradientEndColor, r, g, b, a)
                            if self.ApplyProgressBarPaint then self:ApplyProgressBarPaint() end
                        end,
                    }),
                    overrideColors = {
                        name = L["PROGRESS_BAR_OVERRIDE_COLORS"],
                        desc = L["PROGRESS_BAR_OVERRIDE_COLORS_DESC"],
                        type = "toggle",
                        order = 4,
                        width = "full",
                        get = function() return self.db.profile.progressBar.overrideColors end,
                        set = function(_, value)
                            self.db.profile.progressBar.overrideColors = value
                            if self.ApplyProgressBarPaint then self:ApplyProgressBarPaint() end
                        end,
                    },
                    completedColor = {
                        name = L["PROGRESS_BAR_COMPLETED_COLOR"],
                        type = "color",
                        order = 4.5,
                        hasAlpha = true,
                        width = "full",
                        disabled = function()
                            local pb = self.db.profile.progressBar
                            return not pb.overrideColors or pb.useGradient
                        end,
                        get = function()
                            local c = self.db.profile.progressBar.completedColor
                            return c.r, c.g, c.b, c.a
                        end,
                        set = function(_, r, g, b, a)
                            SetColorTable(self.db.profile.progressBar.completedColor, r, g, b, a)
                            if self.ApplyProgressBarPaint then self:ApplyProgressBarPaint() end
                        end,
                    },
                    inProgressColor = {
                        name = L["PROGRESS_BAR_IN_PROGRESS_COLOR"],
                        type = "color",
                        order = 5,
                        hasAlpha = true,
                        disabled = function()
                            local pb = self.db.profile.progressBar
                            return not pb.overrideColors
                        end,
                        get = function()
                            local c = self.db.profile.progressBar.inProgressColor
                            return c.r, c.g, c.b, c.a
                        end,
                        set = function(_, r, g, b, a)
                            SetColorTable(self.db.profile.progressBar.inProgressColor, r, g, b, a)
                            if self.ApplyProgressBarPaint then self:ApplyProgressBarPaint() end
                        end,
                    },
                    missingColor = {
                        name = L["PROGRESS_BAR_MISSING_COLOR"],
                        type = "color",
                        order = 6,
                        hasAlpha = true,
                        disabled = function() return not self.db.profile.progressBar.overrideColors end,
                        get = function()
                            local c = self.db.profile.progressBar.missingColor
                            return c.r, c.g, c.b, c.a
                        end,
                        set = function(_, r, g, b, a)
                            SetColorTable(self.db.profile.progressBar.missingColor, r, g, b, a)
                            if self.ApplyProgressBarPaint then self:ApplyProgressBarPaint() end
                        end,
                    },
                    borderHeader = {
                        type = "header",
                        name = L["BORDERS"],
                        order = 7,
                    },
                    borderStyleRow = ColumnRow(8, {
                        name = L["PROGRESS_BAR_BORDER_STYLE"],
                        type = "select",
                        values = {
                            NONE = L["PROGRESS_BAR_BORDER_NONE"],
                            SOLID = L["PROGRESS_BAR_BORDER_SOLID"],
                            LSM_BORDER = L["PROGRESS_BAR_BORDER_LSM"],
                        },
                        get = function() return self:GetProgressBarValue("borderStyle") end,
                        set = function(_, value)
                            self.db.profile.progressBar.borderStyle = value
                            if self.ApplyProgressBarBorder then self:ApplyProgressBarBorder() end
                            if self.RefreshProgressBarOptionsPreview then self:RefreshProgressBarOptionsPreview() end
                        end,
                    }, {
                        name = L["PROGRESS_BAR_BORDER_TEXTURE"],
                        type = "select",
                        dialogControl = "LSM30_Border",
                        values = AceGUIWidgetLSMlists.border,
                        style = "dropdown",
                        disabled = function() return self:GetProgressBarValue("borderStyle") ~= "LSM_BORDER" end,
                        get = function() return self.db.profile.progressBar.borderTexture end,
                        set = function(_, value)
                            self.db.profile.progressBar.borderTexture = value
                            if self.ApplyProgressBarBorder then self:ApplyProgressBarBorder() end
                            if self.RefreshProgressBarOptionsPreview then self:RefreshProgressBarOptionsPreview() end
                        end,
                    }),
                    borderDetailRow = ColumnRow(9, {
                        name = L["PROGRESS_BAR_BORDER_COLOR"],
                        type = "color",
                        hasAlpha = true,
                        disabled = function() return self:GetProgressBarValue("borderStyle") == "NONE" end,
                        get = function()
                            local c = self.db.profile.progressBar.borderColor
                            return c.r, c.g, c.b, c.a
                        end,
                        set = function(_, r, g, b, a)
                            SetColorTable(self.db.profile.progressBar.borderColor, r, g, b, a)
                            if self.ApplyProgressBarBorder then self:ApplyProgressBarBorder() end
                            if self.RefreshProgressBarOptionsPreview then self:RefreshProgressBarOptionsPreview() end
                        end,
                    }, {
                        name = L["PROGRESS_BAR_BORDER_SIZE"],
                        type = "range",
                        min = 1, max = 16, step = 1,
                        disabled = function() return self:GetProgressBarValue("borderStyle") == "NONE" end,
                        get = function() return self.db.profile.progressBar.borderSize end,
                        set = function(_, value)
                            self.db.profile.progressBar.borderSize = value
                            if self.ApplyProgressBarBorder then self:ApplyProgressBarBorder() end
                            if self.RefreshProgressBarOptionsPreview then self:RefreshProgressBarOptionsPreview() end
                        end,
                    }),
                    tickHeader = {
                        type = "header",
                        name = L["TICKS"],
                        order = 10,
                    },
                    tickColorRow = ColumnRow(11, {
                        name = L["PROGRESS_BAR_TICK_COLOR"],
                        type = "color",
                        hasAlpha = true,
                        get = function()
                            local c = self.db.profile.progressBar.tickColor
                            return c.r, c.g, c.b, c.a
                        end,
                        set = function(_, r, g, b, a)
                            SetColorTable(self.db.profile.progressBar.tickColor, r, g, b, a)
                            if self.ApplyProgressBarPaint then self:ApplyProgressBarPaint() end
                        end,
                    }, {
                        name = L["PROGRESS_BAR_TICK_WIDTH"],
                        type = "range",
                        min = 1, max = 4, step = 1,
                        get = function() return self.db.profile.progressBar.tickWidth end,
                        set = function(_, value)
                            self.db.profile.progressBar.tickWidth = value
                            if self.ApplyProgressBarLayout then self:ApplyProgressBarLayout() end
                        end,
                    }),
                    tickOverflow = {
                        name = L["PROGRESS_BAR_TICK_OVERFLOW"],
                        desc = L["PROGRESS_BAR_TICK_OVERFLOW_DESC"],
                        type = "range",
                        order = 12,
                        min = 0, max = 6, step = 1,
                        width = 1,
                        get = function() return self.db.profile.progressBar.tickOverflow end,
                        set = function(_, value)
                            self.db.profile.progressBar.tickOverflow = value
                            if self.ApplyProgressBarLayout then self:ApplyProgressBarLayout() end
                        end,
                    },
                    showMilestoneTicks = {
                        name = L["PROGRESS_BAR_SHOW_MILESTONE_TICKS"],
                        desc = L["PROGRESS_BAR_SHOW_MILESTONE_TICKS_DESC"],
                        type = "toggle",
                        order = 12.5,
                        width = "full",
                        get = function() return self:GetProgressBarValue("showMilestoneTicks") end,
                        set = function(_, value)
                            self.db.profile.progressBar.showMilestoneTicks = value
                            if self.ApplyProgressBarMilestoneTicks then self:ApplyProgressBarMilestoneTicks() end
                        end,
                    },
                    milestoneTickColorRow = ColumnRow(12.6, {
                        name = L["PROGRESS_BAR_MILESTONE_TICK_COLOR"],
                        type = "color",
                        hasAlpha = true,
                        disabled = function() return not self:GetProgressBarValue("showMilestoneTicks") end,
                        get = function()
                            local c = self.db.profile.progressBar.milestoneTickColor
                            return c.r, c.g, c.b, c.a
                        end,
                        set = function(_, r, g, b, a)
                            SetColorTable(self.db.profile.progressBar.milestoneTickColor, r, g, b, a)
                            if self.ApplyProgressBarPaint then self:ApplyProgressBarPaint() end
                        end,
                    }, {
                        name = L["PROGRESS_BAR_MILESTONE_TICK_WIDTH"],
                        type = "range",
                        min = 1, max = 3, step = 1,
                        disabled = function() return not self:GetProgressBarValue("showMilestoneTicks") end,
                        get = function() return self.db.profile.progressBar.milestoneTickWidth or 1 end,
                        set = function(_, value)
                            self.db.profile.progressBar.milestoneTickWidth = value
                            if self.ApplyProgressBarLayout then self:ApplyProgressBarLayout() end
                        end,
                    }),
                    calloutHeader = {
                        type = "header",
                        name = L["CALLOUT"],
                        order = 13,
                    },
                    calloutRow = ColumnRow(14, {
                        name = L["PROGRESS_BAR_SHOW_CALLOUT"],
                        desc = L["PROGRESS_BAR_SHOW_CALLOUT_DESC"],
                        type = "toggle",
                        width = 1.25,
                        get = function() return self:GetProgressBarValue("showCallout") end,
                        set = function(_, value)
                            self.db.profile.progressBar.showCallout = value
                            if self.ApplyProgressBarCallout then self:ApplyProgressBarCallout() end
                        end,
                    },
                    {
                        name = L["PROGRESS_BAR_CALLOUT_POSITION"],
                        type = "select",
                        width = 1.1,
                        disabled = function() return not self:GetProgressBarValue("showCallout") end,
                        values = {
                            ABOVE = L["PROGRESS_BAR_CALLOUT_ABOVE"],
                            BELOW = L["PROGRESS_BAR_CALLOUT_BELOW"],
                        },
                        get = function() return self.db.profile.progressBar.calloutPosition end,
                        set = function(_, value)
                            self.db.profile.progressBar.calloutPosition = value
                            if self.ApplyProgressBarCallout then self:ApplyProgressBarCallout() end
                        end,
                    }),
                    calloutFontRow = ColumnRow(16, {
                        name = L["PROGRESS_BAR_CALLOUT_FONT"],
                        type = "select",
                        dialogControl = 'LSM30_Font',
                        values = AceGUIWidgetLSMlists.font,
                        width = 1.25,
                        style = "dropdown",
                        disabled = function() return not self:GetProgressBarValue("showCallout") end,
                        get = function() return self.db.profile.progressBar.calloutFont end,
                        set = function(_, value)
                            self.db.profile.progressBar.calloutFont = value
                            if self.ApplyProgressBarCallout then self:ApplyProgressBarCallout() end
                        end,
                    },
                    {
                        name = L["PROGRESS_BAR_CALLOUT_FONT_SIZE"],
                        type = "range",
                        min = 8, max = 24, step = 1,
                        width = 1,
                        disabled = function() return not self:GetProgressBarValue("showCallout") end,
                        get = function() return self.db.profile.progressBar.calloutFontSize end,
                        set = function(_, value)
                            self.db.profile.progressBar.calloutFontSize = value
                            if self.ApplyProgressBarCallout then self:ApplyProgressBarCallout() end
                        end,
                    }),
                    calloutColorRow = ColumnRow(17, {
                        name = L["PROGRESS_BAR_CALLOUT_TEXT_COLOR"],
                        type = "color",
                        hasAlpha = true,
                        disabled = function() return not self:GetProgressBarValue("showCallout") end,
                        get = function()
                            local c = self.db.profile.progressBar.calloutTextColor
                            return c.r, c.g, c.b, c.a
                        end,
                        set = function(_, r, g, b, a)
                            SetColorTable(self.db.profile.progressBar.calloutTextColor, r, g, b, a)
                            if self.ApplyProgressBarCallout then self:ApplyProgressBarCallout() end
                        end,
                    }, {
                        name = L["PROGRESS_BAR_CALLOUT_BG_COLOR"],
                        type = "color",
                        hasAlpha = true,
                        disabled = function() return not self:GetProgressBarValue("showCallout") end,
                        get = function()
                            local c = self.db.profile.progressBar.calloutBackgroundColor
                            return c.r, c.g, c.b, c.a
                        end,
                        set = function(_, r, g, b, a)
                            SetColorTable(self.db.profile.progressBar.calloutBackgroundColor, r, g, b, a)
                            if self.ApplyProgressBarCallout then self:ApplyProgressBarCallout() end
                        end,
                    }),
                },
            },
        },
    }
end

