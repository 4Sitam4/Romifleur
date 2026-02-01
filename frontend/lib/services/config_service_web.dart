import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

// No dart:io or path_provider imports here

class ConfigService {
  static const String _kRaApiKey = 'ra_api_key';

  late SharedPreferences _prefs;
  Map<String, Map<String, dynamic>> _consoles = {};

  static final ConfigService _instance = ConfigService._internal();
  factory ConfigService() => _instance;
  ConfigService._internal();

  /// Initialize the service
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    await _loadConsoles();
  }

  /// Load consoles.json from assets
  Future<void> _loadConsoles() async {
    try {
      final String jsonString = await rootBundle.loadString(
        'assets/data/consoles.json',
      );
      final Map<String, dynamic> data = json.decode(jsonString);

      _consoles = {};
      data.forEach((category, consoles) {
        if (consoles is Map) {
          _consoles[category] = Map<String, dynamic>.from(consoles);
        }
      });
    } catch (e) {
      print('❌ Error loading consoles.json: $e');
    }
  }

  Map<String, Map<String, dynamic>> get consoles => _consoles;

  /// Web: No local data dir CONCEPT
  Future<String> getDataDir() async {
    return ''; // No-op on web
  }

  /// Web: Browser handles downloads. This path is essentially ignored/dummy.
  Future<String> getDownloadPath() async {
    return 'Downloads'; // Dummy return
  }

  Future<void> setDownloadPath(String path) async {
    // No-op on web
  }

  String get raApiKey => _prefs.getString(_kRaApiKey) ?? '';

  Future<void> setRaApiKey(String key) async {
    await _prefs.setString(_kRaApiKey, key);
  }

  Map<String, dynamic>? getConsoleConfig(String category, String key) {
    return _consoles[category]?[key];
  }
}
