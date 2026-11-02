# DiscordGlass

A Mac Discord voice overlay by [silentrosehill](https://github.com/silentrosehill): profile pictures, speaking rings, mute/deafen icons and right-click volume. Move, resize and adjust the glass in plugin settings.

## Install

Download **DiscordGlass-plugin.zip** from [Releases](https://github.com/silentrosehill/DiscordGlass/releases/latest).

1. Copy `discordGlass` into your Vencord source checkout at `src/userplugins/discordGlass`.
2. Copy `DiscordGlass Overlay.app` into `~/Library/Application Support/DiscordGlass/` (create the folder if needed).
3. In your Vencord checkout, run `pnpm build` and `pnpm inject`, then restart Discord and enable **DiscordGlass**.

Vencord custom plugins require a source build; there is no ZIP import button. [Official guide](https://docs.vencord.dev/installing/custom-plugins/).

macOS 15+. Native Liquid Glass on macOS 26+. The included helper is for Apple silicon and is ad-hoc signed, not notarized. This plugin requires Discord Desktop on macOS.

## Source

`discordGlass/` contains the Vencord plugin. `Overlay/` contains the native helper. Build the helper with `bash build.sh` using Xcode 27 Command Line Tools; it builds for your Mac's architecture.

GPL-3.0-or-later. Uses Vencord APIs by Vendicated and contributors. See [SECURITY.md](SECURITY.md).
