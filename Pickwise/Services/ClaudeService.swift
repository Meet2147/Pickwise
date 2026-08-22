import Foundation

/// Raw-HTTP client for the Claude Messages API. No SDK exists for Swift, so we
/// call `POST /v1/messages` directly. Uses web search so comparisons reflect
/// current prices/specs, and a JSON-schema output format so parsing is exact.
struct ClaudeService {
    static let model = "claude-opus-5"
    static let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!
    static let apiKeyKeychainKey = "anthropic-api-key"

    static var apiKey: String? { KeychainStore.get(apiKeyKeychainKey) }

    private static let systemPrompt = """
    You are Pickwise, a brutally practical purchase advisor. The user gives you 2–5 products \
    (names, URLs, pasted specs, or screenshots of product pages). Your job:
    1. Identify each product precisely. Use web search to get CURRENT pricing and specs; cite URLs in `sources`.
    2. Build a comparison table of the criteria that actually matter for this product category \
    (price, key specs, build, ecosystem, warranty, longevity, etc.). Keep cells short. \
    `values` must have exactly one entry per product, in the same order the products were given.
    3. Give honest pros and cons per product (3–6 each). No marketing fluff.
    4. Score each product 0–100 for overall value to a typical buyer.
    5. Deliver ONE clear verdict: which product to buy and why, in plain language. Name a runner-up \
    and list caveats (situations where the runner-up wins instead).
    Never invent specs. If something is unknown, say "Unknown". Never include affiliate links.
    """

    /// Runs a comparison. Throws AppError with full details on any failure.
    func compare(_ candidates: [Candidate]) async throws -> ComparisonResult {
        guard let key = Self.apiKey, !key.isEmpty else {
            throw AppError("No API key", details: "Add your Anthropic API key in Settings (⌘,). It is stored only in your Keychain.")
        }
        let live = candidates.filter { !$0.isEmpty }
        guard live.count >= 2 else {
            throw AppError("Add at least two products", details: "A comparison needs 2–5 products.")
        }

        // Build the user content: text + optional images, labelled by position.
        var content: [[String: Any]] = []
        for (i, c) in live.enumerated() {
            var label = "Product \(i + 1):"
            let t = c.text.trimmingCharacters(in: .whitespacesAndNewlines)
            if !t.isEmpty { label += " \(t)" }
            content.append(["type": "text", "text": label])
            if let png = c.imagePNG {
                content.append(["type": "image",
                                "source": ["type": "base64", "media_type": "image/png",
                                           "data": png.base64EncodedString()]])
            }
        }
        content.append(["type": "text", "text": "Compare these \(live.count) products and tell me which one to buy."])

        let body: [String: Any] = [
            "model": Self.model,
            "max_tokens": 16000,
            "system": Self.systemPrompt,
            "thinking": ["type": "adaptive"],
            "output_config": [
                "effort": "high",
                "format": ["type": "json_schema", "schema": ComparisonResult.jsonSchema]
            ],
            "tools": [["type": "web_search_20260209", "name": "web_search", "max_uses": 12]],
            "messages": [["role": "user", "content": content]]
        ]

        var req = URLRequest(url: Self.endpoint)
        req.httpMethod = "POST"
        req.timeoutInterval = 600
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(key, forHTTPHeaderField: "x-api-key")
        req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: req)
        } catch {
            throw AppError("Network request failed", error: error)
        }
        let http = response as? HTTPURLResponse
        let status = http?.statusCode ?? -1
        let raw = String(data: data, encoding: .utf8) ?? "<non-UTF8 body, \(data.count) bytes>"

        guard (200..<300).contains(status) else {
            // Surface the API's own error message.
            var msg = "HTTP \(status)"
            if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let err = obj["error"] as? [String: Any] {
                msg = "\(err["type"] ?? "error"): \(err["message"] ?? "")"
            }
            let hint: String
            switch status {
            case 401: hint = "Your API key was rejected. Check it in Settings."
            case 429: hint = "Rate limited — wait a moment and retry."
            case 529, 500...599: hint = "Anthropic's API is overloaded. Retry shortly."
            default: hint = "The API returned an error."
            }
            throw AppError(hint, details: "\(msg)\n\nRequest-Id: \(http?.value(forHTTPHeaderField: "request-id") ?? "?")\n\n\(raw.prefix(4000))")
        }

        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw AppError("Unreadable API response", details: raw.prefix(4000).description)
        }
        let stopReason = obj["stop_reason"] as? String ?? ""
        if stopReason == "refusal" {
            let details = (obj["stop_details"] as? [String: Any])?.description ?? ""
            throw AppError("The model declined this request", details: details)
        }
        if stopReason == "max_tokens" {
            throw AppError("Response was cut off", details: "stop_reason=max_tokens. Try fewer products or shorter inputs.")
        }
        guard let blocks = obj["content"] as? [[String: Any]] else {
            throw AppError("Malformed API response", details: raw.prefix(4000).description)
        }
        // With output_config.format, the final text block is the JSON document.
        guard let text = blocks.last(where: { $0["type"] as? String == "text" })?["text"] as? String,
              let jsonData = text.data(using: .utf8) else {
            throw AppError("No text in API response", details: "stop_reason=\(stopReason)\n\(raw.prefix(4000))")
        }
        do {
            var result = try JSONDecoder().decode(ComparisonResult.self, from: jsonData)
            // Defensive: normalise table widths so the UI never indexes out of range.
            let n = result.products.count
            result.table = result.table.map { row in
                var r = row
                if r.values.count < n { r.values += Array(repeating: "—", count: n - r.values.count) }
                if r.values.count > n { r.values = Array(r.values.prefix(n)) }
                if r.bestIndex >= n { r.bestIndex = -1 }
                return r
            }
            return result
        } catch {
            throw AppError("Couldn't parse comparison", details: "\(error)\n\n\(text.prefix(4000))")
        }
    }

    /// Cheap connectivity/key check used by Settings.
    func validateKey(_ key: String) async throws {
        var req = URLRequest(url: URL(string: "https://api.anthropic.com/v1/models?limit=1")!)
        req.setValue(key, forHTTPHeaderField: "x-api-key")
        req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        let (data, resp) = try await URLSession.shared.data(for: req)
        let status = (resp as? HTTPURLResponse)?.statusCode ?? -1
        guard status == 200 else {
            throw AppError("API key rejected (HTTP \(status))", details: String(data: data, encoding: .utf8) ?? "")
        }
    }
}
