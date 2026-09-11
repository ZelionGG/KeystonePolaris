local AddOnName, KeystonePolaris = ...
local L = LibStub("AceLocale-3.0"):GetLocale(AddOnName)
local _G = _G

local PREFIX = "KPL_ROUTE"
local MSG_HELLO = "H"
local MSG_HERE = "R"
local MSG_SHARE = "S"
local MSG_CHUNK = "C"
local MSG_FOLLOWED = "F"
local PAYLOAD_VERSION = 1
local SHARE_COOLDOWN = 25
local SHARE_CHUNK_SIZE = 180
local PENDING_SHARE_TTL = 15 * 60
local DIFFICULTY_MYTHIC = 23
local DIFFICULTY_MYTHIC_KEYSTONE = 8

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

local function ChatPrint(self, message)
    local prefix = (self.GetChatPrefix and self:GetChatPrefix()) or "Keystone Polaris"
    local text = prefix .. " " .. tostring(message or "")
    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        DEFAULT_CHAT_FRAME:AddMessage(text)
    else
        print(text)
    end
end

local function IsLiveRouteEnabled(self)
    return self.db and self.db.profile and self.db.profile.liveRoute
        and self.db.profile.liveRoute.enabled ~= false
end

local function IsMythicOrKeystoneDifficulty(difficultyID)
    if type(difficultyID) ~= "number" then return false end
    local ids = _G.DifficultyUtil and _G.DifficultyUtil.ID
    if type(ids) == "table" then
        if difficultyID == ids.DungeonMythic or difficultyID == ids.DungeonChallenge then
            return true
        end
    end
    if difficultyID == DIFFICULTY_MYTHIC or difficultyID == DIFFICULTY_MYTHIC_KEYSTONE then
        return true
    end
    if GetDifficultyInfo then
        local _, groupType, _, isChallengeMode, _, displayMythic = GetDifficultyInfo(difficultyID)
        if groupType == "party" and (isChallengeMode or displayMythic) then
            return true
        end
    end
    return false
end

local function GetSessionInfo()
    local instanceName, instanceType, difficultyID, _, _, _, _, instanceID, _, lfgDungeonID = GetInstanceInfo()
    return instanceType, difficultyID, instanceID, instanceName, lfgDungeonID
end

function KeystonePolaris:GetLiveRouteDungeonKey()
    local uiMapID = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player") or nil
    if C_ChallengeMode and C_ChallengeMode.GetActiveChallengeMapID then
        local challengeMapID = C_ChallengeMode.GetActiveChallengeMapID()
        if challengeMapID then
            local dungeonKey = self.GetDungeonKeyById and self:GetDungeonKeyById(challengeMapID) or nil
            if dungeonKey then return dungeonKey, challengeMapID, uiMapID end
        end
    end

    local _, _, instanceID, instanceName, lfgDungeonID = GetSessionInfo()
    if self.GlobalDungeonLookup then
        for dungeonKey, dungeonData in pairs(self.GlobalDungeonLookup) do
            if type(dungeonData) == "table" then
                -- dungeonData.mapID is the instance map ID (GetInstanceInfo 8th), not always a uiMap.
                if instanceID and dungeonData.mapID == instanceID then
                    return dungeonKey, dungeonData.id, uiMapID
                end
                if lfgDungeonID and dungeonData.lfgID == lfgDungeonID then
                    return dungeonKey, dungeonData.id, uiMapID
                end
            end
        end

        if type(instanceName) == "string" and instanceName ~= ""
            and C_ChallengeMode and C_ChallengeMode.GetMapUIInfo then
            for dungeonKey, dungeonData in pairs(self.GlobalDungeonLookup) do
                if type(dungeonData) == "table" and dungeonData.id then
                    local cmName = C_ChallengeMode.GetMapUIInfo(dungeonData.id)
                    if cmName == instanceName then
                        return dungeonKey, dungeonData.id, uiMapID
                    end
                end
            end
        end
    end

    if not (C_Map and C_Map.GetMapInfo) then return nil end
    local mapID = uiMapID
    while mapID do
        if self.GlobalDungeonLookup then
            for dungeonKey, dungeonData in pairs(self.GlobalDungeonLookup) do
                if dungeonData and dungeonData.mapID == mapID then
                    return dungeonKey, dungeonData.id, uiMapID
                end
            end
        end
        local mapInfo = C_Map.GetMapInfo(mapID)
        mapID = mapInfo and mapInfo.parentMapID or nil
    end
    return nil
end

function KeystonePolaris:IsInLiveRouteContext()
    if not IsInInstance() then return false end
    local instanceType, difficultyID = GetSessionInfo()
    if instanceType ~= "party" then return false end
    if not IsMythicOrKeystoneDifficulty(difficultyID) then return false end
    local dungeonKey = self:GetLiveRouteDungeonKey()
    return dungeonKey ~= nil
end

local function IsInLiveRoutePresenceRange()
    if not IsInGroup() then return false end
    if not IsInInstance() then return false end
    local instanceType, difficultyID = GetSessionInfo()
    return instanceType == "party" and IsMythicOrKeystoneDifficulty(difficultyID)
end

-- Midnight: only InChatMessagingLockdown blocks SendAddonMessage (active M+ / encounter).
-- AreOutgoingAddonChatMessagesRestricted is a broader chat-secret flag and is not a send veto.
local function IsLiveRouteCommLocked()
    if not (C_ChatInfo and C_ChatInfo.InChatMessagingLockdown) then
        return false
    end
    local restricted = C_ChatInfo.InChatMessagingLockdown()
    return restricted and true or false
end

local function IsLiveRouteKeystoneActive()
    if C_ChallengeMode then
        if C_ChallengeMode.IsChallengeModeActive and C_ChallengeMode.IsChallengeModeActive() then
            return true
        end
        if C_ChallengeMode.GetActiveChallengeMapID and C_ChallengeMode.GetActiveChallengeMapID() then
            return true
        end
    end
    if IsLiveRouteCommLocked() then return true end
    local _, difficultyID = GetSessionInfo()
    if difficultyID == DIFFICULTY_MYTHIC_KEYSTONE then return true end
    local ids = _G.DifficultyUtil and _G.DifficultyUtil.ID
    if type(ids) == "table" and difficultyID == ids.DungeonChallenge then
        return true
    end
    return false
end

local function SendResultIsLockdown(result)
    local codes = Enum and Enum.SendAddonMessageResult
    if type(codes) == "table" and codes.AddOnMessageLockdown ~= nil then
        return result == codes.AddOnMessageLockdown
    end
    return result == 11
end

local function SendResultIsSuccess(result)
    if result == nil or result == true then return true end
    if result == false then return false end
    local codes = Enum and Enum.SendAddonMessageResult
    if type(codes) == "table" and codes.Success ~= nil then
        return result == codes.Success
    end
    return result == 0
end

local function NormalizeName(name)
    if type(name) ~= "string" or name == "" then return nil end
    return Ambiguate(name, "none")
end

local function PlayerFullName()
    return NormalizeName(GetUnitName("player", true) or UnitName("player"))
end

local function IsSelfSender(sender)
    local selfName = PlayerFullName()
    local other = NormalizeName(sender)
    if not selfName or not other then return false end
    if Ambiguate(selfName, "none") == Ambiguate(other, "none") then return true end
    return Ambiguate(selfName, "short") == Ambiguate(other, "short")
end

local function UnitTokenForName(name)
    local target = NormalizeName(name)
    if not target then return nil end

    local function matches(unit)
        if not UnitExists(unit) then return false end
        local unitName = NormalizeName(GetUnitName(unit, true) or UnitName(unit))
        if not unitName then return false end
        return Ambiguate(unitName, "none") == Ambiguate(target, "none")
            or Ambiguate(unitName, "short") == Ambiguate(target, "short")
    end

    if matches("player") then return "player" end
    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do
            if matches("raid" .. i) then return "raid" .. i end
        end
    elseif IsInGroup() then
        for i = 1, 4 do
            if matches("party" .. i) then return "party" .. i end
        end
    end
    return nil
end

local function IsSenderTrusted(sender)
    local unit = UnitTokenForName(sender)
    if not unit then return false end
    if UnitIsGroupLeader(unit) then return true end
    return UnitGroupRolesAssigned(unit) == "TANK"
end

local function DisplayNameForSender(sender)
    return Ambiguate(sender or "", "short")
end

local function DungeonDisplayName(self, dungeonKey)
    local dungeonData = self.GlobalDungeonLookup and self.GlobalDungeonLookup[dungeonKey]
    return (dungeonData and dungeonData.displayName) or dungeonKey or "?"
end

local function BossKey(index)
    return "Boss" .. KeystonePolaris:GetBossNumberString(index)
end

local function EscapeField(value)
    local text = tostring(value or "")
    text = text:gsub("[|\n\r\t^;/]", " ")
    return text
end

local function EncodePayload(tbl)
    if type(tbl) ~= "table" or type(tbl.dungeonKey) ~= "string" then return nil end
    local bossCount = tonumber(tbl.bossCount) or 0
    if bossCount < 1 then return nil end

    local bossBits = {}
    for i = 1, bossCount do
        local key = BossKey(i)
        bossBits[i] = string.format("%s:%s", tostring(tbl[key] or 0), tbl[key .. "Inform"] and "1" or "0")
    end

    local orderBits = {}
    if type(tbl.bossOrder) == "table" then
        for i = 1, bossCount do
            orderBits[i] = tostring(tbl.bossOrder[i] or i)
        end
    end

    local milestoneLines = {}
    if type(tbl.milestones) == "table" then
        for _, milestone in ipairs(tbl.milestones) do
            if type(milestone) == "table" then
                milestoneLines[#milestoneLines + 1] = table.concat({
                    tostring(milestone.id or ""),
                    EscapeField(milestone.label),
                    tostring(tonumber(milestone.thresholdPercent) or 0),
                    EscapeField(milestone.triggerType),
                    tostring(milestone.matchAreaID or ""),
                    tostring(milestone.matchMapID or ""),
                    EscapeField(milestone.matchText),
                    milestone.inform and "1" or "0",
                    EscapeField(milestone.informSuffix),
                    tostring(milestone.creationOrder or ""),
                }, "/")
            end
        end
    end

    -- Single printable line: addon messages are truncated at newlines.
    return table.concat({
        tostring(PAYLOAD_VERSION),
        tbl.dungeonKey,
        tostring(bossCount),
        table.concat(bossBits, ";"),
        table.concat(orderBits, ","),
        tostring(#milestoneLines),
        table.concat(milestoneLines, "^"),
    }, "|")
end

local function DecodePayload(encoded)
    if type(encoded) ~= "string" or encoded == "" then return nil end
    encoded = encoded:gsub("[\n\r]", "")
    local parts = { strsplit("|", encoded) }
    if tonumber(parts[1]) ~= PAYLOAD_VERSION then return nil end
    local dungeonKey = parts[2]
    local bossCount = tonumber(parts[3]) or 0
    if type(dungeonKey) ~= "string" or dungeonKey == "" or bossCount < 1 then return nil end

    local payload = {
        v = PAYLOAD_VERSION,
        dungeonKey = dungeonKey,
        bossCount = bossCount,
        milestones = {},
    }

    local bossBits = { strsplit(";", parts[4] or "") }
    for i = 1, bossCount do
        local key = BossKey(i)
        local pct, inform = strsplit(":", bossBits[i] or "")
        payload[key] = tonumber(pct) or 0
        payload[key .. "Inform"] = inform == "1"
    end

    local orderBits = { strsplit(",", parts[5] or "") }
    if orderBits[1] and orderBits[1] ~= "" then
        local bossOrder = {}
        for i = 1, bossCount do
            bossOrder[i] = tonumber(orderBits[i]) or i
        end
        payload.bossOrder = bossOrder
    end

    local milestoneCount = tonumber(parts[6]) or 0
    local milestoneBlob = parts[7] or ""
    if milestoneCount > 0 and milestoneBlob ~= "" then
        local milestoneLines = { strsplit("^", milestoneBlob) }
        for i = 1, milestoneCount do
            local line = milestoneLines[i]
            if type(line) == "string" and line ~= "" then
                local id, label, threshold, triggerType, matchAreaID, matchMapID, matchText, inform, informSuffix, creationOrder = strsplit("/", line)
                payload.milestones[#payload.milestones + 1] = {
                    id = tonumber(id) or id,
                    label = label,
                    thresholdPercent = tonumber(threshold) or 0,
                    triggerType = triggerType,
                    matchAreaID = tonumber(matchAreaID),
                    matchMapID = tonumber(matchMapID),
                    matchText = matchText,
                    inform = inform == "1",
                    informSuffix = informSuffix,
                    creationOrder = tonumber(creationOrder),
                }
            end
        end
    end

    return payload
end

local function ValidateBossOrder(order, numBosses)
    if type(order) ~= "table" or numBosses < 1 then return false end
    local seen = {}
    for i = 1, numBosses do
        local idx = tonumber(order[i])
        if not idx then return false end
        idx = math.floor(idx)
        if idx < 1 or idx > numBosses or seen[idx] then return false end
        seen[idx] = true
    end
    return true
end

local function SanitizeMilestones(milestones)
    if type(milestones) ~= "table" then return {} end
    local out = {}
    for _, milestone in ipairs(milestones) do
        if type(milestone) == "table" then
            out[#out + 1] = {
                id = milestone.id,
                label = milestone.label,
                thresholdPercent = tonumber(milestone.thresholdPercent) or 0,
                triggerType = milestone.triggerType,
                matchAreaID = tonumber(milestone.matchAreaID),
                matchMapID = tonumber(milestone.matchMapID),
                matchText = milestone.matchText,
                inform = milestone.inform == true,
                informSuffix = milestone.informSuffix,
                creationOrder = tonumber(milestone.creationOrder),
            }
        end
    end
    return out
end

function KeystonePolaris:BuildLocalLiveRoutePayload(dungeonKey)
    local dungeonData = self.GlobalDungeonLookup and self.GlobalDungeonLookup[dungeonKey]
    if not dungeonData or type(dungeonData.bosses) ~= "table" then return nil end

    local numBosses = #dungeonData.bosses
    local payload = {
        v = PAYLOAD_VERSION,
        dungeonKey = dungeonKey,
        bossCount = numBosses,
    }
    local defaultsOrder = {}
    for i, bossData in ipairs(dungeonData.bosses) do
        local bossKey = "Boss" .. self:GetBossNumberString(i)
        payload[bossKey] = bossData[2]
        payload[bossKey .. "Inform"] = bossData[3] and true or false
        local rank = bossData[4]
        if type(rank) == "number" then
            defaultsOrder[math.floor(rank)] = i
        else
            defaultsOrder[i] = i
        end
    end
    if ValidateBossOrder(defaultsOrder, numBosses) then
        payload.bossOrder = defaultsOrder
    end
    payload.milestones = SanitizeMilestones(dungeonData.milestones)

    local advanced = self.db and self.db.profile and self.db.profile.advanced and self.db.profile.advanced[dungeonKey]
    if type(advanced) == "table" then
        for i = 1, numBosses do
            local bossKey = "Boss" .. self:GetBossNumberString(i)
            if advanced[bossKey] ~= nil then
                payload[bossKey] = advanced[bossKey]
            end
            local informKey = bossKey .. "Inform"
            if advanced[informKey] ~= nil then
                payload[informKey] = advanced[informKey] and true or false
            end
        end
        if ValidateBossOrder(advanced.bossOrder, numBosses) then
            payload.bossOrder = CopyTable(advanced.bossOrder)
        end
        if type(advanced.milestones) == "table" then
            payload.milestones = SanitizeMilestones(advanced.milestones)
        end
    end

    return payload
end

function KeystonePolaris:SanitizeLiveRoutePayload(payload)
    if type(payload) ~= "table" then return nil end
    if tonumber(payload.v) ~= PAYLOAD_VERSION then return nil end
    local dungeonKey = payload.dungeonKey
    if type(dungeonKey) ~= "string" or dungeonKey == "" then return nil end
    local dungeonData = self.GlobalDungeonLookup and self.GlobalDungeonLookup[dungeonKey]
    if not dungeonData or type(dungeonData.bosses) ~= "table" then return nil end

    local clean = {
        v = PAYLOAD_VERSION,
        dungeonKey = dungeonKey,
        milestones = SanitizeMilestones(payload.milestones),
    }
    local numBosses = #dungeonData.bosses
    for i = 1, numBosses do
        local bossKey = "Boss" .. self:GetBossNumberString(i)
        local pct = tonumber(payload[bossKey])
        if not pct then
            pct = dungeonData.bosses[i] and dungeonData.bosses[i][2] or 0
        end
        clean[bossKey] = pct
        clean[bossKey .. "Inform"] = payload[bossKey .. "Inform"] and true or false
    end
    if ValidateBossOrder(payload.bossOrder, numBosses) then
        local bossOrder = {}
        for i = 1, numBosses do
            bossOrder[i] = math.floor(tonumber(payload.bossOrder[i]))
        end
        clean.bossOrder = bossOrder
    end
    return clean
end

function KeystonePolaris:GetLiveRoutePayload(dungeonKey)
    if not IsLiveRouteEnabled(self) then return nil end
    local live = self._liveRoute
    if type(live) ~= "table" or type(live.payload) ~= "table" then return nil end
    if dungeonKey and live.dungeonKey ~= dungeonKey then return nil end
    return live.payload
end

function KeystonePolaris:IsFollowingLiveRoute()
    return type(self._liveRoute) == "table" and type(self._liveRoute.payload) == "table"
end

-- ---------------------------------------------------------------------------
-- Presence
-- ---------------------------------------------------------------------------

local function EnsurePeers(self)
    if type(self._liveRoutePeers) ~= "table" then
        self._liveRoutePeers = {}
    end
    return self._liveRoutePeers
end

local function RememberPeer(self, sender)
    if not sender or IsSelfSender(sender) then return end
    local name = NormalizeName(sender)
    if name then
        EnsurePeers(self)[name] = true
    end
end

local function ClearPendingLiveRoute(self)
    self._pendingLiveShare = nil
    if self.db and self.db.char then
        self.db.char.pendingLiveRoute = false
    end
end

local function GetPendingLiveRoute(self)
    local pending = self._pendingLiveShare
    if type(pending) ~= "table" then
        pending = self.db and self.db.char and self.db.char.pendingLiveRoute
        if type(pending) ~= "table" then return nil end
        self._pendingLiveShare = pending
    end
    if type(pending.receivedAt) == "number" and (time() - pending.receivedAt) > PENDING_SHARE_TTL then
        ClearPendingLiveRoute(self)
        return nil
    end
    if type(pending.payload) ~= "table" or not pending.sender then
        ClearPendingLiveRoute(self)
        return nil
    end
    return pending
end

local function StorePendingLiveRoute(self, sender, payload)
    local pending = {
        sender = NormalizeName(sender) or sender,
        payload = CopyTable(payload),
        receivedAt = time(),
    }
    local previous = GetPendingLiveRoute(self)
    local same = type(previous) == "table"
        and previous.sender == pending.sender
        and type(previous.payload) == "table"
        and previous.payload.dungeonKey == payload.dungeonKey
    self._pendingLiveShare = pending
    if self.db and self.db.char then
        self.db.char.pendingLiveRoute = CopyTable(pending)
    end
    if same then return end
    ChatPrint(self, (L["KPL_LR_QUEUED"] or "Queued %s's route for %s. You'll be asked when you enter the dungeon."):format(
        DisplayNameForSender(pending.sender),
        DungeonDisplayName(self, payload.dungeonKey)
    ))
end

local function ConsumePendingLiveRoute(self)
    if not self:IsInLiveRouteContext() then return end
    local pending = GetPendingLiveRoute(self)
    if not pending then return end
    local dungeonKey = self:GetLiveRouteDungeonKey()
    if dungeonKey and pending.payload.dungeonKey ~= dungeonKey then return end
    local sender, payload = pending.sender, pending.payload
    ClearPendingLiveRoute(self)
    if self.HandleIncomingLiveRoute then
        self:HandleIncomingLiveRoute(sender, payload)
    end
end

local function PrunePeers(self)
    local peers = EnsurePeers(self)
    if not IsInGroup() then
        wipe(peers)
        ClearPendingLiveRoute(self)
        return
    end

    local members = {}
    local sawOther = false
    for i = 1, 4 do
        local unit = "party" .. i
        if UnitExists(unit) then
            sawOther = true
            local unitName = GetUnitName(unit, true) or UnitName(unit)
            if unitName then
                members[Ambiguate(unitName, "none")] = true
                members[Ambiguate(unitName, "short")] = true
            end
        end
    end
    if not sawOther then
        return
    end

    for name in pairs(peers) do
        if IsSelfSender(name) then
            peers[name] = nil
        elseif not members[Ambiguate(name, "none")] and not members[Ambiguate(name, "short")] then
            if not UnitTokenForName(name) then
                peers[name] = nil
            end
        end
    end
end

function KeystonePolaris:GetLiveRoutePeerNames()
    PrunePeers(self)
    local names = {}
    for name in pairs(EnsurePeers(self)) do
        names[#names + 1] = DisplayNameForSender(name)
    end
    table.sort(names)
    return names
end

function KeystonePolaris:HasLiveRoutePeers()
    return #self:GetLiveRoutePeerNames() > 0
end

local function SendLiveRouteMessage(self, text, prio, onResult)
    if not self.SendCommMessage then
        if onResult then onResult(nil, false) end
        return
    end
    if not IsInGroup() then
        if onResult then onResult(nil, false) end
        return
    end
    if IsLiveRouteCommLocked() then
        if onResult then onResult(nil, false) end
        return
    end
    self:SendCommMessage(PREFIX, text, "PARTY", nil, prio or "NORMAL", function(_, _, _, sendResult)
        if onResult then onResult(sendResult, true) end
    end)
end

local function SendSharePayload(self, encoded, onResult)
    if #encoded + 1 <= SHARE_CHUNK_SIZE then
        SendLiveRouteMessage(self, MSG_SHARE .. encoded, "NORMAL", onResult)
        return
    end

    local total = math.ceil(#encoded / SHARE_CHUNK_SIZE)
    local token = string.format("%d", math.floor(GetTime() * 1000))
    for i = 1, total do
        local startIndex = (i - 1) * SHARE_CHUNK_SIZE + 1
        local piece = encoded:sub(startIndex, startIndex + SHARE_CHUNK_SIZE - 1)
        local isLast = i == total
        SendLiveRouteMessage(
            self,
            string.format("%s%s:%d:%d:%s", MSG_CHUNK, token, i, total, piece),
            "NORMAL",
            isLast and onResult or nil
        )
    end
end

function KeystonePolaris:PingLiveRoutePresence()
    if not IsLiveRouteEnabled(self) then return end
    if not IsInLiveRoutePresenceRange() then return end
    if IsLiveRouteCommLocked() or IsLiveRouteKeystoneActive() then return end
    SendLiveRouteMessage(self, MSG_HELLO, "BULK")
end

local function QueueLiveRoutePings(self)
    if IsLiveRouteKeystoneActive() then return end
    self:PingLiveRoutePresence()
    if self._liveRoutePingQueued then return end
    self._liveRoutePingQueued = true
    C_Timer.After(1, function()
        if self.PingLiveRoutePresence then self:PingLiveRoutePresence() end
    end)
    C_Timer.After(3, function()
        self._liveRoutePingQueued = false
        if self.PingLiveRoutePresence then self:PingLiveRoutePresence() end
    end)
end

local function ReplyLiveRouteHere(self)
    if not IsLiveRouteEnabled(self) then return end
    SendLiveRouteMessage(self, MSG_HERE, "BULK")
end

-- ---------------------------------------------------------------------------
-- Overlay persist / apply
-- ---------------------------------------------------------------------------

local function CurrentSessionKeys(self)
    local dungeonKey, challengeMapID, uiMapID = self:GetLiveRouteDungeonKey()
    local _, _, instanceID = GetSessionInfo()
    return dungeonKey, challengeMapID, uiMapID or (C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")), instanceID
end

local function SessionMatchesStored(self, stored)
    if type(stored) ~= "table" then return false end
    if not self:IsInLiveRouteContext() then return false end
    local dungeonKey, challengeMapID, uiMapID, instanceID = CurrentSessionKeys(self)
    if stored.dungeonKey ~= dungeonKey then return false end
    if stored.instanceID and instanceID and stored.instanceID ~= instanceID then return false end
    if stored.challengeMapID and challengeMapID and stored.challengeMapID ~= challengeMapID then return false end
    if stored.uiMapID and uiMapID and stored.uiMapID ~= uiMapID and not stored.challengeMapID then
        -- Different floor of the same dungeon still matches via dungeonKey + instanceID.
        if stored.instanceID and instanceID and stored.instanceID == instanceID then
            return true
        end
        return false
    end
    return true
end

function KeystonePolaris:WipeLiveRouteOverlay()
    local dungeonKey = self._liveRoute and self._liveRoute.dungeonKey
    self._liveRoute = nil
    if self.db and self.db.char then
        self.db.char.liveRoute = false
    end
    self._liveRouteButtonDismissed = false
    if dungeonKey and self.RestoreDungeonDataFromProfile then
        self:RestoreDungeonDataFromProfile(dungeonKey)
    end
    if self.UpdateDungeonData then self:UpdateDungeonData() end
    if self.currentDungeonID and self.BuildSectionOrder then
        self:BuildSectionOrder(self.currentDungeonID)
    end
    if self.UpdatePercentageText then self:UpdatePercentageText() end
    if self.RefreshProgressBar then self:RefreshProgressBar() end
    if self.UpdateLiveRouteShareButton then self:UpdateLiveRouteShareButton() end
end

function KeystonePolaris:ApplyLiveRouteOverlay(sender, payload, session)
    payload = self:SanitizeLiveRoutePayload(payload)
    if not payload then return false end

    local dungeonKey, challengeMapID, uiMapID, instanceID = CurrentSessionKeys(self)
    session = session or {}
    local live = {
        sender = NormalizeName(sender) or sender,
        dungeonKey = payload.dungeonKey,
        payload = payload,
        instanceID = session.instanceID or instanceID,
        challengeMapID = session.challengeMapID or challengeMapID,
        uiMapID = session.uiMapID or uiMapID,
    }
    if dungeonKey and live.dungeonKey ~= dungeonKey then
        return false
    end

    self._liveRoute = live
    if self.db and self.db.char then
        self.db.char.liveRoute = CopyTable(live)
    end

    if self.UpdateDungeonData then self:UpdateDungeonData() end
    local dungeonId = self.GetDungeonIdByKey and self:GetDungeonIdByKey(live.dungeonKey) or nil
    if dungeonId and self.ResetMilestoneRuntimeState then
        self:ResetMilestoneRuntimeState(dungeonId)
    end
    if self.currentDungeonID and self.BuildSectionOrder then
        self:BuildSectionOrder(self.currentDungeonID)
    elseif dungeonId and self.BuildSectionOrder then
        self:BuildSectionOrder(dungeonId)
    end
    if self.UpdatePercentageText then self:UpdatePercentageText() end
    if self.RefreshProgressBar then self:RefreshProgressBar() end
    if self.HideLiveRouteShareButton then self:HideLiveRouteShareButton(true) end
    return true
end

function KeystonePolaris:RestoreLiveRouteOverlay()
    if not IsLiveRouteEnabled(self) then return end
    local stored = self.db and self.db.char and self.db.char.liveRoute
    if type(stored) ~= "table" then
        self._liveRoute = nil
        return
    end
    if not SessionMatchesStored(self, stored) then
        self:WipeLiveRouteOverlay()
        return
    end
    local payload = self:SanitizeLiveRoutePayload(stored.payload)
    if not payload then
        self:WipeLiveRouteOverlay()
        return
    end
    self._liveRoute = {
        sender = stored.sender,
        dungeonKey = stored.dungeonKey,
        payload = payload,
        instanceID = stored.instanceID,
        challengeMapID = stored.challengeMapID,
        uiMapID = stored.uiMapID,
    }
    if self.UpdateDungeonData then self:UpdateDungeonData() end
    if self.currentDungeonID and self.BuildSectionOrder then
        self:BuildSectionOrder(self.currentDungeonID)
    end
end

function KeystonePolaris:UnfollowLiveRoute(source)
    if not self:IsFollowingLiveRoute() then
        if source == "slash" then
            ChatPrint(self, L["KPL_LR_NOT_FOLLOWING"] or "You are not following a shared route.")
        end
        return
    end
    self:WipeLiveRouteOverlay()
    ChatPrint(self, L["KPL_LR_UNFOLLOWED"] or "Stopped following the shared route.")
end

local function FollowedChatMessage(self, sender)
    local senderText = DisplayNameForSender(sender)
    local linkText = "|cffdb6233[" .. (L["KPL_LR_UNFOLLOW"] or "Unfollow") .. "]|r"
    local link = "|Hkplunfollow:1|h" .. linkText .. "|h"
    local body = (L["KPL_LR_FOLLOWING"] or "Following %s's route. %s"):format(senderText, link)
    ChatPrint(self, body)
    local owner = NormalizeName(sender)
    if owner and not IsSelfSender(owner) then
        SendLiveRouteMessage(self, MSG_FOLLOWED .. owner, "NORMAL")
    end
end

-- ---------------------------------------------------------------------------
-- Share button
-- ---------------------------------------------------------------------------

local function StyleShareButton(btn)
    if btn.Left then btn.Left:SetTexture(""); btn.Left:Hide() end
    if btn.Right then btn.Right:SetTexture(""); btn.Right:Hide() end
    if btn.Middle then btn.Middle:SetTexture(""); btn.Middle:Hide() end
    if btn.DisabledLeft then btn.DisabledLeft:SetTexture(""); btn.DisabledLeft:Hide() end
    if btn.DisabledRight then btn.DisabledRight:SetTexture(""); btn.DisabledRight:Hide() end
    if btn.DisabledMiddle then btn.DisabledMiddle:SetTexture(""); btn.DisabledMiddle:Hide() end

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
    if btn.GetFontString then
        local fs = btn.GetFontString and btn:GetFontString()
        if fs then
            fs:SetTextColor(1, 0.82, 0, 1)
            fs:ClearAllPoints()
            fs:SetPoint("CENTER", btn, "CENTER", 0, 0)
        end
    end
end

function KeystonePolaris:EnsureLiveRouteShareButton()
    if self.liveRouteShareButton then return self.liveRouteShareButton end

    local btn = CreateFrame("Button", "KeystonePolarisShareButton", UIParent, "UIPanelButtonTemplate, BackdropTemplate")
    btn:SetSize(160, 28)
    btn:SetText(L["KPL_LR_SHARE"] or "Share")
    btn:EnableMouse(true)
    btn:RegisterForClicks("LeftButtonUp")
    StyleShareButton(btn)

    btn:SetScript("OnClick", function()
        self:ShareLiveRoute()
    end)

    btn:SetScript("OnEnter", function(button)
        GameTooltip:SetOwner(button, "ANCHOR_TOP")
        GameTooltip:AddLine(L["KPL_LR_SHARE"] or "Share")
        local names = self:GetLiveRoutePeerNames()
        if #names > 0 then
            GameTooltip:AddLine(
                (L["KPL_LR_SHARE_WITH"] or "Share with: %s"):format(table.concat(names, ", ")),
                1, 1, 1, true
            )
        end
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    btn:ClearAllPoints()
    if self.displayFrame then
        btn:SetPoint("BOTTOM", self.displayFrame, "TOP", 0, 6)
    else
        btn:SetPoint("CENTER", UIParent, "CENTER", 0, 120)
    end
    btn:Hide()
    self.liveRouteShareButton = btn
    return btn
end

function KeystonePolaris:HideLiveRouteShareButton(dismiss)
    local btn = self.liveRouteShareButton
    if btn then
        btn:Hide()
        btn:SetText(L["KPL_LR_SHARE"] or "Share")
    end
    if dismiss then
        self._liveRouteButtonDismissed = true
    end
end

function KeystonePolaris:UpdateLiveRouteShareButton()
    local shouldShow = IsLiveRouteEnabled(self)
        and self:IsInLiveRouteContext()
        and IsInGroup()
        and self:HasLiveRoutePeers()
        and not self:IsFollowingLiveRoute()
        and type(self._pendingLiveRoute) ~= "table"
        and not self._liveRouteButtonDismissed
        and not IsLiveRouteKeystoneActive()
        and not InCombatLockdown()
        and not UnitAffectingCombat("player")

    if not shouldShow then
        if self.liveRouteShareButton then
            self.liveRouteShareButton:Hide()
        end
        return
    end

    local btn = self:EnsureLiveRouteShareButton()
    if self.displayFrame then
        btn:ClearAllPoints()
        btn:SetPoint("BOTTOM", self.displayFrame, "TOP", 0, 6)
    end
    btn:SetText(L["KPL_LR_SHARE"] or "Share")
    btn:Show()
end

-- ---------------------------------------------------------------------------
-- Share / receive
-- ---------------------------------------------------------------------------

local function CombatBlocked()
    return InCombatLockdown() or UnitAffectingCombat("player")
end

local function CooldownRemaining(self)
    local endTime = self._liveRouteShareCooldownEnd
    if not endTime then return 0 end
    return math.max(0, endTime - GetTime())
end

function KeystonePolaris:ShareLiveRoute()
    if not IsLiveRouteEnabled(self) then
        ChatPrint(self, L["KPL_LR_DISABLED"] or "Live Route Sharing is disabled in options.")
        return
    end
    if self:IsFollowingLiveRoute() then
        ChatPrint(self, L["KPL_LR_SHARE_WHILE_FOLLOWING"] or "Unfollow the current route before sharing yours.")
        return
    end
    if not self:IsInLiveRouteContext() then
        ChatPrint(self, L["KPL_LR_NOT_IN_DUNGEON"] or "Share is only available in Mythic or Mythic+ dungeons.")
        return
    end
    if CombatBlocked() then
        ChatPrint(self, L["KPL_LR_IN_COMBAT"] or "Wait until after combat to share a route.")
        return
    end
    if IsLiveRouteCommLocked() or IsLiveRouteKeystoneActive() then
        ChatPrint(self, L["KPL_LR_COMM_LOCKDOWN"] or "Blizzard blocks addon messages during an active Mythic+ run. Share before starting the keystone.")
        return
    end
    local remaining = CooldownRemaining(self)
    if remaining > 0 then
        ChatPrint(self, (L["KPL_LR_COOLDOWN"] or "Wait %d seconds before sharing again."):format(math.ceil(remaining)))
        return
    end
    PrunePeers(self)
    if not self:HasLiveRoutePeers() then
        ChatPrint(self, L["KPL_LR_NO_PEERS"] or "Nobody else has Keystone Polaris.")
        return
    end

    local dungeonKey = self:GetLiveRouteDungeonKey()
    local payload = dungeonKey and self:BuildLocalLiveRoutePayload(dungeonKey) or nil
    local encoded = payload and EncodePayload(payload) or nil
    if not encoded then
        ChatPrint(self, L["KPL_LR_ENCODE_FAILED"] or "Could not encode the route to share.")
        return
    end

    SendSharePayload(self, encoded, function(sendResult, attempted)
        if not attempted or SendResultIsLockdown(sendResult) then
            ChatPrint(self, L["KPL_LR_COMM_LOCKDOWN"] or "Blizzard blocks addon messages during an active Mythic+ run. Share before starting the keystone.")
            return
        end
        if not SendResultIsSuccess(sendResult) then
            ChatPrint(self, L["KPL_LR_SEND_FAILED"] or "Could not send the route to the group.")
            return
        end
        self._liveRouteShareCooldownEnd = GetTime() + SHARE_COOLDOWN
        self:HideLiveRouteShareButton(true)
        ChatPrint(self, L["KPL_LR_SHARED"] or "Route shared with the group.")
    end)
end

local function ShowLiveRoutePrompt(self, sender, payload, replaceSender)
    local dungeonKey, challengeMapID, uiMapID = self:GetLiveRouteDungeonKey()
    local _, _, instanceID = GetSessionInfo()
    self._pendingLiveRoute = {
        sender = sender,
        payload = payload,
        session = {
            dungeonKey = dungeonKey or payload.dungeonKey,
            instanceID = instanceID,
            challengeMapID = challengeMapID,
            uiMapID = uiMapID,
        },
    }

    local dungeonName = DungeonDisplayName(self, payload.dungeonKey)
    local senderName = DisplayNameForSender(sender)
    local text
    if replaceSender then
        text = (L["KPL_LR_REPLACE_PROMPT"] or "%s wants to replace %s's route for %s. Follow this route?"):format(
            senderName,
            DisplayNameForSender(replaceSender),
            dungeonName
        )
    else
        text = (L["KPL_LR_PROMPT"] or "%s wants to share a Keystone Polaris route for %s. Follow this route?"):format(
            senderName,
            dungeonName
        )
    end

    StaticPopupDialogs["KPL_LIVE_ROUTE"] = {
        text = text,
        button1 = YES,
        button2 = NO,
        OnAccept = function()
            local pending = KeystonePolaris._pendingLiveRoute
            KeystonePolaris._pendingLiveRoute = nil
            if not pending or not KeystonePolaris.ApplyLiveRouteOverlay then return end
            if KeystonePolaris:ApplyLiveRouteOverlay(pending.sender, pending.payload, pending.session) then
                FollowedChatMessage(KeystonePolaris, pending.sender)
            end
        end,
        OnCancel = function()
            KeystonePolaris._pendingLiveRoute = nil
        end,
        OnHide = function()
            if KeystonePolaris.UpdateLiveRouteShareButton then
                KeystonePolaris:UpdateLiveRouteShareButton()
            end
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
    }
    StaticPopup_Show("KPL_LIVE_ROUTE")
    self:HideLiveRouteShareButton(false)
end

function KeystonePolaris:HandleIncomingLiveRoute(sender, payload)
    if not IsLiveRouteEnabled(self) then return end
    if IsSelfSender(sender) then return end
    if not IsInGroup() then return end

    payload = self:SanitizeLiveRoutePayload(payload)
    if not payload then
        ChatPrint(self, L["KPL_LR_DECODE_FAILED"] or "Received a route that could not be read.")
        return
    end

    local dungeonKey = self:GetLiveRouteDungeonKey()
    local inContext = self:IsInLiveRouteContext()
    if not inContext or (dungeonKey and payload.dungeonKey ~= dungeonKey) then
        StorePendingLiveRoute(self, sender, payload)
        return
    end

    local trusted = IsSenderTrusted(sender)
    local alwaysAsk = self.db.profile.liveRoute and self.db.profile.liveRoute.alwaysAsk
    local following = self:IsFollowingLiveRoute()
    local currentSender = following and self._liveRoute.sender or nil

    if trusted and not alwaysAsk and not following then
        if self:ApplyLiveRouteOverlay(sender, payload) then
            FollowedChatMessage(self, sender)
        end
        return
    end

    ShowLiveRoutePrompt(self, sender, payload, following and currentSender or nil)
end

function KeystonePolaris:OnLiveRouteComm(_, message, _, sender)
    if type(message) ~= "string" or message == "" then return end
    if IsSelfSender(sender) then return end
    if not IsLiveRouteEnabled(self) then return end

    local kind = message:sub(1, 1)
    if kind == MSG_HELLO then
        if not IsInGroup() then return end
        RememberPeer(self, sender)
        self:UpdateLiveRouteShareButton()
        ReplyLiveRouteHere(self)
        return
    end
    if kind == MSG_HERE then
        if not IsInGroup() then return end
        RememberPeer(self, sender)
        self:UpdateLiveRouteShareButton()
        return
    end
    if kind == MSG_FOLLOWED then
        local owner = message:sub(2)
        if not IsSelfSender(owner) then return end
        ChatPrint(self, (L["KPL_LR_FOLLOWER_ACCEPTED"] or "%s is following your route."):format(DisplayNameForSender(sender)))
        return
    end
    if kind == MSG_SHARE then
        local payload = DecodePayload(message:sub(2))
        if payload then
            self:HandleIncomingLiveRoute(sender, payload)
        else
            ChatPrint(self, L["KPL_LR_DECODE_FAILED"] or "Received a route that could not be read.")
        end
        return
    end
    if kind == MSG_CHUNK then
        local token, index, total, piece = message:sub(2):match("^([^:]+):(%d+):(%d+):(.*)$")
        index = tonumber(index)
        total = tonumber(total)
        if not token or not index or not total or type(piece) ~= "string" then return end

        local chunks = self._liveRouteChunks
        if type(chunks) ~= "table" then
            chunks = {}
            self._liveRouteChunks = chunks
        end
        local key = (NormalizeName(sender) or sender) .. ":" .. token
        local bucket = chunks[key]
        if type(bucket) ~= "table" then
            bucket = { total = total, parts = {} }
            chunks[key] = bucket
        end
        bucket.parts[index] = piece
        for i = 1, total do
            if type(bucket.parts[i]) ~= "string" then return end
        end
        chunks[key] = nil
        local payload = DecodePayload(table.concat(bucket.parts))
        if payload then
            self:HandleIncomingLiveRoute(sender, payload)
        else
            ChatPrint(self, L["KPL_LR_DECODE_FAILED"] or "Received a route that could not be read.")
        end
    end
end

-- ---------------------------------------------------------------------------
-- Session lifecycle
-- ---------------------------------------------------------------------------

function KeystonePolaris:UpdateLiveRouteSession()
    if not IsLiveRouteEnabled(self) then
        self:HideLiveRouteShareButton(false)
        return
    end

    if not self:IsInLiveRouteContext() then
        local inInstance, instanceType = IsInInstance()
        local _, difficultyID = GetSessionInfo()
        if inInstance and instanceType == "party" and IsMythicOrKeystoneDifficulty(difficultyID) then
            QueueLiveRoutePings(self)
            if not self._liveRouteMapRetry then
                self._liveRouteMapRetry = true
                C_Timer.After(1, function()
                    self._liveRouteMapRetry = false
                    if self.UpdateLiveRouteSession then
                        self:UpdateLiveRouteSession()
                    end
                end)
            end
            return
        end
        self._liveRoutePeers = {}
        self._liveRouteButtonDismissed = false
        self:HideLiveRouteShareButton(false)
        local stored = self.db and self.db.char and self.db.char.liveRoute
        if type(stored) == "table" then
            self:WipeLiveRouteOverlay()
        elseif type(self._liveRoute) == "table" then
            self:WipeLiveRouteOverlay()
        end
        return
    end

    self._liveRouteMapRetry = false
    self:RestoreLiveRouteOverlay()
    PrunePeers(self)
    QueueLiveRoutePings(self)
    self:UpdateLiveRouteShareButton()
    ConsumePendingLiveRoute(self)
end

function KeystonePolaris:OnLiveRouteRosterUpdate()
    if not IsLiveRouteEnabled(self) then return end
    PrunePeers(self)
    if IsInLiveRoutePresenceRange() then
        QueueLiveRoutePings(self)
        self:UpdateLiveRouteShareButton()
    else
        self:HideLiveRouteShareButton(false)
    end
end

function KeystonePolaris:InitializeLiveRoute()
    if self._liveRouteInitialized then return end
    self._liveRouteInitialized = true
    self._liveRoutePeers = {}

    if self.RegisterComm then
        self:RegisterComm(PREFIX, "OnLiveRouteComm")
    end

    -- Own frame: AceEvent allows only one handler per event on the addon object,
    -- and Core/PullTracker already own PLAYER_ENTERING_WORLD / CHALLENGE_MODE_START / PLAYER_REGEN_DISABLED.
    if not self._liveRouteEventFrame then
        local frame = CreateFrame("Frame")
        frame:RegisterEvent("PLAYER_ENTERING_WORLD")
        frame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
        frame:RegisterEvent("PLAYER_DIFFICULTY_CHANGED")
        frame:RegisterEvent("CHALLENGE_MODE_START")
        frame:RegisterEvent("GROUP_ROSTER_UPDATE")
        frame:RegisterEvent("PLAYER_REGEN_DISABLED")
        frame:RegisterEvent("PLAYER_REGEN_ENABLED")
        frame:SetScript("OnEvent", function(_, event)
            if event == "GROUP_ROSTER_UPDATE" then
                self:OnLiveRouteRosterUpdate()
            elseif event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" then
                self:UpdateLiveRouteShareButton()
            elseif self.UpdateLiveRouteSession then
                self:UpdateLiveRouteSession()
            end
        end)
        self._liveRouteEventFrame = frame
    end

    self:UpdateLiveRouteSession()
end

function KeystonePolaris:GetLiveRouteOptions()
    return {
        name = L["KPL_LR_HEADER"] or "Live Route Sharing",
        type = "group",
        order = 8,
        args = {
            header = {
                order = 0,
                type = "header",
                name = "|cffffd100" .. (L["KPL_LR_HEADER"] or "Live Route Sharing") .. "|r",
            },
            description = {
                order = 0.5,
                type = "description",
                name = L["KPL_LR_DESC_LONG"] or "Share your Keystone Polaris route with the group in Mythic or Mythic+ dungeons. Following a route never overwrites your saved Custom Routes.",
                fontSize = "medium",
            },
            enable = {
                name = L["ENABLE"] or "Enable",
                type = "toggle",
                width = "full",
                order = 1,
                get = function()
                    return self.db.profile.liveRoute.enabled
                end,
                set = function(_, value)
                    self.db.profile.liveRoute.enabled = value and true or false
                    if not value then
                        self:WipeLiveRouteOverlay()
                        self._liveRoutePeers = {}
                        ClearPendingLiveRoute(self)
                        self:HideLiveRouteShareButton(false)
                    else
                        self:UpdateLiveRouteSession()
                    end
                end,
            },
            alwaysAsk = {
                name = L["KPL_LR_ALWAYS_ASK"] or "Always ask before following a route",
                desc = L["KPL_LR_ALWAYS_ASK_DESC"] or "When enabled, even routes from the tank or group leader require confirmation.",
                type = "toggle",
                width = "full",
                order = 2,
                get = function()
                    return self.db.profile.liveRoute.alwaysAsk
                end,
                set = function(_, value)
                    self.db.profile.liveRoute.alwaysAsk = value and true or false
                end,
                disabled = function()
                    return not self.db.profile.liveRoute.enabled
                end,
            },
            slashInfo = {
                type = "description",
                name = L["KPL_LR_CHAT_COMMAND_INFO"] or "Tip: use |cffffd100/kpl share|r or |cffffd100/polaris share|r to share your route, and |cffffd100/kpl unfollow|r, |cffffd100/polaris unfollow|r, or the Unfollow chat link to stop following.",
                order = 3,
                fontSize = "medium",
            },
        }
    }
end

if not KeystonePolaris._KPL_LiveRouteChatLinkHooked then
    KeystonePolaris._KPL_LiveRouteChatLinkHooked = true
    hooksecurefunc("SetItemRef", function(link)
        if type(link) ~= "string" then return end
        local linkType = strsplit(":", link, 2)
        if linkType ~= "kplunfollow" then return end
        if KeystonePolaris and KeystonePolaris.UnfollowLiveRoute then
            KeystonePolaris:UnfollowLiveRoute("link")
        end
    end)
end
