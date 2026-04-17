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
    var openIssues:       [Issue] { issues.filter { $0.status == .open } }
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
        let labels = ["M", "T", "W", "T", "F", "S", "S"]
        let calendar = Calendar.current
        let today = Date()
        return labels.enumerated().map { index, label in
            let offset = index - 6
            let date = calendar.date(byAdding: .day, value: offset, to: today)!
            let count = issues.filter { calendar.isDate($0.createdAt, inSameDayAs: date) }.count
            return DailyCount(weekday: label, count: count, hasReport: offset <= 0 && count > 0)
        }
    }

    var typeBreakdown: [(IssueType, Int)] {
        IssueType.allCases.compactMap { type in
            let count = issues.filter { $0.type == type }.count
            return count > 0 ? (type, count) : nil
        }.sorted { $0.1 > $1.1 }
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
        imageURL: String? = nil
    ) async throws -> CreateIssueResult {
        let result = try await APIService.shared.createIssue(
            type: type,
            description: description,
            latitude: latitude,
            longitude: longitude,
            municipality: municipality,
            streetAddress: streetAddress,
            imageURL: imageURL
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
                  status: .open, source: "web", reportCount: 5,
                  createdAt: cal.date(byAdding: .hour, value: -2, to: now)!),
            Issue(id: 2, type: .waterLeak,
                  description: "Burst pipe flooding the sidewalk.",
                  latitude: -26.2051, longitude: 28.0483,
                  municipality: "City of Johannesburg", streetAddress: "12 Main Rd",
                  ward: "Ward 12", tenantId: 1,
                  status: .inProgress, source: "whatsapp", reportCount: 3,
                  createdAt: cal.date(byAdding: .day, value: -1, to: now)!),
            Issue(id: 3, type: .streetlight,
                  description: "Street light out for 3 days.",
                  latitude: -26.2031, longitude: 28.0463,
                  municipality: "City of Johannesburg", streetAddress: "45 Oak Ave",
                  ward: "Ward 13", tenantId: 1,
                  status: .resolved, source: "web", reportCount: 2,
                  createdAt: cal.date(byAdding: .day, value: -5, to: now)!),
            Issue(id: 4, type: .powerOutage,
                  description: "No electricity in the whole block.",
                  latitude: -26.2021, longitude: 28.0493,
                  municipality: "City of Johannesburg", streetAddress: "Bree St Block C",
                  ward: "Ward 12", tenantId: 1,
                  status: .inProgress, source: "whatsapp", reportCount: 12,
                  createdAt: cal.date(byAdding: .hour, value: -18, to: now)!),
            Issue(id: 5, type: .pothole,
                  description: "Multiple potholes along the stretch.",
                  latitude: -26.2011, longitude: 28.0503,
                  municipality: "City of Johannesburg", streetAddress: "N1 Freeway Offramp",
                  ward: "Ward 12", tenantId: 1,
                  status: .resolved, source: "web", reportCount: 9,
                  createdAt: cal.date(byAdding: .day, value: -10, to: now)!),
        ]
    }
}
