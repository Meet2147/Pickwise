import SwiftUI
import PhotosUI

struct MobileRootView: View {
    @EnvironmentObject var store: MobileStore
    @AppStorage("onboarded") private var onboarded = false

    var body: some View {
        if !onboarded {
            OnboardingView { withAnimation { onboarded = true } }
        } else {
            mainView
        }
    }

    @State private var path: [Comparison] = []

    private var mainView: some View {
        NavigationStack(path: $path) {
            ZStack {
                Neu.bg.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        header
                        Button { path.append(Comparison()) } label: {
                            HStack {
                                Image(systemName: "plus").font(Neu.Font.headline)
                                Text("New comparison").font(Neu.Font.headline)
                                Spacer()
                                Image(systemName: "chevron.right").font(Neu.Font.caption).foregroundStyle(Neu.ink2)
                            }
                            .foregroundStyle(Neu.ink)
                            .padding(20)
                        }
                        .buttonStyle(.plain)
                        .neuRaised()

                        if !store.comparisons.isEmpty {
                            Text("History").font(Neu.Font.caption).tracking(1.2)
                                .foregroundStyle(Neu.ink2).textCase(.uppercase)
                                .padding(.leading, 6)
                            ForEach(store.comparisons) { c in
                                Button { path.append(c) } label: { historyRow(c) }
                                    .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(20)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: Comparison.self) { c in
                EditorView(comparison: c)
            }
            .task {
                if SampleData.isDemo, path.isEmpty, let first = store.comparisons.first {
                    try? await Task.sleep(nanoseconds: 2_200_000_000)
                    path.append(first)
                }
            }
        }
        .tint(Neu.accent)
        .sheet(item: $store.error) { MobileErrorSheet(error: $0) }
        .sheet(isPresented: $store.showPaywall) { MobilePaywall(quota: store.quota) }
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Pickwise").font(Neu.Font.hero).foregroundStyle(Neu.ink)
                Text("Which one should I buy?").font(Neu.Font.body).foregroundStyle(Neu.ink2)
            }
            Spacer()
            if let q = store.quota {
                VStack(spacing: 1) {
                    Text("\(q.plan == "pro" ? q.limit - q.used : max(0, q.limit - q.used))")
                        .font(.system(size: 18, weight: .bold, design: .rounded)).foregroundStyle(Neu.accent)
                    Text("left").font(Neu.Font.caption).foregroundStyle(Neu.ink2)
                }
                .frame(width: 56, height: 56)
                .neuInset(radius: 28)
            }
        }
        .padding(.top, 8)
    }

    private func historyRow(_ c: Comparison) -> some View {
        HStack(spacing: 14) {
            Image(systemName: c.result == nil ? "circle.dashed" : "checkmark.circle.fill")
                .foregroundStyle(c.result == nil ? Neu.ink2 : Neu.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text(c.result?.verdict.winner ?? (c.title.isEmpty ? "Draft" : c.title))
                    .font(Neu.Font.headline).foregroundStyle(Neu.ink).lineLimit(1)
                Text(c.createdAt, style: .relative).font(Neu.Font.caption).foregroundStyle(Neu.ink2)
            }
            Spacer()
            Image(systemName: "chevron.right").font(Neu.Font.caption).foregroundStyle(Neu.ink2)
        }
        .padding(16)
        .neuRaised(radius: Neu.radiusSmall + 4, depth: 5)
        .contextMenu {
            Button(role: .destructive) {
                store.comparisons.removeAll { $0.id == c.id }; store.persist()
            } label: { Label("Delete", systemImage: "trash") }
        }
    }
}

// MARK: - Editor

struct EditorView: View {
    @EnvironmentObject var store: MobileStore
    @State var comparison: Comparison
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Neu.bg.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    ForEach(Array($comparison.candidates.enumerated()), id: \.element.id) { i, $c in
                        CandidateCard(index: i, candidate: $c,
                                      canRemove: comparison.candidates.count > 2,
                                      onRemove: { comparison.candidates.removeAll { $0.id == c.id } })
                    }
                    HStack {
                        Button { comparison.candidates.append(Candidate()) } label: {
                            Label("Add", systemImage: "plus")
                        }
                        .buttonStyle(NeuButtonStyle())
                        .disabled(comparison.candidates.count >= 5)
                        Spacer()
                        Button {
                            Task { await store.run(comparison) }
                        } label: {
                            Label(store.isComparing ? "Comparing…" : "Compare", systemImage: "sparkle")
                        }
                        .buttonStyle(NeuButtonStyle(prominent: true))
                        .disabled(store.isComparing || comparison.candidates.filter { !$0.isEmpty }.count < 2)
                    }
                    if store.isComparing { ComparingCard() }
                    if let r = liveResult { MobileResultView(result: r) }
                }
                .padding(20)
            }
        }
        .navigationTitle(comparison.title.isEmpty ? "New comparison" : "")
        .navigationBarTitleDisplayMode(.inline)
        .tint(Neu.accent)
    }

    private var liveResult: ComparisonResult? {
        store.comparisons.first { $0.id == comparison.id }?.result ?? comparison.result
    }
}

/// One product input: inset text well + photo attachment.
struct CandidateCard: View {
    let index: Int
    @Binding var candidate: Candidate
    let canRemove: Bool
    let onRemove: () -> Void
    @State private var photoItem: PhotosPickerItem?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(String(format: "%02d", index + 1)).font(Neu.Font.mono).foregroundStyle(Neu.accent)
                Spacer()
                PhotosPicker(selection: $photoItem, matching: .images) {
                    Image(systemName: "photo.badge.plus").font(Neu.Font.headline).foregroundStyle(Neu.ink2)
                }
                if canRemove {
                    Button(action: onRemove) {
                        Image(systemName: "xmark").font(Neu.Font.caption).foregroundStyle(Neu.ink2)
                    }.buttonStyle(.plain).padding(.leading, 10)
                }
            }
            TextField("Product name, link, or specs", text: $candidate.text, axis: .vertical)
                .font(Neu.Font.body).foregroundStyle(Neu.ink)
                .lineLimit(1...5)
                .padding(14)
                .neuInset()
            if let png = candidate.imagePNG, let ui = UIImage(data: png) {
                HStack(alignment: .top, spacing: 10) {
                    Image(uiImage: ui).resizable().scaledToFit()
                        .frame(maxHeight: 130)
                        .clipShape(RoundedRectangle(cornerRadius: Neu.radiusSmall, style: .continuous))
                    Button { candidate.imagePNG = nil } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(Neu.ink2)
                    }.buttonStyle(.plain)
                }
            }
        }
        .padding(18)
        .neuRaised()
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            Task {
                guard let data = try? await item.loadTransferable(type: Data.self),
                      let img = UIImage(data: data) else { return }
                candidate.imagePNG = img.pickwiseNormalizedPNG()
                photoItem = nil
            }
        }
    }
}

extension UIImage {
    /// Downscale to ≤1024pt wide and re-encode as PNG so payloads stay small
    /// and HEIC photos become something the API accepts.
    func pickwiseNormalizedPNG() -> Data? {
        let maxSide: CGFloat = 1024
        let scaleFactor = min(1, maxSide / max(size.width, size.height))
        let target = CGSize(width: size.width * scaleFactor, height: size.height * scaleFactor)
        let renderer = UIGraphicsImageRenderer(size: target, format: {
            let f = UIGraphicsImageRendererFormat(); f.scale = 1; return f
        }())
        return renderer.image { _ in draw(in: CGRect(origin: .zero, size: target)) }.pngData()
    }
}

struct ComparingCard: View {
    @State private var phase = 0
    private let steps = ["Identifying products", "Checking current prices", "Weighing trade-offs", "Writing the verdict"]
    var body: some View {
        HStack(spacing: 14) {
            ProgressView().tint(Neu.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text(steps[min(phase, steps.count - 1)]).font(Neu.Font.headline).foregroundStyle(Neu.ink)
                Text("Usually 30–90 seconds").font(Neu.Font.caption).foregroundStyle(Neu.ink2)
            }
            Spacer()
        }
        .padding(18)
        .neuRaised()
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 12_000_000_000)
                withAnimation { phase = min(phase + 1, steps.count - 1) }
            }
        }
    }
}

// MARK: - Sheets

struct MobileErrorSheet: View {
    let error: AppError
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        ZStack {
            Neu.bg.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 18) {
                Text(error.title).font(Neu.Font.title).foregroundStyle(Neu.danger)
                if !error.details.isEmpty {
                    ScrollView {
                        Text(error.details).font(Neu.Font.mono).foregroundStyle(Neu.ink2)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(14).neuInset()
                    .frame(maxHeight: 200)
                }
                Button("OK") { dismiss() }.buttonStyle(NeuButtonStyle(prominent: true))
                    .frame(maxWidth: .infinity)
            }
            .padding(24)
        }
        .presentationDetents([.medium])
    }
}

struct MobilePaywall: View {
    let quota: PickwiseAPI.Quota?
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        ZStack {
            Neu.bg.ignoresSafeArea()
            VStack(spacing: 20) {
                Text("\(quota?.used ?? 3)/\(quota?.limit ?? 3)")
                    .font(.system(size: 30, weight: .bold, design: .rounded)).foregroundStyle(Neu.accent)
                    .frame(width: 96, height: 96)
                    .neuInset(radius: 48)
                Text("Free comparisons used").font(Neu.Font.title).foregroundStyle(Neu.ink)
                Text("Pickwise Pro on iPhone is coming soon. Until then, Pro lives in the Mac app — 30 comparisons a month, $5.99.")
                    .font(Neu.Font.body).foregroundStyle(Neu.ink2)
                    .multilineTextAlignment(.center)
                Link("Get Pickwise for Mac", destination: URL(string: "https://pickwise.dashovia.app")!)
                    .buttonStyle(NeuButtonStyle(prominent: true))
                Button("Not now") { dismiss() }.buttonStyle(NeuButtonStyle())
            }
            .padding(28)
        }
        .presentationDetents([.medium, .large])
    }
}
