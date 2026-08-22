import Foundation

/// Persists comparisons as JSON in ~/Library/Application Support/WhosBetter/history.json.
/// Nothing ever leaves the Mac.
struct HistoryStore {
    static let url: URL = {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("WhosBetter", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("history.json")
    }()

    static func load() throws -> [Comparison] {
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }
        let data = try Data(contentsOf: url)
        let dec = JSONDecoder(); dec.dateDecodingStrategy = .iso8601
        return try dec.decode([Comparison].self, from: data)
    }

    static func save(_ items: [Comparison]) throws {
        let enc = JSONEncoder(); enc.dateEncodingStrategy = .iso8601; enc.outputFormatting = .prettyPrinted
        // Strip images from persisted history to keep the file small.
        let slim = items.map { c -> Comparison in
            var c = c
            c.candidates = c.candidates.map { var x = $0; x.imagePNG = nil; return x }
            return c
        }
        try enc.encode(slim).write(to: url, options: .atomic)
    }
}
