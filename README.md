# Sport Book Companion

A native **iOS / SwiftUI** training diary & companion for gridiron athletes — log your
sessions, run drills from the Playbook, keep your streak alive, and unlock achievements.
No betting, no accounts, no backend: everything lives on-device.

- **Bundle id:** `sport.diary.companion.iosapp`
- **Display name:** Sport Book Companion
- **Min iOS:** 16.6 • iPhone + iPad (portrait)
- **Stack:** 100% Swift + SwiftUI. No Kotlin/Multiplatform, no third-party deps.

## Features

| Screen | What it does |
| --- | --- |
| **Home** | Day-streak flame, weekly minutes goal ring, "Today's Focus" drill suggestion, training-load meter, recent sessions |
| **Diary** | Day-grouped log with per-type filters; tap to edit, long-press to delete |
| **Log Session** | Hand-built editor: type, duration, intensity, RPE, mood, notes, tags, date |
| **Playbook** | Drill library grouped by training type; tap a drill for coaching cues and one-tap logging |
| **Progress** | Stat tiles, last-7-days bar chart, time-by-type breakdown, achievement wall |
| **Profile** | Name, position, weekly goals, reset |

Persistence is a single JSON blob in `UserDefaults` written by the `Brain` object.
A fresh install starts with an empty diary (no seeded/mock sessions); the Playbook ships
with a built-in drill library.

## Build & run

The Xcode project is generated from `iosApp/project.yml` with [xcodegen](https://github.com/yonyz/xcodegen):

```sh
cd iosApp
xcodegen generate
open SportBookCompanion.xcodeproj   # then ⌘R, or:
xcodebuild -scheme iosApp -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' build
```

> Set your signing team in Xcode (Target → Signing & Capabilities) before running on a device.

## Layout

```
iosApp/
  project.yml                 # xcodegen spec (source of truth)
  iosApp/
    iOSApp.swift              # @main entry
    ContentView.swift         # root shell, custom tab bar, splash, shared UI bits
    Brain.swift               # the one big state/store/theme object
    Home.swift Diary.swift Playbook.swift Progress.swift Profile.swift
    Assets.xcassets/          # football-themed art + app icon
5050-Assets/                  # original source artwork
design.png                    # promotional reference
5050-Sport-Book-Companion-Screenshots/   # iPhone SE (3rd gen) store screenshots
```
