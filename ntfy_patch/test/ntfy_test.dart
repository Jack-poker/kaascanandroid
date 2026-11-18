import 'package:flutter_test/flutter_test.dart';

import 'package:ntfy/ntfy_platform_interface.dart';
import 'package:ntfy/ntfy_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockNtfyPlatform
    with MockPlatformInterfaceMixin
    implements NtfyPlatform {
  @override
  Future<void> subscribe(String url, String topic, {String? auth}) => Future.value();

  @override
  Future<void> unsubscribe() => Future.value();

  @override
  Stream<String> get messages => const Stream.empty();
}

void main() {
  final NtfyPlatform initialPlatform = NtfyPlatform.instance;

  test('$MethodChannelNtfy is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelNtfy>());
  });

}
