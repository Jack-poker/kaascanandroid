import 'package:flutter/material.dart';
import 'package:kaascan/dashboard/home.dart' show currentIndex;
import 'package:kaascan/screens/kaascan_ai.dart' show somaPrompt;
import 'package:kaascan/services/language_service.dart';

const Color myColor = Color.fromARGB(255, 0, 34, 255);
const Color myWhite = Colors.white;
const Color myOpblue = Color.fromARGB(179, 137, 160, 255);
const Color deepNavy = Color(0xFF1A1F36);
const Color softGray = Color(0xFF9CA3AF);
const Color cloudWhite = Color(0xFFFAFBFC);
const Color lightBlue = Color(0xFFE6F0FF);
const Color successGreen = Color(0xFF10B981);
const Color warningYellow = Color.fromARGB(255, 255, 60, 0);

/// "Add a student" opens the Soma chat, which asks for the child's student
/// code. Children are never picked from a list or searched by name, so no
/// parent can see other families' children.
void openAddStudentDialog(BuildContext context, Color accentColor) {
  Navigator.of(context).popUntil((route) => route is! PopupRoute);
  currentIndex.value = 0;
  somaPrompt.value = switch (languageService.currentLanguageCode) {
    'rw' => 'Huza umwana',
    'fr' => 'Lier un enfant',
    _ => 'Link a child',
  };
}
