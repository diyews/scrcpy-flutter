import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:scrcpy_flutter/cbc_cipher.dart';
import 'package:scrcpy_flutter/device_list.dart';
import 'package:scrcpy_flutter/scrcpy.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await CBCCipher.initIsolate();
  await CBCCipher.initKey();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Scrcpy flutter',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // Try running your application with "flutter run". You'll see the
        // application has a blue toolbar. Then, without quitting the app, try
        // changing the primarySwatch below to Colors.green and then invoke
        // "hot reload" (press "r" in the console where you ran "flutter run",
        // or simply save your changes to "hot reload" in a Flutter IDE).
        // Notice that the counter didn't reset back to zero; the application
        // is not restarted.
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key}) : super(key: key);

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  SharedPreferences? prefs;
  final refreshDeviceNotifier = ChangeNotifier();

  _MyHomePageState() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: []);
  }

  void _incrementCounter(BuildContext context) async {
    prefs ??= await SharedPreferences.getInstance();
    String? ip = prefs!.getString('lastDeviceIP');
    TextEditingController _controller = TextEditingController()
      ..text = (ip ?? '192.168.1.151');
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('IP'),
          titlePadding: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
          contentPadding:
              const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
          content: TextField(
            controller: _controller,
            autofocus: true,
          ),
          actions: [
            ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop(_controller.value.text);
                },
                child: Text('OK'))
          ],
        );
      },
    ).then((val) {
      print(val);
      if (val == null) return;
      prefs!.setString('lastDeviceIP', val);
      Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => Scrcpy(
                ip: val,
              )));
    });
  }

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      appBar: AppBar(
        title: Text('X'),
        actions: [
          IconButton(
              onPressed: () {
                refreshDeviceNotifier.notifyListeners();
              },
              icon: const Icon(Icons.refresh)),
          PopupMenuButton(itemBuilder: (_context) {
            return [
              PopupMenuItem(
                child: const Text('Key'),
                onTap: () {
                  Timer.run(() async {
                    final result = await _openEditEncryptKeyDialog(context);
                    if (result.isNotEmpty) {
                      refreshDeviceNotifier.notifyListeners();
                    }
                  });
                },
              )
            ];
          }),
        ],
      ),
      resizeToAvoidBottomInset: false,
      body: Center(
        // Center is a layout widget. It takes a single child and positions it
        // in the middle of the parent.
        child: DeviceList(
          refreshNotifier: refreshDeviceNotifier,
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _incrementCounter(context),
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}

Future<String> _openEditEncryptKeyDialog(BuildContext context) async {
  final prefs = await SharedPreferences.getInstance();
  final String key = prefs.getString('encrypt_key') ?? '';

  TextEditingController _controller = TextEditingController()..text = key;

  return showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('Key(16 length)'),
        titlePadding: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
        contentPadding: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
        content: TextField(
          controller: _controller,
          autofocus: true,
        ),
        actions: [
          ElevatedButton(
              onPressed: () {
                final text = _controller.text;
                prefs.setString('encrypt_key', text);
                CBCCipher.setAESKey(Uint8List.fromList(text.codeUnits));
                Navigator.of(context).pop(text);
              },
              child: const Text('OK')),
        ],
      );
    },
  ).then((value) {
    return value ?? '';
  });
}
