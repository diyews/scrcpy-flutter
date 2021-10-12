import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class Scrcpy extends StatefulWidget {
  final String ip;

  const Scrcpy({Key? key, required this.ip}) : super(key: key);

  @override
  _ScrcpyState createState() => _ScrcpyState(ip: ip);
}

class _ScrcpyState extends State<Scrcpy> {
  final String ip;
  Socket? videoSocket;
  Socket? controlSocket;
  String deviceName = '';
  int deviceWidth = 0;
  int deviceHeight = 0;

  _ScrcpyState({required this.ip}) {
    setupSocket();
  }

  setupSocket() async {
    await Socket.connect(ip, 7007).then((socket) {
      videoSocket = socket;
      socket.transform(genVideoStreamTransformer()).listen((event) {
        print(event);
      });
    });
    Socket.connect(ip, 7007).then((socket) {
      controlSocket = socket;
      socket.listen((event) {
        print(event);
      });
    });
  }

  StreamTransformer<Uint8List, dynamic> genVideoStreamTransformer() {
    int headCurrentByteCount = 0;

    return StreamTransformer.fromHandlers(
      handleData: (data, sink) {
        print(data);
        sink.add(data);
        for (var i = 0; i < data.length; ++i) {
          var o = data[i];
          // 69 = 1 + 64 + 4
          if (++headCurrentByteCount <= 69 && headCurrentByteCount > 1) {
            if (headCurrentByteCount <= 65 && o > 0) {
              deviceName += String.fromCharCode(o);
            }
            if (headCurrentByteCount == 66) {
              deviceWidth += o << 8;
            }
            if (headCurrentByteCount == 67) {
              deviceWidth += o;
            }
            if (headCurrentByteCount == 68) {
              deviceHeight += o << 8;
            }
            if (headCurrentByteCount == 69) {
              deviceHeight += o;
              print(deviceName);
              print(deviceWidth);
              print(deviceHeight);
            }
          }
        }
      },
    );
  }

  sendPointerEvent(PointerEvent details, double devicePixelRatio, int type) {
    int x = (details.position.dx * devicePixelRatio).floor();
    int y = (details.position.dy * devicePixelRatio).floor();
    var bd = BytesBuilder();
    bd.addByte(2);
    bd.addByte(type);
    bd.add(Uint8List(8)..buffer.asByteData().setInt64(0, 1, Endian.big));
    bd.add(Uint8List(4)..buffer.asByteData().setInt32(0, x, Endian.big));
    bd.add(Uint8List(4)..buffer.asByteData().setInt32(0, y, Endian.big));
    bd.add(
        Uint8List(2)..buffer.asByteData().setInt16(0, deviceWidth, Endian.big));
    bd.add(Uint8List(2)
      ..buffer.asByteData().setInt16(0, deviceHeight, Endian.big));
    bd.add(
        Uint8List(2)..buffer.asByteData().setInt16(0, 255 * 255, Endian.big));
    bd.add(Uint8List(4)..buffer.asByteData().setInt32(0, 0, Endian.big));
    controlSocket!.add(bd.toBytes());
  }

  @override
  void dispose() {
    super.dispose();

    videoSocket?.destroy();
    controlSocket?.destroy();
  }

  @override
  Widget build(BuildContext context) {
    final double devicePixelRatio = MediaQuery.of(context).devicePixelRatio;

    return Scaffold(
      body: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerUp: (details) {
          sendPointerEvent(details, devicePixelRatio, 1);
        },
        onPointerMove: (details) {
          sendPointerEvent(details, devicePixelRatio, 2);
        },
        onPointerDown: (details) {
          sendPointerEvent(details, devicePixelRatio, 0);
        },
        child: Center(
          // Center is a layout widget. It takes a single child and positions it
          // in the middle of the parent.
          child: Column(
            // Column is also a layout widget. It takes a list of children and
            // arranges them vertically. By default, it sizes itself to fit its
            // children horizontally, and tries to be as tall as its parent.
            //
            // Invoke "debug painting" (press "p" in the console, choose the
            // "Toggle Debug Paint" action from the Flutter Inspector in Android
            // Studio, or the "Toggle Debug Paint" command in Visual Studio Code)
            // to see the wireframe for each widget.
            //
            // Column has various properties to control how it sizes itself and
            // how it positions its children. Here we use mainAxisAlignment to
            // center the children vertically; the main axis here is the vertical
            // axis because Columns are vertical (the cross axis would be
            // horizontal).
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text(
                'A',
                style: Theme.of(context).textTheme.headline4,
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: null,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}
