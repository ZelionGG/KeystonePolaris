local AddOnName, KeystonePolaris = ...;
local L = LibStub("AceLocale-3.0"):GetLocale(AddOnName, true)

KeystonePolaris.defaults = {
    profile = {
        general = {
            fontSize = 12,
            textOpacity = 1,
            position = "CENTER",
            xOffset = 0,
            yOffset = 0,
            positioningDimBackground = false,
            positioningShowGrid = false,
            positioningGridSpacing = 60,
            informGroup = true,
            informChannel = "PARTY",
            showCompartmentIcon = true,
            showMinimapIcon = true,
            disableLoginMessage = true,
            minimapAngle = 225,
            mobPercentagesMigrationVersion = "",
            advancedOptionsEnabled = false,
            lastSeasonCheck = "",
            lastVersionCheck = "",
            lastChangelogAnnounce = "",
            rolesEnabled = {
                LEADER = true,
                TANK = true,
                HEALER = true,
                DAMAGER = true
            },
            -- Main display content options
            mainDisplay = {
                showCurrentPercent = true,            -- Show overall current enemy forces percent
                showCurrentPullPercent = true,        -- Show current MDT pull percent (if MDT is available)
                multiLine = true,                     -- Display extras on new lines instead of a single line
                showRequiredText = true,              -- Show the required/remaining text base
                requiredLabel = L["REQUIRED_DEFAULT"], -- Label for the required base value when numeric
                showSectionRequiredText = false,       -- Show the required/remaining text base
                sectionRequiredLabel = L["SECTION_REQUIRED_DEFAULT"], -- Label for the required base value when numeric
                currentLabel = L["CURRENT_DEFAULT"],   -- Label for current percent
                pullLabel = L["PULL_DEFAULT"],         -- Label for current pull percent
                showMilestones = true,                 -- Show milestone supplementary text and logic
                milestoneLabel = L["MILESTONE_DISPLAY_DEFAULT"], -- Label for milestone supplementary text
                customMilestonePrefixColor = false,    -- Use color.milestonePrefix instead of color.prefix for milestone labels
                formatMode = "percent",               -- Display format: "percent" or "count"
                singleLineSeparator = " | ",           -- Separator for single-line layout
                textAlign = "CENTER",                  -- Horizontal font alignment: LEFT, CENTER, RIGHT
                showProjected = false                   -- Append projected values next to Current/Required
            }
        },
        text = {
            font = "Friz Quadrata TT",
            fontFlags = KeystonePolaris.DEFAULT_FONT_FLAG_PRESET,
        },
        color = {
            inProgress = {r = 1, g = 1, b = 1, a = 1},
            finished = {r = 0, g = 1, b = 0, a = 1},
            missing = {r = 1, g = 0, b = 0, a = 1},
            prefix = {r = 1, g = 0.7960784, b = 0.2, a = 1},
            milestonePrefix = {r = 1, g = 0.7960784, b = 0.2, a = 1}
        },
        advanced = {},
        progressBar = {
            enabled = true,
            width = 250,
            height = 20,
            position = "CENTER",
            xOffset = 0,
            yOffset = 350,
            direction = "LEFT_TO_RIGHT",
            barTexture = "Blizzard Raid Bar",
            useGradient = false,
            gradientStartColor = { r = 1, g = 1, b = 1, a = 1 },
            gradientEndColor = { r = 0, g = 1, b = 0, a = 1 },
            overrideColors = false,
            completedColor = { r = 0, g = 1, b = 0, a = 1 },
            inProgressColor = { r = 1, g = 1, b = 1, a = 1 },
            missingColor = { r = 1, g = 0, b = 0, a = 1 },
            backgroundColor = { r = 0, g = 0, b = 0, a = 0.7 },
            borderStyle = "NONE",
            borderTexture = "Blizzard Dialog Gold",
            borderColor = { r = 0, g = 0, b = 0, a = 1 },
            borderSize = 2,
            borderInsets = 1,
            tickColor = { r = 1, g = 1, b = 1, a = 1 },
            tickWidth = 2,
            tickOverflow = 2,
            showMilestoneTicks = false,
            milestoneTickColor = { r = 1, g = 0.82, b = 0, a = 1 },
            milestoneTickWidth = 1,
            showCallout = true,
            calloutPosition = "ABOVE",
            calloutFont = "Friz Quadrata TT",
            calloutFontSize = 10,
            calloutTextColor = { r = 1, g = 0.82, b = 0, a = 1 },
            calloutBackgroundColor = { r = 0, g = 0, b = 0, a = 0.8 },
        },
    }
}

KeystonePolaris.defaults.profile.groupReminder = {
    enabled = true,
    showPopup = true,
    showChat = true,
    showPopupWhenGroupIsFull = false,
    suppressQuickJoinToast = false,
    showDungeonName = true,
    showGroupName = true,
    showGroupDescription = true,
    showAppliedRole = true,
    lastReminder = nil,
    popupXOffset = 0,
    popupYOffset = 0,
}
