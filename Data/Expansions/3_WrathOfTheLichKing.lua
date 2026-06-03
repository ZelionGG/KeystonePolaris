local AddOnName, KeystonePolaris = ...

-- Define a single source of truth for dungeon data
KeystonePolaris.WOTLK_DUNGEON_DATA = {
    -- Format: [shortName] = {id = dungeonID, bosses = {{bossID, percent, shouldInform, bossOrder, journalEncounterID}, ...}}
    PoS = { -- Pit of Saron
        id = 556,
        mapID = 658,
        displayName = "Pit of Saron",
        teleportID = 1254555,
        bosses = {
            {1, 58.63, false, 1, 608, "Forgemaster Garfrost", 252635}, -- Forgemaster Garfrost
            {2, 79.94, false, 2, 609, "Ick and Krick", {252621, 252625, 255037}}, -- Ick and Krick
            {4, 100,   true,  3, 610, "Scourgelord Tyrannus", {252648, 252653}} -- Scourgelord Tyrannus
        }
    }
}
