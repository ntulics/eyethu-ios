import SwiftUI

struct HomeView: View {
    @EnvironmentObject var store: IssueStore
    @State private var showLogin = false
    @State private var currentAreaName = "Near you"
    @State private var showActiveIssues = false

    private var dateHeader: String {
        let f = DateFormatter()
        f.dateFormat = "EEEE, d MMM"
        return f.string(from: Date())
    }

    private var userInitials: String {
        if let user = store.currentUser {
            let parts = user.name.split(separator: " ").prefix(2)
            let initials = parts.compactMap { $0.first }.map(String.init).joined()
            if !initials.isEmpty { return initials.uppercased() }
        }
        return "EY"
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
            .toolbar(.hidden, for: .navigationBar)
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
            .navigationDestination(isPresented: $showActiveIssues) {
                IssueListView(entryFilter: .active)
            }
            .task {
                await store.loadIssues()
                await loadCurrentArea()
            }
            .refreshable {
                await store.loadIssues()
                await loadCurrentArea()
            }
        }
    }

    private var scrollContent: some View {
        ZStack(alignment: .top) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Color.clear
                        .frame(height: 72)

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

                    // Active Reports — full-width card with last-report time
                    StatCard(title: "Active Reports", subtitle: currentAreaName, onTap: {
                        showActiveIssues = true
                    }) {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Spacer()
                                ActivityLegend()
                            }

                            HStack(alignment: .bottom, spacing: 16) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("\(store.activeIssues.count)")
                                        .font(.system(size: 40, weight: .bold, design: .rounded))
                                        .foregroundStyle(.teal)
                                    if let date = store.lastReportDate {
                                        Text("Last: \(date.relativeFormatted)")
                                            .font(.caption2)
                                            .foregroundStyle(.teal.opacity(0.8))
                                    }
                                }
                                Spacer()
                                ActivityBars(days: store.weeklyActivity)
                            }
                        }
                    }
                    .padding(.horizontal, 20)

                    // Status breakdown
                    HStack(spacing: 12) {
                        StatusCountCard(label: "Open", count: store.openIssues.count, color: .orange, icon: "circle.fill")
                        StatusCountCard(label: "In Progress", count: store.inProgressIssues.count, color: .teal, icon: "arrow.triangle.2.circlepath.circle.fill")
                        StatusCountCard(label: "Resolved", count: store.resolvedIssues.count, color: .green, icon: "checkmark.circle.fill")
                    }
                    .padding(.horizontal, 20)

                    // National overview
                    NationalStatsCard(store: store)
                        .padding(.horizontal, 20)

                    // Municipal Leaderboard
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
                        .background(.background, in: RoundedRectangle(cornerRadius: 20))
                        .shadow(color: .black.opacity(0.06), radius: 10, y: 3)
                        .padding(.horizontal, 20)
                    }

                    // Categories
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
                                NavigationLink(destination: IssueListView(prefillType: stat.type)) {
                                    CategoryLeaderboardRow(stat: stat)
                                }
                                .buttonStyle(.plain)
                                
                                if stat.id != store.typeLeaderboard.last?.id {
                                    Divider().padding(.horizontal, 16)
                                }
                            }
                            .padding(.bottom, 8)
                        }
                        .background(.background, in: RoundedRectangle(cornerRadius: 20))
                        .shadow(color: .black.opacity(0.06), radius: 10, y: 3)
                        .padding(.horizontal, 20)
                    }

                    // Recent issues (3 max)
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
                    .background(.background, in: RoundedRectangle(cornerRadius: 20))
                    .shadow(color: .black.opacity(0.06), radius: 10, y: 3)
                    .padding(.horizontal, 20)

                    Spacer(minLength: 20)
                }
            }

            topHeader
                .padding(.top, 8)
                .frame(maxWidth: .infinity)
                .zIndex(1)
        }
    }

    private var topHeader: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("eyethu")
                    .font(.system(size: 27, weight: .bold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                Text(dateHeader)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(spacing: 12) {
                Button {
                    if store.currentUser == nil {
                        showLogin = true
                    }
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color.teal.opacity(0.12))
                            .frame(width: 34, height: 34)

                        if store.currentUser != nil {
                            Text(userInitials)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.teal)
                        } else {
                            Image(systemName: "person.circle")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundStyle(.teal)
                        }
                    }
                }
                .buttonStyle(.plain)

                Button {
                    Task { await store.loadIssues() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 19, weight: .medium))
                        .foregroundStyle(.teal)
                        .frame(width: 34, height: 34)
                }
                .buttonStyle(.plain)
                .disabled(store.isLoading)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(Color(.secondarySystemBackground).opacity(0.9))
            )
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
        }
        .padding(.horizontal, 20)
        .background(Color.clear)
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
            // Stacked bar: red = open issues, green = resolved
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

// MARK: - National Stats Card

struct NationalStatsCard: View {
    let store: IssueStore

    private var topType: IssueType? { store.typeBreakdown.first?.0 }
    private var activeMunis: Int { store.municipalityLeaderboard.count }
    private var resolutionPct: Int { Int((store.resolutionRate * 100).rounded()) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "flag.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 26, height: 26)
                        .background(Color(hex: "#007A4D"), in: RoundedRectangle(cornerRadius: 7))
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

            // Stats row
            HStack(spacing: 0) {
                NationalStatItem(
                    value: "\(store.issues.count)",
                    label: "Total Issues",
                    icon: "exclamationmark.bubble.fill",
                    color: .orange
                )
                Divider().frame(height: 44)
                NationalStatItem(
                    value: "\(resolutionPct)%",
                    label: "Resolved",
                    icon: "checkmark.seal.fill",
                    color: .green
                )
                Divider().frame(height: 44)
                NationalStatItem(
                    value: "\(activeMunis)",
                    label: "Municipalities",
                    icon: "building.2.fill",
                    color: .teal
                )
                if let top = topType {
                    Divider().frame(height: 44)
                    NationalStatItem(
                        value: top.displayName,
                        label: "Top Issue",
                        icon: top.icon,
                        color: top.color
                    )
                }
            }
            .padding(.vertical, 12)
        }
        .background(.background, in: RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.06), radius: 10, y: 3)
    }
}

struct NationalStatItem: View {
    let value: String
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(color)
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
    }
}

// MARK: - Status Count Card

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
