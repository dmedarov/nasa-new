import XCTest

final class NASANewUITests: XCTestCase {
    private enum UIElementID {
        static let appShellSplitRoot = "appShellSplitRoot"
        static let appShellSidebar = "appShellSidebar"
        static let appShellDetail = "appShellDetail"
        static let mainViewRoot = "mainViewRoot"
        static let mainContentScrollView = "mainContentScrollView"
        static let splashScreenRoot = "splashScreenRoot"
        static let shareAPODButton = "shareAPODButton"
        static let shareSection = "shareSection"
        static let refreshAPODButton = "refreshAPODButton"
        static let randomAPODButton = "randomAPODButton"
        static let openArchiveButton = "openArchiveButton"
        static let openSettingsButton = "openSettingsButton"
        static let openFavoritesButton = "openFavoritesButton"
        static let apiRequestFailureState = "apiRequestFailureState"
        static let apiOfflineBanner = "apiOfflineBanner"
        static let apiRateLimitBanner = "apiRateLimitBanner"
        static let settingsSheetRoot = "settingsSheetRoot"
        static let settingsCloseButton = "settingsCloseButton"
        static let followSystemAppearanceToggle = "followSystemAppearanceToggle"
        static let darkModeToggle = "darkModeToggle"
        static let notificationEducationText = "notificationEducationText"
        static let aboutSourceRightsPanel = "aboutSourceRightsPanel"
        static let favoritesSheetRoot = "favoritesSheetRoot"
        static let favoritesEmptyState = "favoritesEmptyState"
        static let favoritesSearchField = "favoritesSearchField"
        static let archiveSheetRoot = "archiveSheetRoot"
        static let archiveSearchField = "archiveSearchField"
        static let archiveDetailBackButton = "archiveDetailBackButton"
        static let savedDetailBackButton = "savedDetailBackButton"
        static let favoriteAPODButton = "favoriteAPODButton"
        static let jumpToLatestAPODDateButton = "jumpToLatestAPODDateButton"
        static let previousAPODDateButton = "previousAPODDateButton"
        static let nextAPODDateButton = "nextAPODDateButton"
        static let paywallRoot = "paywallRoot"
        static let paywallContinueButton = "paywallContinueButton"
        static let paywallUnlockButton = "paywallUnlockButton"
        static let saveToPhotosButton = "saveToPhotosButton"
        static let apodTitleText = "apodTitleText"
        static let apodDateText = "apodDateText"
        static let apodExplanationToggleButton = "apodExplanationToggleButton"
        static let dataSaverModeToggle = "dataSaverModeToggle"
        static let preferHDImagesToggle = "preferHDImagesToggle"
        static let lastStatusCodeValue = "lastStatusCodeValue"
        static let networkConnectionValue = "networkConnectionValue"
        static let meteredNetworkValue = "meteredNetworkValue"
        static let lowDataModeValue = "lowDataModeValue"
        static let autoplayPolicyValue = "autoplayPolicyValue"
        static let networkEfficiencyValue = "networkEfficiencyValue"
        static let directVideoPlayer = "directVideoPlayer"
        static let playVideoInAppButton = "playVideoInAppButton"
        static let unsupportedVideoMessage = "unsupportedVideoMessage"
        static let apodImageUnavailableMessage = "apodImageUnavailableMessage"
        static let videoAutoplayPausedBadge = "videoAutoplayPausedBadge"

        static func favoriteRow(date: String) -> String {
            "favoriteAPODRow-\(date)"
        }

        static func favoriteDeleteAction(date: String) -> String {
            "favoriteAPODDelete-\(date)"
        }

        static func archiveRow(date: String) -> String {
            "archiveAPODRow-\(date)"
        }

        static func appShellSidebarDestination(_ destination: String) -> String {
            "appShellSidebarDestination-\(destination)"
        }
    }

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    override func tearDownWithError() throws {
        if app?.state == .runningForeground || app?.state == .runningBackground {
            app.terminate()
        }
        app = nil
    }

    private func configureLaunchEnvironment(
        stayOnSplash: Bool = false,
        holdSplash: Bool = false,
        fixtureMode: String = "default",
        locale: String = "en_US_POSIX",
        networkKind: String? = nil,
        isExpensiveNetwork: Bool = false,
        isConstrainedNetwork: Bool = false,
        dataSaverMode: Bool? = nil,
        preferHDImages: Bool? = nil,
        wifiOnlyAutoplay: Bool? = nil,
        dynamicTypeSize: String? = nil,
        colorScheme: String? = nil,
        colorSchemeContrast: String? = nil,
        reduceMotion: Bool? = nil,
        reduceTransparency: Bool? = nil,
        differentiateWithoutColor: Bool? = nil,
        resetUserDefaults: Bool = true,
        pendingRouteDestination: String? = nil,
        pendingRouteDate: String? = nil,
        hasPro: Bool = false,
        preloadedFavoriteDates: [String]? = nil,
        forcePhotoExportSuccess: Bool = false
    ) {
        app.launchArguments += ["-ui-testing"]
        app.launchEnvironment["UITEST_USE_FIXTURE"] = "1"
        app.launchEnvironment["UITEST_FIXTURE_MODE"] = fixtureMode
        app.launchEnvironment["UITEST_LIBRARY_STORAGE"] = "userdefaults"
        app.launchEnvironment["UITEST_LOCALE"] = locale
        app.launchEnvironment["UITEST_TIMEZONE"] = "UTC"
        app.launchEnvironment["UITEST_DISABLE_ANIMATIONS"] = "1"
        app.launchEnvironment["UITEST_RESET_USER_DEFAULTS"] = resetUserDefaults ? "1" : "0"
        app.launchEnvironment["UITEST_DISABLE_SCENE_RESTORATION"] = "1"

        if stayOnSplash {
            app.launchEnvironment["UITEST_STAY_ON_SPLASH"] = "1"
        }
        if holdSplash {
            app.launchEnvironment["UITEST_HOLD_SPLASH"] = "1"
        }
        if let networkKind {
            app.launchEnvironment["UITEST_NETWORK_KIND"] = networkKind
            app.launchEnvironment["UITEST_NETWORK_EXPENSIVE"] = isExpensiveNetwork ? "1" : "0"
            app.launchEnvironment["UITEST_NETWORK_CONSTRAINED"] = isConstrainedNetwork ? "1" : "0"
        }
        if let dataSaverMode {
            app.launchEnvironment["UITEST_DEFAULT_DATA_SAVER"] = dataSaverMode ? "1" : "0"
        }
        if let preferHDImages {
            app.launchEnvironment["UITEST_DEFAULT_PREFER_HD_IMAGES"] = preferHDImages ? "1" : "0"
        }
        if let wifiOnlyAutoplay {
            app.launchEnvironment["UITEST_DEFAULT_WIFI_ONLY_AUTOPLAY"] = wifiOnlyAutoplay ? "1" : "0"
        }
        if let dynamicTypeSize {
            app.launchEnvironment["UITEST_DYNAMIC_TYPE_SIZE"] = dynamicTypeSize
        }
        if let colorScheme {
            app.launchEnvironment["UITEST_FORCE_COLOR_SCHEME"] = colorScheme
        }
        if let colorSchemeContrast {
            app.launchEnvironment["UITEST_COLOR_SCHEME_CONTRAST"] = colorSchemeContrast
        }
        if let reduceMotion {
            app.launchEnvironment["UITEST_REDUCE_MOTION"] = reduceMotion ? "1" : "0"
        }
        if let reduceTransparency {
            app.launchEnvironment["UITEST_REDUCE_TRANSPARENCY"] = reduceTransparency ? "1" : "0"
        }
        if let differentiateWithoutColor {
            app.launchEnvironment["UITEST_DIFFERENTIATE_WITHOUT_COLOR"] = differentiateWithoutColor ? "1" : "0"
        }
        if let pendingRouteDestination {
            app.launchEnvironment["UITEST_PENDING_ROUTE_DESTINATION"] = pendingRouteDestination
        }
        if let pendingRouteDate {
            app.launchEnvironment["UITEST_PENDING_ROUTE_DATE"] = pendingRouteDate
        }
        app.launchEnvironment["UITEST_HAS_PRO"] = hasPro ? "1" : "0"
        if let preloadedFavoriteDates, !preloadedFavoriteDates.isEmpty {
            app.launchEnvironment["UITEST_PRELOAD_FAVORITE_DATES"] = preloadedFavoriteDates.joined(separator: ",")
        }
        if forcePhotoExportSuccess {
            app.launchEnvironment["UITEST_FORCE_PHOTO_EXPORT_SUCCESS"] = "1"
        }
    }

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }

    private func waitForElement(identifier: String, timeout: TimeInterval) -> Bool {
        element(identifier).waitForExistence(timeout: timeout)
    }

    private func waitForAPODTitle(containing expectedValue: String, timeout: TimeInterval = 5.0) -> Bool {
        let titleElement = element(UIElementID.apodTitleText)
        if titleElement.waitForExistence(timeout: min(timeout, 2.0)) {
            return waitForLabelContaining(titleElement, substring: expectedValue, timeout: timeout)
        }
        return waitForAnyLabel(containing: expectedValue, timeout: timeout)
    }

    private func waitForFavoriteButton(timeout: TimeInterval = 5.0) -> XCUIElement? {
        if waitForElement(identifier: UIElementID.favoriteAPODButton, timeout: min(timeout, 2.0)) {
            return element(UIElementID.favoriteAPODButton)
        }

        let addFavoriteButton = app.buttons["Add to favorites"]
        if addFavoriteButton.waitForExistence(timeout: timeout) {
            return addFavoriteButton
        }

        let removeFavoriteButton = app.buttons["Remove from favorites"]
        if removeFavoriteButton.waitForExistence(timeout: timeout) {
            return removeFavoriteButton
        }

        return nil
    }

    private func waitForFavoritesSearchInput(timeout: TimeInterval = 5.0) -> XCUIElement? {
        let searchField = app.searchFields["Search favorites"]
        if searchField.waitForExistence(timeout: min(timeout, 2.0)) {
            return searchField
        }

        let textField = app.textFields["Search favorites"]
        if textField.waitForExistence(timeout: min(timeout, 2.0)) {
            return textField
        }

        let identifiedField = element(UIElementID.favoritesSearchField)
        if identifiedField.waitForExistence(timeout: timeout) {
            return identifiedField
        }

        return nil
    }

    private func waitForArchiveSearchInput(timeout: TimeInterval = 5.0) -> XCUIElement? {
        let searchField = app.searchFields["Search archive"]
        if searchField.waitForExistence(timeout: min(timeout, 2.0)) {
            return searchField
        }

        let textField = app.textFields["Search archive"]
        if textField.waitForExistence(timeout: min(timeout, 2.0)) {
            return textField
        }

        let identifiedField = element(UIElementID.archiveSearchField)
        if identifiedField.waitForExistence(timeout: timeout) {
            return identifiedField
        }

        return nil
    }

    private func waitForFilterOption(_ title: String, timeout: TimeInterval = 5.0) -> XCUIElement? {
        let segmentedButton = app.segmentedControls.buttons[title]
        if segmentedButton.waitForExistence(timeout: min(timeout, 2.0)) {
            return segmentedButton
        }

        let button = app.buttons[title]
        if button.waitForExistence(timeout: timeout) {
            return button
        }

        return nil
    }

    private func revealElement(_ target: XCUIElement, maxSwipes: Int = 5) {
        var swipeCount = 0
        while !target.exists && swipeCount < maxSwipes {
            swipeUpPrimaryContent()
            swipeCount += 1
        }
    }

    private func scrollElementToHittable(_ target: XCUIElement, maxSwipes: Int = 5) {
        var swipeCount = 0
        while !target.isHittable && swipeCount < maxSwipes {
            swipeUpPrimaryContent()
            swipeCount += 1
        }
    }

    private func activeScrollSurface() -> XCUIElement? {
        if element(UIElementID.archiveSheetRoot).exists || element(UIElementID.favoritesSheetRoot).exists {
            let candidates = [app.collectionViews.firstMatch, app.tables.firstMatch, app.scrollViews.firstMatch]
            return candidates.first(where: { $0.waitForExistence(timeout: 0.5) })
        }

        let primaryScrollView = element(UIElementID.mainContentScrollView)
        if primaryScrollView.waitForExistence(timeout: 0.5) {
            return primaryScrollView
        }

        let fallbackCandidates = [app.scrollViews.firstMatch, app.collectionViews.firstMatch, app.tables.firstMatch]
        return fallbackCandidates.first(where: { $0.waitForExistence(timeout: 0.5) })
    }

    private func swipeUpPrimaryContent() {
        if element(UIElementID.settingsSheetRoot).exists {
            app.swipeUp()
            return
        }

        guard let scrollSurface = activeScrollSurface() else {
            app.swipeUp()
            return
        }

        let start = scrollSurface.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.82))
        let end = scrollSurface.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.22))
        start.press(forDuration: 0.01, thenDragTo: end)
    }

    private func waitForAnyLabel(containing text: String, timeout: TimeInterval) -> Bool {
        let predicate = NSPredicate(format: "label CONTAINS %@", text)
        return app.descendants(matching: .any).matching(predicate).firstMatch.waitForExistence(timeout: timeout)
    }

    private func waitForElementToBecomeHittable(_ element: XCUIElement, timeout: TimeInterval) -> Bool {
        let predicate = NSPredicate(format: "hittable == true")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }

    private func waitForElementToDisappear(_ element: XCUIElement, timeout: TimeInterval) -> Bool {
        let predicate = NSPredicate(format: "exists == false")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }

    private func tapElement(_ identifier: String, timeout: TimeInterval = 5.0) {
        let target = element(identifier)
        XCTAssertTrue(target.waitForExistence(timeout: timeout))
        revealElement(target)
        scrollElementToHittable(target)
        XCTAssertTrue(waitForElementToBecomeHittable(target, timeout: timeout))
        target.tap()
    }

    private func tapSidebarDestination(_ destination: String, timeout: TimeInterval = 5.0) {
        let target = element(UIElementID.appShellSidebarDestination(destination))
        XCTAssertTrue(target.waitForExistence(timeout: timeout))
        XCTAssertTrue(waitForElementToBecomeHittable(target, timeout: timeout))
        target.tap()
    }

    private func requireSplitShell(timeout: TimeInterval = 5.0) throws {
        if waitForElement(identifier: UIElementID.appShellSplitRoot, timeout: timeout) {
            XCTAssertTrue(waitForElement(identifier: UIElementID.appShellSidebar, timeout: timeout))
            XCTAssertTrue(waitForElement(identifier: UIElementID.appShellDetail, timeout: timeout))
            return
        }

        throw XCTSkip("Requires the regular-width iPad split shell.")
    }

    private func waitForSwitchValue(_ element: XCUIElement, equals expectedValue: String, timeout: TimeInterval) -> Bool {
        let predicate = NSPredicate(format: "value == %@", expectedValue)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }

    private func waitForLabel(_ element: XCUIElement, equals expectedValue: String, timeout: TimeInterval) -> Bool {
        let predicate = NSPredicate(format: "label == %@", expectedValue)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }

    private func waitForLabelContaining(_ element: XCUIElement, substring: String, timeout: TimeInterval) -> Bool {
        let predicate = NSPredicate(format: "label CONTAINS %@", substring)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }

    private func waitForValueContaining(_ element: XCUIElement, substring: String, timeout: TimeInterval) -> Bool {
        let predicate = NSPredicate(format: "value CONTAINS %@", substring)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }

    private func waitForLabelContainingAny(_ element: XCUIElement, substrings: [String], timeout: TimeInterval) -> Bool {
        let predicate = NSPredicate { _, _ in
            let label = element.label
            return substrings.contains { label.contains($0) }
        }
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }

    private func openSettingsAndReadDiagnosticsStatus(waitForNumericStatus: Bool = false) -> String {
        tapElement(UIElementID.openSettingsButton)
        XCTAssertTrue(waitForElement(identifier: UIElementID.settingsSheetRoot, timeout: 5.0))
        let statusCodeValue = app.staticTexts[UIElementID.lastStatusCodeValue]
        XCTAssertTrue(statusCodeValue.waitForExistence(timeout: 5.0))
        if waitForNumericStatus {
            XCTAssertTrue(waitForLabelContainingAny(statusCodeValue, substrings: ["429", "200"], timeout: 5.0))
        }
        return statusCodeValue.label
    }

    private func closeSettingsSheet() {
        let closeButton = app.buttons[UIElementID.settingsCloseButton]
        XCTAssertTrue(closeButton.waitForExistence(timeout: 5.0))
        closeButton.tap()
        XCTAssertTrue(waitForElementToDisappear(element(UIElementID.settingsSheetRoot), timeout: 5.0))
    }

    private func attachDebugMarker(_ name: String, details: String) {
        let attachment = XCTAttachment(string: details)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func monetizationFavoriteSeedDates() -> [String] {
        (5...14).map { String(format: "2025-01-%02d", $0) }
    }

    private func dismissPaywall() {
        let continueButton = element(UIElementID.paywallContinueButton)
        XCTAssertTrue(continueButton.waitForExistence(timeout: 5.0))
        continueButton.tap()
        XCTAssertTrue(waitForPaywallToDisappear(timeout: 5.0))
    }

    private func waitForPaywall(timeout: TimeInterval = 5.0) -> Bool {
        let continueButton = element(UIElementID.paywallContinueButton)
        if continueButton.waitForExistence(timeout: timeout) {
            return true
        }

        let unlockButton = element(UIElementID.paywallUnlockButton)
        return unlockButton.waitForExistence(timeout: timeout)
    }

    private func waitForPaywallToDisappear(timeout: TimeInterval = 5.0) -> Bool {
        let continueButton = element(UIElementID.paywallContinueButton)
        let unlockButton = element(UIElementID.paywallUnlockButton)

        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if !continueButton.exists && !unlockButton.exists {
                return true
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }

        return !continueButton.exists && !unlockButton.exists
    }

    private func launchAndWaitForMainView(fixtureMode: String = "default", dataSaverMode: Bool? = nil, preferHDImages: Bool? = nil) {
        configureLaunchEnvironment(
            fixtureMode: fixtureMode,
            dataSaverMode: dataSaverMode,
            preferHDImages: preferHDImages
        )
        attachDebugMarker("LaunchConfig", details: app.launchEnvironment.description)
        app.launch()
        XCTAssertTrue(waitForElement(identifier: UIElementID.mainViewRoot, timeout: 5.0))
        attachDebugMarker("MainViewReady", details: "mainViewRoot visible")
    }

    private func navigateBackToEarlierAPODDay() {
        let previousDateButton = app.buttons[UIElementID.previousAPODDateButton]
        XCTAssertTrue(previousDateButton.waitForExistence(timeout: 5.0))
        revealElement(previousDateButton)
        scrollElementToHittable(previousDateButton)
        XCTAssertTrue(waitForElementToBecomeHittable(previousDateButton, timeout: 5.0))
        attachDebugMarker("DateNavBeforeFirstTap", details: previousDateButton.debugDescription)
        previousDateButton.tap()
        XCTAssertTrue(waitForAPODTitle(containing: "Fixture APOD 2025-01-14"))
        attachDebugMarker("DateNavAfterFirstTap", details: "Reached 2025-01-14")
        let refreshedPreviousDateButton = app.buttons[UIElementID.previousAPODDateButton]
        revealElement(refreshedPreviousDateButton)
        scrollElementToHittable(refreshedPreviousDateButton)
        XCTAssertTrue(waitForElementToBecomeHittable(refreshedPreviousDateButton, timeout: 5.0))
        refreshedPreviousDateButton.tap()
        XCTAssertTrue(waitForAPODTitle(containing: "Fixture APOD 2025-01-13"))
        attachDebugMarker("DateNavAfterSecondTap", details: "Reached 2025-01-13")
    }

    private func openSettingsAndRevealDataSaverControls() -> (dataSaverSwitch: XCUIElement, preferHDSwitch: XCUIElement) {
        tapElement(UIElementID.openSettingsButton)
        XCTAssertTrue(waitForElement(identifier: UIElementID.settingsSheetRoot, timeout: 5.0))
        let dataSaverSwitch = app.switches[UIElementID.dataSaverModeToggle]
        let preferHDSwitch = app.switches[UIElementID.preferHDImagesToggle]
        revealElement(dataSaverSwitch)
        XCTAssertTrue(dataSaverSwitch.waitForExistence(timeout: 5.0))
        revealElement(preferHDSwitch)
        XCTAssertTrue(preferHDSwitch.waitForExistence(timeout: 5.0))
        attachDebugMarker("DataSaverControlsVisible", details: "\(dataSaverSwitch.debugDescription)\n\(preferHDSwitch.debugDescription)")
        return (dataSaverSwitch, preferHDSwitch)
    }

    func testSplashScreenSnapshot() {
        configureLaunchEnvironment(stayOnSplash: true, holdSplash: true)
        app.launch()

        XCTAssertTrue(waitForElement(identifier: UIElementID.splashScreenRoot, timeout: 5.0))
        XCTAssertFalse(app.buttons[UIElementID.shareAPODButton].exists)

        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "SplashScreen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testMainScreenCriticalControlsAndSnapshot() {
        configureLaunchEnvironment()
        app.launch()

        XCTAssertTrue(waitForElement(identifier: UIElementID.mainViewRoot, timeout: 5.0))
        XCTAssertTrue(app.buttons[UIElementID.shareAPODButton].waitForExistence(timeout: 5.0))
        XCTAssertTrue(app.buttons[UIElementID.refreshAPODButton].exists)
        XCTAssertTrue(app.buttons[UIElementID.openSettingsButton].exists)
        XCTAssertTrue(app.buttons[UIElementID.randomAPODButton].exists)
        XCTAssertTrue(waitForAPODTitle(containing: "Fixture APOD"))

        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "MainScreen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testUnsupportedVideoFallbackControlsAppear() {
        configureLaunchEnvironment(fixtureMode: "unsupported_video")
        app.launch()

        XCTAssertTrue(waitForElement(identifier: UIElementID.mainViewRoot, timeout: 5.0))
        XCTAssertTrue(waitForAPODTitle(containing: "Fixture Unsupported Video"))
        XCTAssertTrue(waitForElement(identifier: UIElementID.playVideoInAppButton, timeout: 5.0))
    }

    func testDirectVideoInlinePlayerAppears() {
        configureLaunchEnvironment(fixtureMode: "direct_video")
        app.launch()

        XCTAssertTrue(waitForElement(identifier: UIElementID.mainViewRoot, timeout: 5.0))
        XCTAssertTrue(waitForAPODTitle(containing: "Fixture Direct Video"))
        XCTAssertFalse(element(UIElementID.playVideoInAppButton).exists)
        XCTAssertFalse(element(UIElementID.unsupportedVideoMessage).exists)
    }

    func testPreviousDateNavigationLoadsEarlierFixture() {
        configureLaunchEnvironment(fixtureMode: "date_navigation")
        app.launch()

        XCTAssertTrue(waitForElement(identifier: UIElementID.mainViewRoot, timeout: 5.0))
        XCTAssertTrue(waitForAPODTitle(containing: "Fixture APOD 2025-01-15"))

        let previousDateButton = app.buttons[UIElementID.previousAPODDateButton]
        XCTAssertTrue(previousDateButton.waitForExistence(timeout: 5.0))
        revealElement(previousDateButton)
        scrollElementToHittable(previousDateButton)
        previousDateButton.tap()

        XCTAssertTrue(waitForAPODTitle(containing: "Fixture APOD 2025-01-14"))
        tapElement(UIElementID.previousAPODDateButton)
        XCTAssertTrue(waitForAPODTitle(containing: "Fixture APOD 2025-01-13"))
    }

    func testNextDateNavigationReturnsToLatestFixture() {
        configureLaunchEnvironment(fixtureMode: "date_navigation")
        app.launch()

        XCTAssertTrue(waitForElement(identifier: UIElementID.mainViewRoot, timeout: 5.0))
        XCTAssertTrue(waitForAPODTitle(containing: "Fixture APOD 2025-01-15"))

        let previousDateButton = app.buttons[UIElementID.previousAPODDateButton]
        let nextDateButton = app.buttons[UIElementID.nextAPODDateButton]
        XCTAssertTrue(previousDateButton.waitForExistence(timeout: 5.0))
        XCTAssertTrue(nextDateButton.waitForExistence(timeout: 5.0))

        revealElement(previousDateButton)
        scrollElementToHittable(previousDateButton)
        previousDateButton.tap()
        XCTAssertTrue(waitForAPODTitle(containing: "Fixture APOD 2025-01-14"))
        revealElement(nextDateButton)
        scrollElementToHittable(nextDateButton)
        nextDateButton.tap()
        XCTAssertTrue(waitForAPODTitle(containing: "Fixture APOD 2025-01-15"))
    }

    func testTodayNavigationReturnsToLatestFixture() {
        launchAndWaitForMainView(fixtureMode: "date_navigation")
        XCTAssertTrue(waitForAPODTitle(containing: "Fixture APOD 2025-01-15"))
        XCTAssertTrue(app.buttons[UIElementID.jumpToLatestAPODDateButton].waitForExistence(timeout: 5.0))
        navigateBackToEarlierAPODDay()
        let refreshedTodayButton = app.buttons[UIElementID.jumpToLatestAPODDateButton]
        revealElement(refreshedTodayButton)
        scrollElementToHittable(refreshedTodayButton)
        XCTAssertTrue(waitForElementToBecomeHittable(refreshedTodayButton, timeout: 5.0))
        attachDebugMarker("TodayButtonReady", details: refreshedTodayButton.debugDescription)
        refreshedTodayButton.tap()
        XCTAssertTrue(waitForAPODTitle(containing: "Fixture APOD 2025-01-15"))
        attachDebugMarker("TodayNavigationComplete", details: "Returned to 2025-01-15")
    }

    func testDirectVideoAutoplayPolicyRequiresManualPlaybackOffWiFi() {
        configureLaunchEnvironment(
            fixtureMode: "direct_video",
            networkKind: "cellular",
            isExpensiveNetwork: true
        )
        app.launch()

        XCTAssertTrue(waitForElement(identifier: UIElementID.mainViewRoot, timeout: 5.0))
        XCTAssertTrue(waitForAPODTitle(containing: "Fixture Direct Video"))
        XCTAssertFalse(element(UIElementID.playVideoInAppButton).exists)

        tapElement(UIElementID.openSettingsButton)
        XCTAssertTrue(waitForElement(identifier: UIElementID.settingsSheetRoot, timeout: 5.0))
        let networkConnectionValue = element(UIElementID.networkConnectionValue)
        revealElement(networkConnectionValue)
        XCTAssertTrue(networkConnectionValue.waitForExistence(timeout: 5.0))
        XCTAssertTrue(waitForLabelContaining(networkConnectionValue, substring: "Cellular", timeout: 5.0))

        let meteredNetworkValue = element(UIElementID.meteredNetworkValue)
        revealElement(meteredNetworkValue)
        XCTAssertTrue(meteredNetworkValue.waitForExistence(timeout: 5.0))
        XCTAssertTrue(waitForLabelContaining(meteredNetworkValue, substring: "Yes", timeout: 5.0))

        let autoplayPolicyValue = element(UIElementID.autoplayPolicyValue)
        revealElement(autoplayPolicyValue)
        XCTAssertTrue(autoplayPolicyValue.waitForExistence(timeout: 5.0))
        XCTAssertTrue(waitForLabelContaining(autoplayPolicyValue, substring: "Manual play required off Wi-Fi", timeout: 5.0))
    }

    func testDirectVideoAutoplayPolicyAllowsPlaybackOnWiFi() {
        configureLaunchEnvironment(
            fixtureMode: "direct_video",
            networkKind: "wifi"
        )
        app.launch()

        XCTAssertTrue(waitForElement(identifier: UIElementID.mainViewRoot, timeout: 5.0))
        XCTAssertTrue(waitForAPODTitle(containing: "Fixture Direct Video"))
        XCTAssertFalse(element(UIElementID.playVideoInAppButton).exists)

        tapElement(UIElementID.openSettingsButton)
        XCTAssertTrue(waitForElement(identifier: UIElementID.settingsSheetRoot, timeout: 5.0))
        let networkConnectionValue = element(UIElementID.networkConnectionValue)
        revealElement(networkConnectionValue)
        XCTAssertTrue(networkConnectionValue.waitForExistence(timeout: 5.0))
        XCTAssertTrue(waitForLabelContaining(networkConnectionValue, substring: "Wi-Fi", timeout: 5.0))

        let autoplayPolicyValue = element(UIElementID.autoplayPolicyValue)
        revealElement(autoplayPolicyValue)
        XCTAssertTrue(autoplayPolicyValue.waitForExistence(timeout: 5.0))
        XCTAssertTrue(waitForLabelContaining(autoplayPolicyValue, substring: "Autoplay allowed on Wi-Fi", timeout: 5.0))
    }

    func testConstrainedNetworkShowsMaximumSavingsDiagnostics() {
        configureLaunchEnvironment(
            fixtureMode: "direct_video",
            networkKind: "cellular",
            isExpensiveNetwork: true,
            isConstrainedNetwork: true,
            dataSaverMode: true,
            preferHDImages: false,
            wifiOnlyAutoplay: true
        )
        app.launch()

        XCTAssertTrue(waitForElement(identifier: UIElementID.mainViewRoot, timeout: 5.0))
        tapElement(UIElementID.openSettingsButton)
        XCTAssertTrue(waitForElement(identifier: UIElementID.settingsSheetRoot, timeout: 5.0))
        let lowDataModeValue = element(UIElementID.lowDataModeValue)
        revealElement(lowDataModeValue)
        XCTAssertTrue(lowDataModeValue.waitForExistence(timeout: 5.0))
        XCTAssertTrue(waitForLabelContaining(lowDataModeValue, substring: "Yes", timeout: 5.0))

        let networkEfficiencyValue = element(UIElementID.networkEfficiencyValue)
        revealElement(networkEfficiencyValue)
        XCTAssertTrue(networkEfficiencyValue.waitForExistence(timeout: 5.0))
        XCTAssertTrue(waitForLabelContaining(networkEfficiencyValue, substring: "Maximum savings. App data saver and Low Data Mode are both active.", timeout: 5.0))
    }

    func testSettingsShowsNotificationGuidanceAndAboutPanel() {
        configureLaunchEnvironment()
        app.launch()

        XCTAssertTrue(waitForElement(identifier: UIElementID.mainViewRoot, timeout: 5.0))
        tapElement(UIElementID.openSettingsButton)
        XCTAssertTrue(waitForElement(identifier: UIElementID.settingsSheetRoot, timeout: 5.0))

        let notificationEducation = element(UIElementID.notificationEducationText)
        revealElement(notificationEducation)
        XCTAssertTrue(notificationEducation.waitForExistence(timeout: 5.0))
        XCTAssertTrue(
            waitForLabelContaining(
                notificationEducation,
                substring: "gentle daily reminder",
                timeout: 5.0
            )
        )

        let aboutPanel = element(UIElementID.aboutSourceRightsPanel)
        revealElement(aboutPanel)
        XCTAssertTrue(aboutPanel.waitForExistence(timeout: 5.0))
    }

    func testDataSaverDisablesAndClearsHDImagePreference() {
        launchAndWaitForMainView(dataSaverMode: false, preferHDImages: true)
        let controls = openSettingsAndRevealDataSaverControls()
        let dataSaverSwitch = controls.dataSaverSwitch
        let preferHDSwitch = controls.preferHDSwitch
        XCTAssertTrue(waitForElementToBecomeHittable(dataSaverSwitch, timeout: 5.0))
        XCTAssertTrue(waitForSwitchValue(preferHDSwitch, equals: "1", timeout: 5.0))
        XCTAssertTrue(preferHDSwitch.isEnabled)
        attachDebugMarker("DataSaverInitialState", details: "dataSaver=\(String(describing: dataSaverSwitch.value)) preferHD=\(String(describing: preferHDSwitch.value))")
        dataSaverSwitch.tap()
        let refreshedDataSaverSwitch = app.switches[UIElementID.dataSaverModeToggle]
        let refreshedPreferHDSwitch = app.switches[UIElementID.preferHDImagesToggle]
        XCTAssertTrue(waitForSwitchValue(refreshedDataSaverSwitch, equals: "1", timeout: 5.0))
        XCTAssertTrue(waitForSwitchValue(refreshedPreferHDSwitch, equals: "0", timeout: 5.0))
        XCTAssertFalse(refreshedPreferHDSwitch.isEnabled)
        attachDebugMarker("DataSaverFinalState", details: "dataSaver=\(String(describing: refreshedDataSaverSwitch.value)) preferHD=\(String(describing: refreshedPreferHDSwitch.value)) enabled=\(refreshedPreferHDSwitch.isEnabled)")
    }

    func testAppearanceSwitchAllowsManualDarkModeSelection() {
        configureLaunchEnvironment(colorScheme: "light")
        app.launch()

        XCTAssertTrue(waitForElement(identifier: UIElementID.mainViewRoot, timeout: 5.0))
        tapElement(UIElementID.openSettingsButton)
        XCTAssertTrue(waitForElement(identifier: UIElementID.settingsSheetRoot, timeout: 5.0))

        let followSystemSwitch = app.switches[UIElementID.followSystemAppearanceToggle]
        let darkModeSwitch = app.switches[UIElementID.darkModeToggle]
        revealElement(followSystemSwitch)
        XCTAssertTrue(followSystemSwitch.waitForExistence(timeout: 5.0))
        XCTAssertTrue(darkModeSwitch.waitForExistence(timeout: 5.0))
        XCTAssertTrue(waitForSwitchValue(followSystemSwitch, equals: "1", timeout: 5.0))

        followSystemSwitch.tap()

        let refreshedFollowSystemSwitch = app.switches[UIElementID.followSystemAppearanceToggle]
        let refreshedDarkModeSwitch = app.switches[UIElementID.darkModeToggle]
        XCTAssertTrue(waitForSwitchValue(refreshedFollowSystemSwitch, equals: "0", timeout: 5.0))
        XCTAssertTrue(waitForSwitchValue(refreshedDarkModeSwitch, equals: "0", timeout: 5.0))
        XCTAssertTrue(refreshedDarkModeSwitch.isEnabled)

        refreshedDarkModeSwitch.tap()

        let enabledDarkModeSwitch = app.switches[UIElementID.darkModeToggle]
        XCTAssertTrue(waitForSwitchValue(enabledDarkModeSwitch, equals: "1", timeout: 5.0))
    }

    func testFavoritesSearchAndSwipeDeleteFlow() {
        launchAndWaitForMainView()
        XCTAssertTrue(waitForAPODTitle(containing: "Fixture APOD"))
        guard let favoriteButton = waitForFavoriteButton() else {
            XCTFail("Expected a favorite button to become available")
            return
        }
        scrollElementToHittable(favoriteButton)
        XCTAssertTrue(waitForElementToBecomeHittable(favoriteButton, timeout: 5.0))
        favoriteButton.tap()
        tapElement(UIElementID.openFavoritesButton)
        XCTAssertTrue(waitForElement(identifier: UIElementID.favoritesSheetRoot, timeout: 5.0))

        if let searchField = waitForFavoritesSearchInput(timeout: 2.0) {
            searchField.tap()
            searchField.typeText("Fixture\n")
        } else {
            attachDebugMarker("FavoritesSearchUnavailable", details: "Search input was not exposed by the simulator accessibility hierarchy; continuing with row/delete validation.")
        }

        let favoriteRow = element(UIElementID.favoriteRow(date: "2025-01-15"))
        revealElement(favoriteRow)
        XCTAssertTrue(favoriteRow.waitForExistence(timeout: 5.0))
        scrollElementToHittable(favoriteRow)
        XCTAssertTrue(waitForElementToBecomeHittable(favoriteRow, timeout: 5.0))
        favoriteRow.swipeLeft()
        let deleteButton = element(UIElementID.favoriteDeleteAction(date: "2025-01-15"))
        revealElement(deleteButton)
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 3.0))
        deleteButton.tap()

        XCTAssertTrue(waitForElement(identifier: UIElementID.favoritesEmptyState, timeout: 5.0))
    }

    func testArchiveSearchAndSelectionFlow() {
        configureLaunchEnvironment(fixtureMode: "date_navigation")
        app.launch()

        XCTAssertTrue(waitForElement(identifier: UIElementID.mainViewRoot, timeout: 5.0))
        XCTAssertTrue(waitForAPODTitle(containing: "Fixture APOD 2025-01-15"))

        tapElement(UIElementID.openArchiveButton)
        XCTAssertTrue(waitForElement(identifier: UIElementID.archiveSheetRoot, timeout: 5.0))

        guard let searchField = waitForArchiveSearchInput(timeout: 2.0) else {
            XCTFail("Expected archive search field to be available")
            return
        }

        searchField.tap()
        searchField.typeText("2025-01-14\n")

        let archiveRow = element(UIElementID.archiveRow(date: "2025-01-14"))
        revealElement(archiveRow)
        XCTAssertTrue(archiveRow.waitForExistence(timeout: 5.0))
        scrollElementToHittable(archiveRow)
        XCTAssertTrue(waitForElementToBecomeHittable(archiveRow, timeout: 5.0))
        archiveRow.tap()

        XCTAssertTrue(waitForAPODTitle(containing: "Fixture APOD 2025-01-14"))
    }

    func testFreeUserOpeningLockedArchiveEntryShowsPaywall() {
        configureLaunchEnvironment(fixtureMode: "monetization")
        app.launch()

        XCTAssertTrue(waitForElement(identifier: UIElementID.mainViewRoot, timeout: 5.0))
        XCTAssertTrue(waitForAPODTitle(containing: "Fixture APOD 2025-01-15"))

        tapElement(UIElementID.openArchiveButton)
        XCTAssertTrue(waitForElement(identifier: UIElementID.archiveSheetRoot, timeout: 5.0))

        guard let searchField = waitForArchiveSearchInput(timeout: 2.0) else {
            XCTFail("Expected archive search field to be available")
            return
        }

        searchField.tap()
        searchField.typeText("2025-01-04\n")

        let archiveRow = element(UIElementID.archiveRow(date: "2025-01-04"))
        revealElement(archiveRow)
        XCTAssertTrue(archiveRow.waitForExistence(timeout: 5.0))
        scrollElementToHittable(archiveRow)
        XCTAssertTrue(waitForElementToBecomeHittable(archiveRow, timeout: 5.0))
        archiveRow.tap()

        XCTAssertTrue(waitForPaywall())
        dismissPaywall()
        XCTAssertTrue(waitForElement(identifier: UIElementID.archiveSheetRoot, timeout: 5.0))
    }

    func testFreeUserPendingLockedArchiveRouteShowsPaywallOnLaunch() {
        configureLaunchEnvironment(
            fixtureMode: "monetization",
            pendingRouteDestination: "archive",
            pendingRouteDate: "2025-01-04"
        )
        app.launch()

        XCTAssertTrue(waitForPaywall())
        dismissPaywall()
        XCTAssertTrue(waitForElement(identifier: UIElementID.mainViewRoot, timeout: 5.0))
        XCTAssertTrue(waitForAPODTitle(containing: "Fixture APOD 2025-01-15"))
        XCTAssertFalse(element(UIElementID.archiveSheetRoot).exists)
    }

    func testFreeUserAddingEleventhFavoriteShowsPaywall() {
        configureLaunchEnvironment(
            fixtureMode: "monetization",
            preloadedFavoriteDates: monetizationFavoriteSeedDates()
        )
        app.launch()

        XCTAssertTrue(waitForElement(identifier: UIElementID.mainViewRoot, timeout: 5.0))
        XCTAssertTrue(waitForAPODTitle(containing: "Fixture APOD 2025-01-15"))

        guard let favoriteButton = waitForFavoriteButton() else {
            XCTFail("Expected a favorite button to become available")
            return
        }

        scrollElementToHittable(favoriteButton)
        XCTAssertTrue(waitForElementToBecomeHittable(favoriteButton, timeout: 5.0))
        favoriteButton.tap()

        XCTAssertTrue(waitForPaywall())
        dismissPaywall()

        guard let refreshedFavoriteButton = waitForFavoriteButton() else {
            XCTFail("Expected a favorite button after dismissing the paywall")
            return
        }

        XCTAssertTrue(refreshedFavoriteButton.label.contains("Add"))
    }

    func testFreeUserSaveToPhotosShowsPaywall() {
        configureLaunchEnvironment(fixtureMode: "monetization")
        app.launch()

        XCTAssertTrue(waitForElement(identifier: UIElementID.mainViewRoot, timeout: 5.0))
        XCTAssertTrue(waitForAPODTitle(containing: "Fixture APOD 2025-01-15"))

        tapElement(UIElementID.saveToPhotosButton, timeout: 8.0)

        XCTAssertTrue(waitForPaywall())
        dismissPaywall()
    }

    func testProUserCanAddEleventhFavoriteWithoutPaywall() {
        configureLaunchEnvironment(
            fixtureMode: "monetization",
            hasPro: true,
            preloadedFavoriteDates: monetizationFavoriteSeedDates(),
            forcePhotoExportSuccess: true
        )
        app.launch()

        XCTAssertTrue(waitForElement(identifier: UIElementID.mainViewRoot, timeout: 5.0))
        XCTAssertTrue(waitForAPODTitle(containing: "Fixture APOD 2025-01-15"))
        XCTAssertFalse(element(UIElementID.paywallContinueButton).exists || element(UIElementID.paywallUnlockButton).exists)

        guard let mainFavoriteButton = waitForFavoriteButton() else {
            XCTFail("Expected a favorite button on the main screen")
            return
        }

        scrollElementToHittable(mainFavoriteButton)
        XCTAssertTrue(waitForElementToBecomeHittable(mainFavoriteButton, timeout: 5.0))
        mainFavoriteButton.tap()

        guard let refreshedMainFavoriteButton = waitForFavoriteButton() else {
            XCTFail("Expected a refreshed favorite button after adding a Pro favorite")
            return
        }

        XCTAssertTrue(refreshedMainFavoriteButton.label.contains("Remove"))
        XCTAssertFalse(element(UIElementID.paywallContinueButton).exists || element(UIElementID.paywallUnlockButton).exists)
    }

    func testProUserCanOpenLockedArchiveAndSavePhotoWithoutPaywall() {
        configureLaunchEnvironment(
            fixtureMode: "monetization",
            hasPro: true,
            preloadedFavoriteDates: monetizationFavoriteSeedDates(),
            forcePhotoExportSuccess: true
        )
        app.launch()

        XCTAssertTrue(waitForElement(identifier: UIElementID.mainViewRoot, timeout: 5.0))
        XCTAssertTrue(waitForAPODTitle(containing: "Fixture APOD 2025-01-15"))
        XCTAssertFalse(element(UIElementID.paywallContinueButton).exists || element(UIElementID.paywallUnlockButton).exists)

        tapElement(UIElementID.openArchiveButton)
        XCTAssertTrue(waitForElement(identifier: UIElementID.archiveSheetRoot, timeout: 5.0))

        guard let searchField = waitForArchiveSearchInput(timeout: 2.0) else {
            XCTFail("Expected archive search field to be available")
            return
        }

        searchField.tap()
        searchField.typeText("2025-01-04\n")

        let archiveRow = element(UIElementID.archiveRow(date: "2025-01-04"))
        revealElement(archiveRow)
        XCTAssertTrue(archiveRow.waitForExistence(timeout: 5.0))
        scrollElementToHittable(archiveRow)
        XCTAssertTrue(waitForElementToBecomeHittable(archiveRow, timeout: 5.0))
        archiveRow.tap()

        XCTAssertTrue(waitForAPODTitle(containing: "Fixture APOD 2025-01-04"))
        XCTAssertFalse(element(UIElementID.paywallContinueButton).exists || element(UIElementID.paywallUnlockButton).exists)

        tapElement(UIElementID.saveToPhotosButton, timeout: 8.0)
        XCTAssertTrue(waitForAnyLabel(containing: "Saved to Photos", timeout: 5.0))
        XCTAssertFalse(element(UIElementID.paywallContinueButton).exists || element(UIElementID.paywallUnlockButton).exists)

        if app.buttons["OK"].waitForExistence(timeout: 1.0) {
            app.buttons["OK"].tap()
        }
    }

    func testArchiveFilterPersistsAcrossRelaunch() {
        configureLaunchEnvironment(fixtureMode: "date_navigation")
        app.launch()

        XCTAssertTrue(waitForElement(identifier: UIElementID.mainViewRoot, timeout: 5.0))
        tapElement(UIElementID.openArchiveButton)
        XCTAssertTrue(waitForElement(identifier: UIElementID.archiveSheetRoot, timeout: 5.0))

        guard let imagesFilter = waitForFilterOption("Images") else {
            XCTFail("Expected archive Images filter to be available")
            return
        }

        imagesFilter.tap()
        XCTAssertTrue(imagesFilter.isSelected)

        app.terminate()
        app = XCUIApplication()
        configureLaunchEnvironment(fixtureMode: "date_navigation", resetUserDefaults: false)
        app.launch()

        XCTAssertTrue(waitForElement(identifier: UIElementID.archiveSheetRoot, timeout: 5.0))

        guard let persistedImagesFilter = waitForFilterOption("Images") else {
            XCTFail("Expected archive Images filter to be available after relaunch")
            return
        }

        XCTAssertTrue(persistedImagesFilter.isSelected)
    }

    func testSavedFilterPersistsAcrossRelaunch() {
        configureLaunchEnvironment()
        app.launch()

        XCTAssertTrue(waitForElement(identifier: UIElementID.mainViewRoot, timeout: 5.0))
        XCTAssertTrue(waitForAPODTitle(containing: "Fixture APOD"))
        guard let favoriteButton = waitForFavoriteButton() else {
            XCTFail("Expected a favorite button to become available")
            return
        }

        scrollElementToHittable(favoriteButton)
        XCTAssertTrue(waitForElementToBecomeHittable(favoriteButton, timeout: 5.0))
        favoriteButton.tap()
        tapElement(UIElementID.openFavoritesButton)
        XCTAssertTrue(waitForElement(identifier: UIElementID.favoritesSheetRoot, timeout: 5.0))

        guard let sourceFilter = waitForFilterOption("Source") else {
            XCTFail("Expected saved Source filter to be available")
            return
        }

        sourceFilter.tap()
        XCTAssertTrue(sourceFilter.isSelected)

        app.terminate()
        app = XCUIApplication()
        configureLaunchEnvironment(resetUserDefaults: false)
        app.launch()

        XCTAssertTrue(waitForElement(identifier: UIElementID.favoritesSheetRoot, timeout: 5.0))
        let persistedFavoriteRow = element(UIElementID.favoriteRow(date: "2025-01-15"))
        XCTAssertTrue(persistedFavoriteRow.waitForExistence(timeout: 5.0))

        guard let persistedSourceFilter = waitForFilterOption("Source") else {
            XCTFail("Expected saved Source filter to be available after relaunch")
            return
        }

        XCTAssertTrue(persistedSourceFilter.isSelected)
    }

    func testIPadSplitShellArchiveSelectionFlow() throws {
        configureLaunchEnvironment(fixtureMode: "date_navigation")
        app.launch()

        try requireSplitShell()

        tapSidebarDestination("archive")
        XCTAssertTrue(waitForElement(identifier: UIElementID.archiveSheetRoot, timeout: 5.0))

        guard let searchField = waitForArchiveSearchInput(timeout: 2.0) else {
            XCTFail("Expected archive search field to be available in split shell.")
            return
        }

        searchField.tap()
        searchField.typeText("2025-01-14\n")

        let archiveRow = element(UIElementID.archiveRow(date: "2025-01-14"))
        XCTAssertTrue(archiveRow.waitForExistence(timeout: 5.0))
        XCTAssertTrue(waitForElementToBecomeHittable(archiveRow, timeout: 5.0))
        archiveRow.tap()

        XCTAssertTrue(waitForAPODTitle(containing: "Fixture APOD 2025-01-14"))
    }

    func testIPadSplitShellArchiveBackClearsSelection() throws {
        configureLaunchEnvironment(fixtureMode: "date_navigation")
        app.launch()

        try requireSplitShell()

        tapSidebarDestination("archive")
        XCTAssertTrue(waitForElement(identifier: UIElementID.archiveSheetRoot, timeout: 5.0))

        guard let searchField = waitForArchiveSearchInput(timeout: 2.0) else {
            XCTFail("Expected archive search field to be available in split shell.")
            return
        }

        searchField.tap()
        searchField.typeText("2025-01-14\n")

        let archiveRow = element(UIElementID.archiveRow(date: "2025-01-14"))
        XCTAssertTrue(archiveRow.waitForExistence(timeout: 5.0))
        XCTAssertTrue(waitForElementToBecomeHittable(archiveRow, timeout: 5.0))
        archiveRow.tap()

        let backButton = element(UIElementID.archiveDetailBackButton)
        XCTAssertTrue(backButton.waitForExistence(timeout: 5.0))
        XCTAssertTrue(waitForElementToBecomeHittable(backButton, timeout: 5.0))
        backButton.tap()

        XCTAssertTrue(waitForElement(identifier: UIElementID.archiveSheetRoot, timeout: 5.0))
        XCTAssertNotNil(waitForArchiveSearchInput(timeout: 2.0))
        XCTAssertTrue(waitForElementToDisappear(backButton, timeout: 5.0))
    }

    func testIPadSavedSelectionUpdatesDetail() throws {
        configureLaunchEnvironment()
        app.launch()

        try requireSplitShell()
        XCTAssertTrue(waitForElement(identifier: UIElementID.mainViewRoot, timeout: 5.0))

        guard let favoriteButton = waitForFavoriteButton() else {
            XCTFail("Expected a favorite button to become available in the split shell.")
            return
        }

        scrollElementToHittable(favoriteButton)
        XCTAssertTrue(waitForElementToBecomeHittable(favoriteButton, timeout: 5.0))
        favoriteButton.tap()

        tapSidebarDestination("saved")
        XCTAssertTrue(waitForElement(identifier: UIElementID.favoritesSheetRoot, timeout: 5.0))

        let favoriteRow = element(UIElementID.favoriteRow(date: "2025-01-15"))
        XCTAssertTrue(favoriteRow.waitForExistence(timeout: 5.0))
        XCTAssertTrue(waitForElementToBecomeHittable(favoriteRow, timeout: 5.0))
        favoriteRow.tap()

        XCTAssertTrue(waitForAPODTitle(containing: "Fixture APOD"))
    }

    func testIPadPendingArchiveRouteFocusesExactDate() throws {
        configureLaunchEnvironment(
            fixtureMode: "date_navigation",
            pendingRouteDestination: "archive",
            pendingRouteDate: "2025-01-13"
        )
        app.launch()

        try requireSplitShell()
        XCTAssertTrue(waitForElement(identifier: UIElementID.archiveSheetRoot, timeout: 5.0))
        XCTAssertTrue(waitForAPODTitle(containing: "Fixture APOD 2025-01-13"))
    }

    func testIPadSidebarDestinationPersistsAcrossRelaunch() throws {
        configureLaunchEnvironment(fixtureMode: "date_navigation")
        app.launch()

        try requireSplitShell()
        tapSidebarDestination("archive")
        XCTAssertTrue(waitForElement(identifier: UIElementID.archiveSheetRoot, timeout: 5.0))

        app.terminate()
        app = XCUIApplication()
        configureLaunchEnvironment(fixtureMode: "date_navigation", resetUserDefaults: false)
        app.launch()

        try requireSplitShell()
        XCTAssertTrue(waitForElement(identifier: UIElementID.archiveSheetRoot, timeout: 5.0))
    }

    func testIPadSplitShellSupportsAccessibilityOverrides() throws {
        configureLaunchEnvironment(
            fixtureMode: "date_navigation",
            locale: "bg_BG",
            dynamicTypeSize: "accessibility3",
            reduceMotion: true,
            reduceTransparency: true,
            differentiateWithoutColor: true
        )
        app.launch()

        try requireSplitShell()
        tapSidebarDestination("archive")
        XCTAssertTrue(waitForElement(identifier: UIElementID.archiveSheetRoot, timeout: 5.0))

        guard let searchField = waitForArchiveSearchInput(timeout: 2.0) else {
            XCTFail("Expected archive search field to remain available with accessibility overrides.")
            return
        }

        searchField.tap()
        searchField.typeText("2025-01-13\n")
        XCTAssertTrue(waitForValueContaining(searchField, substring: "2025-01-13", timeout: 5.0))
    }

    func testLongExplanationAtAccessibilitySizePreservesShareAction() {
        configureLaunchEnvironment(
            fixtureMode: "long_explanation",
            locale: "de_DE",
            dynamicTypeSize: "accessibility5",
            colorScheme: "dark",
            colorSchemeContrast: "increased",
            reduceMotion: true,
            reduceTransparency: true,
            differentiateWithoutColor: true
        )
        app.launch()

        XCTAssertTrue(waitForElement(identifier: UIElementID.mainViewRoot, timeout: 5.0))
        XCTAssertTrue(waitForAPODTitle(containing: "Fixture APOD"))

        let publishedDate = app.staticTexts[UIElementID.apodDateText]
        revealElement(publishedDate)
        XCTAssertTrue(publishedDate.waitForExistence(timeout: 5.0))
        XCTAssertTrue(waitForLabelContainingAny(publishedDate, substrings: ["Januar", "2025"], timeout: 5.0))

        let shareButton = app.buttons[UIElementID.shareAPODButton]
        XCTAssertTrue(shareButton.waitForExistence(timeout: 5.0))
        XCTAssertTrue(shareButton.isEnabled)
    }

    func testOfflineCachedBannerAppearsWithContent() {
        configureLaunchEnvironment(fixtureMode: "offline_cached")
        app.launch()

        XCTAssertTrue(waitForElement(identifier: UIElementID.mainViewRoot, timeout: 5.0))
        XCTAssertTrue(waitForElement(identifier: UIElementID.apiOfflineBanner, timeout: 5.0))
        XCTAssertTrue(waitForAPODTitle(containing: "Fixture APOD Available Offline"))
        XCTAssertTrue(app.buttons[UIElementID.shareAPODButton].waitForExistence(timeout: 5.0))
    }

    func testRateLimitedBannerAppearsWithRecoveryContext() {
        configureLaunchEnvironment(fixtureMode: "rate_limited")
        app.launch()

        XCTAssertTrue(waitForElement(identifier: UIElementID.mainViewRoot, timeout: 5.0))
        XCTAssertTrue(waitForElement(identifier: UIElementID.apiRateLimitBanner, timeout: 5.0))
        XCTAssertTrue(waitForAPODTitle(containing: "Fixture APOD During Rate Limit"))
    }

    func testInitialFailureStateShowsRetryAction() {
        configureLaunchEnvironment(fixtureMode: "load_failure")
        app.launch()

        XCTAssertTrue(waitForElement(identifier: UIElementID.mainViewRoot, timeout: 5.0))
        XCTAssertTrue(waitForElement(identifier: UIElementID.apiRequestFailureState, timeout: 5.0))
        XCTAssertTrue(app.buttons["Retry"].waitForExistence(timeout: 5.0))
    }

    func testNoMediaStateShowsFallbackCard() {
        configureLaunchEnvironment(fixtureMode: "no_media")
        app.launch()

        XCTAssertTrue(waitForElement(identifier: UIElementID.mainViewRoot, timeout: 5.0))
        XCTAssertTrue(waitForAPODTitle(containing: "Fixture APOD Without Media Source"))
        XCTAssertTrue(waitForAnyLabel(containing: "No image source available", timeout: 5.0))
    }

    func testDiagnosticsStatusUpdatesAcrossRefreshes() {
        configureLaunchEnvironment(fixtureMode: "diagnostics_cycle")
        app.launch()

        XCTAssertTrue(waitForElement(identifier: UIElementID.mainViewRoot, timeout: 5.0))

        let initialStatus = openSettingsAndReadDiagnosticsStatus()
        closeSettingsSheet()

        tapElement(UIElementID.refreshAPODButton)
        let firstRefreshedStatus = openSettingsAndReadDiagnosticsStatus(waitForNumericStatus: true)
        XCTAssertNotEqual(firstRefreshedStatus, initialStatus)
        closeSettingsSheet()

        tapElement(UIElementID.refreshAPODButton)
        let secondRefreshedStatus = openSettingsAndReadDiagnosticsStatus(waitForNumericStatus: true)
        XCTAssertNotEqual(secondRefreshedStatus, firstRefreshedStatus)
        XCTAssertTrue(firstRefreshedStatus.contains("429") || firstRefreshedStatus.contains("200"))
        XCTAssertTrue(secondRefreshedStatus.contains("429") || secondRefreshedStatus.contains("200"))
        XCTAssertNotEqual(firstRefreshedStatus.contains("429"), secondRefreshedStatus.contains("429"))
    }

    @available(iOS 17.0, *)
    func testMainScreenAccessibilityAuditPasses() throws {
        configureLaunchEnvironment()
        app.launch()

        XCTAssertTrue(waitForElement(identifier: UIElementID.mainViewRoot, timeout: 5.0))

        let auditTypes: XCUIAccessibilityAuditType = [.elementDetection, .hitRegion, .sufficientElementDescription, .trait]
        try app.performAccessibilityAudit(for: auditTypes) { issue in
            if [UIElementID.mainViewRoot].contains(issue.element?.identifier) {
                return true
            }
            self.attachDebugMarker(
                "AccessibilityIssue",
                details: "\(String(describing: issue.auditType)): \(issue.compactDescription)\n\(issue.detailedDescription)"
            )
            return false
        }
    }

    @available(iOS 17.0, *)
    func testSettingsScreenAccessibilityAuditPasses() throws {
        configureLaunchEnvironment()
        app.launch()

        XCTAssertTrue(waitForElement(identifier: UIElementID.mainViewRoot, timeout: 5.0))
        tapElement(UIElementID.openSettingsButton)
        XCTAssertTrue(waitForElement(identifier: UIElementID.settingsSheetRoot, timeout: 5.0))
        XCTAssertTrue(app.buttons[UIElementID.settingsCloseButton].waitForExistence(timeout: 5.0))

        let auditTypes: XCUIAccessibilityAuditType = [.elementDetection, .hitRegion, .sufficientElementDescription, .trait]
        try app.performAccessibilityAudit(for: auditTypes) { issue in
            if [UIElementID.settingsSheetRoot].contains(issue.element?.identifier) {
                return true
            }
            self.attachDebugMarker(
                "SettingsAccessibilityIssue",
                details: "\(String(describing: issue.auditType)): \(issue.compactDescription)\n\(issue.detailedDescription)"
            )
            return false
        }
    }

    @available(iOS 17.0, *)
    func testAdaptiveMainScreenAccessibilityAuditPasses() throws {
        configureLaunchEnvironment(
            fixtureMode: "long_explanation",
            locale: "de_DE",
            dynamicTypeSize: "accessibility4",
            colorScheme: "dark",
            colorSchemeContrast: "increased",
            reduceMotion: true,
            reduceTransparency: true,
            differentiateWithoutColor: true
        )
        app.launch()

        XCTAssertTrue(waitForElement(identifier: UIElementID.mainViewRoot, timeout: 5.0))

        let auditTypes: XCUIAccessibilityAuditType = [.elementDetection, .hitRegion, .sufficientElementDescription, .trait]
        try app.performAccessibilityAudit(for: auditTypes) { issue in
            if [UIElementID.mainViewRoot].contains(issue.element?.identifier) {
                return true
            }
            self.attachDebugMarker(
                "AdaptiveAccessibilityIssue",
                details: "\(String(describing: issue.auditType)): \(issue.compactDescription)\n\(issue.detailedDescription)"
            )
            return false
        }
    }
}
