import "package:dio/dio.dart";

class Lucas {
  var data;

  var prompt;

  var config;

  Lucas({required this.data, required this.prompt, required this.config});

  Future<bool> checkModelstatus(String modelURL) async {
    var httpClient = Dio();
    var requestStatus = await httpClient.post(modelURL);
    if (requestStatus.statusCode == 200) {
      return true;
    } else {
      return false;
    }
  }

  dynamic ask() async {
    try {
      dynamic aiResponse = "<ai_response_here>";
      final httpClient = Dio();
      var token = "sk-unsloth-e14237ecc88ead7c73a8154d37f1b090";

      var baseUrl = "http://192.168.1.90:8888/v1/chat/completions";
      final response = await httpClient.post(
        baseUrl,
        data: {
          "model": "unsloth/gpt-oss-20b-GGUF:F16",
          "messages": [
            {"role": "user", "content": "muraho neza"},
          ],
          "stream": false,
        },
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        ),
      );

      aiResponse = response.data;

      return {"prompt": prompt, "response": aiResponse};
    } catch (error) {
      return {"error": error};
    }
  }
}
