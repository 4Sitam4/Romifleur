import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

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
  /// Web: Browser handles downloads. This path is essentially ignored/dummy.
  Future<String?> getDownloadPath() async {
    return 'Downloads'; // Dummy return (Non-null implies configured)
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

  // ===== CONSOLE PATH CUSTOMIZATION (Web - Server API) =====

  // Cache for console paths from server
  Map<String, String> _consolePaths = {};
  List<String> _availableFolders = [];
  bool _pathsLoaded = false;

  /// Fetch console-folder mappings from server
  Future<void> _ensurePathsLoaded() async {
    if (_pathsLoaded) return;
    try {
      final response = await http.get(Uri.parse('/api/console-paths'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        _consolePaths = data.map((k, v) => MapEntry(k, v.toString()));
        _pathsLoaded = true;
      }
    } catch (e) {
      print('❌ Error loading console paths: $e');
    }
  }

  /// Get custom folder for a console (returns null if using default)
  String? getConsolePath(String consoleKey) {
    // Trigger async load if not loaded yet (will be empty on first call)
    if (!_pathsLoaded) _ensurePathsLoaded();
    return _consolePaths[consoleKey];
  }

  /// Set custom folder for a console (calls server API)
  Future<void> setConsolePath(String consoleKey, String folderName) async {
    try {
      final response = await http.post(
        Uri.parse('/api/console-paths'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'console': consoleKey, 'folder': folderName}),
      );
      if (response.statusCode == 200) {
        _consolePaths[consoleKey] = folderName;
      }
    } catch (e) {
      print('❌ Error setting console path: $e');
    }
  }

  /// Clear custom folder for a console (reset to default)
  Future<void> clearConsolePath(String consoleKey) async {
    try {
      final response = await http.delete(
        Uri.parse('/api/console-paths/$consoleKey'),
      );
      if (response.statusCode == 200) {
        _consolePaths.remove(consoleKey);
      }
    } catch (e) {
      print('❌ Error clearing console path: $e');
    }
  }

  /// Get all custom console paths
  Map<String, String> getAllConsolePaths() {
    return Map.from(_consolePaths);
  }

  /// List available folders in the download directory
  Future<List<String>> listAvailableFolders() async {
    try {
      final response = await http.get(Uri.parse('/api/folders'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as List;
        _availableFolders = data.map((e) => e.toString()).toList();
        return _availableFolders;
      }
    } catch (e) {
      print('❌ Error listing folders: $e');
    }
    return [];
  }

  /// Create a new folder on the server
  Future<bool> createFolder(String folderName) async {
    try {
      final response = await http.post(
        Uri.parse('/api/folders'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'name': folderName}),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        _availableFolders.add(folderName);
        return true;
      }
    } catch (e) {
      print('❌ Error creating folder: $e');
    }
    return false;
  }
}
