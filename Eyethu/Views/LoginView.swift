import SwiftUI
import AuthenticationServices
import UIKit

struct LoginView: View {
    @EnvironmentObject var store: IssueStore
    @Environment(\.dismiss) private var dismiss

    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var providers: [LoginProviderOption] = []
    @State private var authSession: ASWebAuthenticationSession?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Spacer()

                // Logo
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.teal.opacity(0.12))
                            .frame(width: 88, height: 88)
                        Image(systemName: "exclamationmark.shield.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(.teal)
                    }
                    Text("Eyethu")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                    Text("Sign in to manage issues and access admin features.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }

                Spacer().frame(height: 48)

                // Form
                VStack(spacing: 14) {
                    TextField("Email", text: $email)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()

                    SecureField("Password", text: $password)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(.password)

                    if let msg = errorMessage {
                        Label(msg, systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Button {
                        signIn()
                    } label: {
                        Group {
                            if isLoading {
                                ProgressView().tint(.white)
                            } else {
                                Text("Sign In")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(canSubmit ? Color.teal : Color(.systemGray4), in: RoundedRectangle(cornerRadius: 14))
                        .foregroundStyle(.white)
                    }
                    .disabled(!canSubmit || isLoading)

                    if !providers.isEmpty {
                        VStack(spacing: 12) {
                            HStack(spacing: 12) {
                                Rectangle().fill(Color.secondary.opacity(0.18)).frame(height: 1)
                                Text("Other sign-in options")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(.secondary)
                                    .textCase(.uppercase)
                                Rectangle().fill(Color.secondary.opacity(0.18)).frame(height: 1)
                            }
                            .padding(.top, 6)

                            VStack(spacing: 10) {
                                ForEach(providers) { provider in
                                    ProviderStateCard(provider: provider) {
                                        startProviderSignIn(provider)
                                    }
                                }
                            }

                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "info.circle.fill")
                                    .foregroundStyle(.teal)
                                    .padding(.top, 1)
                                Text("Available providers use the same Eyethu web sign-in flow inside the app. First-time provider sign-in creates a standard user account automatically with public/client permissions.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .background(Color.teal.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                    }
                }
                .padding(.horizontal, 28)

                Spacer().frame(height: 20)

                Button("Continue without signing in") { dismiss() }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer()
            }
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await loadProviders()
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Skip") { dismiss() }.foregroundStyle(.secondary)
                }
            }
        }
    }

    private var canSubmit: Bool {
        !email.trimmingCharacters(in: .whitespaces).isEmpty &&
        password.count >= 4
    }

    private func signIn() {
        isLoading = true
        errorMessage = nil
        Task {
            do {
                let ok = try await store.signIn(email: email, password: password)
                if ok {
                    dismiss()
                } else {
                    errorMessage = "Invalid email or password."
                }
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }

    @MainActor
    private func loadProviders() async {
        do {
            providers = try await APIService.shared.fetchLoginProviders()
        } catch {
            providers = []
        }
    }

    private func startProviderSignIn(_ provider: LoginProviderOption) {
        errorMessage = nil

        var components = URLComponents(url: APIService.appBaseURL.appending(path: "/auth/login"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "callbackUrl", value: "/auth/native-complete"),
            URLQueryItem(name: "provider", value: provider.key),
        ]

        guard let url = components.url else {
            errorMessage = "Could not start sign-in."
            return
        }

        let session = ASWebAuthenticationSession(url: url, callbackURLScheme: "eyethu") { callbackURL, error in
            if let error {
                if (error as? ASWebAuthenticationSessionError)?.code != .canceledLogin {
                    Task { @MainActor in
                        errorMessage = error.localizedDescription
                    }
                }
                Task { @MainActor in authSession = nil }
                return
            }

            guard
                let callbackURL,
                let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
                let grant = components.queryItems?.first(where: { $0.name == "grant" })?.value
            else {
                Task { @MainActor in
                    errorMessage = "Sign-in completed, but the app did not receive a valid session."
                }
                Task { @MainActor in authSession = nil }
                return
            }

            Task {
                do {
                    try await APIService.shared.completeNativeSignIn(grant: grant)
                    await store.restoreSession()
                    await MainActor.run { dismiss() }
                } catch {
                    await MainActor.run {
                        errorMessage = error.localizedDescription
                    }
                }
                await MainActor.run { authSession = nil }
            }
        }

        session.presentationContextProvider = AuthPresentationContextProvider.shared
        session.prefersEphemeralWebBrowserSession = false
        authSession = session
        session.start()
    }
}

private struct ProviderStateCard: View {
    let provider: LoginProviderOption
    let onTap: () -> Void

    private var statusText: String {
        if provider.live { return "Available now" }
        if provider.enabled { return "Configured in admin" }
        if provider.configured { return "Saved but disabled" }
        return "Not configured"
    }

    private var brandColor: Color {
        Color(hex: provider.brand)
    }

    @ViewBuilder
    private var providerButton: some View {
        if provider.key == "google" {
            Button(action: onTap) {
                HStack(spacing: 12) {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 28, height: 28)
                        .overlay(
                            Text("G")
                                .font(.system(size: 16, weight: .black))
                                .foregroundStyle(Color(red: 66/255, green: 133/255, blue: 244/255))
                        )
                    Text("Sign in with Google")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.black.opacity(0.82))
                    Spacer()
                }
                .padding(.horizontal, 16)
                .frame(height: 50)
                .background(Color.white, in: Capsule())
            }
            .buttonStyle(.plain)
        } else if provider.key == "facebook" {
            Button(action: onTap) {
                HStack(spacing: 12) {
                    Circle()
                        .fill(Color.white.opacity(0.18))
                        .frame(width: 28, height: 28)
                        .overlay(
                            Text("f")
                                .font(.system(size: 18, weight: .black))
                                .foregroundStyle(.white)
                        )
                    Text("Sign in with Facebook")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .frame(height: 50)
                .background(brandColor, in: Capsule())
            }
            .buttonStyle(.plain)
        } else {
            Button(action: onTap) {
                HStack(spacing: 12) {
                    Circle()
                        .fill(Color.white.opacity(0.18))
                        .frame(width: 28, height: 28)
                        .overlay(
                            Image(systemName: "building.2.crop.circle.fill")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(.white)
                        )
                    Text("Continue with \(provider.name)")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .frame(height: 50)
                .background(brandColor, in: Capsule())
            }
            .buttonStyle(.plain)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Circle()
                    .fill(brandColor)
                    .frame(width: 10, height: 10)
                    .padding(.top, 5)

                VStack(alignment: .leading, spacing: 4) {
                    Text(provider.name)
                        .font(.system(size: 14, weight: .semibold))
                    Text(provider.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                Text(statusText)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color(.secondarySystemBackground), in: Capsule())
            }

            if provider.live {
                providerButton
            }
        }
        .padding(14)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private final class AuthPresentationContextProvider: NSObject, ASWebAuthenticationPresentationContextProviding {
    static let shared = AuthPresentationContextProvider()

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow) ?? ASPresentationAnchor()
    }
}

#Preview {
    LoginView().environmentObject(IssueStore())
}
