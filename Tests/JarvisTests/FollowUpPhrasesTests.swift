import XCTest
import JarvisCore

final class FollowUpPhrasesTests: XCTestCase {
    func testRecognizesDoneReplies() {
        XCTAssertTrue(FollowUpPhrases.isDone("No thanks"))
        XCTAssertTrue(FollowUpPhrases.isDone("nope"))
        XCTAssertTrue(FollowUpPhrases.isDone("that's all"))
        XCTAssertTrue(FollowUpPhrases.isDone("No, that's all thanks"))
        XCTAssertTrue(FollowUpPhrases.isDone("no that’s all thanks"))
        XCTAssertTrue(FollowUpPhrases.isDone("I'm done"))
        XCTAssertTrue(FollowUpPhrases.isDone("I'm done talking"))
        XCTAssertTrue(FollowUpPhrases.isDone("I don't want to talk anymore"))
        XCTAssertTrue(FollowUpPhrases.isDone("I do not want to continue"))
        XCTAssertTrue(FollowUpPhrases.isDone("Nothing for now"))
        XCTAssertTrue(FollowUpPhrases.isDone("Thank you so much"))
        XCTAssertTrue(FollowUpPhrases.isDone("All set"))
        XCTAssertTrue(FollowUpPhrases.isDone("we're done"))
    }

    func testStripsWakeWordAndPunctuation() {
        XCTAssertTrue(FollowUpPhrases.isDone("That's all, Jarvis."))
        XCTAssertTrue(FollowUpPhrases.isDone("Thanks!"))
    }

    func testNonDoneRepliesAreNotMatched() {
        XCTAssertFalse(FollowUpPhrases.isDone("open my email"))
        XCTAssertFalse(FollowUpPhrases.isDone("what about the second one"))
        XCTAssertFalse(FollowUpPhrases.isDone(""))
    }

    func testNormalizationCollapsesContractions() {
        XCTAssertEqual(FollowUpPhrases.normalized("I'm good"), "im good")
        XCTAssertEqual(FollowUpPhrases.normalized("That’s it!"), "thats it")
    }
}
