import SwiftUI

struct RootView: View {
    @EnvironmentObject var store: AppStore

    var body: some View {
        NavigationSplitView {
            SidebarView()
        } detail: {
            ZStack(alignment: .top) {
                Ground()
                VStack(spacing: 0) {
                    if let u = store.update, !store.updateDismissed { UpdateBanner(info: u) }
                    if store.selectedIndex != nil {
                        ComparisonView()
                    } else {
                        Text("Select or create a comparison").foregroundStyle(Brand.Color.ink2)
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

    var body: some View {
        List(selection: $store.selectedID) {
            Section {
                ForEach(store.comparisons) { c in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(c.result?.verdict.winner ?? (c.title.isEmpty ? "New comparison" : c.title))
                            .font(Brand.Font.headline).lineLimit(1)
                        HStack(spacing: 6) {
                            if c.result != nil {
                                Circle().fill(Brand.Color.accent).frame(width: 6, height: 6)
                                Text("Decided").font(Brand.Font.caption).foregroundStyle(Brand.Color.ink2)
                            } else {
                                Text("Draft").font(Brand.Font.caption).foregroundStyle(Brand.Color.ink3)
                            }
                            Text("·").foregroundStyle(Brand.Color.ink3)
                            Text(c.createdAt, style: .relative).font(Brand.Font.caption).foregroundStyle(Brand.Color.ink3)
                        }
                    }
                    .padding(.vertical, 3)
                    .tag(c.id)
                    .contextMenu { Button("Delete", role: .destructive) { store.delete([c.id]) } }
                }
            } header: {
                Text("Comparisons").font(Brand.Font.monoSmall).foregroundStyle(Brand.Color.ink3).textCase(.uppercase).tracking(1)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Brand.Color.ground)
        .safeAreaInset(edge: .bottom) {
            Button { store.newComparison() } label: {
                HStack { Text("New comparison"); Spacer(); KeyChip(keys: ["⌘", "N"]) }
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(PillButtonStyle())
            .padding(Brand.Space.m)
        }
        .navigationSplitViewColumnWidth(min: 220, ideal: 250)
    }
}

struct TrialBadge: View {
    @EnvironmentObject var store: AppStore
    @ObservedObject private var lic = LicenseManager.shared
    var body: some View {
        Group {
            switch lic.state {
            case .trial(let d):
                Button("Trial · \(d) days left") { store.showPaywall = true }
            case .expired:
                Button("Trial ended · Unlock") { store.showPaywall = true }.foregroundStyle(Brand.Color.warn)
            case .licensed:
                Text("Licensed").foregroundStyle(Brand.Color.ink2)
            }
        }
        .font(Brand.Font.monoSmall)
    }
}
