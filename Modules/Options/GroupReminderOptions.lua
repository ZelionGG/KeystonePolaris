local AddOnName, KeystonePolaris = ...;

local L = LibStub("AceLocale-3.0"):GetLocale(AddOnName, true)

function KeystonePolaris:GetGroupReminderOptions()
    return {
        name = L["KPL_GR_HEADER"] or "Group Reminder",
        type = "group",
        order = 7, -- Place it after Colors
        args = {
            header = {
                order = 0,
                type = "header",
                name = "|cffffd100" .. (L["KPL_GR_HEADER"] or "Group Reminder") .. "|r"
            },
            description = {
                order = 0.5,
                type = "description",
                name = L["KPL_GR_DESC_LONG"] or "Displays a reminder popup and/or chat message when you are accepted into a Mythic+ group, with a button to teleport to the dungeon.",
                fontSize = "medium",
            },
            enable = {
                name = L["ENABLE"] or "Enable",
                type = "toggle",
                width = "full",
                order = 1,
                get = function() return self.db.profile.groupReminder.enabled end,
                set = function(_, value)
                    self.db.profile.groupReminder.enabled = value
                    if value then self:InitializeGroupReminder() else self:DisableGroupReminder() end
                end,
            },
            notificationsHeader = {
                order = 2,
                type = "header",
                name = L["KPL_GR_NOTIFICATIONS"] or "Notifications",
            },
            showPopup = {
                name = L["KPL_GR_SHOW_POPUP"] or "Show popup",
                desc = L["KPL_GR_SHOW_POPUP_DESC"] or "Display the reminder window in the center of the screen.",
                type = "toggle",
                width = "full",
                order = 3,
                get = function() return self.db.profile.groupReminder.showPopup end,
                set = function(_, v) self.db.profile.groupReminder.showPopup = v end,
                disabled = function() return not self.db.profile.groupReminder.enabled end,
            },
            showChat = {
                name = L["KPL_GR_SHOW_CHAT"] or "Show chat message",
                desc = L["KPL_GR_SHOW_CHAT_DESC"] or "Print the reminder details in the chat window.",
                type = "toggle",
                width = "full",
                order = 4,
                get = function() return self.db.profile.groupReminder.showChat end,
                set = function(_, v) self.db.profile.groupReminder.showChat = v end,
                disabled = function() return not self.db.profile.groupReminder.enabled end,
            },
            reminderChatCommandInfo = {
                type = "description",
                name = L["KPL_GR_CHAT_COMMAND_INFO"] or "Tip: use |cffffd100/kpl reminder|r to show the last group reminder again.",
                order = 4.1,
                fontSize = "medium",
            },
            showPopupWhenGroupIsFull = {
                name = L["KPL_GR_SHOW_POPUP_WHEN_FULL"] or "Show popup again when the group is full",
                desc = L["KPL_GR_SHOW_POPUP_WHEN_FULL_DESC"] or "Reopen the reminder window when your Mythic+ group reaches 5 players.",
                type = "toggle",
                width = "full",
                order = 4.5,
                get = function() return self.db.profile.groupReminder.showPopupWhenGroupIsFull end,
                set = function(_, v)
                    self.db.profile.groupReminder.showPopupWhenGroupIsFull = v
                    if not v then
                        self.groupReminderPendingFullPopup = nil
                        self.groupReminderFullPopupShown = nil
                    else
                        self:HandleGroupRosterUpdate()
                    end
                end,
                disabled = function() return not self.db.profile.groupReminder.enabled end,
            },
            showPopupWhenGroupIsFullAsLeader = {
                name = L["KPL_GR_SHOW_POPUP_WHEN_FULL_LEADER"] or "Show popup when the group is full (as group leader)",
                desc = L["KPL_GR_SHOW_POPUP_WHEN_FULL_LEADER_DESC"] or "Display the reminder window when your listed Mythic+ group reaches 5 players while you are the group leader.",
                type = "toggle",
                width = "full",
                order = 4.6,
                get = function() return self.db.profile.groupReminder.showPopupWhenGroupIsFullAsLeader end,
                set = function(_, v)
                    self.db.profile.groupReminder.showPopupWhenGroupIsFullAsLeader = v
                    if not v then
                        self.groupReminderPendingLeaderFullPopup = nil
                        self.groupReminderLeaderFullPopupShown = nil
                    else
                        self:CaptureActiveListingReminder()
                        self:HandleGroupRosterUpdate()
                    end
                end,
                disabled = function() return not self.db.profile.groupReminder.enabled end,
            },
            suppressQuickJoinToast = {
                name = L["KPL_GR_SUPPRESS_TOAST"] or "Suppress Blizzard quick-join toast",
                desc = L["KPL_GR_SUPPRESS_TOAST_DESC"] or "Hide the default Blizzard popup that appears at the bottom of the screen when invited.",
                type = "toggle",
                width = "full",
                order = 5,
                get = function() return self.db.profile.groupReminder.suppressQuickJoinToast end,
                set = function(_, v)
                    self.db.profile.groupReminder.suppressQuickJoinToast = v
                    -- If turning suppression OFF while not in group, restore Blizzard UI now for future invites
                    if (not v) and (not IsInGroup()) and self.RestoreBlizzardJoinUI then
                        self:RestoreBlizzardJoinUI()
                    end
                end,
                disabled = function() return not self.db.profile.groupReminder.enabled end,
            },
            testCurrentSeason = {
                name = L["KPL_GR_TEST_CURRENT_SEASON"] or "Simulate current season acceptance",
                desc = L["KPL_GR_TEST_CURRENT_SEASON_DESC"] or "Show the group reminder using a dungeon from the current season.",
                type = "execute",
                width = "full",
                order = 6,
                func = function() self:TestGroupReminder() end,
                disabled = function() return not self.db.profile.groupReminder.enabled end,
            },
            resetPopupPosition = {
                name = "Reset popup position",
                desc = "Reset the group reminder popup to the center of the screen.",
                type = "execute",
                width = "full",
                order = 7,
                func = function()
                    self.db.profile.groupReminder.popupXOffset = 0
                    self.db.profile.groupReminder.popupYOffset = 0
                    if self.groupReminderStyledFrame then
                        self.groupReminderStyledFrame:ClearAllPoints()
                        self.groupReminderStyledFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
                    end
                end,
                disabled = function() return not self.db.profile.groupReminder.enabled end,
            },
            contentHeader = {
                order = 10,
                type = "header",
                name = L["KPL_GR_CONTENT"] or "Content",
            },
            showDungeonName = {
                name = L["KPL_GR_SHOW_DUNGEON"] or "Show dungeon name",
                type = "toggle",
                order = 11,
                get = function() return self.db.profile.groupReminder.showDungeonName end,
                set = function(_, v) self.db.profile.groupReminder.showDungeonName = v end,
                disabled = function() return not self.db.profile.groupReminder.enabled end,
            },
            showGroupName = {
                name = L["KPL_GR_SHOW_GROUP"] or "Show group name",
                type = "toggle",
                order = 12,
                get = function() return self.db.profile.groupReminder.showGroupName end,
                set = function(_, v) self.db.profile.groupReminder.showGroupName = v end,
                disabled = function() return not self.db.profile.groupReminder.enabled end,
            },
            showGroupDescription = {
                name = L["KPL_GR_SHOW_DESC"] or "Show group description",
                type = "toggle",
                order = 13,
                get = function() return self.db.profile.groupReminder.showGroupDescription end,
                set = function(_, v) self.db.profile.groupReminder.showGroupDescription = v end,
                disabled = function() return not self.db.profile.groupReminder.enabled end,
            },
            showAppliedRole = {
                name = L["KPL_GR_SHOW_ROLE"] or "Show applied role",
                type = "toggle",
                order = 14,
                get = function() return self.db.profile.groupReminder.showAppliedRole end,
                set = function(_, v) self.db.profile.groupReminder.showAppliedRole = v end,
                disabled = function() return not self.db.profile.groupReminder.enabled end,
            },
            showPlaystyle = {
                name = L["KPL_GR_SHOW_PLAYSTYLE"] or "Show playstyle",
                type = "toggle",
                order = 15,
                get = function() return self.db.profile.groupReminder.showPlaystyle end,
                set = function(_, v) self.db.profile.groupReminder.showPlaystyle = v end,
                disabled = function() return not self.db.profile.groupReminder.enabled end,
            },
        },
    }
end
