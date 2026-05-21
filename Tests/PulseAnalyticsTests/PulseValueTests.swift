import Testing
import Foundation
@testable import PulseAnalytics

@Suite("PulseValue")
struct PulseValueTests {

    @Test("String literal creates .string case")
    func stringLiteral() {
        let value: PulseValue = "hello"
        #expect(value == .string("hello"))
    }

    @Test("Integer literal creates .int case")
    func integerLiteral() {
        let value: PulseValue = 42
        #expect(value == .int(42))
    }

    @Test("Float literal creates .double case")
    func floatLiteral() {
        let value: PulseValue = 3.14
        #expect(value == .double(3.14))
    }

    @Test("Boolean literal true creates .bool(true)")
    func boolLiteralTrue() {
        let value: PulseValue = true
        #expect(value == .bool(true))
    }

    @Test("Boolean literal false creates .bool(false)")
    func boolLiteralFalse() {
        let value: PulseValue = false
        #expect(value == .bool(false))
    }

    @Test("Nil literal creates .null case")
    func nilLiteral() {
        let value: PulseValue = nil
        #expect(value == .null)
    }

    @Test("jsonValue returns correct primitive for string")
    func jsonValueString() {
        let value = PulseValue.string("test")
        #expect(value.jsonValue as? String == "test")
    }

    @Test("jsonValue returns correct primitive for int")
    func jsonValueInt() {
        let value = PulseValue.int(7)
        #expect(value.jsonValue as? Int == 7)
    }

    @Test("jsonValue returns correct primitive for double")
    func jsonValueDouble() {
        let value = PulseValue.double(1.5)
        #expect(value.jsonValue as? Double == 1.5)
    }

    @Test("jsonValue returns correct primitive for bool")
    func jsonValueBool() {
        let value = PulseValue.bool(true)
        #expect(value.jsonValue as? Bool == true)
    }

    @Test("jsonValue returns NSNull for null")
    func jsonValueNull() {
        let value = PulseValue.null
        #expect(value.jsonValue is NSNull)
    }

    @Test("Codable round-trip preserves all cases")
    func codableRoundTrip() throws {
        let values: [PulseValue] = [
            .string("abc"),
            .int(99),
            .double(2.71),
            .bool(false),
            .null
        ]
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        for original in values {
            let data = try encoder.encode(original)
            let decoded = try decoder.decode(PulseValue.self, from: data)
            #expect(decoded == original)
        }
    }

    @Test("Dictionary literal with mixed PulseValue types compiles and is correct")
    func dictionaryLiterals() {
        let props: [String: PulseValue] = [
            "screen": "home",
            "count": 3,
            "score": 9.5,
            "enabled": true,
            "removed": nil
        ]
        #expect(props["screen"] == .string("home"))
        #expect(props["count"] == .int(3))
        #expect(props["score"] == .double(9.5))
        #expect(props["enabled"] == .bool(true))
        #expect(props["removed"] == .null)
    }
}
