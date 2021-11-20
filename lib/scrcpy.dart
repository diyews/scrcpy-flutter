import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:floatingpanel/floatingpanel.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'android_keycode.dart';
import 'cbc_cipher.dart';

class Scrcpy extends StatefulWidget {
  final String ip;

  const Scrcpy({Key? key, required this.ip}) : super(key: key);

  @override
  _ScrcpyState createState() => _ScrcpyState();
}

class _ScrcpyState extends _ScrcpySocketState {
  final _ScreenShotModel _screenShotModel = _ScreenShotModel();

  @override
  void dispose() {
    _screenShotModel.dispose();

    super.dispose();
  }

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
                    return Container(
                      decoration: const BoxDecoration(color: Colors.black26),
                      child: Stack(
                        children: [
                          Center(
                            child: Text(
                              centerText,
                              style: Theme.of(context).textTheme.headline4,
                            ),
                          ),
                          if (CBCCipher.aesKey.isNotEmpty)
                            _ScreenShot(
                              'http://${widget.ip}:7008/ognahaonogna',
                              screenShotModel: _screenShotModel,
                            )
                        ],
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
              Icons.screenshot,
              Icons.video_camera_back_outlined,
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
                  _screenShotModel.setMode(_ScreenShotMode.one);
                  break;
                case 4:
                  _screenShotModel.setMode(_ScreenShotMode.videoLike);
                  break;
                case 5:
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

  @override
  initState() {
    super.initState();

    try {
      setupSocket();
    } catch (e) {
      centerText = 'Connect failed';
    }
  }

  setupSocket() async {
    await Socket.connect(ip, remotePort).then((socket) {
      videoSocket = socket;
      socket.transform(genVideoStreamTransformer()).listen((event) {
        print(event);
      });
    });
    Socket.connect(ip, remotePort).then((socket) {
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

class _ScreenShot extends StatefulWidget {
  final String url;
  final _ScreenShotModel screenShotModel;

  const _ScreenShot(this.url, {Key? key, required this.screenShotModel})
      : super(key: key);

  @override
  _ScreenShotState createState() => _ScreenShotState();
}

class _ScreenShotState extends State<_ScreenShot> {
  bool running = false;
  late Future<http.Response> imageFuture;
  Uint8List imageBytes = Uint8List(0);

  @override
  void initState() {
    super.initState();
    widget.screenShotModel.addListener(() {
      requestImage();
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  requestImage() async {
    if (running) {
      return;
    }
    running = true;
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final res = await http.get(Uri.parse('${widget.url}?v=$timestamp'));
    if (!mounted) {
      running = false;
      return;
    }
    setState(() {
      imageBytes = CBCCipher.processBodyBytes(res.bodyBytes);
    });
    running = false;
    if (widget.screenShotModel.mode == _ScreenShotMode.one) {
      return;
    }
    return requestImage();
  }

  @override
  Widget build(BuildContext context) {
    return imageBytes.isEmpty
        ? Container()
        : Image.memory(
            imageBytes,
            gaplessPlayback: true,
          );
  }
}

enum _ScreenShotMode { one, videoLike }

class _ScreenShotModel extends ChangeNotifier {
  _ScreenShotMode mode = _ScreenShotMode.one;

  setMode(_ScreenShotMode v) {
    mode = v;
    notifyListeners();
  }
}
