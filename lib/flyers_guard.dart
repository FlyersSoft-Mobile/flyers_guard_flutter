/// Thin Dart bridge over the prebuilt FlyersGuard native SDKs (an Android AAR
/// and an iOS XCFramework).
///
/// This file contains **no detection logic**. Every check, every verdict and
/// the Play Integrity flow run inside the compiled binaries; the classes here
/// only forward method-channel calls and expose the booleans the native side
/// already decided.
library flyers_guard;

import 'package:flutter/services.dart';

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
  bool get suspiciousPathFound => _m['suspiciousPathFound'] as bool? ?? false;
  List<String> get suspiciousPathsFound =>
      List<String>.from(_m['suspiciousPathsFound'] as List? ?? const []);
  bool get sandboxWriteViolationFound => _m['sandboxWriteViolationFound'] as bool? ?? false;
  bool get cydiaUrlSchemeRegistered => _m['cydiaUrlSchemeRegistered'] as bool? ?? false;
}

/// Entry point. Pure pass-through to the native binaries.
class FlyersGuard {
  FlyersGuard._();

  /// Android: the full root-check report, decided natively.
  static Future<RootCheckReport> getRootCheckReport() async {
    final result = await _channel.invokeMethod<Map<dynamic, dynamic>>('getRootCheckReport');
    return RootCheckReport._(result ?? const {});
  }

  /// Android: `true` if any local root signal fired.
  static Future<bool> isDeviceRooted() async => (await getRootCheckReport()).isRooted;

  /// iOS: the full jailbreak-check report, decided natively.
  static Future<JailbreakCheckReport> getJailbreakCheckReport() async {
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
    final result = await _channel.invokeMethod<bool>('isDeviceCompromised', {
      'backendUrl': backendUrl ?? '',
      'projectNumber': projectNumber ?? '',
    });
    return result ?? false;
  }
}
