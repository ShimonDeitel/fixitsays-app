import SwiftUI

struct RootView: View {
    @EnvironmentObject var account: AccountManager
    @EnvironmentObject var store: Store
    @EnvironmentObject var appModel: AppModel
    @AppStorage("fixitsays.theme") private var themeRaw = AppTheme.system.rawValue

    @State private var forceScreen: String?

    private var theme: AppTheme { AppTheme(rawValue: themeRaw) ?? .system }

    var body: some View {
        // Sign in with Apple is OPTIONAL and never a launch gate (Guideline 5.1.1(v)):
        // Home is always shown immediately. SIWA is offered as an opt-in inside Settings.
        HomeView(forceScreen: forceScreen)
            .preferredColorScheme(theme.colorScheme)
            .onChange(of: store.isPro) { _, _ in appModel.refresh() }
            .onAppear {
                #if DEBUG
                forceScreen = ProcessInfo.processInfo.environment["FIXITSAYS_SCREEN"]
                #endif
            }
    }
}
