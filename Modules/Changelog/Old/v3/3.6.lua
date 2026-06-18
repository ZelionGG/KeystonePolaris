local AddOnName, KeystonePolaris = ...;

local L = LibStub("AceLocale-3.0"):GetLocale(AddOnName, true);

KeystonePolaris.Changelog["3.6"] = {
    version_string = "3.6",
    release_date = "2026/03/28",
    header = {
        ["zhCN"] = {},
        ["zhTW"] = {},
        ["enUS"] = {
            title = "|TInterface\\OptionsFrame\\UI-OptionsFrame-NewFeatureIcon:16:16:0:0|t |cffffd700" .. L["COMPATIBILITY_WARNING"] .. "|r",
            text = L["COMPATIBILITY_WARNING_MESSAGE"],
        },
        ["frFR"] = {
            title = "|TInterface\\OptionsFrame\\UI-OptionsFrame-NewFeatureIcon:16:16:0:0|t |cffffd700" .. L["COMPATIBILITY_WARNING"] .. "|r",
            text = L["COMPATIBILITY_WARNING_MESSAGE"],
        },
        ["koKR"] = {},
        ["ruRU"] = {},
        ["deDE"] = {},
        ["esES"] = {},
        ["esMX"] = {},
        ["itIT"] = {},
        ["ptBR"] = {}
    },
    important = {
        ["zhCN"] = {},
        ["zhTW"] = {},
        ["enUS"] = {
            "Added debouncing to additional in-dungeon update events to reduce event spikes and prevent lag during large pulls or mass enemy deaths (thank you [zaphon]).",
        },
        ["frFR"] = {
            "Ajout du système de regroupement des mises à jour sur d'autres événements en donjon afin de réduire les pics d'événements et éviter les ralentissements sur les gros pulls ou les morts de packs (merci [zaphon]).",
        },
        ["koKR"] = {},
        ["ruRU"] = {},
        ["deDE"] = {},
        ["esES"] = {},
        ["esMX"] = {},
        ["itIT"] = {},
        ["ptBR"] = {}
    },
    new = {
        ["zhCN"] = {},
        ["zhTW"] = {},
        ["enUS"] = {
            "Added [MythicDungeonTools] route import support in [Custom Routes]: Keystone Polaris can now detect the target dungeon, import boss percentages, rebuild the boss order, and open the matching dungeon options automatically.",
        },
        ["frFR"] = {
            "Ajout de la prise en charge de l'import des routes [MythicDungeonTools] dans les [Routes personnalisées] : Keystone Polaris peut maintenant détecter automatiquement le donjon ciblé, importer les pourcentages de boss, reconstruire l'ordre des boss et ouvrir directement les bonnes options.",
        },
        ["koKR"] = {},
        ["ruRU"] = {},
        ["deDE"] = {},
        ["esES"] = {},
        ["esMX"] = {},
        ["itIT"] = {},
        ["ptBR"] = {}
    },
    bugfix = {
        ["zhCN"] = {},
        ["zhTW"] = {},
        ["enUS"] = {},
        ["frFR"] = {},
        ["koKR"] = {},
        ["ruRU"] = {},
        ["deDE"] = {},
        ["esES"] = {},
        ["esMX"] = {},
        ["itIT"] = {},
        ["ptBR"] = {}
    },
    improvment = {
        ["zhCN"] = {},
        ["zhTW"] = {},
        ["enUS"] = {
            "Russian translation updated, thank you [Hollicsh].",
        },
        ["frFR"] = {
            "Traduction russe mise à jour, merci à [Hollicsh].",
        },
        ["koKR"] = {},
        ["ruRU"] = {},
        ["deDE"] = {},
        ["esES"] = {},
        ["esMX"] = {},
        ["itIT"] = {},
        ["ptBR"] = {}
    }
}
