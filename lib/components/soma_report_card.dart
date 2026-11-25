import 'package:flutter/material.dart';
import 'package:kaascan/components/soma_robot.dart';
import 'package:kaascan/services/language_service.dart';

/// A clean, attractive summary of a scanned school report card.
///
/// Mirrors the Somakadi agentic UI design language (palette, cards, student
/// header, section titles) so the report feels like part of the app rather than
/// a bolted-on screen.
///
/// Drawn inside Soma's chat bubble after the QR scan: child & school at the
/// top, an overall ring, one bar per subject, strengths / support tags, home
/// lessons, and a button that opens the full PDF report.
class SomaReportCard extends StatelessWidget {
  const SomaReportCard({
    super.key,
    required this.report,
    this.onSeeReport,
  });

  final Map<dynamic, dynamic> report;
  final VoidCallback? onSeeReport;

  // ── palette (mirrors agentic_ui.dart) ───────────────────────────────────

  static const blue = Color.fromARGB(255, 0, 25, 205);
  static const ink = Color(0xFF1A1F36);
  static const muted = Color(0xFF6B7280);
  static const tint = Color(0xFFF3F5FF);
  static const line = Color(0xFFE8EBF5);
  static const success = Color(0xFF0E9F6E);
  static const danger = Color(0xFFD92D20);

  static const _display = 'gilroy';
  static const _body = 'gilroy-light';

  static const _subjectColors = [
    blue,
    Color(0xFF06B6D4),
    success,
    Color(0xFFF59E0B),
    danger,
    Color(0xFF8B5CF6),
    Color(0xFFEC4899),
    Color(0xFF14B8A6),
    Color(0xFF3B82F6),
    Color(0xFF84CC16),
  ];

  bool get _rw => languageService.currentLanguageCode == 'rw';
  bool get _fr => languageService.currentLanguageCode == 'fr';

  String _t(String en, String rw, String fr) => _rw ? rw : (_fr ? fr : en);

  String get _studentName => _s(report['student_name']);
  String get _school => _s(report['school']);
  String get _district => _s(report['district']);
  String get _grade => _s(report['grade'], fallback: '-');
  String get _decision => _s(report['decision']);
  String get _summary => _s(report['summary']);
  double get _overall => _d(report['overall_percent']);
  double get _conduct => _d(report['conduct']);
  double get _conductMax =>
      _d(report['conduct_max'], fallback: 40) == 0 ? 40 : _d(report['conduct_max']);

  List<Map<dynamic, dynamic>> get _subjects => _list(report['subjects']);
  List<String> get _strengths => _strings(report['strengths']);
  List<String> get _needsSupport => _strings(report['needs_support']);
  List<String> get _homeTips => _strings(report['home_tips']);

  @override
  Widget build(BuildContext context) {
    final gradeColor = _gradeColor(_grade);
    return Container(
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _header(gradeColor),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
            child: _overallRow(gradeColor),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
            child: Column(
              children: [
                for (var i = 0; i < _subjects.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 11),
                    child: _subjectRow(
                      _subjects[i],
                      _subjectColors[i % _subjectColors.length],
                      i,
                    ),
                  ),
              ],
            ),
          ),
          if (_strengths.isNotEmpty || _needsSupport.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: _tags(),
            ),
          if (_summary.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: _somaNote(),
            ),
          if (_homeTips.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: _homeLessons(),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 20),
            child: _reportButton(),
          ),
        ],
      ),
    );
  }

  // ── header ──────────────────────────────────────────────────────────────

  Widget _header(Color gradeColor) {
    final where = [_school, _district].where((s) => s.isNotEmpty).join(' · ');
    return Row(
      children: [
        Container(
          width: 46,
          height: 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: tint,
            shape: BoxShape.circle,
            border: Border.all(color: line, width: 1.5),
          ),
          child: SizedBox(
            width: 30,
            height: 30,
            child: OverflowBox(
              maxWidth: 70,
              maxHeight: 70,
              child: SomaRobot(
                size: 70,
                floating: false,
                color: SomaRobotColor.purple,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _studentName.isEmpty ? _t('Report card', 'Raporo', 'Bulletin') : _studentName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: ink,
                  fontFamily: _display,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  height: 1.1,
                ),
              ),
              if (where.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(
                  where,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: muted,
                    fontFamily: _body,
                    fontWeight: FontWeight.w600,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
          decoration: BoxDecoration(
            color: gradeColor.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: gradeColor.withValues(alpha: 0.35)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _grade,
                style: TextStyle(
                  color: gradeColor,
                  fontFamily: _display,
                  fontWeight: FontWeight.w900,
                  fontSize: 22,
                  height: 1,
                ),
              ),
              Text(
                _t('GRADE', 'ICYICIRO', 'NOTE'),
                style: TextStyle(
                  color: muted,
                  fontFamily: _display,
                  fontWeight: FontWeight.w700,
                  fontSize: 8,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── overall ─────────────────────────────────────────────────────────────

  Widget _overallRow(Color gradeColor) {
    final pct = _overall.clamp(0, 100).toDouble();
    final decisionColor =
        _decision.toUpperCase() == 'REPEAT' ? danger : success;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
          SizedBox(
            width: 70,
            height: 70,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 70,
                  height: 70,
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: pct / 100),
                      duration: const Duration(milliseconds: 900),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, _) => CircularProgressIndicator(
                        value: value,
                        strokeWidth: 8,
                        strokeCap: StrokeCap.round,
                        backgroundColor: gradeColor.withValues(alpha: 0.14),
                        valueColor: AlwaysStoppedAnimation<Color>(gradeColor),
                      ),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${pct.round()}%',
                        style: TextStyle(
                          color: ink,
                          fontFamily: _display,
                          fontWeight: FontWeight.w800,
                          fontSize: 20,
                          height: 1,
                        ),
                      ),
                      Text(
                        _t('overall', 'rusange', 'général'),
                        style: TextStyle(
                          color: muted,
                          fontFamily: _body,
                          fontWeight: FontWeight.w600,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _t('Overall performance', 'Amanota rusange', 'Résultat général'),
                    style: TextStyle(
                      color: ink,
                      fontFamily: _display,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${_subjects.length} ${_t('subjects', 'amasomo', 'matières')}',
                    style: TextStyle(
                      color: muted,
                      fontFamily: _body,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _miniChip(
                        Icons.emoji_events_rounded,
                        _t('Conduct', 'Imyitwarire', 'Conduite'),
                        '${_conduct.toStringAsFixed(0)}/${_conductMax.toStringAsFixed(0)}',
                        blue,
                      ),
                      _miniChip(
                        _decision.toUpperCase() == 'REPEAT'
                            ? Icons.replay_rounded
                            : Icons.verified_rounded,
                        _t('Decision', 'Icyemezo', 'Décision'),
                        _decision.toUpperCase() == 'REPEAT'
                            ? _t('Repeat', 'Asubiramo', 'Reprend')
                            : _t('Promoted', 'Aragera', 'Promu'),
                        decisionColor,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _miniChip(IconData icon, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            '$label ',
            style: TextStyle(
              color: muted,
              fontFamily: _body,
              fontWeight: FontWeight.w600,
              fontSize: 10,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontFamily: _display,
              fontWeight: FontWeight.w800,
              fontSize: 10.5,
            ),
          ),
        ],
      ),
    );
  }

  // ── subject bars ────────────────────────────────────────────────────────

  Widget _subjectRow(Map<dynamic, dynamic> subject, Color color, int index) {
    final name = _s(subject['short_name'], fallback: _s(subject['name']));
    final pct = _d(subject['percent']).clamp(0, 100).toDouble();
    final grade = _s(subject['grade'], fallback: '-');
    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: ink,
              fontFamily: _body,
              fontWeight: FontWeight.w600,
              fontSize: 12.5,
            ),
          ),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: pct / 100),
              duration: Duration(milliseconds: 700 + index * 60),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) => LinearProgressIndicator(
                value: value,
                minHeight: 9,
                backgroundColor: color.withValues(alpha: 0.10),
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ),
        ),
        const SizedBox(width: 7),
        SizedBox(
          width: 30,
          child: Text(
            '${pct.round()}%',
            textAlign: TextAlign.right,
            style: TextStyle(
              color: muted,
              fontFamily: _body,
              fontWeight: FontWeight.w600,
              fontSize: 11.5,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            grade,
            style: TextStyle(
              color: color,
              fontFamily: _display,
              fontWeight: FontWeight.w800,
              fontSize: 11,
            ),
          ),
        ),
      ],
    );
  }

  // ── strengths / support ─────────────────────────────────────────────────

  Widget _tags() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final name in _strengths)
          _tag(
            Icons.star_rounded,
            name,
            success,
          ),
        for (final name in _needsSupport)
          _tag(
            Icons.support_rounded,
            name,
            danger,
          ),
      ],
    );
  }

  Widget _tag(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontFamily: _body,
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  // ── Soma note ───────────────────────────────────────────────────────────

  Widget _somaNote() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: blue.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: SizedBox(
              width: 20,
              height: 20,
              child: OverflowBox(
                maxWidth: 50,
                maxHeight: 50,
                child: SomaRobot(
                  size: 50,
                  floating: false,
                  color: SomaRobotColor.orange,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _summary,
              style: TextStyle(
                color: ink.withValues(alpha: 0.82),
                fontFamily: _body,
                fontWeight: FontWeight.w500,
                fontSize: 12.5,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── home lessons ────────────────────────────────────────────────────────

  Widget _homeLessons() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: success.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: success.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: success,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.school_rounded, color: Colors.white, size: 11),
              ),
              const SizedBox(width: 8),
              Text(
                _t('Lessons to do at home',
                    'Ibyo mwakorera mu rugo', 'Leçons à la maison'),
                style: TextStyle(
                  color: success,
                  fontFamily: _display,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final tip in _homeTips)
            Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.only(top: 6),
                    decoration: const BoxDecoration(
                      color: success,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      tip,
                      style: TextStyle(
                        color: ink.withValues(alpha: 0.78),
                        fontFamily: _body,
                        fontWeight: FontWeight.w500,
                        fontSize: 12.5,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ── PDF button ──────────────────────────────────────────────────────────

  Widget _reportButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onSeeReport,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [blue, Color(0xFF0033CC)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: blue.withValues(alpha: 0.35),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                const Icon(Icons.picture_as_pdf_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _t('See the full report',
                        'Reba raporo yose', 'Voir le bulletin complet'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: _display,
                      fontWeight: FontWeight.w700,
                      fontSize: 14.5,
                    ),
                  ),
                ),
                const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── helpers ─────────────────────────────────────────────────────────────

  static Color _gradeColor(String grade) {
    switch (grade.toUpperCase()) {
      case 'A':
        return success;
      case 'B':
        return Color(0xFF0D9488);
      case 'C':
        return blue;
      case 'D':
        return Color(0xFF7C3AED);
      case 'E':
        return Color(0xFFD97706);
      case 'S':
        return Color(0xFFEA580C);
      default:
        return danger;
    }
  }

  static String _s(dynamic value, {String fallback = ''}) {
    final text = value?.toString() ?? '';
    return text.isEmpty ? fallback : text;
  }

  static double _d(dynamic value, {double fallback = 0}) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static List<String> _strings(dynamic value) {
    if (value is List) {
      return value.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
    }
    return const [];
  }

  static List<Map<dynamic, dynamic>> _list(dynamic value) {
    if (value is List) {
      return value.whereType<Map>().map((e) => e).toList();
    }
    return const [];
  }
}
