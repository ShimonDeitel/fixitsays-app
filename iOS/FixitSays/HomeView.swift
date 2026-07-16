import SwiftUI

struct HomeView: View {
    var forceScreen: String?

    @EnvironmentObject var appModel: AppModel
    @EnvironmentObject var store: Store

    @State private var category: ApplianceCategory = .fridge
    @State private var symptom = ""
    @State private var showSettings = false
    @State private var showPaywall = false
    @State private var showHistory = false
    @State private var showResult = false

    private let columns = [GridItem(.adaptive(minimum: 82), spacing: 10)]

    var body: some View {
        NavigationStack {
            ZStack {
                FixitSaysBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        categoryGrid
                        symptomBox
                        diagnoseButton
                        if !store.isPro {
                            Text("\(appModel.remainingToday) free \(appModel.remainingToday == 1 ? "diagnosis" : "diagnoses") left today")
                                .font(.footnote).foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity)
                        }
                        if case .error(let msg) = appModel.state {
                            Text(msg).font(.footnote).foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity).multilineTextAlignment(.center)
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Fixit Says")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { Haptics.tap(); showHistory = true } label: {
                        Image(systemName: "clock.arrow.circlepath")
                    }
                    .accessibilityIdentifier("open-history")
                    .accessibilityLabel("History")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { Haptics.tap(); showSettings = true } label: {
                        Image(systemName: "gearshape.fill")
                    }
                    .accessibilityIdentifier("open-settings")
                    .accessibilityLabel("Settings")
                }
            }
        }
        .sheet(isPresented: $showSettings) { SettingsView() }
        .sheet(isPresented: $showPaywall) { PaywallView() }
        .sheet(isPresented: $showHistory) { HistoryView() }
        .sheet(isPresented: $showResult) {
            DiagnosisResultView(category: category)
                .onDisappear { if case .result = appModel.state { appModel.reset() } }
        }
        .onChange(of: appModel.state) { _, s in
            if case .result = s { showResult = true }
        }
        .onAppear { applyForceScreen() }
    }

    private var categoryGrid: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("What's acting up?").font(.headline)
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(ApplianceCategory.allCases) { c in
                    let on = category == c
                    Button {
                        Haptics.tap(); category = c
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: c.symbol)
                                .font(.title3)
                            Text(c.rawValue)
                                .font(.caption2.weight(.semibold))
                                .lineLimit(1).minimumScaleFactor(0.7)
                        }
                        .frame(maxWidth: .infinity, minHeight: 64)
                        .background(on ? Color.fixitsaysAccent : Color.fixitsaysCard,
                                    in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .foregroundStyle(on ? .white : .primary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("cat-\(c.rawValue)")
                }
            }
        }
    }

    private var symptomBox: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Describe the symptom").font(.headline)
            TextEditor(text: $symptom)
                .frame(minHeight: 110)
                .padding(10)
                .scrollContentBackground(.hidden)
                .background(Color.fixitsaysField, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(alignment: .topLeading) {
                    if symptom.isEmpty {
                        Text("e.g. fridge is warm but clicking every few minutes...")
                            .foregroundStyle(.secondary)
                            .padding(.top, 18).padding(.leading, 15)
                            .allowsHitTesting(false)
                    }
                }
                .accessibilityIdentifier("symptom-input")
        }
    }

    private var diagnoseButton: some View {
        Button {
            Haptics.soft()
            if appModel.canDiagnose {
                Task { await appModel.diagnose(category: category, symptom: symptom) }
            } else {
                showPaywall = true
            }
        } label: {
            HStack {
                if appModel.state == .diagnosing { ProgressView().tint(.white) }
                Text(appModel.state == .diagnosing ? "Diagnosing..." : "Diagnose")
            }
            .frame(maxWidth: .infinity).padding(.vertical, 4)
        }
        .prominentButton()
        .disabled(symptom.trimmingCharacters(in: .whitespaces).isEmpty || appModel.state == .diagnosing)
        .accessibilityIdentifier("diagnose")
    }

    private func applyForceScreen() {
        guard let s = forceScreen else { return }
        switch s {
        case "settings": showSettings = true
        case "paywall": showPaywall = true
        case "history": showHistory = true
        default: break
        }
    }
}
