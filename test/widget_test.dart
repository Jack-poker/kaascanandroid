import 'package:flutter_test/flutter_test.dart';
import 'package:kaascan/sdk/ai.dart';

void main() {
  final model = Lucas(
    data: "<data>",
    prompt: "Hello, how re you doing?",
    config: "<model_config>",
  );

  final repsonse = model.ask();

  print(repsonse);
}
