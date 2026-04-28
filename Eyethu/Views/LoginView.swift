import SwiftUI
import WebKit

struct LoginView: View {
    @EnvironmentObject var store: IssueStore
    @Environment(\.dismiss) private var dismiss

    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var providers: [LoginProviderOption] = []
    @State private var selectedProvider: LoginProviderOption?

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
                                        selectedProvider = provider
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
            .sheet(item: $selectedProvider) { provider in
                OAuthWebLoginView(provider: provider) { success in
                    if success {
                        Task {
                            await store.restoreSession()
                            dismiss()
                        }
                    }
                }
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

    var body: some View {
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
        .padding(14)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(alignment: .bottomTrailing) {
            if provider.live {
                Button("Continue") { onTap() }
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(brandColor, in: Capsule())
                    .padding(12)
            }
        }
    }
}

private struct OAuthWebLoginView: UIViewRepresentable {
    let provider: LoginProviderOption
    let onComplete: (Bool) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onComplete: onComplete)
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true

        var components = URLComponents(url: APIService.appBaseURL.appending(path: "/auth/login"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "callbackUrl", value: "/auth/native-complete"),
            URLQueryItem(name: "provider", value: provider.key),
        ]
        webView.load(URLRequest(url: components.url!))
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    final class Coordinator: NSObject, WKNavigationDelegate {
        let onComplete: (Bool) -> Void
        private var completed = false

        init(onComplete: @escaping (Bool) -> Void) {
            self.onComplete = onComplete
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            guard let url = webView.url else { return }
            if url.path == "/auth/native-complete" {
                syncCookies(from: webView) { [weak self] in
                    guard let self, !self.completed else { return }
                    self.completed = true
                    self.onComplete(true)
                }
            }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            guard !completed else { return }
            completed = true
            onComplete(false)
        }

        private func syncCookies(from webView: WKWebView, completion: @escaping () -> Void) {
            webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { cookies in
                let storage = HTTPCookieStorage.shared
                cookies.forEach { storage.setCookie($0) }
                completion()
            }
        }
    }
}

#Preview {
    LoginView().environmentObject(IssueStore())
}
