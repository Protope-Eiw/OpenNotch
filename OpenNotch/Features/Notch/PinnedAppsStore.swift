import Combine
import Foundation

extension Notification.Name {
    static let pinnedAppsDidChange = Notification.Name("com.opennotch.pinnedAppsDidChange")
    static let dashboardPopoverPresentationDidChange = Notification.Name("com.opennotch.dashboardPopoverPresentationDidChange")
}

final class PinnedAppsStore: ObservableObject {
    @Published private(set) var apps: [URL] = []

    private let key = "settings.overview.pinnedApps"

    // Candidate default apps — first ones found on disk are used
    private static let defaultCandidates: [String] = [
        "/System/Applications/App Store.app",
        "/System/Applications/Safari.app",
        "/Applications/Safari.app",
        "/System/Applications/System Settings.app",
        "/System/Applications/System Preferences.app",
        "/System/Applications/Notes.app",
        "/System/Applications/Calendar.app",
        "/System/Applications/Mail.app",
        "/System/Applications/Messages.app",
        "/System/Applications/Photos.app",
    ]

    init() { load() }

    func load() {
        // Key not yet written → seed defaults
        if UserDefaults.standard.object(forKey: key) == nil {
            seedDefaults()
            return
        }
        let paths = UserDefaults.standard.stringArray(forKey: key) ?? []
        apps = paths.map { URL(fileURLWithPath: $0) }
    }

    func add(_ url: URL) {
        guard !apps.contains(url), apps.count < 12 else { return }
        apps.append(url)
        save()
        NotificationCenter.default.post(name: .pinnedAppsDidChange, object: nil)
    }

    func remove(_ url: URL) {
        apps.removeAll { $0 == url }
        save()
        NotificationCenter.default.post(name: .pinnedAppsDidChange, object: nil)
    }

    private func save() {
        UserDefaults.standard.set(apps.map(\.path), forKey: key)
    }

    private func seedDefaults() {
        let fm = FileManager.default
        var result: [URL] = []
        var seen = Set<String>()
        for path in Self.defaultCandidates {
            guard fm.fileExists(atPath: path) else { continue }
            // Deduplicate by app bundle name
            let name = (path as NSString).lastPathComponent
            guard seen.insert(name).inserted else { continue }
            result.append(URL(fileURLWithPath: path))
            if result.count == 6 { break }
        }
        apps = result
        save()
    }
}
