local AddOnName, KeystonePolaris = ...;

local L = LibStub("AceLocale-3.0"):GetLocale(AddOnName, true);

KeystonePolaris.Changelog["3.11"] = {
    version_string = "3.11",
    release_date = "2026/07/27",
    header = {
        ["zhCN"] = {},
        ["zhTW"] = {},
        ["enUS"] = {
            title = "|TInterface\\OptionsFrame\\UI-OptionsFrame-NewFeatureIcon:16:16:0:0|t Version 3.11 - Milestones, progress bar ticks, and Midnight season 2 prep|r",
            text = "Version 3.11 introduces [Milestones]: custom checkpoints with zone/subzone triggers, main display text, completion feedback, and [Progress Bar] tick markers. This update also prepares the Midnight Mythic+ season 2 dungeon pool (start date TBD), refreshes season 2 default routes from PTR data, supports TBD season dates, adds chat update and login messages, and fixes the minimap icon tooltip.",
        },
        ["frFR"] = {
            title = "|TInterface\\OptionsFrame\\UI-OptionsFrame-NewFeatureIcon:16:16:0:0|t Version 3.11 - Milestones, repères de barre et préparation Midnight saison 2|r",
            text = "La version 3.11 ajoute les [Milestones] : points de contrôle personnalisés avec déclencheurs de zone/sous-zone, texte sur l'affichage principal, retour de complétion et repères sur la [Barre de progression]. Cette mise à jour prépare aussi le pool de donjons Midnight Mythique+ saison 2 (date de début à confirmer), met à jour les routes S2 par défaut depuis les données PTR, prend en charge les dates de saison TBD, ajoute des messages chat de mise à jour et de connexion, et corrige l'infobulle de l'icône de minimap.",
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
            "Added [Milestones] in [Custom Routes]: create checkpoints with a label, total percentage threshold, optional Zone/Subzone trigger (capture current zone with portable AreaTable/uiMap IDs), and per-milestone Inform text. Active milestones are gated by the current boss section.",
            "Added main display support for milestones under [Text Display]: toggle, configurable prefix (default \"Milestone:\"), optional custom prefix color, in-zone coloring, temporary green \"Milestone Percentage Done\" feedback on completion, and preview scenarios that show synthetic milestone text.",
            "Added optional [Show Milestone Ticks] on the [Progress Bar], with unified tooltips that highlight the nearest upcoming boss or milestone, and a callout that targets that same nearest objective.",
            "Prepared Midnight Mythic+ season 2 rotation data (start date TBD) including [Murder Row], [Den of Nalorakk], [The Blinding Vale], [Voidscar Arena], [Altar of Fangs], [Ruby Life Pools], [Temple of Sethraliss], and [Kings' Rest], with dungeon icon fallbacks for prep dungeons not yet registered in Mythic+ difficulty.",
            "Season dates now support \"TBD\", showing Next/Current Season with a starts/ends soon alert when the date is still to be announced.",
            "Added a chat update announcement after each addon update, with a clickable [Open Changelog] link that opens the changelog (deferred until combat ends if needed) and dismisses until the next version.",
            "Added a login chat tip with slash-command hints, and a [Disable login message] option under [Interface].",
        },
        ["frFR"] = {
            "Ajout des [Milestones] dans [Routes personnalisées] : créez des points de contrôle avec un libellé, un seuil de pourcentage total, un déclencheur optionnel Zone/Sous-zone (capture de la zone actuelle avec IDs AreaTable/uiMap portables) et un texte Inform par milestone. Les milestones actifs sont limités à la section du boss en cours.",
            "Ajout du support des milestones sur l'affichage principal dans [Affichage du texte] : activation, préfixe configurable (défaut \"Milestone:\"), couleur de préfixe optionnelle, coloration en zone, retour temporaire vert \"Milestone Percentage Done\" à la complétion, et scénarios d'aperçu avec texte milestone synthétique.",
            "Ajout de l'option [Afficher les repères milestone] sur la [Barre de progression], avec des infobulles unifiées qui mettent en avant le prochain boss ou milestone, et une étiquette qui cible ce même objectif.",
            "Préparation des données de rotation Midnight Mythique+ saison 2 (date de début à confirmer) incluant [Allée du meurtre], [Antre de Nalorakk], [Val Aveuglant], [Arène de la Cicatrice du Vide], [Autel des Crochets], [Bassins de l’Essence rubis], [Temple de Sephraliss] et [Repos des rois], avec icônes de secours pour les donjons en préparation pas encore enregistrés en difficulté Mythique+.",
            "Les dates de saison acceptent désormais \"TBD\", avec une alerte de début/fin bientôt lorsque la date n’est pas encore annoncée.",
            "Ajout d'une annonce chat après chaque mise à jour de l'addon, avec un lien cliquable [Ouvrir le changelog] qui ouvre les notes de version (différé hors combat si besoin) et ne réapparaît qu'à la prochaine version.",
            "Ajout d'un message chat de connexion avec les commandes slash, et d'une option [Désactiver le message de connexion] dans [Interface].",
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
            "Fixed [Nexus-Point Xenas] boss trash percentages for [Chief Corewright Kasreth] and [Corewarden Nysarra].",
            "Fixed the minimap icon tooltip appearing with a transparent background.",
        },
        ["frFR"] = {
            "Correction des pourcentages requis pour les boss du [Point-nexus Xenas] pour le [Chef forge-cœur Kasreth] et la [Garde-cœur Nysarra].",
            "Correction de l'infobulle de l'icône de minimap qui s'affichait avec un fond transparent.",
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
            "Updated default boss percentages for Midnight season 2 routes using [WarcraftLogs PTR data] (routes are subject to change after the season starts).",
        },
        ["frFR"] = {
            "Traduction russe mise à jour, merci à [Hollicsh].",
            "Mise à jour des pourcentages de boss par défaut pour les routes Midnight Mythique+ saison 2 en utilisant les données [WarcraftLogs issues des RPT] (les routes sont sujettes à changement après le début de la saison).",
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