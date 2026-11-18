import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

const Color _brand = Color(0xFF0022FF);
const Color _successGreen = Color(0xFF10B981);

/// Result returned when the in-app payment WebView closes.
class CardPaymentResult {
  final bool completed;   // true = user finished (success or failure)
  final String? status;   // "SUCCESS" | "FAILED" | "CANCELLED" | null
  final String? referenceId;

  const CardPaymentResult({
    required this.completed,
    this.status,
    this.referenceId,
  });
}

/// Full-screen in-app WebView for Soila Pay / Pesapal card payments.
///
/// Usage:
/// ```dart
/// final result = await Navigator.push<CardPaymentResult>(
///   context,
///   MaterialPageRoute(builder: (_) => CardPaymentWebView(
///     redirectUrl: redirectUrl,
///     referenceId: referenceId,
///     studentName: student["student_name"],
///     amountRwf: amount,
///     channel: "VISA",
///   )),
/// );
/// ```
class CardPaymentWebView extends StatefulWidget {
  final String redirectUrl;
  final String referenceId;
  final String? studentName;
  final int amountRwf;
  final String channel;

  const CardPaymentWebView({
    super.key,
    required this.redirectUrl,
    required this.referenceId,
    this.studentName,
    required this.amountRwf,
    this.channel = "VISA",
  });

  @override
  State<CardPaymentWebView> createState() => _CardPaymentWebViewState();
}

class _CardPaymentWebViewState extends State<CardPaymentWebView> {
  late final WebViewController _controller;
  int _loadingProgress = 0;
  bool _loadError = false;

  // URLs that signal payment is done — Kaascan return page, plus common Pesapal endings.
  static const _returnMarkers = [
    'payment/card/return',
    'PesapalIframe3/Complete',
    'pesapal.com/iframe/success',
    'pesapal.com/iframe/failed',
    'pesapal.com/iframe/cancel',
  ];

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (p) => setState(() => _loadingProgress = p),
          onPageStarted: (_) => setState(() => _loadError = false),
          onWebResourceError: (_) => setState(() => _loadError = true),
          onNavigationRequest: (req) {
            final url = req.url.toLowerCase();
            for (final marker in _returnMarkers) {
              if (url.contains(marker.toLowerCase())) {
                _handleReturn(req.url);
                return NavigationDecision.prevent;
              }
            }
            return NavigationDecision.navigate;
          },
          onPageFinished: (url) {
            final lower = url.toLowerCase();
            for (final marker in _returnMarkers) {
              if (lower.contains(marker.toLowerCase())) {
                _handleReturn(url);
                return;
              }
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.redirectUrl));
  }

  void _handleReturn(String url) {
    if (!mounted) return;
    final uri = Uri.tryParse(url);
    final rawStatus = uri?.queryParameters['status'] ?? '';
    final status = rawStatus.toUpperCase();
    final refId = uri?.queryParameters['reference_id'] ?? widget.referenceId;

    final mapped = _mapStatus(status);
    Navigator.pop(
      context,
      CardPaymentResult(completed: true, status: mapped, referenceId: refId),
    );
  }

  String _mapStatus(String s) {
    if (['SUCCESS', 'SUCCESSFUL', 'COMPLETED', 'PAID'].contains(s)) return 'SUCCESS';
    if (['FAILED', 'FAILURE', 'ERROR'].contains(s)) return 'FAILED';
    if (['CANCEL', 'CANCELLED', 'CANCELED'].contains(s)) return 'CANCELLED';
    return 'PENDING';
  }

  void _confirmClose() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Cancel payment?',
          style: TextStyle(fontFamily: 'gilroy', fontWeight: FontWeight.w800),
        ),
        content: const Text(
          'If you close now, your payment will not be completed. You can try again later.',
          style: TextStyle(fontFamily: 'gilroy-light', fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Stay',
              style: TextStyle(color: _brand, fontFamily: 'gilroy', fontWeight: FontWeight.w700),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(
                context,
                const CardPaymentResult(completed: false, status: 'CANCELLED'),
              );
            },
            child: const Text(
              'Leave',
              style: TextStyle(color: Colors.red, fontFamily: 'gilroy'),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmClose();
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: _buildAppBar(),
        body: Stack(
          children: [
            if (!_loadError) WebViewWidget(controller: _controller),
            if (_loadError) _buildErrorView(),
            if (_loadingProgress < 100 && !_loadError)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: LinearProgressIndicator(
                  value: _loadingProgress / 100,
                  backgroundColor: Colors.transparent,
                  color: _brand,
                  minHeight: 3,
                ),
              ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    final name = widget.studentName ?? '';
    final amtFormatted = _fmtAmount(widget.amountRwf);
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      leading: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: const Icon(CupertinoIcons.xmark, size: 16, color: Colors.black87),
        ),
        onPressed: _confirmClose,
      ),
      title: Column(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                CupertinoIcons.creditcard_fill,
                size: 14,
                color: _brand.withValues(alpha: 0.7),
              ),
              const SizedBox(width: 6),
              Text(
                widget.channel == 'MASTERCARD' ? 'Mastercard Payment' : 'VISA Payment',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'gilroy',
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          if (name.isNotEmpty)
            Text(
              name.isNotEmpty ? '$amtFormatted RWF → $name' : '$amtFormatted RWF',
              style: const TextStyle(
                fontSize: 11,
                fontFamily: 'gilroy-light',
                color: Color(0xFF9CA3AF),
              ),
            ),
        ],
      ),
      centerTitle: true,
      actions: [
        // Secure-lock badge
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: Row(
            children: [
              Icon(CupertinoIcons.lock_fill, size: 13, color: _successGreen),
              const SizedBox(width: 3),
              const Text(
                'Secure',
                style: TextStyle(
                  fontSize: 11,
                  fontFamily: 'gilroy',
                  color: _successGreen,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: Colors.grey[100]),
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(CupertinoIcons.wifi_slash, size: 64, color: Color(0xFFD1D5DB)),
            const SizedBox(height: 20),
            const Text(
              'Could not load payment page',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                fontFamily: 'gilroy',
                color: Color(0xFF11142D),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Check your internet connection and try again.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontFamily: 'gilroy-light',
                color: Color(0xFF9CA3AF),
              ),
            ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              onPressed: () {
                setState(() => _loadError = false);
                _controller.reload();
              },
              icon: const Icon(CupertinoIcons.refresh, size: 16),
              label: const Text(
                'Retry',
                style: TextStyle(fontFamily: 'gilroy', fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _brand,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                elevation: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _fmtAmount(int v) =>
      v.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
}
