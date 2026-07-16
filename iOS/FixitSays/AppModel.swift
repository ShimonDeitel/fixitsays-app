import Foundation
import SwiftData
import SwiftUI

enum DiagnosisState: Equatable {
    case idle
    case diagnosing
    case result(WireDiagnosis)
    case error(String)
}

/// App state: owns the SwiftData store, the diagnosis flow, and history.
@MainActor
final class AppModel: ObservableObject {
    let container: ModelContainer
    weak var store: Store?

    @Published var state: DiagnosisState = .idle
    @Published private(set) var history: [SavedDiagnosis] = []

    /// Free tier keeps only the most recent diagnosis in history.
    static let freeHistoryLimit = 1

    init(container: ModelContainer) {
        self.container = container
        refresh()
    }

    static func makeContainer() -> ModelContainer {
        let schema = Schema([SavedDiagnosis.self])
        if FileManager.default.ubiquityIdentityToken != nil {
            let cloud = ModelConfiguration(schema: schema, cloudKitDatabase: .automatic)
            if let c = try? ModelContainer(for: schema, configurations: cloud) { return c }
        }
        let local = ModelConfiguration(schema: schema, cloudKitDatabase: .none)
        if let c = try? ModelContainer(for: schema, configurations: local) { return c }
        let mem = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try! ModelContainer(for: schema, configurations: mem)
    }

    // MARK: Diagnosis

    var canDiagnose: Bool { AIRateLimiter.canCall(isPro: store?.isPro == true) }
    var remainingToday: Int { AIRateLimiter.remaining() }

    func diagnose(category: ApplianceCategory, symptom: String) async {
        let text = symptom.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        guard canDiagnose else {
            state = .error(AIError.rateLimited.localizedDescription)
            return
        }
        state = .diagnosing
        do {
            let wire = try await AIClient.shared.diagnose(category: category, symptom: text)
            AIRateLimiter.recordCall()
            record(category: category, symptom: text, wire: wire)
            state = .result(wire)
            Haptics.success()
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    func reset() { state = .idle }

    // MARK: History

    func refresh() {
        let d = FetchDescriptor<SavedDiagnosis>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        history = (try? container.mainContext.fetch(d)) ?? []
    }

    /// History visible under the current entitlement.
    func visibleHistory(isPro: Bool) -> [SavedDiagnosis] {
        isPro ? history : Array(history.prefix(Self.freeHistoryLimit))
    }

    private func record(category: ApplianceCategory, symptom: String, wire: WireDiagnosis) {
        let enc = JSONEncoder()
        let causes = (try? enc.encode(wire.causes)).flatMap { String(data: $0, encoding: .utf8) } ?? ""
        let steps = (try? enc.encode(wire.steps)).flatMap { String(data: $0, encoding: .utf8) } ?? ""
        container.mainContext.insert(SavedDiagnosis(category: category.rawValue, symptomText: symptom,
                                                    causesJSON: causes, verdict: wire.verdict,
                                                    stepsJSON: steps))
        try? container.mainContext.save()
        refresh()
    }

    func delete(_ d: SavedDiagnosis) {
        container.mainContext.delete(d)
        try? container.mainContext.save()
        refresh()
    }

    /// A shareable plain-text version of a diagnosis.
    static func shareText(category: String, causes: [WireCause], verdict: Verdict, steps: [String]) -> String {
        var out = "FixitSays - \(category)\n\nLikely causes:\n"
        for c in causes { out += "- \(c.label) (\(c.likelihoodLabel)): \(c.explanation)\n" }
        out += "\nVerdict: \(verdict.label)\n"
        if !steps.isEmpty {
            out += "\nSteps:\n"
            for (i, s) in steps.enumerated() { out += "\(i + 1). \(s)\n" }
        }
        return out
    }

    /// Erase all on-device data (used by Delete Account).
    func deleteAllData() {
        try? container.mainContext.delete(model: SavedDiagnosis.self)
        try? container.mainContext.save()
        refresh()
    }
}
