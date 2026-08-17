import Foundation

/// Result Paspo ID delivers back to the client application by opening its redirect URL.
public enum PaspoAuthCallback: Sendable, Equatable {
    case success(state: String, envelope: PaspoEncryptedEnvelope)
    case failure(state: String, errorCode: Int)
    case cancelled(state: String)

    /// The `state` echoed from the originating request.
    public var state: String {
        switch self {
        case let .success(state, _), let .failure(state, _), let .cancelled(state):
            return state
        }
    }

    /// Appends the callback parameters to `redirectURL`, preserving any query it already has.
    public func makeURL(redirectURL: URL) throws -> URL? {
        guard var components = URLComponents(url: redirectURL, resolvingAgainstBaseURL: false) else { return nil }

        typealias Key = PaspoSSOConstants.CallbackParameter
        var items = components.queryItems ?? []
        items.append(URLQueryItem(name: Key.state, value: state))
        items.append(URLQueryItem(name: Key.version, value: String(PaspoSSOConstants.contractVersion)))

        switch self {
        case let .success(_, envelope):
            items.append(URLQueryItem(name: Key.result, value: PaspoSSOConstants.CallbackResult.success))
            items.append(URLQueryItem(name: Key.data, value: try envelope.encodedForTransport()))
        case let .failure(_, errorCode):
            items.append(URLQueryItem(name: Key.result, value: PaspoSSOConstants.CallbackResult.error))
            items.append(URLQueryItem(name: Key.errorCode, value: String(errorCode)))
        case .cancelled:
            items.append(URLQueryItem(name: Key.result, value: PaspoSSOConstants.CallbackResult.cancelled))
        }

        components.queryItems = items
        return components.url
    }

    /// Parses an incoming callback URL. Returns `nil` when the URL carries no Paspo result.
    public static func parse(url: URL) -> PaspoAuthCallback? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }

        typealias Key = PaspoSSOConstants.CallbackParameter
        let query = components.queryItems ?? []
        func value(_ name: String) -> String? {
            guard let value = query.first(where: { $0.name == name })?.value, value.isEmpty == false else { return nil }
            return value
        }

        guard let result = value(Key.result), let state = value(Key.state) else { return nil }

        switch result {
        case PaspoSSOConstants.CallbackResult.success:
            guard let data = value(Key.data),
                  let envelope = try? PaspoEncryptedEnvelope.decodeFromTransport(data)
            else {
                return .failure(state: state, errorCode: PaspoClientError.invalidRequest.code)
            }
            return .success(state: state, envelope: envelope)

        case PaspoSSOConstants.CallbackResult.error:
            let code = value(Key.errorCode).flatMap(Int.init) ?? PaspoClientError.unknown.code
            return .failure(state: state, errorCode: code)

        case PaspoSSOConstants.CallbackResult.cancelled:
            return .cancelled(state: state)

        default:
            return nil
        }
    }
}
