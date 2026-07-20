local AddOnName, KeystonePolaris = ...;

local pairs, select = pairs, select
local gsub = string.gsub
local strsplit = strsplit

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
    if KeystonePolaris._progressBarPreview then
        if KeystonePolaris.ApplyProgressBarPreviewScenario then
            KeystonePolaris:ApplyProgressBarPreviewScenario()
        end
        if KeystonePolaris.RefreshProgressBar then
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
    ACR:NotifyChange(AddOnName)
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

local function RefreshDisplayColorSettings(self)
    if self.UpdateColorCache then self:UpdateColorCache() end
    if self.UpdatePercentageText then self:UpdatePercentageText() end
    self:Refresh()
    RefreshPreviewWidget()
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
            RefreshDisplayColorSettings(self)
        end
    }
end

local function MakeMilestonePrefixColorProps(self, order)
    return ColumnRow(order, {
        name = L["CUSTOM_MILESTONE_PREFIX_COLOR"],
        desc = L["CUSTOM_MILESTONE_PREFIX_COLOR_DESC"],
        type = "toggle",
        width = 1.125,
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
            self.db.profile.color.milestonePrefix = { r = r, g = g, b = b, a = a }
            RefreshDisplayColorSettings(self)
        end,
        hidden = function()
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

-- Expose shared helpers for other Options modules (load after Helpers.lua)
KeystonePolaris.RefreshPreviewWidget = RefreshPreviewWidget
KeystonePolaris.PreviewScenarioValues = PreviewScenarioValues
KeystonePolaris.SetPreviewScenario = SetPreviewScenario
KeystonePolaris.PreviewScenarioDropdown = PreviewScenarioDropdown
KeystonePolaris.PreviewGroup = PreviewGroup
KeystonePolaris.ColumnRow = ColumnRow
KeystonePolaris.RefreshDisplayColorSettings = RefreshDisplayColorSettings
KeystonePolaris.MakeStatusColorOption = MakeStatusColorOption
KeystonePolaris.MakeMilestonePrefixColorProps = MakeMilestonePrefixColorProps
KeystonePolaris.ShallowCloneTable = ShallowCloneTable
KeystonePolaris.CloneTable = CloneTable
KeystonePolaris.FormatSeasonDate = FormatSeasonDate
KeystonePolaris.InsertSortedDungeonOptions = InsertSortedDungeonOptions
