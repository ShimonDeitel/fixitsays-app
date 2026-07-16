import SwiftUI

struct PaywallView: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    @State private var working = false
    @State private var restoreMessage: String?

    private let benefits: [(String, String, String)] = [
        ("infinity", "Unlimited diagnoses", "No daily cap - diagnose anything, whenever it breaks."),
        ("clock.arrow.circlepath", "Full history", "Every past diagnosis saved per appliance, forever."),
        ("list.number", "Detailed repair steps", "Complete step-by-step guidance on every DIY verdict."),
        ("house.fill", "Whole-home coverage", "Fridge to furnace - one subscription covers it all.")
    ]

    var body: some View {
        ZStack {
            FixitSaysBackground()
            ScrollView {
                VStack(spacing: 22) {
                    VStack(spacing: 8) {
                        Image(systemName: "wrench.and.screwdriver.fill")
                            .font(.system(size: 40, weight: .semibold))
                            .foregroundStyle(Color.fixitsaysAccent)
                        Text("FixitSays Pro").font(.largeTitle.weight(.heavy))
                        Text("$0.99 per month. Auto-renews monthly. Cancel anytime.")
                            .font(.subheadline).foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 28)

                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(benefits, id: \.0) { item in
                            HStack(alignment: .top, spacing: 14) {
                                Image(systemName: item.0)
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(Color.fixitsaysAccent)
                                    .frame(width: 28)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.1).font(.headline)
                                    Text(item.2).font(.subheadline).foregroundStyle(.secondary)
                                }
                                Spacer(minLength: 0)
                            }
                        }
                    }
                    .fixitsaysCard()
                    .padding(.horizontal)

                    VStack(spacing: 12) {
                        Button { Task { await buy() } } label: {
                            HStack {
                                if working { ProgressView().tint(.white) }
                                Text(working ? "Subscribing..." : "Subscribe - \(store.displayPrice)/month")
                                    .font(.headline)
                            }
                            .frame(maxWidth: .infinity).padding(.vertical, 6)
                        }
                        .prominentButton()
                        .accessibilityIdentifier("paywall-unlock")
                        .disabled(working)

                        Button("Restore Purchases") { Task { await restore() } }
                            .font(.subheadline).tint(.secondary)

                        if let restoreMessage {
                            Text(restoreMessage).font(.footnote).foregroundStyle(.secondary)
                        }

                        // Guideline 3.1.2 disclosure
                        VStack(spacing: 6) {
                            Text("FixitSays Pro is an auto-renewable subscription billed at \(store.displayPrice) per month. Payment is charged to your Apple Account at confirmation. The subscription renews automatically unless cancelled at least 24 hours before the end of the period. Manage or cancel anytime in Settings > Apple Account > Subscriptions.")
                                .font(.caption2).foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                            HStack(spacing: 16) {
                                Link("Privacy Policy",
                                     destination: URL(string: "https://shimondeitel.github.io/fixitsays-site/privacy.html")!)
                                Link("Terms of Use",
                                     destination: URL(string: "https://shimondeitel.github.io/fixitsays-site/terms.html")!)
                            }
                            .font(.caption2)
                        }
                        .padding(.top, 4)
                    }
                    .padding(.horizontal).padding(.bottom, 30)
                }
            }
        }
        .overlay(alignment: .topTrailing) {
            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill").font(.title2)
                    .foregroundStyle(.secondary).padding()
            }
            .accessibilityIdentifier("paywall-close")
            .accessibilityLabel("Close")
        }
        .onChange(of: store.isPro) { _, newValue in if newValue { dismiss() } }
    }

    private func buy() async {
        working = true
        let ok = await store.purchase()
        working = false
        if ok { Haptics.success(); dismiss() }
    }

    private func restore() async {
        await store.restore()
        if store.isPro { Haptics.success(); dismiss() }
        else { restoreMessage = "No active subscription found on this Apple ID." }
    }
}
