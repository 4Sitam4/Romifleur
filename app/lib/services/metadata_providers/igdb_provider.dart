import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:romifleur/models/game_metadata.dart';
import 'package:romifleur/services/metadata_providers/metadata_provider.dart';

class IgdbProvider implements MetadataProvider {
  static const String _clientId = "n8z4dla3zzfrdwxbeptpyjonwa54v7";
  static const String _clientSecret = "etx9zqpya4wcr3wdefleaavqt2ufo1";

  final String _authUrl;
  final String _baseUrl;

  String? _accessToken;
  DateTime? _tokenExpiry;

  IgdbProvider({
    String authUrl = "https://id.twitch.tv/oauth2/token",
    String baseUrl = "https://api.igdb.com/v4",
  }) : _authUrl = authUrl,
       _baseUrl = baseUrl;

  @override
  String get name => "IGDB";

  Future<String?> _getToken() async {
    if (_accessToken != null &&
        _tokenExpiry != null &&
        DateTime.now().isBefore(_tokenExpiry!)) {
      return _accessToken;
    }

    try {
      // Note: For Web, this might need a proxy if CORS blocks it.
      // But assuming Native for now as primary concern or Proxy being handled.
      final response = await http.post(
        Uri.parse(_authUrl),
        body: {
          'client_id': _clientId,
          'client_secret': _clientSecret,
          'grant_type': 'client_credentials',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _accessToken = data['access_token'];
        // Buffer of 5 minutes
        _tokenExpiry = DateTime.now().add(
          Duration(seconds: data['expires_in'] - 300),
        );
        return _accessToken;
      } else {
        print('❌ IGDB Auth Failed: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('❌ IGDB Auth Error: $e');
    }
    return null;
  }

  @override
  Future<GameMetadata?> search(String gameName, String consoleKey) async {
    final token = await _getToken();
    if (token == null) return null;

    final platformId = getPlatformId(consoleKey);
    // If platform not mapped, we can try searching without platform or just fail.
    // Better to be specific to avoid bad matches.
    if (platformId == null) return null;

    try {
      // IGDB uses Apicalypse query language in body
      final body =
          '''
fields name, summary, first_release_date, cover.url, total_rating, genres.name, involved_companies.company.name, involved_companies.developer, involved_companies.publisher;
where name ~ *"$gameName"* & platforms = ($platformId);
limit 1;
''';

      final response = await http.post(
        Uri.parse("$_baseUrl/games"),
        headers: {
          'Client-ID': _clientId,
          'Authorization': 'Bearer $token',
          'Content-Type': 'text/plain',
        },
        body: body,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        if (data.isNotEmpty) {
          final game = data[0];

          String? imageUrl;
          if (game['cover'] != null && game['cover']['url'] != null) {
            imageUrl = "https:${game['cover']['url']}";
            imageUrl = imageUrl.replaceAll('t_thumb', 't_cover_big');
          }

          String? dateStr;
          if (game['first_release_date'] != null) {
            // Unix timestamp
            final date = DateTime.fromMillisecondsSinceEpoch(
              game['first_release_date'] * 1000,
            );
            dateStr =
                "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
          }

          // Extract Lists
          final List<String> genres = [];
          if (game['genres'] != null) {
            for (var g in game['genres']) {
              if (g['name'] != null) genres.add(g['name']);
            }
          }

          final List<String> developers = [];
          final List<String> publishers = [];
          if (game['involved_companies'] != null) {
            for (var c in game['involved_companies']) {
              final companyName = c['company']?['name'];
              if (companyName != null) {
                if (c['developer'] == true) developers.add(companyName);
                if (c['publisher'] == true) publishers.add(companyName);
              }
            }
          }

          String? rating;
          if (game['total_rating'] != null) {
            rating = "${(game['total_rating'] as num).toInt()}%";
          }

          return GameMetadata(
            title: game['name'] ?? gameName,
            description: game['summary'],
            releaseDate: dateStr,
            imageUrl: imageUrl,
            provider: name,
            genre: genres.isNotEmpty ? genres.join(', ') : null,
            developer: developers.isNotEmpty ? developers.join(', ') : null,
            publisher: publishers.isNotEmpty ? publishers.join(', ') : null,
            rating: rating,
            players:
                null, // IGDB requires separate endpoint/mode-fetching usually, keeping simple for now
          );
        }
      }
    } catch (e) {
      print('❌ IGDB Search Error: $e');
    }
    return null;
  }

  int? getPlatformId(String key) {
    // Mapping from Romifleur console keys to IGDB Platform IDs
    const map = {
      "NES": 18,
      "SNES": 19,
      "N64": 4,
      "GameCube": 21,
      "Wii": 5,
      "WiiU": 41,
      "GB": 33,
      "GBC": 22,
      "GBA": 24,
      "NDS": 20,
      "3DS": 37,
      "VirtualBoy": 87,
      "MasterSystem": 64,
      "MegaDrive": 29,
      "Sega32X": 30,
      "SegaCD": 78,
      "Saturn": 32,
      "Dreamcast": 23,
      "GameGear": 35,
      "SG1000": 6,
      "PS1": 7,
      "PS2": 8,
      "PS3": 9,
      "PSP": 38,
      "PSVita": 46,
      "Xbox": 11,
      "Xbox360": 12,
      "NeoGeoPocket": 79,
      "NeoGeoPocketColor": 80,
      "PC_Engine": 86,
      "PC_Engine_CD": 150,
      "SuperGrafx": 128,
      "Atari2600": 59,
      "Atari5200": 66,
      "Atari7800": 60,
      "AtariLynx": 61,
      "AtariJaguar": 62,
      "AtariJaguarCD": 62, // Often mapped same as Jaguar base
    };
    return map[key];
  }
}
