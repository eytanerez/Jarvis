import Foundation

/// Risk assessment for `run_shell_command` actions.
///
/// This replaces the old blocklist (which marked a handful of `rm -rf`-style
/// patterns red and waved *everything else* through as yellow). Shell blocklists
/// are famously porous — `rm` behind an env var, `$(...)` substitution, a piped
/// `curl ... | sh`, writing a LaunchAgent plist — so the default is inverted:
/// only a small allowlist of inherently read-only commands earns the lighter
/// (one-tap) confirmation. Anything else requires a typed confirmation.
///
/// Single source of truth — both `ActionRegistry` and `CommandMatcher` defer
/// here instead of carrying their own copies of the rule.
public struct ShellCommandPolicy: Sendable {
    public init() {}

    /// First tokens that are safe regardless of their arguments — *as long as*
    /// the command contains no shell metacharacters (see `unsafeMetacharacters`).
    /// Deliberately conservative and read-only; expand only with care.
    public static let allowedCommands: Set<String> = [
        "ls", "pwd", "echo", "printf", "cat", "head", "tail", "wc",
        "date", "cal", "whoami", "hostname", "uname", "uptime",
        "df", "du", "which", "type", "id", "groups", "arch",
        "env", "printenv", "ps", "sw_vers", "sysctl", "true", "false"
    ]

    /// Characters that let a command chain, substitute, redirect, or expand into
    /// something we can't statically reason about. Their presence forces `red`
    /// even if the leading token looks benign (`echo hi; rm -rf ~`).
    private static let unsafeMetacharacters: Set<Character> = [
        ";", "|", "&", "`", "$", ">", "<", "(", ")", "{", "}", "\n", "\\"
    ]

    public func risk(for command: String) -> ActionRisk {
        let trimmed = command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .red }

        if trimmed.contains(where: { Self.unsafeMetacharacters.contains($0) }) {
            return .red
        }

        guard let firstToken = trimmed.split(whereSeparator: { $0 == " " || $0 == "\t" }).first else {
            return .red
        }
        let binary = (firstToken.split(separator: "/").last.map(String.init) ?? String(firstToken)).lowercased()
        return Self.allowedCommands.contains(binary) ? .yellow : .red
    }

    public func requiresTypedConfirmation(for command: String) -> Bool {
        risk(for: command) == .red
    }
}
