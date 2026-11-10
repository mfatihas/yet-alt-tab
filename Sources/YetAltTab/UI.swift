import Cocoa

func makePanel(level: NSWindow.Level) -> NSPanel {
    let p = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
    p.level = level
    p.backgroundColor = .clear
    p.isOpaque = false
    p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    return p
}

let panel = makePanel(level: .screenSaver)
let previewPanel: NSPanel = {
    let p = makePanel(level: NSWindow.Level(rawValue: NSWindow.Level.screenSaver.rawValue - 1))
    p.ignoresMouseEvents = true
    return p
}()

var tiles: [Tile] = []

func setHighlight(_ i: Int, _ on: Bool) {
    guard tiles.indices.contains(i) else { return }
    tiles[i].layer?.backgroundColor = on ? NSColor.controlAccentColor.withAlphaComponent(0.75).cgColor : nil
}

final class Tile: NSStackView {
    var index = 0
    override func mouseDown(with event: NSEvent) { sel = index; commit() }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        // mouseMoved (not mouseEntered) so a stationary cursor under the panel doesn't override keyboard selection.
        addTrackingArea(NSTrackingArea(rect: .zero, options: [.mouseMoved, .activeAlways, .inVisibleRect], owner: self))
    }

    // Hover selects the tile and shows its preview; highlight is updated in place so views aren't rebuilt under the cursor.
    override func mouseMoved(with event: NSEvent) {
        guard index != sel else { return }
        setHighlight(sel, false)
        sel = index
        setHighlight(sel, true)
        updatePreview()
    }
}

// Sizes passed to label/fixed are base values; the Size setting scales them.
func label(_ s: String, size: CGFloat = 13, color: NSColor = .labelColor, maxWidth: CGFloat) -> NSTextField {
    let l = NSTextField(labelWithString: s)
    l.font = .systemFont(ofSize: size * scale)
    l.textColor = color
    l.lineBreakMode = .byTruncatingTail
    l.widthAnchor.constraint(lessThanOrEqualToConstant: maxWidth * scale).isActive = true
    return l
}

func fixed(_ v: NSView, _ w: CGFloat, _ h: CGFloat) -> NSView {
    v.widthAnchor.constraint(equalToConstant: w * scale).isActive = true
    v.heightAnchor.constraint(equalToConstant: h * scale).isActive = true
    return v
}

func makeTile(_ w: Win, _ i: Int) -> Tile {
    let t = Tile()
    t.index = i
    t.spacing = 6
    t.edgeInsets = NSEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
    t.wantsLayer = true
    t.layer?.cornerRadius = 8
    t.layer?.backgroundColor = i == sel ? NSColor.controlAccentColor.withAlphaComponent(0.75).cgColor : nil
    let badge = w.badge.isEmpty ? nil : label(w.badge, size: 11, color: .secondaryLabelColor, maxWidth: 180)
    switch style {
    case .thumbnails:
        t.orientation = .vertical
        let img = NSImageView(image: snapshot(w.id) ?? w.icon ?? NSImage())
        img.imageScaling = .scaleProportionallyUpOrDown
        t.addArrangedSubview(fixed(img, 180, 110))
        t.addArrangedSubview(label(w.title, maxWidth: 180))
        if let b = badge { t.addArrangedSubview(b) }
    case .icons:
        t.orientation = .vertical
        t.addArrangedSubview(fixed(NSImageView(image: w.icon ?? NSImage()), 64, 64))
        t.addArrangedSubview(label(w.app, maxWidth: 100))
        if let b = badge { t.addArrangedSubview(b) }
    case .titles:
        t.orientation = .horizontal
        t.addArrangedSubview(fixed(NSImageView(image: w.icon ?? NSImage()), 24, 24))
        t.addArrangedSubview(label("\(w.app) — \(w.title)", size: 15, maxWidth: 420))
        if let b = badge { t.addArrangedSubview(b) }
    }
    return t
}

func render() {
    let screen = NSScreen.screens[0].frame
    cols = style == .titles ? 1 : max(1, Int(screen.width * 0.9 / (200 * scale)))  // auto-size: grid fits the screen
    let outer = NSStackView()
    outer.orientation = .vertical
    outer.alignment = .leading
    outer.spacing = 4
    outer.edgeInsets = NSEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
    if !query.isEmpty { outer.addArrangedSubview(label("Search: \(query)", size: 13, color: .secondaryLabelColor, maxWidth: 400)) }
    if shown.isEmpty { outer.addArrangedSubview(label("No match", size: 15, maxWidth: 400)) }
    tiles = []
    for start in stride(from: 0, to: shown.count, by: cols) {
        let rowTiles = (start..<min(start + cols, shown.count)).map { makeTile(shown[$0], $0) }
        tiles += rowTiles
        let row = NSStackView(views: rowTiles)
        row.spacing = 4
        outer.addArrangedSubview(row)
    }
    let bg = NSVisualEffectView()
    bg.material = .popover
    bg.state = .active
    bg.wantsLayer = true
    bg.layer?.cornerRadius = 14
    bg.layer?.masksToBounds = true
    outer.translatesAutoresizingMaskIntoConstraints = false
    bg.addSubview(outer)
    NSLayoutConstraint.activate([
        outer.leadingAnchor.constraint(equalTo: bg.leadingAnchor),
        outer.trailingAnchor.constraint(equalTo: bg.trailingAnchor),
        outer.topAnchor.constraint(equalTo: bg.topAnchor),
        outer.bottomAnchor.constraint(equalTo: bg.bottomAnchor),
    ])
    panel.appearance = theme.appearance
    panel.contentView = bg
    panel.setContentSize(bg.fittingSize)
    panel.setFrameOrigin(NSPoint(x: screen.midX - panel.frame.width / 2, y: screen.minY + screen.height * 0.25))
    panel.orderFrontRegardless()
    updatePreview()
}

// Full-size preview of the selected window, drawn where the window is (centered and shrunk if it's off-screen).
func updatePreview() {
    guard previewEnabled, shown.indices.contains(sel), let img = snapshot(shown[sel].id) else { previewPanel.orderOut(nil); return }
    let w = shown[sel]
    let screen = NSScreen.screens[0].frame
    var f = CGRect(x: w.bounds.minX, y: screen.height - w.bounds.maxY, width: w.bounds.width, height: w.bounds.height)
    if !w.onScreen {
        let s = min(1, screen.width * 0.7 / w.bounds.width, screen.height * 0.7 / w.bounds.height)
        f.size = CGSize(width: w.bounds.width * s, height: w.bounds.height * s)
        f.origin = CGPoint(x: screen.midX - f.width / 2, y: screen.midY - f.height / 2)
    }
    let v = NSImageView(image: img)
    v.imageScaling = .scaleAxesIndependently
    previewPanel.contentView = v
    previewPanel.setFrame(f, display: true)
    previewPanel.orderFrontRegardless()
}

func hide() {
    showing = false
    panel.orderOut(nil)
    previewPanel.orderOut(nil)
}

func commit() {
    hide()
    if shown.indices.contains(sel) { focus(shown[sel]) }
}

func move(_ step: Int) {
    guard !shown.isEmpty else { return }
    sel = (sel + step + shown.count) % shown.count
    render()
}

func refilter() {
    shown = query.isEmpty ? wins : wins.filter { "\($0.app) \($0.title)".localizedCaseInsensitiveContains(query) }
    sel = 0
    render()
}

func open(sameApp: Bool, step: Int) {
    var all = listWindows()
    if sameApp, let pid = NSWorkspace.shared.frontmostApplication?.processIdentifier { all = all.filter { $0.pid == pid } }
    guard all.count > 1 else { return }
    wins = all
    shown = all
    query = ""
    snapshots = [:]
    showing = true
    sel = step > 0 ? 1 : all.count - 1  // index 0 is the current window
    render()
}
