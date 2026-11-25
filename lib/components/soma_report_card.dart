import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:kaascan/components/soma_robot.dart';
import 'package:kaascan/services/language_service.dart';

/// A colourful, animated summary of a scanned school report card.
///
/// It is drawn inside Soma's chat bubble after the QR scan: the child and
/// school at the top, an overall ring, one bar per subject in its own colour,
/// the strengths and the subjects to support, and a button that opens the full
/// PDF report.
class SomaReportCard extends StatelessWidget {
  const SomaReportCard({
    super.key,
    required this.report,
    this.onSeeReport,
  });

  final Map<dynamic, dynamic> report;
  final VoidCallback? onSeeReport;

  static const _subjectColors = [
    Color(0xFF6366F1),
    Color(0xFF06B6D4),
    Color(0xFF10B981),
    Color(0xFFF59E0B),
    Color(0xFFEF4444),
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
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _header(gradeColor),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
            child: _overallRow(gradeColor),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
            child: Column(
              children: [
                for (var i = 0; i < _subjects.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 9),
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
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 0),
              child: _tags(),
            ),
          if (_summary.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
              child: _somaNote(),
            ),
          if (_homeTips.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
              child: _homeLessons(),
            ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: _reportButton(),
          ),
        ],
      ),
    );
  }

  // ── header ──────────────────────────────────────────────────────────────

  Widget _header(Color gradeColor) {
    final where = [_school, _district].where((s) => s.isNotEmpty).join(' · ');
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1E1B4B), Color(0xFF6D28D9), Color(0xFFDB2777)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.35),
                width: 1.5,
              ),
            ),
            alignment: Alignment.center,
            child: SizedBox(
              width: 34,
              height: 34,
              child: OverflowBox(
                maxWidth: 78,
                maxHeight: 78,
                child: SomaRobot(
                  size: 78,
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
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                  ),
                ),
                if (where.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    where,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                      color: Colors.white.withValues(alpha: 0.78),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
            decoration: BoxDecoration(
              color: gradeColor,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: gradeColor.withValues(alpha: 0.55),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _grade,
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
                Text(
                  _t('GRADE', 'ICYICIRO', 'NOTE'),
                  style: GoogleFonts.outfit(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── overall ─────────────────────────────────────────────────────────────

  Widget _overallRow(Color gradeColor) {
    final pct = _overall.clamp(0, 100).toDouble();
    final decisionColor =
        _decision.toUpperCase() == 'REPEAT' ? const Color(0xFFDC2626) : const Color(0xFF15803D);
    return Row(
      children: [
        SizedBox(
          width: 76,
          height: 76,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 76,
                height: 76,
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
                    style: GoogleFonts.outfit(
                      color: const Color(0xFF11142D),
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      height: 1,
                    ),
                  ),
                  Text(
                    _t('overall', 'rusange', 'général'),
                    style: GoogleFonts.outfit(
                      color: const Color(0xFF11142D).withValues(alpha: 0.55),
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
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
                style: GoogleFonts.outfit(
                  color: const Color(0xFF11142D),
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${_subjects.length} ${_t('subjects', 'amasomo', 'matières')}',
                style: GoogleFonts.outfit(
                  color: const Color(0xFF11142D).withValues(alpha: 0.55),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _miniChip(
                    Icons.emoji_events_rounded,
                    _t('Conduct', 'Imyitwarire', 'Conduite'),
                    '${_conduct.toStringAsFixed(0)}/${_conductMax.toStringAsFixed(0)}',
                    const Color(0xFF0EA5E9),
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
    );
  }

  Widget _miniChip(IconData icon, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            '$label ',
            style: GoogleFonts.outfit(
              color: const Color(0xFF11142D).withValues(alpha: 0.6),
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.outfit(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w800,
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
          width: 86,
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.outfit(
              color: const Color(0xFF11142D),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: pct / 100),
              duration: Duration(milliseconds: 700 + index * 70),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) => LinearProgressIndicator(
                value: value,
                minHeight: 8,
                backgroundColor: color.withValues(alpha: 0.12),
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 38,
          child: Text(
            '${pct.round()}%',
            textAlign: TextAlign.right,
            style: GoogleFonts.outfit(
              color: const Color(0xFF11142D).withValues(alpha: 0.7),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Container(
          width: 22,
          height: 22,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(7),
          ),
          child: Text(
            grade,
            style: GoogleFonts.outfit(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }

  // ── strengths / support ─────────────────────────────────────────────────

  Widget _tags() {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final name in _strengths)
          _tag(
            Icons.star_rounded,
            name,
            const Color(0xFF15803D),
          ),
        for (final name in _needsSupport)
          _tag(
            Icons.support_rounded,
            name,
            const Color(0xFFD97706),
          ),
      ],
    );
  }

  Widget _tag(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.outfit(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  // ── Soma note ───────────────────────────────────────────────────────────

  Widget _somaNote() {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF5F3FF), Color(0xFFFDF2F8)],
        ),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: const Color(0xFF7C3AED).withValues(alpha: 0.10)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(
            width: 30,
            height: 30,
            child: OverflowBox(
              maxWidth: 70,
              maxHeight: 70,
              child: SomaRobot(
                size: 70,
                floating: false,
                color: SomaRobotColor.orange,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _summary,
              style: GoogleFonts.outfit(
                color: const Color(0xFF11142D).withValues(alpha: 0.82),
                fontSize: 12,
                height: 1.4,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── home lessons ────────────────────────────────────────────────────────

  Widget _homeLessons() {
    const green = Color(0xFF15803D);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: green.withValues(alpha: 0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.school_rounded, size: 16, color: green),
              const SizedBox(width: 6),
              Text(
                _t('Lessons to do at home',
                    'Ibyo mwakorera mu rugo', 'Leçons à la maison'),
                style: GoogleFonts.outfit(
                  color: green,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final tip in _homeTips)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.only(top: 5),
                    decoration: const BoxDecoration(
                      color: green,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      tip,
                      style: GoogleFonts.outfit(
                        color: const Color(0xFF11142D).withValues(alpha: 0.78),
                        fontSize: 12,
                        height: 1.35,
                        fontWeight: FontWeight.w500,
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
              colors: [Color(0xFF7C3AED), Color(0xFFDB2777)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF7C3AED).withValues(alpha: 0.35),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                const Icon(Icons.picture_as_pdf_rounded,
                    color: Colors.white, size: 20),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    _t('See the full report',
                        'Reba raporo yose', 'Voir le bulletin complet'),
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const Icon(Icons.arrow_forward_rounded,
                    color: Colors.white, size: 18),
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
        return const Color(0xFF15803D);
      case 'B':
        return const Color(0xFF0D9488);
      case 'C':
        return const Color(0xFF2563EB);
      case 'D':
        return const Color(0xFF7C3AED);
      case 'E':
        return const Color(0xFFD97706);
      case 'S':
        return const Color(0xFFEA580C);
      default:
        return const Color(0xFFDC2626);
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
