import Foundation

/// Coordinates when the event queue should be flushed to the network.
///
/// Three triggers:
/// 1. **Timer**: fires every `flushInterval` seconds.
/// 2. **Count**: fires immediately when the queue reaches `batchSize`.
/// 3. **Background**: fires when the app enters the background (5-second deadline).
actor FlushScheduler {
    private let flushInterval: TimeInterval
    private let batchSize: Int
    private var timerTask: Task<Void, Never>?
    private var flushHandler: (@Sendable () async -> Void)?

    init(flushInterval: TimeInterval, batchSize: Int) {
        self.flushInterval = flushInterval
        self.batchSize = batchSize
    }

    /// Sets the async callback that will be invoked on each flush trigger.
    func setFlushHandler(_ handler: @escaping @Sendable () async -> Void) {
        self.flushHandler = handler
    }

    /// Starts the recurring timer-based flush loop.
    func start() {
        timerTask?.cancel()
        timerTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                let interval = self.flushInterval
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                guard !Task.isCancelled else { break }
                await self.triggerFlush()
            }
        }
    }

    /// Stops the timer-based flush loop.
    func stop() {
        timerTask?.cancel()
        timerTask = nil
    }

    /// Notifies the scheduler that `count` new events have been enqueued.
    ///
    /// If `count` reaches `batchSize`, a flush is triggered immediately.
    func notifyEnqueued(totalCount: Int) async {
        if totalCount >= batchSize {
            await triggerFlush()
        }
    }

    /// Triggers an immediate synchronous-style flush with a 5-second deadline.
    ///
    /// Called on app background to ensure events are sent before the process suspends.
    func backgroundFlush() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { [weak self] in
                await self?.triggerFlush()
            }
            group.addTask {
                try? await Task.sleep(nanoseconds: 5_000_000_000)
            }
            await group.next()
            group.cancelAll()
        }
    }

    private func triggerFlush() async {
        await flushHandler?()
    }
}
