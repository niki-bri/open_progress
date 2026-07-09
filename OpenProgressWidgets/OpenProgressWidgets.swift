import AppIntents
import SwiftUI
import WidgetKit

struct ProgressEventEntity: AppEntity {
    typealias ID = String

    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Event")
    static var defaultQuery = ProgressEventQuery()

    let id: String
    let title: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(title)")
    }

    init(item: ProgressItem) {
        self.id = item.id.uuidString
        self.title = item.title
    }
}

struct ProgressEventQuery: EntityQuery {
    func entities(for identifiers: [ProgressEventEntity.ID]) async throws -> [ProgressEventEntity] {
        let wanted = Set(identifiers)
        return ProgressStorage.load()
            .filter { wanted.contains($0.id.uuidString) }
            .map(ProgressEventEntity.init)
    }

    func suggestedEntities() async throws -> [ProgressEventEntity] {
        ProgressStorage.load().map(ProgressEventEntity.init)
    }
}

struct SelectProgressEventIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Event"
    static var description = IntentDescription("Choose the event this widget displays.")

    @Parameter(title: "Event")
    var event: ProgressEventEntity?

    init() {}

    init(event: ProgressEventEntity?) {
        self.event = event
    }
}

struct DashboardConfigurationIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Dashboard"
    static var description = IntentDescription("Choose the events shown in the dashboard widget.")

    @Parameter(title: "Event 1")
    var eventOne: ProgressEventEntity?

    @Parameter(title: "Event 2")
    var eventTwo: ProgressEventEntity?

    @Parameter(title: "Event 3")
    var eventThree: ProgressEventEntity?

    @Parameter(title: "Event 4")
    var eventFour: ProgressEventEntity?

    @Parameter(title: "Event 5")
    var eventFive: ProgressEventEntity?

    @Parameter(title: "Event 6")
    var eventSix: ProgressEventEntity?

    init() {}
}

struct ProgressEntry: TimelineEntry {
    let date: Date
    let item: ProgressItem
}

struct DashboardEntry: TimelineEntry {
    let date: Date
    let items: [ProgressItem]
}

struct ProgressProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> ProgressEntry {
        ProgressEntry(date: .now, item: ProgressStorage.seedItems().first ?? .sample)
    }

    func snapshot(for configuration: SelectProgressEventIntent, in context: Context) async -> ProgressEntry {
        ProgressEntry(date: .now, item: selectedItem(for: configuration))
    }

    func timeline(for configuration: SelectProgressEventIntent, in context: Context) async -> Timeline<ProgressEntry> {
        let item = selectedItem(for: configuration)
        let now = Date()
        let entries = stride(from: 0, through: 24, by: 1).map { offset in
            let date = Calendar.current.date(byAdding: .hour, value: offset, to: now) ?? now
            return ProgressEntry(date: date, item: item)
        }
        let reloadDate = Calendar.current.date(byAdding: .hour, value: 1, to: now) ?? now
        return Timeline(entries: entries, policy: .after(reloadDate))
    }

    private func selectedItem(for configuration: SelectProgressEventIntent) -> ProgressItem {
        let items = ProgressStorage.load()
        guard let selectedId = configuration.event?.id else {
            return items.first ?? ProgressStorage.seedItems().first ?? .sample
        }

        return items.first { $0.id.uuidString == selectedId } ?? items.first ?? ProgressStorage.seedItems().first ?? .sample
    }
}

struct DashboardProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> DashboardEntry {
        DashboardEntry(date: .now, items: DashboardSamples.items)
    }

    func snapshot(for configuration: DashboardConfigurationIntent, in context: Context) async -> DashboardEntry {
        DashboardEntry(date: .now, items: dashboardItems(for: configuration))
    }

    func timeline(for configuration: DashboardConfigurationIntent, in context: Context) async -> Timeline<DashboardEntry> {
        let now = Date()
        let entries = stride(from: 0, through: 24, by: 1).map { offset in
            let date = Calendar.current.date(byAdding: .hour, value: offset, to: now) ?? now
            return DashboardEntry(date: date, items: dashboardItems(for: configuration))
        }
        let reloadDate = Calendar.current.date(byAdding: .hour, value: 1, to: now) ?? now
        return Timeline(entries: entries, policy: .after(reloadDate))
    }

    private func dashboardItems(for configuration: DashboardConfigurationIntent) -> [ProgressItem] {
        let stored = ProgressStorage.load()
        let slots = [
            configuration.eventOne,
            configuration.eventTwo,
            configuration.eventThree,
            configuration.eventFour,
            configuration.eventFive,
            configuration.eventSix
        ]

        let selectedIds = slots.compactMap { $0?.id }
        var selected: [ProgressItem] = []
        for id in selectedIds {
            guard
                let item = stored.first(where: { $0.id.uuidString == id }),
                !selected.contains(where: { $0.id == item.id })
            else {
                continue
            }
            selected.append(item)
        }

        let selectedSet = Set(selected.map(\.id))
        let remaining = stored
            .filter { !selectedSet.contains($0.id) }
            .sorted {
                if $0.endDate == $1.endDate { return $0.title < $1.title }
                return $0.endDate < $1.endDate
            }

        let arranged = selected.isEmpty ? remaining : selected + remaining

        if arranged.isEmpty {
            return DashboardSamples.items
        }

        if arranged.count >= 6 {
            return Array(arranged.prefix(6))
        }

        return Array((arranged + DashboardSamples.items).prefix(6))
    }
}

struct OpenProgressWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: ProgressEntry

    var body: some View {
        switch family {
        case .accessoryCircular:
            Gauge(value: entry.item.progress(at: entry.date)) {
                Image(systemName: entry.item.icon)
            }
            .gaugeStyle(.accessoryCircularCapacity)
        case .accessoryInline:
            Text("\(entry.item.title): \(entry.item.statusText(at: entry.date))")
        case .accessoryRectangular:
            AccessoryProgressView(item: entry.item, date: entry.date)
        case .systemSmall:
            WidgetCardView(item: entry.item, date: entry.date, compact: true)
        default:
            WidgetCardView(item: entry.item, date: entry.date)
        }
    }
}

struct DashboardWidgetView: View {
    @Environment(\.widgetFamily) private var family
    @Environment(\.colorScheme) private var colorScheme
    let entry: DashboardEntry

    var body: some View {
        DashboardPanel(family: family, items: entry.items, date: entry.date)
            .fontDesign(.rounded)
            .containerBackground(for: .widget) {
                colorScheme == .dark ? Color(hex: "#1C1C1E") : .white
            }
    }
}

struct OpenProgressWidgets: Widget {
    let kind = "OpenProgressWidgets"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: SelectProgressEventIntent.self, provider: ProgressProvider()) { entry in
            OpenProgressWidgetView(entry: entry)
        }
        .configurationDisplayName("Open Progress")
        .description("Track a selected event.")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .systemLarge,
            .accessoryInline,
            .accessoryCircular,
            .accessoryRectangular
        ])
        .contentMarginsDisabled()
    }
}

struct OpenProgressDashboardWidgets: Widget {
    let kind = "OpenProgressDashboardWidgets"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: DashboardConfigurationIntent.self, provider: DashboardProvider()) { entry in
            DashboardWidgetView(entry: entry)
        }
        .configurationDisplayName("Dashboard")
        .description("Display several selected events in one widget.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}

@main
struct OpenProgressWidgetBundle: WidgetBundle {
    var body: some Widget {
        OpenProgressWidgets()
        OpenProgressDashboardWidgets()
    }
}

private struct DashboardPanel: View {
    let family: WidgetFamily
    let items: [ProgressItem]
    let date: Date

    @ViewBuilder
    var body: some View {
        switch family {
        case .systemSmall:
            smallLayout
        case .systemMedium:
            mediumLayout
        default:
            largeLayout
        }
    }

    private var smallLayout: some View {
        VStack(spacing: 4) {
            DashboardTile(item: item(0), date: date, variant: .small, showsRing: false)
            DashboardTile(item: item(1), date: date, variant: .small, showsRing: false)
        }
        .padding(4)
    }

    private var mediumLayout: some View {
        HStack(spacing: 4) {
            DashboardTile(item: item(0), date: date, variant: .large, showsRing: true)
                .frame(maxWidth: .infinity)

            VStack(spacing: 4) {
                DashboardTile(item: item(1), date: date, variant: .small, showsRing: false)
                DashboardTile(item: item(2), date: date, variant: .small, showsRing: false)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(4)
    }

    private var largeLayout: some View {
        VStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { row in
                HStack(spacing: 4) {
                    DashboardTile(item: item(row * 2), date: date, variant: .small, showsRing: true, ringSizeOverride: 46, ringWidthOverride: 9)
                    DashboardTile(item: item(row * 2 + 1), date: date, variant: .small, showsRing: true, ringSizeOverride: 46, ringWidthOverride: 9)
                }
            }
        }
        .padding(4)
    }

    private func item(_ index: Int) -> ProgressItem {
        guard items.indices.contains(index) else {
            return DashboardSamples.items[index % DashboardSamples.items.count]
        }
        return items[index]
    }
}

private struct DashboardTile: View {
    enum Variant {
        case large
        case small
    }

    let item: ProgressItem
    let date: Date
    let variant: Variant
    let showsRing: Bool
    var ringSizeOverride: CGFloat?
    var ringWidthOverride: CGFloat?

    private var background: Color { Color(hex: item.backgroundHex) }
    private var tint: Color { Color(hex: item.tintHex) }
    private var isDark: Bool { item.hasDarkBackground }
    private var foreground: Color { isDark ? .white : .black }
    private var secondary: Color { foreground.opacity(isDark ? 0.55 : 0.45) }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(background)

            if showsRing {
                dashboardRing
                    .frame(width: ringSize, height: ringSize)
                    .padding(ringPadding)
            }

            VStack(alignment: .leading, spacing: textSpacing) {
                Text(displayTitle)
                    .font(.system(size: titleSize, weight: .semibold))
                    .foregroundStyle(foreground)
                    .lineLimit(variant == .large ? 2 : 1)
                    .minimumScaleFactor(0.62)

                Text(displaySubtitle)
                    .font(.system(size: subtitleSize, weight: .medium))
                    .foregroundStyle(secondary)
                    .lineLimit(variant == .large ? 2 : 1)
                    .minimumScaleFactor(0.62)

                Spacer(minLength: 0)
            }
            .padding(tilePadding)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var dashboardRing: some View {
        ZStack {
            Circle()
                .stroke(tint.opacity(isDark ? 0.18 : 0.25), lineWidth: ringWidth)
            Circle()
                .trim(from: 0, to: max(item.progress(at: date), 0.035))
                .stroke(tint, style: StrokeStyle(lineWidth: ringWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
    }

    private var displayTitle: String {
        if variant == .small, item.title.count > 16 {
            return String(item.title.prefix(14)) + "..."
        }
        return item.title
    }

    private var displaySubtitle: String {
        item.homeTimeText(at: date).replacingOccurrences(of: "\n", with: " ")
    }

    private var cornerRadius: CGFloat {
        variant == .large ? ProgressWidgetMetrics.dashboardLargeTileCornerRadius : ProgressWidgetMetrics.dashboardSmallTileCornerRadius
    }
    private var tilePadding: CGFloat { variant == .large ? 14 : 10 }
    private var ringPadding: CGFloat { variant == .large ? 16 : 10 }
    private var ringSize: CGFloat { ringSizeOverride ?? (variant == .large ? 64 : 44) }
    private var ringWidth: CGFloat { ringWidthOverride ?? (variant == .large ? 14 : 9) }
    private var textSpacing: CGFloat { variant == .large ? 5 : 2 }
    private var titleSize: CGFloat { variant == .large ? 19 : 16 }
    private var subtitleSize: CGFloat { variant == .large ? 17 : 14 }
}

private enum DashboardSamples {
    static let items: [ProgressItem] = [
        ProgressItem(
            title: "Information Retrieval",
            icon: "books.vertical.fill",
            startDate: Calendar.current.date(byAdding: .day, value: -5, to: .now) ?? .now,
            endDate: Calendar.current.date(byAdding: .hour, value: 637, to: .now) ?? .now,
            tintHex: "#FFDF5A",
            backgroundHex: "#CDB3F7",
            style: .aqua
        ),
        ProgressItem(
            title: "Thursday 9",
            icon: "calendar",
            startDate: Calendar.current.date(byAdding: .day, value: -8, to: .now) ?? .now,
            endDate: Calendar.current.date(byAdding: .day, value: 9, to: .now) ?? .now,
            tintHex: "#63DED7",
            backgroundHex: "#414858",
            style: .grid
        ),
        ProgressItem(
            title: "This week",
            icon: "calendar",
            startDate: Calendar.current.date(byAdding: .day, value: -4, to: .now) ?? .now,
            endDate: Calendar.current.date(byAdding: .day, value: 2, to: .now) ?? .now,
            tintHex: "#FFB323",
            backgroundHex: "#0EA1D5",
            style: .glow
        ),
        ProgressItem(
            title: "July",
            icon: "calendar",
            startDate: Calendar.current.date(byAdding: .day, value: -8, to: .now) ?? .now,
            endDate: Calendar.current.date(byAdding: .day, value: 22, to: .now) ?? .now,
            tintHex: "#3BCB6F",
            backgroundHex: "#E9EAE1",
            style: .retro
        ),
        ProgressItem(
            title: "2026",
            icon: "calendar",
            startDate: Calendar.current.date(byAdding: .day, value: -190, to: .now) ?? .now,
            endDate: Calendar.current.date(byAdding: .day, value: 175, to: .now) ?? .now,
            tintHex: "#3B2F35",
            backgroundHex: "#F25549",
            style: .aqua
        ),
        ProgressItem(
            title: "Thursday 9",
            icon: "calendar",
            startDate: Calendar.current.date(byAdding: .day, value: -8, to: .now) ?? .now,
            endDate: Calendar.current.date(byAdding: .day, value: 9, to: .now) ?? .now,
            tintHex: "#63DED7",
            backgroundHex: "#414858",
            style: .grid
        )
    ]
}
