import 'dart:math';
import 'package:convert/convert.dart';
import 'package:qaad_shared/qaad_sdk.dart';
import 'package:qaad_shared/src/debug.dart';

Map<int, String> hexMap = {
  48: "A",
  72: "B",
  29: "C",
  85: "D",
  14: "E",
  67: "F",
  58: "G",
  31: "H",
  84: "I",
  49: "J",
  66: "K",
  22: "L",
  97: "M",
  55: "N",
  36: "O",
  81: "P",
  13: "Q",
  69: "R",
  44: "S",
  90: "T",
  28: "U",
  75: "V",
  53: "W",
  18: "X",
  86: "Y",
  41: "Z",
  38: "a",
  95: "b",
  52: "c",
  19: "d",
  76: "e",
  33: "f",
  88: "g",
  45: "h",
  61: "i",
  27: "j",
  83: "k",
  16: "l",
  70: "m",
  39: "n",
  92: "o",
  54: "p",
  21: "q",
  87: "r",
  35: "s",
  68: "t",
  12: "u",
  79: "v",
  46: "w",
  98: "x",
  25: "y",
  73: "z",
  42: "0",
  17: "1",
  89: "2",
  56: "3",
  23: "4",
  78: "5",
  34: "6",
  91: "7",
  11: "8",
  63: "9",
  62: "+",
  99: "/",
  10: "=",
};

class KeysInventor {
  final String rawKey;
  final String pin;

  KeysInventor({required this.rawKey, required this.pin});

  Map<String, int> reverseMap = {
    "A": 48,
    "B": 72,
    "C": 29,
    "D": 85,
    "E": 14,
    "F": 67,
    "G": 58,
    "H": 31,
    "I": 84,
    "J": 49,
    "K": 66,
    "L": 22,
    "M": 97,
    "N": 55,
    "O": 36,
    "P": 81,
    "Q": 13,
    "R": 69,
    "S": 44,
    "T": 90,
    "U": 28,
    "V": 75,
    "W": 53,
    "X": 18,
    "Y": 86,
    "Z": 41,
    "a": 38,
    "b": 95,
    "c": 52,
    "d": 19,
    "e": 76,
    "f": 33,
    "g": 88,
    "h": 45,
    "i": 61,
    "j": 27,
    "k": 83,
    "l": 16,
    "m": 70,
    "n": 39,
    "o": 92,
    "p": 54,
    "q": 21,
    "r": 87,
    "s": 35,
    "t": 68,
    "u": 12,
    "v": 79,
    "w": 46,
    "x": 98,
    "y": 25,
    "z": 73,
    "0": 42,
    "1": 17,
    "2": 89,
    "3": 56,
    "4": 23,
    "5": 78,
    "6": 34,
    "7": 91,
    "8": 11,
    "9": 63,
    "+": 62,
    "/": 99,
    "=": 10,
  };

  String generate() {
    String bits;

    if (pin.length != 5) {
      debug.debugMessage('PIN must be exactly 5 characters');
      return "";
    }

    if (rawKey.contains(RegExp(r'^[01]+$'))) {
      bits = rawKey;
    } else {
      bits = rawKey
          .split('')
          .map((h) => int.parse(h, radix: 16).toRadixString(2).padLeft(4, '0'))
          .join('');
    }

    final bitsList =
       bits
            .split('');

    // ✅ FIX: Use the actual pin parameter
    final positions = PinManager(pin: pin).generateHash();
    //                              ^^^^^ Use the actual pin!

    print('PIN: $pin');
    print('Positions: $positions');
    print(
      'Original first 100 bits: ${bits.substring(0, min(100, bits.length))}',
    );

    print("Before flipping:");
    for (var idx in positions!) {
      print("Index $idx: ${bitsList[idx]}");
    }

    // Your flip code
    for (var idx in positions) {
      if (idx < bitsList.length) {
        bitsList[idx] = (bitsList[idx] == '1') ? '0' : '1';
      }
    }

    print("\nAfter flipping:");
    for (var idx in positions) {
      print("Index $idx: ${bitsList[idx]}");
    }

    final flippedBits = bitsList.join('');

    print("flipped bits: $flippedBits");
    final bytes = <int>[];
    for (int i = 0; i < flippedBits.length; i += 8) {
      bytes.add(
        int.parse(
          flippedBits.substring(i, min(i + 8, flippedBits.length)),
          radix: 2,
        ),
      );
    }

    return hex.encode(bytes);
  }
}
