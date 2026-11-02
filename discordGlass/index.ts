// Copyright (c) 2026 silentrosehill
// SPDX-License-Identifier: GPL-3.0-or-later
import { definePluginSettings } from "@api/Settings";
import definePlugin, { OptionType, PluginNative, StartAt } from "@utils/types";
import { findByPropsLazy, findStoreLazy } from "@webpack";
import { ChannelStore, GuildMemberStore, MediaEngineStore, SelectedChannelStore, UserStore, VoiceStateStore } from "@webpack/common";

import { applyVolumes } from "./volume";

const VolumeActions = findByPropsLazy("setLocalVolume", "toggleSelfMute");
let volumeBridgeReady = false;
const Native = VencordNative.pluginHelpers.DiscordGlass as PluginNative<typeof import("./native")>;
const SpeakingStore = findStoreLazy("SpeakingStore");
function editPositionChanged(value: boolean): void {
    if (value) settings.store.corner = "custom";
}
const settings = definePluginSettings({
    glassOpacity: { type: OptionType.SLIDER, description: "Glass frost / opacity (text stays fully visible)",
        default: 0.8, markers: [0, 0.25, 0.5, 0.75, 1], stickToMarkers: false },
    editPosition: { type: OptionType.BOOLEAN, description: "Edit position: drag the overlay anywhere, then turn this off to lock it", default: false,
        onChange: editPositionChanged },
    corner: { type: OptionType.SELECT, description: "Overlay position", options: [
        { label: "Custom (saved position)", value: "custom", default: true }, { label: "Top right", value: "topRight" }, { label: "Top left", value: "topLeft" },
        { label: "Bottom right", value: "bottomRight" }, { label: "Bottom left", value: "bottomLeft" }
    ] }
});
let timer: ReturnType<typeof setInterval> | undefined;
let sending = false;
let warned = false;
async function update() {
    if (sending) return;
    sending = true;
    try {
        const id = SelectedChannelStore.getVoiceChannelId();
        const channel = id ? ChannelStore.getChannel(id) : undefined;
        const states = id ? Object.values(VoiceStateStore.getVoiceStatesForChannel(id)) : [];
        const people = states.map(state => {
            const user = UserStore.getUser(state.userId);
            const nick = channel?.guild_id ? GuildMemberStore.getMember(channel.guild_id, state.userId)?.nick : undefined;
            const muted = Boolean(state.mute || state.selfMute);
            const deaf = Boolean(state.deaf || state.selfDeaf);
            return { id: state.userId, name: nick || user?.globalName || user?.username || "Unknown user",
                isSelf: state.userId === UserStore.getCurrentUser()?.id,
                volume: Math.max(0, Math.min(200, MediaEngineStore.getLocalVolume(state.userId))),
                avatarURL: user?.getAvatarURL(channel?.guild_id, 64, false, "png"),
                speaking: !muted && Boolean(SpeakingStore.isSpeaking(state.userId)), muted, deaf };
        });
        const commands = await Native.update({ version: 1, channelId: id, canSetVolume: volumeBridgeReady, channel: channel?.name || "Voice call", corner: settings.store.corner, glassOpacity: settings.store.glassOpacity, editPosition: settings.store.editPosition, people });
        volumeBridgeReady = Array.isArray(commands);
        const activeId = SelectedChannelStore.getVoiceChannelId();
        const activePeople = new Set(activeId ? Object.values(VoiceStateStore.getVoiceStatesForChannel(activeId)).map(p => p.userId) : []);
        applyVolumes(commands, activeId, activePeople, UserStore.getCurrentUser()?.id,
            (userId, volume) => VolumeActions.setLocalVolume(userId, volume, "default"));
        warned = false;
    } catch (error) {
        if (!warned) console.error("[DiscordGlass] Overlay unavailable; install the Mac helper.", error);
        warned = true;
        await Native.stop().catch(() => {});
    } finally { sending = false; }
}
export default definePlugin({
    name: "DiscordGlass",
    description: "FrameGlass-style native Mac voice overlay: people, speaking rings, mute and deafen.",
    authors: [{ name: "silentrosehill", id: 0n }],
    startAt: StartAt.WebpackReady,
    settings,
    start() { timer = setInterval(update, 150); void update(); },
    stop() { clearInterval(timer); timer = undefined; void Native.stop(); }
});
