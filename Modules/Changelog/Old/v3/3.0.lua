local AddOnName, KeystonePolaris = ...;

KeystonePolaris.Changelog["3.0"] = {
    version_string = "3.0",
    release_date = "2025/10/06",
    important = {
        ["zhCN"] = {},
        ["zhTW"] = {},
        ["enUS"] = {
            "|cff40e0d0A NEW NAME FOR A BIGGER VISION|r\n\n"
            .. "[Keystone Percentage Helper] becomes [Keystone Polaris] — a bold step that reflects the Mythic+ Swiss-army-knife DNA I imagined and built with the community. \n\n"
            .. "Your settings are migrated automatically (no action needed), if you happen to lose your settings, please report it and copy the [KeystonePercentageHelper.lua] in your [WTF/Account/YourAccountName/SavedVariables] folder to a new [KeystonePolaris.lua] file to get your settings back (close the game before doing that). \n\n"
            .. "New name. Same speed. Bigger ambitions. Follow the star — Polaris. [#68]",
            "TOC updated for patch [11.2.5].",
        },
        ["frFR"] = {
            "|cff40e0d0UN NOUVEAU NOM POUR UNE PLUS GRANDE VISION|r \n\n"
            .. "[Keystone Percentage Helper] devient [Keystone Polaris] — une étape ambitieuse qui reflète l'ADN de couteau suisse Mythique+ que j'ai voulu, imaginé et construit avec la communauté. \n\n"
            .. "Vos paramètres sont migrés automatiquement (aucune action requise), si vous veniez à perdre vos paramètres, n'hésitez pas à le signaler sur GitHub, et, en solution alternative, vous pouvez copier le [KeystonePercentageHelper.lua] dans votre dossier [WTF/Account/YourAccountName/SavedVariables] dans un nouveau fichier [KeystonePolaris.lua] (fermez le jeu avant de le faire). \n\n"
            .. "Nouveau nom. Même énergie. Plus d’ambition. Suivez l’étoile — Polaris. [#68]",
            "Mise à jour du TOC pour le patch [11.2.5].",
        },
        ["koKR"] = {},
        ["ruRU"] = {
            "|cff40e0d0НОВОЕ ИМЯ ДЛЯ БОЛЬШЕГО ВИДЕНИЯ|r\n\n"
            .. "[Keystone Percentage Helper] становится [Keystone Polaris] - смелый шаг, отражающий ДНК швейцарского армейского ножа M+, которую я придумал и воплотил вместе с сообществом. \n\n"
            .. "Ваши настройки переносятся автоматически (никаких действий не требуется). Если Вы случайно потеряли свои настройки, сообщите об этом и скопируйте файл [KeystonePercentageHelper.lua] из папки [WTF/Account/ВашеИмяАккаунта/SavedVariables] в новый файл [KeystonePolaris.lua], чтобы вернуть настройки (перед этим закройте игру). \n\n"
            .. "Новое имя. Та же скорость. Большие амбиции. Следуй за звездой - Полярис. [#68]",
            "Обновление файла TOC для патча [11.2.5].",
        },
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
            "Introducing a unified display with optional [Total required for section], [Current percentage] and [Pull percentage] (Requires MDT), projected values (parenthesis) in combat for Required/Current, suffixes per line, configurable layout (single-line or multi-line), and a switch between [percentage] and [count-based] modes. [#40, #69]",
            "Introducing [Test Mode], a new feature that allows you to simulate multiple Mythic+ situations (out-of-fight section in progress, pull in progress with a section in progress, section percentage done, ...) [#71].",
            "Introducing [Changelog Translation], a new feature that allows you to translate the changelog into your language by copying it from a popup and pasting it into your translator tool."
        },
        ["frFR"] = {
            "Introduction d’un affichage unifié avec [Total requis pour la section], [Pourcentage actuel] et [Pourcentage du pull] (requiert MDT) en option, des valeurs prévisionnelles (entre parenthèses) en combat pour Required/Current, des suffixes par ligne, une mise en page configurable (une seule ligne ou multi‑lignes), et une bascule entre les modes [pourcentage] et [compte]. [#40, #69]",
            "Introduction d’un nouveau [Mode test] qui permet de simuler plusieurs situations Mythique+ (section en cours hors combat, pull en cours avec une section en cours, pourcentage de la section terminée, ...) [#71].",
            "Introduction d’une fonctionnalité de [Traduction du changelog] qui permet de traduire le changelog dans votre langue en copiant le changelog dans une fenêtre popup et en le collant dans votre outil de traduction."
        },
        ["koKR"] = {},
        ["ruRU"] = {
            "Представляем унифицированный дисплей с дополнительными параметрами [Всего требуется для части подземелья], [Текущий процент] и [Процент пулла] (требуется MDT), прогнозируемыми значениями (в скобках) в бою для 'Требуемый'/'Текущий', суффиксами на строку, настраиваемым макетом (однострочный или многострочный) и переключением между режимами [процентный] и [на основе количества]. [#40, #69]",
            "Представляем [Тестовый режим] - новую функцию, которая позволяет моделировать несколько ситуаций в М+ (прогресс части подземелья вне боя, прогресс пулла в текущей части подземелья, процент прогресса части подземелья и т.д.) [#71].",
            "Представляем [Перевод журнала изменений] - новую функцию, которая позволяет Вам переводить журнал изменений на Ваш язык, копируя его из всплывающего окна и вставляя в инструмент переводчика."
        },
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
            "Russian translation updated, thank you [Hollicsh]."
        },
        ["frFR"] = {
            "Traduction russe mise à jour, merci à [Hollicsh]."
        },
        ["koKR"] = {},
        ["ruRU"] = {
            "Русский перевод обновлен, спасибо [Hollicsh]."
        },
        ["deDE"] = {},
        ["esES"] = {},
        ["esMX"] = {},
        ["itIT"] = {},
        ["ptBR"] = {}
    }
}
