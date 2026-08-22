import Foundation

/// One product the user wants compared. Either typed text (name/URL/pasted specs)
/// or a screen capture PNG.
struct Candidate: Identifiable, Codable, Equatable {
    var id = UUID()
    var text: String = ""
    var imagePNG: Data? = nil

    var isEmpty: Bool { text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && imagePNG == nil }
    var label: String {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if !t.isEmpty { return String(t.prefix(60)) }
        return imagePNG != nil ? "Screen capture" : "Empty"
    }
}

struct ProductAssessment: Codable, Identifiable, Equatable {
    var id: String { name }
    var name: String
    var summary: String
    var price: String
    var pros: [String]
    var cons: [String]
    /// 0–100 overall fit score.
    var score: Int
}

struct CriterionRow: Codable, Identifiable, Equatable {
    var id: String { criterion }
    var criterion: String
    /// One cell per product, same order as `products`.
    var values: [String]
    /// Index into products of the best on this criterion, or -1 if tie/n/a.
    var bestIndex: Int
}

struct Verdict: Codable, Equatable {
    var winner: String
    var headline: String
    var reasoning: String
    var runnerUp: String
    var caveats: [String]
}

struct ComparisonResult: Codable, Equatable {
    var title: String
    var products: [ProductAssessment]
    var table: [CriterionRow]
    var verdict: Verdict
    var sources: [String]

    /// JSON Schema sent to the API as `output_config.format`.
    static let jsonSchema: [String: Any] = [
        "type": "object",
        "additionalProperties": false,
        "required": ["title", "products", "table", "verdict", "sources"],
        "properties": [
            "title": ["type": "string", "description": "Short title, e.g. 'iPhone 16 vs Pixel 9'"],
            "products": ["type": "array", "items": [
                "type": "object", "additionalProperties": false,
                "required": ["name", "summary", "price", "pros", "cons", "score"],
                "properties": [
                    "name": ["type": "string"],
                    "summary": ["type": "string"],
                    "price": ["type": "string", "description": "Current typical price with currency, or 'Unknown'"],
                    "pros": ["type": "array", "items": ["type": "string"]],
                    "cons": ["type": "array", "items": ["type": "string"]],
                    "score": ["type": "integer", "description": "0–100 overall value score"]
                ]
            ]],
            "table": ["type": "array", "items": [
                "type": "object", "additionalProperties": false,
                "required": ["criterion", "values", "bestIndex"],
                "properties": [
                    "criterion": ["type": "string"],
                    "values": ["type": "array", "items": ["type": "string"]],
                    "bestIndex": ["type": "integer"]
                ]
            ]],
            "verdict": [
                "type": "object", "additionalProperties": false,
                "required": ["winner", "headline", "reasoning", "runnerUp", "caveats"],
                "properties": [
                    "winner": ["type": "string"],
                    "headline": ["type": "string", "description": "One sentence: 'Go with X.'"],
                    "reasoning": ["type": "string"],
                    "runnerUp": ["type": "string"],
                    "caveats": ["type": "array", "items": ["type": "string"]]
                ]
            ],
            "sources": ["type": "array", "items": ["type": "string"], "description": "URLs consulted"]
        ]
    ]
}

struct Comparison: Identifiable, Codable, Equatable {
    var id = UUID()
    var createdAt = Date()
    var candidates: [Candidate] = [Candidate(), Candidate()]
    var result: ComparisonResult? = nil

    var title: String {
        result?.title ?? candidates.filter { !$0.isEmpty }.map(\.label).joined(separator: " vs ")
    }
}
