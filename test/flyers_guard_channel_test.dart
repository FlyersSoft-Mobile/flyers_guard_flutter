import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flyers_guard/flyers_guard.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const native = MethodChannel('flyers_guard/native');
  const legacy = MethodChannel('flyers_guard');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  late List<String> calls;

  void mock(MethodChannel channel, Object? Function(MethodCall) reply) {
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add('${channel.name}:${call.method}:${call.arguments}');
      return reply(call);
    });
  }

  setUp(() => calls = []);

  tearDown(() {
    messenger.setMockMethodCallHandler(native, null);
    messenger.setMockMethodCallHandler(legacy, null);
    debugDefaultTargetPlatformOverride = null;
  });

  test('getRootCheckReport goes through the native channel', () async {
    mock(native, (_) => {'isRooted': true, 'hardSignals': ['suBinary']});

    final report = await FlyersGuard.getRootCheckReport();

    expect(report.isRooted, isTrue);
    expect(report.hardSignals, ['suBinary']);
    expect(calls, ['flyers_guard/native:getRootCheckReport:null']);
  });

  test('isDeviceCompromised uses the native channel on Android', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    mock(native, (_) => true);

    final compromised = await FlyersGuard.isDeviceCompromised(
      backendUrl: 'https://api.example.com',
      projectNumber: '123',
      failClosed: true,
    );

    expect(compromised, isTrue);
    expect(calls, [
      'flyers_guard/native:isDeviceCompromised:'
          '{backendUrl: https://api.example.com, projectNumber: 123, failClosed: true}',
    ]);
  });

  test('isDeviceCompromised uses the legacy channel on iOS', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    mock(legacy, (_) => false);

    expect(await FlyersGuard.isDeviceCompromised(), isFalse);
    expect(calls.single, startsWith('flyers_guard:isDeviceCompromised:'));
  });

  test('requestIntegrityToken sends payload and project number', () async {
    mock(native, (_) => 'token-abc');

    final token = await FlyersGuard.requestIntegrityToken(
      payload: 'nonce:1',
      projectNumber: '123',
    );

    expect(token, 'token-abc');
    expect(calls, [
      'flyers_guard/native:requestIntegrityToken:{payload: nonce:1, projectNumber: 123}',
    ]);
  });

  test('requestIntegrityToken surfaces native errors', () async {
    messenger.setMockMethodCallHandler(native, (_) async {
      throw PlatformException(code: 'TOKEN_FAILED', details: 'PLAY_ERR');
    });

    expect(
      () => FlyersGuard.requestIntegrityToken(payload: 'p', projectNumber: '1'),
      throwsA(isA<PlatformException>()
          .having((e) => e.code, 'code', 'TOKEN_FAILED')),
    );
  });
}
