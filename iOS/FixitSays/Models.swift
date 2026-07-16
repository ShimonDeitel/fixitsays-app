import Foundation
import SwiftData

/// A saved diagnosis. Defaulted props, CloudKit-mirroring compatible.
@Model
final class SavedDiagnosis {
    var id: UUID = UUID()
    var category: String = "Other"
    var symptomText: String = ""
    /// JSON-encoded [WireCause]; keeps the schema simple/CloudKit-safe.
    var causesJSON: String = ""
    var verdict: String = "call_a_pro"
    /// JSON-encoded [String] steps.
    var stepsJSON: String = ""
    var createdAt: Date = Date.now

    init(id: UUID = UUID(), category: String = "Other", symptomText: String = "",
         causesJSON: String = "", verdict: String = "call_a_pro",
         stepsJSON: String = "", createdAt: Date = .now) {
        self.id = id
        self.category = category
        self.symptomText = symptomText
        self.causesJSON = causesJSON
        self.verdict = verdict
        self.stepsJSON = stepsJSON
        self.createdAt = createdAt
    }

    var causes: [WireCause] {
        (try? JSONDecoder().decode([WireCause].self, from: Data(causesJSON.utf8))) ?? []
    }

    var steps: [String] {
        (try? JSONDecoder().decode([String].self, from: Data(stepsJSON.utf8))) ?? []
    }

    var verdictEnum: Verdict { Verdict(rawValue: verdict) ?? .callAPro }
}

/// Appliance/system categories.
enum ApplianceCategory: String, CaseIterable, Identifiable {
    case fridge = "Fridge"
    case washer = "Washer"
    case dryer = "Dryer"
    case dishwasher = "Dishwasher"
    case hvac = "AC / Heating"
    case plumbing = "Plumbing"
    case electrical = "Electrical"
    case other = "Other"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .fridge: return "thermometer.snowflake"
        case .washer: return "water.waves"
        case .dryer: return "wind"
        case .dishwasher: return "dishwasher.fill"
        case .hvac: return "fan.fill"
        case .plumbing: return "drop.fill"
        case .electrical: return "bolt.fill"
        case .other: return "wrench.and.screwdriver.fill"
        }
    }
}

/// DIY-or-pro verdict.
enum Verdict: String {
    case diySafe = "diy_safe"
    case diyWithCaution = "diy_with_caution"
    case callAPro = "call_a_pro"

    var label: String {
        switch self {
        case .diySafe: return "Safe to try yourself"
        case .diyWithCaution: return "DIY with caution"
        case .callAPro: return "Call a professional"
        }
    }

    var symbol: String {
        switch self {
        case .diySafe: return "checkmark.circle.fill"
        case .diyWithCaution: return "exclamationmark.triangle.fill"
        case .callAPro: return "person.fill.checkmark"
        }
    }
}
