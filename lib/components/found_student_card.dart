import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kaascan/widgets/cached_network_image_wrapper.dart';

const _blue = Color(0xFF0019CD);
const _ink = Color(0xFF1A1F36);
const _muted = Color(0xFF6B7280);
const _tint = Color(0xFFF3F5FF);
const _green = Color(0xFF0E9F6E);
const _red = Color(0xFFD92D20);

enum _LinkState { idle, linking, linked, failed, notMine }

/// The child Soma found from a student code, with one clear action: link to
/// the parent's account. Shown under Soma's message, like the other cards.
class FoundStudentCard extends StatefulWidget {
  const FoundStudentCard({
    super.key,
    required this.name,
    required this.school,
    required this.grade,
    required this.photoUrl,
    required this.onLink,
    this.lang = 'rw',
  });

  final String name;
  final String school;
  final String grade;
  final String? photoUrl;

  /// Links the child; resolves to true when it worked.
  final Future<bool> Function() onLink;
  final String lang;

  @override
  State<FoundStudentCard> createState() => _FoundStudentCardState();
}

class _FoundStudentCardState extends State<FoundStudentCard> {
  _LinkState _state = _LinkState.idle;

  bool get _en => widget.lang == 'en';
  String _t(String rw, String en) => _en ? en : rw;

  Future<void> _link() async {
    HapticFeedback.mediumImpact();
    setState(() => _state = _LinkState.linking);
    final ok = await widget.onLink();
    if (!mounted) return;
    HapticFeedback.lightImpact();
    setState(() => _state = ok ? _LinkState.linked : _LinkState.failed);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.10),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: _state == _LinkState.notMine ? _notMine() : _details(),
      ),
    );
  }

  Widget _details() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            _Photo(name: widget.name, url: widget.photoUrl),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _t('Umunyeshuri wabonetse', 'Student found'),
                    style: const TextStyle(
                      fontFamily: 'gilroy-light',
                      fontSize: 12,
                      color: _muted,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'gilroy',
                      fontSize: 18,
                      color: _ink,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      if (widget.school.isNotEmpty)
                        _Chip(icon: Icons.school_rounded, text: widget.school),
                      if (widget.grade.isNotEmpty)
                        _Chip(icon: Icons.class_rounded, text: widget.grade),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: switch (_state) {
            _LinkState.linked => _Result(
                key: const ValueKey('linked'),
                icon: Icons.check_circle_rounded,
                color: _green,
                text: _t('Yahujwe na konti yawe', 'Linked to your account'),
              ),
            _LinkState.failed => Column(
                key: const ValueKey('failed'),
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Result(
                    icon: Icons.error_outline_rounded,
                    color: _red,
                    text: _t('Ntibyakunze. Ongera ugerageze.',
                        "Couldn't link. Please try again."),
                  ),
                  const SizedBox(height: 10),
                  _primaryButton(),
                ],
              ),
            _ => Column(
                key: const ValueKey('actions'),
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _primaryButton(),
                  const SizedBox(height: 4),
                  TextButton(
                    onPressed: _state == _LinkState.linking
                        ? null
                        : () => setState(() => _state = _LinkState.notMine),
                    style: TextButton.styleFrom(foregroundColor: _muted),
                    child: Text(
                      _t('Si umwana wanjye', 'Not my child'),
                      style: const TextStyle(fontFamily: 'gilroy', fontSize: 14),
                    ),
                  ),
                ],
              ),
          },
        ),
      ],
    );
  }

  Widget _primaryButton() {
    final busy = _state == _LinkState.linking;
    return SizedBox(
      height: 50,
      child: FilledButton.icon(
        onPressed: busy ? null : _link,
        style: FilledButton.styleFrom(
          backgroundColor: _blue,
          disabledBackgroundColor: _blue.withValues(alpha: 0.6),
          disabledForegroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        icon: busy
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2.2, color: Colors.white),
              )
            : const Icon(Icons.link_rounded),
        label: Text(
          busy
              ? _t('Turimo kumuhuza…', 'Linking…')
              : _t('Huza na konti yanjye', 'Link to my account'),
          style: const TextStyle(fontFamily: 'gilroy', fontSize: 16),
        ),
      ),
    );
  }

  Widget _notMine() {
    return Row(
      children: [
        const Icon(Icons.info_outline_rounded, color: _muted),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            _t('Sawa. Reba neza kode y\'umunyeshuri hanyuma wongere ugerageze.',
                'Okay. Check the student code and try again.'),
            style: const TextStyle(
                fontFamily: 'gilroy-light', fontSize: 14, color: _ink),
          ),
        ),
      ],
    );
  }
}

class _Photo extends StatelessWidget {
  const _Photo({required this.name, required this.url});

  final String name;
  final String? url;

  @override
  Widget build(BuildContext context) {
    final initials = name
        .split(' ')
        .where((w) => w.isNotEmpty)
        .take(2)
        .map((w) => w[0].toUpperCase())
        .join();
    final fallback = Container(
      width: 64,
      height: 64,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _blue,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        initials.isEmpty ? '?' : initials,
        style: const TextStyle(
            fontFamily: 'gilroy', fontSize: 22, color: Colors.white),
      ),
    );
    if (url == null || url!.isEmpty) return fallback;
    return CachedNetworkImageWrapper(
      imageUrl: url!,
      width: 64,
      height: 64,
      fit: BoxFit.cover,
      borderRadius: BorderRadius.circular(20),
      placeholder: fallback,
      errorWidget: fallback,
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _tint,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: _blue),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontFamily: 'gilroy-light', fontSize: 12.5, color: _ink),
            ),
          ),
        ],
      ),
    );
  }
}

class _Result extends StatelessWidget {
  const _Result({
    super.key,
    required this.icon,
    required this.color,
    required this.text,
  });

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontFamily: 'gilroy', fontSize: 14.5, color: color),
            ),
          ),
        ],
      ),
    );
  }
}
