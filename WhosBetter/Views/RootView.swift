import SwiftUI

struct RootView: View {
    @EnvironmentObject var store: AppStore

    var body: some View {
        NavigationSplitView {
            SidebarView()
        } detail: {
            ZStack(alignment: .top) {
                AuroraBackground()
                VStack(spacing: 0) {
                    if let u = store.update, !store.updateDismissed { UpdateBanner(info: u) }
                    if store.selectedIndex != nil {
                        ComparisonView()
                    } else {
                        Text("Select or create a comparison").foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationSplitViewStyle(.balanced)
        .toolbar { ToolbarItem(placement: .primaryAction) { TrialBadge() } }
        .sheet(item: $store.error) { ErrorSheet(error: $0) }
        .sheet(isPresented: $store.showPaywall) { PaywallView() }
        .onAppear {
            if SampleData.isDemo {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    NSApp.windows.first?.setFrame(NSRect(x: 200, y: 40, width: 1240, height: 1000), display: true)
                }
            }
        }
    }
}

struct SidebarView: View {
    @EnvironmentObject var store: AppStore
    @State private var selection = Set<Comparison.ID>()

    var body: some View {
        List(selection: $store.selectedID) {
            Section("Comparisons") {
                ForEach(store.comparisons) { c in
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            if let w = c.result?.verdict.winner {
                                Image(systemName: "crown.fill").foregroundStyle(Brand.Color.win).font(.caption)
                                Text(w).font(Brand.Font.headline).lineLimit(1)
                            } else {
                                Text(c.title.isEmpty ? "New comparison" : c.title).font(Brand.Font.headline).lineLimit(1)
                            }
                        }
                        Text(c.createdAt, style: .relative).font(Brand.Font.caption).foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
                    .tag(c.id)
                    .contextMenu { Button("Delete", role: .destructive) { store.delete([c.id]) } }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(AuroraBackground().opacity(0.6))
        .safeAreaInset(edge: .bottom) {
            Button { store.newComparison() } label: {
                Label("New Comparison", systemImage: "plus").frame(maxWidth: .infinity)
            }
            .buttonStyle(GlassButtonStyle())
            .padding(Brand.Space.m)
        }
        .navigationSplitViewColumnWidth(min: 220, ideal: 260)
    }
}

struct TrialBadge: View {
    @EnvironmentObject var store: AppStore
    @ObservedObject private var lic: LicenseManager
    init() { _lic = ObservedObject(wrappedValue: LicenseManager.shared) }
    var body: some View {
        Group {
            switch lic.state {
            case .trial(let d):
                Button("Trial · \(d)d left") { store.showPaywall = true }
            case .expired:
                Button("Trial ended · Unlock") { store.showPaywall = true }.tint(Brand.Color.warn)
            case .licensed:
                Label("Licensed", systemImage: "checkmark.seal.fill").foregroundStyle(Brand.Color.win)
            }
        }
        .font(Brand.Font.caption)
    }
}
