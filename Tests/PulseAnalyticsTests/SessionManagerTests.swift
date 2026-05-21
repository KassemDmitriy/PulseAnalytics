import Testing
import Foundation
@testable import PulseAnalytics

@Suite("SessionManager")
struct SessionManagerTests {

    @Test("New SessionManager has a non-nil session ID")
    func initialSessionID() async {
        let manager = SessionManager()
        let id = await manager.sessionID
        // UUID is never nil, but we verify it's a valid UUID (not all-zeros)
        #expect(id != UUID(uuidString: "00000000-0000-0000-0000-000000000000"))
    }

    @Test("startSession generates a new session ID")
    func startSessionGeneratesNewID() async {
        let manager = SessionManager()
        let firstID = await manager.sessionID
        await manager.startSession()
        let secondID = await manager.sessionID
        #expect(firstID != secondID)
    }

    @Test("endSession returns a positive duration")
    func endSessionReturnsDuration() async throws {
        let manager = SessionManager()
        await manager.startSession()
        try await Task.sleep(nanoseconds: 10_000_000) // 10ms
        let duration = await manager.endSession()
        #expect(duration > 0)
    }

    @Test("currentDuration increases over time")
    func durationIncreases() async throws {
        let manager = SessionManager()
        await manager.startSession()
        let d1 = await manager.currentDuration
        try await Task.sleep(nanoseconds: 20_000_000) // 20ms
        let d2 = await manager.currentDuration
        #expect(d2 > d1)
    }

    @Test("Session IDs from consecutive sessions are unique")
    func consecutiveSessionsUniqueIDs() async {
        let manager = SessionManager()
        var ids = Set<UUID>()
        for _ in 0..<5 {
            await manager.startSession()
            let id = await manager.sessionID
            ids.insert(id)
        }
        #expect(ids.count == 5)
    }

    @Test("EventSerializer attaches session ID to serialized events")
    func sessionIDAttachedToEvent() async {
        let manager = SessionManager()
        await manager.startSession()
        let sessionID = await manager.sessionID

        let device = DeviceInfo(
            osVersion: "17.0",
            model: "iPhone",
            locale: "en_US",
            timezone: "UTC",
            appVersion: "1.0",
            appBuild: "1"
        )

        let dict = EventSerializer.serialize(
            .screenViewed(PulseScreen("home")),
            sessionID: sessionID,
            userID: nil,
            appID: "com.test",
            deviceInfo: device
        )

        #expect(dict["session_id"] as? String == sessionID.uuidString)
    }
}
