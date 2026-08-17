import Foundation
import PaspoIDWire

/// Everything the SDK needs to know about the integrating application.
public struct PaspoConfiguration: Sendable {
    /// URL Paspo ID opens to hand the result back.
    ///
    /// Use a Universal Link on a domain you control (`https://your.app/paspo/callback`) and
    /// serve an `apple-app-site-association` file for it. The value must be registered with
    /// Paspo during onboarding: the app rejects redirects it does not know.
    public var redirectURL: URL

    /// Optional custom-scheme fallback (`yourapp://paspo-callback`) used when the Universal
    /// Link cannot be delivered — most notably in the Simulator, where associated domains
    /// are not resolved unless the AASA file is reachable.
    ///
    /// Register the scheme under `CFBundleURLTypes`. Prefer leaving this `nil` in production:
    /// custom schemes can be claimed by other applications.
    public var fallbackRedirectURL: URL?

    /// Bundle identifier reported to Paspo ID. Defaults to the main bundle's identifier.
    public var bundleID: String

    /// App Store page opened when Paspo ID is not installed. When `nil`, the SDK returns
    /// ``PaspoAuthResult/notInstalled`` without navigating anywhere.
    public var appStoreURL: URL?

    /// How long to wait for a callback before giving up. Defaults to 10 minutes.
    public var callbackTimeout: TimeInterval

    /// Grace period after the app returns to the foreground before an absent callback is
    /// treated as a cancellation. Defaults to 0.7 s.
    public var cancellationGracePeriod: TimeInterval

    public init(
        redirectURL: URL,
        fallbackRedirectURL: URL? = nil,
        bundleID: String = Bundle.main.bundleIdentifier ?? "",
        appStoreURL: URL? = nil,
        callbackTimeout: TimeInterval = 600,
        cancellationGracePeriod: TimeInterval = 0.7
    ) {
        self.redirectURL = redirectURL
        self.fallbackRedirectURL = fallbackRedirectURL
        self.bundleID = bundleID
        self.appStoreURL = appStoreURL
        self.callbackTimeout = callbackTimeout
        self.cancellationGracePeriod = cancellationGracePeriod
    }

    /// Every URL this application accepts a callback on.
    var acceptedRedirectURLs: [URL] {
        [redirectURL, fallbackRedirectURL].compactMap { $0 }
    }
}
