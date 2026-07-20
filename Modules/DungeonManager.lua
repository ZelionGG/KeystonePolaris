local AddOnName, KeystonePolaris = ...
local L = LibStub("AceLocale-3.0"):GetLocale(AddOnName)

-- ---------------------------------------------------------------------------
-- Dungeon Data & Management
-- ---------------------------------------------------------------------------

-- List of expansions and their corresponding data
-- Exposed to the addon object so other modules can access it if needed
KeystonePolaris.Expansions = {
    {id = "MIDNIGHT", name = "EXPANSION_MIDNIGHT", order = 3}, -- Midnight
    {id = "TWW", name = "EXPANSION_WW", order = 4}, -- The War Within
    {id = "DF", name = "EXPANSION_DF", order = 5}, -- Dragonflight
    {id = "SL", name = "EXPANSION_SL", order = 6}, -- Shadowlands
    {id = "BFA", name = "EXPANSION_BFA", order = 7}, -- Battle for Azeroth
    {id = "LEGION", name = "EXPANSION_LEGION", order = 8}, -- Legion
    {id = "WOD", name = "EXPANSION_WOD", order = 9},       -- Warlords of Draenor
    -- {id = "MOP", name = "EXPANSION_MOP", order = 10},      -- Mists of Pandaria
    {id = "CATACLYSM", name = "EXPANSION_CATA", order = 11}, -- Cataclysm
    {id = "WOTLK", name = "EXPANSION_WOTLK", order = 12}, -- Wrath of the Lich King
    -- {id = "TBC", name = "EXPANSION_TBC", order = 13} -- The Burning Crusade
    -- {id = "Vanilla", name = "EXPANSION_VANILLA", order = 14} -- Vanilla WoW
}

local expansions = KeystonePolaris.Expansions

-- Deep clone helper
local function CloneTable(tbl)
    if type(CopyTable) == "function" then return CopyTable(tbl) end
    if type(tbl) ~= "table" then return tbl end

    local t = {}
    for k, v in pairs(tbl) do
        if type(v) == "table" then
            t[k] = CloneTable(v)
        else
            t[k] = v
        end
    end
    return t
end

local function NormalizeDefaultMilestones(milestones)
    if type(milestones) ~= "table" or #milestones == 0 then
        return {}
    end

    local normalized = {}
    for index, milestone in ipairs(milestones) do
        if type(milestone) == "table" then
            local triggerType = tostring(milestone.triggerType or "none"):lower()
            if triggerType ~= "none" and triggerType ~= "zone" and triggerType ~= "subzone" then
                triggerType = "none"
            end
            normalized[#normalized + 1] = {
                id = tonumber(milestone.id) or index,
                label = tostring(milestone.label or ""),
                thresholdPercent = tonumber(milestone.thresholdPercent) or 0,
                triggerType = triggerType,
                matchAreaID = tonumber(milestone.matchAreaID),
                matchMapID = tonumber(milestone.matchMapID),
                matchText = tostring(milestone.matchText or ""),
                informSuffix = tostring(milestone.informSuffix or ""),
                inform = milestone.inform == true,
                creationOrder = tonumber(milestone.creationOrder) or index,
            }
        end
    end
    return normalized
end

local function MilestoneMatchesDefaultIdentity(saved, default)
    if type(saved) ~= "table" or type(default) ~= "table" then
        return false
    end

    local savedId = tonumber(saved.id)
    local defaultId = tonumber(default.id)
    if savedId and defaultId and savedId == defaultId then
        return true
    end

    local savedAreaID = tonumber(saved.matchAreaID)
    local defaultAreaID = tonumber(default.matchAreaID)
    if savedAreaID and defaultAreaID and savedAreaID == defaultAreaID then
        return true
    end

    local savedMapID = tonumber(saved.matchMapID)
    local defaultMapID = tonumber(default.matchMapID)
    if savedMapID and defaultMapID and savedMapID == defaultMapID then
        return true
    end

    return false
end

local function IsIncompleteDefaultMilestone(saved, default)
    if not MilestoneMatchesDefaultIdentity(saved, default) then
        return false
    end

    local threshold = tonumber(saved.thresholdPercent) or 0
    local triggerType = tostring(saved.triggerType or "none"):lower()
    local label = tostring(saved.label or ""):match("^%s*(.-)%s*$") or ""

    return threshold == 0 and triggerType == "none" and label == ""
end

local function MergeMilestoneFields(saved, default, fillIncomplete)
    for key, value in pairs(default) do
        if key ~= "id" and key ~= "creationOrder" then
            local current = saved[key]
            local shouldFill = current == nil
            if fillIncomplete then
                if key == "label" and (current == nil or current == "") then
                    shouldFill = true
                elseif key == "thresholdPercent" and (current == nil or (tonumber(current) or 0) == 0) then
                    shouldFill = true
                elseif key == "triggerType" and (current == nil or tostring(current):lower() == "none") then
                    shouldFill = true
                elseif key == "inform" and current ~= true and value == true then
                    shouldFill = true
                elseif key == "informSuffix" and (current == nil or current == "") then
                    shouldFill = true
                elseif key == "matchText" and (current == nil or current == "") then
                    shouldFill = true
                end
            end
            if shouldFill then
                if type(value) == "table" then
                    saved[key] = CloneTable(value)
                else
                    saved[key] = value
                end
            end
        end
    end
end

local function EnsureSavedMilestonesTable(savedAdvanced)
    if type(savedAdvanced.milestones) ~= "table" then
        savedAdvanced.milestones = {}
    end
    return savedAdvanced.milestones
end

local function SeedMilestoneDefaultsIfNeeded(savedAdvanced, defaultMilestones)
    if type(defaultMilestones) ~= "table" or #defaultMilestones == 0 then
        return false
    end

    if savedAdvanced.milestonesUserEdited then
        EnsureSavedMilestonesTable(savedAdvanced)
        return false
    end

    local savedMilestones = savedAdvanced.milestones
    if savedMilestones == nil or (type(savedMilestones) == "table" and #savedMilestones == 0) then
        savedAdvanced.milestones = CloneTable(defaultMilestones)
        return true
    end

    if type(savedMilestones) ~= "table" then
        savedAdvanced.milestones = CloneTable(defaultMilestones)
        return true
    end

    return false
end

local function MergeAdvancedMilestoneDefaults(savedAdvanced, defaultAdvanced)
    if type(savedAdvanced) ~= "table" or type(defaultAdvanced) ~= "table" then
        return
    end

    local defaultMilestones = defaultAdvanced.milestones
    if type(defaultMilestones) ~= "table" or #defaultMilestones == 0 then
        return
    end

    if SeedMilestoneDefaultsIfNeeded(savedAdvanced, defaultMilestones) then
        return
    end

    local savedMilestones = savedAdvanced.milestones
    if type(savedMilestones) ~= "table" or #savedMilestones == 0 then
        return
    end

    for index, savedMilestone in ipairs(savedMilestones) do
        if type(savedMilestone) == "table" then
            for _, defaultMilestone in ipairs(defaultMilestones) do
                if MilestoneMatchesDefaultIdentity(savedMilestone, defaultMilestone) then
                    local fillIncomplete = IsIncompleteDefaultMilestone(savedMilestone, defaultMilestone)
                    MergeMilestoneFields(savedMilestone, defaultMilestone, fillIncomplete)
                    break
                end
            end
            if savedMilestone.id == nil then
                savedMilestone.id = index
            end
            if savedMilestone.creationOrder == nil then
                savedMilestone.creationOrder = index
            end
        end
    end
end

function KeystonePolaris:MergeDungeonMilestoneDefaults(dungeonKey)
    if not dungeonKey or not self.db or not self.db.profile or not self.db.profile.advanced then
        return
    end

    local savedAdvanced = self.db.profile.advanced[dungeonKey]
    if type(savedAdvanced) ~= "table" then
        return
    end

    for _, expansion in ipairs(expansions) do
        local dungeonIds = self[expansion.id .. "_DUNGEON_IDS"]
        if dungeonIds and dungeonIds[dungeonKey] then
            local defaultAdvanced = self[expansion.id .. "_DEFAULTS"][dungeonKey]
            if defaultAdvanced then
                MergeAdvancedMilestoneDefaults(savedAdvanced, defaultAdvanced)
            end
            return
        end
    end
end

-- ---------------------------------------------------------------------------
-- Season Date Helpers
-- ---------------------------------------------------------------------------
-- start_date/end_date can be:
--   - a string "YYYY-MM-DD"
--   - a table keyed by portal (US/EU) with optional "default"
local function ResolveSeasonDate(dateValue)
    if not dateValue then return nil end
    if type(dateValue) ~= "table" then return dateValue end
    local portal = C_CVar.GetCVar("portal")
    return dateValue[portal] or dateValue.default or dateValue.US or
               dateValue.EU
end

local function ResolveSeasonTimestamp(dateStr, defaultHour, defaultMin, useNowIfToday)
    if not dateStr or dateStr == "" then return nil end
    local y, m, d, h, min = dateStr:match("^(%d%d%d%d)%-(%d%d)%-(%d%d)%s+(%d%d):(%d%d)$")
    local hasTime = y ~= nil
    if not hasTime then
        y, m, d = dateStr:match("^(%d%d%d%d)%-(%d%d)%-(%d%d)$")
    end
    local year, month, day = tonumber(y), tonumber(m), tonumber(d)
    if not year or not month or not day then return nil end

    if not hasTime and useNowIfToday and dateStr == date("%Y-%m-%d") then
        return time()
    end

    local hour = defaultHour or 12
    local minute = defaultMin or 0
    if hasTime then
        hour = tonumber(h)
        minute = tonumber(min)
        if not hour or not minute then return nil end
    end

    return time({year = year, month = month, day = day, hour = hour, min = minute})
end

-- Returns current/next season ids and their resolved start/end dates.
-- Current season: start_date <= today and (no end_date or today <= end_date).
-- If end_date is missing, the season is considered active until the next
-- start_date is reached.
function KeystonePolaris:GetSeasonByDate(dateStr)
    local currentId, currentStart, currentEnd
    local nextId, nextStart
    local compareDate = dateStr or date("%Y-%m-%d")
    local compareTs = ResolveSeasonTimestamp(compareDate, 12, 0, true)

    for key, tbl in pairs(self) do
        if type(tbl) == "table" and key:match("_DUNGEONS$") and tbl.start_date and
            not tbl.is_remix then
            local startDate = ResolveSeasonDate(tbl.start_date)
            local endDate = ResolveSeasonDate(tbl.end_date)
            local startTs = ResolveSeasonTimestamp(startDate, 0, 0, false)
            local endTs = ResolveSeasonTimestamp(endDate, 23, 59, false)

            if startTs and compareTs and startTs <= compareTs and
                (not endTs or compareTs <= endTs) then
                if not currentStart or startTs > ResolveSeasonTimestamp(currentStart, 0, 0, false) then
                    currentId = key:gsub("_DUNGEONS$", "")
                    currentStart = startDate
                    currentEnd = endDate
                end
            elseif startTs and compareTs and startTs > compareTs then
                if not nextStart or startTs < ResolveSeasonTimestamp(nextStart, 0, 0, false) then
                    nextId = key:gsub("_DUNGEONS$", "")
                    nextStart = startDate
                end
            end
        end
    end

    return currentId, currentStart, currentEnd, nextId, nextStart
end

function KeystonePolaris.GetBossNumberString(selfOrNum, maybeNum)
    local num = maybeNum ~= nil and maybeNum or selfOrNum
    local numbers = {
        [1] = "One",
        [2] = "Two",
        [3] = "Three",
        [4] = "Four",
        [5] = "Five",
        [6] = "Six",
        [7] = "Seven",
        [8] = "Eight",
        [9] = "Nine",
        [10] = "Ten"
    }
    return numbers[num] or tostring(num)
end

function KeystonePolaris:GenerateExpansionTables(expansionId, dungeonData)
    -- Initialize the tables if they don't exist
    self[expansionId .. "_DUNGEONS"] = self[expansionId .. "_DUNGEONS"] or {}
    self[expansionId .. "_DEFAULTS"] = self[expansionId .. "_DEFAULTS"] or {}
    self[expansionId .. "_DUNGEON_IDS"] = self[expansionId .. "_DUNGEON_IDS"] or {}
    self[expansionId .. "_DUNGEON_NAMES"] = self[expansionId .. "_DUNGEON_NAMES"] or {}

    -- Clear existing data if any
    wipe(self[expansionId .. "_DUNGEONS"])
    wipe(self[expansionId .. "_DEFAULTS"])
    wipe(self[expansionId .. "_DUNGEON_IDS"])
    wipe(self[expansionId .. "_DUNGEON_NAMES"])

    for shortName, dData in pairs(dungeonData) do
        -- Support for 'hidden' flag to skip unimplemented dungeons
        if not dData.hidden then
            -- Generate DUNGEONS table
            local dungeonBosses = {}
            for i, bossData in ipairs(dData.bosses) do
                -- Add haveInformed = false to each boss entry
                dungeonBosses[i] = {bossData[1], bossData[2], bossData[3], false}
            end
            self[expansionId .. "_DUNGEONS"][dData.id] = dungeonBosses

            -- Generate DEFAULTS table
            local defaults = {}
            local numBosses = #dData.bosses
            local bossOrder = {}
            for i, bossData in ipairs(dData.bosses) do
                local bossNumber = "Boss" .. self:GetBossNumberString(i)
                defaults[bossNumber] = bossData[2]
                defaults[bossNumber .. "Inform"] = bossData[3]

                -- Optional 4th field in bossData defines the logical section order (rank)
                local rank = bossData[4]
                if type(rank) == "number" then
                    rank = math.floor(rank)
                    if rank >= 1 and rank <= numBosses then
                        bossOrder[rank] = i
                    end
                end
            end

            -- Only store bossOrder if it forms a complete permutation of 1..numBosses
            local hasOrder = next(bossOrder) ~= nil
            if hasOrder then
                for idx = 1, numBosses do
                    if not bossOrder[idx] then
                        hasOrder = false
                        break
                    end
                end
            end
            if hasOrder then
                defaults.bossOrder = bossOrder
            end
            if type(dData.milestones) == "table" and #dData.milestones > 0 then
                defaults.milestones = NormalizeDefaultMilestones(dData.milestones)
            else
                defaults.milestones = {}
            end

            self[expansionId .. "_DEFAULTS"][shortName] = defaults
        end

        -- Always generate IDS and NAMES tables, even if hidden, so they can be referenced
        self[expansionId .. "_DUNGEON_IDS"][shortName] = dData.id
        self[expansionId .. "_DUNGEON_NAMES"][shortName] = dData.displayName
    end
end

function KeystonePolaris:LoadExpansionDungeons()
    -- Initialize Global Lookup Table for faster access
    self.GlobalDungeonLookup = {} -- Maps dungeonKey (shortName) -> dungeonData
    self.GlobalDungeonIDLookup = {} -- Maps dungeonID -> dungeonKey

    -- Process dungeon data and generate tables for all expansions
    for _, expansion in ipairs(expansions) do
        local dungeonData = self[expansion.id .. "_DUNGEON_DATA"]
        if dungeonData then
            -- Generate the tables for this expansion
            self:GenerateExpansionTables(expansion.id, dungeonData)

            -- Populate Global Lookup and Initialize defaults
            for shortName, dData in pairs(dungeonData) do
                -- Add to global lookup
                self.GlobalDungeonLookup[shortName] = dData
                if dData.id then
                    self.GlobalDungeonIDLookup[dData.id] = shortName
                end

                -- Ensure the advanced settings table exists for this dungeon
                if not self.db.profile.advanced[shortName] then
                    self.db.profile.advanced[shortName] = {}
                end

                -- Initialize with defaults if needed (only if not hidden, effectively)
                local defaults = self[expansion.id .. "_DEFAULTS"][shortName]
                if defaults then
                    local advancedEntry = self.db.profile.advanced[shortName]
                    for key, value in pairs(defaults) do
                        if advancedEntry[key] == nil then
                            if key == "milestones" then
                                if not SeedMilestoneDefaultsIfNeeded(advancedEntry, value) then
                                    EnsureSavedMilestonesTable(advancedEntry)
                                end
                            elseif type(value) == "table" then
                                advancedEntry[key] = CloneTable(value)
                            else
                                advancedEntry[key] = value
                            end
                        end
                    end
                    if self.MergeDungeonMilestoneDefaults then
                        self:MergeDungeonMilestoneDefaults(shortName)
                    end
                end
            end

            -- Load dungeons into the main DUNGEONS table
            local dungeons = self[expansion.id .. "_DUNGEONS"]
            if dungeons then
                for id, data in pairs(dungeons) do
                    self.DUNGEONS[id] = data
                end
            end
        end
    end

    -- Load defaults for AceConfig profile from generated expansion defaults
    -- This ensures that even if we reset profile, we have the right defaults
    for _, expansion in ipairs(expansions) do
        local defaults = self[expansion.id .. "_DEFAULTS"]
        if defaults then
            for k, v in pairs(defaults) do
                if type(v) == "table" then
                    KeystonePolaris.defaults.profile.advanced[k] = CloneTable(v)
                else
                    KeystonePolaris.defaults.profile.advanced[k] = v
                end
            end
        end
    end
end

-- ---------------------------------------------------------------------------
-- Data Accessors (Optimized with Global Lookup)
-- ---------------------------------------------------------------------------

function KeystonePolaris:GetDungeonEncounterID(dungeonKey, bossIndex)
    local dungeonData = self.GlobalDungeonLookup and self.GlobalDungeonLookup[dungeonKey]
    if dungeonData and dungeonData.bosses and dungeonData.bosses[bossIndex] then
        return dungeonData.bosses[bossIndex][5]
    end
    return nil
end

function KeystonePolaris:GetBossName(dungeonKey, bossIdx)
    local name
    local encounterID = self:GetDungeonEncounterID(dungeonKey, bossIdx)

    if encounterID then
        -- Try to get name from Encounter Journal using the ID
        name = EJ_GetEncounterInfo(encounterID)
    end

    if not name then
        -- Try to find manual boss name (6th parameter)
        local dungeonData = self.GlobalDungeonLookup and self.GlobalDungeonLookup[dungeonKey]
        if dungeonData and dungeonData.bosses and dungeonData.bosses[bossIdx] then
            name = dungeonData.bosses[bossIdx][6]
        end
    end

    return name or ("Boss " .. bossIdx)
end

function KeystonePolaris:GetDungeonMapID(dungeonKey)
    local dungeonData = self.GlobalDungeonLookup and self.GlobalDungeonLookup[dungeonKey]
    if dungeonData then
        return dungeonData.mapID
    end
    return nil
end

function KeystonePolaris:GetDungeonIdByKey(dungeonKey)
    local dungeonData = self.GlobalDungeonLookup and self.GlobalDungeonLookup[dungeonKey]
    if dungeonData then
        return dungeonData.id
    end
    return nil
end

function KeystonePolaris:GetDungeonKeyById(dungeonId)
    return self.GlobalDungeonIDLookup and self.GlobalDungeonIDLookup[dungeonId] or nil
end

local DUNGEON_ICON_PLACEHOLDER = "Interface\\Icons\\INV_Misc_QuestionMark"

function KeystonePolaris:GetDungeonIcon(dungeonKey)
    if not dungeonKey then return DUNGEON_ICON_PLACEHOLDER end

    local dungeonData = self.GlobalDungeonLookup and self.GlobalDungeonLookup[dungeonKey]
    local mapId = dungeonData and dungeonData.id

    if mapId then
        local texture = select(4, C_ChallengeMode.GetMapUIInfo(mapId))
        if texture then return texture end
    end

    local teleportID = dungeonData and dungeonData.teleportID
    if teleportID and type(teleportID) == "number" then
        local icon
        if C_Spell and C_Spell.GetSpellTexture then
            icon = C_Spell.GetSpellTexture(teleportID)
        elseif GetSpellInfo then
            icon = select(3, GetSpellInfo(teleportID))
        end
        if icon then return icon end
    end

    local lfgID = dungeonData and dungeonData.lfgID
    if lfgID and type(lfgID) == "number" then
        if C_LFGInfo and C_LFGInfo.GetDungeonInfo then
            local info = C_LFGInfo.GetDungeonInfo(lfgID)
            if info and info.iconID then return info.iconID end
        end
        if GetLFGDungeonInfo then
            local textureFilename = select(11, GetLFGDungeonInfo(lfgID))
            if textureFilename and textureFilename ~= "" then
                return "Interface\\LFGFrame\\LFGIcon-" .. textureFilename .. ".blp"
            end
        end
    end

    return DUNGEON_ICON_PLACEHOLDER
end

function KeystonePolaris:GetDungeonDisplayName(dungeonKey)
    if not dungeonKey then return "Unknown Dungeon" end

    local mapId = self:GetDungeonIdByKey(dungeonKey)

    local name
    if mapId then
        name = C_ChallengeMode.GetMapUIInfo(mapId)
        if name then return name end
    end

    -- Try manual display name from data
    local dungeonData = self.GlobalDungeonLookup and self.GlobalDungeonLookup[dungeonKey]
    if dungeonData and dungeonData.displayName then
        return dungeonData.displayName
    end

    -- Fallback: Try to make the key look presentable
    name = dungeonKey:gsub("_", " ")
    name = name:gsub("(%l)(%u)", "%1 %2") -- Add space between lower and upper case
    name = name:gsub("^%l", string.upper) -- Capitalize first letter
    return name
end

-- ---------------------------------------------------------------------------
-- Season & Update Management
-- ---------------------------------------------------------------------------

function KeystonePolaris:IsCurrentSeasonDungeon(dungeonId)
    -- Get the current date
    local currentDate = date("%Y-%m-%d")

    local currentSeasonId = self:GetSeasonByDate(currentDate)

    if currentSeasonId then
        local seasonDungeonsTabName = currentSeasonId .. "_DUNGEONS"
        local seasonDungeons = self[seasonDungeonsTabName]

        if seasonDungeons then return seasonDungeons[dungeonId] or false end
    end

    return false
end

function KeystonePolaris:IsNextSeasonDungeon(dungeonId)
    -- Get the current date
    local currentDate = date("%Y-%m-%d")

    local _, _, _, nextSeasonId = self:GetSeasonByDate(currentDate)

    if nextSeasonId then
        local nextSeasonDungeonsTabName = nextSeasonId .. "_DUNGEONS"
        local nextSeasonDungeons = self[nextSeasonDungeonsTabName]

        if nextSeasonDungeons then
            return nextSeasonDungeons[dungeonId] or false
        end
    end

    return false
end

function KeystonePolaris:ResetAllDungeons()
    -- Reset all dungeons to their defaults
    -- Use global lookup for iteration if possible, or iterate expansions to keep order/structure logic
    for _, expansion in ipairs(expansions) do
        local dungeonIds = self[expansion.id .. "_DUNGEON_IDS"]
        if dungeonIds then
            for dungeonKey, _ in pairs(dungeonIds) do
                -- Get the appropriate defaults
                local defaults = self[expansion.id .. "_DEFAULTS"][dungeonKey]

                if defaults then
                    if not self.db.profile.advanced[dungeonKey] then
                        self.db.profile.advanced[dungeonKey] = {}
                    else
                        wipe(self.db.profile.advanced[dungeonKey])
                    end
                    for key, value in pairs(defaults) do
                        if type(value) == "table" then
                            self.db.profile.advanced[dungeonKey][key] = CloneTable(value)
                        else
                            self.db.profile.advanced[dungeonKey][key] = value
                        end
                    end
                end
            end
        end
    end

    -- Update the display
    self:UpdateDungeonData()
    if self.currentDungeonID and self.BuildSectionOrder then
        self:BuildSectionOrder(self.currentDungeonID)
    end
    LibStub("AceConfigRegistry-3.0"):NotifyChange("KeystonePolaris")
    if self.UpdatePercentageText then self:UpdatePercentageText() end
end

function KeystonePolaris:ResetCurrentSeasonDungeons(specificDungeons)
    -- Get the current date
    local currentDate = date("%Y-%m-%d")

    local currentSeasonId = self:GetSeasonByDate(currentDate)

    if currentSeasonId then
        local seasonDungeonsTabName = currentSeasonId .. "_DUNGEONS"
        local seasonDungeons = self[seasonDungeonsTabName]

        if seasonDungeons then
            -- Reset only the current season dungeons to their defaults
            for dungeonId, _ in pairs(seasonDungeons) do
                local dungeonKey = self:GetDungeonKeyById(dungeonId)
                if dungeonKey then
                    -- If specificDungeons is provided, only reset those dungeons
                    if not specificDungeons or specificDungeons[dungeonKey] then
                        -- Find the appropriate defaults for this dungeon
                        -- Using global lookup logic could simplify, but sticking to existing struct for safety
                        local defaults
                        for _, expansion in ipairs(expansions) do
                            if self[expansion.id .. "_DUNGEON_IDS"] and
                                self[expansion.id .. "_DUNGEON_IDS"][dungeonKey] then
                                defaults =
                                    self[expansion.id .. "_DEFAULTS"][dungeonKey]
                                break
                            end
                        end

                        if defaults then
                            if not self.db.profile.advanced[dungeonKey] then
                                self.db.profile.advanced[dungeonKey] = {}
                            else
                                wipe(self.db.profile.advanced[dungeonKey])
                            end
                            for key, value in pairs(defaults) do
                                if type(value) == "table" then
                                    self.db.profile.advanced[dungeonKey][key] = CloneTable(value)
                                else
                                    self.db.profile.advanced[dungeonKey][key] = value
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    -- Update the display
    self:UpdateDungeonData()
    if self.currentDungeonID and self.BuildSectionOrder then
        self:BuildSectionOrder(self.currentDungeonID)
    end
    LibStub("AceConfigRegistry-3.0"):NotifyChange("KeystonePolaris")
    if self.UpdatePercentageText then self:UpdatePercentageText() end
end

function KeystonePolaris:CheckForNewSeason()
    local currentDate = date("%Y-%m-%d")

    -- If this is first load (lastSeasonCheck is empty), just set the date and don't show popup
    if not self.db.profile.lastSeasonCheck or self.db.profile.lastSeasonCheck ==
        "" then
        self.db.profile.lastSeasonCheck = currentDate
        return
    end

    -- Find the current season start date
    local _, currentSeasonStart = self:GetSeasonByDate(currentDate)

    -- If last check was before the most recent season start, show popup
    if currentSeasonStart and self.db.profile.lastSeasonCheck <
        currentSeasonStart and not InCombatLockdown() then
        StaticPopupDialogs["KPL_NEW_SEASON"] = {
            text = "|cffffd100Keystone Polaris|r\n\n" ..
                L["NEW_SEASON_RESET_PROMPT"] .. "\n\n",
            button1 = YES,
            button2 = NO,
            OnAccept = function()
                -- Reset only current season dungeon values
                self:ResetCurrentSeasonDungeons()
                self.db.profile.lastSeasonCheck = currentDate
            end,
            OnCancel = function()
                self.db.profile.lastSeasonCheck = currentDate
            end,
            timeout = 0,
            whileDead = true,
            hideOnEscape = true,
            preferredIndex = 3,
            showAlert = true,
            title = "Keystone Polaris"
        }
        StaticPopup_Show("KPL_NEW_SEASON")
    end
end

function KeystonePolaris:GetChangedDungeonsText()
    local changedDungeonsText = ""

    -- Vérifier si la table CHANGED_ROUTES_DUNGEONS existe et n'est pas vide
    if self.CHANGED_ROUTES_DUNGEONS and next(self.CHANGED_ROUTES_DUNGEONS) then
        changedDungeonsText = L["CHANGED_ROUTES_DUNGEONS_LIST"] .. "\n"

        for dungeonKey, _ in pairs(self.CHANGED_ROUTES_DUNGEONS) do
            local displayName = self:GetDungeonDisplayName(dungeonKey) or
                                    dungeonKey
            changedDungeonsText = changedDungeonsText .. "- " .. displayName ..
                                      "\n"
        end
        changedDungeonsText = changedDungeonsText .. "\n"
    end

    return changedDungeonsText
end

-- ---------------------------------------------------------------------------
-- Dungeon State & Tracking
-- ---------------------------------------------------------------------------

function KeystonePolaris:HaveAllSeasonDungeonsChanged()
    -- Get the current date
    local currentDate = date("%Y-%m-%d")
    local currentSeasonId = self:GetSeasonByDate(currentDate)

    if not currentSeasonId then return false end

    local seasonDungeonsTabName = currentSeasonId .. "_DUNGEONS"
    local seasonDungeons = self[seasonDungeonsTabName]

    if not seasonDungeons then return false end
    if not self.CHANGED_ROUTES_DUNGEONS or not next(self.CHANGED_ROUTES_DUNGEONS) then return false end

    -- Check if every season dungeon is in CHANGED_ROUTES_DUNGEONS
    for dungeonId, _ in pairs(seasonDungeons) do
        local dungeonKey = self:GetDungeonKeyById(dungeonId)
        if dungeonKey and not self.CHANGED_ROUTES_DUNGEONS[dungeonKey] then
            return false
        end
    end

    return true
end

function KeystonePolaris:CheckForNewRoutes()
    local currentVersion = C_AddOns.GetAddOnMetadata("KeystonePolaris",
                                                     "Version")
    local lastVersionCheck = self.db.profile.general.lastVersionCheck or ""
    local lastSeasonCheck = self.db.profile.lastSeasonCheck or ""
    local lastRoutesUpdate = self.lastRoutesUpdate or ""

    -- Get the current date
    local currentDate = date("%Y-%m-%d")

    -- If it's the first version check but the user already had a previous version installed
    -- (indicated by lastSeasonCheck being populated), and we need to prompt for route reset
    if lastVersionCheck == "" and self.db.profile.general.advancedOptionsEnabled and
        currentDate > lastSeasonCheck and not InCombatLockdown() then
        local allChanged = self:HaveAllSeasonDungeonsChanged()

        if allChanged then
            -- Simplified popup: all season dungeons have changed routes
            StaticPopupDialogs["KPL_NEW_ROUTES"] = {
                text = "|cffffd100Keystone Polaris|r\n\n" ..
                    L["NEW_ROUTES_ALL_SEASON_PROMPT"],
                button1 = L["YES"],
                button2 = L["NO"],
                OnAccept = function()
                    self:ResetCurrentSeasonDungeons()
                    self.db.profile.general.lastVersionCheck = currentVersion
                end,
                OnCancel = function()
                    self.db.profile.general.lastVersionCheck = currentVersion
                end,
                timeout = 0,
                whileDead = true,
                hideOnEscape = true,
                preferredIndex = 3,
                showAlert = true,
                title = "Keystone Polaris"
            }
        else
            local changedDungeonsText = self:GetChangedDungeonsText()
            StaticPopupDialogs["KPL_NEW_ROUTES"] = {
                text = "|cffffd100Keystone Polaris|r\n\n" ..
                    L["NEW_ROUTES_RESET_PROMPT"] .. "\n\n" .. changedDungeonsText,
                button1 = L["RESET_ALL"],
                button2 = L["NO"],
                button3 = (self.CHANGED_ROUTES_DUNGEONS and
                    next(self.CHANGED_ROUTES_DUNGEONS)) and L["RESET_CHANGED_ONLY"] or
                    nil,
                OnAccept = function()
                    -- Reset all current season dungeon values
                    self:ResetCurrentSeasonDungeons()
                    self.db.profile.general.lastVersionCheck = currentVersion
                end,
                OnAlt = function()
                    -- Reset only dungeons with changed routes
                    self:ResetCurrentSeasonDungeons(self.CHANGED_ROUTES_DUNGEONS)
                    self.db.profile.general.lastVersionCheck = currentVersion
                end,
                OnCancel = function()
                    self.db.profile.general.lastVersionCheck = currentVersion
                end,
                timeout = 0,
                whileDead = true,
                hideOnEscape = true,
                preferredIndex = 3,
                showAlert = true,
                title = "Keystone Polaris"
            }
        end
        StaticPopup_Show("KPL_NEW_ROUTES")
        return
        -- If it's the first initialization of the addon (both checks are empty), just store the current version
    elseif lastVersionCheck == "" and lastSeasonCheck == "" then
        self.db.profile.general.lastVersionCheck = currentVersion
        return
    end

    -- If the version has changed and we need to prompt for route reset
    local prevWasBeta = (lastVersionCheck ~= "" and lastVersionCheck:lower():find("beta", 1, true) ~= nil)
    if lastVersionCheck ~= currentVersion and
        self.db.profile.general.advancedOptionsEnabled and
        not InCombatLockdown() and
        currentDate > lastSeasonCheck and
        (((lastRoutesUpdate > lastVersionCheck or lastVersionCheck == "") and currentVersion >= lastRoutesUpdate) or prevWasBeta) then

        local allChanged = self:HaveAllSeasonDungeonsChanged()

        if allChanged then
            -- Simplified popup: all season dungeons have changed routes
            StaticPopupDialogs["KPL_NEW_ROUTES"] = {
                text = "|cffffd100Keystone Polaris|r\n\n" ..
                    L["NEW_ROUTES_ALL_SEASON_PROMPT"],
                button1 = L["YES"],
                button2 = L["NO"],
                OnAccept = function()
                    self:ResetCurrentSeasonDungeons()
                    self.db.profile.general.lastVersionCheck = currentVersion
                end,
                OnCancel = function()
                    self.db.profile.general.lastVersionCheck = currentVersion
                end,
                timeout = 0,
                whileDead = true,
                hideOnEscape = true,
                preferredIndex = 3,
                showAlert = true,
                title = "Keystone Polaris"
            }
        else
            local changedDungeonsText = self:GetChangedDungeonsText()

            StaticPopupDialogs["KPL_NEW_ROUTES"] = {
                text = "|cffffd100Keystone Polaris|r\n\n" ..
                    L["NEW_ROUTES_RESET_PROMPT"] .. "\n\n" .. changedDungeonsText,
                button1 = L["RESET_ALL"],
                button2 = L["NO"],
                button3 = (self.CHANGED_ROUTES_DUNGEONS and
                    next(self.CHANGED_ROUTES_DUNGEONS)) and L["RESET_CHANGED_ONLY"] or
                    nil,
                OnAccept = function()
                    -- Reset all current season dungeon values
                    self:ResetCurrentSeasonDungeons()
                    self.db.profile.general.lastVersionCheck = currentVersion
                end,
                OnAlt = function()
                    -- Reset only dungeons with changed routes
                    self:ResetCurrentSeasonDungeons(self.CHANGED_ROUTES_DUNGEONS)
                    self.db.profile.general.lastVersionCheck = currentVersion
                end,
                OnCancel = function()
                    self.db.profile.general.lastVersionCheck = currentVersion
                end,
                timeout = 0,
                whileDead = true,
                hideOnEscape = true,
                preferredIndex = 3,
                showAlert = true,
                title = "Keystone Polaris"
            }
        end
        StaticPopup_Show("KPL_NEW_ROUTES")
    else
        -- Update the version check without prompting
        self.db.profile.general.lastVersionCheck = currentVersion
    end
end
