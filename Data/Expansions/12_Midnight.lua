local AddOnName, KeystonePolaris = ...

-- Define a single source of truth for dungeon data
KeystonePolaris.MIDNIGHT_DUNGEON_DATA = {
    -- Format: [shortName] = {id = dungeonID, bosses = {{bossID, percent, shouldInform, bossOrder, journalEncounterID}, ...}}
    -- lfgID: optional LFG dungeon ID for icon fallback before Challenge Mode registration
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
            {1, 37.92, false, 1, 2813, "Chief Corewright Kasreth", 241539}, -- Chief Corewright Kasreth
            {2, 82.72, false, 2, 2814, "Corewarden Nysarra", 241542}, -- Corewarden Nysarra
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
    MR = {
        id = 587,
        mapID = 2813,
        lfgID = 3090,
        displayName = "Murder Row",
        teleportID = 1286809,
        bosses = {
            {1, 45.35, false, 1, 3101, "Kystia Manaheart", 252458}, -- Kystia Manaheart
            {2, 57.36, false, 2, 3102, "Zaen Bladesorrow", 234649}, -- Zaen Bladesorrow
            {3, 100,   true,  3, 3103, "Xathuux the Annihilator", 234647}, -- Xathuux the Annihilator
            {4, 100,   true,  4, 3104, "Lithiel Cinderfury", 237415}, -- Lithiel Cinderfury
        }
    },
    DoN = {
        id = 586,
        mapID = 2825,
        lfgID = 3051,
        displayName = "Den of Nalorakk",
        teleportID = 1286807,
        bosses = {
            {1, 45.35, false, 1, 3207, "The Hoardmonger", 248710}, -- The Hoardmonger
            {2, 57.36, false, 2, 3208, "Sentinel of Winter", 261053}, -- Sentinel of Winter
            {3, 100,   true,  3, 3209, "Nalorakk", 258877}, -- Nalorakk
        }
    },
    TBV = {
        id = 584,
        mapID = 2859,
        lfgID = 3102,
        displayName = "The Blinding Vale",
        teleportID = 1286801,
        bosses = {
            {1, 45.35, false, 1, 3199, "Lightblossom Trinity", {243028, 243030, 243029}}, -- Lightblossom Trinity
            {2, 57.36, false, 2, 3200, "Ikuzz the Light Hunter", 244887}, -- Ikuzz the Light Hunter
            {3, 100,   true,  3, 3201, "Lightwarden Ruia", 245912}, -- Lightwarden Ruia
            {4, 100,   true,  4, 3202, "Ziekket", 247676}, -- Ziekket
        }
    },
    VSA = {
        id = 585,
        mapID = 2923,
        lfgID = 3106,
        displayName = "Voidscar Arena",
        teleportID = 1286804,
        bosses = {
            {1, 45.35, false, 1, 3285, "Taz'Rah", 238887}, -- Taz'Rah
            {2, 57.36, false, 2, 3286, "Atroxus", 239008}, -- Atroxus
            {3, 100,   true,  3, 3287, "Charonus", 248015}, -- Charonus
        }
    },
    AoFa = {
        id = 588,
        mapID = 2993,
        lfgID = 3191,
        displayName = "Altar of Fangs",
        teleportID = 1286812,
        bosses = {
            {1, 45.35, false, 1, 3456, "Rav'i", 259445}, -- Rav'i
            {2, 57.36, false, 2, 3457, "The Writhing Coil", 259446}, -- The Writhing Coil
            {3, 100,   true,  3, 3458, "Zul'jan", 259447}, -- Zul'jan
        }
    },
}
