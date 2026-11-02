// Copyright (c) 2026 silentrosehill
// SPDX-License-Identifier: GPL-3.0-or-later
export interface VolumeCommand { type: "volume"; channelId: string; userId: string; volume: number; }
export function isVolumeCommand(value: unknown): value is VolumeCommand {
    if (!value || typeof value !== "object") return false;
    const c = value as VolumeCommand;
    return c.type === "volume" && typeof c.channelId === "string" && c.channelId.length > 0 && c.channelId.length <= 64
        && typeof c.userId === "string" && c.userId.length > 0 && c.userId.length <= 64
        && typeof c.volume === "number" && Number.isFinite(c.volume) && c.volume >= 0 && c.volume <= 200;
}
export function applyVolumes(commands: unknown, channelId: string | undefined, participants: Set<string>, selfId: string | undefined, setVolume: (userId: string, volume: number) => void) {
    if (!channelId || !Array.isArray(commands)) return;
    for (const command of commands.slice(0, 100)) {
        if (isVolumeCommand(command) && command.channelId === channelId && command.userId !== selfId && participants.has(command.userId)) {
            setVolume(command.userId, command.volume);
        }
    }
}
