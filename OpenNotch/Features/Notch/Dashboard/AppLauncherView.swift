import Combine
import SwiftUI

struct AppLauncherView: View {
    @Binding var searchText: String
    @StateObject private var store = AppLauncherStore()

    private var filteredApps: [URL] {
        guard !searchText.isEmpty else { return store.apps }
        let q = searchText.lowercased()
        return store.apps.filter {
            $0.deletingPathExtension().lastPathComponent.lowercased().contains(q)
        }
    }

    var body: some View {
        Group {
            if store.isLoading {
                SWShimmer {
                    VStack(spacing: 14) {
                        ForEach(0..<4, id: \.self) { _ in
                            HStack(spacing: 8) {
                                ForEach(0..<5, id: \.self) { _ in
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.white.opacity(0.08))
                                        .frame(width: 60, height: 70)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if filteredApps.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 22))
                        .foregroundStyle(.white.opacity(0.2))
                    Text("No apps found")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.3))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 76), spacing: 8)],
                        spacing: 14
                    ) {
                        ForEach(filteredApps, id: \.self) { url in
                            AppIconButton(url: url)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
            }
        }
        .onAppear { store.loadIfNeeded() }
    }
}

struct AppIconButton: View {
    let url: URL
    @State private var isHovered = false

    var body: some View {
        Button {
            NSWorkspace.shared.openApplication(
                at: url,
                configuration: NSWorkspace.OpenConfiguration()
            )
        } label: {
            VStack(spacing: 5) {
                Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 52, height: 52)
                    .scaleEffect(isHovered ? 1.18 : 1.0)
                    .shadow(color: .black.opacity(isHovered ? 0.35 : 0), radius: 8, y: 4)
                    .animation(.spring(response: 0.18, dampingFraction: 0.62), value: isHovered)

                Text(url.deletingPathExtension().lastPathComponent)
                    .font(.system(size: 9.5))
                    .foregroundStyle(.white.opacity(0.72))
                    .lineLimit(1)
                    .frame(maxWidth: 72)
            }
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

@MainActor
final class AppLauncherStore: ObservableObject {
    @Published private(set) var apps: [URL] = []
    @Published private(set) var isLoading = false

    private var loaded = false

    func loadIfNeeded() {
        guard !loaded else { return }
        loaded = true
        isLoading = true
        Task {
            let result = await Self.scanApps()
            apps = result
            isLoading = false
        }
    }

    private static func scanApps() async -> [URL] {
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser.path
        let dirs = [
            "/Applications",
            "/System/Applications",
            "/System/Applications/Utilities",
            (home as NSString).appendingPathComponent("Applications")
        ]
        var seen = Set<String>()
        var result: [URL] = []
        for dir in dirs {
            guard let items = try? fm.contentsOfDirectory(atPath: dir) else { continue }
            for item in items.sorted() where item.hasSuffix(".app") {
                let path = (dir as NSString).appendingPathComponent(item)
                if seen.insert(path).inserted {
                    result.append(URL(fileURLWithPath: path))
                }
            }
        }
        return result.sorted {
            $0.deletingPathExtension().lastPathComponent.lowercased() <
            $1.deletingPathExtension().lastPathComponent.lowercased()
        }
    }
}
