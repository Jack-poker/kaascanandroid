import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

/// Lightweight audio + haptic service for the Soma AI screen.
///
/// Call [SomaAudio.onTyping] from the typewriter loop (every few chars),
/// [SomaAudio.onDone] when the response finishes, and [SomaAudio.onSend]
/// when the user submits a message.
class SomaAudio {
  SomaAudio._();
  static final SomaAudio _i = SomaAudio._();
  static SomaAudio get instance => _i;

  final AudioPlayer _tick = AudioPlayer();
  final AudioPlayer _done = AudioPlayer();
  final AudioPlayer _send = AudioPlayer();

  bool _ready = false;
  bool enabled = true;

  Future<void> init() async {
    if (_ready) return;
    try {
      await _tick.setSource(AssetSource('sound/tick.wav'));
      await _done.setSource(AssetSource('sound/done.wav'));
      await _send.setSource(AssetSource('sound/send.wav'));
      await _tick.setVolume(0.25);
      await _done.setVolume(0.65);
      await _send.setVolume(0.60);
      await _tick.setReleaseMode(ReleaseMode.stop);
      await _done.setReleaseMode(ReleaseMode.stop);
      await _send.setReleaseMode(ReleaseMode.stop);
      _ready = true;
    } catch (_) {}
  }

  Future<void> onTyping() async {
    if (!enabled) return;
    HapticFeedback.selectionClick();
    if (!_ready) return;
    try {
      await _tick.seek(Duration.zero);
      await _tick.resume();
    } catch (_) {}
  }

  Future<void> onDone() async {
    if (!enabled) return;
    HapticFeedback.lightImpact();
    if (!_ready) return;
    try {
      await _done.seek(Duration.zero);
      await _done.resume();
    } catch (_) {}
  }

  Future<void> onSend() async {
    if (!enabled) return;
    HapticFeedback.mediumImpact();
    if (!_ready) return;
    try {
      await _send.seek(Duration.zero);
      await _send.resume();
    } catch (_) {}
  }

  void dispose() {
    _tick.dispose();
    _done.dispose();
    _send.dispose();
    _ready = false;
  }
}
