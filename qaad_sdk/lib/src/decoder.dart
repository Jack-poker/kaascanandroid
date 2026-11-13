//Qaad decoder
//Author: Tuyishime Emmanuel (Quantum Bytes)

import 'package:cli_table/cli_table.dart';
import 'package:chalkdart/chalk.dart';
import 'debug.dart';
// integers tokens decoder

final table = Table(
  header: [
    chalk.yellow.bold('┌─ Generated Token ─┐'),
    chalk.green.bold('└─ Clean Token ─┘'),
  ],
  style: TableStyle(paddingLeft: 20),
);

class ITokenDecoder {
  ITokenDecoder(this.ltoken);

  List<int> ltoken;

 Map<int, String> encodeMap = {
  0: "0",
  1: "1",
  2: "2",
  3: "3",
  4: "4",
  5: "5",
  6: "6",
  7: "7",
  8: "8",
  9: "9",
  10: "a",
  11: "b",
  12: "c",
  13: "d",
  14: "e",
  15: "f",
  16: "g",
  17: "h",
  18: "i",
  19: "j",
  20: "k",
  21: "l",
  22: "m",
  23: "n",
  24: "o",
  25: "p",
  26: "q",
  27: "r",
  28: "s",
  29: "t",
  30: "u",
  31: "v",
  32: "w",
  33: "x",
  34: "y",
  35: "z",
  36: "A",
  37: "B",
  38: "C",
  39: "D",
  40: "E",
  41: "F",
  42: "G",
  43: "H",
  44: "I",
  45: "J",
  46: "K",
  47: "L",
  48: "M",
  49: "N",
  50: "O",
  51: "P",
  52: "Q",
  53: "R",
  54: "S",
  55: "T",
  56: "U",
  57: "V",
  58: "W",
  59: "X",
  60: "Y",
  61: "Z",
  62: " ",
  63: "|",
  64: ".",
  65: "/",
};

  List<String> decodeToken() {
    List<String> token = [];

    ltoken
        .map((value) => {token.add(encodeMap[value].toString())})
        .whereType<int>()
        .toList();

    return token;
  }
}

class IITokenDecoder {
  IITokenDecoder(this.iItoken);
  List<int> iItoken = [];

  Map<int, int> encodeMap = {
    1: 42,
    2: 17,
    3: 89,
    4: 5,
    5: 73,
    6: 31,
    7: 66,
    8: 94,
    9: 23,
    10: 58,
    11: 82,
    12: 39,
    13: 11,
    14: 77,
    15: 45,
    16: 60,
    17: 3,
    18: 88,
    19: 26,
    20: 91,
    21: 34,
    22: 70,
    23: 15,
    24: 50,
    25: 96,
    26: 9,
    27: 54,
    28: 79,
    29: 18,
    30: 63,
    31: 37,
    32: 85,
    33: 2,
    34: 48,
    35: 71,
    36: 20,
    37: 93,
    38: 28,
    39: 65,
    40: 13,
    41: 56,
    42: 81,
    43: 7,
    44: 41,
    45: 69,
    46: 25,
    47: 90,
    48: 33,
    49: 76,
    50: 44,
    51: 62,
    52: 97,
    53: 19,
    54: 86,
    55: 4,
    56: 38,
    57: 72,
    58: 10,
    59: 51,
    60: 84,
    61: 22,
    62: 67,
    63: 30,
    64: 95,
    65: 47,
    66: 61,
    67: 14,
    68: 78,
    69: 35,
    70: 99,
    71: 6,
    72: 53,
    73: 80,
    74: 27,
    75: 92,
    76: 16,
    77: 43,
    78: 75,
    79: 1,
    80: 64,
    81: 49,
    82: 87,
    83: 32,
    84: 59,
    85: 98,
    86: 12,
    87: 40,
    88: 74,
    89: 21,
    90: 83,
    91: 36,
    92: 100,
    93: 29,
    94: 46,
    95: 52,
    96: 24,
    97: 55,
    98: 68,
    99: 8,
    100: 57,
  };

  List<int> decodeToken() {
    try {
      List<int> token = [];

      iItoken
          // .map((value) => {token.add(encodeMap[value.toInt()]!)})
              .map((value) => {token.add(value)})
          .whereType<int>() // Filters out nulls
          .toList();
      return token;
    } catch (e) {
      debug.debugMessage(e.toString());
      return [];
    }
  }
}

class CleanToken {
  CleanToken(this.token);

  final token;

  String? clean() {
    var cleantoken = "";

    token.asMap().forEach((index, map) {
      cleantoken += map.toString();
    });

    if (token.isEmpty) return null;

    table.add([token.toString(), cleantoken]);
    // if (debug.debugmode()) {
    //   print(table);
    // }

    return cleantoken;
  }
}

