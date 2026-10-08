import Foundation

/// Errors the theme Shortcuts actions show to the person running them.
enum ThemeIntentError: Error, CustomLocalizedStringResourceConvertible {
    case themeNotFound
    case lastTheme
    case invalidColor(String)
    case wrongBackgroundCount(Int)
    case tooManyAccents(Int)

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .themeNotFound:
            return "That theme no longer exists."
        case .lastTheme:
            return "The last theme can't be deleted."
        case .invalidColor(let text):
            return "'\(text)' isn't a valid color. Use six hex digits, like #1A2B3C."
        case .wrongBackgroundCount(let count):
            return "A background needs one color (flat) or two (gradient), not \(count)."
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
    /// Button colors. An empty list makes the theme monochrome (tiles use the
    /// label color at low opacity), as the built-in Ink and Paper themes are.
    var accents: [String]?
    /// One color for a flat background, two for a gradient.
    var background: [String]?
    /// One label color, applied to every button.
    var label: String?

    func applying(to theme: BoardTheme) throws -> BoardTheme {
        var result = theme
        if let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty {
            result.name = trimmed
        }
        if let accents {
            guard accents.count <= Self.maxAccents else { throw ThemeIntentError.tooManyAccents(accents.count) }
            result.spec.accents = try accents.map(Self.parseColor)
        }
        if let background {
            guard (1...2).contains(background.count) else { throw ThemeIntentError.wrongBackgroundCount(background.count) }
            result.spec.background = try background.map(Self.parseColor)
        }
        if let label {
            result.spec.labels = Array(repeating: try Self.parseColor(label), count: Self.maxAccents)
        }
        return result
    }

    /// `#RRGGBB` or `RRGGBB`, any case, surrounding whitespace ignored.
    static func parseColor(_ text: String) throws -> RGB {
        var digits = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if digits.hasPrefix("#") { digits.removeFirst() }
        guard digits.count == 6,
              digits.allSatisfy({ $0.isASCII && $0.isHexDigit }),
              let value = UInt32(digits, radix: 16)
        else { throw ThemeIntentError.invalidColor(text) }
        return RGB(value)
    }
}
