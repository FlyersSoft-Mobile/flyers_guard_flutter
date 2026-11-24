/// Thin Dart bridge over the prebuilt FlyersGuard native SDKs (an Android AAR
/// and an iOS XCFramework).
///
/// This file contains **no detection logic**. Every check, every verdict and
/// the Play Integrity flow run inside the compiled binaries; the classes here
/// only forward method-channel calls and expose the booleans the native side
/// already decided.
library flyers_guard;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

part 'src/license.dart';

const MethodChannel _channel = MethodChannel('flyers_guard');

/// Android system-property findings (values and verdicts decided natively).
class SystemPropertiesFindings {
  const SystemPropertiesFindings._(this._m);
  final Map<dynamic, dynamic> _m;

  String get roDebuggable => _m['roDebuggable'] as String? ?? '';
  String get roSecure => _m['roSecure'] as String? ?? '';
  String get roBuildTags => _m['roBuildTags'] as String? ?? '';
  bool get isDebuggable => _m['isDebuggable'] as bool? ?? false;
  bool get isInsecureShell => _m['isInsecureShell'] as bool? ?? false;
  bool get hasTestKeys => _m['hasTestKeys'] as bool? ?? false;
  bool get isSuspicious => _m['isSuspicious'] as bool? ?? false;
}

/// Android build/fingerprint findings (values and verdicts decided natively).
class BuildFingerprintFindings {
  const BuildFingerprintFindings._(this._m);
  final Map<dynamic, dynamic> _m;

  String get tags => _m['tags'] as String? ?? '';
  String get type => _m['type'] as String? ?? '';
  String get fingerprint => _m['fingerprint'] as String? ?? '';
  bool get hasTestKeys => _m['hasTestKeys'] as bool? ?? false;
  bool get isDebugBuildType => _m['isDebugBuildType'] as bool? ?? false;
  bool get hasSuspiciousFingerprint => _m['hasSuspiciousFingerprint'] as bool? ?? false;
  bool get isSuspicious => _m['isSuspicious'] as bool? ?? false;
}

/// Hardware-backed verified boot state (verdict decided natively).
class VerifiedBootState {
  const VerifiedBootState._(this._m);
  final Map<dynamic, dynamic> _m;

  String get name => _m['name'] as String? ?? 'unknown';
  bool get isSuspicious => _m['isSuspicious'] as bool? ?? false;
}

/// Android root-check result. A read-only view over the native report map.
class RootCheckReport {
  const RootCheckReport._(this._m);
  final Map<dynamic, dynamic> _m;

  bool get isRooted => _m['isRooted'] as bool? ?? false;

  /// Names of the *hard* signals that fired — strong, low-false-positive
  /// evidence; any one of these decides [isRooted]. Possible values:
  /// `suBinary`, `knownRootApp`, `testKeys`, `roDebuggable`, `verifiedBootRed`.
  List<String> get hardSignals =>
      List<String>.from(_m['hardSignals'] as List? ?? const []);

  /// Names of the *soft* signals that fired — weak/ambiguous heuristics that
  /// are reported but do **not** decide [isRooted] on their own. Possible
  /// values: `shellSu`, `roSecureZero`, `debugBuildType`,
  /// `suspiciousFingerprint`, `verifiedBootOrange`.
  List<String> get softSignals =>
      List<String>.from(_m['softSignals'] as List? ?? const []);

  bool get suBinaryFound => _m['suBinaryFound'] as bool? ?? false;
  List<String> get suBinaryPathsFound =>
      List<String>.from(_m['suBinaryPathsFound'] as List? ?? const []);
  bool get knownRootAppFound => _m['knownRootAppFound'] as bool? ?? false;
  List<String> get knownRootAppsFound =>
      List<String>.from(_m['knownRootAppsFound'] as List? ?? const []);
  bool get shellSuExecutable => _m['shellSuExecutable'] as bool? ?? false;
  SystemPropertiesFindings get systemProperties =>
      SystemPropertiesFindings._((_m['systemProperties'] as Map?) ?? const {});
  BuildFingerprintFindings get buildFingerprint =>
      BuildFingerprintFindings._((_m['buildFingerprint'] as Map?) ?? const {});
  VerifiedBootState get verifiedBootState =>
      VerifiedBootState._((_m['verifiedBootState'] as Map?) ?? const {});
}

/// iOS jailbreak-check result. A read-only view over the native report map.
class JailbreakCheckReport {
  const JailbreakCheckReport._(this._m);
  final Map<dynamic, dynamic> _m;

  bool get isJailbroken => _m['isJailbroken'] as bool? ?? false;

  /// `true` when running in the iOS Simulator. The file-path check matches
  /// host-Mac binaries there, so [isJailbroken] is forced to `false` on the
  /// Simulator — use this flag to tell "clean device" from "Simulator".
  bool get isSimulator => _m['isSimulator'] as bool? ?? false;

  bool get suspiciousPathFound => _m['suspiciousPathFound'] as bool? ?? false;
  List<String> get suspiciousPathsFound =>
      List<String>.from(_m['suspiciousPathsFound'] as List? ?? const []);
  bool get sandboxWriteViolationFound => _m['sandboxWriteViolationFound'] as bool? ?? false;
  bool get cydiaUrlSchemeRegistered => _m['cydiaUrlSchemeRegistered'] as bool? ?? false;

  /// The jailbreak URL schemes that were openable (a subset of `cydia`,
  /// `sileo`, `zbra`, `undecimus`). Non-empty only when the host app declares
  /// them in `LSApplicationQueriesSchemes`. [cydiaUrlSchemeRegistered] is
  /// `true` when this is non-empty.
  List<String> get suspiciousUrlSchemesFound =>
      List<String>.from(_m['suspiciousUrlSchemesFound'] as List? ?? const []);
}

/// Entry point. Pure pass-through to the native binaries.
///
/// Call [initialize] with the package ID and license key you were issued
/// before using any check; until a valid license is confirmed every check
/// throws [FlyersGuardLicenseException].
class FlyersGuard {
  FlyersGuard._();

  static LicenseResult? _license;

  /// The result of the last [initialize] call, or `null` if never called.
  static LicenseResult? get license => _license;

  /// Validates [packageId] and [licenseKey] with the FlyersSoft license
  /// server. The app's package name (Android) / bundle ID (iOS) is sent too,
  /// so a license can be locked to specific apps.
  ///
  /// Never throws; check [LicenseResult.isValid]. Calling it again
  /// re-validates (for example after a `network_error`).
  static Future<LicenseResult> initialize({
    required String packageId,
    required String licenseKey,
  }) async {
    String? appId;
    try {
      appId = await _channel.invokeMethod<String>('getAppId');
    } on PlatformException {
      appId = null;
    } on MissingPluginException {
      appId = null;
    }
    _license = await _validateLicense(
      packageId: packageId,
      licenseKey: licenseKey,
      appId: appId,
    );
    return _license!;
  }

  static void _ensureLicensed() {
    final license = _license;
    if (license == null) {
      throw const FlyersGuardLicenseException('not_initialized');
    }
    if (!license.isValid) {
      throw FlyersGuardLicenseException(license.reason ?? 'invalid_credentials');
    }
  }

  /// Android: the full root-check report, decided natively.
  static Future<RootCheckReport> getRootCheckReport() async {
    _ensureLicensed();
    final result = await _channel.invokeMethod<Map<dynamic, dynamic>>('getRootCheckReport');
    return RootCheckReport._(result ?? const {});
  }

  /// Android: `true` if any local root signal fired.
  static Future<bool> isDeviceRooted() async => (await getRootCheckReport()).isRooted;

  /// iOS: the full jailbreak-check report, decided natively.
  static Future<JailbreakCheckReport> getJailbreakCheckReport() async {
    _ensureLicensed();
    final result = await _channel.invokeMethod<Map<dynamic, dynamic>>('getJailbreakCheckReport');
    return JailbreakCheckReport._(result ?? const {});
  }

  /// iOS: `true` if any local jailbreak signal fired.
  static Future<bool> isDeviceJailbroken() async => (await getJailbreakCheckReport()).isJailbroken;

  /// Combined verdict, decided entirely by the native SDK. On Android it
  /// additionally verifies a Play Integrity token with [backendUrl] /
  /// [projectNumber]; on iOS those are ignored and the jailbreak verdict is
  /// returned. Fail-open on the server step.
  static Future<bool> isDeviceCompromised({String? backendUrl, String? projectNumber}) async {
    _ensureLicensed();
    final result = await _channel.invokeMethod<bool>('isDeviceCompromised', {
      'backendUrl': backendUrl ?? '',
      'projectNumber': projectNumber ?? '',
    });
    return result ?? false;
  }
}
