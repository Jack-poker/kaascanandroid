import 'package:qaad_sdk/src/debug.dart';

Map<int, String> tokenMap = {
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
};

class Detokenizer {
  Detokenizer({required this.token});

  List<int> token = [];

  Map<String, String>? detokenizer() {
    try {
      if (token.isEmpty) return {"status": "fake"};

      Map<String, String> detokenizedData = {};

      List<Map<String, dynamic>> products = [];
      List<int> currentBlock = [];

      token.asMap().forEach((key, value) {
        currentBlock.add(value);
        if (value == 63) {
          // Remove the delimiter (63) and create product map
          final blockData = List<int>.from(currentBlock)..removeLast();

          products.add({
            'id': products.length + 1,
            'raw_data': blockData,
            'values': blockData.join(', '),
            'length': blockData.length,
            'checksum': blockData.fold(0, (sum, item) => sum + item),
          });

          currentBlock.clear();
        }
      });

      String tokenData(List<int> token) {
        List<String> tokenData = [];
        token.asMap().forEach((key, value) {
          tokenData.add(tokenMap[value].toString());
        });

        String dataToken = "";

        tokenData.asMap().forEach((key, value) {
          dataToken += value;
        });

        return dataToken;
      }

      List<String> productData = [];
      products.asMap().forEach((key, value) {
        productData.add(tokenData(value["raw_data"]));
      });

      detokenizedData.addAll(
        {
          "product_name":productData[0],
          "brand_name":productData[1],
          "batch_number":productData[2],
          "manufacturing_Date":productData[3]
        }
      );

      return detokenizedData;
    } catch (e) {
      debug.debugMessage(e.toString());
    }
    return null;
  }
}
