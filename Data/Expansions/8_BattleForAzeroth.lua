local AddOnName, KeystonePolaris = ...

-- Define a single source of truth for dungeon data
KeystonePolaris.BFA_DUNGEON_DATA = {
    -- Format: [shortName] = {id = dungeonID, bosses = {{bossID, percent, shouldInform, bossOrder, journalEncounterID}, ...}}
    OMGW = {
        id = 370,
        mapID = 2773,
        teleportID = 373274,
        bosses = {
            {1, 22.46, false, 1, 2336},
            {2, 47.59, true, 2, 2339},
            {3, 71.66, true, 3, 2348},
            {4, 100,   true, 4, 2331}
        }
    },
    SoB = {
        id = 353,
        mapID = 1822,
        teleportID = 464256,
        bosses = {
            {1, 37.04, false, 1, 2654},
            {2, 54.66, false, 2, 2173},
            {3, 100, true, 3, 2134},
            {4, 100, true, 4, 2140}
        }
    },
    TML = {
        id = 247,
        mapID = 1594,
        teleportID = {467555, 467553},
        bosses = {
            {1, 26.91, false, 1, 2109},
            {2, 59.30, false, 2, 2114},
            {3, 75.93, false, 3, 2115},
            {4, 100, true, 4, 2116}
        }
    },
    ToSet = {
        id = 250,
        mapID = 1877,
        displayName = "Temple of Sethraliss",
        teleportID = 1286828,
        bosses = {
            {1, 45.35, false, 1, 2142, "Adderis and Aspix", {262530, 262822}}, -- Adderis and Aspix
            {2, 57.36, false, 2, 2143, "Merektha", 244887}, -- Merektha
            {3, 100,   true,  3, 2144, "Galvazzt", 245912}, -- Galvazzt
            {4, 100,   true,  4, 2145, "Avatar of Sethraliss", 133392}, -- Avatar of Sethraliss
        }
    },
    KR = {
        id = 249,
        mapID = 1762,
        displayName = "Kings' Rest",
        teleportID = 1286831,
        bosses = {
            {1, 45.35, false, 1, 2165, "The Golden Serpent", 135322}, -- The Golden Serpent
            {2, 57.36, false, 2, 2170, "Mchimba the Embalmer", 134993}, -- Mchimba the Embalmer
            {3, 100,   true,  3, 2171, "The Council of Tribes", {269811, 269808, 269810}}, -- The Council of Tribes
            {4, 100,   true,  4, 2172, "King Dazar", 136160}, -- King Dazar
        }
    }
}
