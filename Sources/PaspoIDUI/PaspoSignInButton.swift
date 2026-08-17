import PaspoID
import PaspoIDWire
import SwiftUI

/// Ready-made "Sign in with Paspo ID" button.
///
/// Runs the whole flow on tap and blocks repeated taps while a request is in progress.
/// It needs two inputs: a nonce provider and a result handler.
///
/// ```swift
/// PaspoSignInButton(
///     nonceProvider: backend.requestSsoNonce,
///     onResult: handlePaspoResult
/// )
/// ```
///
/// If `nonceProvider` throws, the result is `.failure(error: .serviceUnavailable, ...)`.
@MainActor
public struct PaspoSignInButton: View {
    private let paspo: Paspo
    private let scope: PaspoScope
    private let theme: PaspoButtonTheme
    private let cornerRadius: CGFloat?
    private let showsLogo: Bool
    private let isLogoOnly: Bool
    private let title: String?
    private let nonceProvider: () async throws -> String
    private let onResult: (PaspoAuthResult) -> Void

    @State private var isRunning = false
    @Environment(\.colorScheme) private var colorScheme

    /// - Parameters:
    ///   - paspo: SDK instance to run the flow with. Defaults to ``Paspo/shared``.
    ///   - scope: Profile data to request. Defaults to `.phones`.
    ///   - theme: Visual theme. Defaults to the Paspo brand colour.
    ///   - cornerRadius: Corner radius; `nil` renders a pill.
    ///   - showsLogo: Draw the Paspo mark. `false` renders a text-only button.
    ///   - isLogoOnly: Draw only the mark, without the label.
    ///   - title: Custom label. Defaults to the localized "Sign in with Paspo ID".
    ///   - nonceProvider: Async call fetching a fresh one-time nonce from your backend.
    ///   - onResult: Single result handler.
    public init(
        paspo: Paspo? = nil,
        scope: PaspoScope = .phones,
        theme: PaspoButtonTheme = .brand,
        cornerRadius: CGFloat? = nil,
        showsLogo: Bool = true,
        isLogoOnly: Bool = false,
        title: String? = nil,
        nonceProvider: @escaping () async throws -> String,
        onResult: @escaping (PaspoAuthResult) -> Void
    ) {
        self.paspo = paspo ?? Paspo.shared
        self.scope = scope
        self.theme = theme
        self.cornerRadius = cornerRadius
        self.showsLogo = showsLogo
        self.isLogoOnly = isLogoOnly
        self.title = title
        self.nonceProvider = nonceProvider
        self.onResult = onResult
    }

    public var body: some View {
        Button(action: run) {
            PaspoSignInButtonContent(
                colors: theme.colors(for: colorScheme),
                cornerRadius: cornerRadius,
                showsLogo: showsLogo,
                isLogoOnly: isLogoOnly,
                title: title ?? PaspoUIStrings.signIn,
                isLoading: isRunning
            )
        }
        .buttonStyle(.plain)
        .disabled(isRunning)
        .accessibilityLabel(title ?? PaspoUIStrings.signIn)
    }

    private func run() {
        guard isRunning == false else { return }
        isRunning = true
        Task {
            defer { isRunning = false }
            let nonce: String
            do {
                nonce = try await nonceProvider()
            } catch {
                onResult(.failure(error: .serviceUnavailable, message: "\(error)"))
                return
            }
            onResult(await paspo.authenticate(scope: scope, nonce: nonce))
        }
    }
}

/// Render-only button surface: reports taps without running the flow, for full visual control.
public struct PaspoSignInButtonContent: View {
    private let colors: PaspoButtonColors
    private let cornerRadius: CGFloat?
    private let showsLogo: Bool
    private let isLogoOnly: Bool
    private let title: String
    private let isLoading: Bool

    public init(
        colors: PaspoButtonColors,
        cornerRadius: CGFloat? = nil,
        showsLogo: Bool = true,
        isLogoOnly: Bool = false,
        title: String = PaspoUIStrings.signIn,
        isLoading: Bool = false
    ) {
        self.colors = colors
        self.cornerRadius = cornerRadius
        self.showsLogo = showsLogo
        self.isLogoOnly = isLogoOnly
        self.title = title
        self.isLoading = isLoading
    }

    public var body: some View {
        HStack(spacing: isLogoOnly ? 0 : 10) {
            if showsLogo || isLogoOnly {
                PaspoLogoShape()
                    .fill(colors.foreground)
                    .frame(width: 22, height: 22)
                    .opacity(isLoading ? 0 : 1)
                    .overlay {
                        if isLoading {
                            ProgressView().tint(colors.foreground)
                        }
                    }
            }
            if isLogoOnly == false {
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(colors.foreground)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .padding(.horizontal, isLogoOnly ? 14 : 20)
        .frame(minHeight: 50)
        .frame(maxWidth: isLogoOnly ? nil : .infinity)
        .background(
            shape.fill(colors.background)
        )
        .overlay(
            shape.strokeBorder(colors.border ?? .clear, lineWidth: colors.border == nil ? 0 : 1)
        )
        .contentShape(shape)
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: cornerRadius ?? 25, style: .continuous)
    }
}

/// Localized strings of the UI module.
public enum PaspoUIStrings {
    /// Button label. Localized where a translation exists, English otherwise.
    public static var signIn: String {
        let language = Locale.preferredLanguages.first?.prefix(2).lowercased() ?? "en"
        return translations[String(language)] ?? translations["en"]!
    }

    private static let translations: [String: String] = [
        "en": "Sign in with Paspo ID",
        "ru": "Войти через Paspo ID",
        "kk": "Paspo ID арқылы кіру",
        "uk": "Увійти через Paspo ID",
        "de": "Mit Paspo ID anmelden",
        "fr": "Se connecter avec Paspo ID",
        "es": "Iniciar sesión con Paspo ID",
        "pt": "Entrar com o Paspo ID",
        "it": "Accedi con Paspo ID",
        "pl": "Zaloguj się przez Paspo ID",
        "cs": "Přihlásit se přes Paspo ID",
        "ka": "Paspo ID-ით შესვლა",
        "ko": "Paspo ID로 로그인",
        "ar": "تسجيل الدخول عبر Paspo ID",
    ]
}
