/*
 * Calendar/reminder context bridge for Jarvis.
 *
 * Atoll owns EventKit permissions and presentation. Jarvis receives only a
 * compact, structured snapshot for assistant reasoning.
 */

import EventKit
import Foundation
import JarvisCore

@MainActor
final class JarvisScheduleSnapshotProvider {
    static let shared = JarvisScheduleSnapshotProvider()

    private let calendarManager = CalendarManager.shared
    private var lastRefresh: Date = .distantPast
    private let refreshInterval: TimeInterval = 60
    private var lastSnapshot = ScheduleContext()

    private init() {}

    func start() {
        Task { @MainActor in
            _ = await snapshot(forceRefresh: true)
        }
    }

    func snapshot(forceRefresh: Bool = false) async -> ScheduleContext {
        await refreshIfAuthorized(force: forceRefresh)

        let events = calendarManager.events
            .filter { !$0.type.isReminder }
            .sorted { $0.start < $1.start }
            .prefix(12)
            .map(ScheduleItemContext.init(event:))

        let reminders = calendarManager.events
            .filter { $0.type.isReminder }
            .sorted { $0.start < $1.start }
            .prefix(12)
            .map(ScheduleItemContext.init(event:))

        let snapshot = ScheduleContext(
            generatedAt: Date(),
            calendarAuthorization: Self.authorizationDescription(calendarManager.calendarAuthorizationStatus),
            reminderAuthorization: Self.authorizationDescription(calendarManager.reminderAuthorizationStatus),
            events: Array(events),
            reminders: Array(reminders)
        )
        lastSnapshot = snapshot
        return snapshot
    }

    func cachedSnapshot() -> ScheduleContext {
        lastSnapshot
    }

    private func refreshIfAuthorized(force: Bool) async {
        let now = Date()
        guard force || now.timeIntervalSince(lastRefresh) > refreshInterval else { return }
        lastRefresh = now

        let calendarStatus = EKEventStore.authorizationStatus(for: .event)
        let reminderStatus = EKEventStore.authorizationStatus(for: .reminder)
        calendarManager.calendarAuthorizationStatus = calendarStatus
        calendarManager.reminderAuthorizationStatus = reminderStatus

        guard Self.isAuthorized(calendarStatus) || Self.isAuthorized(reminderStatus) else {
            await calendarManager.reloadCalendarAndReminderLists()
            return
        }

        await calendarManager.reloadCalendarAndReminderLists()
        await calendarManager.updateCurrentDate(Date())
    }

    private static func isAuthorized(_ status: EKAuthorizationStatus) -> Bool {
        switch status {
        case .authorized, .fullAccess:
            return true
        default:
            return false
        }
    }

    private static func authorizationDescription(_ status: EKAuthorizationStatus) -> String {
        switch status {
        case .notDetermined: return "notDetermined"
        case .restricted: return "restricted"
        case .denied: return "denied"
        case .authorized: return "authorized"
        case .writeOnly: return "writeOnly"
        case .fullAccess: return "fullAccess"
        @unknown default: return "unknown"
        }
    }
}

private extension ScheduleItemContext {
    init(event: EventModel) {
        let kind: String
        let completed: Bool?
        switch event.type {
        case .event:
            kind = "event"
            completed = nil
        case .birthday:
            kind = "birthday"
            completed = nil
        case .reminder(let isCompleted):
            kind = "reminder"
            completed = isCompleted
        }

        self.init(
            id: event.id,
            kind: kind,
            title: event.title,
            calendarTitle: event.calendar.title,
            start: event.start,
            end: event.end,
            isAllDay: event.isAllDay,
            location: event.location,
            notes: event.notes,
            url: event.conferenceURL ?? event.url,
            participantNames: event.participants.prefix(6).map(\.name),
            completed: completed
        )
    }
}
