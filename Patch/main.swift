// Copyright (c) 2026 silentrosehill
// SPDX-License-Identifier: GPL-3.0-or-later
import AppKit

final class PatchApp: NSObject, NSApplicationDelegate {
    private var window: NSWindow!
    private let status = NSTextField(wrappingLabelWithString: "")
    private let update = NSButton(title: "Update DiscordGlass", target: nil, action: nil)
    private let restart = NSButton(title: "Restart Discord…", target: nil, action: nil)
    private var busy = false
    private var payload: URL { Bundle.main.resourceURL!.appendingPathComponent("Payload") }
    private var installed: URL { FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/Vencord/dist") }
    private var discord: NSRunningApplication? {
        NSWorkspace.shared.runningApplications.first { ["com.hnc.Discord", "com.hnc.DiscordPTB", "com.hnc.DiscordCanary"].contains($0.bundleIdentifier ?? "") }
    }
    private var needsPlugin: Bool {
        ["patcher.js", "renderer.js"].contains { name in
            guard let wanted = try? Data(contentsOf: payload.appendingPathComponent("Vencord-dist/" + name)),
                  let current = try? Data(contentsOf: installed.appendingPathComponent(name)) else { return true }
            return wanted != current
        }
    }
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.applicationIconImage = NSImage(systemSymbolName: "person.2.wave.2", accessibilityDescription: "DiscordGlass")
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 440, height: 270), styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        window.title = "DiscordGlass Patch"; window.isReleasedWhenClosed = false; window.center()
        let title = NSTextField(labelWithString: "DiscordGlass")
        title.font = .systemFont(ofSize: 25, weight: .semibold)
        let subtitle = NSTextField(wrappingLabelWithString: "Keep your voice overlay up to date.")
        subtitle.textColor = .secondaryLabelColor
        status.font = .systemFont(ofSize: 13); status.preferredMaxLayoutWidth = 380
        update.bezelStyle = .rounded; update.keyEquivalent = "\r"; update.target = self; update.action = #selector(updateNow)
        restart.bezelStyle = .rounded; restart.target = self; restart.action = #selector(restartNow)
        let buttons = NSStackView(views: [update, restart]); buttons.orientation = .horizontal; buttons.spacing = 12
        let stack = NSStackView(views: [title, subtitle, status, buttons]); stack.orientation = .vertical; stack.alignment = .leading; stack.spacing = 20
        stack.translatesAutoresizingMaskIntoConstraints = false
        window.contentView!.addSubview(stack)
        NSLayoutConstraint.activate([stack.leadingAnchor.constraint(equalTo: window.contentView!.leadingAnchor, constant: 28), stack.trailingAnchor.constraint(equalTo: window.contentView!.trailingAnchor, constant: -28), stack.topAnchor.constraint(equalTo: window.contentView!.topAnchor, constant: 24)])
        showStatus(); window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
    }
    func applicationDidBecomeActive(_ notification: Notification) { if window != nil { showStatus() } }
    private func showStatus() {
        guard !busy else { return }
        if needsPlugin { status.stringValue = "A plugin update is ready. If Discord is open, you’ll be asked before restarting it." }
        else if UserDefaults(suiteName: "local.discordglass.overlay")?.object(forKey: "volumeBridgeReady") as? Bool == false {
            status.stringValue = "Overlay updates keep your call running. Volume controls need one Discord restart to load the plugin bridge."
        } else { status.stringValue = "Ready. Overlay-only updates keep Discord and your call running." }
        restart.isEnabled = discord != nil
    }
    private func confirmRestart() -> Bool {
        let alert = NSAlert(); alert.messageText = "Restart Discord?"
        alert.informativeText = "This disconnects any active call. Discord will reopen after the update."
        alert.addButton(withTitle: "Restart & Update"); alert.addButton(withTitle: "Cancel")
        return alert.runModal() == .alertFirstButtonReturn
    }
    @objc private func updateNow() {
        let full = needsPlugin
        if full && discord != nil && !confirmRestart() { return }
        install(full: full, relaunch: full && discord != nil)
    }
    @objc private func restartNow() {
        guard confirmRestart() else { return }
        install(full: true, relaunch: true)
    }
    private func install(full: Bool, relaunch: Bool) {
        guard !busy else { return }
        busy = true; update.isEnabled = false; restart.isEnabled = false
        status.stringValue = relaunch ? "Closing Discord and applying the update…" : "Updating the overlay…"
        let running = discord
        let discordURL = running?.bundleURL ?? URL(fileURLWithPath: "/Applications/Discord.app")
        if relaunch { running?.terminate() }
        let folder = payload
        DispatchQueue.global().async {
            do {
                let deadline = Date().addingTimeInterval(15)
                while relaunch && running?.isTerminated == false && Date() < deadline { Thread.sleep(forTimeInterval: 0.1) }
                if relaunch && running?.isTerminated == false { throw NSError(domain: "DiscordGlass", code: 1, userInfo: [NSLocalizedDescriptionKey: "Discord did not quit. Close it manually, then try again."]) }
                let process = Process(); process.currentDirectoryURL = folder
                process.executableURL = URL(fileURLWithPath: full ? "/bin/bash" : "/usr/bin/python3")
                process.arguments = [folder.appendingPathComponent(full ? "Install.command" : "update-overlay.py").path]
                let pipe = Pipe(); process.standardOutput = pipe; process.standardError = pipe
                try process.run()
                let output = pipe.fileHandleForReading.readDataToEndOfFile(); process.waitUntilExit()
                guard process.terminationStatus == 0 else { throw NSError(domain: "DiscordGlass", code: 2, userInfo: [NSLocalizedDescriptionKey: String(data: output, encoding: .utf8) ?? "Update failed."]) }
                DispatchQueue.main.async {
                    self.busy = false; self.update.isEnabled = true; self.restart.isEnabled = self.discord != nil
                    self.status.stringValue = full ? "Updated. Enable DiscordGlass in Vencord’s Plugins settings if needed." : "Overlay updated. No Discord restart was needed."
                    if relaunch { NSWorkspace.shared.openApplication(at: discordURL, configuration: .init()) }
                }
            } catch {
                DispatchQueue.main.async {
                    self.busy = false; self.update.isEnabled = true; self.restart.isEnabled = self.discord != nil
                    self.status.stringValue = "Update couldn’t finish. Your previous version is backed up."
                    let alert = NSAlert(); alert.messageText = "Could not update DiscordGlass"; alert.informativeText = String(error.localizedDescription.prefix(2000)); alert.runModal()
                    if relaunch && running?.isTerminated == true { NSWorkspace.shared.openApplication(at: discordURL, configuration: .init()) }
                }
            }
        }
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool { window.makeKeyAndOrderFront(nil); return true }
}
let app = NSApplication.shared; let delegate = PatchApp(); app.delegate = delegate; app.run()
