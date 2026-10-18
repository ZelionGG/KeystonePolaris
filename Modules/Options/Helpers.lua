local AddOnName, KeystonePolaris = ...;

local pairs = pairs
local gsub = string.gsub
local strsplit = strsplit

local L = LibStub("AceLocale-3.0"):GetLocale(AddOnName, true)
local ACR = LibStub("AceConfigRegistry-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")
local AceGUI = LibStub("AceGUI-3.0")

-- MDT integration unavailable due to Blizzard API changes in Midnight
local MDT_FEATURES_ENABLED = false
KeystonePolaris.mdtFeaturesEnabled = MDT_FEATURES_ENABLED

-- Shared preview scenario index (persists across Display and Appearance pages)
KeystonePolaris._previewScenario = 1

local function RefreshDisplayPreview()
    local previewWidget = KeystonePolaris._previewWidget
    if previewWidget and previewWidget.RefreshPreview then
        previewWidget:RefreshPreview()
    end
end

local function RefreshPreviewWidget()
    RefreshDisplayPreview()

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
    if KeystonePolaris._progressBarPreview then
        if KeystonePolaris.ApplyProgressBarPreviewScenario then
            KeystonePolaris:ApplyProgressBarPreviewScenario()
        end
        if KeystonePolaris.ApplyProgressBarPaint then
            KeystonePolaris:ApplyProgressBarPaint()
        elseif KeystonePolaris.RefreshProgressBar then
            KeystonePolaris:RefreshProgressBar()
        elseif KeystonePolaris.EnableProgressBarPreview then
            KeystonePolaris:EnableProgressBarPreview()
        end
    end
    local displayPreview = KeystonePolaris._previewWidget
    if displayPreview and displayPreview.RefreshPreview then
        displayPreview:RefreshPreview()
    end
    local progressBarPreview = KeystonePolaris._progressBarPreviewWidget
    if progressBarPreview and progressBarPreview.RefreshPreview then
        progressBarPreview:RefreshPreview()
    end
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
            previewScenario = PreviewScenarioDropdown(1),
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

local function SetColorTable(color, r, g, b, a)
    if not color then
        return { r = r, g = g, b = b, a = a }
    end
    color.r = r
    color.g = g
    color.b = b
    if a ~= nil then
        color.a = a
    end
    return color
end

local function ColumnRow(order, left, right, spacerWidth)
    left.order = 1
    left.width = 1.25
    right.order = 2
    right.width = 1.1
    return {
        type = "group", inline = true, name = "", order = order,
        args = {
            col1 = left,
            spacer = { name = " ", type = "description", order = 1.5, width = spacerWidth or 0.12 },
            col2 = right,
        }
    }
end

local function RefreshDisplayColorSettings(self)
    if self.ApplyDisplayAppearance then
        self:ApplyDisplayAppearance()
    elseif self.Refresh then
        self:Refresh()
    end
    RefreshDisplayPreview()
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
            SetColorTable(self.db.profile.color[colorKey], r, g, b, a)
            RefreshDisplayColorSettings(self)
        end
    }
end

local function MakeMilestonePrefixColorProps(self, order)
    return ColumnRow(order, {
        name = L["CUSTOM_MILESTONE_PREFIX_COLOR"],
        desc = L["CUSTOM_MILESTONE_PREFIX_COLOR_DESC"],
        type = "toggle",
        get = function()
            return self.db.profile.general.mainDisplay.customMilestonePrefixColor == true
        end,
        set = function(_, value)
            self.db.profile.general.mainDisplay.customMilestonePrefixColor = value == true
            RefreshDisplayColorSettings(self)
        end,
        disabled = function()
            return self.db.profile.general.mainDisplay.showMilestones == false
        end,
    }, {
        name = L["MILESTONE_PREFIX_COLOR"],
        desc = L["MILESTONE_PREFIX_COLOR_DESC"],
        type = "color",
        get = function()
            local color = self.db.profile.color.milestonePrefix or self.db.profile.color.prefix
            return color.r, color.g, color.b, color.a
        end,
        set = function(_, r, g, b, a)
            local colors = self.db.profile.color
            if colors.milestonePrefix then
                SetColorTable(colors.milestonePrefix, r, g, b, a)
            else
                colors.milestonePrefix = { r = r, g = g, b = b, a = a }
            end
            RefreshDisplayColorSettings(self)
        end,
        disabled = function()
            return not self.db.profile.general.mainDisplay.customMilestonePrefixColor
        end,
    })
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

-- Helper to format date string "YYYY-MM-DD" to localized format or default.
-- "TBD" is shown as a localized placeholder when the season date is unknown.
local function FormatSeasonDate(dateStr)
    if not dateStr then return "" end
    if dateStr == "TBD" then return L["SEASON_DATE_TBD"] end
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
        local name = (mapId and C_ChallengeMode.GetMapUIInfo(mapId)) or key
        table.insert(sortable, { key = key, name = name })
    end
    table.sort(sortable, function(a, b) return a.name < b.name end)

    for idx, entry in ipairs(sortable) do
        local opt = ShallowCloneTable(sharedOptions[entry.key])
        opt.order = baseOrder + idx
        targetArgs[entry.key] = opt
    end
end

-- ---------------------------------------------------------------------------
-- New-feature badges in the AceConfig tree (few groups only)
-- ---------------------------------------------------------------------------
-- SettingsCategoryListButtonTemplate: NewFeatureLabelTemplate at scale .8,
-- BOTTOMRIGHT to the category name LEFT (-4, -10), Label anchored RIGHT.
local OPTION_FEATURE_MARK_DELAY = 5
local OPTION_FEATURE_LABEL_SCALE = 0.8
local OPTION_FEATURE_LABEL_X = -4
local OPTION_FEATURE_LABEL_Y = -10
-- AceGUI tree text starts at x=8; Settings category names start at x=36.
local OPTION_FEATURE_TEXT_PAD = 24

local optionFeatures = {}
local optionFeatureParents = {}

local function GetSeenOptionFeatures(self)
    if not self.db then return end
    self.db.global = self.db.global or {}
    self.db.global.seenOptionFeatures = self.db.global.seenOptionFeatures or {}
    return self.db.global.seenOptionFeatures
end

-- spec.key, spec.treeValue (Ace3 uniquevalue), spec.parentValue, spec.parentLabel
function KeystonePolaris:RegisterOptionFeature(spec)
    if not self or not spec or not spec.key then return end
    optionFeatures[spec.key] = spec
    local parentValue = spec.parentValue
    if not parentValue then return end
    local parent = optionFeatureParents[parentValue]
    if not parent then
        parent = { keys = {}, label = spec.parentLabel }
        optionFeatureParents[parentValue] = parent
    end
    parent.label = spec.parentLabel or parent.label
    local keys = parent.keys
    for i = 1, #keys do
        if keys[i] == spec.key then return end
    end
    keys[#keys + 1] = spec.key
end

function KeystonePolaris:IsOptionFeatureUnseen(key)
    local seen = GetSeenOptionFeatures(self)
    if not seen then return false end
    return seen[key] ~= true
end

function KeystonePolaris:MarkOptionFeatureSeen(key)
    local seen = GetSeenOptionFeatures(self)
    if not seen then return end
    seen[key] = true
end

function KeystonePolaris:SeedOptionFeaturesIfNewInstall()
    if self._hadPriorVersionCheck then return end
    local seen = GetSeenOptionFeatures(self)
    if not seen then return end
    local defaults = self.defaults and self.defaults.global and self.defaults.global.seenOptionFeatures
    if type(defaults) == "table" then
        for key in pairs(defaults) do
            seen[key] = true
        end
    end
end

local function GetAceConfigTreeSelected()
    local status = AceConfigDialog:GetStatusTable(AddOnName)
    return status and status.groups and status.groups.selected
end

local function IsOptionFeaturePanelSelected(key)
    local spec = optionFeatures[key]
    if not spec or not spec.treeValue then return false end
    return GetAceConfigTreeSelected() == spec.treeValue
end

function KeystonePolaris:CancelQueuedOptionFeatureMark(key)
    if self._optionFeatureMarkQueued then
        self._optionFeatureMarkQueued[key] = nil
    end
    local timers = self._optionFeatureMarkTimers
    local timer = timers and timers[key]
    if timer then
        timers[key] = nil
        if timer.Cancel then
            timer:Cancel()
        end
    end
end

local function CollectQueuedOptionFeatureKeys(self)
    local queued = self._optionFeatureMarkQueued
    if not queued then return nil end
    local keys = {}
    for key in pairs(queued) do
        keys[#keys + 1] = key
    end
    return keys
end

function KeystonePolaris:CancelQueuedOptionFeatureMarks()
    local keys = CollectQueuedOptionFeatureKeys(self)
    if not keys then return end
    for i = 1, #keys do
        self:CancelQueuedOptionFeatureMark(keys[i])
    end
end

local function CancelOptionFeatureMarkIfLeftPanel(self, key)
    if not (self._optionFeatureMarkQueued and self._optionFeatureMarkQueued[key]) then return end
    if IsOptionFeaturePanelSelected(key) then return end
    self:CancelQueuedOptionFeatureMark(key)
end

function KeystonePolaris:CancelOptionFeatureMarksIfLeftPanel()
    local keys = CollectQueuedOptionFeatureKeys(self)
    if not keys then return end
    for i = 1, #keys do
        CancelOptionFeatureMarkIfLeftPanel(self, keys[i])
    end
end

local function QueueMarkOptionFeatureSeen(self, key)
    if not self:IsOptionFeatureUnseen(key) then return end
    self._optionFeatureMarkQueued = self._optionFeatureMarkQueued or {}
    if self._optionFeatureMarkQueued[key] then return end
    self._optionFeatureMarkQueued[key] = true
    self._optionFeatureMarkTimers = self._optionFeatureMarkTimers or {}
    self._optionFeatureMarkTimers[key] = C_Timer.NewTimer(OPTION_FEATURE_MARK_DELAY, function()
        self._optionFeatureMarkTimers[key] = nil
        self._optionFeatureMarkQueued[key] = nil
        if not self:IsOptionFeatureUnseen(key) then return end
        if not IsOptionFeaturePanelSelected(key) then return end
        self:MarkOptionFeatureSeen(key)
        ACR:NotifyChange(AddOnName)
    end)
end

function KeystonePolaris:OptionFeatureSeenProbe(key)
    return {
        type = "description",
        order = -1,
        name = " ",
        hidden = function()
            QueueMarkOptionFeatureSeen(self, key)
            return true
        end,
    }
end

local function ShouldShowOptionFeatureBadge(self, uniquevalue)
    if not uniquevalue then return false end
    for key, spec in pairs(optionFeatures) do
        if spec.treeValue == uniquevalue then
            return self:IsOptionFeatureUnseen(key)
        end
    end
    local parent = optionFeatureParents[uniquevalue]
    if not parent then return false end
    if self._optionFeatureExpanded and self._optionFeatureExpanded[uniquevalue] then
        return false
    end
    for i = 1, #parent.keys do
        if self:IsOptionFeatureUnseen(parent.keys[i]) then
            return true
        end
    end
    return false
end

local function EnsureOptionFeatureLabel(button)
    local frame = button._kplNewFeature
    if frame then return frame end
    if not button.text then return nil end
    frame = CreateFrame("Frame", nil, button, "NewFeatureLabelTemplate")
    frame:SetScale(OPTION_FEATURE_LABEL_SCALE)
    frame:SetFrameLevel(button:GetFrameLevel() + 10)
    frame:SetSize(1, 1)
    button._kplNewFeature = frame
    return frame
end

local function ApplyOptionFeatureBadge(button, show)
    local frame = button._kplNewFeature
    if not show then
        if frame then
            frame:Hide()
        end
        return
    end
    frame = EnsureOptionFeatureLabel(button)
    if not frame or not frame.BGLabel or not frame.Label then return end
    frame:ClearAllPoints()
    frame:SetPoint("BOTTOMRIGHT", button.text, "LEFT", OPTION_FEATURE_LABEL_X, OPTION_FEATURE_LABEL_Y)
    frame.BGLabel:SetPoint("RIGHT", 0.5, -0.5)
    frame.Label:SetPoint("RIGHT", 0, 0)
    local level = button.level or 1
    local left = (level == 1) and 8 or (8 * level)
    button.text:SetPoint("LEFT", left + OPTION_FEATURE_TEXT_PAD, 2)
    frame:Show()
end

function KeystonePolaris:OnOptionFeatureTreeRefreshed(tree)
    self:CancelOptionFeatureMarksIfLeftPanel()
    if not tree then return end

    local status = tree.status or tree.localstatus
    local groups = status and status.groups
    self._optionFeatureExpanded = self._optionFeatureExpanded or {}
    for parentValue in pairs(optionFeatureParents) do
        self._optionFeatureExpanded[parentValue] = groups and groups[parentValue] and true or false
    end

    local buttons = tree.buttons
    if not buttons then return end
    for i = 1, #buttons do
        local button = buttons[i]
        local show = button:IsShown() and ShouldShowOptionFeatureBadge(self, button.uniquevalue)
        ApplyOptionFeatureBadge(button, show)
    end
end

-- AceConfig select groups (Custom Routes seasons/expansions) use DropdownGroup
-- titletext at GameFontNormal 18px. Changelog uses the same widget on another
-- appName; only enlarge titles for this addon's main options table.
local DROPDOWN_TITLE_HEIGHT = 22
local DROPDOWN_TITLE_RIGHT_PAD = 210

local function ResetKplDropdownGroupTitle(group)
    local titletext = group.titletext
    if not titletext then return end
    titletext:SetFontObject(GameFontNormal)
    titletext:SetHeight(18)
    titletext:SetPoint("TOPRIGHT", -4, -5)
end

local function ApplyKplDropdownGroupTitle(group)
    local titletext = group.titletext
    if not titletext then return end
    titletext:SetFontObject(GameFontHighlightLarge)
    titletext:SetHeight(DROPDOWN_TITLE_HEIGHT)
    titletext:SetPoint("TOPRIGHT", -DROPDOWN_TITLE_RIGHT_PAD, -5)
    -- White expansion names stay white in the tree. Gold is only the right-hand title.
    local text = titletext:GetText()
    if text and text:sub(1, 10) == "|cffffffff" then
        titletext:SetText("|cffffd100" .. text:sub(11))
    end
end

if not AceGUI._kplOptionFeatureCreateHook then
    AceGUI._kplOptionFeatureCreateHook = true
    local origCreate = AceGUI.Create
    function AceGUI:Create(widgetType, ...)
        local widget = origCreate(self, widgetType, ...)
        if widgetType == "TreeGroup" and widget and not widget._kplOptionFeatureHook then
            widget._kplOptionFeatureHook = true
            hooksecurefunc(widget, "RefreshTree", function(tree)
                if tree.GetUserData and tree:GetUserData("appName") == AddOnName then
                    KeystonePolaris:OnOptionFeatureTreeRefreshed(tree)
                end
            end)
        elseif widgetType == "DropdownGroup" and widget and not widget._kplDropdownTitleHook then
            widget._kplDropdownTitleHook = true
            hooksecurefunc(widget, "OnAcquire", ResetKplDropdownGroupTitle)
            local function TryApplyKplDropdownTitle(group)
                if group.GetUserData and group:GetUserData("appName") == AddOnName then
                    ApplyKplDropdownGroupTitle(group)
                end
            end
            hooksecurefunc(widget, "SetTitle", TryApplyKplDropdownTitle)
            -- AceConfig SetTitle runs before InjectInfo; SetGroupList is after.
            hooksecurefunc(widget, "SetGroupList", TryApplyKplDropdownTitle)
        end
        return widget
    end
end

hooksecurefunc(AceConfigDialog, "Open", function(_, appName, container)
    if appName ~= AddOnName then return end
    local root = container
    if not root and AceConfigDialog.OpenFrames then
        root = AceConfigDialog.OpenFrames[AddOnName]
    end
    if root and root.frame and not root._kplFeatureHideHook then
        root._kplFeatureHideHook = true
        root.frame:HookScript("OnHide", function()
            KeystonePolaris:CancelQueuedOptionFeatureMarks()
        end)
    end
end)

-- Expose shared helpers for other Options modules (load after Helpers.lua)
KeystonePolaris.RefreshPreviewWidget = RefreshPreviewWidget
KeystonePolaris.RefreshDisplayPreview = RefreshDisplayPreview
KeystonePolaris.PreviewScenarioValues = PreviewScenarioValues
KeystonePolaris.SetPreviewScenario = SetPreviewScenario
KeystonePolaris.PreviewScenarioDropdown = PreviewScenarioDropdown
KeystonePolaris.PreviewGroup = PreviewGroup
KeystonePolaris.ColumnRow = ColumnRow
KeystonePolaris.MakeStatusColorOption = MakeStatusColorOption
KeystonePolaris.MakeMilestonePrefixColorProps = MakeMilestonePrefixColorProps
KeystonePolaris.SetColorTable = SetColorTable
KeystonePolaris.CloneTable = CloneTable
KeystonePolaris.FormatSeasonDate = FormatSeasonDate
KeystonePolaris.InsertSortedDungeonOptions = InsertSortedDungeonOptions
