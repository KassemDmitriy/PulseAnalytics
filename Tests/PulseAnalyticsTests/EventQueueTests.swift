import Testing
import Foundation
@testable import PulseAnalytics

@Suite("EventQueue")
struct EventQueueTests {

    private func makeEvent(id: Int = 0) -> QueuedEvent {
        QueuedEvent(eventID: UUID(), payload: ["index": id])
    }

    @Test("Enqueue and dequeue returns events in FIFO order")
    func enqueueDequeue() async {
        let queue = EventQueue(maxSize: 10)
        await queue.enqueue(makeEvent(id: 1))
        await queue.enqueue(makeEvent(id: 2))
        await queue.enqueue(makeEvent(id: 3))

        let batch = await queue.dequeue(upTo: 2)
        #expect(batch.count == 2)
        #expect(batch[0].payload["index"]?.value as? Int == 1)
        #expect(batch[1].payload["index"]?.value as? Int == 2)
        let remaining = await queue.count
        #expect(remaining == 1)
    }

    @Test("Dequeue more than available returns only available")
    func dequeueMore() async {
        let queue = EventQueue(maxSize: 10)
        await queue.enqueue(makeEvent(id: 1))

        let batch = await queue.dequeue(upTo: 100)
        #expect(batch.count == 1)
        let remaining = await queue.count
        #expect(remaining == 0)
    }

    @Test("Overflow drops oldest events, not newest")
    func overflowDropsOldest() async {
        let maxSize = 3
        let queue = EventQueue(maxSize: maxSize)

        // Fill queue to capacity
        for i in 1...3 {
            await queue.enqueue(makeEvent(id: i))
        }

        // Enqueue one more — should drop id=1
        await queue.enqueue(makeEvent(id: 4))

        let count = await queue.count
        #expect(count == maxSize)

        let all = await queue.allEvents
        let ids = all.compactMap { $0.payload["index"]?.value as? Int }
        #expect(!ids.contains(1), "Oldest event (id=1) should have been dropped")
        #expect(ids.contains(4), "Newest event (id=4) should be present")
    }

    @Test("Remove by IDs removes correct events")
    func removeByIDs() async {
        let queue = EventQueue(maxSize: 10)
        await queue.enqueue(makeEvent(id: 1))
        await queue.enqueue(makeEvent(id: 2))

        let all = await queue.allEvents
        let firstID = all[0].id

        await queue.remove(ids: [firstID])
        let remaining = await queue.count
        #expect(remaining == 1)
    }

    @Test("Restore replaces queue contents")
    func restore() async {
        let queue = EventQueue(maxSize: 10)
        await queue.enqueue(makeEvent(id: 1))

        let restored = [makeEvent(id: 10), makeEvent(id: 20)]
        await queue.restore(restored)

        let count = await queue.count
        #expect(count == 2)
        let all = await queue.allEvents
        #expect(all[0].payload["index"]?.value as? Int == 10)
    }

    @Test("Restore respects maxSize")
    func restoreRespectsMaxSize() async {
        let queue = EventQueue(maxSize: 2)
        let events = (1...5).map { makeEvent(id: $0) }
        await queue.restore(events)

        let count = await queue.count
        #expect(count == 2)
    }
}
