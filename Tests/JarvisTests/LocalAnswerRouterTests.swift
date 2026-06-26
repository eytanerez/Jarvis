import XCTest
import JarvisCore

final class LocalAnswerRouterTests: XCTestCase {
    private let router = LocalAnswerRouter()

    func testAnswersPercentages() {
        XCTAssertEqual(router.answer("What's 18% of 240?"), .answer("43.2"))
    }

    func testAnswersArithmetic() {
        XCTAssertEqual(router.answer("what is 2 plus 2"), .answer("4"))
        XCTAssertEqual(router.answer("12 * 12"), .answer("144"))
    }

    func testAnswersTimeAndDateLocally() {
        if case .answer(let text) = router.answer("what time is it") {
            XCTAssertTrue(text.hasPrefix("It's"))
        } else {
            XCTFail("Expected a local time answer")
        }
    }

    func testAnswersSmallTalkLocally() {
        XCTAssertEqual(router.answer("how are you?"), .answer("I'm good. Ready when you are."))
        XCTAssertEqual(router.answer("thanks Jarvis"), .answer("Anytime."))
    }

    func testEscalatesWhenNoDeterministicMatch() {
        guard case .escalate = router.answer("research the history of jazz") else {
            return XCTFail("Research should escalate to the brain")
        }
        guard case .escalate = router.answer("define entropy") else {
            return XCTFail("Definitions should escalate")
        }
    }
}
