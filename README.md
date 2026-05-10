<p align="center">
  <img src="OpenNotch/Resources/Assets.xcassets/AppIcon.appiconset/logo256.png" alt="OpenNotch logo" width="96" />
</p>

<h1 align="center">OpenNotch</h1>

<p align="center">
  <strong>Turn the MacBook notch into a living native surface.</strong>
</p>

<p align="center">
  OpenNotch is a native macOS app for notched MacBooks that turns the notch into a live system surface for media,
  downloads, AirDrop, timers, screen recording, connectivity events, lock-screen transitions, custom hardware HUDs,
  and a fully customizable interactive dashboard.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/macOS-14.6%2B-111111?logo=apple" alt="macOS 14.6 or later" />
  <img src="https://img.shields.io/badge/UI-SwiftUI%20%2B%20AppKit-0A84FF" alt="SwiftUI and AppKit" />
  <img src="https://img.shields.io/badge/Swift-5-F05138?logo=swift&logoColor=white" alt="Swift 5" />
  <a href="LICENSE">
    <img src="https://img.shields.io/github/license/Protope-Eiw/OpenNotch" alt="License" />
  </a>
</p>

<p>
  <img src="assets/readme/Player.png" alt="OpenNotch preview" width="100%" />
</p>

## Why OpenNotch

OpenNotch treats the MacBook notch like a compact native surface instead of a static cutout.
It stays close to the hardware shape until something important happens, then expands with queue-driven
presentation, gesture support, and system-aware feature routing.

The app is built with SwiftUI and AppKit, so the notch window, settings UI, and event handling feel
like part of macOS rather than a web-style overlay.

The notch engine is built from scratch — it completely replicates the logic, animations, and behavior
of a real Dynamic Island on an iPhone, unlike projects that borrow from existing libraries.

## Highlights

- **Live activities** for Now Playing, Downloads, AirDrop, Timer, Screen Recording, Focus, Personal Hotspot, and Lock Screen media surfaces
- **Temporary alerts** for charging, low battery, full battery, Bluetooth, Wi-Fi, VPN, Focus-off, and notch resize feedback
- **Custom hardware HUDs** replacing the default macOS overlays for brightness, keyboard brightness, and volume
- **Interactive dashboard** that opens on notch hover — an expandable panel with app launcher, time/date, system stats, and pomodoro timer
- **Adaptive app grid** that scales layout from 1×2 up to 3×4 depending on the number of pinned apps (up to 12)
- **Pill widget bar** showing up to two live metrics (CPU, memory, disk, network speed) as compact progress rings or text
- **Pomodoro inline editing** — adjust work duration directly from the dashboard using +/− controls without opening settings
- **Full display placement control** — choose which display the notch overlay appears on
- **Native interactions** including tap to expand, mouse drag gestures, trackpad swipes, swipe-to-dismiss, and swipe-to-restore
- **Extensive personalization** for notch width, height, background style, stroke options, animation presets, fullscreen behavior, and app language
- **Lock Screen controls** for sounds, media panel behavior, widget appearance, tint, and background brightness
- **Screen Recording indicator** that lights up in the notch while macOS reports active screen capture

## Dashboard & Overview

The dashboard opens when you hover over the notch. Inside it:

| Section | Description |
|---|---|
| App Launcher | Quick-launch pinned apps. Adaptive grid layout, optional hidden app names. |
| Time & Date | Large clock and date display, with optional weather. |
| System Info | Live CPU, RAM, and disk usage at a glance. |
| Pomodoro Timer | Inline work session countdown with +/− duration controls. |

Each section can be individually enabled or disabled in **Settings → Interface**.

## Settings

Settings are organized into four groups:

**Application**
- General — startup, display placement, language, appearance
- Permissions — accessibility, Bluetooth, media control access
- Notch — background, stroke, animation, resize feedback
- Interface — dashboard layout, app grid, pinned apps, overview visibility

**Media & Files**
- Now Playing, Downloads, Drag & Drop

**Connectivity**
- Focus, Bluetooth, Network

**System**
- Timer, Screen Recording, Battery, HUD, Lock Screen

## Installation

1. Clone or download the source and build from Xcode.
2. Drag the built app into `Applications`.
3. Launch the app and grant requested permissions.
4. If macOS blocks the first launch, allow it from `System Settings → Privacy & Security`.

## Requirements

- macOS 14.6 or later
- A MacBook with a hardware notch
- Feature-specific permissions as needed:
  - Accessibility for custom HUD interception
  - Bluetooth access for accessory status updates
  - Screen Recording access for audio-reactive Now Playing visualization

## Build From Source

```bash
git clone https://github.com/Protope-Eiw/OpenNotch.git
cd OpenNotch
open OpenNotch.xcodeproj
```

Run the `OpenNotch` scheme from Xcode. Swift Package Manager dependencies are resolved automatically.

## Repository Layout

```text
OpenNotch/
├── Application/        # App entry point, app delegate, window setup, and settings shell
├── Core/               # Shared models, protocols, services, and infrastructure
├── Features/
│   ├── DragAndDrop/
│   ├── Battery/
│   ├── Bluetooth/
│   ├── Download/
│   ├── Focus/
│   ├── HUD/
│   ├── LockScreen/
│   ├── Network/
│   ├── Notch/
│   ├── NowPlaying/
│   ├── Onboarding/
│   ├── ScreenRecording/
│   ├── Settings/
│   └── Timer/
├── Resources/          # Assets, localization, bundled media
└── Shared/             # Shared UI, helpers, and extensions

OpenNotchTests/
OpenNotchUITest/
```

## Architecture at a Glance

- `AppContainer` composes services, monitors, feature view models, coordinators, and window managers.
- `AppDelegate` manages app lifecycle, floating overlay window setup, workspace observers, and lock-screen handoff.
- `NotchEngine` owns the queue-driven notch presentation state machine for live activities, temporary alerts, transitions, and restore flows.
- `NotchViewModel` is the SwiftUI-facing layer for geometry, gestures, interactive resize, and engine-backed presentation state.
- `NotchEventCoordinator` routes system events while feature-specific handlers translate them into notch content.
- `SettingsViewModel` acts as a facade over dedicated settings stores for application, media/files, connectivity, battery, HUD, and lock-screen behavior.
- Feature view models provide domain state for battery, Bluetooth, downloads, network, now playing, screen recording, timer, AirDrop, and lock screen.

## Tech Stack

- SwiftUI for notch content and settings UI
- AppKit for windows, input handling, and macOS integration
- Combine for feature and settings streams
- [Lottie](https://github.com/airbnb/lottie-ios) for animation assets

## Localization

- System language fallback
- English
- Russian
- Spanish
- Simplified Chinese

## License

OpenNotch is released under the GNU General Public License v3.0. See [LICENSE](LICENSE) for details.
