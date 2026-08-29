import SwiftUI

struct MobileRootView: View {
    @EnvironmentObject var store: MobileStore

    var body: some View {
        NavigationStack {
            ZStack {
                Ground()
                List {
                    Section {
                        NavigationLink { EditorView(comparison: Comparison()) } label: {
                            Label("New comparison", systemImage: "plus")
                                .font(Brand.Font.headline)
                        }
                    }
                    if !store.comparisons.isEmpty {
                        Section("History") {
                            ForEach(store.comparisons) { c in
                                NavigationLink { EditorView(comparison: c) } label: {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(c.result?.verdict.winner ?? c.title)
                                            .font(Brand.Font.headline).lineLimit(1)
                                        Text(c.createdAt, style: .relative)
                                            .font(Brand.Font.caption).foregroundStyle(Brand.Color.ink3)
                                    }
                                }
                            }
                            .onDelete { idx in store.comparisons.remove(atOffsets: idx); store.persist() }
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Pickwise")
            .toolbar {
                if let q = store.quota {
                    ToolbarItem(placement: .topBarTrailing) {
                        Text(q.plan == "pro" ? "Pro \(q.used)/\(q.limit)" : "Free \(max(0, q.limit - q.used)) left")
                            .font(Brand.Font.monoSmall).foregroundStyle(Brand.Color.ink2)
                    }
                }
            }
        }
        .sheet(item: $store.error) { e in MobileErrorSheet(error: e) }
        .sheet(isPresented: $store.showPaywall) { MobilePaywall() }
    }
}

struct EditorView: View {
    @EnvironmentObject var store: MobileStore
    @State var comparison: Comparison

    var body: some View {
        ZStack {
            Ground()
            ScrollView {
                VStack(alignment: .leading, spacing: Brand.Space.m) {
                    Surface(padding: 0) {
                        VStack(spacing: 0) {
                            ForEach(Array($comparison.candidates.enumerated()), id: \.element.id) { i, $c in
                                HStack(alignment: .top, spacing: Brand.Space.s) {
                                    Text(String(format: "%02d", i + 1))
                                        .font(Brand.Font.mono).foregroundStyle(Brand.Color.ink3).padding(.top, 10)
                                    TextField("Product name, link, or specs", text: $c.text, axis: .vertical)
                                        .lineLimit(1...5).field()
                                    if comparison.candidates.count > 2 {
                                        Button { comparison.candidates.removeAll { $0.id == c.id } } label: {
                                            Image(systemName: "xmark").font(Brand.Font.caption)
                                        }.buttonStyle(.plain).padding(.top, 12).foregroundStyle(Brand.Color.ink3)
                                    }
                                }
                                .padding(Brand.Space.m)
                                Divider().overlay(Brand.Color.hairline)
                            }
                            HStack {
                                Button("Add product") { comparison.candidates.append(Candidate()) }
                                    .buttonStyle(PillButtonStyle())
                                    .disabled(comparison.candidates.count >= 5)
                                Spacer()
                                Button(store.isComparing ? "Comparing…" : (comparison.result == nil ? "Compare" : "Compare again")) {
                                    Task { await store.run(comparison) }
                                }
                                .buttonStyle(PillButtonStyle(role: .primary))
                                .disabled(store.isComparing || comparison.candidates.filter { !$0.isEmpty }.count < 2)
                            }
                            .padding(Brand.Space.m)
                        }
                    }
                    if store.isComparing { ProgressView("Researching — 30–90 seconds").frame(maxWidth: .infinity) }
                    if let r = liveResult { ResultView(result: r) }
                }
                .padding(Brand.Space.m)
            }
        }
        .navigationTitle(comparison.title.isEmpty ? "New comparison" : comparison.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var liveResult: ComparisonResult? {
        store.comparisons.first { $0.id == comparison.id }?.result ?? comparison.result
    }
}

struct MobileErrorSheet: View {
    let error: AppError
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        ZStack {
            Ground()
            VStack(alignment: .leading, spacing: Brand.Space.m) {
                Text(error.title).font(Brand.Font.title).foregroundStyle(Brand.Color.danger)
                ScrollView { Text(error.details).font(Brand.Font.mono).textSelection(.enabled) }
                Button("OK") { dismiss() }.buttonStyle(PillButtonStyle(role: .primary))
            }.padding(Brand.Space.l)
        }
        .presentationDetents([.medium])
    }
}

struct MobilePaywall: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        ZStack {
            Ground()
            VStack(alignment: .leading, spacing: Brand.Space.m) {
                Text("Out of free comparisons").font(Brand.Font.title)
                Text("Pickwise Pro subscriptions are coming to iOS. For now, Pro is available in the Mac app — or wait for next month's free comparisons.")
                    .font(Brand.Font.body).foregroundStyle(Brand.Color.ink2)
                Button("OK") { dismiss() }.buttonStyle(PillButtonStyle(role: .primary))
            }.padding(Brand.Space.l)
        }
        .presentationDetents([.medium])
    }
}
