/// A strongly-typed screen identifier used in analytics events.
///
/// Define your app's screens by extending `PulseScreen` with static members:
///
/// ```swift
/// extension PulseScreen {
///     static let home      = PulseScreen("home")
///     static let settings  = PulseScreen("settings")
///     static let profile   = PulseScreen("profile")
/// }
/// ```
///
/// Then use them at call sites:
///
/// ```swift
/// Pulse.track(.screenViewed(.home))
/// ```
public struct PulseScreen: RawRepresentable, Hashable, Sendable {
    /// The raw string identifier sent in the wire format.
    public let rawValue: String

    /// Creates a screen with the given raw string identifier.
    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }

    /// Creates a screen with the given raw string identifier.
    public init(rawValue: String) {
        self.rawValue = rawValue
    }
}
