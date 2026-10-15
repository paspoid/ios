import Foundation

/// Region a service is registered in, as issued in the Paspo admin panel (`kz`, `ru`, …).
///
/// Unknown values are accepted as they are, so a region added on the server works without
/// an SDK update: `PaspoRegion(rawValue: "uz")`.
public struct PaspoRegion: RawRepresentable, Hashable, Sendable, ExpressibleByStringLiteral {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue.lowercased()
    }

    public init(stringLiteral value: String) {
        self.init(rawValue: value)
    }

    public static let kz = PaspoRegion(rawValue: "kz")
    public static let ru = PaspoRegion(rawValue: "ru")
}
