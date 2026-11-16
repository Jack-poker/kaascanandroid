import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kaascan/widgets/cached_network_image_wrapper.dart';

/// Agentic UI for the Somakadi assistant.
///
/// The backend (`POST /ask`) decides what to show: next to its sentence it
/// returns a list of `ui` blocks and `suggestions`. This file renders them.
/// Every label and every follow-up prompt comes from the server, already in
/// the parent's language, so nothing here needs translating.
///
/// Block kinds: `balance`, `children`, `transactions`, `amount_picker`,
/// `topup_confirm`, `wallet`. Unknown kinds are skipped, so a newer backend
/// never breaks an older app.

/// Result of asking the host screen to carry out a confirmed top-up.
class AgenticTopupResult {
  final bool ok;
  final String message;
  const AgenticTopupResult({required this.ok, this.message = ''});
}

/// Sends [message] as the parent's next prompt. [studentId] tells the
/// assistant which child the conversation is now about.
typedef AgenticSend = void Function(String message, String? studentId);

/// Performs the top-up described by a `topup_confirm` block.
typedef AgenticConfirmTopup = Future<AgenticTopupResult> Function(
  Map<dynamic, dynamic> block,
);

class _Palette {
  static const blue = Color.fromARGB(255, 0, 25, 205); // "kadi" in the logo
  static const ink = Color(0xFF1A1F36);
  static const muted = Color(0xFF6B7280);
  static const tint = Color(0xFFF3F5FF);
  static const line = Color(0xFFE8EBF5);
  static const success = Color(0xFF0E9F6E);
  static const danger = Color(0xFFD92D20);
}

const _display = 'gilroy';
const _body = 'gilroy-light';

// ── safe readers ────────────────────────────────────────────────────────────

String _str(dynamic map, String key) =>
    map is Map && map[key] != null ? map[key].toString() : '';

double _num(dynamic value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0;
  return 0;
}

Map<dynamic, dynamic> _map(dynamic value) =>
    value is Map ? value : const <dynamic, dynamic>{};

List<dynamic> _list(dynamic value) => value is List ? value : const [];

/// `12500` → `12,500`; keeps two decimals only when there is a real fraction.
String formatMoney(dynamic value) {
  final number = _num(value);
  final whole = (number - number.roundToDouble()).abs() < 0.005;
  final text = whole ? number.round().toString() : number.toStringAsFixed(2);
  final parts = text.split('.');
  final digits = parts[0].replaceFirst('-', '');
  final buffer = StringBuffer();
  for (int i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  final sign = number < 0 ? '-' : '';
  return parts.length > 1 ? '$sign$buffer.${parts[1]}' : '$sign$buffer';
}

String _formatWhen(String iso) {
  final parsed = DateTime.tryParse(iso);
  if (parsed == null) return '';
  // The backend stores UTC without a zone marker.
  final local = DateTime.utc(
    parsed.year,
    parsed.month,
    parsed.day,
    parsed.hour,
    parsed.minute,
  ).toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(local.day)}/${two(local.month)} · ${two(local.hour)}:${two(local.minute)}';
}

// ── entry point ─────────────────────────────────────────────────────────────

class AgenticBlocks extends StatelessWidget {
  final List<dynamic> blocks;
  final List<dynamic> suggestions;
  final AgenticSend onSend;
  final AgenticConfirmTopup? onConfirmTopup;

  const AgenticBlocks({
    super.key,
    required this.blocks,
    required this.suggestions,
    required this.onSend,
    this.onConfirmTopup,
  });

  /// True when [response] carries anything this widget can draw.
  static bool hasContent(Map<dynamic, dynamic>? response) {
    if (response == null) return false;
    return _list(response['ui']).isNotEmpty ||
        _list(response['suggestions']).isNotEmpty;
  }

  Widget? _build(Map<dynamic, dynamic> block) {
    switch (_str(block, 'kind')) {
      case 'balance':
        return _BalanceCard(block: block);
      case 'children':
        return _ChildrenCard(block: block, onSend: onSend);
      case 'transactions':
        return _TransactionsCard(block: block);
      case 'amount_picker':
        return _AmountPickerCard(block: block, onSend: onSend);
      case 'topup_confirm':
        return _TopupConfirmCard(block: block, onConfirm: onConfirmTopup);
      case 'wallet':
        return _WalletCard(block: block);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    for (final raw in blocks) {
      if (raw is! Map) continue;
      final widget = _build(raw);
      if (widget != null) children.add(widget);
    }
    if (suggestions.isNotEmpty) {
      children.add(_SuggestionChips(suggestions: suggestions, onSend: onSend));
    }
    if (children.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (int i = 0; i < children.length; i++)
            _Entrance(
              delay: Duration(milliseconds: 90 * i),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: children[i],
              ),
            ),
        ],
      ),
    );
  }
}

/// Fades and lifts a block into place, one after another.
class _Entrance extends StatefulWidget {
  final Duration delay;
  final Widget child;
  const _Entrance({required this.delay, required this.child});

  @override
  State<_Entrance> createState() => _EntranceState();
}

class _EntranceState extends State<_Entrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
  );
  late final Animation<double> _curve = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
  );

  @override
  void initState() {
    super.initState();
    Future.delayed(widget.delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _curve,
      child: AnimatedBuilder(
        animation: _curve,
        builder: (context, child) => Transform.translate(
          offset: Offset(0, 14 * (1 - _curve.value)),
          child: child,
        ),
        child: widget.child,
      ),
    );
  }
}

// ── shared pieces ───────────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  const _Card({required this.child, this.padding = const EdgeInsets.all(18)});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
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
      child: child,
    );
  }
}

class _Avatar extends StatelessWidget {
  final Map<dynamic, dynamic> student;
  final double size;
  const _Avatar({required this.student, this.size = 46});

  @override
  Widget build(BuildContext context) {
    final name = _str(student, 'student_name');
    final photo = _str(student, 'photo_url');
    final initials = name
        .split(' ')
        .where((w) => w.isNotEmpty)
        .take(2)
        .map((w) => w[0].toUpperCase())
        .join();

    final fallback = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: _Palette.tint,
        shape: BoxShape.circle,
      ),
      child: Text(
        initials.isEmpty ? '?' : initials,
        style: TextStyle(
          color: _Palette.blue,
          fontFamily: _display,
          fontWeight: FontWeight.w700,
          fontSize: size * 0.36,
        ),
      ),
    );
    if (photo.isEmpty) return fallback;

    return ClipOval(
      child: CachedNetworkImageWrapper(
        imageUrl: photo,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorWidget: fallback,
        placeholder: fallback,
      ),
    );
  }
}

class _StudentHeader extends StatelessWidget {
  final Map<dynamic, dynamic> student;
  const _StudentHeader({required this.student});

  @override
  Widget build(BuildContext context) {
    final school = _str(student, 'school_name');
    final grade = _str(student, 'grade');
    final subtitle = [school, grade].where((s) => s.isNotEmpty).join(' · ');
    return Row(
      children: [
        _Avatar(student: student),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _str(student, 'student_name'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _Palette.ink,
                  fontFamily: _display,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              if (subtitle.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _Palette.muted,
                    fontFamily: _body,
                    fontWeight: FontWeight.w600,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _CardTitle extends StatelessWidget {
  final String text;
  const _CardTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        color: _Palette.muted,
        fontFamily: _display,
        fontWeight: FontWeight.w700,
        fontSize: 11,
        letterSpacing: 1.2,
      ),
    );
  }
}

/// A large amount with its currency set smaller beside it.
class _Amount extends StatelessWidget {
  final dynamic value;
  final String currency;
  final double size;
  final Color color;
  const _Amount({
    required this.value,
    required this.currency,
    this.size = 34,
    this.color = _Palette.ink,
  });

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            formatMoney(value),
            style: TextStyle(
              color: color,
              fontFamily: _display,
              fontWeight: FontWeight.w800,
              fontSize: size,
              height: 1.05,
              letterSpacing: -0.6,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            currency,
            style: TextStyle(
              color: _Palette.muted,
              fontFamily: _display,
              fontWeight: FontWeight.w700,
              fontSize: size * 0.4,
            ),
          ),
        ],
      ),
    );
  }
}

// ── balance ─────────────────────────────────────────────────────────────────

class _BalanceCard extends StatelessWidget {
  final Map<dynamic, dynamic> block;
  const _BalanceCard({required this.block});

  @override
  Widget build(BuildContext context) {
    final labels = _map(block['labels']);
    final currency = _str(block, 'currency');
    final dailyLimit = _num(block['daily_limit']);
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StudentHeader(student: _map(block['student'])),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _Palette.tint,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _CardTitle(_str(labels, 'balance')),
                const SizedBox(height: 8),
                _Amount(
                  value: block['balance'],
                  currency: currency,
                  color: _Palette.blue,
                ),
                if (dailyLimit > 0) ...[
                  const SizedBox(height: 10),
                  Text(
                    '${_str(labels, 'daily_limit')}: ${formatMoney(dailyLimit)} $currency',
                    style: const TextStyle(
                      color: _Palette.muted,
                      fontFamily: _body,
                      fontWeight: FontWeight.w600,
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── wallet ──────────────────────────────────────────────────────────────────

class _WalletCard extends StatelessWidget {
  final Map<dynamic, dynamic> block;
  const _WalletCard({required this.block});

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: const BoxDecoration(
              color: _Palette.tint,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.account_balance_wallet_outlined,
              color: _Palette.blue,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _CardTitle(_str(_map(block['labels']), 'wallet')),
                const SizedBox(height: 6),
                _Amount(
                  value: block['balance'],
                  currency: _str(block, 'currency'),
                  size: 28,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── children ────────────────────────────────────────────────────────────────

class _ChildrenCard extends StatelessWidget {
  final Map<dynamic, dynamic> block;
  final AgenticSend onSend;
  const _ChildrenCard({required this.block, required this.onSend});

  @override
  Widget build(BuildContext context) {
    final items = _list(block['items']).whereType<Map>().toList();
    final currency = _str(block, 'currency');
    return _Card(
      padding: const EdgeInsets.fromLTRB(8, 18, 8, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: _CardTitle(_str(block, 'title')),
          ),
          const SizedBox(height: 6),
          for (int i = 0; i < items.length; i++) ...[
            if (i > 0)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 10),
                child: Divider(height: 1, color: _Palette.line),
              ),
            _ChildRow(item: items[i], currency: currency, onSend: onSend),
          ],
        ],
      ),
    );
  }
}

class _ChildRow extends StatelessWidget {
  final Map<dynamic, dynamic> item;
  final String currency;
  final AgenticSend onSend;
  const _ChildRow({
    required this.item,
    required this.currency,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    final student = _map(item['student']);
    final message = _str(item, 'message');
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: message.isEmpty
            ? null
            : () {
                HapticFeedback.selectionClick();
                onSend(message, _str(student, 'student_id'));
              },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          child: Row(
            children: [
              _Avatar(student: student, size: 42),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _str(student, 'student_name'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _Palette.ink,
                        fontFamily: _display,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _str(student, 'school_name'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _Palette.muted,
                        fontFamily: _body,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatMoney(item['balance']),
                    style: const TextStyle(
                      color: _Palette.blue,
                      fontFamily: _display,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    currency,
                    style: const TextStyle(
                      color: _Palette.muted,
                      fontFamily: _display,
                      fontWeight: FontWeight.w700,
                      fontSize: 10.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.chevron_right_rounded,
                color: _Palette.muted,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── transactions ────────────────────────────────────────────────────────────

class _TransactionsCard extends StatelessWidget {
  final Map<dynamic, dynamic> block;
  const _TransactionsCard({required this.block});

  @override
  Widget build(BuildContext context) {
    final items = _list(block['items']).whereType<Map>().toList();
    final labels = _map(block['labels']);
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardTitle(_str(block, 'title')),
          const SizedBox(height: 6),
          for (int i = 0; i < items.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: _Palette.line),
            _TransactionRow(item: items[i], labels: labels),
          ],
        ],
      ),
    );
  }
}

class _TransactionRow extends StatelessWidget {
  final Map<dynamic, dynamic> item;
  final Map<dynamic, dynamic> labels;
  const _TransactionRow({required this.item, required this.labels});

  @override
  Widget build(BuildContext context) {
    final incoming = _str(item, 'direction') == 'in';
    final status = _str(item, 'status');
    final failed = status == 'failed';
    final pending = status == 'pending';

    final when = _formatWhen(_str(item, 'timestamp'));
    final statusLabel = failed
        ? _str(labels, 'failed')
        : pending
            ? _str(labels, 'pending')
            : '';
    final subtitle = [when, statusLabel].where((s) => s.isNotEmpty).join(' · ');

    final amountColor = failed
        ? _Palette.muted
        : incoming
            ? _Palette.success
            : _Palette.ink;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: incoming
                  ? _Palette.success.withValues(alpha: 0.12)
                  : _Palette.tint,
              shape: BoxShape.circle,
            ),
            child: Icon(
              incoming
                  ? Icons.south_west_rounded
                  : Icons.shopping_bag_outlined,
              color: incoming ? _Palette.success : _Palette.blue,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _str(item, 'title'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _Palette.ink,
                    fontFamily: _display,
                    fontWeight: FontWeight.w700,
                    fontSize: 14.5,
                  ),
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: failed ? _Palette.danger : _Palette.muted,
                      fontFamily: _body,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${incoming ? '+' : '−'}${formatMoney(item['amount'])}',
            style: TextStyle(
              color: amountColor,
              fontFamily: _display,
              fontWeight: FontWeight.w800,
              fontSize: 15,
              decoration: failed ? TextDecoration.lineThrough : null,
            ),
          ),
        ],
      ),
    );
  }
}

// ── amount picker ───────────────────────────────────────────────────────────

class _AmountPickerCard extends StatelessWidget {
  final Map<dynamic, dynamic> block;
  final AgenticSend onSend;
  const _AmountPickerCard({required this.block, required this.onSend});

  @override
  Widget build(BuildContext context) {
    final student = _map(block['student']);
    final options = _list(block['options']).whereType<Map>().toList();
    final currency = _str(block, 'currency');
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StudentHeader(student: student),
          const SizedBox(height: 16),
          _CardTitle(_str(block, 'title')),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              const gap = 10.0;
              final width = (constraints.maxWidth - gap) / 2;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (final option in options)
                    SizedBox(
                      width: width,
                      child: Material(
                        color: _Palette.tint,
                        borderRadius: BorderRadius.circular(16),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            onSend(
                              _str(option, 'message'),
                              _str(student, 'student_id'),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 16,
                            ),
                            child: _Amount(
                              value: option['amount'],
                              currency: currency,
                              size: 20,
                              color: _Palette.blue,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

// ── top-up confirmation ─────────────────────────────────────────────────────

enum _TopupState { review, sending, sent, failed, cancelled }

class _TopupConfirmCard extends StatefulWidget {
  final Map<dynamic, dynamic> block;
  final AgenticConfirmTopup? onConfirm;
  const _TopupConfirmCard({required this.block, required this.onConfirm});

  @override
  State<_TopupConfirmCard> createState() => _TopupConfirmCardState();
}

class _TopupConfirmCardState extends State<_TopupConfirmCard> {
  _TopupState _state = _TopupState.review;
  String _error = '';

  Map<dynamic, dynamic> get _labels => _map(widget.block['labels']);

  Future<void> _confirm() async {
    // One tap, one payment request: ignore anything while it is in flight
    // or once it has gone out.
    if (_state != _TopupState.review && _state != _TopupState.failed) return;
    final confirm = widget.onConfirm;
    if (confirm == null) return;

    HapticFeedback.mediumImpact();
    setState(() {
      _state = _TopupState.sending;
      _error = '';
    });

    AgenticTopupResult result;
    try {
      result = await confirm(widget.block);
    } catch (_) {
      result = const AgenticTopupResult(ok: false);
    }
    if (!mounted) return;

    setState(() {
      _state = result.ok ? _TopupState.sent : _TopupState.failed;
      _error = result.ok ? '' : result.message;
    });
    if (result.ok) {
      HapticFeedback.heavyImpact();
    }
  }

  Widget _line(String label, String value, {bool strong = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: strong ? _Palette.ink : _Palette.muted,
                fontFamily: strong ? _display : _body,
                fontWeight: strong ? FontWeight.w700 : FontWeight.w600,
                fontSize: strong ? 15 : 14,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: strong ? _Palette.blue : _Palette.ink,
              fontFamily: _display,
              fontWeight: strong ? FontWeight.w800 : FontWeight.w700,
              fontSize: strong ? 18 : 14.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _outcome({
    required IconData icon,
    required Color color,
    required String title,
    String detail = '',
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontFamily: _display,
                    fontWeight: FontWeight.w700,
                    fontSize: 14.5,
                  ),
                ),
                if (detail.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    detail,
                    style: const TextStyle(
                      color: _Palette.ink,
                      fontFamily: _body,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      height: 1.35,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _actions() {
    switch (_state) {
      case _TopupState.sent:
        return _outcome(
          icon: Icons.check_circle_rounded,
          color: _Palette.success,
          title: _str(_labels, 'request_sent'),
          detail: _str(_labels, 'approve_on_phone'),
        );
      case _TopupState.cancelled:
        return _outcome(
          icon: Icons.cancel_outlined,
          color: _Palette.muted,
          title: _str(_labels, 'cancelled'),
        );
      case _TopupState.review:
      case _TopupState.sending:
      case _TopupState.failed:
        final sending = _state == _TopupState.sending;
        return Column(
          children: [
            if (_state == _TopupState.failed) ...[
              _outcome(
                icon: Icons.error_outline_rounded,
                color: _Palette.danger,
                title: _str(_labels, 'request_failed'),
                detail: _error,
              ),
              const SizedBox(height: 12),
            ],
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 52,
                    child: TextButton(
                      onPressed: sending
                          ? null
                          : () => setState(
                                () => _state = _TopupState.cancelled,
                              ),
                      style: TextButton.styleFrom(
                        foregroundColor: _Palette.muted,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        _str(_labels, 'cancel'),
                        style: const TextStyle(
                          fontFamily: _display,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: sending ? null : _confirm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _Palette.blue,
                        disabledBackgroundColor:
                            _Palette.blue.withValues(alpha: 0.6),
                        foregroundColor: Colors.white,
                        disabledForegroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: sending
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Flexible(
                                  child: Text(
                                    _str(_labels, 'sending'),
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontFamily: _display,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : Text(
                              _str(_labels, 'confirm'),
                              style: const TextStyle(
                                fontFamily: _display,
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                                letterSpacing: 0.3,
                              ),
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final block = widget.block;
    final currency = _str(block, 'currency');
    final phone = _str(block, 'phone');
    final payWith = [
      _str(_labels, 'pay_with'),
      phone,
    ].where((s) => s.isNotEmpty).join(' · ');

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardTitle(_str(_labels, 'confirm_title')),
          const SizedBox(height: 12),
          _StudentHeader(student: _map(block['student'])),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: _Palette.tint,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              children: [
                _line(
                  _str(_labels, 'amount'),
                  '${formatMoney(block['amount'])} $currency',
                ),
                _line(
                  _str(_labels, 'fee'),
                  '${formatMoney(block['fee'])} $currency',
                ),
                const Divider(height: 14, color: _Palette.line),
                _line(
                  _str(_labels, 'total'),
                  '${formatMoney(block['charge'])} $currency',
                  strong: true,
                ),
              ],
            ),
          ),
          if (payWith.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(
                  Icons.phone_iphone_rounded,
                  color: _Palette.muted,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    payWith,
                    style: const TextStyle(
                      color: _Palette.muted,
                      fontFamily: _body,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            alignment: Alignment.topCenter,
            child: _actions(),
          ),
        ],
      ),
    );
  }
}

// ── suggestion chips ────────────────────────────────────────────────────────

class _SuggestionChips extends StatelessWidget {
  final List<dynamic> suggestions;
  final AgenticSend onSend;
  const _SuggestionChips({required this.suggestions, required this.onSend});

  @override
  Widget build(BuildContext context) {
    final chips = suggestions.whereType<Map>().toList();
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final chip in chips)
          _Chip(
            label: _str(chip, 'label'),
            primary: _str(chip, 'style') == 'primary',
            onTap: () {
              HapticFeedback.selectionClick();
              final studentId = _str(chip, 'student_id');
              onSend(
                _str(chip, 'message'),
                studentId.isEmpty ? null : studentId,
              );
            },
          ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool primary;
  final VoidCallback onTap;
  const _Chip({required this.label, required this.primary, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: primary ? Colors.white : Colors.white.withValues(alpha: 0.16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(100),
        side: BorderSide(
          color: Colors.white.withValues(alpha: primary ? 1 : 0.55),
          width: 1.2,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          child: Text(
            label,
            style: TextStyle(
              color: primary ? _Palette.blue : Colors.white,
              fontFamily: _display,
              fontWeight: FontWeight.w700,
              fontSize: 13.5,
            ),
          ),
        ),
      ),
    );
  }
}
