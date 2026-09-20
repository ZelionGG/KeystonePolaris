local AddOnName, KeystonePolaris = ...;

local L = LibStub("AceLocale-3.0"):GetLocale(AddOnName, true);

KeystonePolaris.Changelog["3.12"] = {
    version_string = "3.12",
    release_date = "2026/09/16",
    header = {
        ["zhCN"] = {},
        ["zhTW"] = {},
        ["enUS"] = {
            title = "|TInterface\\OptionsFrame\\UI-OptionsFrame-NewFeatureIcon:16:16:0:0|t Version 3.12 - Role Marker and Midnight season 2 routes|r",
            text = "Version 3.12 adds the [Role Marker] module: a clickable button that marks the tank and/or healer in your party. Midnight protects raid markers, so this cannot run automatically. Default routes for the dungeons of the Midnight Mythic+ season 2 have been updated. This update also adds a New Feature icon on unread settings, improves [Show Anchor] positioning, and adds a [Group Reminder] option when you are the group leader and the party is full.",
        },
        ["frFR"] = {
            title = "|TInterface\\OptionsFrame\\UI-OptionsFrame-NewFeatureIcon:16:16:0:0|t Version 3.12 - Marqueur de rôles et routes Midnight saison 2|r",
            text = "La version 3.12 ajoute le module [Marqueur de rôles] : un bouton cliquable pour marquer le tank et/ou le soigneur du groupe. Midnight protège les marqueurs, donc ce n'est pas automatique. Les routes par défaut des donjons de la saison 2 de Mythique+ Midnight ont été mises à jour. Cette mise à jour ajoute aussi une icône de nouveauté sur les options non lues, améliore le positionnement via [Afficher l'ancrage] et ajoute une option de [Rappel de Groupe] lorsque vous êtes le chef et que le groupe est complet.",
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
            "Updated default boss percentages for Midnight Mythic+ season 2: [Murder Row], [Den of Nalorakk], [The Blinding Vale], [Voidscar Arena], [Altar of Fangs], [Ruby Life Pools], [Temple of Sethraliss], and [Kings' Rest].",
        },
        ["frFR"] = {
            "Mise à jour des pourcentages de boss par défaut pour Midnight Mythique+ saison 2 : [Allée du meurtre], [Antre de Nalorakk], [Val Aveuglant], [Arène de la Cicatrice du Vide], [Autel des Crochets], [Bassins de l’Essence rubis], [Temple de Sephraliss] et [Repos des rois].",
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
            "Added the [Role Marker] module: click a button to mark selected tank and/or healer roles in a 5-player group. Icons are configurable, and [Show Anchor] moves the button with the rest of the display. A click is required because Midnight protects raid markers. The button lists only roles present in the party.",
            "Added a New Feature icon on unread options in the settings tree. [Role Marker] is the first module to use it: the icon sits on [Modules] while collapsed, then on [Role Marker] until the panel is opened.",
            "[Show Anchor] now focuses the component you opened it from (display, [Progress Bar], or [Role Marker]). Right-click a component to edit its X/Y offsets in a popup beside it. The dashed outline includes the progress bar callout.",
            "Added an option to show the [Group Reminder] popup when your Mythic+ group is full and you are the group leader.",
        },
        ["frFR"] = {
            "Ajout du module [Marqueur de rôles] : un clic pose les marques du tank et/ou du healer dans un groupe de 5. Icônes configurables, y compris -aucun-, et [Afficher l'ancrage] déplace le bouton avec le reste de l'affichage. Un clic est obligatoire car Midnight protège les marqueurs. Le bouton n'affiche que les rôles présents dans le groupe.",
            "Ajout d'une icône de nouveauté sur les options non lues dans l'arbre des paramètres. [Marqueur de rôles] est le premier module concerné : l'icône s'affiche sur [Modules] tant que le groupe est replié, puis sur [Marqueur de rôles] jusqu'à l'ouverture du panneau.",
            "[Afficher l'ancrage] cible désormais le composant depuis lequel vous l'avez ouvert (affichage, [Barre de progression] ou [Marqueur de rôles]). Clic droit sur un composant pour modifier ses décalages X/Y dans une popup à côté. Le cadre pointillé inclut l'étiquette de la barre de progression.",
            "Ajout d'une option pour afficher la popup de [Rappel de Groupe] lorsque votre groupe Mythique+ est complet et que vous en êtes le chef.",
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
            "Fixed [Temple of Sethraliss] [MythicDungeonTools] import.",
            "Opening [Changelog] should no longer freeze the Settings panel.",
            "Canceling [Show Anchor] no longer leaves preview milestone ticks on the [Progress Bar].",
        },
        ["frFR"] = {
            "Correction de l'import [MythicDungeonTools] du [Temple de Sephraliss].",
            "L'ouverture des [Mises à jour] ne devrait plus figer le panneau des paramètres.",
            "Annuler [Afficher l'ancrage] ne laisse plus de ticks de milestones de prévisualisation sur la [Barre de progression].",
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
            "Korean translation updated, thank you [BlueSea-jun].",
            "Removed the New Feature icon from each title in [Modules Overview] so it is not confused with unread features.",
        },
        ["frFR"] = {
            "Traduction coréenne mise à jour, merci à [BlueSea-jun].",
            "Suppression de l'icône de nouveauté sur chaque titre dans [Aperçu des modules] pour ne plus la confondre avec les fonctionnalités non lues.",
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
