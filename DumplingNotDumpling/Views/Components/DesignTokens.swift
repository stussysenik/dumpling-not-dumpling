import SwiftUI

// MARK: - Carbon Color Tokens
//
// Colors sourced from the IBM Carbon Design System v11 white theme.
// Reference: https://carbondesignsystem.com/elements/color/tokens/
enum CarbonColor {
    /// Green-60: Used for success states (classification confirmed, positive feedback)
    static let supportSuccess = Color(hex: 0x198038)
    /// Red-60: Used for error states (misclassification, invalid input)
    static let supportError = Color(hex: 0xDA1E28)
    /// Blue-70: Used for informational states (processing, pending classification)
    static let supportInfo = Color(hex: 0x0043CE)
    /// Gray-100: Primary text — headers, labels, body copy
    static let textPrimary = Color(hex: 0x161616)
    /// Gray-70: Secondary text — captions, supporting information
    static let textSecondary = Color(hex: 0x525252)
    /// Gray-40: Placeholder text — empty field hints
    static let textPlaceholder = Color(hex: 0xA8A8A8)
    /// Gray-10: Layer 01 — card backgrounds, elevated surfaces
    static let layer01 = Color(hex: 0xF4F4F4)
    /// Gray-20: Subtle borders — dividers, input outlines
    static let borderSubtle = Color(hex: 0xE0E0E0)
    /// White: Page background
    static let background = Color.white
}

// MARK: - Carbon Spacing (8px grid)
//
// Carbon's spacing scale uses a base-8 grid. Every spacing value is a
// multiple of 4px, doubling in rhythm to maintain visual harmony.
// Reference: https://carbondesignsystem.com/elements/spacing/overview/
enum CarbonSpacing {
    /// 4px — tight internal padding, icon-to-label gap
    static let spacing02: CGFloat = 4
    /// 8px — standard component padding unit
    static let spacing03: CGFloat = 8
    /// 12px — compact padding for dense UI
    static let spacing04: CGFloat = 12
    /// 16px — default padding for most UI regions
    static let spacing05: CGFloat = 16
    /// 24px — section separation
    static let spacing06: CGFloat = 24
    /// 32px — major section gap
    static let spacing07: CGFloat = 32
    /// 40px — page-level breathing room
    static let spacing08: CGFloat = 40
    /// 48px — minimum tap target height (WCAG 2.5.5 compliant)
    static let spacing09: CGFloat = 48
}

// MARK: - Typography
//
// Two typefaces form the DumplingNotDumpling typographic system:
//   • Inter — a humanist sans-serif optimised for screens, used for all UI text
//   • IBM Plex Mono — IBM's monospace companion, used for data and classification scores
//
// Font names use PostScript identifiers (not filenames) as required by SwiftUI's
// .custom(_:size:) API. The PostScript names were verified via the name table (nameID 6)
// of each TTF file.
//
//   Inter-ExtraLight.ttf  → PostScript: "Inter-ExtraLight"
//   Inter-Regular.ttf     → PostScript: "Inter-Regular"
//   Inter-Medium.ttf      → PostScript: "Inter-Medium"
//   IBMPlexMono-Medium.ttf → PostScript: "IBMPlexMono-Medm"  ← note the abbreviated suffix
enum DumplingFont {
    /// Display / hero text — Inter ExtraLight (weight 200)
    /// Use for large decorative labels and splash screens.
    static func display(_ size: CGFloat) -> Font {
        .custom("Inter-ExtraLight", size: size)
    }

    /// Body text — Inter Regular (weight 400)
    /// Default reading weight for paragraphs, descriptions, and UI labels.
    static func body(_ size: CGFloat) -> Font {
        .custom("Inter-Regular", size: size)
    }

    /// Emphasis / interactive text — Inter Medium (weight 500)
    /// Buttons, active navigation items, section headings.
    static func medium(_ size: CGFloat) -> Font {
        .custom("Inter-Medium", size: size)
    }

    /// Data / code — IBM Plex Mono Medium (weight 500)
    /// Classification percentages, confidence scores, technical output.
    /// PostScript name is "IBMPlexMono-Medm" — IBM's internal abbreviation.
    static func mono(_ size: CGFloat) -> Font {
        .custom("IBMPlexMono-Medm", size: size)
    }
}

// MARK: - Color Extension
//
// Convenience initialiser that accepts a 24-bit hex literal (e.g. 0xFF5733)
// and converts it to normalised sRGB components. The alpha parameter allows
// transparent variants without a separate colour definition.
extension Color {
    /// Creates a Color from a 24-bit hex integer in 0xRRGGBB format.
    ///
    /// Example:
    /// ```swift
    /// let coral = Color(hex: 0xFF5733)
    /// let dimmed = Color(hex: 0xFF5733, alpha: 0.6)
    /// ```
    init(hex: UInt, alpha: Double = 1.0) {
        self.init(
            .sRGB,
            red:     Double((hex >> 16) & 0xFF) / 255,
            green:   Double((hex >>  8) & 0xFF) / 255,
            blue:    Double( hex        & 0xFF) / 255,
            opacity: alpha
        )
    }
}
