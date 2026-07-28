local AddOnName, KeystonePolaris = ...

-- Define which dungeons are in the current season
-- start_date: YYYY-MM-DD (required) or table keyed by portal (US/EU)
-- end_date: YYYY-MM-DD (optional) or table keyed by portal (US/EU)
KeystonePolaris.MIDNIGHT_1_DUNGEONS = {
    start_date = {
        US = "2026-03-24",
        EU = "2026-03-25",
        default = "2026-03-25"
    },
    end_date = {
        US = "2026-08-11",
        EU = "2026-08-12",
        default = "2026-08-12"
    },
    -- Midnight dungeons
    [557] = true, -- Windrunner Spire
    [558] = true, -- Magisters' Terrace
    [559] = true, -- Nexus-Point Xenas
    [560] = true, -- Maisara Caverns
    -- Dragonflight dungeons
    [402] = true, -- AA (Algeth'ar Academy)
    -- Legion dungeons
    [239] = true, -- SotT (Seat of the Triumvirate)
    -- Warlords of Draenor dungeons
    [161] = true, -- SKY (Skyreach)
    -- Wrath of the Lich King dungeons
    [556] = true, -- PoS (Pit of Saron)
}