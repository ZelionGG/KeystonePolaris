local AddOnName, KeystonePolaris = ...;

local _G = _G
local HideUIPanel = _G.HideUIPanel
local AceGUIWidgetLSMlists = _G.AceGUIWidgetLSMlists

local L = LibStub("AceLocale-3.0"):GetLocale(AddOnName, true)
local ACR = LibStub("AceConfigRegistry-3.0")

local RefreshPreviewWidget = KeystonePolaris.RefreshPreviewWidget
local PreviewGroup = KeystonePolaris.PreviewGroup
local ColumnRow = KeystonePolaris.ColumnRow
local MakeStatusColorOption = KeystonePolaris.MakeStatusColorOption
local MakeMilestonePrefixColorProps = KeystonePolaris.MakeMilestonePrefixColorProps
local MDT_FEATURES_ENABLED = KeystonePolaris.mdtFeaturesEnabled

function KeystonePolaris:GetPositioningOptions()
    return {
        name = L["POSITIONING"],
        type = "group",
        order = 3,
        args = {
            positionRow = ColumnRow(2, {
                name = L["POSITION"],
                type = "select",
                sorting = { "TOP", "CENTER", "BOTTOM" },
                values = {
                    TOP = L["TOP"],
                    CENTER = L["CENTER"],
                    BOTTOM = L["BOTTOM"]
                },
                get = function()
                    return self.db.profile.general.position
                end,
                set = function(_, value)
                    self.db.profile.general.position = value
                    self.db.profile.general.xOffset = 0
                    self.db.profile.general.yOffset = 0
                    self:Refresh()
                end
            }, {
                name = L["SHOW_ANCHOR"],
                type = "execute",
                func = function()
                    HideUIPanel(SettingsPanel)
                    self:EnterPositioningMode()
                end
            }),
            offsetRow = ColumnRow(3, {
                name = L["X_OFFSET"],
                type = "range",
                min = -math.ceil(GetScreenWidth()),
                max = math.ceil(GetScreenWidth()),
                step = 1,
                get = function()
                    return self.db.profile.general.xOffset
                end,
                set = function(_, value)
                    self.db.profile.general.xOffset = value
                    self:Refresh()
                end
            }, {
                name = L["Y_OFFSET"],
                type = "range",
                min = -math.ceil(GetScreenHeight()),
                max = math.ceil(GetScreenHeight()),
                step = 1,
                get = function()
                    return self.db.profile.general.yOffset
                end,
                set = function(_, value)
                    self.db.profile.general.yOffset = value
                    self:Refresh()
                end
            }),
            positioningHeader = {
                type = "header",
                name = "",
                order = 4,
            },
            dimBackground = {
                name = L["DIM_BACKGROUND"],
                type = "toggle",
                order = 5,
                get = function()
                    return self.db.profile.general.positioningDimBackground
                end,
                set = function(_, value)
                    self.db.profile.general.positioningDimBackground = not not value
                end,
            },
            showGrid = {
                name = L["SHOW_GRID"],
                type = "toggle",
                order = 6,
                get = function()
                    return self.db.profile.general.positioningShowGrid
                end,
                set = function(_, value)
                    self.db.profile.general.positioningShowGrid = not not value
                end,
            },
            gridSpacing = {
                name = L["GRID_SPACING"],
                type = "range",
                order = 7,
                min = 10,
                max = 200,
                step = 5,
                get = function()
                    return self.db.profile.general.positioningGridSpacing
                end,
                set = function(_, value)
                    self.db.profile.general.positioningGridSpacing = value
                end,
                disabled = function()
                    return not self.db.profile.general.positioningShowGrid
                end,
            }
        }
    }
end

function KeystonePolaris:GetAppearanceOptions()
    return {
        name = L["APPEARANCE"],
        type = "group",
        order = 2,
        args = {
            previewGroup = PreviewGroup(0.01),
            fontRow = ColumnRow(1, {
                name = L["FONT"],
                type = "select",
                dialogControl = 'LSM30_Font',
                values = AceGUIWidgetLSMlists.font,
                style = "dropdown",
                get = function() return self.db.profile.text.font end,
                set = function(_, value)
                    self.db.profile.text.font = value
                    self:Refresh()
                    RefreshPreviewWidget()
                end
            }, {
                name = L["FONT_ALIGN"],
                desc = L["FONT_ALIGN_DESC"],
                type = "select",
                values = {
                    LEFT = L["LEFT"],
                    CENTER = L["CENTER"],
                    RIGHT = L["RIGHT"],
                },
                get = function() return self.db.profile.general.mainDisplay.textAlign end,
                set = function(_, value)
                    self.db.profile.general.mainDisplay.textAlign = value
                    if self.ApplyTextLayout then self:ApplyTextLayout() end
                    if self.displayFrame and self.displayFrame.text then
                        local t = self.displayFrame.text
                        t:SetText(t:GetText())
                    end
                    if self.UpdatePercentageText then self:UpdatePercentageText() end
                    if self.ApplyTextLayout then self:ApplyTextLayout() end
                    if self.AdjustDisplayFrameSize then self:AdjustDisplayFrameSize() end

                    local function reapply()
                        if self.displayFrame and self.displayFrame.text then
                            if self.ApplyTextLayout then self:ApplyTextLayout() end
                            local t = self.displayFrame.text
                            t:SetText(t:GetText())
                            if self.AdjustDisplayFrameSize then self:AdjustDisplayFrameSize() end
                        end
                    end
                    C_Timer.After(0.03, reapply)
                    C_Timer.After(0.08, reapply)
                    C_Timer.After(0.15, reapply)

                    local origMulti = self.db.profile.general.mainDisplay.multiLine
                    local function setMulti(val)
                        self.db.profile.general.mainDisplay.multiLine = val
                        ACR:NotifyChange(AddOnName)
                    end
                    setMulti(not origMulti)
                    reapply()
                    C_Timer.After(0.05, function()
                        setMulti(origMulti)
                        reapply()
                    end)
                    C_Timer.After(0.10, function()
                        setMulti(origMulti)
                        reapply()
                    end)
                    C_Timer.After(0.20, function()
                        setMulti(origMulti)
                        reapply()
                    end)
                    RefreshPreviewWidget()
                end,
                disabled = function()
                    return not self.db.profile.general.mainDisplay.multiLine
                end
            }),
            fontSizeRow = ColumnRow(2, {
                name = L["FONT_SIZE"],
                desc = L["FONT_SIZE_DESC"],
                type = "range",
                min = 8,
                max = 64,
                step = 1,
                get = function()
                    return self.db.profile.general.fontSize
                end,
                set = function(_, value)
                    self.db.profile.general.fontSize = value
                    self:Refresh()
                    RefreshPreviewWidget()
                end
            }, {
                name = L["TEXT_OPACITY"],
                desc = L["TEXT_OPACITY_DESC"],
                type = "range",
                min = 0, max = 1, step = 0.05,
                isPercent = true,
                get = function()
                    return self.db.profile.general.textOpacity or 1
                end,
                set = function(_, value)
                    self.db.profile.general.textOpacity = value
                    if self.UpdatePercentageText then self:UpdatePercentageText() end
                    self:Refresh()
                    RefreshPreviewWidget()
                end,
            }),
            fontFlags = {
                name = L["FONT_FLAGS"],
                desc = L["FONT_FLAGS_DESC"],
                type = "select",
                order = 2.5,
                width = 1.25,
                sorting = KeystonePolaris.fontFlagPresetSorting,
                values = function()
                    return self:GetFontFlagSelectValues()
                end,
                get = function()
                    return self:GetFontFlagsPreset()
                end,
                set = function(_, value)
                    self.db.profile.text.fontFlags = value or KeystonePolaris.DEFAULT_FONT_FLAG_PRESET
                    self:Refresh()
                    if self.RefreshMobPercentageFrames then self:RefreshMobPercentageFrames() end
                    if self.RefreshProgressBar then self:RefreshProgressBar() end
                    RefreshPreviewWidget()
                end,
            },
            colorsSpacer = {
                type = "description",
                name = " ",
                order = 2.9,
                width = "full",
            },
            colorsHeader = {
                type = "header",
                name = L["COLORS"],
                order = 3,
            },
            prefixColor = MakeStatusColorOption(L["PREFIX"], L["PREFIX_COLOR_DESC"], "prefix", self, 4),
            inProgressColor = MakeStatusColorOption(L["IN_PROGRESS"], L["IN_PROGRESS_COLOR_DESC"], "inProgress", self, 5),
            missingColor = MakeStatusColorOption(L["MISSING"], L["MISSING_COLOR_DESC"], "missing", self, 6),
            finishedColor = MakeStatusColorOption(L["FINISHED_COLOR"], L["FINISHED_COLOR_DESC"], "finished", self, 7),
            milestonePrefixColorRow = MakeMilestonePrefixColorProps(self, 8),
        }
    }
end

-- Display options: control which values to show and layout
function KeystonePolaris:GetDisplayOptions()
    local function IsMDTAvailable()
        if not MDT_FEATURES_ENABLED then return false end
        if C_AddOns and C_AddOns.IsAddOnLoaded then
            return C_AddOns.IsAddOnLoaded("MythicDungeonTools") or (_G.MDT ~= nil) or (_G.MethodDungeonTools ~= nil)
        end
        return (_G and (_G.MDT or _G.MethodDungeonTools))
    end
    return {
        name = L["DISPLAY"],
        type = "group",
        order = 1,
        args = {
            previewGroup = PreviewGroup(0.01),
            formatMode = {
                name = L["FORMAT_MODE"],
                desc = L["FORMAT_MODE_DESC"],
                type = "select",
                order = 2,
                width = "full",
                values = function()
                    local percentLabel = L["PERCENTAGE"]
                    local countLabel = L["COUNT"]
                    return { percent = percentLabel, count = countLabel }
                end,
                get = function()
                    return self.db.profile.general.mainDisplay.formatMode or "percent"
                end,
                set = function(_, value)
                    self.db.profile.general.mainDisplay.formatMode = value == "count" and "count" or "percent"
                    if self.UpdatePercentageText then self:UpdatePercentageText() end
                    if self.ApplyTextLayout then self:ApplyTextLayout() end
                    if self.AdjustDisplayFrameSize then self:AdjustDisplayFrameSize() end
                    RefreshPreviewWidget()
                end
            },
            requiredRow = ColumnRow(3, {
                name = L["SHOW_REQUIRED_PREFIX"],
                desc = L["SHOW_REQUIRED_PREFIX_DESC"],
                type = "toggle",
                get = function() return self.db.profile.general.mainDisplay.showRequiredText end,
                set = function(_, value)
                    self.db.profile.general.mainDisplay.showRequiredText = value
                    self:UpdatePercentageText()
                    RefreshPreviewWidget()
                end
            }, {
                name = L["PREFIX"],
                desc = L["REQUIRED_LABEL_DESC"],
                type = "input",
                get = function() return self.db.profile.general.mainDisplay.requiredLabel end,
                set = function(_, value)
                    local text = type(value) == "string" and value or ""
                    text = (text ~= "" and text) or L["REQUIRED_DEFAULT"]
                    self.db.profile.general.mainDisplay.requiredLabel = text
                    self:UpdatePercentageText()
                    RefreshPreviewWidget()
                end,
                disabled = function()
                    return not self.db.profile.general.mainDisplay.showRequiredText
                end
            }),
            sectionRequiredRow = ColumnRow(5, {
                name = L["SHOW_SECTION_REQUIRED_PREFIX"],
                desc = L["SHOW_SECTION_REQUIRED_PREFIX_DESC"],
                type = "toggle",
                get = function() return self.db.profile.general.mainDisplay.showSectionRequiredText end,
                set = function(_, value)
                    self.db.profile.general.mainDisplay.showSectionRequiredText = value
                    self:UpdatePercentageText()
                    RefreshPreviewWidget()
                end
            }, {
                name = L["PREFIX"],
                desc = L["SECTION_REQUIRED_LABEL_DESC"],
                type = "input",
                get = function() return self.db.profile.general.mainDisplay.sectionRequiredLabel end,
                set = function(_, value)
                    local text = type(value) == "string" and value or ""
                    text = (text ~= "" and text) or L["SECTION_REQUIRED_DEFAULT"]
                    self.db.profile.general.mainDisplay.sectionRequiredLabel = text
                    self:UpdatePercentageText()
                    RefreshPreviewWidget()
                end,
                disabled = function()
                    return not self.db.profile.general.mainDisplay.showSectionRequiredText
                end
            }),
            currentRow = ColumnRow(7, {
                name = L["SHOW_CURRENT_PERCENT"],
                desc = L["SHOW_CURRENT_PERCENT_DESC"],
                type = "toggle",
                get = function() return self.db.profile.general.mainDisplay.showCurrentPercent end,
                set = function(_, value)
                    self.db.profile.general.mainDisplay.showCurrentPercent = value
                    self:UpdatePercentageText()
                    RefreshPreviewWidget()
                end
            }, {
                name = L["PREFIX"],
                desc = L["CURRENT_LABEL_DESC"],
                type = "input",
                get = function() return self.db.profile.general.mainDisplay.currentLabel end,
                set = function(_, value)
                    local text = type(value) == "string" and value or ""
                    text = (text ~= "" and text) or L["CURRENT_DEFAULT"]
                    self.db.profile.general.mainDisplay.currentLabel = text
                    self:UpdatePercentageText()
                    RefreshPreviewWidget()
                end,
                disabled = function()
                    return not self.db.profile.general.mainDisplay.showCurrentPercent
                end
            }),
            showCurrentPullPercentLocked = {
                name = "|cff9d9d9d" .. L["SHOW_CURRENT_PULL_PERCENT"] .. "|r",
                desc = L["MDT_FEATURE_UNAVAILABLE"],
                type = "description",
                dialogControl = "InteractiveLabel",
                order = 12,
                width = 1.4,
                hidden = function() return MDT_FEATURES_ENABLED and IsMDTAvailable() end,
                image = "Interface\\PetBattles\\PetBattle-LockIcon",
                imageWidth = 20,
                imageHeight = 20,
                fontSize = "medium",
            },
            showCurrentPullPercent = {
                name = L["SHOW_CURRENT_PULL_PERCENT"],
                desc = L["SHOW_CURRENT_PULL_PERCENT_DESC"],
                type = "toggle",
                order = 12,
                width = 1.4,
                hidden = function() return (not MDT_FEATURES_ENABLED) or (not IsMDTAvailable()) end,
                get = function() return self.db.profile.general.mainDisplay.showCurrentPullPercent end,
                set = function(_, value)
                    self.db.profile.general.mainDisplay.showCurrentPullPercent = value
                    self:UpdatePercentageText()
                    RefreshPreviewWidget()
                end,
            },
            pullLabel = {
                name = L["PREFIX"],
                desc = L["PULL_LABEL_DESC"],
                type = "input",
                order = 13,
                width = 1,
                get = function() return self.db.profile.general.mainDisplay.pullLabel end,
                set = function(_, value)
                    local text = type(value) == "string" and value or ""
                    text = (text ~= "" and text) or L["PULL_DEFAULT"]
                    self.db.profile.general.mainDisplay.pullLabel = text
                    self:UpdatePercentageText()
                    RefreshPreviewWidget()
                end,
                hidden = function()
                    return not self.db.profile.general.mainDisplay.showCurrentPullPercent or not IsMDTAvailable()
                end
            },
            milestoneRow = ColumnRow(10, {
                name = L["SHOW_MILESTONES"],
                desc = L["SHOW_MILESTONES_DESC"],
                type = "toggle",
                get = function() return self.db.profile.general.mainDisplay.showMilestones ~= false end,
                set = function(_, value)
                    self.db.profile.general.mainDisplay.showMilestones = value and true or false
                    self:UpdatePercentageText()
                end
            }, {
                name = L["PREFIX"],
                desc = L["MILESTONE_DISPLAY_LABEL_DESC"],
                type = "input",
                get = function() return self.db.profile.general.mainDisplay.milestoneLabel or L["MILESTONE_DISPLAY_DEFAULT"] end,
                set = function(_, value)
                    local text = type(value) == "string" and value or ""
                    text = (text ~= "" and text) or L["MILESTONE_DISPLAY_DEFAULT"]
                    self.db.profile.general.mainDisplay.milestoneLabel = text
                    self:UpdatePercentageText()
                end,
                disabled = function()
                    return self.db.profile.general.mainDisplay.showMilestones == false
                end
            }),
            showProjectedLocked = {
                name = "|cff9d9d9d" .. L["SHOW_PROJECTED"] .. "|r",
                desc = L["MDT_FEATURE_UNAVAILABLE"],
                type = "description",
                dialogControl = "InteractiveLabel",
                order = 14,
                width = 1.6,
                hidden = function() return MDT_FEATURES_ENABLED and IsMDTAvailable() end,
                image = "Interface\\PetBattles\\PetBattle-LockIcon",
                imageWidth = 20,
                imageHeight = 20,
                fontSize = "medium",
            },
            showProjected = {
                name = L["SHOW_PROJECTED"],
                desc = L["SHOW_PROJECTED_DESC"],
                type = "toggle",
                order = 14,
                width = 1.6,
                hidden = function() return (not MDT_FEATURES_ENABLED) or (not IsMDTAvailable()) end,
                get = function() return self.db.profile.general.mainDisplay.showProjected end,
                set = function(_, value)
                    self.db.profile.general.mainDisplay.showProjected = value
                    if self.UpdatePercentageText then self:UpdatePercentageText() end
                    if self.ApplyTextLayout then self:ApplyTextLayout() end
                    if self.AdjustDisplayFrameSize then self:AdjustDisplayFrameSize() end
                    RefreshPreviewWidget()
                end,
            },
            multiLineRow = ColumnRow(9, {
                name = L["USE_MULTI_LINE_LAYOUT"],
                desc = L["USE_MULTI_LINE_LAYOUT_DESC"],
                type = "toggle",
                get = function() return self.db.profile.general.mainDisplay.multiLine end,
                set = function(_, value)
                    self.db.profile.general.mainDisplay.multiLine = value
                    if self.UpdatePercentageText then self:UpdatePercentageText() end
                    if self.ApplyTextLayout then self:ApplyTextLayout() end
                    if self.AdjustDisplayFrameSize then self:AdjustDisplayFrameSize() end
                    ACR:NotifyChange(AddOnName)
                    local function reapply()
                        if self.displayFrame and self.displayFrame.text then
                            if self.UpdatePercentageText then self:UpdatePercentageText() end
                            if self.ApplyTextLayout then self:ApplyTextLayout() end
                            if self.AdjustDisplayFrameSize then self:AdjustDisplayFrameSize() end
                            local t = self.displayFrame.text
                            t:SetText(t:GetText())
                        end
                    end
                    C_Timer.After(0.03, reapply)
                    C_Timer.After(0.08, reapply)
                    C_Timer.After(0.15, reapply)
                    RefreshPreviewWidget()
                end
            }, {
                name = L["SINGLE_LINE_SEPARATOR"],
                desc = L["SINGLE_LINE_SEPARATOR_DESC"],
                type = "input",
                get = function() return self.db.profile.general.mainDisplay.singleLineSeparator end,
                set = function(_, value)
                    self.db.profile.general.mainDisplay.singleLineSeparator = tostring(value or " | ")
                    self:UpdatePercentageText()
                    RefreshPreviewWidget()
                end,
                disabled = function()
                    return self.db.profile.general.mainDisplay.multiLine
                end
            }),
        }
    }
end

