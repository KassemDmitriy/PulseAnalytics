# PulseAnalytics

Lightweight, Swift 6-native analytics SDK for iOS and macOS. Tracks events, identifies users, and ships data to your own backend — including Supabase with zero third-party dependencies.

---

## Requirements

| | Minimum |
|---|---|
| iOS | 16.0 |
| macOS | 13.0 |
| Swift | 6.0 |
| Xcode | 15+ |

---

## Installation

### Xcode (recommended)

1. **File → Add Package Dependencies…**
2. Paste your repository URL
3. Select **Up to Next Major Version** starting from `1.0.0`
4. Add `PulseAnalytics` to your app target

### Swift Package Manager

Add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/KassemDmitriy/PulseAnalytics", from: "1.0.0")
],
targets: [
    .target(name: "YourApp", dependencies: ["PulseAnalytics"])
]
```

---

## Quick Start

```swift
import PulseAnalytics

// 1. Configure once at app launch
Pulse.configure(appID: "com.example.app", apiKey: "your-api-key", environment: .production)

// 2. Track events anywhere
Pulse.track(.screenViewed(.home))
Pulse.track(.buttonTapped("subscribe", screen: .home))

// 3. Identify a logged-in user
Pulse.identify(userID: "user-123", traits: ["plan": "pro"])

// 4. Clear identity on logout
Pulse.reset()
```

---

## Configuration

### Environments

| Value | Behaviour |
|---|---|
| `.production` | Events sent to the configured endpoint |
| `.staging` | Events sent to the configured endpoint |
| `.debug` | Events printed to the console only — nothing sent |

Use `.debug` during development so no test data reaches your backend.

### Options

```swift
var options = PulseOptions()
options.batchSize     = 20        // flush after N events (default: 20)
options.flushInterval = 30        // flush every N seconds (default: 30)
options.maxQueueSize  = 500       // max events in memory before oldest are dropped (default: 500)
options.logLevel      = .verbose  // .none | .error | .verbose (default: .none)

Pulse.configure(appID: "com.example.app", apiKey: "key", environment: .production, options: options)
```

---

## Defining Screens and Features

Extend `PulseScreen` and `PulseFeature` with your app's values — once, in one file:

```swift
extension PulseScreen {
    static let home      = PulseScreen("home")
    static let settings  = PulseScreen("settings")
    static let profile   = PulseScreen("profile")
    static let onboarding = PulseScreen("onboarding")
}

extension PulseFeature {
    static let search     = PulseFeature("search")
    static let darkMode   = PulseFeature("dark_mode")
    static let shareSheet = PulseFeature("share_sheet")
}
```

---

## Tracking Events

### Lifecycle

```swift
Pulse.track(.sessionStarted)
Pulse.track(.sessionEnded(duration: 120))
Pulse.track(.appForegrounded)
Pulse.track(.appBackgrounded)
```

> Lifecycle events are tracked automatically — you only need these if you manage sessions manually.

### Navigation

```swift
Pulse.track(.screenViewed(.home))
Pulse.track(.screenDismissed(.settings))
```

### Engagement

```swift
Pulse.track(.featureUsed(.search, properties: ["query": "swift concurrency"]))
Pulse.track(.featureUsed(.darkMode, properties: nil))
Pulse.track(.buttonTapped("get_started", screen: .onboarding))
Pulse.track(.searchPerformed(query: "analytics", resultsCount: 14))
```

### Commerce

```swift
Pulse.track(.purchaseStarted(productID: "pro_monthly"))
Pulse.track(.purchaseCompleted(productID: "pro_monthly", revenue: 9.99, currency: "USD"))
Pulse.track(.purchaseFailed(productID: "pro_monthly", reason: "payment_declined"))
Pulse.track(.subscriptionStarted(plan: "pro_annual"))
Pulse.track(.subscriptionCancelled(reason: "too_expensive"))
```

### Quality

```swift
Pulse.track(.errorOccurred(code: "AUTH_001", message: "Token expired", screen: .profile))
Pulse.track(.crashRecovered)
```

### Custom Events

```swift
Pulse.track(.custom(name: "onboarding_step_completed", properties: [
    "step": 2,
    "method": "email"
]))
```

---

## Identifying Users

Call `identify` after a successful login. Subsequent events will include the `user_id` field.

```swift
Pulse.identify(userID: "user-123")

// With optional traits
Pulse.identify(userID: "user-123", traits: [
    "plan": "pro",
    "account_age_days": 42
])
```

Call `reset()` on logout:

```swift
Pulse.reset()
```

---

## Supabase Backend

Send events directly to a Supabase table — no Edge Function or CLI required.

### 1. Create the table

Run in **SQL Editor → New query**:

```sql
create table events (
  id          uuid        primary key default gen_random_uuid(),
  event_id    text        not null unique,
  event       text        not null,
  app_id      text        not null,
  install_id  text        not null,
  session_id  text        not null,
  user_id     text,
  timestamp   timestamptz not null,
  properties  jsonb,
  device      jsonb,
  received_at timestamptz not null default now()
);

create index on events (app_id, install_id);
create index on events (timestamp desc);
```

### 2. Get your credentials

**Project Settings → API** — copy the **Project URL** and **anon public** key.

### 3. Configure the SDK

```swift
var options = PulseOptions()
options.supabase = SupabaseConfig(
    projectURL: URL(string: "https://YOUR_REF.supabase.co")!,
    anonKey: "YOUR_ANON_KEY"
)

Pulse.configure(
    appID: "com.example.app",
    apiKey: "",   // not used when supabase is set
    environment: .production,
    options: options
)
```

That's it. Events are batched, retried on failure, and deduplicated by `event_id`.

---

## How It Works

- **Batching** — events accumulate in memory and are flushed periodically or when `batchSize` is reached
- **Persistence** — the queue is saved to disk so events survive app restarts and crashes
- **Retries** — failed batches are retried up to 3 times with exponential backoff + jitter (1s → 2s → 4s)
- **Idempotency** — every event has a stable `event_id`; duplicate sends are safe
- **install_id** — a UUID generated once and stored in Keychain; stable across app updates, reset on reinstall
- **Privacy** — no IDFA, no device fingerprinting, no PII collected by default
