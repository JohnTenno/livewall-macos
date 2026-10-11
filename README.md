# Livewall

A lightweight Wallpaper Engine–style live wallpaper app for macOS, written in Swift (SwiftPM, no Xcode required).

## Features

- **Video** wallpapers (`.mp4`, `.mov`, `.m4v`) looped seamlessly with `AVPlayerLooper`.
- **Web** wallpapers: a local `.html` file, a folder containing `index.html`, or any `http(s)` URL.
- **Metal shader** wallpapers with time, resolution and live mouse position (no Accessibility permission needed).
- One click-through window per display at desktop level — below Finder icons, above the system wallpaper, on every Space.
- Automatic pause when the desktop is fully covered, the screen sleeps or locks, Low Power Mode is on, or (optionally) on battery.
- Menu bar app (no Dock icon) with a library window and launch-at-login.
- **Lock screen**: renders the current video or shader to a 4K HEVC loop and swaps it into the Aerial selected in System Settings (original kept as a backup, restorable).
- **Steam Workshop**: searches Wallpaper Engine items through the Steam Web API and downloads video/web ones with SteamCMD using your own Steam session (requires owning Wallpaper Engine). Scene and application items are not supported.

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

## Lock screen

Since macOS 26, Aerials are cached per user in `~/Library/Application Support/com.apple.wallpaper/aerials/videos/<assetID>.mov`.
Livewall replaces that file (copying the original extended attributes so it is not re-downloaded), backs the original up to
`~/Library/Application Support/Livewall/AerialBackups/`, and restarts `WallpaperAgent`. Unofficial: a macOS update may restore the original.

## Steam Workshop

1. Create a Web API key at https://steamcommunity.com/dev/apikey and paste it in Settings → Steam (stored in the Keychain).
2. Enter your Steam login name and press "Log in to SteamCMD": Terminal opens so you type your password and Steam Guard code; Livewall never sees them.
3. SteamCMD lives in `~/Library/Application Support/Livewall/steamcmd/`.

Web items get a small shim for Wallpaper Engine's JS API (`wallpaperRegisterAudioListener` stubs and default `applyUserProperties`).

## Layout

| Folder | Contents |
| --- | --- |
| `App/` | Entry point and app delegate |
| `Model/` | `Wallpaper`, `WallpaperKind`, `WallpaperSource`, `AppSettings` |
| `Library/` | Persistent library (Application Support) and built-in shaders |
| `Rendering/` | `WallpaperRenderer` protocol, video/web/shader renderers, `RendererFactory` |
| `Desktop/` | Desktop windows per display, playback policy, `DesktopController` |
| `LockScreen/` | Aerial replacement, shader-to-video recorder, transcoder |
| `Workshop/` | Steam Web API client, SteamCMD wrapper, Wallpaper Engine project import |
| `UI/` | SwiftUI menu bar, library and settings |
