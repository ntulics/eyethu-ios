import SwiftUI

struct IssueRowView: View {
    let issue: Issue

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(iconBackground)
                    .frame(width: 44, height: 44)
                IssueTypeGlyph(type: issue.type, size: 18, color: iconColor)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(issue.type.displayName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.primary)
                    Spacer()
                    StatusBadge(status: issue.status)
                }
                Text(issue.displayStreet)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                HStack(spacing: 8) {
                    if let muni = issue.municipality {
                        Label(muni, systemImage: "mappin.circle")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    if issue.reportCount > 1 {
                        Label("\(issue.reportCount) reports", systemImage: "person.2")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    Spacer()
                    Text(issue.createdAt.relativeFormatted)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var iconBackground: Color { issue.type.color.opacity(0.12) }
    private var iconColor: Color      { issue.type.color }
}

extension Date {
    var relativeFormatted: String {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f.localizedString(for: self, relativeTo: Date())
    }
    var shortFormatted: String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f.string(from: self)
    }
}
