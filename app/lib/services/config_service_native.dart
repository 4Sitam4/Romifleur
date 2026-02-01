import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'package:path/path.dart' as p;

class ConfigService {
  static const String _kRomsPathKey = 'roms_path';
  static const String _kRaApiKey = 'ra_api_key';

  late SharedPreferences _prefs;
  Map<String, Map<String, dynamic>> _consoles = {};

  // Singleton pattern is managed by the main factory in config_service.dart
  // But for the impl classes, we can just expose a normal class or singleton
  static final ConfigService _instance = ConfigService._internal();
  factory ConfigService() => _instance;
  ConfigService._internal();

  bool _isInitialized = false;

  /// Initialize the service
  Future<void> init() async {
    if (_isInitialized) return;
    _prefs = await SharedPreferences.getInstance();
    await _loadConsoles();
    _isInitialized = true;
  }

  /// Load consoles.json from assets
  Future<void> _loadConsoles() async {
    try {
      final String jsonString = await rootBundle.loadString(
        'assets/data/consoles.json',
      );
      final Map<String, dynamic> data = json.decode(jsonString);

      // Transform to expected format: Category -> { ConsoleKey -> Data }
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

  /// Get simplified map of all consoles
  Map<String, Map<String, dynamic>> get consoles => _consoles;

  /// Get persistent data directory for app (Caches, Logs, Default ROMs)
  Future<String> getDataDir() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final path = p.join(docsDir.path, 'Romifleur');
    await Directory(path).create(recursive: true);
    return path;
  }

  /// Get configured ROMs download path
  /// Get configured ROMs download path
  Future<String?> getDownloadPath() async {
    final String? savedPath = _prefs.getString(_kRomsPathKey);
    if (savedPath != null && await Directory(savedPath).exists()) {
      return savedPath;
    }

    return null;
  }

  Future<void> setDownloadPath(String path) async {
    await _prefs.setString(_kRomsPathKey, path);
  }

  String get raApiKey => _prefs.getString(_kRaApiKey) ?? '';

  Future<void> setRaApiKey(String key) async {
    await _prefs.setString(_kRaApiKey, key);
  }

  Map<String, dynamic>? getConsoleConfig(String category, String key) {
    return _consoles[category]?[key];
  }
}
