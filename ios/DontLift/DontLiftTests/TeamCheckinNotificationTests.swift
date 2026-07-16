import Foundation
import Testing
@testable import DontLift

@MainActor
struct TeamCheckinNotificationTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        return calendar
    }

    private var now: Date {
        calendar.date(from: DateComponents(year: 2026, month: 7, day: 14, hour: 12))!
    }

    @Test func sameLocalDateDoesNotSuppressNotification() {
        let checkinDate = TeamService.dateOnly(now)

        #expect(!TeamService.shouldSuppressCheckinNotification(checkinDate: checkinDate, now: now))
    }

    @Test func previousLocalDateSuppressesNotification() {
        let yesterday = calendar.date(byAdding: .day, value: -1, to: now)!

        #expect(TeamService.shouldSuppressCheckinNotification(
            checkinDate: TeamService.dateOnly(yesterday), now: now))
    }
}
