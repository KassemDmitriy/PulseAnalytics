import Testing
import Foundation
@testable import PulseAnalytics

// MARK: - Mock HTTP client

final class MockHTTPClient: HTTPClient, @unchecked Sendable {
    var statusCode: Int
    var shouldThrow: Bool
    private(set) var callCount = 0

    init(statusCode: Int = 200, shouldThrow: Bool = false) {
        self.statusCode = statusCode
        self.shouldThrow = shouldThrow
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        callCount += 1
        if shouldThrow {
            throw URLError(.notConnectedToInternet)
        }
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: nil
        )!
        return (Data(), response)
    }
}

// MARK: - Tests

@Suite("BatchSender")
struct BatchSenderTests {

    private let endpoint = URL(string: "https://api.example.com/events")!

    private func makeEvent(id: Int = 0) -> QueuedEvent {
        QueuedEvent(payload: ["event": .string("test"), "index": .int(id)])
    }

    @Test("200 response returns true (success)")
    func successReturnsTrue() async {
        let client = MockHTTPClient(statusCode: 200)
        let sender = BatchSender(appID: "com.test", apiKey: "key", endpoint: endpoint, httpClient: client)
        let events = [makeEvent(id: 1)]
        let result = await sender.send(events)
        #expect(result == true)
    }

    @Test("500 response returns false after all retries")
    func serverErrorReturnsFalse() async {
        let client = MockHTTPClient(statusCode: 500)
        let sender = BatchSender(appID: "com.test", apiKey: "key", endpoint: endpoint, httpClient: client)
        let events = [makeEvent(id: 1)]
        let result = await sender.send(events)
        #expect(result == false)
        // Should have retried exactly maxRetries (3) times
        #expect(client.callCount == 3)
    }

    @Test("Network error returns false after all retries")
    func networkErrorReturnsFalse() async {
        let client = MockHTTPClient(shouldThrow: true)
        let sender = BatchSender(appID: "com.test", apiKey: "key", endpoint: endpoint, httpClient: client)
        let events = [makeEvent(id: 1)]
        let result = await sender.send(events)
        #expect(result == false)
        #expect(client.callCount == 3)
    }

    @Test("Empty batch returns true without making any request")
    func emptyBatch() async {
        let client = MockHTTPClient()
        let sender = BatchSender(appID: "com.test", apiKey: "key", endpoint: endpoint, httpClient: client)
        let result = await sender.send([])
        #expect(result == true)
        #expect(client.callCount == 0)
    }

    @Test("Success on second attempt after one failure")
    func successOnSecondAttempt() async {
        final class FlakyClient: HTTPClient, @unchecked Sendable {
            var callCount = 0
            func data(for request: URLRequest) async throws -> (Data, URLResponse) {
                callCount += 1
                let code = callCount == 1 ? 500 : 200
                let response = HTTPURLResponse(
                    url: request.url!,
                    statusCode: code,
                    httpVersion: nil,
                    headerFields: nil
                )!
                return (Data(), response)
            }
        }

        let client = FlakyClient()
        let sender = BatchSender(appID: "com.test", apiKey: "key", endpoint: endpoint, httpClient: client)
        let result = await sender.send([makeEvent()])
        #expect(result == true)
        #expect(client.callCount == 2)
    }
}
