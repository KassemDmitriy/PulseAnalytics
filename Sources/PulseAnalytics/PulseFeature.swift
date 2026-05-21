/// A strongly-typed feature identifier used in analytics events.
///
/// Define your app's features by extending `PulseFeature` with static members:
///
/// ```swift
/// extension PulseFeature {
///     static let search      = PulseFeature("search")
///     static let darkMode    = PulseFeature("dark_mode")
///     static let shareSheet  = PulseFeature("share_sheet")
/// }
/// ```
///
/// Then use them at call sites:
///
/// ```swift
/// Pulse.track(.featureUsed(.search, properties: ["query": "analytics"]))
/// ```
public struct PulseFeature: RawRepresentable, Hashable, Sendable {
    /// The raw string identifier sent in the wire format.
    public let rawValue: String

    /// Creates a feature with the given raw string identifier.
    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }

    /// Creates a feature with the given raw string identifier.
    public init(rawValue: String) {
        self.rawValue = rawValue
    }
}
