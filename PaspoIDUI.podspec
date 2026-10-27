Pod::Spec.new do |s|
  s.name             = 'PaspoIDUI'
  s.version          = '1.2.1'
  s.summary          = 'Ready-made "Sign in with Paspo ID" button for iOS.'
  s.description      = <<~DESC
    SwiftUI and UIKit sign-in buttons for the Paspo ID SDK: four themes, configurable corner
    radius, logo-only and text-only variants, and a render-only surface for full visual control.
  DESC
  s.homepage         = 'https://paspo.id'
  s.license          = { type: 'Apache-2.0', file: 'LICENSE' }
  s.author           = { 'PingOcean LLP' => 'https://pingocean.com' }
  s.source           = { git: 'https://github.com/paspoid/ios.git', tag: s.version.to_s }

  s.ios.deployment_target = '15.0'
  s.swift_versions   = ['5.9']
  s.frameworks       = 'SwiftUI', 'UIKit'

  s.dependency 'PaspoID', s.version.to_s
  s.source_files     = 'Sources/PaspoIDUI/**/*.swift'
end
