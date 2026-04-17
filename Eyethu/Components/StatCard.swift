import SwiftUI

struct StatCard<Content: View>: View {
    let title: String
    let subtitle: String
    let onTap: (() -> Void)?
    @ViewBuilder let content: () -> Content

    init(
        title: String,
        subtitle: String,
        onTap: (() -> Void)? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.onTap = onTap
        self.content = content
    }

    var body: some View {
        Button { onTap?() } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.primary)
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    Spacer()
                    if onTap != nil {
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                content()
            }
            .padding(14)
            .background(.background, in: RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
        }
        .buttonStyle(.plain)
    }
}

struct ActivityBars: View {
    let days: [DailyCount]
    let accentColor: Color

    var body: some View {
        HStack(alignment: .bottom, spacing: 6) {
            ForEach(days) { day in
                VStack(spacing: 3) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(day.hasReport ? accentColor : accentColor.opacity(0.2))
                        .frame(width: 18, height: day.hasReport ? CGFloat(14 + day.count * 4) : 14)
                        .animation(.easeInOut, value: day.count)
                    Text(day.weekday)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

struct StatusBadge: View {
    let status: IssueStatus

    var body: some View {
        Text(status.displayName)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(badgeColor.opacity(0.15), in: Capsule())
            .foregroundStyle(badgeColor)
    }

    private var badgeColor: Color {
        switch status {
        case .open:       return .orange
        case .inProgress: return .blue
        case .resolved:   return .green
        }
    }
}

struct IssueTypeTag: View {
    let type: IssueType

    var body: some View {
        HStack(spacing: 4) {
            IssueTypeGlyph(type: type, size: 11, color: .secondary)
            Text(type.displayName)
        }
            .font(.caption2.weight(.medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Color.secondary.opacity(0.12), in: Capsule())
            .foregroundStyle(.secondary)
    }
}
