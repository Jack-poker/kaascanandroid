import 'package:flutter/material.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'pos_logger.dart';

class NfcReaderService {
  static final NfcReaderService _instance = NfcReaderService._internal();
  factory NfcReaderService() => _instance;
  NfcReaderService._internal();

  bool _isAvailable = false;
  bool get isAvailable => _isAvailable;

  Future<bool> initialize() async {
    try {
      PosLogger().log('📱 Checking NFC Availability...');
      _isAvailable = await NfcManager.instance.isAvailable();
      PosLogger().log('📱 NFC Available: $_isAvailable');
      return _isAvailable;
    } catch (e) {
      PosLogger().log('❌ NFC Init Error: $e', isError: true);
      _isAvailable = false;
      return false;
    }
  }

  Future<String?> readCardId({
    required Function(String) onCardDetected,
    required Function() onError,
  }) async {
    if (!_isAvailable) {
      debugPrint('⚠️ NFC not available');
      onError();
      return null;
    }

    try {
      PosLogger().log('📡 Starting NFC Session...');
      await NfcManager.instance.startSession(
        onDiscovered: (tag) async {
          final id = _extractCardIdentifier(tag);

          if (id != null && id.isNotEmpty) {
            PosLogger().log('🎯 Card Tapped: $id');
            onCardDetected(id);
            await NfcManager.instance.stopSession();
          } else {
            PosLogger().log('⚠️ Unrecognized card.', isError: true);
            Fluttertoast.showToast(
              msg: "Ikarita ntizwi. Nyamuneka koresha ikarita y'ishuri.",
              toastLength: Toast.LENGTH_SHORT,
              gravity: ToastGravity.BOTTOM,
              backgroundColor: Colors.red,
              textColor: Colors.white,
            );
            onError();
          }
        },
        pollingOptions: {
          NfcPollingOption.iso14443,
          NfcPollingOption.iso15693,
          NfcPollingOption.iso18092,
        },
      );
      return null;
    } catch (e) {
      PosLogger().log('❌ NFC Session Error: $e', isError: true);
      onError();
      return null;
    }
  }

  Future<void> stopSession() async {
    try {
      await NfcManager.instance.stopSession();
      PosLogger().log('🛑 NFC Session Stopped');
    } catch (e) {
      PosLogger().log('❌ Stop Session Error: $e', isError: true);
    }
  }

  String? _extractCardIdentifier(NfcTag tag) {
    try {
      final dynamic rawData = tag.data;
      Map<dynamic, dynamic> data = {};

      if (rawData is Map) {
        data = rawData;
      } else {
        // Handle cases where data is an object (e.g., TagPigeon)
        try {
          // If it's a platform-specific object like TagPigeon, it often has a 'data' field 
          // that is actually a Map, but we need to access it dynamically.
          final dynamic internalData = (rawData as dynamic).data;
          if (internalData is Map) {
            data = Map<dynamic, dynamic>.from(internalData);
          }
        } catch (_) {}
      }

      // If map-based extraction failed, try string parsing fallback
      if (data.isEmpty) {
        final str = rawData.toString();
        // Look for the identifier pattern in the string: identifier: [1, 2, 3, 4]
        final match = RegExp(r'identifier:\s*\[([\d,\s]+)\]').firstMatch(str);
        if (match != null) {
          final bytesStr = match.group(1);
          if (bytesStr != null) {
            final bytes = bytesStr.split(',').map((e) => int.parse(e.trim())).toList();
            final hex = bytes.map((e) => e.toRadixString(16).padLeft(2, '0')).join('').toUpperCase();
            debugPrint('✅ Identified Card ID (via String Parsing): $hex');
            return hex;
          }
        }
      }

      // Standard Map-based extraction
      Iterable<dynamic>? identifier;
      final techKeys = ['nfca', 'mifare', 'isodep', 'iso7816', 'mifareclassic', 'nfcv', 'nfcb'];
      
      for (var key in techKeys) {
        if (data.containsKey(key) && data[key] != null) {
          final techData = data[key];
          if (techData is Map && techData.containsKey('identifier')) {
            identifier = techData['identifier'];
            break;
          }
        }
      }

      if (identifier == null) {
        for (var value in data.values) {
          if (value is Map && value.containsKey('identifier')) {
            identifier = value['identifier'];
            break;
          }
        }
      }

      if (identifier != null && identifier is List) {
        final hex = identifier.map((e) => e.toRadixString(16).padLeft(2, '0')).join('').toUpperCase();
        debugPrint('✅ Identified Card ID: $hex');
        return hex;
      }

      debugPrint('⚠️ NFC Tag data could not be parsed. Raw: $rawData');
      return null;
    } catch (e) {
      debugPrint('❌ Error extracting identifier: $e');
      return null;
    }
  }
}
