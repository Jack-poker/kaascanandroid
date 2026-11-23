import 'dart:async';

import 'package:flutter/material.dart';
import 'package:kaascan/Api/config.dart' show floatingSomaRobot;
import 'package:kaascan/services/soma_audio.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kaascan/components/soma_chat_background.dart';
import 'package:kaascan/provider/values_provider.dart';

/// Gestures baked into assets/animations/soma_robot.json as markers.
enum SomaMood { idle, thinking, yes, no, alert, jump }

/// The original Soma AI orange (the first chat background).
const Color somaBrandOrange = Color(0xFFFF3C00);

/// Colour themes for the robot. The body gradient runs light to dark.
enum SomaRobotColor {
  orange('Orange', [Color(0xFFFF6A33), somaBrandOrange, Color(0xFFCC3000)],
      somaBrandOrange, Colors.white),
  green('Green', [Color(0xFF22C55E), Color(0xFF16A34A), Color(0xFF0F7A37)],
      Color(0xFF1DB954), Colors.white),
  purple('Purple', [Color(0xFF8B5CF6), Color(0xFF7C3AED), Color(0xFF5B21B6)],
      Color(0xFF7C3AED), Colors.white),
  // White eyes vanish on yellow, so its face is dark.
  yellow('Yellow', [Color(0xFFFDE047), Color(0xFFFACC15), Color(0xFFEAB308)],
      Color(0xFFFACC15), Color(0xFF11142D)),
  black('Black', [Color(0xFF3A3A40), Color(0xFF1F1F24), Color(0xFF0A0A0C)],
      Color(0xFF18181B), Colors.white);

  const SomaRobotColor(this.label, this.body, this.inner, this.face);

  final String label;
  final List<Color> body;
  final Color inner;
  final Color face;
}

/// Colours for Soma's chat bubble; all carry white text, so no yellow.
enum SomaBubbleColor {
  orange('Orange', somaBrandOrange),
  blue('Blue', Color(0xFF0019CD)),
  green('Green', Color(0xFF15803D)),
  purple('Purple', Color(0xFF6D28D9)),
  black('Black', Color(0xFF1F1F24));

  const SomaBubbleColor(this.label, this.color);

  final String label;
  final Color color;
}

/// Chat screen backgrounds; all dark enough for the white title and doodles.
enum SomaBackgroundColor {
  blue('Blue', Color(0xFF0022FF)),
  orange('Orange', somaBrandOrange),
  green('Green', Color(0xFF0B6B3A)),
  purple('Purple', Color(0xFF4C1D95)),
  black('Black', Color(0xFF111114));

  const SomaBackgroundColor(this.label, this.color);

  final String label;
  final Color color;
}

/// WhatsApp-style doodle sets drawn faintly behind the chat.
enum SomaDoodle {
  none('None', []),
  school('School', [
    Icons.menu_book_rounded,
    Icons.edit_rounded,
    Icons.school_rounded,
    Icons.backpack_rounded,
    Icons.calculate_rounded,
    Icons.science_rounded,
    Icons.sports_soccer_rounded,
    Icons.lightbulb_outline_rounded,
  ]),
  money('Money', [
    Icons.savings_rounded,
    Icons.payments_rounded,
    Icons.account_balance_wallet_rounded,
    Icons.monetization_on_outlined,
    Icons.credit_card_rounded,
    Icons.trending_up_rounded,
    Icons.receipt_long_rounded,
    Icons.phone_android_rounded,
  ]),
  fun('Fun', [
    Icons.star_rounded,
    Icons.favorite_rounded,
    Icons.emoji_emotions_outlined,
    Icons.rocket_launch_rounded,
    Icons.music_note_rounded,
    Icons.cake_rounded,
    Icons.wb_sunny_outlined,
    Icons.pets_rounded,
  ]),
  mixed('Mixed', [
    Icons.menu_book_rounded,
    Icons.savings_rounded,
    Icons.star_rounded,
    Icons.edit_rounded,
    Icons.favorite_rounded,
    Icons.school_rounded,
    Icons.payments_rounded,
    Icons.emoji_emotions_outlined,
    Icons.backpack_rounded,
    Icons.rocket_launch_rounded,
  ]);

  const SomaDoodle(this.label, this.icons);

  final String label;
  final List<IconData> icons;
}

/// The parent's chat look (robot, bubble, background, doodles), shared
/// app-wide and remembered between sessions.
class SomaRobotTheme {
  SomaRobotTheme._();

  static final ValueNotifier<SomaRobotColor> color =
      ValueNotifier(SomaRobotColor.orange);
  static final ValueNotifier<SomaBubbleColor> bubble =
      ValueNotifier(SomaBubbleColor.orange);
  static final ValueNotifier<SomaBackgroundColor> background =
      ValueNotifier(SomaBackgroundColor.blue);
  static final ValueNotifier<SomaDoodle> doodle =
      ValueNotifier(SomaDoodle.school);

  /// On other tabs, the robot floats above the bottom bar and opens Soma in a
  /// pop-up; off, it stays in its tab. Defaults to config.dart.
  static final ValueNotifier<bool> floating = ValueNotifier(floatingSomaRobot);

  static Listenable get all =>
      Listenable.merge([color, bubble, background, doodle]);

  static bool _loaded = false;

  static T _pick<T extends Enum>(List<T> values, String? saved, T fallback) =>
      values.firstWhere((v) => v.name == saved, orElse: () => fallback);

  static Future<void> ensureLoaded() async {
    if (_loaded) return;
    _loaded = true;
    final p = await SharedPreferences.getInstance();
    color.value = _pick(SomaRobotColor.values,
        p.getString('soma_robot_color'), SomaRobotColor.orange);
    bubble.value = _pick(SomaBubbleColor.values,
        p.getString('soma_bubble_color'), SomaBubbleColor.orange);
    background.value = _pick(SomaBackgroundColor.values,
        p.getString('soma_background_color'), SomaBackgroundColor.blue);
    doodle.value = _pick(
        SomaDoodle.values, p.getString('soma_doodle'), SomaDoodle.school);
    floating.value = p.getBool('soma_floating') ?? floatingSomaRobot;
  }

  static Future<void> setFloating(bool on) async {
    floating.value = on;
    final p = await SharedPreferences.getInstance();
    await p.setBool('soma_floating', on);
  }

  static Future<void> _save(String key, Enum value) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(key, value.name);
  }

  static Future<void> set(SomaRobotColor c) {
    color.value = c;
    return _save('soma_robot_color', c);
  }

  static Future<void> setBubble(SomaBubbleColor c) {
    bubble.value = c;
    return _save('soma_bubble_color', c);
  }

  static Future<void> setBackground(SomaBackgroundColor c) {
    background.value = c;
    return _save('soma_background_color', c);
  }

  static Future<void> setDoodle(SomaDoodle d) {
    doodle.value = d;
    return _save('soma_doodle', d);
  }
}

const _sheetInk = Color(0xFF11142D);
const _sheetBlue = Color(0xFF0019CD);

/// Sheet where the parent picks the robot's and the chat bubble's colours.
Future<void> showSomaColorPicker(BuildContext context) {
  SomaRobotTheme.ensureLoaded();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheet) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: ListenableBuilder(
          listenable: Listenable.merge(
              [SomaRobotTheme.all, SomaRobotTheme.floating]),
          builder: (_, __) {
            final robot = SomaRobotTheme.color.value;
            final bubble = SomaRobotTheme.bubble.value;
            final background = SomaRobotTheme.background.value;
            final doodle = SomaRobotTheme.doodle.value;
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Center(
                  child: Text(
                    'Personalise Soma',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: _sheetInk,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                // Live preview: a mini chat with every choice applied.
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: SizedBox(
                    height: 140,
                    child: SomaChatBackground(
                      background: background,
                      doodle: doodle,
                      cell: 48,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(6, 0, 16, 0),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 88,
                              height: 88,
                              child: OverflowBox(
                                maxWidth: 160,
                                maxHeight: 160,
                                child: SomaRobot(
                                    size: 160, color: robot, floating: false),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: bubble.color,
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(4),
                                    topRight: Radius.circular(20),
                                    bottomLeft: Radius.circular(20),
                                    bottomRight: Radius.circular(20),
                                  ),
                                ),
                                child: const Text(
                                  'Keza has 5,000 RWF left on her card.',
                                  style: TextStyle(
                                      color: Colors.white, fontSize: 14),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                _SwatchSection(
                  title: 'Background',
                  items: [
                    for (final c in SomaBackgroundColor.values)
                      _Swatch(
                        label: c.label,
                        gradient: [c.color, c.color],
                        checkColor: Colors.white,
                        selected: c == background,
                        onTap: () => SomaRobotTheme.setBackground(c),
                      ),
                  ],
                ),
                const SizedBox(height: 18),
                _SwatchSection(
                  title: 'Doodles',
                  items: [
                    for (final d in SomaDoodle.values)
                      _Swatch(
                        label: d.label,
                        gradient: [background.color, background.color],
                        checkColor: Colors.white,
                        icon: d.icons.isEmpty
                            ? Icons.block_rounded
                            : d.icons.first,
                        selected: d == doodle,
                        onTap: () => SomaRobotTheme.setDoodle(d),
                      ),
                  ],
                ),
                const SizedBox(height: 18),
                _SwatchSection(
                  title: 'Robot',
                  items: [
                    for (final c in SomaRobotColor.values)
                      _Swatch(
                        label: c.label,
                        gradient: c.body,
                        checkColor: c.face,
                        selected: c == robot,
                        onTap: () => SomaRobotTheme.set(c),
                      ),
                  ],
                ),
                const SizedBox(height: 18),
                _SwatchSection(
                  title: 'Chat bubble',
                  items: [
                    for (final c in SomaBubbleColor.values)
                      _Swatch(
                        label: c.label,
                        gradient: [c.color, c.color],
                        checkColor: Colors.white,
                        selected: c == bubble,
                        onTap: () => SomaRobotTheme.setBubble(c),
                      ),
                  ],
                ),
                const SizedBox(height: 18),
                Container(
                  decoration: BoxDecoration(
                    color: _sheetBlue.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: SwitchListTile.adaptive(
                    value: SomaRobotTheme.floating.value,
                    onChanged: SomaRobotTheme.setFloating,
                    activeTrackColor: _sheetBlue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    title: const Text(
                      'Floating Soma',
                      style: TextStyle(
                          fontWeight: FontWeight.w700, color: _sheetInk),
                    ),
                    subtitle: Text(
                      'On other screens, Soma floats above the menu and opens '
                      'a quick chat when tapped.',
                      style: TextStyle(
                          fontSize: 12,
                          color: _sheetInk.withValues(alpha: 0.6)),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    ),
  );
}

class _SwatchSection extends StatelessWidget {
  const _SwatchSection({required this.title, required this.items});

  final String title;
  final List<Widget> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.6,
            color: _sheetInk.withValues(alpha: 0.55),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [for (final i in items) Expanded(child: i)],
        ),
      ],
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.label,
    required this.gradient,
    required this.checkColor,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final IconData? icon;
  final String label;
  final List<Color> gradient;
  final Color checkColor;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: gradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(
                  color: selected ? _sheetBlue : Colors.transparent,
                  width: 3,
                ),
              ),
              child: selected
                  ? Icon(Icons.check_rounded, color: checkColor, size: 22)
                  : icon == null
                      ? null
                      : Icon(icon,
                          color: Colors.white.withValues(alpha: 0.75),
                          size: 20),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              style: const TextStyle(fontSize: 11.5, color: _sheetInk),
            ),
          ],
        ),
      ),
    );
  }
}

/// The Soma AI robot. [mood] is the resting state (idle or thinking);
/// changing [reactionId] plays [reaction] once, then it returns to [mood].
class SomaRobot extends StatefulWidget {
  const SomaRobot({
    super.key,
    this.size = 120,
    this.mood = SomaMood.idle,
    this.reaction,
    this.reactionId = 0,
    this.greet = false,
    this.floating = true,
    this.color,
  });

  final double size;
  final SomaMood mood;
  final SomaMood? reaction;
  final int reactionId;
  final bool greet;
  final bool floating;
  /// Fixed colour (used by the picker preview); otherwise the parent's choice.
  final SomaRobotColor? color;

  @override
  State<SomaRobot> createState() => _SomaRobotState();
}

/// The robot sized as a chat avatar. The robot fills under half of its
/// animation canvas, so the canvas is drawn larger than the avatar slot.
class SomaAvatar extends StatelessWidget {
  const SomaAvatar({super.key, this.size = 40, this.mood = SomaMood.idle});

  final double size;
  final SomaMood mood;

  @override
  Widget build(BuildContext context) {
    final canvas = size * 2.3;
    return SizedBox(
      width: size,
      height: size,
      child: OverflowBox(
        maxWidth: canvas,
        maxHeight: canvas,
        child: SomaRobot(size: canvas, mood: mood, floating: false),
      ),
    );
  }
}

class _SomaRobotState extends State<SomaRobot> with TickerProviderStateMixin {
  static const _asset = 'assets/animations/soma_robot.json';
  // The idle marker fades in from white, so idle holds the first fully
  // brand-coloured frame instead of looping it.
  static const _restFrame = 30.0;

  late final AnimationController _lottie = AnimationController(vsync: this);
  late final AnimationController _float = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  )..repeat(reverse: true);

  // 0 = resting, 1 = fully squeezed; dips below 0 as it jiggles back.
  late final AnimationController _squeeze = AnimationController(
    vsync: this,
    lowerBound: -1,
    upperBound: 1,
    value: 0,
  );
  bool _pressed = false;

  LottieComposition? _comp;
  bool _reacting = false;
  int _playToken = 0;

  @override
  void didUpdateWidget(SomaRobot old) {
    super.didUpdateWidget(old);
    if (widget.reactionId != old.reactionId && widget.reaction != null) {
      _react(widget.reaction!);
    } else if (widget.mood != old.mood && !_reacting) {
      _rest();
    }
  }

  @override
  void dispose() {
    _lottie.dispose();
    _float.dispose();
    _squeeze.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    if (!widget.floating) _float.stop();
    SomaRobotTheme.ensureLoaded();
  }

  LottieDelegates _delegates(SomaRobotColor c) => LottieDelegates(
        values: [
          ValueDelegate.gradientColor(const ['outer', '**'], value: c.body),
          ValueDelegate.color(const ['inner', '**'], value: c.inner),
          ValueDelegate.strokeColor(const ['**'], value: c.face),
        ],
      );

  void _onLoaded(LottieComposition c) {
    _comp = c;
    if (widget.greet) {
      _react(SomaMood.jump);
    } else {
      _rest();
    }
  }

  Duration _period(LottieComposition c, Marker m) => Duration(
      milliseconds: (m.durationFrames / c.frameRate * 1000).round());

  void _rest() {
    final c = _comp;
    if (c == null) return;
    _playToken++;
    _reacting = false;
    final thinking = c.getMarker('thinking');
    if (widget.mood == SomaMood.thinking && thinking != null) {
      _lottie.value = thinking.start;
      _lottie.repeat(
        min: thinking.start,
        max: thinking.end,
        period: _period(c, thinking),
      );
    } else {
      _lottie.stop();
      _lottie.value = (_restFrame - c.startFrame) / c.durationFrames;
    }
    if (mounted) setState(() {});
  }

  Future<void> _react(SomaMood mood) async {
    final c = _comp;
    final m = c?.getMarker(mood.name);
    if (c == null || m == null) return;
    final token = ++_playToken;
    setState(() => _reacting = true);
    _lottie.value = m.start;
    try {
      await _lottie.animateTo(m.end, duration: _period(c, m)).orCancel;
    } on TickerCanceled {
      return;
    }
    if (!mounted || token != _playToken) return;
    _rest();
  }

  void _squish() {
    if (_pressed) return;
    _pressed = true;
    SomaAudio.instance.onSquish();
    _squeeze.animateTo(1, duration: const Duration(milliseconds: 110), curve: Curves.easeOut);
  }

  void _release() {
    if (!_pressed) return;
    _pressed = false;
    SomaAudio.instance.onBoing();
    _squeeze.animateTo(0, duration: const Duration(milliseconds: 650), curve: Curves.elasticOut);
  }

  @override
  Widget build(BuildContext context) {
    final robot = ValueListenableBuilder<SomaRobotColor>(
      valueListenable: SomaRobotTheme.color,
      builder: (_, chosen, __) => Lottie.asset(
        _asset,
        controller: _lottie,
        width: widget.size,
        height: widget.size,
        fit: BoxFit.contain,
        onLoaded: _onLoaded,
        delegates: _delegates(widget.color ?? chosen),
        errorBuilder: (_, __, ___) => Icon(
          Icons.smart_toy_rounded,
          color: Colors.white,
          size: widget.size * 0.4,
        ),
      ),
    );

    return Semantics(
      label: 'Soma AI',
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _squish(),
        onTapUp: (_) => _release(),
        onTapCancel: _release,
        onTap: () => _react(SomaMood.jump),
        onLongPress: widget.color == null
            ? () {
                _release();
                showSomaColorPicker(context);
              }
            : null,
        child: AnimatedBuilder(
          animation: Listenable.merge([_float, _squeeze]),
          builder: (_, child) {
            final bob = _reacting || !widget.floating
                ? 0.0
                : Curves.easeInOut.transform(_float.value) * widget.size * 0.025;
            // Squash wide and short, keeping its volume; the overshoot past
            // 0 stretches it tall for the jelly wobble.
            final s = _squeeze.value;
            return Transform.translate(
              offset: Offset(0, -bob),
              child: Transform(
                alignment: const Alignment(0, 0.35),
                transform: Matrix4.diagonal3Values(1 + 0.14 * s, 1 - 0.16 * s, 1),
                child: child,
              ),
            );
          },
          child: robot,
        ),
      ),
    );
  }
}

/// [SomaRobot] wired to the chat: thinks while Soma answers, nods on an
/// answer, shakes its head on an error and perks up when the user types.
class SomaRobotLive extends StatefulWidget {
  const SomaRobotLive({
    super.key,
    this.size = 120,
    this.input,
    this.greet = false,
  });

  final double size;
  final TextEditingController? input;
  final bool greet;

  @override
  State<SomaRobotLive> createState() => _SomaRobotLiveState();
}

class _SomaRobotLiveState extends State<SomaRobotLive> {
  int? _seenCount;
  bool _hadText = false;
  SomaMood? _reaction;
  int _reactionId = 0;

  @override
  void initState() {
    super.initState();
    _hadText = widget.input?.text.trim().isNotEmpty ?? false;
    widget.input?.addListener(_onInput);
  }

  @override
  void didUpdateWidget(SomaRobotLive old) {
    super.didUpdateWidget(old);
    if (old.input != widget.input) {
      old.input?.removeListener(_onInput);
      widget.input?.addListener(_onInput);
    }
  }

  @override
  void dispose() {
    widget.input?.removeListener(_onInput);
    super.dispose();
  }

  void _onInput() {
    final hasText = widget.input!.text.trim().isNotEmpty;
    final waiting = context.read<ValuesProvider>().waiting_ask;
    if (hasText && !_hadText && !waiting) {
      setState(() {
        _reaction = SomaMood.alert;
        _reactionId++;
      });
    }
    _hadText = hasText;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ValuesProvider>();
    final messages = provider.messages;
    final seen = _seenCount;
    if (seen == null || messages.length < seen) {
      _seenCount = messages.length;
    } else if (messages.length > seen) {
      _seenCount = messages.length;
      final last = messages.last;
      if (last.isAi) {
        _reaction = last.askResponse != null ? SomaMood.yes : SomaMood.no;
        _reactionId++;
      }
    }

    return SomaRobot(
      size: widget.size,
      greet: widget.greet,
      mood: provider.waiting_ask ? SomaMood.thinking : SomaMood.idle,
      reaction: _reaction,
      reactionId: _reactionId,
    );
  }
}

/// The robot as a bottom-nav icon. While its tab is not selected it waves for
/// attention every few seconds (exclamation, then a jump); selected, it rests.
class SomaNavRobot extends StatefulWidget {
  const SomaNavRobot({super.key, required this.selected, this.size = 40});

  final bool selected;
  final double size;

  @override
  State<SomaNavRobot> createState() => _SomaNavRobotState();
}

class _SomaNavRobotState extends State<SomaNavRobot> {
  static const _every = Duration(seconds: 7);
  Timer? _timer;
  int _reactionId = 0;
  SomaMood _reaction = SomaMood.alert;

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(SomaNavRobot old) {
    super.didUpdateWidget(old);
    if (old.selected != widget.selected) _sync();
  }

  void _sync() {
    _timer?.cancel();
    _timer = null;
    if (widget.selected) return;
    _timer = Timer.periodic(_every, (_) {
      if (!mounted) return;
      setState(() {
        _reaction =
            _reaction == SomaMood.alert ? SomaMood.jump : SomaMood.alert;
        _reactionId++;
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canvas = widget.size * 2.3;
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: OverflowBox(
        maxWidth: canvas,
        maxHeight: canvas,
        child: IgnorePointer(
          child: SomaRobot(
            size: canvas,
            floating: false,
            reaction: _reaction,
            reactionId: _reactionId,
          ),
        ),
      ),
    );
  }
}
