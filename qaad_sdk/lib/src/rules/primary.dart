import 'dart:math';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class Primary {
  Primary({required this.schoolStudentData, required this.data});
  List<dynamic> data;

  // {
  //   "student_data": { "fullname": "...", "studentid": "..." },
  //   "school_data":  { "school_name": "...", "school_district": "...", ... }
  // }
  Map schoolStudentData;

  Map<dynamic, dynamic> get rules => {
        "school_data": {
          "school_name": schoolStudentData["school_data"]["school_name"],
          "district": schoolStudentData["school_data"]["school_district"],
          "school_code": "786548|",
          "phone": schoolStudentData["school_data"]["school_phonenumber"],
          "head_teacher": schoolStudentData["school_data"]["director_name"],
          "level": {"default": "primary"},
        },
        "primary": [
          {
            "student_data": {
              "names": {
                "first_name": schoolStudentData["student_data"]["fullname"],
                "second_name": "",
                "index_space": "<MEASURE_LENGTH(<firstname>,<second_name>)>",
                "note":
                    "for adding space betweem the names we see the capital letters then we know where the separator need to be",
              },
              "studentid": schoolStudentData["student_data"]["studentid"],
              "data_patterns": ["studentname", "student name", "first name"],
            },
            "student_marks": {
              "conduct_marks": {
                "marks": [
                  LOOK_INDEX(0, "INT"),
                  LOOK_INDEX(1, "INT"),
                  LOOK_INDEX(2, "INT"),
                ],
                "max": 40,
              },
              "subject_marks": {
                "total_terms": 3,
                "subjects_alloc": {
                  // ---------------- KINYARWANDA ----------------
                  "kinyarwanda / Rwanda Sign Language": {
                    "blocks_size": "SUM([<all_terms>][<block_sizes>])",
                    "loc_index": 0,
                    "term_1": {
                      "block_1": [LOOK_INDEX(3, "INT")],
                      "block_2": [LOOK_INDEX(4, "INT")],
                      "block_3": [SUM(LOOK_INDEX(3, "INT"), LOOK_INDEX(4, "INT"))],
                      "block_4": [LOOK_INDEX(5, "INT")],
                      "block_5": [LOOK_INDEX(6, "INT")],
                      "block_6": [SUM(LOOK_INDEX(5, "INT"), LOOK_INDEX(6, "INT"))],
                      "block_7": [
                        PERCENTAGE(
                          SUM(LOOK_INDEX(5, "INT"), LOOK_INDEX(6, "INT")),
                          180,
                        ),
                      ],
                      "block_8": [
                        GRADING_SCALE(
                          PERCENTAGE(
                            SUM(LOOK_INDEX(5, "INT"), LOOK_INDEX(6, "INT")),
                            180,
                          ),
                        ),
                      ],
                      "block_9": [
                        TERM_ANALYSIS(
                          "kinyarwanda / Rwanda Sign Language",
                          1,
                          SUM(LOOK_INDEX(3, "INT"), LOOK_INDEX(4, "INT")),
                          SUM(LOOK_INDEX(5, "INT"), LOOK_INDEX(6, "INT")),
                          schoolStudentData["student_data"],
                          schoolStudentData["school_data"],
                        ),
                      ],
                      "block_10": [
                        DEEP_ANALYSIS(
                          "kinyarwanda / Rwanda Sign Language",
                          1,
                          LOOK_INDEX(3, "INT"),
                          LOOK_INDEX(4, "INT"),
                          LOOK_INDEX(5, "INT"),
                          LOOK_INDEX(6, "INT"),
                          PERCENTAGE(
                            SUM(LOOK_INDEX(5, "INT"), LOOK_INDEX(6, "INT")),
                            180,
                          ),
                          schoolStudentData["student_data"],
                          schoolStudentData["school_data"],
                        ),
                      ],
                    },
                    "term_2": {
                      "block_1": [LOOK_INDEX(7, "INT")],
                      "block_2": [LOOK_INDEX(8, "INT")],
                      "block_3": [SUM(LOOK_INDEX(7, "INT"), LOOK_INDEX(8, "INT"))],
                      "block_4": [LOOK_INDEX(9, "INT")],
                      "block_5": [LOOK_INDEX(10, "INT")],
                      "block_6": [SUM(LOOK_INDEX(9, "INT"), LOOK_INDEX(10, "INT"))],
                      "block_7": [
                        PERCENTAGE(
                          SUM(LOOK_INDEX(9, "INT"), LOOK_INDEX(10, "INT")),
                          180,
                        ),
                      ],
                      "block_8": [
                        GRADING_SCALE(
                          PERCENTAGE(
                            SUM(LOOK_INDEX(9, "INT"), LOOK_INDEX(10, "INT")),
                            180,
                          ),
                        ),
                      ],
                      "block_9": [
                        TERM_ANALYSIS(
                          "kinyarwanda / Rwanda Sign Language",
                          2,
                          SUM(LOOK_INDEX(7, "INT"), LOOK_INDEX(8, "INT")),
                          SUM(LOOK_INDEX(9, "INT"), LOOK_INDEX(10, "INT")),
                          schoolStudentData["student_data"],
                          schoolStudentData["school_data"],
                        ),
                      ],
                      "block_10": [
                        DEEP_ANALYSIS(
                          "kinyarwanda / Rwanda Sign Language",
                          2,
                          LOOK_INDEX(7, "INT"),
                          LOOK_INDEX(8, "INT"),
                          LOOK_INDEX(9, "INT"),
                          LOOK_INDEX(10, "INT"),
                          PERCENTAGE(
                            SUM(LOOK_INDEX(9, "INT"), LOOK_INDEX(10, "INT")),
                            180,
                          ),
                          schoolStudentData["student_data"],
                          schoolStudentData["school_data"],
                        ),
                      ],
                    },
                    "term_3": {
                      "block_1": [LOOK_INDEX(11, "INT")],
                      "block_2": [LOOK_INDEX(12, "INT")],
                      "block_3": [
                        SUM(LOOK_INDEX(11, "INT"), LOOK_INDEX(12, "INT")),
                      ],
                      "block_4": [LOOK_INDEX(13, "INT")],
                      "block_5": [LOOK_INDEX(14, "INT")],
                      "block_6": [
                        SUM(LOOK_INDEX(13, "INT"), LOOK_INDEX(14, "INT")),
                      ],
                      "block_7": [
                        PERCENTAGE(
                          SUM(LOOK_INDEX(13, "INT"), LOOK_INDEX(14, "INT")),
                          180,
                        ),
                      ],
                      "block_8": [
                        GRADING_SCALE(
                          PERCENTAGE(
                            SUM(LOOK_INDEX(13, "INT"), LOOK_INDEX(14, "INT")),
                            180,
                          ),
                        ),
                      ],
                      "block_9": [
                        TERM_ANALYSIS(
                          "kinyarwanda / Rwanda Sign Language",
                          3,
                          SUM(LOOK_INDEX(11, "INT"), LOOK_INDEX(12, "INT")),
                          SUM(LOOK_INDEX(13, "INT"), LOOK_INDEX(14, "INT")),
                          schoolStudentData["student_data"],
                          schoolStudentData["school_data"],
                        ),
                      ],
                      "block_10": [
                        DEEP_ANALYSIS(
                          "kinyarwanda / Rwanda Sign Language",
                          3,
                          LOOK_INDEX(11, "INT"),
                          LOOK_INDEX(12, "INT"),
                          LOOK_INDEX(13, "INT"),
                          LOOK_INDEX(14, "INT"),
                          PERCENTAGE(
                            SUM(LOOK_INDEX(13, "INT"), LOOK_INDEX(14, "INT")),
                            180,
                          ),
                          schoolStudentData["student_data"],
                          schoolStudentData["school_data"],
                        ),
                      ],
                    },
                  },

                  // ---------------- MATHEMATICS ----------------
                  "Mathematics": {
                    "blocks_size": "SUM([<all_terms>][<block_sizes>])",
                    "loc_index": 0,
                    "term_1": {
                      "block_1": [LOOK_INDEX(15, "INT")],
                      "block_2": [LOOK_INDEX(16, "INT")],
                      "block_3": [
                        SUM(LOOK_INDEX(15, "INT"), LOOK_INDEX(16, "INT")),
                      ],
                      "block_4": [LOOK_INDEX(17, "INT")],
                      "block_5": [LOOK_INDEX(18, "INT")],
                      "block_6": [
                        SUM(LOOK_INDEX(17, "INT"), LOOK_INDEX(18, "INT")),
                      ],
                      "block_7": [
                        PERCENTAGE(
                          SUM(LOOK_INDEX(17, "INT"), LOOK_INDEX(18, "INT")),
                          180,
                        ),
                      ],
                      "block_8": [
                        GRADING_SCALE(
                          PERCENTAGE(
                            SUM(LOOK_INDEX(17, "INT"), LOOK_INDEX(18, "INT")),
                            180,
                          ),
                        ),
                      ],
                      "block_9": [
                        TERM_ANALYSIS(
                          "Mathematics",
                          1,
                          SUM(LOOK_INDEX(15, "INT"), LOOK_INDEX(16, "INT")),
                          SUM(LOOK_INDEX(17, "INT"), LOOK_INDEX(18, "INT")),
                          schoolStudentData["student_data"],
                          schoolStudentData["school_data"],
                        ),
                      ],
                      "block_10": [
                        DEEP_ANALYSIS(
                          "Mathematics",
                          1,
                          LOOK_INDEX(15, "INT"),
                          LOOK_INDEX(16, "INT"),
                          LOOK_INDEX(17, "INT"),
                          LOOK_INDEX(18, "INT"),
                          PERCENTAGE(
                            SUM(LOOK_INDEX(17, "INT"), LOOK_INDEX(18, "INT")),
                            180,
                          ),
                          schoolStudentData["student_data"],
                          schoolStudentData["school_data"],
                        ),
                      ],
                    },
                    "term_2": {
                      "block_1": [LOOK_INDEX(19, "INT")],
                      "block_2": [LOOK_INDEX(20, "INT")],
                      "block_3": [
                        SUM(LOOK_INDEX(19, "INT"), LOOK_INDEX(20, "INT")),
                      ],
                      "block_4": [LOOK_INDEX(21, "INT")],
                      "block_5": [LOOK_INDEX(22, "INT")],
                      "block_6": [
                        SUM(LOOK_INDEX(21, "INT"), LOOK_INDEX(22, "INT")),
                      ],
                      "block_7": [
                        PERCENTAGE(
                          SUM(LOOK_INDEX(21, "INT"), LOOK_INDEX(22, "INT")),
                          180,
                        ),
                      ],
                      "block_8": [
                        GRADING_SCALE(
                          PERCENTAGE(
                            SUM(LOOK_INDEX(21, "INT"), LOOK_INDEX(22, "INT")),
                            180,
                          ),
                        ),
                      ],
                      "block_9": [
                        TERM_ANALYSIS(
                          "Mathematics",
                          2,
                          SUM(LOOK_INDEX(19, "INT"), LOOK_INDEX(20, "INT")),
                          SUM(LOOK_INDEX(21, "INT"), LOOK_INDEX(22, "INT")),
                          schoolStudentData["student_data"],
                          schoolStudentData["school_data"],
                        ),
                      ],
                      "block_10": [
                        DEEP_ANALYSIS(
                          "Mathematics",
                          2,
                          LOOK_INDEX(19, "INT"),
                          LOOK_INDEX(20, "INT"),
                          LOOK_INDEX(21, "INT"),
                          LOOK_INDEX(22, "INT"),
                          PERCENTAGE(
                            SUM(LOOK_INDEX(21, "INT"), LOOK_INDEX(22, "INT")),
                            180,
                          ),
                          schoolStudentData["student_data"],
                          schoolStudentData["school_data"],
                        ),
                      ],
                    },
                    "term_3": {
                      "block_1": [LOOK_INDEX(23, "INT")],
                      "block_2": [LOOK_INDEX(24, "INT")],
                      "block_3": [
                        SUM(LOOK_INDEX(23, "INT"), LOOK_INDEX(24, "INT")),
                      ],
                      "block_4": [LOOK_INDEX(25, "INT")],
                      "block_5": [LOOK_INDEX(26, "INT")],
                      "block_6": [
                        SUM(LOOK_INDEX(25, "INT"), LOOK_INDEX(26, "INT")),
                      ],
                      "block_7": [
                        PERCENTAGE(
                          SUM(LOOK_INDEX(25, "INT"), LOOK_INDEX(26, "INT")),
                          180,
                        ),
                      ],
                      "block_8": [
                        GRADING_SCALE(
                          PERCENTAGE(
                            SUM(LOOK_INDEX(25, "INT"), LOOK_INDEX(26, "INT")),
                            180,
                          ),
                        ),
                      ],
                      "block_9": [
                        TERM_ANALYSIS(
                          "Mathematics",
                          3,
                          SUM(LOOK_INDEX(23, "INT"), LOOK_INDEX(24, "INT")),
                          SUM(LOOK_INDEX(25, "INT"), LOOK_INDEX(26, "INT")),
                          schoolStudentData["student_data"],
                          schoolStudentData["school_data"],
                        ),
                      ],
                      "block_10": [
                        DEEP_ANALYSIS(
                          "Mathematics",
                          3,
                          LOOK_INDEX(23, "INT"),
                          LOOK_INDEX(24, "INT"),
                          LOOK_INDEX(25, "INT"),
                          LOOK_INDEX(26, "INT"),
                          PERCENTAGE(
                            SUM(LOOK_INDEX(25, "INT"), LOOK_INDEX(26, "INT")),
                            180,
                          ),
                          schoolStudentData["student_data"],
                          schoolStudentData["school_data"],
                        ),
                      ],
                    },
                  },

                  // ---------------- ENGLISH ----------------
                  "English": {
                    "blocks_size": "SUM([<all_terms>][<block_sizes>])",
                    "loc_index": 0,
                    "term_1": {
                      "block_1": [LOOK_INDEX(27, "INT")],
                      "block_2": [LOOK_INDEX(28, "INT")],
                      "block_3": [
                        SUM(LOOK_INDEX(27, "INT"), LOOK_INDEX(28, "INT")),
                      ],
                      "block_4": [LOOK_INDEX(29, "INT")],
                      "block_5": [LOOK_INDEX(30, "INT")],
                      "block_6": [
                        SUM(LOOK_INDEX(29, "INT"), LOOK_INDEX(30, "INT")),
                      ],
                      "block_7": [
                        PERCENTAGE(
                          SUM(LOOK_INDEX(29, "INT"), LOOK_INDEX(30, "INT")),
                          180,
                        ),
                      ],
                      "block_8": [
                        GRADING_SCALE(
                          PERCENTAGE(
                            SUM(LOOK_INDEX(29, "INT"), LOOK_INDEX(30, "INT")),
                            180,
                          ),
                        ),
                      ],
                      "block_9": [
                        TERM_ANALYSIS(
                          "English",
                          1,
                          SUM(LOOK_INDEX(27, "INT"), LOOK_INDEX(28, "INT")),
                          SUM(LOOK_INDEX(29, "INT"), LOOK_INDEX(30, "INT")),
                          schoolStudentData["student_data"],
                          schoolStudentData["school_data"],
                        ),
                      ],
                      "block_10": [
                        DEEP_ANALYSIS(
                          "English",
                          1,
                          LOOK_INDEX(27, "INT"),
                          LOOK_INDEX(28, "INT"),
                          LOOK_INDEX(29, "INT"),
                          LOOK_INDEX(30, "INT"),
                          PERCENTAGE(
                            SUM(LOOK_INDEX(29, "INT"), LOOK_INDEX(30, "INT")),
                            180,
                          ),
                          schoolStudentData["student_data"],
                          schoolStudentData["school_data"],
                        ),
                      ],
                    },
                    "term_2": {
                      "block_1": [LOOK_INDEX(31, "INT")],
                      "block_2": [LOOK_INDEX(32, "INT")],
                      "block_3": [
                        SUM(LOOK_INDEX(31, "INT"), LOOK_INDEX(32, "INT")),
                      ],
                      "block_4": [LOOK_INDEX(33, "INT")],
                      "block_5": [LOOK_INDEX(34, "INT")],
                      "block_6": [
                        SUM(LOOK_INDEX(33, "INT"), LOOK_INDEX(34, "INT")),
                      ],
                      "block_7": [
                        PERCENTAGE(
                          SUM(LOOK_INDEX(33, "INT"), LOOK_INDEX(34, "INT")),
                          180,
                        ),
                      ],
                      "block_8": [
                        GRADING_SCALE(
                          PERCENTAGE(
                            SUM(LOOK_INDEX(33, "INT"), LOOK_INDEX(34, "INT")),
                            180,
                          ),
                        ),
                      ],
                      "block_9": [
                        TERM_ANALYSIS(
                          "English",
                          2,
                          SUM(LOOK_INDEX(31, "INT"), LOOK_INDEX(32, "INT")),
                          SUM(LOOK_INDEX(33, "INT"), LOOK_INDEX(34, "INT")),
                          schoolStudentData["student_data"],
                          schoolStudentData["school_data"],
                        ),
                      ],
                      "block_10": [
                        DEEP_ANALYSIS(
                          "English",
                          2,
                          LOOK_INDEX(31, "INT"),
                          LOOK_INDEX(32, "INT"),
                          LOOK_INDEX(33, "INT"),
                          LOOK_INDEX(34, "INT"),
                          PERCENTAGE(
                            SUM(LOOK_INDEX(33, "INT"), LOOK_INDEX(34, "INT")),
                            180,
                          ),
                          schoolStudentData["student_data"],
                          schoolStudentData["school_data"],
                        ),
                      ],
                    },
                    "term_3": {
                      "block_1": [LOOK_INDEX(35, "INT")],
                      "block_2": [LOOK_INDEX(36, "INT")],
                      "block_3": [
                        SUM(LOOK_INDEX(35, "INT"), LOOK_INDEX(36, "INT")),
                      ],
                      "block_4": [LOOK_INDEX(37, "INT")],
                      "block_5": [LOOK_INDEX(38, "INT")],
                      "block_6": [
                        SUM(LOOK_INDEX(37, "INT"), LOOK_INDEX(38, "INT")),
                      ],
                      "block_7": [
                        PERCENTAGE(
                          SUM(LOOK_INDEX(37, "INT"), LOOK_INDEX(38, "INT")),
                          180,
                        ),
                      ],
                      "block_8": [
                        GRADING_SCALE(
                          PERCENTAGE(
                            SUM(LOOK_INDEX(37, "INT"), LOOK_INDEX(38, "INT")),
                            180,
                          ),
                        ),
                      ],
                      "block_9": [
                        TERM_ANALYSIS(
                          "English",
                          3,
                          SUM(LOOK_INDEX(35, "INT"), LOOK_INDEX(36, "INT")),
                          SUM(LOOK_INDEX(37, "INT"), LOOK_INDEX(38, "INT")),
                          schoolStudentData["student_data"],
                          schoolStudentData["school_data"],
                        ),
                      ],
                      "block_10": [
                        DEEP_ANALYSIS(
                          "English",
                          3,
                          LOOK_INDEX(35, "INT"),
                          LOOK_INDEX(36, "INT"),
                          LOOK_INDEX(37, "INT"),
                          LOOK_INDEX(38, "INT"),
                          PERCENTAGE(
                            SUM(LOOK_INDEX(37, "INT"), LOOK_INDEX(38, "INT")),
                            180,
                          ),
                          schoolStudentData["student_data"],
                          schoolStudentData["school_data"],
                        ),
                      ],
                    },
                  },

                  // ---------------- FRENCH ----------------
                  "French": {
                    "blocks_size": "SUM([<all_terms>][<block_sizes>])",
                    "loc_index": 0,
                    "term_1": {
                      "block_1": [LOOK_INDEX(39, "INT")],
                      "block_2": [LOOK_INDEX(40, "INT")],
                      "block_3": [
                        SUM(LOOK_INDEX(39, "INT"), LOOK_INDEX(40, "INT")),
                      ],
                      "block_4": [LOOK_INDEX(41, "INT")],
                      "block_5": [LOOK_INDEX(42, "INT")],
                      "block_6": [
                        SUM(LOOK_INDEX(41, "INT"), LOOK_INDEX(42, "INT")),
                      ],
                      "block_7": [
                        PERCENTAGE(
                          SUM(LOOK_INDEX(41, "INT"), LOOK_INDEX(42, "INT")),
                          100,
                        ),
                      ],
                      "block_8": [
                        GRADING_SCALE(
                          PERCENTAGE(
                            SUM(LOOK_INDEX(41, "INT"), LOOK_INDEX(42, "INT")),
                            100,
                          ),
                        ),
                      ],
                      "block_9": [
                        TERM_ANALYSIS(
                          "French",
                          1,
                          SUM(LOOK_INDEX(39, "INT"), LOOK_INDEX(40, "INT")),
                          SUM(LOOK_INDEX(41, "INT"), LOOK_INDEX(42, "INT")),
                          schoolStudentData["student_data"],
                          schoolStudentData["school_data"],
                        ),
                      ],
                      "block_10": [
                        DEEP_ANALYSIS(
                          "French",
                          1,
                          LOOK_INDEX(39, "INT"),
                          LOOK_INDEX(40, "INT"),
                          LOOK_INDEX(41, "INT"),
                          LOOK_INDEX(42, "INT"),
                          PERCENTAGE(
                            SUM(LOOK_INDEX(41, "INT"), LOOK_INDEX(42, "INT")),
                            100,
                          ),
                          schoolStudentData["student_data"],
                          schoolStudentData["school_data"],
                        ),
                      ],
                    },
                    "term_2": {
                      "block_1": [LOOK_INDEX(43, "INT")],
                      "block_2": [LOOK_INDEX(44, "INT")],
                      "block_3": [
                        SUM(LOOK_INDEX(43, "INT"), LOOK_INDEX(44, "INT")),
                      ],
                      "block_4": [LOOK_INDEX(45, "INT")],
                      "block_5": [LOOK_INDEX(46, "INT")],
                      "block_6": [
                        SUM(LOOK_INDEX(45, "INT"), LOOK_INDEX(46, "INT")),
                      ],
                      "block_7": [
                        PERCENTAGE(
                          SUM(LOOK_INDEX(45, "INT"), LOOK_INDEX(46, "INT")),
                          100,
                        ),
                      ],
                      "block_8": [
                        GRADING_SCALE(
                          PERCENTAGE(
                            SUM(LOOK_INDEX(45, "INT"), LOOK_INDEX(46, "INT")),
                            100,
                          ),
                        ),
                      ],
                      "block_9": [
                        TERM_ANALYSIS(
                          "French",
                          2,
                          SUM(LOOK_INDEX(43, "INT"), LOOK_INDEX(44, "INT")),
                          SUM(LOOK_INDEX(45, "INT"), LOOK_INDEX(46, "INT")),
                          schoolStudentData["student_data"],
                          schoolStudentData["school_data"],
                        ),
                      ],
                      "block_10": [
                        DEEP_ANALYSIS(
                          "French",
                          2,
                          LOOK_INDEX(43, "INT"),
                          LOOK_INDEX(44, "INT"),
                          LOOK_INDEX(45, "INT"),
                          LOOK_INDEX(46, "INT"),
                          PERCENTAGE(
                            SUM(LOOK_INDEX(45, "INT"), LOOK_INDEX(46, "INT")),
                            100,
                          ),
                          schoolStudentData["student_data"],
                          schoolStudentData["school_data"],
                        ),
                      ],
                    },
                    "term_3": {
                      "block_1": [LOOK_INDEX(47, "INT")],
                      "block_2": [LOOK_INDEX(48, "INT")],
                      "block_3": [
                        SUM(LOOK_INDEX(47, "INT"), LOOK_INDEX(48, "INT")),
                      ],
                      "block_4": [LOOK_INDEX(49, "INT")],
                      "block_5": [LOOK_INDEX(50, "INT")],
                      "block_6": [
                        SUM(LOOK_INDEX(49, "INT"), LOOK_INDEX(50, "INT")),
                      ],
                      "block_7": [
                        PERCENTAGE(
                          SUM(LOOK_INDEX(49, "INT"), LOOK_INDEX(50, "INT")),
                          100,
                        ),
                      ],
                      "block_8": [
                        GRADING_SCALE(
                          PERCENTAGE(
                            SUM(LOOK_INDEX(49, "INT"), LOOK_INDEX(50, "INT")),
                            100,
                          ),
                        ),
                      ],
                      "block_9": [
                        TERM_ANALYSIS(
                          "French",
                          3,
                          SUM(LOOK_INDEX(47, "INT"), LOOK_INDEX(48, "INT")),
                          SUM(LOOK_INDEX(49, "INT"), LOOK_INDEX(50, "INT")),
                          schoolStudentData["student_data"],
                          schoolStudentData["school_data"],
                        ),
                      ],
                      "block_10": [
                        DEEP_ANALYSIS(
                          "French",
                          3,
                          LOOK_INDEX(47, "INT"),
                          LOOK_INDEX(48, "INT"),
                          LOOK_INDEX(49, "INT"),
                          LOOK_INDEX(50, "INT"),
                          PERCENTAGE(
                            SUM(LOOK_INDEX(49, "INT"), LOOK_INDEX(50, "INT")),
                            100,
                          ),
                          schoolStudentData["student_data"],
                          schoolStudentData["school_data"],
                        ),
                      ],
                    },
                  },

                  // ---------------- SOCIAL STUDIES ----------------
                  "Social Studies and Religious Education": {
                    "blocks_size": "SUM([<all_terms>][<block_sizes>])",
                    "loc_index": 0,
                    "term_1": {
                      "block_1": [LOOK_INDEX(51, "INT")],
                      "block_2": [LOOK_INDEX(52, "INT")],
                      "block_3": [
                        SUM(LOOK_INDEX(51, "INT"), LOOK_INDEX(52, "INT")),
                      ],
                      "block_4": [LOOK_INDEX(53, "INT")],
                      "block_5": [LOOK_INDEX(54, "INT")],
                      "block_6": [
                        SUM(LOOK_INDEX(53, "INT"), LOOK_INDEX(54, "INT")),
                      ],
                      "block_7": [
                        PERCENTAGE(
                          SUM(LOOK_INDEX(53, "INT"), LOOK_INDEX(54, "INT")),
                          100,
                        ),
                      ],
                      "block_8": [
                        GRADING_SCALE(
                          PERCENTAGE(
                            SUM(LOOK_INDEX(53, "INT"), LOOK_INDEX(54, "INT")),
                            100,
                          ),
                        ),
                      ],
                      "block_9": [
                        TERM_ANALYSIS(
                          "Social Studies and Religious Education",
                          1,
                          SUM(LOOK_INDEX(51, "INT"), LOOK_INDEX(52, "INT")),
                          SUM(LOOK_INDEX(53, "INT"), LOOK_INDEX(54, "INT")),
                          schoolStudentData["student_data"],
                          schoolStudentData["school_data"],
                        ),
                      ],
                      "block_10": [
                        DEEP_ANALYSIS(
                          "Social Studies and Religious Education",
                          1,
                          LOOK_INDEX(51, "INT"),
                          LOOK_INDEX(52, "INT"),
                          LOOK_INDEX(53, "INT"),
                          LOOK_INDEX(54, "INT"),
                          PERCENTAGE(
                            SUM(LOOK_INDEX(53, "INT"), LOOK_INDEX(54, "INT")),
                            100,
                          ),
                          schoolStudentData["student_data"],
                          schoolStudentData["school_data"],
                        ),
                      ],
                    },
                    "term_2": {
                      "block_1": [LOOK_INDEX(55, "INT")],
                      "block_2": [LOOK_INDEX(56, "INT")],
                      "block_3": [
                        SUM(LOOK_INDEX(55, "INT"), LOOK_INDEX(56, "INT")),
                      ],
                      "block_4": [LOOK_INDEX(57, "INT")],
                      "block_5": [LOOK_INDEX(58, "INT")],
                      "block_6": [
                        SUM(LOOK_INDEX(57, "INT"), LOOK_INDEX(58, "INT")),
                      ],
                      "block_7": [
                        PERCENTAGE(
                          SUM(LOOK_INDEX(57, "INT"), LOOK_INDEX(58, "INT")),
                          100,
                        ),
                      ],
                      "block_8": [
                        GRADING_SCALE(
                          PERCENTAGE(
                            SUM(LOOK_INDEX(57, "INT"), LOOK_INDEX(58, "INT")),
                            100,
                          ),
                        ),
                      ],
                      "block_9": [
                        TERM_ANALYSIS(
                          "Social Studies and Religious Education",
                          2,
                          SUM(LOOK_INDEX(55, "INT"), LOOK_INDEX(56, "INT")),
                          SUM(LOOK_INDEX(57, "INT"), LOOK_INDEX(58, "INT")),
                          schoolStudentData["student_data"],
                          schoolStudentData["school_data"],
                        ),
                      ],
                      "block_10": [
                        DEEP_ANALYSIS(
                          "Social Studies and Religious Education",
                          2,
                          LOOK_INDEX(55, "INT"),
                          LOOK_INDEX(56, "INT"),
                          LOOK_INDEX(57, "INT"),
                          LOOK_INDEX(58, "INT"),
                          PERCENTAGE(
                            SUM(LOOK_INDEX(57, "INT"), LOOK_INDEX(58, "INT")),
                            100,
                          ),
                          schoolStudentData["student_data"],
                          schoolStudentData["school_data"],
                        ),
                      ],
                    },
                    "term_3": {
                      "block_1": [LOOK_INDEX(59, "INT")],
                      "block_2": [LOOK_INDEX(60, "INT")],
                      "block_3": [
                        SUM(LOOK_INDEX(59, "INT"), LOOK_INDEX(60, "INT")),
                      ],
                      "block_4": [LOOK_INDEX(61, "INT")],
                      "block_5": [LOOK_INDEX(62, "INT")],
                      "block_6": [
                        SUM(LOOK_INDEX(61, "INT"), LOOK_INDEX(62, "INT")),
                      ],
                      "block_7": [
                        PERCENTAGE(
                          SUM(LOOK_INDEX(61, "INT"), LOOK_INDEX(62, "INT")),
                          100,
                        ),
                      ],
                      "block_8": [
                        GRADING_SCALE(
                          PERCENTAGE(
                            SUM(LOOK_INDEX(61, "INT"), LOOK_INDEX(62, "INT")),
                            100,
                          ),
                        ),
                      ],
                      "block_9": [
                        TERM_ANALYSIS(
                          "Social Studies and Religious Education",
                          3,
                          SUM(LOOK_INDEX(59, "INT"), LOOK_INDEX(60, "INT")),
                          SUM(LOOK_INDEX(61, "INT"), LOOK_INDEX(62, "INT")),
                          schoolStudentData["student_data"],
                          schoolStudentData["school_data"],
                        ),
                      ],
                      "block_10": [
                        DEEP_ANALYSIS(
                          "Social Studies and Religious Education",
                          3,
                          LOOK_INDEX(59, "INT"),
                          LOOK_INDEX(60, "INT"),
                          LOOK_INDEX(61, "INT"),
                          LOOK_INDEX(62, "INT"),
                          PERCENTAGE(
                            SUM(LOOK_INDEX(61, "INT"), LOOK_INDEX(62, "INT")),
                            100,
                          ),
                          schoolStudentData["student_data"],
                          schoolStudentData["school_data"],
                        ),
                      ],
                    },
                  },

                  // ---------------- SCIENCE ----------------
                  "Science and Elementary Technology": {
                    "blocks_size": "SUM([<all_terms>][<block_sizes>])",
                    "loc_index": 0,
                    "term_1": {
                      "block_1": [LOOK_INDEX(63, "INT")],
                      "block_2": [LOOK_INDEX(64, "INT")],
                      "block_3": [
                        SUM(LOOK_INDEX(63, "INT"), LOOK_INDEX(64, "INT")),
                      ],
                      "block_4": [LOOK_INDEX(65, "INT")],
                      "block_5": [LOOK_INDEX(66, "INT")],
                      "block_6": [
                        SUM(LOOK_INDEX(65, "INT"), LOOK_INDEX(66, "INT")),
                      ],
                      "block_7": [
                        PERCENTAGE(
                          SUM(LOOK_INDEX(65, "INT"), LOOK_INDEX(66, "INT")),
                          100,
                        ),
                      ],
                      "block_8": [
                        GRADING_SCALE(
                          PERCENTAGE(
                            SUM(LOOK_INDEX(65, "INT"), LOOK_INDEX(66, "INT")),
                            100,
                          ),
                        ),
                      ],
                      "block_9": [
                        TERM_ANALYSIS(
                          "Science and Elementary Technology",
                          1,
                          SUM(LOOK_INDEX(63, "INT"), LOOK_INDEX(64, "INT")),
                          SUM(LOOK_INDEX(65, "INT"), LOOK_INDEX(66, "INT")),
                          schoolStudentData["student_data"],
                          schoolStudentData["school_data"],
                        ),
                      ],
                      "block_10": [
                        DEEP_ANALYSIS(
                          "Science and Elementary Technology",
                          1,
                          LOOK_INDEX(63, "INT"),
                          LOOK_INDEX(64, "INT"),
                          LOOK_INDEX(65, "INT"),
                          LOOK_INDEX(66, "INT"),
                          PERCENTAGE(
                            SUM(LOOK_INDEX(65, "INT"), LOOK_INDEX(66, "INT")),
                            100,
                          ),
                          schoolStudentData["student_data"],
                          schoolStudentData["school_data"],
                        ),
                      ],
                    },
                    "term_2": {
                      "block_1": [LOOK_INDEX(67, "INT")],
                      "block_2": [LOOK_INDEX(68, "INT")],
                      "block_3": [
                        SUM(LOOK_INDEX(67, "INT"), LOOK_INDEX(68, "INT")),
                      ],
                      "block_4": [LOOK_INDEX(69, "INT")],
                      "block_5": [LOOK_INDEX(70, "INT")],
                      "block_6": [
                        SUM(LOOK_INDEX(69, "INT"), LOOK_INDEX(70, "INT")),
                      ],
                      "block_7": [
                        PERCENTAGE(
                          SUM(LOOK_INDEX(69, "INT"), LOOK_INDEX(70, "INT")),
                          100,
                        ),
                      ],
                      "block_8": [
                        GRADING_SCALE(
                          PERCENTAGE(
                            SUM(LOOK_INDEX(69, "INT"), LOOK_INDEX(70, "INT")),
                            100,
                          ),
                        ),
                      ],
                      "block_9": [
                        TERM_ANALYSIS(
                          "Science and Elementary Technology",
                          2,
                          SUM(LOOK_INDEX(67, "INT"), LOOK_INDEX(68, "INT")),
                          SUM(LOOK_INDEX(69, "INT"), LOOK_INDEX(70, "INT")),
                          schoolStudentData["student_data"],
                          schoolStudentData["school_data"],
                        ),
                      ],
                      "block_10": [
                        DEEP_ANALYSIS(
                          "Science and Elementary Technology",
                          2,
                          LOOK_INDEX(67, "INT"),
                          LOOK_INDEX(68, "INT"),
                          LOOK_INDEX(69, "INT"),
                          LOOK_INDEX(70, "INT"),
                          PERCENTAGE(
                            SUM(LOOK_INDEX(69, "INT"), LOOK_INDEX(70, "INT")),
                            100,
                          ),
                          schoolStudentData["student_data"],
                          schoolStudentData["school_data"],
                        ),
                      ],
                    },
                    "term_3": {
                      "block_1": [LOOK_INDEX(71, "INT")],
                      "block_2": [LOOK_INDEX(72, "INT")],
                      "block_3": [
                        SUM(LOOK_INDEX(71, "INT"), LOOK_INDEX(72, "INT")),
                      ],
                      "block_4": [LOOK_INDEX(73, "INT")],
                      "block_5": [LOOK_INDEX(74, "INT")],
                      "block_6": [
                        SUM(LOOK_INDEX(73, "INT"), LOOK_INDEX(74, "INT")),
                      ],
                      "block_7": [
                        PERCENTAGE(
                          SUM(LOOK_INDEX(73, "INT"), LOOK_INDEX(74, "INT")),
                          100,
                        ),
                      ],
                      "block_8": [
                        GRADING_SCALE(
                          PERCENTAGE(
                            SUM(LOOK_INDEX(73, "INT"), LOOK_INDEX(74, "INT")),
                            100,
                          ),
                        ),
                      ],
                      "block_9": [
                        TERM_ANALYSIS(
                          "Science and Elementary Technology",
                          3,
                          SUM(LOOK_INDEX(71, "INT"), LOOK_INDEX(72, "INT")),
                          SUM(LOOK_INDEX(73, "INT"), LOOK_INDEX(74, "INT")),
                          schoolStudentData["student_data"],
                          schoolStudentData["school_data"],
                        ),
                      ],
                      "block_10": [
                        DEEP_ANALYSIS(
                          "Science and Elementary Technology",
                          3,
                          LOOK_INDEX(71, "INT"),
                          LOOK_INDEX(72, "INT"),
                          LOOK_INDEX(73, "INT"),
                          LOOK_INDEX(74, "INT"),
                          PERCENTAGE(
                            SUM(LOOK_INDEX(73, "INT"), LOOK_INDEX(74, "INT")),
                            100,
                          ),
                          schoolStudentData["student_data"],
                          schoolStudentData["school_data"],
                        ),
                      ],
                    },
                  },

                  // ---------------- PE ----------------
                  "Physical Education and Sports": {
                    "blocks_size": "SUM([<all_terms>][<block_sizes>])",
                    "loc_index": 0,
                    "term_1": {
                      "block_1": [LOOK_INDEX(75, "INT")],
                      "block_2": [LOOK_INDEX(76, "INT")],
                      "block_3": [
                        SUM(LOOK_INDEX(75, "INT"), LOOK_INDEX(76, "INT")),
                      ],
                      "block_4": [LOOK_INDEX(77, "INT")],
                      "block_5": [LOOK_INDEX(78, "INT")],
                      "block_6": [
                        SUM(LOOK_INDEX(77, "INT"), LOOK_INDEX(78, "INT")),
                      ],
                      "block_7": [
                        PERCENTAGE(
                          SUM(LOOK_INDEX(77, "INT"), LOOK_INDEX(78, "INT")),
                          40,
                        ),
                      ],
                      "block_8": [
                        GRADING_SCALE(
                          PERCENTAGE(
                            SUM(LOOK_INDEX(77, "INT"), LOOK_INDEX(78, "INT")),
                            40,
                          ),
                        ),
                      ],
                      "block_9": [
                        TERM_ANALYSIS(
                          "Physical Education and Sports",
                          1,
                          SUM(LOOK_INDEX(75, "INT"), LOOK_INDEX(76, "INT")),
                          SUM(LOOK_INDEX(77, "INT"), LOOK_INDEX(78, "INT")),
                          schoolStudentData["student_data"],
                          schoolStudentData["school_data"],
                        ),
                      ],
                      "block_10": [
                        DEEP_ANALYSIS(
                          "Physical Education and Sports",
                          1,
                          LOOK_INDEX(75, "INT"),
                          LOOK_INDEX(76, "INT"),
                          LOOK_INDEX(77, "INT"),
                          LOOK_INDEX(78, "INT"),
                          PERCENTAGE(
                            SUM(LOOK_INDEX(77, "INT"), LOOK_INDEX(78, "INT")),
                            40,
                          ),
                          schoolStudentData["student_data"],
                          schoolStudentData["school_data"],
                        ),
                      ],
                    },
                    "term_2": {
                      "block_1": [LOOK_INDEX(79, "INT")],
                      "block_2": [LOOK_INDEX(80, "INT")],
                      "block_3": [
                        SUM(LOOK_INDEX(79, "INT"), LOOK_INDEX(80, "INT")),
                      ],
                      "block_4": [LOOK_INDEX(81, "INT")],
                      "block_5": [LOOK_INDEX(82, "INT")],
                      "block_6": [
                        SUM(LOOK_INDEX(81, "INT"), LOOK_INDEX(82, "INT")),
                      ],
                      "block_7": [
                        PERCENTAGE(
                          SUM(LOOK_INDEX(81, "INT"), LOOK_INDEX(82, "INT")),
                          40,
                        ),
                      ],
                      "block_8": [
                        GRADING_SCALE(
                          PERCENTAGE(
                            SUM(LOOK_INDEX(81, "INT"), LOOK_INDEX(82, "INT")),
                            40,
                          ),
                        ),
                      ],
                      "block_9": [
                        TERM_ANALYSIS(
                          "Physical Education and Sports",
                          2,
                          SUM(LOOK_INDEX(79, "INT"), LOOK_INDEX(80, "INT")),
                          SUM(LOOK_INDEX(81, "INT"), LOOK_INDEX(82, "INT")),
                          schoolStudentData["student_data"],
                          schoolStudentData["school_data"],
                        ),
                      ],
                      "block_10": [
                        DEEP_ANALYSIS(
                          "Physical Education and Sports",
                          2,
                          LOOK_INDEX(79, "INT"),
                          LOOK_INDEX(80, "INT"),
                          LOOK_INDEX(81, "INT"),
                          LOOK_INDEX(82, "INT"),
                          PERCENTAGE(
                            SUM(LOOK_INDEX(81, "INT"), LOOK_INDEX(82, "INT")),
                            40,
                          ),
                          schoolStudentData["student_data"],
                          schoolStudentData["school_data"],
                        ),
                      ],
                    },
                    "term_3": {
                      "block_1": [LOOK_INDEX(83, "INT")],
                      "block_2": [LOOK_INDEX(84, "INT")],
                      "block_3": [
                        SUM(LOOK_INDEX(83, "INT"), LOOK_INDEX(84, "INT")),
                      ],
                      "block_4": [LOOK_INDEX(85, "INT")],
                      "block_5": [LOOK_INDEX(86, "INT")],
                      "block_6": [
                        SUM(LOOK_INDEX(85, "INT"), LOOK_INDEX(86, "INT")),
                      ],
                      "block_7": [
                        PERCENTAGE(
                          SUM(LOOK_INDEX(85, "INT"), LOOK_INDEX(86, "INT")),
                          40,
                        ),
                      ],
                      "block_8": [
                        GRADING_SCALE(
                          PERCENTAGE(
                            SUM(LOOK_INDEX(85, "INT"), LOOK_INDEX(86, "INT")),
                            40,
                          ),
                        ),
                      ],
                      "block_9": [
                        TERM_ANALYSIS(
                          "Physical Education and Sports",
                          3,
                          SUM(LOOK_INDEX(83, "INT"), LOOK_INDEX(84, "INT")),
                          SUM(LOOK_INDEX(85, "INT"), LOOK_INDEX(86, "INT")),
                          schoolStudentData["student_data"],
                          schoolStudentData["school_data"],
                        ),
                      ],
                      "block_10": [
                        DEEP_ANALYSIS(
                          "Physical Education and Sports",
                          3,
                          LOOK_INDEX(83, "INT"),
                          LOOK_INDEX(84, "INT"),
                          LOOK_INDEX(85, "INT"),
                          LOOK_INDEX(86, "INT"),
                          PERCENTAGE(
                            SUM(LOOK_INDEX(85, "INT"), LOOK_INDEX(86, "INT")),
                            40,
                          ),
                          schoolStudentData["student_data"],
                          schoolStudentData["school_data"],
                        ),
                      ],
                    },
                  },

                  // ---------------- CREATIVE ARTS ----------------
                  "Creative Arts (Fine Art and Music)": {
                    "blocks_size": "SUM([<all_terms>][<block_sizes>])",
                    "loc_index": 0,
                    "term_1": {
                      "block_1": [LOOK_INDEX(87, "INT")],
                      "block_2": [LOOK_INDEX(88, "INT")],
                      "block_3": [
                        SUM(LOOK_INDEX(87, "INT"), LOOK_INDEX(88, "INT")),
                      ],
                      "block_4": [LOOK_INDEX(89, "INT")],
                      "block_5": [LOOK_INDEX(90, "INT")],
                      "block_6": [
                        SUM(LOOK_INDEX(89, "INT"), LOOK_INDEX(90, "INT")),
                      ],
                      "block_7": [
                        PERCENTAGE(
                          SUM(LOOK_INDEX(89, "INT"), LOOK_INDEX(90, "INT")),
                          40,
                        ),
                      ],
                      "block_8": [
                        GRADING_SCALE(
                          PERCENTAGE(
                            SUM(LOOK_INDEX(89, "INT"), LOOK_INDEX(90, "INT")),
                            40,
                          ),
                        ),
                      ],
                      "block_9": [
                        TERM_ANALYSIS(
                          "Creative Arts (Fine Art and Music)",
                          1,
                          SUM(LOOK_INDEX(87, "INT"), LOOK_INDEX(88, "INT")),
                          SUM(LOOK_INDEX(89, "INT"), LOOK_INDEX(90, "INT")),
                          schoolStudentData["student_data"],
                          schoolStudentData["school_data"],
                        ),
                      ],
                      "block_10": [
                        DEEP_ANALYSIS(
                          "Creative Arts (Fine Art and Music)",
                          1,
                          LOOK_INDEX(87, "INT"),
                          LOOK_INDEX(88, "INT"),
                          LOOK_INDEX(89, "INT"),
                          LOOK_INDEX(90, "INT"),
                          PERCENTAGE(
                            SUM(LOOK_INDEX(89, "INT"), LOOK_INDEX(90, "INT")),
                            40,
                          ),
                          schoolStudentData["student_data"],
                          schoolStudentData["school_data"],
                        ),
                      ],
                    },
                    "term_2": {
                      "block_1": [LOOK_INDEX(91, "INT")],
                      "block_2": [LOOK_INDEX(92, "INT")],
                      "block_3": [
                        SUM(LOOK_INDEX(91, "INT"), LOOK_INDEX(92, "INT")),
                      ],
                      "block_4": [LOOK_INDEX(93, "INT")],
                      "block_5": [LOOK_INDEX(94, "INT")],
                      "block_6": [
                        SUM(LOOK_INDEX(93, "INT"), LOOK_INDEX(94, "INT")),
                      ],
                      "block_7": [
                        PERCENTAGE(
                          SUM(LOOK_INDEX(93, "INT"), LOOK_INDEX(94, "INT")),
                          40,
                        ),
                      ],
                      "block_8": [
                        GRADING_SCALE(
                          PERCENTAGE(
                            SUM(LOOK_INDEX(93, "INT"), LOOK_INDEX(94, "INT")),
                            40,
                          ),
                        ),
                      ],
                      "block_9": [
                        TERM_ANALYSIS(
                          "Creative Arts (Fine Art and Music)",
                          2,
                          SUM(LOOK_INDEX(91, "INT"), LOOK_INDEX(92, "INT")),
                          SUM(LOOK_INDEX(93, "INT"), LOOK_INDEX(94, "INT")),
                          schoolStudentData["student_data"],
                          schoolStudentData["school_data"],
                        ),
                      ],
                      "block_10": [
                        DEEP_ANALYSIS(
                          "Creative Arts (Fine Art and Music)",
                          2,
                          LOOK_INDEX(91, "INT"),
                          LOOK_INDEX(92, "INT"),
                          LOOK_INDEX(93, "INT"),
                          LOOK_INDEX(94, "INT"),
                          PERCENTAGE(
                            SUM(LOOK_INDEX(93, "INT"), LOOK_INDEX(94, "INT")),
                            40,
                          ),
                          schoolStudentData["student_data"],
                          schoolStudentData["school_data"],
                        ),
                      ],
                    },
                    "term_3": {
                      "block_1": [LOOK_INDEX(95, "INT")],
                      "block_2": [LOOK_INDEX(96, "INT")],
                      "block_3": [
                        SUM(LOOK_INDEX(95, "INT"), LOOK_INDEX(96, "INT")),
                      ],
                      "block_4": [LOOK_INDEX(97, "INT")],
                      "block_5": [LOOK_INDEX(98, "INT")],
                      "block_6": [
                        SUM(LOOK_INDEX(97, "INT"), LOOK_INDEX(98, "INT")),
                      ],
                      "block_7": [
                        PERCENTAGE(
                          SUM(LOOK_INDEX(97, "INT"), LOOK_INDEX(98, "INT")),
                          40,
                        ),
                      ],
                      "block_8": [
                        GRADING_SCALE(
                          PERCENTAGE(
                            SUM(LOOK_INDEX(97, "INT"), LOOK_INDEX(98, "INT")),
                            40,
                          ),
                        ),
                      ],
                      "block_9": [
                        TERM_ANALYSIS(
                          "Creative Arts (Fine Art and Music)",
                          3,
                          SUM(LOOK_INDEX(95, "INT"), LOOK_INDEX(96, "INT")),
                          SUM(LOOK_INDEX(97, "INT"), LOOK_INDEX(98, "INT")),
                          schoolStudentData["student_data"],
                          schoolStudentData["school_data"],
                        ),
                      ],
                      "block_10": [
                        DEEP_ANALYSIS(
                          "Creative Arts (Fine Art and Music)",
                          3,
                          LOOK_INDEX(95, "INT"),
                          LOOK_INDEX(96, "INT"),
                          LOOK_INDEX(97, "INT"),
                          LOOK_INDEX(98, "INT"),
                          PERCENTAGE(
                            SUM(LOOK_INDEX(97, "INT"), LOOK_INDEX(98, "INT")),
                            40,
                          ),
                          schoolStudentData["student_data"],
                          schoolStudentData["school_data"],
                        ),
                      ],
                    },
                  },
                },
              },
            },
          },
        ],
        "security_data": {},
      };

  // ---------------------------------------------------------
  // MATH PRIMITIVES
  // ---------------------------------------------------------
  // ignore: non_constant_identifier_names
  int LOOK_INDEX(int index, String type) {
    if (index >= data.length) return 0;
    return data[index];
  }

  // ignore: non_constant_identifier_names
  int SUM(int value1, int value2) {
    return value1 + value2;
  }

  // ignore: non_constant_identifier_names
  String PERCENTAGE(int total, int max) {
    if (max == 0) return "0%";
    double percentage = (total / max) * 100;
    return "${percentage.toStringAsFixed(1)}%";
  }

  // ignore: non_constant_identifier_names
  String GRADING_SCALE(String percentageStr) {
    String cleanStr = percentageStr.replaceAll("%", "");
    double percentage = double.tryParse(cleanStr) ?? 0.0;

    if (percentage >= 80) return "A";
    if (percentage >= 75) return "B";
    if (percentage >= 70) return "C";
    if (percentage >= 65) return "D";
    if (percentage >= 60) return "E";
    if (percentage >= 50) return "S";
    return "F";
  }

  // ---------------------------------------------------------
  // KINYARWANDA ANALYSIS ENGINE
  // ---------------------------------------------------------
  static final Random _feedbackRandom = Random();

  // ignore: non_constant_identifier_names
  String TERM_ANALYSIS(
    String subjectName,
    int termNumber,
    int euTotal,
    int etTotal,
    Map studentData,
    Map schoolData,
  ) {
    final String name = _studentName(studentData);
    final String school = _schoolName(schoolData);
    final String subject = _getKinyarwandaSubjectName(subjectName);

    final List<String> openings = [
      'Nkurikije uko $name yitwaye mu isomo rya $subject, hari ibyo twishimira n’ibyo yakomeza kunoza.',
      'Ku bijyanye n’isomo rya $subject, ndabona $name afite intambwe amaze gutera n’aho akeneye gukomeza gushyira imbaraga.',
      'Mubyeyi, reka turebere hamwe uko $name yitwaye mu isomo rya $subject muri iki gihembwe.',
      'Ibyavuye mu isuzuma rya $name mu isomo rya $subject bidufasha kureba aho ageze n’uko twamufasha gukomeza.',
      'Mu isomo rya $subject, ni byiza kureba amanota ya $name nk’uburyo bwo kumenya aho akeneye gushyigikirwa.',
    ];

    final String opening = openings[_feedbackRandom.nextInt(openings.length)];

    return '''
Muraho neza, mubyeyi wa $name.

$opening

Mu gihembwe cya $termNumber, ku ishuri rya $school, dukomeze gufatanya kugira ngo $name arusheho gusobanukirwa ibyo yiga. Kumutera umwete no kumufasha gusubiramo amasomo bishobora kumugirira akamaro.

Ese wifuza ko ngusobanurira mu buryo burambuye uko yitwaye n'ibyo wamufasha kunoza?
''';
  }

  // ignore: non_constant_identifier_names
  String DEEP_ANALYSIS(
    String subjectName,
    int termNumber,
    int block1,
    int block2,
    int block4,
    int block5,
    String percentage,
    Map studentData,
    Map schoolData,
  ) {
    final String name = _studentName(studentData);
    final String school = _schoolName(schoolData);
    final String subject = _getKinyarwandaSubjectName(subjectName);

    final double mark = _parsePercentage(percentage);
    final String normalizedMark = _formatMark(mark);
    final String grade = _getGrade(mark);
    final String category = _getFeedbackCategory(mark);

    final List<String> seeds = _feedbackSeeds[category]!;
    final String selected = seeds[_feedbackRandom.nextInt(seeds.length)];

    final String feedback = selected
        .replaceAll('{name}', name)
        .replaceAll('{subject}', subject)
        .replaceAll('{mark}', normalizedMark)
        .replaceAll('{term}', termNumber.toString());

    return '''
Muraho neza, mubyeyi wa $name.

Mu gihembwe cya $termNumber, ku ishuri rya $school, $name yabonye amanota $normalizedMark% mu isomo rya $subject. Icyiciro cy'amanota ni $grade.

$feedback

Icyo mwakora: Muganire ku byo yize, mumufashe gusubiramo amasomo kandi mumushishikarize kubaza aho atumva neza. Gufatanya n'umwarimu bizafasha kumenya ubufasha bukenewe.

Icy'ingenzi ni uko $name yumva ko mumushyigikiye. Amanota agaragaza uko yakoze muri iri suzuma, ariko ubufasha, imyitozo n'umwete bishobora kumufasha gutera imbere.

Kanda [[REBA]] urebe raporo yose.
''';
  }

  String _studentName(Map studentData) {
    return (studentData['fullname'] ??
            studentData['full_name'] ??
            studentData['name'] ??
            'umunyeshuri wacu')
        .toString()
        .trim();
  }

  String _schoolName(Map schoolData) {
    return (schoolData['name'] ??
            schoolData['schoolName'] ??
            schoolData['school_name'] ??
            'ishuri ryanyu')
        .toString()
        .trim();
  }

  double _parsePercentage(String percentage) {
    final String cleaned =
        percentage.replaceAll('%', '').trim().replaceAll(',', '.');
    final double? value = double.tryParse(cleaned);
    if (value == null || !value.isFinite) return 0;
    return value.clamp(0.0, 100.0).toDouble();
  }

  String _formatMark(double mark) {
    return mark == mark.roundToDouble()
        ? mark.toInt().toString()
        : mark.toStringAsFixed(1);
  }

  String _getGrade(double mark) {
    if (mark >= 80) return 'A';
    if (mark >= 75) return 'B';
    if (mark >= 70) return 'C';
    if (mark >= 65) return 'D';
    if (mark >= 60) return 'E';
    if (mark >= 50) return 'S';
    return 'F';
  }

  String _getFeedbackCategory(double mark) {
    if (mark >= 80) return 'excellent';
    if (mark >= 70) return 'good';
    if (mark >= 60) return 'developing';
    if (mark >= 50) return 'support';
    return 'low';
  }

  String _getKinyarwandaSubjectName(String subjectName) {
    final String subject = subjectName.trim().toLowerCase();
    const Map<String, String> subjects = {
      'kinyarwanda': 'Ikinyarwanda',
      'english': 'Icyongereza',
      'anglais': 'Icyongereza',
      'french': 'Igifaransa',
      'français': 'Igifaransa',
      'mathematics': 'Imibare',
      'math': 'Imibare',
      'maths': 'Imibare',
      'science': 'Ubumenyi',
      'social studies': 'Ubumenyi bw’imibereho y’abaturage',
      'ict': 'Ikoranabuhanga',
      'computer science': 'Ikoranabuhanga',
      'kiswahili': 'Igiswahili',
      'biology': 'Ibinyabuzima',
      'chemistry': 'Ubutabire',
      'physics': 'Ubugenge',
      'geography': 'Ubumenyi bw’isi',
      'history': 'Amateka',
      'religion': 'Iyobokamana',
      'entrepreneurship': 'Rwiyemezamirimo',
      'physical education': 'Imikino n’imyitozo ngororamubiri',
      'music': 'Umuziki',
      'art': 'Ubugeni',
      'economics': 'Ubukungu',
      'literature': 'Ubuvanganzo',
    };
    return subjects[subject] ?? subjectName;
  }

  static const Map<String, List<String>> _feedbackSeeds = {
    'excellent': [
      '{name} yitwaye neza cyane mu isomo rya {subject}, abona {mark}% mu gihembwe cya {term}. Mukomeze kumutera umwete.',
      'Ndabona {name} yaragize umusaruro ushimishije mu isomo rya {subject}: {mark}%. Mukomeze kumushyigikira.',
      '{name} yerekanye ubumenyi bwiza mu isomo rya {subject}, aho yabonye {mark}%. Ibi ni ibyo kwishimira.',
      'Mu gihembwe cya {term}, {name} yakoze neza cyane mu isomo rya {subject}, abona {mark}%. Mukomeze kumushishikariza kwiga.',
      'Ni ibyishimo kubona {name} yitwaye neza mu isomo rya {subject}, akabona {mark}%. Kumushimira bizamufasha gukomeza.',
      '{name} yageze ku musaruro mwiza mu isomo rya {subject}. Amanota ye ya {mark}% ni intambwe yo kwishimira.',
      'Amanota ya {name} mu isomo rya {subject} ni meza cyane: {mark}%. Mukomeze kumutera akanyabugabo.',
      '{name} yakoze neza mu isomo rya {subject}, abona {mark}% mu gihembwe cya {term}. Mukomeze kumushyigikira.',
      '{name} agaragaza ubumenyi bwiza mu isomo rya {subject}, n’amanota {mark}%. Mukomeze kumufasha gukunda kwiga.',
      'Umusaruro wa {name} mu isomo rya {subject} urashimishije: {mark}%. Mukomeze kumushimira ku mbaraga yashyizemo.',
      '{name} yageze ku rwego rwiza mu isomo rya {subject}, abona {mark}%. Gukomeza imyitozo bizamufasha kurushaho.',
      'Mu isomo rya {subject}, {name} yabonye {mark}%, umusaruro mwiza mu gihembwe cya {term}. Mukomeze kumutera umwete.',
      '{name} yerekanye ko ashobora gukora neza mu isomo rya {subject}; yabonye {mark}%. Mukomeze kumushyigikira.',
      'Ndashimira intambwe {name} yateye mu isomo rya {subject}, aho yabonye {mark}%. Mukomeze kumufasha kugumana umwete.',
      '{name} yitwaye neza mu isomo rya {subject}, n’amanota {mark}%. Mukomeze kumushishikariza kwagura ubumenyi.',
      'Amanota {mark}% ya {name} mu isomo rya {subject} ni umusaruro ushimishije. Mukomeze kumutera inkunga.',
      '{name} yakoze neza cyane mu gihembwe cya {term} mu isomo rya {subject}. Yabonye {mark}%; mukomeze kumushyigikira.',
      'Umusaruro wa {name} mu isomo rya {subject} uratanga icyizere: {mark}%. Mukomeze kumufasha gukomeza gutera imbere.',
      '{name} yagaragaje ko asobanukiwe neza isomo rya {subject}, abona {mark}%. Ni byiza gukomeza umwete n’imyitozo.',
      '{name} afite amanota meza mu isomo rya {subject}: {mark}%. Kumushimira no kumutera umwete bizamufasha gukomeza.',
    ],
    'good': [
      '{name} yitwaye neza mu isomo rya {subject}, abona {mark}% mu gihembwe cya {term}. Akomeze imyitozo kugira ngo arusheho gutera imbere.',
      '{name} afite intambwe nziza mu isomo rya {subject}, n’amanota {mark}%. Mukomeze kumutera umwete.',
      'Ndabona {name} yakoze neza mu isomo rya {subject}, abona {mark}%. Gukomeza gusubiramo bizamufasha kurushaho.',
      'Mu isomo rya {subject}, {name} yabonye {mark}%. Ni umusaruro mwiza ushobora kurushaho kwiyongera.',
      '{name} ari gutera intambwe nziza mu isomo rya {subject}. Amanota ya {mark}% ni aho yakomereza yubaka.',
      '{name} yabonye {mark}% mu isomo rya {subject}. Mumushimire ibyo yagezeho kandi mumufashe kunoza ibitaratungana.',
      'Umusaruro wa {name} mu isomo rya {subject} ni mwiza, n’amanota {mark}%. Gahunda yo kwiga yazamufasha kurushaho.',
      '{name} yakoze neza mu isomo rya {subject}, abona {mark}% mu gihembwe cya {term}. Imyitozo yo mu rugo yamufasha kurushaho.',
      'Amanota ya {name} mu isomo rya {subject} ni {mark}%. Hari ibyo yakoze neza, kandi ashobora gukomeza kunoza ubumenyi.',
      '{name} yerekanye ko ashobora gukora neza mu isomo rya {subject}, abona {mark}%. Mukomeze kumushyigikira.',
      '{name} yageze ku musaruro mwiza mu isomo rya {subject}: {mark}%. Gusubiramo ibyo yize buri gihe byamufasha kurushaho.',
      'Mu gihembwe cya {term}, {name} yabonye {mark}% mu isomo rya {subject}. Gukomeza gushyiramo imbaraga bizamufasha.',
      '{name} afite umusingi mwiza mu isomo rya {subject}, n’amanota {mark}%. Mumufashe kwitoza ibyo agikeneye kunoza.',
      'Amanota {mark}% ya {name} mu isomo rya {subject} agaragaza intambwe nziza. Mukomeze kumutera akanyabugabo.',
      '{name} yitwaye neza mu isomo rya {subject}. Yabonye {mark}%; gukomeza kubaza ibyo atumva byamufasha kurushaho.',
      'Mu isomo rya {subject}, {name} yabonye {mark}%. Gukomeza kugira umwete no gukora imyitozo ni ingenzi.',
      '{name} arimo gutera imbere mu isomo rya {subject}, n’amanota {mark}%. Mukomeze kumushyigikira mu masomo.',
      'Umusaruro wa {name} mu isomo rya {subject} urashimishije, {mark}%. Hari amahirwe yo kurushaho kunoza.',
      '{name} yakoze neza mu gihembwe cya {term}, abona {mark}% mu isomo rya {subject}. Mukomeze kumufasha gukomeza.',
      '{name} afite ubushobozi bwo kurushaho mu isomo rya {subject}; yabonye {mark}%. Imyitozo ihoraho izamufasha.',
    ],
    'developing': [
      '{name} yabonye {mark}% mu isomo rya {subject}. Kumufasha gusubiramo no gukora imyitozo byamufasha kurushaho kumva neza.',
      '{name} aracyafite ibyo kunoza mu isomo rya {subject}, aho yabonye {mark}%. Mumufashe gushyiraho umwanya wo kwiga.',
      'Mu isomo rya {subject}, {name} yabonye {mark}%. Kuganira n’umwarimu ku byo agorwa byamufasha gutera imbere.',
      '{name} aracyubaka ubumenyi bwe mu isomo rya {subject}; yabonye {mark}%. Kumutera umwete no kwitoza byamugirira akamaro.',
      'Amanota ya {name} mu isomo rya {subject} ni {mark}%. Mwamufasha gusubiramo amasomo make make buri munsi.',
      '{name} akeneye gukomeza kwitoza isomo rya {subject}, aho yabonye {mark}%. Gahunda ihoraho yo gusubiramo yamufasha.',
      'Mu gihembwe cya {term}, {name} yabonye {mark}% mu isomo rya {subject}. Ashobora gutera imbere abifashijwemo no kwiga buri gihe.',
      '{name} afite ibyo kongera imbaraga mu isomo rya {subject}, n’amanota {mark}%. Mumufashe kumenya ibyo agorwa.',
      '{name} yabonye {mark}% mu isomo rya {subject}. Kwiga mu bihe bigufi ariko bihoraho byamufasha.',
      'Umusaruro wa {name} mu isomo rya {subject} uracyakeneye kunozwa: {mark}%. Gushyigikirwa n’umuryango n’abarimu byamufasha.',
      '{name} aracyafite amahirwe yo kunoza amanota mu isomo rya {subject}, aho yabonye {mark}%. Mumufashe kwitoza buhoro buhoro.',
      'Amanota ya {name} ni {mark}% mu isomo rya {subject}. Kumubaza ibyo yize no kumufasha aho atumva byamugirira akamaro.',
      '{name} akeneye kurushaho gusubiramo isomo rya {subject}; yabonye {mark}%. Kumutera umwete bizamufasha gukomeza.',
      'Mu isomo rya {subject}, {name} yabonye {mark}%. Byaba byiza asubiyemo amasomo buri munsi kandi akabaza aho agorwa.',
      '{name} aracyafite ibyo kwiga mu isomo rya {subject}, n’amanota {mark}%. Gukora imyitozo myinshi byamufasha.',
      '{name} yabonye {mark}% mu gihembwe cya {term} mu isomo rya {subject}. Mumufashe gushyiraho intego nto zishoboka.',
      'Ni byiza gufasha {name} kunoza isomo rya {subject}, aho yabonye {mark}%. Gahunda yo gusubiramo ishobora kumufasha.',
      '{name} akeneye ubufasha bwo gukomeza gusobanukirwa isomo rya {subject}; amanota ye ni {mark}%. Mumutere inkunga.',
      'Amanota {mark}% ya {name} mu isomo rya {subject} agaragaza ko hakiri ibyo kunoza. Intambwe nto za buri munsi ni ingenzi.',
      '{name} ashobora kurushaho kunoza mu isomo rya {subject}, aho yabonye {mark}%. Kumushyigikira no kwitoza byamufasha.',
    ],
    'support': [
      'Nkurikije amanota ya {name} mu isomo rya {subject} ({mark}%), akeneye ubufasha bwisumbuyeho. Mumufashe gusubiramo amasomo.',
      '{name} yabonye {mark}% mu isomo rya {subject}. Byaba byiza muganiriye n’umwarimu kugira ngo mumenye aho akeneye ubufasha.',
      'Mu isomo rya {subject}, {name} aracyakeneye ubufasha kugira ngo arusheho gusobanukirwa; yabonye {mark}%. Mumushyigikire.',
      '{name} yabonye {mark}% mu gihembwe cya {term} mu isomo rya {subject}. Ntimucike intege; mufatanye kumufasha buhoro buhoro.',
      'Amanota ya {name} mu isomo rya {subject} ni {mark}%. Imyitozo ya buri munsi no kumushimira intambwe nto byamufasha.',
      '{name} akeneye kwitabwaho kurushaho mu isomo rya {subject}, aho yabonye {mark}%. Gufatanya n’ishuri ni intambwe nziza.',
      'Mu isomo rya {subject}, {name} yabonye {mark}%. Mumufashe gutegura gahunda yoroshye yo kwiga buri munsi.',
      '{name} aracyafite imbogamizi mu isomo rya {subject}; amanota ye ni {mark}%. Kumutera inkunga no gushaka ubufasha bw’umwarimu byamufasha.',
      'Nkurikije amanota ya {name} ya {mark}% mu isomo rya {subject}, byaba byiza mwibanze ku bumenyi bw’ibanze.',
      '{name} akeneye ubufasha bufatika mu isomo rya {subject}, aho yabonye {mark}%. Mumwereke ko mumushyigikiye.',
      '{name} yabonye {mark}% mu isomo rya {subject}. Muganire n’umwarimu ku masomo amugora, maze mushyireho gahunda yo kumufasha.',
      'Mu gihembwe cya {term}, {name} yabonye {mark}% mu isomo rya {subject}. Gukomeza kugerageza no gufashwa bishobora kuzana impinduka.',
      '{name} aracyakeneye umwanya wo gusubiramo isomo rya {subject}; amanota ye ni {mark}%. Mumufashe intambwe ku yindi.',
      'Amanota ya {name} mu isomo rya {subject} ni {mark}%. Kumutega amatwi no kumufasha kubona ubufasha bikwiye ni ingenzi.',
      '{name} akeneye kongererwa ubufasha mu isomo rya {subject}, aho yabonye {mark}%. Mukorane n’umwarimu kugira ngo mutegure intambwe zikurikira.',
      '{name} yabonye {mark}% mu isomo rya {subject}. Mumufashe kumenya ibyo atumva kandi mumushishikarize kubaza ibibazo.',
      'Mu isomo rya {subject}, {name} aracyakeneye gushyigikirwa; yabonye {mark}%. Kumutera icyizere bizamufasha gukomeza kugerageza.',
      '{name} afite ibyo akeneye kunoza mu isomo rya {subject}, n’amanota {mark}%. Gufasha umwana utamuca intege ni ingenzi.',
      'Byaba byiza mufashije {name} gusubiramo iby’ibanze mu isomo rya {subject}, aho yabonye {mark}%. Umwarimu ashobora kubafasha kumenya aho ahera.',
      '{name} yabonye {mark}% mu isomo rya {subject}. Nubwo hakiri urugendo, ubufasha buhoraho n’umwete bishobora kumufasha gutera imbere.',
    ],
    'low': [
      '{name} yabonye {mark}% mu isomo rya {subject}. Akeneye ubufasha buhoraho; muganire n’umwarimu kugira ngo mumenye aho ahera.',
      'Amanota ya {name} mu isomo rya {subject} ni {mark}%. Ntimucike intege; mumufashe gusubiramo iby’ibanze buhoro buhoro.',
      '{name} aracyagorwa n’isomo rya {subject}, aho yabonye {mark}%. Kumutera inkunga no kumufasha buri munsi bishobora kumufasha gutera imbere.',
      'Mu gihembwe cya {term}, {name} yabonye {mark}% mu isomo rya {subject}. Byaba byiza mushatse ubufasha bw’umwarimu ku masomo amugora.',
      '{name} akeneye kwitabwaho cyane mu isomo rya {subject}; yabonye {mark}%. Mumufashe gushyiraho gahunda yoroshye yo gusubiramo.',
      'Amanota ya {name} ni {mark}% mu isomo rya {subject}. Icy’ingenzi ubu ni ukumenya ibyo atumva no kubimufashamo, atishinja cyangwa acibwa intege.',
      '{name} yabonye {mark}% mu isomo rya {subject}. Gufatanya n’umwarimu no gukora imyitozo y’ibanze bishobora kumufasha.',
      'Mu isomo rya {subject}, {name} aracyakeneye ubufasha bwinshi; amanota ye ni {mark}%. Mumushishikarize kubaza ibibazo no gusubiramo.',
      '{name} afite urugendo rwo kunoza isomo rya {subject}, aho yabonye {mark}%. Kumushyigikira no kwibanda ku ntambwe nto ni ingenzi.',
      'Nkurikije amanota ya {name} ya {mark}% mu isomo rya {subject}, byaba byiza mumenye n’umwarimu ibice bimugora kurusha ibindi.',
      '{name} yabonye {mark}% mu isomo rya {subject}. Mumufashe kwiga buri munsi mu gihe gito kandi muganire ku byo yize.',
      'Mu gihembwe cya {term}, {name} ntiyageze ku musaruro twifuzaga mu isomo rya {subject}; yabonye {mark}%. Ubufasha n’imyitozo bishobora kumufasha.',
      '{name} aracyakeneye gufashwa gusobanukirwa isomo rya {subject}, aho yabonye {mark}%. Mumwereke ko ashobora kongera kugerageza.',
      'Amanota {mark}% ya {name} mu isomo rya {subject} agaragaza ko hakenewe ubufasha bwihariye. Mugane umwarimu mushyireho gahunda y’iterambere.',
      '{name} yabonye {mark}% mu isomo rya {subject}. Mumufashe kumva iby’ibanze kandi mumushimire imbaraga ashyiraho.',
      'Mu isomo rya {subject}, {name} akeneye ubufasha bwihariye; yabonye {mark}%. Kuganira n’umwarimu bizafasha kumenya intambwe ikurikira.',
      '{name} aracyagorwa n’isomo rya {subject}. Amanota ya {mark}% ni impamvu yo kumufasha kurushaho, si ukumuca intege.',
      '{name} yabonye {mark}% mu isomo rya {subject}. Mushobora gutangirira ku isomo rimwe rimugora, mukarikoraho imyitozo mike buri munsi.',
      'Byaba byiza mufashije {name} kubona ubufasha mu isomo rya {subject}, aho yabonye {mark}%. Gushyigikirwa n’umuryango n’ishuri bishobora kugira icyo bihindura.',
      '{name} akeneye indi nkunga mu isomo rya {subject}, n’amanota {mark}%. Mukomeze kumutera icyizere kandi mufatanye n’umwarimu gutegura uko azamuka.',
    ],
  };

  Map marks() {
    return rules["primary"][0]["student_marks"];
  }

  // ---------------------------------------------------------
  // PUBLIC SDK METHOD: Generate PDF Report Card
  // ---------------------------------------------------------
  Future<Uint8List> generateReportPdf() async {
    final pdf = pw.Document();

    final Map ruleData = rules;
    final Map schoolData = ruleData["school_data"];
    final Map primaryData = ruleData["primary"][0];
    final Map studentData = primaryData["student_data"];
    final Map studentMarks = primaryData["student_marks"];
    final Map conduct = studentMarks["conduct_marks"];
    final Map subjectsAlloc = studentMarks["subject_marks"]["subjects_alloc"];

    final String fullName =
        (studentData["names"]["first_name"] ?? "").toString();
    final String studentId = (studentData["studentid"] ?? "").toString();
    final String schoolName = (schoolData["school_name"] ?? "").toString();
    final String district = (schoolData["district"] ?? "").toString();
    final String schoolCode = (schoolData["school_code"] ?? "").toString();
    final String phone = (schoolData["phone"] ?? "").toString();
    final String headTeacher = (schoolData["head_teacher"] ?? "").toString();

    final List<int> conductMarks =
        (conduct["marks"] as List).map((e) => e as int).toList();
    final int conductMax = conduct["max"] as int;
    final int conductTotal = conductMarks.fold(0, (a, b) => a + b);

    final List<MapEntry<String, Map>> subjectEntries = subjectsAlloc.entries
        .map((e) => MapEntry(e.key as String, e.value as Map))
        .toList();

    int grandMax = 0;
    int grandTotal = 0;
    for (final entry in subjectEntries) {
      final Map subj = entry.value;
      final int maxPerSubject = _inferSubjectMax(subj);
      grandMax += maxPerSubject;
      final int subjTotal = _subjectAnnualTotal(subj);
      grandTotal += subjTotal;
    }
    final double overallPct = grandMax == 0 ? 0 : (grandTotal / grandMax) * 100;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        build: (context) => [
          // HEADER
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text("REPUBLIC OF RWANDA",
                      style: const pw.TextStyle(fontSize: 8)),
                  pw.Text("MINISTRY OF EDUCATION",
                      style: const pw.TextStyle(fontSize: 8)),
                  pw.Text("DISTRICT: $district",
                      style: const pw.TextStyle(fontSize: 8)),
                  pw.Text("School: $schoolName",
                      style: const pw.TextStyle(fontSize: 8)),
                  pw.Text("School Code: $schoolCode",
                      style: const pw.TextStyle(fontSize: 8)),
                  pw.Text("E-mail: $phone",
                      style: const pw.TextStyle(fontSize: 8)),
                  pw.Text("Phone: $phone",
                      style: const pw.TextStyle(fontSize: 8)),
                ],
              ),
              pw.Container(
                padding: const pw.EdgeInsets.all(6),
                decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.8)),
                child: pw.Column(
                  children: [
                    pw.Text("STUDENT REPORT CARD",
                        style: pw.TextStyle(
                            fontSize: 11, fontWeight: pw.FontWeight.bold)),
                    pw.Text("PRIMARY",
                        style: pw.TextStyle(
                            fontSize: 10, fontWeight: pw.FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 6),

          // STUDENT INFO
          pw.Container(
            padding: const pw.EdgeInsets.all(4),
            decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.8)),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text("Names: $fullName",
                        style: const pw.TextStyle(fontSize: 8)),
                    pw.Text("Student Unique Identifier: $studentId",
                        style: const pw.TextStyle(fontSize: 8)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text("Academic Year: 2025/2026",
                        style: const pw.TextStyle(fontSize: 8)),
                    pw.Text("Level: PRIMARY",
                        style: const pw.TextStyle(fontSize: 8)),
                    pw.Text("Class: P6B",
                        style: const pw.TextStyle(fontSize: 8)),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 6),

          // MARKS TABLE
          _buildMarksTable(subjectEntries, conductMarks, conductMax, conductTotal),

          pw.SizedBox(height: 6),

          // TOTALS
          _buildTotalsRow(grandMax, grandTotal, overallPct),

          pw.SizedBox(height: 6),

          // GRADING SCALE
          _buildGradingScale(),

          pw.SizedBox(height: 8),

          // DECISION & SIGNATURES
          _buildDecisionAndSignatures(overallPct, headTeacher),

          pw.SizedBox(height: 10),

          // ANALYSIS PAGES
          ..._buildAnalysisPages(subjectEntries),
        ],
      ),
    );

    return pdf.save();
  }

  int _inferSubjectMax(Map subject) {
    final Map t1 = subject["term_1"];
    final int total = _termETTotal(t1);
    final String pct = t1["block_7"][0].toString().replaceAll('%', '');
    final double p = double.tryParse(pct) ?? 0;
    if (p <= 0) return 180;
    return ((total / p) * 100).round();
  }

  int _termETTotal(Map term) {
    final int v1 = (term["block_4"][0] as int);
    final int v2 = (term["block_5"][0] as int);
    return v1 + v2;
  }

  int _subjectAnnualTotal(Map subject) {
    int total = 0;
    for (final term in ["term_1", "term_2", "term_3"]) {
      final Map t = subject[term];
      total += (t["block_6"][0] as int);
    }
    return total;
  }

  pw.Widget _buildMarksTable(
    List<MapEntry<String, Map>> subjects,
    List<int> conductMarks,
    int conductMax,
    int conductTotal,
  ) {
    final headerStyle =
        pw.TextStyle(fontSize: 6, fontWeight: pw.FontWeight.bold);
    final cellStyle = const pw.TextStyle(fontSize: 6);

    final List<List<String>> dataRows = [];

    dataRows.add([
      "Conduct", "$conductMax",
      "${conductMarks[0]}", "", "$conductTotal", "", "",
      "${conductMarks[1]}", "", "$conductTotal", "", "",
      "${conductMarks[2]}", "", "$conductTotal", "", "",
      "$conductTotal", "$conductMax", "", "",
    ]);

    for (final e in subjects) {
      final Map s = e.value;
      final Map t1 = s["term_1"];
      final Map t2 = s["term_2"];
      final Map t3 = s["term_3"];
      final int max = _inferSubjectMax(s);
      final int annual = _subjectAnnualTotal(s);
      final double pct = max == 0 ? 0 : (annual / max) * 100;

      dataRows.add([
        e.key, "$max",
        "${t1["block_1"][0]}", "${t1["block_4"][0]}",
        "${t1["block_6"][0]}", "${t1["block_7"][0]}", "${t1["block_8"][0]}",
        "${t2["block_1"][0]}", "${t2["block_4"][0]}",
        "${t2["block_6"][0]}", "${t2["block_7"][0]}", "${t2["block_8"][0]}",
        "${t3["block_1"][0]}", "${t3["block_4"][0]}",
        "${t3["block_6"][0]}", "${t3["block_7"][0]}", "${t3["block_8"][0]}",
        "$annual", "$max",
        "${pct.toStringAsFixed(1)}%",
        (GRADING_SCALE("${pct.toStringAsFixed(1)}%")),
      ]);
    }

    return pw.TableHelper.fromTextArray(
      headers: [
        "SUBJECT", "MAX",
        "EU", "ET", "TOT", "%", "GR",
        "EU", "ET", "TOT", "%", "GR",
        "EU", "ET", "TOT", "%", "GR",
        "TOTAL", "MAX", "%", "GR"
      ],
      data: dataRows,
      headerStyle: headerStyle,
      cellStyle: cellStyle,
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
      cellDecoration: (index, data, rowNum) =>
          pw.BoxDecoration(border: pw.Border.all(width: 0.3)),
      headerAlignment: pw.Alignment.center,
      cellAlignment: pw.Alignment.center,
      columnWidths: {
        0: const pw.FlexColumnWidth(2.4),
        for (int i = 1; i < 21; i++) i: const pw.FlexColumnWidth(1),
      },
    );
  }

  pw.Widget _buildTotalsRow(int max, int total, double pct) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(4),
      decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.6)),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text("Total: $total / $max",
              style: const pw.TextStyle(fontSize: 8)),
          pw.Text("Percentage: ${pct.toStringAsFixed(1)}%",
              style: const pw.TextStyle(fontSize: 8)),
          pw.Text("Grade: ${GRADING_SCALE("${pct.toStringAsFixed(1)}%")}",
              style: const pw.TextStyle(fontSize: 8)),
        ],
      ),
    );
  }

  pw.Widget _buildGradingScale() {
    final scale = [
      ["Final Grade", "100-80", "79-75", "74-70", "69-65", "64-60", "59-50", "49-0"],
      ["Letter Grade", "A", "B", "C", "D", "E", "S", "F"],
    ];
    return pw.TableHelper.fromTextArray(
      data: scale,
      cellStyle: const pw.TextStyle(fontSize: 7),
      headerStyle:
          pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
      cellDecoration: (i, d, r) =>
          pw.BoxDecoration(border: pw.Border.all(width: 0.3)),
      cellAlignment: pw.Alignment.center,
    );
  }

  pw.Widget _buildDecisionAndSignatures(
      double overallPct, String headTeacher) {
    final decision = overallPct >= 50 ? "PROMOTED" : "REPEAT";
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text("Decision",
                style:
                    pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
            pw.Text(decision,
                style: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                  color: decision == "PROMOTED"
                      ? PdfColors.green700
                      : PdfColors.red700,
                )),
          ],
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text("HEADTEACHER",
                style:
                    pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
            pw.Text(headTeacher, style: const pw.TextStyle(fontSize: 8)),
            pw.SizedBox(height: 2),
            pw.Text("Class teacher's Signature: ______________",
                style: const pw.TextStyle(fontSize: 7)),
            pw.Text("Parent's Signature: ______________",
                style: const pw.TextStyle(fontSize: 7)),
          ],
        ),
      ],
    );
  }

  List<pw.Widget> _buildAnalysisPages(
      List<MapEntry<String, Map>> subjects) {
    final List<pw.Widget> widgets = [];
    for (final e in subjects) {
      final Map s = e.value;
      for (final term in ["term_1", "term_2", "term_3"]) {
        final Map t = s[term];
        if (t.containsKey("block_10")) {
          widgets.add(pw.SizedBox(height: 4));
          widgets.add(pw.Container(
            padding: const pw.EdgeInsets.all(6),
            decoration:
                pw.BoxDecoration(border: pw.Border.all(width: 0.4)),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text("${e.key} — ${term.replaceAll("_", " ")}",
                    style: pw.TextStyle(
                        fontSize: 8, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 2),
                pw.Text("${t["block_10"][0]}",
                    style: const pw.TextStyle(fontSize: 7)),
              ],
            ),
          ));
        }
      }
    }
    return widgets;
  }
}