import XCTest
import JarvisCore

final class IntentRouterTests: XCTestCase {
    private let router = IntentRouter()

    func testClassifiesMemoryRequests() {
        XCTAssertEqual(router.classify("remember that I take my coffee black"), .memory)
        XCTAssertEqual(router.classify("what do you remember about my trip"), .memory)
    }

    func testClassifiesActionRequests() {
        XCTAssertEqual(router.classify("open Spotify"), .action)
        XCTAssertEqual(router.classify("send an email to Bob"), .action)
        XCTAssertEqual(router.classify("draft a message to Moshe"), .action)
    }

    func testClassifiesWebRequests() {
        XCTAssertEqual(router.classify("find the best mechanical keyboard"), .web)
        XCTAssertEqual(router.classify("what's the latest news on the election"), .web)
    }

    func testClassifiesCompareAndScreenContext() {
        XCTAssertEqual(router.classify("compare the first two"), .compare)
        XCTAssertEqual(router.classify("summarize this page for me"), .screenContext)
        XCTAssertEqual(router.classify("summarize this website for me"), .screenContext)
        XCTAssertEqual(router.classify("summarize this article"), .screenContext)
        XCTAssertEqual(router.classify("what does this mean"), .screenContext)
        XCTAssertEqual(router.classify("explain this highlighted text"), .screenContext)
    }

    func testClassifiesGeneralFallback() {
        XCTAssertEqual(router.classify("what is the capital of France"), .general)
        XCTAssertEqual(router.classify("explain how a transformer works"), .general)
    }

    func testActionWinsOverScreenContextOrdering() {
        // "open this page in a new tab" is an action even though it mentions a page.
        XCTAssertEqual(router.classify("open this tab in chrome"), .action)
    }

    func testRequiresScreenContext() {
        XCTAssertTrue(router.requiresScreenContext("Summarize the page"))
        XCTAssertTrue(router.requiresScreenContext("Summarize this website"))
        XCTAssertTrue(router.requiresScreenContext("what's on my screen right now"))
        XCTAssertTrue(router.requiresScreenContext("what does this mean?"))
        XCTAssertFalse(router.requiresScreenContext("what is the weather"))
    }

    func testReferencesSelectedOrHighlightedText() {
        XCTAssertTrue(router.referencesSelectedOrHighlightedText("what does this highlighted text mean"))
        XCTAssertTrue(router.referencesSelectedOrHighlightedText("explain this selection"))
        XCTAssertFalse(router.referencesSelectedOrHighlightedText("what is the capital of France"))
    }

    func testModeSelection() {
        XCTAssertEqual(router.mode(for: "compare these two laptops", hasBrowserContext: false), .smart)
        XCTAssertEqual(router.mode(for: "think through this decision", hasBrowserContext: false), .smart)
        XCTAssertEqual(router.mode(for: "use clout agent to think through this", hasBrowserContext: false), .smart)
        XCTAssertEqual(router.mode(for: "summarize the page", hasBrowserContext: false), .fast)
        XCTAssertEqual(router.mode(for: "summarize this article", hasBrowserContext: false), .fast)
        XCTAssertEqual(router.mode(for: "what time is it", hasBrowserContext: false), .fast)
        // A "why/how/explain" question only escalates when there's browser context.
        XCTAssertEqual(router.mode(for: "why is this happening", hasBrowserContext: true), .smart)
        XCTAssertEqual(router.mode(for: "why is this happening", hasBrowserContext: false), .fast)
    }

    func testNormalizationHandlesSmartQuotes() {
        XCTAssertTrue(router.isMemoryRequest("don’t forget the milk"))
    }

    func testPrefersCloudAgentAliases() {
        XCTAssertTrue(router.prefersCloudAgent("use cloud agent to answer this"))
        XCTAssertTrue(router.prefersCloudAgent("use a clout agent for this"))
        XCTAssertFalse(router.prefersCloudAgent("what is cloud computing"))
    }
}
