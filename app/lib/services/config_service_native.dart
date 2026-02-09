import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:romifleur/utils/logger.dart';
import 'package:saf_util/saf_util.dart';

const _log = AppLogger('ConfigService');

class ConfigService {
  static const String _kRomsPathKey = 'roms_path';
  static const String _kRaApiKey = 'ra_api_key';
  static const String _kConsolePath = 'console_path_';

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
      _log.error('Error loading consoles.json: $e');
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

  // ===== SAF URI SUPPORT (Android SD Card) =====
  static const String _kRomsUriKey = 'roms_uri';

  /// Check if a path/URI is a SAF content URI
  bool isSafUri(String? pathOrUri) {
    if (pathOrUri == null) return false;
    return pathOrUri.startsWith('content://');
  }

  /// Get SAF URI for downloads (Android SD card)
  String? getDownloadUri() {
    return _prefs.getString(_kRomsUriKey);
  }

  /// Set SAF URI for downloads (Android SD card)
  Future<void> setDownloadUri(String uri) async {
    await _prefs.setString(_kRomsUriKey, uri);
    // Also clear the regular path to avoid confusion
    await _prefs.remove(_kRomsPathKey);
  }

  /// Clear SAF URI
  Future<void> clearDownloadUri() async {
    await _prefs.remove(_kRomsUriKey);
  }

  /// Validates that the stored SAF URI still has read+write permission.
  /// Returns true if no SAF URI is stored (non-SAF path) or if permission is valid.
  /// Returns false if SAF URI is stored but permission has expired/been revoked.
  Future<bool> validateSafPermission() async {
    final uri = getDownloadUri();
    if (uri == null) return true;

    try {
      final safUtil = SafUtil();
      return await safUtil.hasPersistedPermission(
        uri,
        checkRead: true,
        checkWrite: true,
      );
    } catch (e) {
      _log.warning('SAF permission check failed: $e');
      return false;
    }
  }

  /// Get effective download location (URI or path)
  /// Returns the URI if set (SAF), otherwise the path
  Future<String?> getEffectiveDownloadLocation() async {
    final uri = getDownloadUri();
    if (uri != null) return uri;
    return await getDownloadPath();
  }

  String get raApiKey => _prefs.getString(_kRaApiKey) ?? '';

  Future<void> setRaApiKey(String key) async {
    await _prefs.setString(_kRaApiKey, key);
  }

  Map<String, dynamic>? getConsoleConfig(String category, String key) {
    return _consoles[category]?[key];
  }

  // ===== CONSOLE PATH CUSTOMIZATION =====

  /// Get custom path for a console (returns null if using default)
  String? getConsolePath(String consoleKey) {
    return _prefs.getString('$_kConsolePath$consoleKey');
  }

  /// Set custom path for a console
  Future<void> setConsolePath(String consoleKey, String path) async {
    await _prefs.setString('$_kConsolePath$consoleKey', path);
  }

  /// Clear custom path for a console (reset to default)
  Future<void> clearConsolePath(String consoleKey) async {
    await _prefs.remove('$_kConsolePath$consoleKey');
  }

  /// Get all custom console paths (for settings display)
  Map<String, String> getAllConsolePaths() {
    final Map<String, String> paths = {};
    final keys = _prefs.getKeys();
    for (final key in keys) {
      if (key.startsWith(_kConsolePath)) {
        final consoleKey = key.replaceFirst(_kConsolePath, '');
        final value = _prefs.getString(key);
        if (value != null) {
          paths[consoleKey] = value;
        }
      }
    }
    return paths;
  }

  /// List available folders (Web only - stub for native)
  Future<List<String>> listAvailableFolders() async {
    // Native uses file picker, not folder list
    return [];
  }

  /// Create a new folder (Web only - stub for native)
  Future<bool> createFolder(String folderName) async {
    // Native uses file picker to select/create folders
    return false;
  }
}
