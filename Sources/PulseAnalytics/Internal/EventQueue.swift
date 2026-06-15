import Foundation

struct AnyCodable: Codable, @unchecked Sendable {
    let value: Any

    init(_ value: Any) { self.value = value }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() { value = NSNull(); return }
        if let int = try? container.decode(Int.self) { value = int; return }
        if let double = try? container.decode(Double.self) { value = double; return }
        if let bool = try? container.decode(Bool.self) { value = bool; return }
        if let string = try? container.decode(String.self) { value = string; return }
        if let dict = try? container.decode([String: AnyCodable].self) { value = dict; return }
        if let array = try? container.decode([AnyCodable].self) { value = array; return }
        throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported type")
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case let int as Int: try container.encode(int)
        case let double as Double: try container.encode(double)
        case let bool as Bool: try container.encode(bool)
        case let string as String: try container.encode(string)
        case let dict as [String: AnyCodable]: try container.encode(dict)
        case let array as [AnyCodable]: try container.encode(array)
        case is NSNull: try container.encodeNil()
        default:
            let context = EncodingError.Context(codingPath: container.codingPath, debugDescription: "Unsupported type")
            throw EncodingError.invalidValue(value, context)
        }
    }
}

/// A queued event entry stored in memory and persisted to disk.
struct QueuedEvent: Codable, Sendable {
    let id: UUID                // queue entry id
    let eventID: UUID           // stable per-event id for idempotency
    let payload: [String: AnyCodable] // serialized event dictionary
    let enqueuedAt: Date

    init(eventID: UUID, payload: [String: Any], enqueuedAt: Date = Date()) {
        self.id = UUID()
        self.eventID = eventID
        self.payload = payload.mapValues { value in
            // encodePayload() in Pulse.swift converts the wire dict to [String: PulseValue]
            // before passing here. Extract the JSON primitive so AnyCodable can round-trip
            // through both JSONEncoder (persistence) and JSONSerialization (network).
            if let pv = value as? PulseValue { return AnyCodable(pv.jsonValue) }
            return AnyCodable(value)
        }
        self.enqueuedAt = enqueuedAt
    }
}

/// Thread-safe, append-only in-memory event queue.
///
/// When the queue reaches `maxSize`, the **oldest** events are dropped to make
/// room for new ones — the SDK never crashes due to memory pressure.
actor EventQueue {
    private var events: [QueuedEvent] = []
    private let maxSize: Int

    /// Creates a queue with the given capacity limit.
    init(maxSize: Int) {
        self.maxSize = maxSize
    }

    /// The number of events currently in the queue.
    var count: Int { events.count }

    /// Returns all events currently held in the queue without removing them.
    var allEvents: [QueuedEvent] { events }

    /// Adds an event to the end of the queue.
    ///
    /// If the queue is at capacity, the oldest event is removed first.
    func enqueue(eventID: UUID, payload: [String: Any]) {
        let qe = QueuedEvent(eventID: eventID, payload: payload)
        if events.count >= maxSize {
            // Drop oldest — preserves newest events.
            events.removeFirst()
        }
        events.append(qe)
    }

    /// Deprecated: prefer enqueue(eventID:payload:)
    func enqueue(_ event: QueuedEvent) {
        // Preserve existing behavior by appending directly
        if events.count >= maxSize {
            events.removeFirst()
        }
        events.append(event)
    }

    /// Removes and returns up to `count` events from the front of the queue.
    func dequeue(upTo count: Int) -> [QueuedEvent] {
        let slice = Array(events.prefix(count))
        events.removeFirst(slice.count)
        return slice
    }

    /// Removes specific events by their IDs (called after successful send).
    func remove(ids: Set<UUID>) {
        events.removeAll { ids.contains($0.id) }
    }

    /// Replaces the entire queue with a restored set (used during load from disk).
    func restore(_ restored: [QueuedEvent]) {
        events = Array(restored.suffix(maxSize))
    }
}
