# Keystone Polaris

## [3.9](https://github.com/ZelionGG/KeystonePolaris/releases/tag/3.9) (2026-06-03)

[Full Changelog](https://github.com/ZelionGG/KeystonePolaris/compare/3.8...3.9) [Previous Releases](https://github.com/ZelionGG/KeystonePolaris/releases)

> **Version 3.9 - Progress bar, profiles, and dungeons fixes**
>
> Version 3.9 brings a new **Progress Bar** for Mythic+ enemy forces, with boss thresholds, live preview, and full appearance controls. This update also adds profile sharing, improves dungeon progression accuracy, fixes combat-related taint issues, and refreshes several translations.

- 🆕 _**NEW** -_ Added an highly customizable **Progress Bar**, visual enemy-forces bar with boss tick marks, hover tooltip (per-section and per-boss status), optional callout, gradient and border options, live preview in options, custom-route support, enabled by default.
- 🆕 _**NEW** -_ Added profile sharing, export your current setup (settings + routes) or only your settings, then import it later into any profile.
- 🛠️ _**IMPROVEMENT** -_ Updated the Midnight compatibility warning to list only currently disabled core features, **Mob Percentages** is no longer shown as disabled.
- 🛠️ _**IMPROVEMENT** -_ Chinese translation updated, thank you **Toothache-xDD**.
- 🛠️ _**IMPROVEMENT** -_ Russian translation updated, thank you **Hollicsh**.
- 🐞 _**BUGFIX** -_ Fixed combat taint on the **Inform Group** secure button, macro attributes are no longer updated during combat lockdown.
- 🐞 _**BUGFIX** -_ Fixed combat taint on the **Group Reminder** Mythic+ teleport button by deferring the popup until combat ends.
- 🐞 _**BUGFIX** -_ Fixed **Algeth'ar Academy** boss criteria and section order after kills (e.g. Overgrown Ancient before Crawth).
- 🐞 _**BUGFIX** -_ Fixed **Pit of Saron** progression ignoring the **Quarry** intermediate objective so percentages stay aligned after the second boss.
