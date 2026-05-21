import Testing
import Foundation
@testable import PulseAnalytics

@Suite("EventSerializer")
struct EventSerializerTests {

    private let session = UUID()
    private let device = DeviceInfo(
        osVersion: "17.0",
        model: "iPhone",
        locale: "en_US",
        timezone: "UTC",
        appVersion: "1.0",
        appBuild: "1"
    )

    private func name(of event: PulseEvent) -> String {
        EventSerializer.eventNameAndProperties(event).name
    }

    // MARK: - Lifecycle

    @Test("sessionStarted → session_started")
    func sessionStarted() {
        #expect(name(of: .sessionStarted) == "session_started")
    }

    @Test("sessionEnded → session_ended")
    func sessionEnded() {
        let (n, props) = EventSerializer.eventNameAndProperties(.sessionEnded(duration: 60))
        #expect(n == "session_ended")
        #expect(props?["duration"] == .double(60))
    }

    @Test("appBackgrounded → app_backgrounded")
    func appBackgrounded() {
        #expect(name(of: .appBackgrounded) == "app_backgrounded")
    }

    @Test("appForegrounded → app_foregrounded")
    func appForegrounded() {
        #expect(name(of: .appForegrounded) == "app_foregrounded")
    }

    // MARK: - Navigation

    @Test("screenViewed → screen_viewed with screen property")
    func screenViewed() {
        let (n, props) = EventSerializer.eventNameAndProperties(.screenViewed(PulseScreen("home")))
        #expect(n == "screen_viewed")
        #expect(props?["screen"] == .string("home"))
    }

    @Test("screenDismissed → screen_dismissed with screen property")
    func screenDismissed() {
        let (n, props) = EventSerializer.eventNameAndProperties(.screenDismissed(PulseScreen("settings")))
        #expect(n == "screen_dismissed")
        #expect(props?["screen"] == .string("settings"))
    }

    // MARK: - Engagement

    @Test("featureUsed → feature_used with feature and extra properties")
    func featureUsed() {
        let (n, props) = EventSerializer.eventNameAndProperties(
            .featureUsed(PulseFeature("search"), properties: ["query": "swift"])
        )
        #expect(n == "feature_used")
        #expect(props?["feature"] == .string("search"))
        #expect(props?["query"] == .string("swift"))
    }

    @Test("featureUsed without extra properties still includes feature")
    func featureUsedNoProps() {
        let (n, props) = EventSerializer.eventNameAndProperties(
            .featureUsed(PulseFeature("darkMode"), properties: nil)
        )
        #expect(n == "feature_used")
        #expect(props?["feature"] == .string("darkMode"))
    }

    @Test("buttonTapped → button_tapped with button and screen")
    func buttonTapped() {
        let (n, props) = EventSerializer.eventNameAndProperties(
            .buttonTapped("subscribe", screen: PulseScreen("home"))
        )
        #expect(n == "button_tapped")
        #expect(props?["button"] == .string("subscribe"))
        #expect(props?["screen"] == .string("home"))
    }

    @Test("searchPerformed → search_performed with query and results_count")
    func searchPerformed() {
        let (n, props) = EventSerializer.eventNameAndProperties(
            .searchPerformed(query: "analytics", resultsCount: 5)
        )
        #expect(n == "search_performed")
        #expect(props?["query"] == .string("analytics"))
        #expect(props?["results_count"] == .int(5))
    }

    // MARK: - Commerce

    @Test("purchaseCompleted → purchase_completed with productID, revenue, currency")
    func purchaseCompleted() {
        let (n, props) = EventSerializer.eventNameAndProperties(
            .purchaseCompleted(productID: "pro", revenue: 9.99, currency: "USD")
        )
        #expect(n == "purchase_completed")
        #expect(props?["product_id"] == .string("pro"))
        #expect(props?["revenue"] == .double(9.99))
        #expect(props?["currency"] == .string("USD"))
    }

    @Test("purchaseStarted → purchase_started")
    func purchaseStarted() {
        let (n, props) = EventSerializer.eventNameAndProperties(.purchaseStarted(productID: "basic"))
        #expect(n == "purchase_started")
        #expect(props?["product_id"] == .string("basic"))
    }

    @Test("purchaseFailed → purchase_failed with reason when provided")
    func purchaseFailedWithReason() {
        let (n, props) = EventSerializer.eventNameAndProperties(
            .purchaseFailed(productID: "pro", reason: "card_declined")
        )
        #expect(n == "purchase_failed")
        #expect(props?["product_id"] == .string("pro"))
        #expect(props?["reason"] == .string("card_declined"))
    }

    @Test("purchaseFailed → purchase_failed without reason key when nil")
    func purchaseFailedNoReason() {
        let (_, props) = EventSerializer.eventNameAndProperties(
            .purchaseFailed(productID: "pro", reason: nil)
        )
        #expect(props?["reason"] == nil)
    }

    @Test("subscriptionStarted → subscription_started with plan")
    func subscriptionStarted() {
        let (n, props) = EventSerializer.eventNameAndProperties(.subscriptionStarted(plan: "annual"))
        #expect(n == "subscription_started")
        #expect(props?["plan"] == .string("annual"))
    }

    @Test("subscriptionCancelled → subscription_cancelled with reason when provided")
    func subscriptionCancelledWithReason() {
        let (n, props) = EventSerializer.eventNameAndProperties(
            .subscriptionCancelled(reason: "too_expensive")
        )
        #expect(n == "subscription_cancelled")
        #expect(props?["reason"] == .string("too_expensive"))
    }

    @Test("subscriptionCancelled → subscription_cancelled with nil properties when reason is nil")
    func subscriptionCancelledNoReason() {
        let (n, props) = EventSerializer.eventNameAndProperties(.subscriptionCancelled(reason: nil))
        #expect(n == "subscription_cancelled")
        #expect(props == nil)
    }

    // MARK: - Quality

    @Test("errorOccurred → error_occurred with code, message, screen")
    func errorOccurred() {
        let (n, props) = EventSerializer.eventNameAndProperties(
            .errorOccurred(code: "E001", message: "Token expired", screen: PulseScreen("profile"))
        )
        #expect(n == "error_occurred")
        #expect(props?["code"] == .string("E001"))
        #expect(props?["message"] == .string("Token expired"))
        #expect(props?["screen"] == .string("profile"))
    }

    @Test("errorOccurred without optional fields only includes code")
    func errorOccurredMinimal() {
        let (_, props) = EventSerializer.eventNameAndProperties(
            .errorOccurred(code: "E002", message: nil, screen: nil)
        )
        #expect(props?["code"] == .string("E002"))
        #expect(props?["message"] == nil)
        #expect(props?["screen"] == nil)
    }

    @Test("crashRecovered → crash_recovered")
    func crashRecovered() {
        #expect(name(of: .crashRecovered) == "crash_recovered")
    }

    // MARK: - Extensibility

    @Test("custom → uses provided name and properties")
    func custom() {
        let (n, props) = EventSerializer.eventNameAndProperties(
            .custom(name: "my_event", properties: ["key": "value"])
        )
        #expect(n == "my_event")
        #expect(props?["key"] == .string("value"))
    }

    // MARK: - Full serialization

    @Test("serialize attaches required top-level fields")
    func serializeTopLevelFields() {
        let dict = EventSerializer.serialize(
            .sessionStarted,
            sessionID: session,
            userID: "user-1",
            appID: "com.test",
            deviceInfo: device
        )
        #expect(dict["event"] as? String == "session_started")
        #expect(dict["session_id"] as? String == session.uuidString)
        #expect(dict["user_id"] as? String == "user-1")
        #expect(dict["app_id"] as? String == "com.test")
        #expect(dict["timestamp"] as? String != nil)
        #expect(dict["device"] != nil)
    }

    @Test("serialize omits user_id when nil")
    func serializeNoUserID() {
        let dict = EventSerializer.serialize(
            .sessionStarted,
            sessionID: session,
            userID: nil,
            appID: "com.test",
            deviceInfo: device
        )
        #expect(dict["user_id"] == nil)
    }
}
