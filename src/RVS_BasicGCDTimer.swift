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
 
 Version: 1.2.1
 */

import Foundation

/* ################################################################## */
/**
 This is the basic callback protocol for the general-purpose GCD timer class. It has one simple required method, and two optional methods.
 */
public protocol RVS_BasicGCDTimerDelegate: class {
    /* ############################################################## */
    /**
     Called periodically, as the GCDTimer repeats (or fires once). This is required.
     
     - parameter timer: The BasicGCDTimer instance that is invoking the callback.
     */
    func basicGCDTimerCallback(_ timer: RVS_BasicGCDTimer)
    /* ############################################################## */
    /**
     This is called after the timer is initially valid (but before the first run). It is optional.
     
     - parameter timer: The BasicGCDTimer instance that is invoking the callback.
     */
    func basicGCDTimerValid(_ timer: RVS_BasicGCDTimer)
    /* ############################################################## */
    /**
     This is called just before the timer invalidates. It is optional.
     
     - parameter timer: The BasicGCDTimer instance that is invoking the callback.
     */
    func basicGCDTimerWillBecomeInvalid(_ timer: RVS_BasicGCDTimer)
    /* ############################################################## */
    /**
     This is called just before the timer invalidates. It is optional.
     
     - parameter timer: The BasicGCDTimer instance that is invoking the callback.
     */
    func basicGCDTimerSuspend(_ timer: RVS_BasicGCDTimer)
    
    /* ############################################################## */
    /**
     This is called when the timer resumes.
     
     - parameter timer: The BasicGCDTimer instance that is invoking the callback.
     */
    func basicGCDTimerResume(_ timer: RVS_BasicGCDTimer)
}

/* ################################################################## */
/**
 These defaults mean that these methods are optional.
 */
public extension RVS_BasicGCDTimerDelegate {
    /* ############################################################## */
    /**
     - parameter timer: The BasicGCDTimer instance that is invoking the callback.
     */
    func basicGCDTimerValid(_ timer: RVS_BasicGCDTimer) {
        #if DEBUG
            print("Default basicGCDTimerValid delegate call!")
        #endif
    }
    
    /* ############################################################## */
    /**
     This is called just before the timer invalidates.
     
     - parameter timer: The BasicGCDTimer instance that is invoking the callback.
     */
    func basicGCDTimerWillBecomeInvalid(_ timer: RVS_BasicGCDTimer) {
        #if DEBUG
            print("Default basicGCDTimerWillBecomeInvalid delegate call!")
        #endif
    }
    
    /* ############################################################## */
    /**
     This is called when the timer suspends.
     
     - parameter timer: The BasicGCDTimer instance that is invoking the callback.
     */
    func basicGCDTimerSuspend(_ timer: RVS_BasicGCDTimer) {
        #if DEBUG
            print("Default basicGCDTimerSuspend delegate call!")
        #endif
    }
    
    /* ############################################################## */
    /**
     This is called when the timer resumes.
     
     - parameter timer: The BasicGCDTimer instance that is invoking the callback.
     */
    func basicGCDTimerResume(_ timer: RVS_BasicGCDTimer) {
        #if DEBUG
            print("Default basicGCDTimerResume delegate call!")
        #endif
    }
}

/* ################################################################## */
/**
 This is a general-purpose GCD timer class.
 
 It requires that an owning instance register a delegate to receive callbacks.
 
 The way that you use this, is to create an instance of this class (we use a class, to ensure that it is referenced, as opposed to copied).
 You then call "resume()" on that instance.
 */
public class RVS_BasicGCDTimer {
    /* ############################################################## */
    // MARK: - Private Enums
    /* ############################################################## */
    /// This is used to hold state flags for internal use.
    private enum _State {
        /// The timer is currently invalid.
        case _invalid
        /// The timer is currently paused.
        case _suspended
        /// The timer is firing.
        case _running
    }
    
    /* ############################################################## */
    // MARK: - Private Instance Properties
    /* ############################################################## */
    /// This holds our current run state.
    private var _state: _State = ._invalid
    /// This holds a Boolean that is true, if we are to only fire once (default is false, which means we repeat).
    private var _onlyFireOnce: Bool = false
    /// This contains the actual dispatch timer object instance.
    private var _timerVar: DispatchSourceTimer!
    /// This is the contained delegate instance
    private weak var _delegate: RVS_BasicGCDTimerDelegate?
    
    /* ############################################################## */
    /**
     This dynamically initialized calculated property will return (or create and return) a basic GCD timer that (probably) repeats.
     
     It uses the current queue.
     */
    private var _timer: DispatchSourceTimer! {
        if nil == _timerVar {   // If we don't already have a timer, we create one. Otherwise, we simply return the already-instantiated object.
            #if DEBUG
                print("timer create GCD object")
            #endif
            _timerVar = DispatchSource.makeTimerSource(queue: queue)                // We make a generic, default timer source. No frou-frou. If a queue was specified, we use that.
            let leeway = DispatchTimeInterval.milliseconds(leewayInMilliseconds)    // If they have provided a leeway, we apply it here. We assume milliseconds.
            _timerVar.setEventHandler { [weak self] in                              // This is the timer's base callback. This is called from the system timer.
                if let self = self {
                    self.delegate?.basicGCDTimerCallback(self)                      // Call the delegate back.
                    if nil == self.delegate || self._onlyFireOnce {                 // The timer commits seppukku if it's only to fire one time. It also does it if the variable can't unwrap (should never happen).
                        self.invalidate()
                    }
                }
            }
            if _onlyFireOnce {                                                      // Just this once...
                if isWallTime {                                                     // See if we want to use "Wall" time, which doesn't care whether or not the computer goes to sleep.
                    _timerVar.schedule(wallDeadline: DispatchWallTime.now() + timeIntervalInSeconds)
                } else {
                    _timerVar.schedule(deadline: .now() + timeIntervalInSeconds)
                }
            } else {
                if isWallTime {                                                     // See if we want to use "Wall" time, which doesn't care whether or not the computer goes to sleep.
                    _timerVar.schedule(wallDeadline: DispatchWallTime.now() + timeIntervalInSeconds,    // The number of seconds each iteration of the timer will take.
                        repeating: timeIntervalInSeconds,                                               // If we are repeating (default), we add our duration as the repeating time.
                        leeway: leeway)                                                                 // Add any leeway we specified.
                } else {
                    _timerVar.schedule(deadline: .now() + timeIntervalInSeconds,    // The number of seconds each iteration of the timer will take.
                        repeating: timeIntervalInSeconds,                           // If we are repeating (default), we add our duration as the repeating time.
                        leeway: leeway)                                             // Add any leeway we specified.
                }
            }
            
            delegate?.basicGCDTimerValid(self)
        }
        
        return _timerVar
    }
    
    /* ############################################################## */
    /**
     This is called to completely invalidate the timer.
     */
    private func _seppukku() {
        if let timer = _timerVar {
            #if DEBUG
                print("timer invalidating.")
            #endif
            delegate?.basicGCDTimerWillBecomeInvalid(self)
            _delegate = nil
            timer.setEventHandler(handler: nil)
            timer.cancel()
            
            // We clean up everything.
            timeIntervalInSeconds = 0
            leewayInMilliseconds = 0
            context = nil
            _onlyFireOnce = false
            
            if ._suspended == _state {  // If we were suspended, then we need to call resume one more time.
                #if DEBUG
                    print("timer one more for the road")
                #endif
                timer.resume()
            }
            
            _timerVar = nil
            _state = ._invalid
        }
    }
    
    /* ############################################################## */
    // MARK: - Public Instance Properties
    /* ############################################################## */
    /// This is the time between fires, in seconds.
    public var timeIntervalInSeconds: TimeInterval = 0
    /// This is how much "leeway" we give the timer, in milliseconds. It is ignored for onlyFireOnce.
    public var leewayInMilliseconds: Int = 0
    /// This allows the delegate to add any "context" data to the instance,
    public var context: Any!
    /// This is the dispatch queue the timer will use.
    public var queue: DispatchQueue!
    /// True, if we are to use the Apple "Wall Clock" time.
    public var isWallTime: Bool = false
    
    /* ############################################################## */
    // MARK: - Public Calculated Properties
    /* ############################################################## */
    /**
     - returns: true, if the timer is invalid. READ ONLY
     */
    public var isInvalid: Bool {
        return ._invalid == _state
    }
    
    /* ############################################################## */
    /**
     - returns: true, if the timer will only fire one time (will return false after that one fire). READ ONLY
     */
    public var isOnlyFiringOnce: Bool {
        return _onlyFireOnce
    }
    
    /* ############################################################## */
    /**
     - returns: true, if the timer is currently running. READ/WRITE
     */
    public var isRunning: Bool {
        get {
            return ._running == _state  // Simply return true, if we are running.
        }
        
        set {
            if ._running == _state && !newValue {   // If we were running, and the new value if false, we pause.
                _state = ._suspended
                _timer.suspend()
            } else if newValue {    // If the new value is true, then we resume (which could create a new instance of the timer).
                _state = ._running
                _timer.resume()
            }
        }
    }
    
    /* ############################################################## */
    /**
     - returns: the delegate object. READ/WRITE. If nil, then the instance will stop and invalidate. You must have a delegate to run.
     */
    public var delegate: RVS_BasicGCDTimerDelegate? {
        get {
            return _delegate
        }
        
        set {
            if _delegate !== newValue {
                #if DEBUG
                    print("timer changing the delegate from \(String(describing: delegate)) to \(String(describing: newValue))")
                #endif
                if nil == newValue {  // We can't have a timer with no one to call. We also use this to kill the timer.
                    _seppukku()
                } else {
                    _delegate = newValue
                }
            }
        }
    }
    
    /* ############################################################## */
    // MARK: - Deinitializer
    /* ############################################################## */
    /**
     We have to carefully dismantle this, as we can end up with crashes if we don't clean up properly.
     */
    deinit {
        #if DEBUG
            print("timer deinit")
        #endif
        _seppukku()
    }
    
    /* ############################################################## */
    // MARK: - Public Methods
    /* ############################################################## */
    /**
     Default constructor
     
     - parameter timeIntervalInSeconds: The time (in seconds) between fires.
     - parameter delegate: Our delegate, for callbacks. Optional. Default is nil.
     - parameter leewayInMilliseconds: Any leeway. This is optional, and default is zero (0). It is ignored if onlyFireOnce is true.
     - parameter onlyFireOnce: If true, then this will only fire one time, as opposed to repeat. Optional. Default is false. If true, then leewayInMilliseconds is ignored.
     - parameter context: This can be any data that the caller wants to associate with the timer. It will be available in the callback, as the timer object's "context" property.
     - parameter queue: The DispatchQueue to use for the timer. Optional. If not specified, the default queue is used.
     - parameter isWallTime: If true (default is false), then the timer will use the Apple "Wall time" clock, which is more consistent.
     */
    public init(timeIntervalInSeconds inTimeIntervalInSeconds: TimeInterval,
                delegate inDelegate: RVS_BasicGCDTimerDelegate?,
                leewayInMilliseconds inLeewayInMilliseconds: Int = 0,
                onlyFireOnce inOnlyFireOnce: Bool = false,
                context inContext: Any! = nil,
                queue inQueue: DispatchQueue! = nil,
                isWallTime inIsWallTime: Bool = false) {
        #if DEBUG
            print("timer init")
            print("\tleewayInMilliseconds: \(inLeewayInMilliseconds)")
            print("\tonlyFireOnce: \(inOnlyFireOnce ? "true" : "false")")
            print("\tisWallTime: \(inIsWallTime ? "true" : "false")")
        #endif
        timeIntervalInSeconds = inTimeIntervalInSeconds
        leewayInMilliseconds = inLeewayInMilliseconds
        delegate = inDelegate
        context = inContext
        isWallTime = inIsWallTime
        queue = inQueue
        _onlyFireOnce = inOnlyFireOnce
    }
    
    /* ############################################################## */
    /**
     If the timer is not currently running, we resume. If running, nothing happens.
     */
    public func resume() {
        if ._running != _state {
            #if DEBUG
                print("timer resume")
            #endif
            delegate?.basicGCDTimerResume(self) // Call the delegate
            isRunning = true    // Remember that this could create a timer on the spot.
        }
    }
    
    /* ############################################################## */
    /**
     If the timer is currently running, we suspend. If not running, nothing happens.
     */
    public func pause() {
        if ._running == _state {
            #if DEBUG
                print("timer suspend")
            #endif
            delegate?.basicGCDTimerSuspend(self) // Call the delegate
            isRunning = false
        }
    }
    
    /* ############################################################## */
    /**
     This completely nukes the timer. It resets the entire object to default.
     */
    public func invalidate() {
        _seppukku()
    }
}
