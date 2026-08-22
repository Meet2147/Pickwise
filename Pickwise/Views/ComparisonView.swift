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
                    ProgressRow()
                } else if let r = binding.wrappedValue.result {
                    ResultView(result: r)
                }
            }
            .padding(.horizontal, Brand.Space.xl).padding(.vertical, Brand.Space.l)
            .frame(maxWidth: 1040, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Which one should I buy?").font(Brand.Font.hero).tracking(-0.4)
            Text("Two to five products. Names, links, pasted specs, or a screen grab.")
                .font(Brand.Font.body).foregroundStyle(Brand.Color.ink2)
        }
    }
}

struct CandidatesEditor: View {
    @EnvironmentObject var store: AppStore
    @Binding var comparison: Comparison

    var body: some View {
        Surface(padding: 0) {
            VStack(spacing: 0) {
                ForEach(Array($comparison.candidates.enumerated()), id: \.element.id) { i, $c in
                    CandidateRow(candidate: $c, index: i,
                                 canRemove: comparison.candidates.count > 2,
                                 onRemove: { comparison.candidates.removeAll { $0.id == c.id } },
                                 onCapture: { Task { await store.captureIntoCandidate(c.id) } })
                    Divider().overlay(Brand.Color.hairline)
                }
                HStack {
                    Button { comparison.candidates.append(Candidate()) } label: { Text("Add product") }
                        .buttonStyle(PillButtonStyle())
                        .disabled(comparison.candidates.count >= 5)
                    Spacer()
                    Button { Task { await store.runComparison() } } label: {
                        HStack(spacing: 10) {
                            Text(comparison.result == nil ? "Compare" : "Compare again")
                            KeyChip(keys: ["⌘", "↵"], onAccent: true)
                        }
                    }
                    .buttonStyle(PillButtonStyle(role: .primary))
                    .keyboardShortcut(.return, modifiers: .command)
                    .disabled(store.isComparing || comparison.candidates.filter { !$0.isEmpty }.count < 2)
                }
                .padding(Brand.Space.m)
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
            Text(String(format: "%02d", index + 1))
                .font(Brand.Font.mono).foregroundStyle(Brand.Color.ink3)
                .frame(width: 28, alignment: .leading).padding(.top, 9)
            VStack(alignment: .leading, spacing: Brand.Space.s) {
                TextField("Product name, link, or pasted specs", text: $candidate.text, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(Brand.Font.body)
                    .lineLimit(1...6)
                    .field()
                if let png = candidate.imagePNG, let img = NSImage(data: png) {
                    HStack(alignment: .top, spacing: Brand.Space.s) {
                        Image(nsImage: img).resizable().scaledToFit()
                            .frame(maxHeight: 110)
                            .clipShape(RoundedRectangle(cornerRadius: Brand.radiusSmall, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: Brand.radiusSmall).strokeBorder(Brand.Color.hairline))
                        Button("Remove capture") { candidate.imagePNG = nil }
                            .buttonStyle(.plain).font(Brand.Font.caption).foregroundStyle(Brand.Color.ink2)
                    }
                }
            }
            Button(action: onCapture) { Image(systemName: "viewfinder") }
                .buttonStyle(PillButtonStyle())
                .help("Capture a region of your screen")
            Button(action: onRemove) { Image(systemName: "xmark") }
                .buttonStyle(PillButtonStyle())
                .disabled(!canRemove)
                .help("Remove")
        }
        .padding(Brand.Space.m)
    }
}

struct ProgressRow: View {
    @State private var phase = 0
    private let steps = ["Identifying products", "Checking current prices and specs", "Weighing trade-offs", "Writing the verdict"]
    var body: some View {
        Surface {
            HStack(spacing: Brand.Space.m) {
                ProgressView().controlSize(.small)
                VStack(alignment: .leading, spacing: 2) {
                    Text(steps[min(phase, steps.count - 1)]).font(Brand.Font.headline)
                    Text("Usually 30–90 seconds — it's reading the web.").font(Brand.Font.caption).foregroundStyle(Brand.Color.ink2)
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
