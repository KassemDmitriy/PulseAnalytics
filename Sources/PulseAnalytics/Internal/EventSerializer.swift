import Foundation

/// Converts ``PulseEvent`` values into wire-format JSON dictionaries.
///
/// All functions are pure (no side effects) for easy unit testing.
/// 
/// Supports per-event `event_id` and provides a batch assembly helper.
enum EventSerializer {

    // nonisolated(unsafe) is safe here because the formatter is only ever read
    // (never mutated) after its single initialization at first use.
    private nonisolated(unsafe) static let iso8601Formatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    /// Serializes a ``PulseEvent`` into a wire-format dictionary.
    ///
    /// - Parameters:
    ///   - event: The event to serialize.
    ///   - eventID: The unique event UUID.
    ///   - sessionID: The current session UUID.
    ///   - userID: The identified user ID, if any.
    ///   - appID: The application identifier.
    ///   - installID: Stable anonymous install identifier.
    ///   - deviceInfo: Collected device metadata.
    ///   - timestamp: The event timestamp (defaults to now).
    /// - Returns: A `[String: Any]` dictionary ready for JSON serialization.
    static func serialize(
        _ event: PulseEvent,
        eventID: UUID,
        sessionID: UUID,
        userID: String?,
        appID: String,
        installID: UUID,
        deviceInfo: DeviceInfo,
        timestamp: Date = Date()
    ) -> [String: Any] {
        let (name, properties) = eventNameAndProperties(event)

        var dict: [String: Any] = [
            "event": name,
            "event_id": eventID.uuidString,
            "session_id": sessionID.uuidString,
            "app_id": appID,
            "timestamp": iso8601Formatter.string(from: timestamp),
            "device": deviceInfo.jsonDictionary()
        ]

        if let userID {
            dict["user_id"] = userID
        }

        if let properties {
            dict["properties"] = properties.mapValues { $0.jsonValue }
        }

        return dict
    }

    /// Builds the top-level batch body with shared fields.
    /// - Parameters:
    ///   - appID: Application identifier
    ///   - apiKey: API key
    ///   - installID: Stable anonymous install identifier
    ///   - events: Array of per-event dictionaries from `serialize`
    /// - Returns: Dictionary suitable for JSON serialization
    static func makeBatchBody(
        appID: String,
        apiKey: String,
        installID: UUID,
        events: [[String: Any]]
    ) -> [String: Any] {
        return [
            "app_id": appID,
            "api_key": apiKey,
            "install_id": installID.uuidString,
            "events": events
        ]
    }

    // MARK: - Event name mapping

    /// Returns the snake_case event name and optional properties for each ``PulseEvent`` case.
    ///
    /// This switch is intentionally exhaustive — adding a new case without handling it
    /// here causes a compile-time error.
    static func eventNameAndProperties(_ event: PulseEvent) -> (name: String, properties: [String: PulseValue]?) {
        switch event {
        // MARK: Lifecycle
        case .sessionStarted:
            return ("session_started", nil)

        case .sessionEnded(let duration):
            return ("session_ended", ["duration": .double(duration)])

        case .appBackgrounded:
            return ("app_backgrounded", nil)

        case .appForegrounded:
            return ("app_foregrounded", nil)

        // MARK: Navigation
        case .screenViewed(let screen):
            return ("screen_viewed", ["screen": .string(screen.rawValue)])

        case .screenDismissed(let screen):
            return ("screen_dismissed", ["screen": .string(screen.rawValue)])

        // MARK: Engagement
        case .featureUsed(let feature, let properties):
            var props: [String: PulseValue] = ["feature": .string(feature.rawValue)]
            if let extra = properties {
                props.merge(extra) { _, new in new }
            }
            return ("feature_used", props)

        case .buttonTapped(let button, let screen):
            return ("button_tapped", [
                "button": .string(button),
                "screen": .string(screen.rawValue)
            ])

        case .searchPerformed(let query, let count):
            return ("search_performed", [
                "query": .string(query),
                "results_count": .int(count)
            ])

        // MARK: Commerce
        case .purchaseCompleted(let productID, let revenue, let currency):
            return ("purchase_completed", [
                "product_id": .string(productID),
                "revenue": .double(revenue),
                "currency": .string(currency)
            ])

        case .purchaseStarted(let productID):
            return ("purchase_started", ["product_id": .string(productID)])

        case .purchaseFailed(let productID, let reason):
            var props: [String: PulseValue] = ["product_id": .string(productID)]
            if let reason { props["reason"] = .string(reason) }
            return ("purchase_failed", props)

        case .subscriptionStarted(let plan):
            return ("subscription_started", ["plan": .string(plan)])

        case .subscriptionCancelled(let reason):
            var props: [String: PulseValue] = [:]
            if let reason { props["reason"] = .string(reason) }
            return ("subscription_cancelled", props.isEmpty ? nil : props)

        // MARK: Quality
        case .errorOccurred(let code, let message, let screen):
            var props: [String: PulseValue] = ["code": .string(code)]
            if let message { props["message"] = .string(message) }
            if let screen { props["screen"] = .string(screen.rawValue) }
            return ("error_occurred", props)

        case .crashRecovered:
            return ("crash_recovered", nil)

        // MARK: Extensibility
        case .custom(let name, let properties):
            return (name, properties)
        }
    }
}
