import XCTest
@testable import NASA_New

final class MainViewStateTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        return calendar
    }

    func testDataSaverPolicyDisablesHDPreferenceWhenEnabled() {
        XCTAssertFalse(DataSaverPreferencePolicy.resolvedPreferHDImages(dataSaverMode: true, preferHDImages: true))
        XCTAssertFalse(DataSaverPreferencePolicy.resolvedPreferHDImages(dataSaverMode: true, preferHDImages: false))
    }

    func testDataSaverPolicyPreservesHDPreferenceWhenDisabled() {
        XCTAssertTrue(DataSaverPreferencePolicy.resolvedPreferHDImages(dataSaverMode: false, preferHDImages: true))
        XCTAssertFalse(DataSaverPreferencePolicy.resolvedPreferHDImages(dataSaverMode: false, preferHDImages: false))
    }

    func testAPODDateNavigationShiftsBackwardWithinBounds() {
        let minimumDate = calendar.date(from: DateComponents(year: 2025, month: 1, day: 13))!
        let maximumDate = calendar.date(from: DateComponents(year: 2025, month: 1, day: 15))!
        let startDate = maximumDate

        let previousDate = APODDateNavigationPolicy.shiftedDate(
            from: startDate,
            dayOffset: -1,
            calendar: calendar,
            minimumDate: minimumDate,
            maximumDate: maximumDate
        )
        let oldestDate = APODDateNavigationPolicy.shiftedDate(
            from: previousDate,
            dayOffset: -1,
            calendar: calendar,
            minimumDate: minimumDate,
            maximumDate: maximumDate
        )

        XCTAssertEqual(previousDate, calendar.date(from: DateComponents(year: 2025, month: 1, day: 14)))
        XCTAssertEqual(oldestDate, minimumDate)
    }

    func testAPODDateNavigationJumpToLatestReturnsMaximumDate() {
        let maximumDate = calendar.date(from: DateComponents(year: 2025, month: 1, day: 15))!

        XCTAssertEqual(APODDateNavigationPolicy.latestDate(maximumDate: maximumDate), maximumDate)
    }

    func testAPODDateNavigationClampsPastMinimumDate() {
        let minimumDate = calendar.date(from: DateComponents(year: 2025, month: 1, day: 13))!
        let maximumDate = calendar.date(from: DateComponents(year: 2025, month: 1, day: 15))!

        let clampedDate = APODDateNavigationPolicy.shiftedDate(
            from: minimumDate,
            dayOffset: -1,
            calendar: calendar,
            minimumDate: minimumDate,
            maximumDate: maximumDate
        )

        XCTAssertEqual(clampedDate, minimumDate)
    }
}
