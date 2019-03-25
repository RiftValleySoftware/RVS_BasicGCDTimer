/**
 © Copyright 2019, The Great Rift Valley Software Company
 
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

typealias ResponseHandlerContextFunc = (_: RVS_BasicGCDTimer?) -> Void
typealias TimerCallbacks = (standard: ResponseHandlerContextFunc, first: ResponseHandlerContextFunc, last: ResponseHandlerContextFunc)

class RVS_BasicGCDTimerTests: XCTestCase, RVS_BasicGCDTimerDelegate {
    func basicGCDTimerCallback(_ inTimer: RVS_BasicGCDTimer) {
        if let contextfunc = inTimer.context as? ResponseHandlerContextFunc {
            contextfunc(inTimer)
        } else if let contextfunc = inTimer.context as? TimerCallbacks {
            contextfunc.standard(inTimer)
        }
    }
    
    func basicGCDTimerValid(_ inTimer: RVS_BasicGCDTimer) {
        if let contextfunc = inTimer.context as? TimerCallbacks {
            contextfunc.first(inTimer)
        } else {
            print("Default basicGCDTimerValid delegate call!")
        }
    }

    func basicGCDTimerWillBecomeInvalid(_ inTimer: RVS_BasicGCDTimer) {
        if let contextfunc = inTimer.context as? TimerCallbacks {
            contextfunc.last(inTimer)
        } else {
            print("Default basicGCDTimerValid delegate call!")
        }
    }

    // Extremely basic one-shot call.
    func testGCDBasicOneShot() {
        var startTime: Date!
        var newTimer: RVS_BasicGCDTimer!

        let expectation = XCTestExpectation()
        
        func responseFunc(_: RVS_BasicGCDTimer?) {
            print(String(format: "Timer Complete After %f milliseconds", Date().timeIntervalSince(startTime) * 1000))
            expectation.fulfill()
        }
        
        // 100 milliseconds on the main queue.
        newTimer = RVS_BasicGCDTimer(timeIntervalInSeconds: 0.1, delegate: self, leewayInMilliseconds: 0, onlyFireOnce: true, context: responseFunc, queue: DispatchQueue.main)
        
        startTime = Date()
        newTimer.resume()
        
        // Wait until the expectation is fulfilled, with a timeout of half a second.
        wait(for: [expectation], timeout: 0.5)
        
        XCTAssertTrue(newTimer.isInvalid)   // We should be invalid.
    }
    
    // Extremely basic test repeat five times.
    func testGCDBasicRepeat() {
        var timerCount: Int = 0
        var startTime: Date!
        var newTimer: RVS_BasicGCDTimer!
        
        let expectation = XCTestExpectation()
        expectation.expectedFulfillmentCount = 5
        
        func responseFunc(_: RVS_BasicGCDTimer?) {
            print(String(format: "Completed Repetition %d at %f milliseconds.", timerCount + 1, (Date().timeIntervalSince(startTime) * 1000)))
            if 4 == timerCount {
                print("Timer Complete After Five Repetitions!")
                newTimer.invalidate()
            }
            expectation.fulfill()
            timerCount += 1
        }
        
        // Every 100 milliseconds on the global queue.
        newTimer = RVS_BasicGCDTimer(timeIntervalInSeconds: 0.1, delegate: self, leewayInMilliseconds: 0, onlyFireOnce: false, context: responseFunc, queue: DispatchQueue.global())
        
        startTime = Date()
        newTimer.resume()
        
        // Wait until the expectation is fulfilled, with a timeout of a second.
        wait(for: [expectation], timeout: 1.0)

        XCTAssertTrue(newTimer.isInvalid)   // We should be invalid.
    }
    
    // Extremely basic test repeat five times, but give a leeway.
    func testGCDBasicRepeatWithLeeway() {
        let leewayInMilliseconds = 10   // If you make this less than ten, you'll probably get intermittent failures, because of the overhead.
        let timerTime: Double = 0.1
        let repetitionCount = 50
        
        var offset: Double = 0.0    // This is the overhead incurred before the first callback. We add this to the leeway.
        
        var timerCount: Int = 0
        var startTime: Date!
        var newTimer: RVS_BasicGCDTimer!
        
        let expectation = XCTestExpectation()
        expectation.expectedFulfillmentCount = 50
        
        func responseFunc(_: RVS_BasicGCDTimer?) {
            timerCount += 1
            let timeInMilliseconds = Date().timeIntervalSince(startTime) * 1000.0
            if 0 == offset {
                offset = timeInMilliseconds - (timerTime * 1000)
            }
            let compareTime: Double = (Double(timerCount) * timerTime * 1000.0) + offset + Double(leewayInMilliseconds)
            XCTAssertLessThan(timeInMilliseconds, compareTime, "We are outside the expected window")
            print(String(format: "Completed Repetition %d at %f milliseconds.", timerCount + 1, timeInMilliseconds))
            if repetitionCount == timerCount {
                print("Timer Complete After Fifty Repetitions!")
                newTimer.invalidate()
            }
            expectation.fulfill()
        }
        
        // Every 100 milliseconds on the global queue, and give a leeway of 20ms.
        newTimer = RVS_BasicGCDTimer(timeIntervalInSeconds: timerTime, delegate: self, leewayInMilliseconds: leewayInMilliseconds, onlyFireOnce: false, context: responseFunc, queue: DispatchQueue.global())
        
        startTime = Date()
        newTimer.resume()
        
        // Wait until the expectation is fulfilled, with a timeout designed to give us very little wiggle room.
        let timeoutInSeconds = (Double(repetitionCount) * timerTime) + (Double(leewayInMilliseconds) / 1000.0)
        wait(for: [expectation], timeout: timeoutInSeconds)
        
        XCTAssertTrue(newTimer.isInvalid)   // We should be invalid.
    }

    // Test multiple queues (100 one-shot timers).
    func testThreading() {
        func runTimers(_ inTimerArray: [RVS_BasicGCDTimer]) {
            func getTimerIndex(_ inTimer: RVS_BasicGCDTimer) -> Int! {
                var ret: Int!
                
                for tuple in inTimerArray.enumerated() {
                    if tuple.element === inTimer {
                        ret = tuple.offset
                    }
                }
                return ret
            }
            
            var expectation = XCTestExpectation()
            expectation.expectedFulfillmentCount = inTimerArray.count
            var startTime: Date!
            
            func initFunc(_ inTimer: RVS_BasicGCDTimer?) {
                var indexString = ""
                if let timer = inTimer {
                    if let index = getTimerIndex(timer) {
                        indexString = " " + String(index + 1)
                    }
                }
                print(String(format: "Initializing timer\(indexString) at %f milliseconds", (Date().timeIntervalSince(startTime) * 1000)))
            }
            
            func invalidateFunc(_ inTimer: RVS_BasicGCDTimer?) {
                var indexString = ""
                if let timer = inTimer {
                    if let index = getTimerIndex(timer) {
                        indexString = " " + String(index + 1)
                    }
                }
                print(String(format: "Invalidating timer\(indexString) at %f milliseconds", (Date().timeIntervalSince(startTime) * 1000)))
                expectation.fulfill()
            }
            
            func responseFunc(_ inTimer: RVS_BasicGCDTimer?) {
                XCTAssertNotNil(inTimer, "The timer should not be nil!")
                var wallString = ""
                var indexString = ""
                if let timer = inTimer {
                    if let index = getTimerIndex(timer) {
                        indexString = " " + String(index + 1)
                    }
                    
                    wallString = timer.isWallTime ? " (Wall Time)." : "."
                }
                print(String(format: "Completed timer\(indexString) at %f milliseconds\(wallString)", (Date().timeIntervalSince(startTime) * 1000)))
            }
            
            startTime = Date()
            inTimerArray.forEach {
                $0.context = (standard: responseFunc, first: initFunc, last: invalidateFunc)
                $0.resume()
            }
            
            // Wait until the expectation is fulfilled, with a timeout of 150 ms.
            wait(for: [expectation], timeout: 0.15)
            
            for timerTuple in inTimerArray.enumerated() {
                XCTAssertTrue(timerTuple.element.isInvalid, "Timer \(timerTuple.offset + 1) should be invalid!")   // We should be invalid.
            }
        }

        var timers: [RVS_BasicGCDTimer] = []
        
        for _ in 0..<10 {
            timers.append(RVS_BasicGCDTimer(timeIntervalInSeconds: 0.1, delegate: self, onlyFireOnce: true, queue: DispatchQueue.main))
            timers.append(RVS_BasicGCDTimer(timeIntervalInSeconds: 0.1, delegate: self, onlyFireOnce: true, queue: DispatchQueue.main, isWallTime: true))
            timers.append(RVS_BasicGCDTimer(timeIntervalInSeconds: 0.1, delegate: self, onlyFireOnce: true, queue: DispatchQueue.global(qos: .default)))
            timers.append(RVS_BasicGCDTimer(timeIntervalInSeconds: 0.1, delegate: self, onlyFireOnce: true, queue: DispatchQueue.global(qos: .default), isWallTime: true))
            timers.append(RVS_BasicGCDTimer(timeIntervalInSeconds: 0.1, delegate: self, onlyFireOnce: true, queue: DispatchQueue.global(qos: .background)))
            timers.append(RVS_BasicGCDTimer(timeIntervalInSeconds: 0.1, delegate: self, onlyFireOnce: true, queue: DispatchQueue.global(qos: .background), isWallTime: true))
            timers.append(RVS_BasicGCDTimer(timeIntervalInSeconds: 0.1, delegate: self, onlyFireOnce: true, queue: DispatchQueue.global(qos: .userInteractive)))
            timers.append(RVS_BasicGCDTimer(timeIntervalInSeconds: 0.1, delegate: self, onlyFireOnce: true, queue: DispatchQueue.global(qos: .userInteractive), isWallTime: true))
            timers.append(RVS_BasicGCDTimer(timeIntervalInSeconds: 0.1, delegate: self, onlyFireOnce: true, queue: DispatchQueue.global(qos: .userInitiated)))
            timers.append(RVS_BasicGCDTimer(timeIntervalInSeconds: 0.1, delegate: self, onlyFireOnce: true, queue: DispatchQueue.global(qos: .userInitiated), isWallTime: true))
        }

        runTimers(timers)
    }
    
    // Test multiple queues (100 repeating timers).
    func testRepeatThreading() {
        func runTimers(_ inTimerArray: [RVS_BasicGCDTimer]) {
            var expectation = XCTestExpectation()
            var fulfillmentCount = 0
            
            expectation.expectedFulfillmentCount = inTimerArray.count
            print("Waiting for fulfillment of \(inTimerArray.count * 5) iterations.")
            var startTime: Date!
            
            var trackTimers = [Int](repeatElement(0, count: inTimerArray.count))
            
            func getTimerIndex(_ inTimer: RVS_BasicGCDTimer) -> Int! {
                var ret: Int!
                
                for tuple in inTimerArray.enumerated() {
                    if tuple.element === inTimer {
                        ret = tuple.offset
                    }
                }
                return ret
            }
            
            func initFunc(_ inTimer: RVS_BasicGCDTimer?) {
                if let timer = inTimer {
                    var indexString = ""
                    if let index = getTimerIndex(timer) {
                        indexString = " " + String(index + 1)
                    }
                    print(String(format: "Initializing timer\(indexString) at %f milliseconds", (Date().timeIntervalSince(startTime) * 1000)))
                } else {
                    XCTFail("This should never happen!")
                }
            }
            
            func invalidateFunc(_ inTimer: RVS_BasicGCDTimer?) {
                if let timer = inTimer {
                    var indexString = ""
                    if let index = getTimerIndex(timer) {
                        indexString = " " + String(index + 1)
                    }
                    print(String(format: "Invalidating timer\(indexString) at %f milliseconds", (Date().timeIntervalSince(startTime) * 1000)))
                    fulfillmentCount += 1
                    print("Fullfillment \(fulfillmentCount).")
                    expectation.fulfill()
                } else {
                    XCTFail("This should never happen!")
                }
            }
            
            func responseFunc(_ inTimer: RVS_BasicGCDTimer?) {
                if let timer = inTimer {
                    var wallString = ""
                    var indexString = ""
                    var callbackIndexString = ""
                    var destroy = false

                    if let index = getTimerIndex(timer) {
                        indexString = " " + String(index + 1)
                        trackTimers[index] += 1
                        callbackIndexString = String(trackTimers[index])
                        if 5 == trackTimers[index] {
                            print("This will be the final call for timer\(indexString).")
                            destroy = true
                        }
                    }
                    
                    wallString = timer.isWallTime ? " (Wall Time)." : "."
                    
                    print(String(format: "Called timer\(indexString) callback (\(callbackIndexString)) at %f milliseconds\(wallString)", (Date().timeIntervalSince(startTime) * 1000)))
                    
                    if destroy {
                        inTimer?.invalidate()
                    }
                } else {
                    XCTFail("This should never happen!")
                }
            }

            startTime = Date()
            inTimerArray.forEach {
                $0.context = (standard: responseFunc, first: initFunc, last: invalidateFunc)
                $0.resume()
            }
            
            // Wait until the expectation is fulfilled, with a timeout of 1 second.
            wait(for: [expectation], timeout: 1)
            
            for timerTuple in inTimerArray.enumerated() {
                XCTAssertTrue(timerTuple.element.isInvalid, "Timer \(timerTuple.offset + 1) should be invalid!")   // We should be invalid.
            }
        }
        
        var timers: [RVS_BasicGCDTimer] = []
        
        for _ in 0..<10 {
            timers.append(RVS_BasicGCDTimer(timeIntervalInSeconds: 0.05, delegate: self, queue: DispatchQueue.main))
            timers.append(RVS_BasicGCDTimer(timeIntervalInSeconds: 0.05, delegate: self, queue: DispatchQueue.main, isWallTime: true))
            timers.append(RVS_BasicGCDTimer(timeIntervalInSeconds: 0.05, delegate: self, queue: DispatchQueue.global(qos: .default)))
            timers.append(RVS_BasicGCDTimer(timeIntervalInSeconds: 0.05, delegate: self, queue: DispatchQueue.global(qos: .default), isWallTime: true))
            timers.append(RVS_BasicGCDTimer(timeIntervalInSeconds: 0.05, delegate: self, queue: DispatchQueue.global(qos: .background)))
            timers.append(RVS_BasicGCDTimer(timeIntervalInSeconds: 0.05, delegate: self, queue: DispatchQueue.global(qos: .background), isWallTime: true))
            timers.append(RVS_BasicGCDTimer(timeIntervalInSeconds: 0.05, delegate: self, queue: DispatchQueue.global(qos: .userInteractive)))
            timers.append(RVS_BasicGCDTimer(timeIntervalInSeconds: 0.05, delegate: self, queue: DispatchQueue.global(qos: .userInteractive), isWallTime: true))
            timers.append(RVS_BasicGCDTimer(timeIntervalInSeconds: 0.05, delegate: self, queue: DispatchQueue.global(qos: .userInitiated)))
            timers.append(RVS_BasicGCDTimer(timeIntervalInSeconds: 0.05, delegate: self, queue: DispatchQueue.global(qos: .userInitiated), isWallTime: true))
        }
        
        runTimers(timers)
    }
}
