# Changelog

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

## [1.0.2] - 2026-08-20

### Changed
- `PaspoSignInButton` now matches the Android SDK exactly: pill radius, 48pt minimum height, 30pt mark, 16pt horizontal padding, 12pt gap and a 16pt medium label.
- The button sizes itself to its content instead of filling the available width. Wrap it in your own `frame` to widen it.
- Theme palettes are the Android ones, down to the brand blue (`#1677FF`), and no longer follow the host's colour scheme - the same button renders identically in every app.
- `PaspoSignInButtonContent` takes a `theme:` and an optional `colors:` override, and dims itself at 60% when `isEnabled` is false.

## [1.0.0] - unreleased

### Added
- `Paspo(configuration:)` and `Paspo.configure(_:)` / `Paspo.shared` - the SDK entry point.
- `authenticate(scope:nonce:)` - starts the SSO flow via the Paspo ID app; a single result channel `PaspoAuthResult` (`.success` / `.cancelled` / `.notInstalled` / `.failure`).
- `handle(url:)` - feeds callback URLs (Universal Link or custom scheme) back into the SDK.
- `isPaspoInstalled` - checks whether the Paspo ID app is installed.
- `isSignInRequest(url:)` - optional entry point for sign-in initiated from Paspo.
- `cleanup()` - manual destruction of the pending flow and its ephemeral encryption key.
- `PaspoScope` - requested profile data: `.phones`, `.emails`, `.nationalID`, `.paspoID`.
- `PaspoClientError` - flow error codes, identical to the Android SDK.
- `PaspoConfiguration` - redirect URLs, bundle identifier, App Store URL, timeouts.
- End-to-end encryption of the exchange with Paspo: ECDH P-256 + HKDF (HMAC-SHA256) + AES-256-GCM, ephemeral in-memory keys.
- `state` binding between a request and its callback, so foreign or stale callbacks cannot resolve a live flow.
- App Store redirect when Paspo ID is not installed, with referral nonce hand-off after installation.
- `PaspoIDUI`: `PaspoSignInButton` (SwiftUI), `PaspoSignInButtonView` (UIKit), `PaspoSignInButtonContent` (render-only), four themes and a resource-free Paspo mark.
- Distribution as a Swift package, CocoaPods pods and prebuilt XCFrameworks.
