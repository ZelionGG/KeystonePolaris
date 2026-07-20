local AddOnName, KeystonePolaris = ...;

local L = LibStub("AceLocale-3.0"):GetLocale(AddOnName, true)

local ColumnRow = KeystonePolaris.ColumnRow

function KeystonePolaris:GetInterfaceOptions()
    return {
        name = L["INTERFACE"],
        type = "group",
        order = 7,
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

