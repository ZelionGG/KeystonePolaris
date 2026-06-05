local AddOnName, KeystonePolaris = ...

-- Define a single source of truth for dungeon data
KeystonePolaris.MIDNIGHT_DUNGEON_DATA = {
    -- Format: [shortName] = {id = dungeonID, bosses = {{bossID, percent, shouldInform, bossOrder, journalEncounterID}, ...}}
    MAGI = { -- Magisters' Terrace
        id = 558,
        mapID = 2811,
        displayName = "Magisters' Terrace",
        teleportID = 1254572,
        bosses = {
            {1, 27.81, false, 1, 2659, "Arcanotron Custos", 231861}, -- Arcanotron Custos
            {2, 48.91, false, 2, 2661, "Seranel Sunlash", 231863}, -- Seranel Sunlash
            {3, 78.06, false, 3, 2660, "Gemellus", {231864, 239636, 241397}}, -- Gemellus
            {4, 100,   true,  4, 2662, "Degentrius", 231865} -- Degentrius
        }
    },
    MAIS = { -- Maisara Caverns
        id = 560,
        mapID = 2874,
        displayName = "Maisara Caverns",
        teleportID = 1254559,
        bosses = {
            {1, 48.6,  false, 1, 2810, "Muro'jin and Nekraxx", {247570, 247572}}, -- Muro'jin and Nekraxx
            {2, 89.95, false, 2, 2811, "Vordaza", 248595}, -- Vordaza
            {3, 100,   true,  3, 2812, "Rak'tul, Vessel of Souls", 248605}, -- Rak'tul, Vessel of Souls
        }
    },
    NPX = { -- Nexus-Point Xenas
        id = 559,
        mapID = 2915,
        displayName = "Nexus-Point Xenas",
        teleportID = 1254563,
        bosses = {
            {1, 29.36, false, 1, 2813, "Chief Corewright Kasreth", 241539}, -- Chief Corewright Kasreth
            {2, 73.66, false, 2, 2814, "Corewarden Nysarra", 241542}, -- Corewarden Nysarra
            {3, 100,   true,  3, 2815, "Lothraxion", 241546}, -- Lothraxion
        },
        milestones = {
            {
                id = 1,
                label = "Before Nysarra's Arena",
                thresholdPercent = 69.46,
                triggerType = "subzone",
                -- Core Defense Nullward (AreaTable ID; parent 16573, continent/uiMap 2915)
                matchAreaID = 16575,
                inform = true,
                informSuffix = "before entering Nysarra's arena.",
                creationOrder = 1,
            },
        },
    },
    WIS = { -- Windrunner Spire
        id = 557,
        mapID = 2805,
        displayName = "Windrunner Spire",
        teleportID = 1254400,
        bosses = {
            {1, 45.35, false, 1, 2655, "Emberdawn", 231606}, -- Emberdawn
            {2, 57.36, false, 2, 2656, "Derelict Duo", {231626, 231629}}, -- Derelict Duo
            {3, 100,   true,  3, 2657, "Commander Kroluk", 231631}, -- Commander Kroluk
            {4, 100,   true,  4, 2658, "The Restless Heart", 231636}, -- The Restless Heart
        }
    },
}
