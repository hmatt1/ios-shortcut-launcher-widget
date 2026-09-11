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
            // Jewel-cool: indigo, azure and violet on deep navy. Accents deepened
            // one luminance notch from the original cut (was as low as 3.92:1
            // against the label) so every chip clears 4.5:1; the lighter background
            // stop is deepened too, lifting the worst chip-vs-background contrast
            // from 1.91:1 to 2.20:1 for anyone who hand-builds a tight, solid board.
            return ThemeSpec(
                accents: [RGB(0x3B5BDB), RGB(0x2560C0), RGB(0x5F3DC4), RGB(0x6741D9), RGB(0x0B6C7E), RGB(0x3A57D2)],
                background: [RGB(0x0A1128), RGB(0x172049)],
                labels: Array(repeating: RGB(0xF5F7FF), count: 12)
            )
        case .aurora:
            // Borealis greens and teals over a forest-to-deep-sea wash. Two chips
            // deepened slightly (one was 4.37:1 against the label) to clear 4.5:1.
            return ThemeSpec(
                accents: [RGB(0x0B7A5B), RGB(0x0A7D5C), RGB(0x0C7A8C), RGB(0x24793A), RGB(0x0F7C68), RGB(0x0B7285)],
                background: [RGB(0x042922), RGB(0x0A3F4A)],
                labels: Array(repeating: RGB(0xF0FFF9), count: 12)
            )
        case .sunset:
            // Coral through magenta to orchid, on a plum-to-wine dusk. Ramp
            // deepened ~4% so every chip clears 4.5:1 against the label.
            return ThemeSpec(
                accents: [RGB(0xCE2C2C), RGB(0xC82E60), RGB(0xC2255C), RGB(0xA332BC), RGB(0x9C36B5), RGB(0xC13C0C)],
                background: [RGB(0x2A0B2E), RGB(0x4E1233)],
                labels: Array(repeating: RGB(0xFFF3EE), count: 12)
            )
        case .nocturne:
            // Single-hue violet ramp on dark indigo — quiet and modern. Ramp
            // collapsed toward its calm centre so every chip clears 4.5:1; the
            // lighter background stop is deepened too, lifting the worst chip-vs-
            // background contrast from 1.97:1 to 2.09:1.
            return ThemeSpec(
                accents: [RGB(0x6A44DE), RGB(0x6741D9), RGB(0x6440D3), RGB(0x5F3DC4), RGB(0x533AAF), RGB(0x6244CC)],
                background: [RGB(0x130A24), RGB(0x241047)],
                labels: Array(repeating: RGB(0xEFE9FF), count: 12)
            )
        case .ember:
            // Fire ramp, red to burnt amber, on a warm near-black. The whole ramp
            // used to fail hard against the label (down to ~2.5:1); pulled into a
            // deeper luminance band it clears 4.5:1 and, as a side effect, is now
            // the best-separating chromatic theme against its own background
            // (2.80:1 worst case) — the only chromatic theme licensed for a tight
            // density on a solid background.
            return ThemeSpec(
                accents: [RGB(0xC82B23), RGB(0xC33318), RGB(0xBC400F), RGB(0xAF4B0B), RGB(0x965009), RGB(0xBB3E1D)],
                background: [RGB(0x1A0E08), RGB(0x331206)],
                labels: Array(repeating: RGB(0xFFF1E8), count: 12)
            )
        case .meadow:
            // Light. Soft green chips on a pale green wash, deep-green text. The
            // original pastel chips (~1.1:1 against the wash) were invisible at
            // any density; recut as mid-tone greens they clear 4.5:1 against the
            // (also deepened) label and 2.19:1 against the background.
            return ThemeSpec(
                accents: [RGB(0x4FB172), RGB(0x45B268), RGB(0x57AE55), RGB(0x62AC49), RGB(0x4FAE86), RGB(0x4AAB63)],
                background: [RGB(0xF2FAEC), RGB(0xDCEFCB)],
                labels: Array(repeating: RGB(0x14301E), count: 12)
            )
        case .sandstone:
            // Light. Warm clay and wheat pastels on sand, espresso text. Recut
            // from near-invisible pastels (~1.1:1 against the sand) to mid clay
            // and ochre tones that clear 4.5:1 against the (also deepened) label
            // and 1.90:1 against the background — the palette's tightest margin,
            // which is why this theme is only shown on a solid background at
            // Relaxed density or roomier.
            return ThemeSpec(
                accents: [RGB(0xC58F49), RGB(0xCB9A55), RGB(0xC08640), RGB(0xBE8446), RGB(0xC79355), RGB(0xC28D4C)],
                background: [RGB(0xFBF4E9), RGB(0xEEDDC4)],
                labels: Array(repeating: RGB(0x2E2114), count: 12)
            )
        case .frost:
            // Light. Cool sky pastels on pale ice, deep navy-slate text. Recut
            // from near-invisible pastels (~1.1-1.3:1 against the ice) to mid
            // sky/periwinkle tones that clear 4.5:1 against the (also deepened)
            // label and 2.12:1 against the background.
            return ThemeSpec(
                accents: [RGB(0x5AA0CE), RGB(0x62A3CD), RGB(0x5E9BCE), RGB(0x7C97D2), RGB(0x5CA4B8), RGB(0x7699D2)],
                background: [RGB(0xF0F4F9), RGB(0xD9E3EF)],
                labels: Array(repeating: RGB(0x182A3B), count: 12)
            )
        }
    }
}


