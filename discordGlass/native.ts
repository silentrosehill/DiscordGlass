// Copyright (c) 2026 silentrosehill
// SPDX-License-Identifier: GPL-3.0-or-later
import { ChildProcessWithoutNullStreams, spawn } from "child_process";
import { existsSync } from "fs";
import { homedir } from "os";
import { join } from "path";

import { isVolumeCommand, VolumeCommand } from "./volume";

let commands = new Map<string, VolumeCommand>();
let child: ChildProcessWithoutNullStreams | undefined;
let retryAfter = 0;
export function update(_event: unknown, packet: unknown) {
    if (process.platform !== "darwin") throw new Error("DiscordGlass requires macOS");
    const data = JSON.stringify(packet);
    if (data.length > 64_000) throw new Error("Overlay update too large");
    const value = packet as { channelId?: string; people?: { id?: string; isSelf?: boolean }[] };
    if (!Array.isArray(value?.people) || value.people.length > 100) throw new Error("Invalid participants");
    if (!value.people.length) { stop(); return []; }
    if (!child) {
        if (Date.now() < retryAfter) return [];
        const path = join(homedir(), "Library/Application Support/DiscordGlass/DiscordGlass Overlay.app/Contents/MacOS/DiscordGlassOverlay");
        if (!existsSync(path)) throw new Error("Install DiscordGlass Overlay.app first");
        const current = spawn(path, [], { stdio: "pipe" });
        child = current;
        let pending = "";
        current.stdout.on("data", (data: Buffer) => {
            if (child !== current) return;
            pending += data.toString("utf8");
            if (pending.length > 16_384) { pending = ""; return; }
            let end: number;
            while ((end = pending.indexOf("\n")) !== -1) {
                const line = pending.slice(0, end); pending = pending.slice(end + 1);
                try {
                    const command: unknown = JSON.parse(line);
                    if (isVolumeCommand(command) && commands.size < 100) commands.set(command.userId, command);
                } catch { /* Ignore malformed helper output. */ }
            }
        });
        current.stderr.resume();
        current.on("error", () => { if (child === current) child = undefined; retryAfter = Date.now() + 5000; });
        current.on("exit", () => { if (child === current) child = undefined; retryAfter = Date.now() + 1000; });
        current.stdin.on("error", () => { if (child === current) stop(); });
    }
    if (child.stdin.writableLength < 128_000) child.stdin.write(data + "\n");
    const allowed = new Set(value.people.filter(p => !p.isSelf).map(p => p.id));
    const result = [...commands.values()].filter(c => c.channelId === value.channelId && allowed.has(c.userId));
    commands.clear();
    return result;
}
export function stop() {
    commands.clear();
    const current = child; child = undefined;
    current?.stdin.end(); current?.kill();
}
