import Foundation

/// Sample result used when launched with WHOSBETTER_DEMO=1 (screenshots, previews). Never shown otherwise.
enum SampleData {
    static var isDemo: Bool { ProcessInfo.processInfo.environment["WHOSBETTER_DEMO"] == "1" }

    static let comparison: Comparison = {
        var c = Comparison()
        c.candidates = [Candidate(text: "Sony WH-1000XM5"), Candidate(text: "Bose QuietComfort Ultra"), Candidate(text: "AirPods Max (USB-C)")]
        c.result = ComparisonResult(
            title: "Sony XM5 vs Bose QC Ultra vs AirPods Max",
            products: [
                .init(name: "Sony WH-1000XM5", summary: "Best all-rounder: class-leading ANC, 30h battery, great app.", price: "$328",
                      pros: ["Best-in-class noise cancelling", "30-hour battery", "Multipoint + LDAC", "Lightest of the three"],
                      cons: ["Doesn't fold flat", "Plastic build feels cheaper", "Mediocre call quality in wind"], score: 88),
                .init(name: "Bose QuietComfort Ultra", summary: "Most comfortable, warmest sound, Immersive Audio mode.", price: "$379",
                      pros: ["Supreme comfort", "Folds for travel", "Excellent ANC, best for voices"],
                      cons: ["24h battery", "Immersive mode drains battery", "Pricier than Sony"], score: 82),
                .init(name: "AirPods Max (USB-C)", summary: "Premium build, seamless with Apple, heavy and expensive.", price: "$549",
                      pros: ["Aluminium build", "Best spatial audio", "Effortless Apple handoff"],
                      cons: ["385 g — heavy", "No power switch, odd case", "$549 with 2020-era chip"], score: 71),
            ],
            table: [
                .init(criterion: "Price", values: ["$328", "$379", "$549"], bestIndex: 0),
                .init(criterion: "Battery (ANC on)", values: ["30 h", "24 h", "20 h"], bestIndex: 0),
                .init(criterion: "Weight", values: ["250 g", "254 g", "385 g"], bestIndex: 0),
                .init(criterion: "Noise cancelling", values: ["Excellent", "Excellent", "Very good"], bestIndex: -1),
                .init(criterion: "Comfort", values: ["Very good", "Best", "Good"], bestIndex: 1),
                .init(criterion: "Codecs", values: ["SBC, AAC, LDAC", "SBC, AAC, aptX Adaptive", "AAC"], bestIndex: 0),
                .init(criterion: "Folds", values: ["No", "Yes", "No"], bestIndex: 1),
            ],
            verdict: .init(winner: "Sony WH-1000XM5",
                           headline: "Go with the Sony WH-1000XM5.",
                           reasoning: "It matches Bose on noise cancelling, beats both on battery and weight, and costs $50–$220 less. Unless you're deep in the Apple ecosystem or prioritise comfort on 10-hour flights, the XM5 is the rational buy.",
                           runnerUp: "Bose QuietComfort Ultra — pick it if comfort and a folding design matter more than battery.",
                           caveats: ["AirPods Max only makes sense if you want spatial audio across Apple devices and don't mind the weight."]),
            sources: ["https://www.sony.com/electronics/headband-headphones/wh-1000xm5",
                      "https://www.bose.com/p/headphones/bose-quietcomfort-ultra-headphones",
                      "https://www.apple.com/airpods-max/",
                      "https://www.rtings.com/headphones/tools/compare"])
        return c
    }()
}
