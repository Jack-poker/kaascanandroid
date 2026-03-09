import 'package:flutter/material.dart';
import 'package:kaascan/Auth/login.dart';

class FavoriteStudentsWidget extends StatelessWidget {
  final List<Map<String, dynamic>> students;
  final VoidCallback onAddStudent;
  final Function(int index) onStudentTap;
  final bool showAddButton;

  // Color constants
  static const Color softGray = Color(0xFF9CA3AF);
  static const Color lightBlue = Color(0xFFE6F0FF);
  static const Color softBlue = Color(0xFF3B82F6);
  static const Color darkGray = Color(0xFF374151);
  static const Color mediumGray = Color(0xFF6B7280);
  static const Color primaryBlue = Color.fromARGB(255, 0, 34, 255);
  static const Color pastelBorder = Color(0xFFE0E7FF);

  const FavoriteStudentsWidget({
    Key? key,
    required this.students,
    required this.onAddStudent,
    required this.onStudentTap,
    this.showAddButton = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final cardPadding = screenWidth * 0.04; // 4% of screen width

    return Container(
      padding: EdgeInsets.symmetric(horizontal: cardPadding, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        // boxShadow: [
        //   BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2)),
        // ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // // Section Title
          // Padding(
          //   padding: EdgeInsets.only(left: 4, bottom: 16, top: 8),
          //   child: Text(
          //     'My lecent students',
          //     style: TextStyle(
          //       color: softGray,
          //       fontSize: 12,
          //       fontWeight: FontWeight.w500,
          //       letterSpacing: 1.2,
          //       fontFamily: 'gilroy',
          //     ),
          //   ),
          // ),

          // Horizontal scrollable row
          SizedBox(
            height: 120,
            child: Row(
              children: [
                // Add Button
                if (showAddButton) ...[
                  _buildAddButton(context),
                  SizedBox(width: 12),
                ],

                // Student Avatars
                Expanded(
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: students.length > 3 ? 3 : students.length,
                    itemBuilder: (context, index) {
                      return _buildStudentAvatar(
                        context,
                        students[index],
                        index,
                      );
                    },
                  ),
                ),

                // Right arrow if more than 3 students
                if (students.length > 3)
                  Padding(
                    padding: EdgeInsets.only(left: 8),
                    child: Icon(
                      Icons.chevron_right,
                      color: Colors.orangeAccent,
                      size: 28,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddButton(BuildContext context) {
    return GestureDetector(
      onTap: onAddStudent,
      child: Container(
        width: 80,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Circular container with + icon
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Color.fromARGB(255, 255, 60, 0),
                shape: BoxShape.circle,
                border: Border.all(color: pastelBorder, width: 2),
              ),
              child: Icon(Icons.add, color: myWhite, size: 32),
            ),
            SizedBox(height: 8),
            // "Add" label
            Text(
              'Add',
              style: TextStyle(
                color: mediumGray,
                fontSize: 14,
                fontWeight: FontWeight.w500,
                fontFamily: 'gilroy-light',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentAvatar(
    BuildContext context,
    Map<String, dynamic> student,
    int index,
  ) {
    final studentName = student['student_name'] ?? 'Student';
    final profilePicture = student['profile_picture'];

    // Get first name only
    final firstName = studentName.split(' ').first;
    final displayName = firstName.length > 6
        ? '${firstName.substring(0, 6)}...'
        : firstName;

    return GestureDetector(
      onTap: () => onStudentTap(index),
      child: Container(
        width: 80,
        margin: EdgeInsets.only(right: 12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Avatar with star badge
            Stack(
              clipBehavior: Clip.none,
              children: [
                // Circular avatar
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: pastelBorder, width: 2),
                    image: profilePicture != null
                        ? DecorationImage(
                            image: NetworkImage(profilePicture),
                            fit: BoxFit.cover,
                          )
                        : null,
                    color: profilePicture == null ? lightBlue : null,
                  ),
                  child: profilePicture == null
                      ? Icon(Icons.person, color: softBlue, size: 32)
                      : null,
                ),
                // Star badge
                Positioned(
                  top: -4,
                  right: -4,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: myColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(Icons.star, color: Colors.white, size: 14),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            // Student name
            Text(
              displayName,
              style: TextStyle(
                color: darkGray,
                fontSize: 13,
                fontWeight: FontWeight.w500,
                fontFamily: 'gilroy-light',
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
