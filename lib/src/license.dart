part of '../flyers_guard.dart';

/// Supabase project that holds the `package_licenses` table and the
/// `validate_package` RPC function.
const String _supabaseUrl = 'https://tdmukhnekbxpoqootmzw.supabase.co';

/// The project's **anon / publishable** key (Project Settings → API Keys).
/// It is safe to ship in the package. Never put the service_role / secret
/// key here.
const String _supabaseAnonKey = 'sb_publishable_3TDmLzphHzJCyt1hbSYqEQ_8net2wqV';

const Duration _licenseTimeout = Duration(seconds: 10);

/// Result of validating a package ID + license key against the backend.
class LicenseResult {
  const LicenseResult._({
    required this.isValid,
    this.reason,
    this.clientName,
    this.expiresAt,
  });

  /// `true` when the backend accepted the package ID and key.
  final bool isValid;

  /// Why validation failed, when [isValid] is `false`. One of
  /// `invalid_credentials`, `revoked`, `expired`, `app_not_allowed`,
  /// `not_configured`, `network_error`, `server_error`.
  final String? reason;

  /// The client name registered for this license.
  final String? clientName;

  /// When the license expires, or `null` if it never does.
  final DateTime? expiresAt;

  @override
  String toString() => isValid
      ? 'LicenseResult(valid, client: $clientName, expiresAt: $expiresAt)'
      : 'LicenseResult(invalid, reason: $reason)';
}

/// Thrown by the FlyersGuard checks when [FlyersGuard.initialize] has not
/// been called or did not return a valid license.
class FlyersGuardLicenseException implements Exception {
  const FlyersGuardLicenseException(this.reason);

  /// `not_initialized`, or the [LicenseResult.reason] of the failed check.
  final String reason;

  @override
  String toString() => 'FlyersGuardLicenseException: $reason';
}

/// Calls the Supabase `validate_package` RPC. Never throws: every failure is
/// returned as an invalid [LicenseResult] with a [LicenseResult.reason].
Future<LicenseResult> _validateLicense({
  required String packageId,
  required String licenseKey,
  required String? appId,
}) async {
  if (_supabaseAnonKey.startsWith('PASTE_')) {
    return const LicenseResult._(isValid: false, reason: 'not_configured');
  }

  final client = HttpClient()..connectionTimeout = _licenseTimeout;
  try {
    final request = await client
        .postUrl(Uri.parse('$_supabaseUrl/rest/v1/rpc/validate_package'))
        .timeout(_licenseTimeout);
    request.headers
      ..set('apikey', _supabaseAnonKey)
      ..set('Authorization', 'Bearer $_supabaseAnonKey')
      ..contentType = ContentType.json;
    request.write(jsonEncode({
      'p_package_id': packageId,
      'p_key': licenseKey,
      'p_app_id': appId,
    }));

    final response = await request.close().timeout(_licenseTimeout);
    final body =
        await response.transform(utf8.decoder).join().timeout(_licenseTimeout);
    if (response.statusCode != HttpStatus.ok) {
      return const LicenseResult._(isValid: false, reason: 'server_error');
    }

    final json = jsonDecode(body);
    if (json is! Map<String, dynamic>) {
      return const LicenseResult._(isValid: false, reason: 'server_error');
    }
    if (json['valid'] != true) {
      return LicenseResult._(
        isValid: false,
        reason: json['reason'] as String? ?? 'invalid_credentials',
      );
    }
    final expires = json['expires_at'] as String?;
    return LicenseResult._(
      isValid: true,
      clientName: json['client'] as String?,
      expiresAt: expires == null ? null : DateTime.tryParse(expires),
    );
  } on FormatException {
    return const LicenseResult._(isValid: false, reason: 'server_error');
  } catch (_) {
    // SocketException, TimeoutException, HttpException, ...
    return const LicenseResult._(isValid: false, reason: 'network_error');
  } finally {
    client.close(force: true);
  }
}
