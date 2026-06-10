local AddOnName, KeystonePolaris = ...

-- Define a single source of truth for dungeon data
KeystonePolaris.LEGION_DUNGEON_DATA = {
    -- Format: [shortName] = {id = dungeonID, bosses = {{bossID, percent, shouldInform, bossOrder, journalEncounterID}, ...}}
    BRH = { -- Black Rook Hold
        id = 199,
        mapID = 1501,
        teleportID = 424153,
        bosses = {
            {1, 16.03, false, 1, 1518},
            {2, 53.53, false, 2, 1653},
            {3, 84.62, true, 3, 1664},
            {4, 100, true, 4, 1672}
        }
    },
    CoEN = { -- Cathedral of Eternal Night
        id = 233,
        mapID = 1677,
        teleportID = 0,
        bosses = {
            {1, 39.68, false, 1, 1905},
            {2, 45.83, false, 2, 1906},
            {3, 81.26, false, 3, 1904},
            {4, 100, true, 4, 1878}
        }
    },
    CoS = { -- Court of Stars
        id = 210,
        mapID = 1571,
        teleportID = 393766,
        bosses = {
            {1, 48.95, false, 1, 1718},
            {2, 93.68, true, 2, 1719},
            {3, 100, true, 3, 1720}
        }
    },
    DHT = { -- Darkheart Thicket
        id = 198,
        mapID = 1466,
        teleportID = 424163,
        bosses = {
            {1, 28.57, false, 1, 1654},
            {2, 59.71, false, 2, 1655},
            {3, 78.39, true, 3, 1656},
            {4, 100, true, 4, 1657}
        }
    },
    EoA = { -- Eye of Azshara
        id = 197,
        mapID = 1456,
        teleportID = 0,
        bosses = {
            {1, 19.42, false, 1, 1480},
            {2, 40.78, false, 2, 1490},
            {3, 62.14, false, 4, 1491},
            {4, 92.24, false, 3, 1479},
            {5, 100, true, 5, 1492},
        }
    },
    HoV = { -- Halls of Valor
        id = 200,
        mapID = 1477,
        teleportID = 393764,
        bosses = {
            {1, 11.85, false, 1, 1485},
            {2, 79.63, false, 3, 1486},
            {3, 54.44, false, 2, 1487},
            {4, 100, true, 4, 1488},
            {5, 100, true, 5, 1489},
        }
    },
    MoS = { -- Maw of Souls
        id = 208,
        mapID = 1492,
        teleportID = 0,
        bosses = {
            {1, 32.67, false, 1, 1502},
            {2, 66, false, 2, 1512},
            {3, 100, true, 3, 1663},
        }
    },
    NL = { -- Neltharion's Lair
        id = 206,
        mapID = 1458,
        teleportID = 410078,
        bosses = {
            {1, 21.36, false, 1, 1662},
            {2, 60.91, false, 2, 1665},
            {3, 81.36, false, 3, 1673},
            {4, 100, true, 4, 1687}
        }
    },
    KZLO = { -- Return to Karazhan: Lower
        id = 227,
        mapID = 1651,
        teleportID = 410078,
        bosses = {
            {1, 39.68, false, 1, 1826},
            {2, 45.83, false, 2, 1825},
            {3, 81.26, false, 3, 1837},
            {4, 100, true, 4, 1835}
        }
    },
    KZUP = { -- Return to Karazhan: Lower
        id = 234,
        mapID = 1651,
        teleportID = 410078,
        bosses = {
            {1, 39.68, false, 1, 1836},
            {2, 45.83, false, 2, 1817},
            {3, 81.26, false, 3, 1818},
            {4, 100, true, 4, 1838}
        }
    },
    SotT = { -- Seat of the Triumvirate
        id = 239,
        mapID = 1753,
        teleportID = 1254551,
        bosses = {
            {1, 14.61, false, 1, 1979, "Zuraal the Ascended", 122313}, -- Zuraal the Ascended
            {2, 56.87, false, 2, 1980, "Saprish", {122316, 122319}}, -- Saprish
            {3, 100,   true,  3, 1981, "Viceroy Nezhar", 122056}, -- Viceroy Nezhar
            {4, 100,   true,  4, 1982, "L'ura", {124729, 125340}} -- L'ura
        },
        milestones = {
            {
                id = 1,
                label = "Before Nezhar's arena",
                thresholdPercent = 81.33,
                triggerType = "none",
                creationOrder = 1,
            },
        },
    },
    ARCW = { -- The Arcway
        id = 209,
        mapID = 1516,
        teleportID = 0,
        bosses = {
            {1, 39.68, false, 1, 1497},
            {2, 45.83, false, 2, 1498},
            {3, 81.26, false, 3, 1499},
            {4, 100, false, 4, 1500},
            {5, 100, true, 5, 1501},
        }
    },
    VotW = { -- Vault of the Wardens
        id = 207,
        mapID = 1493,
        teleportID = 0,
        bosses = {
            {1, 39.68, false, 1, 1467},
            {2, 45.83, false, 2, 1695},
            {3, 81.26, false, 3, 1468},
            {4, 100, false, 4, 1469},
            {5, 100, true, 5, 1470},
        }
    },
}
