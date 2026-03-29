import XCTest
import SwiftUI
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

    func testAppAppearancePolicyDefaultsToSystemForMissingOrInvalidValues() {
        XCTAssertEqual(AppAppearancePolicy.resolvedPreference(from: nil), .system)
        XCTAssertEqual(AppAppearancePolicy.resolvedPreference(from: "unexpected"), .system)
    }

    func testAppAppearancePolicyUsesSystemColorSchemeWhenFollowingSystem() {
        XCTAssertTrue(AppAppearancePolicy.effectiveIsDarkMode(preference: .system, systemColorScheme: .dark))
        XCTAssertFalse(AppAppearancePolicy.effectiveIsDarkMode(preference: .system, systemColorScheme: .light))
    }

    func testAppAppearancePolicyCreatesExplicitPreferenceFromSystemColorScheme() {
        XCTAssertEqual(AppAppearancePolicy.explicitPreference(matching: .dark), .dark)
        XCTAssertEqual(AppAppearancePolicy.explicitPreference(matching: .light), .light)
    }

    func testAppAppearancePolicyCreatesExplicitPreferenceFromDarkModeFlag() {
        XCTAssertEqual(AppAppearancePolicy.explicitPreference(forDarkMode: true), .dark)
        XCTAssertEqual(AppAppearancePolicy.explicitPreference(forDarkMode: false), .light)
    }

    func testAppAppearancePolicyMigratesLegacyPreference() {
        let suiteName = "MainViewStateTests.appearanceMigration.\(UUID().uuidString)"
        guard let userDefaults = UserDefaults(suiteName: suiteName) else {
            XCTFail("Unable to create test user defaults suite")
            return
        }

        userDefaults.removePersistentDomain(forName: suiteName)
        userDefaults.set(true, forKey: AppAppearancePolicy.legacyStorageKey)

        AppAppearancePolicy.migrateLegacyPreferenceIfNeeded(in: userDefaults)

        XCTAssertEqual(
            userDefaults.string(forKey: AppAppearancePolicy.storageKey),
            AppAppearancePreference.dark.rawValue
        )

        userDefaults.removePersistentDomain(forName: suiteName)
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

    func testAPODSourceLinkPolicyDescribesHDMediaSource() {
        let nasa = NASA(
            date: "2025-01-15",
            hdurl: URL(string: "https://images.example.com/image-hd.jpg"),
            mediaType: .image,
            title: "Test",
            url: URL(string: "https://images.example.com/image.jpg")
        )

        XCTAssertEqual(
            APODSourceLinkPolicy.preferredMediaDescription(for: nasa, dataSaverMode: false, preferHDImages: true),
            "Direct high-resolution image file referenced by the APOD entry."
        )
    }

    func testAPODSourceLinkPolicyHostLabelStripsWWWPrefix() {
        XCTAssertEqual(
            APODSourceLinkPolicy.hostLabel(for: URL(string: "https://www.youtube.com/watch?v=abc123")),
            "youtube.com"
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
        XCTAssertEqual(APODAttributionPolicy.creditTitle(for: nasa), "Rights Holder")
        XCTAssertEqual(APODAttributionPolicy.rightsStatus(for: nasa), .copyrightProtected)
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
        XCTAssertEqual(APODAttributionPolicy.rightsStatus(for: nasa), .nasaContentLikely)
        XCTAssertNotNil(APODAttributionPolicy.rightsNotice(for: nasa))
    }

    func testAPODAttributionPolicyTreatsExplicitNASACreditAsLikelyNASAContent() {
        let nasa = NASA(
            copyright: "NASA",
            date: "2025-01-15",
            mediaType: .image,
            title: "Test",
            url: URL(string: "https://example.com/image.jpg")
        )

        XCTAssertEqual(APODAttributionPolicy.rightsStatus(for: nasa), .nasaContentLikely)
        XCTAssertEqual(APODAttributionPolicy.rightsBadgeTitle(for: nasa), "NASA source likely")
    }

    func testAPODAttributionPolicyRequestsReviewWhenMediaAndCreditAreMissing() {
        let nasa = NASA(
            date: "2025-01-15",
            explanation: "No linked media yet.",
            mediaType: .other,
            title: "Pending Source"
        )

        XCTAssertEqual(APODAttributionPolicy.rightsStatus(for: nasa), .reviewOriginalCredit)
        XCTAssertEqual(APODAttributionPolicy.rightsBadgeTitle(for: nasa), "Verify original credit")
    }

    func testAppBrandingPolicyUsesOfficialAPODArchiveHomeURL() {
        XCTAssertEqual(
            AppBrandingPolicy.officialAPODHomeURL()?.absoluteString,
            "https://apod.nasa.gov/apod/astropix.html"
        )
    }

    func testAPODSharePolicyIncludesIndependentAppAndSourceContext() {
        let nasa = NASA(
            date: "2025-01-15",
            explanation: "A bright nebula over a quiet horizon photographed with a long exposure.",
            mediaType: .image,
            title: "Nebula Horizon",
            url: URL(string: "https://example.com/image.jpg")
        )
        let sourceURL = URL(string: "https://apod.nasa.gov/apod/ap250115.html")!

        let message = APODSharePolicy.shareMessage(for: nasa, sourceURL: sourceURL, explanationMaxLength: 80)

        XCTAssertTrue(message.contains("Space Briefing"))
        XCTAssertTrue(message.contains("Official APOD source"))
        XCTAssertTrue(message.contains(sourceURL.absoluteString))
    }

    func testAPODSharePolicyOmitsSourceLineWhenSourceURLMissing() {
        let nasa = NASA(
            date: "2025-01-15",
            explanation: "A short APOD summary.",
            mediaType: .image,
            title: "Source Missing",
            url: URL(string: "https://example.com/image.jpg")
        )

        let message = APODSharePolicy.shareMessage(for: nasa, sourceURL: nil, explanationMaxLength: 80)

        XCTAssertFalse(message.contains("Official APOD source"))
    }
}
