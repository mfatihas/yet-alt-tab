import Cocoa

let repo = "mfatihas/yet-alt-tab"
// CI stamps the release tag into Info.plist; untagged builds report 0.0.0 and always see the latest release as newer.
let currentVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"

func alert(_ text: String) {
    NSApp.activate(ignoringOtherApps: true)
    let a = NSAlert()
    a.messageText = text
    a.runModal()
}

// silent: launch-time check that only speaks up when an update exists.
func checkForUpdates(silent: Bool) {
    var req = URLRequest(url: URL(string: "https://api.github.com/repos/\(repo)/releases/latest")!)
    req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
    URLSession.shared.dataTask(with: req) { data, _, _ in
        let json = data.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
        DispatchQueue.main.async {
            guard let json, let tag = json["tag_name"] as? String else {
                if !silent { alert("Could not check for updates.") }
                return
            }
            let latest = tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
            let asset = (json["assets"] as? [[String: Any]])?.first { ($0["name"] as? String)?.hasSuffix(".dmg") == true }
            guard latest.compare(currentVersion, options: .numeric) == .orderedDescending,
                  let link = asset?["browser_download_url"] as? String, let url = URL(string: link) else {
                if !silent { alert("YetAltTab is up to date (\(currentVersion)).") }
                return
            }
            NSApp.activate(ignoringOtherApps: true)
            let a = NSAlert()
            a.messageText = "YetAltTab \(latest) is available"
            a.informativeText = "You have \(currentVersion). Install it and relaunch? macOS may ask you to grant permissions again."
            a.addButton(withTitle: "Install & Relaunch")
            a.addButton(withTitle: "Later")
            if a.runModal() == .alertFirstButtonReturn { install(url) }
        }
    }.resume()
}

// Downloads the DMG, then hands off to a shell script that waits for this process to exit, swaps the bundle and relaunches.
// A URLSession download carries no quarantine flag, so Gatekeeper doesn't prompt for the updated app.
func install(_ url: URL) {
    URLSession.shared.downloadTask(with: url) { tmp, _, _ in
        let dmg = FileManager.default.temporaryDirectory.appendingPathComponent("YetAltTab-update.dmg")
        try? FileManager.default.removeItem(at: dmg)
        guard let tmp, (try? FileManager.default.moveItem(at: tmp, to: dmg)) != nil else {
            DispatchQueue.main.async { alert("Download failed.") }
            return
        }
        let script = """
        APP="\(Bundle.main.bundlePath)"
        MNT=$(mktemp -d); STAGE=$(mktemp -d)
        hdiutil attach "\(dmg.path)" -nobrowse -readonly -mountpoint "$MNT" >/dev/null || exit 1
        cp -R "$MNT"/*.app "$STAGE/YetAltTab.app"; hdiutil detach "$MNT" >/dev/null
        while kill -0 \(getpid()) 2>/dev/null; do sleep 0.2; done
        mv "$APP" "$APP.old" && mv "$STAGE/YetAltTab.app" "$APP" && rm -rf "$APP.old" || { [ -d "$APP.old" ] && mv "$APP.old" "$APP"; }
        open "$APP"
        """
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/sh")
        p.arguments = ["-c", script]
        DispatchQueue.main.async {
            do { try p.run() } catch { alert("Update failed: \(error.localizedDescription)"); return }
            NSApp.terminate(nil)
        }
    }.resume()
}
