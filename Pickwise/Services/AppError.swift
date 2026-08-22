import Foundation

/// FAIL LOUD: every failure carries a user-facing message AND copyable details.
struct AppError: LocalizedError, Identifiable {
    let id = UUID()
    let title: String
    let details: String

    var errorDescription: String? { title }

    init(_ title: String, details: String = "") {
        self.title = title
        self.details = details
    }

    /// Wrap any Error, unwrapping NSUnderlyingErrorKey chains.
    init(_ title: String, error: Error) {
        self.title = title
        var lines: [String] = []
        var current: Error? = error
        var depth = 0
        while let e = current, depth < 6 {
            let ns = e as NSError
            lines.append("\(depth == 0 ? "" : "↳ ")\(ns.domain) (\(ns.code)): \(ns.localizedDescription)")
            if let reason = ns.localizedFailureReason { lines.append("   reason: \(reason)") }
            current = ns.userInfo[NSUnderlyingErrorKey] as? Error
            depth += 1
        }
        self.details = lines.joined(separator: "\n")
    }
}
