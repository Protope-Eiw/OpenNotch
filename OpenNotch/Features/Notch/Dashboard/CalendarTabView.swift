import SwiftUI
import Combine
import EventKit

struct CalendarTabView: View {
    @StateObject private var store = CalendarStore()
    @State private var selectedDate = Date()
    @State private var displayedMonth: Date = {
        let c = Calendar.current
        return c.date(from: c.dateComponents([.year, .month], from: Date())) ?? Date()
    }()

    var body: some View {
        switch store.authStatus {
        case .notDetermined:
            calendarPermissionView(
                icon: "calendar",
                message: L10n.app("calendar.needPermission", fallback: "Calendar access needed"),
                buttonLabel: L10n.app("calendar.grantAccess", fallback: "Grant Access"),
                action: { store.requestAccess() }
            )
        case .denied, .restricted:
            calendarPermissionView(
                icon: "calendar.badge.exclamationmark",
                message: L10n.app("calendar.accessDenied", fallback: "Calendar access denied"),
                buttonLabel: L10n.app("calendar.openSettings", fallback: "Open System Settings"),
                action: { store.openPrivacySettings() }
            )
        default:
            HStack(spacing: 0) {
                MiniCalendarView(selectedDate: $selectedDate, displayedMonth: $displayedMonth)
                    .frame(width: 162)
                Rectangle()
                    .fill(Color.white.opacity(0.07))
                    .frame(width: 1)
                    .padding(.vertical, 10)
                CalendarEventPane(
                    date: selectedDate,
                    events: store.events,
                    version: store.version
                )
            }
            .onAppear { store.load(for: selectedDate) }
            .onChange(of: selectedDate) { _, d in store.load(for: d) }
        }
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

    private let cal = Calendar.current

    private var weekdaySymbols: [String] {
        var s = cal.veryShortWeekdaySymbols
        s.append(s.removeFirst())
        return s
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
                            isSelected: cal.isDate(date, inSameDayAs: selectedDate)
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
    let action: () -> Void

    var body: some View {
        Button(action: action) {
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
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Calendar Event Pane

struct CalendarEventPane: View {
    let date: Date
    let events: [EKEvent]
    let version: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(dateLabel)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.45))
                    .padding(.leading, 12)
                    .padding(.top, 8)
                    .padding(.bottom, 5)
                Spacer()
            }

            Divider().opacity(0.08)

            if events.isEmpty {
                VStack(spacing: 5) {
                    Image(systemName: "calendar.badge.checkmark")
                        .font(.system(size: 16))
                        .foregroundStyle(.white.opacity(0.15))
                    Text(Calendar.current.isDateInToday(date) ? L10n.app("calendar.noEventsToday", fallback: "No events today") : L10n.app("calendar.noEvents", fallback: "No events"))
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.25))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 0) {
                            ForEach(events, id: \.eventIdentifier) { event in
                                CalendarEventRow(event: event).id(event.eventIdentifier)
                                if event.eventIdentifier != events.last?.eventIdentifier {
                                    Divider().opacity(0.08).padding(.leading, 11)
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

    var body: some View {
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
                if event.isAllDay {
                    Text(L10n.app("calendar.allDay", fallback: "All Day"))
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.white.opacity(0.45))
                } else {
                    Text(fmt(event.startDate))
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.white.opacity(0.65))
                    Text(fmt(event.endDate))
                        .font(.system(size: 9))
                        .foregroundStyle(.white.opacity(0.3))
                }
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

// MARK: - CalendarStore

@MainActor
final class CalendarStore: ObservableObject {
    @Published var events: [EKEvent] = []
    @Published var version: Int = 0
    @Published var authStatus: EKAuthorizationStatus = EKEventStore.authorizationStatus(for: .event)

    private let ekStore = EKEventStore.app
    private var activeObserver: NSObjectProtocol?
    private var lastLoadedDate: Date?

    init() {
        activeObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in self.refreshStatus() }
        }
    }

    func load(for date: Date) {
        lastLoadedDate = date
        let status = EKEventStore.authorizationStatus(for: .event)
        authStatus = status
        guard isAuthorized(status) else { return }
        fetch(for: date)
    }

    func requestAccess() {
        Task {
            do {
                let granted = try await ekStore.requestFullAccessToEvents()
                if granted {
                    authStatus = .fullAccess
                    fetch(for: lastLoadedDate ?? Date())
                } else {
                    authStatus = .denied
                }
            } catch {
                openPrivacySettings()
            }
        }
    }

    func openPrivacySettings() {
        NSWorkspace.shared.open(
            URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars")!
        )
    }

    private func refreshStatus() {
        let status = EKEventStore.authorizationStatus(for: .event)
        authStatus = status
        if isAuthorized(status), let date = lastLoadedDate {
            fetch(for: date)
        }
    }

    private func isAuthorized(_ status: EKAuthorizationStatus) -> Bool {
        status == .fullAccess
    }

    private func fetch(for date: Date) {
        let cal   = Calendar.current
        let start = cal.startOfDay(for: date)
        let end   = cal.date(byAdding: .day, value: 1, to: start) ?? start
        let pred  = ekStore.predicateForEvents(withStart: start, end: end, calendars: nil)
        events  = ekStore.events(matching: pred).sorted { $0.startDate < $1.startDate }
        version += 1
    }
}
