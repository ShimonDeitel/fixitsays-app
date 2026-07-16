import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appModel: AppModel
    @EnvironmentObject var store: Store
    @EnvironmentObject var account: AccountManager
    @Environment(\.dismiss) private var dismiss

    @AppStorage("fixitsays.theme") private var themeRaw = AppTheme.system.rawValue
    @AppStorage("fixitsays.haptics") private var hapticsEnabled = true
    @AppStorage("fixitsays.reminderOn") private var reminderOn = false
    @AppStorage("fixitsays.reminderHour") private var reminderHour = 9
    @AppStorage("fixitsays.reminderMinute") private var reminderMinute = 0

    @State private var showPaywall = false
    @State private var showSignIn = false
    @State private var showDeleteConfirm = false
    @State private var restoreMessage: String?

    private var version: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        return "FixitSays \(v)"
    }

    private var reminderTime: Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(from: DateComponents(hour: reminderHour, minute: reminderMinute)) ?? Date()
            },
            set: { newValue in
                let c = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                reminderHour = c.hour ?? 9
                reminderMinute = c.minute ?? 0
                if reminderOn { Reminders.schedule(hour: reminderHour, minute: reminderMinute) }
            }
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                proSection
                appearanceSection
                sessionSection
                accountSection
                aboutSection
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } }
            }
            .tint(Color.fixitsaysAccent)
            .sheet(isPresented: $showPaywall) { PaywallView() }
            .sheet(isPresented: $showSignIn) { SignInView() }
            .alert("Delete Account?", isPresented: $showDeleteConfirm) {
                Button("Delete", role: .destructive) {
                    appModel.deleteAllData()
                    account.deleteAccount()
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This permanently deletes your account and erases your diagnosis history on this device and from iCloud. This can't be undone.")
            }
        }
    }

    @ViewBuilder
    private var proSection: some View {
        Section {
            if store.isPro {
                HStack {
                    Label("FixitSays Pro", systemImage: "sparkles")
                    Spacer()
                    Text("Unlocked").foregroundStyle(.secondary)
                }
            } else {
                Button {
                    Haptics.tap(); showPaywall = true
                } label: {
                    HStack {
                        Label("Unlock FixitSays Pro", systemImage: "sparkles")
                        Spacer()
                        Text(store.displayPrice).foregroundStyle(.secondary)
                    }
                }
                Button("Restore Purchase") {
                    Task {
                        await store.restore()
                        restoreMessage = store.isPro ? "Restored." : "No previous purchase found."
                    }
                }
                if let restoreMessage {
                    Text(restoreMessage).font(.footnote).foregroundStyle(.secondary)
                }
            }
        } footer: {
            if !store.isPro {
                Text("$0.99/month auto-renewable subscription. Unlimited diagnoses and full history. Cancel anytime in Settings.")
            }
        }
    }

    private var appearanceSection: some View {
        Section("Appearance") {
            Picker("Theme", selection: $themeRaw) {
                ForEach(AppTheme.allCases) { Text($0.label).tag($0.rawValue) }
            }
            .pickerStyle(.segmented)
        }
    }

    private var sessionSection: some View {
        Section("General") {
            Toggle("Haptics", isOn: $hapticsEnabled)
            Toggle("Daily reminder", isOn: $reminderOn)
                .onChange(of: reminderOn) { _, on in
                    if on {
                        Task {
                            let granted = await Reminders.requestAuthorization()
                            if granted {
                                Reminders.schedule(hour: reminderHour, minute: reminderMinute)
                            } else {
                                reminderOn = false
                            }
                        }
                    } else {
                        Reminders.cancel()
                    }
                }
            if reminderOn {
                DatePicker("Time", selection: reminderTime, displayedComponents: .hourAndMinute)
            }
        }
    }

    @ViewBuilder
    private var accountSection: some View {
        Section {
            if account.isSignedIn {
                HStack {
                    Text("Signed in")
                    Spacer()
                    Text(account.displayName.isEmpty ? "Apple ID" : account.displayName)
                        .foregroundStyle(.secondary)
                }
                Button("Sign Out", role: .destructive) { account.signOut() }
                Button("Delete Account", role: .destructive) { showDeleteConfirm = true }
            } else {
                Button {
                    Haptics.tap(); showSignIn = true
                } label: {
                    Label("Sign in with Apple", systemImage: "icloud")
                }
            }
        } footer: {
            if !account.isSignedIn {
                Text("Optional. Sign in to sync your holds, streak and Pro status across devices.")
            }
        }
    }

    private var aboutSection: some View {
        Section {
            Link("Privacy Policy", destination: URL(string: "https://shimondeitel.github.io/fixitsays-site/privacy.html")!)
        } footer: {
            Text(version).frame(maxWidth: .infinity, alignment: .center).padding(.top, 4)
        }
    }
}
