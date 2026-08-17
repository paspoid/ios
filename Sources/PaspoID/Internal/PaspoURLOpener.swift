import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// Indirection over `UIApplication` so the flow can be driven in tests.
@MainActor
protocol PaspoURLOpening: AnyObject {
    func canOpen(_ url: URL) -> Bool
    func open(_ url: URL) async -> Bool
}

@MainActor
final class PaspoSystemURLOpener: PaspoURLOpening {
    func canOpen(_ url: URL) -> Bool {
        #if canImport(UIKit)
        return UIApplication.shared.canOpenURL(url)
        #else
        return false
        #endif
    }

    func open(_ url: URL) async -> Bool {
        #if canImport(UIKit)
        return await UIApplication.shared.open(url)
        #else
        return false
        #endif
    }
}
