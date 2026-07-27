local AddOnName, KeystonePolaris = ...

-- Define which dungeons are in the current season
-- start_date: YYYY-MM-DD, "TBD", or table keyed by portal (US/EU)
-- end_date: YYYY-MM-DD (optional), "TBD", or table keyed by portal (US/EU)
KeystonePolaris.MIDNIGHT_2_DUNGEONS = {
    --[[ start_date = {
        US = "2026-08-18",
        EU = "2026-08-19",
        default = "2026-08-19"
    }, ]]
    start_date = "TBD",
    -- Midnight dungeons
    [587] = true, -- Murder Row
    [586] = true, -- Den of Nalorakk
    [584] = true, -- The Blinding Vale
    [585] = true, -- Voidscar Arena
    [588] = true, -- Altar of Fangs
    -- Dragonflight dungeons
    [399] = true, -- Ruby Life Pools
    -- Battle for Azeroth dungeons
    [250] = true, -- Temple of Sethraliss
    [249] = true, -- Kings' Rest
}
