import EventKit
import SwiftUI

@MainActor
class EventKitManager: ObservableObject {
    private let ekStore = EKEventStore()

    @Published var authStatus: EKAuthorizationStatus = EKEventStore.authorizationStatus(for: .event)

    // MARK: - Authorization

    func requestAccess() async -> Bool {
        do {
            let granted = try await ekStore.requestFullAccessToEvents()
            authStatus = EKEventStore.authorizationStatus(for: .event)
            return granted
        } catch {
            authStatus = EKEventStore.authorizationStatus(for: .event)
            return false
        }
    }

    var isAuthorized: Bool { authStatus == .fullAccess }

    // MARK: - Events

    /// Returns events for the given year/month, filtered to enabledCalendarIDs if non-empty.
    func events(for year: Int, month: Int, enabledIDs: Set<String>, showAll: Bool) -> [EKEvent] {
        guard isAuthorized else { return [] }

        let cal = Calendar(identifier: .gregorian)
        var startC = DateComponents(); startC.year = year; startC.month = month; startC.day = 1
        guard let start = cal.date(from: startC) else { return [] }
        guard let end   = cal.date(byAdding: DateComponents(month: 1), to: start) else { return [] }

        let pred   = ekStore.predicateForEvents(withStart: start, end: end, calendars: nil)
        let all    = ekStore.events(matching: pred)

        if showAll { return all }
        return all.filter { enabledIDs.contains($0.calendar.calendarIdentifier) }
    }

    /// All available event calendars on the device.
    func availableCalendars() -> [EKCalendar] {
        ekStore.calendars(for: .event)
    }
}
