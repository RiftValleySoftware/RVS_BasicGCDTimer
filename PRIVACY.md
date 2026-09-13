# Privacy Declaration

RVS_BasicGCDTimer schedules local callbacks. The library does not collect or transmit data, access files or preferences, or emit debug logging. Its optional context and completion are held in memory and released on invalidation or deinitialization, subject to any references retained by the calling application.

The calling application controls the work performed by delegates and completions, and is responsible for that work's privacy behavior. The library's declaration does not describe the application's own data use.

The Swift package includes `Sources/RVS_BasicGCDTimer/PrivacyInfo.xcprivacy` as a resource. Static Xcode archives contain no resources; direct-source and archive consumers should include the manifest in their application's resource/manifest arrangement.
