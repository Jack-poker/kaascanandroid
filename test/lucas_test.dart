import 'package:flutter_test/flutter_test.dart';
import 'package:kaascan/sdk/ai.dart';
import 'dart:convert';

void main() {
  test('Lucas.ask returns a non-empty response', () async {
    final model = Lucas(data: "", prompt: "hello,there", config: "");
    final response = await model.ask();

    // ignore: avoid_print
    print(JsonEncoder.withIndent('  ').convert(response));

    expect(response, isNotNull);
    expect(response.toString(), isNotEmpty);
  });
}