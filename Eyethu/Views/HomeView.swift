import SwiftUI

struct HomeView: View {
    @EnvironmentObject var store: IssueStore
    @State private var showLogin = false

    private var dateHeader: String {
        let f = DateFormatter()
        f.dateFormat = "EEEE, d MMM"
        return f.string(from: Date())
    }

    var body: some View {
        NavigationStack {
            Group {
                if store.isLoading && store.issues.isEmpty {
                    ProgressView("Loading issues…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    scrollContent
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Eyethu")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    if let user = store.currentUser {
                        Menu {
                            Text("Signed in as \(user.name)")
                            Divider()
                            Button(role: .destructive) {
                                Task { try? await store.signOut() }
                            } label: {
                                Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                            }
                        } label: {
                            Image(systemName: "person.circle.fill")
                                .symbolRenderingMode(.hierarchical)
                                .foregroundStyle(.teal)
                        }
                    } else {
                        Button { showLogin = true } label: {
                            Image(systemName: "person.circle")
                        }
                    }

                    Button {
                        Task { await store.loadIssues() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(store.isLoading)
                }
            }
            .sheet(isPresented: $showLogin) {
                LoginView().environmentObject(store)
            }
            .task { await store.loadIssues() }
            .refreshable { await store.loadIssues() }
        }
    }

    private var scrollContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                // Error banner
                if let err = store.error {
                    Label(err, systemImage: "wifi.slash")
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
                        .padding(.horizontal, 20)
                }

                // Date header
                Text(dateHeader)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 20)

                // Performance rings card
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text("Issue Overview")
                            .font(.system(size: 16, weight: .semibold))
                        Spacer()
                        NavigationLink("See all") { IssueListView() }
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.teal)
                    }

                    HStack(spacing: 0) {
                        RingProgressView(
                            progress: store.activeRate,
                            color: .red,
                            icon: "exclamationmark.circle.fill",
                            label: "Active"
                        ).frame(maxWidth: .infinity)

                        RingProgressView(
                            progress: store.inProgressRate,
                            color: .teal,
                            icon: "arrow.triangle.2.circlepath",
                            label: "In Progress"
                        ).frame(maxWidth: .infinity)

                        RingProgressView(
                            progress: store.resolutionRate,
                            color: .blue,
                            icon: "checkmark.circle.fill",
                            label: "Resolved"
                        ).frame(maxWidth: .infinity)
                    }
                }
                .padding(16)
                .background(.background, in: RoundedRectangle(cornerRadius: 20))
                .shadow(color: .black.opacity(0.06), radius: 10, y: 3)
                .padding(.horizontal, 20)

                // Active reports + Last report
                HStack(spacing: 12) {
                    StatCard(title: "Active Reports", subtitle: "This week") {
                        Text("\(store.activeIssues.count)")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundStyle(.purple)
                        ActivityBars(days: store.weeklyActivity, accentColor: .purple)
                    }

                    StatCard(title: "Last Report", subtitle: "Submitted") {
                        if let date = store.lastReportDate {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(date.relativeFormatted)
                                    .font(.system(size: 20, weight: .bold, design: .rounded))
                                    .foregroundStyle(.teal)
                                Text(date.shortFormatted)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Spacer(minLength: 8)
                                HStack(spacing: 4) {
                                    ForEach(0..<5) { i in
                                        RoundedRectangle(cornerRadius: 2)
                                            .fill(i < 3 ? Color.teal : Color.teal.opacity(0.2))
                                            .frame(height: 3)
                                    }
                                }
                            }
                        } else {
                            Text("No reports yet").font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.horizontal, 20)

                // Status breakdown
                HStack(spacing: 12) {
                    StatusCountCard(label: "Open",        count: store.openIssues.count,       color: .orange, icon: "exclamationmark.triangle.fill")
                    StatusCountCard(label: "In Progress", count: store.inProgressIssues.count, color: .teal,   icon: "arrow.triangle.2.circlepath.circle.fill")
                    StatusCountCard(label: "Resolved",    count: store.resolvedIssues.count,   color: .green,  icon: "checkmark.circle.fill")
                }
                .padding(.horizontal, 20)

                // Recent issues
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Label("Recent Issues", systemImage: "clock.fill")
                            .font(.system(size: 15, weight: .semibold))
                        Spacer()
                        NavigationLink("View all") { IssueListView() }
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.teal)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 8)

                    Divider().padding(.horizontal, 16)

                    ForEach(store.issues.prefix(5)) { issue in
                        NavigationLink(destination: IssueDetailView(issue: issue)) {
                            IssueRowView(issue: issue)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 6)
                        }
                        .buttonStyle(.plain)

                        if issue.id != store.issues.prefix(5).last?.id {
                            Divider().padding(.horizontal, 16)
                        }
                    }
                    .padding(.bottom, 8)
                }
                .background(.background, in: RoundedRectangle(cornerRadius: 20))
                .shadow(color: .black.opacity(0.06), radius: 10, y: 3)
                .padding(.horizontal, 20)

                // Category + notices
                HStack(spacing: 12) {
                    StatCard(title: "Categories", subtitle: "Issue types") {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(store.typeBreakdown.prefix(4), id: \.0) { type, count in
                                HStack {
                                    Image(systemName: type.icon).font(.caption).foregroundStyle(.secondary).frame(width: 16)
                                    Text(type.displayName).font(.caption).foregroundStyle(.secondary)
                                    Spacer()
                                    Text("\(count)").font(.caption.bold()).foregroundStyle(.primary)
                                }
                            }
                        }
                    }

                    StatCard(title: "Total Reports", subtitle: "All time") {
                        Text("\(store.issues.count)")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundStyle(.orange)
                        Text("across \(store.typeBreakdown.count) categories")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 20)

                Spacer(minLength: 20)
            }
            .padding(.top, 8)
        }
    }
}

struct StatusCountCard: View {
    let label: String
    let count: Int
    let color: Color
    let icon: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 20)).foregroundStyle(color)
            Text("\(count)").font(.system(size: 20, weight: .bold, design: .rounded))
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(.background, in: RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.05), radius: 6, y: 2)
    }
}

#Preview {
    HomeView().environmentObject(IssueStore())
}
