import XCTest
import SwiftUI

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

    func testArchiveLibraryPolicyFiltersSavedItemsAndBuildsNewestSectionsFirst() {
        let locale = Locale(identifier: "en_US_POSIX")
        let newestSaved = makeArchivePolicyItem(
            date: "2025-02-10",
            title: "Nebula Saved",
            mediaKind: .image,
            isSaved: true,
            creditLine: "NASA"
        )
        let olderSaved = makeArchivePolicyItem(
            date: "2025-02-01",
            title: "Nebula Earlier",
            mediaKind: .image,
            isSaved: true,
            creditLine: "NASA"
        )
        let januarySaved = makeArchivePolicyItem(
            date: "2025-01-20",
            title: "Nebula January",
            mediaKind: .video,
            isSaved: true,
            creditLine: "ESA"
        )
        let unsavedMatch = makeArchivePolicyItem(
            date: "2025-02-12",
            title: "Nebula Unsaved",
            mediaKind: .image,
            isSaved: false,
            creditLine: "NASA"
        )

        let resolution = ArchiveLibraryPolicy.resolve(
            items: [januarySaved, unsavedMatch, olderSaved, newestSaved],
            filter: .saved,
            searchQuery: "Nebula",
            locale: locale
        )

        XCTAssertEqual(resolution.filteredItemIDs, [januarySaved.id, olderSaved.id, newestSaved.id])
        XCTAssertEqual(resolution.sections.map(\.id), ["2025-02", "2025-01"])
        XCTAssertEqual(resolution.sections.first?.itemIDs, [newestSaved.id, olderSaved.id])
    }

    func testArchiveLibraryPolicyBuildsLocalizedSectionTitles() {
        XCTAssertEqual(
            ArchiveLibraryPolicy.sectionTitle(
                for: "2025-01",
                locale: Locale(identifier: "en_US_POSIX")
            ),
            "January 2025"
        )
    }

    func testArchiveLibraryPolicyFallsBackToUnknownSectionForMissingDate() {
        XCTAssertEqual(ArchiveLibraryPolicy.sectionKey(for: nil), "unknown")
        XCTAssertEqual(
            ArchiveLibraryPolicy.sectionTitle(
                for: "unknown",
                locale: Locale(identifier: "en_US_POSIX")
            ),
            "Unknown"
        )
    }

    func testSavedLibraryPolicyFiltersSourceBackedEntriesAndPreservesSearchOrder() {
        let sourceBacked = makeSavedPolicyItem(
            id: "source-backed",
            date: "2025-02-10",
            title: "Nebula Source",
            creditLine: "NASA",
            storageState: .sourceBacked
        )
        let preview = makeSavedPolicyItem(
            id: "preview",
            date: "2025-02-09",
            title: "Nebula Preview",
            creditLine: "NASA",
            storageState: .preview
        )
        let secondSourceBacked = makeSavedPolicyItem(
            id: "second-source",
            date: "2025-02-08",
            title: "Nebula Source Backup",
            creditLine: "ESA",
            storageState: .sourceBacked
        )

        let filteredIDs = SavedLibraryPolicy.filteredItemIDs(
            items: [sourceBacked, preview, secondSourceBacked],
            filter: .sourceRequired,
            searchQuery: "Nebula"
        )

        XCTAssertEqual(filteredIDs, [sourceBacked.id, secondSourceBacked.id])
    }

    func testLibraryLayoutPolicyOnlyUsesGridInRegularStandaloneLayout() {
        XCTAssertTrue(
            LibraryLayoutPolicy.usesSplitLayout(isRegularWidth: true, embedInRegularShell: false)
        )
        XCTAssertFalse(
            LibraryLayoutPolicy.usesSplitLayout(isRegularWidth: true, embedInRegularShell: true)
        )
        XCTAssertFalse(
            LibraryLayoutPolicy.usesSplitLayout(isRegularWidth: false, embedInRegularShell: false)
        )
        XCTAssertEqual(
            LibraryLayoutPolicy.resolvedPresentationMode(from: "unexpected", fallback: .list),
            .list
        )
        XCTAssertTrue(
            LibraryLayoutPolicy.usesGridPresentation(
                isRegularWidth: true,
                embedInRegularShell: false,
                presentationMode: .grid
            )
        )
        XCTAssertFalse(
            LibraryLayoutPolicy.usesGridPresentation(
                isRegularWidth: true,
                embedInRegularShell: true,
                presentationMode: .grid
            )
        )
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

    func testPremiumAccessPolicyFreeArchiveWindowCoversLatestSevenDaysExactly() {
        let referenceDate = calendar.date(from: DateComponents(year: 2025, month: 1, day: 15))!
        let earliestFreeDate = calendar.date(from: DateComponents(year: 2025, month: 1, day: 9))!
        let lockedDate = calendar.date(from: DateComponents(year: 2025, month: 1, day: 8))!

        XCTAssertEqual(
            PremiumAccessPolicy.earliestFreeArchiveDate(referenceDate: referenceDate, calendar: calendar),
            earliestFreeDate
        )
        XCTAssertTrue(
            PremiumAccessPolicy.canAccessArchive(
                date: earliestFreeDate,
                hasPro: false,
                referenceDate: referenceDate,
                calendar: calendar
            )
        )
        XCTAssertFalse(
            PremiumAccessPolicy.canAccessArchive(
                date: lockedDate,
                hasPro: false,
                referenceDate: referenceDate,
                calendar: calendar
            )
        )
    }

    func testPremiumAccessPolicyAllowsOlderArchiveDatesForProUsers() {
        let referenceDate = calendar.date(from: DateComponents(year: 2025, month: 1, day: 15))!
        let oldestDate = calendar.date(from: DateComponents(year: 2025, month: 1, day: 1))!

        XCTAssertTrue(
            PremiumAccessPolicy.canAccessArchive(
                date: oldestDate,
                hasPro: true,
                referenceDate: referenceDate,
                calendar: calendar
            )
        )
    }

    @MainActor
    func testPurchaseManagerBlocksEleventhFavoriteButAllowsExistingFavoriteToRemainAccessible() {
        let userDefaults = isolatedUserDefaults(name: "favoriteLimit")
        let manager = PurchaseManager(
            backend: MockPurchaseBackend(),
            userDefaults: userDefaults,
            environment: [:]
        )

        XCTAssertFalse(manager.canAddFavorite(currentCount: 10, isAlreadyFavorite: false))
        XCTAssertTrue(manager.canAddFavorite(currentCount: 10, isAlreadyFavorite: true))
    }

    @MainActor
    func testPurchaseManagerShowsArchiveVisitNudgeOnlyOnce() {
        let userDefaults = isolatedUserDefaults(name: "archiveVisitNudge")
        let manager = PurchaseManager(
            backend: MockPurchaseBackend(),
            userDefaults: userDefaults,
            environment: [:]
        )

        manager.registerArchiveVisitIfNeeded()
        XCTAssertNil(manager.activePaywall)

        manager.registerArchiveVisitIfNeeded()
        XCTAssertNil(manager.activePaywall)

        manager.registerArchiveVisitIfNeeded()
        XCTAssertEqual(manager.activePaywall?.trigger, .archiveVisitNudge)
        XCTAssertEqual(manager.activePaywall?.feature, .fullArchive)

        manager.dismissPaywall()
        XCTAssertNil(manager.activePaywall)

        manager.registerArchiveVisitIfNeeded()
        XCTAssertNil(manager.activePaywall)
    }

    @MainActor
    func testPurchaseManagerRefreshEntitlementsAppliesMockedBackendState() async {
        let userDefaults = isolatedUserDefaults(name: "refreshEntitlements")
        let backend = MockPurchaseBackend()
        let manager = PurchaseManager(
            backend: backend,
            userDefaults: userDefaults,
            environment: [:]
        )

        await backend.setEntitlementProductIDs([AppProduct.proLifetime.rawValue])
        await manager.refreshEntitlements()

        XCTAssertTrue(manager.hasPro)
    }

    @MainActor
    func testPurchaseManagerRestorePurchasesUpdatesEntitlementsAndDismissesPaywall() async {
        let userDefaults = isolatedUserDefaults(name: "restorePurchases")
        let backend = MockPurchaseBackend()
        let manager = PurchaseManager(
            backend: backend,
            userDefaults: userDefaults,
            environment: [:]
        )

        manager.presentPaywall(trigger: .favoriteLimit, feature: .unlimitedFavorites)
        await backend.setEntitlementProductIDs([AppProduct.proLifetime.rawValue])

        await manager.restorePurchases()

        XCTAssertTrue(manager.hasPro)
        XCTAssertNil(manager.activePaywall)
        let syncCallCount = await backend.syncCallCount()
        XCTAssertEqual(syncCallCount, 1)
        XCTAssertFalse(manager.paywallMessage?.isEmpty ?? true)
    }

    @MainActor
    func testPurchaseManagerListensForMockedTransactionUpdates() async {
        let userDefaults = isolatedUserDefaults(name: "transactionUpdates")
        let backend = MockPurchaseBackend(
            productSnapshots: [
                StoreProductSnapshot(
                    id: AppProduct.proLifetime.rawValue,
                    displayName: "Pro Lifetime",
                    description: "Unlock the full space experience.",
                    displayPrice: "9.99 lv"
                )
            ]
        )
        let manager = PurchaseManager(
            backend: backend,
            userDefaults: userDefaults,
            environment: [:]
        )

        manager.start()
        let didSubscribe = await backend.waitUntilSubscribed()
        XCTAssertTrue(didSubscribe)

        await backend.setEntitlementProductIDs([AppProduct.proLifetime.rawValue])
        await backend.emitTransactionUpdate()

        await assertEventually {
            await MainActor.run { manager.hasPro }
        }
        XCTAssertNotNil(manager.proLifetimeProduct)
    }

    func testPremiumAccessPolicyAllowsOriginalMediaSaveOnlyForProImageEntriesWithSource() {
        let hdImage = NASA(
            date: "2025-01-15",
            hdurl: URL(string: "https://example.com/image-hd.jpg"),
            mediaType: .image,
            title: "HD Test",
            url: URL(string: "https://example.com/image.jpg")
        )
        let standardImage = NASA(
            date: "2025-01-15",
            mediaType: .image,
            title: "Standard Test",
            url: URL(string: "https://example.com/image.jpg")
        )
        let missingSource = NASA(
            date: "2025-01-15",
            mediaType: .image,
            title: "Missing Source"
        )
        let video = NASA(
            date: "2025-01-15",
            mediaType: .video,
            title: "Video Test",
            url: URL(string: "https://example.com/video.mp4")
        )

        XCTAssertTrue(PremiumAccessPolicy.canSaveOriginalMedia(apod: hdImage, hasPro: true))
        XCTAssertTrue(PremiumAccessPolicy.canSaveOriginalMedia(apod: standardImage, hasPro: true))
        XCTAssertFalse(PremiumAccessPolicy.canSaveOriginalMedia(apod: missingSource, hasPro: true))
        XCTAssertFalse(PremiumAccessPolicy.canSaveOriginalMedia(apod: video, hasPro: true))
        XCTAssertFalse(PremiumAccessPolicy.canSaveOriginalMedia(apod: hdImage, hasPro: false))
    }

    func testAPODDownloadServiceDownloadsSupportedImageToFile() async throws {
        let sourceURL = try temporaryFileURL(
            named: "download-service-image.jpg",
            data: Data([0xFF, 0xD8, 0xFF, 0xD9])
        )
        let destinationDirectoryURL = temporaryDirectoryURL(named: "download-service-destination")
        let service = APODDownloadService()

        let downloadedFile = try await service.download(
            from: sourceURL,
            to: destinationDirectoryURL,
            fileStem: "apod-image",
            validation: .offlineImageAsset
        )

        XCTAssertTrue(FileManager.default.fileExists(atPath: downloadedFile.fileURL.path))
        XCTAssertEqual(downloadedFile.byteCount, 4)
        XCTAssertEqual(downloadedFile.fileExtension, "jpg")
    }

    func testAPODDownloadServiceRejectsUnsupportedContentTypes() async throws {
        let sourceURL = try temporaryFileURL(
            named: "download-service-invalid.html",
            data: Data("<html></html>".utf8)
        )
        let destinationDirectoryURL = temporaryDirectoryURL(named: "download-service-invalid-destination")
        let service = APODDownloadService()

        do {
            _ = try await service.download(
                from: sourceURL,
                to: destinationDirectoryURL,
                fileStem: "invalid-image",
                validation: .offlineImageAsset
            )
            XCTFail("Expected unsupported content type error")
        } catch let error as APODDownloadService.DownloadError {
            guard case .unsupportedContentType(let expected, _) = error else {
                XCTFail("Expected unsupported content type error, got \(error)")
                return
            }

            XCTAssertEqual(expected, "offline image")
        }
    }

    func testAPODDownloadServiceRejectsOversizedFiles() async throws {
        let sourceURL = try temporaryFileURL(
            named: "download-service-oversized.jpg",
            data: Data(repeating: 0xAB, count: 64)
        )
        let destinationDirectoryURL = temporaryDirectoryURL(named: "download-service-oversized-destination")
        let service = APODDownloadService()
        let strictValidation = APODDownloadValidation(
            expectedContentLabel: "tiny image",
            allowedExactMIMETypes: APODDownloadValidation.offlineImageAsset.allowedExactMIMETypes,
            allowedMIMETypePrefixes: APODDownloadValidation.offlineImageAsset.allowedMIMETypePrefixes,
            allowedPathExtensions: APODDownloadValidation.offlineImageAsset.allowedPathExtensions,
            fallbackExtension: "jpg",
            maxByteCount: 8
        )

        do {
            _ = try await service.download(
                from: sourceURL,
                to: destinationDirectoryURL,
                fileStem: "oversized-image",
                validation: strictValidation
            )
            XCTFail("Expected oversized download error")
        } catch let error as APODDownloadService.DownloadError {
            guard case .fileTooLarge(let maxBytes, let actualBytes) = error else {
                XCTFail("Expected file too large error, got \(error)")
                return
            }

            XCTAssertEqual(maxBytes, 8)
            XCTAssertEqual(actualBytes, 64)
        }
    }

    func testSharedOfflineMediaStoreDownloadsFavoriteImageToLocalFile() async throws {
        let sourceURL = try temporaryFileURL(
            named: "offline-store-image.jpg",
            data: Data(repeating: 0xCD, count: 1_024)
        )
        let rootDirectoryURL = temporaryDirectoryURL(named: "offline-store-root")
        let userDefaults = isolatedUserDefaults(name: "offlineMediaStoreDownload")
        let store = SharedAPODOfflineMediaStore(
            userDefaults: userDefaults,
            rootDirectoryURL: rootDirectoryURL
        )
        let favorite = NASA(
            date: "2025-01-15",
            explanation: "Offline image fixture.",
            mediaType: .image,
            title: "Offline Favorite",
            url: sourceURL
        )

        let records = await store.synchronizeFavorites(
            [favorite],
            preferences: APODOfflineMediaPreferences(dataSaverMode: false, preferHDImages: false)
        )

        guard let record = records[favorite.id] else {
            XCTFail("Expected offline record for favorite")
            return
        }

        guard let relativePath = record.localAssetRelativePath else {
            XCTFail("Expected a local asset path for the downloaded favorite")
            return
        }

        XCTAssertEqual(record.availability, .availableOffline)
        XCTAssertEqual(record.byteCount, 1_024)
        XCTAssertTrue(
            FileManager.default.fileExists(
                atPath: rootDirectoryURL.appendingPathComponent(relativePath, isDirectory: false).path
            )
        )
    }

    func testSharedOfflineMediaStoreKeepsDirectVideosRemoteOnlyByDefault() async {
        let rootDirectoryURL = temporaryDirectoryURL(named: "offline-store-direct-video-root")
        let userDefaults = isolatedUserDefaults(name: "offlineMediaStoreDirectVideo")
        let store = SharedAPODOfflineMediaStore(
            userDefaults: userDefaults,
            rootDirectoryURL: rootDirectoryURL
        )
        let favorite = NASA(
            date: "2025-01-16",
            explanation: "Direct video fixture.",
            mediaType: .video,
            title: "Direct Video",
            url: URL(string: "https://example.com/direct-video.mp4")
        )

        let records = await store.synchronizeFavorites(
            [favorite],
            preferences: APODOfflineMediaPreferences(dataSaverMode: false, preferHDImages: false)
        )

        guard let record = records[favorite.id] else {
            XCTFail("Expected offline record for direct video favorite")
            return
        }

        XCTAssertEqual(record.availability, .remoteOnly)
        XCTAssertNil(record.localAssetRelativePath)
        XCTAssertNil(record.localPreviewRelativePath)
    }

    func testSharedOfflineMediaStoreClearRecordsRemovesPersistedFiles() async throws {
        let sourceURL = try temporaryFileURL(
            named: "offline-store-clear-image.jpg",
            data: Data(repeating: 0xEF, count: 2_048)
        )
        let rootDirectoryURL = temporaryDirectoryURL(named: "offline-store-clear-root")
        let userDefaults = isolatedUserDefaults(name: "offlineMediaStoreClear")
        let store = SharedAPODOfflineMediaStore(
            userDefaults: userDefaults,
            rootDirectoryURL: rootDirectoryURL
        )
        let favorite = NASA(
            date: "2025-01-17",
            explanation: "Offline image clear fixture.",
            mediaType: .image,
            title: "Offline Clear Favorite",
            url: sourceURL
        )

        let records = await store.synchronizeFavorites(
            [favorite],
            preferences: APODOfflineMediaPreferences(dataSaverMode: false, preferHDImages: false)
        )

        guard let relativePath = records[favorite.id]?.localAssetRelativePath else {
            XCTFail("Expected a downloaded file before clearing records")
            return
        }

        let storedFileURL = rootDirectoryURL.appendingPathComponent(relativePath, isDirectory: false)
        XCTAssertTrue(FileManager.default.fileExists(atPath: storedFileURL.path))

        let clearedRecords = await store.clearRecords()

        XCTAssertTrue(clearedRecords.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: storedFileURL.path))
        XCTAssertNil(userDefaults.data(forKey: "nasa.apod.offline-media.records.v1"))
    }

    func testAPODOfflineMediaAssetStateMapsFullAndPreviewAssets() {
        let fullAsset = APODOfflineMediaAsset(
            apodID: "image-asset",
            mediaType: .image,
            remoteSourceURL: URL(string: "https://example.com/image.jpg"),
            localAssetRelativePath: "offline/image-asset.jpg",
            availability: .availableOffline,
            byteCount: 2_048
        )
        let previewAsset = APODOfflineMediaAsset(
            apodID: "video-preview",
            mediaType: .video,
            remoteSourceURL: URL(string: "https://example.com/video"),
            localPreviewRelativePath: "offline/video-preview.jpg",
            availability: .previewOffline,
            byteCount: 512
        )

        switch fullAsset.state {
        case .full(let localAssetURL, let remoteSourceURL):
            XCTAssertTrue(localAssetURL.path.contains("image-asset.jpg"))
            XCTAssertEqual(remoteSourceURL?.absoluteString, "https://example.com/image.jpg")
        default:
            XCTFail("Expected a full offline state for stored image media")
        }

        switch previewAsset.state {
        case .preview(let localPreviewURL, let remoteSourceURL):
            XCTAssertTrue(localPreviewURL.path.contains("video-preview.jpg"))
            XCTAssertEqual(remoteSourceURL?.absoluteString, "https://example.com/video")
        default:
            XCTFail("Expected a preview offline state for hosted video media")
        }
    }

    func testAPODOfflineMediaAssetStateTreatsSourceBackedEntriesExplicitly() {
        let sourceRequiredAsset = APODOfflineMediaAsset(
            apodID: "remote-only",
            mediaType: .video,
            remoteSourceURL: URL(string: "https://example.com/direct-video.mp4"),
            availability: .remoteOnly
        )
        let syncingAsset = APODOfflineMediaAsset(
            apodID: "syncing",
            mediaType: .image,
            remoteSourceURL: URL(string: "https://example.com/syncing.jpg"),
            availability: .syncing
        )
        let failedAsset = APODOfflineMediaAsset(
            apodID: "failed",
            mediaType: .image,
            remoteSourceURL: URL(string: "https://example.com/failed.jpg"),
            availability: .failed,
            errorDescription: "network"
        )

        if case .sourceRequired(let remoteSourceURL) = sourceRequiredAsset.state {
            XCTAssertEqual(remoteSourceURL?.absoluteString, "https://example.com/direct-video.mp4")
        } else {
            XCTFail("Expected sourceRequired state for direct video media")
        }

        XCTAssertTrue(syncingAsset.state.countsAsSourceBacked)
        XCTAssertTrue(failedAsset.state.countsAsSourceBacked)
    }

    func testAPODOfflineMediaStorageSummaryCountsDerivedStateBuckets() {
        var summary = APODOfflineMediaStorageSummary()
        let fullAsset = APODOfflineMediaAsset(
            apodID: "full",
            mediaType: .image,
            remoteSourceURL: URL(string: "https://example.com/full.jpg"),
            localAssetRelativePath: "offline/full.jpg",
            availability: .availableOffline,
            byteCount: 1_024
        )
        let previewAsset = APODOfflineMediaAsset(
            apodID: "preview",
            mediaType: .video,
            remoteSourceURL: URL(string: "https://example.com/video"),
            localPreviewRelativePath: "offline/preview.jpg",
            availability: .previewOffline,
            byteCount: 256
        )
        let syncingAsset = APODOfflineMediaAsset(
            apodID: "syncing",
            mediaType: .image,
            remoteSourceURL: URL(string: "https://example.com/syncing.jpg"),
            availability: .syncing
        )
        let failedAsset = APODOfflineMediaAsset(
            apodID: "failed",
            mediaType: .image,
            remoteSourceURL: URL(string: "https://example.com/failed.jpg"),
            availability: .failed
        )

        summary.register(fullAsset)
        summary.register(previewAsset)
        summary.register(syncingAsset)
        summary.register(failedAsset)
        summary.register(nil)

        XCTAssertEqual(summary.fullyOfflineCount, 1)
        XCTAssertEqual(summary.previewCount, 1)
        XCTAssertEqual(summary.syncingCount, 1)
        XCTAssertEqual(summary.failedCount, 1)
        XCTAssertEqual(summary.remoteOnlyCount, 1)
        XCTAssertEqual(summary.totalByteCount, 1_280)
    }

    func testAPODOfflineMediaItemStateDerivesSavedPresentationAndStorageState() {
        let asset = APODOfflineMediaAsset(
            apodID: "video",
            mediaType: .video,
            remoteSourceURL: URL(string: "https://example.com/video"),
            localAssetRelativePath: "offline/video.mp4",
            availability: .availableOffline
        )
        let state = APODOfflineMediaItemState(mediaType: .video, asset: asset, isSaved: true)

        XCTAssertEqual(state.savedLibraryStorageState, .full)
        XCTAssertEqual(state.statusPresentation?.title, "Available Offline")
        XCTAssertEqual(state.localVideoURL?.lastPathComponent, "video.mp4")
    }

    func testAPODOfflineMediaLibraryStateBuildsSavedStatusBadgesFromSummary() {
        let summary = APODOfflineMediaStorageSummary(
            fullyOfflineCount: 2,
            previewCount: 1,
            remoteOnlyCount: 3,
            syncingCount: 0,
            failedCount: 0,
            totalByteCount: 4_096,
            lastUpdatedAt: nil
        )
        let state = APODOfflineMediaLibraryState(summary: summary)

        XCTAssertTrue(state.showsSavedStatusBadges)
        XCTAssertEqual(state.savedStatusBadges.map(\.title), ["2 offline", "1 preview"])
    }

    func testAPODOfflineMediaManagementStateDerivesMetricsAndCompletionMessage() {
        let summary = APODOfflineMediaStorageSummary(
            fullyOfflineCount: 1,
            previewCount: 2,
            remoteOnlyCount: 4,
            syncingCount: 1,
            failedCount: 1,
            totalByteCount: 2_048,
            lastUpdatedAt: nil
        )
        let state = APODOfflineMediaManagementState(
            summary: summary,
            operation: .idle,
            lastUpdatedText: "Apr 4, 2026 at 2:40 AM",
            lastCompletedAction: .rebuilt
        )

        XCTAssertTrue(state.canClear)
        XCTAssertTrue(state.canRebuild)
        XCTAssertEqual(
            state.metrics.map(\.id),
            ["saved-offline", "saved-preview", "source-required", "syncing", "failed", "media-size", "last-updated"]
        )
        XCTAssertEqual(state.actionMessage, "Offline media refreshed for your saved APOD items.")
    }

    func testAPODOfflineMediaManagementStateDisablesActionsWhileOperationRuns() {
        let summary = APODOfflineMediaStorageSummary(
            fullyOfflineCount: 0,
            previewCount: 0,
            remoteOnlyCount: 2,
            syncingCount: 0,
            failedCount: 0,
            totalByteCount: 0,
            lastUpdatedAt: nil
        )
        let state = APODOfflineMediaManagementState(
            summary: summary,
            operation: .clearing,
            lastUpdatedText: "Not available",
            lastCompletedAction: nil
        )

        XCTAssertFalse(state.canClear)
        XCTAssertFalse(state.canRebuild)
        XCTAssertNil(state.actionMessage)
    }

    func testPhotoExportServiceRejectsVideoEntriesBeforePhotoAuthorization() async {
        let service = PhotoExportService()
        let nasa = NASA(
            date: "2025-01-15",
            mediaType: .video,
            title: "Video Entry",
            url: URL(string: "https://example.com/video.mp4")
        )

        do {
            try await service.exportOriginalImage(for: nasa)
            XCTFail("Expected unsupported media error")
        } catch let error as PhotoExportService.ExportError {
            XCTAssertEqual(error, .unsupportedMedia)
        } catch {
            XCTFail("Expected PhotoExportService.ExportError, got \(error)")
        }
    }

    func testPhotoExportServiceRejectsMissingImageSourceBeforePhotoAuthorization() async {
        let service = PhotoExportService()
        let nasa = NASA(
            date: "2025-01-15",
            mediaType: .image,
            title: "Missing Source"
        )

        do {
            try await service.exportOriginalImage(for: nasa)
            XCTFail("Expected missing source error")
        } catch let error as PhotoExportService.ExportError {
            XCTAssertEqual(error, .missingSource)
        } catch {
            XCTFail("Expected PhotoExportService.ExportError, got \(error)")
        }
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

    func testAPODMediaPresentationPolicyUsesYouTubeThumbnailForVideoShareMedia() {
        let nasa = NASA(
            date: "2025-01-15",
            mediaType: .video,
            title: "Video Share",
            url: URL(string: "https://www.youtube.com/watch?v=abc123xyz")
        )

        let mediaItem = APODMediaPresentationPolicy.shareMediaItem(for: nasa) as? URL

        XCTAssertEqual(mediaItem?.absoluteString, "https://img.youtube.com/vi/abc123xyz/hqdefault.jpg")
    }

    func testAPODReaderSourceContextPrefersHDImageWhenAllowed() {
        let nasa = NASA(
            date: "2025-01-15",
            hdurl: URL(string: "https://example.com/image-hd.jpg"),
            mediaType: .image,
            title: "HD Context",
            url: URL(string: "https://example.com/image.jpg")
        )

        let context = APODReaderSourceContext(
            nasa: nasa,
            dataSaverMode: false,
            preferHDImages: true
        )

        XCTAssertEqual(context.nasaPageURL?.absoluteString, "https://apod.nasa.gov/apod/ap250115.html")
        XCTAssertEqual(context.preferredMediaSourceURL, nasa.hdurl)
        XCTAssertEqual(context.preferredMediaSourceTitle, "Open HD Image")
    }

    private func isolatedUserDefaults(name: String) -> UserDefaults {
        let suiteName = "MainViewStateTests.\(name).\(UUID().uuidString)"
        guard let userDefaults = UserDefaults(suiteName: suiteName) else {
            fatalError("Unable to create isolated user defaults suite: \(suiteName)")
        }

        userDefaults.removePersistentDomain(forName: suiteName)
        addTeardownBlock {
            userDefaults.removePersistentDomain(forName: suiteName)
        }
        return userDefaults
    }

    private func assertEventually(
        timeout: TimeInterval = 1.0,
        file: StaticString = #filePath,
        line: UInt = #line,
        condition: @escaping @Sendable () async -> Bool
    ) async {
        let deadline = Date().addingTimeInterval(timeout)

        while Date() < deadline {
            if await condition() {
                return
            }
            try? await Task.sleep(nanoseconds: 20_000_000)
        }

        let finalResult = await condition()
        XCTAssertTrue(finalResult, file: file, line: line)
    }

    private func temporaryDirectoryURL(named name: String) -> URL {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(name)-\(UUID().uuidString)", isDirectory: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: directoryURL)
        }
        return directoryURL
    }

    private func temporaryFileURL(named name: String, data: Data) throws -> URL {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(UUID().uuidString)-\(name)", isDirectory: false)
        try data.write(to: fileURL, options: .atomic)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: fileURL)
        }
        return fileURL
    }

    private func makeArchivePolicyItem(
        date: String,
        title: String,
        mediaKind: ArchiveLibraryPolicy.Item.MediaKind,
        isSaved: Bool,
        creditLine: String
    ) -> ArchiveLibraryPolicy.Item {
        ArchiveLibraryPolicy.Item(
            id: "\(date)-\(title)",
            date: date,
            title: title,
            creditLine: creditLine,
            mediaKind: mediaKind,
            isSaved: isSaved
        )
    }

    private func makeSavedPolicyItem(
        id: String,
        date: String,
        title: String,
        creditLine: String,
        storageState: SavedLibraryPolicy.Item.StorageState
    ) -> SavedLibraryPolicy.Item {
        SavedLibraryPolicy.Item(
            id: id,
            date: date,
            title: title,
            creditLine: creditLine,
            storageState: storageState
        )
    }
}

private actor MockPurchaseBackend: PurchaseBackend {
    private let productSnapshots: [StoreProductSnapshot]
    private var entitlementProductIDs: Set<String>
    private var updatesContinuation: AsyncStream<Set<String>>.Continuation?
    private var isSubscribed = false
    private var syncCount = 0

    init(
        productSnapshots: [StoreProductSnapshot] = [],
        entitlementProductIDs: Set<String> = []
    ) {
        self.productSnapshots = productSnapshots
        self.entitlementProductIDs = entitlementProductIDs
    }

    func loadProducts(productIDs: [String]) async throws -> [StoreProductSnapshot] {
        productSnapshots
    }

    func currentEntitlementProductIDs() async -> Set<String> {
        entitlementProductIDs
    }

    func purchase(productID: String) async throws -> PurchaseBackendResult {
        .purchased
    }

    func sync() async throws {
        syncCount += 1
    }

    func transactionUpdates() async -> AsyncStream<Set<String>> {
        isSubscribed = true
        return AsyncStream { continuation in
            updatesContinuation = continuation
        }
    }

    func setEntitlementProductIDs(_ productIDs: Set<String>) {
        entitlementProductIDs = productIDs
    }

    func emitTransactionUpdate() {
        updatesContinuation?.yield(entitlementProductIDs)
    }

    func syncCallCount() -> Int {
        syncCount
    }

    func waitUntilSubscribed(timeoutNanoseconds: UInt64 = 1_000_000_000) async -> Bool {
        let deadline = DispatchTime.now().uptimeNanoseconds + timeoutNanoseconds

        while DispatchTime.now().uptimeNanoseconds < deadline {
            if isSubscribed {
                return true
            }
            try? await Task.sleep(nanoseconds: 20_000_000)
        }

        return isSubscribed
    }
}
