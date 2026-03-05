import XCTest

final class NASANewUITests: XCTestCase {
    private func makeApp(stayOnSplash: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-ui-testing"]
        app.launchEnvironment["UITEST_USE_FIXTURE"] = "1"
        app.launchEnvironment["UITEST_LOCALE"] = "en_US_POSIX"
        app.launchEnvironment["UITEST_TIMEZONE"] = "UTC"
        app.launchEnvironment["UITEST_DISABLE_ANIMATIONS"] = "1"

        if stayOnSplash {
            app.launchEnvironment["UITEST_STAY_ON_SPLASH"] = "1"
        }

        return app
    }

    func testSplashScreenSnapshot() {
        let app = makeApp(stayOnSplash: true)
        app.launch()

        XCTAssertFalse(app.buttons["Share APOD"].waitForExistence(timeout: 1.5))

        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "SplashScreen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testMainScreenCriticalControlsAndSnapshot() {
        let app = makeApp()
        app.launch()

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
}
