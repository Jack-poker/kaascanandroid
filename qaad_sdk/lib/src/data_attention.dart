import 'package:chalkdart/chalk.dart';
import 'decoder.dart';
import 'models/school_model.dart';
import 'models/student_model.dart';
import 'rules/primary.dart';
import 'package:pretty_print_json/pretty_print_json.dart';

class DataAttention {
  DataAttention({required this.data});
  List data = [];

  // school and student data
  List<dynamic> ssData(layerData) {
    List data = [];
    List current = [];

    for (var ldn in layerData) {
      if (ldn == "-") {
        data.add(current);
        current = [];
      } else {
        if (ldn != 65) {
          current.add(ldn);
        }
      }
    }

    if (current.isNotEmpty) {
      data.add(current);
    }

    return data;
  }

  //student marks data
  // ignore: strict_top_level_inference
  List<dynamic> smData(layerData) {
    List data = [];
    List current = [];
    bool started = false; // flag to know when we've hit 65

    for (var ldn in layerData) {
      if (ldn == 65) {
        // If we already have a group, save it before starting a new one
        if (current.isNotEmpty) {
          data.add(current);
        }
        current = []; // start a new group
        started = true;
        continue; // don't include the 65 itself
      }

      // Only collect values after the first 65
      if (started) {
        current.add(ldn);
      }
    }

    // Add the last group if it has data
    if (current.isNotEmpty) {
      data.add(current);
    }

    return data[0];
  }

  // Layer 1: get student and school data
  List<dynamic> layer_0() {
    List layer1Tkn = [];
    for (var dn in data) {
      if (dn == 63) {
        layer1Tkn.add("-");
      } else {
        layer1Tkn.add(dn);
      }
      if (dn == 65) {
        break;
      }
    }

    // Display layer data
    print(
      chalk.bgBrightYellow(
        "[*] Layer 1 / <student_data/school_data>:",
        chalk.bgGray(layer1Tkn),
      ),
    );
    print("\n");

    return layer1Tkn;
  }

  List<dynamic> layer_1() {
    return data;
  }

  // Layer 2: decode student and school data
  Map<dynamic, dynamic> layer_2() {
    // List layer2Dt = [];

    List<dynamic> schoolStudentData = ssData(layer_0());
    List<dynamic> studentMarksData = smData(layer_1());

    print(schoolStudentData);
    print("\n");

    List<int> block_0 = List<int>.from(schoolStudentData[0]);
    List<int> block_1 = List<int>.from(schoolStudentData[1]);
    List<int> block_2 = List<int>.from(schoolStudentData[2]);
    List<int> block_3 = List<int>.from(schoolStudentData[3]);
    List<int> block_4 = List<int>.from(schoolStudentData[4]);
    List<int> block_5 = List<int>.from(schoolStudentData[5]);

    String tkc(block) {
      var tkn = ITokenDecoder(block).decodeToken();
      return CleanToken(tkn).clean()!;
    }

    final student = Student(fullNames: tkc(block_5), studentId: tkc(block_2));
    final school = SchoolModel(
      schoolName: tkc(block_0),
      schoolDistrict: tkc(block_1),
      schoolPhone: tkc(block_3),
      directorName: tkc(block_4),
    );

    Map ssData_ = {
      "student_data": {
        "fullname": student.fullNames,
        "studentid": student.studentId,
      },
      "school_data": {
        "school_name": school.schoolName,
        "school_district": school.schoolDistrict,
        "school_phonenumber": school.schoolPhone,
        "director_name": school.directorName,
      },
    };

    return {
      "student_data": {
        "fullname": student.fullNames,
        "studentid": student.studentId,
      },
      "school_data": {
        "school_name": school.schoolName,
        "school_district": school.schoolDistrict,
        "school_phonenumber": school.schoolPhone,
        "director_name": school.directorName,
      },
      "student_marks": Primary(schoolStudentData: ssData_,data: studentMarksData).marks(),
    };
  }
}

void main() {
  var Datn = DataAttention(
    data: [
      38,
      24,
      21,
      21,
      14,
      16,
      14,
      62,
      48,
      10,
      27,
      10,
      23,
      10,
      29,
      17,
      10,
      63,
      49,
      34,
      10,
      23,
      35,
      10,
      63,
      7,
      8,
      6,
      5,
      4,
      8,
      63,
      0,
      7,
      8,
      8,
      6,
      3,
      9,
      3,
      9,
      8,
      63,
      55,
      30,
      34,
      18,
      28,
      17,
      18,
      22,
      14,
      62,
      40,
      22,
      22,
      10,
      23,
      30,
      14,
      21,
      63,
      44,
      23,
      14,
      35,
      10,
      39,
      14,
      11,
      24,
      27,
      10,
      17,
      65,
      40,
      30,
      35,
      90,
      90,
      54,
      53,
      90,
      90,
      54,
      53,
      90,
      90,
      54,
      53,
      90,
      90,
      54,
      53,
      90,
      90,
      54,
      53,
      90,
      90,
      54,
      53,
      90,
      90,
      54,
      53,
      90,
      90,
      54,
      53,
      90,
      90,
      54,
      53,
      90,
      90,
      54,
      53,
      90,
      90,
      54,
      53,
      90,
      90,
      54,
      53,
      90,
      90,
      54,
      53,
      90,
      90,
      54,
      53,
      90,
      90,
      54,
      53,
      90,
      90,
      54,
      53,
      90,
      90,
      54,
      53,
      90,
      90,
      54,
      53,
      90,
      90,
      54,
      53,
      90,
      90,
      54,
      53,
      90,
      90,
      54,
      53,
      90,
      90,
      54,
      53,
      90,
      90,
      54,
      53,
      90,
      90,
      54,
      53,
      90,
      90,
      54,
      53,
      90,
      90,
      54,
      53,
      90,
      90,
      54,
      53,
      90,
      90,
      54,
      53,
      90,
      90,
      54,
      53,
      90,
      90,
      54,
      53,
      90,
      90,
      54,
      53,
      90,
      90,
      54,
      53,
      90,
      90,
      54,
      53,
      90,
      90,
      54,
      53,
      90,
      90,
      54,
      53,
      90,
      90,
      54,
      53,
      90,
      90,
      54,
      53,
      90,
      90,
      54,
      53,
      90,
      90,
      54,
      53,
      90,
      90,
      54,
      53,
      90,
      90,
      54,
      53,
      90,
      90,
      54,
      53,
      90,
      90,
      54,
      53,
      90,
      90,
      54,
      53,
      90,
      90,
      54,
      53,
      90,
      90,
      54,
      53,
      90,
      90,
      54,
      53,
      90,
      90,
      54,
      53,
      90,
      90,
      54,
      53,
      90,
      90,
      54,
      53,
      90,
      90,
      54,
      53,
      90,
      90,
      54,
      53,
      90,
      90,
      54,
      53,
      90,
      90,
      54,
      53,
      90,
      90,
      54,
      53,
      90,
      90,
      54,
      53,
      90,
      90,
      54,
      53,
      90,
      90,
      54,
      53,
      90,
      90,
      54,
      53,
      90,
      90,
      54,
      53,
      90,
      90,
      54,
      53,
      90,
      90,
      54,
      53,
      90,
      90,
      54,
      53,
      90,
      90,
      54,
      53,
      90,
      90,
      54,
      53,
      90,
      90,
      54,
      53,
      90,
      90,
      54,
      53,
      90,
      90,
      54,
      53,
      90,
      90,
      54,
      53,
      90,
      90,
      54,
      53,
      90,
      90,
      54,
      53,
      90,
      90,
      54,
      53,
      90,
      90,
      54,
      53,
      90,
      90,
      54,
      53,
      90,
      90,
      54,
      53,
      90,
      90,
      54,
      53,
      90,
      90,
      54,
      53,
      90,
      90,
      54,
      53,
      90,
      90,
      54,
      53,
      90,
      90,
      54,
      53,
      90,
      90,
      54,
      53,
      90,
      90,
      54,
      53,
      90,
      90,
      54,
      53,
      90,
      90,
      54,
      53,
      90,
      90,
      54,
      53,
      90,
      90,
      54,
      53,
      90,
      90,
      54,
      53,
      90,
      90,
      54,
      53,
      90,
      90,
      54,
      53,
      90,
      90,
      54,
      53,
      90,
      90,
      54,
      53,
      90,
      90,
      54,
      53,
      90,
      90,
      54,
      53,
      90,
      90,
      54,
      53,
      90,
      90,
      54,
      53,
      90,
      90,
      54,
      53,
    ],
  );
  print("\n");
  print(prettyJson(Datn.layer_2()));
  Datn.smData(Datn.layer_1());
}
