import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Input capabilities, not layout breakpoints. Layout still follows width.
abstract final class DeviceCapabilities {
  static const _channel = MethodChannel('pl.otherradio/device');

  static Future<bool> isTelevision() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return false;
    return await _channel.invokeMethod<bool>('isTelevision') ?? false;
  }
}
