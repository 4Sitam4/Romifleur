import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
// No dart:io

class MetadataService {
  static const String _apiKey =
      "60618838ba6187bceb6cef061e6d207f44773204f247f01e62901caff3ede5f7";

  Map<String, dynamic> _cache = {};

  static final MetadataService _instance = MetadataService._internal();
  factory MetadataService() => _instance;
  MetadataService._internal();

  /// Initialize (In-memory only for web)
  Future<void> init() async {
    _cache = {};
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
      // Use Proxy /tgdb/ instead of direct URL
      // https://api.thegamesdb.net/v1/Games/ByGameName
      final uri = Uri.parse("/tgdb/v1/Games/ByGameName").replace(
        queryParameters: {
          "apikey": _apiKey,
          "name": cleanName,
          "fields": "overview,release_date",
          "filter[platform]": platformId.toString(),
          "include": "boxart",
        },
      );

      print('🌐 WEB Metadata Fetch: $uri');
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
                  String imgUrl = "$baseUrl${art['filename']}";
                  // Rewrite for Proxy
                  if (imgUrl.contains('cdn.thegamesdb.net')) {
                    imgUrl = imgUrl.replaceFirst(
                      'https://cdn.thegamesdb.net',
                      '/tgdb-cdn',
                    );
                  }
                  output['image_url'] = imgUrl;
                  break;
                }
              }
            }
          }
        }
      }
    } catch (e) {
      print('❌ Metadata fetch error (Web): $e');
    }

    _cache[cacheKey] = output;
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
