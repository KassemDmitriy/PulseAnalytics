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
        QueuedEvent(eventID: UUID(), payload: ["event": "test", "index": id])
    }

    @Test("200 response returns delivered")
    func successReturnsDelivered() async {
        let client = MockHTTPClient(statusCode: 200)
        let sender = BatchSender(appID: "com.test", apiKey: "key", endpoint: endpoint, httpClient: client)
        let result = await sender.send([makeEvent(id: 1)])
        #expect(result == .delivered)
        #expect(client.callCount == 1)
    }

    @Test("409 returns delivered without retrying (idempotent duplicate)")
    func conflictReturnsDelivered() async {
        let client = MockHTTPClient(statusCode: 409)
        let sender = BatchSender(appID: "com.test", apiKey: "key", endpoint: endpoint, httpClient: client)
        let result = await sender.send([makeEvent()])
        #expect(result == .delivered)
        #expect(client.callCount == 1)
    }

    @Test("400 returns permanentFailure without retrying")
    func badRequestReturnsPermanentFailure() async {
        let client = MockHTTPClient(statusCode: 400)
        let sender = BatchSender(appID: "com.test", apiKey: "key", endpoint: endpoint, httpClient: client)
        let result = await sender.send([makeEvent()])
        #expect(result == .permanentFailure)
        #expect(client.callCount == 1)
    }

    @Test("401 returns permanentFailure without retrying")
    func unauthorizedReturnsPermanentFailure() async {
        let client = MockHTTPClient(statusCode: 401)
        let sender = BatchSender(appID: "com.test", apiKey: "key", endpoint: endpoint, httpClient: client)
        let result = await sender.send([makeEvent()])
        #expect(result == .permanentFailure)
        #expect(client.callCount == 1)
    }

    @Test("403 returns permanentFailure without retrying")
    func forbiddenReturnsPermanentFailure() async {
        let client = MockHTTPClient(statusCode: 403)
        let sender = BatchSender(appID: "com.test", apiKey: "key", endpoint: endpoint, httpClient: client)
        let result = await sender.send([makeEvent()])
        #expect(result == .permanentFailure)
        #expect(client.callCount == 1)
    }

    @Test("429 returns retryableFailure after all retries")
    func rateLimitedReturnsRetryableFailure() async {
        let client = MockHTTPClient(statusCode: 429)
        let sender = BatchSender(appID: "com.test", apiKey: "key", endpoint: endpoint, httpClient: client)
        let result = await sender.send([makeEvent()])
        #expect(result == .retryableFailure)
        #expect(client.callCount == 3)
    }

    @Test("500 response returns retryableFailure after all retries")
    func serverErrorReturnsRetryableFailure() async {
        let client = MockHTTPClient(statusCode: 500)
        let sender = BatchSender(appID: "com.test", apiKey: "key", endpoint: endpoint, httpClient: client)
        let result = await sender.send([makeEvent(id: 1)])
        #expect(result == .retryableFailure)
        #expect(client.callCount == 3)
    }

    @Test("Network error returns retryableFailure after all retries")
    func networkErrorReturnsRetryableFailure() async {
        let client = MockHTTPClient(shouldThrow: true)
        let sender = BatchSender(appID: "com.test", apiKey: "key", endpoint: endpoint, httpClient: client)
        let result = await sender.send([makeEvent(id: 1)])
        #expect(result == .retryableFailure)
        #expect(client.callCount == 3)
    }

    @Test("Empty batch returns delivered without making any request")
    func emptyBatch() async {
        let client = MockHTTPClient()
        let sender = BatchSender(appID: "com.test", apiKey: "key", endpoint: endpoint, httpClient: client)
        let result = await sender.send([])
        #expect(result == .delivered)
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
        #expect(result == .delivered)
        #expect(client.callCount == 2)
    }
}
