import SwiftUI
import UIKit

struct ContentView: View {
    @EnvironmentObject private var store: ProgressStore
    @Namespace private var transitionNamespace

    @State private var selectedFilter: EventFilter?
    @State private var sortOption: SortOption = .dueDate
    @State private var isAddMenuOpen = false
    @State private var editorRoute: EditorRoute?

    private let horizontalPadding: CGFloat = 16
    private let gridSpacing: CGFloat = 10

    private var homeCardSize: CGFloat {
        let screenWidth = max(UIScreen.main.bounds.width, 320)
        return floor((screenWidth - (horizontalPadding * 2) - gridSpacing) / 2)
    }

    private var filteredItems: [ProgressItem] {
        let now = Date()
        let filtered: [ProgressItem]

        switch selectedFilter {
        case nil:
            filtered = store.items
        case .some(.today):
            filtered = store.items.filter { Calendar.current.isDateInToday($0.endDate) }
        case .some(.nextSevenDays):
            let upper = Calendar.current.date(byAdding: .day, value: 7, to: now) ?? now
            filtered = store.items.filter { $0.endDate >= now && $0.endDate <= upper }
        case .some(.nextThirtyDays):
            let upper = Calendar.current.date(byAdding: .day, value: 30, to: now) ?? now
            filtered = store.items.filter { $0.endDate >= now && $0.endDate <= upper }
        }

        switch sortOption {
        case .dueDate:
            return filtered.sorted { $0.endDate < $1.endDate }
        case .createdDate:
            return filtered.sorted { $0.createdAt > $1.createdAt }
        case .name:
            return filtered.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        case .modifiedDate:
            return filtered.sorted { ($0.modifiedAt ?? $0.createdAt) > ($1.modifiedAt ?? $1.createdAt) }
        }
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Color.white.ignoresSafeArea()

            mainContent

            if isAddMenuOpen {
                AddMenuOverlay(
                    actions: AddAction.allCases,
                    onDismiss: closeAddMenu,
                    onSelect: handleAddAction
                )
                .zIndex(1)
                .transition(.opacity)
            }

            FloatingAddButton(isOpen: isAddMenuOpen) {
                toggleAddMenu()
            }
            .padding(.trailing, 24)
            .padding(.bottom, 28)
            .zIndex(2)
        }
        .dynamicTypeSize(.medium)
        .animation(.spring(response: 0.42, dampingFraction: 0.86), value: isAddMenuOpen)
        .sensoryFeedback(.impact(weight: .medium), trigger: isAddMenuOpen)
        .sensoryFeedback(.selection, trigger: selectedFilter)
        .sensoryFeedback(.selection, trigger: sortOption)
        .sheet(item: $editorRoute) { route in
            EditorView(item: route.item) { saved in
                if route.isNew {
                    store.add(saved)
                } else {
                    store.update(saved)
                }
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.hidden)
            .presentationCornerRadius(32)
            .presentationBackground(Color(hex: "#F2F2F7"))
        }
    }

    private var mainContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                Text("Events")
                    .font(.system(size: 31, weight: .semibold))
                    .foregroundStyle(.black)
                    .padding(.top, 66)
                    .padding(.horizontal, horizontalPadding)
                    .minimumScaleFactor(0.72)

                filterBar

                eventGrid
                    .padding(.horizontal, horizontalPadding)
                    .padding(.bottom, 140)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollIndicators(.hidden)
    }

    private var filterBar: some View {
        ZStack(alignment: .trailing) {
            ScrollView(.horizontal) {
                HStack(spacing: 10) {
                    ForEach(EventFilter.allCases) { filter in
                        FilterChip(filter: filter, isSelected: selectedFilter == filter) {
                            Haptics.selection()
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                                selectedFilter = selectedFilter == filter ? nil : filter
                            }
                        }
                    }
                }
                .padding(.leading, horizontalPadding)
                .padding(.trailing, 88)
                .padding(.vertical, 8)
            }
            .scrollIndicators(.hidden)
            .scrollClipDisabled()
            .overlay(alignment: .trailing) {
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0),
                        .init(color: .white.opacity(0.85), location: 0.62),
                        .init(color: .white, location: 1)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: 128)
                .allowsHitTesting(false)
            }

            Menu {
                Picker("Sort by", selection: $sortOption) {
                    ForEach(SortOption.allCases) { option in
                        Label(option.title, systemImage: option.systemImage).tag(option)
                    }
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color.black.opacity(0.42))
                    .frame(width: 40, height: 40)
                    .liquidGlass(in: Circle(), interactive: true)
            }
            .padding(.trailing, horizontalPadding)
        }
        .frame(height: 54)
    }

    private var eventGrid: some View {
        LazyVGrid(
            columns: [
                GridItem(.fixed(homeCardSize), spacing: gridSpacing, alignment: .topLeading),
                GridItem(.fixed(homeCardSize), spacing: gridSpacing, alignment: .topLeading)
            ],
            alignment: .leading,
            spacing: gridSpacing
        ) {
            ForEach(filteredItems) { item in
                Button {
                    Haptics.impact(.light)
                    editorRoute = EditorRoute(item: item, isNew: false)
                } label: {
                    EventTile(item: item, size: homeCardSize)
                }
                .buttonStyle(.plain)
                .matchedTransitionSourceIfAvailable(id: item.id, in: transitionNamespace)
                .contextMenu {
                    Button(role: .destructive) {
                        Haptics.impact(.medium)
                        delete(item)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
    }

    private func toggleAddMenu() {
        Haptics.impact(isAddMenuOpen ? .light : .medium)
        isAddMenuOpen.toggle()
    }

    private func closeAddMenu() {
        Haptics.selection()
        isAddMenuOpen = false
    }

    private func handleAddAction(_ action: AddAction) {
        Haptics.impact(.light)
        let route = EditorRoute(item: action.makeItem(), isNew: true)

        withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) {
            isAddMenuOpen = false
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            editorRoute = route
        }
    }

    private func delete(_ item: ProgressItem) {
        guard let index = store.items.firstIndex(where: { $0.id == item.id }) else { return }
        store.items.remove(at: index)
    }
}

private struct EventTile: View {
    let item: ProgressItem
    let size: CGFloat

    private var cornerRadius: CGFloat { size * 0.17 }
    private var contentPadding: CGFloat { max(size * 0.048, 8) }
    private var titleSize: CGFloat { min(max(size * 0.09, 13), 17) }
    private var timeSize: CGFloat { min(max(size * 0.092, 14), 18) }
    private var ringSize: CGFloat { size * 0.34 }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color(hex: item.backgroundHex))

            ProgressRing(progress: item.progress, tint: Color(hex: item.tintHex), lineWidth: max(size * 0.07, 10))
                .frame(width: ringSize, height: ringSize)
                .padding(contentPadding)

                VStack(alignment: .leading, spacing: 6) {
                Text(item.title)
                    .font(.system(size: titleSize, weight: .semibold))
                    .foregroundStyle(.black)
                    .lineLimit(2)
                    .minimumScaleFactor(0.72)
                    .frame(maxWidth: size * 0.72, alignment: .leading)

                Text(item.homeTimeText())
                    .font(.system(size: timeSize, weight: .medium))
                    .foregroundStyle(.black.opacity(0.42))
                    .lineLimit(2)
                    .minimumScaleFactor(0.66)

                Spacer(minLength: 0)
            }
            .padding(contentPadding)
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

private struct ProgressRing: View {
    let progress: Double
    let tint: Color
    var lineWidth: CGFloat = 14

    var body: some View {
        ZStack {
            Circle()
                .stroke(tint.opacity(0.62), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(progress, 0.02))
                .stroke(Color(hex: "#FFDF5A"), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
    }
}

private struct FilterChip: View {
    let filter: EventFilter
    let isSelected: Bool
    let action: () -> Void
    private let selectedBlue = Color(hex: "#1297F5")

    var body: some View {
        Button(action: action) {
            HStack(spacing: 0) {
                Text(filter.title)
                    .font(.system(size: 14, weight: .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .foregroundStyle(isSelected ? selectedBlue : Color.black.opacity(0.34))
            .padding(.horizontal, 13)
            .frame(height: 36)
            .liquidGlass(in: Capsule(), tint: isSelected ? selectedBlue.opacity(0.28) : nil, interactive: true)
            .overlay {
                if isSelected {
                    Capsule()
                        .stroke(selectedBlue.opacity(0.35), lineWidth: 1)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

private struct FloatingAddButton: View {
    let isOpen: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.system(size: 27, weight: .regular))
                .foregroundStyle(.white)
                .rotationEffect(.degrees(isOpen ? 45 : 0))
                .frame(width: 58, height: 58)
                .background {
                    Circle().fill(Color(hex: "#1297F5").opacity(0.82))
                }
                .liquidGlass(in: Circle(), tint: Color(hex: "#1297F5").opacity(0.62), interactive: true)
                .shadow(color: Color(hex: "#1297F5").opacity(0.24), radius: 18, x: 0, y: 12)
                .shadow(color: .black.opacity(0.16), radius: 22, x: 0, y: 14)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isOpen ? "Close add menu" : "Open add menu")
    }
}

private struct AddMenuOverlay: View {
    let actions: [AddAction]
    let onDismiss: () -> Void
    let onSelect: (AddAction) -> Void

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Rectangle()
                .fill(.white.opacity(0.86))
                .background(.ultraThinMaterial)
                .ignoresSafeArea()
                .onTapGesture(perform: onDismiss)

            VStack(alignment: .trailing, spacing: 18) {
                ForEach(Array(actions.enumerated()), id: \.element.id) { index, action in
                    AddMenuRow(action: action) {
                        onSelect(action)
                    }
                    .transition(
                        .asymmetric(
                            insertion: .move(edge: .trailing)
                                .combined(with: .opacity)
                                .combined(with: .scale(scale: 0.9, anchor: .trailing)),
                            removal: .opacity
                                .combined(with: .scale(scale: 0.94, anchor: .trailing))
                        )
                    )
                    .animation(.spring(response: 0.34, dampingFraction: 0.82).delay(Double(index) * 0.025), value: actions.count)
                }
            }
            .padding(.trailing, 26)
            .padding(.bottom, 112)
            .zIndex(1)
        }
    }
}

private struct AddMenuRow: View {
    let action: AddAction
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                Text(action.title)
                    .font(.system(size: 21, weight: .regular))
                    .foregroundStyle(.black)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                Image(systemName: action.systemImage)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(.black)
                    .frame(width: 38, height: 38)
                    .liquidGlass(in: Circle(), interactive: true)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private enum EventFilter: String, CaseIterable, Identifiable {
    case today
    case nextSevenDays
    case nextThirtyDays

    var id: String { rawValue }

    var title: String {
        switch self {
        case .today: "Today"
        case .nextSevenDays: "Next 7 days"
        case .nextThirtyDays: "Next 30 days"
        }
    }

    var systemImage: String {
        switch self {
        case .today: "rectangle.stack.fill"
        case .nextSevenDays: "rectangle.stack.fill"
        case .nextThirtyDays: "rectangle.stack.fill"
        }
    }
}

private enum SortOption: String, CaseIterable, Identifiable {
    case dueDate
    case createdDate
    case name
    case modifiedDate

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dueDate: "Due date"
        case .createdDate: "Date created"
        case .name: "Name"
        case .modifiedDate: "Date modified"
        }
    }

    var systemImage: String {
        switch self {
        case .dueDate: "calendar.badge.clock"
        case .createdDate: "plus.circle"
        case .name: "textformat"
        case .modifiedDate: "pencil.circle"
        }
    }
}

private struct EditorRoute: Identifiable {
    let id = UUID()
    let item: ProgressItem
    let isNew: Bool
}

private enum AddActionKind: String, CaseIterable {
    case countdown
    case timeSince
    case timer
    case birthday
    case importEvent
    case importReminder
}

private struct AddAction: Identifiable, Hashable {
    let kind: AddActionKind
    var id: AddActionKind { kind }

    static let allCases = AddActionKind.allCases.map(AddAction.init)

    var title: String {
        switch kind {
        case .countdown: "Countdown"
        case .timeSince: "Time since"
        case .timer: "Timer"
        case .birthday: "Birthday"
        case .importEvent: "Import event"
        case .importReminder: "Import reminder"
        }
    }

    var systemImage: String {
        switch kind {
        case .countdown: "arrow.down"
        case .timeSince: "arrow.up"
        case .timer: "timer"
        case .birthday: "gift.fill"
        case .importEvent: "calendar"
        case .importReminder: "list.bullet.circle"
        }
    }

    func makeItem() -> ProgressItem {
        switch kind {
        case .countdown:
            return ProgressItem(
                title: "New countdown",
                icon: "arrow.down",
                startDate: .now,
                endDate: Calendar.current.date(byAdding: .day, value: 30, to: .now) ?? .now,
                tintHex: "#D14C40",
                backgroundHex: "#F25549",
                style: .aqua
            )
        case .timeSince:
            return ProgressItem(
                title: "Time since",
                icon: "arrow.up",
                startDate: Calendar.current.date(byAdding: .day, value: -7, to: .now) ?? .now,
                endDate: Calendar.current.date(byAdding: .day, value: 365, to: .now) ?? .now,
                tintHex: "#18A999",
                backgroundHex: "#D9F6EE",
                style: .minimal
            )
        case .timer:
            return ProgressItem(
                title: "Timer",
                icon: "timer",
                startDate: .now,
                endDate: Calendar.current.date(byAdding: .hour, value: 1, to: .now) ?? .now,
                tintHex: "#1D9BF0",
                backgroundHex: "#DDF0FF",
                style: .swiss
            )
        case .birthday:
            return ProgressItem(
                title: "Birthday",
                icon: "gift.fill",
                startDate: .now,
                endDate: Calendar.current.date(byAdding: .month, value: 1, to: .now) ?? .now,
                tintHex: "#EC5D57",
                backgroundHex: "#FFE2E0",
                style: .grid
            )
        case .importEvent:
            return ProgressItem(
                title: "Imported event",
                icon: "calendar",
                startDate: .now,
                endDate: Calendar.current.date(byAdding: .day, value: 7, to: .now) ?? .now,
                tintHex: "#D14C40",
                backgroundHex: "#F25549",
                style: .aqua
            )
        case .importReminder:
            return ProgressItem(
                title: "Imported reminder",
                icon: "list.bullet.circle",
                startDate: .now,
                endDate: Calendar.current.date(byAdding: .day, value: 1, to: .now) ?? .now,
                tintHex: "#1D9BF0",
                backgroundHex: "#DDF0FF",
                style: .swiss
            )
        }
    }
}

enum Haptics {
    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred()
    }

    static func selection() {
        let generator = UISelectionFeedbackGenerator()
        generator.prepare()
        generator.selectionChanged()
    }
}

private extension View {
    @ViewBuilder
    func matchedTransitionSourceIfAvailable<ID: Hashable>(id: ID, in namespace: Namespace.ID) -> some View {
        if #available(iOS 18.0, *) {
            self.matchedTransitionSource(id: id, in: namespace)
        } else {
            self
        }
    }

    @ViewBuilder
    func liquidGlass<S: Shape>(in shape: S, tint: Color? = nil, interactive: Bool = false) -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(.regular.tint(tint).interactive(interactive), in: shape)
        } else {
            self
                .background(.ultraThinMaterial, in: shape)
                .overlay {
                    shape.stroke(.white.opacity(0.68), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.08), radius: 22, x: 0, y: 12)
        }
    }
}
