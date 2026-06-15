import Testing
import Foundation
@testable import PulseAnalytics

@Suite("PulseOptions", .serialized)
@MainActor
struct PulseOptionsTests {

    @Test("Lifecycle event tracking defaults to enabled")
    func lifecycleTrackingDefaultsToEnabled() {
        let options = PulseOptions()
        #expect(options.tracksLifecycleEvents)
    }

    @Test("Lifecycle event tracking can be disabled")
    func lifecycleTrackingCanBeDisabled() {
        let options = PulseOptions(tracksLifecycleEvents: false)
        #expect(!options.tracksLifecycleEvents)
    }

    @Test("Configure does not start lifecycle observers when disabled")
    func configureSkipsLifecycleObserversWhenDisabled() async {
        await Pulse.resetForTesting()

        let options = PulseOptions(
            batchSize: 100,
            flushInterval: 3_600,
            tracksLifecycleEvents: false
        )

        Pulse.configure(
            appID: "com.test.lifecycle-disabled",
            apiKey: "test",
            environment: .production,
            options: options
        )

        #expect(!Pulse.isObservingLifecycleEvents)
        await Pulse.resetForTesting()
    }

    @Test("Explicit events still enqueue when lifecycle tracking is disabled")
    func explicitEventsStillEnqueueWhenLifecycleTrackingIsDisabled() async throws {
        await Pulse.resetForTesting()

        let options = PulseOptions(
            batchSize: 100,
            flushInterval: 3_600,
            tracksLifecycleEvents: false
        )

        Pulse.configure(
            appID: "com.test.explicit-events",
            apiKey: "test",
            environment: .production,
            options: options
        )

        try await Task.sleep(nanoseconds: 50_000_000)
        let initialCount = await Pulse.queuedEventCount

        Pulse.track(.custom(name: "mission_started", properties: nil))

        try await Task.sleep(nanoseconds: 50_000_000)
        let finalCount = await Pulse.queuedEventCount

        #expect(finalCount == initialCount + 1)
        await Pulse.resetForTesting()
    }
}
