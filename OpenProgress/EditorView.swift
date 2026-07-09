import SwiftUI
import UIKit

struct EditorView: View {
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isTitleFocused: Bool

    @State private var draft: ProgressItem
    @State private var selectedPanel: EditorPanel = .date
    @State private var showingDateEditor = false
    @State private var isNoteExpanded = false
    @State private var note = ""
    @State private var showPercentage = false
    @State private var selectedFontWeight: EditorFontWeight = .regular
    @State private var direction: DirectionOption = .normal
    @State private var scrollResetToken = UUID()

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
        .safeAreaInset(edge: .top) {
            topBar
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 10)
                .background(Color(hex: "#F2F2F7").opacity(0.94))
        }
        .safeAreaInset(edge: .bottom) {
            bottomControl
                .padding(.bottom, 12)
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
        .sensoryFeedback(.selection, trigger: selectedPanel)
        .sensoryFeedback(.impact(weight: .light), trigger: isNoteExpanded)
        .sensoryFeedback(.selection, trigger: showPercentage)
        .sensoryFeedback(.selection, trigger: selectedFontWeight)
        .sensoryFeedback(.selection, trigger: direction)
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
        VStack(spacing: 0) {
            EditorPreviewCard(item: draft)
                .aspectRatio(ProgressWidgetMetrics.mediumAspectRatio, contentMode: .fit)
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 14)
        }
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
            .frame(height: 26)
            .offset(y: 26)
            .allowsHitTesting(false)
        }
        .zIndex(2)
    }

    private var panelScroll: some View {
        ScrollViewReader { proxy in
            ScrollView {
                Color.clear
                    .frame(height: 0)
                    .id(scrollResetToken)

                Group {
                    switch selectedPanel {
                    case .date:
                        datePanel
                    case .measure:
                        measurePanel
                    case .paint:
                        paintPanel
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 156)
                .transition(.opacity)
            }
            .scrollIndicators(.hidden)
            .mask {
                VStack(spacing: 0) {
                    LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom)
                        .frame(height: 22)
                    Color.black
                }
            }
            .onChange(of: selectedPanel) { _, _ in
                scrollResetToken = UUID()
                DispatchQueue.main.async {
                    withAnimation(.easeOut(duration: 0.18)) {
                        proxy.scrollTo(scrollResetToken, anchor: .top)
                    }
                }
            }
        }
        .animation(.spring(response: 0.32, dampingFraction: 0.88), value: selectedPanel)
    }

    private var datePanel: some View {
        VStack(spacing: 14) {
            titleField
            dateDetailsCard
            noteCard
        }
    }

    private var measurePanel: some View {
        VStack(spacing: 14) {
            VStack(spacing: 0) {
                HStack(spacing: 14) {
                    iconTile("ruler")

                    Text("Show time")
                        .font(.system(size: 19, weight: .regular))
                        .foregroundStyle(.black)

                    Spacer(minLength: 10)

                    HStack(spacing: 0) {
                        Button {
                            Haptics.selection()
                            showPercentage = false
                        } label: {
                            Image(systemName: "clock.fill")
                                .font(.system(size: 17, weight: .semibold))
                                .frame(width: 50, height: 34)
                                .foregroundStyle(showPercentage ? .black.opacity(0.45) : .white)
                                .background {
                                    if !showPercentage {
                                        Capsule().fill(.black)
                                    }
                                }
                        }

                        Button {
                            Haptics.selection()
                            showPercentage = true
                        } label: {
                            Text("%")
                                .font(.system(size: 22, weight: .regular))
                                .frame(width: 50, height: 34)
                                .foregroundStyle(showPercentage ? .white : .black)
                                .background {
                                    if showPercentage {
                                        Capsule().fill(.black)
                                    }
                                }
                        }
                    }
                    .padding(3)
                    .background(Color.black.opacity(0.08), in: Capsule())
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 14)

                Divider()

                HStack(alignment: .top, spacing: 14) {
                    iconTile("slider.horizontal.3")

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Time units")
                            .font(.system(size: 19, weight: .regular))
                            .foregroundStyle(.black)

                        Text("Units to show as text. Updates in real time on your widgets.")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundStyle(.black.opacity(0.45))
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 8)

                    Text("Live format")
                        .font(.system(size: 18, weight: .regular))
                        .foregroundStyle(.black)
                        .lineLimit(1)

                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.black.opacity(0.38))
                        .padding(.top, 4)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 14)
            }
            .editorCard()

            Button {
                Haptics.selection()
            } label: {
                HStack(spacing: 14) {
                    iconTile("textformat.size")

                    Text("Accessory indicator")
                        .font(.system(size: 19, weight: .regular))
                        .foregroundStyle(.black)

                    Spacer(minLength: 8)

                    Text("... left")
                        .font(.system(size: 18, weight: .regular))
                        .foregroundStyle(.black)

                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.black.opacity(0.38))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 14)
                .editorCard()
            }
            .buttonStyle(.plain)
        }
    }

    private var paintPanel: some View {
        VStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 14) {
                    iconTile("theatermasks.fill")

                    Text("Theme")
                        .font(.system(size: 19, weight: .regular))
                        .foregroundStyle(.black)

                    Spacer(minLength: 8)

                    Text("\(draft.style.title) Style")
                        .font(.system(size: 19, weight: .regular))
                        .foregroundStyle(.black)
                }

                ScrollView(.horizontal) {
                    HStack(spacing: 18) {
                        ForEach(ProgressStyle.allCases) { style in
                            Button {
                                Haptics.selection()
                                draft.style = style
                            } label: {
                                ThemePreviewCard(item: draft, style: style, isSelected: draft.style == style)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 52)
                    .padding(.bottom, 8)
                }
                .scrollIndicators(.hidden)
                .scrollClipDisabled()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 14)
            .editorCard()

            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 14) {
                    iconTile("paintpalette.fill")

                    Text("Palette")
                        .font(.system(size: 19, weight: .regular))
                        .foregroundStyle(.black)
                }

                HStack(spacing: 12) {
                    Button {
                        Haptics.selection()
                    } label: {
                        Label("Add image", systemImage: "photo.badge.plus")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(Color(hex: "#1297F5"))
                            .frame(height: 44)
                            .padding(.horizontal, 18)
                            .background(Color(hex: "#1297F5").opacity(0.12), in: Capsule())
                    }
                    .buttonStyle(.plain)

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

            Button {
                Haptics.selection()
                selectedFontWeight = selectedFontWeight.next
            } label: {
                HStack(spacing: 14) {
                    iconTile("textformat")

                    Text("Font")
                        .font(.system(size: 19, weight: .regular))
                        .foregroundStyle(.black)

                    Spacer(minLength: 8)

                    Text(selectedFontWeight.title)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.black)
                        .frame(width: 138, height: 46)
                        .background(Color.black.opacity(0.06), in: Capsule())
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 14)
                .editorCard()
            }
            .buttonStyle(.plain)

            Button {
                Haptics.selection()
                direction = direction.next
            } label: {
                HStack(spacing: 14) {
                    iconTile("arrow.triangle.2.circlepath")

                    Text(direction.title)
                        .font(.system(size: 19, weight: .regular))
                        .foregroundStyle(.black.opacity(0.58))

                    Spacer(minLength: 8)

                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(.black.opacity(0.48))
                        .frame(width: 46, height: 38)
                        .background(Color.black.opacity(0.06), in: Capsule())
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 14)
                .editorCard()
            }
            .buttonStyle(.plain)
        }
    }

    private var titleField: some View {
        TextField("Event name", text: $draft.title)
            .font(.system(size: 21, weight: .semibold))
            .multilineTextAlignment(.center)
            .foregroundStyle(.black)
            .tint(Color(hex: "#1297F5"))
            .focused($isTitleFocused)
            .submitLabel(.done)
            .frame(height: 58)
            .padding(.horizontal, 18)
            .background(.white, in: RoundedRectangle(cornerRadius: 29, style: .continuous))
            .shadow(color: .black.opacity(0.02), radius: 12, x: 0, y: 6)
    }

    private var dateDetailsCard: some View {
        VStack(spacing: 0) {
            Button {
                Haptics.selection()
                selectedPanel = .date
                showingDateEditor = true
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

    private var noteCard: some View {
        VStack(spacing: 0) {
            Button {
                Haptics.impact(.light)
                withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                    isNoteExpanded.toggle()
                }
            } label: {
                HStack(spacing: 14) {
                    Image(systemName: "plus")
                        .font(.system(size: 23, weight: .regular))
                        .foregroundStyle(Color(hex: "#1297F5"))
                        .frame(width: 44, height: 44)
                        .background(Color(hex: "#1297F5").opacity(0.10), in: Circle())

                    Text(note.isEmpty ? "Add note" : note)
                        .font(.system(size: 18, weight: .regular))
                        .foregroundStyle(Color(hex: "#1297F5"))
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
            }
            .buttonStyle(.plain)

            if isNoteExpanded {
                TextEditor(text: $note)
                    .font(.system(size: 16, weight: .regular))
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 78)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 14)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .editorCard(cornerRadius: 24)
    }

    private var bottomControl: some View {
        Picker("Section", selection: $selectedPanel) {
            ForEach(EditorPanel.allCases) { panel in
                Image(systemName: panel.systemImage)
                    .tag(panel)
            }
        }
        .pickerStyle(.segmented)
        .frame(width: 236, height: 56)
        .padding(6)
        .liquidGlass(in: Capsule(), tint: .white.opacity(0.2), interactive: true)
        .shadow(color: .black.opacity(0.10), radius: 24, x: 0, y: 12)
        .onChange(of: selectedPanel) { _, _ in
            Haptics.selection()
        }
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

    private func selectPanel(_ panel: EditorPanel) {
        Haptics.selection()
        withAnimation(.spring(response: 0.26, dampingFraction: 0.86)) {
            selectedPanel = panel
        }
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

private struct EditorPreviewCard: View {
    let item: ProgressItem

    private var cardBackground: Color { Color(hex: item.backgroundHex) }
    private var ringTint: Color { Color(hex: item.tintHex) }
    private var title: String { item.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Event name" : item.title }
    private var timeText: String {
        let raw = item.homeTimeText().replacingOccurrences(of: "\n", with: " ")
        if raw.hasPrefix("In ") {
            return "\(raw.dropFirst(3)) left"
        }
        return raw
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            RoundedRectangle(cornerRadius: ProgressWidgetMetrics.cardCornerRadius, style: .continuous)
                .fill(cardBackground)

            ZStack {
                Circle()
                    .stroke(Color.black.opacity(0.16), lineWidth: 16)
                Circle()
                    .trim(from: 0, to: max(item.progress, 0.03))
                    .stroke(ringTint, style: StrokeStyle(lineWidth: 16, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            .frame(width: 72, height: 72)
            .padding(.trailing, 22)
            .padding(.bottom, 22)

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.62)

                Text(timeText)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.58))
                    .lineLimit(1)
                    .minimumScaleFactor(0.56)

                Spacer(minLength: 0)
            }
            .padding(.top, 24)
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .clipShape(RoundedRectangle(cornerRadius: ProgressWidgetMetrics.cardCornerRadius, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 16, x: 0, y: 8)
    }
}

private struct ThemePreviewCard: View {
    let item: ProgressItem
    let style: ProgressStyle
    let isSelected: Bool

    private var previewItem: ProgressItem {
        var copy = item
        copy.style = style
        return copy
    }

    var body: some View {
        VStack(spacing: 8) {
            EditorPreviewCard(item: previewItem)
                .aspectRatio(ProgressWidgetMetrics.mediumAspectRatio, contentMode: .fit)
                .frame(width: 154)
                .opacity(isSelected ? 1 : 0.45)

            Circle()
                .fill(isSelected ? .black : .clear)
                .frame(width: 10, height: 10)
        }
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

private enum EditorPanel: String, CaseIterable, Identifiable {
    case date
    case measure
    case paint

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .date:
            return "calendar"
        case .measure:
            return "ruler"
        case .paint:
            return "paintbrush.pointed.fill"
        }
    }
}

private enum EditorFontWeight: String, CaseIterable {
    case regular
    case medium
    case bold

    var title: String {
        switch self {
        case .regular:
            return "Regular"
        case .medium:
            return "Medium"
        case .bold:
            return "Bold"
        }
    }

    var next: EditorFontWeight {
        let all = Self.allCases
        guard let index = all.firstIndex(of: self) else { return .regular }
        return all[(index + 1) % all.count]
    }
}

private enum DirectionOption: String, CaseIterable {
    case normal
    case reverse

    var title: String {
        switch self {
        case .normal:
            return "Normal direction"
        case .reverse:
            return "Reverse direction"
        }
    }

    var next: DirectionOption {
        self == .normal ? .reverse : .normal
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
