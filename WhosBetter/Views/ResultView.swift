import SwiftUI

struct ResultView: View {
    let result: ComparisonResult

    var body: some View {
        VStack(alignment: .leading, spacing: Brand.Space.l) {
            verdictCard
            productCards
            tableCard
            if !result.sources.isEmpty { sourcesCard }
        }
    }

    private var verdictCard: some View {
        GlassCard(glow: true, padding: Brand.Space.l) {
            VStack(alignment: .leading, spacing: Brand.Space.s) {
                HStack(spacing: Brand.Space.s) {
                    Image(systemName: "crown.fill").foregroundStyle(Brand.Color.win)
                    Text("VERDICT").font(Brand.Font.caption).tracking(2).foregroundStyle(.secondary)
                }
                Text(result.verdict.headline).font(Brand.Font.title)
                Text(result.verdict.reasoning).font(Brand.Font.body).foregroundStyle(.primary.opacity(0.9))
                    .fixedSize(horizontal: false, vertical: true)
                if !result.verdict.runnerUp.isEmpty {
                    Divider().padding(.vertical, Brand.Space.xs)
                    Text("Runner-up: ").font(Brand.Font.headline) + Text(result.verdict.runnerUp).font(Brand.Font.body)
                }
                ForEach(result.verdict.caveats, id: \.self) { c in
                    Label(c, systemImage: "exclamationmark.triangle").font(Brand.Font.caption)
                        .foregroundStyle(Brand.Color.warn)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var productCards: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: Brand.Space.m, alignment: .top)],
                  alignment: .leading, spacing: Brand.Space.m) {
            ForEach(result.products) { p in
                GlassCard {
                    VStack(alignment: .leading, spacing: Brand.Space.s) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(p.name).font(Brand.Font.headline)
                                Text(p.price).font(Brand.Font.mono).foregroundStyle(.secondary)
                            }
                            Spacer()
                            ScoreRing(score: p.score, isWinner: p.name == result.verdict.winner)
                        }
                        Text(p.summary).font(Brand.Font.body).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Divider()
                        ForEach(p.pros, id: \.self) { Label($0, systemImage: "plus.circle.fill").font(Brand.Font.body).foregroundStyle(Brand.Color.win) }
                        ForEach(p.cons, id: \.self) { Label($0, systemImage: "minus.circle.fill").font(Brand.Font.body).foregroundStyle(Brand.Color.danger) }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private var tableCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: Brand.Space.s) {
                Text("Side by side").font(Brand.Font.headline)
                Grid(alignment: .leading, horizontalSpacing: Brand.Space.m, verticalSpacing: Brand.Space.s) {
                    GridRow {
                        Text("").gridColumnAlignment(.leading)
                        ForEach(result.products) { p in Text(p.name).font(Brand.Font.headline).lineLimit(2) }
                    }
                    Divider()
                    ForEach(result.table) { row in
                        GridRow {
                            Text(row.criterion).font(Brand.Font.caption).foregroundStyle(.secondary)
                            ForEach(Array(row.values.enumerated()), id: \.offset) { i, v in
                                Text(v).font(Brand.Font.body)
                                    .fontWeight(i == row.bestIndex ? .semibold : .regular)
                                    .foregroundStyle(i == row.bestIndex ? Brand.Color.win : .primary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        Divider().opacity(0.4)
                    }
                }
            }
        }
    }

    private var sourcesCard: some View {
        GlassCard {
            DisclosureGroup("Sources (\(result.sources.count))") {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(result.sources, id: \.self) { s in
                        if let u = URL(string: s) { Link(s, destination: u).font(Brand.Font.mono).lineLimit(1) }
                        else { Text(s).font(Brand.Font.mono) }
                    }
                }.padding(.top, Brand.Space.s)
            }
            .font(Brand.Font.headline)
        }
    }
}

struct ScoreRing: View {
    let score: Int
    let isWinner: Bool
    var body: some View {
        ZStack {
            Circle().stroke(Color.white.opacity(0.12), lineWidth: 5)
            Circle().trim(from: 0, to: CGFloat(score) / 100)
                .stroke(isWinner ? AnyShapeStyle(Brand.Color.win) : AnyShapeStyle(Brand.Color.accentGradient),
                        style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(score)").font(Brand.Font.mono)
        }
        .frame(width: 44, height: 44)
    }
}
