std = 'lua51'
codes = true
max_line_length = false

exclude_files = {
    '**/.libraries/',
    '**/.history/',
    '**/Libs/',
    '**/libs/',
}

globals = {
    'StaticPopupDialogs',
}

read_globals = {
    'BackdropTemplateMixin',
    'C_AddOns',
    'C_ChallengeMode',
    'C_CVar',
    'C_DateAndTime',
    'C_LFGInfo',
    'C_LFGList',
    'C_Map',
    'C_MapExplorationInfo',
    'C_NamePlate',
    'C_ScenarioInfo',
    'C_Spell',
    'C_Texture',
    'C_Timer',
    'CANCEL',
    'ChatFontNormal',
    'CopyTable',
    'CreateColor',
    'CreateFrame',
    'DAMAGER',
    'date',
    'DEFAULT_CHAT_FRAME',
    'EJ_GetEncounterInfo',
    'ElvUI',
    'EXPANSION_NAME2',
    'EXPANSION_NAME3',
    'EXPANSION_NAME5',
    'EXPANSION_NAME6',
    'EXPANSION_NAME7',
    'EXPANSION_NAME8',
    'EXPANSION_NAME9',
    'EXPANSION_NAME10',
    'EXPANSION_NAME11',
    'GameTooltip',
    'GetBuildInfo',
    'GetCursorPosition',
    'GetLFGDungeonInfo',
    'GetLFGRoles',
    'GetLocale',
    'GetNumGroupMembers',
    'GetPhysicalScreenSize',
    'GetScreenHeight',
    'GetScreenWidth',
    'GetSpellInfo',
    'GetSubZoneText',
    'GetTexCoordsForRole',
    'GetZoneText',
    'GetTexCoordsForRoleSmallCircle',
    'GetTime',
    'HEALER',
    'hooksecurefunc',
    'InCombatLockdown',
    'IsAddOnLoaded',
    'IsInGroup',
    'IsInRaid',
    'IsSpellKnown',
    'LFGListInviteDialog',
    'LibStub',
    'MDT',
    'MethodDungeonTools',
    'NO',
    'OKAY',
    'Settings',
    'SettingsPanel',
    'StaticPopup_Show',
    'strsplit',
    'TANK',
    'time',
    'UIParent',
    'UISpecialFrames',
    'UnitAffectingCombat',
    'UnitExists',
    'UnitGroupRolesAssigned',
    'UnitGUID',
    'UnitIsGroupLeader',
    'UnitReaction',
    'wipe',
    'YES',
    'RURU',
    'KOKR',
    'ZHCN',
    'DEDE',
    'LFG_LIST_LANGUAGE_PTBR',
    'FRFR',
    'LEADER',
}

files['Locales/*.lua'] = {
    ignore = {
        '211',
    },
}

files['Data/**/*.lua'] = {
    ignore = {
        '211',
    },
}

files['Modules/Changelog/**/*.lua'] = {
    ignore = {
        '211',
    },
}
