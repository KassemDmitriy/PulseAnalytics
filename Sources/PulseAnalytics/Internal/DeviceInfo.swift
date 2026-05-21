import Foundation

/// Static device and application metadata attached to every event on the wire.
///
/// All fields are collected once at process start and cached.
struct DeviceInfo: Sendable, Codable {
    let osVersion: String
    let model: String
    let locale: String
    let timezone: String
    let appVersion: String
    let appBuild: String

    /// Collects current device and app metadata.
    static func collect() -> DeviceInfo {
        DeviceInfo(
            osVersion: Self.osVersionString,
            model: Self.modelIdentifier,
            locale: Locale.current.identifier,
            timezone: TimeZone.current.identifier,
            appVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown",
            appBuild: Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown"
        )
    }

    func jsonDictionary() -> [String: String] {
        [
            "os_version": osVersion,
            "model": model,
            "locale": locale,
            "timezone": timezone,
            "app_version": appVersion,
            "app_build": appBuild
        ]
    }

    // MARK: - Private helpers

    private static var osVersionString: String {
#if canImport(UIKit)
        return _UIKitOSVersion()
#else
        return ProcessInfo.processInfo.operatingSystemVersionString
#endif
    }

    private static var modelIdentifier: String {
#if canImport(UIKit)
        return _UIKitModel()
#else
        return "unknown"
#endif
    }
}

#if canImport(UIKit)
import UIKit

private func _UIKitOSVersion() -> String {
    UIDevice.current.systemVersion
}

private func _UIKitModel() -> String {
    UIDevice.current.model
}
#endif
