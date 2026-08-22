import SwiftUI

// MARK: - Error sheet (fail loud, copyable details)

struct ErrorSheet: View {
    let error: AppError
    @Environment(\.dismiss) private var dismiss
    @State private var copied = false

    var body: some View {
        ZStack {
            Ground()
            Surface(padding: Brand.Space.l) {
                VStack(alignment: .leading, spacing: Brand.Space.m) {
                    Text(error.title).font(Brand.Font.title).foregroundStyle(Brand.Color.danger)
                    if !error.details.isEmpty {
                        ScrollView {
                            Text(error.details).font(Brand.Font.mono).textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(maxHeight: 220)
                        .field()
                    }
                    HStack {
                        Button(copied ? "Copied" : "Copy details") {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString("\(error.title)\n\n\(error.details)", forType: .string)
                            copied = true
                        }.buttonStyle(PillButtonStyle())
                        Spacer()
                        Button("OK") { dismiss() }.buttonStyle(PillButtonStyle(role: .primary)).keyboardShortcut(.defaultAction)
                    }
                }
            }
            .padding(Brand.Space.l)
        }
        .frame(width: 560)
    }
}

// MARK: - Update banner

struct UpdateBanner: View {
    @EnvironmentObject var store: AppStore
    let info: UpdateInfo
    var body: some View {
        HStack(spacing: Brand.Space.m) {
            Circle().fill(Brand.Color.accent).frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 1) {
                Text("Pickwise \(info.version) is available").font(Brand.Font.headline)
                if !info.notes.isEmpty { Text(info.notes).font(Brand.Font.caption).foregroundStyle(.secondary).lineLimit(1) }
            }
            Spacer()
            Button("Download") { if let u = URL(string: info.url) { NSWorkspace.shared.open(u) } }
                .buttonStyle(PillButtonStyle(role: .primary))
            Button { store.updateDismissed = true } label: { Image(systemName: "xmark") }
                .buttonStyle(.plain).foregroundStyle(.secondary)
        }
        .padding(.horizontal, Brand.Space.m).padding(.vertical, Brand.Space.s)
        .background(.ultraThinMaterial)
        .overlay(Divider(), alignment: .bottom)
    }
}

// MARK: - Paywall

struct PaywallView: View {
    @EnvironmentObject var store: AppStore
    @ObservedObject private var lic = LicenseManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var key = ""
    @State private var busy = false

    var body: some View {
        ZStack {
            Ground()
            Surface(emphasis: true, padding: Brand.Space.l) {
                VStack(alignment: .leading, spacing: Brand.Space.m) {
                    Text("Unlock Pickwise").font(Brand.Font.hero)
                    Text(headline).font(Brand.Font.body).foregroundStyle(.secondary)
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(PolarConfig.price).font(Brand.Font.hero)
                        Text("one-time · yours forever").font(Brand.Font.caption).foregroundStyle(.secondary)
                    }
                    Button("Buy a license") { lic.openCheckout() }.buttonStyle(PillButtonStyle(role: .primary))
                    Divider()
                    Text("Already have a key?").font(Brand.Font.headline)
                    HStack {
                        TextField("XXXX-XXXX-XXXX-XXXX", text: $key).textFieldStyle(.plain).font(Brand.Font.mono).field()
                        Button(busy ? "Activating…" : "Activate") {
                            busy = true
                            Task { await lic.activate(key: key); busy = false
                                   if case .licensed = lic.state { dismiss() } }
                        }.buttonStyle(PillButtonStyle()).disabled(busy || key.isEmpty)
                    }
                    if let e = lic.lastError {
                        Text(e.title).font(Brand.Font.caption).foregroundStyle(Brand.Color.danger)
                        if !e.details.isEmpty { Text(e.details).font(Brand.Font.mono).textSelection(.enabled).lineLimit(4) }
                    }
                    HStack { Spacer(); Button("Not now") { dismiss() }.buttonStyle(.plain).foregroundStyle(.secondary) }
                }
            }
            .padding(Brand.Space.l)
        }
        .frame(width: 520)
    }

    private var headline: String {
        switch lic.state {
        case .trial(let d): return "Your free trial has \(d) day\(d == 1 ? "" : "s") left. Unlock unlimited comparisons."
        case .expired: return "Your 7-day trial has ended. Buy once, keep it forever."
        case .licensed(let k): return "Licensed (\(k)). Thank you!"
        }
    }
}

// MARK: - Settings

struct SettingsView: View {
    @ObservedObject private var lic = LicenseManager.shared
    @State private var apiKey = ClaudeService.apiKey ?? ""
    @State private var status = ""
    @State private var statusOK = true
    @State private var busy = false

    var body: some View {
        ZStack {
            Ground()
            VStack(alignment: .leading, spacing: Brand.Space.m) {
                Surface {
                    VStack(alignment: .leading, spacing: Brand.Space.s) {
                        Text("Anthropic API key").font(Brand.Font.headline)
                        Text("Comparisons run on Claude using your own key. The key is stored in your macOS Keychain and sent only to api.anthropic.com.")
                            .font(Brand.Font.caption).foregroundStyle(.secondary)
                        HStack {
                            SecureField("sk-ant-…", text: $apiKey).textFieldStyle(.plain).font(Brand.Font.mono).field()
                            Button(busy ? "Checking…" : "Save & test") { saveKey() }
                                .buttonStyle(PillButtonStyle(role: .primary)).disabled(busy || apiKey.isEmpty)
                        }
                        if !status.isEmpty {
                            Text(status).font(Brand.Font.caption)
                                .foregroundStyle(statusOK ? Brand.Color.win : Brand.Color.danger)
                                .textSelection(.enabled)
                        }
                        Link("Get a key at console.anthropic.com", destination: URL(string: "https://console.anthropic.com/settings/keys")!)
                            .font(Brand.Font.caption)
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }
                Surface {
                    VStack(alignment: .leading, spacing: Brand.Space.s) {
                        Text("License").font(Brand.Font.headline)
                        switch lic.state {
                        case .licensed(let k):
                            Text("Licensed · \(k)").foregroundStyle(Brand.Color.win)
                            Button("Remove license from this Mac") { lic.deactivateLocally() }.buttonStyle(PillButtonStyle())
                        case .trial(let d):
                            Text("Trial · \(d) days left").foregroundStyle(.secondary)
                        case .expired:
                            Text("Trial ended").foregroundStyle(Brand.Color.warn)
                        }
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }
                Text("Pickwise \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") ?? "") (\(UpdateChecker.currentBuild))")
                    .font(Brand.Font.caption).foregroundStyle(.secondary)
            }
            .padding(Brand.Space.l)
        }
        .frame(width: 520)
    }

    private func saveKey() {
        busy = true; status = ""
        Task {
            do {
                try await ClaudeService().validateKey(apiKey)
                try KeychainStore.set(apiKey, for: ClaudeService.apiKeyKeychainKey)
                status = "Key works and is saved in Keychain."; statusOK = true
            } catch let e as AppError {
                status = "\(e.title)\n\(e.details.prefix(300))"; statusOK = false
            } catch {
                status = error.localizedDescription; statusOK = false
            }
            busy = false
        }
    }
}
