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

    func testAPODDateDisplayPolicyFormatsReadableDate() {
        XCTAssertEqual(
            APODDateDisplayPolicy.displayString(for: "2025-01-15", locale: Locale(identifier: "en_US_POSIX")),
            "January 15, 2025"
        )
    }

    func testAPODDateDisplayPolicyFallsBackWhenDateMissing() {
        XCTAssertEqual(APODDateDisplayPolicy.displayString(for: nil), "Unknown date")
        XCTAssertEqual(APODDateDisplayPolicy.displayString(for: " "), "Unknown date")
    }

    func testAPODExplanationDisplayPolicyOffersExpansionForLongText() {
        let longText = String(repeating: "Galaxy ", count: 40)
        XCTAssertTrue(APODExplanationDisplayPolicy.shouldOfferExpansion(for: longText))
        XCTAssertFalse(APODExplanationDisplayPolicy.shouldOfferExpansion(for: "Short APOD summary."))
    }

    func testAPODMediaInteractionPolicyOnlyAllowsPanningWhenZoomed() {
        XCTAssertFalse(APODMediaInteractionPolicy.allowsImagePanning(atScale: 1.0))
        XCTAssertFalse(APODMediaInteractionPolicy.allowsImagePanning(atScale: 1.01))
        XCTAssertTrue(APODMediaInteractionPolicy.allowsImagePanning(atScale: 1.2))
    }

    func testAPODSourceLinkPolicyBuildsArchiveURLForValidDate() {
        let archiveURL = APODSourceLinkPolicy.nasaPageURL(
            for: "2025-01-15",
            fallbackURL: URL(string: "https://example.com/fallback")
        )

        XCTAssertEqual(archiveURL?.absoluteString, "https://apod.nasa.gov/apod/ap250115.html")
    }

    func testAPODSourceLinkPolicyFallsBackForImpossibleDate() {
        let fallbackURL = URL(string: "https://example.com/fallback")
        let archiveURL = APODSourceLinkPolicy.nasaPageURL(
            for: "2025-02-30",
            fallbackURL: fallbackURL
        )

        XCTAssertEqual(archiveURL, fallbackURL)
    }

    func testAPODSourceLinkPolicyPrefersHDImageWhenAllowed() {
        let nasa = NASA(
            date: "2025-01-15",
            hdurl: URL(string: "https://example.com/image-hd.jpg"),
            mediaType: .image,
            title: "Test",
            url: URL(string: "https://example.com/image.jpg")
        )

        XCTAssertEqual(
            APODSourceLinkPolicy.preferredMediaURL(for: nasa, dataSaverMode: false, preferHDImages: true)?.absoluteString,
            "https://example.com/image-hd.jpg"
        )
        XCTAssertEqual(
            APODSourceLinkPolicy.preferredMediaTitle(for: nasa, dataSaverMode: false, preferHDImages: true),
            "Open HD Image"
        )
    }

    func testAPODSourceLinkPolicyUsesStandardImageInDataSaverMode() {
        let nasa = NASA(
            date: "2025-01-15",
            hdurl: URL(string: "https://example.com/image-hd.jpg"),
            mediaType: .image,
            title: "Test",
            url: URL(string: "https://example.com/image.jpg")
        )

        XCTAssertEqual(
            APODSourceLinkPolicy.preferredMediaURL(for: nasa, dataSaverMode: true, preferHDImages: true)?.absoluteString,
            "https://example.com/image.jpg"
        )
        XCTAssertEqual(
            APODSourceLinkPolicy.preferredMediaTitle(for: nasa, dataSaverMode: true, preferHDImages: true),
            "Open Image"
        )
    }

    func testAPODAttributionPolicyPrefersExplicitCreditLine() {
        let nasa = NASA(
            copyright: "ESA/Hubble",
            date: "2025-01-15",
            mediaType: .image,
            title: "Test",
            url: URL(string: "https://example.com/image.jpg")
        )

        XCTAssertEqual(APODAttributionPolicy.creditLine(for: nasa), "ESA/Hubble")
        XCTAssertNotNil(APODAttributionPolicy.rightsNotice(for: nasa))
    }

    func testAPODAttributionPolicyFallsBackToNASAWhenCopyrightMissing() {
        let nasa = NASA(
            date: "2025-01-15",
            mediaType: .image,
            title: "Test",
            url: URL(string: "https://example.com/image.jpg")
        )

        XCTAssertEqual(APODAttributionPolicy.creditLine(for: nasa), "NASA")
        XCTAssertNotNil(APODAttributionPolicy.rightsNotice(for: nasa))
    }
}
