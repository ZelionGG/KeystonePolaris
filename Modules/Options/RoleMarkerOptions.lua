local AddOnName, KeystonePolaris = ...;

local _G = _G
local HideUIPanel = _G.HideUIPanel

local L = LibStub("AceLocale-3.0"):GetLocale(AddOnName, true)

local ColumnRow = KeystonePolaris.ColumnRow

local RAID_ICON_TEXTURE = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_%d"
local RAID_MARKER_SORTING = { 0, 1, 2, 3, 4, 5, 6, 7, 8 }
local ROLE_MARKER_DEFAULT_FONT = "Friz Quadrata TT"
local ROLE_MARKER_DEFAULT_FONT_SIZE = 16

local function GetRoleMarkerDB(self)
    return self.db and self.db.profile and self.db.profile.roleMarker
end

local function RaidMarkerValues()
    local values = {
        [0] = L["KPL_RM_MARKER_NONE"],
    }
    for i = 1, 8 do
        local label = _G["RAID_TARGET_" .. i] or tostring(i)
        values[i] = string.format("|T%s:16:16:0:0|t %s", string.format(RAID_ICON_TEXTURE, i), label)
    end
    return values
end

function KeystonePolaris:GetRoleMarkerOptions()
    local function IsRoleMarkerDisabled()
        local db = GetRoleMarkerDB(self)
        return not (db and db.enabled)
    end

    self:RegisterOptionFeature({
        key = "roleMarker",
        treeValue = "modules\001roleMarker",
        parentValue = "modules",
        parentLabel = L["MODULES"],
    })

    return {
        name = L["KPL_RM_HEADER"],
        type = "group",
        order = 5,
        args = {
            featureSeenProbe = self:OptionFeatureSeenProbe("roleMarker"),
            header = {
                order = 0,
                type = "header",
                name = "|cffffd100" .. L["KPL_RM_HEADER"] .. "|r",
            },
            description = {
                order = 0.5,
                type = "description",
                name = L["KPL_RM_DESC_LONG"],
                fontSize = "medium",
            },
            enable = {
                name = L["ENABLE"],
                type = "toggle",
                width = "full",
                order = 1,
                get = function()
                    local db = GetRoleMarkerDB(self)
                    return db and db.enabled
                end,
                set = function(_, value)
                    local db = GetRoleMarkerDB(self)
                    if not db then return end
                    db.enabled = value and true or false
                    if db.enabled then
                        self:InitializeRoleMarker()
                    else
                        self:DisableRoleMarker()
                    end
                end,
            },
            showOutsideInstance = {
                name = L["KPL_RM_SHOW_OUTSIDE"],
                desc = L["KPL_RM_SHOW_OUTSIDE_DESC"],
                type = "toggle",
                width = "full",
                order = 1.5,
                get = function()
                    local db = GetRoleMarkerDB(self)
                    return db and db.showOutsideInstance
                end,
                set = function(_, value)
                    local db = GetRoleMarkerDB(self)
                    if not db then return end
                    db.showOutsideInstance = value and true or false
                    self:UpdateRoleMarkerState()
                end,
                disabled = IsRoleMarkerDisabled,
            },
            showTitle = {
                name = L["KPL_RM_SHOW_TITLE"],
                desc = L["KPL_RM_SHOW_TITLE_DESC"],
                type = "toggle",
                width = "full",
                order = 1.6,
                get = function()
                    local db = GetRoleMarkerDB(self)
                    if not db or db.showTitle == nil then return true end
                    return db.showTitle and true or false
                end,
                set = function(_, value)
                    local db = GetRoleMarkerDB(self)
                    if not db then return end
                    db.showTitle = value and true or false
                    self:UpdateRoleMarkerState()
                end,
                disabled = IsRoleMarkerDisabled,
            },
            clickRequired = {
                order = 2,
                type = "description",
                name = L["KPL_RM_CLICK_REQUIRED"],
                fontSize = "medium",
                disabled = IsRoleMarkerDisabled,
            },
            markersHeader = {
                order = 3,
                type = "header",
                name = L["KPL_RM_MARKERS"],
            },
            markersRow = ColumnRow(4, {
                name = TANK,
                type = "select",
                values = RaidMarkerValues,
                sorting = RAID_MARKER_SORTING,
                get = function()
                    local db = GetRoleMarkerDB(self)
                    if not db or db.tankMarker == nil then return 6 end
                    return db.tankMarker
                end,
                set = function(_, value)
                    local db = GetRoleMarkerDB(self)
                    if not db then return end
                    db.tankMarker = value
                    self:UpdateRoleMarkerState()
                end,
                disabled = IsRoleMarkerDisabled,
            },
            {
                name = HEALER,
                type = "select",
                values = RaidMarkerValues,
                sorting = RAID_MARKER_SORTING,
                get = function()
                    local db = GetRoleMarkerDB(self)
                    if not db or db.healerMarker == nil then return 5 end
                    return db.healerMarker
                end,
                set = function(_, value)
                    local db = GetRoleMarkerDB(self)
                    if not db then return end
                    db.healerMarker = value
                    self:UpdateRoleMarkerState()
                end,
                disabled = IsRoleMarkerDisabled,
            }),
            appearanceHeader = {
                order = 4.8,
                type = "header",
                name = L["APPEARANCE"],
            },
            fontRow = ColumnRow(4.5, {
                name = L["FONT"],
                type = "select",
                dialogControl = "LSM30_Font",
                values = function()
                    return _G.AceGUIWidgetLSMlists and _G.AceGUIWidgetLSMlists.font or {}
                end,
                order = 4.85,
                get = function()
                    local db = GetRoleMarkerDB(self)
                    return (db and db.font) or ROLE_MARKER_DEFAULT_FONT
                end,
                set = function(_, value)
                    local db = GetRoleMarkerDB(self)
                    if not db then return end
                    db.font = value
                    self:RefreshRoleMarkerIcons()
                end,
                disabled = IsRoleMarkerDisabled,
            },
            {
                name = L["FONT_SIZE"],
                desc = L["FONT_SIZE_DESC"],
                type = "range",
                min = 8,
                max = 32,
                step = 1,
                get = function()
                    local db = GetRoleMarkerDB(self)
                    return (db and db.fontSize) or ROLE_MARKER_DEFAULT_FONT_SIZE
                end,
                set = function(_, value)
                    local db = GetRoleMarkerDB(self)
                    if not db then return end
                    db.fontSize = value
                    self:RefreshRoleMarkerIcons()
                end,
                disabled = IsRoleMarkerDisabled,
            }),
            fontFlags = {
                name = L["FONT_FLAGS"],
                type = "select",
                order = 4.95,
                width = 1.25,
                sorting = KeystonePolaris.fontFlagPresetSorting,
                values = function()
                    return self:GetFontFlagSelectValues()
                end,
                get = function()
                    local db = GetRoleMarkerDB(self)
                    local stored = db and db.fontFlags
                    local vals = self:GetFontFlagSelectValues()
                    if stored and vals[stored] then
                        return stored
                    end
                    return KeystonePolaris.DEFAULT_FONT_FLAG_PRESET
                end,
                set = function(_, value)
                    local db = GetRoleMarkerDB(self)
                    if not db then return end
                    db.fontFlags = value or KeystonePolaris.DEFAULT_FONT_FLAG_PRESET
                    self:RefreshRoleMarkerIcons()
                end,
                disabled = IsRoleMarkerDisabled,
            },
            positionHeader = {
                order = 5,
                type = "header",
                name = L["KPL_RM_POSITION"],
            },
            anchorRow = ColumnRow(6, {
                name = L["SHOW_ANCHOR"],
                type = "execute",
                func = function()
                    HideUIPanel(SettingsPanel)
                    if self.EnterPositioningMode then
                        self:EnterPositioningMode("roleMarker")
                    end
                end,
                disabled = IsRoleMarkerDisabled,
            }, {
                name = L["KPL_RM_RESET_POSITION"],
                desc = L["KPL_RM_RESET_POSITION_DESC"],
                type = "execute",
                func = function()
                    local db = GetRoleMarkerDB(self)
                    if not db then return end
                    db.xOffset = KeystonePolaris.ROLE_MARKER_DEFAULT_X
                    db.yOffset = KeystonePolaris.ROLE_MARKER_DEFAULT_Y
                    self:ApplyRoleMarkerPosition()
                end,
                disabled = IsRoleMarkerDisabled,
            }),
            offsetRow = ColumnRow(7, {
                name = L["X_OFFSET"],
                type = "range",
                min = -math.ceil(GetScreenWidth()),
                max = math.ceil(GetScreenWidth()),
                step = 1,
                get = function()
                    local db = GetRoleMarkerDB(self)
                    return (db and db.xOffset) or 0
                end,
                set = function(_, value)
                    local db = GetRoleMarkerDB(self)
                    if not db then return end
                    db.xOffset = value
                    self:ApplyRoleMarkerPosition()
                end,
                disabled = IsRoleMarkerDisabled,
            }, {
                name = L["Y_OFFSET"],
                type = "range",
                min = -math.ceil(GetScreenHeight()),
                max = math.ceil(GetScreenHeight()),
                step = 1,
                get = function()
                    local db = GetRoleMarkerDB(self)
                    return (db and db.yOffset) or 0
                end,
                set = function(_, value)
                    local db = GetRoleMarkerDB(self)
                    if not db then return end
                    db.yOffset = value
                    self:ApplyRoleMarkerPosition()
                end,
                disabled = IsRoleMarkerDisabled,
            }),
        },
    }
end
