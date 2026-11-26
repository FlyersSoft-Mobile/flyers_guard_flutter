## 0.3.0
- Android: new `flyers_guard/native` method channel whose handler lives in the AAR (`FlyersGuardChannel`, SDK 1.2.0). The plugin's Kotlin bridge is now a pure forwarder; the Dart API uses the new channel on Android. The legacy `flyers_guard` channel is still served.
- New `FlyersGuard.requestIntegrityToken(payload:, projectNumber:)` (Android).
- `isDeviceCompromised` takes an optional `failClosed` (Android; default `false`, same as before).
- Vendored Android SDK bumped to `flyers-guard-android:1.2.0`; plugin `compileSdk` raised to 36, which the AAR requires.

## 0.2.0
- Surface the native SDKs' new report fields (additive; existing fields unchanged):
  - Android `RootCheckReport`: `hardSignals` and `softSignals` — the verdict (`isRooted`) is now driven by hard signals only; soft signals are reported but do not decide it.
  - iOS `JailbreakCheckReport`: `isSimulator` (verdict is forced `false` on the Simulator) and `suspiciousUrlSchemesFound` (now probes `cydia`, `sileo`, `zbra`, `undecimus`).
- README updated: new fields, expanded iOS paths/schemes, Simulator behaviour, and the Android hard/soft distinction.
- Note: the new fields populate once the matching native binaries (Android AAR / iOS XCFramework carrying these fields) are re-vendored; against the current binaries they return safe defaults (empty lists / `false`).

## 0.1.0
- First feature release: Android root detection (6 checks) and iOS jailbreak detection (3 checks), shipped as a Dart bridge over prebuilt native binaries.
