import SwiftUI

@MainActor
final class AppStore: ObservableObject {
    @Published var comparisons: [Comparison] = []
    @Published var selectedID: Comparison.ID?
    @Published var isComparing = false
    @Published var error: AppError?
    @Published var update: UpdateInfo?
    @Published var updateDismissed = false
    @Published var showPaywall = false

    let license = LicenseManager.shared

    init() {
        if SampleData.isDemo {
            comparisons = [SampleData.comparison]
        } else {
            do { comparisons = try HistoryStore.load() }
            catch { self.error = AppError("Couldn't load history", error: error) }
        }
        if comparisons.isEmpty { newComparison() } else { selectedID = comparisons.first?.id }
        Task { await checkForUpdate() }
    }

    var selectedIndex: Int? { comparisons.firstIndex { $0.id == selectedID } }

    func newComparison() {
        let c = Comparison()
        comparisons.insert(c, at: 0)
        selectedID = c.id
    }

    func delete(_ ids: Set<Comparison.ID>) {
        comparisons.removeAll { ids.contains($0.id) }
        if selectedID.map(ids.contains) == true { selectedID = comparisons.first?.id }
        if comparisons.isEmpty { newComparison() }
        persist()
    }

    func persist() {
        if SampleData.isDemo { return }
        do { try HistoryStore.save(comparisons) }
        catch { self.error = AppError("Couldn't save history", error: error) }
    }

    func runComparison() async {
        guard let i = selectedIndex else { return }
        guard license.isUnlocked else { showPaywall = true; return }
        isComparing = true
        defer { isComparing = false }
        let id = comparisons[i].id
        do {
            let result = try await ClaudeService().compare(comparisons[i].candidates)
            if let j = comparisons.firstIndex(where: { $0.id == id }) {
                comparisons[j].result = result
                comparisons[j].createdAt = Date()
                persist()
            }
        } catch let e as AppError {
            error = e
        } catch {
            self.error = AppError("Comparison failed", error: error)
        }
    }

    func captureIntoCandidate(_ candidateID: Candidate.ID) async {
        guard let i = selectedIndex else { return }
        do {
            let png = try await ScreenCapture.captureRegion()
            if let k = comparisons[i].candidates.firstIndex(where: { $0.id == candidateID }) {
                comparisons[i].candidates[k].imagePNG = png
            }
        } catch let e as AppError {
            if e.title != "Capture cancelled" { error = e }
        } catch {
            self.error = AppError("Screen capture failed", error: error)
        }
    }

    func checkForUpdate() async {
        do { update = try await UpdateChecker.check() }
        catch { /* Silent: an unreachable update feed shouldn't nag on every launch. Logged only. */
            NSLog("Update check failed: \(error)") }
    }
}
