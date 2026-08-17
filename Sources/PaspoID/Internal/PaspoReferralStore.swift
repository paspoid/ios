import Foundation

/// Persists the nonce of an attempt that was interrupted by an App Store redirect, so the
/// next successful attempt can carry it as an install-attribution referral.
///
/// Mirrors Android's `ReferralManager` (`SharedPreferences` there, `UserDefaults` here).
struct PaspoReferralStore {
    private static let key = "paspoid.sso.referral_nonce"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func save(nonce: String) {
        defaults.set(nonce, forKey: Self.key)
    }

    func load() -> String? {
        defaults.string(forKey: Self.key)
    }

    func clear() {
        defaults.removeObject(forKey: Self.key)
    }
}
