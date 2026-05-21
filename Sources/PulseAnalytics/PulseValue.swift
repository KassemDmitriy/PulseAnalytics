import Foundation

/// A type-safe value that can be attached to analytics event properties.
///
/// Use ``PulseValue`` as dictionary values when passing `properties` to events.
/// It conforms to all common `ExpressibleBy` literal protocols so you can write
/// idiomatic Swift literals directly in your call sites:
///
/// ```swift
/// Pulse.track(.featureUsed(.search, properties: [
///     "query": "swift concurrency",
///     "results_count": 42,
///     "is_premium": true
/// ]))
/// ```
public enum PulseValue: Sendable, Codable, Equatable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case null

    // MARK: - Codable

    private enum CodingKeys: String, CodingKey {
        case type, value
    }

    private enum ValueType: String, Codable {
        case string, int, double, bool, null
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(ValueType.self, forKey: .type)
        switch type {
        case .string:
            self = .string(try container.decode(String.self, forKey: .value))
        case .int:
            self = .int(try container.decode(Int.self, forKey: .value))
        case .double:
            self = .double(try container.decode(Double.self, forKey: .value))
        case .bool:
            self = .bool(try container.decode(Bool.self, forKey: .value))
        case .null:
            self = .null
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .string(let v):
            try container.encode(ValueType.string, forKey: .type)
            try container.encode(v, forKey: .value)
        case .int(let v):
            try container.encode(ValueType.int, forKey: .type)
            try container.encode(v, forKey: .value)
        case .double(let v):
            try container.encode(ValueType.double, forKey: .type)
            try container.encode(v, forKey: .value)
        case .bool(let v):
            try container.encode(ValueType.bool, forKey: .type)
            try container.encode(v, forKey: .value)
        case .null:
            try container.encode(ValueType.null, forKey: .type)
        }
    }

    // MARK: - JSON primitive value

    /// Returns the underlying value as a JSON-compatible primitive (String, Int, Double, Bool, or NSNull).
    var jsonValue: Any {
        switch self {
        case .string(let v): return v
        case .int(let v): return v
        case .double(let v): return v
        case .bool(let v): return v
        case .null: return NSNull()
        }
    }
}

// MARK: - ExpressibleBy literals

extension PulseValue: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self = .string(value)
    }
}

extension PulseValue: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: Int) {
        self = .int(value)
    }
}

extension PulseValue: ExpressibleByFloatLiteral {
    public init(floatLiteral value: Double) {
        self = .double(value)
    }
}

extension PulseValue: ExpressibleByBooleanLiteral {
    public init(booleanLiteral value: Bool) {
        self = .bool(value)
    }
}

extension PulseValue: ExpressibleByNilLiteral {
    public init(nilLiteral: ()) {
        self = .null
    }
}
