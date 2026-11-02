// import 'package:ai_barcode_scanner/ai_barcode_scanner.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:http/http.dart' as http;
import 'package:kaascan/dashboard/home.dart';
import 'package:kaascan/onBoradingScreen.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:kaascan/widgets/cached_network_image_wrapper.dart';

import 'package:phone_form_field/phone_form_field.dart';
import 'package:shared_preferences/shared_preferences.dart';

const Color myColor = Color.fromARGB(255, 0, 34, 255);
const Color myWhite = Colors.white;
const Color myOpblue = Color.fromARGB(179, 137, 160, 255);
const Color deepNavy = Color(0xFF1A1F36);
const Color softGray = Color(0xFF9CA3AF);
const Color cloudWhite = Color(0xFFFAFBFC);
const Color lightBlue = Color(0xFFE6F0FF);
const Color successGreen = Color(0xFF10B981);
const Color warningYellow = Color.fromARGB(255, 255, 60, 0);

class AddStudentDialog extends StatefulWidget {
  final Color accentColor;

  const AddStudentDialog({Key? key, required this.accentColor})
    : super(key: key);

  @override
  _AddStudentDialogState createState() => _AddStudentDialogState();
}

class _AddStudentDialogState extends State<AddStudentDialog> {
  int _step = 0;
  String? _selectedSchool;
  String? _selectedStudentId;
  Map<String, dynamic>? _studentProfile;
  List<Map<String, dynamic>> _allStudents = [];
  List<String> _schools = [];
  List<String> _filteredSchools = [];
  List<Map<String, dynamic>> _filteredStudents = [];
  bool _isLoading = false;
  bool _hasError = false;
  final TextEditingController _search = TextEditingController();
  final TextEditingController _schoolSearch = TextEditingController();
  String? _resultMessage;
  bool _resultIsError = false;

  @override
  void initState() {
    super.initState();
    _loadStudents();
  }

  @override
  void dispose() {
    _search.dispose();
    _schoolSearch.dispose();
    super.dispose();
  }

  Future<void> _loadStudents() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    try {
      final resp = await http
          .get(Uri.parse('https://automation.kaascan.com/webhook/schools'))
          .timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        final List<dynamic> data = json.decode(resp.body);
        _allStudents = data.cast<Map<String, dynamic>>();
        _schools =
            _allStudents.map((s) => s['school_name'] as String).toSet().toList()
              ..sort();
        _filteredSchools = List.from(_schools);
      } else {
        _showSnack(
          'Error fetching students: ${resp.statusCode}. Please try again later.',
        );
        setState(() => _hasError = true);
      }
    } catch (e) {
      _showSnack(
        'Network error: Unable to connect. Please check your internet and try again.',
      );
      setState(() => _hasError = true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showSnack(String msg) {
    Get.snackbar(
      "Notice", // Title of the snackbar
      msg, // Message content
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.black.withOpacity(0.7),
      colorText: Colors.white,
      margin: EdgeInsets.all(12),
      borderRadius: 10,
      duration: Duration(seconds: 3),
    );
  }

  void _applyFilter() {
    if (_selectedSchool == null) return;
    final query = _search.text.toLowerCase();
    _filteredStudents =
        _allStudents
            .where(
              (s) =>
                  s['school_name'] == _selectedSchool &&
                  (s['student_name'] as String).toLowerCase().contains(query),
            )
            .toList()
          ..sort((a, b) => a['student_name'].compareTo(b['student_name']));
    setState(() {});
  }

  void _applySchoolFilter() {
    final query = _schoolSearch.text.toLowerCase();
    _filteredSchools =
        _schools.where((s) => s.toLowerCase().contains(query)).toList()..sort();
    setState(() {});
  }

  void _loadProfile(String studentId) {
    _studentProfile = _allStudents.firstWhere(
      (s) => s['student_id'] == studentId,
      orElse: () => {},
    );
  }

  Future<String?> _getphonenumber() async {
    final tempStorage = await SharedPreferences.getInstance();
    return tempStorage.getString("phonenumber");
  }

  Future<void> _submit() async {
    var phoneNumber = await _getphonenumber();
    if (_studentProfile == null) return;
    setState(() => _isLoading = true);
    try {
      final resp = await http
          .post(
            Uri.parse('https://automation.kaascan.com/webhook/add-student'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'phone_number': phoneNumber,
              'student_id': _selectedStudentId,
              'school_name': _selectedSchool,
              'student_name': _studentProfile!['student_name'],
            }),
          )
          .timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        Future.delayed(Duration(milliseconds: 100), () {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => DashboardNav()),
          );
        });

        _showSnack('Umunyeshuri yahujwe na konte yanyu !');
        setState(() {
          _resultMessage = 'Umunyeshuri yahujwe na konte yanyu!';
          _resultIsError = false;
        });
        Navigator.pop(context, true);
      } else {
        if (resp.statusCode == 599) {
          _showSnack('Umunyeshuri asanzwe ahujwe..');
          setState(() {
            _resultMessage = 'Umunyeshuri asanzwe ahujwe..';
            _resultIsError = true;
          });
        } else {
          _showSnack(
            'Error adding student: ${resp.statusCode}. Please try again.',
          );
          setState(() {
            _resultMessage =
                'Error ${resp.statusCode}: Unable to link student right now.';
            _resultIsError = true;
          });
        }
      }
    } catch (e) {
      _showSnack(
        'Network error: Unable to connect. Please check your internet and try again.',
      );
      setState(() {
        _resultMessage =
            'Network error: Unable to connect. Please check your internet and try again.';
        _resultIsError = true;
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        width: MediaQuery.sizeOf(context).width / 0.2,
        height: MediaQuery.sizeOf(context).height / 0.5,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [myColor, Color(0xFF2A53FF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.25),
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 20),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: _isLoading
                    ? Center(
                        child: LoadingAnimationWidget.discreteCircle(
                          // secondRingColor: myOpblue,
                          // thirdRingColor: myColor,
                          color: myColor,
                          size: 50,
                        ),
                      )
                    : _hasError
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('Failed to load data.'),
                            const SizedBox(height: 10),
                            ElevatedButton(
                              onPressed: _loadStudents,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : _buildStep(),
              ),
            ),
            const SizedBox(height: 12),
            _buildResultMessage(),
            const SizedBox(height: 16),
            _buildButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildResultMessage() {
    if (_resultMessage == null) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _resultIsError
            ? warningYellow.withOpacity(0.15)
            : successGreen.withOpacity(0.2),
        border: Border.all(
          color: _resultIsError ? warningYellow : successGreen,
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(
            _resultIsError ? Icons.error_outline : Icons.check_circle_outline,
            color: _resultIsError ? warningYellow : successGreen,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _resultMessage!,
              style: TextStyle(
                color: _resultIsError ? warningYellow : successGreen,
                fontFamily: "gilroy",
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final titles = ['Select School', 'Select Student', 'Confirm Student'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.25),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.add_box, color: Colors.white, size: 30),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titles[_step],
                    style: const TextStyle(
                      fontSize: 24,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.4,
                      fontFamily: "gilroy-light",
                    ),
                  ),
                  Text(
                    'Guiding you through every step for peace of mind.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.85),
                      fontFamily: "gilroy-light",
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        _buildStepIndicator(),
      ],
    );
  }

  Widget _buildStepIndicator() {
    final titles = ['School', 'Student', 'Confirm'];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(3, (index) {
        final completed = _step > index;
        final isActive = _step == index;
        return Expanded(
          child: Column(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: completed || isActive
                      ? Colors.white
                      : Colors.white.withOpacity(0.4),
                ),
                child: Center(
                  child: Icon(
                    completed ? Icons.check : Icons.circle,
                    size: 12,
                    color: completed || isActive
                        ? myColor
                        : const Color.fromARGB(
                            255,
                            255,
                            255,
                            255,
                          ).withOpacity(0.6),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                titles[index],
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.white.withOpacity(0.8),
                  fontFamily: "gilroy",
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildStep() {
    switch (_step) {
      case 0:
        if (_schools.isEmpty) {
          return const Center(child: Text('No schools available.'));
        }
        return Column(
          children: [
            TextField(
              controller: _schoolSearch,
              decoration: InputDecoration(
                labelText: 'Search Schools',
                hintText: 'Type a school name',
                suffixIcon: Icon(Icons.school, color: widget.accentColor),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onChanged: (_) => _applySchoolFilter(),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                itemCount: _filteredSchools.length,
                itemBuilder: (ctx, i) {
                  final school = _filteredSchools[i];
                  final isSelected = _selectedSchool == school;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: GestureDetector(
                      onTap: () {
                        _selectedSchool = school;
                        _selectedStudentId = null;
                        _studentProfile = null;
                        _search.clear();
                        _filteredStudents = [];
                        _applyFilter();
                        setState(() {});
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isSelected ? lightBlue : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSelected
                                ? myColor
                                : Colors.grey.withOpacity(0.2),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 22,
                              backgroundColor: isSelected
                                  ? myColor
                                  : const Color.fromARGB(255, 255, 51, 0),
                              child: Center(
                                child: Text(
                                  school
                                      .split(' ')
                                      .map((w) => w.isNotEmpty ? w[0] : '')
                                      .take(2)
                                      .join(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontFamily: "gilroy-light",
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
                                    school,
                                    style: TextStyle(
                                      fontFamily: "gilroy-light",
                                      fontSize: 16,
                                      color: isSelected ? deepNavy : myColor,
                                      fontWeight: isSelected
                                          ? FontWeight.w700
                                          : FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Tap to connect with the school community',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                      fontFamily: "gilroy-light",
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              isSelected
                                  ? Icons.check_circle
                                  : Icons.chevron_right,
                              color: isSelected ? myColor : Colors.grey,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      case 1:
        return Column(
          children: [
            TextField(
              controller: _search,
              decoration: InputDecoration(
                labelText: 'Search Student',
                labelStyle: TextStyle(
                  color: myColor,
                  fontFamily: "gilroy-light",
                ),
                suffixIcon: Icon(Icons.search, color: widget.accentColor),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onChanged: (_) => _applyFilter(),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: _filteredStudents.isEmpty
                  ? const Center(
                      child: Text('No students found for this school.'),
                    )
                  : ListView.builder(
                      itemCount: _filteredStudents.length,
                      itemBuilder: (ctx, i) {
                        final s = _filteredStudents[i];
                        final studentSelected =
                            _selectedStudentId == s['student_id'];
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: GestureDetector(
                            onTap: () {
                              _selectedStudentId = s['student_id'];
                              _loadProfile(_selectedStudentId!);
                              setState(() {});
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: studentSelected
                                    ? lightBlue
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: studentSelected
                                      ? myColor
                                      : Colors.grey.withOpacity(0.2),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.04),
                                    blurRadius: 6,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 28,
                                    backgroundImage:
                                        s['student_photo_url'] != null
                                        ? CachedNetworkImageProvider(s['student_photo_url'])
                                        : null,
                                    backgroundColor: Colors.grey[200],
                                    onBackgroundImageError: (exception, stackTrace) {
                                      // Fail silently to keep user screen clean
                                    },
                                    child: s['student_photo_url'] == null
                                        ? Text(
                                            s['student_name']
                                                .split(' ')
                                                .where((w) => w.isNotEmpty)
                                                .map((w) => w[0])
                                                .take(2)
                                                .join(),
                                            style: const TextStyle(
                                              color: Colors.black54,
                                              fontWeight: FontWeight.w700,
                                              fontFamily: "gilroy-light",
                                            ),
                                          )
                                        : null,
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          s['student_name'],
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: studentSelected
                                                ? deepNavy
                                                : myColor,
                                            fontFamily: "gilroy-light",
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Grade ${s['grade'] ?? 'N/A'} • ${s['school_name'] ?? ''}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                            fontFamily: "gilroy-light",
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          'Connected on ${DateTime.now().year}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey[500],
                                            fontFamily: "gilroy-light",
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    studentSelected
                                        ? Icons.check_circle
                                        : Icons.arrow_forward_ios,
                                    size: 18,
                                    color: studentSelected
                                        ? myColor
                                        : Colors.grey,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      case 2:
        if (_studentProfile == null || _studentProfile!.isEmpty) {
          return const Center(
            child: Text(
              'No student data available. Please go back and select again.',
            ),
          );
        }
        return SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: () =>
                    _showFullImageDialog(_studentProfile!['student_photo_url']),
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: widget.accentColor, width: 2),
                  ),
                  child: ClipOval(
                    child: _studentProfile!['student_photo_url'] != null
                        ? CachedNetworkImageWrapper(
                            imageUrl: _studentProfile!['student_photo_url'],
                            fit: BoxFit.cover,
                            placeholder: Center(
                              child: LoadingAnimationWidget.discreteCircle(
                                color: myColor,
                                size: 40,
                              ),
                            ),
                            errorWidget: const Icon(Icons.person, size: 100),
                          )
                        : const Icon(Icons.person, size: 100),

                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _studentProfile!['student_name'] ?? 'N/A',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: myColor,
                  fontFamily: "gilroy-light",
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  Chip(
                    label: Text(
                      'Grade ${_studentProfile!['grade'] ?? 'N/A'}',
                      style: const TextStyle(fontFamily: "gilroy-light"),
                    ),
                    backgroundColor: lightBlue.withOpacity(0.4),
                    labelStyle: const TextStyle(color: deepNavy),
                  ),
                  Chip(
                    label: Text(
                      _studentProfile!['school_name'] ?? 'Unknown school',
                      style: const TextStyle(fontFamily: "gilroy-light"),
                    ),
                    backgroundColor: Colors.white,
                    labelStyle: const TextStyle(color: myColor),
                  ),
                  if (_studentProfile!['student_id'] != null)
                    Chip(
                      label: Text(
                        'ID ${_studentProfile!['student_id']}',
                        style: const TextStyle(fontFamily: "gilroy-light"),
                      ),
                      backgroundColor: Colors.white,
                      labelStyle: TextStyle(color: Colors.grey[700]),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                _studentProfile!['school_name'] ?? 'N/A',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: "gilroy-light",
                  color: Colors.green,
                ),
              ),
            ],
          ),
        );
      default:
        return const SizedBox();
    }
  }

  Widget _buildButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        if (_step > 0)
          TextButton(
            style: ButtonStyle(
              backgroundColor: MaterialStateProperty.all<Color>(myOpblue),
            ),
            onPressed: _isLoading ? null : () => setState(() => _step--),
            child: const Text(
              'Back',
              style: TextStyle(color: Colors.white, fontFamily: "gilroy"),
            ),
          ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: widget.accentColor),
          onPressed: _isLoading
              ? null
              : () {
                  if ((_step == 0 && _selectedSchool != null) ||
                      (_step == 1 &&
                          _selectedStudentId != null &&
                          _studentProfile != null)) {
                    setState(() => _step++);
                  } else if (_step == 2 && _studentProfile != null) {
                    _submit();
                  } else {
                    _showSnack('Please select an option to proceed.');
                  }
                },
          child: Text(
            _step == 2 ? 'Add Student' : 'Next',
            style: TextStyle(color: Colors.white, fontFamily: "gilroy-light"),
          ),
        ),
      ],
    );
  }

  void _showFullImageDialog(String? imageUrl) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.9),
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          alignment: Alignment.center,
          children: [
            InteractiveViewer(
              panEnabled: true,
              boundaryMargin: const EdgeInsets.all(20),
              minScale: 0.5,
              maxScale: 4,
              child: imageUrl != null && imageUrl.isNotEmpty
                  ? CachedNetworkImageWrapper(
                      imageUrl: imageUrl,
                      fit: BoxFit.contain,
                      errorWidget: const Icon(Icons.person, size: 100, color: Colors.white),
                    )
                  : const Icon(Icons.person, size: 100, color: Colors.white),
            ),
            Positioned(
              top: 40,
              right: 20,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void openAddStudentDialog(BuildContext context, Color accentColor) {
  showDialog(
    context: context,
    builder: (_) => AddStudentDialog(accentColor: accentColor),
  );
}
