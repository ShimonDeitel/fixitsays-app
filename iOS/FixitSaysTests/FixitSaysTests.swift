import XCTest
@testable import FixitSays

final class FixitSaysTests: XCTestCase {

    func testDecodeDiagnosisTolerantly() throws {
        let content = """
        {"causes":[{"label":"Faulty start relay","likelihood":"HIGH","explanation":"Clicking usually means the compressor relay is failing."},{"label":"Dirty condenser coils"}],"verdict":"DIY_WITH_CAUTION","steps":["Unplug the fridge","Vacuum the coils"]}
        """
        let d: WireDiagnosis = try AIClient.decodeContent(content)
        XCTAssertEqual(d.causes.count, 2)
        XCTAssertEqual(d.causes[0].likelihood, "high")
        XCTAssertEqual(d.causes[1].likelihood, "medium")   // default
        XCTAssertEqual(d.verdictEnum, .diyWithCaution)
        XCTAssertEqual(d.steps.count, 2)
        XCTAssertTrue(d.isUsable)
    }

    func testUnknownVerdictFallsBackToPro() throws {
        let content = "{\"causes\":[{\"label\":\"x\"}],\"verdict\":\"whatever\",\"steps\":[]}"
        let d: WireDiagnosis = try AIClient.decodeContent(content)
        XCTAssertEqual(d.verdictEnum, .callAPro)
    }

    func testJSONCandidatesHandlesFences() {
        let clean = "{\"causes\":[],\"verdict\":\"diy_safe\",\"steps\":[]}"
        XCTAssertTrue(AIClient.jsonCandidates(from: "```json\n\(clean)\n```").contains { $0 == clean })
    }

    func testRateLimiterCapsFreeOnly() {
        let d = UserDefaults(suiteName: "test.fixitsays.\(UUID().uuidString)")!
        for _ in 0..<AIConfig.freeDailyLimit { AIRateLimiter.recordCall(d) }
        XCTAssertFalse(AIRateLimiter.canCall(isPro: false, d))
        XCTAssertTrue(AIRateLimiter.canCall(isPro: true, d))
    }

    func testCategoryAndVerdictRosters() {
        XCTAssertEqual(ApplianceCategory.allCases.count, 8)
        for c in ApplianceCategory.allCases { XCTAssertFalse(c.symbol.isEmpty) }
        XCTAssertEqual(Verdict(rawValue: "diy_safe"), .diySafe)
        XCTAssertEqual(Verdict.callAPro.label, "Call a professional")
    }

    @MainActor
    func testHistoryFreeLimitAndShareText() {
        let model = AppModel(container: AppModel.makeContainer())
        model.deleteAllData()
        XCTAssertTrue(model.visibleHistory(isPro: false).isEmpty)
        let share = AppModel.shareText(category: "Fridge",
                                       causes: [WireCause(label: "Relay", likelihood: "high", explanation: "clicking")],
                                       verdict: .callAPro, steps: ["Note the model number"])
        XCTAssertTrue(share.contains("Fridge"))
        XCTAssertTrue(share.contains("Relay"))
        XCTAssertTrue(share.contains("Call a professional"))
        XCTAssertTrue(share.contains("1. Note the model number"))
        model.deleteAllData()
    }

    @MainActor
    func testSavedDiagnosisJSONRoundTrip() {
        let enc = JSONEncoder()
        let causes = [WireCause(label: "A", likelihood: "high", explanation: "e")]
        let cj = String(data: try! enc.encode(causes), encoding: .utf8)!
        let sj = String(data: try! enc.encode(["step one"]), encoding: .utf8)!
        let saved = SavedDiagnosis(category: "Washer", symptomText: "leaks", causesJSON: cj,
                                   verdict: "diy_safe", stepsJSON: sj)
        XCTAssertEqual(saved.causes.first?.label, "A")
        XCTAssertEqual(saved.steps, ["step one"])
        XCTAssertEqual(saved.verdictEnum, .diySafe)
    }
}
