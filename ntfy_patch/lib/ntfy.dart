// You have generated a new plugin project without specifying the `--platforms`
// flag. A plugin project with no platform support was generated. To add a
// platform, run `flutter create -t plugin --platforms <platforms> .` under the
// same directory. You can also find a detailed instruction on how to add
// platforms in the `pubspec.yaml` at
// https://flutter.dev/to/pubspec-plugin-platforms.

import 'ntfy_platform_interface.dart';

class Ntfy {


  Future<void> subscribe(String url, String topic, {String? auth}) {
    return NtfyPlatform.instance.subscribe(url, topic, auth: auth);
  }

  Future<void> unsubscribe() {
    return NtfyPlatform.instance.unsubscribe();
  }

  Stream<String> get messages {
    return NtfyPlatform.instance.messages;
  }
}
