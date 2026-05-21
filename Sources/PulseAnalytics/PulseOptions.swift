import Foundation

/// The environment in which the SDK operates.
///
/// - ``production``: Events are sent to the production endpoint.
/// - ``staging``: Events are sent to the staging endpoint.
/// - ``debug``: Events are printed to the console only — nothing is sent to the network.
public enum PulseEnvironment: Sendable {
    case production
    case staging
    /// Prints events to the console instead of sending them. Useful during development.
    case debug
}

/// Supabase project credentials for direct table insertion.
///
/// Set this on ``PulseOptions/supabase`` to route events straight into your
/// Supabase `events` table via the PostgREST API — no Edge Function or CLI required.
///
/// ```swift
/// var options = PulseOptions()
/// options.supabase = SupabaseConfig(
///     projectURL: URL(string: "https://xyz.supabase.co")!,
///     anonKey: "your-anon-key"
/// )
/// Pulse.configure(appID: "com.example.app", apiKey: "unused", environment: .production, options: options)
/// ```
public struct SupabaseConfig: Sendable {
    /// Your Supabase project URL, e.g. `https://abcxyz.supabase.co`.
    public let projectURL: URL
    /// The anon (public) API key from your Supabase project settings → API.
    public let anonKey: String

    public init(projectURL: URL, anonKey: String) {
        self.projectURL = projectURL
        self.anonKey = anonKey
    }
}

/// Configuration options for ``Pulse``.
///
/// All properties have sensible defaults. Override only what you need:
///
/// ```swift
/// var options = PulseOptions()
/// options.batchSize = 10
/// options.flushInterval = 15
/// options.logLevel = .verbose
/// Pulse.configure(appID: "com.example.app", apiKey: "key", environment: .production, options: options)
/// ```
public struct PulseOptions: Sendable {
    /// Number of events to accumulate before triggering a flush. Default: `20`.
    public var batchSize: Int

    /// Interval in seconds between automatic flushes. Default: `30`.
    public var flushInterval: TimeInterval

    /// Maximum number of events held in memory before the oldest are dropped. Default: `500`.
    public var maxQueueSize: Int

    /// Verbosity of SDK log output. Default: ``LogLevel/none``.
    public var logLevel: LogLevel

    /// Override the default endpoint URL. When `nil` the SDK uses its built-in endpoint. Default: `nil`.
    /// Ignored when ``supabase`` is set.
    public var endpoint: URL?

    /// Supabase credentials. When set, events are sent directly to your Supabase `events` table.
    /// Overrides ``endpoint``. Default: `nil`.
    public var supabase: SupabaseConfig?

    /// Creates a `PulseOptions` value with all defaults applied.
    public init(
        batchSize: Int = 20,
        flushInterval: TimeInterval = 30,
        maxQueueSize: Int = 500,
        logLevel: LogLevel = .none,
        endpoint: URL? = nil,
        supabase: SupabaseConfig? = nil
    ) {
        self.batchSize = batchSize
        self.flushInterval = flushInterval
        self.maxQueueSize = maxQueueSize
        self.logLevel = logLevel
        self.endpoint = endpoint
        self.supabase = supabase
    }
}

/// Controls how much the SDK logs to the console.
public enum LogLevel: Sendable {
    /// No logging. Default.
    case none
    /// Logs errors only.
    case error
    /// Logs errors and informational messages.
    case verbose
}
