import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:romifleur/models/game_metadata.dart';
import 'package:romifleur/services/metadata_providers/metadata_provider.dart';

class TgdbProvider implements MetadataProvider {
  static const String _apiKey =
      "60618838ba6187bceb6cef061e6d207f44773204f247f01e62901caff3ede5f7";

  // Base URL can be overridden for proxy support (web)
  final String _baseUrl;

  TgdbProvider({String baseUrl = "https://api.thegamesdb.net"})
    : _baseUrl = baseUrl;

  @override
  String get name => "TheGamesDB";

  @override
  Future<GameMetadata?> search(String gameName, String consoleKey) async {
    final platformId = getPlatformId(consoleKey);
    if (platformId == null) return null;

    try {
      final uri = Uri.parse("$_baseUrl/v1/Games/ByGameName").replace(
        queryParameters: {
          "apikey": _apiKey,
          "name": gameName,
          "fields":
              "overview,release_date,players,publishers,developers,genres", // Added fields
          "filter[platform]": platformId.toString(),
          "include": "boxart,developer,publisher,genre", // Added includes
        },
      );

      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['data']['games'] != null &&
            (data['data']['games'] as List).isNotEmpty) {
          final game = data['data']['games'][0];
          final gameId = game['id'];

          String? imageUrl;

          // Extract Boxart
          if (data['include']?['boxart'] != null) {
            final boxarts = data['include']['boxart'];
            final baseUrl = boxarts['base_url']['medium'];
            final gameArts = boxarts['data'][gameId.toString()];

            if (gameArts != null && gameArts is List) {
              for (var art in gameArts) {
                if (art['side'] == 'front') {
                  imageUrl = "$baseUrl${art['filename']}";

                  // Handle proxy rewrite for Web if needed
                  if (_baseUrl.startsWith('/tgdb') && imageUrl != null) {
                    if (imageUrl!.contains('cdn.thegamesdb.net')) {
                      imageUrl = imageUrl!.replaceFirst(
                        'https://cdn.thegamesdb.net',
                        '/tgdb-cdn',
                      );
                    }
                  }

                  break;
                }
              }
            }
          }

          // Extract extra fields
          return GameMetadata(
            title: game['game_title'] ?? gameName,
            description: game['overview'],
            releaseDate: game['release_date'],
            imageUrl: imageUrl,
            provider: name,
            developer: _resolveNames(
              game['developers'],
              data['include']?['developer']?['data'],
            ),
            publisher: _resolveNames(
              game['publishers'],
              data['include']?['publisher']?['data'],
            ),
            genre: _resolveNames(
              game['genres'],
              data['include']?['genre']?['data'],
            ),
            rating: game['rating'],
            players: game['players']?.toString(),
          );
        }
      }
    } catch (e) {
      print('❌ TGDB Metadata fetch error: $e');
    }
    return null;
  }

  String? _resolveNames(dynamic ids, dynamic includedData) {
    if (ids is List && ids.isNotEmpty && includedData is Map) {
      final names = <String>[];
      for (var id in ids) {
        final idStr = id.toString();
        if (includedData.containsKey(idStr)) {
          names.add(includedData[idStr]['name']);
        }
      }
      if (names.isNotEmpty) return names.join(', ');
    }
    return null;
  }

  int? getPlatformId(String key) {
    const map = {
      "NES": 7,
      "SNES": 6,
      "N64": 3,
      "GameCube": 2,
      "Wii": 9,
      "WiiU": 38,
      "GB": 4,
      "GBC": 41,
      "GBA": 5,
      "NDS": 8,
      "3DS": 4912,
      "VirtualBoy": 4918,
      "MasterSystem": 35,
      "MegaDrive": 18,
      "Sega32X": 33,
      "SegaCD": 21,
      "Saturn": 17,
      "Dreamcast": 16,
      "GameGear": 20,
      "SG1000": 4949,
      "PS1": 10,
      "PS2": 11,
      "PS3": 12,
      "PSP": 13,
      "PSVita": 39,
      "Xbox": 14,
      "Xbox360": 15,
      "NeoGeo": 24, // Added NeoGeo
      "NeoGeoPocket": 4922,
      "NeoGeoPocketColor": 4923,
      "PC_Engine": 34,
      "PC_Engine_CD": 4955,
      "SuperGrafx": 34, // Fallback to PC Engine/TG16 as no specific ID exists
      "Atari2600": 22,
      "Atari5200": 26,
      "Atari7800": 27,
      "AtariLynx": 4924,
      "AtariJaguar": 28,
      "AtariJaguarCD": 29,
    };
    return map[key];
  }
}
