import Cocoa
import ApplicationServices

var tap: CFMachPort?

let kTab: Int64 = 48, kBacktick: Int64 = 50, kEsc: Int64 = 53, kReturn: Int64 = 36, kDelete: Int64 = 51
let kLeft: Int64 = 123, kRight: Int64 = 124, kDown: Int64 = 125, kUp: Int64 = 126

let callback: CGEventTapCallBack = { _, type, event, _ in
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        if let t = tap { CGEvent.tapEnable(tap: t, enable: true) }
        return Unmanaged.passUnretained(event)
    }
    let flags = event.flags
    if type == .flagsChanged {
        if showing && !flags.contains(modifier) { commit() }
        return Unmanaged.passUnretained(event)
    }
    let key = event.getIntegerValueField(.keyboardEventKeycode)
    let step = flags.contains(.maskShift) ? -1 : 1
    if showing {
        switch key {
        case kEsc: hide()
        case kReturn: commit()
        case kTab, kBacktick: move(step)
        case kLeft: move(-1)
        case kRight: move(1)
        case kUp: move(-cols)
        case kDown: move(cols)
        case kDelete: if !query.isEmpty { query.removeLast(); refilter() }
        default:
            // Typing while the switcher is open searches window titles (AltTab Pro feature).
            guard let s = NSEvent(cgEvent: event)?.charactersIgnoringModifiers, s.count == 1,
                  s.unicodeScalars.allSatisfy({ CharacterSet.alphanumerics.contains($0) }) else { return Unmanaged.passUnretained(event) }
            query += s
            refilter()
        }
        return nil
    }
    guard flags.contains(modifier), key == kTab || key == kBacktick else { return Unmanaged.passUnretained(event) }
    open(sameApp: key == kBacktick, step: step)  // modifier+Tab: all windows, modifier+`: current app only
    return nil
}

final class Menu: NSObject {
    let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

    func rebuild() {
        item.button?.title = "⇥"
        let m = NSMenu()
        m.addItem(withTitle: "Shortcut", action: nil, keyEquivalent: "").isEnabled = false
        for (i, mod) in modifiers.enumerated() {
            let mi = NSMenuItem(title: "\(mod.name)+Tab  /  \(mod.name)+`", action: #selector(setMod(_:)), keyEquivalent: "")
            mi.target = self
            mi.tag = i
            mi.state = mod.flag == modifier ? .on : .off
            m.addItem(mi)
        }
        m.addItem(.separator())
        m.addItem(withTitle: "Style", action: nil, keyEquivalent: "").isEnabled = false
        for (s, name) in zip(Style.allCases, ["Thumbnails", "App icons", "Title list"]) {
            let mi = NSMenuItem(title: name, action: #selector(setStyle(_:)), keyEquivalent: "")
            mi.target = self
            mi.tag = s.rawValue
            mi.state = s == style ? .on : .off
            m.addItem(mi)
        }
        m.addItem(.separator())
        m.addItem(withTitle: "Size", action: nil, keyEquivalent: "").isEnabled = false
        for (i, name) in ["Small", "Medium", "Large"].enumerated() {
            let mi = NSMenuItem(title: name, action: #selector(setSize(_:)), keyEquivalent: "")
            mi.target = self
            mi.tag = i
            mi.state = i == sizeIndex ? .on : .off
            m.addItem(mi)
        }
        m.addItem(.separator())
        m.addItem(withTitle: "Theme", action: nil, keyEquivalent: "").isEnabled = false
        for (t, name) in zip(Theme.allCases, ["System", "Light", "Dark"]) {
            let mi = NSMenuItem(title: name, action: #selector(setTheme(_:)), keyEquivalent: "")
            mi.target = self
            mi.tag = t.rawValue
            mi.state = t == theme ? .on : .off
            m.addItem(mi)
        }
        m.addItem(.separator())
        let p = NSMenuItem(title: "Show window preview", action: #selector(togglePreview), keyEquivalent: "")
        p.target = self
        p.state = previewEnabled ? .on : .off
        m.addItem(p)
        m.addItem(.separator())
        let u = NSMenuItem(title: "Check for Updates… (\(currentVersion))", action: #selector(checkUpdates), keyEquivalent: "")
        u.target = self
        m.addItem(u)
        let q = NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q")
        q.target = self
        m.addItem(q)
        item.menu = m
    }

    @objc func setMod(_ s: NSMenuItem) { defaults.set(s.tag, forKey: "mod"); rebuild() }
    @objc func setStyle(_ s: NSMenuItem) { defaults.set(s.tag, forKey: "style"); rebuild() }
    @objc func setSize(_ s: NSMenuItem) { defaults.set(s.tag, forKey: "size"); rebuild() }
    @objc func setTheme(_ s: NSMenuItem) { defaults.set(s.tag, forKey: "theme"); rebuild() }
    @objc func togglePreview() { defaults.set(!previewEnabled, forKey: "preview"); rebuild() }
    @objc func checkUpdates() { checkForUpdates(silent: false) }
    @objc func quit() { NSApp.terminate(nil) }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let menu = Menu()
menu.rebuild()

// Accessibility: event tap + raising windows. Screen Recording: window titles and previews.
// Ask once per version: asking on every launch keeps re-opening System Settings when the grant went stale after an update.
let askedKey = "askedScreenCapture-\(currentVersion)"
if !CGPreflightScreenCaptureAccess(), !defaults.bool(forKey: askedKey) {
    defaults.set(true, forKey: askedKey)
    _ = CGRequestScreenCaptureAccess()
}
guard AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary) else {
    print("Grant Accessibility permission in System Settings, then relaunch.")
    exit(1)
}

let mask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.flagsChanged.rawValue)
guard let t = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
                                eventsOfInterest: CGEventMask(mask), callback: callback, userInfo: nil) else {
    print("Could not create event tap.")
    exit(1)
}
tap = t
CFRunLoopAddSource(CFRunLoopGetMain(), CFMachPortCreateRunLoopSource(nil, t, 0), .commonModes)
// Auto-check at most once a day.
if Date().timeIntervalSince1970 - defaults.double(forKey: "lastUpdateCheck") > 86400 {
    defaults.set(Date().timeIntervalSince1970, forKey: "lastUpdateCheck")
    checkForUpdates(silent: true)
}
app.run()
