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
        let q = NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q")
        q.target = self
        m.addItem(q)
        item.menu = m
    }

    @objc func setMod(_ s: NSMenuItem) { defaults.set(s.tag, forKey: "mod"); rebuild() }
    @objc func setStyle(_ s: NSMenuItem) { defaults.set(s.tag, forKey: "style"); rebuild() }
    @objc func quit() { NSApp.terminate(nil) }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let menu = Menu()
menu.rebuild()

// Accessibility: event tap + raising windows. Screen Recording: window titles and previews.
_ = CGRequestScreenCaptureAccess()
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
app.run()
