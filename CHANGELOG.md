# Keystone Polaris

## [3.11](https://github.com/ZelionGG/KeystonePolaris/releases/tag/3.11) (2026-07-27)

[Full Changelog](https://github.com/ZelionGG/KeystonePolaris/compare/3.10...3.11) [Previous Releases](https://github.com/ZelionGG/KeystonePolaris/releases)

> **Version 3.11 - Milestones, progress bar ticks, and Midnight season 2 prep**
>
> Version 3.11 introduces **Milestones**: custom checkpoints with zone/subzone triggers, main display text, completion feedback, and **Progress Bar** tick markers. This update also prepares the Midnight Mythic+ season 2 dungeon pool (start date TBD), refreshes season 2 default routes from PTR data, supports TBD season dates, adds chat update and login messages, and fixes the minimap icon tooltip.

- 🆕 _**NEW** -_ Added **Milestones** in **Custom Routes**: create checkpoints with a label, total percentage threshold, optional Zone/Subzone trigger (capture current zone with portable AreaTable/uiMap IDs), and per-milestone Inform text. Active milestones are gated by the current boss section.
- 🆕 _**NEW** -_ Added main display support for milestones under **Text Display**: toggle, configurable prefix (default "Milestone:"), optional custom prefix color, in-zone coloring, temporary green "Milestone Percentage Done" feedback on completion, and preview scenarios that show synthetic milestone text.
- 🆕 _**NEW** -_ Added optional **Show Milestone Ticks** on the **Progress Bar**, with unified tooltips that highlight the nearest upcoming boss or milestone, and a callout that targets that same nearest objective.
- 🆕 _**NEW** -_ Prepared Midnight Mythic+ season 2 rotation data (start date TBD) including **Murder Row**, **Den of Nalorakk**, **The Blinding Vale**, **Voidscar Arena**, **Altar of Fangs**, **Ruby Life Pools**, **Temple of Sethraliss**, and **Kings' Rest**, with dungeon icon fallbacks for prep dungeons not yet registered in Mythic+ difficulty.
- 🆕 _**NEW** -_ Season dates now support "TBD", showing Next/Current Season with a starts/ends soon alert when the date is still to be announced.
- 🆕 _**NEW** -_ Added a chat update announcement after each addon update, with a clickable **Open Changelog** link that opens the changelog (deferred until combat ends if needed) and dismisses until the next version.
- 🆕 _**NEW** -_ Added a login chat tip with slash-command hints, and a **Disable login message** option under **Interface**.
- 🛠️ _**IMPROVEMENT** -_ Russian translation updated, thank you **Hollicsh**.
- 🛠️ _**IMPROVEMENT** -_ Updated default boss percentages for Midnight season 2 routes using **WarcraftLogs PTR data** (routes are subject to change after the season starts).
- 🐞 _**BUGFIX** -_ Fixed **Nexus-Point Xenas** boss trash percentages for **Chief Corewright Kasreth** and **Corewarden Nysarra**.
- 🐞 _**BUGFIX** -_ Fixed the minimap icon tooltip appearing with a transparent background.
