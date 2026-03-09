import 'package:flutter/services.dart';
import 'dart:async';
import 'pos_logger.dart';

class PosExtensionService {
  static const _channel = MethodChannel('com.kaascan/pos_extensions');
  static final PosExtensionService _instance = PosExtensionService._internal();
  factory PosExtensionService() => _instance;
  PosExtensionService._internal();

  final _nfcController = StreamController<Map<String, String>>.broadcast();
  Stream<Map<String, String>> get onNfcDetected => _nfcController.stream;

  void handleNfcEvent(String tagId, String ndefData) {
    _nfcController.add({'tagId': tagId, 'ndefData': ndefData});
  }

  Future<void> startNfcReading() async {
    try {
      await _channel.invokeMethod('startNfcReading');
    } on PlatformException catch (e) {
      PosLogger().log('❌ NFC Error: ${e.message}', isError: true);
    }
  }

  Future<bool> hasPaper() async {
    try {
      final bool? result = await _channel.invokeMethod('hasPaper');
      return result ?? false;
    } catch (e) {
      PosLogger().log('❌ Printer Status Error: $e', isError: true);
      return false;
    }
  }

  Future<void> stopNfcReading() async {
    try {
      await _channel.invokeMethod('stopNfcReading');
    } on PlatformException catch (e) {
      PosLogger().log('❌ NFC Stop Error: ${e.message}', isError: true);
    }
  }

  Future<void> setPrinterMac(String mac) async {
    try {
      await _channel.invokeMethod('setPrinterMac', {'mac': mac});
    } on PlatformException catch (e) {
      PosLogger().log('❌ MAC Set Error: ${e.message}', isError: true);
    }
  }

  Future<void> setPrinterSecure(bool secure) async {
    try {
      await _channel.invokeMethod('setPrinterSecure', {'secure': secure});
    } on PlatformException catch (e) {
      PosLogger().log('❌ Secure Toggle Error: ${e.message}', isError: true);
    }
  }

  Future<void> printInvoice({
    required String header,
    required String invoiceId,
    required String date,
    required String employee,
    required String customer,
    List<String> products = const [],
    required String total,
    String discount = "0",
    String remark = "",
    String footer = "Thank you for using KaaScan!",
  }) async {
    try {
      await _channel.invokeMethod('printInvoice', {
        'header': header,
        'invoiceId': invoiceId,
        'date': date,
        'employee': employee,
        'customer': customer,
        'products': products,
        'discount': discount,
        'total': total,
        'remark': remark,
        'footer': footer,
      });
      PosLogger().log('🖨️ Printing Invoice #$invoiceId');
    } on PlatformException catch (e) {
      PosLogger().log('❌ Printing Error: ${e.message}', isError: true);
    }
  }

  /// Fully customizable raw ESC/POS invoice — every label configurable from Dart.
  Future<void> printRawInvoice({
    required String header,
    String subHeader = "",
    required String invoiceId,
    String invoiceLabel = "Invoice #",
    String dateLabel = "Date",
    required String date,
    String employeeLabel = "Cashier",
    required String employee,
    String customerLabel = "Customer",
    required String customer,
    List<String> products = const [],
    String discountLabel = "Discount",
    String discount = "0",
    String totalLabel = "TOTAL AMOUNT",
    String currency = "RWF",
    required String total,
    String remarkLabel = "Payment",
    String remark = "",
    String footer = "Thank you for using KaaScan!",
    int paperWidth = 32,
  }) async {
    try {
      await _channel.invokeMethod('printRawInvoice', {
        'header': header,
        'subHeader': subHeader,
        'invoiceId': invoiceId,
        'invoiceLabel': invoiceLabel,
        'dateLabel': dateLabel,
        'date': date,
        'employeeLabel': employeeLabel,
        'employee': employee,
        'customerLabel': customerLabel,
        'customer': customer,
        'products': products,
        'discountLabel': discountLabel,
        'discount': discount,
        'totalLabel': totalLabel,
        'currency': currency,
        'total': total,
        'remarkLabel': remarkLabel,
        'remark': remark,
        'footer': footer,
        'paperWidth': paperWidth,
      });
      PosLogger().log('🖨️ Raw Invoice Printed #$invoiceId');
    } on PlatformException catch (e) {
      PosLogger().log('❌ Print Error: ${e.message}', isError: true);
    }
  }
}
