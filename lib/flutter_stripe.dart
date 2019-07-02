import 'dart:async';

import 'package:flutter/services.dart';

class FlutterStripe {
  static const MethodChannel _channel =
      const MethodChannel('flutter_stripe');

  static Future<String> get platformVersion async {
    final String version = await _channel.invokeMethod('getPlatformVersion');
    return version;
  }
}