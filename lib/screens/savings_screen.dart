import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kaascan/Api/client.dart';
import 'package:kaascan/Api/config.dart';
import 'package:kaascan/components/soma_robot.dart';
import '../services/language_service.dart';

// ── Colours (the app's blue and Soma's orange) ───────────────────────────────

const _blue = Color(0xFF0022FF);
const _blueDeep = Color(0xFF0019CD);
const _orange = Color(0xFFFF3C00);
const _ink = Color(0xFF11142D);
const _soft = Color(0xFF646C9C);
const _green = Color(0xFF16A34A);

String _rwf(num v) => '${NumberFormat('#,###').format(v.round())} RWF';
String _t(String key, String fallback) => languageService.t(key, fallback: fallback);

// ── Data ─────────────────────────────────────────────────────────────────────

class SavingsData {
  SavingsData(this.raw);
  final Map<String, dynamic> raw;

  double _d(dynamic v) => (v as num?)?.toDouble() ?? 0;
  double get saved => _d(raw['saved']);
  double get thisWeek => _d(raw['this_week']);
  double get thisMonth => _d(raw['this_month']);
  double get totalPutAside => _d(raw['total_put_aside']);
  int get timesSaved => (raw['times_saved'] as num?)?.toInt() ?? 0;
  Map get autoSave => (raw['auto_save'] as Map?) ?? const {};
  bool get on => autoSave['on'] == true;
  String get offReason => '${autoSave['reason'] ?? ''}';
  double get rate => _d(autoSave['rate']);
  double get minPurchase => _d(autoSave['min_purchase']);
  double get maxPerPurchase => _d(autoSave['max_per_purchase']);
  Map get milestone => (raw['milestone'] as Map?) ?? const {};
  double? get nextGoal => (milestone['next'] as num?)?.toDouble();
  double get progress => _d(milestone['progress']).clamp(0, 1).toDouble();
  List<Map> get weeks => List<Map>.from(raw['weeks'] ?? const []);
  List<Map> get events => List<Map>.from(raw['events'] ?? const []);
}

/// GET /students/{id}/savings for the logged-in parent.
Future<SavingsData?> fetchSavings(String studentId) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('login_token');
    if (token == null || studentId.isEmpty) return null;
    final res = await api_Call.get(
      '$Base_Url/students/$studentId/savings',
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    if (res.statusCode == 200 && res.data is Map) {
      return SavingsData(Map<String, dynamic>.from(res.data));
    }
  } catch (e) {
    debugPrint('[savings] $e');
  }
  return null;
}

// ── Students page: the savings card (replaces the history list) ──────────────

class SavingsPreviewCard extends StatefulWidget {
  const SavingsPreviewCard({super.key, required this.studentId, required this.studentName, this.data});
  final String studentId;
  final String studentName;

  /// Preloaded data (previews and tests); fetched from the server otherwise.
  final SavingsData? data;

  @override
  State<SavingsPreviewCard> createState() => _SavingsPreviewCardState();
}

class _SavingsPreviewCardState extends State<SavingsPreviewCard> {
  late Future<SavingsData?> _future = widget.data != null ? Future.value(widget.data) : fetchSavings(widget.studentId);

  @override
  void didUpdateWidget(SavingsPreviewCard old) {
    super.didUpdateWidget(old);
    if (old.studentId != widget.studentId) _future = fetchSavings(widget.studentId);
  }

  void _open() {
    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (_) => SavingsScreen(studentId: widget.studentId, studentName: widget.studentName),
      ),
    ).then((_) => setState(() => _future = fetchSavings(widget.studentId)));
  }

  @override
  Widget build(BuildContext context) {
    final first = widget.studentName.trim().split(' ').first;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _t('savings.title', 'Savings'),
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900, fontFamily: 'gilroy-light'),
          ),
          const SizedBox(height: 10),
          FutureBuilder<SavingsData?>(
            future: _future,
            builder: (context, snap) {
              final d = snap.data;
              final loading = snap.connectionState != ConnectionState.done;
              return GestureDetector(
                onTap: _open,
                child: Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(26)),
                  child: Stack(
                    children: [
                      // A warm orange glow behind Soma.
                      Positioned(
                        left: -40,
                        top: -30,
                        child: Container(
                          width: 170,
                          height: 170,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(colors: [_orange.withValues(alpha: 0.16), _orange.withValues(alpha: 0)]),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(4, 8, 18, 16),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 112,
                              height: 112,
                              child: OverflowBox(
                                maxWidth: 170,
                                maxHeight: 170,
                                child: SomaRobot(
                                  size: 170,
                                  mood: (d?.thisWeek ?? 0) > 0 ? SomaMood.jump : SomaMood.idle,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: loading
                                  ? const Padding(
                                      padding: EdgeInsets.symmetric(vertical: 30),
                                      child: Center(child: CupertinoActivityIndicator()),
                                    )
                                  : d == null
                                  ? Text(
                                      _t('savings.unavailable', "Couldn't load savings. Tap to try again."),
                                      style: const TextStyle(fontFamily: 'gilroy', color: _soft, fontSize: 14),
                                    )
                                  : Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '$first ${_t('savings.has_saved', 'has saved')}',
                                          style: const TextStyle(fontFamily: 'gilroy', color: _soft, fontSize: 13.5),
                                        ),
                                        const SizedBox(height: 2),
                                        FittedBox(
                                          fit: BoxFit.scaleDown,
                                          alignment: Alignment.centerLeft,
                                          child: Text(
                                            _rwf(d.saved),
                                            style: const TextStyle(fontFamily: 'gilroy', color: _ink, fontSize: 28, fontWeight: FontWeight.w800),
                                          ),
                                        ),
                                        const SizedBox(height: 10),
                                        _ProgressBar(value: d.progress),
                                        const SizedBox(height: 6),
                                        Text(
                                          d.nextGoal == null
                                              ? _t('savings.all_goals', 'Every goal reached!')
                                              : '${_t('savings.next_goal', 'Next goal')} ${_rwf(d.nextGoal!)}',
                                          style: const TextStyle(fontFamily: 'gilroy', color: _soft, fontSize: 12.5),
                                        ),
                                        const SizedBox(height: 10),
                                        Row(
                                          children: [
                                            if (d.thisWeek > 0)
                                              _Chip(
                                                '+${_rwf(d.thisWeek)} ${_t('savings.this_week_short', 'this week')}',
                                                color: _green,
                                              )
                                            else
                                              _Chip(
                                                d.on ? '${d.rate.toStringAsFixed(d.rate % 1 == 0 ? 0 : 1)}% ${_t('savings.auto', 'auto-save')}' : _t('savings.paused', 'Auto-save paused'),
                                                color: d.on ? _blue : _soft,
                                              ),
                                            const Spacer(),
                                            const Icon(CupertinoIcons.chevron_right_circle_fill, color: _orange, size: 26),
                                          ],
                                        ),
                                      ],
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ── The savings page ─────────────────────────────────────────────────────────

class SavingsScreen extends StatefulWidget {
  const SavingsScreen({super.key, required this.studentId, required this.studentName, this.data, this.embedded = false});
  final String studentId;
  final String studentName;

  /// Inside a tab (the Messages tab): no back button, see-through background.
  final bool embedded;

  /// Preloaded data (previews and tests); fetched from the server otherwise.
  final SavingsData? data;

  @override
  State<SavingsScreen> createState() => _SavingsScreenState();
}

class _SavingsScreenState extends State<SavingsScreen> {
  late Future<SavingsData?> _future = widget.data != null ? Future.value(widget.data) : fetchSavings(widget.studentId);

  Future<void> _reload() async {
    final f = fetchSavings(widget.studentId);
    setState(() => _future = f);
    await f;
  }

  @override
  Widget build(BuildContext context) {
    final first = widget.studentName.trim().split(' ').first;
    return Scaffold(
      backgroundColor: widget.embedded ? Colors.transparent : const Color(0xFFEEF1FF),
      body: FutureBuilder<SavingsData?>(
        future: _future,
        builder: (context, snap) {
          final d = snap.data;
          return RefreshIndicator(
            color: _orange,
            onRefresh: _reload,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
              slivers: [
                SliverToBoxAdapter(
                  child: _Hero(first: first, data: d, loading: snap.connectionState != ConnectionState.done, embedded: widget.embedded),
                ),
                if (snap.connectionState == ConnectionState.done && d == null)
                  SliverToBoxAdapter(child: _Problem(onRetry: _reload))
                else if (d != null) ...[
                  SliverToBoxAdapter(child: _Stats(d)),
                  SliverToBoxAdapter(child: _HowItWorks(d, first)),
                  SliverToBoxAdapter(child: _WeeksChart(d)),
                  SliverToBoxAdapter(child: _Activity(d, first)),
                  // Room for the floating nav bar when shown inside a tab.
                  SliverToBoxAdapter(child: SizedBox(height: widget.embedded ? 150 : 40)),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Blue hero: Soma, the saved amount counting up, and the goal ring.
class _Hero extends StatelessWidget {
  const _Hero({required this.first, required this.data, required this.loading, this.embedded = false});
  final String first;
  final SavingsData? data;
  final bool loading;
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final d = data;
    final top = MediaQuery.paddingOf(context).top;
    return Container(
      margin: embedded ? const EdgeInsets.fromLTRB(20, 8, 20, 0) : EdgeInsets.zero,
      padding: EdgeInsets.fromLTRB(20, embedded ? 4 : top + 8, 20, 28),
      decoration: embedded
          // Glass card over the tab's blue doodles.
          ? BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
            )
          : const BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF2B4BFF), _blue, _blueDeep]),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(36)),
            ),
      child: Column(
        children: [
          if (!embedded) Row(
            children: [
              _CircleButton(icon: CupertinoIcons.back, onTap: () => Navigator.pop(context)),
              const Spacer(),
              Text(
                _t('savings.title', 'Savings'),
                style: const TextStyle(fontFamily: 'gilroy', color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              const SizedBox(width: 44),
            ],
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 220,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // The goal ring around Soma.
                SizedBox(
                  width: 210,
                  height: 210,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: d?.progress ?? 0),
                    duration: const Duration(milliseconds: 1400),
                    curve: Curves.easeOutCubic,
                    builder: (_, v, __) => CustomPaint(painter: _RingPainter(v)),
                  ),
                ),
                const _FloatingCoins(),
                SizedBox(
                  width: 170,
                  height: 170,
                  child: OverflowBox(
                    maxWidth: 250,
                    maxHeight: 250,
                    child: SomaRobot(size: 250, mood: SomaMood.jump),
                  ),
                ),
              ],
            ),
          ),
          Text(
            '$first ${_t('savings.has_saved', 'has saved')}',
            style: TextStyle(fontFamily: 'gilroy', color: Colors.white.withValues(alpha: 0.85), fontSize: 15),
          ),
          const SizedBox(height: 4),
          loading
              ? const Padding(padding: EdgeInsets.all(10), child: CupertinoActivityIndicator(color: Colors.white))
              : TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: d?.saved ?? 0),
                  duration: const Duration(milliseconds: 1200),
                  curve: Curves.easeOutCubic,
                  builder: (_, v, __) => Text(
                    _rwf(v),
                    style: const TextStyle(fontFamily: 'gilroy', color: Colors.white, fontSize: 40, fontWeight: FontWeight.w800, height: 1.1),
                  ),
                ),
          const SizedBox(height: 10),
          if (d != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(999)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(d.on ? CupertinoIcons.sparkles : CupertinoIcons.pause_circle, color: Colors.white, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    d.nextGoal == null
                        ? _t('savings.all_goals', 'Every goal reached!')
                        : '${(d.progress * 100).round()}% ${_t('savings.of_way_to', 'of the way to')} ${_rwf(d.nextGoal!)}',
                    style: const TextStyle(fontFamily: 'gilroy', color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Stats extends StatelessWidget {
  const _Stats(this.d);
  final SavingsData d;

  @override
  Widget build(BuildContext context) {
    Widget tile(String label, String value, IconData icon, Color color) => Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(height: 10),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value, style: const TextStyle(fontFamily: 'gilroy', color: _ink, fontSize: 17, fontWeight: FontWeight.w800)),
            ),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(fontFamily: 'gilroy', color: _soft, fontSize: 12)),
          ],
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Row(
        children: [
          tile(_t('savings.this_week', 'This week'), _rwf(d.thisWeek), CupertinoIcons.calendar_today, _orange),
          const SizedBox(width: 10),
          tile(_t('savings.this_month', 'This month'), _rwf(d.thisMonth), CupertinoIcons.chart_bar_alt_fill, _blue),
          const SizedBox(width: 10),
          tile(_t('savings.times', 'Times saved'), '${d.timesSaved}', CupertinoIcons.star_fill, _green),
        ],
      ),
    );
  }
}

/// The savings workflow, told with this card's real numbers.
class _HowItWorks extends StatelessWidget {
  const _HowItWorks(this.d, this.first);
  final SavingsData d;
  final String first;

  @override
  Widget build(BuildContext context) {
    final rate = d.rate;
    final example = math.max(1000.0, d.minPurchase);
    final put = math.min(example * rate / 100, d.maxPerPurchase);
    final rateText = '${rate.toStringAsFixed(rate % 1 == 0 ? 0 : 1)}%';
    final steps = [
      (CupertinoIcons.creditcard_fill, _blue, _t('savings.step1_t', 'Buys at school'),
          '$first ${_t('savings.step1_d', 'pays with the card, e.g.')} ${_rwf(example)}'),
      (CupertinoIcons.sparkles, _orange, '${_t('savings.step2_t', 'Soma puts aside')} $rateText',
          '${_rwf(put)} ${_t('savings.step2_d', 'goes into savings automatically')}'),
      (CupertinoIcons.arrow_up_right_circle_fill, _green, _t('savings.step3_t', 'Savings grow'),
          _t('savings.step3_d', 'Every purchase adds a little. No effort needed.')),
      (CupertinoIcons.gift_fill, const Color(0xFF7C3AED), _t('savings.step4_t', 'Reach the goal'),
          _t('savings.step4_d', 'The school can give the savings back to the card when needed.')),
    ];
    return _Section(
      title: _t('savings.how', 'How saving works'),
      trailing: _Chip(
        d.on ? _t('savings.on', 'Auto-save on') : _t('savings.paused', 'Auto-save paused'),
        color: d.on ? _green : _soft,
      ),
      child: Column(
        children: [
          for (var i = 0; i < steps.length; i++)
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: 44,
                    child: Column(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(color: steps[i].$2, borderRadius: BorderRadius.circular(14)),
                          child: Icon(steps[i].$1, color: Colors.white, size: 20),
                        ),
                        if (i < steps.length - 1)
                          Expanded(
                            child: Container(
                              width: 2,
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [steps[i].$2.withValues(alpha: 0.5), steps[i + 1].$2.withValues(alpha: 0.5)],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(top: 2, bottom: i < steps.length - 1 ? 18 : 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(steps[i].$3, style: const TextStyle(fontFamily: 'gilroy', color: _ink, fontSize: 15, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 3),
                          Text(steps[i].$4, style: const TextStyle(fontFamily: 'gilroy', color: _soft, fontSize: 13, height: 1.35)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (!d.on) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFFFFF4E5), borderRadius: BorderRadius.circular(14)),
              child: Row(
                children: [
                  const Icon(CupertinoIcons.info_circle_fill, color: Color(0xFFB06000), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      d.offReason == 'not_for_this_card'
                          ? _t('savings.off_card', "Auto-save isn't turned on for this card's school yet.")
                          : _t('savings.off_paused', 'Auto-save is paused for now. What was saved stays safe.'),
                      style: const TextStyle(fontFamily: 'gilroy', color: Color(0xFF7A4300), fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The last 8 weeks as friendly bars.
class _WeeksChart extends StatelessWidget {
  const _WeeksChart(this.d);
  final SavingsData d;

  @override
  Widget build(BuildContext context) {
    final weeks = d.weeks;
    final maxV = weeks.fold<double>(0, (m, w) => math.max(m, (w['amount'] as num?)?.toDouble() ?? 0));
    return _Section(
      title: _t('savings.weeks', 'Last 8 weeks'),
      child: SizedBox(
        height: 150,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (var i = 0; i < weeks.length; i++)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0, end: maxV == 0 ? 0 : ((weeks[i]['amount'] as num?)?.toDouble() ?? 0) / maxV),
                            duration: Duration(milliseconds: 700 + i * 70),
                            curve: Curves.easeOutBack,
                            builder: (_, v, __) => FractionallySizedBox(
                              heightFactor: math.max(0.04, v.clamp(0, 1).toDouble()),
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  gradient: LinearGradient(
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.topCenter,
                                    colors: i == weeks.length - 1
                                        ? const [_orange, Color(0xFFFF7A45)]
                                        : const [_blue, Color(0xFF6B82FF)],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        i == weeks.length - 1
                            ? _t('savings.now', 'Now')
                            : DateFormat('d/M').format(DateTime.tryParse('${weeks[i]['week_start']}') ?? DateTime.now()),
                        style: TextStyle(
                          fontFamily: 'gilroy',
                          fontSize: 10.5,
                          color: i == weeks.length - 1 ? _orange : _soft,
                          fontWeight: i == weeks.length - 1 ? FontWeight.w700 : FontWeight.w400,
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

class _Activity extends StatelessWidget {
  const _Activity(this.d, this.first);
  final SavingsData d;
  final String first;

  @override
  Widget build(BuildContext context) {
    final events = d.events;
    return _Section(
      title: _t('savings.activity', 'Recent savings'),
      child: events.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 70,
                    height: 70,
                    child: OverflowBox(maxWidth: 120, maxHeight: 120, child: SomaRobot(size: 120, mood: SomaMood.thinking)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${_t('savings.empty_a', 'No savings yet. The next time')} $first ${_t('savings.empty_b', 'buys with the card, Soma will start the savings.')}',
                      style: const TextStyle(fontFamily: 'gilroy', color: _soft, fontSize: 13.5, height: 1.4),
                    ),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                for (final e in events)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: (e['kind'] == 'released' ? _blue : _green).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            e['kind'] == 'released' ? CupertinoIcons.arrow_turn_up_left : CupertinoIcons.plus_circle_fill,
                            color: e['kind'] == 'released' ? _blue : _green,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                e['kind'] == 'released'
                                    ? _t('savings.released', 'Given back to the card')
                                    : '${_t('savings.from', 'From a')} ${_rwf((e['purchase'] as num?) ?? 0)} ${_t('savings.purchase', 'purchase')}',
                                style: const TextStyle(fontFamily: 'gilroy', color: _ink, fontSize: 14.5, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                [
                                  if ('${e['merchant'] ?? ''}'.isNotEmpty && e['kind'] != 'released') '${e['merchant']}',
                                  _when(e['at']),
                                ].join(' · '),
                                style: const TextStyle(fontFamily: 'gilroy', color: _soft, fontSize: 12.5),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '${e['kind'] == 'released' ? '−' : '+'}${_rwf((e['amount'] as num?) ?? 0)}',
                          style: TextStyle(
                            fontFamily: 'gilroy',
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                            color: e['kind'] == 'released' ? _blue : _green,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }

  static String _when(dynamic iso) {
    final t = DateTime.tryParse('${iso ?? ''}');
    if (t == null) return '';
    // The server stores UTC; Rwanda is UTC+2.
    final local = t.add(const Duration(hours: 2));
    return DateFormat('d MMM, HH:mm').format(local);
  }
}

class _Problem extends StatelessWidget {
  const _Problem({required this.onRetry});
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        children: [
          SizedBox(width: 120, height: 120, child: OverflowBox(maxWidth: 180, maxHeight: 180, child: SomaRobot(size: 180, mood: SomaMood.no))),
          const SizedBox(height: 8),
          Text(
            _t('savings.unavailable_long', "Soma couldn't load the savings right now."),
            textAlign: TextAlign.center,
            style: const TextStyle(fontFamily: 'gilroy', color: _ink, fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 14),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _blue, shape: const StadiumBorder()),
            onPressed: onRetry,
            child: Text(_t('common.retry', 'Try again'), style: const TextStyle(fontFamily: 'gilroy')),
          ),
        ],
      ),
    );
  }
}

// ── Small pieces ─────────────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child, this.trailing});
  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(26)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(title, style: const TextStyle(fontFamily: 'gilroy', color: _ink, fontSize: 17, fontWeight: FontWeight.w800)),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.text, {required this.color});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999)),
      child: Text(text, style: TextStyle(fontFamily: 'gilroy', color: color, fontSize: 12, fontWeight: FontWeight.w700)),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.value});
  final double value;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: SizedBox(
        height: 9,
        child: Stack(
          children: [
            Container(color: const Color(0xFFEEF1FF)),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: value),
              duration: const Duration(milliseconds: 1100),
              curve: Curves.easeOutCubic,
              builder: (_, v, __) => FractionallySizedBox(
                widthFactor: math.max(0.03, v),
                child: Container(
                  decoration: const BoxDecoration(gradient: LinearGradient(colors: [_orange, Color(0xFFFF7A45)])),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.16), shape: BoxShape.circle),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }
}

/// The ring around Soma: how far to the next goal.
class _RingPainter extends CustomPainter {
  _RingPainter(this.value);
  final double value;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2 - 8;
    canvas.drawCircle(c, r, Paint()
      ..color = Colors.white.withValues(alpha: 0.14)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12);
    if (value <= 0) return;
    final rect = Rect.fromCircle(center: c, radius: r);
    canvas.drawArc(
      rect,
      -math.pi / 2,
      2 * math.pi * value,
      false,
      Paint()
        ..shader = const SweepGradient(colors: [Color(0xFFFFB199), _orange, Color(0xFFFFB199)]).createShader(rect)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 12,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.value != value;
}

/// Little coins drifting up around Soma.
class _FloatingCoins extends StatefulWidget {
  const _FloatingCoins();

  @override
  State<_FloatingCoins> createState() => _FloatingCoinsState();
}

class _FloatingCoinsState extends State<_FloatingCoins> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const coins = [(-88.0, 0.0, 22.0), (84.0, 0.33, 18.0), (-60.0, 0.6, 16.0), (64.0, 0.8, 20.0)];
    return SizedBox(
      width: 230,
      height: 220,
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) => Stack(
          children: [
            for (final (dx, phase, size) in coins)
              Builder(builder: (_) {
                final t = (_c.value + phase) % 1.0;
                return Positioned(
                  left: 115 + dx - size / 2,
                  top: 170 - t * 150,
                  child: Opacity(
                    opacity: math.sin(t * math.pi).clamp(0, 1).toDouble(),
                    child: Container(
                      width: size,
                      height: size,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(colors: [Color(0xFFFFD86B), Color(0xFFFFB020)]),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.7), width: 1.5),
                      ),
                      // A coin's inner rim, drawn (no glyph needed).
                      child: Center(
                        child: Container(
                          width: size * 0.5,
                          height: size * 0.5,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFFB37400).withValues(alpha: 0.6), width: 1.5),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}


// ── The Messages tab's Savings view: pick a child, see their savings ─────────

class SavingsTab extends StatefulWidget {
  const SavingsTab({super.key});

  @override
  State<SavingsTab> createState() => _SavingsTabState();
}

class _SavingsTabState extends State<SavingsTab> {
  List<Map<String, dynamic>>? _children;
  int _selected = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    List<Map<String, dynamic>> list = const [];
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('login_token');
      if (token != null) {
        final res = await backendClient().studentsLinked(token);
        list = List<Map<String, dynamic>>.from(res.data['students'] ?? const []);
      }
    } catch (e) {
      debugPrint('[savings] children: $e');
    }
    if (mounted) setState(() => _children = list);
  }

  @override
  Widget build(BuildContext context) {
    final kids = _children;
    if (kids == null) return const Center(child: CupertinoActivityIndicator(color: Colors.white));
    if (kids.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(width: 120, height: 120, child: OverflowBox(maxWidth: 180, maxHeight: 180, child: SomaRobot(size: 180))),
              const SizedBox(height: 8),
              Text(
                _t('savings.no_children', 'Add a child to start seeing their savings.'),
                textAlign: TextAlign.center,
                style: const TextStyle(fontFamily: 'gilroy', color: Colors.white, fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }
    final i = _selected.clamp(0, kids.length - 1);
    final child = kids[i];
    final id = '${child['student_id'] ?? ''}';
    return Column(
      children: [
        if (kids.length > 1)
          SizedBox(
            height: 46,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
              itemCount: kids.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, k) {
                final on = k == i;
                final name = '${kids[k]['student_name'] ?? ''}'.trim().split(' ').first;
                return GestureDetector(
                  onTap: () => setState(() => _selected = k),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: on ? Colors.white : Colors.white.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      name,
                      style: TextStyle(fontFamily: 'gilroy', fontSize: 14, color: on ? _blue : Colors.white, fontWeight: FontWeight.w600),
                    ),
                  ),
                );
              },
            ),
          ),
        Expanded(
          child: SavingsScreen(
            key: ValueKey('savings-tab-$id'),
            studentId: id,
            studentName: '${child['student_name'] ?? ''}',
            embedded: true,
          ),
        ),
      ],
    );
  }
}
