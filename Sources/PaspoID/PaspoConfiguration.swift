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

    /// Public identifier of your service, issued in the Paspo admin panel together with ``region``.
    ///
    /// Enables the service landing page (``landingURL``), opened when neither Paspo ID nor its
    /// App Clip can take the sign-in.
    public var serviceID: String?

    /// Region your service is registered in, issued in the Paspo admin panel.
    public var region: PaspoRegion

    /// App Clip link the sign-in is handed to when Paspo ID is not installed; the SDK appends the
    /// request to its query. `nil` skips the App Clip.
    ///
    /// Defaults to Apple's App Clip link for Paspo ID. Point it at `https://paspo.id/clip/sso` to
    /// test with a Local Experience before the App Clip is live on your device.
    public var appClipURL: URL?

    /// App Store page opened when Paspo ID is not installed and there is no ``landingURL``.
    /// When both are `nil`, the SDK returns ``PaspoAuthResult/notInstalled`` without navigating anywhere.
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
        serviceID: String? = nil,
        region: PaspoRegion = .kz,
        appClipURL: URL? = PaspoConfiguration.paspoAppClipURL,
        appStoreURL: URL? = nil,
        callbackTimeout: TimeInterval = 600,
        cancellationGracePeriod: TimeInterval = 0.7
    ) {
        self.redirectURL = redirectURL
        self.fallbackRedirectURL = fallbackRedirectURL
        self.bundleID = bundleID
        self.serviceID = serviceID
        self.region = region
        self.appClipURL = appClipURL
        self.appStoreURL = appStoreURL
        self.callbackTimeout = callbackTimeout
        self.cancellationGracePeriod = cancellationGracePeriod
    }

    /// Apple's App Clip link for Paspo ID.
    public static let paspoAppClipURL = URL(string: "https://appclip.apple.com/id?p=paspo.id.Clip")!

    /// `https://{region}.paspo.id/mob/s/{serviceID}?flow=phone`: your service's page in Paspo ID,
    /// which installs Paspo ID and starts sign-up with a phone number. `nil` without ``serviceID``.
    public var landingURL: URL? {
        guard let serviceID, serviceID.isEmpty == false else { return nil }
        var components = URLComponents()
        components.scheme = "https"
        components.host = "\(region.rawValue).paspo.id"
        components.path = "/mob/s/\(serviceID)"
        components.queryItems = [URLQueryItem(name: "flow", value: "phone")]
        return components.url
    }

    /// Every URL this application accepts a callback on.
    var acceptedRedirectURLs: [URL] {
        [redirectURL, fallbackRedirectURL].compactMap { $0 }
    }
}
