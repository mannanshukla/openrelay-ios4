# OpenRelay for iPod touch

A native iOS 4 messaging client for OpenRelay inference. Looks like 2011 Messages, talks to today'"s

open

## Building

Targets iOS 4.3 on armv7 from a modern Mac with only the Command Line Tools installed. No Xcode.

1. Get the iPhoneOS 4.3 SDK from [EachAndOther/Legacy-iOS-SDKs](https://github.com/EachAndOther/Legacy-iOS-SDKs) into `~/ios4sdk/iPhoneOS4.3.sdk`.
2. The modern linker refuses the old dylibs, so convert them to text stubs once: run `tapi stubify` from the Command Line Tools over the SDK's frameworks and retarget the `-darwin` platform strings to `-ios`.
3. `./build.sh` compiles with `clang -target armv7-apple-ios4.3 -fobjc-runtime=ios-4.3 -fno-objc-arc -marm`, pseudo-signs with `ldid -S`, and zips an IPA into `build/`. ARM mode matters: modern ld drops the Thumb bit on Objective-C method pointers for this target and the app crashes at launch without it.
4. Install on a jailbroken device with AppSync: `ideviceinstaller install build/<App>.ipa`.

Everything is hand-written Foundation and UIKit from 2011. The JSON parser is in `src/ORJSON.m` because iOS 4 has no NSJSONSerialization.

## License

MIT for the code. Third-party marks and data belong to their owners.
