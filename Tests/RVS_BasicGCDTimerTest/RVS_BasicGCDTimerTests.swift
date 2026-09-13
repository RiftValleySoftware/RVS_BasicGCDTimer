/*
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
 */

import XCTest
import RVS_BasicGCDTimer

private final class Delegate: RVS_BasicGCDTimerDelegate {
    var onFire: (RVS_BasicGCDTimer) -> Void = { _ in }
    var onValid: (RVS_BasicGCDTimer) -> Void = { _ in }
    var onInvalid: (RVS_BasicGCDTimer) -> Void = { _ in }
    var onPause: (RVS_BasicGCDTimer) -> Void = { _ in }
    var onResume: (RVS_BasicGCDTimer) -> Void = { _ in }
    func basicGCDTimerCallback(_ timer: RVS_BasicGCDTimer) { onFire(timer) }
    func basicGCDTimerValid(_ timer: RVS_BasicGCDTimer) { onValid(timer) }
    func basicGCDTimerWillBecomeInvalid(_ timer: RVS_BasicGCDTimer) { onInvalid(timer) }
    func basicGCDTimerSuspend(_ timer: RVS_BasicGCDTimer) { onPause(timer) }
    func basicGCDTimerResume(_ timer: RVS_BasicGCDTimer) { onResume(timer) }
}

private final class Locked<Value> {
    private let lock = NSLock()
    private var storage: Value
    init(_ value: Value) { storage = value }
    var value: Value { update { $0 } }
    @discardableResult func update<T>(_ action: (inout Value) -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return action(&storage)
    }
}

private final class Weak<Value: AnyObject> {
    weak var value: Value?
    init(_ value: Value?) { self.value = value }
}

final class RVS_BasicGCDTimerTests: XCTestCase {
    private func waitUntilInvalid(_ timer: RVS_BasicGCDTimer) {
        let invalid = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in timer.isInvalid }, object: nil)
        wait(for: [invalid], timeout: 3)
    }

    func testGCDBasicOneShot() {
        let fired = expectation(description: "one event")
        var results: [Bool] = []
        let timer = RVS_BasicGCDTimer(timeIntervalInSeconds: 0.01, queue: .main) { timer, success in
            results.append(success)
            XCTAssertTrue(success)
            XCTAssertTrue(timer.isOnlyFiringOnce)
            fired.fulfill()
        }
        XCTAssertTrue(timer.isInvalid)
        XCTAssertFalse(timer.isRunning)
        timer.resume()
        wait(for: [fired], timeout: 3)
        XCTAssertTrue(timer.isInvalid)
        XCTAssertFalse(timer.isOnlyFiringOnce)
        XCTAssertNil(timer.completion)
        timer.invalidate()
        XCTAssertEqual(results, [true])
    }

    func testSimpleInitializerUsesCompletion() {
        let fired = expectation(description: "simple initializer")
        let results = Locked<[Bool]>([])
        let timer = RVS_BasicGCDTimer(0.01) { _, success in
            results.update { $0.append(success) }
            fired.fulfill()
        }
        timer.resume()
        wait(for: [fired], timeout: 3)
        waitUntilInvalid(timer)
        XCTAssertEqual(results.value, [true])
    }

    func testGCDBasicRepeat() {
        let finished = expectation(description: "five events and cancellation")
        var results: [Bool] = []
        let timer = RVS_BasicGCDTimer(timeIntervalInSeconds: 0.01, onlyFireOnce: false, queue: .main) { timer, fired in
            results.append(fired)
            if fired && results.count == 5 { timer.invalidate() }
            if !fired {
                // Previously this reentered the same cancellation closure indefinitely.
                timer.invalidate()
                finished.fulfill()
            }
        }
        timer.resume()
        wait(for: [finished], timeout: 3)
        XCTAssertEqual(results, [true, true, true, true, true, false])
        XCTAssertTrue(timer.isInvalid)
        XCTAssertNil(timer.completion)
    }

    func testGCDBasicRepeatWithLeeway() {
        let finished = expectation(description: "repeating timer with leeway")
        var count = 0
        let timer = RVS_BasicGCDTimer(timeIntervalInSeconds: 0.01, leewayInMilliseconds: 5, onlyFireOnce: false, queue: .main) { timer, fired in
            guard fired else { return }
            count += 1
            if count == 3 { timer.invalidate(); finished.fulfill() }
        }
        timer.resume()
        wait(for: [finished], timeout: 3)
        XCTAssertEqual(count, 3)
        XCTAssertTrue(timer.isInvalid)
    }

    func testThreading() {
        let fired = expectation(description: "each queue and clock")
        fired.expectedFulfillmentCount = 6
        let queues: [DispatchQueue] = [.main, .global(), DispatchQueue(label: "timer.test.serial")]
        let timers = queues.flatMap { queue in
            [false, true].map { wall in
                RVS_BasicGCDTimer(timeIntervalInSeconds: 0.01, queue: queue, isWallTime: wall) { _, success in
                    XCTAssertTrue(success)
                    fired.fulfill()
                }
            }
        }
        timers.forEach { $0.resume() }
        wait(for: [fired], timeout: 3)
        timers.forEach { waitUntilInvalid($0) }
    }

    func testRepeatThreading() {
        let done = expectation(description: "concurrent control operations")
        let eventQueue = DispatchQueue(label: "timer.test.events")
        let counts = Locked((events: 0, cancellations: 0))
        let timer = RVS_BasicGCDTimer(timeIntervalInSeconds: 0.001, onlyFireOnce: false, queue: eventQueue) { _, fired in
            counts.update { if fired { $0.events += 1 } else { $0.cancellations += 1 } }
        }
        timer.resume()
        DispatchQueue.global().async {
            DispatchQueue.concurrentPerform(iterations: 1000) { index in
                switch index % 5 {
                case 0: timer.resume()
                case 1: timer.pause()
                case 2: timer.isRunning = true
                case 3: timer.context = index
                default: _ = (timer.isRunning, timer.isInvalid, timer.context, timer.completion)
                }
            }
            DispatchQueue.concurrentPerform(iterations: 20) { _ in timer.invalidate() }
            eventQueue.sync {}
            done.fulfill()
        }
        wait(for: [done], timeout: 5)
        XCTAssertTrue(timer.isInvalid)
        XCTAssertEqual(counts.value.cancellations, 1)
        XCTAssertNil(timer.context)
    }

    func testSuspendResume() {
        let finished = expectation(description: "resumes after pause")
        let delegate = Delegate()
        var events = 0
        var pauses = 0
        var resumes = 0
        delegate.onPause = { timer in pauses += 1; timer.pause() }
        delegate.onResume = { timer in resumes += 1; timer.resume() }
        delegate.onFire = { timer in
            events += 1
            if events == 1 {
                timer.pause()
                timer.isRunning = false
                XCTAssertFalse(timer.isInvalid)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.03) {
                    XCTAssertEqual(events, 1)
                    timer.resume()
                    timer.isRunning = true
                }
            } else {
                timer.invalidate()
                finished.fulfill()
            }
        }
        let timer = RVS_BasicGCDTimer(timeIntervalInSeconds: 0.01, delegate: delegate, onlyFireOnce: false, queue: .main)
        timer.resume()
        timer.resume()
        wait(for: [finished], timeout: 3)
        XCTAssertEqual(events, 2)
        XCTAssertEqual(pauses, 1)
        XCTAssertEqual(resumes, 2)
    }

    func testProtocolDefaults() {
        final class DefaultDelegate: RVS_BasicGCDTimerDelegate {
            let fired: XCTestExpectation
            init(_ fired: XCTestExpectation) { self.fired = fired }
            func basicGCDTimerCallback(_ timer: RVS_BasicGCDTimer) { fired.fulfill() }
        }
        let fired = expectation(description: "default lifecycle implementations")
        let delegate = DefaultDelegate(fired)
        let timer = RVS_BasicGCDTimer(timeIntervalInSeconds: 0.01, delegate: delegate, queue: .main)
        timer.resume()
        timer.pause()
        timer.resume()
        wait(for: [fired], timeout: 3)
        XCTAssertTrue(timer.isInvalid)
    }

    func testLifecycleOrderAndContext() {
        let finished = expectation(description: "ordered notifications")
        let delegate = Delegate()
        var events: [String] = []
        delegate.onValid = { timer in
            XCTAssertTrue(timer.isRunning)
            events.append("valid")
        }
        delegate.onResume = { _ in events.append("resume") }
        delegate.onFire = { _ in events.append("event") }
        delegate.onInvalid = { timer in
            XCTAssertTrue(timer.isInvalid)
            XCTAssertEqual(timer.context as? String, "context")
            events.append("invalid")
            finished.fulfill()
        }
        let timer = RVS_BasicGCDTimer(timeIntervalInSeconds: 0.01, delegate: delegate, context: "context", queue: .main) { _, fired in
            XCTAssertTrue(fired)
            events.append("completion")
        }
        timer.resume()
        wait(for: [finished], timeout: 3)
        XCTAssertEqual(events, ["valid", "resume", "event", "completion", "invalid"])
        XCTAssertNil(timer.context)
        XCTAssertNil(timer.delegate)
    }

    func testInvalidateBeforeStartIsPermanentAndIdempotent() {
        var results: [Bool] = []
        let timer = RVS_BasicGCDTimer(10) { timer, fired in
            results.append(fired)
            XCTAssertTrue(timer.isInvalid)
            timer.invalidate()
            timer.resume()
        }
        timer.context = "context"
        timer.invalidate()
        timer.invalidate()
        timer.isRunning = true
        XCTAssertEqual(results, [false])
        XCTAssertFalse(timer.isRunning)
        XCTAssertNil(timer.completion)
        XCTAssertNil(timer.context)
        XCTAssertEqual(timer.timeIntervalInSeconds, 0)
    }

    func testOneShotCompletionCanInvalidateWithoutFailureCallback() {
        let fired = expectation(description: "one-shot reentrant invalidation")
        var results: [Bool] = []
        let timer = RVS_BasicGCDTimer(timeIntervalInSeconds: 0.01, queue: .main) { timer, success in
            results.append(success)
            timer.invalidate()
            fired.fulfill()
        }
        timer.resume()
        wait(for: [fired], timeout: 3)
        XCTAssertEqual(results, [true])
        XCTAssertTrue(timer.isInvalid)
    }

    func testDelegateCanCancelBeforeCompletionDelivery() {
        let cancelled = expectation(description: "cancel from delegate")
        let delegate = Delegate()
        var results: [Bool] = []
        delegate.onFire = { timer in timer.invalidate(); cancelled.fulfill() }
        let timer = RVS_BasicGCDTimer(timeIntervalInSeconds: 0.01, delegate: delegate, onlyFireOnce: false, queue: .main) { _, fired in results.append(fired) }
        timer.resume()
        wait(for: [cancelled], timeout: 3)
        XCTAssertEqual(results, [false])
    }

    func testValidCallbackCanInvalidateNewSuspendedSource() {
        let delegate = Delegate()
        var invalidations = 0
        var resumes = 0
        delegate.onValid = { $0.invalidate() }
        delegate.onInvalid = { timer in invalidations += 1; timer.invalidate() }
        delegate.onResume = { _ in resumes += 1 }
        let timer = RVS_BasicGCDTimer(timeIntervalInSeconds: 1, delegate: delegate)
        timer.resume()
        XCTAssertTrue(timer.isInvalid)
        XCTAssertEqual(invalidations, 1)
        XCTAssertEqual(resumes, 0)
    }

    func testValidCallbackCanResumeWithoutOverResuming() {
        let fired = expectation(description: "resume from validity callback")
        let delegate = Delegate()
        delegate.onValid = { $0.resume() }
        delegate.onFire = { _ in fired.fulfill() }
        let timer = RVS_BasicGCDTimer(timeIntervalInSeconds: 0.01, delegate: delegate, queue: .main)
        timer.resume()
        wait(for: [fired], timeout: 3)
    }

    func testResumeCallbackCanPauseBeforeActivation() {
        let delegate = Delegate()
        delegate.onResume = { $0.pause() }
        let timer = RVS_BasicGCDTimer(timeIntervalInSeconds: 1, delegate: delegate)
        timer.resume()
        XCTAssertFalse(timer.isRunning)
        XCTAssertFalse(timer.isInvalid)
        timer.invalidate()
        XCTAssertTrue(timer.isInvalid)
    }

    func testRemovingDelegatePreservesCompletion() {
        let fired = expectation(description: "completion remains")
        let delegate = Delegate()
        delegate.onFire = { _ in XCTFail("Removed delegate was called") }
        let timer = RVS_BasicGCDTimer(timeIntervalInSeconds: 0.01, delegate: delegate, queue: .main) { _, success in
            XCTAssertTrue(success)
            fired.fulfill()
        }
        timer.delegate = nil
        XCTAssertNil(timer.delegate)
        timer.resume()
        wait(for: [fired], timeout: 3)
    }

    func testRemovingDelegateFromStartedTimerPreservesCompletion() {
        let fired = expectation(description: "started timer keeps its completion")
        let delegate = Delegate()
        delegate.onFire = { _ in XCTFail("Removed delegate was called") }
        var results: [Bool] = []
        // The main queue cannot deliver the event until the test begins waiting.
        let timer = RVS_BasicGCDTimer(timeIntervalInSeconds: 0.01, delegate: delegate, queue: .main) { _, success in
            results.append(success)
            fired.fulfill()
        }
        timer.resume()
        timer.delegate = nil
        XCTAssertNil(timer.delegate)
        XCTAssertTrue(timer.isRunning)
        XCTAssertFalse(timer.isInvalid)
        XCTAssertNotNil(timer.completion)
        wait(for: [fired], timeout: 3)
        XCTAssertEqual(results, [true])
        XCTAssertTrue(timer.isInvalid)
    }

    func testRemovingLastDelegateCancelsStartedTimer() {
        for paused in [false, true] {
            let delegate = Delegate()
            delegate.onFire = { _ in XCTFail("Removed delegate was called") }
            let timer = RVS_BasicGCDTimer(timeIntervalInSeconds: 1, delegate: delegate,
                                         onlyFireOnce: false, context: "context", queue: .main)
            timer.resume()
            if paused { timer.pause() }
            XCTAssertFalse(timer.isInvalid)
            XCTAssertEqual(timer.isRunning, !paused)

            timer.delegate = nil
            XCTAssertTrue(timer.isInvalid)
            XCTAssertFalse(timer.isRunning)
            XCTAssertNil(timer.delegate)
            XCTAssertNil(timer.context)
            XCTAssertEqual(timer.timeIntervalInSeconds, 0)

            // Removing the last recipient permanently invalidates the timer.
            timer.delegate = delegate
            timer.resume()
            XCTAssertNil(timer.delegate)
            XCTAssertTrue(timer.isInvalid)
            XCTAssertFalse(timer.isRunning)
        }
    }

    func testMissingRecipientsCannotStartViaIsRunning() {
        let timer = RVS_BasicGCDTimer(timeIntervalInSeconds: 1)
        timer.isRunning = true
        XCTAssertTrue(timer.isInvalid)
        XCTAssertFalse(timer.isRunning)
        timer.completion = { _, _ in }
        timer.isRunning = true
        XCTAssertTrue(timer.isRunning)
        timer.invalidate()
    }

    func testRemovingLastRecipientCancelsPausedSource() {
        let timer = RVS_BasicGCDTimer(1) { _, _ in XCTFail("Removed completion must not run") }
        timer.resume()
        timer.pause()
        timer.completion = nil
        XCTAssertTrue(timer.isInvalid)
    }

    func testWeakDelegateDisappearanceInvalidatesAtNextEvent() {
        var delegate: Delegate? = Delegate()
        let weakDelegate = Weak(delegate)
        let timer = RVS_BasicGCDTimer(timeIntervalInSeconds: 0.01, delegate: delegate, onlyFireOnce: false, queue: .main)
        timer.resume()
        delegate = nil
        XCTAssertNil(weakDelegate.value)
        waitUntilInvalid(timer)
    }

    func testInvalidIntervalsCancelWithoutScheduling() {
        let intervals: [Double] = [0, -1, .nan, .infinity, -.infinity, .greatestFiniteMagnitude, Double(Int64.max) / 1_000_000_000]
        for interval in intervals {
            var results: [Bool] = []
            let timer = RVS_BasicGCDTimer(interval) { _, fired in results.append(fired) }
            timer.resume()
            XCTAssertTrue(timer.isInvalid)
            XCTAssertFalse(timer.isRunning)
            XCTAssertEqual(results, [false])
        }
    }

    func testInvalidLeewayCancelsWithoutScheduling() {
        let invalidLeeways = Int64(Int.max) > Int64.max / 1_000_000 ? [-1, Int.max] : [-1]
        for once in [false, true] {
            for leeway in invalidLeeways {
                var results: [Bool] = []
                let timer = RVS_BasicGCDTimer(timeIntervalInSeconds: 1, leewayInMilliseconds: leeway, onlyFireOnce: once) { _, fired in results.append(fired) }
                timer.resume()
                XCTAssertTrue(timer.isInvalid)
                XCTAssertEqual(results, [false])
            }
        }
    }

    func testPositiveSubnanosecondIntervalIsSafe() {
        let fired = expectation(description: "minimum effective interval")
        let timer = RVS_BasicGCDTimer(timeIntervalInSeconds: 0.0000000001, queue: .main) { _, success in
            XCTAssertTrue(success)
            fired.fulfill()
        }
        timer.resume()
        wait(for: [fired], timeout: 3)
    }

    func testLongIntervalsAndLeewayWorkOnEveryArchitecture() {
        for once in [false, true] {
            for wall in [false, true] {
                let timer = RVS_BasicGCDTimer(timeIntervalInSeconds: 60, leewayInMilliseconds: 10_000, onlyFireOnce: once, isWallTime: wall) { _, _ in }
                timer.resume()
                XCTAssertTrue(timer.isRunning)
                timer.invalidate()
            }
        }
    }

    func testConfigurationIsCapturedAtFirstResume() {
        let firstQueue = DispatchQueue(label: "timer.test.configuration")
        let timer = RVS_BasicGCDTimer(1) { _, _ in }
        timer.timeIntervalInSeconds = 5
        timer.leewayInMilliseconds = 10
        timer.queue = firstQueue
        timer.isWallTime = true
        timer.resume()
        timer.timeIntervalInSeconds = 0
        timer.leewayInMilliseconds = -1
        timer.queue = .main
        timer.isWallTime = false
        XCTAssertEqual(timer.timeIntervalInSeconds, 5)
        XCTAssertEqual(timer.leewayInMilliseconds, 10)
        XCTAssertTrue(timer.queue === firstQueue)
        XCTAssertTrue(timer.isWallTime)
        timer.invalidate()
    }

    func testEventUsesRequestedQueue() {
        let key = DispatchSpecificKey<String>()
        let queue = DispatchQueue(label: "timer.test.delivery")
        queue.setSpecific(key: key, value: "timer queue")
        let fired = expectation(description: "queue identity")
        let timer = RVS_BasicGCDTimer(timeIntervalInSeconds: 0.01, queue: queue) { _, _ in
            XCTAssertEqual(DispatchQueue.getSpecific(key: key), "timer queue")
            fired.fulfill()
        }
        timer.resume()
        wait(for: [fired], timeout: 3)
        queue.sync {}
    }

    func testCallbacksDoNotHoldStateLock() {
        let finished = expectation(description: "cross-thread access from callback")
        let timer = RVS_BasicGCDTimer(timeIntervalInSeconds: 0.01, queue: DispatchQueue(label: "timer.test.unlocked")) { timer, fired in
            guard fired else { return }
            let readFinished = DispatchSemaphore(value: 0)
            DispatchQueue.global().async {
                _ = timer.isRunning
                readFinished.signal()
            }
            XCTAssertEqual(readFinished.wait(timeout: .now() + 2), .success)
            timer.invalidate()
            finished.fulfill()
        }
        timer.resume()
        wait(for: [finished], timeout: 3)
    }

    func testInvalidationReleasesCapturedObjects() {
        final class Token {}
        var token: Token? = Token()
        let weakToken = Weak(token)
        let timer = RVS_BasicGCDTimer(10) { [token] _, _ in _ = token }
        token = nil
        XCTAssertNotNil(weakToken.value)
        timer.invalidate()
        XCTAssertNil(weakToken.value)
    }

    func testDeinitializingPausedTimerDoesNotNotifyDelegate() {
        let delegate = Delegate()
        delegate.onInvalid = { _ in XCTFail("Deinitialization must not call client code") }
        var timer: RVS_BasicGCDTimer? = RVS_BasicGCDTimer(timeIntervalInSeconds: 10, delegate: delegate)
        let weakTimer = Weak(timer)
        timer?.resume()
        timer?.pause()
        timer = nil
        XCTAssertNil(weakTimer.value)
    }

    func testEqualityUsesObjectIdentity() {
        let timer = RVS_BasicGCDTimer(timeIntervalInSeconds: 1)
        let alias = timer
        let other = RVS_BasicGCDTimer(timeIntervalInSeconds: 1)
        XCTAssertEqual(timer, alias)
        XCTAssertNotEqual(timer, other)
        timer.invalidate()
        XCTAssertEqual(timer, alias)
        XCTAssertNotEqual(timer, other)
    }
}
