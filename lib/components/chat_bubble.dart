import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:kaascan/widgets/cached_network_image_wrapper.dart';
import 'package:kaascan/main.dart';
import 'package:url_launcher/url_launcher.dart';

/// An animated AI response bubble with typewriter effect, product cards,
/// structured data rendering (student lists, etc.), and copy button.
class ChatBubble extends StatefulWidget {
  final String message;
  final String? avatarUrl;
  final String? senderName;
  final DateTime timestamp;
  final Map<dynamic, dynamic>? productData;
  final VoidCallback? onProductTap;

  /// Structured response data from the AI (e.g., student lists)
  final Map<dynamic, dynamic>? responseData;

  /// Called when an actionable tag/item is tapped (e.g., a student card).
  /// The String argument is the message to send back to the AI.
  final ValueChanged<String>? onActionTapped;

  /// Called for visual-only simulation + showing students in a NEW bubble.
  final void Function(
    String actionMessage,
    Map<dynamic, dynamic> studentResponse,
  )? onSimulateAndShow;

  /// Called when the active student changes in the list scroll.
  final void Function(String photoUrl, String studentName)?
      onActiveStudentChanged;

  const ChatBubble({
    super.key,
    required this.message,
    this.avatarUrl,
    this.senderName,
    required this.timestamp,
    this.productData,
    this.onProductTap,
    this.responseData,
    this.onActionTapped,
    this.onSimulateAndShow,
    this.onActiveStudentChanged,
  });

  @override
  State<ChatBubble> createState() => _ChatBubbleState();
}

/// Type of detected link in the AI response text.
enum _LinkType { url, email, phone }

/// A detected link segment with text position.
class _LinkMatch {
  final int start;
  final int end;
  final String raw;
  final _LinkType type;

  const _LinkMatch({
    required this.start,
    required this.end,
    required this.raw,
    required this.type,
  });

  bool get isEmail => type == _LinkType.email;
  bool get isPhone => type == _LinkType.phone;
  bool get isUrl => type == _LinkType.url;
}

/// Parsed student data from the AI response.
class _ParsedStudent {
  final String id;
  final String name;
  final String school;
  final String grade;
  final String? photoUrl;

  const _ParsedStudent({
    required this.id,
    required this.name,
    required this.school,
    required this.grade,
    this.photoUrl,
  });

  static String _resolveName(dynamic rawName) {
    if (rawName == null) return '';
    if (rawName is String) return rawName;
    if (rawName is Map) {
      final inner = rawName['name'] ?? rawName['student_name'];
      if (inner != null) return inner.toString();
    }
    return rawName.toString();
  }
}

/// Parsed structured response from message text or responseData map.
class _ParsedResponse {
  final String? status;
  final String? type;
  final String? responseText;
  final String? message;
  final List<_ParsedStudent> students;
  final int count;
  final String? actionWord;
  final String? actionMessage;

  const _ParsedResponse({
    this.status,
    this.type,
    this.responseText,
    this.message,
    this.students = const [],
    this.count = 0,
    this.actionWord,
    this.actionMessage,
  });

  bool get isStudentList =>
      status == 'multiple' && type == 'list' && students.isNotEmpty;

  bool get hasSingleStudent =>
      status == 'found' && type == 'detail' && students.length == 1;

  bool get hasActionWord => actionWord != null && actionWord!.isNotEmpty;
}

class _ChatBubbleState extends State<ChatBubble> with TickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  late AnimationController _cardAnimController;
  late List<Animation<double>> _cardSlideAnimations;
  late List<Animation<double>> _cardFadeAnimations;
  late List<Animation<double>> _cardScaleAnimations;

  String _displayedText = '';
  int _charIndex = 0;
  bool _typewriterComplete = false;

  _ParsedResponse? _parsedResponse;

  final ScrollController _studentScrollController = ScrollController();
  int _activeStudentIndex = 0;
  final List<GlobalKey> _cardKeys = [];

  // 🔑 Special token emitted by Primary's DEEP_ANALYSIS message.
  static const String _rebaToken = "[[REBA]]";

  bool get _hasRebaToken => widget.message.contains(_rebaToken);

  @override
  void initState() {
    super.initState();

    _parsedResponse = _parseResponseData();

    if (_parsedResponse != null &&
        (_parsedResponse!.isStudentList ||
            _parsedResponse!.hasSingleStudent)) {
      final count = _parsedResponse!.students.length;
      _cardKeys.addAll(List.generate(count, (_) => GlobalKey()));
      _studentScrollController.addListener(_onStudentScroll);
    }

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(-0.3, 0), end: Offset.zero).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));

    _animController.forward();

    final studentCount = _parsedResponse?.students.length ?? 0;
    _cardAnimController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 200 + studentCount * 100),
    );

    _cardSlideAnimations = [];
    _cardFadeAnimations = [];
    _cardScaleAnimations = [];
    final staggerStep = studentCount > 1 ? 0.7 / studentCount : 0.0;
    for (int i = 0; i < studentCount; i++) {
      final start = i * staggerStep;
      final end = (start + 0.35).clamp(0.0, 1.0);
      _cardSlideAnimations.add(
        Tween<double>(begin: 30.0, end: 0.0).animate(
          CurvedAnimation(
            parent: _cardAnimController,
            curve: Interval(start, end, curve: Curves.easeOutCubic),
          ),
        ),
      );
      _cardFadeAnimations.add(
        Tween<double>(begin: 0.0, end: 1.0).animate(
          CurvedAnimation(
            parent: _cardAnimController,
            curve: Interval(start, end, curve: Curves.easeOut),
          ),
        ),
      );
      _cardScaleAnimations.add(
        Tween<double>(begin: 0.92, end: 1.0).animate(
          CurvedAnimation(
            parent: _cardAnimController,
            curve: Interval(start, end, curve: Curves.easeOutBack),
          ),
        ),
      );
    }

    if (_displayMessageText.isNotEmpty) {
      _startTypewriter();
    } else {
      _typewriterComplete = true;
    }
  }

  String get _displayMessageText {
    // Strip the REBA token from typewriter output; it becomes a widget later.
    String base;
    if (_parsedResponse != null &&
        (_parsedResponse!.isStudentList ||
            _parsedResponse!.hasSingleStudent)) {
      base = _parsedResponse!.responseText ?? _parsedResponse!.message ?? '';
    } else {
      base = widget.message;
    }
    return base.replaceAll(_rebaToken, "").trimRight();
  }

  _ParsedResponse? _parseResponseData() {
    if (widget.responseData != null) {
      final data = widget.responseData!;
      final status = data['status']?.toString();
      final type = data['type']?.toString();
      final hasActionWord = data['action_word']?.toString() != null &&
          data['action_word'].toString().isNotEmpty;

      if (status != null || type != null || hasActionWord) {
        final students = <_ParsedStudent>[];
        if (data['students'] is List) {
          for (final s in data['students'] as List) {
            if (s is Map) {
              students.add(
                _ParsedStudent(
                  id: s['student_id']?.toString() ?? '',
                  name: _ParsedStudent._resolveName(s['student_name']),
                  school: s['school_name']?.toString() ?? '',
                  grade: s['grade']?.toString() ?? '',
                  photoUrl: s['photo_url']?.toString(),
                ),
              );
            }
          }
        }
        if (data['student'] is Map) {
          final s = data['student'] as Map;
          students.add(
            _ParsedStudent(
              id: s['student_id']?.toString() ?? '',
              name: _ParsedStudent._resolveName(s['student_name']),
              school: s['school_name']?.toString() ?? '',
              grade: s['grade']?.toString() ?? '',
              photoUrl: s['photo_url']?.toString(),
            ),
          );
        }

        String? responseText = data['response']?.toString();
        String? actionWord = data['action_word']?.toString();
        String? actionMessage = data['action_message']?.toString();

        if (status == 'found' && type == 'detail' && students.length == 1) {
          actionWord = actionWord ?? 'hano';
          final student = students[0];
          actionMessage = actionMessage ??
              'LINK_STUDENT:${student.id}:${student.name}:${student.photoUrl ?? ''}';
          if (responseText != null && !responseText.contains(actionWord)) {
            final displayName = student.name.length > 25
                ? '${student.name.substring(0, 22)}...'
                : student.name;
            responseText = responseText +
                '\n\nKanda "$actionWord" urebe amafoto ya $displayName hanyuma uhuzwe na konti yawe.';
          }
        }

        return _ParsedResponse(
          status: status,
          type: type,
          responseText: responseText,
          message: data['message']?.toString(),
          students: students,
          count: _parseInt(data['count']),
          actionWord: actionWord,
          actionMessage: actionMessage,
        );
      }
    }

    try {
      final decoded = jsonDecode(widget.message);
      if (decoded is Map) {
        final data = decoded;
        final status = data['status']?.toString();
        final type = data['type']?.toString();
        final hasActionWord = data['action_word']?.toString() != null &&
            data['action_word'].toString().isNotEmpty;

        if (status != null || type != null || hasActionWord) {
          final students = <_ParsedStudent>[];
          if (data['students'] is List) {
            for (final s in data['students'] as List) {
              if (s is Map) {
                students.add(
                  _ParsedStudent(
                    id: s['student_id']?.toString() ?? '',
                    name: _ParsedStudent._resolveName(s['student_name']),
                    school: s['school_name']?.toString() ?? '',
                    grade: s['grade']?.toString() ?? '',
                    photoUrl: s['photo_url']?.toString(),
                  ),
                );
              }
            }
          }
          if (data['student'] is Map) {
            final s = data['student'] as Map;
            students.add(
              _ParsedStudent(
                id: s['student_id']?.toString() ?? '',
                name: _ParsedStudent._resolveName(s['student_name']),
                school: s['school_name']?.toString() ?? '',
                grade: s['grade']?.toString() ?? '',
                photoUrl: s['photo_url']?.toString(),
              ),
            );
          }

          String? responseText = data['response']?.toString();
          String? actionWord = data['action_word']?.toString();
          String? actionMessage = data['action_message']?.toString();

          if (status == 'found' && type == 'detail' && students.length == 1) {
            actionWord = actionWord ?? 'hano';
            final student = students[0];
            actionMessage = actionMessage ??
                'LINK_STUDENT:${student.id}:${student.name}:${student.photoUrl ?? ''}';
            if (responseText != null && !responseText.contains(actionWord)) {
              final displayName = student.name.length > 25
                  ? '${student.name.substring(0, 22)}...'
                  : student.name;
              responseText = responseText +
                  '\n\nKanda "$actionWord" urebe amafoto ya $displayName hanyuma uhuzwe na konti yawe.';
            }
          }

          return _ParsedResponse(
            status: status,
            type: type,
            responseText: responseText,
            message: data['message']?.toString(),
            students: students,
            count: _parseInt(data['count']),
            actionWord: actionWord,
            actionMessage: actionMessage,
          );
        }
      }
    } catch (_) {}

    return null;
  }

  int _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  void _startTypewriter() {
    const typeSpeed = Duration(milliseconds: 15);
    _charIndex = 0;
    _displayedText = '';

    Future.doWhile(() async {
      await Future.delayed(typeSpeed);
      if (!mounted) return false;

      _charIndex++;
      setState(() {
        _displayedText = _displayMessageText.substring(0, _charIndex);
      });

      if (_charIndex >= _displayMessageText.length) {
        _typewriterComplete = true;
        setState(() {});
        if (_parsedResponse != null &&
            (_parsedResponse!.isStudentList ||
                _parsedResponse!.hasSingleStudent) &&
            _cardAnimController.status != AnimationStatus.forward &&
            _cardAnimController.status != AnimationStatus.completed) {
          _cardAnimController.forward();
          if (_parsedResponse!.students.isNotEmpty) {
            final firstStudent = _parsedResponse!.students[0];
            widget.onActiveStudentChanged?.call(
              firstStudent.photoUrl ?? '',
              firstStudent.name,
            );
          }
        }
        return false;
      }
      return true;
    });
  }

  void _onStudentScroll() {
    if (!_studentScrollController.hasClients || _cardKeys.isEmpty) return;

    final scrollPos = _studentScrollController.offset;
    final viewportHeight = _studentScrollController.position.viewportDimension;
    final focusPoint = scrollPos + viewportHeight * 0.3;

    int closestIndex = 0;
    double minDist = double.infinity;
    double accumulated = 0;

    for (int i = 0; i < _cardKeys.length; i++) {
      final ctx = _cardKeys[i].currentContext;
      final cardHeight = ctx != null
          ? (ctx.findRenderObject() as RenderBox?)?.size.height ?? 72.0
          : 72.0;
      final cardCenter = accumulated + cardHeight / 2;
      final dist = (cardCenter - focusPoint).abs();

      if (dist < minDist) {
        minDist = dist;
        closestIndex = i;
      }
      accumulated += cardHeight + 6.0;
    }

    if (closestIndex != _activeStudentIndex) {
      setState(() => _activeStudentIndex = closestIndex);
      if (_parsedResponse != null &&
          closestIndex < _parsedResponse!.students.length) {
        final student = _parsedResponse!.students[closestIndex];
        widget.onActiveStudentChanged?.call(
          student.photoUrl ?? '',
          student.name,
        );
      }
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    _cardAnimController.dispose();
    _studentScrollController.removeListener(_onStudentScroll);
    _studentScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: _buildAiBubble(),
      ),
    );
  }

  Widget _buildAiBubble() {
    return Padding(
      padding: const EdgeInsets.only(left: 4, right: 48, top: 4, bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFF7C4DFF), Color(0xFFB388FF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.3),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.deepPurpleAccent.withValues(alpha: 0.2),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: (1 > 0)
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.asset(
                        "assets/logo.jpg",
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.chat_bubble,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    )
                  : const Icon(Icons.smart_toy, color: Colors.white, size: 18),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color.fromARGB(255, 0, 72, 255),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(20),
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.senderName != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        widget.senderName!,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          fontFamily: "minigap",
                          color: const Color.fromARGB(255, 255, 255, 255)
                              .withValues(alpha: 0.7),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),

                  if (_displayMessageText.isNotEmpty)
                    _typewriterComplete
                        ? RichText(
                            text: TextSpan(
                              style: const TextStyle(color: Colors.white),
                              children: _parseTextWithLinks(_displayMessageText),
                            ),
                          )
                        : _buildTypewriterRichText(),

                  // 🎯 Special: "Reba Report" chip after typewriter completes
                  if (_hasRebaToken && _typewriterComplete)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: GestureDetector(
                        onTap: () {
                          HapticFeedback.mediumImpact();
                          widget.onActionTapped?.call("SHOW_REPORT_PDF");
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFFB300), Color(0xFFFF6F00)],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFFF6F00)
                                    .withValues(alpha: 0.4),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(Icons.picture_as_pdf,
                                  color: Colors.white, size: 20),
                              SizedBox(width: 8),
                              Text(
                                "Reba Report",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  fontFamily: "minigap",
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                  if (_parsedResponse != null &&
                      _typewriterComplete &&
                      ((_parsedResponse!.isStudentList &&
                              !_parsedResponse!.hasActionWord) ||
                          _parsedResponse!.hasSingleStudent))
                    ..._buildStudentList(),

                  if (widget.productData != null && _typewriterComplete)
                    ..._buildProductDetails(),

                  if (_typewriterComplete) ..._buildLinkPreviews(),

                  if (_typewriterComplete &&
                      widget.responseData != null &&
                      widget.responseData!['_show_guide'] == true)
                    _buildGuideCard(),

                  if (_typewriterComplete)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _formatTime(widget.timestamp),
                              style: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 10,
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () {
                                Clipboard.setData(
                                  ClipboardData(text: widget.message),
                                );
                                scaffoldMessengerKey.currentState?.showSnackBar(
                                  const SnackBar(
                                    content: Text('Copied !'),
                                    duration: Duration(seconds: 1),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              },
                              child: Icon(
                                Icons.copy_rounded,
                                size: 14,
                                color: Colors.grey[400],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypewriterRichText() {
    final hasActionWord = _parsedResponse?.hasActionWord == true;
    if (!hasActionWord) {
      return RichText(
        strutStyle: const StrutStyle(fontFamily: "minigap"),
        text: TextSpan(
          style: const TextStyle(color: Colors.white),
          children: [
            TextSpan(
              text: _displayedText,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontFamily: "minigap",
                height: 1.4,
              ),
            ),
            const TextSpan(
              text: '▌',
              style: TextStyle(
                color: Colors.deepPurpleAccent,
                fontSize: 15,
                fontWeight: FontWeight.w300,
              ),
            ),
          ],
        ),
      );
    }

    return RichText(
      strutStyle: const StrutStyle(fontFamily: "minigap"),
      text: TextSpan(
        style: const TextStyle(color: Colors.white),
        children: [
          TextSpan(
            text: _displayedText,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontFamily: "minigap",
              height: 1.4,
            ),
          ),
          const TextSpan(
            text: '▌',
            style: TextStyle(
              color: Colors.deepPurpleAccent,
              fontSize: 15,
              fontWeight: FontWeight.w300,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildStudentList() {
    final parsed = _parsedResponse!;
    final students = parsed.students;

    if (students.length == 1) {
      return _buildSingleStudentPreview(students.first);
    }

    return [
      const SizedBox(height: 10),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.deepPurple.shade800.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: Colors.deepPurpleAccent.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.deepPurpleAccent.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.people_rounded,
                  size: 16, color: Colors.white),
            ),
            const SizedBox(width: 8),
            Text(
              '${students.length} students found',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontFamily: 'minigap',
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            Text(
              'Tap to select →',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 10,
                fontFamily: 'minigap',
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 8),
      Stack(
        children: [
          SizedBox(
            height: math.min(students.length * 72.0, 320.0),
            child: ListView(
              controller: _studentScrollController,
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.zero,
              children: [
                ...students.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final student = entry.value;
                  return AnimatedBuilder(
                    animation: _cardAnimController,
                    builder: (context, child) {
                      final offset = _cardSlideAnimations.length > idx
                          ? _cardSlideAnimations[idx].value
                          : 0.0;
                      final opacity = _cardFadeAnimations.length > idx
                          ? _cardFadeAnimations[idx].value
                          : 1.0;
                      final scale = _cardScaleAnimations.length > idx
                          ? _cardScaleAnimations[idx].value
                          : 1.0;
                      return Opacity(
                        opacity: opacity,
                        child: Transform.translate(
                          offset: Offset(offset, 0),
                          child: Transform.scale(
                            scale: scale,
                            child: Padding(
                              padding: const EdgeInsets.only(right: 4),
                              child: child,
                            ),
                          ),
                        ),
                      );
                    },
                    child: Container(
                      key: _cardKeys.length > idx ? _cardKeys[idx] : null,
                      child: _buildStudentCard(student),
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    ];
  }

  List<Widget> _buildSingleStudentPreview(_ParsedStudent student) {
    final colors = [
      const Color.fromARGB(255, 255, 215, 171),
      const Color(0xFF00BFA5),
      const Color(0xFFFF6B6B),
      const Color(0xFFFFA726),
      const Color(0xFF42A5F5),
      const Color(0xFFAB47BC),
      const Color(0xFF26C6DA),
      const Color(0xFF8D6E63),
    ];
    final colorIndex = student.name.hashCode % colors.length;
    final accentColor = colors[colorIndex];

    final initials = student.name.isNotEmpty
        ? student.name
            .split(' ')
            .where((w) => w.isNotEmpty)
            .take(2)
            .map((w) => w[0].toUpperCase())
            .join()
        : '?';

    final hasPhoto = student.photoUrl != null && student.photoUrl!.isNotEmpty;

    return [
      const SizedBox(height: 10),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.green.shade900.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.greenAccent.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.person_search_rounded,
                  size: 16, color: Colors.white),
            ),
            const SizedBox(width: 8),
            Text(
              'Umunyeshuri umwe yabonetse',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontFamily: 'minigap',
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      AnimatedBuilder(
        animation: _cardAnimController,
        builder: (context, child) {
          final opacity =
              _cardFadeAnimations.isNotEmpty ? _cardFadeAnimations[0].value : 1.0;
          final scale =
              _cardScaleAnimations.isNotEmpty ? _cardScaleAnimations[0].value : 1.0;
          return Opacity(
            opacity: opacity,
            child: Transform.scale(scale: scale, child: child),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: accentColor.withValues(alpha: 0.4),
              width: 1.5,
            ),
          ),
          child: Column(
            children: [
              GestureDetector(
                onTap: () => _showPhotoViewer(student, accentColor, initials),
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: hasPhoto
                        ? null
                        : LinearGradient(
                            colors: [
                              accentColor,
                              accentColor.withValues(alpha: 0.7),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                    boxShadow: [
                      BoxShadow(
                        color: accentColor.withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: hasPhoto
                      ? CachedNetworkImageWrapper(
                          imageUrl: student.photoUrl!,
                          width: 100,
                          height: 100,
                          fit: BoxFit.cover,
                          shape: BoxShape.circle,
                          errorWidget:
                              _buildInitialsAvatar(initials, accentColor),
                          placeholder:
                              _buildInitialsAvatar(initials, accentColor),
                        )
                      : Center(
                          child: Text(
                            initials,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'minigap',
                            ),
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                student.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'minigap',
                ),
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                student.school.isNotEmpty
                    ? student.school
                    : 'School not specified',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 13,
                  fontFamily: 'minigap',
                ),
                maxLines: 1,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
              if (student.grade.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  'Grade ${student.grade}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 12,
                    fontFamily: 'minigap',
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 16),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    final welcomeResponse = <dynamic, dynamic>{
                      "response":
                          "Mubyukuri nishimiye ko tubashije kubona amakuru y`umwana wawe ushobora guhuza umwana wawe na konti ukanze hano",
                      "ask_response":
                          "Mubyukuri nishimiye kuguhuza numwana wawe ushobora guhuza umwana wawe na konti ukanze hano",
                      "action_word": "hano",
                      "action_message": "CONFIRM_LINK",
                      "_pending_student_id": student.id,
                      "_pending_student_name": student.name,
                      "_pending_photo_url": student.photoUrl ?? '',
                    };
                    widget.onSimulateAndShow?.call(
                      'ni umwana wange',
                      welcomeResponse,
                    );
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          accentColor,
                          accentColor.withValues(alpha: 0.8),
                        ],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: accentColor.withValues(alpha: 0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.favorite_rounded,
                            color: Colors.white, size: 18),
                        SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'Uyu ni umwana wange',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'minigap',
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () => _showPhotoViewer(student, accentColor, initials),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.visibility_rounded,
                        size: 12,
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Kanda urebe amafoto',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 11,
                          fontFamily: 'minigap',
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ];
  }

  Widget _buildStudentCard(_ParsedStudent student) {
    final colors = [
      const Color(0xFF6C63FF),
      const Color(0xFF00BFA5),
      const Color(0xFFFF6B6B),
      const Color(0xFFFFA726),
      const Color(0xFF42A5F5),
      const Color(0xFFAB47BC),
      const Color(0xFF26C6DA),
      const Color(0xFF8D6E63),
    ];
    final colorIndex = student.name.hashCode % colors.length;
    final accentColor = colors[colorIndex];

    final initials = student.name.isNotEmpty
        ? student.name
            .split(' ')
            .where((w) => w.isNotEmpty)
            .take(2)
            .map((w) => w[0].toUpperCase())
            .join()
        : '?';

    final hasPhoto = student.photoUrl != null && student.photoUrl!.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _handleStudentTap(student),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: accentColor.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: hasPhoto
                      ? () => _showPhotoViewer(student, accentColor, initials)
                      : null,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: hasPhoto
                          ? null
                          : LinearGradient(
                              colors: [
                                accentColor,
                                accentColor.withValues(alpha: 0.7),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                      boxShadow: [
                        BoxShadow(
                          color: accentColor.withValues(alpha: 0.3),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: hasPhoto
                        ? CachedNetworkImageWrapper(
                            imageUrl: student.photoUrl!,
                            width: 40,
                            height: 40,
                            fit: BoxFit.cover,
                            borderRadius: BorderRadius.circular(20),
                            errorWidget:
                                _buildInitialsAvatar(initials, accentColor),
                            placeholder:
                                _buildInitialsAvatar(initials, accentColor),
                          )
                        : Center(
                            child: Text(
                              initials,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'minigap',
                              ),
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        student.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'minigap',
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(
                            Icons.school_rounded,
                            size: 10,
                            color: Colors.white.withValues(alpha: 0.5),
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              student.school.isNotEmpty
                                  ? student.school
                                  : 'School not specified',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.6),
                                fontSize: 11,
                                fontFamily: 'minigap',
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      if (student.grade.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(
                              Icons.menu_book_rounded,
                              size: 10,
                              color: Colors.white.withValues(alpha: 0.5),
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                student.grade,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.6),
                                  fontSize: 11,
                                  fontFamily: 'minigap',
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 12,
                    color: accentColor.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showPhotoViewer(
    _ParsedStudent student,
    Color accentColor,
    String initials,
  ) {
    HapticFeedback.lightImpact();

    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) {
        return Dialog(
          insetPadding: EdgeInsets.zero,
          backgroundColor: Colors.transparent,
          child: Stack(
            children: [
              Positioned.fill(
                child: InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: Center(
                    child: student.photoUrl != null &&
                            student.photoUrl!.isNotEmpty
                        ? CachedNetworkImageWrapper(
                            imageUrl: student.photoUrl!,
                            fit: BoxFit.contain,
                            width: double.infinity,
                            height: double.infinity,
                            errorWidget:
                                _buildInitialsAvatar(initials, accentColor),
                            placeholder: const Center(
                              child: CircularProgressIndicator(
                                color: Color.fromARGB(255, 255, 255, 255),
                              ),
                            ),
                          )
                        : _buildInitialsAvatar(initials, accentColor),
                  ),
                ),
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: EdgeInsets.only(
                    top: MediaQuery.of(ctx).padding.top + 8,
                    left: 16,
                    right: 16,
                    bottom: 16,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.7),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              student.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'minigap',
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (student.school.isNotEmpty)
                              Text(
                                student.school,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.7),
                                  fontSize: 12,
                                  fontFamily: 'minigap',
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: EdgeInsets.only(
                    left: 24,
                    right: 24,
                    top: 24,
                    bottom: MediaQuery.of(ctx).padding.bottom + 24,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.7),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accentColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 4,
                        shadowColor: accentColor.withValues(alpha: 0.4),
                      ),
                      icon: const Icon(Icons.favorite_rounded, size: 20),
                      label: const Text(
                        'Uyu ni umwana wanjye',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'minigap',
                        ),
                      ),
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        HapticFeedback.mediumImpact();
                        final welcomeResponse = <dynamic, dynamic>{
                          "response":
                              "Mubyukuri nishimiye kuguhuza numwana wawe ushobora guhuza umwana wawe na konti ukanze hano",
                          "ask_response":
                              "Mubyukuri nishimiye kuguhuza numwana wawe ushobora guhuza umwana wawe na konti ukanze hano",
                          "action_word": "hano",
                          "action_message": "CONFIRM_LINK",
                          "_pending_student_id": student.id,
                          "_pending_student_name": student.name,
                          "_pending_photo_url": student.photoUrl ?? '',
                        };
                        widget.onSimulateAndShow?.call(
                          'ni umwana wange',
                          welcomeResponse,
                        );
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInitialsAvatar(String initials, Color accentColor) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [accentColor, accentColor.withValues(alpha: 0.7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(
          initials,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
            fontFamily: 'minigap',
          ),
        ),
      ),
    );
  }

  void _handleActionWordTap(String actionMessage) {
    if (_parsedResponse != null && _parsedResponse!.hasSingleStudent) {
      HapticFeedback.mediumImpact();
      final student = _parsedResponse!.students[0];
      final initials = student.name.isNotEmpty
          ? student.name
              .split(' ')
              .where((w) => w.isNotEmpty)
              .take(2)
              .map((w) => w[0].toUpperCase())
              .join()
          : '?';
      final colors = [
        const Color(0xFF6C63FF),
        const Color(0xFF00BFA5),
        const Color(0xFFFF6B6B),
        const Color(0xFFFFA726),
        const Color(0xFF42A5F5),
        const Color(0xFFAB47BC),
        const Color(0xFF26C6DA),
        const Color(0xFF8D6E63),
      ];
      final colorIndex = student.name.hashCode % colors.length;
      final accentColor = colors[colorIndex];
      _showPhotoViewer(student, accentColor, initials);
      return;
    }

    if (_parsedResponse != null && _parsedResponse!.isStudentList) {
      HapticFeedback.mediumImpact();
      widget.onSimulateAndShow?.call(actionMessage, widget.responseData!);
      return;
    }

    if (widget.onActionTapped == null) return;
    if (actionMessage.isEmpty) return;

    HapticFeedback.mediumImpact();
    widget.onActionTapped!(actionMessage);
  }

  void _handleStudentTap(_ParsedStudent student) {
    HapticFeedback.lightImpact();
    final initials = student.name.isNotEmpty
        ? student.name
            .split(' ')
            .where((w) => w.isNotEmpty)
            .take(2)
            .map((w) => w[0].toUpperCase())
            .join()
        : '?';
    final colors = [
      const Color(0xFF6C63FF),
      const Color(0xFF00BFA5),
      const Color(0xFFFF6B6B),
      const Color(0xFFFFA726),
      const Color(0xFF42A5F5),
      const Color(0xFFAB47BC),
      const Color(0xFF26C6DA),
      const Color(0xFF8D6E63),
    ];
    final colorIndex = student.name.hashCode % colors.length;
    final accentColor = colors[colorIndex];
    _showPhotoViewer(student, accentColor, initials);
  }

  List<Widget> _buildProductDetails() {
    final data = widget.productData!;

    final List<dynamic> products = data["products"] is List
        ? (data["products"] as List).cast<Map<dynamic, dynamic>>()
        : data["price"] != null ||
                data["seller_contact"] != null ||
                data["image_url"] != null ||
                data["matched_keyword"] != null
            ? [data]
            : [];

    if (products.isEmpty) return [];

    return [
      const SizedBox(height: 8),
      Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 6),
        child: Row(
          children: [
            const Icon(
              Icons.inventory_2,
              size: 14,
              color: Color.fromARGB(255, 255, 255, 255),
            ),
            const SizedBox(width: 4),
            Text(
              products.length == 1
                  ? "1 product found"
                  : "${products.length} products found",
              style: const TextStyle(
                fontSize: 11,
                color: Colors.white24,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
      SizedBox(
        height: products.length > 1 ? 200 : null,
        child: ListView.separated(
          shrinkWrap: products.length == 1,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: products.length,
          separatorBuilder: (_, __) => const SizedBox(height: 6),
          itemBuilder: (context, index) {
            final product = products[index] as Map<dynamic, dynamic>;
            final relevance = _parseDouble(product["relevance"]);
            return _buildProductCard(product, relevance);
          },
        ),
      ),
    ];
  }

  Widget _buildProductCard(Map<dynamic, dynamic> data, double? relevance) {
    final imageUrl = data["image_url"]?.toString() ?? "";
    final name = data["matched_keyword"]?.toString() ?? "";
    final price = data["price"]?.toString() ?? "";
    final contact = data["seller_contact"]?.toString() ?? "";

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: widget.onProductTap,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.deepPurpleAccent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color.fromARGB(31, 209, 193, 255)!),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (imageUrl.isNotEmpty)
                CachedNetworkImageWrapper(
                  imageUrl: imageUrl,
                  width: 64,
                  height: 64,
                  fit: BoxFit.cover,
                  borderRadius: BorderRadius.circular(8),
                  errorWidget: Container(
                    width: 64,
                    height: 64,
                    color: Colors.grey[200],
                    child: Icon(
                      Icons.image_not_supported,
                      size: 24,
                      color: Colors.grey[400],
                    ),
                  ),
                ),
              if (imageUrl.isNotEmpty) const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (name.isNotEmpty)
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Color.fromARGB(255, 255, 255, 255),
                          fontFamily: "minigap",
                        ),
                      ),
                    if (name.isNotEmpty) const SizedBox(height: 4),
                    Row(
                      children: [
                        if (price.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green[50],
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.green[200]!),
                            ),
                            child: Text(
                              "RWF $price",
                              style: const TextStyle(
                                color: Colors.deepPurpleAccent,
                                fontWeight: FontWeight.bold,
                                fontFamily: "minigap",
                                fontSize: 11,
                              ),
                            ),
                          ),
                        if (price.isNotEmpty && contact.isNotEmpty)
                          const SizedBox(width: 6),
                        if (contact.isNotEmpty)
                          Text(
                            contact,
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey[500],
                            ),
                          ),
                      ],
                    ),
                    if (relevance != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.star,
                              size: 10, color: Colors.amber.shade600),
                          const SizedBox(width: 2),
                          Text(
                            "${relevance.toStringAsFixed(1)}/10",
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              Icon(Icons.chevron_right, size: 16, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGuideCard() {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.heavyImpact();
          widget.onActionTapped?.call('NAVIGATE_STUDENTS');
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.asset(
            'assets/pin_guide.png',
            fit: BoxFit.contain,
            width: double.infinity,
          ),
        ),
      ),
    );
  }

  List<Widget> _buildLinkPreviews() {
    return [];
  }

  static _LinkMatch _matchLink(RegExpMatch m, String text, _LinkType type) {
    return _LinkMatch(
      start: m.start,
      end: m.end,
      raw: text.substring(m.start, m.end),
      type: type,
    );
  }

  List<TextSpan> _parseTextWithLinks(String text) {
    if (text.isEmpty) return [];

    final urlRx = RegExp(
      r'(?:https?://|www\.)[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}\b[-a-zA-Z0-9()@:%_\+.~#?&//=]*',
      caseSensitive: false,
    );
    final emailRx = RegExp(
      r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}',
      caseSensitive: false,
    );
    final phoneRx = RegExp(
      r'(?:\+?\d{1,3}[-.\s]?)?\(?\d{2,4}\)?[-.\s]?\d{3,4}[-.\s]?\d{3,4}',
      caseSensitive: false,
    );

    final matches = <_LinkMatch>[];
    for (final m in urlRx.allMatches(text)) {
      matches.add(_matchLink(m, text, _LinkType.url));
    }
    for (final m in emailRx.allMatches(text)) {
      matches.add(_matchLink(m, text, _LinkType.email));
    }
    for (final m in phoneRx.allMatches(text)) {
      matches.add(_matchLink(m, text, _LinkType.phone));
    }
    matches.sort((a, b) => a.start.compareTo(b.start));

    final filtered = <_LinkMatch>[];
    for (final m in matches) {
      if (filtered.isEmpty) {
        filtered.add(m);
      } else {
        final last = filtered.last;
        if (m.start >= last.end) {
          filtered.add(m);
        } else if (m.start == last.start && m.end > last.end) {
          filtered[filtered.length - 1] = m;
        }
      }
    }

    const textStyle = TextStyle(
      color: Color.fromARGB(255, 255, 255, 255),
      fontSize: 15,
      fontFamily: 'minigap',
      height: 1.4,
    );
    const linkStyle = TextStyle(
      color: Color.fromARGB(255, 187, 219, 255),
      fontSize: 15,
      fontFamily: 'minigap',
      height: 1.4,
      decoration: TextDecoration.underline,
      decorationColor: Color.fromARGB(255, 188, 219, 255),
      decorationThickness: 1.5,
    );
    const emailStyle = TextStyle(
      color: Color(0xFF2E7D32),
      fontSize: 15,
      fontFamily: 'minigap',
      height: 1.4,
      decoration: TextDecoration.underline,
      decorationColor: Color(0xFF2E7D32),
      decorationThickness: 1.5,
    );
    const phoneStyle = TextStyle(
      color: Color(0xFFE65100),
      fontSize: 15,
      fontFamily: 'minigap',
      height: 1.4,
      decoration: TextDecoration.underline,
      decorationColor: Color(0xFFE65100),
      decorationThickness: 1.5,
    );

    final actionWordStyle = TextStyle(
      color: const Color(0xFFFFD740),
      fontSize: 15,
      fontFamily: 'minigap',
      height: 1.4,
      decoration: TextDecoration.underline,
      decorationColor: const Color(0xFFFFD740),
      decorationThickness: 2.0,
      fontWeight: FontWeight.w600,
    );

    final spans = <TextSpan>[];
    int lastEnd = 0;

    final actionWord = _parsedResponse?.actionWord;
    final actionMessage = _parsedResponse?.actionMessage ?? '';
    final hasActionWord =
        actionWord != null && actionWord.isNotEmpty && actionMessage.isNotEmpty;

    for (final link in filtered) {
      if (link.start > lastEnd) {
        if (hasActionWord) {
          spans.addAll(
            _buildSpansWithActionWord(
              text.substring(lastEnd, link.start),
              textStyle,
              actionWord!,
              actionWordStyle,
              actionMessage,
            ),
          );
        } else {
          spans.add(
            TextSpan(
              text: text.substring(lastEnd, link.start),
              style: textStyle,
            ),
          );
        }
      }

      if (link.isPhone) {
        spans.add(
          TextSpan(
            text: link.raw,
            style: phoneStyle,
            recognizer: TapGestureRecognizer()..onTap = () => _openPhone(link.raw),
          ),
        );
      } else if (link.isEmail) {
        spans.add(
          TextSpan(
            text: link.raw,
            style: emailStyle,
            recognizer: TapGestureRecognizer()..onTap = () => _openEmail(link.raw),
          ),
        );
      } else {
        final fullUrl =
            link.raw.startsWith('http://') || link.raw.startsWith('https://')
                ? link.raw
                : 'https://${link.raw}';
        spans.add(
          TextSpan(
            text: link.raw,
            style: linkStyle,
            recognizer: TapGestureRecognizer()..onTap = () => _openUrl(fullUrl),
          ),
        );
      }

      lastEnd = link.end;
    }

    if (lastEnd < text.length) {
      final remaining = text.substring(lastEnd);
      if (hasActionWord) {
        spans.addAll(
          _buildSpansWithActionWord(
            remaining,
            textStyle,
            actionWord!,
            actionWordStyle,
            actionMessage,
          ),
        );
      } else {
        spans.add(TextSpan(text: remaining, style: textStyle));
      }
    }

    return spans;
  }

  List<TextSpan> _buildSpansWithActionWord(
    String text,
    TextStyle normalStyle,
    String actionWord,
    TextStyle actionStyle,
    String actionMsg,
  ) {
    final spans = <TextSpan>[];
    final escaped = RegExp.escape(actionWord);
    final rx = RegExp(escaped, caseSensitive: false);
    int lastEnd = 0;

    for (final match in rx.allMatches(text)) {
      if (match.start > lastEnd) {
        spans.add(
          TextSpan(
            text: text.substring(lastEnd, match.start),
            style: normalStyle,
          ),
        );
      }
      spans.add(
        TextSpan(
          text: text.substring(match.start, match.end),
          style: actionStyle,
          recognizer: TapGestureRecognizer()
            ..onTap = () => _handleActionWordTap(actionMsg),
        ),
      );
      lastEnd = match.end;
    }

    if (lastEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastEnd), style: normalStyle));
    }

    return spans.isEmpty ? [TextSpan(text: text, style: normalStyle)] : spans;
  }

  void _openUrl(String url) {}

  Future<void> _openPhone(String number) async {
    final digits = number.replaceAll(RegExp(r'[^\d+]'), '');
    final uri = Uri(scheme: 'tel', path: digits);
    try {
      final launched = await launchUrl(uri);
      if (!launched && context.mounted) {
        scaffoldMessengerKey.currentState?.showSnackBar(
          const SnackBar(
            content: Text('Could not open dialer'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      if (context.mounted) {
        scaffoldMessengerKey.currentState?.showSnackBar(
          const SnackBar(
            content: Text('No phone app found'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _openEmail(String email) async {
    final uri = Uri(scheme: 'mailto', path: email);
    try {
      final launched = await launchUrl(uri);
      if (!launched && context.mounted) {
        scaffoldMessengerKey.currentState?.showSnackBar(
          const SnackBar(
            content: Text('Could not open email app'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      if (context.mounted) {
        scaffoldMessengerKey.currentState?.showSnackBar(
          const SnackBar(
            content: Text('No email app found'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) {
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}