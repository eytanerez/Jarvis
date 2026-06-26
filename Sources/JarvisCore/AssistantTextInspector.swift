import Foundation

public enum AssistantTextInspector {
    public static func containsQuestion(_ text: String) -> Bool {
        text.unicodeScalars.contains { $0.value == 63 }
    }

    public static func endsWithQuestion(_ text: String) -> Bool {
        for scalar in text.unicodeScalars.reversed() {
            if CharacterSet.whitespacesAndNewlines.contains(scalar) || isTrailingCloser(scalar) {
                continue
            }
            return scalar.value == 63
        }
        return false
    }

    private static func isTrailingCloser(_ scalar: UnicodeScalar) -> Bool {
        switch scalar.value {
        case 34, 39, 41, 93, 125, 0x2019, 0x201D:
            return true
        default:
            return false
        }
    }
}
