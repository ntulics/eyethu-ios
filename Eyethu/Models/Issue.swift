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

    var icon: String {
        switch self {
        case .pothole:        return "exclamationmark.triangle.fill"
        case .waterLeak:      return "drop.fill"
        case .powerOutage:    return "bolt.fill"
        case .streetlight:    return "lightbulb.fill"
        case .illegalDumping: return "trash.fill"
        case .trafficLights:  return "car.2.fill"
        }
    }

    var imageName: String {
        switch self {
        case .pothole:        return "icon-pothole"
        case .waterLeak:      return "icon-water-leak"
        case .powerOutage:    return "icon-power-outage"
        case .streetlight:    return "icon-streetlight"
        case .illegalDumping: return "icon-illegal-dumping"
        case .trafficLights:  return "icon-traffic-lights"
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
    case assigned   = "assigned"
    case inProgress = "in_progress"
    case resolved   = "resolved"

    var displayName: String {
        switch self {
        case .open:       return "Open"
        case .assigned:   return "Assigned"
        case .inProgress: return "In Progress"
        case .resolved:   return "Resolved"
        }
    }
}

enum EmailDeliveryStatus: String, Codable {
    case pending
    case sent
    case delivered
    case opened

    var displayName: String {
        switch self {
        case .pending:   return "Pending"
        case .sent:      return "Sent"
        case .delivered: return "Delivered"
        case .opened:    return "Opened"
        }
    }
}

// Photo attached to an issue (from issue_photos table, max 5 per issue)
struct IssuePhoto: Identifiable, Codable {
    let id: Int
    let issueId: Int
    let url: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case issueId   = "issue_id"
        case url
        case createdAt = "created_at"
    }
}

struct ReportLocation: Codable, Hashable {
    let lat: Double
    let lon: Double

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: lat, longitude: lon)
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
    let source: String?
    let reportCount: Int?
    let disagreeCount: Int?
    let imageURL: String?
    let emailStatus: EmailDeliveryStatus?
    let emailRawStatus: String?
    let emailError: String?
    let emailSentAt: Date?
    let createdAt: Date
    // Populated by GET /api/issues/[id] (not present in list responses)
    let photos: [IssuePhoto]?
    let reportLocations: [ReportLocation]?

    enum CodingKeys: String, CodingKey {
        case id, type, description, latitude, longitude, municipality, ward, status, source, photos
        case streetAddress = "street_address"
        case tenantId      = "tenant_id"
        case reportCount   = "report_count"
        case disagreeCount = "disagree_count"
        case imageURL      = "image_url"
        case emailStatus   = "email_status"
        case emailRawStatus = "email_raw_status"
        case emailError    = "email_error"
        case emailSentAt   = "email_sent_at"
        case createdAt     = "created_at"
        case reportLocations = "report_locations"
    }

    var coordinate: CLLocationCoordinate2D? {
        guard let lat = latitude, let lon = longitude else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    var isActive: Bool { status != .resolved }
    var displayAddress: String { streetAddress ?? municipality ?? "Unknown location" }

    /// Street name without the house number — e.g. "Henry Fagan Street" not "20 Henry Fagan Street"
    var displayStreet: String {
        guard let addr = streetAddress else { return municipality ?? "Unknown location" }
        // Strip a leading house number: "20 Henry Fagan St" → "Henry Fagan St"
        let stripped = addr.replacingOccurrences(
            of: #"^\d+[\w-]*\s+"#,
            with: "",
            options: .regularExpression
        ).trimmingCharacters(in: .whitespaces)
        return stripped.isEmpty ? addr : stripped
    }
}

// Response shape when POST /api/issues detects a duplicate
struct DuplicateIssueResponse: Codable {
    let duplicate: Bool
    let existingId: Int
    let reportCount: Int?
    let alreadyCounted: Bool?

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
    let open: Int
    let inProgress: Int
    let resolved: Int

    var count: Int { open + inProgress + resolved }
    var hasReport: Bool { count > 0 }
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
