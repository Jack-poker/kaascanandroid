import 'package:flutter/material.dart';

import 'package:kaascan/services/student_messages.dart';
import 'package:kaascan/widgets/cached_network_image_wrapper.dart';

/// One colour theme for a message card (the same family as the admin panel's
/// cards). [on] is the readable text colour on [color].
class MessageAccent {
  const MessageAccent(this.color, this.on);

  final Color color;
  final Color on;

  /// Light wash for the card behind the bubble.
  Color get wash => Color.lerp(Colors.white, color, 0.13)!;
  Color get soft => color.withValues(alpha: 0.14);
}

const _palette = <MessageAccent>[
  MessageAccent(Color(0xFFFF5A1F), Colors.white), // kadi orange
  MessageAccent(Color(0xFF7B7BFF), Colors.white), // lavender
  MessageAccent(Color(0xFF8DB600), Color(0xFF14172B)), // lime
  MessageAccent(Color(0xFFEC4899), Colors.white), // pink
  MessageAccent(Color(0xFF0EA5A4), Colors.white), // teal
  MessageAccent(Color(0xFFF5B800), Color(0xFF14172B)), // sunny
  MessageAccent(Color(0xFF7C3AED), Colors.white), // purple
  MessageAccent(Color(0xFF16A34A), Colors.white), // green
];

/// A message keeps its colour forever, and neighbours never share one.
MessageAccent messageAccent(int id) => _palette[id.abs() % _palette.length];

String _t(String lang, String rw, String en, String fr) => switch (lang) {
  'rw' => rw,
  'fr' => fr,
  _ => en,
};

String moneyText(double v) {
  final digits = v.round().abs().toString();
  final buf = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buf.write(',');
    buf.write(digits[i]);
  }
  return buf.toString();
}

const _months = {
  'rw': ['Mut', 'Gas', 'Wer', 'Mat', 'Gic', 'Kam', 'Nya', 'Kan', 'Nze', 'Ukw', 'Ugu', 'Uku'],
  'fr': ['janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin', 'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.'],
  'en': ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'],
};

/// "Today, 10:42" · "Yesterday, 18:05" · "3 Nov, 08:15" (year when not this year).
String messageTime(DateTime at, String lang) {
  final now = DateTime.now();
  final hm = '${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}';
  final day = DateTime(at.year, at.month, at.day);
  final today = DateTime(now.year, now.month, now.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return '${_t(lang, 'Uyu munsi', 'Today', 'Aujourd\'hui')}, $hm';
  if (diff == 1) return '${_t(lang, 'Ejo', 'Yesterday', 'Hier')}, $hm';
  final month = (_months[lang] ?? _months['en']!)[at.month - 1];
  final year = at.year == now.year ? '' : ' ${at.year}';
  return '${at.day} $month$year, $hm';
}

/// What the message is about, in one line: "Keza is asking for 2,000 RWF".
IconData messageIcon(String kind) => switch (kind) {
  'money_request' => Icons.payments_rounded,
  'call_me' => Icons.call_rounded,
  'pick_me_up' => Icons.directions_walk_rounded,
  'school_note' => Icons.campaign_rounded,
  _ => Icons.chat_bubble_rounded,
};

({IconData icon, String line}) messageSummary(StudentMessage m, String lang) {
  final name = m.firstName.isEmpty ? _t(lang, 'Umwana', 'Your child', 'Votre enfant') : m.firstName;
  final amount = m.amount != null ? '${moneyText(m.amount!)} RWF' : null;
  return switch (m.kind) {
    'money_request' => (
      icon: Icons.payments_rounded,
      line: amount != null
          ? _t(lang, '$name arasaba $amount', '$name is asking for $amount', '$name demande $amount')
          : _t(lang, '$name arasaba amafaranga', '$name is asking for money', '$name demande de l\'argent'),
    ),
    'call_me' => (
      icon: Icons.call_rounded,
      line: _t(lang, '$name arasaba ko umuhamagara', '$name asks you to call', '$name demande que vous appeliez'),
    ),
    'pick_me_up' => (
      icon: Icons.directions_walk_rounded,
      line: _t(
        lang,
        '$name arasaba ko uza kumutwara',
        '$name asks to be picked up',
        '$name demande qu\'on vienne le chercher',
      ),
    ),
    'school_note' => (
      icon: Icons.campaign_rounded,
      line: _t(
        lang,
        'Ubutumwa bw\'ishuri kuri $name',
        'A note from school about $name',
        'Un mot de l\'école sur $name',
      ),
    ),
    _ => (
      icon: Icons.chat_bubble_rounded,
      line: _t(lang, '$name yohereje ubutumwa', '$name sent a message', '$name a envoyé un message'),
    ),
  };
}

/// What the chat keeps about the message the parent asked Soma about. Plain
/// values only, so it can be saved with the chat history.
Map<String, dynamic> messageQuote(StudentMessage m, String lang) {
  final summary = messageSummary(m, lang);
  return {
    'id': m.id,
    'student_id': m.studentId,
    'name': m.studentName,
    'photo': m.photoUrl,
    'line': summary.line,
    'kind': m.kind,
    'text': m.text,
    'at': m.createdAt.toIso8601String(),
    'time': messageTime(m.createdAt, lang),
  };
}

/// The chip shown in the parent's chat bubble instead of a typed question:
/// which message Soma is explaining.
class MessageQuoteChip extends StatelessWidget {
  const MessageQuoteChip({super.key, required this.quote});

  final Map quote;

  @override
  Widget build(BuildContext context) {
    final id = (quote['id'] as num?)?.toInt() ?? 0;
    final accent = messageAccent(id);
    final name = quote['name']?.toString() ?? '';
    final text = quote['text']?.toString() ?? '';
    return Container(
      constraints: const BoxConstraints(maxWidth: 300),
      decoration: BoxDecoration(color: accent.wash, borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 5, color: accent.color),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    MessageAvatar(name: name, url: quote['photo']?.toString(), accent: accent, size: 34),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Icon(messageIcon(quote['kind']?.toString() ?? ''), size: 14, color: accent.color),
                              const SizedBox(width: 5),
                              Expanded(
                                child: Text(
                                  quote['line']?.toString() ?? '',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontFamily: 'gilroy',
                                    fontSize: 13.5,
                                    height: 1.25,
                                    color: Color(0xFF14172B),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (text.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(
                              '“$text”',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: 'gilroy-light',
                                fontSize: 13,
                                height: 1.3,
                                color: Color(0xFF3B3F55),
                              ),
                            ),
                          ],
                          const SizedBox(height: 4),
                          Text(
                            quote['time']?.toString() ?? '',
                            style: const TextStyle(
                              fontFamily: 'gilroy-light',
                              fontSize: 11.5,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Child's photo, or initials on the message colour.
class MessageAvatar extends StatelessWidget {
  const MessageAvatar({
    super.key,
    required this.name,
    required this.url,
    required this.accent,
    this.size = 46,
    this.unread = false,
  });

  final String name;
  final String? url;
  final MessageAccent accent;
  final double size;
  final bool unread;

  @override
  Widget build(BuildContext context) {
    final initials = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .take(2)
        .map((p) => p[0].toUpperCase())
        .join();
    final fallback = Container(
      color: accent.color,
      alignment: Alignment.center,
      child: Text(
        initials.isEmpty ? '?' : initials,
        style: TextStyle(fontFamily: 'gilroy', fontSize: size * 0.33, color: accent.on),
      ),
    );
    final radius = BorderRadius.circular(size * 0.34);
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(color: accent.color, width: 2),
            ),
            padding: const EdgeInsets.all(2),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(size * 0.26),
              child: SizedBox.expand(
                child: (url ?? '').startsWith('http')
                    ? CachedNetworkImageWrapper(imageUrl: url!, errorWidget: fallback)
                    : fallback,
              ),
            ),
          ),
          if (unread)
            Positioned(
              right: -3,
              top: -3,
              child: Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF6A00),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2.4),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
