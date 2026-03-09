import 'package:wiseasy_thermal_printer/wiseasy_thermal_printer.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'pos_logger.dart';

class ThermalPrinterService {
  static final ThermalPrinterService _instance = ThermalPrinterService._internal();
  factory ThermalPrinterService() => _instance;
  ThermalPrinterService._internal();

  final _printer = WiseasyThermalPrinter();
  bool _isInitialized = false;

  /// Initialize the thermal printer
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      PosLogger().log('🖨️ Initializing printer...');
      final result = await _printer.initPrinter();
      _isInitialized = result == 0; // 0 typically means success
      PosLogger().log('🖨️ Printer Initialized: $_isInitialized (result: $result)', isError: !_isInitialized);
      return _isInitialized;
    } catch (e) {
      PosLogger().log('❌ Printer Init Error: $e', isError: true);
      _isInitialized = false;
      return false;
    }
  }

  /// Print a transaction receipt
  Future<bool> printTransactionReceipt({
    required String merchantName,
    required String merchantId,
    required String studentName,
    required String amount,
    required String currency,
    required String transactionId,
    required String date,
    String? studentId,
  }) async {
    try {
      // Ensure printer is initialized
      if (!_isInitialized) {
        final initialized = await initialize();
        if (!initialized) {
          debugPrint('❌ Printer not initialized');
          return false;
        }
      }

      // Header - Merchant Name
      await _printer.printLine(
        merchantName.toUpperCase(),
        35,
        'center',
        true,
        false,
      );

      await _printer.printLine('', 20, 'left', false, false);

      // Merchant ID
      await _printer.printLine(
        'Merchant ID: $merchantId',
        22,
        'center',
        false,
        false,
      );

      // Divider
      await _printer.printLine(
        '================================',
        22,
        'center',
        false,
        false,
      );

      await _printer.printLine('', 20, 'left', false, false);

      // Transaction Type
      await _printer.printLine(
        'PAYMENT RECEIPT',
        28,
        'center',
        true,
        false,
      );

      await _printer.printLine('', 20, 'left', false, false);

      // Date & Time
      await _printer.printLine(
        'Date: $date',
        22,
        'left',
        false,
        false,
      );

      await _printer.printLine('', 20, 'left', false, false);

      // Student Details
      await _printer.printLine(
        'Student: $studentName',
        22,
        'left',
        false,
        false,
      );

      if (studentId != null && studentId.isNotEmpty) {
        await _printer.printLine(
          'ID: $studentId',
          20,
          'left',
          false,
          false,
        );
      }

      await _printer.printLine('', 20, 'left', false, false);

      // Divider
      await _printer.printLine(
        '================================',
        22,
        'center',
        false,
        false,
      );

      await _printer.printLine('', 20, 'left', false, false);

      // Amount - Big and bold
      await _printer.printLine(
        'AMOUNT',
        22,
        'left',
        false,
        false,
      );

      await _printer.printLine(
        '$currency $amount',
        40,
        'center',
        true,
        true,
      );

      await _printer.printLine('', 20, 'left', false, false);

      // Divider
      await _printer.printLine(
        '================================',
        22,
        'center',
        false,
        false,
      );

      await _printer.printLine('', 20, 'left', false, false);

      // Transaction ID
      await _printer.printLine(
        'Transaction ID:',
        20,
        'left',
        false,
        false,
      );

      await _printer.printLine(
        transactionId,
        18,
        'center',
        false,
        false,
      );

      await _printer.printLine('', 20, 'left', false, false);

      // Footer
      await _printer.printLine(
        'Thank you!',
        24,
        'center',
        false,
        true,
      );

      await _printer.printLine(
        'Powered by Kaascan',
        20,
        'center',
        false,
        false,
      );

      // Paper feed to cut
      await _printer.paperFeed(100);

      PosLogger().log('✅ Receipt printed successfully');
      return true;
    } catch (e) {
      PosLogger().log('❌ Print Error: $e', isError: true);
      return false;
    }
  }

  /// Print a test receipt
  Future<bool> printTestReceipt() async {
    return await printTransactionReceipt(
      merchantName: 'Test Merchant',
      merchantId: '****1234',
      studentName: 'Test Student',
      amount: '1,000',
      currency: 'RWF',
      transactionId: 'TEST-${DateTime.now().millisecondsSinceEpoch}',
      date: DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now()),
      studentId: 'STU001',
    );
  }

  /// Stop printer
  Future<void> stopPrinter() async {
    try {
      await _printer.stopPrint();
      debugPrint('🛑 Printer Stopped');
    } catch (e) {
      debugPrint('❌ Stop Printer Error: $e');
    }
  }
}
