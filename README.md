# Livewall

A lightweight Wallpaper Engine–style live wallpaper app for macOS, written in Swift (SwiftPM, no Xcode required).

## Features

- **Video** wallpapers (`.mp4`, `.mov`, `.m4v`) looped seamlessly with `AVPlayerLooper`.
- **Web** wallpapers: a local `.html` file, a folder containing `index.html`, or any `http(s)` URL.
- **Metal shader** wallpapers with time, resolution and live mouse position (no Accessibility permission needed).
- One click-through window per display at desktop level — below Finder icons, above the system wallpaper, on every Space.
- Automatic pause when the desktop is fully covered, the screen sleeps or locks, Low Power Mode is on, or (optionally) on battery.
- Menu bar app (no Dock icon) with a library window and launch-at-login.

## Build

```sh
swift test                  # unit tests, including compiling the built-in shaders
./scripts/bundle-app.sh     # produces build/Livewall.app
open build/Livewall.app
```

## Shader contract

A `.metal` file must define:

```metal
float4 wallpaper(float2 fragCoord, float2 resolution, float time, float2 mouse)
```

`fragCoord` and `mouse` are in pixels with the origin at the bottom-left (Shadertoy convention).
`time` is in seconds and freezes while paused.

## Web wallpaper events

Pages receive `livewall-pause` and `livewall-play` events on `window` so they can stop their own animation loops.

## Layout

| Folder | Contents |
| --- | --- |
| `App/` | Entry point and app delegate |
| `Model/` | `Wallpaper`, `WallpaperKind`, `WallpaperSource`, `AppSettings` |
| `Library/` | Persistent library (Application Support) and built-in shaders |
| `Rendering/` | `WallpaperRenderer` protocol, video/web/shader renderers, `RendererFactory` |
| `Desktop/` | Desktop windows per display, playback policy, `DesktopController` |
| `UI/` | SwiftUI menu bar, library and settings |
