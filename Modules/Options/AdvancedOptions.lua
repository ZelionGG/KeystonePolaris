local AddOnName, KeystonePolaris = ...;

local pairs, select = pairs, select
local format = string.format
local strsplit = strsplit
local CALENDAR_WEEKDAY_NAMES = _G.CALENDAR_WEEKDAY_NAMES

local L = LibStub("AceLocale-3.0"):GetLocale(AddOnName, true)
local ACR = LibStub("AceConfigRegistry-3.0")

local ColumnRow = KeystonePolaris.ColumnRow
local CloneTable = KeystonePolaris.CloneTable
local FormatSeasonDate = KeystonePolaris.FormatSeasonDate
local InsertSortedDungeonOptions = KeystonePolaris.InsertSortedDungeonOptions

local expansions = KeystonePolaris.Expansions


function KeystonePolaris:GetAdvancedOptions()
    -- Helper function to get dungeon name with icon
    local function GetDungeonNameWithIcon(dungeonKey)
        local mapId = self:GetDungeonIdByKey(dungeonKey)

        local name
        if mapId then
            name = select(1, C_ChallengeMode.GetMapUIInfo(mapId))
        end

        -- Retrieve manual display name
        local manualName
        for _, expansion in ipairs(expansions) do
            local names = self[expansion.id .. "_DUNGEON_NAMES"]
            if names and names[dungeonKey] then
                manualName = names[dungeonKey]
                break
            end
        end

        local icon = self:GetDungeonIcon(dungeonKey)
        local displayName = name or manualName or dungeonKey or "Unknown"

        return '|T' .. icon .. ":20:20:0:0|t " .. displayName
    end

    -- Helper function to format dungeon text
    local function FormatDungeonText(dungeonKey, defaults)
        local text = ""
        if defaults then
            text = text .. "|cffffd700" .. GetDungeonNameWithIcon(dungeonKey) ..
                       "|r:\n"

            local bossNum = 1
            while defaults["Boss" .. self:GetBossNumberString(bossNum)] do
                local bossKey = "Boss" .. self:GetBossNumberString(bossNum)
                local informKey = bossKey .. "Inform"
                local bossName = self:GetBossName(dungeonKey, bossNum)

                text = text ..
                           string.format(
                               "  %s: |cff40E0D0%.2f%%|r - " ..
                                   L["SHOW_INFORM_GROUP_BUTTON"] .. ": %s\n",
                               bossName,
                               defaults[bossKey] or 0,
                               defaults[informKey] and '|cff00ff00' .. L["YES"] ..
                                   '|r' or '|cffff0000' .. L["NO"] .. '|r')
                bossNum = bossNum + 1
            end

            -- Show logical boss order if available
            local bossOrder = defaults.bossOrder
            if type(bossOrder) == "table" and next(bossOrder) ~= nil then
                -- Extra blank line between last boss percentage and order header
                text = text .. "\n"
                -- Collect boss names in logical section order
                local names = {}
                local numSections = #bossOrder
                for section = 1, numSections do
                    local idx = bossOrder[section]
                    if type(idx) == "number" then
                        local bossName = self:GetBossName(dungeonKey, idx)
                        table.insert(names, bossName)
                    end
                end

                if #names > 0 then
                    -- Orange title and numbered list (1) BossName, 2) BossName, ...)
                    local orderTitle = "|cffffa500" .. L["BOSS_ORDER"] .. "|r"
                    text = text .. "  " .. orderTitle .. ":\n"

                    for i, bossName in ipairs(names) do
                        text = text .. string.format("    %d) %s\n", i, bossName)
                    end

                    text = text .. "\n"
                else
                    text = text .. "\n"
                end
            else
                text = text .. "\n"
            end

            -- Show default milestones if available
            local milestones = defaults.milestones
            if type(milestones) == "table" and #milestones > 0 then
                local sorted = {}
                for _, milestone in ipairs(milestones) do
                    if type(milestone) == "table" then
                        sorted[#sorted + 1] = milestone
                    end
                end
                table.sort(sorted, function(left, right)
                    local leftPct = tonumber(left.thresholdPercent) or 0
                    local rightPct = tonumber(right.thresholdPercent) or 0
                    if leftPct ~= rightPct then
                        return leftPct < rightPct
                    end
                    local leftCreation = tonumber(left.creationOrder) or 0
                    local rightCreation = tonumber(right.creationOrder) or 0
                    if leftCreation ~= rightCreation then
                        return leftCreation < rightCreation
                    end
                    return (tonumber(left.id) or 0) < (tonumber(right.id) or 0)
                end)

                local milestonesTitle = "|cffffa500" .. L["MILESTONES"] .. "|r"
                text = text .. "  " .. milestonesTitle .. ":\n"

                for _, milestone in ipairs(sorted) do
                    local label = tostring(milestone.label or ""):match("^%s*(.-)%s*$") or ""
                    if label == "" then
                        if KeystonePolaris.GetMilestoneTriggerDisplayText then
                            label = KeystonePolaris.GetMilestoneTriggerDisplayText(milestone) or ""
                        else
                            label = tostring(milestone.matchText or "")
                        end
                        label = tostring(label):match("^%s*(.-)%s*$") or ""
                    end
                    if label == "" then
                        label = L["MILESTONE"]
                    end

                    local informText = milestone.inform and
                                           ('|cff00ff00' .. L["YES"] .. '|r') or
                                           ('|cffff0000' .. L["NO"] .. '|r')
                    local line = string.format(
                                     "    %s: |cff40E0D0%.2f%%|r - " ..
                                         L["SHOW_INFORM_GROUP_BUTTON"] .. ": %s",
                                     label, tonumber(milestone.thresholdPercent) or
                                         0, informText)

                    local triggerType = tostring(milestone.triggerType or "none"):lower()
                    if triggerType == "zone" or triggerType == "subzone" then
                        local triggerLabel = triggerType == "zone" and
                                                 L["MILESTONE_TRIGGER_ZONE"] or
                                                 L["MILESTONE_TRIGGER_SUBZONE"]
                        local matchText
                        if KeystonePolaris.GetMilestoneTriggerDisplayText then
                            matchText =
                                KeystonePolaris.GetMilestoneTriggerDisplayText(
                                    milestone) or ""
                        else
                            matchText = tostring(milestone.matchText or "")
                        end
                        matchText = tostring(matchText):match("^%s*(.-)%s*$") or
                                        ""
                        if matchText ~= "" then
                            line = line ..
                                       string.format(" - %s: %s", triggerLabel,
                                                     matchText)
                        else
                            line = line .. " - " .. triggerLabel
                        end
                    end

                    text = text .. line .. "\n"
                end

                text = text .. "\n"
            end
        end
        return text
    end

    -- Helper: days until a YYYY-MM-DD or YYYY-MM-DD HH:MM date (nil if invalid)
    local function GetDaysUntil(dateStr)
        if not dateStr or dateStr == "" then return nil end
        local y, m, d, h, min = dateStr:match("^(%d%d%d%d)%-(%d%d)%-(%d%d)%s+(%d%d):(%d%d)$")
        local hasTime = y ~= nil
        if not hasTime then
            y, m, d = dateStr:match("^(%d%d%d%d)%-(%d%d)%-(%d%d)$")
        end
        local year, month, day = tonumber(y), tonumber(m), tonumber(d)
        if not year or not month or not day then return nil end

        local target
        local current
        if hasTime then
            local hour, minute = tonumber(h), tonumber(min)
            if not hour or not minute then return nil end
            target = time({year = year, month = month, day = day, hour = hour, min = minute})
            current = time()
            if target < current then
                return -1
            end
        else
            local currentDate = date("%Y-%m-%d")
            local cYear, cMonth, cDay = strsplit("-", currentDate)
            cYear, cMonth, cDay = tonumber(cYear), tonumber(cMonth), tonumber(cDay)
            if not cYear or not cMonth or not cDay then return nil end
            target = time({year = year, month = month, day = day, hour = 12})
            current = time({year = cYear, month = cMonth, day = cDay, hour = 12})
        end

        return math.floor((target - current) / 86400)
    end

    local function GetSeasonCountdownText(daysUntil, prefixKey, withIcon, targetDate)
        if not daysUntil or daysUntil < 0 then return nil end
        local iconPrefix = withIcon and
                               "|TInterface\\OptionsFrame\\UI-OptionsFrame-NewFeatureIcon:16:16:0:0|t " or
                               ""
        if daysUntil <= 7 then
            local weekdaySuffix = ""
            if targetDate then
                local dateOnly = targetDate:match("^(%d%d%d%d%-%d%d%-%d%d)") or targetDate
                local year, month, day = strsplit("-", dateOnly)
                year, month, day = tonumber(year), tonumber(month), tonumber(day)
                if year and month and day then
                    local target = time({year = year, month = month, day = day, hour = 12})
                    local wday = date("*t", target).wday
                    local weekdayName = CALENDAR_WEEKDAY_NAMES and
                                            CALENDAR_WEEKDAY_NAMES[wday]
                    if weekdayName then
                        local weekdayFormat = L["WEEKDAY_NEXT_FORMAT"]
                        weekdaySuffix = " " .. weekdayFormat:format(weekdayName)
                    end
                end
            end
            if daysUntil == 1 then
                return iconPrefix .. L[prefixKey .. "_TOMORROW"]
            end
            local dayText = L[prefixKey .. "_DAYS"]:format(daysUntil)
            return iconPrefix .. dayText .. weekdaySuffix
        end
        if daysUntil <= 14 then
            local weeks = math.ceil(daysUntil / 7)
            local weekKey = weeks == 1 and "_WEEK" or "_WEEKS"
            local weekText = L[prefixKey .. weekKey]
            if weeks ~= 1 then
                weekText = weekText:format(weeks)
            end
            return iconPrefix .. weekText
        end
        if daysUntil <= 30 then
            return iconPrefix .. L[prefixKey .. "_ONE_MONTH"]
        end
        return nil
    end

    -- Create shared dungeon options
    local sharedDungeonOptions = {}
    for _, expansion in ipairs(expansions) do
        local dungeonIds = self[expansion.id .. "_DUNGEON_IDS"]
        if dungeonIds then
            for dungeonKey, _ in pairs(dungeonIds) do
                sharedDungeonOptions[dungeonKey] =
                    self:CreateDungeonOptions(dungeonKey, 0)
            end
        end
    end

    -- Generic builder for section args (used for seasons and expansions)
    local function CreateGenericSectionArgs(sectionLabel, dungeonKeys, dungeonFilter, getDefaultsFn, headerTitle, extraDisclaimerText)
        local args = {
            title = {
                order = 0,
                type = "description",
                fontSize = "large",
                name = (headerTitle or ("|cffeda55f" .. sectionLabel .. "|r")) .. "\n"
            },
            seasonAlert = extraDisclaimerText and {
                order = 0.1,
                type = "description",
                fontSize = "medium",
                name = extraDisclaimerText or "",
            } or nil,
            separatorTitle = {
                order = 0.2,
                type = "header",
                name = "",
            },
            disclaimer = {
                order = 0.5,
                type = "description",
                fontSize = "medium",
                name = L["ROUTES_DISCLAIMER"],
            },
            separator = {order = 1, type = "header", name = ""},
            export = {
                order = 1.25,
                type = "execute",
                name = L["EXPORT_SECTION"],
                desc = (L["EXPORT_SECTION_DESC"]):format(sectionLabel),
                func = function()
                    local addon = KeystonePolaris
                    local sectionData = {}
                    for _, dungeonKey in ipairs(dungeonKeys) do
                        if addon.db and addon.db.profile and addon.db.profile.advanced and addon.db.profile.advanced[dungeonKey] then
                            sectionData[dungeonKey] = addon.db.profile.advanced[dungeonKey]
                        end
                    end
                    addon:ExportDungeonSettings(sectionData, "section", sectionLabel)
                end
            },
            import = {
                order = 1.5,
                type = "execute",
                name = L["IMPORT_SECTION"],
                desc = (L["IMPORT_SECTION_DESC"]):format(sectionLabel),
                func = function()
                    KeystonePolaris:ShowImportDialog(sectionLabel, dungeonFilter)
                end
            },
            separatorDefaultPercentages = {
                order = 2,
                type = "header",
                name = L["DEFAULT_PERCENTAGES"],
            },
            defaultPercentages = {
                order = 2.5,
                type = "description",
                fontSize = "medium",
                name = L["DEFAULT_PERCENTAGES_DESC"],
            },
            separatorDefaultPercentagesText = {
                order = 2.8,
                type = "header",
                name = "",
            },
            defaultPercentagesText = {
                order = 3,
                type = "description",
                fontSize = "medium",
                name = function()
                    local text = ""
                    for _, dungeonKey in ipairs(dungeonKeys) do
                        local defaults = getDefaultsFn and getDefaultsFn(dungeonKey) or nil
                        text = text .. FormatDungeonText(dungeonKey, defaults)
                    end
                    return text
                end
            }
        }

        -- Add per-dungeon options (alphabetical by localized name)
        -- Start at order 4 to come after the defaults header/description/text
        InsertSortedDungeonOptions(self, dungeonKeys, sharedDungeonOptions, args, 4)
        return args
    end

    -- Create current season options
    local currentSeasonDungeons = {}
    local currentSeasonTitle
    local currentSeasonListTitle
    local currentSeasonAlertText

    -- Get the current date
    local currentDate = date("%Y-%m-%d")

    -- Resolve the current season based on start/end dates
    local currentSeasonId, currentSeasonStart, currentSeasonEnd =
        self:GetSeasonByDate(currentDate)

    if currentSeasonId then
        local seasonDungeonsTabName = currentSeasonId .. "_DUNGEONS"
        local seasonDungeons = self[seasonDungeonsTabName]

        if seasonDungeons then
            for _, expansion in ipairs(expansions) do
                local dungeonIds = self[expansion.id .. "_DUNGEON_IDS"]
                if dungeonIds then
                    for dungeonKey, dungeonId in pairs(dungeonIds) do
                        if seasonDungeons[dungeonId] then
                            table.insert(currentSeasonDungeons,
                                         {key = dungeonKey, id = dungeonId})
                        end
                    end
                end
            end
        end
    end

    -- Sort dungeons alphabetically by their localized names
    table.sort(currentSeasonDungeons, function(a, b)
        local mapIdA = a.id or self:GetDungeonIdByKey(a.key)
        local mapIdB = b.id or self:GetDungeonIdByKey(b.key)

        local nameA
        if mapIdA then nameA = select(1, C_ChallengeMode.GetMapUIInfo(mapIdA)) end
        nameA = nameA or a.key

        local nameB
        if mapIdB then nameB = select(1, C_ChallengeMode.GetMapUIInfo(mapIdB)) end
        nameB = nameB or b.key

        return nameA < nameB
    end)

    -- Create current season dungeon args (using generic builder)
    local dungeonArgs
    do
        local keys = {}
        local filter = {}
        for _, d in ipairs(currentSeasonDungeons) do
            table.insert(keys, d.key)
            filter[d.key] = true
        end

        local function getDefaultsFn(dungeonKey)
            for _, expansion in ipairs(expansions) do
                local ids = self[expansion.id .. "_DUNGEON_IDS"]
                if ids and ids[dungeonKey] then
                    local defaults = self[expansion.id .. "_DEFAULTS"]
                    return defaults and defaults[dungeonKey] or nil
                end
            end
            return nil
        end

        local daysUntilEnd = currentSeasonEnd and GetDaysUntil(currentSeasonEnd)
        local countdownText = GetSeasonCountdownText(daysUntilEnd, "SEASON_ENDS_IN", true, currentSeasonEnd)
        local hasEndSoon = countdownText ~= nil
        currentSeasonTitle = "|cff40E0D0" .. L["CURRENT_SEASON"] .. "|r - |cffbbbbbb" .. FormatSeasonDate(currentSeasonStart)
        if currentSeasonEnd and currentSeasonEnd ~= "" then
            currentSeasonTitle = currentSeasonTitle .. " -> " .. FormatSeasonDate(currentSeasonEnd)
        end
        currentSeasonTitle = currentSeasonTitle .. "|r"
        currentSeasonListTitle = currentSeasonTitle
        if hasEndSoon then
            currentSeasonListTitle = "|TInterface\\OptionsFrame\\UI-OptionsFrame-NewFeatureIcon:16:16:0:0|t " ..
                currentSeasonTitle
            currentSeasonAlertText = countdownText
        end
        dungeonArgs = CreateGenericSectionArgs(L["CURRENT_SEASON"], keys, filter, getDefaultsFn, currentSeasonTitle, currentSeasonAlertText)
    end

    -- Create next season dungeon args
    local nextSeasonDungeons = {}
    local nextSeasonTitle
    local nextSeasonListTitle

    -- Find the next season (first season that starts after current date)
    local _, _, _, nextSeasonId, nextSeasonDate = self:GetSeasonByDate(currentDate)

    if nextSeasonId then
        local nextSeasonDungeonsTabName = nextSeasonId .. "_DUNGEONS"
        local nextSeasonDungeonsTable = self[nextSeasonDungeonsTabName]

        if nextSeasonDungeonsTable then
            for _, expansion in ipairs(expansions) do
                local dungeonIds = self[expansion.id .. "_DUNGEON_IDS"]
                if dungeonIds then
                    for dungeonKey, dungeonId in pairs(dungeonIds) do
                        if nextSeasonDungeonsTable[dungeonId] then
                            table.insert(nextSeasonDungeons,
                                         {key = dungeonKey, id = dungeonId})
                        end
                    end
                end
            end
        end
    end

    -- Sort dungeons alphabetically by their localized names
    table.sort(nextSeasonDungeons, function(a, b)
        local mapIdA = a.id or self:GetDungeonIdByKey(a.key)
        local mapIdB = b.id or self:GetDungeonIdByKey(b.key)

        local nameA
        if mapIdA then nameA = select(1, C_ChallengeMode.GetMapUIInfo(mapIdA)) end
        nameA = nameA or a.key

        local nameB
        if mapIdB then nameB = select(1, C_ChallengeMode.GetMapUIInfo(mapIdB)) end
        nameB = nameB or b.key

        return nameA < nameB
    end)

    -- Create next season dungeon args (using generic builder)
    local nextSeasonDungeonArgs
    do
        local keys = {}
        local filter = {}
        for _, d in ipairs(nextSeasonDungeons) do
            table.insert(keys, d.key)
            filter[d.key] = true
        end

        local function getDefaultsFn(dungeonKey)
            for _, expansion in ipairs(expansions) do
                local ids = self[expansion.id .. "_DUNGEON_IDS"]
                if ids and ids[dungeonKey] then
                    local defaults = self[expansion.id .. "_DEFAULTS"]
                    return defaults and defaults[dungeonKey] or nil
                end
            end
            return nil
        end

        nextSeasonTitle = "|cffff5733" .. L["NEXT_SEASON"] .. "|r - |cffbbbbbb" .. FormatSeasonDate(nextSeasonDate)
        local nextSeasonAlertText
        local nextSeasonEnd
        if nextSeasonId then
            local nextSeasonTable = self[nextSeasonId .. "_DUNGEONS"]
            if nextSeasonTable and nextSeasonTable.end_date then
                local portal = C_CVar.GetCVar("portal")
                if type(nextSeasonTable.end_date) == "table" then
                    nextSeasonEnd = nextSeasonTable.end_date[portal] or
                                    nextSeasonTable.end_date.default or
                                    nextSeasonTable.end_date.US or
                                    nextSeasonTable.end_date.EU
                else
                    nextSeasonEnd = nextSeasonTable.end_date
                end
            end
        end
        if nextSeasonEnd and nextSeasonEnd ~= "" then
            nextSeasonTitle = nextSeasonTitle .. " -> " .. FormatSeasonDate(nextSeasonEnd)
        end
        nextSeasonTitle = nextSeasonTitle .. "|r"
        local nextSeasonDaysUntilStart = nextSeasonDate and GetDaysUntil(nextSeasonDate)
        nextSeasonAlertText = GetSeasonCountdownText(nextSeasonDaysUntilStart, "SEASON_STARTS_IN", true, nextSeasonDate)
        nextSeasonListTitle = nextSeasonTitle
        if nextSeasonAlertText then
            nextSeasonListTitle = "|TInterface\\OptionsFrame\\UI-OptionsFrame-NewFeatureIcon:16:16:0:0|t " ..
                nextSeasonTitle
        end
        nextSeasonDungeonArgs = CreateGenericSectionArgs(L["NEXT_SEASON"], keys, filter, getDefaultsFn, nextSeasonTitle, nextSeasonAlertText)
    end

    -- Create expansion sections
    local args = {
        disclaimer = {
            order = 0,
            type = "description",
            fontSize = "medium",
            name = L["ROUTES_DISCLAIMER"],
        },
        separator = {
            order = 1,
            type = "header",
            name = "",
        },
        resetAll = {
            order = 2,
            type = "execute",
            name = L["RESET_ALL_DUNGEONS"],
            desc = L["RESET_ALL_DUNGEONS_DESC"],
            confirm = true,
            confirmText = L["RESET_ALL_DUNGEONS_CONFIRM"],
            func = function()
                -- Reset all dungeons to their defaults
                self:ResetAllDungeons()
            end
        },
        exportAllDungeons = {
            order = 3,
            type = "execute",
            name = L["EXPORT_ALL_DUNGEONS"],
            desc = L["EXPORT_ALL_DUNGEONS_DESC"],
            func = function()
                local addon = KeystonePolaris

                -- Collect all dungeon data
                local allDungeonData = {}
                for _, expansion in ipairs(expansions) do
                    if addon.db.profile.advanced then
                        for dungeonKey, _ in pairs(addon[expansion.id .. "_DUNGEON_IDS"] or {}) do
                            if addon.db.profile.advanced[dungeonKey] then
                                allDungeonData[dungeonKey] = addon.db.profile.advanced[dungeonKey]
                            end
                        end
                    end
                end
                addon:ExportDungeonSettings(allDungeonData, "all_dungeons")
            end
        },
        importAllDungeons = {
            order = 3.5,
            type = "execute",
            name = L["IMPORT_ALL_DUNGEONS"],
            desc = L["IMPORT_ALL_DUNGEONS_DESC"],
            func = function()
                KeystonePolaris:ShowImportDialog(nil)
            end
        }
    }

    -- Only add current season section if a current season exists and has dungeons
    if currentSeasonId and #currentSeasonDungeons > 0 then
        args.dungeons = {
            name = currentSeasonListTitle,
            type = "group",
            childGroups = "tree",
            order = 5,
            args = dungeonArgs
        }
    end

    -- Only add next season section if there are next season dungeons
    if nextSeasonId and #nextSeasonDungeons > 0 then
        args.nextseason = {
            name = nextSeasonListTitle,
            type = "group",
            childGroups = "tree",
            order = 4,
            args = nextSeasonDungeonArgs
        }
    end

    -- Helper to add days to a YYYY-MM-DD string
    local function AddDays(dateStr, days)
        if not dateStr or days == 0 then return dateStr end
        local year, month, day = strsplit("-", dateStr)
        year, month, day = tonumber(year), tonumber(month), tonumber(day)
        if not year or not month or not day then return dateStr end

        -- Convert to timestamp, add seconds, convert back
        -- Note: os.time takes a table. Basic implementation for simple date math.
        local time = time({year=year, month=month, day=day, hour=12}) -- noon to avoid DST issues
        time = time + (days * 86400)
        return date("%Y-%m-%d", time)
    end

    -- Helper to create a remix section
    local function HandleRemixSection(_, data, _)
        -- Collect dungeon keys
        local remixDungeons = {}
        for id, enabled in pairs(data) do
            if id ~= "expansion" and id ~= "start_date" and id ~= "end_date" and enabled then
                    local dungeonKey = self:GetDungeonKeyById(id)
                    if dungeonKey then
                        table.insert(remixDungeons, {key = dungeonKey, id = id})
                    end
            end
        end

        -- Sort dungeons alphabetically by their localized names
        table.sort(remixDungeons, function(a, b)
            local mapIdA = a.id or self:GetDungeonIdByKey(a.key)
            local mapIdB = b.id or self:GetDungeonIdByKey(b.key)

            local nameA
            if mapIdA then nameA = select(1, C_ChallengeMode.GetMapUIInfo(mapIdA)) end
            nameA = nameA or a.key

            local nameB
            if mapIdB then nameB = select(1, C_ChallengeMode.GetMapUIInfo(mapIdB)) end
            nameB = nameB or b.key

            return nameA < nameB
        end)

        local keys = {}
        for _, d in ipairs(remixDungeons) do
                table.insert(keys, d.key)
        end

        -- Handle dates with region offset
        local eDate = data.end_date

        -- Add +1 day for non-US regions if dates are present
        local portal = C_CVar.GetCVar("portal")
        local eDateFromTable = false
        if type(eDate) == "table" then
            eDate = eDate[portal] or eDate.default or eDate.US or eDate.EU
            eDateFromTable = true
        end
        if portal ~= "US" then
            if eDate and eDate ~= "" and not eDateFromTable then
                eDate = AddDays(eDate, 1)
            end
        end

        local daysUntilEnd
        if eDate and eDate ~= "" then
            daysUntilEnd = GetDaysUntil(eDate)
            if daysUntilEnd and daysUntilEnd < 0 then
                return
            end
        end

        -- Add dates to title if available
    end

    -- Create remix season sections
    for key, data in pairs(self) do
        if type(key) == "string" and key:match("_DUNGEONS$") and type(data) == "table" and rawget(data, "expansion") then
            HandleRemixSection(key, data, args)
        end
    end

    -- Create expansion sections
    for _, expansion in ipairs(expansions) do
        local sectionKey = expansion.id:lower()
        local dungeonIds = self[expansion.id .. "_DUNGEON_IDS"]
        local defaults = self[expansion.id .. "_DEFAULTS"]
        local keys = {}
        local filter = {}
        if dungeonIds then
            for dungeonKey, _ in pairs(dungeonIds) do
                table.insert(keys, dungeonKey)
                filter[dungeonKey] = true
            end
        end

        local function getDefaultsFn(dungeonKey)
            return defaults and defaults[dungeonKey] or nil
        end

        local expansionTitle = "|cffffffff" .. L[expansion.name] .. "|r"
        args[sectionKey] = {
            name = expansionTitle,
            type = "group",
            childGroups = "tree",
            order = expansion.order + 4, -- Shift expansion orders to after next season
            args = CreateGenericSectionArgs(L[expansion.name], keys, filter, getDefaultsFn, expansionTitle)
        }
    end
    return {
        name = L["ADVANCED_SETTINGS"],
        type = "group",
        childGroups = "tree",
        order = 5,
        args = args
    }
end


function KeystonePolaris:RefreshAdvancedOptionsTree(dungeonKey)
    local rebuilder = self._dungeonMilestoneRebuilders
        and self._dungeonMilestoneRebuilders[dungeonKey]
    if rebuilder then rebuilder() end

    ACR:NotifyChange(AddOnName)
end

function KeystonePolaris:CreateDungeonOptions(dungeonKey, order)
    local numBosses = #self.DUNGEONS[self:GetDungeonIdByKey(dungeonKey)]

    -- Ensure the advanced settings table exists for this dungeon
    if not self.db.profile.advanced[dungeonKey] then
        self.db.profile.advanced[dungeonKey] = {}

        -- Initialize with defaults if needed
        for _, expansion in ipairs(expansions) do
            if self[expansion.id .. "_DUNGEON_IDS"] and
                self[expansion.id .. "_DUNGEON_IDS"][dungeonKey] then
                local defaults = self[expansion.id .. "_DEFAULTS"][dungeonKey]
                if defaults then
                    for key, value in pairs(defaults) do
                        if type(value) == "table" then
                            self.db.profile.advanced[dungeonKey][key] = CloneTable(value)
                        else
                            self.db.profile.advanced[dungeonKey][key] = value
                        end
                    end
                end
                break
            end
        end
    end

    local function GetMilestoneMatchDisplayText(milestone)
        if KeystonePolaris.GetMilestoneTriggerDisplayText then
            return KeystonePolaris.GetMilestoneTriggerDisplayText(milestone)
        end
        return milestone and milestone.matchText or ""
    end

    local function EnsureMilestonesTable()
        if self.MergeDungeonMilestoneDefaults then
            self:MergeDungeonMilestoneDefaults(dungeonKey)
        end

        local advanced = self.db.profile.advanced[dungeonKey]
        if type(advanced.milestones) ~= "table" then
            advanced.milestones = {}
        end

        for index, milestone in ipairs(advanced.milestones) do
            if type(milestone) ~= "table" then
                milestone = {}
                advanced.milestones[index] = milestone
            end
            if milestone.id == nil then
                milestone.id = index
            end
            if milestone.creationOrder == nil then
                milestone.creationOrder = index
            end
            milestone.thresholdPercent = tonumber(milestone.thresholdPercent) or 0
            local triggerType = tostring(milestone.triggerType or "none"):lower()
            if triggerType ~= "none" and triggerType ~= "zone" and triggerType ~= "subzone" then
                triggerType = "none"
            end
            milestone.triggerType = triggerType
            milestone.matchAreaID = tonumber(milestone.matchAreaID)
            milestone.matchMapID = tonumber(milestone.matchMapID)
            milestone.matchText = tostring(milestone.matchText or "")
            milestone.label = tostring(milestone.label or "")
            milestone.informSuffix = tostring(milestone.informSuffix or "")
            milestone.inform = milestone.inform == true
        end

        return advanced.milestones
    end

    local function RefreshMilestoneRuntime()
        self:UpdateDungeonData()
        local dungeonId = self:GetDungeonIdByKey(dungeonKey)
        if dungeonId and self.ResetMilestoneRuntimeState then
            self:ResetMilestoneRuntimeState(dungeonId)
        end
        if dungeonId and self.BuildSectionOrder then
            self:BuildSectionOrder(dungeonId)
        end
        if self.UpdatePercentageText then self:UpdatePercentageText() end
        local activeDungeonId = C_ChallengeMode.GetActiveChallengeMapID()
        local activeKey = activeDungeonId and self:GetDungeonKeyById(activeDungeonId)
        if activeKey == dungeonKey and self.RefreshProgressBar then
            self:RefreshProgressBar()
        end
    end

    local function RefreshDungeonRouting()
        RefreshMilestoneRuntime()
        ACR:NotifyChange(AddOnName)
    end

    local function RefreshDungeonRoutingOptionsView()
        if self.RefreshAdvancedOptionsTree then
            self:RefreshAdvancedOptionsTree(dungeonKey)
        end
    end

    local function NextMilestoneId(milestones)
        local maxId = 0
        for _, milestone in ipairs(milestones) do
            local id = tonumber(milestone.id)
            if id and id > maxId then
                maxId = id
            end
        end
        return maxId + 1
    end

    local function NextMilestoneCreationOrder(milestones)
        local maxOrder = 0
        for _, milestone in ipairs(milestones) do
            local creationOrder = tonumber(milestone.creationOrder)
            if creationOrder and creationOrder > maxOrder then
                maxOrder = creationOrder
            end
        end
        return maxOrder + 1
    end

    local options = {
        name = function()
            local mapId = self:GetDungeonIdByKey(dungeonKey)

            local name
            if mapId then
                name = select(1, C_ChallengeMode.GetMapUIInfo(mapId))
            end

            if not name then
                for _, expansion in ipairs(expansions) do
                    local names = self[expansion.id .. "_DUNGEON_NAMES"]
                    if names and names[dungeonKey] then
                        name = names[dungeonKey]
                        break
                    end
                end
            end
            name = name or dungeonKey or "Unknown"

            return '|T' .. self:GetDungeonIcon(dungeonKey) .. ":16:16:0:0|t " .. (name)
        end,
        type = "group",
        order = order,
        args = {
            dungeonHeader = {
                order = 0,
                type = "description",
                fontSize = "large",
                name = function()
                    local mapId = self:GetDungeonIdByKey(dungeonKey)

                    local name
                    if mapId then
                        name = select(1, C_ChallengeMode.GetMapUIInfo(mapId))
                    end

                    if not name then
                         for _, expansion in ipairs(expansions) do
                             local names = self[expansion.id .. "_DUNGEON_NAMES"]
                             if names and names[dungeonKey] then
                                 name = names[dungeonKey]
                                 break
                             end
                         end
                    end
                    name = name or dungeonKey or "Unknown"

                    return "|T" .. self:GetDungeonIcon(dungeonKey) .. ":20:20:0:0|t |cff40E0D0" ..
                               (name) .. "|r"
                end
            },
            dungeonSecondHeader = {type = "header", name = "", order = 1},
            reset = {
                order = 2,
                type = "execute",
                name = L["RESET_DUNGEON"],
                desc = L["RESET_DUNGEON_DESC"],
                func = function()
                    local dungeonId = self:GetDungeonIdByKey(dungeonKey)
                    if dungeonId and self.DUNGEONS[dungeonId] then
                        -- Reset all boss percentages and inform group settings for this dungeon to defaults
                        if not self.db.profile.advanced[dungeonKey] then
                            self.db.profile.advanced[dungeonKey] = {}
                        else
                            wipe(self.db.profile.advanced[dungeonKey])
                        end

                        -- Get the appropriate defaults
                        local defaults
                        for _, expansion in ipairs(expansions) do
                            if self[expansion.id .. "_DUNGEON_IDS"][dungeonKey] then
                                defaults =
                                    self[expansion.id .. "_DEFAULTS"][dungeonKey]
                                break
                            end
                        end

                        if defaults then
                            for key, value in pairs(defaults) do
                                if type(value) == "table" then
                                    self.db.profile.advanced[dungeonKey][key] = CloneTable(value)
                                else
                                    self.db.profile.advanced[dungeonKey][key] = value
                                end
                            end
                        end

                        -- Update the display
                        self:UpdateDungeonData()
                        if dungeonId and self.ResetMilestoneRuntimeState then
                            self:ResetMilestoneRuntimeState(dungeonId)
                        end
                        if self.currentDungeonID and self.BuildSectionOrder then
                            self:BuildSectionOrder(self.currentDungeonID)
                        end
                        if self.RefreshAdvancedOptionsTree then
                            self:RefreshAdvancedOptionsTree(dungeonKey)
                        else
                            ACR:NotifyChange(AddOnName)
                        end
                        if self.UpdatePercentageText then self:UpdatePercentageText() end
                    end
                end,
                confirm = true,
                confirmText = L["RESET_DUNGEON_CONFIRM"]
            },
            export = {
                order = 3,
                type = "execute",
                name = L["EXPORT_DUNGEON"],
                desc = L["EXPORT_DUNGEON_DESC"],
                func = function()
                    local addon = KeystonePolaris
                    local dungeonId = addon:GetDungeonIdByKey(dungeonKey)
                    if dungeonId and addon.DUNGEONS[dungeonId] and
                        addon.db.profile.advanced[dungeonKey] then
                        addon:ExportDungeonSettings(
                            addon.db.profile.advanced[dungeonKey],
                            "dungeon",
                            dungeonKey
                        )
                    end
                end
            },
            import = {
                order = 3.5,
                type = "execute",
                name = L["IMPORT_DUNGEON"],
                desc = L["IMPORT_DUNGEON_DESC"],
                func = function()
                    local addon = KeystonePolaris

                    -- Create filter for this specific dungeon
                    local dungeonFilter = {}
                    dungeonFilter[dungeonKey] = true

                    local dungeonLabel = addon:GetDungeonDisplayName(dungeonKey) or dungeonKey
                    addon:ShowImportDialog(dungeonLabel, dungeonFilter)
                end
            },
            header = {order = 4, type = "header", name = L["TANK_GROUP_HEADER"]}
        }
    }

    -- Build choices for boss order selector (indexed by boss index in DUNGEONS)
    local bossChoices = {}
    for i = 1, numBosses do
        local bossName = self:GetBossName(dungeonKey, i)
        bossChoices[i] = bossName
    end

    -- Group to control logical section order (bossOrder)
    options.args.bossOrder = {
        type = "group",
        name = L["BOSS_ORDER"],
        inline = true,
        order = 4.5,
        args = {}
    }

    for section = 1, numBosses do
        options.args.bossOrder.args["section" .. section] = {
            type = "select",
            name = format(L["BOSS"] .. " %d", section),
            order = section,
            values = bossChoices,
            get = function()
                local adv = self.db.profile.advanced[dungeonKey]
                local orderTable = adv and adv.bossOrder
                local idx = orderTable and orderTable[section]
                if type(idx) ~= "number" or idx < 1 or idx > numBosses then
                    return section
                end
                return idx
            end,
            set = function(_, value)
                if not self.db.profile.advanced[dungeonKey].bossOrder then
                    self.db.profile.advanced[dungeonKey].bossOrder = {}
                end
                self.db.profile.advanced[dungeonKey].bossOrder[section] = value
                local dungeonId = self:GetDungeonIdByKey(dungeonKey)
                if dungeonId then
                    if self.BuildSectionOrder then
                        self:BuildSectionOrder(dungeonId)
                    end
                    self:UpdateDungeonData()
                    if self.UpdatePercentageText then self:UpdatePercentageText() end
                end
            end
        }
    end

    for i = 1, numBosses do
        local bossNumStr = self:GetBossNumberString(i)
        local bossName = self:GetBossName(dungeonKey, i)

        -- Create a group for each boss line
        options.args["boss" .. i] = {
            type = "group",
            name = bossName,
            inline = true,
            order = i + 4, -- Start boss orders at 5 (after header)
            args = {
                percent = {
                    name = L["PERCENTAGE"],
                    type = "range",
                    min = 0,
                    max = 100,
                    step = 0.01,
                    order = 1,
                    width = 1,
                    get = function()
                        return self.db.profile.advanced[dungeonKey]["Boss" ..
                                   bossNumStr]
                    end,
                    set = function(_, value)
                        self.db.profile.advanced[dungeonKey]["Boss" ..
                            bossNumStr] = value
                        self:UpdateDungeonData()
                    end
                },
                inform = {
                    name = L["SHOW_INFORM_GROUP_BUTTON"],
                    desc = L["SHOW_INFORM_GROUP_BUTTON_DESC"],
                    type = "toggle",
                    order = 2,
                    width = 1,
                    get = function()
                        return self.db.profile.advanced[dungeonKey]["Boss" ..
                                   bossNumStr .. "Inform"]
                    end,
                    set = function(_, value)
                        self.db.profile.advanced[dungeonKey]["Boss" ..
                            bossNumStr .. "Inform"] = value
                        self:UpdateDungeonData()
                    end
                }
            }
        }
    end

    local RebuildMilestoneOptionGroups

    options.args.milestones = {
        type = "group",
        name = L["MILESTONES"],
        inline = true,
        order = numBosses + 5,
        args = {
            description = {
                type = "description",
                order = 0,
                fontSize = "medium",
                name = L["MILESTONES_DESC"]
            },
            addMilestone = {
                type = "execute",
                order = 1,
                name = L["MILESTONE_ADD"],
                func = function()
                    local advanced = self.db.profile.advanced[dungeonKey]
                    local milestones = EnsureMilestonesTable()
                    if advanced then
                        advanced.milestonesUserEdited = true
                    end
                    milestones[#milestones + 1] = {
                        id = NextMilestoneId(milestones),
                        label = "",
                        thresholdPercent = 0,
                        triggerType = "none",
                        matchAreaID = nil,
                        matchMapID = nil,
                        matchText = "",
                        informSuffix = "",
                        inform = false,
                        creationOrder = NextMilestoneCreationOrder(milestones),
                    }
                    if RebuildMilestoneOptionGroups then
                        RebuildMilestoneOptionGroups()
                    end
                    RefreshDungeonRouting()
                    RefreshDungeonRoutingOptionsView()
                end
            }
        }
    }

    local function AddMilestoneOptions(milestoneIndex)
        local milestones = EnsureMilestonesTable()
        local milestone = milestones[milestoneIndex]
        if not milestone then return end

        local optionKey = "milestone" .. milestoneIndex
        options.args.milestones.args[optionKey] = {
            type = "group",
            inline = true,
            order = milestoneIndex + 10,
            name = function()
                local currentMilestones = EnsureMilestonesTable()
                local current = currentMilestones[milestoneIndex]
                if not current then
                    return string.format("%s %d", L["MILESTONE"], milestoneIndex)
                end
                local label = tostring(current.label or ""):match("^%s*(.-)%s*$") or ""
                if label ~= "" then
                    return label
                end
                local matchText = tostring(GetMilestoneMatchDisplayText(current) or ""):match("^%s*(.-)%s*$") or ""
                if matchText ~= "" then
                    return matchText
                end
                return string.format("%s %d", L["MILESTONE"], milestoneIndex)
            end,
            args = {
                label = {
                    type = "input",
                    order = 1,
                    width = 1.2,
                    name = L["MILESTONE_LABEL"],
                    get = function()
                        local current = EnsureMilestonesTable()[milestoneIndex]
                        return current and current.label or ""
                    end,
                    set = function(_, value)
                        local current = EnsureMilestonesTable()[milestoneIndex]
                        if not current then return end
                        current.label = tostring(value or "")
                        RefreshMilestoneRuntime()
                    end
                },
                threshold = {
                    type = "range",
                    min = 0,
                    max = 100,
                    step = 0.01,
                    order = 2,
                    width = 0.8,
                    name = L["MILESTONE_THRESHOLD"],
                    get = function()
                        local current = EnsureMilestonesTable()[milestoneIndex]
                        return (current and tonumber(current.thresholdPercent)) or 0
                    end,
                    set = function(_, value)
                        local current = EnsureMilestonesTable()[milestoneIndex]
                        if not current then return end
                        current.thresholdPercent = tonumber(value) or 0
                        RefreshMilestoneRuntime()
                    end
                },
                triggerType = {
                    type = "select",
                    order = 3,
                    width = 0.8,
                    name = L["MILESTONE_TRIGGER_TYPE"],
                    values = {
                        none = L["MILESTONE_TRIGGER_NONE"],
                        zone = L["MILESTONE_TRIGGER_ZONE"],
                        subzone = L["MILESTONE_TRIGGER_SUBZONE"],
                    },
                    get = function()
                        local current = EnsureMilestonesTable()[milestoneIndex]
                        return (current and current.triggerType) or "none"
                    end,
                    set = function(_, value)
                        local current = EnsureMilestonesTable()[milestoneIndex]
                        if not current then return end
                        current.triggerType = value
                        if value == "none" then
                            current.inform = false
                            current.matchAreaID = nil
                            current.matchMapID = nil
                        end
                        RefreshDungeonRouting()
                    end
                },
                matchText = {
                    type = "input",
                    order = 4,
                    width = 1.2,
                    name = L["MILESTONE_MATCH_TEXT"],
                    hidden = function()
                        local current = EnsureMilestonesTable()[milestoneIndex]
                        return not current or current.triggerType == "none"
                    end,
                    get = function()
                        local current = EnsureMilestonesTable()[milestoneIndex]
                        return current and GetMilestoneMatchDisplayText(current) or ""
                    end,
                    set = function(_, value)
                        local current = EnsureMilestonesTable()[milestoneIndex]
                        if not current then return end
                        current.matchText = tostring(value or "")
                        current.matchAreaID = nil
                        current.matchMapID = nil
                        RefreshMilestoneRuntime()
                    end
                },
                captureZone = {
                    type = "execute",
                    order = 5,
                    width = 0.8,
                    name = L["MILESTONE_CAPTURE_ZONE"],
                    hidden = function()
                        local current = EnsureMilestonesTable()[milestoneIndex]
                        return not current or current.triggerType ~= "zone"
                    end,
                    func = function()
                        local advanced = self.db.profile.advanced[dungeonKey]
                        local current = EnsureMilestonesTable()[milestoneIndex]
                        if not current then return end
                        if advanced then
                            advanced.milestonesUserEdited = true
                        end
                        if self.CaptureMilestoneTrigger then
                            self:CaptureMilestoneTrigger(current, "zone")
                        end
                        RefreshMilestoneRuntime()
                        ACR:NotifyChange(AddOnName)
                    end
                },
                captureSubzone = {
                    type = "execute",
                    order = 6,
                    width = 0.8,
                    name = L["MILESTONE_CAPTURE_SUBZONE"],
                    hidden = function()
                        local current = EnsureMilestonesTable()[milestoneIndex]
                        return not current or current.triggerType ~= "subzone"
                    end,
                    func = function()
                        local advanced = self.db.profile.advanced[dungeonKey]
                        local current = EnsureMilestonesTable()[milestoneIndex]
                        if not current then return end
                        if advanced then
                            advanced.milestonesUserEdited = true
                        end
                        if self.CaptureMilestoneTrigger then
                            self:CaptureMilestoneTrigger(current, "subzone")
                        end
                        RefreshMilestoneRuntime()
                        ACR:NotifyChange(AddOnName)
                    end
                },
                informRow = ColumnRow(7, {
                    type = "toggle",
                    width = 1,
                    name = L["SHOW_INFORM_GROUP_BUTTON"],
                    desc = L["SHOW_INFORM_GROUP_BUTTON_DESC"],
                    hidden = function()
                        local current = EnsureMilestonesTable()[milestoneIndex]
                        return not current or current.triggerType == "none"
                    end,
                    get = function()
                        local current = EnsureMilestonesTable()[milestoneIndex]
                        return current and current.inform == true or false
                    end,
                    set = function(_, value)
                        local current = EnsureMilestonesTable()[milestoneIndex]
                        if not current then return end
                        current.inform = value == true
                        RefreshMilestoneRuntime()
                    end
                }, {
                    type = "input",
                    width = 1.1,
                    name = L["MILESTONE_INFORM_SUFFIX"],
                    desc = L["MILESTONE_INFORM_SUFFIX_DESC"],
                    hidden = function()
                        local current = EnsureMilestonesTable()[milestoneIndex]
                        return not current or current.triggerType == "none" or current.inform == false
                    end,
                    get = function()
                        local current = EnsureMilestonesTable()[milestoneIndex]
                        return current and current.informSuffix or ""
                    end,
                    set = function(_, value)
                        local current = EnsureMilestonesTable()[milestoneIndex]
                        if not current then return end
                        current.informSuffix = tostring(value or "")
                        RefreshMilestoneRuntime()
                    end
                }),
                remove = {
                    type = "execute",
                    order = 8,
                    width = 0.8,
                    name = L["MILESTONE_REMOVE"],
                    confirm = true,
                    confirmText = L["MILESTONE_REMOVE_CONFIRM"],
                    func = function()
                        local advanced = self.db.profile.advanced[dungeonKey]
                        if advanced then
                            advanced.milestonesUserEdited = true
                        end
                        local currentMilestones = EnsureMilestonesTable()
                        table.remove(currentMilestones, milestoneIndex)
                        if RebuildMilestoneOptionGroups then
                            RebuildMilestoneOptionGroups()
                        end
                        RefreshDungeonRouting()
                        RefreshDungeonRoutingOptionsView()
                    end
                },
            }
        }
    end

    RebuildMilestoneOptionGroups = function()
        local milestoneArgs = options.args.milestones.args
        for key in pairs(milestoneArgs) do
            if type(key) == "string" and key:match("^milestone%d+$") then
                milestoneArgs[key] = nil
            end
        end

        local milestones = EnsureMilestonesTable()
        for milestoneIndex = 1, #milestones do
            AddMilestoneOptions(milestoneIndex)
        end
    end

    RebuildMilestoneOptionGroups()

    self._dungeonMilestoneRebuilders = self._dungeonMilestoneRebuilders or {}
    self._dungeonMilestoneRebuilders[dungeonKey] = RebuildMilestoneOptionGroups

    return options
end
