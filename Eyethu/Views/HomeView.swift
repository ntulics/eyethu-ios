import SwiftUI

enum InboxTab: String, CaseIterable, Identifiable {
    case messages = "Messages"
    case notifications = "Notifications"

    var id: String { rawValue }
}

struct HomeView: View {
    @EnvironmentObject var store: IssueStore
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var showLogin           = false
    @State private var currentAreaName    = "Near you"
    @State private var showActiveIssues   = false
    @State private var showInbox          = false
    @State private var inboxInitialTab: InboxTab = .messages
    
    // Track unread alerts locally
    @State private var hasUnreadAlerts = false

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let timeText: String
        if hour >= 5 && hour < 12 { timeText = "Morning" }
        else if hour >= 12 && hour < 17 { timeText = "Afternoon" }
        else { timeText = "Evening" }
        
        let firstName = store.currentUser?.name.split(separator: " ").first.map(String.init) ?? "Guest"
        return "\(timeText), \(firstName)"
    }

    private var dateHeader: String {
        let f = DateFormatter()
        f.dateFormat = "EEEE, d MMM"
        return f.string(from: Date())
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                Group {
                    if store.isLoading && store.issues.isEmpty {
                        ProgressView("Loading issues…")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        scrollContent
                    }
                }
                .background(Color(.systemGroupedBackground))
                
                topHeader
                    .zIndex(1)
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showLogin) {
                LoginView().environmentObject(store)
            }
            .fullScreenCover(isPresented: $showInbox) {
                InboxView(initialTab: inboxInitialTab)
            }
            .navigationDestination(isPresented: $showActiveIssues) {
                IssueListView(entryFilter: .active)
            }
            .task {
                await store.loadIssues()
                await loadCurrentArea()
                await checkUnreadAlerts()
            }
            .refreshable {
                await store.loadIssues()
                await loadCurrentArea()
                await checkUnreadAlerts()
            }
        }
    }

    private var scrollContent: some View {
        GeometryReader { proxy in
            let useDashboardGrid = proxy.size.width >= 640
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Header spacer
                    Color.clear
                        .frame(height: 54)

                    // Error banner
                    if let err = store.error {
                        Label(err, systemImage: "wifi.slash")
                            .font(.caption)
                            .foregroundStyle(.orange)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
                            .padding(.horizontal, contentHorizontalPadding(for: proxy.size.width))
                    }

                    LazyVGrid(
                        columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: useDashboardGrid ? 2 : 1),
                        spacing: 16
                    ) {
                        overviewCard
                        activeReportsCard
                        NationalStatsCard(store: store)
                    }
                    .padding(.horizontal, contentHorizontalPadding(for: proxy.size.width))

                    LazyVGrid(
                        columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: useDashboardGrid ? 2 : 1),
                        spacing: 16
                    ) {
                        municipalLeaderboardCard
                        categoriesCard
                        recentIssuesCard
                    }
                    .padding(.horizontal, contentHorizontalPadding(for: proxy.size.width))

                    Spacer(minLength: 120)
                }
            }
        }
    }

    private func contentHorizontalPadding(for width: CGFloat) -> CGFloat {
        width >= 900 ? 32 : 20
    }

    private var overviewCard: some View {
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
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.08), radius: 10, y: 3)
    }

    private var activeReportsCard: some View {
        ActiveReportsCard(
            title: "Active Reports",
            subtitle: currentAreaName,
            count: store.openIssues.count,
            accentColor: store.issues.first?.type.color ?? .teal,
            lastDate: store.lastReportDate,
            days: store.weeklyActivity,
            openCount: store.openIssues.count,
            inProgressCount: store.inProgressIssues.count,
            resolvedCount: store.resolvedIssues.count,
            onTap: { showActiveIssues = true }
        )
    }

    @ViewBuilder
    private var municipalLeaderboardCard: some View {
        if !store.municipalityLeaderboard.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Label("Municipal Leaderboard", systemImage: "trophy.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.primary)
                    Spacer()
                    HStack(spacing: 10) {
                        Label("Issues", systemImage: "circle.fill")
                            .font(.caption2)
                            .foregroundStyle(.red.opacity(0.7))
                        Label("Resolved", systemImage: "circle.fill")
                            .font(.caption2)
                            .foregroundStyle(.green.opacity(0.8))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 12)

                Divider().padding(.horizontal, 16)

                ForEach(store.municipalityLeaderboard) { stat in
                    MunicipalityLeaderboardRow(stat: stat)
                    if stat.id != store.municipalityLeaderboard.last?.id {
                        Divider().padding(.horizontal, 16)
                    }
                }
                .padding(.bottom, 8)
            }
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
            .shadow(color: .black.opacity(0.08), radius: 10, y: 3)
        }
    }

    @ViewBuilder
    private var categoriesCard: some View {
        if !store.typeLeaderboard.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline) {
                    Label("Categories", systemImage: "square.grid.2x2.fill")
                        .font(.system(size: 15, weight: .semibold))
                    Spacer()
                    Text("\(store.issues.count) Total")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.teal)
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 6)

                HStack {
                    Text("Issue types")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    HStack(spacing: 10) {
                        Label("Issues", systemImage: "circle.fill")
                            .font(.caption2)
                            .foregroundStyle(.red.opacity(0.7))
                        Label("Resolved", systemImage: "circle.fill")
                            .font(.caption2)
                            .foregroundStyle(.green.opacity(0.8))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)

                Divider().padding(.horizontal, 16)

                ForEach(store.typeLeaderboard) { stat in
                    CategoryLeaderboardRow(stat: stat)
                    if stat.id != store.typeLeaderboard.last?.id {
                        Divider().padding(.horizontal, 16)
                    }
                }
                .padding(.bottom, 8)
            }
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
            .shadow(color: .black.opacity(0.08), radius: 10, y: 3)
        }
    }

    private var recentIssuesCard: some View {
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

            ForEach(store.issues.prefix(3)) { issue in
                NavigationLink(destination: IssueDetailView(issue: issue)) {
                    IssueRowView(issue: issue)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.plain)

                if issue.id != store.issues.prefix(3).last?.id {
                    Divider().padding(.horizontal, 16)
                }
            }
            .padding(.bottom, 8)
        }
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.08), radius: 10, y: 3)
    }

    private var topHeader: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top) {
                HStack(alignment: .center, spacing: 12) {
                    Image("BrandMark")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 42, height: 42)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(greeting)
                            .font(.system(size: 26, weight: .bold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)

                        Text(dateHeader)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                if horizontalSizeClass != .regular {
                    Button {
                        inboxInitialTab = .messages
                        showInbox = true
                        hasUnreadAlerts = false
                    } label: {
                        ZStack(alignment: .topTrailing) {
                            Circle()
                                .fill(Color.teal.opacity(0.12))
                                .frame(width: 48, height: 48)
                                .overlay {
                                    Image(systemName: "bubble.left.and.bubble.right")
                                        .font(.system(size: 22, weight: .medium))
                                        .foregroundStyle(.teal)
                                }

                            if hasUnreadAlerts {
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 14, height: 14)
                                    .overlay(Circle().stroke(Color(.systemGroupedBackground), lineWidth: 2))
                                    .offset(x: -2, y: 2)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 10)
            .background(.ultraThinMaterial.opacity(0.34))
            
            // Very soft gradient spill to avoid hard cut
            LinearGradient(
                stops: [
                    .init(color: Color(.systemGroupedBackground).opacity(0.10), location: 0),
                    .init(color: Color(.systemGroupedBackground).opacity(0.03), location: 0.42),
                    .init(color: .clear, location: 1.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 18)
            .allowsHitTesting(false)
        }
    }
    
    private func checkUnreadAlerts() async {
        guard let alerts = try? await APIService.shared.fetchAlerts() else { return }
        let active = alerts.filter { $0.status == "active" }
        let stored = UserDefaults.standard.array(forKey: "eyethu.readAlertIds") as? [Int] ?? []
        let readIds = Set(stored)
        
        await MainActor.run {
            hasUnreadAlerts = active.contains { !readIds.contains($0.id) }
        }
    }

    private func loadCurrentArea() async {
        do {
            let loc = try await LocationHelper.shared.requestLocation()
            let result = try await APIService.shared.geocode(lat: loc.coordinate.latitude, lon: loc.coordinate.longitude)
            currentAreaName = compactAreaName(streetAddress: result.streetAddress, municipality: result.municipality)
        } catch {
            currentAreaName = "Near you"
        }
    }

    private func compactAreaName(streetAddress: String?, municipality: String?) -> String {
        if let municipality, !municipality.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return municipality.replacingOccurrences(of: "City of ", with: "")
        }

        if let streetAddress, !streetAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return streetAddress
                .split(separator: ",")
                .first
                .map { String($0) } ?? "Near you"
        }

        return "Near you"
    }
}

struct MunicipalityLeaderboardRow: View {
    let stat: IssueStore.MuniStat

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(stat.name)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                Spacer()
                HStack(spacing: 12) {
                    Label("\(stat.open)", systemImage: "exclamationmark.circle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.red)
                    Label("\(stat.resolved)", systemImage: "checkmark.circle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.green)
                }
            }
            GeometryReader { geo in
                let total = max(stat.total, 1)
                let openW    = geo.size.width * CGFloat(stat.open)    / CGFloat(total)
                let resolvedW = geo.size.width * CGFloat(stat.resolved) / CGFloat(total)
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3).fill(Color(.systemGray5)).frame(height: 6)
                    HStack(spacing: 1) {
                        if stat.open > 0 {
                            RoundedRectangle(cornerRadius: 3).fill(Color.red.opacity(0.7)).frame(width: openW, height: 6)
                        }
                        if stat.resolved > 0 {
                            RoundedRectangle(cornerRadius: 3).fill(Color.green.opacity(0.8)).frame(width: resolvedW, height: 6)
                        }
                    }
                }
            }
            .frame(height: 6)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}

struct CategoryLeaderboardRow: View {
    let stat: IssueStore.TypeStat

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: 10) {
                HStack(spacing: 10) {
                    IssueTypeGlyph(type: stat.type, size: 15, color: stat.type.color)
                        .frame(width: 18)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(stat.type.displayName)
                            .font(.system(size: 13, weight: .semibold))
                            .lineLimit(1)
                        Text("\(stat.total) total")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                HStack(spacing: 12) {
                    Label("\(stat.active)", systemImage: "exclamationmark.circle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.red)
                    Label("\(stat.resolved)", systemImage: "checkmark.circle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.green)
                }
            }
            GeometryReader { geo in
                let total = max(stat.total, 1)
                let activeW = geo.size.width * CGFloat(stat.active) / CGFloat(total)
                let resolvedW = geo.size.width * CGFloat(stat.resolved) / CGFloat(total)
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color(.systemGray5))
                        .frame(height: 6)
                    HStack(spacing: 1) {
                        if stat.active > 0 {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.red.opacity(0.7))
                                .frame(width: activeW, height: 6)
                        }
                        if stat.resolved > 0 {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.green.opacity(0.8))
                                .frame(width: resolvedW, height: 6)
                        }
                    }
                }
            }
            .frame(height: 6)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}

struct NationalStatsCard: View {
    let store: IssueStore
    private var topType: IssueType? { store.typeBreakdown.first?.0 }
    private var activeMunis: Int { store.municipalityLeaderboard.count }
    private var resolutionPct: Int { Int((store.resolutionRate * 100).rounded()) }
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                HStack(spacing: 6) {
                    Image("icon-national-south-africa")
                        .resizable()
                        .renderingMode(.original)
                        .scaledToFit()
                        .frame(width: 28, height: 28)
                    Text("National")
                        .font(.system(size: 15, weight: .semibold))
                }
                Spacer()
                Text("South Africa")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)
            Divider().padding(.horizontal, 16)
            HStack(spacing: 0) {
                NationalStatItem(value: "\(store.issues.count)", label: "Total Issues", assetName: "icon-national-issues")
                Divider().frame(height: 44)
                NationalStatItem(value: "\(resolutionPct)%", label: "Resolved", assetName: "icon-national-resolved")
                Divider().frame(height: 44)
                NationalStatItem(value: "\(activeMunis)", label: "Municipalities", assetName: "icon-national-municipality")
                if let top = topType {
                    Divider().frame(height: 44)
                    NationalStatItem(value: top.displayName, label: "Top Issue", issueType: top)
                }
            }
            .padding(.vertical, 12)
        }
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.08), radius: 10, y: 3)
    }
}

struct NationalStatItem: View {
    let value: String
    let label: String
    let assetName: String?
    let issueType: IssueType?

    init(value: String, label: String, assetName: String) {
        self.value = value
        self.label = label
        self.assetName = assetName
        self.issueType = nil
    }

    init(value: String, label: String, issueType: IssueType) {
        self.value = value
        self.label = label
        self.assetName = nil
        self.issueType = issueType
    }

    var body: some View {
        VStack(spacing: 4) {
            if let issueType {
                IssueTypeGlyph(type: issueType, size: 15, color: issueType.color)
            } else if let assetName {
                Image(assetName)
                    .resizable()
                    .renderingMode(.original)
                    .scaledToFit()
                    .frame(width: 22, height: 22)
            }
            Text(value).font(.system(size: 13, weight: .bold, design: .rounded)).foregroundStyle(.primary).lineLimit(1).minimumScaleFactor(0.7)
            Text(label).font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(1).minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 4)
    }
}

struct StatusCountCard: View {
    let label: String; let count: Int; let color: Color; let icon: String
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 20)).foregroundStyle(color)
            Text("\(count)").font(.system(size: 20, weight: .bold, design: .rounded))
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 14).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14)).shadow(color: .black.opacity(0.06), radius: 6, y: 2)
    }
}

import UserNotifications

struct InboxView: View {
    private static let readAlertsKey = "eyethu.readAlertIds"
    let initialTab: InboxTab
    let showsDoneButton: Bool
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab: InboxTab
    @State private var pushStatus: UNAuthorizationStatus = .notDetermined
    @State private var requesting    = false
    @State private var alerts: [APIService.MuniAlert] = []
    @State private var alertsLoading = false
    @State private var selectedAlert: APIService.MuniAlert?
    @State private var readAlertIds: Set<Int> = []
    init(initialTab: InboxTab, showsDoneButton: Bool = true) {
        self.initialTab = initialTab
        self.showsDoneButton = showsDoneButton
        _selectedTab = State(initialValue: initialTab)
    }
    var body: some View {
        NavigationStack {
            Group {
                if selectedTab == .messages { ScrollView { messagesContent } }
                else { ScrollView { VStack(spacing: 12) { pushPermissionCard.padding(.top, 8).padding(.horizontal, 20); notificationsState }.padding(.bottom, 20) } }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(selectedAlert == nil ? "Messages" : "Message")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { if selectedAlert != nil { Button { selectedAlert = nil } label: { Label("Back", systemImage: "chevron.left") }.foregroundStyle(.teal) } }
                if showsDoneButton {
                    ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() }.foregroundStyle(.teal) }
                }
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                if selectedAlert == nil {
                    Picker("Inbox", selection: $selectedTab) { ForEach(InboxTab.allCases) { tab in Text(tab.rawValue).tag(tab) } }
                        .pickerStyle(.segmented).padding(.horizontal, 20).padding(.bottom, 8).background(Color(.systemGroupedBackground).opacity(0.96))
                }
            }
        }
        .task { loadReadAlerts(); await refreshPushStatus(); await loadAlerts() }
    }
    @ViewBuilder private var messagesContent: some View {
        if let selectedAlert { MessageDetailView(alert: selectedAlert).padding(.horizontal, 20).padding(.top, 12).padding(.bottom, 28) }
        else if alertsLoading { ProgressView().frame(maxWidth: .infinity).padding(.vertical, 48) }
        else if alerts.isEmpty { emptyState(icon: "bubble.left.and.bubble.right", title: "No messages yet", subtitle: "Updates and responses from your municipality will appear here.") }
        else { VStack(spacing: 0) { ForEach(alerts) { alert in Button { markAsRead(alert.id); selectedAlert = alert } label: { AlertRow(alert: alert, isRead: readAlertIds.contains(alert.id)) }.buttonStyle(.plain) } }.padding(.horizontal, 20).padding(.top, 8).padding(.bottom, 28) }
    }
    @ViewBuilder private var notificationsState: some View { emptyState(icon: "bell", title: "Notification settings", subtitle: "Push delivery lives here. Municipality messages stay in the inbox.") }
    private func emptyState(icon: String, title: String, subtitle: String) -> some View {
        VStack(spacing: 16) {
            ZStack { RoundedRectangle(cornerRadius: 20).fill(Color(.systemGray5)).frame(width: 72, height: 72); Image(systemName: icon).font(.system(size: 30, weight: .light)).foregroundStyle(.secondary) }
            VStack(spacing: 6) { Text(title).font(.system(size: 17, weight: .semibold)); Text(subtitle).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center).padding(.horizontal, 32) }
        }.frame(maxWidth: .infinity).padding(.vertical, 40)
    }
    private func loadAlerts() async { alertsLoading = true; if let fetched = try? await APIService.shared.fetchAlerts() { await MainActor.run { alerts = fetched.filter { $0.status == "active" }; alertsLoading = false } } else { await MainActor.run { alertsLoading = false } } }
    @ViewBuilder private var pushPermissionCard: some View {
        HStack(spacing: 14) {
            ZStack { RoundedRectangle(cornerRadius: 12).fill(pushStatus == .authorized ? Color.teal.opacity(0.12) : Color.orange.opacity(0.10)).frame(width: 44, height: 44); Image(systemName: pushStatus == .authorized ? "bell.badge.fill" : "bell.slash").font(.system(size: 18)).foregroundStyle(pushStatus == .authorized ? .teal : .orange) }
            VStack(alignment: .leading, spacing: 3) { Text(pushStatus == .authorized ? "Notifications on" : "Enable notifications").font(.system(size: 14, weight: .semibold)); Text(pushStatus == .authorized ? "Push alerts are enabled for this device." : "Allow push alerts so new municipality messages can reach you outside the app.").font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true) }
            Spacer(minLength: 0)
            if pushStatus == .notDetermined { Button { requestPushPermission() } label: { Text(requesting ? "…" : "Allow").font(.system(size: 13, weight: .semibold)).padding(.horizontal, 14).padding(.vertical, 8).background(Color.orange, in: RoundedRectangle(cornerRadius: 10)).foregroundStyle(.white) }.buttonStyle(.plain).disabled(requesting) }
            else if pushStatus == .denied { Button { if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) } } label: { Text("Settings").font(.system(size: 13, weight: .semibold)).padding(.horizontal, 14).padding(.vertical, 8).background(Color(.systemGray5), in: RoundedRectangle(cornerRadius: 10)).foregroundStyle(.primary) }.buttonStyle(.plain) }
        }.padding(14).background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }
    private func refreshPushStatus() async { let settings = await UNUserNotificationCenter.current().notificationSettings(); await MainActor.run { pushStatus = settings.authorizationStatus } }
    private func requestPushPermission() { requesting = true; Task { do { let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]); await MainActor.run { pushStatus = granted ? .authorized : .denied; if granted { UIApplication.shared.registerForRemoteNotifications() }; requesting = false } } catch { await MainActor.run { requesting = false } } } }
    private func loadReadAlerts() { let stored = UserDefaults.standard.array(forKey: Self.readAlertsKey) as? [Int] ?? []; readAlertIds = Set(stored) }
    private func markAsRead(_ id: Int) { guard !readAlertIds.contains(id) else { return }; readAlertIds.insert(id); UserDefaults.standard.set(Array(readAlertIds).sorted(), forKey: Self.readAlertsKey) }
}

struct AlertRow: View {
    let alert: APIService.MuniAlert; let isRead: Bool
    private var severityColor: Color { switch alert.severity { case "critical": return .red; case "warning": return .orange; default: return .teal } }
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            ZStack(alignment: .topTrailing) {
                Circle()
                    .fill(severityColor)
                    .frame(width: 48, height: 48)
                    .overlay {
                        Text(String(alert.tenantName.prefix(1)).uppercased())
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.white)
                    }

                if !isRead {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 13, height: 13)
                        .overlay(Circle().stroke(Color(.systemGroupedBackground), lineWidth: 2))
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(alert.title)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Spacer()
                    Text(alert.createdAt.relativeFormatted)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }

                Text(alert.body)
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                Text(alert.tenantName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(severityColor)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 12)
        .overlay(alignment: .bottom) {
            Divider().padding(.leading, 60)
        }
    }
}

struct MessageDetailView: View {
    let alert: APIService.MuniAlert
    private var severityColor: Color { switch alert.severity { case "critical": return .red; case "warning": return .orange; default: return .teal } }
    var body: some View {
        VStack(spacing: 16) {
            Text(alert.createdAt.relativeFormatted)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.top, 4)

            HStack(alignment: .bottom, spacing: 8) {
                Circle()
                    .fill(severityColor)
                    .frame(width: 32, height: 32)
                    .overlay {
                        Text(String(alert.tenantName.prefix(1)).uppercased())
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white)
                    }

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Circle().fill(severityColor).frame(width: 8, height: 8)
                        Text(alert.tenantName)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }

                    Text(alert.title)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.primary)

                    Text(alert.body)
                        .font(.system(size: 16))
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color(.systemGray5), in: UnevenRoundedRectangle(topLeadingRadius: 20, bottomLeadingRadius: 5, bottomTrailingRadius: 20, topTrailingRadius: 20))

                Spacer(minLength: 32)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
