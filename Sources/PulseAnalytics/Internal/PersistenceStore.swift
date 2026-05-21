import Foundation

/// Persistence abstraction for the event queue.
///
/// Conform to this protocol to provide a custom storage backend.
/// The default implementation is ``FilePersistenceStore``.
protocol PersistenceStore: Actor {
    /// Persists the given events to storage.
    func save(_ events: [QueuedEvent]) async throws
    /// Loads previously persisted events from storage.
    func load() async throws -> [QueuedEvent]
}

/// A file-backed persistence store that writes the event queue as JSON
/// to the application's **Caches** directory.
///
/// Caches is preferred over Documents because:
/// - It is excluded from iCloud backup.
/// - The OS may purge it under storage pressure, which is acceptable for
///   analytics queues.
///
/// This implementation writes to a temporary file and then atomically replaces
/// the target file to ensure atomic writes. On loading, if decoding fails,
/// it attempts partial recovery by decoding individual events from the file.
actor FilePersistenceStore: PersistenceStore {
    private let fileURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let fm = FileManager.default
    private let tempSuffix = ".tmp"

    /// Creates a store writing to the given file URL.
    ///
    /// Defaults to `<Caches>/pulse_queue.json`.
    init(fileURL: URL? = nil) {
        if let fileURL {
            self.fileURL = fileURL
        } else {
            let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            self.fileURL = caches.appendingPathComponent("pulse_queue.json")
        }
        encoder.outputFormatting = []
        // decoder defaults used, no custom dateDecodingStrategy applied.
    }

    func save(_ events: [QueuedEvent]) async throws {
        let data = try encoder.encode(events)
        let tmpURL = fileURL.appendingPathExtension("tmp")

        try fm.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: tmpURL, options: .completeFileProtectionUnlessOpen)
        _ = try fm.replaceItemAt(fileURL, withItemAt: tmpURL)
    }

    func load() async throws -> [QueuedEvent] {
        guard fm.fileExists(atPath: fileURL.path) else {
            return []
        }
        let data = try Data(contentsOf: fileURL)
        do {
            return try decoder.decode([QueuedEvent].self, from: data)
        } catch {
            // Logging stub: Detected corruption, attempting partial recovery...
            var salvagedEvents: [QueuedEvent] = []

            // Attempt partial recovery by element-wise decoding from JSON array
            do {
                let jsonObject = try JSONSerialization.jsonObject(with: data)
                if let jsonArray = jsonObject as? [Any] {
                    for element in jsonArray {
                        do {
                            let elementData = try JSONSerialization.data(withJSONObject: element)
                            let event = try decoder.decode(QueuedEvent.self, from: elementData)
                            salvagedEvents.append(event)
                        } catch {
                            // Logging stub: Failed to decode element during partial recovery, skipping element.
                        }
                    }
                    // If some events were successfully salvaged, return them.
                    if !salvagedEvents.isEmpty {
                        return salvagedEvents
                    }
                }
            } catch {
                // Logging stub: JSONSerialization failed, will attempt line-delimited JSON recovery.
            }

            // Attempt line-delimited JSON recovery
            let stringData = String(decoding: data, as: UTF8.self)
            salvagedEvents = []
            for line in stringData.components(separatedBy: .newlines) where !line.isEmpty {
                if let lineData = line.data(using: .utf8) {
                    do {
                        let event = try decoder.decode(QueuedEvent.self, from: lineData)
                        salvagedEvents.append(event)
                    } catch {
                        // Logging stub: Failed to decode line during partial recovery, skipping line.
                    }
                }
            }
            return salvagedEvents
        }
    }
}
