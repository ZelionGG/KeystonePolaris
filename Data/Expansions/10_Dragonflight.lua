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
            {2, 51.09, false, 2, 2495, "Crawth", 191736}, -- Crawth
            {3, 21.52, false, 1, 2512, "Overgrown Ancient", 196482}, -- Overgrown Ancient
            {4, 100,   true,  4, 2514, "Echo of Doragosa", 190609} -- Echo of Doragosa
        }
    },
    RLP = { -- Ruby Life Pools
        id = 399,
        mapID = 2521,
        teleportID = 393256,
        bosses = {
            {1, 35.15, false, 1, 2488, "Melidrussa Chillworn", 188252}, -- Melidrussa Chillworn
            {2, 76.97, false, 2, 2485, "Kokia Blazehoof", 189232}, -- Kokia Blazehoof
            {3, 100,   true,  3, 2503, "Kyrakka and Erkhart Stormvein", {199790, 199791}}, -- Kyrakka and Erkhart Stormvein
        }
    }
}
