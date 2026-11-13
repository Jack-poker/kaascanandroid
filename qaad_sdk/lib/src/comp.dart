import 'dart:typed_data';

class Comp {
  static const int base = 101;

  /// Compress marks to bytes (matches Python's compress)
  static Uint8List compress(List<int> marks) {
    BigInt v = BigInt.zero;
    final bigBase = BigInt.from(base);
    
    for (int i = 0; i < marks.length; i++) {
      v += BigInt.from(marks[i]) * bigBase.pow(i);
    }
    
    final byteLength = (v.bitLength + 7) ~/ 8;
    if (byteLength == 0) return Uint8List(0);
    
    final bytes = Uint8List(byteLength);
    BigInt temp = v;
    
    for (int i = byteLength - 1; i >= 0; i--) {
      bytes[i] = (temp & BigInt.from(0xFF)).toInt();
      temp = temp >> 8;
    }
    
    return bytes;
  }

  /// Decompress raw bytes to marks (EXACTLY like Python's decompress)
  static List<int> decompress(Uint8List byteData) {
    // int.from_bytes(byte_data, byteorder='big')
    BigInt v = BigInt.zero;
    for (final byte in byteData) {
      v = (v << 8) | BigInt.from(byte);
    }
    
    // divmod loop
    final marks = <int>[];
    final bigBase = BigInt.from(base);
    
    while (v > BigInt.zero) {
      marks.add((v % bigBase).toInt());
      v = v ~/ bigBase;
    }
    
    return marks;
  }

  /// Convert hex string to raw bytes
  static Uint8List hexToBytes(String hex) {
    // Remove 0x prefix
    String cleanHex = hex.startsWith('0x') || hex.startsWith('0X') 
        ? hex.substring(2) 
        : hex;
    
    // Pad if odd length
    if (cleanHex.length % 2 != 0) {
      cleanHex = '0$cleanHex';
    }
    
    final length = cleanHex.length ~/ 2;
    final bytes = Uint8List(length);
    
    for (int i = 0; i < length; i++) {
      bytes[i] = int.parse(cleanHex.substring(i * 2, (i + 1) * 2), radix: 16);
    }
    
    return bytes;
  }

  /// Convert binary string to raw bytes
  static Uint8List binaryToBytes(String binary) {
    // Pad to multiple of 8
    final paddedLength = (binary.length + 7) ~/ 8 * 8;
    final padded = binary.padLeft(paddedLength, '0');
    
    final length = paddedLength ~/ 8;
    final bytes = Uint8List(length);
    
    for (int i = 0; i < length; i++) {
      bytes[i] = int.parse(padded.substring(i * 8, (i + 1) * 8), radix: 2);
    }
    
    return bytes;
  }

  /// Decompress from hex string directly
  static List<int> decompressFromHex(String hex) {
    return decompress(hexToBytes(hex));
  }

  /// Decompress from binary string directly
  static List<int> decompressFromBinary(String binary) {
    return decompress(binaryToBytes(binary));
  }

  /// Convert bytes to hex string
  static String bytesToHex(Uint8List bytes) {
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Convert bytes to binary string
  static String bytesToBinary(Uint8List bytes) {
    return bytes.map((b) => b.toRadixString(2).padLeft(8, '0')).join();
  }
}