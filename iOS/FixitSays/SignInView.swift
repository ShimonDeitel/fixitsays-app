import SwiftUI
import AuthenticationServices

/// Optional Sign in with Apple — presented from Settings, never a launch gate.
/// Signing in lets your holds and Pro status sync across devices via iCloud. Fully optional.
struct SignInView: View {
    @EnvironmentObject var account: AccountManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ZStack {
            FixitSaysBackground()
            VStack(spacing: 0) {
                Spacer(minLength: 20)

                Image(systemName: "icloud.fill")
                    .font(.system(size: 64, weight: .semibold))
                    .foregroundStyle(Color.fixitsaysAccent)

                Spacer(minLength: 24)

                VStack(spacing: 10) {
                    Text("Sync your holds")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                    Text("Sign in to keep your streak, levels and\npersonal bests across your devices.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                Spacer(minLength: 24)

                VStack(spacing: 12) {
                    SignInWithAppleButton(.continue) { request in
                        account.configure(request)
                    } onCompletion: { result in
                        account.handle(result)
                        if account.isSignedIn { dismiss() }
                    }
                    .signInWithAppleButtonStyle(scheme == .dark ? .white : .black)
                    .frame(height: 52)
                    .clipShape(Capsule())
                    .accessibilityIdentifier("siwa")

                    Text("Optional. FixitSays works fully without an account.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 32)

                Spacer().frame(height: 24)
            }
            .padding()
        }
        .overlay(alignment: .topTrailing) {
            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill").font(.title2)
                    .foregroundStyle(.secondary).padding()
            }
            .accessibilityLabel("Close")
        }
    }
}
