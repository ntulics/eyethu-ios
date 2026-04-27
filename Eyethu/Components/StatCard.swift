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
    let badge: String?
    let onTap: (() -> Void)?
    @ViewBuilder let content: () -> Content

    init(
        title: String,
        subtitle: String,
        badge: String? = nil,
        onTap: (() -> Void)? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.badge = badge
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
                    if let badge = badge {
                        Text(badge)
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundStyle(.teal)
                    }
                }
                content()
            }
            .padding(14)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.08), radius: 8, y: 2)
        }
        .buttonStyle(.plain)
    }
}

private let brandOrange = Color(hex: "#FF6B35")
private let compactTrackHeight: CGFloat = 44
private let compactBarWidth: CGFloat = 8
private let trackHeight: CGFloat = 50
private let barWidth: CGFloat = 9

struct ActiveReportsCard: View {
    let title: String
    let subtitle: String
    let count: Int
    let accentColor: Color
    let lastDate: Date?
    let days: [DailyCount]
    let openCount: Int
    let inProgressCount: Int
    let resolvedCount: Int
    let onTap: (() -> Void)?

    var body: some View {
        Button { onTap?() } label: {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(.primary)
                        Text(subtitle)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(.secondary)
                        .padding(.top, 2)
                }

                HStack(alignment: .bottom, spacing: 8) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(count)")
                            .font(.system(size: 44, weight: .black, design: .rounded))
                            .foregroundStyle(accentColor)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                        if let lastDate {
                            Text("Last: \(lastDate.relativeFormatted)")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(accentColor)
                        }
                    }
                    .frame(width: 92, alignment: .leading)

                    MiniWeeklyBars(days: days, accentColor: accentColor)
                        .frame(maxWidth: .infinity, alignment: .bottom)
                }
                .padding(.top, 14)

                Divider()
                    .padding(.top, 14)

                HStack {
                    FlatLegendItem(color: brandOrange, text: "\(openCount) OPEN")
                    Spacer()
                    FlatLegendItem(color: .teal, text: "\(inProgressCount) IN PROGRESS")
                    Spacer()
                    FlatLegendItem(color: .green, text: "\(resolvedCount) RESOLVED")
                }
                .padding(.top, 12)
            }
            .padding(16)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
            .shadow(color: .black.opacity(0.08), radius: 10, y: 3)
        }
        .buttonStyle(.plain)
    }
}

struct ActivityBars: View {
    let days: [DailyCount]
    var lastDate: Date? = nil

    private var maxCount: Int {
        days.flatMap { [$0.open, $0.inProgress, $0.resolved] }.max().map { max($0, 1) } ?? 1
    }

    private func h(_ count: Int) -> CGFloat {
        guard count > 0 else { return 0 }
        return max(3, CGFloat(count) / CGFloat(maxCount) * trackHeight)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let date = lastDate {
                Text("Last: \(date.relativeFormatted)")
                    .font(.caption2)
                    .foregroundStyle(.teal.opacity(0.8))
            }
            HStack(alignment: .bottom, spacing: 0) {
                ForEach(days) { day in
                    VStack(spacing: 3) {
                        HStack(alignment: .bottom, spacing: 1) {
                            TrackBar(height: h(day.open),       color: brandOrange)
                            TrackBar(height: h(day.inProgress), color: .teal)
                            TrackBar(height: h(day.resolved),   color: .green)
                        }
                        Text(day.weekday)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(maxWidth: .infinity)

            HStack(spacing: 10) {
                LegendDot(color: brandOrange, label: "Open")
                LegendDot(color: .teal,       label: "In Progress")
                LegendDot(color: .green,      label: "Resolved")
            }
        }
        .frame(maxWidth: .infinity)
    }
}

private struct MiniWeeklyBars: View {
    let days: [DailyCount]
    let accentColor: Color

    private var maxCount: Int {
        days.flatMap { [$0.open, $0.inProgress, $0.resolved] }.max().map { max($0, 1) } ?? 1
    }

    private func barHeight(_ count: Int) -> CGFloat {
        guard count > 0 else { return 4 }
        let pct = CGFloat(count) / CGFloat(maxCount)
        let eased = pow(pct, 1.35)
        return 4 + (eased * 30)
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            ForEach(Array(days.enumerated()), id: \.element.id) { index, day in
                VStack(spacing: 3) {
                    HStack(alignment: .bottom, spacing: 3) {
                        MiniBar(height: barHeight(day.open), color: brandOrange)
                        MiniBar(height: barHeight(day.inProgress), color: .teal)
                        MiniBar(height: barHeight(day.resolved), color: .green)
                    }
                    Text(day.weekday)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(index == days.count - 1 ? accentColor : .secondary)
                }
                .frame(maxWidth: .infinity, alignment: .bottom)
            }
        }
        .frame(maxWidth: .infinity, alignment: .bottom)
        .padding(.bottom, 2)
    }
}

private struct MiniBar: View {
    let height: CGFloat
    let color: Color

    var body: some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(color)
            .frame(width: compactBarWidth, height: height)
            .animation(.easeInOut(duration: 0.45), value: height)
    }
}

private struct FlatLegendItem: View {
    let color: Color
    let text: String

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(text)
                .font(.system(size: 10, weight: .semibold))
                .tracking(0.6)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }
}

private struct TrackBar: View {
    let height: CGFloat
    let color: Color

    var body: some View {
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.secondary.opacity(0.12))
                .frame(width: barWidth, height: trackHeight)
            if height > 0 {
                RoundedRectangle(cornerRadius: 3)
                    .fill(color)
                    .frame(width: barWidth, height: height)
                    .animation(.easeInOut, value: height)
            }
        }
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
