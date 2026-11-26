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
| 1 | File & path detection | Jailbreak apps and tooling — Cydia / Sileo / Zebra, MobileSubstrate, rootless `/var/jb`, `sshd` / `ssh` / `bash`, apt dirs |
| 2 | Sandbox violation | Tries to write a file outside the app sandbox (`/private/jailbreak.test`) |
| 3 | Custom URL scheme probing | Whether a jailbreak handler (`cydia`, `sileo`, `zbra`, `undecimus`) is registered |

**The verdict.** On **iOS**, the device is reported as jailbroken if **any
single check** fires. On **Android**, the verdict (`isRooted`) is driven by
*hard* signals only (strong, low-false-positive evidence); *soft* signals
(weak/ambiguous heuristics) are reported separately so a single weak heuristic
can never lock out a legitimate user — see the breakdown below. A clean,
unmodified retail device returns `false` / empty for every check. On the iOS
Simulator the verdict is always `false` (see the Simulator note).


---

## Installation

### 1. Add the dependency

In your app's `pubspec.yaml`:

```yaml
dependencies:
  flyers_guard:
    git:
      url: https://github.com/FlyersSoft-Mobile/flyers_guard_flutter.git
      ref: v0.1.0
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
  <string>sileo</string>
  <string>zbra</string>
  <string>undecimus</string>
</array>
```

Without these entries iOS always reports the schemes as unregistered, so that
one check silently does nothing. Minimum deployment target: **iOS 12**. After
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

report.isRooted;                              // overall verdict (hard signals only)
report.hardSignals;                           // e.g. [suBinary, testKeys] — these decide isRooted
report.softSignals;                           // e.g. [verifiedBootOrange] — reported, not deciding
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

report.isJailbroken;                 // overall verdict (always false on the Simulator)
report.isSimulator;                  // bool — true in the iOS Simulator
report.suspiciousPathFound;          // bool
report.suspiciousPathsFound;         // e.g. [/Applications/Cydia.app]
report.sandboxWriteViolationFound;   // bool
report.cydiaUrlSchemeRegistered;     // bool
report.suspiciousUrlSchemesFound;    // e.g. [cydia, sileo]
```

### What each value means

A normal, unmodified device returns `false` / empty / `green` for all of these.

**Android**

| Value | Meaning · suspicious when |
|-------|---------------------------|
| `isRooted` | Overall verdict — `true` if any **hard** signal fired. |
| `hardSignals` | The hard signals that fired (`suBinary`, `knownRootApp`, `testKeys`, `roDebuggable`, `verifiedBootRed`). Any one of these makes `isRooted` true. |
| `softSignals` | Weak/ambiguous signals that fired (`shellSu`, `roSecureZero`, `debugBuildType`, `suspiciousFingerprint`, `verifiedBootOrange`). Reported for your own policy; they do **not** set `isRooted` alone. |
| `suBinaryFound` / `suBinaryPathsFound` | The `su` (superuser) program exists on the device. Stock Android does not ship it. Suspicious when found. |
| `knownRootAppFound` / `knownRootAppsFound` | A root-manager app (Magisk, SuperSU, KingRoot…) is installed. |
| `shellSuExecutable` | The app could actually run `su` and gain root. Catches a hidden `su` that still works. |
| `systemProperties.isSuspicious` | OS build flags indicate a debug/insecure or custom-signed image (`ro.debuggable=1`, `ro.secure=0`, or `test-keys`). |
| `buildFingerprint.isSuspicious` | The build identity looks like a debug/engineering or non-official build (`userdebug`/`eng`, `test-keys`, `generic…`). |
| `verifiedBootState` | Boot-time integrity from the bootloader. `orange` (bootloader unlocked) and `red` (verification failed) are suspicious; `green`/`yellow` are fine. |

**iOS**

| Value | Meaning · suspicious when |
|-------|---------------------------|
| `isJailbroken` | Overall verdict — `true` if any check below fires. Always `false` on the Simulator. |
| `isSimulator` | `true` when running in the iOS Simulator. Lets you tell a genuinely clean device from a Simulator run. |
| `suspiciousPathFound` / `suspiciousPathsFound` | Files that exist only on jailbroken devices were found (Cydia / Sileo / Zebra, MobileSubstrate, rootless `/var/jb`, sshd…). |
| `sandboxWriteViolationFound` | The app could write outside its sandbox — iOS normally forbids this. A strong jailbreak signal. |
| `cydiaUrlSchemeRegistered` / `suspiciousUrlSchemesFound` | Something can open a jailbreak app-store scheme (`cydia`, `sileo`, `zbra`, `undecimus`). Requires the `Info.plist` entries above. |

> **iOS Simulator note:** on the Simulator the file-path check matches real
> host-Mac binaries (`/usr/sbin/sshd`, `/usr/bin/ssh`), because Simulator apps
> run as native macOS processes. To avoid a guaranteed false positive,
> `isJailbroken` is forced to `false` on the Simulator and `isSimulator` is set
> to `true` — the raw `suspiciousPathsFound` list is still populated. Always
> validate the "not jailbroken" path on a **real, non-jailbroken iPhone**.

---

## API summary

| Method | Platform | Returns |
|--------|----------|---------|
| `FlyersGuard.isDeviceRooted()` | Android | `Future<bool>` |
| `FlyersGuard.getRootCheckReport()` | Android | `Future<RootCheckReport>` |
| `FlyersGuard.isDeviceJailbroken()` | iOS | `Future<bool>` |
| `FlyersGuard.getJailbreakCheckReport()` | iOS | `Future<JailbreakCheckReport>` |
| `FlyersGuard.isDeviceCompromised({backendUrl, projectNumber, failClosed})` | Android, iOS | `Future<bool>` |
| `FlyersGuard.requestIntegrityToken({payload, projectNumber})` | Android | `Future<String>` (Play Integrity token) |

### How Android calls reach the SDK

On Android the Dart API talks to the `flyers_guard/native` method channel. Its
handler, `com.flyerssoft.guard.FlyersGuardChannel`, ships **inside the AAR**:
it owns the method keys, argument keys, threading and error codes. The
plugin's Kotlin class only forwards each call's method key and arguments to
it. Errors arrive as `PlatformException` with code `INVALID_ARGUMENT`,
`TOKEN_FAILED` or `INTERNAL`. The legacy `flyers_guard` channel is still
served (and is what iOS uses).

## Requirements

- Flutter `>= 3.10`, Dart `>= 3.0`
- Android `minSdk 21`, `compileSdk 36` (required by the vendored AAR)
- iOS `12.0+`
