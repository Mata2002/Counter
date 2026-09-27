# Tallyho

A counter app for iPhone and Apple Watch. Count anything, up to a goal, down to zero, or just keep going.

## Open and run

1. Open `Tallyho.xcodeproj` in Xcode 26.
2. Pick the **Tallyho** scheme and your iPhone, then press Run. The watch app installs with it.
3. Signing: the project uses team `AT4H4G56UK` (from your Hydra project) with automatic signing. If Xcode asks, choose your team under *Signing & Capabilities* for all three targets: **Tallyho**, **TallyhoWidgetsExtension** and **Tallyho Watch App**.
4. The app and its widgets share data through the app group `group.MMT.Tallyho`. Xcode registers it automatically the first time you build with your team.

To run only the watch app, pick the **Tallyho Watch App** scheme and your watch.

## What's in it

**Tallies.** A tally counts up (0 → 70, or 20 → 70) or down (70 → 0), by any step, with or without a goal. Tags, an emoji, one of six theme colors, and an optional notification when you reach the goal.

**The counting stage.** Tap a tally to open it full screen. The whole screen is the button: tap anywhere to count. The color rises as you count up and drains as you count down. Only the few floating controls don't count: close, more, tally settings, the undo step (−1) and reset. Swipe down to close. The screen stays awake while you count.

**Goals.** Reaching a goal triggers a "Tallyho!" celebration with confetti in the theme's style, a strong vibration you can feel in a pocket, and a notification if it happened from a widget or Siri. Finish the tally, or keep counting.

**Folders.** Group tallies in folders. Collapse them, hide them, or archive a whole folder with everything in it. An empty folder shows its last finished tally faded out, with "Again" to start it over.

**Lists.**
- Swipe left: Complete, Archive, Delete. A full swipe completes.
- Swipe right: Reset, Hide.
- Touch and hold: a preview with every action.
- The round button on each row counts without opening it.

**Sort and filter.** Last used, closest to or farthest from the goal, name, newest, oldest, highest count. Filter by direction, tags or goal, and show hidden items. In Settings you can split counting up and counting down into two panes.

**Finished, Archive and Hidden** live in Settings. Finished tallies stay filed under the folder they came from, can be sorted and filtered by tag, and can be started again.

**Themes.**
- Everyday themes: Riso, Night Shift, Sorbet, Blueprint, Chalk, Espresso, Swiss, Citrus.
- Holiday themes: New Year, Valentine's, St. Patrick's, Easter, Fourth of July, Halloween, Thanksgiving, Christmas and Nowruz.
- Each holiday brings its own confetti.
- Shuffle favorites daily or on each open. Holidays switch on by themselves and switch back afterwards.

**Widgets.** Small and medium Home Screen widgets with working + and − buttons. Lock Screen widgets. A Control Center control, which also works on the Action button. Choose the tally by editing the widget.

**Siri and Shortcuts.** "Count Push-ups in Tallyho."

**Apple Watch.** Your active tallies on the wrist. Tap anywhere to count, or turn the Digital Crown. Counts reach the iPhone, and are queued when it's out of reach. You can finish a tally from the watch.

## Project layout

| Folder | What |
|---|---|
| `Tallyho/` | iPhone app |
| `Shared/` | Model, themes, storage, App Intents and sync payloads, shared with the widget and the watch |
| `TallyhoWidgets/` | Widgets and the Control Center control |
| `TallyhoWatch/` | Apple Watch app |
| `Config/` | Entitlements and Info.plist fragments |
| `design/themes/` | Theme palettes (`themes.js`), contrast audit and Swift generator |
| `tools/gen_project.py` | Regenerates the Xcode project |

Theme colors come from `design/themes/themes.js`. After changing a palette, run `node design/themes/build.js`. It fails if a theme's text or counting numbers aren't readable, and it regenerates `Shared/Theme/ThemeCatalog.swift`.

Every push builds all three targets on GitHub Actions and screenshots the simulator. The screenshots are under Actions → the run → *screenshots* artifact.
