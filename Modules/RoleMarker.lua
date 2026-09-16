local AddOnName, KeystonePolaris = ...
local L = LibStub("AceLocale-3.0"):GetLocale(AddOnName)
local _G = _G
local GetCVarBool = _G.GetCVarBool
local HideUIPanel = _G.HideUIPanel
local issecretvalue = _G.issecretvalue

local ROLE_MARKER_UNITS = { "player", "party1", "party2", "party3", "party4" }
local RAID_ICON_TEXTURE = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_%d"
local RAID_MARKER_SORTING = { 0, 1, 2, 3, 4, 5, 6, 7, 8 }
local ROLE_MARKER_ICON_SIZE = 14
local ROLE_MARKER_DEFAULT_FONT = "Friz Quadrata TT"
local ROLE_MARKER_DEFAULT_FONT_SIZE = 16

local function GetRoleMarkerDB(self)
    return self.db and self.db.profile and self.db.profile.roleMarker
end

local function CanUseRoleMarker(self)
    if not (IsInGroup() and not IsInRaid()) then return false end
    local inInstance, instanceType = IsInInstance()
    if not inInstance then
        local db = GetRoleMarkerDB(self)
        return db and db.showOutsideInstance and true or false
    end
    if instanceType ~= "party" then return false end
    if C_DelvesUI and C_DelvesUI.HasActiveDelve then
        local mapID = select(4, UnitPosition("player"))
        if C_DelvesUI.HasActiveDelve(mapID) then return false end
    end
    local difficultyID = select(3, GetInstanceInfo())
    if not difficultyID or difficultyID == 0 then return false end
    local _, _, _, isChallengeMode, _, displayMythic = GetDifficultyInfo(difficultyID)
    return isChallengeMode or displayMythic
end

-- 0 / missing-out-of-range means "do not mark this role". Nil db uses fallback.
local function ResolveRoleMarker(value, fallback)
    if value == nil then return fallback end
    local marker = tonumber(value) or 0
    if marker < 1 or marker > 8 then return nil end
    return marker
end

local function GetConfiguredRoleMarkers(db)
    local tankMarker = ResolveRoleMarker(db and db.tankMarker, 6)
    local healerMarker = ResolveRoleMarker(db and db.healerMarker, 5)
    return tankMarker, healerMarker
end

local function ApplyRoleMarkerLabelFont(self, label, db)
    if not label then return end
    local fontName = (db and db.font) or ROLE_MARKER_DEFAULT_FONT
    local fontSize = tonumber(db and db.fontSize) or ROLE_MARKER_DEFAULT_FONT_SIZE
    local fontPath = self.LSM and self.LSM:Fetch("font", fontName)
    local flags = self:GetFontFlagsForPreset(db and db.fontFlags)
    label:SetFont(fontPath or "Fonts\\FRIZQT__.TTF", fontSize, flags)
    return fontSize
end

local function RaidIconMarkup(marker)
    return string.format("|T%s:%d:%d:0:0|t", string.format(RAID_ICON_TEXTURE, marker), ROLE_MARKER_ICON_SIZE, ROLE_MARKER_ICON_SIZE)
end

local function GetPartyRolePresence()
    local hasTank, hasHealer = false, false
    for i = 1, #ROLE_MARKER_UNITS do
        local unit = ROLE_MARKER_UNITS[i]
        if UnitExists(unit) then
            local role = UnitGroupRolesAssigned(unit)
            if role == "TANK" then
                hasTank = true
            elseif role == "HEALER" then
                hasHealer = true
            end
            if hasTank and hasHealer then
                break
            end
        end
    end
    return hasTank, hasHealer
end

local function FormatRoleMarkerLabel(tankMarker, healerMarker, requirePresent)
    local hasTank, hasHealer = true, true
    if requirePresent then
        hasTank, hasHealer = GetPartyRolePresence()
    end
    local roles = {}
    if tankMarker and hasTank then
        roles[#roles + 1] = string.format("%s %s", TANK, RaidIconMarkup(tankMarker))
    end
    if healerMarker and hasHealer then
        roles[#roles + 1] = string.format("%s %s", HEALER, RaidIconMarkup(healerMarker))
    end
    if #roles == 0 then
        return L["KPL_RM_HEADER"]
    end
    local roleText = roles[1]
    if roles[2] then
        roleText = string.format(L["KPL_RM_ROLES_AND"], roles[1], roles[2])
    end
    return string.format(L["KPL_RM_BUTTON"], roleText)
end

-- GetRaidTargetIndex is secret when a mark exists. Comparing it from addon
-- code errors ("secret number value"). Skip units whose index is secret:
-- they already have a mark, and /tm would toggle it off.
local function ShouldApplyRoleMark(unit, marker)
    local current = GetRaidTargetIndex(unit)
    if issecretvalue and issecretvalue(current) then
        return false
    end
    return current ~= marker
end

local function ApplyRoleMarkerBackdrop(btn)
    local backdrop = {
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\ChatFrame\\ChatFrameBackground",
        tile = true, tileSize = 16, edgeSize = 1,
    }
    if btn.SetBackdrop then
        btn:SetBackdrop(backdrop)
        btn:SetBackdropColor(0, 0, 0, 0.7)
        btn:SetBackdropBorderColor(1, 0.82, 0, 1)
    elseif BackdropTemplateMixin and BackdropTemplateMixin.SetBackdrop then
        BackdropTemplateMixin.SetBackdrop(btn, backdrop)
        btn:SetBackdropColor(0, 0, 0, 0.7)
        btn:SetBackdropBorderColor(1, 0.82, 0, 1)
    end
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

function KeystonePolaris:EnsureRoleMarkerWatcher()
    if self._roleMarkerWatcher then return end

    local f = CreateFrame("Frame")
    f:RegisterEvent("PLAYER_REGEN_ENABLED")
    f:SetScript("OnEvent", function()
        if self._pendingRoleMarkerUpdate then
            self._pendingRoleMarkerUpdate = nil
            self:UpdateRoleMarkerState()
        end
    end)

    self._roleMarkerWatcher = f
end

function KeystonePolaris:BuildRoleMarkerMacro()
    local db = GetRoleMarkerDB(self)
    if not db then return nil end

    local tankMarker, healerMarker = GetConfiguredRoleMarkers(db)
    local assigned = { TANK = false, HEALER = false }
    local lines = {}

    for i = 1, #ROLE_MARKER_UNITS do
        local unit = ROLE_MARKER_UNITS[i]
        if UnitExists(unit) then
            local role = UnitGroupRolesAssigned(unit)
            local marker
            if role == "TANK" and tankMarker and not assigned.TANK then
                marker = tankMarker
                assigned.TANK = true
            elseif role == "HEALER" and healerMarker and not assigned.HEALER then
                marker = healerMarker
                assigned.HEALER = true
            end

            if marker and ShouldApplyRoleMark(unit, marker) then
                lines[#lines + 1] = string.format("/tm [@%s] %d", unit, marker)
            end
        end
    end

    if #lines == 0 then return nil end
    return table.concat(lines, "\n")
end

function KeystonePolaris:RefreshRoleMarkerIcons()
    local btn = self.roleMarkerButton
    if not btn or not btn.Label then return end

    local db = GetRoleMarkerDB(self)
    local tankMarker, healerMarker = GetConfiguredRoleMarkers(db)
    local fontSize = ApplyRoleMarkerLabelFont(self, btn.Label, db)
    btn.Label:SetText(FormatRoleMarkerLabel(tankMarker, healerMarker, not self._positioningMode))

    if not InCombatLockdown() then
        local textWidth = btn.Label:GetStringWidth() or 0
        btn:SetWidth(math.max(80, textWidth + 16))
        btn:SetHeight(math.max(28, (fontSize or ROLE_MARKER_DEFAULT_FONT_SIZE) + 12))
    end
end

function KeystonePolaris:ApplyRoleMarkerPosition(force)
    local btn = self.roleMarkerButton
    if not btn then return end
    if self._positioningMode and not force then return end
    if InCombatLockdown() then
        self._pendingRoleMarkerUpdate = true
        self:EnsureRoleMarkerWatcher()
        return
    end

    local db = GetRoleMarkerDB(self)
    local xOff = (db and db.xOffset) or 0
    local yOff = (db and db.yOffset) or 0
    btn:ClearAllPoints()
    btn:SetPoint("CENTER", UIParent, "CENTER", xOff, yOff)
end

function KeystonePolaris:SaveRoleMarkerPositioningState()
    local db = GetRoleMarkerDB(self)
    if not db then
        self._savedRoleMarkerPosition = nil
        return
    end
    self._savedRoleMarkerPosition = {
        xOffset = db.xOffset,
        yOffset = db.yOffset,
    }
end

function KeystonePolaris:BeginRoleMarkerPositioning()
    local db = GetRoleMarkerDB(self)
    if not db or not db.enabled then return end
    if InCombatLockdown() then return end

    local btn = self:EnsureRoleMarkerButton()
    self:RefreshRoleMarkerIcons()
    self:ApplyRoleMarkerPosition(true)
    btn:SetAttribute("type", nil)
    btn:SetAttribute("macrotext", nil)
    btn:SetMovable(true)
    btn:RegisterForDrag("LeftButton")
    btn:EnableMouse(true)
    btn:SetAlpha(1)
    btn:Show()
end

function KeystonePolaris:FinishRoleMarkerPositioning(save)
    local db = GetRoleMarkerDB(self)
    if not save and self._savedRoleMarkerPosition and db then
        db.xOffset = self._savedRoleMarkerPosition.xOffset
        db.yOffset = self._savedRoleMarkerPosition.yOffset
    end
    self._savedRoleMarkerPosition = nil
    self:UpdateRoleMarkerState()
end

function KeystonePolaris:ApplyRoleMarkerCombatVisualState(shouldShow)
    local btn = self.roleMarkerButton
    if not btn then return end
    if shouldShow then
        btn:SetAlpha(1)
    else
        btn:SetAlpha(0)
    end
end

function KeystonePolaris:EnsureRoleMarkerButton()
    if self.roleMarkerButton then
        return self.roleMarkerButton
    end

    local btn = CreateFrame("Button", "KeystonePolarisRoleMarkerButton", UIParent, "SecureActionButtonTemplate, BackdropTemplate")
    btn:SetSize(180, 28)
    btn:SetClampedToScreen(true)
    btn:SetFrameStrata("MEDIUM")
    btn:EnableMouse(true)
    ApplyRoleMarkerBackdrop(btn)
    btn:SetHighlightTexture("Interface\\Buttons\\WHITE8x8")
    local highlight = btn:GetHighlightTexture()
    if highlight then
        highlight:SetVertexColor(1, 0.82, 0, 0.2)
        highlight:SetBlendMode("ADD")
    end

    local useKeyDown = GetCVarBool("ActionButtonUseKeyDown")
    if useKeyDown then
        btn:RegisterForClicks("LeftButtonDown")
    else
        btn:RegisterForClicks("LeftButtonUp")
    end

    btn.Label = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    btn.Label:SetTextColor(1, 0.82, 0, 1)
    btn.Label:SetPoint("LEFT", 8, 0)
    btn.Label:SetPoint("RIGHT", -8, 0)
    btn.Label:SetJustifyH("CENTER")
    btn.Label:SetWordWrap(false)

    btn:SetScript("OnEnter", function(button)
        if self._positioningMode then return end
        GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
        GameTooltip:SetText(L["KPL_RM_HEADER"])
        GameTooltip:AddLine(L["KPL_RM_TOOLTIP"], 1, 1, 1, true)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    btn:SetScript("OnMouseUp", function(_, mouseButton)
        if not self._positioningMode then return end
        if mouseButton ~= "LeftButton" and mouseButton ~= "RightButton" then return end
        if self.SetPositioningFocus then self:SetPositioningFocus("roleMarker") end
        if self.ShowPositioningOffsetPopup then self:ShowPositioningOffsetPopup() end
    end)
    btn:SetScript("OnDragStart", function(button)
        if InCombatLockdown() or not self._positioningMode then return end
        if self.SetPositioningFocus then self:SetPositioningFocus("roleMarker") end
        button:StartMoving()
    end)
    btn:SetScript("OnDragStop", function(button)
        button:StopMovingOrSizing()
        if InCombatLockdown() or not self._positioningMode then return end
        local db = GetRoleMarkerDB(self)
        if not db then return end
        local cx, cy = button:GetCenter()
        local sw, sh = GetScreenWidth(), GetScreenHeight()
        if cx and cy and sw and sh then
            db.xOffset = cx - sw / 2
            db.yOffset = cy - sh / 2
        end
        self:ApplyRoleMarkerPosition(true)
        if self.RefreshPositioningOffsetSliders then self:RefreshPositioningOffsetSliders() end
        LibStub("AceConfigRegistry-3.0"):NotifyChange(AddOnName)
    end)

    btn:Hide()
    self.roleMarkerButton = btn
    self:RefreshRoleMarkerIcons()
    self:ApplyRoleMarkerPosition()
    return btn
end

function KeystonePolaris:UpdateRoleMarkerState()
    local db = GetRoleMarkerDB(self)
    local btn = self.roleMarkerButton
    if not db or not db.enabled then
        if btn then
            if InCombatLockdown() then
                self._pendingRoleMarkerUpdate = true
                self:ApplyRoleMarkerCombatVisualState(false)
                self:EnsureRoleMarkerWatcher()
            else
                btn:EnableMouse(false)
                btn:Hide()
                btn:SetAlpha(1)
            end
        end
        return
    end

    btn = self:EnsureRoleMarkerButton()
    local positioning = self._positioningMode and true or false
    local macroText = (not positioning) and CanUseRoleMarker(self) and self:BuildRoleMarkerMacro() or nil
    local shouldShow = (macroText ~= nil) or positioning

    if InCombatLockdown() then
        self._pendingRoleMarkerUpdate = true
        self:ApplyRoleMarkerCombatVisualState(shouldShow)
        self:EnsureRoleMarkerWatcher()
        return
    end

    self:RefreshRoleMarkerIcons()
    self:ApplyRoleMarkerPosition()
    btn:SetAlpha(1)
    btn:SetMovable(positioning)
    if positioning then
        btn:RegisterForDrag("LeftButton")
    else
        btn:RegisterForDrag()
    end

    if shouldShow then
        if macroText then
            btn:SetAttribute("type", "macro")
            btn:SetAttribute("macrotext", macroText)
        else
            btn:SetAttribute("type", nil)
            btn:SetAttribute("macrotext", nil)
        end
        btn:EnableMouse(true)
        btn:Show()
    else
        btn:SetAttribute("type", nil)
        btn:SetAttribute("macrotext", nil)
        btn:EnableMouse(false)
        btn:Hide()
    end
end

function KeystonePolaris:InitializeRoleMarker()
    if not self._roleMarkerEventFrame then
        local f = CreateFrame("Frame")
        f:SetScript("OnEvent", function()
            self:UpdateRoleMarkerState()
        end)
        self._roleMarkerEventFrame = f
    end

    local f = self._roleMarkerEventFrame
    f:RegisterEvent("GROUP_ROSTER_UPDATE")
    f:RegisterEvent("RAID_TARGET_UPDATE")
    f:RegisterEvent("ROLE_CHANGED_INFORM")
    f:RegisterEvent("PLAYER_ENTERING_WORLD")
    f:RegisterEvent("PLAYER_DIFFICULTY_CHANGED")
    f:RegisterEvent("CHALLENGE_MODE_START")
    f:RegisterEvent("CHALLENGE_MODE_COMPLETED")
    f:RegisterEvent("ZONE_CHANGED_NEW_AREA")

    self:EnsureRoleMarkerWatcher()
    self:UpdateRoleMarkerState()
end

function KeystonePolaris:DisableRoleMarker()
    if self._roleMarkerEventFrame then
        self._roleMarkerEventFrame:UnregisterAllEvents()
    end
    self._pendingRoleMarkerUpdate = nil
    self:UpdateRoleMarkerState()
end

function KeystonePolaris:GetRoleMarkerOptions()
    local ColumnRow = KeystonePolaris.ColumnRow
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
        name = function()
            return self:GetOptionFeatureLabel("roleMarker", L["KPL_RM_HEADER"])
        end,
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
            tankMarker = {
                name = TANK,
                type = "select",
                order = 4,
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
            healerMarker = {
                name = HEALER,
                type = "select",
                order = 4.5,
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
            },
            appearanceHeader = {
                order = 4.8,
                type = "header",
                name = L["APPEARANCE"],
            },
            font = {
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
                    self:UpdateRoleMarkerState()
                end,
                disabled = IsRoleMarkerDisabled,
            },
            fontSize = {
                name = L["FONT_SIZE"],
                desc = L["FONT_SIZE_DESC"],
                type = "range",
                order = 4.9,
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
                    self:UpdateRoleMarkerState()
                end,
                disabled = IsRoleMarkerDisabled,
            },
            fontFlags = {
                name = L["FONT_FLAGS"],
                type = "select",
                order = 4.95,
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
                    self:UpdateRoleMarkerState()
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
                    db.xOffset = 0
                    db.yOffset = 0
                    self:ApplyRoleMarkerPosition()
                end,
                disabled = IsRoleMarkerDisabled,
            }),
            offsetRow = ColumnRow(6.5, {
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
