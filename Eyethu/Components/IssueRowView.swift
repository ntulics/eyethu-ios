import SwiftUI

struct IssueRowView: View {
    let issue: Issue

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(iconBackground)
                    .frame(width: 56, height: 56)
                IssueTypeGlyph(type: issue.type, size: 26, color: iconColor)
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(issue.type.displayName)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(.primary)
                    Spacer()
                    StatusBadge(status: issue.status)
                }
                Text(issue.displayStreet)
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                HStack(spacing: 8) {
                    if let muni = issue.municipality {
                        Label(muni, systemImage: "mappin.circle")
                            .font(.system(size: 14))
                            .foregroundStyle(.tertiary)
                    }
                    if (issue.reportCount ?? 1) > 1 {
                        Label("\(issue.reportCount ?? 1) reports", systemImage: "person.2")
                            .font(.system(size: 14))
                            .foregroundStyle(.tertiary)
                    }
                    Spacer()
                    Text(issue.createdAt.relativeFormatted)
                        .font(.system(size: 14))
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.vertical, 18)
        .overlay(alignment: .bottom) {
            Divider().padding(.leading, 70)
        }
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
