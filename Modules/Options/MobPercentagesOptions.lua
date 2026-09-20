local AddOnName, KeystonePolaris = ...;

local _G = _G
local C_ScenarioInfo = _G.C_ScenarioInfo

local L = LibStub("AceLocale-3.0"):GetLocale(AddOnName, true)

local function HasMobPercentagesAPI()
    return C_ScenarioInfo and type(C_ScenarioInfo.GetUnitCriteriaProgressValues) == "function"
end

function KeystonePolaris:GetMobPercentagesOptions()
    local function IsMobPercentagesOptionsDisabled()
        return (not self.db.profile.mobPercentages.enabled) or (not HasMobPercentagesAPI())
    end

    return {
        name = L["MOB_PERCENTAGES"],
        type = "group",
        order = 4,
        args = {
            mdtWarning = {
                name = function()
                    return HasMobPercentagesAPI() and L["MOB_PERCENTAGES_API_FOUND"] or L["MOB_PERCENTAGES_API_WARNING"]
                end,
                type = "description",
                order = 0,
                fontSize = "medium",
            },
            mobIndicatorHeader = {
                name = L["MOB_PERCENTAGES"],
                type = "header",
                order = 1,
            },
            enableLocked = {
                name = "|cff9d9d9d" .. L["ENABLE"] .. "|r",
                desc = L["MOB_PERCENTAGES_API_UNAVAILABLE"],
                type = "description",
                dialogControl = "InteractiveLabel",
                order = 1,
                width = 1.4,
                hidden = function() return HasMobPercentagesAPI() end,
                image = "Interface\\PetBattles\\PetBattle-LockIcon",
                imageWidth = 20,
                imageHeight = 20,
                fontSize = "medium",
            },
            enable = {
                name = L["ENABLE"],
                desc = L["ENABLE_MOB_PERCENTAGES_DESC"],
                type = "toggle",
                width = "full",
                order = 2,
                hidden = function() return not HasMobPercentagesAPI() end,
                get = function() return self.db.profile.mobPercentages.enabled end,
                set = function(_, value)
                    self.db.profile.mobPercentages.enabled = value and true or false
                    if value then
                        self:InitializeMobPercentages()
                    else
                        if self.mobPercentFrame then
                            self.mobPercentFrame:UnregisterAllEvents()
                        end
                        self:HideAllMobPercentageFrames()
                    end
                end,
                disabled = function()
                    return not HasMobPercentagesAPI()
                end
            },
            displayOptions = {
                name = L["DISPLAY_OPTIONS"],
                type = "group",
                inline = true,
                order = 3,
                disabled = function()
                    return IsMobPercentagesOptionsDisabled()
                end,
                args = {
                    showPercent = {
                        name = L["SHOW_PERCENTAGE"],
                        desc = L["SHOW_PERCENTAGE_DESC"],
                        type = "toggle",
                        order = 1,
                        width = "full",
                        get = function() return self.db.profile.mobPercentages.showPercent end,
                        set = function(_, value)
                            self.db.profile.mobPercentages.showPercent = value
                            self:RefreshMobPercentageFrames()
                        end,
                        disabled = function()
                            return IsMobPercentagesOptionsDisabled()
                        end
                    },
                    showCount = {
                        name = L["SHOW_COUNT"],
                        desc = L["SHOW_COUNT_DESC"],
                        type = "toggle",
                        order = 2,
                        width = "full",
                        get = function() return self.db.profile.mobPercentages.showCount end,
                        set = function(_, value)
                            self.db.profile.mobPercentages.showCount = value
                            self:RefreshMobPercentageFrames()
                        end,
                        disabled = function()
                            return IsMobPercentagesOptionsDisabled()
                        end
                    },
                    showTotal = {
                        name = L["SHOW_TOTAL"],
                        desc = L["SHOW_TOTAL_DESC"],
                        type = "toggle",
                        order = 3,
                        width = "full",
                        get = function() return self.db.profile.mobPercentages.showTotal end,
                        set = function(_, value)
                            self.db.profile.mobPercentages.showTotal = value
                            self:RefreshMobPercentageFrames()
                        end,
                        disabled = function()
                            return IsMobPercentagesOptionsDisabled() or (not self.db.profile.mobPercentages.showCount)
                        end
                    },
                    customFormat = {
                        name = L["CUSTOM_FORMAT"],
                        desc = L["CUSTOM_FORMAT_DESC"],
                        type = "input",
                        order = 4,
                        width = 1.5,
                        get = function()
                            local v = self.db.profile.mobPercentages.customFormat
                            if not v or v == "" then return "(%s)" end
                            return v
                        end,
                        set = function(_, value)
                            local v = (value or ""):gsub("^%s+", ""):gsub("%s+$", "")
                            if v == "" then v = "(%s)" end
                            self.db.profile.mobPercentages.customFormat = v
                            self:RefreshMobPercentageFrames()
                        end,
                        disabled = function()
                            return IsMobPercentagesOptionsDisabled()
                        end
                    },
                    resetCustomFormat = {
                        name = L["RESET_TO_DEFAULT"],
                        desc = L["RESET_FORMAT_DESC"],
                        type = "execute",
                        order = 5,
                        width = 0.5,
                        func = function()
                            self.db.profile.mobPercentages.customFormat = "(%s)"
                            self:RefreshMobPercentageFrames()
                        end,
                        disabled = function()
                            return IsMobPercentagesOptionsDisabled()
                        end
                    },
                }
            },
            appearanceOptions = {
                name = L["APPEARANCE_OPTIONS"],
                type = "group",
                inline = true,
                order = 4,
                disabled = function()
                    return IsMobPercentagesOptionsDisabled()
                end,
                args = {
                    fontSize = {
                        name = L["MOB_PERCENTAGE_FONT_SIZE"],
                        desc = L["MOB_PERCENTAGE_FONT_SIZE_DESC"],
                        type = "range",
                        order = 1,
                        min = 6,
                        max = 32,
                        step = 1,
                        get = function() return self.db.profile.mobPercentages.fontSize end,
                        set = function(_, value)
                            self.db.profile.mobPercentages.fontSize = value
                            for _, frame in pairs(self.nameplateTextFrames or {}) do
                                frame.text:SetFont(self.LSM:Fetch('font', self.db.profile.text.font), value, self:GetFontFlags())
                            end
                        end,
                        disabled = function()
                            return IsMobPercentagesOptionsDisabled()
                        end
                    },
                    textColor = {
                        name = L["TEXT_COLOR"],
                        desc = L["TEXT_COLOR_DESC"],
                        type = "color",
                        order = 2,
                        hasAlpha = true,
                        get = function() return self.db.profile.mobPercentages.textColor.r, self.db.profile.mobPercentages.textColor.g, self.db.profile.mobPercentages.textColor.b, self.db.profile.mobPercentages.textColor.a end,
                        set = function(_, r, g, b, a)
                            KeystonePolaris.SetColorTable(self.db.profile.mobPercentages.textColor, r, g, b, a)
                            for _, frame in pairs(self.nameplateTextFrames or {}) do
                                frame.text:SetTextColor(r, g, b, a)
                            end
                        end,
                        disabled = function()
                            return IsMobPercentagesOptionsDisabled()
                        end
                    },
                    position = {
                        name = L["MOB_PERCENTAGE_POSITION"],
                        desc = L["MOB_PERCENTAGE_POSITION_DESC"],
                        type = "select",
                        order = 4,
                        values = {
                            RIGHT = L["RIGHT"],
                            LEFT = L["LEFT"],
                            TOP = L["TOP"],
                            BOTTOM = L["BOTTOM"]
                        },
                        get = function() return self.db.profile.mobPercentages.position end,
                        set = function(_, value)
                            self.db.profile.mobPercentages.position = value
                            for unit in pairs(self.nameplateTextFrames or {}) do
                                self:UpdateNameplatePosition(unit)
                            end
                        end,
                        disabled = function()
                            return IsMobPercentagesOptionsDisabled()
                        end
                    },
                    xOffset = {
                        name = L["X_OFFSET"],
                        desc = L["X_OFFSET_DESC"],
                        type = "range",
                        order = 5,
                        min = -100,
                        max = 100,
                        step = 1,
                        get = function() return self.db.profile.mobPercentages.xOffset end,
                        set = function(_, value)
                            self.db.profile.mobPercentages.xOffset = value
                            for unit in pairs(self.nameplateTextFrames or {}) do
                                self:UpdateNameplatePosition(unit)
                            end
                        end,
                        disabled = function()
                            return IsMobPercentagesOptionsDisabled()
                        end
                    },
                    yOffset = {
                        name = L["Y_OFFSET"],
                        desc = L["Y_OFFSET_DESC"],
                        type = "range",
                        order = 6,
                        min = -100,
                        max = 100,
                        step = 1,
                        get = function() return self.db.profile.mobPercentages.yOffset end,
                        set = function(_, value)
                            self.db.profile.mobPercentages.yOffset = value
                            for unit in pairs(self.nameplateTextFrames or {}) do
                                self:UpdateNameplatePosition(unit)
                            end
                        end,
                        disabled = function()
                            return IsMobPercentagesOptionsDisabled()
                        end
                    },
                }
            }
        }
    }
end
