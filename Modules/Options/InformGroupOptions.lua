local AddOnName, KeystonePolaris = ...;

local L = LibStub("AceLocale-3.0"):GetLocale(AddOnName, true)

local ColumnRow = KeystonePolaris.ColumnRow

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

