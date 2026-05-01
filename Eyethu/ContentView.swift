import SwiftUI

struct ContentView: View {
    @StateObject private var store = IssueStore()
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var selectedTab = 0
    @State private var selectedSection: AppSection? = .home
    @Environment(\.openURL) private var openURL
    // Simplified report flow: one sheet
    @State private var showReportSheet = false

    var body: some View {
        Group {
            if horizontalSizeClass == .regular {
                iPadLayout
            } else {
                phoneLayout
            }
        }
        .environmentObject(store)
        .sheet(isPresented: $showReportSheet) {
            ReportIssueView()
                .environmentObject(store)
                .presentationDetents(horizontalSizeClass == .regular ? [.large] : [.fraction(0.6), .large])
                .presentationDragIndicator(.visible)
        }
        .task {
            await store.restoreSession()
        }
    }

    private var phoneLayout: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                HomeView()
                    .tabItem { Label("Home", systemImage: "house.fill") }
                    .tag(0)

                NavigationStack {
                    IssueListView()
                }
                .tabItem { Label("Issues", systemImage: "list.bullet.rectangle.fill") }
                .tag(1)

                // Centre tab — replaced by FAB; kept as empty placeholder
                Color.clear
                    .tabItem { Label("", systemImage: "plus") }
                    .tag(2)

                NavigationStack {
                    IssueMapView()
                        .navigationTitle("Map")
                        .navigationBarTitleDisplayMode(.inline)
                }
                .tabItem { Label("Map", systemImage: "map.fill") }
                .tag(3)

                ProfileView()
                    .tabItem { Label("Profile", systemImage: "person.circle.fill") }
                    .tag(4)
            }
            .tint(.teal)

            // Floating action button — opens report sheet directly
            Button {
                showReportSheet = true
            } label: {
                ZStack {
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 58, height: 58)
                        .shadow(color: .orange.opacity(0.4), radius: 10, y: 4)
                    Image(systemName: "plus")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
            .offset(y: -4)
        }
    }

    private var iPadLayout: some View {
        NavigationSplitView {
            List(selection: $selectedSection) {
                Section {
                    Button {
                        selectedSection = .profile
                    } label: {
                        SidebarAccountCard(
                            name: store.currentUser?.name ?? "Guest",
                            subtitle: store.currentUser?.email ?? "Community member",
                            isSelected: selectedSection == .profile
                        )
                    }
                    .buttonStyle(.plain)
                    .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
                    .listRowBackground(Color.clear)
                }

                Section {
                    ForEach(AppSection.sidebarCases) { section in
                        Label(section.title, systemImage: section.systemImage)
                            .tag(section)
                    }
                }

                if let user = store.currentUser {
                    Section("Admin") {
                        ForEach(AdminLink.links(for: user)) { link in
                            Button {
                                openURL(link.url)
                            } label: {
                                Label(link.title, systemImage: link.systemImage)
                            }
                        }
                    }
                }
            }
            .navigationTitle("eyethu")
            .safeAreaInset(edge: .bottom) {
                Button {
                    showReportSheet = true
                } label: {
                    Label("Report Issue", systemImage: "plus.circle.fill")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(Color.orange, in: RoundedRectangle(cornerRadius: 18))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }
        } detail: {
            Group {
                switch selectedSection ?? .home {
                case .home:
                    HomeView()
                case .issues:
                    NavigationStack { IssueListView() }
                case .map:
                    NavigationStack {
                        IssueMapView()
                            .navigationTitle("Map")
                            .navigationBarTitleDisplayMode(.inline)
                    }
                case .profile:
                    ProfileView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemGroupedBackground))
        }
        .navigationSplitViewStyle(.balanced)
    }
}

private struct AdminLink: Identifiable {
    let id: String
    let title: String
    let path: String
    let systemImage: String
    let permission: String?
    let superOnly: Bool

    var url: URL {
        APIService.appBaseURL.appending(path: path)
    }

    static func links(for user: SessionUser) -> [AdminLink] {
        all.filter { link in
            (!link.superOnly || user.isSuperAdmin) && (link.permission == nil || user.can(link.permission!))
        }
    }

    private static let all: [AdminLink] = [
        AdminLink(id: "dashboard", title: "Dashboard", path: "/admin", systemImage: "square.grid.2x2", permission: "dashboard.access", superOnly: false),
        AdminLink(id: "admin-issues", title: "Admin Issues", path: "/admin/issues", systemImage: "exclamationmark.triangle", permission: "issues.read", superOnly: false),
        AdminLink(id: "alerts", title: "Alerts", path: "/admin/alerts", systemImage: "bell", permission: "dashboard.access", superOnly: false),
        AdminLink(id: "zones", title: "Zones", path: "/admin/zones", systemImage: "mappin.and.ellipse", permission: "zones.read", superOnly: false),
        AdminLink(id: "users", title: "Users", path: "/admin/users", systemImage: "person.2", permission: "users.read", superOnly: false),
        AdminLink(id: "login", title: "Login", path: "/admin/integrations", systemImage: "key", permission: nil, superOnly: true),
        AdminLink(id: "email", title: "Email", path: "/admin/email", systemImage: "envelope", permission: nil, superOnly: true),
        AdminLink(id: "whatsapp", title: "WhatsApp", path: "/admin/whatsapp", systemImage: "message", permission: "whatsapp.manage", superOnly: true),
        AdminLink(id: "tenants", title: "Municipalities", path: "/admin/tenants", systemImage: "building.2", permission: nil, superOnly: true),
        AdminLink(id: "roles", title: "Roles", path: "/admin/roles", systemImage: "shield", permission: nil, superOnly: true),
    ]
}

private struct SidebarAccountCard: View {
    let name: String
    let subtitle: String
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image("BrandMark")
                .resizable()
                .scaledToFit()
                .frame(width: 46, height: 46)
                .padding(8)
                .background(Color.orange.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(name)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(isSelected ? .blue : .primary)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(isSelected ? Color(.systemGray5) : Color.clear, in: RoundedRectangle(cornerRadius: 18))
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
    }
}

private enum AppSection: String, CaseIterable, Identifiable {
    case home
    case issues
    case map
    case profile

    var id: String { rawValue }

    static var sidebarCases: [AppSection] {
        [.home, .issues, .map]
    }

    var title: String {
        switch self {
        case .home: return "Home"
        case .issues: return "Issues"
        case .map: return "Map"
        case .profile: return "Profile"
        }
    }

    var systemImage: String {
        switch self {
        case .home: return "house.fill"
        case .issues: return "list.bullet.rectangle.fill"
        case .map: return "map.fill"
        case .profile: return "person.circle.fill"
        }
    }
}

#Preview {
    ContentView()
}
