import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'ntfy_platform_interface.dart';

/// An implementation of [NtfyPlatform] that uses method channels.
class MethodChannelNtfy extends NtfyPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('ntfy');



  @override
  Future<void> subscribe(String url, String topic, {String? auth}) async {
    await methodChannel.invokeMethod('subscribe', {
      'url': url,
      'topic': topic,
      'auth': auth,
    });
  }

  @override
  Future<void> unsubscribe() async {
    await methodChannel.invokeMethod('unsubscribe');
  }

  final _eventChannel = const EventChannel('ntfy_events');

  @override
  Stream<String> get messages {
    return _eventChannel.receiveBroadcastStream().map((event) => event as String);
  }
}
