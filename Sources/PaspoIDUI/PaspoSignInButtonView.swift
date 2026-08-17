#if canImport(UIKit)
import PaspoID
import PaspoIDWire
import SwiftUI
import UIKit

/// UIKit flavour of ``PaspoSignInButton`` for applications that are not on SwiftUI.
///
/// ```swift
/// let button = PaspoSignInButtonView()
/// button.setAuthHandler(scope: .phones, nonceProvider: backend.requestSsoNonce) { result in ... }
/// ```
@MainActor
public final class PaspoSignInButtonView: UIControl {
    /// Visual theme. Defaults to the Paspo brand colour.
    public var theme: PaspoButtonTheme = .brand { didSet { reload() } }
    /// Corner radius; `nil` renders a pill.
    public var cornerRadius: CGFloat? { didSet { reload() } }
    /// Draw the Paspo mark.
    public var showsLogo: Bool = true { didSet { reload() } }
    /// Draw only the mark, without the label.
    public var isLogoOnly: Bool = false { didSet { reload() } }
    /// Custom label; `nil` uses the localized default.
    public var title: String? { didSet { reload() } }

    private var paspo: Paspo?
    private var scope: PaspoScope = .phones
    private var nonceProvider: (() async throws -> String)?
    private var onResult: ((PaspoAuthResult) -> Void)?
    private var isRunning = false { didSet { reload() } }

    private var hostingController: UIHostingController<AnyView>?

    public override init(frame: CGRect) {
        super.init(frame: frame)
        setUp()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setUp()
    }

    /// Binds the sign-in flow to this button.
    ///
    /// - Parameters:
    ///   - paspo: SDK instance. Defaults to ``Paspo/shared``.
    ///   - scope: Profile data to request.
    ///   - nonceProvider: Async call fetching a fresh nonce from your backend.
    ///   - onResult: Result handler.
    public func setAuthHandler(
        paspo: Paspo? = nil,
        scope: PaspoScope = .phones,
        nonceProvider: @escaping () async throws -> String,
        onResult: @escaping (PaspoAuthResult) -> Void
    ) {
        self.paspo = paspo ?? Paspo.shared
        self.scope = scope
        self.nonceProvider = nonceProvider
        self.onResult = onResult
    }

    public override var intrinsicContentSize: CGSize {
        CGSize(width: isLogoOnly ? 50 : UIView.noIntrinsicMetric, height: 50)
    }

    private func setUp() {
        let controller = UIHostingController(rootView: AnyView(EmptyView()))
        controller.view.backgroundColor = .clear
        controller.view.isUserInteractionEnabled = false
        controller.view.translatesAutoresizingMaskIntoConstraints = false
        addSubview(controller.view)
        NSLayoutConstraint.activate([
            controller.view.topAnchor.constraint(equalTo: topAnchor),
            controller.view.bottomAnchor.constraint(equalTo: bottomAnchor),
            controller.view.leadingAnchor.constraint(equalTo: leadingAnchor),
            controller.view.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
        hostingController = controller
        addTarget(self, action: #selector(handleTap), for: .touchUpInside)
        reload()
    }

    private func reload() {
        let colors = theme.colors(for: traitCollection.userInterfaceStyle == .dark ? .dark : .light)
        hostingController?.rootView = AnyView(
            PaspoSignInButtonContent(
                colors: colors,
                cornerRadius: cornerRadius,
                showsLogo: showsLogo,
                isLogoOnly: isLogoOnly,
                title: title ?? PaspoUIStrings.signIn,
                isLoading: isRunning
            )
        )
        isEnabled = isRunning == false
        invalidateIntrinsicContentSize()
    }

    public override func traitCollectionDidChange(_ previous: UITraitCollection?) {
        super.traitCollectionDidChange(previous)
        if previous?.userInterfaceStyle != traitCollection.userInterfaceStyle {
            reload()
        }
    }

    @objc private func handleTap() {
        guard isRunning == false, let paspo, let nonceProvider, let onResult else { return }
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
#endif
