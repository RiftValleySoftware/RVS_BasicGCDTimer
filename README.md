![Project Icon](icon.png)

# Basic GCD Timer

## Introduction

This is a fundamental tool: A simple [Grand Central Dispatch](https://developer.apple.com/documentation/dispatch) timer that either fires repeatedly, or only once.

## What Problem Does This Solve?

Timers are necessary for many different reasons. They could be the driving engine of a clock app, or a UI tool to refresh a display or close a screen.

This will allow "leeway," which Apple suggests as a way to help reduce energy usage.

The timer is thread-independent. You can instantiate it on any queue that you want.

It's incredibly simple. Just a "set and forget," if you are firing just once, or a simple repeating callback.

## Requirements

It should work fine for osx, tvOS and iOS. It only depends on the Swift Foundation library.

This requires Swift Version 4.0 or above (tested with 4.2).

## WHERE TO GET

[This is the GitHub repo for the project.](https://github.com/RiftValleySoftware/RVS_BasicGCDTimer).

[This is the documentation page for it](https://riftvalleysoftware.com/work/open-source-projects/#RVS_BasicGCDTimer)

## USAGE

[Swift Package Manager (SPM)](https://swift.org/package-manager/)
-

You can use SPM to load the project as a dependency, by referencing its [GitHub Repo](https://github.com/RiftValleySoftware/RVS_BasicGCDTimer/) URI (SSH: [git@github.com:RiftValleySoftware/RVS_BasicGCDTimer.git](git@github.com:RiftValleySoftware/RVS_BasicGCDTimer.git), or HTTPS: [https://github.com/RiftValleySoftware/RVS_BasicGCDTimer.git](https://github.com/RiftValleySoftware/RVS_BasicGCDTimer.git)).

Once you have the dependency attached, you reference it by adding an import to the files that consume the package:
    
    import RVS_BasicGCDTimer

### Include the Source in Your Project

You can use it as a simple source file; not a module.

To use this, simply add the [RVS_BasicGCDTimer/RVS_BasicGCDTimer.swift](https://github.com/RiftValleySoftware/RVS_BasicGCDTimer/blob/master/RVS_BasicGCDTimer/RVS_BasicGCDTimer.swift) file to your project; copying it wherever you want.

You then instantiate the timer:

Either as a one-shot timer (in this case, 100 milliseconds), or as a repeating timer:

`timeIntervalInSeconds` is a double-precision floating point number, with the timer period, in seconds (not milliseconds). It is required to be a positive value over zero.

The `delegate` is required (if there is no completion). The timer won't work at all without a valid delegate or completion.

`leewayInMilliseconds` is the recommended "leeway" that Apple suggests that you give timers. This helps conserve energy in mobile devices.

Set `onlyFireOnce` to true in order for the timer to be a "one-shot" timer.

`someContext` is any data that you want returned to the callback in your delegate method. It will be available as the timer's `context` property.

`queue` is the GCD queue to use. Not specifying means that the default queue is used.

`isWallTime` asks the timer to use the "Apple Wall Clock" time. That time is absolute, and doesn't care about whether or not the computer sleeps or has performance breaks. It tends to be more consistent.

Note that using Wall Time can lead to unexpected behavior. For example, if the app is suspended for some period of time, and is restarted, instead of continuing where it left off, the completion call may be executed immediately.

`completion` is a completion function. Not specifying it means that a delegate should be provided.

> NOTE: As of version 1.6.0, there is now an optional completion function. It can be a tail completion, and the delegate is now no longer required.

### EXAMPLES

    newTimer = RVS_BasicGCDTimer(timeIntervalInSeconds: 0.1, delegate: someDelegate, leewayInMilliseconds: 25.0, onlyFireOnce: true, context: someContext, queue: DispatchQueue.main, isWallTime: true, completion: nil )

    newTimer = RVS_BasicGCDTimer(timeIntervalInSeconds: 0.1, delegate: nil, leewayInMilliseconds: 25.0, onlyFireOnce: true, context: someContext, queue: DispatchQueue.main, isWallTime: true ) { inTimer, inIsSuccess in
        print("Timer is \(String(describing: inTimer))")
        print("Timer was".(inIsSuccess ? " " : "not ")."successful.")
    }
}

Here, we specify a repeating timer, with no leeway, and no context data:

    newTimer = RVS_BasicGCDTimer(timeIntervalInSeconds: 0.1, delegate: someDelegate, leewayInMilliseconds: 0, onlyFireOnce: false, context: nil, queue: nil, isWallTime: false)

However, there's a lot of defaults. You can specify the exact same as such:

    newTimer = RVS_BasicGCDTimer(timeIntervalInSeconds: 0.1, delegate: someDelegate)

Or:

    newTimer = RVS_BasicGCDTimer(timeIntervalInSeconds: 0.1) { inTimer, inIsSuccess in
        print("Timer is \(String(describing: inTimer))")
        print("Timer was".(inIsSuccess ? " " : "not ")."successful.")
    }

Or:

    newTimer = RVS_BasicGCDTimer(0.1) { inTimer, inIsSuccess in
        print("Timer is \(String(describing: inTimer))")
        print("Timer was".(inIsSuccess ? " " : "not ")."successful.")
    }

Once the timer is instantiated, you start it by calling `resume()`:

    newTimer.resume()

You pause (suspend) a running timer by calling `pause()`:

    newTimer.pause()

If the timer is not already running, nothing happens. If it is running, then it suspends.

If repeating, the timer will repeat until it is invalidated or deinitialized:

    newTimer.invalidate()

If a "one-shot," then the timer is invalidated as soon as it completes.

### Completion

As of version 1.6.0, there is now an optional completion function. It can be a tail completion.

The completion function has 2 arguments: The timer instance, and a boolean, which is true, if the timer completed, and false, if not.

### Delegate

The delegate has one required method, and four optional ones (with default extension handlers). The parameter passed in is the timer object.

You can look at the timer object's `context` property for any data/functions/whatever that you want the callback to access.

This one is called at the completion of the timer. It is required:

    func basicGCDTimerCallback(_ timer: RVS_BasicGCDTimer)

This one is an optional method that is called when the timer bcomes valid:

    func basicGCDTimerValid(_ timer: RVS_BasicGCDTimer)

This one is an optional one that is called JUST PRIOR to a timer bcoming invalid:

    func basicGCDTimerWillBecomeInvalid(_ timer: RVS_BasicGCDTimer)

This is an optional method that is called as the timer is suspended:

    func basicGCDTimerSuspend(_ timer: RVS_BasicGCDTimer)

This is an optional method that is called as the timer is resumed (which includes the initial start):

    func basicGCDTimerResume(_ timer: RVS_BasicGCDTimer)

## DEPENDENCIES

There are no dependencies to use RVS_BasicGCDTimer in your project. In order to test it and run it in the module project, you should use [CocoaPods](https://cocoapods.org) to install [SwiftLint](https://cocoapods.org/pods/SwiftLint), although that is not required. It's [just good practice](https://littlegreenviper.com/series/swiftwater/swiftlint/).

## LICENSE

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


[The Great Rift Valley Software Company: https://riftvalleysoftware.com](https://riftvalleysoftware.com)

