import Foundation

/// An exhaustive, compiler-enforced set of analytics events.
///
/// Using an enum instead of raw strings guarantees that every event your app
/// can emit is known at compile time. The ``EventSerializer`` maps each case
/// to its snake_case wire-format name.
///
/// ## Lifecycle
/// ```swift
/// Pulse.track(.sessionStarted)
/// Pulse.track(.sessionEnded(duration: 120))
/// Pulse.track(.appBackgrounded)
/// Pulse.track(.appForegrounded)
/// ```
///
/// ## Navigation
/// ```swift
/// Pulse.track(.screenViewed(.home))
/// Pulse.track(.screenDismissed(.settings))
/// ```
///
/// ## Engagement
/// ```swift
/// Pulse.track(.featureUsed(.search, properties: ["query": "swift"]))
/// Pulse.track(.buttonTapped("subscribe", screen: .home))
/// Pulse.track(.searchPerformed(query: "analytics", resultsCount: 14))
/// ```
///
/// ## Commerce
/// ```swift
/// Pulse.track(.purchaseCompleted(productID: "pro_monthly", revenue: 9.99, currency: "USD"))
/// ```
///
/// ## Quality
/// ```swift
/// Pulse.track(.errorOccurred(code: "AUTH_001", message: "Token expired", screen: .profile))
/// ```
///
/// ## Custom
/// ```swift
/// Pulse.track(.custom(name: "onboarding_step", properties: ["step": 3]))
/// ```
public enum PulseEvent: Sendable {

    // MARK: - Lifecycle

    /// Fired when a new session begins (on configure or foreground).
    case sessionStarted

    /// Fired when a session ends (on background).
    case sessionEnded(duration: TimeInterval)

    /// Fired when the app moves to the background.
    case appBackgrounded

    /// Fired when the app returns to the foreground.
    case appForegrounded

    // MARK: - Navigation

    /// Fired when a screen becomes visible.
    case screenViewed(PulseScreen)

    /// Fired when a screen is dismissed or hidden.
    case screenDismissed(PulseScreen)

    // MARK: - Engagement

    /// Fired when the user interacts with a named feature.
    case featureUsed(PulseFeature, properties: [String: PulseValue]?)

    /// Fired when a button is tapped.
    case buttonTapped(String, screen: PulseScreen)

    /// Fired when the user performs a search.
    case searchPerformed(query: String, resultsCount: Int)

    // MARK: - Commerce

    /// Fired when a purchase completes successfully.
    case purchaseCompleted(productID: String, revenue: Double, currency: String)

    /// Fired when the purchase flow is initiated.
    case purchaseStarted(productID: String)

    /// Fired when a purchase attempt fails.
    case purchaseFailed(productID: String, reason: String?)

    /// Fired when a subscription is activated.
    case subscriptionStarted(plan: String)

    /// Fired when a subscription is cancelled.
    case subscriptionCancelled(reason: String?)

    // MARK: - Quality

    /// Fired when a non-fatal error is encountered.
    case errorOccurred(code: String, message: String?, screen: PulseScreen?)

    /// Fired when the app recovers from a previous crash on next launch.
    case crashRecovered

    // MARK: - Extensibility

    /// A custom event not covered by the typed cases above.
    case custom(name: String, properties: [String: PulseValue]?)
}
