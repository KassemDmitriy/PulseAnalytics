import Foundation

/// HTTPClient adapter that translates PulseAnalytics batch payloads into
/// Supabase PostgREST bulk-insert requests.
///
/// BatchSender produces a standard envelope:
///   { app_id, api_key, install_id, events: [...] }
///
/// This adapter unpacks that envelope, remaps each event to a flat DB row,
/// and POSTs the array to /rest/v1/events with Supabase auth headers.
/// The `resolution=ignore-duplicates` Prefer header makes retries idempotent
/// provided the table has a UNIQUE constraint on event_id.
struct SupabaseHTTPClient: HTTPClient {
    private let eventsURL: URL
    private let anonKey: String
    private let session: URLSession

    init(projectURL: URL, anonKey: String, session: URLSession = .shared) {
        self.eventsURL = projectURL
            .appendingPathComponent("rest")
            .appendingPathComponent("v1")
            .appendingPathComponent("events")
        self.anonKey = anonKey
        self.session = session
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        guard
            let body = request.httpBody,
            let batch = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
            let rawEvents = batch["events"] as? [[String: Any]],
            let installID = batch["install_id"] as? String
        else {
            throw URLError(.cannotParseResponse)
        }

        let batchAppID = batch["app_id"] as? String ?? ""

        let rows: [[String: Any]] = rawEvents.compactMap { event in
            guard
                let eventID   = event["event_id"]  as? String,
                let eventName = event["event"]      as? String,
                let sessionID = event["session_id"] as? String,
                let timestamp = event["timestamp"]  as? String
            else { return nil }

            var row: [String: Any] = [
                "event_id":   eventID,
                "event":      eventName,
                "app_id":     event["app_id"] as? String ?? batchAppID,
                "install_id": installID,
                "session_id": sessionID,
                "timestamp":  timestamp,
            ]

            if let userID = event["user_id"] as? String {
                row["user_id"] = userID
            }

            // encodePayload() may have JSON-encoded nested dicts (device, properties)
            // into strings. Parse them back so Supabase stores proper jsonb objects.
            if let device = event["device"] {
                row["device"] = parsedJSON(device)
            }
            if let props = event["properties"] {
                row["properties"] = parsedJSON(props)
            }

            return row
        }

        var supabaseRequest = URLRequest(url: eventsURL)
        supabaseRequest.httpMethod = "POST"
        supabaseRequest.setValue(anonKey,             forHTTPHeaderField: "apikey")
        supabaseRequest.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        supabaseRequest.setValue("application/json",  forHTTPHeaderField: "Content-Type")
        // return=minimal skips returning inserted rows; ignore-duplicates makes retries safe.
        supabaseRequest.setValue("return=minimal,resolution=ignore-duplicates", forHTTPHeaderField: "Prefer")
        supabaseRequest.httpBody = try JSONSerialization.data(withJSONObject: rows)

        return try await session.data(for: supabaseRequest)
    }

    /// If `value` is a JSON-encoded string, parse it back to a Foundation object.
    /// This undoes the string-encoding that encodePayload() applies to nested dicts.
    private func parsedJSON(_ value: Any) -> Any {
        guard
            let str  = value as? String,
            let data = str.data(using: .utf8),
            let obj  = try? JSONSerialization.jsonObject(with: data)
        else { return value }
        return obj
    }
}
