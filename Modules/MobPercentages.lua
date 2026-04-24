local _, KeystonePolaris = ...
local _G = _G
local pairs, format, unpack, type = pairs, string.format, unpack, type

local C_ScenarioInfo = _G.C_ScenarioInfo

local L = KeystonePolaris.L

local function HasMobPercentagesAPI()
    return C_ScenarioInfo and type(C_ScenarioInfo.GetUnitCriteriaProgressValues) == "function"
end

local function BuildDisplayText(fmt, showPercent, showCount, showTotal, percentString, rawCount, totalCount)
    local hasPercentText = showPercent and type(percentString) == "string"
    local hasCountText = showCount and type(rawCount) ~= "nil"
    if not hasPercentText and not hasCountText then
        return nil
    end

    local percentText = nil
    if hasPercentText then
        percentText = percentString .. "%"
    end

    local countText = nil
    if hasCountText then
        if showTotal and type(totalCount) ~= "nil" then
            countText = format("%s/%s", rawCount, totalCount)
        else
            countText = rawCount
        end
    end

    if fmt:find("%c", 1, true) == nil and fmt:find("%t", 1, true) == nil then
        if hasPercentText and hasCountText then
            return fmt, { format("%s | %s", percentText, countText) }
        elseif hasPercentText then
            return fmt, { percentText }
        else
            return fmt, { countText }
        end
    end

    local args = {}
    local escapedPercentToken = "\1PCT\2"
    local formatString = fmt:gsub("%%%%", escapedPercentToken)

    formatString = formatString:gsub("%%[sct]", function(token)
        if token == "%s" then
            if hasPercentText then
                args[#args + 1] = percentText
            else
                args[#args + 1] = ""
            end
        elseif token == "%c" then
            if hasCountText then
                args[#args + 1] = rawCount
            else
                args[#args + 1] = ""
            end
        else
            if type(totalCount) ~= "nil" then
                args[#args + 1] = totalCount
            else
                args[#args + 1] = ""
            end
        end

        return "%s"
    end)

    return formatString:gsub(escapedPercentToken, "%%%%"), args
end

function KeystonePolaris:HideAllMobPercentageFrames()
    if not self.nameplateTextFrames then
        self.nameplateTextFrames = {}
        return
    end

    for unit, frame in pairs(self.nameplateTextFrames) do
        frame:Hide()
        self.nameplateTextFrames[unit] = nil
    end
end

function KeystonePolaris:RefreshMobPercentageFrames()
    for unit in pairs(self.nameplateTextFrames or {}) do
        self:UpdateNameplate(unit)
    end
end

function KeystonePolaris:InitializeMobPercentages()
    if not self.db.profile.mobPercentages.enabled or not HasMobPercentagesAPI() then return end

    if not self.mobPercentFrame then
        self.mobPercentFrame = CreateFrame("Frame")
        self.mobPercentFrame:SetScript("OnEvent", function(_, event, ...)
            if event == "NAME_PLATE_UNIT_ADDED" then
                local unit = ...
                self:UpdateNameplate(unit)
            elseif event == "NAME_PLATE_UNIT_REMOVED" then
                local unit = ...
                self:RemoveNameplate(unit)
            else
                self:UpdateAllNameplates()
            end
        end)
    else
        self.mobPercentFrame:UnregisterAllEvents()
    end

    self.mobPercentFrame:RegisterEvent("NAME_PLATE_UNIT_ADDED")
    self.mobPercentFrame:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
    self.mobPercentFrame:RegisterEvent("CHALLENGE_MODE_START")
    self.mobPercentFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    self.mobPercentFrame:RegisterEvent("SCENARIO_UPDATE")

    self.nameplateTextFrames = self.nameplateTextFrames or {}
    self:UpdateAllNameplates()
end

function KeystonePolaris:UpdateAllNameplates()
    if not self.db.profile.mobPercentages.enabled then return end
    if not HasMobPercentagesAPI() then
        self:HideAllMobPercentageFrames()
        return
    end

    for i = 1, 40 do
        local unit = "nameplate" .. i
        if UnitExists(unit) then
            self:UpdateNameplate(unit)
        end
    end
end

function KeystonePolaris:UpdateNameplate(unit)
    local textFrame = self.nameplateTextFrames and self.nameplateTextFrames[unit] or nil

    if not self.db.profile.mobPercentages.enabled or not HasMobPercentagesAPI() then
        if textFrame then textFrame:Hide() end
        return
    end

    if not C_ChallengeMode.IsChallengeModeActive() then
        if textFrame then textFrame:Hide() end
        return
    end

    if not unit or not UnitExists(unit) then
        if textFrame then textFrame:Hide() end
        return
    end

    if UnitReaction(unit, "player") and UnitReaction(unit, "player") > 4 then
        if textFrame then textFrame:Hide() end
        return
    end

    if not UnitGUID(unit) then
        if textFrame then textFrame:Hide() end
        return
    end

    if not textFrame then
        local nameplate = C_NamePlate.GetNamePlateForUnit(unit)
        if not nameplate then
            return
        end

        textFrame = CreateFrame("Frame", "KPL_PercentFrame_" .. unit, UIParent)
        textFrame:SetSize(80, 30)
        textFrame:SetFrameStrata("MEDIUM")
        textFrame:SetIgnoreParentAlpha(true)

        textFrame.text = textFrame:CreateFontString(nil, "OVERLAY")
        textFrame.text:SetPoint("CENTER")
        textFrame.text:SetFont(self.LSM:Fetch('font', self.db.profile.text.font),
            self.db.profile.mobPercentages.fontSize or 8, "OUTLINE")
        textFrame.text:SetTextColor(
            self.db.profile.mobPercentages.textColor.r or 1,
            self.db.profile.mobPercentages.textColor.g or 1,
            self.db.profile.mobPercentages.textColor.b or 1,
            self.db.profile.mobPercentages.textColor.a or 1
        )

        self.nameplateTextFrames[unit] = textFrame
    end

    self:UpdateNameplatePosition(unit)

    local rawCount, _, percentString = C_ScenarioInfo.GetUnitCriteriaProgressValues(unit)
    local showPercent = self.db.profile.mobPercentages.showPercent
    local showCount = self.db.profile.mobPercentages.showCount
    local showTotal = self.db.profile.mobPercentages.showTotal

    if not showPercent and not showCount then
        textFrame:Hide()
        return
    end

    local totalCount = nil
    if showCount and showTotal then
        totalCount = select(2, self:GetCurrentForcesInfo())
    end

    local fmt = self.db.profile.mobPercentages.customFormat or "(%s)"
    local formatString, args = BuildDisplayText(fmt, showPercent, showCount, showTotal, percentString, rawCount, totalCount)
    if type(formatString) == "nil" or type(args) == "nil" then
        textFrame:Hide()
        return
    end

    textFrame.text:SetFormattedText(formatString, unpack(args))
    textFrame:Show()
end

function KeystonePolaris:RemoveNameplate(unit)
    local textFrame = self.nameplateTextFrames and self.nameplateTextFrames[unit] or nil
    if textFrame then
        textFrame:Hide()
        self.nameplateTextFrames[unit] = nil
    end
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
                                frame.text:SetFont(self.LSM:Fetch('font', self.db.profile.text.font), value, "OUTLINE")
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
                            self.db.profile.mobPercentages.textColor = {r = r, g = g, b = b, a = a}
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

function KeystonePolaris:UpdateNameplatePosition(unit)
    local frame = self.nameplateTextFrames and self.nameplateTextFrames[unit] or nil
    if not frame then return end

    local nameplate = C_NamePlate.GetNamePlateForUnit(unit)
    if not nameplate then return end

    local position = self.db.profile.mobPercentages.position or "RIGHT"
    local xOffset = self.db.profile.mobPercentages.xOffset or 0
    local yOffset = self.db.profile.mobPercentages.yOffset or 0

    frame.text:ClearAllPoints()
    if position == "RIGHT" then
        frame.text:SetPoint("LEFT", frame, "LEFT")
    elseif position == "LEFT" then
        frame.text:SetPoint("RIGHT", frame, "RIGHT")
    else
        frame.text:SetPoint("CENTER", frame, "CENTER")
    end

    frame:ClearAllPoints()
    if position == "RIGHT" then
        frame:SetPoint("LEFT", nameplate, "RIGHT", xOffset, yOffset)
    elseif position == "LEFT" then
        frame:SetPoint("RIGHT", nameplate, "LEFT", xOffset, yOffset)
    elseif position == "TOP" then
        frame:SetPoint("BOTTOM", nameplate, "TOP", xOffset, yOffset)
    elseif position == "BOTTOM" then
        frame:SetPoint("TOP", nameplate, "BOTTOM", xOffset, yOffset)
    else
        frame:SetPoint(position, nameplate, position, xOffset, yOffset)
    end
end

KeystonePolaris.defaults.profile.mobPercentages = {
    enabled = true,
    fontSize = 8,
    textColor = { r = 1, g = 1, b = 1, a = 1 },
    position = "RIGHT",
    showPercent = true,
    showCount = false,
    showTotal = false,
    xOffset = 0,
    yOffset = 0,
    customFormat = "(%s)"
}
