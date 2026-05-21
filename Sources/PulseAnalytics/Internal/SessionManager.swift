import Foundation

/// Manages session lifecycle and provides the current session ID.
///
/// A session begins on ``configure()`` or when the app returns to the foreground,
/// and ends when the app enters the background. Every event is stamped with the
/// current ``sessionID``.
actor SessionManager {
    private(set) var sessionID: UUID = UUID()
    private(set) var sessionStartDate: Date = Date()

    /// Starts a new session, replacing the previous session ID.
    func startSession() {
        sessionID = UUID()
        sessionStartDate = Date()
    }

    /// Ends the current session and returns its duration in seconds.
    @discardableResult
    func endSession() -> TimeInterval {
        let duration = Date().timeIntervalSince(sessionStartDate)
        return duration
    }

    /// The duration of the current session so far.
    var currentDuration: TimeInterval {
        Date().timeIntervalSince(sessionStartDate)
    }
}
