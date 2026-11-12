# flyers_guard

A Flutter plugin that tells your app whether the device it is running on is
**rooted** (Android) or **jailbroken** (iOS).

Root/jailbreak removes the restrictions the operating system normally enforces,
so a compromised device can read another app's private data, bypass security
controls, or tamper with your app at runtime. `flyers_guard` runs a set of
on-device checks and gives you a clear verdict plus a per-check breakdown, so
your app can decide how to react (for example, warn the user or block
sensitive features).


---

## What it detects

### Android — root detection (6 checks)

| # | Check | What it looks at |
|---|-------|-------------------|
| 1 | SU binary existence | `su` program at `/system/bin/su`, `/xbin/su`, `/sbin/su` |
| 2 | Known root-manager apps | Magisk, SuperSU, KingRoot / KingoRoot package IDs |
| 3 | Shell `su` execution test | Tries to actually run `su` and gain elevated access |
| 4 | System properties | `ro.debuggable`, `ro.secure`, `ro.build.tags` |
| 5 | Build fingerprinting | `Build.TYPE`, `Build.TAGS`, `Build.FINGERPRINT` |
| 6 | Verified boot state | `ro.boot.verifiedbootstate` → green / yellow / orange / red |

### iOS — jailbreak detection (3 checks)

| # | Check | What it looks at |
|---|-------|-------------------|
| 1 | File & path detection | `/Applications/Cydia.app`, `MobileSubstrate.dylib`, `/usr/sbin/sshd`, `/usr/bin/ssh`, `/etc/apt` |
| 2 | Sandbox violation | Tries to write a file outside the app sandbox (`/private/jailbreak.test`) |
| 3 | Custom URL scheme probing | Whether a `cydia://` handler is registered |

**The verdict.** The device is reported as rooted / jailbroken if **any single
check** fires (defense in depth). A clean, unmodified retail device returns
`false` for every check.


---

## Installation

### 1. Add the dependency

In your app's `pubspec.yaml`:

```yaml
dependencies:
  flyers_guard:
    git:
      url: https://github.com/FlyersSoft-Mobile/flyers_guard_flutter.git
      ref: v1.1.2
```

Then fetch it:

```bash
flutter pub get
```

That is all that is required on Android — the plugin's native library and the
package-visibility rules it needs (to detect the known root-manager apps on
Android 11+) are merged into your app automatically.

### 2. iOS setup (one extra step)

For the `cydia://` scheme check to work, declare the scheme in your app's
`ios/Runner/Info.plist`:

```xml
<key>LSApplicationQueriesSchemes</key>
<array>
  <string>cydia</string>
</array>
```

Without this entry iOS always reports the scheme as unregistered, so that one
check silently does nothing. Minimum deployment target: **iOS 12**. After
adding the dependency, run `pod install` in `ios/` if your setup does not do it
automatically.

---

## Usage

Import the package and call the check for the platform you are on. Android
methods run on Android, iOS methods on iOS — guard with `Platform.isAndroid` /
`Platform.isIOS` from `dart:io`.

```dart
import 'dart:io' show Platform;
import 'package:flyers_guard/flyers_guard.dart';

Future<void> runSecurityCheck() async {
  if (Platform.isAndroid) {
    final bool rooted = await FlyersGuard.isDeviceRooted();
    if (rooted) {
      // Warn the user or block sensitive features.
    }
  } else if (Platform.isIOS) {
    final bool jailbroken = await FlyersGuard.isDeviceJailbroken();
    if (jailbroken) {
      // Warn the user or block sensitive features.
    }
  }
}
```

### Full per-check breakdown

Use the report objects when you want to know *which* check fired and show it to
the user.

**Android**

```dart
final RootCheckReport report = await FlyersGuard.getRootCheckReport();

report.isRooted;                              // overall verdict
report.suBinaryFound;                         // bool
report.suBinaryPathsFound;                    // e.g. [/system/bin/su]
report.knownRootAppFound;                     // bool
report.knownRootAppsFound;                    // e.g. [com.topjohnwu.magisk]
report.shellSuExecutable;                     // bool
report.systemProperties.isSuspicious;         // bool (ro.debuggable/ro.secure/tags)
report.buildFingerprint.isSuspicious;         // bool (TYPE/TAGS/FINGERPRINT)
report.verifiedBootState.name;                // "green" | "yellow" | "orange" | "red" | "unknown"
report.verifiedBootState.isSuspicious;        // true for orange / red
```

**iOS**

```dart
final JailbreakCheckReport report = await FlyersGuard.getJailbreakCheckReport();

report.isJailbroken;                 // overall verdict
report.suspiciousPathFound;          // bool
report.suspiciousPathsFound;         // e.g. [/Applications/Cydia.app]
report.sandboxWriteViolationFound;   // bool
report.cydiaUrlSchemeRegistered;     // bool
```

### What each value means

A normal, unmodified device returns `false` / empty / `green` for all of these.

**Android**

| Value | Meaning · suspicious when |
|-------|---------------------------|
| `isRooted` | Overall verdict — `true` if any check below fires. |
| `suBinaryFound` / `suBinaryPathsFound` | The `su` (superuser) program exists on the device. Stock Android does not ship it. Suspicious when found. |
| `knownRootAppFound` / `knownRootAppsFound` | A root-manager app (Magisk, SuperSU, KingRoot…) is installed. |
| `shellSuExecutable` | The app could actually run `su` and gain root. Catches a hidden `su` that still works. |
| `systemProperties.isSuspicious` | OS build flags indicate a debug/insecure or custom-signed image (`ro.debuggable=1`, `ro.secure=0`, or `test-keys`). |
| `buildFingerprint.isSuspicious` | The build identity looks like a debug/engineering or non-official build (`userdebug`/`eng`, `test-keys`, `generic…`). |
| `verifiedBootState` | Boot-time integrity from the bootloader. `orange` (bootloader unlocked) and `red` (verification failed) are suspicious; `green`/`yellow` are fine. |

**iOS**

| Value | Meaning · suspicious when |
|-------|---------------------------|
| `isJailbroken` | Overall verdict — `true` if any check below fires. |
| `suspiciousPathFound` / `suspiciousPathsFound` | Files that exist only on jailbroken devices were found (Cydia, MobileSubstrate, sshd…). |
| `sandboxWriteViolationFound` | The app could write outside its sandbox — iOS normally forbids this. A strong jailbreak signal. |
| `cydiaUrlSchemeRegistered` | Something can open `cydia://` links (the jailbreak app store). Requires the `Info.plist` entry above. |

> **iOS Simulator note:** on the Simulator the file-path check almost always
> reports a *false positive* — `/usr/sbin/sshd` and `/usr/bin/ssh` are real
> binaries on the host Mac, because Simulator apps run as native macOS
> processes. Always validate the "not jailbroken" path on a **real,
> non-jailbroken iPhone**.

---

## API summary

| Method | Platform | Returns |
|--------|----------|---------|
| `FlyersGuard.isDeviceRooted()` | Android | `Future<bool>` |
| `FlyersGuard.getRootCheckReport()` | Android | `Future<RootCheckReport>` |
| `FlyersGuard.isDeviceJailbroken()` | iOS | `Future<bool>` |
| `FlyersGuard.getJailbreakCheckReport()` | iOS | `Future<JailbreakCheckReport>` |

## Requirements

- Flutter `>= 3.10`, Dart `>= 3.0`
- Android `minSdk 21`
- iOS `12.0+`
