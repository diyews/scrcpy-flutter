import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:floatingpanel/floatingpanel.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'android_keycode.dart';

class Scrcpy extends StatefulWidget {
  final String ip;

  const Scrcpy({Key? key, required this.ip}) : super(key: key);

  @override
  _ScrcpyState createState() => _ScrcpyState();
}

class _ScrcpyState extends _ScrcpySocketState {
  @override
  Widget build(BuildContext context) {
    final double devicePixelRatio = MediaQuery.of(context).devicePixelRatio;

    return Scaffold(
      body: Stack(
        children: [
          Center(
            child: OrientationBuilder(builder: (context, orientation) {
              if ((orientation == Orientation.portrait &&
                      deviceHeight < deviceWidth) ||
                  (orientation == Orientation.landscape &&
                      deviceHeight > deviceWidth)) {
                final int tmp = deviceHeight;
                deviceHeight = deviceWidth;
                deviceWidth = tmp;
              }
              return AspectRatio(
                aspectRatio:
                    deviceWidth == 0 ? 9 / 16 : deviceWidth / deviceHeight,
                child: Listener(
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
                  child: LayoutBuilder(builder: (context, constraints) {
                    touchableSize =
                        Size(constraints.maxWidth, constraints.maxHeight);
                    if (connected) {
                      positionScale = deviceHeight /
                          (touchableSize.height * devicePixelRatio);
                    }
                    print(videoAndroidView);
                    print(constraints);
                    return SizedBox(
                      width: constraints.maxWidth,
                      height: constraints.maxHeight,
                      child: const AndroidView(
                        viewType: 'scrcpy-surface-view',
                      ),
                    );
                  }),
                ),
              );
            }),
          ),
          FloatBoxPanel(
            positionTop: 50,
            size: 50,
            backgroundColor: Theme.of(context).colorScheme.primary,
            dockType: DockType.inside,
            defaultDock: true,
            buttons: const [
              Icons.arrow_back,
              Icons.home,
              Icons.menu,
              Icons.power_settings_new,
            ],
            onPressed: (int index) {
              switch (index) {
                case 0:
                  sendBackEvent();
                  break;
                case 1:
                  sendKeyEvent(AndroidKeycode.AKEYCODE_HOME);
                  break;
                case 2:
                  sendKeyEvent(AndroidKeycode.AKEYCODE_APP_SWITCH);
                  break;
                case 3:
                  sendKeyEvent(AndroidKeycode.AKEYCODE_POWER);
                  break;
                default:
              }
            },
          ),
        ],
      ),
    );
  }
}

abstract class _ScrcpySocketState extends State<Scrcpy> {
  static const scrcpyChannel = MethodChannel('diye.ws/scrcpy');
  static const int remotePort = 7007;
  String get ip => widget.ip;
  Socket? videoSocket;
  Socket? controlSocket;
  String deviceName = '';
  int deviceWidth = 0;
  int deviceHeight = 0;
  bool connected = false;
  Size touchableSize = Size.zero;
  double positionScale = 0;
  String centerText = 'A';
  AndroidView? videoAndroidView;

  @override
  initState() {
    super.initState();

    try {
      WidgetsBinding.instance?.addPostFrameCallback((timeStamp) {
        setupSocket();
      });
    } catch (e) {
      centerText = 'Connect failed';
    }
  }

  setupSocket() async {
    final Map<dynamic, dynamic> value = await scrcpyChannel
        .invokeMethod('connectVideo', {'ip': ip, 'port': remotePort});
    print(value);
    if (value.isNotEmpty) {
      setState(() {
        deviceName = value['name'];
        deviceWidth = value['width'];
        deviceHeight = value['height'];
      });
    }
    await Future.delayed(const Duration(milliseconds: 1500));
    await Socket.connect(ip, remotePort).then((socket) {
      controlSocket = socket;
      socket.listen((event) {
        print(event);
      });
    });
    await scrcpyChannel.invokeMethod('start');
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
              connected = true;
              centerText = deviceName;
              setState(() {});
            }
          }
        }
      },
    );
  }

  sendPointerEvent(PointerEvent details, double devicePixelRatio, int type) {
    int x =
        (details.localPosition.dx * positionScale * devicePixelRatio).floor();
    int y =
        (details.localPosition.dy * positionScale * devicePixelRatio).floor();
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

  sendBackEvent() {
    var bd = BytesBuilder();
    bd.addByte(4);
    bd.addByte(0);
    bd.addByte(4);
    bd.addByte(1);
    controlSocket!.add(bd.toBytes());
  }

  sendKeyEvent(int keycode) {
    var bd = BytesBuilder();
    bd.addByte(0);
    bd.addByte(0);
    bd.add(Uint8List(4)..buffer.asByteData().setInt32(0, keycode, Endian.big));
    bd.add(Uint8List(4)..buffer.asByteData().setInt32(0, 0, Endian.big));
    bd.add(Uint8List(4)..buffer.asByteData().setInt32(0, 0, Endian.big));

    bd.addByte(0);
    bd.addByte(1);
    bd.add(Uint8List(4)..buffer.asByteData().setInt32(0, keycode, Endian.big));
    bd.add(Uint8List(4)..buffer.asByteData().setInt32(0, 0, Endian.big));
    bd.add(Uint8List(4)..buffer.asByteData().setInt32(0, 0, Endian.big));
    controlSocket!.add(bd.toBytes());
  }

  @override
  void dispose() {
    super.dispose();

    videoSocket?.destroy();
    controlSocket?.destroy();
  }
}
