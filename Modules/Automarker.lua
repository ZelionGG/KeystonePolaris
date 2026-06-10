local AddOnName, KeystonePolaris = ...
local L = LibStub("AceLocale-3.0"):GetLocale(AddOnName)

-- ---------------------------------------------------------------------------
-- Automarker Module
-- ---------------------------------------------------------------------------
-- Marks tank and healer with raid target icons when a Mythic+ LFG group reaches 5 players.

local MARKER_TEXTURE_PREFIX = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_"

local function IsMythicPlusActivity(activityID)
    local t = C_LFGList.GetActivityInfoTable and C_LFGList.GetActivityInfoTable(activityID)
    if t and t.isMythicPlusActivity ~= nil then
        return not not t.isMythicPlusActivity
    end
    return false
end

local function IsCurrentGroupFull()
    if not IsInGroup or not IsInGroup() then return false end
    if IsInRaid and IsInRaid() then return false end
    return (GetNumGroupMembers and GetNumGroupMembers() or 0) >= 5
end

local function GetMarkerSelectValues()
    local values = {}
    for i = 1, 8 do
        local name = L["KPL_AM_MARKER_" .. i]
        values[i] = string.format("|T%s%d:20|t %s", MARKER_TEXTURE_PREFIX, i, name or tostring(i))
    end
    return values
end

local function MarkRoleUnit(unit, role, markerIndex)
    if not unit or not UnitExists(unit) then return end
    if UnitGroupRolesAssigned(unit) ~= role then return end
    if GetRaidTargetIndex(unit) == markerIndex then return end
    SetRaidTarget(unit, markerIndex)
end

function KeystonePolaris:ApplyTankHealerMarks()
    local db = self.db and self.db.profile and self.db.profile.automarker
    if not db or not db.enabled then return end
    if db.onlyWhenLeader and not UnitIsGroupLeader("player") then return end
    if UnitAffectingCombat and UnitAffectingCombat("player") then return end

    local tankMarker = tonumber(db.tankMarker) or 6
    local healerMarker = tonumber(db.healerMarker) or 1

    MarkRoleUnit("player", "TANK", tankMarker)
    MarkRoleUnit("player", "HEALER", healerMarker)

    local members = (GetNumGroupMembers and GetNumGroupMembers() or 1) - 1
    for i = 1, members do
        local unit = "party" .. i
        MarkRoleUnit(unit, "TANK", tankMarker)
        MarkRoleUnit(unit, "HEALER", healerMarker)
    end
end

function KeystonePolaris:ResetAutomarkerTracking()
    self.automarkerPendingFull = nil
    self.automarkerApplied = nil
end

function KeystonePolaris:HandleAutomarkerRosterUpdate()
    local db = self.db and self.db.profile and self.db.profile.automarker
    if not db or not db.enabled then return end
    if not self.automarkerPendingFull or self.automarkerApplied then return end
    if not IsCurrentGroupFull() then return end
    if IsPartyLFG and not IsPartyLFG() then return end

    self.automarkerApplied = true
    C_Timer.After(0.2, function()
        self:ApplyTankHealerMarks()
    end)
end

function KeystonePolaris:InitializeAutomarker()
    if self.automarkerFrame then
        self:UpdateAutomarkerRegistration()
        return
    end

    self.automarkerFrame = CreateFrame("Frame")
    self.automarkerFrame:RegisterEvent("LFG_LIST_APPLICATION_STATUS_UPDATED")
    self.automarkerFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
    self.automarkerFrame:RegisterEvent("GROUP_LEFT")

    self.automarkerFrame:SetScript("OnEvent", function(_, event, ...)
        if event == "GROUP_LEFT" then
            self:ResetAutomarkerTracking()
            return
        end
        if event == "GROUP_ROSTER_UPDATE" then
            self:HandleAutomarkerRosterUpdate()
            return
        end
        if event ~= "LFG_LIST_APPLICATION_STATUS_UPDATED" then return end

        local searchResultID, newStatus = ...
        if not searchResultID or newStatus ~= "inviteaccepted" then return end

        local srd = C_LFGList.GetSearchResultInfo(searchResultID)
        if not srd then return end

        local activityID = (srd.activityIDs and srd.activityIDs[1]) or srd.activityID
        if not activityID or not IsMythicPlusActivity(activityID) then return end

        self.automarkerPendingFull = true
        C_Timer.After(0.2, function()
            self:HandleAutomarkerRosterUpdate()
        end)
    end)
end

function KeystonePolaris:DisableAutomarker()
    if self.automarkerFrame then
        self.automarkerFrame:UnregisterAllEvents()
    end
end

function KeystonePolaris:UpdateAutomarkerRegistration()
    local db = self.db and self.db.profile and self.db.profile.automarker
    if not db then return end
    if db.enabled then
        if not self.automarkerFrame then
            self:InitializeAutomarker()
            return
        end
        self.automarkerFrame:RegisterEvent("LFG_LIST_APPLICATION_STATUS_UPDATED")
        self.automarkerFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
        self.automarkerFrame:RegisterEvent("GROUP_LEFT")
    else
        self:DisableAutomarker()
    end
end

function KeystonePolaris:GetAutomarkerOptions()
    local markerValues = GetMarkerSelectValues()

    return {
        name = L["KPL_AM_HEADER"],
        type = "group",
        order = 8,
        args = {
            header = {
                order = 0,
                type = "header",
                name = "|cffffd100" .. L["KPL_AM_HEADER"] .. "|r",
            },
            description = {
                order = 0.5,
                type = "description",
                name = L["KPL_AM_DESC_LONG"],
                fontSize = "medium",
            },
            enable = {
                name = L["ENABLE"],
                type = "toggle",
                width = "full",
                order = 1,
                get = function() return self.db.profile.automarker.enabled end,
                set = function(_, value)
                    self.db.profile.automarker.enabled = value
                    if value then
                        self:InitializeAutomarker()
                    else
                        self:DisableAutomarker()
                        self:ResetAutomarkerTracking()
                    end
                end,
            },
            tankMarker = {
                name = L["KPL_AM_TANK_MARKER"],
                type = "select",
                width = "full",
                order = 2,
                values = markerValues,
                get = function() return self.db.profile.automarker.tankMarker end,
                set = function(_, value)
                    if value == self.db.profile.automarker.healerMarker then return end
                    self.db.profile.automarker.tankMarker = value
                end,
                disabled = function() return not self.db.profile.automarker.enabled end,
            },
            healerMarker = {
                name = L["KPL_AM_HEALER_MARKER"],
                type = "select",
                width = "full",
                order = 3,
                values = markerValues,
                get = function() return self.db.profile.automarker.healerMarker end,
                set = function(_, value)
                    if value == self.db.profile.automarker.tankMarker then return end
                    self.db.profile.automarker.healerMarker = value
                end,
                disabled = function() return not self.db.profile.automarker.enabled end,
            },
            onlyWhenLeader = {
                name = L["KPL_AM_ONLY_WHEN_LEADER"],
                desc = L["KPL_AM_ONLY_WHEN_LEADER_DESC"],
                type = "toggle",
                width = "full",
                order = 4,
                get = function() return self.db.profile.automarker.onlyWhenLeader end,
                set = function(_, value)
                    self.db.profile.automarker.onlyWhenLeader = value
                end,
                disabled = function() return not self.db.profile.automarker.enabled end,
            },
        },
    }
end
