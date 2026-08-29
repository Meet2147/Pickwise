import Foundation

/// Fetches version.json {build, version, url, notes} and reports if newer than this build.
struct UpdateInfo: Decodable, Equatable {
    let build: Int
    let version: String
    let url: String
    let notes: String
}

enum UpdateChecker {
    static let feedURL = URL(string: "https://pickwise.dashovia.app/version.json")!

    static var currentBuild: Int {
        Int(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0") ?? 0
    }

    /// Returns the update if one is available; nil otherwise. Throws on real failures.
    static func check() async throws -> UpdateInfo? {
        var req = URLRequest(url: feedURL)
        req.cachePolicy = .reloadIgnoringLocalCacheData
        req.timeoutInterval = 15
        let (data, resp) = try await URLSession.shared.data(for: req)
        let status = (resp as? HTTPURLResponse)?.statusCode ?? -1
        guard status == 200 else { throw AppError("Update check failed (HTTP \(status))") }
        let info = try JSONDecoder().decode(UpdateInfo.self, from: data)
        return info.build > currentBuild ? info : nil
    }
}
