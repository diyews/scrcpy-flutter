import 'dart:typed_data';

import 'package:pointycastle/export.dart' hide State;
import 'package:shared_preferences/shared_preferences.dart';

class CBCCipher {
  static Uint8List aesKey = Uint8List(0);

  static Future<void> initKey() async {
    final prefs = await SharedPreferences.getInstance();
    final key = prefs.getString('encrypt_key') ?? '';
    if (key.isNotEmpty) {
      aesKey = Uint8List.fromList(key.codeUnits);
    }
  }

  static Uint8List processBodyBytes(Uint8List bodyBytes) {
    final iv = Uint8List.sublistView(bodyBytes, 0, aesKey.length);
    final cipherText = Uint8List.sublistView(bodyBytes, aesKey.length);

    final cbc = CBCBlockCipher(AESFastEngine())
      ..init(false, ParametersWithIV(KeyParameter(aesKey), iv));

    final paddedPlainText = Uint8List(cipherText.length);

    /* decrypt take 100ms(cold), 50ms(medium), 15-30ms(hot) */
    var offset = 0;
    while (offset < cipherText.length) {
      offset += cbc.processBlock(cipherText, offset, paddedPlainText, offset);
    }

    return Uint8List.sublistView(
        paddedPlainText, 0, paddedPlainText.length - paddedPlainText.last);
  }
}
