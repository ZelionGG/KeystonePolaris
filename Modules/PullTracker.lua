local _, KeystonePolaris = ...

-- ---------------------------------------------------------------------------
-- Pull Tracker Module
-- ---------------------------------------------------------------------------

-- Track currently engaged mobs for real pull percent
KeystonePolaris.realPull = {
    mobs = {},    -- [guid] = { npcID = number, count = number }
    sum = 0,      -- total count across engaged GUIDs
    denom = 0,    -- MDT total required count for 100%
}

function KeystonePolaris:InitializePullTracker()
    -- Register events related to pull tracking
    self:RegisterEvent("PLAYER_REGEN_ENABLED")
    self:RegisterEvent("ENCOUNTER_END")

    if(not self.isMidnight) then
        self:RegisterEvent("NAME_PLATE_UNIT_ADDED")
        self:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
        self:RegisterEvent("PLAYER_REGEN_DISABLED")
        self:RegisterEvent("UNIT_THREAT_LIST_UPDATE")
    end

    -- Initialize state
    self.realPull.mobs = {}
    self.realPull.sum = 0
    self.realPull.denom = 0
end

-- Helpers to manage real pull set
function KeystonePolaris:AddEngagedMobByGUID(guid)
    if not guid then return end
    -- If already tracked, just refresh lastSeen and return
    local existing = self.realPull.mobs[guid]
    if existing then
        existing.lastSeen = (GetTime and GetTime()) or existing.lastSeen or 0
        return
    end
    local DungeonTools = _G.MythicDungeonToolsAPI
    if type(DungeonTools) ~= "table" or type(DungeonTools.GetEnemyForces) ~= "function" then
        DungeonTools = _G.MDT or _G.MethodDungeonTools
    end
    if not DungeonTools or not DungeonTools.GetEnemyForces then return end

    local _, _, _, _, _, npcID = strsplit("-", guid)
    local id = tonumber(npcID)
    if not id then return end

    local count, max, maxTeeming, teemingCount = DungeonTools:GetEnemyForces(id)
    local isTeeming = self.IsTeeming and self:IsTeeming() or false
    local denom = (isTeeming and maxTeeming) or max
    local c = (isTeeming and teemingCount) or count
    c = tonumber(c) or 0
    denom = tonumber(denom) or 0

    -- Initialize denominator when first known
    if self.realPull.denom == 0 and denom > 0 then
        self.realPull.denom = denom
    end

    if c > 0 then
        self.realPull.mobs[guid] = { npcID = id, count = c, lastSeen = (GetTime and GetTime()) or 0 }
        self.realPull.sum = self.realPull.sum + c
    end
end

function KeystonePolaris:RemoveEngagedMobByGUID(guid)
    local data = guid and self.realPull.mobs[guid]
    if not data then return end
    self.realPull.sum = math.max(0, self.realPull.sum - (data.count or 0))
    self.realPull.mobs[guid] = nil
end

-- Compute current planned pull percent via MDT (if available)
function KeystonePolaris:GetCurrentPullPercent()
    if not C_ChallengeMode.IsChallengeModeActive() then return 0 end
    local denom = tonumber(self.realPull.denom) or 0
    local sum = tonumber(self.realPull.sum) or 0
    if denom <= 0 or sum <= 0 then return 0 end
    return (sum / denom) * 100
end

-- React to nameplate additions/removals to refresh dynamic pull percent
function KeystonePolaris:NAME_PLATE_UNIT_ADDED(_, unit)
    -- Maintain a map of nameplate unit -> GUID so we can cleanly remove on REMOVED
    self._nameplateUnits = self._nameplateUnits or {}
    if unit then
        local guid = UnitGUID(unit)
        if guid then
            self._nameplateUnits[unit] = guid
        end
    end
    -- Engagement tracking remains via COMBAT_LOG to avoid double counting
    if self._QueuePullUpdate then self:_QueuePullUpdate() end
end

function KeystonePolaris:NAME_PLATE_UNIT_REMOVED(_, unit)
    -- Use stored GUID (UnitGUID may be nil after removal)
    -- Do not remove engaged mobs here: nameplates can disappear when rotating camera;
    -- rely on COMBAT_LOG (UNIT_DIED/UNIT_DESTROYED) and end-of-combat reset instead.
    if unit then
        if self._nameplateUnits then
            self._nameplateUnits[unit] = nil
        end
        -- Intentionally not calling RemoveEngagedMobByGUID(guid) to avoid Pull% oscillation.
    end
    if self._QueuePullUpdate then self:_QueuePullUpdate() end
end

-- Update when threat list changes (engagement state)
function KeystonePolaris:UNIT_THREAT_LIST_UPDATE(_, unit)
    -- Add mobs to current pull based on threat updates (WarpDeplete-like)
    if not C_ChallengeMode.IsChallengeModeActive() then return end
    if not (UnitAffectingCombat and UnitAffectingCombat("player")) then return end
    if not unit or not UnitExists(unit) then return end

    local guid = UnitGUID(unit)
    if not guid then return end

    -- Prevent re-adding mobs that have been marked dead during this combat
    self._deadGuids = self._deadGuids or {}
    if self._deadGuids[guid] then return end

    -- If already tracked, just refresh lastSeen
    if self.realPull and self.realPull.mobs[guid] then
        local existing = self.realPull.mobs[guid]
        existing.lastSeen = (GetTime and GetTime()) or existing.lastSeen or 0
        return
    end

    -- Use AddEngagedMobByGUID which pulls MDT count/denom and updates sums
    self:AddEngagedMobByGUID(guid)
    self:_QueuePullUpdate()
end

-- Start of combat: reset real pull state
function KeystonePolaris:PLAYER_REGEN_DISABLED()
    if self._testMode and self.DisableTestMode then self:DisableTestMode("entered combat") end
    self.realPull.mobs = {}
    self.realPull.sum = 0
    self.realPull.denom = 0
    -- Start a lightweight watchdog ticker to clean stale GUIDs during combat
    if self._pullWatchdogTicker then
        self._pullWatchdogTicker:Cancel()
        self._pullWatchdogTicker = nil
    end
    local TTL = 8 -- seconds without activity before considering GUID stale
    self._pullWatchdogTicker = C_Timer.NewTicker(1, function()
        if not C_ChallengeMode.IsChallengeModeActive() then return end
        -- Build a quick lookup of currently visible nameplate GUIDs
        local plateGuids = {}
        if self._nameplateUnits then
            for _, g in pairs(self._nameplateUnits) do
                if g then plateGuids[g] = true end
            end
        end
        local now = (GetTime and GetTime()) or 0
        for g, data in pairs(self.realPull.mobs) do
            local last = tonumber(data and data.lastSeen) or now
            if (now - last) >= TTL then
                -- Skip removal if GUID is clearly still in view/target
                local stillVisible = plateGuids[g]
                    or (UnitGUID and (g == UnitGUID("target") or g == UnitGUID("focus") or g == UnitGUID("mouseover")
                        or g == UnitGUID("boss1") or g == UnitGUID("boss2") or g == UnitGUID("boss3") or g == UnitGUID("boss4") or g == UnitGUID("boss5")))
                if not stillVisible then
                    self:RemoveEngagedMobByGUID(g)
                    self:_QueuePullUpdate()
                end
            end
        end
    end)
end

-- End of combat: clear and refresh
function KeystonePolaris:PLAYER_REGEN_ENABLED()
    self.realPull.mobs = {}
    self.realPull.sum = 0
    self.realPull.denom = 0
    if self._deadGuids then
        wipe(self._deadGuids)
    end
    if self._pullWatchdogTicker then
        self._pullWatchdogTicker:Cancel()
        self._pullWatchdogTicker = nil
    end
    if self.UpdatePercentageText then self:UpdatePercentageText() end
end

-- Reset pull state when an encounter ends (e.g., boss end), mirroring WarpDeplete behavior
function KeystonePolaris:ENCOUNTER_END()
    self.realPull.mobs = {}
    self.realPull.sum = 0
    self.realPull.denom = 0
    if self._deadGuids then
        wipe(self._deadGuids)
    end
    if self._pullWatchdogTicker then
        self._pullWatchdogTicker:Cancel()
        self._pullWatchdogTicker = nil
    end
    if self.UpdatePercentageText then self:UpdatePercentageText() end
end

-- Throttled updater for combat log bursts
function KeystonePolaris:_QueuePullUpdate()
    if self._pullUpdateQueued then return end
    self._pullUpdateQueued = true
    C_Timer.After(0.1, function()
        self._pullUpdateQueued = nil
        if self.UpdatePercentageText then self:UpdatePercentageText() end
    end)
end
