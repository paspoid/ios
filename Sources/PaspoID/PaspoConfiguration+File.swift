import Foundation

extension PaspoConfiguration {
    /// Name of the configuration file downloaded from the Paspo admin panel.
    public static let fileName = "PaspoID-Info.plist"

    /// Why a configuration file could not be used.
    public enum FileError: Error, Equatable, CustomStringConvertible {
        case notFound(String)
        case unreadable(String)
        case missingKey(String)
        case invalidURL(key: String)

        public var description: String {
            switch self {
            case let .notFound(name):
                return "\(name) is not in the app bundle. Download it from the Paspo admin panel and add it to the app target."
            case let .unreadable(reason):
                return "\(PaspoConfiguration.fileName) is not a valid property list: \(reason)"
            case let .missingKey(key):
                return "\(PaspoConfiguration.fileName) has no \(key). Download the file again from the Paspo admin panel."
            case let .invalidURL(key):
                return "\(key) in \(PaspoConfiguration.fileName) is not a valid URL."
            }
        }
    }

    /// Reads the configuration from `PaspoID-Info.plist` in `bundle`.
    ///
    /// The file holds `SERVICE_ID` and `REGION`, plus optional `REDIRECT_URL` (defaults to
    /// ``returnURL(serviceID:region:)``), `FALLBACK_REDIRECT_URL` and `BUNDLE_ID`. Settings the file does not cover keep their defaults
    /// and can be changed on the returned value.
    public init(bundle: Bundle = .main) throws {
        let name = (Self.fileName as NSString).deletingPathExtension
        guard let url = bundle.url(forResource: name, withExtension: "plist") else {
            throw FileError.notFound(Self.fileName)
        }
        try self.init(contentsOf: url)
    }

    /// Reads the configuration from a `PaspoID-Info.plist` file at `url`.
    public init(contentsOf url: URL) throws {
        let values: [String: Any]
        do {
            let data = try Data(contentsOf: url)
            guard let dictionary = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else {
                throw FileError.unreadable("the root is not a dictionary")
            }
            values = dictionary
        } catch let error as FileError {
            throw error
        } catch {
            throw FileError.unreadable("\(error)")
        }

        func string(_ key: String) -> String? {
            guard let value = (values[key] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
                  value.isEmpty == false
            else { return nil }
            return value
        }
        func link(_ key: String) throws -> URL? {
            guard let value = string(key) else { return nil }
            guard let url = URL(string: value), url.scheme != nil else { throw FileError.invalidURL(key: key) }
            return url
        }

        guard let serviceID = string("SERVICE_ID") else { throw FileError.missingKey("SERVICE_ID") }
        guard let region = string("REGION") else { throw FileError.missingKey("REGION") }
        let paspoRegion = PaspoRegion(rawValue: region)
        guard let redirectURL = try link("REDIRECT_URL") ?? Self.returnURL(serviceID: serviceID, region: paspoRegion)
        else { throw FileError.invalidURL(key: "SERVICE_ID") }

        self.init(
            redirectURL: redirectURL,
            fallbackRedirectURL: try link("FALLBACK_REDIRECT_URL"),
            bundleID: string("BUNDLE_ID") ?? Bundle.main.bundleIdentifier ?? "",
            serviceID: serviceID,
            region: paspoRegion
        )
    }
}
