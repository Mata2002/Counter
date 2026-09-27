# Tallyho — working brief

Tallyho is an iPhone + Apple Watch counter app. The owner is not a Swift engineer: show him screenshots, explain choices in one plain sentence, push back when a request would make the app worse.

## Identity

- **Tally marks** (four strokes and a slash) are the brand: list progress, empty states, the icon.
- **The counting stage**: the tally's color fills the screen like liquid, rising toward the goal (count up) or draining toward it (count down). The numeral switches ink where the liquid crosses it.
- **"Tallyho!"** is the celebration when a goal is reached. Confetti shape comes from the theme (tally sticks, hearts, clovers, eggs, stars, bats, leaves, snow, goldfish and blossoms).
- Hierarchy comes from type and space (Things 3 is the reference), not boxes. The stage and the theme tiles are the only big color fields.

## Rules

- Every color comes from the active theme (`@Environment(\.theme)`). Never hard-code colors in views; system tints for swipe actions are the exception.
- Themes live in `design/themes/themes.js`. Run `node design/themes/build.js` after any change: it audits contrast (text 4.5:1; stage numeral 3:1 per region) and regenerates `Shared/Theme/ThemeCatalog.swift`.
- Holiday themes are US holidays plus Nowruz only.
- Data model changes must stay backward compatible: `Tally`, `TallyFolder` and `TallyData` decode with `decodeIfPresent`.
- New Swift files in `Shared/` that the widget or watch need: re-run `python3 tools/gen_project.py`.
- Hit targets are at least 44 pt. Every counting control has a VoiceOver label. Reduce Motion turns the liquid still and the confetti off.

## Verify

This repo builds on GitHub Actions (`.github/workflows/build.yml`, Xcode 26.6). Every push compiles the app, widgets and watch app, then screenshots the simulator with `-demo` data and uploads a `screenshots` artifact. Launch arguments: `-demo`, `-theme <id>`, `-screen <home|stage|stagedown|stagefree|celebrate|editor|new|settings|themes|finished|archive>`, `-split`, `-ghost`; on the watch `-demo -open`.
