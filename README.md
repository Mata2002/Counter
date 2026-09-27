# Tallyho

A counter app for iPhone and Apple Watch. Count anything, up to a goal, down to zero, or just keep going.

## Open and run

1. Open `Tallyho.xcodeproj` in Xcode 26.
2. Pick the **Tallyho** scheme and your iPhone, then press Run. The watch app installs with it.
3. Signing: the project uses team `AT4H4G56UK` (from your Hydra project) with automatic signing. If Xcode asks, choose your team under *Signing & Capabilities* for all three targets: **Tallyho**, **TallyhoWidgetsExtension** and **Tallyho Watch App**.
4. The app and its widgets share data through the app group `group.MMT.Tallyho`. Xcode registers it automatically the first time you build with your team.

**Apple Watch.** The **Tallyho** scheme only runs on an iPhone. That's why picking a watch simulator with it says the platform doesn't match. To try the watch:

- **On your devices:** run the **Tallyho** scheme on your iPhone. The watch app installs on the paired watch by itself (Watch app on the iPhone → Tallyho → Show on Apple Watch, if it doesn't).
- **In the simulator:** pick the **Tallyho Watch App** scheme, then a watch simulator that's paired with an iPhone simulator (it's listed as "Apple Watch … via iPhone …"). To see counts sync, run **Tallyho** on that iPhone simulator too.

The Xcode console prints a lot of system chatter in the simulator (haptics, keyboard, `WCSession counterpart app not installed`). None of it is an error in Tallyho: the simulator has no haptic engine, and the phone logs the watch message when no watch app is installed. The app now checks for an installed watch app before sending, so that last one should stop.

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
- Touch, hold and move: the preview lets go and you're dragging the tally. Drop it on a folder, or on a tally inside one, to move it there. Drop it on **New folder** at the end of the list to start a folder with it. Near the top or bottom edge, the list scrolls.

**Sort and filter.** Last used, closest to or farthest from the goal, name, newest, oldest, highest count. Filter by direction, tags or goal, and show hidden items. In Settings you can split counting up and counting down into two panes.

**Finished, Archive and Hidden** live in Settings. Finished tallies stay filed under the folder they came from, can be sorted and filtered by tag, and can be started again.

**Themes.**
- Everyday themes: Riso, Night Shift, Sorbet, Blueprint, Chalk, Espresso, Swiss, Citrus.
- Holiday themes: New Year, Valentine's, St. Patrick's, Easter, Fourth of July, Halloween, Thanksgiving, Christmas and Nowruz.
- Each holiday brings its own confetti.
- Shuffle favorites daily or on each open. Holidays switch on by themselves and switch back afterwards.
- Every theme has a light and a dark version. Choose **Appearance: Device, Light or Dark** in Settings. The dark versions of bright themes are dimmed so a full-screen color isn't glaring at night. The watch always uses the dark version.

**Widgets.** Small and medium Home Screen widgets with working + and − buttons, in your theme and appearance: the liquid at its level, tally marks toward the goal, and confetti once you get there. Lock Screen widgets. A Control Center control, which also works on the Action button. Choose the tally by editing the widget.

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

Theme colors come from `design/themes/themes.js`, each theme in its home appearance. `node design/themes/build.js` derives the other appearance, audits both (it fails if any text or counting number isn't readable), and regenerates `Shared/Theme/ThemeCatalog.swift`.

Every push builds all three targets on GitHub Actions and screenshots the simulator. The screenshots are under Actions → the run → *screenshots* artifact.
