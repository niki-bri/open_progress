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
            case .swiss:
                swiss
            case .grid:
                grid
            case .aqua:
                aqua
            case .retro:
                retro
            case .minimal:
                minimal
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

    private var swiss: some View {
        VStack(alignment: .leading, spacing: compact ? 8 : 12) {
            header
            Spacer(minLength: 0)
            percentageText
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.primary.opacity(0.12))
                    Capsule().fill(tint).frame(width: max(proxy.size.width * progress, 7))
                }
            }
            .frame(height: compact ? 8 : 12)
            footerText
        }
        .padding(compact ? 14 : 18)
    }

    private var grid: some View {
        VStack(alignment: .leading, spacing: compact ? 8 : 10) {
            header
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 5), count: compact ? 5 : 8), spacing: 5) {
                ForEach(0..<(compact ? 20 : 32), id: \.self) { index in
                    let filled = Double(index + 1) / Double(compact ? 20 : 32) <= progress
                    RoundedRectangle(cornerRadius: 3)
                        .fill(filled ? tint : Color.primary.opacity(0.11))
                        .aspectRatio(1, contentMode: .fit)
                }
            }
            Spacer(minLength: 0)
            HStack {
                percentageText
                Spacer()
                footerText
            }
        }
        .padding(compact ? 14 : 18)
    }

    private var aqua: some View {
        VStack(alignment: .leading, spacing: compact ? 10 : 14) {
            header
            Spacer(minLength: 0)
            ZStack {
                Circle()
                    .stroke(tint.opacity(0.18), lineWidth: compact ? 12 : 18)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        LinearGradient(colors: [tint.opacity(0.55), tint], startPoint: .topLeading, endPoint: .bottomTrailing),
                        style: StrokeStyle(lineWidth: compact ? 12 : 18, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                percentageText
            }
            .padding(.horizontal, compact ? 18 : 28)
            footerText
        }
        .padding(compact ? 14 : 18)
    }

    private var retro: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Circle().fill(Color(hex: "#FF5F57")).frame(width: 10, height: 10)
                Circle().fill(Color(hex: "#FFBD2E")).frame(width: 10, height: 10)
                Circle().fill(Color(hex: "#28C840")).frame(width: 10, height: 10)
                Spacer()
            }
            header
            Spacer(minLength: 0)
            VStack(alignment: .leading, spacing: 6) {
                Text(item.statusText(at: date))
                    .font(.system(size: compact ? 12 : 14, weight: .bold, design: .monospaced))
                    .foregroundStyle(.primary)
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Rectangle().fill(Color.white.opacity(0.8))
                        Rectangle().fill(tint).frame(width: max(proxy.size.width * progress, 5))
                    }
                    .border(.black.opacity(0.45), width: 2)
                }
                .frame(height: compact ? 18 : 24)
            }
            percentageText
        }
        .padding(compact ? 14 : 18)
    }

    private var minimal: some View {
        VStack(alignment: .leading, spacing: compact ? 10 : 14) {
            HStack {
                if item.showIcon {
                    Image(systemName: item.icon)
                        .font(.system(size: compact ? 24 : 32, weight: .medium))
                        .foregroundStyle(tint)
                }
                Spacer()
                percentageText
            }
            Spacer(minLength: 0)
            Text(item.title)
                .font(.system(size: compact ? 17 : 22, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
            footerText
        }
        .padding(compact ? 14 : 18)
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
