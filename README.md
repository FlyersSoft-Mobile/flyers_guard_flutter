# flyers_guard (Flutter wrapper)

A Flutter plugin that reports whether an Android device is **rooted** or an iOS
device is **jailbroken**. It is a thin [platform-channel] bridge over two
**prebuilt native binaries** — the detection logic is compiled and shipped as
binaries, so this package does **not** contain the native detection source.

| Platform | Binary (vendored here)             | Built from (private)                     |
|----------|------------------------------------|------------------------------------------|
| Android  | `android/m2repository/...aar`      | `FlyersSoft-Mobile/flyers_guard_android` |
| iOS      | `ios/Frameworks/FlyersGuard.xcframework` | `FlyersSoft-Mobile/flyers_guard_ios` |

Only Dart code and the compiled binaries are visible to consumers of this repo.

## Install

```yaml
dependencies:
  flyers_guard:
    git:
      url: https://github.com/FlyersSoft-Mobile/flyers_guard_flutter.git
      ref: v1.0.0
```

## Usage

```dart
import 'package:flyers_guard/flyers_guard.dart';

// Android
final rootReport = await FlyersGuard.getRootCheckReport();
if (rootReport.isRooted) { /* ... */ }

// iOS
final jbReport = await FlyersGuard.getJailbreakCheckReport();
if (jbReport.isJailbroken) { /* ... */ }

// Combined local + (Android) Play Integrity backend verdict
final compromised = await DeviceIntegrity().isDeviceCompromised(
  backendUrl: 'https://api.example.com/',
  projectNumber: '123456789012',
);
```

### iOS note
For the `cydia://` scheme check to be meaningful, add to the host app's
`Info.plist`:

```xml
<key>LSApplicationQueriesSchemes</key>
<array><string>cydia</string></array>
```

The Android `<queries>` block for known root-manager packages is merged into the
host manifest automatically.
