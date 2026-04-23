import SwiftUI

struct IssueTypeGlyph: View {
    let type: IssueType
    let size: CGFloat
    let weight: Font.Weight
    let color: Color

    init(type: IssueType, size: CGFloat, weight: Font.Weight = .medium, color: Color) {
        self.type = type
        self.size = size
        self.weight = weight
        self.color = color
    }

    var body: some View {
        Image(systemName: type.icon)
            .font(.system(size: size, weight: weight))
            .foregroundStyle(color)
    }
}

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

    private var maxCount: Int {
        max(
            days.flatMap { [$0.openCount, $0.inProgressCount, $0.resolvedCount] }.max() ?? 0,
            1
        )
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 6) {
            ForEach(days) { day in
                VStack(spacing: 4) {
                    HStack(alignment: .bottom, spacing: 2) {
                        ActivityBarSegment(count: day.openCount, maxCount: maxCount, color: .orange)
                        ActivityBarSegment(count: day.inProgressCount, maxCount: maxCount, color: .teal)
                        ActivityBarSegment(count: day.resolvedCount, maxCount: maxCount, color: .green)
                    }
                    .frame(height: 46)

                    Text(day.weekday)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

struct ActivityLegend: View {
    var body: some View {
        HStack(spacing: 10) {
            ActivityLegendItem(label: "Open", color: .orange)
            ActivityLegendItem(label: "In Progress", color: .teal)
            ActivityLegendItem(label: "Resolved", color: .green)
        }
    }
}

private struct ActivityBarSegment: View {
    let count: Int
    let maxCount: Int
    let color: Color

    private var height: CGFloat {
        guard count > 0 else { return 8 }
        return 8 + (CGFloat(count) / CGFloat(maxCount)) * 38
    }

    var body: some View {
        RoundedRectangle(cornerRadius: 2.5)
            .fill(count > 0 ? color : color.opacity(0.18))
            .frame(width: 5, height: height)
            .animation(.easeInOut(duration: 0.2), value: count)
    }
}

private struct ActivityLegendItem: View {
    let label: String
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 5, height: 5)
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.secondary)
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
