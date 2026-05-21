# Task: Create PulseAnalytics Swift Package

## Status
- [x] Planned
- [ ] In Progress
- [ ] Complete

## Goal
Build a production-ready, typed analytics SDK as a Swift Package targeting iOS 16+, Swift 6 strict concurrency, with batched event delivery, offline persistence, and session management.

## Scope

**In scope:**
- All public API types (Pulse, PulseEvent, PulseValue, PulseScreen, PulseFeature, PulseOptions, PulseEnvironment)
- Internal actors: EventQueue, BatchSender, SessionManager, FlushScheduler, PersistenceStore (default impl)
- Pure helpers: EventSerializer, DeviceInfo
- Complete test suite using Swift Testing
- README.md with wire format reference
- PrivacyInfo.xcprivacy

**Out of scope:**
- SwiftUI view helpers
- macOS/tvOS/watchOS support
- Real backend server

---

## Files to Create / Modify

| File | Action | Purpose |
|------|--------|---------|
| `Package.swift` | modify | Add iOS 16 platform, test target, resource for PrivacyInfo |
| `Sources/PulseAnalytics/Pulse.swift` | create | Public entry point — `@MainActor` class with configure/track/identify/reset |
| `Sources/PulseAnalytics/PulseEvent.swift` | create | Exhaustive typed event enum |
| `Sources/PulseAnalytics/PulseValue.swift` | create | Type-safe property value enum + ExpressibleBy literal conformances |
| `Sources/PulseAnalytics/PulseScreen.swift` | create | RawRepresentable screen type |
| `Sources/PulseAnalytics/PulseFeature.swift` | create | RawRepresentable feature type |
| `Sources/PulseAnalytics/PulseOptions.swift` | create | Configuration struct + PulseEnvironment enum |
| `Sources/PulseAnalytics/Internal/EventQueue.swift` | create | Actor — append-only queue, drops oldest on overflow |
| `Sources/PulseAnalytics/Internal/BatchSender.swift` | create | Actor — POST batches, exponential backoff, retry ×3 |
| `Sources/PulseAnalytics/Internal/EventSerializer.swift` | create | Pure functions — PulseEvent → wire JSON dict |
| `Sources/PulseAnalytics/Internal/SessionManager.swift` | create | Actor — UUID session, attaches session_id to every event |
| `Sources/PulseAnalytics/Internal/PersistenceStore.swift` | create | Protocol + file-backed actor impl (Caches dir, Codable JSON) |
| `Sources/PulseAnalytics/Internal/FlushScheduler.swift` | create | Actor — timer + count + background lifecycle flush triggers |
| `Sources/PulseAnalytics/Internal/DeviceInfo.swift` | create | Sendable struct — OS version, model, locale, timezone, app version/build |
| `Tests/PulseAnalyticsTests/EventQueueTests.swift` | create | Enqueue, dequeue, overflow drops oldest |
| `Tests/PulseAnalyticsTests/PulseValueTests.swift` | create | All ExpressibleBy literal conformances |
| `Tests/PulseAnalyticsTests/EventSerializerTests.swift` | create | Every PulseEvent → correct event name string |
| `Tests/PulseAnalyticsTests/BatchSenderTests.swift` | create | Success removes from queue; failure keeps in queue |
| `Tests/PulseAnalyticsTests/PersistenceStoreTests.swift` | create | Save → restart → load restores queue |
| `Tests/PulseAnalyticsTests/SessionManagerTests.swift` | create | session_id present on all events in session |
| `README.md` | create | Installation, quick start, screen/feature extension, event table, wire format, privacy manifest note |
| `PrivacyInfo.xcprivacy` | create | NSPrivacyTracking false, user_id data type declared |

---

## Implementation Steps

### Phase 1 — Package Scaffold
1. [ ] Update `Package.swift`: platforms `.iOS(.v16)`, strict concurrency, add test target, add `PrivacyInfo.xcprivacy` as a resource
2. [ ] Create directory structure: `Sources/PulseAnalytics/Internal/` and `Tests/PulseAnalyticsTests/`

### Phase 2 — Public Types
3. [ ] `PulseValue.swift` — enum with Sendable, Codable, all four ExpressibleBy conformances
4. [ ] `PulseScreen.swift` — RawRepresentable, Hashable, Sendable struct
5. [ ] `PulseFeature.swift` — RawRepresentable, Hashable, Sendable struct
6. [ ] `PulseOptions.swift` — PulseOptions struct + PulseEnvironment enum
7. [ ] `PulseEvent.swift` — exhaustive enum, all cases from spec, Sendable

### Phase 3 — Internal Infrastructure
8. [ ] `DeviceInfo.swift` — Sendable struct collecting OS version, model, locale, timezone, app version/build via UIKit/Foundation (no UIKit import at module level — use conditional or Bundle/ProcessInfo)
9. [ ] `EventSerializer.swift` — `serialize(_:sessionID:userID:appID:deviceInfo:) -> [String: Any]` covering every PulseEvent case exhaustively; ISO8601 timestamp
10. [ ] `EventQueue.swift` — actor; `enqueue`, `dequeue(upTo:)`, `count`, overflow policy (drop oldest); Codable storage type `QueuedEvent`
11. [ ] `PersistenceStore.swift` — protocol `PersistenceStore` + `FilePersistenceStore` actor; Caches dir; async save/load of `[QueuedEvent]`
12. [ ] `SessionManager.swift` — actor; `startSession()`, `endSession()`, `currentSessionID: UUID`; listens to UIApplication notifications via async stream or Task
13. [ ] `FlushScheduler.swift` — actor; timer loop (`Task.sleep`), count-triggered flush, background flush with 5s deadline
14. [ ] `BatchSender.swift` — actor; takes `[QueuedEvent]`, POSTs to endpoint, exponential backoff 1→2→4→…→32s, max 3 retries; protocol `HTTPClient` for testability

### Phase 4 — Public Entry Point
15. [ ] `Pulse.swift` — `@MainActor` enum (no instances); `configure(appID:apiKey:environment:options:)` wires all actors together; `track(_:)`, `identify(userID:traits:)`, `reset()`; lifecycle notification subscription

### Phase 5 — Tests
16. [ ] `EventQueueTests.swift` — enqueue/dequeue happy path; overflow drops oldest (not newest)
17. [ ] `PulseValueTests.swift` — all literal conformances round-trip correctly
18. [ ] `EventSerializerTests.swift` — one test per PulseEvent case checking `event` key in output dict
19. [ ] `BatchSenderTests.swift` — mock HTTPClient; 200 → events removed; 500 → events kept; backoff sequence
20. [ ] `PersistenceStoreTests.swift` — write then read from temp directory restores events
21. [ ] `SessionManagerTests.swift` — session_id non-nil after startSession; changes after endSession+startSession

### Phase 6 — Documentation & Manifest
22. [ ] Add `///` DocC comments to every public type and method
23. [ ] `README.md` — installation, quick start, custom screens/features, full PulseEvent table, wire format JSON block, privacy manifest note
24. [ ] `PrivacyInfo.xcprivacy` — NSPrivacyTracking false, NSPrivacyCollectedDataTypes with user_id

---

## Acceptance Criteria
- [ ] `swift build` succeeds with zero errors/warnings under Swift 6 strict concurrency
- [ ] All tests pass (`swift test`)
- [ ] `EventSerializer` has exhaustive switch on `PulseEvent` (no default case)
- [ ] Zero force-unwraps (`!`), zero `try!`, zero `@unchecked Sendable`
- [ ] Zero `DispatchQueue` usage
- [ ] `print()` calls exist only inside `.debug` environment check
- [ ] `PrivacyInfo.xcprivacy` present at package root
- [ ] `README.md` contains wire format JSON block

---

## Architecture Decisions

### Why `Pulse` is an enum (not a class)
Using a caseless `enum` as a namespace prevents instantiation and makes the singleton pattern explicit without `shared` boilerplate — common Swift SDK pattern.

### DeviceInfo — no UIKit at module level
UIKit must only be imported inside a function or extension conditional on `canImport(UIKit)` to avoid breaking macOS/Linux builds if anyone attempts it. Use `Bundle.main`, `ProcessInfo`, and `Locale.current` for most fields.

### PersistenceStore — Caches not Documents
Analytics queues are transient. Caches dir is excluded from iCloud backup and can be cleared by the OS under storage pressure — appropriate for this data.

### Exponential backoff in BatchSender
Uses `Task.sleep(nanoseconds:)` — no DispatchQueue. Max 3 retries per batch to avoid queue poisoning by a single malformed event.

### Wire format event name derivation
`PulseEvent` cases map to snake_case strings (e.g. `.screenViewed` → `"screen_viewed"`) inside `EventSerializer`. The switch is exhaustive — adding a new case forces a compile error until the serializer is updated.

---

## Notes
- `swift-tools-version: 6.2` is already set in Package.swift — retain it
- iOS 16 minimum is required for `Observable` macro usage if added later, and for certain async API guarantees
- The package has no external dependencies — everything uses Foundation + URLSession
- Tests use `Swift Testing` framework (`import Testing`) not `XCTest`
