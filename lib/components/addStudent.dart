import 'package:ai_barcode_scanner/ai_barcode_scanner.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:http/http.dart' as http;
import 'package:kaascan/dashboard/home.dart';
import 'package:kaascan/onBoradingScreen.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'dart:convert';

import 'package:phone_form_field/phone_form_field.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  List<Map<String, dynamic>> _filteredStudents = [];
  bool _isLoading = false;
  bool _hasError = false;
  final TextEditingController _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadStudents();
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
    "Notice",       // Title of the snackbar
    msg,            // Message content
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
        Navigator.pop(context, true);
      } else {
        if (resp.statusCode == 599) {
          _showSnack('Umunyeshuri asanzwe ahujwe..');
        } else {
          _showSnack(
            'Error adding student: ${resp.statusCode}. Please try again.',
          );
        }
      }
    } catch (e) {
      _showSnack(
        'Network error: Unable to connect. Please check your internet and try again.',
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(20),
        width: 350,
        height: 450,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            _buildHeader(),
            const SizedBox(height: 20),
            Expanded(
              child: _isLoading
                  ? Center(
                      child: LoadingAnimationWidget.discreteCircle(
                        secondRingColor: myOpblue,
                        thirdRingColor: myColor,
                        color: myWhite,
                        size: 40,
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
            const SizedBox(height: 10),
            _buildButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final titles = ['Select School', 'Select Student', 'Confirm Student'];
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.add_box, color: widget.accentColor, size: 36),
        const SizedBox(width: 10),
        Text(
          titles[_step],
          style: TextStyle(
            fontSize: 24,
            color: widget.accentColor,
            fontWeight: FontWeight.w500,
            fontFamily:"gilroy"
          ),
        ),
      ],
    );
  }

  Widget _buildStep() {
    switch (_step) {
      case 0:
        if (_schools.isEmpty) {
          return const Center(child: Text('No schools available.'));
        }
        return ListView.builder(
          itemCount: _schools.length,
          itemBuilder: (ctx, i) {
            final school = _schools[i];
            return ListTile(
              leading: Icon(Icons.check_circle),
              title: Text(
                school,
                style: TextStyle(fontFamily: "gilroy", color: myColor),
              ),
              selected: _selectedSchool == school,
              selectedColor: Colors.amber,

              onTap: () {
                _selectedSchool = school;
                _selectedStudentId = null;
                _studentProfile = null;
                _search.clear();
                _filteredStudents = [];
                _applyFilter();
                setState(() {});
              },
            );
          },
        );
      case 1:
        return Column(
          children: [
            TextField(
              controller: _search,
              decoration: InputDecoration(
                labelText: 'Search Student',
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
                        return ListTile(
                          selectedColor: Colors.orange,
                          leading: CircleAvatar(
                            backgroundImage: s['student_photo_url'] != null
                                ? NetworkImage(s['student_photo_url'])
                                : null,
                            child: s['student_photo_url'] == null
                                ? const Icon(Icons.person)
                                : null,
                          ),
                          title: Text(
                            s['student_name'],
                            style: TextStyle(
                              color: myColor,
                              fontFamily: "gilroy",
                            ),
                          ),
                          subtitle: Text(
                            s['grade'] ?? 'N/A',
                            style: TextStyle(fontFamily: "gilroy"),
                          ),
                          selected: _selectedStudentId == s['student_id'],
                          onTap: () {
                            _selectedStudentId = s['student_id'];
                            _loadProfile(_selectedStudentId!);
                            setState(() {});
                          },
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
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: widget.accentColor, width: 2),
                ),
                child: ClipOval(
                  child: _studentProfile!['student_photo_url'] != null
                      ? Image.network(
                          _studentProfile!['student_photo_url'],
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Center(
                              child: LoadingAnimationWidget.discreteCircle(
                                secondRingColor: myOpblue,
                                thirdRingColor: myColor,
                                color: myWhite,
                                size: 40,
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            return const Icon(Icons.person, size: 100);
                          },
                        )
                      : const Icon(Icons.person, size: 100),
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
                  fontFamily: "gilroy",
                ),
              ),
              Text(
                _studentProfile!['school_name'] ?? 'N/A',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontFamily: "gilroy", color: Colors.green),
              ),
              Text(
                _studentProfile!['student_id'] ?? 'N/A',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontFamily: "gilroy", color: Colors.amber),
              ),
              Text(
                _studentProfile!['grade'] ?? 'N/A',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontFamily: "gilroy", color: myColor),
              ),
              if (_studentProfile!['created_at'] != null)
                Text(
                  'Created: ${_studentProfile!['created_at']}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontFamily: "gilroy", color: myColor),
                ),
              const SizedBox(height: 10),
              Text(
                'Confirm adding this student?',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontFamily: "gilroy", color: Colors.green),
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
            style: TextStyle(color: Colors.white, fontFamily: "gilroy"),
          ),
        ),
      ],
    );
  }
}

void openAddStudentDialog(BuildContext context, Color accentColor) {
  showDialog(
    context: context,
    builder: (_) => AddStudentDialog(accentColor: accentColor),
  );
}
