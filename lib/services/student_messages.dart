import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kaascan/Api/client.dart';

/// One message about a child: sent by the child tapping their card on a
/// school device, or a note (maybe with a photo) from the school.
class StudentMessage {
  StudentMessage({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.kind,
    required this.status,
    required this.createdAt,
    this.photoUrl,
    this.school,
    this.balance,
    this.amount,
    this.text,
    this.notePhotoUrl,
    this.sender,
    this.billing,
    this.fee,
  });

  final int id;
  final String studentId;
  final String studentName;
  final String? photoUrl;
  final String? school;
  final double? balance;
  final String kind; // money_request | call_me | pick_me_up | custom | school_note
  final double? amount;
  final String? text;
  /// School notes only: the photo the school attached, and who sent it.
  final String? notePhotoUrl;
  final String? sender;
  /// What the message cost the child: free | paid | free_empty (card too low).
  final String? billing;
  final double? fee;
  String status; // new | read | approved | declined
  final DateTime createdAt;

  String get firstName => studentName.trim().split(' ').first;
  bool get isMoney => kind == 'money_request';
  bool get isSchool => kind == 'school_note';
  bool get isOpen => status == 'new' || status == 'read';

  static StudentMessage? fromJson(Map m) {
    final id = (m['id'] as num?)?.toInt();
    if (id == null) return null;
    return StudentMessage(
      id: id,
      studentId: m['student_id']?.toString() ?? '',
      studentName: (m['student_name']?.toString() ?? '').trim(),
      photoUrl: m['student_photo_url']?.toString(),
      school: m['school_name']?.toString(),
      balance: (m['student_balance'] as num?)?.toDouble(),
      kind: m['kind']?.toString() ?? 'custom',
      amount: (m['amount'] as num?)?.toDouble(),
      text: m['text']?.toString(),
      notePhotoUrl: m['photo_url']?.toString(),
      sender: m['sender']?.toString(),
      billing: m['billing']?.toString(),
      fee: (m['fee'] as num?)?.toDouble(),
      status: m['status']?.toString() ?? 'new',
      createdAt: DateTime.tryParse(m['created_at']?.toString() ?? '')?.toLocal() ?? DateTime.now(),
    );
  }
}

/// The parent's inbox of card-tap messages, and the unread count the nav bar
/// and the home-screen widget show.
class StudentMessages {
  StudentMessages._();

  static final ValueNotifier<int> unread = ValueNotifier(0);

  static Future<String?> _token() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('login_token');
    return (token == null || token.isEmpty) ? null : token;
  }

  /// Null when the inbox could not be loaded.
  static Future<List<StudentMessage>?> load() async {
    final token = await _token();
    if (token == null) return null;
    final res = await backendClient().studentMessages(token);
    final data = res.data;
    if (res.statusCode != 200 || data is! Map || data['messages'] is! List) return null;
    unread.value = (data['unread'] as num?)?.toInt() ?? 0;
    return (data['messages'] as List)
        .whereType<Map>()
        .map(StudentMessage.fromJson)
        .whereType<StudentMessage>()
        .toList();
  }

  static Future<void> markRead(List<int> ids) async {
    final token = await _token();
    if (token == null || ids.isEmpty) return;
    final res = await backendClient().markStudentMessagesRead(token, ids);
    if (res.statusCode == 200) {
      unread.value = (unread.value - ids.length).clamp(0, 1 << 30);
    }
  }

  /// "approved" or "declined". True when the server recorded it.
  static Future<bool> resolve(int id, String action) async {
    final token = await _token();
    if (token == null) return false;
    final res = await backendClient().resolveStudentMessage(token, id, action);
    return res.statusCode == 200;
  }
}
