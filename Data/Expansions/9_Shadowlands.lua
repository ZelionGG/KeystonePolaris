local AddOnName, KeystonePolaris = ...

-- Define a single source of truth for dungeon data
KeystonePolaris.SL_DUNGEON_DATA = {
    -- Format: [shortName] = {id = dungeonID, bosses = {{bossID, percent, shouldInform, bossOrder, journalEncounterID}, ...}}
    MoTS = { -- Mists of Tirna Scithe
        id = 375,
        mapID = 2290,
        teleportID = 354464,
        bosses = {
            {1, 33.10, false, 1, 2400},
            {2, 63.45, false, 2, 2402},
            {3, 100, true, 3, 2405}
        }
    },
    NW = { -- Necrotic Wake
        id = 376,
        mapID = 2286,
        teleportID = 354462,
        bosses = {
            {1, 22.59, false, 1, 2395},
            {2, 76.81, true, 2, 2391},
            {3, 100, true, 3, 2392},
            {4, 100, true, 4, 2396}
        }
    },
    ToP = { -- Theater of Pain
        id = 382,
        mapID = 2293,
        teleportID = 354467,
        bosses = {
            {1, 7.01, false, 1, 2397},
            {2, 37.27, false, 2, 2401},
            {3, 71.59, false, 3, 2390},
            {4, 100, false, 4, 2389},
            {5, 100, true, 5, 2417}
        }
    },
    TSoW = { -- Tazavesh, the Veiled Market: Streets of Wonder
        id = 391,
        mapID = 2441,
        teleportID = 367416,
        bosses = {
            {1, 31.67, false, 1, 2437},
            {2, 57.22, false, 2, 2454},
            {3, 91.67, true, 4, 2436},
            {4, 77.22, false, 3, 2452},
            {5, 100, true, 5, 2451}
        }
    },
    TSLG = { -- Tazavesh, the Veiled Market: So'leah's Gambit
        id = 392,
        mapID = 2441,
        teleportID = 367416,
        bosses = {
            {1, 51.45, false, 1, 2448},
            {2, 75.43, false, 2, 2449},
            {3, 100, true, 3, 2455}
        }
    },
    HoA = { -- Halls of Atonement
        id = 378,
        mapID = 2287,
        teleportID = 354465,
        bosses = {
            {1, 57.73, false, 1, 2406},
            {2, 79.83, false, 2, 2387},
            {3, 92.49, true, 3, 2411},
            {4, 100, true, 4, 2413}
        }
    }
}
