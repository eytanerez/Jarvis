import XCTest
import JarvisCore

final class CommandMatcherTests: XCTestCase {
    private let matcher = CommandMatcher()

    func testNormalizationStripsWakeWordAndFiller() {
        XCTAssertEqual(matcher.normalize("Jarvis pause"), "pause")
        XCTAssertEqual(matcher.normalize("Hey Jarvis please open spotify"), "open spotify")
    }

    func testOpensKnownApp() {
        guard case .handled(let response, let action?) = matcher.match("please open Spotify") else {
            return XCTFail("Expected Spotify command to be handled")
        }
        XCTAssertEqual(response, "Opening Spotify.")
        XCTAssertEqual(action.type, "open_app")
        XCTAssertEqual(action.payload["name"]?.stringValue, "Spotify")
    }

    func testOpensKnownWebsite() {
        guard case .handled(_, let action?) = matcher.match("open amazon") else {
            return XCTFail("Expected website command to be handled")
        }
        XCTAssertEqual(action.type, "open_url")
        XCTAssertEqual(action.payload["url"]?.stringValue, "https://www.amazon.com")
    }

    func testShellCommandNeedsConfirmation() {
        guard case .needsConfirmation(let confirmation) = matcher.match("run command pwd") else {
            return XCTFail("Expected shell command to need confirmation")
        }
        XCTAssertEqual(confirmation.action.type, "run_shell_command")
        XCTAssertEqual(confirmation.action.payload["command"]?.stringValue, "pwd")
        // "pwd" is allowlisted, so it's a one-tap (yellow) confirmation.
        XCTAssertEqual(confirmation.risk, .yellow)
        XCTAssertFalse(confirmation.requiresTypedConfirmation)
    }

    func testDangerousShellCommandRequiresTypedConfirmation() {
        guard case .needsConfirmation(let confirmation) = matcher.match("run command rm -rf ~/Documents") else {
            return XCTFail("Expected shell command to need confirmation")
        }
        XCTAssertEqual(confirmation.risk, .red)
        XCTAssertTrue(confirmation.requiresTypedConfirmation)
    }

    func testUnmatchedFallsThrough() {
        XCTAssertEqual(matcher.match("what is the meaning of life"), .notMatched)
    }
}
