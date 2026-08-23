import Foundation
import AppKit

/// Free tier (5 comparisons, metered by the server per device) → Pickwise Pro subscription via Polar.
/// Polar issues a license key with the subscription and revokes it when it lapses, so the key
/// doubles as the subscription check. Key + activation live in the Keychain.
@MainActor
final class LicenseManager: ObservableObject {
    static let shared = LicenseManager()

    enum State: Equatable {
        case free(used: Int, limit: Int)
        case pro(displayKey: String, used: Int, limit: Int)
    }

    @Published private(set) var state: State = .free(used: 0, limit: PolarConfig.freeComparisons)
    @Published var lastError: AppError?

    private enum K {
        static let key = "polar-license-key"
        static let activationID = "polar-activation-id"
        static let displayKey = "polar-display-key"
        static let freeUsed = "free-used"
    }

    var storedKey: String? { KeychainStore.get(K.key).flatMap { $0.isEmpty ? nil : $0 } }
    var storedActivationID: String? { KeychainStore.get(K.activationID) }
    var isPro: Bool { if case .pro = state { return true } else { return false } }

    init() { refresh() }

    func refresh() {
        if let _ = storedKey {
            state = .pro(displayKey: KeychainStore.get(K.displayKey) ?? "••••", used: 0, limit: PolarConfig.monthlyComparisons)
        } else {
            state = .free(used: Int(KeychainStore.get(K.freeUsed) ?? "") ?? 0, limit: PolarConfig.freeComparisons)
        }
    }

    /// Called after every server response so the badge and paywall reflect real usage.
    func apply(_ q: PickwiseAPI.Quota) {
        if q.plan == "pro", let _ = storedKey {
            state = .pro(displayKey: KeychainStore.get(K.displayKey) ?? "••••", used: q.used, limit: q.limit)
        } else {
            try? KeychainStore.set(String(q.used), for: K.freeUsed)
            state = .free(used: q.used, limit: q.limit)
        }
    }

    // MARK: Polar

    private struct PolarError: Decodable { let detail: String? }

    func activate(key rawKey: String) async {
        let key = rawKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { lastError = AppError("Enter your subscription key"); return }
        guard !PolarConfig.organizationID.isEmpty else {
            lastError = AppError("Subscriptions aren't configured yet", details: "PolarConfig.organizationID is empty."); return
        }
        let label = Host.current().localizedName ?? "Mac"
        do {
            let obj = try await post("activate", ["key": key, "organization_id": PolarConfig.organizationID, "label": label])
            guard let activationID = obj["id"] as? String else { throw AppError("Unexpected activation response", details: "\(obj)") }
            let display = (obj["license_key"] as? [String: Any])?["display_key"] as? String ?? String(key.suffix(8))
            try KeychainStore.set(key, for: K.key)
            try KeychainStore.set(activationID, for: K.activationID)
            try KeychainStore.set(display, for: K.displayKey)
            state = .pro(displayKey: display, used: 0, limit: PolarConfig.monthlyComparisons)
            lastError = nil
        } catch let e as AppError { lastError = e }
        catch { lastError = AppError("Activation failed", error: error) }
    }

    func deactivateLocally() {
        [K.key, K.activationID, K.displayKey].forEach(KeychainStore.delete)
        refresh()
    }

    func openCheckout() {
        guard !PolarConfig.checkoutURL.isEmpty, let url = URL(string: PolarConfig.checkoutURL) else {
            lastError = AppError("Checkout isn't configured yet"); return
        }
        NSWorkspace.shared.open(url)
    }

    private func post(_ path: String, _ body: [String: Any]) async throws -> [String: Any] {
        var req = URLRequest(url: URL(string: "https://api.polar.sh/v1/customer-portal/license-keys/\(path)")!)
        req.httpMethod = "POST"; req.timeoutInterval = 30
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, resp) = try await URLSession.shared.data(for: req)
        let status = (resp as? HTTPURLResponse)?.statusCode ?? -1
        let raw = String(data: data, encoding: .utf8) ?? ""
        guard (200..<300).contains(status) else {
            let detail = (try? JSONDecoder().decode(PolarError.self, from: data))?.detail
            let friendly: String
            switch status {
            case 404: friendly = "Polar: subscription key not found"
            case 403: friendly = "Polar: key revoked, expired, or activation limit reached"
            default:  friendly = "Polar: HTTP \(status)"
            }
            throw AppError(friendly, details: detail ?? raw)
        }
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw AppError("Polar: unreadable response", details: raw)
        }
        return obj
    }
}
