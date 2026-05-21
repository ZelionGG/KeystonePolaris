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
    'C_LFGList',
    'C_Map',
    'C_NamePlate',
    'C_ScenarioInfo',
    'C_Spell',
    'C_Texture',
    'C_Timer',
    'CANCEL',
    'ChatFontNormal',
    'CopyTable',
    'CreateFrame',
    'DAMAGER',
    'date',
    'DEFAULT_CHAT_FRAME',
    'EJ_GetEncounterInfo',
    'ElvUI',
    'GameTooltip',
    'GetBuildInfo',
    'GetLFGRoles',
    'GetLocale',
    'GetNumGroupMembers',
    'GetScreenHeight',
    'GetScreenWidth',
    'GetSpellInfo',
    'GetTexCoordsForRole',
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
