local AddOnName, KeystonePolaris = ...;

local L = LibStub("AceLocale-3.0"):GetLocale(AddOnName, true);

KeystonePolaris.Changelog["3.5"] = {
    version_string = "3.5",
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
            "Updated teleportIDs for various dungeons.",
        },
        ["frFR"] = {
            "Mise à jour des teleportIDs pour divers donjons.",
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
            "Keystone Polaris is now translated in Portuguese, thank you [roneicostajr].",
            "Added an option to show the group [Playstyle] in the [Group Reminder] module.",
        },
        ["frFR"] = {
            "Keystone Polaris est maintenant traduit en portugais, merci à [roneicostajr].",
            "Ajout d'une option pour afficher le [Style de jeu] du groupe dans le module [Rappel du groupe].",
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
        ["enUS"] = {
            "Fixing Lua errors with dungeons data export.",
            "Fixing multiple Lua errors happening in various situations.",
        },
        ["frFR"] = {
            "Correction des erreurs Lua causées par l'exportation des données de donjons.",
            "Correction de plusieurs erreurs Lua survenant dans diverses situations.",
        },
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
            "Added a [!KeystonePolaris:] prefix to the dungeons export strings.",
            "The [Inform Group] button should no longer appear on bosses where the option is disabled.",
            "Russian translation updated, thank you [Hollicsh].",
            "Replaced some localized strings with Blizzard's GlobalStrings.",
            "Renamed the [Inform Group] options to [Inform Group Button].",
        },
        ["frFR"] = {
            "Ajout d'un préfixe [!KeystonePolaris:] aux chaînes d'exportation des donjons.",
            "Le bouton [Informer le groupe] ne s'affiche plus sur les boss où l'option est désactivée.",
            "Traduction russe mise à jour, merci à [Hollicsh].",
            "Remplacement de certaines chaînes localisées par les GlobalStrings de Blizzard.",
            "Renommage des options [Informer le groupe] en [Bouton Informer le groupe].",
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
