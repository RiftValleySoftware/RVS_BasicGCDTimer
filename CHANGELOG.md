**Version 1.8.0** *September 13, 2026*
- Synchronized timer state and property storage to prevent concurrent pause/resume/invalidation from unbalancing the dispatch source.
- Made invalidation idempotent and reentrant, including cancellation before the first start. Cancelled instances cannot restart.
- Prevented recursive cancellation completions and suppressed event completion after delegate-driven invalidation. One-shot delivery no longer reports a subsequent cancellation.
- Balanced suspended-source cleanup and removed client callbacks during deinitialization.
- Corrected delegate removal when a completion remains, and made `isRunning` use the same checked transitions and notifications as `resume()` and `pause()`.
- Validate intervals and leeway before scheduling, including nonfinite values and overflow; retain support for long delays on 32-bit watchOS. Apply leeway to one-shot timers as well as repeating timers.
- Capture schedule settings at the first resume and ignore later changes. Completion, delegate, and context remain editable until invalidation.
- Removed library debug logging, including descriptions of delegate objects.
- Rewrote DocC, Quick Help, and README guidance for ownership, callback queues, cancellation, timing, concurrency, and migration.
- Replaced seven broad/flaky tests with focused regression coverage that actually exercises repeating timers and concurrent control.
- Added regression tests for removing delegates from started timers, with and without a remaining completion, and enabled coverage collection in the macOS library scheme.
- Raised minimum iOS/iPadOS support to 15. Updated Xcode library targets to macOS 12, tvOS 15, and watchOS 9, and test targets to the SDK-recommended minimums for Xcode 27 compatibility; other Swift package platform minimums are unchanged.
- Moved the privacy manifest into the Swift package target and included it as a resource. Documented resource integration for Xcode static archives and direct-source consumers.

**Version 1.7.3** *February 17, 2026*
- Documentation changes. No functional changes.

**Version 1.7.2** *March 17, 2025*
- Fixed a crash, that can occur, if `resume()` is called on an already running timer.

**Version 1.7.0** *October 15, 2022*
- I changed the timer to be a full optional (I don't like implicit optionals).
- Improved the documentation.
- Do concrete checks for either delegate or completion.
- Allow delegate to be omitted.
- Improved tests.
- `onlyFireOnce` is now default true.

**Version 1.6.0** *October 15, 2022*
- Updated the tools.
- Added a completion to the default initializer, for a simpler use case.
- I had to remove Swiftlint (boo hiss). It looks like the tool did not survive the transition to the new Xcode.

**Version 1.5.2** *September 16, 2022*
- Updated tools. No API changes.

**Version 1.5.1** *September 11, 2022*

- Documentation updates.

**Version 1.5.0** *May 31, 2022*

- Renamed the product in the package file.

**Version 1.4.2** *May 20, 2022*

- Just to be a completionist, I added tests and builds for all the platforms.
- I also stretched a couple of timeouts, for possibly clunkier tests.

**Version 1.4.1** *May 20, 2022*

- Just reduced the OS requirements, as there's no need to have them so tight.

**Version 1.4.0** *May 8, 2022*

- Made the class Equatable.

**Version 1.3.6** *March 15, 2022*

- Updated to latest tools. No code changes.

**Version 1.3.5** *January 27, 2022*

- Added support for DocC. No code changes.

**Version 1.3.4** *December 24, 2021*

- Updated for the latest toolchains.

**Version 1.3.3** *September 23, 2021*

- Updated for the latest toolchains.

**Version 1.3.2** *June 16, 2021*

- Updated to latest of everything

**Version 1.3.1** *July 31, 2020*

- Switched structure to enable GitHub Swift Action

**Version 1.3.0** *July 5, 2020*

- Switched to a static library.

**Version 1.2.1** *June 19, 2020*

- Added SPM support.

**Version 1.2.0** *May 26, 2020*

- Removed the CocoaPods stuff.
- Removed a looping Cartfile (copy/pasta error).
- Made the Jazzy and Carthage stuff into .command files.
- Tweaked the version.
- Re-ran docs.
