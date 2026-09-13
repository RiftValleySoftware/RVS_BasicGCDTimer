# ``RVS_BasicGCDTimer``

Schedule one-shot or repeating work with a manually controlled Dispatch timer.

## Overview

Retain a ``RVS_BasicGCDTimer/RVS_BasicGCDTimer`` instance, supply a completion or delegate, and call `resume()`. The default is **one shot**. Pass `onlyFireOnce: false` for repeated delivery.

The timer does not retain itself. Dropping the last strong reference cancels it. A delegate is weakly held, while the completion and context are strongly held until removed or invalidated.

### Start a repeating timer

This example owns the timer, handles cancellation separately from events, and delivers callbacks on the main queue:

```swift
import RVS_BasicGCDTimer

final class Counter {
    private var timer: RVS_BasicGCDTimer?
    private(set) var count = 0

    // Call this object's methods on the main thread.
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

For one event, omit `onlyFireOnce: false`. The short initializer `RVS_BasicGCDTimer(1) { timer, fired in ... }` uses the default global queue; it does **not** default to the main queue.

### Understand the lifecycle

| Operation or event | Result |
| --- | --- |
| Initialize | No dispatch source exists; `isInvalid` is true and `isRunning` is false. |
| First `resume()` | Validates settings, creates the source, and starts the first deadline. At least one recipient is required. |
| `pause()` | Suspends event delivery. The source remains valid. |
| Resume a paused timer | Enables delivery using the existing schedule. An overdue event can arrive immediately. |
| One-shot event | Calls the delegate, then the completion with true, and invalidates automatically. |
| Repeating event | Calls the delegate, then the completion with true. |
| `invalidate()` | Permanently cancels, clears recipients and context, and resets interval/leeway/one-shot values. |
| Release the last reference | Cancels the source without calling the delegate or completion. |

Setting `isRunning` performs the same operation as calling `resume()` or `pause()`. Repeated starts, pauses, and invalidations are harmless. Create a new instance after invalidation; a cancelled source cannot restart.

Cancellation before an event reports false to the current completion, including cancellation before the timer is first started. Repeating timers can report several true events followed by one false cancellation. Cancelling from a repeating completion can therefore invoke that completion once more, synchronously, with false. Check the flag before doing event work.

A one-shot event that has already begun does not subsequently report false. If its delegate invalidates the timer, the remaining completion is suppressed. Invalidating again from any cancellation or invalidation callback has no effect.

### Configure timing before starting

`timeIntervalInSeconds` must be finite and positive, and its conversion to nanoseconds must be less than `Int64.max`. Positive values below one nanosecond use one nanosecond. `leewayInMilliseconds` must be nonnegative and fit in signed 64-bit nanoseconds. Invalid settings cause the first `resume()` to invalidate and report cancellation instead of passing invalid values to Dispatch.

Set the interval, leeway, queue, and clock before the first `resume()`. Later assignments to those four settings are ignored. You can update the completion, delegate, and context until invalidation.

Leeway applies to both repeating and one-shot timers. It gives Dispatch flexibility to combine wakeups, but it is not a maximum latency guarantee for a busy callback queue. The default clock is monotonic; `isWallTime: true` follows the calendar clock and can be affected by clock changes. Neither option keeps an app running during suspension, wakes a sleeping device on demand, or guarantees exact deadlines. See [Apple's timer scheduling documentation](https://developer.apple.com/documentation/dispatch/dispatchsourcetimer/schedule(deadline:repeating:leeway:)-hvhp).

### Choose queues and protect shared state

Events use the configured queue; lifecycle and cancellation notifications execute on the thread performing the operation. For example, invalidating a main-queue timer from a background thread calls its cancellation completion on that background thread.

Timer state and stored properties are synchronized. Client callbacks execute outside the state lock, may call timer methods, and must protect their own shared data. Concurrent lifecycle operations can produce overlapping notifications. Pausing and invalidating do not wait for already selected callbacks to finish. See [Apple's cancellation semantics](https://developer.apple.com/documentation/dispatch/dispatchsourceprotocol/cancel()).

The class does not declare `Sendable`: synchronizing a timer does not make its arbitrary context, delegate, or captured objects safe to transfer between Swift actors. Access those objects according to their own isolation requirements. Do not assume lifecycle callbacks execute on the event queue.

### Use a delegate for lifecycle notifications

Implement ``RVS_BasicGCDTimerDelegate/basicGCDTimerCallback(_:)`` to receive events. The other four protocol methods have no-op defaults. On a normal initial start the order is validity, resume, event, completion, then invalidation for a one-shot timer. State transitions happen before lifecycle callbacks, so callbacks can inspect state and call timer methods without recursively repeating the same transition.

An invalidation notification receives an already-invalid timer, with its context still available until that notification returns. Deinitialization deliberately does not invoke client code; explicitly invalidate if you need a cancellation notification.

### Integrate and migrate

The Swift package supports iOS/iPadOS 15, macOS 10.14, tvOS 11, and watchOS 5, and requires Swift tools 5.5 or later. The Xcode library targets use iOS 15, macOS 12, tvOS 15, and watchOS 9. Xcode test targets follow the installed SDK’s recommended deployment targets to match its XCTest libraries. The module has no third-party dependencies.

Version 1.8 makes invalidation permanent, applies leeway to one-shot timers, and consistently ignores schedule-setting assignments after startup. It removes debug logging and callbacks during deinitialization. Existing code should retain timers, configure them before starting, handle the completion's false cancellation case, and create a fresh instance when starting a new schedule.

The package includes a privacy manifest. Xcode's `.a` products contain code only; when integrating those archives or copying the Swift source, include `Sources/RVS_BasicGCDTimer/PrivacyInfo.xcprivacy` in the consuming application's resources as appropriate for that application's manifest arrangement.

## Topics

### Timer

- ``RVS_BasicGCDTimer/RVS_BasicGCDTimer``

### Delegate callbacks

- ``RVS_BasicGCDTimerDelegate``
