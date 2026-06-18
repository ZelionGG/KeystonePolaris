local AddOnName, KeystonePolaris = ...;

local L = LibStub("AceLocale-3.0"):GetLocale(AddOnName, true);

KeystonePolaris.Changelog["3.9"] = {
    version_string = "3.9",
    release_date = "2026/06/03",
    header = {
        ["zhCN"] = {},
        ["zhTW"] = {},
        ["enUS"] = {
            title = "|TInterface\\OptionsFrame\\UI-OptionsFrame-NewFeatureIcon:16:16:0:0|t Version 3.9 - Progress bar, profiles, and dungeons fixes|r",
            text = "Version 3.9 brings a new [Progress Bar] for Mythic+ enemy forces, with boss thresholds, live preview, and full appearance controls. This update also adds profile sharing, improves dungeon progression accuracy, fixes combat-related taint issues, and refreshes several translations.",
        },
        ["frFR"] = {
            title = "|TInterface\\OptionsFrame\\UI-OptionsFrame-NewFeatureIcon:16:16:0:0|t Version 3.9 - Barre de progression, profils et corrections de donjons|r",
            text = "La version 3.9 ajoute une nouvelle [Barre de progression] pour les forces ennemies en Mythique+, avec seuils de boss, aperçu en direct et réglages d'apparence complets. Cette mise à jour ajoute aussi le partage de profils, améliore la précision de la progression en donjon, corrige des problèmes de taint en combat et met à jour plusieurs traductions.",
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
            "Added an highly customizable [Progress Bar], visual enemy-forces bar with boss tick marks, hover tooltip (per-section and per-boss status), optional callout, gradient and border options, live preview in options, custom-route support, enabled by default.",
            "Added profile sharing, export your current setup (settings + routes) or only your settings, then import it later into any profile.",
        },
        ["frFR"] = {
            "Ajout d'une [Barre de progression] hautement personnalisable, barre des forces ennemies avec repères de boss, infobulle au survol (statut par section et par boss), étiquette optionnelle, dégradé et bordures, aperçu dans les options, prise en charge des routes personnalisées, activée par défaut.",
            "Ajout du partage de profil, exportez votre configuration complète (réglages + routes) ou seulement vos réglages, puis réimportez-les plus tard dans n'importe quel profil.",
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
            "Fixed combat taint on the [Inform Group] secure button, macro attributes are no longer updated during combat lockdown.",
            "Fixed combat taint on the [Group Reminder] Mythic+ teleport button by deferring the popup until combat ends.",
            "Fixed [Algeth'ar Academy] boss criteria and section order after kills (e.g. Overgrown Ancient before Crawth).",
            "Fixed [Pit of Saron] progression ignoring the [Quarry] intermediate objective so percentages stay aligned after the second boss.",
        },
        ["frFR"] = {
            "Correction du taint en combat sur le bouton sécurisé [Informer le groupe], les attributs de macro ne sont plus mis à jour pendant le verrouillage de combat.",
            "Correction du taint en combat sur le bouton de téléportation Mythique+ du [Rappel de groupe] en différant la fenêtre jusqu'à la fin du combat.",
            "Correction des critères de boss et de l'ordre de section à l'[Académie Algeth'ar] (ex. Ancien embroussaillé avant Tricérabec).",
            "Correction de la progression dans la [Fosse de Saron] en ignorant l'objectif intermédiaire de la [carrière] pour éviter un décalage de pourcentage après le second boss.",
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
            "Updated the Midnight compatibility warning to list only currently disabled core features, [Mob Percentages] is no longer shown as disabled.",
            "Chinese translation updated, thank you [Toothache-xDD].",
            "Russian translation updated, thank you [Hollicsh].",
        },
        ["frFR"] = {
            "Mise à jour de l'avertissement de compatibilité Midnight pour ne lister que les fonctionnalités core réellement désactivées, [Pourcentages des monstres] n'y figure plus.",
            "Traduction chinoise mise à jour, merci à [Toothache-xDD].",
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