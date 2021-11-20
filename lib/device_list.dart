import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:scrcpy_flutter/cbc_cipher.dart';
import 'package:scrcpy_flutter/scrcpy.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DeviceList extends StatefulWidget {
  const DeviceList({Key? key, required this.refreshNotifier}) : super(key: key);
  final ChangeNotifier refreshNotifier;

  @override
  _DeviceListState createState() => _DeviceListState();
}

class _DeviceListState extends State<DeviceList> {
  List<_DeviceWidget> _deviceWidgetList = [];
  SharedPreferences? prefs;

  @override
  void initState() {
    super.initState();

    SharedPreferences.getInstance().then((prefs) {
      this.prefs = prefs;
      final devicesStr = prefs.getString('queried_devices') ?? '';
      if (devicesStr.isEmpty) {
        batchQueryWrapped();
      } else if (CBCCipher.aesKey.isNotEmpty) {
        _deviceWidgetList.addAll(_DeviceWidget.jsonStringToList(devicesStr));
      }

      /* clear and refresh */
      widget.refreshNotifier.addListener(() async {
        _deviceWidgetList = [];
        prefs.remove('queried_devices');
        batchQueryWrapped();
      });
    });
  }

  batchQueryWrapped() {
    if (CBCCipher.aesKey.isNotEmpty) {
      batchQuery();
    }
  }

  batchQuery() {
    final List<String> prefixList = ['192.168.0', '192.168.1'];

    for (var element in prefixList) {
      for (var i = 1; i < 255; ++i) {
        query('$element.$i');
      }
    }
  }

  query(String ip) async {
    try {
      final res = await http.get(Uri.parse('http://$ip:7008/huinyegrbizgn'));
      final bytes = CBCCipher.processBodyBytes(res.bodyBytes);
      final name = String.fromCharCodes(bytes);
      setState(() {
        _deviceWidgetList.add(_DeviceWidget(ip: ip, name: name));
      });
      prefs!.setString(
          'queried_devices', _DeviceWidget.listToJsonString(_deviceWidgetList));
    } catch (e) {
      /* ignore */
    }
  }

  @override
  Widget build(BuildContext context) {
    return CBCCipher.aesKey.isNotEmpty
        ? GridView.count(
            crossAxisCount: 2,
            padding: const EdgeInsets.all(10),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            children: _deviceWidgetList,
          )
        : const Center(
            child: Text('Please set key'),
          );
  }
}

class _DeviceWidget extends StatefulWidget {
  final String name;
  final String ip;

  const _DeviceWidget({Key? key, required this.ip, this.name = ''})
      : super(key: key);

  static String listToJsonString(List<_DeviceWidget> list) {
    return jsonEncode(list.map((e) => {"ip": e.ip, "name": e.name}).toList());
  }

  static List<_DeviceWidget> jsonStringToList(String str) {
    return (jsonDecode(str) as List<dynamic>)
        .map((e) => _DeviceWidget(
              ip: e['ip']!,
              name: e['name']!,
            ))
        .toList();
  }

  @override
  _DeviceWidgetState createState() => _DeviceWidgetState();
}

class _DeviceWidgetState extends State<_DeviceWidget> {
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => Scrcpy(
                  ip: widget.ip,
                )));
      },
      child: Container(
          alignment: Alignment.center,
          decoration: const BoxDecoration(color: Colors.black26),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(widget.name),
              const SizedBox(
                height: 2,
              ),
              Text(
                widget.ip,
                style: const TextStyle(color: Colors.black26, fontSize: 12),
              ),
            ],
          )),
    );
  }
}
