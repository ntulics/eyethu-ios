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
        // SVGs include internal padding, so render at 1.5× to match SF Symbol visual weight
        let visualSize = size * 1.5
        Image(type.imageName)
            .resizable()
            .renderingMode(.original)
            .scaledToFit()
            .frame(width: visualSize, height: visualSize)
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

private let brandOrange = Color(hex: "#FF6B35")

struct ActivityBars: View {
    let days: [DailyCount]

    private let minHeight: CGFloat = 4
    private let unitHeight: CGFloat = 6

    private func barHeight(for count: Int) -> CGFloat {
        guard count > 0 else { return 0 }
        return max(CGFloat(count) * unitHeight, minHeight)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .bottom, spacing: 0) {
                ForEach(days) { day in
                    let total = day.open + day.inProgress + day.resolved
                    VStack(spacing: 3) {
                        if total == 0 {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.secondary.opacity(0.15))
                                .frame(height: minHeight)
                        } else {
                            VStack(spacing: 1) {
                                if day.resolved > 0 {
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(Color.green)
                                        .frame(height: barHeight(for: day.resolved))
                                }
                                if day.inProgress > 0 {
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(Color.teal)
                                        .frame(height: barHeight(for: day.inProgress))
                                }
                                if day.open > 0 {
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(brandOrange)
                                        .frame(height: barHeight(for: day.open))
                                }
                            }
                            .animation(.easeInOut, value: total)
                        }
                        Text(day.weekday)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }

            HStack(spacing: 16) {
                LegendDot(color: brandOrange, label: "Open")
                LegendDot(color: .teal,       label: "In Progress")
                LegendDot(color: .green,      label: "Resolved")
            }
        }
        .frame(maxWidth: .infinity)
    }
}

private struct LegendDot: View {
    let color: Color
    let label: String

    var body: some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(label)
                .font(.system(size: 10, weight: .medium))
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
