import SwiftUI

struct ComparisonView: View {
    @EnvironmentObject var store: AppStore

    private var binding: Binding<Comparison> {
        Binding(get: { store.comparisons[store.selectedIndex ?? 0] },
                set: { v in if let i = store.selectedIndex { store.comparisons[i] = v } })
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Brand.Space.l) {
                header
                CandidatesEditor(comparison: binding)
                if store.isComparing {
                    ProgressCard()
                } else if let r = binding.wrappedValue.result {
                    ResultView(result: r)
                }
            }
            .padding(Brand.Space.xl)
            .frame(maxWidth: 1100, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Brand.Space.xs) {
            Text("Who's better?").font(Brand.Font.hero)
                .foregroundStyle(Brand.Color.accentGradient)
            Text("Add 2–5 products — names, links, pasted specs, or a screen grab. Get one verdict.")
                .font(Brand.Font.body).foregroundStyle(.secondary)
        }
    }
}

struct CandidatesEditor: View {
    @EnvironmentObject var store: AppStore
    @Binding var comparison: Comparison

    var body: some View {
        GlassCard {
            VStack(spacing: Brand.Space.m) {
                ForEach($comparison.candidates) { $c in
                    CandidateRow(candidate: $c,
                                 index: comparison.candidates.firstIndex { $0.id == c.id } ?? 0,
                                 canRemove: comparison.candidates.count > 2,
                                 onRemove: { comparison.candidates.removeAll { $0.id == c.id } },
                                 onCapture: { Task { await store.captureIntoCandidate(c.id) } })
                }
                HStack {
                    Button { comparison.candidates.append(Candidate()) } label: {
                        Label("Add product", systemImage: "plus")
                    }
                    .buttonStyle(GlassButtonStyle(prominent: false))
                    .disabled(comparison.candidates.count >= 5)
                    Spacer()
                    Button {
                        Task { await store.runComparison() }
                    } label: {
                        Label(comparison.result == nil ? "Compare" : "Compare again", systemImage: "sparkles")
                    }
                    .buttonStyle(GlassButtonStyle())
                    .keyboardShortcut(.return, modifiers: .command)
                    .disabled(store.isComparing || comparison.candidates.filter { !$0.isEmpty }.count < 2)
                }
            }
        }
    }
}

struct CandidateRow: View {
    @Binding var candidate: Candidate
    let index: Int
    let canRemove: Bool
    let onRemove: () -> Void
    let onCapture: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: Brand.Space.m) {
            Text("\(index + 1)")
                .font(Brand.Font.headline)
                .frame(width: 28, height: 28)
                .background(Circle().fill(Brand.Color.accentGradient))
                .foregroundStyle(.black.opacity(0.8))
            VStack(alignment: .leading, spacing: Brand.Space.s) {
                TextField("Product name, URL, or paste specs…", text: $candidate.text, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(Brand.Font.body)
                    .lineLimit(1...6)
                    .glassField()
                if let png = candidate.imagePNG, let img = NSImage(data: png) {
                    HStack(alignment: .top) {
                        Image(nsImage: img).resizable().scaledToFit()
                            .frame(maxHeight: 120)
                            .clipShape(RoundedRectangle(cornerRadius: Brand.radiusSmall, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: Brand.radiusSmall).strokeBorder(.white.opacity(0.2)))
                        Button { candidate.imagePNG = nil } label: { Image(systemName: "xmark.circle.fill") }
                            .buttonStyle(.plain).foregroundStyle(.secondary)
                    }
                }
            }
            Button(action: onCapture) { Image(systemName: "camera.viewfinder") }
                .buttonStyle(GlassButtonStyle(prominent: false))
                .help("Capture a region of your screen (e.g. a product page)")
            Button(action: onRemove) { Image(systemName: "trash") }
                .buttonStyle(GlassButtonStyle(prominent: false))
                .disabled(!canRemove)
        }
    }
}

struct ProgressCard: View {
    @State private var phase = 0
    private let steps = ["Identifying products", "Researching current prices & specs", "Weighing pros and cons", "Writing the verdict"]
    var body: some View {
        GlassCard(glow: true) {
            HStack(spacing: Brand.Space.m) {
                ProgressView().controlSize(.regular)
                VStack(alignment: .leading, spacing: 2) {
                    Text(steps[min(phase, steps.count - 1)]).font(Brand.Font.headline)
                    Text("Usually 30–90 seconds. Live web research takes a moment.").font(Brand.Font.caption).foregroundStyle(.secondary)
                }
                Spacer()
            }
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 12_000_000_000)
                withAnimation { phase = min(phase + 1, steps.count - 1) }
            }
        }
    }
}
