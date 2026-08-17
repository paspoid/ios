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
    static let brandColor = Color(red: 0.09, green: 0.36, blue: 0.90)

    func colors(for colorScheme: ColorScheme) -> PaspoButtonColors {
        switch self {
        case .brand:
            return PaspoButtonColors(background: Self.brandColor, foreground: .white)
        case .light:
            return PaspoButtonColors(background: .white, foreground: Color(white: 0.09), border: Color(white: 0.85))
        case .dark:
            return PaspoButtonColors(background: Color(white: 0.09), foreground: .white)
        case .neutral:
            let content: Color = colorScheme == .dark ? .white : Color(white: 0.09)
            return PaspoButtonColors(background: .clear, foreground: content, border: content.opacity(0.25))
        }
    }
}
