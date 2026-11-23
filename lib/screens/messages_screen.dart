import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:kaascan/components/soma_chat_background.dart';
import 'package:kaascan/components/soma_robot.dart';
import 'package:kaascan/components/student_message_style.dart';
import 'package:kaascan/dashboard/home.dart' show currentIndex;
import 'package:kaascan/dashboard/send_money_ui.dart';
import 'package:kaascan/dashboard/transactions.dart';
import 'package:kaascan/screens/kaascan_ai.dart' show somaQuote;
import 'package:kaascan/services/language_service.dart';
import 'package:kaascan/services/soma_home_widget.dart';
import 'package:kaascan/services/student_messages.dart';
import 'package:kaascan/widgets/cached_network_image_wrapper.dart';

const _blue = Color(0xFF0022FF);
const _ink = Color(0xFF14172B);
const _muted = Color(0xFF6B7280);
const _orange = Color(0xFFFF6A00);
const _green = Color(0xFF0E9F6E);

/// The third tab: what the children sent from school (card taps), with the
/// transaction history one switch away.
class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key, @visibleForTesting this.preview});

  /// Shown instead of loading from the server (previews and tests).
  final List<StudentMessage>? preview;

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  bool _history = false;
  bool _loading = true;
  bool _failed = false;
  List<StudentMessage> _messages = const [];
  final Set<int> _busy = {};
  Timer? _readTimer;

  String get _lang => languageService.currentLanguageCode;
  String _t(String rw, String en, String fr) => switch (_lang) {
    'rw' => rw,
    'fr' => fr,
    _ => en,
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _readTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final list = widget.preview ?? await StudentMessages.load();
    if (!mounted) return;
    setState(() {
      _loading = false;
      _failed = list == null;
      if (list != null) _messages = list;
    });
    // Seen: clear the badges after a moment on screen.
    final unseen = _messages.where((m) => m.status == 'new').map((m) => m.id).toList();
    if (unseen.isEmpty || widget.preview != null) return;
    _readTimer?.cancel();
    _readTimer = Timer(const Duration(milliseconds: 1500), () async {
      await StudentMessages.markRead(unseen);
      for (final m in _messages) {
        if (unseen.contains(m.id)) m.status = 'read';
      }
      if (mounted) setState(() {});
      SomaHomeWidget.refreshBalance();
    });
  }

  // ── actions ──────────────────────────────────────────────────────────────

  void _approve(StudentMessage m) {
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SendMoneySheet(
        student: {'student_id': m.studentId, 'student_name': m.studentName, 'photo_url': m.photoUrl ?? ''},
        parentBalance: 0,
        parentName: languageService.t('common.parent', fallback: 'Parent'),
        initialAmount: m.amount,
        onTransferSuccess: () => _resolve(m, 'approved'),
      ),
    );
  }

  Future<void> _resolve(StudentMessage m, String action) async {
    setState(() => _busy.add(m.id));
    final ok = await StudentMessages.resolve(m.id, action);
    if (!mounted) return;
    setState(() {
      _busy.remove(m.id);
      if (ok) m.status = action;
    });
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _t('Ntibyakunze. Ongera ugerageze.', 'That did not work. Try again.', 'Cela n\'a pas marché. Réessayez.'),
          ),
        ),
      );
    }
    SomaHomeWidget.refreshBalance();
  }

  void _askSoma(StudentMessage m) {
    HapticFeedback.selectionClick();
    currentIndex.value = 0;
    somaQuote.value = messageQuote(m, _lang);
  }

  // ── build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _blue,
      body: SomaChatBackground(
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Padding(padding: const EdgeInsets.fromLTRB(20, 12, 20, 4), child: _switcher()),
              Expanded(
                child: _history
                    ? const TransactionsScreen()
                    : RefreshIndicator(color: _blue, onRefresh: _load, child: _body()),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _switcher() {
    Widget tab(String label, bool selected, VoidCallback onTap, {int badge = 0}) {
      return Expanded(
        child: GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? Colors.white : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(fontFamily: 'gilroy', fontSize: 14, color: selected ? _blue : Colors.white),
                ),
                if (badge > 0) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: _orange, borderRadius: BorderRadius.circular(10)),
                    child: Text(
                      badge > 9 ? '9+' : '$badge',
                      style: const TextStyle(fontFamily: 'gilroy', fontSize: 11, color: Colors.white),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(18)),
      child: ValueListenableBuilder<int>(
        valueListenable: StudentMessages.unread,
        builder: (_, unread, __) => Row(
          children: [
            tab(
              _t('Ubutumwa', 'Messages', 'Messages'),
              !_history,
              () => setState(() => _history = false),
              badge: unread,
            ),
            tab(_t('Amateka', 'History', 'Historique'), _history, () => setState(() => _history = true)),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.4));
    }
    if (_failed && _messages.isEmpty) {
      return _placeholder(
        mood: SomaMood.no,
        title: _t('Ntitwabashije kubona ubutumwa', 'Could not load messages', 'Impossible de charger'),
        body: _t('Kurura hasi wongere ugerageze.', 'Pull down to try again.', 'Tirez vers le bas pour réessayer.'),
      );
    }
    if (_messages.isEmpty) {
      return _placeholder(
        mood: SomaMood.idle,
        title: _t('Nta butumwa buraza', 'No messages yet', 'Pas encore de messages'),
        body: _t(
          'Umwana wawe nakoza ikarita ye ku cyuma cya Somakadi ku ishuri asaba amafaranga, cyangwa ishuri rikakwandikira, ubutumwa buzaza hano.',
          'When your child taps their card on the Somakadi device at school to ask for money, or the school sends you a note, it shows up here.',
          'Quand votre enfant passe sa carte sur l\'appareil Somakadi à l\'école pour demander de l\'argent, ou que l\'école vous écrit, cela apparaît ici.',
        ),
      );
    }

    final open = _messages.where((m) => m.isOpen && m.isMoney).toList();
    final rest = _messages.where((m) => !(m.isOpen && m.isMoney)).toList();
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 140),
      children: [
        if (open.isNotEmpty) ...[
          _sectionLabel(_t('Bitegereje igisubizo', 'Waiting for you', 'En attente')),
          for (final m in open) _MessageCard(message: m, parent: this),
          const SizedBox(height: 10),
        ],
        if (rest.isNotEmpty) ...[
          _sectionLabel(_t('Ibyabanje', 'Earlier', 'Plus tôt')),
          for (final m in rest) _MessageCard(message: m, parent: this),
        ],
      ],
    );
  }

  Widget _sectionLabel(String text) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 6, 4, 10),
    child: Text(
      text.toUpperCase(),
      style: TextStyle(
        fontFamily: 'gilroy',
        fontSize: 11,
        letterSpacing: 1.1,
        color: Colors.white.withValues(alpha: 0.7),
      ),
    ),
  );

  Widget _placeholder({required SomaMood mood, required String title, required String body}) {
    return LayoutBuilder(
      builder: (context, c) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: c.maxHeight),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(36, 0, 36, 120),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SomaRobot(size: 150, mood: mood),
                const SizedBox(height: 6),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontFamily: 'gilroy', fontSize: 22, color: Colors.white),
                ),
                const SizedBox(height: 8),
                Text(
                  body,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'gilroy-light',
                    fontSize: 14,
                    height: 1.45,
                    color: Colors.white.withValues(alpha: 0.82),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({required this.message, required this.parent});

  final StudentMessage message;
  final _MessagesScreenState parent;

  String _t(String rw, String en, String fr) => parent._t(rw, en, fr);

  @override
  Widget build(BuildContext context) {
    final m = message;
    final lang = parent._lang;
    final accent = messageAccent(m.id);
    final summary = messageSummary(m, lang);
    final busy = parent._busy.contains(m.id);
    final unread = m.status == 'new';
    final words = (m.text ?? '').trim();

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: accent.wash,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.10), blurRadius: 18, offset: const Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Who + when
          Row(
            children: [
              MessageAvatar(name: m.studentName, url: m.photoUrl, accent: accent, unread: unread),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      m.studentName.isEmpty ? _t('Umwana', 'Your child', 'Votre enfant') : m.studentName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontFamily: 'gilroy', fontSize: 16, color: _ink),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      m.isSchool
                          ? (m.sender ?? m.school ?? _t('Ishuri', 'School', 'École'))
                          : (m.school ?? _t('Ku ishuri', 'At school', 'À l\'école')),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontFamily: 'gilroy-light', fontSize: 12.5, color: _muted),
                    ),
                  ],
                ),
              ),
              _StatusChip(status: m.status, t: _t),
            ],
          ),
          const SizedBox(height: 12),

          // The bubble: what they want, in their words
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(6),
                topRight: Radius.circular(22),
                bottomLeft: Radius.circular(22),
                bottomRight: Radius.circular(22),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(color: accent.soft, borderRadius: BorderRadius.circular(10)),
                      child: Icon(summary.icon, size: 17, color: accent.color),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 5),
                        child: Text(
                          summary.line,
                          style: const TextStyle(fontFamily: 'gilroy', fontSize: 15, height: 1.3, color: _ink),
                        ),
                      ),
                    ),
                  ],
                ),
                if (words.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    m.isSchool ? words : '“$words”',
                    style: const TextStyle(fontFamily: 'gilroy-light', fontSize: 14.5, height: 1.4, color: _ink),
                  ),
                ],
                if (m.billing == 'paid' && (m.fee ?? 0) > 0 || m.billing == 'free_empty') ...[
                  const SizedBox(height: 8),
                  _FeeTag(message: m, t: _t),
                ],
                if ((m.notePhotoUrl ?? '').startsWith('http')) ...[
                  const SizedBox(height: 10),
                  _NotePhoto(url: m.notePhotoUrl!),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (m.balance != null && !m.isSchool)
                      Expanded(
                        child: Text(
                          _t(
                            'Ku ikarita: ${moneyText(m.balance!)} RWF',
                            'On the card: ${moneyText(m.balance!)} RWF',
                            'Sur la carte : ${moneyText(m.balance!)} RWF',
                          ),
                          style: TextStyle(
                            fontFamily: 'gilroy-light',
                            fontSize: 12,
                            color: m.balance! < 1000 ? _orange : _muted,
                          ),
                        ),
                      )
                    else
                      const Spacer(),
                    Icon(Icons.schedule_rounded, size: 13, color: _muted.withValues(alpha: 0.8)),
                    const SizedBox(width: 4),
                    Text(
                      messageTime(m.createdAt, lang),
                      style: const TextStyle(fontFamily: 'gilroy-light', fontSize: 12, color: _muted),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // What the parent can do
          if (m.isMoney && m.isOpen)
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 44,
                    child: FilledButton(
                      onPressed: busy ? null : () => parent._approve(m),
                      style: FilledButton.styleFrom(
                        backgroundColor: accent.color,
                        foregroundColor: accent.on,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: busy
                          ? SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: accent.on),
                            )
                          : Text(
                              _t('Emeza', 'Approve', 'Approuver'),
                              style: const TextStyle(fontFamily: 'gilroy', fontSize: 14),
                            ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                SizedBox(
                  height: 44,
                  child: TextButton(
                    onPressed: busy ? null : () => parent._resolve(m, 'declined'),
                    style: TextButton.styleFrom(
                      foregroundColor: _ink.withValues(alpha: 0.7),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: Text(
                      _t('Anga', 'Decline', 'Refuser'),
                      style: const TextStyle(fontFamily: 'gilroy', fontSize: 14),
                    ),
                  ),
                ),
                _SomaButton(onTap: () => parent._askSoma(m), label: _t('Baza Soma', 'Ask Soma', 'Soma')),
              ],
            )
          else
            Row(
              children: [
                Expanded(
                  child: Text(
                    m.isMoney
                        ? (m.status == 'approved'
                              ? _t('Wemeje, amafaranga yoherejwe.', 'You approved and sent it.', 'Approuvé et envoyé.')
                              : _t('Wanze iki cyifuzo.', 'You declined this request.', 'Vous avez refusé.'))
                        : _t('Soma irabigusobanurira.', 'Soma can explain this.', 'Soma peut vous l\'expliquer.'),
                    style: TextStyle(fontFamily: 'gilroy-light', fontSize: 13, color: _ink.withValues(alpha: 0.65)),
                  ),
                ),
                _SomaButton(onTap: () => parent._askSoma(m), label: _t('Baza Soma', 'Ask Soma', 'Soma')),
              ],
            ),
        ],
      ),
    );
  }
}

/// A school note's photo; tap to see it full screen and zoom.
class _NotePhoto extends StatelessWidget {
  const _NotePhoto({required this.url});

  final String url;

  void _open(BuildContext context) {
    HapticFeedback.selectionClick();
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black,
        pageBuilder: (context, _, __) => Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            children: [
              Positioned.fill(
                child: InteractiveViewer(
                  maxScale: 5,
                  child: Center(
                    child: Hero(
                      tag: url,
                      child: CachedNetworkImageWrapper(imageUrl: url, fit: BoxFit.contain),
                    ),
                  ),
                ),
              ),
              SafeArea(
                child: Align(
                  alignment: Alignment.topRight,
                  child: IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _open(context),
      child: Hero(
        tag: url,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: AspectRatio(
            aspectRatio: 4 / 3,
            child: CachedNetworkImageWrapper(
              imageUrl: url,
              errorWidget: Container(
                color: const Color(0xFFF3F5FF),
                alignment: Alignment.center,
                child: const Icon(Icons.image_not_supported_outlined, color: _muted),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SomaButton extends StatelessWidget {
  const _SomaButton({required this.onTap, required this.label});

  final VoidCallback onTap;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Container(
          height: 44,
          padding: const EdgeInsets.only(left: 4, right: 12),
          decoration: BoxDecoration(color: const Color(0xFFF3F5FF), borderRadius: BorderRadius.circular(14)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SomaRobot(size: 36, floating: false),
              Text(
                label,
                style: const TextStyle(fontFamily: 'gilroy', fontSize: 13, color: _blue),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// What sending the message cost the child, so the parent is never surprised.
class _FeeTag extends StatelessWidget {
  const _FeeTag({required this.message, required this.t});

  final StudentMessage message;
  final String Function(String, String, String) t;

  @override
  Widget build(BuildContext context) {
    final paid = message.billing == 'paid';
    final fee = moneyText(message.fee ?? 0);
    final label = paid
        ? t(
            'Ubutumwa bwatwaye $fee RWF ku ikarita',
            'Message fee: $fee RWF from the card',
            'Frais du message : $fee RWF sur la carte',
          )
        : t(
            'Ubutumwa bw\'ubuntu: ikarita ifite amafaranga make',
            'Sent free: the card was low',
            'Envoyé gratuitement : la carte était presque vide',
          );
    final color = paid ? _muted : _orange;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(paid ? Icons.toll_rounded : Icons.card_giftcard_rounded, size: 13, color: color),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              style: TextStyle(fontFamily: 'gilroy-light', fontSize: 12, color: color),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status, required this.t});

  final String status;
  final String Function(String, String, String) t;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      'approved' => (t('Byemejwe', 'Approved', 'Approuvé'), _green),
      'declined' => (t('Byanzwe', 'Declined', 'Refusé'), _muted),
      'new' => (t('Gishya', 'New', 'Nouveau'), _orange),
      _ => (null, _muted),
    };
    if (label == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
      child: Text(
        label,
        style: TextStyle(fontFamily: 'gilroy', fontSize: 11.5, color: color),
      ),
    );
  }
}
