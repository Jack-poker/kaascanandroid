import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/pos_logger.dart';
import '../services/thermal_printer_service.dart';
import '../services/nfc_reader_service.dart';

class PosDiagnosticScreen extends StatefulWidget {
  const PosDiagnosticScreen({super.key});

  @override
  State<PosDiagnosticScreen> createState() => _PosDiagnosticScreenState();
}

class _PosDiagnosticScreenState extends State<PosDiagnosticScreen> {
  final ScrollController _logScrollController = ScrollController();
  bool _isNfcLive = false;

  @override
  void initState() {
    super.initState();
    PosLogger().addListener(_updateLogs);
  }

  @override
  void dispose() {
    PosLogger().removeListener(_updateLogs);
    _logScrollController.dispose();
    if (_isNfcLive) {
      NfcReaderService().stopSession();
    }
    super.dispose();
  }

  void _updateLogs() {
    if (mounted) {
      setState(() {});
      // Scroll to top automatically (since we insert at 0)
    }
  }

  Future<void> _testPrinter() async {
    PosLogger().log('🧪 Starting Manual Printer Test...');
    final success = await ThermalPrinterService().printTestReceipt();
    if (success) {
      PosLogger().log('✅ Manual Printer Test PASSED');
    } else {
      PosLogger().log('❌ Manual Printer Test FAILED - Printer not responding', isError: true);
    }
  }

  Future<void> _toggleNfcListener() async {
    if (_isNfcLive) {
      NfcReaderService().stopSession();
      setState(() => _isNfcLive = false);
      PosLogger().log('🛑 NFC Diagnostic Listener Stopped');
    } else {
      final available = await NfcReaderService().initialize();
      if (!available) {
        PosLogger().log('❌ NFC Hardware Not Available on this device', isError: true);
        return;
      }
      
      setState(() => _isNfcLive = true);
      PosLogger().log('📡 NFC Diagnostic Listener ACTIVE - Please tap a card...');
      
      NfcReaderService().readCardId(
        onCardDetected: (id) {
          PosLogger().log('🎯 CARD DETECTED! ID: $id');
        },
        onError: () {
          PosLogger().log('❌ NFC Listener encountered an error', isError: true);
          setState(() => _isNfcLive = false);
        }
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFF1A237E); // Default deep blue if theme fails

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('POS Diagnostics', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep_rounded),
            onPressed: () => PosLogger().clear(),
            tooltip: 'Clear Logs',
          ),
        ],
      ),
      body: Column(
        children: [
          // Hardware Controls
          _buildControlPanel(primaryColor),
          
          const Divider(height: 1),
          
          // Log Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.grey[200],
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Real-time Hardware Logs', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                Text('${PosLogger().logs.length} entries', style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ),
          
          // Log List
          Expanded(
            child: Container(
              color: Colors.black,
              child: ListView.builder(
                controller: _logScrollController,
                padding: const EdgeInsets.all(8),
                itemCount: PosLogger().logs.length,
                itemBuilder: (context, index) {
                  final log = PosLogger().logs[index];
                  return _buildLogItem(log);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlPanel(Color primary) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildTestBtn(
                  icon: Icons.print_rounded,
                  label: 'Printer Test',
                  desc: 'Init & Print Receipt',
                  onTap: _testPrinter,
                  color: Colors.orange[800]!,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTestBtn(
                  icon: _isNfcLive ? Icons.stop_circle_rounded : Icons.sensors_rounded,
                  label: 'NFC Test',
                  desc: _isNfcLive ? 'Listening...' : 'Start Listening',
                  onTap: _toggleNfcListener,
                  color: _isNfcLive ? Colors.red : Colors.green[700]!,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTestBtn({
    required IconData icon,
    required String label,
    required String desc,
    required VoidCallback onTap,
    required Color color,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          border: Border.all(color: color.withOpacity(0.3)),
          borderRadius: BorderRadius.circular(12),
          color: color.withOpacity(0.05),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
            Text(desc, style: TextStyle(color: color.withOpacity(0.7), fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Widget _buildLogItem(PosLogEntry log) {
    final timeStr = DateFormat('HH:mm:ss.SSS').format(log.timestamp);
    final color = log.isError ? Colors.red[400] : Colors.green[400];
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('[$timeStr] ', style: const TextStyle(color: Colors.grey, fontSize: 10, fontFamily: 'monospace')),
          Expanded(
            child: Text(
              log.message,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontFamily: 'monospace',
                height: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
