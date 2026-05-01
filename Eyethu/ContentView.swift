import SwiftUI

struct ContentView: View {
    @StateObject private var store = IssueStore()
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var selectedTab = 0
    @State private var selectedSection: AppSection? = .home
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
                    ForEach(AppSection.allCases) { section in
                        Label(section.title, systemImage: section.systemImage)
                            .tag(section)
                    }
                }

                Section {
                    Button {
                        showReportSheet = true
                    } label: {
                        Label("Report Issue", systemImage: "plus.circle.fill")
                            .font(.headline)
                            .foregroundStyle(.orange)
                    }
                }
            }
            .navigationTitle("eyethu")
            .safeAreaInset(edge: .bottom) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(store.currentUser?.name ?? "Guest")
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                    Text(store.currentUser?.email ?? "Community member")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(.ultraThinMaterial)
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

private enum AppSection: String, CaseIterable, Identifiable {
    case home
    case issues
    case map
    case profile

    var id: String { rawValue }

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
