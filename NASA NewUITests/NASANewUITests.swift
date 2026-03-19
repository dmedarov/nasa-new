import XCTest

final class NASANewUITests: XCTestCase {
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
        fixtureMode: String = "default"
    ) {
        app.launchArguments += ["-ui-testing"]
        app.launchEnvironment["UITEST_USE_FIXTURE"] = "1"
        app.launchEnvironment["UITEST_FIXTURE_MODE"] = fixtureMode
        app.launchEnvironment["UITEST_LOCALE"] = "en_US_POSIX"
        app.launchEnvironment["UITEST_TIMEZONE"] = "UTC"
        app.launchEnvironment["UITEST_DISABLE_ANIMATIONS"] = "1"
        app.launchEnvironment["UITEST_RESET_USER_DEFAULTS"] = "1"

        if stayOnSplash {
            app.launchEnvironment["UITEST_STAY_ON_SPLASH"] = "1"
        }
        if holdSplash {
            app.launchEnvironment["UITEST_HOLD_SPLASH"] = "1"
        }
    }

    private func waitForElement(identifier: String, timeout: TimeInterval) -> Bool {
        app.descendants(matching: .any)[identifier].waitForExistence(timeout: timeout)
    }

    func testSplashScreenSnapshot() {
        configureLaunchEnvironment(stayOnSplash: true, holdSplash: true)
        app.launch()

        XCTAssertTrue(waitForElement(identifier: "splashScreenRoot", timeout: 5.0))
        XCTAssertFalse(app.buttons["Share APOD"].exists)

        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "SplashScreen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testMainScreenCriticalControlsAndSnapshot() {
        configureLaunchEnvironment()
        app.launch()

        XCTAssertTrue(waitForElement(identifier: "mainViewRoot", timeout: 5.0))
        XCTAssertTrue(app.buttons["Share APOD"].waitForExistence(timeout: 5.0))
        XCTAssertTrue(app.buttons["Refresh APOD data"].exists)
        XCTAssertTrue(app.buttons["Open settings"].exists)
        XCTAssertTrue(app.buttons["Select random APOD"].exists || app.buttons["Select random image"].exists)
        XCTAssertTrue(app.staticTexts["Fixture APOD"].exists)

        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "MainScreen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testUnsupportedVideoFallbackControlsAppear() {
        configureLaunchEnvironment(fixtureMode: "unsupported_video")
        app.launch()

        XCTAssertTrue(waitForElement(identifier: "mainViewRoot", timeout: 5.0))
        XCTAssertTrue(app.staticTexts["Fixture Unsupported Video"].waitForExistence(timeout: 5.0))
        XCTAssertTrue(app.buttons["Play Video"].waitForExistence(timeout: 5.0))
    }

    func testDirectVideoInlinePlayerAppears() {
        configureLaunchEnvironment(fixtureMode: "direct_video")
        app.launch()

        XCTAssertTrue(waitForElement(identifier: "mainViewRoot", timeout: 5.0))
        XCTAssertTrue(app.staticTexts["Fixture Direct Video"].waitForExistence(timeout: 5.0))
        XCTAssertFalse(app.buttons["Play Video"].exists)
    }

    func testFavoritesSearchAndSwipeDeleteFlow() {
        configureLaunchEnvironment()
        app.launch()

        XCTAssertTrue(app.buttons["Add to favorites"].waitForExistence(timeout: 5.0))
        app.buttons["Add to favorites"].tap()
        app.buttons["Open favorites"].tap()

        let searchField = app.searchFields["Search favorites"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5.0))
        searchField.tap()
        searchField.typeText("Fixture")

        let favoriteRowButton = app.buttons["Fixture APOD, 2025-01-15"]
        XCTAssertTrue(favoriteRowButton.waitForExistence(timeout: 5.0))
        favoriteRowButton.swipeLeft()
        XCTAssertTrue(app.buttons["Delete"].waitForExistence(timeout: 3.0))
        app.buttons["Delete"].tap()

        XCTAssertTrue(app.staticTexts["No Favorites Yet"].waitForExistence(timeout: 5.0))
    }

    func testDiagnosticsStatusUpdatesAcrossRefreshes() {
        configureLaunchEnvironment(fixtureMode: "diagnostics_cycle")
        app.launch()

        XCTAssertTrue(waitForElement(identifier: "mainViewRoot", timeout: 5.0))

        app.buttons["Open settings"].tap()
        XCTAssertTrue(app.staticTexts["Last Status Code"].waitForExistence(timeout: 5.0))
        app.buttons["Close settings"].tap()

        app.buttons["Refresh APOD data"].tap()
        sleep(1)
        app.buttons["Open settings"].tap()
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS '429'")).firstMatch.waitForExistence(timeout: 5.0))
        app.buttons["Close settings"].tap()

        app.buttons["Refresh APOD data"].tap()
        sleep(1)
        app.buttons["Open settings"].tap()
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS '200'")).firstMatch.waitForExistence(timeout: 5.0))
    }
}
