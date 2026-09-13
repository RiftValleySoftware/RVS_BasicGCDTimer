/**
 © Copyright 2019-2026, The Great Rift Valley Software Company
 
 LICENSE:
 
 MIT License
 
 Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation
 files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy,
 modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the
 Software is furnished to do so, subject to the following conditions:
 
 The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
 OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
 IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF
 CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 
 
 The Great Rift Valley Software Company: https://riftvalleysoftware.com
 
 Version: 1.8.0
 */

import Foundation

/// Receives timer events and optional lifecycle notifications.
///
/// Keep a strong reference to the delegate; the timer stores it weakly. Event callbacks
/// run on the timer's configured queue. Lifecycle notifications run on the thread that
/// performs the transition, which may differ from that queue. See ``RVS_BasicGCDTimer``
/// for concurrency and ownership requirements.
public protocol RVS_BasicGCDTimerDelegate: AnyObject {
    /// Handles one delivered timer event, before the completion closure is called.
    ///
    /// Invalidating the timer here suppresses the event's subsequent completion call.
    /// - Parameter timer: The timer delivering the event.
    func basicGCDTimerCallback(_ timer: RVS_BasicGCDTimer)

    /// Reports creation of the dispatch source, before its first activation.
    ///
    /// The default implementation does nothing. Calling `invalidate()` here cancels
    /// activation; calling `resume()` again has no effect.
    /// - Parameter timer: The timer whose source was created.
    func basicGCDTimerValid(_ timer: RVS_BasicGCDTimer)

    /// Reports invalidation of a previously created source.
    ///
    /// The timer is already invalid when called, so reentrant invalidation is harmless.
    /// Its context remains available until invalidation notifications return. This is
    /// not called during deinitialization. The default implementation does nothing.
    /// - Parameter timer: The timer being invalidated.
    func basicGCDTimerWillBecomeInvalid(_ timer: RVS_BasicGCDTimer)

    /// Reports a transition to the paused state.
    ///
    /// The default implementation does nothing.
    /// - Parameter timer: The paused timer.
    func basicGCDTimerSuspend(_ timer: RVS_BasicGCDTimer)

    /// Reports an initial start or a transition from paused to running.
    ///
    /// The timer reports `isRunning == true` before this notification. On initial
    /// start, `basicGCDTimerValid(_:)` precedes it. The default does nothing.
    /// - Parameter timer: The timer being resumed.
    func basicGCDTimerResume(_ timer: RVS_BasicGCDTimer)
}

public extension RVS_BasicGCDTimerDelegate {
    /// Provides a no-op default for source creation notifications.
    /// - Parameter timer: The timer whose source was created.
    func basicGCDTimerValid(_ timer: RVS_BasicGCDTimer) {}

    /// Provides a no-op default for invalidation notifications.
    /// - Parameter timer: The timer being invalidated.
    func basicGCDTimerWillBecomeInvalid(_ timer: RVS_BasicGCDTimer) {}

    /// Provides a no-op default for pause notifications.
    /// - Parameter timer: The paused timer.
    func basicGCDTimerSuspend(_ timer: RVS_BasicGCDTimer) {}

    /// Provides a no-op default for resume notifications.
    /// - Parameter timer: The timer being resumed.
    func basicGCDTimerResume(_ timer: RVS_BasicGCDTimer) {}
}

/// A manually started Dispatch timer that delivers one event or repeats until cancelled.
///
/// Retain the timer, supply a delegate or completion, and call ``resume()``. A timer
/// defaults to a single event; pass `onlyFireOnce: false` to repeat. Use `queue: .main`
/// for callbacks that update UI. A nil queue uses Dispatch's default global queue.
///
/// ```swift
/// final class DelayedAction {
///     private var timer: RVS_BasicGCDTimer?
///
///     func start() {
///         timer?.invalidate()
///         timer = RVS_BasicGCDTimer(timeIntervalInSeconds: 0.5, queue: .main) { _, fired in
///             if fired { print("Timer fired") }
///         }
///         timer?.resume()
///     }
/// }
/// ```
/// Retain the `DelayedAction` owner for as long as delivery is needed.
///
/// Timer state and stored properties are protected against concurrent access. Client
/// callbacks execute outside the internal lock and may call timer methods. Lifecycle
/// notifications from concurrent operations can overlap or arrive in a different order
/// than the operations; serialize your calls if notification ordering matters. Pausing
/// or invalidating does not wait for a callback already in progress to finish. Protect
/// your delegate, captured variables, and objects held in ``context`` as needed.
///
/// The timer retains its completion and context but not its delegate. Avoid a closure
/// or context that strongly retains the timer or its owner; call ``invalidate()`` when
/// finished. Deinitialization cancels the source without invoking client code.
///
/// Invalidation is permanent. Create another timer to start a new schedule. Dispatch
/// timers are best-effort scheduling tools, not real-time deadlines or a way to keep an
/// app executing while the operating system suspends it.
///
/// ## Topics
///
/// ### Creating a timer
/// - ``init(timeIntervalInSeconds:delegate:leewayInMilliseconds:onlyFireOnce:context:queue:isWallTime:completion:)``
/// - ``init(_:completion:)``
///
/// ### Controlling delivery
/// - ``resume()``
/// - ``pause()``
/// - ``invalidate()``
/// - ``isRunning``
/// - ``isInvalid``
/// - ``isOnlyFiringOnce``
///
/// ### Configuring the schedule
/// - ``timeIntervalInSeconds``
/// - ``leewayInMilliseconds``
/// - ``queue``
/// - ``isWallTime``
///
/// ### Receiving callbacks
/// - ``delegate``
/// - ``completion``
/// - ``context``
/// - ``RVS_BasicGCDTimerCompletion``
public class RVS_BasicGCDTimer {
    /// Handles a delivered event (`true`) or explicit cancellation before completion (`false`).
    ///
    /// Repeating timers call this with `true` for each delivered event and at most once
    /// with `false` when invalidated. One-shot timers do not report cancellation after
    /// their event has begun. Cancellation before the first `resume()` also reports
    /// `false`. Deinitialization never calls this closure.
    ///
    /// Event delivery uses ``queue``. Cancellation delivery runs synchronously on the
    /// thread calling ``invalidate()`` and can be nested inside a repeating event call.
    /// - Parameters:
    ///   - timer: The timer delivering the notification.
    ///   - fired: Whether a timer event was delivered rather than cancelled.
    public typealias RVS_BasicGCDTimerCompletion = (_ timer: RVS_BasicGCDTimer, _ fired: Bool) -> Void

    private enum State { case idle, running, paused, invalidated }
    private let _lock = NSRecursiveLock()
    private var _state: State = .idle
    private var _source: DispatchSourceTimer?
    private var _sourceIsSuspended = true
    private var _transition = UUID()
    private var _oneShotEventBegan = false
    private var _onlyFireOnce = true
    private weak var _delegate: RVS_BasicGCDTimerDelegate?
    private var _completion: RVS_BasicGCDTimerCompletion?
    private var _interval: TimeInterval = 0
    private var _leeway = 0
    private var _context: Any?
    private var _queue: DispatchQueue?
    private var _wallTime = false

    private func _locked<T>(_ body: () -> T) -> T {
        _lock.lock()
        defer { _lock.unlock() }
        return body()
    }

    /// The event and cancellation closure, retained until removed or invalidated.
    ///
    /// Assigning nil removes it without invoking it. Removing the last recipient from
    /// a started timer invalidates that timer. Assignments after invalidation are ignored.
    public var completion: RVS_BasicGCDTimerCompletion? {
        get { _locked { _completion } }
        set {
            let shouldInvalidate = _locked { () -> Bool in
                guard _state != .invalidated else { return false }
                _completion = newValue
                return _source != nil && _completion == nil && _delegate == nil
            }
            if shouldInvalidate { invalidate() }
        }
    }

    /// The delay to the first event and, when repeating, the period, in seconds.
    ///
    /// Set this before the first `resume()`; later assignments are ignored. It must be
    /// finite, positive, and representable as a signed 64-bit nanosecond interval.
    /// Positive subnanosecond values are rounded up to one nanosecond. Invalid settings
    /// cause `resume()` to invalidate the timer and report cancellation.
    public var timeIntervalInSeconds: TimeInterval {
        get { _locked { _interval } }
        set { _locked { if _state == .idle { _interval = newValue } } }
    }

    /// The permitted scheduling leeway, in milliseconds, for both one-shot and repeating timers.
    ///
    /// Set this before the first `resume()`; later assignments are ignored. Values must
    /// be nonnegative and representable as signed 64-bit nanoseconds. Leeway allows Dispatch
    /// to coalesce events to save energy; it does not bound delays caused by a busy queue.
    public var leewayInMilliseconds: Int {
        get { _locked { _leeway } }
        set { _locked { if _state == .idle { _leeway = newValue } } }
    }

    /// Arbitrary caller-owned data retained for callbacks, then released on invalidation.
    ///
    /// Access to this property is synchronized; mutations inside a referenced object
    /// are your responsibility. Assignments after invalidation are ignored.
    public var context: Any! {
        get { _locked { _context } }
        set { _locked { if _state != .invalidated { _context = newValue } } }
    }

    /// The event delivery queue; nil requests Dispatch's default global queue.
    ///
    /// Set this before the first `resume()`; later assignments are ignored. Lifecycle
    /// and cancellation notifications use the calling thread, independently of this queue.
    public var queue: DispatchQueue! {
        get { _locked { _queue } }
        set { _locked { if _state == .idle { _queue = newValue } } }
    }

    /// Whether to schedule using wall-clock time instead of the default monotonic clock.
    ///
    /// Set this before the first `resume()`; later assignments are ignored. Wall time
    /// follows calendar-clock adjustments. Neither clock guarantees execution during
    /// sleep or app suspension; overdue events may be delivered when execution resumes.
    public var isWallTime: Bool {
        get { _locked { _wallTime } }
        set { _locked { if _state == .idle { _wallTime = newValue } } }
    }

    /// Whether there is no live dispatch source, including before the first start.
    ///
    /// A newly initialized timer can be resumed. After explicit or automatic
    /// invalidation, it cannot be restarted. Paused timers remain valid.
    public var isInvalid: Bool { _locked { _state == .idle || _state == .invalidated } }

    /// Whether the timer is configured for one event; false after invalidation.
    public var isOnlyFiringOnce: Bool { _locked { _onlyFireOnce } }

    /// Whether event delivery is enabled; setting this calls `resume()` or `pause()`.
    ///
    /// Repeated assignments are harmless. A paused timer remains valid, and a newly
    /// created timer cannot start without a delegate or completion.
    public var isRunning: Bool {
        get { _locked { _state == .running } }
        set { if newValue { resume() } else { pause() } }
    }

    /// The weakly held delegate; a completion may be used alongside it or instead of it.
    ///
    /// Explicitly removing the last recipient from a started timer invalidates it.
    /// If the delegate deallocates, the missing recipient is detected at the next event.
    /// Assignments after invalidation are ignored.
    public var delegate: RVS_BasicGCDTimerDelegate? {
        get { _locked { _delegate } }
        set {
            let shouldInvalidate = _locked { () -> Bool in
                guard _state != .invalidated else { return false }
                _delegate = newValue
                return _source != nil && _delegate == nil && _completion == nil
            }
            if shouldInvalidate { invalidate() }
        }
    }

    /// Creates a stopped timer without scheduling any work.
    ///
    /// The first deadline is calculated by `resume()`, not by this initializer.
    /// - Parameters:
    ///   - inTimeIntervalInSeconds: Positive, finite delay and repeat period in seconds.
    ///   - inDelegate: Weak event recipient. Optional when a completion is supplied.
    ///   - inLeewayInMilliseconds: Nonnegative scheduling leeway in milliseconds; defaults to zero.
    ///   - inOnlyFireOnce: Whether to deliver one event; defaults to true.
    ///   - inContext: Optional data retained for callbacks.
    ///   - inQueue: Event delivery queue; nil uses Dispatch's default global queue.
    ///   - inIsWallTime: Whether to use wall time; defaults to false (monotonic time).
    ///   - inCompletion: Optional event/cancellation closure. Capture owners weakly when appropriate.
    public init(timeIntervalInSeconds inTimeIntervalInSeconds: TimeInterval,
                delegate inDelegate: RVS_BasicGCDTimerDelegate? = nil,
                leewayInMilliseconds inLeewayInMilliseconds: Int = 0,
                onlyFireOnce inOnlyFireOnce: Bool = true,
                context inContext: Any! = nil,
                queue inQueue: DispatchQueue! = nil,
                isWallTime inIsWallTime: Bool = false,
                completion inCompletion: RVS_BasicGCDTimerCompletion! = nil) {
        _interval = inTimeIntervalInSeconds
        _delegate = inDelegate
        _leeway = inLeewayInMilliseconds
        _onlyFireOnce = inOnlyFireOnce
        _context = inContext
        _queue = inQueue
        _wallTime = inIsWallTime
        _completion = inCompletion
    }

    /// Creates a stopped one-shot timer using Dispatch's default global queue.
    /// - Parameters:
    ///   - inTimeIntervalInSeconds: Positive, finite delay in seconds.
    ///   - inCompletion: Receives true for the event or false for cancellation before delivery.
    public convenience init(_ inTimeIntervalInSeconds: TimeInterval, completion inCompletion: @escaping RVS_BasicGCDTimerCompletion) {
        self.init(timeIntervalInSeconds: inTimeIntervalInSeconds, completion: inCompletion)
    }

    /// Starts or resumes event delivery; repeated calls while running do nothing.
    ///
    /// At least one recipient is required. Invalid intervals or leeway permanently
    /// invalidate the timer and report cancellation. Pausing does not move the original
    /// deadlines, so resuming an overdue timer can deliver an event immediately.
    public func resume() {
        _lock.lock()
        guard _state == .idle || _state == .paused,
              _delegate != nil || _completion != nil else { _lock.unlock(); return }
        let created = _source == nil
        if created {
            let nanoseconds = _interval * 1_000_000_000
            guard nanoseconds.isFinite, nanoseconds > 0, nanoseconds < Double(Int64.max),
                  _leeway >= 0, Int64(_leeway) <= Int64.max / 1_000_000 else {
                _lock.unlock()
                invalidate()
                return
            }
            let source = DispatchSource.makeTimerSource(queue: _queue)
            // Keep seconds as Double: Int-sized nanoseconds would cap 32-bit watchOS at two seconds.
            let interval = max(0.000000001, _interval)
            let leeway = DispatchTimeInterval.milliseconds(_leeway)
            source.setEventHandler { [weak self] in self?._fire() }
            if _wallTime {
                if _onlyFireOnce {
                    source.schedule(wallDeadline: .now() + interval, leeway: leeway)
                } else {
                    source.schedule(wallDeadline: .now() + interval, repeating: interval, leeway: leeway)
                }
            } else {
                if _onlyFireOnce {
                    source.schedule(deadline: .now() + interval, leeway: leeway)
                } else {
                    source.schedule(deadline: .now() + interval, repeating: interval, leeway: leeway)
                }
            }
            _source = source
            _sourceIsSuspended = true
        }
        _state = .running
        let transition = UUID()
        _transition = transition
        let recipient = _delegate
        _lock.unlock()

        if created { recipient?.basicGCDTimerValid(self) }
        // Client code can pause or invalidate during either lifecycle callback.
        guard _locked({ _state == .running && _transition == transition }) else { return }
        recipient?.basicGCDTimerResume(self)
        _locked {
            guard _state == .running, _transition == transition, _sourceIsSuspended else { return }
            _source?.resume()
            _sourceIsSuspended = false
        }
    }

    /// Pauses future events without resetting the schedule; repeated calls do nothing.
    ///
    /// A callback already in progress may finish. Resume with `resume()` or `isRunning = true`.
    public func pause() {
        let recipient = _locked { () -> RVS_BasicGCDTimerDelegate? in
            guard _state == .running else { return nil }
            _state = .paused
            _transition = UUID()
            if !_sourceIsSuspended {
                _source?.suspend()
                _sourceIsSuspended = true
            }
            return _delegate
        }
        recipient?.basicGCDTimerSuspend(self)
    }

    /// Permanently cancels the timer and releases its completion, delegate, and context.
    ///
    /// Repeated or reentrant calls do nothing. Cancellation reports false to the current
    /// completion unless a one-shot event has already begun. A source's invalidation
    /// notification follows the cancellation completion. Context is then released, and
    /// interval, leeway, and the one-shot flag reset to zero/false.
    ///
    /// This does not wait for client code already executing on another thread. A callback
    /// already selected for delivery may finish after this method returns.
    public func invalidate() {
        _invalidate(notify: true)
    }

    private func _fire() {
        _lock.lock()
        guard _state == .running else { _lock.unlock(); return }
        let recipient = _delegate
        let hasCompletion = _completion != nil
        let once = _onlyFireOnce
        if once && (recipient != nil || hasCompletion) { _oneShotEventBegan = true }
        _lock.unlock()
        guard recipient != nil || hasCompletion else { invalidate(); return }

        recipient?.basicGCDTimerCallback(self)
        let callback = _locked { () -> RVS_BasicGCDTimerCompletion? in
            guard _state != .invalidated else { return nil }
            let callback = _completion
            if once { _completion = nil }
            return callback
        }
        callback?(self, true)
        if once { _invalidate(notify: false) }
    }

    private func _invalidate(notify: Bool) {
        _lock.lock()
        guard _state != .invalidated else { _lock.unlock(); return }
        let recipient = _source == nil ? nil : _delegate
        let callback = notify && !_oneShotEventBegan ? _completion : nil
        _state = .invalidated
        _transition = UUID()
        _delegate = nil
        _completion = nil
        _cancelSource()
        _lock.unlock()

        callback?(self, false)
        recipient?.basicGCDTimerWillBecomeInvalid(self)
        _locked {
            _context = nil
            _interval = 0
            _leeway = 0
            _onlyFireOnce = false
        }
    }

    // Must be called with exclusive access. Every suspended source gets one final resume.
    private func _cancelSource() {
        guard let source = _source else { return }
        source.setEventHandler(handler: nil)
        source.cancel()
        if _sourceIsSuspended { source.resume() }
        _source = nil
        _sourceIsSuspended = false
    }

    deinit {
        // Never pass a partially deinitialized object to client code.
        _cancelSource()
    }
}

extension RVS_BasicGCDTimer: Equatable {
    /// Compares timer identity, regardless of scheduling or lifecycle state.
    /// - Parameters:
    ///   - lhs: The first timer.
    ///   - rhs: The second timer.
    /// - Returns: True only when both references identify the same instance.
    public static func == (lhs: RVS_BasicGCDTimer, rhs: RVS_BasicGCDTimer) -> Bool { lhs === rhs }
}
