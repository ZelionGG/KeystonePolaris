local AddOnName, KeystonePolaris = ...

-- Define a single source of truth for dungeon data
KeystonePolaris.DF_DUNGEON_DATA = {
    -- Format: [shortName] = {id = dungeonID, bosses = {{bossID, percent, shouldInform, bossOrder, journalEncounterID}, ...}}
    AA = { -- Algeth'ar Academy
        id = 402,
        mapID = 2526,
        teleportID = 393273,
        bosses = {
            {1, 77.17, false, 3, 2509, "Vexamus", 194181}, -- Vexamus
            {2, 21.52, false, 1, 2512, "Overgrown Ancient", 196482}, -- Overgrown Ancient
            {3, 51.09, false, 2, 2495, "Crawth", 191736}, -- Crawth
            {4, 100,   true,  4, 2514, "Echo of Doragosa", 190609} -- Echo of Doragosa
        }
    }
}
