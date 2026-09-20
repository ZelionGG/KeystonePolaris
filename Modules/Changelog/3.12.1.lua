local AddOnName, KeystonePolaris = ...;

local L = LibStub("AceLocale-3.0"):GetLocale(AddOnName, true);

KeystonePolaris.Changelog["3.12.1"] = {
    version_string = "3.12.1",
    release_date = "2026/09/18",
    header = {
        ["zhCN"] = {},
        ["zhTW"] = {},
        ["enUS"] = {
            title = "|TInterface\\OptionsFrame\\UI-OptionsFrame-NewFeatureIcon:16:16:0:0|t Version 3.12.1 - Settings freeze fix|r",
            text = "Version 3.12.1 stops the game from freezing after browsing [Custom Routes], then opening [Changelog] or another addon's settings. Huge thank you to [Zensunim] for the detailed reports that made this fix possible. This update also makes [Role Marker] easier to identify, keeps [Text Display] visible for every role, and should make [Progress Bar] options feel smoother.",
        },
        ["frFR"] = {
            title = "|TInterface\\OptionsFrame\\UI-OptionsFrame-NewFeatureIcon:16:16:0:0|t Version 3.12.1 - Correction des freezes|r",
            text = "La version 3.12.1 empêche le jeu de figer après avoir parcouru les [Routes personnalisées], puis ouvert les [Mises à jour] ou les options d'un autre addon. Un énorme merci à [Zensunim] pour les pistes détaillées qui ont permis cette correction. Cette mise à jour rend aussi le [Marqueur de rôles] plus identifiable, garde l'[Affichage du texte] visible pour tous les rôles, et devrait rendre les options de la [Barre de progression] plus fluides.",
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
            "Browsing [Custom Routes] then opening [Changelog] or another addon's settings should no longer freeze or crash the game. Season and expansion dungeon lists now use a dropdown in the top-right of the page. Huge thank you to [Zensunim] for the invaluable detailed reports.",
        },
        ["frFR"] = {
            "Parcourir les [Routes personnalisées] puis ouvrir les [Mises à jour] ou les options d'un autre addon ne devrait plus figer ni faire planter le jeu. Les listes de donjons des saisons et extensions passent par un menu déroulant en haut à droite de la page. Un énorme merci à [Zensunim] pour les précieuses pistes détaillées.",
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
    bugfix = {
        ["zhCN"] = {},
        ["zhTW"] = {},
        ["enUS"] = {
            "[Role(s) Required] no longer hides [Required] and [Current] on the main display. Only the [Inform Group] button is filtered by role.",
        },
        ["frFR"] = {
            "[Role(s) nécessaire(s)] ne masque plus [Requis] et [Actuel] sur l'affichage principal. Seul le bouton [Informer le groupe] est filtré par rôle.",
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
            "Sorry for the lack of transparency around [Role Marker]: it is now off by default and shows a title so it is clear the button comes from Keystone Polaris. You can turn [Show Title] off in the [Role Marker] settings. Profiles that already had it enabled are unchanged.",
            "The [Role Marker] default position is now above the [Progress Bar] instead of the center of the screen.",
            "The current expansion is highlighted in the [Custom Routes] list.",
            "Changing [Progress Bar] options should feel smoother. Feedback on [GitHub] would be appreciated and would help me a lot!"
        },
        ["frFR"] = {
            "Désolé pour le manque de transparence autour du [Marqueur de rôles] : il est désormais désactivé par défaut et affiche un titre pour indiquer que le bouton vient de Keystone Polaris. Vous pouvez désactiver [Afficher le titre] dans les options du [Marqueur de rôles]. Les profils qui l'avaient déjà activé ne changent pas.",
            "La position par défaut du [Marqueur de rôles] est désormais au-dessus de la [Barre de progression] plutôt qu'au centre de l'écran.",
            "L'extension en cours est mise en évidence dans la liste des [Routes personnalisées].",
            "Changer les options de la [Barre de progression] devrait sembler plus fluide. Un retour sur [GitHub] serait apprécié et m'aiderait beaucoup!",
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
