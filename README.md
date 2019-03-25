![Project Icon](icon.png)

Basic Grand Central Dispatch Timer
=

Introduction
-

This is a fundamental tool: A simple [Grand Central Dispatch](https://developer.apple.com/documentation/dispatch) timer that either fires repeatedly, or only once.

What Problem Does This Solve?
-

Timers are necessary for many different reasons. They could be the driving engine of a clock app, or a UI tool to refresh a display or close a screen.

This will allow "leeway," which Apple suggests as a way to help reduce energy usage, and is thread-independent. You can instantiate it on any queue that you want.

It's incredibly simple. Just a "set and forget," if you are firing just once, or a simple repeating callback.

Requirements
-

It should work fine for osx, tvOS and iOS. It only depends on the Swift Foundation library.

This requires Swift Version 4.0 or above (tested with 4.2).

WHERE TO GET
=

[This is the GitHub repo for the project.](https://github.com/RiftValleySoftware/RVS_BasicGCDTimer).

[Thisis the documentation page for it](https://riftvalleysoftware.com/work/open-source-projects/#RVS_BasicGCDTimer)

USAGE
=

Include the Source in Your Project
-

This is a simple source file; not a module.

To use this, simply add the [RVS_BasicGCDTimer/RVS_BasicGCDTimer.swift](https://github.com/RiftValleySoftware/RVS_BasicGCDTimer/blob/master/RVS_BasicGCDTimer/RVS_BasicGCDTimer.swift) file to your project; copying it wherever you want.

You then instantiate the timer:

Either as a one-shot timer (in this case, 100 milliseconds):

`timeIntervalInSeconds` is a double-precision floating point number, with the timer period, in seconds (not milliseconds). It is required to be a positive value over zero.

The `delegate` is required. The timer won't work at all without a valid delegate.

`leewayInMilliseconds` is the recommended "leeway" that Apple suggests that you give timers. This helps conserve energy in mobile devices.

Set `onlyFireOnce` to true in order for the timer to be a "one-shot" timer.

`someContext` is any data that you want returned to the callback in your delegate method. It will be available as the timer's `context` property.

`queue` is the GCD queue to use. Not specifying means that the default queue is used.

`isWallTime` asks the timer to use the "Apple Wall Clock" time. That time is absolute, and doesn't care about whether or not the computer sleeps or has performance breaks. It tends to be more consistent.

    newTimer = RVS_BasicGCDTimer(timeIntervalInSeconds: 0.1, delegate: someDelegate, leewayInMilliseconds: 25.0, onlyFireOnce: true, context: someContext, queue: DispatchQueue.main, isWallTime: true)

Here, we specify repeating, with no leeway, and no context data:

    newTimer = RVS_BasicGCDTimer(timeIntervalInSeconds: 0.1, delegate: someDelegate, leewayInMilliseconds: 0, onlyFireOnce: false, context: nil, queue: nil, isWallTime: false)

However, there's a lot of defaults. You can specify the exact same as such:

    newTimer = RVS_BasicGCDTimer(timeIntervalInSeconds: 0.1, delegate: someDelegate)

Once the timer is instantiated, you start it by calling `resume()`:

    newTimer.resume()

If repeating, the timer will repeat until it is invalidated or deinitialized:

    newTimer.invalidate()

If a "one-shot," then the timer is invalidated as soon as it completes.

DEPENDENCIES
=

There are no dependencies to use RVS_BasicGCDTimer in your project. In order to test it and run it in the module project, you should use [CocoaPods](https://cocoapods.org) to install [SwiftLint](https://cocoapods.org/pods/SwiftLint), although that is not required. It's [just good practice](https://littlegreenviper.com/series/swiftwater/swiftlint/).

LICENSE
=
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

