import SwiftUI

@main
struct PickwiseMobileApp: App {
    @StateObject private var store = MobileStore()

    var body: some Scene {
        WindowGroup {
            MobileRootView().environmentObject(store)
        }
    }
}

@MainActor
final class MobileStore: ObservableObject {
    @Published var comparisons: [Comparison] = []
    @Published var isComparing = false
    @Published var error: AppError?
    @Published var quota: PickwiseAPI.Quota?
    @Published var showPaywall = false

    init() {
        if SampleData.isDemo {
            comparisons = [SampleData.comparison]
            quota = .init(plan: "free", used: 1, limit: 5)
            return
        }
        do { comparisons = try HistoryStore.load() }
        catch { self.error = AppError("Couldn't load history", error: error) }
    }

    func persist() {
        if SampleData.isDemo { return }
        do { try HistoryStore.save(comparisons) }
        catch { self.error = AppError("Couldn't save history", error: error) }
    }

    func run(_ comparison: Comparison) async {
        isComparing = true
        defer { isComparing = false }
        do {
            let r = try await PickwiseAPI().compare(comparison.candidates)
            quota = r.quota
            if let i = comparisons.firstIndex(where: { $0.id == comparison.id }) {
                comparisons[i].result = r.result
                comparisons[i].createdAt = Date()
            } else {
                var c = comparison; c.result = r.result; comparisons.insert(c, at: 0)
            }
            persist()
        } catch let q as PickwiseAPI.QuotaExhausted {
            quota = .init(plan: "free", used: q.used, limit: q.limit)
            showPaywall = true
        } catch let e as AppError {
            error = e
        } catch {
            self.error = AppError("Comparison failed", error: error)
        }
    }
}
