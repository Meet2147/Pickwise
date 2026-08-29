import Foundation

/// Client for the Pickwise API (Server/). The server holds the model key and meters usage;
/// the app sends candidates plus either a subscription key or an anonymous device id.
struct PickwiseAPI {
    static let baseURL = URL(string: ProcessInfo.processInfo.environment["PICKWISE_API"] ?? "https://pickwise-api-3jv9.onrender.com")!
    static let deviceIDKey = "device-id"

    /// Stable anonymous id for the free tier, created once and kept in the Keychain.
    static var deviceID: String {
        if let id = KeychainStore.get(deviceIDKey) { return id }
        let id = UUID().uuidString
        try? KeychainStore.set(id, for: deviceIDKey)
        return id
    }

    struct Quota: Equatable { let plan: String; let used: Int; let limit: Int }
    struct Response { let result: ComparisonResult; let quota: Quota }

    /// Thrown when the server says the caller has no remaining comparisons (HTTP 402).
    struct QuotaExhausted: Error { let code: String; let used: Int; let limit: Int }

    func compare(_ candidates: [Candidate]) async throws -> Response {
        let live = candidates.filter { !$0.isEmpty }
        guard live.count >= 2 else { throw AppError("Add at least two products", details: "A comparison needs 2–5 products.") }

        var body: [String: Any] = [
            "candidates": live.map { c -> [String: Any] in
                var d: [String: Any] = ["text": c.text.trimmingCharacters(in: .whitespacesAndNewlines)]
                if let png = c.imagePNG { d["imagePNG"] = png.base64EncodedString() }
                return d
            },
            "deviceId": Self.deviceID,
        ]
        if let key = await LicenseManager.shared.storedKey, let act = await LicenseManager.shared.storedActivationID {
            body["licenseKey"] = key; body["activationId"] = act
        }

        var req = URLRequest(url: Self.baseURL.appendingPathComponent("v1/compare"))
        req.httpMethod = "POST"
        req.timeoutInterval = 600
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Pickwise/\(UpdateChecker.currentBuild)", forHTTPHeaderField: "User-Agent")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let data: Data, response: URLResponse
        do { (data, response) = try await URLSession.shared.data(for: req) }
        catch { throw AppError("Couldn't reach the Pickwise service", error: error) }
        let status = (response as? HTTPURLResponse)?.statusCode ?? -1
        let raw = String(data: data, encoding: .utf8) ?? "<\(data.count) bytes>"
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw AppError("Unreadable response from the Pickwise service (HTTP \(status))", details: String(raw.prefix(2000)))
        }

        if status == 402 {
            throw QuotaExhausted(code: obj["code"] as? String ?? "quota_exhausted",
                                 used: obj["used"] as? Int ?? 0, limit: obj["limit"] as? Int ?? 0)
        }
        guard status == 200 else {
            let msg = obj["message"] as? String ?? "HTTP \(status)"
            let hint: String
            switch status {
            case 503: hint = "The service is busy or not configured. Try again in a moment."
            case 400: hint = "The request was rejected."
            default: hint = "The Pickwise service returned an error."
            }
            throw AppError(hint, details: "HTTP \(status) · \(obj["code"] ?? "")\n\(msg)")
        }
        // 200 with an in-band error (status line was already sent while the model worked).
        if let err = obj["error"] as? [String: Any] {
            let code = err["code"] as? String ?? "error"
            let hint: String
            switch code {
            case "refused": hint = "The model declined this request"
            case "truncated": hint = "Response was cut off"
            case "upstream_error": hint = "The AI service returned an error. Try again."
            default: hint = "Comparison failed"
            }
            throw AppError(hint, details: "\(code)\n\(err["message"] ?? "")\nRequest-Id: \(err["requestId"] ?? "?")")
        }
        guard let resultObj = obj["result"], let resultData = try? JSONSerialization.data(withJSONObject: resultObj) else {
            throw AppError("Malformed response from the Pickwise service", details: String(raw.prefix(2000)))
        }
        do {
            let result = try JSONDecoder().decode(ComparisonResult.self, from: resultData)
            let q = Quota(plan: obj["plan"] as? String ?? "free", used: obj["used"] as? Int ?? 0, limit: obj["limit"] as? Int ?? 0)
            return Response(result: result, quota: q)
        } catch {
            throw AppError("Couldn't parse comparison", details: "\(error)\n\n\(raw.prefix(2000))")
        }
    }
}
