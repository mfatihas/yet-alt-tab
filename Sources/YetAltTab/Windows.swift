import Cocoa
import ApplicationServices

// Private but long-stable APIs (AltTab uses the same ones).
@_silgen_name("_AXUIElementGetWindow")
func _AXUIElementGetWindow(_ el: AXUIElement, _ id: UnsafeMutablePointer<CGWindowID>) -> AXError
@_silgen_name("CGSMainConnectionID")
func CGSMainConnectionID() -> Int32
@_silgen_name("CGSCopySpacesForWindows")
func CGSCopySpacesForWindows(_ cid: Int32, _ mask: Int32, _ wids: CFArray) -> Unmanaged<CFArray>?
@_silgen_name("CGSCopyManagedDisplaySpaces")
func CGSCopyManagedDisplaySpaces(_ cid: Int32) -> Unmanaged<CFArray>?

struct Win {
    let id: CGWindowID, pid: pid_t, title: String, app: String
    let icon: NSImage?, bounds: CGRect, onScreen: Bool
    let badge: String  // "", "Minimized", "Hidden", "Space N"
}

// Shared switcher state. Everything runs on the main thread (event tap is on the main run loop).
var wins: [Win] = []   // all candidates
var shown: [Win] = []  // after search filter
var sel = 0
var cols = 1
var query = ""
var showing = false
var snapshots: [CGWindowID: NSImage] = [:]
// The window switched to last. CG z-order lags behind focus changes, so a quick second Option+Tab would otherwise
// still see the old front window at index 0 and pick the wrong "previous" one.
var lastCommit: (id: CGWindowID, at: Date)?

let defaults = UserDefaults.standard
let modifiers: [(name: String, flag: CGEventFlags)] = [("Option", .maskAlternate), ("Control", .maskControl), ("Command", .maskCommand)]
var modifier: CGEventFlags { modifiers[min(max(defaults.integer(forKey: "mod"), 0), modifiers.count - 1)].flag }
enum Style: Int, CaseIterable { case thumbnails, icons, titles }
enum Theme: Int, CaseIterable {
    case auto, light, dark
    var appearance: NSAppearance? { self == .auto ? nil : NSAppearance(named: self == .light ? .aqua : .darkAqua) }
}
var theme: Theme { Theme(rawValue: defaults.integer(forKey: "theme")) ?? .auto }
let sizeScales: [CGFloat] = [0.8, 1, 1.3]  // small, medium, large
var sizeIndex: Int { min(max(defaults.object(forKey: "size") as? Int ?? 1, 0), sizeScales.count - 1) }
var scale: CGFloat { sizeScales[sizeIndex] }
var previewEnabled: Bool { defaults.object(forKey: "preview") as? Bool ?? true }
var style: Style { Style(rawValue: defaults.integer(forKey: "style")) ?? .thumbnails }

func spaceOrder() -> [Int] {
    guard let displays = CGSCopyManagedDisplaySpaces(CGSMainConnectionID())?.takeRetainedValue() as? [[String: Any]] else { return [] }
    return displays.flatMap { ($0["Spaces"] as? [[String: Any]] ?? []).compactMap { $0["id64"] as? Int } }
}

func spaceNumber(of wid: CGWindowID, _ order: [Int]) -> Int? {
    let ids = [NSNumber(value: wid)] as CFArray
    guard let s = (CGSCopySpacesForWindows(CGSMainConnectionID(), 7, ids)?.takeRetainedValue() as? [Int])?.first else { return nil }
    return order.firstIndex(of: s).map { $0 + 1 }
}

func axWindows(_ pid: pid_t) -> [(el: AXUIElement, id: CGWindowID)] {
    var ref: CFTypeRef?
    AXUIElementCopyAttributeValue(AXUIElementCreateApplication(pid), kAXWindowsAttribute as CFString, &ref)
    return ((ref as? [AXUIElement]) ?? []).map { el in
        var id: CGWindowID = 0
        _ = _AXUIElementGetWindow(el, &id)
        return (el, id)
    }
}

func isMinimized(_ el: AXUIElement) -> Bool {
    var v: CFTypeRef?
    AXUIElementCopyAttributeValue(el, kAXMinimizedAttribute as CFString, &v)
    return (v as? Bool) ?? false
}

// shortcut: hides off-screen windows with an empty title (helper windows); without Screen Recording permission that
// also hides minimized / other-Space windows, because macOS blanks all titles. Upgrade: filter via AX role/subrole.
func listWindows() -> [Win] {
    let info = CGWindowListCopyWindowInfo([.optionAll, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
    let order = spaceOrder()
    let me = getpid()
    var apps: [pid_t: NSRunningApplication] = [:]
    var ax: [pid_t: [(el: AXUIElement, id: CGWindowID)]] = [:]
    var out: [Win] = []
    for d in info {
        guard d[kCGWindowLayer as String] as? Int == 0,
              (d[kCGWindowAlpha as String] as? Double ?? 1) > 0,
              let id = d[kCGWindowNumber as String] as? CGWindowID,
              let pid = d[kCGWindowOwnerPID as String] as? pid_t, pid != me,
              let bd = d[kCGWindowBounds as String] as? NSDictionary,
              let b = CGRect(dictionaryRepresentation: bd as CFDictionary), b.width >= 80, b.height >= 40
        else { continue }
        if apps[pid] == nil { apps[pid] = NSRunningApplication(processIdentifier: pid) }
        guard let app = apps[pid], app.activationPolicy == .regular else { continue }
        let name = d[kCGWindowName as String] as? String ?? ""
        let onScreen = d[kCGWindowIsOnscreen as String] as? Bool ?? false
        if !onScreen && name.isEmpty { continue }
        let owner = app.localizedName ?? d[kCGWindowOwnerName as String] as? String ?? "?"
        var badge = ""
        if !onScreen {
            if ax[pid] == nil { ax[pid] = axWindows(pid) }
            if let w = ax[pid]?.first(where: { $0.id == id }), isMinimized(w.el) { badge = "Minimized" }
            else if app.isHidden { badge = "Hidden" }
            else { badge = spaceNumber(of: id, order).map { "Space \($0)" } ?? "Other Space" }
        }
        out.append(Win(id: id, pid: pid, title: name.isEmpty ? owner : name, app: owner, icon: app.icon,
                       bounds: b, onScreen: onScreen, badge: badge))
    }
    // CG lists front-to-back, so on-screen windows keep most-recently-used order.
    return out.filter { $0.onScreen } + out.filter { !$0.onScreen }
}

// shortcut: for a window on another Space this activates the app, and macOS jumps to that app's last-used window's Space
// (not necessarily this window). Exact targeting needs private SkyLight calls (_SLPSSetFrontProcessWithOptions).
func focus(_ w: Win) {
    let app = NSRunningApplication(processIdentifier: w.pid)
    if app?.isHidden == true { app?.unhide() }
    for (el, id) in axWindows(w.pid) where id == w.id {
        if isMinimized(el) { AXUIElementSetAttributeValue(el, kAXMinimizedAttribute as CFString, kCFBooleanFalse) }
        AXUIElementPerformAction(el, kAXRaiseAction as CFString)
    }
    // macOS 14+ often ignores activate() from a background app; AXFrontmost reliably brings the app forward.
    AXUIElementSetAttributeValue(AXUIElementCreateApplication(w.pid), kAXFrontmostAttribute as CFString, kCFBooleanTrue)
    app?.activate(options: [.activateIgnoringOtherApps])
}

// Obsoleted in the macOS 15 SDK; CI pins Xcode 15.4. Needs Screen Recording permission.
func snapshot(_ id: CGWindowID) -> NSImage? {
    if let s = snapshots[id] { return s }
    guard let cg = CGWindowListCreateImage(.null, .optionIncludingWindow, id, [.boundsIgnoreFraming, .bestResolution]) else { return nil }
    let img = NSImage(cgImage: cg, size: NSSize(width: cg.width, height: cg.height))
    snapshots[id] = img
    return img
}
