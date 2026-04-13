local AddOnName, KeystonePolaris = ...
local L = LibStub("AceLocale-3.0"):GetLocale(AddOnName)
local _G = _G
local Enum = _G.Enum
local GROUP_FINDER_GENERAL_PLAYSTYLE1 = _G.GROUP_FINDER_GENERAL_PLAYSTYLE1
local GROUP_FINDER_GENERAL_PLAYSTYLE2 = _G.GROUP_FINDER_GENERAL_PLAYSTYLE2
local GROUP_FINDER_GENERAL_PLAYSTYLE3 = _G.GROUP_FINDER_GENERAL_PLAYSTYLE3
local GROUP_FINDER_GENERAL_PLAYSTYLE4 = _G.GROUP_FINDER_GENERAL_PLAYSTYLE4
local ENCOUNTER_JOURNAL_INSTANCE = _G.ENCOUNTER_JOURNAL_INSTANCE
local GROUP = _G.GROUP
local DESCRIPTION = _G.DESCRIPTION
local GROUP_FINDER_FILTER_PLAYSTYLE = _G.GROUP_FINDER_FILTER_PLAYSTYLE
local ROLE = _G.ROLE
local TELEPORT_TO_DUNGEON = _G.TELEPORT_TO_DUNGEON

-- ---------------------------------------------------------------------------
-- Group Reminder Module
-- ---------------------------------------------------------------------------
-- Minimal Group Reminder with simple options: enable, showPopup, showChat
-- Triggers on 'inviteaccepted' only and filters to Mythic+ activities

-- Track the role used at application time by searchResultID
KeystonePolaris.groupReminderRoleByResult = {}

-- Hook ApplyToGroup to capture the role flags used for each application
if C_LFGList and C_LFGList.ApplyToGroup then
    hooksecurefunc(C_LFGList, "ApplyToGroup", function(searchResultID, tank, heal, dps)
        if tank then
            KeystonePolaris.groupReminderRoleByResult[searchResultID] = "Tank"
        elseif heal then
            KeystonePolaris.groupReminderRoleByResult[searchResultID] = "Healer"
        elseif dps then
            KeystonePolaris.groupReminderRoleByResult[searchResultID] = "Damage"
        else
            KeystonePolaris.groupReminderRoleByResult[searchResultID] = "-"
        end
    end)
end

-- Internal helpers
local function IsMythicPlusActivity(activityID)
    local t = C_LFGList.GetActivityInfoTable and C_LFGList.GetActivityInfoTable(activityID)
    if t and t.isMythicPlusActivity ~= nil then
        return not not t.isMythicPlusActivity
    end
    return false
end

local function GetAppliedRoleText(searchResultID)
    -- Prefer the role actually assigned in the group (after join)
    if type(UnitGroupRolesAssigned) == "function" then
        local assigned = UnitGroupRolesAssigned("player")
        if assigned == "TANK" then return TANK end
        if assigned == "HEALER" then return HEALER end
        if assigned == "DAMAGER" then return DAMAGER end
    end

    -- Prefer role captured at application time
    local role = KeystonePolaris.groupReminderRoleByResult and KeystonePolaris.groupReminderRoleByResult[searchResultID]
    if role then
        if role == "Tank" then return TANK end
        if role == "Healer" then return HEALER end
        if role == "Damage" then return DAMAGER end
        return role
    end
    -- Fallback to current LFG role flags
    local tank, heal, dps = GetLFGRoles()
    if tank then return TANK end
    if heal then return HEALER end
    if dps then return DAMAGER end
    return "-"
end

local function GetTeleportCandidatesForMapIDLocal(self, mapID)
    if not mapID then return nil end
    if type(self.GetTeleportCandidatesForMapID) == "function" then
        return self:GetTeleportCandidatesForMapID(mapID)
    end

    if type(self.GlobalDungeonLookup) == "table" then
        for _, d in pairs(self.GlobalDungeonLookup) do
            if type(d) == "table" and d.mapID == mapID and d.teleportID ~= nil then
                return d.teleportID
            end
        end
    end

    if type(self.Expansions) ~= "table" then return nil end
    for _, expansion in ipairs(self.Expansions) do
        local expansionId = type(expansion) == "table" and expansion.id
        local data = expansionId and self[expansionId .. "_DUNGEON_DATA"]
        if type(data) == "table" then
            for _, d in pairs(data) do
                if type(d) == "table" and d.mapID == mapID and d.teleportID ~= nil then
                    return d.teleportID
                end
            end
        end
    end
    return nil
end

local function GetRoleIconTag(roleText)
    if type(roleText) ~= "string" then return "" end
    local up = string.upper(roleText)
    local roleKey

    if up == "TANK" or roleText == TANK then
        roleKey = "TANK"
    elseif up == "HEALER" or roleText == HEALER then
        roleKey = "HEALER"
    elseif up == "DAMAGER" or up == "DAMAGE" or roleText == DAMAGER then
        roleKey = "DAMAGER"
    end
    if not roleKey then return "" end

    local size = 14
    local atlasCandidates = {
        TANK = {"roleicon-tank", "roleicon-tiny-tank"},
        HEALER = {"roleicon-healer", "roleicon-tiny-healer"},
        DAMAGER = {"roleicon-dps", "roleicon-tiny-dps"},
    }
    local candidates = atlasCandidates[roleKey]
    if candidates then
        if C_Texture and C_Texture.GetAtlasInfo then
            for _, name in ipairs(candidates) do
                if C_Texture.GetAtlasInfo(name) then
                    return string.format("|A:%s:%d:%d|a", name, size, size)
                end
            end
        else
            return string.format("|A:%s:%d:%d|a", candidates[1], size, size)
        end
    end

    local left, right, top, bottom
    if GetTexCoordsForRoleSmallCircle then
        left, right, top, bottom = GetTexCoordsForRoleSmallCircle(roleKey)

    elseif GetTexCoordsForRole then
        left, right, top, bottom = GetTexCoordsForRole(roleKey)
    elseif roleKey == "TANK" then
        left, right, top, bottom = 0, 0.25, 0, 0.25
    elseif roleKey == "HEALER" then
        left, right, top, bottom = 0.25, 0.5, 0, 0.25
    else
        left, right, top, bottom = 0.5, 0.75, 0, 0.25
    end

    return string.format("|T%s:%d:%d:0:0:64:64:%.3f:%.3f:%.3f:%.3f|t", "Interface\\LFGFrame\\UI-LFG-ICON-ROLES", size, size, left, right, top, bottom)
end

local function GetGroupReminderHeaderLabel()
    local headerText = (L["KPL_GR_HEADER"] or "Group Reminder")
    local addonName = (KeystonePolaris.GetGradientAddonName and KeystonePolaris:GetGradientAddonName()) or "Keystone Polaris"
    return addonName .. "|r - |cffffd700" .. headerText .. "|r"
end

local function BuildMessages(db, zoneText, groupName, roleText, playstyle)
    local details = {}
    local valueColor = "|cffff6a00"

    if db.showDungeonName then
        table.insert(details, valueColor .. (zoneText or "-") .. "|r")
    end
    if db.showGroupName then
        table.insert(details, valueColor .. (groupName or "-") .. "|r")
    end
    if db.showPlaystyle then
        table.insert(details, valueColor .. (playstyle or "-") .. "|r")
    end

    local body = ""
    if #details > 0 or db.showAppliedRole then
        body = (L["KPL_GR_INVITED"] or "You have been invited to")
        if #details > 0 then
            body = body .. " " .. table.concat(details, ", ")
        end
        if db.showAppliedRole then
            local roleLabel = string.format((L["KPL_GR_AS_ROLE"] or "as a %s"), valueColor .. (roleText or "-") .. "|r")
            local roleIcon = GetRoleIconTag(roleText)
            if roleIcon ~= "" then
                roleLabel = roleLabel .. " " .. roleIcon
            end
            if #details > 0 then
                body = body .. ", " .. roleLabel
            else
                body = body .. " " .. roleLabel
            end
        end
    end

    local headerLabel = GetGroupReminderHeaderLabel()
    local popupMsg
    if body ~= "" then
        popupMsg = headerLabel .. " " .. body
    else
        popupMsg = headerLabel
    end

    return popupMsg, body
end

local GENERAL_PLAYSTYLE_TEXT_BY_VALUE = {
    [Enum.LFGEntryGeneralPlaystyle.Learning] = GROUP_FINDER_GENERAL_PLAYSTYLE1,
    [Enum.LFGEntryGeneralPlaystyle.FunRelaxed] = GROUP_FINDER_GENERAL_PLAYSTYLE2,
    [Enum.LFGEntryGeneralPlaystyle.FunSerious] = GROUP_FINDER_GENERAL_PLAYSTYLE3,
    [Enum.LFGEntryGeneralPlaystyle.Expert] = GROUP_FINDER_GENERAL_PLAYSTYLE4,
}

-- Clickable chat link handler: opens the reminder popup again
if not KeystonePolaris._KPL_ReminderChatLinkHooked then
    KeystonePolaris._KPL_ReminderChatLinkHooked = true
    hooksecurefunc("SetItemRef", function(link)
        if type(link) ~= "string" then return end
        local linkType = strsplit(":", link, 2)
        if linkType ~= "kphreminder" then return end

        if KeystonePolaris and KeystonePolaris.ShowLastGroupReminder then
            KeystonePolaris:ShowLastGroupReminder()
        end
    end)
end

-- Styled popup UI with a text hyperlink (secure button) to teleport
local function GuessRoleKey(roleText)
    if type(roleText) ~= "string" then return nil end
    local up = string.upper(roleText)
    if up == "TANK" or roleText == TANK then return "TANK" end
    if up == "HEALER" or roleText == HEALER then return "HEALER" end
    if up == "DAMAGER" or up == "DAMAGE" or roleText == DAMAGER then return "DAMAGER" end
end

local function EnsureGroupReminderStyledFrame(self)
    if self.groupReminderStyledFrame then return self.groupReminderStyledFrame end

    local f = CreateFrame("Frame", "KPL_GroupReminderStyled", UIParent, "BackdropTemplate")
    f:SetSize(400, 200) -- Slightly smaller/standard size
    local xOff = self.db.profile.groupReminder.popupXOffset or 0
    local yOff = self.db.profile.groupReminder.popupYOffset or 0
    f:SetPoint("CENTER", UIParent, "CENTER", xOff, yOff)
    f:SetFrameStrata("DIALOG")
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", function(frame)
        frame:StopMovingOrSizing()
        local cx, cy = frame:GetCenter()
        local sw, sh = GetScreenWidth(), GetScreenHeight()
        local db = self.db.profile.groupReminder
        db.popupXOffset = cx - sw / 2
        db.popupYOffset = cy - sh / 2
    end)

    f:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\Buttons\\WHITE8x8", -- Simple solid texture
        tile = true, tileSize = 32, edgeSize = 1, -- 1px border
        insets = { left = 0, right = 0, top = 0, bottom = 0 }
    })
    f:SetBackdropBorderColor(0, 0, 0, 1) -- Black border

    table.insert(UISpecialFrames, "KPL_GroupReminderStyled")

    f.Title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    f.Title:SetPoint("TOP", 0, -16)
    f.Title:SetText(GetGroupReminderHeaderLabel())

    f.RoleIcon = f:CreateTexture(nil, "OVERLAY")
    f.RoleIcon:SetSize(22, 22)
    f.RoleIcon:SetPoint("TOP", f.Title, "BOTTOM", 0, -6)
    f.RoleIcon:Hide()

    -- Text label "Teleport to dungeon" above the icon
    f.TeleportLabel = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    f.TeleportLabel:SetPoint("BOTTOM", 0, 55) -- Position above the icon
    f.TeleportLabel:SetText(TELEPORT_TO_DUNGEON)
    f.TeleportLabel:SetTextColor(1, 0.82, 0, 1) -- Gold color

    -- Single centered content block
    f.Content = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.Content:SetPoint("TOP", f.RoleIcon, "BOTTOM", 0, -8)
    f.Content:SetPoint("LEFT", 20, 0)
    f.Content:SetPoint("RIGHT", -20, 0)
    f.Content:SetJustifyH("CENTER")
    f.Content:SetJustifyV("TOP")
    f.Content:SetSpacing(4) -- Add some breathing room between lines

    -- Icon-based secure button for teleport, centered at bottom
    f.TeleportLink = CreateFrame("Button", nil, f, "SecureActionButtonTemplate")
    f.TeleportLink:SetPoint("BOTTOM", 0, 20)
    f.TeleportLink:SetSize(40, 40)
    f.TeleportLink:RegisterForClicks("AnyUp", "AnyDown")

    f.TeleportLink.Icon = f.TeleportLink:CreateTexture(nil, "ARTWORK")
    f.TeleportLink.Icon:SetAllPoints()
    f.TeleportLink.Icon:SetTexCoord(0.08, 0.92, 0.08, 0.92) -- Zoom slightly to remove ugly borders

    f.TeleportLink:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")

    -- Tooltip handling
    f.TeleportLink:SetScript("OnEnter", function(button)
        if button.spellID then
            GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
            GameTooltip:SetSpellByID(button.spellID)
            GameTooltip:Show()
        end
    end)
    f.TeleportLink:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    f.Close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    f.Close:SetPoint("TOPRIGHT", -5, -5)
    local closeAtlas
    local closeTexture
    if SettingsPanel and SettingsPanel.ClosePanelButton and SettingsPanel.ClosePanelButton.Texture then
        local textureRegion = SettingsPanel.ClosePanelButton.Texture
        if textureRegion.GetAtlas then
            closeAtlas = textureRegion:GetAtlas()
        end
        if not closeAtlas and textureRegion.GetTexture then
            closeTexture = textureRegion:GetTexture()
        end
    end
    if not closeAtlas and not closeTexture and IsAddOnLoaded and IsAddOnLoaded("ElvUI") and ElvUI then
        local E = ElvUI[1]
        closeTexture = E and E.Media and E.Media.Textures and E.Media.Textures.Close
        if not closeTexture then
            closeTexture = "Interface\\AddOns\\ElvUI\\Core\\Media\\Textures\\Close"
        end
    end
    if closeAtlas or closeTexture then
        f.Close:Hide()
        if not f.ElvClose then
            local btn = CreateFrame("Button", nil, f)
            btn:SetPoint("TOPRIGHT", -9, -8)
            btn:SetSize(14, 14)

            if closeAtlas then
                btn:SetNormalTexture(0)
                btn:SetPushedTexture(0)
                btn:SetHighlightTexture(0)
                local nt = btn:GetNormalTexture()
                local pt = btn:GetPushedTexture()
                local ht = btn:GetHighlightTexture()
                if nt and nt.SetAtlas then nt:SetAtlas(closeAtlas) end
                if pt and pt.SetAtlas then pt:SetAtlas(closeAtlas) end
                if ht and ht.SetAtlas then ht:SetAtlas(closeAtlas) end
            else
                btn:SetNormalTexture(closeTexture)
                btn:SetPushedTexture(closeTexture)
                btn:SetHighlightTexture(closeTexture)
            end
            local nt = btn:GetNormalTexture()
            local pt = btn:GetPushedTexture()
            local ht = btn:GetHighlightTexture()
            if nt then nt:SetVertexColor(1, 1, 1, 1) end
            if pt then pt:SetVertexColor(0.8, 0.8, 0.8, 1) end
            if ht then ht:SetVertexColor(1, 1, 1, 0.85) end
            btn:SetScript("OnClick", function()
                f:Hide()
            end)
            f.ElvClose = btn
        else
            f.ElvClose:Show()
        end
    end

    f:Hide()
    self.groupReminderStyledFrame = f
    return f
end

function KeystonePolaris:ShowStyledGroupReminderPopup(zone, groupName, groupComment, roleText, teleportSpellID, teleportSpellUnknown, playstyleText)
    local db = self.db.profile.groupReminder
    local f = EnsureGroupReminderStyledFrame(self)
    f.Title:SetText(GetGroupReminderHeaderLabel())

    local lines = {}
    local labelColor = "|cffffd100"
    local valueColor = "|cffffffff"
    if db.showDungeonName then table.insert(lines, labelColor .. ENCOUNTER_JOURNAL_INSTANCE .. ":|r " .. valueColor .. (zone or "-") .. "|r") end
    if db.showGroupName then table.insert(lines, labelColor .. GROUP .. ":|r " .. valueColor .. (groupName or "-") .. "|r") end
    if db.showGroupDescription then table.insert(lines, labelColor .. DESCRIPTION .. ":|r " .. valueColor .. (groupComment or "-") .. "|r") end
    if db.showPlaystyle then table.insert(lines, labelColor .. GROUP_FINDER_FILTER_PLAYSTYLE .. ":|r " .. valueColor .. (playstyleText or "-") .. "|r") end
    if db.showAppliedRole then table.insert(lines, labelColor .. ROLE .. ":|r " .. valueColor .. (roleText or "-") .. "|r") end

    -- Join all lines with newlines
    local fullText = table.concat(lines, "\n")
    f.Content:SetText(fullText)

    -- Role icon under the title
    local roleKey = GuessRoleKey(roleText)
    if db.showAppliedRole and roleKey then
        local atlasCandidates = {
            TANK = {"roleicon-tank", "roleicon-tiny-tank"},
            HEALER = {"roleicon-healer", "roleicon-tiny-healer"},
            DAMAGER = {"roleicon-dps", "roleicon-tiny-dps"},
        }
        local atlas
        local candidates = atlasCandidates[roleKey]
        if candidates and f.RoleIcon.SetAtlas then
            if C_Texture and C_Texture.GetAtlasInfo then
                for _, name in ipairs(candidates) do
                    if C_Texture.GetAtlasInfo(name) then
                        atlas = name
                        break
                    end
                end
            else
                atlas = candidates[1]
            end
        end
        if atlas then
            f.RoleIcon:SetAtlas(atlas)
        else
            f.RoleIcon:SetTexture("Interface\\LFGFrame\\UI-LFG-ICON-ROLES")
            if GetTexCoordsForRoleSmallCircle then
                f.RoleIcon:SetTexCoord(GetTexCoordsForRoleSmallCircle(roleKey))
            elseif GetTexCoordsForRole then
                f.RoleIcon:SetTexCoord(GetTexCoordsForRole(roleKey))
            elseif roleKey == "TANK" then
                f.RoleIcon:SetTexCoord(0, 0.25, 0, 0.25)
            elseif roleKey == "HEALER" then
                f.RoleIcon:SetTexCoord(0.25, 0.5, 0, 0.25)
            else
                f.RoleIcon:SetTexCoord(0.5, 0.75, 0, 0.25)
            end
        end
        f.RoleIcon:Show()
    else
        f.RoleIcon:Hide()
    end

    if teleportSpellUnknown then
        f.TeleportLabel:SetText(L["KPL_GR_TELEPORT_UNKNOWN"] or "Teleport spell not known")
    else
        f.TeleportLabel:SetText(TELEPORT_TO_DUNGEON .. ":")
    end

    -- Configure teleport link (secure button) only if spell is known (or in test mode)
    local isKnown = teleportSpellID and type(teleportSpellID) == "number" and IsSpellKnown and IsSpellKnown(teleportSpellID)
    if self._testingGroupReminder and teleportSpellID then isKnown = true end

    if teleportSpellID and isKnown then
        local spellName, _, icon
        if C_Spell and C_Spell.GetSpellName then
            spellName = C_Spell.GetSpellName(teleportSpellID)
            icon = C_Spell.GetSpellTexture(teleportSpellID)
        elseif GetSpellInfo then
            spellName, _, icon = GetSpellInfo(teleportSpellID)
        end

        if spellName then
            f.TeleportLink.spellID = teleportSpellID -- Store for tooltip
            f.TeleportLink:SetAttribute("type", "macro")
            f.TeleportLink:SetAttribute("macrotext", "/cast " .. spellName)
            if icon then
                f.TeleportLink.Icon:SetTexture(icon)
            end
            f.TeleportLink:Show()
            f.TeleportLabel:Show()
        else
            f.TeleportLink:Hide()
            if teleportSpellUnknown then
                f.TeleportLabel:Show()
            else
                f.TeleportLabel:Hide()
            end
        end
    else
        f.TeleportLink:Hide()
        if teleportSpellUnknown then
            f.TeleportLabel:Show()
        else
            f.TeleportLabel:Hide()
        end
    end

    -- Layout dynamique + hauteur (après visibilité réelle des éléments)
    f.TeleportLabel:ClearAllPoints()
    if f.TeleportLink:IsShown() then
        f.TeleportLabel:SetPoint("BOTTOM", f.TeleportLink, "TOP", 0, 2)
    elseif f.TeleportLabel:IsShown() then
        local gap = teleportSpellUnknown and -16 or -8
        f.TeleportLabel:SetPoint("TOP", f.Content, "BOTTOM", 0, gap)
    end
    local textHeight = f.Content:GetStringHeight()
    local labelHeight = f.TeleportLabel:IsShown() and f.TeleportLabel:GetStringHeight() or 0
    local iconHeight = f.TeleportLink:IsShown() and 40 or 0
    local baseHeight = 112
    local teleportHeight = 0
    if f.TeleportLink:IsShown() then
        teleportHeight = teleportHeight + iconHeight + labelHeight + 8
    elseif f.TeleportLabel:IsShown() then
        teleportHeight = teleportHeight + labelHeight + 8
    end
    f:SetHeight(baseHeight + textHeight + teleportHeight)

    f:Show()
end

function KeystonePolaris:ShowLastGroupReminder()
    if not IsInGroup or not IsInGroup() then
        local prefix = (self.GetChatPrefix and self:GetChatPrefix()) or "Keystone Polaris"
        print(prefix .. ": No active group to show the reminder.")
        return
    end

    local data = self.lastGroupReminder
    if not data and self.db and self.db.profile and self.db.profile.groupReminder then
        data = self.db.profile.groupReminder.lastReminder
    end
    if not data then
        local prefix = (self.GetChatPrefix and self:GetChatPrefix()) or "Keystone Polaris"
        print(prefix .. ": No reminder data stored yet.")
        return
    end

    self:ShowStyledGroupReminderPopup(
        data.zone,
        data.groupName,
        data.comment,
        data.roleText,
        data.teleportSpellID,
        data.teleportSpellUnknown,
        data.playstyleText
    )
end

function KeystonePolaris:ShowGroupReminder(searchResultID, title, zone, comment, activityMapID, playstyleText)
    local db = self.db and self.db.profile and self.db.profile.groupReminder
    if not db or not db.enabled then return end

    local roleText = GetAppliedRoleText(searchResultID)
    local _, body = BuildMessages(db, zone, title, roleText, playstyleText)

    -- Resolve teleport spell for this dungeon
    local teleportSpellID = self.GetTeleportSpellForMapID and self:GetTeleportSpellForMapID(activityMapID) or nil
    if not teleportSpellID then
        local candidates = GetTeleportCandidatesForMapIDLocal(self, activityMapID)
        if type(candidates) == "number" then
            teleportSpellID = candidates
        elseif type(candidates) == "table" then
            teleportSpellID = candidates[1]
        end
    end

    -- Filter unknown teleport spell as early as possible
    local teleportSpellUnknown = false
    if teleportSpellID and IsSpellKnown and not IsSpellKnown(teleportSpellID) then
        teleportSpellUnknown = true
        teleportSpellID = nil
    end

    -- Store last reminder data (for chat link + command)
    local reminderData = {
        zone = zone,
        groupName = title,
        comment = comment,
        playstyleText = playstyleText,
        roleText = roleText,
        teleportSpellID = teleportSpellID,
        teleportSpellUnknown = teleportSpellUnknown,
    }
    self.lastGroupReminder = reminderData
    if self.db and self.db.profile and self.db.profile.groupReminder then
        self.db.profile.groupReminder.lastReminder = reminderData
    end

    self.groupReminderPendingFullPopup = db.showPopupWhenGroupIsFull and true or nil
    self.groupReminderFullPopupShown = nil

    -- Popup
    if db.showPopup then
        self:ShowStyledGroupReminderPopup(
            zone,
            title,
            comment,
            roleText,
            teleportSpellID,
            teleportSpellUnknown,
            playstyleText
        )
    end

    -- Chat
    if db.showChat then
        local chatHeader = "|cffdb6233" .. GetGroupReminderHeaderLabel() .. "|r: "
        local linkText = "|cffffd100[" .. (L["KPL_GR_OPEN_REMINDER"] or "Open reminder") .. "]|r"
        local link = string.format("|Hkphreminder:1|h%s|h", linkText)
        if body ~= "" then
            print(chatHeader .. " " .. body .. " " .. link)
        else
            print(chatHeader .. " " .. link)
        end
    end
end

function KeystonePolaris:InitializeGroupReminder()
    if self.groupReminderFrame then
        -- Ensure registration reflects current settings
        self:UpdateGroupReminderRegistration()
        return
    end

    self.groupReminderFrame = CreateFrame("Frame")
    self.groupReminderFrame:RegisterEvent("LFG_LIST_APPLICATION_STATUS_UPDATED")
    self.groupReminderFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
    self.groupReminderFrame:RegisterEvent("GROUP_LEFT")

    self.groupReminderFrame:SetScript("OnEvent", function(_, event, ...)
        if event == "GROUP_LEFT" then
            self:ResetGroupReminderTracking(true)
            return
        end
        if event == "GROUP_ROSTER_UPDATE" then
            self:HandleGroupRosterUpdate()
            return
        end
        if event ~= "LFG_LIST_APPLICATION_STATUS_UPDATED" then return end

        local searchResultID, newStatus = ...
        if not searchResultID or not newStatus then return end

        -- Show reminder when the invite is accepted (joined)
        if newStatus ~= "inviteaccepted" then return end

        local srd = C_LFGList.GetSearchResultInfo(searchResultID)
        if not srd then return end

        -- Some APIs return multiple activityIDs; prefer the first when present
        local activityID = (srd.activityIDs and srd.activityIDs[1]) or srd.activityID
        if not activityID then return end

        if not IsMythicPlusActivity(activityID) then return end

        local activity = C_LFGList.GetActivityInfoTable(activityID)
        if not activity then return end

        -- Hide Blizzard's LFG invite dialog if it's still visible (post-accept)
        if self.db.profile.groupReminder.suppressQuickJoinToast and type(LFGListInviteDialog) == "table" and LFGListInviteDialog.Hide then
            if LFGListInviteDialog:IsShown() then
                LFGListInviteDialog:Hide()
            end
        end

        local title = srd.name or ""
        local zone = activity.fullName or ""
        local comment = srd.comment or ""
        local mapID = activity.mapID
        local generalPlaystyle = srd.generalPlaystyle or srd.playstyle or activity.playstyle
        local noneValue = Enum and Enum.LFGEntryGeneralPlaystyle and Enum.LFGEntryGeneralPlaystyle.None
        local playstyleText = srd.playstyleString
        if not playstyleText and generalPlaystyle and generalPlaystyle ~= noneValue then
            playstyleText = GENERAL_PLAYSTYLE_TEXT_BY_VALUE[generalPlaystyle]
        end
        playstyleText = playstyleText or ""
        -- Delay slightly to allow group roster to update so UnitGroupRolesAssigned returns the accepted role
        C_Timer.After(0.2, function()
            self:ShowGroupReminder(searchResultID, title, zone, comment, mapID, playstyleText)
            self:HandleGroupRosterUpdate()
        end)

        -- Cleanup stored role for this application
        self.groupReminderRoleByResult[searchResultID] = nil
    end)
end

function KeystonePolaris:DisableGroupReminder()
    if self.groupReminderFrame then
        self.groupReminderFrame:UnregisterAllEvents()
    end
end

function KeystonePolaris:UpdateGroupReminderRegistration()
    local db = self.db and self.db.profile and self.db.profile.groupReminder
    if not db then return end
    if db.enabled then
        if not self.groupReminderFrame then
            self:InitializeGroupReminder()
            return
        end
        self.groupReminderFrame:RegisterEvent("LFG_LIST_APPLICATION_STATUS_UPDATED")
        self.groupReminderFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
        self.groupReminderFrame:RegisterEvent("GROUP_LEFT")
    else
        self:DisableGroupReminder()
    end
end

local function IsCurrentGroupFull()
    if not IsInGroup or not IsInGroup() then return false end
    if IsInRaid and IsInRaid() then return false end
    return (GetNumGroupMembers and GetNumGroupMembers() or 0) >= 5
end

function KeystonePolaris:ResetGroupReminderTracking(clearLastReminder)
    self.groupReminderPendingFullPopup = nil
    self.groupReminderFullPopupShown = nil

    if clearLastReminder then
        self.lastGroupReminder = nil
        if self.db and self.db.profile and self.db.profile.groupReminder then
            self.db.profile.groupReminder.lastReminder = nil
        end
    end
end

function KeystonePolaris:HandleGroupRosterUpdate()
    local db = self.db and self.db.profile and self.db.profile.groupReminder
    if not db or not db.enabled or not db.showPopupWhenGroupIsFull then return end
    if not self.groupReminderPendingFullPopup or self.groupReminderFullPopupShown then return end
    if not self.lastGroupReminder then return end
    if not IsCurrentGroupFull() then return end

    self.groupReminderFullPopupShown = true
    self:ShowLastGroupReminder()
end

-- Ensure Blizzard UI related to group invites/toasts is visible again
function KeystonePolaris.RestoreBlizzardJoinUI()
    if type(LFGListInviteDialog) == "table" and LFGListInviteDialog.Show then
        LFGListInviteDialog:Show()
    end
end

function KeystonePolaris:TestGroupReminder()
    self._testingGroupReminder = true
    local fakeID = 999999
    -- Fake a role application
    self.groupReminderRoleByResult = self.groupReminderRoleByResult or {}
    local roles = {TANK, HEALER, DAMAGER}
    self.groupReminderRoleByResult[fakeID] = roles[math.random(#roles)]

    -- Fake data (randomized)
    local titles = {
        "Push +10 chill",
        "+10 Weekly vault run",
        "Fast +12 no leavers",
        "Timed +15 key",
        "Casual +2 keys",
    }
    local lorem = {
        "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.",
        "Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat.",
        "Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur.",
        "Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.",
    }

    local title = titles[math.random(#titles)]
    local comment = lorem[math.random(#lorem)]

    local dungeonId, mapID
    local zone = nil
    if type(self.GetSeasonByDate) == "function" then
        local currentSeasonId = self:GetSeasonByDate(date("%Y-%m-%d"))
        local seasonDungeons = currentSeasonId and self[currentSeasonId .. "_DUNGEONS"]
        if type(seasonDungeons) == "table" then
            local dungeonIds = {}
            for id, enabled in pairs(seasonDungeons) do
                if type(id) == "number" and enabled then
                    table.insert(dungeonIds, id)
                end
            end
            if #dungeonIds > 0 then
                dungeonId = dungeonIds[math.random(#dungeonIds)]
                if C_ChallengeMode and C_ChallengeMode.GetMapUIInfo then
                    local name = C_ChallengeMode.GetMapUIInfo(dungeonId)
                    zone = name or zone
                end
                local shortName = self.GlobalDungeonIDLookup and self.GlobalDungeonIDLookup[dungeonId]
                local dungeonData = shortName and self.GlobalDungeonLookup and self.GlobalDungeonLookup[shortName]
                mapID = dungeonData and dungeonData.mapID
                if not zone and mapID and C_Map and C_Map.GetMapInfo then
                    local info = C_Map.GetMapInfo(mapID)
                    zone = info and info.name or zone
                end
                zone = zone or (dungeonData and (dungeonData.displayName or dungeonData.name)) or (shortName or tostring(dungeonId))
            end
        end
    end

    if not mapID then
        local prefix = (self.GetChatPrefix and self:GetChatPrefix(true)) or "[Keystone Polaris]"
        print(prefix .. " Could not resolve a current-season dungeon. Falling back to The Stonevault.")
        mapID = 2652
        zone = "The Stonevault"
    end

    if not zone and dungeonId and C_ChallengeMode and C_ChallengeMode.GetMapUIInfo then
        local name = C_ChallengeMode.GetMapUIInfo(dungeonId)
        zone = name or zone
    end
    if not zone and mapID and C_Map and C_Map.GetMapInfo then
        local info = C_Map.GetMapInfo(mapID)
        zone = info and info.name or zone
    end

    -- Ensure options are loaded so we don't crash
    if not self.db.profile.groupReminder then
        self.db.profile.groupReminder = self.defaults.profile.groupReminder
    end

    -- Force show even if disabled, for testing purposes?
    -- Better to respect "enabled" flag or print a warning.
    if not self.db.profile.groupReminder.enabled then
        local prefix = (self.GetChatPrefix and self:GetChatPrefix(true)) or "[Keystone Polaris]"
        print(prefix .. " Group Reminder is currently disabled in options.")
        self._testingGroupReminder = false
        return
    end

    self:ShowGroupReminder(fakeID, title, zone, comment, mapID)
    self._testingGroupReminder = false
end

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
