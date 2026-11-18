import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'ntfy_method_channel.dart';

abstract class NtfyPlatform extends PlatformInterface {
  /// Constructs a NtfyPlatform.
  NtfyPlatform() : super(token: _token);

  static final Object _token = Object();

  static NtfyPlatform _instance = MethodChannelNtfy();

  /// The default instance of [NtfyPlatform] to use.
  ///
  /// Defaults to [MethodChannelNtfy].
  static NtfyPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [NtfyPlatform] when
  /// they register themselves.
  static set instance(NtfyPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }



  Future<void> subscribe(String url, String topic, {String? auth}) {
    throw UnimplementedError('subscribe() has not been implemented.');
  }

  Future<void> unsubscribe() {
    throw UnimplementedError('unsubscribe() has not been implemented.');
  }

  Stream<String> get messages {
    throw UnimplementedError('messages() has not been implemented.');
  }
}
