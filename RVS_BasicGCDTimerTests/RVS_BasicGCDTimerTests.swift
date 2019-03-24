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

typealias ResponseHandlerContextFunc = () -> Void

class RVS_BasicGCDTimerTests: XCTestCase, RVS_BasicGCDTimerDelegate {
    func basicGCDTimerCallback(_ inTimer: RVS_BasicGCDTimer) {
        if let contextfunc = inTimer.context as? ResponseHandlerContextFunc {
            contextfunc()
        }
    }
    
    // Extremely basic one-shot call.
    func testGCDBasicOneShot() {
        var endTime: Date!
        var startTime: Date!
        var newTimer: RVS_BasicGCDTimer!

        let expectation = XCTestExpectation(description: "Complete Timer")
        
        func responseFunc() {
            endTime = Date()
            print("Timer Complete!")
            expectation.fulfill()
        }
        
        // 100 milliseconds.
        newTimer = RVS_BasicGCDTimer(timeIntervalInSeconds: 0.1, delegate: self, leewayInMilliseconds: 0, onlyFireOnce: true, context: responseFunc)
        
        startTime = Date()
        newTimer.resume()
        
        // Wait until the expectation is fulfilled, with a timeout of half a second.
        wait(for: [expectation], timeout: 0.5)
        
        XCTAssertTrue(newTimer.isInvalid)   // We should be invalid.
        XCTAssertNotNil(endTime, "No end time!")
        
        if let endTime = endTime {
            print(String(format: "Total Time To Run: %f milliseconds", (endTime.timeIntervalSinceReferenceDate - startTime.timeIntervalSinceReferenceDate) * 1000))
        }
        
        newTimer.invalidate()
    }
    
    // Test repeat five times.
    func testGCDBasicRepeat() {
        var timerCount: Int = 0
        var endTime: Date!
        var startTime: Date!
        var newTimer: RVS_BasicGCDTimer!
        
        let expectation = XCTestExpectation(description: "Complete Timer")
        
        func responseFunc() {
            timerCount += 1
            endTime = Date()
            print(String(format: "Callback at %f milliseconds", (endTime.timeIntervalSinceReferenceDate - startTime.timeIntervalSinceReferenceDate) * 1000))
            if 4 < timerCount {
                print("Timer Complete After Five Repetitions!")
                newTimer.invalidate()
                expectation.fulfill()
            }
        }
        
        // Every 100 milliseconds.
        newTimer = RVS_BasicGCDTimer(timeIntervalInSeconds: 0.1, delegate: self, leewayInMilliseconds: 0, onlyFireOnce: false, context: responseFunc)
        
        startTime = Date()
        newTimer.resume()
        
        // Wait until the expectation is fulfilled, with a timeout of a second.
        wait(for: [expectation], timeout: 1.0)
        
        XCTAssertTrue(newTimer.isInvalid)   // We should be invalid.
        XCTAssertNotNil(endTime, "No end time!")
        
        if let endTime = endTime {
            print(String(format: "Total Time To Run: %f milliseconds", (endTime.timeIntervalSinceReferenceDate - startTime.timeIntervalSinceReferenceDate) * 1000))
        }
        
        newTimer.invalidate()
    }
}