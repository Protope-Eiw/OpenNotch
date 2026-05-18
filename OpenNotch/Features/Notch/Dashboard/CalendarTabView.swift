import SwiftUI
import Combine
import EventKit
internal import AppKit

struct CalendarTabView: View {
    @StateObject private var store = CalendarStore()
    @State private var selectedDate = Date()
    @State private var displayedMonth: Date = {
        let c = Calendar.current
        return c.date(from: c.dateComponents([.year, .month], from: Date())) ?? Date()
    }()
    @State private var showEditSheet = false
    @State private var editingEvent: EKEvent? = nil
    @State private var showDeleteConfirm = false
    @State private var authStatus: EKAuthorizationStatus = EKEventStore.authorizationStatus(for: .event)
    private static var eventWindow: NSWindow?

    var body: some View {
        Group {
            switch authStatus {
        case .notDetermined:
            if store.isRequesting {
                VStack(spacing: 10) {
                    ProgressView()
                        .controlSize(.small)
                        .scaleEffect(0.8)
                    Text(L10n.app("calendar.requesting", fallback: "Requesting access…"))
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.3))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                calendarPermissionView(
                    icon: "calendar",
                    message: L10n.app("calendar.needPermission", fallback: "Calendar access needed"),
                    buttonLabel: L10n.app("calendar.grantAccess", fallback: "Grant Access"),
                    action: { store.requestAccess() }
                )
            }
        case .denied, .restricted:
            calendarPermissionView(
                icon: "calendar.badge.exclamationmark",
                message: L10n.app("calendar.accessDenied", fallback: "Calendar access denied"),
                buttonLabel: L10n.app("calendar.openSettings", fallback: "Open System Settings"),
                action: { store.openPrivacySettings() }
            )
        default:
            HStack(spacing: 0) {
                MiniCalendarView(
                    selectedDate: $selectedDate,
                    displayedMonth: $displayedMonth,
                    eventDates: store.eventDates,
                    reminderDates: store.reminderDates
                )
                .frame(width: 162)
                .padding(.leading, 12)

                Rectangle()
                    .fill(Color.white.opacity(0.07))
                    .frame(width: 1)
                    .padding(.vertical, 10)
                    .padding(.leading, 12)

                CalendarEventPane(
                    date: selectedDate,
                    events: store.events,
                    reminders: store.reminders,
                    version: store.version,
                    onNewEvent: { showEditSheet = true; editingEvent = nil },
                    onEditEvent: { event in
                        editingEvent = event
                        showEditSheet = true
                    },
                    onDeleteEvent: { event in
                        editingEvent = event
                        showDeleteConfirm = true
                    }
                )
            }
            .onAppear {
                store.load(for: selectedDate)
                store.loadReminders()
            }
            .onChange(of: selectedDate) { _, d in store.load(for: d) }
            .onChange(of: showEditSheet) { _, show in
                if show { presentEventWindow() } else { closeEventWindow() }
            }
            .onDisappear { Self.eventWindow = nil }
            .alert(L10n.app("calendar.deleteConfirm", fallback: "Delete this event?"), isPresented: $showDeleteConfirm) {
                Button(L10n.app("calendar.delete", fallback: "Delete"), role: .destructive) {
                    if let event = editingEvent {
                        store.removeEvent(event)
                    }
                    editingEvent = nil
                }
                Button(L10n.app("calendar.cancel", fallback: "Cancel"), role: .cancel) {
                    editingEvent = nil
                }
            }
            }
        }
        .onReceive(store.$authStatus) { newStatus in
            authStatus = newStatus
        }
        .task {
            await store.warmUp()
            authStatus = store.authStatus
        }
    }

    private func presentEventWindow() {
        Self.eventWindow?.close()
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 340, height: 420),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.backgroundColor = NSColor(Color(white: 0.28))
        window.level = .floating
        window.center()

        window.delegate = Self.makeDelegate { Self.eventWindow = nil }
        let view = CalendarEventCreatorView(
            store: store,
            defaultDate: selectedDate,
            editingEvent: editingEvent,
            onDismiss: {
                window.close()
                Self.eventWindow = nil
            }
        )
        window.contentView = NSHostingView(rootView: view)
        window.makeKeyAndOrderFront(nil)
        Self.eventWindow = window
    }

    private func closeEventWindow() {
        Self.eventWindow?.close()
        Self.eventWindow = nil
    }

    private static func makeDelegate(onClose: @escaping () -> Void) -> EventWindowDelegate {
        let d = EventWindowDelegate()
        d.onClose = onClose
        return d
    }

    private func calendarPermissionView(
        icon: String, message: String, buttonLabel: String, action: @escaping () -> Void
    ) -> some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundStyle(.white.opacity(0.2))
            Text(message)
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.3))
            Button(buttonLabel, action: action)
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.55))
                .buttonStyle(.plain)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Mini Calendar

struct MiniCalendarView: View {
    @Binding var selectedDate: Date
    @Binding var displayedMonth: Date
    var eventDates: Set<String> = []
    var reminderDates: Set<String> = []

    private let cal = Calendar.current

    private var weekdaySymbols: [String] {
        var s = cal.veryShortWeekdaySymbols
        s.append(s.removeFirst())
        return s
    }

    private func dateKey(_ date: Date) -> String {
        let c = Calendar.current
        return "\(c.component(.year, from: date))-\(c.component(.month, from: date))-\(c.component(.day, from: date))"
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Button { navigate(-1) } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 9, weight: .semibold))
                        .frame(width: 22, height: 22)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white.opacity(0.45))

                Spacer()

                Text(monthYearString)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white)
                    .onTapGesture { jumpToToday() }

                Spacer()

                Button { navigate(1) } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .frame(width: 22, height: 22)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white.opacity(0.45))
            }
            .padding(.horizontal, 6)
            .padding(.top, 8)
            .padding(.bottom, 3)

            HStack(spacing: 0) {
                ForEach(weekdaySymbols, id: \.self) { sym in
                    Text(sym)
                        .font(.system(size: 8.5, weight: .medium))
                        .foregroundStyle(.white.opacity(0.28))
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 2)

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 1), count: 7),
                spacing: 1
            ) {
                ForEach(gridCells, id: \.index) { cell in
                    if let date = cell.date {
                        MiniDateCell(
                            day: cal.component(.day, from: date),
                            isToday: cal.isDateInToday(date),
                            isSelected: cal.isDate(date, inSameDayAs: selectedDate),
                            hasEvent: eventDates.contains(dateKey(date)),
                            hasReminder: reminderDates.contains(dateKey(date))
                        ) {
                            selectedDate = date
                        }
                    } else {
                        Color.clear.frame(height: 19)
                    }
                }
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 8)
        }
    }

    private var monthYearString: String {
        let f = DateFormatter()
        f.dateFormat = "MMM yyyy"
        f.locale = Locale(identifier: L10n.appLanguageIdentifier)
        return f.string(from: displayedMonth)
    }

    private func navigate(_ delta: Int) {
        guard let next = cal.date(byAdding: .month, value: delta, to: displayedMonth) else { return }
        displayedMonth = cal.date(from: cal.dateComponents([.year, .month], from: next)) ?? next
    }

    private func jumpToToday() {
        let today = Date()
        selectedDate = today
        displayedMonth = cal.date(from: cal.dateComponents([.year, .month], from: today)) ?? today
    }

    private struct Cell { let index: Int; let date: Date? }

    private var gridCells: [Cell] {
        guard let start = cal.date(from: cal.dateComponents([.year, .month], from: displayedMonth)) else { return [] }
        let daysInMonth = cal.range(of: .day, in: .month, for: start)?.count ?? 30
        let firstWeekday = cal.component(.weekday, from: start)
        let leading = (firstWeekday + 5) % 7

        var cells: [Cell] = []
        var idx = 0
        for _ in 0..<leading          { cells.append(Cell(index: idx, date: nil)); idx += 1 }
        for d in 0..<daysInMonth      { cells.append(Cell(index: idx, date: cal.date(byAdding: .day, value: d, to: start))); idx += 1 }
        let rem = cells.count % 7
        if rem != 0 { for _ in 0..<(7 - rem) { cells.append(Cell(index: idx, date: nil)); idx += 1 } }
        return cells
    }
}

struct MiniDateCell: View {
    let day: Int
    let isToday: Bool
    let isSelected: Bool
    var hasEvent: Bool = false
    var hasReminder: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .bottom) {
                Text("\(day)")
                    .font(.system(size: 10.5, weight: isToday ? .semibold : .regular))
                    .foregroundStyle(isToday || isSelected ? .white : .white.opacity(0.5))
                    .frame(maxWidth: .infinity)
                    .frame(height: 19)
                    .background(
                        isToday     ? Color.accentColor :
                        isSelected  ? Color.white.opacity(0.18) : Color.clear
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 4))

                if hasEvent {
                    Circle()
                        .fill(Color.white.opacity(0.6))
                        .frame(width: 3, height: 3)
                        .offset(y: -1.5)
                } else if hasReminder {
                    Circle()
                        .fill(Color.orange.opacity(0.7))
                        .frame(width: 3, height: 3)
                        .offset(y: -1.5)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Calendar Event Pane

struct CalendarEventPane: View {
    let date: Date
    let events: [EKEvent]
    let reminders: [EKReminder]
    let version: Int
    var onNewEvent: (() -> Void)? = nil
    var onEditEvent: ((EKEvent) -> Void)? = nil
    var onDeleteEvent: ((EKEvent) -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(dateLabel)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.45))
                Spacer()
                Button(action: { onNewEvent?() }) {
                    Image(systemName: "plus")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.45))
                        .frame(width: 20, height: 20)
                        .background(Color.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                .buttonStyle(.plain)
                .help(L10n.app("calendar.newEvent", fallback: "New event"))
            }
            .padding(.leading, 12)
            .padding(.trailing, 10)
            .padding(.top, 8)
            .padding(.bottom, 5)

            Divider().opacity(0.08)

            if events.isEmpty && reminders.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "calendar.badge.checkmark")
                        .font(.system(size: 20))
                        .foregroundStyle(.white.opacity(0.12))
                    Text(Calendar.current.isDateInToday(date) ? L10n.app("calendar.noEventsToday", fallback: "No events today") : L10n.app("calendar.noEvents", fallback: "No events"))
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.25))
                    Button(action: { onNewEvent?() }) {
                        Text(L10n.app("calendar.addEvent", fallback: "Add Event"))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.blue.opacity(0.7))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.white.opacity(0.06))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 0) {
                            if !reminders.isEmpty {
                                VStack(spacing: 0) {
                                    HStack {
                                        Text(L10n.app("calendar.reminders", fallback: "Reminders"))
                                            .font(.system(size: 8.5, weight: .semibold))
                                            .foregroundStyle(.orange.opacity(0.6))
                                            .padding(.leading, 4)
                                            .padding(.top, 4)
                                            .padding(.bottom, 2)
                                        Spacer()
                                    }
                                    ForEach(reminders, id: \.self) { reminder in
                                        CalendarReminderRow(reminder: reminder)
                                        if reminder != reminders.last {
                                            Divider().opacity(0.08).padding(.leading, 11)
                                        }
                                    }
                                }
                            }
                            if !events.isEmpty {
                                if !reminders.isEmpty {
                                    Divider().opacity(0.12).padding(.vertical, 2)
                                }
                                ForEach(events, id: \.eventIdentifier) { event in
                                    CalendarEventRow(
                                        event: event,
                                        onEdit: { onEditEvent?(event) },
                                        onDelete: { onDeleteEvent?(event) }
                                    ).id(event.eventIdentifier)
                                    if event.eventIdentifier != events.last?.eventIdentifier {
                                        Divider().opacity(0.08).padding(.leading, 11)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                    }
                    .onAppear { scrollToUpcoming(proxy) }
                    .onChange(of: version) { _, _ in scrollToUpcoming(proxy) }
                }
            }
        }
    }

    private var dateLabel: String {
        let c = Calendar.current
        if c.isDateInToday(date)     { return L10n.app("calendar.today", fallback: "Today") }
        if c.isDateInYesterday(date) { return L10n.app("calendar.yesterday", fallback: "Yesterday") }
        if c.isDateInTomorrow(date)  { return L10n.app("calendar.tomorrow", fallback: "Tomorrow") }
        let f = DateFormatter()
        f.dateFormat = DateFormatter.dateFormat(
            fromTemplate: c.component(.year, from: date) == c.component(.year, from: Date()) ? "Md" : "yMd",
            options: 0, locale: Locale(identifier: L10n.appLanguageIdentifier)
        )
        return f.string(from: date)
    }

    private func scrollToUpcoming(_ proxy: ScrollViewProxy) {
        let now = Date()
        let target = events.first(where: { !$0.isAllDay && $0.endDate > now })
            ?? events.first(where: { $0.isAllDay })
            ?? events.last
        if let id = target?.eventIdentifier {
            withTransaction(Transaction(animation: nil)) { proxy.scrollTo(id, anchor: .top) }
        }
    }
}

// MARK: - Calendar Event Row

struct CalendarEventRow: View {
    let event: EKEvent
    var onEdit: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil

    var body: some View {
        Group {
            if event.isAllDay {
                allDayBanner
            } else {
                timedEventRow
            }
        }
        .onTapGesture(count: 2) { onEdit?() }
        .contextMenu {
            Button(L10n.app("calendar.edit", fallback: "Edit"), action: { onEdit?() })
            Divider()
            Button(L10n.app("calendar.delete", fallback: "Delete"), role: .destructive, action: { onDelete?() })
        }
    }

    private var allDayBanner: some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 1.5)
                .fill(Color(cgColor: event.calendar.cgColor))
                .frame(width: 3)

            Circle()
                .fill(Color(cgColor: event.calendar.cgColor))
                .frame(width: 5, height: 5)

            Text(event.title ?? L10n.app("calendar.untitled", fallback: "Untitled"))
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(Color(cgColor: event.calendar.cgColor).opacity(0.9))
                .lineLimit(1)

            Spacer(minLength: 0)

            Text(L10n.app("calendar.allDay", fallback: "All Day"))
                .font(.system(size: 8, weight: .medium))
                .foregroundStyle(Color(cgColor: event.calendar.cgColor).opacity(0.55))
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(Color(cgColor: event.calendar.cgColor).opacity(0.12))
                .clipShape(Capsule())
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 6)
        .background(Color(cgColor: event.calendar.cgColor).opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private var timedEventRow: some View {
        HStack(alignment: .top, spacing: 8) {
            RoundedRectangle(cornerRadius: 1.5)
                .fill(Color(cgColor: event.calendar.cgColor))
                .frame(width: 3)
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 2) {
                Text(event.title ?? "Untitled")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                if let loc = event.location, !loc.isEmpty {
                    Text(loc)
                        .font(.system(size: 9))
                        .foregroundStyle(.white.opacity(0.38))
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)

            VStack(alignment: .trailing, spacing: 2) {
                Text(fmt(event.startDate))
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.white.opacity(0.65))
                Text(fmt(event.endDate))
                    .font(.system(size: 9))
                    .foregroundStyle(.white.opacity(0.3))
            }
        }
        .padding(.vertical, 5)
        .opacity(isPast ? 0.45 : 1)
    }

    private var isPast: Bool {
        !event.isAllDay
            && event.endDate < Date()
            && Calendar.current.isDateInToday(event.startDate)
    }

    private func fmt(_ date: Date) -> String {
        let f = DateFormatter()
        f.timeStyle = .short
        f.dateStyle = .none
        return f.string(from: date)
    }
}

// MARK: - Calendar Reminder Row

struct CalendarReminderRow: View {
    let reminder: EKReminder

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: reminder.isCompleted ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 10))
                .foregroundStyle(reminder.isCompleted ? .green.opacity(0.7) : .orange.opacity(0.5))

            Text(reminder.title ?? L10n.app("calendar.untitled", fallback: "Untitled"))
                .font(.system(size: 10.5, weight: .regular))
                .foregroundStyle(reminder.isCompleted ? .white.opacity(0.35) : .white)
                .strikethrough(reminder.isCompleted)
                .lineLimit(1)

            Spacer(minLength: 0)

            if let dueDate = reminder.dueDateComponents?.date {
                Text(fmtReminder(dueDate))
                    .font(.system(size: 8.5))
                    .foregroundStyle(.white.opacity(0.3))
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 6)
    }

    private func fmtReminder(_ date: Date) -> String {
        let f = DateFormatter()
        f.timeStyle = .short
        f.dateStyle = .none
        return f.string(from: date)
    }
}

// MARK: - CalendarStore

private final class EventWindowDelegate: NSObject, NSWindowDelegate {
    var onClose: (() -> Void)?
    func windowWillClose(_ notification: Notification) {
        onClose?()
    }
}

@MainActor
final class CalendarStore: ObservableObject {
    @Published var events: [EKEvent] = []
    @Published var upcomingEvents: [EKEvent] = []
    @Published var reminders: [EKReminder] = []
    @Published var version: Int = 0
    @Published var authStatus: EKAuthorizationStatus = .notDetermined
    @Published var reminderAuthStatus: EKAuthorizationStatus = .notDetermined

    var eventDates: Set<String> {
        Set(events.map { dateKey($0.startDate) })
    }

    var reminderDates: Set<String> {
        Set(reminders.compactMap { r in
            guard let d = r.dueDateComponents?.date else { return nil }
            return dateKey(d)
        })
    }

    var calendars: [EKCalendar] {
        ekStore.calendars(for: .event)
    }

    private let ekStore = EKEventStore.app
    private var activeObserver: NSObjectProtocol?
    private var lastLoadedDate: Date?
    @Published var isRequesting = false
    private var hasWarmedUp = false

    init() {
        reminderAuthStatus = EKEventStore.authorizationStatus(for: .reminder)
        let status = EKEventStore.authorizationStatus(for: .event)
        authStatus = status
        activeObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in self.refresh() }
        }
    }

    deinit {
        if let activeObserver {
            NotificationCenter.default.removeObserver(activeObserver)
        }
    }

    private func dateKey(_ date: Date) -> String {
        let c = Calendar.current
        return "\(c.component(.year, from: date))-\(c.component(.month, from: date))-\(c.component(.day, from: date))"
    }

    func load(for date: Date) {
        lastLoadedDate = date
        let status = EKEventStore.authorizationStatus(for: .event)
        authStatus = status
        guard status == .fullAccess || status == .writeOnly else { return }
        fetch(for: date)
    }

    func loadUpcoming(days: Int = 14) {
        let status = EKEventStore.authorizationStatus(for: .event)
        authStatus = status
        guard status == .fullAccess else {
            upcomingEvents = []
            return
        }
        fetchUpcoming(days: days)
    }

    func loadReminders() {
        let status = EKEventStore.authorizationStatus(for: .reminder)
        reminderAuthStatus = status
        guard status == .fullAccess else { return }
        fetchReminders()
    }

    func requestAccess() {
        isRequesting = true
        let status = EKEventStore.authorizationStatus(for: .event)
        if status == .writeOnly {
            authStatus = status
            fetch(for: lastLoadedDate ?? Date())
            loadReminders()
            isRequesting = false
            return
        }
        guard status == .notDetermined else {
            openPrivacySettings()
            isRequesting = false
            return
        }
        Task {
            do {
                let granted = try await ekStore.requestFullAccessToEvents()
                if granted {
                    authStatus = .fullAccess
                    fetch(for: lastLoadedDate ?? Date())
                    loadReminders()
                } else {
                    authStatus = .denied
                }
            } catch {
                openPrivacySettings()
            }
            isRequesting = false
        }
    }

    /// macOS 15+ returns .notDetermined from authorizationStatus() until
    /// requestFullAccessToEvents() is called at least once per session —
    /// even when the user has already granted access. This call is always
    /// silent for previously-granted permissions (no dialog). For genuinely
    /// undetermined permissions it will show the system dialog.
    /// Must run off the main actor to prevent main thread freeze
    /// when the system permission dialog appears.
    func warmUp() async {
        guard !hasWarmedUp else { return }
        hasWarmedUp = true
        guard await MainActor.run(body: { !isRequesting }) else { return }
        await Self.requestEventAccessOnce()
        let s = EKEventStore.authorizationStatus(for: .event)
        await MainActor.run { authStatus = s }
    }

    nonisolated private static func requestEventAccessOnce() async {
        do {
            _ = try await EKEventStore.app.requestFullAccessToEvents()
        } catch {}
    }

    func openPrivacySettings() {
        NSWorkspace.shared.open(
            URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars")!
        )
    }

    @discardableResult
    func saveEvent(_ event: EKEvent) -> Bool {
        do {
            try ekStore.save(event, span: .thisEvent, commit: true)
            if let date = lastLoadedDate { fetch(for: date) }
            return true
        } catch {
            return false
        }
    }

    @discardableResult
    func removeEvent(_ event: EKEvent) -> Bool {
        do {
            try ekStore.remove(event, span: .thisEvent, commit: true)
            if let date = lastLoadedDate { fetch(for: date) }
            return true
        } catch {
            return false
        }
    }

    private func refresh() {
        let status = EKEventStore.authorizationStatus(for: .event)
        authStatus = status
        if (status == .fullAccess || status == .writeOnly), let date = lastLoadedDate {
            fetch(for: date)
        }
        if status == .fullAccess {
            fetchUpcoming(days: 14)
        }
        let reminderStatus = EKEventStore.authorizationStatus(for: .reminder)
        reminderAuthStatus = reminderStatus
        if reminderStatus == .fullAccess { fetchReminders() }
    }


    private func fetch(for date: Date) {
        let cal   = Calendar.current
        let start = cal.startOfDay(for: date)
        let end   = cal.date(byAdding: .day, value: 1, to: start) ?? start
        let pred  = ekStore.predicateForEvents(withStart: start, end: end, calendars: nil)
        events  = ekStore.events(matching: pred).sorted { $0.startDate < $1.startDate }
        version += 1
    }

    private func fetchUpcoming(days: Int) {
        let now = Date()
        let start = Calendar.current.startOfDay(for: now)
        let end = Calendar.current.date(byAdding: .day, value: days, to: now) ?? now
        let pred = ekStore.predicateForEvents(withStart: start, end: end, calendars: nil)
        upcomingEvents = ekStore.events(matching: pred)
            .filter { $0.endDate > now }
            .sorted { $0.startDate < $1.startDate }
        version += 1
    }

    private func fetchReminders() {
        let predicate = ekStore.predicateForIncompleteReminders(
            withDueDateStarting: nil,
            ending: nil,
            calendars: nil
        )
        ekStore.fetchReminders(matching: predicate) { [weak self] fetched in
            guard let self, let fetched else { return }
            let now = Date()
            let upcoming = fetched.filter { r in
                guard let d = r.dueDateComponents?.date else { return false }
                return d > now.addingTimeInterval(-86400) && d < now.addingTimeInterval(86400 * 14)
            }
            Task { @MainActor in
                self.reminders = upcoming.sorted { a, b in
                    (a.dueDateComponents?.date ?? .distantFuture) < (b.dueDateComponents?.date ?? .distantFuture)
                }
                self.version += 1
            }
        }
    }
}
