## Unreleased
- **Breaking:** license validation. Call `FlyersGuard.initialize(packageId:, clientId:, licenseKey:)` before any check; it validates against the FlyersSoft Supabase backend (`validate_package` RPC) and returns a `LicenseResult`. A license is identified by package ID + client ID + key: many clients share one package ID. Checks throw `FlyersGuardLicenseException` until a valid license is confirmed.
- New native method `getAppId` (Android package name / iOS bundle ID), sent with the validation so licenses can be locked to specific apps.

## 0.2.0
- Surface the native SDKs' new report fields (additive; existing fields unchanged):
  - Android `RootCheckReport`: `hardSignals` and `softSignals` — the verdict (`isRooted`) is now driven by hard signals only; soft signals are reported but do not decide it.
  - iOS `JailbreakCheckReport`: `isSimulator` (verdict is forced `false` on the Simulator) and `suspiciousUrlSchemesFound` (now probes `cydia`, `sileo`, `zbra`, `undecimus`).
- README updated: new fields, expanded iOS paths/schemes, Simulator behaviour, and the Android hard/soft distinction.
- Note: the new fields populate once the matching native binaries (Android AAR / iOS XCFramework carrying these fields) are re-vendored; against the current binaries they return safe defaults (empty lists / `false`).

## 0.1.0
- First feature release: Android root detection (6 checks) and iOS jailbreak detection (3 checks), shipped as a Dart bridge over prebuilt native binaries.
