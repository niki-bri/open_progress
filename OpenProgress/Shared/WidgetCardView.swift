import SwiftUI

enum ProgressWidgetMetrics {
    static let mediumAspectRatio: CGFloat = 338.0 / 158.0
    static let cardCornerRadius: CGFloat = 34
    static let dashboardCornerRadius: CGFloat = 30
    static let dashboardLargeTileCornerRadius: CGFloat = 24
    static let dashboardSmallTileCornerRadius: CGFloat = 22
}

struct WidgetCardView: View {
    let item: ProgressItem
    let date: Date
    var compact = false

    private var tint: Color { Color(hex: item.tintHex) }
    private var background: Color { Color(hex: item.backgroundHex) }
    private var progress: Double { item.progress(at: date) }

    var body: some View {
        ZStack {
            background
            switch item.style {
            case .aqua:
                ringCard
            case .grid:
                blockGrid
            case .glow:
                glowPanel
            case .retro:
                iconBar
            }
        }
        .containerBackground(background, for: .widget)
    }

    private var header: some View {
        HStack(spacing: 8) {
            if item.showIcon {
                Image(systemName: item.icon)
                    .font(.system(size: compact ? 14 : 17, weight: .semibold))
                    .foregroundStyle(tint)
            }

            Text(item.title)
                .font(.system(size: compact ? 13 : 16, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            Spacer(minLength: 0)
        }
    }

    private var percentageText: some View {
        Text(progress.formatted(.percent.precision(.fractionLength(0))))
            .font(.system(size: compact ? 23 : 34, weight: .semibold, design: .rounded))
            .foregroundStyle(tint)
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.6)
    }

    private var footerText: some View {
        Text(item.statusText(at: date))
            .font(.system(size: compact ? 11 : 13, weight: .medium, design: .rounded))
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
    }

    private var ringCard: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(alignment: .leading, spacing: compact ? 3 : 6) {
                HStack(spacing: 8) {
                    Text(item.title)
                        .font(.system(size: compact ? 17 : 25, weight: .bold, design: .rounded))
                        .foregroundStyle(.black)
                        .lineLimit(compact ? 1 : 2)
                        .minimumScaleFactor(0.55)

                    if item.showIcon {
                        Image(systemName: item.icon)
                            .font(.system(size: compact ? 14 : 20, weight: .semibold))
                            .foregroundStyle(.black.opacity(0.85))
                    }
                }

                Text(item.homeTimeText(at: date).replacingOccurrences(of: "\n", with: " "))
                    .font(.system(size: compact ? 15 : 23, weight: .bold, design: .rounded))
                    .foregroundStyle(.black.opacity(0.45))
                    .lineLimit(compact ? 1 : 2)
                    .minimumScaleFactor(0.5)

                Spacer(minLength: 0)
            }
            .padding(compact ? 14 : 22)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            ZStack {
                Circle()
                    .stroke(tint.opacity(0.24), lineWidth: compact ? 10 : 16)
                Circle()
                    .trim(from: 0, to: max(progress, 0.03))
                    .stroke(tint, style: StrokeStyle(lineWidth: compact ? 10 : 16, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            .frame(width: compact ? 54 : 74, height: compact ? 54 : 74)
            .padding(compact ? 14 : 22)
        }
    }

    private var blockGrid: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text(item.title)
                    .font(.system(size: compact ? 17 : 30, weight: .bold, design: .rounded))
                    .foregroundStyle(.black)
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)
                Spacer(minLength: 8)
                percentageText
                    .foregroundStyle(.black.opacity(0.52))
            }

            Spacer(minLength: compact ? 8 : 18)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: compact ? 4 : 6), count: compact ? 10 : 20), spacing: compact ? 4 : 7) {
                ForEach(0..<(compact ? 30 : 80), id: \.self) { index in
                    let filled = Double(index + 1) / Double(compact ? 30 : 80) <= progress
                    RoundedRectangle(cornerRadius: compact ? 3 : 5, style: .continuous)
                        .fill(filled ? tint : .clear)
                        .overlay {
                            RoundedRectangle(cornerRadius: compact ? 3 : 5, style: .continuous)
                                .stroke(tint.opacity(0.82), lineWidth: filled ? 0 : 1.6)
                        }
                        .aspectRatio(1, contentMode: .fit)
                }
            }
            .frame(maxHeight: compact ? 54 : 94)
        }
        .padding(compact ? 14 : 22)
    }

    private var glowPanel: some View {
        ZStack(alignment: .topTrailing) {
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [tint.opacity(0.92), Color(hex: "#AA00FF"), tint.opacity(0.72)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: compact ? 84 : 164, height: compact ? 70 : 116)
                .blur(radius: compact ? 8 : 15)
                .offset(x: compact ? 8 : 18, y: compact ? -8 : -18)

            VStack(alignment: .leading, spacing: compact ? 4 : 10) {
                HStack(spacing: 8) {
                    Text(item.title)
                        .font(.system(size: compact ? 18 : 30, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.55)
                    if item.showIcon {
                        Image(systemName: item.icon)
                            .font(.system(size: compact ? 16 : 26, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.88))
                    }
                }

                Text(item.homeTimeText(at: date).replacingOccurrences(of: "\n", with: " "))
                    .font(.system(size: compact ? 15 : 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.45))
                    .lineLimit(1)
                    .minimumScaleFactor(0.48)

                Spacer(minLength: 0)
            }
            .padding(compact ? 14 : 22)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    private var iconBar: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: compact ? 10 : 18) {
                if item.showIcon {
                    Image(systemName: item.icon)
                        .font(.system(size: compact ? 24 : 38, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: compact ? 44 : 68, height: compact ? 44 : 68)
                        .background(tint, in: RoundedRectangle(cornerRadius: compact ? 13 : 18, style: .continuous))
                }

                VStack(alignment: .leading, spacing: compact ? 2 : 5) {
                    Text(item.title)
                        .font(.system(size: compact ? 18 : 30, weight: .bold, design: .rounded))
                        .foregroundStyle(.black)
                        .lineLimit(1)
                        .minimumScaleFactor(0.55)

                    Text(item.homeTimeText(at: date).replacingOccurrences(of: "\n", with: " "))
                        .font(.system(size: compact ? 15 : 27, weight: .bold, design: .rounded))
                        .foregroundStyle(.black.opacity(0.45))
                        .lineLimit(1)
                        .minimumScaleFactor(0.48)
                }
            }

            Spacer(minLength: compact ? 12 : 18)

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(.black.opacity(0.12))
                    Capsule().fill(tint).frame(width: max(proxy.size.width * progress, compact ? 10 : 18))
                }
            }
            .frame(height: compact ? 12 : 20)
        }
        .padding(compact ? 14 : 22)
    }

}

struct AccessoryProgressView: View {
    let item: ProgressItem
    let date: Date

    var body: some View {
        HStack(spacing: 8) {
            Gauge(value: item.progress(at: date)) {
                Text(item.title)
            }
            .gaugeStyle(.accessoryCircularCapacity)
            VStack(alignment: .leading, spacing: 1) {
                Text(item.title).lineLimit(1)
                Text(item.statusText(at: date)).foregroundStyle(.secondary).lineLimit(1)
            }
        }
    }
}
