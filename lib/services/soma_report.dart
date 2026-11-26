import 'dart:typed_data';

import 'package:qaad_sdk/qaad_sdk.dart';

/// One subject on a scanned report card, reduced to what the chat needs.
class SomaSubject {
  const SomaSubject({
    required this.name,
    required this.annualTotal,
    required this.annualMax,
    required this.termPercents,
  });

  final String name;
  final int annualTotal;
  final int annualMax;
  final List<double> termPercents;

  /// Authoritative term-wise percentage (from `block_7`), averaged across
  /// terms and clamped to 0-100. Falls back to annual total/max when terms
  /// are missing, since some cards encode `block_7` as a raw mark instead of
  /// a percentage.
  double get percent {
    if (termPercents.isNotEmpty) {
      final total = termPercents.reduce((a, b) => a + b);
      return (total / termPercents.length).clamp(0, 100).toDouble();
    }
    return annualMax == 0 ? 0 : (annualTotal / annualMax) * 100;
  }

  double get displayPercent => percent.clamp(0, 100).toDouble();

  String get grade => SomaReport.gradeFor(displayPercent);

  String get shortName => SomaReport.shortSubject(name);
}

/// A school report card decoded from the QR code Soma scans.
///
/// The QR carries a base-101 compressed list of tokens. [Comp.decompress]
/// turns it back into tokens, and [DataAttention] maps the tokens to the
/// student, school and marks.
class SomaReport {
  SomaReport._({
    required this.payload,
    required this.rawMarks,
    required this.studentName,
    required this.studentId,
    required this.schoolName,
    required this.district,
    required this.schoolPhone,
    required this.headTeacher,
    required this.subjects,
    required this.conductMarks,
    required this.conductMax,
    required this.overallPercent,
    required this.decision,
  });

  final Uint8List payload;

  /// The raw token list the marks were built from. Kept so the PDF report can
  /// be regenerated later from the same scan.
  final List<dynamic> rawMarks;

  final String studentName;
  final String studentId;
  final String schoolName;
  final String district;
  final String schoolPhone;
  final String headTeacher;
  final List<SomaSubject> subjects;
  final List<int> conductMarks;
  final int conductMax;
  final double overallPercent;
  final String decision;

  // ── decode ──────────────────────────────────────────────────────────────

  static SomaReport decode(Uint8List payload) {
    final tokens = Comp.decompress(payload);
    if (tokens.isEmpty) {
      throw const FormatException('The report QR code was empty.');
    }

    final attention = DataAttention(data: tokens);
    final raw = attention.layer_2();
    final rawMarks = attention.smData(attention.layer_1());

    final student = _asMap(raw['student_data']);
    final school = _asMap(raw['school_data']);
    final marks = _asMap(raw['student_marks']);
    final conduct = _asMap(marks['conduct_marks']);
    final subjectsAlloc = _asMap(_asMap(marks['subject_marks'])['subjects_alloc']);

    final subjects = <SomaSubject>[];
    for (final entry in subjectsAlloc.entries) {
      final subject = _asMap(entry.value);
      if (subject.isEmpty) continue;
      final terms = <double>[];
      var annualTotal = 0;
      var annualMax = 0;
      for (final key in const ['term_1', 'term_2', 'term_3']) {
        final term = _asMap(subject[key]);
        final termPercent = _percent(_first(term['block_7']));
        final termTotal = _int(_first(term['block_6']));
        final examTotal =
            _int(_first(term['block_4'])) + _int(_first(term['block_5']));
        // Same inference the PDF uses: block_3 is not reliable for every
        // subject, but the term's exam total and percentage are.
        final termMax = termPercent > 0
            ? ((examTotal / termPercent) * 100).round()
            : 180;
        terms.add(termPercent);
        annualTotal += termTotal;
        annualMax += termMax > 0 ? termMax : 180;
      }
      subjects.add(
        SomaSubject(
          name: entry.key.toString(),
          annualTotal: annualTotal,
          annualMax: annualMax <= 0 ? 180 : annualMax,
          termPercents: terms,
        ),
      );
    }

    if (subjects.isEmpty) {
      throw const FormatException('No marks were found on this report card.');
    }

    // Overall is the average of subject percentages (block_7 is authoritative
    // for each term), so it stays consistent with what the card shows even
    // when `block_7` is a raw mark for some subjects.
    final overall = subjects.isEmpty
        ? 0.0
        : (subjects
                .fold<double>(0, (sum, s) => sum + s.displayPercent) /
            subjects.length)
            .clamp(0, 100)
            .toDouble();

    final conductList = (conduct['marks'] as List?)
            ?.map((e) => _int(e))
            .toList() ??
        const <int>[];

    return SomaReport._(
      payload: payload,
      rawMarks: rawMarks,
      studentName: _prettyName(student['fullname']?.toString() ?? ''),
      studentId: student['studentid']?.toString() ?? '',
      schoolName: school['school_name']?.toString() ?? '',
      district: school['school_district']?.toString() ?? '',
      schoolPhone: school['school_phonenumber']?.toString() ?? '',
      headTeacher: school['director_name']?.toString() ?? '',
      subjects: subjects,
      conductMarks: conductList,
      conductMax: _int(conduct['max']),
      overallPercent: overall,
      decision: overall >= 50 ? 'PROMOTED' : 'REPEAT',
    );
  }

  // ── derived views ───────────────────────────────────────────────────────

  String get overallGrade => gradeFor(overallPercent);

  double get conductAverage {
    if (conductMarks.isEmpty || conductMax == 0) return 0;
    final total = conductMarks.fold<int>(0, (sum, mark) => sum + mark);
    return (total / conductMarks.length).clamp(0, conductMax).toDouble();
  }

  List<SomaSubject> get strengths {
    final sorted = [...subjects]
      ..sort((a, b) => b.displayPercent.compareTo(a.displayPercent));
    return sorted.where((s) => s.displayPercent >= 60).take(2).toList();
  }

  List<SomaSubject> get needsSupport {
    final sorted = [...subjects]
      ..sort((a, b) => a.displayPercent.compareTo(b.displayPercent));
    return sorted.where((s) => s.displayPercent < 60).take(2).toList();
  }

  String get summary {
    final strengthsText = strengths.map((s) => s.shortName).join(' na ');
    final needsText = needsSupport.map((s) => s.shortName).join(' na ');
    if (strengths.isEmpty && needsSupport.isEmpty) {
      return 'Raporo yarangiye neza. Komeza umushyigikire mu masomo ye.';
    }
    if (strengths.isEmpty) {
      return 'Amanota ari hagati ya 50 na 60. '
          'Tuzamufasha cyane mu $needsText.';
    }
    if (needsSupport.isEmpty) {
      return 'Komeza umushyigikire: yagaragaje imbaraga mu $strengthsText.';
    }
    return 'Yagaragaje imbaraga mu $strengthsText. '
        'Tuzamufasha cyane mu $needsText.';
  }

  /// Two or three practical lessons a parent can do at home, chosen from the
  /// subjects that need the most support (or from the strengths when every
  /// subject is already above the line).
  List<String> homeTips(String language) {
    final rw = language == 'rw';
    final focus = needsSupport.isEmpty
        ? strengths.take(1).toList()
        : needsSupport;
    final tips = <String>[
      for (final subject in focus) _tipFor(subject.shortName, rw),
    ];
    if (tips.length < 2) {
      tips.add(rw
          ? 'Mufashe gusubiramo amasomo mu minota 15 buri munsi.'
          : 'Help them revise for 15 minutes every day.');
    }
    if (tips.length < 3) {
      tips.add(rw
          ? 'Mushimire imbaraga ashyiraho kandi muganire n\'umwarimu.'
          : 'Praise the effort and talk with the teacher.');
    }
    return tips.take(3).toList();
  }

  /// A short, playful invitation. The full report is already on the card —
  /// the parent chooses what to talk about instead of being given everything.
  String introMessage(String language) {
    final name = studentName.isEmpty ? 'umwana wawe' : studentName;
    switch (language) {
      case 'rw':
        return 'Ehe, namaze gusoma indanga ya $name! 😊 Ushaka kureba iki cya mbere: '
            'amanota, amakuru y\'ishuri, cyangwa inama zo mu rugo?';
      case 'fr':
        return 'J\'ai lu le bulletin de $name. Par quoi commençons-nous — '
            'les notes, les détails de l\'école ou les activités à la maison ?';
      default:
        return 'I just read $name\'s report card. What should we look at first — '
            'the marks, the school notes, or the home lessons?';
    }
  }

  /// Status lines shown on the thinking robot while a report is being read.
  static const List<String> thinkingPhrases = [
    'Ndigusoma indanga manota',
    'Kureba amakuru',
    'Kureba ibihembye byose',
  ];

  /// Topic chips shown under the intro so the parent can steer the chat.
  List<Map<String, String>> topics(String language) {
    switch (language) {
      case 'fr':
        return [
          {'key': 'marks', 'label': 'Voir les notes', 'message': 'Parle-moi des notes.'},
          {'key': 'info', 'label': 'Voir les détails', 'message': 'Kureba amakuru'},
          {'key': 'lessons', 'label': 'Activités à la maison', 'message': 'Inama zo mu rugo'},
        ];
      case 'rw':
        break;
    }
    return [
      {'key': 'marks', 'label': 'Reba amanota', 'message': 'Mbwira amanota y\'umwana'},
      {'key': 'info', 'label': 'Kureba amakuru', 'message': 'Kureba amakuru'},
      {'key': 'lessons', 'label': 'Inama zo mu rugo', 'message': 'Inama zo mu rugo'},
    ];
  }

  /// The prompt sent to the Soma agent. It carries a compact copy of the data
  /// as CONTEXT ONLY — the app has already shown the full card, and the parent
  /// asks about one thing at a time. Never dump everything in one answer.
  String agentPrompt(String language) {
    final buffer = StringBuffer()
      ..writeln('[SOMA REPORT CARD — just scanned by the parent]')
      ..writeln('The app already decoded and displayed this report in full. '
          'Use the data below only to answer what the parent asks — never '
          'repeat all of it at once.')
      ..writeln('Student: ${studentName.isEmpty ? 'Unknown' : studentName}')
      ..writeln('School: $schoolName${district.isEmpty ? '' : ' ($district)'}')
      ..writeln(
          'Overall: ${overallPercent.toStringAsFixed(1)}% (grade $overallGrade)')
      ..writeln('Decision: $decision')
      ..writeln(
          'Conduct: ${conductAverage.toStringAsFixed(0)} / ${conductMax == 0 ? 40 : conductMax}')
      ..writeln('Subjects (context for follow-up questions):');
    for (final subject in subjects) {
      final terms =
          subject.termPercents.map((p) => p.clamp(0, 100).toStringAsFixed(1)).join(' / ');
      buffer.writeln(
          '- ${subject.shortName}: ${subject.displayPercent.toStringAsFixed(1)}% '
          '(grade ${subject.grade}); terms $terms');
    }
    if (strengths.isNotEmpty) {
      buffer.writeln(
          'Strongest: ${strengths.map((s) => s.shortName).join(', ')}');
    } else {
      buffer.writeln(
          'No subject is above 60 yet; praise the effort and the best '
          'relative subject.');
    }
    if (needsSupport.isNotEmpty) {
      buffer.writeln(
          'Needs support: ${needsSupport.map((s) => s.shortName).join(', ')}');
    }
    buffer
      ..writeln()
      ..writeln('HOW TO REPLY (playful Soma robot, parent-led conversation)')
      ..writeln('1. This first message: notice one genuine effort with a warm, '
          'playful touch, then ask which part the parent wants to look at '
          'first — marks, school details, or home lessons. Offer at most these '
          'three choices in one short question.')
      ..writeln('2. After that, answer ONLY the part they ask about. Give one '
          'clear, encouraging insight and stop — let them ask the next thing. '
          'Never list every subject or repeat the overall number unasked.')
      ..writeln('3. "Amanota" = marks, "amakuru" = details, "ibihembye" = '
          'remarks. Use the parent\'s own words. Celebrate small wins; if no '
          'subject is above 60, praise effort instead of listing failures.')
      ..writeln('4. Reply in the parent\'s language, under 90 words, no money '
          'talk, no jargon. Act curious and delighted to figure it out together.');
    return buffer.toString();
  }

  /// Everything the chat card needs, as plain values.
  Map<String, dynamic> toUiMap([String language = 'rw']) => {
        'student_name': studentName,
        'student_id': studentId,
        'school': schoolName,
        'district': district,
        'overall_percent': overallPercent,
        'grade': overallGrade,
        'decision': decision,
        'conduct': conductAverage,
        'conduct_max': conductMax == 0 ? 40 : conductMax,
        'summary': summary,
        'home_tips': homeTips(language),
        'topics': topics(language),
        'subjects': [
          for (final subject in subjects)
            {
              'name': subject.name,
              'short_name': subject.shortName,
              'percent': subject.displayPercent,
              'grade': subject.grade,
              'terms': subject.termPercents
                  .map((p) => p.clamp(0, 100).toDouble())
                  .toList(),
            },
        ],
        'strengths': [for (final s in strengths) s.shortName],
        'needs_support': [for (final s in needsSupport) s.shortName],
      };

  /// Builds the full PDF report from the same scan.
  Future<Uint8List> generatePdf() {
    final primary = Primary(
      schoolStudentData: {
        'student_data': {
          'fullname': studentName,
          'studentid': studentId,
        },
        'school_data': {
          'school_name': schoolName,
          'school_district': district,
          'school_phonenumber': schoolPhone,
          'director_name': headTeacher,
        },
      },
      data: rawMarks,
    );
    return primary.generateReportPdf();
  }

  // ── helpers ─────────────────────────────────────────────────────────────

  static String _tipFor(String subject, bool rw) {
    switch (subject) {
      case 'Kinyarwanda':
        return rw
            ? 'Soma inkuru ngufi buri joro, hanyuma umubaze ibyo yumvise.'
            : 'Read a short story every evening, then ask what they understood.';
      case 'Mathematics':
        return rw
            ? 'Mukore imyitozo mike y\'ibiharuro buri munsi, muyongere buhoro.'
            : 'Do a few maths exercises daily, adding new ones slowly.';
      case 'English':
        return rw
            ? 'Muvuge interuro eshanu z\'icyongereza ku meza, cyangwa asome ijwi rirangira.'
            : 'Say five English sentences at the table, or read aloud together.';
      case 'French':
        return rw
            ? 'Mukoreshe interuro ngufi z\'igifaransa buri munsi, cyangwa mureke asome ijwi rirangira.'
            : 'Practise short French sentences daily, or read aloud together.';
      case 'Science':
        return rw
            ? 'Murebe video ngufi cyangwa muganire ku bidukikije nk\'amazi n\'ibimera.'
            : 'Watch a short science video or talk about water and plants around you.';
      case 'Social Studies':
        return rw
            ? 'Muganire ku byabaye mu gihugu n\'amateka y\'umuryango wawe.'
            : 'Talk about current events and your family history together.';
      case 'PE':
        return rw
            ? 'Mukore siporo ngufi hamwe buri munsi, nko kwiruka cyangwa kugenda.'
            : 'Do a short activity together daily, like running or walking.';
      case 'Creative Arts':
        return rw
            ? 'Mumufashe gushushanya cyangwa kuririmba buri cyumweru.'
            : 'Draw or sing together every week.';
      default:
        return rw
            ? 'Mufashe gusubiramo amasomo mu minota 15 buri munsi.'
            : 'Help them revise for 15 minutes every day.';
    }
  }

  static String gradeFor(double percent) {
    if (percent >= 80) return 'A';
    if (percent >= 75) return 'B';
    if (percent >= 70) return 'C';
    if (percent >= 65) return 'D';
    if (percent >= 60) return 'E';
    if (percent >= 50) return 'S';
    return 'F';
  }

  static String shortSubject(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('kinyarwanda')) return 'Kinyarwanda';
    if (lower.contains('mathematics') || lower.contains('math')) {
      return 'Mathematics';
    }
    if (lower.contains('english')) return 'English';
    if (lower.contains('french')) return 'French';
    if (lower.contains('social studies')) return 'Social Studies';
    if (lower.contains('science')) return 'Science';
    if (lower.contains('physical education')) return 'PE';
    if (lower.contains('creative arts')) return 'Creative Arts';
    return name;
  }

  /// "InezaDeborah" → "Ineza Deborah"; leaves normal names alone.
  static String _prettyName(String raw) {
    if (raw.trim().isEmpty) return raw;
    return raw
        .replaceAllMapped(RegExp(r'(?<!^)(?=[A-Z])'), (match) => ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static Map<dynamic, dynamic> _asMap(dynamic value) {
    if (value is Map) return value;
    return const <dynamic, dynamic>{};
  }

  static dynamic _first(dynamic value) {
    if (value is List) return value.isEmpty ? null : value.first;
    return value;
  }

  static int _int(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static double _percent(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(
          value?.toString().replaceAll('%', '').trim() ?? '',
        ) ??
        0;
  }
}
