import SwiftUI

/// A literal sRGB triple. Themes are the product's identity, so their colors
/// are declared by hand rather than derived from system colors.
public struct RGB: Sendable, Codable, Equatable {
    public var red: Double
    public var green: Double
    public var blue: Double

    public init(_ hex: UInt32) {
        red = Double((hex >> 16) & 0xFF) / 255
        green = Double((hex >> 8) & 0xFF) / 255
        blue = Double(hex & 0xFF) / 255
    }

    public init(red: Double, green: Double, blue: Double) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    public var color: Color {
        get { Color(.sRGB, red: red, green: green, blue: blue) }
        set {
            if let components = UIColor(newValue).cgColor.components {
                if components.count >= 3 {
                    self.red = Double(components[0])
                    self.green = Double(components[1])
                    self.blue = Double(components[2])
                }
            }
        }
    }
}

public struct ThemeSpec: Sendable, Codable, Equatable {
    /// Tile surfaces. Empty means the theme is monochrome and tiles use the
    /// label color at low opacity instead.
    public var accents: [RGB]
    /// One color for a flat background, two for a gradient.
    public var background: [RGB]
    /// Label colors for each shortcut.
    public var labels: [RGB]
    
    public init(accents: [RGB], background: [RGB], labels: [RGB]) {
        self.accents = accents
        self.background = background
        self.labels = labels
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        accents = try container.decode([RGB].self, forKey: .accents)
        background = try container.decode([RGB].self, forKey: .background)
        
        if let singleLabel = try? container.decode(RGB.self, forKey: .labels) {
            labels = Array(repeating: singleLabel, count: 12)
        } else if let labelsArray = try? container.decode([RGB].self, forKey: .labels) {
            labels = labelsArray
        } else {
            labels = Array(repeating: RGB(0xFFFFFF), count: 12)
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case accents
        case background
        case labels = "label" // map old "label" key to "labels"
    }
}

public struct BoardTheme: Codable, Sendable, Identifiable, Equatable {
    public let id: UUID
    public var name: String
    public var spec: ThemeSpec
    
    public init(id: UUID = UUID(), name: String, spec: ThemeSpec) {
        self.id = id
        self.name = name
        self.spec = spec
    }
}

/// A curated set of ready-made looks, in place of a combinatorial style matrix.
/// Dark themes pair vivid tile chips with near-white labels; light themes pair
/// soft pastel chips with a dark label so on-tile text and the empty-state
/// message (which reuses the label color) both stay legible.
///
/// Order is load-bearing: `BoardThemeStore.createDefaultThemes()` derives each
/// built-in's stable id from its index here, so new cases must be appended.
public enum Theme: String, Codable, CaseIterable, Sendable {
    case ink
    case paper
    case midnight
    case aurora
    case sunset
    case nocturne
    case ember
    case meadow
    case sandstone
    case frost

    var displayName: String {
        switch self {
        case .ink: return "Ink"
        case .paper: return "Paper"
        case .midnight: return "Midnight"
        case .aurora: return "Aurora"
        case .sunset: return "Sunset"
        case .nocturne: return "Nocturne"
        case .ember: return "Ember"
        case .meadow: return "Meadow"
        case .sandstone: return "Sandstone"
        case .frost: return "Frost"
        }
    }

    var spec: ThemeSpec {
        switch self {
        case .ink:
            // Monochrome. Near-black with a faint cool lift for depth.
            return ThemeSpec(
                accents: [],
                background: [RGB(0x0A0A0C), RGB(0x17171B)],
                labels: Array(repeating: RGB(0xFAFAFA), count: 12)
            )
        case .paper:
            // Monochrome. Warm off-white, soft gradient.
            return ThemeSpec(
                accents: [],
                background: [RGB(0xFCF9F3), RGB(0xF0E9DB)],
                labels: Array(repeating: RGB(0x1B1712), count: 12)
            )
        case .midnight:
            // Jewel-cool: indigo, azure and violet on deep navy.
            return ThemeSpec(
                accents: [RGB(0x3B5BDB), RGB(0x1C7ED6), RGB(0x5F3DC4), RGB(0x6741D9), RGB(0x0B7285), RGB(0x4263EB)],
                background: [RGB(0x0A1128), RGB(0x1D2A5E)],
                labels: Array(repeating: RGB(0xF5F7FF), count: 12)
            )
        case .aurora:
            // Borealis greens and teals over a forest-to-deep-sea wash.
            return ThemeSpec(
                accents: [RGB(0x0B7A5B), RGB(0x087F5B), RGB(0x0C7A8C), RGB(0x2B7A3E), RGB(0x12866F), RGB(0x0B7285)],
                background: [RGB(0x042922), RGB(0x0A3F4A)],
                labels: Array(repeating: RGB(0xF0FFF9), count: 12)
            )
        case .sunset:
            // Coral through magenta to orchid, on a plum-to-wine dusk.
            return ThemeSpec(
                accents: [RGB(0xE03131), RGB(0xD6336C), RGB(0xC2255C), RGB(0xAE3EC9), RGB(0x9C36B5), RGB(0xD9480F)],
                background: [RGB(0x2A0B2E), RGB(0x4E1233)],
                labels: Array(repeating: RGB(0xFFF3EE), count: 12)
            )
        case .nocturne:
            // Single-hue violet ramp on dark indigo — quiet and modern.
            return ThemeSpec(
                accents: [RGB(0x7950F2), RGB(0x7048E8), RGB(0x6741D9), RGB(0x5F3DC4), RGB(0x533AAF), RGB(0x6E4BD4)],
                background: [RGB(0x130A24), RGB(0x291452)],
                labels: Array(repeating: RGB(0xEFE9FF), count: 12)
            )
        case .ember:
            // Fire ramp, red to burnt amber, on a warm near-black.
            return ThemeSpec(
                accents: [RGB(0xE8352E), RGB(0xDE3D1F), RGB(0xD24A15), RGB(0xC4550F), RGB(0xB85E0A), RGB(0xCE4826)],
                background: [RGB(0x1A0E08), RGB(0x331206)],
                labels: Array(repeating: RGB(0xFFF1E8), count: 12)
            )
        case .meadow:
            // Light. Soft green chips on a pale green wash, deep-green text.
            return ThemeSpec(
                accents: [RGB(0x94D8A0), RGB(0x69DB7C), RGB(0xA6DE6B), RGB(0x8CD94E), RGB(0xA7D98C), RGB(0x63C9A4)],
                background: [RGB(0xF2FAEC), RGB(0xDCEFCB)],
                labels: Array(repeating: RGB(0x1E3A24), count: 12)
            )
        case .sandstone:
            // Light. Warm clay and wheat pastels on sand, espresso text.
            return ThemeSpec(
                accents: [RGB(0xFFC078), RGB(0xFFD8A8), RGB(0xFAB77C), RGB(0xEFB884), RGB(0xFFCBA0), RGB(0xE8B98A)],
                background: [RGB(0xFBF4E9), RGB(0xEEDDC4)],
                labels: Array(repeating: RGB(0x4A3524), count: 12)
            )
        case .frost:
            // Light. Cool sky pastels on pale ice, deep navy-slate text.
            return ThemeSpec(
                accents: [RGB(0x99D8F5), RGB(0xA9DCF7), RGB(0x8CC8F0), RGB(0xB0C4F5), RGB(0xA9DDE8), RGB(0xAEC4F5)],
                background: [RGB(0xF0F4F9), RGB(0xD9E3EF)],
                labels: Array(repeating: RGB(0x1F3348), count: 12)
            )
        }
    }
}


