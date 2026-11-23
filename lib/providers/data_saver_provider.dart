import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Mode hemat data untuk mengurangi unduhan gambar sampul.
class DataSaverProvider extends ChangeNotifier {
  static const _key = 'data_saver';

  bool _enabled = false;

  bool get enabled => _enabled;

  late final Future<void> ready;

  DataSaverProvider() {
    ready = _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _enabled = prefs.getBool(_key) ?? false;
    notifyListeners();
  }

  Future<void> setEnabled(bool value) async {
    _enabled = value;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, value);
  }
}
