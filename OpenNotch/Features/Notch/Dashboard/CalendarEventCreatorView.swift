import SwiftUI
import EventKit

struct CalendarEventCreatorView: View {
    @ObservedObject var store: CalendarStore
    var defaultDate: Date = Date()
    var editingEvent: EKEvent?
    var onDismiss: (() -> Void)? = nil

    @State private var title = ""
    @State private var location = ""
    @State private var notes = ""
    @State private var startDate: Date
    @State private var endDate: Date
    @State private var isAllDay = false
    @State private var selectedCalendar: EKCalendar?
    @State private var calendars: [EKCalendar] = []
    @State private var isSaving = false
    @State private var showError = false
    @State private var showDeleteConfirm = false

    init(store: CalendarStore, defaultDate: Date, editingEvent: EKEvent? = nil, onDismiss: (() -> Void)? = nil) {
        self.store = store
        self.defaultDate = defaultDate
        self.editingEvent = editingEvent
        self.onDismiss = onDismiss
        if let event = editingEvent {
            _title = State(initialValue: event.title ?? "")
            _location = State(initialValue: event.location ?? "")
            _notes = State(initialValue: event.notes ?? "")
            _startDate = State(initialValue: event.startDate)
            _endDate = State(initialValue: event.endDate)
            _isAllDay = State(initialValue: event.isAllDay)
            _selectedCalendar = State(initialValue: event.calendar)
        } else {
            let cal = Calendar.current
            let hour = cal.component(.hour, from: Date()) + 1
            let roundedStart = cal.date(bySettingHour: hour, minute: 0, second: 0, of: defaultDate) ?? defaultDate
            _startDate = State(initialValue: roundedStart)
            _endDate = State(initialValue: roundedStart.addingTimeInterval(3600))
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(L10n.app("calendar.cancel", fallback: "Cancel")) { onDismiss?() }
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.55))
                    .buttonStyle(.plain)
                Spacer()
                Text(editingEvent != nil
                    ? L10n.app("calendar.editEvent", fallback: "Edit Event")
                    : L10n.app("calendar.createEvent", fallback: "New Event"))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                Spacer()
                HStack(spacing: 6) {
                    if editingEvent != nil {
                        Button(action: { showDeleteConfirm = true }) {
                            Image(systemName: "trash")
                                .font(.system(size: 11))
                                .foregroundStyle(.red.opacity(0.7))
                        }
                        .buttonStyle(.plain)
                        .help(L10n.app("calendar.delete", fallback: "Delete"))
                    }
                    Button(L10n.app("calendar.save", fallback: "Save")) { save() }
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(title.isEmpty ? .white.opacity(0.25) : .blue)
                        .buttonStyle(.plain)
                        .disabled(title.isEmpty || isSaving)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            Divider().opacity(0.1)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 12) {
                    formField(L10n.app("calendar.title", fallback: "Title")) {
                        TextField(L10n.app("calendar.titlePlaceholder", fallback: "Event title"), text: $title)
                            .textFieldStyle(.plain)
                            .font(.system(size: 12))
                            .foregroundStyle(.white)
                    }

                    formField(L10n.app("calendar.location", fallback: "Location")) {
                        TextField(L10n.app("calendar.locationPlaceholder", fallback: "Optional"), text: $location)
                            .textFieldStyle(.plain)
                            .font(.system(size: 12))
                            .foregroundStyle(.white)
                    }

                    Toggle(isOn: $isAllDay) {
                        Text(L10n.app("calendar.allDay", fallback: "All-day"))
                            .font(.system(size: 12))
                            .foregroundStyle(.white)
                    }
                    .toggleStyle(.switch)
                    .controlSize(.small)

                    if !isAllDay {
                        HStack(spacing: 8) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(L10n.app("calendar.starts", fallback: "Starts"))
                                    .font(.system(size: 9))
                                    .foregroundStyle(.white.opacity(0.35))
                                DatePicker("", selection: $startDate, displayedComponents: [.date, .hourAndMinute])
                                    .datePickerStyle(.compact)
                                    .labelsHidden()
                                    .scaleEffect(0.85)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            VStack(alignment: .leading, spacing: 3) {
                                Text(L10n.app("calendar.ends", fallback: "Ends"))
                                    .font(.system(size: 9))
                                    .foregroundStyle(.white.opacity(0.35))
                                DatePicker("", selection: $endDate, in: startDate..., displayedComponents: [.date, .hourAndMinute])
                                    .datePickerStyle(.compact)
                                    .labelsHidden()
                                    .scaleEffect(0.85)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }

                    if !calendars.isEmpty {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(L10n.app("calendar.calendar", fallback: "Calendar"))
                                .font(.system(size: 9))
                                .foregroundStyle(.white.opacity(0.35))
                            Picker("", selection: $selectedCalendar) {
                                ForEach(calendars, id: \.calendarIdentifier) { cal in
                                    HStack(spacing: 6) {
                                        Circle()
                                            .fill(Color(cgColor: cal.cgColor))
                                            .frame(width: 8, height: 8)
                                        Text(cal.title)
                                    }
                                    .tag(cal as EKCalendar?)
                                }
                            }
                            .labelsHidden()
                            .pickerStyle(.menu)
                            .tint(.white)
                        }
                    }

                    formField(L10n.app("calendar.notes", fallback: "Notes")) {
                        TextEditor(text: $notes)
                            .font(.system(size: 11))
                            .foregroundStyle(.white)
                            .scrollContentBackground(.hidden)
                            .background(Color.white.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .frame(height: 60)
                    }
                }
                .padding(14)
            }
        }
        .onAppear { loadCalendars() }
        .alert(L10n.app("calendar.error", fallback: "Could not save event"), isPresented: $showError) {
            Button("OK") { showError = false }
        }
        .alert(L10n.app("calendar.deleteConfirm", fallback: "Delete this event?"), isPresented: $showDeleteConfirm) {
            Button(L10n.app("calendar.delete", fallback: "Delete"), role: .destructive) { delete() }
            Button(L10n.app("calendar.cancel", fallback: "Cancel"), role: .cancel) { }
        }
    }

    @ViewBuilder
    private func formField(_ label: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(.white.opacity(0.35))
            content()
        }
    }

    private func loadCalendars() {
        calendars = store.calendars.filter { $0.allowsContentModifications }
        if selectedCalendar == nil, let first = calendars.first {
            selectedCalendar = first
        }
    }

    private func save() {
        guard !title.isEmpty, let calendar = selectedCalendar else { return }
        isSaving = true

        let event: EKEvent
        if let existing = editingEvent {
            event = existing
            existing.title = title
            existing.location = location.isEmpty ? nil : location
            existing.notes = notes.isEmpty ? nil : notes
            existing.calendar = calendar
            existing.isAllDay = isAllDay
        } else {
            event = EKEvent(eventStore: EKEventStore.app)
            event.title = title
            event.location = location.isEmpty ? nil : location
            event.notes = notes.isEmpty ? nil : notes
            event.calendar = calendar
            event.isAllDay = isAllDay
        }

        if isAllDay {
            let cal = Calendar.current
            event.startDate = cal.startOfDay(for: startDate)
            event.endDate = cal.date(byAdding: .day, value: 1, to: event.startDate) ?? event.startDate
        } else {
            event.startDate = startDate
            event.endDate = endDate
        }

        if store.saveEvent(event) {
            onDismiss?()
        } else {
            showError = true
            isSaving = false
        }
    }

    private func delete() {
        guard let event = editingEvent else { return }
        if store.removeEvent(event) {
            onDismiss?()
        }
    }
}
