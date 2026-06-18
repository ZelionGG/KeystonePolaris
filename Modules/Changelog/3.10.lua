local AddOnName, KeystonePolaris = ...;

local L = LibStub("AceLocale-3.0"):GetLocale(AddOnName, true);

KeystonePolaris.Changelog["3.10"] = {
    version_string = "3.10",
    release_date = "2026/06/18",
    header = {
        ["zhCN"] = {},
        ["zhTW"] = {},
        ["enUS"] = {
            title = "|TInterface\\OptionsFrame\\UI-OptionsFrame-NewFeatureIcon:16:16:0:0|t Version 3.10 - Font flags, inform fixes, and polish|r",
            text = "Version 3.10 adds configurable [Font Flags] in [Appearance], including Slug presets applied across the main display, previews, [Mob Percentages] and [Progress Bar] callouts. This update also fixes [Inform Group] chat messages showing an extra percent sign, keeps the [Progress Bar] hidden after leaving a dungeon, corrects [Algeth'ar Academy] route data, and refreshes the Russian translation.",
        },
        ["frFR"] = {
            title = "|TInterface\\OptionsFrame\\UI-OptionsFrame-NewFeatureIcon:16:16:0:0|t Version 3.10 - Options de police, corrections Inform et finitions|r",
            text = "La version 3.10 ajoute des [Options de police] configurables dans [Apparence], avec des préréglages incluant Slug appliqués à l'affichage principal, aux aperçus, aux [Pourcentages des monstres] et aux étiquettes de la [Barre de progression]. Cette mise à jour corrige aussi les messages [Informer le groupe] affichant un signe % en trop, masque la [Barre de progression] en quittant un donjon, corrige les données de route de l'[Académie Algeth'ar] et met à jour la traduction russe.",
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
    new = {
        ["zhCN"] = {},
        ["zhTW"] = {},
        ["enUS"] = {
            "Added configurable [Font Flags] in [Appearance], with presets such as Outline, Slug, and Outline + Slug applied across the main display, previews, [Mob Percentages], [Progress Bar] callouts, and import/export dialogs. Outline + Slug is the default when unset.",
        },
        ["frFR"] = {
            "Ajout d'[Options de police] configurables dans [Apparence], avec des préréglages tels que Contour, Slug et Contour + Slug appliqués à l'affichage principal, aux aperçus, aux [Pourcentages des monstres], aux étiquettes de la [Barre de progression] et aux fenêtres d'import/export. Contour + Slug est le défaut lorsqu'aucune option n'est définie.",
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
            "Fixed [Inform Group] chat messages showing a trailing extra percent sign (e.g. \"34.15% %\") when using /say, /party, or /yell.",
            "Fixed the [Progress Bar] staying visible after leaving a Mythic+ dungeon instead of hiding with the main display.",
            "Fixed [Algeth'ar Academy] route ranks and trash percentages by correcting the Crawth and Overgrown Ancient boss order in dungeon data.",
        },
        ["frFR"] = {
            "Correction des messages [Informer le groupe] affichant un signe % en trop à la fin (ex. \"34.15% %\") avec /say, /party ou /yell.",
            "Correction de la [Barre de progression] restant visible après avoir quitté un donjon Mythique+, au lieu de se masquer avec l'affichage principal.",
            "Correction des rangs de route et des pourcentages de trash à l'[Académie Algeth'ar] en corrigeant l'ordre des boss Tricérabec et Ancien embroussaillé dans les données du donjon.",
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
