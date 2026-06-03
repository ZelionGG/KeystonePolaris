local AddOnName, KeystonePolaris = ...;

local _G = _G;
local pairs, select = pairs, select
local format = string.format
local gsub = string.gsub
local strsplit = strsplit
local HideUIPanel = _G.HideUIPanel
local AceGUIWidgetLSMlists = _G.AceGUIWidgetLSMlists
local CALENDAR_WEEKDAY_NAMES = _G.CALENDAR_WEEKDAY_NAMES

-- Get localization table
local L = LibStub("AceLocale-3.0"):GetLocale(AddOnName, true)
local ACR = LibStub("AceConfigRegistry-3.0")

-- MDT integration unavailable due to Blizzard API changes in Midnight
local MDT_FEATURES_ENABLED = false
KeystonePolaris.mdtFeaturesEnabled = MDT_FEATURES_ENABLED

-- Shared preview scenario index (persists across Display and Appearance pages)
KeystonePolaris._previewScenario = 1

local function RefreshPreviewWidget()
    local previewWidget = KeystonePolaris._previewWidget
    if previewWidget and previewWidget.RefreshPreview then
        previewWidget:RefreshPreview()
    end

    local progressBarPreviewWidget = KeystonePolaris._progressBarPreviewWidget
    if progressBarPreviewWidget and progressBarPreviewWidget.RefreshPreview then
        progressBarPreviewWidget:RefreshPreview()
    end
end

local function PreviewScenarioValues()
    local scenarios = KeystonePolaris.PreviewScenarios
    if not scenarios then return {} end
    local vals = {}
    for i, s in ipairs(scenarios) do
        if not s.requiresMDT or KeystonePolaris.mdtFeaturesEnabled then
            vals[i] = s.name
        end
    end
    return vals
end

local function SetPreviewScenario(value)
    KeystonePolaris._previewScenario = value
    KeystonePolaris._testScenario = value
    if KeystonePolaris.UpdatePercentageText then KeystonePolaris:UpdatePercentageText() end
    if KeystonePolaris._progressBarPreview and KeystonePolaris.EnableProgressBarPreview then
        KeystonePolaris:EnableProgressBarPreview()
    end
    RefreshPreviewWidget()
    ACR:NotifyChange(AddOnName)
end

-- Progress bar width: store UI units (GetScreenWidth), show physical pixels on the slider.
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

local function PreviewScenarioDropdown(order)
    return {
        name = L["PREVIEW_SCENARIO"],
        type = "select",
        order = order,
        width = "full",
        values = PreviewScenarioValues,
        get = function() return KeystonePolaris._previewScenario or 1 end,
        set = function(_, value) SetPreviewScenario(value) end,
    }
end

local function PreviewGroup(order)
    return {
        type = "group",
        inline = true,
        name = "",
        order = order,
        args = {
            previewScenario = {
                name = L["PREVIEW_SCENARIO"],
                type = "select",
                order = 1,
                width = "full",
                values = PreviewScenarioValues,
                get = function() return KeystonePolaris._previewScenario or 1 end,
                set = function(_, value) SetPreviewScenario(value) end,
            },
            preview = {
                name = "",
                type = "select",
                dialogControl = "KeystonePolaris_Preview",
                order = 2,
                width = "full",
                values = PreviewScenarioValues,
                get = function() return KeystonePolaris._previewScenario or 1 end,
                set = function(_, value) SetPreviewScenario(value) end,
            },
        },
    }
end

local function ColumnRow(order, left, right, spacerWidth)
    left.order = 1
    left.width = left.width or 1.25
    right.order = 2
    right.width = right.width or 1.25
    return {
        type = "group", inline = true, name = "", order = order,
        args = {
            col1 = left,
            spacer = { name = " ", type = "description", order = 1.5, width = spacerWidth or 0.12 },
            col2 = right,
        }
    }
end

local function MakeStatusColorOption(name, desc, colorKey, self, order)
    return {
        name = name,
        desc = desc,
        type = "color",
        order = order,
        width = 1.25,
        get = function()
            local color = self.db.profile.color[colorKey]
            return color.r, color.g, color.b, color.a
        end,
        set = function(_, r, g, b, a)
            self.db.profile.color[colorKey] = { r = r, g = g, b = b, a = a }
            if self.UpdateColorCache then self:UpdateColorCache() end
            if self.UpdatePercentageText then self:UpdatePercentageText() end
            self:Refresh()
            RefreshPreviewWidget()
        end
    }
end

-- ---------------------------------------------------------------------------
-- Helper utilities
-- ---------------------------------------------------------------------------
-- Shallow-clone a table (one level only). Used for AceConfig dungeon groups so
-- each section keeps its own `order` while sharing nested `args` references.
-- Do not use WoW CopyTable here: it deep-copies nested tables, which breaks
-- live milestone add/remove updates in the options UI.
local function ShallowCloneTable(tbl)
    local t = {}
    for k, v in pairs(tbl) do t[k] = v end
    return t
end

-- Deep-clone nested tables (e.g. advanced defaults copied into saved variables).
local function CloneTable(tbl)
    if type(tbl) ~= "table" then return tbl end
    local t = {}
    for k, v in pairs(tbl) do
        if type(v) == "table" then
            t[k] = CloneTable(v)
        else
            t[k] = v
        end
    end
    return t
end

-- Helper to format date string "YYYY-MM-DD" to localized format or default
local function FormatSeasonDate(dateStr)
    if not dateStr then return "" end
    local year, month, day = strsplit("-", dateStr)
    if year and month and day then
         if L["%month%-%day%-%year%"] then
            local formatted = L["%month%-%day%-%year%"]
            formatted = gsub(formatted, "%%year%%", year)
            formatted = gsub(formatted, "%%month%%", month)
            formatted = gsub(formatted, "%%day%%", day)
            return formatted
         else
            return string.format("%s-%s-%s", year, month, day)
         end
    end
    return dateStr
end

-- Insert dungeon option groups into an AceConfig args table in alphabetical
-- order. Every option is cloned from `sharedOptions[key]`, placed after the
-- section headers (offset with `baseOrder`), and assigned its own `order` so
-- AceConfig displays them deterministically.
--   addon        : reference to KeystonePolaris for helper calls
--   dungeonKeys  : array of dungeon string keys (short names)
--   sharedOptions: table containing pre-built option groups for each dungeon
--   targetArgs   : the args table we are populating (e.g., dungeonArgs)
--   baseOrder    : numeric order to start from (usually 3)
local function InsertSortedDungeonOptions(addon, dungeonKeys, sharedOptions, targetArgs, baseOrder)
    local sortable = {}
    for _, key in ipairs(dungeonKeys) do
        local mapId = addon:GetDungeonIdByKey(key)
        local name = (mapId and select(1, C_ChallengeMode.GetMapUIInfo(mapId))) or key
        table.insert(sortable, { key = key, name = name })
    end
    table.sort(sortable, function(a, b) return a.name < b.name end)

    for idx, entry in ipairs(sortable) do
        local opt = ShallowCloneTable(sharedOptions[entry.key])
        opt.order = baseOrder + idx
        targetArgs[entry.key] = opt
    end
end

KeystonePolaris.defaults = {
    profile = {
        general = {
            fontSize = 12,
            textOpacity = 1,
            position = "CENTER",
            xOffset = 0,
            yOffset = 0,
            positioningDimBackground = false,
            positioningShowGrid = false,
            positioningGridSpacing = 60,
            informGroup = true,
            informChannel = "PARTY",
            showCompartmentIcon = true,
            showMinimapIcon = true,
            minimapAngle = 225,
            mobPercentagesMigrationVersion = "",
            advancedOptionsEnabled = false,
            lastSeasonCheck = "",
            lastVersionCheck = "",
            rolesEnabled = {
                LEADER = true,
                TANK = true,
                HEALER = true,
                DAMAGER = true
            },
            -- Main display content options
            mainDisplay = {
                showCurrentPercent = true,            -- Show overall current enemy forces percent
                showCurrentPullPercent = true,        -- Show current MDT pull percent (if MDT is available)
                multiLine = true,                     -- Display extras on new lines instead of a single line
                showRequiredText = true,              -- Show the required/remaining text base
                requiredLabel = L["REQUIRED_DEFAULT"], -- Label for the required base value when numeric
                showSectionRequiredText = false,       -- Show the required/remaining text base
                sectionRequiredLabel = L["SECTION_REQUIRED_DEFAULT"], -- Label for the required base value when numeric
                currentLabel = L["CURRENT_DEFAULT"],   -- Label for current percent
                pullLabel = L["PULL_DEFAULT"],         -- Label for current pull percent
                showMilestones = true,                 -- Show milestone supplementary text and logic
                milestoneLabel = L["MILESTONE_DISPLAY_DEFAULT"], -- Label for milestone supplementary text
                formatMode = "percent",               -- Display format: "percent" or "count"
                singleLineSeparator = " | ",           -- Separator for single-line layout
                textAlign = "CENTER",                  -- Horizontal font alignment: LEFT, CENTER, RIGHT
                showProjected = false                   -- Append projected values next to Current/Required
            }
        },
        text = {font = "Friz Quadrata TT"},
        color = {
            inProgress = {r = 1, g = 1, b = 1, a = 1},
            finished = {r = 0, g = 1, b = 0, a = 1},
            missing = {r = 1, g = 0, b = 0, a = 1},
            prefix = {r = 1, g = 0.7960784, b = 0.2, a = 1}
        },
        advanced = {},
        progressBar = {
            enabled = true,
            width = 250,
            height = 20,
            position = "CENTER",
            xOffset = 0,
            yOffset = 350,
            direction = "LEFT_TO_RIGHT",
            barTexture = "Blizzard Raid Bar",
            useGradient = false,
            gradientStartColor = { r = 1, g = 1, b = 1, a = 1 },
            gradientEndColor = { r = 0, g = 1, b = 0, a = 1 },
            overrideColors = false,
            completedColor = { r = 0, g = 1, b = 0, a = 1 },
            inProgressColor = { r = 1, g = 1, b = 1, a = 1 },
            missingColor = { r = 1, g = 0, b = 0, a = 1 },
            backgroundColor = { r = 0, g = 0, b = 0, a = 0.7 },
            borderStyle = "NONE",
            borderTexture = "Blizzard Dialog Gold",
            borderColor = { r = 0, g = 0, b = 0, a = 1 },
            borderSize = 2,
            borderInsets = 1,
            tickColor = { r = 1, g = 1, b = 1, a = 1 },
            tickWidth = 2,
            tickOverflow = 2,
            showCallout = true,
            calloutPosition = "ABOVE",
            calloutFont = "Friz Quadrata TT",
            calloutFontSize = 10,
            calloutTextColor = { r = 1, g = 0.82, b = 0, a = 1 },
            calloutBackgroundColor = { r = 0, g = 0, b = 0, a = 0.8 },
        },
    }
}

KeystonePolaris.defaults.profile.groupReminder = {
    enabled = true,
    showPopup = true,
    showChat = true,
    showPopupWhenGroupIsFull = false,
    suppressQuickJoinToast = false,
    showDungeonName = true,
    showGroupName = true,
    showGroupDescription = true,
    showAppliedRole = true,
    lastReminder = nil,
    popupXOffset = 0,
    popupYOffset = 0,
}

local expansions = KeystonePolaris.Expansions

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

function KeystonePolaris:GetInformGroupOptions()
    return {
        name = L["INFORM_GROUP"],
        type = "group",
        order = 3,
        args = {
            informRow = ColumnRow(1, {
                name = L["SHOW_INFORM_GROUP_BUTTON"],
                desc = L["SHOW_INFORM_GROUP_BUTTON_DESC"],
                type = "toggle",
                get = function()
                    return self.db.profile.general.informGroup
                end,
                set = function(_, value)
                    self.db.profile.general.informGroup = value
                end
            }, {
                name = L["MESSAGE_CHANNEL"],
                desc = L["MESSAGE_CHANNEL_DESC"],
                type = "select",
                values = {PARTY = L["PARTY"], SAY = L["SAY"], YELL = L["YELL"]},
                disabled = function()
                    return not self.db.profile.general.informGroup
                end,
                get = function()
                    return self.db.profile.general.informChannel
                end,
                set = function(_, value)
                    self.db.profile.general.informChannel = value
                end
            }),
            rolesHeader = {
                type = "header",
                name = "",
                order = 3,
            },
            rolesEnabled = {
                name = L["ROLES_ENABLED"],
                desc = L["ROLES_ENABLED_DESC"],
                type = "multiselect",
                order = 4,
                values = {
                    LEADER = LEADER,
                    TANK = TANK,
                    HEALER = HEALER,
                    DAMAGER = DAMAGER
                },
                get = function(_, key)
                    return self.db.profile.general.rolesEnabled[key] or false
                end,
                set = function(_, key, state)
                    if state then
                        self.db.profile.general.rolesEnabled[key] = true
                    else
                        self.db.profile.general.rolesEnabled[key] = false
                    end
                    self:Refresh()
                end
            },
            advancedHeader = {
                type = "header",
                name = "",
                order = 5,
            },
            enabled = {
                name = L["ENABLE_ADVANCED_OPTIONS"],
                desc = L["ADVANCED_OPTIONS_DESC"],
                type = "toggle",
                width = "full",
                order = 6,
                get = function()
                    return self.db.profile.general.advancedOptionsEnabled
                end,
                set = function(_, value)
                    self.db.profile.general.advancedOptionsEnabled = value
                    self:UpdateDungeonData()
                end
            }
        }
    }
end

function KeystonePolaris:GetInterfaceOptions()
    return {
        name = L["INTERFACE"],
        type = "group",
        order = 4,
        args = {
            iconsRow = ColumnRow(1, {
                type = "toggle",
                name = L["SHOW_COMPARTMENT_ICON"],
                get = function()
                    return self.db.profile.general.showCompartmentIcon
                end,
                set = function(_, value)
                    self.db.profile.general.showCompartmentIcon = not not value
                    self:UpdateCompartmentIconVisibility()
                end,
            }, {
                type = "toggle",
                name = L["SHOW_MINIMAP_ICON"],
                get = function()
                    return self.db.profile.general.showMinimapIcon
                end,
                set = function(_, value)
                    self.db.profile.general.showMinimapIcon = not not value
                    self:UpdateMinimapIconVisibility()
                end,
            }),
            commandsHeader = {
                order = 3,
                type = "header",
                name = L["COMMANDS_HEADER"] or "Commands",
            },
            commandsDescription = {
                order = 4,
                type = "description",
                name = function()
                    return self:ColorizeCommands(L["COMMANDS_HELP_DESC"] or "")
                end,
                fontSize = "medium",
            },
        }
    }
end

function KeystonePolaris:GetAdvancedOptions()
    -- Helper function to get dungeon name with icon
    local function GetDungeonNameWithIcon(dungeonKey)
        local mapId = self:GetDungeonIdByKey(dungeonKey)

        local name, texture
        if mapId then
            name = select(1, C_ChallengeMode.GetMapUIInfo(mapId))
            texture = select(4, C_ChallengeMode.GetMapUIInfo(mapId))
        end

        -- Retrieve manual display name
        local manualName
        for _, expansion in ipairs(expansions) do
            local names = self[expansion.id .. "_DUNGEON_NAMES"]
            if names and names[dungeonKey] then
                manualName = names[dungeonKey]
                break
            end
        end

        -- Fallbacks
        local icon = texture or "Interface\\Icons\\INV_Misc_QuestionMark"
        local displayName = name or manualName or dungeonKey or "Unknown"

        return '|T' .. icon .. ":20:20:0:0|t " .. displayName
    end

    -- Helper function to format dungeon text
    local function FormatDungeonText(dungeonKey, defaults)
        local text = ""
        if defaults then
            text = text .. "|cffffd700" .. GetDungeonNameWithIcon(dungeonKey) ..
                       "|r:\n"

            local bossNum = 1
            while defaults["Boss" .. self:GetBossNumberString(bossNum)] do
                local bossKey = "Boss" .. self:GetBossNumberString(bossNum)
                local informKey = bossKey .. "Inform"
                local bossName = self:GetBossName(dungeonKey, bossNum)

                text = text ..
                           string.format(
                               "  %s: |cff40E0D0%.2f%%|r - " ..
                                   L["SHOW_INFORM_GROUP_BUTTON"] .. ": %s\n",
                               bossName,
                               defaults[bossKey] or 0,
                               defaults[informKey] and '|cff00ff00' .. L["YES"] ..
                                   '|r' or '|cffff0000' .. L["NO"] .. '|r')
                bossNum = bossNum + 1
            end

            -- Show logical boss order if available
            local bossOrder = defaults.bossOrder
            if type(bossOrder) == "table" and next(bossOrder) ~= nil then
                -- Extra blank line between last boss percentage and order header
                text = text .. "\n"
                -- Collect boss names in logical section order
                local names = {}
                local numSections = #bossOrder
                for section = 1, numSections do
                    local idx = bossOrder[section]
                    if type(idx) == "number" then
                        local bossName = self:GetBossName(dungeonKey, idx)
                        table.insert(names, bossName)
                    end
                end

                if #names > 0 then
                    -- Orange title and numbered list (1) BossName, 2) BossName, ...)
                    local orderTitle = "|cffffa500" .. L["BOSS_ORDER"] .. "|r"
                    text = text .. "  " .. orderTitle .. ":\n"

                    for i, bossName in ipairs(names) do
                        text = text .. string.format("    %d) %s\n", i, bossName)
                    end

                    text = text .. "\n"
                else
                    text = text .. "\n"
                end
            else
                text = text .. "\n"
            end
        end
        return text
    end

    -- Helper: days until a YYYY-MM-DD or YYYY-MM-DD HH:MM date (nil if invalid)
    local function GetDaysUntil(dateStr)
        if not dateStr or dateStr == "" then return nil end
        local y, m, d, h, min = dateStr:match("^(%d%d%d%d)%-(%d%d)%-(%d%d)%s+(%d%d):(%d%d)$")
        local hasTime = y ~= nil
        if not hasTime then
            y, m, d = dateStr:match("^(%d%d%d%d)%-(%d%d)%-(%d%d)$")
        end
        local year, month, day = tonumber(y), tonumber(m), tonumber(d)
        if not year or not month or not day then return nil end

        local target
        local current
        if hasTime then
            local hour, minute = tonumber(h), tonumber(min)
            if not hour or not minute then return nil end
            target = time({year = year, month = month, day = day, hour = hour, min = minute})
            current = time()
            if target < current then
                return -1
            end
        else
            local currentDate = date("%Y-%m-%d")
            local cYear, cMonth, cDay = strsplit("-", currentDate)
            cYear, cMonth, cDay = tonumber(cYear), tonumber(cMonth), tonumber(cDay)
            if not cYear or not cMonth or not cDay then return nil end
            target = time({year = year, month = month, day = day, hour = 12})
            current = time({year = cYear, month = cMonth, day = cDay, hour = 12})
        end

        return math.floor((target - current) / 86400)
    end

    local function GetSeasonCountdownText(daysUntil, prefixKey, withIcon, targetDate)
        if not daysUntil or daysUntil < 0 then return nil end
        local iconPrefix = withIcon and
                               "|TInterface\\OptionsFrame\\UI-OptionsFrame-NewFeatureIcon:16:16:0:0|t " or
                               ""
        if daysUntil <= 7 then
            local weekdaySuffix = ""
            if targetDate then
                local dateOnly = targetDate:match("^(%d%d%d%d%-%d%d%-%d%d)") or targetDate
                local year, month, day = strsplit("-", dateOnly)
                year, month, day = tonumber(year), tonumber(month), tonumber(day)
                if year and month and day then
                    local target = time({year = year, month = month, day = day, hour = 12})
                    local wday = date("*t", target).wday
                    local weekdayName = CALENDAR_WEEKDAY_NAMES and
                                            CALENDAR_WEEKDAY_NAMES[wday]
                    if weekdayName then
                        local weekdayFormat = L["WEEKDAY_NEXT_FORMAT"]
                        weekdaySuffix = " " .. weekdayFormat:format(weekdayName)
                    end
                end
            end
            if daysUntil == 1 then
                return iconPrefix .. L[prefixKey .. "_TOMORROW"]
            end
            local dayText = L[prefixKey .. "_DAYS"]:format(daysUntil)
            return iconPrefix .. dayText .. weekdaySuffix
        end
        if daysUntil <= 14 then
            local weeks = math.ceil(daysUntil / 7)
            local weekKey = weeks == 1 and "_WEEK" or "_WEEKS"
            local weekText = L[prefixKey .. weekKey]
            if weeks ~= 1 then
                weekText = weekText:format(weeks)
            end
            return iconPrefix .. weekText
        end
        if daysUntil <= 30 then
            return iconPrefix .. L[prefixKey .. "_ONE_MONTH"]
        end
        return nil
    end

    -- Create shared dungeon options
    local sharedDungeonOptions = {}
    for _, expansion in ipairs(expansions) do
        local dungeonIds = self[expansion.id .. "_DUNGEON_IDS"]
        if dungeonIds then
            for dungeonKey, _ in pairs(dungeonIds) do
                sharedDungeonOptions[dungeonKey] =
                    self:CreateDungeonOptions(dungeonKey, 0)
            end
        end
    end

    -- Generic builder for section args (used for seasons and expansions)
    local function CreateGenericSectionArgs(sectionLabel, dungeonKeys, dungeonFilter, getDefaultsFn, headerTitle, extraDisclaimerText)
        local args = {
            title = {
                order = 0,
                type = "description",
                fontSize = "large",
                name = (headerTitle or ("|cffeda55f" .. sectionLabel .. "|r")) .. "\n"
            },
            seasonAlert = extraDisclaimerText and {
                order = 0.1,
                type = "description",
                fontSize = "medium",
                name = extraDisclaimerText or "",
            } or nil,
            separatorTitle = {
                order = 0.2,
                type = "header",
                name = "",
            },
            disclaimer = {
                order = 0.5,
                type = "description",
                fontSize = "medium",
                name = L["ROUTES_DISCLAIMER"],
            },
            separator = {order = 1, type = "header", name = ""},
            export = {
                order = 1.25,
                type = "execute",
                name = L["EXPORT_SECTION"],
                desc = (L["EXPORT_SECTION_DESC"]):format(sectionLabel),
                func = function()
                    local addon = KeystonePolaris
                    local sectionData = {}
                    for _, dungeonKey in ipairs(dungeonKeys) do
                        if addon.db and addon.db.profile and addon.db.profile.advanced and addon.db.profile.advanced[dungeonKey] then
                            sectionData[dungeonKey] = addon.db.profile.advanced[dungeonKey]
                        end
                    end
                    addon:ExportDungeonSettings(sectionData, "section", sectionLabel)
                end
            },
            import = {
                order = 1.5,
                type = "execute",
                name = L["IMPORT_SECTION"],
                desc = (L["IMPORT_SECTION_DESC"]):format(sectionLabel),
                func = function()
                    KeystonePolaris:ShowImportDialog(sectionLabel, dungeonFilter)
                end
            },
            separatorDefaultPercentages = {
                order = 2,
                type = "header",
                name = L["DEFAULT_PERCENTAGES"],
            },
            defaultPercentages = {
                order = 2.5,
                type = "description",
                fontSize = "medium",
                name = L["DEFAULT_PERCENTAGES_DESC"],
            },
            separatorDefaultPercentagesText = {
                order = 2.8,
                type = "header",
                name = "",
            },
            defaultPercentagesText = {
                order = 3,
                type = "description",
                fontSize = "medium",
                name = function()
                    local text = ""
                    for _, dungeonKey in ipairs(dungeonKeys) do
                        local defaults = getDefaultsFn and getDefaultsFn(dungeonKey) or nil
                        text = text .. FormatDungeonText(dungeonKey, defaults)
                    end
                    return text
                end
            }
        }

        -- Add per-dungeon options (alphabetical by localized name)
        -- Start at order 4 to come after the defaults header/description/text
        InsertSortedDungeonOptions(self, dungeonKeys, sharedDungeonOptions, args, 4)
        return args
    end

    -- Create current season options
    local currentSeasonDungeons = {}
    local currentSeasonTitle
    local currentSeasonListTitle
    local currentSeasonAlertText

    -- Get the current date
    local currentDate = date("%Y-%m-%d")

    -- Resolve the current season based on start/end dates
    local currentSeasonId, currentSeasonStart, currentSeasonEnd =
        self:GetSeasonByDate(currentDate)

    if currentSeasonId then
        local seasonDungeonsTabName = currentSeasonId .. "_DUNGEONS"
        local seasonDungeons = self[seasonDungeonsTabName]

        if seasonDungeons then
            for _, expansion in ipairs(expansions) do
                local dungeonIds = self[expansion.id .. "_DUNGEON_IDS"]
                if dungeonIds then
                    for dungeonKey, dungeonId in pairs(dungeonIds) do
                        if seasonDungeons[dungeonId] then
                            table.insert(currentSeasonDungeons,
                                         {key = dungeonKey, id = dungeonId})
                        end
                    end
                end
            end
        end
    end

    -- Sort dungeons alphabetically by their localized names
    table.sort(currentSeasonDungeons, function(a, b)
        local mapIdA = a.id or self:GetDungeonIdByKey(a.key)
        local mapIdB = b.id or self:GetDungeonIdByKey(b.key)

        local nameA
        if mapIdA then nameA = select(1, C_ChallengeMode.GetMapUIInfo(mapIdA)) end
        nameA = nameA or a.key

        local nameB
        if mapIdB then nameB = select(1, C_ChallengeMode.GetMapUIInfo(mapIdB)) end
        nameB = nameB or b.key

        return nameA < nameB
    end)

    -- Create current season dungeon args (using generic builder)
    local dungeonArgs
    do
        local keys = {}
        local filter = {}
        for _, d in ipairs(currentSeasonDungeons) do
            table.insert(keys, d.key)
            filter[d.key] = true
        end

        local function getDefaultsFn(dungeonKey)
            for _, expansion in ipairs(expansions) do
                local ids = self[expansion.id .. "_DUNGEON_IDS"]
                if ids and ids[dungeonKey] then
                    local defaults = self[expansion.id .. "_DEFAULTS"]
                    return defaults and defaults[dungeonKey] or nil
                end
            end
            return nil
        end

        local daysUntilEnd = currentSeasonEnd and GetDaysUntil(currentSeasonEnd)
        local countdownText = GetSeasonCountdownText(daysUntilEnd, "SEASON_ENDS_IN", true, currentSeasonEnd)
        local hasEndSoon = countdownText ~= nil
        currentSeasonTitle = "|cff40E0D0" .. L["CURRENT_SEASON"] .. "|r - |cffbbbbbb" .. FormatSeasonDate(currentSeasonStart)
        if currentSeasonEnd and currentSeasonEnd ~= "" then
            currentSeasonTitle = currentSeasonTitle .. " -> " .. FormatSeasonDate(currentSeasonEnd)
        end
        currentSeasonTitle = currentSeasonTitle .. "|r"
        currentSeasonListTitle = currentSeasonTitle
        if hasEndSoon then
            currentSeasonListTitle = "|TInterface\\OptionsFrame\\UI-OptionsFrame-NewFeatureIcon:16:16:0:0|t " ..
                currentSeasonTitle
            currentSeasonAlertText = countdownText
        end
        dungeonArgs = CreateGenericSectionArgs(L["CURRENT_SEASON"], keys, filter, getDefaultsFn, currentSeasonTitle, currentSeasonAlertText)
    end

    -- Create next season dungeon args
    local nextSeasonDungeons = {}
    local nextSeasonTitle
    local nextSeasonListTitle

    -- Find the next season (first season that starts after current date)
    local _, _, _, nextSeasonId, nextSeasonDate = self:GetSeasonByDate(currentDate)

    if nextSeasonId then
        local nextSeasonDungeonsTabName = nextSeasonId .. "_DUNGEONS"
        local nextSeasonDungeonsTable = self[nextSeasonDungeonsTabName]

        if nextSeasonDungeonsTable then
            for _, expansion in ipairs(expansions) do
                local dungeonIds = self[expansion.id .. "_DUNGEON_IDS"]
                if dungeonIds then
                    for dungeonKey, dungeonId in pairs(dungeonIds) do
                        if nextSeasonDungeonsTable[dungeonId] then
                            table.insert(nextSeasonDungeons,
                                         {key = dungeonKey, id = dungeonId})
                        end
                    end
                end
            end
        end
    end

    -- Sort dungeons alphabetically by their localized names
    table.sort(nextSeasonDungeons, function(a, b)
        local mapIdA = a.id or self:GetDungeonIdByKey(a.key)
        local mapIdB = b.id or self:GetDungeonIdByKey(b.key)

        local nameA
        if mapIdA then nameA = select(1, C_ChallengeMode.GetMapUIInfo(mapIdA)) end
        nameA = nameA or a.key

        local nameB
        if mapIdB then nameB = select(1, C_ChallengeMode.GetMapUIInfo(mapIdB)) end
        nameB = nameB or b.key

        return nameA < nameB
    end)

    -- Create next season dungeon args (using generic builder)
    local nextSeasonDungeonArgs
    do
        local keys = {}
        local filter = {}
        for _, d in ipairs(nextSeasonDungeons) do
            table.insert(keys, d.key)
            filter[d.key] = true
        end

        local function getDefaultsFn(dungeonKey)
            for _, expansion in ipairs(expansions) do
                local ids = self[expansion.id .. "_DUNGEON_IDS"]
                if ids and ids[dungeonKey] then
                    local defaults = self[expansion.id .. "_DEFAULTS"]
                    return defaults and defaults[dungeonKey] or nil
                end
            end
            return nil
        end

        nextSeasonTitle = "|cffff5733" .. L["NEXT_SEASON"] .. "|r - |cffbbbbbb" .. FormatSeasonDate(nextSeasonDate)
        local nextSeasonAlertText
        local nextSeasonEnd
        if nextSeasonId then
            local nextSeasonTable = self[nextSeasonId .. "_DUNGEONS"]
            if nextSeasonTable and nextSeasonTable.end_date then
                local portal = C_CVar.GetCVar("portal")
                if type(nextSeasonTable.end_date) == "table" then
                    nextSeasonEnd = nextSeasonTable.end_date[portal] or
                                    nextSeasonTable.end_date.default or
                                    nextSeasonTable.end_date.US or
                                    nextSeasonTable.end_date.EU
                else
                    nextSeasonEnd = nextSeasonTable.end_date
                end
            end
        end
        if nextSeasonEnd and nextSeasonEnd ~= "" then
            nextSeasonTitle = nextSeasonTitle .. " -> " .. FormatSeasonDate(nextSeasonEnd)
        end
        nextSeasonTitle = nextSeasonTitle .. "|r"
        local nextSeasonDaysUntilStart = nextSeasonDate and GetDaysUntil(nextSeasonDate)
        nextSeasonAlertText = GetSeasonCountdownText(nextSeasonDaysUntilStart, "SEASON_STARTS_IN", true, nextSeasonDate)
        nextSeasonListTitle = nextSeasonTitle
        if nextSeasonAlertText then
            nextSeasonListTitle = "|TInterface\\OptionsFrame\\UI-OptionsFrame-NewFeatureIcon:16:16:0:0|t " ..
                nextSeasonTitle
        end
        nextSeasonDungeonArgs = CreateGenericSectionArgs(L["NEXT_SEASON"], keys, filter, getDefaultsFn, nextSeasonTitle, nextSeasonAlertText)
    end

    -- Create expansion sections
    local args = {
        disclaimer = {
            order = 0,
            type = "description",
            fontSize = "medium",
            name = L["ROUTES_DISCLAIMER"],
        },
        separator = {
            order = 1,
            type = "header",
            name = "",
        },
        resetAll = {
            order = 2,
            type = "execute",
            name = L["RESET_ALL_DUNGEONS"],
            desc = L["RESET_ALL_DUNGEONS_DESC"],
            confirm = true,
            confirmText = L["RESET_ALL_DUNGEONS_CONFIRM"],
            func = function()
                -- Reset all dungeons to their defaults
                self:ResetAllDungeons()
            end
        },
        exportAllDungeons = {
            order = 3,
            type = "execute",
            name = L["EXPORT_ALL_DUNGEONS"],
            desc = L["EXPORT_ALL_DUNGEONS_DESC"],
            func = function()
                local addon = KeystonePolaris

                -- Collect all dungeon data
                local allDungeonData = {}
                for _, expansion in ipairs(expansions) do
                    if addon.db.profile.advanced then
                        for dungeonKey, _ in pairs(addon[expansion.id .. "_DUNGEON_IDS"] or {}) do
                            if addon.db.profile.advanced[dungeonKey] then
                                allDungeonData[dungeonKey] = addon.db.profile.advanced[dungeonKey]
                            end
                        end
                    end
                end
                addon:ExportDungeonSettings(allDungeonData, "all_dungeons")
            end
        },
        importAllDungeons = {
            order = 3.5,
            type = "execute",
            name = L["IMPORT_ALL_DUNGEONS"],
            desc = L["IMPORT_ALL_DUNGEONS_DESC"],
            func = function()
                KeystonePolaris:ShowImportDialog(nil)
            end
        }
    }

    -- Only add current season section if a current season exists and has dungeons
    if currentSeasonId and #currentSeasonDungeons > 0 then
        args.dungeons = {
            name = currentSeasonListTitle,
            type = "group",
            childGroups = "tree",
            order = 5,
            args = dungeonArgs
        }
    end

    -- Only add next season section if there are next season dungeons
    if nextSeasonId and #nextSeasonDungeons > 0 then
        args.nextseason = {
            name = nextSeasonListTitle,
            type = "group",
            childGroups = "tree",
            order = 4,
            args = nextSeasonDungeonArgs
        }
    end

    -- Helper to add days to a YYYY-MM-DD string
    local function AddDays(dateStr, days)
        if not dateStr or days == 0 then return dateStr end
        local year, month, day = strsplit("-", dateStr)
        year, month, day = tonumber(year), tonumber(month), tonumber(day)
        if not year or not month or not day then return dateStr end

        -- Convert to timestamp, add seconds, convert back
        -- Note: os.time takes a table. Basic implementation for simple date math.
        local time = time({year=year, month=month, day=day, hour=12}) -- noon to avoid DST issues
        time = time + (days * 86400)
        return date("%Y-%m-%d", time)
    end

    -- Helper to create a remix section
    local function HandleRemixSection(_, data, _)
        -- Collect dungeon keys
        local remixDungeons = {}
        for id, enabled in pairs(data) do
            if id ~= "expansion" and id ~= "start_date" and id ~= "end_date" and enabled then
                    local dungeonKey = self:GetDungeonKeyById(id)
                    if dungeonKey then
                        table.insert(remixDungeons, {key = dungeonKey, id = id})
                    end
            end
        end

        -- Sort dungeons alphabetically by their localized names
        table.sort(remixDungeons, function(a, b)
            local mapIdA = a.id or self:GetDungeonIdByKey(a.key)
            local mapIdB = b.id or self:GetDungeonIdByKey(b.key)

            local nameA
            if mapIdA then nameA = select(1, C_ChallengeMode.GetMapUIInfo(mapIdA)) end
            nameA = nameA or a.key

            local nameB
            if mapIdB then nameB = select(1, C_ChallengeMode.GetMapUIInfo(mapIdB)) end
            nameB = nameB or b.key

            return nameA < nameB
        end)

        local keys = {}
        for _, d in ipairs(remixDungeons) do
                table.insert(keys, d.key)
        end

        -- Handle dates with region offset
        local eDate = data.end_date

        -- Add +1 day for non-US regions if dates are present
        local portal = C_CVar.GetCVar("portal")
        local eDateFromTable = false
        if type(eDate) == "table" then
            eDate = eDate[portal] or eDate.default or eDate.US or eDate.EU
            eDateFromTable = true
        end
        if portal ~= "US" then
            if eDate and eDate ~= "" and not eDateFromTable then
                eDate = AddDays(eDate, 1)
            end
        end

        local daysUntilEnd
        if eDate and eDate ~= "" then
            daysUntilEnd = GetDaysUntil(eDate)
            if daysUntilEnd and daysUntilEnd < 0 then
                return
            end
        end

        -- Add dates to title if available
    end

    -- Create remix season sections
    for key, data in pairs(self) do
        if type(key) == "string" and key:match("_DUNGEONS$") and type(data) == "table" and rawget(data, "expansion") then
            HandleRemixSection(key, data, args)
        end
    end

    -- Create expansion sections
    for _, expansion in ipairs(expansions) do
        local sectionKey = expansion.id:lower()
        local dungeonIds = self[expansion.id .. "_DUNGEON_IDS"]
        local defaults = self[expansion.id .. "_DEFAULTS"]
        local keys = {}
        local filter = {}
        if dungeonIds then
            for dungeonKey, _ in pairs(dungeonIds) do
                table.insert(keys, dungeonKey)
                filter[dungeonKey] = true
            end
        end

        local function getDefaultsFn(dungeonKey)
            return defaults and defaults[dungeonKey] or nil
        end

        local expansionTitle = "|cffffffff" .. L[expansion.name] .. "|r"
        args[sectionKey] = {
            name = expansionTitle,
            type = "group",
            childGroups = "tree",
            order = expansion.order + 4, -- Shift expansion orders to after next season
            args = CreateGenericSectionArgs(L[expansion.name], keys, filter, getDefaultsFn, expansionTitle)
        }
    end
    return {
        name = L["ADVANCED_SETTINGS"],
        type = "group",
        childGroups = "tree",
        order = 5,
        args = args
    }
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
                        width = 1.5,
                        get = function() return self:GetProgressBarValue("enabled") end,
                        set = function(_, value)
                            self.db.profile.progressBar.enabled = value
                            if self.UpdateProgressBar then self:UpdateProgressBar() end
                        end,
                    }, {
                        name = L["SHOW_ANCHOR"],
                        type = "execute",
                        width = 1,
                        func = function()
                            HideUIPanel(SettingsPanel)
                            if self.EnterPositioningMode then
                                self:EnterPositioningMode()
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
                            if self.RefreshProgressBar then self:RefreshProgressBar() end
                        end,
                    }, {
                        name = L["PROGRESS_BAR_HEIGHT"],
                        type = "range",
                        min = 8, max = 60, step = 1,
                        get = function() return self.db.profile.progressBar.height end,
                        set = function(_, value)
                            self.db.profile.progressBar.height = value
                            if self.RefreshProgressBar then self:RefreshProgressBar() end
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
                            if self.RefreshProgressBar then self:RefreshProgressBar() end
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
                            if self.RefreshProgressBar then self:RefreshProgressBar() end
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
                            if self.RefreshProgressBar then self:RefreshProgressBar() end
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
                        width = 1.5,
                        get = function() return self.db.profile.progressBar.barTexture end,
                        set = function(_, value)
                            self.db.profile.progressBar.barTexture = value
                            if self.RefreshProgressBar then self:RefreshProgressBar() end
                        end,
                    }, {
                        name = L["PROGRESS_BAR_BG_ALPHA"],
                        type = "range",
                        min = 0, max = 1, step = 0.05,
                        isPercent = true,
                        width = 1,
                        get = function() return self.db.profile.progressBar.backgroundColor.a or 0.7 end,
                        set = function(_, value)
                            self.db.profile.progressBar.backgroundColor.a = value
                            if self.RefreshProgressBar then self:RefreshProgressBar() end
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
                            local alpha = self.db.profile.progressBar.backgroundColor.a or 0.7
                            self.db.profile.progressBar.backgroundColor = { r = r, g = g, b = b, a = alpha }
                            if self.RefreshProgressBar then self:RefreshProgressBar() end
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
                            if self.RefreshProgressBar then self:RefreshProgressBar() end
                            ACR:NotifyChange(AddOnName)
                        end,
                    },
                    gradientColorRow = ColumnRow(3.6, {
                        name = L["PROGRESS_BAR_GRADIENT_START_COLOR"],
                        type = "color",
                        width = 1,
                        hasAlpha = true,
                        hidden = function() return not self.db.profile.progressBar.useGradient end,
                        get = function()
                            local c = self.db.profile.progressBar.gradientStartColor
                            return c.r, c.g, c.b, c.a
                        end,
                        set = function(_, r, g, b, a)
                            self.db.profile.progressBar.gradientStartColor = { r = r, g = g, b = b, a = a }
                            if self.RefreshProgressBar then self:RefreshProgressBar() end
                        end,
                    }, {
                        name = L["PROGRESS_BAR_GRADIENT_END_COLOR"],
                        type = "color",
                        width = 1,
                        hasAlpha = true,
                        hidden = function() return not self.db.profile.progressBar.useGradient end,
                        get = function()
                            local c = self.db.profile.progressBar.gradientEndColor
                            return c.r, c.g, c.b, c.a
                        end,
                        set = function(_, r, g, b, a)
                            self.db.profile.progressBar.gradientEndColor = { r = r, g = g, b = b, a = a }
                            if self.RefreshProgressBar then self:RefreshProgressBar() end
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
                            if self.RefreshProgressBar then self:RefreshProgressBar() end
                            ACR:NotifyChange(AddOnName)
                        end,
                    },
                    completedColor = {
                        name = L["PROGRESS_BAR_COMPLETED_COLOR"],
                        type = "color",
                        order = 4.5,
                        hasAlpha = true,
                        width = "full",
                        hidden = function()
                            local pb = self.db.profile.progressBar
                            return not pb.overrideColors or pb.useGradient
                        end,
                        get = function()
                            local c = self.db.profile.progressBar.completedColor
                            return c.r, c.g, c.b, c.a
                        end,
                        set = function(_, r, g, b, a)
                            self.db.profile.progressBar.completedColor = { r = r, g = g, b = b, a = a }
                            if self.RefreshProgressBar then self:RefreshProgressBar() end
                        end,
                    },
                    inProgressColor = {
                        name = L["PROGRESS_BAR_IN_PROGRESS_COLOR"],
                        type = "color",
                        order = 5,
                        hasAlpha = true,
                        hidden = function()
                            local pb = self.db.profile.progressBar
                            return not pb.overrideColors
                        end,
                        get = function()
                            local c = self.db.profile.progressBar.inProgressColor
                            return c.r, c.g, c.b, c.a
                        end,
                        set = function(_, r, g, b, a)
                            self.db.profile.progressBar.inProgressColor = { r = r, g = g, b = b, a = a }
                            if self.RefreshProgressBar then self:RefreshProgressBar() end
                        end,
                    },
                    missingColor = {
                        name = L["PROGRESS_BAR_MISSING_COLOR"],
                        type = "color",
                        order = 6,
                        hasAlpha = true,
                        hidden = function() return not self.db.profile.progressBar.overrideColors end,
                        get = function()
                            local c = self.db.profile.progressBar.missingColor
                            return c.r, c.g, c.b, c.a
                        end,
                        set = function(_, r, g, b, a)
                            self.db.profile.progressBar.missingColor = { r = r, g = g, b = b, a = a }
                            if self.RefreshProgressBar then self:RefreshProgressBar() end
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
                            if self.RefreshProgressBar then self:RefreshProgressBar() end
                            ACR:NotifyChange(AddOnName)
                        end,
                    }, {
                        name = L["PROGRESS_BAR_BORDER_TEXTURE"],
                        type = "select",
                        dialogControl = "LSM30_Border",
                        values = AceGUIWidgetLSMlists.border,
                        style = "dropdown",
                        hidden = function() return self:GetProgressBarValue("borderStyle") ~= "LSM_BORDER" end,
                        get = function() return self.db.profile.progressBar.borderTexture end,
                        set = function(_, value)
                            self.db.profile.progressBar.borderTexture = value
                            if self.RefreshProgressBar then self:RefreshProgressBar() end
                        end,
                    }),
                    borderDetailRow = ColumnRow(9, {
                        name = L["PROGRESS_BAR_BORDER_COLOR"],
                        type = "color",
                        hasAlpha = true,
                        width = 1,
                        hidden = function() return self:GetProgressBarValue("borderStyle") == "NONE" end,
                        get = function()
                            local c = self.db.profile.progressBar.borderColor
                            return c.r, c.g, c.b, c.a
                        end,
                        set = function(_, r, g, b, a)
                            self.db.profile.progressBar.borderColor = { r = r, g = g, b = b, a = a }
                            if self.RefreshProgressBar then self:RefreshProgressBar() end
                        end,
                    }, {
                        name = L["PROGRESS_BAR_BORDER_SIZE"],
                        type = "range",
                        min = 1, max = 16, step = 1,
                        width = 1,
                        hidden = function() return self:GetProgressBarValue("borderStyle") == "NONE" end,
                        get = function() return self.db.profile.progressBar.borderSize end,
                        set = function(_, value)
                            self.db.profile.progressBar.borderSize = value
                            if self.RefreshProgressBar then self:RefreshProgressBar() end
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
                        width = 1.25,
                        get = function()
                            local c = self.db.profile.progressBar.tickColor
                            return c.r, c.g, c.b, c.a
                        end,
                        set = function(_, r, g, b, a)
                            self.db.profile.progressBar.tickColor = { r = r, g = g, b = b, a = a }
                            if self.RefreshProgressBar then self:RefreshProgressBar() end
                        end,
                    }, {
                        name = L["PROGRESS_BAR_TICK_WIDTH"],
                        type = "range",
                        min = 1, max = 4, step = 1,
                        width = 1,
                        get = function() return self.db.profile.progressBar.tickWidth end,
                        set = function(_, value)
                            self.db.profile.progressBar.tickWidth = value
                            if self.RefreshProgressBar then self:RefreshProgressBar() end
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
                            if self.RefreshProgressBar then self:RefreshProgressBar() end
                        end,
                    },
                    calloutHeader = {
                        type = "header",
                        name = L["CALLOUT"],
                        order = 13,
                    },
                    showCallout = {
                        name = L["PROGRESS_BAR_SHOW_CALLOUT"],
                        desc = L["PROGRESS_BAR_SHOW_CALLOUT_DESC"],
                        type = "toggle",
                        order = 14,
                        get = function() return self:GetProgressBarValue("showCallout") end,
                        set = function(_, value)
                            self.db.profile.progressBar.showCallout = value
                            if self.RefreshProgressBar then self:RefreshProgressBar() end
                            ACR:NotifyChange(AddOnName)
                        end,
                    },
                    calloutPosition = {
                        name = L["PROGRESS_BAR_CALLOUT_POSITION"],
                        type = "select",
                        order = 15,
                        hidden = function() return not self:GetProgressBarValue("showCallout") end,
                        values = {
                            ABOVE = L["PROGRESS_BAR_CALLOUT_ABOVE"],
                            BELOW = L["PROGRESS_BAR_CALLOUT_BELOW"],
                        },
                        get = function() return self.db.profile.progressBar.calloutPosition end,
                        set = function(_, value)
                            self.db.profile.progressBar.calloutPosition = value
                            if self.RefreshProgressBar then self:RefreshProgressBar() end
                        end,
                    },
                    calloutFont = {
                        name = L["PROGRESS_BAR_CALLOUT_FONT"],
                        type = "select",
                        dialogControl = 'LSM30_Font',
                        values = AceGUIWidgetLSMlists.font,
                        style = "dropdown",
                        order = 15.5,
                        hidden = function() return not self:GetProgressBarValue("showCallout") end,
                        get = function() return self.db.profile.progressBar.calloutFont end,
                        set = function(_, value)
                            self.db.profile.progressBar.calloutFont = value
                            if self.RefreshProgressBar then self:RefreshProgressBar() end
                        end,
                    },
                    calloutFontSize = {
                        name = L["PROGRESS_BAR_CALLOUT_FONT_SIZE"],
                        type = "range",
                        order = 16,
                        min = 8, max = 24, step = 1,
                        hidden = function() return not self:GetProgressBarValue("showCallout") end,
                        get = function() return self.db.profile.progressBar.calloutFontSize end,
                        set = function(_, value)
                            self.db.profile.progressBar.calloutFontSize = value
                            if self.RefreshProgressBar then self:RefreshProgressBar() end
                        end,
                    },
                    calloutColorRow = ColumnRow(17, {
                        name = L["PROGRESS_BAR_CALLOUT_TEXT_COLOR"],
                        type = "color",
                        hasAlpha = true,
                        width = 1,
                        hidden = function() return not self:GetProgressBarValue("showCallout") end,
                        get = function()
                            local c = self.db.profile.progressBar.calloutTextColor
                            return c.r, c.g, c.b, c.a
                        end,
                        set = function(_, r, g, b, a)
                            self.db.profile.progressBar.calloutTextColor = { r = r, g = g, b = b, a = a }
                            if self.RefreshProgressBar then self:RefreshProgressBar() end
                        end,
                    }, {
                        name = L["PROGRESS_BAR_CALLOUT_BG_COLOR"],
                        type = "color",
                        hasAlpha = true,
                        width = 1,
                        hidden = function() return not self:GetProgressBarValue("showCallout") end,
                        get = function()
                            local c = self.db.profile.progressBar.calloutBackgroundColor
                            return c.r, c.g, c.b, c.a
                        end,
                        set = function(_, r, g, b, a)
                            self.db.profile.progressBar.calloutBackgroundColor = { r = r, g = g, b = b, a = a }
                            if self.RefreshProgressBar then self:RefreshProgressBar() end
                        end,
                    }),
                },
            },
        },
    }
end

function KeystonePolaris:RefreshAdvancedOptionsTree(dungeonKey)
    local rebuilder = self._dungeonMilestoneRebuilders
        and self._dungeonMilestoneRebuilders[dungeonKey]
    if rebuilder then rebuilder() end

    ACR:NotifyChange(AddOnName)
end

function KeystonePolaris:CreateDungeonOptions(dungeonKey, order)
    local numBosses = #self.DUNGEONS[self:GetDungeonIdByKey(dungeonKey)]

    -- Ensure the advanced settings table exists for this dungeon
    if not self.db.profile.advanced[dungeonKey] then
        self.db.profile.advanced[dungeonKey] = {}

        -- Initialize with defaults if needed
        for _, expansion in ipairs(expansions) do
            if self[expansion.id .. "_DUNGEON_IDS"] and
                self[expansion.id .. "_DUNGEON_IDS"][dungeonKey] then
                local defaults = self[expansion.id .. "_DEFAULTS"][dungeonKey]
                if defaults then
                    for key, value in pairs(defaults) do
                        if type(value) == "table" then
                            self.db.profile.advanced[dungeonKey][key] = CloneTable(value)
                        else
                            self.db.profile.advanced[dungeonKey][key] = value
                        end
                    end
                end
                break
            end
        end
    end

    local function EnsureMilestonesTable()
        local advanced = self.db.profile.advanced[dungeonKey]
        if type(advanced.milestones) ~= "table" then
            advanced.milestones = {}
        end

        for index, milestone in ipairs(advanced.milestones) do
            if type(milestone) ~= "table" then
                milestone = {}
                advanced.milestones[index] = milestone
            end
            if milestone.id == nil then
                milestone.id = index
            end
            if milestone.creationOrder == nil then
                milestone.creationOrder = index
            end
            milestone.thresholdPercent = tonumber(milestone.thresholdPercent) or 0
            local triggerType = tostring(milestone.triggerType or "none"):lower()
            if triggerType ~= "none" and triggerType ~= "zone" and triggerType ~= "subzone" then
                triggerType = "none"
            end
            milestone.triggerType = triggerType
            milestone.matchText = tostring(milestone.matchText or "")
            milestone.label = tostring(milestone.label or "")
            milestone.informSuffix = tostring(milestone.informSuffix or "")
            milestone.inform = milestone.inform == true
        end

        return advanced.milestones
    end

    local function RefreshMilestoneRuntime()
        self:UpdateDungeonData()
        local dungeonId = self:GetDungeonIdByKey(dungeonKey)
        if dungeonId and self.ResetMilestoneRuntimeState then
            self:ResetMilestoneRuntimeState(dungeonId)
        end
        if dungeonId and self.BuildSectionOrder then
            self:BuildSectionOrder(dungeonId)
        end
        if self.UpdatePercentageText then self:UpdatePercentageText() end
    end

    local function RefreshDungeonRouting()
        RefreshMilestoneRuntime()
        ACR:NotifyChange(AddOnName)
    end

    local function RefreshDungeonRoutingOptionsView()
        if self.RefreshAdvancedOptionsTree then
            self:RefreshAdvancedOptionsTree(dungeonKey)
        end
    end

    local function NextMilestoneId(milestones)
        local maxId = 0
        for _, milestone in ipairs(milestones) do
            local id = tonumber(milestone.id)
            if id and id > maxId then
                maxId = id
            end
        end
        return maxId + 1
    end

    local function NextMilestoneCreationOrder(milestones)
        local maxOrder = 0
        for _, milestone in ipairs(milestones) do
            local creationOrder = tonumber(milestone.creationOrder)
            if creationOrder and creationOrder > maxOrder then
                maxOrder = creationOrder
            end
        end
        return maxOrder + 1
    end

    local options = {
        name = function()
            local mapId = self:GetDungeonIdByKey(dungeonKey)

            local name, texture
            if mapId then
                name = select(1, C_ChallengeMode.GetMapUIInfo(mapId))
                texture = select(4, C_ChallengeMode.GetMapUIInfo(mapId))
            end

            -- Fallback if name/texture is missing
            if not name then
                -- Try to find manual name
                for _, expansion in ipairs(expansions) do
                    local names = self[expansion.id .. "_DUNGEON_NAMES"]
                    if names and names[dungeonKey] then
                        name = names[dungeonKey]
                        break
                    end
                end
            end
            name = name or dungeonKey or "Unknown"
            texture = texture or "Interface\\Icons\\INV_Misc_QuestionMark"

            return '|T' .. texture .. ":16:16:0:0|t " .. (name)
        end,
        type = "group",
        order = order,
        args = {
            dungeonHeader = {
                order = 0,
                type = "description",
                fontSize = "large",
                name = function()
                    local mapId = self:GetDungeonIdByKey(dungeonKey)

                    local name, texture
                    if mapId then
                        name = select(1, C_ChallengeMode.GetMapUIInfo(mapId))
                        texture = select(4, C_ChallengeMode.GetMapUIInfo(mapId))
                    end

                    -- Fallback if name/texture is missing
                    if not name then
                         -- Try to find manual name
                         for _, expansion in ipairs(expansions) do
                             local names = self[expansion.id .. "_DUNGEON_NAMES"]
                             if names and names[dungeonKey] then
                                 name = names[dungeonKey]
                                 break
                             end
                         end
                    end
                    name = name or dungeonKey or "Unknown"
                    texture = texture or "Interface\\Icons\\INV_Misc_QuestionMark"

                    return "|T" .. texture .. ":20:20:0:0|t |cff40E0D0" ..
                               (name) .. "|r"
                end
            },
            dungeonSecondHeader = {type = "header", name = "", order = 1},
            reset = {
                order = 2,
                type = "execute",
                name = L["RESET_DUNGEON"],
                desc = L["RESET_DUNGEON_DESC"],
                func = function()
                    local dungeonId = self:GetDungeonIdByKey(dungeonKey)
                    if dungeonId and self.DUNGEONS[dungeonId] then
                        -- Reset all boss percentages and inform group settings for this dungeon to defaults
                        if not self.db.profile.advanced[dungeonKey] then
                            self.db.profile.advanced[dungeonKey] = {}
                        else
                            wipe(self.db.profile.advanced[dungeonKey])
                        end

                        -- Get the appropriate defaults
                        local defaults
                        for _, expansion in ipairs(expansions) do
                            if self[expansion.id .. "_DUNGEON_IDS"][dungeonKey] then
                                defaults =
                                    self[expansion.id .. "_DEFAULTS"][dungeonKey]
                                break
                            end
                        end

                        if defaults then
                            for key, value in pairs(defaults) do
                                if type(value) == "table" then
                                    self.db.profile.advanced[dungeonKey][key] = CloneTable(value)
                                else
                                    self.db.profile.advanced[dungeonKey][key] = value
                                end
                            end
                        end

                        -- Update the display
                        self:UpdateDungeonData()
                        if dungeonId and self.ResetMilestoneRuntimeState then
                            self:ResetMilestoneRuntimeState(dungeonId)
                        end
                        if self.currentDungeonID and self.BuildSectionOrder then
                            self:BuildSectionOrder(self.currentDungeonID)
                        end
                        if self.RefreshAdvancedOptionsTree then
                            self:RefreshAdvancedOptionsTree(dungeonKey)
                        else
                            ACR:NotifyChange(AddOnName)
                        end
                        if self.UpdatePercentageText then self:UpdatePercentageText() end
                    end
                end,
                confirm = true,
                confirmText = L["RESET_DUNGEON_CONFIRM"]
            },
            export = {
                order = 3,
                type = "execute",
                name = L["EXPORT_DUNGEON"],
                desc = L["EXPORT_DUNGEON_DESC"],
                func = function()
                    local addon = KeystonePolaris
                    local dungeonId = addon:GetDungeonIdByKey(dungeonKey)
                    if dungeonId and addon.DUNGEONS[dungeonId] and
                        addon.db.profile.advanced[dungeonKey] then
                        addon:ExportDungeonSettings(
                            addon.db.profile.advanced[dungeonKey],
                            "dungeon",
                            dungeonKey
                        )
                    end
                end
            },
            import = {
                order = 3.5,
                type = "execute",
                name = L["IMPORT_DUNGEON"],
                desc = L["IMPORT_DUNGEON_DESC"],
                func = function()
                    local addon = KeystonePolaris

                    -- Create filter for this specific dungeon
                    local dungeonFilter = {}
                    dungeonFilter[dungeonKey] = true

                    local dungeonLabel = addon:GetDungeonDisplayName(dungeonKey) or dungeonKey
                    addon:ShowImportDialog(dungeonLabel, dungeonFilter)
                end
            },
            header = {order = 4, type = "header", name = L["TANK_GROUP_HEADER"]}
        }
    }

    -- Build choices for boss order selector (indexed by boss index in DUNGEONS)
    local bossChoices = {}
    for i = 1, numBosses do
        local bossName = self:GetBossName(dungeonKey, i)
        bossChoices[i] = bossName
    end

    -- Group to control logical section order (bossOrder)
    options.args.bossOrder = {
        type = "group",
        name = L["BOSS_ORDER"],
        inline = true,
        order = 4.5,
        args = {}
    }

    for section = 1, numBosses do
        options.args.bossOrder.args["section" .. section] = {
            type = "select",
            name = format(L["BOSS"] .. " %d", section),
            order = section,
            values = bossChoices,
            get = function()
                local adv = self.db.profile.advanced[dungeonKey]
                local orderTable = adv and adv.bossOrder
                local idx = orderTable and orderTable[section]
                if type(idx) ~= "number" or idx < 1 or idx > numBosses then
                    return section
                end
                return idx
            end,
            set = function(_, value)
                if not self.db.profile.advanced[dungeonKey].bossOrder then
                    self.db.profile.advanced[dungeonKey].bossOrder = {}
                end
                self.db.profile.advanced[dungeonKey].bossOrder[section] = value
                local dungeonId = self:GetDungeonIdByKey(dungeonKey)
                if dungeonId then
                    if self.BuildSectionOrder then
                        self:BuildSectionOrder(dungeonId)
                    end
                    self:UpdateDungeonData()
                    if self.UpdatePercentageText then self:UpdatePercentageText() end
                end
            end
        }
    end

    for i = 1, numBosses do
        local bossNumStr = self:GetBossNumberString(i)
        local bossName = self:GetBossName(dungeonKey, i)

        -- Create a group for each boss line
        options.args["boss" .. i] = {
            type = "group",
            name = bossName,
            inline = true,
            order = i + 4, -- Start boss orders at 5 (after header)
            args = {
                percent = {
                    name = L["PERCENTAGE"],
                    type = "range",
                    min = 0,
                    max = 100,
                    step = 0.01,
                    order = 1,
                    width = 1,
                    get = function()
                        return self.db.profile.advanced[dungeonKey]["Boss" ..
                                   bossNumStr]
                    end,
                    set = function(_, value)
                        self.db.profile.advanced[dungeonKey]["Boss" ..
                            bossNumStr] = value
                        self:UpdateDungeonData()
                    end
                },
                inform = {
                    name = L["SHOW_INFORM_GROUP_BUTTON"],
                    desc = L["SHOW_INFORM_GROUP_BUTTON_DESC"],
                    type = "toggle",
                    order = 2,
                    width = 1,
                    get = function()
                        return self.db.profile.advanced[dungeonKey]["Boss" ..
                                   bossNumStr .. "Inform"]
                    end,
                    set = function(_, value)
                        self.db.profile.advanced[dungeonKey]["Boss" ..
                            bossNumStr .. "Inform"] = value
                        self:UpdateDungeonData()
                    end
                }
            }
        }
    end

    local RebuildMilestoneOptionGroups

    options.args.milestones = {
        type = "group",
        name = L["MILESTONES"],
        inline = true,
        order = numBosses + 5,
        args = {
            description = {
                type = "description",
                order = 0,
                fontSize = "medium",
                name = L["MILESTONES_DESC"]
            },
            addMilestone = {
                type = "execute",
                order = 1,
                name = L["MILESTONE_ADD"],
                func = function()
                    local milestones = EnsureMilestonesTable()
                    milestones[#milestones + 1] = {
                        id = NextMilestoneId(milestones),
                        label = "",
                        thresholdPercent = 0,
                        triggerType = "none",
                        matchText = "",
                        informSuffix = "",
                        inform = false,
                        creationOrder = NextMilestoneCreationOrder(milestones),
                    }
                    if RebuildMilestoneOptionGroups then
                        RebuildMilestoneOptionGroups()
                    end
                    RefreshDungeonRouting()
                    RefreshDungeonRoutingOptionsView()
                end
            }
        }
    }

    local function AddMilestoneOptions(milestoneIndex)
        local milestones = EnsureMilestonesTable()
        local milestone = milestones[milestoneIndex]
        if not milestone then return end

        local optionKey = "milestone" .. milestoneIndex
        options.args.milestones.args[optionKey] = {
            type = "group",
            inline = true,
            order = milestoneIndex + 10,
            name = function()
                local currentMilestones = EnsureMilestonesTable()
                local current = currentMilestones[milestoneIndex]
                if not current then
                    return string.format("%s %d", L["MILESTONE"], milestoneIndex)
                end
                local matchText = tostring(current.matchText or ""):match("^%s*(.-)%s*$") or ""
                if matchText ~= "" then
                    return matchText
                end
                local label = tostring(current.label or ""):match("^%s*(.-)%s*$") or ""
                if label ~= "" then
                    return label
                end
                return string.format("%s %d", L["MILESTONE"], milestoneIndex)
            end,
            args = {
                label = {
                    type = "input",
                    order = 1,
                    width = 1.2,
                    name = L["MILESTONE_LABEL"],
                    get = function()
                        local current = EnsureMilestonesTable()[milestoneIndex]
                        return current and current.label or ""
                    end,
                    set = function(_, value)
                        local current = EnsureMilestonesTable()[milestoneIndex]
                        if not current then return end
                        current.label = tostring(value or "")
                        RefreshMilestoneRuntime()
                    end
                },
                threshold = {
                    type = "range",
                    min = 0,
                    max = 100,
                    step = 0.01,
                    order = 2,
                    width = 0.8,
                    name = L["MILESTONE_THRESHOLD"],
                    get = function()
                        local current = EnsureMilestonesTable()[milestoneIndex]
                        return (current and tonumber(current.thresholdPercent)) or 0
                    end,
                    set = function(_, value)
                        local current = EnsureMilestonesTable()[milestoneIndex]
                        if not current then return end
                        current.thresholdPercent = tonumber(value) or 0
                        RefreshMilestoneRuntime()
                    end
                },
                triggerType = {
                    type = "select",
                    order = 3,
                    width = 0.8,
                    name = L["MILESTONE_TRIGGER_TYPE"],
                    values = {
                        none = L["MILESTONE_TRIGGER_NONE"],
                        zone = L["MILESTONE_TRIGGER_ZONE"],
                        subzone = L["MILESTONE_TRIGGER_SUBZONE"],
                    },
                    get = function()
                        local current = EnsureMilestonesTable()[milestoneIndex]
                        return (current and current.triggerType) or "none"
                    end,
                    set = function(_, value)
                        local current = EnsureMilestonesTable()[milestoneIndex]
                        if not current then return end
                        current.triggerType = value
                        if value == "none" then
                            current.inform = false
                        end
                        RefreshDungeonRouting()
                    end
                },
                matchText = {
                    type = "input",
                    order = 4,
                    width = 1.2,
                    name = L["MILESTONE_MATCH_TEXT"],
                    hidden = function()
                        local current = EnsureMilestonesTable()[milestoneIndex]
                        return not current or current.triggerType == "none"
                    end,
                    get = function()
                        local current = EnsureMilestonesTable()[milestoneIndex]
                        return current and current.matchText or ""
                    end,
                    set = function(_, value)
                        local current = EnsureMilestonesTable()[milestoneIndex]
                        if not current then return end
                        current.matchText = tostring(value or "")
                        RefreshMilestoneRuntime()
                    end
                },
                captureZone = {
                    type = "execute",
                    order = 5,
                    width = 0.8,
                    name = L["MILESTONE_CAPTURE_ZONE"],
                    hidden = function()
                        local current = EnsureMilestonesTable()[milestoneIndex]
                        return not current or current.triggerType ~= "zone"
                    end,
                    func = function()
                        local current = EnsureMilestonesTable()[milestoneIndex]
                        if not current then return end
                        current.matchText = tostring(GetZoneText() or "")
                        RefreshMilestoneRuntime()
                        ACR:NotifyChange(AddOnName)
                    end
                },
                captureSubzone = {
                    type = "execute",
                    order = 6,
                    width = 0.8,
                    name = L["MILESTONE_CAPTURE_SUBZONE"],
                    hidden = function()
                        local current = EnsureMilestonesTable()[milestoneIndex]
                        return not current or current.triggerType ~= "subzone"
                    end,
                    func = function()
                        local current = EnsureMilestonesTable()[milestoneIndex]
                        if not current then return end
                        current.matchText = tostring(GetSubZoneText() or "")
                        RefreshMilestoneRuntime()
                        ACR:NotifyChange(AddOnName)
                    end
                },
                informRow = ColumnRow(7, {
                    type = "toggle",
                    width = 1,
                    name = L["SHOW_INFORM_GROUP_BUTTON"],
                    desc = L["SHOW_INFORM_GROUP_BUTTON_DESC"],
                    hidden = function()
                        local current = EnsureMilestonesTable()[milestoneIndex]
                        return not current or current.triggerType == "none"
                    end,
                    get = function()
                        local current = EnsureMilestonesTable()[milestoneIndex]
                        return current and current.inform == true or false
                    end,
                    set = function(_, value)
                        local current = EnsureMilestonesTable()[milestoneIndex]
                        if not current then return end
                        current.inform = value == true
                        RefreshMilestoneRuntime()
                    end
                }, {
                    type = "input",
                    width = 1.1,
                    name = L["MILESTONE_INFORM_SUFFIX"],
                    desc = L["MILESTONE_INFORM_SUFFIX_DESC"],
                    hidden = function()
                        local current = EnsureMilestonesTable()[milestoneIndex]
                        return not current or current.triggerType == "none"
                    end,
                    get = function()
                        local current = EnsureMilestonesTable()[milestoneIndex]
                        return current and current.informSuffix or ""
                    end,
                    set = function(_, value)
                        local current = EnsureMilestonesTable()[milestoneIndex]
                        if not current then return end
                        current.informSuffix = tostring(value or "")
                        RefreshMilestoneRuntime()
                    end
                }),
                remove = {
                    type = "execute",
                    order = 8,
                    width = 0.8,
                    name = L["MILESTONE_REMOVE"],
                    confirm = true,
                    confirmText = L["MILESTONE_REMOVE_CONFIRM"],
                    func = function()
                        local currentMilestones = EnsureMilestonesTable()
                        table.remove(currentMilestones, milestoneIndex)
                        if RebuildMilestoneOptionGroups then
                            RebuildMilestoneOptionGroups()
                        end
                        RefreshDungeonRouting()
                        RefreshDungeonRoutingOptionsView()
                    end
                },
            }
        }
    end

    RebuildMilestoneOptionGroups = function()
        local milestoneArgs = options.args.milestones.args
        for key in pairs(milestoneArgs) do
            if type(key) == "string" and key:match("^milestone%d+$") then
                milestoneArgs[key] = nil
            end
        end

        local milestones = EnsureMilestonesTable()
        for milestoneIndex = 1, #milestones do
            AddMilestoneOptions(milestoneIndex)
        end
    end

    RebuildMilestoneOptionGroups()

    self._dungeonMilestoneRebuilders = self._dungeonMilestoneRebuilders or {}
    self._dungeonMilestoneRebuilders[dungeonKey] = RebuildMilestoneOptionGroups

    return options
end
