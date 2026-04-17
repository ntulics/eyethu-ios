import Foundation
import CoreLocation
import SwiftUI

enum IssueType: String, CaseIterable, Codable {
    case pothole        = "pothole"
    case waterLeak      = "water_leak"
    case powerOutage    = "power_outage"
    case streetlight    = "streetlight"
    case illegalDumping = "illegal_dumping"
    case trafficLights  = "traffic_lights"

    var displayName: String {
        switch self {
        case .pothole:        return "Pothole"
        case .waterLeak:      return "Water Leak"
        case .powerOutage:    return "Power Outage"
        case .streetlight:    return "Streetlight"
        case .illegalDumping: return "Illegal Dumping"
        case .trafficLights:  return "Traffic Lights"
        }
    }

    // SF Symbol — matches the spirit of the web app emoji icons
    var icon: String {
        switch self {
        case .pothole:        return "triangle.fill"
        case .waterLeak:      return "drop.fill"
        case .powerOutage:    return "bolt.fill"
        case .streetlight:    return "lightbulb.fill"
        case .illegalDumping: return "trash.fill"
        case .trafficLights:  return "car.2.fill"
        }
    }

    // Exact hex colours from the web app (lib/types.ts ISSUE_COLORS)
    var color: Color {
        switch self {
        case .pothole:        return Color(hex: "#FF4444")
        case .waterLeak:      return Color(hex: "#3B82F6")
        case .powerOutage:    return Color(hex: "#FFB612")
        case .streetlight:    return Color(hex: "#F97316")
        case .illegalDumping: return Color(hex: "#22C55E")
        case .trafficLights:  return Color(hex: "#A855F7")
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

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >>  8) & 0xFF) / 255
        let b = Double( int        & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
