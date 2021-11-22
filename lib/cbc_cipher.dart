import 'dart:isolate';
import 'dart:typed_data';

import 'package:pointycastle/export.dart' hide State;
import 'package:shared_preferences/shared_preferences.dart';

class CBCCipher {
  static Uint8List aesKey = Uint8List(0);

  static void setAESKey(Uint8List key, [bool isSync = true]) {
    aesKey = key;
    if (isSync) {
      CBCCipherIsolate.syncKey();
    }
  }

  static Future<void> initKey() async {
    final prefs = await SharedPreferences.getInstance();
    final key = prefs.getString('encrypt_key') ?? '';
    if (key.isNotEmpty) {
      setAESKey(Uint8List.fromList(key.codeUnits));
    }
  }

  static Future<void> initIsolate() async {
    final receivePort = ReceivePort();
    await Isolate.spawn(_handler, receivePort.sendPort);
    final sendPort = await receivePort.first;
    CBCCipherIsolate.initSendPort(sendPort);
    await CBCCipherIsolate.syncKey();
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

class CBCCipherIsolate {
  static SendPort? _sendPort;

  static initSendPort(SendPort sendPort) {
    _sendPort = sendPort;
  }

  static Future syncKey() {
    return _send(_sendPort!, {'type': 'update_key', 'data': CBCCipher.aesKey});
  }

  static Future processBodyBytesIsolate(Uint8List bodyBytes) {
    return _send(_sendPort!, {'type': 'decrypt', 'data': bodyBytes});
  }
}

Future _send(SendPort port, msg) {
  final response = ReceivePort();
  port.send([msg, response.sendPort]);
  return response.first;
}

Future<void> _handler(SendPort sendPort) async {
  final port = ReceivePort();
  sendPort.send(port.sendPort);

  await for (var msg in port) {
    final request = msg[0];
    SendPort replyTo = msg[1];

    switch (request['type']) {
      case 'update_key':
        CBCCipher.setAESKey(request['data'], false);
        replyTo.send('Done');
        break;
      case 'decrypt':
        final decrypted = CBCCipher.processBodyBytes(request['data']);
        replyTo.send(decrypted);
        break;
      case 'test':
        replyTo.send('Done');
        break;
      default:
        replyTo.send('Done');
    }
  }
}
