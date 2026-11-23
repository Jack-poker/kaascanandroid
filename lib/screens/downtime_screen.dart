import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:kaascan/components/soma_chat_background.dart';
import 'package:kaascan/components/soma_robot.dart';
import 'package:kaascan/services/language_service.dart';
import 'package:kaascan/services/server_status.dart';

/// Shown over the whole app while the Somakadi server is overloaded or
/// unreachable. Retries on its own and disappears when the server answers.
class DowntimeScreen extends StatefulWidget {
  const DowntimeScreen({super.key});

  @override
  State<DowntimeScreen> createState() => _DowntimeScreenState();
}

class _DowntimeScreenState extends State<DowntimeScreen> {
  static const _blue = Color(0xFF0022FF);

  // Waits between automatic retries: quick at first, then gentler on the server.
  static const _waits = [10, 20, 30, 60];
  int _attempt = 0;
  int _secondsLeft = _waits.first;
  bool _checking = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    _timer?.cancel();
    _secondsLeft = _waits[_attempt.clamp(0, _waits.length - 1)];
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_secondsLeft <= 1) {
        t.cancel();
        _retry();
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  Future<void> _retry() async {
    if (_checking) return;
    _timer?.cancel();
    setState(() => _checking = true);
    final ok = await ServerStatus.check();
    if (!mounted || ok) return; // the screen goes away when the server is back
    HapticFeedback.lightImpact();
    setState(() {
      _checking = false;
      _attempt++;
    });
    _startCountdown();
  }

  ({String title, String body, String safe, String retry, String retryIn, String checking}) get _text {
    switch (languageService.currentLanguageCode) {
      case 'rw':
        return (
          title: 'Turagaruka vuba',
          body: 'Somakadi ifite abantu benshi cyangwa iri gutunganywa. Mwihangane gato, turimo kongera kugerageza.',
          safe: 'Amafaranga yawe n\'ay\'abana bawe ari mu mutekano.',
          retry: 'Ongera ugerageze',
          retryIn: 'Turongera kugerageza mu masegonda',
          checking: 'Turimo kureba…',
        );
      case 'fr':
        return (
          title: 'Nous revenons vite',
          body: 'Somakadi est très sollicité ou en maintenance. Nous réessayons automatiquement.',
          safe: 'Votre argent et celui de vos enfants est en sécurité.',
          retry: 'Réessayer',
          retryIn: 'Nouvel essai dans',
          checking: 'Vérification…',
        );
      default:
        return (
          title: "We'll be right back",
          body: 'Somakadi is very busy or under maintenance right now. We keep trying for you.',
          safe: "Your money and your children's money are safe.",
          retry: 'Try again',
          retryIn: 'Trying again in',
          checking: 'Checking…',
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = _text;
    return Material(
      color: _blue,
      child: SomaChatBackground(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, c) => SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: c.maxHeight),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SomaRobot(
                          size: (c.maxHeight * 0.36).clamp(150.0, 260.0),
                          mood: _checking ? SomaMood.thinking : SomaMood.idle,
                          floating: true,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          t.title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontFamily: 'gilroy',
                            fontSize: 28,
                            color: Colors.white,
                            height: 1.15,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          t.body,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'gilroy-light',
                            fontSize: 15,
                            height: 1.45,
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.verified_user_rounded, color: Colors.white, size: 18),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  t.safe,
                                  style: const TextStyle(fontFamily: 'gilroy', fontSize: 13, color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 28),
                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: FilledButton(
                            onPressed: _checking ? null : _retry,
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: _blue,
                              disabledBackgroundColor: Colors.white.withValues(alpha: 0.7),
                              disabledForegroundColor: _blue,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                            ),
                            child: _checking
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(strokeWidth: 2.4, color: _blue),
                                  )
                                : Text(t.retry, style: const TextStyle(fontFamily: 'gilroy', fontSize: 16)),
                          ),
                        ),
                        const SizedBox(height: 14),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: Text(
                            _checking ? t.checking : '${t.retryIn} $_secondsLeft s',
                            key: ValueKey(_checking ? 'c' : '$_secondsLeft'),
                            style: TextStyle(
                              fontFamily: 'gilroy-light',
                              fontSize: 13,
                              color: Colors.white.withValues(alpha: 0.75),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
