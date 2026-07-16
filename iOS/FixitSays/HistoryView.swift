import SwiftUI

/// Past diagnoses; free tier sees only the most recent one.
struct HistoryView: View {
    @EnvironmentObject var appModel: AppModel
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss

    @State private var showPaywall = false

    private var visible: [SavedDiagnosis] { appModel.visibleHistory(isPro: store.isPro) }
    private var hiddenCount: Int { appModel.history.count - visible.count }

    var body: some View {
        NavigationStack {
            ZStack {
                FixitSaysBackground()
                if appModel.history.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 44, weight: .light)).foregroundStyle(.secondary)
                        Text("No diagnoses yet").font(.headline)
                        Text("Every diagnosis is saved here automatically.")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                } else {
                    list
                }
            }
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } }
            }
        }
        .sheet(isPresented: $showPaywall) { PaywallView() }
        .onAppear { appModel.refresh() }
    }

    private var list: some View {
        List {
            ForEach(visible) { d in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Label(d.category, systemImage: ApplianceCategory(rawValue: d.category)?.symbol ?? "wrench.and.screwdriver.fill")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Text(d.createdAt, style: .date).font(.caption2).foregroundStyle(.secondary)
                    }
                    Text(d.symptomText).font(.subheadline).foregroundStyle(.secondary).lineLimit(2)
                    HStack(spacing: 6) {
                        Image(systemName: d.verdictEnum.symbol).font(.caption)
                        Text(d.verdictEnum.label).font(.caption.weight(.semibold))
                    }
                    .foregroundStyle(d.verdictEnum == .diySafe ? Color.fixitsaysAccent : Color.secondary)
                }
                .padding(.vertical, 2)
                .swipeActions {
                    Button(role: .destructive) { appModel.delete(d) } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
            if hiddenCount > 0 {
                Button {
                    showPaywall = true
                } label: {
                    Label("\(hiddenCount) older \(hiddenCount == 1 ? "diagnosis" : "diagnoses") - unlock with Pro",
                          systemImage: "lock.fill")
                        .font(.subheadline)
                }
            }
        }
        .scrollContentBackground(.hidden)
    }
}
