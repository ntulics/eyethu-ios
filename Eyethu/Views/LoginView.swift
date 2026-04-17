import SwiftUI

struct LoginView: View {
    @EnvironmentObject var store: IssueStore
    @Environment(\.dismiss) private var dismiss

    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

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
                }
                .padding(.horizontal, 28)

                Spacer().frame(height: 20)

                Button("Continue without signing in") { dismiss() }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer()
            }
            .navigationBarTitleDisplayMode(.inline)
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
}

#Preview {
    LoginView().environmentObject(IssueStore())
}
