import SwiftUI

struct ContentView: View {
    @StateObject private var store = IssueStore()
    @State private var selectedTab = 0
    // App-drawer report flow: type picker → report sheet
    @State private var showTypePicker  = false
    @State private var pendingType: IssueType? = nil
    @State private var showReportSheet = false

    var body: some View {
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

            // Floating action button — opens type-picker drawer first
            Button {
                showTypePicker = true
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
        .environmentObject(store)
        // Step 1 — type picker drawer (same style as the map)
        .sheet(isPresented: $showTypePicker, onDismiss: {
            if pendingType != nil { showReportSheet = true }
        }) {
            IssueTypePickerSheet { type in
                pendingType = type
                showTypePicker = false
            }
            .presentationDetents([.height(360)])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(24)
        }
        // Step 2 — full report form with progress bar
        .sheet(isPresented: $showReportSheet, onDismiss: {
            pendingType = nil
        }) {
            ReportIssueView(prefillType: pendingType)
                .environmentObject(store)
        }
        .task {
            await store.restoreSession()
        }
    }
}

#Preview {
    ContentView()
}
