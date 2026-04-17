import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var store: IssueStore
    @State private var notificationsEnabled = true
    @State private var showLogin = false

    var body: some View {
        NavigationStack {
            List {
                // User header
                Section {
                    if let user = store.currentUser {
                        HStack(spacing: 14) {
                            ZStack {
                                Circle().fill(Color.teal.opacity(0.15)).frame(width: 60, height: 60)
                                Text(String(user.name.prefix(2)).uppercased())
                                    .font(.system(size: 22, weight: .bold))
                                    .foregroundStyle(.teal)
                            }
                            VStack(alignment: .leading, spacing: 3) {
                                Text(user.name).font(.system(size: 17, weight: .semibold))
                                Text(user.email).font(.subheadline).foregroundStyle(.secondary)
                                Label(user.role.capitalized, systemImage: "person.badge.shield.checkmark")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 6)
                    } else {
                        Button { showLogin = true } label: {
                            HStack {
                                Image(systemName: "person.circle.fill")
                                    .font(.system(size: 40))
                                    .foregroundStyle(.teal.opacity(0.5))
                                VStack(alignment: .leading) {
                                    Text("Sign In").font(.headline)
                                    Text("Access admin features and manage issues")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 6)
                        }
                    }
                }

                // Activity
                Section("My Activity") {
                    LabeledContent("Issues Visible") {
                        Text("\(store.issues.count)").font(.system(size: 14, weight: .semibold)).foregroundStyle(.teal)
                    }
                    LabeledContent("Resolved") {
                        Text("\(store.resolvedIssues.count)").font(.system(size: 14, weight: .semibold)).foregroundStyle(.green)
                    }
                    LabeledContent("Active") {
                        Text("\(store.activeIssues.count)").font(.system(size: 14, weight: .semibold)).foregroundStyle(.orange)
                    }
                }

                if let user = store.currentUser, !user.permissions.isEmpty {
                    Section("Permissions") {
                        ForEach(user.permissions, id: \.self) { perm in
                            Label(perm, systemImage: "checkmark.shield")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                // Preferences
                Section("Preferences") {
                    Toggle("Push Notifications", isOn: $notificationsEnabled).tint(.teal)
                }

                // About
                Section("About") {
                    LabeledContent("Backend", value: "eyethu.azurewebsites.net")
                    LabeledContent("Version", value: "1.0.0")
                }

                if store.currentUser != nil {
                    Section {
                        Button(role: .destructive) {
                            Task { try? await store.signOut() }
                        } label: {
                            Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                        }
                    }
                }
            }
            .navigationTitle("Profile")
            .sheet(isPresented: $showLogin) {
                LoginView().environmentObject(store)
            }
        }
    }
}

#Preview {
    ProfileView().environmentObject(IssueStore())
}
