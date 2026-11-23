import 'package:flutter/foundation.dart';

/// A file or photo the parent attached to a question.
class ChatAttachment {
  final String name;
  final String mime;
  final Uint8List bytes;

  const ChatAttachment({
    required this.name,
    required this.mime,
    required this.bytes,
  });

  bool get isImage => mime.startsWith('image/');
}

/// Represents a single chat message in the conversation.
class ChatMessage {
  final String role; // 'user' or 'ai'
  final String text;
  final DateTime timestamp;
  final Map<dynamic, dynamic>? askResponse;
  final List<ChatAttachment> attachments;
  /// The child's message the parent asked Soma about (shown as a chip).
  final Map<String, dynamic>? quote;

  ChatMessage({
    required this.role,
    required this.text,
    DateTime? timestamp,
    this.askResponse,
    this.attachments = const [],
    this.quote,
  }) : timestamp = timestamp ?? DateTime.now();

  bool get isUser => role == 'user';
  bool get isAi => role == 'ai';
}

class ValuesProvider extends ChangeNotifier {
  /// Identifies this conversation in chat history, however many chat views
  /// (AI tab, pop-up sheet) show it.
  String get sessionId => _sessionId;
  String _sessionId = DateTime.now().millisecondsSinceEpoch.toString();

  // Conversation history
  final List<ChatMessage> _messages = [];
  List<ChatMessage> get messages => List.unmodifiable(_messages);

  // Legacy fields for backward compatibility
  String reload_amount = "";
  dynamic ask_repsonse = {};
  bool waiting_ask = false;

  /// Add a user message to the conversation
  void addUserMessage(String text, {List<ChatAttachment> attachments = const [], Map<String, dynamic>? quote}) {
    _messages.add(ChatMessage(role: 'user', text: text, attachments: attachments, quote: quote));
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

  /// Starts a fresh conversation. The current one is already in history.
  void startNewChat() {
    _messages.clear();
    waiting_ask = false;
    ask_repsonse = {};
    _sessionId = DateTime.now().millisecondsSinceEpoch.toString();
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
