import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:other_radio/core/device_capabilities.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('pl.otherradio/device');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    messenger.setMockMethodCallHandler(channel, null);
  });
  test('Android TV input mode comes from native device capabilities', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    for (final television in [true, false]) {
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'isTelevision');
        return television;
      });
      expect(await DeviceCapabilities.isTelevision(), television);
    }
  });
  test('desktop does not require the Android device channel', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    expect(await DeviceCapabilities.isTelevision(), isFalse);
  });
}
