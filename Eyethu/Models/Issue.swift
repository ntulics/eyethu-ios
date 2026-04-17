import Foundation
import CoreLocation

// Only the 4 types the backend supports
enum IssueType: String, CaseIterable, Codable {
    case pothole       = "pothole"
    case waterLeak     = "water_leak"
    case powerOutage   = "power_outage"
    case streetlight   = "streetlight"

    var displayName: String {
        switch self {
        case .pothole:     return "Pothole"
        case .waterLeak:   return "Water Leak"
        case .powerOutage: return "Power Outage"
        case .streetlight: return "Streetlight"
        }
    }

    var icon: String {
        switch self {
        case .pothole:     return "road.lanes"
        case .waterLeak:   return "drop.fill"
        case .powerOutage: return "bolt.slash.fill"
        case .streetlight: return "lightbulb.slash.fill"
        }
    }
}

enum IssueStatus: String, CaseIterable, Codable {
    case open       = "open"
    case inProgress = "in_progress"
    case resolved   = "resolved"

    var displayName: String {
        switch self {
        case .open:       return "Open"
        case .inProgress: return "In Progress"
        case .resolved:   return "Resolved"
        }
    }
}

struct Issue: Identifiable, Codable {
    let id: Int
    let type: IssueType
    let description: String?
    let latitude: Double?
    let longitude: Double?
    let municipality: String?
    let streetAddress: String?
    let ward: String?
    let tenantId: Int?
    let status: IssueStatus
    let source: String
    let reportCount: Int
    let imageURL: String?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, type, description, latitude, longitude, municipality, ward, status, source
        case streetAddress = "street_address"
        case tenantId      = "tenant_id"
        case reportCount   = "report_count"
        case imageURL      = "image_url"
        case createdAt     = "created_at"
    }

    var coordinate: CLLocationCoordinate2D? {
        guard let lat = latitude, let lon = longitude else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    var isActive: Bool { status != .resolved }
    var displayAddress: String { streetAddress ?? municipality ?? "Unknown location" }
}

// Response shape when POST /api/issues detects a duplicate
struct DuplicateIssueResponse: Codable {
    let duplicate: Bool
    let existingId: Int
    let reportCount: Int
    let alreadyCounted: Bool

    enum CodingKeys: String, CodingKey {
        case duplicate
        case existingId    = "existing_id"
        case reportCount   = "report_count"
        case alreadyCounted = "already_counted"
    }
}

struct CreateIssueResult {
    enum Value {
        case created(Issue)
        case duplicate(DuplicateIssueResponse)
    }
    let value: Value
}

struct DailyCount: Identifiable {
    let id = UUID()
    let weekday: String
    let count: Int
    let hasReport: Bool
}
