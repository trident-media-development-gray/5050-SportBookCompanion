# KMP Platform-Specific Resources Guide

## Project Structure

```
Sample/
├── settings.gradle.kts          ← Root config: includes :composeApp and :app
├── build.gradle.kts             ← Root config: declares plugins (apply false)
├── gradle/libs.versions.toml   ← Version catalog (single source of truth)
│
├── app/                         ← Android application shell (entry point)
│   ├── build.gradle.kts         ← Android app plugin, depends on :composeApp
│   └── src/main/
│       ├── AndroidManifest.xml  ← Android launcher config, app_name, icon refs
│       ├── kotlin/.../MainActivity.kt
│       └── res/                 ← NATIVE Android resources (NOT Compose resources)
│           ├── values/strings.xml        ← app_name for launcher
│           ├── mipmap-hdpi/              ← Launcher icon 72x72
│           ├── mipmap-xhdpi/             ← Launcher icon 96x96
│           ├── mipmap-xxhdpi/            ← Launcher icon 144x144
│           └── mipmap-xxxhdpi/           ← Launcher icon 192x192
│
├── composeApp/                  ← KMP shared module (library)
│   ├── build.gradle.kts         ← KMP + Compose Multiplatform + Android library
│   └── src/
│       ├── commonMain/          ← Shared across ALL platforms
│       │   ├── composeResources/
│       │   │   ├── drawable/    ← Shared drawables (fallback)
│       │   │   ├── font/        ← Shared fonts
│       │   │   └── values/
│       │   │       └── strings.xml  ← Shared strings (fallback)
│       │   └── kotlin/...       ← Shared Kotlin code
│       │
│       ├── androidMain/         ← Android-specific overrides
│       │   ├── composeResources/
│       │   │   ├── drawable/          ← Android-specific drawables (OVERRIDE)
│       │   │   ├── drawable-hdpi/     ← DPI-specific (Android only)
│       │   │   ├── drawable-xhdpi/
│       │   │   ├── drawable-xxhdpi/
│       │   │   ├── drawable-xxxhdpi/
│       │   │   └── values/
│       │   │       └── strings.xml    ← Android-specific strings (OVERRIDE)
│       │   └── kotlin/...
│       │
│       └── iosMain/             ← iOS-specific overrides
│           ├── composeResources/
│           │   ├── drawable/          ← iOS-specific drawables (OVERRIDE)
│           │   └── values/
│           │       └── strings.xml    ← iOS-specific strings (OVERRIDE)
│           └── kotlin/...
│
└── iosApp/                      ← iOS application shell (Xcode project)
    ├── Configuration/Config.xcconfig  ← Bundle ID, team, app name
    └── iosApp/
        ├── Info.plist                 ← CFBundleDisplayName = iOS app name
        └── Assets.xcassets/
            └── AppIcon.appiconset/    ← iOS launcher icon (1024x1024)
```

---

## How Resource Resolution Works

### Compose Multiplatform Resources (composeResources/)

The Compose resource plugin resolves resources using source set priority:

```
platformMain/composeResources/ > commonMain/composeResources/
```

**Same file name = override.** If `sample_image.xml` exists in both `commonMain/composeResources/drawable/` and `androidMain/composeResources/drawable/`, Android uses the androidMain version, iOS falls back to commonMain.

**The `Res` class is generated from commonMain.** You always reference `Res.drawable.sample_image` — the plugin wires the correct file at compile time per platform.

### Resolution Examples

| Resource | commonMain | androidMain | iosMain | Android gets | iOS gets |
|----------|-----------|-------------|---------|-------------|----------|
| `Res.drawable.logo` | logo.png | logo.png | logo.png | androidMain | iosMain |
| `Res.drawable.icon` | icon.png | icon.png | (none) | androidMain | commonMain |
| `Res.drawable.bg` | bg.png | (none) | (none) | commonMain | commonMain |
| `Res.string.app_name` | "Shared" | "Android" | "iOS" | "Android" | "iOS" |
| `Res.string.greeting` | "Hello" | (none) | (none) | "Hello" | "Hello" |

---

## Different App Names Per Platform

### In-App Display Name (Compose resources)

Place in platform-specific `composeResources/values/strings.xml`:

```xml
<!-- androidMain/composeResources/values/strings.xml -->
<resources>
    <string name="app_name">App Name 1 (Android)</string>
</resources>

<!-- iosMain/composeResources/values/strings.xml -->
<resources>
    <string name="app_name">App Name 2 (iOS)</string>
</resources>
```

Use in code: `stringResource(Res.string.app_name)`

### Launcher/Home Screen Name (Native resources)

These are NOT Compose resources — they're native platform concepts:

**Android** — `app/src/main/res/values/strings.xml`:
```xml
<string name="app_name">App Name 1</string>
```
Referenced in `AndroidManifest.xml` via `android:label="@string/app_name"`.

**iOS** — `iosApp/iosApp/Info.plist`:
```xml
<key>CFBundleDisplayName</key>
<string>App Name 2</string>
```
Or in `Config.xcconfig`: `APP_NAME=App Name 2`

---

## Different Icons Per Platform

### Launcher Icons (Native — NOT Compose resources)

**Android** — Place density-specific PNGs in the `app` module:
```
app/src/main/res/
├── mipmap-hdpi/ic_launcher.png          (72x72)
├── mipmap-hdpi/ic_launcher_round.png    (72x72)
├── mipmap-xhdpi/ic_launcher.png         (96x96)
├── mipmap-xhdpi/ic_launcher_round.png   (96x96)
├── mipmap-xxhdpi/ic_launcher.png        (144x144)
├── mipmap-xxhdpi/ic_launcher_round.png  (144x144)
├── mipmap-xxxhdpi/ic_launcher.png       (192x192)
└── mipmap-xxxhdpi/ic_launcher_round.png (192x192)
```

**iOS** — Place a single 1024x1024 PNG:
```
iosApp/iosApp/Assets.xcassets/AppIcon.appiconset/app-icon-1024.png
```
Xcode auto-generates all required sizes from this.

### In-App Icons (Compose resources)

For icons used within your app UI (not launcher), use platform overrides:
```
androidMain/composeResources/drawable/my_icon.png   ← Android version
iosMain/composeResources/drawable/my_icon.png        ← iOS version
```

---

## DPI-Specific Drawables (Android Only)

Android supports density qualifiers in composeResources:

```
androidMain/composeResources/
├── drawable/            ← Default (mdpi baseline)
│   └── hero.png         (100x100)
├── drawable-hdpi/
│   └── hero.png         (150x150)
├── drawable-xhdpi/
│   └── hero.png         (200x200)
├── drawable-xxhdpi/
│   └── hero.png         (300x300)
└── drawable-xxxhdpi/
    └── hero.png         (400x400)
```

iOS does NOT use DPI qualifiers. For iOS, put the highest resolution version in:
```
iosMain/composeResources/drawable/hero.png   ← Single @3x resolution
```

Or if you want iOS to use @2x/@3x scale, use the Apple naming convention in the iosMain drawable folder — but Compose Multiplatform on iOS currently just picks the single file and scales it.

**Recommended approach for your game:**
- Put original full-resolution PNGs in `iosMain/composeResources/drawable/`
- Put DPI-specific resized versions in `androidMain/composeResources/drawable-{dpi}/`
- Put shared vector drawables (XML) in `commonMain/composeResources/drawable/`

---

## Fonts

Fonts are typically shared. Place in commonMain:
```
commonMain/composeResources/font/
├── my_font_regular.ttf
├── my_font_bold.ttf
└── my_font_black.ttf
```

If you need different fonts per platform (rare), the same override mechanism works:
```
androidMain/composeResources/font/my_font_regular.ttf
iosMain/composeResources/font/my_font_regular.ttf
```

---

## What Goes Where — Quick Reference

| Resource Type | Where | Why |
|---|---|---|
| Launcher icon (Android) | `app/src/main/res/mipmap-*/` | Native Android resource |
| Launcher icon (iOS) | `iosApp/.../AppIcon.appiconset/` | Native Xcode asset |
| Launcher app name (Android) | `app/src/main/res/values/strings.xml` | Referenced by AndroidManifest |
| Launcher app name (iOS) | `iosApp/iosApp/Info.plist` | CFBundleDisplayName |
| Shared in-app drawables | `commonMain/composeResources/drawable/` | Same on both platforms |
| Android-only drawables | `androidMain/composeResources/drawable/` | Override commonMain |
| Android DPI drawables | `androidMain/composeResources/drawable-{dpi}/` | Density-specific |
| iOS-only drawables | `iosMain/composeResources/drawable/` | Override commonMain |
| Shared strings | `commonMain/composeResources/values/strings.xml` | Fallback for both |
| Android-only strings | `androidMain/composeResources/values/strings.xml` | Override keys |
| iOS-only strings | `iosMain/composeResources/values/strings.xml` | Override keys |
| Shared fonts | `commonMain/composeResources/font/` | Usually shared |
| Shared files (audio, json) | `commonMain/composeResources/files/` | `Res.readBytes()` |

---

## Gradle Configuration Notes

### Two config files (matching your existing setup):

1. **`settings.gradle.kts`** — Root project config:
   - `pluginManagement` block with repositories
   - `dependencyResolutionManagement` block with repositories
   - `include(":composeApp")` — shared KMP library module
   - `include(":app")` — Android application module

2. **`build.gradle.kts` (root)** — Plugin declarations with `apply false`:
   - All plugins declared here but NOT applied — submodules apply them individually

### Module roles:
- **`:composeApp`** — `androidLibrary` + `kotlinMultiplatform` + `composeMultiplatform` — contains ALL shared code and compose resources
- **`:app`** — `androidApplication` — thin shell that `implementation(projects.composeApp)` and provides MainActivity + native Android resources
- **`iosApp/`** — NOT a Gradle module — it's an Xcode project that links the ComposeApp framework

---

## Common Pitfalls

1. **`composeResources` not `resources`** — The directory MUST be named `composeResources` (not `resources`) for the Compose plugin to generate `Res` accessors.

2. **File names must match exactly** — For an override to work, the file name in `androidMain/composeResources/drawable/foo.png` must match `commonMain/composeResources/drawable/foo.png` exactly.

3. **Don't put launcher icons in composeResources** — Launcher icons are native platform resources. Android reads them from `mipmap-*`, iOS from `Assets.xcassets`.

4. **Qualifier directories only work on Android** — `drawable-hdpi`, `drawable-night`, `values-es` etc. are Android resource qualifiers. They won't have any effect in iosMain.

5. **Generate Res class** — Make sure your composeApp `build.gradle.kts` has:
   ```kotlin
   compose.resources {
       publicResClass = true
       packageOfResClass = "your.package.generated.resources"
       generateResClass = always
   }
   ```
