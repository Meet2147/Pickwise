import SwiftUI

/// Neumorphic result presentation for iOS.
struct MobileResultView: View {
    let result: ComparisonResult

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            verdict
            ForEach(result.products) { product(p: $0) }
            table
            if !result.sources.isEmpty { sources }
        }
    }

    private var verdict: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Circle().fill(Neu.accent).frame(width: 8, height: 8)
                Text("VERDICT").font(Neu.Font.mono).tracking(1.4).foregroundStyle(Neu.accent)
            }
            Text(result.verdict.headline).font(Neu.Font.title).foregroundStyle(Neu.ink)
            Text(result.verdict.reasoning).font(Neu.Font.body).foregroundStyle(Neu.ink2)
                .fixedSize(horizontal: false, vertical: true)
            if !result.verdict.runnerUp.isEmpty {
                labeled("Runner-up", result.verdict.runnerUp)
            }
            ForEach(result.verdict.caveats, id: \.self) { labeled("Unless", $0) }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .neuRaised(depth: 9)
    }

    private func labeled(_ label: String, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(label).font(Neu.Font.mono).foregroundStyle(Neu.ink2.opacity(0.8))
            Text(text).font(Neu.Font.body).foregroundStyle(Neu.ink2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func product(p: ProductAssessment) -> some View {
        let winner = p.name == result.verdict.winner
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 14) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(p.name).font(Neu.Font.headline).foregroundStyle(Neu.ink)
                    Text(p.price).font(Neu.Font.mono).foregroundStyle(Neu.ink2)
                }
                Spacer()
                Text("\(p.score)")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(winner ? Neu.accent : Neu.ink2)
                    .frame(width: 54, height: 54)
                    .neuInset(radius: 27)
            }
            Text(p.summary).font(Neu.Font.body).foregroundStyle(Neu.ink2)
                .fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: 5) {
                ForEach(p.pros, id: \.self) { bullet($0, "+", Neu.win) }
                ForEach(p.cons, id: \.self) { bullet($0, "−", Neu.danger) }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .neuRaised()
    }

    private func bullet(_ text: String, _ glyph: String, _ color: Color) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(glyph).font(Neu.Font.mono).foregroundStyle(color)
            Text(text).font(Neu.Font.body).foregroundStyle(Neu.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var table: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Side by side").font(Neu.Font.headline).foregroundStyle(Neu.ink)
            ScrollView(.horizontal, showsIndicators: false) {
                Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 9) {
                    GridRow {
                        Text("")
                        ForEach(result.products) {
                            Text($0.name).font(Neu.Font.caption).bold().foregroundStyle(Neu.ink)
                                .frame(maxWidth: 120, alignment: .leading).lineLimit(2)
                        }
                    }
                    ForEach(result.table) { row in
                        GridRow {
                            Text(row.criterion).font(Neu.Font.mono).foregroundStyle(Neu.ink2)
                            ForEach(Array(row.values.enumerated()), id: \.offset) { i, v in
                                Text(v).font(Neu.Font.caption)
                                    .foregroundStyle(i == row.bestIndex ? Neu.accent : Neu.ink)
                                    .frame(maxWidth: 120, alignment: .leading)
                            }
                        }
                    }
                }
                .padding(16)
            }
            .neuInset(radius: Neu.radiusSmall)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .neuRaised()
    }

    private var sources: some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(result.sources, id: \.self) { s in
                    if let u = URL(string: s) {
                        Link(s, destination: u).font(Neu.Font.mono).foregroundStyle(Neu.accent).lineLimit(1)
                    } else { Text(s).font(Neu.Font.mono).foregroundStyle(Neu.ink2) }
                }
            }.padding(.top, 8)
        } label: {
            Text("Sources · \(result.sources.count)").font(Neu.Font.headline).foregroundStyle(Neu.ink)
        }
        .padding(18)
        .neuRaised()
    }
}
