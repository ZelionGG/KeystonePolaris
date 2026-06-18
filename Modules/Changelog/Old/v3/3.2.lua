local AddOnName, KeystonePolaris = ...;

KeystonePolaris.Changelog["3.2"] = {
    version_string = "3.2",
    release_date = "2026/01/17",
    important = {
        ["zhCN"] = {},
        ["zhTW"] = {},
        ["enUS"] = {
            "Added the [Commands] section to the [General options] and a new [Help] command."
        },
        ["frFR"] = {
            "Ajout de la section [Commandes] dans les [Options générales] et une nouvelle commande [Help]."
        },
        ["koKR"] = {},
        ["ruRU"] = {
            "В раздел [Общие параметры] добавлен раздел [Команды], а также новая команда [Справка]."
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
            "Addon name is now using gradient coloring in chat and UI headers.",
            "|TInterface\\OptionsFrame\\UI-OptionsFrame-NewFeatureIcon:16:16:0:0|t Added the [Group Reminder] module, showing a popup on group invite with an optional chat recap (dungeon, group name, role).",
            "Added a [Minimap icon] with a toggle in the [General options].",
            "Added a [Compartment icon] toggle in the [General options].",
            "Added full support for all [Legion] Dungeons.",
            "Introduced the new [Remix] options category (yes, I know, it's a bit late...).",
            "Season start dates (and end dates) are now displayed directly in the [Options] menu.",
            "Automated the retrieval of boss names using Blizzard's API for better accuracy.",
            "Initial preparation for the upcoming [Midnight Season 1].",
            "Added a [Modules] section to the right panel of the [Modules] menu."
        },
        ["frFR"] = {
            "Le nom de l’addon est désormais coloré en dégradé dans le chat et les titres UI.",
            "|TInterface\\OptionsFrame\\UI-OptionsFrame-NewFeatureIcon:16:16:0:0|t Ajout du module [Rappel de groupe] avec un popup à l’invitation, un récap chat activable (donjon, nom du groupe, rôle).",
            "Ajout d'une icône [Minimap] activable dans les [Options générales].",
            "Ajout du paramétrage de l'activation de l'icône [Compartiment] dans les [Options générales].",
            "Ajout complet de tous les Donjons de [Legion].",
            "Introduction de la nouvelle catégorie d'options [Remix] (oui, je sais, c'est un peu tard...).",
            "Les dates de début (et de fin) de saison s'affichent désormais directement dans les options.",
            "Automatisation de la récupération des noms de boss via l'API Blizzard pour une meilleure fiabilité.",
            "Préparatifs initiaux pour la future [Saison 1 de Midnight].",
            "Ajout d'une liste des [Modules] à la droite du menu [Modules]."
        },
        ["koKR"] = {},
        ["ruRU"] = {
            "В названии дополнения теперь используется градиентная раскраска в заголовках чата и пользовательского интерфейса.",
            "|TInterface\\OptionsFrame\\UI-OptionsFrame-NewFeatureIcon:16:16:0:0|t Добавлен модуль [Групповое напоминание], отображающий всплывающее окно при приглашении в группу с возможностью краткого обзора чата (подземелье, название группы, роль).",
            "Добавлен [значок миникарты] с возможностью переключения в [Общие параметры].",
            "Добавлен переключатель [Значок отделения] в [Общие параметры].",
            "Добавлена ​​полная поддержка всех подземелий [Легиона].",
            "Добавлена ​​новая категория опций [Ремикс] (да, я знаю, немного поздновато...).",
            "Даты начала (и окончания) сезона теперь отображаются непосредственно в меню [Параметры].",
            "Автоматизировано получение имен боссов с использованием API Blizzard для повышения точности.",
            "Начальная подготовка к предстоящему [1-му сезону 'Полночь'].",
            "Добавлен раздел [Модули] в правую панель меню [Модули]."
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
        ["enUS"] = {
            "Fixed [Import All Dungeons] returning [Invalid import string]."
        },
        ["frFR"] = {
            "Correction du bouton [Importer tous les donjons] qui retournait [Chaîne d'import non valide]."
        },
        ["koKR"] = {},
        ["ruRU"] = {
            "Исправлена ​​ошибка, из-за которой при выполнении команды [Импорт всех подземелий] возвращалась ошибка [Недопустимая строка импорта]."
        },
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
            "|TInterface\\OptionsFrame\\UI-OptionsFrame-NewFeatureIcon:16:16:0:0|t Massive code reorganization and cleanup for better performance and easier maintenance.",
            "Added informative placeholders in the options menu for dungeons that are not yet implemented.",
            "Optimized locale initialization to reduce load times.",
            "Russian locale updated (thank you again Hollicsh)."
        },
        ["frFR"] = {
            "|TInterface\\OptionsFrame\\UI-OptionsFrame-NewFeatureIcon:16:16:0:0|t Réorganisation massive et nettoyage du code pour de meilleures performances et une maintenance facilitée.",
            "Ajout d'indicateurs visuels dans le menu d'options pour les donjons non implémentés en jeu.",
            "Optimisation du chargement des fichiers de langue.",
            "Mise à jour de la traduction russe (merci encore Hollicsh)."
        },
        ["koKR"] = {},
        ["ruRU"] = {
            "|TInterface\\OptionsFrame\\UI-OptionsFrame-NewFeatureIcon:16:16:0:0|t Масштабная реорганизация и очистка кода для повышения производительности и более простое обслуживание.",
            "В меню настроек добавлены информативные поля для подземелий, которые ещё не реализованы.",
            "Оптимизирована инициализация локали для сокращения времени загрузки.",
            "Обновлена русская локализация ​​(ещё раз спасибо, Hollicsh)."
        },
        ["deDE"] = {},
        ["esES"] = {},
        ["esMX"] = {},
        ["itIT"] = {},
        ["ptBR"] = {}
    }
}
