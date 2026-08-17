Pod::Spec.new do |s|
  s.name             = 'PaspoID'
  s.version          = '1.0.0'
  s.summary          = 'Sign in with Paspo ID for iOS.'
  s.description      = <<~DESC
    Adds "Sign in with Paspo ID" to an iOS app: one call returns a one-time authorization
    code that your server exchanges for the user's verified profile data. The exchange with
    the Paspo ID app is end-to-end encrypted by the SDK.
  DESC
  s.homepage         = 'https://paspo.id'
  s.license          = { type: 'Apache-2.0', file: 'LICENSE' }
  s.author           = { 'PingOcean LLP' => 'https://pingocean.com' }
  s.source           = { git: 'https://github.com/pingocean/paspo-ios-sdk.git', tag: s.version.to_s }
  s.documentation_url = 'https://github.com/pingocean/paspo-ios-sdk/blob/main/README.md'

  s.ios.deployment_target = '15.0'
  s.swift_versions   = ['5.9']
  s.frameworks       = 'Foundation', 'CryptoKit', 'UIKit'

  # The wire contract ships with the core pod: CocoaPods has no notion of the package's
  # separate `PaspoIDWire` target, and the two are versioned together anyway.
  s.source_files     = 'Sources/PaspoID/**/*.swift', 'Sources/PaspoIDWire/**/*.swift'
end
