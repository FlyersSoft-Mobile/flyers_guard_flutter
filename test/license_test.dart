import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flyers_guard/flyers_guard.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('flyers_guard'),
            (call) async {
      if (call.method == 'getAppId') return 'com.example.test';
      return <String, dynamic>{};
    });
  });

  test('checks throw before initialize', () {
    expect(FlyersGuard.getRootCheckReport(),
        throwsA(isA<FlyersGuardLicenseException>()));
  });

  test('initialize never throws and gates checks on failure', () async {
    final result = await FlyersGuard.initialize(
      packageId: 'PKG-TEST',
      licenseKey: 'wrong-key',
    );
    expect(result.isValid, isFalse);
    expect(result.reason, isNotNull);
    expect(FlyersGuard.isDeviceJailbroken(),
        throwsA(isA<FlyersGuardLicenseException>()));
  });
}
