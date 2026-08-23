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
                    Text("Pickwise Pro").font(Brand.Font.hero)
                    Text(headline).font(Brand.Font.body).foregroundStyle(Brand.Color.ink2)
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(PolarConfig.price).font(Brand.Font.hero)
                        Text("per \(PolarConfig.period) · \(PolarConfig.monthlyComparisons) comparisons · cancel anytime")
                            .font(Brand.Font.caption).foregroundStyle(Brand.Color.ink2)
                    }
                    if !lic.isPro {
                        Button("Subscribe") { lic.openCheckout() }.buttonStyle(PillButtonStyle(role: .primary))
                        Text("You'll get a subscription key by email. Paste it below.").font(Brand.Font.caption).foregroundStyle(Brand.Color.ink3)
                        Divider().overlay(Brand.Color.hairline)
                        Text("Have a key?").font(Brand.Font.headline)
                        HStack {
                            TextField("XXXX-XXXX-XXXX-XXXX", text: $key).textFieldStyle(.plain).font(Brand.Font.mono).field()
                            Button(busy ? "Activating…" : "Activate") {
                                busy = true
                                Task { await lic.activate(key: key); busy = false
                                       if lic.isPro { dismiss() } }
                            }.buttonStyle(PillButtonStyle()).disabled(busy || key.isEmpty)
                        }
                    }
                    if let e = lic.lastError {
                        Text(e.title).font(Brand.Font.caption).foregroundStyle(Brand.Color.danger)
                        if !e.details.isEmpty { Text(e.details).font(Brand.Font.mono).textSelection(.enabled).lineLimit(4) }
                    }
                    HStack { Spacer(); Button(lic.isPro ? "Done" : "Not now") { dismiss() }.buttonStyle(.plain).foregroundStyle(Brand.Color.ink2) }
                }
            }
            .padding(Brand.Space.l)
        }
        .frame(width: 520)
    }

    private var headline: String {
        switch lic.state {
        case .free(let used, let limit):
            return used >= limit ? "You've used your \(limit) free comparisons. Subscribe to keep going."
                                 : "\(limit - used) of \(limit) free comparisons left. No account needed until then."
        case .pro(let k, let used, let limit):
            return "Subscribed (\(k)). \(used) of \(limit) comparisons used this month."
        }
    }
}

// MARK: - Settings

struct SettingsView: View {
    @EnvironmentObject var store: AppStore
    @ObservedObject private var lic = LicenseManager.shared

    var body: some View {
        ZStack {
            Ground()
            VStack(alignment: .leading, spacing: Brand.Space.m) {
                Surface {
                    VStack(alignment: .leading, spacing: Brand.Space.s) {
                        Text("Plan").font(Brand.Font.headline)
                        switch lic.state {
                        case .pro(let k, let used, let limit):
                            Text("Pickwise Pro · \(k)").foregroundStyle(Brand.Color.win)
                            Text("\(used) of \(limit) comparisons used this month.").font(Brand.Font.caption).foregroundStyle(Brand.Color.ink2)
                            Button("Remove subscription key from this Mac") { lic.deactivateLocally() }.buttonStyle(PillButtonStyle())
                        case .free(let used, let limit):
                            Text("Free · \(max(0, limit - used)) of \(limit) comparisons left").foregroundStyle(Brand.Color.ink2)
                            Button("Get Pickwise Pro") { store.showPaywall = true }.buttonStyle(PillButtonStyle(role: .primary))
                        }
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }
                Surface {
                    VStack(alignment: .leading, spacing: Brand.Space.s) {
                        Text("Privacy").font(Brand.Font.headline)
                        Text("Comparisons are sent to the Pickwise service, which runs the AI model and keeps no copy of your products or results. History is stored only on this Mac.")
                            .font(Brand.Font.caption).foregroundStyle(Brand.Color.ink2)
                        Text("Device id · \(PickwiseAPI.deviceID)").font(Brand.Font.monoSmall).foregroundStyle(Brand.Color.ink3).textSelection(.enabled)
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }
                Text("Pickwise \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") ?? "") (\(UpdateChecker.currentBuild))")
                    .font(Brand.Font.caption).foregroundStyle(Brand.Color.ink3)
            }
            .padding(Brand.Space.l)
        }
        .frame(width: 520)
    }
}
