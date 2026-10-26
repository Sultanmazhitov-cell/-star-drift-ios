import XCTest

final class FlightUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testFlightPauseAndSettings() throws {
        let app = XCUIApplication()
        app.launch()

        let start = app.buttons["start-flight"]
        let pause = app.buttons["pause-flight"]
        XCTAssertTrue(start.waitForExistence(timeout: 10), "The first flight can be started.")
        XCTAssertFalse(pause.isEnabled, "Pause is unavailable before a flight.")
        saveScreenshot("01-ready", from: app)

        start.tap()
        XCTAssertTrue(waitUntil { !start.exists && pause.isEnabled }, "Starting hides the launch overlay.")
        saveScreenshot("02-playing", from: app)

        pause.tap()
        XCTAssertTrue(start.waitForExistence(timeout: 5), "Pause exposes the resume action.")
        XCTAssertEqual(pause.label, "Продолжить полёт")
        saveScreenshot("03-paused", from: app)

        start.tap()
        XCTAssertTrue(waitUntil { !start.exists && pause.label == "Пауза" }, "The same flight resumes.")

        app.buttons["open-settings"].tap()
        let sound = app.switches["toggle-sound"]
        XCTAssertTrue(sound.waitForExistence(timeout: 5))
        let previousValue = try XCTUnwrap(sound.value as? String)
        saveScreenshot("04-settings-before", from: app)
        // SwiftUI exposes the whole Form row as a switch; its center is the
        // label area. Tap the actual trailing control rather than the row.
        sound.coordinate(withNormalizedOffset: CGVector(dx: 0.94, dy: 0.5)).tap()
        XCTAssertTrue(waitUntil { (sound.value as? String) != previousValue }, "The sound preference changes.")
        saveScreenshot("05-settings-sound-changed", from: app)
        sound.coordinate(withNormalizedOffset: CGVector(dx: 0.94, dy: 0.5)).tap()
        XCTAssertTrue(waitUntil { (sound.value as? String) == previousValue }, "The test restores the sound preference.")

        app.buttons["close-settings"].tap()
        XCTAssertTrue(start.waitForExistence(timeout: 5), "Closing settings keeps the flight paused.")
        XCTAssertEqual(pause.label, "Продолжить полёт")
    }

    @MainActor
    private func waitUntil(timeout: TimeInterval = 5, _ condition: @escaping () -> Bool) -> Bool {
        let predicate = NSPredicate { _, _ in condition() }
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: nil)
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }

    @MainActor
    private func saveScreenshot(_ name: String, from app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
