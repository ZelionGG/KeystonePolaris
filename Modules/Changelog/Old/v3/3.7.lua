local AddOnName, KeystonePolaris = ...;

local L = LibStub("AceLocale-3.0"):GetLocale(AddOnName, true);

KeystonePolaris.Changelog[3700] = {
    version_string = "3.7",
    release_date = "2026/04/08",
    header = {
        ["zhCN"] = {},
        ["zhTW"] = {},
        ["enUS"] = {
            title = "|TInterface\\OptionsFrame\\UI-OptionsFrame-NewFeatureIcon:16:16:0:0|t |cffffd700A smoother interface, at last|r",
            text = "This update gives the overall experience a real refresh. The [Positioning Mode] has been redesigned to feel more intuitive, easier to read, and more comfortable to use, while the [Settings] layout is now clearer as well with new sub-sections, making [Keystone Polaris] smoother to use every day. A huge thank you to [whatisboom] for the valuable help on this version.",
        },
        ["frFR"] = {
            title = "|TInterface\\OptionsFrame\\UI-OptionsFrame-NewFeatureIcon:16:16:0:0|t |cffffd700Une interface plus agreable, enfin|r",
            text = "Cette mise a jour apporte un vrai coup de frais à l'expérience d'utilisation. Le [Mode de positionnement] a été repensé pour être plus intuitif, plus lisible et plus confortable, tandis que l'organisation des [Options] gagne aussi en clarté avec de nouvelles sous-sections pour rendre [Keystone Polaris] plus agréable à utiliser au quotidien. Un énorme merci à [whatisboom] pour son aide précieuse sur cette version.",
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
            "The [Positioning Mode] is now easier to use, with a clearer drag-and-drop flow, an alignment grid, a dimmed background, dedicated controls, and better visual feedback while moving the UI.",
        },
        ["frFR"] = {
            "Le [Mode de positionnement] est maintenant plus simple à utiliser, avec un déplacement plus clair de l'interface, une grille d'alignement, un fond assombri, des contrôles dédiés et un meilleur retour visuel.",
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
            "Added an [About] page with contributors and support links.",
        },
        ["frFR"] = {
            "Ajout d'une page [À propos] avec les contributeurs et les liens de support.",
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
            "Fixed a few [Positioning Mode] issues that could show up in combat, when pressing [ESC], or while closing the mode.",
            "Fixed an issue where changing one color could unexpectedly affect another preview.",
            "Fixed the MDT mob percentage option so it is now properly disabled due to Midnight's APIs limitations.",
        },
        ["frFR"] = {
            "Correction de problèmes avec le [Mode de positionnement] pouvant apparaître en combat, en appuyant sur [Echap] ou à la fermeture du mode.",
            "Correction d'un problème où modifier une couleur pouvait aussi changer un autre aperçu de manière inattendue.",
            "Correction de l'option MDT liée au pourcentage des monstres, qui est désormais correctement désactivée en raison des limitations des API de Midnight.",
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
            "Reworked the [Settings] panel into a tree layout with dedicated sub-sections for a clearer and more comfortable navigation experience.",
            "Updated [prefixColor] to use [color.prefix], with an automatic migration for existing settings.",
            "The [Group Reminder] popup will now remember its position even after a reload.",
            "Improved the locale synchronization and validation workflow to make translations easier to maintain.",
        },
        ["frFR"] = {
            "Réorganisation du panneau d'[Options] sous la forme d'une arborescence avec des sous-sections dédiées pour rendre la navigation plus claire et plus agréable.",
            "Mise à jour du stockage de [prefixColor] vers [color.prefix], avec migration automatique des paramètres existants.",
            "La popup [Rappel de groupe] mémorise désormais sa position même après un rechargement de l'interface.",
            "Amélioration des outils de synchronisation et de validation des traductions afin de faciliter la maintenance des locales.",
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
