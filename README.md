# DiscordGlass

A Mac Discord voice overlay by [silentrosehill](https://github.com/silentrosehill).

Glass styling, profile pictures, speaking rings, mute/deafen icons and right-click volume controls. Move and resize it in **Edit position**.

## Install

1. Install [Vencord](https://vencord.dev/download/) for Discord Desktop.
2. Download **DiscordGlass-Mac.zip** from [Releases](https://github.com/silentrosehill/DiscordGlass/releases/latest).
3. Open **DiscordGlass Patch.app** and click **Update DiscordGlass**.
4. Enable **DiscordGlass** in Vencord’s Plugins settings.

Use the same patch app for updates. Overlay-only updates keep Discord running; plugin updates ask before restarting it.

macOS 15+. Native Liquid Glass on macOS 26+. The download is for Apple silicon; Intel users can build from source. The updater needs Python 3. Client mods are unsupported by Discord. The apps are signed ad hoc, not Apple-notarized.

## Build

Requires Xcode Command Line Tools, Git, Node.js and pnpm.

```sh
bash build.sh
```

Builds the patch app and refreshes its Desktop copy. GPL-3.0-or-later; includes Vencord code by Vendicated and contributors. See [SECURITY.md](SECURITY.md) for review details and limits.
