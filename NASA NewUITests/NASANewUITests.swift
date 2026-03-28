import XCTest

final class NASANewUITests: XCTestCase {
    private enum UIElementID {
        static let mainViewRoot = "mainViewRoot"
        static let splashScreenRoot = "splashScreenRoot"
        static let shareAPODButton = "shareAPODButton"
        static let refreshAPODButton = "refreshAPODButton"
        static let randomAPODButton = "randomAPODButton"
        static let openSettingsButton = "openSettingsButton"
        static let openFavoritesButton = "openFavoritesButton"
        static let settingsSheetRoot = "settingsSheetRoot"
        static let settingsCloseButton = "settingsCloseButton"
        static let favoritesSheetRoot = "favoritesSheetRoot"
        static let favoritesEmptyState = "favoritesEmptyState"
        static let favoriteAPODButton = "favoriteAPODButton"
        static let jumpToLatestAPODDateButton = "jumpToLatestAPODDateButton"
        static let previousAPODDateButton = "previousAPODDateButton"
        static let nextAPODDateButton = "nextAPODDateButton"
        static let apodTitleText = "apodTitleText"
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
        static let videoAutoplayPausedBadge = "videoAutoplayPausedBadge"

        static func favoriteRow(date: String) -> String {
            "favoriteAPODRow-\(date)"
        }

        static func favoriteDeleteAction(date: String) -> String {
            "favoriteAPODDelete-\(date)"
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
        networkKind: String? = nil,
        isExpensiveNetwork: Bool = false,
        isConstrainedNetwork: Bool = false,
        dataSaverMode: Bool? = nil,
        preferHDImages: Bool? = nil,
        wifiOnlyAutoplay: Bool? = nil,
        resetUserDefaults: Bool = true
    ) {
        app.launchArguments += ["-ui-testing"]
        app.launchEnvironment["UITEST_USE_FIXTURE"] = "1"
        app.launchEnvironment["UITEST_FIXTURE_MODE"] = fixtureMode
        app.launchEnvironment["UITEST_LOCALE"] = "en_US_POSIX"
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

    private func revealElement(_ target: XCUIElement, maxSwipes: Int = 5) {
        var swipeCount = 0
        while !target.exists && swipeCount < maxSwipes {
            app.swipeUp()
            swipeCount += 1
        }
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

    private func tapElement(_ identifier: String, timeout: TimeInterval = 5.0) {
        let target = element(identifier)
        XCTAssertTrue(target.waitForExistence(timeout: timeout))
        XCTAssertTrue(waitForElementToBecomeHittable(target, timeout: timeout))
        target.tap()
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

    private func attachDebugMarker(_ name: String, details: String) {
        let attachment = XCTAttachment(string: details)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
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
        XCTAssertTrue(waitForElementToBecomeHittable(previousDateButton, timeout: 5.0))
        attachDebugMarker("DateNavBeforeFirstTap", details: previousDateButton.debugDescription)
        previousDateButton.tap()
        XCTAssertTrue(waitForAPODTitle(containing: "Fixture APOD 2025-01-14"))
        attachDebugMarker("DateNavAfterFirstTap", details: "Reached 2025-01-14")
        let refreshedPreviousDateButton = app.buttons[UIElementID.previousAPODDateButton]
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
        previousDateButton.tap()

        XCTAssertTrue(waitForAPODTitle(containing: "Fixture APOD 2025-01-14"))
        app.buttons[UIElementID.previousAPODDateButton].tap()
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

        previousDateButton.tap()
        XCTAssertTrue(waitForAPODTitle(containing: "Fixture APOD 2025-01-14"))
        nextDateButton.tap()
        XCTAssertTrue(waitForAPODTitle(containing: "Fixture APOD 2025-01-15"))
    }

    func testTodayNavigationReturnsToLatestFixture() {
        launchAndWaitForMainView(fixtureMode: "date_navigation")
        XCTAssertTrue(waitForAPODTitle(containing: "Fixture APOD 2025-01-15"))
        XCTAssertTrue(app.buttons[UIElementID.jumpToLatestAPODDateButton].waitForExistence(timeout: 5.0))
        navigateBackToEarlierAPODDay()
        let refreshedTodayButton = app.buttons[UIElementID.jumpToLatestAPODDateButton]
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
        let autoplayPolicyValue = app.staticTexts[UIElementID.autoplayPolicyValue]
        revealElement(autoplayPolicyValue)
        XCTAssertTrue(autoplayPolicyValue.waitForExistence(timeout: 5.0))
        XCTAssertTrue(waitForLabelContaining(autoplayPolicyValue, substring: "Manual play required off Wi-Fi", timeout: 5.0))
        XCTAssertTrue(app.staticTexts[UIElementID.networkConnectionValue].label.contains("Cellular"))
        XCTAssertTrue(app.staticTexts[UIElementID.meteredNetworkValue].label.contains("Yes"))
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
        let autoplayPolicyValue = app.staticTexts[UIElementID.autoplayPolicyValue]
        revealElement(autoplayPolicyValue)
        XCTAssertTrue(autoplayPolicyValue.waitForExistence(timeout: 5.0))
        XCTAssertTrue(waitForLabelContaining(autoplayPolicyValue, substring: "Autoplay allowed on Wi-Fi", timeout: 5.0))
        XCTAssertTrue(app.staticTexts[UIElementID.networkConnectionValue].label.contains("Wi-Fi"))
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
        app.buttons[UIElementID.openSettingsButton].tap()
        XCTAssertTrue(waitForElement(identifier: UIElementID.settingsSheetRoot, timeout: 5.0))
        let networkEfficiencyValue = app.staticTexts[UIElementID.networkEfficiencyValue]
        revealElement(networkEfficiencyValue)
        XCTAssertTrue(networkEfficiencyValue.waitForExistence(timeout: 5.0))
        XCTAssertTrue(waitForLabelContaining(networkEfficiencyValue, substring: "Maximum savings. App data saver and Low Data Mode are both active.", timeout: 5.0))
        XCTAssertTrue(app.staticTexts[UIElementID.lowDataModeValue].label.contains("Yes"))
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

    func testFavoritesSearchAndSwipeDeleteFlow() {
        launchAndWaitForMainView()
        XCTAssertTrue(waitForAPODTitle(containing: "Fixture APOD"))
        guard let favoriteButton = waitForFavoriteButton() else {
            XCTFail("Expected a favorite button to become available")
            return
        }
        favoriteButton.tap()
        tapElement(UIElementID.openFavoritesButton)
        XCTAssertTrue(waitForElement(identifier: UIElementID.favoritesSheetRoot, timeout: 5.0))

        let searchField = app.searchFields["Search favorites"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5.0))
        searchField.tap()
        searchField.typeText("Fixture")

        let favoriteRow = element(UIElementID.favoriteRow(date: "2025-01-15"))
        XCTAssertTrue(favoriteRow.waitForExistence(timeout: 5.0))
        favoriteRow.swipeLeft()
        let deleteButton = element(UIElementID.favoriteDeleteAction(date: "2025-01-15"))
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 3.0))
        deleteButton.tap()

        XCTAssertTrue(waitForElement(identifier: UIElementID.favoritesEmptyState, timeout: 5.0))
    }

    func testDiagnosticsStatusUpdatesAcrossRefreshes() {
        configureLaunchEnvironment(fixtureMode: "diagnostics_cycle")
        app.launch()

        XCTAssertTrue(waitForElement(identifier: UIElementID.mainViewRoot, timeout: 5.0))

        let initialStatus = openSettingsAndReadDiagnosticsStatus()
        app.buttons[UIElementID.settingsCloseButton].tap()

        app.buttons[UIElementID.refreshAPODButton].tap()
        let firstRefreshedStatus = openSettingsAndReadDiagnosticsStatus(waitForNumericStatus: true)
        XCTAssertNotEqual(firstRefreshedStatus, initialStatus)
        app.buttons[UIElementID.settingsCloseButton].tap()

        app.buttons[UIElementID.refreshAPODButton].tap()
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
        app.buttons[UIElementID.openSettingsButton].tap()
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
}
