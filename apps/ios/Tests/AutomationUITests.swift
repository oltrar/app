import XCTest

private struct PresetLibrary: Decodable {
    let activePreset: String
    let presets: [GesturePreset]
}

private struct GesturePreset: Decodable {
    let id: String
    let name: String
    let bundleId: String
    let repeatCount: Int
    let steps: [GestureStep]
}

private struct GestureStep: Decodable {
    let action: String
    let waitMs: Int
    let xPercent: Double
    let yPercent: Double

    var isValid: Bool {
        ["tap", "swipe_up", "swipe_down", "swipe_left", "swipe_right"].contains(action)
        && waitMs >= 0 && waitMs <= 600000
        && xPercent.isFinite && yPercent.isFinite
        && (0...100).contains(xPercent) && (0...100).contains(yPercent)
    }
}

/// Developer-mode automation: runs from Xcode/XCUITest, NOT from the sandboxed iOS app.
final class AutomationUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func loadLibrary() throws -> PresetLibrary {
        let bundle = Bundle(for: AutomationUITests.self)
        let url = try XCTUnwrap(bundle.url(forResource: "presets", withExtension: "json"),
                                "Copy Tests/presets.json into the UI test bundle")
        return try JSONDecoder().decode(PresetLibrary.self, from: Data(contentsOf: url))
    }

    func testPresetFileIsValid() throws {
        let library = try loadLibrary()
        XCTAssertFalse(library.presets.isEmpty)
        XCTAssertNotNil(library.presets.first { $0.id == library.activePreset })
        for preset in library.presets {
            XCTAssertFalse(preset.id.isEmpty)
            XCTAssertFalse(preset.bundleId.isEmpty)
            XCTAssertFalse(preset.steps.isEmpty)
            XCTAssertGreaterThan(preset.repeatCount, 0)
            XCTAssertTrue(preset.steps.allSatisfy(\.isValid))
        }
    }

    func testRunActivePresetAcrossApps() throws {
        // Select 'activePreset' in Tests/presets.json, and run this test on the
        // connected iPhone using Xcode. Stop the test in Xcode at any time.
        executionTimeAllowance = 3600
        let library = try loadLibrary()
        let preset = try XCTUnwrap(
            library.presets.first { $0.id == library.activePreset },
            "Unknown activePreset value"
        )
        XCTAssertGreaterThan(preset.repeatCount, 0,
                             "XCUITest presets must have a finite repeatCount.")
        XCTAssertFalse(preset.steps.isEmpty)
        XCTAssertTrue(preset.steps.allSatisfy(\.isValid))

        let app = XCUIApplication(bundleIdentifier: preset.bundleId)
        app.activate()
        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 20),
                      "Target app not installed, not accessible, or not in foreground.")
        for _ in 0..<preset.repeatCount {
            for step in preset.steps {
                if step.waitMs > 0 {
                    Thread.sleep(forTimeInterval: Double(step.waitMs) / 1000.0)
                }
                XCTAssertEqual(app.state, .runningForeground,
                               "Target app left the foreground; stop automation.")
                perform(step, in: app)
            }
        }
    }

    private func perform(_ step: GestureStep, in app: XCUIApplication) {
        let x = step.xPercent / 100.0
        let y = step.yPercent / 100.0
        if step.action == "tap" {
            app.coordinate(withNormalizedOffset: CGVector(dx: x, dy: y)).tap()
            return
        }

        let start: CGVector
        let finish: CGVector
        switch step.action {
        case "swipe_up":
            start = CGVector(dx: 0.5, dy: 0.8)
            finish = CGVector(dx: 0.5, dy: 0.2)
        case "swipe_down":
            start = CGVector(dx: 0.5, dy: 0.2)
            finish = CGVector(dx: 0.5, dy: 0.8)
        case "swipe_left":
            start = CGVector(dx: 0.8, dy: 0.5)
            finish = CGVector(dx: 0.2, dy: 0.5)
        case "swipe_right":
            start = CGVector(dx: 0.2, dy: 0.5)
            finish = CGVector(dx: 0.8, dy: 0.5)
        default:
            XCTFail("Unknown action: \(step.action)")
            return
        }

        let from = app.coordinate(withNormalizedOffset: start)
        let to = app.coordinate(withNormalizedOffset: finish)
        from.press(forDuration: 0.1, thenDragTo: to)
    }
}
