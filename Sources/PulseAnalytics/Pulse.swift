import Foundation

/// The main entry point for PulseAnalytics.
///
/// Call ``configure(appID:apiKey:environment:options:)`` once at app launch
/// (typically in `application(_:didFinishLaunchingWithOptions:)` or your
/// `@main` App initializer), then call ``track(_:)`` anywhere in your app.
///
/// ```swift
/// // AppDelegate or @main App
/// Pulse.configure(appID: "com.example.app", apiKey: "your-api-key", environment: .production)
///
/// // Anywhere
/// Pulse.track(.screenViewed(.home))
/// Pulse.identify(userID: "user-123", traits: ["plan": "pro"])
/// ```
///
/// All public methods are `@MainActor` — safe to call from SwiftUI views and
/// UIKit view controllers without additional dispatching.
@MainActor
public enum Pulse {

    // MARK: - Private state

    private static var isConfigured = false
    private static var environment: PulseEnvironment = .production
    private static var options: PulseOptions = PulseOptions()
    private static var appID: String = ""
    private static var apiKey: String = ""

    private static var eventQueue: EventQueue?
    private static var sessionManager: SessionManager?
    private static var batchSender: BatchSender?
    private static var flushScheduler: FlushScheduler?
    private static var persistenceStore: (any PersistenceStore)?
    private static var deviceInfo: DeviceInfo = DeviceInfo.collect()
    private static var userID: String?

    private static var installIDStore: InstallIDStore = InstallIDStore()

    private static var foregroundTask: Task<Void, Never>?
    private static var backgroundTask: Task<Void, Never>?

    // MARK: - Configuration

    /// Configures the SDK. Call this once before tracking any events.
    ///
    /// - Parameters:
    ///   - appID: Your application's bundle identifier or a custom ID string.
    ///   - apiKey: The API key issued for your account.
    ///   - environment: Controls whether events are sent to production, staging, or only logged locally.
    ///   - options: Fine-grained configuration. Uses sensible defaults if omitted.
    public static func configure(
        appID: String,
        apiKey: String,
        environment: PulseEnvironment = .production,
        options: PulseOptions = PulseOptions()
    ) {
        guard !isConfigured else { return }
        isConfigured = true

        Self.appID = appID
        Self.apiKey = apiKey
        Self.environment = environment
        Self.options = options
        Self.deviceInfo = DeviceInfo.collect()

        let queue = EventQueue(maxSize: options.maxQueueSize)
        let session = SessionManager()
        let scheduler = FlushScheduler(flushInterval: options.flushInterval, batchSize: options.batchSize)
        let persistence = FilePersistenceStore()

        eventQueue = queue
        sessionManager = session
        flushScheduler = scheduler
        persistenceStore = persistence

        if environment != .debug {
            let resolvedEndpoint = options.endpoint ?? URL(string: "https://api.pulseanalytics.io/v1/events")!
            let httpClient: any HTTPClient = options.supabase.map {
                SupabaseHTTPClient(projectURL: $0.projectURL, anonKey: $0.anonKey)
            } ?? URLSession.shared
            batchSender = BatchSender(
                appID: appID,
                apiKey: apiKey,
                endpoint: resolvedEndpoint,
                httpClient: httpClient,
                logLevel: options.logLevel
            )
        }

        // Wire flush handler
        let flushClosure: @Sendable () async -> Void = {
            await Pulse.flush()
        }
        Task {
            await scheduler.setFlushHandler(flushClosure)
        }

        // Load persisted queue
        Task {
            await loadPersistedQueue(into: queue, from: persistence)
            await session.startSession()
            await scheduler.start()
        }

        // Subscribe to app lifecycle notifications
        startLifecycleObserver()
    }

    // MARK: - Tracking

    /// Tracks an event.
    ///
    /// In `.debug` environment the event is printed to the console and not sent.
    ///
    /// - Parameter event: The event to track.
    public static func track(_ event: PulseEvent) {
        guard isConfigured, let queue = eventQueue, let session = sessionManager else { return }

        if environment == .debug {
            let (name, props) = EventSerializer.eventNameAndProperties(event)
            print("[PulseAnalytics DEBUG] event=\(name) properties=\(props ?? [:])")
            return
        }

        Task {
            let sessionID = await session.sessionID
            let eventID = UUID()
            let installID = await Self.installIDStore.installID()
            let payload = EventSerializer.serialize(
                event,
                eventID: eventID,
                sessionID: sessionID,
                userID: Self.userID,
                appID: Self.appID,
                installID: installID,
                deviceInfo: Self.deviceInfo
            )

            // Convert to [String: PulseValue] for storage
            let encodable = encodePayload(payload)
            let queued = QueuedEvent(eventID: eventID, payload: encodable)
            await queue.enqueue(queued)

            let count = await queue.count
            await flushScheduler?.notifyEnqueued(totalCount: count)
        }
    }

    /// Associates subsequent events with the given user ID and optional traits.
    ///
    /// Call this after a successful login. Traits are sent as a separate
    /// `identify` event.
    ///
    /// - Parameters:
    ///   - userID: A stable, non-PII identifier for the user.
    ///   - traits: Optional key-value metadata about the user (e.g. plan, role).
    public static func identify(userID: String, traits: [String: PulseValue]? = nil) {
        Self.userID = userID

        guard isConfigured, let queue = eventQueue, let session = sessionManager else { return }

        if environment == .debug {
            print("[PulseAnalytics DEBUG] identify userID=\(userID) traits=\(traits ?? [:])")
            return
        }

        Task {
            let sessionID = await session.sessionID
            let eventID = UUID()
            let installID = await Self.installIDStore.installID()
            var identifyPayload: [String: Any] = [
                "event": "identify",
                "event_id": eventID.uuidString,
                "install_id": installID.uuidString,
                "user_id": userID,
                "session_id": sessionID.uuidString,
                "app_id": Self.appID,
                "timestamp": ISO8601DateFormatter().string(from: Date()),
                "device": Self.deviceInfo.jsonDictionary()
            ]
            if let traits {
                identifyPayload["traits"] = traits.mapValues { $0.jsonValue }
            }
            let encodable = encodePayload(identifyPayload)
            let queued = QueuedEvent(eventID: eventID, payload: encodable)
            await queue.enqueue(queued)
        }
    }

    /// Clears the current user ID. Call this on logout.
    ///
    /// Subsequent events will not include a `user_id` field until
    /// ``identify(userID:traits:)`` is called again.
    public static func reset() {
        userID = nil
    }

    // MARK: - Internal flush

    /// Flushes pending events to the network immediately.
    static func flush() async {
        guard let queue = eventQueue, let sender = batchSender, let persistence = persistenceStore else { return }

        let batch = await queue.dequeue(upTo: options.batchSize)
        guard !batch.isEmpty else { return }

        let sent = await sender.send(batch)
        if !sent {
            // Re-enqueue failed events at the front (best-effort)
            for event in batch.reversed() {
                await queue.enqueue(event)
            }
        }

        // Persist remaining queue
        let remaining = await queue.allEvents
        try? await persistence.save(remaining)
    }

    // MARK: - Private helpers

    private static func loadPersistedQueue(into queue: EventQueue, from store: any PersistenceStore) async {
        guard let events = try? await store.load() else { return }
        await queue.restore(events)
    }

    private static func startLifecycleObserver() {
        foregroundTask?.cancel()
        backgroundTask?.cancel()

        let fgName = UIApplicationNotification.didBecomeActive
        foregroundTask = Task {
            for await _ in NotificationCenter.default.notifications(named: fgName) {
                await Pulse.handleForeground()
            }
        }

        let bgName = UIApplicationNotification.didEnterBackground
        backgroundTask = Task {
            for await _ in NotificationCenter.default.notifications(named: bgName) {
                await Pulse.handleBackground()
            }
        }
    }

    private static func handleForeground() async {
        track(.appForegrounded)
        await sessionManager?.startSession()
        track(.sessionStarted)
    }

    private static func handleBackground() async {
        if let duration = await sessionManager?.endSession() {
            track(.sessionEnded(duration: duration))
        }
        track(.appBackgrounded)
        await flushScheduler?.backgroundFlush()
        if let queue = eventQueue, let persistence = persistenceStore {
            let events = await queue.allEvents
            try? await persistence.save(events)
        }
    }

    // MARK: - Payload encoding helpers

    /// Converts a `[String: Any]` wire payload into `[String: PulseValue]` for queue storage.
    private static func encodePayload(_ payload: [String: Any]) -> [String: PulseValue] {
        var result: [String: PulseValue] = [:]
        for (key, value) in payload {
            switch value {
            case let v as String:
                result[key] = .string(v)
            case let v as Int:
                result[key] = .int(v)
            case let v as Double:
                result[key] = .double(v)
            case let v as Bool:
                result[key] = .bool(v)
            case is NSNull:
                result[key] = .null
            default:
                // Nested dicts (device, properties) — JSON-encode them as strings
                if let nested = value as? [String: Any],
                   let data = try? JSONSerialization.data(withJSONObject: nested),
                   let str = String(data: data, encoding: .utf8) {
                    result[key] = .string(str)
                } else if let nested = value as? [String: String],
                          let data = try? JSONSerialization.data(withJSONObject: nested),
                          let str = String(data: data, encoding: .utf8) {
                    result[key] = .string(str)
                }
            }
        }
        return result
    }
}

// MARK: - UIApplication notification name abstraction

private enum UIApplicationNotification {
    static var didBecomeActive: Notification.Name {
#if canImport(UIKit)
        return UIApplication.didBecomeActiveNotification
#else
        return Notification.Name("NSApplicationDidBecomeActiveNotification")
#endif
    }

    static var didEnterBackground: Notification.Name {
#if canImport(UIKit)
        return UIApplication.didEnterBackgroundNotification
#else
        return Notification.Name("NSApplicationDidResignActiveNotification")
#endif
    }
}
