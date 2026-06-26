import XCTest
import JarvisCore

final class FollowUpResolverTests: XCTestCase {
    private func sessionWithResults() -> SessionStore {
        SessionStore(lastResults: [
            StructuredResult(id: "1", rank: 1, name: "Apple", url: URL(string: "https://apple.com")),
            StructuredResult(id: "2", rank: 2, name: "Best Buy", url: URL(string: "https://bestbuy.com")),
            StructuredResult(id: "3", rank: 3, name: "Costco", url: URL(string: "https://costco.com"))
        ])
    }

    func testResolvesNamedOpenAction() {
        let resolution = FollowUpResolver().resolve("Open the Costco one", session: sessionWithResults())
        guard case .action(let action, let selected?) = resolution else {
            return XCTFail("Expected a named open action")
        }
        XCTAssertEqual(selected.name, "Costco")
        XCTAssertEqual(action.payload["url"]?.stringValue, "https://costco.com")
    }

    func testResolvesCompare() {
        let resolution = FollowUpResolver().resolve("Compare the first two", session: sessionWithResults())
        guard case .compare(let results) = resolution else {
            return XCTFail("Expected a compare resolution")
        }
        XCTAssertEqual(results.map(\.name), ["Apple", "Best Buy"])
    }

    func testExpiredSessionReportsExpired() {
        let expired = SessionStore(
            lastResults: [StructuredResult(id: "1", rank: 1, name: "Apple")],
            expiresAt: Date().addingTimeInterval(-60)
        )
        XCTAssertEqual(FollowUpResolver().resolve("open the first", session: expired), .expired)
    }

    func testNoResultsIsNotAFollowUp() {
        XCTAssertEqual(FollowUpResolver().resolve("open the first", session: SessionStore()), .notFollowUp)
    }
}
