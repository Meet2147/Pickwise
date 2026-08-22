import SwiftUI

struct ResultView: View {
    let result: ComparisonResult

    var body: some View {
        VStack(alignment: .leading, spacing: Brand.Space.l) {
            verdict
            products
            table
            if !result.sources.isEmpty { sources }
        }
    }

    // The one place color is spent.
    private var verdict: some View {
        Surface(emphasis: true, padding: Brand.Space.l) {
            VStack(alignment: .leading, spacing: Brand.Space.s) {
                Text("Verdict").font(Brand.Font.monoSmall).textCase(.uppercase).tracking(1.2).foregroundStyle(Brand.Color.accent)
                Text(result.verdict.headline).font(Brand.Font.title).tracking(-0.3)
                Text(result.verdict.reasoning).font(Brand.Font.body).foregroundStyle(Brand.Color.ink2)
                    .fixedSize(horizontal: false, vertical: true)
                if !result.verdict.runnerUp.isEmpty || !result.verdict.caveats.isEmpty {
                    Divider().overlay(Brand.Color.hairline).padding(.vertical, Brand.Space.xs)
                }
                if !result.verdict.runnerUp.isEmpty {
                    row(label: "Runner-up", text: result.verdict.runnerUp)
                }
                ForEach(result.verdict.caveats, id: \.self) { row(label: "Unless", text: $0) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func row(label: String, text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Brand.Space.m) {
            Text(label).font(Brand.Font.monoSmall).foregroundStyle(Brand.Color.ink3).frame(width: 64, alignment: .leading)
            Text(text).font(Brand.Font.body).foregroundStyle(Brand.Color.ink2).fixedSize(horizontal: false, vertical: true)
        }
    }

    private var products: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 250), spacing: Brand.Space.m, alignment: .top)],
                  alignment: .leading, spacing: Brand.Space.m) {
            ForEach(result.products) { p in
                let winner = p.name == result.verdict.winner
                Surface {
                    VStack(alignment: .leading, spacing: Brand.Space.s) {
                        HStack(alignment: .firstTextBaseline) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(p.name).font(Brand.Font.headline)
                                Text(p.price).font(Brand.Font.mono).foregroundStyle(Brand.Color.ink2)
                            }
                            Spacer()
                            Text("\(p.score)")
                                .font(.system(size: 26, weight: .semibold, design: .default)).tracking(-0.5)
                                .foregroundStyle(winner ? Brand.Color.accent : Brand.Color.ink2)
                        }
                        Text(p.summary).font(Brand.Font.body).foregroundStyle(Brand.Color.ink2)
                            .fixedSize(horizontal: false, vertical: true)
                        Divider().overlay(Brand.Color.hairline)
                        ForEach(p.pros, id: \.self) { bullet($0, color: Brand.Color.win, glyph: "+") }
                        ForEach(p.cons, id: \.self) { bullet($0, color: Brand.Color.danger, glyph: "−") }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private func bullet(_ text: String, color: Color, glyph: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(glyph).font(Brand.Font.mono).foregroundStyle(color).frame(width: 10)
            Text(text).font(Brand.Font.body).fixedSize(horizontal: false, vertical: true)
        }
    }

    private var table: some View {
        Surface {
            VStack(alignment: .leading, spacing: Brand.Space.s) {
                Text("Side by side").font(Brand.Font.headline)
                Grid(alignment: .leading, horizontalSpacing: Brand.Space.m, verticalSpacing: 10) {
                    GridRow {
                        Text("")
                        ForEach(result.products) { p in
                            Text(p.name).font(Brand.Font.caption).foregroundStyle(Brand.Color.ink2).lineLimit(2)
                        }
                    }
                    Divider().overlay(Brand.Color.hairline)
                    ForEach(result.table) { row in
                        GridRow {
                            Text(row.criterion).font(Brand.Font.monoSmall).foregroundStyle(Brand.Color.ink3)
                            ForEach(Array(row.values.enumerated()), id: \.offset) { i, v in
                                Text(v).font(Brand.Font.body)
                                    .foregroundStyle(i == row.bestIndex ? Brand.Color.accent : .primary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }
            }
        }
    }

    private var sources: some View {
        Surface {
            DisclosureGroup {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(result.sources, id: \.self) { s in
                        if let u = URL(string: s) { Link(s, destination: u).font(Brand.Font.mono).lineLimit(1).foregroundStyle(Brand.Color.ink2) }
                        else { Text(s).font(Brand.Font.mono) }
                    }
                }.padding(.top, Brand.Space.s)
            } label: {
                Text("Sources · \(result.sources.count)").font(Brand.Font.headline)
            }
        }
    }
}
