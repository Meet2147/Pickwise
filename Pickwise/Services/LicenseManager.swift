import Foundation
import AppKit

/// Free 7-day local trial → one-time license via Polar.
/// Keys live in the Keychain. Validation hits Polar's org-gated customer-portal
/// API (no server secret needed). Offline grace: 14 days since last successful validation.
@MainActor
final class LicenseManager: ObservableObject {
    enum State: Equatable {
        case trial(daysLeft: Int)
        case expired
        case licensed(displayKey: String)
    }

    static let shared = LicenseManager()

    @Published private(set) var state: State = .expired
    @Published var lastError: AppError?

    // Filled in from PolarConfig (non-secret identifiers).
    static let trialDays = 7
    static let graceDays = 14

    private enum K {
        static let firstLaunch = "trial-first-launch"
        static let key = "polar-license-key"
        static let activationID = "polar-activation-id"
        static let lastValidated = "polar-last-validated"
        static let displayKey = "polar-display-key"
    }

    init() { refresh() }

    var isUnlocked: Bool {
        if case .expired = state { return false }
        return true
    }

    func refresh() {
        if let key = KeychainStore.get(K.key), !key.isEmpty {
            let display = KeychainStore.get(K.displayKey) ?? "••••"
            let last = Double(KeychainStore.get(K.lastValidated) ?? "") ?? 0
            let age = Date().timeIntervalSince1970 - last
            if age < Double(Self.graceDays) * 86400 {
                state = .licensed(displayKey: display)
            } else {
                state = .expired   // grace exhausted; revalidate() will fix it when online
            }
            Task { await revalidate() }
            return
        }
        // Trial
        let first: Double
        if let s = KeychainStore.get(K.firstLaunch), let d = Double(s) {
            first = d
        } else {
            first = Date().timeIntervalSince1970
            try? KeychainStore.set(String(first), for: K.firstLaunch)
        }
        let elapsedDays = Int((Date().timeIntervalSince1970 - first) / 86400)
        let left = Self.trialDays - elapsedDays
        state = left > 0 ? .trial(daysLeft: left) : .expired
    }

    // MARK: Polar

    private struct PolarError: Decodable { let detail: String? }

    func activate(key rawKey: String) async {
        let key = rawKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { lastError = AppError("Enter a license key"); return }
        guard !PolarConfig.organizationID.isEmpty else {
            lastError = AppError("Licensing not configured", details: "PolarConfig.organizationID is empty."); return
        }
        let label = Host.current().localizedName ?? "Mac"
        do {
            let obj = try await post("activate", ["key": key, "organization_id": PolarConfig.organizationID, "label": label])
            guard let activationID = obj["id"] as? String else {
                throw AppError("Unexpected activation response", details: "\(obj)")
            }
            let lk = obj["license_key"] as? [String: Any]
            let display = lk?["display_key"] as? String ?? String(key.suffix(8))
            try KeychainStore.set(key, for: K.key)
            try KeychainStore.set(activationID, for: K.activationID)
            try KeychainStore.set(display, for: K.displayKey)
            try KeychainStore.set(String(Date().timeIntervalSince1970), for: K.lastValidated)
            state = .licensed(displayKey: display)
            lastError = nil
        } catch let e as AppError {
            lastError = e
        } catch {
            lastError = AppError("Activation failed", error: error)
        }
    }

    func revalidate() async {
        guard let key = KeychainStore.get(K.key), let act = KeychainStore.get(K.activationID) else { return }
        do {
            let obj = try await post("validate", ["key": key, "organization_id": PolarConfig.organizationID, "activation_id": act])
            let status = obj["status"] as? String ?? "?"
            if status == "granted" {
                try KeychainStore.set(String(Date().timeIntervalSince1970), for: K.lastValidated)
                state = .licensed(displayKey: obj["display_key"] as? String ?? KeychainStore.get(K.displayKey) ?? "••••")
            } else {
                deactivateLocally()
                lastError = AppError("License is \(status)", details: "\(obj)")
            }
        } catch let e as AppError where e.title.hasPrefix("Polar") {
            // Definitive server rejection (4xx) → key is bad.
            deactivateLocally()
            lastError = e
        } catch {
            // Network failure → stay in grace; nothing to do.
        }
    }

    func deactivateLocally() {
        [K.key, K.activationID, K.lastValidated, K.displayKey].forEach(KeychainStore.delete)
        refresh()
    }

    func openCheckout() {
        guard let url = URL(string: PolarConfig.checkoutURL), !PolarConfig.checkoutURL.isEmpty else {
            lastError = AppError("Checkout link not configured"); return
        }
        NSWorkspace.shared.open(url)
    }

    private func post(_ path: String, _ body: [String: Any]) async throws -> [String: Any] {
        var req = URLRequest(url: URL(string: "https://api.polar.sh/v1/customer-portal/license-keys/\(path)")!)
        req.httpMethod = "POST"
        req.timeoutInterval = 30
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, resp) = try await URLSession.shared.data(for: req)
        let status = (resp as? HTTPURLResponse)?.statusCode ?? -1
        let raw = String(data: data, encoding: .utf8) ?? ""
        guard (200..<300).contains(status) else {
            let detail = (try? JSONDecoder().decode(PolarError.self, from: data))?.detail
            let friendly: String
            switch status {
            case 404: friendly = "Polar: license key not found"
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
