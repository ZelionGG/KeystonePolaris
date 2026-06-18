local AddOnName, KeystonePolaris = ...
local L = LibStub("AceLocale-3.0"):GetLocale(AddOnName)
local EXPORT_PREFIX = "!KeystonePolaris:"

-- ---------------------------------------------------------------------------
-- Import / Export Logic
-- ---------------------------------------------------------------------------

-- Shallow clone helper (reused here locally if needed, or we can make it global later)
local function CloneTable(tbl)
    if type(CopyTable) == "function" then return CopyTable(tbl) end
    local t = {}
    for k, v in pairs(tbl) do t[k] = v end
    return t
end

local IsProfileImportPayload

local function IsKeystoneImportPayload(importData)
    if type(importData) ~= "table" then return false end
    if importData.type == "all_dungeons" or importData.type == "section" then
        return type(importData.data) == "table"
    end
    if importData.dungeon and type(importData.data) == "table" then return true end
    return false
end

local function SortedNumericKeys(tbl)
    local keys = {}
    if type(tbl) ~= "table" then return keys end
    for k in pairs(tbl) do
        if type(k) == "number" then
            keys[#keys + 1] = k
        end
    end
    table.sort(keys)
    return keys
end

local function CountSelectedClones(selection)
    if selection == true then return 1 end
    if type(selection) == "number" then
        if selection > 0 then return selection end
        return 0
    end
    if type(selection) ~= "table" then return 0 end

    local c = 0
    for k, v in pairs(selection) do
        -- Canonical MDT format: array of clone IDs (numeric key/value)
        if type(k) == "number" then
            if type(v) == "boolean" then
                if v then c = c + 1 end
            else
                -- Value can be clone id or payload; key position still denotes one selected clone.
                c = c + 1
            end
        else
            -- Some variants use cloneID as string key -> true
            local keyClone = tonumber(k)
            if keyClone and keyClone > 0 then
                keyClone = math.floor(keyClone)
            else
                keyClone = nil
            end
            if keyClone and v then
                c = c + 1
            end
        end
    end
    return c
end

local function ParsePositiveInt(v)
    local n = tonumber(v)
    if n and n > 0 then return math.floor(n) end
    return nil
end

local function BossDataHasNpcID(bossData, npcID)
    npcID = ParsePositiveInt(npcID)
    if not npcID or type(bossData) ~= "table" then return false end

    local bossNpcData = bossData[7]
    if type(bossNpcData) == "table" then
        for _, value in ipairs(bossNpcData) do
            if ParsePositiveInt(value) == npcID then
                return true
            end
        end
        return false
    end

    return ParsePositiveInt(bossNpcData) == npcID
end

local function DungeonBossDataHasNpcIDs(addon, dungeonKey)
    local dungeon = addon.GlobalDungeonLookup and addon.GlobalDungeonLookup[dungeonKey]
    local bosses = dungeon and dungeon.bosses
    if type(bosses) ~= "table" or #bosses == 0 then return false end

    for _, bossData in ipairs(bosses) do
        local bossNpcData = type(bossData) == "table" and bossData[7] or nil
        if type(bossNpcData) == "table" then
            local hasValidNpcID = false
            for _, value in ipairs(bossNpcData) do
                if ParsePositiveInt(value) then
                    hasValidNpcID = true
                    break
                end
            end
            if not hasValidNpcID then return false end
        elseif not ParsePositiveInt(bossNpcData) then
            return false
        end
    end

    return true
end

local function GetPullEnemySelectionTable(pull)
    if type(pull) ~= "table" then return nil end
    if next(pull) ~= nil then
        local hasNumeric = false
        for k in pairs(pull) do
            if type(k) == "number" or ParsePositiveInt(k) then
                hasNumeric = true
                break
            end
        end
        if hasNumeric then return pull end
    end

    local candidates = {
        pull.enemies,
        pull.selection,
        pull.pulls,
        pull.data
    }
    for _, t in ipairs(candidates) do
        if type(t) == "table" then return t end
    end
    return nil
end

local function CollectRouteEnemyIndices(pulls)
    local out = {}
    local hasAny = false
    if type(pulls) ~= "table" then return out, hasAny end

    for _, pull in pairs(pulls) do
        local selection = GetPullEnemySelectionTable(pull)
        if type(selection) == "table" then
            for enemyIdx in pairs(selection) do
                local idx = ParsePositiveInt(enemyIdx)
                if idx then
                    out[idx] = true
                    hasAny = true
                end
            end
        end
    end

    return out, hasAny
end

local function InferMDTDungeonIndexFromPulls(pulls, mdt)
    if not mdt or type(mdt.dungeonEnemies) ~= "table" then
        return nil, {reason = "mdt_enemies_unavailable"}
    end
    local usedEnemies, hasAny = CollectRouteEnemyIndices(pulls)
    if not hasAny then return nil, {reason = "no_enemy_indices"} end

    local bestIdx, bestScore, bestMiss = nil, -1, 10 ^ 9
    local secondScore = -1
    for idx, enemyList in pairs(mdt.dungeonEnemies) do
        if type(idx) == "number" and type(enemyList) == "table" then
            local score = 0
            local miss = 0
            for enemyIdx in pairs(usedEnemies) do
                if enemyList[enemyIdx] ~= nil then
                    score = score + 1
                else
                    miss = miss + 1
                end
            end

            if score > bestScore or (score == bestScore and miss < bestMiss) then
                secondScore = bestScore
                bestScore = score
                bestMiss = miss
                bestIdx = idx
            elseif score > secondScore then
                secondScore = score
            end
        end
    end

    if not bestIdx then return nil, {reason = "no_candidates"} end
    -- Strong confidence when everything matches.
    if bestMiss == 0 and bestScore > 0 then
        return bestIdx, {bestScore = bestScore, secondScore = secondScore, bestMiss = bestMiss, confidence = "exact"}
    end
    -- Otherwise require a clear winner.
    if bestScore > 0 and (bestScore - secondScore) >= 3 then
        return bestIdx, {bestScore = bestScore, secondScore = secondScore, bestMiss = bestMiss, confidence = "clear_winner"}
    end
    return nil, {bestScore = bestScore, secondScore = secondScore, bestMiss = bestMiss, reason = "ambiguous"}
end

local function NormalizeTextForMatch(text)
    if type(text) ~= "string" then return nil end
    local s = text:lower()
    s = s:gsub("[%s%p_%-]+", "")
    return s
end

local function FindRouteLikeTable(root)
    if type(root) ~= "table" then return nil end
    if type(root.pulls) == "table" then return root end

    local queue = {root}
    local seen = {[root] = true}
    local q = 1

    while q <= #queue do
        local node = queue[q]
        q = q + 1
        for _, v in pairs(node) do
            if type(v) == "table" and not seen[v] then
                if type(v.pulls) == "table" then return v end
                seen[v] = true
                queue[#queue + 1] = v
            end
        end
    end
    return nil
end

local function ResolveMDTDungeonIndex(routeData, mdt)
    if type(routeData) ~= "table" then return nil end
    local candidates = {
        routeData.currentDungeonIdx,
        routeData.dungeonIdx,
        routeData.dungeonIndex,
        routeData.value and routeData.value.currentDungeonIdx,
        routeData.value and routeData.value.dungeonIdx,
        routeData.value and routeData.value.dungeonIndex
    }
    for _, c in ipairs(candidates) do
        local n = ParsePositiveInt(c)
        if n then return n end
    end
    -- Some MDT exports may encode the challenge mode id directly.
    local directMap = {
        routeData.currentDungeonID,
        routeData.dungeonID,
        routeData.challengeModeID,
        routeData.challengeModeMapID,
        routeData.value and routeData.value.currentDungeonID,
        routeData.value and routeData.value.dungeonID,
        routeData.value and routeData.value.challengeModeID,
        routeData.value and routeData.value.challengeModeMapID
    }
    for _, c in ipairs(directMap) do
        local n = ParsePositiveInt(c)
        if n then
            -- If this is already a challenge mode id, caller will map it.
            return n
        end
    end

    if mdt and type(mdt.currentDungeonIdx) == "number" then
        return mdt.currentDungeonIdx
    end
    return nil
end

local function GetDungeonKeyByMapID(addon, mapID)
    local wanted = ParsePositiveInt(mapID)
    if not wanted then return nil end
    for dungeonKey, dData in pairs(addon.GlobalDungeonLookup or {}) do
        if type(dData) == "table" and ParsePositiveInt(dData.mapID) == wanted then
            return dungeonKey
        end
    end
    return nil
end

local function TryResolveDungeonKeyByCandidate(addon, mdt, candidate)
    local n = ParsePositiveInt(candidate)
    if not n then return nil end

    -- Candidate might already be a challenge mode map id.
    local byCMId = addon:GetDungeonKeyById(n)
    if byCMId then return byCMId end

    -- Candidate might be a UI map id.
    local byMapId = GetDungeonKeyByMapID(addon, n)
    if byMapId then return byMapId end

    -- Candidate might be an MDT dungeon index.
    if mdt and type(mdt.mapInfo) == "table" and type(mdt.mapInfo[n]) == "table" then
        local info = mdt.mapInfo[n]
        local infoCandidates = {
            info.mapID,
            info.challengeModeID,
            info.challengeModeMapID,
            info.cmID
        }
        for _, v in ipairs(infoCandidates) do
            local key = TryResolveDungeonKeyByCandidate(addon, nil, v)
            if key then return key end
        end
    end

    if mdt and type(mdt.dungeonList) == "table" and type(mdt.dungeonList[n]) == "string" then
        local normalized = NormalizeTextForMatch(mdt.dungeonList[n])
        if normalized then
            for dungeonKey, data in pairs(addon.GlobalDungeonLookup or {}) do
                local displayName = addon:GetDungeonDisplayName(dungeonKey)
                local candidates = {
                    dungeonKey,
                    data and data.displayName,
                    displayName
                }
                for _, candidateName in ipairs(candidates) do
                    if NormalizeTextForMatch(candidateName) == normalized then
                        return dungeonKey
                    end
                end
            end
        end
    end

    if mdt and type(mdt.dungeonList) == "table" and type(mdt.dungeonList[n]) == "table" then
        local entry = mdt.dungeonList[n]
        local mapCandidates = {
            entry.id,
            entry.challengeModeID,
            entry.challengeModeMapID,
            entry.cmID,
            entry.mapID
        }
        for _, v in ipairs(mapCandidates) do
            local key = TryResolveDungeonKeyByCandidate(addon, nil, v)
            if key then return key end
        end
    end

    -- Some MDT builds/plugins don't key dungeonList by index, but store index-like fields in entries.
    if mdt and type(mdt.dungeonList) == "table" then
        for _, entry in pairs(mdt.dungeonList) do
            if type(entry) == "table" then
                local idxLike = ParsePositiveInt(entry.index or entry.dungeonIdx or entry.currentDungeonIdx or entry.value)
                if idxLike and idxLike == n then
                    local mapCandidates = {
                        entry.id,
                        entry.challengeModeID,
                        entry.challengeModeMapID,
                        entry.cmID,
                        entry.mapID
                    }
                    for _, v in ipairs(mapCandidates) do
                        local key = TryResolveDungeonKeyByCandidate(addon, nil, v)
                        if key then return key end
                    end
                end
            end
        end
    end

    return nil
end

local function InferDungeonKeyFromBossData(addon, pulls, mdt, preferredIdx)
    if type(pulls) ~= "table" or not mdt or type(mdt.dungeonEnemies) ~= "table" then
        return nil
    end

    local dungeonIdx = preferredIdx
    if not dungeonIdx then
        dungeonIdx = ResolveMDTDungeonIndex({pulls = pulls}, mdt)
    end
    if not dungeonIdx then
        dungeonIdx = InferMDTDungeonIndexFromPulls(pulls, mdt)
    end
    if not dungeonIdx then return nil end

    local enemies = mdt.dungeonEnemies[dungeonIdx]
    if type(enemies) ~= "table" then return nil end

    local encounterSet = {}
    local bossNpcSet = {}
    local bossNameSet = {}
    for _, pull in pairs(pulls) do
        local selection = GetPullEnemySelectionTable(pull)
        if type(selection) == "table" then
            for enemyIdx, cloneSelection in pairs(selection) do
                local idx = ParsePositiveInt(enemyIdx)
                local enemy = idx and enemies[idx] or nil
                if type(enemy) == "table" and CountSelectedClones(cloneSelection) > 0 then
                    local encounterID = ParsePositiveInt(enemy.encounterID or enemy.journalEncounterID or enemy.ejid)
                    if encounterID then
                        encounterSet[encounterID] = true
                    end
                    if enemy.isBoss then
                        local bossNpc = ParsePositiveInt(enemy.id or enemy.npcId)
                        if bossNpc then
                            bossNpcSet[bossNpc] = true
                        end
                    end
                    if enemy.isBoss and type(enemy.name) == "string" then
                        bossNameSet[NormalizeTextForMatch(enemy.name)] = true
                    end
                end
            end
        end
    end

    local bestKey, bestScore = nil, 0
    for dungeonKey, dData in pairs(addon.GlobalDungeonLookup or {}) do
        if type(dData) == "table" and type(dData.bosses) == "table" then
            local score = 0
            for i, bossData in ipairs(dData.bosses) do
                local ej = ParsePositiveInt(bossData[5])
                local hasBossNpc = false
                for bossNpc in pairs(bossNpcSet) do
                    if BossDataHasNpcID(bossData, bossNpc) then
                        hasBossNpc = true
                        break
                    end
                end
                if hasBossNpc then
                    score = score + 5
                elseif ej and encounterSet[ej] then
                    score = score + 3
                else
                    local bossName = NormalizeTextForMatch(addon:GetBossName(dungeonKey, i))
                    if bossName and bossNameSet[bossName] then
                        score = score + 1
                    end
                end
            end
            if score > bestScore then
                bestScore = score
                bestKey = dungeonKey
            end
        end
    end

    if bestScore > 0 then return bestKey end
    return nil
end

local function ResolveDungeonKeyFromMDT(addon, routeData, pulls, mdt)
    local idxOrMapId = ResolveMDTDungeonIndex(routeData, mdt)
    local inferredInfo = nil
    local inferredIdx = nil
    if not idxOrMapId then
        inferredIdx, inferredInfo = InferMDTDungeonIndexFromPulls(pulls, mdt)
    end
    idxOrMapId = idxOrMapId or inferredIdx
    if idxOrMapId then
        local fromPrimary = TryResolveDungeonKeyByCandidate(addon, mdt, idxOrMapId)
        if fromPrimary then return fromPrimary, idxOrMapId, inferredInfo end
    end

    -- If a route index exists but couldn't be resolved, still try enemy-based inference.
    if not inferredIdx then
        inferredIdx, inferredInfo = InferMDTDungeonIndexFromPulls(pulls, mdt)
    end
    if inferredIdx then
        local fromInference = TryResolveDungeonKeyByCandidate(addon, mdt, inferredIdx)
        if fromInference then return fromInference, inferredIdx, inferredInfo end
    end

    -- Final fallback: infer dungeon via selected boss encounterIDs/names from MDT enemy data.
    local fromBossData = InferDungeonKeyFromBossData(addon, pulls, mdt, idxOrMapId or inferredIdx)
    if fromBossData then
        return fromBossData, (idxOrMapId or inferredIdx), inferredInfo
    end

    local importName = routeData and (routeData.name or routeData.dungeonName or routeData.title
        or (routeData.value and routeData.value.name)
        or (routeData.value and routeData.value.dungeonName))
    local normalizedImportName = NormalizeTextForMatch(importName)
    if not normalizedImportName then return nil, idxOrMapId, inferredInfo end

    for dungeonKey, data in pairs(addon.GlobalDungeonLookup or {}) do
        local displayName = addon:GetDungeonDisplayName(dungeonKey)
        local candidates = {
            dungeonKey,
            data and data.displayName,
            displayName
        }
        for _, candidate in ipairs(candidates) do
            if NormalizeTextForMatch(candidate) == normalizedImportName then
                return dungeonKey, idxOrMapId, inferredInfo
            end
        end
    end
    return nil, idxOrMapId, inferredInfo
end

local function GetEnemyForcesCount(enemy)
    if type(enemy) ~= "table" then return 0 end
    local n = tonumber(enemy.count or enemy.forces or enemy.enemyForces or enemy.teemingCount)
    if n and n > 0 then return n end
    return 0
end

local function ResolveTotalForces(mdt, dungeonIdx, enemyTable)
    if mdt and type(mdt.dungeonTotalCount) == "table" then
        local total = mdt.dungeonTotalCount[dungeonIdx]
        if type(total) == "number" and total > 0 then return total end
        if type(total) == "table" then
            local n = tonumber(total.normal or total.count or total.total)
            if n and n > 0 then return n end
        end
    end
    if mdt and type(mdt.GetEnemyForces) == "function" and type(enemyTable) == "table" then
        for _, enemy in pairs(enemyTable) do
            local npc = type(enemy) == "table" and tonumber(enemy.id) or nil
            if npc then
                local _, max, maxTeeming = mdt:GetEnemyForces(npc)
                local denom = tonumber(max) or tonumber(maxTeeming)
                if denom and denom > 0 then return denom end
            end
        end
    end
    return nil
end

local function ResolveBossIndex(addon, dungeonKey, enemy)
    if type(enemy) ~= "table" then return nil end

    local dungeon = addon.GlobalDungeonLookup and addon.GlobalDungeonLookup[dungeonKey]
    local bosses = dungeon and dungeon.bosses
    if type(bosses) ~= "table" then return nil end

    local npcID = ParsePositiveInt(enemy.id or enemy.npcId)
    if npcID then
        local matched = {}
        for i, bossData in ipairs(bosses) do
            if BossDataHasNpcID(bossData, npcID) then
                matched[#matched + 1] = i
            end
        end
        if #matched == 1 then
            return matched[1]
        end
    end

    local encounterID = tonumber(enemy.encounterID or enemy.journalEncounterID or enemy.ejid)
    if encounterID then
        local matched = {}
        for i, bossData in ipairs(bosses) do
            if tonumber(bossData[5]) == encounterID then
                matched[#matched + 1] = i
            end
        end
        -- Only trust encounterID when it maps to a single boss.
        if #matched == 1 then
            return matched[1]
        end
    end

    -- Fallback by name, but only for explicit boss entries.
    if not enemy.isBoss then return nil end
    local enemyName = NormalizeTextForMatch(enemy.name)
    if not enemyName then return nil end

    local function NameMatches(a, b)
        if not a or not b then return false end
        if a == b then return true end
        if #a >= 4 and #b >= 4 then
            return a:find(b, 1, true) ~= nil or b:find(a, 1, true) ~= nil
        end
        return false
    end

    for i = 1, #bosses do
        local bossName = NormalizeTextForMatch(addon:GetBossName(dungeonKey, i))
        local manualBossName = NormalizeTextForMatch(bosses[i] and bosses[i][6])
        if NameMatches(enemyName, bossName) or NameMatches(enemyName, manualBossName) then
            return i
        end
    end
    return nil
end

local function BuildFallbackOrder(existingOrder, numBosses)
    local out = {}
    if type(existingOrder) == "table" then
        for i = 1, numBosses do
            out[#out + 1] = tonumber(existingOrder[i]) or i
        end
    else
        for i = 1, numBosses do
            out[#out + 1] = i
        end
    end
    return out
end

local function FindExpansionSectionKeyForDungeon(addon, dungeonKey)
    if type(dungeonKey) ~= "string" then return nil end

    for _, expansion in ipairs(addon.Expansions or {}) do
        local dungeonIds = addon[expansion.id .. "_DUNGEON_IDS"]
        if type(dungeonIds) == "table" and dungeonIds[dungeonKey] then
            return expansion.id:lower()
        end
    end

    return nil
end

local function OpenOptionsForDungeon(addon, dungeonKey)
    if type(dungeonKey) ~= "string" then return false end

    local dungeonId = addon:GetDungeonIdByKey(dungeonKey)
    if not dungeonId or not addon.DUNGEONS[dungeonId] then return false end

    addon.currentDungeonID = dungeonId
    if addon.BuildSectionOrder then
        addon:BuildSectionOrder(dungeonId)
    end

    local optionsAddonName = (addon.GetGradientAddonNameFromSecondLetter and addon:GetGradientAddonNameFromSecondLetter()) or "Keystone Polaris"
    if Settings and Settings.OpenToCategory then
        Settings.OpenToCategory(addon.optionsCategoryId or optionsAddonName)
    end

    local aceConfigDialog = LibStub("AceConfigDialog-3.0", true)
    if not aceConfigDialog then return true end

    local expansionSectionKey = FindExpansionSectionKeyForDungeon(addon, dungeonKey)
    if expansionSectionKey then
        aceConfigDialog:SelectGroup(AddOnName, "advanced", expansionSectionKey, dungeonKey)
    else
        aceConfigDialog:SelectGroup(AddOnName, "advanced")
    end

    return true
end

local function CopyImportedDungeonData(addon, dungeonKey, dungeonData)
    local dungeonId = addon:GetDungeonIdByKey(dungeonKey)
    if not dungeonId or not addon.DUNGEONS[dungeonId] or type(dungeonData) ~= "table" then
        return false
    end

    if not addon.db.profile.advanced[dungeonKey] then
        addon.db.profile.advanced[dungeonKey] = {}
    end

    for k, v in pairs(dungeonData) do
        if type(v) == "table" then
            addon.db.profile.advanced[dungeonKey][k] = CloneTable(v)
        else
            addon.db.profile.advanced[dungeonKey][k] = v
        end
    end

    return true
end

local function DecodeSerializedPayload(payload)
    local libDeflate = LibStub("LibDeflate")
    local serializer = LibStub("AceSerializer-3.0")
    if type(payload) ~= "string" then return nil end

    local candidatePayloads = {payload}
    if payload:sub(1, 1) == "!" then
        candidatePayloads[#candidatePayloads + 1] = payload:sub(2)
    end

    for _, p in ipairs(candidatePayloads) do
        local decoded = libDeflate:DecodeForPrint(p)
        if decoded then
            local decompressed = libDeflate:DecompressDeflate(decoded)
            if decompressed then
                local ok, data = serializer:Deserialize(decompressed)
                if ok and data then
                    return data
                end
            end
        end
    end

    return nil
end

function KeystonePolaris:TryImportMDTRoute(importPayload)
    local prefix = (self.GetChatPrefix and self:GetChatPrefix()) or "Keystone Polaris"
    local routeRoot = DecodeSerializedPayload(importPayload)
    if not routeRoot then
        print(prefix .. ": " .. L["IMPORT_ERROR"])
        return false
    end

    local routeData = FindRouteLikeTable(routeRoot) or routeRoot
    local pulls = routeData and routeData.pulls
    if type(pulls) ~= "table" then
        print(prefix .. ": " .. L["IMPORT_MDT_NO_PULLS"])
        return false
    end

    local mdt = _G and (_G.MDT or _G.MethodDungeonTools) or nil
    if not mdt or type(mdt.dungeonEnemies) ~= "table" then
        print(prefix .. ": " .. L["IMPORT_MDT_MISSING_ADDON"])
        return false
    end

    local dungeonKey = ResolveDungeonKeyFromMDT(self, routeData, pulls, mdt)
    if not dungeonKey then
        print(prefix .. ": " .. L["IMPORT_MDT_DUNGEON_UNKNOWN"])
        return false
    end

    local mapId = self:GetDungeonIdByKey(dungeonKey)
    if not mapId or not self.DUNGEONS[mapId] then
        print(prefix .. ": " .. L["IMPORT_MDT_DUNGEON_UNKNOWN"])
        return false
    end
    if not DungeonBossDataHasNpcIDs(self, dungeonKey) then
        print(prefix .. ": " .. L["IMPORT_MDT_BOSS_NPCIDS_MISSING"]:format(self:GetDungeonDisplayName(dungeonKey)))
        return false
    end

    local dungeonIdx = ResolveMDTDungeonIndex(routeData, mdt)
    if not dungeonIdx then
        dungeonIdx = InferMDTDungeonIndexFromPulls(pulls, mdt)
    end
    local enemies = dungeonIdx and mdt.dungeonEnemies[dungeonIdx] or nil
    if type(enemies) ~= "table" and type(mdt.dungeonList) == "table" then
        for idx, dungeonInfo in pairs(mdt.dungeonList) do
            if type(idx) == "number" and type(dungeonInfo) == "table" then
                local entryMapId = tonumber(dungeonInfo.id or dungeonInfo.challengeModeID or dungeonInfo.challengeModeMapID or dungeonInfo.cmID)
                if entryMapId and entryMapId == mapId and type(mdt.dungeonEnemies[idx]) == "table" then
                    dungeonIdx = idx
                    enemies = mdt.dungeonEnemies[idx]
                    break
                end
            end
        end
    end
    local totalForces = ResolveTotalForces(mdt, dungeonIdx, enemies)

    if not self.db.profile.advanced[dungeonKey] then
        self.db.profile.advanced[dungeonKey] = {}
    end
    local advancedData = self.db.profile.advanced[dungeonKey]
    local numBosses = #(self.DUNGEONS[mapId] or {})

    local cumulativeForces = 0
    local bossThresholds = {}
    local seenBossSet = {}

    for _, pullIdx in ipairs(SortedNumericKeys(pulls)) do
        local pull = pulls[pullIdx]
        local pullSelection = GetPullEnemySelectionTable(pull)
        if type(pullSelection) == "table" then
            local pullForces = 0
            local pullBosses = {}

            for enemyIdx, cloneSelection in pairs(pullSelection) do
                local enemyIndex = ParsePositiveInt(enemyIdx)
                if enemyIndex then
                    local enemy = enemies[enemyIndex]
                    if type(enemy) == "table" then
                        local selectedClones = CountSelectedClones(cloneSelection)
                        if selectedClones > 0 then
                            pullForces = pullForces + (GetEnemyForcesCount(enemy) * selectedClones)

                            local bossIndex = ResolveBossIndex(self, dungeonKey, enemy)
                            if bossIndex and not pullBosses[bossIndex] then
                                pullBosses[bossIndex] = true
                            end
                        end
                    end
                end
            end

            cumulativeForces = cumulativeForces + pullForces
            if cumulativeForces < 0 then cumulativeForces = 0 end
            if cumulativeForces > totalForces then cumulativeForces = totalForces end

            local pct = (cumulativeForces / totalForces) * 100
            pct = math.floor((pct * 100) + 0.5) / 100

            local pullBossList = {}
            for bossIndex in pairs(pullBosses) do
                pullBossList[#pullBossList + 1] = bossIndex
            end
            table.sort(pullBossList)
            for _, bossIndex in ipairs(pullBossList) do
                if not bossThresholds[bossIndex] then
                    bossThresholds[bossIndex] = pct
                    if not seenBossSet[bossIndex] then
                        seenBossSet[bossIndex] = true
                    end
                end
            end

        end
    end

    local importedCount = 0
    local missingBosses = {}
    for bossIdx = 1, numBosses do
        if bossThresholds[bossIdx] == nil then
            missingBosses[#missingBosses + 1] = bossIdx
        end
    end

    if #missingBosses > 0 then
        print(prefix .. ": " .. L["IMPORT_MDT_INCOMPLETE"])
        return false
    end

    for bossIdx = 1, numBosses do
        local threshold = bossThresholds[bossIdx]
        if threshold ~= nil then
            local bossNumStr = self:GetBossNumberString(bossIdx)
            advancedData["Boss" .. bossNumStr] = threshold
            importedCount = importedCount + 1
        end
    end

    -- Build boss order from final thresholds (fallback to previous order for ties/unknowns).
    local existingOrder = BuildFallbackOrder(advancedData.bossOrder, numBosses)
    local rankByExisting = {}
    for rank, bossIdx in ipairs(existingOrder) do
        rankByExisting[bossIdx] = rank
    end
    local orderCandidates = {}
    for bossIdx = 1, numBosses do
        orderCandidates[#orderCandidates + 1] = {
            idx = bossIdx,
            pct = tonumber(bossThresholds[bossIdx]) or 999,
            rank = rankByExisting[bossIdx] or bossIdx
        }
    end
    table.sort(orderCandidates, function(a, b)
        if a.pct ~= b.pct then return a.pct < b.pct end
        return a.rank < b.rank
    end)
    local builtOrder = {}
    for rank, item in ipairs(orderCandidates) do
        builtOrder[rank] = item.idx
    end
    advancedData.bossOrder = builtOrder
    self:UpdateDungeonData()
    if self.currentDungeonID and self.BuildSectionOrder then
        self:BuildSectionOrder(self.currentDungeonID)
    end
    LibStub("AceConfigRegistry-3.0"):NotifyChange("KeystonePolaris")
    if self.UpdatePercentageText then self:UpdatePercentageText() end

    if importedCount > 0 then
        local openedOptions = OpenOptionsForDungeon(self, dungeonKey)
        local messageKey = openedOptions and "IMPORT_MDT_SUCCESS_OPENED" or "IMPORT_MDT_SUCCESS"
        print(prefix .. ": " .. L[messageKey]:format(self:GetDungeonDisplayName(dungeonKey), importedCount))
        return true
    end

    print(prefix .. ": " .. L["IMPORT_MDT_INCOMPLETE"])
    return false
end

local function ImportKeystoneData(addon, importData, sectionName, dungeonFilter)
    local prefix = (addon.GetChatPrefix and addon:GetChatPrefix()) or "Keystone Polaris"
    local importCount = 0

    -- Handle different import types
    if importData.type == "all_dungeons" and importData.data then
        -- Import all dungeon data (filtered by dungeonFilter if provided)
        for dungeonKey, dungeonData in pairs(importData.data) do
            if not dungeonFilter or dungeonFilter[dungeonKey] then
                local dungeonId = addon:GetDungeonIdByKey(dungeonKey)
                if dungeonId and addon.DUNGEONS[dungeonId] then
                    if not addon.db.profile.advanced[dungeonKey] then
                        addon.db.profile.advanced[dungeonKey] = {}
                    end
                    for k, v in pairs(dungeonData) do
                        if type(v) == "table" then
                            addon.db.profile.advanced[dungeonKey][k] = CloneTable(v)
                        else
                            addon.db.profile.advanced[dungeonKey][k] = v
                        end
                    end
                    importCount = importCount + 1
                end
            end
        end
    elseif importData.type == "section" and importData.data then
        -- Import section data (filtered by dungeonFilter if provided)
        for dungeonKey, dungeonData in pairs(importData.data) do
            if not dungeonFilter or dungeonFilter[dungeonKey] then
                local dungeonId = addon:GetDungeonIdByKey(dungeonKey)
                if dungeonId and addon.DUNGEONS[dungeonId] then
                    if not addon.db.profile.advanced[dungeonKey] then
                        addon.db.profile.advanced[dungeonKey] = {}
                    end
                    for k, v in pairs(dungeonData) do
                        if type(v) == "table" then
                            addon.db.profile.advanced[dungeonKey][k] = CloneTable(v)
                        else
                            addon.db.profile.advanced[dungeonKey][k] = v
                        end
                    end
                    importCount = importCount + 1
                end
            end
        end
    elseif importData.dungeon then
        -- Handle single dungeon import for backward compatibility
        local dungeonKey = importData.dungeon
        if CopyImportedDungeonData(addon, dungeonKey, importData.data) then
            addon:UpdateDungeonData()
            if addon.currentDungeonID and addon.BuildSectionOrder then
                addon:BuildSectionOrder(addon.currentDungeonID)
            end
            LibStub("AceConfigRegistry-3.0"):NotifyChange(
                "KeystonePolaris")
            if addon.UpdatePercentageText then addon:UpdatePercentageText() end
            local openedOptions = OpenOptionsForDungeon(addon, dungeonKey)
            local messageKey = openedOptions and "IMPORT_SUCCESS_OPENED" or "IMPORT_SUCCESS"
            print(prefix .. ": " ..
                      L[messageKey]:format(
                          addon:GetDungeonDisplayName(dungeonKey)))
            return true
        end

        print(prefix .. ": " .. L["IMPORT_ERROR"])
        return false
    else
        print(prefix .. ": " .. L["IMPORT_ERROR"])
        return false
    end

    -- Update data and notify of changes
    if importCount > 0 then
        addon:UpdateDungeonData()

        if addon.currentDungeonID and addon.BuildSectionOrder then
            addon:BuildSectionOrder(addon.currentDungeonID)
        end
        LibStub("AceConfigRegistry-3.0"):NotifyChange("KeystonePolaris")
        if addon.UpdatePercentageText then addon:UpdatePercentageText() end

        -- Determine success message based on import type
        if importData.type == "all_dungeons" then
            print(prefix .. ": " ..
                      (L["IMPORT_ALL_SUCCESS"]))
        elseif importData.type == "section" then
            local successTarget = sectionName or importData.section
            if not successTarget and dungeonFilter then
                local dungeonKey = next(dungeonFilter)
                if dungeonKey then
                    successTarget = addon:GetDungeonDisplayName(dungeonKey)
                end
            end

            if successTarget then
                print(prefix .. ": " ..
                          (L["IMPORT_SUCCESS"]):format(successTarget))
            else
                print(prefix .. ": " .. (L["IMPORT_ALL_SUCCESS"]))
            end
        end
        return true
    else
        print(prefix .. ": " .. (L["IMPORT_ERROR"]))
        return false
    end
end

-- Dedicated copy window for long texts (multi-line, scrollable)
function KeystonePolaris:ShowCopyPopup(text)
    if not self.copyPopup then
        local f = CreateFrame("Frame", "KeystonePolarisCopyPopup", UIParent, "BackdropTemplate")
        f:SetFrameStrata("FULLSCREEN_DIALOG")
        f:SetToplevel(true)
        f:SetSize(700, 500)
        f:SetPoint("CENTER")
        -- Style aligné sur l'overlay Test Mode: fond sombre + bordure 1px or
        f:SetBackdrop({ bgFile = "Interface\\ChatFrame\\ChatFrameBackground", edgeFile = "Interface\\ChatFrame\\ChatFrameBackground", tile = true, tileSize = 16, edgeSize = 1 })
        f:SetBackdropColor(0, 0, 0, 1)
        f:SetBackdropBorderColor(1, 0.82, 0, 1)
        -- Renforcer la bordure 1px sur tous les côtés (comme Test Mode)
        if not f.border then f.border = {} end
        local br, bgc, bb, ba = 1, 0.82, 0, 1
        if not f.border.top then f.border.top = f:CreateTexture(nil, "BORDER") end
        f.border.top:SetColorTexture(br, bgc, bb, ba)
        f.border.top:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
        f.border.top:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)
        f.border.top:SetHeight(1)

        if not f.border.bottom then f.border.bottom = f:CreateTexture(nil, "BORDER") end
        f.border.bottom:SetColorTexture(br, bgc, bb, ba)
        f.border.bottom:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 0)
        f.border.bottom:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)
        f.border.bottom:SetHeight(1)

        if not f.border.left then f.border.left = f:CreateTexture(nil, "BORDER") end
        f.border.left:SetColorTexture(br, bgc, bb, ba)
        f.border.left:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
        f.border.left:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 0)
        f.border.left:SetWidth(1)

        if not f.border.right then f.border.right = f:CreateTexture(nil, "BORDER") end
        f.border.right:SetColorTexture(br, bgc, bb, ba)
        f.border.right:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)
        f.border.right:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)
        f.border.right:SetWidth(1)

        local title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
        title:SetPoint("TOP", 0, -12)
        title:SetText("Keystone Polaris — " .. L["Changelog"])
        title:SetTextColor(1, 0.82, 0, 1)

        local instr = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        instr:SetPoint("TOPLEFT", 12, -40)
        instr:SetPoint("RIGHT", -12, 0)
        instr:SetJustifyH("LEFT")
        instr:SetText(L["COPY_INSTRUCTIONS"])
        -- Appliquer la police LSM si dispo, cohérente avec Test Mode
        local fontPath = self.LSM and self.LSM:Fetch('font', self.db and self.db.profile and self.db.profile.text and self.db.profile.text.font) or nil
        local baseSize = (self.db and self.db.profile and self.db.profile.general and self.db.profile.general.fontSize) or 12
        if fontPath then
            title:SetFont(fontPath, (baseSize or 12), self:GetFontFlags())
            instr:SetFont(fontPath, math.max(10, (baseSize or 12) - 6), self:GetFontFlags())
        end

        -- Séparateur sous le texte d'instruction
        local sep = f:CreateTexture(nil, "BORDER")
        sep:SetColorTexture(1, 0.82, 0, 0.25)
        sep:ClearAllPoints()
        sep:SetPoint("TOPLEFT", instr, "BOTTOMLEFT", 0, -10)
        sep:SetPoint("TOPRIGHT", instr, "BOTTOMRIGHT", 0, -10)
        sep:SetHeight(1)

        local scroll = CreateFrame("ScrollFrame", "KeystonePolarisCopyScroll", f, "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", sep, "BOTTOMLEFT", 0, -10)
        scroll:SetPoint("BOTTOMRIGHT", -32, 44)

        local edit = CreateFrame("EditBox", "KeystonePolarisCopyEditBox", scroll)
        edit:SetMultiLine(true)
        edit:SetFontObject(ChatFontNormal)
        edit:SetAutoFocus(true)
        edit:SetWidth(scroll:GetWidth())
        edit:SetText("")
        scroll:SetScrollChild(edit)

        scroll:HookScript("OnSizeChanged", function(_, width)
            edit:SetWidth(width)
        end)

        local selectBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        selectBtn:SetSize(100, 22)
        selectBtn:SetPoint("BOTTOMLEFT", 12, 12)
        selectBtn:SetText(L["SELECT_ALL"])
        selectBtn:SetScript("OnClick", function()
            edit:SetFocus()
            edit:HighlightText()
        end)

        local closeBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        closeBtn:SetSize(80, 22)
        closeBtn:SetPoint("BOTTOMRIGHT", -12, 12)
        closeBtn:SetText(OKAY or "OK")
        closeBtn:SetScript("OnClick", function() f:Hide() end)

        f:SetScript("OnShow", function()
            edit:SetFocus()
            edit:HighlightText()
        end)
        f:SetScript("OnKeyDown", function(_, key)
            if key == "ESCAPE" then f:Hide() end
        end)
        f:EnableKeyboard(true)

        f.editBox = edit
        self.copyPopup = f
    end

    local f = self.copyPopup
    if f and f.editBox then
        f.editBox:SetText(text or "")
        f:Show()
        -- Assurer l'affichage au-dessus des StaticPopup (ex: KPL_MIGRATION)
        local maxPopupLevel = 0
        for i = 1, 4 do
            local p = _G["StaticPopup" .. i]
            if p and p:IsShown() then
                local lvl = p:GetFrameLevel() or 0
                if lvl > maxPopupLevel then maxPopupLevel = lvl end
                -- Si une StaticPopup est en FULLSCREEN_DIALOG, garder la même strata
                if p:GetFrameStrata() == "FULLSCREEN_DIALOG" then
                    f:SetFrameStrata("FULLSCREEN_DIALOG")
                end
            end
        end
        local myLvl = f:GetFrameLevel() or 0
        if maxPopupLevel >= myLvl then
            f:SetFrameLevel(maxPopupLevel + 2)
        end
        f:Raise()
    end
end

-- Global export function for dungeon settings
function KeystonePolaris.ExportDungeonSettings(_, dungeonData, exportType, sectionName)
    -- Create export string
    local exportData
    if exportType == "dungeon" then
        exportData = {
            type = exportType,
            dungeon = sectionName,
            data = dungeonData
        }
    else
        exportData = {
            type = exportType,
            section = sectionName,
            data = dungeonData
        }
    end
    local serialized = LibStub("AceSerializer-3.0"):Serialize(exportData)
    local compressed = LibStub("LibDeflate"):CompressDeflate(serialized)
    local encoded = LibStub("LibDeflate"):EncodeForPrint(compressed)
    local exportString = EXPORT_PREFIX .. encoded

    -- Determine dialog text based on export type
    local dialogText
    if exportType == "all_dungeons" then
        dialogText = L["EXPORT_ALL_DIALOG_TEXT"]
    elseif exportType == "section" then
        dialogText = (L["EXPORT_SECTION_DIALOG_TEXT"]):format(sectionName)
    else
        dialogText = L["EXPORT_DIALOG_TEXT"]
    end

    -- Show export dialog
    StaticPopupDialogs["KPL_EXPORT_DIALOG"] = {
        text = dialogText,
        button1 = OKAY,
        hasEditBox = true,
        editBoxWidth = 350,
        maxLetters = 999999,
        OnShow = function(dialog)
            dialog.EditBox:SetText(exportString)
            dialog.EditBox:HighlightText()
            dialog.EditBox:SetFocus()
        end,
        EditBoxOnEscapePressed = function(editBox)
            editBox:GetParent():Hide()
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true
    }
    StaticPopup_Show("KPL_EXPORT_DIALOG")
end

-- Global import function for dungeon settings
function KeystonePolaris:ImportDungeonSettings(importString,
                                                        sectionName,
                                                        dungeonFilter)
    local addon = self
    local importPayload = importString
    if type(importPayload) == "string" then
        importPayload = importPayload:match("^%s*(.-)%s*$")
        if importPayload:sub(1, #EXPORT_PREFIX) == EXPORT_PREFIX then
            importPayload = importPayload:sub(#EXPORT_PREFIX + 1)
        end
    end

    local importData = DecodeSerializedPayload(importPayload)
    if IsProfileImportPayload(importData) then
        local chatPrefix = (addon.GetChatPrefix and addon:GetChatPrefix()) or "Keystone Polaris"
        print(chatPrefix .. ": " .. L["IMPORT_PROFILE_USE_INTERFACE"])
        return false
    end

    local routeLike = FindRouteLikeTable(importData)
    if routeLike then return addon:TryImportMDTRoute(importPayload, dungeonFilter) end

    if IsKeystoneImportPayload(importData) then
        return ImportKeystoneData(addon, importData, sectionName, dungeonFilter)
    end

    -- Fallback: try MDT route import
    return addon:TryImportMDTRoute(importPayload, dungeonFilter)
end

-- Global function to create import dialog
function KeystonePolaris:ShowImportDialog(sectionName, dungeonFilter)
    local addon = self
    local dialogText

    if not sectionName then
        dialogText = L["IMPORT_ALL_DIALOG_TEXT"]
    else
        dialogText = (L["IMPORT_SECTION_DIALOG_TEXT"]):format(sectionName)
    end
    dialogText = string.format("%s\n|cff999999%s|r", dialogText, L["IMPORT_DIALOG_INFO"])

    StaticPopupDialogs["KPL_IMPORT_DIALOG"] = {
        text = dialogText,
        button1 = OKAY,
        button2 = CANCEL,
        hasEditBox = true,
        editBoxWidth = 350,
        maxLetters = 999999,
        OnAccept = function(dialog)
            local importString = dialog.EditBox:GetText()
            addon:ImportDungeonSettings(importString, sectionName, dungeonFilter)
        end,
        EditBoxOnEscapePressed = function(editBox)
            editBox:GetParent():Hide()
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true
    }
    StaticPopup_Show("KPL_IMPORT_DIALOG")
end

-- ---------------------------------------------------------------------------
-- Profile export / import (shareable strings)
-- ---------------------------------------------------------------------------

local PROFILE_EXPORT_SCHEMA = 1

local EXCLUDED_GENERAL_KEYS = {
    lastSeasonCheck = true,
    lastVersionCheck = true,
    mobPercentagesMigrationVersion = true,
}

local EXCLUDED_GROUP_REMINDER_KEYS = {
    lastReminder = true,
}

local function DeepCloneTable(tbl, excludeKeys)
    if type(tbl) ~= "table" then return tbl end
    local out = {}
    for k, v in pairs(tbl) do
        if not (excludeKeys and excludeKeys[k]) then
            if type(v) == "table" then
                out[k] = DeepCloneTable(v, nil)
            else
                out[k] = v
            end
        end
    end
    return out
end

local function StripExportPrefix(payload)
    if type(payload) ~= "string" then return payload end
    payload = payload:match("^%s*(.-)%s*$")
    if payload:sub(1, #EXPORT_PREFIX) == EXPORT_PREFIX then
        return payload:sub(#EXPORT_PREFIX + 1)
    end
    return payload
end

local function EncodeExportPayload(exportData)
    local serialized = LibStub("AceSerializer-3.0"):Serialize(exportData)
    local compressed = LibStub("LibDeflate"):CompressDeflate(serialized)
    local encoded = LibStub("LibDeflate"):EncodeForPrint(compressed)
    return EXPORT_PREFIX .. encoded
end

IsProfileImportPayload = function(importData)
    return type(importData) == "table"
        and importData.type == "profile"
        and type(importData.data) == "table"
        and importData.schemaVersion ~= nil
end

local function DefaultImportProfileName(sourceName)
    local dateStr = date("%Y-%m-%d")
    if sourceName and sourceName ~= "" then
        return sourceName .. " (" .. dateStr .. ")"
    end
    return "Import " .. dateStr
end

local function GetProfileScopeLabel(scope)
    if scope == "full" then
        return L["PROFILE_SCOPE_FULL"]
    end
    return L["PROFILE_SCOPE_SETTINGS"]
end

function KeystonePolaris:BuildProfileSnapshot(scope)
    local profile = self.db and self.db.profile
    if not profile then return nil end

    local data = {}
    if profile.general then
        data.general = DeepCloneTable(profile.general, EXCLUDED_GENERAL_KEYS)
    end
    if profile.text then
        data.text = DeepCloneTable(profile.text, nil)
    end
    if profile.color then
        data.color = DeepCloneTable(profile.color, nil)
    end
    if profile.progressBar then
        data.progressBar = DeepCloneTable(profile.progressBar, nil)
    end
    if profile.groupReminder then
        data.groupReminder = DeepCloneTable(profile.groupReminder, EXCLUDED_GROUP_REMINDER_KEYS)
    end
    if profile.mobPercentages then
        data.mobPercentages = DeepCloneTable(profile.mobPercentages, nil)
    end
    if scope == "full" and profile.advanced then
        data.advanced = DeepCloneTable(profile.advanced, nil)
    end
    return data
end

function KeystonePolaris:ApplyProfileSnapshot(targetName, importPayload, switchAfter)
    local db = self.db
    if not db or not importPayload or type(importPayload.data) ~= "table" then
        return false
    end

    local data = importPayload.data
    local scope = importPayload.scope
    local defaults = db.defaults and db.defaults.profile

    if not db.profiles[targetName] then
        db.profiles[targetName] = defaults and DeepCloneTable(defaults, nil) or {}
    end

    local target = db.profiles[targetName]

    if data.general then target.general = DeepCloneTable(data.general, nil) end
    if data.text then target.text = DeepCloneTable(data.text, nil) end
    if data.color then target.color = DeepCloneTable(data.color, nil) end
    if data.progressBar then target.progressBar = DeepCloneTable(data.progressBar, nil) end
    if data.groupReminder then target.groupReminder = DeepCloneTable(data.groupReminder, nil) end
    if data.mobPercentages then target.mobPercentages = DeepCloneTable(data.mobPercentages, nil) end
    if scope == "full" and data.advanced then
        target.advanced = DeepCloneTable(data.advanced, nil)
    end

    local currentProfile = db:GetCurrentProfile()
    if switchAfter then
        db:SetProfile(targetName)
    end

    if switchAfter or targetName == currentProfile then
        self:RefreshForActiveProfile()
    end

    return true
end

function KeystonePolaris:ExportProfileSettings(scope)
    local exportData = {
        type = "profile",
        scope = scope,
        schemaVersion = PROFILE_EXPORT_SCHEMA,
        profileName = self.db:GetCurrentProfile(),
        data = self:BuildProfileSnapshot(scope),
    }
    local exportString = EncodeExportPayload(exportData)

    local dialogText = (scope == "full") and L["EXPORT_PROFILE_FULL_DIALOG_TEXT"]
        or L["EXPORT_PROFILE_SETTINGS_DIALOG_TEXT"]

    StaticPopupDialogs["KPL_EXPORT_PROFILE_DIALOG"] = {
        text = dialogText,
        button1 = OKAY,
        hasEditBox = true,
        editBoxWidth = 350,
        maxLetters = 999999,
        OnShow = function(dialog)
            dialog.EditBox:SetText(exportString)
            dialog.EditBox:HighlightText()
            dialog.EditBox:SetFocus()
        end,
        EditBoxOnEscapePressed = function(editBox)
            editBox:GetParent():Hide()
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
    }
    StaticPopup_Show("KPL_EXPORT_PROFILE_DIALOG")
end

function KeystonePolaris:ShowProfileImportConfirmDialog(importPayload)
    local addon = self
    local currentProfile = self.db:GetCurrentProfile()
    local scopeLabel = GetProfileScopeLabel(importPayload.scope)
    local defaultName = DefaultImportProfileName(importPayload.profileName)
    local targetExists = self.db.profiles[defaultName] ~= nil

    local warning = ""
    if targetExists then
        warning = "\n\n" .. (L["IMPORT_PROFILE_EXISTS"]):format(defaultName)
    end

    local text = (L["IMPORT_PROFILE_CONFIRM_TEXT"]):format(
        scopeLabel,
        defaultName,
        currentProfile or "Default"
    ) .. warning

    StaticPopupDialogs["KPL_IMPORT_PROFILE_CONFIRM"] = {
        text = text,
        button1 = L["IMPORT_PROFILE_ACTIVATE"],
        button2 = L["IMPORT_PROFILE_ONLY"],
        button3 = CANCEL,
        hasEditBox = true,
        editBoxWidth = 220,
        maxLetters = 64,
        OnShow = function(dialog)
            dialog.EditBox:SetText(defaultName)
            dialog.EditBox:HighlightText()
            dialog.EditBox:SetFocus()
        end,
        OnAccept = function(dialog)
            local targetName = dialog.EditBox:GetText():match("^%s*(.-)%s*$")
            if targetName == "" then
                targetName = defaultName
            end
            addon:ApplyProfileSnapshot(targetName, importPayload, true)
            local prefix = (addon.GetChatPrefix and addon:GetChatPrefix()) or "Keystone Polaris"
            print(prefix .. ": " .. (L["IMPORT_PROFILE_SUCCESS"]):format(targetName))
        end,
        OnButton2 = function(dialog)
            local targetName = dialog.EditBox:GetText():match("^%s*(.-)%s*$")
            if targetName == "" then
                targetName = defaultName
            end
            addon:ApplyProfileSnapshot(targetName, importPayload, false)
            local prefix = (addon.GetChatPrefix and addon:GetChatPrefix()) or "Keystone Polaris"
            print(prefix .. ": " .. (L["IMPORT_PROFILE_SUCCESS"]):format(targetName))
        end,
        EditBoxOnEscapePressed = function(editBox)
            editBox:GetParent():Hide()
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
    }
    StaticPopup_Show("KPL_IMPORT_PROFILE_CONFIRM")
end

function KeystonePolaris:ImportProfileSettings(importString)
    local prefix = (self.GetChatPrefix and self:GetChatPrefix()) or "Keystone Polaris"
    local importPayload = StripExportPrefix(importString)
    local importData = DecodeSerializedPayload(importPayload)

    if not IsProfileImportPayload(importData) then
        print(prefix .. ": " .. L["IMPORT_PROFILE_ERROR"])
        return false
    end

    if importData.schemaVersion ~= PROFILE_EXPORT_SCHEMA then
        print(prefix .. ": " .. L["IMPORT_PROFILE_UNKNOWN_VERSION"])
        return false
    end

    if importData.scope ~= "full" and importData.scope ~= "settings" then
        print(prefix .. ": " .. L["IMPORT_PROFILE_ERROR"])
        return false
    end

    self:ShowProfileImportConfirmDialog(importData)
    return true
end

function KeystonePolaris:ShowProfileImportDialog()
    local addon = self

    StaticPopupDialogs["KPL_IMPORT_PROFILE_DIALOG"] = {
        text = L["IMPORT_PROFILE_DIALOG_TEXT"],
        button1 = OKAY,
        button2 = CANCEL,
        hasEditBox = true,
        editBoxWidth = 350,
        maxLetters = 999999,
        OnAccept = function(dialog)
            local importString = dialog.EditBox:GetText()
            addon:ImportProfileSettings(importString)
        end,
        EditBoxOnEscapePressed = function(editBox)
            editBox:GetParent():Hide()
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
    }
    StaticPopup_Show("KPL_IMPORT_PROFILE_DIALOG")
end
