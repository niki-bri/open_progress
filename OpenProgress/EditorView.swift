import SwiftUI
import UIKit

struct EditorView: View {
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isTitleFocused: Bool

    @State private var draft: ProgressItem
    @State private var showingDateEditor = false
    @State private var keyboardHeight: CGFloat = 0
    @State private var focusedThemeIndex: Int
    @State private var themePageOffset: CGFloat = 0
    @State private var isThemePaging = false
    @GestureState private var themeDragOffset: CGFloat = 0

    let onSave: (ProgressItem) -> Void

    private let colors = ["#D14C40", "#18A999", "#1D9BF0", "#8B5CF6", "#F59E0B", "#111827"]
    private let backgrounds = ["#8F959E", "#F25549", "#D9F6EE", "#DDF0FF", "#F2FCEB", "#F8F5FF", "#F9FAFB"]
    private let icons = ["arrow.down", "arrow.up", "timer", "calendar", "gift.fill", "airplane.departure", "heart.fill", "book.fill", "bolt.fill", "rocket.fill", "list.bullet.circle"]

    init(item: ProgressItem?, onSave: @escaping (ProgressItem) -> Void) {
        let initial = item ?? ProgressItem(
            title: "Event name",
            icon: "arrow.down",
            startDate: .now,
            endDate: Calendar.current.date(byAdding: .day, value: 7, to: .now) ?? .now,
            tintHex: "#79C8E5",
            backgroundHex: "#8F959E",
            style: .aqua
        )
        _draft = State(initialValue: initial)
        _focusedThemeIndex = State(initialValue: Self.themeIndex(for: initial.style))
        self.onSave = onSave
    }

    var body: some View {
        ZStack {
            Color(hex: "#F2F2F7")
                .ignoresSafeArea()

            VStack(spacing: 0) {
                fixedPreviewArea
                panelScroll
            }
        }
        .dynamicTypeSize(.medium)
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .safeAreaInset(edge: .top) {
            topBar
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 10)
                .background(Color(hex: "#F2F2F7").opacity(0.94))
        }
        .sheet(isPresented: $showingDateEditor) {
            DateCalendarSheet(item: $draft, kindLabel: kindLabel) {
                normalizeDates()
                showingDateEditor = false
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.hidden)
            .presentationCornerRadius(32)
            .presentationBackground(Color(hex: "#F2F2F7"))
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)) { notification in
            keyboardHeight = keyboardOverlap(from: notification)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            keyboardHeight = 0
        }
    }

    private var topBar: some View {
        HStack(spacing: 14) {
            Button {
                Haptics.impact(.light)
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 22, weight: .regular))
                    .foregroundStyle(.black)
                    .frame(width: 50, height: 50)
                    .liquidGlass(in: Circle(), interactive: true)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close")

            Spacer(minLength: 0)

            Button {
                saveDraft()
            } label: {
                Image(systemName: "checkmark")
                    .font(.system(size: 23, weight: .regular))
                    .foregroundStyle(.white)
                    .frame(width: 50, height: 50)
                    .background {
                        Circle().fill(Color(hex: "#1297F5").opacity(0.9))
                    }
                    .liquidGlass(in: Circle(), tint: Color(hex: "#1297F5").opacity(0.64), interactive: true)
                    .shadow(color: Color(hex: "#1297F5").opacity(0.25), radius: 22, x: 0, y: 13)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Save")
        }
    }

    private var fixedPreviewArea: some View {
        GeometryReader { proxy in
            let previewWidth = max(proxy.size.width - 32, 0)
            let previewHeight = previewWidth / ProgressWidgetMetrics.mediumAspectRatio
            let pageStride = previewWidth + Self.themeCarouselSpacing

            ZStack(alignment: .top) {
                HStack(spacing: Self.themeCarouselSpacing) {
                    ForEach(themePageSlots) { slot in
                        let style = Self.themeStyles[slot.index]
                        themePreviewCard(style: style, index: slot.index)
                            .frame(width: previewWidth, height: previewHeight)
                            .id(slot.id)
                    }
                }
                .padding(.top, 16)
                .padding(.bottom, 34)
                .offset(x: themePageOffset + themeDragOffset)
                .gesture(themeDragGesture(pageStride: pageStride))
            }
            .frame(width: proxy.size.width, height: previewHeight + 54, alignment: .top)
            .clipped()
        }
        .frame(height: fixedPreviewHeight)
        .background(Color(hex: "#F2F2F7").opacity(0.97))
        .overlay(alignment: .bottom) {
            LinearGradient(
                colors: [
                    Color(hex: "#F2F2F7"),
                    Color(hex: "#F2F2F7").opacity(0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 18)
            .offset(y: 18)
            .allowsHitTesting(false)
        }
        .onChange(of: draft.style) { _, newValue in
            let index = Self.themeIndex(for: newValue)
            guard focusedThemeIndex != index else { return }
            withTransaction(Transaction(animation: nil)) {
                focusedThemeIndex = index
            }
        }
        .zIndex(2)
    }

    private static let themeStyles = ProgressStyle.allCases
    private static let themeCarouselSpacing: CGFloat = 12

    private static func themeIndex(for style: ProgressStyle) -> Int {
        themeStyles.firstIndex(of: style) ?? 0
    }

    private var themePageSlots: [ThemePageSlot] {
        [
            ThemePageSlot(id: -1, index: Self.wrappedThemeIndex(focusedThemeIndex - 1)),
            ThemePageSlot(id: 0, index: Self.wrappedThemeIndex(focusedThemeIndex)),
            ThemePageSlot(id: 1, index: Self.wrappedThemeIndex(focusedThemeIndex + 1))
        ]
    }

    private static func wrappedThemeIndex(_ index: Int) -> Int {
        guard !themeStyles.isEmpty else { return 0 }
        return (index % themeStyles.count + themeStyles.count) % themeStyles.count
    }

    @ViewBuilder
    private func themePreviewCard(style: ProgressStyle, index: Int) -> some View {
        if index == focusedThemeIndex {
            EditableEditorPreviewCard(
                item: $draft,
                isTitleFocused: $isTitleFocused,
                onDateTap: openDateEditor
            )
        } else {
            EditorPreviewCard(item: previewItem(for: style))
                .overlay {
                    RoundedRectangle(cornerRadius: ProgressWidgetMetrics.cardCornerRadius, style: .continuous)
                        .stroke(Color.white.opacity(0.7), lineWidth: 1)
                }
                .onTapGesture {
                    selectTheme(index)
                }
        }
    }

    private func themeDragGesture(pageStride: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 6)
            .updating($themeDragOffset) { value, state, _ in
                guard !isThemePaging else { return }
                state = max(min(value.translation.width, pageStride), -pageStride)
            }
            .onEnded { value in
                finishThemeDrag(value, pageStride: pageStride)
            }
    }

    private func finishThemeDrag(_ value: DragGesture.Value, pageStride: CGFloat) {
        guard !isThemePaging else { return }

        let threshold = pageStride * 0.22
        let predicted = value.predictedEndTranslation.width
        let translation = value.translation.width
        let direction: Int

        if predicted < -threshold || translation < -threshold {
            direction = 1
        } else if predicted > threshold || translation > threshold {
            direction = -1
        } else {
            direction = 0
        }

        guard direction != 0 else {
            withAnimation(.snappy(duration: 0.18)) {
                themePageOffset = 0
            }
            return
        }

        isThemePaging = true
        withAnimation(.snappy(duration: 0.2)) {
            themePageOffset = CGFloat(-direction) * pageStride
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            let newIndex = Self.wrappedThemeIndex(focusedThemeIndex + direction)
            withTransaction(Transaction(animation: nil)) {
                focusedThemeIndex = newIndex
                draft.style = Self.themeStyles[newIndex]
                themePageOffset = 0
            }
            isThemePaging = false
            Haptics.selection()
            isTitleFocused = false
        }
    }

    private func selectTheme(_ index: Int) {
        let newIndex = Self.wrappedThemeIndex(index)
        guard focusedThemeIndex != newIndex else { return }
        Haptics.selection()
        isTitleFocused = false
        withTransaction(Transaction(animation: nil)) {
            focusedThemeIndex = newIndex
            draft.style = Self.themeStyles[newIndex]
            themePageOffset = 0
        }
    }

    private var panelScroll: some View {
        ScrollView {
            editorControlsPanel
                .padding(.horizontal, 16)
                .padding(.top, 30)
                .padding(.bottom, 42 + keyboardHeight)
                .transition(.opacity)
        }
        .scrollIndicators(.hidden)
        .mask {
            VStack(spacing: 0) {
                LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom)
                    .frame(height: 8)
                Color.black
            }
        }
    }

    private var fixedPreviewHeight: CGFloat {
        let width = max(UIScreen.main.bounds.width - 32, 0)
        return (width / ProgressWidgetMetrics.mediumAspectRatio) + 54
    }

    private var editorControlsPanel: some View {
        VStack(spacing: 14) {
            eventKindCard
            dateDetailsCard
            designPanel
        }
    }

    private var eventKindCard: some View {
        HStack(spacing: 12) {
            kindButton(title: "Countdown", systemImage: "arrow.down", iconValue: "arrow.down")
            kindButton(title: "Count up", systemImage: "arrow.up", iconValue: "arrow.up")
        }
    }

    private func kindButton(title: String, systemImage: String, iconValue: String) -> some View {
        let isSelected = draft.icon == iconValue

        return Button {
            Haptics.selection()
            withAnimation(.spring(response: 0.24, dampingFraction: 0.88)) {
                draft.icon = iconValue
                if iconValue == "arrow.up", draft.endDate <= Date() {
                    draft.endDate = Calendar.current.date(byAdding: .day, value: 365, to: .now) ?? .now
                } else if iconValue == "arrow.down", draft.endDate <= draft.startDate {
                    draft.startDate = .now
                    draft.endDate = Calendar.current.date(byAdding: .day, value: 30, to: .now) ?? .now
                }
            }
        } label: {
            HStack(spacing: 9) {
                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .semibold))
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .foregroundStyle(isSelected ? Color(hex: "#1297F5") : Color.black.opacity(0.52))
            .frame(maxWidth: .infinity)
            .frame(height: 46)
            .background(isSelected ? Color(hex: "#E4F2FF") : .white, in: Capsule())
            .overlay {
                Capsule()
                    .stroke(isSelected ? Color(hex: "#1297F5").opacity(0.28) : Color.black.opacity(0.05), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    private var designPanel: some View {
        VStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 14) {
                    iconTile("paintpalette.fill")

                    Text("Palette")
                        .font(.system(size: 19, weight: .regular))
                        .foregroundStyle(.black)
                }

                HStack(spacing: 12) {
                    ForEach(Array(backgrounds.prefix(4)), id: \.self) { value in
                        PaletteSwatch(value: value, isSelected: draft.backgroundHex == value) {
                            Haptics.selection()
                            draft.backgroundHex = value
                        }
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 14)
            .editorCard()
        }
    }

    private func previewItem(for style: ProgressStyle) -> ProgressItem {
        var copy = draft
        copy.style = style
        return copy
    }

    private var dateDetailsCard: some View {
        VStack(spacing: 0) {
            Button {
                openDateEditor()
            } label: {
                HStack(spacing: 14) {
                    iconTile("calendar")

                    VStack(alignment: .leading, spacing: 3) {
                        Text(formattedDate(draft.endDate))
                            .font(.system(size: 19, weight: .semibold))
                            .foregroundStyle(.black)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)

                        Text(kindLabel)
                            .font(.system(size: 15, weight: .regular))
                            .foregroundStyle(.black.opacity(0.45))
                            .lineLimit(1)
                    }

                    Spacer(minLength: 8)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.black.opacity(0.32))
                        .frame(width: 34, height: 34)
                        .background(Color.black.opacity(0.08), in: Circle())
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
            }
            .buttonStyle(.plain)

            Divider()

            VStack(spacing: 14) {
                HStack(alignment: .top, spacing: 22) {
                    metric(title: "Start", value: startText)
                    metric(title: "Total", value: totalText)
                }

                HStack(alignment: .top, spacing: 22) {
                    metric(title: "Elapsed", value: elapsedText)
                    metric(title: "Remaining", value: remainingText)
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 14)
            .padding(.bottom, 16)
        }
        .editorCard(cornerRadius: 24)
    }

    private var kindLabel: String {
        switch draft.icon {
        case "arrow.up":
            return "Time since"
        case "timer":
            return "Timer"
        case "gift.fill":
            return "Birthday"
        case "calendar":
            return "Imported event"
        case "list.bullet.circle":
            return "Imported reminder"
        default:
            return "Countdown"
        }
    }

    private var startText: String {
        let formatted = formattedDate(draft.startDate)
        return Calendar.current.isDateInToday(draft.startDate) ? "Today, \(formatted)" : formatted
    }

    private var totalText: String {
        durationText(from: draft.startDate, to: draft.endDate, compact: false)
    }

    private var elapsedText: String {
        durationText(from: draft.startDate, to: min(Date(), draft.endDate), compact: true)
    }

    private var remainingText: String {
        durationText(from: Date(), to: draft.endDate, compact: true)
    }

    private func iconTile(_ systemImage: String) -> some View {
        Image(systemName: systemImage)
            .font(.system(size: 20, weight: .medium))
            .foregroundStyle(Color(hex: "#173957"))
            .frame(width: 44, height: 44)
            .background(Color(hex: "#EEF0F7"), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func metric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(.black.opacity(0.45))
                .lineLimit(1)

            Text(value)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.black.opacity(0.52))
                .lineLimit(1)
                .minimumScaleFactor(0.68)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func openDateEditor() {
        Haptics.selection()
        isTitleFocused = false
        showingDateEditor = true
    }

    private func saveDraft() {
        Haptics.impact(.medium)
        normalizeDates()

        var saved = draft
        let trimmedTitle = saved.title.trimmingCharacters(in: .whitespacesAndNewlines)
        saved.title = trimmedTitle.isEmpty ? "Event name" : trimmedTitle
        saved.modifiedAt = Date()
        onSave(saved)
        dismiss()
    }

    private func keyboardOverlap(from notification: Notification) -> CGFloat {
        guard
            let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
            let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene
        else {
            return 0
        }

        let screenHeight = windowScene.screen.bounds.height
        return max(0, screenHeight - frame.minY)
    }

    private func normalizeDates() {
        guard draft.endDate <= draft.startDate else { return }
        draft.endDate = Calendar.current.date(byAdding: .day, value: 1, to: draft.startDate) ?? draft.startDate
    }

    private func formattedDate(_ date: Date) -> String {
        Self.dateFormatter.string(from: date)
    }

    private func durationText(from start: Date, to end: Date, compact: Bool) -> String {
        let seconds = max(end.timeIntervalSince(start), 0)
        let days = Int(seconds / 86_400)
        let hours = Int(seconds.truncatingRemainder(dividingBy: 86_400) / 3_600)
        let minutes = Int(seconds.truncatingRemainder(dividingBy: 3_600) / 60)
        let remainingSeconds = Int(seconds.truncatingRemainder(dividingBy: 60))

        if !compact {
            if days > 0 { return "\(days) \(days == 1 ? "day" : "days")" }
            if hours > 0 { return "\(hours) \(hours == 1 ? "hour" : "hours")" }
            return "\(minutes) min"
        }

        if days > 0 {
            return "\(days)d \(hours)h \(minutes)m"
        }
        if hours > 0 {
            return "\(hours)h \(minutes)m \(remainingSeconds)s"
        }
        if minutes > 0 {
            return "\(minutes)m \(remainingSeconds)s"
        }
        return "\(remainingSeconds)s"
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateFormat = "d. MMM yyyy"
        return formatter
    }()
}

private struct ThemePageSlot: Identifiable {
    let id: Int
    let index: Int
}

private struct DateCalendarSheet: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var item: ProgressItem
    let kindLabel: String
    let onDone: () -> Void

    @State private var displayedMonth: Date
    @State private var allDayEvent = true
    @State private var countAllDays = true

    private let calendar = Calendar.current
    private let blue = Color(hex: "#1297F5")
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 7)
    private let weekdaySymbols = ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"]

    init(item: Binding<ProgressItem>, kindLabel: String, onDone: @escaping () -> Void) {
        _item = item
        self.kindLabel = kindLabel
        self.onDone = onDone
        _displayedMonth = State(initialValue: Calendar.current.monthStart(for: item.wrappedValue.endDate))
    }

    var body: some View {
        ZStack {
            Color(hex: "#F2F2F7")
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 14) {
                    calendarCard
                    repeatCard
                    countDaysCard
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 34)
            }
            .scrollIndicators(.hidden)
        }
        .dynamicTypeSize(.medium)
        .safeAreaInset(edge: .top) {
            calendarTopBar
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 10)
                .background(Color(hex: "#F2F2F7").opacity(0.94))
        }
    }

    private var calendarTopBar: some View {
        ZStack {
            HStack {
                Button {
                    Haptics.impact(.light)
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 22, weight: .regular))
                        .foregroundStyle(.black)
                        .frame(width: 50, height: 50)
                        .liquidGlass(in: Circle(), interactive: true)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close")

                Spacer(minLength: 0)

                Button {
                    Haptics.impact(.medium)
                    onDone()
                } label: {
                    Image(systemName: "checkmark")
                        .font(.system(size: 23, weight: .regular))
                        .foregroundStyle(.white)
                        .frame(width: 50, height: 50)
                        .background {
                            Circle().fill(Color(hex: "#1297F5").opacity(0.9))
                        }
                        .liquidGlass(in: Circle(), tint: Color(hex: "#1297F5").opacity(0.64), interactive: true)
                        .shadow(color: Color(hex: "#1297F5").opacity(0.25), radius: 22, x: 0, y: 13)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Save date")
            }

            HStack(spacing: 8) {
                Text(kindLabel)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(.black)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.black.opacity(0.35))
            }
            .frame(height: 42)
            .padding(.horizontal, 18)
            .liquidGlass(in: Capsule(), interactive: true)
        }
    }

    private var calendarCard: some View {
        VStack(spacing: 0) {
            HStack {
                Text(monthTitle)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.black)

                Image(systemName: "chevron.right")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(blue)

                Spacer(minLength: 0)

                Button {
                    Haptics.selection()
                    changeMonth(by: -1)
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(.black.opacity(0.24))
                        .frame(width: 42, height: 42)
                }
                .buttonStyle(.plain)

                Button {
                    Haptics.selection()
                    changeMonth(by: 1)
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(blue)
                        .frame(width: 42, height: 42)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 18)
            .padding(.top, 22)
            .padding(.bottom, 18)

            LazyVGrid(columns: columns, spacing: 20) {
                ForEach(weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.black.opacity(0.42))
                        .frame(maxWidth: .infinity)
                }

                ForEach(Array(calendarDays.enumerated()), id: \.offset) { _, date in
                    if let date {
                        dayButton(for: date)
                    } else {
                        Color.clear
                            .frame(height: 44)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 22)

            HStack(spacing: 14) {
                Image(systemName: "circle.inset.filled")
                    .font(.system(size: 23, weight: .medium))
                    .foregroundStyle(Color(hex: "#173957"))
                    .frame(width: 50, height: 50)
                    .background(.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.black.opacity(0.07), lineWidth: 1)
                    }

                Text("All day event")
                    .font(.system(size: 19, weight: .regular))
                    .foregroundStyle(.black)

                Spacer(minLength: 0)

                Toggle("", isOn: $allDayEvent)
                    .labelsHidden()
                    .tint(Color(hex: "#34C759"))
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)

            Divider()

            HStack {
                Text("Total:")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(.black.opacity(0.45))
                Text(totalDaysText)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.black.opacity(0.55))

                Spacer(minLength: 0)

                Button {
                    Haptics.selection()
                    item.startDate = Calendar.current.startOfDay(for: Date())
                    if item.endDate <= item.startDate {
                        item.endDate = Calendar.current.date(byAdding: .day, value: 7, to: item.startDate) ?? item.startDate
                        displayedMonth = calendar.monthStart(for: item.endDate)
                    }
                } label: {
                    Text("Add start date")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(blue)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
        }
        .editorCard(cornerRadius: 24)
    }

    private var repeatCard: some View {
        Button {
            Haptics.selection()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "repeat")
                    .font(.system(size: 21, weight: .semibold))
                    .foregroundStyle(Color(hex: "#173957"))
                    .frame(width: 50, height: 50)
                    .background(.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.black.opacity(0.07), lineWidth: 1)
                    }

                Text("Repeat")
                    .font(.system(size: 20, weight: .regular))
                    .foregroundStyle(.black)

                Spacer(minLength: 0)

                Text("No repeat")
                    .font(.system(size: 19, weight: .regular))
                    .foregroundStyle(.black)

                Image(systemName: "chevron.right")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.black.opacity(0.32))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 14)
            .editorCard()
        }
        .buttonStyle(.plain)
    }

    private var countDaysCard: some View {
        HStack(spacing: 14) {
            Image(systemName: "number")
                .font(.system(size: 21, weight: .semibold))
                .foregroundStyle(Color(hex: "#173957"))
                .frame(width: 50, height: 50)
                .background(.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.black.opacity(0.07), lineWidth: 1)
                }

            Text("Count all days")
                .font(.system(size: 20, weight: .regular))
                .foregroundStyle(.black)

            Spacer(minLength: 0)

            Toggle("", isOn: $countAllDays)
                .labelsHidden()
                .tint(Color(hex: "#34C759"))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 14)
        .editorCard()
    }

    private func dayButton(for date: Date) -> some View {
        let isSelected = calendar.isDate(date, inSameDayAs: item.endDate)
        let isToday = calendar.isDateInToday(date)
        let isPast = calendar.startOfDay(for: date) < calendar.startOfDay(for: Date())

        return Button {
            Haptics.selection()
            setEndDate(date)
        } label: {
            Text("\(calendar.component(.day, from: date))")
                .font(.system(size: 23, weight: .regular))
                .foregroundStyle(isSelected || isToday ? blue : (isPast ? .black.opacity(0.18) : .black))
                .frame(width: 44, height: 44)
                .background {
                    if isSelected {
                        Circle().fill(blue.opacity(0.12))
                    }
                }
        }
        .buttonStyle(.plain)
    }

    private var monthTitle: String {
        Self.monthFormatter.string(from: displayedMonth)
    }

    private var calendarDays: [Date?] {
        let monthStart = calendar.monthStart(for: displayedMonth)
        let range = calendar.range(of: .day, in: .month, for: monthStart) ?? 1..<31
        let firstWeekday = calendar.component(.weekday, from: monthStart)
        let mondayBasedOffset = (firstWeekday + 5) % 7

        var dates: [Date?] = Array(repeating: nil, count: mondayBasedOffset)
        for day in range {
            var components = calendar.dateComponents([.year, .month], from: monthStart)
            components.day = day
            dates.append(calendar.date(from: components))
        }

        while dates.count % 7 != 0 {
            dates.append(nil)
        }
        return dates
    }

    private var totalDaysText: String {
        let start = calendar.startOfDay(for: item.startDate)
        let end = calendar.startOfDay(for: item.endDate)
        let days = max(calendar.dateComponents([.day], from: start, to: end).day ?? 0, 0)
        return "\(days) \(days == 1 ? "day" : "days")"
    }

    private func changeMonth(by offset: Int) {
        displayedMonth = calendar.date(byAdding: .month, value: offset, to: displayedMonth) ?? displayedMonth
    }

    private func setEndDate(_ date: Date) {
        let time = calendar.dateComponents([.hour, .minute, .second], from: item.endDate)
        var components = calendar.dateComponents([.year, .month, .day], from: date)
        components.hour = time.hour
        components.minute = time.minute
        components.second = time.second
        let newEnd = calendar.date(from: components) ?? date
        item.endDate = newEnd

        if item.endDate <= item.startDate {
            item.startDate = calendar.date(byAdding: .day, value: -7, to: item.endDate) ?? item.startDate
        }
    }

    private static let monthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateFormat = "LLLL yyyy"
        return formatter
    }()
}

private struct EditableEditorPreviewCard: View {
    @Binding var item: ProgressItem
    let isTitleFocused: FocusState<Bool>.Binding
    let onDateTap: () -> Void

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: ProgressWidgetMetrics.cardCornerRadius, style: .continuous)
                .fill(background)

            switch item.style {
            case .aqua:
                editableRingCard
            case .grid:
                editableBlockGrid
            case .glow:
                editableGlowPanel
            case .retro:
                editableIconBar
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: ProgressWidgetMetrics.cardCornerRadius, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 16, x: 0, y: 8)
    }

    private var background: Color { Color(hex: item.backgroundHex) }
    private var tint: Color { Color(hex: item.tintHex) }
    private var progress: Double { item.progress }
    private var percentageText: String { progress.formatted(.percent.precision(.fractionLength(0))) }
    private var timeText: String {
        let raw = item.homeTimeText().replacingOccurrences(of: "\n", with: " ")
        if raw.hasPrefix("In ") {
            return "\(raw.dropFirst(3)) left"
        }
        return raw
    }

    private func titleField(color: Color, size: CGFloat, maxWidth: CGFloat? = nil) -> some View {
        TextField("Event name", text: $item.title)
            .font(.system(size: size, weight: .bold, design: .rounded))
            .foregroundStyle(color)
            .tint(color)
            .submitLabel(.done)
            .focused(isTitleFocused)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .textFieldStyle(.plain)
            .frame(maxWidth: maxWidth, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture {
                Haptics.selection()
            }
    }

    private func dateButton(_ text: String, color: Color, size: CGFloat, alignment: Alignment = .leading) -> some View {
        Button {
            onDateTap()
        } label: {
            Text(text)
                .font(.system(size: size, weight: .bold, design: .rounded))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.45)
                .frame(maxWidth: .infinity, alignment: alignment)
        }
        .buttonStyle(.plain)
    }

    private var editableRingCard: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(alignment: .leading, spacing: 6) {
                titleField(color: .black, size: 25, maxWidth: 245)
                dateButton(timeText, color: .black.opacity(0.45), size: 23)

                Spacer(minLength: 0)
            }
            .padding(22)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            ZStack {
                Circle()
                    .stroke(tint.opacity(0.24), lineWidth: 16)
                Circle()
                    .trim(from: 0, to: max(progress, 0.03))
                    .stroke(tint, style: StrokeStyle(lineWidth: 16, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            .frame(width: 74, height: 74)
            .padding(22)
        }
    }

    private var editableBlockGrid: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                titleField(color: .black, size: 30)
                Spacer(minLength: 8)
                dateButton(percentageText, color: .black.opacity(0.52), size: 34, alignment: .trailing)
                    .frame(width: 112)
            }

            Spacer(minLength: 18)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 20), spacing: 7) {
                ForEach(0..<80, id: \.self) { index in
                    let filled = Double(index + 1) / 80.0 <= progress
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(filled ? tint : .clear)
                        .overlay {
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .stroke(tint.opacity(0.82), lineWidth: filled ? 0 : 1.6)
                        }
                        .aspectRatio(1, contentMode: .fit)
                }
            }
            .frame(maxHeight: 94)
        }
        .padding(22)
    }

    private var editableGlowPanel: some View {
        ZStack(alignment: .topTrailing) {
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [tint.opacity(0.92), Color(hex: "#AA00FF"), tint.opacity(0.72)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 164, height: 116)
                .blur(radius: 15)
                .offset(x: 18, y: -18)

            VStack(alignment: .leading, spacing: 10) {
                titleField(color: .white, size: 30, maxWidth: 250)
                dateButton(timeText, color: .white.opacity(0.45), size: 28)
                Spacer(minLength: 0)
            }
            .padding(22)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    private var editableIconBar: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 18) {
                Image(systemName: item.icon)
                    .font(.system(size: 38, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 68, height: 68)
                    .background(tint, in: RoundedRectangle(cornerRadius: 18, style: .continuous))

                VStack(alignment: .leading, spacing: 5) {
                    titleField(color: .black, size: 30)
                    dateButton(timeText, color: .black.opacity(0.45), size: 27)
                }
            }

            Spacer(minLength: 18)

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(.black.opacity(0.12))
                    Capsule().fill(tint).frame(width: max(proxy.size.width * progress, 18))
                }
            }
            .frame(height: 20)
        }
        .padding(22)
    }

}

private struct EditorPreviewCard: View {
    let item: ProgressItem

    var body: some View {
        WidgetCardView(item: item, date: .now)
        .clipShape(RoundedRectangle(cornerRadius: ProgressWidgetMetrics.cardCornerRadius, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 16, x: 0, y: 8)
    }
}

private struct PaletteSwatch: View {
    let value: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Circle()
                .fill(Color(hex: value))
                .frame(width: 44, height: 44)
                .overlay {
                    Circle()
                        .stroke(isSelected ? Color.black.opacity(0.28) : Color.black.opacity(0.12), lineWidth: isSelected ? 3 : 1)
                }
                .background(Color.black.opacity(0.05), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private extension Calendar {
    func monthStart(for date: Date) -> Date {
        let components = dateComponents([.year, .month], from: date)
        return self.date(from: components) ?? date
    }
}

private extension View {
    func editorCard(cornerRadius: CGFloat = 24) -> some View {
        self
            .background(.white, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .shadow(color: .black.opacity(0.02), radius: 12, x: 0, y: 6)
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
