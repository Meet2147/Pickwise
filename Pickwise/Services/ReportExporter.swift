import SwiftUI
import AppKit

/// Renders a comparison as a single-page PDF (print-friendly light layout) and returns the file URL.
@MainActor
enum ReportExporter {
    static func exportPDF(_ comparison: Comparison) throws -> URL {
        guard let result = comparison.result else {
            throw AppError("Nothing to export", details: "Run a comparison first.")
        }
        let report = ReportView(result: result, date: comparison.createdAt)
            .frame(width: 820)
            .environment(\.colorScheme, .light)
        let renderer = ImageRenderer(content: report)
        renderer.proposedSize = ProposedViewSize(width: 820, height: nil)
        renderer.scale = 2

        let safeName = result.title.replacingOccurrences(of: "/", with: "-").prefix(60)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("Pickwise — \(safeName).pdf")
        var rendered = false
        renderer.render { size, draw in
            var box = CGRect(origin: .zero, size: size)
            guard let consumer = CGDataConsumer(url: url as CFURL),
                  let pdf = CGContext(consumer: consumer, mediaBox: &box, nil) else { return }
            pdf.beginPDFPage(nil)
            draw(pdf)
            pdf.endPDFPage()
            pdf.closePDF()
            rendered = true
        }
        guard rendered, FileManager.default.fileExists(atPath: url.path) else {
            throw AppError("Couldn't create the PDF", details: "ImageRenderer produced no output for '\(result.title)'.")
        }
        return url
    }
}

/// Print-friendly report. Light, no glass, no glow — meant for PDF and paper.
struct ReportView: View {
    let result: ComparisonResult
    let date: Date

    private let ink = Color(red: 0.09, green: 0.10, blue: 0.12)
    private let muted = Color(red: 0.42, green: 0.44, blue: 0.50)
    private let accent = Color(red: 0.00, green: 0.55, blue: 0.70)
    private let hairline = Color.black.opacity(0.12)

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .firstTextBaseline) {
                Text("Pickwise").font(.system(size: 15, weight: .semibold)).foregroundStyle(ink)
                Spacer()
                Text(date.formatted(date: .abbreviated, time: .shortened))
                    .font(.system(size: 11, design: .monospaced)).foregroundStyle(muted)
            }
            Divider().overlay(hairline)

            Text(result.title).font(.system(size: 26, weight: .semibold)).foregroundStyle(ink)

            VStack(alignment: .leading, spacing: 8) {
                Text("VERDICT").font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .tracking(1.4).foregroundStyle(accent)
                Text(result.verdict.headline).font(.system(size: 18, weight: .semibold)).foregroundStyle(ink)
                Text(result.verdict.reasoning).font(.system(size: 12)).foregroundStyle(ink.opacity(0.85)).fixedSize(horizontal: false, vertical: true)
                if !result.verdict.runnerUp.isEmpty {
                    Text("Runner-up: \(result.verdict.runnerUp)").font(.system(size: 12)).foregroundStyle(muted)
                }
                ForEach(result.verdict.caveats, id: \.self) {
                    Text("Unless: \($0)").font(.system(size: 12)).foregroundStyle(muted)
                }
            }
            .padding(14)
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(accent.opacity(0.5)))

            HStack(alignment: .top, spacing: 12) {
                ForEach(result.products) { p in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(p.name).font(.system(size: 13, weight: .semibold)).foregroundStyle(ink)
                            Spacer()
                            Text("\(p.score)").font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(p.name == result.verdict.winner ? accent : muted)
                        }
                        Text(p.price).font(.system(size: 11, design: .monospaced)).foregroundStyle(muted)
                        Text(p.summary).font(.system(size: 11)).foregroundStyle(ink.opacity(0.8)).fixedSize(horizontal: false, vertical: true)
                        Divider().overlay(hairline)
                        ForEach(p.pros, id: \.self) { Text("+ \($0)").font(.system(size: 10.5)).fixedSize(horizontal: false, vertical: true).foregroundStyle(Color(red: 0.05, green: 0.45, blue: 0.28)) }
                        ForEach(p.cons, id: \.self) { Text("− \($0)").font(.system(size: 10.5)).fixedSize(horizontal: false, vertical: true).foregroundStyle(Color(red: 0.66, green: 0.16, blue: 0.20)) }
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(hairline))
                }
            }

            Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 6) {
                GridRow {
                    Text("")
                    ForEach(result.products) { Text($0.name).font(.system(size: 10, weight: .semibold)).foregroundStyle(ink) }
                }
                Divider().overlay(hairline)
                ForEach(result.table) { row in
                    GridRow {
                        Text(row.criterion).font(.system(size: 10, design: .monospaced)).foregroundStyle(muted)
                        ForEach(Array(row.values.enumerated()), id: \.offset) { i, v in
                            Text(v).font(.system(size: 10.5, weight: i == row.bestIndex ? .semibold : .regular))
                                .foregroundStyle(i == row.bestIndex ? accent : ink)
                        }
                    }
                }
            }

            if !result.sources.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Sources").font(.system(size: 10, weight: .semibold)).foregroundStyle(muted)
                    ForEach(result.sources, id: \.self) { Text($0).font(.system(size: 9, design: .monospaced)).foregroundStyle(muted).lineLimit(1) }
                }
            }
            Divider().overlay(hairline)
            Text("Made with Pickwise · pickwise.dashovia.app")
                .font(.system(size: 9, design: .monospaced)).foregroundStyle(muted)
        }
        .padding(36)
        .background(Color.white)
    }
}
