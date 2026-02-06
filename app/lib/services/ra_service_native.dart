import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:romifleur/services/config_service.dart';
import 'package:romifleur/utils/logger.dart';

const _log = AppLogger('RaService');

class RaService {
  static const String _baseUrl = "https://retroachievements.org/API";

  final ConfigService _config = ConfigService();
  Map<String, List<dynamic>> _cache = {}; // ConsoleID -> List of Games
  Timer? _saveTimer;

  static final RaService _instance = RaService._internal();
  factory RaService() => _instance;
  RaService._internal();

  Future<void> init() async {
    await _loadCache();
  }

  Future<void> _loadCache() async {
    final dir = await _config.getDataDir();
    final file = File(p.join(dir, 'ra_cache.json'));
    if (await file.exists()) {
      try {
        final content = await file.readAsString();
        final decoded = json.decode(content);
        _cache = {};
        decoded.forEach((k, v) {
          _cache[k] = List<dynamic>.from(v);
        });
      } catch (e) {
        _log.warning('Error loading RA cache: $e');
      }
    }
  }

  void _scheduleSaveCache() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 500), () {
      _doSaveCache();
    });
  }

  Future<void> _doSaveCache() async {
    try {
      final dir = await _config.getDataDir();
      final file = File(p.join(dir, 'ra_cache.json'));
      await file.writeAsString(json.encode(_cache));
    } catch (e) {
      print('⚠️ Error saving RA cache: $e');
    }
  }

  /// Get/Validate API Key
  String get _apiKey => _config.raApiKey;

  Future<bool> validateKey(String key) async {
    try {
      final uri = Uri.parse(
        "$_baseUrl/API_GetConsoleIDs.php",
      ).replace(queryParameters: {"y": key});
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data is List && data.isNotEmpty;
      }
    } catch (e) {
      _log.error('RA Key Validation Error: $e');
    }
    return false;
  }

  /// Check if a ROM is compatible with RA
  Future<bool> checkRomCompatibility(String consoleKey, String filename) async {
    final apiKey = _apiKey;
    if (apiKey.isEmpty) return false;

    final consoleId = _getConsoleId(consoleKey);
    if (consoleId == null) return false;

    final games = await _fetchGameList(consoleId, apiKey);
    return _isCompatible(filename, games);
  }

  Future<List<dynamic>> _fetchGameList(int consoleId, String apiKey) async {
    final cid = consoleId.toString();
    if (_cache.containsKey(cid)) {
      return _cache[cid]!;
    }

    try {
      final uri = Uri.parse("$_baseUrl/API_GetGameList.php").replace(
        queryParameters: {
          "y": apiKey,
          "i": cid,
          "f": "1", // Only with achievements
        },
      );

      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is List) {
          // Minimize storage
          final simplified = data
              .map((g) => {"Title": g["Title"], "ID": g["ID"]})
              .toList();

          _cache[cid] = simplified;
          _scheduleSaveCache();
          return simplified;
        }
      }
    } catch (e) {
      _log.error('RA Fetch Error: $e');
    }
    return [];
  }

  bool _isCompatible(String filename, List<dynamic> games) {
    String cleanName = p.basenameWithoutExtension(filename);
    cleanName = cleanName
        .replaceAll(RegExp(r'\s*[\(\[].*?[\)\]]'), '')
        .trim()
        .toLowerCase();

    for (var game in games) {
      String raTitle = game['Title'].toString();
      raTitle = raTitle
          .replaceAll(RegExp(r'\s*[\(\[].*?[\)\]]'), '')
          .trim()
          .toLowerCase();

      if (cleanName == raTitle) return true;
      if (cleanName.length > 10 && cleanName.contains(raTitle)) return true;
    }
    return false;
  }

  int? _getConsoleId(String key) {
    const map = {
      "NES": 7,
      "SNES": 3,
      "N64": 2,
      "GameCube": 16,
      "GB": 4,
      "GBC": 6,
      "GBA": 5,
      "NDS": 18,
      "MasterSystem": 11,
      "MegaDrive": 1,
      "Saturn": 39,
      "Dreamcast": 40,
      "GameGear": 15,
      "PS1": 12,
      "PSP": 41,
      "PS2": 21,
      "NeoGeo": 29,
      "PC_Engine": 8,
      "Atari2600": 25,
      "Wii": 19,
      "3DS": 62,
    };
    return map[key];
  }
}
