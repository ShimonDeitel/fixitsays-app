import SwiftUI

/// Ranked causes + the DIY-or-pro verdict + steps.
struct DiagnosisResultView: View {
    let category: ApplianceCategory

    @EnvironmentObject var appModel: AppModel
    @Environment(\.dismiss) private var dismiss

    private var diagnosis: WireDiagnosis? {
        if case .result(let d) = appModel.state { return d }
        return nil
    }

    var body: some View {
        NavigationStack {
            ZStack {
                FixitSaysBackground()
                if let d = diagnosis {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 18) {
                            verdictBanner(d.verdictEnum)
                            causesSection(d.causes)
                            if !d.steps.isEmpty { stepsSection(d.steps, verdict: d.verdictEnum) }
                            ShareLink(item: AppModel.shareText(category: category.rawValue,
                                                               causes: d.causes,
                                                               verdict: d.verdictEnum,
                                                               steps: d.steps)) {
                                Label("Share this diagnosis", systemImage: "square.and.arrow.up")
                                    .frame(maxWidth: .infinity)
                            }
                            .softButton()
                        }
                        .padding(20)
                    }
                }
            }
            .navigationTitle(category.rawValue)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } }
            }
        }
    }

    private func verdictBanner(_ v: Verdict) -> some View {
        HStack(spacing: 12) {
            Image(systemName: v.symbol)
                .font(.title2)
                .foregroundStyle(v == .diySafe ? Color.fixitsaysAccent : Color.primary)
            VStack(alignment: .leading, spacing: 2) {
                Text(v.label).font(.headline)
                Text(v == .callAPro
                     ? "This one isn't worth the risk - bring in a technician."
                     : "You can likely handle this - follow the steps below.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .fixitsaysCard()
        .accessibilityIdentifier("verdict")
    }

    private func causesSection(_ causes: [WireCause]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Likely causes").font(.headline)
            ForEach(causes) { c in
                HStack(alignment: .top, spacing: 12) {
                    Text(c.likelihoodLabel)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(c.likelihood == "high" ? Color.fixitsaysAccent : Color.secondary)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Color.fixitsaysField, in: Capsule())
                        .frame(width: 86)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(c.label).font(.subheadline.weight(.semibold))
                        Text(c.explanation).font(.subheadline).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }
            }
        }
        .fixitsaysCard()
    }

    private func stepsSection(_ steps: [String], verdict: Verdict) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(verdict == .callAPro ? "Before the technician arrives" : "Try this").font(.headline)
            ForEach(Array(steps.enumerated()), id: \.offset) { i, step in
                HStack(alignment: .top, spacing: 12) {
                    Text("\(i + 1)")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 26, height: 26)
                        .background(Color.fixitsaysAccent, in: Circle())
                    Text(step).font(.subheadline)
                    Spacer(minLength: 0)
                }
            }
        }
        .fixitsaysCard()
    }
}
