import Foundation
import os

/// Polls the GitHub Releases API once per day and exposes whether a newer
/// version of Veil is available. Result caches in UserDefaults so we don't
/// hit the network on every launch.
@MainActor
final class UpdateChecker: ObservableObject {
    static let shared = UpdateChecker()

    @Published private(set) var latestVersion: String?
    @Published private(set) var updateAvailable: Bool = false

    private let logger = Logger(subsystem: "com.veil.app", category: "UpdateChecker")
    private let releasesURL = URL(string: "https://api.github.com/repos/zlahham/Veil/releases/latest")!

    private enum Key {
        static let lastCheck = "updateChecker.lastCheck"
        static let lastTag   = "updateChecker.lastTag"
    }

    /// 24 hours.
    private let cacheTTL: TimeInterval = 86_400

    private init() {
        loadCache()
    }

    /// Kick off a check. No-op if we've checked within the last 24h.
    func checkIfStale() {
        let now = Date().timeIntervalSince1970
        let last = UserDefaults.standard.double(forKey: Key.lastCheck)
        if last > 0, now - last < cacheTTL {
            // Cache fresh — already loaded into properties.
            return
        }
        Task { await fetchLatest() }
    }

    /// Force a check regardless of cache.
    func checkNow() {
        Task { await fetchLatest() }
    }

    /// URL the user should be sent to in order to download.
    var downloadURL: URL {
        URL(string: "https://github.com/zlahham/Veil/releases/latest")!
    }

    // MARK: - Private

    private func loadCache() {
        let tag = UserDefaults.standard.string(forKey: Key.lastTag)
        latestVersion = tag
        updateAvailable = isNewer(tag, than: currentVersion)
    }

    private func fetchLatest() async {
        var request = URLRequest(url: releasesURL)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 8
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                logger.warning("GitHub releases returned non-200")
                return
            }
            let payload = try JSONDecoder().decode(GitHubRelease.self, from: data)
            await MainActor.run {
                self.latestVersion = payload.tagName
                self.updateAvailable = isNewer(payload.tagName, than: currentVersion)
                UserDefaults.standard.set(payload.tagName, forKey: Key.lastTag)
                UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: Key.lastCheck)
            }
        } catch {
            logger.warning("Update check failed: \(error.localizedDescription)")
        }
    }

    private var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    }

    /// Tag-vs-version comparison. Strips a leading "v" and compares numeric
    /// components left to right. Anything we can't parse counts as "no update."
    private func isNewer(_ tagOrNil: String?, than current: String) -> Bool {
        guard let tag = tagOrNil else { return false }
        let stripped = tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
        let lhs = stripped.split(separator: ".").compactMap { Int($0) }
        let rhs = current.split(separator: ".").compactMap { Int($0) }
        for i in 0..<max(lhs.count, rhs.count) {
            let l = i < lhs.count ? lhs[i] : 0
            let r = i < rhs.count ? rhs[i] : 0
            if l > r { return true }
            if l < r { return false }
        }
        return false
    }

    private struct GitHubRelease: Decodable {
        let tagName: String
        enum CodingKeys: String, CodingKey { case tagName = "tag_name" }
    }
}
