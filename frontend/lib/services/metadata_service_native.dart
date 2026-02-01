import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:romifleur/services/config_service.dart';

class MetadataService {
  static const String _apiKey =
      "60618838ba6187bceb6cef061e6d207f44773204f247f01e62901caff3ede5f7";

  final ConfigService _config = ConfigService();
  Map<String, dynamic> _cache = {};

  static final MetadataService _instance = MetadataService._internal();
  factory MetadataService() => _instance;
  MetadataService._internal();

  /// Initialize and load cache
  Future<void> init() async {
    await _loadCache();
  }

  Future<void> _loadCache() async {
    final dir = await _config.getDataDir();
    final file = File(p.join(dir, 'metadata_cache.json'));
    if (await file.exists()) {
      try {
        final content = await file.readAsString();
        _cache = json.decode(content);
      } catch (e) {
        print('⚠️ Error loading metadata cache: $e');
      }
    }
  }

  Future<void> _saveCache() async {
    final dir = await _config.getDataDir();
    final file = File(p.join(dir, 'metadata_cache.json'));
    await file.writeAsString(json.encode(_cache));
  }

  /// Get metadata for a game
  Future<Map<String, dynamic>> getMetadata(
    String consoleKey,
    String filename,
  ) async {
    final cacheKey = '$consoleKey|$filename';
    if (_cache.containsKey(cacheKey)) {
      return Map<String, dynamic>.from(_cache[cacheKey]);
    }

    final cleanName = _cleanFilename(filename);
    final platformId = _getPlatformId(consoleKey);

    // Default
    final Map<String, dynamic> output = {
      "title": cleanName,
      "description": "No description available.",
      "date": "Unknown",
      "image_url": null,
      "provider": "Local",
      "has_achievements": false,
    };

    if (platformId == null) {
      return output;
    }

    try {
      // Fetch from TGDB
      final uri = Uri.parse("https://api.thegamesdb.net/v1/Games/ByGameName")
          .replace(
            queryParameters: {
              "apikey": _apiKey,
              "name": cleanName,
              "fields": "overview,release_date",
              "filter[platform]": platformId.toString(),
              "include": "boxart",
            },
          );

      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['data']['games'] != null &&
            (data['data']['games'] as List).isNotEmpty) {
          final game = data['data']['games'][0];
          final gameId = game['id'];

          output['title'] = game['game_title'] ?? cleanName;
          output['description'] = game['overview'] ?? output['description'];
          output['date'] = game['release_date'] ?? output['date'];
          output['provider'] = "TheGamesDB";

          // Extract Boxart
          if (data['include']?['boxart'] != null) {
            final boxarts = data['include']['boxart'];
            final baseUrl = boxarts['base_url']['medium'];
            final gameArts = boxarts['data'][gameId.toString()];

            if (gameArts != null && gameArts is List) {
              for (var art in gameArts) {
                if (art['side'] == 'front') {
                  output['image_url'] = "$baseUrl${art['filename']}";
                  break;
                }
              }
            }
          }
        }
      }
    } catch (e) {
      print('❌ Metadata fetch error: $e');
    }

    _cache[cacheKey] = output;
    _saveCache(); // Fire and forget save
    return output;
  }

  String _cleanFilename(String filename) {
    String name = p.basenameWithoutExtension(filename);
    name = name.replaceAll(RegExp(r'\s*[\(\[].*?[\)\]]'), '');
    return name.trim();
  }

  int? _getPlatformId(String key) {
    const map = {
      "NES": 7,
      "SNES": 6,
      "N64": 3,
      "GameCube": 2,
      "GB": 4,
      "GBC": 41,
      "GBA": 5,
      "NDS": 8,
      "3DS": 4912,
      "MasterSystem": 35,
      "MegaDrive": 18,
      "Saturn": 17,
      "Dreamcast": 16,
      "GameGear": 20,
      "PS1": 10,
      "PSP": 13,
      "PS2": 11,
      "NeoGeo": 4923,
      "PC_Engine": 34,
      "Atari2600": 22,
    };
    return map[key];
  }
}
