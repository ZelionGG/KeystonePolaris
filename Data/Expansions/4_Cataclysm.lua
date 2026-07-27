local AddOnName, KeystonePolaris = ...

-- Define a single source of truth for dungeon data
KeystonePolaris.CATACLYSM_DUNGEON_DATA = {
    -- Format: [shortName] = {id = dungeonID, bosses = {{bossID, percent, shouldInform, bossOrder, journalEncounterID}, ...}}
    GB = { -- Grim Batol
        id = 507,
        mapID = 670,
        teleportID = 445424,
        bosses = {
            {1, 39.68, false, 1, 2617},
            {2, 45.83, false, 2, 2627},
            {3, 81.26, true, 3, 2618},
            {4, 100, true, 4, 2619}
        }
    }
}
