import EventKit
import Foundation

enum CalendarReminderError: LocalizedError {
    case accessDenied(String)
    case noCalendar

    var errorDescription: String? {
        switch self {
        case .accessDenied(let name):
            return "没有\(name)访问权限"
        case .noCalendar:
            return "没有可写入的日历"
        }
    }
}

final class CalendarReminderService: @unchecked Sendable {
    private let store = EKEventStore()

    func addEvent(title: String, notes: String, date: Date) async throws {
        guard try await requestEventAccess() else {
            throw CalendarReminderError.accessDenied("日历")
        }
        guard let calendar = store.defaultCalendarForNewEvents else {
            throw CalendarReminderError.noCalendar
        }
        let event = EKEvent(eventStore: store)
        event.title = title
        event.notes = notes
        event.startDate = date
        event.endDate = date.addingTimeInterval(60 * 60)
        event.calendar = calendar
        event.addAlarm(EKAlarm(relativeOffset: -10 * 60))
        try store.save(event, span: .thisEvent, commit: true)
    }

    func addReminder(title: String, notes: String, date: Date) async throws {
        guard try await requestReminderAccess() else {
            throw CalendarReminderError.accessDenied("提醒事项")
        }
        guard let calendar = store.defaultCalendarForNewReminders() else {
            throw CalendarReminderError.noCalendar
        }
        let reminder = EKReminder(eventStore: store)
        reminder.title = title
        reminder.notes = notes
        reminder.calendar = calendar
        reminder.dueDateComponents = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute, .timeZone],
            from: date
        )
        reminder.addAlarm(EKAlarm(absoluteDate: date))
        try store.save(reminder, commit: true)
    }

    private func requestEventAccess() async throws -> Bool {
        if #available(macOS 14.0, *) {
            return try await store.requestFullAccessToEvents()
        }
        return try await requestLegacyAccess(to: .event)
    }

    private func requestReminderAccess() async throws -> Bool {
        if #available(macOS 14.0, *) {
            return try await store.requestFullAccessToReminders()
        }
        return try await requestLegacyAccess(to: .reminder)
    }

    private func requestLegacyAccess(to entityType: EKEntityType) async throws -> Bool {
        try await withCheckedThrowingContinuation { continuation in
            store.requestAccess(to: entityType) { granted, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: granted)
                }
            }
        }
    }
}
