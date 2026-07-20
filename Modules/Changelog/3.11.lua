local AddOnName, KeystonePolaris = ...;

local L = LibStub("AceLocale-3.0"):GetLocale(AddOnName, true);

KeystonePolaris.Changelog["3.11"] = {
    version_string = "3.11",
    release_date = "2026/07/20",
    header = {
        ["zhCN"] = {},
        ["zhTW"] = {},
        ["enUS"] = {
            title = "|TInterface\\OptionsFrame\\UI-OptionsFrame-NewFeatureIcon:16:16:0:0|t Version 3.11 - Milestones, progress bar ticks, and Midnight season 2 prep|r",
            text = "Version 3.11 introduces [Milestones]: custom checkpoints with zone/subzone triggers, main display text, completion feedback, and [Progress Bar] tick markers. This update also prepares the Midnight Mythic+ season 2 dungeon pool, improves progress bar callouts and tooltips, and fixes preview issues.",
        },
        ["frFR"] = {
            title = "|TInterface\\OptionsFrame\\UI-OptionsFrame-NewFeatureIcon:16:16:0:0|t Version 3.11 - Milestones, repères de barre et préparation Midnight saison 2|r",
            text = "La version 3.11 ajoute les [Milestones] : points de contrôle personnalisés avec déclencheurs de zone/sous-zone, texte sur l'affichage principal, retour de complétion et repères sur la [Barre de progression]. Cette mise à jour prépare aussi le pool de donjons Midnight Mythique+ saison 2, améliore les étiquettes et infobulles de la barre de progression, et corrige des problèmes d'aperçu.",
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
            "Prepared Midnight Mythic+ season 2 rotation data (estimated US/EU start dates) including [Murder Row], [Den of Nalorakk], [The Blinding Vale], [Voidscar Arena], [Altar of Fangs], [Ruby Life Pools], [Temple of Sethraliss], and [Kings' Rest], with dungeon icon fallbacks for prep dungeons not yet registered in Mythic+ difficulty.",
        },
        ["frFR"] = {
            "Ajout des [Milestones] dans [Routes personnalisées] : créez des points de contrôle avec un libellé, un seuil de pourcentage total, un déclencheur optionnel Zone/Sous-zone (capture de la zone actuelle avec IDs AreaTable/uiMap portables) et un texte Inform par milestone. Les milestones actifs sont limités à la section du boss en cours.",
            "Ajout du support des milestones sur l'affichage principal dans [Affichage du texte] : activation, préfixe configurable (défaut \"Milestone:\"), couleur de préfixe optionnelle, coloration en zone, retour temporaire vert \"Milestone Percentage Done\" à la complétion, et scénarios d'aperçu avec texte milestone synthétique.",
            "Ajout de l'option [Afficher les repères milestone] sur la [Barre de progression], avec des infobulles unifiées qui mettent en avant le prochain boss ou milestone, et une étiquette qui cible ce même objectif.",
            "Préparation des données de rotation Midnight Mythique+ saison 2 (dates de début US/EU estimées) incluant [Allée du meurtre], [Antre de Nalorakk], [Val Aveuglant], [Arène de la Cicatrice du Vide], [Autel des Crochets], [Bassins de l’Essence rubis], [Temple de Sephraliss] et [Repos des rois], avec icônes de secours pour les donjons en préparation pas encore enregistrés en difficulté Mythique+.",
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
        },
        ["frFR"] = {
            "Correction des pourcentages requis pour les boss du [Point-nexus Xenas] pour le [Chef forge-cœur Kasreth] et la [Garde-cœur Nysarra].",
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
        ["enUS"] = {},
        ["frFR"] = {},
        ["koKR"] = {},
        ["ruRU"] = {},
        ["deDE"] = {},
        ["esES"] = {},
        ["esMX"] = {},
        ["itIT"] = {},
        ["ptBR"] = {}
    }
}