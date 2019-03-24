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

import Foundation

/* ################################################################## */
/**
 This is the basic callback protocol for the general-purpose GCD timer class. It has one simple required method.
 */
public protocol RVS_BasicGCDTimerDelegate: class {
    /* ############################################################## */
    /**
     Called periodically, as the GCDTimer repeats (or fires once).
     
     - parameter timer: The BasicGCDTimer instance that is invoking the callback.
     */
    func basicGCDTimerCallback(_ timer: RVS_BasicGCDTimer)
}

/* ################################################################## */
/**
 This is a general-purpose GCD timer class.
 
 It requires that an owning instance register a delegate to receive callbacks.
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
            _timerVar = DispatchSource.makeTimerSource()                            // We make a generic, default timer source. No frou-frou.
            let leeway = DispatchTimeInterval.milliseconds(leewayInMilliseconds)    // If they have provided a leeway, we apply it here. We assume milliseconds.
            _timerVar.setEventHandler { [weak self] in
                self?.delegate?.basicGCDTimerCallback(self!)
            }
            if _onlyFireOnce {
                _timerVar.schedule(deadline: .now() + timeIntervalInSeconds)
            } else {
                _timerVar.schedule(deadline: .now() + timeIntervalInSeconds,    // The number of seconds each iteration of the timer will take.
                    repeating: timeIntervalInSeconds,                           // If we are repeating (default), we add our duration as the repeating time. Otherwise (only fire once), we set 0.
                    leeway: leeway)                                             // Add any leeway we specified.
            }
        }
        
        return _timerVar
    }
    
    /* ############################################################## */
    // MARK: - Public Instance Properties
    /* ############################################################## */
    /// This is the time between fires, in seconds.
    public var timeIntervalInSeconds: TimeInterval = 0
    /// This is how much "leeway" we give the timer, in milliseconds. It is ignored for onlyFireOnce.
    public var leewayInMilliseconds: Int = 0
    
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
     - returns: true, if the timer is currently running. READ ONLY
     */
    public var isRunning: Bool {
        return ._running == _state
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
     - returns: the delegate object. READ/WRITE
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
                _delegate = newValue
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
        invalidate()
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
     */
    public init(timeIntervalInSeconds inTimeIntervalInSeconds: TimeInterval,
                delegate inDelegate: RVS_BasicGCDTimerDelegate?,
                leewayInMilliseconds inLeewayInMilliseconds: Int = 0,
                onlyFireOnce inOnlyFireOnce: Bool = false) {
        #if DEBUG
            print("timer init")
        #endif
        timeIntervalInSeconds = inTimeIntervalInSeconds
        leewayInMilliseconds = inLeewayInMilliseconds
        delegate = inDelegate
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
            _state = ._running
            _timer.resume()    // Remember that this could create a timer on the spot.
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
            _state = ._suspended
            _timer.suspend()
        }
    }
    
    /* ############################################################## */
    /**
     This completely nukes the timer. It resets the entire object to default.
     */
    public func invalidate() {
        if ._invalid != _state, nil != _timerVar {
            #if DEBUG
                print("timer invalidate")
            #endif
            delegate = nil
            _timerVar.setEventHandler(handler: nil)
            
            _timerVar.cancel()
            if ._suspended == _state {  // If we were suspended, then we need to call resume one more time.
                #if DEBUG
                    print("timer one more for the road")
                #endif
                _timerVar.resume()
            }
            
            // We clean up everything.
            _onlyFireOnce = false
            timeIntervalInSeconds = 0
            leewayInMilliseconds = 0
            _state = ._invalid
            _timerVar = nil
        }
    }
}
