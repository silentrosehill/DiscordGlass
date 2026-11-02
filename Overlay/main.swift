// Copyright (c) 2026 silentrosehill
// SPDX-License-Identifier: GPL-3.0-or-later
import AppKit
import ImageIO

struct Person: Codable, Equatable { let id: String; let name: String; let speaking: Bool; let muted: Bool; let deaf: Bool; var avatarURL: String? = nil; var volume: Double? = nil; var isSelf: Bool? = nil }
struct Packet: Codable, Equatable {
    let version: Int; let channel: String; let corner: String; let people: [Person]
    var glassOpacity: Double? = nil
    var editPosition: Bool? = nil
    var channelId: String? = nil
    var canSetVolume: Bool? = nil
    var valid: Bool { (glassOpacity == nil || (glassOpacity!.isFinite && (0...1).contains(glassOpacity!))) && (channelId?.count ?? 0) <= 64 && version == 1 && channel.count <= 256 && people.count <= 100 && people.allSatisfy { $0.id.count <= 64 && $0.name.count <= 256 && ($0.avatarURL?.count ?? 0) <= 2048 && ($0.volume == nil || ($0.volume!.isFinite && (0...200).contains($0.volume!))) } && ["custom", "topLeft", "topRight", "bottomLeft", "bottomRight"].contains(corner) }
}
func avatarAddress(_ value: String?) -> URL? {
    guard let value, value.count <= 2048, let url = URL(string: value),
          url.scheme == "https", ["cdn.discordapp.com", "media.discordapp.net"].contains(url.host ?? ""),
          url.user == nil, url.password == nil, url.port == nil,
          ["/avatars/", "/guilds/", "/embed/avatars/"].contains(where: { url.path.hasPrefix($0) }) else { return nil }
    return url
}
func decodedAvatar(_ data: Data) -> NSImage? {
    guard data.count <= AvatarDownload.limit,
          let source = CGImageSourceCreateWithData(data as CFData, nil),
          let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
          let width = props[kCGImagePropertyPixelWidth] as? NSNumber,
          let height = props[kCGImagePropertyPixelHeight] as? NSNumber,
          (1...1024).contains(width.intValue), (1...1024).contains(height.intValue),
          let image = CGImageSourceCreateImageAtIndex(source, 0, [kCGImageSourceShouldCacheImmediately: false] as CFDictionary) else { return nil }
    return NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
}
final class Panel: NSPanel { override var canBecomeKey: Bool { false }; override var canBecomeMain: Bool { false } }
func fittedOrigin(_ origin: NSPoint, size: NSSize, area: NSRect) -> NSPoint {
    NSPoint(x: max(area.minX, min(origin.x, max(area.minX, area.maxX - size.width))),
            y: max(area.minY, min(origin.y, max(area.minY, area.maxY - size.height))))
}
func fittedSize(_ size: NSSize, area: NSRect) -> NSSize {
    NSSize(width: min(area.width, max(180, size.width)), height: min(area.height, max(110, size.height)))
}
func resizedFrame(_ frame: NSRect, from start: NSPoint, to point: NSPoint, minimum: NSSize, maximum: NSSize) -> NSRect {
    let width = max(minimum.width, min(maximum.width, frame.width + point.x - start.x))
    let height = max(minimum.height, min(maximum.height, frame.height - point.y + start.y))
    return NSRect(x: frame.minX, y: frame.maxY - height, width: width, height: height)
}
final class ResizeGrip: NSView {
    private var start: NSPoint?
    private var original = NSRect.zero
    override var mouseDownCanMoveWindow: Bool { false }
    override func hitTest(_ point: NSPoint) -> NSView? { self }
    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .frameResize(position: .bottomRight, directions: [.inward, .outward]))
    }
    override func draw(_ dirtyRect: NSRect) {
        NSColor.black.withAlphaComponent(0.3).setFill()
        NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), xRadius: 7, yRadius: 7).fill()
        let image = NSImage(systemSymbolName: "arrow.up.left.and.arrow.down.right", accessibilityDescription: nil)?
            .withSymbolConfiguration(NSImage.SymbolConfiguration(paletteColors: [.white]))
        image?.draw(in: bounds.insetBy(dx: 6, dy: 6))
    }
    override func mouseDown(with event: NSEvent) { start = NSEvent.mouseLocation; original = window?.frame ?? .zero }
    override func mouseDragged(with event: NSEvent) {
        guard let window, let start else { return }
        window.setFrame(resizedFrame(original, from: start, to: NSEvent.mouseLocation, minimum: window.minSize, maximum: window.maxSize), display: true)
    }
    override func mouseUp(with event: NSEvent) { start = nil }
}
struct VolumeCommand: Encodable {
    let type = "volume"
    let channelId: String
    let userId: String
    let volume: Double
}
final class VolumeControl: NSViewController {
    let person: Person
    let channelId: String
    var available = true
    private var slider: NSSlider!
    private let value = NSTextField(labelWithString: "")
    init(person: Person, channelId: String) { self.person = person; self.channelId = channelId; super.init(nibName: nil, bundle: nil) }
    required init?(coder: NSCoder) { fatalError("Not used") }
    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 240, height: 115))
        if !available {
            let message = NSTextField(wrappingLabelWithString: "Restart Discord once to enable avatar volume controls. Use DiscordGlass Patch on your Desktop.")
            message.frame = NSRect(x: 14, y: 34, width: 212, height: 65); view.addSubview(message)
            return
        }
        let title = NSTextField(labelWithString: "\(person.name) · Volume")
        title.font = .systemFont(ofSize: 13, weight: .semibold); title.lineBreakMode = .byTruncatingTail
        title.frame = NSRect(x: 14, y: 85, width: 212, height: 18); view.addSubview(title)
        slider = NSSlider(value: person.volume ?? 100, minValue: 0, maxValue: 200, target: self, action: #selector(changeVolume))
        slider.isContinuous = true; slider.frame = NSRect(x: 14, y: 50, width: 168, height: 24)
        slider.setAccessibilityLabel("\(person.name)'s local voice volume")
        view.addSubview(slider)
        value.frame = NSRect(x: 184, y: 53, width: 50, height: 18)
        value.font = .monospacedDigitSystemFont(ofSize: 12, weight: .medium)
        value.stringValue = "\(Int(slider.doubleValue.rounded()))%"; view.addSubview(value)
        let reset = NSButton(title: "Reset to 100%", target: self, action: #selector(resetVolume))
        reset.bezelStyle = .rounded; reset.frame = NSRect(x: 12, y: 10, width: 130, height: 28); view.addSubview(reset)
    }
    @objc private func changeVolume() {
        let volume = slider.doubleValue
        guard volume.isFinite, (0...200).contains(volume), !channelId.isEmpty, !person.id.isEmpty else { return }
        value.stringValue = "\(Int(volume.rounded()))%"
        if let data = try? JSONEncoder().encode(VolumeCommand(channelId: channelId, userId: person.id, volume: volume)) {
            try? FileHandle.standardOutput.write(contentsOf: data + Data([10]))
        }
    }
    @objc private func resetVolume() { slider.doubleValue = 100; changeVolume() }
}
final class AvatarBadge: NSView, NSPopoverDelegate {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func resetCursorRects() { if enabled { addCursorRect(bounds, cursor: .pointingHand) } }
    override var mouseDownCanMoveWindow: Bool { editing }
    var person: Person!
    var channelId = ""
    var enabled = false
    var volumeAvailable = false
    var editing = false
    var popupChanged: ((Bool) -> Void)?
    private var popover: NSPopover?
    override func mouseDown(with event: NSEvent) { if editing { window?.performDrag(with: event) } }
    override func rightMouseDown(with event: NSEvent) { showVolume() }
    func showVolume() {
        guard enabled else { return }
        if popover?.isShown == true { return }
        let popup = NSPopover(); popup.behavior = .transient; popup.delegate = self
        let control = VolumeControl(person: person, channelId: channelId)
        control.available = volumeAvailable
        popup.contentViewController = control
        popup.contentSize = NSSize(width: 240, height: 115)
        popover = popup; popupChanged?(true)
        popup.show(relativeTo: bounds, of: self, preferredEdge: .maxX)
    }
    func popoverDidShow(_ notification: Notification) {
        popover?.contentViewController?.view.window?.level = NSWindow.Level(rawValue: NSWindow.Level.screenSaver.rawValue + 2)
    }
    func popoverDidClose(_ notification: Notification) { popover = nil; popupChanged?(false) }
}
final class AvatarTarget: NSView {
    weak var badge: AvatarBadge?
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override var mouseDownCanMoveWindow: Bool { false }
    override func resetCursorRects() { addCursorRect(bounds, cursor: .pointingHand) }
    override func rightMouseDown(with event: NSEvent) { badge?.showVolume() }
}
final class DragSurface: NSView {
    override func hitTest(_ point: NSPoint) -> NSView? {
        guard bounds.contains(point) else { return nil }
        if let grip = subviews.first(where: { $0 is ResizeGrip }), !grip.isHidden, grip.frame.contains(point) { return grip }
        var hit = super.hitTest(point)
        while let view = hit, view !== self {
            if let badge = view as? AvatarBadge, badge.enabled { return badge }
            hit = view.superview
        }
        return self
    }
    override var mouseDownCanMoveWindow: Bool { true }
    override func mouseDown(with event: NSEvent) { window?.performDrag(with: event) }
}
final class Overlay: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var panel: Panel!
    private var stack: NSStackView!
    private var packet: Packet?
    private var heartbeat = Date()
    private var pending = Data()
    private let queue = DispatchQueue(label: "discordglass.input")
    private var timer: Timer?
    private var glass: NSView!
    private let resizeGrip = ResizeGrip()
    private var placing = false
    private var popupOpen = false
    private var hotspots: [Panel] = []
    private var badges: [AvatarBadge] = []
    private func updateInteractivity() {
        panel.ignoresMouseEvents = !(packet?.editPosition == true || popupOpen)
    }
    private func clearHotspots() {
        for target in hotspots { panel.removeChildWindow(target); target.close() }
        hotspots.removeAll()
    }
    private func placeHotspots() {
        clearHotspots()
        guard packet?.editPosition != true else { return }
        panel.contentView?.layoutSubtreeIfNeeded()
        for badge in badges where badge.enabled {
            let rect = panel.convertToScreen(badge.convert(badge.bounds, to: nil))
            let target = Panel(contentRect: rect, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            target.isReleasedWhenClosed = false; target.isOpaque = false
            target.backgroundColor = NSColor.white.withAlphaComponent(0.001)
            target.hasShadow = false; target.hidesOnDeactivate = false
            target.level = NSWindow.Level(rawValue: panel.level.rawValue + 1)
            target.collectionBehavior = panel.collectionBehavior
            let view = AvatarTarget(); view.badge = badge
            view.setAccessibilityElement(true); view.setAccessibilityRole(.button)
            view.setAccessibilityLabel("\(badge.person.name): adjust volume")
            view.setAccessibilityCustomActions([NSAccessibilityCustomAction(name: "Adjust volume", handler: { [weak badge] in badge?.showVolume(); return true })])
            target.contentView = view
            panel.addChildWindow(target, ordered: .above)
            hotspots.append(target)
        }
    }
    private let avatars = NSCache<NSString, NSImage>()
    private var fetching = Set<String>()
    private var retryAfter: [String: Date] = [:]
    private func avatar(_ address: String?) -> NSImage? {
        guard let url = avatarAddress(address) else { return nil }
        let key = url.absoluteString
        if let image = avatars.object(forKey: key as NSString) { return image }
        guard !fetching.contains(key), retryAfter[key].map({ $0 < Date() }) ?? true else { return nil }
        fetching.insert(key)
        AvatarDownload { [weak self] data in
            DispatchQueue.main.async {
                guard let self else { return }
                self.fetching.remove(key)
                guard let data, let image = decodedAvatar(data) else {
                    self.retryAfter[key] = Date().addingTimeInterval(60); return
                }
                self.avatars.countLimit = 200
                self.avatars.setObject(image, forKey: key as NSString)
                if Date().timeIntervalSince(self.heartbeat) < 2, let current = self.packet, current.people.contains(where: { $0.avatarURL == key }) { self.apply(current, force: true) }
            }
        }.start(url)
        return nil
    }
    private var savedOrigin: NSPoint? {
        let defaults = UserDefaults.standard
        guard let x = defaults.object(forKey: "overlayX") as? Double,
              let y = defaults.object(forKey: "overlayY") as? Double, x.isFinite, y.isFinite else { return nil }
        return NSPoint(x: x, y: y)
    }
    private var savedSize: NSSize? {
        let defaults = UserDefaults.standard
        guard let width = defaults.object(forKey: "overlayWidth") as? Double,
              let height = defaults.object(forKey: "overlayHeight") as? Double,
              width.isFinite, height.isFinite, width > 0, height > 0 else { return nil }
        return NSSize(width: width, height: height)
    }
    func windowDidResize(_ notification: Notification) {
        guard packet?.editPosition == true, !placing else { return }
        UserDefaults.standard.set(panel.frame.minX, forKey: "overlayX")
        UserDefaults.standard.set(panel.frame.minY, forKey: "overlayY")
        UserDefaults.standard.set(panel.frame.width, forKey: "overlayWidth")
        UserDefaults.standard.set(panel.frame.height, forKey: "overlayHeight")
        if let current = packet { apply(current, force: true) }
    }
    func windowDidMove(_ notification: Notification) {
        guard packet?.editPosition == true, !placing else { return }
        UserDefaults.standard.set(panel.frame.minX, forKey: "overlayX")
        UserDefaults.standard.set(panel.frame.minY, forKey: "overlayY")
    }
    func applicationDidFinishLaunching(_ note: Notification) {
        let preview = CommandLine.arguments.contains("--preview") || Bundle.main.object(forInfoDictionaryKey: "DiscordGlassPreview") as? Bool == true
        NSApp.setActivationPolicy(.accessory)
        panel = Panel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isReleasedWhenClosed = false; panel.isOpaque = false; panel.backgroundColor = .clear
        panel.hasShadow = false; panel.hidesOnDeactivate = false; panel.ignoresMouseEvents = true
        panel.isFloatingPanel = true; panel.level = .screenSaver
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        if #available(macOS 26, *) { panel.collectionBehavior.insert(.canJoinAllApplications) }
        panel.delegate = self
        panel.isMovableByWindowBackground = true
        panel.minSize = NSSize(width: 180, height: 110)
        if #available(macOS 26, *) {
            let view = NSGlassEffectView(); view.style = .clear; view.cornerRadius = 16; if #available(macOS 27, *) { view.effectIsInteractive = false }; glass = view
        } else {
            let view = NSVisualEffectView(); view.material = .hudWindow; view.state = .active
            view.wantsLayer = true; view.layer?.cornerRadius = 16; view.layer?.masksToBounds = true; glass = view
        }
        stack = NSStackView(); stack.orientation = .vertical; stack.alignment = .leading; stack.spacing = 8
        stack.edgeInsets = NSEdgeInsets(top: 12, left: 14, bottom: 12, right: 14)
        // Keep material and content separate so fading the glass never fades names or status icons.
        let surface = DragSurface()
        surface.addSubview(glass); glass.autoresizingMask = [.width, .height]
        surface.addSubview(stack); stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([stack.leadingAnchor.constraint(equalTo: surface.leadingAnchor), stack.trailingAnchor.constraint(equalTo: surface.trailingAnchor), stack.topAnchor.constraint(equalTo: surface.topAnchor), stack.bottomAnchor.constraint(equalTo: surface.bottomAnchor)])
        surface.addSubview(resizeGrip)
        resizeGrip.toolTip = "Drag to resize overlay"
        resizeGrip.setAccessibilityElement(true)
        resizeGrip.setAccessibilityRole(.image)
        resizeGrip.setAccessibilityLabel("Resize overlay: drag this corner")
        panel.contentView = surface
        if !preview { FileHandle.standardInput.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { handle.readabilityHandler = nil; DispatchQueue.main.async { NSApp.terminate(nil) }; return }
            self?.queue.async { self?.receive(data) }
        }
        }
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self else { return }
            if getppid() == 1 || Date().timeIntervalSince(self.heartbeat) > 10 { NSApp.terminate(nil) }
            else if Date().timeIntervalSince(self.heartbeat) > 2 { self.panel.orderOut(nil); self.clearHotspots() }
            else if self.packet != nil { self.panel.orderFrontRegardless() }
        }
        if preview {
            FileHandle.standardInput.readabilityHandler = nil
            apply(Packet(version: 1, channel: "Voice preview", corner: "topRight", people: [Person(id: "1", name: "Alex", speaking: true, muted: false, deaf: false, avatarURL: "https://cdn.discordapp.com/embed/avatars/0.png"), Person(id: "2", name: "Jamie", speaking: false, muted: true, deaf: false, volume: 75), Person(id: "3", name: "Sam", speaking: false, muted: true, deaf: true)], glassOpacity: 0.65, editPosition: false, channelId: "preview", canSetVolume: true))
            timer?.invalidate()
        }
    }
    private func receive(_ data: Data) {
        pending.append(data)
        while let end = pending.firstIndex(of: 10) {
            let line = pending[..<end]; pending.removeSubrange(...end)
            if line.count <= 64_000, let packet = try? JSONDecoder().decode(Packet.self, from: line), packet.valid {
                DispatchQueue.main.async { self.apply(packet) }
            }
        }
        if pending.count > 64_000 { pending.removeAll() }
    }
    private func label(_ text: String, size: CGFloat, color: NSColor) -> NSTextField {
        let view = NSTextField(labelWithString: text); view.font = .systemFont(ofSize: size, weight: .medium)
        view.textColor = color; view.lineBreakMode = .byTruncatingTail
        let shadow = NSShadow(); shadow.shadowColor = NSColor.black.withAlphaComponent(0.45); shadow.shadowBlurRadius = 2; shadow.shadowOffset = NSSize(width: 0, height: -1); view.shadow = shadow
        return view
    }
    private func apply(_ next: Packet, force: Bool = false) {
        if !force { heartbeat = Date() }
        let defaults = UserDefaults.standard
        if defaults.object(forKey: "volumeBridgeReady") == nil || defaults.bool(forKey: "volumeBridgeReady") != (next.canSetVolume == true) {
            defaults.set(next.canSetVolume == true, forKey: "volumeBridgeReady")
        }
        if popupOpen { packet = next; return }
        guard !next.people.isEmpty else { packet = nil; panel.orderOut(nil); clearHotspots(); return }
        guard force || packet != next else { if hotspots.isEmpty && next.editPosition != true { placeHotspots() }; panel.orderFrontRegardless(); return }
        let previous = packet
        packet = next
        placing = true
        let editing = next.editPosition == true
        panel.ignoresMouseEvents = !editing
        resizeGrip.isHidden = !editing
        panel.minSize = NSSize(width: 180, height: editing ? 128 : 110)
        stack.edgeInsets.bottom = editing ? 36 : 12
        if editing && !panel.styleMask.contains(.resizable) { panel.styleMask.insert(.resizable) }
        else if !editing && panel.styleMask.contains(.resizable) { panel.styleMask.remove(.resizable) }
        // shortcut: native glass has no public blur radius; blend opacity until a blur API is available.
        glass.alphaValue = next.glassOpacity ?? 0.8
        if #available(macOS 26, *), let material = glass as? NSGlassEffectView { material.style = .regular }
        clearHotspots()
        badges.removeAll()
        stack.arrangedSubviews.forEach { stack.removeArrangedSubview($0); $0.removeFromSuperview() }
        let stored = savedOrigin
        let custom = next.corner == "custom" || editing
        let screen = (custom ? stored.flatMap { point in NSScreen.screens.first { $0.visibleFrame.contains(point) } } : nil) ?? NSScreen.main ?? NSScreen.screens[0]
        let area = screen.visibleFrame
        stack.addArrangedSubview(label(editing ? "\(next.channel.uppercased()) · EDIT" : next.channel.uppercased(), size: 10, color: .white.withAlphaComponent(0.65)))
        panel.maxSize = area.size
        let requestedSize = savedSize.map { fittedSize($0, area: area) }
        let maximum = max(1, Int(((requestedSize?.height ?? (area.height - 40)) - (editing ? 84 : 60)) / 36))
        for person in next.people.prefix(maximum) {
            let badge = AvatarBadge(); badge.wantsLayer = true
            badge.person = person; badge.channelId = next.channelId ?? ""; badge.editing = editing
            badge.enabled = person.isSelf != true
            badge.volumeAvailable = next.canSetVolume == true && !badge.channelId.isEmpty
            if badge.enabled {
                badge.toolTip = "Right-click to adjust \(person.name)'s volume"
                badge.setAccessibilityElement(true); badge.setAccessibilityRole(.button)
                badge.setAccessibilityLabel("\(person.name): adjust volume")
                badge.setAccessibilityCustomActions([NSAccessibilityCustomAction(name: "Adjust volume", handler: { [weak badge] in badge?.showVolume(); return true })])
            }
            badge.popupChanged = { [weak self] open in
                guard let self else { return }
                self.popupOpen = open
                if !open, let current = self.packet { self.apply(current, force: true) }
                self.updateInteractivity()
            }
            badges.append(badge)
            badge.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.08).cgColor
            badge.layer?.cornerRadius = 14; badge.layer?.borderWidth = person.speaking ? 2 : 1
            badge.layer?.borderColor = (person.speaking ? NSColor.systemGreen : NSColor.white.withAlphaComponent(0.15)).cgColor
            badge.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([badge.widthAnchor.constraint(equalToConstant: 28), badge.heightAnchor.constraint(equalToConstant: 28)])
            if let image = avatar(person.avatarURL) {
                let picture = NSImageView(image: image)
                picture.imageScaling = .scaleProportionallyUpOrDown
                picture.wantsLayer = true; picture.layer?.cornerRadius = 12; picture.layer?.masksToBounds = true
                picture.translatesAutoresizingMaskIntoConstraints = false; badge.addSubview(picture)
                NSLayoutConstraint.activate([picture.leadingAnchor.constraint(equalTo: badge.leadingAnchor, constant: 2), picture.topAnchor.constraint(equalTo: badge.topAnchor, constant: 2), picture.widthAnchor.constraint(equalToConstant: 24), picture.heightAnchor.constraint(equalToConstant: 24)])
                picture.setAccessibilityLabel("\(person.name)'s profile picture")
            } else {
                let initial = label(String(person.name.prefix(1)).uppercased(), size: 12, color: .white)
                initial.translatesAutoresizingMaskIntoConstraints = false; badge.addSubview(initial)
                NSLayoutConstraint.activate([initial.centerXAnchor.constraint(equalTo: badge.centerXAnchor), initial.centerYAnchor.constraint(equalTo: badge.centerYAnchor)])
            }
            let name = label(person.name, size: 13, color: .white); name.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
            let row = NSStackView(views: [badge, name]); row.orientation = .horizontal; row.spacing = 10
            for symbol in [person.muted ? "mic.slash.fill" : nil, person.deaf ? "speaker.slash.fill" : nil].compactMap({ $0 }) {
                let image = NSImageView(image: NSImage(systemSymbolName: symbol, accessibilityDescription: symbol == "mic.slash.fill" ? "Muted" : "Deafened") ?? NSImage())
                image.contentTintColor = .white.withAlphaComponent(0.65); row.addArrangedSubview(image)
            }
            row.setAccessibilityLabel("\(person.name)\(person.speaking ? ", speaking" : "")\(person.muted ? ", muted" : "")\(person.deaf ? ", deafened" : "")")
            stack.addArrangedSubview(row)
            row.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -28).isActive = true
        }
        if next.people.count > maximum { stack.addArrangedSubview(label("+\(next.people.count - maximum) more", size: 11, color: .white.withAlphaComponent(0.65))) }
        let height = CGFloat(min(next.people.count, maximum)) * 36 + 40 + (next.people.count > maximum ? 20 : 0)
        var size = requestedSize ?? fittedSize(NSSize(width: 240, height: height + (editing ? 24 : 0)), area: area)
        if editing { size.height = min(area.height, max(128, size.height)) }
        let x = next.corner.hasSuffix("Right") ? area.maxX - size.width - 20 : area.minX + 20
        let y = next.corner.hasPrefix("top") ? area.maxY - size.height - 20 : area.minY + 20
        let defaultOrigin = NSPoint(x: area.maxX - size.width - 20, y: area.maxY - size.height - 20)
        let initial = (editing && previous != nil) ? panel.frame.origin : defaultOrigin
        let origin = fittedOrigin(panel.inLiveResize ? panel.frame.origin : (custom ? (stored ?? initial) : NSPoint(x: x, y: y)), size: size, area: area)
        placing = true
        panel.setFrame(NSRect(origin: origin, size: size), display: true)
        glass.frame = panel.contentView!.bounds
        resizeGrip.frame = NSRect(x: size.width - 34, y: 4, width: 28, height: 28)
        panel.invalidateCursorRects(for: resizeGrip)
        placing = false
        placeHotspots()
        updateInteractivity()
        panel.orderFrontRegardless()
    }
}
if CommandLine.arguments.contains("--test-placement") {
    let area = NSRect(x: -1000, y: 20, width: 1000, height: 800), size = NSSize(width: 240, height: 150)
    precondition(fittedOrigin(NSPoint(x: -500, y: 100), size: size, area: area) == NSPoint(x: -500, y: 100))
    precondition(fittedOrigin(NSPoint(x: -2000, y: -100), size: size, area: area) == NSPoint(x: -1000, y: 20))
    precondition(fittedOrigin(NSPoint(x: 100, y: 1000), size: size, area: area) == NSPoint(x: -240, y: 670))
    precondition(fittedSize(NSSize(width: 360, height: 300), area: area) == NSSize(width: 360, height: 300))
    precondition(fittedSize(NSSize(width: 20, height: 20), area: area) == NSSize(width: 180, height: 110))
    precondition(fittedSize(NSSize(width: 2000, height: 2000), area: area) == area.size)
    let original = NSRect(x: 100, y: 200, width: 240, height: 150)
    let resized = resizedFrame(original, from: .zero, to: NSPoint(x: 60, y: -40), minimum: NSSize(width: 180, height: 110), maximum: area.size)
    precondition(resized.size == NSSize(width: 300, height: 190) && resized.minX == original.minX && resized.maxY == original.maxY)
    precondition(resizedFrame(original, from: .zero, to: NSPoint(x: -2000, y: 2000), minimum: NSSize(width: 180, height: 110), maximum: area.size).size == NSSize(width: 180, height: 110))
    precondition(avatarAddress("https://cdn.discordapp.com/embed/avatars/0.png") != nil)
    precondition(avatarAddress("https://cdn.discordapp.com/avatars/123/hash.png?size=64") != nil)
    precondition(avatarAddress("file:///etc/passwd") == nil)
    precondition(avatarAddress("https://example.com/avatars/1.png") == nil)
    precondition(avatarAddress("https://cdn.discordapp.com.evil.test/avatars/1.png") == nil)
    precondition(avatarAddress("https://cdn.discordapp.com/api/users/@me") == nil)
    func png(_ width: Int) -> Data {
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: 2, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        return bitmap.representation(using: .png, properties: [:])!
    }
    precondition(decodedAvatar(png(2)) != nil)
    precondition(decodedAvatar(png(1025)) == nil)
    let session = URLSession(configuration: .ephemeral)
    let url = URL(string: "https://cdn.discordapp.com/embed/avatars/0.png")!
    let task = session.dataTask(with: url)
    var result: Data?
    let downloader = AvatarDownload { result = $0 }
    let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "image/png"])!
    downloader.urlSession(session, dataTask: task, didReceive: response) { precondition($0 == .allow) }
    downloader.urlSession(session, dataTask: task, didReceive: Data(repeating: 0, count: AvatarDownload.limit + 1))
    downloader.urlSession(session, task: task, didCompleteWithError: nil)
    precondition(result == nil)
    let redirectSession = URLSession(configuration: .ephemeral)
    let redirectTask = redirectSession.dataTask(with: url)
    downloader.urlSession(redirectSession, task: redirectTask, willPerformHTTPRedirection: response, newRequest: URLRequest(url: URL(string: "http://127.0.0.1/private")!)) { precondition($0 == nil) }
    redirectSession.invalidateAndCancel()
    precondition(decodedAvatar(Data("not an image".utf8)) == nil)
    precondition(decodedAvatar(Data(repeating: 0, count: AvatarDownload.limit + 1)) == nil)
    print("Placement, avatar URL and image bounds checks passed"); exit(0)
}
if CommandLine.arguments.contains("--validate") {
    let p = try JSONDecoder().decode(Packet.self, from: FileHandle.standardInput.readDataToEndOfFile())
    guard p.valid else { exit(1) }; print("Valid overlay packet: \(p.people.count) participants"); exit(0)
}
let app = NSApplication.shared; let delegate = Overlay(); app.delegate = delegate; app.run()
