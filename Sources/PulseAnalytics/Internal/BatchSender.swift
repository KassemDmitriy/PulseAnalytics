import Foundation

/// Abstraction over URLSession for testability.
///
/// The default implementation uses `URLSession.shared`.
protocol HTTPClient: Sendable {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: HTTPClient {}

/// Sends batches of events to the configured endpoint.
///
/// On success, events are removed from the queue.
/// On failure, events are retained and the sender applies jittered exponential backoff
/// (1s → ~0.8-1.2s → 2s → ~1.6-2.4s → 4s → … → 32s max) for up to 3 retry attempts per batch.
/// Requests are classified as fatal (do not retry) or retryable errors accordingly.
actor BatchSender {
    private let appID: String
    private let apiKey: String
    private let endpoint: URL
    private let httpClient: any HTTPClient
    private let logLevel: LogLevel
    private let installIDStore: InstallIDStore

    private var isSending = false

    private static let maxRetries = 3
    private static let maxBackoffSeconds: Double = 32

    init(
        appID: String,
        apiKey: String,
        endpoint: URL,
        httpClient: any HTTPClient = URLSession.shared,
        logLevel: LogLevel = .none,
        installIDStore: InstallIDStore = InstallIDStore()
    ) {
        self.appID = appID
        self.apiKey = apiKey
        self.endpoint = endpoint
        self.httpClient = httpClient
        self.logLevel = logLevel
        self.installIDStore = installIDStore
    }

    /// Attempts to send the given events to the endpoint.
    ///
    /// - Returns: `true` if the batch was accepted by the server, `false` otherwise.
    ///   On failure the caller is responsible for retaining the events in the queue.
    @discardableResult
    func send(_ events: [QueuedEvent]) async -> Bool {
        guard !events.isEmpty else { return true }

        if isSending {
            log("Concurrent send attempt detected, skipping this send.", level: .verbose)
            return false
        }

        isSending = true
        defer { isSending = false }

        var attempt = 0
        while attempt < Self.maxRetries {
            do {
                let success = try await attemptSend(events)
                if success {
                    return true
                }
                // If attemptSend returns false (should never happen with current logic), treat as retryable
            } catch let error as SendError {
                switch error {
                case .fatal(let status):
                    log("Batch send fatal error (HTTP \(status)) — will not retry.", level: .error)
                    return false
                case .retryable:
                    log("Batch send retryable error (attempt \(attempt + 1)) — will retry.", level: .error)
                }
            } catch {
                log("Batch send error (attempt \(attempt + 1)): \(error)", level: .error)
            }

            attempt += 1
            if attempt < Self.maxRetries {
                let base = min(pow(2.0, Double(attempt - 1)), Self.maxBackoffSeconds)
                let jitter = base * Double.random(in: -0.2...0.2)
                let delay = max(0, base + jitter)
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }

        log("Batch send failed after \(Self.maxRetries) attempts — keeping \(events.count) events in queue.", level: .error)
        return false
    }

    // MARK: - Private

    private enum SendError: Error {
        case retryable
        case fatal(Int)
    }

    private func attemptSend(_ events: [QueuedEvent]) async throws -> Bool {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")

        let installID = await installIDStore.installID()
        // Unwrap AnyCodable.value so JSONSerialization receives Foundation-compatible types.
        let eventPayloads = events.map { event -> [String: Any] in
            event.payload.mapValues { $0.value }
        }
        let bodyDict = EventSerializer.makeBatchBody(appID: appID, apiKey: apiKey, installID: installID, events: eventPayloads)

        request.httpBody = try JSONSerialization.data(withJSONObject: bodyDict)

        do {
            let (_, response) = try await httpClient.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw SendError.retryable
            }

            let statusCode = httpResponse.statusCode
            switch statusCode {
            case 200...299:
                log("Batch sent (\(events.count) events) — HTTP \(statusCode)", level: .verbose)
                return true
            case 400, 401, 403:
                log("Batch send fatal HTTP error \(statusCode)", level: .error)
                throw SendError.fatal(statusCode)
            case 429, 500...599:
                log("Batch send retryable HTTP error \(statusCode)", level: .error)
                throw SendError.retryable
            default:
                log("Batch send unexpected HTTP error \(statusCode)", level: .error)
                throw SendError.retryable
            }
        } catch {
            if (error as? URLError) != nil {
                log("Batch send network error: \(error)", level: .error)
                throw SendError.retryable
            }
            throw error
        }
    }

    private func log(_ message: String, level: LogLevel) {
        switch (logLevel, level) {
        case (.verbose, _), (.error, .error):
            print("[PulseAnalytics] \(message)")
        default:
            break
        }
    }
}
