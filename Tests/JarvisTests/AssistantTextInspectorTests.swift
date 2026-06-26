import XCTest
import JarvisCore

final class AssistantTextInspectorTests: XCTestCase {
    func testDetectsQuestionsAnywhereInResponse() {
        XCTAssertTrue(AssistantTextInspector.containsQuestion("Want me to open that file?"))
        XCTAssertTrue(AssistantTextInspector.containsQuestion("I can do that. Should I start now?"))
        XCTAssertFalse(AssistantTextInspector.containsQuestion("I opened it."))
    }

    func testDetectsQuestionAtEndWithTrailingClosers() {
        XCTAssertTrue(AssistantTextInspector.endsWithQuestion("Want me to open it?"))
        XCTAssertTrue(AssistantTextInspector.endsWithQuestion("\"Want me to open it?\""))
        XCTAssertTrue(AssistantTextInspector.endsWithQuestion("Want me to open it?\u{201D}"))
        XCTAssertFalse(AssistantTextInspector.endsWithQuestion("I can open it if you want."))
    }
}
