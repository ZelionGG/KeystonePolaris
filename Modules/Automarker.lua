local AddOnName, KeystonePolaris = ...
local L = LibStub("AceLocale-3.0"):GetLocale(AddOnName)

-- ---------------------------------------------------------------------------
-- Automarker Module
-- ---------------------------------------------------------------------------
-- Marks tank and healer with raid target icons in Mythic+ LFG groups as members join.
-- Raid markers are protected in Midnight (12.0+); marks use /tm via a secure UIParent button click.

local MARKER_TEXTURE_PREFIX = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_"

local function IsMythicPlusActivity(activityID)
    local t = C_LFGList.GetActivityInfoTable and C_LFGList.GetActivityInfoTable(activityID)
    if t and t.isMythicPlusActivity ~= nil then
        return not not t.isMythicPlusActivity
    end
    return false
end

local function GetActiveEntryActivityID()
    if not C_LFGList or not C_LFGList.GetActiveEntryInfo then return nil end
    local entry = C_LFGList.GetActiveEntryInfo()
    if not entry then return nil end
    return (entry.activityIDs and entry.activityIDs[1]) or entry.activityID
end

local function HasActiveMythicPlusListing()
    local activityID = GetActiveEntryActivityID()
    return activityID and IsMythicPlusActivity(activityID)
end

local function IsAutomarkerLfgContext()
    if IsPartyLFG and IsPartyLFG() then return true end
    return HasActiveMythicPlusListing()
end

local function GetMarkerSelectValues()
    local values = {}
    values[0] = string.format(" - %s - ", NONE or "None")
    for i = 1, 8 do
        local name = L["KPL_AM_MARKER_" .. i]
        values[i] = string.format("|T%s%d:20|t %s", MARKER_TEXTURE_PREFIX, i, name or tostring(i))
    end
    return values
end

local function GetAutomarkerMarkerSettings(db)
    local tankMarker = db.tankMarker
    if tankMarker == nil then tankMarker = 6 end
    local healerMarker = db.healerMarker
    if healerMarker == nil then healerMarker = 1 end
    return tankMarker, healerMarker
end

local function RoleMarkingEnabled(markerIndex)
    return markerIndex and markerIndex > 0
end

local function GetAutomarkerButtonText(tankMarker, healerMarker)
    local markTank = RoleMarkingEnabled(tankMarker)
    local markHeal = RoleMarkingEnabled(healerMarker)
    local prefix = L["KPL_AM_MARK"]
    if markTank and markHeal then
        return prefix .. " " .. TANK .. " / " .. HEALER
    elseif markTank then
        return prefix .. " " .. TANK
    elseif markHeal then
        return prefix .. " " .. HEALER
    end
end

local function GroupRolesAreReady()
    local playerRole = UnitGroupRolesAssigned("player")
    if playerRole == "NONE" then
        if not GetLFGRoles then return false end
        if not select(1, GetLFGRoles()) and not select(2, GetLFGRoles()) and not select(3, GetLFGRoles()) then
            return false
        end
    end

    local members = (GetNumGroupMembers and GetNumGroupMembers() or 1) - 1
    for i = 1, members do
        local unit = "party" .. i
        if UnitExists(unit) and UnitGroupRolesAssigned(unit) == "NONE" then
            return false
        end
    end

    return true
end

local function UnitMatchesRole(unit, role)
    if not unit or not UnitExists(unit) then return false end

    local assigned = UnitGroupRolesAssigned(unit)
    if assigned == role then return true end
    if unit ~= "player" or assigned ~= "NONE" then return false end
    if not GetLFGRoles then return false end

    if role == "TANK" then return select(1, GetLFGRoles()) end
    if role == "HEALER" then return select(2, GetLFGRoles()) end
    if role == "DAMAGER" then return select(3, GetLFGRoles()) end
    return false
end

local function CollectPendingMarks(tankMarker, healerMarker)
    local marks = {}
    local function consider(unit, role, markerIndex)
        if not RoleMarkingEnabled(markerIndex) then return end
        if not UnitMatchesRole(unit, role) then return end
        if GetRaidTargetIndex(unit) == markerIndex then return end
        marks[#marks + 1] = { unit = unit, index = markerIndex }
    end

    consider("player", "TANK", tankMarker)
    consider("player", "HEALER", healerMarker)

    local members = (GetNumGroupMembers and GetNumGroupMembers() or 1) - 1
    for i = 1, members do
        local unit = "party" .. i
        consider(unit, "TANK", tankMarker)
        consider(unit, "HEALER", healerMarker)
    end

    return marks
end

local function BuildMarkMacro(marks)
    if #marks == 0 then return nil end
    local lines = {}
    for i = 1, #marks do
        local mark = marks[i]
        lines[i] = string.format("/tm [@%s] !%d", mark.unit, mark.index)
    end
    return table.concat(lines, "\n")
end

function KeystonePolaris:SyncAutomarkerFromCurrentState()
    if not IsInGroup or not IsInGroup() then return end
    if IsInRaid and IsInRaid() then return end
    if not IsAutomarkerLfgContext() then return end
    self:ArmAutomarkerPending()
end

function KeystonePolaris:ScheduleAutomarkerRoleRetry()
    self._automarkerRoleRetries = (self._automarkerRoleRetries or 0) + 1
    if self._automarkerRoleRetries > 6 then return end
    C_Timer.After(0.5, function()
        self:ApplyTankHealerMarks()
    end)
end

function KeystonePolaris:ScheduleAutomarkerStartupSync()
    self:SyncAutomarkerFromCurrentState()
    C_Timer.After(0.5, function() self:SyncAutomarkerFromCurrentState() end)
    C_Timer.After(1.5, function() self:SyncAutomarkerFromCurrentState() end)
end

function KeystonePolaris:EnsureAutomarkerSecureButton()
    if self.automarkerSecureButton then return self.automarkerSecureButton end

    local btn = CreateFrame("Button", "KeystonePolarisAutomarkerButton", UIParent, "SecureActionButtonTemplate, UIPanelButtonTemplate")
    btn:SetHeight(28)
    btn:SetPoint("TOP", UIParent, "TOP", 0, -120)
    btn:SetFrameStrata("DIALOG")
    btn:EnableMouse(true)
    btn:RegisterForClicks("AnyUp", "AnyDown")

    if btn.GetFontString then
        local fs = btn:GetFontString()
        if fs then
            fs:SetTextColor(1, 0.82, 0, 1)
        end
    end

    btn:SetScript("PostClick", function()
        C_Timer.After(0.3, function()
            if KeystonePolaris.ApplyTankHealerMarks then
                KeystonePolaris:ApplyTankHealerMarks()
            end
        end)
    end)

    btn:Hide()
    self.automarkerSecureButton = btn
    return btn
end

function KeystonePolaris:HideAutomarkerButton()
    if self.automarkerSecureButton then
        self.automarkerSecureButton:Hide()
    end
    self._pendingAutomarkerShow = nil
end

function KeystonePolaris:EnsureAutomarkerCombatWatcher()
    if self._automarkerCombatWatcher then return end

    local watcher = CreateFrame("Frame")
    watcher:RegisterEvent("PLAYER_REGEN_ENABLED")
    watcher:SetScript("OnEvent", function()
        local pending = self._pendingAutomarkerShow
        if pending and not InCombatLockdown() then
            self._pendingAutomarkerShow = nil
            self:ShowAutomarkerButton(pending.macroText, pending.tankMarker, pending.healerMarker)
        end
    end)
    self._automarkerCombatWatcher = watcher
end

function KeystonePolaris:ShowAutomarkerButton(macroText, tankMarker, healerMarker)
    if not macroText then return end
    self:EnsureAutomarkerSecureButton()

    if InCombatLockdown() then
        self._pendingAutomarkerShow = {
            macroText = macroText,
            tankMarker = tankMarker,
            healerMarker = healerMarker,
        }
        self:EnsureAutomarkerCombatWatcher()
        return
    end

    local btn = self.automarkerSecureButton
    local label = GetAutomarkerButtonText(tankMarker, healerMarker) or L["KPL_AM_MARK"]
    btn:SetText(label)
    btn:SetWidth(math.max(180, (#label * 7) + 24))
    btn:SetAttribute("type", "macro")
    btn:SetAttribute("macrotext", macroText)
    btn:Show()
    self._pendingAutomarkerShow = nil
end

function KeystonePolaris:ApplyTankHealerMarks()
    local db = self.db and self.db.profile and self.db.profile.automarker
    if not db or not db.enabled then
        self:HideAutomarkerButton()
        return
    end
    if db.onlyWhenLeader and not UnitIsGroupLeader("player") then
        self:HideAutomarkerButton()
        return
    end

    local tankMarker, healerMarker = GetAutomarkerMarkerSettings(db)
    if not RoleMarkingEnabled(tankMarker) and not RoleMarkingEnabled(healerMarker) then
        self:HideAutomarkerButton()
        return
    end

    local macroText = BuildMarkMacro(CollectPendingMarks(tankMarker, healerMarker))
    if not macroText then
        if not GroupRolesAreReady() and (self._automarkerRoleRetries or 0) < 6 then
            self:ScheduleAutomarkerRoleRetry()
            return
        end
        self._automarkerRoleRetries = nil
        self:HideAutomarkerButton()
        return
    end

    self._automarkerRoleRetries = nil
    self:ShowAutomarkerButton(macroText, tankMarker, healerMarker)
end

function KeystonePolaris:ResetAutomarkerTracking()
    self.automarkerPending = nil
    self._automarkerRoleRetries = nil
    self:HideAutomarkerButton()
end

function KeystonePolaris:ArmAutomarkerPending()
    self.automarkerPending = true
    C_Timer.After(0.2, function()
        self:HandleAutomarkerRosterUpdate()
    end)
end

function KeystonePolaris:HandleAutomarkerRosterUpdate()
    local db = self.db and self.db.profile and self.db.profile.automarker
    if not db or not db.enabled then return end
    if not self.automarkerPending then return end
    if not IsInGroup or not IsInGroup() then return end
    if IsInRaid and IsInRaid() then return end
    if not IsAutomarkerLfgContext() then return end

    C_Timer.After(0.2, function()
        self:ApplyTankHealerMarks()
    end)
end

function KeystonePolaris:HandleAutomarkerActiveEntryUpdate()
    if HasActiveMythicPlusListing() then
        self:ArmAutomarkerPending()
        return
    end
    if IsPartyLFG and IsPartyLFG() then return end
    self:ResetAutomarkerTracking()
end

function KeystonePolaris:InitializeAutomarker()
    if self.automarkerFrame then
        self:UpdateAutomarkerRegistration()
        return
    end

    self.automarkerFrame = CreateFrame("Frame")
    self.automarkerFrame:RegisterEvent("LFG_LIST_APPLICATION_STATUS_UPDATED")
    self.automarkerFrame:RegisterEvent("LFG_LIST_ACTIVE_ENTRY_UPDATE")
    self.automarkerFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
    self.automarkerFrame:RegisterEvent("GROUP_LEFT")
    self.automarkerFrame:RegisterEvent("PLAYER_ENTERING_WORLD")

    self.automarkerFrame:SetScript("OnEvent", function(_, event, ...)
        if event == "GROUP_LEFT" then
            self:ResetAutomarkerTracking()
            return
        end
        if event == "PLAYER_ENTERING_WORLD" then
            self:ScheduleAutomarkerStartupSync()
            return
        end
        if event == "GROUP_ROSTER_UPDATE" then
            self:HandleAutomarkerRosterUpdate()
            return
        end
        if event == "LFG_LIST_ACTIVE_ENTRY_UPDATE" then
            self:HandleAutomarkerActiveEntryUpdate()
            return
        end
        if event ~= "LFG_LIST_APPLICATION_STATUS_UPDATED" then return end

        local searchResultID, newStatus = ...
        if not searchResultID or newStatus ~= "inviteaccepted" then return end

        local srd = C_LFGList.GetSearchResultInfo(searchResultID)
        if not srd then return end

        local activityID = (srd.activityIDs and srd.activityIDs[1]) or srd.activityID
        if not activityID or not IsMythicPlusActivity(activityID) then return end

        self:ArmAutomarkerPending()
    end)

    self:ScheduleAutomarkerStartupSync()
end

function KeystonePolaris:DisableAutomarker()
    if self.automarkerFrame then
        self.automarkerFrame:UnregisterAllEvents()
    end
    self:HideAutomarkerButton()
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
        self.automarkerFrame:RegisterEvent("LFG_LIST_ACTIVE_ENTRY_UPDATE")
        self.automarkerFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
        self.automarkerFrame:RegisterEvent("GROUP_LEFT")
        self.automarkerFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
        self:ScheduleAutomarkerStartupSync()
    else
        self:DisableAutomarker()
    end
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
            markerRow = ColumnRow(2, {
                name = L["KPL_AM_TANK_MARKER"],
                type = "select",
                order = 2,
                values = markerValues,
                get = function() return self.db.profile.automarker.tankMarker end,
                set = function(_, value)
                    self.db.profile.automarker.tankMarker = value
                    self:ApplyTankHealerMarks()
                end,
                disabled = function() return not self.db.profile.automarker.enabled end,
            }, {
                name = L["KPL_AM_HEALER_MARKER"],
                type = "select",
                order = 3,
                values = markerValues,
                get = function() return self.db.profile.automarker.healerMarker end,
                set = function(_, value)
                    self.db.profile.automarker.healerMarker = value
                    self:ApplyTankHealerMarks()
                end,
                disabled = function() return not self.db.profile.automarker.enabled end,
            }),
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
