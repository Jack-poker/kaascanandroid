import 'package:flutter/foundation.dart';

/// Represents a single chat message in the conversation.
class ChatMessage {
  final String role; // 'user' or 'ai'
  final String text;
  final DateTime timestamp;
  final Map<dynamic, dynamic>? askResponse;

  ChatMessage({
    required this.role,
    required this.text,
    DateTime? timestamp,
    this.askResponse,
  }) : timestamp = timestamp ?? DateTime.now();

  bool get isUser => role == 'user';
  bool get isAi => role == 'ai';
}

class ValuesProvider extends ChangeNotifier {
  // Conversation history
  final List<ChatMessage> _messages = [];
  List<ChatMessage> get messages => List.unmodifiable(_messages);

  // Legacy fields for backward compatibility
  String reload_amount = "";
  dynamic ask_repsonse = {};
  bool waiting_ask = false;

  /// Add a user message to the conversation
  void addUserMessage(String text) {
    _messages.add(ChatMessage(role: 'user', text: text));
    waiting_ask = true;
    notifyListeners();
  }

  /// Add an AI response message to the conversation
  void addAiResponse(Map<dynamic, dynamic> response) {
    final text = response["ask_response"]?.toString() ?? "";
    _messages.add(ChatMessage(
      role: 'ai',
      text: text,
      askResponse: response,
    ));
    ask_repsonse = response;
    waiting_ask = false;
    notifyListeners();
  }

  /// Handle AI error
  void addAiError(String errorText) {
    _messages.add(ChatMessage(
      role: 'ai',
      text: errorText,
    ));
    waiting_ask = false;
    notifyListeners();
  }

  void updateWaitingask(bool waiting) {
    waiting_ask = waiting;
    notifyListeners();
  }

  void updateaskResponse(dynamic response) {
    ask_repsonse = response;
    notifyListeners();
  }

  void updateAmount(String amount) {
    reload_amount = amount;
    notifyListeners();
  }
}
