![Project Icon](icon.png)

# Basic GCD Timer

A small Swift wrapper around a Dispatch timer. It delivers one event by default, or repeats until cancelled. It has no third-party dependencies.

## Quick start

Add this repository as a Swift package dependency, select the `RVS_BasicGCDTimer` product, and import the module:

```swift
import RVS_BasicGCDTimer
```

Keep the timer in a property so it survives until delivery:

```swift
final class Counter {
    private var timer: RVS_BasicGCDTimer?
    private(set) var count = 0

    // Access this object on the main thread.
    func start() {
        stop()
        timer = RVS_BasicGCDTimer(
            timeIntervalInSeconds: 1,
            leewayInMilliseconds: 50,
            onlyFireOnce: false,
            queue: .main
        ) { [weak self] _, fired in
            guard fired else { return }
            self?.count += 1
        }
        timer?.resume()
    }

    func pause() { timer?.pause() }
    func resume() { timer?.resume() }

    func stop() {
        timer?.invalidate()
        timer = nil
    }
}
```

Omit `onlyFireOnce: false` for a one-shot timer. The short initializer, `RVS_BasicGCDTimer(1) { timer, fired in ... }`, uses a global queue. Specify `queue: .main` with the full initializer for UI callbacks.

A delegate can supplement or replace the completion. Implement `basicGCDTimerCallback(_:)`; validity, invalidation, pause, and resume notifications have no-op defaults. The delegate is held weakly, so retain it elsewhere.

## Behavior to know

- Construction does not schedule work. The first deadline starts at `resume()`. A delegate or completion is required.
- The completion receives `true` for each delivered event and at most one `false` for cancellation. A repeating completion that calls `invalidate()` can receive a nested false call; handle that case separately.
- One-shot timers invalidate after their event. They do not report false once their event has begun. A delegate that invalidates suppresses the following event completion.
- `pause()` stops delivery without resetting deadlines. Resuming an overdue timer can deliver immediately. Repeated calls to `pause()`, `resume()`, or `invalidate()` are harmless.
- `invalidate()` is permanent, including before the first start. Create another timer to restart. It clears the completion, delegate, and context and resets interval, leeway, and the one-shot flag.
- `isInvalid` is also true before the first start; paused timers remain valid. Setting `isRunning` calls `resume()` or `pause()`.
- Retain the timer. It retains its completion and context, so avoid ownership cycles. Deinitialization cancels without calling client code.

Set interval, leeway, queue, and clock **before the first resume**; later assignments are ignored. The interval must be finite, positive, and representable in signed 64-bit nanoseconds. Positive subnanosecond values use one nanosecond. Leeway is a nonnegative millisecond count representable in signed 64-bit nanoseconds. Invalid settings cause cancellation on the first resume, rather than a Dispatch trap or zero-period loop.

Leeway applies to both one-shot and repeating timers. It permits scheduling flexibility, not a strict latency limit. A busy queue, system sleep, and application suspension can all delay execution. The default clock is monotonic; wall time follows calendar-clock adjustments. A timer does not grant background execution or provide real-time guarantees. See [Apple's scheduling documentation](https://developer.apple.com/documentation/dispatch/dispatchsourcetimer/schedule(deadline:repeating:leeway:)-hvhp).

## Concurrency

Timer state and property storage are synchronized. Client callbacks run outside the internal state lock and may call timer methods. Event callbacks use the configured queue; lifecycle and cancellation callbacks run on the thread performing the transition. Concurrent lifecycle operations can produce overlapping notifications.

Pausing or invalidating does not wait for already selected callbacks to finish. Protect shared data in closures and delegates, and dispatch UI work to the main queue. Synchronizing the timer does not synchronize mutations inside its arbitrary context object. The class does not declare `Sendable`; respect the isolation requirements of captured objects when using Swift concurrency.

## Requirements and testing

| Integration | Minimum platforms |
| --- | --- |
| Swift package, Swift tools 5.5+ | iOS/iPadOS 15, macOS 10.14, tvOS 11, watchOS 5 |
| Xcode library targets | iOS/iPadOS 15, macOS 12, tvOS 15, watchOS 9 |
| Xcode test targets | The installed SDK’s recommended deployment targets, to match XCTest |

Run `swift test` for the package. The Xcode project includes library and test schemes for all four platforms. Tests cover one-shot and repeating delivery, lifecycle callbacks, concurrent control, callback reentrancy, invalid inputs, queue selection, and ownership cleanup. They do not require a real-time scheduling deadline.

Use **Build Documentation** in Xcode for the full DocC guide, and Option-click symbols for Quick Help. The older generated documentation in `docs/` may describe an earlier release.

## Updating to 1.8

Invalidation is now permanent; create a new timer for a new schedule. Configuration setters after startup are ignored, leeway now applies to one-shot timers, and deinitialization no longer invokes client callbacks. Default delegate methods no longer print debug messages. See [CHANGELOG.md](CHANGELOG.md) for the complete changes.

## Privacy and direct source integration

The timer does not collect or transmit data, and emits no library debug logging. See [PRIVACY.md](PRIVACY.md).

The Swift package copies its privacy manifest as a resource. You may also copy [the single Swift source](Sources/RVS_BasicGCDTimer/RVS_BasicGCDTimer.swift) into an app. Xcode's static `.a` archives do not embed resources: for direct source or archive integration, include [PrivacyInfo.xcprivacy](Sources/RVS_BasicGCDTimer/PrivacyInfo.xcprivacy) in the consuming app's resources as appropriate for its manifest arrangement.

## License

[MIT License](LICENSE). Copyright 2019–2026, The Great Rift Valley Software Company.
