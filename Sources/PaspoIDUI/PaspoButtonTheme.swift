import SwiftUI

/// Visual themes of ``PaspoSignInButton``, matching the Android SDK's `PaspoButtonTheme`.
public enum PaspoButtonTheme: String, Sendable, CaseIterable {
    /// Paspo brand colour, white content. The default.
    case brand
    /// White surface, dark content.
    case light
    /// Black surface, white content.
    case dark
    /// Transparent surface with a border; content follows the host colour scheme.
    case neutral
}

/// Explicit colour set, for full visual control over ``PaspoSignInButtonContent``.
public struct PaspoButtonColors: Sendable, Equatable {
    public var background: Color
    public var foreground: Color
    public var border: Color?

    public init(background: Color, foreground: Color, border: Color? = nil) {
        self.background = background
        self.foreground = foreground
        self.border = border
    }
}

extension PaspoButtonTheme {
    /// Brand blue of Paspo ID.
    static let brandColor = Color(hex: 0x1677FF)

    /// Deliberately independent of the host's colour scheme, exactly like the Android SDK: a
    /// partner app must get the same button everywhere, so the theme is the only thing that
    /// decides the palette.
    var colors: PaspoButtonColors {
        switch self {
        case .brand:
            return PaspoButtonColors(background: Self.brandColor, foreground: .white)
        case .light:
            return PaspoButtonColors(
                background: .white,
                foreground: Color(hex: 0x1F1F1F),
                border: Color(hex: 0xE0E0E0)
            )
        case .dark:
            return PaspoButtonColors(background: Color(hex: 0x131314), foreground: Color(hex: 0xE3E3E3))
        case .neutral:
            return PaspoButtonColors(background: Color(hex: 0xF2F2F2), foreground: Color(hex: 0x1F1F1F))
        }
    }
}

private extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}
