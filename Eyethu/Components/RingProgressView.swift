import SwiftUI

struct RingProgressView: View {
    let progress: Double
    let color: Color
    let trackColor: Color
    let lineWidth: CGFloat
    let icon: String
    let label: String
    let valueText: String

    init(
        progress: Double,
        color: Color,
        trackColor: Color? = nil,
        lineWidth: CGFloat = 10,
        icon: String,
        label: String,
        valueText: String? = nil
    ) {
        self.progress = min(max(progress, 0), 1)
        self.color = color
        self.trackColor = trackColor ?? color.opacity(0.15)
        self.lineWidth = lineWidth
        self.icon = icon
        self.label = label
        self.valueText = valueText ?? "\(Int(progress * 100))%"
    }

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .stroke(trackColor, lineWidth: lineWidth)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 1.0), value: progress)

                VStack(spacing: 2) {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(color)
                    Text(valueText)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                }
            }
            .frame(width: 80, height: 80)

            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

struct SmallRingView: View {
    let progress: Double
    let color: Color
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.15), lineWidth: 4)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(color, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.8), value: progress)
        }
        .frame(width: size, height: size)
    }
}
