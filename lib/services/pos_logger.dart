import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'pos_extension_service.dart';

class PosLogger {
  static final PosLogger _instance = PosLogger._internal();
  factory PosLogger() => _instance;
  PosLogger._internal();

  final List<PosLogEntry> _logs = [];
  final _listeners = <VoidCallback>{};
  static const _logChannel = MethodChannel('com.kaascan/pos_logs');

  List<PosLogEntry> get logs => List.unmodifiable(_logs);

  void initialize() {
    _logChannel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'log':
          final message = call.arguments['message'] as String;
          final isError = call.arguments['isError'] as bool;
          log(message, isError: isError);
          break;
        case 'onExtensionEvent':
          final event = call.arguments['event'] as String;
          final component = call.arguments['component'] as String;
          final args = call.arguments['args'] as List;
          log('🔔 $component Event: $event ($args)');

          // Specific handling for BizaNFCRFID TagDetected events
          if (component == 'BizaNFCRFID' &&
              event == 'TagDetected' &&
              args.isNotEmpty) {
            final tagId = args[0].toString().trim();
            if (tagId.isNotEmpty) {
              log('🎯 NFC Detected: $tagId');
              PosExtensionService().handleNfcEvent(tagId, "");
            }
          }
          break;
        case 'onNfcDetected':
          final tagId = call.arguments['tagId'] as String;
          final ndefData = call.arguments['ndefData'] as String;
          log('🎯 Card Tapped: $tagId', isError: false);
          PosExtensionService().handleNfcEvent(tagId, ndefData);
          break;
      }
    });
  }

  void log(String message, {bool isError = false}) {
    final entry = PosLogEntry(
      message: message,
      timestamp: DateTime.now(),
      isError: isError,
    );
    _logs.insert(0, entry);
    if (_logs.length > 100) _logs.removeLast();
    
    debugPrint('${isError ? '❌' : 'ℹ️'} $message');
    _notify();
  }

  void clear() {
    _logs.clear();
    _notify();
  }

  void addListener(VoidCallback listener) => _listeners.add(listener);
  void removeListener(VoidCallback listener) => _listeners.remove(listener);

  void _notify() {
    for (final l in _listeners) {
      l();
    }
  }
}

class PosLogEntry {
  final String message;
  final DateTime timestamp;
  final bool isError;

  PosLogEntry({
    required this.message,
    required this.timestamp,
    this.isError = false,
  });
}
