local AddOnName, KeystonePolaris = ...;

local _G = _G;
-- Cache frequently used global functions for better performance
local pairs, select = pairs, select
local C_Scenario = _G.C_Scenario
local C_ScenarioInfo = _G.C_ScenarioInfo

-- Initialize Ace3 libraries
local AceAddon = LibStub("AceAddon-3.0")
KeystonePolaris = AceAddon:NewAddon(KeystonePolaris, AddOnName, "AceConsole-3.0", "AceEvent-3.0");

-- Initialize changelog
KeystonePolaris.Changelog = {}

KeystonePolaris.isMidnight = select(4, GetBuildInfo()) >= 120000

-- Define constants
KeystonePolaris.constants = {
    mediaPath = "Interface\\AddOns\\" .. AddOnName .. "\\media\\"
}

-- Track the last routes update version for prompting users
KeystonePolaris.lastRoutesUpdate = "3.4" -- Set to true when routes have been updated

-- Table to store dungeons with changed routes
KeystonePolaris.CHANGED_ROUTES_DUNGEONS = {
    ["WIS"] = true, -- Windrunner Spire
    ["MAGI"] = true, -- Magisters' Terrace
    ["NPX"] = true, -- Nexus-Point Xenas
    ["MAIS"] = true, -- Maisara Caverns
    ["AA"] = true, -- Algeth'ar Academy
    ["SotT"] = true, -- Seat of the Triumvirate
    ["SKY"] = true, -- Skyreach
    ["PoS"] = true, -- Pit of Saron
}

-- Initialize Ace3 configuration libraries
local AceConfig = LibStub("AceConfig-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")

-- Initialize LibSharedMedia for font and texture support
KeystonePolaris.LSM = LibStub('LibSharedMedia-3.0');

-- Get localization table
local L = LibStub("AceLocale-3.0"):GetLocale(AddOnName, true)
KeystonePolaris.L = L

local LDB = LibStub("LibDataBroker-1.1", true)
local LDBIcon = LibStub("LibDBIcon-1.0", true)
-- One-shot marker used to re-enable mob percentages when the Blizzard API returned.
local MOB_PERCENTAGES_REENABLE_MIGRATION = "3.8"

local function Lerp(a, b, t)
    return a + (b - a) * t
end

local function GradientText(text)
    local len = text and #text or 0
    if len == 0 then return "" end
    local colors = {
        {1, 0.2, 0.2},   -- red
        {1, 0.55, 0},    -- orange
        {1, 0.9, 0.2},   -- yellow
    }
    local out = {}
    for i = 1, len do
        local t = (len == 1) and 0 or (i - 1) / (len - 1)
        local c1, c2, lt
        if t <= 0.5 then
            c1, c2, lt = colors[1], colors[2], t * 2
        else
            c1, c2, lt = colors[2], colors[3], (t - 0.5) * 2
        end
        local r = Lerp(c1[1], c2[1], lt)
        local g = Lerp(c1[2], c2[2], lt)
        local b = Lerp(c1[3], c2[3], lt)
        out[i] = string.format("|cff%02x%02x%02x%s|r",
            math.floor((r * 255) + 0.5),
            math.floor((g * 255) + 0.5),
            math.floor((b * 255) + 0.5),
            text:sub(i, i))
    end
    return table.concat(out)
end

local function BuildModulesOverviewDescription()
    local featureIcon = "|TInterface\\OptionsFrame\\UI-OptionsFrame-NewFeatureIcon:14:14:0:0|t"
    local intro = L["MODULES_SUMMARY_INTRO"]
    local mobPercentagesTitle = L["MOB_PERCENTAGES"]
    local mobPercentagesDesc = L["MODULES_SUMMARY_MOB_PERCENTAGES_DESC"]
    local groupReminderTitle = L["KPL_GR_HEADER"]
    local groupReminderDesc = L["MODULES_SUMMARY_GROUP_REMINDER_DESC"]

    return table.concat({
        intro,
        "",
        featureIcon .. " |cffffd100" .. mobPercentagesTitle .. "|r",
        "   |cff9d9d9d" .. mobPercentagesDesc .. "|r",
        "",
        featureIcon .. " |cffffd100" .. groupReminderTitle .. "|r",
        "   |cff9d9d9d" .. groupReminderDesc .. "|r",
    }, "\n")
end

function KeystonePolaris:GetGradientAddonName()
    if not self._gradientAddonName then
        self._gradientAddonName = GradientText("Keystone Polaris")
    end
    return self._gradientAddonName
end

function KeystonePolaris:GetGradientAddonNameFromSecondLetter()
    if not self._gradientAddonNameFromSecond then
        local name = "Keystone Polaris"
        local first = name:sub(1, 1)
        local rest = name:sub(2)
        self._gradientAddonNameFromSecond = first .. GradientText(rest)
    end
    return self._gradientAddonNameFromSecond
end

function KeystonePolaris:GetChatPrefix(bracketed, plain)
    local name = plain and "Keystone Polaris" or self:GetGradientAddonName()
    if bracketed then
        if plain then
            return "[" .. name .. "]"
        end
        return "|cffffd100[|r" .. name .. "|cffffd100]|r"
    end
    return name
end

function KeystonePolaris.ColorizeCommands(_, text)
    if type(text) ~= "string" then return text end
    local knownSubCommands = {
        help = true,
        reminder = true,
        changelog = true,
    }
    local out = {}
    local index = 1
    while true do
        local startPos, endPos, cmd = text:find("(/%w+)", index)
        if not startPos then
            table.insert(out, text:sub(index))
            break
        end
        table.insert(out, text:sub(index, startPos - 1))
        local subStart, subEnd, subWord = text:find("%s+(%w+)", endPos + 1)
        if subStart == endPos + 1 and subWord and knownSubCommands[subWord] then
            table.insert(out, "|cffffd100" .. cmd .. text:sub(subStart, subEnd) .. "|r")
            index = subEnd + 1
        else
            table.insert(out, "|cffffd100" .. cmd .. "|r")
            index = endPos + 1
        end
    end
    return table.concat(out)
end

local function EnsureMinimapSettings(self)
    if not (self.db and self.db.profile and self.db.profile.general) then return end
    local general = self.db.profile.general
    general.minimap = general.minimap or {}
    if general.minimap.minimapPos == nil and general.minimapAngle ~= nil then
        general.minimap.minimapPos = general.minimapAngle
    end
    if general.minimap.hide == nil then
        general.minimap.hide = not general.showMinimapIcon
    end
    if general.minimap.showInCompartment == nil then
        general.minimap.showInCompartment = general.showCompartmentIcon ~= false
    end
end

local function EnsureAddonCompartmentLoaded()
    if _G.AddonCompartmentFrame then return end
    if C_AddOns and C_AddOns.LoadAddOn then
        C_AddOns.LoadAddOn("Blizzard_AddonCompartment")
    end
end

local function CleanupCompartmentEntries(self)
    local compartmentFrame = _G.AddonCompartmentFrame
    if not compartmentFrame or not compartmentFrame.registeredAddons then return end
    local label = (self.GetGradientAddonName and self:GetGradientAddonName()) or "Keystone Polaris"
    for i = #compartmentFrame.registeredAddons, 1, -1 do
        local entry = compartmentFrame.registeredAddons[i]
        if entry and (entry.text == AddOnName or entry.text == label) then
            table.remove(compartmentFrame.registeredAddons, i)
        end
    end
    if compartmentFrame.UpdateDisplay then
        compartmentFrame:UpdateDisplay()
    end
end

local function UpdateCompartmentEntryLabel(self)
    local compartmentFrame = _G.AddonCompartmentFrame
    if not compartmentFrame or not compartmentFrame.registeredAddons then return end
    local label = (self.GetGradientAddonName and self:GetGradientAddonName()) or "Keystone Polaris"
    for i = 1, #compartmentFrame.registeredAddons do
        local entry = compartmentFrame.registeredAddons[i]
        if entry and entry.text == AddOnName then
            entry.text = label
            entry.icon = entry.icon or "Interface\\AddOns\\KeystonePolaris\\icon.png"
            if compartmentFrame.UpdateDisplay then
                compartmentFrame:UpdateDisplay()
            end
            return
        end
    end
end

function KeystonePolaris:UpdateMinimapIconVisibility()
    if not LDBIcon then return end
    EnsureMinimapSettings(self)
    if not (self.db and self.db.profile and self.db.profile.general) then return end
    local general = self.db.profile.general
    local hide = not general.showMinimapIcon
    general.minimap.hide = hide
    if hide then
        LDBIcon:Hide(AddOnName)
    else
        LDBIcon:Show(AddOnName)
    end
end

function KeystonePolaris:InitializeMinimapIcon()
    if self._minimapIconInitialized or not (LDB and LDBIcon) then return end
    EnsureMinimapSettings(self)

    if not self._ldbObject then
        self._ldbObject = LDB:NewDataObject(AddOnName, {
            type = "data source",
            text = "Keystone Polaris",
            icon = "Interface\\AddOns\\KeystonePolaris\\icon.png",
            OnClick = function()
                if self.ToggleConfig then
                    self:ToggleConfig()
                end
            end,
            OnTooltipShow = function(tooltip)
                if not tooltip or not tooltip.AddLine then return end
                tooltip:AddLine("Keystone Polaris")
                tooltip:AddLine("Click to open options", 1, 1, 1)
            end,
        })
    end

    LDBIcon:Register(AddOnName, self._ldbObject, self.db.profile.general.minimap)
    self._minimapIconInitialized = true
    self:UpdateMinimapIconVisibility()
end

function KeystonePolaris:UpdateCompartmentIconVisibility()
    if not (self.db and self.db.profile and self.db.profile.general) then return end
    local show = self.db.profile.general.showCompartmentIcon ~= false
    if not LDBIcon then return end
    EnsureAddonCompartmentLoaded()
    if not _G.AddonCompartmentFrame then
        if not self._pendingCompartmentUpdate and C_Timer and C_Timer.After then
            self._pendingCompartmentUpdate = true
            C_Timer.After(1, function()
                self._pendingCompartmentUpdate = false
                if self.UpdateCompartmentIconVisibility then
                    self:UpdateCompartmentIconVisibility()
                end
            end)
        end
        return
    end
    EnsureMinimapSettings(self)
    if self.db.profile.general.minimap then
        self.db.profile.general.minimap.showInCompartment = show
    end
    if LDBIcon.RemoveButtonFromCompartment then
        LDBIcon:RemoveButtonFromCompartment(AddOnName)
    end
    CleanupCompartmentEntries(self)
    if show and LDBIcon.AddButtonToCompartment then
        LDBIcon:AddButtonToCompartment(AddOnName)
        UpdateCompartmentEntryLabel(self)
    end
end

-- Initialize dungeons table to store all dungeon data
KeystonePolaris.DUNGEONS = {}


-- Track current dungeon and section
KeystonePolaris.currentDungeonID = 0
KeystonePolaris.currentSection = 1
KeystonePolaris.currentSectionOrder = nil

-- Called when the addon is first loaded
function KeystonePolaris:OnInitialize()
    -- Initialize the database first with AceDB
    self.db = LibStub("AceDB-3.0"):New("KeystonePolarisDB", self.defaults, "Default")

    local general = self.db.profile.general
    -- Force-enable the returning feature once per profile, then keep user choice afterwards.
    if general.mobPercentagesMigrationVersion ~= MOB_PERCENTAGES_REENABLE_MIGRATION then
        self.db.profile.mobPercentages = self.db.profile.mobPercentages or {}
        self.db.profile.mobPercentages.enabled = true
        general.mobPercentagesMigrationVersion = MOB_PERCENTAGES_REENABLE_MIGRATION
    end

    -- Migrate prefixColor from general.mainDisplay to color.prefix
    local oldPrefix = self.db.profile.general.mainDisplay.prefixColor
    if oldPrefix then
        if not self.db.profile.color.prefix then
            self.db.profile.color.prefix = oldPrefix
        end
        self.db.profile.general.mainDisplay.prefixColor = nil
    end

    -- Load dungeon data from expansion modules
    self:LoadExpansionDungeons()

    -- Generate changelog for display in options
    self:GenerateChangelog()
    self:GenerateAbout()

    -- Check if a new season has started
    self:CheckForNewSeason()

    -- Check if routes have been updated in a new version
    self:CheckForNewRoutes()

    -- Initialize Display (Frames, Overlay, Anchors) - Moved to Modules/Display.lua
    if self.InitializeDisplay then
        self:InitializeDisplay()
    end

    self:InitializeMinimapIcon()
    self:UpdateCompartmentIconVisibility()

    -- Register options with Ace3 config system
    local optionsAddonName = (self.GetGradientAddonNameFromSecondLetter and self:GetGradientAddonNameFromSecondLetter()) or "Keystone Polaris"
    local optionsAddonDisplayName = (self.GetGradientAddonName and self:GetGradientAddonName()) or optionsAddonName
    local modulesSummaryDescription = BuildModulesOverviewDescription(L)
    AceConfig:RegisterOptionsTable(AddOnName, {
        name = optionsAddonDisplayName,
        type = "group",
        args = {
            general = {
                name = L["GENERAL_SETTINGS"],
                type = "group",
                order = 1,
                childGroups = "tree",
                args = {
                    disclaimerHeader = {
                        order = 0,
                        type = "header",
                        name = "|TInterface\\OptionsFrame\\UI-OptionsFrame-NewFeatureIcon:16:16:0:0|t " .. L["COMPATIBILITY_WARNING"],
                    },
                    warningMessage = {
                        name = L["COMPATIBILITY_WARNING_MESSAGE_CORE"],
                        type = "description",
                        order = 0.15,
                        width = "full",
                        fontSize = "medium",
                    },
                    display = self:GetDisplayOptions(),
                    appearance = self:GetAppearanceOptions(),
                    positioning = self:GetPositioningOptions(),
                    informGroup = self:GetInformGroupOptions(),
                    interface = self:GetInterfaceOptions(),
                }
            },
            modules = {
                name = L["MODULES"],
                type = "group",
                order = 2,
                childGroups = "tree",
                args = {
                    modulesSummaryHeader = {
                        order = 0,
                        type = "header",
                        name = L["MODULES_SUMMARY_HEADER"] or L["MODULES"],
                    },
                    modulesSummaryDescription = {
                        order = 1,
                        type = "description",
                        name = modulesSummaryDescription,
                        fontSize = "medium",
                    },
                    mobPercentages = self:GetMobPercentagesOptions(),
                    groupReminder = self:GetGroupReminderOptions(),
                }
            },
            advanced = self:GetAdvancedOptions()
        }
    })
    AceConfig:RegisterOptionsTable(AddOnName .. "_Changelog", self.changelogOptions)
    AceConfig:RegisterOptionsTable(AddOnName .. "_About", self.aboutOptions)

    self.optionsCategoryId = select(2, AceConfigDialog:AddToBlizOptions(AddOnName, optionsAddonName))
    self.changelogCategoryId = select(2, AceConfigDialog:AddToBlizOptions(AddOnName .. "_Changelog", L["Changelog"], optionsAddonName))
    self.aboutCategoryId = select(2, AceConfigDialog:AddToBlizOptions(AddOnName .. "_About", L["ABOUT"], optionsAddonName))


    -- Register chat command and events
    self:RegisterChatCommand('kpl', 'ToggleConfig')
    self:RegisterChatCommand('polaris', 'ToggleConfig')

    -- Initialize mob percentages module if enabled
    if self.db.profile.mobPercentages and self.db.profile.mobPercentages.enabled then
        self:InitializeMobPercentages()
    end

    -- Initialize group reminder module if enabled
    if self.db.profile.groupReminder and self.db.profile.groupReminder.enabled then
        self:InitializeGroupReminder()
    end
end

-- Open configuration panel when command is used
function KeystonePolaris:ToggleConfig(input)
    local optionsAddonName = (self.GetGradientAddonNameFromSecondLetter and self:GetGradientAddonNameFromSecondLetter()) or "Keystone Polaris"
    local trim = _G.strtrim or function(value)
        return (value:gsub("^%s+", ""):gsub("%s+$", ""))
    end
    local command = trim(input or ""):lower()
    if command == "help" or command == "?" then
        if self.ShowHelp then self:ShowHelp() end
        return
    end
    if command == "changelog" then
        if Settings and Settings.OpenToCategory then
            Settings.OpenToCategory(self.changelogCategoryId or self.optionsCategoryId or optionsAddonName)
        end
        return
    end
    if command == "reminder" then
        self:ShowLastGroupReminder()
        return
    end

    Settings.OpenToCategory(self.optionsCategoryId or optionsAddonName)
end

function KeystonePolaris:ShowHelp()
    local header = L["COMMANDS_HEADER"] or "Commands"
    local prefix = (self.GetChatPrefix and self:GetChatPrefix(false)) or "[Keystone Polaris]"
    local lines = {
        L["COMMANDS_HELP_OPEN"] or "/kpl or /polaris - Open options",
        L["COMMANDS_HELP_CHANGELOG"] or "/kpl changelog or /polaris changelog - Open changelog",
        L["COMMANDS_HELP_REMINDER"] or "/kpl reminder - Show last group reminder",
        L["COMMANDS_HELP_HELP"] or "/kpl help - Show this help",
    }
    local function addMessage(message)
        if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
            DEFAULT_CHAT_FRAME:AddMessage(message)
        else
            print(message)
        end
    end
    addMessage(prefix .. " " .. header)
    for _, line in ipairs(lines) do
        addMessage(self:ColorizeCommands(line))
    end
end

-- Refresh the addon display (called when options change)
function KeystonePolaris:Refresh()
    if self.UpdateColorCache then self:UpdateColorCache() end
    if self.UpdatePercentageText then self:UpdatePercentageText() end
    if self.ApplyTextLayout then self:ApplyTextLayout() end
    if self.AdjustDisplayFrameSize then self:AdjustDisplayFrameSize() end
end

-- Handler for addon compartment button click
_G.KeystonePolaris_OnAddonCompartmentClick = function()
    KeystonePolaris:ToggleConfig()
end

-- Build logical section order for the given dungeon, using advanced bossOrder when available
function KeystonePolaris:BuildSectionOrder(dungeonId)
    self.currentSectionOrder = nil
    local dungeon = self.DUNGEONS[dungeonId]
    if not dungeon then return end

    local numBosses = #dungeon
    if numBosses == 0 then return end

    local order = {}
    local dungeonKey = self.GetDungeonKeyById and self:GetDungeonKeyById(dungeonId) or nil
    if dungeonKey and self.db and self.db.profile and self.db.profile.advanced and self.db.profile.advanced[dungeonKey] then
        local adv = self.db.profile.advanced[dungeonKey]
        local advOrder = adv.bossOrder
        if type(advOrder) == "table" then
            local valid = true
            for i = 1, numBosses do
                local idx = advOrder[i]
                if type(idx) ~= "number" or idx < 1 or idx > numBosses then
                    valid = false
                    break
                end
                order[i] = math.floor(idx)
            end
            if valid then
                self.currentSectionOrder = order
                return
            end
        end
    end

    -- Fallback: order by required percentage ascending
    for i = 1, numBosses do
        order[i] = i
    end
    table.sort(order, function(a, b)
        local da = dungeon[a]
        local db = dungeon[b]
        local pa = da and da[2] or 0
        local pb = db and db[2] or 0
        return pa < pb
    end)
    self.currentSectionOrder = order
end

-- Initialize dungeon tracking when entering a dungeon
function KeystonePolaris:InitiateDungeon()
    local currentDungeonId = C_ChallengeMode.GetActiveChallengeMapID()
    -- Return if not in a dungeon or already tracking this dungeon
    if currentDungeonId == nil or currentDungeonId == self.currentDungeonID then return end

    -- Set current dungeon and reset to first section
    self.currentDungeonID = currentDungeonId
    self.currentSection = 1
    self:BuildSectionOrder(self.currentDungeonID)
end

-- Get the current enemy forces percentage from the scenario UI
function KeystonePolaris.GetCurrentPercentage(_)
    -- Mirror WarpDeplete logic: scan criteria and use weighted progress with the
    local stepCount = select(3, C_Scenario.GetStepInfo())
    if not stepCount or stepCount <= 0 then return 0 end

    local bestTotal = 0
    local bestCurrent = 0
    for i = 1, stepCount do
        local info = C_ScenarioInfo.GetCriteriaInfo(i)
        if info and info.isWeightedProgress and info.totalQuantity and info.totalQuantity > 0 then
            local currentCount = type(info.quantityString) == "string"
                and (tonumber(info.quantityString:match("%d+")) or 0)
                or (tonumber(info.quantity) or 0)
            if info.totalQuantity > bestTotal then
                bestTotal = info.totalQuantity
                bestCurrent = currentCount
            end
        end
    end

    if bestTotal > 0 then
        return (bestCurrent / bestTotal) * 100
    end
    return 0
end

-- Retrieve raw Enemy Forces counts: current and total. Returns 0,0 if unavailable.
function KeystonePolaris.GetCurrentForcesInfo(_)
    local stepCount = select(3, C_Scenario.GetStepInfo())
    if not stepCount or stepCount <= 0 then return 0, 0 end

    local bestTotal = 0
    local bestCurrent = 0
    for i = 1, stepCount do
        local info = C_ScenarioInfo.GetCriteriaInfo(i)
        if info and info.isWeightedProgress and info.totalQuantity and info.totalQuantity > 0 then
            local currentCount = type(info.quantityString) == "string"
                and (tonumber(info.quantityString:match("%d+")) or 0)
                or (tonumber(info.quantity) or 0)
            if info.totalQuantity > bestTotal then
                bestTotal = info.totalQuantity
                bestCurrent = currentCount
            end
        end
    end

    return bestCurrent, bestTotal
end

-- Get data for the current section of the dungeon
function KeystonePolaris:GetDungeonData()
    local dungeon = self.DUNGEONS[self.currentDungeonID]
    if not dungeon then
        return nil
    end

    if not self.currentSectionOrder then
        if self.currentDungeonID then
            self:BuildSectionOrder(self.currentDungeonID)
        end
    end

    local order = self.currentSectionOrder
    if not order then
        return nil
    end

    local sectionIndex = order[self.currentSection]
    if not sectionIndex or not dungeon[sectionIndex] then
        return nil
    end

    local dungeonData = dungeon[sectionIndex]
    return dungeonData[1], dungeonData[2], dungeonData[3], dungeonData[4]
end

-- Send a chat message to inform the group about missing percentage
function KeystonePolaris:InformGroup(percentage)
    if not self.db.profile.general.informGroup then return end

    local percentageStr = string.format("%.2f%%", percentage)
    -- Don't send message if percentage is 0
    if percentageStr == "0.00%" then return end
    local prefix = (self.GetChatPrefix and self:GetChatPrefix(true, true)) or "[Keystone Polaris]"
    self:PrepareInformMacro(prefix .. ": " .. L["WE_STILL_NEED"] .. " " .. percentageStr)
    -- SendChatMessage(prefix .. ": " .. L["WE_STILL_NEED"] .. " " .. percentageStr, channel)
end


-- Called when the addon is enabled
function KeystonePolaris:OnEnable()
    -- Ensure display exists and is visible
    if self.CreateDisplayFrame then
        self:CreateDisplayFrame()
    end

    -- Mythic+ mode triggers
    self:RegisterEvent("CHALLENGE_MODE_START")
    self:RegisterEvent("CHALLENGE_MODE_COMPLETED")

	-- Scenario triggers
	self:RegisterEvent("SCENARIO_POI_UPDATE")
	self:RegisterEvent("SCENARIO_CRITERIA_UPDATE")

    self:RegisterEvent("PLAYER_ENTERING_WORLD")

    -- Extra refresh triggers for dynamic current pull percent
    if self.InitializePullTracker then
        self:InitializePullTracker()
    end

    -- Force an initial update
    if self.UpdatePercentageText then
        self:UpdatePercentageText()
    end
end

-- Event handler for POI updates (boss positions)
function KeystonePolaris:SCENARIO_POI_UPDATE()
    if self._QueuePullUpdate then self:_QueuePullUpdate() end
end

-- Event handler for criteria updates (enemy forces percentage changes)
-- This event fires once per mob killed, so debouncing is critical to avoid
-- hanging the game when a large pack dies all at once.
function KeystonePolaris:SCENARIO_CRITERIA_UPDATE()
    if self._QueuePullUpdate then self:_QueuePullUpdate() end
end

-- Event handler for starting a Mythic+ dungeon
function KeystonePolaris:CHALLENGE_MODE_START()
    if self._testMode and self.DisableTestMode then self:DisableTestMode("started dungeon") end
    self.currentDungeonID = nil

    self:InitiateDungeon()
    if self.HideInformButton then self:HideInformButton() end
    if self.PrepareInformMacro then
        C_Timer.After(5, function()
            if self.PrepareInformMacro then
                self:PrepareInformMacro(nil) -- init macro without fake percent text
            end
        end)
    end
    if self.UpdatePercentageText then self:UpdatePercentageText() end
end

function KeystonePolaris:CHALLENGE_MODE_COMPLETED()
    self.currentDungeonID = nil
    if self.HideInformButton then self:HideInformButton() end
end

-- Event handler for entering the world or changing zones
function KeystonePolaris:PLAYER_ENTERING_WORLD()
    if self._testMode and self.DisableTestMode then self:DisableTestMode("changed zone") end
    self:InitiateDungeon()
    if self.HideInformButton then self:HideInformButton() end
    if self.PrepareInformMacro then
        -- Utilise le message par défaut (WE_STILL_NEED + % fictif)
        C_Timer.After(10, function()
            if self.PrepareInformMacro then
                self:PrepareInformMacro(nil)
            end
        end)
    end
    if self.UpdatePercentageText then self:UpdatePercentageText() end
end

-- Update dungeon data with advanced options if enabled
function KeystonePolaris:UpdateDungeonData()
    if self.db.profile.general.advancedOptionsEnabled then
        for dungeonId, dungeonData in pairs(self.DUNGEONS) do
            local dungeonKey = self:GetDungeonKeyById(dungeonId)
            if dungeonKey then
                local advancedData = self.db.profile.advanced[dungeonKey]
                local defaultBosses = self.GlobalDungeonLookup
                    and self.GlobalDungeonLookup[dungeonKey]
                    and self.GlobalDungeonLookup[dungeonKey].bosses
                for i, bossData in ipairs(dungeonData) do
                    local bossNumStr = self:GetBossNumberString(i)

                    local pct = advancedData and advancedData["Boss" .. bossNumStr] or nil
                    local inform = advancedData and advancedData["Boss" .. bossNumStr .. "Inform"] or nil

                    if pct == nil and defaultBosses and defaultBosses[i] then
                        pct = defaultBosses[i][2]
                    end
                    if inform == nil and defaultBosses and defaultBosses[i] then
                        inform = defaultBosses[i][3]
                    end

                    if pct ~= nil then
                        bossData[2] = pct
                    end
                    if inform ~= nil then
                        bossData[3] = inform
                    end
                    bossData[4] = false -- Reset informed status
                end
            end
        end
    end
end
