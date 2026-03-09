import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/pos_logger.dart';

class PosLogScreen extends StatefulWidget {
  const PosLogScreen({super.key});

  @override
  State<PosLogScreen> createState() => _PosLogScreenState();
}

class _PosLogScreenState extends State<PosLogScreen> {
  final PosLogger _logger = PosLogger();

  @override
  void initState() {
    super.initState();
    _logger.addListener(_refresh);
  }

  @override
  void dispose() {
    _logger.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    // Premium color palette requested: Blue table and Deep Orange
    const Color tableBlue = Color(0xFF0052FF); // Deep Blue
    const Color deepOrange = Color(0xFFFF4500); // Deep Orange / OrangeRed
    const Color bgBlue = Color(0xFFF0F5FF); // Light Blue background

    return Scaffold(
      backgroundColor: bgBlue,
      appBar: AppBar(
        title: const Text(
          'POS SYSTEM LOGS',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
            fontFamily: "gilroy",
          ),
        ),
        backgroundColor: tableBlue,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: () => _logger.clear(),
            icon: const Icon(Icons.delete_sweep, color: Colors.white),
          ),
        ],
      ),
      body: Column(
        children: [
          // Header Table Row
          Container(
            color: tableBlue.withOpacity(0.9),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            child: Row(
              children: [
                SizedBox(
                  width: 80,
                  child: Text(
                    'TIME',
                    style: TextStyle(
                      color: deepOrange,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                const Expanded(
                  child: Text(
                    'MESSAGE / ACTIVITY',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Log List
          Expanded(
            child: _logger.logs.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.terminal, size: 60, color: tableBlue.withOpacity(0.2)),
                        const SizedBox(height: 16),
                        Text(
                          'Waiting for Java Extension logs...',
                          style: TextStyle(color: tableBlue.withOpacity(0.5), fontStyle: FontStyle.italic),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: EdgeInsets.zero,
                    itemCount: _logger.logs.length,
                    separatorBuilder: (context, index) => Divider(
                      height: 1,
                      color: tableBlue.withOpacity(0.1),
                    ),
                    itemBuilder: (context, index) {
                      final log = _logger.logs[index];
                      return Container(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        decoration: BoxDecoration(
                          color: log.isError ? Colors.red.withOpacity(0.05) : Colors.white,
                          border: Border(
                            left: BorderSide(
                              color: log.isError ? Colors.red : deepOrange,
                              width: 3,
                            ),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 80,
                              child: Text(
                                DateFormat('HH:mm:ss').format(log.timestamp),
                                style: TextStyle(
                                  color: tableBlue.withOpacity(0.6),
                                  fontSize: 12,
                                  fontFamily: "monospace",
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                log.message,
                                style: TextStyle(
                                  color: log.isError ? Colors.red.shade900 : tableBlue,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
