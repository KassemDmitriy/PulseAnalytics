import Testing
import Foundation
@testable import PulseAnalytics

@Suite("PersistenceStore")
struct PersistenceStoreTests {

    private func makeTempStore() -> FilePersistenceStore {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let fileURL = tempDir.appendingPathComponent("test_queue.json")
        return FilePersistenceStore(fileURL: fileURL)
    }

    private func makeEvent(index: Int) -> QueuedEvent {
        QueuedEvent(eventID: UUID(), payload: ["index": index, "name": "event_\(index)"])
    }

    @Test("Save and load restores all events")
    func saveAndLoad() async throws {
        let store = makeTempStore()
        let events = [makeEvent(index: 1), makeEvent(index: 2), makeEvent(index: 3)]

        try await store.save(events)
        let loaded = try await store.load()

        #expect(loaded.count == events.count)
        for (original, restored) in zip(events, loaded) {
            #expect(original.id == restored.id)
            #expect(original.payload["index"]?.value as? Int == restored.payload["index"]?.value as? Int)
        }
    }

    @Test("Load on missing file returns empty array")
    func loadMissingFile() async throws {
        let store = makeTempStore()
        let loaded = try await store.load()
        #expect(loaded.isEmpty)
    }

    @Test("Save empty array clears the store")
    func saveEmpty() async throws {
        let store = makeTempStore()
        try await store.save([makeEvent(index: 1)])
        try await store.save([])
        let loaded = try await store.load()
        #expect(loaded.isEmpty)
    }

    @Test("Overwrite replaces previous contents")
    func overwrite() async throws {
        let store = makeTempStore()
        try await store.save([makeEvent(index: 1), makeEvent(index: 2)])
        try await store.save([makeEvent(index: 99)])
        let loaded = try await store.load()
        #expect(loaded.count == 1)
        #expect(loaded[0].payload["index"]?.value as? Int == 99)
    }

    @Test("Payload values survive round-trip correctly")
    func payloadRoundTrip() async throws {
        let store = makeTempStore()
        let event = QueuedEvent(eventID: UUID(), payload: [
            "str": "hello",
            "num": 42,
            "dbl": 3.14,
            "bool": true,
            "nil": NSNull()
        ])
        try await store.save([event])
        let loaded = try await store.load()
        let restored = loaded[0]
        #expect(restored.payload["str"]?.value as? String == "hello")
        #expect(restored.payload["num"]?.value as? Int == 42)
        #expect(restored.payload["dbl"]?.value as? Double == 3.14)
        #expect(restored.payload["bool"]?.value as? Bool == true)
        #expect(restored.payload["nil"]?.value is NSNull)
    }
}
