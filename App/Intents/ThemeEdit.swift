import Foundation

/// Errors the theme Shortcuts actions show to the person running them.
enum ThemeIntentError: Error, CustomLocalizedStringResourceConvertible {
    case themeNotFound
    case lastTheme
    case invalidColor(String)
    case tooManyAccents(Int)

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .themeNotFound:
            return "That theme no longer exists."
        case .lastTheme:
            return "The last theme can't be deleted."
        case .invalidColor(let text):
            return "'\(text)' isn't a valid color. Use six hex digits, like #1A2B3C."
        case .tooManyAccents(let count):
            return "A theme holds at most \(ThemeEdit.maxAccents) button colors, not \(count)."
        }
    }
}

/// The optional fields of the "Update Theme" Shortcuts action. Only the fields
/// that are set change. Free of App Intents types so it can be unit-tested.
struct ThemeEdit: Equatable {
    /// Matches the 12 per-button colors the editor exposes.
    static let maxAccents = 12

    var name: String?
    /// First background color. Alone, the background becomes flat.
    var backgroundColor: String?
    /// Gradient end. Alone, it keeps the current first color.
    var backgroundColor2: String?
    /// One label color, applied to every button.
    var labelColor: String?
    /// Button colors. Empty or nil leaves them alone.
    var buttonColors: [String]?
    /// True clears the button colors, so tiles use the faint label tint, as the
    /// built-in Ink and Paper themes do. Button Colors, if also given, win.
    var monochrome: Bool?

    func applying(to theme: BoardTheme) throws -> BoardTheme {
        var result = theme

        // Parse everything first so a bad color changes nothing.
        let first = try backgroundColor.map(Self.parseColor)
        let second = try backgroundColor2.map(Self.parseColor)
        let label = try labelColor.map(Self.parseColor)
        var accents: [RGB]?
        if let buttonColors, !buttonColors.isEmpty {
            guard buttonColors.count <= Self.maxAccents else { throw ThemeIntentError.tooManyAccents(buttonColors.count) }
            accents = try buttonColors.map(Self.parseColor)
        }

        if let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty {
            result.name = trimmed
        }
        if first != nil || second != nil, let start = first ?? result.spec.background.first ?? second {
            result.spec.background = second.map { [start, $0] } ?? [start]
        }
        if let label {
            result.spec.labels = Array(repeating: label, count: Self.maxAccents)
        }
        if monochrome == true {
            result.spec.accents = []
        }
        if let accents {
            result.spec.accents = accents
        }
        return result
    }

    /// `#RRGGBB`, `RRGGBB`, `#RGB` or `RGB`, any case, surrounding whitespace ignored.
    static func parseColor(_ text: String) throws -> RGB {
        var digits = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if digits.hasPrefix("#") { digits.removeFirst() }
        guard digits.allSatisfy({ $0.isASCII && $0.isHexDigit }) else {
            throw ThemeIntentError.invalidColor(text)
        }
        if digits.count == 3 {
            digits = digits.map { "\($0)\($0)" }.joined()
        }
        guard digits.count == 6, let value = UInt32(digits, radix: 16) else {
            throw ThemeIntentError.invalidColor(text)
        }
        return RGB(value)
    }

    /// `#RRGGBB`, uppercase.
    static func hex(_ color: RGB) -> String {
        func byte(_ component: Double) -> Int { Int((min(max(component, 0), 1) * 255).rounded()) }
        return String(format: "#%02X%02X%02X", byte(color.red), byte(color.green), byte(color.blue))
    }
}

/// The values a theme exposes to Shortcuts as readable properties
/// ("Get Details of Theme"). Pure, so it can be unit-tested.
struct ThemeSummary: Equatable {
    var name: String
    var buttonColors: [String]
    var backgroundColors: [String]
    var labelColor: String

    init(_ theme: BoardTheme) {
        name = theme.name
        buttonColors = theme.spec.accents.map(ThemeEdit.hex)
        backgroundColors = theme.spec.background.map(ThemeEdit.hex)
        labelColor = theme.spec.labels.first.map(ThemeEdit.hex) ?? "#FFFFFF"
    }
}
