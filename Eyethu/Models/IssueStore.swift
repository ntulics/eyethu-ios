import Foundation
import Combine

@MainActor
class IssueStore: ObservableObject {
    @Published var issues: [Issue] = []
    @Published var isLoading = false
    @Published var error: String? = nil
    @Published var currentUser: SessionUser? = nil

    var activeIssues:     [Issue] { issues.filter { $0.isActive } }
    var resolvedIssues:   [Issue] { issues.filter { !$0.isActive } }
    var openIssues:       [Issue] { issues.filter { $0.status == .open || $0.status == .assigned } }
    var inProgressIssues: [Issue] { issues.filter { $0.status == .inProgress } }

    var lastReportDate: Date? { issues.map(\.createdAt).max() }

    var resolutionRate: Double {
        guard !issues.isEmpty else { return 0 }
        return Double(resolvedIssues.count) / Double(issues.count)
    }
    var activeRate: Double {
        guard !issues.isEmpty else { return 0 }
        return Double(activeIssues.count) / Double(issues.count)
    }
    var inProgressRate: Double {
        guard !issues.isEmpty else { return 0 }
        return Double(inProgressIssues.count) / Double(issues.count)
    }

    var weeklyActivity: [DailyCount] {
        var calendar = Calendar.current
        calendar.firstWeekday = 2 // Monday

        let today = Date()
        let weekInterval = calendar.dateInterval(of: .weekOfYear, for: today)
        let startOfWeek = weekInterval?.start ?? today
        let dayLetters = ["M", "T", "W", "T", "F", "S", "S"]

        return (0..<7).map { index in
            let date = calendar.date(byAdding: .day, value: index, to: startOfWeek) ?? today
            let dayIssues = issues.filter { calendar.isDate($0.createdAt, inSameDayAs: date) }
            return DailyCount(
                weekday:    dayLetters[index],
                open:       dayIssues.filter { $0.status == .open || $0.status == .assigned }.count,
                inProgress: dayIssues.filter { $0.status == .inProgress }.count,
                resolved:   dayIssues.filter { $0.status == .resolved   }.count
            )
        }
    }

    struct MuniStat: Identifiable {
        let id = UUID()
        let name: String
        let total: Int
        let open: Int
        let resolved: Int
    }

    struct TypeStat: Identifiable {
        let id: IssueType
        let type: IssueType
        let total: Int
        let active: Int
        let resolved: Int
    }

    var municipalityLeaderboard: [MuniStat] {
        var counts: [String: (total: Int, open: Int, resolved: Int)] = [:]
        for issue in issues {
            guard let muni = issue.municipality, !muni.trimmingCharacters(in: .whitespaces).isEmpty else { continue }
            let c = counts[muni] ?? (0, 0, 0)
            counts[muni] = (
                total:    c.total + 1,
                open:     c.open + ((issue.status == .open || issue.status == .assigned) ? 1 : 0),
                resolved: c.resolved + (issue.status == .resolved ? 1 : 0)
            )
        }
        return counts
            .map { MuniStat(name: $0.key, total: $0.value.total, open: $0.value.open, resolved: $0.value.resolved) }
            .sorted { $0.total > $1.total }
            .prefix(8)
            .map { $0 }
    }

    var typeLeaderboard: [TypeStat] {
        IssueType.allCases.compactMap { type in
            let matchingIssues = issues.filter { $0.type == type }
            guard !matchingIssues.isEmpty else { return nil }
            let resolved = matchingIssues.filter { $0.status == .resolved }.count
            let active = matchingIssues.count - resolved
            return TypeStat(
                id: type,
                type: type,
                total: matchingIssues.count,
                active: active,
                resolved: resolved
            )
        }
        .sorted { lhs, rhs in
            if lhs.total == rhs.total {
                return lhs.type.displayName < rhs.type.displayName
            }
            return lhs.total > rhs.total
        }
    }

    var typeBreakdown: [(IssueType, Int)] {
        typeLeaderboard.map { ($0.type, $0.total) }
    }

    // MARK: - Fetch

    func loadIssues(status: IssueStatus? = nil, type: IssueType? = nil) async {
        isLoading = true
        error = nil
        do {
            issues = try await APIService.shared.fetchIssues(status: status, type: type)
        } catch APIError.networkError {
            // Offline — fall back to mock data so the UI still works
            if issues.isEmpty { loadMockData() }
            error = "Offline — showing cached data."
        } catch {
            if issues.isEmpty { loadMockData() }
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func refreshIssue(id: Int) async {
        guard let index = issues.firstIndex(where: { $0.id == id }) else { return }
        do {
            issues[index] = try await APIService.shared.fetchIssue(id: id)
        } catch {}
    }

    func createIssue(
        type: IssueType,
        description: String?,
        latitude: Double?,
        longitude: Double?,
        municipality: String?,
        streetAddress: String?,
        imageURL: String? = nil,
        imageURLs: [String] = []
    ) async throws -> CreateIssueResult {
        let result = try await APIService.shared.createIssue(
            type: type,
            description: description,
            latitude: latitude,
            longitude: longitude,
            municipality: municipality,
            streetAddress: streetAddress,
            imageURL: imageURL,
            imageURLs: imageURLs
        )
        // Refresh the list so the new issue appears immediately
        await loadIssues()
        return result
    }

    func updateStatus(issue: Issue, status: IssueStatus) async throws {
        let updated = try await APIService.shared.updateIssueStatus(id: issue.id, status: status)
        if let index = issues.firstIndex(where: { $0.id == issue.id }) {
            issues[index] = updated
        }
    }

    func vote(issue: Issue, type: String) async throws {
        let updated = try await APIService.shared.voteOnIssue(id: issue.id, vote: type)
        if let index = issues.firstIndex(where: { $0.id == issue.id }) {
            issues[index] = updated
        }
    }

    // MARK: - Auth

    func signIn(email: String, password: String) async throws -> Bool {
        let result = try await APIService.shared.signIn(email: email, password: password)
        if result.ok {
            currentUser = try await APIService.shared.fetchSession()
        }
        return result.ok
    }

    func signOut() async throws {
        try await APIService.shared.signOut()
        currentUser = nil
    }

    func restoreSession() async {
        currentUser = try? await APIService.shared.fetchSession()
    }

    // MARK: - Mock fallback (used when offline)

    private func loadMockData() {
        let cal = Calendar.current
        let now = Date()
        issues = [
            Issue(id: 1, type: .pothole,
                  description: "Large pothole in center of intersection.",
                  latitude: -26.2041, longitude: 28.0473,
                  municipality: "City of Johannesburg", streetAddress: "700-748 SE Monroe St",
                  ward: "Ward 12", tenantId: 1,
                  status: .open, source: "web", reportCount: 5, disagreeCount: 0, imageURL: nil, emailStatus: nil, emailRawStatus: nil, emailError: nil, emailSentAt: nil,
                  createdAt: cal.date(byAdding: .hour, value: -2, to: now)!, photos: nil),
            Issue(id: 2, type: .waterLeak,
                  description: "Burst pipe flooding the sidewalk.",
                  latitude: -26.2051, longitude: 28.0483,
                  municipality: "City of Johannesburg", streetAddress: "12 Main Rd",
                  ward: "Ward 12", tenantId: 1,
                  status: .inProgress, source: "whatsapp", reportCount: 3, disagreeCount: 1, imageURL: nil, emailStatus: .delivered, emailRawStatus: "delivered", emailError: nil, emailSentAt: cal.date(byAdding: .hour, value: -20, to: now),
                  createdAt: cal.date(byAdding: .day, value: -1, to: now)!, photos: nil),
            Issue(id: 3, type: .streetlight,
                  description: "Street light out for 3 days.",
                  latitude: -26.2031, longitude: 28.0463,
                  municipality: "City of Johannesburg", streetAddress: "45 Oak Ave",
                  ward: "Ward 13", tenantId: 1,
                  status: .resolved, source: "web", reportCount: 2, disagreeCount: 0, imageURL: nil, emailStatus: .opened, emailRawStatus: "opened", emailError: nil, emailSentAt: cal.date(byAdding: .day, value: -4, to: now),
                  createdAt: cal.date(byAdding: .day, value: -5, to: now)!, photos: nil),
            Issue(id: 4, type: .powerOutage,
                  description: "No electricity in the whole block.",
                  latitude: -26.2021, longitude: 28.0493,
                  municipality: "City of Johannesburg", streetAddress: "Bree St Block C",
                  ward: "Ward 12", tenantId: 1,
                  status: .assigned, source: "whatsapp", reportCount: 12, disagreeCount: 2, imageURL: nil, emailStatus: .sent, emailRawStatus: "sent", emailError: nil, emailSentAt: cal.date(byAdding: .hour, value: -16, to: now),
                  createdAt: cal.date(byAdding: .hour, value: -18, to: now)!, photos: nil),
            Issue(id: 5, type: .pothole,
                  description: "Multiple potholes along the stretch.",
                  latitude: -26.2011, longitude: 28.0503,
                  municipality: "City of Johannesburg", streetAddress: "N1 Freeway Offramp",
                  ward: "Ward 12", tenantId: 1,
                  status: .resolved, source: "web", reportCount: 9, disagreeCount: 0, imageURL: nil, emailStatus: .opened, emailRawStatus: "clicked", emailError: nil, emailSentAt: cal.date(byAdding: .day, value: -9, to: now),
                  createdAt: cal.date(byAdding: .day, value: -10, to: now)!, photos: nil),
        ]
    }
}
